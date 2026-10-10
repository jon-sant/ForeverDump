# Container state (partial secrets)

Source: `addon:ForeverDumpLogDB.containers`, build 70245. Codes: A absent, N nil, S secret, K container (all clear), T container with secret contents, C clear, E error, R multiple returns. Counts are observations; a field missing in some observations of its container is absent (A) there. Only codes / flags / key names are stored, never values.

## Aura table, field by field (per context x unit class)

First aura of the unit (`GetAuraDataByIndex(u,1,filter)`; the UNIT_AURA `addedAuras[]` payload where the API errored or returned nothing). 'unobserved' = no aura table seen there (no aura present, API error, or no such unit).

| field | combat / player | combat / target NPC | combat / party/raid | combat / pet | combat / self via other token | ooc / player | ooc / target NPC | ooc / party/raid | ooc / pet | ooc / self via other token |
|---|---|---|---|---|---|---|---|---|---|---|
| *(table itself)* | E1 | E1 | unobserved | unobserved | E1 | K1 | unobserved | unobserved | unobserved | unobserved |
| `auraInstanceID` | unobserved | unobserved | unobserved | unobserved | unobserved | C1 | unobserved | unobserved | unobserved | unobserved |
| `isFromPlayerOrPlayerPet` | unobserved | unobserved | unobserved | unobserved | unobserved | C1 | unobserved | unobserved | unobserved | unobserved |
| `sourceUnit` | unobserved | unobserved | unobserved | unobserved | unobserved | unobserved | unobserved | unobserved | unobserved | unobserved |
| `applications` | unobserved | unobserved | unobserved | unobserved | unobserved | C1 | unobserved | unobserved | unobserved | unobserved |
| `expirationTime` | unobserved | unobserved | unobserved | unobserved | unobserved | C1 | unobserved | unobserved | unobserved | unobserved |
| `duration` | unobserved | unobserved | unobserved | unobserved | unobserved | C1 | unobserved | unobserved | unobserved | unobserved |
| `dispelName` | unobserved | unobserved | unobserved | unobserved | unobserved | C1 | unobserved | unobserved | unobserved | unobserved |
| `spellId` | unobserved | unobserved | unobserved | unobserved | unobserved | C1 | unobserved | unobserved | unobserved | unobserved |
| `name` | unobserved | unobserved | unobserved | unobserved | unobserved | C1 | unobserved | unobserved | unobserved | unobserved |
| `icon` | unobserved | unobserved | unobserved | unobserved | unobserved | C1 | unobserved | unobserved | unobserved | unobserved |
| `isHelpful` | unobserved | unobserved | unobserved | unobserved | unobserved | C1 | unobserved | unobserved | unobserved | unobserved |
| `isHarmful` | unobserved | unobserved | unobserved | unobserved | unobserved | C1 | unobserved | unobserved | unobserved | unobserved |
| `canActivePlayerDispel` | unobserved | unobserved | unobserved | unobserved | unobserved | C1 | unobserved | unobserved | unobserved | unobserved |
| `points` | unobserved | unobserved | unobserved | unobserved | unobserved | K1 | unobserved | unobserved | unobserved | unobserved |
| UNIT_AURA `(payload)` | T12 | T2 | unobserved | unobserved | unobserved | K3 | unobserved | unobserved | unobserved | unobserved |
| UNIT_AURA `addedAuras` | S8 | S1 | unobserved | unobserved | unobserved | K2 | unobserved | unobserved | unobserved | unobserved |
| UNIT_AURA `removedAuraInstanceIDs` | S5 | S1 | unobserved | unobserved | unobserved | K2 | unobserved | unobserved | unobserved | unobserved |
| UNIT_AURA `updatedAuraInstanceIDs` | S2 | unobserved | unobserved | unobserved | unobserved | unobserved | unobserved | unobserved | unobserved | unobserved |
| UNIT_AURA `isFullUpdate` | S12 | S2 | unobserved | unobserved | unobserved | C3 | unobserved | unobserved | unobserved | unobserved |

Sources per cell: combat/player: C_UnitAuras.GetAuraDataByIndex(u,1,HELPFUL) (player); combat/self via other token: C_UnitAuras.GetAuraDataByIndex(u,1,HELPFUL) (targettarget:self); combat/target NPC: C_UnitAuras.GetAuraDataByIndex(u,1,HELPFUL) (target:hostile-npc); ooc/player: C_UnitAuras.GetAuraDataByIndex(u,1,HELPFUL) (player)

