# Forever secrets VERIFY report

Build 1.60.1.70245 (toc 16001). Documented secrecy (APIDocumentation) reconciled with live observations (issecretvalue per position, per context `state/instanceType/unit`).

- CONFIRMED: docs and observations agree (conditional + only clear so far is CONFIRMED but marked unverified)
- **CONTRADICTED**: docs say secret but it was observed clear in that context, or NeverSecret observed secret
- UNOBSERVED: no data yet
- **UNDOCUMENTED-SECRET**: observed secret, no secrecy annotation

## Summary

- CONTRADICTED: 7
- UNDOCUMENTED-SECRET: 5
- CONFIRMED: 473
- UNOBSERVED: 9282

## Coverage

| scope | positions | observed | % |
|---|---|---|---|
| all | 9748 | 466 | 4.78 |
| documentedSecretOrNever | 1564 | 243 | 15.54 |
| functionReturnsSecret | 325 | 169 | 52.00 |
| eventPayloadSecret | 403 | 43 | 10.67 |
| verifiedInCombat | 728 | 211 | 28.98 |

Capture sessions: cap-20261007195248-2 (sweep calls 1796)

## CONTRADICTED (7)

| key | pos | name | documented | samples | secret | clear | secret in | clear in | note |
|---|---|---|---|---|---|---|---|---|---|
| api:C_CombatText.GetCurrentEventInfo | 1 |  | always | 14 | 0 | 14 |  | combat/none/none, ooc/none/none | documented always-secret, observed clear in combat/none/none, ooc/none/none |
| api:GetRaidTargetIndex | 1 | result | always | 19 | 0 | 19 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | documented always-secret, observed clear in combat/none/other, combat/none/self, ooc/none/other, ooc/none/self |
| api:UnitCastingDuration | 1 | duration | always | 18 | 0 | 18 |  | combat/none/other, combat/none/self, ooc/none/self | documented always-secret, observed clear in combat/none/other, combat/none/self, ooc/none/self |
| api:UnitGetIncomingHeals | 1 | result | always | 23 | 18 | 5 | combat/none/none, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self | combat/none/none, combat/none/other | documented always-secret, observed clear in combat/none/none, combat/none/other |
| api:UnitPowerBarTimerInfo | 1 | duration | always | 20 | 0 | 20 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | documented always-secret, observed clear in combat/none/other, combat/none/self, ooc/none/other, ooc/none/self |
| api:UnitSpellTargetClass | 1 | classFilename | always | 18 | 6 | 12 | combat/none/self, ooc/none/self | combat/none/other, ooc/none/other, ooc/none/self | documented always-secret, observed clear in combat/none/other, ooc/none/other, ooc/none/self |
| api:UnitSpellTargetName | 1 | targetName | always | 18 | 6 | 12 | combat/none/self, ooc/none/self | combat/none/other, ooc/none/other, ooc/none/self | documented always-secret, observed clear in combat/none/other, ooc/none/other, ooc/none/self |

## UNDOCUMENTED-SECRET (5)

| key | pos | name | documented | samples | secret | clear | secret in | clear in | note |
|---|---|---|---|---|---|---|---|---|---|
| field:C_Spell.GetSpellCooldown#1.activeCategory | 1 |  | unspecified | 8 | 6 | 2 | combat/none/none | ooc/none/none | no secrecy annotation, observed secret in combat/none/none |
| field:C_Spell.GetSpellCooldown#1.duration | 1 |  | unspecified | 24 | 8 | 16 | combat/none/none | ooc/none/none | no secrecy annotation, observed secret in combat/none/none |
| field:C_Spell.GetSpellCooldown#1.modRate | 1 |  | unspecified | 24 | 8 | 16 | combat/none/none | ooc/none/none | no secrecy annotation, observed secret in combat/none/none |
| field:C_Spell.GetSpellCooldown#1.startTime | 1 |  | unspecified | 24 | 8 | 16 | combat/none/none | ooc/none/none | no secrecy annotation, observed secret in combat/none/none |
| field:C_Spell.GetSpellCooldown#1.timeUntilEndOfStartRecovery | 1 |  | unspecified | 8 | 6 | 2 | combat/none/none | ooc/none/none | no secrecy annotation, observed secret in combat/none/none |

## CONFIRMED (473)

