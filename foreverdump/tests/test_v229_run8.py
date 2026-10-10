"""v2.2.9 permanent regressions from run 8 (battleground, 2026-10-08).

* correlate crashed on BG event payloads whose table args mix integer and string keys (UPDATE_UI_WIDGET-style
  {1: .., "widgetID": ..}): `sorted(v.keys())` raised TypeError and aborted `fdump.py analyze`.
* v2.2.8 docs: the end-of-capture procedure (errors show + screenshot BEFORE OFF; OFF reloads, no separate /reload).
* diag is the default FD_Logs capture level (v2.2.10: diag gated on in-game cost, test keeps the 26 MB size gate).
"""
import os
import sys
import types
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from fdump import analysis, correlate, correlate_findings, coverage, damagemeter_join  # noqa: E402

MIXED = {1: {"widgetID": 7469}, "widgetType": 4, 2: "x", "widgetSetID": 249}


def live_with_mixed():
    ev = [{"e": "UPDATE_UI_WIDGET", "te": 1.0 + i, "a": [MIXED, i]} for i in range(3)]
    ev.append({"e": "UNIT_HEALTH", "te": 5.0, "a": ["party1"]})
    return types.SimpleNamespace(events=ev, record=[])


class MixedKeys(unittest.TestCase):
    def test_live_features_mixed_keys(self):
        feats = correlate.live_features(live_with_mixed())
        keys = [k for _, ks, _ in feats for k in ks]
        self.assertTrue(any("arg" in k and ".has=" in k for k in keys), keys[:8])

    def test_findings_alias_mixed_keys(self):
        # must not raise on a dict payload with mixed keys
        correlate_findings.discover_aliases(types.SimpleNamespace(
            events=[{"e": "UNIT_AURA", "te": 1.0, "a": ["party1", MIXED]}, {"e": "UNIT_AURA", "te": 1.0, "a": ["player", MIXED]}],
            record=[]), "Player-0-00000000")


class Docs(unittest.TestCase):
    def test_end_of_capture_procedure(self):
        s = open(os.path.join(ROOT, "ADDON-USAGE.md"), encoding="utf-8").read()
        i, j = s.find("Ending a capture"), s.find("Click FD_Logs (OFF)")
        self.assertTrue(0 < i < s.find("/fdump errors show", i) < j, "errors show + screenshot must come BEFORE the OFF click")
        self.assertIn("Don't\n     type a separate `/reload`", s)

    def test_off_macro_reloads(self):
        src = open(os.path.join(ROOT, "ForeverDump", "Logs.lua"), encoding="utf-8").read()
        self.assertIn('if not target and cfg().autoReload then lines[#lines + 1] = "/reload" end', src)
        core = open(os.path.join(ROOT, "ForeverDump", "Core.lua"), encoding="utf-8").read()
        self.assertIn("autoReload = true", core)


class DiagDefault(unittest.TestCase):
    def test_runner_gates_diag(self):
        # v2.2.11: run_converter_tests.sh runs tests/runner.py; the gates must be in the runner's commands (what runs)
        # and in the serial reference list
        import sys
        sys.path.insert(0, os.path.join(ROOT, "tests"))
        import runner
        sh = " ".join(t[2] for t in runner.TESTS)
        serial = open(os.path.join(ROOT, "tests", "run_converter_tests_serial.sh"), encoding="utf-8").read()
        for gate in ("sv_serialize_bench.lua diag", "sv_serialize_bench.lua release"):
            self.assertIn(gate, serial)
        self.assertIn("tests/runner.py", open(os.path.join(ROOT, "tests", "run_converter_tests.sh"), encoding="utf-8").read())
        self.assertIn("sv_serialize_bench.lua diag", sh)
        bench = open(os.path.join(ROOT, "tests", "sv_serialize_bench.lua"), encoding="utf-8").read()
        # v2.2.10 (user decision): diag is no longer size-gated; test keeps the unchanged 26 MB limit, release gets a size
        # gate, and diag is gated on in-game cost by the 30 min real-data BG replay (frame-time limits unchanged)
        self.assertIn('level == "test" and mb > 26', bench)
        self.assertIn('level == "release" and mb > 4', bench)
        self.assertIn("sv_serialize_bench.lua release", sh)
        self.assertIn("python3 tests/bg_replay_gate.py", sh)
        gate = open(os.path.join(ROOT, "tests", "bg_replay.lua"), encoding="utf-8").read()
        for needle in ("res.impactPct <= 10", "res.lastImpactPct <= 1.5 * res.firstImpactPct", "not res.ceilingHit"):
            self.assertIn(needle, gate)
        perf = open(os.path.join(ROOT, "tests", "perf_bench.lua"), encoding="utf-8").read()
        self.assertIn('CAPTURE_LEVEL == "diag"', perf)


ANCHOR = {"epoch": 1000.0, "gameTime": 50.0}


