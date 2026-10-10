# TOKENS: unit token matrix per context / instance type

Discovery scanner (Tokens.lua `T.Scan`): every token family (player/pet/target/focus/mouseover/soft*, party1-4, raid1-40, arena1-5, boss1-8, nameplate1-40, plus `target` / `targettarget` chains) is read round-robin under a per-slice time budget. Codes: C clear, S secret, N nil, T secret table, K table, E error; `*` = mixed (dominant share < 100%). Re-verified every capture against the stored baseline; a changed dominant code is a change alert.

## build 70334

### instance `pvp`, group `raid`

| state | family | exists | guid | name | class | level | health | healthMax | power | isPlayer | reaction | canAttack | isMe | isTarget | dead | combat | idSecret |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| combat | arenaNtarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | arenaNtargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | focus | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | focustarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | focustargettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | mouseover | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | mouseovertarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | nameplateN | C | S | C | S | C | S | S | S | C | C | C | C | C | C | C | C |
| combat | npc | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | partyNtarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | partyNtargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | pet | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | pettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | player | C | C | C | C | C | S | C | S | C | C | C | C | C | C | C | C |
| combat | playertarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | playertargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | raidN | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| combat | raidNtarget | C | S* | C | S* | C | S | S | S | C | C* | C | S* | S | C | C | C |
| combat | raidNtargettarget | C | S | C* | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | softenemy | C | S | C | S | C | S | S | S | C | C | C | C | C | C | C | C |
| combat | softenemytargettarget | - | - | - | - | - | - | - | - | - | - | - | - | - | C | C | C |
| combat | softfriend | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | softinteract | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | target | C | S | C | S | C | S | S | S | C | C | C | C | C | C | C | C |
| combat | targettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | targettargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | vehicle | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | arenaN | C | S* | C | S* | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | arenaNtarget | C | S | C* | S | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | arenaNtargettarget | C | S | C | S | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | arenapetN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | bossN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | bossNtarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | focus | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | focustarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | focustargettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | mouseover | C | C* | C* | C* | C | S | S* | S* | C | C* | C | C | C | C | C | C |
| restricted | mouseovertarget | C | S* | C* | S* | C | S | S* | S* | C | C* | C | C* | C* | C | C | C |
| restricted | nameplateN | C | S | C* | S* | C | S | S | S* | C | C* | C | C | C | C | C | C |
| restricted | nameplateNtarget | C | S* | C* | S* | C | S | S | S* | C | C* | C | S* | S* | C | C | C |
| restricted | npc | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | partyN | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | partyNtarget | C | S* | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | partyNtargettarget | C | S* | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | partypetN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | pet | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | pettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | player | C | C | C | C | C | S | C | S | C | C | C | C | C | C | C | C |
| restricted | playertarget | C | S* | C* | S* | C | S | S* | S | C | C* | C | S* | S* | C | C | C |
| restricted | playertargettarget | C | S* | C* | S* | C | S | S* | S | C | C* | C | S* | S* | C | C | C |
| restricted | raidN | C | C | C | C | C | S | S* | S | C | C | C | C | C | C | C | C |
| restricted | raidNtarget | C | S* | C* | S* | C | S | S* | S* | C | C* | C | S* | S* | C | C | C |
| restricted | raidNtargettarget | C | S* | C* | S* | C | S | S* | S | C | C* | C | S* | S* | C | C | C |
| restricted | raidpetN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | softenemy | C | S | C* | S | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | softenemytarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | softenemytargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | softfriend | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | softfriendtarget | C | C* | C | C* | C | S | S | S | C | C* | C | C* | C* | C | C | C |
| restricted | softinteract | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | target | C | S* | C* | S* | C | S | S* | S | C | C | C | C | C | C | C | C |
| restricted | targettarget | C | S* | C* | S* | C | S | S* | S* | C | C* | C | S* | S* | C | C | C |
| restricted | targettargettarget | C | S* | C* | S* | C | S | S* | S* | C | C* | C | S* | S* | C | C | C |
| restricted | vehicle | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |

### Scan cost per capture

| capture start | ms | slices | tokens | reads | existing | sweeps | sweep s | max slice ms | over budget | budget | list | contexts |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1791600745 | 885.93 | 10200 | 12551 | 77982 | 3526 | 24 | 6.81 | 0.308 | 64 | 0.12 | 303 | combat/pvp/raid 3, restricted/pvp/raid 16 |

### Same unit on several tokens (dedupe pairs)

- `raidNtarget=raidNtargettarget`: 120
- `raidN=raidNtarget`: 107
- `partyNtarget=raidNtarget`: 45
- `partyN=raidN`: 31
- `partyNtargettarget=raidNtarget`: 22
- `player=raidN`: 18
- `partyNtarget=partyNtargettarget`: 17
- `playertarget=raidNtarget`: 15
- `mouseover=target`: 10
- `mouseover=raidN`: 9
- `raidN=raidNtargettarget`: 7
- `partyN=partyNtarget`: 7
- `mouseover=raidNtarget`: 6
- `playertargettarget=raidNtarget`: 5
- `mouseovertarget=raidNtarget`: 4
- `partyN=raidNtarget`: 4
- `partyNtargettarget=raidNtargettarget`: 3
- `targettarget=targettargettarget`: 3
- `arenaN=raidN`: 3
- `player=playertarget`: 3
- `partyNtarget=raidN`: 3
- `mouseover=partyN`: 3
- `playertarget=playertargettarget`: 3
- `player=raidNtarget`: 3
- `partyN=raidNtargettarget`: 3
- `mouseovertarget=target`: 3
- `mouseover=mouseovertarget`: 2
- `playertarget=targettargettarget`: 2
- `partyNtarget=targettargettarget`: 2
- `raidN=target`: 2
- `raidN=raidN`: 2
- `raidNtarget=targettargettarget`: 2
- `mouseovertarget=targettarget`: 2
- `playertarget=raidNtargettarget`: 2
- `mouseovertarget=partyNtarget`: 2
- `partyNtarget=raidNtargettarget`: 2
- `playertargettarget=targettargettarget`: 1
- `mouseovertarget=raidNtargettarget`: 1
- `raidNtarget=softfriendtarget`: 1
- `player=raidNtargettarget`: 1
- `partyNtarget=target`: 1
- `raidNtarget=target`: 1
- `partyNtargettarget=raidN`: 1
- `raidNtargettarget=raidNtargettarget`: 1
- `playertarget=raidN`: 1
- `partyNtarget=targettarget`: 1
- `raidNtargettarget=targettargettarget`: 1
- `partyN=target`: 1
- `playertargettarget=raidNtargettarget`: 1
- `mouseover=raidNtargettarget`: 1
- `mouseovertarget=softfriendtarget`: 1

### Secret-GUID tokens resolved by alias (shared cast / castGUID)

- `targettarget<-raidN:castGUID`: 12
- `nameplateN<-target:frame`: 2
- `softfriend<-partyN:frame`: 1
- `targettarget<-raidN:frame`: 1
- `target<-partyN:frame`: 1
- `targettarget<-partyN:frame`: 1
- `target<-raidN:castGUID`: 1

## Change alerts

none (first capture with the scanner sets the baseline)

## One-shot token survey (v2.2 TokenSurvey, out of combat)

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

