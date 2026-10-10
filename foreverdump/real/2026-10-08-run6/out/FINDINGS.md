# FINDINGS — runs 6, 6b (v2.2.6) and run 7 (v2.2.7 health check)

Redacted: no player names or GUIDs. NPC ids and spell ids only. Times are client-local (ET).
Truth = WoWCombatLog (read offline only). Live = what the addon recorded without CLEU.

## 0. Run 7 (v2.2.7, 19:26–19:32 ET): health check

- **Version.** 2.2.7 ran (`addonVersion` 2.2.7, tape hdr 2.2.7, build 70291). Login session 26 started 19:26:49. Capture `cap-…193236-27` ran ON 19:32:36 → OFF 19:32:40 (3.8 s, out of combat, 0 casts, 0 UNIT_COMBAT).
- **Errors.** No new Lua errors and no new selfErrors. The SV holds 2 errors and 4 selfErrors, all from runs 6/6b (last 18:41:04). There were 0 ADDON_ACTION_BLOCKED and 0 restriction events in sessions 26/27.
- **Taint.** taint.log has 22 entries, all at 19:32:36.684: 18 expected and 4 contained, 0 unexpected. They come from the deliberate secret-op probes run inside pcall (Controls.lua:154-156 OPS, Lab.lua:241-246 boundary experiments, Core.lua:569 `date("*t").isdst`).
- **HSM alive.** `inference` now exports sid + counters for cap-27. In 6/6b it never did.
- **Static dump.** The static dump landed:
  - `ForeverDumpStaticDB` 10.91 MB, marker `reason=auto`, written at 19:27:10 (21 s after login, not at ON).
  - `ForeverDumpDocsDB`/`StringsDB` are gone (migrated).
- **Why the file is still 14.4 MB.** WoW writes every SavedVariable of an addon into one file (`ForeverDump.lua`), so the static DB sits in the same file. Breakdown:

  | SavedVariable | size |
  |---|---|
  | ForeverDumpStaticDB | 10.91 MB (written once per build) |
  | ForeverDumpDB | 1.15 MB (was 7.88 MB in 6b) |
  | ForeverDumpLogDB | 1.99 MB (cumulative; mostly the 6/6b tapes) |
  | ForeverDumpRecordDB | 0.26 MB |
  | ForeverDumpCombatLogDB | 0.10 MB |

  The run-7 capture itself added a 4.5 KB tape (93 records), 29 record events and 0 CL events. Per-capture data is small; the file size is the static DB. If a small main file matters, move the static DB to a load-on-demand companion addon (own SV file).
- **ObjectiveTracker.** No ObjectiveTracker error in sessions 26/27; its 8 occurrences end at 18:41:04, in 2.2.6. uiIntegrity has the same signature (`BonusW QuestW WorldQuestW Achievement= Scenario= CampaignQuestW`) at section:docs, capture:on before/after and capture:off.
- **Guard.** The capture was out of combat, so CombatGuard had nothing to skip, and there were 0 blocks. Not verifiable from the SV: `guardSkips` is only a runtime counter and is never persisted (follow-up below).
- **Live damage.** Run 7 can't answer the live-damage question: no combat. The combat log sent with run 7 is the 6b log plus 104 lines, ending 18:41:15. It holds no 19:xx data.
- **Known 2.2.7 data bug confirmed in the field.** All 92 run-7 `ws` records carry `p` only (no `q`), so the lossy pack shipped in 2.2.7. It is fixed in source (§6, B2).

## 1. Top priority — why the live engine saw 0 of my 11 damage events (6b), and 0/17 (run 6)

**Root cause: the live HSM never started.** The DamageMeter.lua:51 secret-boolean error was real but secondary. The evidence:

