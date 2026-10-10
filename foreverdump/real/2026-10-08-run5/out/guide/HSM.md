# Hybrid state machine (HSM) - predictions vs ground truth

Per prediction kind and context: aura presence %, duration error, damage/heal within the predicted range %,
cooldown timing error; then the failure cases. The library is ForeverDump/Lib/HybridState.lua (reusable).

## Live HSM (addon capture)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 14 | 5 | 3 | 6 | 62.5% | - |
| amount | ooc | 1 | 0 | 0 | 1 | - | - |
| aura | combat | 12 | 7 | 5 | 0 | 58.3% | 167.9 |
| aura | ooc | 1 | 1 | 0 | 0 | 100.0% | 598.06 |
| cooldown | combat | 12 | 2 | 0 | 10 | 100.0% | 1.66 |
| dispel | combat | 1 | 0 | 0 | 1 | - | - |
| summon | combat | 3 | 3 | 0 | 0 | 100.0% | - |
| summon | ooc | 3 | 3 | 0 | 0 | 100.0% | - |

Failure cases: removed-early (dispel/cancel/death) x3, haste/duration-modifier x3, crit x3, resist/miss:RESIST x2, dispel: nothing removed (no dispellable effect / resisted) x1, resist/miss:MISS x1

## Offline replay on the file log (clear mode, 248 events, knowledge learned online while values were readable)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 19 | 12 | 4 | 3 | 75.0% | - |
| amount | ooc | 1 | 1 | 0 | 0 | 100.0% | - |
| aura | combat | 15 | 14 | 1 | 0 | 93.3% | 10.28 |
| aura | ooc | 2 | 2 | 0 | 0 | 100.0% | 22.02 |
| cooldown | combat | 35 | 1 | 7 | 27 | 12.5% | 12.94 |
| cooldown | ooc | 3 | 0 | 0 | 3 | - | - |

Failure cases: removed-early (dispel/cancel/death) x7, recast-before-predicted-cooldown-end (cd reset/haste) x7, longer-than-predicted x3, crit x3, resist/miss:RESIST x2, refresh x1, haste/duration-modifier x1, resist/miss:MISS x1

## Offline replay on the file log (secret mode, 248 events, knowledge learned online while values were readable)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 19 | 12 | 4 | 3 | 75.0% | - |
| amount | ooc | 1 | 1 | 0 | 0 | 100.0% | - |
| aura | combat | 15 | 14 | 1 | 0 | 93.3% | 10.28 |
| aura | ooc | 2 | 2 | 0 | 0 | 100.0% | 22.02 |
| cooldown | combat | 35 | 1 | 7 | 27 | 12.5% | 12.94 |
| cooldown | ooc | 3 | 0 | 0 | 3 | - | - |

Failure cases: removed-early (dispel/cancel/death) x7, recast-before-predicted-cooldown-end (cd reset/haste) x7, longer-than-predicted x3, crit x3, resist/miss:RESIST x2, refresh x1, haste/duration-modifier x1, resist/miss:MISS x1

## Offline replay on the file log (secret-pretrained mode, 207 events, spell knowledge given up front, as if cached out of combat by Knowledge.lua)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 26 | 16 | 7 | 3 | 69.6% | - |
| amount | ooc | 1 | 1 | 0 | 0 | 100.0% | - |
| aura | combat | 21 | 17 | 4 | 0 | 81.0% | 8.47 |
| aura | ooc | 5 | 5 | 0 | 0 | 100.0% | 8.83 |
| cooldown | combat | 47 | 14 | 0 | 33 | 100.0% | 2.75 |
| cooldown | ooc | 6 | 1 | 0 | 5 | 100.0% | 0.01 |
| summon | combat | 15 | 15 | 0 | 0 | 100.0% | - |
| summon | ooc | 4 | 4 | 0 | 0 | 100.0% | - |

Failure cases: removed-early (dispel/cancel/death) x7, crit x7, longer-than-predicted x3, resist/miss:RESIST x2, refresh x1, haste/duration-modifier x1, resist/miss:MISS x1

Notes: only the log owner's casts and auras are known in a file log; in Forever, UNIT_AURA only fires for unit
tokens (player/target/focus/party/nameplates), so the replay is an upper bound for other units.

