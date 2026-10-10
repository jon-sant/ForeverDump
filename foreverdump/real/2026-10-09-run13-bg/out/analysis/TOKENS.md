# TOKENS: unit token matrix per context / instance type

Discovery scanner (Tokens.lua `T.Scan`): every token family (player/pet/target/focus/mouseover/soft*, party1-4, raid1-40, arena1-5, boss1-8, nameplate1-40, plus `target` / `targettarget` chains) is read round-robin under a per-slice time budget. Codes: C clear, S secret, N nil, T secret table, K table, E error; `*` = mixed (dominant share < 100%). Re-verified every capture against the stored baseline; a changed dominant code is a change alert.

## build 70291

### instance `pvp`, group `raid`

| state | family | exists | guid | name | class | level | health | healthMax | power | isPlayer | reaction | canAttack | isMe | isTarget | dead | combat | idSecret |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| combat | mouseover | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | mouseovertarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | nameplateN | C | S | C | S | C | S | S | S | C | C | C | C | C | C | C | C |
| combat | nameplateNtarget | C | S | S | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | partyNtarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | partyNtargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | playertarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | playertargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | raidNtarget | C | S* | C | S* | C | S | S* | S | C | C | C | S* | S* | C | C | C |
| combat | raidNtargettarget | C | S | C* | S | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| combat | softenemytarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | softenemytargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | softfriendtarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | target | C | S | C | S | C | S | S | S | C | C | C | C | C | C | C | C |
| combat | targettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | targettargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | arenaN | C | S* | C | S* | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | arenaNtarget | C | S* | C | S* | C | S | S | S* | C | C* | C | S* | S* | C | C | C |
| restricted | arenaNtargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | arenapetN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | bossN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | bossNtarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | focus | C | C* | C* | C* | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | focustarget | C | S* | C* | S* | C | S | S* | S | C | C | C | S* | S* | C | C | C |
| restricted | focustargettarget | C | S* | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | mouseover | C | C* | C* | C* | C | S | S | S* | C | C* | C | C | C | C | C | C |
| restricted | mouseovertarget | C | S* | C* | S* | C | S | S | S* | C | C* | C | C* | C* | C | C | C |
| restricted | nameplateN | C | S | C* | S | C | S | S | S* | C | C* | C | C | C | C | C | C |
| restricted | nameplateNtarget | C | S | C* | S | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | npc | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | partyN | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | partyNtarget | C | S* | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | partyNtargettarget | C | S* | C* | S* | C | S | S | S* | C | C* | C | S* | S* | C | C | C |
| restricted | partypetN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | pet | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | pettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | player | C | C | C | C | C | S | C | S | C | C | C | C | C | C | C | C |
| restricted | playertarget | C | S* | C | S* | C | S | S* | S | C | C | C | S* | S* | C | C | C |
| restricted | playertargettarget | C | S* | C* | S* | C | S | S* | S | C | C* | C | S* | S* | C | C | C |
| restricted | raidN | C | C | C | C | C | S | S* | S | C | C | C | C | C | C | C | C |
| restricted | raidNtarget | C | S* | C* | S* | C | S | S* | S* | C | C* | C | S* | S* | C | C | C |
| restricted | raidNtargettarget | C | S* | C* | S* | C | S | S* | S | C | C* | C | S* | S* | C | C | C |
| restricted | raidpetN | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | raidpetNtarget | C | S | C* | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | raidpetNtargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | softenemy | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | softenemytarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | softenemytargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S* | C | C | C |
| restricted | softfriend | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | softfriendtarget | C | S* | C* | S* | C | S | S | S* | C | C* | C | S* | S* | C | C | C |
| restricted | softinteract | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | target | C | S* | C* | S* | C | S | S | S* | C | C* | C | C | C | C | C | C |
| restricted | targettarget | C | S* | C* | S* | C | S | S | S* | C | C* | C | S* | S* | C | C | C |
| restricted | targettargettarget | C | S* | C | S* | C | S | S | S* | C | C* | C | S* | S* | C | C | C |
| restricted | vehicle | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |

