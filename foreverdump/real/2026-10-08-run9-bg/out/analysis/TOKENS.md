# TOKENS: unit token matrix per context / instance type

Discovery scanner (Tokens.lua `T.Scan`): every token family (player/pet/target/focus/mouseover/soft*, party1-4, raid1-40, arena1-5, boss1-8, nameplate1-40, plus `target` / `targettarget` chains) is read round-robin under a per-slice time budget. Codes: C clear, S secret, N nil, T secret table, K table, E error; `*` = mixed (dominant share < 100%). Re-verified every capture against the stored baseline; a changed dominant code is a change alert.

## build 70291

### instance `pvp`, group `raid`

| state | family | exists | guid | name | class | level | health | healthMax | power | isPlayer | reaction | canAttack | isMe | isTarget | dead | combat | idSecret |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| combat | arenaNtarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | arenaNtargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | focustarget | C | S* | C* | S* | C | S | S | S | C | C | C | S* | S | C | C | C |
| combat | focustargettarget | C | S* | C | S* | C | S | S | S | C | C | C | S* | S | C | C | C |
| combat | mouseover | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | mouseovertarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | nameplateN | C | S | C | S | C | S | S | S | C | C | C | C | C | C | C | C |
| combat | nameplateNtarget | C | S* | C* | S* | C | S | S | S* | C | C* | C | S* | S* | C | C | C |
| combat | partyNtarget | C | S* | C | S* | C | S | S | S | C | C | C | S* | S* | C | C | C |
| combat | partyNtargettarget | C | S* | C* | S* | C | S | S | S | C | C | C | S* | S* | C | C | C |
| combat | partypetNtarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | partypetNtargettarget | C | S | S | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | playertarget | C | S | C | S | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| combat | playertargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | raidNtarget | C | S* | C* | S* | C | S | S | S | C | C | C | S* | S* | C | C | C |
| combat | raidNtargettarget | C | S* | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| combat | raidpetNtarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | raidpetNtargettarget | C | S | C* | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | softenemytarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | softenemytargettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | softfriendtarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| combat | target | C | S | C | S | C | S | S | S | C | C | C | C | C | C | C | C |
| combat | targettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| combat | targettargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | arenaN | C | C* | C | C* | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | arenaNtarget | C | S* | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | arenaNtargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | arenapetN | C | S | S | S | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | arenapetNtarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | arenapetNtargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | bossN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | bossNtarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | focus | C | C* | C | C* | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | focustarget | C | S* | C* | S* | C | S | S | S | C | C | C | S* | S* | C | C | C |
| restricted | focustargettarget | C | S* | C* | S* | C | S | S | S | C | C | C | S* | S* | C | C | C |
| restricted | mouseover | C | C* | C* | C* | C | S | S | S* | C | C* | C | C | C | C | C | C |
| restricted | mouseovertarget | C | S* | C* | S* | C | S | S | S* | C | C* | C | S* | S* | C | C | C |
| restricted | nameplateN | C | S* | C* | S* | C | S | S | S* | C | C* | C | C | C | C | C | C |
| restricted | nameplateNtarget | C | S | C* | S | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | npc | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | partyN | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | partyNtarget | C | S* | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | partyNtargettarget | C | S* | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | partypetN | C | C | C | C* | C | S | S | S* | C | C* | C | C | C | C | C | C |
| restricted | partypetNtarget | C | S | C* | S | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | partypetNtargettarget | C | S | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | pet | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | pettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | player | C | C | C | C | C | S | C | S | C | C | C | C | C | C | C | C |
| restricted | playertarget | C | S* | C* | S* | C | S | S* | S | C | C* | C | S* | S* | C | C | C |
| restricted | playertargettarget | C | S* | C* | S* | C | S | S* | S* | C | C* | C | S* | S* | C | C | C |
| restricted | raidN | C | C | C | C | C | S | S* | S | C | C | C | C | C | C | C | C |
| restricted | raidNtarget | C | S* | C* | S* | C | S | S* | S | C | C* | C | S* | S* | C | C | C |
| restricted | raidNtargettarget | C | S* | C* | S* | C | S | S* | S | C | C* | C | S* | S* | C | C | C |
| restricted | raidpetN | C | C | C | C* | C | S | S | S* | C | C* | C | C | C | C | C | C |
| restricted | raidpetNtarget | C | S | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | raidpetNtargettarget | C | S | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | softenemy | C | S | S* | S | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | softenemytarget | C | S | C | S | C | S | S | S | C | C | C | S* | S* | C | C | C |
| restricted | softenemytargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | softfriend | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | softfriendtarget | C | S | C* | S | C | S | S | S | C | C | C | S* | S* | C | C | C |
| restricted | softinteract | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | target | C | S* | C* | S* | C | S | S | S* | C | C* | C | C | C | C | C | C |
| restricted | targettarget | C | S* | C* | S* | C | S | S | S* | C | C* | C | S* | S* | C | C | C |
| restricted | targettargettarget | C | S* | C* | S* | C | S | S | S | C | C | C | S* | S* | C | C | C |
| restricted | vehicle | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |

### instance `world`, group `solo`

