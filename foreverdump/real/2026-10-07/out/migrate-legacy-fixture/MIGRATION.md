# Migration report: tests/legacy_addon

Against 1.60.1.70245 (toc 16001) (client TOC 16001). Mapping DB: 109 curated + 360 Blizzard_Deprecated shim entries.

## Summary

- APIs by status: deprecated-shim 1, now-secret 1, ok 3, protected 1, removed 1, renamed 1, replacement-missing 1, signature-changed 8
- call sites by status: deprecated-shim 1, now-secret 1, ok 5, protected 1, removed 1, renamed 1, replacement-missing 1, signature-changed 8
- events by status: ok 1, removed-event 1, renamed-event 1, restricted-event 1
- TOC findings: 4; taint-prone patterns: 7; secret-value flow findings: 1

## TOC

- **error** LegacyAddon.toc: ## Interface: 30400 does not include this client's 16001: the addon is listed as out of date. Set ## Interface: 16001 (a comma list like '16001, 120001' is accepted by current clients; verify on Forever)
- **warn** LegacyAddon.toc: ## Interface-Classic: 11403 is a legacy per-flavor key (BigWigs packager era); clients ignore it. Use per-flavor TOC files or a comma list in ## Interface
- **error** LegacyAddon.toc: depends on Blizzard_CombatLog_DoesNotExist, which does not exist on Forever
- **note** LegacyAddon.toc: no SavedVariables (fine if the addon keeps no state)

## API call sites

| API | status | replacement | notes | secrecy | sites |
|---|---|---|---|---|---|
| CombatLogGetCurrentEventInfo | **removed** |  | Forever restricts COMBAT_LOG_EVENT(_UNFILTERED) and has no C_CombatLog.GetCurrentEventInfo. Use UNIT_COMBAT, UNIT_SPELLCAST_*, COMBAT_TEXT_UPDATE + C_CombatText.GetCurrentEventInfo and C_DamageMeter (amounts secret in combat); offline analysis: Logs/WoWCombatLog.txt |  | LegacyAddon.lua:10 |
| CombatLogGetNumEntries | **replacement-missing** | C_CombatLog.GetEntryCount | mapped to C_CombatLog.GetEntryCount, which is NOT present in this client.  |  | LegacyAddon.lua:47 |
| GetContainerItemInfo | **signature-changed** | C_Container.GetContainerItemInfo | ContainerItemInfo {iconFileID, stackCount, isLocked, quality, isReadable, hasLoot, hyperlink, isFiltered, hasNoValue, itemID, isBound}; old: texture, count, locked, quality, readable, lootable, link, isFiltered, noValue, itemID, isBound |  | LegacyAddon.lua:19 |
| GetMouseFocus | **signature-changed** | GetMouseFoci | GetMouseFoci() returns a table of regions under the cursor (top first) |  | LegacyAddon.lua:20 |
| GetSpellCooldown | **signature-changed** | C_Spell.GetSpellCooldown | SpellCooldownInfo {startTime, duration, isEnabled (boolean), modRate}; old: start, duration, enabled (1/0), modRate | returns #1 secret (conditional); when SecretWhenCooldownsRestricted; struct fields secret: SpellCooldownInfo.startTime, SpellCooldownInfo.duration, SpellCooldownInfo.modRate, SpellCooldownInfo.activeCategory, SpellCooldownInfo.timeUntilEndOfStartRecovery | LegacyAddon.lua:22 |
| GetSpellInfo | **signature-changed** | C_Spell.GetSpellInfo | SpellInfo {name, iconID, originalIconID, castTime, minRange, maxRange, spellID}; old: name, rank, icon, castTime, minRange, maxRange, spellID, originalIcon. rank is gone. Returns nil for unknown spells. |  | LegacyAddon.lua:18 |
| InterfaceOptions_AddCategory | **signature-changed** | Settings.RegisterCanvasLayoutCategory | local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name); Settings.RegisterAddOnCategory(category) |  | LegacyAddon.lua:30 |
| IsAddOnLoaded | **signature-changed** | C_AddOns.IsAddOnLoaded | loadedOrLoading, loaded |  | LegacyAddon.lua:21 |
| SendAddonMessage | **signature-changed** | C_ChatInfo.SendAddonMessage | returns Enum.SendAddonMessageResult; outgoing addon messages can be restricted (C_ChatInfo.AreOutgoingAddonChatMessagesRestricted) | rejects secret arguments | LegacyAddon.lua:21 |
| UnitAura | **signature-changed** | C_UnitAuras.GetAuraDataByIndex | AuraData {name, icon, applications, dispelName, duration, expirationTime, sourceUnit, isStealable, spellId, auraInstanceID, isHelpful, isHarmful, ...}; AuraUtil.UnpackAuraData(aura) rebuilds the old tuple. Prefer UNIT_AURA updateInfo + C_UnitAuras.GetAuraDataByAuraInstanceID. | returns #1 secret (conditional); when SecretWhenUnitAuraRestricted | LegacyAddon.lua:24 |
| GetItemGem | **renamed** | C_Item.GetItemGem | same arguments |  | LegacyAddon.lua:45 |
| ActionHasRange | **deprecated-shim** | C_ActionBar.HasRangeRequirements | provided by Blizzard_DeprecatedActionBar/Deprecated_ActionBar.lua (forever; loads only while CVar loadDeprecationFallbacks=1) |  | LegacyAddon.lua:46 |
| CastSpellByName | **protected** |  | protected/restricted: callable only from secure code (or out of combat) |  | LegacyAddon.lua:42 |
| UnitHealth | **now-secret** |  |  | returns #1 secret (always) | LegacyAddon.lua:13 |

