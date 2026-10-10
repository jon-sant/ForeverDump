"""v2.2 converter tests: combat/tokens/lab/ops/knowledge reports, guide JSON schemas (tools/guide/README.md), drift,
inference + HSM replay (mock log; plus the run-2 Barrens log when present), the guide build, Lua/Python docs hash parity.
Needs tests/out/ForeverDump.lua (smoke.lua) and tests/out/hsm_sv.lua (hsm.lua)."""
import json
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
sys.path.insert(0, os.path.join(ROOT, "tools", "guide"))
from fdump.dump import Dump  # noqa: E402
from fdump import drift, guidejson, inference, probes  # noqa: E402
from fdump.expect import Inventory  # noqa: E402
from fdump import combatlog  # noqa: E402
import guide_data as G  # noqa: E402

N = [0]


def ok(cond, msg):
    N[0] += 1
    if not cond:
        raise SystemExit("FAIL: " + msg)


SMOKE = os.path.join(ROOT, "tests", "out", "ForeverDump.lua")
HSMSV = os.path.join(ROOT, "tests", "out", "hsm_sv.lua")
MOCKLOG = os.path.join(ROOT, "tests", "fixtures", "WoWCombatLog-sample.txt")
BARRENS = os.path.join(ROOT, "real", "2026-10-07-run2", "WoWCombatLog.txt")
CTXS = {"ooc", "combat", "restricted"}
UNITS = {"player", "target_hostile_npc", "friendly_npc", "other_player", "party_raid", "nameplate", "any"}
CODE_RX = re.compile(r"^[CSEXNP]\??$")
ITEM_IDS = {i["id"] for i in G.COMBAT_ITEMS} | {d[0] for d in G.DETECT}

smoke, hsv = Dump.load(SMOKE), Dump.load(HSMSV)

# docs hash parity (Baseline.lua FNV-1a vs drift.fnv_hash)
lua_docs = (smoke.log.get("baseline") or {}).get("docs") or {}
ok(lua_docs.get("hash") == drift.docs_signatures(smoke)[0]["hash"], "Lua/Python docs hash differ: %s" % lua_docs)

# combat/1 schema
cj = guidejson.combat(hsv, guidejson.build_label(hsv), guidejson.captured(hsv))
ok(cj["schema"] == "foreverdump.combat/1" and set(cj) == {"schema", "build", "captured", "source", "items", "observations"}, "combat keys")
ok(set(cj["items"]) <= ITEM_IDS, "unknown item ids %s" % (set(cj["items"]) - ITEM_IDS))
for item, byU in cj["items"].items():
    for u, byC in byU.items():
        ok(u in UNITS and (not item.startswith("det.") or u == "any"), "unit class %s/%s" % (item, u))
        for c, cell in byC.items():
            ok(c in CTXS and CODE_RX.match(cell["code"]) and set(cell) <= {"code", "n", "api", "note"}, "cell %s %s %s %s" % (item, u, c, cell))
for o in cj["observations"]:
    ok(o["unit"] in UNITS and o["context"] in CTXS and CODE_RX.match(o["code"]) and o["item"] not in ITEM_IDS, "obs %s" % o)
ok({"health.current", "cast.info", "det.cast.self", "det.aura.mine"} <= set(cj["items"]), "core combat items present")
ok(cj["items"]["health.current"]["target_hostile_npc"]["combat"]["code"] == "S", "target health secret in combat")
ok(any(o["item"].startswith("unitToken.") for o in cj["observations"]), "token survey folded into observations")
lab = guidejson.lab(hsv)
ok(set(lab) == {"lab", "controls"} and isinstance(lab["lab"], list) and lab["lab"] and "items" in lab["lab"][0], "lab json")
ok(isinstance(lab["controls"], list) and lab["controls"] and "ops" in lab["controls"][0], "controls json")

# reports
res = probes.combat(hsv, Inventory())
md = probes.combat_markdown(res)
ok("Is it casting/channelling?" in md and "MY buff/debuff?" in md, "detectability tables")
tk = probes.tokens(hsv)
fams = {f["family"] for f in tk["families"]}
ok({"player", "target", "party", "raid", "nameplate", "boss", "arena", "targettarget"} <= fams, "token families %s" % sorted(fams))
ok("token works?" in probes.tokens_markdown(tk), "tokens md")
kn = probes.knowledge(hsv)
ok(kn and "Spell knowledge" in probes.knowledge_markdown(kn), "knowledge")
ok(probes.ops(smoke) and "| " in probes.ops_markdown(probes.ops(smoke)), "ops")
ok("Porting patterns for secret values" in probes.lab_markdown(probes.lab(smoke)), "lab porting patterns")

