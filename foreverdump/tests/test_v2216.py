"""v2.2.16 analyzer regressions (synthetic data only, no names / GUIDs from a real capture).

1. session_join: a BG meter record is the cumulative SESSION; it is compared with the SUM of the log fights inside
   [te - dur, te] (run 13: per-fight join compared a 1-18 s fight with a 38-159 s meter session).
2. damagemeter_join compares the meter once per session (last fight) against summed log totals.
3. verify_live: a cast failure "You are dead" (or stunned / out of range) is not a cooldown refutation; shadow P
   verdicts are counted in the VERIFY table.
4. score_cooldowns: precondition failures are "precondition", not contradicts / inside-other-reason.
5. candscore false-self gate: a rule may not raise false-self claims on any run, nor lose accuracy beyond noise.
6. selflink seed: Data/SelfLinkSeed.lua and its JSON mirror agree; spell IDs and counts only.
"""
from __future__ import annotations

import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "tools"))

from fdump import candscore, coverage, selflink, verify_live  # noqa: E402


def fight(n, start, stop, mine):
    return {"n": n, "start": start, "stop": stop, "dur": stop - start, "mineDamage": mine, "otherOnTargets": 10,
            "takenDamage": 5, "healEffective": 1, "interruptsMine": 0}


class SessionJoin(unittest.TestCase):
    def test_sum_inside_window(self):
        fights = [fight(1, 100, 110, 300), fight(2, 120, 130, 200), fight(3, 300, 310, 50)]
        recs = [{"te": 131, "dur": 31, "damage": 500, "source": "DamageMeter.lua"}, {"te": 311, "dur": 11, "damage": 50}]
        rows = coverage.session_join(fights, recs)
        r12 = next(r for r in rows if r["fights"] == [1, 2])
        self.assertEqual(r12["logMine"], 500)
        self.assertEqual(r12["dmMine"], 500)
        self.assertEqual(r12["fight"], "1+2")
        r3 = next(r for r in rows if r["fights"] == [3])
        self.assertEqual((r3["logMine"], r3["dmMine"]), (50, 50))

    def test_partial_and_unmatched(self):
        fights = [fight(1, 80, 125, 300), fight(2, 200, 210, 7)]
        rows = coverage.session_join(fights, [{"te": 126, "dur": 20, "damage": 100}])
        self.assertTrue(rows[0]["partial"])
        self.assertEqual(rows[1]["window"], "none")
        self.assertIsNone(rows[1]["dmMine"])


class VerifyDead(unittest.TestCase):
    def test_precondition_is_not_refutation(self):
        self.assertTrue(verify_live._PRECOND.search("You are dead"))
        self.assertTrue(coverage._PRECOND_RE.search("You are dead"))
        # never loosened beyond death: range / stun reasons stay real cooldown refutations (test_v224_tools)
        for reason in ("Not yet recovered", "Out of range", "Can't do that while stunned"):
            self.assertIsNone(verify_live._PRECOND.search(reason), reason)

    def test_score_cooldowns_precondition(self):
        me = "P-me"
        a = ["x"] * 12
        a[3], a[11] = me, 2484
        fx = {"events": [{"cleu": True, "sub": "SPELL_CAST_FAILED", "t": 10.0, "a": a + ["You are dead"]}]}
        rep = {"attributions": [{"k": "failed", "spell": 2484, "t": 10.01, "rule": "fail-inside-cd"}], "predictions": []}
        res = coverage.score_cooldowns(rep, fx, me)
        self.assertEqual(res["counts"], {"precondition": 1})
        self.assertEqual(res["fails"][0]["verdict"], "precondition")


class FalseSelfGate(unittest.TestCase):
    def test_gate(self):
        b = {"scorable": 100, "accuracy": 90.0, "falseSelf": 3}
        self.assertFalse(candscore.gate_run(b, {"scorable": 100, "accuracy": 95.0, "falseSelf": 4})[0])
        self.assertFalse(candscore.gate_run(b, {"scorable": 100, "accuracy": 87.0, "falseSelf": 0})[0])
        ok, better, _ = candscore.gate_run(b, {"scorable": 100, "accuracy": 89.0, "falseSelf": 1})
        self.assertTrue(ok and better)

    def test_rule_metrics(self):
        attrs = [{"k": "aura", "ref": "a1", "rule": "own-cast-frame", "src": "mine"},
                 {"k": "aura", "ref": "a2", "rule": "own-cast-frame", "src": "mine"},
                 {"k": "aura", "ref": "a3", "rule": "aura-ambiguous", "src": "none"}]
        truth = {"a1": {"src": "me"}, "a2": {"src": "player"}, "a3": {"src": "me"}}
        m = candscore.rule_metrics(attrs, truth, {})
        self.assertEqual(m["own-cast-frame"]["falseSelf"], 1)
        self.assertEqual(m["own-cast-frame"]["correctMine"], 1)


class SelfLinkSeed(unittest.TestCase):
    def test_lua_matches_json(self):
        js = selflink.load()
        self.assertGreater(len(js), 10)
        lua = open(selflink.LUA_PATH).read()
        rows = dict((int(a), (int(b), int(c))) for a, b, c in re.findall(r"\[(\d+)\] = \{ (\d+), (\d+) \}", lua))
        self.assertEqual(rows, {int(k): (v["casts"], v["hits"]) for k, v in js.items()})
        self.assertNotRegex(lua, r"Player-|Creature-|\"[A-Z][a-z]+-[A-Z]")
        ev = selflink.stream_events(5.0)
        self.assertTrue(all(e["k"] == "linkseed" and e["t"] == 5.0 for e in ev))


if __name__ == "__main__":
    unittest.main(verbosity=1)
