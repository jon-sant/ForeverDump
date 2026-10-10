p='/workspace/foreverdump/ForeverDump/Errors.lua'; s=open(p).read()
a='''-- ADDON_RESTRICTION_STATE_CHANGED into ForeverDumpLogDB.blocked. Secret values are never touched.'''
b='''-- ADDON_RESTRICTION_STATE_CHANGED into ForeverDumpLogDB.blocked. Secret values are never touched.
-- BugGrabber/BugSack: when !BugGrabber is loaded it owns the error handler (it replaces seterrorhandler with a no-op
-- and re-installs its own handler at PLAYER_LOGIN), so ForeverDump registers for its CallbackHandler event
-- "BugGrabber_BugGrabbed" instead (BugGrabber.setupCallbacks() makes BugGrabber.RegisterCallback appear when some
-- addon such as BugSack ships CallbackHandler-1.0). Without callbacks, BugGrabber's session errors are still copied
-- from BugGrabber:GetDB() on FD_Logs OFF / logout / "/fdump errors bg". Without BugGrabber the handler is chained.'''
assert a in s; s=s.replace(a,b)
a='''local function handler(msg, ...)'''
b='''-- error object from BugGrabber (message, stack, locals, session, time, counter)
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
        addon = addonFromText(text) or addonFromText(stack), build = ns.Meta().build,
        gameTime = GetTime and GetTime() or nil, source = "BugGrabber", bgSession = tonumber(obj.session) }
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
                if mode ~= "buggrabber" then pcall(captureBugGrabber, obj) end
            end
        end
    end
    ForeverDumpLogDB.bugGrabber = out
    return out
end

function Err.Mode() return mode end

local function handler(msg, ...)'''
assert a in s; s=s.replace(a,b)
a='''function Err.Install()
    if installed then return true end
    local get, set = rawget(_G, "geterrorhandler"), rawget(_G, "seterrorhandler")'''
b='''function Err.Install()
    if installed then return true end
    local bg = bugGrabber()
    if bg then
        installed = attachBugGrabber(bg)
        return installed
    end
    mode = "chain"
    local get, set = rawget(_G, "geterrorhandler"), rawget(_G, "seterrorhandler")'''
assert a in s; s=s.replace(a,b)
a='''function Err.Uninstall()
    if not installed then return end'''
b='''function Err.Uninstall()
    if not installed then return end
    if mode == "buggrabber" or mode == "buggrabber-poll" then
        local bg = bugGrabber()
        if mode == "buggrabber" and bg and type(bg.UnregisterCallback) == "function" then
            pcall(bg.UnregisterCallback, Err, "BugGrabber_BugGrabbed")
        end
        installed, mode = false, nil
        return
    end'''
assert a in s; s=s.replace(a,b)
a='''ns.On("ADDON_LOADED", function(_, name)
    if name == ns.ADDON and ns.config.errors.enabled then Err.Install() end
end)'''
b='''ns.On("ADDON_LOADED", function(_, name)
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
end)'''
assert a in s; s=s.replace(a,b)
a='''    ns.Print(string.format("errors: handler %s (enabled=%s); %d unique errors (%d total, %d this session, %d dropped); "
        .. "%d blocked/forbidden/warning events (%d dropped)",
        tostring(installed), tostring(ns.config.errors.enabled),'''
b='''    ns.Print(string.format("errors: handler %s (mode %s, enabled=%s); %d unique errors (%d total, %d this session, %d dropped); "
        .. "%d blocked/forbidden/warning events (%d dropped)",
        tostring(installed), tostring(mode), tostring(ns.config.errors.enabled),'''
assert a in s; s=s.replace(a,b)
open(p,'w').write(s)
print("ok")
