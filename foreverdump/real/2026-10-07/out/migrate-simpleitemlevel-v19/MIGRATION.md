# Migration report: .cache/sil-v19

Against 1.60.1.70245 (toc 16001) (client TOC 16001). Mapping DB: 109 curated + 360 Blizzard_Deprecated shim entries.

## Summary

- APIs by status: ok 6, removed 2, renamed 5, signature-changed 1
- call sites by status: ok 18, removed 2, renamed 5, signature-changed 1
- events by status: ok 1
- TOC findings: 4; taint-prone patterns: 0; secret-value flow findings: 0

## TOC

- **error** SimpleItemLevel.toc: ## Interface: 100000 does not include this client's 16001: the addon is listed as out of date. Set ## Interface: 16001 (a comma list like '16001, 120001' is accepted by current clients; verify on Forever)
- **warn** SimpleItemLevel.toc: ## Interface-Wrath: 30400 is a legacy per-flavor key (BigWigs packager era); clients ignore it. Use per-flavor TOC files or a comma list in ## Interface
- **warn** SimpleItemLevel.toc: ## Interface-BCC: 20503 is a legacy per-flavor key (BigWigs packager era); clients ignore it. Use per-flavor TOC files or a comma list in ## Interface
- **warn** SimpleItemLevel.toc: ## Interface-Classic: 11403 is a legacy per-flavor key (BigWigs packager era); clients ignore it. Use per-flavor TOC files or a comma list in ## Interface

## API call sites

| API | status | replacement | notes | secrecy | sites |
|---|---|---|---|---|---|
| GetVoidItemHyperlinkString | **removed** |  | not present in this client and no known replacement |  | addon.lua:243 |
| GetVoidItemInfo | **removed** |  | not present in this client and no known replacement |  | addon.lua:239 |
| IsAddOnLoaded | **signature-changed** | C_AddOns.IsAddOnLoaded | loadedOrLoading, loaded |  | addon.lua:15 |
| GetAddOnMetadata | **renamed** | C_AddOns.GetAddOnMetadata | same arguments |  | addon.lua:2 |
| GetDetailedItemLevelInfo | **renamed** | C_Item.GetDetailedItemLevelInfo | same arguments |  | addon.lua:131 |
| GetItemInfo | **renamed** | C_Item.GetItemInfo | same tuple (itemName, itemLink, quality, itemLevel, minLevel, type, subType, stackCount, equipLoc, texture, sellPrice, classID, subclassID, bindType, expansionID, setID, isCraftingReagent); nil until GET_ITEM_INFO_RECEIVED / ITEM_DATA_LOAD_RESULT |  | addon.lua:104 |
| GetItemInfoInstant | **renamed** | C_Item.GetItemInfoInstant | same arguments |  | addon.lua:105 |
| GetItemQualityColor | **renamed** | C_Item.GetItemQualityColor | same arguments |  | addon.lua:76 |

OK (present, no secrecy/restriction flags): CreateFrame, GetInventoryItemLink, GetInventoryItemQuality, LibStub, UnitLevel, hooksecurefunc

## Events

| event | status | replacement | notes | sites |
|---|---|---|---|---|
| ADDON_LOADED | ok |  |  | addon.lua:24, addon.lua:45 |

## Taint-prone patterns

- none found

## Secret-value flow (operations that error when the value is secret)

- none found
