# Hybrid state machine (HSM) - predictions vs ground truth

Per prediction kind and context: aura presence %, duration error, damage/heal within the predicted range %,
cooldown timing error; then the failure cases. The library is ForeverDump/Lib/HybridState.lua (reusable).

## Live HSM (addon capture)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | ooc | 15 | 0 | 0 | 15 | - | - |
| aura | ooc | 13 | 0 | 13 | 0 | 0.0% | - |
| cooldown | ooc | 12 | 0 | 0 | 12 | - | - |
| dispel | ooc | 1 | 0 | 0 | 1 | - | - |
| summon | ooc | 6 | 0 | 6 | 0 | 0.0% | - |

Failure cases: dispel: nothing removed (no dispellable effect / resisted) x1

## Offline replay on the file log (clear mode, 23 events, knowledge learned online while values were readable)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 2 | 1 | 1 | 0 | 50.0% | - |
| aura | combat | 1 | 1 | 0 | 0 | 100.0% | 1.81 |
| cooldown | combat | 1 | 0 | 0 | 1 | - | - |

Failure cases: removed-early (dispel/cancel/death) x1, crit x1

## Offline replay on the file log (secret mode, 23 events, knowledge learned online while values were readable)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 2 | 1 | 1 | 0 | 50.0% | - |
| aura | combat | 1 | 1 | 0 | 0 | 100.0% | 1.81 |
| cooldown | combat | 1 | 0 | 0 | 1 | - | - |

Failure cases: removed-early (dispel/cancel/death) x1, crit x1

## Offline replay on the file log (secret-pretrained mode, 20 events, spell knowledge given up front, as if cached out of combat by Knowledge.lua)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 4 | 3 | 1 | 0 | 75.0% | - |
| aura | combat | 2 | 2 | 0 | 0 | 100.0% | 0.92 |
| cooldown | combat | 2 | 1 | 0 | 1 | 100.0% | 0.0 |

Failure cases: removed-early (dispel/cancel/death) x1, crit x1

Notes: only the log owner's casts and auras are known in a file log; in Forever, UNIT_AURA only fires for unit
tokens (player/target/focus/party/nameplates), so the replay is an upper bound for other units.

