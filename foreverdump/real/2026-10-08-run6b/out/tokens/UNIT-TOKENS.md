# Unit token survey

Per token family (not per index), once per capture context. One-glance answer first, details below.

| family | token works? | identity secret when? | values secret when? |
|---|---|---|---|
| nameplate | ooc: 1/40 resolved; combat: 1/40 resolved | ooc: clear; combat: clear | ooc: secret (UnitHealth,UnitHealthMax); combat: secret (UnitHealth,UnitHealthMax) |
| targettargettarget | combat: 1/1 resolved | combat: clear | combat: secret (UnitHealth,UnitHealthMax) |
| npc | no unit seen (token valid, nothing to resolve) | - | - |
| party | no unit seen (token valid, nothing to resolve) | - | - |
| softenemy | combat: 1/1 resolved | combat: clear | combat: secret (UnitHealth,UnitHealthMax) |
| focus | no unit seen (token valid, nothing to resolve) | - | - |
| target | combat: 1/1 resolved | combat: clear | combat: secret (UnitHealth,UnitHealthMax) |
| vehicle | no unit seen (token valid, nothing to resolve) | - | - |
| raid1target | no unit seen (token valid, nothing to resolve) | - | - |
| softinteract | no unit seen (token valid, nothing to resolve) | - | - |
| party1target | no unit seen (token valid, nothing to resolve) | - | - |
| raid | no unit seen (token valid, nothing to resolve) | - | - |
| raidpet | no unit seen (token valid, nothing to resolve) | - | - |
| mouseover | no unit seen (token valid, nothing to resolve) | - | - |
| pet | no unit seen (token valid, nothing to resolve) | - | - |
| arena1target | no unit seen (token valid, nothing to resolve) | - | - |
| pettarget | no unit seen (token valid, nothing to resolve) | - | - |
| partypet | no unit seen (token valid, nothing to resolve) | - | - |
| mouseovertarget | no unit seen (token valid, nothing to resolve) | - | - |
| player | ooc: 1/1 resolved; combat: 1/1 resolved | ooc: clear; combat: clear | ooc: secret (UnitHealth); combat: secret (UnitHealth) |
| focustarget | no unit seen (token valid, nothing to resolve) | - | - |
| targettarget | combat: 1/1 resolved | combat: clear | combat: secret (UnitHealth) |
| softfriend | no unit seen (token valid, nothing to resolve) | - | - |
| arena | no unit seen (token valid, nothing to resolve) | - | - |
| focustargettarget | no unit seen (token valid, nothing to resolve) | - | - |
| boss | no unit seen (token valid, nothing to resolve) | - | - |

## Details (codes for existing units; `none:` = a non-existent token of that family)

| family | ctx | resolved | UnitExists | UnitGUID | UnitName | UnitIsUnit(player) | UnitIsUnit(target) | UnitCanAttack | UnitIsPlayer | UnitHealth | UnitHealthMax | CanCompareUnitTokens | ShouldUnitIdentityBeSecret |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| nameplate | ooc | 1/40 | C none:C | C none:N | C none:N | C none:C | C none:C | C none:C | C none:C | S none:S | S none:S | C none:C | C none:C |
| nameplate | combat | 1/40 | C none:C | C none:N | C none:N | C none:C | C none:C | C none:C | C none:C | S none:S | S none:S | C none:C | C none:C |
| targettargettarget | ooc | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| targettargettarget | combat | 1/1 | C | C | C | C | C | C | C | S | S | C | C |
| npc | ooc | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| npc | combat | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| party | ooc | 0/4 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| party | combat | 0/4 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| softenemy | ooc | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| softenemy | combat | 1/1 | C | C | C | C | C | C | C | S | S | C | C |
| focus | ooc | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| focus | combat | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| target | ooc | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| target | combat | 1/1 | C | C | C | C | C | C | C | S | S | C | C |
| vehicle | ooc | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| vehicle | combat | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| raid1target | ooc | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| raid1target | combat | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| softinteract | ooc | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| softinteract | combat | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| party1target | ooc | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| party1target | combat | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| raid | ooc | 0/40 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| raid | combat | 0/40 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| raidpet | ooc | 0/40 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| raidpet | combat | 0/40 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| mouseover | ooc | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| mouseover | combat | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| pet | ooc | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| pet | combat | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| arena1target | ooc | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| arena1target | combat | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| pettarget | ooc | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| pettarget | combat | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| partypet | ooc | 0/4 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| partypet | combat | 0/4 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| mouseovertarget | ooc | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| mouseovertarget | combat | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| player | ooc | 1/1 | C | C | C | C | C | C | C | S | C | C | C |
| player | combat | 1/1 | C | C | C | C | C | C | C | S | C | C | C |
| focustarget | ooc | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| focustarget | combat | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| targettarget | ooc | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| targettarget | combat | 1/1 | C | C | C | C | C | C | C | S | C | C | C |
| softfriend | ooc | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| softfriend | combat | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| arena | ooc | 0/5 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| arena | combat | 0/5 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| focustargettarget | ooc | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| focustargettarget | combat | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| boss | ooc | 0/8 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| boss | combat | 0/8 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
