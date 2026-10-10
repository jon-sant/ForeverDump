-- ForeverDump v2 - error & taint capture: /fdump errors [status|on|off|clear|show]
-- Chains the Lua error handler (seterrorhandler), keeping whatever handler was installed before (Blizzard's
-- ScriptErrorsFrame / BugGrabber keep working), and logs each unique error with count, stack (debugstack)
-- and locals (debuglocals, when available) into ForeverDumpLogDB.errors. Also logs ADDON_ACTION_BLOCKED,
-- ADDON_ACTION_FORBIDDEN, MACRO_ACTION_BLOCKED, MACRO_ACTION_FORBIDDEN, LUA_WARNING and
-- ADDON_RESTRICTION_STATE_CHANGED into ForeverDumpLogDB.blocked. Secret values are never touched.
-- BugGrabber/BugSack: when !BugGrabber is loaded it owns the error handler (it replaces seterrorhandler with a no-op
-- and re-installs its own handler at PLAYER_LOGIN), so ForeverDump registers for its CallbackHandler event
-- "BugGrabber_BugGrabbed" instead (BugGrabber.setupCallbacks() makes BugGrabber.RegisterCallback appear when some
-- addon such as BugSack ships CallbackHandler-1.0). Without callbacks, BugGrabber's session errors are still copied
-- from BugGrabber:GetDB() on FD_Logs OFF / logout / "/fdump errors bg". Without BugGrabber the handler is chained.
local _, ns = ...
local Err = {}
ns.Errors = Err

local BLOCK_EVENTS = {
    ADDON_ACTION_BLOCKED = { "addon", "function" },
    ADDON_ACTION_FORBIDDEN = { "addon", "function" },
    MACRO_ACTION_BLOCKED = { "function" },
    MACRO_ACTION_FORBIDDEN = { "function" },
    LUA_WARNING = { "warningText" },
    ADDON_RESTRICTION_STATE_CHANGED = { "type", "state" },
}

local installed = false
local previous
local inHandler = false
local sessionErrors = 0
local index -- msg -> entry
local imported = setmetatable({}, { __mode = "k" }) -- BugGrabber error objects already merged into the main log

local function cfg() return ns.config and ns.config.errors or ns.defaults.errors end

local function safeString(v, max)
    if v == nil then return nil end
    if ns.IsSecret(v) then return ns.SECRET end
    local s = tostring(v)
    if max and #s > max then s = string.sub(s, 1, max) .. "<...>" end
    return s
end

-- v2.2.9 (run 8): debugstack runs inside our handler, so every raw stack starts with ForeverDump/Errors.lua frames,
-- the [C] pcall around capture() and the client's "[C]: ?" dispatch frame. Health counted every error as
-- "own" (3354 in a BG where none were ours) and classified nil-calls as "inside [C] pcall". StripOwn removes exactly
-- that prefix (Errors.lua frames + pcall lines interleaved at the top, then one "[C]: ?"); any other ForeverDump frame is
-- real (idempotent: an already stripped stack is returned unchanged).
local function stripOwn(stack)
    if type(stack) ~= "string" or ns.IsSecret(stack) then return stack end
    local lines = {}
    for line in string.gmatch(stack, "[^\n]+") do lines[#lines + 1] = line end
    local cut = 0
    for i, line in ipairs(lines) do
        if string.find(line, "AddOns/" .. ns.ADDON .. "/Errors.lua", 1, true) then cut = i   -- only the handler's own file
        elseif line ~= "[C]: in function 'pcall'" and line ~= "[C]: in function `pcall'" then break end
    end
    if cut == 0 then return stack end
    if lines[cut + 1] == "[C]: ?" then cut = cut + 1 end
    if cut >= #lines then return stack end
    return table.concat(lines, "\n", cut + 1)
end
Err.StripOwn = stripOwn

-- an error ForeverDump caused: the message names a ForeverDump file, or a ForeverDump frame sits below the handler prefix
function Err.IsOwn(e)
    if type(e) ~= "table" then return false end
    if e.addon == ns.ADDON then return true end
    local msg = e.message
    if type(msg) == "string" and not ns.IsSecret(msg) and string.find(msg, "AddOns/" .. ns.ADDON .. "/", 1, true) then return true end
    local st = stripOwn(e.stack)
    if type(st) ~= "string" or ns.IsSecret(st) then return false end
    if st == e.stack and string.find(st, "^%[[^\n]*AddOns/" .. ns.ADDON .. "/[^\n]*Errors%.lua") then return false end -- unstrippable handler-only stack
    return string.find(st, "AddOns/" .. ns.ADDON .. "/", 1, true) ~= nil
end

-- first addon folder named in the text, skipping ForeverDump's own handler frames (they are always on top of
-- the stack because debugstack runs inside our error handler; v2.0 blamed every error on ForeverDump)
local function addonFromText(s)
    if type(s) ~= "string" then return nil end
    for name in string.gmatch(s, "[Ii]nterface[/\\][Aa]dd[Oo]ns[/\\]([^/\\]+)[/\\]") do
        if name ~= ns.ADDON then return name end
    end