## Can a clear aura COUNT be had?

`C` = the count / slot list came back clear, `S` = secret, `E` = the call errored, `N` = nil (none / nothing added). For the UNIT_AURA payload a field that is nil vs secret is itself a clear yes/no signal.

| context | unit class | method | codes |
|---|---|---|---|
| combat | player | GetAuraDataByIndex-iterate(HARMFUL) | E1 |
| combat | player | GetAuraDataByIndex-iterate(HARMFUL\|PLAYER) | E1 |
| combat | player | GetAuraDataByIndex-iterate(HELPFUL) | E1 |
| combat | player | GetAuraDataByIndex-iterate(HELPFUL\|PLAYER) | E1 |
| combat | player | GetAuraSlots returns u,HARMFUL | E1 |
| combat | player | GetAuraSlots returns u,HARMFUL\|PLAYER | E1 |
| combat | player | GetAuraSlots returns u,HELPFUL | E1 |
| combat | player | GetAuraSlots returns u,HELPFUL\|PLAYER | E1 |
| combat | player | GetUnitAuras HARMFUL | E1 |
| combat | player | GetUnitAuras HARMFUL\|PLAYER | E1 |
| combat | player | GetUnitAuras HELPFUL | E1 |
| combat | player | GetUnitAuras HELPFUL\|PLAYER | E1 |
| combat | player | UNIT_AURA payload .addedAuras | S8 |
| combat | player | UNIT_AURA payload .isFullUpdate | S12 |
| combat | player | UNIT_AURA payload .removedAuraInstanceIDs | S5 |
| combat | player | UNIT_AURA payload .updatedAuraInstanceIDs | S2 |
| combat | self via other token | GetAuraDataByIndex-iterate(HARMFUL) | E1 |
| combat | self via other token | GetAuraDataByIndex-iterate(HARMFUL\|PLAYER) | E1 |
| combat | self via other token | GetAuraDataByIndex-iterate(HELPFUL) | E1 |
| combat | self via other token | GetAuraDataByIndex-iterate(HELPFUL\|PLAYER) | E1 |
| combat | self via other token | GetAuraSlots returns u,HARMFUL | E1 |
| combat | self via other token | GetAuraSlots returns u,HARMFUL\|PLAYER | E1 |
| combat | self via other token | GetAuraSlots returns u,HELPFUL | E1 |
| combat | self via other token | GetAuraSlots returns u,HELPFUL\|PLAYER | E1 |
| combat | self via other token | GetUnitAuras HARMFUL | E1 |
| combat | self via other token | GetUnitAuras HARMFUL\|PLAYER | E1 |
| combat | self via other token | GetUnitAuras HELPFUL | E1 |
| combat | self via other token | GetUnitAuras HELPFUL\|PLAYER | E1 |
| combat | target NPC | GetAuraDataByIndex-iterate(HARMFUL) | E1 |
| combat | target NPC | GetAuraDataByIndex-iterate(HARMFUL\|PLAYER) | E1 |
| combat | target NPC | GetAuraDataByIndex-iterate(HELPFUL) | E1 |
| combat | target NPC | GetAuraDataByIndex-iterate(HELPFUL\|PLAYER) | E1 |
| combat | target NPC | GetAuraSlots returns u,HARMFUL | E1 |
| combat | target NPC | GetAuraSlots returns u,HARMFUL\|PLAYER | E1 |
| combat | target NPC | GetAuraSlots returns u,HELPFUL | E1 |
| combat | target NPC | GetAuraSlots returns u,HELPFUL\|PLAYER | E1 |
| combat | target NPC | GetUnitAuras HARMFUL | E1 |
| combat | target NPC | GetUnitAuras HARMFUL\|PLAYER | E1 |
| combat | target NPC | GetUnitAuras HELPFUL | E1 |
| combat | target NPC | GetUnitAuras HELPFUL\|PLAYER | E1 |
| combat | target NPC | UNIT_AURA payload .addedAuras | S1 |
| combat | target NPC | UNIT_AURA payload .isFullUpdate | S2 |
| combat | target NPC | UNIT_AURA payload .removedAuraInstanceIDs | S1 |
| ooc | player | GetAuraDataByIndex-iterate(HARMFUL) | C1 |
| ooc | player | GetAuraDataByIndex-iterate(HARMFUL\|PLAYER) | C1 |
| ooc | player | GetAuraDataByIndex-iterate(HELPFUL) | C1 |
| ooc | player | GetAuraDataByIndex-iterate(HELPFUL\|PLAYER) | C1 |
| ooc | player | GetAuraSlots returns u,HARMFUL | N1 |
| ooc | player | GetAuraSlots returns u,HARMFUL\|PLAYER | N1 |
| ooc | player | GetAuraSlots returns u,HELPFUL | R1 |
| ooc | player | GetAuraSlots returns u,HELPFUL\|PLAYER | N1 |
| ooc | player | GetUnitAuras HARMFUL | K1 |
| ooc | player | GetUnitAuras HARMFUL\|PLAYER | K1 |
| ooc | player | GetUnitAuras HELPFUL | K1 |
| ooc | player | GetUnitAuras HELPFUL\|PLAYER | K1 |
| ooc | player | UNIT_AURA payload .addedAuras | K2 |
| ooc | player | UNIT_AURA payload .isFullUpdate | C3 |
| ooc | player | UNIT_AURA payload .removedAuraInstanceIDs | K2 |

