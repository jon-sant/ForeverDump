-- Test addon for the ForeverDump converter: a tiny damage meter driven by CLEU.
local _, ns = ...
SampleAddonDB = SampleAddonDB or {}

ns.damage, ns.events, ns.secrets, ns.encounters = {}, {}, 0, {}

local f = CreateFrame("Frame", "SampleAddonFrame", UIParent)
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("ENCOUNTER_START")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetSize(10, 10)

local tex = f:CreateTexture(nil, "ARTWORK")
tex:SetAllPoints()

local function onCLEU()
    local timestamp, subevent, _, sourceGUID, sourceName, _, _, destGUID = CombatLogGetCurrentEventInfo()
    if issecretvalue(subevent) then ns.secrets = ns.secrets + 1 return end
    ns.events[subevent] = (ns.events[subevent] or 0) + 1
    if subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" then
        local amount = select(15, CombatLogGetCurrentEventInfo())
        if issecretvalue(amount) or issecretvalue(sourceGUID) then ns.secrets = ns.secrets + 1 return end
        ns.damage[sourceGUID] = (ns.damage[sourceGUID] or 0) + amount
    elseif subevent == "SWING_DAMAGE" then
        local amount = select(12, CombatLogGetCurrentEventInfo())
        if issecretvalue(amount) or issecretvalue(sourceGUID) then ns.secrets = ns.secrets + 1 return end
        ns.damage[sourceGUID] = (ns.damage[sourceGUID] or 0) + amount
    end
    ns.last = { timestamp = timestamp, sourceName = sourceName, destGUID = destGUID }
end

f:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        onCLEU()
    elseif event == "ENCOUNTER_START" then
        local _, encounterName = ...
        ns.encounters[#ns.encounters + 1] = encounterName
    elseif event == "PLAYER_REGEN_ENABLED" then
        SampleAddonDB.lastFight = ns.damage
    end
end)
ns.frame = f
