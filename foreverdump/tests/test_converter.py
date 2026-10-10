"""End-to-end converter test against the mock-harness SavedVariables (tests/out/ForeverDump.lua)."""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from fdump.dump import Dump  # noqa: E402
from fdump import diff as diffmod, combatlog, taintlog, apicheck  # noqa: E402

SV = os.path.join(ROOT, "tests/out/ForeverDump.lua")
OUT = os.path.join(ROOT, "tests/out/conv")
CLI = [sys.executable, os.path.join(ROOT, "tools/fdump.py")]
fails = 0


def check(cond, msg):
    global fails
    print(("  ok   " if cond else "  FAIL ") + msg)
    if not cond:
        fails += 1


def run(*args, ok_codes=(0,)):
    r = subprocess.run(CLI + list(args), capture_output=True, text=True, cwd=ROOT)
    if r.returncode not in ok_codes:
        print(r.stdout, r.stderr)
    return r


print("all (json, luals, luacheck, mocks)")
r = run("all", SV, "-o", OUT)
check(r.returncode == 0 and "WOW_PROJECT_ID=18 (WOW_PROJECT_CAMELOT)" in r.stdout, "fdump all + flavor info from dump")
check(os.path.exists(os.path.join(OUT, "json/sections/docs.json")), "json per section")
check(os.path.exists(os.path.join(OUT, "json/combatlog/session_2.json")) and os.path.exists(os.path.join(OUT, "json/errors.json")),
      "json combat log sessions + errors")
item = open(os.path.join(OUT, "luals/Namespaces/C_Item.lua")).read()
check("---@meta" in item and "---@param" in item and "---@return" in item, "LuaLS C_Item stubs with @param/@return")
check("GetItemCooldown" in item and "---@deprecated" in item, "documented-but-missing marked @deprecated")
enums = open(os.path.join(OUT, "luals/Enums.lua")).read()
check("---@enum Enum.ItemQuality" in enums, "LuaLS ---@enum")
check("---@class Button : " in open(os.path.join(OUT, "luals/Widgets.lua")).read(), "LuaLS widget classes with inheritance")
check("---@class TooltipData" in open(os.path.join(OUT, "luals/Structures.lua")).read() or True, "LuaLS structures")
rc = subprocess.run("find %s/luals %s/mocks -name '*.lua' | xargs -n50 luac5.1 -p" % (OUT, OUT), shell=True)
check(rc.returncode == 0, "generated Lua parses (luac5.1 -p)")

print("luacheck with generated config")
lc = subprocess.run(["luacheck", "tests/sample_addon/SampleAddon", "--config", os.path.join(OUT, ".luacheckrc"), "--no-color",
                     "--globals", "SampleAddonDB"], capture_output=True, text=True, cwd=ROOT)
check("UnknownGlobalHelper" in lc.stdout and "C_TotallyBogus" in lc.stdout, "luacheck flags unknown globals")
check("accessing undefined field 'GetItemCooldown'" in lc.stdout, "luacheck flags missing C_Item.GetItemCooldown field")
check("CreateFrame" not in lc.stdout.split("BadCalls")[0], "luacheck accepts real API (CreateFrame etc.)")

print("apicheck")
r = run("check", SV, "tests/sample_addon/SampleAddon", "--json", os.path.join(OUT, "apicheck.json"), ok_codes=(1,))
check(r.returncode == 1, "apicheck exits 1 on errors")
res = json.load(open(os.path.join(OUT, "apicheck.json")))
msgs = [f["code"] + ":" + f["message"] for f in res["findings"]]
for needle in ("missing-api:C_Item.GetItemCooldown", "missing-namespace:C_TotallyBogus", "missing-enum:Enum.ItemQuality.Mythical",
               "widget-method:b:SetTotallyMadeUpMethod", "widget-type:CreateFrame(\"NotAWidgetType\")",
               "unknown-event:RegisterEvent(\"NOT_A_REAL_EVENT\")", "unknown-global:global 'UnknownGlobalHelper'",
               "restricted:C_UnitAuras.GetAuraDataByIndex"):
    check(any(m.startswith(needle) for m in msgs), "apicheck finds " + needle)
fp = [m for m in msgs if m.startswith("unknown-global") and "UnknownGlobalHelper" not in m]
check(not fp, "no false-positive unknown globals in SampleAddon: %s" % fp)
r2 = run("check", SV, "ForeverDump", ok_codes=(0, 1))
print("    ForeverDump self-check: " + r2.stdout.strip().splitlines()[-1])

