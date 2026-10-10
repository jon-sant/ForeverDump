"""run 20 (PvE dungeon) tooling: tools/fdump/pvescript.py (scripted-event verifier) and the aurapresence auto clock
offset. Synthetic data only (plus the real run 20 capture when present)."""
import os
import sys
import time
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from fdump import pvescript as pv, aurapresence as apm  # noqa: E402

ME = "Player-1-0000000A"
NPC = "Creature-0-1-389-1-11319-000000001"
TOT = "Creature-0-1-389-1-5925-000000002"
G0, E0 = 1000.0, 1791646693          # anchor gameTime <-> epoch (whole seconds)
L0 = apm.epoch_to_logsec(E0)


def row(t, ev, src="", dst="", sid=None, spell=None, *extra):
    p = [ev, src, "s", "0x0", "0x0", dst, "d", "0x0", "0x0"]
    if sid is not None:
        p += [str(sid), spell or "x", "0x1"]
    return (L0 + t, p + list(extra))


class T(unittest.TestCase):
    def test_codes(self):
        self.assertEqual(pv.code("<secret>"), "S")
        self.assertEqual(pv.code("<secrettable>"), "T")
        self.assertEqual(pv.code("<nil>"), "N")
        self.assertEqual(pv.code(5), "C")
        self.assertEqual(pv.code({"isFullUpdate": "<secret>", "addedAuras": "<secrettable>"}), "K{ST}")
        self.assertEqual(pv.code({"isFullUpdate": False, "addedAuras": ["<table>"]}), "K{CK}")
        self.assertEqual(pv.sig({"a": ["target", "<secret>", "<secret>", "<secret>", "CastBar-1"]}), ("target", "S S S C"))
        self.assertEqual(pv.sig({"a": ["<secret>"]}), ("-", "S"))

    def test_fit_offset(self):
        # the log is 1.0 s later than the anchor mapping (epoch truncated to whole seconds)
        cl = [row(6.0, "SPELL_CAST_SUCCESS", ME, "", 905), row(9.5, "SPELL_CAST_SUCCESS", ME, "", 8232)]
        rec = [{"e": "UNIT_SPELLCAST_SUCCEEDED", "t": G0 + 5.0, "a": ["player", "Cast-1", 905, "<nil>"]},
               {"e": "UNIT_SPELLCAST_SUCCEEDED", "t": G0 + 8.5, "a": ["player", "Cast-2", 8232, "<nil>"]},
               {"e": "UNIT_SPELLCAST_SUCCEEDED", "t": G0 + 8.5, "a": ["target", "<secret>", "<secret>", "C"]}]
        off, n = pv.fit_offset(rec, G0, E0, cl, ME)
        self.assertAlmostEqual(off, 1.0, places=3)
        self.assertEqual(n, 2)

    def test_truth_families(self):
        cl = [row(1, "SPELL_AURA_APPLIED", ME, ME, 905, "Lightning Shield", "BUFF"),
              row(2, "SPELL_AURA_APPLIED_DOSE", NPC, ME, 18070, "Earthborer Acid", "DEBUFF", "3"),
              row(3, "SPELL_MISSED", ME, NPC, 8046, "Earth Shock", "IMMUNE", "nil", "ST"),
              row(4, "SPELL_SUMMON", ME, TOT, 8177, "Grounding Totem"),
              row(5, "SPELL_CAST_SUCCESS", NPC, TOT, 9532, "Lightning Bolt"),
              row(6, "SPELL_INTERRUPT", ME, NPC, 8046, "Earth Shock", "9532", "Lightning Bolt", "8"),
              row(7, "SPELL_MISSED", NPC, ME, 9532, "Lightning Bolt", "RESIST", "nil", "ST"),
              row(8, "SPELL_AURA_APPLIED", ME, ME, 1238931, "Improved Stormstrike", "BUFF")]
        tr = pv.find_truth(cl, ME)
        self.assertEqual(tr["3-earthborer-acid"][0]["stacks"], "3")
        self.assertEqual(tr["5-immune"][0]["miss"], "IMMUNE")
        self.assertEqual([r["ev"] for r in tr["7-grounding"]], ["SPELL_SUMMON", "SPELL_CAST_SUCCESS"])
        self.assertEqual(tr["8-interrupt"][0]["interrupted"], "9532 Lightning Bolt")
        self.assertEqual([r["miss"] for r in tr["9-resist"]], ["RESIST"])
        self.assertIn(1238931, [r["sid"] for r in tr["4-stormstrike"]])

    def test_truth_is_mine_only(self):
        # run 21 (open world): another shaman's Flame Shock / Stormstrike / interrupt and a Net on her Searing Totem
        # were counted as the user's events (Flame Shock 123 rows, 16 mine)
        other, otot = "Player-1-0000000B", "Creature-0-1-1-1-3902-000000003"
        cl = [row(1, "SPELL_CAST_SUCCESS", other, NPC, 8052, "Flame Shock"),
              row(2, "SPELL_AURA_APPLIED", other, NPC, 17364, "Stormstrike", "DEBUFF"),
              row(3, "SPELL_INTERRUPT", other, NPC, 8046, "Earth Shock", "939", "Healing Wave", "8"),
              row(4, "SPELL_SUMMON", other, otot, 6363, "Searing Totem"),
              row(5, "SPELL_MISSED", NPC, otot, 6533, "Net", "IMMUNE", "nil", "ST"),
              row(6, "SPELL_SUMMON", other, TOT, 8177, "Grounding Totem"),
              row(7, "SPELL_CAST_SUCCESS", ME, NPC, 8052, "Flame Shock"),
              row(8, "SPELL_SUMMON", ME, "Creature-0-1-1-1-3902-000000004", 6363, "Searing Totem"),
              row(9, "SPELL_MISSED", NPC, "Creature-0-1-1-1-3902-000000004", 6533, "Net", "IMMUNE", "nil", "ST")]
        tr = pv.find_truth(cl, ME)
        self.assertEqual([r["t"] - L0 for r in tr["2-flame-shock"]], [7])
        self.assertEqual(tr.get("4-stormstrike", []), [])
        self.assertEqual(tr.get("8-interrupt", []), [])
        self.assertEqual(tr.get("7-grounding", []), [])
        self.assertEqual([r["t"] - L0 for r in tr["5-immune"]], [9])   # my own totem still counts

    def test_phase_is_per_fd_event(self):
        # a log row just before PLAYER_REGEN_DISABLED: FD events after the flip must count as combat (run 20 fix)
        rec = [{"e": "UNIT_AURA", "t": G0 + 1.0, "a": ["player", {"isFullUpdate": False}]},
               {"e": "PLAYER_REGEN_DISABLED", "t": G0 + 1.1, "a": {}},
               {"e": "UNIT_AURA", "t": G0 + 1.2, "a": ["player", {"isFullUpdate": "<secret>"}], "c": True}]
        raw = {"ForeverDumpRecordDB": {"sessions": [{"events": rec}]},
               "ForeverDumpLogDB": {"auraPresence": {"anchor": {"gameTime": G0, "epoch": E0}, "tape": []}}}
        cl = [row(0.95, "SPELL_AURA_APPLIED", ME, ME, 905, "Lightning Shield", "BUFF")]
        rep = pv.analyse(raw, cl, ME)
        agg = {(a["phase"], a["codes"]) for a in rep["events"]["1-self-buffs"]["fdAgg"]}
        self.assertEqual(agg, {("ooc", "K{C}"), ("combat", "K{S}")})
        self.assertEqual(rep["events"]["1-self-buffs"]["truth"][0]["phase"], "ooc")

    def test_aurapresence_auto_offset(self):
        import json
        import tempfile
        d = tempfile.mkdtemp()
        log = os.path.join(d, "WoWCombatLog.txt")
        lt = time.gmtime(E0 + 6 - 4 * 3600)   # the log carries its own zone (-4); box zone must not matter
        stamp = "%d/%d/%d %02d:%02d:%02d.000-4" % (lt.tm_mon, lt.tm_mday, lt.tm_year, lt.tm_hour, lt.tm_min, lt.tm_sec)
        with open(log, "w") as f:
            f.write(stamp + '  SPELL_CAST_SUCCESS,%s,"Me",0x511,0x0,0000000000000000,nil,0x0,0x0,905,"LS",0x8\n' % ME)
        raw = {"ForeverDumpRecordDB": {"sessions": [{"events": [
            {"e": "UNIT_SPELLCAST_SUCCEEDED", "t": G0 + 5.0, "a": ["player", "Cast-1", 905, "<nil>"]}]}]}}
        apd = {"anchor": {"gameTime": G0, "epoch": E0}}
        off, n = apm.auto_offset(raw, apd, log, {ME: {"mine": True}})
        self.assertEqual(n, 1)
        self.assertAlmostEqual(off, 1.0, places=2)
        self.assertEqual(apm.auto_offset(raw, apd, log, {}), (0.0, 0))
        json.dumps(apm._strkeys({1: {2: 3}}))

    @unittest.skipUnless(os.path.exists(os.path.join(ROOT, "real", "2026-10-10-run20-dungeon", "sv", "ForeverDump.lua")),
                         "run 20 capture not present")
    def test_run20_real(self):
        from fdump import refdata
        from fdump.dump import load_raw
        R = os.path.join(ROOT, "real", "2026-10-10-run20-dungeon")
        raw = load_raw(os.path.join(R, "sv", "ForeverDump.lua"))
        cl = [(t, p) for t, p in refdata.lines(os.path.join(R, "WoWCombatLog.txt")) if t is not None and p]
        self.assertEqual(refdata.log_utc_offset(os.path.join(R, "WoWCombatLog.txt")), -4.0)
        rep = pv.analyse(raw, cl, "Player-4618-00EB40D8", refdata.log_utc_offset(os.path.join(R, "WoWCombatLog.txt")))
        self.assertAlmostEqual(rep["offset"], 1.0, delta=0.05)
        ev = rep["events"]
        for k in ("1-self-buffs", "2-flame-shock", "3-earthborer-acid", "4-stormstrike", "5-immune", "6-self-heal",
                  "7-grounding", "8-interrupt"):
            self.assertTrue(ev.get(k, {}).get("truth"), k)
        # UNIT_AURA payload: clear out of combat, secret (S/T) in combat - never mixed
        for k, e in ev.items():
            for a in e["fdAgg"]:
                if a["event"] == "UNIT_AURA":
                    self.assertEqual(a["codes"], "K{CK}" if a["phase"] == "ooc" else "K{ST}", (k, a))
        it = {(a["token"], a["codes"]) for a in ev["8-interrupt"]["fdAgg"] if a["event"] == "UNIT_SPELLCAST_INTERRUPTED"}
        self.assertEqual(it, {("target", "S S S C"), ("nameplate2", "S S S C"), ("softenemy", "S S S C")})


if __name__ == "__main__":
    unittest.main(verbosity=1)
