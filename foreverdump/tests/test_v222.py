"""v2.2.2 converter checks: container schema (addon + legacy), partial-secret matrix, baseline diff; taint classification
(expected probe vs unexpected); summon/dispel truth + scoring and the cooldown recast window; inference history; identity
last name. Needs tests/out/hsm_sv.lua (tests/hsm.lua)."""
import os
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from fdump import characters as C, containers as CT, inference as I, taintlog  # noqa: E402
from fdump.dump import Dump  # noqa: E402

N = [0]


def ok(cond, msg):
    N[0] += 1
    if not cond:
        raise SystemExit("FAIL: " + msg)


# ---------------------------------------------------------------- containers: addon schema from the mock capture
sv = os.path.join(ROOT, "tests", "out", "hsm_sv.lua")
d = Dump.load(sv)
r = CT.report(d)
ok(r["source"].startswith("addon:"), "addon container schema read from ForeverDumpLogDB.containers")
ok("ooc" in r["contexts"] and any(c.startswith("combat") for c in r["contexts"]), "contexts ooc + combat: %s" % r["contexts"])
ok("player" in r["unitClasses"], "unit class player present")
md = CT.markdown(r)
ok("## Aura table, field by field" in md and "Can a clear aura COUNT" in md and "unobserved" in md, "CONTAINERS.md sections + unobserved labels")
ok("| field |" in md and "\\|" in md or "HELPFUL" in md, "markdown tables escape filter pipes")
flat = CT.flatten(r["raw"]["schema"])
ok(len(flat) > 20, "flattened schema has field paths (%d)" % len(flat))
same = CT.diff(r["raw"], r["raw"])
ok(same["changed"] == [] and same["new"] == 0 and same["gone"] == 0, "self diff is empty (stable dominant ordering)")
import copy  # noqa: E402
mod = copy.deepcopy(r["raw"])
ctx0 = next(iter(mod["schema"]))
u0 = next(iter(mod["schema"][ctx0]))
p0 = next(iter(mod["schema"][ctx0][u0]))
mod["schema"][ctx0][u0][p0]["s"] = {"S": 99}
dd = CT.diff(r["raw"], mod)
ok(len(dd["changed"]) >= 1 and dd["changed"][0]["now"] == "S", "baseline diff detects a state change")
ok(CT.group_of("party1:friendly-player") == "party/raid" and CT.group_of("pet:friendly-npc") == "pet"
   and CT.group_of("target:hostile-npc") == "target NPC" and CT.group_of("target:self") == "self via other token", "unit-class groups")
gj = CT.guide_json(r)
ok(gj["schema"] == "foreverdump.containers/1" and "auraMatrix" in gj and "countMatrix" in gj, "guide JSON shape")

# legacy (<= 2.2.1) schema from combat probe cells + UNIT_AURA payload codes
legacy = {"combatProbe": {
    "cells": {"combat": {"player": {"aura:GetAuraDataByIndex[HELPFUL]": {"n": 3, "e": 3, "err": "Auras cannot be accessed when secret while tainted", "r": {}}}},
              "ooc": {"player": {"aura:GetAuraDataByIndex[HELPFUL]": {"n": 2, "r": [{"K": 2}], "f": {"spellId": {"C": 2}, "auraInstanceID": {"C": 2}}}}}},
    "events": {"combat": {"player": {"UNIT_AURA": {"n": 4, "r": {2: {"T": 4}}, "f": {"addedAuras": {"S": 3, "N": 1}, "isFullUpdate": {"S": 4}}}}}}}}
lr = CT.from_legacy(legacy)
am = CT.aura_matrix(lr["schema"])
ok(am[("ooc", "player")]["fields"]["spellId"] == {"C": 2}, "legacy: ooc player spellId clear")
ok(am[("combat", "player")]["table"] == {"E": 3} and am[("combat", "player")]["event"]["addedAuras"] == {"S": 3, "N": 1}, "legacy: combat API error + payload nil/secret")
ok(any(p["probe"] == "event:UNIT_AURA" for p in [{"probe": k} for k in lr["schema"]["combat"]["player"]]) and
   CT.is_partial(lr["schema"]["combat"]["player"]["event:UNIT_AURA"]), "legacy: combat UNIT_AURA payload is a partial-secret container (T)")

# ---------------------------------------------------------------- taint classification
tl = os.path.join(tempfile.mkdtemp(), "taint.log")
with open(tl, "w") as f:
    f.write("""10/7 22:02:15.000  An attempt to compare a secret value was blocked because of taint from ForeverDump - Interface/AddOns/ForeverDump/Controls.lua:155
10/7 22:02:15.000      Interface/AddOns/ForeverDump/Controls.lua:155
10/7 22:02:15.000      pcall()
10/7 22:02:16.000  An action was blocked in combat because of taint from ForeverDump -
10/7 22:02:16.000      pcall()
10/7 22:02:16.000      Interface/AddOns/ForeverDump/CombatProbe.lua:163
10/7 22:02:17.000  Execution tainted by ForeverDump while reading field oldestFadingLineTimestamp (<table: 0001>) - Interface/AddOns/Blizzard_SharedXML/ScrollingMessageFrame.lua:765
10/7 22:02:17.000      Interface/AddOns/Blizzard_SharedXML/ScrollingMessageFrame.lua:765 ChatFrame1:UpdateFading()
10/7 22:02:18.000  Execution tainted by ForeverDump while reading field b (<table: 0002>) -
10/7 22:02:18.000      AddPoint()
10/7 22:02:18.000      Interface/AddOns/ForeverDump/Lab.lua:182
""")
tr_ = taintlog.parse(tl)
by = tr_["summary"].get("byClass") or {}
ok(by.get("expected") == 1 and by.get("probe-blocked") == 1 and by.get("benign-chat") == 1 and by.get("contained") == 1,
   "taint classes expected/probe-blocked/benign-chat (v2.2.3: chat fading after ns.Print)/contained: %s" % by)