## Partial-secret containers (readable container, some secret fields)

| context | unit | probe | container | secret fields | clear fields |
|---|---|---|---|---|---|
| combat\|r0 | player | `C_Spell.GetSpellCooldown(spell)` | T | duration, modRate, startTime | isActive, isEnabled |
| combat\|r0 | player | `C_Spell.GetSpellCooldownDuration(spell)` | T | GetElapsedDuration(), GetElapsedPercent(), GetEndTime(), GetModRate(), GetRemainingDuration(), GetRemainingPercent(), GetStartTime(), GetTotalDuration(), IsZero() | HasSecretValues() |
| combat\|r0 | player | `event:UNIT_AURA` | T | addedAuras, isFullUpdate, removedAuraInstanceIDs, updatedAuraInstanceIDs | - |
| combat\|r0 | target:hostile-npc | `UnitCastingDuration(u)` | T | GetElapsedDuration(), GetElapsedPercent(), GetEndTime(), GetModRate(), GetRemainingDuration(), GetRemainingPercent(), GetStartTime(), GetTotalDuration(), IsZero() | HasSecretValues() |
| combat\|r0 | target:hostile-npc | `UnitCastingInfo(u)` | R | ret1, ret2, ret3, ret4, ret5, ret7, ret8, ret9 | ret10, ret11, ret6 |
| combat\|r0 | target:hostile-npc | `event:UNIT_AURA` | T | addedAuras, isFullUpdate, removedAuraInstanceIDs | - |

## Errors (text only)

- `C_UnitAuras.GetAuraDataByIndex`: GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted by 'ForeverDump' Lua Taint: ForeverDump
- `C_UnitAuras.GetAuraSlots`: GetAuraSlots(): Auras cannot be accessed when secret while tainted by 'ForeverDump' Lua Taint: ForeverDump
- `C_UnitAuras.GetUnitAuras`: GetUnitAuras(): Auras cannot be accessed when secret while tainted by 'ForeverDump' Lua Taint: ForeverDump

## Change detection vs baseline

Baseline `/workspace/foreverdump/fixtures/baselines/70245/containers.json` (legacy:combatProbe cells + UNIT_AURA payload codes (addon <= 2.2.1, one level deep)) vs this capture (addon:ForeverDumpLogDB.containers) (different schema sources: new/gone expected): 1 state change(s), 256 new key(s), 1993 gone.
- `ooc|player|event:UNIT_AURA|addedAuras`: N/K -> K

## Per probe (every field)

<details><summary>combat|r0 / player (35 probes)</summary>

- `C_Spell.GetSpellCharges(gcd)`: **N1** 
- `C_Spell.GetSpellCharges(spell)`: **N3** 
- `C_Spell.GetSpellCooldown(gcd)`: **N1** 
- `C_Spell.GetSpellCooldown(spell)`: **T3** (len<=0, clear fields<=2, issecrettable=false3, canaccesstable=true3, hasanysecretvalues=true3)
  - `duration`: S3
  - `isActive`: C3
  - `isEnabled`: C3
  - `modRate`: S3
  - `startTime`: S3
