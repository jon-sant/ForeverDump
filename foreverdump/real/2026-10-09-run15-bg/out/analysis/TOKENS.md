# TOKENS: unit token matrix per context / instance type

Discovery scanner (Tokens.lua `T.Scan`): every token family (player/pet/target/focus/mouseover/soft*, party1-4, raid1-40, arena1-5, boss1-8, nameplate1-40, plus `target` / `targettarget` chains) is read round-robin under a per-slice time budget. Codes: C clear, S secret, N nil, T secret table, K table, E error; `*` = mixed (dominant share < 100%). Re-verified every capture against the stored baseline; a changed dominant code is a change alert.

## build 70334

### instance `pvp`, group `raid`

| state | family | exists | guid | name | class | level | health | healthMax | power | isPlayer | reaction | canAttack | isMe | isTarget | dead | combat | idSecret |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| restricted | arenaN | C | C* | C | C* | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | arenaNtarget | C | C* | C | C* | C | S | S | S | C | C | C | C* | C* | C | C | C |
| restricted | arenaNtargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | arenapetN | C | S | S | S | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | bossN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | bossNtarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | focus | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | focustarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | focustargettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | mouseover | C | C* | C* | S* | C | S | S | S* | C | C* | C | C | C | C | C | C |
| restricted | mouseovertarget | C | S* | C | S* | C | S | S | S* | C | C* | C | S* | S* | C | C | C |
| restricted | nameplateN | C | S | C* | S* | C | S | S | S* | C | C* | C | C | C | C | C | C |
| restricted | nameplateNtarget | C | S* | C* | S* | C | S | S | S* | C | C* | C | S* | S* | C | C | C |
| restricted | npc | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | partyN | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | partyNtarget | C | C* | C* | C* | C | S | S | S | C | C | C | C* | S* | C | C | C |
| restricted | partyNtargettarget | C | S* | C* | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | partypetN | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | partypetNtarget | C | S | C | S | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | partypetNtargettarget | C | S | C* | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | pet | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | pettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | player | C | C | C | C | C | S | C | S | C | C | C | C | C | C | C | C |
| restricted | playertarget | C | S* | C | S* | C | S | S* | S | C | C | C | S* | S* | C | C | C |
| restricted | playertargettarget | C | S* | C* | S* | C | S | S* | S | C | C* | C | S* | S* | C | C | C |
| restricted | raidN | C | C | C | C | C | S | S* | S | C | C | C | C | C | C | C | C |
| restricted | raidNtarget | C | S* | C* | S* | C | S | S* | S* | C | C* | C | S* | S* | C | C | C |
| restricted | raidNtargettarget | C | S* | C* | S* | C | S | S* | S | C | C* | C | S* | S* | C | C | C |
| restricted | raidpetN | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | raidpetNtarget | C | S | C | S* | C | S | S | S | C | C* | C | S* | S* | C | C | C |
| restricted | raidpetNtargettarget | C | S | C* | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | softenemy | C | S | C | S | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | softenemytarget | C | S | C | S | C | S | S | S* | C | C* | C | S* | S* | C | C | C |
| restricted | softenemytargettarget | C | S | C | S | C | S | S | S | C | C | C | S | S | C | C | C |
| restricted | softfriend | C | C | C | C | C | S | S | S | C | C | C | C | C | C | C | C |
| restricted | softfriendtarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | softinteract | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | target | C | S* | C | S* | C | S | S* | S | C | C | C | C | C | C | C | C |
| restricted | targettarget | C | S* | C* | S* | C | S | S* | S* | C | C* | C | S* | S* | C | C | C |
| restricted | targettargettarget | C | S* | C | S* | C | S | S* | S | C | C | C | S* | S* | C | C | C |
| restricted | vehicle | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |

### instance `pvp`, group `solo`

| state | family | exists | guid | name | class | level | health | healthMax | power | isPlayer | reaction | canAttack | isMe | isTarget | dead | combat | idSecret |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| restricted | arenaN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | arenapetN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | focus | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | focustarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | focustargettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | mouseover | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | mouseovertarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | npc | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | partyN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | partyNtarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | partyNtargettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | partypetN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | pet | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | pettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | player | C | C | C | C | C | S | C | S | C | C | C | C | C | C | C | C |
| restricted | raidN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | raidNtarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | softenemy | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | softfriend | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | softinteract | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | target | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | targettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| restricted | targettargettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
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
| ooc | mouseover | C | C* | C* | C* | C | S | S* | S* | C | C* | C | C | C | C | C | C |
| ooc | mouseovertarget | C | C | C | C | C | S | S | S* | C | C* | C | C | C | C | C | C |
| ooc | nameplateN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | nameplateNtarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | npc | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | partyN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | partyNtarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | partyNtargettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | partypetN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | pet | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | pettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | player | C | C | C | C | C | S | C | S | C | C | C | C | C | C | C | C |
| ooc | raidN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | raidNtarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | raidNtargettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | raidpetN | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | softenemy | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | softfriend | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | softinteract | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | target | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | targettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | targettargettarget | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| ooc | vehicle | C | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |

