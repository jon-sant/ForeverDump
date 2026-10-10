# TOKENS: unit token matrix per context / instance type

Discovery scanner (Tokens.lua `T.Scan`): every token family (player/pet/target/focus/mouseover/soft*, party1-4, raid1-40, arena1-5, boss1-8, nameplate1-40, plus `target` / `targettarget` chains) is read round-robin under a per-slice time budget. Codes: C clear, S secret, N nil, T secret table, K table, E error; `*` = mixed (dominant share < 100%). Re-verified every capture against the stored baseline; a changed dominant code is a change alert.

## build 70291

### instance `pvp`, group `raid`

| state | family | exists | guid | name | class | level | health | healthMax | power | isPlayer | reaction | canAttack | isMe | isTarget | dead | combat | idSecret |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| restricted | arenaN | C | C* | C | C* | C | S | S* | S | C | C | C | C | C | C | C | C |
| restricted | arenaNtarget | C | S* | C | S* | C | S | S | S | C | C | C | S* | S* | C | C | C |
| restricted | arenaNtargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | arenapetN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | bossN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | bossNtarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | focus | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | focustarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | focustargettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | mouseover | C | C* | C* | C* | C | S | S | S* | C | C* | C | C | C | C | C | C |
| restricted | mouseovertarget | C | S* | C* | S* | C | S | S | S* | C | C* | C | C* | C* | C | C | C |
| restricted | nameplateN | C | S | C | S | C | S | S | S* | C | C* | C | C | C | C | C | C |
| restricted | nameplateNtarget | C | S* | C* | S* | C | S | S | S* | C | C* | C | S* | S* | C | C | C |
| restricted | npc | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | partyN | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | partyNtarget | C | S* | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | partyNtargettarget | C | S* | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | partypetN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | pet | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | pettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | player | C | C | C | C | C | S | C | S | C | C | C | C | C | C | C | C |
| restricted | playertarget | C | S* | C* | S* | C | S | S* | S | C | C | C | S* | S* | C | C | C |
| restricted | playertargettarget | C | S* | C* | S* | C | S | S* | S* | C | C* | C | S* | S* | C | C | C |
| restricted | raidN | C | C | C | C | C | S | S* | S | C | C | C | C | C | C | C | C |
| restricted | raidNtarget | C | S* | C* | S* | C | S | S* | S | C | C* | C | S* | S* | C | C | C |
| restricted | raidNtargettarget | C | S* | C* | S* | C | S | S* | S | C | C* | C | S* | S* | C | C | C |
| restricted | raidpetN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | softenemy | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | softenemytarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | softenemytargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S* | C | C | C |
| restricted | softfriend | C | C* | C* | C* | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | softfriendtarget | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | softinteract | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | target | C | S* | C* | S* | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | targettarget | C | S* | C* | S* | C | S | S* | S | C | C | C | S* | S* | C | C | C |
| restricted | targettargettarget | C | S* | C* | S* | C | S | S* | S | C | C | C | S* | S* | C | C | C |
| restricted | vehicle | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |

### Scan cost per capture

| capture start | ms | slices | tokens | reads | existing | sweeps | sweep s | max slice ms | over budget | budget | list | contexts |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1791552545 | 932.03 | 10691 | 15520 | 87340 | 3824 | 33 | 2.92 | 0.425 | 85 | 0.12 | 303 | restricted/pvp/raid 14 |

### Same unit on several tokens (dedupe pairs)

- `raidN=raidNtarget`: 128
- `raidNtarget=raidNtargettarget`: 122
- `player=raidN`: 36
- `partyNtarget=raidNtarget`: 35
- `partyN=raidN`: 31
- `partyNtargettarget=raidNtarget`: 27
- `partyNtarget=partyNtargettarget`: 25
- `raidN=raidNtargettarget`: 15
- `partyNtarget=raidN`: 14
- `partyN=partyNtarget`: 12
- `partyNtargettarget=raidNtargettarget`: 10
- `playertarget=raidNtarget`: 9
- `softfriend=target`: 9
- `mouseover=raidN`: 8
- `raidN=raidN`: 7
- `partyNtarget=raidNtargettarget`: 6
- `arenaN=raidN`: 5
- `mouseover=target`: 5
- `partyNtargettarget=raidN`: 4
- `raidNtarget=target`: 4
- `partyN=raidNtarget`: 4
- `raidN=softfriend`: 4
- `raidNtarget=targettargettarget`: 4
- `raidNtarget=targettarget`: 3
- `arenaN=arenaNtarget`: 3
- `partyN=raidNtargettarget`: 3
- `mouseovertarget=raidNtarget`: 2
- `mouseover=partyN`: 2
- `raidNtarget=softfriendtarget`: 2
- `mouseover=raidNtarget`: 2
- `arenaN=raidNtarget`: 2
- `arenaN=player`: 2
- `raidNtarget=softfriend`: 2
- `partyN=partyNtargettarget`: 2
- `raidNtarget=raidNtarget`: 2
- `arenaN=mouseover`: 2
- `player=playertarget`: 2
- `targettarget=targettargettarget`: 1
- `playertarget=raidNtargettarget`: 1
- `raidN=target`: 1
- `playertarget=playertargettarget`: 1
- `player=raidNtarget`: 1
- `arenaNtarget=raidNtarget`: 1
- `arenaN=targettarget`: 1

### Secret-GUID tokens resolved by alias (shared cast / castGUID)

- `targettarget<-raidN:castGUID`: 10
- `targettarget<-raidN:frame`: 4
- `partyN<-raidN:frame`: 3
- `nameplateN<-target:frame`: 2
- `target<-raidN:frame`: 1
- `softfriend<-raidN:frame`: 1

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
| partypet | no unit seen (token valid, nothing to resolve) | - | - |
| mouseovertarget | no unit seen (token valid, nothing to resolve) | - | - |
| player | restricted: 1/1 resolved | restricted: clear | restricted: secret (UnitHealth) |
| mouseover | no unit seen (token valid, nothing to resolve) | - | - |
| raidpet | no unit seen (token valid, nothing to resolve) | - | - |
| raid | restricted: 15/40 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| arena | no unit seen (token valid, nothing to resolve) | - | - |
| focustargettarget | no unit seen (token valid, nothing to resolve) | - | - |
| softenemy | no unit seen (token valid, nothing to resolve) | - | - |