class DmJoinRun8(unittest.TestCase):
    """run 8: the HSM export kept the last 13 of ~38 BG fights; every uncovered fight got the last dm-reconcile numbers
    (live=1540 taken=1252) and the missing combat log file was reported as log=0."""

    def inf(self):
        return {"anchor": ANCHOR,
                "fights": [{"start": 60.0, "stop": 70.0, "dmg": {"mine": 591}, "taken": {"amount": 0}},
                           {"start": 100.0, "stop": 110.0, "dmg": {"mine": 1540}, "taken": {"amount": 1252}}],
                "inferences": [{"rule": "dm-reconcile", "t": 111.0, "liveMine": 1540, "liveTaken": 1252}]}

    def test_live_by_time(self):
        inf = self.inf()
        self.assertEqual(damagemeter_join._live_by_time(inf, 1010.0, 1020.0)["damage"], 591)
        self.assertEqual(damagemeter_join._live_by_time(inf, 1050.0, 1060.0)["damage"], 1540)
        self.assertEqual(damagemeter_join._live_by_time(inf, 900.0, 905.0), {}, "no overlap -> no live numbers")

    def test_join_uncovered_fights_never_share_numbers(self):
        dump = types.SimpleNamespace(log={"inference": self.inf(), "damageMeter": {"fights": []}})
        fights = [{"n": 1, "start": 900.0, "stop": 905.0, "logCovered": False},
                  {"n": 2, "start": 930.0, "stop": 940.0, "logCovered": False},
                  {"n": 3, "start": 1051.0, "stop": 1059.0, "logCovered": False}]
        res = damagemeter_join.join(dump, {"fights": fights, "damageMeter": {}})
        live = [f["live"]["damage"] for f in res["fights"]]
        self.assertEqual(live, [None, None, 1540])
        for f in res["fights"]:
            self.assertIsNone(f["log"]["damage"], "no combat log file for the fight -> None, never 0")
            self.assertNotEqual(f["metrics"]["damage"]["verdict"], "off")

    def test_fights_truth_marks_uncovered_and_counts_pvp(self):
        me, foe = "Player-1-AAAAAAAA", "Player-2-BBBBBBBB"
        fx = {"events": [{"cleu": True, "t": 10.0, "sub": "SPELL_DAMAGE",
                          "a": [0, 0, 0, me, "", 0, 0, foe, "", 0, 0, 403, "x", 0, 50]}]}
        live = types.SimpleNamespace(combat=[(9.0, 11.0), (500.0, 520.0)])
        cls = lambda g: "me" if g == me else ("player" if str(g).startswith("Player-") else "npc")  # noqa: E731
        orig = coverage._cats
        coverage._cats = lambda e: [("damage", {"amount": 50})]
        try:
            out = coverage.fights_truth(fx, live, cls, me)
        finally:
            coverage._cats = orig
        self.assertTrue(out[0]["logCovered"])
        self.assertEqual(out[0]["mineDamage"], 50, "damage to a hostile player counts in a battleground")
        self.assertFalse(out[1]["logCovered"])


class TrailingToggle(unittest.TestCase):
    def test_main_session_skips_short_trailing(self):
        long_s = {"captureSid": "cap-A", "startTime": 0.0, "stopTime": 1300.0, "combatEvents": 14000}
        short_s = {"captureSid": "cap-B", "startTime": 1400.0, "stopTime": 1403.8, "combatEvents": 0, "cleuTotal": 0}
        ms, skipped = coverage.main_session([long_s, short_s])
        self.assertIs(ms, long_s)
        self.assertEqual([x["captureSid"] for x in skipped], ["cap-B"])
        ms, skipped = coverage.main_session([long_s])
        self.assertIs(ms, long_s)
        self.assertEqual(skipped, [])

    def test_earlier_capture_errors_are_info(self):
        ctx = {"engineHealth": {"latest": "cap-20261008194049-33", "captureErrors": [
            {"sid": "cap-20261008183032-9", "where": "capture:x", "err": "os"},
            {"sid": "cap-20261008194049-33", "where": "capture:y", "err": "boom"}], "down": [],
            "skippedTrailing": [{"sid": "cap-20261008200300-40", "sec": 3.8}]}}
        L = analysis.leads(ctx)
        sev = {(x["kind"], x["title"].split(":")[0]): x["severity"] for x in L}
        self.assertEqual(sev[("capture module failed (earlier capture)", "capture")], "info")
        self.assertEqual(sev[("capture module failed", "capture")], "high")
        self.assertTrue(any(x["kind"] == "short trailing capture skipped" for x in L))


class TaintChatRun8(unittest.TestCase):
    def test_messageinfo_fading_is_benign_chat_but_real_frames_stay(self):
        import tempfile
        from fdump import taintlog
        with tempfile.NamedTemporaryFile("w", suffix=".log", delete=False) as f:
            f.write("""10/8 19:42:44.551  Execution tainted by ForeverDump while reading field messageInfo (<table: 01>) - Interface/AddOns/Blizzard_SharedXML/ScrollingMessageFrame.lua:778 ChatFrame1:UpdateFading()
10/8 19:42:44.551      Interface/AddOns/Blizzard_SharedXML/ScrollingMessageFrame.lua:778 ChatFrame1:UpdateFading()
10/8 19:42:54.000  Execution tainted by ForeverDump while reading field shown (<table: 03>) - Interface/AddOns/Blizzard_UnitFrame/PlayerFrame.lua:10
10/8 19:42:54.000      Interface/AddOns/Blizzard_UnitFrame/PlayerFrame.lua:10 PlayerFrame_Update()
""")
        by = taintlog.parse(f.name)["summary"]["byClass"]
        os.unlink(f.name)
        self.assertEqual(by, {"benign-chat": 1, "blizzard-frame": 1})


if __name__ == "__main__":
    unittest.main()
