"""v2.2.22 audit (tools side): a "T" container (some fields secret) is never folded into "secret".

- master_guide.readability: T codes -> "mixed" (was _norm_code T -> S -> "secret")
- guidejson: T / HasSecretValues()==true -> "X" (container: per field) with per-field codes in the note (was "S")
- probes._mismatch: a struct-level T is judged per field, not as a "never secret" contradiction
"""
import os
import sys
import unittest
from collections import Counter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from fdump import guidejson, master_guide, probes  # noqa: E402


class T(unittest.TestCase):
    def test_norm_keeps_T(self):
        self.assertEqual(master_guide._norm_code("T"), "T")
        self.assertEqual(master_guide._norm_code("K"), "C")

    def test_readability_T_is_mixed(self):
        v, _ = master_guide.readability({"codes": Counter({"T": 40})})
        self.assertEqual(v, "mixed")
        v, _ = master_guide.readability({"codes": Counter({"C": 10, "T": 30})})
        self.assertEqual(v, "mixed")
        v, _ = master_guide.readability({"codes": Counter({"S": 10})})
        self.assertEqual(v, "secret")

    def test_guidejson_partial(self):
        self.assertEqual(guidejson.CODE["T"], "X")
        self.assertEqual(guidejson._code({"T": 5}), "X")
        self.assertEqual(guidejson._code({"K": 5}, {"true": 5}), "X")
        self.assertEqual(guidejson._code({"S": 5}), "S")

    def test_mismatch_T_not_never(self):
        self.assertFalse(probes._mismatch("T", {"class": "never"}))
        self.assertTrue(probes._mismatch("S", {"class": "never"}))


if __name__ == "__main__":
    unittest.main()
