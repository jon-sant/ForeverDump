-- ForeverDump v2 - recorder: /fdump record start|stop|status
-- Registers all events on a hidden frame and logs timestamp, event, args
-- (secret values become "<secret>" and are never touched), combat flag.
-- Bounded ring buffer + per-event throttle for spam. Combat-safe.
local _, ns = ...
local Rec = {}
ns.Recorder = Rec

local GetTime = GetTime
local frame
local active = false
local session, ring, head, size
local cfg
local throttle = {}   -- event -> { second = n, count = c }

local function serializeArg(v, maxString)
    if v == nil then return "<nil>" end
    -- v2.2.22 (audit): a "T" table (secret contents) is cleaned per field by ns.Clean, not dropped whole
    if type(v) == "table" then
        if ns.IsSecretValue(v) then return ns.SECRET_TABLE end
    elseif ns.IsSecret(v) then return ns.SECRET end
    local t = type(v)
    if t == "string" then
        if #v > maxString then return string.sub(v, 1, maxString) .. "<...>" end
        return v
    elseif t == "number" then
        return ns.CleanNumber(v)
    elseif t == "boolean" then
        return v
    elseif t == "table" then
        return ns.Clean(v, { maxDepth = 2, maxKeys = 30, maxString = maxString })
    end
    return "<" .. t .. ">"
end

