"""v2.2.18 derivation inventory: for every guide row (value family x unit family) and every former
"unsolvable" HSM row, the alternate API / higher-order inference chain that derives the secret value, which inputs are
readable, the offline estimate on runs 9-15 (combat log truth, leave-one-run-out reference data) and the live probe
(ForeverDumpLogDB.derive key) that settles the open readability question.

Status vocabulary:
  direct        the value itself is readable (no derivation needed)
  derived       derivation implemented and scored offline (numbers in `estimate`)
  derivable     derivation designed; inputs readable; needs the probe / live scoring
  probe         an input's readability is still unknown; the Derive probe measures it in the next BG
  bound         only a bound / presence is derivable from readable inputs today
"""

DERIVE_STATUSES = ("direct", "derived", "derivable", "probe", "bound", "unsolvable by design")

# id -> dict(path, inputs, estimate, probe, status, fam={family: overrides})
DERIVE = {
    "health": dict(
        status="derived",
        path="UNIT_COMBAT amounts (clear on every token) accumulated per IdKey (GUID, or name key for hostile players) "
             "on a cached max (healthMax row) -> c-hp-net running estimate; resync on any clear UnitHealth read and on "
             "UNIT_DIED (0) / out-of-combat full",
        inputs="UNIT_COMBAT action/amount/school (clear), UNIT_HEALTH tick timing (clear), healthMax cache",
        estimate="c-hp-net offline (run 14 BG): 89.1% of samples within tolerance of the log value",
        probe="derive.read UnitHealthPercent|UnitHealthMissing per family/ctx (an alternate API may be clear)",
        fam={"player": dict(status="direct", path="UnitHealth on player is clear; running estimate only as a fallback")}),
    "healthMax": dict(
        status="derived",
        path="clear UnitHealthMax reads cached per IdKey / NPC id; otherwise RefData.npcs[npcId].maxHP[level] (mined) "
             "or RefData.classLevelHP[class][level] once the class engine knows the class (UnitLevel is clear on target)",
        inputs="UnitHealthMax ooc, UnitLevel (clear on target), class engine, RefData npcs (35) and classLevelHP (106 cells)",
        estimate="NPC max: exact per level from the log; player max: class x level median (gear spread, the HP net "
                 "corrects with the first clear percentage)",
        probe="derive.read UnitHealthMax|nameplateN|hostileP|combat and UnitLevel per family",
        fam={"player": dict(status="direct", path="clear")}),
    "power": dict(
        status="derivable",
        path="power TYPE is clear in UNIT_POWER_* (feeds the class engine); amount: player = UNIT_POWER_UPDATE deltas + "
             "own cast costs (RefData cost); others = RefData spell cost x observed casts (mana spent lower bound), rage "
             "from UNIT_COMBAT dealt/taken, energy regen model",
        inputs="UNIT_POWER_FREQUENT powerType (clear: plates RAGE 599 / MANA 446 / ENERGY 112), cast timing, RefData cost",
        estimate="type: 100% readable (run 14 tape); amount: not scored yet",
        probe="derive.read UnitPower / UnitPowerMax per family/ctx; UnitPowerType (clear)"),
    "absorbs": dict(
        status="derivable",
        path="UNIT_ABSORB_AMOUNT_CHANGED (fires) + UNIT_COMBAT WOUND with the ABSORB flag in the same frame; the shield "
             "size from RefData amount bands of the absorb spell (caster class known)",
        inputs="absorb-changed delivery, UNIT_COMBAT flags (clear), RefData amount bands",
        estimate="presence: 100% from the event; size: amount band of the spell (2-98 percentile)",
        probe="derive.read UnitGetTotalAbsorbs per family/ctx"),
    "incheal": dict(
        status="bound",
        path="UNIT_HEAL_PREDICTION timing + the healer's cast start (raid tokens: timing clear) + RefData heal amount band",
        inputs="event timing, friendly cast timing, RefData amount bands",
        estimate="not scored (low value)",
        probe="derive.read UnitGetIncomingHeals per family/ctx"),
    "health-event": dict(status="direct", path="event delivery is clear", inputs="UNIT_HEALTH", estimate="-", probe="-"),
    "dead": dict(status="direct", path="UnitIsDeadOrGhost clear", inputs="-", estimate="-", probe="-"),
    "casting": dict(status="direct", path="event delivery is clear", inputs="-", estimate="-", probe="-"),
    "spellid": dict(
        status="derivable",
        path="(1) UnitCastingInfo planned start/end (if clear) -> planned cast time -> RefData castTime x the caster's class "
             "(class engine) -> candidate spells; (2) out of combat the meter's CombatSpells per clear-GUID source lists the "
             "spellIds actually used; (3) NPCs: castModel per NPC id",
        inputs="cast timing (clear), class engine, meter CombatSpells ooc (clear), RefData castTime (640 spells)",
        estimate="START->SUCCESS duration as the fingerprint: 0-60% (pushback stretches it) -> rejected; planned time "
                 "needs the probe",
        probe="derive.cast cast:<family> positions 5/6 (startMS/endMS) and 10 (spellID) codes",
        fam={"player": dict(status="direct", path="own spellIds clear")}),
    "castbar": dict(status="direct", path="castBarID clear", inputs="-", estimate="-", probe="-"),
    "casttiming": dict(
        status="derivable",
        path="START->STOP/SUCCEEDED event timing (clear) + RefData castTime of the derived spell; planned end from "
             "UnitCastingInfo if clear",
        inputs="event timing, RefData", estimate="planned-time readability pending",
        probe="derive.cast positions 5/6",
        fam={"player": dict(status="direct", path="clear")}),
    "interrupted": dict(status="direct", path="event delivery is clear", inputs="-", estimate="-", probe="-"),
    "interrupt-mine": dict(status="derived", path="HSM frame join (my cast / DM type 5 in the INTERRUPTED frame)",
                           inputs="clear timing", estimate="HSM accuracy in the guide evidence", probe="-"),
    "aura-event": dict(status="direct", path="UNIT_AURA delivery is clear", inputs="-", estimate="-", probe="-"),
    "aura-payload": dict(
        status="bound",
        path="payload wholly secret in BG -> presence/timing only: UNIT_AURA frame joined with a cast SUCCEEDED of a "
             "class-known caster in the same frame -> RefData spells of that class with an aura duration",
        inputs="UNIT_AURA timing, cast timing, class engine, RefData auraDur",
        estimate="identity from duration alone 1.0% unique (27.6k applications); with caster class 5.3% -> needs the "
                 "cast-frame join",
        probe="derive.read GetAuraSlots / GetAuraDataByIndex field codes per family/ctx"),
    "aura-details": dict(
        status="derivable",
        path="own auras: HSM cast+aura frame join (proven); others: caster cast frame + class + RefData auraDur, confirmed "
             "by the removal time (UNIT_AURA) matching the mined duration",
        inputs="as aura-payload", estimate="duration+class unique 5.3% offline; cast-frame join not yet scored",
        probe="derive.read aura field codes (spellId/duration/expirationTime/sourceUnit)"),
    "aura-count": dict(
        status="derivable",
        path="count = clear ooc baseline + UNIT_AURA add/remove deltas inferred from the cast-frame join",
        inputs="UNIT_AURA timing", estimate="not scored", probe="derive.read GetAuraSlots per family/ctx"),
    "aura-presence": dict(
        status="derivable",
        path="clear GetUnitAuraBySpellID state out of combat (instance / world) carried into combat; in combat the "
             "own-cast frame (UNIT_SPELLCAST_SUCCEEDED spellID clear) + UNIT_AURA delivery on the same unit marks applied, "
             "known duration / UNIT_AURA remove marks gone (replay decide 'applied player sp=17364' etc.)",
        inputs="AuraData clear ooc (8/8 fields C, run 20), own spellID clear in combat, UNIT_AURA delivery clear",
        estimate="run 20: ooc presence 52/52 agree with the log; combat nil = 3/3 false absence",
        probe="auraPresence tape + replay decide applied/removed"),
    "aura-mine": dict(status="derived", path="HSM my-cast + UNIT_AURA frame join", inputs="clear own casts",
                      estimate="HSM accuracy in the guide evidence", probe="-"),
    "guid": dict(
        status="derivable",
        path="hostile players: name key (UnitName is clear on target C60, plate C6, targettarget C9) replaces the GUID as "
             "the identity (IdKey('name', name)); the meter's GUID is clear out of combat",
        inputs="UnitName (clear), meter sourceGUID ooc", estimate="name key covers 100% of named hostile players",
        probe="derive.meter.ooc guidClear / nameClear counters",
        fam={"player": dict(status="direct", path="clear")}),
    "name": dict(status="direct", path="clear (never stored raw)", inputs="-", estimate="-", probe="-"),
    "unit-combat": dict(status="direct", path="clear", inputs="-", estimate="-", probe="-"),
    "hit-mine": dict(status="derived", path="HSM dm-frame / cast-frame / swing-lag rules", inputs="clear timing + meter ticks",
                     estimate="HSM accuracy in the guide evidence", probe="-"),
    "hit-taken": dict(status="derived", path="UNIT_COMBAT player WOUND + DM type 7", inputs="clear", estimate="proven", probe="-"),
    "heal-mine": dict(status="derived", path="UNIT_COMBAT HEAL on me; same-class tie-break via the totem tick phase",
                      inputs="clear", estimate="see same-class tie-break", probe="-"),
    "heal-hostile": dict(status="derivable", path="UNIT_COMBAT HEAL on hostile tokens is clear; record it into the world unit",
                         inputs="clear", estimate="input clear", probe="-"),
    "unit-died": dict(status="derivable", path="secret player deaths: DM type 9 (deaths) in the same frame + the c-hp-net "
                                               "estimate reaching 0 + UnitIsDeadOrGhost on the name-keyed token",
                      inputs="DM type 9, UnitIsDeadOrGhost (clear)", estimate="not scored", probe="-"),
    "threat": dict(status="bound", path="n/a for enemy players; NPCs: last clear status + hit-mine damage share",
                   inputs="UNIT_THREAT_LIST_UPDATE timing", estimate="-", probe="derive.read UnitThreatSituation"),
    "range": dict(status="derivable", path="UnitDistanceSquared / UnitInRange probes; else own-spell range errors and "
                                           "swing updates; plates exist only within the plate distance",
                  inputs="plate add/remove (clear)", estimate="bound only", probe="derive.read UnitDistanceSquared/UnitInRange",
                  fam={"target": dict(status="direct", path="cached")}),
    "cooldown": dict(status="derived", path="HSM cd tracker from my casts + SPELL_UPDATE_COOLDOWN", inputs="clear own casts",
                     estimate="proven", probe="-"),
    "meter": dict(status="derived", path="totals clear after combat; in combat the session update timing + DM ticks",
                  inputs="session events", estimate="provisional", probe="derive.meter counters"),
    "class": dict(
        status="derived",
        path="class engine (Lib/ClassEvidence): BG scoreboard GetBattlefieldScore name + LOCALIZED class (+ faction "
             "-> enemy) assigns the whole enemy team per name key from BG prep (v2.2.20); power type (P) eliminates; "
             "clear spellId / summon -> RefData class; meter composition (K) is provisional only (v2.2.20); meter "
             "name-key join (M) only where enemy meter names are clear",
        inputs="GetBattlefieldScore name/faction/race/class clear on 100% of rows (run 15: 2432 ooc + 446 combat); "
               "classToken secret; powerType clear; enemy meter names 0/5594 clear in a BG (run 15)",
        estimate="run 15 live: comp made 10 enemy SHAMAN assignments, >= 6 false (truth 4 shamans; 3 had rage/energy) -> "
                 "comp demoted to provisional. P+K 0 false on runs 9-15 (coverage 6.2-26.3%). M measured by raw GUID join "
                 "(v2.2.21 rawjoin): 0% in the BG on runs 9-15 (in-BG meter snapshots list only my team with clear GUIDs), "
                 "post-BG snapshot 15/16 enemies, 100% class-correct. Scoreboard rule: server class per name, promoted; join to plate "
                 "keys checked live by derive.score bfJoin",
        probe="derive.score bfRow / bfJoin, derive.meter.ooc enemyNameClear, derive.summary (enemyAssigned, "
              "enemyProvisional, overridden)",
        fam={"player": dict(status="direct", path="clear"), "friendly": dict(status="direct", path="party/raid UnitClass clear")}),
}