1. `selfErrors`: `Drift.lua:156 attempt to index global 'os'` with where=`capture:spell knowledge + HSM inference`, at every capture start: 18:30:32 (run 6), 18:35:32 and 18:38:52 (6b). Chain: `I.NewHSM → Timing.Attach → Drift.Decay → os.time`. The shipped spell-timing seed carries `lastSeen` dates (81 entries), so Decay ran on every start. WoW has no `os` table.
2. The inference export has only `sid/anchor/ctx0/player/appliers`: no counters, no signals, no inferences.
3. The replay tapes hold only `dm/hdr/sec/ws` records: **0 decide records** in 9012 (6b) and 1814 (run 6). The determinism report said "OK (0 groups)". That pass was vacuous (fixed: now VACUOUS = failure, §6).

**The live stream carried every hit. Nothing was missing from the client side:**

| | run 6 | run 6b |
|---|---|---|
| my damage events (log) | 17 | 11 |
| matched by a live UNIT_COMBAT with the same amount | 17/17 (nameplate2 17, target 16, targettarget 4) | 11/11 (nameplate1 11, target 11, softenemy 5) |
| live − log offset | ±8 ms (melee ≈ +459 ms, swing lag) | −2 ms median; melee up to +458 ms |
| offline HSM replay (same library, log-inferred target) | damage-on-target 16/16, taken 11/11, heal-on-me 6/6, interrupt 1/1, miss 1/1 | damage-on-target 18/18, taken 17/17, heal-on-me 2/2, miss 1/1; 0 false-self |
| replay mine vs meter vs log | 1318 / 1327 / 1327 (−9, inside tol) | 439 / 439 / 439 |
| naive "everything on my target is mine" | — | 61.1 % correct, 7 false-self, 534 wrongly credited |

**Proof the fix works.**
- In-game: run 7 HSM exported counters, with no selfError. Combat is still unproven in-game.
- In tests: `tests/hsm_alive.lua` runs a whole capture with `os = nil`. It gets 8/8 on 2.2.7 and fails 7 on 2.2.6.

**Real-time detection path (no combat log), with the evidence from these runs:**

1. **dm-frame rule (main).** `DAMAGE_METER_COMBAT_SESSION_UPDATED` (type 0/1/10 with sid ≠ 0, then sid 0) fires in the same frame as each of my hits, including procs and DoT ticks with no cast in the frame.
   - 6b: Lightning Shield 26366 ×4 and Flame Shock 8052 ticks ×4 were all claimed by dm-frame (replay rules: dm-frame 8, cast-frame 3).
   - A hit on my target with no meter tick in its frame is someone else's (elimination; 6b: 8 hits, 534 dmg).
2. **cast-frame rule.** My `UNIT_SPELLCAST_SUCCEEDED` (spellID clear for the player) lands in the same frame as the direct hit. Cast-sync (UNIT_SPELLCAST_SUCCEEDED ↔ SPELL_CAST_SUCCESS): run 6 n=5, 0 ms; 6b n=10, median −3.5 ms (−6…−2), drift −0.21 ms/min.
3. **swing-lag rule** for melee: PLAYER_SWING, then UNIT_COMBAT at +0.3–0.5 s.
4. **Token coverage.** The same hit arrives on target, nameplateN, softenemy and targettarget, all with the clear amount. Use target/focus/player, plus nameplates in capture mode, canonicalised by GUID.
   - Probe (/tmp/uc_multi.lua): the same hit on 3 tokens counts once. A mob hit on player+targettarget counts once as taken.
   - Not a bug, but worth turning into a permanent test (below).
5. **Post-combat exact spell per hit (new).** After combat the meter exposes clear per-spell totals (`CombatSpell.spellID/totalAmount` C after combat; S in combat).
   - Assign the live hit amounts to spells by subset-sum. 6b: 26366=176, 8046=184, 8052=79 → **exactly one assignment, 11/11 correct**.
   - The same works for taken (`takenSpells` 6660=494) and for heals (8008=400).

## 2. Reconcile verdicts (live ↔ meter ↔ log)

