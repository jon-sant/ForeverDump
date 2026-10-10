# Unit token survey

Per token family (not per index), once per capture context. One-glance answer first, details below.

| family | token works? | identity secret when? | values secret when? |
|---|---|---|---|
| nameplate | no unit seen (token valid, nothing to resolve) | - | - |
| targettargettarget | no unit seen (token valid, nothing to resolve) | - | - |
| npc | no unit seen (token valid, nothing to resolve) | - | - |
| party | restricted: 2/4 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| boss | no unit seen (token valid, nothing to resolve) | - | - |
| focus | no unit seen (token valid, nothing to resolve) | - | - |
| target | no unit seen (token valid, nothing to resolve) | - | - |
| vehicle | no unit seen (token valid, nothing to resolve) | - | - |
| pettarget | no unit seen (token valid, nothing to resolve) | - | - |
| softinteract | no unit seen (token valid, nothing to resolve) | - | - |
| arena1target | no unit seen (token valid, nothing to resolve) | - | - |
| raid1target | restricted: 1/1 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| party1target | no unit seen (token valid, nothing to resolve) | - | - |
| softfriend | no unit seen (token valid, nothing to resolve) | - | - |
| targettarget | no unit seen (token valid, nothing to resolve) | - | - |
| focustarget | no unit seen (token valid, nothing to resolve) | - | - |
| pet | no unit seen (token valid, nothing to resolve) | - | - |
| partypet | no unit seen (token valid, nothing to resolve) | - | - |
| mouseovertarget | no unit seen (token valid, nothing to resolve) | - | - |
| player | restricted: 1/1 resolved | restricted: clear | restricted: secret (UnitHealth) |
| mouseover | no unit seen (token valid, nothing to resolve) | - | - |
| raidpet | no unit seen (token valid, nothing to resolve) | - | - |
| raid | restricted: 13/40 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| arena | no unit seen (token valid, nothing to resolve) | - | - |
| focustargettarget | no unit seen (token valid, nothing to resolve) | - | - |
| softenemy | no unit seen (token valid, nothing to resolve) | - | - |

## Details (codes for existing units; `none:` = a non-existent token of that family)

| family | ctx | resolved | UnitExists | UnitGUID | UnitName | UnitIsUnit(player) | UnitIsUnit(target) | UnitCanAttack | UnitIsPlayer | UnitHealth | UnitHealthMax | CanCompareUnitTokens | ShouldUnitIdentityBeSecret |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| nameplate | restricted | 0/40 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| targettargettarget | restricted | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| npc | restricted | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| party | restricted | 2/4 | C none:C | C none:N | C none:N | C none:C | C none:C | C none:C | C none:C | S none:S | S none:S | C none:C | C none:C |
| boss | restricted | 0/8 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| focus | restricted | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| target | restricted | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| vehicle | restricted | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| pettarget | restricted | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| softinteract | restricted | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| arena1target | restricted | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| raid1target | restricted | 1/1 | C | C | C | C | C | C | C | S | S | C | C |
| party1target | restricted | 0/1 | none:C | none:S | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| softfriend | restricted | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| targettarget | restricted | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| focustarget | restricted | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| pet | restricted | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| partypet | restricted | 0/4 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| mouseovertarget | restricted | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| player | restricted | 1/1 | C | C | C | C | C | C | C | S | C | C | C |
| mouseover | restricted | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| raidpet | restricted | 0/40 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| raid | restricted | 13/40 | C none:C | C none:N | C none:N | C none:C | C none:C | C none:C | C none:C | S none:S | S* none:S | C none:C | C none:C |
| arena | restricted | 0/5 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| focustargettarget | restricted | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
| softenemy | restricted | 0/1 | none:C | none:N | none:N | none:C | none:C | none:C | none:C | none:S | none:S | none:C | none:C |
