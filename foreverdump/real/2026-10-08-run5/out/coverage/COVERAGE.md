# Combat-event coverage: combat log (truth) vs what the addon read live

Truth = the WoWCombatLog file, read offline only. Live = event payloads/timing and API values the capture saw (no CLEU, no side channels). Columns: **log** events in the capture span; **tok** the event touched a unit token the addon follows (player/target); **seen** a live event matched it (time window + amount); **amt** the amount/value was readable; **spell** the spellID was readable live.

## Matrix (category x source x context)

| category | source | ctx | log | tok | seen | amt | spell |
|---|---|---|---|---|---|---|---|
| damage | me | combat | 44 | 44 | 39 | 39 | 9 |
| damage | another player | ooc | 23 | 0 | 0 | 0 | 0 |
| damage | another player | combat | 7 | 2 | 2 | 2 | 0 |
| damage | hostile NPC | ooc | 7 | 0 | 0 | 0 | 0 |
| damage | hostile NPC | combat | 28 | 26 | 26 | 26 | 0 |
| miss | me | combat | 4 | 4 | 4 | 4 | 3 |
| miss | another player | ooc | 10 | 0 | 0 | 0 | 0 |
| miss | another player | combat | 1 | 0 | 0 | 0 | 0 |
| miss | hostile NPC | ooc | 2 | 0 | 0 | 0 | 0 |
| miss | hostile NPC | combat | 10 | 10 | 10 | 10 | 0 |
| crit | me | ooc | 1 | 1 | 0 | 0 | 0 |
| crit | me | combat | 2 | 2 | 2 | 2 | 2 |
| crit | my totems/pets | ooc | 3 | 1 | 0 | 0 | 0 |
| crit | my totems/pets | combat | 4 | 2 | 0 | 0 | 0 |
| crit | another player | ooc | 5 | 0 | 0 | 0 | 0 |
| crit | another player | combat | 2 | 0 | 0 | 0 | 0 |
| overkill | me | combat | 3 | 3 | 0 | 0 | 0 |
| overkill | another player | ooc | 3 | 0 | 0 | 0 | 0 |
| heal | me | ooc | 1 | 1 | 1 | 1 | 1 |
| heal | me | combat | 2 | 2 | 2 | 2 | 2 |
| heal | my totems/pets | ooc | 36 | 17 | 17 | 17 | 0 |
| heal | my totems/pets | combat | 74 | 34 | 34 | 34 | 0 |
| heal | another player | ooc | 3 | 0 | 0 | 0 | 0 |
| heal | another player | combat | 2 | 0 | 0 | 0 | 0 |
| energize | me | ooc | 1 | 1 | 1 | 1 | 0 |
| energize | my totems/pets | ooc | 3 | 3 | 3 | 3 | 0 |
| energize | another player | ooc | 21 | 0 | 0 | 0 | 0 |
| energize | another player | combat | 3 | 0 | 0 | 0 | 0 |
| aura+ | me | ooc | 2 | 2 | 2 | 2 | 2 |
| aura+ | me | combat | 7 | 7 | 7 | 0 | 0 |
| aura+ | my totems/pets | combat | 3 | 3 | 3 | 0 | 0 |
| aura+ | another player | ooc | 30 | 0 | 0 | 0 | 0 |
| aura+ | another player | combat | 9 | 0 | 0 | 0 | 0 |
| aura+ | hostile NPC | ooc | 1 | 0 | 0 | 0 | 0 |
| aura- | me | ooc | 2 | 2 | 2 | 2 | 2 |
| aura- | me | combat | 11 | 11 | 8 | 0 | 0 |
| aura- | my totems/pets | combat | 1 | 0 | 0 | 0 | 0 |
| aura- | another player | ooc | 12 | 0 | 0 | 0 | 0 |
| aura- | another player | combat | 6 | 0 | 0 | 0 | 0 |
| aura- | hostile NPC | ooc | 1 | 0 | 0 | 0 | 0 |
| cast-start | me | combat | 3 | 3 | 3 | 0 | 3 |
| cast-start | another player | ooc | 1 | 0 | 0 | 0 | 0 |
| cast-start | another player | combat | 6 | 0 | 0 | 0 | 0 |
| cast-start | hostile NPC | combat | 7 | 5 | 4 | 0 | 0 |
| cast-success | me | ooc | 7 | 7 | 7 | 0 | 7 |
| cast-success | me | combat | 17 | 17 | 17 | 0 | 17 |
| cast-success | my totems/pets | combat | 1 | 0 | 0 | 0 | 0 |
| cast-success | another player | ooc | 22 | 0 | 0 | 0 | 0 |
| cast-success | another player | combat | 10 | 2 | 0 | 0 | 0 |
| cast-success | hostile NPC | combat | 5 | 4 | 4 | 0 | 0 |
| cast-fail | me | combat | 4 | 4 | 4 | 0 | 4 |
| interrupt | me | combat | 1 | 1 | 1 | 0 | 0 |
| summon | me | ooc | 3 | 3 | 3 | 0 | 3 |
| summon | me | combat | 3 | 3 | 3 | 0 | 3 |
| death | - | ooc | 2 | 0 | 0 | 0 | 0 |
| death | - | combat | 3 | 0 | 0 | 0 | 0 |

