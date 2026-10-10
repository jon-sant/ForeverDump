"""run 22 (BG) tooling: tools/fdump/derivesim.py (own-cast derivation rule vs combat-log truth) and
tools/fdump/totemscore.py (GetTotemInfo icon nil/secret per slot vs SPELL_SUMMON truth). Synthetic data, plus the real
run 22 capture when present (numbers pinned to the 2026-10-10 report)."""
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from fdump import derivesim as ds, totemscore as ts, aurapresence as apm, refdata  # noqa: E402

ME = "Player-1-0000000A"
EN = "Player-2-0000000B"
G0, E0, OFF = 1000.0, 1791653966, -4      # anchor gameTime <-> epoch; log zone -4
L0 = apm.epoch_to_logsec(E0, OFF)


def row(t, ev, src="", dst="", sid=None, spell=None, *extra):
    p = [ev, src, "s", "0x0", "0x0", dst, "d", "0x0", "0x0"]
    if sid is not None:
        p += [str(sid), spell or "x", "0x1"]
    return (L0 + t, p + list(extra))


class Derive(unittest.TestCase):
    def test_rules_from_sv(self):
        raw = {"ForeverDumpDB": {"knowledge": {"70338": {"spells": {
            8056: {"data": {"parsed": {"auraDuration": 8}}}, 403: {"data": {"parsed": {}}}}}},
            "refLearned": {"70338": {"auraDur": {8056: {"min": 6, "max": 8, "n": 3}}}}}}
        r = ds.rules_from_sv(raw, 70338)
        self.assertEqual(set(r), {8056})
        self.assertEqual(r[8056][8056], {"dur": 6.0, "src": "refLearned"})

    def test_simulate(self):
        rules = {8056: {8056: {"dur": 8.0, "src": "knowledge"}}}
        rows = [row(0, "SPELL_CAST_SUCCESS", ME, EN, 8056), row(0.1, "SPELL_AURA_APPLIED", ME, EN, 8056),
                row(8.2, "SPELL_AURA_REMOVED", ME, EN, 8056),                 # ok
                row(20, "SPELL_CAST_SUCCESS", ME, EN, 8056), row(20.1, "SPELL_AURA_APPLIED", ME, EN, 8056),
                row(22, "SPELL_AURA_REMOVED", ME, EN, 8056),                  # early (dispel)
                row(40, "SPELL_CAST_SUCCESS", ME, EN, 8056),                  # miss (resist)
                row(50, "SPELL_CAST_SUCCESS", ME, "0000000000000000", 17364), row(50.2, "SPELL_AURA_APPLIED", ME, ME, 1238931)]
        out = ds.simulate(rows, ME, rules)
        self.assertEqual(out["score"]["8056->8056"], {"applied": 2, "end:ok": 1, "end:early": 1, "miss": 1})
        self.assertEqual(out["observedPairs"], {"17364->1238931": 1})


class Totems(unittest.TestCase):
    def test_score(self):
        # slot 4: empty (N) until the summon at +10 (event row S), totem dies at +25 -> N again
        rel = lambda t: "%.2f" % (G0 + t)
        ap = {"anchor": {"gameTime": G0, "epoch": E0},
              "totems": [rel(0) + "|4|tick|SSSSNSS|?|||||bg/ooc/gates", rel(10.1) + "|4|event|SSSSSSS|?|||||bg/ooc/gates",
                         rel(25.1) + "|4|event|SSSSNSS|?|||||bg/ooc/gates", rel(40) + "|4|tick|SSSSNSS|?|||||bg/ooc/gates"]}
        rows = [row(0, "ZONE_CHANGE"), row(10, "SPELL_SUMMON", ME, "Creature-0-1-1-1-5925-1", 8177, "Grounding Totem"),
                row(25, "UNIT_DIED", "", "Creature-0-1-1-1-5925-1"), row(41, "ZONE_CHANGE")]
        out = ts.score(ap, rows, ME, OFF)
        self.assertEqual(out["bySlot"], {4: 1})
        s = out["samples"]
        self.assertGreater(s.get("empty|icon=N", 0), 40)
        self.assertGreater(s.get("totem|icon=S", 0), 25)
        self.assertNotIn("empty|icon=S", s)
        self.assertNotIn("totem|icon=N", s)


class Guide(unittest.TestCase):
    def test_empty_presence_does_not_evict(self):
        from fdump import master_guide as mg
        old = {"run": "a", "label": "runA", "inspect": {"auraPresence": {"bg/combat/combat": {"player": {"E": 3, "held": 40}}}}}
        new = {"run": "b", "label": "runB", "inspect": {"auraPresence": {"bg/combat/combat": {"player": {}}}}}
        obs = mg.collect([old, new])[0]
        runs = set()
        for byctx in obs.cells.values():
            for c in byctx.values():
                runs |= c["runs"]
        self.assertEqual(runs, {"runA"})


RUN22 = os.path.join(ROOT, "real", "2026-10-10-run22-bg")


@unittest.skipUnless(os.path.exists(os.path.join(RUN22, "sv", "ForeverDump.lua")), "run 22 capture not present")
class Real(unittest.TestCase):
    def test_totems_run22(self):
        from fdump.dump import load_raw
        raw = load_raw(os.path.join(RUN22, "sv", "ForeverDump.lua"))
        log = os.path.join(RUN22, "WoWCombatLog.txt")
        out = ts.score(raw["ForeverDumpLogDB"]["auraPresence"], list(refdata.lines(log)), "Player-4618-00EB40D8",
                       refdata.log_utc_offset(log))
        self.assertEqual(out["summons"], 34)
        self.assertEqual(out["bySlot"], {1: 6, 2: 8, 3: 6, 4: 14})
        self.assertEqual(out["samples"]["empty|icon=N"], 5076)
        self.assertNotIn("empty|icon=S", out["samples"])


if __name__ == "__main__":
    unittest.main()
