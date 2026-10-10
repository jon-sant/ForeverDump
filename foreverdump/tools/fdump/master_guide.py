"""v2.2.10 cumulative master secrets guide: docs/SECRETS-GUIDE.html (people) + docs/SECRETS-GUIDE.md (AI) +
docs/secrets-guide-state.json (state snapshot), regenerated from every capture under real/ by
`python3 tools/fdump.py master-guide`.

Rows are value x unit family; columns are readability per context (out of combat / PvE combat / PvP-BG combat), HSM
status, valid-in-combat, method, evidence (run + counts) and next step.

Inputs (all per run directory real/<run>/):
  sv/ForeverDump.lua                -> out/master/sv-inspect.json (svinspect: ring per session, token matrix, combat
                                       probe cells, aura containers; codes and counts only, cached by SV size+mtime)
  out/analysis/analysis.json        -> HSM rule accuracy per capture (attr:*, verify:*, overheal-estimate, ...)
  out/coverage/coverage-guide.json  -> (runs 5, 6, 6b) attribution after / meter reconcile
  out/guide/coverage-guide.json        same, older layout (run 5)
  out/FINDINGS.md                   -> curated claims; a claim is used only while its quoted sentence is still in the file
Cumulative SV stores (tokenscan, combatProbe, containers) are merged per cell from the newest run that holds the cell;
recorder sessions are de-duplicated by start epoch (a session kept in several SVs counts once, for its first run).

"Changed since last run" = this state vs the state rebuilt without the newest run, so the output is a pure function
of the data (the regression test regenerates and compares byte for byte). Nothing written here may carry a player
name or a raw GUID: v2.2.21 allows both (raw identity; `assert_private` is a no-op)."""
import collections
import hashlib
import html
import json
import os
import re

from . import svinspect
from . import derivation

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCHEMA = "foreverdump.master-guide/1"
CTXS = ("ooc", "inst", "combat", "icombat", "pvp")
CTX_LABEL = {"ooc": "Out of combat (open world)", "inst": "PvE instance, out of combat (map-restricted)",
             "combat": "In combat (PvE, open world)", "icombat": "In combat (PvE instance: dungeon / raid)",
             "pvp": "PvP / BG combat"}
INSTANCE_ENVS = ("dungeon", "raid", "scenario", "delve")
FAMILIES = ("player", "target", "focus", "friendly", "enemy-player", "npc", "pet", "nameplate", "any")
FAM_LABEL = {"player": "player", "target": "target", "focus": "focus", "friendly": "party/raid friendlies",
             "enemy-player": "enemy players", "npc": "NPCs", "pet": "pets", "nameplate": "nameplates", "any": "any / global"}
STATUSES = ("live", "cached", "correlated-proven", "provisional", "estimated", "unsolved", "not measured")
OUTPUTS = ("docs/SECRETS-GUIDE.md", "docs/SECRETS-GUIDE.html", "docs/secrets-guide-state.json")

# ----------------------------------------------------------------------------------------------- row specification
# selectors:
#   ("tok", field)                       token scanner matrix field (exists/guid/name/health/healthMax/power/dead/...)
#   ("probe", item, ret)                 combat probe cell (API item, return index or .field)
#   ("ring", events, "arg", i)           recorder ring: share of events whose argument i is secret
#   ("ring", events, "delivery", None)   recorder ring: the event fires for that unit (delivery is readable)
#   ("ring", events, "payload", None)    recorder ring: secret fields inside the payload table (UNIT_AURA)
#   ("died", kinds)                      UNIT_DIED GUID: clear for kinds, secret marker counted as S
#   ("aura", part)                       containers aura matrix: "table" / "fields" / "event"
#   ("auracount", None)                  containers count matrix (GetAuraSlots / iterate)
#   ("partial", probe_substring)         containers partial-secret containers (cooldown structs)
#   ("acc", metric)                      HSM accuracy metric (not a readability code; feeds the status)
ALL8 = ("player", "target", "focus", "friendly", "enemy-player", "npc", "pet", "nameplate")
CASTS = ("UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_SUCCEEDED",
         "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_DELAYED")