### Scan cost per capture

| capture start | ms | slices | tokens | reads | existing | sweeps | sweep s | max slice ms | over budget | budget | list | contexts |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1791571591 | 928.24 | 10495 | 13168 | 73319 | 3215 | 26 | 3.85 | 0.377 | 155 | 0.12 | 303 | combat/pvp/raid 1, restricted/pvp/raid 21 |

### Same unit on several tokens (dedupe pairs)

- `raidN=raidNtarget`: 85
- `partyNtarget=raidNtarget`: 72
- `raidNtarget=raidNtargettarget`: 28
- `player=raidN`: 26
- `partyNtarget=partyNtargettarget`: 18
- `partyNtarget=raidN`: 17
- `partyN=partyNtarget`: 17
- `partyN=raidN`: 16
- `playertarget=raidNtarget`: 15
- `partyNtargettarget=raidNtarget`: 14
- `focus=raidN`: 13
- `focus=partyN`: 11
- `partyNtargettarget=raidNtargettarget`: 9
- `partyNtarget=raidNtargettarget`: 9
- `mouseover=raidN`: 8
- `focustarget=raidN`: 6
- `raidN=raidNtargettarget`: 5
- `raidN=raidN`: 5
- `mouseover=target`: 5
- `focus=partyNtarget`: 5
- `mouseover=raidNtarget`: 4
- `partyNtargettarget=raidN`: 4
- `raidNtarget=target`: 3
- `player=playertarget`: 3
- `raidN=target`: 3
- `player=raidNtarget`: 3
- `mouseover=mouseovertarget`: 3
- `partyN=partyNtargettarget`: 3
- `mouseover=partyN`: 2
- `mouseovertarget=target`: 2
- `playertarget=raidN`: 2
- `partyN=raidNtarget`: 2
- `arenaN=arenaNtarget`: 2
- `playertarget=playertargettarget`: 2
- `mouseovertarget=raidNtarget`: 1
- `focustarget=targettarget`: 1
- `focustargettarget=raidN`: 1
- `playertargettarget=raidNtarget`: 1
- `softfriend=target`: 1
- `arenaNtarget=raidNtarget`: 1
- `focustarget=raidNtarget`: 1
- `focustarget=focustargettarget`: 1
- `mouseover=targettarget`: 1
- `focustargettarget=raidNtarget`: 1
- `raidN=softfriendtarget`: 1
- `raidN=targettarget`: 1
- `mouseover=targettargettarget`: 1
- `partyN=raidNtargettarget`: 1
- `focus=mouseovertarget`: 1

### Secret-GUID tokens resolved by alias (shared cast / castGUID)

- `targettarget<-raidN:castGUID`: 11
- `targettarget<-raidN:frame`: 5
- `target<-raidN:frame`: 2
- `softfriend<-raidN:frame`: 1
- `nameplateN<-target:frame`: 1
- `partyN<-raidN:frame`: 1
- `targettarget<-partyN:frame`: 1
- `softfriend<-partyN:frame`: 1
- `raidN<-partyN:frame`: 1
- `target<-partyN:frame`: 1

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
| partypet | no unit seen (token valid, nothing to resolve) | - | - |
| mouseovertarget | no unit seen (token valid, nothing to resolve) | - | - |
| player | restricted: 1/1 resolved | restricted: clear | restricted: secret (UnitHealth) |
| mouseover | no unit seen (token valid, nothing to resolve) | - | - |
| raidpet | restricted: 2/40 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| raid | restricted: 9/40 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| arena | no unit seen (token valid, nothing to resolve) | - | - |
| focustargettarget | no unit seen (token valid, nothing to resolve) | - | - |
| softenemy | no unit seen (token valid, nothing to resolve) | - | - |