ok("classification:" in taintlog.text_summary(tr_), "taint text summary shows the classification")

# ---------------------------------------------------------------- summon / dispel truth + scoring, cooldown window
P = "Player-4618-00EB40D8"


def cl(t, sub, src=P, dst="0000000000000000", spell=None, name=None, extra=()):
    a = [t, sub, False, src, "Uglaz-R-", "0x511", "0x0", dst, "x", "0xa28", "0x0", spell, name, 8] + list(extra)
    return {"cleu": True, "sub": sub, "a": a}


fx = {"events": [cl(100.0, "SPELL_CAST_SUCCESS", spell=6391, name="Stoneclaw Totem"),
                 cl(100.0, "SPELL_SUMMON", dst="Creature-0-1-2-3-3912-01", spell=6391, name="Stoneclaw Totem"),
                 cl(108.0, "UNIT_DIED", src="0000000000000000", dst="Creature-0-1-2-3-3912-01"),
                 cl(110.0, "SPELL_CAST_SUCCESS", dst="Creature-0-1-2-3-100-02", spell=370, name="Purge"),
                 cl(110.1, "SPELL_DISPEL", dst="Creature-0-1-2-3-100-02", spell=370, name="Purge", extra=[1234, "Buff", 1, "BUFF"]),
                 cl(200.0, "SPELL_CAST_SUCCESS", spell=6391, name="Stoneclaw Totem"),
                 cl(5000.0, "SPELL_CAST_SUCCESS", spell=6391, name="Stoneclaw Totem")]}
tr = I.truth(fx, P)
ok(len(tr["summons"]) == 1 and tr["summons"][0]["end"] == 108.0 and len(tr["dispels"]) == 1, "truth: SPELL_SUMMON -> UNIT_DIED lifetime, SPELL_DISPEL")
rows = I.score_predictions([{"t": 100.0, "spell": 6391, "unit": "player", "summon": {"duration": 15}, "cooldownEnds": 130.0},
                            {"t": 110.0, "spell": 370, "dispel": True},
                            {"t": 200.0, "spell": 6391, "cooldownEnds": 230.0}], tr)
s0 = rows[0]["checks"]["summon"]
ok(s0["present"] and s0["actual"] == 8.0 and s0["errorSec"] == -7.0 and any("summon-ended-early" in f for f in rows[0]["failures"]),
   "summon scored: present, lifetime 8 s vs 15 predicted -> ended early")
ok(rows[1]["checks"]["dispel"]["result"] == "SPELL_DISPEL", "dispel prediction verified by SPELL_DISPEL")
ok(rows[0]["checks"]["cooldown"].get("noRecastInWindow") and rows[2]["checks"]["cooldown"].get("noRecastInWindow"),
   "cooldown: recast 70 s / 4770 s after a 30 s cd is outside the window -> unverified, no error")
summ, _ = I.summarize_predictions(rows)
cdrow = [x for x in summ if x["kind"] == "cooldown"][0]
ok(cdrow["meanAbsErrorSec"] is None and cdrow["pending"] == 2, "cooldown mean error no longer inflated by out-of-window recasts")
evs, _ = I.replay_stream(fx, P, "secret-pretrained", {6391: {"summon": {"duration": 15}}})
ok(any(e.get("k") == "learn" and e.get("summon") for e in evs), "pretrained replay seeds tooltip summon lifetimes")
ok(not any(e.get("k") == "learn" and e.get("cooldown", 0) > 180 for e in evs), "replay ignores recast gaps > 180 s as cooldowns")

# ---------------------------------------------------------------- inference history + identity last name
# v2.2.11: FD_Logs ON wipes the previous capture, so history lives inside one capture (restart/resume); hsm.lua
# saves that side capture separately
dh = Dump.load(os.path.join(ROOT, "tests", "out", "hsm_history_sv.lua"))
infh = dh.log.get("inference") or {}
ok(isinstance(infh.get("history"), list) and len(infh["history"]) >= 1 and infh["history"][-1].get("predictions"),
   "SV keeps inference history (with predictions)")
inf = d.log.get("inference") or {}
res = I.analyze(d, None, None)
ok(res["addon"] is not None, "analyze reads the addon inference block")


class Stub:
    def __init__(self, identity):
        self._m = {"identity": identity}
        self.log, self.combatlog = {}, {"sessions": []}

    def meta(self):
        return self._m


idn = C.identity_from_dump(Stub({"name": "Uglaz", "nameRealm": "Doomaxe", "fullNameRealm": "Doomaxe", "realm": "Classic Beta PvE",
                                 "normalizedRealm": "ClassicBetaPvE", "unitNameWithRealm": "Uglaz Doomaxe", "guid": "Player-4618-00EB40D8"}))
ok(idn["first"] == "Uglaz" and idn["last"] == "Doomaxe" and idn["display"] == "Uglaz Doomaxe", "identity: 2.2.1 SV (first, last) -> last name")
idn2 = C.identity_from_dump(Stub({"name": "Pally", "nameRealm": "ClassicBetaPvE", "normalizedRealm": "ClassicBetaPvE", "guid": "Player-1"}))
ok(idn2["last"] is None, "identity: a realm in the second return is not a last name")

print("V222 CONVERTER OK (%d checks)" % N[0])
