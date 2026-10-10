import os as _wos  # portable root (handoff): WOWDEV_ROOT or the nearest parent dir holding foreverdump/
def _wowdev_root():
    r = _wos.environ.get("WOWDEV_ROOT")
    if r:
        return r
    d = _wos.path.dirname(_wos.path.abspath(__file__))
    while d != _wos.path.dirname(d) and not _wos.path.isdir(_wos.path.join(d, "foreverdump")):
        d = _wos.path.dirname(d)
    return d
_WROOT = _wowdev_root()
"""Time audit 2026-10-10: every epoch <-> log-time / date converter must give the same answer whatever zone the box runs
in. The runner executes this file once per zone in runner.TZS. Expected values come from calendar.timegm (zone-free).
Covers: combatlog.to_epoch, refdata._t/log_seconds/log_utc_offset, aurapresence.epoch_to_logsec/anchor_pair,
classderive.day_seconds, clientlog._epoch/parse (year rollover), timefmt.clock, KTH logtruth.parse_ts;
month / year / midnight (run 17 23:52 -> 00:13) rollovers."""
import calendar
import os
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
sys.path.insert(0, _WROOT + "/kth/tools")
from fdump import aurapresence, classderive, clientlog, combatlog, refdata, timefmt  # noqa: E402

UTC = calendar.timegm


def utc(y, mo, d, h, mi, s, frac=0.0, off_h=-4):
    """epoch of a client wall clock in zone off_h"""
    return UTC((y, mo, d, h, mi, s, 0, 0, 0)) - off_h * 3600 + frac


