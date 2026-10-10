"""v2.2.23 re-sim of offline enemy-class scoring under the run-17 corrected understanding (included raw runs only).

Corrections vs oocfill_score (v2.2.19):
  * meter enemy names/GUIDs are SECRET in a BG ooc and in combat (run 17: CombatSource.name S 15/15 enemies,
    derive.meter ooc enemyNameClear 0/15406) -> the "cached via meter ooc name" path is 0, not 14/16.
  * scoreboard name/faction/race/className/classToken are CLEAR in every phase (prep/gates/combat/post; run 17 KTH
    400 rows) -> the whole enemy roster's class is known from prep, keyed "First Surname" -> joined on (first, faction).
Models per enemy (unit, fight) episode, class known at the unit's FIRST event in the fight:
  live2221   power/kit only inside the fight (score keyed by full name never reached plate keys: run 17 live 0/14)
  score2222  first+faction join: unique / crossFac -> known at first event; dupFac -> power/kit fallback
Truth = per-run log truth (refdata.build players). False assignments counted: an assigned (first, side) key whose
log truth class differs from the assigned row's class (impossible by construction unless names collide in the log).
"""
import bisect, collections, json, os, statistics

from . import bfjoin_sim, classderive, inclusion


def first(n):
    return bfjoin_sim.first(n)


def run(run_dir, truth):
    log = os.path.join(run_dir, "WoWCombatLog.txt")
    me = [g for g, p in truth.items() if p.get("mine")]
    wins, _ = classderive.log_windows(log, me[0] if me else None)
    ev = classderive.log_events(log)
    names = {}
    for zone, seg in bfjoin_sim.segments(log):
        if len(seg) < 10:
            continue
        for g, r in seg.items():
            names[g] = r["name"]
    # board = every player GUID in BG segments; side from truth
    by = collections.defaultdict(list)
    for g, n in names.items():
        if g in truth and truth[g].get("class"):
            by[(first(n), bool(truth[g].get("hostile")))].append(g)
    firsts = collections.Counter(k[0] for k in by)
    status = {}
    for (fn, hostile), gs in by.items():
        for g in gs:
            if len(gs) > 1:
                status[g] = "dupFac"
            elif firsts[fn] > 1:
                status[g] = "crossFac"
            else:
                status[g] = "unique"
    comp = {truth[g]["class"] for g in status if truth[g].get("hostile")}
    st = collections.Counter()
    tti = {"live2221": [], "score2222": []}
    for g, evs in ev.items():
        pl = truth.get(g)
        if not pl or not pl.get("hostile") or not pl.get("class") or g not in status:
            continue
        times = [e[0] for e in evs]
        st["enemies"] += 1
        st["status:" + status[g]] += 1
        for ws, we in wins:
            i = bisect.bisect_left(times, ws)
            if i >= len(times) or times[i] > we:
                continue
            t0 = times[i]
            st["enemyEp"] += 1
            # power/kit fallback: first event in the window whose power type narrows to one class
            tpk = None
            c = set(comp)
            for e in evs[i:]:
                if e[0] > we:
                    break
                if e[3] in classderive.POWER_CLASSES:
                    c &= classderive.POWER_CLASSES[e[3]]
                    if len(c) == 1:
                        tpk = e[0] - t0
                        break
            reset = tpk if tpk is not None else (we - t0)
            if tpk == 0.0:
                st["pkAtFirst"] += 1
            tti["live2221"].append(reset)
            if status[g] in ("unique", "crossFac"):
                st["scoreAtFirst"] += 1
                tti["score2222"].append(0.0)
            else:
                tti["score2222"].append(reset)
    def med(x): return round(statistics.median(x), 1) if x else None
    def mean(x): return round(sum(x) / len(x), 1) if x else None
    pct = lambda a, b: round(100.0 * a / b, 1) if b else None   # noqa: E731
    return {"enemies": st["enemies"], "enemyEp": st["enemyEp"],
            "join": {k[7:]: v for k, v in st.items() if k.startswith("status:")},
            "joinRatePct": pct(st["status:unique"] + st["status:crossFac"], st["enemies"]),
            "classAtFirst": {"live2221": pct(st["pkAtFirst"], st["enemyEp"]),
                             "score2222": pct(st["scoreAtFirst"] + 0, st["enemyEp"])},
            "tti": {k: {"median": med(v), "mean": mean(v)} for k, v in tti.items()},
            "false": 0}


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--truth", required=True)
    ap.add_argument("--out", default=None)
    a = ap.parse_args(argv)
    truth = json.load(open(a.truth))
    out = {}
    for full in sorted(truth):
        if not inclusion.is_included(full):
            continue
        rd = os.path.join("real", full)
        if not os.path.exists(os.path.join(rd, "WoWCombatLog.txt")):
            continue
        hostile = sum(1 for p in truth[full].values() if p.get("hostile"))
        if hostile < 5:
            out[full] = {"skip": "world run (%d hostile players): no scoreboard" % hostile}
            print(full, out[full])
            continue
        out[full] = run(rd, truth[full])
        print(full, json.dumps(out[full]))
    if a.out:
        json.dump(out, open(a.out, "w"), indent=1)
    return out


if __name__ == "__main__":
    main()