# drift: self-compare is clean; a flipped secrecy key shows up as newly secret
b = drift.from_dump(smoke)
r = drift.compare(b, b)
ok(not r["newlySecret"] and not r["apisAdded"] and not r["buildBump"], "self drift clean")
b2 = json.loads(json.dumps(b))
b2["build"] = 99999
k = next(iter(b2["secrecy"]))
b2["secrecy"][k] = re.sub(r"[C-]", "S", b2["secrecy"][k])
r = drift.compare(b, b2)
ok(r["buildBump"] and (r["newlySecret"] or b["secrecy"][k] == b2["secrecy"][k]), "drift detects newly secret")
ok("## Summary" in drift.markdown(r), "drift md")
ok(b.get("tokens") is not None and b.get("combat") is not None, "baseline carries tokens + combat")

# inference / hsm/1 schema (mock log)
fx = combatlog.parse_file(MOCKLOG)
g, _ = inference.owner_guid(fx)
ires = inference.analyze(hsv, fx, g)
hj = inference.hsm_guide_json(ires, "1.60.1.70245", "2026-10-07T21:00:00-04:00")
ok(hj["schema"] == "foreverdump.hsm/1" and {"rules", "inputs", "predictions", "build", "captured"} <= set(hj), "hsm keys")
for row in hj["rules"]:
    ok({"id", "context", "predictions", "verified", "contradicted", "pending", "status"} <= set(row)
       and row["status"] in ("verified", "pending", "failing", "contradicted") and row["context"] in CTXS | {"enc"}, "hsm rule %s" % row)
for c, sigs in hj["inputs"].items():
    for sig, v in sigs.items():
        ok(set(v) == {"r", "u"}, "inputs shape")
for p in hj["predictions"]:
    ok(p["outcome"] in ("verified", "contradicted", "unverified") and set(p) <= {"t", "unit", "spell", "kind", "rule", "conf", "outcome", "errorSec"}, "pred %s" % p)
ok(len(hj["predictions"]) <= 40, "sample <= 40")
ok("aura presence" in inference.hsm_markdown(ires).lower() or "aura" in inference.hsm_markdown(ires), "HSM.md")
ok("Inference" in inference.inference_markdown(ires), "INFERENCE.md")

# Barrens replay (real run-2 log, owner auto-detected)
if os.path.exists(BARRENS):
    bfx = combatlog.parse_file(BARRENS)
    bg, name = inference.owner_guid(bfx)
    ok(bg == "Player-4618-00EB40D8" and name.startswith("Uglaz"), "Barrens owner %s %s" % (bg, name))
    br = inference.analyze(Dump.load(os.path.join(ROOT, "real", "2026-10-07-run2", "sv", "ForeverDump.lua")), bfx, bg)
    rp = br["replay"]
    ok(rp["clear"]["recall"]["recall"] == 100.0, "clear recall 100 (%s)" % rp["clear"]["recall"])
    ok(rp["secret-pretrained"]["recall"]["recall"] >= 50.0, "pretrained recall >= 50 (%s)" % rp["secret-pretrained"]["recall"])
    aura = [p for p in rp["secret-pretrained"]["predictions"] if p["kind"] == "aura"]
    ok(aura and all(p["bad"] == 0 for p in aura), "pretrained aura predictions all verified")
    bh = inference.hsm_guide_json(br, "1.60.1.70245", None)
    ok(bh["replayMode"] == "secret-pretrained" and all(r_["id"].startswith("replay:") for r_ in bh["rules"]), "replay rows labelled")

# guide build end to end on the mock SV (never the synthetic samples)
with tempfile.TemporaryDirectory() as td:
    out = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "fdump.py"), "guide", HSMSV, "--file", MOCKLOG, "-o", td],
                         capture_output=True, text=True)
    ok(out.returncode == 0, "fdump guide: " + out.stderr[-600:])
    html = open(os.path.join(td, "SECRETS-GUIDE.html"), encoding="utf-8").read()
    ok("0 warnings" in out.stdout and "hsm.json" in html and "combat.json" in html, "guide used our JSON")
    ok("sample.json" not in html, "no synthetic samples in the guide")
    for fn in ("lab.json", "combat.json", "hsm.json", "tokens.json", "inference.json", "verify.json"):
        ok(os.path.exists(os.path.join(td, fn)), fn)
# 255-character audit: every /run or /script snippet in the shipped docs and guide text
snips = []
for fn in ("README.md", "ADDON-USAGE.md", "INSTRUCTIONS-console.md", "SELF-HOSTING.md", "CHANGES.md", "tools/README.md",
           "tools/guide/guide_data.py", "tools/guide/README.md"):
    path = os.path.join(ROOT, fn)
    if os.path.exists(path):
        txt = open(path, encoding="utf-8").read()
        snips += [(fn, m.group(1)) for m in re.finditer(r"(?:`|<code>)(/(?:run|script) [^`<]*)", txt)]
ok(snips, "found /run snippets to audit")
for fn, sn in snips:
    ok(len(sn) <= 255, "%s: /run snippet %d chars > 255: %s" % (fn, len(sn), sn[:60]))
AUDIT = len(snips)
print("V22 CONVERTER OK (%d checks; %d /run snippets <= 255 chars)" % (N[0], AUDIT))
