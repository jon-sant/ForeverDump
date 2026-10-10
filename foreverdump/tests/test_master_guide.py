"""v2.2.10 master secrets guide regression (docs/SECRETS-GUIDE.html + .md + docs/secrets-guide-state.json).

Fails when the committed guide is stale: it differs byte for byte from `python3 tools/fdump.py master-guide` output for
the runs under real/, or a guide file is older than the newest run input (SV, analysis/coverage JSON, FINDINGS.md).
Also: no raw GUIDs / player names in any guide file, sane structure (rows x families x contexts, statuses, tally,
HTML and Markdown carry the same rows), every curated FINDINGS claim still resolves, and the staleness check itself
detects an edited or outdated guide (negative controls on a scratch copy). Without the private captures (real/ absent,
e.g. in a release zip) only the placeholder and structure checks on whatever guide is present run."""
import json
import os
import re
import shutil
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from fdump import master_guide as mg  # noqa: E402

HAVE_RUNS = bool(mg.list_runs(ROOT))
DOCS = {rel: os.path.join(ROOT, rel) for rel in mg.OUTPUTS}
HAVE_DOCS = all(os.path.exists(p) for p in DOCS.values())


def _read(rel):
    with open(DOCS[rel], encoding="utf-8") as f:
        return f.read()


@unittest.skipUnless(HAVE_DOCS or HAVE_RUNS, "no master guide and no private captures")
class Fresh(unittest.TestCase):
    @unittest.skipUnless(HAVE_RUNS, "private captures (real/) absent")
    def test_guide_is_fresh(self):
        probs = mg.check(ROOT)
        self.assertEqual(probs, [], "stale master guide; run `python3 tools/fdump.py master-guide`: %s" % probs)

    @unittest.skipUnless(HAVE_RUNS, "private captures (real/) absent")
    def test_claims_resolve(self):
        st = json.loads(_read("docs/secrets-guide-state.json"))
        self.assertEqual(st["droppedClaims"], [], "FINDINGS claim quote no longer found")
        self.assertGreaterEqual(st["claimsUsed"], 20)
        self.assertEqual(st["newestRun"], mg.list_runs(ROOT)[-1])


@unittest.skipUnless(HAVE_DOCS, "master guide not generated")
class Content(unittest.TestCase):
    def test_no_placeholders(self):
        # v2.2.21 (raw identity): no privacy gate; the guide must not carry redaction placeholders either
        for rel in mg.OUTPUTS:
            text = _read(rel)
            self.assertNotIn(":redacted", text, rel)
            self.assertNotIn("<redacted>", text, rel)

    def test_structure(self):
        st = json.loads(_read("docs/secrets-guide-state.json"))
        rows = st["rows"]
        self.assertEqual(st["schema"], mg.SCHEMA)
        self.assertEqual(len(rows), st["rowCount"])
        self.assertGreaterEqual(len(rows), 150)
        self.assertEqual(len({r["id"] for r in rows}), len(rows))
        self.assertEqual(sum(st["tally"].values()), len(rows))
        for r in rows:
            self.assertIn(r["status"], mg.STATUSES, r["id"])
            self.assertEqual(set(r["read"]), set(mg.CTXS), r["id"])
            self.assertIn(r["family"], mg.FAMILIES, r["id"])
        # every requested value family is covered
        ids = {r["id"].split("/")[0] for r in rows}
        for need in ("health", "healthMax", "power", "casting", "spellid", "castbar", "aura-event", "aura-payload", "aura-details",
                     "guid", "name", "unit-combat", "unit-died", "threat", "range", "cooldown", "meter"):
            self.assertIn(need, ids)
        fams = {r["family"] for r in rows if r["id"].startswith("health/")}
        self.assertEqual(fams, set(mg.ALL8))
        # HTML and Markdown carry the same rows and the same tally
        html = _read("docs/SECRETS-GUIDE.html")
        md = _read("docs/SECRETS-GUIDE.md")
        self.assertEqual(len(re.findall(r'<tr id="', html)), len(rows))
        data_rows = 0
        for sec in re.split(r"\n## ", md):
            if sec.startswith("| value | family | ooc |") or "\n| value | family | ooc |" in sec:
                data_rows += len([ln for ln in sec.splitlines() if ln.startswith("| ") and not ln.startswith("| value |")])
        self.assertEqual(data_rows, len(rows))
        for s, n in st["tally"].items():
            self.assertIn("| %s | %d |" % (s, n), md)
        self.assertIn("Changed since last run", md)
        self.assertIn("Changed since last run", html)

    def test_raw_allowed(self):
        # v2.2.21 (raw identity): GUIDs and character names pass unchanged - no privacy gate
        self.assertIsNone(mg.assert_private("x Player-1234-0ABCDEF0 y", ROOT))
        names = sorted(mg.forbidden_names(ROOT))
        if names:
            self.assertIsNone(mg.assert_private("row about %s here" % names[0], ROOT))


