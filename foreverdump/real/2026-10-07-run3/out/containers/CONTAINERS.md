# Container state (partial secrets)

Source: `legacy:combatProbe cells + UNIT_AURA payload codes (addon <= 2.2.1, one level deep)`, build 70245. Codes: A absent, N nil, S secret, K container (all clear), T container with secret contents, C clear, E error, R multiple returns. Counts are observations; a field missing in some observations of its container is absent (A) there. Only codes / flags / key names are stored, never values.

## Aura table, field by field (per context x unit class)

First aura of the unit (`GetAuraDataByIndex(u,1,filter)`; the UNIT_AURA `addedAuras[]` payload where the API errored or returned nothing). 'unobserved' = no aura table seen there (no aura present, API error, or no such unit).

| field | combat / player | combat / target NPC | combat / party/raid | combat / pet | combat / self via other token | ooc / player | ooc / target NPC | ooc / party/raid | ooc / pet | ooc / self via other token |
|---|---|---|---|---|---|---|---|---|---|---|
| *(table itself)* | E14 | E20 | unobserved | unobserved | E13 | K12 | N15 | unobserved | unobserved | K9 |
| `auraInstanceID` | unobserved | unobserved | unobserved | unobserved | unobserved | C12 | unobserved | unobserved | unobserved | C9 |
| `isFromPlayerOrPlayerPet` | unobserved | unobserved | unobserved | unobserved | unobserved | C12 | unobserved | unobserved | unobserved | C9 |
| `sourceUnit` | unobserved | unobserved | unobserved | unobserved | unobserved | C2 | unobserved | unobserved | unobserved | C2 |
| `applications` | unobserved | unobserved | unobserved | unobserved | unobserved | C12 | unobserved | unobserved | unobserved | C9 |
| `expirationTime` | unobserved | unobserved | unobserved | unobserved | unobserved | C12 | unobserved | unobserved | unobserved | C9 |
| `duration` | unobserved | unobserved | unobserved | unobserved | unobserved | C12 | unobserved | unobserved | unobserved | C9 |
| `dispelName` | unobserved | unobserved | unobserved | unobserved | unobserved | C12 | unobserved | unobserved | unobserved | C9 |
| `spellId` | unobserved | unobserved | unobserved | unobserved | unobserved | C12 | unobserved | unobserved | unobserved | C9 |
| `name` | unobserved | unobserved | unobserved | unobserved | unobserved | C12 | unobserved | unobserved | unobserved | C9 |
| `icon` | unobserved | unobserved | unobserved | unobserved | unobserved | C12 | unobserved | unobserved | unobserved | C9 |
| `isHelpful` | unobserved | unobserved | unobserved | unobserved | unobserved | C12 | unobserved | unobserved | unobserved | C9 |
| `isHarmful` | unobserved | unobserved | unobserved | unobserved | unobserved | C12 | unobserved | unobserved | unobserved | C9 |
| `canActivePlayerDispel` | unobserved | unobserved | unobserved | unobserved | unobserved | C12 | unobserved | unobserved | unobserved | C9 |
| `points` | unobserved | unobserved | unobserved | unobserved | unobserved | K12 | unobserved | unobserved | unobserved | K9 |
| UNIT_AURA `(payload)` | T25 | T12 | unobserved | unobserved | T37 | K3 | unobserved | unobserved | unobserved | K3 |
| UNIT_AURA `addedAuras` | S15 N10 | S7 N5 | unobserved | unobserved | S21 N16 | N2 K1 | unobserved | unobserved | unobserved | N2 K1 |
| UNIT_AURA `removedAuraInstanceIDs` | N13 S12 | N7 S5 | unobserved | unobserved | N20 S17 | K3 | unobserved | unobserved | unobserved | K3 |
| UNIT_AURA `updatedAuraInstanceIDs` | N19 S6 | N12 | unobserved | unobserved | N26 S11 | N3 | unobserved | unobserved | unobserved | N3 |
| UNIT_AURA `isFullUpdate` | S25 | S12 | unobserved | unobserved | S37 | C3 | unobserved | unobserved | unobserved | C3 |

Sources per cell: combat/player: aura:GetAuraDataByIndex[HELPFUL] (player); combat/self via other token: aura:GetAuraDataByIndex[HELPFUL] (focus:self, target:self, targettarget:self); combat/target NPC: aura:GetAuraDataByIndex[HELPFUL] (focustarget:hostile-npc, nameplate:hostile-npc, softenemy:hostile-npc, target:hostile-npc); ooc/player: aura:GetAuraDataByIndex[HELPFUL] (player); ooc/self via other token: aura:GetAuraDataByIndex[HELPFUL] (focus:self, target:self); ooc/target NPC: aura:GetAuraDataByIndex[HELPFUL] (nameplate:hostile-npc, target:hostile-npc)

## Can a clear aura COUNT be had?

`C` = the count / slot list came back clear, `S` = secret, `E` = the call errored, `N` = nil (none / nothing added). For the UNIT_AURA payload a field that is nil vs secret is itself a clear yes/no signal.

| context | unit class | method | codes |
|---|---|---|---|
| combat | player | GetAuraSlots returns HARMFUL | E14 |
| combat | player | GetAuraSlots returns HARMFUL\|PLAYER | E14 |
| combat | player | GetAuraSlots returns HARMFUL\|RAID | E14 |
| combat | player | GetAuraSlots returns HARMFUL\|RAID_PLAYER_DISPELLABLE | E14 |
| combat | player | GetAuraSlots returns HELPFUL | E14 |
| combat | player | GetAuraSlots returns HELPFUL\|PLAYER | E14 |
| combat | player | GetUnitAuras HARMFUL | E14 |
| combat | player | GetUnitAuras HARMFUL\|PLAYER | E14 |
| combat | player | GetUnitAuras HARMFUL\|RAID | E14 |
| combat | player | GetUnitAuras HARMFUL\|RAID_PLAYER_DISPELLABLE | E14 |
| combat | player | GetUnitAuras HELPFUL | E14 |
| combat | player | GetUnitAuras HELPFUL\|PLAYER | E14 |
| combat | player | UNIT_AURA payload .addedAuras | S15 N10 |
| combat | player | UNIT_AURA payload .isFullUpdate | S25 |
| combat | player | UNIT_AURA payload .removedAuraInstanceIDs | N13 S12 |
| combat | player | UNIT_AURA payload .updatedAuraInstanceIDs | N19 S6 |
| combat | self via other token | GetAuraSlots returns HARMFUL | E13 |
| combat | self via other token | GetAuraSlots returns HARMFUL\|PLAYER | E13 |
| combat | self via other token | GetAuraSlots returns HARMFUL\|RAID | E13 |
| combat | self via other token | GetAuraSlots returns HARMFUL\|RAID_PLAYER_DISPELLABLE | E13 |
| combat | self via other token | GetAuraSlots returns HELPFUL | E13 |
| combat | self via other token | GetAuraSlots returns HELPFUL\|PLAYER | E13 |
| combat | self via other token | GetUnitAuras HARMFUL | E13 |
| combat | self via other token | GetUnitAuras HARMFUL\|PLAYER | E13 |
| combat | self via other token | GetUnitAuras HARMFUL\|RAID | E13 |
| combat | self via other token | GetUnitAuras HARMFUL\|RAID_PLAYER_DISPELLABLE | E13 |
| combat | self via other token | GetUnitAuras HELPFUL | E13 |
| combat | self via other token | GetUnitAuras HELPFUL\|PLAYER | E13 |
| combat | self via other token | UNIT_AURA payload .addedAuras | S21 N16 |
| combat | self via other token | UNIT_AURA payload .isFullUpdate | S37 |
| combat | self via other token | UNIT_AURA payload .removedAuraInstanceIDs | N20 S17 |
| combat | self via other token | UNIT_AURA payload .updatedAuraInstanceIDs | N26 S11 |
| combat | target NPC | GetAuraSlots returns HARMFUL | E20 |
| combat | target NPC | GetAuraSlots returns HARMFUL\|PLAYER | E20 |
| combat | target NPC | GetAuraSlots returns HARMFUL\|RAID | E20 |
| combat | target NPC | GetAuraSlots returns HARMFUL\|RAID_PLAYER_DISPELLABLE | E20 |
| combat | target NPC | GetAuraSlots returns HELPFUL | E20 |
| combat | target NPC | GetAuraSlots returns HELPFUL\|PLAYER | E20 |
| combat | target NPC | GetUnitAuras HARMFUL | E20 |
| combat | target NPC | GetUnitAuras HARMFUL\|PLAYER | E20 |
| combat | target NPC | GetUnitAuras HARMFUL\|RAID | E20 |
| combat | target NPC | GetUnitAuras HARMFUL\|RAID_PLAYER_DISPELLABLE | E20 |
| combat | target NPC | GetUnitAuras HELPFUL | E20 |
| combat | target NPC | GetUnitAuras HELPFUL\|PLAYER | E20 |
| combat | target NPC | UNIT_AURA payload .addedAuras | S7 N5 |
| combat | target NPC | UNIT_AURA payload .isFullUpdate | S12 |
| combat | target NPC | UNIT_AURA payload .removedAuraInstanceIDs | N7 S5 |
| combat | target NPC | UNIT_AURA payload .updatedAuraInstanceIDs | N12 |
| ooc | player | GetAuraSlots returns HARMFUL | N12 |
| ooc | player | GetAuraSlots returns HARMFUL\|PLAYER | N12 |
| ooc | player | GetAuraSlots returns HARMFUL\|RAID | N12 |
| ooc | player | GetAuraSlots returns HARMFUL\|RAID_PLAYER_DISPELLABLE | N12 |
| ooc | player | GetAuraSlots returns HELPFUL | R12 |
| ooc | player | GetAuraSlots returns HELPFUL\|PLAYER | R12 |
| ooc | player | GetAuraSlots(HARMFUL) | C12 |
| ooc | player | GetAuraSlots(HARMFUL\|PLAYER) | C12 |
| ooc | player | GetAuraSlots(HARMFUL\|RAID) | C12 |
| ooc | player | GetAuraSlots(HARMFUL\|RAID_PLAYER_DISPELLABLE) | C12 |
| ooc | player | GetAuraSlots(HELPFUL) | C12 |
| ooc | player | GetAuraSlots(HELPFUL\|PLAYER) | C12 |
| ooc | player | GetUnitAuras HARMFUL | K12 |
| ooc | player | GetUnitAuras HARMFUL\|PLAYER | K12 |
| ooc | player | GetUnitAuras HARMFUL\|RAID | K12 |
| ooc | player | GetUnitAuras HARMFUL\|RAID_PLAYER_DISPELLABLE | K12 |
| ooc | player | GetUnitAuras HELPFUL | K12 |
| ooc | player | GetUnitAuras HELPFUL\|PLAYER | K12 |
| ooc | player | UNIT_AURA payload .addedAuras | N2 K1 |
| ooc | player | UNIT_AURA payload .isFullUpdate | C3 |
| ooc | player | UNIT_AURA payload .removedAuraInstanceIDs | K3 |
| ooc | player | UNIT_AURA payload .updatedAuraInstanceIDs | N3 |
| ooc | self via other token | GetAuraSlots returns HARMFUL | N9 |
| ooc | self via other token | GetAuraSlots returns HARMFUL\|PLAYER | N9 |
| ooc | self via other token | GetAuraSlots returns HARMFUL\|RAID | N9 |
| ooc | self via other token | GetAuraSlots returns HARMFUL\|RAID_PLAYER_DISPELLABLE | N9 |
| ooc | self via other token | GetAuraSlots returns HELPFUL | R9 |
| ooc | self via other token | GetAuraSlots returns HELPFUL\|PLAYER | R6 N3 |
| ooc | self via other token | GetAuraSlots(HARMFUL) | C9 |
| ooc | self via other token | GetAuraSlots(HARMFUL\|PLAYER) | C9 |
| ooc | self via other token | GetAuraSlots(HARMFUL\|RAID) | C9 |
| ooc | self via other token | GetAuraSlots(HARMFUL\|RAID_PLAYER_DISPELLABLE) | C9 |
| ooc | self via other token | GetAuraSlots(HELPFUL) | C9 |
| ooc | self via other token | GetAuraSlots(HELPFUL\|PLAYER) | C9 |
| ooc | self via other token | GetUnitAuras HARMFUL | K9 |
| ooc | self via other token | GetUnitAuras HARMFUL\|PLAYER | K9 |
| ooc | self via other token | GetUnitAuras HARMFUL\|RAID | K9 |
| ooc | self via other token | GetUnitAuras HARMFUL\|RAID_PLAYER_DISPELLABLE | K9 |
| ooc | self via other token | GetUnitAuras HELPFUL | K9 |
| ooc | self via other token | GetUnitAuras HELPFUL\|PLAYER | K9 |
| ooc | self via other token | UNIT_AURA payload .addedAuras | N2 K1 |
| ooc | self via other token | UNIT_AURA payload .isFullUpdate | C3 |
| ooc | self via other token | UNIT_AURA payload .removedAuraInstanceIDs | K3 |
| ooc | self via other token | UNIT_AURA payload .updatedAuraInstanceIDs | N3 |
| ooc | target NPC | GetAuraSlots returns HARMFUL | N15 |
| ooc | target NPC | GetAuraSlots returns HARMFUL\|PLAYER | N15 |
| ooc | target NPC | GetAuraSlots returns HARMFUL\|RAID | N15 |
| ooc | target NPC | GetAuraSlots returns HARMFUL\|RAID_PLAYER_DISPELLABLE | N15 |
| ooc | target NPC | GetAuraSlots returns HELPFUL | N15 |
| ooc | target NPC | GetAuraSlots returns HELPFUL\|PLAYER | N15 |
| ooc | target NPC | GetAuraSlots(HARMFUL) | C15 |
| ooc | target NPC | GetAuraSlots(HARMFUL\|PLAYER) | C15 |
| ooc | target NPC | GetAuraSlots(HARMFUL\|RAID) | C15 |
| ooc | target NPC | GetAuraSlots(HARMFUL\|RAID_PLAYER_DISPELLABLE) | C15 |
| ooc | target NPC | GetAuraSlots(HELPFUL) | C15 |
| ooc | target NPC | GetAuraSlots(HELPFUL\|PLAYER) | C15 |
| ooc | target NPC | GetUnitAuras HARMFUL | K15 |
| ooc | target NPC | GetUnitAuras HARMFUL\|PLAYER | K15 |
| ooc | target NPC | GetUnitAuras HARMFUL\|RAID | K15 |
| ooc | target NPC | GetUnitAuras HARMFUL\|RAID_PLAYER_DISPELLABLE | K15 |
| ooc | target NPC | GetUnitAuras HELPFUL | K15 |
| ooc | target NPC | GetUnitAuras HELPFUL\|PLAYER | K15 |