| fight | damage | healing | interrupts | taken | dispels |
|---|---|---|---|---|---|
| run 6 f1 | match (1318/1327/1327) | match 243 | match 1/1 (after the fix; was off 0/1) | match 290 | unexplained (meter 0, log none) |
| run 6b f1 | match 439 | match 400 (gross 456 − overheal est. 56) | unexplained (0/0) | match 494 | unexplained |

Per-unit (IdKey) rows: run 6 player match; 6b player match (439/400/494).

The "6b per-unit off 1327" earlier was a **tool bug** (B5): the join took the meter fight by index, so 6b fight 1 got run 6's numbers.

## 3. Meter ↔ log per-unit join (heals)

- **My heals.** Lesser Healing Wave 8008:
  - Run 6, 18:31:12.121: 243 → live player HEAL 243 at +1 ms.
  - 6b: 227 (56 over) and 229 (0 over) → live 227/229. The meter counts **effective** 400 = live gross 456 − estimated overheal 56. The HSM now reconciles effective healing (with a test).
- **Thrill of Adventure (1261483) HoT, 5 per tick on me.** Seen live: UNIT_COMBAT player HEAL 5 every 2.0 s (18:31:18.562 … 18:31:26.594). The aura was removed (`removedAuraInstanceIDs` clear ooc) in the frame of the last tick. *(This corrects an earlier note that said these ticks were unseen.)*
- **Target self-heal.** Healing Wave 939 by NPC 4096, 18:30:52.558, 339.
  - Live: UNIT_COMBAT HEAL 339 on nameplate2/target/targettarget at +1 ms, plus that unit's UNIT_SPELLCAST_SUCCEEDED/STOP (castBarID clear, spellID secret).
  - **The engine drops heals on hostiles** (`HybridState.lua:1017 "heals on hostiles: not attributed"`), so heal-on-target replays 0/1. Proposal P4.
- **Not seen live:**
  - 18:31:04.683: a 324 self-heal by a second NPC 4096 that was neither target nor on a nameplate event.
  - 6b: the heals of another NPC (321, 340).
  - 6b: a 335 self-heal 0.27 s before I targeted that NPC.
  - All four were off-token: no unit token showed those units.

## 4. Interrupt and the DM type-5 sample

- **Run 6, 18:31:15.001.** My Earth Shock 8046 interrupted Healing Wave 939 cast by NPC 4096. In the same frame (all −2 ms vs the log):
  - UNIT_SPELLCAST_INTERRUPTED on target/nameplate2/targettarget (payload secret except castBarID, which differs per token);
  - my UNIT_SPELLCAST_SUCCEEDED 8046;
  - DM type 5 `(5,40)` and `(5,0)`.
  - Type 5 fired only here and once in an older session (00:03:17). The meter's Interrupts=1 matches.
- **6b.** 9 live UNIT_SPELLCAST_INTERRUPTED and 0 SPELL_INTERRUPT in the log:
  - 1 on a nameplate in the frame of that NPC's UNIT_DIED (killed mid-cast);
  - 8 on player/targettarget (my own casts, filtered).
  - So INTERRUPTED alone ≠ interrupt. It needs my cast or DM type 5 in the frame, and must not have a UNIT_DIED of the same GUID in the frame (P5).
- **Replay.** interrupt 1/1 after the tool fix (B4); `verify:interrupt-attribution` 100 % (n=1).

## 5. Shadow-rule verdicts and rule accuracy (current library replayed)

| rule | run 6 | run 5 | run 6b |
|---|---|---|---|
| damage-on-target | 100 % (16) | 100 % (41) | 100 % (18) |
| damage-taken | 100 % (11) | 100 % (36) | 100 % (17) |
| heal-on-me | 100 % (1–6) | 100 % (54) | 100 % (2) |
| heal-on-target | **0 % (1)**: hostile heals dropped (P4) | — | — |
| interrupt | 100 % (1) | 100 % (1) | — |
| miss-on-target | 100 % (1) | 100 % (4) | 100 % (1) |
| overheal-estimate | 100 % (1) | 96.3 % (54) | 100 % (2) |
| cooldown-fail | — | 100 % (4) | 0 % (1) |

