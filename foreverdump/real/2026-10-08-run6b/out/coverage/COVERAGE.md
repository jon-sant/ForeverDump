# Combat-event coverage: combat log (truth) vs what the addon read live

Truth = the WoWCombatLog file, read offline only. Live = event payloads/timing and API values the capture saw (no CLEU, no side channels). Columns: **log** events in the capture span; **tok** the event touched a unit token the addon follows (player/target); **seen** a live event matched it (time window + amount); **amt** the amount/value was readable; **spell** the spellID was readable live.

**Target timeline: log-inferred.** This capture has no live target signals (the HSM did not run), so the target at each moment is rebuilt from my own offensive log events. **seen** then means the live event stream carried a matching event on the target token, not that the engine processed it.

**Own casts: raw events.** No HSM cast signals; the replay's own casts come from the raw UNIT_SPELLCAST_* records (target chosen like Inference.lua).

## Matrix (category x source x context)

| category | source | ctx | log | tok | seen | amt | spell |
|---|---|---|---|---|---|---|---|
| damage | me | combat | 11 | 11 | 11 | 11 | 3 |
| damage | another player | ooc | 277 | 0 | 0 | 0 | 0 |
| damage | another player | combat | 147 | 4 | 4 | 4 | 0 |
| damage | hostile NPC | ooc | 122 | 0 | 0 | 0 | 0 |
| damage | hostile NPC | combat | 47 | 14 | 14 | 14 | 0 |
| damage | other | ooc | 76 | 0 | 0 | 0 | 0 |
| damage | other | combat | 39 | 4 | 3 | 3 | 0 |
| damage | - | ooc | 1 | 0 | 0 | 0 | 0 |
| miss | another player | ooc | 27 | 0 | 0 | 0 | 0 |
| miss | another player | combat | 7 | 0 | 0 | 0 | 0 |
| miss | hostile NPC | ooc | 19 | 0 | 0 | 0 | 0 |
| miss | hostile NPC | combat | 9 | 3 | 3 | 3 | 0 |
| miss | other | ooc | 8 | 0 | 0 | 0 | 0 |
| miss | other | combat | 1 | 1 | 1 | 1 | 0 |
| crit | another player | ooc | 35 | 0 | 0 | 0 | 0 |
| crit | another player | combat | 15 | 0 | 0 | 0 | 0 |
| crit | hostile NPC | ooc | 1 | 0 | 0 | 0 | 0 |
| crit | other | ooc | 4 | 0 | 0 | 0 | 0 |
| crit | other | combat | 2 | 0 | 0 | 0 | 0 |
| overkill | another player | ooc | 12 | 0 | 0 | 0 | 0 |
| overkill | another player | combat | 12 | 0 | 0 | 0 | 0 |
| overkill | other | ooc | 4 | 0 | 0 | 0 | 0 |
| absorb | hostile NPC | ooc | 15 | 0 | 0 | 0 | 0 |
| absorb | hostile NPC | combat | 5 | 0 | 0 | 0 | 0 |
| heal | me | combat | 2 | 2 | 2 | 2 | 2 |
| heal | another player | ooc | 116 | 0 | 0 | 0 | 0 |
| heal | another player | combat | 63 | 0 | 0 | 0 | 0 |
| heal | hostile NPC | ooc | 3 | 0 | 0 | 0 | 0 |
| energize | another player | ooc | 131 | 0 | 0 | 0 | 0 |
| energize | another player | combat | 75 | 0 | 0 | 0 | 0 |
| energize | hostile NPC | ooc | 27 | 0 | 0 | 0 | 0 |
| energize | hostile NPC | combat | 18 | 0 | 0 | 0 | 0 |
| aura+ | me | ooc | 1 | 1 | 1 | 1 | 1 |
| aura+ | me | combat | 3 | 3 | 3 | 0 | 0 |
| aura+ | another player | ooc | 189 | 0 | 0 | 0 | 0 |
| aura+ | another player | combat | 92 | 0 | 0 | 0 | 0 |
| aura+ | hostile NPC | ooc | 10 | 0 | 0 | 0 | 0 |
| aura+ | hostile NPC | combat | 4 | 2 | 2 | 0 | 0 |
| aura+ | other | ooc | 2 | 0 | 0 | 0 | 0 |
| aura+ | other | combat | 2 | 0 | 0 | 0 | 0 |
| aura- | me | ooc | 1 | 1 | 1 | 1 | 1 |
| aura- | me | combat | 5 | 5 | 5 | 0 | 0 |
| aura- | another player | ooc | 139 | 0 | 0 | 0 | 0 |
| aura- | another player | combat | 86 | 0 | 0 | 0 | 0 |
| aura- | hostile NPC | ooc | 12 | 0 | 0 | 0 | 0 |
| aura- | hostile NPC | combat | 3 | 2 | 2 | 0 | 0 |
| cast-start | me | combat | 3 | 3 | 3 | 0 | 3 |
| cast-start | another player | ooc | 32 | 0 | 0 | 0 | 0 |
| cast-start | another player | combat | 11 | 0 | 0 | 0 | 0 |
| cast-start | hostile NPC | ooc | 30 | 0 | 0 | 0 | 0 |
| cast-start | hostile NPC | combat | 27 | 17 | 0 | 0 | 0 |
| cast-success | me | ooc | 1 | 1 | 1 | 0 | 1 |
| cast-success | me | combat | 9 | 9 | 9 | 0 | 9 |
| cast-success | another player | ooc | 205 | 0 | 0 | 0 | 0 |
| cast-success | another player | combat | 96 | 4 | 0 | 0 | 0 |
| cast-success | hostile NPC | ooc | 31 | 0 | 0 | 0 | 0 |
| cast-success | hostile NPC | combat | 28 | 19 | 0 | 0 | 0 |
| cast-success | other | ooc | 31 | 0 | 0 | 0 | 0 |
| cast-success | other | combat | 9 | 2 | 0 | 0 | 0 |
| cast-fail | me | ooc | 1 | 1 | 1 | 0 | 1 |
| cast-fail | me | combat | 3 | 3 | 2 | 0 | 2 |
| summon | me | combat | 2 | 2 | 2 | 0 | 2 |
| summon | another player | ooc | 3 | 0 | 0 | 0 | 0 |
| summon | another player | combat | 4 | 0 | 0 | 0 | 0 |
| death | - | ooc | 9 | 0 | 0 | 0 | 0 |
| death | - | combat | 10 | 1 | 1 | 0 | 0 |

