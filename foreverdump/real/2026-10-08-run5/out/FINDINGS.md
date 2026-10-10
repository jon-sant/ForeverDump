# Run 5 findings (2026-10-08, Forever 1.60.1.70245, shaman, addon v2.2.3)

All times are ET (box-local) on 2026-10-08. Ground truth is the client's own `WoWCombatLog.txt`, read offline on the box only.
The addon never used CLEU and no side channels were used. Names of other players are replaced by labels ("other player A").
Reports: `out/coverage/COVERAGE.md`, `out/analysis/ANALYSIS.md` (ranked leads), `out/analysis/VERIFY.md`,
`out/analysis/TOKENS.md`, `out/knowledge/KNOWLEDGE.md`, `out/inference/HSM.md`, `out/perf/PERF.md`, guide section 12.
Re-create everything with `sh real/2026-10-08-run5/convert.sh` (about 80 s).

Capture: 151 s. Three fights: 00:02:03–00:02:31, 00:02:42–00:03:20 (contains my Earth Shock interrupt at 00:03:17.98) and
00:03:31–00:03:45. In the third fight an ungrouped mage ("other player A") hit my target.

## Top findings in plain words

1. **The addon can tell my damage from someone else's on my target, live, without the combat log.** The v2.2.4 attribution
   rules were replayed over the live events v2.2.3 recorded in game. Every hit was credited correctly: damage on my target,
   damage taken, heals, misses and the interrupt (100%, up from 0% with the v2.2.3 rules). Not one of the mage's hits was
   credited to me. A meter that counts everything on my target as mine would have given me 360 damage that was the mage's.
2. **The damage meter matches the combat log to the point after combat.** Post-combat `C_DamageMeter` values equal the log
   for my damage (1324 / 1213 / 799), damage taken (267 / 935 / 221) and interrupts (0 / 1 / 0). In combat its numbers are
   secret, but its update event is not, and it fires in the same frame as *my* damage. It does not track an ungrouped player at
   all, which is exactly what makes "live total minus meter = others" work.
3. **The cooldown tracker never contradicted reality.** None of my 25 casts landed while the tracker said "cooling" or
   "on GCD". All 4 "Not yet recovered" failures in the log happened while it said cooling. Every known GCD answer held:
   totems 1.0 s, Lightning Shield 1.5 s.
4. **The correlation miner found the Earth Shock interrupt by itself, with no rule written for it.** It also found that the
   damage meter's update of type 5 fired once in the whole capture, in exactly the frame of the interrupt. That is a
   candidate live "my interrupt landed" signal, worth confirming with more interrupts.
5. **The "tooltip gets an extra line while on cooldown" idea is not proven, so it stays off.** In combat every shock showed
   one extra tooltip line. That matches "the shocks share a cooldown and one was cooling" perfectly (21/21), but run 5 has
   only one sample moment, so it can't be told apart from "shocks always gain a line in combat". One more sample with the
   shocks ready decides it.
6. **v2.2.3 fixed the frame-rate drop in game.** In run 5 the whole addon used 0.185% of wall time, and the cost per call
   stayed flat over the session (run 4: frame time went from 20.7 to 59.3 ms).
7. **14 values became secret in combat compared with the run-2 baseline,** so the drift guard matters:
   `C_Spell.GetSpellCooldown`, `GetSpellCooldownDuration`, `UnitCastingInfo` / `UnitCastingDuration`, the
   `UNIT_SPELLCAST_*` spell/cast-id arguments and the `UNIT_AURA` payload. 6 became clear, among them `UnitHealthMax` and
   `UnitPowerMax` out of combat. The tracker exists because the cooldown API is now secret in combat.

## Coverage matrix summary (log truth vs what the addon read live)

Per category (log events in the capture span → seen live → amount readable → spell id readable). Full matrix: COVERAGE.md.

