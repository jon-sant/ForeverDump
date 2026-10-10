"""Offline class-derivation scorer (v2.2.18). Box only: reads real/ combat logs + SVs, prints aggregate numbers.

Truth: per-player class from tools/fdump/refdata.py (log spells -> class). The live engine can only use signals that
are readable in a BG. Each signal is simulated from the log for the enemy players inside the capture window:
  P  power type of the unit (UNIT_POWER_* powerType / UnitPowerType: clear on plates and target in BG)
       0 mana -> casters + hunter + druid, 1 rage -> warrior/druid, 3 energy -> rogue/druid
  C  cast-time fingerprint (UNIT_SPELLCAST_START -> SUCCEEDED timing, spell secret): the classes that own a spell with
       that cast time in the reference table (built WITHOUT this run: leave-one-run-out)
  M  damage-meter join: the meter lists every combatant of both teams with a CLEAR classFilename; source names are
       clear out of combat, plate UnitName is clear in combat -> a name key joins the row to the unit. Identified at
       the first out-of-combat moment (PLAYER_REGEN_ENABLED in the capture) after the enemy's first combat event.
Visibility caveat: P and C assume the unit was on a plate / target when it acted (upper bound); M assumes the enemy's
meter row name is clear out of combat (the v2.2.18 lab probe `meterNames` measures it).
"""
import bisect, collections, os, re, statistics

from . import refdata

POWER_CLASSES = {0: {"MAGE", "PRIEST", "WARLOCK", "PALADIN", "SHAMAN", "HUNTER", "DRUID"},
                 1: {"WARRIOR", "DRUID"}, 3: {"ROGUE", "DRUID"}, 2: {"HUNTER"}}


def day_seconds(date_str):
    y, mo, d, hh, mm, ss = map(int, re.split(r"[- :]", date_str))
    return refdata.log_seconds(y, mo, d, hh, mm, ss)   # time audit: continuous across month ends (was day-of-month)


def log_events(path):
    """per-player own events: (t, sub, spellId, powerType)"""
    ev = collections.defaultdict(list)
    for t, p in refdata.lines(path):
        if t is None or len(p) < 12 or not refdata.is_player(p[1]):
            continue
        sub = p[0]
        if not sub.startswith(("SPELL_", "RANGE_", "SWING_")):
            continue
        pt = refdata._int(p[22]) if (len(p) > 22 and p[12] == p[1]) else None
        sid = refdata._int(p[9]) if sub.startswith(("SPELL_", "RANGE_")) else None
        ev[p[1]].append((t, sub, sid, pt))
    return ev


def align(cs, rows, my_ev):
    """log time = anchor day-seconds + (gameTime - anchor.gameTime) + offset; offset from my own casts"""
    a = cs["anchor"]
    base = day_seconds(a["date"]) - a["gameTime"]
    tape = [r["t"] for r in rows if r.get("e") == "UNIT_SPELLCAST_SUCCEEDED" and (r.get("a") or [None])[0] == "player"]
    logc = sorted(t for t, sub, _, _ in my_ev if sub == "SPELL_CAST_SUCCESS")
    if not tape or not logc:
        return base
    h = collections.Counter()
    for tt in tape[:400]:
        x = tt + base
        i = bisect.bisect_left(logc, x - 4 * 3600)
        j = bisect.bisect_right(logc, x + 4 * 3600)
        for lt in logc[i:j]:
            h[round(lt - x)] += 1
    return base + (h.most_common(1)[0][0] if h else 0)


def fingerprints(ref):
    """cast time (0.1 s) -> classes; a bucket shared with any classless (generic) spell, or its +-0.1 s neighbours,
    is dropped: a generic cast (mount, bandage, flag) must never eliminate the true class"""
    fp, poisoned = collections.defaultdict(set), set()
    for sid, e in ref["spells"].items():
        ct = e.get("castTime", 0) or 0
        if ct <= 0.4:
            continue
        b = round(ct, 1)
        if e.get("class"):
            fp[b].add(e["class"])
        else:
            poisoned |= {round(b - 0.1, 1), b, round(b + 0.1, 1)}
    return {k: v for k, v in fp.items() if k not in poisoned}


HOSTILE = 0x40


def log_windows(path, me, leave=5.0):
    """my combat windows from the log alone (no SV tape): any event between me and a hostile unit puts me in combat;
    the window ends `leave` s after the last such event (the client leaves combat ~5 s after the last hostile action)"""
    ts = []
    span = [None, None]
    for t, p in refdata.lines(path):
        if t is None or len(p) < 8:
            continue
        if span[0] is None:
            span[0] = t
        span[1] = t
        try:
            sf, df = int(p[3], 16), int(p[7], 16)
        except (ValueError, TypeError):
            continue
        if (p[1] == me and df & HOSTILE) or (p[5] == me and sf & HOSTILE):
            ts.append(t)
    wins = []
    for t in ts:
        if wins and t - wins[-1][1] <= leave:
            wins[-1][1] = t
        else:
            wins.append([t, t])
    return [(a, b + leave) for a, b in wins], span