SPECS = [
    # id, section, value, families, selectors, static(cacheable), method, next step, priority (1 = most wanted)
    ("health", "Health & power", "health (UnitHealth)", ALL8, [("tok", "health"), ("probe", "UnitHealth", "1"), ("probe", "UnitHealthPercent", "1")],
     False, "Read UnitHealth; secret -> player running estimate (healthMax + UNIT_COMBAT amounts); others: UNIT_HEALTH tick timing only",
     "Estimate other units' health % from UNIT_COMBAT amounts on a cached max (target/nameplate) and score it against the log", 1),
    ("healthMax", "Health & power", "healthMax (UnitHealthMax)", ALL8, [("tok", "healthMax"), ("probe", "UnitHealthMax", "1")],
     True, "Read UnitHealthMax out of combat and cache by IdKey; UNIT_MAXHEALTH marks a change",
     "Cache max per NPC id from clear reads (nameplateNtarget / ooc) and verify against the log max", 2),
    ("power", "Health & power", "power (UnitPower)", ALL8, [("tok", "power"), ("probe", "UnitPower", "1")],
     False, "Read UnitPower; player: UNIT_POWER_UPDATE deltas", "Player power from UNIT_POWER_UPDATE delta + ENERGIZE (log join)", 2),
    ("absorbs", "Health & power", "absorbs (UnitGetTotalAbsorbs)", ALL8, [("probe", "UnitGetTotalAbsorbs", "1"), ("ring", ("UNIT_ABSORB_AMOUNT_CHANGED",), "delivery", None)],
     False, "Event UNIT_ABSORB_AMOUNT_CHANGED delivers; the amount API is secret", "Join the absorb-changed frame with the WOUND frame (SPELL_ABSORBED in the log)", 3),
    ("incheal", "Health & power", "incoming heals (UnitGetIncomingHeals)", ALL8, [("probe", "UnitGetIncomingHeals", "1")],
     False, "UnitGetIncomingHeals; UNIT_HEAL_PREDICTION timing", "Score heal-prediction timing vs HEAL on the same unit", 3),
    ("health-event", "Health & power", "health change delivery (UNIT_HEALTH / UNIT_MAXHEALTH fire)", ALL8,
     [("ring", ("UNIT_HEALTH", "UNIT_MAXHEALTH"), "delivery", None)],
     False, "UNIT_HEALTH fires per unit (no value); timing joins with UNIT_COMBAT in the same frame", "none (keep the regression)", 3),
    ("dead", "Health & power", "dead (UnitIsDeadOrGhost)", ALL8, [("tok", "dead"), ("probe", "UnitIsDeadOrGhost", "1")],
     False, "UnitIsDeadOrGhost", "none (keep the regression)", 3),
    ("casting", "Casts", "cast events delivered (START/STOP/SUCCEEDED/CHANNEL)", ALL8,
     [("ring", ("UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP"), "delivery", None)],
     False, "UNIT_SPELLCAST_START/STOP delivery per token (canonicalise by GUID)", "none (keep the regression)", 2),
    ("spellid", "Casts", "cast spellID (event arg 3 / UnitCastingInfo)", ALL8,
     [("ring", CASTS, "arg", 3), ("probe", "UnitCastingInfo", "spellID"), ("probe", "UnitChannelInfo", "spellID")],
     False, "Own casts: event spellID clear. Others: duration fingerprint per NPC id (castModel) + after-combat meter takenSpells",
     "Score castModel spell guesses per NPC id over 2+ runs; for players no fingerprint yet", 1),
    ("castbar", "Casts", "castBarID (event arg 4/5)", ALL8,
     [("ring", ("UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START"), "arg", 4), ("ring", ("UNIT_SPELLCAST_INTERRUPTED",), "arg", 5)],
     False, "castBarID pairs START/STOP/INTERRUPTED of one cast; it differs per token for the same cast",
     "Use castBarID + GUID as the cast key across tokens", 3),
    ("casttiming", "Casts", "cast timing (UnitCastingInfo start/end, UnitCastingDuration)", ALL8,
     [("probe", "UnitCastingInfo", "endTimeMS"), ("probe", "UnitChannelInfo", "endTimeMS"), ("probe", "UnitCastingDuration", "1")],
     False, "UnitCastingInfo times / duration object; others: START->STOP event timing + castModel per NPC id",
     "Predict end time from castModel; score within 150 ms", 2),
    ("interrupted", "Casts", "cast interrupted event (UNIT_SPELLCAST_INTERRUPTED fires)", ALL8,
     [("ring", ("UNIT_SPELLCAST_INTERRUPTED",), "delivery", None)],
     False, "INTERRUPTED delivery per token (payload spellID secret for others)", "none (keep the regression)", 3),
    ("interrupt-mine", "Casts", "interrupt by me (attribution)", ("target", "npc", "nameplate", "enemy-player"),
     [("acc", "attr:interrupt"), ("acc", "verify:interrupt-attribution")],
     False, "INTERRUPTED + my cast or DM type 5 in the same frame, no UNIT_DIED of the same GUID in the frame",
     "Add the interrupt-dm-frame rule (P5) and keep the killed-mid-cast exclusion; need 10+ scored", 2),
    ("aura-event", "Auras", "aura change delivery (UNIT_AURA fires)", ALL8, [("ring", ("UNIT_AURA",), "delivery", None), ("aura", "event-delivery")],
     False, "UNIT_AURA fires per unit even when its payload is secret", "none (keep the regression)", 3),
    ("aura-payload", "Auras", "aura event payload (added/removed IDs)", ALL8, [("ring", ("UNIT_AURA",), "payload", None), ("aura", "event")],
     False, "updateInfo tables: addedAuras / removedAuraInstanceIDs", "Track instance IDs ooc; in combat only the fact that something changed", 2),
    ("aura-details", "Auras", "aura details (C_UnitAuras spellId/duration/stacks)", ALL8, [("aura", "fields"), ("probe", "aura:GetAuraDataByIndex[HELPFUL]", ".spellId"), ("probe", "aura:GetAuraDataByIndex[HARMFUL]", ".spellId"), ("probe", "aura:GetPlayerAuraBySpellID", ".spellId")],
     False, "C_UnitAuras.* reads; in combat they error ('Auras cannot be accessed when secret') or return secrets",
     "HSM aura-on-me / aura-on-target from cast + UNIT_AURA frame joins; prove over 2+ runs", 1),
    ("aura-count", "Auras", "aura presence / count (GetAuraSlots)", ALL8, [("auracount", None), ("probe", "aura:GetAuraSlots[HELPFUL]", "1"), ("probe", "aura:GetAuraSlots[HARMFUL]", "1")],
     False, "GetAuraSlots / iterate counts", "Count from UNIT_AURA added/removed deltas while clear; in combat via HSM", 2),
    ("aura-presence", "Auras", "aura presence by spell ID (C_UnitAuras.GetUnitAuraBySpellID, v2.2.25)", ("player", "target", "any"), [("presence",)],
     False, "GetUnitAuraBySpellID on curated IDs: clear AuraData out of combat (open world, PvE instance); nil for every ID in "
     "combat in every environment measured: open world (run 21), PvE instance (run 20), BG (run 19) - a hidden aura, not an "
     "absent one (combat 'absent' samples present per the log: run 20 3/3, run 21 4/4)",
     "Do not treat nil-in-combat as absence; carry the last clear ooc state + UNIT_AURA delivery (aura-event) through combat", 1),
    ("aura-mine", "Auras", "my auras on the unit (applied by me)", ALL8, [("acc", "attr:aura-on-me"), ("acc", "attr:aura-on-target"), ("probe", "aura:GetAuraDataByIndex[HELPFUL|PLAYER]", "1")],
     False, "HSM: my cast + UNIT_AURA in the same frame -> my aura (attr:aura-on-me / aura-on-target)", "Need 10+ scored auras over 2 runs", 2),
    ("guid", "Identity", "GUID (UnitGUID)", ALL8, [("tok", "guid"), ("probe", "UnitGUID", "1")],
     True, "UnitGUID on direct tokens; stored raw (kind:<GUID>)", "Alias secret chain tokens to the clear direct token (alias learning)", 2),
    ("class", "Identity", "class (UnitClass)", ALL8, [("tok", "class"), ("probe", "UnitClass", "2")],
     True, "UnitClass on group tokens; hostile players: class engine (power type + meter composition + meter name join)",
     "Score the class engine live (meter enemy row names ooc, scoreboard, plate colour)", 1),
    ("name", "Identity", "name (UnitName)", ALL8, [("tok", "name"), ("probe", "UnitName", "name")],
     True, "UnitName (never stored for players; only clear/secret codes)", "none (keep the regression)", 3),
    ("unit-combat", "Combat events", "UNIT_COMBAT amount (arg 4)", ALL8, [("ring", ("UNIT_COMBAT",), "arg", 4), ("acc", "attr:damage-on-target"), ("acc", "attr:damage-taken")],
     False, "UNIT_COMBAT unit/action/amount/school on every token; same hit on several tokens counted once by GUID",
     "none (keep the regression); attribution rows below", 1),
    ("hit-mine", "Combat events", "whose hit (my damage on the unit)", ("target", "npc", "nameplate", "enemy-player"),
     [("acc", "attr:damage-on-target"), ("acc", "attr:miss-on-target")],
     False, "HSM dm-frame rule (meter tick in the hit's frame) + cast-frame rule + swing-lag rule; elimination for others",
     "BG: re-check dm-frame pairing against a BG combat log (run 9)", 1),
    ("hit-taken", "Combat events", "damage taken by me", ("player",), [("acc", "attr:damage-taken")],
     False, "UNIT_COMBAT player WOUND (clear) + DM type 7", "none (keep the regression)", 2),
    ("heal-mine", "Combat events", "heals on me / by me", ("player",), [("acc", "attr:heal-on-me"), ("acc", "overheal-estimate")],
     False, "UNIT_COMBAT player HEAL (clear); effective = gross - overheal estimate", "none (keep the regression)", 2),
    ("heal-hostile", "Combat events", "heals on hostile units (NPC self-heals)", ("target", "npc", "nameplate"), [("acc", "attr:heal-on-target")],
     False, "UNIT_COMBAT HEAL on target/nameplates is clear but the engine drops heals on hostiles", "P4: record HEAL into the world unit; self-heal rule (unit's cast in frame)", 2),
    ("unit-died", "Combat events", "UNIT_DIED GUID", ("npc", "any"), [("died", ("Creature", "Player", "Pet", "Vehicle", "GameObject"))],
     False, "UNIT_DIED arg 1 (Creature GUIDs clear; BG player deaths often secret) + DM type 9", "P2: kill timeline / killing blow; BG: DM type 9 join for secret deaths", 2),
    ("threat", "Threat & range", "threat (UnitThreatSituation)", ALL8, [("probe", "UnitThreatSituation", "1"), ("probe", "UnitDetailedThreatSituation", "status"), ("probe", "UnitDetailedThreatSituation", "scaledPct")],
     False, "UnitThreatSituation / UnitDetailedThreatSituation", "Cache the last clear status; check enemy-player threat (n/a in PvP)", 3),
    ("range", "Threat & range", "distance / range (UnitInRange, CheckInteractDistance, IsSpellInRange)", ALL8,
     [("probe", "UnitInRange", "inRange"), ("probe", "CheckInteractDistance", "1"), ("probe", "C_Spell.IsSpellInRange", "1")],
     False, "CheckInteractDistance clear ooc but protected in combat (CombatGuard skips it, G); UnitInRange secret",
     "Range from cast success/failure (out-of-range errors) and swing range updates", 2),
    ("cooldown", "Cooldowns", "my cooldowns (C_Spell.GetSpellCooldown / SPELL_UPDATE_COOLDOWN)", ("player",),
     [("partial", "GetSpellCooldown"), ("acc", "verify:cooldown"), ("acc", "cooldown-fail")],
     False, "Struct fields secret in combat (isOnGCD/isActive clear); HSM cd tracker from my casts + SPELL_UPDATE_COOLDOWN",
     "Prove cd-ready under haste/latency (run 8 drift on 3 spells)", 2),
    ("meter", "Damage meter", "damage meter (C_DamageMeter session totals)", ("any",),
     [("probe", "C_DamageMeter.GetCombatSessionFromType", ".totalAmount"), ("ring", ("DAMAGE_METER_COMBAT_SESSION_UPDATED",), "delivery", None)],
     False, "Session update events (type/sid) clear; totals secret in combat, clear after combat",
     "BG: fix fight-boundary pairing (live vs meter off-by-one)", 1),
]

