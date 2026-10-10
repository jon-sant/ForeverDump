"""v2.2.23: run-17 scoring helpers (runscore bfJoin rule, derivation MEASURED rows, GBS layout)."""
import os, sys, unittest
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from fdump import runscore, derivation  # noqa: E402


class T(unittest.TestCase):
    def test_bfjoin_rule(self):
        board = {
            "Rei Sky": {"first": "Rei", "class": "WARRIOR", "faction": 1},
            "Johnny A": {"first": "Johnny", "class": "ROGUE", "faction": 1},
            "Johnny B": {"first": "Johnny", "class": "SHAMAN", "faction": 0},
            "Ann X": {"first": "Ann", "class": "MAGE", "faction": 1},
            "Ann Y": {"first": "Ann", "class": "PRIEST", "faction": 1},
        }
        plates = {"Rei": {"enemy": True}, "Johnny": {"enemy": True}}
        tr = {"g1": {"first": "Rei", "hostile": True, "cls": "WARRIOR"},
              "g2": {"first": "Johnny", "hostile": True, "cls": "ROGUE"},
              "g3": {"first": "Johnny", "hostile": False, "cls": "SHAMAN"}}
        res, false = runscore.bfjoin_v2222(board, plates, 0, tr)
        self.assertEqual(res["unique"], 1)
        self.assertEqual(res["crossFac"], 1)          # enemy Johnny (plate hostility known)
        self.assertEqual(res["pendingCrossFac"], 1)   # friendly Johnny: no friendly plate
        self.assertEqual(res["dupFac"], 2)            # two Ann on one team: never assigned
        self.assertEqual(res["false"], 0)
        self.assertEqual(false, [])

    def test_measured_rows(self):
        for rid in derivation.MEASURED:
            row = derivation.DERIVE.get(rid) or next((e for k, _l, e in derivation.EXTRA if k == rid), None)
            self.assertIsNotNone(row, rid)
            self.assertNotIn("remeasure", row, rid)
            self.assertTrue(row["estimate"].startswith("MEASURED run 1"), rid)
        for rid in derivation.STILL_REMEASURE:
            row = derivation.DERIVE.get(rid) or next((e for k, _l, e in derivation.EXTRA if k == rid), None)
            self.assertIn("remeasure", row, rid)
        self.assertEqual(set(derivation.MEASURED) | set(derivation.STILL_REMEASURE), set(derivation.REMEASURE))

    def test_gbs_layout(self):
        with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ForeverDump", "Derive.lua")) as f:
            src = f.read()
        self.assertNotIn('"honorGained", "faction", "rank"', src)
        self.assertIn("clearStr(r[8])", src)                 # race = pos 7
        self.assertIn("classFromLocalized(r[10])", src)      # classToken = pos 9
        self.assertNotIn("clearStr(r[11])", src)             # pos 10 = damage, never the class


if __name__ == "__main__":
    r = unittest.main(exit=False, verbosity=0).result
    print("OK" if r.wasSuccessful() else "FAIL")
    sys.exit(0 if r.wasSuccessful() else 1)
