"""HARD RULE: included runs must have 100% IdKey restore (no hashed keys left in analysis SV)."""
from __future__ import annotations

import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

from fdump import inclusion  # noqa: E402


class TestUnhashInclusion(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = inclusion.load()
        if not cls.data.get("included") and not cls.data.get("excluded"):
            # rebuild from per-run manifests if the aggregate file is empty/missing
            cls.data = inclusion.build_from_manifests(ROOT)
            inclusion.save(cls.data)

    def test_manifest_present(self):
        self.assertTrue(os.path.exists(inclusion.MANIFEST), "unhash-inclusion.json missing")
        self.assertTrue(self.data.get("included"), "no included runs")

    def test_included_are_100_percent(self):
        for name in self.data["included"]:
            st = self.data["runs"][name]
            self.assertEqual(st.get("status"), "included", name)
            self.assertEqual(st.get("resolvedPct"), 100.0, "%s not 100%%" % name)

    def test_excluded_below_100(self):
        for name in self.data["excluded"]:
            st = self.data["runs"][name]
            self.assertEqual(st.get("status"), "excluded", name)
            pct = st.get("resolvedPct")
            if pct is None:
                continue
            self.assertLess(pct, 100.0, "%s should be <100" % name)

    def test_included_sv_has_no_hashed_keys(self):
        for name in self.data["included"]:
            run_dir = os.path.join(ROOT, "real", name)
            if not os.path.isdir(run_dir):
                continue
            inclusion.assert_no_hashed_keys(run_dir, self.data)

    def test_pre_idkey_runs_included(self):
        for name in ("2026-10-07", "2026-10-07-run2", "2026-10-07-run3", "2026-10-07-run4", "2026-10-08-run5"):
            if name in self.data["runs"]:
                self.assertIn(name, self.data["included"], name)


if __name__ == "__main__":
    unittest.main()
