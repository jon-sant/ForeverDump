# Combat-event coverage: combat log (truth) vs what the addon read live

Truth = the WoWCombatLog file, read offline only. Live = event payloads/timing and API values the capture saw (no CLEU, no side channels). Columns: **log** events in the capture span; **tok** the event touched a unit token the addon follows (player/target); **seen** a live event matched it (time window + amount); **amt** the amount/value was readable; **spell** the spellID was readable live.

## Matrix (category x source x context)

| category | source | ctx | log | tok | seen | amt | spell |
|---|---|---|---|---|---|---|---|
| damage | me | ooc | 8 | 8 | 0 | 0 | 0 |
| damage | me | combat | 94 | 94 | 0 | 0 | 0 |
| damage | my totems/pets | ooc | 1 | 0 | 0 | 0 | 0 |
| damage | my totems/pets | combat | 14 | 0 | 0 | 0 | 0 |
| damage | another player | ooc | 2313 | 34 | 29 | 29 | 0 |
| damage | another player | combat | 3065 | 316 | 293 | 293 | 0 |
| damage | hostile NPC | ooc | 22 | 1 | 1 | 1 | 0 |
| damage | hostile NPC | combat | 45 | 3 | 3 | 3 | 0 |
| damage | other | ooc | 70 | 3 | 3 | 3 | 0 |
| damage | other | combat | 79 | 28 | 27 | 27 | 0 |
| damage | - | ooc | 25 | 1 | 1 | 1 | 0 |
| damage | - | combat | 16 | 1 | 1 | 1 | 0 |
| miss | me | ooc | 1 | 1 | 0 | 0 | 0 |
| miss | me | combat | 24 | 24 | 0 | 0 | 0 |
| miss | my totems/pets | ooc | 2 | 0 | 0 | 0 | 0 |
| miss | my totems/pets | combat | 12 | 0 | 0 | 0 | 0 |
| miss | another player | ooc | 348 | 4 | 0 | 0 | 0 |
| miss | another player | combat | 482 | 24 | 11 | 11 | 0 |
| miss | hostile NPC | ooc | 8 | 1 | 1 | 1 | 0 |
| miss | hostile NPC | combat | 19 | 2 | 1 | 1 | 0 |
| miss | other | ooc | 20 | 0 | 0 | 0 | 0 |
| miss | other | combat | 24 | 6 | 2 | 2 | 0 |
| crit | me | ooc | 1 | 1 | 0 | 0 | 0 |
| crit | me | combat | 4 | 4 | 0 | 0 | 0 |
| crit | my totems/pets | ooc | 5 | 1 | 0 | 0 | 0 |
| crit | my totems/pets | combat | 14 | 2 | 0 | 0 | 0 |
| crit | another player | ooc | 233 | 5 | 2 | 2 | 0 |
| crit | another player | combat | 307 | 27 | 24 | 24 | 0 |
| crit | hostile NPC | ooc | 18 | 1 | 0 | 0 | 0 |
| crit | hostile NPC | combat | 16 | 2 | 0 | 0 | 0 |
| crit | other | ooc | 16 | 0 | 0 | 0 | 0 |
| crit | other | combat | 8 | 2 | 2 | 2 | 0 |
| overkill | me | combat | 3 | 3 | 0 | 0 | 0 |
| overkill | another player | ooc | 72 | 3 | 0 | 0 | 0 |
| overkill | another player | combat | 74 | 6 | 0 | 0 | 0 |
| overkill | - | ooc | 1 | 0 | 0 | 0 | 0 |
| absorb | me | combat | 14 | 14 | 0 | 0 | 0 |
| absorb | my totems/pets | ooc | 2 | 0 | 0 | 0 | 0 |
| absorb | my totems/pets | combat | 9 | 0 | 0 | 0 | 0 |
| absorb | another player | ooc | 130 | 4 | 0 | 0 | 0 |
| absorb | another player | combat | 195 | 13 | 0 | 0 | 0 |
| absorb | hostile NPC | ooc | 1 | 0 | 0 | 0 | 0 |
| absorb | hostile NPC | combat | 9 | 1 | 0 | 0 | 0 |
| absorb | other | ooc | 3 | 0 | 0 | 0 | 0 |
| absorb | other | combat | 7 | 4 | 0 | 0 | 0 |
| heal | me | ooc | 3 | 3 | 3 | 3 | 3 |
| heal | me | combat | 15 | 15 | 14 | 14 | 14 |
| heal | my totems/pets | ooc | 92 | 28 | 28 | 28 | 0 |
| heal | my totems/pets | combat | 205 | 43 | 43 | 43 | 0 |
| heal | another player | ooc | 675 | 19 | 17 | 17 | 0 |
| heal | another player | combat | 992 | 57 | 56 | 56 | 0 |
| heal | hostile NPC | ooc | 211 | 10 | 10 | 10 | 0 |
| heal | hostile NPC | combat | 332 | 25 | 25 | 25 | 0 |
| heal | other | ooc | 22 | 0 | 0 | 0 | 0 |
| heal | other | combat | 37 | 0 | 0 | 0 | 0 |
| energize | another player | ooc | 732 | 5 | 4 | 4 | 0 |
| energize | another player | combat | 836 | 22 | 19 | 0 | 0 |
| energize | hostile NPC | ooc | 18 | 0 | 0 | 0 | 0 |
| energize | hostile NPC | combat | 37 | 0 | 0 | 0 | 0 |
| aura+ | me | ooc | 31 | 31 | 26 | 0 | 0 |
| aura+ | me | combat | 69 | 69 | 33 | 0 | 0 |
| aura+ | my totems/pets | ooc | 9 | 0 | 0 | 0 | 0 |
| aura+ | my totems/pets | combat | 18 | 0 | 0 | 0 | 0 |
| aura+ | another player | ooc | 2428 | 48 | 38 | 0 | 0 |
| aura+ | another player | combat | 2094 | 105 | 99 | 0 | 0 |
| aura+ | hostile NPC | ooc | 45 | 0 | 0 | 0 | 0 |
| aura+ | hostile NPC | combat | 40 | 0 | 0 | 0 | 0 |
| aura+ | other | ooc | 24 | 0 | 0 | 0 | 0 |
| aura+ | other | combat | 8 | 1 | 1 | 0 | 0 |
| aura+ | - | ooc | 30 | 0 | 0 | 0 | 0 |
| aura+ | - | combat | 25 | 0 | 0 | 0 | 0 |
| aura- | me | ooc | 30 | 30 | 23 | 0 | 0 |
| aura- | me | combat | 75 | 75 | 46 | 0 | 0 |
| aura- | my totems/pets | ooc | 4 | 0 | 0 | 0 | 0 |
| aura- | my totems/pets | combat | 4 | 0 | 0 | 0 | 0 |
| aura- | another player | ooc | 1896 | 37 | 33 | 1 | 1 |
| aura- | another player | combat | 1981 | 112 | 96 | 0 | 0 |
| aura- | hostile NPC | ooc | 27 | 0 | 0 | 0 | 0 |
| aura- | hostile NPC | combat | 26 | 0 | 0 | 0 | 0 |
| aura- | other | ooc | 14 | 0 | 0 | 0 | 0 |
| aura- | other | combat | 10 | 1 | 1 | 0 | 0 |
| aura- | - | ooc | 30 | 0 | 0 | 0 | 0 |
| aura- | - | combat | 23 | 0 | 0 | 0 | 0 |
| cast-start | me | ooc | 7 | 7 | 7 | 0 | 7 |
| cast-start | me | combat | 16 | 16 | 16 | 0 | 16 |
| cast-start | my totems/pets | ooc | 1 | 0 | 0 | 0 | 0 |
| cast-start | my totems/pets | combat | 35 | 0 | 0 | 0 | 0 |
| cast-start | another player | ooc | 249 | 2 | 1 | 0 | 0 |
| cast-start | another player | combat | 329 | 0 | 0 | 0 | 0 |
| cast-start | hostile NPC | ooc | 39 | 0 | 0 | 0 | 0 |
| cast-start | hostile NPC | combat | 65 | 0 | 0 | 0 | 0 |
| cast-start | other | ooc | 1 | 0 | 0 | 0 | 0 |
| cast-start | other | combat | 2 | 0 | 0 | 0 | 0 |
| cast-success | me | ooc | 42 | 42 | 42 | 0 | 42 |
| cast-success | me | combat | 117 | 117 | 117 | 0 | 117 |
| cast-success | my totems/pets | ooc | 3 | 0 | 0 | 0 | 0 |
| cast-success | my totems/pets | combat | 29 | 0 | 0 | 0 | 0 |
| cast-success | another player | ooc | 2079 | 45 | 1 | 0 | 0 |
| cast-success | another player | combat | 2399 | 144 | 0 | 0 | 0 |
| cast-success | hostile NPC | ooc | 31 | 0 | 0 | 0 | 0 |
| cast-success | hostile NPC | combat | 61 | 0 | 0 | 0 | 0 |
| cast-success | other | ooc | 16 | 0 | 0 | 0 | 0 |
| cast-success | other | combat | 9 | 1 | 0 | 0 | 0 |
| cast-fail | me | ooc | 33 | 33 | 30 | 0 | 30 |
| cast-fail | me | combat | 434 | 434 | 433 | 0 | 433 |
| interrupt | another player | ooc | 1 | 0 | 0 | 0 | 0 |
| dispel | me | combat | 14 | 14 | 0 | 0 | 0 |
| dispel | another player | ooc | 16 | 0 | 0 | 0 | 0 |
| dispel | another player | combat | 24 | 2 | 0 | 0 | 0 |
| summon | me | ooc | 12 | 12 | 12 | 0 | 12 |
| summon | me | combat | 26 | 26 | 26 | 0 | 26 |
| summon | another player | ooc | 54 | 0 | 0 | 0 | 0 |
| summon | another player | combat | 66 | 0 | 0 | 0 | 0 |
| death | - | ooc | 73 | 9 | 9 | 0 | 0 |
| death | - | combat | 58 | 0 | 0 | 0 | 0 |