# value families that have no guide row of their own (former HSM-STATUS section 3 + new)
EXTRA = [
    ("census", "enemy same-class census (how many enemy shamans)", dict(
        status="derived",
        path="meter rows with displayType 2 (enemy) carry a clear classFilename -> per-team class composition -> "
             "Inference.SetMeterEnemyCensus (max with the plate count, 120 s validity)",
        inputs="meter classFilename (clear)", estimate="enemy shaman count = log on runs 10-14 (0/0, 1/1, 3/3, 0/0, 3/3); "
                                                       "full composition 13/15 to 16/19 enemies in the window",
        probe="derive.meterCompLast vs the log")),
    ("same-class", "which of two same-class players applied an identical aura / heal on me", dict(
        status="derived",
        path="totem tick phase: a friendly shaman's raid-token cast timing (clear) sets candidate drop times; a tick not on "
             "my own drop phase (mod 2 s) is not mine; RefData summons -> owner class; GetTotemInfo for my own slots",
        inputs="raid-token cast timing (clear), my totem drop time (clear), RefData summons",
        estimate="Healing Stream ticks on me, runs 9-15: other shamans' ticks exclude me 35/35; my ticks keep me "
                 "216/227 (95.2%)",
        probe="derive.read GetTotemInfo#1-4|global, UnitIsOwnerOrControllerOfUnit on pet/totem plates")),
    ("aura-source", "aura identity and source on other units (BG)", dict(
        status="bound",
        path="UNIT_AURA frame + the caster's cast timing in that frame + caster class (engine) + RefData auraDur; "
             "confirmed by the removal at the mined duration",
        inputs="UNIT_AURA timing, cast timing, class engine, RefData",
        estimate="duration alone 1.0%, duration + caster class 5.3% unique; cast-frame join not yet scored",
        probe="derive.read aura field codes")),
    ("others-spellid", "other players' cast spellIds (BG)", dict(
        status="derivable",
        path="planned cast time (UnitCastingInfo) x class -> RefData; ooc meter CombatSpells per source; learned votes "
             "(refLearned[build].spellClass)",
        inputs="cast timing (clear), meter ooc spell lists (clear)", estimate="see spellid",
        probe="derive.cast positions 5/6/10")),
    ("meter-enemy", "meter breakdown per enemy unit", dict(
        status="derivable",
        path="enemy rows (displayType 2, no id) out of combat: name + classFilename + totals + CombatSpells clear -> "
             "per-enemy breakdown keyed by name key; in combat only the composition",
        inputs="meter rows ooc", estimate="names clear in 14/16 ooc observations (run 14); per-enemy totals ooc",
        probe="derive.meter.ooc enemyNameClear / rows")),
    ("race-level", "race / sex / level / faction of hostile players", dict(
        status="derivable", path="UnitLevel + UnitFactionGroup clear on target; race/sex: probe; scoreboard race field",
        inputs="UnitLevel, UnitFactionGroup (clear on target)", estimate="level/faction: direct on target",
        probe="derive.read UnitRace/UnitSex per family; derive.score race")),
    ("pet-owner", "pet / totem / summon owner", dict(
        status="derivable",
        path="RefData.summons npc id -> owner class (28 mined); UnitIsOwnerOrControllerOfUnit pair probe; pet power "
             "type FOCUS/HAPPINESS -> hunter pet",
        inputs="pet powerType (clear), npc id from clear GUIDs", estimate="28 summon types, share >= 0.9 used",
        probe="derive.read UnitIsOwnerOrControllerOfUnit|pair")),
    ("scoreboard", "BG scoreboard (kills, damage, healing per player)", dict(
        status="probe", path="GetBattlefieldScore / C_PvP.GetScoreInfo out of combat (RequestBattlefieldScoreData every 10 s)",
        inputs="unknown", estimate="-", probe="derive.score field codes")),
    ("spec", "spec of hostile players", dict(
        status="derivable", path="GetArenaOpponentSpec (arena); BG: talent-only spells from RefData via the spellId path",
        inputs="spellId path", estimate="-", probe="derive.score talentSpec, ARENA_PREP")),
]