@unittest.skipUnless(HAVE_RUNS and HAVE_DOCS, "private captures absent")
class StaleDetection(unittest.TestCase):
    """negative controls: the check must flag an edited guide and a guide older than the run data"""

    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="fd_mg_")
        os.symlink(os.path.join(ROOT, "real"), os.path.join(self.tmp, "real"))
        os.makedirs(os.path.join(self.tmp, "tools", "fdump"))
        shutil.copy(os.path.join(ROOT, "tools", "fdump", "characters.json"), os.path.join(self.tmp, "tools", "fdump"))
        os.makedirs(os.path.join(self.tmp, "docs"))
        for rel in mg.OUTPUTS:
            shutil.copy2(DOCS[rel], os.path.join(self.tmp, rel))

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_copy_is_fresh(self):
        self.assertEqual(mg.check(self.tmp), [])

    def test_edit_detected(self):
        p = os.path.join(self.tmp, "docs", "SECRETS-GUIDE.md")
        st = os.stat(p)
        with open(p, "a", encoding="utf-8") as f:
            f.write("hand edit\n")
        os.utime(p, (st.st_atime, st.st_mtime))
        self.assertTrue(any("does not match" in x for x in mg.check(self.tmp)))

    def test_older_than_data_detected(self):
        p = os.path.join(self.tmp, "docs", "SECRETS-GUIDE.html")
        os.utime(p, (1, 1))
        self.assertTrue(any("older than the newest run data" in x for x in mg.check(self.tmp)))