## Partial-secret containers (readable container, some secret fields)

| context | unit | probe | container | secret fields | clear fields |
|---|---|---|---|---|---|
| combat | focus:self | `event:UNIT_AURA` | T | addedAuras, isFullUpdate, removedAuraInstanceIDs, updatedAuraInstanceIDs | - |
| combat | focustarget:hostile-npc | `event:UNIT_AURA` | T | addedAuras, isFullUpdate, removedAuraInstanceIDs | - |
| combat | global | `C_DamageMeter.GetCombatSessionFromType` | T | durationSeconds, maxAmount, totalAmount | - |
| combat | nameplate:hostile-npc | `event:UNIT_AURA` | T | addedAuras, isFullUpdate, removedAuraInstanceIDs | - |
| combat | player | `event:UNIT_AURA` | T | addedAuras, isFullUpdate, removedAuraInstanceIDs, updatedAuraInstanceIDs | - |
| combat | softenemy:hostile-npc | `event:UNIT_AURA` | T | addedAuras, isFullUpdate, removedAuraInstanceIDs | - |
| combat | target:hostile-npc | `event:UNIT_AURA` | T | addedAuras, isFullUpdate, removedAuraInstanceIDs | - |
| combat | targettarget:self | `event:UNIT_AURA` | T | addedAuras, isFullUpdate, removedAuraInstanceIDs, updatedAuraInstanceIDs | - |

## Errors (text only)

- `C_UnitAuras.GetAuraDataByIndex`: GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted by 'ForeverDump' Lua Taint: ForeverDump
- `C_UnitAuras.GetAuraDispelTypeColor`: bad argument #3 to '?' (Usage: local dispelTypeColor = C_UnitAuras.GetAuraDispelTypeColor(auraInstance, curve))
- `C_UnitAuras.GetAuraSlots`: GetAuraSlots(): Auras cannot be accessed when secret while tainted by 'ForeverDump' Lua Taint: ForeverDump
- `C_UnitAuras.GetUnitAuras`: GetUnitAuras(): Auras cannot be accessed when secret while tainted by 'ForeverDump' Lua Taint: ForeverDump

## Change detection vs baseline

Baseline `/workspace/foreverdump/fixtures/baselines/70245/containers.json` (legacy:combatProbe cells + UNIT_AURA payload codes (addon <= 2.2.1, one level deep)) vs this capture (legacy:combatProbe cells + UNIT_AURA payload codes (addon <= 2.2.1, one level deep)): 0 state change(s), 0 new key(s), 0 gone.

## Per probe (every field)

<details><summary>combat / focus:self (58 probes)</summary>

- `C_Map.GetPlayerMapPosition`: **K12** 
  - `Add`: C12
  - `Clone`: C12
  - `Cross`: C12
  - `DivideBy`: C12
  - `Dot`: C12
  - `GetLength`: C12
  - `GetLengthSquared`: C12
  - `GetXY`: C12
  - `IsEqualTo`: C12
  - `IsZero`: C12
  - `Normalize`: C12
  - `OnLoad`: C12
  - `RotateDirection`: C12
  - `ScaleBy`: C12
  - `SetXY`: C12
  - `Subtract`: C12
  - `x`: C12
  - `y`: C12
- `C_Spell.IsSpellInRange`: **N12** 
- `CanCompareUnitTokens`: **C12** 
- `CheckInteractDistance`: **C12** 
- `GetRaidTargetIndex`: **N12** 
- `GetUnitSpeed`: **R12** 
  - `current`: S12
  - `flight`: S12
  - `run`: S12
  - `swim`: S12
- `ShouldUnitIdentityBeSecret`: **C12** 
- `UnitAffectingCombat`: **C12** 
- `UnitCanAttack`: **C12** 
- `UnitCastingDuration`: **K4** 
- `UnitCastingInfo`: **R16** 
  - `10`: A12 C4
  - `11`: A12 C4
  - `castID`: A12 C4
  - `endTimeMS`: A12 C4
  - `isTradeSkill`: A12 C4
  - `name`: N12 C4
  - `notInterruptible`: A12 C4
  - `spellID`: A12 C4
  - `startTimeMS`: A12 C4
  - `text`: A12 C4
  - `texture`: A12 C4
- `UnitChannelInfo`: **N16** 
- `UnitClass`: **R12** 
  - `classFile`: C12
  - `classID`: C12
  - `className`: C12
- `UnitDetailedThreatSituation`: **N12** 
- `UnitExists`: **C12** 
- `UnitFullName`: **R12** 
  - `name`: C12
  - `realm`: C12
- `UnitGUID`: **C12** 
- `UnitGetIncomingHeals`: **S12** 
- `UnitGetTotalAbsorbs`: **S12** 
- `UnitGetTotalHealAbsorbs`: **S12** 
- `UnitHealth`: **S12** 
- `UnitHealthMax`: **C12** 
- `UnitHealthPercent`: **S12** 
- `UnitInRange`: **R12** 
  - `checked`: S12
  - `inRange`: S12
- `UnitIsDeadOrGhost`: **C12** 
- `UnitIsEnemy`: **C12** 
- `UnitIsFriend`: **C12** 
- `UnitIsPlayer`: **C12** 
- `UnitIsUnit(u,player)`: **C12** 
- `UnitLevel`: **C12** 
- `UnitName`: **R12** 
  - `name`: C12
  - `realm`: C12
- `UnitPosition`: **R12** 
  - `mapID`: C12
  - `x`: C12
  - `y`: C12
  - `z`: C12
- `UnitPower`: **S12** 
- `UnitPowerMax`: **C12** 
- `UnitPowerType`: **R12** 
  - `3`: N12
  - `4`: N12
  - `5`: N12
  - `powerToken`: C12
  - `powerType`: C12
- `UnitRace`: **R12** 
  - `raceFile`: C12
  - `raceID`: C12
  - `raceName`: C12