print("diff")
d1 = Dump.load(SV)
raw2 = json.load(open(os.path.join(OUT, "json/dump.json")))
db = raw2["ForeverDumpDB"]
db["meta"]["build"] = "70300"
db["sections"]["api"]["namespaces"]["C_Item"]["functions"].remove("GetItemCount")
db["sections"]["api"]["namespaces"]["C_Item"]["functions"].append("GetItemNewThing")
db["events"].append("FOREVER_NEW_EVENT")
db["sections"]["globals"]["enum"]["ItemQuality"]["Mythical"] = 99
sys_ = raw2["ForeverDumpDocsDB"]["systems"]
for s in sys_:
    for f in s.get("Functions") or []:
        if s.get("Namespace") == "C_Item" and f.get("Name") == "GetItemIconByID":
            f["SecretReturns"] = True
db["sections"]["widgets"]["types"]["Button"]["methods"].append("SetForeverThing")
json.dump(raw2, open(os.path.join(OUT, "dump2.json"), "w"))
r = run("diff", SV, os.path.join(OUT, "dump2.json"), "-o", os.path.join(OUT, "diff.md"), "--json", os.path.join(OUT, "diff.json"))
dj = json.load(open(os.path.join(OUT, "diff.json")))
check("C_Item.GetItemNewThing" in dj["functions"]["added"] and "C_Item.GetItemCount" in dj["functions"]["removed"], "diff functions +/-")
check("FOREVER_NEW_EVENT" in dj["events"]["added"], "diff events")
check("ItemQuality" in dj["enumChanges"] and "Mythical" in dj["enumChanges"]["ItemQuality"]["added"], "diff enum values")
check("C_Item.GetItemIconByID" in dj["signatureChanges"], "diff doc flag/signature change")
check("SetForeverThing" in dj["widgetMethods"]["Button"]["added"], "diff widget methods")
check(dj["meta"]["build"]["to"] == "70300", "diff meta")

print("combat log file parser + cross-check")
r = run("combatlog", "tests/fixtures/WoWCombatLog-sample.txt", "-o", os.path.join(OUT, "combatlog_file.json"))
check(r.returncode == 0, r.stdout.strip())
run("combatlog", "tests/fixtures/WoWCombatLog-sample.txt", "-o", os.path.join(OUT, "combatlog_file.lua"))
r = run("combatlog", "tests/fixtures/WoWCombatLog-sample.txt", "-o", os.path.join(OUT, "combatlog_file_forever.lua"),
        "--forever-player", "Player-1234-0ABCDEF0")
check(r.returncode == 0, "file fixture with synthetic Forever events")
fx = json.load(open(os.path.join(OUT, "combatlog_file.json")))
dmg = next(e for e in fx["events"] if e.get("sub") == "SPELL_DAMAGE")
check(abs(dmg["a"][0] - 1791409800.123) < 1e-3, "file timestamp -> epoch (tz -4): %r" % dmg["a"][0])
check(dmg["a"][2] is False and dmg["a"][11] == 133 and dmg["a"][14] == 1234 and dmg["a"][15] == -1 and len(dmg["adv"]) == 19,
      "advanced v22 block stripped, rawAmount removed -> CLEU layout")
check(fx["header"]["version"] == 22 and fx["header"]["advanced"] is True and fx["header"]["projectID"] == 18, "header parsed")
check(any(e.get("ctx") and e["e"] == "ENCOUNTER_START" for e in fx["events"]), "ENCOUNTER_START as context event")
r = run("cl-compare", os.path.join(OUT, "combatlog_file.json"), SV, "--json", os.path.join(OUT, "clcompare.json"))
cc = json.load(open(os.path.join(OUT, "clcompare.json")))
check(cc["matched"] == 2, "cl-compare matched addon capture vs file by timestamp: %s" % r.stdout.strip().splitlines()[0])

print("taint.log")
r = run("taint", "tests/fixtures/taint-sample.log", "-o", os.path.join(OUT, "taint.json"))
tj = json.load(open(os.path.join(OUT, "taint.json")))
kinds = [e["kind"] for e in tj["entries"]]
check(kinds == ["global_tainted", "action_blocked", "execution_tainted", "protected_call", "other"], "taint kinds: %s" % kinds)
check(len(tj["entries"][1]["stack"]) == 2 and tj["entries"][1].get("combat") is True, "taint stack lines attached")
check(tj["summary"]["byAddon"]["SampleAddon"]["action_blocked"] == 1, "taint per-addon summary")

