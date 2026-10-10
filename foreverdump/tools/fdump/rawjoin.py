"""v2.2.21 raw-identity joins to the combat log (offline, box only).

User decision 2026-10-09: identities are stored raw. Every raw GUID the SV holds joins 1:1 to the combat log (truth:
GUID -> class / hostile / first event). Sources joined here:
  meter   ForeverDumpCombatLogDB.sessions[].damageMeter[].byType.*.combatSources[] (sourceGUID + classFilename + name,
          read out of combat): MEASURED M signal per enemy (was simulated from the log composition until v2.2.20)
  signals ForeverDumpLogDB.inference.signals[].guid (unit GUID read when clear): GUID -> log identity hit rate
  derive  ForeverDumpLogDB.derive.units[key].guids / .names (v2.2.21+): the live class engine per unit vs the log
  cache   ForeverDumpLogDB.oocfill.cache[player:<GUID>].f.class (v2.2.21+): cached class per unit vs the log
"""
import collections
import json
import os
import pickle
import re
import statistics
import sys

GUID = re.compile(r"^(Player|Pet|Creature|Vehicle)-[0-9A-Za-z-]+$")


def _list(x):
    if isinstance(x, list):
        return x
    if isinstance(x, dict):
        return [x[k] for k in sorted(x, key=lambda k: (not isinstance(k, int), str(k)))]
    return []


def meter_rows(raw):
    """[(gameTime, guid, class, name, faction)] from every combat-log damage-meter snapshot"""
    out = []
    for s in _list((raw.get("ForeverDumpCombatLogDB") or {}).get("sessions")):
        if not isinstance(s, dict):
            continue
        for snap in _list(s.get("damageMeter")):
            if not isinstance(snap, dict):
                continue
            t = snap.get("gameTime")   # GetTime() seconds (snap.time is epoch)
            for ty in (snap.get("byType") or {}).values():
                if not isinstance(ty, dict):
                    continue
                for src in _list(ty.get("combatSources")):
                    if isinstance(src, dict) and isinstance(src.get("sourceGUID"), str):
                        out.append((t, src["sourceGUID"], src.get("classFilename"), src.get("name"), src.get("factionGroup")))
    return out


def live_units(raw):
    """v2.2.21+: [(guid, class, via, enemy)] from derive.units (raw guids) and the oocfill cache (player:<GUID> keys)"""
    log = raw.get("ForeverDumpLogDB") or {}
    out = []
    der = (log.get("derive") or {}).get("units") or {}
    for key, u in der.items():
        if not isinstance(u, dict) or not u.get("class"):
            continue
        for g in (u.get("guids") or {}):
            out.append((g, u["class"], "derive:" + str(u.get("via")), u.get("enemy")))
    cache = ((log.get("oocfill") or {}).get("cache")) or {}
    for key, u in cache.items():
        if not isinstance(key, str) or not isinstance(u, dict):
            continue
        g = key.split(":", 1)[1] if key.startswith(("player:", "pet:", "guid:")) else None
        f = (u.get("f") or {})
        g = g if (g and GUID.match(g)) else ((f.get("guid") or {}).get("v"))   # pre-2.2.21 keys are salted hashes
        c = (f.get("class") or {}).get("v")
        if g and c:
            out.append((g, c, "cache", None))
    return out


def signal_guids(raw):
    sig = ((raw.get("ForeverDumpLogDB") or {}).get("inference") or {}).get("signals")
    return [s["guid"] for s in _list(sig) if isinstance(s, dict) and isinstance(s.get("guid"), str)]


def score_run(run_dir, raw, truth, ev=None):
    from . import classderive, bgreplay
    if ev is None:
        ev = classderive.log_events(os.path.join(run_dir, "WoWCombatLog.txt"))
    me = [g for g, p in truth.items() if p.get("mine")]
    cs, _ = bgreplay.main_capture(raw)
    meta, rows = bgreplay.stream(raw)
    base = classderive.align(cs, rows, ev.get(me[0], []) if me else [])
    t0, t1 = cs["startTime"] + base, cs["stopTime"] + base
    enemies = {}
    for g, pl in truth.items():
        if pl.get("hostile") and pl.get("class"):
            evs = [e for e in ev.get(g, []) if t0 <= e[0] <= t1]
            if evs:
                enemies[g] = evs[0][0]
    # meter (measured M)
    mr = meter_rows(raw)
    first_ok, wrong, seen = {}, collections.Counter(), set()
    for t, g, cls, name, fac in mr:
        seen.add(g)
        pl = truth.get(g)
        if not pl or not cls or not pl.get("class"):
            continue
        if cls != pl.get("class"):
            wrong[g] += 1
            continue
        if g in enemies and isinstance(t, (int, float)):
            lt = t + base
            if lt >= enemies[g] and (g not in first_ok or lt < first_ok[g]):
                first_ok[g] = lt
    joined = [g for g in seen if g in truth]
    tti = [first_ok[g] - enemies[g] for g in first_ok]
    sg = signal_guids(raw)
    lu = live_units(raw)
    lu_ok = sum(1 for g, c, _, _ in lu if truth.get(g, {}).get("class") == c)
    lu_join = sum(1 for g, _, _, _ in lu if g in truth)
    pct = lambda a, b: round(100.0 * a / b, 1) if b else None
    return {
        "enemies": len(enemies),
        "meter": {"rows": len(mr), "guids": len(seen), "joinedToLog": len(joined), "joinRate": pct(len(joined), len(seen)),
                  "classWrongGuids": len(wrong), "enemyIdentified": len(first_ok), "coverage": pct(len(first_ok), len(enemies)),
                  "medianTTI": round(statistics.median(tti), 1) if tti else None},
        "signals": {"guids": len(sg), "distinct": len(set(sg)), "joinedToLog": sum(1 for g in set(sg) if g in truth)},
        "live": {"units": len(lu), "joinedToLog": lu_join, "correct": lu_ok, "wrong": lu_join - lu_ok},
    }


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--truth", required=True)
    ap.add_argument("--raw", required=True, help="pickle pattern with {run}")
    ap.add_argument("--runs", nargs="*", default=None)
    ap.add_argument("--out")
    a = ap.parse_args(argv)
    truth = json.load(open(a.truth))
    out = {}
    try:
        from . import inclusion as _inc
    except Exception:
        _inc = None
    for full in sorted(truth):
        short = full.split("-")[3] if full.count("-") >= 3 else full
        if _inc is not None and not _inc.is_included(full):
            continue
        if a.runs and short not in a.runs:
            continue
        p = a.raw.format(run=short)
        if not os.path.exists(p):
            continue
        with open(p, "rb") as f:
            raw = pickle.load(f)
        out[short] = score_run(os.path.join("real", full), raw, truth[full])
        print(short, json.dumps(out[short]))
    if a.out:
        with open(a.out, "w") as f:
            json.dump(out, f, indent=1)
    return out


if __name__ == "__main__":
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    main()
