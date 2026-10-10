-- Intentionally wrong API usage for `fdump.py check` (never executed).
local _, ns = ...
function ns.NeverCalled()
    local start, duration = C_Item.GetItemCooldown(6948)          -- documented but missing in the mock client
    local x = C_TotallyBogus.DoThing()                            -- namespace does not exist
    local q = Enum.ItemQuality.Mythical                           -- enum value does not exist
    local b = CreateFrame("Button", nil, UIParent)
    b:SetTotallyMadeUpMethod(true)                                -- not a Button method
    local blob = CreateFrame("NotAWidgetType")                    -- not creatable
    b:RegisterEvent("NOT_A_REAL_EVENT")                           -- unknown event
    UnknownGlobalHelper(start, duration, x, q, blob)              -- unknown global (warning)
    local name = UnitName("target")                               -- fine
    return name, C_UnitAuras.GetAuraDataByIndex("target", 1)       -- restricted/secret note
end