# v2.2.19 out-of-combat cache (OocFill.lua + Lib/UnitCache.lua): the first step of the path wherever a value reads
# clear out of combat (prep, after combat, graveyard, between fights) - read per identity, cached with source / time /
# staleness, verified by later clear reads (contradiction -> unknown).
OOC = {
    "health": "max health cached per identity ooc (exact) is the c-hp-net base",
    "healthMax": "every token read ooc caches UnitHealthMax per merged identity (TTL 600 s, drift counted)",
    "power": "power type + max power cached per identity ooc",
    "aura-details": "ooc aura scan per token: spellId / duration / source key -> HSM ledger + learned aura durations",
    "aura-count": "ooc aura scan gives the baseline count per identity",
    "aura-payload": "ooc aura scan seeds the HSM ledger (instance id -> spell) before the fight",
    "guid": "GUID key and name key linked on one clear read: in combat the name key resolves the GUID key",
    "class": "class cached ooc per identity (tokens, meter roster, scoreboard) pre-assigns the class engine",
    "spellid": "ooc aura scan votes spell -> source class (learned per build)",
    "range": "-",
}
OOC_EXTRA = {
    "census": "meter roster swept on every ooc moment",
    "same-class": "who-targets-whom edges from every *target token (shadow rule tt-same-class)",
    "meter-enemy": "enemy roster names / GUID keys swept ooc into the cache",
    "race-level": "race / level / faction / sex cached per identity ooc and verified later",
    "pet-owner": "pet tokens (pet, partypetN, raidpetN) link the owner key at every ooc read",
    "scoreboard": "RequestBattlefieldScoreData + sweep on UPDATE_BATTLEFIELD_SCORE ooc; clear class -> cache",
    "spec": "arenaN: GetArenaOpponentSpec cached per identity",
}
for _k, _t in OOC.items():
    if _k in DERIVE and _t != "-":
        DERIVE[_k]["path"] = "ooc cache: " + _t + "; " + DERIVE[_k]["path"]
