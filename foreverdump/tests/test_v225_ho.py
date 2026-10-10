"""v2.2.5 higher-order correlation: synthetic chain / identity / find_chains / profiles + markdown."""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from fdump import correlate, correlate_ho  # noqa: E402

N = [0]


def ok(cond, msg):
    N[0] += 1
    if not cond:
        raise SystemExit("FAIL: " + msg)


class StubLive:
    def target_at(self, t):
        return None


def feat(t, keys, ev=None, args=None):
    e = ev if ev is not None else {"e": keys[0].split("|")[0], "a": args or [], "te": t}
    return (t, keys, e)


T0 = 100.0
live_feats = [
    feat(T0, ["UNIT_SPELLCAST_INTERRUPTED|target"], args=["target"]),
    feat(T0, ["UNIT_SPELLCAST_SUCCEEDED|player|arg2=8046"], args=["player", None, 8046]),
    feat(T0 + 0.01, ["DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=5"], args=[5]),
    feat(T0 + 5.0, ["UNIT_SPELLCAST_INTERRUPTED|target"], args=["target"]),
    feat(T0 + 5.0, ["UNIT_SPELLCAST_SUCCEEDED|player|arg2=8046"], args=["player", None, 8046]),
    feat(T0 + 5.01, ["DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=5"], args=[5]),
    feat(T0 + 1.0, ["UNIT_HEALTH|player"], args=["player"]),
]
truth_feats = [
    feat(T0, ["SPELL_INTERRUPT|me>npc|spell=8046"]),
    feat(T0 + 5.0, ["SPELL_INTERRUPT|me>npc|spell=8046"]),
    feat(T0 + 1.5, ["SPELL_DAMAGE|me>npc|spell=8046"]),
    feat(T0 + 3.0, ["SWING_DAMAGE|player>npc"]),
]
span, combat = (0.0, 20.0), [(T0 - 1, T0 + 10)]

rules, rare = correlate.mine(live_feats, truth_feats, span, combat, "live->truth")
rules2, rare2 = correlate.mine(live_feats, live_feats, span, combat, "live->live")
all_rules = rules + rules2
all_rare = (rare or []) + (rare2 or [])

cap = {
    "lf": live_feats, "tf": truth_feats, "live": StubLive(), "truth": truth_feats,
    "span": span, "combat": combat, "label": "synth",
}
ho = correlate_ho.higher_order(cap, all_rules, all_rare, profile="quick")
ok(ho["profile"] == "quick", "HO profile quick")
ok(ho["elapsedSec"] >= 0, "HO elapsedSec present")
ok(isinstance(ho["chains"], list) and ho["chains"], "HO chains non-empty")
ident = [ch for ch in ho["chains"] if ch.get("pattern") == "identity"]
ok(ident, "synthetic identity join mined (INTERRUPTED + SUCCEEDED -> SPELL_INTERRUPT)")
ok(any("INTERRUPT" in "||".join(ch["hops"]) for ch in ident), "identity hops mention INTERRUPT")
ok(any(ch.get("proposedRule") for ch in ident), "proposedRule present on identity chain")
ok(any(ch.get("depth", 0) >= 2 or len(ch.get("hops") or []) >= 3 for ch in ident),
   "identity chain is at least 2-hop")

res = {"higher": ho["chains"], "profile": "quick", "elapsedSec": {"higher": ho["elapsedSec"]}}
found = correlate.find_chains(res, r"INTERRUPTED", r"SUCCEEDED", r"SPELL_INTERRUPT", patterns=("identity", "chain"))
ok(found, "find_chains locates the 2-hop interrupt identity")

cfg_f, cfg_q = correlate_ho.HO_PROFILES["full"], correlate_ho.HO_PROFILES["quick"]
ok(cfg_f["beam"] > cfg_q["beam"] and cfg_f["max_depth"] >= cfg_q["max_depth"], "full beam/depth >= quick")
ok(cfg_f["shuffles"] > cfg_q["shuffles"] and len(cfg_f["windows"]) > len(cfg_q["windows"]), "full more shuffles/windows")
ok(3 <= cfg_f["max_depth"] <= 4, "full depth 3-4")

md = "\n".join(correlate_ho.markdown_higher({"higher": ho["chains"], "profile": "quick"}))
ok("Higher-order leads" in md and "proposed:" in md, "markdown_higher has section + proposed rules")

ia = {
    "UNIT_SPELLCAST_INTERRUPTED|target": [T0, T0 + 5.0],
    "UNIT_SPELLCAST_SUCCEEDED|player|arg2=8046": [T0, T0 + 5.0],
    "SPELL_INTERRUPT|me>npc|spell=8046": [T0, T0 + 5.0],
}
sc = correlate_ho._score_path(
    ["UNIT_SPELLCAST_INTERRUPTED|target", "UNIT_SPELLCAST_SUCCEEDED|player|arg2=8046",
     "SPELL_INTERRUPT|me>npc|spell=8046"],
    [0.05, 0.05], ia, [False, False], 20.0, 8, combat)
ok(sc and sc["support"] == 2 and sc["precision"] == 1.0 and sc["lift"] >= 2.0,
   "score_path: perfect 2-hop, lift>=2")

# elimination: UNIT_COMBAT with no nearby my-cast / DM -> other damage
live_e = [
    feat(10.0, ["UNIT_COMBAT|target|WOUND"], args=["target", "WOUND"]),
    feat(10.5, ["UNIT_SPELLCAST_SUCCEEDED|player|arg2=403"], args=["player", None, 403]),
    feat(10.5, ["DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=1"], args=[1]),
    feat(11.0, ["UNIT_COMBAT|target|WOUND"], args=["target", "WOUND"]),
    feat(12.0, ["UNIT_COMBAT|target|WOUND"], args=["target", "WOUND"]),
]
truth_e = [
    feat(10.5, ["SPELL_DAMAGE|me>npc|spell=403"]),
    feat(11.0, ["SPELL_DAMAGE|player>npc|spell=133"]),
    feat(12.0, ["SWING_DAMAGE|player>npc"]),
]
cap_e = {"lf": live_e, "tf": truth_e, "live": StubLive(), "span": (0.0, 30.0), "combat": [(9.0, 15.0)]}
elim = correlate_ho._elimination(cap_e, correlate_ho.HO_PROFILES["quick"])
ok(isinstance(elim, list), "elimination returns list")
ok(any(ch.get("pattern") == "elimination" for ch in elim), "elimination finds no-my-cast hit -> other damage")

held = correlate_ho.holdout_chain(
    {"hops": ["UNIT_SPELLCAST_INTERRUPTED|target", "SPELL_INTERRUPT|me>npc|spell=8046"],
     "windows": [0.05], "pattern": "chain", "precision": 1.0},
    {"lf": [], "tf": [], "span": (0, 1), "combat": []})
ok(held["status"] == "absent", "holdout absent when hops missing")

held2 = correlate_ho.holdout_chain(
    {"hops": ["ELIM(no my-cast, no DM):UNIT_COMBAT|target", "SWING_DAMAGE|player>npc"],
     "windows": [0.15], "pattern": "elimination", "precision": 1.0},
    cap_e)
ok(held2["status"] == "absent" and held2.get("reason") == "synthetic-key",
   "holdout marks synthetic ELIM keys absent")

ok(callable(correlate.run) and "profile" in correlate.run.__code__.co_varnames, "correlate.run accepts profile")
ok("higher" in correlate.run.__code__.co_varnames, "correlate.run accepts higher")

print("test_v225_ho: %d checks passed" % N[0])
