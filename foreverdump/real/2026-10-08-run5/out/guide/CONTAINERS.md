# Container state (partial secrets)

Source: `addon:ForeverDumpLogDB.containers`, build 70245. Codes: A absent, N nil, S secret, K container (all clear), T container with secret contents, C clear, E error, R multiple returns. Counts are observations; a field missing in some observations of its container is absent (A) there. Only codes / flags / key names are stored, never values.

## Aura table, field by field (per context x unit class)

First aura of the unit (`GetAuraDataByIndex(u,1,filter)`; the UNIT_AURA `addedAuras[]` payload where the API errored or returned nothing). 'unobserved' = no aura table seen there (no aura present, API error, or no such unit).

| field | combat / player | combat / target NPC | combat / party/raid | combat / pet | combat / self via other token | ooc / player | ooc / target NPC | ooc / party/raid | ooc / pet | ooc / self via other token |
|---|---|---|---|---|---|---|---|---|---|---|
| *(table itself)* | E1 | E1 | unobserved | unobserved | E1 | K1 | unobserved | unobserved | unobserved | unobserved |
| `auraInstanceID` | unobserved | unobserved | unobserved | unobserved | unobserved | C1 | unobserved | unobserved | unobserved | unobserved |
| `isFromPlayerOrPlayerPet` | unobserved | unobserved | unobserved | unobserved | unobserved | C1 | unobserved | unobserved | unobserved | unobserved |
| `sourceUnit` | unobserved | unobserved | unobserved | unobserved | unobserved | C1 | unobserved | unobserved | unobserved | unobserved |
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
| UNIT_AURA `(payload)` | T11 | T10 | unobserved | unobserved | unobserved | K10 | unobserved | unobserved | unobserved | unobserved |
| UNIT_AURA `addedAuras` | S4 | S6 | unobserved | unobserved | unobserved | K6 | unobserved | unobserved | unobserved | unobserved |
| UNIT_AURA `removedAuraInstanceIDs` | S4 | S2 | unobserved | unobserved | unobserved | K7 | unobserved | unobserved | unobserved | unobserved |
| UNIT_AURA `updatedAuraInstanceIDs` | S4 | S2 | unobserved | unobserved | unobserved | unobserved | unobserved | unobserved | unobserved | unobserved |
| UNIT_AURA `isFullUpdate` | S11 | S10 | unobserved | unobserved | unobserved | C10 | unobserved | unobserved | unobserved | unobserved |

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
| combat | player | UNIT_AURA payload .addedAuras | S4 |
| combat | player | UNIT_AURA payload .isFullUpdate | S11 |
| combat | player | UNIT_AURA payload .removedAuraInstanceIDs | S4 |
| combat | player | UNIT_AURA payload .updatedAuraInstanceIDs | S4 |
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
| combat | target NPC | UNIT_AURA payload .addedAuras | S6 |
| combat | target NPC | UNIT_AURA payload .isFullUpdate | S10 |
| combat | target NPC | UNIT_AURA payload .removedAuraInstanceIDs | S2 |
| combat | target NPC | UNIT_AURA payload .updatedAuraInstanceIDs | S2 |
| ooc | player | GetAuraDataByIndex-iterate(HARMFUL) | C1 |
| ooc | player | GetAuraDataByIndex-iterate(HARMFUL\|PLAYER) | C1 |
| ooc | player | GetAuraDataByIndex-iterate(HELPFUL) | C1 |
| ooc | player | GetAuraDataByIndex-iterate(HELPFUL\|PLAYER) | C1 |
| ooc | player | GetAuraSlots returns u,HARMFUL | N1 |
| ooc | player | GetAuraSlots returns u,HARMFUL\|PLAYER | N1 |
| ooc | player | GetAuraSlots returns u,HELPFUL | R1 |
| ooc | player | GetAuraSlots returns u,HELPFUL\|PLAYER | R1 |
| ooc | player | GetUnitAuras HARMFUL | K1 |
| ooc | player | GetUnitAuras HARMFUL\|PLAYER | K1 |
| ooc | player | GetUnitAuras HELPFUL | K1 |
| ooc | player | GetUnitAuras HELPFUL\|PLAYER | K1 |
| ooc | player | UNIT_AURA payload .addedAuras | K6 |
| ooc | player | UNIT_AURA payload .isFullUpdate | C10 |
| ooc | player | UNIT_AURA payload .removedAuraInstanceIDs | K7 |

## Partial-secret containers (readable container, some secret fields)

