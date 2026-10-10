# Combat-event coverage: combat log (truth) vs what the addon read live

Truth = the WoWCombatLog file, read offline only. Live = event payloads/timing and API values the capture saw (no CLEU, no side channels). Columns: **log** events in the capture span; **tok** the event touched a unit token the addon follows (player/target); **seen** a live event matched it (time window + amount); **amt** the amount/value was readable; **spell** the spellID was readable live.

**Target timeline: log-inferred.** This capture has no live target signals (the HSM did not run), so the target at each moment is rebuilt from my own offensive log events. **seen** then means the live event stream carried a matching event on the target token, not that the engine processed it.

**Own casts: raw events.** No HSM cast signals; the replay's own casts come from the raw UNIT_SPELLCAST_* records (target chosen like Inference.lua).

## Matrix (category x source x context)

| category | source | ctx | log | tok | seen | amt | spell |
|---|---|---|---|---|---|---|---|
| damage | me | combat | 17 | 17 | 16 | 16 | 4 |
| damage | another player | ooc | 16 | 0 | 0 | 0 | 0 |
| damage | another player | combat | 142 | 0 | 0 | 0 | 0 |
| damage | hostile NPC | ooc | 15 | 0 | 0 | 0 | 0 |
| damage | hostile NPC | combat | 54 | 10 | 10 | 10 | 0 |
| damage | other | ooc | 7 | 0 | 0 | 0 | 0 |
| damage | other | combat | 44 | 0 | 0 | 0 | 0 |
| miss | me | combat | 1 | 1 | 1 | 1 | 0 |
| miss | another player | ooc | 2 | 0 | 0 | 0 | 0 |
| miss | another player | combat | 14 | 0 | 0 | 0 | 0 |
| miss | hostile NPC | combat | 8 | 1 | 1 | 1 | 0 |
| miss | other | combat | 4 | 0 | 0 | 0 | 0 |
| crit | me | combat | 3 | 3 | 3 | 3 | 2 |
| crit | another player | ooc | 3 | 0 | 0 | 0 | 0 |
| crit | another player | combat | 23 | 0 | 0 | 0 | 0 |
| crit | hostile NPC | ooc | 1 | 0 | 0 | 0 | 0 |
| crit | other | ooc | 1 | 0 | 0 | 0 | 0 |
| crit | other | combat | 3 | 0 | 0 | 0 | 0 |
| overkill | me | combat | 1 | 1 | 0 | 0 | 1 |
| overkill | another player | ooc | 1 | 0 | 0 | 0 | 0 |
| overkill | another player | combat | 4 | 0 | 0 | 0 | 0 |
| overkill | other | combat | 1 | 0 | 0 | 0 | 0 |
| heal | me | combat | 1 | 1 | 1 | 1 | 1 |
| heal | another player | ooc | 7 | 0 | 0 | 0 | 0 |
| heal | another player | combat | 25 | 0 | 0 | 0 | 0 |
| heal | hostile NPC | combat | 2 | 1 | 1 | 1 | 0 |
| energize | another player | ooc | 7 | 0 | 0 | 0 | 0 |
| energize | another player | combat | 46 | 0 | 0 | 0 | 0 |
| energize | hostile NPC | ooc | 3 | 0 | 0 | 0 | 0 |
| energize | hostile NPC | combat | 8 | 0 | 0 | 0 | 0 |
| aura+ | me | combat | 5 | 5 | 5 | 0 | 0 |
| aura+ | another player | ooc | 21 | 0 | 0 | 0 | 0 |
| aura+ | another player | combat | 115 | 0 | 0 | 0 | 0 |
| aura+ | hostile NPC | ooc | 1 | 0 | 0 | 0 | 0 |
| aura+ | hostile NPC | combat | 3 | 0 | 0 | 0 | 0 |
| aura+ | other | combat | 1 | 0 | 0 | 0 | 0 |
| aura- | me | ooc | 1 | 1 | 1 | 0 | 0 |
| aura- | me | combat | 2 | 2 | 2 | 0 | 0 |
| aura- | another player | ooc | 13 | 0 | 0 | 0 | 0 |
| aura- | another player | combat | 40 | 0 | 0 | 0 | 0 |
| aura- | hostile NPC | ooc | 1 | 0 | 0 | 0 | 0 |
| aura- | hostile NPC | combat | 3 | 0 | 0 | 0 | 0 |
| cast-start | me | combat | 1 | 1 | 1 | 0 | 1 |
| cast-start | another player | ooc | 4 | 0 | 0 | 0 | 0 |
| cast-start | another player | combat | 13 | 0 | 0 | 0 | 0 |
| cast-start | hostile NPC | ooc | 5 | 0 | 0 | 0 | 0 |
| cast-start | hostile NPC | combat | 14 | 2 | 2 | 0 | 0 |
| cast-success | me | combat | 5 | 5 | 5 | 0 | 5 |
| cast-success | another player | ooc | 27 | 0 | 0 | 0 | 0 |
| cast-success | another player | combat | 110 | 0 | 0 | 0 | 0 |
| cast-success | hostile NPC | ooc | 4 | 0 | 0 | 0 | 0 |
| cast-success | hostile NPC | combat | 13 | 1 | 1 | 0 | 0 |
| cast-success | other | ooc | 5 | 0 | 0 | 0 | 0 |
| cast-success | other | combat | 28 | 0 | 0 | 0 | 0 |
| interrupt | me | combat | 1 | 1 | 1 | 0 | 0 |
| summon | another player | ooc | 4 | 0 | 0 | 0 | 0 |
| summon | another player | combat | 2 | 0 | 0 | 0 | 0 |
| death | - | ooc | 1 | 0 | 0 | 0 | 0 |
| death | - | combat | 5 | 1 | 1 | 0 | 0 |

