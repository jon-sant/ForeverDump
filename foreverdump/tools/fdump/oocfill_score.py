"""v2.2.19 offline score of the out-of-combat pre-fill on BG runs (combat log truth).

Episodes: (unit, fight) pairs - a fight is a PLAYER_REGEN_DISABLED..ENABLED window of my own (SV tape, aligned to the log
with classderive.align). For each episode, at the unit's FIRST event in that fight, which facts were already cached:
  friendly players  class / level / max health: raid tokens are clear in and out of combat -> cached (100% by design)
  enemy players     identity (name key) if the unit was seen before (any earlier event); class if it took part in an
                    earlier fight that ended before this one (meter roster class + name read out of combat after that fight;
                    weighted by the run-14 out-of-combat name readability 14/16); max health = RefData classLevelHP of the
                    cached class at the bracket median level (error reported vs the log's max health)
  NPCs              max health from RefData npcs (leave-one-run-out) by NPC id + level
Time to identify (class) per enemy episode: reset-per-fight (no cache: P+K inside the fight, else the meter after it) vs
cached (knowledge kept across fights = the pre-fill) vs scoreboard (upper bound if the scoreboard is clear ooc)."""
import bisect, collections, json, os, pickle, statistics, sys

from . import refdata, classderive

NAME_CLEAR = 14 / 16.0


def _windows(rows, base):
    out, start = [], None
    for r in rows:
        e = r.get("e")
        if e == "PLAYER_REGEN_DISABLED" and start is None:
            start = r["t"] + base
        elif e == "PLAYER_REGEN_ENABLED" and start is not None:
            out.append((start, r["t"] + base))
            start = None
    return out


def unit_events(path, t0, t1):
    """every unit's events (as source or dest) inside [t0, t1]: guid -> sorted times; NPC id + level + max hp; power types"""
    ev = collections.defaultdict(list)
    info = {}
    ptype = collections.defaultdict(set)
    for t, p in refdata.lines(path):
        if t is None or len(p) < 12 or not (t0 <= t <= t1):
            continue
        for g in (p[1], p[5]):
            if g and g != "0000000000000000" and (g.startswith("Player-") or g.startswith("Creature-")):
                ev[g].append(t)
        if len(p) > 30 and p[12] and p[12] != "0000000000000000":
            mx, lvl, pt = refdata._int(p[15]), refdata._int(p[30]), refdata._int(p[22])
            if mx and lvl:
                info[p[12]] = (mx, lvl)
            if pt is not None and p[12] == p[1]:
                ptype[p[12]].add(pt)
    return ev, info, ptype


