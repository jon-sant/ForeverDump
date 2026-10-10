"""v2.2.4 offline tools, synthetic and fast: spell-timing seed (load, merge, promotion, conflict, idempotent, known answers,
Lua output), learned DB (from_log, from_sv drift proposals, merge, idempotent, raw seed, runtime view), TOKENS.md
(scanner matrix, dominant / mixed codes, change alerts, cost, no GUIDs), analyze leads for these (known-answer mismatch
high, conflicts / drift proposals medium). The run-5 golden checks live in tests/test_golden_run5.py."""
import copy
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from fdump import timing, learned, tokenscan, analysis  # noqa: E402

N = [0]


def ok(cond, msg):
    N[0] += 1
    if not cond:
        raise SystemExit("FAIL: " + msg)


ME = "Player-1-0000AAAA"
MOB = "Creature-0-1-1-1-4119-0000000A"


def ev(t, sub, src, dst, sid, name="X", school=8, raw=None, amount=None, extra=None):
    a = [t, sub, False, src, "Me" if src == ME else "Kobold", 0x511 if src == ME else 0xa48, 0, dst, "Me" if dst == ME else "Kobold",
         0xa48 if dst != ME else 0x511, 0, sid, name, school]
    if extra is not None:
        a += [extra, "Heal", 2]
    e = {"cleu": True, "sub": sub, "t": t, "a": a}
    if raw:
        e["raw"] = raw
    if amount is not None:
        e["rawAmount"] = amount
    return e


class FakeDump:
    def __init__(self, db=None, record=None, combatlog=None):
        self.db = db or {}
        self.record = record or {}
        self.combatlog = combatlog or {}


# ------------------------------------------------------------------ spell timing
def t_evidence(label, spells, cid=None, build="70245", date="2026-10-08"):
    return {"label": label, "id": cid or ("id-" + label), "build": build, "date": date, "spells": spells}


seed0 = timing.load_seed(None)
ok(seed0["spells"] == {} and seed0["schema"] == timing.SCHEMA, "empty seed without a file")
e1 = t_evidence("c1", {8046: {"baseGCD": 1.5, "baseCooldown": 6.0, "category": 19, "srCategory": 133, "gaps": [1.52, 1.55], "gapMin": 1.52,
                              "live": {"cdN": 2, "cdSum": 12.1}},
                       5394: {"baseGCD": 1.0, "gaps": [1.02], "gapMin": 1.02}})
s1, r1 = timing.merge(seed0, [e1])
ok(s1["spells"]["8046"]["gcd"] == 1.5 and s1["spells"]["8046"]["source"] == "api", "api baseGCD is the resolved GCD below a promoted observation")
ok(s1["spells"]["5394"]["gcd"] == 1.0 and s1["spells"]["5394"]["source"] == "known-answer", "totem: known answer 1.0 s wins")
ok("observedCooldown" not in s1["spells"]["8046"], "2 cooldown samples < threshold 3: not promoted yet")
e2 = t_evidence("c2", {8046: {"baseGCD": 1.5, "live": {"cdN": 2, "cdSum": 11.9}}})
s2, r2 = timing.merge(s1, [e2])
ok(s2["spells"]["8046"].get("observedCooldown") == 6.0 and any(p["spell"] == 8046 for p in r2["promoted"]), "4 isActive flips -> observed cooldown promoted (6.0 s)")
s3, r3 = timing.merge(s2, [e1, e2])
ok(r3.get("skipped") == ["c1", "c2"] and s3["spells"] == s2["spells"], "merge idempotent per capture id (no double counting)")
e3 = t_evidence("c3", {8046: {"baseGCD": 1.0}})
s4, r4 = timing.merge(s3, [e3])
ok(any(c["field"] == "baseGCD" and c["seed"] == 1.5 and c["new"] == 1.0 for c in r4["conflicts"]) and s4["spells"]["8046"]["baseGCD"] == 1.5,
   "differing API value -> conflict flagged, seed kept")