Full rows with target classes: coverage.json `matrix`.

## Live attribution (HSM replay of the recorded live events, scored against the log)

before = v2.2.3 library behaviour (no UNIT_COMBAT/DM/swing/interrupt attribution, secret-timing window 2.4 s); after = HybridState MINOR 3 (v2.2.4). accuracy = correct / events with a log match; coverage = attributed / matched; falseSelf = attributed to me but the log says someone else (counted as contradictions).

| category | n | before acc | before cov | before falseSelf | after acc | after cov | after falseSelf | after missedSelf |
|---|---|---|---|---|---|---|---|---|
| aura-on-target | 0 | None | None | 0 | None | None | 0 | 0 |
| damage-on-target | 16 | 0.0 | 0.0 | 0 | 100.0 | 100.0 | 0 | 0 |
| damage-taken | 11 | 0.0 | 0.0 | 0 | 100.0 | 100.0 | 0 | 0 |
| heal-on-me | 1 | 0.0 | 0.0 | 0 | 100.0 | 100.0 | 0 | 0 |
| heal-on-target | 1 | 0.0 | 0.0 | 0 | 0.0 | 0.0 | 0 | 0 |
| interrupt | 1 | 0.0 | 0.0 | 0 | 100.0 | 100.0 | 0 | 0 |
| miss-on-target | 1 | 0.0 | 0.0 | 0 | 100.0 | 100.0 | 0 | 0 |

Reference: a meter that counts everything on my target as mine: 100.0% correct, 0 false-self hit(s), 0 damage wrongly credited to me.


## Timing models (trained on this log)

| channel | n | min | median | max |
|---|---|---|---|---|
| UNIT_COMBAT - file time, damage | 9 | -0.008 | 0.000 | 0.001 |
| UNIT_COMBAT - file time, damage/melee | 17 | 0.000 | 0.519 | 0.531 |
| UNIT_COMBAT - file time, heal | 2 | 0.001 | 0.001 | 0.001 |
| UNIT_COMBAT - file time, miss | 2 | 0.459 | 0.519 | 0.519 |

## Fights: log vs C_DamageMeter (post-combat, clear)

| fight | dur (log/DM) | my damage log/DM | others on my targets log / DM others | taken log/DM | my effective heal on me log/DM | my interrupts log/DM |
|---|---|---|---|---|---|---|
| 1 | 29.3/29 | 1327/1327 | 0 / 0 | 290/290 | 243/243 | 1/1 |

HSM live reconciliation at PLAYER_REGEN_ENABLED (after):

- DM mine 1327 vs live mine 1318; live other 0; others-on-target (live total - DM mine) 0; interrupts DM 1 / live 1

## C_DamageMeter