| what | log | seen live | amount | spell id | why the rest is missing |
|---|---|---|---|---|---|
| my damage (combat) | 44 | 39 | 39 | 9 | 4 killing-blow hits in the frame the mob died and the target changed, 1 dropped by the offline recorder (5/s cap); melee and DoT ticks carry no spell id |
| hostile NPC damage (to me / my totems) | 28 | 26 | 26 | 0 | 2 on units without a token |
| my misses / NPC misses on me | 4 / 10 | 4 / 10 | 4 / 10 | 3 / 0 | – |
| heals from my totems (combat + ooc) | 110 | 51 | 51 | 0 | ticks landing on the totem itself have no unit token |
| my auras gained / lost (combat) | 7 / 11 | 7 / 8 | 0 | 0 | payload secret in combat, presence readable |
| my casts (start / success / fail) | 3 / 24 / 4 | all | – | all | spell id is clear for the player |
| hostile casts (start / success) | 7 / 5 | 4 / 4 | – | 0 | spell id and cast GUID secret in combat |
| my interrupt | 1 | 1 | – | – | interrupter fields secret; timing identifies it |
| other players' events | 166 | 2 | 2 | 0 | not on a token the addon follows: invisible by design |
| deaths | 5 | 0 | – | – | no unit-token event (UNIT_HEALTH only) |

Miss explainer (every missed log event classified): no-api-signal 59 (totem heals on totems), secret-payload 10 (aura
presence only), target-changed 9, recorder-throttle 1. No rule gap and no wrong attribution.

## The other mage on my target (fight 3, 00:03:31–00:03:45)

- Log: other player A cast Frost Armor (00:03:29.7), then two Frostbolts on my target: 177 at 00:03:38.2 and 183 at
  00:03:41.4. That is 360 damage, against my 799 in the fight.
- Live, the addon saw both hits as `UNIT_COMBAT` WOUND on target, school 16 (frost), amounts readable. The mage's casts never
  reached a token the addon follows (5 casts in the log, 0 visible).
- The hard case: my Frost Shock is also frost (105 crit at 00:03:37.5). It was credited to me by the cast-frame rule (my
  own cast in the same frame). The Frostbolts had no own cast in their frame *and no damage-meter update in their frame*, so
  elimination credited them to "other".
- Result: live "other" 360 = log 360. Live "mine" 799 = log 799 = meter 799. 0 false self-attributions. The meter's
  "others" was 0 (it does not track ungrouped players), so the reconciliation "live total − meter mine = 360 others on my
  target" holds exactly.

## C_DamageMeter findings

| fight | duration log / meter | my damage log / meter | others on my target log / meter | taken log / meter | my effective heal log / meter | interrupts log / meter |
|---|---|---|---|---|---|---|
| 1 | 28.5 / 28 | 1324 / 1324 | 0 / 0 | 267 / 267 | 69 / 69 | 0 / 0 |
| 2 | 37.4 / 37 | 1213 / 1213 | 0 / 0 | 935 / 935 | 555 / 555 | 1 / 1 |
| 3 | 14.4 / 14 | 799 / 799 | 360 / 0 | 221 / 221 | 18 / 12 | 0 / 0 |

- Post-combat reads are clear and exact for my damage, damage taken and interrupts. Duration is whole seconds. Fight 3
  healing differs by 6 (log effective 18, meter 12); unexplained, so it is watched in the next run.
- In combat `C_DamageMeter.GetCombatSessionFromType` returns a container with secret contents: `durationSeconds`,
  `totalAmount` and `maxAmount` are secret, while the `combatSources` container is readable. Out of combat everything is
  clear. `IsDamageMeterAvailable` is always clear.
- `DAMAGE_METER_COMBAT_SESSION_UPDATED(type, sessionID)`: 426 events (414 in combat), with no secret argument ever. Counts
  per type: 0, 1, 10: 80 each; 2, 3: 66; 7: 52; 5: 2 (one frame, at the interrupt). It fires in the frame my damage or
  healing lands, so it is timing evidence of *my* events.
- An ungrouped player is absent from the meter. Others on my target = live `UNIT_COMBAT` total − meter mine.
- Live vs meter gaps: fight 1 live mine 1219 vs 1324. The 105 is the killing-blow swing, which landed in the frame the mob died
  and my target changed (miss class target-changed). Fight 2: 1088 vs 1213. The 125 is one swing the offline recorder dropped at its 5/s
  cap; the live HSM gets every event, so in game this gap would not exist.

## HSM before / after

Attribution, replay of the run-5 live events scored against the log (before = v2.2.3 library, after = v2.2.4 HybridState):

