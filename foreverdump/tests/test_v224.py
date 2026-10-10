"""v2.2.4 checks (run 5): coverage matrix + live attribution replay (before/after) on a synthetic capture where another
player hits my target, C_DamageMeter reconciliation, PERF.md honours table caps, guide --coverage section + DM rows in
combat.json, and no names/GUIDs in the guide JSON. Needs lua5.1 (the replay runs the addon's own HybridState.lua)."""
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from fdump import coverage as cov, perf as perfmod, guidejson  # noqa: E402
from fdump.dump import Dump  # noqa: E402

N = [0]


def ok(cond, msg):
    N[0] += 1
    if not cond:
        raise SystemExit("FAIL: " + msg)


ME = "Player-1-0000AAAA"
OTHER = "Player-1-0000BBBB"
MOB = "Creature-0-1-1-1-100-0000000A"
E0 = 1000.0   # epoch = 1000 + gameTime


def cl(t, sub, src, dst, *rest):
    sname = {ME: "Me", OTHER: "Other"}.get(src, "Mob")
    dname = {ME: "Me", OTHER: "Other"}.get(dst, "Mob")
    sflags = 0x511 if src == ME else (0x518 if src == OTHER else 0xa48)
    return {"cleu": True, "sub": sub, "t": E0 + t, "a": [E0 + t, sub, False, src, sname, sflags, 0, dst, dname, 0xa48, 0] + list(rest)}


def spell_dmg(t, src, sid, name, school, amt, crit=None):
    return cl(t, "SPELL_DAMAGE", src, MOB, sid, name, school, amt, -1, school, 0, 0, 0, crit, None, None)


fx = {"events": [
    cl(10.0, "SPELL_CAST_SUCCESS", ME, MOB, 8056, "Frost Shock", 16),
    spell_dmg(11.0, ME, 8056, "Frost Shock", 16, 105, 1),
    cl(12.0, "SPELL_PERIODIC_DAMAGE", ME, MOB, 8052, "Flame Shock", 4, 8, -1, 4, 0, 0, 0, None, None, None),
    cl(13.0, "SWING_DAMAGE", ME, MOB, 119, -1, 1, 0, 0, 0, None, None, None),
    cl(13.5, "SPELL_CAST_START", OTHER, "0000000000000000", 8406, "Frostbolt", 16),
    spell_dmg(14.0, OTHER, 8406, "Frostbolt", 16, 177),
    cl(15.0, "SWING_DAMAGE", MOB, ME, 50, -1, 1, 0, 0, 0, None, None, None),
]}
# SPELL_CAST_SUCCESS at 10.0 does not damage; the Frost Shock damage lands at 11.0 with the live SUCCEEDED (same frame)
fx["events"][0]["t"] = fx["events"][0]["a"][0] = E0 + 11.0
fx["events"].sort(key=lambda e: e["t"])

ev = [
    {"t": 9.0, "e": "PLAYER_REGEN_DISABLED", "a": {}},
    {"t": 11.0, "e": "UNIT_SPELLCAST_SUCCEEDED", "a": ["player", "Cast-1", 8056]},
    {"t": 11.0, "e": "DAMAGE_METER_COMBAT_SESSION_UPDATED", "a": [0, 3]},
    {"t": 11.0, "e": "UNIT_COMBAT", "a": ["target", "WOUND", "CRITICAL", 105, 16]},
    {"t": 12.0, "e": "DAMAGE_METER_COMBAT_SESSION_UPDATED", "a": [0, 3]},
    {"t": 12.0, "e": "UNIT_COMBAT", "a": ["target", "WOUND", "", 8, 4]},
    {"t": 13.0, "e": "PLAYER_SWING", "a": [3.3, 0]},
    {"t": 13.0, "e": "DAMAGE_METER_COMBAT_SESSION_UPDATED", "a": [0, 3]},
    {"t": 13.458, "e": "UNIT_COMBAT", "a": ["target", "WOUND", "", 119, 1]},
    {"t": 14.01, "e": "UNIT_COMBAT", "a": ["target", "WOUND", "", 177, 16]},
    {"t": 15.4, "e": "UNIT_COMBAT", "a": ["player", "WOUND", "", 50, 1]},
    {"t": 20.0, "e": "PLAYER_REGEN_ENABLED", "a": {}},
]
signals = [
    {"t": 8.0, "e": "target", "guid": MOB},
    {"t": 11.0, "e": "cast", "ev": "SUCCEEDED", "unit": "player", "sid": 8056, "target": MOB},
]
snap = {"inCombat": False, "gameTime": 20.6, "time": 1020, "byType": {
    "DamageDone": {"durationSeconds": 11, "totalAmount": 232, "combatSources": [{"isLocalPlayer": True, "totalAmount": 232}]},
    "HealingDone": {"durationSeconds": 11, "totalAmount": 0, "combatSources": []},
    "Interrupts": {"durationSeconds": 11, "totalAmount": 0, "combatSources": []},
    "DamageTaken": {"durationSeconds": 11, "totalAmount": 50, "combatSources": [{"isLocalPlayer": True, "totalAmount": 50}]}}}
anchor = {"epochTick": E0, "gameTimeTick": 0.0}
raw = {"ForeverDumpDB": {"addonVersion": "2.2.4"},
       "ForeverDumpCombatLogDB": {"sessions": [{"anchor": anchor, "events": ev, "damageMeter": [snap]}]},
       "ForeverDumpLogDB": {"inference": {"anchor": anchor, "signals": signals, "inputs": {"combat": {"unitCast.spellID": {"r": 0, "u": 2}}}},
                            "damageMeter": {"schema": {"combat": {"GetCombatSessionFromType": {"S": 1}, "CombatSource.totalAmount": {"S": 1}},
                                                       "after-combat": {"CombatSource.totalAmount": {"C": 1}}}}}}