- `C_Spell.GetSpellCooldownDuration(gcd)`: **N1** 
- `C_Spell.GetSpellCooldownDuration(spell)`: **T3** (clear fields<=1, HasSecretValues=true3)
  - `GetElapsedDuration()`: S3
  - `GetElapsedPercent()`: S3
  - `GetEndTime()`: S3
  - `GetModRate()`: S3
  - `GetRemainingDuration()`: S3
  - `GetRemainingPercent()`: S3
  - `GetStartTime()`: S3
  - `GetTotalDuration()`: S3
  - `HasSecretValues()`: C3
  - `IsZero()`: S3
- `C_Spell.GetSpellInfo(gcd)`: **N1** 
- `C_Spell.GetSpellInfo(spell)`: **K3** (len<=0, clear fields<=7, issecrettable=false3, canaccesstable=true3, hasanysecretvalues=false3)
  - `castTime`: C3
  - `iconID`: C3
  - `maxRange`: C3
  - `minRange`: C3
  - `name`: C3
  - `originalIconID`: C3
  - `spellID`: C3
- `C_UnitAuras.GetAuraDataByIndex(u,1,HARMFUL)`: **E1** 
- `C_UnitAuras.GetAuraDataByIndex(u,1,HARMFUL|PLAYER)`: **E1** 
- `C_UnitAuras.GetAuraDataByIndex(u,1,HELPFUL)`: **E1** 
- `C_UnitAuras.GetAuraDataByIndex(u,1,HELPFUL|PLAYER)`: **E1** 
- `C_UnitAuras.GetAuraSlots(u,HARMFUL)`: **E1** 
- `C_UnitAuras.GetAuraSlots(u,HARMFUL|PLAYER)`: **E1** 
- `C_UnitAuras.GetAuraSlots(u,HELPFUL)`: **E1** 
- `C_UnitAuras.GetAuraSlots(u,HELPFUL|PLAYER)`: **E1** 
- `C_UnitAuras.GetUnitAuras(u,HARMFUL)`: **E1** 
- `C_UnitAuras.GetUnitAuras(u,HARMFUL|PLAYER)`: **E1** 
- `C_UnitAuras.GetUnitAuras(u,HELPFUL)`: **E1** 
- `C_UnitAuras.GetUnitAuras(u,HELPFUL|PLAYER)`: **E1** 
- `GetTotemInfo(slot)`: **R4** (clear fields<=0)
  - `ret1`: S4
  - `ret2`: S4
  - `ret3`: S4
  - `ret4`: S4
  - `ret5`: N4
  - `ret6`: S4
  - `ret7`: S4
- `UnitCastingDuration(u)`: **N1** 
- `UnitCastingInfo(u)`: **N1** 
- `UnitChannelDuration(u)`: **N1** 
- `UnitChannelInfo(u)`: **N1** 
- `UnitGUID(u)`: **C1** 
- `UnitHealth(u)`: **S1** 
- `UnitHealthMax(u)`: **C1** 
- `UnitName(u)`: **R1** (clear fields<=2)
  - `ret1`: C1
  - `ret2`: C1
- `UnitPower(u)`: **S1** 
- `count:GetAuraDataByIndex-iterate(HARMFUL)`: **E1** 
- `count:GetAuraDataByIndex-iterate(HARMFUL|PLAYER)`: **E1** 
- `count:GetAuraDataByIndex-iterate(HELPFUL)`: **E1** 
- `count:GetAuraDataByIndex-iterate(HELPFUL|PLAYER)`: **E1** 
- `event:UNIT_AURA`: **T12** (len<=0, clear fields<=0, issecrettable=false12, canaccesstable=true12, hasanysecretvalues=true12)
  - `addedAuras`: S8 A4
  - `isFullUpdate`: S12
  - `removedAuraInstanceIDs`: A7 S5
  - `updatedAuraInstanceIDs`: A10 S2

</details>

<details><summary>combat|r0 / target:hostile-npc (26 probes)</summary>