| key | pos | name | documented | samples | secret | clear | secret in | clear in | note |
|---|---|---|---|---|---|---|---|---|---|
| api:C_ChatInfo.AreOutgoingAddonChatMessagesRestricted | 1 | isRestricted | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:C_Club.IsRestricted | 1 | restrictionReason | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:C_CombatLog.IsCombatLogRestricted | 1 | restricted | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:C_Container.GetItemCooldown | 1 | startTime | unspecified | 18 | 0 | 18 |  | combat/none/none, ooc/none/none |  |
| api:C_Container.GetItemCooldown | 2 | duration | unspecified | 18 | 0 | 18 |  | combat/none/none, ooc/none/none |  |
| api:C_Container.GetItemCooldown | 3 | enable | unspecified | 18 | 0 | 18 |  | combat/none/none, ooc/none/none |  |
| api:C_DamageMeter.GetCombatSessionFromType | 1 | session | conditional | 110 | 0 | 110 |  | ooc/none/none | clear so far (condition not triggered in: ooc/none/none) |
| api:C_Item.GetDetailedItemLevelInfo | 1 | actualItemLevel | unspecified | 18 | 0 | 18 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetDetailedItemLevelInfo | 2 | previewLevel | unspecified | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetDetailedItemLevelInfo | 3 | sparseItemLevel | unspecified | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemCooldown | 1 | startTimeSeconds | unspecified | 18 | 0 | 18 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemCooldown | 2 | durationSeconds | unspecified | 18 | 0 | 18 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemCooldown | 3 | enableCooldownTimer | unspecified | 18 | 0 | 18 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemCount | 1 | count | unspecified | 18 | 0 | 18 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemIconByID | 1 | icon | unspecified | 18 | 0 | 18 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfo | 1 | itemName | unspecified | 18 | 0 | 18 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfo | 2 | itemLink | unspecified | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfo | 3 | itemQuality | unspecified | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfo | 4 | itemLevel | unspecified | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfo | 5 | itemMinLevel | unspecified | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfo | 6 | itemType | unspecified | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfo | 7 | itemSubType | unspecified | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfo | 8 | itemStackCount | unspecified | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfo | 9 | itemEquipLoc | unspecified | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfo | 10 | itemTexture | unspecified | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfo | 11 | sellPrice | unspecified | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfo | 12 | classID | unspecified | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfo | 13 | subclassID | unspecified | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfo | 14 | bindType | unspecified | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfo | 15 | expansionID | unspecified | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfo | 16 | setID | unspecified | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfo | 17 | isCraftingReagent | unspecified | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfo | 18 | itemDescription | unspecified | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfoInstant | 1 | itemID | unspecified | 18 | 0 | 18 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfoInstant | 2 | itemType | unspecified | 18 | 0 | 18 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfoInstant | 3 | itemSubType | unspecified | 18 | 0 | 18 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfoInstant | 4 | itemEquipLoc | unspecified | 18 | 0 | 18 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfoInstant | 5 | icon | unspecified | 18 | 0 | 18 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfoInstant | 6 | classID | unspecified | 18 | 0 | 18 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemInfoInstant | 7 | subClassID | unspecified | 18 | 0 | 18 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemNameByID | 1 | itemName | unspecified | 18 | 0 | 18 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemQualityByID | 1 | itemQuality | unspecified | 18 | 0 | 18 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemSpell | 1 | spellName | unspecified | 18 | 0 | 18 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.GetItemSpell | 2 | spellID | unspecified | 10 | 0 | 10 |  | combat/none/none, ooc/none/none |  |
| api:C_Item.IsItemDataCachedByID | 1 | isCached | unspecified | 18 | 0 | 18 |  | combat/none/none, ooc/none/none |  |
| api:C_LFGList.GetActiveEntryInfo | 1 | entryData | conditional | 14 | 0 | 14 |  | combat/none/none, ooc/none/none | clear so far (condition not triggered in: combat/none/none, ooc/none/none) |
| api:C_PartyInfo.GetRestrictPings | 1 | restrictTo | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:C_PlayerInfo.IsPlayerNPERestricted | 1 | isRestricted | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:C_PlayerMentorship.IsMentorRestricted | 1 | isRestricted | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:C_PvP.GetArenaCrowdControlInfo | 1 | spellID | conditional | 18 | 0 | 18 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:C_QuestLog.GetLogIndexForQuestID | 1 | questLogIndex | unspecified | 9 | 0 | 9 |  | combat/none/none, ooc/none/none |  |
| api:C_QuestLog.GetQuestObjectives | 1 | objectives | unspecified | 9 | 0 | 9 |  | combat/none/none, ooc/none/none |  |
| api:C_QuestLog.GetQuestTagInfo | 1 | info | unspecified | 9 | 0 | 9 |  | combat/none/none, ooc/none/none |  |
| api:C_QuestLog.GetTitleForQuestID | 1 | title | unspecified | 9 | 0 | 9 |  | combat/none/none, ooc/none/none |  |
| api:C_QuestLog.IsOnQuest | 1 | isOnQuest | unspecified | 9 | 0 | 9 |  | combat/none/none, ooc/none/none |  |
| api:C_QuestLog.IsQuestFlaggedCompleted | 1 | isCompleted | unspecified | 9 | 0 | 9 |  | combat/none/none, ooc/none/none |  |
| api:C_QuestLog.ReadyForTurnIn | 1 | readyForTurnIn | unspecified | 9 | 0 | 9 |  | combat/none/none, ooc/none/none |  |
| api:C_ScenarioInfo.GetUnitCriteriaProgressValues | 1 | actualValue | conditional | 18 | 0 | 18 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:C_Secrets.GetSpellAuraSecrecy | 1 | secrecy | unspecified | 40 | 0 | 40 |  | combat/none/none, ooc/none/none |  |
| api:C_Secrets.GetSpellCastSecrecy | 1 | secrecy | unspecified | 40 | 0 | 40 |  | combat/none/none, ooc/none/none |  |
| api:C_Secrets.GetSpellCooldownSecrecy | 1 | secrecy | unspecified | 40 | 0 | 40 |  | combat/none/none, ooc/none/none |  |
| api:C_Secrets.HasSecretRestrictions | 1 | hasSecretRestrictions | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:C_Secrets.ShouldAurasBeSecret | 1 | hasSecretAuras | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:C_Secrets.ShouldCooldownsBeSecret | 1 | hasSecretCooldowns | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:C_Secrets.ShouldUnitStatsBeSecret | 1 | hasSecretStats | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:C_SocialRestrictions.IsAgeVerificationRestricted | 1 | restricted | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:C_SpecializationInfo.GetInspectSpecialization | 1 | specializationID | conditional | 18 | 0 | 18 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:C_Spell.DoesSpellExist | 1 | spellExists | unspecified | 24 | 0 | 24 |  | combat/none/none, ooc/none/none |  |
| api:C_Spell.GetSpellCastCount | 1 | castCount | conditional | 24 | 8 | 16 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:C_Spell.GetSpellCharges | 1 | chargeInfo | conditional | 24 | 0 | 24 |  | combat/none/none, ooc/none/none | clear so far (condition not triggered in: combat/none/none, ooc/none/none) |
| api:C_Spell.GetSpellCooldown | 1 | spellCooldownInfo | conditional | 24 | 0 | 24 |  | combat/none/none, ooc/none/none | clear so far (condition not triggered in: combat/none/none, ooc/none/none) |
| api:C_Spell.GetSpellCooldownDuration | 1 | duration | unspecified | 24 | 0 | 24 |  | combat/none/none, ooc/none/none |  |
| api:C_Spell.GetSpellDescription | 1 | description | unspecified | 24 | 0 | 24 |  | combat/none/none, ooc/none/none |  |
| api:C_Spell.GetSpellInfo | 1 | spellInfo | unspecified | 24 | 0 | 24 |  | combat/none/none, ooc/none/none |  |
| api:C_Spell.GetSpellLink | 1 | spellLink | unspecified | 24 | 0 | 24 |  | combat/none/none, ooc/none/none |  |
| api:C_Spell.GetSpellName | 1 | name | unspecified | 24 | 0 | 24 |  | combat/none/none, ooc/none/none |  |
| api:C_Spell.GetSpellPowerCost | 1 | powerCosts | unspecified | 24 | 0 | 24 |  | combat/none/none, ooc/none/none |  |
| api:C_Spell.GetSpellTexture | 1 | iconID | unspecified | 24 | 0 | 24 |  | combat/none/none, ooc/none/none |  |
| api:C_Spell.GetSpellTexture | 2 | originalIconID | unspecified | 24 | 0 | 24 |  | combat/none/none, ooc/none/none |  |
| api:C_Spell.GetSpellTexture | 3 | conditionalIconID | unspecified | 24 | 0 | 24 |  | combat/none/none, ooc/none/none |  |
| api:C_Spell.IsSpellPassive | 1 | isPassive | unspecified | 24 | 0 | 24 |  | combat/none/none, ooc/none/none |  |
| api:C_Spell.IsSpellUsable | 1 | isUsable | unspecified | 24 | 0 | 24 |  | combat/none/none, ooc/none/none |  |
| api:C_Spell.IsSpellUsable | 2 | insufficientPower | unspecified | 24 | 0 | 24 |  | combat/none/none, ooc/none/none |  |
| api:C_SpellBook.IsSpellInSpellBook | 1 | isInSpellBook | unspecified | 24 | 0 | 24 |  | combat/none/none, ooc/none/none |  |
| api:C_SpellBook.IsSpellKnown | 1 | isKnown | unspecified | 24 | 0 | 24 |  | combat/none/none, ooc/none/none |  |
| api:GetArmorPenetration | 1 | result | conditional | 14 | 2 | 12 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetAvoidance | 1 | result | conditional | 14 | 2 | 12 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetBlockChance | 1 | result | conditional | 14 | 2 | 12 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetCritChance | 1 | result | conditional | 14 | 2 | 12 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetDodgeChance | 1 | result | conditional | 14 | 2 | 12 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetDodgeChanceFromAttribute | 1 | result | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetExpertise | 1 | mainhandExpertise | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetExpertise | 2 | offhandExpertise | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetExpertise | 3 | rangedExpertise | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetExpertisePercent | 1 | mainhandExpertisePercent | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetExpertisePercent | 2 | offhandExpertisePercent | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetExpertisePercent | 3 | rangedExpertisePercent | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetHaste | 1 | result | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetHitModifier | 1 | result | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetLifesteal | 1 | result | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetManaRegen | 1 | baseManaRegen | conditional | 14 | 4 | 10 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetManaRegen | 2 | castingManaRegen | conditional | 14 | 4 | 10 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetMastery | 1 | result | conditional | 14 | 4 | 10 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetMasteryEffect | 1 | masteryEffect | conditional | 14 | 4 | 10 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetMasteryEffect | 2 | bonusCoefficient | conditional | 14 | 4 | 10 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetMeleeHaste | 1 | result | conditional | 14 | 4 | 10 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetModResilienceDamageReduction | 1 | result | conditional | 14 | 4 | 10 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetOverrideAPBySpellPower | 1 | result | conditional | 14 | 4 | 10 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetOverrideSpellPowerByAP | 1 | result | conditional | 14 | 4 | 10 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetParryChance | 1 | result | conditional | 14 | 4 | 10 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetParryChanceFromAttribute | 1 | result | conditional | 14 | 4 | 10 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetPetHitChanceModifier | 1 | result | conditional | 14 | 4 | 10 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetPetMeleeHaste | 1 | result | conditional | 14 | 4 | 10 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetPetSpellBonusDamage | 1 | result | conditional | 14 | 4 | 10 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetPetSpellHitChanceModifier | 1 | result | conditional | 14 | 4 | 10 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetPowerRegen | 1 | basePowerRegen | conditional | 14 | 4 | 10 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetPowerRegen | 2 | castingPowerRegen | conditional | 14 | 4 | 10 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetPvpPowerDamage | 1 | result | conditional | 14 | 4 | 10 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetPvpPowerHealing | 1 | result | conditional | 14 | 4 | 10 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetRangedCritChance | 1 | result | conditional | 14 | 4 | 10 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetRangedHaste | 1 | result | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetRangedHaste | 2 | quiverHaste | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetRangedHitModifier | 1 | result | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetRestrictedAccountData | 1 | maxLevel | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:GetRestrictedAccountData | 2 | maxMoney | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:GetRestrictedAccountData | 3 | professionCap | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:GetShieldBlock | 1 | result | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetSpeed | 1 | result | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetSpellBonusHealing | 1 | result | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetSpellCritChance | 1 | result | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetSpellHitModifier | 1 | result | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetSpellPenetration | 1 | result | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetSturdiness | 1 | result | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:GetUnitChargedPowerPoints | 1 | pointIndices | conditional | 19 | 0 | 19 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:GetUnitEmpowerHoldAtMaxTime | 1 | holdAtMaxTime | conditional | 19 | 5 | 14 | combat/none/other, ooc/none/other | combat/none/self, ooc/none/self | secret in combat/none/other, ooc/none/other |
| api:GetUnitEmpowerMinHoldTime | 1 | minHoldTime | conditional | 19 | 5 | 14 | combat/none/other, ooc/none/other | combat/none/self, ooc/none/self | secret in combat/none/other, ooc/none/other |
| api:GetUnitSpeed | 1 | currentSpeed | conditional | 24 | 9 | 15 | combat/none/none, combat/none/other, combat/none/self | ooc/none/none, ooc/none/other, ooc/none/self | secret in combat/none/none, combat/none/other, combat/none/self |
| api:GetUnitSpeed | 2 | runSpeed | conditional | 24 | 9 | 15 | combat/none/none, combat/none/other, combat/none/self | ooc/none/none, ooc/none/other, ooc/none/self | secret in combat/none/none, combat/none/other, combat/none/self |
| api:GetUnitSpeed | 3 | flightSpeed | conditional | 24 | 9 | 15 | combat/none/none, combat/none/other, combat/none/self | ooc/none/none, ooc/none/other, ooc/none/self | secret in combat/none/none, combat/none/other, combat/none/self |
| api:GetUnitSpeed | 4 | swimSpeed | conditional | 24 | 9 | 15 | combat/none/none, combat/none/other, combat/none/self | ooc/none/none, ooc/none/other, ooc/none/self | secret in combat/none/none, combat/none/other, combat/none/self |
| api:IsRestrictedAccount | 1 | result | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:PlayerEffectiveAttackPower | 1 | mainHandAttackPower | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:PlayerEffectiveAttackPower | 2 | offHandAttackPower | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:PlayerEffectiveAttackPower | 3 | rangedAttackPower | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:PlayerEffectiveAttackPower | 4 | baseAttackPower | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:PlayerEffectiveAttackPower | 5 | baseRangedAttackPower | conditional | 14 | 3 | 11 | combat/none/none | ooc/none/none | secret in combat/none/none |
| api:PlayerIsSpellTarget | 1 | result | always | 18 | 18 | 0 | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self |  |  |
| api:UnitAffectingCombat | 1 | result | unspecified | 7 | 0 | 7 |  | combat/none/none, ooc/none/none |  |
| api:UnitArmor | 1 | base | conditional | 23 | 9 | 14 | combat/none/none, combat/none/other, combat/none/self | ooc/none/none, ooc/none/other, ooc/none/self | secret in combat/none/none, combat/none/other, combat/none/self |
| api:UnitArmor | 2 | effective | conditional | 23 | 9 | 14 | combat/none/none, combat/none/other, combat/none/self | ooc/none/none, ooc/none/other, ooc/none/self | secret in combat/none/none, combat/none/other, combat/none/self |
| api:UnitArmor | 3 | real | conditional | 23 | 9 | 14 | combat/none/none, combat/none/other, combat/none/self | ooc/none/none, ooc/none/other, ooc/none/self | secret in combat/none/none, combat/none/other, combat/none/self |
| api:UnitArmor | 4 | bonus | conditional | 23 | 9 | 14 | combat/none/none, combat/none/other, combat/none/self | ooc/none/none, ooc/none/other, ooc/none/self | secret in combat/none/none, combat/none/other, combat/none/self |
| api:UnitAttackPower | 1 | attackPower | conditional | 23 | 9 | 14 | combat/none/none, combat/none/other, combat/none/self | ooc/none/none, ooc/none/other, ooc/none/self | secret in combat/none/none, combat/none/other, combat/none/self |
| api:UnitAttackPower | 2 | posBuff | conditional | 23 | 9 | 14 | combat/none/none, combat/none/other, combat/none/self | ooc/none/none, ooc/none/other, ooc/none/self | secret in combat/none/none, combat/none/other, combat/none/self |
| api:UnitAttackPower | 3 | negBuff | conditional | 23 | 9 | 14 | combat/none/none, combat/none/other, combat/none/self | ooc/none/none, ooc/none/other, ooc/none/self | secret in combat/none/none, combat/none/other, combat/none/self |
| api:UnitAttackSpeed | 1 | attackSpeed | conditional | 18 | 6 | 12 | combat/none/other, combat/none/self | ooc/none/other, ooc/none/self | secret in combat/none/other, combat/none/self |
| api:UnitAttackSpeed | 2 | offhandAttackSpeed | conditional | 18 | 0 | 18 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitAttackSpeed | 3 | rangedAttackSpeed | conditional | 18 | 0 | 18 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitCanAttack | 1 | result | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:UnitCastingInfo | 1 | name | conditional | 24 | 0 | 24 |  | combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self) |
| api:UnitChannelInfo | 1 | name | conditional | 24 | 0 | 24 |  | combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self) |
| api:UnitClass | 1 | className | conditional | 24 | 0 | 24 |  | combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self) |
| api:UnitClass | 2 | classFilename | conditional | 24 | 0 | 24 |  | combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self) |
| api:UnitClass | 3 | classID | conditional | 24 | 0 | 24 |  | combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self) |
| api:UnitClassBase | 1 | classFilename | conditional | 19 | 0 | 19 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitClassBase | 2 | classID | conditional | 19 | 0 | 19 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitClassification | 1 | result | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:UnitCreatureFamily | 1 | name | conditional | 24 | 0 | 24 |  | combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self) |
| api:UnitCreatureFamily | 2 | id | conditional | 6 | 0 | 6 |  | combat/none/none, combat/none/other | clear so far (condition not triggered in: combat/none/none, combat/none/other) |
| api:UnitCreatureType | 1 | name | conditional | 23 | 0 | 23 |  | combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self) |
| api:UnitCreatureType | 2 | id | conditional | 23 | 0 | 23 |  | combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self) |
| api:UnitDamage | 1 | minDamage | conditional | 18 | 6 | 12 | combat/none/other, combat/none/self | ooc/none/other, ooc/none/self | secret in combat/none/other, combat/none/self |
| api:UnitDamage | 2 | maxDamage | conditional | 18 | 6 | 12 | combat/none/other, combat/none/self | ooc/none/other, ooc/none/self | secret in combat/none/other, combat/none/self |
| api:UnitDamage | 3 | offhandMinDamage | conditional | 18 | 6 | 12 | combat/none/other, combat/none/self | ooc/none/other, ooc/none/self | secret in combat/none/other, combat/none/self |
| api:UnitDamage | 4 | offhandMaxDamage | conditional | 18 | 6 | 12 | combat/none/other, combat/none/self | ooc/none/other, ooc/none/self | secret in combat/none/other, combat/none/self |
| api:UnitDamage | 5 | posBuff | conditional | 18 | 6 | 12 | combat/none/other, combat/none/self | ooc/none/other, ooc/none/self | secret in combat/none/other, combat/none/self |
| api:UnitDamage | 6 | negBuff | conditional | 18 | 6 | 12 | combat/none/other, combat/none/self | ooc/none/other, ooc/none/self | secret in combat/none/other, combat/none/self |
| api:UnitDamage | 7 | percent | conditional | 18 | 6 | 12 | combat/none/other, combat/none/self | ooc/none/other, ooc/none/self | secret in combat/none/other, combat/none/self |
| api:UnitDefenseSkill | 1 | base | conditional | 18 | 6 | 12 | combat/none/other, combat/none/self | ooc/none/other, ooc/none/self | secret in combat/none/other, combat/none/self |
| api:UnitDefenseSkill | 2 | modifier | conditional | 18 | 6 | 12 | combat/none/other, combat/none/self | ooc/none/other, ooc/none/self | secret in combat/none/other, combat/none/self |
| api:UnitDetailedThreatSituation | 1 | isTanking | conditional | 5 | 1 | 4 | combat/none/none | combat/none/none, ooc/none/none | secret in combat/none/none |
| api:UnitDetailedThreatSituation | 2 | status | conditional | 2 | 1 | 1 | combat/none/none | combat/none/none | secret in combat/none/none |
| api:UnitDetailedThreatSituation | 3 | scaledPercentage | conditional | 2 | 1 | 1 | combat/none/none | combat/none/none | secret in combat/none/none |
| api:UnitDetailedThreatSituation | 4 | rawPercentage | conditional | 2 | 1 | 1 | combat/none/none | combat/none/none | secret in combat/none/none |
| api:UnitDetailedThreatSituation | 5 | rawThreat | conditional | 2 | 1 | 1 | combat/none/none | combat/none/none | secret in combat/none/none |
| api:UnitEffectiveLevel | 1 | result | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:UnitExists | 1 | result | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:UnitFactionGroup | 1 | factionGroupTag | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:UnitFactionGroup | 2 | localized | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:UnitFullName | 1 | unitName | conditional | 18 | 0 | 18 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitFullName | 2 | unitServer | conditional | 18 | 0 | 18 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitGUID | 1 | result | conditional | 23 | 0 | 23 |  | combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self) |
| api:UnitGetAvailableRoles | 1 | tank | conditional | 18 | 0 | 18 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitGetAvailableRoles | 2 | healer | conditional | 18 | 0 | 18 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitGetAvailableRoles | 3 | dps | conditional | 18 | 0 | 18 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitGetTotalAbsorbs | 1 | result | always | 22 | 22 | 0 | combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self |  |  |
| api:UnitGetTotalHealAbsorbs | 1 | result | always | 17 | 17 | 0 | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self |  |  |
| api:UnitGroupRolesAssigned | 1 | result | conditional | 17 | 0 | 17 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitGroupRolesAssignedEnum | 1 | result | conditional | 18 | 0 | 18 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitHasEffectivelyTankAura | 1 | result | conditional | 18 | 0 | 18 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitHealth | 1 | result | always | 22 | 22 | 0 | combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self |  |  |
| api:UnitHealthMax | 1 | result | conditional | 22 | 5 | 17 | combat/none/none, combat/none/other, ooc/none/other | combat/none/none, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self | secret in combat/none/none, combat/none/other, ooc/none/other |
| api:UnitHealthMissing | 1 | result | always | 22 | 22 | 0 | combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self |  |  |
| api:UnitHealthPercent | 1 | result | always | 22 | 22 | 0 | combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self |  |  |
| api:UnitHonorLevel | 1 | result | conditional | 17 | 0 | 17 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitInRaid | 1 | result | conditional | 17 | 0 | 17 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitInRange | 1 | inRange | always | 22 | 22 | 0 | combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self |  |  |
| api:UnitInRange | 2 | checkedRange | always | 22 | 22 | 0 | combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self |  |  |
| api:UnitIsAFK | 1 | result | conditional | 17 | 0 | 17 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitIsCharmed | 1 | result | conditional | 17 | 2 | 15 | combat/none/other | combat/none/self, ooc/none/other, ooc/none/self | secret in combat/none/other |
| api:UnitIsDND | 1 | result | conditional | 17 | 0 | 17 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitIsDead | 1 | result | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:UnitIsEnemy | 1 | result | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:UnitIsFriend | 1 | result | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:UnitIsGhost | 1 | result | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:UnitIsGroupAssistant | 1 | isAssistant | conditional | 17 | 0 | 17 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitIsGroupLeader | 1 | isLeader | conditional | 17 | 0 | 17 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitIsPVP | 1 | result | conditional | 17 | 0 | 17 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitIsPlayer | 1 | result | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:UnitIsPossessed | 1 | result | conditional | 18 | 2 | 16 | combat/none/other | combat/none/self, ooc/none/other, ooc/none/self | secret in combat/none/other |
| api:UnitIsRaidOfficer | 1 | result | conditional | 18 | 0 | 18 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitIsTapDenied | 1 | result | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:UnitIsUnit | 1 | result | conditional | 5 | 0 | 5 |  | combat/none/none, ooc/none/none | clear so far (condition not triggered in: combat/none/none, ooc/none/none) |
| api:UnitIsVisible | 1 | result | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:UnitLeadsAnyGroup | 1 | isLeader | conditional | 18 | 0 | 18 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitLevel | 1 | result | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:UnitName | 1 | unitName | conditional | 23 | 0 | 23 |  | combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self) |
| api:UnitName | 2 | unitServer | conditional | 23 | 0 | 23 |  | combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self) |
| api:UnitNameUnmodified | 1 | unitName | conditional | 18 | 0 | 18 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitNameUnmodified | 2 | unitServer | conditional | 18 | 0 | 18 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitOwnerGUID | 1 | ownerGUID | conditional | 18 | 0 | 18 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitPVPName | 1 | result | conditional | 19 | 0 | 19 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitPartialPower | 1 | partialPower | conditional | 20 | 20 | 0 | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self |  | secret in combat/none/other, combat/none/self, ooc/none/other, ooc/none/self |
| api:UnitPhaseReason | 1 | reason | conditional | 20 | 0 | 20 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitPower | 1 | power | conditional | 25 | 25 | 0 | combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self |  | secret in combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self |
| api:UnitPowerMax | 1 | maxPower | conditional | 24 | 7 | 17 | combat/none/none, combat/none/other, ooc/none/other | combat/none/none, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self | secret in combat/none/none, combat/none/other, ooc/none/other |
| api:UnitPowerMissing | 1 | result | conditional | 19 | 19 | 0 | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self |  | secret in combat/none/other, combat/none/self, ooc/none/other, ooc/none/self |
| api:UnitPowerPercent | 1 | result | conditional | 19 | 19 | 0 | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self |  | secret in combat/none/other, combat/none/self, ooc/none/other, ooc/none/self |
| api:UnitPowerType | 1 | powerType | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:UnitPowerType | 2 | powerTypeToken | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:UnitPowerType | 3 | rgbX | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:UnitPowerType | 4 | rgbY | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:UnitPowerType | 5 | rgbZ | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:UnitRace | 1 | localizedRaceName | conditional | 24 | 0 | 24 |  | combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self) |
| api:UnitRace | 2 | englishRaceName | conditional | 17 | 0 | 17 |  | combat/none/none, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/none, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self) |
| api:UnitRace | 3 | raceID | conditional | 17 | 0 | 17 |  | combat/none/none, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/none, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self) |
| api:UnitRangedAttackPower | 1 | attackPower | conditional | 19 | 8 | 11 | combat/none/other, combat/none/self | ooc/none/other, ooc/none/self | secret in combat/none/other, combat/none/self |
| api:UnitRangedAttackPower | 2 | posBuff | conditional | 19 | 8 | 11 | combat/none/other, combat/none/self | ooc/none/other, ooc/none/self | secret in combat/none/other, combat/none/self |
| api:UnitRangedAttackPower | 3 | negBuff | conditional | 19 | 8 | 11 | combat/none/other, combat/none/self | ooc/none/other, ooc/none/self | secret in combat/none/other, combat/none/self |
| api:UnitRangedDamage | 1 | speed | conditional | 19 | 8 | 11 | combat/none/other, combat/none/self | ooc/none/other, ooc/none/self | secret in combat/none/other, combat/none/self |
| api:UnitRangedDamage | 2 | minDamage | conditional | 19 | 8 | 11 | combat/none/other, combat/none/self | ooc/none/other, ooc/none/self | secret in combat/none/other, combat/none/self |
| api:UnitRangedDamage | 3 | maxDamage | conditional | 19 | 8 | 11 | combat/none/other, combat/none/self | ooc/none/other, ooc/none/self | secret in combat/none/other, combat/none/self |
| api:UnitRangedDamage | 4 | posBuff | conditional | 19 | 8 | 11 | combat/none/other, combat/none/self | ooc/none/other, ooc/none/self | secret in combat/none/other, combat/none/self |
| api:UnitRangedDamage | 5 | negBuff | conditional | 19 | 8 | 11 | combat/none/other, combat/none/self | ooc/none/other, ooc/none/self | secret in combat/none/other, combat/none/self |
| api:UnitRangedDamage | 6 | percent | conditional | 19 | 8 | 11 | combat/none/other, combat/none/self | ooc/none/other, ooc/none/self | secret in combat/none/other, combat/none/self |
| api:UnitReaction | 1 | result | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| api:UnitSex | 1 | sex | conditional | 24 | 0 | 24 |  | combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self) |
| api:UnitSexBase | 1 | sex | conditional | 19 | 0 | 19 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| api:UnitSpellHaste | 1 | result | conditional | 19 | 8 | 11 | combat/none/other, combat/none/self | ooc/none/other, ooc/none/self | secret in combat/none/other, combat/none/self |
| api:UnitStagger | 1 | result | conditional | 18 | 4 | 14 | combat/none/other, ooc/none/other | combat/none/self, ooc/none/other, ooc/none/self | secret in combat/none/other, ooc/none/other |
| api:UnitThreatSituation | 1 | result | conditional | 23 | 1 | 22 | combat/none/none | combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self | secret in combat/none/none |
| api:UnitWeaponAttackPower | 1 | mainHandWeaponAttackPower | conditional | 18 | 6 | 12 | combat/none/other, combat/none/self | ooc/none/other, ooc/none/self | secret in combat/none/other, combat/none/self |
| api:UnitWeaponAttackPower | 2 | offHandWeaponAttackPower | conditional | 18 | 6 | 12 | combat/none/other, combat/none/self | ooc/none/other, ooc/none/self | secret in combat/none/other, combat/none/self |
| api:UnitWeaponAttackPower | 3 | rangedWeaponAttackPower | conditional | 18 | 6 | 12 | combat/none/other, combat/none/self | ooc/none/other, ooc/none/self | secret in combat/none/other, combat/none/self |
| event:ACTIONBAR_HIDEGRID | 1 |  | unspecified | 1 | 0 | 1 |  | ooc/none/none |  |
| event:ACTIONBAR_SHOWGRID | 1 |  | unspecified | 1 | 0 | 1 |  | ooc/none/none |  |
| event:ACTIONBAR_SLOT_CHANGED | 1 | slot | unspecified | 12 | 0 | 12 |  | combat/none/none, ooc/none/none |  |
| event:ACTIONBAR_UPDATE_COOLDOWN | 1 |  | unspecified | 49 | 0 | 49 |  | combat/none/none, ooc/none/none |  |
| event:ACTIONBAR_UPDATE_STATE | 1 |  | unspecified | 47 | 0 | 47 |  | combat/none/none, ooc/none/none |  |
| event:ACTIONBAR_UPDATE_USABLE | 1 |  | unspecified | 18 | 0 | 18 |  | combat/none/none, ooc/none/none |  |
| event:ACTION_RANGE_CHECK_UPDATE | 1 | slot | unspecified | 321 | 0 | 321 |  | combat/none/none, ooc/none/none |  |
| event:ACTION_RANGE_CHECK_UPDATE | 2 | isInRange | unspecified | 321 | 0 | 321 |  | combat/none/none, ooc/none/none |  |
| event:ACTION_RANGE_CHECK_UPDATE | 3 | checksRange | unspecified | 321 | 0 | 321 |  | combat/none/none, ooc/none/none |  |
| event:ACTION_USABLE_CHANGED | 1 | changes | unspecified | 18 | 0 | 18 |  | combat/none/none, ooc/none/none |  |
| event:ADDON_LOADED | 1 | addOnName | unspecified | 4 | 0 | 4 |  | ooc/none/none |  |
| event:ADDON_LOADED | 2 | containsBindings | unspecified | 4 | 0 | 4 |  | ooc/none/none |  |
| event:ADDON_RESTRICTION_STATE_CHANGED | 1 | type | unspecified | 18 | 0 | 18 |  | ooc/none/none |  |
| event:ADDON_RESTRICTION_STATE_CHANGED | 2 | state | unspecified | 18 | 0 | 18 |  | ooc/none/none |  |
| event:ARENA_COOLDOWNS_UPDATE | 1 |  | unspecified | 1 | 0 | 1 |  | combat/none/none |  |
| event:BAG_UPDATE | 1 | bagID | unspecified | 4 | 0 | 4 |  | combat/none/none, ooc/none/none |  |
| event:BAG_UPDATE_COOLDOWN | 1 |  | unspecified | 24 | 0 | 24 |  | combat/none/none, ooc/none/none |  |
| event:BAG_UPDATE_DELAYED | 1 |  | unspecified | 2 | 0 | 2 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_LOGGING_CHANGED | 1 | whichLog | unspecified | 2 | 0 | 2 |  | ooc/none/none |  |
| event:CHAT_LOGGING_CHANGED | 2 | isEnabled | unspecified | 2 | 0 | 2 |  | ooc/none/none |  |
| event:CHAT_MSG_CHANNEL | 1 | text | conditional | 15 | 0 | 15 |  | combat/none/none, ooc/none/none | clear so far (condition not triggered in: combat/none/none, ooc/none/none) |
| event:CHAT_MSG_CHANNEL | 2 | playerName | conditional | 15 | 0 | 15 |  | combat/none/none, ooc/none/none | clear so far (condition not triggered in: combat/none/none, ooc/none/none) |
| event:CHAT_MSG_CHANNEL | 3 | languageName | never | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_CHANNEL | 4 | channelName | never | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_CHANNEL | 5 | playerName2 | conditional | 15 | 0 | 15 |  | combat/none/none, ooc/none/none | clear so far (condition not triggered in: combat/none/none, ooc/none/none) |
| event:CHAT_MSG_CHANNEL | 6 | specialFlags | never | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_CHANNEL | 7 | zoneChannelID | never | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_CHANNEL | 8 | channelIndex | never | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_CHANNEL | 9 | channelBaseName | never | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_CHANNEL | 10 | languageID | never | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_CHANNEL | 11 | lineID | never | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_CHANNEL | 12 | guid | conditional | 15 | 0 | 15 |  | combat/none/none, ooc/none/none | clear so far (condition not triggered in: combat/none/none, ooc/none/none) |
| event:CHAT_MSG_CHANNEL | 13 | bnSenderID | conditional | 15 | 0 | 15 |  | combat/none/none, ooc/none/none | clear so far (condition not triggered in: combat/none/none, ooc/none/none) |
| event:CHAT_MSG_CHANNEL | 14 | isMobile | never | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_CHANNEL | 15 | isSubtitle | never | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_CHANNEL | 16 | hideSenderInLetterbox | never | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_CHANNEL | 17 | suppressRaidIcons | never | 15 | 0 | 15 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_CHANNEL | 18 | discordInfo | conditional | 15 | 0 | 15 |  | combat/none/none, ooc/none/none | clear so far (condition not triggered in: combat/none/none, ooc/none/none) |
| event:CHAT_MSG_TRADESKILLS | 1 | text | conditional | 78 | 0 | 78 |  | combat/none/none, ooc/none/none | clear so far (condition not triggered in: combat/none/none, ooc/none/none) |
| event:CHAT_MSG_TRADESKILLS | 2 | playerName | conditional | 78 | 0 | 78 |  | combat/none/none, ooc/none/none | clear so far (condition not triggered in: combat/none/none, ooc/none/none) |
| event:CHAT_MSG_TRADESKILLS | 3 | languageName | never | 78 | 0 | 78 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_TRADESKILLS | 4 | channelName | never | 78 | 0 | 78 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_TRADESKILLS | 5 | playerName2 | conditional | 78 | 0 | 78 |  | combat/none/none, ooc/none/none | clear so far (condition not triggered in: combat/none/none, ooc/none/none) |
| event:CHAT_MSG_TRADESKILLS | 6 | specialFlags | never | 78 | 0 | 78 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_TRADESKILLS | 7 | zoneChannelID | never | 78 | 0 | 78 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_TRADESKILLS | 8 | channelIndex | never | 78 | 0 | 78 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_TRADESKILLS | 9 | channelBaseName | never | 78 | 0 | 78 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_TRADESKILLS | 10 | languageID | never | 78 | 0 | 78 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_TRADESKILLS | 11 | lineID | never | 78 | 0 | 78 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_TRADESKILLS | 12 | guid | conditional | 78 | 0 | 78 |  | combat/none/none, ooc/none/none | clear so far (condition not triggered in: combat/none/none, ooc/none/none) |
| event:CHAT_MSG_TRADESKILLS | 13 | bnSenderID | conditional | 78 | 0 | 78 |  | combat/none/none, ooc/none/none | clear so far (condition not triggered in: combat/none/none, ooc/none/none) |
| event:CHAT_MSG_TRADESKILLS | 14 | isMobile | never | 78 | 0 | 78 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_TRADESKILLS | 15 | isSubtitle | never | 78 | 0 | 78 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_TRADESKILLS | 16 | hideSenderInLetterbox | never | 78 | 0 | 78 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_TRADESKILLS | 17 | suppressRaidIcons | never | 78 | 0 | 78 |  | combat/none/none, ooc/none/none |  |
| event:CHAT_MSG_TRADESKILLS | 18 | discordInfo | conditional | 78 | 0 | 78 |  | combat/none/none, ooc/none/none | clear so far (condition not triggered in: combat/none/none, ooc/none/none) |
| event:CLICKBINDINGS_SET_HIGHLIGHTS_SHOWN | 1 | showHighlights | unspecified | 2 | 0 | 2 |  | ooc/none/none |  |
| event:COMBAT_RATING_UPDATE | 1 |  | unspecified | 6 | 0 | 6 |  | combat/none/none, ooc/none/none |  |
| event:CONSOLE_MESSAGE | 1 | message | unspecified | 480 | 0 | 480 |  | combat/none/none, ooc/none/none |  |
| event:CONSOLE_MESSAGE | 2 | colorType | unspecified | 480 | 0 | 480 |  | combat/none/none, ooc/none/none |  |
| event:CRITERIA_UPDATE | 1 |  | unspecified | 36 | 0 | 36 |  | combat/none/none, ooc/none/none |  |
| event:CURRENT_SPELL_CAST_CHANGED | 1 | cancelledCast | unspecified | 66 | 0 | 66 |  | combat/none/none, ooc/none/none |  |
| event:CURSOR_CHANGED | 1 | isDefault | unspecified | 78 | 0 | 78 |  | combat/none/none, ooc/none/none |  |
| event:CURSOR_CHANGED | 2 | newCursorType | unspecified | 78 | 0 | 78 |  | combat/none/none, ooc/none/none |  |
| event:CURSOR_CHANGED | 3 | oldCursorType | unspecified | 78 | 0 | 78 |  | combat/none/none, ooc/none/none |  |
| event:CURSOR_CHANGED | 4 | oldCursorVirtualID | unspecified | 78 | 0 | 78 |  | combat/none/none, ooc/none/none |  |
| event:CVAR_UPDATE | 1 | eventName | unspecified | 1 | 0 | 1 |  | ooc/none/none |  |
| event:CVAR_UPDATE | 2 | value | unspecified | 1 | 0 | 1 |  | ooc/none/none |  |
| event:DAMAGE_METER_COMBAT_SESSION_UPDATED | 1 | type | unspecified | 244 | 0 | 244 |  | combat/none/none, ooc/none/none |  |
| event:DAMAGE_METER_COMBAT_SESSION_UPDATED | 2 | sessionID | unspecified | 244 | 0 | 244 |  | combat/none/none, ooc/none/none |  |
| event:DAMAGE_METER_CURRENT_SESSION_UPDATED | 1 |  | unspecified | 5 | 0 | 5 |  | combat/none/none, ooc/none/none |  |
| event:ENCHANT_SPELL_COMPLETED | 1 | successful | unspecified | 2 | 0 | 2 |  | combat/none/none, ooc/none/none |  |
| event:ENCHANT_SPELL_COMPLETED | 2 | enchantedItem | unspecified | 2 | 0 | 2 |  | combat/none/none, ooc/none/none |  |
| event:GET_ITEM_INFO_RECEIVED | 1 | itemID | unspecified | 6 | 0 | 6 |  | ooc/none/none |  |
| event:GET_ITEM_INFO_RECEIVED | 2 | success | unspecified | 6 | 0 | 6 |  | ooc/none/none |  |
| event:GLOBAL_MOUSE_DOWN | 1 | button | unspecified | 124 | 0 | 124 |  | combat/none/none, ooc/none/none |  |
| event:GLOBAL_MOUSE_UP | 1 | button | unspecified | 124 | 0 | 124 |  | combat/none/none, ooc/none/none |  |
| event:GLOBAL_REGION_MOUSE_DOWN | 1 | region | unspecified | 121 | 0 | 121 |  | combat/none/none, ooc/none/none |  |
| event:GLOBAL_REGION_MOUSE_DOWN | 2 | button | unspecified | 121 | 0 | 121 |  | combat/none/none, ooc/none/none |  |
| event:GLOBAL_REGION_MOUSE_UP | 1 | region | unspecified | 124 | 0 | 124 |  | combat/none/none, ooc/none/none |  |
| event:GLOBAL_REGION_MOUSE_UP | 2 | button | unspecified | 124 | 0 | 124 |  | combat/none/none, ooc/none/none |  |
| event:ITEM_DATA_LOAD_RESULT | 1 | itemID | unspecified | 1 | 0 | 1 |  | ooc/none/none |  |
| event:ITEM_DATA_LOAD_RESULT | 2 | success | unspecified | 1 | 0 | 1 |  | ooc/none/none |  |
| event:MODIFIER_STATE_CHANGED | 1 | key | unspecified | 8 | 0 | 8 |  | combat/none/none |  |
| event:MODIFIER_STATE_CHANGED | 2 | down | unspecified | 8 | 0 | 8 |  | combat/none/none |  |
| event:NAME_PLATE_CREATED | 1 | namePlateFrame | unspecified | 3 | 0 | 3 |  | combat/none/none, ooc/none/none |  |
| event:NAME_PLATE_UNIT_ADDED | 1 | unitToken | unspecified | 35 | 0 | 35 |  | combat/none/other, ooc/none/other |  |
| event:NAME_PLATE_UNIT_REMOVED | 1 | unitToken | unspecified | 36 | 0 | 36 |  | combat/none/other, ooc/none/other |  |
| event:PARTY_KILL | 1 | attackerGUID | conditional | 9 | 0 | 9 |  | combat/none/none, ooc/none/none | clear so far (condition not triggered in: combat/none/none, ooc/none/none) |
| event:PARTY_KILL | 2 | targetGUID | conditional | 9 | 0 | 9 |  | combat/none/none, ooc/none/none | clear so far (condition not triggered in: combat/none/none, ooc/none/none) |
| event:PET_BAR_UPDATE_USABLE | 1 |  | unspecified | 9 | 0 | 9 |  | combat/none/none, ooc/none/none |  |
| event:PLAYER_DAMAGE_DONE_MODS | 1 | unitTarget | unspecified | 3 | 0 | 3 |  | ooc/none/other, ooc/none/self |  |
| event:PLAYER_ENTER_COMBAT | 1 |  | unspecified | 8 | 0 | 8 |  | combat/none/none, ooc/none/none |  |
| event:PLAYER_IN_COMBAT_CHANGED | 1 | inCombat | unspecified | 18 | 0 | 18 |  | ooc/none/none |  |
| event:PLAYER_LEAVE_COMBAT | 1 |  | unspecified | 8 | 0 | 8 |  | combat/none/none, ooc/none/none |  |
| event:PLAYER_REGEN_DISABLED | 1 |  | unspecified | 9 | 0 | 9 |  | ooc/none/none |  |
| event:PLAYER_REGEN_ENABLED | 1 |  | unspecified | 9 | 0 | 9 |  | ooc/none/none |  |
| event:PLAYER_SOFT_ENEMY_CHANGED | 1 |  | unspecified | 13 | 0 | 13 |  | combat/none/none, ooc/none/none |  |
| event:PLAYER_STARTED_LOOKING | 1 |  | unspecified | 8 | 0 | 8 |  | combat/none/none, ooc/none/none |  |
| event:PLAYER_STARTED_MOVING | 1 |  | unspecified | 25 | 0 | 25 |  | combat/none/none, ooc/none/none |  |
| event:PLAYER_STARTED_TURNING | 1 |  | unspecified | 29 | 0 | 29 |  | combat/none/none, ooc/none/none |  |
| event:PLAYER_STOPPED_LOOKING | 1 |  | unspecified | 8 | 0 | 8 |  | combat/none/none, ooc/none/none |  |
| event:PLAYER_STOPPED_MOVING | 1 |  | unspecified | 25 | 0 | 25 |  | combat/none/none, ooc/none/none |  |
| event:PLAYER_STOPPED_TURNING | 1 |  | unspecified | 29 | 0 | 29 |  | combat/none/none, ooc/none/none |  |
| event:PLAYER_SWING | 1 | swingDuration | unspecified | 11 | 0 | 11 |  | combat/none/none, ooc/none/none |  |
| event:PLAYER_SWING | 2 | swingType | unspecified | 11 | 0 | 11 |  | combat/none/none, ooc/none/none |  |
| event:PLAYER_TARGET_CHANGED | 1 |  | unspecified | 31 | 0 | 31 |  | combat/none/none, ooc/none/none |  |
| event:PLAYER_TARGET_DIED | 1 |  | unspecified | 9 | 0 | 9 |  | combat/none/none, ooc/none/none |  |
| event:PLAYER_TOTEM_UPDATE | 1 | totemSlot | unspecified | 4 | 0 | 4 |  | combat/none/none, ooc/none/none |  |
| event:PORTRAITS_UPDATED | 1 |  | unspecified | 2 | 0 | 2 |  | ooc/none/none |  |
| event:QUEST_LOG_UPDATE | 1 |  | unspecified | 3 | 0 | 3 |  | combat/none/none, ooc/none/none |  |
| event:SPELL_ACTIVATION_OVERLAY_HIDE | 1 | spellID | unspecified | 241 | 0 | 241 |  | combat/none/none, ooc/none/none |  |
| event:SPELL_DATA_LOAD_RESULT | 1 | spellID | unspecified | 7 | 0 | 7 |  | ooc/none/none |  |
| event:SPELL_DATA_LOAD_RESULT | 2 | success | unspecified | 7 | 0 | 7 |  | ooc/none/none |  |
| event:SPELL_POWER_CHANGED | 1 |  | unspecified | 2 | 0 | 2 |  | ooc/none/none |  |
| event:SPELL_TEXT_UPDATE | 1 | spellID | unspecified | 102 | 0 | 102 |  | ooc/none/none |  |
| event:SPELL_UPDATE_COOLDOWN | 1 | spellID | unspecified | 54 | 0 | 54 |  | combat/none/none, ooc/none/none |  |
| event:SPELL_UPDATE_COOLDOWN | 2 | baseSpellID | unspecified | 54 | 0 | 54 |  | combat/none/none, ooc/none/none |  |
| event:SPELL_UPDATE_COOLDOWN | 3 | category | unspecified | 54 | 0 | 54 |  | combat/none/none, ooc/none/none |  |
| event:SPELL_UPDATE_COOLDOWN | 4 | startRecoveryCategory | unspecified | 54 | 0 | 54 |  | combat/none/none, ooc/none/none |  |
| event:SPELL_UPDATE_COOLDOWN | 5 | itemID | unspecified | 54 | 0 | 54 |  | combat/none/none, ooc/none/none |  |
| event:SPELL_UPDATE_USABLE | 1 |  | unspecified | 929 | 0 | 929 |  | combat/none/none, ooc/none/none |  |
| event:TOOLTIP_DATA_UPDATE | 1 | dataInstanceID | unspecified | 23 | 0 | 23 |  | combat/none/none, ooc/none/none |  |
| event:TRADE_SKILL_CLOSE | 1 |  | unspecified | 2 | 0 | 2 |  | ooc/none/none |  |
| event:TRADE_SKILL_ITEM_CRAFTED_RESULT | 1 | data | unspecified | 2 | 0 | 2 |  | combat/none/none, ooc/none/none |  |
| event:UI_ERROR_MESSAGE | 1 | errorType | unspecified | 4 | 0 | 4 |  | combat/none/none, ooc/none/none |  |
| event:UI_ERROR_MESSAGE | 2 | message | unspecified | 4 | 0 | 4 |  | combat/none/none, ooc/none/none |  |
| event:UNIT_ATTACK_POWER | 1 | unitTarget | unspecified | 2 | 0 | 2 |  | ooc/none/self |  |
| event:UNIT_ATTACK_SPEED | 1 | unitTarget | unspecified | 12 | 0 | 12 |  | combat/none/self, ooc/none/self |  |
| event:UNIT_AURA | 1 | unitTarget | conditional | 43 | 0 | 43 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| event:UNIT_AURA | 2 | updateInfo | conditional | 43 | 0 | 43 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self | clear so far (condition not triggered in: combat/none/other, combat/none/self, ooc/none/other, ooc/none/self) |
| event:UNIT_COMBAT | 1 | unitTarget | unspecified | 153 | 0 | 153 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self |  |
| event:UNIT_COMBAT | 2 | event | unspecified | 153 | 0 | 153 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self |  |
| event:UNIT_COMBAT | 3 | flagText | unspecified | 153 | 0 | 153 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self |  |
| event:UNIT_COMBAT | 4 | amount | unspecified | 153 | 0 | 153 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self |  |
| event:UNIT_COMBAT | 5 | schoolMask | unspecified | 153 | 0 | 153 |  | combat/none/other, combat/none/self, ooc/none/other, ooc/none/self |  |
| ... 73 more in verify.json | | | | | | | | | |

