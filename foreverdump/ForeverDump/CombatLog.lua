-- ForeverDump v2 - combat recorder: /fdump cl start [file]|stop|status, /fdump cl cleu-force
--
-- On Forever (Midnight-era API) COMBAT_LOG_EVENT and COMBAT_LOG_EVENT_UNFILTERED are restricted: registering
-- them fires ADDON_ACTION_FORBIDDEN and the "blocked from an action only available to the Blizzard UI" popup
-- that offers to disable the addon (pcall does not prevent it), and CombatLogGetCurrentEventInfo is gone.
-- So by default this recorder captures what addons CAN use on Forever:
--   UNIT_COMBAT, UNIT_SPELLCAST_*, PLAYER_SWING / PLAYER_SWING_RANGE_UPDATE (+ C_SwingTimer range checks),
--   COMBAT_TEXT_UPDATE (+ C_CombatText.GetCurrentEventInfo()), DAMAGE_METER_* events, ENCOUNTER_START/END,
--   PLAYER_REGEN_*, zone/instance/restriction changes, and a C_DamageMeter snapshot read AFTER combat
--   (its getters are SecretWhenInCombat). Secret values are recorded as "<secret>", never touched.
-- Each event is only registered if it is documented, valid and not restricted (ns.SafeEventList).
-- CLEU capture survives only as an explicit opt-in ("/fdump cl cleu-force") that refuses unless
-- CombatLogGetCurrentEventInfo exists AND C_CombatLog.IsCombatLogRestricted() returns false.
-- Optional: "/fdump cl start file" sets advancedCombatLogging=1 (restored on stop). It only calls
-- LoggingCombat itself when logs.callLogging=true (whether LoggingCombat is protected on Forever is unverified);
-- otherwise use the FD_Logs macro (/fdump logs macro) or type Blizzard's own /combatlog.
-- Entries share the recorder shape so tools/replay.lua can feed them to addons:
--   { t = GetTime(), e = event, c = inCombat, a = args, n = n, s = secretPositions,
--     g = { ["C_CombatText.GetCurrentEventInfo"] = { a =, n =, s = } } }   -- getter results at dispatch time
--   legacy CLEU entries (cleu-force only): { e = "COMBAT_LOG_EVENT_UNFILTERED", cleu = true, sub = subevent, a = payload }
local _, ns = ...
local CL = {}
ns.CombatLog = CL

local CLEU = "COMBAT_LOG_EVENT_UNFILTERED"
local COMBAT_EVENTS = {
    "UNIT_COMBAT", "PLAYER_SWING", "PLAYER_SWING_RANGE_UPDATE", "COMBAT_TEXT_UPDATE",
    "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED", "DAMAGE_METER_RESET",
    "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_AURA", "UNIT_DIED", "PLAYER_TARGET_CHANGED",
}
local CONTEXT_EVENTS = {
    "ENCOUNTER_START", "ENCOUNTER_END", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD", "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED",
    "PLAYER_DEAD", "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "ADDON_RESTRICTION_STATE_CHANGED", "COMBAT_LOG_ENTRIES_CLEARED",
}
local CONTEXT = {}
for _, e in ipairs(CONTEXT_EVENTS) do CONTEXT[e] = true end

local frame
local active = false
local session, ring, head, size, cfg
local getter, getterName
local guidMap, guidCount

local function cvarGet(name)
    local C = rawget(_G, "C_CVar")
    local f = (type(C) == "table" and C.GetCVar) or rawget(_G, "GetCVar")
    if type(f) ~= "function" then return nil end
    local ok, v = pcall(f, name)
    if ok and not ns.IsSecret(v) then return v end
end

local function cvarSet(name, value)
    local C = rawget(_G, "C_CVar")
    local f = (type(C) == "table" and C.SetCVar) or rawget(_G, "SetCVar")
    if type(f) ~= "function" then return false, "SetCVar missing" end
    return pcall(f, name, value)