# curated claims from FINDINGS.md; used only while `quote` is still in that run's FINDINGS (and that run exists)
CLAIMS = {
    "health/player": {"status": "estimated", "run": "2026-10-08-run5", "quote": "Player running estimate (`hp`)",
                      "metric": ["overheal-estimate"], "note": "HSM player hp estimate (overheal-estimate accuracy)"},
    "spellid/npc": {"status": "provisional", "run": "2026-10-08-run5", "quote": "enemy cast model (`ecast`/`castModel`)",
                    "metric": ["enemy-cast-time"], "note": "castModel duration fingerprint per NPC id"},
    "spellid/nameplate": {"status": "provisional", "run": "2026-10-08-run5", "quote": "enemy cast model (`ecast`/`castModel`)",
                          "metric": ["enemy-cast-time"], "note": "castModel duration fingerprint per NPC id"},
    "spellid/target": {"status": "provisional", "run": "2026-10-08-run5", "quote": "enemy cast model (`ecast`/`castModel`)",
                       "metric": ["enemy-cast-time"], "note": "castModel duration fingerprint per NPC id"},
    "unit-combat/target": {"status": "live", "run": "2026-10-08-run6", "quote": "matched by a live UNIT_COMBAT with the same amount",
                           "metric": [], "note": "live amounts = log amounts 17/17 (run 6), 11/11 (6b)"},
    "unit-combat/nameplate": {"status": "live", "run": "2026-10-08-run6", "quote": "matched by a live UNIT_COMBAT with the same amount",
                              "metric": [], "note": "live amounts = log amounts 17/17 (run 6), 11/11 (6b)"},
    "unit-combat/friendly": {"status": "live", "run": "2026-10-08-run8-bg", "quote": "UNIT_COMBAT / UNIT_HEALTH / UNIT_AURA / UNIT_ABSORB_AMOUNT_CHANGED | 0% for every family",
                             "metric": [], "note": "BG: 0% secret args for every family"},
    "spellid/friendly": {"status": "unsolved", "run": "2026-10-08-run8-bg", "quote": "others' UNIT_SPELLCAST_START / STOP / CHANNEL_START | 96–100%",
                         "metric": [], "note": "BG: other players' spell args secret"},
    "hit-mine/target": {"status": "correlated-proven", "run": "2026-10-08-run6", "quote": "dm-frame rule (main)", "metric": ["attr:damage-on-target"]},
    "hit-mine/npc": {"status": "correlated-proven", "run": "2026-10-08-run6", "quote": "dm-frame rule (main)", "metric": ["attr:damage-on-target"]},
    "hit-mine/nameplate": {"status": "correlated-proven", "run": "2026-10-08-run6", "quote": "dm-frame rule (main)", "metric": ["attr:damage-on-target"]},
    "hit-mine/enemy-player": {"status": "unsolved", "run": "2026-10-08-run8-bg", "quote": "the dm-join in BGs isn't trustworthy yet", "metric": [],
                              "note": "no BG combat log (FD_Logs toggle bug B2); BG dm-join off-by-one"},
    "hit-taken/player": {"status": "correlated-proven", "run": "2026-10-08-run6", "quote": "dm-frame rule (main)", "metric": ["attr:damage-taken"]},
    "heal-mine/player": {"status": "correlated-proven", "run": "2026-10-08-run6", "quote": "The HSM now reconciles effective healing",
                         "metric": ["attr:heal-on-me"]},
    "heal-hostile/target": {"status": "unsolved", "run": "2026-10-08-run6", "quote": "The engine drops heals on hostiles", "metric": ["attr:heal-on-target"]},
    "heal-hostile/npc": {"status": "unsolved", "run": "2026-10-08-run6", "quote": "The engine drops heals on hostiles", "metric": ["attr:heal-on-target"]},
    "heal-hostile/nameplate": {"status": "unsolved", "run": "2026-10-08-run6", "quote": "The engine drops heals on hostiles", "metric": ["attr:heal-on-target"]},
    "interrupt-mine/target": {"status": "correlated-proven", "run": "2026-10-08-run8-bg", "quote": "Interrupts match 34/34",
                           "metric": ["attr:interrupt", "verify:interrupt-attribution"], "note": "BG: meter interrupts 34/34"},
    "interrupt-mine/npc": {"status": "correlated-proven", "run": "2026-10-08-run6", "quote": "Interrupt identity = my cast + DM type 5 in frame",
                        "metric": ["attr:interrupt", "verify:interrupt-attribution"]},
    "aura-mine/player": {"status": "provisional", "run": "2026-10-08-run5", "quote": "scored aura presence 58.3% in combat", "metric": ["attr:aura-on-me"]},
    "aura-mine/target": {"status": "provisional", "run": "2026-10-08-run5", "quote": "scored aura presence 58.3% in combat", "metric": ["attr:aura-on-target"]},
    "aura-mine/npc": {"status": "provisional", "run": "2026-10-08-run5", "quote": "scored aura presence 58.3% in combat", "metric": ["attr:aura-on-target"]},
    "aura-details/player": {"status": "provisional", "run": "2026-10-08-run5", "quote": "payload secret in combat, presence readable", "metric": ["attr:aura-on-me"]},
    "cooldown/player": {"status": "correlated-proven", "run": "2026-10-08-run6", "quote": "SPELL_UPDATE_COOLDOWN carries my spellID clear in combat",
                        "metric": ["verify:cooldown"], "note": "cd-payload-clear; run 8 drift on 3 spells under PvP haste"},
    "meter/any": {"status": "provisional", "run": "2026-10-08-run6", "quote": "exactly one assignment, 11/11 correct", "metric": [],
                  "note": "after-combat per-spell subset-sum, one run; BG dm-join untrusted"},
    "unit-died/any": {"status": "provisional", "run": "2026-10-08-run8-bg", "quote": "Deaths are inferable live through the", "metric": [],
                      "note": "secret BG deaths via DM type 9 (precision 0.58)"},
    "range/target": {"status": "cached", "run": "2026-10-08-run6", "quote": "range C (out of combat; G = guarded in combat from 2.2.7)",
                     "note": "last clear ooc range carried into combat (guard skips in combat)"},
    "threat/target": {"status": "live", "run": "2026-10-08-run6", "quote": "target: threat C (with `th`)"},
    "healthMax/nameplate": {"status": "cached", "run": "2026-10-08-run6", "quote": "healthMax via nameplateNtarget",
                            "note": "max read through nameplateNtarget and cached per unit"},
}

PROVEN_MIN_N = 10       # pooled scored events
PROVEN_MIN_RUNS = 2     # captures with scored events
PROVEN_MIN_ACC = 95.0
FAIL_ACC = 50.0


# ------------------------------------------------------------------------------------------------------- loaders
def run_label(name):
    m = re.search(r"run(\d+[a-z]?)", name)
    return "run" + m.group(1) if m else "run1"


def list_runs(root):
    d = os.path.join(root, "real")
    if not os.path.isdir(d):
        return []
    runs = sorted(n for n in os.listdir(d) if os.path.isdir(os.path.join(d, n)) and os.path.isdir(os.path.join(d, n, "out")))
    try:
        from . import inclusion as _inc
        runs = _inc.filter_runs(runs)
    except Exception:
        pass
    return runs


def log_only_runs(root):
    """v2.2.20 (run 15): run dirs with a combat log but no analysed capture (the SV held no capture of that BG). They add
    no readability evidence, so they stay out of the state; the guide names them so the newest run is not hidden."""
    d = os.path.join(root, "real")
    if not os.path.isdir(d):
        return []
    return sorted(n for n in os.listdir(d) if os.path.isdir(os.path.join(d, n)) and not os.path.isdir(os.path.join(d, n, "out"))
                  and any(f.startswith("WoWCombatLog") for f in os.listdir(os.path.join(d, n))))


