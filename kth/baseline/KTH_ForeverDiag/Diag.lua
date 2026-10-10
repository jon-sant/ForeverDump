-- K.T.H. Forever Diagnostics: a read-only probe that runs alongside UNMODIFIED K.T.H. on WoW Forever.
-- It never writes to Blizzard chat frames. Output: its own message frame (/kthfd) and SavedVariables KTHForeverDiagDB.
-- Readability codes: C = clear, S = secret value, T = secret table, N = nil, E = the call raised an error.
-- Raw clear values are stored as-is (not hashed or scrubbed).
local ADDON = ...
local DB
local issecretvalue, issecrettable, canaccesstable = issecretvalue, issecrettable, canaccesstable
local type, pcall, select, tostring, GetTime = type, pcall, select, tostring, GetTime

local function code(v)
    local t = type(v)
    if t == "nil" then return "N" end
    if t == "table" and issecrettable then
        local ok, s = pcall(issecrettable, v)
        if ok and s then return "T" end
        if canaccesstable then local ok2, a = pcall(canaccesstable, v); if ok2 and not a then return "T" end end
    end
    if issecretvalue then
        local ok, s = pcall(issecretvalue, v)
        if not ok or s then return "S" end
    end
    return "C"
end
local function clear(v) if code(v) == "C" then return v end end

-------------------------------------------------------------------------------- own frame
local F
local pend = {}
local function out(msg)
    if F then pcall(F.AddMessage, F, "|cff66ccffKTH-FD|r " .. msg) else pend[#pend + 1] = msg end
end
local function makeFrame()
    F = CreateFrame("ScrollingMessageFrame", "KTHForeverDiagFrame", UIParent)
    F:SetSize(560, 160); F:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 220)
    for _, c in ipairs({ { "SetFontObject", GameFontHighlightSmall }, { "SetJustifyH", "LEFT" }, { "SetFading", true },
                         { "SetTimeVisible", 20 }, { "SetMaxLines", 300 }, { "SetInsertMode", "BOTTOM" } }) do
        if F[c[1]] then pcall(F[c[1]], F, c[2]) end
    end
    F:SetMovable(true); F:EnableMouse(true); F:RegisterForDrag("LeftButton")
    F:SetScript("OnDragStart", F.StartMoving); F:SetScript("OnDragStop", F.StopMovingOrSizing)
    F:EnableMouseWheel(true)
    F:SetScript("OnMouseWheel", function(s, d) if d > 0 then s:ScrollUp() else s:ScrollDown() end end)
    for _, m in ipairs(pend) do out(m) end
    pend = {}
end

-------------------------------------------------------------------------------- counters
-- BG phase: world | prep (gates closed) | ooc (gates open, out of combat) | combat | post (match over)
-- Sources (all pcall + readability-gated): IsInInstance, C_PvP.GetActiveMatchState (Enum.PvPMatchState), GetBattlefieldWinner,
-- InCombatLockdown. Raw matchState / winner are stored in the samples so the phase rule can be re-derived offline.
local function players()
    local ok, n = pcall(GetNumBattlefieldScores)
    return (ok and code(n) == "C") and n or -1
end
local function rawPhase()
    local okI, inInst, kind = pcall(IsInInstance)
    local ms, win
    if C_PvP and C_PvP.GetActiveMatchState then local ok, v = pcall(C_PvP.GetActiveMatchState); ms = ok and clear(v) or nil end
    if GetBattlefieldWinner then local ok, v = pcall(GetBattlefieldWinner); win = ok and clear(v) or nil end
    return okI and clear(kind) or nil, ms, win
end
local function phase()
    local kind, ms, win = rawPhase()
    if kind ~= "pvp" then return "world" end
    local S = Enum and Enum.PvPMatchState
    if win ~= nil then return "post" end
    if S and ms ~= nil then
        if ms == S.PostRound or ms == S.Complete then return "post" end
        if ms == S.Waiting or ms == S.StartUp then return "prep" end
    end
    if InCombatLockdown and InCombatLockdown() then return "combat" end
    return "ooc"
end
local function ctx() return phase() .. "|p" .. players() end
local function bump(tbl, key, c)
    local k = key .. "|" .. ctx()
    local e = tbl[k]; if not e then e = {}; tbl[k] = e end
    e[c] = (e[c] or 0) + 1
end
local function sample(list, max, row) if #list < max then list[#list + 1] = row end end

