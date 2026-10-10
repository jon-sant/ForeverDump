-- K.T.H. Forever - Core/Driver.lua
-- Reads only signals that are clear on Forever (1.60.1 / toc 16001) in battlegrounds:
--   UnitName / UnitCanAttack / UnitIsPlayer / UnitIsUnit / UnitPowerType on any unit token,
--   UNIT_SPELLCAST_SUCCEEDED delivery (spellID usually secret -> only used when clear),
--   UNIT_COMBAT action ("HEAL"/"WOUND"; amount is never read),
--   GetBattlefieldScore positions 1 (name), 6 (faction), 8 (class), 9 (classToken),
--   C_PvP.GetScoreInfo table fields only when the table is readable (post-match / ooc).
-- Secret signals (UnitClass, UnitGUID, score 2-5 & 10-12, most spellIDs) are never compared or keyed.
local ADDON, ns = ...
local S, E = ns.S, ns.E
local D = {}
ns.D = D

local GetTime, type, pairs, ipairs = GetTime, type, pairs, ipairs
local str, num, bool, call = S.str, S.num, S.bool, S.call

D.frame = CreateFrame("Frame", "KTHForeverEventFrame")
D.inBG = false
D.probes = nil

-------------------------------------------------------------------------------- identity
-- ident(token) -> engine record or nil. Never touches UnitClass/UnitGUID (secret on Forever plates).
local identCache, identT = {}, -1
function D.ident(tok)
    tok = str(tok)
    if not tok then return nil end
    local t = GetTime()
    if t ~= identT then identT = t; for k in pairs(identCache) do identCache[k] = nil end end
    local c = identCache[tok]
    if c ~= nil then return c or nil end
    local rec = false
    if bool(call(UnitIsPlayer, tok)) and not bool(call(UnitIsUnit, tok, "player")) then
        local name = S.firstWord(call(UnitName, tok))
        local enemy = bool(call(UnitCanAttack, "player", tok))
        if name and enemy ~= nil then
            rec = E.get(enemy and "E" or "F", name)
            local _, ptok = call(UnitPowerType, tok)
            ptok = str(ptok)
            if ptok then E.power(rec, ptok == "MANA") end
        end
    end
    identCache[tok] = rec
    return rec or nil
end

-------------------------------------------------------------------------------- frame-join
-- All events of one client frame share one GetTime(). A cast SUCCEEDED by exactly one identity in a frame
-- plus a HEAL on another same-side player in that frame = one heal-on-other link (WOUND on the other side
-- = one damage link). Several casters in one frame = ambiguous, nothing is attributed.
local B = { t = nil, casters = {}, n = 0, heals = {}, wounds = {} }
function D.flush()
    if B.t and B.n > 0 then E.join(B.t, B.casters, B.n, B.heals, B.wounds) end
    B.t = nil; B.n = 0
    for k in pairs(B.casters) do B.casters[k] = nil end
    for i = #B.heals, 1, -1 do B.heals[i] = nil end
    for i = #B.wounds, 1, -1 do B.wounds[i] = nil end
end
local function bucket()
    local t = GetTime()
    if B.t ~= t then D.flush(); B.t = t end
    return t
end

local sigName = {}
local function spellEvidence(rec, spellID, t)
    spellID = num(spellID)
    if not spellID then return end
    if D.probes then D.probes.clearSpellOther = (D.probes.clearSpellOther or 0) + 1 end
    local H = ns.HealSpells
    local name = str(call(C_Spell and C_Spell.GetSpellName, spellID))
    if (H.signatureIds[spellID]) or (name and sigName[name]) then
        E.direct(rec, t, "signature " .. (name or spellID), 1)
    end
end

function D.onCast(tok, spellID)
    if not D.inBG and not (ns.db and ns.db.anywhere) then return end
    local rec = D.ident(tok)
    if not rec then return end
    local t = bucket()
    if not B.casters[rec.key] then B.casters[rec.key] = rec; B.n = B.n + 1 end
    spellEvidence(rec, spellID, t)
end