## UNOBSERVED documented-secret/never positions (1321; all UNOBSERVED rows in verify.json)

api:C_ActionBar.GetActionCharges#1, api:C_ActionBar.GetActionCooldown#1, api:C_ActionBar.GetActionDisplayCount#1, api:C_ActionBar.GetActionLossOfControlCooldownInfo#1, api:C_ActionBar.GetActionUseCount#1, api:C_Calendar.EventGetInvite#1, api:C_Calendar.EventGetInviteResponseTime#1, api:C_Calendar.GetClubCalendarEvents#1, api:C_Calendar.GetDayEvent#1, api:C_ChatInfo.GetChatLineSenderGUID#1, api:C_ChatInfo.GetChatLineSenderName#1, api:C_ChatInfo.GetChatLineText#1, api:C_Club.GetClubInfo#1, api:C_Club.GetClubMembers#1, api:C_Club.GetInfoFromLastCommunityChatLine#1, api:C_Club.GetInfoFromLastCommunityChatLine#2, api:C_Club.GetInfoFromLastCommunityChatLine#3, api:C_Club.GetInfoFromLastCommunityChatLine#4, api:C_Club.GetMemberInfo#1, api:C_Club.GetMessageInfo#1, api:C_Club.GetMessageRanges#1, api:C_Club.GetMessagesBefore#1, api:C_Club.GetMessagesInRange#1, api:C_Club.GetStreamInfo#1, api:C_Club.GetStreams#1, api:C_Club.GetSubscribedClubs#1, api:C_Club.IsBeginningOfStream#1, api:C_Club.RequestMoreMessagesBefore#1, api:C_CombatAudioAlert.AddToKnownTargetingList#1, api:C_CombatAudioAlert.RemoveFromKnownTargetingList#1, api:C_DamageMeter.GetCombatSessionFromID#1, api:C_DamageMeter.GetCombatSessionSourceFromID#1, api:C_DamageMeter.GetCombatSessionSourceFromType#1, api:C_EncounterTimeline.GetEventColor#1, api:C_EncounterTimeline.GetEventInfo#1, api:C_LFGList.GetApplicantInfo#1, api:C_LFGList.GetSearchResultInfo#1, api:C_LFGList.GetSearchResultLeaderInfo#1, api:C_LFGList.GetSearchResultPlayerInfo#1, api:C_LossOfControl.GetActiveLossOfControlDataByUnit#1, api:C_PvP.GetArenaCrowdControlInfo#2, api:C_PvP.GetArenaCrowdControlInfo#3, api:C_PvP.GetArenaOpponentSpec#1, api:C_PvP.GetArenaOpponentSpec#2, api:C_PvP.GetScoreInfo#1, api:C_PvP.GetScoreInfoByPlayerGuid#1, api:C_ScenarioInfo.GetUnitCriteriaProgressValues#2, api:C_ScenarioInfo.GetUnitCriteriaProgressValues#3, api:C_Spell.GetLastCategoryCooldownSource#1, api:C_Spell.GetLastCategoryCooldownSource#2, api:C_Spell.GetSpellDisplayCount#1, api:C_Spell.GetSpellLossOfControlCooldownInfo#1, api:C_Spell.GetSpellMaxCumulativeAuraApplications#1, api:C_Spell.IsActiveSpell#1, api:C_SpellBook.GetSpellBookItemCastCount#1, api:C_SpellBook.GetSpellBookItemCharges#1, api:C_SpellBook.GetSpellBookItemCooldown#1, api:C_SpellBook.GetSpellBookItemLossOfControlCooldownInfo#1, api:C_SpellDiminish.ShouldTrackSpellDiminishCategory#1, api:C_TooltipInfo.GetUnitAura#1, api:C_TooltipInfo.GetUnitAuraByAuraInstanceID#1, api:C_TooltipInfo.GetUnitBuff#1, api:C_TooltipInfo.GetUnitBuffByAuraInstanceID#1, api:C_TooltipInfo.GetUnitDebuff#1, api:C_TooltipInfo.GetUnitDebuffByAuraInstanceID#1, api:C_UnitAuras.DoesAuraHaveExpirationTime#1, api:C_UnitAuras.GetAuraApplicationDisplayCount#1, api:C_UnitAuras.GetAuraBaseDuration#1, api:C_UnitAuras.GetAuraCasterGUID#1, api:C_UnitAuras.GetAuraDataByAuraInstanceID#1, api:C_UnitAuras.GetAuraDataByIndex#1, api:C_UnitAuras.GetAuraDataBySlot#1, api:C_UnitAuras.GetAuraDataBySpellName#1, api:C_UnitAuras.GetAuraDispelTypeColor#1, api:C_UnitAuras.GetBuffDataByIndex#1, api:C_UnitAuras.GetDebuffDataByIndex#1, api:C_UnitAuras.GetPlayerAuraBySpellID#1, api:C_UnitAuras.GetRefreshCarryOverDuration#1, api:C_UnitAuras.GetRefreshExtendedDuration#1, api:C_UnitAuras.GetUnitAuraBySpellID#1, api:C_UnitAuras.GetUnitAuras#1, api:C_VoiceChat.GetChannel#1, api:C_VoiceChat.GetChannelForChannelType#1, api:C_VoiceChat.GetChannelForCommunityStream#1, api:C_VoiceChat.GetMemberGUID#1, api:C_VoiceChat.GetMemberID#1, api:C_VoiceChat.GetMemberInfo#1, api:C_VoiceChat.GetMemberName#1, api:C_VoiceChat.IsMemberMutedForAll#1, api:C_VoiceChat.IsMemberSilenced#1, api:ClosestGameObjectPosition#1, api:ClosestGameObjectPosition#2, api:ClosestGameObjectPosition#3, api:ClosestUnitPosition#1, api:ClosestUnitPosition#2, api:ClosestUnitPosition#3, api:GetAttackPowerForStat#1, api:GetCombatRating#1, api:GetCombatRatingBonus#1, api:GetComboPoints#1, api:GetCritChanceFromStat#1, api:GetNextAvailableRaidTargetMarkerIndex#1, api:GetPowerRegenForPowerType#1, api:GetPowerRegenForPowerType#2, api:GetRangedAttackPowerForStat#1, api:GetSpellBonusDamage#1, api:GetSpellCritChanceFromStat#1, api:GetTotemInfo#1, api:GetTotemInfo#2, api:GetTotemInfo#3, api:GetTotemInfo#4, api:GetTotemInfo#5, api:GetTotemInfo#6, api:GetTotemInfo#7, api:GetTotemTimeLeft#1, api:GetUnitEmpowerStageDuration#1, api:GetVersatilityBonus#1, api:IsRaidMarkerActive#1, api:UnitCastingInfo#2, api:UnitCastingInfo#3, api:UnitCastingInfo#4, api:UnitCastingInfo#5, api:UnitCastingInfo#6, api:UnitCastingInfo#7, api:UnitCastingInfo#8, api:UnitCastingInfo#9, api:UnitCastingInfo#10, api:UnitCastingInfo#11, api:UnitChannelInfo#2, api:UnitChannelInfo#3, api:UnitChannelInfo#4, api:UnitChannelInfo#5, api:UnitChannelInfo#6, api:UnitChannelInfo#7, api:UnitChannelInfo#8, api:UnitChannelInfo#9, api:UnitChannelInfo#10, api:UnitChannelInfo#11, api:UnitClassFromGUID#1, api:UnitCreatureID#1, api:UnitIsOwnerOrControllerOfUnit#1, api:UnitNameFromGUID#1, api:UnitNameFromGUID#2, api:UnitPercentHealthFromGUID#1, api:UnitPowerBarTimerInfo#2, api:UnitPowerBarTimerInfo#3, api:UnitPowerBarTimerInfo#4, api:UnitResistance#1, api:UnitResistance#2, api:UnitResistance#3, api:UnitResistance#4, api:UnitStat#1, api:UnitStat#2, api:UnitStat#3, api:UnitStat#4, api:UnitThreatLeadSituation#1, api:UnitThreatPercentageOfLead#1, api:UnitTokenFromGUID#1, api:table.count#1, api:table.getcountinfo#1, api:table.getcountinfo#2, api:table.getcountinfo#3, api:table.isempty#1, event:ARENA_CROWD_CONTROL_SPELL_UPDATE#1, event:ARENA_CROWD_CONTROL_SPELL_UPDATE#2, event:CANCEL_PLAYER_COUNTDOWN#1, event:CANCEL_PLAYER_COUNTDOWN#2, event:CANCEL_PLAYER_COUNTDOWN#3, event:CHAT_COMBAT_MSG_ARENA_POINTS_GAIN#3, event:CHAT_COMBAT_MSG_ARENA_POINTS_GAIN#4, event:CHAT_COMBAT_MSG_ARENA_POINTS_GAIN#6, event:CHAT_COMBAT_MSG_ARENA_POINTS_GAIN#7, event:CHAT_COMBAT_MSG_ARENA_POINTS_GAIN#8, event:CHAT_COMBAT_MSG_ARENA_POINTS_GAIN#9, event:CHAT_COMBAT_MSG_ARENA_POINTS_GAIN#10, event:CHAT_COMBAT_MSG_ARENA_POINTS_GAIN#11, event:CHAT_COMBAT_MSG_ARENA_POINTS_GAIN#14, event:CHAT_COMBAT_MSG_ARENA_POINTS_GAIN#15, event:CHAT_COMBAT_MSG_ARENA_POINTS_GAIN#16, event:CHAT_COMBAT_MSG_ARENA_POINTS_GAIN#17, event:CHAT_MSG_ACHIEVEMENT#3, event:CHAT_MSG_ACHIEVEMENT#4, event:CHAT_MSG_ACHIEVEMENT#6, event:CHAT_MSG_ACHIEVEMENT#7, event:CHAT_MSG_ACHIEVEMENT#8, event:CHAT_MSG_ACHIEVEMENT#9, event:CHAT_MSG_ACHIEVEMENT#10, event:CHAT_MSG_ACHIEVEMENT#11, event:CHAT_MSG_ACHIEVEMENT#14, event:CHAT_MSG_ACHIEVEMENT#15, event:CHAT_MSG_ACHIEVEMENT#16, event:CHAT_MSG_ACHIEVEMENT#17, event:CHAT_MSG_AFK#1, event:CHAT_MSG_AFK#2, event:CHAT_MSG_AFK#3, event:CHAT_MSG_AFK#4, event:CHAT_MSG_AFK#5, event:CHAT_MSG_AFK#6, event:CHAT_MSG_AFK#7, event:CHAT_MSG_AFK#8, event:CHAT_MSG_AFK#9, event:CHAT_MSG_AFK#10, event:CHAT_MSG_AFK#11, event:CHAT_MSG_AFK#12, event:CHAT_MSG_AFK#13, event:CHAT_MSG_AFK#14, event:CHAT_MSG_AFK#15, event:CHAT_MSG_AFK#16, event:CHAT_MSG_AFK#17, event:CHAT_MSG_AFK#18, event:CHAT_MSG_BG_SYSTEM_ALLIANCE#3, event:CHAT_MSG_BG_SYSTEM_ALLIANCE#4, event:CHAT_MSG_BG_SYSTEM_ALLIANCE#6, event:CHAT_MSG_BG_SYSTEM_ALLIANCE#7, event:CHAT_MSG_BG_SYSTEM_ALLIANCE#8, event:CHAT_MSG_BG_SYSTEM_ALLIANCE#9, event:CHAT_MSG_BG_SYSTEM_ALLIANCE#10, event:CHAT_MSG_BG_SYSTEM_ALLIANCE#11, event:CHAT_MSG_BG_SYSTEM_ALLIANCE#14, event:CHAT_MSG_BG_SYSTEM_ALLIANCE#15, event:CHAT_MSG_BG_SYSTEM_ALLIANCE#16, event:CHAT_MSG_BG_SYSTEM_ALLIANCE#17, event:CHAT_MSG_BG_SYSTEM_HORDE#3, event:CHAT_MSG_BG_SYSTEM_HORDE#4, event:CHAT_MSG_BG_SYSTEM_HORDE#6, event:CHAT_MSG_BG_SYSTEM_HORDE#7, event:CHAT_MSG_BG_SYSTEM_HORDE#8, event:CHAT_MSG_BG_SYSTEM_HORDE#9, event:CHAT_MSG_BG_SYSTEM_HORDE#10, event:CHAT_MSG_BG_SYSTEM_HORDE#11, event:CHAT_MSG_BG_SYSTEM_HORDE#14, event:CHAT_MSG_BG_SYSTEM_HORDE#15, event:CHAT_MSG_BG_SYSTEM_HORDE#16, event:CHAT_MSG_BG_SYSTEM_HORDE#17, event:CHAT_MSG_BG_SYSTEM_NEUTRAL#3, event:CHAT_MSG_BG_SYSTEM_NEUTRAL#4, event:CHAT_MSG_BG_SYSTEM_NEUTRAL#6, event:CHAT_MSG_BG_SYSTEM_NEUTRAL#7, event:CHAT_MSG_BG_SYSTEM_NEUTRAL#8, event:CHAT_MSG_BG_SYSTEM_NEUTRAL#9, event:CHAT_MSG_BG_SYSTEM_NEUTRAL#10, event:CHAT_MSG_BG_SYSTEM_NEUTRAL#11, event:CHAT_MSG_BG_SYSTEM_NEUTRAL#14, event:CHAT_MSG_BG_SYSTEM_NEUTRAL#15, event:CHAT_MSG_BG_SYSTEM_NEUTRAL#16, event:CHAT_MSG_BG_SYSTEM_NEUTRAL#17, event:CHAT_MSG_BN#1, event:CHAT_MSG_BN#2, event:CHAT_MSG_BN#3, event:CHAT_MSG_BN#4, event:CHAT_MSG_BN#5, event:CHAT_MSG_BN#6, event:CHAT_MSG_BN#7, event:CHAT_MSG_BN#8, event:CHAT_MSG_BN#9, event:CHAT_MSG_BN#10, event:CHAT_MSG_BN#11, event:CHAT_MSG_BN#12, event:CHAT_MSG_BN#13, event:CHAT_MSG_BN#14, event:CHAT_MSG_BN#15, event:CHAT_MSG_BN#16, event:CHAT_MSG_BN#17, event:CHAT_MSG_BN#18, event:CHAT_MSG_BN_INLINE_TOAST_ALERT#1, event:CHAT_MSG_BN_INLINE_TOAST_ALERT#2, event:CHAT_MSG_BN_INLINE_TOAST_ALERT#3, event:CHAT_MSG_BN_INLINE_TOAST_ALERT#4, event:CHAT_MSG_BN_INLINE_TOAST_ALERT#5, event:CHAT_MSG_BN_INLINE_TOAST_ALERT#6, event:CHAT_MSG_BN_INLINE_TOAST_ALERT#7, event:CHAT_MSG_BN_INLINE_TOAST_ALERT#8, event:CHAT_MSG_BN_INLINE_TOAST_ALERT#9, event:CHAT_MSG_BN_INLINE_TOAST_ALERT#10, event:CHAT_MSG_BN_INLINE_TOAST_ALERT#11, event:CHAT_MSG_BN_INLINE_TOAST_ALERT#12, event:CHAT_MSG_BN_INLINE_TOAST_ALERT#13, event:CHAT_MSG_BN_INLINE_TOAST_ALERT#14, event:CHAT_MSG_BN_INLINE_TOAST_ALERT#15, event:CHAT_MSG_BN_INLINE_TOAST_ALERT#16, event:CHAT_MSG_BN_INLINE_TOAST_ALERT#17, event:CHAT_MSG_BN_INLINE_TOAST_ALERT#18, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST#1, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST#2, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST#3, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST#4, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST#5, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST#6, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST#7, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST#8, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST#9, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST#10, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST#11, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST#12, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST#13, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST#14, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST#15, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST#16, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST#17, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST#18, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM#1, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM#2, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM#3, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM#4, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM#5, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM#6, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM#7, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM#8, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM#9, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM#10, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM#11, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM#12, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM#13, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM#14, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM#15, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM#16, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM#17, event:CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM#18, event:CHAT_MSG_BN_INLINE_TOAST_CONVERSATION#1, event:CHAT_MSG_BN_INLINE_TOAST_CONVERSATION#2, event:CHAT_MSG_BN_INLINE_TOAST_CONVERSATION#3, event:CHAT_MSG_BN_INLINE_TOAST_CONVERSATION#4, event:CHAT_MSG_BN_INLINE_TOAST_CONVERSATION#5, event:CHAT_MSG_BN_INLINE_TOAST_CONVERSATION#6, event:CHAT_MSG_BN_INLINE_TOAST_CONVERSATION#7, event:CHAT_MSG_BN_INLINE_TOAST_CONVERSATION#8, event:CHAT_MSG_BN_INLINE_TOAST_CONVERSATION#9, event:CHAT_MSG_BN_INLINE_TOAST_CONVERSATION#10, event:CHAT_MSG_BN_INLINE_TOAST_CONVERSATION#11, event:CHAT_MSG_BN_INLINE_TOAST_CONVERSATION#12, event:CHAT_MSG_BN_INLINE_TOAST_CONVERSATION#13, event:CHAT_MSG_BN_INLINE_TOAST_CONVERSATION#14, event:CHAT_MSG_BN_INLINE_TOAST_CONVERSATION#15, event:CHAT_MSG_BN_INLINE_TOAST_CONVERSATION#16, event:CHAT_MSG_BN_INLINE_TOAST_CONVERSATION#17, event:CHAT_MSG_BN_INLINE_TOAST_CONVERSATION#18, event:CHAT_MSG_BN_WHISPER#1, event:CHAT_MSG_BN_WHISPER#2, event:CHAT_MSG_BN_WHISPER#3, event:CHAT_MSG_BN_WHISPER#4, event:CHAT_MSG_BN_WHISPER#5, event:CHAT_MSG_BN_WHISPER#6, event:CHAT_MSG_BN_WHISPER#7, event:CHAT_MSG_BN_WHISPER#8, event:CHAT_MSG_BN_WHISPER#9, event:CHAT_MSG_BN_WHISPER#10, event:CHAT_MSG_BN_WHISPER#11, event:CHAT_MSG_BN_WHISPER#12, event:CHAT_MSG_BN_WHISPER#13, event:CHAT_MSG_BN_WHISPER#14, event:CHAT_MSG_BN_WHISPER#15, event:CHAT_MSG_BN_WHISPER#16, event:CHAT_MSG_BN_WHISPER#17, event:CHAT_MSG_BN_WHISPER#18, event:CHAT_MSG_BN_WHISPER_INFORM#1, event:CHAT_MSG_BN_WHISPER_INFORM#2, event:CHAT_MSG_BN_WHISPER_INFORM#3, event:CHAT_MSG_BN_WHISPER_INFORM#4, event:CHAT_MSG_BN_WHISPER_INFORM#5, event:CHAT_MSG_BN_WHISPER_INFORM#6, event:CHAT_MSG_BN_WHISPER_INFORM#7, event:CHAT_MSG_BN_WHISPER_INFORM#8, event:CHAT_MSG_BN_WHISPER_INFORM#9, event:CHAT_MSG_BN_WHISPER_INFORM#10, event:CHAT_MSG_BN_WHISPER_INFORM#11, event:CHAT_MSG_BN_WHISPER_INFORM#12, event:CHAT_MSG_BN_WHISPER_INFORM#13, event:CHAT_MSG_BN_WHISPER_INFORM#14, event:CHAT_MSG_BN_WHISPER_INFORM#15, event:CHAT_MSG_BN_WHISPER_INFORM#16, event:CHAT_MSG_BN_WHISPER_INFORM#17, event:CHAT_MSG_BN_WHISPER_INFORM#18, event:CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE#1, event:CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE#2, event:CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE#3, event:CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE#4, event:CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE#5, event:CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE#6, event:CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE#7, event:CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE#8, event:CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE#9, event:CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE#10, event:CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE#11, event:CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE#12, event:CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE#13, event:CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE#14, event:CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE#15, event:CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE#16, event:CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE#17, event:CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE#18, event:CHAT_MSG_CHANNEL_JOIN#1, event:CHAT_MSG_CHANNEL_JOIN#2, event:CHAT_MSG_CHANNEL_JOIN#3, event:CHAT_MSG_CHANNEL_JOIN#4, event:CHAT_MSG_CHANNEL_JOIN#5, event:CHAT_MSG_CHANNEL_JOIN#6, event:CHAT_MSG_CHANNEL_JOIN#7, event:CHAT_MSG_CHANNEL_JOIN#8, event:CHAT_MSG_CHANNEL_JOIN#9, event:CHAT_MSG_CHANNEL_JOIN#10, event:CHAT_MSG_CHANNEL_JOIN#11, event:CHAT_MSG_CHANNEL_JOIN#12, event:CHAT_MSG_CHANNEL_JOIN#13, event:CHAT_MSG_CHANNEL_JOIN#14, event:CHAT_MSG_CHANNEL_JOIN#15, event:CHAT_MSG_CHANNEL_JOIN#16, event:CHAT_MSG_CHANNEL_JOIN#17, event:CHAT_MSG_CHANNEL_JOIN#18, event:CHAT_MSG_CHANNEL_LEAVE#1, event:CHAT_MSG_CHANNEL_LEAVE#2, event:CHAT_MSG_CHANNEL_LEAVE#3, event:CHAT_MSG_CHANNEL_LEAVE#4, event:CHAT_MSG_CHANNEL_LEAVE#5, event:CHAT_MSG_CHANNEL_LEAVE#6, event:CHAT_MSG_CHANNEL_LEAVE#7, event:CHAT_MSG_CHANNEL_LEAVE#8, event:CHAT_MSG_CHANNEL_LEAVE#9, event:CHAT_MSG_CHANNEL_LEAVE#10, event:CHAT_MSG_CHANNEL_LEAVE#11, event:CHAT_MSG_CHANNEL_LEAVE#12, event:CHAT_MSG_CHANNEL_LEAVE#13, event:CHAT_MSG_CHANNEL_LEAVE#14, event:CHAT_MSG_CHANNEL_LEAVE#15, event:CHAT_MSG_CHANNEL_LEAVE#16, event:CHAT_MSG_CHANNEL_LEAVE#17, event:CHAT_MSG_CHANNEL_LEAVE#18, event:CHAT_MSG_CHANNEL_LIST#1, event:CHAT_MSG_CHANNEL_LIST#2, event:CHAT_MSG_CHANNEL_LIST#3, event:CHAT_MSG_CHANNEL_LIST#4, event:CHAT_MSG_CHANNEL_LIST#5, event:CHAT_MSG_CHANNEL_LIST#6, event:CHAT_MSG_CHANNEL_LIST#7, event:CHAT_MSG_CHANNEL_LIST#8, event:CHAT_MSG_CHANNEL_LIST#9, event:CHAT_MSG_CHANNEL_LIST#10, event:CHAT_MSG_CHANNEL_LIST#11, event:CHAT_MSG_CHANNEL_LIST#12, event:CHAT_MSG_CHANNEL_LIST#13, event:CHAT_MSG_CHANNEL_LIST#14, event:CHAT_MSG_CHANNEL_LIST#15, event:CHAT_MSG_CHANNEL_LIST#16, event:CHAT_MSG_CHANNEL_LIST#17, event:CHAT_MSG_CHANNEL_LIST#18, event:CHAT_MSG_CHANNEL_NOTICE#1, event:CHAT_MSG_CHANNEL_NOTICE#2, event:CHAT_MSG_CHANNEL_NOTICE#3, event:CHAT_MSG_CHANNEL_NOTICE#4, event:CHAT_MSG_CHANNEL_NOTICE#5, event:CHAT_MSG_CHANNEL_NOTICE#6, event:CHAT_MSG_CHANNEL_NOTICE#7, event:CHAT_MSG_CHANNEL_NOTICE#8, event:CHAT_MSG_CHANNEL_NOTICE#9, event:CHAT_MSG_CHANNEL_NOTICE#10, event:CHAT_MSG_CHANNEL_NOTICE#11, event:CHAT_MSG_CHANNEL_NOTICE#12, event:CHAT_MSG_CHANNEL_NOTICE#13, event:CHAT_MSG_CHANNEL_NOTICE#14, event:CHAT_MSG_CHANNEL_NOTICE#15, event:CHAT_MSG_CHANNEL_NOTICE#16, event:CHAT_MSG_CHANNEL_NOTICE#17, event:CHAT_MSG_CHANNEL_NOTICE#18, event:CHAT_MSG_CHANNEL_NOTICE_USER#1, event:CHAT_MSG_CHANNEL_NOTICE_USER#2, event:CHAT_MSG_CHANNEL_NOTICE_USER#3, event:CHAT_MSG_CHANNEL_NOTICE_USER#4, event:CHAT_MSG_CHANNEL_NOTICE_USER#5, event:CHAT_MSG_CHANNEL_NOTICE_USER#6, event:CHAT_MSG_CHANNEL_NOTICE_USER#7, event:CHAT_MSG_CHANNEL_NOTICE_USER#8, event:CHAT_MSG_CHANNEL_NOTICE_USER#9, event:CHAT_MSG_CHANNEL_NOTICE_USER#10, event:CHAT_MSG_CHANNEL_NOTICE_USER#11, event:CHAT_MSG_CHANNEL_NOTICE_USER#12, event:CHAT_MSG_CHANNEL_NOTICE_USER#13, event:CHAT_MSG_CHANNEL_NOTICE_USER#14, event:CHAT_MSG_CHANNEL_NOTICE_USER#15, event:CHAT_MSG_CHANNEL_NOTICE_USER#16, event:CHAT_MSG_CHANNEL_NOTICE_USER#17, event:CHAT_MSG_CHANNEL_NOTICE_USER#18, event:CHAT_MSG_COLLECTED_APPEARANCE#3, event:CHAT_MSG_COLLECTED_APPEARANCE#4, event:CHAT_MSG_COLLECTED_APPEARANCE#6, event:CHAT_MSG_COLLECTED_APPEARANCE#7, event:CHAT_MSG_COLLECTED_APPEARANCE#8, event:CHAT_MSG_COLLECTED_APPEARANCE#9, event:CHAT_MSG_COLLECTED_APPEARANCE#10, event:CHAT_MSG_COLLECTED_APPEARANCE#11, event:CHAT_MSG_COLLECTED_APPEARANCE#14, event:CHAT_MSG_COLLECTED_APPEARANCE#15, event:CHAT_MSG_COLLECTED_APPEARANCE#16, event:CHAT_MSG_COLLECTED_APPEARANCE#17, event:CHAT_MSG_COMBAT_FACTION_CHANGE#3, event:CHAT_MSG_COMBAT_FACTION_CHANGE#4, event:CHAT_MSG_COMBAT_FACTION_CHANGE#6, event:CHAT_MSG_COMBAT_FACTION_CHANGE#7, event:CHAT_MSG_COMBAT_FACTION_CHANGE#8, event:CHAT_MSG_COMBAT_FACTION_CHANGE#9, event:CHAT_MSG_COMBAT_FACTION_CHANGE#10, event:CHAT_MSG_COMBAT_FACTION_CHANGE#11, event:CHAT_MSG_COMBAT_FACTION_CHANGE#14, event:CHAT_MSG_COMBAT_FACTION_CHANGE#15, event:CHAT_MSG_COMBAT_FACTION_CHANGE#16, event:CHAT_MSG_COMBAT_FACTION_CHANGE#17, event:CHAT_MSG_COMBAT_HONOR_GAIN#3, event:CHAT_MSG_COMBAT_HONOR_GAIN#4, event:CHAT_MSG_COMBAT_HONOR_GAIN#6, event:CHAT_MSG_COMBAT_HONOR_GAIN#7, event:CHAT_MSG_COMBAT_HONOR_GAIN#8, event:CHAT_MSG_COMBAT_HONOR_GAIN#9, event:CHAT_MSG_COMBAT_HONOR_GAIN#10, event:CHAT_MSG_COMBAT_HONOR_GAIN#11, event:CHAT_MSG_COMBAT_HONOR_GAIN#14, event:CHAT_MSG_COMBAT_HONOR_GAIN#15, event:CHAT_MSG_COMBAT_HONOR_GAIN#16, event:CHAT_MSG_COMBAT_HONOR_GAIN#17, event:CHAT_MSG_COMBAT_MISC_INFO#3, event:CHAT_MSG_COMBAT_MISC_INFO#4, event:CHAT_MSG_COMBAT_MISC_INFO#6, event:CHAT_MSG_COMBAT_MISC_INFO#7, event:CHAT_MSG_COMBAT_MISC_INFO#8, event:CHAT_MSG_COMBAT_MISC_INFO#9, event:CHAT_MSG_COMBAT_MISC_INFO#10, event:CHAT_MSG_COMBAT_MISC_INFO#11, event:CHAT_MSG_COMBAT_MISC_INFO#14, event:CHAT_MSG_COMBAT_MISC_INFO#15, event:CHAT_MSG_COMBAT_MISC_INFO#16, event:CHAT_MSG_COMBAT_MISC_INFO#17, event:CHAT_MSG_COMBAT_XP_GAIN#3, event:CHAT_MSG_COMBAT_XP_GAIN#4, event:CHAT_MSG_COMBAT_XP_GAIN#6, event:CHAT_MSG_COMBAT_XP_GAIN#7, event:CHAT_MSG_COMBAT_XP_GAIN#8, event:CHAT_MSG_COMBAT_XP_GAIN#9, event:CHAT_MSG_COMBAT_XP_GAIN#10, event:CHAT_MSG_COMBAT_XP_GAIN#11, event:CHAT_MSG_COMBAT_XP_GAIN#14, event:CHAT_MSG_COMBAT_XP_GAIN#15, event:CHAT_MSG_COMBAT_XP_GAIN#16, event:CHAT_MSG_COMBAT_XP_GAIN#17, event:CHAT_MSG_COMMUNITIES_CHANNEL#1, event:CHAT_MSG_COMMUNITIES_CHANNEL#2, event:CHAT_MSG_COMMUNITIES_CHANNEL#3, event:CHAT_MSG_COMMUNITIES_CHANNEL#4, event:CHAT_MSG_COMMUNITIES_CHANNEL#5, event:CHAT_MSG_COMMUNITIES_CHANNEL#6, event:CHAT_MSG_COMMUNITIES_CHANNEL#7, event:CHAT_MSG_COMMUNITIES_CHANNEL#8, event:CHAT_MSG_COMMUNITIES_CHANNEL#9, event:CHAT_MSG_COMMUNITIES_CHANNEL#10, event:CHAT_MSG_COMMUNITIES_CHANNEL#11, event:CHAT_MSG_COMMUNITIES_CHANNEL#12, event:CHAT_MSG_COMMUNITIES_CHANNEL#13, event:CHAT_MSG_COMMUNITIES_CHANNEL#14, event:CHAT_MSG_COMMUNITIES_CHANNEL#15, event:CHAT_MSG_COMMUNITIES_CHANNEL#16, event:CHAT_MSG_COMMUNITIES_CHANNEL#17, event:CHAT_MSG_COMMUNITIES_CHANNEL#18, event:CHAT_MSG_CURRENCY#3, event:CHAT_MSG_CURRENCY#4, event:CHAT_MSG_CURRENCY#6, event:CHAT_MSG_CURRENCY#7, event:CHAT_MSG_CURRENCY#8, event:CHAT_MSG_CURRENCY#9, event:CHAT_MSG_CURRENCY#10, event:CHAT_MSG_CURRENCY#11, event:CHAT_MSG_CURRENCY#14, event:CHAT_MSG_CURRENCY#15, event:CHAT_MSG_CURRENCY#16, event:CHAT_MSG_CURRENCY#17, event:CHAT_MSG_DND#1, event:CHAT_MSG_DND#2, event:CHAT_MSG_DND#3, event:CHAT_MSG_DND#4, event:CHAT_MSG_DND#5, event:CHAT_MSG_DND#6, event:CHAT_MSG_DND#7, event:CHAT_MSG_DND#8, event:CHAT_MSG_DND#9, event:CHAT_MSG_DND#10, event:CHAT_MSG_DND#11, event:CHAT_MSG_DND#12, event:CHAT_MSG_DND#13, event:CHAT_MSG_DND#14, event:CHAT_MSG_DND#15, event:CHAT_MSG_DND#16, event:CHAT_MSG_DND#17, event:CHAT_MSG_DND#18, event:CHAT_MSG_EMOTE#1, event:CHAT_MSG_EMOTE#2, event:CHAT_MSG_EMOTE#3, event:CHAT_MSG_EMOTE#4, event:CHAT_MSG_EMOTE#5, event:CHAT_MSG_EMOTE#6, event:CHAT_MSG_EMOTE#7, event:CHAT_MSG_EMOTE#8, event:CHAT_MSG_EMOTE#9, event:CHAT_MSG_EMOTE#10, event:CHAT_MSG_EMOTE#11, event:CHAT_MSG_EMOTE#12 ...

## Contradictions detected live in game (0)

none recorded
