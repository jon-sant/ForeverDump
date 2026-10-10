"""Player identity (v2.2.1): SV meta identity -> combat log owner, name forms for --player/--forever-player,
characters.json fallback, raw fixtures (v2.2.21: nothing scrubbed). Needs tests/out/hsm_sv.lua (tests/hsm.lua)."""
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from fdump import characters as C, combatlog  # noqa: E402
from fdump.dump import Dump  # noqa: E402

N = [0]


def ok(cond, msg):
    N[0] += 1
    if not cond:
        raise SystemExit("FAIL: " + msg)


class Stub:
    def __init__(self, identity=None, sessions=()):
        self._m = {"identity": identity} if identity else {}
        self.log, self.combatlog = {}, {"sessions": list(sessions)}

    def meta(self):
        return self._m


def ev(src, sname, dst="Creature-0-1-2-3-100-0000000001", dname="Boar", flags="0x511", sub="SPELL_CAST_SUCCESS"):
    return {"cleu": True, "a": [0, sub, False, src, sname, flags, "0x0", dst, dname, "0xa48", "0x0", 133, "Fireball", 4]}


FX = {"events": [ev("Player-4618-00EB40D8", "Uglaz-ClassicBetaPvE-")] * 5 +
      [ev("Player-4618-00AAAAAA", "Pally-ClassicBetaPvE-", flags="0x512")] * 2 +
      [ev("Player-4618-00BBBBBB", "Stranger-OtherRealm-", flags="0x548")] * 9}

# name forms
ok(C.parse_name("Uglaz Doomaxe") == {"first": "Uglaz", "last": "Doomaxe", "realm": None, "raw": "Uglaz Doomaxe"}, "First Last")
ok(C.parse_name("Uglaz-ClassicBetaPvE")["realm"] == "ClassicBetaPvE", "Name-Realm")
ok(C.parse_name("Uglaz Doomaxe-ClassicBetaPvE")["last"] == "Doomaxe", "First Last-Realm")
ok(C.parse_name("Player-4618-00EB40D8") == {"guid": "Player-4618-00EB40D8"}, "GUID")

# without SV and without config: the old 0x511 auto-detect
g, i = C.resolve(None, FX, None, config=False)
ok(g == "Player-4618-00EB40D8" and i["method"] == "auto:log-owner 0x511", "fallback auto-detect: %s" % i)
for spec in ("Uglaz Doomaxe", "Uglaz", "uglaz", "Uglaz-ClassicBetaPvE", "Uglaz Doomaxe-ClassicBetaPvE", "Player-4618-00EB40D8"):
    g, i = C.resolve(spec, FX, None, config=False)
    ok(g == "Player-4618-00EB40D8", "--player %r -> %s %s" % (spec, g, i))
g, i = C.resolve("Pally Palzy", FX, None, config=False)
ok(g == "Player-4618-00AAAAAA" and i["method"] == "name-in-log", "alt by full name (first name in log)")
g, i = C.resolve("Pally-Palzy", FX, None, config=False)
ok(g == "Player-4618-00AAAAAA", "'Pally-Palzy' as Name-Realm falls back to the first name when the realm doesn't match")

# SV identity (dynamic): GUID first, then name; no flags needed
sv = Stub({"name": "Pally Palzy", "firstName": "Pally", "lastName": "Palzy", "guid": "Player-4618-00AAAAAA", "realm": "ClassicBetaPvE"})
g, i = C.resolve(None, FX, sv, config=False)
ok(g == "Player-4618-00AAAAAA" and i["method"] == "auto:sv-meta guid", "SV identity GUID picks the owner even if not the 0x511 top: %s" % i)
sv2 = Stub({"name": "Uglaz Doomaxe", "realm": "ClassicBetaPvE", "anySecret": True, "secret": {"guid": True}})
g, i = C.resolve(None, FX, sv2, config=False)
ok(g == "Player-4618-00EB40D8" and i["method"] == "auto:sv-meta name", "secret GUID -> SV name 'First Last' matched to 'First-Realm-' in the log")
ok(C.identity_from_dump(sv2)["anySecret"] is True and C.identity_from_dump(sv2)["last"] == "Doomaxe", "identity carries secret flag + last name")
old = Stub(None, sessions=[{"playerGUID": "Player-4618-00EB40D8"}])
ok(C.identity_from_dump(old) == {"source": "sv-sessions", "guid": "Player-4618-00EB40D8"}, "pre-2.2.1 SV: GUID from recorder sessions")

