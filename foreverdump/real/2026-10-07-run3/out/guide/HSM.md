# Hybrid state machine (HSM) - predictions vs ground truth

Per prediction kind and context: aura presence %, duration error, damage/heal within the predicted range %,
cooldown timing error; then the failure cases. The library is ForeverDump/Lib/HybridState.lua (reusable).

## Live HSM (addon capture)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 5 | 1 | 0 | 4 | 100.0% | - |
| aura | combat | 4 | 0 | 4 | 0 | 0.0% | - |
| cooldown | combat | 2 | 0 | 0 | 2 | - | - |

Failure cases: none

## Offline replay on the file log (clear mode, 133 events, knowledge learned online while values were readable)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 6 | 6 | 0 | 0 | 100.0% | - |
| aura | combat | 5 | 5 | 0 | 0 | 100.0% | 13.35 |
| aura | ooc | 1 | 1 | 0 | 0 | 100.0% | 7.88 |
| cooldown | combat | 13 | 0 | 3 | 10 | 0.0% | 15.3 |
| cooldown | ooc | 1 | 0 | 0 | 1 | - | - |

Failure cases: removed-early (dispel/cancel/death) x3, recast-before-predicted-cooldown-end (cd reset/haste) x3, longer-than-predicted x2, refresh x1

## Offline replay on the file log (secret mode, 133 events, knowledge learned online while values were readable)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 6 | 6 | 0 | 0 | 100.0% | - |
| aura | combat | 5 | 5 | 0 | 0 | 100.0% | 13.35 |
| aura | ooc | 1 | 1 | 0 | 0 | 100.0% | 7.88 |
| cooldown | combat | 13 | 0 | 3 | 10 | 0.0% | 15.3 |
| cooldown | ooc | 1 | 0 | 0 | 1 | - | - |

Failure cases: removed-early (dispel/cancel/death) x3, recast-before-predicted-cooldown-end (cd reset/haste) x3, longer-than-predicted x2, refresh x1

## Offline replay on the file log (secret-pretrained mode, 119 events, spell knowledge given up front, as if cached out of combat by Knowledge.lua)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 10 | 8 | 2 | 0 | 80.0% | - |
| aura | combat | 6 | 6 | 0 | 0 | 100.0% | 11.13 |
| aura | ooc | 4 | 4 | 0 | 0 | 100.0% | 1.99 |
| cooldown | combat | 19 | 8 | 0 | 11 | 100.0% | 2.18 |
| cooldown | ooc | 3 | 0 | 0 | 3 | - | - |
| summon | combat | 6 | 6 | 0 | 0 | 100.0% | - |
| summon | ooc | 1 | 1 | 0 | 0 | 100.0% | - |

Failure cases: removed-early (dispel/cancel/death) x3, crit x2, longer-than-predicted x2, refresh x1

Notes: only the log owner's casts and auras are known in a file log; in Forever, UNIT_AURA only fires for unit
tokens (player/target/focus/party/nameplates), so the replay is an upper bound for other units.