- Shadow findings:
  - `shadow-dm-type7`: cross-run 22/26, precision 0.846 (enemy melee on me).
  - `meter-frame-join`: cross-run 11/14.
  - `totem-heal-live` (provisional, run 5 only).
  - `identity-interrupt` (provisional, n=1).
- Contradictions: 0 in both replays.
- 6b counters: fail-outside-cd 3, fail-gcd 1. These match the 4 SPELL_CAST_FAILED of mine in the log.

## 6. Bugs found (this follow-up)

| # | where | effect | status |
|---|---|---|---|
| B1 | Drift.lua `os` (2.2.6) | live HSM never ran in 6/6b → 0 live attributions | fixed in shipped 2.2.7. Permanent test: tests/hsm_alive.lua. Confirmed in run 7 (HSM exported, no selfError) |
| B2 | WorldCapture 64-bit pack in a Lua double | exists/health/healthMax codes rounded away in every `ws` record (2.2.6 **and shipped 2.2.7**; run 7: 92/92 `p` only) | fixed in source (p/q words) + tests/worldcap_pack.lua + legacy decoder marks `L`. **Not in a zip** |
| B3 | ReplayLog.IdKey npc pattern | every NPC → `npc:1`, so per-unit world rows of different NPCs merge (2.2.6 and **shipped 2.2.7**) | fixed in source + test. **Not in a zip** |
| B4 | coverage replay took own casts only from HSM signals | with the HSM down, the interrupt scored 0/1 | fixed: raw UNIT_SPELLCAST_* fallback (`castSource=raw-events`), test |
| B5 | damagemeter_join picked the meter fight by index | 6b fight 1 joined to run 6's meter (false "off") | fixed: by epoch, test |
| B6 | replay "decide determinism OK (0 groups)" | hid the dead HSM | fixed: VACUOUS = failure, test |
| B7 | perf: real WorldCapture slice mean 0.126–0.130 ms > 0.10 budget (TokenScan 0.1295 > 0.12 in run 6); the bench passes (0.073) | unflagged real-client overrun | now a perf flag, test |
| B8 | HSM drops heals on hostile units | heal-on-target 0/1 | proposal P4 (engine) |
| B9 | `guardSkips` not persisted | the guard cannot be verified from an SV | follow-up: write it into tape hdr/selfstats at OFF |
| B10 | converter outputs on the box (`inference/*`, `convert.log`) contain the player GUID | box-only and never packaged, but violates "no GUIDs in outputs" if ever shared | follow-up: scrub at write time |

All new checks are in `tests/test_v227_findings.py` (14), `tests/hsm_alive.lua` (8) and `tests/worldcap_pack.lua` (5), all wired into the runner.

## 7. World capture coverage (ws) per token, and what other-unit state we actually got

- **Formats.** 6/6b: all legacy-lossy. exists/health/healthMax were lost (`L`) whenever a high field was set. Run 7 is the same (2.2.7 zip).
- **Waste.**
  - 98.6 % (run 6) / 98.8 % (6b) of `ws` samples are tokens that do not exist: raid*/party*/boss*/arena* solo, and empty nameplates.
  - `ws` is 79–85 % of the tape. 6b: 7553 of 7646 samples were all-absent; only 93 described a real unit.
- **Clear values we did get:**
  - target: threat C (with `th`), threat detail C (`tp`), power S, casting N, range C (out of combat; G = guarded in combat from 2.2.7), dead C (6).
  - nameplates: threat C, ids, target-of; healthMax via nameplateNtarget.
  - player: buff/debuff counts, health.
  - softenemy: present 1/27.
  - Health of other units: not recoverable from the legacy packs (lost nibble).
- **Cost.** The real client spent ≈ 60 % of FD handler time in captures on TokenScan + WorldCapture (capture 4: 215 of 350 ms), mostly on absent tokens (P6).

## 8. Distinct-findings correlation pass (2nd/3rd order, timing, identity)