def _load_json(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def input_files(root, run):
    base = os.path.join(root, "real", run)
    try:
        from . import inclusion as _inc
        sv_p = _inc.sv_path_for_analysis(base)
    except Exception:
        sv_p = os.path.join(base, "sv", "ForeverDump.lua")
    cands = [sv_p, os.path.join(base, "out", "analysis", "analysis.json"),
             os.path.join(base, "out", "coverage", "coverage-guide.json"), os.path.join(base, "out", "guide", "coverage-guide.json"),
             os.path.join(base, "out", "FINDINGS.md")]
    return [p for p in cands if os.path.exists(p)]


def load_run(root, run, inspect=True):
    base = os.path.join(root, "real", run)
    r = {"run": run, "label": run_label(run)}
    try:
        from . import inclusion as _inc
        sv = _inc.sv_path_for_analysis(base)
    except Exception:
        sv = os.path.join(base, "sv", "ForeverDump.lua")
    if inspect and os.path.exists(sv):
        r["inspect"] = svinspect.inspect_cached(sv, os.path.join(base, "out", "master", "sv-inspect.json"))
    an = _load_json(os.path.join(base, "out", "analysis", "analysis.json")) or {}
    r["accuracy"] = an.get("accuracy") or {}
    cov = _load_json(os.path.join(base, "out", "coverage", "coverage-guide.json")) or _load_json(
        os.path.join(base, "out", "guide", "coverage-guide.json")) or {}
    if not r["accuracy"] and cov.get("attribution"):
        r["accuracy"] = {"attr:" + k: v for k, v in (cov["attribution"].get("after") or {}).items()}
    f = os.path.join(base, "out", "FINDINGS.md")
    r["findings"] = ""
    if os.path.exists(f):
        with open(f, encoding="utf-8") as fh:
            r["findings"] = fh.read()
    return r


# ------------------------------------------------------------------------------------------------- family mapping
def probe_families(ucls, ctx):
    tok, _, cls = str(ucls).partition(":")
    out = set()
    base = {"player": "player", "target": "target", "focus": "focus", "party": "friendly", "raid": "friendly",
            "nameplate": "nameplate", "global": "any", "pet": "pet", "arena": "enemy-player", "boss": "npc"}.get(tok)
    if cls == "self" and tok != "player":
        base = None
    # v2.2.29: in a BG arenaN tokens also name FRIENDLY players (run 19-22: arena:friendly-player 112x next to
    # arena:hostile-player 112x); folding both into enemy-player made class / GUID flip C/S between runs
    if tok == "arena" and "friendly-player" in cls:
        base = "friendly"
    if base:
        out.add(base)
    if "hostile-npc" in cls or "friendly-npc" in cls:
        out.add("npc")
    if "hostile-player" in cls:
        out.add("enemy-player")
    if "friendly-player" in cls and tok in ("focus", "target", "party", "raid", "mouseover", "nameplate"):
        out.add("friendly")
    return out


PVP_ENVS = ("bg", "arena")


def instance_run(envs):
    """run 20: True when every env counter of the run is a PvE instance (dungeon / raid / ...): its ooc / restricted
    cells go to "inst" and its combat cells to "icombat", so an instance capture neither overwrites open-world PvE
    cells (target GUID / name are secret in dungeon combat, clear in open-world combat on runs 1-7) nor is hidden."""
    envset = {k for byenv in (envs or {}).values() for k, n in (byenv or {}).items() if n}
    return bool(envset) and envset <= set(INSTANCE_ENVS)


def inst_ctx(ctx):
    """guide ctx of an instance run's raw / mapped ctx"""
    if ctx is None:
        return None
    c = str(ctx)
    if c == "pvp":
        return "pvp"
    if c.startswith(("combat", "enc", "icombat")):
        return "icombat"
    if c.startswith(("ooc", "restricted", "inst", "postcombat")):
        return "inst"
    return ctx


def presence_ctx(tag):
    """AuraPresence env tag 'env/phase/sub' -> guide ctx (bg / arena -> pvp; dungeon / raid -> inst / icombat; else
    open world ooc / combat)"""
    env, _, rest = str(tag).partition("/")
    combat = rest.split("/")[0] == "combat"
    if env in PVP_ENVS:
        return "pvp"
    if env in INSTANCE_ENVS:
        return "icombat" if combat else "inst"
    return "combat" if combat else "ooc"


def restricted_ctx(envs):
    """guide ctx of the raw "restricted" ctx (restrictions active, not in combat). run 20 (dungeon): with env counters
    that are all non-PvP (dungeon / raid / world) it is the PvE-instance out-of-combat column "inst" (auras clear,
    health / power secret); bg / arena or legacy runs without env counters keep "pvp" (BG between fights)."""
    e = (envs or {}).get("restricted") if envs else None
    if e and not any(k in PVP_ENVS for k in e) and any(n for n in e.values()):
        return "inst"
    return "pvp"


def probe_ctx(ctx, ucls, envs=None):
    """map a CombatProbe ctx to a guide ctx. v2.2.25 (BG-only audit): when the run recorded ctx@env counters
    (envs = {ctx: {env: n}}), the environment decides (pvp = bg/arena only; a dungeon / world combat with party
    members is "combat"). Legacy runs (no env) keep the old heuristic."""
    e = (envs or {}).get(ctx) if envs else None
    if e:
        pv = sum(n for k, n in e.items() if k in PVP_ENVS)
        other = sum(n for k, n in e.items() if k not in PVP_ENVS)
        if pv and not other:
            return "pvp"
        if other and not pv:
            if ctx.startswith("restricted"):
                return "inst"   # run 20: restricted in a dungeon = out of combat inside the instance (was "combat")
            return "combat" if ctx.startswith(("combat", "enc")) else ("ooc" if ctx.startswith("ooc") else None)
        # mixed: fall through to the legacy heuristic
    if ctx == "restricted":
        return "pvp"
    if ctx.startswith("combat") and "player" in str(ucls).partition(":")[2]:
        return "pvp"   # other players only appear in the BG capture (run 8)
    return "combat" if ctx.startswith("combat") or ctx.startswith("enc") else ("ooc" if ctx.startswith("ooc") else None)


def token_families(fam):
    g = svinspect.scan_family(fam)
    return {g} if g in ALL8 else set()


def ring_families(fam, ctx):
    out = {fam} if fam in ALL8 else set()
    if ctx in ("ooc", "combat", "inst", "icombat") and fam in ("target", "nameplate"):
        out.add("npc")   # PvE captures (runs 1-7): target / nameplates are NPCs (FINDINGS: NPC ids only)
    return out


# ------------------------------------------------------------------------------------------------ observations
class Obs:
    """per (row, family, ctx): code counts + evidence {source: {code: n}} + runs"""

    def __init__(self):
        self.cells = collections.defaultdict(lambda: collections.defaultdict(lambda: {"codes": collections.Counter(), "src": collections.defaultdict(collections.Counter), "runs": set()}))

    def add(self, key, ctx, code, n, src, run):
        if not n or ctx not in CTXS:
            return
        c = self.cells[key][ctx]
        c["codes"][code] += n
        c["src"][src][code] += n
        c["runs"].add(run)


def _norm_code(code):
    code = str(code)
    # v2.2.22 (audit): "T" (container with SOME secret fields) stays "T" -> verdict "mixed" (was folded into "S")
    return {"K": "C", "X": "N", "L": "N"}.get(code, code)


def _cont_ctx(actx, rctx):
    """raw containers ctx -> guide ctx (restricted -> rctx; combat* -> combat; ooc* -> ooc)"""
    if actx == "restricted":
        return rctx
    if str(actx).startswith("combat"):
        return "combat"
    return actx


def _ring_ctxs(r):
    ctxs = set()
    for s in (((r.get("inspect") or {}).get("ring") or {}).get("sessions") or []):
        for byf in (s.get("events") or {}).values():
            for byc in byf.values():
                ctxs.update(byc.keys())
    return ctxs


def collect(runs):
    """runs: loaded run dicts (sorted). Returns (obs, acc) where acc[metric] = [(label, acc, n)]."""
    obs = Obs()
    by_id = {s[0]: s for s in SPECS}
    # cumulative stores: newest run holding the cell wins
    tok_cells, probe_cells, aura_cells, count_cells, partial_cells, presence_cells = {}, {}, {}, {}, {}, {}
    seen_sessions = set()
    for r in runs:
        ins = r.get("inspect") or {}
        lab = r["label"]
        envs = (ins.get("probes") or {}).get("envCtx")
        inst = instance_run(envs)
        cmap = inst_ctx if inst else (lambda c: c)
        for t in ins.get("tokens") or []:
            for f, c in (t.get("cells") or {}).items():
                tok_cells[(t["family"], cmap(t["ctx"]), t["state"], f)] = (lab, c)
        # run 19 (v2.2.25 env tags): cells are keyed by the MAPPED guide ctx, so a newer run whose env counters map a
        # cell to "pvp" no longer evicts an older run's "combat" cell (and vice versa). A BG-only capture (every ring
        # context is pvp) maps its legacy "combat" probe cells to pvp: before v2.2.25 that BG combat was filed under
        # PvE combat by the legacy heuristic.
        rctx = restricted_ctx(envs)
        bg_only = _ring_ctxs(r) == {"pvp"}
        for item, byret in ((ins.get("probes") or {}).get("matrix") or {}).items():
            for ret, byu in byret.items():
                for ucls, byc in byu.items():
                    for ctx, c in byc.items():
                        mctx = probe_ctx(ctx, ucls, envs)
                        if bg_only and mctx == "combat":
                            mctx = "pvp"
                        if inst:
                            mctx = inst_ctx(mctx)
                        probe_cells[(item, ret, ucls, mctx)] = (lab, c, ctx)
        run_presence = {}   # several env tags map to one guide ctx (bg/combat, bg/ooc/gates, ... -> pvp): sum per run
        for tag, byf in (ins.get("auraPresence") or {}).items():
            pctx = presence_ctx(tag)
            for fam, codes in (byf or {}).items():
                acc_c = run_presence.setdefault((str(fam), pctx), collections.Counter())
                for k, n in (codes or {}).items():
                    acc_c[str(k)] += n
        for key, codes in run_presence.items():
            # run 22: a run whose probe ran with 0 candidates holds EMPTY code dicts per env tag; that is no evidence and
            # must not evict an older run's cell (pvp aura presence went clear -> '-')
            if sum(codes.values()) > 0:
                presence_cells[key] = (lab, dict(codes))
        cont = ins.get("containers") or {}
        # containers carry no env: the raw "restricted" ctx is mapped with this run's probe env counters, and the cell
        # key holds the MAPPED ctx so a dungeon run's "inst" cells do not evict a BG run's "pvp" cells (run 20)
        for a in cont.get("auraMatrix") or []:
            aura_cells[(cmap(_cont_ctx(a.get("ctx"), rctx)), a.get("group"), tuple(a.get("units") or ()))] = (lab, a)
        for a in cont.get("countMatrix") or []:
            count_cells[(cmap(_cont_ctx(a.get("ctx"), rctx)), a.get("group"), a.get("method"))] = (lab, a)
        for p in cont.get("partial") or []:
            partial_cells[(cmap(_cont_ctx(p.get("ctx"), rctx)), p.get("unit"), p.get("probe"))] = (lab, dict(p, _raw=p.get("ctx")))
        for s in ((ins.get("ring") or {}).get("sessions") or []):
            if s.get("epoch") in seen_sessions:
                continue
            seen_sessions.add(s.get("epoch"))
            _ring(obs, s, lab, cmap)
    for sid, _sec, _val, fams, sels, *_ in SPECS:
        for sel in sels:
            kind = sel[0]
            if kind == "tok":
                for (fam, ctx, _st, f), (lab, c) in tok_cells.items():
                    if f != sel[1]:
                        continue
                    for g in token_families(fam) & set(fams):
                        obs.add((sid, g), ctx, _norm_code(c["code"]), c["n"], "tokens:%s" % f, lab)
            elif kind == "probe":
                for (item, ret, ucls, ctx), (lab, c, pctx) in probe_cells.items():
                    if item != sel[1] or ret != sel[2]:
                        continue
                    for code, n in (c.get("counts") or {}).items():
                        for g in probe_families(ucls, pctx) & set(fams):
                            obs.add((sid, g), ctx, _norm_code(code), n, "probe:%s%s" % (item, "" if ret == "1" else ret if ret.startswith(".") else "." + ret), lab)
            elif kind == "aura":
                for (ctx, _grp, units), (lab, a) in aura_cells.items():
                    gs = set()
                    for u in units:
                        gs |= probe_families(u, a.get("ctx"))
                    gs &= set(fams)
                    part = sel[1]
                    if part == "event-delivery":
                        n = sum(sum(v.values()) for v in (a.get("event") or {}).values() if isinstance(v, dict))
                        codes = {"C": n} if n else {}
                    elif part == "event":
                        codes = collections.Counter()
                        for v in (a.get("event") or {}).values():
                            for k, n in (v or {}).items():
                                codes[k] += n
                    else:
                        codes = collections.Counter(a.get("table") or {})
                        for v in (a.get("fields") or {}).values():
                            for k, n in (v or {}).items():
                                codes[k] += n
                    for g in gs:
                        for code, n in codes.items():
                            obs.add((sid, g), ctx, _norm_code(code), n, "containers:aura-%s" % part, lab)
            elif kind == "presence":
                pmap = {"player": {"player"}, "target": {"target"}}
                for (fam, ctx), (lab, codes) in presence_cells.items():
                    for g in (pmap.get(fam, set()) | {"any"}) & set(fams):
                        for code, n in (codes or {}).items():
                            obs.add((sid, g), ctx, _norm_code(code), n, "auraPresence:%s" % fam, lab)
            elif kind == "auracount":
                gmap = {"player": {"player"}, "target NPC": {"target", "npc", "nameplate"}, "party/raid": {"friendly"},
                        "other player": {"enemy-player", "friendly"}}
                for (ctx, grp, _m), (lab, a) in count_cells.items():
                    for g in gmap.get(grp, set()) & set(fams):
                        for code, n in (a.get("codes") or {}).items():
                            obs.add((sid, g), ctx, _norm_code(code), n, "containers:aura-count", lab)
            elif kind == "partial":
                for (ctx, unit, probe), (lab, p) in partial_cells.items():
                    if sel[1] not in str(probe):
                        continue
                    for g in probe_families(unit, p.get("_raw")) & set(fams):
                        obs.add((sid, g), ctx, "S" if p.get("secretFields") else "C", 1, "containers:%s" % probe.split("(")[0], lab)
    acc = collections.defaultdict(list)
    for r in runs:
        for k, v in (r.get("accuracy") or {}).items():
            if isinstance(v, dict) and isinstance(v.get("n"), (int, float)) and v.get("accuracy") is not None:
                acc[k].append((r["label"], float(v["accuracy"]), int(v["n"])))
    return obs, acc, by_id


def _ring(obs, s, lab, cmap=lambda c: c):
    evs = s.get("events") or {}
    for sid, _sec, _val, fams, sels, *_ in SPECS:
        for sel in sels:
            if sel[0] == "ring":
                _, events, mode, idx = sel
                for ev in events:
                    for fam, byc in (evs.get(ev) or {}).items():
                        for rctx, c in byc.items():
                            ctx = cmap(rctx)
                            for g in ring_families(fam, ctx) & set(fams):
                                src = "ring:%s%s" % (ev.replace("UNIT_SPELLCAST_", "SC_"), "" if mode == "delivery" else ".%s" % (idx or "payload"))
                                if mode == "delivery":
                                    obs.add((sid, g), ctx, "C", c["n"], src, lab)
                                elif mode == "payload":
                                    obs.add((sid, g), ctx, "S", c["secretAny"], src, lab)
                                    obs.add((sid, g), ctx, "C", c["n"] - c["secretAny"], src, lab)
                                else:
                                    sec = int((c.get("args") or {}).get(str(idx), 0))
                                    present = int((c.get("present") or {}).get(str(idx), 0))
                                    obs.add((sid, g), ctx, "S", sec, src, lab)
                                    obs.add((sid, g), ctx, "C", max(0, present - sec), src, lab)
            elif sel[0] == "died":
                for rctx, kinds in (s.get("deaths") or {}).items():
                    ctx = cmap(rctx)
                    for k, n in kinds.items():
                        if "npc" in fams and k == "Creature":
                            obs.add((sid, "npc"), ctx, "C", n, "ring:UNIT_DIED.1", lab)
                        if "any" in fams:
                            code = "S" if k == "secret" else ("C" if k in sel[1] else "N")
                            obs.add((sid, "any"), ctx, code, n, "ring:UNIT_DIED.1", lab)


# ------------------------------------------------------------------------------------------------------ verdicts
def readability(cell):
    """codes -> (verdict, short) where verdict in clear/secret/mixed/error/nil/guarded/-"""
    if not cell:
        return "-", ""
    codes = cell["codes"]
    tot = sum(codes.values())
    if not tot:
        return "-", ""
    c, s, e, n, g = codes.get("C", 0), codes.get("S", 0), codes.get("E", 0), codes.get("N", 0), codes.get("G", 0)
    t = codes.get("T", 0)   # v2.2.22: container, some fields secret -> never a "secret" verdict on its own
    sig = c + s + e + g + t
    if not sig:
        return "nil", "N %d" % n
    parts = ["%s %d" % (k, v) for k, v in sorted(codes.items(), key=lambda kv: (-kv[1], kv[0])) if v]
    short = " ".join(parts[:3])
    if c == sig:
        return "clear", short
    if t:
        return "mixed", short
    if s == sig:
        return "secret", short
    if e == sig:
        return "error", short
    if g and g + e + s == sig and not c:
        return "guarded", short
    if c / float(sig) >= 0.95:
        return "clear", short
    if (s + e) / float(sig) >= 0.95:
        return "secret" if s >= e else "error", short
    return "mixed", short


def pooled(acc, metrics):
    rows = [x for m in metrics for x in acc.get(m, [])]
    if not rows:
        return None
    n = sum(x[2] for x in rows)
    if not n:
        return None
    correct = sum(x[1] * x[2] / 100.0 for x in rows)
    runs = sorted({x[0] for x in rows if x[2]}, key=_run_sort)
    return {"acc": round(100.0 * correct / n, 1), "n": n, "runs": runs, "metrics": list(metrics)}


def _run_sort(lab):
    m = re.match(r"run(\d+)([a-z]?)", lab)
    return (int(m.group(1)), m.group(2)) if m else (0, "")


def _run_span(labels):
    labs = sorted(set(labels), key=_run_sort)
    if not labs:
        return ""
    return labs[0] if len(labs) == 1 else "%s..%s (%d)" % (labs[0], labs[-1], len(labs))


def decide(spec, fam, read, claim, acc):
    """-> (status, valid, why)"""
    sid, _sec, _val, _fams, sels, static, *_ = spec
    metrics = [s[1] for s in sels if s[0] == "acc"]
    if claim and "metric" in claim:
        metrics = claim["metric"]
    p = pooled(acc, metrics) if metrics else None
    # open-world PvE combat decides; an instance-only row (no open-world cell yet) falls back to the instance cell
    combat = read["combat"] if read.get("combat", "-") != "-" else read.get("icombat", "-")
    pvp, ooc = read["pvp"], read["ooc"]
    if claim:
        st = claim["status"]
        if st in ("correlated-proven", "provisional") and p:
            if p["acc"] < FAIL_ACC:
                st = "unsolved"
            elif p["acc"] >= PROVEN_MIN_ACC and p["n"] >= PROVEN_MIN_N and len(p["runs"]) >= PROVEN_MIN_RUNS:
                st = "correlated-proven"
            else:
                st = "provisional"
        elif st == "correlated-proven" and not p:
            st = "provisional"
        if st == "live" and combat != "clear":
            st = "unsolved" if combat in ("secret", "error") else st
        return st, p
    if combat == "clear" and pvp in ("clear", "-"):
        return "live", p
    if combat == "clear" or (combat == "-" and pvp == "clear"):
        return "live", p
    if combat == "-" and pvp == "-":
        if ooc == "clear":
            return ("cached" if static else "not measured"), p
        return "not measured", p
    if static and ooc == "clear":
        return "cached", p
    if p and p["acc"] >= PROVEN_MIN_ACC and p["n"] >= PROVEN_MIN_N and len(p["runs"]) >= PROVEN_MIN_RUNS:
        return "correlated-proven", p
    if p and p["acc"] >= 90:
        return "provisional", p
    return "unsolved", p


def valid_in_combat(status, read):
    if status == "live":
        bad = ("secret", "error", "mixed", "guarded")
        if read["combat"] == "clear" and read.get("icombat") in bad:
            return "open-world PvE only" if read["pvp"] in bad else "not in PvE instances"
        if read["combat"] == "clear" and read["pvp"] in bad:
            return "PvE only"
        return "yes"
    return {"cached": "yes (cached ooc value)", "correlated-proven": "yes (HSM)", "estimated": "approx (HSM)",
            "provisional": "partial", "unsolved": "no", "not measured": "?"}[status]


# ------------------------------------------------------------------------------------------------------- state
def build_state(runs):
    obs, acc, _ = collect(runs)
    rows = []
    for spec in SPECS:
        sid, sec, val, fams, sels, static, method, nxt, prio = spec
        for fam in fams:
            cells = obs.cells.get((sid, fam), {})
            read = {}
            short = {}
            for ctx in CTXS:
                read[ctx], short[ctx] = readability(cells.get(ctx))
            key = "%s/%s" % (sid, fam)
            claim = None
            cl = CLAIMS.get(key)
            if cl:
                rr = [r for r in runs if r["run"] == cl["run"]]
                if rr and cl["quote"] in rr[0]["findings"]:
                    claim = cl
            if all(read[c] == "-" for c in CTXS) and not claim and not any(s[0] == "acc" and acc.get(s[1]) for s in sels):
                status, p = "not measured", None
            else:
                status, p = decide(spec, fam, read, claim, acc)
            ev = []
            src = collections.defaultdict(lambda: collections.Counter())
            runs_seen = set()
            for ctx in CTXS:
                c = cells.get(ctx)
                if not c:
                    continue
                runs_seen |= c["runs"]
                for s, codes in c["src"].items():
                    src[s].update(codes)
            for s, codes in sorted(src.items()):
                ev.append("%s %s" % (s, "/".join("%s%d" % (k, v) for k, v in sorted(codes.items(), key=lambda kv: (-kv[1], kv[0])))))
            if p:
                ev.append("HSM %s %.1f%% n=%d (%s)" % ("+".join(p["metrics"]), p["acc"], p["n"], ",".join(p["runs"])))
            if claim:
                ev.append("FINDINGS %s: \"%s\"%s" % (run_label(claim["run"]), claim["quote"], (" - " + claim["note"]) if claim.get("note") else ""))
            rows.append({"id": key, "section": sec, "value": val, "family": fam, "read": read, "counts": short,
                         "status": status, "valid": valid_in_combat(status, read), "method": method,
                         "evidence": ev, "runs": _run_span(runs_seen), "next": "none (keep the regression)" if status == "live" else nxt,
                         "priority": prio, "derive": _derive(key, fam, status)})
    tally = collections.Counter(r["status"] for r in rows)
    have = {r["run"]: r for r in runs}
    dropped = sorted(k for k, c in CLAIMS.items() if c["run"] in have and c["quote"] not in have[c["run"]]["findings"])
    return {"rows": rows, "tally": {s: tally.get(s, 0) for s in STATUSES}, "droppedClaims": dropped}


def diff_states(old, new):
    o = {r["id"]: r for r in old["rows"]}
    out = []
    for r in new["rows"]:
        p = o.get(r["id"])
        if not p:
            out.append({"id": r["id"], "what": "new row", "old": None, "new": r["status"]})
            continue
        if p["status"] != r["status"]:
            out.append({"id": r["id"], "what": "status", "old": p["status"], "new": r["status"]})
        for ctx in CTXS:
            if p["read"][ctx] != r["read"][ctx]:
                out.append({"id": r["id"], "what": "read:" + ctx, "old": p["read"][ctx], "new": r["read"][ctx]})
    return out


def _changes_by_row(changes):
    """-> [(row id, 'old -> new' status or '=', 'ctx: old -> new; ...')] in row order"""
    out = collections.OrderedDict()
    for c in changes:
        st, reads = out.setdefault(c["id"], ["=", []])
        if c["what"] == "new row":
            out[c["id"]][0] = "new: %s" % c["new"]
        elif c["what"] == "status":
            out[c["id"]][0] = "%s -> %s" % (c["old"], c["new"])
        else:
            reads.append("%s: %s -> %s" % (c["what"].split(":", 1)[1], c["old"], c["new"]))
    rows = [(k, v[0], "; ".join(v[1])) for k, v in out.items()]
    return [r for r in rows if r[1] != "="] + [r for r in rows if r[1] == "="]


def _derive(key, fam, status):
    d = derivation.lookup(key.split("/")[0], fam) or {"status": "probe", "path": "not inventoried", "inputs": "-", "estimate": "-", "probe": "-"}
    if status == "live" and d["status"] != "direct":
        d = dict(d, status="direct", path="readable directly (" + d["path"] + " kept as the fallback)")
    return d


def _dcell(r):
    d = r.get("derive") or {}
    return "[%s] %s" % (d.get("status", "-"), d.get("path", "-"))


def derivation_table(cur):
    """one line per value family (guide rows grouped by id) + the extra families; the worst-status unit families listed"""
    out, seen = [], collections.OrderedDict()
    for r in cur["rows"]:
        seen.setdefault(r["id"].split("/")[0], []).append(r)
    for rid, rows in seen.items():
        e = derivation.DERIVE.get(rid) or {}
        unsolved = [r["family"] for r in rows if r["status"] in ("unsolved", "not measured")]
        out.append({"id": rid, "value": rows[0]["value"], "status": e.get("status", "probe"), "path": e.get("path", "-"),
                    "inputs": e.get("inputs", "-"), "estimate": e.get("estimate", "-"), "probe": e.get("probe", "-"),
                    "open": ",".join(FAM_LABEL[f] for f in unsolved) or "-"})
    for rid, val, e in derivation.EXTRA:
        out.append({"id": rid, "value": val, "status": e["status"], "path": e["path"], "inputs": e["inputs"],
                    "estimate": e["estimate"], "probe": e["probe"], "open": "(HSM family)"})
    return out


def top_unsolved(state, k=10):
    rows = [r for r in state["rows"] if r["status"] == "unsolved"]
    weight = {"player": 0, "target": 1, "npc": 2, "nameplate": 3, "enemy-player": 4, "friendly": 5, "focus": 6, "pet": 7, "any": 1}
    rows.sort(key=lambda r: (r["priority"], weight.get(r["family"], 9), r["id"]))
    return rows[:k]


def fingerprint(root, runs):
    h = hashlib.sha256()
    for run in runs:
        for p in input_files(root, run):
            st = os.stat(p)
            h.update(("%s:%d\n" % (os.path.relpath(p, root), st.st_size)).encode())
            if p.endswith((".json", ".md")):
                with open(p, "rb") as f:
                    h.update(hashlib.sha256(f.read()).digest())
    with open(os.path.abspath(__file__), "rb") as f:
        h.update(hashlib.sha256(f.read()).digest())
    return h.hexdigest()[:16]


def run_table(runs):
    out = []
    for r in runs:
        ins = r.get("inspect") or {}
        ring = (ins.get("ring") or {}).get("sessions") or []
        ctxs = set()
        nev = 0
        for s in ring:
            for byf in (s.get("events") or {}).values():
                for byc in byf.values():
                    for ctx, c in byc.items():
                        ctxs.add(inst_ctx(ctx) if instance_run((ins.get("probes") or {}).get("envCtx")) else ctx)
                        nev += c["n"]
        out.append({"label": r["label"], "dir": r["run"], "build": ins.get("build", "-"), "addon": ins.get("addonVersion", "-"),
                    "sessions": len(ring), "ringEvents": nev, "contexts": sorted(ctxs, key=lambda c: CTXS.index(c) if c in CTXS else len(CTXS)),
                    "tokenCells": len(ins.get("tokens") or []), "scored": sum(int(v.get("n") or 0) for v in r["accuracy"].values() if isinstance(v, dict)),
                    "findings": bool(r["findings"])})
    return out


def generate(root=ROOT):
    names = list_runs(root)
    runs = [load_run(root, n) for n in names]
    cur = build_state(runs)
    prev = build_state(runs[:-1]) if len(runs) > 1 else {"rows": [], "tally": {}}
    history = []
    for i in range(1, len(runs) + 1):
        st = cur if i == len(runs) else (prev if i == len(runs) - 1 else build_state(runs[:i]))
        history.append({"run": runs[i - 1]["label"], "tally": st["tally"]})
    state = {"schema": SCHEMA, "runs": [r["label"] for r in runs], "newestRun": names[-1] if names else None,
             "fingerprint": fingerprint(root, names), "rowCount": len(cur["rows"]), "tally": cur["tally"],
             "changes": diff_states(prev, cur) if len(runs) > 1 else [], "history": history,
             "runTable": run_table(runs), "topUnsolved": [r["id"] for r in top_unsolved(cur)],
             "claimsUsed": sum(1 for r in cur["rows"] if any(e.startswith("FINDINGS ") for e in r["evidence"])),
             "droppedClaims": cur["droppedClaims"], "logOnlyRuns": [run_label(n) for n in log_only_runs(root)],
             "rows": [{k: r[k] for k in ("id", "value", "family", "read", "status", "valid", "runs")} for r in cur["rows"]]}
    md = render_md(state, cur)
    ht = render_html(state, cur)
    js = json.dumps(state, indent=1, sort_keys=True) + "\n"
    for text in (md, ht, js):
        assert_private(text, root)
    return {"docs/SECRETS-GUIDE.md": md, "docs/SECRETS-GUIDE.html": ht, "docs/secrets-guide-state.json": js}, state


# ----------------------------------------------------------------------------------------------------- privacy
GUID_RE = re.compile(r"\b(?:Player|Creature|Pet|Vehicle|GameObject|Cast)-\d+-[0-9A-Fa-f-]{6,}|\b[0-9A-F]{8}-[0-9A-F]{8}\b")


def forbidden_names(root=ROOT):
    names = set()
    d = _load_json(os.path.join(root, "tools", "fdump", "characters.json")) or {}
    for c in d.get("characters") or []:
        for k in ("display", "combatLogName"):
            v = c.get(k)
            if isinstance(v, str) and v:
                names.add(v)
                for part in re.split(r"[\s-]+", v):
                    if len(part) >= 4:
                        names.add(part)
    return names


def assert_private(text, root=ROOT):
    """v2.2.21 (user decision 2026-10-09): raw names / GUIDs are allowed in the guide - no privacy gate."""
    return None


# ------------------------------------------------------------------------------------------------------ render
LEGEND_READ = [("clear", "readable value (C)"), ("secret", "secret value (S/T)"), ("error", "API errors / refused (E)"),
               ("mixed", "clear and secret both seen"), ("guarded", "skipped by CombatGuard (G)"), ("nil", "only nil returned"),
               ("-", "not measured")]
LEGEND_STATUS = [("live", "readable live in combat"), ("cached", "read out of combat, carried into combat"),
                 ("correlated-proven", f"HSM inference scored >= {PROVEN_MIN_ACC:.0f}% on >= {PROVEN_MIN_N} events over >= {PROVEN_MIN_RUNS} runs"),
                 ("provisional", "HSM inference with too little evidence (or one run)"), ("estimated", "HSM estimate (approximate value)"),
                 ("unsolved", "secret/error in combat and no proven inference"), ("not measured", "no capture covered it")]


def _group(cur):
    out = collections.OrderedDict()
    for r in cur["rows"]:
        out.setdefault(r["section"], []).append(r)
    return out


def _md(x):
    return str(x).replace("|", "\\|")


LOG_ONLY = ("Log-only runs (combat log only, no capture in the SV, so not part of this state; scored offline in "
            "HSM-STATUS): %s.")


def render_md(state, cur):
    L = ["# ForeverDump master secrets guide (cumulative)", "",
         "Generated by `python3 tools/fdump.py master-guide` from every capture under `real/` (%s). Do not edit by hand; "
         "the regression test `tests/test_master_guide.py` fails when this file is stale. Paired with SECRETS-GUIDE.html "
         "(same content, colour-coded). No player names or raw GUIDs: only codes, counts, spell/NPC ids." % ", ".join(state["runs"]), "",
         "Data fingerprint `%s`, newest run `%s`, %d rows." % (state["fingerprint"], state["newestRun"], state["rowCount"]), "",
         "## How to read", "",
         "- Contexts: **ooc** = out of combat (open world), **inst** = inside a PvE instance out of combat (map restrictions "
         "active; run 20 dungeon), **combat** = open-world PvE combat, **icombat** = PvE instance combat (dungeon / raid; run 20), "
         "**pvp** = inside a battleground (PvP-restricted, between fights included, and PvP combat).",
         "- Readability: " + "; ".join("`%s` %s" % kv for kv in LEGEND_READ) + ". Counts after the verdict are raw code counts (C clear, S secret, E error, N nil, G guarded).",
         "- HSM status: " + "; ".join("`%s` %s" % kv for kv in LEGEND_STATUS) + ".",
         "- Evidence sources: `tokens:` token scanner matrix, `probe:` combat probe cells, `ring:` recorder events (SC_ = UNIT_SPELLCAST_, .N = argument N), "
         "`containers:` aura/struct schema, `HSM` pooled rule accuracy vs the combat log, `FINDINGS` curated claim (used only while the quoted sentence is in that run's FINDINGS.md).",
         "- Cumulative SV stores are merged per cell from the newest run holding it; recorder sessions count once.", "",
         "## Status tally", "", "| status | rows |", "|---|---|"]
    for s in STATUSES:
        L.append("| %s | %d |" % (s, state["tally"][s]))
    L += ["", "FINDINGS claims used: %d rows; dropped (quote no longer in FINDINGS): %s." % (
        state["claimsUsed"], ", ".join(state["droppedClaims"]) or "none")]
    L += ["", "## Changed since last run (%s vs state without it)" % (state["runs"][-1] if state["runs"] else "-"), ""]
    if state.get("logOnlyRuns"):
        L += ["%s" % (LOG_ONLY % ", ".join(state["logOnlyRuns"])), ""]
    if state["changes"]:
        L += ["| row | status | readability changes |", "|---|---|---|"]
        for rid, st, reads in _changes_by_row(state["changes"]):
            L.append("| %s | %s | %s |" % (_md(rid), _md(st), _md(reads or "-")))
    else:
        L.append("No row changed.")
    L += ["", "## Top unsolved", "", "| # | row | value | family | combat | icombat | pvp | next step |", "|---|---|---|---|---|---|---|---|"]
    for i, r in enumerate(top_unsolved(cur), 1):
        L.append("| %d | %s | %s | %s | %s | %s | %s | %s |" % (i, r["id"], _md(r["value"]), FAM_LABEL[r["family"]], r["read"]["combat"],
                                                          r["read"]["icombat"], r["read"]["pvp"], _md(r["next"])))
    L += ["", "## Runs", "", "| run | dir | build | addon | recorder sessions (new) | ring events | contexts | token cells | HSM scored | FINDINGS |",
          "|---|---|---|---|---|---|---|---|---|---|"]
    for t in state["runTable"]:
        L.append("| %s | %s | %s | %s | %d | %d | %s | %d | %d | %s |" % (t["label"], t["dir"], t["build"], t["addon"], t["sessions"], t["ringEvents"],
                                                                         ",".join(t["contexts"]) or "-", t["tokenCells"], t["scored"], "yes" if t["findings"] else "-"))
    L += ["", "## Status history (cumulative, per run)", "", "| run | " + " | ".join(STATUSES) + " |", "|---|" + "---|" * len(STATUSES)]
    for h in state["history"]:
        L.append("| %s | %s |" % (h["run"], " | ".join(str(h["tally"].get(s, 0)) for s in STATUSES)))
    L += ["", "## Derivation paths (v2.2.18: no secret is final)", "",
          "Every value family, with the alternate API / higher-order chain that derives it when the direct read is secret. "
          "Status: " + "; ".join("`%s`" % x for x in derivation.DERIVE_STATUSES) + " (see tools/fdump/derivation.py). "
          "Estimates are offline on runs 9-14 against the combat log; probes are ForeverDumpLogDB.derive keys.", "",
          "| row | value | derivation status | path | readable inputs | offline estimate | probe | unit families still open |",
          "|---|---|---|---|---|---|---|---|"]
    for d in derivation_table(cur):
        L.append("| %s | %s | %s | %s | %s | %s | %s | %s |" % tuple(_md(d[k]) for k in ("id", "value", "status", "path", "inputs", "estimate", "probe", "open")))
    for sec, rows in _group(cur).items():
        L += ["", "## %s" % sec, "", "| value | family | ooc | inst | combat | icombat | pvp | HSM status | valid in combat | method | evidence | next step | derivation path |",
              "|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
        for r in rows:
            cell = lambda c: r["read"][c] + (" (%s)" % r["counts"][c] if r["counts"][c] else "")  # noqa: E731
            L.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
                _md(r["value"]), FAM_LABEL[r["family"]], cell("ooc"), cell("inst"), cell("combat"), cell("icombat"), cell("pvp"), r["status"], _md(r["valid"]), _md(r["method"]),
                _md("; ".join(r["evidence"])) or "-", _md(r["next"]), _md(_dcell(r))))
    return "\n".join(L) + "\n"