| context | unit | probe | container | secret fields | clear fields |
|---|---|---|---|---|---|
| combat\|r0 | player | `C_Spell.GetSpellCooldown(spell)` | T | activeCategory, duration, modRate, startTime, timeUntilEndOfStartRecovery | isActive, isEnabled, isOnGCD |
| combat\|r0 | player | `C_Spell.GetSpellCooldownDuration(spell)` | T | GetElapsedDuration(), GetElapsedPercent(), GetEndTime(), GetModRate(), GetRemainingDuration(), GetRemainingPercent(), GetStartTime(), GetTotalDuration(), IsZero() | HasSecretValues() |
| combat\|r0 | player | `event:UNIT_AURA` | T | addedAuras, isFullUpdate, removedAuraInstanceIDs, updatedAuraInstanceIDs | - |
| combat\|r0 | target:hostile-npc | `event:UNIT_AURA` | T | addedAuras, isFullUpdate, removedAuraInstanceIDs, updatedAuraInstanceIDs | - |

## Errors (text only)

- `C_UnitAuras.GetAuraDataByIndex`: GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted by 'ForeverDump' Lua Taint: ForeverDump
- `C_UnitAuras.GetAuraSlots`: GetAuraSlots(): Auras cannot be accessed when secret while tainted by 'ForeverDump' Lua Taint: ForeverDump
- `C_UnitAuras.GetUnitAuras`: GetUnitAuras(): Auras cannot be accessed when secret while tainted by 'ForeverDump' Lua Taint: ForeverDump

## Change detection vs baseline

Baseline `/workspace/foreverdump/fixtures/baselines/70245/containers.json` (legacy:combatProbe cells + UNIT_AURA payload codes (addon <= 2.2.1, one level deep)) vs this capture (addon:ForeverDumpLogDB.containers) (different schema sources: new/gone expected): 1 state change(s), 296 new key(s), 1993 gone.
- `ooc|player|event:UNIT_AURA|addedAuras`: N/K -> K

## Per probe (every field)

<details><summary>combat|r0 / player (35 probes)</summary>

- `C_Spell.GetSpellCharges(gcd)`: **N1** 
- `C_Spell.GetSpellCharges(spell)`: **N3** 
- `C_Spell.GetSpellCooldown(gcd)`: **N1** 
- `C_Spell.GetSpellCooldown(spell)`: **T3** (len<=0, clear fields<=3, issecrettable=false3, canaccesstable=true3, hasanysecretvalues=true3)
  - `activeCategory`: S2 A1
  - `duration`: S3
  - `isActive`: C3
  - `isEnabled`: C3
  - `isOnGCD`: C2 A1
  - `modRate`: S3
  - `startTime`: S3
  - `timeUntilEndOfStartRecovery`: S2 A1
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
  - `ret5`: N3 S1
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
- `event:UNIT_AURA`: **T11** (len<=0, clear fields<=0, issecrettable=false11, canaccesstable=true11, hasanysecretvalues=true11)
  - `addedAuras`: A7 S4
  - `isFullUpdate`: S11
  - `removedAuraInstanceIDs`: A7 S4
  - `updatedAuraInstanceIDs`: A7 S4

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
- `UnitCastingDuration(u)`: **N1** 
- `UnitCastingInfo(u)`: **N1** 
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
- `event:UNIT_AURA`: **T10** (len<=0, clear fields<=0, issecrettable=false10, canaccesstable=true10, hasanysecretvalues=true10)
  - `addedAuras`: S6 A4
  - `isFullUpdate`: S10
  - `removedAuraInstanceIDs`: A8 S2
  - `updatedAuraInstanceIDs`: A8 S2

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
- `C_UnitAuras.GetAuraApplicationDisplayCount(u,iid)`: **C2** 
- `C_UnitAuras.GetAuraDataByIndex(u,1,HARMFUL)`: **N1** 
- `C_UnitAuras.GetAuraDataByIndex(u,1,HARMFUL|PLAYER)`: **N1** 
- `C_UnitAuras.GetAuraDataByIndex(u,1,HELPFUL)`: **K1** (len<=0, clear fields<=25, issecrettable=false1, canaccesstable=true1, hasanysecretvalues=false1)
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
  - `sourceUnit`: C1
  - `spellId`: C1
  - `timeMod`: C1
- `C_UnitAuras.GetAuraDataByIndex(u,1,HELPFUL|PLAYER)`: **K1** (len<=0, clear fields<=25, issecrettable=false1, canaccesstable=true1, hasanysecretvalues=false1)
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
  - `sourceUnit`: C1
  - `spellId`: C1
  - `timeMod`: C1