- `C_UnitAuras.GetAuraDataByIndex(u,1,HARMFUL)`: **E1** 
- `C_UnitAuras.GetAuraDataByIndex(u,1,HARMFUL|PLAYER)`: **E1** 
- `C_UnitAuras.GetAuraDataByIndex(u,1,HELPFUL)`: **E1** 
- `C_UnitAuras.GetAuraDataByIndex(u,1,HELPFUL|PLAYER)`: **E1** 
- `C_UnitAuras.GetAuraSlots(u,HARMFUL)`: **E1** 
- `C_UnitAuras.GetAuraSlots(u,HARMFUL|PLAYER)`: **E1** 
- `C_UnitAuras.GetAuraSlots(u,HELPFUL)`: **E1** 
- `C_UnitAuras.GetAuraSlots(u,HELPFUL|PLAYER)`: **E1** 
- `C_UnitAuras.GetUnitAuras(u,HARMFUL)`: **E1** 
- `C_UnitAuras.GetUnitAuras(u,HARMFUL|PLAYER)`: **E1** 
- `C_UnitAuras.GetUnitAuras(u,HELPFUL)`: **E1** 
- `C_UnitAuras.GetUnitAuras(u,HELPFUL|PLAYER)`: **E1** 
- `UnitCastingDuration(u)`: **T1** (clear fields<=1, HasSecretValues=true1)
  - `GetElapsedDuration()`: S1
  - `GetElapsedPercent()`: S1
  - `GetEndTime()`: S1
  - `GetModRate()`: S1
  - `GetRemainingDuration()`: S1
  - `GetRemainingPercent()`: S1
  - `GetStartTime()`: S1
  - `GetTotalDuration()`: S1
  - `HasSecretValues()`: C1
  - `IsZero()`: S1
- `UnitCastingInfo(u)`: **R1** (clear fields<=3)
  - `ret1`: S1
  - `ret10`: C1
  - `ret11`: C1
  - `ret2`: S1
  - `ret3`: S1
  - `ret4`: S1
  - `ret5`: S1
  - `ret6`: C1
  - `ret7`: S1
  - `ret8`: S1
  - `ret9`: S1
- `UnitChannelDuration(u)`: **N1** 
- `UnitChannelInfo(u)`: **N1** 
- `UnitGUID(u)`: **C1** 
- `UnitHealth(u)`: **S1** 
- `UnitHealthMax(u)`: **S1** 
- `UnitName(u)`: **R1** (clear fields<=1)
  - `ret1`: C1
  - `ret2`: N1
- `UnitPower(u)`: **S1** 
- `count:GetAuraDataByIndex-iterate(HARMFUL)`: **E1** 
- `count:GetAuraDataByIndex-iterate(HARMFUL|PLAYER)`: **E1** 
- `count:GetAuraDataByIndex-iterate(HELPFUL)`: **E1** 
- `count:GetAuraDataByIndex-iterate(HELPFUL|PLAYER)`: **E1** 
- `event:UNIT_AURA`: **T2** (len<=0, clear fields<=0, issecrettable=false2, canaccesstable=true2, hasanysecretvalues=true2)
  - `addedAuras`: S1 A1
  - `isFullUpdate`: S2
  - `removedAuraInstanceIDs`: S1 A1

</details>

<details><summary>combat|r0 / targettarget:self (25 probes)</summary>

- `C_UnitAuras.GetAuraDataByIndex(u,1,HARMFUL)`: **E1** 
- `C_UnitAuras.GetAuraDataByIndex(u,1,HARMFUL|PLAYER)`: **E1** 
- `C_UnitAuras.GetAuraDataByIndex(u,1,HELPFUL)`: **E1** 
- `C_UnitAuras.GetAuraDataByIndex(u,1,HELPFUL|PLAYER)`: **E1** 
- `C_UnitAuras.GetAuraSlots(u,HARMFUL)`: **E1** 
- `C_UnitAuras.GetAuraSlots(u,HARMFUL|PLAYER)`: **E1** 
- `C_UnitAuras.GetAuraSlots(u,HELPFUL)`: **E1** 
- `C_UnitAuras.GetAuraSlots(u,HELPFUL|PLAYER)`: **E1** 
- `C_UnitAuras.GetUnitAuras(u,HARMFUL)`: **E1** 
- `C_UnitAuras.GetUnitAuras(u,HARMFUL|PLAYER)`: **E1** 
- `C_UnitAuras.GetUnitAuras(u,HELPFUL)`: **E1** 
- `C_UnitAuras.GetUnitAuras(u,HELPFUL|PLAYER)`: **E1** 
- `UnitCastingDuration(u)`: **N1** 
- `UnitCastingInfo(u)`: **N1** 
- `UnitChannelDuration(u)`: **N1** 
- `UnitChannelInfo(u)`: **N1** 
- `UnitGUID(u)`: **C1** 
- `UnitHealth(u)`: **S1** 
- `UnitHealthMax(u)`: **C1** 
- `UnitName(u)`: **R1** (clear fields<=2)
  - `ret1`: C1
  - `ret2`: C1