for _k, _v, _e in EXTRA:
    if _k in OOC_EXTRA:
        _e["path"] = "ooc cache: " + OOC_EXTRA[_k] + "; " + _e["path"]
EXTRA.append(("target-chains", "who targets whom (every *target token)", dict(
    status="derivable",
    path="ooc cache + sweep: XNtarget edges between identity keys (party/raid/boss/arena/nameplate/target/focus/mouseover)"
         " -> shadow rules tt-attacker (hostiles targeting me when I am hit) and tt-same-class (same-class friendlies "
         "targeting a unit whose auras changed)",
    inputs="UnitName on *target tokens (clear for players), GUID ooc", estimate="not scorable offline (the log has no "
    "targets); live counts in oocfill.shadow",
    probe="oocfill.shadow / oocfill.events (timestamps for the log join)")))
EXTRA.append(("enemy-distance", "distance to each hostile player (BG)", dict(
    status="direct",
    path="UnitDistanceSquared on hostile tokens (clear 100% in and out of combat in a BG, run 15)",
    inputs="nameplate / target tokens", estimate="run 15: 226/226 hostile-player reads clear",
    probe="derive.read UnitDistanceSquared|hostileP")))
EXTRA.append(("prefill", "knowledge cached before a unit's first in-combat event", dict(
    status="derived",
    path="ooc cache per identity (class, level, max health, faction, race, power) checked at each unit's first "
         "in-combat event (oocfill.prefill)",
    inputs="clear ooc reads, meter roster, scoreboard",
    estimate="run 15 LIVE: enemy class cached at the first in-combat event 0/99 (meter names secret, comp not a cache "
             "source), level 99/99, max health 0/99; scoreboard rule (v2.2.20) caches every enemy class from BG prep. "
             "Offline (assumed M join) runs 9-15 per fight episode: enemy class cached 86.6-95.5% (75.8-83.6% weighted by ooc name readability), "
             "friendlies 100%, NPC max health 79-100%; class TTI median 6.6-10.7 s -> 0 s",
    probe="oocfill.prefill per kind")))

