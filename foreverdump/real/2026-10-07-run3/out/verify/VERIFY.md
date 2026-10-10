# Forever secrets VERIFY report (v2.2)

Build 1.60.1.70245 (toc 16001). Ground truth: `api-secrecy-inventory-forever-70245.tsv` (5785 functions, 1804 events). Data: v2.2 SavedVariables.

Value states: absent / nil / secret / container / clear; only present values count. Conditional rows are only CONTRADICTED when the same-frame `C_Secrets.Should*BeSecret` disagreed (v2.2 data); NeverSecret fields secret are always CONTRADICTED.

## Summary

| status | count | before (v2.1 verifier) |
|---|---|---|
| CONTRADICTED | 1 | 1 |
| UNDOCUMENTED-SECRET | 1 | 6 |
| INCONCLUSIVE | 70 | - |
| CONFIRMED | 396 | 392 |
| UNOBSERVED | 10038 | 9368 |

Inventory vs the client's own docs (dump): 5114 agree, 0 disagree, 7 dump functions not in the inventory.

## Coverage

| scope | positions | observed | % |
|---|---|---|---|
| all | 10487 | 449 | 4.28 |
| expectedSecretOrNever | 1591 | 256 | 16.09 |
| alwaysSecret | 45 | 18 | 40.00 |
| conditional | 707 | 210 | 29.70 |
| structFields | 19 | 19 | 100.00 |

## CONTRADICTED (1)

| key | pos | expected | tag | present | secret | clear | containers | nil | absent | note |
|---|---|---|---|---|---|---|---|---|---|---|
| event:UNIT_AURA | 1 | conditional | SecretWhenAurasRestricted | 80 | 0 | 80 | 0 | 0 | 0 | same-frame C_Secrets.ShouldAurasBeSecret disagreed: secret while false 0, clear while true 74 |

## UNDOCUMENTED-SECRET (1)

| key | pos | expected | tag | present | secret | clear | containers | nil | absent | note |
|---|---|---|---|---|---|---|---|---|---|---|
| api:C_Spell.GetSpellCooldownDuration | 1 | none |  | 48 | 16 | 0 | 48 | 0 | 0 | no secrecy tag; secret in combat/none/none |

## INCONCLUSIVE (70)