end

-- short call-site signature: the first two stack lines that are not ForeverDump's own handler frames
local function originOf(stack)
    if type(stack) ~= "string" then return nil end
    local keep = {}
    for line in string.gmatch(stack, "[^\n]+") do
        if not string.find(line, "AddOns/" .. ns.ADDON .. "/", 1, true) and not string.find(line, "^%[C%]: %?") then
            local short = line:gsub("^.-[Ii]nterface[/\\][Aa]dd[Oo]ns[/\\]", ""):gsub("^%[string \"@?", "")
            keep[#keep + 1] = short:sub(1, 120)
            if #keep >= 2 then break end
        end
    end
    return #keep > 0 and table.concat(keep, " < ") or nil
end
Err.OriginOf = originOf

local function captureState()
    local logs = ns.db and ns.db.logs
    return logs and logs.on and true or nil
end

local function taintLogValue()
    local get = (rawget(_G, "C_CVar") and C_CVar.GetCVar) or rawget(_G, "GetCVar")
    if type(get) ~= "function" then return nil end
    local ok, v = pcall(get, "taintLog")
    if ok and type(v) == "string" then return v end
end

local function capture(msg)
    local c = cfg()
    local log = ForeverDumpLogDB and ForeverDumpLogDB.errors
    if not log then return end
    local text = safeString(msg, 2000) or "<nil error>"
    index = index or {}
    if not next(index) then for _, e in ipairs(log) do if e.message then index[e.message] = e end end end
    local now = time and time() or nil
    local e = index[text]
    if e then
        e.count = e.count + 1
        e.lastTime = now
        e.lastSession = sessionErrors
        if captureState() then e.duringCapture = (e.duringCapture or 0) + 1 end
        -- the same message from different call sites (v2.1: one TriggerEvent message, 470 hits, 10+ origins)
        if e.count <= 300 then
            local ds = rawget(_G, "debugstack")
            if type(ds) == "function" then
                local ok, st = pcall(ds, 2, 16, 0)
                local o = ok and not ns.IsSecret(st) and originOf(stripOwn(st))   -- 12.0.7+: debugstack may return a secret
                if o then
                    e.origins = e.origins or {}
                    if e.origins[o] then e.origins[o] = e.origins[o] + 1
                    else
                        local n = 0
                        for _ in pairs(e.origins) do n = n + 1 end
                        if n < 12 then e.origins[o] = 1 else e.originsDropped = (e.originsDropped or 0) + 1 end
                    end
                end
            end
        end
        return
    end
    if #log >= (tonumber(c.maxErrors) or 200) then
        ForeverDumpLogDB.droppedErrors = (ForeverDumpLogDB.droppedErrors or 0) + 1
        return
    end
    local ds = rawget(_G, "debugstack")
    local dl = rawget(_G, "debuglocals")
    local stack, locals
    if type(ds) == "function" then
        local ok, s = pcall(ds, 2, 30, 30)
        if ok and not ns.IsSecret(s) then s = stripOwn(s) end
        stack = ok and safeString(s, c.maxStack) or nil
    end
    if c.captureLocals and type(dl) == "function" then
        local ok, l = pcall(dl, 4)
        locals = ok and safeString(l, c.maxLocals) or nil
    end
    e = { message = text, count = 1, time = now, lastTime = now, date = date and date("%Y-%m-%d %H:%M:%S") or nil,
        stack = stack, locals = locals, inCombat = ns.InCombat(), addon = addonFromText(text) or addonFromText(stack),
        build = ns.Build(), gameTime = GetTime and GetTime() or nil,
        duringCapture = captureState() and 1 or nil, taintLog = taintLogValue() }
    if ns.UISig then local okU, sig = pcall(ns.UISig) if okU then e.uiSig = sig end end   -- v2.2.7: tracker method identity at first hit
    local o = originOf(stack)
    if o then e.origins = { [o] = 1 } end
    -- an error raised by ForeverDump's own code (a ForeverDump frame below the handler frames) counts toward the
    -- self-protection limit: probes/sweeps stop long before the client's ~100 errors/session report cap
    if Err.IsOwn(e) then
        e.addon = ns.ADDON
        if ns.NoteSelfError then ns.NoteSelfError("error", text) end
    end
    ns.Stamp(e)
    log[#log + 1] = e
    index[text] = e
end

-- error object from BugGrabber (message, stack, locals, session, time, counter)
local function captureBugGrabber(obj)
    if type(obj) ~= "table" then return end
    local log = ForeverDumpLogDB and ForeverDumpLogDB.errors
    if not log then return end
    local c = cfg()
    local text = safeString(obj.message, 2000) or "<nil error>"
    index = index or {}
    if not next(index) then for _, e in ipairs(log) do if e.message then index[e.message] = e end end end
    local now = time and time() or nil
    local e = index[text]
    sessionErrors = sessionErrors + 1
    if e then
        e.count = e.count + 1
        e.lastTime = now
        return
    end
    if #log >= (tonumber(c.maxErrors) or 200) then
        ForeverDumpLogDB.droppedErrors = (ForeverDumpLogDB.droppedErrors or 0) + 1
        return
    end
    local stack = safeString(obj.stack, c.maxStack)
    e = { message = text, count = 1, time = now, lastTime = now, date = safeString(obj.time, 40), stack = stack,
        locals = c.captureLocals and safeString(obj.locals, c.maxLocals) or nil, inCombat = ns.InCombat(),
        addon = addonFromText(text) or addonFromText(stack), build = ns.Build(),
        gameTime = GetTime and GetTime() or nil, source = "BugGrabber", bgSession = tonumber(obj.session) }
    ns.Stamp(e)
    log[#log + 1] = e
    index[text] = e
end

local function bugGrabber()
    local bg = rawget(_G, "BugGrabber")
    if type(bg) == "table" then return bg end
end
Err.BugGrabber = bugGrabber

local mode -- "chain" | "buggrabber" (callbacks) | "buggrabber-poll" (copy from GetDB only)

local function noteHandler(what)
    local ev = ForeverDumpLogDB.handlerEvents
    ev[#ev + 1] = { time = time and time() or nil, what = what }
    while #ev > 20 do table.remove(ev, 1) end
end

local function onBugGrabbed(...)
    -- CallbackHandler passes (eventname, errorObject); be lenient about the shape
    local a, b = ...
    local obj = type(a) == "table" and a or b
    if type(obj) == "table" then imported[obj] = true end
    if not inHandler then
        inHandler = true
        pcall(captureBugGrabber, obj)
        inHandler = false
    end
end

local function attachBugGrabber(bg)
    if type(bg.RegisterCallback) ~= "function" and type(bg.setupCallbacks) == "function" then pcall(bg.setupCallbacks) end
    if type(bg.RegisterCallback) == "function" then
        local ok, err = pcall(bg.RegisterCallback, Err, "BugGrabber_BugGrabbed", onBugGrabbed)
        if ok then
            mode = "buggrabber"
            noteHandler("BugGrabber present: registered BugGrabber_BugGrabbed callback")
            return true
        end
        noteHandler("BugGrabber RegisterCallback failed: " .. tostring(err))
    end
    mode = "buggrabber-poll"
    noteHandler("BugGrabber present without callbacks (no CallbackHandler-1.0): errors copied from BugGrabber:GetDB() at OFF/logout")
    return true
end

-- copy BugGrabber's errors for its current session into ForeverDumpLogDB.bugGrabber (and the main log)
function Err.ImportBugGrabber(reason)
    local bg = bugGrabber()
    if not bg or not ForeverDumpLogDB then return nil end
    local okDB, db = pcall(bg.GetDB, bg)
    local okS, sid = pcall(bg.GetSessionId, bg)
    if not okDB or type(db) ~= "table" then return nil end
    sid = okS and tonumber(sid) or nil
    local out = { reason = reason, time = time and time() or nil, session = sid, errors = {}, total = 0 }
    local max = tonumber(cfg().maxErrors) or 200
    for _, obj in ipairs(db) do
        if type(obj) == "table" and (not sid or tonumber(obj.session) == sid) then
            out.total = out.total + 1
            if #out.errors < max then
                out.errors[#out.errors + 1] = { message = safeString(obj.message, 2000), stack = safeString(obj.stack, cfg().maxStack),
                    locals = cfg().captureLocals and safeString(obj.locals, cfg().maxLocals) or nil, counter = tonumber(obj.counter),
                    time = safeString(obj.time, 40), session = tonumber(obj.session) }
                if mode ~= "buggrabber" and not imported[obj] then
                    imported[obj] = true
                    pcall(captureBugGrabber, obj)
                end
            end
        end
    end
    ForeverDumpLogDB.bugGrabber = out
    return out
end

function Err.Mode() return mode end

-- v2.2.11: FD_Logs ON wipes the main log; mark BugGrabber's already-stored errors as seen so a later
-- poll-mode import (OFF/logout) does not put pre-ON errors back into the fresh capture's main log.
-- ForeverDumpLogDB.bugGrabber still copies BugGrabber's whole current session (its own data, labelled).
function Err.MarkBugGrabberSeen()
    local bg = bugGrabber()
    if not bg then return 0 end
    local okDB, db = pcall(bg.GetDB, bg)
    if not okDB or type(db) ~= "table" then return 0 end
    local n = 0
    for _, obj in ipairs(db) do if type(obj) == "table" and not imported[obj] then imported[obj] = true n = n + 1 end end
    return n
end

local function handler(msg, ...)
    sessionErrors = sessionErrors + 1
    if not inHandler then
        inHandler = true
        pcall(capture, msg)
        inHandler = false
    end
    if previous then return previous(msg, ...) end
end

function Err.Install()
    if installed then return true end
    local bg = bugGrabber()
    if bg then
        installed = attachBugGrabber(bg)
        return installed
    end
    mode = "chain"
    local get, set = rawget(_G, "geterrorhandler"), rawget(_G, "seterrorhandler")
    if type(set) ~= "function" then
        ForeverDumpLogDB.handlerEvents[#ForeverDumpLogDB.handlerEvents + 1] = { time = time and time(), what = "seterrorhandler missing" }
        return false
    end
    previous = type(get) == "function" and get() or nil
    local ok, err = pcall(set, handler)
    local ev = ForeverDumpLogDB.handlerEvents
    ev[#ev + 1] = { time = time and time() or nil, what = ok and "installed" or ("seterrorhandler failed: " .. tostring(err)) }
    while #ev > 20 do table.remove(ev, 1) end
    installed = ok
    return ok
end

function Err.Uninstall()
    if not installed then return end
    if mode == "buggrabber" or mode == "buggrabber-poll" then
        local bg = bugGrabber()
        if mode == "buggrabber" and bg and type(bg.UnregisterCallback) == "function" then
            pcall(bg.UnregisterCallback, Err, "BugGrabber_BugGrabbed")
        end
        installed, mode = false, nil
        return
    end
    local get, set = rawget(_G, "geterrorhandler"), rawget(_G, "seterrorhandler")
    if type(get) == "function" and get() == handler and previous then
        pcall(set, previous)
        installed = false
    else
        -- someone chained after us; stay installed but stop capturing
        installed = "passive"
    end
end

function Err.IsInstalled() return installed end

-- v2.2.7: never print from inside the blocked call (run 6: 47 synchronous prints into ChatFrame1 from the blocked
-- CheckInteractDistance stack, each logged as "Execution tainted ... ChatFrame1:AddMessage"). One deferred, throttled line
-- per event+site every 30 s with the count since the last line.
local printGate = {}
local function deferPrint(event, entry)
    local key = event .. "|" .. tostring(entry.site or entry.resolved or entry.args["function"] or "")
    local now = GetTime and GetTime() or 0
    local gte = printGate[key]
    if not gte then gte = { n = 0, t = -1e9 } printGate[key] = gte end
    gte.n = gte.n + 1
    if now - gte.t < 30 then return end
    local n = gte.n
    gte.n, gte.t = 0, now
    local msg = string.format("|cffff8800%s|r %s%s%s%s", event, tostring(entry.args["function"] or ""),
        entry.resolved and (" = " .. entry.resolved .. " (now skipped in combat)") or "",
        entry.site and (" at " .. entry.site) or "", n > 1 and string.format(" (x%d)", n) or "")
    local T = rawget(_G, "C_Timer")
    if type(T) == "table" and type(T.After) == "function" then T.After(0, function() ns.Print(msg) end) else ns.Print(msg) end
end
Err.DeferPrint = deferPrint

local function onBlock(event, ...)
    local log = ForeverDumpLogDB and ForeverDumpLogDB.blocked
    if not log then return end
    if #log >= (tonumber(cfg().maxBlocked) or 500) then
        ForeverDumpLogDB.droppedBlocked = (ForeverDumpLogDB.droppedBlocked or 0) + 1
        return
    end
    local names = BLOCK_EVENTS[event] or {}
    local entry = { event = event, time = time and time() or nil, gameTime = GetTime and GetTime() or nil,
        inCombat = ns.InCombat(), args = {}, duringCapture = captureState(), taintLog = taintLogValue() }
    if ns.Restrictions and event ~= "LUA_WARNING" then
        local okR, st = pcall(ns.Restrictions.States)
        if okR and st then
            local act = {}
            for k, v in pairs(st) do if v ~= 0 then act[#act + 1] = k end end
            table.sort(act)
            entry.restrictions = #act > 0 and table.concat(act, ",") or "none"
        end
    end
    for i = 1, select("#", ...) do
        entry.args[names[i] or i] = ns.SerializeArg and ns.SerializeArg((select(i, ...)), 300) or safeString((select(i, ...)), 300)
    end
    -- v2.2.2: the client names the function "UNKNOWN()" on Forever; attach the probe path that was running (the event is
    -- dispatched synchronously inside the blocked call) and learn it so probes skip it in combat
    local attr = (event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN") and ns.ProbeAttribution and ns.ProbeAttribution()
    if attr and entry.args.addon == ns.ADDON then
        entry.probe = attr
        entry.resolved = string.format("%s:%s(%s)", tostring(attr.module), tostring(attr.path), tostring(attr.unit or ""))
        if ns.LearnBlocked then ns.LearnBlocked(attr, entry.inCombat) end
    end
    local ds = rawget(_G, "debugstack")
    if type(ds) == "function" then
        -- foreign frames in .stack; our own frames (minus this handler) in .ownStack (v2.2.1 dropped them -> UNKNOWN())
        local ok, s = pcall(ds, 2, 20, 10)
        if ok and type(s) == "string" and not ns.IsSecret(s) then
            local keep, own = {}, {}
            for line in string.gmatch(s, "[^\n]+") do
                if string.find(line, "AddOns/" .. ns.ADDON .. "/", 1, true) then
                    if not string.find(line, "Errors.lua", 1, true) and not string.find(line, "Core.lua", 1, true) then own[#own + 1] = line end
                elseif line ~= "[C]: ?" then keep[#keep + 1] = line end
            end
            if #keep > 0 then entry.stack = safeString(table.concat(keep, "\n"), 2000) end
            if #own > 0 then
                entry.ownStack = safeString(table.concat(own, "\n"), 1000)
                -- v2.2.7: innermost own frame that is not the perf wrapper = the call site (run 6: Tokens.lua:296 readToken)
                for _, line in ipairs(own) do
                    if not string.find(line, "Perf.lua", 1, true) then
                        local f, l = string.match(line, "ForeverDump/([%w_/]+%.lua)%]?:(%d+)")
                        if f then entry.site = f .. ":" .. l break end
                    end
                end
            end
        end
    end
    ns.Stamp(entry)
    log[#log + 1] = entry
    if event ~= "LUA_WARNING" and event ~= "ADDON_RESTRICTION_STATE_CHANGED" then
        deferPrint(event, entry)
    end
end

for ev in pairs(BLOCK_EVENTS) do
    ns.On(ev, function(event, ...)
        if not (ns.config and ns.config.errors and ns.config.errors.enabled) then return end
        onBlock(event, ...)
    end)
end

ns.On("ADDON_LOADED", function(_, name)
    if name == ns.ADDON and ns.config.errors.enabled then Err.Install() end
end)

-- BugGrabber re-installs its handler at PLAYER_LOGIN; if it showed up after us, switch to its callbacks
ns.On("PLAYER_LOGIN", function()
    if not (ns.config and ns.config.errors and ns.config.errors.enabled) then return end
    local bg = bugGrabber()
    if bg and mode == "chain" then
        installed = false
        previous = nil
        Err.Install()
    end
end)

ns.On("PLAYER_LOGOUT", function()
    if mode == "buggrabber-poll" then pcall(Err.ImportBugGrabber, "logout") end
end)

function Err.Status()
    local log = ForeverDumpLogDB or {}
    local total = 0
    for _, e in ipairs(log.errors or {}) do total = total + (e.count or 0) end
    ns.Print(string.format("errors: handler %s (mode %s, enabled=%s); %d unique errors (%d total, %d this session, %d dropped); "
        .. "%d blocked/forbidden/warning events (%d dropped)",
        tostring(installed), tostring(mode), tostring(ns.config.errors.enabled), #(log.errors or {}), total, sessionErrors,
        log.droppedErrors or 0, #(log.blocked or {}), log.droppedBlocked or 0))
end

function Err.Clear()
    ForeverDumpLogDB.errors, ForeverDumpLogDB.blocked = {}, {}
    ForeverDumpLogDB.droppedErrors, ForeverDumpLogDB.droppedBlocked = nil, nil
    index = {}
end

function Err.Text()
    local lines = { "==== ERRORS ====" }
    for _, e in ipairs(ForeverDumpLogDB.errors or {}) do
        lines[#lines + 1] = string.format("[%dx] %s", e.count or 1, tostring(e.message))
        if e.stack then lines[#lines + 1] = e.stack end
        if e.locals then lines[#lines + 1] = "Locals:\n" .. e.locals end
        lines[#lines + 1] = ""
    end
    lines[#lines + 1] = "==== BLOCKED / FORBIDDEN / WARNINGS ===="
    for _, b in ipairs(ForeverDumpLogDB.blocked or {}) do
        local parts = {}
        for k, v in pairs(b.args or {}) do parts[#parts + 1] = tostring(k) .. "=" .. tostring(v) end
        table.sort(parts)
        lines[#lines + 1] = string.format("%s %s %s", tostring(b.date or b.time), b.event, table.concat(parts, " "))
    end
    return table.concat(lines, "\n")
end