# addon-written identity in the mock SV
hsv = Dump.load(os.path.join(ROOT, "tests", "out", "hsm_sv.lua"))
idn = C.identity_from_dump(hsv)
ok(idn and idn["source"] == "sv-meta" and idn["guid"] == "Player-1234-0ABCDEF0" and idn["first"] == "Mockchar", "mock SV meta.identity: %s" % idn)
mfx = combatlog.parse_file(os.path.join(ROOT, "tests", "fixtures", "WoWCombatLog-sample.txt"))
g, i = C.resolve(None, mfx, hsv, config=False)
ok(g == "Player-1234-0ABCDEF0" and i["method"].startswith("auto:sv-meta"), "mock log owner from the SV identity: %s" % i)

# characters.json fallback (no SV): configured character beats the 0x511 top
with tempfile.TemporaryDirectory() as td:
    cfg = os.path.join(td, "characters.json")
    json.dump({"characters": [{"display": "Stranger Danger", "combatLogName": "Stranger", "realm": "OtherRealm", "guid": ""}]}, open(cfg, "w"))
    os.environ["FDUMP_CHARACTERS"] = cfg
    g, i = C.resolve(None, FX, None)
    ok(g == "Player-4618-00BBBBBB" and i["method"] == "auto:characters.json name", "configured character by name: %s" % i)
    del os.environ["FDUMP_CHARACTERS"]
shipped = C.load_config()
ok(any(c["guid"] == "Player-4618-00EB40D8" and c["first"] == "Uglaz" and c["last"] == "Doomaxe" for c in shipped)
   and any(c["first"] == "Pally" and not c["guid"] for c in shipped), "shipped characters.json: Uglaz Doomaxe (GUID) + Pally-Palzy (no GUID)")

# identity list (SV identity + config): first + last names of both characters and the GUID
names, guids = C.scrub_names(sv2)
ok({"Uglaz", "Doomaxe", "Pally", "Palzy"} <= set(names) and "Player-4618-00EB40D8" in guids, "identity list from SV identity + config")

# fixtures end to end (v2.2.21 raw): the SV identity name and GUID stay in the pack verbatim
with tempfile.TemporaryDirectory() as td:
    log = os.path.join(td, "WoWCombatLog.txt")
    with open(os.path.join(ROOT, "tests", "fixtures", "WoWCombatLog-sample.txt"), encoding="utf-8") as f:
        body = f.read()
    with open(log, "w", encoding="utf-8") as f:
        f.write(body + '10/7/2026 19:52:48.000-4  COMBAT_LOG_VERSION,22,ADVANCED_LOG_ENABLED,1,BUILD_VERSION,1.60.1,PROJECT_ID,18\n'
                '10/7/2026 19:52:49.000-4  EMOTE,Player-1234-0ABCDEF0,"Mockchar",0000000000000000,nil,Mockchar waves\n')
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "fdump.py"), "fixtures", os.path.join(ROOT, "tests", "out", "hsm_sv.lua"),
                        "--file", log, "-o", os.path.join(td, "fx")], capture_output=True, text=True)
    ok(r.returncode == 0 and "(raw)" in r.stdout, "fixtures with SV identity: %s %s" % (r.stdout[-300:], r.stderr[-300:]))
    with open(os.path.join(td, "fx", "WoWCombatLog.txt"), encoding="utf-8") as f:
        fxlog = f.read()
    ok(fxlog == open(log, encoding="utf-8").read() and "Mockchar" in fxlog and "Player-1234-0ABCDEF0" in fxlog,
       "raw fixture log is byte-identical (Mockchar + GUID kept)")

# CLI: no --player needed; names accepted
r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "fdump.py"), "combatlog", os.path.join(ROOT, "tests", "fixtures", "WoWCombatLog-sample.txt"),
                    "--forever-player", "Mockchar", "-o", os.path.join(tempfile.gettempdir(), "fx_id.json")], capture_output=True, text=True)
ok(r.returncode == 0 and "Player-1234-0ABCDEF0" in r.stdout, "combatlog --forever-player NAME: " + r.stdout[-200:] + r.stderr[-300:])
BARRENS = os.path.join(ROOT, "real", "2026-10-07-run2", "WoWCombatLog.txt")
if os.path.exists(BARRENS):
    bfx = combatlog.parse_file(BARRENS)
    bdump = Dump.load(os.path.join(ROOT, "real", "2026-10-07-run2", "sv", "ForeverDump.lua"))
    g, i = C.resolve(None, bfx, bdump)
    ok(g == "Player-4618-00EB40D8", "run 2: automatic owner from the SV (%s)" % i)
    for spec in ("Uglaz Doomaxe", "Uglaz", "Uglaz-ClassicBetaPvE"):
        ok(C.resolve(spec, bfx, None, config=False)[0] == "Player-4618-00EB40D8", "run 2: %r" % spec)
    g, i = C.resolve("Pally-Palzy", bfx, bdump)
    ok(g == "Player-4618-00EB40D8" and "not in this log" in i.get("note", ""), "run 2: alt not in log -> note + auto: %s" % i)
print("IDENTITY OK (%d checks)" % N[0])