Full rows with target classes: coverage.json `matrix`.

## Live attribution (HSM replay of the recorded live events, scored against the log)

before = v2.2.3 library behaviour (no UNIT_COMBAT/DM/swing/interrupt attribution, secret-timing window 2.4 s); after = HybridState MINOR 3 (v2.2.4). accuracy = correct / events with a log match; coverage = attributed / matched; falseSelf = attributed to me but the log says someone else (counted as contradictions).

| category | n | before acc | before cov | before falseSelf | after acc | after cov | after falseSelf | after missedSelf |
|---|---|---|---|---|---|---|---|---|
| aura-on-target | 0 | None | None | 0 | None | None | 0 | 0 |
| damage-on-target | 18 | 0.0 | 0.0 | 0 | 100.0 | 100.0 | 0 | 0 |
| damage-taken | 17 | 0.0 | 0.0 | 0 | 100.0 | 100.0 | 0 | 0 |
| heal-on-me | 2 | 0.0 | 0.0 | 0 | 100.0 | 100.0 | 0 | 0 |
| miss-on-target | 1 | 0.0 | 0.0 | 0 | 100.0 | 100.0 | 0 | 0 |

Reference: a meter that counts everything on my target as mine: 61.1% correct, 7 false-self hit(s), 534 damage wrongly credited to me.


## Timing models (trained on this log)

| channel | n | min | median | max |
|---|---|---|---|---|
| UNIT_COMBAT - file time, damage | 12 | -0.005 | -0.002 | 0.000 |
| UNIT_COMBAT - file time, damage/melee | 20 | -0.002 | 0.015 | 0.458 |
| UNIT_COMBAT - file time, heal | 2 | -0.001 | -0.001 | -0.001 |
| UNIT_COMBAT - file time, miss | 4 | -0.004 | -0.004 | -0.001 |

## Fights: log vs C_DamageMeter (post-combat, clear)

| fight | dur (log/DM) | my damage log/DM | others on my targets log / DM others | taken log/DM | my effective heal on me log/DM | my interrupts log/DM |
|---|---|---|---|---|---|---|
| 1 | 48.1/48 | 439/439 | 585 / 0 | 494/494 | 400/400 | 0/0 |

HSM live reconciliation at PLAYER_REGEN_ENABLED (after):

- DM mine 439 vs live mine 439; live other 534; others-on-target (live total - DM mine) 534; interrupts DM 0 / live 0

## Another player on my target (newest such fight)

Others: other player A. Their casts in the log: 6; their auras on the target: 0. Damage by others: log 407, live 'other' 534; live 'mine' 439; false self-attributions: 0.