### Scan cost per capture

| capture start | ms | slices | tokens | reads | existing | sweeps | sweep s | max slice ms | over budget | budget | list | contexts |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1791588516 | 1127.83 | 13341 | 103039 | 156465 | 2848 | 327 | 2.32 | 1.027 | 113 | 0.12 | 303 | ooc/world/solo 2, restricted/pvp/raid 15, restricted/pvp/solo 1 |

### Same unit on several tokens (dedupe pairs)

- `partyNtarget=raidNtarget`: 126
- `player=raidN`: 99
- `raidN=raidNtarget`: 82
- `raidNtarget=raidNtargettarget`: 60
- `partyN=raidN`: 46
- `partyNtargettarget=raidNtarget`: 20
- `partyNtarget=partyNtargettarget`: 17
- `raidN=raidN`: 16
- `partyN=raidNtarget`: 14
- `partypetN=raidpetN`: 13
- `partyN=partyNtarget`: 12
- `partyNtarget=raidN`: 6
- `arenaN=raidN`: 4
- `playertarget=raidNtarget`: 4
- `mouseover=player`: 4
- `arenaNtarget=raidN`: 3
- `partyNtargettarget=raidNtargettarget`: 3
- `mouseover=partyN`: 2
- `arenaN=arenaNtarget`: 2
- `mouseover=mouseovertarget`: 2
- `arenaN=partyN`: 2
- `mouseover=raidN`: 2
- `raidNtarget=targettargettarget`: 2
- `raidNtarget=targettarget`: 1
- `arenaN=target`: 1
- `raidN=raidNtargettarget`: 1
- `mouseover=target`: 1
- `partyN=raidNtargettarget`: 1
- `arenaNtarget=raidNtarget`: 1
- `playertarget=raidN`: 1
- `raidN=target`: 1
- `target=targettarget`: 1
- `playertarget=targettargettarget`: 1
- `partyN=partyNtargettarget`: 1
- `raidNtargettarget=targettargettarget`: 1
- `playertargettarget=targettargettarget`: 1
- `target=targettargettarget`: 1
- `mouseover=raidNtargettarget`: 1
- `arenaN=softfriend`: 1
- `partyNtarget=raidNtargettarget`: 1

### Secret-GUID tokens resolved by alias (shared cast / castGUID)

- `targettarget<-raidN:castGUID`: 5
- `targettarget<-raidN:frame`: 2
- `target<-raidN:castGUID`: 1

## Change alerts

none (first capture with the scanner sets the baseline)

## One-shot token survey (v2.2 TokenSurvey, out of combat)

| family | token works? | identity secret when? | values secret when? |
|---|---|---|---|
| nameplate | no unit seen (token valid, nothing to resolve) | - | - |
| targettargettarget | no unit seen (token valid, nothing to resolve) | - | - |
| npc | no unit seen (token valid, nothing to resolve) | - | - |
| party | restricted: 3/4 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| boss | no unit seen (token valid, nothing to resolve) | - | - |
| focus | no unit seen (token valid, nothing to resolve) | - | - |
| target | no unit seen (token valid, nothing to resolve) | - | - |
| vehicle | no unit seen (token valid, nothing to resolve) | - | - |
| pettarget | no unit seen (token valid, nothing to resolve) | - | - |
| softinteract | no unit seen (token valid, nothing to resolve) | - | - |
| arena1target | no unit seen (token valid, nothing to resolve) | - | - |
| raid1target | restricted: 1/1 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| party1target | restricted: 1/1 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| softfriend | no unit seen (token valid, nothing to resolve) | - | - |
| targettarget | no unit seen (token valid, nothing to resolve) | - | - |
| focustarget | no unit seen (token valid, nothing to resolve) | - | - |
| pet | no unit seen (token valid, nothing to resolve) | - | - |
| partypet | no unit seen (token valid, nothing to resolve) | - | - |
| mouseovertarget | no unit seen (token valid, nothing to resolve) | - | - |
| player | restricted: 1/1 resolved | restricted: clear | restricted: secret (UnitHealth) |
| mouseover | no unit seen (token valid, nothing to resolve) | - | - |
| raidpet | restricted: 3/40 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| raid | restricted: 14/40 resolved | restricted: clear | restricted: secret (UnitHealth,UnitHealthMax) |
| arena | no unit seen (token valid, nothing to resolve) | - | - |
| focustargettarget | no unit seen (token valid, nothing to resolve) | - | - |
| softenemy | no unit seen (token valid, nothing to resolve) | - | - |

