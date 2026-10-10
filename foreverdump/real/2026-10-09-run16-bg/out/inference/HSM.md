# Hybrid state machine (HSM) - predictions vs ground truth

Per prediction kind and context: aura presence %, duration error, damage/heal within the predicted range %,
cooldown timing error; then the failure cases. The library is ForeverDump/Lib/HybridState.lua (reusable).

## Live HSM (addon capture)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 43 | 22 | 15 | 6 | 59.5% | - |
| amount | ooc | 10 | 4 | 1 | 5 | 80.0% | - |
| aura | combat | 49 | 44 | 5 | 0 | 89.8% | 15.81 |
| aura | ooc | 5 | 5 | 0 | 0 | 100.0% | 533.74 |
| cooldown | combat | 68 | 10 | 0 | 58 | 100.0% | 3.27 |
| cooldown | ooc | 1 | 0 | 0 | 1 | - | - |
| dispel | combat | 19 | 14 | 0 | 5 | 100.0% | - |
| summon | combat | 28 | 28 | 0 | 0 | 100.0% | - |
| summon | ooc | 10 | 10 | 0 | 0 | 100.0% | - |

Failure cases: removed-early (dispel/cancel/death) x25, dispel: nothing removed (no dispellable effect / resisted) x5, resist/miss:ABSORB x3, crit x2, resist/miss:MISS x2, refresh x1

## Offline replay on the file log (clear mode, 591 events, knowledge learned online while values were readable)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 56 | 32 | 15 | 9 | 68.1% | - |
| amount | ooc | 4 | 1 | 3 | 0 | 25.0% | - |
| aura | combat | 58 | 53 | 5 | 0 | 91.4% | 19.72 |
| aura | ooc | 12 | 12 | 0 | 0 | 100.0% | 38.45 |
| cooldown | combat | 105 | 20 | 25 | 60 | 44.4% | 13.01 |
| cooldown | ooc | 27 | 1 | 3 | 23 | 25.0% | 20.42 |

Failure cases: removed-early (dispel/cancel/death) x31, recast-before-predicted-cooldown-end (cd reset/haste) x28, longer-than-predicted x15, resist/miss:ABSORB x5, resist/miss:MISS x3, crit x2, haste/duration-modifier x2, resist/miss:PARRY x1

## Offline replay on the file log (secret mode, 591 events, knowledge learned online while values were readable)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 56 | 32 | 15 | 9 | 68.1% | - |
| amount | ooc | 4 | 1 | 3 | 0 | 25.0% | - |
| aura | combat | 58 | 53 | 5 | 0 | 91.4% | 19.72 |
| aura | ooc | 12 | 12 | 0 | 0 | 100.0% | 38.45 |
| cooldown | combat | 105 | 20 | 25 | 60 | 44.4% | 13.01 |
| cooldown | ooc | 27 | 1 | 3 | 23 | 25.0% | 20.42 |

Failure cases: removed-early (dispel/cancel/death) x31, recast-before-predicted-cooldown-end (cd reset/haste) x28, longer-than-predicted x15, resist/miss:ABSORB x5, resist/miss:MISS x3, crit x2, haste/duration-modifier x2, resist/miss:PARRY x1

## Offline replay on the file log (secret-pretrained mode, 493 events, spell knowledge given up front, as if cached out of combat by Knowledge.lua)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 60 | 50 | 1 | 9 | 98.0% | - |
| amount | ooc | 5 | 4 | 1 | 0 | 80.0% | - |
| aura | combat | 63 | 58 | 5 | 0 | 92.1% | 17.9 |
| aura | ooc | 17 | 17 | 0 | 0 | 100.0% | 28.05 |
| cooldown | combat | 120 | 32 | 13 | 75 | 71.1% | 6.35 |
| cooldown | ooc | 30 | 2 | 3 | 25 | 40.0% | 1.79 |
| summon | combat | 28 | 28 | 0 | 0 | 100.0% | - |
| summon | ooc | 10 | 10 | 0 | 0 | 100.0% | - |

Failure cases: removed-early (dispel/cancel/death) x31, longer-than-predicted x16, recast-before-predicted-cooldown-end (cd reset/haste) x16, resist/miss:ABSORB x5, resist/miss:MISS x3, crit x2, haste/duration-modifier x2, refresh x1, resist/miss:PARRY x1

Notes: only the log owner's casts and auras are known in a file log; in Forever, UNIT_AURA only fires for unit
tokens (player/target/focus/party/nameplates), so the replay is an upper bound for other units.

