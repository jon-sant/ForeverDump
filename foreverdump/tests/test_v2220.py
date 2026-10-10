"""v2.2.20 (run 15 sign-off): log-only combat windows, p10 cast time, BG reminder / autoBG config wiring."""
import os
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from fdump import classderive, refdata  # noqa: E402

ME, EN, FR = "Player-1-0000000A", "Player-1-0000000B", "Player-1-0000000C"


def line(sec, sub, src, sf, dst, df, rest="1,\"S\",0x1"):
    return '10/9/2026 19:00:%06.3f-4  %s,%s,"a",%s,0x0,%s,"b",%s,0x0,%s\n' % (sec, sub, src, sf, dst, df, rest)


class LogWindows(unittest.TestCase):
    def test_windows(self):
        rows = [line(1, "SPELL_AURA_APPLIED", ME, "0x511", FR, "0x512"),     # friendly: no combat
                line(10, "SPELL_DAMAGE", ME, "0x511", EN, "0x548"),           # I hit a hostile
                line(13, "SPELL_DAMAGE", EN, "0x548", ME, "0x511"),           # hostile hits me (3 s later: same)
                line(30, "SPELL_DAMAGE", EN, "0x548", ME, "0x511"),           # new window
                line(40, "SPELL_HEAL", FR, "0x512", FR, "0x512")]
        with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as f:
            f.writelines(rows)
        try:
            wins, span = classderive.log_windows(f.name, ME)
        finally:
            os.unlink(f.name)
        self.assertEqual(len(wins), 2)
        self.assertAlmostEqual(wins[0][1] - wins[0][0], 8.0, places=2)   # 10 -> 13 + 5 s leave
        self.assertAlmostEqual(wins[1][1] - wins[1][0], 5.0, places=2)
        self.assertAlmostEqual(span[1] - span[0], 39.0, places=2)


class CastTimeP10(unittest.TestCase):
    def test_pushback_does_not_lengthen(self):
        rows, t = [], 0.0
        for d in (2.0, 2.0, 2.0, 2.0, 2.5, 3.1, 3.4, 3.9):   # median 2.5 (pushback), planned 2.0
            rows.append(line(t, "SPELL_CAST_START", ME, "0x511", "0000000000000000", "0x80000000", "403,\"Lightning Bolt\",0x8"))
            rows.append(line(t + d, "SPELL_CAST_SUCCESS", ME, "0x511", EN, "0x548", "403,\"Lightning Bolt\",0x8"))
            t += 5
        with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as f:
            f.writelines(rows)
        try:
            ref = refdata.build([f.name])[0]
        finally:
            os.unlink(f.name)
        e = ref["spells"].get(403) or ref["spells"].get("403")
        self.assertIsNotNone(e)
        self.assertEqual(e.get("castTime"), 2.0)


class Wiring(unittest.TestCase):
    def test_config(self):
        core = open(os.path.join(ROOT, "ForeverDump", "Core.lua")).read()
        self.assertIn("autoBG = false", core)       # opt-in, default off
        self.assertIn("bgReminder = true", core)
        cmd = open(os.path.join(ROOT, "ForeverDump", "Commands.lua")).read()
        self.assertIn('["logs.autoBG"] = true', cmd)
        logs = open(os.path.join(ROOT, "ForeverDump", "Logs.lua")).read()
        self.assertIn("function Logs.OnEnterWorld()", logs)


if __name__ == "__main__":
    unittest.main()