- DAMAGE_METER_COMBAT_SESSION_UPDATED by type: {'0': 30, '1': 30, '10': 30, '7': 20, '2': 4, '3': 4, '5': 2} (by context {'combat': 116, 'ooc': 4}); events with a secret argument: 0
- post-combat records: 3 (DamageMeter.lua)
- deep per-unit sources (IdKey'd): 7 source-rows / 1 distinct IdKeys across 1 deep fight(s)

CombatProbe cells (v2.2 probe set):

| context | API | result codes | fields | predicate |
|---|---|---|---|---|
| combat | C_DamageMeter.GetCombatSessionFromType | [{'T': 10}] | {'durationSeconds': {'S': 10}, 'combatSources': {'K': 10}, 'maxAmount': {'S': 10}, 'totalAmount': {'S': 10}} | {'t': 10} |
| combat | C_DamageMeter.IsDamageMeterAvailable | [{'C': 10}, {'C': 10}] | None | None |
| ooc | C_DamageMeter.GetCombatSessionFromType | [{'K': 7}] | {'durationSeconds': {'C': 7}, 'combatSources': {'K': 7}, 'maxAmount': {'C': 7}, 'totalAmount': {'C': 7}} | {'f': 7} |
| ooc | C_DamageMeter.IsDamageMeterAvailable | [{'C': 7}, {'C': 7}] | None | None |

| context | field | codes |
|---|---|---|
| after-combat | AvailableCombatSession.durationSeconds | {'C': 3} |
| after-combat | AvailableCombatSession.name | {'C': 3} |
| after-combat | AvailableCombatSession.sessionID | {'C': 3} |
| after-combat | CombatSession.combatSources | {'K': 3} |
| after-combat | CombatSession.durationSeconds | {'C': 3} |
| after-combat | CombatSession.maxAmount | {'C': 3} |
| after-combat | CombatSession.totalAmount | {'C': 3} |
| after-combat | CombatSessionSource.combatSpells | {'K': 3} |
| after-combat | CombatSessionSource.totalAmount | {'C': 3} |
| after-combat | CombatSource.amountPerSecond | {'C': 3} |
| after-combat | CombatSource.classFilename | {'C': 3} |
| after-combat | CombatSource.classification | {'C': 3} |
| after-combat | CombatSource.combatSpells | {'N': 3} |
| after-combat | CombatSource.deathRecapID | {'C': 3} |
| after-combat | CombatSource.deathTimeSeconds | {'C': 3} |
| after-combat | CombatSource.isLocalPlayer | {'C': 3} |
| after-combat | CombatSource.name | {'C': 3} |
| after-combat | CombatSource.sourceCreatureID | {'N': 3} |
| after-combat | CombatSource.sourceDisplayType | {'C': 3} |
| after-combat | CombatSource.sourceGUID | {'C': 3} |
| after-combat | CombatSource.specIconID | {'C': 3} |
| after-combat | CombatSource.totalAmount | {'C': 3} |
| after-combat | CombatSpell.amountPerSecond | {'C': 3} |
| after-combat | CombatSpell.combatSpellDetails | {'K': 3} |
| after-combat | CombatSpell.creatureName | {'C': 3} |
| after-combat | CombatSpell.isAvoidable | {'N': 3} |
| after-combat | CombatSpell.isDeadly | {'N': 3} |
| after-combat | CombatSpell.overkillAmount | {'C': 3} |
| after-combat | CombatSpell.spellID | {'C': 3} |
| after-combat | CombatSpell.totalAmount | {'C': 3} |
| after-combat | GetAvailableCombatSessions | {'K': 3} |
| after-combat | GetCombatSessionFromType | {'K': 3} |
| after-combat | GetCombatSessionSourceFromType | {'K': 3} |
| after-combat | GetSessionDurationSeconds | {'C': 3} |
| after-combat | IsDamageMeterAvailable | {'C': 3} |
| after-combat | nAvailableSessions | {'C': 3} |
| combat | AvailableCombatSession.durationSeconds | {'C': 1} |
| combat | AvailableCombatSession.name | {'C': 1} |
| combat | AvailableCombatSession.sessionID | {'C': 1} |
| combat | CombatSession.combatSources | {'K': 1} |
| combat | CombatSession.durationSeconds | {'S': 1} |
| combat | CombatSession.maxAmount | {'S': 1} |
| combat | CombatSession.totalAmount | {'S': 1} |
| combat | CombatSessionSource.combatSpells | {'K': 1} |
| combat | CombatSessionSource.totalAmount | {'S': 1} |
| combat | CombatSource.amountPerSecond | {'S': 1} |
| combat | CombatSource.classFilename | {'C': 1} |
| combat | CombatSource.classification | {'C': 1} |
| combat | CombatSource.combatSpells | {'N': 1} |
| combat | CombatSource.deathRecapID | {'C': 1} |
| combat | CombatSource.deathTimeSeconds | {'S': 1} |
| combat | CombatSource.isLocalPlayer | {'C': 1} |
| combat | CombatSource.name | {'S': 1} |
| combat | CombatSource.sourceCreatureID | {'N': 1} |
| combat | CombatSource.sourceDisplayType | {'S': 1} |
| combat | CombatSource.sourceGUID | {'S': 1} |
| combat | CombatSource.specIconID | {'C': 1} |
| combat | CombatSource.totalAmount | {'S': 1} |
| combat | CombatSpell.amountPerSecond | {'S': 1} |
| combat | CombatSpell.creatureName | {'S': 1} |
| combat | CombatSpell.overkillAmount | {'S': 1} |
| combat | CombatSpell.spellID | {'S': 1} |
| combat | CombatSpell.totalAmount | {'S': 1} |
| combat | GetAvailableCombatSessions | {'K': 1} |
| combat | GetCombatSessionFromType | {'T': 1} |
| combat | GetCombatSessionSourceFromType | {'T': 1} |
| combat | GetSessionDurationSeconds | {'C': 1} |
| combat | IsDamageMeterAvailable | {'C': 1} |
| combat | nAvailableSessions | {'C': 1} |
| combat-struct | struct.DamageDone.nSources | {'C': 13} |
| combat-struct | struct.DamageDone.nSpells | {'N': 13} |
| combat-struct | struct.DamageDone.session | {'T': 13} |
| combat-struct | struct.DamageTaken.nSources | {'C': 10} |
| combat-struct | struct.DamageTaken.nSpells | {'N': 10} |
| combat-struct | struct.DamageTaken.session | {'T': 10} |
| combat-struct | struct.Dps.nSources | {'C': 13} |
| combat-struct | struct.Dps.nSpells | {'N': 13} |
| combat-struct | struct.Dps.session | {'T': 13} |
| combat-struct | struct.EnemyDamageTaken.nSources | {'C': 13} |
| combat-struct | struct.EnemyDamageTaken.nSpells | {'N': 13} |
| combat-struct | struct.EnemyDamageTaken.session | {'T': 13} |
| combat-struct | struct.HealingDone.nSources | {'C': 2} |
| combat-struct | struct.HealingDone.nSpells | {'N': 2} |
| combat-struct | struct.HealingDone.session | {'K': 1, 'T': 1} |
| combat-struct | struct.Hps.nSources | {'C': 2} |
| combat-struct | struct.Hps.nSpells | {'N': 2} |
| combat-struct | struct.Hps.session | {'K': 1, 'T': 1} |
| combat-struct | struct.Interrupts.nSources | {'C': 1} |
| combat-struct | struct.Interrupts.nSpells | {'N': 1} |
| combat-struct | struct.Interrupts.session | {'T': 1} |
| ooc | AvailableCombatSession.durationSeconds | {'C': 1} |
| ooc | AvailableCombatSession.name | {'C': 1} |
| ooc | AvailableCombatSession.sessionID | {'C': 1} |
| ooc | CombatSession.combatSources | {'K': 1} |
| ooc | CombatSession.durationSeconds | {'C': 1} |
| ooc | CombatSession.maxAmount | {'C': 1} |
| ooc | CombatSession.totalAmount | {'C': 1} |
| ooc | CombatSessionSource.combatSpells | {'K': 1} |
| ooc | CombatSessionSource.totalAmount | {'C': 1} |
| ooc | CombatSource.amountPerSecond | {'C': 1} |
| ooc | CombatSource.classFilename | {'C': 1} |
| ooc | CombatSource.classification | {'C': 1} |
| ooc | CombatSource.combatSpells | {'N': 1} |
| ooc | CombatSource.deathRecapID | {'C': 1} |
| ooc | CombatSource.deathTimeSeconds | {'C': 1} |
| ooc | CombatSource.isLocalPlayer | {'C': 1} |
| ooc | CombatSource.name | {'C': 1} |
| ooc | CombatSource.sourceCreatureID | {'N': 1} |
| ooc | CombatSource.sourceDisplayType | {'C': 1} |
| ooc | CombatSource.sourceGUID | {'C': 1} |
| ooc | CombatSource.specIconID | {'C': 1} |
| ooc | CombatSource.totalAmount | {'C': 1} |
| ooc | CombatSpell.amountPerSecond | {'C': 1} |
| ooc | CombatSpell.combatSpellDetails | {'K': 1} |
| ooc | CombatSpell.creatureName | {'C': 1} |
| ooc | CombatSpell.isAvoidable | {'N': 1} |
| ooc | CombatSpell.isDeadly | {'N': 1} |
| ooc | CombatSpell.overkillAmount | {'C': 1} |
| ooc | CombatSpell.spellID | {'C': 1} |
| ooc | CombatSpell.totalAmount | {'C': 1} |
| ooc | GetAvailableCombatSessions | {'K': 1} |
| ooc | GetCombatSessionFromType | {'K': 1} |
| ooc | GetCombatSessionSourceFromType | {'K': 1} |
| ooc | GetSessionDurationSeconds | {'C': 1} |
| ooc | IsDamageMeterAvailable | {'C': 1} |
| ooc | nAvailableSessions | {'C': 1} |

## Cooldown / GCD tracker (HybridState MINOR 5) vs the log

State the tracker held at each of my successful casts (log SPELL_CAST_SUCCESS). A cast while the tracker said 'cooling' (or 'gcd') with more than 0.15 s left is a contradiction. 'Not yet recovered' fails in the log should find the tracker cooling.

- casts checked: 5; consistent 5; cast while cooling 0; cast inside GCD 0
- log 'Not yet recovered' fails: tracker cooling/gcd 0, tracker idle (missed) 0
- learned readies: 0; GCD windows observed: 0; spells tracked: 8

| spell | category | shared-recovery category | fail confirms | learned n | gcd n |
|---|---|---|---|---|---|
| 6391 | 45 | 133 | 0 | 0 | 0 |
| 8008 |  | 133 | 0 | 0 | 0 |
| 8046 | 19 | 133 | 0 | 0 | 0 |
| 8052 | 19 | 133 | 0 | 0 | 0 |
| 8056 | 19 | 133 | 0 | 0 | 0 |
| 8177 | 230 | 133 | 0 | 0 | 0 |
| 17364 |  | 133 | 0 | 0 | 0 |
| 408342 | 35 | 133 | 0 | 0 | 0 |

## Cooldown model vs log cast failures

- fail verdicts: {}

| spell | cast | predicted ready (+s) | recast (+s) | recast - ready | verdict |
|---|---|---|---|---|---|
| 8052 | 18:30:47 | 6.0 | 18.8 | 12.804 | consistent |

## Enemy cast bars: live duration model vs log

- log NPC casts: 21; predicted: 0; mean abs error None s; within 150 ms: 0
- model npc:4096: n 1, median 3.062 s (min 3.062, max 3.062)

## Overheal estimate vs log

- heals 1, estimated 1, exact 1, overheal yes/no correct 1, mean abs error 0.0

## Ledger (cached clear facts) vs log

- aura claims (live / cached-fresh / cached-stale) vs log: {}; by confidence: {}
- 'maybe-removed' entries are doubts, never claims: removalConfirmed = the log shows the aura really was gone, stillPresent = the doubt was unnecessary
- token->GUID resolutions: {'n': 16, 'correct': 16}
- ledger stats: {'evicted': 0, 'invalidated': 0, 'stale': 0, 'puts': 7, 'live': 0, 'fresh': 0, 'miss': 0}

## Live verdicts (verify ring, replayed)

| kind | V | C | U | X |
|---|---|---|---|---|
| cast-end | 0 | 0 | 1 | 0 |
| cooldown | 1 | 0 | 0 | 0 |
| damage-range | 3 | 0 | 0 | 0 |
| dm-damage | 1 | 0 | 0 | 0 |
| dm-dispels | 0 | 0 | 1 | 0 |
| dm-healing | 1 | 0 | 0 | 0 |
| dm-interrupts | 1 | 0 | 0 | 0 |
| dm-taken | 0 | 0 | 1 | 0 |
| interrupt-attribution | 1 | 0 | 0 | 0 |
