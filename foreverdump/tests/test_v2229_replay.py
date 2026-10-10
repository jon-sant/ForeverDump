"""v2.2.29 acceptance on replays: runs 19-22's stored ForeverDumpDB through the real AuraPresence in a simulated BG
(tools/fdump/measure_sched.lua, virtual clock at the measured 0.012 ms per call): every candidate covered on every unit,
per-frame cost bounded, wall share within the budget; v2.2.28 (cut at the limit) is the comparison."""
import os
import subprocess
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUNS = ["2026-10-10-run19-bg", "2026-10-10-run20-dungeon", "2026-10-10-run21-world", "2026-10-10-run22-bg"]


def sim(cost="0.012", secs="90", runs=RUNS, env=None):
    svs = [os.path.join("real", r, "sv", "ForeverDump.lua") for r in runs]
    out = subprocess.run(["lua5.1", "tools/fdump/measure_sched.lua", "ForeverDump", cost, secs] + svs, cwd=ROOT,
                         capture_output=True, text=True, env=dict(os.environ, **(env or {})), check=True).stdout
    rows = [ln.split("|") for ln in out.splitlines() if ln.startswith("run") and not ln.startswith("run|")]
    return rows


@unittest.skipUnless(all(os.path.isfile(os.path.join(ROOT, "real", r, "sv", "ForeverDump.lua")) for r in RUNS), "no runs")
class T(unittest.TestCase):
    def test_full_coverage_within_budget(self):
        for env in ({}, {"NOLIB": "1"}):
            for r in sim(env=env):
                run, cand, checked, cover, mean, mx, wall = r[0], int(r[2]), int(r[3]), float(r[4]), float(r[5]), float(r[6]), float(r[7])
                self.assertEqual(checked, cand, "%s: every candidate listed" % run)
                self.assertEqual(cover, 100.0, "%s %s: (unit, id) coverage" % (run, env))
                self.assertLessEqual(mx, 1.5 + 0.2, "%s: worst frame %.3f ms" % (run, mx))
                self.assertLessEqual(wall, 5.0, "%s: wall share %.2f %%" % (run, wall))


class Guide(unittest.TestCase):
    def test_arena_split_by_hostility(self):
        import sys
        sys.path.insert(0, os.path.join(ROOT, "tools"))
        from fdump.master_guide import probe_families
        self.assertEqual(probe_families("arena:friendly-player", "pvp"), {"friendly"})
        self.assertEqual(probe_families("arena:hostile-player", "pvp"), {"enemy-player"})
        self.assertEqual(probe_families("arena", "pvp"), {"enemy-player"})


if __name__ == "__main__":
    unittest.main()