Full rows with target classes: coverage.json `matrix`.

## Live attribution (HSM replay of the recorded live events, scored against the log)

before = v2.2.3 library behaviour (no UNIT_COMBAT/DM/swing/interrupt attribution, secret-timing window 2.4 s); after = HybridState MINOR 3 (v2.2.4). accuracy = correct / events with a log match; coverage = attributed / matched; falseSelf = attributed to me but the log says someone else (counted as contradictions).

| category | n | before acc | before cov | before falseSelf | after acc | after cov | after falseSelf | after missedSelf |
|---|---|---|---|---|---|---|---|---|
| aura-on-me | 2 | 50.0 | 50.0 | 0 | 100.0 | 100.0 | 0 | 0 |
| aura-on-target | 6 | 83.3 | 83.3 | 0 | 100.0 | 100.0 | 0 | 0 |
| damage-on-target | 41 | 0.0 | 0.0 | 0 | 100.0 | 100.0 | 0 | 0 |
| damage-taken | 36 | 0.0 | 0.0 | 0 | 100.0 | 100.0 | 0 | 0 |
| heal-on-me | 54 | 0.0 | 0.0 | 0 | 100.0 | 100.0 | 0 | 0 |
| interrupt | 1 | 0.0 | 0.0 | 0 | 100.0 | 100.0 | 0 | 0 |
| miss-on-target | 4 | 0.0 | 0.0 | 0 | 100.0 | 100.0 | 0 | 0 |

Reference: a meter that counts everything on my target as mine: 95.1% correct, 2 false-self hit(s), 360 damage wrongly credited to me.


## Timing models (trained on this log)

| channel | n | min | median | max |
|---|---|---|---|---|
| UNIT_COMBAT - file time, damage | 28 | -0.010 | -0.001 | 0.208 |
| UNIT_COMBAT - file time, damage/melee | 39 | -0.002 | 0.458 | 0.979 |
| UNIT_COMBAT - file time, heal | 54 | -0.005 | -0.001 | 0.000 |
| UNIT_COMBAT - file time, miss | 14 | -0.003 | 0.334 | 0.750 |

## Fights: log vs C_DamageMeter (post-combat, clear)

| fight | dur (log/DM) | my damage log/DM | others on my targets log / DM others | taken log/DM | my effective heal on me log/DM | my interrupts log/DM |
|---|---|---|---|---|---|---|
| 1 | 28.5/28 | 1324/1324 | 0 / 0 | 267/267 | 69/69 | 0/0 |
| 2 | 37.4/37 | 1213/1213 | 0 / 0 | 935/935 | 555/555 | 1/1 |
| 3 | 14.4/14 | 799/799 | 360 / 0 | 221/221 | 18/12 | 0/0 |

HSM live reconciliation at PLAYER_REGEN_ENABLED (after):

- DM mine 1324 vs live mine 1219; live other 0; others-on-target (live total - DM mine) 0; interrupts DM 0 / live 0
- DM mine 1213 vs live mine 1088; live other 0; others-on-target (live total - DM mine) 0; interrupts DM 1 / live 1
- DM mine 799 vs live mine 799; live other 360; others-on-target (live total - DM mine) 360; interrupts DM 0 / live 0

## Another player on my target (newest such fight)

Others: other player A. Their casts in the log: 5; their auras on the target: 0. Damage by others: log 360, live 'other' 360; live 'mine' 799; false self-attributions: 0.

| t | live UNIT_COMBAT | amount | school | crit | DM event | HSM | rule | log truth |
|---|---|---|---|---|---|---|---|---|
| 1791432211.291 | WOUND | 38 | 4 | False | True | mine | cast-frame | me |
| 1791432213.376 | WOUND | 123 | 1 | False | True | mine | cast-frame | me |
| 1791432214.001 | WOUND | 119 | 1 | False | False | mine | swing-lag | me |
| 1791432214.209 | WOUND | 8 | 4 | False | True | mine | dm-frame | me |
| 1791432216.793 | DODGE | 0 | 1 | False | False | mine | swing-lag | me |
| 1791432217.293 | WOUND | 8 | 4 | False | True | mine | dm-frame | me |
| 1791432217.522 | WOUND | 105 | 16 | True | True | mine | cast-frame | me |
| 1791432218.272 | WOUND | 177 | 16 | False | False | other | elimination | player |
| 1791432220.168 | WOUND | 128 | 1 | False | False | mine | swing-lag | me |
| 1791432220.293 | WOUND | 8 | 4 | False | True | mine | dm-frame | me |
| 1791432221.584 | WOUND | 183 | 16 | False | False | other | elimination | player |
| 1791432223.209 | WOUND | 8 | 4 | False | True | mine | dm-frame | me |
| 1791432224.126 | WOUND | 130 | 1 | False | False | mine | swing-lag | me |
| 1791432224.668 | WOUND | 124 | 1 | False | True | mine | cast-frame | None |

