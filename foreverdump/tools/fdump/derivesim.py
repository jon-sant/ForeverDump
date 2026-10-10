"""Offline check of the aura-presence DERIVATION rule (state D) against combat-log truth (run 22, 2026-10-10).

The addon derives "aura X present on unit U until t + dur" from the player's own clear UNIT_SPELLCAST_SUCCEEDED
(AuraPresence.OnOwnCast). This replays that rule on the log's own SPELL_CAST_SUCCESS rows of the player and scores
each derivation against the log's SPELL_AURA_APPLIED / REFRESH / REMOVED rows:
  applied  = the expected aura appeared on the expected unit within APPLY_WINDOW s of the cast
  miss     = it did not (resist / immune / out of range / wrong unit guess)
  end:ok   = its removal fell within END_TOL s of cast + dur
  end:early= removed earlier (dispel, death, consumed charges); end:late = later (duration changed / talent)
  end:open = still on at the end of the log / no removal seen; refreshed = my next cast of it came first
Rule sources (all dynamic, per build, read from the SV): knowledge[build].spells parsed.auraDuration (same-ID rule),
refLearned[build].auraDur (OOC-learned durations, min), ForeverDumpDB.auraPairs[build] (observed pairs).
Also lists the auras that actually appeared on me <= PAIR_WINDOW s after my own casts (what the in-game pair learner
would record)."""
import argparse
import collections
import json
import sys

from . import refdata

APPLY_WINDOW = 1.0
END_TOL = 1.5
PAIR_WINDOW = 0.6
NOGUID = "0000000000000000"


def rules_from_sv(raw, build):
    db = (raw or {}).get("ForeverDumpDB") or {}
    b = str(build)
    rules = {}
    kn = ((db.get("knowledge") or {}).get(b) or {}).get("spells") or {}
    for sid, v in kn.items():
        p = ((v or {}).get("data") or {}).get("parsed") or {}
        if isinstance(p.get("auraDuration"), (int, float)) and p["auraDuration"] > 0:
            rules.setdefault(int(sid), {})[int(sid)] = {"dur": float(p["auraDuration"]), "src": "knowledge"}
    ad = ((db.get("refLearned") or {}).get(b) or {}).get("auraDur") or {}
    for c in rules.values():
        for aid, r in c.items():
            lr = ad.get(aid) or ad.get(str(aid))
            if isinstance(lr, dict) and isinstance(lr.get("min"), (int, float)):
                r["dur"], r["src"] = float(lr["min"]), "refLearned"
    for cast, m in ((db.get("auraPairs") or {}).get(b) or {}).items():
        for aid, pr in (m or {}).items():
            lr = ((db.get("auraLearned") or {}).get(b) or {}).get(aid) or {}
            if isinstance(lr.get("dur"), (int, float)):
                rules.setdefault(int(cast), {})[int(aid)] = {"dur": float(lr["dur"]), "src": "pair",
                                                              "who": "self" if (pr.get("self") or 0) >= (pr.get("target") or 0) else "target"}
    return rules


def simulate(rows, mine, rules):
    """rows: [(t, fields)] from refdata.lines; mine: player GUID; rules: {castSid: {auraSid: {dur, src[, who]}}}"""
    aura = collections.defaultdict(list)     # (sid, dest) -> [(t, event)]
    casts = []
    pairs = collections.Counter()
    for t, p in rows:
        if t is None or not p:
            continue
        ev = p[0]
        if ev in ("SPELL_AURA_APPLIED", "SPELL_AURA_REFRESH", "SPELL_AURA_REMOVED", "SPELL_AURA_APPLIED_DOSE") and len(p) > 9:
            try:
                sid = int(p[9])
            except ValueError:
                continue
            aura[(sid, p[5])].append((t, ev, p[1]))
        elif ev == "SPELL_CAST_SUCCESS" and len(p) > 9 and p[1] == mine:
            try:
                casts.append((t, int(p[9]), p[5]))
            except ValueError:
                pass
    # observed pairs: auras of mine applied on me within PAIR_WINDOW after a cast of mine
    mine_on_me = sorted((tt, sid) for (sid, dest), evs in aura.items() if dest == mine
                        for tt, ev, src in evs if ev == "SPELL_AURA_APPLIED" and src == mine)
    j = 0
    for t, csid, _ in casts:
        while j < len(mine_on_me) and mine_on_me[j][0] < t - 0.05:
            j += 1
        k = j
        while k < len(mine_on_me) and mine_on_me[k][0] <= t + PAIR_WINDOW:
            pairs[(csid, mine_on_me[k][1])] += 1
            k += 1
    res = collections.defaultdict(collections.Counter)
    errs = collections.defaultdict(list)
    for i, (t, csid, dest) in enumerate(casts):
        for aid, r in (rules.get(csid) or {}).items():
            who = r.get("who") or ("self" if dest in (NOGUID, "", mine) else "target")
            unit = mine if who == "self" else dest
            key = "%d->%d" % (csid, aid)
            evs = aura.get((aid, unit)) or []
            app = [e for e in evs if t - 0.05 <= e[0] <= t + APPLY_WINDOW and e[1] in ("SPELL_AURA_APPLIED", "SPELL_AURA_REFRESH")
                   and e[2] == mine]
            if not app:
                res[key]["miss"] += 1
                continue
            res[key]["applied"] += 1
            pred = t + r["dur"]
            nxt = next((c[0] for c in casts[i + 1:] if c[1] == csid and c[2] == dest), None)
            rem = next((e[0] for e in evs if e[0] > app[0][0] and e[1] == "SPELL_AURA_REMOVED"), None)
            if nxt is not None and (rem is None or nxt < rem) and nxt < pred:
                res[key]["refreshed"] += 1
            elif rem is None:
                res[key]["end:open"] += 1
            else:
                d = rem - pred
                errs[key].append(round(d, 2))
                res[key]["end:ok" if abs(d) <= END_TOL else ("end:early" if d < 0 else "end:late")] += 1
    return {"casts": len(casts), "rules": {k: {a: dict(v) for a, v in m.items()} for k, m in rules.items()},
            "score": {k: dict(v) for k, v in sorted(res.items())},
            "endError": {k: {"n": len(v), "median": sorted(v)[len(v) // 2]} for k, v in errs.items() if v},
            "observedPairs": {"%d->%d" % k: n for k, n in pairs.most_common(40)}}


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("sv")
    ap.add_argument("log")
    ap.add_argument("--mine", required=True)
    ap.add_argument("--build", default=None)
    ap.add_argument("--json")
    a = ap.parse_args(argv)
    from .dump import load_raw
    raw = load_raw(a.sv)
    build = a.build or (((raw.get("ForeverDumpDB") or {}).get("meta") or {}).get("build"))
    out = simulate(list(refdata.lines(a.log)), a.mine, rules_from_sv(raw, build))
    out["build"] = build
    js = json.dumps(out, indent=1, sort_keys=True, default=str)
    if a.json:
        with open(a.json, "w") as f:
            f.write(js)
    print(js)
    return 0


if __name__ == "__main__":
    sys.exit(main())