| category | n | before accuracy | after accuracy | after false self |
|---|---|---|---|---|
| aura on me | 2 | 50.0% | 100% | 0 |
| aura on target | 6 | 83.3% | 100% | 0 |
| damage on target | 41 | 0% | 100% | 0 |
| damage taken | 36 | 0% | 100% | 0 |
| heal on me | 54 | 0% | 100% | 0 |
| interrupt | 1 | 0% | 100% | 0 |
| miss on target | 4 | 0% | 100% | 0 |

Rule accuracy over all captures (current library, replay): damage on target 100% (run 3, n=1) → 90% (run 4, n=10) → 100%
(run 5, n=41). Damage taken and heals on me were 100% in all three runs. Overheal estimate 96.3% (52 of 54 exact).

New v2.2.4 checks on run 5 (replay):
- cooldown tracker: 25/25 casts consistent; 4/4 "Not yet recovered" confirmed.
- cooldown model vs log failures: 4 confirmations.
- enemy cast bars: 2 predictions, mean error 0.056 s; the NPC 4119 Lightning Bolt model has a median of 3.5 s.
- verification ring: 24 verdicts, 0 refuted; cooldown 100% (10 confirmed), cast-end, damage-range and interrupt
  attribution 100%.
- Ledger: target token→GUID right 41 of 44 times. Its 50 "maybe removed" doubts were justified 35 times. A scoring bug used
  to count those doubts as wrong claims; it is fixed.

The live HSM that ran in game (v2.2.3) scored aura presence 58.3% in combat (12 judged) and cooldowns 2/2 (10 pending).
That gap is why v2.2.4 moved to the timing-based attribution, Ledger and tracker above.

Cost: v2.2.3 in game 0.185% of wall time, flat per call. The v2.2.4 perf gate: aged/fresh 1.00–1.18, storm 0.29–0.39%,
40-man scanner slice at most 0.115 ms against a 0.12 ms budget (PERFORMANCE.md).

## Tooltip extra-line cooldown hypothesis: evidence table (signal disabled unless proven)

Rule: enable `hsm.tooltipCooldownSignal` only with at least 10 known-answer samples per phase, 100% agreement and at least
2 sample moments. Only tooltip line **counts** were recorded, never text. Sample moment: the in-combat knowledge pass (one
moment for all spells). "On cooldown" comes from the log (my last cast of the spell within its base cooldown).
**Verdict: NOT proven, so the signal stays off.** Agreement is 14/21 with "this exact spell was on cooldown" and 21/21 with
"a spell of the same shared shock cooldown was on cooldown", from 1 sample moment.

| spell | name | lines ooc → combat | extra line | on cooldown (my own last cast, log) | on cooldown (shared-cooldown view, assumption) | agrees (own / shared) |
|---|---|---|---|---|---|---|
| 556 | Astral Recall | 4 → 4 | no | no | no | ✓ / ✓ |
| 2484 | Earthbind Totem | 5 → 5 | no | no | no | ✓ / ✓ |
| 5730 | Stoneclaw Totem | 5 → 5 | no | no | no | ✓ / ✓ |
| 6390 | Stoneclaw Totem | 5 → 5 | no | no | no | ✓ / ✓ |
| 6391 | Stoneclaw Totem | 5 → 5 | no | no | no | ✓ / ✓ |
| 8042 | Earth Shock | 4 → 5 | yes | no | yes | ✗ / ✓ |
| 8044 | Earth Shock | 4 → 5 | yes | no | yes | ✗ / ✓ |
| 8045 | Earth Shock | 4 → 5 | yes | no | yes | ✗ / ✓ |
| 8046 | Earth Shock | 4 → 5 | yes | no | yes | ✗ / ✓ |
| 8050 | Flame Shock | 4 → 5 | yes | no | yes | ✗ / ✓ |
| 8052 | Flame Shock | 4 → 5 | yes | yes | yes | ✓ / ✓ |
| 8053 | Flame Shock | 4 → 5 | yes | no | yes | ✗ / ✓ |
| 8056 | Frost Shock | 4 → 5 | yes | no | yes | ✗ / ✓ |
| 8177 | Grounding Totem | 5 → 5 | no | no | no | ✓ / ✓ |
| 17364 | Stormstrike | 4 → 4 | no | no | no | ✓ / ✓ |
| 20572 | Blood Fury | 4 → 4 | no | no | no | ✓ / ✓ |
| 20608 | Reincarnation | 5 → 5 | no | no | no | ✓ / ✓ |
| 408341 | Fire Nova | 4 → 4 | no | no | no | ✓ / ✓ |
| 408342 | Fire Nova | 4 → 4 | no | no | no | ✓ / ✓ |
| 437009 | Totemic Projection | 4 → 4 | no | no | no | ✓ / ✓ |
| 1299026 | Shatter Curse | 4 → 4 | no | no | no | ✓ / ✓ |