- `UnitPower(u)`: **S1** 
- `count:GetAuraDataByIndex-iterate(HARMFUL)`: **E1** 
- `count:GetAuraDataByIndex-iterate(HARMFUL|PLAYER)`: **E1** 
- `count:GetAuraDataByIndex-iterate(HELPFUL)`: **E1** 
- `count:GetAuraDataByIndex-iterate(HELPFUL|PLAYER)`: **E1** 

</details>

<details><summary>ooc / player (33 probes)</summary>

- `C_Spell.GetSpellCharges(gcd)`: **N1** 
- `C_Spell.GetSpellCooldown(gcd)`: **N1** 
- `C_Spell.GetSpellCooldownDuration(gcd)`: **N1** 
- `C_Spell.GetSpellInfo(gcd)`: **N1** 
- `C_UnitAuras.GetAuraApplicationDisplayCount(u,iid)`: **C1** 
- `C_UnitAuras.GetAuraDataByIndex(u,1,HARMFUL)`: **N1** 
- `C_UnitAuras.GetAuraDataByIndex(u,1,HARMFUL|PLAYER)`: **N1** 
- `C_UnitAuras.GetAuraDataByIndex(u,1,HELPFUL)`: **K1** (len<=0, clear fields<=24, issecrettable=false1, canaccesstable=true1, hasanysecretvalues=false1)
  - `applications`: C1
  - `auraInstanceID`: C1
  - `canActivePlayerDispel`: C1
  - `canApplyAura`: C1
  - `dispelName`: C1
  - `duration`: C1
  - `expirationTime`: C1
  - `hideOnPartyFrames`: C1
  - `icon`: C1
  - `isBossAura`: C1
  - `isDPSRoleAura`: C1
  - `isFromPlayerOrPlayerPet`: C1
  - `isHarmful`: C1
  - `isHealerRoleAura`: C1
  - `isHelpful`: C1
  - `isNameplateOnly`: C1
  - `isRaid`: C1
  - `isStealable`: C1
  - `isTankRoleAura`: C1
  - `name`: C1
  - `nameplateShowAll`: C1
  - `nameplateShowPersonal`: C1
  - `points`: K1
  - `spellId`: C1
  - `timeMod`: C1
- `C_UnitAuras.GetAuraDataByIndex(u,1,HELPFUL|PLAYER)`: **N1** 
- `C_UnitAuras.GetAuraDuration(u,iid)`: **K1** (clear fields<=10, HasSecretValues=false1)
  - `GetElapsedDuration()`: C1
  - `GetElapsedPercent()`: C1
  - `GetEndTime()`: C1
  - `GetModRate()`: C1
  - `GetRemainingDuration()`: C1
  - `GetRemainingPercent()`: C1
  - `GetStartTime()`: C1
  - `GetTotalDuration()`: C1
  - `HasSecretValues()`: C1
  - `IsZero()`: C1
- `C_UnitAuras.GetAuraSlots(u,HARMFUL)`: **N1** 
- `C_UnitAuras.GetAuraSlots(u,HARMFUL|PLAYER)`: **N1** 
- `C_UnitAuras.GetAuraSlots(u,HELPFUL)`: **R1** (clear fields<=2)
  - `ret1`: N1
  - `ret2`: C1
  - `ret3`: C1