dump = Dump(raw)
res = cov.analyze(dump, fx, ME)
b, a = res["replay"]["before"]["scores"], res["replay"]["after"]["scores"]
d = a["damage-on-target"]
ok(d["scorable"] == 4 and d["accuracy"] == 100.0 and d.get("falseSelf", 0) == 0, "after: 4/4 hits on my target attributed correctly (cast-frame, dm-frame, swing-lag, other)")
ok(b["damage-on-target"]["coverage"] == 0.0, "before (v2.2.3 library): no damage attribution at all")
ok(res["naive"]["falseSelf"] == 1 and res["naive"]["falseSelfAmount"] == 177, "naive 'all on my target is mine' credits the other player's 177 to me")
ok(a["damage-taken"]["accuracy"] == 100.0, "damage taken: hostile source")
op = res["otherPlayer"]
ok(op and op["otherDamageLog"] == 177 and op["otherDamageLive"] == 177 and not op["falseSelf"] and op["others"] == ["other player A"],
   "other-player section: log 177 vs live 'other' 177, labelled anonymously")
rc = res["damageMeter"]["reconcile"][0]
ok(rc["logMine"] == 232 and rc["dmMine"] == 232 and rc["logOtherOnTargets"] == 177 and rc["dmOthers"] == 0,
   "DM reconcile: my damage log = DM; the ungrouped player is absent from the meter")
rec = res["replay"]["after"]["reconcile"]
ok(rec and rec[0]["dmMine"] == 232 and rec[0]["liveMine"] == 232 and rec[0]["othersOnTarget"] == 177, "HSM ReconcileDM in the replay: others on target = live total - DM mine")
ok(res["timing"]["damage/melee"]["median"] > 0.4, "timing model: melee combat text lags the swing")
m = {(r["cat"], r["src"], r["ctx"]): r for r in res["matrix"]}
ok(m[("damage", "player", "combat")]["visible"] == 1 and m[("damage", "player", "combat")]["spell"] == 0, "matrix: other player's hit seen live, spell not readable")
ok(m[("cast-start", "player", "combat")]["visible"] == 0, "matrix: other player's cast start invisible live (no token)")
ok(m[("damage", "me", "combat")]["spell"] >= 1, "matrix: my spell damage tied to a clear spellID (same-frame cast)")
md = cov.markdown(res)
ok("## Live attribution" in md and "## C_DamageMeter" in md and "other player A" in md, "COVERAGE.md sections")
gj = cov.guide_json(res, "70245", "test")
blob = json.dumps(gj)
ok(ME not in blob and OTHER not in blob and MOB not in blob and '"Other"' not in blob and '"Me"' not in blob, "guide JSON has no GUIDs or names")

# ---------------------------------------------------------------- guide: --coverage section + DM observations in combat.json
tmp = tempfile.mkdtemp()
gp = os.path.join(tmp, "coverage-guide.json")
with open(gp, "w") as f:
    json.dump(gj, f)
html = os.path.join(tmp, "g.html")
r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "guide", "build_guide.py"), "--coverage", gp, "--out", html], capture_output=True, text=True)
ok(r.returncode == 0, "guide builds with --coverage: " + r.stderr[-300:])
h = open(html, encoding="utf-8").read()
ok("id='coverage'" in h and "Live attribution: before / after" in h and "C_DamageMeter vs the log" in h, "guide coverage section rendered")
cj = guidejson.combat(dump, "70245", "test")
dmobs = [o for o in cj["observations"] if o["item"].startswith("damageMeter.")]
ok(any(o["item"] == "damageMeter.GetCombatSessionFromType" and o["code"] == "S" and o["context"] == "combat" for o in dmobs)
   and any(o["item"] == "damageMeter.CombatSource.totalAmount" and o["code"] == "C" and o["context"] == "ooc" for o in dmobs),
   "combat.json: DM classification per context (secret in combat, clear after combat)")

# ---------------------------------------------------------------- PERF.md: capped tables are not "still growing"
samples = [{"t": i * 5, "sz": {"hsm.inferences": i, "unbounded": i}} for i in range(30)]
rep = perfmod.analyze_session({"sid": "s", "handlers": {}, "samples": samples, "bounds": {"hsm.inferences": 2500}}) \
    if hasattr(perfmod, "analyze_session") else None
if rep is None:
    class D:
        log = {"perf": {"sessions": [{"sid": "s", "start": 0, "stop": 150, "handlers": {}, "samples": samples, "bounds": {"hsm.inferences": 2500}}]}}
        db = {"addonVersion": "2.2.4"}
        record, combatlog, sections = {}, {}, {}
    rep = perfmod.analyze(D())
    flags = [f for s in rep["sessions"] for f in s["flags"]]
else:
    flags = rep["flags"]
ok(any("unbounded" in f for f in flags) and not any("hsm.inferences" in f for f in flags), "PERF.md flags only uncapped growth")

# ---------------------------------------------------------------- addon: version + DamageMeter in the TOC after Inference
toc = open(os.path.join(ROOT, "ForeverDump", "ForeverDump.toc")).read().split()
ok("2.2.4" in open(os.path.join(ROOT, "ForeverDump", "Core.lua")).read() and toc.index("DamageMeter.lua") > toc.index("Inference.lua"),
   "v2.2.4 + DamageMeter.lua loads after Inference.lua")
src = open(os.path.join(ROOT, "ForeverDump", "DamageMeter.lua")).read()
ok("OnUpdate" not in src.replace("no OnUpdate", "") and "COMBAT_LOG_EVENT" not in src, "DamageMeter.lua: no OnUpdate, no CLEU")
print("test_v224: %d checks passed" % N[0])
