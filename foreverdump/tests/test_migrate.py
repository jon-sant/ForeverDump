#!/usr/bin/env python3
"""migrate command: deliberate legacy addon (tests/legacy_addon) against the mock SavedVariables
(tests/out/ForeverDump.lua written by smoke.lua). No user data involved."""
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from fdump import migrate  # noqa: E402
from fdump.dump import Dump  # noqa: E402

SV = os.path.join(ROOT, "tests", "out", "ForeverDump.lua")


def by_name(rep):
    return {a["name"]: a for a in rep["apis"]}


def main():
    out = tempfile.mkdtemp()
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "fdump.py"), "migrate", SV,
                    os.path.join(ROOT, "tests", "legacy_addon"), "-o", out], check=True, capture_output=True)
    rep = json.load(open(os.path.join(out, "migration.json")))
    md = open(os.path.join(out, "MIGRATION.md")).read()
    a = by_name(rep)
    exp = {"GetSpellInfo": "signature-changed", "GetContainerItemInfo": "signature-changed", "UnitAura": "signature-changed",
           "GetItemGem": "renamed", "CombatLogGetNumEntries": "replacement-missing", "UnitHealth": "now-secret"}
    for k, v in exp.items():
        assert a[k]["status"] == v, (k, a[k])
    assert a["GetSpellInfo"]["replacement"] == "C_Spell.GetSpellInfo"
    assert "returns #1 secret" in (a["UnitHealth"].get("secrecy") or "")
    ev = {e["event"]: e for e in rep["events"]}
    assert ev["COMBAT_LOG_EVENT_UNFILTERED"]["status"] == "restricted-event"
    assert ev["UNIT_HEALTH_FREQUENT"]["status"] == "renamed-event" and ev["UNIT_HEALTH_FREQUENT"]["replacement"] == "UNIT_HEALTH"
    assert ev["TOTALLY_FAKE_OLD_EVENT"]["status"] == "removed-event"
    assert ev["PLAYER_LOGIN"]["status"] == "ok"
    toc = [t["level"] for t in rep["toc"]]
    assert toc.count("error") >= 2, rep["toc"]  # old Interface + missing dependency
    pats = {t["pattern"] for t in rep["taint"]}
    for p in ("RegisterAllEvents", "SetBackdrop", "PlaySound-string", "secure-attribute-unguarded"):
        assert p in pats, (p, pats)
    assert any("UnitHealth" in f["message"] and f["level"] in ("error", "warn") for f in rep["secretFlow"]), rep["secretFlow"]
    assert "## TOC" in md and "restricted-event" in md

    # unit level: local upvalue caching (local UnitBuff = UnitBuff), shadowing, global overwrite, addon-owned globals
    d = Dump.load(SV)
    m = migrate.Migrator(d)
    tmp = tempfile.mkdtemp()
    with open(os.path.join(tmp, "T.toc"), "w") as f:
        f.write("## Interface: 16001\n## SavedVariables: TDB\nT.lua\n")
    with open(os.path.join(tmp, "T.lua"), "w") as f:
        f.write("local select, UnitBuff,\n      GetSpellInfo = select, UnitBuff,\n      GetSpellInfo\n"
                "local n = UnitBuff('player', 1)\n"
                "local function GetItemGem() return 1 end\nGetItemGem()\n"
                "MyAddonThing = {}\nMyAddonThing.x = 1\n"
                "function CreateFrame() end\n")
    r = m.scan(tmp)
    sites = [(s["name"], s["line"], s.get("via"), s.get("ref")) for s in r["sites"]] if "sites" in r else None
    ab = by_name(r)
    assert ab["UnitBuff"]["status"] == "signature-changed", ab.get("UnitBuff")
    lines = sorted(int(x.split(":")[1]) for x in ab["UnitBuff"]["sites"])
    assert lines == [2, 4], lines  # the alias reference and the call through the alias, not the LHS name
    assert "GetItemGem" not in ab, "local function shadows the global"
    assert "MyAddonThing" not in ab
    assert any(t["pattern"] == "overwrites-global" and "CreateFrame" in t["message"] for t in r["taint"]), r["taint"]
    assert not [t for t in r["toc"] if t["level"] == "error"], r["toc"]
    del sites

    # fixtures command (v2.2.21 raw): the combat log and taint log are copied byte-for-byte, real GUIDs kept
    fx_out = tempfile.mkdtemp()
    sample = os.path.join(ROOT, "tests", "fixtures", "WoWCombatLog-sample.txt")
    taint = os.path.join(ROOT, "tests", "fixtures", "taint-sample.log")
    p = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "fdump.py"), "fixtures", SV, "--file", sample,
                        "--taint", taint, "-o", fx_out], capture_output=True, text=True)
    assert p.returncode == 0, p.stdout + p.stderr
    raw_log = open(os.path.join(fx_out, "WoWCombatLog.txt"), "rb").read()
    assert raw_log == open(sample, "rb").read()[:len(raw_log)] and b"Player-1234-0ABCDEF0" in raw_log
    assert b"Player-0000-00000001" not in raw_log
    assert open(os.path.join(fx_out, "taint.log"), "rb").read() == open(taint, "rb").read()
    for fn in ("environment.json", "api-surface.json", "secrets-documented.json", "combatlog_file.lua", "pack.json"):
        assert os.path.exists(os.path.join(fx_out, fn)), fn
    assert not os.path.exists(os.path.join(fx_out, "anonymization.json"))
    print("MIGRATE OK (%d APIs, %d events, %d taint, %d flow)" % (len(rep["apis"]), len(rep["events"]), len(rep["taint"]),
                                                             len(rep["secretFlow"])))


if __name__ == "__main__":
    main()