Log timeline:

| t | who | event | spell | amount |
|---|---|---|---|---|
| 1791432209.729 | other player A | SPELL_CAST_SUCCESS | Frost Armor | None |
| 1791432211.293 | me | SPELL_CAST_SUCCESS | Flame Shock | None |
| 1791432211.301 | me | SPELL_DAMAGE | Flame Shock | 38 |
| 1791432211.301 | me | SPELL_AURA_APPLIED | Flame Shock | None |
| 1791432213.022 | me | SWING_DAMAGE | melee | 119 |
| 1791432213.022 | me | SWING_DAMAGE_LANDED | melee | None |
| 1791432213.378 | me | SPELL_CAST_SUCCESS | Stormstrike | None |
| 1791432213.378 | me | SPELL_DAMAGE | Stormstrike | 123 |
| 1791432213.379 | me | SPELL_AURA_APPLIED | Stormstrike | None |
| 1791432214.209 | me | SPELL_PERIODIC_DAMAGE | Flame Shock | 8 |
| 1791432214.626 | other player A | SPELL_CAST_START | Frostbolt | None |
| 1791432216.335 | me | SWING_MISSED | melee | None |
| 1791432217.147 | other player A | SPELL_CAST_SUCCESS | Frostbolt | None |
| 1791432217.293 | me | SPELL_PERIODIC_DAMAGE | Flame Shock | 8 |
| 1791432217.523 | me | SPELL_CAST_SUCCESS | Frost Shock | None |
| 1791432217.525 | me | SPELL_AURA_APPLIED | Frost Shock | None |
| 1791432217.525 | me | SPELL_DAMAGE | Frost Shock | 105 |
| 1791432217.938 | other player A | SPELL_CAST_START | Frostbolt | None |
| 1791432218.23 | other player A | SPELL_DAMAGE | Frostbolt | 177 |
| 1791432219.709 | me | SWING_DAMAGE | melee | 128 |
| 1791432219.71 | me | SWING_DAMAGE_LANDED | melee | None |
| 1791432220.293 | me | SPELL_PERIODIC_DAMAGE | Flame Shock | 8 |
| 1791432220.399 | other player A | SPELL_CAST_SUCCESS | Frostbolt | None |
| 1791432221.438 | other player A | SPELL_DAMAGE | Frostbolt | 183 |
| 1791432223.211 | me | SPELL_PERIODIC_DAMAGE | Flame Shock | 8 |
| 1791432223.211 | me | SPELL_AURA_REMOVED | Flame Shock | None |
| 1791432223.668 | me | SWING_DAMAGE | melee | 130 |
| 1791432223.668 | me | SWING_DAMAGE_LANDED | melee | None |
| 1791432224.669 | me | SPELL_CAST_SUCCESS | Stormstrike | None |
| 1791432224.671 | me | SPELL_AURA_REMOVED | Stormstrike | None |
| 1791432224.671 | me | SPELL_AURA_REMOVED | Frost Shock | None |
| 1791432224.671 | me | PARTY_KILL |  | None |
| 1791432224.671 | me | SPELL_DAMAGE | Stormstrike | 124 |

## C_DamageMeter

- DAMAGE_METER_COMBAT_SESSION_UPDATED by type: {'0': 80, '1': 80, '10': 80, '7': 52, '2': 66, '3': 66, '5': 2} (by context {'combat': 414, 'ooc': 12}); events with a secret argument: 0
- post-combat records: 4 (CombatLog snapshot)

CombatProbe cells (v2.2 probe set):

| context | API | result codes | fields | predicate |
|---|---|---|---|---|
| combat | C_DamageMeter.IsDamageMeterAvailable | [{'C': 6}, {'C': 6}] | None | None |
| combat | C_DamageMeter.GetCombatSessionFromType | [{'T': 6}] | {'durationSeconds': {'S': 6}, 'combatSources': {'K': 6}, 'totalAmount': {'S': 6}, 'maxAmount': {'S': 6}} | {'t': 6} |
| ooc | C_DamageMeter.IsDamageMeterAvailable | [{'C': 4}, {'C': 4}] | None | None |
| ooc | C_DamageMeter.GetCombatSessionFromType | [{'K': 4}] | {'durationSeconds': {'C': 4}, 'combatSources': {'K': 4}, 'totalAmount': {'C': 4}, 'maxAmount': {'C': 4}} | {'f': 4} |