-------------------------------------------------------------------------------- errors (chained, never swallowed)
local function hookErrors()
    local orig = geterrorhandler()
    seterrorhandler(function(msg, ...)
        if DB then
            local s = type(msg) == "string" and msg or tostring(code(msg))
            local mine = s:find("KTH", 1, true) or s:find("HHTD", 1, true) or s:find("K.T.H", 1, true)
            DB.errors[#DB.errors + 1] = { t = time(), ctx = ctx(), kth = mine and true or false, msg = s:sub(1, 600),
                stack = debugstack and debugstack(2, 8, 4) or nil }
            while #DB.errors > 200 do table.remove(DB.errors, 1) end
            if mine then out("|cffff4040Lua error|r " .. s:sub(1, 200)) end
        end
        return orig(msg, ...)
    end)
end

-------------------------------------------------------------------------------- KTH branch + state
local function kth()
    local ok, a = pcall(function() return LibStub("AceAddon-3.0"):GetAddon("K.T.H.", true) end)
    return ok and a or nil
end
local function branch()
    local H = kth()
    local _, build, _, toc = GetBuildInfo()
    local b = { at = time(), toc = toc, build = build, project = WOW_PROJECT_ID, kthLoaded = H ~= nil }
    if H then
        local C = H.Constants or {}
        b.MN = C.MN; b.WOWC = C.WOWC
        b.MNP = H.MNP_GetStatus ~= nil                  -- MidnightNameplates.lua ran past its MN guard
        b.status = H.MNP_GetStatus and select(2, pcall(H.MNP_GetStatus)) or nil
        b.enabled = H.IsEnabled and H:IsEnabled() or nil
        b.healerSpells = 0
        for _ in pairs(C.Healers_Only_Spells_ByID_Lookup or {}) do b.healerSpells = b.healerSpells + 1 end
        b.mnCount = H.MN_HealerCount and { enemy = H.MN_HealerCount.enemy, friendly = H.MN_HealerCount.friendly } or nil
        b.diag = {}
        for k, v in pairs(H.MN_Diag or {}) do if type(v) ~= "table" then b.diag[k] = v end end
        b.regE, b.regF = 0, 0
        for _ in pairs((H.Registry_by_GUID or {})[false] or {}) do b.regE = b.regE + 1 end
        for _ in pairs((H.Registry_by_GUID or {})[true] or {}) do b.regF = b.regF + 1 end
        b.cleuRegistered = H.IsEventRegistered and select(2, pcall(H.IsEventRegistered, H, "COMBAT_LOG_EVENT_UNFILTERED")) or nil
    end
    b.C_CombatLogInternal = C_CombatLogInternal ~= nil
    b.CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo ~= nil
    b.canaccessvalue = canaccessvalue ~= nil
    return b
end