class ProbeCtxEviction(unittest.TestCase):
    """run 19 (v2.2.25 env tags): a newer run whose env counters map a probe cell to pvp must not evict an older
    PvE run's "combat" cell for the same (item, ret, unit, raw ctx); a BG-only legacy run files its combat cells as pvp."""

    @staticmethod
    def _run(label, ctxs, cell_ctx, code, envs=None):
        ring = [{"epoch": label, "events": {"X": {"player": {c: {"n": 1} for c in ctxs}}}}]
        probes = {"matrix": {"UnitHealth": {"1": {"player:self": {cell_ctx: {"counts": {code: 5}}}}}}}
        if envs:
            probes["envCtx"] = envs
        return {"label": label, "run": label, "inspect": {"ring": {"sessions": ring}, "probes": probes}, "accuracy": {}}

    def _cells(self, runs):
        obs, _acc, _ = mg.collect(runs)
        return {ctx: dict(c["codes"]) for ctx, c in obs.cells[("health", "player")].items()}

    def test_pve_combat_survives_env_tagged_bg_run(self):
        pve = self._run("runA", ["ooc", "combat"], "combat", "C")
        bg = self._run("runB", ["pvp"], "combat", "S", envs={"combat": {"bg": 9}})
        cells = self._cells([pve, bg])
        self.assertEqual(cells.get("combat"), {"C": 5})
        self.assertEqual(cells.get("pvp"), {"S": 5})

    def test_bg_only_legacy_run_maps_combat_to_pvp(self):
        bg = self._run("runC", ["pvp"], "combat", "S")
        cells = self._cells([bg])
        self.assertNotIn("combat", cells)
        self.assertEqual(cells.get("pvp"), {"S": 5})

    def test_dungeon_restricted_is_inst_not_combat(self):
        # run 20: "restricted" with dungeon env counters = out of combat inside a PvE instance; it was filed as PvE
        # combat (probe cells) and as pvp (containers) before
        dun = self._run("runD", ["ooc", "combat"], "restricted", "S", envs={"restricted": {"dungeon": 8}, "combat": {"dungeon": 16}})
        cells = self._cells([dun])
        self.assertEqual(cells, {"inst": {"S": 5}})
        # the same run's combat cell is instance combat, not open-world PvE combat
        dun2 = self._run("runE", ["ooc", "combat"], "combat", "S", envs={"restricted": {"dungeon": 8}, "combat": {"dungeon": 16}})
        world = self._run("runW", ["ooc", "combat"], "combat", "C")
        cells = self._cells([world, dun2])
        self.assertEqual(cells.get("combat"), {"C": 5})      # open-world cell kept (keep the good)
        self.assertEqual(cells.get("icombat"), {"S": 5})     # instance evidence shown next to it
        self.assertTrue(mg.instance_run({"combat": {"dungeon": 1}}))
        self.assertFalse(mg.instance_run({"combat": {"dungeon": 1, "bg": 1}}))
        self.assertFalse(mg.instance_run(None))
        self.assertEqual(mg.valid_in_combat("live", {"combat": "clear", "icombat": "secret", "pvp": "secret", "ooc": "clear", "inst": "-"}),
                         "open-world PvE only")
        self.assertEqual(mg.valid_in_combat("live", {"combat": "clear", "icombat": "secret", "pvp": "-", "ooc": "clear", "inst": "-"}),
                         "not in PvE instances")
        self.assertEqual(mg.probe_ctx("restricted", "player:self", {"restricted": {"bg": 3}}), "pvp")
        self.assertEqual(mg.probe_ctx("restricted", "player:self", None), "pvp")
        self.assertEqual(mg.probe_ctx("combat", "player:self", {"combat": {"dungeon": 2}}), "combat")

    def test_presence_ctx_and_rows(self):
        self.assertEqual(mg.presence_ctx("dungeon/combat/-"), "icombat")
        self.assertEqual(mg.presence_ctx("dungeon/ooc/-"), "inst")
        self.assertEqual(mg.presence_ctx("bg/ooc/gates"), "pvp")
        self.assertEqual(mg.presence_ctx("world/combat/-"), "combat")
        self.assertEqual(mg.presence_ctx("world/ooc/-"), "ooc")
        run = {"label": "runP", "run": "runP", "accuracy": {}, "inspect": {"ring": {"sessions": []}, "auraPresence": {
            "dungeon/ooc/-": {"player": {"K": 3, "N": 7}}, "dungeon/combat/-": {"player": {"N": 9}, "target": {"N": 4}}}}}
        obs, _acc, _ = mg.collect([run])
        cells = {ctx: dict(c["codes"]) for ctx, c in obs.cells[("aura-presence", "player")].items()}
        self.assertEqual(cells, {"inst": {"C": 3, "N": 7}, "icombat": {"N": 9}})
        self.assertEqual(dict(obs.cells[("aura-presence", "any")]["icombat"]["codes"]), {"N": 13})
        bg = {"label": "runB", "run": "runB", "accuracy": {}, "inspect": {"ring": {"sessions": []}, "auraPresence": {
            "bg/combat/combat": {"player": {"N": 5}}, "bg/ooc/post": {"player": {"K": 2, "N": 1}}}}}
        obs, _acc, _ = mg.collect([bg])
        self.assertEqual(dict(obs.cells[("aura-presence", "player")]["pvp"]["codes"]), {"N": 6, "C": 2})   # summed, not last tag

    def test_containers_restricted_follow_env(self):
        def run(label, env):
            cont = {"countMatrix": [{"ctx": "restricted", "group": "player", "method": "GetAuraSlots", "codes": {"C": 2}}],
                    "auraMatrix": [{"ctx": "restricted", "group": "player", "units": ["player"], "table": {"K": 1}, "fields": {}, "event": {}}]}
            return {"label": label, "run": label, "accuracy": {},
                    "inspect": {"ring": {"sessions": []}, "containers": cont, "probes": {"envCtx": {"restricted": {env: 4}}}}}
        obs, _acc, _ = mg.collect([run("bgRun", "bg"), run("dunRun", "dungeon")])
        ctxs = {ctx for (rid, fam), byc in obs.cells.items() if fam == "player" for ctx, c in byc.items() if c["codes"]}
        self.assertIn("inst", ctxs)    # the dungeon run's cells ...
        self.assertIn("pvp", ctxs)     # ... no longer evict the BG run's (same raw ctx, different mapped ctx)
        self.assertEqual(mg.restricted_ctx({"restricted": {"dungeon": 1}}), "inst")
        self.assertEqual(mg.restricted_ctx({"restricted": {"dungeon": 1, "bg": 1}}), "pvp")


if __name__ == "__main__":
    r = unittest.main(exit=False, verbosity=1).result
    print("master guide: %s (%d tests, %d skipped)" % ("OK" if r.wasSuccessful() else "FAILED", r.testsRun, len(r.skipped)))
    sys.exit(0 if r.wasSuccessful() else 1)