EXTRA.append(("secret-compare", "compare / key / rawequal on secret values", dict(
    status="unsolvable by design",
    path="rawequal, table key, and == on secret numbers are all blocked (ForceTaint_Strong)",
    inputs="any secret number / secret string",
    estimate="run 16 in-game: attempt to compare ... secret number value, while execution tainted by ForceTaint_Strong",
    evidence="user paste 2026-10-09; TESTED / CLOSED — do not pursue as an identity side-channel",
    probe="n/a (closed)")))


# v2.2.22 T-container audit (user directive 2026-10-09: collect data first, then conclude). Before v2.2.22 a container
# with SOME secret fields ("T": issecrettable / HasSecretValues / one secret field) was skipped, dropped whole, or
# coarse-coded "secret" in these probes; every conclusion below rests on such a probe and is re-marked until the
# v2.2.22 data-collection build re-measures it per field and per BG phase.
REMEASURE = {
    "class": "scoreboard GetScoreInfo fields were never read on T rows (2787/2877 ooc, 1140/1140 combat); enemy meter "
             "names '0/5594 clear' came from DamageMeter field() which returned nil (coded N) for every T source struct",
    "scoreboard": "GetScoreInfo per-field codes missing on T rows; the '15% clear table' figure is RETRACTED (it counted "
                  "only all-clear tables, which had every field clear incl. talentSpec/classToken/guid)",
    "spec": "talentSpec on GetScoreInfo T rows never read (clear on all 90 all-clear tables)",
    "meter-enemy": "DamageMeter source/session structs flagged by issecrettable were never indexed (every field -> N)",
    "prefill": "'meter names secret' rests on the same DamageMeter T-skip",
    "aura-details": "derive.read aura field codes recorded only for all-clear (K) aura structs; T structs skipped",
    "aura-source": "derive.read aura field codes recorded only for K aura structs",
    "aura-payload": "UNIT_AURA removed-ID lists classified T were skipped whole (Inference) and counted as secret "
                    "(LabProbes); recorder dropped T event payload tables as SECRET_TABLE",
    "aura-count": "LabProbes counted T added/removed lists as secret instead of counting them",
    "race-level": "scoreboard race field per phase not recorded (GetBattlefieldScore per-position only)",
}
for _rid, _why in REMEASURE.items():
    _row = DERIVE.get(_rid)
    if _row is None:
        _row = next((e for k, _l, e in EXTRA if k == _rid), None)
    if _row is not None:
        _row["remeasure"] = _why
        _row["estimate"] = "NEEDS RE-MEASURE (v2.2.22 T-audit: %s). Prior: %s" % (_why, _row.get("estimate", "-"))