CSS = """body{font:14px/1.4 system-ui,sans-serif;margin:24px;color:#1d2330;background:#fafbfc}
h1{font-size:22px}h2{margin-top:28px;font-size:18px;border-bottom:1px solid #dde}
table{border-collapse:collapse;margin:8px 0;font-size:12.5px}th,td{border:1px solid #d6dbe4;padding:4px 6px;vertical-align:top}
th{background:#eef1f6;position:sticky;top:0}
.r-clear{background:#d9f5dd;color:#145a22}.r-secret{background:#fbd9d9;color:#7a1414}.r-error{background:#ead9fb;color:#4b1a7a}
.r-mixed{background:#fff1c9;color:#6b4e00}.r-guarded{background:#ffe2c4;color:#7a3d00}.r-nil{background:#eceff3;color:#555}.r--{background:#f4f5f7;color:#999}
.s{display:inline-block;padding:1px 7px;border-radius:9px;font-weight:600;white-space:nowrap}
.s-live{background:#1f9d47;color:#fff}.s-cached{background:#2f7fd1;color:#fff}.s-correlated-proven{background:#0f766e;color:#fff}
.s-provisional{background:#d99a00;color:#fff}.s-estimated{background:#7c5cd6;color:#fff}.s-unsolved{background:#c62828;color:#fff}.s-not-measured{background:#9aa3ad;color:#fff}
small,.ev{color:#556;font-size:11.5px}.ev{max-width:520px}.cnt{display:block;font-size:10.5px;opacity:.8}"""