- **1st order (cross-run).**
  - meter-frame-join (11/14, lift 21).
  - cd-payload-clear (SPELL_UPDATE_COOLDOWN carries my spellID clear in combat; arg3 = 133 on GCD).
  - token-alias (targettarget ≡ player when a mob targets me).
  - dm-type-7 (22/26).
  - live `UNIT_DIED` → log UNIT_DIED (held on run 5 and 6b at 1.0).
- **2nd/3rd order chains (held-1/cross-run).**
  - `UNIT_COMBAT target WOUND → SPELL_UPDATE_COOLDOWN → my SPELL_DAMAGE` (prec 0.545, lift 6.2).
  - `UNIT_AURA player full → SPELL_UPDATE_COOLDOWN → my SPELL_DAMAGE` (0.75).
  - `UNIT_FLAGS player → SPELL_UPDATE_COOLDOWN → my cast` (0.6).
  - These say SPELL_UPDATE_COOLDOWN is a reliable "I just acted" clock. It is already used by cast-frame/cd rules, so the chains add nothing new to encode.
- **Timing joins.**
  - Live−log: casts −3.5 ms, UNIT_COMBAT −2…+1 ms, UNIT_DIED −1/−2 ms (19/19), melee +0.46 s, DM same frame.
  - 6b timing model: UNIT_COMBAT − file time = −0.002 s median.
- **Identity joins.**
  - UNIT_DIED carries the **clear Creature GUID** (6b: 19/19 log deaths matched by GUID at −1/−2 ms; 39 live deaths in total, 20 out of log range).
  - The meter's after-combat `EnemyDamageTaken.sources[].creatureID` (6b: 4093 = 439) gives the NPC id of what I hit.
  - Interrupt identity = my cast + DM type 5 in frame.
- **Miner flaw.** The miner keyed some chains on `UNIT_SPELLCAST_SENT arg1` = the target's **name** (free text). That is an identity leak and overfitting. Hash or drop free-text args before mining (P9).

## 9. Manual combat-log review — what we don't capture or infer yet, and how to get it live

| in the log | count (6 / 6b spans) | live today | how to get it live |
|---|---|---|---|
| UNIT_DIED (npc) / PARTY_KILL (me) | 6 / 19; 1 / 0 | recorded (clear GUID), **not used by the HSM** | P2: kill timeline, killing blow = my hit (dm-frame) in the frame before UNIT_DIED of that GUID, fight end, per-NPC TTK |
| per-hit spell id of my damage | 17 / 11 | cast-frame only (direct hits) | P3: after-combat meter per-spell subset-sum (6b unique 11/11); live probe of `#combatSpells` growth per DM update |
| NPC self-heals (939) | 2 / 3 | target/nameplate HEAL clear, dropped | P4 |
| resisted/blocked/absorbed/overkill on hits | 25+10+8 / 29+10+13 (mostly others) | no (UNIT_COMBAT has amount only) | overkill: meter `CombatSpell.overkillAmount` after combat (C); partial resist: below-range verdict "U" already |
| overheal | 4 / 32 | estimated from health (100 %, n=2) | keep; add the meter effective-vs-gross check per fight (done) |
| my cast failures with reason | 0 / 4 | UNIT_SPELLCAST_FAILED (no reason) | probe UI_ERROR_MESSAGE in the same frame for the reason id |
| totem summons (8155) | 0 / 2 | PLAYER_TOTEM_UPDATE (OnTotem) | already; verify GetTotemInfo clarity in combat |
| enemy casts (6660/6351/939 starts) | 21 / 57 | START/STOP/INTERRUPTED with castBarID; spellID secret | duration fingerprint per NPC id (castModel) + after-combat `takenSpells` (6b 6660=494) |
| damage to me by spell | 24 / 59 SPELL_DAMAGE 6660 | UNIT_COMBAT WOUND + school | after-combat `takenSpells` subset-sum (same as P3) |
| other players' damage/heals/auras near me | hundreds | only via my target/nameplates | out of scope (no token); elimination gives others-on-my-target only |
| absorbs on me (SPELL_ABSORBED) | 7 / 25 | no | `UNIT_ABSORB_AMOUNT_CHANGED` is registered; join the drop with the WOUND frame |
| energize | 64 / 251 (mostly others) | ENERGIZE on player only | UNIT_POWER_UPDATE delta for me |

