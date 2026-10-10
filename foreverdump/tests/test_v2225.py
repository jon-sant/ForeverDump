"""v2.2.25: aura-presence offline scorer (synthetic), env-aware guide ctx, wiring."""
import os
import sys
import tempfile
import time
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
from tools.fdump import aurapresence as ap  # noqa: E402
from tools.fdump import master_guide as mg  # noqa: E402
from tools.fdump import refdata  # noqa: E402

def read(*parts):
    with open(os.path.join(ROOT, *parts)) as f:
        return f.read()


G1, G2 = "Player-1-0000000A", "Player-1-0000000B"


def ts(epoch):
    lt = time.gmtime(epoch - 4 * 3600)   # time audit: the stamp says -4, so render it in -4 (was the box zone)
    return "%d/%d/%d %02d:%02d:%02d.%03d-4" % (lt.tm_mon, lt.tm_mday, lt.tm_year, lt.tm_hour, lt.tm_min, lt.tm_sec,
                                              int(round((epoch - int(epoch)) * 1000)))


def ev(epoch, name, dst, sid):
    return '%s  %s,Player-1-0000000C,"Src-R-",0x548,0x0,%s,"Dst-R-",0x548,0x0,%d,"Rejuvenation",0x8,BUFF\n' % (
        ts(epoch), name, dst, sid)


class Scorer(unittest.TestCase):
    def setUp(self):
        self.e0 = 1791000000.0   # anchor epoch
        lines = [ev(self.e0 + 10, "SPELL_AURA_APPLIED", G1, 774), ev(self.e0 + 25, "SPELL_AURA_REMOVED", G1, 774),
                 ev(self.e0 + 30, "SPELL_AURA_APPLIED", G2, 139)]
        fd, self.path = tempfile.mkstemp(suffix=".txt")
        with os.fdopen(fd, "w") as f:
            f.writelines(lines)
        self.truth = {G1: {"full": "Ann Oak", "first": "Ann", "mine": False},
                      G2: {"full": "Bob Elm", "first": "Bob", "mine": False}}

    def tearDown(self):
        os.unlink(self.path)

    def test_intervals(self):
        iv = ap.log_intervals(refdata.lines(self.path))
        self.assertEqual(len(iv[(G1, 774)]), 1)
        self.assertEqual(iv[(G2, 139)][0][1], float("inf"))

    def test_score(self):
        iv = ap.log_intervals(refdata.lines(self.path))
        g0 = 500.0
        tape = ["%.2f|nameplate3|Ann-Oak||774|P|bg/combat/combat" % (g0 + 15),     # present, log present -> agree
                "%.2f|nameplate3|Ann-Oak||774|A|bg/combat/combat" % (g0 + 40),     # absent, log removed -> agree
                "%.2f|target|Bob-Elm||139|A|bg/combat/combat" % (g0 + 35),         # absent, log present -> disagree
                "%.2f|target|Bob-Elm||139|S|arena/combat/combat" % (g0 + 36),      # unreadable
                "%.2f|target|Ann-Oak||774|P|bg/ooc/gates" % (g0 + 10.2),           # within EDGE of the apply -> edge
                "%.2f|target|Zed-X||774|P|bg/ooc/gates" % (g0 + 12)]               # unknown name
        sc, unres = ap.score({"anchor": {"gameTime": g0, "epoch": self.e0}, "tape": tape}, iv, self.truth,
                            utc_off=refdata.log_utc_offset(self.path))
        bc = sc["bg/combat/combat"]
        self.assertEqual(bc.get("agree:P"), 1)
        self.assertEqual(bc.get("agree:A"), 1)
        self.assertEqual(bc.get("disagree:A"), 1)
        self.assertEqual(sc["arena/combat/combat"].get("unreadable:S"), 1)
        self.assertEqual(sc["bg/ooc/gates"].get("edge"), 1)
        self.assertEqual(sc["bg/ooc/gates"].get("unresolved"), 1)
        self.assertEqual(unres.get("noname", 0) + unres.get("ambiguous", 0), 1)

    def test_score_v2226_unknown_and_derived(self):
        iv = ap.log_intervals(refdata.lines(self.path))
        g0 = 500.0
        tape = ["%.2f|target|Bob-Elm||139|U|world-solo/combat/-" % (g0 + 35),   # unknown, log present
                "%.2f|target|Ann-Oak||774|U|world-solo/combat/-" % (g0 + 40),   # unknown, log absent
                "%.2f|target|Ann-Oak||774|D|world-solo/combat/-" % (g0 + 15),   # derived, log present -> agree
                "%.2f|target|Ann-Oak||774|D|world-solo/combat/-" % (g0 + 45)]   # derived, log absent -> disagree
        sc, _ = ap.score({"anchor": {"gameTime": g0, "epoch": self.e0}, "tape": tape, "v": 2}, iv, self.truth,
                            utc_off=refdata.log_utc_offset(self.path))
        c = sc["world-solo/combat/-"]
        self.assertEqual(c.get("unknown:present"), 1)
        self.assertEqual(c.get("unknown:absent"), 1)
        self.assertEqual(c.get("agree:D"), 1)
        self.assertEqual(c.get("disagree:D"), 1)
        self.assertNotIn("disagree:A", c)

    def test_extras(self):
        x = ap.extras({"detail": ["1.00|player|Me||905|3|600|1234.5|11;22|player|1|HELPFUL|Lightning Shield|7|world-solo/ooc/-"],
                       "derived": ["1.00|17364|1238931|player|G|15.0|seed|t", "2.00|17364|1238931|player|G|15.0|seed|t"],
                       "totemCodes": {"t": {"event:1": {"CCCCCCC": 1}}}, "totems": ["x"], "hctx": {"t": {"k": {"health:S": 1}}}})
        self.assertEqual(x["detail"]["world-solo/ooc/-"], {"rows": 1, "stacks>1": 1, "withPoints": 1})
        self.assertEqual(x["derived"], [{"cast": 17364, "aura": 1238931, "on": "player", "n": 2}])
        self.assertEqual(x["totemRows"], 1)
        self.assertIn("hctx", x)
        self.assertEqual(ap.extras({}), {})

    def test_code_table(self):
        t = ap.code_table({"codes": {"bg/combat/combat": {"target": {"774": {"S": 3, "E": 1}}, "nameplateN": {"139": {"S": 2}}}}})
        self.assertEqual(t["bg/combat/combat"], {"S": 5, "E": 1})