class Converters(unittest.TestCase):
    def test_combatlog_to_epoch(self):
        m = combatlog.LINE.match("10/10/2026 11:38:13.243-4  SPELL_CAST_SUCCESS,x")
        self.assertAlmostEqual(combatlog.to_epoch(m, 2026, None), utc(2026, 10, 10, 11, 38, 13, 0.243), places=3)
        m = combatlog.LINE.match("10/10/2026 11:38:13.243  SPELL_CAST_SUCCESS,x")   # no suffix: explicit offset wins
        self.assertAlmostEqual(combatlog.to_epoch(m, 2026, -4 * 3600), utc(2026, 10, 10, 11, 38, 13, 0.243), places=3)

    def test_combatlog_midnight_and_dst(self):
        a = combatlog.to_epoch(combatlog.LINE.match("10/9/2026 23:59:59.900-4  X"), 2026, None)
        b = combatlog.to_epoch(combatlog.LINE.match("10/10/2026 00:00:00.100-4  X"), 2026, None)
        self.assertAlmostEqual(b - a, 0.2, places=3)
        a = combatlog.to_epoch(combatlog.LINE.match("11/1/2026 01:59:59.000-4  X"), 2026, None)   # EDT -> EST
        b = combatlog.to_epoch(combatlog.LINE.match("11/1/2026 01:00:00.000-5  X"), 2026, None)
        self.assertAlmostEqual(b - a, 1.0, places=3)

    def test_kth_parse_ts(self):
        import logtruth
        self.assertAlmostEqual(logtruth.parse_ts("10/10/2026 11:38:13.243-4"), utc(2026, 10, 10, 11, 38, 13, 0.243), places=3)
        self.assertAlmostEqual(logtruth.parse_ts("10/10/2026 00:00:00.100-4") - logtruth.parse_ts("10/9/2026 23:59:59.900-4"),
                               0.2, places=3)
        self.assertAlmostEqual(logtruth.parse_ts("11/1/2026 01:00:00.000-5") - logtruth.parse_ts("11/1/2026 01:59:59.000-4"),
                               1.0, places=3)
        self.assertAlmostEqual(logtruth.parse_ts("1/1/2027 00:00:00.000-4") - logtruth.parse_ts("12/31/2026 23:59:59.000-4"),
                               1.0, places=3)

    def test_refdata_rollovers(self):
        t = lambda s: refdata._t(s)  # noqa: E731
        self.assertAlmostEqual(t("10/10/2026 00:00:00.100-4") - t("10/9/2026 23:59:59.900-4"), 0.2, places=3)
        self.assertAlmostEqual(t("11/1/2026 00:00:00.500-4") - t("10/31/2026 23:59:59.500-4"), 1.0, places=3)
        self.assertAlmostEqual(t("1/1/2027 00:00:00.000-4") - t("12/31/2026 23:59:59.000-4"), 1.0, places=3)
        self.assertAlmostEqual(t("10/10/2026 11:38:13.25-4") % 1, 0.25, places=6)   # fraction of any width

    def test_log_utc_offset(self):
        with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as f:
            f.write("10/10/2026 11:38:13.243-4  COMBAT_LOG_VERSION,22\n")
        try:
            self.assertEqual(refdata.log_utc_offset(f.name), -4.0)
        finally:
            os.unlink(f.name)

    def test_epoch_to_logsec_matches_log(self):
        for wall in [(2026, 10, 10, 11, 38, 13), (2026, 10, 9, 23, 59, 59), (2026, 10, 31, 23, 59, 59), (2026, 12, 31, 23, 59, 59)]:
            e = utc(*wall, frac=0.5)
            ts = "%d/%d/%d %02d:%02d:%02d.500-4" % (wall[1], wall[2], wall[0], wall[3], wall[4], wall[5])
            self.assertAlmostEqual(aurapresence.epoch_to_logsec(e, -4.0), refdata._t(ts), places=3)

    def test_anchor_pair_prefers_tick(self):
        self.assertEqual(aurapresence.anchor_pair({"gameTime": 10.0, "epoch": 100}), (10.0, 100))
        self.assertEqual(aurapresence.anchor_pair({"gameTime": 10.0, "epoch": 100, "gameTimeTick": 10.4, "epochTick": 101}),
                         (10.4, 101))

    def test_classderive_day_seconds(self):
        self.assertEqual(classderive.day_seconds("2026-10-10 00:00:01") - classderive.day_seconds("2026-10-09 23:59:59"), 2)
        self.assertEqual(classderive.day_seconds("2026-11-01 00:00:00") - classderive.day_seconds("2026-10-31 23:59:59"), 1)
        # an SV anchor date (client wall clock) and the same wall clock in the log are the same number
        self.assertAlmostEqual(classderive.day_seconds("2026-10-10 11:38:13"), refdata._t("10/10/2026 11:38:13.000-4"), places=3)

    def test_clientlog(self):
        import datetime
        ts = datetime.datetime(2026, 10, 10, 11, 38, 13, 243000)
        self.assertAlmostEqual(clientlog._epoch(ts, -4 * 3600), utc(2026, 10, 10, 11, 38, 13, 0.243), places=3)
        self.assertEqual(clientlog._clock(utc(2026, 10, 10, 11, 38, 13), -4 * 3600), "11:38:13")
        with tempfile.NamedTemporaryFile("w", suffix=".log", delete=False) as f:
            f.write("12/31 23:59:59.000  [E][Lua] a\n1/1 00:00:01.000  [E][Lua] b\n")
        try:
            e = clientlog.parse(f.name, year=2026, utc_offset_sec=-4 * 3600)
        finally:
            os.unlink(f.name)
        self.assertAlmostEqual(e[1]["epoch"] - e[0]["epoch"], 2.0, places=3)   # New Year rollover
        self.assertTrue(e[1]["time"].startswith("2027-01-01"))
        dump = {"ForeverDumpRecordDB": {"sessions": [{"anchor": {"utcOffset": -14400, "date": "2026-10-10 11:38:13"}}]}}
        self.assertEqual(clientlog.anchor_year(dump), 2026)

    def test_timefmt_client_zone(self):
        raw = {"ForeverDumpRecordDB": {"sessions": [{"anchor": {"utcOffset": -14400}}]}}
        self.assertEqual(timefmt.dump_offset(raw), -14400)
        self.assertEqual(timefmt.clock(utc(2026, 10, 10, 11, 38, 13), off=-14400), "11:38:13")
        self.assertEqual(timefmt.clock(utc(2026, 10, 10, 11, 38, 13), off=19800), "21:08:13")