end

local function restricted()
    local C = rawget(_G, "C_CombatLog")
    local f = type(C) == "table" and C.IsCombatLogRestricted
    if type(f) ~= "function" then return nil end
    local ok, v = pcall(f)
    if ok and not ns.IsSecret(v) then return v end
    return ok and ns.SECRET or ("error: " .. tostring(v))
end
CL.IsRestricted = restricted

-- C_RestrictedActions.GetAddOnRestrictionState for every Enum.AddOnRestrictionType.
function CL.RestrictionStates()
    local R = rawget(_G, "C_RestrictedActions")
    local E = rawget(_G, "Enum")
    local types = type(E) == "table" and rawget(E, "AddOnRestrictionType")
    if type(R) ~= "table" or type(types) ~= "table" then return nil end
    local f = R.GetAddOnRestrictionState or R.IsAddOnRestrictionActive
    if type(f) ~= "function" then return nil end
    local out = {}
    for name, value in pairs(types) do
        local ok, v = pcall(f, value)
        out[name] = ok and ns.SerializeArg(v, 50) or ("error: " .. tostring(v))
    end
    return out
end

-- Legacy CLEU payload getter (gone on Forever; only used by cleu-force).
local function findGetter()
    local g = rawget(_G, "CombatLogGetCurrentEventInfo")
    if type(g) == "function" then return g, "CombatLogGetCurrentEventInfo" end
    local C = rawget(_G, "C_CombatLog")
    if type(C) == "table" and type(C.GetCurrentEventInfo) == "function" then
        return C.GetCurrentEventInfo, "C_CombatLog.GetCurrentEventInfo"
    end
    return nil, nil
end
CL.FindGetter = findGetter

local function instanceInfo()
    local f = rawget(_G, "GetInstanceInfo")
    if type(f) ~= "function" then return nil end
    local r = ns.SafeCall(f)
    if not r.ok then return { err = r.err } end
    local v = r.values
    return { name = v[1], instanceType = v[2], difficultyID = v[3], difficultyName = v[4], maxPlayers = v[5],
        dynamicDifficulty = v[6], isDynamic = v[7], instanceID = v[8], instanceGroupSize = v[9], lfgDungeonID = v[10],
        secret = r.secret }
end

-- time audit 2026-10-10: this copy still wrote l.isdst into the table date() returned and called time(l) - the exact
-- pattern Core.lua removed in v2.2.11 (run 9 taint "while reading field isdst"). Use Core's arithmetic offset.
local function utcOffset()
    local a = ns.TimeAnchor and ns.TimeAnchor(true)
    return a and a.utcOffset or nil
end

local function redactGUIDs(args, positions)
    if not cfg.redactPlayers then return end
    for _, i in ipairs(positions) do
        local g = args[i]
        if type(g) == "string" and string.find(g, "^Player%-") then
            if not guidMap[g] then guidCount = guidCount + 1 guidMap[g] = "Player-#" .. guidCount end
            args[i] = guidMap[g]
            local nameIdx = i + 1
            if type(args[nameIdx]) == "string" and args[nameIdx] ~= "<nil>" then args[nameIdx] = "<player>" end
        end
    end
end

local rle, rawSeq = nil, 0   -- v2.2.10 DAMAGE_METER_* run-length state + raw event sequence (pushed + folded)
local function push(entry)
    head = head % size + 1
    if ring[head] then
        session.overwritten = session.overwritten + 1
        if ns.ReplayLog then ns.ReplayLog.NoteOverflow("combat", 1, size) end
    end
    ring[head] = entry
    session.kept = math.min(session.kept + 1, size)