| state | family | exists | guid | name | class | level | health | healthMax | power | isPlayer | reaction | canAttack | isMe | isTarget | dead | combat | idSecret |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ooc | arenaN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | arenaNtarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | arenapetN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | bossN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | bossNtarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | focus | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | focustarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | focustargettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | mouseover | C | C | C* | C* | C | S | S | S* | C | C* | C | C | C | C | C | C |
| ooc | mouseovertarget | C | C | C | C | C | S | C* | S* | C | C* | C | C | C | C | C | C |
| ooc | nameplateN | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| ooc | nameplateNtarget | C | C | C | C | C | S | C* | S | C | C | C | C | C | C | C | C |
| ooc | npc | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | partyN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | partyNtarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | partyNtargettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | partypetN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | pet | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | pettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | player | C | C | C | C | C | S | C | S | C | C | C | C | C | C | C | C |
| ooc | playertarget | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| ooc | playertargettarget | C | C | C | C | C | S | C | S | C | C | C | C | C | C | C | C |
| ooc | raidN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | raidNtarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | raidNtargettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | raidpetN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | softenemy | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| ooc | softenemytarget | C | C | C | C | C | S | C | S | C | C | C | C | C | C | C | C |
| ooc | softenemytargettarget | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| ooc | softfriend | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | softinteract | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | target | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| ooc | targettarget | C | C | C | C | C | S | C* | S | C | C | C | C | C | C | C | C |
| ooc | targettargettarget | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| ooc | vehicle | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |

### Scan cost per capture

| capture start | ms | slices | tokens | reads | existing | sweeps | sweep s | max slice ms | over budget | budget | list | contexts |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1791498632 | 66.23 | 546 | 7595 | 10084 | 131 | 24 | 1.86 | 9.128 | 44 | 0.12 | 303 | ooc/world/solo 1 |
| 1791498932 | 94.90 | 995 | 15679 | 19555 | 204 | 51 | 1.56 | 0.821 | 74 | 0.12 | 303 | ooc/world/solo 1 |
| 1791499132 | 119.55 | 1305 | 20058 | 24029 | 209 | 66 | 1.88 | 0.496 | 66 | 0.12 | 303 | ooc/world/solo 1 |
| 1791502356 | 2.88 | 35 | 390 | 428 | 2 | 1 | 0 | 0.086 | 0 | 0.12 | 303 | ooc/world/solo 1 |
| 1791502850 | 1082.75 | 12438 | 15412 | 100303 | 4570 | 28 | 55.66 | 0.202 | 95 | 0.12 | 303 | combat/pvp/raid 1, restricted/pvp/raid 12 |
| 1791511826 | 1194.17 | 13765 | 15492 | 110491 | 5123 | 27 | 102.43 | 0.242 | 95 | 0.12 | 303 | combat/pvp/raid 3, restricted/pvp/raid 13 |

### Same unit on several tokens (dedupe pairs)

- `raidN=raidNtarget`: 273
- `raidNtarget=raidNtargettarget`: 166
- `partyNtarget=raidNtarget`: 62
- `playertarget=raidNtarget`: 60
- `nameplateNtarget=player`: 57
- `nameplateN=targettargettarget`: 54
- `player=raidN`: 45
- `nameplateN=target`: 42
- `player=targettarget`: 38
- `partypetN=raidpetN`: 36
- `partyN=raidN`: 32
- `focus=raidN`: 30
- `partyNtarget=partyNtargettarget`: 29
- `partyNtargettarget=raidNtarget`: 29
- `mouseover=target`: 28
- `target=targettargettarget`: 26
- `raidN=raidN`: 24
- `partyNtargettarget=raidNtargettarget`: 24
- `partyNtarget=raidN`: 23
- `raidN=raidNtargettarget`: 22
- `partyN=partyNtarget`: 22
- `mouseovertarget=player`: 18
- `mouseover=nameplateN`: 18
- `mouseovertarget=nameplateNtarget`: 14
- `focus=partyN`: 14
- `partyN=raidNtarget`: 13
- `mouseover=raidN`: 13
- `nameplateNtarget=targettarget`: 12
- `mouseovertarget=targettarget`: 10
- `nameplateN=nameplateNtarget`: 8
- `playertarget=playertargettarget`: 8
- `nameplateN=softenemy`: 7
- `mouseover=mouseovertarget`: 7
- `playertarget=target`: 7
- `mouseover=partyN`: 6
- `playertarget=raidN`: 6
- `focustargettarget=partyNtargettarget`: 6
- `nameplateNtarget=targettargettarget`: 6
- `focustarget=partyNtargettarget`: 6
- `playertarget=raidNtargettarget`: 6
- `arenaN=raidN`: 6
- `raidN=target`: 5
- `nameplateN=playertarget`: 5
- `partyNtargettarget=raidN`: 4
- `partyN=partyNtargettarget`: 4
- `mouseovertarget=target`: 3
- `mouseover=raidNtarget`: 3
- `arenaN=partyN`: 3
- `mouseover=nameplateNtarget`: 3
- `nameplateNtarget=target`: 3
- `partyN=target`: 2
- `raidN=targettarget`: 2
- `mouseover=targettargettarget`: 2
- `focus=mouseover`: 2
- `player=softenemytarget`: 2
- `arenaNtarget=raidNtarget`: 2
- `softenemytarget=targettarget`: 2
- `focus=partyNtargettarget`: 2
- `targettarget=targettargettarget`: 2
- `nameplateNtarget=softenemytarget`: 2
- `focustarget=focustargettarget`: 2
- `mouseovertarget=playertargettarget`: 2
- `mouseovertarget=raidN`: 2
- `raidNtarget=targettarget`: 1
- `mouseovertarget=raidNtarget`: 1
- `partyN=targettarget`: 1
- `mouseovertarget=nameplateN`: 1
- `softenemy=target`: 1
- `playertarget=targettargettarget`: 1
- `nameplateN=softenemytargettarget`: 1
- `focustarget=raidN`: 1
- `mouseover=partyNtarget`: 1
- `playertargettarget=targettarget`: 1
- `nameplateN=nameplateN`: 1
- `arenaN=mouseover`: 1
- `mouseovertarget=raidNtargettarget`: 1
- `raidN=targettargettarget`: 1
- `player=playertargettarget`: 1
- `focus=partyNtarget`: 1
- `partyNtargettarget=target`: 1
- `player=playertarget`: 1
- `mouseover=raidNtargettarget`: 1
- `arenaNtarget=raidN`: 1
- `target=targettarget`: 1
- `partyNtarget=target`: 1
- `focustargettarget=raidNtarget`: 1
- `focustarget=raidNtarget`: 1
- `mouseovertarget=targettargettarget`: 1
- `partyNtarget=raidNtargettarget`: 1