function D.onCombat(tok, action)
    if not D.inBG and not (ns.db and ns.db.anywhere) then return end
    action = str(action)
    if action ~= "HEAL" and action ~= "WOUND" then return end
    local rec = D.ident(tok)
    if not rec then return end
    bucket()
    local L = action == "HEAL" and B.heals or B.wounds
    for _, r in ipairs(L) do if r == rec then return end end
    L[#L + 1] = rec
end

-------------------------------------------------------------------------------- scoreboard
local classMap
local function localizedClassMap()
    if classMap then return classMap end
    classMap = {}
    for _, tbl in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
        for tokn, loc in pairs(tbl) do if type(loc) == "string" then classMap[loc] = tokn end end
    end
    local n = num(call(GetNumClasses)) or 0
    for i = 1, n do
        local loc, tokn = call(GetClassInfo, i)
        loc, tokn = str(loc), str(tokn)
        if loc and tokn then classMap[loc] = tokn end
    end
    return classMap
end

function D.myFaction()
    local f = num(call(GetBattlefieldArenaFaction))
    if f then return f end
    local g = str(call(UnitFactionGroup, "player"))
    if g == "Horde" then return 0 elseif g == "Alliance" then return 1 end
end

function D.sweep()
    local t = GetTime()
    local mine = D.myFaction()
    local n = num(call(GetNumBattlefieldScores)) or 0
    local P = D.probes
    for i = 1, n do
        local cnt, name, _, _, _, _, faction, _, class, classToken = S.callAll(GetBattlefieldScore, i)
        if cnt > 0 then
            local full = str(name)
            local first = S.firstWord(full)
            faction = num(faction)
            local ct = str(classToken) or localizedClassMap()[str(class) or ""]
            if first and faction and mine then
                E.rosterRow(faction == mine and "F" or "E", first, full, ct, t)
            end
            if P then
                P.scoreRows = (P.scoreRows or 0) + 1
                if not full then P.scoreNameSecret = (P.scoreNameSecret or 0) + 1 end
                if not ct then P.scoreClassSecret = (P.scoreClassSecret or 0) + 1 end
            end
            -- readable score table (post-match / some ooc sweeps): healing vs damage is direct evidence
            local info = C_PvP and C_PvP.GetScoreInfo and S.tbl(call(C_PvP.GetScoreInfo, i))
            if info and first and faction and mine then
                local heal, dmg = num(info.healingDone), num(info.damageDone)
                if P then P.scoreInfoClear = (P.scoreInfoClear or 0) + 1 end
                if heal and dmg and heal > 0 and heal >= dmg then
                    local rec = E.get(faction == mine and "F" or "E", first)
                    E.direct(rec, t, "scoreboard healing", 1)
                end
            elseif P then
                P.scoreInfoSecret = (P.scoreInfoSecret or 0) + 1
            end
        end
    end
end

-------------------------------------------------------------------------------- zone
function D.updateZone()
    local inInst, kind = call(IsInInstance)
    kind = str(kind)
    local was = D.inBG
    D.inBG = (bool(inInst) and kind == "pvp") or false
    if D.inBG and not was then
        E.reset(); D.flush()
        ns.db.probes = ns.db.probes or {}
        D.probes = { start = GetTime() }
        ns.db.probes[#ns.db.probes + 1] = D.probes
        while #ns.db.probes > 20 do table.remove(ns.db.probes, 1) end
        call(RequestBattlefieldScoreData)
        ns.msg("Battleground detected - watching for healers.")
    elseif was and not D.inBG then
        if D.probes then D.probes.stats = E.stats; D.probes.claims = #E.healers() end
        D.probes = nil
    end
    if ns.UI then ns.UI.refresh() end
end

-------------------------------------------------------------------------------- events
local ev = {}
function ev.ADDON_LOADED(name)
    if name ~= ADDON then return end
    KTH_ForeverDB = KTH_ForeverDB or {}
    ns.db = KTH_ForeverDB
    local H = ns.HealSpells
    for _, n in ipairs(H.signatureNames) do sigName[n] = true end
    for k, v in pairs(ns.DEFAULTS) do if ns.db[k] == nil then ns.db[k] = v end end
    for k, v in pairs(ns.db.cfg or {}) do if E.CFG[k] ~= nil then E.CFG[k] = v end end
    if ns.UI then ns.UI.init() end
end
function ev.PLAYER_ENTERING_WORLD() D.updateZone() end
ev.ZONE_CHANGED_NEW_AREA = ev.PLAYER_ENTERING_WORLD
function ev.UPDATE_BATTLEFIELD_SCORE() if D.inBG then D.sweep() end end
function ev.UNIT_SPELLCAST_SUCCEEDED(unit, _, spellID) D.onCast(unit, spellID) end
function ev.UNIT_COMBAT(unit, action) D.onCombat(unit, action) end
function ev.NAME_PLATE_UNIT_ADDED(unit) if ns.UI then ns.UI.plateAdded(unit) end end
function ev.NAME_PLATE_UNIT_REMOVED(unit) if ns.UI then ns.UI.plateRemoved(unit) end end
function ev.PLAYER_TARGET_CHANGED() if ns.UI then ns.UI.targetChanged() end end

D.events = ev
D.frame:SetScript("OnEvent", function(_, event, ...)
    local f = ev[event]
    if f then
        local ok, err = pcall(f, ...)
        if not ok and ns.debug then ns.debug("event " .. event .. ": " .. tostring(err)) end
    end
end)
for e in pairs(ev) do D.frame:RegisterEvent(e) end
D.frame:SetScript("OnUpdate", function()
    if B.t and B.t ~= GetTime() then D.flush() end
end)

E.listeners[#E.listeners + 1] = function(rec, claim)
    if ns.UI then ns.UI.onClaim(rec, claim) end
end

-- periodic: scoreboard refresh (10 s) and plate rescan (1 s)
local acc10 = 0
function D.tick()
    if not D.inBG then return end
    acc10 = acc10 + 1
    if acc10 >= 10 then acc10 = 0; call(RequestBattlefieldScoreData) end
    if ns.UI then ns.UI.rescan() end
end
if C_Timer and C_Timer.NewTicker then D.ticker = C_Timer.NewTicker(1, D.tick) end