class DST(unittest.TestCase):
    """v2.2.26: a capture spanning the US DST change (2026-11-01 02:00 EDT -> 01:00 EST; 2026-03-08 02:00 EST -> 03:00 EDT)"""

    def _log(self, rows):
        f = tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False)
        f.write("".join("%s  SPELL_CAST_SUCCESS,x\n" % r for r in rows))
        f.close()
        try:
            return [t for t, _p in refdata.lines(f.name)], refdata.log_utc_offset(f.name)
        finally:
            os.unlink(f.name)

    def test_refdata_lines_fall_back(self):
        ts, off = self._log(["11/1/2026 01:59:59.000-4", "11/1/2026 01:00:01.000-5", "11/1/2026 01:30:00.000-5"])
        self.assertEqual(off, -4.0)
        self.assertAlmostEqual(ts[1] - ts[0], 2.0, places=3)
        self.assertAlmostEqual(ts[2] - ts[1], 1799.0, places=3)
        # the SV epoch of the post-switch row maps onto the same continuous log seconds
        self.assertAlmostEqual(aurapresence.epoch_to_logsec(utc(2026, 11, 1, 1, 0, 1, off_h=-5), off), ts[1], places=3)

    def test_refdata_lines_spring_forward(self):
        ts, off = self._log(["3/8/2026 01:59:59.000-5", "3/8/2026 03:00:01.000-4"])
        self.assertAlmostEqual(ts[1] - ts[0], 2.0, places=3)
        self.assertAlmostEqual(aurapresence.epoch_to_logsec(utc(2026, 3, 8, 3, 0, 1, off_h=-4), off), ts[1], places=3)

    def test_epoch_parsers_across_dst(self):
        import logtruth
        a, b = "11/1/2026 01:59:59.000-4", "11/1/2026 01:00:01.000-5"
        self.assertAlmostEqual(logtruth.parse_ts(b) - logtruth.parse_ts(a), 2.0, places=3)
        ea = combatlog.to_epoch(combatlog.LINE.match(a + "  X"), 2026, None)
        eb = combatlog.to_epoch(combatlog.LINE.match(b + "  X"), 2026, None)
        self.assertAlmostEqual(eb - ea, 2.0, places=3)

    def _client(self, rows):
        with tempfile.NamedTemporaryFile("w", suffix=".log", delete=False) as f:
            f.write("".join("%s  [E][Lua] m\n" % r for r in rows))
        try:
            return [e["epoch"] for e in clientlog.parse(f.name, year=2026, utc_offset_sec=-4 * 3600)]
        finally:
            os.unlink(f.name)

    def test_clientlog_fall_back(self):
        e = self._client(["11/1 01:59:30.000", "11/1 01:00:10.000", "11/1 01:10:00.000"])
        self.assertAlmostEqual(e[0], utc(2026, 11, 1, 1, 59, 30, off_h=-4), places=3)
        self.assertAlmostEqual(e[1] - e[0], 40.0, places=3)
        self.assertAlmostEqual(e[2] - e[1], 590.0, places=3)

    def test_clientlog_spring_forward(self):
        with tempfile.NamedTemporaryFile("w", suffix=".log", delete=False) as f:
            f.write("3/8 01:59:30.000  [E][Lua] m\n3/8 03:00:10.000  [E][Lua] m\n")
        try:
            e = [x["epoch"] for x in clientlog.parse(f.name, year=2026, utc_offset_sec=-5 * 3600)]
        finally:
            os.unlink(f.name)
        self.assertAlmostEqual(e[1] - e[0], 40.0, places=3)

    def test_clientlog_no_false_dst(self):
        # an ordinary 1 h idle gap or an evening hour must not move the offset
        e = self._client(["10/10 13:00:00.000", "10/10 14:10:00.000", "10/10 01:10:00.000"])
        self.assertAlmostEqual(e[1] - e[0], 4200.0, places=3)


if __name__ == "__main__":
    unittest.main(verbosity=0)