| t | live UNIT_COMBAT | amount | school | crit | DM event | HSM | rule | log truth |
|---|---|---|---|---|---|---|---|---|
| 1791499213.823 | WOUND | 41 | 4 | False | True | mine | cast-frame | me |
| 1791499216.793 | WOUND | 9 | 4 | False | True | mine | dm-frame | me |
| 1791499219.814 | WOUND | 10 | 4 | False | True | mine | dm-frame | me |
| 1791499222.908 | WOUND | 9 | 4 | False | True | mine | dm-frame | me |
| 1791499225.783 | WOUND | 10 | 4 | False | True | mine | dm-frame | me |
| 1791499239.298 | WOUND | 44 | 8 | False | True | mine | dm-frame | me |
| 1791499240.673 | WOUND | 92 | 8 | False | True | mine | cast-frame | me |
| 1791499244.152 | WOUND | 44 | 8 | False | True | mine | dm-frame | me |
| 1791499247.36 | WOUND | 92 | 8 | False | True | mine | cast-frame | me |
| 1791499249.049 | WOUND | 44 | 8 | False | True | mine | dm-frame | me |
| 1791499253.861 | WOUND | 44 | 8 | False | True | mine | dm-frame | me |
| 1791499257.32 | WOUND | 102 | 64 | False | False | other | elimination | player |
| 1791499257.549 | WOUND | 95 | 1 | False | False | other | elimination | player |
| 1791499258.778 | MISS | 0 | 1 | False | False | other | elimination | other |
| 1791499259.111 | WOUND | 56 | 1 | False | False | other | elimination | other |
| 1791499259.611 | WOUND | 17 | 1 | False | False | other | elimination | other |
| 1791499260.528 | WOUND | 95 | 1 | False | False | other | elimination | player |
| 1791499260.653 | WOUND | 115 | 1 | False | False | other | elimination | player |
| 1791499260.653 | WOUND | 54 | 1 | False | False | other | elimination | other |

Log timeline:

| t | who | event | spell | amount |
|---|---|---|---|---|
| 1791499213.825 | me | SPELL_CAST_SUCCESS | Flame Shock | None |
| 1791499213.826 | me | SPELL_DAMAGE | Flame Shock | 41 |
| 1791499213.827 | me | SPELL_AURA_APPLIED | Flame Shock | None |
| 1791499216.794 | me | SPELL_PERIODIC_DAMAGE | Flame Shock | 9 |
| 1791499219.815 | me | SPELL_PERIODIC_DAMAGE | Flame Shock | 10 |
| 1791499222.911 | me | SPELL_PERIODIC_DAMAGE | Flame Shock | 9 |
| 1791499225.788 | me | SPELL_PERIODIC_DAMAGE | Flame Shock | 10 |
| 1791499225.788 | me | SPELL_AURA_REMOVED | Flame Shock | None |
| 1791499226.966 | other player A | SPELL_CAST_START | Aimed Shot | None |
| 1791499239.3 | me | SPELL_DAMAGE | Lightning Shield | 44 |
| 1791499240.675 | me | SPELL_CAST_SUCCESS | Earth Shock | None |
| 1791499240.676 | me | SPELL_DAMAGE | Earth Shock | 92 |
| 1791499244.153 | me | SPELL_DAMAGE | Lightning Shield | 44 |
| 1791499247.364 | me | SPELL_CAST_SUCCESS | Earth Shock | None |
| 1791499247.364 | me | SPELL_DAMAGE | Earth Shock | 92 |
| 1791499249.051 | me | SPELL_DAMAGE | Lightning Shield | 44 |
| 1791499253.862 | me | SPELL_DAMAGE | Lightning Shield | 44 |
| 1791499256.758 | other player A | SPELL_CAST_SUCCESS | Arcane Shot | None |
| 1791499257.008 | other player A | SPELL_CAST_SUCCESS | Auto Shot | None |
| 1791499257.32 | other player A | SPELL_DAMAGE | Arcane Shot | 102 |
| 1791499257.55 | other player A | RANGE_DAMAGE |  | 95 |
| 1791499258.258 | other player A | SPELL_CAST_START | Aimed Shot | None |
| 1791499259.987 | other player A | SPELL_CAST_SUCCESS | Auto Shot | None |
| 1791499260.091 | other player A | SPELL_CAST_SUCCESS | Aimed Shot | None |
| 1791499260.53 | other player A | RANGE_DAMAGE |  | 95 |
| 1791499260.654 | other player A | SPELL_DAMAGE | Aimed Shot | 115 |

## C_DamageMeter

