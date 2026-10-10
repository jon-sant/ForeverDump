-- Forever-style combat handling (no CLEU): UNIT_COMBAT, UNIT_SPELLCAST_SUCCEEDED, COMBAT_TEXT_UPDATE.
local _, ns = ...
ns.forever = { unitCombat = 0, wound = 0, heal = 0, secretAmounts = 0, casts = 0, combatText = 0, secretText = 0 }

local f = CreateFrame("Frame")
f:RegisterEvent("UNIT_COMBAT")
f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
f:RegisterEvent("COMBAT_TEXT_UPDATE")
f:SetScript("OnEvent", function(_, event, ...)
    local s = ns.forever
    if event == "UNIT_COMBAT" then
        local _, action, _, amount = ...
        s.unitCombat = s.unitCombat + 1
        if issecretvalue(amount) then s.secretAmounts = s.secretAmounts + 1
        elseif action == "HEAL" then s.heal = s.heal + amount
        else s.wound = s.wound + amount end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        s.casts = s.casts + 1
    elseif event == "COMBAT_TEXT_UPDATE" then
        s.combatText = s.combatText + 1
        local first = C_CombatText.GetCurrentEventInfo()
        if issecretvalue(first) then s.secretText = s.secretText + 1 end
    end
end)
ns.foreverFrame = f