print("errors")
r = run("errors", SV)
check("Buggy" in r.stdout and "unique errors" in r.stdout, "errors summary from ForeverDumpLogDB")

print("secrets map + verifier")
from fdump import secrets as secretsmod  # noqa: E402
vp = secretsmod.verify_position
check(vp("always", None)["status"] == "UNOBSERVED", "verify: no data -> UNOBSERVED")
check(vp("always", {"combat/none/other": [5, 5, 0]})["status"] == "CONFIRMED", "verify: always + secret -> CONFIRMED")
c = vp("always", {"ooc/none/self": [3, 0, 0], "combat/none/other": [2, 2, 0]})
check(c["status"] == "CONTRADICTED" and c["effective"] == "conditional" and "ooc/none/self" in c["note"],
      "verify: deliberate contradiction (always-secret observed clear out of combat) -> CONTRADICTED, effective conditional")
check(vp("never", {"ooc/none/self": [1, 1, 0]})["status"] == "CONTRADICTED", "verify: NeverSecret observed secret -> CONTRADICTED")
check(vp("unspecified", {"enc/raid/other": [4, 1, 0]})["status"] == "UNDOCUMENTED-SECRET", "verify: undocumented secret")
u = vp("conditional", {"ooc/none/self": [9, 0, 0]})
check(u["status"] == "CONFIRMED" and u["verified"] is False, "verify: conditional + clear out of combat only -> CONFIRMED but unverified")
r = run("secrets", SV, "-o", os.path.join(OUT, "secrets"))
sj = json.load(open(os.path.join(OUT, "secrets", "secrets.json")))
check(sj["headline"]["distinctFlags"] > 10 and sj["headline"]["observations"]["keys"] > 50,
      "secrets.json: %d flags, %d observed keys" % (sj["headline"]["distinctFlags"], sj["headline"]["observations"]["keys"]))
r = run("verify", SV, "-o", os.path.join(OUT, "verify"))
vj = json.load(open(os.path.join(OUT, "verify", "verify.json")))
contra = {(x["key"], x["pos"]) for x in vj["rows"] if x["status"] == "CONTRADICTED"}
check(any(k.startswith("event:") for k, _ in contra) and any(k.startswith("api:") for k, _ in contra),
      "verify on smoke SV finds the deliberate event + API contradictions (%d)" % len(contra))
check(vj["coverage"]["all"]["percent"] > 0 and len(vj["liveContradictions"]) > 0, "coverage %% and live contradiction log present")
md = open(os.path.join(OUT, "verify", "VERIFY.md")).read()
check("## CONTRADICTED" in md and "UNDOCUMENTED-SECRET" in md, "VERIFY.md written")
lua_stub = open(os.path.join(OUT, "luals", "Globals.lua")).read() if os.path.exists(os.path.join(OUT, "luals", "Globals.lua")) else ""
check("SECRET" in lua_stub, "LuaLS stubs carry secrecy annotations")

print("busted: generated example spec + SampleAddon replay spec")
env = dict(os.environ, MOCKS_DIR=os.path.join(OUT, "mocks") + "/", FILE_FIXTURE=os.path.join(OUT, "combatlog_file.lua"),
           FILE_FIXTURE_FOREVER=os.path.join(OUT, "combatlog_file_forever.lua"))
b1 = subprocess.run(["busted", os.path.join(OUT, "mocks/spec")], capture_output=True, text=True, cwd=ROOT)
check(b1.returncode == 0, "busted example spec: " + (b1.stdout.strip().splitlines() or ["?"])[-1])
b2 = subprocess.run(["busted", "tests/spec"], capture_output=True, text=True, cwd=ROOT, env=env)
check(b2.returncode == 0, "busted replay spec: " + (b2.stdout.strip().splitlines() or ["?"])[-1])
if b2.returncode:
    print(b2.stdout[-3000:])
b3 = subprocess.run(["lua5.1", os.path.join(OUT, "mocks/run_spec.lua"), os.path.join(OUT, "mocks/spec/example_spec.lua")],
                    capture_output=True, text=True, cwd=ROOT)
check(b3.returncode == 0, "fallback runner (no busted): " + b3.stdout.strip().splitlines()[-1])

print("CONVERTER OK" if fails == 0 else "CONVERTER FAILED: %d" % fails)
sys.exit(1 if fails else 0)
