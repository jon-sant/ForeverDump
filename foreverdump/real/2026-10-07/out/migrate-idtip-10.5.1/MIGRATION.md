# Migration report: .cache/idtip-10.5.1

Against 1.60.1.70245 (toc 16001) (client TOC 16001). Mapping DB: 109 curated + 360 Blizzard_Deprecated shim entries.

## Summary

- APIs by status: now-secret 1, ok 16, removed 3, renamed 1, signature-changed 6
- call sites by status: now-secret 2, ok 17, removed 3, renamed 2, signature-changed 10
- events by status: ok 1
- TOC findings: 5; taint-prone patterns: 0; secret-value flow findings: 3

## TOC

- **error** idTip.toc: ## Interface: 100100 does not include this client's 16001: the addon is listed as out of date. Set ## Interface: 16001 (a comma list like '16001, 120001' is accepted by current clients; verify on Forever)
- **warn** idTip.toc: ## Interface-Classic: 11403 is a legacy per-flavor key (BigWigs packager era); clients ignore it. Use per-flavor TOC files or a comma list in ## Interface
- **warn** idTip.toc: ## Interface-BCC: 20504 is a legacy per-flavor key (BigWigs packager era); clients ignore it. Use per-flavor TOC files or a comma list in ## Interface
- **warn** idTip.toc: ## Interface-Wrath: 30400 is a legacy per-flavor key (BigWigs packager era); clients ignore it. Use per-flavor TOC files or a comma list in ## Interface
- **note** idTip.toc: no SavedVariables (fine if the addon keeps no state)

## API call sites

| API | status | replacement | notes | secrecy | sites |
|---|---|---|---|---|---|
| C_TradeSkillUI.GetRecipeReagentItemLink | **removed** |  | not present in this client and no known replacement |  | idTip.lua:308 |
| GetGlyphSocketInfo | **removed** |  | not present in this client and no known replacement |  | idTip.lua:4 |
| SpellBook_GetSpellBookSlot | **removed** |  | not present in this client and no known replacement |  | idTip.lua:202 |
| GetMouseFocus | **signature-changed** | GetMouseFoci | GetMouseFoci() returns a table of regions under the cursor (top first) |  | idTip.lua:304, idTip.lua:307 |
| GetSpellBookItemInfo | **signature-changed** | C_SpellBook.GetSpellBookItemInfo | SpellBookItemInfo {actionID, spellID, itemType (Enum.SpellBookItemType), name, subName, iconID, isPassive, isOffSpec, skillLineIndex}; bookType string -> Enum.SpellBookSpellBank |  | idTip.lua:203 |
| GetSpellInfo | **signature-changed** | C_Spell.GetSpellInfo | SpellInfo {name, iconID, originalIconID, castTime, minRange, maxRange, spellID}; old: name, rank, icon, castTime, minRange, maxRange, spellID, originalIcon. rank is gone. Returns nil for unknown spells. |  | idTip.lua:75 |
| UnitAura | **signature-changed** | C_UnitAuras.GetAuraDataByIndex | AuraData {name, icon, applications, dispelName, duration, expirationTime, sourceUnit, isStealable, spellId, auraInstanceID, isHelpful, isHarmful, ...}; AuraUtil.UnpackAuraData(aura) rebuilds the old tuple. Prefer UNIT_AURA updateInfo + C_UnitAuras.GetAuraDataByAuraInstanceID. | returns #1 secret (conditional); when SecretWhenUnitAuraRestricted | idTip.lua:3, idTip.lua:182 |
| UnitBuff | **signature-changed** | C_UnitAuras.GetBuffDataByIndex | AuraData (see UnitAura) | returns #1 secret (conditional); when SecretWhenUnitAuraRestricted | idTip.lua:3, idTip.lua:170 |
| UnitDebuff | **signature-changed** | C_UnitAuras.GetDebuffDataByIndex | AuraData (see UnitAura) | returns #1 secret (conditional); when SecretWhenUnitAuraRestricted | idTip.lua:3, idTip.lua:176 |
| GetItemGem | **renamed** | C_Item.GetItemGem | same arguments |  | idTip.lua:292, idTip.lua:294 |
| UnitGUID | **now-secret** |  |  | returns #1 secret (conditional); when SecretWhenUnitIdentityRestricted | idTip.lua:3, idTip.lua:252 |

OK (present, no secrecy/restriction flags): C_ArtifactUI.GetPowerInfo, C_CurrencyInfo.GetCurrencyListLink, C_Item.GetItemIconByID, C_PetBattles.GetAbilityInfo, C_PetBattles.GetActivePet, C_PetBattles.GetAuraInfo, C_PetBattles.IsInBattle, C_PetJournal.GetPetInfoByPetID, C_PetJournal.GetPetInfoBySpeciesID, C_QuestLog.GetQuestIDForLogIndex, CreateFrame, GetAchievementCriteriaInfo, GetActionInfo, GetPvpTalentInfoByID, GetTalentInfoByID, hooksecurefunc

### Replacement examples

- `GetMouseFocus` -> `local focus = GetMouseFoci()[1]`
- `GetSpellInfo` -> `local info = C_Spell.GetSpellInfo(id); local name, icon = info and info.name, info and info.iconID`
- `UnitAura` -> `local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, filter); if not aura then break end`

## Events

| event | status | replacement | notes | sites |
|---|---|---|---|---|
| ADDON_LOADED | ok |  |  | idTip.lua:334 |

## Taint-prone patterns

- none found

## Secret-value flow (operations that error when the value is secret)

- idTip.lua:252 warn boolean test on a conditionally secret value from UnitGUID return #1: errors when the value is secret; guard with issecretvalue(v) / canaccessvalue(v)
- idTip.lua:253 note string method on a possibly secret value from UnitGUID return #1 (in 'guid'): allowed, but the result is a secret string (no compare/length/parse); guard with issecretvalue(v) / canaccessvalue(v)
- idTip.lua:254 warn boolean test on a conditionally secret value from UnitGUID return #1 (in 'guid'): errors when the value is secret; guard with issecretvalue(v) / canaccessvalue(v)