class GuideCtx(unittest.TestCase):
    def test_env_aware(self):
        # legacy (no env): "restricted" and "combat with players" are assumed BG
        self.assertEqual(mg.probe_ctx("restricted", "x"), "pvp")
        self.assertEqual(mg.probe_ctx("combat", "u:player"), "pvp")
        # v2.2.25: a dungeon / world run with party players is combat, a BG run is pvp
        self.assertEqual(mg.probe_ctx("combat", "u:player", {"combat": {"dungeon": 4}}), "combat")
        # run 20 (dungeon): "restricted" is out of combat inside the instance (map restriction), not combat -> "inst"
        self.assertEqual(mg.probe_ctx("restricted", "x", {"restricted": {"raid": 2}}), "inst")
        self.assertEqual(mg.probe_ctx("combat", "u:npc", {"combat": {"bg": 3, "arena": 1}}), "pvp")
        # mixed environments fall back to the legacy heuristic
        self.assertEqual(mg.probe_ctx("combat", "u:player", {"combat": {"bg": 1, "world-solo": 1}}), "pvp")


class Wiring(unittest.TestCase):
    def test_toc_and_version(self):
        toc = read("ForeverDump", "ForeverDump.toc")
        self.assertIn("Derive.lua\nAuraPresence.lua\n", toc)
        core = read("ForeverDump", "Core.lua")
        self.assertRegex(core, r'ns\.VERSION = "2\.2\.2[5-9]"')
        self.assertIn("function ns.EnvNow()", core)
        self.assertIn("function AG.Call(", core)

    def test_gates_applied(self):
        for f, needle in (("Inference.lua", 'AG.Call("GetAuraSlots"'), ("OocFill.lua", "AuraGate.Call("),
                          ("Identity.lua", "AuraGate.Call("), ("Derive.lua", "AG.Call("),
                          ("CombatProbe.lua", "envCtx")):
            self.assertIn(needle, read("ForeverDump", f), f)
        self.assertNotIn("countsBroken", read("ForeverDump", "Inference.lua"))


if __name__ == "__main__":
    unittest.main()