# known answers: totems 1.0 s, Lightning Shield 1.5 s
ka = {(r["spell"], r["capture"]): r for r in r1["knownAnswers"]}
ok(ka[(5394, "c1")]["ok"] and ka[(5394, "c1")]["known"] == 1.0, "known answer: totem 1.0 s confirmed (baseGCD 1.0, min gap 1.02)")
bad = timing.known_answer_check(s1, [t_evidence("cx", {905: {"baseGCD": 1.0}, 2484: {"gapMin": 0.6, "gapN": 1}})])
bk = {r["spell"]: r for r in bad}
ok(not bk[905]["ok"] and "baseGCD" in bk[905]["why"], "known answer: Lightning Shield reported with a 1.0 s GCD is refuted (1.5 s)")
ok(not bk[2484]["ok"] and "0.600" in bk[2484]["why"], "known answer: a cast 0.6 s after a totem refutes the 1.0 s GCD")
ok(set(timing.TOTEMS) | set(timing.LIGHTNING_SHIELD) == set(timing.KNOWN_ANSWERS), "known-answer table covers every totem + Lightning Shield rank")
md = timing.markdown(s1, r1)
ok("Known answers (totems 1.0 s, Lightning Shield 1.5 s)" in md and "| 5394 | totem | 1.0 |" in md, "known-answer table rendered")
lua = timing.to_lua(s4)
with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False) as f:
    f.write(lua)
ok(subprocess.run(["luac5.1", "-p", f.name]).returncode == 0 and "[8046] = {" in lua, "seed Lua output parses (luac -p)")
os.unlink(f.name)
with tempfile.TemporaryDirectory() as td:
    timing.write_seed(s4, os.path.join(td, "t.json"), os.path.join(td, "t.lua"))
    ok(timing.load_seed(os.path.join(td, "t.json"))["spells"]["8046"]["baseGCD"] == 1.5, "write_seed / load_seed round trip")
# the shipped seed carries the known answers
shipped = timing.load_seed()
ok(all(shipped["spells"].get(str(s), {}).get("gcd") == k["gcd"] for s, k in timing.KNOWN_ANSWERS.items()), "shipped spell-timing seed: every known answer present")

# ------------------------------------------------------------------ learned DB
fx = {"events": [
    ev(100.0, "SPELL_CAST_START", MOB, ME, 403, "Lightning Bolt"), ev(102.0, "SPELL_CAST_SUCCESS", MOB, ME, 403, "Lightning Bolt"),
    ev(102.1, "SPELL_DAMAGE", MOB, ME, 403, "Lightning Bolt", amount=31),
    ev(110.0, "SPELL_CAST_START", MOB, ME, 403, "Lightning Bolt"), ev(112.0, "SPELL_CAST_SUCCESS", MOB, ME, 403, "Lightning Bolt"),
    ev(120.0, "SPELL_CAST_SUCCESS", ME, MOB, 8052, "Flame Shock", 4), ev(120.0, "SPELL_AURA_APPLIED", ME, MOB, 8052, "Flame Shock", 4, raw=[0, 0, 0, "DEBUFF"]),
    ev(132.0, "SPELL_AURA_REMOVED", ME, MOB, 8052, "Flame Shock", 4),
    ev(140.0, "SPELL_CAST_SUCCESS", ME, MOB, 8052, "Flame Shock", 4), ev(140.1, "SPELL_AURA_APPLIED", ME, MOB, 8052, "Flame Shock", 4, raw=[0, 0, 0, "DEBUFF"]),
    ev(152.1, "SPELL_AURA_REMOVED", ME, MOB, 8052, "Flame Shock", 4),
    ev(150.0, "SPELL_CAST_START", MOB, ME, 403, "Lightning Bolt"), ev(151.0, "SPELL_CAST_SUCCESS", ME, MOB, 8046, "Earth Shock", 8),
    ev(151.0, "SPELL_INTERRUPT", ME, MOB, 8046, "Earth Shock", 8, extra=403),
]}
le = learned.from_log(fx, ME, label="L1", build="70245", date="2026-10-08")
ok(le["id"] == "log:L1" and le["spells"][403]["castT"]["npc"]["n"] == 2 and abs(le["spells"][403]["castT"]["npc"]["med"] - 2.0) < 1e-6,
   "from_log: NPC cast START->SUCCESS cast time 2.0 s (n=2)")