def score_run(run_dir, raw, ref, truth_players, use_cast_time=False, use_comp=True):
    ev = log_events(os.path.join(run_dir, "WoWCombatLog.txt"))
    me = [g for g, p in truth_players.items() if p.get("mine")]
    if raw is None:
        # v2.2.20 log-only run (run 15: the SV holds no capture of this BG): windows from the log
        wins, span = log_windows(os.path.join(run_dir, "WoWCombatLog.txt"), me[0] if me else None)
        t0, t1 = span
        regen = sorted(w[1] for w in wins)
        base, cs = 0.0, None
    else:
        from . import bgreplay
        cs, _ = bgreplay.main_capture(raw)
        meta, rows = bgreplay.stream(raw)
        base = align(cs, rows, ev.get(me[0], []) if me else [])
        t0, t1 = cs["startTime"] + base, cs["stopTime"] + base
        regen = sorted(r["t"] + base for r in rows if r.get("e") == "PLAYER_REGEN_ENABLED")
    fp = fingerprints(ref) if use_cast_time else {}
    comp = {pl["class"] for g, pl in truth_players.items() if pl.get("hostile") and pl.get("class")
            and any(t0 <= e[0] <= t1 for e in ev.get(g, [])[:1] + ev.get(g, [])[-1:])} if use_comp else None
    res = []
    for g, pl in truth_players.items():
        if not pl.get("hostile") or not pl.get("class"):
            continue
        evs = [e for e in ev.get(g, []) if t0 <= e[0] <= t1]
        if not evs:
            continue
        first, truth = evs[0][0], pl["class"]
        # K: the meter's enemy composition (class is clear in and out of combat) bounds the candidates; simulated
        # with the log composition of the window (the meter matched it on runs 10-14, see HSM-STATUS)
        cand, t_id, starts = set(comp) if comp else set(refdata.CLASSES), None, {}
        for t, sub, sid, pt in evs:
            if pt in POWER_CLASSES:
                cand &= POWER_CLASSES[pt]
            if sub == "SPELL_CAST_START":
                starts[sid] = t
            elif sub == "SPELL_CAST_SUCCESS" and sid in starts:
                d = round(t - starts.pop(sid), 1)
                hit = set()
                for dd in (d - 0.1, d, d + 0.1):
                    hit |= fp.get(round(dd, 1), set())
                if hit and d > 0.4 and (cand & hit):
                    cand &= hit
            if len(cand) == 1 and t_id is None:
                t_id = t
        k = bisect.bisect_right(regen, first)
        res.append({"truth": truth, "first": first, "cand": sorted(cand), "tId": t_id, "pcOk": truth in cand,
                    "pcSingle": len(cand) == 1, "tMeter": regen[k] if k < len(regen) else None})
    if cs is None:
        return res, {"offset": None, "logOnly": True}
    off = round(base - (day_seconds(cs["anchor"]["date"]) - cs["anchor"]["gameTime"]))
    return res, {"offset": off}


def summarize(res):
    n = len(res)
    single = [r for r in res if r["pcSingle"]]
    ok = [r for r in single if r["pcOk"]]
    tt = [r["tId"] - r["first"] for r in ok if r["tId"] is not None]
    m = [r for r in res if r["tMeter"] is not None]
    tm = [r["tMeter"] - r["first"] for r in m]
    comb = []
    for r in res:
        xs = []
        if r["pcSingle"] and r["pcOk"] and r["tId"] is not None:
            xs.append(r["tId"] - r["first"])
        if r["tMeter"] is not None:
            xs.append(r["tMeter"] - r["first"])
        if xs:
            comb.append(min(xs))
    pct = lambda a, b: round(100.0 * a / b, 1) if b else None
    return {"enemies": n,
            "PC": {"assigned": len(single), "correct": len(ok), "wrong": len(single) - len(ok),
                   "coverage": pct(len(ok), n), "accuracy": pct(len(ok), len(single)),
                   "medianTTI": round(statistics.median(tt), 1) if tt else None,
                   "meanCandidates": round(statistics.mean(len(r["cand"]) for r in res), 2) if res else None,
                   "truthInSet": pct(sum(1 for r in res if r["pcOk"]), n)},
            "M": {"assigned": len(m), "coverage": pct(len(m), n),
                  "medianTTI": round(statistics.median(tm), 1) if tm else None},
            "combined": {"coverage": pct(len(comb), n), "medianTTI": round(statistics.median(comb), 1) if comb else None}}