### Secret-GUID tokens resolved by alias (shared cast / castGUID)

- `targettarget<-raidN:castGUID`: 33
- `targettarget<-raidN:frame`: 13
- `targettarget<-partyN:frame`: 3
- `softfriend<-partyN:frame`: 2
- `nameplateN<-focus:frame`: 2
- `target<-raidN:frame`: 2
- `nameplateN<-focustarget:frame`: 2
- `nameplateN<-target:frame`: 2
- `softfriend<-raidN:frame`: 2
- `arenaN<-raidN:frame`: 2
- `arenapetN<-partypetN:frame`: 1
- `nameplateN<-partyN:frame`: 1
- `targettarget<-focustarget:frame`: 1
- `arenaN<-partyN:frame`: 1
- `focustarget<-raidN:frame`: 1

## Change alerts

| build | cell | old | new | date |
|---|---|---|---|---|
| 70291 | ooc/world/solo/nameplateN/threat | C | N | 2026-10-08 |
| 70291 | ooc/world/solo/mouseover/threat | S | N | 2026-10-08 |
| 70291 | restricted/pvp/raid/mouseovertarget/isTarget | C | S | 2026-10-08 |

## One-shot token survey (v2.2 TokenSurvey, out of combat)

| family | token works? | identity secret when? | values secret when? |
|---|---|---|---|
| nameplate | combat: 1/40 resolved | combat: clear | combat: secret (UnitHealth,UnitHealthMax) |
| targettargettarget | combat: 1/1 resolved | combat: clear | combat: secret (UnitHealth,UnitHealthMax) |
| npc | no unit seen (token valid, nothing to resolve) | - | - |
| party | restricted: 4/4 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| boss | no unit seen (token valid, nothing to resolve) | - | - |
| focus | no unit seen (token valid, nothing to resolve) | - | - |
| target | combat: 1/1 resolved | combat: clear | combat: secret (UnitHealth,UnitHealthMax) |
| vehicle | no unit seen (token valid, nothing to resolve) | - | - |
| pettarget | no unit seen (token valid, nothing to resolve) | - | - |
| softinteract | no unit seen (token valid, nothing to resolve) | - | - |
| arena1target | no unit seen (token valid, nothing to resolve) | - | - |
| raid1target | restricted: 1/1 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| party1target | no unit seen (token valid, nothing to resolve) | - | - |
| softfriend | no unit seen (token valid, nothing to resolve) | - | - |
| targettarget | combat: 1/1 resolved | combat: clear | combat: secret (UnitHealth) |
| focustarget | no unit seen (token valid, nothing to resolve) | - | - |
| pet | no unit seen (token valid, nothing to resolve) | - | - |
| partypet | restricted: 1/4 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| mouseovertarget | no unit seen (token valid, nothing to resolve) | - | - |
| player | ooc: 1/1 resolved; restricted: 1/1 resolved; combat: 1/1 resolved | ooc: clear; restricted: clear; combat: clear | ooc: secret (UnitHealth); restricted: secret (UnitHealth); combat: secret (UnitHealth) |
| mouseover | no unit seen (token valid, nothing to resolve) | - | - |
| raidpet | restricted: 5/40 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| raid | restricted: 15/40 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| arena | no unit seen (token valid, nothing to resolve) | - | - |
| focustargettarget | no unit seen (token valid, nothing to resolve) | - | - |
| softenemy | combat: 1/1 resolved | combat: clear | combat: secret (UnitHealth,UnitHealthMax) |

