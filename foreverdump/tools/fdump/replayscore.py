"""v2.2.10: per-rule detection/correlation hit/miss of a capture against its combat log (ground truth).

Used to score the real-data load replays (tests/bg_replay.lua --out SV) next to the original live capture:
  attribution  replay 'after' scores per category (attr:*): scorable n, hits = accuracy x n, coverage
  deaths       coverage matrix 'death' rows: log events vs. visible on a unit token vs. live-detected
  interrupts   attr:interrupt + live interrupt predictions (rule names) + verify interrupt-attribution
  meter join   live estimate vs C_DamageMeter vs CLEU per fight/metric: match / off / unexplained
Counts only (no names, no GUIDs), so the JSON/markdown is safe to keep in docs.
usage: python3 -m fdump.replayscore --file WoWCombatLog.txt [--year 2026] LABEL=SV.lua [LABEL=SV.lua ...] [--json OUT]
"""
from __future__ import annotations

import argparse
import json
import sys

from . import analysis, characters as charmod, combatlog, coverage as covmod, damagemeter_join as dmjoin, verify_live, knowlint
from .dump import Dump


def score(sv_path, fx):
    dump = Dump.load(sv_path)
    player, _info = charmod.resolve(None, fx, dump)
    cov = covmod.analyze(dump, fx, player)
    kl = knowlint.analyze(dump, fx, player)
    ver = verify_live.analyze(dump, fx, player, cov, kl, cov["_ctx"]["cls"], replay_verdicts=cov.get("verdicts"))
    acc = analysis.accuracy_table(cov, ver)
    out = {"attribution": {}, "deaths": {"log": 0, "onToken": 0, "visible": 0}, "interrupts": {}, "meterJoin": {},
           "rleExpanded": bool(getattr(dump, "rle_expanded", False))}
    for k, v in sorted(acc.items()):
        if k.startswith("attr:"):
            n = v.get("n") or 0
            out["attribution"][k[5:]] = {"n": n, "hit": int(round((v.get("accuracy") or 0) * n / 100.0)),
                                         "miss": n - int(round((v.get("accuracy") or 0) * n / 100.0)),
                                         "accuracy": v.get("accuracy"), "coverage": v.get("coverage")}
    for r in cov.get("matrix") or []:
        if r.get("cat") == "death":
            for f in ("log", "onToken", "visible"):
                out["deaths"][f] += int(r.get(f) or 0)
    it = out["interrupts"]
    a = acc.get("attr:interrupt")
    it["attribution"] = {"n": a["n"], "accuracy": a["accuracy"]} if a else None
    preds = cov.get("interrupts") or []
    it["livePredictions"] = len(preds)
    it["rules"] = sorted({p.get("rule") for p in preds if p.get("rule")})
    v = acc.get("verify:interrupt-attribution")
    it["verify"] = {"n": v["n"], "accuracy": v["accuracy"]} if v else None
    j = dmjoin.join(dump, cov)
    s = j.get("summary") or {}
    out["meterJoin"] = {k: s.get(k) for k in ("fights", "match", "off", "unexplained", "units")}
    out["verify"] = {k: {x: a.get(x) for x in ("n", "V", "C", "U", "refuted", "missed")}
                     for k, a in sorted(((ver or {}).get("accuracy") or {}).items())}
    return out


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", required=True)
    ap.add_argument("--year", type=int, default=None)
    ap.add_argument("--json")
    ap.add_argument("svs", nargs="+", help="LABEL=SV.lua")
    a = ap.parse_args(argv)
    fx = combatlog.parse_file(a.file, year=a.year)
    res = {}
    for spec in a.svs:
        label, path = spec.split("=", 1)
        res[label] = score(path, fx)
    js = json.dumps(res, indent=1, sort_keys=True, default=str)
    if a.json:
        with open(a.json, "w") as f:
            f.write(js + "\n")
    else:
        sys.stdout.write(js + "\n")


if __name__ == "__main__":
    main()
