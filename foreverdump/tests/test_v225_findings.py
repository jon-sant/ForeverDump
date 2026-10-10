"""v2.2.5 distinct-findings regressions: alias collapse, finite lift, minimality, holdout flags,
echo appendix, and the five expected real findings on runs 3/4/5 (skipped if captures absent)."""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from fdump import correlate_findings as cf  # noqa: E402
from fdump import correlate, correlate_ho  # noqa: E402

N = [0]


def ok(cond, msg):
    N[0] += 1
    if not cond:
        raise SystemExit("FAIL: " + msg)


# ---- unit: lift smoothing never 9999
lift, lo, hi = cf.smooth_lift(1.0, 0.0, 6)
ok(lift < 9999 and lift > 1 and lo <= lift <= hi, "smooth_lift finite with CI on zero null")
lift2, _, _ = cf.smooth_lift(0.5, 0.5, 10)
ok(0.5 <= lift2 <= 2.0, "smooth_lift ~1 when prec==null")

# ---- unit: holdout flags
ok(cf.annotate_status({"holdout": {"a": {"status": "held"}, "b": {"status": "held"}}})["status"] == "cross-run",
   "held on 2 -> cross-run, provisional cleared")
ok(cf.annotate_status({"holdout": {"a": {"status": "held"}, "b": {"status": "absent"}}, "provisional": True})["provisional"] is False,
   "held-1 clears provisional flag")
ok(cf.annotate_status({"holdout": {"a": {"status": "failed"}, "b": {"status": "absent"}}})["status"] == "failed",
   "failed holdout")
ok(cf.annotate_status({"holdout": {"a": {"status": "absent"}}})["status"] == "provisional",
   "absent-only -> provisional")

# ---- unit: minimality drops middle-echo depth-3 when endpoints exist
chains = [
    {"hops": ["A", "C"], "precision": 0.9, "support": 10, "pattern": "chain", "depth": 1},
    {"hops": ["A", "DAMAGE_METER_X", "C"], "precision": 0.9, "support": 10, "pattern": "chain", "depth": 2},
    {"hops": ["A", "UNIT_HEAL_PREDICTION|player", "C"], "precision": 0.91, "support": 10, "pattern": "chain", "depth": 2},
    {"hops": ["A", "B", "C"], "precision": 0.95, "support": 12, "pattern": "chain", "depth": 2},  # real gain
]
kept = cf.minimize_chains(chains)
ok(all(len(c["hops"]) != 3 or "DAMAGE_METER" not in c["hops"][1] for c in kept), "middle DM echo pruned")
ok(any(c["hops"] == ["A", "B", "C"] for c in kept), "informative depth-2 kept")
ok(any(c["hops"] == ["A", "C"] for c in kept), "short endpoints kept")

# ---- unit: echo classifier
ok(cf.is_echo_rule({"a": "BAG_UPDATE_COOLDOWN", "b": "SPELL_CAST_SUCCESS|me>npc|spell=370", "known": "ui echo"}),
   "BAG_UPDATE echo")
ok(cf.is_echo_chain({"hops": ["UNIT_SPELLCAST_SENT|player", "UNIT_SPELLCAST_SUCCEEDED|player"]}),
   "SENT->SUCCEEDED echo")
ok(not cf.is_echo_chain({"hops": ["UNIT_SPELLCAST_INTERRUPTED|target", "UNIT_SPELLCAST_SUCCEEDED|player|arg2=8046",
                                   "SPELL_INTERRUPT|me>npc|spell=8046"]}),
   "interrupt chain not echo")

# ---- unit: alias prefer_token
ok(cf.prefer_token("targettarget", "player") == "player", "player beats targettarget")
ok(cf.prefer_token("nameplateN", "target") == "target", "target beats nameplate")