## Cooldown / GCD tracker (HybridState MINOR 5) vs the log

State the tracker held at each of my successful casts (log SPELL_CAST_SUCCESS). A cast while the tracker said 'cooling' (or 'gcd') with more than 0.15 s left is a contradiction. 'Not yet recovered' fails in the log should find the tracker cooling.

- casts checked: 25; consistent 25; cast while cooling 0; cast inside GCD 0
- log 'Not yet recovered' fails: tracker cooling/gcd 4, tracker idle (missed) 0
- learned readies: 0; GCD windows observed: 0; spells tracked: 15

| spell | category | shared-recovery category | fail confirms | learned n | gcd n |
|---|---|---|---|---|---|
| 370 |  | 133 | 0 | 0 | 0 |
| 905 |  | 133 | 0 | 0 | 0 |
| 2484 |  | 133 | 0 | 0 | 0 |
| 5675 |  | 133 | 0 | 0 | 0 |
| 6375 |  | 133 | 0 | 0 | 0 |
| 6391 | 45 | 133 | 0 | 0 | 0 |
| 8008 |  | 133 | 0 | 0 | 0 |
| 8046 | 19 | 133 | 3 | 0 | 0 |
| 8052 | 19 | 133 | 2 | 0 | 0 |
| 8056 | 19 | 133 | 0 | 0 | 0 |
| 8155 |  | 133 | 0 | 0 | 0 |
| 8177 | 230 | 133 | 0 | 0 | 0 |
| 17364 |  | 133 | 0 | 0 | 0 |
| 36936 |  | 133 | 0 | 0 | 0 |
| 408342 | 35 | 133 | 0 | 0 | 0 |

## Cooldown model vs log cast failures

- fail verdicts: {'confirms': 4}

| spell | cast | predicted ready (+s) | recast (+s) | recast - ready | verdict |
|---|---|---|---|---|---|
| 8052 | 00:02:03 | 6.0 | 16.9 | 10.855 | consistent |
| 8052 | 00:02:19 | 6.0 | 22.9 | 16.921 | consistent |
| 8046 | 00:02:51 | 6.0 | 6.0 | 0.023 | consistent |
| 8046 | 00:02:57 | 6.0 | 20.7 | 14.668 | consistent |
| 17364 | 00:03:33 | 8.0 | 11.3 | 3.293 | consistent |

## Enemy cast bars: live duration model vs log

- log NPC casts: 15; predicted: 2; mean abs error 0.056 s; within 150 ms: 2
- model npc:4119: n 3, median 3.500 s (min 3.437, max 3.542)

## Overheal estimate vs log

- heals 54, estimated 54, exact 52, overheal yes/no correct 53, mean abs error 0.5

## Ledger (cached clear facts) vs log

- aura claims (live / cached-fresh / cached-stale) vs log: {'unknown': 21, 'correct': 1}; by confidence: {'cached-stale': {'unknown': 21}, 'cached-fresh': {'correct': 1}, 'maybe-removed': {'unknown': 50, 'stillPresent': 15, 'removalConfirmed': 35}}
- 'maybe-removed' entries are doubts, never claims: removalConfirmed = the log shows the aura really was gone, stillPresent = the doubt was unnecessary
- token->GUID resolutions: {'n': 44, 'correct': 41, 'wrong': 3}
- ledger stats: {'evicted': 0, 'invalidated': 2, 'stale': 0, 'puts': 43, 'live': 0, 'fresh': 0, 'miss': 3}

## Live verdicts (verify ring, replayed)

| kind | V | C | U | X |
|---|---|---|---|---|
| aura-expiry | 0 | 0 | 1 | 0 |
| cast-end | 2 | 0 | 1 | 0 |
| cooldown | 11 | 0 | 0 | 0 |
| damage-range | 4 | 0 | 1 | 0 |
| dm-total | 3 | 0 | 0 | 0 |
| interrupt-attribution | 1 | 0 | 0 | 0 |

## Unreadable rule inputs (Inference.inputs, u > 0)

- combat: aura.addedAuras r0/u10, aura.count r0/u24, totem.duration r0/u5, totem.haveTotem r0/u5, totem.name r0/u5, totem.startTime r0/u5, unitCast.castGUID r0/u27, unitCast.spellID r0/u27
- ooc: unitCast.castGUID r0/u2, unitCast.spellID r0/u2
