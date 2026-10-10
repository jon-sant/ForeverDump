# TOKENS: unit token matrix per context / instance type

Discovery scanner (Tokens.lua `T.Scan`): every token family (player/pet/target/focus/mouseover/soft*, party1-4, raid1-40, arena1-5, boss1-8, nameplate1-40, plus `target` / `targettarget` chains) is read round-robin under a per-slice time budget. Codes: C clear, S secret, N nil, T secret table, K table, E error; `*` = mixed (dominant share < 100%). Re-verified every capture against the stored baseline; a changed dominant code is a change alert.

## build 70291

### instance `pvp`, group `raid`

| state | family | exists | guid | name | class | level | health | healthMax | power | isPlayer | reaction | canAttack | isMe | isTarget | dead | combat | idSecret |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| restricted | arenaN | C | C* | C | C* | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | arenaNtarget | C | S | C* | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | arenaNtargettarget | C | S | C* | S* | C | S | S | S | C | C* | C | S* | S | C | C | C |
| restricted | arenapetN | C | S | S | S | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | arenapetNtarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | arenapetNtargettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | bossN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | bossNtarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | focus | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | focustarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | focustargettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | mouseover | C | C* | C* | C* | C | S | S | S* | C | C* | C | C | C | C | C | C |
| restricted | mouseovertarget | C | S* | C* | S* | C | S | S | S* | C | C* | C | C* | C* | C | C | C |
| restricted | nameplateN | C | S | C* | S* | C | S | S | S* | C | C* | C | C | C | C | C | C |
| restricted | nameplateNtarget | C | S | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | npc | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | partyN | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | partyNtarget | C | S* | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | partyNtargettarget | C | S* | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | partypetN | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | partypetNtarget | C | S | C* | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | partypetNtargettarget | C | S | C* | S | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | pet | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | pettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | player | C | C | C | C | C | S | C | S | C | C | C | C | C | C | C | C |
| restricted | playertarget | C | S* | C* | S* | C | S | S* | S | C | C | C | S* | S* | C | C | C |
| restricted | playertargettarget | C | S* | C* | S* | C | S | S* | S | C | C* | C | S* | S* | C | C | C |
| restricted | raidN | C | C | C | C | C | S | S* | S | C | C | C | C | C | C | C | C |
| restricted | raidNtarget | C | S* | C* | S* | C | S | S* | S | C | C* | C | S* | S* | C | C | C |
| restricted | raidNtargettarget | C | S* | C* | S* | C | S | S* | S | C | C* | C | S* | S* | C | C | C |
| restricted | raidpetN | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | raidpetNtarget | C | S | C* | S | C | S | S | S | C | C | C | S | S* | C | C | C |
| restricted | raidpetNtargettarget | C | S | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | softenemy | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | softenemytarget | C | S | C* | S | C | S | S | S* | C | C* | C | S* | S* | C | C | C |
| restricted | softenemytargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | softfriend | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | softfriendtarget | C | S* | C | S* | C | S | S | S | C | C | C | S* | C* | C | C | C |
| restricted | softinteract | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | target | C | S* | C* | S* | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | targettarget | C | S* | C* | S* | C | S | S | S* | C | C* | C | S* | S* | C | C | C |
| restricted | targettargettarget | C | S* | C* | S* | C | S | S | S | C | C | C | S* | S* | C | C | C |
| restricted | vehicle | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |

### Scan cost per capture

| capture start | ms | slices | tokens | reads | existing | sweeps | sweep s | max slice ms | over budget | budget | list | contexts |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1791518213 | 1169.61 | 13481 | 14747 | 100389 | 4605 | 23 | 3.64 | 0.272 | 88 | 0.12 | 303 | restricted/pvp/raid 14 |

### Same unit on several tokens (dedupe pairs)

- `raidN=raidNtarget`: 76
- `partyNtarget=raidNtarget`: 70
- `raidNtarget=raidNtargettarget`: 51
- `player=raidN`: 32
- `partyNtargettarget=raidNtargettarget`: 18
- `partypetN=raidpetN`: 16
- `partyN=raidN`: 15
- `partyNtargettarget=raidNtarget`: 13
- `partyN=partyNtarget`: 13
- `partyN=raidNtarget`: 11
- `playertarget=raidNtarget`: 10
- `partyNtarget=partyNtargettarget`: 10
- `partyNtarget=raidN`: 9
- `raidN=raidN`: 9
- `raidN=raidNtargettarget`: 7
- `mouseover=target`: 6
- `partyNtarget=raidNtargettarget`: 6
- `mouseover=raidN`: 5
- `mouseover=raidNtarget`: 4
- `arenaN=raidN`: 4
- `mouseover=raidNtargettarget`: 4
- `partyNtargettarget=raidN`: 3
- `mouseover=partyN`: 2
- `raidNtargettarget=targettarget`: 2
- `targettarget=targettargettarget`: 2
- `raidNtarget=target`: 2
- `raidNtarget=softfriend`: 2
- `player=raidNtarget`: 2
- `arenaN=mouseover`: 2
- `raidNtarget=softfriendtarget`: 1
- `raidNtargettarget=target`: 1
- `raidN=target`: 1
- `player=playertarget`: 1
- `mouseovertarget=raidNtarget`: 1
- `partyN=partyNtargettarget`: 1
- `player=raidNtargettarget`: 1
- `player=playertargettarget`: 1
- `mouseovertarget=raidNtargettarget`: 1
- `raidNtarget=targettargettarget`: 1
- `mouseovertarget=targettargettarget`: 1
- `raidN=softfriend`: 1
- `mouseover=mouseovertarget`: 1

### Secret-GUID tokens resolved by alias (shared cast / castGUID)

- `targettarget<-raidN:castGUID`: 12
- `targettarget<-raidN:frame`: 5
- `targettarget<-partyN:frame`: 4
- `nameplateN<-target:frame`: 2
- `softenemy<-nameplateN:frame`: 2
- `raidpetN<-targettarget:frame`: 1
- `targettarget<-partypetN:frame`: 1
- `nameplateN<-targettarget:frame`: 1
- `target<-raidN:frame`: 1
- `partypetN<-raidpetN:frame`: 1
- `softfriend<-raidN:frame`: 1
- `target<-nameplateN:frame`: 1
- `nameplateN<-softenemy:frame`: 1

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
| raid1target | restricted: 1/1 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| party1target | no unit seen (token valid, nothing to resolve) | - | - |
| softfriend | no unit seen (token valid, nothing to resolve) | - | - |
| targettarget | no unit seen (token valid, nothing to resolve) | - | - |
| focustarget | no unit seen (token valid, nothing to resolve) | - | - |
| pet | no unit seen (token valid, nothing to resolve) | - | - |
| partypet | restricted: 2/4 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| mouseovertarget | no unit seen (token valid, nothing to resolve) | - | - |
| player | restricted: 1/1 resolved | restricted: clear | restricted: secret (UnitHealth) |
| mouseover | no unit seen (token valid, nothing to resolve) | - | - |
| raidpet | restricted: 4/40 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| raid | restricted: 15/40 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| arena | no unit seen (token valid, nothing to resolve) | - | - |
| focustargettarget | no unit seen (token valid, nothing to resolve) | - | - |
| softenemy | no unit seen (token valid, nothing to resolve) | - | - |