Full rows with target classes: coverage.json `matrix`.

## Live attribution (HSM replay of the recorded live events, scored against the log)

before = v2.2.3 library behaviour (no UNIT_COMBAT/DM/swing/interrupt attribution, secret-timing window 2.4 s); after = HybridState MINOR 3 (v2.2.4). accuracy = correct / events with a log match; coverage = attributed / matched; falseSelf = attributed to me but the log says someone else (counted as contradictions).

| category | n | before acc | before cov | before falseSelf | after acc | after cov | after falseSelf | after missedSelf |
|---|---|---|---|---|---|---|---|---|
| aura-on-me | 164 | 4.9 | 4.9 | 0 | 89.0 | 97.0 | 4 | 11 |
| aura-on-target | 22 | 0.0 | 0.0 | 0 | 100.0 | 100.0 | 0 | 0 |
| damage-on-target | 90 | 0.0 | 0.0 | 0 | 100.0 | 100.0 | 0 | 0 |
| damage-taken | 297 | 0.0 | 0.0 | 0 | 100.0 | 100.0 | 0 | 0 |
| heal-on-me | 165 | 0.0 | 0.0 | 0 | 75.8 | 99.4 | 24 | 16 |
| heal-on-target | 31 | 0.0 | 0.0 | 0 | 100.0 | 100.0 | 0 | 0 |
| interrupt | 1 | 0.0 | 0.0 | 0 | 100.0 | 100.0 | 0 | 0 |
| miss-on-target | 1 | 0.0 | 0.0 | 0 | 100.0 | 100.0 | 0 | 0 |

