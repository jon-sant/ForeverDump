# TOKENS: unit token matrix per context / instance type

Discovery scanner (Tokens.lua `T.Scan`): every token family (player/pet/target/focus/mouseover/soft*, party1-4, raid1-40, arena1-5, boss1-8, nameplate1-40, plus `target` / `targettarget` chains) is read round-robin under a per-slice time budget. Codes: C clear, S secret, N nil, T secret table, K table, E error; `*` = mixed (dominant share < 100%). Re-verified every capture against the stored baseline; a changed dominant code is a change alert.

_No scanner data in this dump (the scanner ships with v2.2.4; captures before it only have the one-shot survey below)._

## Change alerts

none (first capture with the scanner sets the baseline)

## One-shot token survey (v2.2 TokenSurvey, out of combat)

| family | token works? | identity secret when? | values secret when? |
|---|---|---|---|
| nameplate | combat: 1/40 resolved | combat: clear | combat: secret (UnitHealth,UnitHealthMax) |
| targettargettarget | combat: 1/1 resolved | combat: clear | combat: secret (UnitHealth,UnitHealthMax) |
| npc | no unit seen (token valid, nothing to resolve) | - | - |
| party | no unit seen (token valid, nothing to resolve) | - | - |
| boss | no unit seen (token valid, nothing to resolve) | - | - |
| focus | no unit seen (token valid, nothing to resolve) | - | - |
| target | combat: 1/1 resolved | combat: clear | combat: secret (UnitHealth,UnitHealthMax) |
| vehicle | no unit seen (token valid, nothing to resolve) | - | - |
| pettarget | no unit seen (token valid, nothing to resolve) | - | - |
| softinteract | no unit seen (token valid, nothing to resolve) | - | - |
| arena1target | no unit seen (token valid, nothing to resolve) | - | - |
| raid1target | no unit seen (token valid, nothing to resolve) | - | - |
| party1target | no unit seen (token valid, nothing to resolve) | - | - |
| softfriend | no unit seen (token valid, nothing to resolve) | - | - |
| targettarget | combat: 1/1 resolved | combat: clear | combat: secret (UnitHealth) |
| focustarget | no unit seen (token valid, nothing to resolve) | - | - |
| pet | no unit seen (token valid, nothing to resolve) | - | - |
| partypet | no unit seen (token valid, nothing to resolve) | - | - |
| mouseovertarget | no unit seen (token valid, nothing to resolve) | - | - |
| player | ooc: 1/1 resolved; combat: 1/1 resolved | ooc: clear; combat: clear | ooc: secret (UnitHealth); combat: secret (UnitHealth) |
| mouseover | no unit seen (token valid, nothing to resolve) | - | - |
| raidpet | no unit seen (token valid, nothing to resolve) | - | - |
| raid | no unit seen (token valid, nothing to resolve) | - | - |
| arena | no unit seen (token valid, nothing to resolve) | - | - |
| focustargettarget | no unit seen (token valid, nothing to resolve) | - | - |
| softenemy | combat: 1/1 resolved | combat: clear | combat: secret (UnitHealth,UnitHealthMax) |

