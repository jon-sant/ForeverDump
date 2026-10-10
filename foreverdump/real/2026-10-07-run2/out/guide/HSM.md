# Hybrid state machine (HSM) - predictions vs ground truth

Per prediction kind and context: aura presence %, duration error, damage/heal within the predicted range %,
cooldown timing error; then the failure cases. The library is ForeverDump/Lib/HybridState.lua (reusable).

## Offline replay on the file log (clear mode, 65 events, knowledge learned online while values were readable)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 2 | 2 | 0 | 0 | 100.0% | - |
| aura | ooc | 1 | 1 | 0 | 0 | 100.0% | 7.88 |
| cooldown | combat | 1 | 1 | 0 | 0 | 100.0% | 19.15 |

Failure cases: removed-early (dispel/cancel/death) x1

## Offline replay on the file log (secret mode, 65 events, knowledge learned online while values were readable)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 2 | 2 | 0 | 0 | 100.0% | - |
| aura | ooc | 1 | 1 | 0 | 0 | 100.0% | 7.88 |
| cooldown | combat | 1 | 1 | 0 | 0 | 100.0% | 19.15 |

Failure cases: removed-early (dispel/cancel/death) x1

## Offline replay on the file log (secret-pretrained mode, 60 events, spell knowledge given up front, as if cached out of combat by Knowledge.lua)

| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |
|---|---|---|---|---|---|---|---|
| amount | combat | 4 | 3 | 1 | 0 | 75.0% | - |
| aura | combat | 1 | 1 | 0 | 0 | 100.0% | 0.01 |
| aura | ooc | 4 | 4 | 0 | 0 | 100.0% | 1.99 |
| cooldown | combat | 3 | 3 | 0 | 0 | 100.0% | 6.38 |
| cooldown | ooc | 1 | 1 | 0 | 0 | 100.0% | 0.01 |

Failure cases: removed-early (dispel/cancel/death) x1, crit x1

Notes: only the log owner's casts and auras are known in a file log; in Forever, UNIT_AURA only fires for unit
tokens (player/target/focus/party/nameplates), so the replay is an upper bound for other units.

