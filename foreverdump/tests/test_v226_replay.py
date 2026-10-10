"""v2.2.6 sealed replay tape + offline fdump replay (synthetic)."""
import json
import os
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

from fdump import replay as replaymod  # noqa: E402


class FakeDump:
    def __init__(self, log):
        self.log = log


def _sess(**kw):
    tape = {
        1: {"k": "hdr", "i": 1, "d": 0, "verbosity": "test"},
        2: {"k": "decide", "i": 2, "d": 10, "r": 1, "b": 1, "c": 3, "kind": "cast", "sp": 8042},
        3: {"k": "decide", "i": 3, "d": 20, "r": 1, "b": 1, "c": 3, "kind": "cast", "sp": 8042},
        4: {"k": "anchor", "i": 4, "d": 100, "spell": 8042, "n": 1},
        5: {"k": "verdict", "i": 5, "d": 110, "kind": "cast", "v": "ok", "sp": 8042},
        6: {"k": "sec", "i": 6, "d": 120, "e": "UNIT_SPELLCAST_SUCCEEDED", "n": 2, "p": 4},
        7: {"k": "map", "i": 7, "d": 130, "tok": "nameplateN", "id": "npc:123", "how": "live"},
    }
    base = {
        "hdr": {
            "v": 1, "addonVersion": "2.2.6", "schemaVersion": 3, "verbosity": "test",
            "verbosityEnd": "release", "groupType": "solo", "groupSize": 1,
            "seeds": {"spellTiming": "st:deadbeef"}, "t0": 100.0,
            "anchor": {"getTime": 100.0, "epoch": 1_700_000_000.0},
        },
        "tape": tape, "n": 7, "overwritten": 0, "overflow": 0, "bytes": 900,
        "anchors": [{"i": 4, "spell": 8042, "d": 100}],
        "rules": {1: "own-cast-frame"},
        "ringOverflow": {}, "dropped": {},
    }
    base.update(kw)
    return base


class TestReplayOffline(unittest.TestCase):
    def test_reconstruct_order(self):
        s = _sess()
        tape = replaymod.reconstruct_tape(s)
        self.assertEqual([r["i"] for r in tape], [1, 2, 3, 4, 5, 6, 7])

    def test_decide_determinism_ok(self):
        s = _sess()
        det = replaymod.decide_determinism(replaymod.reconstruct_tape(s), s["rules"])
        self.assertTrue(det["ok"])
        self.assertEqual(det["groups"], 1)

    def test_decide_conflict(self):
        s = _sess()
        s["tape"][3]["c"] = 1  # same r,b different conf
        det = replaymod.decide_determinism(replaymod.reconstruct_tape(s), s["rules"])
        self.assertFalse(det["ok"])
        self.assertEqual(len(det["conflicts"]), 1)

    def test_raw_guid_kept_and_counted(self):
        # v2.2.21: raw GUIDs are stored on purpose; reconstruct_tape keeps them byte-identical and the scan counts them
        s = _sess()
        s["tape"][7]["id"] = "player:Player-1-0A1B2C3D"
        s["tape"][7]["g"] = "Player-1-0A1B2C3D"
        hits = replaymod.identity_scan(s)
        self.assertGreater(len(hits), 0)
        tape = replaymod.reconstruct_tape(s)
        self.assertIn("Player-1-0A1B2C3D", repr(tape))

    def test_no_identity_in_synthetic(self):
        s = _sess()
        hits = replaymod.identity_scan({"hdr": s["hdr"], "tape": s["tape"], "rules": s["rules"]})
        self.assertEqual(hits, [])

    def test_anchor_join_cleu(self):
        s = _sess()
        # epoch = 1_700_000_000 + (100 - 100) = t0_epoch; cast at t0_epoch + 0.100
        t0_epoch = 1_700_000_000.0
        fx = {"events": [
            {"cleu": True, "sub": "SPELL_CAST_SUCCESS",
             "a": [t0_epoch + 0.100, None, None, "Player-1-X", "X", 0x511, 0, None, None, None, None, 8042, "Earth Shock"]},
        ]}
        res = replaymod.analyze_session(s, fx=fx)
        self.assertEqual(res["anchorJoin"]["matched"], 1)
        self.assertEqual(res["rawIdentities"], 0)
        self.assertTrue(res["decide"]["ok"])

    def test_write_empty_sv(self):
        d = FakeDump({})
        with tempfile.TemporaryDirectory() as td:
            res = replaymod.write(d, td)
            self.assertEqual(res["sessionCount"], 0)
            self.assertTrue(os.path.isfile(os.path.join(td, "REPLAY.md")))
            self.assertTrue(os.path.isfile(os.path.join(td, "replay.json")))

    def test_write_session(self):
        d = FakeDump({"replay": {"v": 1, "sessions": [_sess()]}})
        with tempfile.TemporaryDirectory() as td:
            res = replaymod.write(d, td)
            self.assertEqual(res["sessionCount"], 1)
            self.assertTrue(res["summary"]["ok"])
            md = open(os.path.join(td, "REPLAY.md"), encoding="utf-8").read()
            self.assertIn("sealed replay", md.lower())
            self.assertIn("test", md)


class TestReplayLogLua(unittest.TestCase):
    def test_replaylog_has_api(self):
        src = open(os.path.join(ROOT, "ForeverDump", "ReplayLog.lua"), encoding="utf-8").read()
        for name in ("BeginCapture", "EndCapture", "SetLevel", "OnInfer", "OnVerdict",
                     "OnOwnSucceeded", "OnCriticalEvent", "OnApiSample", "OnMapDelta",
                     "IdKey", "StatusLine", "Command", "VerifyCap", "IsTest", "SyncFromConfig"):
            self.assertIn("function R.%s" % name, src)
        self.assertIn('level = "release"', src)
        self.assertIn("captureLevel", src)
        self.assertIn("FD_Logs", src)

    def test_toc_order(self):
        toc = open(os.path.join(ROOT, "ForeverDump", "ForeverDump.toc"), encoding="utf-8").read()
        self.assertIn("## Version: 2.2.29", toc)   # exact current version (bumped with the release)
        self.assertLess(toc.find("Verify.lua"), toc.find("ReplayLog.lua"))

    def test_commands_level(self):
        src = open(os.path.join(ROOT, "ForeverDump", "Commands.lua"), encoding="utf-8").read()
        self.assertIn('cmd == "level"', src)
        self.assertIn("/fdump level", src)

    def test_core_config_defaults(self):
        src = open(os.path.join(ROOT, "ForeverDump", "Core.lua"), encoding="utf-8").read()
        self.assertIn('level = "release"', src)
        self.assertIn('captureLevel = "lab"', src)   # v2.2.15: FD_Logs ON raises to lab by default (user decision 2026-10-09)


if __name__ == "__main__":
    unittest.main()
