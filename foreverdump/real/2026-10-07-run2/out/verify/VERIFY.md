# Forever secrets VERIFY report (v2.2)

Build 1.60.1.70245 (toc 16001). Ground truth: `api-secrecy-inventory-forever-70245.tsv` (5785 functions, 1804 events). Data: v2.1 SavedVariables.

Value states: absent / nil / secret / container / clear; only present values count. Conditional rows are only CONTRADICTED when the same-frame `C_Secrets.Should*BeSecret` disagreed (v2.2 data); NeverSecret fields secret are always CONTRADICTED.

## Summary

| status | count | before (v2.1 verifier) |
|---|---|---|
| CONTRADICTED | 0 | 7 |
| UNDOCUMENTED-SECRET | 0 | 5 |
| INCONCLUSIVE | 4 | - |
| CONFIRMED | 481 | 473 |
| UNOBSERVED | 10021 | 9282 |

Inventory vs the client's own docs (dump): 5114 agree, 0 disagree, 7 dump functions not in the inventory.

## Coverage

| scope | positions | observed | % |
|---|---|---|---|
| all | 10487 | 466 | 4.44 |
| expectedSecretOrNever | 1591 | 251 | 15.78 |
| alwaysSecret | 45 | 15 | 33.33 |
| conditional | 707 | 202 | 28.57 |
| structFields | 19 | 19 | 100.00 |

## CONTRADICTED (0)

none

## UNDOCUMENTED-SECRET (0)

none

## INCONCLUSIVE (4)

| key | pos | expected | tag | present | secret | clear | containers | nil | absent | note |
|---|---|---|---|---|---|---|---|---|---|---|
| api:C_CombatText.GetCurrentEventInfo | 1 | always |  | 14 | 0 | 14 | 0 | 0 | 0 | v2.1 counted nil/containers as clear; variadic/empty Returns (only valid inside its event); no secret sample |
| api:GetRaidTargetIndex | 1 | always |  | 19 | 0 | 19 | 0 | 0 | 0 | v2.1 counted nil/containers as clear; return is Nilable; no secret sample |
| api:UnitCastingDuration | 1 | always |  | 18 | 0 | 18 | 0 | 0 | 0 | v2.1 counted nil/containers as clear; MayReturnNothing; returns a container (LuaDurationObject): issecretvalue(obj) is false, needs obj:HasSecretValues(); no secret sample |
| api:UnitPowerBarTimerInfo | 1 | always |  | 20 | 0 | 20 | 0 | 0 | 0 | v2.1 counted nil/containers as clear; MayReturnNothing; no secret sample |

## CONFIRMED (481)

