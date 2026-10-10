# Hybrid state machine (HSM) - predictions vs ground truth

Per prediction kind and context: aura presence %, duration error, damage/heal within the predicted range %,
cooldown timing error; then the failure cases. The library is ForeverDump/Lib/HybridState.lua (reusable).

## Live HSM (addon capture)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|

Failure cases: none

## Offline replay on the file log (clear mode, 162 events, knowledge learned online while values were readable)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 7 | 6 | 1 | 0 | 85.7% | - |
| aura | combat | 9 | 9 | 0 | 0 | 100.0% | 11.75 |
| aura | ooc | 1 | 1 | 0 | 0 | 100.0% | 7.88 |
| cooldown | combat | 18 | 0 | 3 | 15 | 0.0% | 15.3 |
| cooldown | ooc | 1 | 0 | 0 | 1 | - | - |

Failure cases: removed-early (dispel/cancel/death) x4, recast-before-predicted-cooldown-end (cd reset/haste) x3, longer-than-predicted x3, refresh x1, crit x1

## Offline replay on the file log (secret mode, 162 events, knowledge learned online while values were readable)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 7 | 6 | 1 | 0 | 85.7% | - |
| aura | combat | 9 | 9 | 0 | 0 | 100.0% | 11.75 |
| aura | ooc | 1 | 1 | 0 | 0 | 100.0% | 7.88 |
| cooldown | combat | 18 | 0 | 3 | 15 | 0.0% | 15.3 |
| cooldown | ooc | 1 | 0 | 0 | 1 | - | - |

Failure cases: removed-early (dispel/cancel/death) x4, recast-before-predicted-cooldown-end (cd reset/haste) x3, longer-than-predicted x3, refresh x1, crit x1

## Offline replay on the file log (secret-pretrained mode, 145 events, spell knowledge given up front, as if cached out of combat by Knowledge.lua)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 11 | 8 | 3 | 0 | 72.7% | - |
| aura | combat | 10 | 10 | 0 | 0 | 100.0% | 10.44 |
| aura | ooc | 4 | 4 | 0 | 0 | 100.0% | 1.99 |
| cooldown | combat | 26 | 9 | 0 | 17 | 100.0% | 1.94 |
| cooldown | ooc | 3 | 0 | 0 | 3 | - | - |
| summon | combat | 12 | 12 | 0 | 0 | 100.0% | - |
| summon | ooc | 1 | 1 | 0 | 0 | 100.0% | - |

Failure cases: removed-early (dispel/cancel/death) x4, crit x3, longer-than-predicted x3, refresh x1

Notes: only the log owner's casts and auras are known in a file log; in Forever, UNIT_AURA only fires for unit
tokens (player/target/focus/party/nameplates), so the replay is an upper bound for other units.

