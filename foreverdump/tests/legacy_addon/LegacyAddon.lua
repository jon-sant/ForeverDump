-- Deliberately legacy (2018-2022 style) code: every line exercises a migrate status. Not meant to run.
-- luacheck: ignore  (deliberately legacy migration fixture; excluded from the luacheck run)
local f = CreateFrame("Frame", "LegacyAddonFrame", UIParent)
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("UNIT_HEALTH_FREQUENT")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("TOTALLY_FAKE_OLD_EVENT")
f:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, sub, _, src, _, _, _, dst, _, _, _, spellId, _, _, amount = CombatLogGetCurrentEventInfo()
        if amount and amount > 1000 then print("big hit") end
    elseif event == "UNIT_HEALTH_FREQUENT" then
        local hp = UnitHealth("target")
        if hp < 100 then print("execute!") end
    end
end)

local name, rank, icon = GetSpellInfo(133)
local texture, count = GetContainerItemInfo(0, 1)
local focus = GetMouseFocus()
if IsAddOnLoaded("Details") then SendAddonMessage("LEG", "hi", "PARTY") end
local start, duration = GetSpellCooldown(133)
for i = 1, 40 do
    local aname, _, _, _, _, expires = UnitAura("player", i, "HELPFUL")
    if not aname then break end
end

local panel = CreateFrame("Frame")
panel.name = "LegacyAddon"
InterfaceOptions_AddCategory(panel)
UIDropDownMenu_Initialize(panel, function() end)
PlaySound("igMainMenuOpen")
panel:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
f:RegisterAllEvents()

local btn = CreateFrame("Button", "LegacyCastButton", UIParent, "SecureActionButtonTemplate")
btn:SetAttribute("type", "spell")
btn:SetPoint("CENTER")

function GameTooltip_ShowHyperlink(...) print("replaced a Blizzard global") end

local function nuke() CastSpellByName("Fireball") end

-- more statuses: renamed alias, deprecated shim (present only via loadDeprecationFallbacks), replacement missing on Forever
local gemName, gemLink = GetItemGem(19019, 1)
local hasRange = ActionHasRange(1)
local entries = CombatLogGetNumEntries()