end
-- v2.2.10: DAMAGE_METER_* rows fold losslessly into run rows (ns.RLE); everything else is pushed as before
local function pushOrFold(entry)
    rawSeq = rawSeq + 1
    local e = entry.e
    if rle and type(e) == "string" and string.sub(e, 1, 13) == "DAMAGE_METER_" and not entry.ctx then
        local RLE = ns.RLE
        local sk = ""
        if entry.s then
            if type(entry.s) ~= "table" then sk = nil else sk = table.concat(entry.s, ",") end
        end
        local key = sk and RLE.Key(e, (entry.c and "c" or "") .. (entry.enc and "e" or "") .. "|" .. sk, entry.a, entry.n)
        if key then
            local ms = RLE.Ms(entry.t)
            if RLE.Fold(rle, key, ms, rawSeq, ring) then return end
            push(entry)
            RLE.Open(rle, key, entry, head, ms, rawSeq)
            return
        end
    end
    push(entry)
end

local function pack(...) return ns.PackArgs(cfg.maxArgs, cfg.maxString, ...) end

local function getterResult(f, ...)
    if type(f) ~= "function" then return nil end
    local r = ns.Pack(pcall(f, ...))
    if not r[1] then return { err = tostring(r[2]) } end
    local a, n, s = pack(select(2, unpack(r, 1, r.n)))
    return { a = a, n = n, s = s }
end

local function damageMeterSnapshot(reason)
    local D = rawget(_G, "C_DamageMeter")
    local E = rawget(_G, "Enum")
    if type(D) ~= "table" then return { unavailable = "C_DamageMeter missing" } end
    local snap = { reason = reason, time = time and time() or nil, gameTime = GetTime(), inCombat = ns.InCombat(),
        available = getterResult(D.IsDamageMeterAvailable), sessions = getterResult(D.GetAvailableCombatSessions), byType = {} }
    local types = type(E) == "table" and rawget(E, "DamageMeterType")
    local stypes = type(E) == "table" and rawget(E, "DamageMeterSessionType")
    local current = type(stypes) == "table" and stypes.Current or 1
    if type(types) == "table" and type(D.GetCombatSessionFromType) == "function" then
        for name, value in pairs(types) do
            local ok, res = pcall(D.GetCombatSessionFromType, current, value)
            if not ok then snap.byType[name] = { err = tostring(res) }
            else
                snap.byType[name] = ns.Clean(res, { maxDepth = 4, maxKeys = 60, maxString = 200 })
                if ns.ObserveArgs then
                    ns.ObserveArgs("api", "C_DamageMeter.GetCombatSessionFromType", 1, ns.IsSecretValue(res) and { 1 } or nil)
                    -- v2.2.22 (audit): a "T" session (issecrettable / secret fields) is observed per field too
                    if type(res) == "table" and not ns.IsSecretValue(res) then
                        pcall(function()
                            for k, v in next, res do
                                if type(k) == "string" and not ns.IsSecretValue(k) then
                                    ns.ObserveArgs("field", "DamageMeterCombatSession." .. k, 1, ns.IsSecretValue(v) and { 1 } or nil)
                                end
                            end
                        end)
                    end
                end
            end
        end
    end
    snap.duration = getterResult(D.GetSessionDurationSeconds, current)
    return snap
end
CL.DamageMeterSnapshot = damageMeterSnapshot

local function swingRange()
    local S = rawget(_G, "C_SwingTimer")
    local E = rawget(_G, "Enum")
    local types = type(E) == "table" and rawget(E, "PlayerSwingType")
    if type(S) ~= "table" or type(S.IsTargetWithinSwingRange) ~= "function" or type(types) ~= "table" then return nil end
    local out = {}
    for name, value in pairs(types) do
        local r = getterResult(S.IsTargetWithinSwingRange, value)
        out[name] = r and (r.err or r.a[1])
    end
    return out
end