Reference: a meter that counts everything on my target as mine: 0.0% correct, 90 false-self hit(s), 4088 damage wrongly credited to me.

Remaining errors (after):

- 1791600764.229 aura-on-me: claimed other, log me (rule aura-me-elim, amount None)
- 1791600798.041 aura-on-me: claimed other, log me (rule aura-me-elim, amount None)
- 1791600825.727 aura-on-me: claimed other, log me (rule aura-me-elim, amount None)
- 1791600877.632 aura-on-me: claimed mine, log player (rule own-cast-frame, amount None)
- 1791600885.554 heal-on-me: claimed mine, log player (rule summon-cadence, amount 71)
- 1791600891.539 heal-on-me: claimed mine, log player (rule heal-cadence, amount 71)
- 1791600923.378 heal-on-me: claimed other, log me (rule elimination, amount 232)
- 1791600939.673 aura-on-me: claimed other, log me (rule aura-me-elim, amount None)
- 1791600942.966 heal-on-me: claimed mine, log player (rule summon-cadence, amount 70)
- 1791600948.966 heal-on-me: claimed mine, log player (rule heal-cadence, amount 70)
- 1791600962.509 heal-on-me: claimed mine, log player (rule summon-cadence, amount 120)
- 1791600966.58 heal-on-me: claimed mine, log player (rule heal-cadence, amount 106)
- 1791600967.024 heal-on-me: claimed mine, log player (rule summon-cadence, amount 125)
- 1791600968.524 heal-on-me: claimed mine, log player (rule summon-cadence, amount 124)
- 1791600969.607 heal-on-me: claimed mine, log player (rule summon-cadence, amount 70)
- 1791600969.732 heal-on-me: claimed mine, log player (rule summon-cadence, amount 682)
- 1791600972.586 heal-on-me: claimed mine, log player (rule summon-cadence, amount 71)
- 1791600975.586 heal-on-me: claimed mine, log player (rule summon-cadence, amount 71)
- 1791600978.586 heal-on-me: claimed mine, log player (rule summon-cadence, amount 70)
- 1791600983.857 aura-on-me: claimed mine, log player (rule own-cast-frame, amount None)
- 1791601246.28 aura-on-me: claimed other, log me (rule aura-me-elim, amount None)
- 1791601257.092 heal-on-me: claimed mine, log player (rule summon-cadence, amount 121)
- 1791601263.644 heal-on-me: claimed other, log mine (rule elimination, amount 6)
- 1791601265.644 heal-on-me: claimed other, log mine (rule elimination, amount 6)
- 1791601267.644 heal-on-me: claimed other, log mine (rule elimination, amount 9)
- 1791601269.646 heal-on-me: claimed other, log mine (rule elimination, amount 7)
- 1791601271.646 heal-on-me: claimed other, log mine (rule elimination, amount 7)
- 1791601273.646 heal-on-me: claimed other, log mine (rule elimination, amount 6)
- 1791601275.646 heal-on-me: claimed other, log mine (rule elimination, amount 7)
- 1791601277.646 heal-on-me: claimed other, log mine (rule elimination, amount 6)
- 1791601279.626 heal-on-me: claimed other, log mine (rule elimination, amount 7)
- 1791601281.626 heal-on-me: claimed other, log mine (rule elimination, amount 7)
- 1791601283.646 heal-on-me: claimed other, log mine (rule elimination, amount 7)
- 1791601285.625 heal-on-me: claimed other, log mine (rule elimination, amount 7)
- 1791601287.646 heal-on-me: claimed other, log mine (rule elimination, amount 7)
- 1791601289.625 heal-on-me: claimed other, log mine (rule elimination, amount 6)
- 1791601327.253 aura-on-me: claimed other, log me (rule aura-me-elim, amount None)
- 1791601329.086 aura-on-me: claimed mine, log player (rule own-cast-frame, amount None)
- 1791601425.326 aura-on-me: claimed other, log me (rule aura-me-elim, amount None)
- 1791601524.042 aura-on-me: claimed other, log me (rule aura-me-elim, amount None)

## Timing models (trained on this log)

| channel | n | min | median | max |
|---|---|---|---|---|
| UNIT_COMBAT - file time, damage | 247 | -0.022 | -0.016 | 0.734 |
| UNIT_COMBAT - file time, damage/melee | 112 | -0.034 | 0.026 | 0.965 |
| UNIT_COMBAT - file time, heal | 196 | -0.021 | -0.016 | -0.015 |
| UNIT_COMBAT - file time, miss | 29 | -0.021 | -0.015 | 0.964 |

## Fights: log vs C_DamageMeter (post-combat, clear)