- `C_UnitAuras.GetAuraSlots(u,HELPFUL|PLAYER)`: **N1** 
- `C_UnitAuras.GetUnitAuras(u,HARMFUL)`: **K1** (len<=0, clear fields<=0, issecrettable=false1, canaccesstable=true1)
- `C_UnitAuras.GetUnitAuras(u,HARMFUL|PLAYER)`: **K1** (len<=0, clear fields<=0, issecrettable=false1, canaccesstable=true1)
- `C_UnitAuras.GetUnitAuras(u,HELPFUL)`: **K1** (len<=2, clear fields<=0, issecrettable=false1, canaccesstable=true1, hasanysecretvalues=false1)
  - `[]`: K2
  - `[].applications`: C2
  - `[].auraInstanceID`: C2
  - `[].canActivePlayerDispel`: C2
  - `[].canApplyAura`: C2
  - `[].dispelName`: C2
  - `[].duration`: C2
  - `[].expirationTime`: C2
  - `[].hideOnPartyFrames`: C2
  - `[].icon`: C2
  - `[].isBossAura`: C2
  - `[].isDPSRoleAura`: C2
  - `[].isFromPlayerOrPlayerPet`: C2
  - `[].isHarmful`: C2
  - `[].isHealerRoleAura`: C2
  - `[].isHelpful`: C2
  - `[].isNameplateOnly`: C2
  - `[].isRaid`: C2
  - `[].isStealable`: C2
  - `[].isTankRoleAura`: C2
  - `[].name`: C2
  - `[].nameplateShowAll`: C2
  - `[].nameplateShowPersonal`: C2
  - `[].points`: K2
  - `[].spellId`: C2
  - `[].timeMod`: C2
- `C_UnitAuras.GetUnitAuras(u,HELPFUL|PLAYER)`: **K1** (len<=0, clear fields<=0, issecrettable=false1, canaccesstable=true1)
- `GetTotemInfo(slot)`: **R4** (clear fields<=6)
  - `ret1`: C4
  - `ret2`: C4
  - `ret3`: C4
  - `ret4`: C4
  - `ret5`: N4
  - `ret6`: C4
  - `ret7`: C4
- `UnitCastingDuration(u)`: **N1** 
- `UnitCastingInfo(u)`: **N1** 
- `UnitChannelDuration(u)`: **N1** 
- `UnitChannelInfo(u)`: **N1** 
- `UnitGUID(u)`: **C1** 
- `UnitHealth(u)`: **S1** 
- `UnitHealthMax(u)`: **C1** 
- `UnitName(u)`: **R1** (clear fields<=2)
  - `ret1`: C1
  - `ret2`: C1
- `UnitPower(u)`: **S1** 
- `count:GetAuraDataByIndex-iterate(HARMFUL)`: **C1** (len<=0)
- `count:GetAuraDataByIndex-iterate(HARMFUL|PLAYER)`: **C1** (len<=0)
- `count:GetAuraDataByIndex-iterate(HELPFUL)`: **C1** (len<=2)
- `count:GetAuraDataByIndex-iterate(HELPFUL|PLAYER)`: **C1** (len<=0)
- `event:UNIT_AURA`: **K3** (len<=0, clear fields<=1, issecrettable=false3, canaccesstable=true3, hasanysecretvalues=false3)
  - `addedAuras`: K2 A1
  - `addedAuras[]`: K2
  - `addedAuras[].applications`: C2
  - `addedAuras[].auraInstanceID`: C2
  - `addedAuras[].canActivePlayerDispel`: C2
  - `addedAuras[].canApplyAura`: C2
  - `addedAuras[].dispelName`: C1 A1
  - `addedAuras[].duration`: C2
  - `addedAuras[].expirationTime`: C2
  - `addedAuras[].hideOnPartyFrames`: C2
  - `addedAuras[].icon`: C2
  - `addedAuras[].isBossAura`: C2
  - `addedAuras[].isDPSRoleAura`: C2
  - `addedAuras[].isFromPlayerOrPlayerPet`: C2
  - `addedAuras[].isHarmful`: C2
  - `addedAuras[].isHealerRoleAura`: C2
  - `addedAuras[].isHelpful`: C2
  - `addedAuras[].isNameplateOnly`: C2
  - `addedAuras[].isRaid`: C2
  - `addedAuras[].isStealable`: C2
  - `addedAuras[].isTankRoleAura`: C2
  - `addedAuras[].name`: C2
  - `addedAuras[].nameplateShowAll`: C2
  - `addedAuras[].nameplateShowPersonal`: C2
  - `addedAuras[].points`: K2
  - `addedAuras[].sourceUnit`: C2
  - `addedAuras[].spellId`: C2
  - `addedAuras[].timeMod`: C2
  - `isFullUpdate`: C3
  - `removedAuraInstanceIDs`: K2 A1
  - `removedAuraInstanceIDs[]`: C2

</details>