What it means: the extra line appears on exactly the spells of one shared cooldown (the shocks), and Flame Shock 8052 was
cooling at that moment. Two explanations fit: "the line shows the shared cooldown" or "shocks gain a line in combat anyway".
To decide, the next run needs a second in-combat sample with all shocks ready. v2.2.4's `knowledge.cdLineProbe` records line
counts and types per phase automatically.

## What the correlation miner found that we hadn't

The miner pairs every live event shape with every log event shape at 50 / 150 / 300 / 750 ms. It scores each pair against
a null model and checks it on the other captures (run 3, run 4).
- **Rediscovered without a rule:** my `UNIT_SPELLCAST_SUCCEEDED` (Earth Shock 8046) ↔ `SPELL_INTERRUPT` 8046, same frame,
  matching spell id. The target's (and nameplate's / soft-enemy's) `UNIT_SPELLCAST_INTERRUPTED` lands in the frame of my
  Earth Shock (p = 0.002). The interrupter fields of that event are secret in combat; timing alone identifies it. This is
  the golden test (`tests/test_golden_run5.py`).
- **New: damage meter type 5.** `DAMAGE_METER_COMBAT_SESSION_UPDATED` with type 5 occurred once in 151 s, in the
  interrupt frame (p = 0.0007). It is a candidate clear "my interrupt counted" signal. It needs at least 3 more interrupts to
  become a rule, so for now it is provisional.
- **New: the soft-enemy token reports the shock crit.** `UNIT_COMBAT softenemy CRITICAL school 8` in the interrupt frame is
  the Earth Shock hit itself (nature, crit), seen through the soft-enemy token as well as target and nameplate. That makes
  soft-enemy a third view of the same unit; it is not a separate interrupt signal.
- **New: targettarget mirrors me.** When the mob targets me, `UNIT_SPELLCAST_SENT/SUCCEEDED targettarget` repeats my own
  casts (precision 0.86–1.0, held on 2 other captures). That is a token alias: useful for dedupe, and no new information.
- **New: free "my cast happened" echo.** `BAG_UPDATE_COOLDOWN` fires on every one of my successful casts (25/25,
  precision 1.0, held on 2 captures).
- **New: totem heal ticks are visible as `UNIT_HEAL_PREDICTION player`** (precision 0.9, recall 1.0, held on 2 captures).
  The heal tick itself only shows when it lands on me.
- Privacy fix found on the way: miner keys carried `UNIT_SPELLCAST_SENT` target names. Player names are now redacted
  (`<player>`), and NPC names (game data) stay.

## Higher-order / distinct findings (v2.2.5, offline)

Post-review cleanup: token-alias collapse (global only for strong me-views like `targettarget`→`player`; same-frame payload dedup otherwise),
add-½ smoothed lift with CI (no more 9999), chain minimality, holdout status (**cross-run** / **held-1** / **provisional** / **failed** — provisional clears when holdout holds),
echo appendix, and a short **Distinct findings** table (≤12 rows). See `out/correlate/CORRELATE.md`.

**Runs 3+4+5 full profile:** mine 13.3s + higher 3.9s + distill 0.04s = **17.4s** total; 12 distinct findings; 265 minimized HO leads; 33 echoes parked.

