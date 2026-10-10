"""v2.2.19: offline pre-fill scorer helpers + derivation inventory (ooc cache paths) + module wiring."""
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from fdump import oocfill_score, derivation  # noqa: E402


class Windows(unittest.TestCase):
    def test_pairs(self):
        rows = [{"e": "PLAYER_REGEN_DISABLED", "t": 10}, {"e": "X", "t": 11}, {"e": "PLAYER_REGEN_ENABLED", "t": 20},
                {"e": "PLAYER_REGEN_ENABLED", "t": 21}, {"e": "PLAYER_REGEN_DISABLED", "t": 30},
                {"e": "PLAYER_REGEN_DISABLED", "t": 31}, {"e": "PLAYER_REGEN_ENABLED", "t": 40}]
        self.assertEqual(oocfill_score._windows(rows, 100), [(110, 120), (130, 140)])


class Inventory(unittest.TestCase):
    def test_ooc_paths(self):
        self.assertTrue(derivation.DERIVE["class"]["path"].startswith("ooc cache:"))
        self.assertTrue(derivation.DERIVE["healthMax"]["path"].startswith("ooc cache:"))
        ids = [x[0] for x in derivation.EXTRA]
        self.assertIn("target-chains", ids)
        self.assertIn("prefill", ids)
        for _, _, e in derivation.EXTRA:
            self.assertIn(e["status"], derivation.DERIVE_STATUSES)


class Wiring(unittest.TestCase):
    def test_toc_and_lint(self):
        toc = open(os.path.join(ROOT, "ForeverDump", "ForeverDump.toc")).read().splitlines()
        self.assertLess(toc.index("Lib\\UnitCache.lua"), toc.index("OocFill.lua"))
        self.assertLess(toc.index("Derive.lua"), toc.index("OocFill.lua"))
        lint = open(os.path.join(ROOT, "tests", "test_v227_secret_lint.py")).read()
        self.assertIn('"OocFill.lua"', lint)
        src = open(os.path.join(ROOT, "ForeverDump", "OocFill.lua")).read()
        for bad in ("AddMessage", "print(", "DEFAULT_CHAT_FRAME", "CheckInteractDistance", "hooksecurefunc"):
            self.assertNotIn(bad, src)


if __name__ == "__main__":
    unittest.main()