OK (present, no secrecy/restriction flags): CreateFrame, PlaySound, UIDropDownMenu_Initialize

### Replacement examples

- `GetContainerItemInfo` -> `local info = C_Container.GetContainerItemInfo(bag, slot); if info then local count = info.stackCount end`
- `GetMouseFocus` -> `local focus = GetMouseFoci()[1]`
- `GetSpellCooldown` -> `local cd = C_Spell.GetSpellCooldown(id); if cd and cd.duration > 0 then ... end`
- `GetSpellInfo` -> `local info = C_Spell.GetSpellInfo(id); local name, icon = info and info.name, info and info.iconID`
- `UnitAura` -> `local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, filter); if not aura then break end`

## Events

| event | status | replacement | notes | sites |
|---|---|---|---|---|
| COMBAT_LOG_EVENT_UNFILTERED | **restricted-event** |  | registering it on Forever fires ADDON_ACTION_FORBIDDEN and offers to disable the addon (pcall does not help). Use UNIT_COMBAT / UNIT_SPELLCAST_* / COMBAT_TEXT_UPDATE / C_DamageMeter. | LegacyAddon.lua:4, LegacyAddon.lua:9 |
| UNIT_HEALTH_FREQUENT | **renamed-event** | UNIT_HEALTH | merged into UNIT_HEALTH (9.0); health values are secret for many units | LegacyAddon.lua:5, LegacyAddon.lua:12 |
| PLAYER_LOGIN | ok |  |  | LegacyAddon.lua:6 |
| TOTALLY_FAKE_OLD_EVENT | **removed-event** |  | event not known to this client | LegacyAddon.lua:7 |

## Taint-prone patterns

- LegacyAddon.lua:40 [overwrites-global] redefines Blizzard global GameTooltip_ShowHyperlink: taints every Blizzard caller; use hooksecurefunc('GameTooltip_ShowHyperlink', fn)
- LegacyAddon.lua:31 [UIDropDownMenu] UIDropDownMenu_Initialize: legacy dropdowns taint the shared menu frames; use the Blizzard_Menu API (MenuUtil)
- LegacyAddon.lua:32 [PlaySound-string] PlaySound("igMainMenuOpen"): sound names were replaced by SOUNDKIT IDs (7.3)
- LegacyAddon.lua:33 [SetBackdrop] SetBackdrop needs frames created with "BackdropTemplate" (9.0+)
- LegacyAddon.lua:34 [RegisterAllEvents] RegisterAllEvents also registers restricted events (COMBAT_LOG_EVENT*) -> ADDON_ACTION_FORBIDDEN on Forever
- LegacyAddon.lua:37 [secure-attribute-unguarded] SetAttribute on a secure template without any InCombatLockdown() check in this file (blocked in combat)
- LegacyAddon.lua:38 [secure-layout-unguarded] SetPoint in a file using secure templates without InCombatLockdown(): blocked in combat (ADDON_ACTION_BLOCKED, like ClassicFishingCompanion's CFCHUDFrame:SetHeight)

## Secret-value flow (operations that error when the value is secret)

- LegacyAddon.lua:14 error comparison on a documented secret value from UnitHealth return #1 (in 'hp'): errors when the value is secret; guard with issecretvalue(v) / canaccessvalue(v)