### Confirmed / refuted (reviewer expectations)
1. **(a) SPELL_UPDATE_COOLDOWN clear spellID — CONFIRMED, already live.** `arg0=370` (Purge) → `SPELL_CAST_SUCCESS|me>npc|spell=370` support **6/6**, prec 1.0, lift 10.5 [1.7–31.5], **cross-run** held on runs 4/5. `arg3=133` is GCD start-recovery. Already fed to CooldownTracker via `HS:CDPayload` (v2.2.4) — **no new Lua / no new zip**.
2. **(b) Totem heal ticks live — CONFIRMED as a distinct finding; overlap note.** `UNIT_COMBAT|player` HEAL + `UNIT_HEAL_PREDICTION|player` → `SPELL_PERIODIC_HEAL|mine>me|spell=6371` (~0.8 prec, cross-run). Heals that land **on me** are already well covered by live attribution (`heal-on-me`). The remaining gap is ticks on the totem units themselves (`no-api-signal` in the miss explainer). Proposed TotemHealLive is review-only; not auto-wired.
3. **(c) DAMAGE_METER type 7 on every enemy melee on me — CONFIRMED.** 47/47 (run 3 best), prec 1.0, cross-run held. Proposed MeterType7 review-only.
4. **(d) Meter frame-join / elimination — CONFIRMED, already live.** Distinct finding `meter-frame-join` (cross-run). HybridState already subtracts meter-attributed hits; no new Lua.
5. **(e) Interrupt identity chain — CONFIRMED, provisional.** `INTERRUPTED|target` → `SUCCEEDED|player` → `SPELL_INTERRUPT|me>npc` (support 1, prec 1.0, run 5 only; holdout absent on 3/4). Needs ≥3 interrupts before enabling InterruptAttribution.

