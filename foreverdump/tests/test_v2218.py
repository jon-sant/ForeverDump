"""v2.2.18: reference-data miner (tools/fdump/refdata.py) and class-derivation scorer (tools/fdump/classderive.py)."""
import json, os, sys, tempfile, unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))
from fdump import refdata, classderive  # noqa: E402

ADV = "{g},0000000000000000,1000,1000,0,0,0,0,0,0,{pt},100,100,{cost},1.0,2.0,1,0.0,30"


def line(t, sub, src, sid, name, school="0x8", dst="0000000000000000", flags="0x548", pt=0, cost=0, extra=""):
    adv = ADV.format(g=src, pt=pt, cost=cost)
    return ('10/9/2026 17:%02d:%06.3f-4  %s,%s,"P-R",%s,0x0,%s,nil,0x0,0x0,%s,"%s",%s,%s%s'
            % (t // 60, t % 60, sub, src, flags, dst, sid, name, school, adv, extra))


class RefDataMiner(unittest.TestCase):
    def setUp(self):
        L = []
        sh = ["Player-1-0000000%d" % i for i in range(1, 5)]
        war = "Player-1-00000009"
        t = 1.0
        for g in sh:                                   # 4 shamans: seed spell + an unseeded spell 999
            for _ in range(2):
                L.append(line(t, "SPELL_CAST_START", g, 403, "Lightning Bolt")); t += 2.0
                L.append(line(t, "SPELL_CAST_SUCCESS", g, 403, "Lightning Bolt")); t += 0.5
            L.append(line(t, "SPELL_CAST_SUCCESS", g, 999, "Mystery Shock")); t += 0.5
        for g in sh[:2]:                               # only 2 shamans: not enough casters -> no class tag
            L.append(line(t, "SPELL_CAST_SUCCESS", g, 888, "Rare Thing")); t += 0.5
        for _ in range(3):                             # warrior with seed spells, rage
            L.append(line(t, "SPELL_CAST_SUCCESS", war, 78, "Heroic Strike", pt=1)); t += 0.5
        L.append(line(t, "SPELL_CAST_SUCCESS", war, 746, "First Aid")); t += 0.5
        L.append(line(t, "SPELL_CAST_SUCCESS", sh[0], 746, "First Aid")); t += 0.5
        L.append(line(t, "SPELL_SUMMON", sh[0], 5394, "Healing Stream Totem", dst="Creature-0-1-2-3-3527-0001",
                      extra=""))
        self.dir = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.dir, "runA"))
        self.path = os.path.join(self.dir, "runA", "WoWCombatLog.txt")
        with open(self.path, "w") as f:
            f.write("\n".join(L) + "\n")

    def test_tables(self):
        ref, per_run, _ = refdata.build([self.path], 70291)
        sp = ref["spells"]
        self.assertEqual(sp["403"]["class"], "SHAMAN")
        self.assertAlmostEqual(sp["403"]["castTime"], 2.0, places=1)
        self.assertEqual(sp["999"]["class"], "SHAMAN", "propagated: 4 casters, all shamans")
        self.assertNotIn("class", sp.get("888", {}), "2 casters of one class are not enough")
        self.assertNotIn("class", sp.get("746", {}), "a spell cast by two classes is generic")
        self.assertEqual(ref["summons"]["3527"]["ownerClass"], "SHAMAN")
        self.assertIn("1", ref["classPower"]["WARRIOR"])
        self.assertEqual(ref["build"], 70291)
        self.assertNotIn("Player-", json.dumps(ref), "no player GUID in the shipped tables")
        self.assertNotIn("P-R", json.dumps(ref), "no player name in the shipped tables")
        lua = refdata.to_lua(ref)
        self.assertIn("[403]={7,", lua)          # SHAMAN = class code 7 (sorted)
        self.assertIn("build = 70291", lua)

    def test_fingerprints_poisoned_by_generic(self):
        ref = {"spells": {"1": {"class": "MAGE", "castTime": 2.5}, "2": {"castTime": 2.5},
                          "3": {"class": "PRIEST", "castTime": 3.5}}}
        fp = classderive.fingerprints(ref)
        self.assertNotIn(2.5, fp, "a generic spell shares 2.5 s -> no elimination at 2.5 s")
        self.assertNotIn(2.4, fp)
        self.assertEqual(fp.get(3.5), {"PRIEST"})

    def test_power_map(self):
        self.assertEqual(classderive.POWER_CLASSES[1], {"WARRIOR", "DRUID"})
        self.assertEqual(classderive.POWER_CLASSES[3], {"ROGUE", "DRUID"})
        self.assertNotIn("WARRIOR", classderive.POWER_CLASSES[0])

    def test_summarize(self):
        res = [{"truth": "MAGE", "first": 0, "cand": ["MAGE"], "tId": 5, "pcOk": True, "pcSingle": True, "tMeter": 30},
               {"truth": "ROGUE", "first": 0, "cand": ["DRUID", "ROGUE"], "tId": None, "pcOk": True, "pcSingle": False,
                "tMeter": None}]
        s = classderive.summarize(res)
        self.assertEqual(s["PC"]["correct"], 1)
        self.assertEqual(s["PC"]["wrong"], 0)
        self.assertEqual(s["combined"]["coverage"], 50.0)
        self.assertEqual(s["combined"]["medianTTI"], 5)


class LearnedMerge(unittest.TestCase):
    def test_merge(self):
        ref = {"build": 70291, "spells": {"370": {"class": "SHAMAN", "castTime": 0}, "403": {"class": "SHAMAN", "castTime": 2.0}, "999": {}}}
        learned = {"70400": {"spellClass": {"999": {"MAGE": 4}, "370": {"PRIEST": 5}, "403": {"SHAMAN": 2}},
                             "castMs": {"403": {"n": 3, "min": 1500}, "998": {"n": 1, "min": 3000}}}}
        st = refdata.merge_learned(ref, learned)
        self.assertEqual(ref["spells"]["999"]["class"], "MAGE")
        self.assertEqual(ref["spells"]["370"]["conflict"], "PRIEST")
        self.assertEqual(ref["drift"]["70400"]["403"], {"seed": 2.0, "live": 1.5})
        self.assertEqual(ref["spells"]["403"]["castTime"], 1.5)          # newer build wins
        self.assertEqual(ref["spells"]["998"]["castTime"], 3.0)
        self.assertEqual((st["tagged"], st["conflict"], st["drift"], st["confirmed"]), (1, 1, 1, 1))


class DerivationInventory(unittest.TestCase):
    def test_every_guide_row_has_a_path(self):
        from fdump import master_guide, derivation
        ids = {sp[0] for sp in master_guide.SPECS}
        self.assertEqual(sorted(ids - set(derivation.DERIVE)), [])
        for k, e in list(derivation.DERIVE.items()) + [(x[0], x[2]) for x in derivation.EXTRA]:
            self.assertIn(e["status"], derivation.DERIVE_STATUSES, k)
            self.assertTrue(e["path"] and e["path"] != "-" or e["status"] == "direct", k)
        for k in ("census", "same-class", "aura-source", "others-spellid", "meter-enemy"):   # former HSM-STATUS section 3
            self.assertIn(k, [x[0] for x in derivation.EXTRA])


if __name__ == "__main__":
    unittest.main()