| fight | dur (log/DM) | my damage log/DM | others on my targets log / DM others | taken log/DM | my effective heal on me log/DM | my interrupts log/DM |
|---|---|---|---|---|---|---|
| 1 | 30.1/None | 639/None | 3032 / None | 2392/None | 0/None | 0/None |
| 2 | 22.6/None | 316/None | 1520 / None | 0/None | 0/None | 0/None |
| 3 | 13.6/None | 60/None | 1291 / None | 427/None | 0/None | 0/None |
| 4 | 24.3/None | 341/None | 2419 / None | 1588/None | 0/None | 0/None |
| 5 | 19.6/None | 785/None | 446 / None | 2079/None | 36/None | 0/None |
| 6 | 9.2/None | 140/None | 0 / None | 75/None | 0/None | 0/None |
| 7 | 29.3/41 | 571/571 | 1604 / 18043 | 1789/1789 | 324/324 | 0/0 |
| 7+8+9+10 | 52.5/67 | 833/833 | 3290 / 29623 | 2417/2408 | 553/553 | 0/0 |
| 11 | 6.1/21 | 77/77 | 0 / 1761 | 16/0 | 0/0 | 0/0 |
| 11+12+13 | 58.5/90 | 1854/2314 | 6974 / 40985 | 1680/1664 | 264/264 | 0/0 |
| 11+12+13+14 | 72.6/120 | 2258/2718 | 6974 / 49860 | 3018/3002 | 284/315 | 0/0 |
| 11+12+13+14+15 | 89.6/165 | 3646/4106 | 7832 / 71188 | 4322/4354 | 284/315 | 0/0 |
| 11+12+13+14+15+16 | 99.8/223 | 3700/4218 | 9373 / 92038 | 4330/4362 | 284/549 | 0/0 |
| 11+12+13+14+15+16+17 | 126.5/262 | 3840/4436 | 9460 / 107204 | 5061/5093 | 284/1382 | 0/0 |
| 11+12+13+14+15+16+17+18 | 140.4/302 | 3945/4564 | 9712 / 121071 | 5599/5808 | 572/1670 | 0/0 |
| 11+12+13+14+15+16+17+18+19+20 | 156.9/322 | 4308/5408 | 9820 / 131043 | 6899/7204 | 572/1670 | 0/0 |
| 11+12+13+14+15+16+17+18+19+20+21 | 168.8/345 | 4942/6064 | 10255 / 143954 | 7103/7408 | 572/1670 | 0/0 |
| 21+22 (partial) | 35.2/29 | 1387/753 | 1341 / 7847 | 542/460 | 0/0 | 0/0 |
| 22+23+24 (partial) | 55.4/37 | 753/0 | 906 / 14458 | 877/503 | 51/846 | 0/0 |
| 23 | 12.3/12 | 0/0 | 0 / 3859 | 395/359 | 13/30 | 0/0 |
| 23+24+25 | 43.2/49 | 338/338 | 1086 / 22233 | 882/846 | 63/858 | 0/0 |
| 23+24+25+26 | 63.4/71 | 338/338 | 1086 / 27179 | 882/846 | 63/918 | 0/0 |
| 23+24+25+26+27 | 70.3/89 | 459/459 | 1428 / 36109 | 2128/2100 | 63/938 | 0/0 |
| 28 | 18.5/43 | 170/292 | 0 / 16368 | 1238/1238 | 0/0 | 0/0 |
| 28 | 18.5/116 | 170/292 | 0 / 41051 | 1238/1238 | 0/0 | 0/0 |
| 28 | 18.5/118 | 170/292 | 0 / 41051 | 1238/1238 | 0/0 | 0/0 |

HSM live reconciliation at PLAYER_REGEN_ENABLED (after):

- DM mine 571 vs live mine 173; live other 1223; others-on-target (live total - DM mine) 825; interrupts DM 0 / live 0
- DM mine 833 vs live mine 0; live other 435; others-on-target (live total - DM mine) 0; interrupts DM 0 / live 0
- DM mine 77 vs live mine 77; live other 0; others-on-target (live total - DM mine) 0; interrupts DM 0 / live 0
- DM mine 2314 vs live mine 102; live other 714; others-on-target (live total - DM mine) 0; interrupts DM 0 / live 0
- DM mine 2718 vs live mine 77; live other 327; others-on-target (live total - DM mine) 0; interrupts DM 0 / live 0
- DM mine 4106 vs live mine 643; live other 610; others-on-target (live total - DM mine) 0; interrupts DM 0 / live 0
- DM mine 4218 vs live mine 54; live other 1019; others-on-target (live total - DM mine) 0; interrupts DM 0 / live 0
- DM mine 4436 vs live mine 53; live other 717; others-on-target (live total - DM mine) 0; interrupts DM 0 / live 0
- DM mine 4564 vs live mine 74; live other 283; others-on-target (live total - DM mine) 0; interrupts DM 0 / live 0
- DM mine 5408 vs live mine 181; live other 132; others-on-target (live total - DM mine) 0; interrupts DM 0 / live 0
- DM mine 6064 vs live mine 95; live other 284; others-on-target (live total - DM mine) 0; interrupts DM 0 / live 0
- DM mine 753 vs live mine 235; live other 903; others-on-target (live total - DM mine) 385; interrupts DM 0 / live 0
- DM mine 0 vs live mine 0; live other 0; others-on-target (live total - DM mine) 0; interrupts DM 0 / live 0
- DM mine 0 vs live mine 0; live other 2757; others-on-target (live total - DM mine) 2757; interrupts DM 0 / live 0
- DM mine 338 vs live mine 155; live other 1228; others-on-target (live total - DM mine) 1045; interrupts DM 0 / live 0
- DM mine 338 vs live mine 0; live other 531; others-on-target (live total - DM mine) 193; interrupts DM 0 / live 0
- DM mine 459 vs live mine 0; live other 341; others-on-target (live total - DM mine) 0; interrupts DM 0 / live 0
- DM mine 292 vs live mine 83; live other 48; others-on-target (live total - DM mine) 0; interrupts DM 0 / live 0

## Another player on my target (newest such fight)

Others: other player A. Their casts in the log: 3; their auras on the target: 0. Damage by others: log 0, live 'other' 950; live 'mine' 235; false self-attributions: 0.