ok(le["npcs"][4119]["name"] == "Kobold" and le["npcs"][4119]["interrupted"].get(403) == 1, "from_log: per-NPC name (clear) + interrupted spell")
ok(le["spells"][8052]["aura"][8052]["n"] == 2 and le["spells"][8052]["aura"][8052]["kind"] == "DEBUFF", "from_log: cast -> aura mapping (Flame Shock debuff)")
ok(le["spells"][8052]["auraDur"]["n"] == 2, "from_log: aura durations measured")
again = learned.from_log(fx, ME, label="L1b", seen=set(), build="70245")
seen = set()
learned.from_log(fx, ME, label="A", seen=seen)
dup = learned.from_log(fx, ME, label="B", seen=seen)
ok(dup["events"] == 0 and again["events"] > 0, "appended logs: events shared with an earlier capture are not counted twice")
sv = FakeDump({"learned": {"70245": {"first": 1, "spells": {"8046": {"name": "Earth Shock", "by": {"player": 3}, "cast": {"player": [3, 0, 0, 0]},
                                                                      "aura": {}, "amt": {"damage": [2, 30, 40, 70]}}},
                                     "npcs": {"4119": {"name": "Kobold", "spells": {"403": 2}, "cast": {"403": [2, 2.0, 2.1, 4.1]}, "intr": {"yes": 2}}},
                                     "classes": {"MAGE": {"n": 4, "spells": {"133": 4}}}}},
               "drift": {"70245": {"changelog": [{"kind": "castTime", "key": "403", "old": 2.0, "new": 2.5, "n": 6, "date": "2026-10-08", "what": "drift"}]}}})
se = learned.from_sv(sv, label="S1")
ok(se["npcs"][4119]["interruptible"] is True and se["classes"]["MAGE"]["spells"][133] == 4, "from_sv: NPC interruptible + class catalog")
ok(se["drift"] and se["drift"][0]["new"] == 2.5, "from_sv: drift changelog carried as proposals")
ls1, lr1 = learned.merge(learned.load_seed(None), [le, se])
ok("403" in ls1["spells"] and "4119" in ls1["npcs"], "learned merge: spells + NPCs")
ok(any(p["kind"] == "castTime" and p["new"] == 2.5 for p in lr1["proposals"]), "drift proposal reported (old -> new, build, date)")
ls2, lr2 = learned.merge(ls1, [le, se])
ok(sorted(lr2["skipped"]) == sorted([le["id"], se["id"]]) or len(lr2.get("skipped", [])) == 2, "learned merge idempotent per evidence id")
ok(ls2["spells"] == ls1["spells"] and ls2["npcs"] == ls1["npcs"], "re-merge changes nothing")
dirty = copy.deepcopy(ls1)
dirty["npcs"]["4119"]["name"] = "Creature-0-1-1-1-4119-0000000A"
dirty["spells"]["403"]["note"] = "seen from Player-1-0000AAAA"
clean = learned.anonymize(dirty)
ok(clean == dirty and learned.GUID_RE.search(json.dumps(clean)), "v2.2.21: learned seed is not anonymized (raw kept)")
lua = learned.to_lua(ls1)
ok("ns.LearnedSeed" in lua and not learned.GUID_RE.search(lua) and "Player" not in lua, "learned seed Lua: no GUIDs, no players")
rv = learned.runtime_view(ls1)
ok(rv["spells"][8052]["auras"][8052] in (0, 12.0, 12.1), "runtime view: aura mapping, duration only when tight")

# ------------------------------------------------------------------ TOKENS.md
tdb = FakeDump({"tokenscan": {"70245": {
    "m": {"combat|pvp|raid": {"raidN": {"exists": {"C": 80}, "guid": {"C": 79, "S": 1}, "health": {"S": 80}},
                              "raidNtarget": {"exists": {"C": 40}, "guid": {"S": 40}}},
          "ooc|none|solo": {"target": {"exists": {"C": 5}, "guid": {"C": 5}, "health": {"C": 5}}}},
    "cost": [{"start": 1, "ms": 2.5, "slices": 30, "tokens": 300, "reads": 4800, "existing": 120, "sweeps": 1, "sweepS": 3.1,
              "maxSliceMs": 0.11, "overBudget": 0, "budgetMs": 0.12, "listSize": 303, "contexts": {"combat|pvp|raid": 2}},
             {"start": 2, "ms": 1.0, "slices": 10, "tokens": 90, "maxSliceMs": 0.15, "overBudget": 2, "budgetMs": 0.12, "contexts": {}}],
    "dup": {"party1=raidN": 3}, "alias": {"nameplateN<-raidNtarget:castGUID": 2}, "baseline": {"combat|pvp|raid/raidN/health": "S"}}},
    "drift": {"70245": {"changelog": [{"kind": "token-matrix", "key": "combat|pvp|raid/raidN/health", "old": "S", "new": "C", "date": "2026-10-09"}]}}})
tr = tokenscan.analyze(tdb)
rows = {(r["ctx"], r["family"]): r for r in tr["builds"]["70245"]["rows"]}
g = rows[("combat|pvp|raid", "raidN")]["cells"]["guid"]
ok(g["code"] == "C" and g["mixed"] and g["n"] == 80, "matrix: dominant code + mixed flag per family/field")
ok(rows[("combat|pvp|raid", "raidNtarget")]["cells"]["guid"]["code"] == "S" and rows[("combat|pvp|raid", "raidN")]["instance"] == "pvp",
   "matrix per context / instance type (BG = raid group in a pvp instance)")