local function packArgs(maxArgs, maxString, ...)
    local n = select("#", ...)
    local args = {}
    local secrets
    for i = 1, math.min(n, maxArgs) do
        local v = select(i, ...)
        local s = serializeArg(v, maxString)
        if s == ns.SECRET or s == ns.SECRET_TABLE then
            secrets = secrets or {}
            secrets[#secrets + 1] = i
        end
        args[i] = s
    end
    return args, n, secrets
end

-- v2.2.10 hot path: the same as packArgs, but positions the live observer already classified "C" (clear scalar) or
-- "N" skip the second secrecy probe. Anything else (secret, container, beyond the observed positions) goes through
-- serializeArg unchanged, so the stored row is identical.
local HUGE = math.huge
local SECRET_MARK, SECRET_TABLE_MARK
local function convKnown(v, code, maxString)
    if code == "N" then return "<nil>" end
    if code == "C" then
        local t = type(v)
        if t == "number" then
            if v ~= v then return "<nan>" elseif v == HUGE then return "<inf>" elseif v == -HUGE then return "<-inf>" end
            return v
        elseif t == "string" then
            if #v > maxString then return string.sub(v, 1, maxString) .. "<...>" end
            return v
        elseif t == "boolean" then return v end
    end
    return serializeArg(v, maxString)
end

local function packArgsKnown(maxArgs, maxString, codes, lim, ...)
    local n = select("#", ...)
    local m = math.min(n, maxArgs)
    if m > 8 or m > lim then return packArgs(maxArgs, maxString, ...) end
    local args
    if m == 0 then return {}, n, nil end
    local a1, a2, a3, a4, a5, a6, a7, a8 = ...
    local c1, c2, c3, c4, c5, c6, c7, c8 = codes[1], codes[2], codes[3], codes[4], codes[5], codes[6], codes[7], codes[8]
    -- one constructor per arity (no array rehash); values are only classified/copied, never operated on when secret
    if m == 1 then args = { convKnown(a1, c1, maxString) }
    elseif m == 2 then args = { convKnown(a1, c1, maxString), convKnown(a2, c2, maxString) }
    elseif m == 3 then args = { convKnown(a1, c1, maxString), convKnown(a2, c2, maxString), convKnown(a3, c3, maxString) }
    elseif m == 4 then args = { convKnown(a1, c1, maxString), convKnown(a2, c2, maxString), convKnown(a3, c3, maxString),
        convKnown(a4, c4, maxString) }
    elseif m == 5 then args = { convKnown(a1, c1, maxString), convKnown(a2, c2, maxString), convKnown(a3, c3, maxString),
        convKnown(a4, c4, maxString), convKnown(a5, c5, maxString) }
    elseif m == 6 then args = { convKnown(a1, c1, maxString), convKnown(a2, c2, maxString), convKnown(a3, c3, maxString),
        convKnown(a4, c4, maxString), convKnown(a5, c5, maxString), convKnown(a6, c6, maxString) }
    elseif m == 7 then args = { convKnown(a1, c1, maxString), convKnown(a2, c2, maxString), convKnown(a3, c3, maxString),
        convKnown(a4, c4, maxString), convKnown(a5, c5, maxString), convKnown(a6, c6, maxString), convKnown(a7, c7, maxString) }
    else args = { convKnown(a1, c1, maxString), convKnown(a2, c2, maxString), convKnown(a3, c3, maxString),
        convKnown(a4, c4, maxString), convKnown(a5, c5, maxString), convKnown(a6, c6, maxString), convKnown(a7, c7, maxString),
        convKnown(a8, c8, maxString) } end
    SECRET_MARK, SECRET_TABLE_MARK = ns.SECRET, ns.SECRET_TABLE
    local secrets
    for i = 1, m do
        local s = args[i]
        if s == SECRET_MARK or s == SECRET_TABLE_MARK then
            secrets = secrets or {}
            secrets[#secrets + 1] = i
        end
    end
    return args, n, secrets
end

ns.SerializeArg = serializeArg
ns.PackArgs = packArgs

local rle, rawSeq = nil, 0   -- v2.2.10 DAMAGE_METER_* run-length state + raw sequence (pushed + folded rows)
local function push(entry)
    head = head % size + 1
    rawSeq = rawSeq + 1
    if ring[head] then
        session.ringOverwrites = (session.ringOverwrites or 0) + 1
        if ns.ReplayLog then ns.ReplayLog.NoteOverflow("record", 1, size) end
    end
    ring[head] = entry
    session.total = session.total + 1
end

local function allowed(event)
    local now = math.floor(GetTime())
    local t = throttle[event]
    if not t or t.second ~= now then
        t = { second = now, count = 0 }
        throttle[event] = t
    end
    t.count = t.count + 1
    local limit = cfg.perEventPerSec
    if event == "COMBAT_LOG_EVENT_UNFILTERED" or event == "COMBAT_LOG_EVENT" then limit = limit * 4 end
    return t.count <= limit
end

local redactCache = {}
local function redacted(event)
    local r = redactCache[event]
    if r == nil then
        r = (string.find(event, "^CHAT_MSG_") or string.find(event, "^BN_") or string.find(event, "^CLUB_")) and true or false
        redactCache[event] = r
    end
    return r
end

local covered = {}
function Rec.Covers(event) return active and covered[event] == true end

local function onEvent(_, event, ...)
    if not active then return end
    local counts = session.counts
    counts[event] = (counts[event] or 0) + 1
    -- secrets verifier: every event is tallied live (issecretvalue/canaccessvalue per position), before throttling
    local codes, lim
    if ns.ObserveLive and event ~= "COMBAT_LOG_EVENT_UNFILTERED" then codes, lim = ns.ObserveLive("event", event, ...) end
    local nArgs = select("#", ...)
    if type(codes) ~= "table" or type(lim) ~= "number" or lim < math.min(nArgs, 8) then codes, lim = nil, 0 end
    if ns.ReplayLog and ns.ReplayLog.IsTest and ns.ReplayLog.IsTest()
        and (event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_START"
            or event == "UNIT_SPELLCAST_SENT" or event == "UNIT_SPELLCAST_INTERRUPTED"
            or event == "UNIT_SPELLCAST_STOP" or event == "UNIT_COMBAT"
            or event == "SPELL_UPDATE_COOLDOWN" or event == "DAMAGE_METER_COMBAT_SESSION_UPDATED"
            or event == "UNIT_AURA") then
        if nArgs > 0 and nArgs <= 8 then
            if codes then
                ns.ReplayLog.OnCriticalEvent(event, nil, codes, nArgs)   -- v2.2.10: the observer's codes, no copy
            else
                local st = {}
                for i = 1, nArgs do st[i] = ns.ClassifyValue and ns.ClassifyValue(select(i, ...)) or "?" end
                ns.ReplayLog.OnCriticalEvent(event, nil, st)
            end
        end
    end
    -- v2.2.10: DAMAGE_METER_* rows fold losslessly (ns.RLE) before the throttle: a folded occurrence costs two numbers
    local dmKey
    if rle and string.sub(event, 1, 13) == "DAMAGE_METER_" then
        local args, n, secrets
        if codes then args, n, secrets = packArgsKnown(cfg.maxArgs, cfg.maxString, codes, lim, ...)
        else args, n, secrets = packArgs(cfg.maxArgs, cfg.maxString, ...) end
        local c = ns.InCombat() or nil
        local sk = secrets and table.concat(secrets, ",") or ""
        dmKey = ns.RLE.Key(event, (c and "c" or "") .. "|" .. sk, args, n)
        if dmKey then
            local t = GetTime()
            local ms = ns.RLE.Ms(t)
            if ns.RLE.Fold(rle, dmKey, ms, rawSeq + 1, ring) then rawSeq = rawSeq + 1 return end
            local entry = { t = t, e = event, c = c, a = args, n = n, s = secrets }
            push(entry)
            ns.RLE.Open(rle, dmKey, entry, head, ms, rawSeq)
            return
        end
    end
    if not allowed(event) then
        session.dropped[event] = (session.dropped[event] or 0) + 1
        return
    end
    local now, inC = GetTime(), ns.InCombat() or nil
    local args, n, secrets
    if codes and not (cfg.redactChat and redacted(event)) then
        -- v2.2.10 hot path: one presized row constructor (no rehash when a/n/s are added), codes reused
        args, n, secrets = packArgsKnown(cfg.maxArgs, cfg.maxString, codes, lim, ...)
        push({ t = now, e = event, c = inC, a = args, n = n, s = secrets })
        return
    end
    local entry = { t = now, e = event, c = inC }
    if cfg.redactChat and (string.find(event, "^CHAT_MSG_") or string.find(event, "^BN_") or string.find(event, "^CLUB_")) then
        n = select("#", ...)
        entry.a, entry.n, entry.redacted = { "<redacted>" }, n, true
        push(entry)
        return
    end
    if event == "COMBAT_LOG_EVENT_UNFILTERED" and type(rawget(_G, "CombatLogGetCurrentEventInfo")) == "function" then
        local ok = pcall(function()
            args, n, secrets = packArgs(cfg.maxArgs + 10, cfg.maxString, CombatLogGetCurrentEventInfo())
        end)
        if not ok then args, n = { "<CombatLogGetCurrentEventInfo failed>" }, 1 end
        entry.cleu = true
    else
        args, n, secrets = packArgs(cfg.maxArgs, cfg.maxString, ...)
    end
    entry.a = args
    entry.n = n
    entry.s = secrets
    if entry.cleu and ns.ObserveArgs then ns.ObserveArgs("cleu", event, n, secrets) end
    push(entry)
end

-- EventRegistry callbacks (v2.2). v2.1 post-hooked EventRegistry.TriggerEvent with hooksecurefunc. On Forever 70245
-- that broke Blizzard UI: while the hook was installed, the client's hook wrapper itself raised
-- "attempt to call a nil value" ([C]: in function 'TriggerEvent', no ForeverDump frame, ~470 errors per 6 min from
-- GlobalCallbackRegistry.lua:11, EventImplementation.lua:126, MainMenuBarMicroButtons.lua:1503, tooltips, ...).
-- ForeverDump now installs NO hooks on Blizzard code. Opt-in only (record.callbacks = true): subscribe to an explicit
-- list of callback events through the public API EventRegistry:RegisterCallback(event, func, owner). Blizzard
-- dispatches it via secureexecuterange/securecallfunction, so our code runs isolated and can't taint the caller.
local cbOwner = {}
local cbRegistered = {}
local function onCallback(event, ...)
    if not active or not cfg or not cfg.callbacks then return end
    local key = "CB:" .. event
    session.counts[key] = (session.counts[key] or 0) + 1
    if not allowed(key) then
        session.dropped[key] = (session.dropped[key] or 0) + 1
        return
    end
    local args, n, secrets = packArgs(cfg.maxArgs, cfg.maxString, ...)
    push({ t = GetTime(), e = event, cb = true, c = ns.InCombat() or nil, a = args, n = n, s = secrets })
end

local function registerCallbacks()
    if not cfg.callbacks then return 0 end
    local reg = rawget(_G, "EventRegistry")
    if type(reg) ~= "table" or type(reg.RegisterCallback) ~= "function" then return 0 end
    local n = 0
    for _, event in ipairs(cfg.callbackEvents or {}) do
        if type(event) == "string" and not cbRegistered[event] then
            local ok = pcall(reg.RegisterCallback, reg, event, function(_, ...)
                local okCb, err = pcall(onCallback, event, ...)
                if not okCb and session then session.callbackErrors = (session.callbackErrors or 0) + 1 session.lastCallbackError = tostring(err) end
            end, cbOwner)
            if ok then cbRegistered[event] = true n = n + 1 end
        end
    end
    return n
end

local function unregisterCallbacks()
    local reg = rawget(_G, "EventRegistry")
    if type(reg) ~= "table" or type(reg.UnregisterCallback) ~= "function" then return end
    for event in pairs(cbRegistered) do pcall(reg.UnregisterCallback, reg, event, cbOwner) end
    cbRegistered = {}
end
Rec.CallbackOwner = cbOwner

function Rec.Start()
    if active then ns.Print("recorder already running.") return end
    cfg = ns.config.record
    size = math.max(100, tonumber(cfg.maxEvents) or 5000)
    ring, head = {}, 0
    rle, rawSeq = ns.RLE and ns.RLE.New() or nil, 0
    throttle = {}
    session = { meta = ns.Meta(), sid = ns.NewSessionId("rec"), captureSid = ns.SessionId(), anchor = ns.TimeAnchor(),
        startTime = GetTime(), startEpoch = time(), total = 0, counts = {}, dropped = {},
                config = ns.Clean(cfg) }
    if not frame then
        frame = CreateFrame("Frame")
        frame:Hide()
    end
    -- Never RegisterAllEvents(): on Forever it would include restricted events (COMBAT_LOG_EVENT*), and
    -- registering those fires ADDON_ACTION_FORBIDDEN + a "disable addon" popup that pcall cannot stop.
    -- Register documented events one by one, skipping anything the docs mark restricted/secure-only.
    local events, skipped, why = ns.SafeEventList()
    if not events then
        ns.Print("|cffff5555cannot record:|r " .. tostring(why) .. " (refusing to fall back to RegisterAllEvents)")
        session = nil
        return
    end
    local failed = {}
    for _, e in ipairs(events) do
        local ok, err = pcall(frame.RegisterEvent, frame, e)
        if not ok then failed[e] = tostring(err) else covered[e] = true end
    end
    -- v2.2.3: timed by the self-perf monitor (one key for all events: O(1) memory)
    local clock = rawget(_G, "debugprofilestop")
    frame:SetScript("OnEvent", function(f, event, ...)
        local P = ns.Perf
        if not (P and P.on and clock) then return onEvent(f, event, ...) end
        local t0 = clock()
        onEvent(f, event, ...)
        P.Add("Recorder.onEvent", clock() - t0)
    end)
    session.registered = #events
    session.skippedEvents = skipped
    session.registerFailed = failed
    session.callbacksRegistered = registerCallbacks()
    active = true
    local nSkipped = 0
    for _ in pairs(session.skippedEvents) do nSkipped = nSkipped + 1 end
    ns.Print(string.format("registered %d documented events, skipped %d restricted/secure-only (see session.skippedEvents)",
        session.registered, nSkipped))
    ns.Print("recording events (ring buffer " .. size .. ", throttle " .. cfg.perEventPerSec .. "/s per event). /fdump record stop to save.")
end

function Rec.Stop()
    if not active then ns.Print("recorder is not running.") return end
    active = false
    pcall(frame.UnregisterAllEvents, frame)
    unregisterCallbacks()
    -- linearize ring buffer, oldest first
    local events = {}
    local count = math.min(session.total, size)
    local start = (session.total > size) and (head % size + 1) or 1
    for i = 0, count - 1 do
        local idx = (start + i - 1) % size + 1
        events[#events + 1] = ring[idx]
    end
    session.events = events
    session.stopTime = GetTime()
    session.anchorEnd = ns.TimeAnchor(true)
    session.stopEpoch = time()
    session.kept = #events
    session.overwritten = math.max(0, session.total - size)
    session.rawSeq = rawSeq
    session.rle = ns.RLE and ns.RLE.Summary(rle) or nil
    if session.overwritten > 0 and rle and rle.folded > 0 then session.rleOrderApprox = true end
    rle = nil
    local sessions = ForeverDumpRecordDB.sessions
    sessions[#sessions + 1] = session
    while #sessions > (tonumber(ns.config.record.maxSessions) or 3) do table.remove(sessions, 1) end
    ns.Print(string.format("recording saved: %d events kept (%d recorded, %d overwritten). /reload or log out to write it.",
        #events, session.total, session.overwritten))
    ring, session = nil, nil
end

function Rec.Status()
    if active then
        ns.Print(string.format("recording: %d events so far (%.0fs).", session.total, GetTime() - session.startTime))
    else
        ns.Print("recorder idle; " .. #ForeverDumpRecordDB.sessions .. " saved session(s).")
    end
end

function Rec.IsActive() return active end
