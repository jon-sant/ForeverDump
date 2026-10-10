"""v2.2.4 golden checks on the real run-5 capture (real/2026-10-08-run5; skipped when the capture is not present).
One `analysis.run` (coverage + HSM replay, knowledge lint, live verification join, miss explainer, co-occurrence miner,
spell-timing + learned seed merge, token matrix) and assertions on what run 5 is known to contain:
- the miner rediscovers the Earth Shock interrupt link (my 8046 cast <-> SPELL_INTERRUPT 8046, same frame, id match) and the
  target's UNIT_SPELLCAST_INTERRUPTED in the frame of my Earth Shock;
- the known-answer GCD table (totems 1.0 s, Lightning Shield 1.5 s) holds with no mismatch;
- the live verification join has no refuted verdict and cooldown checks at 100%;
- the miss explainer finds no rule gap / wrong attribution (only explainable classes);
- the tooltip extra-line cooldown hypothesis stays NOT proven (signal disabled);
- the seeds are idempotent (re-merging run 5 changes nothing) and the token report states the pre-scanner capture."""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
RUN = os.path.join(ROOT, "real", "2026-10-08-run5")
if not os.path.exists(os.path.join(RUN, "sv", "ForeverDump.lua")):
    print("test_golden_run5: skipped (no real/2026-10-08-run5 capture)")
    sys.exit(0)
from fdump import luasv, combatlog, analysis, correlate, timing, learned  # noqa: E402
from fdump.dump import Dump  # noqa: E402

N = [0]


def ok(cond, msg):
    N[0] += 1
    if not cond:
        raise SystemExit("FAIL: " + msg)


ME = "Player-4618-00EB40D8"
with open(os.path.join(RUN, "sv", "ForeverDump.lua"), encoding="utf-8", errors="replace") as f:
    dump = Dump(luasv.parse_savedvariables(f.read()))
fx = combatlog.parse_file(os.path.join(RUN, "WoWCombatLog.txt"), year=2026, utc_offset_sec=-14400)
ctx = analysis.run(dump, fx, ME, label="run5", correlate_profile="quick", correlate_higher=True)

# miner golden: the Earth Shock interrupt
mn = ctx["miner"]
hit = correlate.find(mn, r"^UNIT_SPELLCAST_SUCCEEDED\|player\|arg\d=8046$", r"^SPELL_INTERRUPT\|me>npc\|spell=8046$")
ok(hit and any(r["idMatch"] and r["window"] <= 0.05 for r in hit), "miner rediscovers my Earth Shock (8046) <-> SPELL_INTERRUPT 8046 (same frame, id match)")
hit2 = correlate.find(mn, r"^UNIT_SPELLCAST_INTERRUPTED\|target$", r"^SPELL_CAST_SUCCESS\|me>npc\|spell=8046$")
ok(hit2 and all(r["precision"] == 1.0 for r in hit2), "miner: the target's UNIT_SPELLCAST_INTERRUPTED lands in the frame of my Earth Shock")
ok(any(correlate.known(r) == "interrupt" for r in correlate.find(mn, r"UNIT_SPELLCAST_INTERRUPTED", r"SPELL_INTERRUPT")), "interrupt rule classified as known")
# Permanent: DAMAGE_METER type 5 fires in the interrupt frame (FINDINGS / run5). Softened 2026-10-08 to
# "meter-frame-join OR any METER" after canonicalize_features treated arg0=N as a unit token and dropped
# arg0=5 — that was a bug, not a legitimate count change. Restored after the token-gate fix.
dm = correlate.find(mn, r"^UNIT_SPELLCAST_INTERRUPTED\|", r"^DAMAGE_METER_COMBAT_SESSION_UPDATED\|arg0=5$")
ok(dm, "miner: DAMAGE_METER_COMBAT_SESSION_UPDATED(type 5) fires in the frame of the interrupt (finding)")

# known answers: totems 1.0 s, Lightning Shield 1.5 s
ka = ctx["timing"]["report"]["knownAnswers"]
ok(ka and all(r["ok"] for r in ka), "known-answer GCD table: no mismatch on run 5")
by = {r["spell"]: r for r in ka}
ok(by[905]["baseGCD"] == 1.5 and by[905]["gapMin"] >= 1.4, "Lightning Shield 905: baseGCD 1.5, next cast >= 1.4 s later")
ok(by[8177]["baseGCD"] == 1.0 and by[8177]["gapMin"] >= 0.9, "Grounding Totem 8177: baseGCD 1.0, next cast >= 0.9 s later")
ok(sum(1 for r in ka if r["label"] == "totem") >= 20 and sum(1 for r in ka if r["label"] == "Lightning Shield") >= 3, "table covers totems + Lightning Shield ranks")
ok(not any(x["kind"] == "known-answer mismatch" for x in ctx["leads"]), "no known-answer lead")