## 10. Proposed engine changes, ranked by value

1. **P1 HSM start isolation + visible "HSM DOWN".**
   - pcall each attach (Timing/Learned/Drift/Knowledge) so a failure degrades the seed, not the engine.
   - Set an `hsmUp` flag in the tape hdr; print one chat line; show a red HSMUI row.
   - Test: inject an error into Timing.Attach → the HSM still attributes.
2. **P2 Consume UNIT_DIED (clear GUID).** Kill/killing-blow/fight-end/TTK. Evidence: 19/19 at −1/−2 ms.
3. **P3 Post-combat exact spell per hit** from meter per-spell totals (damage, taken, heal) by subset-sum over live amounts. Evidence: 6b unique 11/11. Plus a live `#combatSpells` probe.
4. **P4 Hostile heals.** Record HEAL on target/focus/nameplates into the world unit. Rule "self-heal": the unit's UNIT_SPELLCAST_SUCCEEDED/STOP in the frame. Evidence: 339 at +1 ms with the cast in frame.
5. **P5 Interrupt hardening.**
   - Add a `interrupt-dm-frame` rule (DM type 5 in frame, no own cast, solo).
   - Never count INTERRUPTED with a same-GUID UNIT_DIED in the frame (6b: killed mid-cast).
6. **P6 Event-driven WorldCapture/TokenScan list.** Only existing tokens: group roster + NAME_PLATE_UNIT_ADDED/REMOVED; ws on change only. Would cut ~98 % of samples and ~84 % of the tape. Brings the real slice cost under budget (B7).
7. **P7 Ship B2/B3** (p/q pack and IdKey) — this is the hotfix decision below.
8. **P8 Persist guard/selfstats** (`guardSkips`, HSM up, counters) into the tape hdr at OFF (B9).
9. **P9 Miner hygiene.** Drop/hash free-text args (names) before mining.

## 11. SV MB/min

| capture | duration | tape | tape MB/min |
|---|---|---|---|
| run 6 cap-9 | 0.98 min | 92 KB | 0.13 (79 % ws) |
| 6b cap-14 | 1.73 min | 168 KB | 0.137 |
| 6b cap-21 | 2.39 min | 191 KB | 0.113 (85 % ws) |
| run 7 cap-27 | 0.06 min, idle | 4.5 KB | ≈0.07 (100 % ws) |

- All capture-scoped DBs in 6b: LogDB 1.77 + RecordDB 0.44 + CombatLogDB 0.17 ≈ 2.4 MB over ≈5.5 capture-min, about **0.43 MB/min** (includes the meter/probe snapshots).
- Static: 2.2.6 rewrote ≈13 MB of static data with the capture (ForeverDumpDB 7.88 + Docs 4.14 + Strings 1.04). 2.2.7 writes it once per build (10.91 MB StaticDB) and ForeverDumpDB is 1.15 MB.
- With P6 the tape would be ≈0.02–0.03 MB/min.
- Run 6 perf: FD memory +64.8 MB and frame time ×2.9 at capture end. This matches the 2.2.6 first-ON full dump that 2.2.7 removed; confirm on the next combat capture.

## 12. Replay determinism

- 6b: 3 sessions, 9012 records, 0 privacy hits, 0 conflicts. All 3 sessions are now **VACUOUS**: combat on tape, 0 decide records.
- Run 6: 1 session, 1814 records, VACUOUS.
- Determinism of live decisions remains unproven until a 2.2.7 **combat** capture.

## Next capture needed

One 2.2.7 combat capture with combat logging on: a few pulls, one interrupt, one self-heal. It proves the live HSM in combat (11/11-style), B9 and the guard in combat.
