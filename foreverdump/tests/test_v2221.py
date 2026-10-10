"""v2.2.21 raw identity (user decision 2026-10-09: store raw GUIDs / names, never scrub or hash).

1. capture -> SVPack -> converter -> analysis: tests/raw_roundtrip.lua writes an SV with known raw GUIDs and a full
   name with realm; the converter's loader (SVPack unpack) must return them byte-identical at their capture paths and
   `fdump.py replay` / `fdump.py json` must carry them unchanged.
2. rawjoin: raw GUIDs in damage-meter snapshots / live units join 1:1 to combat-log truth.
3. package.py: no scrubber left; zip entries are byte-identical to their sources.
"""
import json
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from fdump import dump as dumpmod, rawjoin  # noqa: E402

PG = "Player-4619-0ABCDEF1"
CG = "Creature-0-1234-5678-90-12345-0000ABCDEF"
FULL = "Grukk-Stonefist Realm"
SV = os.path.join(ROOT, "tests", "out", "raw_roundtrip_sv.lua")


def walk(x, needle, path="", out=None):
    out = [] if out is None else out
    if isinstance(x, dict):
        for k, v in x.items():
            if k == needle:
                out.append(path + "{key}")
            walk(v, needle, "%s.%s" % (path, k), out)
    elif isinstance(x, (list, tuple)):
        for i, v in enumerate(x):
            walk(v, needle, "%s[%d]" % (path, i), out)
    elif x == needle:
        out.append(path)
    return out


class RoundTrip(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.makedirs(os.path.dirname(SV), exist_ok=True)
        r = subprocess.run(["lua5.1", "tests/raw_roundtrip.lua", "ForeverDump", SV], cwd=ROOT, capture_output=True, text=True)
        assert r.returncode == 0, r.stdout + r.stderr
        cls.raw = dumpmod.load_raw(SV)

    def test_loader_returns_raw_values_at_capture_paths(self):
        log = self.raw["ForeverDumpLogDB"]
        units = log["derive"]["units"]["name:Grukk"]
        self.assertIn(FULL, units["names"])
        self.assertIn(PG, units["guids"])
        cache = log["oocfill"]["cache"]["player:" + PG]["f"]
        self.assertEqual(cache["name"]["v"], FULL)
        self.assertEqual(cache["guid"]["v"], PG)
        self.assertTrue(walk(log, "player:" + PG), "tape / HSM key player:<GUID>")
        self.assertTrue(walk(log, CG), "creature GUID kept (map delta g)")
        self.assertTrue(walk(log.get("inference") or {}, PG), "HSM export holds the raw GUID")

    def test_no_hash_or_placeholder(self):
        blob = json.dumps(self.raw, default=str)
        self.assertNotIn(":redacted", blob)
        self.assertNotIn("<redacted>", blob)
        self.assertNotIn("saltNote", blob)

    def test_converter_json_and_replay_keep_raw(self):
        with tempfile.TemporaryDirectory() as td:
            for cmd in (["json", SV, "-o", os.path.join(td, "json")], ["replay", SV, "-o", os.path.join(td, "replay")]):
                r = subprocess.run([sys.executable, "tools/fdump.py"] + cmd, cwd=ROOT, capture_output=True, text=True)
                self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            text = ""
            for dp, _, fns in os.walk(td):
                for fn in fns:
                    with open(os.path.join(dp, fn), encoding="utf-8", errors="replace") as f:
                        text += f.read()
            self.assertIn(PG, text)
            self.assertIn(FULL, text)


    def test_analysis_joins_raw_guid(self):
        # analysis stage: the live units read back from the SV join to the log by the raw GUID (rawjoin), and the full
        # analyze pipeline runs on the raw SV
        lu = rawjoin.live_units(self.raw)
        self.assertIn((PG, "SHAMAN", "cache", None), lu)
        with tempfile.TemporaryDirectory() as td:
            r = subprocess.run([sys.executable, "tools/fdump.py", "analyze", SV, "--log", "tests/fixtures/WoWCombatLog-sample.txt",
                                "-o", td], cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)


class RawJoin(unittest.TestCase):
    def test_meter_and_live_join(self):
        raw = {"ForeverDumpCombatLogDB": {"sessions": [{"damageMeter": [{"gameTime": 10.0, "byType": {"DamageDone": {
            "combatSources": [{"sourceGUID": "Player-1-000000AA", "classFilename": "MAGE", "name": "Aa Bb"},
                              {"sourceGUID": "Player-1-000000BB", "classFilename": "ROGUE", "name": "Cc Dd"}]}}}]}]},
            "ForeverDumpLogDB": {"derive": {"units": {"name:Aa": {"class": "MAGE", "via": "score", "guids": {"Player-1-000000AA": True}}}},
                                 "oocfill": {"cache": {"player:Player-1-000000BB": {"f": {"class": {"v": "WARRIOR"}}},
                                                       "player:0a1b2c3d": {"f": {"class": {"v": "MAGE"}}}}}}}
        rows = rawjoin.meter_rows(raw)
        self.assertEqual({r[1] for r in rows}, {"Player-1-000000AA", "Player-1-000000BB"})
        lu = rawjoin.live_units(raw)
        self.assertIn(("Player-1-000000AA", "MAGE", "derive:score", None), lu)
        self.assertIn(("Player-1-000000BB", "WARRIOR", "cache", None), lu)
        self.assertEqual(len(lu), 2, "pre-2.2.21 salted keys are not joinable")


class Package(unittest.TestCase):
    def test_no_scrubber(self):
        with open(os.path.join(ROOT, "tools", "package.py")) as f:
            src = f.read()
        self.assertNotIn("def scrub", src)
        self.assertNotIn("leak", src.lower())  # noqa
        self.assertIn("byte-identical", src)
        self.assertFalse(os.path.exists(os.path.join(ROOT, "tools", "fdump", "anonymize.py")))


if __name__ == "__main__":
    unittest.main(verbosity=1)