# live verification join
ver = ctx["verify"]
ok(not any(r["truth"] == "refuted" for r in ver["rows"]), "verify_live: no refuted verdict")
ok(ver["accuracy"]["cooldown"]["accuracy"] == 100.0 and ver["accuracy"]["cooldown"]["n"] >= 10, "verify_live: cooldown verdicts 100% (n >= 10)")

# miss explainer
br = ctx["misses"]["byReason"]
ok(br.get("rule-gap", 0) == 0 and br.get("wrong-attribution", 0) == 0, "misses: no rule gap / wrong attribution")
ok(br.get("target-changed", 0) >= 1 and br.get("no-api-signal", 0) >= 1, "misses: target-changed + no-api-signal classes explained")

# knowledge lint: tooltip extra-line cooldown hypothesis stays disabled unless proven
ok(ctx["knowlint"]["cdLine"]["verdict"].startswith("NOT proven"), "tooltip cd-line hypothesis NOT proven -> HSM signal stays disabled")
ok(not any(r["severity"] == "error" for r in ctx["knowlint"]["data"] + ctx["knowlint"].get("log", [])), "knowledge lint: no error on run 5")

# coverage replay: attribution never claims another player's damage as mine
after = ((ctx["coverage"].get("replay") or {}).get("after") or {}).get("scores") or {}
dot = after.get("damage-on-target") or {}
ok(dot.get("scorable", 0) >= 10 and dot.get("falseSelf", 0) == 0, "HSM after: no other-player damage attributed to me")

# seeds idempotent: run 5 is already merged into the shipped seeds
for mod, key in ((timing, "timing"), (learned, "learned")):
    a, b = dict(ctx[key]["seed"]), mod.load_seed()
    a.pop("generated", None)
    b = dict(b)
    b.pop("generated", None)
    ok(a == b, "%s seed unchanged by re-merging run 5 (idempotent)" % key)
ok(not learned.GUID_RE.search(json.dumps(learned.load_seed())), "shipped learned seed: no GUIDs")
ok("No scanner data" in ctx["tokensMd"], "token report: run 5 predates the scanner (stated)")

# v2.2.5 higher-order: at least one 2-hop interrupt chain on run 5
ho = mn.get("higher") or []
ok(ho, "higher-order: at least one chain on run 5")
ok(mn.get("profile") == "quick", "higher-order: golden uses quick profile")
ok((mn.get("elapsedSec") or {}).get("higher") is not None, "higher-order: elapsedSec.higher present")
chains = correlate.find_chains(mn, r"INTERRUPTED", r"SUCCEEDED|SPELL_INTERRUPT|INTERRUPT", patterns=("identity", "chain"))
ok(chains, "higher-order: >=1 interrupt-related 2-hop (INTERRUPTED + SUCCEEDED/INTERRUPT)")
ok(any(ch.get("depth", 0) >= 2 or len(ch.get("hops") or []) >= 3 for ch in chains),
   "higher-order: interrupt chain has depth>=2 (2-hop)")
ok(any(ch.get("proposedRule") for ch in chains), "higher-order: proposedRule on interrupt chain")
# Permanent: ANALYSIS leads must surface higher-order (not only distilled findings). Softened 2026-10-08
# to "or ho" when leads() emitted finding:* instead of higher-order:* — coverage moved, assert was weakened.
# Restored: leads() again emits higher-order rows from miner.higher; assert stays exact.
ok(any(x["kind"].startswith("higher-order") for x in ctx["leads"]), "ANALYSIS leads include higher-order")


# v2.2.5 distinct findings (quick profile may omit some; require interrupt + finite lift)
fs = {f["id"] for f in (mn.get("findings") or [])}
if fs:
    ok("identity-interrupt" in fs or correlate.find_chains(mn, r"INTERRUPTED", patterns=("identity", "chain")),
       "distinct findings include interrupt (or HO chain present)")
    ok(all((f.get("evidence") or {}).get("lift", 0) != 9999 for f in (mn.get("findings") or []) if f.get("best")),
       "distinct findings: no lift 9999")
    ok(all(f.get("status") in ("cross-run", "held-1", "provisional", "failed") for f in mn.get("findings") or []),
       "distinct findings: status vocabulary")
print("test_golden_run5: %d checks passed" % N[0])