- DAMAGE_METER_COMBAT_SESSION_UPDATED by type: {'0': 22, '1': 22, '10': 22, '7': 28, '2': 4, '3': 4} (by context {'combat': 102}); events with a secret argument: 0
- post-combat records: 11 (DamageMeter.lua)
- deep per-unit sources (IdKey'd): 17 source-rows / 1 distinct IdKeys across 3 deep fight(s)

CombatProbe cells (v2.2 probe set):

| context | API | result codes | fields | predicate |
|---|---|---|---|---|
| combat | C_DamageMeter.GetCombatSessionFromType | [{'T': 17}] | {'durationSeconds': {'S': 17}, 'combatSources': {'K': 17}, 'maxAmount': {'S': 17}, 'totalAmount': {'S': 17}} | {'t': 17} |
| combat | C_DamageMeter.IsDamageMeterAvailable | [{'C': 15}, {'C': 15}] | None | None |
| ooc | C_DamageMeter.GetCombatSessionFromType | [{'K': 10}] | {'durationSeconds': {'C': 10}, 'combatSources': {'K': 10}, 'maxAmount': {'C': 10}, 'totalAmount': {'C': 10}} | {'f': 10} |
| ooc | C_DamageMeter.IsDamageMeterAvailable | [{'C': 10}, {'C': 10}] | None | None |

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
| combat-struct | struct.DamageDone.nSources | {'C': 11} |
| combat-struct | struct.DamageDone.nSpells | {'N': 11} |
| combat-struct | struct.DamageDone.session | {'T': 11} |
| combat-struct | struct.DamageTaken.nSources | {'C': 14} |
| combat-struct | struct.DamageTaken.nSpells | {'N': 14} |
| combat-struct | struct.DamageTaken.session | {'T': 14} |
| combat-struct | struct.Dps.nSources | {'C': 11} |
| combat-struct | struct.Dps.nSpells | {'N': 11} |
| combat-struct | struct.Dps.session | {'T': 11} |
| combat-struct | struct.EnemyDamageTaken.nSources | {'C': 11} |
| combat-struct | struct.EnemyDamageTaken.nSpells | {'N': 11} |
| combat-struct | struct.EnemyDamageTaken.session | {'T': 11} |
| combat-struct | struct.HealingDone.nSources | {'C': 2} |
| combat-struct | struct.HealingDone.nSpells | {'N': 2} |
| combat-struct | struct.HealingDone.session | {'T': 2} |
| combat-struct | struct.Hps.nSources | {'C': 2} |
| combat-struct | struct.Hps.nSpells | {'N': 2} |
| combat-struct | struct.Hps.session | {'T': 2} |
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

- casts checked: 10; consistent 10; cast while cooling 0; cast inside GCD 0
- log 'Not yet recovered' fails: tracker cooling/gcd 1, tracker idle (missed) 0
- learned readies: 0; GCD windows observed: 0; spells tracked: 10

| spell | category | shared-recovery category | fail confirms | learned n | gcd n |
|---|---|---|---|---|---|
| 905 |  | 133 | 0 | 0 | 0 |
| 6391 | 45 | 133 | 0 | 0 | 0 |
| 8008 |  | 133 | 0 | 0 | 0 |
| 8046 | 19 | 133 | 0 | 0 | 0 |
| 8052 | 19 | 133 | 0 | 0 | 0 |
| 8056 | 19 | 133 | 0 | 0 | 0 |
| 8155 |  | 133 | 0 | 0 | 0 |
| 8177 | 230 | 133 | 0 | 0 | 0 |
| 408342 | 35 | 133 | 0 | 0 | 0 |
| 1238640 |  | 133 | 0 | 0 | 0 |

## Cooldown model vs log cast failures

- fail verdicts: {'n/a': 2, 'contradicts': 1}

| spell | cast | predicted ready (+s) | recast (+s) | recast - ready | verdict |
|---|---|---|---|---|---|
| 8046 | 18:40:40 | 6.0 | 6.7 | 0.691 | consistent |

## Enemy cast bars: live duration model vs log

- log NPC casts: 81; predicted: 0; mean abs error None s; within 150 ms: 0

## Overheal estimate vs log

- heals 2, estimated 2, exact 2, overheal yes/no correct 2, mean abs error 0.0

## Ledger (cached clear facts) vs log

- aura claims (live / cached-fresh / cached-stale) vs log: {}; by confidence: {}
- 'maybe-removed' entries are doubts, never claims: removalConfirmed = the log shows the aura really was gone, stillPresent = the doubt was unnecessary
- token->GUID resolutions: {'n': 18, 'correct': 18}
- ledger stats: {'evicted': 0, 'invalidated': 0, 'stale': 0, 'puts': 24, 'live': 0, 'fresh': 0, 'miss': 0}

## Live verdicts (verify ring, replayed)

| kind | V | C | U | X |
|---|---|---|---|---|
| cooldown | 1 | 0 | 4 | 0 |
| damage-range | 3 | 0 | 0 | 0 |
| dm-damage | 1 | 0 | 0 | 0 |
| dm-dispels | 0 | 0 | 1 | 0 |
| dm-healing | 1 | 0 | 0 | 0 |
| dm-interrupts | 1 | 0 | 0 | 0 |
| dm-taken | 0 | 0 | 1 | 0 |