tmd = tokenscan.markdown(tr)
ok("### instance `pvp`, group `raid`" in tmd and "| combat | raidN | C | C* |" in tmd, "TOKENS.md: per instance type table with codes")
ok("combat/pvp/raid" in tmd and "| combat|pvp" not in tmd.split("## Change alerts")[1], "context keys escaped inside tables")
ok("party1=raidN" in tmd and "nameplateN<-raidNtarget:castGUID" in tmd, "TOKENS.md: dedupe pairs + alias learning")
tl = tokenscan.leads(tr)
ok(any(x[1] == "token matrix change" and x[0] == "medium" for x in tl) and any(x[1] == "token scan over budget" for x in tl),
   "leads: matrix change alert (medium) + over-budget slices")
ok(not learned.GUID_RE.search(tmd), "TOKENS.md holds no GUIDs")
ok("No scanner data" in tokenscan.markdown(tokenscan.analyze(FakeDump({}))), "pre-2.2.4 dump: scanner absence stated")

# ------------------------------------------------------------------ analyze leads
ctx = {"label": "x", "timing": {"report": {"knownAnswers": bk and bad, "conflicts": r4["conflicts"], "promoted": r2["promoted"]}},
       "learned": {"report": lr1}, "tokens": tr}
L = analysis.leads(ctx)
kinds = {(x["severity"], x["kind"]) for x in L}
ok(("high", "known-answer mismatch") in kinds, "analyze: known-answer mismatch is a high lead")
ok(("medium", "timing conflict") in kinds and ("medium", "drift proposal") in kinds, "analyze: timing conflicts + drift proposals are medium leads")
ok(("medium", "token matrix change") in kinds, "analyze: token matrix change alert lead")
ok(L[0]["severity"] == "high", "leads ranked by severity")

# ------------------------------------------------------------------ correlate (synthetic: planted link must be found, noise must not)
from fdump import correlate, misses, verify_live, knowlint  # noqa: E402
import random  # noqa: E402
rnd = random.Random(7)
A, B = [], []
for i in range(12):                         # planted: my 8046 cast and SPELL_INTERRUPT 8046 in the same frame
    t = 10.0 + i * 37.3
    A.append((t, ["UNIT_SPELLCAST_SUCCEEDED|player|arg2=8046"], None))
    B.append((t + 0.004, ["SPELL_INTERRUPT|me>npc|spell=8046"], None))
for i in range(60):                         # noise on both sides
    A.append((rnd.uniform(0, 500), ["UNIT_HEALTH|target"], None))
    B.append((rnd.uniform(0, 500), ["SWING_DAMAGE|npc>me"], None))
A.sort(key=lambda x: x[0])
B.sort(key=lambda x: x[0])
rules, rare = correlate.mine(A, B, (0, 500), [(0, 500)], "live->log")
res = {"rules": rules, "rare": rare}
hit = correlate.find(res, r"arg2=8046$", r"SPELL_INTERRUPT")
ok(hit and hit[0]["window"] == 0.05 and hit[0]["idMatch"] and hit[0]["precision"] == 1.0, "correlate: planted same-frame link found (50 ms, id match)")
ok(not correlate.find(res, r"UNIT_HEALTH", r"SWING_DAMAGE"), "correlate: uniform noise yields no rule")
ok(correlate.known({"a": "UNIT_SPELLCAST_INTERRUPTED|target", "b": "SPELL_INTERRUPT|me>npc|spell=8046"}) == "interrupt", "correlate: interrupt pair classified known")
ok(correlate.known({"a": "DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=5", "b": "SPELL_INTERRUPT|me>npc|spell=8046"}) == "damage meter", "correlate: DM pair classified")
ok(correlate._idmatch("x|arg2=8046", "y|spell=8046") and not correlate._idmatch("x|arg0=5", "y|arg1=5"), "correlate: id match needs a >=3-digit id")
r1 = [(100.0, ["RARE_EVENT|player"], None)]
rules, rare = correlate.mine(r1, [(100.01, ["SPELL_INTERRUPT|me>npc|spell=8046"], None)], (0, 5000), [(0, 5000)], "live->log")
ok(rare and rare[0]["rare"] and rare[0]["p"] <= 0.01, "correlate: single-occurrence same-frame pair kept as a rare pair with p-value")