| key | pos | expected | tag | present | secret | clear | containers | nil | absent | note |
|---|---|---|---|---|---|---|---|---|---|---|
| api:C_CombatText.GetCurrentEventInfo | 1 | always |  | 0 | 0 | 0 | 0 | 17 | 0 | only nil/absent values observed (17 nil, 0 absent) |
| api:C_Item.GetItemInfo | 16 | none |  | 0 | 0 | 0 | 0 | 36 | 0 | only nil/absent values observed (36 nil, 0 absent) |
| api:C_LFGList.GetActiveEntryInfo | 1 | conditional | SecretInChatMessagingLockdown | 0 | 0 | 0 | 0 | 0 | 17 | only nil/absent values observed (0 nil, 17 absent) |
| api:C_PvP.GetArenaCrowdControlInfo | 1 | conditional | SecretWhenLossOfControlInfoRestricted | 0 | 0 | 0 | 0 | 0 | 26 | only nil/absent values observed (0 nil, 26 absent) |
| api:C_PvP.GetArenaCrowdControlInfo | 2 | conditional | SecretWhenLossOfControlInfoRestricted | 0 | 0 | 0 | 0 | 0 | 26 | only nil/absent values observed (0 nil, 26 absent) |
| api:C_PvP.GetArenaCrowdControlInfo | 3 | conditional | SecretWhenLossOfControlInfoRestricted | 0 | 0 | 0 | 0 | 0 | 26 | only nil/absent values observed (0 nil, 26 absent) |
| api:C_QuestLog.GetLogIndexForQuestID | 1 | none |  | 0 | 0 | 0 | 0 | 18 | 0 | only nil/absent values observed (18 nil, 0 absent) |
| api:C_QuestLog.GetQuestTagInfo | 1 | none |  | 0 | 0 | 0 | 0 | 18 | 0 | only nil/absent values observed (18 nil, 0 absent) |
| api:C_ScenarioInfo.GetUnitCriteriaProgressValues | 1 | conditional | SecretWhenUnitIdentityRestricted | 0 | 0 | 0 | 0 | 0 | 26 | only nil/absent values observed (0 nil, 26 absent) |
| api:C_ScenarioInfo.GetUnitCriteriaProgressValues | 2 | conditional | SecretWhenUnitIdentityRestricted | 0 | 0 | 0 | 0 | 0 | 26 | only nil/absent values observed (0 nil, 26 absent) |
| api:C_ScenarioInfo.GetUnitCriteriaProgressValues | 3 | conditional | SecretWhenUnitIdentityRestricted | 0 | 0 | 0 | 0 | 0 | 26 | only nil/absent values observed (0 nil, 26 absent) |
| api:C_Spell.GetSpellCharges | 1 | conditional | SecretWhenCooldownsRestricted | 0 | 0 | 0 | 0 | 0 | 48 | only nil/absent values observed (0 nil, 48 absent) |
| api:C_Spell.GetSpellTexture | 3 | none |  | 0 | 0 | 0 | 0 | 48 | 0 | only nil/absent values observed (48 nil, 0 absent) |
| api:GetUnitChargedPowerPoints | 1 | conditional | SecretWhenUnitPowerRestricted | 0 | 0 | 0 | 0 | 0 | 26 | only nil/absent values observed (0 nil, 26 absent) |
| api:UnitAttackSpeed | 2 | conditional | SecretWhenUnitStatsRestricted | 0 | 0 | 0 | 0 | 26 | 0 | only nil/absent values observed (26 nil, 0 absent) |
| api:UnitAttackSpeed | 3 | conditional | SecretWhenUnitStatsRestricted | 0 | 0 | 0 | 0 | 26 | 0 | only nil/absent values observed (26 nil, 0 absent) |
| api:UnitCastingDuration | 1 | always |  | 1 | 0 | 0 | 1 | 0 | 26 | container(s) with no secret contents (e.g. the player's own cast) |
| api:UnitChannelInfo | 1 | conditional | SecretWhenUnitSpellCastRestricted | 0 | 0 | 0 | 0 | 0 | 36 | only nil/absent values observed (0 nil, 36 absent) |
| api:UnitChannelInfo | 2 | conditional | SecretWhenUnitSpellCastRestricted | 0 | 0 | 0 | 0 | 0 | 36 | only nil/absent values observed (0 nil, 36 absent) |
| api:UnitChannelInfo | 3 | conditional | SecretWhenUnitSpellCastRestricted | 0 | 0 | 0 | 0 | 0 | 36 | only nil/absent values observed (0 nil, 36 absent) |
| api:UnitChannelInfo | 4 | conditional | SecretWhenUnitSpellCastRestricted | 0 | 0 | 0 | 0 | 0 | 36 | only nil/absent values observed (0 nil, 36 absent) |
| api:UnitChannelInfo | 5 | conditional | SecretWhenUnitSpellCastRestricted | 0 | 0 | 0 | 0 | 0 | 36 | only nil/absent values observed (0 nil, 36 absent) |
| api:UnitChannelInfo | 6 | never | SecretWhenUnitSpellCastRestricted | 0 | 0 | 0 | 0 | 0 | 36 | only nil/absent values observed (0 nil, 36 absent) |
| api:UnitChannelInfo | 7 | conditional | SecretWhenUnitSpellCastRestricted | 0 | 0 | 0 | 0 | 0 | 36 | only nil/absent values observed (0 nil, 36 absent) |
| api:UnitChannelInfo | 8 | conditional | SecretWhenUnitSpellCastRestricted | 0 | 0 | 0 | 0 | 0 | 36 | only nil/absent values observed (0 nil, 36 absent) |
| api:UnitChannelInfo | 9 | never | SecretWhenUnitSpellCastRestricted | 0 | 0 | 0 | 0 | 0 | 36 | only nil/absent values observed (0 nil, 36 absent) |
| api:UnitChannelInfo | 10 | never | SecretWhenUnitSpellCastRestricted | 0 | 0 | 0 | 0 | 0 | 36 | only nil/absent values observed (0 nil, 36 absent) |
| api:UnitChannelInfo | 11 | never | SecretWhenUnitSpellCastRestricted | 0 | 0 | 0 | 0 | 0 | 36 | only nil/absent values observed (0 nil, 36 absent) |
| api:UnitInRaid | 1 | conditional | SecretWhenUnitIdentityRestricted | 0 | 0 | 0 | 0 | 24 | 0 | only nil/absent values observed (24 nil, 0 absent) |
| api:UnitOwnerGUID | 1 | conditional | SecretWhenUnitIdentityRestricted | 0 | 0 | 0 | 0 | 23 | 0 | only nil/absent values observed (23 nil, 0 absent) |
| api:UnitPhaseReason | 1 | conditional | SecretWhenUnitIdentityRestricted | 0 | 0 | 0 | 0 | 24 | 0 | only nil/absent values observed (24 nil, 0 absent) |
| api:UnitPowerBarTimerInfo | 1 | always |  | 0 | 0 | 0 | 0 | 0 | 24 | only nil/absent values observed (0 nil, 24 absent) |
| api:UnitPowerBarTimerInfo | 2 | always |  | 0 | 0 | 0 | 0 | 0 | 24 | only nil/absent values observed (0 nil, 24 absent) |
| api:UnitPowerBarTimerInfo | 3 | always |  | 0 | 0 | 0 | 0 | 0 | 24 | only nil/absent values observed (0 nil, 24 absent) |
| api:UnitPowerBarTimerInfo | 4 | always |  | 0 | 0 | 0 | 0 | 0 | 24 | only nil/absent values observed (0 nil, 24 absent) |
| api:UnitPowerType | 3 | none |  | 0 | 0 | 0 | 0 | 9 | 0 | only nil/absent values observed (9 nil, 0 absent) |
| api:UnitPowerType | 4 | none |  | 0 | 0 | 0 | 0 | 9 | 0 | only nil/absent values observed (9 nil, 0 absent) |
| api:UnitPowerType | 5 | none |  | 0 | 0 | 0 | 0 | 9 | 0 | only nil/absent values observed (9 nil, 0 absent) |
| event:ACTIONBAR_UPDATE_COOLDOWN | 1 | none |  | 0 | 0 | 0 | 0 | 84 | 0 | only nil/absent values observed (84 nil, 0 absent) |
| event:ACTIONBAR_UPDATE_STATE | 1 | none |  | 0 | 0 | 0 | 0 | 87 | 0 | only nil/absent values observed (87 nil, 0 absent) |
| event:ACTIONBAR_UPDATE_USABLE | 1 | none |  | 0 | 0 | 0 | 0 | 12 | 0 | only nil/absent values observed (12 nil, 0 absent) |
| event:BAG_UPDATE_COOLDOWN | 1 | none |  | 0 | 0 | 0 | 0 | 37 | 0 | only nil/absent values observed (37 nil, 0 absent) |
| event:COMBAT_RATING_UPDATE | 1 | none |  | 0 | 0 | 0 | 0 | 6 | 0 | only nil/absent values observed (6 nil, 0 absent) |
| event:CRITERIA_UPDATE | 1 | none |  | 0 | 0 | 0 | 0 | 24 | 0 | only nil/absent values observed (24 nil, 0 absent) |
| event:DAMAGE_METER_CURRENT_SESSION_UPDATED | 1 | none |  | 0 | 0 | 0 | 0 | 5 | 0 | only nil/absent values observed (5 nil, 0 absent) |
| event:PET_BAR_UPDATE_USABLE | 1 | none |  | 0 | 0 | 0 | 0 | 25 | 0 | only nil/absent values observed (25 nil, 0 absent) |
| event:PLAYER_ENTER_COMBAT | 1 | none |  | 0 | 0 | 0 | 0 | 8 | 0 | only nil/absent values observed (8 nil, 0 absent) |
| event:PLAYER_FOCUS_CHANGED | 1 | none |  | 0 | 0 | 0 | 0 | 1 | 0 | only nil/absent values observed (1 nil, 0 absent) |
| event:PLAYER_LEAVE_COMBAT | 1 | none |  | 0 | 0 | 0 | 0 | 8 | 0 | only nil/absent values observed (8 nil, 0 absent) |
| event:PLAYER_REGEN_DISABLED | 1 | none |  | 0 | 0 | 0 | 0 | 6 | 0 | only nil/absent values observed (6 nil, 0 absent) |
| event:PLAYER_REGEN_ENABLED | 1 | none |  | 0 | 0 | 0 | 0 | 6 | 0 | only nil/absent values observed (6 nil, 0 absent) |
| event:PLAYER_SOFT_ENEMY_CHANGED | 1 | none |  | 0 | 0 | 0 | 0 | 11 | 0 | only nil/absent values observed (11 nil, 0 absent) |
| event:PLAYER_STARTED_LOOKING | 1 | none |  | 0 | 0 | 0 | 0 | 23 | 0 | only nil/absent values observed (23 nil, 0 absent) |
| event:PLAYER_STARTED_MOVING | 1 | none |  | 0 | 0 | 0 | 0 | 32 | 0 | only nil/absent values observed (32 nil, 0 absent) |
| event:PLAYER_STARTED_TURNING | 1 | none |  | 0 | 0 | 0 | 0 | 49 | 0 | only nil/absent values observed (49 nil, 0 absent) |
| event:PLAYER_STOPPED_LOOKING | 1 | none |  | 0 | 0 | 0 | 0 | 23 | 0 | only nil/absent values observed (23 nil, 0 absent) |
| event:PLAYER_STOPPED_MOVING | 1 | none |  | 0 | 0 | 0 | 0 | 32 | 0 | only nil/absent values observed (32 nil, 0 absent) |
| event:PLAYER_STOPPED_TURNING | 1 | none |  | 0 | 0 | 0 | 0 | 49 | 0 | only nil/absent values observed (49 nil, 0 absent) |
| event:PLAYER_TARGET_CHANGED | 1 | none |  | 0 | 0 | 0 | 0 | 37 | 0 | only nil/absent values observed (37 nil, 0 absent) |
| event:PLAYER_TARGET_DIED | 1 | none |  | 0 | 0 | 0 | 0 | 6 | 0 | only nil/absent values observed (6 nil, 0 absent) |
| event:RAID_TARGET_UPDATE | 1 | none |  | 0 | 0 | 0 | 0 | 2 | 0 | only nil/absent values observed (2 nil, 0 absent) |
| event:SPELL_ACTIVATION_OVERLAY_HIDE | 1 | none |  | 0 | 0 | 0 | 0 | 147 | 0 | only nil/absent values observed (147 nil, 0 absent) |
| event:SPELL_UPDATE_COOLDOWN | 2 | none |  | 0 | 0 | 0 | 0 | 84 | 0 | only nil/absent values observed (84 nil, 0 absent) |
| event:SPELL_UPDATE_COOLDOWN | 5 | none |  | 0 | 0 | 0 | 0 | 84 | 0 | only nil/absent values observed (84 nil, 0 absent) |
| event:SPELL_UPDATE_USABLE | 1 | none |  | 0 | 0 | 0 | 0 | 843 | 0 | only nil/absent values observed (843 nil, 0 absent) |
| event:UNIT_SPELLCAST_FAILED | 4 | never | SecretWhenUnitSpellCastRestricted | 0 | 0 | 0 | 0 | 10 | 0 | only nil/absent values observed (10 nil, 0 absent) |
| event:UNIT_SPELLCAST_INTERRUPTED | 4 | conditional | SecretWhenUnitSpellCastRestricted | 0 | 0 | 0 | 0 | 112 | 0 | only nil/absent values observed (112 nil, 0 absent) |
| event:UPDATE_INVENTORY_DURABILITY | 1 | none |  | 0 | 0 | 0 | 0 | 8 | 0 | only nil/absent values observed (8 nil, 0 absent) |
| event:UPDATE_MACROS | 1 | none |  | 0 | 0 | 0 | 0 | 3 | 0 | only nil/absent values observed (3 nil, 0 absent) |
| event:UPDATE_MOUSEOVER_UNIT | 1 | none |  | 0 | 0 | 0 | 0 | 45 | 0 | only nil/absent values observed (45 nil, 0 absent) |

## CONFIRMED (396)

| key | pos | expected | tag | present | secret | clear | containers | nil | absent | note |
|---|---|---|---|---|---|---|---|---|---|---|
| api:C_ChatInfo.AreOutgoingAddonChatMessagesRestricted | 1 | none |  | 7 | 0 | 7 | 0 | 0 | 0 |  |
| api:C_Club.IsRestricted | 1 | none |  | 7 | 0 | 7 | 0 | 0 | 0 |  |
| api:C_CombatLog.IsCombatLogRestricted | 1 | none |  | 7 | 0 | 7 | 0 | 0 | 0 |  |
| api:C_Container.GetItemCooldown | 1 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Container.GetItemCooldown | 2 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Container.GetItemCooldown | 3 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_DamageMeter.GetCombatSessionFromType | 1 | conditional | SecretWhenInCombat | 88 | 0 | 88 | 0 | 0 | 0 | unverified-predicate (no same-frame sample) |
| api:C_Item.GetDetailedItemLevelInfo | 1 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetDetailedItemLevelInfo | 2 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetDetailedItemLevelInfo | 3 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemCooldown | 1 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemCooldown | 2 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemCooldown | 3 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemCount | 1 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemIconByID | 1 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 1 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 2 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 3 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 4 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 5 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 6 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 7 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 8 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 9 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 10 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 11 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 12 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 13 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 14 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 15 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 17 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfo | 18 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfoInstant | 1 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfoInstant | 2 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfoInstant | 3 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfoInstant | 4 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfoInstant | 5 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfoInstant | 6 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemInfoInstant | 7 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemNameByID | 1 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemQualityByID | 1 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_Item.GetItemSpell | 1 | none |  | 24 | 0 | 24 | 0 | 0 | 12 |  |
| api:C_Item.GetItemSpell | 2 | none |  | 24 | 0 | 24 | 0 | 0 | 12 |  |
| api:C_Item.IsItemDataCachedByID | 1 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| api:C_PartyInfo.GetRestrictPings | 1 | none |  | 7 | 0 | 7 | 0 | 0 | 0 |  |
| api:C_PlayerInfo.IsPlayerNPERestricted | 1 | none |  | 7 | 0 | 7 | 0 | 0 | 0 |  |
| api:C_PlayerMentorship.IsMentorRestricted | 1 | none |  | 7 | 0 | 7 | 0 | 0 | 0 |  |
| api:C_QuestLog.GetQuestObjectives | 1 | none |  | 18 | 0 | 0 | 18 | 0 | 0 |  |
| api:C_QuestLog.GetTitleForQuestID | 1 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_QuestLog.IsOnQuest | 1 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_QuestLog.IsQuestFlaggedCompleted | 1 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_QuestLog.ReadyForTurnIn | 1 | none |  | 18 | 0 | 18 | 0 | 0 | 0 |  |
| api:C_Secrets.GetSpellAuraSecrecy | 1 | none |  | 80 | 0 | 80 | 0 | 0 | 0 |  |
| api:C_Secrets.GetSpellCastSecrecy | 1 | none |  | 80 | 0 | 80 | 0 | 0 | 0 |  |
| api:C_Secrets.GetSpellCooldownSecrecy | 1 | none |  | 80 | 0 | 80 | 0 | 0 | 0 |  |
| api:C_Secrets.HasSecretRestrictions | 1 | none |  | 7 | 0 | 7 | 0 | 0 | 0 |  |
| api:C_Secrets.ShouldAurasBeSecret | 1 | none |  | 7 | 0 | 7 | 0 | 0 | 0 |  |
| api:C_Secrets.ShouldCooldownsBeSecret | 1 | none |  | 7 | 0 | 7 | 0 | 0 | 0 |  |
| api:C_Secrets.ShouldUnitStatsBeSecret | 1 | none |  | 7 | 0 | 7 | 0 | 0 | 0 |  |
| api:C_SocialRestrictions.IsAgeVerificationRestricted | 1 | none |  | 7 | 0 | 7 | 0 | 0 | 0 |  |
| api:C_SpecializationInfo.GetInspectSpecialization | 1 | conditional | SecretWhenUnitIdentityRestricted | 26 | 0 | 26 | 0 | 0 | 0 | verified against same-frame predicate |
| api:C_Spell.DoesSpellExist | 1 | none |  | 48 | 0 | 48 | 0 | 0 | 0 |  |
| api:C_Spell.GetSpellCastCount | 1 | conditional | SecretWhenCooldownsRestricted | 48 | 16 | 32 | 0 | 0 | 0 | verified against same-frame predicate |
| api:C_Spell.GetSpellCooldown | 1 | conditional | SecretWhenCooldownsRestricted | 48 | 16 | 0 | 48 | 0 | 0 | verified against same-frame predicate |
| api:C_Spell.GetSpellDescription | 1 | none |  | 48 | 0 | 48 | 0 | 0 | 0 |  |
| api:C_Spell.GetSpellInfo | 1 | none |  | 48 | 0 | 0 | 48 | 0 | 0 |  |
| api:C_Spell.GetSpellLink | 1 | none |  | 48 | 0 | 48 | 0 | 0 | 0 |  |
| api:C_Spell.GetSpellName | 1 | none |  | 48 | 0 | 48 | 0 | 0 | 0 |  |
| api:C_Spell.GetSpellPowerCost | 1 | none |  | 30 | 0 | 0 | 30 | 0 | 18 |  |
| api:C_Spell.GetSpellTexture | 1 | none |  | 48 | 0 | 48 | 0 | 0 | 0 |  |
| api:C_Spell.GetSpellTexture | 2 | none |  | 48 | 0 | 48 | 0 | 0 | 0 |  |
| api:C_Spell.IsSpellPassive | 1 | none |  | 48 | 0 | 48 | 0 | 0 | 0 |  |
| api:C_Spell.IsSpellUsable | 1 | none |  | 48 | 0 | 48 | 0 | 0 | 0 |  |
| api:C_Spell.IsSpellUsable | 2 | none |  | 48 | 0 | 48 | 0 | 0 | 0 |  |
| api:C_SpellBook.IsSpellInSpellBook | 1 | none |  | 48 | 0 | 48 | 0 | 0 | 0 |  |
| api:C_SpellBook.IsSpellKnown | 1 | none |  | 48 | 0 | 48 | 0 | 0 | 0 |  |
| api:GetArmorPenetration | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetAvoidance | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetBlockChance | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetCritChance | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetDodgeChance | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetDodgeChanceFromAttribute | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetExpertise | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetExpertise | 2 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetExpertise | 3 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetExpertisePercent | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetExpertisePercent | 2 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetExpertisePercent | 3 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetHaste | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetHitModifier | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetLifesteal | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetManaRegen | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetManaRegen | 2 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetMastery | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetMasteryEffect | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetMasteryEffect | 2 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetMeleeHaste | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetModResilienceDamageReduction | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetOverrideAPBySpellPower | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetOverrideSpellPowerByAP | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetParryChance | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetParryChanceFromAttribute | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetPetHitChanceModifier | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetPetMeleeHaste | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetPetSpellBonusDamage | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetPetSpellHitChanceModifier | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetPowerRegen | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetPowerRegen | 2 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetPvpPowerDamage | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetPvpPowerHealing | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetRaidTargetIndex | 1 | always |  | 2 | 2 | 0 | 0 | 26 | 0 |  |
| api:GetRangedCritChance | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetRangedHaste | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetRangedHaste | 2 | conditional | SecretWhenUnitStatsRestricted | 17 | 10 | 7 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetRangedHitModifier | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 9 | 8 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetRestrictedAccountData | 1 | none |  | 7 | 0 | 7 | 0 | 0 | 0 |  |
| api:GetRestrictedAccountData | 2 | none |  | 7 | 0 | 7 | 0 | 0 | 0 |  |
| api:GetRestrictedAccountData | 3 | none |  | 7 | 0 | 7 | 0 | 0 | 0 |  |
| api:GetShieldBlock | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 8 | 9 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetSpeed | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 8 | 9 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetSpellBonusHealing | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 8 | 9 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetSpellCritChance | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 8 | 9 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetSpellHitModifier | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 8 | 9 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetSpellPenetration | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 8 | 9 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetSturdiness | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 8 | 9 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetUnitEmpowerHoldAtMaxTime | 1 | conditional | SecretWhenUnitSpellCastRestricted | 26 | 9 | 17 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetUnitEmpowerMinHoldTime | 1 | conditional | SecretWhenUnitSpellCastRestricted | 26 | 9 | 17 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetUnitSpeed | 1 | conditional | SecretWhenUnitStatsRestricted | 35 | 20 | 15 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetUnitSpeed | 2 | conditional | SecretWhenUnitStatsRestricted | 35 | 20 | 15 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetUnitSpeed | 3 | conditional | SecretWhenUnitStatsRestricted | 35 | 20 | 15 | 0 | 0 | 0 | verified against same-frame predicate |
| api:GetUnitSpeed | 4 | conditional | SecretWhenUnitStatsRestricted | 35 | 20 | 15 | 0 | 0 | 0 | verified against same-frame predicate |
| api:IsRestrictedAccount | 1 | none |  | 7 | 0 | 7 | 0 | 0 | 0 |  |
| api:PlayerEffectiveAttackPower | 1 | conditional | SecretWhenUnitStatsRestricted | 17 | 8 | 9 | 0 | 0 | 0 | verified against same-frame predicate |
| api:PlayerEffectiveAttackPower | 2 | conditional | SecretWhenUnitStatsRestricted | 17 | 8 | 9 | 0 | 0 | 0 | verified against same-frame predicate |
| api:PlayerEffectiveAttackPower | 3 | conditional | SecretWhenUnitStatsRestricted | 17 | 8 | 9 | 0 | 0 | 0 | verified against same-frame predicate |
| api:PlayerEffectiveAttackPower | 4 | conditional | SecretWhenUnitStatsRestricted | 17 | 8 | 9 | 0 | 0 | 0 | verified against same-frame predicate |
| api:PlayerEffectiveAttackPower | 5 | conditional | SecretWhenUnitStatsRestricted | 17 | 8 | 9 | 0 | 0 | 0 | verified against same-frame predicate |
| api:PlayerIsSpellTarget | 1 | always |  | 26 | 26 | 0 | 0 | 0 | 0 |  |
| api:UnitAffectingCombat | 1 | none |  | 13 | 0 | 13 | 0 | 0 | 0 |  |
| api:UnitArmor | 1 | conditional | SecretWhenUnitStatsRestricted | 35 | 20 | 15 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitArmor | 2 | conditional | SecretWhenUnitStatsRestricted | 35 | 20 | 15 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitArmor | 3 | conditional | SecretWhenUnitStatsRestricted | 35 | 20 | 15 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitArmor | 4 | conditional | SecretWhenUnitStatsRestricted | 35 | 20 | 15 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitAttackPower | 1 | conditional | SecretWhenUnitStatsRestricted | 35 | 20 | 15 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitAttackPower | 2 | conditional | SecretWhenUnitStatsRestricted | 35 | 20 | 15 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitAttackPower | 3 | conditional | SecretWhenUnitStatsRestricted | 35 | 20 | 15 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitAttackSpeed | 1 | conditional | SecretWhenUnitStatsRestricted | 26 | 16 | 10 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitCanAttack | 1 | none |  | 9 | 0 | 9 | 0 | 0 | 0 |  |
| api:UnitCastingInfo | 1 | conditional | SecretWhenUnitSpellCastRestricted | 1 | 0 | 1 | 0 | 0 | 35 | verified against same-frame predicate |
| api:UnitCastingInfo | 2 | conditional | SecretWhenUnitSpellCastRestricted | 1 | 0 | 1 | 0 | 0 | 35 | verified against same-frame predicate |
| api:UnitCastingInfo | 3 | conditional | SecretWhenUnitSpellCastRestricted | 1 | 0 | 1 | 0 | 0 | 35 | verified against same-frame predicate |
| api:UnitCastingInfo | 4 | conditional | SecretWhenUnitSpellCastRestricted | 1 | 0 | 1 | 0 | 0 | 35 | verified against same-frame predicate |
| api:UnitCastingInfo | 5 | conditional | SecretWhenUnitSpellCastRestricted | 1 | 0 | 1 | 0 | 0 | 35 | verified against same-frame predicate |
| api:UnitCastingInfo | 6 | never | SecretWhenUnitSpellCastRestricted | 1 | 0 | 1 | 0 | 0 | 35 |  |
| api:UnitCastingInfo | 7 | conditional | SecretWhenUnitSpellCastRestricted | 1 | 0 | 1 | 0 | 0 | 35 | verified against same-frame predicate |
| api:UnitCastingInfo | 8 | conditional | SecretWhenUnitSpellCastRestricted | 1 | 0 | 1 | 0 | 0 | 35 | verified against same-frame predicate |
| api:UnitCastingInfo | 9 | conditional | SecretWhenUnitSpellCastRestricted | 1 | 0 | 1 | 0 | 0 | 35 | verified against same-frame predicate |
| api:UnitCastingInfo | 10 | never | SecretWhenUnitSpellCastRestricted | 1 | 0 | 1 | 0 | 0 | 35 |  |
| api:UnitCastingInfo | 11 | never | SecretWhenUnitSpellCastRestricted | 1 | 0 | 1 | 0 | 0 | 35 |  |
| api:UnitClass | 1 | conditional | SecretWhenUnitIdentityRestricted | 36 | 0 | 36 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitClass | 2 | conditional | SecretWhenUnitIdentityRestricted | 36 | 0 | 36 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitClass | 3 | conditional | SecretWhenUnitIdentityRestricted | 36 | 0 | 36 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitClassBase | 1 | conditional | SecretWhenUnitIdentityRestricted | 27 | 0 | 27 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitClassBase | 2 | conditional | SecretWhenUnitIdentityRestricted | 27 | 0 | 27 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitClassification | 1 | none |  | 9 | 0 | 9 | 0 | 0 | 0 |  |
| api:UnitCreatureFamily | 1 | conditional | SecretWhenUnitIdentityRestricted | 11 | 0 | 11 | 0 | 0 | 25 | verified against same-frame predicate |
| api:UnitCreatureFamily | 2 | conditional | SecretWhenUnitIdentityRestricted | 11 | 0 | 11 | 0 | 0 | 25 | verified against same-frame predicate |
| api:UnitCreatureType | 1 | conditional | SecretWhenUnitIdentityRestricted | 36 | 0 | 36 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitCreatureType | 2 | conditional | SecretWhenUnitIdentityRestricted | 36 | 0 | 36 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitDamage | 1 | conditional | SecretWhenUnitStatsRestricted | 27 | 18 | 9 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitDamage | 2 | conditional | SecretWhenUnitStatsRestricted | 27 | 18 | 9 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitDamage | 3 | conditional | SecretWhenUnitStatsRestricted | 27 | 18 | 9 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitDamage | 4 | conditional | SecretWhenUnitStatsRestricted | 27 | 18 | 9 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitDamage | 5 | conditional | SecretWhenUnitStatsRestricted | 27 | 18 | 9 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitDamage | 6 | conditional | SecretWhenUnitStatsRestricted | 27 | 18 | 9 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitDamage | 7 | conditional | SecretWhenUnitStatsRestricted | 27 | 18 | 9 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitDefenseSkill | 1 | conditional | SecretWhenUnitStatsRestricted | 26 | 16 | 10 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitDefenseSkill | 2 | conditional | SecretWhenUnitStatsRestricted | 26 | 16 | 10 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitDetailedThreatSituation | 1 | conditional | SecretWhenUnitThreatValuesRestricted | 1 | 0 | 1 | 0 | 0 | 8 | verified against same-frame predicate |
| api:UnitDetailedThreatSituation | 2 | conditional | SecretWhenUnitThreatValuesRestricted | 1 | 0 | 1 | 0 | 0 | 8 | verified against same-frame predicate |
| api:UnitDetailedThreatSituation | 3 | conditional | SecretWhenUnitThreatValuesRestricted | 1 | 0 | 1 | 0 | 0 | 8 | verified against same-frame predicate |
| api:UnitDetailedThreatSituation | 4 | conditional | SecretWhenUnitThreatValuesRestricted | 1 | 0 | 1 | 0 | 0 | 8 | verified against same-frame predicate |
| api:UnitDetailedThreatSituation | 5 | conditional | SecretWhenUnitThreatValuesRestricted | 1 | 0 | 1 | 0 | 0 | 8 | verified against same-frame predicate |
| api:UnitEffectiveLevel | 1 | none |  | 9 | 0 | 9 | 0 | 0 | 0 |  |
| api:UnitExists | 1 | none |  | 9 | 0 | 9 | 0 | 0 | 0 |  |
| api:UnitFactionGroup | 1 | none |  | 8 | 0 | 8 | 0 | 1 | 0 |  |
| api:UnitFactionGroup | 2 | none |  | 8 | 0 | 8 | 0 | 1 | 0 |  |
| api:UnitFullName | 1 | conditional | SecretWhenUnitIdentityRestricted | 25 | 0 | 25 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitFullName | 2 | conditional | SecretWhenUnitIdentityRestricted | 16 | 0 | 16 | 0 | 9 | 0 | verified against same-frame predicate |
| api:UnitGUID | 1 | conditional | SecretWhenUnitIdentityRestricted | 34 | 0 | 34 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitGetAvailableRoles | 1 | conditional | SecretWhenUnitIdentityRestricted | 25 | 0 | 25 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitGetAvailableRoles | 2 | conditional | SecretWhenUnitIdentityRestricted | 25 | 0 | 25 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitGetAvailableRoles | 3 | conditional | SecretWhenUnitIdentityRestricted | 25 | 0 | 25 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitGetIncomingHeals | 1 | always |  | 24 | 24 | 0 | 0 | 10 | 0 |  |
| api:UnitGetTotalAbsorbs | 1 | always |  | 33 | 33 | 0 | 0 | 0 | 0 |  |
| api:UnitGetTotalHealAbsorbs | 1 | always |  | 24 | 24 | 0 | 0 | 0 | 0 |  |
| api:UnitGroupRolesAssigned | 1 | conditional | SecretWhenUnitIdentityRestricted | 24 | 0 | 24 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitGroupRolesAssignedEnum | 1 | conditional | SecretWhenUnitIdentityRestricted | 24 | 0 | 24 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitHasEffectivelyTankAura | 1 | conditional | SecretWhenUnitIdentityRestricted | 24 | 0 | 24 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitHealth | 1 | always |  | 33 | 33 | 0 | 0 | 0 | 0 |  |
| api:UnitHealthMax | 1 | conditional | SecretWhenUnitHealthMaxRestricted | 33 | 9 | 24 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitHealthMissing | 1 | always |  | 33 | 33 | 0 | 0 | 0 | 0 |  |
| api:UnitHealthPercent | 1 | always |  | 33 | 33 | 0 | 0 | 0 | 0 |  |
| api:UnitHonorLevel | 1 | conditional | SecretWhenUnitIdentityRestricted | 24 | 0 | 24 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitInRange | 1 | always |  | 33 | 33 | 0 | 0 | 0 | 0 |  |
| api:UnitInRange | 2 | always |  | 33 | 33 | 0 | 0 | 0 | 0 |  |
| api:UnitIsAFK | 1 | conditional | SecretInChatMessagingLockdown | 24 | 0 | 24 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitIsCharmed | 1 | conditional | SecretWhenUnitPossessionRestricted | 24 | 8 | 16 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); secret in combat/none/other |
| api:UnitIsDND | 1 | conditional | SecretInChatMessagingLockdown | 24 | 0 | 24 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitIsDead | 1 | none |  | 9 | 0 | 9 | 0 | 0 | 0 |  |
| api:UnitIsEnemy | 1 | none |  | 9 | 0 | 9 | 0 | 0 | 0 |  |
| api:UnitIsFriend | 1 | none |  | 9 | 0 | 9 | 0 | 0 | 0 |  |
| api:UnitIsGhost | 1 | none |  | 9 | 0 | 9 | 0 | 0 | 0 |  |
| api:UnitIsGroupAssistant | 1 | conditional | SecretWhenUnitIdentityRestricted | 24 | 0 | 24 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitIsGroupLeader | 1 | conditional | SecretWhenUnitIdentityRestricted | 24 | 0 | 24 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitIsPVP | 1 | conditional | SecretWhenUnitIdentityRestricted | 24 | 0 | 24 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitIsPlayer | 1 | none |  | 9 | 0 | 9 | 0 | 0 | 0 |  |
| api:UnitIsPossessed | 1 | conditional | SecretWhenUnitPossessionRestricted | 24 | 8 | 16 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); secret in combat/none/other |
| api:UnitIsRaidOfficer | 1 | conditional | SecretWhenUnitIdentityRestricted | 24 | 0 | 24 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitIsTapDenied | 1 | none |  | 9 | 0 | 9 | 0 | 0 | 0 |  |
| api:UnitIsUnit | 1 | conditional | SecretWhenUnitComparisonRestricted | 9 | 0 | 9 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitIsVisible | 1 | none |  | 9 | 0 | 9 | 0 | 0 | 0 |  |
| api:UnitLeadsAnyGroup | 1 | conditional | SecretWhenUnitIdentityRestricted | 23 | 0 | 23 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitLevel | 1 | none |  | 9 | 0 | 9 | 0 | 0 | 0 |  |
| api:UnitName | 1 | conditional | SecretWhenUnitNameIdentityRestricted | 32 | 0 | 32 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitName | 2 | conditional | SecretWhenUnitNameIdentityRestricted | 23 | 0 | 23 | 0 | 9 | 0 | verified against same-frame predicate |
| api:UnitNameUnmodified | 1 | conditional | SecretWhenUnitIdentityRestricted | 23 | 0 | 23 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitNameUnmodified | 2 | conditional | SecretWhenUnitIdentityRestricted | 15 | 0 | 15 | 0 | 8 | 0 | verified against same-frame predicate |
| api:UnitPVPName | 1 | conditional | SecretWhenUnitIdentityRestricted | 23 | 0 | 23 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitPartialPower | 1 | conditional | SecretWhenUnitPowerRestricted | 24 | 24 | 0 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitPower | 1 | conditional | SecretWhenUnitPowerRestricted | 33 | 33 | 0 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitPowerMax | 1 | conditional | SecretWhenUnitPowerMaxRestricted | 33 | 10 | 23 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitPowerMissing | 1 | conditional | SecretWhenUnitPowerRestricted | 24 | 24 | 0 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitPowerPercent | 1 | conditional | SecretWhenCurveSecret | 24 | 24 | 0 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitPowerType | 1 | none |  | 9 | 0 | 9 | 0 | 0 | 0 |  |
| api:UnitPowerType | 2 | none |  | 9 | 0 | 9 | 0 | 0 | 0 |  |
| api:UnitRace | 1 | conditional | SecretWhenUnitIdentityRestricted | 23 | 0 | 23 | 0 | 0 | 10 | verified against same-frame predicate |
| api:UnitRace | 2 | conditional | SecretWhenUnitIdentityRestricted | 23 | 0 | 23 | 0 | 0 | 10 | verified against same-frame predicate |
| api:UnitRace | 3 | conditional | SecretWhenUnitIdentityRestricted | 23 | 0 | 23 | 0 | 0 | 10 | verified against same-frame predicate |
| api:UnitRangedAttackPower | 1 | conditional | SecretWhenUnitStatsRestricted | 24 | 19 | 5 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitRangedAttackPower | 2 | conditional | SecretWhenUnitStatsRestricted | 24 | 19 | 5 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitRangedAttackPower | 3 | conditional | SecretWhenUnitStatsRestricted | 24 | 19 | 5 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitRangedDamage | 1 | conditional | SecretWhenUnitStatsRestricted | 24 | 19 | 5 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitRangedDamage | 2 | conditional | SecretWhenUnitStatsRestricted | 24 | 19 | 5 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitRangedDamage | 3 | conditional | SecretWhenUnitStatsRestricted | 24 | 19 | 5 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitRangedDamage | 4 | conditional | SecretWhenUnitStatsRestricted | 24 | 19 | 5 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitRangedDamage | 5 | conditional | SecretWhenUnitStatsRestricted | 24 | 19 | 5 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitRangedDamage | 6 | conditional | SecretWhenUnitStatsRestricted | 24 | 19 | 5 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitReaction | 1 | none |  | 9 | 0 | 9 | 0 | 0 | 0 |  |
| api:UnitSex | 1 | conditional | SecretWhenUnitIdentityRestricted | 33 | 0 | 33 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitSexBase | 1 | conditional | SecretWhenUnitIdentityRestricted | 24 | 0 | 24 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitSpellHaste | 1 | conditional | SecretWhenUnitStatsRestricted | 24 | 19 | 5 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitSpellTargetClass | 1 | always |  | 15 | 15 | 0 | 0 | 9 | 0 |  |
| api:UnitSpellTargetName | 1 | always |  | 15 | 15 | 0 | 0 | 0 | 9 |  |
| api:UnitStagger | 1 | conditional |  | 24 | 9 | 15 | 0 | 0 | 0 | unverified-predicate (no same-frame sample); secret in combat/none/other |
| api:UnitThreatSituation | 1 | conditional | SecretWhenUnitThreatStateRestricted | 11 | 0 | 11 | 0 | 22 | 0 | verified against same-frame predicate |
| api:UnitWeaponAttackPower | 1 | conditional | SecretWhenUnitStatsRestricted | 24 | 19 | 5 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitWeaponAttackPower | 2 | conditional | SecretWhenUnitStatsRestricted | 24 | 19 | 5 | 0 | 0 | 0 | verified against same-frame predicate |
| api:UnitWeaponAttackPower | 3 | conditional | SecretWhenUnitStatsRestricted | 24 | 19 | 5 | 0 | 0 | 0 | verified against same-frame predicate |
| event:ACTIONBAR_SLOT_CHANGED | 1 | none |  | 7 | 0 | 7 | 0 | 0 | 0 |  |
| event:ACTION_RANGE_CHECK_UPDATE | 1 | none |  | 309 | 0 | 309 | 0 | 0 | 0 |  |
| event:ACTION_RANGE_CHECK_UPDATE | 2 | none |  | 309 | 0 | 309 | 0 | 0 | 0 |  |
| event:ACTION_RANGE_CHECK_UPDATE | 3 | none |  | 309 | 0 | 309 | 0 | 0 | 0 |  |
| event:ACTION_USABLE_CHANGED | 1 | none |  | 12 | 0 | 0 | 12 | 0 | 0 |  |
| event:ADDON_ACTION_BLOCKED | 1 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| event:ADDON_ACTION_BLOCKED | 2 | none |  | 36 | 0 | 36 | 0 | 0 | 0 |  |
| event:ADDON_RESTRICTION_STATE_CHANGED | 1 | none |  | 12 | 0 | 12 | 0 | 0 | 0 |  |
| event:ADDON_RESTRICTION_STATE_CHANGED | 2 | none |  | 12 | 0 | 12 | 0 | 0 | 0 |  |
| event:CHAT_LOGGING_CHANGED | 1 | none |  | 4 | 0 | 4 | 0 | 0 | 0 |  |
| event:CHAT_LOGGING_CHANGED | 2 | none |  | 4 | 0 | 4 | 0 | 0 | 0 |  |
| event:CHAT_MSG_CHANNEL | 1 | conditional | SecretInChatMessagingLockdown | 5 | 0 | 5 | 0 | 0 | 0 | verified against same-frame predicate |
| event:CHAT_MSG_CHANNEL | 2 | conditional | SecretInChatMessagingLockdown | 5 | 0 | 5 | 0 | 0 | 0 | verified against same-frame predicate |
| event:CHAT_MSG_CHANNEL | 3 | never | SecretInChatMessagingLockdown | 5 | 0 | 5 | 0 | 0 | 0 |  |
| event:CHAT_MSG_CHANNEL | 4 | never | SecretInChatMessagingLockdown | 5 | 0 | 5 | 0 | 0 | 0 |  |
| event:CHAT_MSG_CHANNEL | 5 | conditional | SecretInChatMessagingLockdown | 5 | 0 | 5 | 0 | 0 | 0 | verified against same-frame predicate |
| event:CHAT_MSG_CHANNEL | 6 | never | SecretInChatMessagingLockdown | 5 | 0 | 5 | 0 | 0 | 0 |  |
| event:CHAT_MSG_CHANNEL | 7 | never | SecretInChatMessagingLockdown | 5 | 0 | 5 | 0 | 0 | 0 |  |
| event:CHAT_MSG_CHANNEL | 8 | never | SecretInChatMessagingLockdown | 5 | 0 | 5 | 0 | 0 | 0 |  |
| event:CHAT_MSG_CHANNEL | 9 | never | SecretInChatMessagingLockdown | 5 | 0 | 5 | 0 | 0 | 0 |  |
| event:CHAT_MSG_CHANNEL | 10 | never | SecretInChatMessagingLockdown | 5 | 0 | 5 | 0 | 0 | 0 |  |
| event:CHAT_MSG_CHANNEL | 11 | never | SecretInChatMessagingLockdown | 5 | 0 | 5 | 0 | 0 | 0 |  |
| event:CHAT_MSG_CHANNEL | 12 | conditional | SecretInChatMessagingLockdown | 5 | 0 | 5 | 0 | 0 | 0 | verified against same-frame predicate |
| event:CHAT_MSG_CHANNEL | 13 | conditional | SecretInChatMessagingLockdown | 5 | 0 | 5 | 0 | 0 | 0 | verified against same-frame predicate |
| event:CHAT_MSG_CHANNEL | 14 | never | SecretInChatMessagingLockdown | 5 | 0 | 5 | 0 | 0 | 0 |  |
| event:CHAT_MSG_CHANNEL | 15 | never | SecretInChatMessagingLockdown | 5 | 0 | 5 | 0 | 0 | 0 |  |
| event:CHAT_MSG_CHANNEL | 16 | never | SecretInChatMessagingLockdown | 5 | 0 | 5 | 0 | 0 | 0 |  |
| event:CHAT_MSG_CHANNEL | 17 | never | SecretInChatMessagingLockdown | 5 | 0 | 5 | 0 | 0 | 0 |  |
| event:CHAT_MSG_CHANNEL | 18 | conditional | SecretInChatMessagingLockdown | 5 | 0 | 0 | 5 | 0 | 0 | verified against same-frame predicate |
| event:CURRENT_SPELL_CAST_CHANGED | 1 | none |  | 125 | 0 | 125 | 0 | 0 | 0 |  |
| event:CURSOR_CHANGED | 1 | none |  | 74 | 0 | 74 | 0 | 0 | 0 |  |
| event:CURSOR_CHANGED | 2 | none |  | 74 | 0 | 74 | 0 | 0 | 0 |  |
| event:CURSOR_CHANGED | 3 | none |  | 74 | 0 | 74 | 0 | 0 | 0 |  |
| event:CURSOR_CHANGED | 4 | none |  | 74 | 0 | 74 | 0 | 0 | 0 |  |
| event:CVAR_UPDATE | 1 | none |  | 2 | 0 | 2 | 0 | 0 | 0 |  |
| event:CVAR_UPDATE | 2 | none |  | 2 | 0 | 2 | 0 | 0 | 0 |  |
| event:DAMAGE_METER_COMBAT_SESSION_UPDATED | 1 | none |  | 608 | 0 | 608 | 0 | 0 | 0 |  |
| event:DAMAGE_METER_COMBAT_SESSION_UPDATED | 2 | none |  | 608 | 0 | 608 | 0 | 0 | 0 |  |
| event:GLOBAL_MOUSE_DOWN | 1 | none |  | 119 | 0 | 119 | 0 | 0 | 0 |  |
| event:GLOBAL_MOUSE_UP | 1 | none |  | 119 | 0 | 119 | 0 | 0 | 0 |  |
| event:GLOBAL_REGION_MOUSE_DOWN | 1 | none |  | 22 | 0 | 0 | 22 | 90 | 0 |  |
| ... 96 more in verify.json |||||||||||

## Contradictions flagged live in game (3; v2.1 flags used the old nil-as-clear rule)

- event:UNIT_AURA #1 doc conditional observed clear-while-predicate-true (combat/none/other) x49
- api:C_Spell.GetSpellCooldownDuration #1 doc unspecified observed secret (combat/none/none) x16
- event:UNIT_AURA #1 doc conditional observed clear-while-predicate-true (combat/none/self) x25