# v2.2.23: run 17 (2026-10-10, raw, 0 hashed) re-measured the rows above per field x BG phase. Sources: KTH_ForeverDiag
# (scoreboard + nameplate per phase prep/gates/combat/post, 400 GetScoreInfo + 400 GetBattlefieldScore rows, 750 enemy
# plate samples) and FD v2.2.21 per-field probes (DamageMeter schema, CombatProbe, derive.read, inference inputs).
# Run 17 ran FD v2.2.21, so FD's own @phase keys (v2.2.22) are absent; rows that need them stay NEEDS RE-MEASURE.
MEASURED = {
    "class": "MEASURED run 17: scoreboard name/className/classToken/faction CLEAR in every phase (GetScoreInfo prep 150 / "
             "gates 130 / combat 120 / post rows; GetBattlefieldScore pos 1,6-9 same); enemy plate UnitClass SECRET (gates "
             "189, combat 561; no enemy plates in prep); meter classFilename CLEAR, name/GUID SECRET. Board keyed 'First "
             "Surname' -> join on (first, faction): run 17 sim 15/15 enemies assigned, 14 met plates, 0 false (GUID-checked); "
             "re-sim runs 10-13,16,17: 141/141 enemies joinable, class at first event 100% (P-only 0-8%)",
    "scoreboard": "MEASURED run 17 (KTH) + run 18 (FD 2.2.23 own @phase probes, identical codes; GetScoreInfo prep 500 / gates 2771 / combat 1380 / post 30 rows, post = K all clear): name, className, classToken, faction C in prep/gates/combat/post; guid, "
                  "talentSpec, damage, healing, KB, HK, deaths, honor, rating, roleAssigned S in prep/gates/combat, C post; "
                  "race N, bgRating N always. GetBattlefieldScore (Forever, no 'rank'): 1 name, 6 faction, 7 race, 8 className, "
                  "9 classToken C all phases; 2-5, 10-13, 15-17 S except post; 14 N. The old 'classToken secret' was pos 10 "
                  "(damage) misread by an r[]/position off-by-one",
    "spec": "MEASURED run 17: GetScoreInfo.talentSpec S in prep/gates/combat, C only post (per unit: no). Meter "
            "CombatSource.specIconID C in ooc and combat (24/24) but its name/GUID is S for enemies -> enemy spec "
            "composition is clear, per-unit spec is not",
    "meter-enemy": "MEASURED run 17 (DamageMeter per-field schema; the source structs were K, so the T-skip did not apply): "
                   "enemy CombatSource.name S and sourceGUID S ooc and in combat (15/15 enemies; derive.meter ooc enemy "
                   "names clear 0/15406); classFilename, specIconID, isLocalPlayer, classification C; amounts S in combat, "
                   "C after combat. Prior '0/5594' stands",
    "prefill": "MEASURED run 17: meter enemy names S (confirmed) -> enemy class prefill must come from the scoreboard join. "
               "Live v2.2.21 enemy prefill class 0/214 because score rows were keyed by full name; v2.2.22 keys name:<First> "
               "(sim: 14/14 seen enemy plates covered at first in-combat event)",
    "aura-details": "MEASURED run 17 (ctx ooc/combat): in a BG every C_UnitAuras call errors (client rule: aura enumeration raises for ANY addon/insecure caller while auras are secret; same message reported for Questie, WarpDeplete, Ace3; run 18 E on every unit family, no success) (E: hostile 143 "
                    "ooc / 367 combat, other 1210 ooc / 548 combat; 'Auras cannot be accessed when secret while tainted') -> "
                    "no struct is returned, so the T-skip was moot; outside a BG all 14 fields C (20 K structs). Prep vs "
                    "gates split still needs FD v2.2.22 @phase keys",
    "aura-source": "MEASURED run 17: same as aura-details (call-level E in a BG for any addon caller, not an FD-specific taint; sourceUnit C outside BG)",
    "race-level": "MEASURED run 17: race from GetBattlefieldScore pos 7 C in all phases; GetScoreInfo.race N; hostile "
                  "UnitRace S, UnitLevel C. FD v2.2.20-22 parsed race from pos 8 (localized className) -> wrong; fixed v2.2.23",
}
STILL_REMEASURE = {}
# v2.2.24: run 18 (FD v2.2.23 live, raw) measured the last two rows with the v2.2.22+ counters (infoT/addT/remT).
MEASURED.update({
    "aura-payload": "MEASURED run 18 (FD 2.2.23): UNIT_AURA updateInfo is a T container on 9153/9160 events (S 0); its "
                    "fields: addedAuras S when present / N when absent (lab addSecret 4581, addT 0), removedAuraInstanceIDs "
                    "S/N (remSecret 3219, remT 0, clear 4 IDs), updatedAuraInstanceIDs S/N, isFullUpdate S (CombatProbe "
                    "UNIT_AURA field codes, restricted + combat). Event KIND (added/removed/updated present) is clear via "
                    "S-vs-N; contents and IDs are secret. Prior 'payload wholly secret' stands for the contents",
    "aura-count": "MEASURED run 18: added/removed lists are SECRET values (not T) -> no length; counts 0 readable in a BG "
                  "(4 clear removed IDs on raid units); only per-event presence (S vs N) and event counts per unit family "
                  "(nameplate 730, party 1514, raid 5310, target 424 ...)",
})
for _rid, _what in list(MEASURED.items()) + list(STILL_REMEASURE.items()):
    _row = DERIVE.get(_rid)
    if _row is None:
        _row = next((e for k, _l, e in EXTRA if k == _rid), None)
    if _row is None:
        continue
    _prior = _row.get("estimate", "-").split("Prior: ", 1)[-1]
    if _rid in MEASURED:
        _row.pop("remeasure", None)
        _row["measured"] = "run17"
        _row["estimate"] = "%s. Prior: %s" % (_what, _prior)
    else:
        _row["remeasure"] = _what
        _row["estimate"] = "NEEDS RE-MEASURE (%s). Prior: %s" % (_what, _prior)


def lookup(row_id, family=None):
    e = DERIVE.get(row_id)
    if e is None:
        return None
    out = {k: v for k, v in e.items() if k != "fam"}
    if family and family in e.get("fam", {}):
        out.update(e["fam"][family])
    return out