# ---- synthetic distill
res = {
    "captures": ["a", "b"],
    "rules": [{
        "a": "SPELL_UPDATE_COOLDOWN|arg0=370", "b": "SPELL_CAST_SUCCESS|me>npc|spell=370",
        "kind": "live->truth", "support": 6, "nA": 6, "precision": 1.0, "recall": 1.0,
        "lift": 9999, "nullA": 0.0, "nullB": 0.01, "window": 0.05,
        "holdout": {"b": {"status": "held"}, "c": {"status": "held"}}, "capture": "a", "known": None,
        "provisional": True,
    }, {
        "a": "DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=7", "b": "SWING_DAMAGE|npc>me",
        "kind": "live->truth", "support": 49, "nA": 49, "precision": 1.0, "recall": 0.9,
        "lift": 50, "nullA": 0.02, "nullB": 0.02, "window": 0.05,
        "holdout": {"b": {"status": "held"}, "c": {"status": "held"}}, "capture": "a", "known": "damage meter",
        "provisional": False,
    }],
    "rare": [],
    "higher": [{
        "hops": ["UNIT_SPELLCAST_INTERRUPTED|target", "UNIT_SPELLCAST_SUCCEEDED|player|arg2=8046",
                 "SPELL_INTERRUPT|me>npc|spell=8046"],
        "pattern": "identity", "depth": 2, "support": 1, "nA": 1, "precision": 1.0, "lift": 9999,
        "nullA": 0.0, "holdout": {"b": {"status": "absent"}}, "capture": "a", "provisional": True,
        "reason": "interrupt was mine", "proposedRule": "InterruptAttribution",
    }, {
        "hops": ["UNIT_COMBAT|player|arg1=HEAL", "UNIT_HEAL_PREDICTION|player",
                 "SPELL_PERIODIC_HEAL|mine>me|spell=6371"],
        "pattern": "chain", "depth": 2, "support": 25, "nA": 28, "precision": 0.9, "lift": 9999,
        "nullA": 0.0, "holdout": {"b": {"status": "held"}, "c": {"status": "held"}}, "capture": "a",
        "provisional": True, "reason": "totem heal", "proposedRule": "TotemHeal",
    }, {
        "hops": ["BAG_UPDATE_COOLDOWN", "SPELL_CAST_SUCCESS|me>npc|spell=370"],
        "pattern": "sequence", "depth": 1, "support": 3, "nA": 10, "precision": 0.3, "lift": 5,
        "nullA": 0.1, "holdout": {}, "capture": "a", "provisional": True,
    }],
}
alias_obs = [{"alias": "targettarget", "canon": "player", "n": 100, "via": "same-frame-payload"}]
fs = cf.distill(res, alias_obs=alias_obs, max_findings=28)
ids = [f["id"] for f in fs]
ok("token-alias" in ids, "token-alias finding present")
ok("cd-payload-clear" in ids, "cd-payload-clear promoted")
ok("dm-type-7" in ids, "dm-type-7 promoted")
ok("identity-interrupt" in ids or any("interrupt" in i for i in ids), "interrupt finding")
ok("totem-heal-live" in ids, "totem-heal finding")
ok(len(fs) <= 28, "under 30 distinct findings")
ok(all((f.get("evidence") or {}).get("lift", 0) != 9999 for f in fs if f.get("best")),
   "no finding carries lift 9999")
ok(res["rules"][0]["lift"] != 9999 and res["rules"][0]["status"] == "cross-run",
   "1-hop CD smoothed + cross-run (provisional flag fixed)")
ok(res["rules"][0]["provisional"] is False, "cross-run clears provisional")
ok(any(e.get("pattern") == "sequence" or "BAG_" in str(e.get("hops")) for e in res.get("echoes") or []),
   "BAG echo parked in appendix")
md = "\n".join(cf.markdown_distinct(res))
ok("Distinct findings" in md and "Echoes / side-effects" in md, "markdown sections")

# ---- real captures (optional)
RUN5 = os.path.join(ROOT, "real", "2026-10-08-run5", "out", "correlate", "correlate.json")
if os.path.exists(RUN5):
    # Prefer re-mined file if it already has findings; else skip heavy re-run here (done by runner separately)
    data = json.load(open(RUN5))
    if data.get("findings"):
        ids = [f["id"] for f in data["findings"]]
        ok(len(data["findings"]) <= 30, "real distinct findings <= 30 (got %d)" % len(data["findings"]))
        ok("token-alias" in ids, "real: token-alias")
        for need in ("cd-payload-clear", "dm-type-7", "totem-heal-live", "identity-interrupt"):
            ok(need in ids or any(need.split("-")[0] in i for i in ids), "real: " + need)
        ok(all(f.get("status") in ("cross-run", "held-1", "provisional", "failed") for f in data["findings"]),
           "real: status vocabulary")
        # lift finite on higher
        ok(all((c.get("lift") or 0) < 9999 for c in data.get("higher") or []), "real: no lift 9999 in higher")
    else:
        print("test_v225_findings: real correlate.json has no findings yet (re-run correlate full)")
else:
    print("test_v225_findings: no run5 correlate.json (skip real checks)")

print("test_v225_findings: %d checks passed" % N[0])
