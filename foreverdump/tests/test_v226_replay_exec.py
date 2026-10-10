"""v2.2.6 sealed-tape re-execution: HybridState offline must exact-match taped decides."""
import json
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

from fdump import replay as replaymod  # noqa: E402

OUT = os.path.join(ROOT, "tests", "out", "replay_tape")
HARNESS = os.path.join(ROOT, "tests", "replay_tape_harness.lua")


def _ensure_tape():
    os.makedirs(OUT, exist_ok=True)
    tape = os.path.join(OUT, "tape.json")
    ev = os.path.join(OUT, "events.lua")
    # always regenerate so shadow/ReplayLog order stays current
    env = os.environ.copy()
    r = subprocess.run(["lua5.1", HARNESS, OUT], cwd=ROOT, capture_output=True, text=True, env=env, timeout=60)
    if r.returncode != 0:
        raise RuntimeError("harness failed: %s\n%s" % (r.stdout, r.stderr))
    assert os.path.isfile(tape) and os.path.isfile(ev), "harness missing outputs"
    return tape, ev


class TestReplayReexec(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tape_path, cls.events_path = _ensure_tape()
        cls.sess = json.load(open(cls.tape_path, encoding="utf-8"))["session"]

    def test_addon_tape_has_decides_and_shadow_verdicts(self):
        taped = replaymod.taped_decides(self.sess)
        self.assertGreaterEqual(len(taped), 5)
        kinds = {r.get("k") for r in replaymod.reconstruct_tape(self.sess)}
        self.assertIn("decide", kinds)
        self.assertIn("verdict", kinds)
        verdicts = [r for r in replaymod.reconstruct_tape(self.sess) if r.get("k") == "verdict"]
        shadow = [v for v in verdicts if str(v.get("kind") or "").startswith("shadow-")]
        self.assertGreaterEqual(len(shadow), 1, "capture-mode shadow findings must land on the tape")

    def test_reexec_exact_match(self):
        res = replaymod.reexec_session(self.sess, self.events_path)
        self.assertTrue(res.get("ok"), res)
        d = res["determinism"]
        self.assertTrue(d["ok"])
        self.assertEqual(d["nTape"], d["nRegen"])
        self.assertEqual(d["mismatches"], [])

    def test_library_self_determinism(self):
        a = replaymod.reexec_hsm(self.events_path)
        b = replaymod.reexec_hsm(self.events_path)
        self.assertNotIn("_error", a)
        m = replaymod.exact_match_decides(
            [{"rule": x["rule"], "kind": x["kind"], "c": x["c"], "id": x["id"]} for x in a["decides"]],
            b["decides"])
        self.assertTrue(m["ok"])

    def test_perturbed_tape_fails(self):
        taped = replaymod.taped_decides(self.sess)
        regen = replaymod.reexec_hsm(self.events_path)["decides"]
        bad = replaymod.perturb_decides(taped)
        m = replaymod.exact_match_decides(bad, regen)
        self.assertFalse(m["ok"])
        self.assertGreaterEqual(len(m["mismatches"]), 1)

    def test_cleu_diff_on_synthetic_log(self):
        """Anchors on tape joined to a synthetic CLEU SUCCESS stream; unmatched must be reported."""
        anchors = self.sess.get("anchors") or []
        if isinstance(anchors, dict):
            anchors = list(anchors.values())
        if not anchors:
            self.skipTest("no anchors on tape")
        # build CLEU matching every anchor spell at epoch offsets
        hdr = self.sess.get("hdr") or {}
        am = hdr.get("anchor") or {}
        t0 = float(hdr.get("t0") or 1000)
        # harness uses GetTime without epoch anchor sometimes — synthesize relative CLEU
        events = []
        for an in anchors:
            sp, d_ms = an.get("spell"), an.get("d")
            if sp is None or d_ms is None:
                continue
            events.append({"cleu": True, "sub": "SPELL_CAST_SUCCESS",
                           "a": [t0 + float(d_ms) / 1000.0, None, None, "Player-1-AABB", "X", 0x511,
                                 0, None, None, None, None, sp, "Spell"]})
        fx = {"events": events}
        # without epoch, join matches by spell only
        join = replaymod.join_anchors_cleu(anchors, fx, t0_epoch=None)
        self.assertEqual(join["matched"], join["anchors"])
        # CLEU diff ok when all anchors matched
        diff = replaymod.cleu_diff(anchors, fx, t0_epoch=None)
        self.assertTrue(diff["ok"])
        # drop one CLEU → still ok for anchors (unmatched CLEU not fatal without epoch);
        # remove one anchor spell from CLEU to leave an unmatched anchor
        if len(events) >= 2:
            fx2 = {"events": events[1:]}
            diff2 = replaymod.cleu_diff(anchors, fx2, t0_epoch=None)
            self.assertGreater(diff2["unmatchedAnchors"], 0)
            self.assertFalse(diff2["ok"])


class TestGoldenStrictRestored(unittest.TestCase):
    """Document before/after of the 2026-10-08 softening and that strict asserts are back."""

    def test_golden_source_has_strict_asserts(self):
        src = open(os.path.join(ROOT, "tests", "test_golden_run5.py"), encoding="utf-8").read()
        self.assertIn('DAMAGE_METER_COMBAT_SESSION_UPDATED\\|arg0=5$', src)
        self.assertIn('ok(dm, "miner: DAMAGE_METER_COMBAT_SESSION_UPDATED(type 5)', src)
        self.assertIn('ok(any(x["kind"].startswith("higher-order") for x in ctx["leads"]), "ANALYSIS leads include higher-order")', src)
        # must NOT keep the softened or-forms as the live assert
        self.assertNotIn('dm or ("meter-frame-join"', src)
        self.assertNotIn('or ho,\n   "ANALYSIS leads include higher-order', src)


if __name__ == "__main__":
    unittest.main()