- `UnitReaction`: **C12** 
- `UnitThreatSituation`: **N12** 
- `aura:GetAuraDataByIndex[HARMFUL]`: **E12** 
- `aura:GetAuraDataByIndex[HARMFUL|PLAYER]`: **E12** 
- `aura:GetAuraDataByIndex[HARMFUL|RAID]`: **E12** 
- `aura:GetAuraDataByIndex[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **E12** 
- `aura:GetAuraDataByIndex[HELPFUL]`: **E12** 
- `aura:GetAuraDataByIndex[HELPFUL|PLAYER]`: **E12** 
- `aura:GetAuraSlots[HARMFUL]`: **E12** 
- `aura:GetAuraSlots[HARMFUL|PLAYER]`: **E12** 
- `aura:GetAuraSlots[HARMFUL|RAID]`: **E12** 
- `aura:GetAuraSlots[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **E12** 
- `aura:GetAuraSlots[HELPFUL]`: **E12** 
- `aura:GetAuraSlots[HELPFUL|PLAYER]`: **E12** 
- `aura:GetUnitAuras[HARMFUL]`: **E12** 
- `aura:GetUnitAuras[HARMFUL|PLAYER]`: **E12** 
- `aura:GetUnitAuras[HARMFUL|RAID]`: **E12** 
- `aura:GetUnitAuras[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **E12** 
- `aura:GetUnitAuras[HELPFUL]`: **E12** 
- `aura:GetUnitAuras[HELPFUL|PLAYER]`: **E12** 
- `casting:GetSpellCastSecrecy`: **C4** 
- `event:UNIT_AURA`: **T14** 
  - `addedAuras`: S7 N7
  - `isFullUpdate`: S14
  - `removedAuraInstanceIDs`: N9 S5
  - `updatedAuraInstanceIDs`: N8 S6

</details>

<details><summary>combat / focustarget:hostile-npc (1 probes)</summary>

- `event:UNIT_AURA`: **T3** 
  - `addedAuras`: S2 N1
  - `isFullUpdate`: S3
  - `removedAuraInstanceIDs`: N2 S1
  - `updatedAuraInstanceIDs`: N3

</details>

<details><summary>combat / global (2 probes)</summary>

- `C_DamageMeter.GetCombatSessionFromType`: **T14** 
  - `combatSources`: K14
  - `durationSeconds`: S14
  - `maxAmount`: S14
  - `totalAmount`: S14
- `C_DamageMeter.IsDamageMeterAvailable`: **R14** 
  - `ret1`: C14
  - `ret2`: C14

</details>

<details><summary>combat / mouseover:hostile-npc (37 probes)</summary>

- `C_Map.GetPlayerMapPosition`: **N4** 
- `C_Spell.IsSpellInRange`: **N4** 
- `CanCompareUnitTokens`: **C4** 
- `CheckInteractDistance`: **C4** 
- `GetRaidTargetIndex`: **S2 N2** 
- `GetUnitSpeed`: **R4** 
  - `current`: S4
  - `flight`: S4
  - `run`: S4
  - `swim`: S4
- `ShouldUnitIdentityBeSecret`: **C4** 
- `UnitAffectingCombat`: **C4** 
- `UnitCanAttack`: **C4** 
- `UnitCastingInfo`: **N4** 
- `UnitChannelInfo`: **N4** 
- `UnitClass`: **R4** 
  - `classFile`: C4
  - `classID`: C4
  - `className`: C4
- `UnitDetailedThreatSituation`: **R4** 
  - `isTanking`: S4
  - `rawPct`: S4
  - `rawThreat`: S4
  - `scaledPct`: S4
  - `status`: S4
- `UnitExists`: **C4** 
- `UnitFullName`: **R4** 
  - `name`: C4
  - `realm`: N4
- `UnitGUID`: **C4** 
- `UnitGetIncomingHeals`: **N4** 
- `UnitGetTotalAbsorbs`: **S4** 
- `UnitGetTotalHealAbsorbs`: **S4** 
- `UnitHealth`: **S4** 
- `UnitHealthMax`: **S4** 
- `UnitHealthPercent`: **S4** 
- `UnitInRange`: **R4** 
  - `checked`: S4
  - `inRange`: S4
- `UnitIsDeadOrGhost`: **C4** 
- `UnitIsEnemy`: **C4** 
- `UnitIsFriend`: **C4** 
- `UnitIsPlayer`: **C4** 
- `UnitIsUnit(u,player)`: **C4** 
- `UnitLevel`: **C4** 
- `UnitName`: **R4** 
  - `name`: C4
  - `realm`: N4
- `UnitPosition`: **R4** 
  - `mapID`: C4
  - `x`: N4
  - `y`: N4
  - `z`: N4
- `UnitPower`: **S4** 
- `UnitPowerMax`: **S4** 
- `UnitPowerType`: **R4** 
  - `3`: N4
  - `4`: N4
  - `5`: N4
  - `powerToken`: C4
  - `powerType`: C4
- `UnitRace`: **N4** 
- `UnitReaction`: **C4** 
- `UnitThreatSituation`: **S4** 

</details>

<details><summary>combat / mouseover:self (37 probes)</summary>

- `C_Map.GetPlayerMapPosition`: **K1** 
  - `Add`: C1
  - `Clone`: C1
  - `Cross`: C1
  - `DivideBy`: C1
  - `Dot`: C1
  - `GetLength`: C1
  - `GetLengthSquared`: C1
  - `GetXY`: C1
  - `IsEqualTo`: C1
  - `IsZero`: C1
  - `Normalize`: C1
  - `OnLoad`: C1
  - `RotateDirection`: C1
  - `ScaleBy`: C1
  - `SetXY`: C1
  - `Subtract`: C1
  - `x`: C1
  - `y`: C1
- `C_Spell.IsSpellInRange`: **N1** 
- `CanCompareUnitTokens`: **C1** 
- `CheckInteractDistance`: **C1** 
- `GetRaidTargetIndex`: **N1** 
- `GetUnitSpeed`: **R1** 
  - `current`: S1
  - `flight`: S1
  - `run`: S1
  - `swim`: S1
- `ShouldUnitIdentityBeSecret`: **C1** 
- `UnitAffectingCombat`: **C1** 
- `UnitCanAttack`: **C1** 
- `UnitCastingInfo`: **N1** 
- `UnitChannelInfo`: **N1** 
- `UnitClass`: **R1** 
  - `classFile`: C1
  - `classID`: C1
  - `className`: C1
- `UnitDetailedThreatSituation`: **N1** 
- `UnitExists`: **C1** 
- `UnitFullName`: **R1** 
  - `name`: C1
  - `realm`: C1
- `UnitGUID`: **C1** 
- `UnitGetIncomingHeals`: **S1** 
- `UnitGetTotalAbsorbs`: **S1** 
- `UnitGetTotalHealAbsorbs`: **S1** 
- `UnitHealth`: **S1** 
- `UnitHealthMax`: **C1** 
- `UnitHealthPercent`: **S1** 
- `UnitInRange`: **R1** 
  - `checked`: S1
  - `inRange`: S1
- `UnitIsDeadOrGhost`: **C1** 
- `UnitIsEnemy`: **C1** 
- `UnitIsFriend`: **C1** 
- `UnitIsPlayer`: **C1** 
- `UnitIsUnit(u,player)`: **C1** 
- `UnitLevel`: **C1** 
- `UnitName`: **R1** 
  - `name`: C1
  - `realm`: C1
- `UnitPosition`: **R1** 
  - `mapID`: C1
  - `x`: C1
  - `y`: C1
  - `z`: C1
- `UnitPower`: **S1** 
- `UnitPowerMax`: **C1** 
- `UnitPowerType`: **R1** 
  - `3`: N1
  - `4`: N1
  - `5`: N1
  - `powerToken`: C1
  - `powerType`: C1
- `UnitRace`: **R1** 
  - `raceFile`: C1
  - `raceID`: C1
  - `raceName`: C1
- `UnitReaction`: **C1** 
- `UnitThreatSituation`: **N1** 

</details>

<details><summary>combat / nameplate:hostile-npc (56 probes)</summary>

- `C_Map.GetPlayerMapPosition`: **N13** 
- `C_Spell.IsSpellInRange`: **N13** 
- `CanCompareUnitTokens`: **C13** 
- `CheckInteractDistance`: **C13** 
- `GetRaidTargetIndex`: **N10 S3** 
- `GetUnitSpeed`: **R13** 
  - `current`: S13
  - `flight`: S13
  - `run`: S13
  - `swim`: S13
- `ShouldUnitIdentityBeSecret`: **C13** 
- `UnitAffectingCombat`: **C13** 
- `UnitCanAttack`: **C13** 
- `UnitCastingInfo`: **N13** 
- `UnitChannelInfo`: **N13** 
- `UnitClass`: **R13** 
  - `classFile`: C13
  - `classID`: C13
  - `className`: C13
- `UnitDetailedThreatSituation`: **R13** 
  - `isTanking`: S13
  - `rawPct`: S13
  - `rawThreat`: S13
  - `scaledPct`: S13
  - `status`: S13
- `UnitExists`: **C13** 
- `UnitFullName`: **R13** 
  - `name`: C13
  - `realm`: N13
- `UnitGUID`: **C13** 
- `UnitGetIncomingHeals`: **N13** 
- `UnitGetTotalAbsorbs`: **S13** 
- `UnitGetTotalHealAbsorbs`: **S13** 
- `UnitHealth`: **S13** 
- `UnitHealthMax`: **S13** 
- `UnitHealthPercent`: **S13** 
- `UnitInRange`: **R13** 
  - `checked`: S13
  - `inRange`: S13
- `UnitIsDeadOrGhost`: **C13** 
- `UnitIsEnemy`: **C13** 
- `UnitIsFriend`: **C13** 
- `UnitIsPlayer`: **C13** 
- `UnitIsUnit(u,player)`: **C13** 
- `UnitLevel`: **C13** 
- `UnitName`: **R13** 
  - `name`: C13
  - `realm`: N13
- `UnitPosition`: **R13** 
  - `mapID`: C13
  - `x`: N13
  - `y`: N13
  - `z`: N13
- `UnitPower`: **S13** 
- `UnitPowerMax`: **S13** 
- `UnitPowerType`: **R13** 
  - `3`: N13
  - `4`: N13
  - `5`: N13
  - `powerToken`: C13
  - `powerType`: C13
- `UnitRace`: **N13** 
- `UnitReaction`: **C13** 
- `UnitThreatSituation`: **C13** 
- `aura:GetAuraDataByIndex[HARMFUL]`: **E13** 
- `aura:GetAuraDataByIndex[HARMFUL|PLAYER]`: **E13** 
- `aura:GetAuraDataByIndex[HARMFUL|RAID]`: **E13** 
- `aura:GetAuraDataByIndex[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **E13** 
- `aura:GetAuraDataByIndex[HELPFUL]`: **E13** 
- `aura:GetAuraDataByIndex[HELPFUL|PLAYER]`: **E13** 
- `aura:GetAuraSlots[HARMFUL]`: **E13** 
- `aura:GetAuraSlots[HARMFUL|PLAYER]`: **E13** 
- `aura:GetAuraSlots[HARMFUL|RAID]`: **E13** 
- `aura:GetAuraSlots[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **E13** 
- `aura:GetAuraSlots[HELPFUL]`: **E13** 
- `aura:GetAuraSlots[HELPFUL|PLAYER]`: **E13** 
- `aura:GetUnitAuras[HARMFUL]`: **E13** 
- `aura:GetUnitAuras[HARMFUL|PLAYER]`: **E13** 
- `aura:GetUnitAuras[HARMFUL|RAID]`: **E13** 
- `aura:GetUnitAuras[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **E13** 
- `aura:GetUnitAuras[HELPFUL]`: **E13** 
- `aura:GetUnitAuras[HELPFUL|PLAYER]`: **E13** 
- `event:UNIT_AURA`: **T4** 
  - `addedAuras`: S2 N2
  - `isFullUpdate`: S4
  - `removedAuraInstanceIDs`: S2 N2
  - `updatedAuraInstanceIDs`: N4

</details>

<details><summary>combat / player (60 probes)</summary>

- `C_Map.GetPlayerMapPosition`: **K14** 
  - `Add`: C14
  - `Clone`: C14
  - `Cross`: C14
  - `DivideBy`: C14
  - `Dot`: C14
  - `GetLength`: C14
  - `GetLengthSquared`: C14
  - `GetXY`: C14
  - `IsEqualTo`: C14
  - `IsZero`: C14
  - `Normalize`: C14
  - `OnLoad`: C14
  - `RotateDirection`: C14
  - `ScaleBy`: C14
  - `SetXY`: C14
  - `Subtract`: C14
  - `x`: C14
  - `y`: C14
- `C_Spell.IsSpellInRange`: **N14** 
- `CanCompareUnitTokens`: **C14** 
- `CheckInteractDistance`: **C14** 
- `GetPlayerFacing`: **C14** 
- `GetRaidTargetIndex`: **N14** 
- `GetUnitSpeed`: **R14** 
  - `current`: S14
  - `flight`: S14
  - `run`: S14
  - `swim`: S14
- `IsFalling`: **C14** 
- `IsFlying`: **C14** 
- `IsSwimming`: **C14** 
- `ShouldUnitIdentityBeSecret`: **C14** 
- `UnitAffectingCombat`: **C14** 
- `UnitCanAttack`: **C14** 
- `UnitCastingInfo`: **N14** 
- `UnitChannelInfo`: **N14** 
- `UnitClass`: **R14** 
  - `classFile`: C14
  - `classID`: C14
  - `className`: C14
- `UnitDetailedThreatSituation`: **N14** 
- `UnitExists`: **C14** 
- `UnitFullName`: **R14** 
  - `name`: C14
  - `realm`: C14
- `UnitGUID`: **C14** 
- `UnitGetIncomingHeals`: **S14** 
- `UnitGetTotalAbsorbs`: **S14** 
- `UnitGetTotalHealAbsorbs`: **S14** 
- `UnitHealth`: **S14** 
- `UnitHealthMax`: **C14** 
- `UnitHealthPercent`: **S14** 
- `UnitInRange`: **R14** 
  - `checked`: S14
  - `inRange`: S14
- `UnitIsDeadOrGhost`: **C14** 
- `UnitIsEnemy`: **C14** 
- `UnitIsFriend`: **C14** 
- `UnitIsPlayer`: **C14** 
- `UnitIsUnit(u,player)`: **C14** 
- `UnitLevel`: **C14** 
- `UnitName`: **R14** 
  - `name`: C14
  - `realm`: C14
- `UnitPosition`: **R14** 
  - `mapID`: C14
  - `x`: C14
  - `y`: C14
  - `z`: C14
- `UnitPower`: **S14** 
- `UnitPowerMax`: **C14** 
- `UnitPowerType`: **R14** 
  - `3`: N14
  - `4`: N14
  - `5`: N14
  - `powerToken`: C14
  - `powerType`: C14
- `UnitRace`: **R14** 
  - `raceFile`: C14
  - `raceID`: C14
  - `raceName`: C14
- `UnitReaction`: **C14** 
- `UnitThreatSituation`: **N14** 
- `aura:GetAuraDataByIndex[HARMFUL]`: **E14** 
- `aura:GetAuraDataByIndex[HARMFUL|PLAYER]`: **E14** 
- `aura:GetAuraDataByIndex[HARMFUL|RAID]`: **E14** 
- `aura:GetAuraDataByIndex[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **E14** 
- `aura:GetAuraDataByIndex[HELPFUL]`: **E14** 
- `aura:GetAuraDataByIndex[HELPFUL|PLAYER]`: **E14** 
- `aura:GetAuraSlots[HARMFUL]`: **E14** 
- `aura:GetAuraSlots[HARMFUL|PLAYER]`: **E14** 
- `aura:GetAuraSlots[HARMFUL|RAID]`: **E14** 
- `aura:GetAuraSlots[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **E14** 
- `aura:GetAuraSlots[HELPFUL]`: **E14** 
- `aura:GetAuraSlots[HELPFUL|PLAYER]`: **E14** 
- `aura:GetUnitAuras[HARMFUL]`: **E14** 
- `aura:GetUnitAuras[HARMFUL|PLAYER]`: **E14** 
- `aura:GetUnitAuras[HARMFUL|RAID]`: **E14** 
- `aura:GetUnitAuras[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **E14** 
- `aura:GetUnitAuras[HELPFUL]`: **E14** 
- `aura:GetUnitAuras[HELPFUL|PLAYER]`: **E14** 
- `event:UNIT_AURA`: **T25** 
  - `addedAuras`: S15 N10
  - `isFullUpdate`: S25
  - `removedAuraInstanceIDs`: N13 S12
  - `updatedAuraInstanceIDs`: N19 S6

</details>

<details><summary>combat / softenemy:hostile-npc (1 probes)</summary>

- `event:UNIT_AURA`: **T2** 
  - `addedAuras`: S1 N1
  - `isFullUpdate`: S2
  - `removedAuraInstanceIDs`: S1 N1
  - `updatedAuraInstanceIDs`: N2

</details>

<details><summary>combat / target:hostile-npc (56 probes)</summary>

- `C_Map.GetPlayerMapPosition`: **N7** 
- `C_Spell.IsSpellInRange`: **N7** 
- `CanCompareUnitTokens`: **C7** 
- `CheckInteractDistance`: **C7** 
- `GetRaidTargetIndex`: **N6 S1** 
- `GetUnitSpeed`: **R7** 
  - `current`: S7
  - `flight`: S7
  - `run`: S7
  - `swim`: S7
- `ShouldUnitIdentityBeSecret`: **C7** 
- `UnitAffectingCombat`: **C7** 
- `UnitCanAttack`: **C7** 
- `UnitCastingInfo`: **N7** 
- `UnitChannelInfo`: **N7** 
- `UnitClass`: **R7** 
  - `classFile`: C7
  - `classID`: C7
  - `className`: C7
- `UnitDetailedThreatSituation`: **R7** 
  - `isTanking`: C7
  - `rawPct`: C7
  - `rawThreat`: C7
  - `scaledPct`: C7
  - `status`: C7
- `UnitExists`: **C7** 
- `UnitFullName`: **R7** 
  - `name`: C7
  - `realm`: N7
- `UnitGUID`: **C7** 
- `UnitGetIncomingHeals`: **N7** 
- `UnitGetTotalAbsorbs`: **S7** 
- `UnitGetTotalHealAbsorbs`: **S7** 
- `UnitHealth`: **S7** 
- `UnitHealthMax`: **S7** 
- `UnitHealthPercent`: **S7** 
- `UnitInRange`: **R7** 
  - `checked`: S7
  - `inRange`: S7
- `UnitIsDeadOrGhost`: **C7** 
- `UnitIsEnemy`: **C7** 
- `UnitIsFriend`: **C7** 
- `UnitIsPlayer`: **C7** 
- `UnitIsUnit(u,player)`: **C7** 
- `UnitLevel`: **C7** 
- `UnitName`: **R7** 
  - `name`: C7
  - `realm`: N7
- `UnitPosition`: **R7** 
  - `mapID`: C7
  - `x`: N7
  - `y`: N7
  - `z`: N7
- `UnitPower`: **S7** 
- `UnitPowerMax`: **S7** 
- `UnitPowerType`: **R7** 
  - `3`: N7
  - `4`: N7
  - `5`: N7
  - `powerToken`: C7
  - `powerType`: C7
- `UnitRace`: **N7** 
- `UnitReaction`: **C7** 
- `UnitThreatSituation`: **C7** 
- `aura:GetAuraDataByIndex[HARMFUL]`: **E7** 
- `aura:GetAuraDataByIndex[HARMFUL|PLAYER]`: **E7** 
- `aura:GetAuraDataByIndex[HARMFUL|RAID]`: **E7** 
- `aura:GetAuraDataByIndex[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **E7** 
- `aura:GetAuraDataByIndex[HELPFUL]`: **E7** 
- `aura:GetAuraDataByIndex[HELPFUL|PLAYER]`: **E7** 
- `aura:GetAuraSlots[HARMFUL]`: **E7** 
- `aura:GetAuraSlots[HARMFUL|PLAYER]`: **E7** 
- `aura:GetAuraSlots[HARMFUL|RAID]`: **E7** 
- `aura:GetAuraSlots[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **E7** 
- `aura:GetAuraSlots[HELPFUL]`: **E7** 
- `aura:GetAuraSlots[HELPFUL|PLAYER]`: **E7** 
- `aura:GetUnitAuras[HARMFUL]`: **E7** 
- `aura:GetUnitAuras[HARMFUL|PLAYER]`: **E7** 
- `aura:GetUnitAuras[HARMFUL|RAID]`: **E7** 
- `aura:GetUnitAuras[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **E7** 
- `aura:GetUnitAuras[HELPFUL]`: **E7** 
- `aura:GetUnitAuras[HELPFUL|PLAYER]`: **E7** 
- `event:UNIT_AURA`: **T3** 
  - `addedAuras`: S2 N1
  - `isFullUpdate`: S3
  - `removedAuraInstanceIDs`: N2 S1
  - `updatedAuraInstanceIDs`: N3

</details>

<details><summary>combat / target:self (57 probes)</summary>

- `C_Map.GetPlayerMapPosition`: **K1** 
  - `Add`: C1
  - `Clone`: C1
  - `Cross`: C1
  - `DivideBy`: C1
  - `Dot`: C1
  - `GetLength`: C1
  - `GetLengthSquared`: C1
  - `GetXY`: C1
  - `IsEqualTo`: C1
  - `IsZero`: C1
  - `Normalize`: C1
  - `OnLoad`: C1
  - `RotateDirection`: C1
  - `ScaleBy`: C1
  - `SetXY`: C1
  - `Subtract`: C1
  - `x`: C1
  - `y`: C1
- `C_Spell.IsSpellInRange`: **N1** 
- `CanCompareUnitTokens`: **C1** 
- `CheckInteractDistance`: **C1** 
- `GetRaidTargetIndex`: **N1** 
- `GetUnitSpeed`: **R1** 
  - `current`: S1
  - `flight`: S1
  - `run`: S1
  - `swim`: S1
- `ShouldUnitIdentityBeSecret`: **C1** 
- `UnitAffectingCombat`: **C1** 
- `UnitCanAttack`: **C1** 
- `UnitCastingDuration`: **K1** 
- `UnitCastingInfo`: **R2** 
  - `10`: C1 A1
  - `11`: C1 A1
  - `castID`: C1 A1
  - `endTimeMS`: C1 A1
  - `isTradeSkill`: C1 A1
  - `name`: C1 N1
  - `notInterruptible`: C1 A1
  - `spellID`: C1 A1
  - `startTimeMS`: C1 A1
  - `text`: C1 A1
  - `texture`: C1 A1
- `UnitChannelInfo`: **N2** 
- `UnitClass`: **R1** 
  - `classFile`: C1
  - `classID`: C1
  - `className`: C1
- `UnitDetailedThreatSituation`: **N1** 
- `UnitExists`: **C1** 
- `UnitFullName`: **R1** 
  - `name`: C1
  - `realm`: C1
- `UnitGUID`: **C1** 
- `UnitGetIncomingHeals`: **S1** 
- `UnitGetTotalAbsorbs`: **S1** 
- `UnitGetTotalHealAbsorbs`: **S1** 
- `UnitHealth`: **S1** 
- `UnitHealthMax`: **C1** 
- `UnitHealthPercent`: **S1** 
- `UnitInRange`: **R1** 
  - `checked`: S1
  - `inRange`: S1
- `UnitIsDeadOrGhost`: **C1** 
- `UnitIsEnemy`: **C1** 
- `UnitIsFriend`: **C1** 
- `UnitIsPlayer`: **C1** 
- `UnitIsUnit(u,player)`: **C1** 
- `UnitLevel`: **C1** 
- `UnitName`: **R1** 
  - `name`: C1
  - `realm`: C1
- `UnitPosition`: **R1** 
  - `mapID`: C1
  - `x`: C1
  - `y`: C1
  - `z`: C1
- `UnitPower`: **S1** 
- `UnitPowerMax`: **C1** 
- `UnitPowerType`: **R1** 
  - `3`: N1
  - `4`: N1
  - `5`: N1
  - `powerToken`: C1
  - `powerType`: C1
- `UnitRace`: **R1** 
  - `raceFile`: C1
  - `raceID`: C1
  - `raceName`: C1
- `UnitReaction`: **C1** 
- `UnitThreatSituation`: **N1** 
- `aura:GetAuraDataByIndex[HARMFUL]`: **E1** 
- `aura:GetAuraDataByIndex[HARMFUL|PLAYER]`: **E1** 
- `aura:GetAuraDataByIndex[HARMFUL|RAID]`: **E1** 
- `aura:GetAuraDataByIndex[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **E1** 
- `aura:GetAuraDataByIndex[HELPFUL]`: **E1** 
- `aura:GetAuraDataByIndex[HELPFUL|PLAYER]`: **E1** 
- `aura:GetAuraSlots[HARMFUL]`: **E1** 
- `aura:GetAuraSlots[HARMFUL|PLAYER]`: **E1** 
- `aura:GetAuraSlots[HARMFUL|RAID]`: **E1** 
- `aura:GetAuraSlots[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **E1** 
- `aura:GetAuraSlots[HELPFUL]`: **E1** 
- `aura:GetAuraSlots[HELPFUL|PLAYER]`: **E1** 
- `aura:GetUnitAuras[HARMFUL]`: **E1** 
- `aura:GetUnitAuras[HARMFUL|PLAYER]`: **E1** 
- `aura:GetUnitAuras[HARMFUL|RAID]`: **E1** 
- `aura:GetUnitAuras[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **E1** 
- `aura:GetUnitAuras[HELPFUL]`: **E1** 
- `aura:GetUnitAuras[HELPFUL|PLAYER]`: **E1** 
- `casting:GetSpellCastSecrecy`: **C1** 

</details>

<details><summary>combat / targettarget:self (38 probes)</summary>

- `C_Map.GetPlayerMapPosition`: **K8** 
  - `Add`: C8
  - `Clone`: C8
  - `Cross`: C8
  - `DivideBy`: C8
  - `Dot`: C8
  - `GetLength`: C8
  - `GetLengthSquared`: C8
  - `GetXY`: C8
  - `IsEqualTo`: C8
  - `IsZero`: C8
  - `Normalize`: C8
  - `OnLoad`: C8
  - `RotateDirection`: C8
  - `ScaleBy`: C8
  - `SetXY`: C8
  - `Subtract`: C8
  - `x`: C8
  - `y`: C8
- `C_Spell.IsSpellInRange`: **N8** 
- `CanCompareUnitTokens`: **C8** 
- `CheckInteractDistance`: **C8** 
- `GetRaidTargetIndex`: **N8** 
- `GetUnitSpeed`: **R8** 
  - `current`: S8
  - `flight`: S8
  - `run`: S8
  - `swim`: S8
- `ShouldUnitIdentityBeSecret`: **C8** 
- `UnitAffectingCombat`: **C8** 
- `UnitCanAttack`: **C8** 
- `UnitCastingInfo`: **N8** 
- `UnitChannelInfo`: **N8** 
- `UnitClass`: **R8** 
  - `classFile`: C8
  - `classID`: C8
  - `className`: C8
- `UnitDetailedThreatSituation`: **N8** 
- `UnitExists`: **C8** 
- `UnitFullName`: **R8** 
  - `name`: C8
  - `realm`: C8
- `UnitGUID`: **C8** 
- `UnitGetIncomingHeals`: **S8** 
- `UnitGetTotalAbsorbs`: **S8** 
- `UnitGetTotalHealAbsorbs`: **S8** 
- `UnitHealth`: **S8** 
- `UnitHealthMax`: **C8** 
- `UnitHealthPercent`: **S8** 
- `UnitInRange`: **R8** 
  - `checked`: S8
  - `inRange`: S8
- `UnitIsDeadOrGhost`: **C8** 
- `UnitIsEnemy`: **C8** 
- `UnitIsFriend`: **C8** 
- `UnitIsPlayer`: **C8** 
- `UnitIsUnit(u,player)`: **C8** 
- `UnitLevel`: **C8** 
- `UnitName`: **R8** 
  - `name`: C8
  - `realm`: C8
- `UnitPosition`: **R8** 
  - `mapID`: C8
  - `x`: C8
  - `y`: C8
  - `z`: C8
- `UnitPower`: **S8** 
- `UnitPowerMax`: **C8** 
- `UnitPowerType`: **R8** 
  - `3`: N8
  - `4`: N8
  - `5`: N8
  - `powerToken`: C8
  - `powerType`: C8
- `UnitRace`: **R8** 
  - `raceFile`: C8
  - `raceID`: C8
  - `raceName`: C8
- `UnitReaction`: **C8** 
- `UnitThreatSituation`: **N8** 
- `event:UNIT_AURA`: **T23** 
  - `addedAuras`: S14 N9
  - `isFullUpdate`: S23
  - `removedAuraInstanceIDs`: S12 N11
  - `updatedAuraInstanceIDs`: N18 S5

</details>

<details><summary>ooc / focus:self (76 probes)</summary>

- `C_Map.GetPlayerMapPosition`: **K6** 
  - `Add`: C6
  - `Clone`: C6
  - `Cross`: C6
  - `DivideBy`: C6
  - `Dot`: C6
  - `GetLength`: C6
  - `GetLengthSquared`: C6
  - `GetXY`: C6
  - `IsEqualTo`: C6
  - `IsZero`: C6
  - `Normalize`: C6
  - `OnLoad`: C6
  - `RotateDirection`: C6
  - `ScaleBy`: C6
  - `SetXY`: C6
  - `Subtract`: C6
  - `x`: C6
  - `y`: C6
- `C_Spell.IsSpellInRange`: **N6** 
- `CanCompareUnitTokens`: **C6** 
- `CheckInteractDistance`: **C6** 
- `GetRaidTargetIndex`: **N6** 
- `GetUnitSpeed`: **R6** 
  - `current`: C6
  - `flight`: C6
  - `run`: C6
  - `swim`: C6
- `ShouldUnitIdentityBeSecret`: **C6** 
- `UnitAffectingCombat`: **C6** 
- `UnitCanAttack`: **C6** 
- `UnitCastingDuration`: **K5** 
- `UnitCastingInfo`: **R11** 
  - `10`: A6 C5
  - `11`: A6 C5
  - `castID`: A6 C5
  - `endTimeMS`: A6 C5
  - `isTradeSkill`: A6 C5
  - `name`: N6 C5
  - `notInterruptible`: A6 C5
  - `spellID`: A6 C5
  - `startTimeMS`: A6 C5
  - `text`: A6 C5
  - `texture`: A6 C5
- `UnitChannelInfo`: **N11** 
- `UnitClass`: **R6** 
  - `classFile`: C6
  - `classID`: C6
  - `className`: C6
- `UnitDetailedThreatSituation`: **N6** 
- `UnitExists`: **C6** 
- `UnitFullName`: **R6** 
  - `name`: C6
  - `realm`: C6
- `UnitGUID`: **C6** 
- `UnitGetIncomingHeals`: **S6** 
- `UnitGetTotalAbsorbs`: **S6** 
- `UnitGetTotalHealAbsorbs`: **S6** 
- `UnitHealth`: **S6** 
- `UnitHealthMax`: **C6** 
- `UnitHealthPercent`: **S6** 
- `UnitInRange`: **R6** 
  - `checked`: S6
  - `inRange`: S6
- `UnitIsDeadOrGhost`: **C6** 
- `UnitIsEnemy`: **C6** 
- `UnitIsFriend`: **C6** 
- `UnitIsPlayer`: **C6** 
- `UnitIsUnit(u,player)`: **C6** 
- `UnitLevel`: **C6** 
- `UnitName`: **R6** 
  - `name`: C6
  - `realm`: C6
- `UnitPosition`: **R6** 
  - `mapID`: C6
  - `x`: C6
  - `y`: C6
  - `z`: C6
- `UnitPower`: **S6** 
- `UnitPowerMax`: **C6** 
- `UnitPowerType`: **R6** 
  - `3`: N6
  - `4`: N6
  - `5`: N6
  - `powerToken`: C6
  - `powerType`: C6
- `UnitRace`: **R6** 
  - `raceFile`: C6
  - `raceID`: C6
  - `raceName`: C6
- `UnitReaction`: **C6** 
- `UnitThreatSituation`: **N6** 
- `aura:GetAuraApplicationDisplayCount[HELPFUL]`: **C6** 
- `aura:GetAuraApplicationDisplayCount[HELPFUL|PLAYER]`: **C2** 
- `aura:GetAuraDataByAuraInstanceID[HELPFUL]`: **K6** 
  - `applications`: C6
  - `auraInstanceID`: C6
  - `canActivePlayerDispel`: C6
  - `canApplyAura`: C6
  - `dispelName`: C6
  - `duration`: C6
  - `expirationTime`: C6
  - `hideOnPartyFrames`: C6
  - `icon`: C6
  - `isBossAura`: C6
  - `isDPSRoleAura`: C6
  - `isFromPlayerOrPlayerPet`: C6
  - `isHarmful`: C6
  - `isHealerRoleAura`: C6
  - `isHelpful`: C6
  - `isNameplateOnly`: C6
  - `isRaid`: C6
  - `isStealable`: C6
  - `isTankRoleAura`: C6
  - `name`: C6
  - `nameplateShowAll`: C6
  - `nameplateShowPersonal`: C6
  - `points`: K6
  - `sourceUnit`: A4 C2
  - `spellId`: C6
  - `timeMod`: C6
- `aura:GetAuraDataByAuraInstanceID[HELPFUL|PLAYER]`: **K2** 
  - `applications`: C2
  - `auraInstanceID`: C2
  - `canActivePlayerDispel`: C2
  - `canApplyAura`: C2
  - `dispelName`: C2
  - `duration`: C2
  - `expirationTime`: C2
  - `hideOnPartyFrames`: C2
  - `icon`: C2
  - `isBossAura`: C2
  - `isDPSRoleAura`: C2
  - `isFromPlayerOrPlayerPet`: C2
  - `isHarmful`: C2
  - `isHealerRoleAura`: C2
  - `isHelpful`: C2
  - `isNameplateOnly`: C2
  - `isRaid`: C2
  - `isStealable`: C2
  - `isTankRoleAura`: C2
  - `name`: C2
  - `nameplateShowAll`: C2
  - `nameplateShowPersonal`: C2
  - `points`: K2
  - `sourceUnit`: C2
  - `spellId`: C2
  - `timeMod`: C2
- `aura:GetAuraDataByIndex[HARMFUL]`: **N6** 
- `aura:GetAuraDataByIndex[HARMFUL|PLAYER]`: **N6** 
- `aura:GetAuraDataByIndex[HARMFUL|RAID]`: **N6** 
- `aura:GetAuraDataByIndex[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **N6** 
- `aura:GetAuraDataByIndex[HELPFUL]`: **K6** 
  - `applications`: C6
  - `auraInstanceID`: C6
  - `canActivePlayerDispel`: C6
  - `canApplyAura`: C6
  - `dispelName`: C6
  - `duration`: C6
  - `expirationTime`: C6
  - `hideOnPartyFrames`: C6
  - `icon`: C6
  - `isBossAura`: C6
  - `isDPSRoleAura`: C6
  - `isFromPlayerOrPlayerPet`: C6
  - `isHarmful`: C6
  - `isHealerRoleAura`: C6
  - `isHelpful`: C6
  - `isNameplateOnly`: C6
  - `isRaid`: C6
  - `isStealable`: C6
  - `isTankRoleAura`: C6
  - `name`: C6
  - `nameplateShowAll`: C6
  - `nameplateShowPersonal`: C6
  - `points`: K6
  - `sourceUnit`: A4 C2
  - `spellId`: C6
  - `timeMod`: C6
- `aura:GetAuraDataByIndex[HELPFUL|PLAYER]`: **N4 K2** 
  - `applications`: A4 C2
  - `auraInstanceID`: A4 C2
  - `canActivePlayerDispel`: A4 C2
  - `canApplyAura`: A4 C2
  - `dispelName`: A4 C2
  - `duration`: A4 C2
  - `expirationTime`: A4 C2
  - `hideOnPartyFrames`: A4 C2
  - `icon`: A4 C2
  - `isBossAura`: A4 C2
  - `isDPSRoleAura`: A4 C2
  - `isFromPlayerOrPlayerPet`: A4 C2
  - `isHarmful`: A4 C2
  - `isHealerRoleAura`: A4 C2
  - `isHelpful`: A4 C2
  - `isNameplateOnly`: A4 C2
  - `isRaid`: A4 C2
  - `isStealable`: A4 C2
  - `isTankRoleAura`: A4 C2
  - `name`: A4 C2
  - `nameplateShowAll`: A4 C2
  - `nameplateShowPersonal`: A4 C2
  - `points`: A4 K2
  - `sourceUnit`: A4 C2
  - `spellId`: A4 C2
  - `timeMod`: A4 C2
- `aura:GetAuraDataBySlot[HELPFUL]`: **K6** 
  - `applications`: C6
  - `auraInstanceID`: C6
  - `canActivePlayerDispel`: C6
  - `canApplyAura`: C6
  - `dispelName`: C6
  - `duration`: C6
  - `expirationTime`: C6
  - `hideOnPartyFrames`: C6
  - `icon`: C6
  - `isBossAura`: C6
  - `isDPSRoleAura`: C6
  - `isFromPlayerOrPlayerPet`: C6
  - `isHarmful`: C6
  - `isHealerRoleAura`: C6
  - `isHelpful`: C6
  - `isNameplateOnly`: C6
  - `isRaid`: C6
  - `isStealable`: C6
  - `isTankRoleAura`: C6
  - `name`: C6
  - `nameplateShowAll`: C6
  - `nameplateShowPersonal`: C6
  - `points`: K6
  - `sourceUnit`: A4 C2
  - `spellId`: C6
  - `timeMod`: C6
- `aura:GetAuraDataBySlot[HELPFUL|PLAYER]`: **K2** 
  - `applications`: C2
  - `auraInstanceID`: C2
  - `canActivePlayerDispel`: C2
  - `canApplyAura`: C2
  - `dispelName`: C2
  - `duration`: C2
  - `expirationTime`: C2
  - `hideOnPartyFrames`: C2
  - `icon`: C2
  - `isBossAura`: C2
  - `isDPSRoleAura`: C2
  - `isFromPlayerOrPlayerPet`: C2
  - `isHarmful`: C2
  - `isHealerRoleAura`: C2
  - `isHelpful`: C2
  - `isNameplateOnly`: C2
  - `isRaid`: C2
  - `isStealable`: C2
  - `isTankRoleAura`: C2
  - `name`: C2
  - `nameplateShowAll`: C2
  - `nameplateShowPersonal`: C2
  - `points`: K2
  - `sourceUnit`: C2
  - `spellId`: C2
  - `timeMod`: C2
- `aura:GetAuraDispelTypeColor[HELPFUL]`: **E6** 
- `aura:GetAuraDispelTypeColor[HELPFUL|PLAYER]`: **E2** 
- `aura:GetAuraDuration[HELPFUL]`: **K6** 
- `aura:GetAuraDuration[HELPFUL]#object`: **K1** 
  - `GetRemainingDuration()`: C1
  - `GetRemainingPercent()`: C1
  - `GetTotalDuration()`: C1
  - `HasSecretValues()`: C1
  - `IsZero()`: C1
- `aura:GetAuraDuration[HELPFUL|PLAYER]`: **K2** 
- `aura:GetAuraDuration[HELPFUL|PLAYER]#object`: **K1** 
  - `GetRemainingDuration()`: C1
  - `GetRemainingPercent()`: C1
  - `GetTotalDuration()`: C1
  - `HasSecretValues()`: C1
  - `IsZero()`: C1
- `aura:GetAuraSlots[HARMFUL]`: **N6** 
- `aura:GetAuraSlots[HARMFUL|PLAYER]`: **N6** 
- `aura:GetAuraSlots[HARMFUL|RAID]`: **N6** 
- `aura:GetAuraSlots[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **N6** 
- `aura:GetAuraSlots[HELPFUL]`: **R6** 
  - `ret1`: N6
  - `ret2`: C6
  - `ret3`: C6
- `aura:GetAuraSlots[HELPFUL|PLAYER]`: **R6** 
  - `ret1`: N6
  - `ret2`: A4 C2
- `aura:GetUnitAuras[HARMFUL]`: **K6** 
- `aura:GetUnitAuras[HARMFUL|PLAYER]`: **K6** 
- `aura:GetUnitAuras[HARMFUL|RAID]`: **K6** 
- `aura:GetUnitAuras[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **K6** 
- `aura:GetUnitAuras[HELPFUL]`: **K6** 
- `aura:GetUnitAuras[HELPFUL|PLAYER]`: **K6** 
- `casting:GetSpellCastSecrecy`: **C5** 
- `count:GetAuraSlots(HARMFUL)`: **C6** 
- `count:GetAuraSlots(HARMFUL|PLAYER)`: **C6** 
- `count:GetAuraSlots(HARMFUL|RAID)`: **C6** 
- `count:GetAuraSlots(HARMFUL|RAID_PLAYER_DISPELLABLE)`: **C6** 
- `count:GetAuraSlots(HELPFUL)`: **C6** 
- `count:GetAuraSlots(HELPFUL|PLAYER)`: **C6** 
- `event:UNIT_AURA`: **K3** 
  - `addedAuras`: N2 K1
  - `addedAuras[]`: K1
  - `addedAuras[].applications`: C1
  - `addedAuras[].auraInstanceID`: C1
  - `addedAuras[].canActivePlayerDispel`: C1
  - `addedAuras[].canApplyAura`: C1
  - `addedAuras[].duration`: C1
  - `addedAuras[].expirationTime`: C1
  - `addedAuras[].hideOnPartyFrames`: C1
  - `addedAuras[].icon`: C1
  - `addedAuras[].isBossAura`: C1
  - `addedAuras[].isDPSRoleAura`: C1
  - `addedAuras[].isFromPlayerOrPlayerPet`: C1
  - `addedAuras[].isHarmful`: C1
  - `addedAuras[].isHealerRoleAura`: C1
  - `addedAuras[].isHelpful`: C1
  - `addedAuras[].isNameplateOnly`: C1
  - `addedAuras[].isRaid`: C1
  - `addedAuras[].isStealable`: C1
  - `addedAuras[].isTankRoleAura`: C1
  - `addedAuras[].name`: C1
  - `addedAuras[].nameplateShowAll`: C1
  - `addedAuras[].nameplateShowPersonal`: C1
  - `addedAuras[].points`: K1
  - `addedAuras[].sourceUnit`: C1
  - `addedAuras[].spellId`: C1
  - `addedAuras[].timeMod`: C1
  - `isFullUpdate`: C3
  - `removedAuraInstanceIDs`: K3
  - `updatedAuraInstanceIDs`: N3

</details>

<details><summary>ooc / global (2 probes)</summary>

- `C_DamageMeter.GetCombatSessionFromType`: **K12** 
  - `combatSources`: K12
  - `durationSeconds`: C12
  - `maxAmount`: C12
  - `totalAmount`: C12
- `C_DamageMeter.IsDamageMeterAvailable`: **R12** 
  - `ret1`: C12
  - `ret2`: C12

</details>

<details><summary>ooc / mouseover:hostile-npc (37 probes)</summary>

- `C_Map.GetPlayerMapPosition`: **N4** 
- `C_Spell.IsSpellInRange`: **N4** 
- `CanCompareUnitTokens`: **C4** 
- `CheckInteractDistance`: **C4** 
- `GetRaidTargetIndex`: **N4** 
- `GetUnitSpeed`: **R4** 
  - `current`: C4
  - `flight`: C4
  - `run`: C4
  - `swim`: C4
- `ShouldUnitIdentityBeSecret`: **C4** 
- `UnitAffectingCombat`: **C4** 
- `UnitCanAttack`: **C4** 
- `UnitCastingInfo`: **N4** 
- `UnitChannelInfo`: **N4** 
- `UnitClass`: **R4** 
  - `classFile`: C4
  - `classID`: C4
  - `className`: C4
- `UnitDetailedThreatSituation`: **N4** 
- `UnitExists`: **C4** 
- `UnitFullName`: **R4** 
  - `name`: C4
  - `realm`: N4
- `UnitGUID`: **C4** 
- `UnitGetIncomingHeals`: **N4** 
- `UnitGetTotalAbsorbs`: **S4** 
- `UnitGetTotalHealAbsorbs`: **S4** 
- `UnitHealth`: **S4** 
- `UnitHealthMax`: **S4** 
- `UnitHealthPercent`: **S4** 
- `UnitInRange`: **R4** 
  - `checked`: S4
  - `inRange`: S4
- `UnitIsDeadOrGhost`: **C4** 
- `UnitIsEnemy`: **C4** 
- `UnitIsFriend`: **C4** 
- `UnitIsPlayer`: **C4** 
- `UnitIsUnit(u,player)`: **C4** 
- `UnitLevel`: **C4** 
- `UnitName`: **R4** 
  - `name`: C4
  - `realm`: N4
- `UnitPosition`: **R4** 
  - `mapID`: C4
  - `x`: N4
  - `y`: N4
  - `z`: N4
- `UnitPower`: **S4** 
- `UnitPowerMax`: **S4** 
- `UnitPowerType`: **R4** 
  - `3`: N4
  - `4`: N4
  - `5`: N4
  - `powerToken`: C4
  - `powerType`: C4
- `UnitRace`: **N4** 
- `UnitReaction`: **C4** 
- `UnitThreatSituation`: **N4** 

</details>

<details><summary>ooc / mouseover:self (37 probes)</summary>

- `C_Map.GetPlayerMapPosition`: **K3** 
  - `Add`: C3
  - `Clone`: C3
  - `Cross`: C3
  - `DivideBy`: C3
  - `Dot`: C3
  - `GetLength`: C3
  - `GetLengthSquared`: C3
  - `GetXY`: C3
  - `IsEqualTo`: C3
  - `IsZero`: C3
  - `Normalize`: C3
  - `OnLoad`: C3
  - `RotateDirection`: C3
  - `ScaleBy`: C3
  - `SetXY`: C3
  - `Subtract`: C3
  - `x`: C3
  - `y`: C3
- `C_Spell.IsSpellInRange`: **N3** 
- `CanCompareUnitTokens`: **C3** 
- `CheckInteractDistance`: **C3** 
- `GetRaidTargetIndex`: **N3** 
- `GetUnitSpeed`: **R3** 
  - `current`: C3
  - `flight`: C3
  - `run`: C3
  - `swim`: C3
- `ShouldUnitIdentityBeSecret`: **C3** 
- `UnitAffectingCombat`: **C3** 
- `UnitCanAttack`: **C3** 
- `UnitCastingInfo`: **N3** 
- `UnitChannelInfo`: **N3** 
- `UnitClass`: **R3** 
  - `classFile`: C3
  - `classID`: C3
  - `className`: C3
- `UnitDetailedThreatSituation`: **N3** 
- `UnitExists`: **C3** 
- `UnitFullName`: **R3** 
  - `name`: C3
  - `realm`: C3
- `UnitGUID`: **C3** 
- `UnitGetIncomingHeals`: **S3** 
- `UnitGetTotalAbsorbs`: **S3** 
- `UnitGetTotalHealAbsorbs`: **S3** 
- `UnitHealth`: **S3** 
- `UnitHealthMax`: **C3** 
- `UnitHealthPercent`: **S3** 
- `UnitInRange`: **R3** 
  - `checked`: S3
  - `inRange`: S3
- `UnitIsDeadOrGhost`: **C3** 
- `UnitIsEnemy`: **C3** 
- `UnitIsFriend`: **C3** 
- `UnitIsPlayer`: **C3** 
- `UnitIsUnit(u,player)`: **C3** 
- `UnitLevel`: **C3** 
- `UnitName`: **R3** 
  - `name`: C3
  - `realm`: C3
- `UnitPosition`: **R3** 
  - `mapID`: C3
  - `x`: C3
  - `y`: C3
  - `z`: C3
- `UnitPower`: **S3** 
- `UnitPowerMax`: **C3** 
- `UnitPowerType`: **R3** 
  - `3`: N3
  - `4`: N3
  - `5`: N3
  - `powerToken`: C3
  - `powerType`: C3
- `UnitRace`: **R3** 
  - `raceFile`: C3
  - `raceID`: C3
  - `raceName`: C3
- `UnitReaction`: **C3** 
- `UnitThreatSituation`: **N3** 

</details>

<details><summary>ooc / nameplate:hostile-npc (61 probes)</summary>

- `C_Map.GetPlayerMapPosition`: **N10** 
- `C_Spell.IsSpellInRange`: **N10** 
- `CanCompareUnitTokens`: **C10** 
- `CheckInteractDistance`: **C10** 
- `GetRaidTargetIndex`: **N8 S2** 
- `GetUnitSpeed`: **R10** 
  - `current`: C10
  - `flight`: C10
  - `run`: C10
  - `swim`: C10
- `ShouldUnitIdentityBeSecret`: **C10** 
- `UnitAffectingCombat`: **C10** 
- `UnitCanAttack`: **C10** 
- `UnitCastingInfo`: **N10** 
- `UnitChannelInfo`: **N10** 
- `UnitClass`: **R10** 
  - `classFile`: C10
  - `classID`: C10
  - `className`: C10
- `UnitDetailedThreatSituation`: **N10** 
- `UnitExists`: **C10** 
- `UnitFullName`: **R10** 
  - `name`: C10
  - `realm`: N10
- `UnitGUID`: **C10** 
- `UnitGetIncomingHeals`: **N10** 
- `UnitGetTotalAbsorbs`: **S10** 
- `UnitGetTotalHealAbsorbs`: **S10** 
- `UnitHealth`: **S10** 
- `UnitHealthMax`: **S10** 
- `UnitHealthPercent`: **S10** 
- `UnitInRange`: **R10** 
  - `checked`: S10
  - `inRange`: S10
- `UnitIsDeadOrGhost`: **C10** 
- `UnitIsEnemy`: **C10** 
- `UnitIsFriend`: **C10** 
- `UnitIsPlayer`: **C10** 
- `UnitIsUnit(u,player)`: **C10** 
- `UnitLevel`: **C10** 
- `UnitName`: **R10** 
  - `name`: C10
  - `realm`: N10
- `UnitPosition`: **R10** 
  - `mapID`: C10
  - `x`: N10
  - `y`: N10
  - `z`: N10
- `UnitPower`: **S10** 
- `UnitPowerMax`: **S10** 
- `UnitPowerType`: **R10** 
  - `3`: N10
  - `4`: N10
  - `5`: N10
  - `powerToken`: C10
  - `powerType`: C10
- `UnitRace`: **N10** 
- `UnitReaction`: **C10** 
- `UnitThreatSituation`: **N10** 
- `aura:GetAuraDataByIndex[HARMFUL]`: **N10** 
- `aura:GetAuraDataByIndex[HARMFUL|PLAYER]`: **N10** 
- `aura:GetAuraDataByIndex[HARMFUL|RAID]`: **N10** 
- `aura:GetAuraDataByIndex[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **N10** 
- `aura:GetAuraDataByIndex[HELPFUL]`: **N10** 
- `aura:GetAuraDataByIndex[HELPFUL|PLAYER]`: **N10** 
- `aura:GetAuraSlots[HARMFUL]`: **N10** 
- `aura:GetAuraSlots[HARMFUL|PLAYER]`: **N10** 
- `aura:GetAuraSlots[HARMFUL|RAID]`: **N10** 
- `aura:GetAuraSlots[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **N10** 
- `aura:GetAuraSlots[HELPFUL]`: **N10** 
- `aura:GetAuraSlots[HELPFUL|PLAYER]`: **N10** 
- `aura:GetUnitAuras[HARMFUL]`: **K10** 
- `aura:GetUnitAuras[HARMFUL|PLAYER]`: **K10** 
- `aura:GetUnitAuras[HARMFUL|RAID]`: **K10** 
- `aura:GetUnitAuras[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **K10** 
- `aura:GetUnitAuras[HELPFUL]`: **K10** 
- `aura:GetUnitAuras[HELPFUL|PLAYER]`: **K10** 
- `count:GetAuraSlots(HARMFUL)`: **C10** 
- `count:GetAuraSlots(HARMFUL|PLAYER)`: **C10** 
- `count:GetAuraSlots(HARMFUL|RAID)`: **C10** 
- `count:GetAuraSlots(HARMFUL|RAID_PLAYER_DISPELLABLE)`: **C10** 
- `count:GetAuraSlots(HELPFUL)`: **C10** 
- `count:GetAuraSlots(HELPFUL|PLAYER)`: **C10** 

</details>

<details><summary>ooc / player (81 probes)</summary>

- `C_Map.GetPlayerMapPosition`: **K12** 
  - `Add`: C12
  - `Clone`: C12
  - `Cross`: C12
  - `DivideBy`: C12
  - `Dot`: C12
  - `GetLength`: C12
  - `GetLengthSquared`: C12
  - `GetXY`: C12
  - `IsEqualTo`: C12
  - `IsZero`: C12
  - `Normalize`: C12
  - `OnLoad`: C12
  - `RotateDirection`: C12
  - `ScaleBy`: C12
  - `SetXY`: C12
  - `Subtract`: C12
  - `x`: C12
  - `y`: C12
- `C_Spell.IsSpellInRange`: **N12** 
- `CanCompareUnitTokens`: **C12** 
- `CheckInteractDistance`: **C12** 
- `GetPlayerFacing`: **C12** 
- `GetRaidTargetIndex`: **N12** 
- `GetUnitSpeed`: **R12** 
  - `current`: C12
  - `flight`: C12
  - `run`: C12
  - `swim`: C12
- `IsFalling`: **C12** 
- `IsFlying`: **C12** 
- `IsSwimming`: **C12** 
- `ShouldUnitIdentityBeSecret`: **C12** 
- `UnitAffectingCombat`: **C12** 
- `UnitCanAttack`: **C12** 
- `UnitCastingInfo`: **N12** 
- `UnitChannelInfo`: **N12** 
- `UnitClass`: **R12** 
  - `classFile`: C12
  - `classID`: C12
  - `className`: C12
- `UnitDetailedThreatSituation`: **N12** 
- `UnitExists`: **C12** 
- `UnitFullName`: **R12** 
  - `name`: C12
  - `realm`: C12
- `UnitGUID`: **C12** 
- `UnitGetIncomingHeals`: **S12** 
- `UnitGetTotalAbsorbs`: **S12** 
- `UnitGetTotalHealAbsorbs`: **S12** 
- `UnitHealth`: **S12** 
- `UnitHealthMax`: **C12** 
- `UnitHealthPercent`: **S12** 
- `UnitInRange`: **R12** 
  - `checked`: S12
  - `inRange`: S12
- `UnitIsDeadOrGhost`: **C12** 
- `UnitIsEnemy`: **C12** 
- `UnitIsFriend`: **C12** 
- `UnitIsPlayer`: **C12** 
- `UnitIsUnit(u,player)`: **C12** 
- `UnitLevel`: **C12** 
- `UnitName`: **R12** 
  - `name`: C12
  - `realm`: C12
- `UnitPosition`: **R12** 
  - `mapID`: C12
  - `x`: C12
  - `y`: C12
  - `z`: C12
- `UnitPower`: **S12** 
- `UnitPowerMax`: **C12** 
- `UnitPowerType`: **R12** 
  - `3`: N12
  - `4`: N12
  - `5`: N12
  - `powerToken`: C12
  - `powerType`: C12
- `UnitRace`: **R12** 
  - `raceFile`: C12
  - `raceID`: C12
  - `raceName`: C12
- `UnitReaction`: **C12** 
- `UnitThreatSituation`: **N12** 
- `aura:GetAuraApplicationDisplayCount[HELPFUL]`: **C12** 
- `aura:GetAuraApplicationDisplayCount[HELPFUL|PLAYER]`: **C2** 
- `aura:GetAuraDataByAuraInstanceID[HELPFUL]`: **K12** 
  - `applications`: C12
  - `auraInstanceID`: C12
  - `canActivePlayerDispel`: C12
  - `canApplyAura`: C12
  - `dispelName`: C12
  - `duration`: C12
  - `expirationTime`: C12
  - `hideOnPartyFrames`: C12
  - `icon`: C12
  - `isBossAura`: C12
  - `isDPSRoleAura`: C12
  - `isFromPlayerOrPlayerPet`: C12
  - `isHarmful`: C12
  - `isHealerRoleAura`: C12
  - `isHelpful`: C12
  - `isNameplateOnly`: C12
  - `isRaid`: C12
  - `isStealable`: C12
  - `isTankRoleAura`: C12
  - `name`: C12
  - `nameplateShowAll`: C12
  - `nameplateShowPersonal`: C12
  - `points`: K12
  - `sourceUnit`: A10 C2
  - `spellId`: C12
  - `timeMod`: C12
- `aura:GetAuraDataByAuraInstanceID[HELPFUL|PLAYER]`: **K2** 
  - `applications`: C2
  - `auraInstanceID`: C2
  - `canActivePlayerDispel`: C2
  - `canApplyAura`: C2
  - `dispelName`: C2
  - `duration`: C2
  - `expirationTime`: C2
  - `hideOnPartyFrames`: C2
  - `icon`: C2
  - `isBossAura`: C2
  - `isDPSRoleAura`: C2
  - `isFromPlayerOrPlayerPet`: C2
  - `isHarmful`: C2
  - `isHealerRoleAura`: C2
  - `isHelpful`: C2
  - `isNameplateOnly`: C2
  - `isRaid`: C2
  - `isStealable`: C2
  - `isTankRoleAura`: C2
  - `name`: C2
  - `nameplateShowAll`: C2
  - `nameplateShowPersonal`: C2
  - `points`: K2
  - `sourceUnit`: C2
  - `spellId`: C2
  - `timeMod`: C2
- `aura:GetAuraDataByIndex[HARMFUL]`: **N12** 
- `aura:GetAuraDataByIndex[HARMFUL|PLAYER]`: **N12** 
- `aura:GetAuraDataByIndex[HARMFUL|RAID]`: **N12** 
- `aura:GetAuraDataByIndex[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **N12** 
- `aura:GetAuraDataByIndex[HELPFUL]`: **K12** 
  - `applications`: C12
  - `auraInstanceID`: C12
  - `canActivePlayerDispel`: C12
  - `canApplyAura`: C12
  - `dispelName`: C12
  - `duration`: C12
  - `expirationTime`: C12
  - `hideOnPartyFrames`: C12
  - `icon`: C12
  - `isBossAura`: C12
  - `isDPSRoleAura`: C12
  - `isFromPlayerOrPlayerPet`: C12
  - `isHarmful`: C12
  - `isHealerRoleAura`: C12
  - `isHelpful`: C12
  - `isNameplateOnly`: C12
  - `isRaid`: C12
  - `isStealable`: C12
  - `isTankRoleAura`: C12
  - `name`: C12
  - `nameplateShowAll`: C12
  - `nameplateShowPersonal`: C12
  - `points`: K12
  - `sourceUnit`: A10 C2
  - `spellId`: C12
  - `timeMod`: C12
- `aura:GetAuraDataByIndex[HELPFUL|PLAYER]`: **N10 K2** 
  - `applications`: A10 C2
  - `auraInstanceID`: A10 C2
  - `canActivePlayerDispel`: A10 C2
  - `canApplyAura`: A10 C2
  - `dispelName`: A10 C2
  - `duration`: A10 C2
  - `expirationTime`: A10 C2
  - `hideOnPartyFrames`: A10 C2
  - `icon`: A10 C2
  - `isBossAura`: A10 C2
  - `isDPSRoleAura`: A10 C2
  - `isFromPlayerOrPlayerPet`: A10 C2
  - `isHarmful`: A10 C2
  - `isHealerRoleAura`: A10 C2
  - `isHelpful`: A10 C2
  - `isNameplateOnly`: A10 C2
  - `isRaid`: A10 C2
  - `isStealable`: A10 C2
  - `isTankRoleAura`: A10 C2
  - `name`: A10 C2
  - `nameplateShowAll`: A10 C2
  - `nameplateShowPersonal`: A10 C2
  - `points`: A10 K2
  - `sourceUnit`: A10 C2
  - `spellId`: A10 C2
  - `timeMod`: A10 C2
- `aura:GetAuraDataBySlot[HELPFUL]`: **K12** 
  - `applications`: C12
  - `auraInstanceID`: C12
  - `canActivePlayerDispel`: C12
  - `canApplyAura`: C12
  - `dispelName`: C12
  - `duration`: C12
  - `expirationTime`: C12
  - `hideOnPartyFrames`: C12
  - `icon`: C12
  - `isBossAura`: C12
  - `isDPSRoleAura`: C12
  - `isFromPlayerOrPlayerPet`: C12
  - `isHarmful`: C12
  - `isHealerRoleAura`: C12
  - `isHelpful`: C12
  - `isNameplateOnly`: C12
  - `isRaid`: C12
  - `isStealable`: C12
  - `isTankRoleAura`: C12
  - `name`: C12
  - `nameplateShowAll`: C12
  - `nameplateShowPersonal`: C12
  - `points`: K12
  - `sourceUnit`: A10 C2
  - `spellId`: C12
  - `timeMod`: C12
- `aura:GetAuraDataBySlot[HELPFUL|PLAYER]`: **K2** 
  - `applications`: C2
  - `auraInstanceID`: C2
  - `canActivePlayerDispel`: C2
  - `canApplyAura`: C2
  - `dispelName`: C2
  - `duration`: C2
  - `expirationTime`: C2
  - `hideOnPartyFrames`: C2
  - `icon`: C2
  - `isBossAura`: C2
  - `isDPSRoleAura`: C2
  - `isFromPlayerOrPlayerPet`: C2
  - `isHarmful`: C2
  - `isHealerRoleAura`: C2
  - `isHelpful`: C2
  - `isNameplateOnly`: C2
  - `isRaid`: C2
  - `isStealable`: C2
  - `isTankRoleAura`: C2
  - `name`: C2
  - `nameplateShowAll`: C2
  - `nameplateShowPersonal`: C2
  - `points`: K2
  - `sourceUnit`: C2
  - `spellId`: C2
  - `timeMod`: C2
- `aura:GetAuraDispelTypeColor[HELPFUL]`: **E12** 
- `aura:GetAuraDispelTypeColor[HELPFUL|PLAYER]`: **E2** 
- `aura:GetAuraDuration[HELPFUL]`: **K12** 
- `aura:GetAuraDuration[HELPFUL]#object`: **K1** 
  - `GetRemainingDuration()`: C1
  - `GetRemainingPercent()`: C1
  - `GetTotalDuration()`: C1
  - `HasSecretValues()`: C1
  - `IsZero()`: C1
- `aura:GetAuraDuration[HELPFUL|PLAYER]`: **K2** 
- `aura:GetAuraDuration[HELPFUL|PLAYER]#object`: **K1** 
  - `GetRemainingDuration()`: C1
  - `GetRemainingPercent()`: C1
  - `GetTotalDuration()`: C1
  - `HasSecretValues()`: C1
  - `IsZero()`: C1
- `aura:GetAuraSlots[HARMFUL]`: **N12** 
- `aura:GetAuraSlots[HARMFUL|PLAYER]`: **N12** 
- `aura:GetAuraSlots[HARMFUL|RAID]`: **N12** 
- `aura:GetAuraSlots[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **N12** 
- `aura:GetAuraSlots[HELPFUL]`: **R12** 
  - `ret1`: N12
  - `ret2`: C12
  - `ret3`: C9 A3
- `aura:GetAuraSlots[HELPFUL|PLAYER]`: **R12** 
  - `ret1`: N12
  - `ret2`: A10 C2
- `aura:GetPlayerAuraBySpellID`: **K12** 
  - `applications`: C12
  - `auraInstanceID`: C12
  - `canActivePlayerDispel`: C12
  - `canApplyAura`: C12
  - `dispelName`: C12
  - `duration`: C12
  - `expirationTime`: C12
  - `hideOnPartyFrames`: C12
  - `icon`: C12
  - `isBossAura`: C12
  - `isDPSRoleAura`: C12
  - `isFromPlayerOrPlayerPet`: C12
  - `isHarmful`: C12
  - `isHealerRoleAura`: C12
  - `isHelpful`: C12
  - `isNameplateOnly`: C12
  - `isRaid`: C12
  - `isStealable`: C12
  - `isTankRoleAura`: C12
  - `name`: C12
  - `nameplateShowAll`: C12
  - `nameplateShowPersonal`: C12
  - `points`: K12
  - `sourceUnit`: A10 C2
  - `spellId`: C12
  - `timeMod`: C12
- `aura:GetSpellAuraSecrecy`: **C12** 
- `aura:GetUnitAuras[HARMFUL]`: **K12** 
- `aura:GetUnitAuras[HARMFUL|PLAYER]`: **K12** 
- `aura:GetUnitAuras[HARMFUL|RAID]`: **K12** 
- `aura:GetUnitAuras[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **K12** 
- `aura:GetUnitAuras[HELPFUL]`: **K12** 
- `aura:GetUnitAuras[HELPFUL|PLAYER]`: **K12** 
- `aura:ShouldSpellAuraBeSecret`: **C12** 
- `count:GetAuraSlots(HARMFUL)`: **C12** 
- `count:GetAuraSlots(HARMFUL|PLAYER)`: **C12** 
- `count:GetAuraSlots(HARMFUL|RAID)`: **C12** 
- `count:GetAuraSlots(HARMFUL|RAID_PLAYER_DISPELLABLE)`: **C12** 
- `count:GetAuraSlots(HELPFUL)`: **C12** 
- `count:GetAuraSlots(HELPFUL|PLAYER)`: **C12** 
- `event:UNIT_AURA`: **K3** 
  - `addedAuras`: N2 K1
  - `addedAuras[]`: K1
  - `addedAuras[].applications`: C1
  - `addedAuras[].auraInstanceID`: C1
  - `addedAuras[].canActivePlayerDispel`: C1
  - `addedAuras[].canApplyAura`: C1
  - `addedAuras[].duration`: C1
  - `addedAuras[].expirationTime`: C1
  - `addedAuras[].hideOnPartyFrames`: C1
  - `addedAuras[].icon`: C1
  - `addedAuras[].isBossAura`: C1
  - `addedAuras[].isDPSRoleAura`: C1
  - `addedAuras[].isFromPlayerOrPlayerPet`: C1
  - `addedAuras[].isHarmful`: C1
  - `addedAuras[].isHealerRoleAura`: C1
  - `addedAuras[].isHelpful`: C1
  - `addedAuras[].isNameplateOnly`: C1
  - `addedAuras[].isRaid`: C1
  - `addedAuras[].isStealable`: C1
  - `addedAuras[].isTankRoleAura`: C1
  - `addedAuras[].name`: C1
  - `addedAuras[].nameplateShowAll`: C1
  - `addedAuras[].nameplateShowPersonal`: C1
  - `addedAuras[].points`: K1
  - `addedAuras[].sourceUnit`: C1
  - `addedAuras[].spellId`: C1
  - `addedAuras[].timeMod`: C1
  - `isFullUpdate`: C3
  - `removedAuraInstanceIDs`: K3
  - `updatedAuraInstanceIDs`: N3

</details>

<details><summary>ooc / target:hostile-npc (61 probes)</summary>

- `C_Map.GetPlayerMapPosition`: **N5** 
- `C_Spell.IsSpellInRange`: **N5** 
- `CanCompareUnitTokens`: **C5** 
- `CheckInteractDistance`: **C5** 
- `GetRaidTargetIndex`: **N5** 
- `GetUnitSpeed`: **R5** 
  - `current`: C5
  - `flight`: C5
  - `run`: C5
  - `swim`: C5
- `ShouldUnitIdentityBeSecret`: **C5** 
- `UnitAffectingCombat`: **C5** 
- `UnitCanAttack`: **C5** 
- `UnitCastingInfo`: **N5** 
- `UnitChannelInfo`: **N5** 
- `UnitClass`: **R5** 
  - `classFile`: C5
  - `classID`: C5
  - `className`: C5
- `UnitDetailedThreatSituation`: **N5** 
- `UnitExists`: **C5** 
- `UnitFullName`: **R5** 
  - `name`: C5
  - `realm`: N5
- `UnitGUID`: **C5** 
- `UnitGetIncomingHeals`: **N5** 
- `UnitGetTotalAbsorbs`: **S5** 
- `UnitGetTotalHealAbsorbs`: **S5** 
- `UnitHealth`: **S5** 
- `UnitHealthMax`: **S5** 
- `UnitHealthPercent`: **S5** 
- `UnitInRange`: **R5** 
  - `checked`: S5
  - `inRange`: S5
- `UnitIsDeadOrGhost`: **C5** 
- `UnitIsEnemy`: **C5** 
- `UnitIsFriend`: **C5** 
- `UnitIsPlayer`: **C5** 
- `UnitIsUnit(u,player)`: **C5** 
- `UnitLevel`: **C5** 
- `UnitName`: **R5** 
  - `name`: C5
  - `realm`: N5
- `UnitPosition`: **R5** 
  - `mapID`: C5
  - `x`: N5
  - `y`: N5
  - `z`: N5
- `UnitPower`: **S5** 
- `UnitPowerMax`: **S5** 
- `UnitPowerType`: **R5** 
  - `3`: N5
  - `4`: N5
  - `5`: N5
  - `powerToken`: C5
  - `powerType`: C5
- `UnitRace`: **N5** 
- `UnitReaction`: **C5** 
- `UnitThreatSituation`: **N5** 
- `aura:GetAuraDataByIndex[HARMFUL]`: **N5** 
- `aura:GetAuraDataByIndex[HARMFUL|PLAYER]`: **N5** 
- `aura:GetAuraDataByIndex[HARMFUL|RAID]`: **N5** 
- `aura:GetAuraDataByIndex[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **N5** 
- `aura:GetAuraDataByIndex[HELPFUL]`: **N5** 
- `aura:GetAuraDataByIndex[HELPFUL|PLAYER]`: **N5** 
- `aura:GetAuraSlots[HARMFUL]`: **N5** 
- `aura:GetAuraSlots[HARMFUL|PLAYER]`: **N5** 
- `aura:GetAuraSlots[HARMFUL|RAID]`: **N5** 
- `aura:GetAuraSlots[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **N5** 
- `aura:GetAuraSlots[HELPFUL]`: **N5** 
- `aura:GetAuraSlots[HELPFUL|PLAYER]`: **N5** 
- `aura:GetUnitAuras[HARMFUL]`: **K5** 
- `aura:GetUnitAuras[HARMFUL|PLAYER]`: **K5** 
- `aura:GetUnitAuras[HARMFUL|RAID]`: **K5** 
- `aura:GetUnitAuras[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **K5** 
- `aura:GetUnitAuras[HELPFUL]`: **K5** 
- `aura:GetUnitAuras[HELPFUL|PLAYER]`: **K5** 
- `count:GetAuraSlots(HARMFUL)`: **C5** 
- `count:GetAuraSlots(HARMFUL|PLAYER)`: **C5** 
- `count:GetAuraSlots(HARMFUL|RAID)`: **C5** 
- `count:GetAuraSlots(HARMFUL|RAID_PLAYER_DISPELLABLE)`: **C5** 
- `count:GetAuraSlots(HELPFUL)`: **C5** 
- `count:GetAuraSlots(HELPFUL|PLAYER)`: **C5** 

</details>

<details><summary>ooc / target:self (67 probes)</summary>

- `C_Map.GetPlayerMapPosition`: **K3** 
  - `Add`: C3
  - `Clone`: C3
  - `Cross`: C3
  - `DivideBy`: C3
  - `Dot`: C3
  - `GetLength`: C3
  - `GetLengthSquared`: C3
  - `GetXY`: C3
  - `IsEqualTo`: C3
  - `IsZero`: C3
  - `Normalize`: C3
  - `OnLoad`: C3
  - `RotateDirection`: C3
  - `ScaleBy`: C3
  - `SetXY`: C3
  - `Subtract`: C3
  - `x`: C3
  - `y`: C3
- `C_Spell.IsSpellInRange`: **N3** 
- `CanCompareUnitTokens`: **C3** 
- `CheckInteractDistance`: **C3** 
- `GetRaidTargetIndex`: **N3** 
- `GetUnitSpeed`: **R3** 
  - `current`: C3
  - `flight`: C3
  - `run`: C3
  - `swim`: C3
- `ShouldUnitIdentityBeSecret`: **C3** 
- `UnitAffectingCombat`: **C3** 
- `UnitCanAttack`: **C3** 
- `UnitCastingInfo`: **N3** 
- `UnitChannelInfo`: **N3** 
- `UnitClass`: **R3** 
  - `classFile`: C3
  - `classID`: C3
  - `className`: C3
- `UnitDetailedThreatSituation`: **N3** 
- `UnitExists`: **C3** 
- `UnitFullName`: **R3** 
  - `name`: C3
  - `realm`: C3
- `UnitGUID`: **C3** 
- `UnitGetIncomingHeals`: **S3** 
- `UnitGetTotalAbsorbs`: **S3** 
- `UnitGetTotalHealAbsorbs`: **S3** 
- `UnitHealth`: **S3** 
- `UnitHealthMax`: **C3** 
- `UnitHealthPercent`: **S3** 
- `UnitInRange`: **R3** 
  - `checked`: S3
  - `inRange`: S3
- `UnitIsDeadOrGhost`: **C3** 
- `UnitIsEnemy`: **C3** 
- `UnitIsFriend`: **C3** 
- `UnitIsPlayer`: **C3** 
- `UnitIsUnit(u,player)`: **C3** 
- `UnitLevel`: **C3** 
- `UnitName`: **R3** 
  - `name`: C3
  - `realm`: C3
- `UnitPosition`: **R3** 
  - `mapID`: C3
  - `x`: C3
  - `y`: C3
  - `z`: C3
- `UnitPower`: **S3** 
- `UnitPowerMax`: **C3** 
- `UnitPowerType`: **R3** 
  - `3`: N3
  - `4`: N3
  - `5`: N3
  - `powerToken`: C3
  - `powerType`: C3
- `UnitRace`: **R3** 
  - `raceFile`: C3
  - `raceID`: C3
  - `raceName`: C3
- `UnitReaction`: **C3** 
- `UnitThreatSituation`: **N3** 
- `aura:GetAuraApplicationDisplayCount[HELPFUL]`: **C3** 
- `aura:GetAuraDataByAuraInstanceID[HELPFUL]`: **K3** 
  - `applications`: C3
  - `auraInstanceID`: C3
  - `canActivePlayerDispel`: C3
  - `canApplyAura`: C3
  - `dispelName`: C3
  - `duration`: C3
  - `expirationTime`: C3
  - `hideOnPartyFrames`: C3
  - `icon`: C3
  - `isBossAura`: C3
  - `isDPSRoleAura`: C3
  - `isFromPlayerOrPlayerPet`: C3
  - `isHarmful`: C3
  - `isHealerRoleAura`: C3
  - `isHelpful`: C3
  - `isNameplateOnly`: C3
  - `isRaid`: C3
  - `isStealable`: C3
  - `isTankRoleAura`: C3
  - `name`: C3
  - `nameplateShowAll`: C3
  - `nameplateShowPersonal`: C3
  - `points`: K3
  - `spellId`: C3
  - `timeMod`: C3
- `aura:GetAuraDataByIndex[HARMFUL]`: **N3** 
- `aura:GetAuraDataByIndex[HARMFUL|PLAYER]`: **N3** 
- `aura:GetAuraDataByIndex[HARMFUL|RAID]`: **N3** 
- `aura:GetAuraDataByIndex[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **N3** 
- `aura:GetAuraDataByIndex[HELPFUL]`: **K3** 
  - `applications`: C3
  - `auraInstanceID`: C3
  - `canActivePlayerDispel`: C3
  - `canApplyAura`: C3
  - `dispelName`: C3
  - `duration`: C3
  - `expirationTime`: C3
  - `hideOnPartyFrames`: C3
  - `icon`: C3
  - `isBossAura`: C3
  - `isDPSRoleAura`: C3
  - `isFromPlayerOrPlayerPet`: C3
  - `isHarmful`: C3
  - `isHealerRoleAura`: C3
  - `isHelpful`: C3
  - `isNameplateOnly`: C3
  - `isRaid`: C3
  - `isStealable`: C3
  - `isTankRoleAura`: C3
  - `name`: C3
  - `nameplateShowAll`: C3
  - `nameplateShowPersonal`: C3
  - `points`: K3
  - `spellId`: C3
  - `timeMod`: C3
- `aura:GetAuraDataByIndex[HELPFUL|PLAYER]`: **N3** 
- `aura:GetAuraDataBySlot[HELPFUL]`: **K3** 
  - `applications`: C3
  - `auraInstanceID`: C3
  - `canActivePlayerDispel`: C3
  - `canApplyAura`: C3
  - `dispelName`: C3
  - `duration`: C3
  - `expirationTime`: C3
  - `hideOnPartyFrames`: C3
  - `icon`: C3
  - `isBossAura`: C3
  - `isDPSRoleAura`: C3
  - `isFromPlayerOrPlayerPet`: C3
  - `isHarmful`: C3
  - `isHealerRoleAura`: C3
  - `isHelpful`: C3
  - `isNameplateOnly`: C3
  - `isRaid`: C3
  - `isStealable`: C3
  - `isTankRoleAura`: C3
  - `name`: C3
  - `nameplateShowAll`: C3
  - `nameplateShowPersonal`: C3
  - `points`: K3
  - `spellId`: C3
  - `timeMod`: C3
- `aura:GetAuraDispelTypeColor[HELPFUL]`: **E3** 
- `aura:GetAuraDuration[HELPFUL]`: **K3** 
- `aura:GetAuraDuration[HELPFUL]#object`: **K1** 
  - `GetRemainingDuration()`: C1
  - `GetRemainingPercent()`: C1
  - `GetTotalDuration()`: C1
  - `HasSecretValues()`: C1
  - `IsZero()`: C1
- `aura:GetAuraSlots[HARMFUL]`: **N3** 
- `aura:GetAuraSlots[HARMFUL|PLAYER]`: **N3** 
- `aura:GetAuraSlots[HARMFUL|RAID]`: **N3** 
- `aura:GetAuraSlots[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **N3** 
- `aura:GetAuraSlots[HELPFUL]`: **R3** 
  - `ret1`: N3
  - `ret2`: C3
  - `ret3`: C3
- `aura:GetAuraSlots[HELPFUL|PLAYER]`: **N3** 
- `aura:GetUnitAuras[HARMFUL]`: **K3** 
- `aura:GetUnitAuras[HARMFUL|PLAYER]`: **K3** 
- `aura:GetUnitAuras[HARMFUL|RAID]`: **K3** 
- `aura:GetUnitAuras[HARMFUL|RAID_PLAYER_DISPELLABLE]`: **K3** 
- `aura:GetUnitAuras[HELPFUL]`: **K3** 
- `aura:GetUnitAuras[HELPFUL|PLAYER]`: **K3** 
- `count:GetAuraSlots(HARMFUL)`: **C3** 
- `count:GetAuraSlots(HARMFUL|PLAYER)`: **C3** 
- `count:GetAuraSlots(HARMFUL|RAID)`: **C3** 
- `count:GetAuraSlots(HARMFUL|RAID_PLAYER_DISPELLABLE)`: **C3** 
- `count:GetAuraSlots(HELPFUL)`: **C3** 
- `count:GetAuraSlots(HELPFUL|PLAYER)`: **C3** 

</details>

<details><summary>ooc / targettarget:self (37 probes)</summary>

- `C_Map.GetPlayerMapPosition`: **K3** 
  - `Add`: C3
  - `Clone`: C3
  - `Cross`: C3
  - `DivideBy`: C3
  - `Dot`: C3
  - `GetLength`: C3
  - `GetLengthSquared`: C3
  - `GetXY`: C3
  - `IsEqualTo`: C3
  - `IsZero`: C3
  - `Normalize`: C3
  - `OnLoad`: C3
  - `RotateDirection`: C3
  - `ScaleBy`: C3
  - `SetXY`: C3
  - `Subtract`: C3
  - `x`: C3
  - `y`: C3
- `C_Spell.IsSpellInRange`: **N3** 
- `CanCompareUnitTokens`: **C3** 
- `CheckInteractDistance`: **C3** 
- `GetRaidTargetIndex`: **N3** 
- `GetUnitSpeed`: **R3** 
  - `current`: C3
  - `flight`: C3
  - `run`: C3
  - `swim`: C3
- `ShouldUnitIdentityBeSecret`: **C3** 
- `UnitAffectingCombat`: **C3** 
- `UnitCanAttack`: **C3** 
- `UnitCastingInfo`: **N3** 
- `UnitChannelInfo`: **N3** 
- `UnitClass`: **R3** 
  - `classFile`: C3
  - `classID`: C3
  - `className`: C3
- `UnitDetailedThreatSituation`: **N3** 
- `UnitExists`: **C3** 
- `UnitFullName`: **R3** 
  - `name`: C3
  - `realm`: C3
- `UnitGUID`: **C3** 
- `UnitGetIncomingHeals`: **S3** 
- `UnitGetTotalAbsorbs`: **S3** 
- `UnitGetTotalHealAbsorbs`: **S3** 
- `UnitHealth`: **S3** 
- `UnitHealthMax`: **C3** 
- `UnitHealthPercent`: **S3** 
- `UnitInRange`: **R3** 
  - `checked`: S3
  - `inRange`: S3
- `UnitIsDeadOrGhost`: **C3** 
- `UnitIsEnemy`: **C3** 
- `UnitIsFriend`: **C3** 
- `UnitIsPlayer`: **C3** 
- `UnitIsUnit(u,player)`: **C3** 
- `UnitLevel`: **C3** 
- `UnitName`: **R3** 
  - `name`: C3
  - `realm`: C3
- `UnitPosition`: **R3** 
  - `mapID`: C3
  - `x`: C3
  - `y`: C3
  - `z`: C3
- `UnitPower`: **S3** 
- `UnitPowerMax`: **C3** 
- `UnitPowerType`: **R3** 
  - `3`: N3
  - `4`: N3
  - `5`: N3
  - `powerToken`: C3
  - `powerType`: C3
- `UnitRace`: **R3** 
  - `raceFile`: C3
  - `raceID`: C3
  - `raceName`: C3
- `UnitReaction`: **C3** 
- `UnitThreatSituation`: **N3** 

</details>