-- count K.T.H. chat output (HHTD:Print goes to DEFAULT_CHAT_FRAME in the unmodified addon)
local function hookPrint()
    local H = kth()
    if not H or DB.printHooked then return end
    if H.Print then
        hooksecurefunc(H, "Print", function(_, ...)
            local parts = {}
            for i = 1, select("#", ...) do local v = select(i, ...); parts[#parts + 1] = code(v) == "C" and tostring(v) or code(v) end
            DB.kthPrints[#DB.kthPrints + 1] = { t = time(), ctx = ctx(), text = table.concat(parts, " "):sub(1, 300) }
            while #DB.kthPrints > 100 do table.remove(DB.kthPrints, 1) end
        end)
    end
end

-------------------------------------------------------------------------------- unit probes
local function probeUnit(tok)
    local okP, isPlayer = pcall(UnitIsPlayer, tok)
    if not okP or code(isPlayer) ~= "C" or not isPlayer then return end
    local okA, canAttack = pcall(UnitCanAttack, "player", tok)
    local side = (okA and code(canAttack) == "C") and (canAttack and "enemy" or "friend") or ("side" .. (okA and code(canAttack) or "E"))
    local fam = tok:gsub("%d+$", "N")
    local key = fam .. ":" .. side
    local U = DB.units
    local function rec(name, ...)
        local ok = select(1, ...)
        if not ok then bump(U, key .. ":" .. name, "E"); return end
        for i = 2, select("#", ...) do bump(U, key .. ":" .. name .. "." .. (i - 1), code((select(i, ...)))) end
    end
    rec("UnitName", pcall(UnitName, tok))
    rec("UnitGUID", pcall(UnitGUID, tok))
    rec("UnitClass", pcall(UnitClass, tok))
    rec("UnitPowerType", pcall(UnitPowerType, tok))
    rec("UnitIsFriend", pcall(UnitIsFriend, tok, "player"))
    rec("UnitCanAttack", okA, canAttack)
    rec("UnitHealthMax", pcall(UnitHealthMax, tok))
    -- raw sample of what was readable (store raw)
    local n, g, c1, c2, pt, ptok = select(2, pcall(UnitName, tok)), select(2, pcall(UnitGUID, tok)),
        select(2, pcall(UnitClass, tok)), select(3, pcall(UnitClass, tok)), select(2, pcall(UnitPowerType, tok)), select(3, pcall(UnitPowerType, tok))
    local kind, ms, win = rawPhase()
    sample(DB.unitSamples, 300, { t = time(), ctx = ctx(), matchState = ms, winner = win, tok = tok, side = side, name = clear(n), guid = clear(g),
        class = clear(c1), classToken = clear(c2), powerType = clear(pt), powerToken = clear(ptok) })
end

local function scanPlates()
    for i = 1, 40 do
        local tok = "nameplate" .. i
        local ok, ex = pcall(UnitExists, tok)
        if ok and code(ex) == "C" and ex then probeUnit(tok) end
    end
end

-------------------------------------------------------------------------------- scoreboard probes
local SCORE_FIELDS = { "name", "guid", "classToken", "className", "talentSpec", "roleAssigned", "faction", "race",
    "killingBlows", "honorableKills", "deaths", "honorGained", "damageDone", "healingDone", "rating", "bgRating" }
local function probeScore()
    local okN, n = pcall(GetNumBattlefieldScores)
    bump(DB.score, "GetNumBattlefieldScores", okN and code(n) or "E")
    if not okN or code(n) ~= "C" then return end
    for i = 1, n do
        local r = { pcall(GetBattlefieldScore, i) }
        if r[1] then
            local row = {}
            for p = 2, math.min(#r, 20) do
                bump(DB.score, "GetBattlefieldScore." .. (p - 1), code(r[p]))
                row[p - 1] = clear(r[p])
            end
            row.n = #r - 1
            local _, ms, win = rawPhase()
            sample(DB.scoreRows, 400, { t = time(), ctx = ctx(), matchState = ms, winner = win, i = i, vals = row })
        else
            bump(DB.score, "GetBattlefieldScore", "E")
        end
        if C_PvP and C_PvP.GetScoreInfo then
            local ok, info = pcall(C_PvP.GetScoreInfo, i)
            local c = ok and code(info) or "E"
            bump(DB.score, "GetScoreInfo", c)
            -- per-field codes are recorded for EVERY returned table, including tables flagged secret ("T"): a flagged
            -- table can still hold clear fields. Indexing is pcall'd; an index error is recorded as "E".
            if ok and (type(info) == "table" or type(info) == "userdata") then
                local raw = { _tableCode = c }
                for _, f in ipairs(SCORE_FIELDS) do
                    local okf, v = pcall(function() return info[f] end)
                    bump(DB.score, "GetScoreInfo." .. f .. "@" .. c, okf and code(v) or "E")
                    raw[f] = okf and clear(v) or nil
                end
                local _, ms, win = rawPhase()
                sample(DB.scoreInfoRows, 400, { t = time(), ctx = ctx(), matchState = ms, winner = win, i = i, vals = raw })
            end
        end
    end
end

-------------------------------------------------------------------------------- events
local fr = CreateFrame("Frame")
local events = { "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "NAME_PLATE_UNIT_ADDED", "UPDATE_BATTLEFIELD_SCORE",
    "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }
for _, e in ipairs(events) do pcall(fr.RegisterEvent, fr, e) end
local lastSpell = {}
fr:SetScript("OnEvent", function(_, event, a1, a2, a3)
    if event == "ADDON_LOADED" and a1 == ADDON then
        KTHForeverDiagDB = KTHForeverDiagDB or {}
        DB = KTHForeverDiagDB
        DB.sessions = DB.sessions or {}
        DB.errors, DB.kthPrints = DB.errors or {}, DB.kthPrints or {}
        DB.units, DB.unitSamples, DB.score, DB.scoreRows, DB.scoreInfoRows = {}, {}, {}, {}, {}
        DB.spells, DB.blocked = {}, {}
        hookErrors()
        return
    end
    if not DB then return end
    if event == "PLAYER_LOGIN" then
        makeFrame()
        hookPrint()
        local b = branch()
        DB.sessions[#DB.sessions + 1] = b
        while #DB.sessions > 30 do table.remove(DB.sessions, 1) end
        out(("toc=%s build=%s project=%s KTH=%s MN=%s WOWC=%s MidnightNameplates=%s CLEUgetter=%s/%s"):format(
            tostring(b.toc), tostring(b.build), tostring(b.project), tostring(b.kthLoaded), tostring(b.MN), tostring(b.WOWC),
            tostring(b.MNP), tostring(b.CombatLogGetCurrentEventInfo), tostring(b.C_CombatLogInternal)))
    elseif event == "PLAYER_ENTERING_WORLD" then
        local inInst, kind = IsInInstance()
        DB.lastZone = { t = time(), inInstance = clear(inInst), kind = clear(kind) }
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        pcall(probeUnit, a1)
    elseif event == "UPDATE_BATTLEFIELD_SCORE" then
        local ok, err = pcall(probeScore)
        if not ok then DB.errors[#DB.errors + 1] = { t = time(), probe = true, msg = tostring(err) } end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local fam = type(a1) == "string" and a1:gsub("%d+$", "N") or code(a1)
        bump(DB.spells, fam .. ":spellID", code(a3))
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        DB.blocked[#DB.blocked + 1] = { t = time(), event = event, addon = clear(a1), func = clear(a2) }
        out("|cffff4040" .. event .. "|r " .. tostring(clear(a1)) .. " " .. tostring(clear(a2)))
    end
end)
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(2, function()
        if not DB then return end
        local inInst, kind = IsInInstance()
        if clear(kind) == "pvp" then pcall(scanPlates) end
        DB.phaseNow = { t = time(), ctx = ctx() }
        -- request fresh scoreboard data every 10 s while in a BG (the same call K.T.H.'s MN path makes) so the
        -- scoreboard is probed even when the unmodified K.T.H. takes the non-MN branch and never asks for it
        DB._tick = (DB._tick or 0) + 1
        if clear(kind) == "pvp" and DB._tick % 5 == 0 and RequestBattlefieldScoreData then pcall(RequestBattlefieldScoreData) end
    end)
end

-------------------------------------------------------------------------------- slash
local function summary()
    local b = branch()
    DB.sessions[#DB.sessions + 1] = b
    out(("MN=%s MidnightNameplates=%s enabled=%s %s regE=%d regF=%d CLEUreg=%s errors=%d kthPrints=%d"):format(
        tostring(b.MN), tostring(b.MNP), tostring(b.enabled), tostring(b.status or ""), b.regE or 0, b.regF or 0,
        tostring(b.cleuRegistered), #DB.errors, #DB.kthPrints))
    for _, k in ipairs({ "nameplateN:enemy:UnitClass.2", "nameplateN:enemy:UnitPowerType.1", "nameplateN:enemy:UnitName.1",
                         "nameplateN:enemy:UnitGUID.1" }) do
        local agg = {}
        for key, e in pairs(DB.units) do
            local ph = key:sub(1, #k + 1) == k .. "|" and key:sub(#k + 2):match("^(%a+)")
            if ph then local a = agg[ph] or {}; agg[ph] = a; for c, n in pairs(e) do a[c] = (a[c] or 0) + n end end
        end
        for ph, e in pairs(agg) do out(k .. "|" .. ph .. "  C=" .. (e.C or 0) .. " S=" .. (e.S or 0) .. " N=" .. (e.N or 0) .. " E=" .. (e.E or 0)) end
    end
    for _, k in ipairs({ "GetScoreInfo", "GetScoreInfo.talentSpec@T", "GetScoreInfo.talentSpec@C", "GetScoreInfo.classToken@T",
                         "GetScoreInfo.healingDone@T", "GetScoreInfo.name@T", "GetBattlefieldScore.9", "GetBattlefieldScore.16" }) do
        local agg = {}
        for key, e in pairs(DB.score) do
            local ph = key:sub(1, #k + 1) == k .. "|" and key:sub(#k + 2):match("^(%a+)")
            if ph then local a = agg[ph] or {}; agg[ph] = a; for c, n in pairs(e) do a[c] = (a[c] or 0) + n end end
        end
        for ph, e in pairs(agg) do out(k .. "|" .. ph .. "  C=" .. (e.C or 0) .. " S=" .. (e.S or 0) .. " T=" .. (e.T or 0) .. " N=" .. (e.N or 0)) end
    end
end
SLASH_KTHFORVERDIAG1 = "/kthfd"
SlashCmdList["KTHFORVERDIAG"] = function(msg)
    if not F then makeFrame() end
    msg = type(msg) == "string" and msg:lower() or ""
    if msg == "hide" then F:Hide() elseif msg == "show" then F:Show()
    elseif msg == "scan" then pcall(scanPlates); pcall(probeScore); out("scanned plates + scoreboard")
    elseif msg == "errors" then
        for i = math.max(1, #DB.errors - 5), #DB.errors do out(tostring(DB.errors[i].msg):sub(1, 250)) end
    else F:Show(); summary() end
end