| t | live UNIT_COMBAT | amount | school | crit | DM event | HSM | rule | log truth |
|---|---|---|---|---|---|---|---|---|
| 1791601537.677 | WOUND | 47 | 16 | False | True | other | elimination | None |
| 1791601537.76 | DODGE | 0 | 1 | False | False | other | elimination | None |
| 1791601537.989 | PARRY | 0 | 1 | False | True | other | elimination | None |
| 1791601538.635 | WOUND | 23 | 4 | False | True | other | elimination | None |
| 1791601538.677 | WOUND | 51 | 1 | False | False | other | elimination | None |
| 1791601544.552 | WOUND | 76 | 16 | False | True | mine | cast-frame | None |
| 1791601544.573 | WOUND | 21 | 4 | False | True | none | damage-ambiguous | None |
| 1791601546.867 | WOUND | 75 | 16 | False | True | other | elimination | None |
| 1791601546.909 | WOUND | 133 | 1 | False | False | none | damage-ambiguous | None |
| 1791601547.555 | WOUND | 127 | 1 | False | True | other | elimination | None |
| 1791601547.745 | WOUND | 20 | 4 | False | False | other | elimination | None |
| 1791601550.224 | WOUND | 149 | 1 | False | False | mine | swing-lag | None |
| 1791601551.849 | WOUND | 163 | 1 | False | False | other | elimination | None |
| 1791601552.432 | MISS | 0 | 1 | False | True | other | elimination | None |
| 1791601553.016 | WOUND | 161 | 1 | False | False | other | elimination | None |
| 1791601553.099 | WOUND | 10 | 1 | True | True | mine | swing-frame | None |
| 1791601553.516 | WOUND | 156 | 1 | False | False | other | elimination | None |
| 1791601554.599 | WOUND | 127 | 1 | False | True | other | elimination | None |

Log timeline:

| t | who | event | spell | amount |
|---|---|---|---|---|
| 1791601554.198 | other player A | SPELL_CAST_START | Corruption | None |
| 1791601554.512 | me | SPELL_SUMMON | Grounding Totem | None |
| 1791601555.703 | other player A | SPELL_CAST_SUCCESS | Siphon Life | None |
| 1791601555.703 | other player A | SPELL_MISSED | Siphon Life | None |
| 1791601559.282 | other player A | SPELL_CAST_START | Corruption | None |

## C_DamageMeter