local function onCLEU()
    local entry = { t = GetTime(), e = CLEU, cleu = true, c = ns.InCombat() or nil }
    if not getter then session.noGetter = (session.noGetter or 0) + 1 return end
    local r = getterResult(getter)
    if r.err then
        session.getterErrors = (session.getterErrors or 0) + 1
        session.lastGetterError = r.err
        return
    end
    entry.a, entry.n, entry.s = r.a, r.n, r.s
    local sub = r.a[2]
    if type(sub) ~= "string" or sub == "<nil>" then sub = "?" end
    entry.sub = sub
    session.cleuCounts[sub] = (session.cleuCounts[sub] or 0) + 1
    session.cleuTotal = session.cleuTotal + 1
    if r.s then session.secretEntries = session.secretEntries + 1 end
    redactGUIDs(r.a, { 4, 8 })
    pushOrFold(entry)
end

local function onEvent(_, event, ...)
    if event == CLEU then return onCLEU() end
    local a, n, s = pack(...)
    local entry = { t = GetTime(), e = event, c = ns.InCombat() or nil, a = a, n = n, s = s }
    if ns.Secrets and ns.Secrets.InEncounter() then entry.enc = true end
    -- tally once per event: the event recorder does it when it is running and registered this event
    if ns.ObserveLive and not (ns.Recorder and ns.Recorder.Covers(event)) then ns.ObserveLive("event", event, ...) end
    if ns.ReplayLog and ns.ReplayLog.IsTest and ns.ReplayLog.IsTest() and not (ns.Recorder and ns.Recorder.Covers(event))
        and (event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_START"
            or event == "UNIT_SPELLCAST_SENT" or event == "UNIT_SPELLCAST_INTERRUPTED"
            or event == "UNIT_SPELLCAST_STOP" or event == "UNIT_COMBAT"
            or event == "SPELL_UPDATE_COOLDOWN" or event == "DAMAGE_METER_COMBAT_SESSION_UPDATED"
            or event == "UNIT_AURA") then
        local argc = select("#", ...)
        if argc > 0 and argc <= 8 then
            local st = {}
            for i = 1, argc do st[i] = ns.ClassifyValue and ns.ClassifyValue(select(i, ...)) or "?" end
            ns.ReplayLog.OnCriticalEvent(event, nil, st)
        end
    end
    if CONTEXT[event] then
        entry.ctx = true
        entry.epoch = time and time() or nil
        if event == "ENCOUNTER_START" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD"
            or event == "CHALLENGE_MODE_START" then
            entry.instance = instanceInfo()
        end
        if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" or event == "ENCOUNTER_START" then
            entry.restricted = restricted()
            entry.restrictions = CL.RestrictionStates()
        end
        session.context[event] = (session.context[event] or 0) + 1
        session.contextTotal = session.contextTotal + 1
    end
    if event == "COMBAT_TEXT_UPDATE" then
        local C = rawget(_G, "C_CombatText")
        entry.g = { ["C_CombatText.GetCurrentEventInfo"] = getterResult(C and C.GetCurrentEventInfo) }
        local gr = entry.g["C_CombatText.GetCurrentEventInfo"]
        if ns.ObserveArgs and type(gr) == "table" and gr.n then ns.ObserveArgs("api", "C_CombatText.GetCurrentEventInfo", gr.n, gr.s, "player") end
    elseif event == "PLAYER_SWING" then
        entry.range = swingRange()
    elseif event == "PLAYER_REGEN_ENABLED" and cfg.damageMeter then
        -- C_DamageMeter getters are SecretWhenInCombat: read shortly after combat ends.
        local after = rawget(_G, "C_Timer") and C_Timer.After
        local sess = session
        local function snap()
            if sess and sess.damageMeter then
                local d = damageMeterSnapshot("PLAYER_REGEN_ENABLED")
                sess.damageMeter[#sess.damageMeter + 1] = d
                while #sess.damageMeter > 20 do table.remove(sess.damageMeter, 1) end
            end
        end
        if type(after) == "function" then after(0.5, snap) else snap() end
    end
    if event == "UNIT_COMBAT" or (type(event) == "string" and string.find(event, "^UNIT_SPELLCAST_")) then
        session.combatEvents = session.combatEvents + 1
    end
    if s then session.secretEntries = session.secretEntries + 1 end
    session.counts[event] = (session.counts[event] or 0) + 1
    session.total = session.total + 1
    pushOrFold(entry)
end

local function protectedHint(name)
    -- Do not call a function the docs or the protected section flag as protected/restricted.
    local p = ns.db and ns.db.sections and ns.db.sections.protected
    if p and p.functions and p.functions[name] then
        local f = p.functions[name].flags or {}
        if f.IsProtectedFunction or f.HasRestrictions then return "flagged protected/restricted in docs" end
    end
    if type(rawget(_G, "issecurevariable")) == "function" then
        local ok, secure = pcall(issecurevariable, name)
        if ok and secure == false then return "LoggingCombat is tainted (insecure) - not calling it" end
    end
    return nil
end

local function setFileLogging(on)
    local fl = session.fileLogging
    local f = rawget(_G, "LoggingCombat")
    local C = rawget(_G, "C_ChatInfo")
    local isLogging = type(C) == "table" and C.IsLoggingCombat
    if type(f) ~= "function" then fl.error = "LoggingCombat missing (use Blizzard's /combatlog instead)" return end
    if on and not (ns.config.logs and ns.config.logs.callLogging) then
        fl.error = "skipped: ForeverDump does not call LoggingCombat by default (may be protected on Forever); "
            .. "use the FD_Logs macro (/fdump logs macro) or type /combatlog"
        ns.Print("combat log file: " .. fl.error)
        if cfg.advanced then
            fl.prevAdvanced = cvarGet("advancedCombatLogging")
            if fl.prevAdvanced ~= nil and tostring(fl.prevAdvanced) ~= "1" then
                local okSet, err = cvarSet("advancedCombatLogging", "1")
                fl.advancedSet = okSet and true or ("failed: " .. tostring(err))
            end
            fl.advanced = cvarGet("advancedCombatLogging")
        end
        return
    end
    if on then
        local hint = protectedHint("LoggingCombat")
        if hint then fl.error = hint ns.Print("combat log file: " .. hint .. " - type /combatlog yourself") return end
        local okRead, prev
        if type(isLogging) == "function" then okRead, prev = pcall(isLogging) else okRead, prev = pcall(f) end
        if okRead and not ns.IsSecret(prev) then fl.prevLogging = prev end
        if cfg.advanced then
            fl.prevAdvanced = cvarGet("advancedCombatLogging")
            if fl.prevAdvanced ~= nil and tostring(fl.prevAdvanced) ~= "1" then
                local okSet, err = cvarSet("advancedCombatLogging", "1")
                fl.advancedSet = okSet and true or ("failed: " .. tostring(err))
            end
            fl.advanced = cvarGet("advancedCombatLogging")
        end
        local okOn, res = pcall(f, true)
        fl.enabled = okOn and (ns.IsSecret(res) and ns.SECRET or res) or nil
        if not okOn then fl.error = tostring(res) end
        fl.startEpoch = time and time() or nil
        ns.Print("combat log file: " .. (okOn and "LoggingCombat(true) -> Logs/WoWCombatLog*.txt" or ("failed: " .. tostring(res))))
    else
        if fl.prevLogging == false and fl.enabled ~= nil then pcall(f, false) end
        if fl.advancedSet == true and fl.prevAdvanced ~= nil then cvarSet("advancedCombatLogging", fl.prevAdvanced) end
        fl.stopEpoch = time and time() or nil
    end
end

function CL.IsActive() return active end

local function wantedEvents(forceCLEU)
    local safe, skipped, err = ns.SafeEventList()
    if not safe then return nil, nil, err end
    local ok = {}
    for _, e in ipairs(safe) do ok[e] = true end
    local list = {}
    for _, e in ipairs(COMBAT_EVENTS) do if ok[e] then list[#list + 1] = e end end
    for _, e in ipairs(CONTEXT_EVENTS) do if ok[e] then list[#list + 1] = e end end
    for _, e in ipairs(safe) do if string.find(e, "^UNIT_SPELLCAST_") then list[#list + 1] = e end end
    local notAvailable = {}
    for _, e in ipairs(COMBAT_EVENTS) do if not ok[e] then notAvailable[e] = skipped[e] or "not documented on this client" end end
    if forceCLEU then list[#list + 1] = CLEU end
    return list, notAvailable
end

-- opts.file: toggle client file logging; opts.cleuForce: legacy CLEU capture (guarded, may show a popup).
function CL.Start(opts)
    opts = opts or {}
    if active then ns.Print("combat recorder already running (/fdump cl stop)") return end
    cfg = ns.config.cl
    size = math.max(100, tonumber(cfg.maxEvents) or 20000)
    ring, head = {}, 0
    rle, rawSeq = ns.RLE and ns.RLE.New() or nil, 0
    guidMap, guidCount = {}, 0
    local okG, pguid = pcall(rawget(_G, "UnitGUID") or function() end, "player")
    if not okG or ns.IsSecret(pguid) or type(pguid) ~= "string" then pguid = nil end
    session = { sid = ns.NewSessionId("cl"), captureSid = ns.SessionId(), anchor = ns.TimeAnchor(), playerGUID = pguid,
        meta = ns.Meta(), kind = "combat", startTime = GetTime(), startEpoch = time and time() or nil,
        utcOffsetSec = utcOffset(), total = 0, kept = 0, overwritten = 0, secretEntries = 0, contextTotal = 0,
        combatEvents = 0, counts = {}, context = {}, cleuCounts = {}, cleuTotal = 0, config = ns.Clean(cfg),
        restrictedAtStart = restricted(), instanceAtStart = instanceInfo(), restrictionsAtStart = CL.RestrictionStates(),
        fileLogging = { requested = opts.file or false }, damageMeter = {}, cleu = { requested = opts.cleuForce or false },
    }
    if opts.cleuForce then
        getter, getterName = findGetter()
        local r = session.restrictedAtStart
        if not getter then
            session.cleu.refused = "CombatLogGetCurrentEventInfo missing (expected on Forever)"
        elseif r ~= false then
            session.cleu.refused = "C_CombatLog.IsCombatLogRestricted() = " .. tostring(r) .. " (must be false)"
        end
        if session.cleu.refused then
            ns.Print("|cffff5555cleu-force refused:|r " .. session.cleu.refused .. ". Recording Forever combat events only.")
            opts.cleuForce = false
        else
            ns.Print("|cffff8800WARNING:|r registering COMBAT_LOG_EVENT_UNFILTERED. If the client restricts it you will get "
                .. "ADDON_ACTION_FORBIDDEN and a popup offering to disable ForeverDump - choose Ignore, then /fdump cl stop.")
            session.cleu.getter = getterName
        end
    end
    local list, notAvailable, err = wantedEvents(opts.cleuForce)
    if not list then
        ns.Print("|cffff5555cannot record:|r " .. tostring(err))
        session = nil
        return
    end
    session.notAvailable = notAvailable
    if not frame then frame = CreateFrame("Frame") end
    frame:UnregisterAllEvents()
    local failed = {}
    for _, ev in ipairs(list) do
        local ok, e = pcall(frame.RegisterEvent, frame, ev)
        if not ok then failed[ev] = tostring(e) end
    end
    session.registered = list
    session.registerFailed = failed
    if opts.cleuForce then session.cleu.registered = not failed[CLEU] end
    local clock = rawget(_G, "debugprofilestop")
    frame:SetScript("OnEvent", function(f, event, ...)   -- v2.2.3: timed by the self-perf monitor
        local P = ns.Perf
        if not (P and P.on and clock) then return onEvent(f, event, ...) end
        local t0 = clock()
        onEvent(f, event, ...)
        P.Add("CombatLog.onEvent", clock() - t0)
    end)
    active = true
    if session.fileLogging.requested then setFileLogging(true) end
    ns.Print(string.format("combat recorder started: %d events (UNIT_COMBAT, UNIT_SPELLCAST_*, PLAYER_SWING, COMBAT_TEXT_UPDATE, "
        .. "DAMAGE_METER_*, encounter/regen context), buffer %d%s", #list, size,
        opts.cleuForce and ", + legacy CLEU" or ""))
end

function CL.Stop()
    if not active then ns.Print("combat recorder is not running") return end
    active = false
    frame:UnregisterAllEvents()
    frame:SetScript("OnEvent", nil)
    if session.fileLogging.requested then setFileLogging(false) end
    local events = {}
    if session.overwritten > 0 then
        for i = 1, size do
            local e = ring[(head + i - 1) % size + 1]
            if e then events[#events + 1] = e end
        end
    else
        for i = 1, head do events[i] = ring[i] end   -- never wrapped: ring[1..head] is already oldest-first (v2.2.10: no 1M-slot walk)
    end
    session.events = events
    session.rawSeq = rawSeq
    session.rle = ns.RLE and ns.RLE.Summary(rle) or nil
    -- v2.2.10: ring wrapped (safety ceiling) -> run rows still carry exact times/payloads; stream positions of folded
    -- occurrences relative to the overwritten part are unknown
    if session.overwritten > 0 and rle and rle.folded > 0 then session.rleOrderApprox = true end
    rle = nil
    session.stopTime = GetTime()
    session.anchorEnd = ns.TimeAnchor(true)
    session.stopEpoch = time and time() or nil
    session.restrictedAtStop = restricted()
    session.restrictionsAtStop = CL.RestrictionStates()
    if cfg.damageMeter and not ns.InCombat() then
        session.damageMeter[#session.damageMeter + 1] = damageMeterSnapshot("stop")
    end
    local sessions = ForeverDumpCombatLogDB.sessions
    sessions[#sessions + 1] = session
    while #sessions > (tonumber(ns.config.cl.maxSessions) or 3) do table.remove(sessions, 1) end
    ns.Print(string.format("combat recorder stopped: %d events (%d kept, %d UNIT_COMBAT/UNIT_SPELLCAST, %d with secrets, %d context, "
        .. "%d damage meter snapshot(s)%s); saved session #%d. /reload to write.",
        session.total, #events, session.combatEvents, session.secretEntries, session.contextTotal, #session.damageMeter,
        session.cleu.requested and (", legacy CLEU " .. session.cleuTotal) or "", #sessions))
    session = nil
    ring = nil
end

function CL.Status()
    cfg = cfg or ns.config.cl
    local saved = ForeverDumpCombatLogDB and ForeverDumpCombatLogDB.sessions or {}
    if active then
        ns.Print(string.format("combat recorder: RUNNING %ds, %d events (%d kept/%d buffer), %d with secrets",
            math.floor(GetTime() - session.startTime), session.total, session.kept, size, session.secretEntries))
    else
        ns.Print("combat recorder: idle")
    end
    local _, name = findGetter()
    local C = rawget(_G, "C_ChatInfo")
    local isLogging = type(C) == "table" and C.IsLoggingCombat
    local okL, logging = false, nil
    if type(isLogging) == "function" then okL, logging = pcall(isLogging) end
    ns.Print(string.format("  C_CombatLog.IsCombatLogRestricted: %s; legacy CLEU getter: %s; file logging: %s; "
        .. "advancedCombatLogging: %s; C_DamageMeter: %s; %d saved session(s)",
        tostring(restricted()), tostring(name or "none (expected on Forever)"),
        okL and tostring(ns.IsSecret(logging) and "<secret>" or logging) or "unknown",
        tostring(cvarGet("advancedCombatLogging")), tostring(type(rawget(_G, "C_DamageMeter")) == "table"), #saved))
end