def _e(s):
    return html.escape(str(s), quote=True)


def _badge(s):
    return '<span class="s s-%s">%s</span>' % (s.replace(" ", "-"), _e(s))


def render_html(state, cur):
    H = ["<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>ForeverDump master secrets guide</title><style>%s</style></head><body>" % CSS,
         "<h1>ForeverDump master secrets guide (cumulative)</h1>",
         "<p>Generated by <code>python3 tools/fdump.py master-guide</code> from every capture under <code>real/</code> (%s). "
         "Data fingerprint <code>%s</code>, newest run <code>%s</code>, %d rows. Same content as SECRETS-GUIDE.md. "
         "No player names or raw GUIDs.</p>" % (_e(", ".join(state["runs"])), _e(state["fingerprint"]), _e(state["newestRun"]), state["rowCount"]),
         "<h2>Legend</h2><table><tr><th>readability</th><th>meaning</th></tr>"]
    for k, v in LEGEND_READ:
        H.append('<tr><td class="r-%s">%s</td><td>%s</td></tr>' % (k, _e(k), _e(v)))
    H.append("</table><table><tr><th>HSM status</th><th>meaning</th></tr>")
    for k, v in LEGEND_STATUS:
        H.append("<tr><td>%s</td><td>%s</td></tr>" % (_badge(k), _e(v)))
    H.append("</table><p><small>Evidence: <b>tokens:</b> token scanner matrix, <b>probe:</b> combat probe cells, <b>ring:</b> recorder events "
             "(SC_ = UNIT_SPELLCAST_, .N = argument N), <b>containers:</b> aura/struct schema, <b>HSM</b> pooled rule accuracy vs the combat log, "
             "<b>FINDINGS</b> curated claim (used only while the quoted sentence is in that run's FINDINGS.md). Cumulative SV stores are merged per cell "
             "from the newest run holding it; recorder sessions count once.</small></p>")
    H.append("<h2>Status tally</h2><table><tr>%s</tr><tr>%s</tr></table>" % (
        "".join("<th>%s</th>" % _badge(s) for s in STATUSES), "".join("<td>%d</td>" % state["tally"][s] for s in STATUSES)))
    H.append("<p>FINDINGS claims used: %d rows; dropped (quote no longer in FINDINGS): %s.</p>" % (
        state["claimsUsed"], _e(", ".join(state["droppedClaims"]) or "none")))
    H.append("<h2>Changed since last run (%s vs state without it)</h2>" % _e(state["runs"][-1] if state["runs"] else "-"))
    if state.get("logOnlyRuns"):
        H.append("<p>%s</p>" % _e(LOG_ONLY % ", ".join(state["logOnlyRuns"])))
    if state["changes"]:
        H.append("<table><tr><th>row</th><th>status</th><th>readability changes</th></tr>")
        for rid, st, reads in _changes_by_row(state["changes"]):
            H.append("<tr><td>%s</td><td>%s</td><td>%s</td></tr>" % (_e(rid), _e(st), _e(reads or "-")))
        H.append("</table>")
    else:
        H.append("<p>No row changed.</p>")
    H.append("<h2>Top unsolved</h2><table><tr><th>#</th><th>value</th><th>family</th><th>combat</th><th>icombat</th><th>pvp</th><th>next step</th></tr>")
    for i, r in enumerate(top_unsolved(cur), 1):
        H.append('<tr><td>%d</td><td>%s</td><td>%s</td><td class="r-%s">%s</td><td class="r-%s">%s</td><td class="r-%s">%s</td><td>%s</td></tr>' % (
            i, _e(r["value"]), _e(FAM_LABEL[r["family"]]), _e(r["read"]["combat"]), _e(r["read"]["combat"]), _e(r["read"]["icombat"]),
            _e(r["read"]["icombat"]), _e(r["read"]["pvp"]), _e(r["read"]["pvp"]), _e(r["next"])))
    H.append("</table><h2>Runs</h2><table><tr><th>run</th><th>dir</th><th>build</th><th>addon</th><th>recorder sessions (new)</th><th>ring events</th>"
             "<th>contexts</th><th>token cells</th><th>HSM scored</th><th>FINDINGS</th></tr>")
    for t in state["runTable"]:
        H.append("<tr>%s</tr>" % "".join("<td>%s</td>" % _e(x) for x in (t["label"], t["dir"], t["build"], t["addon"], t["sessions"], t["ringEvents"],
                                                                        ",".join(t["contexts"]) or "-", t["tokenCells"], t["scored"], "yes" if t["findings"] else "-")))
    H.append("</table><h2>Status history (cumulative, per run)</h2><table><tr><th>run</th>%s</tr>" % "".join("<th>%s</th>" % _badge(s) for s in STATUSES))
    for h in state["history"]:
        H.append("<tr><td>%s</td>%s</tr>" % (_e(h["run"]), "".join("<td>%d</td>" % h["tally"].get(s, 0) for s in STATUSES)))
    H.append("</table>")
    H.append("<h2>Derivation paths (v2.2.18: no secret is final)</h2><p>Every value family, with the alternate API / higher-order "
             "chain that derives it when the direct read is secret. Estimates are offline on runs 9-14 against the combat log; "
             "probes are ForeverDumpLogDB.derive keys.</p><table><tr><th>row</th><th>value</th><th>derivation status</th><th>path</th>"
             "<th>readable inputs</th><th>offline estimate</th><th>probe</th><th>unit families still open</th></tr>")
    for d in derivation_table(cur):
        H.append("<tr>%s</tr>" % "".join("<td>%s</td>" % _e(d[k]) for k in ("id", "value", "status", "path", "inputs", "estimate", "probe", "open")))
    H.append("</table>")
    for sec, rows in _group(cur).items():
        H.append("<h2>%s</h2><table><tr><th>value</th><th>family</th><th>ooc</th><th>inst</th><th>combat</th><th>icombat</th><th>pvp</th><th>HSM status</th>"
                 "<th>valid in combat</th><th>method</th><th>evidence</th><th>next step</th><th>derivation path</th></tr>" % _e(sec))
        for r in rows:
            cells = "".join('<td class="r-%s">%s<span class="cnt">%s</span></td>' % (_e(r["read"][c]), _e(r["read"][c]), _e(r["counts"][c])) for c in CTXS)
            H.append('<tr id="%s"><td>%s</td><td>%s</td>%s<td>%s</td><td>%s</td><td><small>%s</small></td><td class="ev">%s</td><td><small>%s</small></td><td><small>%s</small></td></tr>' % (
                _e(r["id"]), _e(r["value"]), _e(FAM_LABEL[r["family"]]), cells, _badge(r["status"]), _e(r["valid"]), _e(r["method"]),
                "<br>".join(_e(x) for x in r["evidence"]) or "-", _e(r["next"]), _e(_dcell(r))))
        H.append("</table>")
    H.append("</body></html>")
    return "\n".join(H) + "\n"


# --------------------------------------------------------------------------------------------------------- CLI
def write(root=ROOT):
    files, state = generate(root)
    for rel, text in files.items():
        p = os.path.join(root, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8") as f:
            f.write(text)
    return files, state


def check(root=ROOT):
    """-> list of problems (empty = fresh)"""
    problems = []
    names = list_runs(root)
    files, _ = generate(root)
    for rel, text in files.items():
        p = os.path.join(root, rel)
        if not os.path.exists(p):
            problems.append("%s missing" % rel)
            continue
        with open(p, encoding="utf-8") as f:
            if f.read() != text:
                problems.append("%s does not match generator output" % rel)
    newest = 0.0
    for n in names:
        for p in input_files(root, n):
            newest = max(newest, os.path.getmtime(p))
    for rel in OUTPUTS:
        p = os.path.join(root, rel)
        if os.path.exists(p) and os.path.getmtime(p) < newest:
            problems.append("%s is older than the newest run data" % rel)
    return problems