def score_run(run_dir, raw, ref, truth):
    me = [g for g, p in truth.items() if p.get("mine")]
    if raw is None:      # log-only run: my combat windows from the log (classderive.log_windows)
        wins, (t0, t1) = classderive.log_windows(os.path.join(run_dir, "WoWCombatLog.txt"), me[0] if me else None)
    else:
        from . import bgreplay
        cs, _ = bgreplay.main_capture(raw)
        _, rows = bgreplay.stream(raw)
        myev = classderive.log_events(os.path.join(run_dir, "WoWCombatLog.txt"))
        base = classderive.align(cs, rows, myev.get(me[0], []) if me else [])
        t0, t1 = cs["startTime"] + base, cs["stopTime"] + base
        wins = _windows(rows, base)
    ev, info, ptype = unit_events(os.path.join(run_dir, "WoWCombatLog.txt"), t0, t1)
    ends = [w[1] for w in wins]
    comp = {pl["class"] for g, pl in truth.items() if pl.get("hostile") and pl.get("class") and ev.get(g)}
    lv = [info[g][1] for g, pl in truth.items() if g in info and pl.get("class")]
    bracket = int(statistics.median(lv)) if lv else None
    clhp = ref.get("classLevelHP", {})
    npcs = ref.get("npcs", {})
    stat = collections.Counter()
    tti = {"reset": [], "cached": [], "score": []}
    hp_err = []
    for g, times in ev.items():
        isP = g.startswith("Player-")
        pl = truth.get(g, {}) if isP else {}
        if isP and (pl.get("mine") or not pl.get("class")):
            continue
        seen_before = None
        known_class_at = None        # time the class became known (cached path)
        for (ws, we) in wins:
            i = bisect.bisect_left(times, ws)
            if i >= len(times) or times[i] > we:
                continue
            first = times[i]
            if not isP:
                stat["npcEp"] += 1
                nid = g.split("-")[5] if len(g.split("-")) > 5 else None
                if nid and nid in npcs:
                    stat["npcHp"] += 1
                continue
            if not pl.get("hostile"):
                stat["friendEp"] += 1
                stat["friendCached"] += 1        # raid tokens clear: class / level / max health
                continue
            stat["enemyEp"] += 1
            if seen_before is not None:
                stat["enemyIdentity"] += 1
            # class cached at the episode start: took part in an earlier fight that already ended (meter ooc + name)
            if known_class_at is not None and known_class_at <= first:
                stat["enemyClass"] += 1
                stat["enemyClassW"] += NAME_CLEAR
                key = "%s:%d" % (pl["class"], bracket) if bracket else None
                if key in clhp and g in info:
                    hp_err.append(abs(clhp[key] - info[g][0]) / float(info[g][0]))
                    stat["enemyHpEst"] += 1
            # time to identify inside this episode
            cand = set(comp) or set(refdata.CLASSES)
            t_pk = None
            for pt in ptype.get(g, ()):
                if pt in classderive.POWER_CLASSES:
                    cand &= classderive.POWER_CLASSES[pt]
            if len(cand) == 1:
                t_pk = first
            reset = 0.0 if t_pk is not None else (we - first)
            cached = 0.0 if (known_class_at is not None and known_class_at <= first) else reset
            tti["reset"].append(reset)
            tti["cached"].append(cached)
            tti["score"].append(0.0)
            if known_class_at is None:
                k = bisect.bisect_left(ends, first)
                if k < len(ends):
                    known_class_at = ends[k] + 1.0      # meter sweep 1 s after REGEN_ENABLED
            seen_before = first
    def med(x): return round(statistics.median(x), 1) if x else None
    def mean(x): return round(sum(x) / len(x), 1) if x else None
    pct = lambda a, b: round(100.0 * a / b, 1) if b else None   # noqa: E731
    return {
        "fights": len(wins), "enemyEpisodes": stat["enemyEp"], "friendEpisodes": stat["friendEp"], "npcEpisodes": stat["npcEp"],
        "enemyIdentityPct": pct(stat["enemyIdentity"], stat["enemyEp"]),
        "enemyClassPct": pct(stat["enemyClass"], stat["enemyEp"]),
        "enemyClassPctNameWeighted": pct(stat["enemyClassW"], stat["enemyEp"]),
        "enemyHpEstPct": pct(stat["enemyHpEst"], stat["enemyEp"]),
        "enemyHpEstMedianErrPct": round(100 * statistics.median(hp_err), 1) if hp_err else None,
        "friendCachedPct": pct(stat["friendCached"], stat["friendEp"]),
        "npcHpPct": pct(stat["npcHp"], stat["npcEp"]),
        "tti": {k: {"median": med(v), "mean": mean(v)} for k, v in tti.items()},
        "bracket": bracket,
    }


def main(argv=None):
    import argparse, glob
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--truth", required=True)
    ap.add_argument("--raw", required=True, help="pickle pattern with {run}, e.g. /tmp/v218_{run}.pkl")
    ap.add_argument("--out", default=None)
    ap.add_argument("--log-only", nargs="*", default=None, help="run dirs scored from the log alone (no SV capture)")
    a = ap.parse_args(argv)
    truth = json.load(open(a.truth))
    allp = sorted(glob.glob("real/*/WoWCombatLog*.txt"))
    try:
        from . import inclusion as _inc
        allp = [p for p in allp if _inc.is_included(p.split("/")[1])]
    except Exception:
        pass
    out = {}
    for full in sorted(truth):
        short = full.split("-")[3] if full.count("-") >= 3 else full
        rawp = a.raw.format(run=short)
        if full in (a.log_only or []):
            raw = None
        elif not os.path.exists(rawp):
            continue
        else:
            with open(rawp, "rb") as f:
                raw = pickle.load(f)
        ref, _, _ = refdata.build([p for p in allp if full not in p])
        out[short] = score_run(os.path.join("real", full), raw, ref, truth[full])
        print(short, json.dumps(out[short]))
    if a.out:
        with open(a.out, "w") as f:
            json.dump(out, f, indent=1)
    return out


if __name__ == "__main__":
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    main()
