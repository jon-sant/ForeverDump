# TOKENS: unit token matrix per context / instance type

Discovery scanner (Tokens.lua `T.Scan`): every token family (player/pet/target/focus/mouseover/soft*, party1-4, raid1-40, arena1-5, boss1-8, nameplate1-40, plus `target` / `targettarget` chains) is read round-robin under a per-slice time budget. Codes: C clear, S secret, N nil, T secret table, K table, E error; `*` = mixed (dominant share < 100%). Re-verified every capture against the stored baseline; a changed dominant code is a change alert.

## build 70291

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

### Same unit on several tokens (dedupe pairs)

- `nameplateNtarget=player`: 57
- `nameplateN=targettargettarget`: 54
- `nameplateN=target`: 42
- `player=targettarget`: 38
- `target=targettargettarget`: 26
- `mouseover=nameplateN`: 18
- `mouseovertarget=player`: 18
- `mouseovertarget=nameplateNtarget`: 14
- `nameplateNtarget=targettarget`: 12
- `mouseovertarget=targettarget`: 9
- `nameplateN=nameplateNtarget`: 8
- `nameplateN=softenemy`: 7
- `playertarget=target`: 7
- `nameplateNtarget=targettargettarget`: 6
- `nameplateN=playertarget`: 5
- `mouseover=target`: 4
- `nameplateNtarget=target`: 3
- `mouseover=nameplateNtarget`: 3
- `softenemytarget=targettarget`: 2
- `player=softenemytarget`: 2
- `mouseover=targettargettarget`: 2
- `mouseovertarget=playertargettarget`: 2
- `nameplateNtarget=softenemytarget`: 2
- `player=playertargettarget`: 1
- `nameplateN=nameplateN`: 1
- `mouseovertarget=nameplateN`: 1
- `nameplateN=softenemytargettarget`: 1
- `softenemy=target`: 1
- `playertarget=targettargettarget`: 1
- `playertargettarget=targettarget`: 1

## Change alerts

| build | cell | old | new | date |
|---|---|---|---|---|
| 70291 | ooc/world/solo/nameplateN/threat | C | N | 2026-10-08 |
| 70291 | ooc/world/solo/mouseover/threat | S | N | 2026-10-08 |

## One-shot token survey (v2.2 TokenSurvey, out of combat)

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

