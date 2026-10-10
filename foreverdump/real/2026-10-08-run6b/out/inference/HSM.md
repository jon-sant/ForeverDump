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

## Offline replay on the file log (clear mode, 64 events, knowledge learned online while values were readable)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 7 | 5 | 2 | 0 | 71.4% | - |
| aura | combat | 3 | 3 | 0 | 0 | 100.0% | 0.98 |
| cooldown | combat | 6 | 0 | 0 | 6 | - | - |

Failure cases: removed-early (dispel/cancel/death) x1, crit x1

## Offline replay on the file log (secret mode, 64 events, knowledge learned online while values were readable)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 7 | 5 | 2 | 0 | 71.4% | - |
| aura | combat | 3 | 3 | 0 | 0 | 100.0% | 0.98 |
| cooldown | combat | 6 | 0 | 0 | 6 | - | - |

Failure cases: removed-early (dispel/cancel/death) x1, crit x1

## Offline replay on the file log (secret-pretrained mode, 50 events, spell knowledge given up front, as if cached out of combat by Knowledge.lua)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 9 | 8 | 1 | 0 | 88.9% | - |
| aura | combat | 5 | 5 | 0 | 0 | 100.0% | 0.51 |
| aura | ooc | 1 | 1 | 0 | 0 | 100.0% | 0.03 |
| cooldown | combat | 13 | 5 | 0 | 8 | 100.0% | 0.0 |
| summon | combat | 2 | 2 | 0 | 0 | 100.0% | - |

Failure cases: removed-early (dispel/cancel/death) x1, crit x1

Notes: only the log owner's casts and auras are known in a file log; in Forever, UNIT_AURA only fires for unit
tokens (player/target/focus/party/nameplates), so the replay is an upper bound for other units.