- DAMAGE_METER_COMBAT_SESSION_UPDATED by type: {'0': 10768, '1': 10768, '10': 10768, '7': 10440, '2': 3672, '3': 3672, '4': 806, '6': 122, '9': 252, '5': 2} (by context {'combat': 29724, 'ooc': 21546}); events with a secret argument: 0
- post-combat records: 20 (DamageMeter.lua)
- deep per-unit sources (IdKey'd): 2774 source-rows / 15 distinct IdKeys across 18 deep fight(s)

CombatProbe cells (v2.2 probe set):

| context | API | result codes | fields | predicate |
|---|---|---|---|---|
| restricted | C_DamageMeter.IsDamageMeterAvailable | [{'C': 39}, {'C': 39}] | None | None |
| restricted | C_DamageMeter.GetCombatSessionFromType | [{'K': 39}] | {'durationSeconds': {'C': 30}, 'combatSources': {'K': 39}, 'totalAmount': {'C': 39}, 'maxAmount': {'C': 39}} | None |
| combat | C_DamageMeter.IsDamageMeterAvailable | [{'C': 41}, {'C': 41}] | None | None |
| combat | C_DamageMeter.GetCombatSessionFromType | [{'T': 41}] | {'durationSeconds': {'S': 41}, 'combatSources': {'K': 41}, 'totalAmount': {'S': 41}, 'maxAmount': {'S': 41}} | None |

| context | field | codes |
|---|---|---|
| after-combat | AvailableCombatSession.durationSeconds | {'C': 25} |
| after-combat | AvailableCombatSession.name | {'C': 25} |
| after-combat | AvailableCombatSession.sessionID | {'C': 25} |
| after-combat | CombatSession.combatSources | {'K': 25} |
| after-combat | CombatSession.durationSeconds | {'C': 25} |
| after-combat | CombatSession.maxAmount | {'C': 25} |
| after-combat | CombatSession.totalAmount | {'C': 25} |
| after-combat | CombatSessionSource.combatSpells | {'K': 25} |
| after-combat | CombatSessionSource.totalAmount | {'C': 25} |
| after-combat | CombatSource.amountPerSecond | {'C': 25} |
| after-combat | CombatSource.classFilename | {'C': 25} |
| after-combat | CombatSource.classification | {'C': 25} |
| after-combat | CombatSource.combatSpells | {'N': 25} |
| after-combat | CombatSource.deathRecapID | {'C': 25} |
| after-combat | CombatSource.deathTimeSeconds | {'C': 25} |
| after-combat | CombatSource.isLocalPlayer | {'C': 25} |
| after-combat | CombatSource.name | {'S': 24, 'C': 1} |
| after-combat | CombatSource.sourceCreatureID | {'N': 25} |
| after-combat | CombatSource.sourceDisplayType | {'C': 25} |
| after-combat | CombatSource.sourceGUID | {'S': 24, 'C': 1} |
| after-combat | CombatSource.specIconID | {'C': 24, 'N': 1} |
| after-combat | CombatSource.totalAmount | {'C': 25} |
| after-combat | CombatSpell.amountPerSecond | {'C': 23} |
| after-combat | CombatSpell.combatSpellDetails | {'K': 23} |
| after-combat | CombatSpell.creatureName | {'C': 23} |
| after-combat | CombatSpell.isAvoidable | {'C': 23} |
| after-combat | CombatSpell.isDeadly | {'C': 23} |
| after-combat | CombatSpell.overkillAmount | {'C': 23} |
| after-combat | CombatSpell.spellID | {'C': 23} |
| after-combat | CombatSpell.totalAmount | {'C': 23} |
| after-combat | GetAvailableCombatSessions | {'K': 25} |
| after-combat | GetCombatSessionFromType | {'K': 25} |
| after-combat | GetCombatSessionSourceFromType | {'K': 25} |
| after-combat | GetSessionDurationSeconds | {'C': 25} |
| after-combat | IsDamageMeterAvailable | {'C': 25} |
| after-combat | nAvailableSessions | {'C': 25} |
| combat | AvailableCombatSession.durationSeconds | {'C': 28} |
| combat | AvailableCombatSession.name | {'C': 28} |
| combat | AvailableCombatSession.sessionID | {'C': 28} |
| combat | CombatSession.combatSources | {'K': 28} |
| combat | CombatSession.durationSeconds | {'S': 28} |
| combat | CombatSession.maxAmount | {'S': 28} |
| combat | CombatSession.totalAmount | {'S': 28} |
| combat | CombatSessionSource.combatSpells | {'K': 28} |
| combat | CombatSessionSource.totalAmount | {'S': 28} |
| combat | CombatSource.amountPerSecond | {'S': 28} |
| combat | CombatSource.classFilename | {'C': 28} |
| combat | CombatSource.classification | {'C': 28} |
| combat | CombatSource.combatSpells | {'N': 28} |
| combat | CombatSource.deathRecapID | {'C': 28} |
| combat | CombatSource.deathTimeSeconds | {'S': 28} |
| combat | CombatSource.isLocalPlayer | {'C': 28} |
| combat | CombatSource.name | {'S': 28} |
| combat | CombatSource.sourceCreatureID | {'N': 28} |
| combat | CombatSource.sourceDisplayType | {'S': 28} |
| combat | CombatSource.sourceGUID | {'S': 28} |
| combat | CombatSource.specIconID | {'C': 27, 'N': 1} |
| combat | CombatSource.totalAmount | {'S': 28} |
| combat | CombatSpell.amountPerSecond | {'S': 25} |
| combat | CombatSpell.combatSpellDetails | {'T': 25} |
| combat | CombatSpell.creatureName | {'S': 25} |
| combat | CombatSpell.isAvoidable | {'S': 25} |
| combat | CombatSpell.isDeadly | {'S': 25} |
| combat | CombatSpell.overkillAmount | {'S': 25} |
| combat | CombatSpell.spellID | {'S': 25} |
| combat | CombatSpell.totalAmount | {'S': 25} |
| combat | GetAvailableCombatSessions | {'K': 28} |
| combat | GetCombatSessionFromType | {'T': 28} |
| combat | GetCombatSessionSourceFromType | {'T': 28} |
| combat | GetSessionDurationSeconds | {'C': 28} |
| combat | IsDamageMeterAvailable | {'C': 28} |
| combat | nAvailableSessions | {'C': 28} |
| combat-struct | struct.Absorbs.nSources | {'C': 272} |
| combat-struct | struct.Absorbs.nSpells | {'N': 272} |
| combat-struct | struct.Absorbs.session | {'K': 108, 'T': 164} |
| combat-struct | struct.DamageDone.nSources | {'C': 1333} |
| combat-struct | struct.DamageDone.nSpells | {'N': 1333} |
| combat-struct | struct.DamageDone.session | {'K': 631, 'T': 702} |
| combat-struct | struct.DamageTaken.nSources | {'C': 1316} |
| combat-struct | struct.DamageTaken.nSpells | {'N': 1316} |
| combat-struct | struct.DamageTaken.session | {'K': 620, 'T': 696} |
| combat-struct | struct.Deaths.nSources | {'C': 121} |
| combat-struct | struct.Deaths.nSpells | {'N': 121} |
| combat-struct | struct.Deaths.session | {'K': 66, 'T': 55} |
| combat-struct | struct.Dispels.nSources | {'C': 58} |
| combat-struct | struct.Dispels.nSpells | {'N': 58} |
| combat-struct | struct.Dispels.session | {'K': 20, 'T': 38} |
| combat-struct | struct.Dps.nSources | {'C': 1334} |
| combat-struct | struct.Dps.nSpells | {'N': 1334} |
| combat-struct | struct.Dps.session | {'K': 634, 'T': 700} |
| combat-struct | struct.EnemyDamageTaken.nSources | {'C': 1332} |
| combat-struct | struct.EnemyDamageTaken.nSpells | {'N': 1332} |
| combat-struct | struct.EnemyDamageTaken.session | {'K': 632, 'T': 700} |
| combat-struct | struct.HealingDone.nSources | {'C': 861} |
| combat-struct | struct.HealingDone.nSpells | {'N': 861} |
| combat-struct | struct.HealingDone.session | {'K': 383, 'T': 478} |
| combat-struct | struct.Hps.nSources | {'C': 861} |
| combat-struct | struct.Hps.nSpells | {'N': 861} |
| combat-struct | struct.Hps.session | {'K': 383, 'T': 478} |
| combat-struct | struct.Interrupts.nSources | {'C': 1} |
| combat-struct | struct.Interrupts.nSpells | {'N': 1} |
| combat-struct | struct.Interrupts.session | {'K': 1} |
| ooc | CombatSession.combatSources | {'K': 1} |
| ooc | CombatSession.durationSeconds | {'N': 1} |
| ooc | CombatSession.maxAmount | {'C': 1} |
| ooc | CombatSession.totalAmount | {'C': 1} |
| ooc | CombatSessionSource.combatSpells | {'K': 1} |
| ooc | CombatSessionSource.totalAmount | {'C': 1} |
| ooc | GetAvailableCombatSessions | {'K': 1} |
| ooc | GetCombatSessionFromType | {'K': 1} |
| ooc | GetCombatSessionSourceFromType | {'K': 1} |
| ooc | GetSessionDurationSeconds | {'N': 1} |
| ooc | IsDamageMeterAvailable | {'C': 1} |
| ooc | nAvailableSessions | {'C': 1} |

## Cooldown / GCD tracker (HybridState MINOR 5) vs the log

State the tracker held at each of my successful casts (log SPELL_CAST_SUCCESS). A cast while the tracker said 'cooling' (or 'gcd') with more than 0.15 s left is a contradiction. 'Not yet recovered' fails in the log should find the tracker cooling.

- casts checked: 161; consistent 143; cast while cooling 1; cast inside GCD 17
- log 'Not yet recovered' fails: tracker cooling/gcd 340, tracker idle (missed) 0
- learned readies: 97; GCD windows observed: 23; spells tracked: 24

| t | spell | remaining | source | gcd |
|---|---|---|---|---|
| 1791600966.83 | 6375 | 0.834 | gcd:learned | yes |
| 1791601058.909 | 6375 | 0.646 | gcd:learned | yes |
| 1791601105.388 | 17364 | 0.713 | learned |  |
| 1791601207.217 | 8143 | 0.709 | gcd:learned | yes |
| 1791601234.196 | 370 | 0.271 | gcd:learned | yes |
| 1791601237.196 | 370 | 1.646 | gcd:learned | yes |
| 1791601329.086 | 8177 | 1.625 | gcd:learned | yes |
| 1791601419.03 | 2484 | 0.459 | gcd:learned | yes |
| 1791601466.463 | 8056 | 0.521 | gcd:learned | yes |
| 1791601483.101 | 8052 | 0.689 | gcd:learned | yes |
| 1791601522.188 | 8177 | 1.479 | gcd:learned | yes |
| 1791601540.614 | 1238640 | 0.5 | gcd:learned | yes |
| 1791601549.058 | 370 | 1.622 | gcd:learned | yes |
| 1791601569.849 | 8143 | 0.688 | gcd:learned | yes |
| 1791601652.215 | 2484 | 0.538 | gcd:learned | yes |
| 1791601729.319 | 370 | 0.169 | gcd:learned | yes |
| 1791601732.319 | 370 | 0.19 | gcd:learned | yes |
| 1791601733.819 | 8177 | 0.169 | gcd:learned | yes |

| spell | category | shared-recovery category | fail confirms | learned n | gcd n |
|---|---|---|---|---|---|
| 370 |  | 133 | 0 | 0 | 3 |
| 905 |  | 133 | 0 | 0 | 0 |
| 2484 |  | 133 | 6 | 4 | 1 |
| 2870 |  | 133 | 0 | 0 | 0 |
| 6364 |  | 133 | 0 | 0 | 1 |
| 6375 |  | 133 | 0 | 0 | 0 |
| 6391 | 45 | 133 | 0 | 0 | 0 |
| 8008 |  | 133 | 0 | 0 | 5 |
| 8046 | 19 | 133 | 7 | 2 | 0 |
| 8052 | 19 | 133 | 43 | 4 | 1 |
| 8056 | 19 | 133 | 46 | 8 | 0 |
| 8143 |  | 133 | 0 | 0 | 1 |
| 8177 | 230 | 133 | 41 | 8 | 1 |
| 8232 |  | 133 | 0 | 0 | 0 |
| 17364 |  | 133 | 168 | 8 | 2 |
| 20572 |  | 0 | 0 | 1 | 0 |
| 21169 | 1161 | 0 | 0 | 0 | 0 |
| 408342 | 35 | 133 | 0 | 0 | 0 |
| 1238640 |  | 133 | 0 | 0 | 6 |
| 1299026 |  | 133 | 5 | 2 | 0 |
| 1301167 |  | 133 | 0 | 0 | 0 |
| 1301168 |  |  | 0 | 0 | 0 |
| 1316048 |  |  | 0 | 0 | 0 |
| 1322629 |  | 0 | 0 | 0 | 0 |

## Cooldown model vs log cast failures

- fail verdicts: {'n/a': 104, 'confirms': 221, 'contradicts': 119, 'precondition': 15, 'inside-other-reason': 3}

| spell | cast | predicted ready (+s) | recast (+s) | recast - ready | verdict |
|---|---|---|---|---|---|
| 8177 | 22:54:37 | 15.0 | 30.7 | 15.653 | consistent |
| 17364 | 22:54:41 | 8.0 | 33.0 | 24.965 | consistent |
| 8177 | 22:55:08 | 15.0 | 36.4 | 21.36 | consistent |
| 17364 | 22:55:14 | 8.0 | 36.9 | 28.903 | consistent |
| 8056 | 22:55:42 | 6.0 | 16.4 | 10.415 | consistent |
| 8177 | 22:55:44 | 15.0 | 39.3 | 24.261 | consistent |
| 17364 | 22:55:51 | 8.0 | 29.2 | 21.24 | consistent |
| 8056 | 22:55:58 | 6.0 | 19.5 | 13.471 | consistent |
| 8177 | 22:57:19 | 15.0 | 16.9 | 1.872 | consistent |
| 8177 | 22:57:36 | 15.0 | 34.3 | 19.288 | consistent |
| 17364 | 22:58:17 | 8.0 | 8.0 | 0.019 | consistent |
| 17364 | 22:58:25 | 8.0 | 26.5 | 18.498 | consistent |
| 8056 | 22:59:52 | 6.0 | 22.3 | 16.253 | consistent |
| 8056 | 23:00:15 | 6.0 | 8.2 | 2.225 | consistent |
| 17364 | 23:00:20 | 8.0 | 15.5 | 7.517 | consistent |
| 8056 | 23:00:23 | 6.0 | 7.4 | 1.392 | consistent |
| 8056 | 23:00:30 | 6.0 | 22.1 | 16.079 | consistent |
| 17364 | 23:00:35 | 8.0 | 25.3 | 17.332 | consistent |
| 17364 | 23:01:01 | 8.0 | 31.1 | 23.068 | consistent |
| 8056 | 23:01:30 | 6.0 | 35.6 | 29.603 | consistent |
| 17364 | 23:01:32 | 8.0 | 35.5 | 27.519 | consistent |
| 17364 | 23:02:07 | 8.0 | 14.5 | 6.54 | consistent |
| 8052 | 23:03:15 | 6.0 | 25.4 | 19.375 | consistent |
| 8177 | 23:04:25 | 15.0 | 16.8 | 1.822 | consistent |
| 8056 | 23:04:26 | 6.0 | 29.7 | 23.739 | consistent |
| 8177 | 23:04:41 | 15.0 | 40.4 | 25.374 | consistent |
| 8056 | 23:04:56 | 6.0 | 22.9 | 16.891 | consistent |
| 17364 | 23:04:57 | 8.0 | 22.9 | 14.873 | consistent |
| 8056 | 23:05:19 | 6.0 | 25.5 | 19.509 | consistent |
| 17364 | 23:05:20 | 8.0 | 17.5 | 9.465 | consistent |
| 8177 | 23:05:22 | 15.0 | 32.3 | 17.324 | consistent |
| 17364 | 23:05:37 | 8.0 | 9.6 | 1.583 | consistent |
| 8056 | 23:08:40 | 6.0 | 6.3 | 0.271 | consistent |

## Enemy cast bars: live duration model vs log

- log NPC casts: 104; predicted: 0; mean abs error None s; within 150 ms: 0

## Overheal estimate vs log

- heals 165, estimated 165, exact 136, overheal yes/no correct 141, mean abs error 5.8

## Ledger (cached clear facts) vs log

- aura claims (live / cached-fresh / cached-stale) vs log: {}; by confidence: {}
- 'maybe-removed' entries are doubts, never claims: removalConfirmed = the log shows the aura really was gone, stillPresent = the doubt was unnecessary
- token->GUID resolutions: {'n': 337, 'wrong': 258, 'correct': 79}
- ledger stats: {'evicted': 0, 'invalidated': 0, 'stale': 0, 'puts': 930, 'live': 0, 'fresh': 0, 'miss': 1}

## Live verdicts (verify ring, replayed)

| kind | V | C | U | X |
|---|---|---|---|---|
| cand-heal:c-cad-amount | 3 | 1 | 14 | 0 |
| cand-heal:c-cad-guard | 3 | 1 | 14 | 0 |
| cand-heal:c-cad-phase | 3 | 1 | 14 | 0 |
| cand-heal:c-cad-phase-amount | 3 | 1 | 14 | 0 |
| cand-heal:c-cad-tight | 4 | 1 | 13 | 0 |
| cand-heal:c-heal-me-wide | 4 | 1 | 13 | 0 |
| cand-heal:c-heal-tgt-frame | 3 | 0 | 15 | 0 |
| cand-heal:c-heal-tgt-totem | 4 | 1 | 13 | 0 |
| cand-heal:c-heal-tgt-wide | 3 | 0 | 15 | 0 |
| cand:c-aura-me-elim | 0 | 0 | 0 | 0 |
| cand:c-aura-me-self | 0 | 0 | 0 | 0 |
| cand:c-aura-me-tight | 0 | 0 | 0 | 0 |
| cand:c-cad-amount | 0 | 0 | 0 | 0 |
| cand:c-cad-guard | 0 | 0 | 0 | 0 |
| cand:c-cad-phase | 0 | 0 | 0 | 0 |
| cand:c-cad-phase-amount | 0 | 0 | 0 | 0 |
| cand:c-cad-tight | 0 | 0 | 0 | 0 |
| cand:c-heal-me-wide | 0 | 0 | 0 | 0 |
| cand:c-heal-tgt-frame | 0 | 0 | 0 | 0 |
| cand:c-heal-tgt-totem | 0 | 0 | 0 | 0 |
| cand:c-heal-tgt-wide | 0 | 0 | 0 | 0 |
| cand:c-int-wide | 0 | 0 | 0 | 0 |
| cd-ready | 40 | 3 | 11 | 0 |
| cooldown | 358 | 0 | 361 | 0 |
| damage-range | 23 | 0 | 0 | 0 |
| dm-damage | 3 | 0 | 15 | 0 |
| dm-dispels | 0 | 0 | 18 | 0 |
| dm-healing | 4 | 1 | 13 | 0 |
| dm-interrupts | 18 | 0 | 0 | 0 |
| dm-taken | 0 | 0 | 18 | 0 |
| gcd | 3 | 17 | 3 | 0 |
| interrupt-attribution | 0 | 0 | 1 | 0 |

## Unreadable rule inputs (Inference.inputs, u > 0)

- combat: aura.addedAuras r0/u600, aura.count r0/u1314, totem.duration r0/u40, totem.haveTotem r0/u40, totem.name r0/u40, totem.startTime r0/u40, unitCast.castGUID r0/u123, unitCast.spellID r0/u123
- restricted: aura.addedAuras r0/u475, aura.count r6/u880, playerCast.castGUID r121/u1, totem.duration r0/u28, totem.haveTotem r0/u28, totem.name r0/u28, totem.startTime r0/u28, unitCast.castGUID r3/u81, unitCast.spellID r3/u81
