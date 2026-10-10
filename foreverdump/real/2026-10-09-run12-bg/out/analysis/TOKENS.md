# TOKENS: unit token matrix per context / instance type

Discovery scanner (Tokens.lua `T.Scan`): every token family (player/pet/target/focus/mouseover/soft*, party1-4, raid1-40, arena1-5, boss1-8, nameplate1-40, plus `target` / `targettarget` chains) is read round-robin under a per-slice time budget. Codes: C clear, S secret, N nil, T secret table, K table, E error; `*` = mixed (dominant share < 100%). Re-verified every capture against the stored baseline; a changed dominant code is a change alert.

## build 70291

### instance `pvp`, group `raid`

| state | family | exists | guid | name | class | level | health | healthMax | power | isPlayer | reaction | canAttack | isMe | isTarget | dead | combat | idSecret |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| restricted | arenaN | C | C* | C | C* | C | S | S* | S | C | C | C | C | C | C | C | C |
| restricted | arenaNtarget | C | S* | C | S* | C | S | S* | S | C | C | C | S* | S* | C | C | C |
| restricted | arenaNtargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | arenapetN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | bossN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | bossNtarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | focus | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | focustarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | focustargettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | mouseover | C | C* | C* | C* | C | S | S | S* | C | C* | C | C | C | C | C | C |
| restricted | mouseovertarget | C | S* | S* | S* | C | S | S | S* | C | C* | C | S* | S* | C | C | C |
| restricted | nameplateN | C | S | C* | S | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | nameplateNtarget | C | S | C* | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | npc | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | partyN | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | partyNtarget | C | S* | C* | S* | C | S | S | S* | C | C* | C | S* | S* | C | C | C |
| restricted | partyNtargettarget | C | S* | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | partypetN | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | partypetNtarget | C | S | S* | S | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | partypetNtargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | pet | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | pettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | player | C | C | C | C | C | S | C | S | C | C | C | C | C | C | C | C |
| restricted | playertarget | C | S* | C* | S* | C | S | S* | S | C | C* | C | S* | S* | C | C | C |
| restricted | playertargettarget | C | S | C | S | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | raidN | C | C | C | C | C | S | S* | S | C | C | C | C | C | C | C | C |
| restricted | raidNtarget | C | S* | C* | S* | C | S | S* | S | C | C* | C | S* | S* | C | C | C |
| restricted | raidNtargettarget | C | S* | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | raidpetN | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | raidpetNtarget | C | S | C* | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | raidpetNtargettarget | C | S | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | softenemy | C | S | S | S | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | softenemytarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | softenemytargettarget | C | S | C* | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | softfriend | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | softfriendtarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | softinteract | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | target | C | S* | C* | S* | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | targettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | targettargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | vehicle | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |

### Scan cost per capture

| capture start | ms | slices | tokens | reads | existing | sweeps | sweep s | max slice ms | over budget | budget | list | contexts |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1791566223 | 443.04 | 5071 | 7480 | 39240 | 1697 | 15 | 3.65 | 0.342 | 44 | 0.12 | 303 | restricted/pvp/raid 15 |

### Same unit on several tokens (dedupe pairs)

- `raidNtarget=raidNtargettarget`: 79
- `raidN=raidNtarget`: 76
- `partyNtarget=raidNtarget`: 60
- `player=raidN`: 20
- `partyNtargettarget=raidNtarget`: 17
- `partyN=raidN`: 15
- `partyN=partyNtarget`: 13
- `partyNtarget=partyNtargettarget`: 12
- `partyNtarget=raidN`: 9
- `partyNtargettarget=raidNtargettarget`: 6
- `mouseover=partyN`: 4
- `partyNtarget=raidNtargettarget`: 4
- `mouseover=raidNtarget`: 3
- `partypetN=raidpetN`: 3
- `arenaN=arenaNtarget`: 2
- `partyN=raidNtarget`: 2
- `mouseover=raidN`: 2
- `mouseover=mouseovertarget`: 2
- `playertarget=raidNtarget`: 2
- `partyNtargettarget=raidN`: 2
- `mouseover=partyNtarget`: 1
- `arenaN=player`: 1
- `arenaN=raidNtarget`: 1
- `raidN=raidNtargettarget`: 1
- `mouseovertarget=raidN`: 1
- `mouseovertarget=partyNtarget`: 1

### Secret-GUID tokens resolved by alias (shared cast / castGUID)

- `targettarget<-raidN:frame`: 2
- `targettarget<-raidN:castGUID`: 2
- `softfriend<-raidN:frame`: 1
- `arenaN<-raidN:castGUID`: 1
- `target<-raidN:frame`: 1
- `nameplateN<-raidN:frame`: 1

## Change alerts

none (first capture with the scanner sets the baseline)

## One-shot token survey (v2.2 TokenSurvey, out of combat)

| family | token works? | identity secret when? | values secret when? |
|---|---|---|---|
| nameplate | no unit seen (token valid, nothing to resolve) | - | - |
| targettargettarget | no unit seen (token valid, nothing to resolve) | - | - |
| npc | no unit seen (token valid, nothing to resolve) | - | - |
| party | restricted: 4/4 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| boss | no unit seen (token valid, nothing to resolve) | - | - |
| focus | no unit seen (token valid, nothing to resolve) | - | - |
| target | no unit seen (token valid, nothing to resolve) | - | - |
| vehicle | no unit seen (token valid, nothing to resolve) | - | - |
| pettarget | no unit seen (token valid, nothing to resolve) | - | - |
| softinteract | no unit seen (token valid, nothing to resolve) | - | - |
| arena1target | no unit seen (token valid, nothing to resolve) | - | - |
| raid1target | no unit seen (token valid, nothing to resolve) | - | - |
| party1target | restricted: 1/1 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| softfriend | no unit seen (token valid, nothing to resolve) | - | - |
| targettarget | no unit seen (token valid, nothing to resolve) | - | - |
| focustarget | no unit seen (token valid, nothing to resolve) | - | - |
| pet | no unit seen (token valid, nothing to resolve) | - | - |
| partypet | restricted: 1/4 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| mouseovertarget | no unit seen (token valid, nothing to resolve) | - | - |
| player | restricted: 1/1 resolved | restricted: clear | restricted: secret (UnitHealth) |
| mouseover | no unit seen (token valid, nothing to resolve) | - | - |
| raidpet | restricted: 3/40 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| raid | restricted: 13/40 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| arena | no unit seen (token valid, nothing to resolve) | - | - |
| focustargettarget | no unit seen (token valid, nothing to resolve) | - | - |
| softenemy | no unit seen (token valid, nothing to resolve) | - | - |