### Distinct findings (this run)
- **dm-type-7** [cross-run, already-live=False]: DAMAGE_METER update type 7 fires on every enemy melee hit on me (best 47/47, prec 1.0).
- **cd-payload-clear** [cross-run, already-live=True]: SPELL_UPDATE_COOLDOWN carries my spellID in the clear during combat (arg0=370 matched SPELL_CAST_SUCCESS spell=370, support 6/6, prec 1.0). arg3 is the GCD start-recovery category (133 = on GCD, 0 = o
- **meter-frame-join** [cross-run, already-live=True]: DamageMeter update fires in the same frame as my UNIT_COMBAT hits; hits without a meter tick (and without my cast) are someone else's -- subtract to recover others-on-target
- **totem-heal-live** [cross-run, already-live=False]: Totem heal ticks (e.g. spell 6371) show live as UNIT_COMBAT HEAL + UNIT_HEAL_PREDICTION on player with no own cast nearby (~0.9 precision).
- **token-alias** [cross-run, already-live=False]: Unit-token aliasing: when a mob targets me, targettarget (and often nameplate/softenemy) refers to the same unit as player, so every player signal is duplicated on those tokens. Mining collapses alias
- **identity-interrupt** [provisional, already-live=False]: target cast interrupted (secret interrupter) + my Earth Shock SUCCEEDED in the same frame -> the interrupt was mine
- **chain:SPELL_UPDATE_COOLDOWN=>SPELL_CAST_SUCCESS|me>none** [cross-run, already-live=False]: SPELL_UPDATE_COOLDOWN links via UNIT_AURA / player / arg1.has=addedAuras to ground truth SPELL_CAST_SUCCESS / me>none (end-to-end precision 0.405, lift 12.83 vs shuffled-time null)
- **chain:UNIT_AURA|player|arg1.has=isFullUpdate=>SPELL_CAST_SUCCESS|me>none** [cross-run, already-live=False]: UNIT_AURA / player / arg1.has=isFullUpdate links via SPELL_ACTIVATION_OVERLAY_HIDE to ground truth SPELL_CAST_SUCCESS / me>none (end-to-end precision 0.364, lift 9.0 vs shuffled-time null)
- **chain:UNIT_COMBAT|target=>SPELL_DAMAGE|me>npc** [held-1, already-live=False]: UNIT_COMBAT / target / arg1=WOUND links via SPELL_UPDATE_COOLDOWN to ground truth SPELL_DAMAGE / me>npc (end-to-end precision 0.5, lift 8.8 vs shuffled-time null)
- **chain:UNIT_SPELLCAST_SUCCEEDED|target=>SPELL_CAST_SUCCESS|npc>me** [provisional, already-live=False]: UNIT_SPELLCAST_SUCCEEDED / target links via UNIT_SPELLCAST_STOP / target to ground truth SPELL_CAST_SUCCESS / npc>me / spell=7951 (end-to-end precision 1.0, lift 12.75 vs shuffled-time null)
- **chain:PLAYER_TOTEM_UPDATE=>SPELL_PERIODIC_DAMAGE|npc>player** [provisional, already-live=False]: PLAYER_TOTEM_UPDATE links via SPELL_UPDATE_USABLE -> PLAYER_TOTEM_UPDATE to ground truth SPELL_PERIODIC_DAMAGE / npc>player / spell=744 (end-to-end precision 0.833, lift 10.15 vs shuffled-time null)
- **chain:UNIT_SPELLCAST_SENT|player=>SPELL_PERIODIC_DAMAGE|npc>player** [provisional, already-live=False]: UNIT_SPELLCAST_SENT / player links via PLAYER_TOTEM_UPDATE to ground truth SPELL_PERIODIC_DAMAGE / npc>player / spell=744 (end-to-end precision 0.312, lift 10.15 vs shuffled-time null)


### Higher-order review checklist
1. Prefer chains with holdout **held** on ≥1 other capture and precision ≥ 0.7.
2. Identity interrupt (INTERRUPTED + my SUCCEEDED → SPELL_INTERRUPT) needs ≥3 interrupts before a live rule.
3. DamageMeter type-5 / UNIT_COMBAT frame joins need the same.
4. Elimination (others-on-target) needs a party/raid pull with a second damager on my target.
5. Do **not** enable proposed HSM rules from a single provisional fight.
6. Re-run with `--quick` while iterating; use default `full` for the FINDINGS write-up.

## Dungeon / battleground capture checklist (next run)

Run v2.2.4 with FD_Logs ON, `/combatlog` running from before FD_Logs ON until after OFF, and the file log copied together
with the SV. Each line says what it fills.
1. **Target / focus / mouseover / soft target.** Set a focus on a second mob and mouse over a third during a pull: fills the
   token matrix for focus, mouseover and soft-enemy in combat, and the Ledger token→GUID cache.
2. **A party member with a target.** In a group, have one member target something else: `party1target`, and group-meter
   "others" (the meter tracks group members, so the reconciliation changes).
3. **Raid member targeting** (any raid group, 6+ players): `raidNtarget` families, scanner cost per slice with 40 tokens
   (the budget must hold in game, not only in the bench).
4. **Arena or battleground:** `arenaN` tokens and PvP-restricted APIs (`UnitTokenPvPRestrictedForAddOns`). Look for
   restriction flips and the drift changelog's "build-change" / category entries.
5. **A boss encounter:** `bossN` tokens and ENCOUNTER_START containers. Check whether the meter's session types change
   inside an encounter.
6. **Interrupt known answer:** at least 3 Earth Shock interrupts on casting mobs, plus 1 deliberately late (cast already
   finished). That decides the damage-meter type 5 signal and fills `verify:interrupt-attribution`.
11. **Higher-order identity:** after ≥3 interrupts, confirm the identity-join chain holds on a second capture (holdout
    held) before reviewing the proposed InterruptAttribution rule.
12. **Higher-order elimination:** in a party, have someone else hit your target while you do not cast: confirm
    UNIT_COMBAT wounds with no my-cast / no DM tick score as other on holdout.
7. **isActive / isOnGCD flips:** cast a totem, then Lightning Shield, then a shock back to back, and cast once while a shock
   is cooling. That checks the 1.0 s / 1.5 s GCD known answers live and the shared shock cooldown.
8. **Tooltip second sample:** stay in combat at least 20 s after the last shock (all shocks ready) so the in-combat knowledge
   pass samples them ready. That decides the extra-line hypothesis.
9. **Ring verify:** after the run, `fdump.py analyze ... --history run5=...` must show the verify ring as source **live**
   (not replay), 0 refuted, and no known-answer mismatch lead.
10. Keep the file log running until after FD_Logs OFF (run 5 lost one heal at 00:03:50, after the log stopped).

## v2.2.6 logging (addon; not yet re-captured in game)

Sealed replay tape + session_hdr land in ForeverDumpLogDB.replay on the next FD_Logs capture. Cast-sync anchors
(every Nth own SUCCEEDED in release; all in test) are designed for offline CLEU join via `fdump replay --file …`.
Decide/verdict IDs enable sealed HSM determinism checks. Default build is release; capture elevates then restores.

---

# ForeverDump v2.2.6 findings (damage-meter self-reconcile + world-state capture)

Times ET. Addon never uses CLEU live. Ground truth for offline joins is `WoWCombatLog.txt` on the box only.
**In-game re-capture with this build is still pending** — reconcile accuracy below is from synthetic HSM re-exec + the prior run-5 meter↔log agreement; treat live numbers as the design target until the next FD_Logs session.

## Self-reconciliation loop (live ↔ meter ↔ CLEU)

### In combat (HSM live estimates)
- Per fight, `liveEst` tracks **my** damage / healing / interrupts / dispels / damage taken from UNIT_COMBAT + own casts + DAMAGE_METER_* timing (incl. type-6 dispel join).
- Per-unit `fight.world[unitKey|IdKey]`: taken, dmg (from me), interrupts, dm tick joins, crude DTPS from inter-hit gaps on that token.
- Tokens covered live for UNIT_COMBAT: player / target / focus / pet; **capture mode** registers all UNIT_COMBAT tokens (party/raid/nameplate/boss/…) filtered in-handler.

### After combat (clear meter read)
- `DamageMeter.ReadClear` (deep in capture) reads every `Enum.DamageMeterType` with all sources IdKey'd (no raw names/GUIDs).
- `HybridState:ReconcileDM` compares liveEst vs meter for damage / healing / interrupts / dispels / taken → verdicts **match / off by Δ / unexplained** into the verify ring + replay tape (`verdict` KEEP) + `f.reconcile` for HSM UI.
- Per-unit: meter `sources[Type][].id` joined to `fight.world[idKey]`; player forced from fight totals.

### Offline (three-way)
- Existing coverage fight table: log mine/others/taken/heal/interrupts vs DM.
- Deep capture adds IdKey'd source rows; coverage reports source-row / distinct-IdKey counts.
- Discrepancies (live≠meter or meter≠log) are regression leads for the next correlate pass (per-unit when sources present).

### In-game reconcile accuracy (FINDINGS target)

| Metric | Synthetic HSM (this build) | Run-5 post-combat meter↔log (prior build) | Notes |
|---|---|---|---|
| Damage (mine) | match within 2% / ±5 | matched log after combat | Over-attribution → contradiction (`dm-damage` C) |
| Healing (mine) | match / unexplained if no HEAL attribution | matched effective heals on me | Overheal does not move meter |
| Interrupts | exact (tol 0) | Earth Shock interrupt chain confirmed | cast+dm type 5 = high |
| Dispels | cast+dm type 6 when knowledge.dispel | not scored in run 5 | live truth weak without CLEU |
| Damage taken | match within 2% | matched | DM type 7 ↔ UNIT_COMBAT wound (shadow finding) |
| Per-unit (IdKey) | player match in harness; NPC via `npc:<id>` | deep sources not yet captured in game | Needs FD_Logs capture session |

**Report line for packaging:** *In-game reconcile accuracy: pending re-capture; synthetic self-reconcile match/off paths green; run-5 meter↔log damage/heal/interrupt/taken agreement stands as the floor.*

## World-state fields: tracked vs gaps

HSM is a **world** state machine. Capture mode now logs broad raw samples (`WorldCapture`, tape kind `ws`, PRI 5 droppable). HSM *inference* for non-meter world fields is deferred to the next version except where already live.

| Field | Already in HSM / Identity / Tokens | Readable / secret (1.60.1) | Capture logging (v2.2.6) | Planned workaround (next version+) |
|---|---|---|---|---|
| **Cast / channel** (spell, start/end, interruptible) | Yes: `casts[unitKey]`, enemy cast model (`ecast`/`castModel`), castBarID | Spell name/ID often **S** in combat; castBarID / notInterruptible / delay often **C** (NeverSecret) | `ws` codes for casting/channeling/notInt + clear spellId/castBar when C | Keep predicting from clear bar id + duration model; ledger last clear cast |
| **Auras** (buffs/debuffs) | Yes: `units[].auras`, ledger aura cache, GetAuraSlots counts | Instance lists / spellIds often **S** in combat; counts sometimes C OOC | `ws` buffN/debuffN slot counts; existing UNIT_AURA path | Collect-while-clear ledger; single-applier / cast-correlation (already) |
| **Health / health %** | Player running estimate (`hp`); UnitHealthMax in ledger | UnitHealth **S** in/out of combat for player; max often **C** | `ws` health/healthMax codes + clear max; UNIT_HEALTH/MAX in capture for all tokens | Anchor quiet-full OOC; UNIT_COMBAT ±amount; % from cur/max estimate |
| **Power** | Not inferred in HSM | Often **S** in combat | `ws` power/powerMax codes | Same as health: max clear + event deltas when available |
| **DTPS / healing received** | Live: player taken + per-token taken/dmg in `fight.world`; meter post-combat | UNIT_COMBAT amount **C**; meter in-combat container **S**, post-combat **C** | Meter deep sources; DM update timing joins | Offline CLEU join per IdKey; live DTPS from UC gaps (started) |
| **Distance / range bands** | Tokens matrix has no range yet | CheckInteractDistance often **C**; UnitInRange returns may be **S** | `ws` range10/range28/inRange codes | Band logic only on clear bools; never store yards from secret |
| **Threat** | Not in HSM inference | UnitThreatSituation / Detailed restricted when threat secret | `ws` threat + scaled % when C | Cache last clear status; UI only when C |
| **Target-of** (who → whom) | Identity chains (targettarget, focustarget, partyNtarget); map deltas on tape | GUID often **S** in combat; UnitIsUnit sometimes **C** | `ws` tgt IdKey when GUID clear; `me` if their target is player | Alias/fingerprint via Identity ledger (already); IdKey join |
| **Meter per-source / per-target** | ReconcileDM + DamageMeter deep read | Post-combat sources **C** (amounts); names ConditionalSecret → IdKey only | Full deep read in capture; light me/others in release | Offline per-unit CLEU↔meter↔liveEst |
| **Group/raid/nameplate coverage** | Tokens scanner matrix; Identity | Mixed | WorldCapture round-robins BuildList (all families) under budget | Inference next version |

### Perf / caps
- Release: WorldCapture **no-ops**; DamageMeter light; UNIT_COMBAT limited to player/target/focus/pet → **&lt;1%** goal unchanged.
- Capture: WorldCapture ≤0.10 ms/slice + tokenscan ≤0.12 ms; tape `ws` drops before decide/verdict/anchor; session still aimed at **~30 MB** / 25 min 40-man BG.

## What to do next in game
1. FD_Logs ON → combat with party/raid + nameplates + meter → OFF.
2. Pull `ForeverDumpLogDB.replay` + `damageMeter.fights` (deep) + verify ring; run `fdump coverage` / `correlate`.
3. Fill the reconcile accuracy table from real `f.reconcile.summary` + log joins.

## SV growth / serialize proxy (v2.2.6)

`ReplayLog.SerializeProxy` runs at capture end: row counts (keepers / ws / dm) + estimated bytes + MB/min.
Design targets (25 min 40-man BG, capture/test):

| Band | MB/min (est.) | 25 min total | Notes |
|---|---|---|---|
| Release solo/5/40 | 0.15 / 0.35 / 0.90 | small | no WorldCapture, light DM |
| Capture test (pre-ws) | 0.22 / 0.50 / 1.18 | ~29 MB @ 40 | tapeCap binds before byteBudget |
| Capture + WorldCapture ws | +~0.05–0.15 | still ≤~30 MB | delta+heartbeat; ws drops first under budget |

Logout/load: rings grow lazily; priority keep preserves decide/verdict/anchor/shadow for the session.

## Run-5 smoke: meter three-way join (v2.2.6 offline)

`fdump` `damagemeter_join` on run 5 (pre-deep-capture SV; no IdKey sources yet):

| Fights | match cells | off | unexplained | per-unit rows |
|---|---|---|---|---|
| 3 | 9 | 1 (healing fight 3) | 5 (mostly interrupts/dispels without meter) | 0 (no deep sources) |

Damage/taken match fight-over-fight; healing off once; interrupts/dispels unexplained when meter silent. Deep per-unit join awaits a capture with `DamageMeter` deepRead.