- `C_UnitAuras.GetAuraDuration(u,iid)`: **K2** (clear fields<=10, HasSecretValues=false2)
  - `GetElapsedDuration()`: C2
  - `GetElapsedPercent()`: C2
  - `GetEndTime()`: C2
  - `GetModRate()`: C2
  - `GetRemainingDuration()`: C2
  - `GetRemainingPercent()`: C2
  - `GetStartTime()`: C2
  - `GetTotalDuration()`: C2
  - `HasSecretValues()`: C2
  - `IsZero()`: C2
- `C_UnitAuras.GetAuraSlots(u,HARMFUL)`: **N1** 
- `C_UnitAuras.GetAuraSlots(u,HARMFUL|PLAYER)`: **N1** 
- `C_UnitAuras.GetAuraSlots(u,HELPFUL)`: **R1** (clear fields<=2)
  - `ret1`: N1
  - `ret2`: C1
  - `ret3`: C1
- `C_UnitAuras.GetAuraSlots(u,HELPFUL|PLAYER)`: **R1** (clear fields<=1)
  - `ret1`: N1
  - `ret2`: C1
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
  - `[].sourceUnit`: C1 A1
  - `[].spellId`: C2
  - `[].timeMod`: C2
- `C_UnitAuras.GetUnitAuras(u,HELPFUL|PLAYER)`: **K1** (len<=1, clear fields<=0, issecrettable=false1, canaccesstable=true1, hasanysecretvalues=false1)
  - `[]`: K1
  - `[].applications`: C1
  - `[].auraInstanceID`: C1
  - `[].canActivePlayerDispel`: C1
  - `[].canApplyAura`: C1
  - `[].dispelName`: C1
  - `[].duration`: C1
  - `[].expirationTime`: C1
  - `[].hideOnPartyFrames`: C1
  - `[].icon`: C1
  - `[].isBossAura`: C1
  - `[].isDPSRoleAura`: C1
  - `[].isFromPlayerOrPlayerPet`: C1
  - `[].isHarmful`: C1
  - `[].isHealerRoleAura`: C1
  - `[].isHelpful`: C1
  - `[].isNameplateOnly`: C1
  - `[].isRaid`: C1
  - `[].isStealable`: C1
  - `[].isTankRoleAura`: C1
  - `[].name`: C1
  - `[].nameplateShowAll`: C1
  - `[].nameplateShowPersonal`: C1
  - `[].points`: K1
  - `[].sourceUnit`: C1
  - `[].spellId`: C1
  - `[].timeMod`: C1
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
- `count:GetAuraDataByIndex-iterate(HELPFUL|PLAYER)`: **C1** (len<=1)
- `event:UNIT_AURA`: **K10** (len<=0, clear fields<=1, issecrettable=false10, canaccesstable=true10, hasanysecretvalues=false10)
  - `addedAuras`: K6 A4
  - `addedAuras[]`: K6
  - `addedAuras[].applications`: C6
  - `addedAuras[].auraInstanceID`: C6
  - `addedAuras[].canActivePlayerDispel`: C6
  - `addedAuras[].canApplyAura`: C6
  - `addedAuras[].dispelName`: A4 C2
  - `addedAuras[].duration`: C6
  - `addedAuras[].expirationTime`: C6
  - `addedAuras[].hideOnPartyFrames`: C6
  - `addedAuras[].icon`: C6
  - `addedAuras[].isBossAura`: C6
  - `addedAuras[].isDPSRoleAura`: C6
  - `addedAuras[].isFromPlayerOrPlayerPet`: C6
  - `addedAuras[].isHarmful`: C6
  - `addedAuras[].isHealerRoleAura`: C6
  - `addedAuras[].isHelpful`: C6
  - `addedAuras[].isNameplateOnly`: C6
  - `addedAuras[].isRaid`: C6
  - `addedAuras[].isStealable`: C6
  - `addedAuras[].isTankRoleAura`: C6
  - `addedAuras[].name`: C6
  - `addedAuras[].nameplateShowAll`: C6
  - `addedAuras[].nameplateShowPersonal`: C6
  - `addedAuras[].points`: K6
  - `addedAuras[].sourceUnit`: C6
  - `addedAuras[].spellId`: C6
  - `addedAuras[].timeMod`: C6
  - `isFullUpdate`: C10
  - `removedAuraInstanceIDs`: K7 A3
  - `removedAuraInstanceIDs[]`: C7

</details>