| key | pos | expected | tag | present | secret | clear | containers | nil | absent | note |
|---|---|---|---|---|---|---|---|---|---|---|
| api:C_ChatInfo.AreOutgoingAddonChatMessagesRestricted | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:C_Club.IsRestricted | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:C_CombatLog.IsCombatLogRestricted | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:C_Container.GetItemCooldown | 1 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_Container.GetItemCooldown | 2 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_Container.GetItemCooldown | 3 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_DamageMeter.GetCombatSessionFromType | 1 | conditional | SecretWhenInCombat | 110 | 0 | 110 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:C_Item.GetDetailedItemLevelInfo | 1 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_Item.GetDetailedItemLevelInfo | 2 | none |  | 15 | 0 | 15 | 0 | 0 | 0 |  |
| api:C_Item.GetDetailedItemLevelInfo | 3 | none |  | 15 | 0 | 15 | 0 | 0 | 0 |  |
| api:C_Item.GetItemCooldown | 1 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_Item.GetItemCooldown | 2 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_Item.GetItemCooldown | 3 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_Item.GetItemCount | 1 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_Item.GetItemIconByID | 1 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 1 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 2 | none |  | 15 | 0 | 15 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 3 | none |  | 15 | 0 | 15 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 4 | none |  | 15 | 0 | 15 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 5 | none |  | 15 | 0 | 15 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 6 | none |  | 15 | 0 | 15 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 7 | none |  | 15 | 0 | 15 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 8 | none |  | 15 | 0 | 15 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 9 | none |  | 15 | 0 | 15 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 10 | none |  | 15 | 0 | 15 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 11 | none |  | 15 | 0 | 15 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 12 | none |  | 15 | 0 | 15 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 13 | none |  | 15 | 0 | 15 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 14 | none |  | 15 | 0 | 15 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 15 | none |  | 15 | 0 | 15 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 16 | none |  | 15 | 0 | 15 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 17 | none |  | 15 | 0 | 15 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 18 | none |  | 15 | 0 | 15 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfoInstant | 1 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfoInstant | 2 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfoInstant | 3 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfoInstant | 4 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfoInstant | 5 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfoInstant | 6 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfoInstant | 7 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_Item.GetItemNameByID | 1 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_Item.GetItemQualityByID | 1 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_Item.GetItemSpell | 1 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_Item.GetItemSpell | 2 | none |  | 10 | 0 | 10 | 0 | 0 | 0 |  |
| api:C_Item.IsItemDataCachedByID | 1 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_LFGList.GetActiveEntryInfo | 1 | conditional | SecretInChatMessagingLockdown | 14 | 0 | 14 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:C_PartyInfo.GetRestrictPings | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:C_PlayerInfo.IsPlayerNPERestricted | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:C_PlayerMentorship.IsMentorRestricted | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:C_PvP.GetArenaCrowdControlInfo | 1 | conditional | SecretWhenLossOfControlInfoRestricted | 18 | 0 | 18 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:C_QuestLog.GetLogIndexForQuestID | 1 | none |  | 9 | 0 | 9 | 0 | 0 | 0 |  |
| api:C_QuestLog.GetQuestObjectives | 1 | none |  | 9 | 0 | 9 | 0 | 0 | 0 |  |
| api:C_QuestLog.GetQuestTagInfo | 1 | none |  | 9 | 0 | 9 | 0 | 0 | 0 |  |
| api:C_QuestLog.GetTitleForQuestID | 1 | none |  | 9 | 0 | 9 | 0 | 0 | 0 |  |
| api:C_QuestLog.IsOnQuest | 1 | none |  | 9 | 0 | 9 | 0 | 0 | 0 |  |
| api:C_QuestLog.IsQuestFlaggedCompleted | 1 | none |  | 9 | 0 | 9 | 0 | 0 | 0 |  |
| api:C_QuestLog.ReadyForTurnIn | 1 | none |  | 9 | 0 | 9 | 0 | 0 | 0 |  |
| api:C_ScenarioInfo.GetUnitCriteriaProgressValues | 1 | conditional | SecretWhenUnitIdentityRestricted | 18 | 0 | 18 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:C_Secrets.GetSpellAuraSecrecy | 1 | none |  | 40 | 0 | 40 | 0 | 0 | 0 |  |
| api:C_Secrets.GetSpellCastSecrecy | 1 | none |  | 40 | 0 | 40 | 0 | 0 | 0 |  |
| api:C_Secrets.GetSpellCooldownSecrecy | 1 | none |  | 40 | 0 | 40 | 0 | 0 | 0 |  |
| api:C_Secrets.HasSecretRestrictions | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:C_Secrets.ShouldAurasBeSecret | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:C_Secrets.ShouldCooldownsBeSecret | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:C_Secrets.ShouldUnitStatsBeSecret | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:C_SocialRestrictions.IsAgeVerificationRestricted | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:C_SpecializationInfo.GetInspectSpecialization | 1 | conditional | SecretWhenUnitIdentityRestricted | 18 | 0 | 18 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:C_Spell.DoesSpellExist | 1 | none |  | 24 | 0 | 24 | 0 | 0 | 0 |  |
| api:C_Spell.GetSpellCastCount | 1 | conditional | SecretWhenCooldownsRestricted | 24 | 8 | 16 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldCooldownsBeSecret snapshot; secret in combat/none/none |
| api:C_Spell.GetSpellCharges | 1 | conditional | SecretWhenCooldownsRestricted | 24 | 0 | 24 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); INCONSISTENT with the per-context ShouldCooldownsBeSecret snapshot (combat/none/none) |
| api:C_Spell.GetSpellCooldown | 1 | conditional | SecretWhenCooldownsRestricted | 24 | 0 | 24 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); INCONSISTENT with the per-context ShouldCooldownsBeSecret snapshot (combat/none/none) |
| api:C_Spell.GetSpellCooldownDuration | 1 | none |  | 24 | 0 | 24 | 0 | 0 | 0 |  |
| api:C_Spell.GetSpellDescription | 1 | none |  | 24 | 0 | 24 | 0 | 0 | 0 |  |
| api:C_Spell.GetSpellInfo | 1 | none |  | 24 | 0 | 24 | 0 | 0 | 0 |  |
| api:C_Spell.GetSpellLink | 1 | none |  | 24 | 0 | 24 | 0 | 0 | 0 |  |
| api:C_Spell.GetSpellName | 1 | none |  | 24 | 0 | 24 | 0 | 0 | 0 |  |
| api:C_Spell.GetSpellPowerCost | 1 | none |  | 24 | 0 | 24 | 0 | 0 | 0 |  |
| api:C_Spell.GetSpellTexture | 1 | none |  | 24 | 0 | 24 | 0 | 0 | 0 |  |
| api:C_Spell.GetSpellTexture | 2 | none |  | 24 | 0 | 24 | 0 | 0 | 0 |  |
| api:C_Spell.GetSpellTexture | 3 | none |  | 24 | 0 | 24 | 0 | 0 | 0 |  |
| api:C_Spell.IsSpellPassive | 1 | none |  | 24 | 0 | 24 | 0 | 0 | 0 |  |
| api:C_Spell.IsSpellUsable | 1 | none |  | 24 | 0 | 24 | 0 | 0 | 0 |  |
| api:C_Spell.IsSpellUsable | 2 | none |  | 24 | 0 | 24 | 0 | 0 | 0 |  |
| api:C_SpellBook.IsSpellInSpellBook | 1 | none |  | 24 | 0 | 24 | 0 | 0 | 0 |  |
| api:C_SpellBook.IsSpellKnown | 1 | none |  | 24 | 0 | 24 | 0 | 0 | 0 |  |
| api:GetArmorPenetration | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 2 | 12 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetAvoidance | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 2 | 12 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetBlockChance | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 2 | 12 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetCritChance | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 2 | 12 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetDodgeChance | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 2 | 12 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetDodgeChanceFromAttribute | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetExpertise | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetExpertise | 2 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetExpertise | 3 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetExpertisePercent | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetExpertisePercent | 2 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetExpertisePercent | 3 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetHaste | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetHitModifier | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetLifesteal | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetManaRegen | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 4 | 10 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetManaRegen | 2 | conditional | SecretWhenUnitStatsRestricted | 14 | 4 | 10 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetMastery | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 4 | 10 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetMasteryEffect | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 4 | 10 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetMasteryEffect | 2 | conditional | SecretWhenUnitStatsRestricted | 14 | 4 | 10 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetMeleeHaste | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 4 | 10 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetModResilienceDamageReduction | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 4 | 10 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetOverrideAPBySpellPower | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 4 | 10 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetOverrideSpellPowerByAP | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 4 | 10 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetParryChance | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 4 | 10 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetParryChanceFromAttribute | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 4 | 10 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetPetHitChanceModifier | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 4 | 10 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetPetMeleeHaste | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 4 | 10 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetPetSpellBonusDamage | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 4 | 10 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetPetSpellHitChanceModifier | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 4 | 10 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetPowerRegen | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 4 | 10 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetPowerRegen | 2 | conditional | SecretWhenUnitStatsRestricted | 14 | 4 | 10 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetPvpPowerDamage | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 4 | 10 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetPvpPowerHealing | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 4 | 10 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetRangedCritChance | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 4 | 10 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetRangedHaste | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetRangedHaste | 2 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetRangedHitModifier | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetRestrictedAccountData | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:GetRestrictedAccountData | 2 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:GetRestrictedAccountData | 3 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:GetShieldBlock | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetSpeed | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetSpellBonusHealing | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetSpellCritChance | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetSpellHitModifier | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetSpellPenetration | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetSturdiness | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:GetUnitChargedPowerPoints | 1 | conditional | SecretWhenUnitPowerRestricted | 19 | 0 | 19 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:GetUnitEmpowerHoldAtMaxTime | 1 | conditional | SecretWhenUnitSpellCastRestricted | 19 | 5 | 14 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); secret in combat/none/other, ooc/none/other |
| api:GetUnitEmpowerMinHoldTime | 1 | conditional | SecretWhenUnitSpellCastRestricted | 19 | 5 | 14 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); secret in combat/none/other, ooc/none/other |
| api:GetUnitSpeed | 1 | conditional | SecretWhenUnitStatsRestricted | 24 | 9 | 15 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none, combat/none/other, combat/none/self |
| api:GetUnitSpeed | 2 | conditional | SecretWhenUnitStatsRestricted | 24 | 9 | 15 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none, combat/none/other, combat/none/self |
| api:GetUnitSpeed | 3 | conditional | SecretWhenUnitStatsRestricted | 24 | 9 | 15 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none, combat/none/other, combat/none/self |
| api:GetUnitSpeed | 4 | conditional | SecretWhenUnitStatsRestricted | 24 | 9 | 15 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none, combat/none/other, combat/none/self |
| api:IsRestrictedAccount | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:PlayerEffectiveAttackPower | 1 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:PlayerEffectiveAttackPower | 2 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:PlayerEffectiveAttackPower | 3 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:PlayerEffectiveAttackPower | 4 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:PlayerEffectiveAttackPower | 5 | conditional | SecretWhenUnitStatsRestricted | 14 | 3 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none |
| api:PlayerIsSpellTarget | 1 | always |  | 18 | 18 | 0 | 0 | 0 | 0 |  |
| api:UnitAffectingCombat | 1 | none |  | 7 | 0 | 7 | 0 | 0 | 0 |  |
| api:UnitArmor | 1 | conditional | SecretWhenUnitStatsRestricted | 23 | 9 | 14 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none, combat/none/other, combat/none/self |
| api:UnitArmor | 2 | conditional | SecretWhenUnitStatsRestricted | 23 | 9 | 14 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none, combat/none/other, combat/none/self |
| api:UnitArmor | 3 | conditional | SecretWhenUnitStatsRestricted | 23 | 9 | 14 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none, combat/none/other, combat/none/self |
| api:UnitArmor | 4 | conditional | SecretWhenUnitStatsRestricted | 23 | 9 | 14 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none, combat/none/other, combat/none/self |
| api:UnitAttackPower | 1 | conditional | SecretWhenUnitStatsRestricted | 23 | 9 | 14 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none, combat/none/other, combat/none/self |
| api:UnitAttackPower | 2 | conditional | SecretWhenUnitStatsRestricted | 23 | 9 | 14 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none, combat/none/other, combat/none/self |
| api:UnitAttackPower | 3 | conditional | SecretWhenUnitStatsRestricted | 23 | 9 | 14 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/none, combat/none/other, combat/none/self |
| api:UnitAttackSpeed | 1 | conditional | SecretWhenUnitStatsRestricted | 18 | 6 | 12 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/other, combat/none/self |
| api:UnitAttackSpeed | 2 | conditional | SecretWhenUnitStatsRestricted | 18 | 0 | 18 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); INCONSISTENT with the per-context ShouldUnitStatsBeSecret snapshot (combat/none/other, combat/none/self) |
| api:UnitAttackSpeed | 3 | conditional | SecretWhenUnitStatsRestricted | 18 | 0 | 18 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); INCONSISTENT with the per-context ShouldUnitStatsBeSecret snapshot (combat/none/other, combat/none/self) |
| api:UnitCanAttack | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:UnitCastingInfo | 1 | conditional | SecretWhenUnitSpellCastRestricted | 24 | 0 | 24 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitChannelInfo | 1 | conditional | SecretWhenUnitSpellCastRestricted | 24 | 0 | 24 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitClass | 1 | conditional | SecretWhenUnitIdentityRestricted | 24 | 0 | 24 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitClass | 2 | conditional | SecretWhenUnitIdentityRestricted | 24 | 0 | 24 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitClass | 3 | conditional | SecretWhenUnitIdentityRestricted | 24 | 0 | 24 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitClassBase | 1 | conditional | SecretWhenUnitIdentityRestricted | 19 | 0 | 19 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitClassBase | 2 | conditional | SecretWhenUnitIdentityRestricted | 19 | 0 | 19 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitClassification | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:UnitCreatureFamily | 1 | conditional | SecretWhenUnitIdentityRestricted | 24 | 0 | 24 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitCreatureFamily | 2 | conditional | SecretWhenUnitIdentityRestricted | 6 | 0 | 6 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitCreatureType | 1 | conditional | SecretWhenUnitIdentityRestricted | 23 | 0 | 23 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitCreatureType | 2 | conditional | SecretWhenUnitIdentityRestricted | 23 | 0 | 23 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitDamage | 1 | conditional | SecretWhenUnitStatsRestricted | 18 | 6 | 12 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/other, combat/none/self |
| api:UnitDamage | 2 | conditional | SecretWhenUnitStatsRestricted | 18 | 6 | 12 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/other, combat/none/self |
| api:UnitDamage | 3 | conditional | SecretWhenUnitStatsRestricted | 18 | 6 | 12 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/other, combat/none/self |
| api:UnitDamage | 4 | conditional | SecretWhenUnitStatsRestricted | 18 | 6 | 12 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/other, combat/none/self |
| api:UnitDamage | 5 | conditional | SecretWhenUnitStatsRestricted | 18 | 6 | 12 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/other, combat/none/self |
| api:UnitDamage | 6 | conditional | SecretWhenUnitStatsRestricted | 18 | 6 | 12 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/other, combat/none/self |
| api:UnitDamage | 7 | conditional | SecretWhenUnitStatsRestricted | 18 | 6 | 12 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/other, combat/none/self |
| api:UnitDefenseSkill | 1 | conditional | SecretWhenUnitStatsRestricted | 18 | 6 | 12 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/other, combat/none/self |
| api:UnitDefenseSkill | 2 | conditional | SecretWhenUnitStatsRestricted | 18 | 6 | 12 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/other, combat/none/self |
| api:UnitDetailedThreatSituation | 1 | conditional | SecretWhenUnitThreatValuesRestricted | 5 | 1 | 4 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); secret in combat/none/none |
| api:UnitDetailedThreatSituation | 2 | conditional | SecretWhenUnitThreatValuesRestricted | 2 | 1 | 1 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); secret in combat/none/none |
| api:UnitDetailedThreatSituation | 3 | conditional | SecretWhenUnitThreatValuesRestricted | 2 | 1 | 1 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); secret in combat/none/none |
| api:UnitDetailedThreatSituation | 4 | conditional | SecretWhenUnitThreatValuesRestricted | 2 | 1 | 1 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); secret in combat/none/none |
| api:UnitDetailedThreatSituation | 5 | conditional | SecretWhenUnitThreatValuesRestricted | 2 | 1 | 1 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); secret in combat/none/none |
| api:UnitEffectiveLevel | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:UnitExists | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:UnitFactionGroup | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:UnitFactionGroup | 2 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:UnitFullName | 1 | conditional | SecretWhenUnitIdentityRestricted | 18 | 0 | 18 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitFullName | 2 | conditional | SecretWhenUnitIdentityRestricted | 18 | 0 | 18 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitGUID | 1 | conditional | SecretWhenUnitIdentityRestricted | 23 | 0 | 23 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitGetAvailableRoles | 1 | conditional | SecretWhenUnitIdentityRestricted | 18 | 0 | 18 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitGetAvailableRoles | 2 | conditional | SecretWhenUnitIdentityRestricted | 18 | 0 | 18 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitGetAvailableRoles | 3 | conditional | SecretWhenUnitIdentityRestricted | 18 | 0 | 18 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitGetIncomingHeals | 1 | always |  | 23 | 18 | 5 | 0 | 0 | 0 | secret whenever a value was present; the 5 'clear' sample(s) are attributable to nil returns (return is Nilable; probe saw <nil> 2x) |
| api:UnitGetTotalAbsorbs | 1 | always |  | 22 | 22 | 0 | 0 | 0 | 0 |  |
| api:UnitGetTotalHealAbsorbs | 1 | always |  | 17 | 17 | 0 | 0 | 0 | 0 |  |
| api:UnitGroupRolesAssigned | 1 | conditional | SecretWhenUnitIdentityRestricted | 17 | 0 | 17 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitGroupRolesAssignedEnum | 1 | conditional | SecretWhenUnitIdentityRestricted | 18 | 0 | 18 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitHasEffectivelyTankAura | 1 | conditional | SecretWhenUnitIdentityRestricted | 18 | 0 | 18 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitHealth | 1 | always |  | 22 | 22 | 0 | 0 | 0 | 0 |  |
| api:UnitHealthMax | 1 | conditional | SecretWhenUnitHealthMaxRestricted | 22 | 5 | 17 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); secret in combat/none/none, combat/none/other, ooc/none/other |
| api:UnitHealthMissing | 1 | always |  | 22 | 22 | 0 | 0 | 0 | 0 |  |
| api:UnitHealthPercent | 1 | always |  | 22 | 22 | 0 | 0 | 0 | 0 |  |
| api:UnitHonorLevel | 1 | conditional | SecretWhenUnitIdentityRestricted | 17 | 0 | 17 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitInRaid | 1 | conditional | SecretWhenUnitIdentityRestricted | 17 | 0 | 17 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitInRange | 1 | always |  | 22 | 22 | 0 | 0 | 0 | 0 |  |
| api:UnitInRange | 2 | always |  | 22 | 22 | 0 | 0 | 0 | 0 |  |
| api:UnitIsAFK | 1 | conditional | SecretInChatMessagingLockdown | 17 | 0 | 17 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitIsCharmed | 1 | conditional | SecretWhenUnitPossessionRestricted | 17 | 2 | 15 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); secret in combat/none/other |
| api:UnitIsDND | 1 | conditional | SecretInChatMessagingLockdown | 17 | 0 | 17 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitIsDead | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:UnitIsEnemy | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:UnitIsFriend | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:UnitIsGhost | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:UnitIsGroupAssistant | 1 | conditional | SecretWhenUnitIdentityRestricted | 17 | 0 | 17 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitIsGroupLeader | 1 | conditional | SecretWhenUnitIdentityRestricted | 17 | 0 | 17 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitIsPVP | 1 | conditional | SecretWhenUnitIdentityRestricted | 17 | 0 | 17 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitIsPlayer | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:UnitIsPossessed | 1 | conditional | SecretWhenUnitPossessionRestricted | 18 | 2 | 16 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); secret in combat/none/other |
| api:UnitIsRaidOfficer | 1 | conditional | SecretWhenUnitIdentityRestricted | 18 | 0 | 18 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitIsTapDenied | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:UnitIsUnit | 1 | conditional | SecretWhenUnitComparisonRestricted | 5 | 0 | 5 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitIsVisible | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:UnitLeadsAnyGroup | 1 | conditional | SecretWhenUnitIdentityRestricted | 18 | 0 | 18 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitLevel | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:UnitName | 1 | conditional | SecretWhenUnitNameIdentityRestricted | 23 | 0 | 23 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitName | 2 | conditional | SecretWhenUnitNameIdentityRestricted | 23 | 0 | 23 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitNameUnmodified | 1 | conditional | SecretWhenUnitIdentityRestricted | 18 | 0 | 18 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitNameUnmodified | 2 | conditional | SecretWhenUnitIdentityRestricted | 18 | 0 | 18 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitOwnerGUID | 1 | conditional | SecretWhenUnitIdentityRestricted | 18 | 0 | 18 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitPVPName | 1 | conditional | SecretWhenUnitIdentityRestricted | 19 | 0 | 19 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitPartialPower | 1 | conditional | SecretWhenUnitPowerRestricted | 20 | 20 | 0 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); secret in combat/none/other, combat/none/self, ooc/none/other, ooc/none/self |
| api:UnitPhaseReason | 1 | conditional | SecretWhenUnitIdentityRestricted | 20 | 0 | 20 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitPower | 1 | conditional | SecretWhenUnitPowerRestricted | 25 | 25 | 0 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); secret in combat/none/none, combat/none/other, combat/none/self, ooc/none/none, ooc/none/other, ooc/none/self |
| api:UnitPowerMax | 1 | conditional | SecretWhenUnitPowerMaxRestricted | 24 | 7 | 17 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); secret in combat/none/none, combat/none/other, ooc/none/other |
| api:UnitPowerMissing | 1 | conditional | SecretWhenUnitPowerRestricted | 19 | 19 | 0 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); secret in combat/none/other, combat/none/self, ooc/none/other, ooc/none/self |
| api:UnitPowerPercent | 1 | conditional | SecretWhenCurveSecret | 19 | 19 | 0 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); secret in combat/none/other, combat/none/self, ooc/none/other, ooc/none/self |
| api:UnitPowerType | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:UnitPowerType | 2 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:UnitPowerType | 3 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:UnitPowerType | 4 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:UnitPowerType | 5 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:UnitRace | 1 | conditional | SecretWhenUnitIdentityRestricted | 24 | 0 | 24 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitRace | 2 | conditional | SecretWhenUnitIdentityRestricted | 17 | 0 | 17 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitRace | 3 | conditional | SecretWhenUnitIdentityRestricted | 17 | 0 | 17 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitRangedAttackPower | 1 | conditional | SecretWhenUnitStatsRestricted | 19 | 8 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/other, combat/none/self |
| api:UnitRangedAttackPower | 2 | conditional | SecretWhenUnitStatsRestricted | 19 | 8 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/other, combat/none/self |
| api:UnitRangedAttackPower | 3 | conditional | SecretWhenUnitStatsRestricted | 19 | 8 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/other, combat/none/self |
| api:UnitRangedDamage | 1 | conditional | SecretWhenUnitStatsRestricted | 19 | 8 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/other, combat/none/self |
| api:UnitRangedDamage | 2 | conditional | SecretWhenUnitStatsRestricted | 19 | 8 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/other, combat/none/self |
| api:UnitRangedDamage | 3 | conditional | SecretWhenUnitStatsRestricted | 19 | 8 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/other, combat/none/self |
| api:UnitRangedDamage | 4 | conditional | SecretWhenUnitStatsRestricted | 19 | 8 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/other, combat/none/self |
| api:UnitRangedDamage | 5 | conditional | SecretWhenUnitStatsRestricted | 19 | 8 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/other, combat/none/self |
| api:UnitRangedDamage | 6 | conditional | SecretWhenUnitStatsRestricted | 19 | 8 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/other, combat/none/self |
| api:UnitReaction | 1 | none |  | 5 | 0 | 5 | 0 | 0 | 0 |  |
| api:UnitSex | 1 | conditional | SecretWhenUnitIdentityRestricted | 24 | 0 | 24 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitSexBase | 1 | conditional | SecretWhenUnitIdentityRestricted | 19 | 0 | 19 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:UnitSpellHaste | 1 | conditional | SecretWhenUnitStatsRestricted | 19 | 8 | 11 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/other, combat/none/self |
| api:UnitSpellTargetClass | 1 | always |  | 18 | 6 | 12 | 0 | 0 | 0 | secret whenever a value was present; the 12 'clear' sample(s) are attributable to nil returns (doc text says it returns nil) |
| api:UnitSpellTargetName | 1 | always |  | 18 | 6 | 12 | 0 | 0 | 0 | secret whenever a value was present; the 12 'clear' sample(s) are attributable to nil returns (doc text says it returns nil; MayReturnNothing) |
| api:UnitStagger | 1 | conditional |  | 18 | 4 | 14 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); secret in combat/none/other, ooc/none/other |
| api:UnitThreatSituation | 1 | conditional | SecretWhenUnitThreatStateRestricted | 23 | 1 | 22 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); secret in combat/none/none |
| api:UnitWeaponAttackPower | 1 | conditional | SecretWhenUnitStatsRestricted | 18 | 6 | 12 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/other, combat/none/self |
| api:UnitWeaponAttackPower | 2 | conditional | SecretWhenUnitStatsRestricted | 18 | 6 | 12 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/other, combat/none/self |
| api:UnitWeaponAttackPower | 3 | conditional | SecretWhenUnitStatsRestricted | 18 | 6 | 12 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); consistent with the per-context ShouldUnitStatsBeSecret snapshot; secret in combat/none/other, combat/none/self |
| event:ACTIONBAR_HIDEGRID | 1 | none |  | 1 | 0 | 1 | 0 | 0 | 0 |  |
| event:ACTIONBAR_SHOWGRID | 1 | none |  | 1 | 0 | 1 | 0 | 0 | 0 |  |
| event:ACTIONBAR_SLOT_CHANGED | 1 | none |  | 12 | 0 | 12 | 0 | 0 | 0 |  |
| event:ACTIONBAR_UPDATE_COOLDOWN | 1 | none |  | 49 | 0 | 49 | 0 | 0 | 0 |  |
| event:ACTIONBAR_UPDATE_STATE | 1 | none |  | 47 | 0 | 47 | 0 | 0 | 0 |  |
| event:ACTIONBAR_UPDATE_USABLE | 1 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| event:ACTION_RANGE_CHECK_UPDATE | 1 | none |  | 321 | 0 | 321 | 0 | 0 | 0 |  |
| event:ACTION_RANGE_CHECK_UPDATE | 2 | none |  | 321 | 0 | 321 | 0 | 0 | 0 |  |
| event:ACTION_RANGE_CHECK_UPDATE | 3 | none |  | 321 | 0 | 321 | 0 | 0 | 0 |  |
| event:ACTION_USABLE_CHANGED | 1 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| event:ADDON_LOADED | 1 | none |  | 4 | 0 | 4 | 0 | 0 | 0 |  |
| event:ADDON_LOADED | 2 | none |  | 4 | 0 | 4 | 0 | 0 | 0 |  |
| event:ADDON_RESTRICTION_STATE_CHANGED | 1 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| event:ADDON_RESTRICTION_STATE_CHANGED | 2 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| event:ARENA_COOLDOWNS_UPDATE | 1 | none |  | 1 | 0 | 1 | 0 | 0 | 0 |  |
| event:BAG_UPDATE | 1 | none |  | 4 | 0 | 4 | 0 | 0 | 0 |  |
| event:BAG_UPDATE_COOLDOWN | 1 | none |  | 24 | 0 | 24 | 0 | 0 | 0 |  |
| event:BAG_UPDATE_DELAYED | 1 | none |  | 2 | 0 | 2 | 0 | 0 | 0 |  |
| event:CHAT_LOGGING_CHANGED | 1 | none |  | 2 | 0 | 2 | 0 | 0 | 0 |  |
| event:CHAT_LOGGING_CHANGED | 2 | none |  | 2 | 0 | 2 | 0 | 0 | 0 |  |
| event:CHAT_MSG_CHANNEL | 1 | conditional | SecretInChatMessagingLockdown | 15 | 0 | 15 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| event:CHAT_MSG_CHANNEL | 2 | conditional | SecretInChatMessagingLockdown | 15 | 0 | 15 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| event:CHAT_MSG_CHANNEL | 3 | never | SecretInChatMessagingLockdown | 15 | 0 | 15 | 0 | 0 | 0 |  |
| event:CHAT_MSG_CHANNEL | 4 | never | SecretInChatMessagingLockdown | 15 | 0 | 15 | 0 | 0 | 0 |  |
| event:CHAT_MSG_CHANNEL | 5 | conditional | SecretInChatMessagingLockdown | 15 | 0 | 15 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| event:CHAT_MSG_CHANNEL | 6 | never | SecretInChatMessagingLockdown | 15 | 0 | 15 | 0 | 0 | 0 |  |
| event:CHAT_MSG_CHANNEL | 7 | never | SecretInChatMessagingLockdown | 15 | 0 | 15 | 0 | 0 | 0 |  |
| event:CHAT_MSG_CHANNEL | 8 | never | SecretInChatMessagingLockdown | 15 | 0 | 15 | 0 | 0 | 0 |  |
| event:CHAT_MSG_CHANNEL | 9 | never | SecretInChatMessagingLockdown | 15 | 0 | 15 | 0 | 0 | 0 |  |
| event:CHAT_MSG_CHANNEL | 10 | never | SecretInChatMessagingLockdown | 15 | 0 | 15 | 0 | 0 | 0 |  |
| event:CHAT_MSG_CHANNEL | 11 | never | SecretInChatMessagingLockdown | 15 | 0 | 15 | 0 | 0 | 0 |  |
| event:CHAT_MSG_CHANNEL | 12 | conditional | SecretInChatMessagingLockdown | 15 | 0 | 15 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| event:CHAT_MSG_CHANNEL | 13 | conditional | SecretInChatMessagingLockdown | 15 | 0 | 15 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| ... 181 more in verify.json |||||||||||

## Contradictions flagged live in game (0; v2.1 flags used the old nil-as-clear rule)

