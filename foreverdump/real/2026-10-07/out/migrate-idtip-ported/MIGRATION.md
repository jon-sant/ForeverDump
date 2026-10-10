# Migration report: /workspace/idtip-wowforever/build/idTip

Against 1.60.1.70245 (toc 16001) (client TOC 16001). Mapping DB: 109 curated + 360 Blizzard_Deprecated shim entries.

## Summary

- APIs by status: now-secret 5, ok 16
- call sites by status: now-secret 5, ok 17
- events by status: ok 1
- TOC findings: 0; taint-prone patterns: 0; secret-value flow findings: 0

## TOC


## API call sites

| API | status | replacement | notes | secrecy | sites |
|---|---|---|---|---|---|
| C_UnitAuras.GetAuraDataByAuraInstanceID | **now-secret** |  |  | returns #1 secret (conditional); when SecretWhenUnitAuraRestricted | idTip.lua:324 |
| C_UnitAuras.GetAuraDataByIndex | **now-secret** |  |  | returns #1 secret (conditional); when SecretWhenUnitAuraRestricted | idTip.lua:325 |
| C_UnitAuras.GetBuffDataByIndex | **now-secret** |  |  | returns #1 secret (conditional); when SecretWhenUnitAuraRestricted | idTip.lua:326 |
| C_UnitAuras.GetDebuffDataByIndex | **now-secret** |  |  | returns #1 secret (conditional); when SecretWhenUnitAuraRestricted | idTip.lua:326 |
| UnitGUID | **now-secret** |  |  | returns #1 secret (conditional); when SecretWhenUnitIdentityRestricted | idTip.lua:318 |

OK (present, no secrecy/restriction flags): C_CurrencyInfo.GetCurrencyListLink, C_PetBattles.GetAbilityInfo, C_PetBattles.GetActivePet, C_PetBattles.GetAuraInfo, C_PetBattles.IsInBattle, C_PetJournal.GetPetInfoByPetID, C_PetJournal.GetPetInfoBySpeciesID, C_QuestLog.GetQuestIDForLogIndex, CreateFrame, CreateSettingsListSectionHeaderInitializer, GetAchievementCriteriaInfo, GetAchievementNumCriteria, GetActionInfo, hooksecurefunc, issecrettable, issecretvalue

## Events

| event | status | replacement | notes | sites |
|---|---|---|---|---|
| ADDON_LOADED | ok |  |  | idTip.lua:582 |

## Taint-prone patterns

- none found

## Secret-value flow (operations that error when the value is secret)

- none found
