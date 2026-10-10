# TOKENS: unit token matrix per context / instance type

Discovery scanner (Tokens.lua `T.Scan`): every token family (player/pet/target/focus/mouseover/soft*, party1-4, raid1-40, arena1-5, boss1-8, nameplate1-40, plus `target` / `targettarget` chains) is read round-robin under a per-slice time budget. Codes: C clear, S secret, N nil, T secret table, K table, E error; `*` = mixed (dominant share < 100%). Re-verified every capture against the stored baseline; a changed dominant code is a change alert.

## build 70291

### instance `pvp`, group `raid`

| state | family | exists | guid | name | class | level | health | healthMax | power | isPlayer | reaction | canAttack | isMe | isTarget | dead | combat | idSecret |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| combat | focus | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | focustarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | focustargettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | mouseover | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | mouseovertarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | npc | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | partyNtarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | partyNtargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | pet | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | pettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | player | C | C | C | C | C | S | C | S | C | C | C | C | C | C | C | C |
| combat | raidN | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| combat | raidNtarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | raidNtargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | softenemy | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | softfriend | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | softinteract | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | target | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | targettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | targettargettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | vehicle | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | arenaN | C | C* | C | C* | C | S | C* | S | C | C | C | C | C | C | C | C |
| restricted | arenaNtarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | arenapetN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | bossN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | bossNtarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | focus | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | focustarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | focustargettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | mouseover | C | C* | C* | C* | C | S | S | S* | C | C* | C | C | C | C | C | C |
| restricted | mouseovertarget | C | C* | C | C* | C | S | S | S* | C | C* | C | C* | C* | C | C | C |
| restricted | nameplateN | C | S | C | S | C | S | S | S* | C | C* | C | C | C | C | C | C |
| restricted | nameplateNtarget | C | S | C* | S | C | S | S | S | C | C | C | S | S* | C | C | C |
| restricted | npc | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | partyN | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | partyNtarget | C | S* | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | partyNtargettarget | C | S* | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | partypetN | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | partypetNtarget | C | S | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | partypetNtargettarget | C | S | C* | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | pet | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | pettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | player | C | C | C | C | C | S | C | S | C | C | C | C | C | C | C | C |
| restricted | playertarget | C | S* | C* | S* | C | S | S* | S | C | C | C | S* | S* | C | C | C |
| restricted | playertargettarget | C | S* | C* | S* | C | S | S* | S | C | C | C | S* | S* | C | C | C |
| restricted | raidN | C | C | C | C | C | S | S* | S | C | C | C | C | C | C | C | C |
| restricted | raidNtarget | C | S* | C* | S* | C | S | S* | S | C | C* | C | S* | S* | C | C | C |
| restricted | raidNtargettarget | C | S* | C* | S* | C | S | S* | S | C | C* | C | S* | S* | C | C | C |
| restricted | raidpetN | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | raidpetNtarget | C | S | C* | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | raidpetNtargettarget | C | S | C* | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | softenemy | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | softenemytarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | softenemytargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | softfriend | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | softfriendtarget | C | S | C | S | C | S | S | S | C | N | C | C | C | C | C | C |
| restricted | softinteract | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | target | C | S* | C* | S* | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | targettarget | C | S* | C* | S* | C | S | S | S | C | C | C | S* | S* | C | C | C |
| restricted | targettargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | vehicle | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |

### Scan cost per capture

| capture start | ms | slices | tokens | reads | existing | sweeps | sweep s | max slice ms | over budget | budget | list | contexts |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1791580516 | 474.66 | 5444 | 6910 | 39475 | 1753 | 12 | 6.94 | 0.177 | 43 | 0.12 | 303 | combat/pvp/raid 1, restricted/pvp/raid 19 |

### Same unit on several tokens (dedupe pairs)

- `raidN=raidNtarget`: 76
- `raidNtarget=raidNtargettarget`: 55
- `player=raidN`: 27
- `raidN=raidN`: 21
- `partyNtargettarget=raidNtarget`: 19
- `partyNtarget=raidNtarget`: 16
- `partypetN=raidpetN`: 13
- `partyNtargettarget=raidNtargettarget`: 12
- `partyNtarget=partyNtargettarget`: 12
- `partyNtarget=raidNtargettarget`: 8
- `partyN=raidN`: 7
- `partyN=partyNtarget`: 7
- `partyN=partyNtargettarget`: 6
- `partyN=raidNtargettarget`: 5
- `raidN=raidNtargettarget`: 4
- `mouseover=raidNtarget`: 2
- `partyNtarget=raidN`: 2
- `playertarget=raidNtarget`: 2
- `partyNtargettarget=raidN`: 2
- `mouseover=target`: 1
- `raidpetN=raidpetN`: 1
- `playertarget=raidN`: 1
- `mouseovertarget=partyN`: 1
- `playertargettarget=raidNtarget`: 1
- `mouseovertarget=raidNtarget`: 1
- `playertarget=playertargettarget`: 1
- `mouseovertarget=partyNtarget`: 1
- `mouseover=raidN`: 1
- `raidNtarget=target`: 1

### Secret-GUID tokens resolved by alias (shared cast / castGUID)

- `targettarget<-raidN:castGUID`: 2
- `targettarget<-raidN:frame`: 1
- `partyN<-raidN:frame`: 1
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
| raid | restricted: 11/40 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| arena | no unit seen (token valid, nothing to resolve) | - | - |
| focustargettarget | no unit seen (token valid, nothing to resolve) | - | - |
| softenemy | no unit seen (token valid, nothing to resolve) | - | - |