# ------------------------------------------------------------------ verify_live.judge (synthetic log)
ME = "Player-1-00000001"


def ev(t, sub, src, sp, extra=None):
    a = ["", "", "", src, "", "", "", "Creature-0-1-1-1-1-1", "", "", "", sp] + (extra or [])
    return {"t": t, "sub": sub, "a": a, "cleu": True}


fxv = {"events": [ev(5.0, "SPELL_CAST_FAILED", ME, 8046, ["", "Not yet recovered"]), ev(9.0, "SPELL_CAST_SUCCESS", ME, 8046),
                  ev(20.0, "SPELL_INTERRUPT", ME, 8046), ev(30.0, "SPELL_CAST_FAILED", ME, 8046, ["", "Out of range"])]}
verd = [{"t": 5.02, "kind": "cooldown", "spell": 8046, "v": "V"}, {"t": 9.01, "kind": "cooldown", "spell": 8046, "v": "C"},
        {"t": 20.1, "kind": "interrupt-attribution", "v": "V"}, {"t": 30.0, "kind": "cooldown", "spell": 8046, "v": "V"},
        {"t": 40.0, "kind": "cooldown", "spell": 8046, "v": "U"}]
rows, acc = verify_live.judge(verd, fxv, ME, lambda g: "me" if g == ME else "npc")
tr = [r["truth"] for r in rows]
ok(tr == ["confirmed", "confirmed-contradiction", "confirmed", "refuted", "no-truth"], "verify_live: verdicts judged against the log (%s)" % tr)
ok(acc["cooldown"]["refuted"] == 1 and acc["cooldown"]["accuracy"] == round(100.0 * 2 / 3, 1), "verify_live: accuracy = confirmed / judged")
ok(acc["interrupt-attribution"]["accuracy"] == 100.0, "verify_live: interrupt attribution confirmed")

# ------------------------------------------------------------------ misses (grouping + every reason has a fix hint)
mrows = [{"t": 1.0, "sub": "SPELL_DAMAGE", "cat": "damage", "src": "me", "dst": "totem", "spell": 3606, "ctx": "combat", "reason": "no-api-signal", "detail": "d"},
         {"t": 2.0, "sub": "SPELL_DAMAGE", "cat": "damage", "src": "me", "dst": "totem", "spell": 3606, "ctx": "combat", "reason": "no-api-signal", "detail": "d"},
         {"t": 3.0, "sub": "SPELL_HEAL", "cat": "heal", "src": "me", "dst": "me", "spell": 331, "ctx": "ooc", "reason": "target-changed", "detail": ""}]
g = misses.group(mrows)
ok(len(g) == 2 and g[0]["n"] == 2 and g[0]["first"] == 1.0 and g[0]["last"] == 2.0, "misses: identical misses grouped with first/last")
for reason in ("no-api-signal", "secret-payload", "target-changed", "recorder-throttle", "rule-gap", "wrong-attribution", "after-log-end"):
    ok(misses.HINT.get(reason), "misses: reason %s has a fix hint" % reason)
ok(misses.explain({}, {"events": []}, ME)["rows"] == [], "misses: no coverage context -> empty, no crash")

# ------------------------------------------------------------------ knowlint.data_checks (synthetic spell DB)
sp = {8046: {"data": {"info.name": "Earth Shock", "baseCooldown": 6000, "header": {"cooldown": 5.0, "castTime": None}, "costs": [{"cost": 45}],
                      "parsed": {}}, "ctx": {"ooc": {"powerCost.n": 2}}},
      324: {"data": {"info.name": "Lightning Shield", "header": {}, "parsed": {"auraDuration": 600}}},
      331: {"data": {"info.name": "Healing Wave", "cost": 25, "header": {}, "parsed": {}}}}
kr = knowlint.data_checks(sp, None)
chk = {(r["spell"], r["check"]) for r in kr}
ok((8046, "header-vs-api:cooldown") in chk, "knowlint: tooltip cooldown vs GetSpellBaseCooldown mismatch flagged")
ok((8046, "multi-cost") in chk, "knowlint: API cost count != stored costs flagged")
ok((324, "unverified-aura") in chk, "knowlint: parsed aura never observed -> note")
ok(("-", "costs-legacy") in chk, "knowlint: pre-2.2.4 single-cost capture noted")
ok((324, "unverified-aura") not in {(r["spell"], r["check"]) for r in knowlint.data_checks(sp, None, {324: {"auraDurations": [600]}})},
   "knowlint: observed aura clears the note")

print("test_v224_tools: %d checks passed" % N[0])
