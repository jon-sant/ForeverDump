-- BugGrabber/BugSack coexistence test (both paths). usage: lua5.1 tests/buggrabber.lua ForeverDump
-- Path A: no BugGrabber -> ForeverDump chains seterrorhandler and still calls the previous handler.
-- Path B: a BugGrabber clone (same API shape as funkydude/BugGrabber: seterrorhandler becomes a no-op, its handler is
--         re-installed at PLAYER_LOGIN, callbacks via setupCallbacks()/RegisterCallback with (eventname, errorObject),
--         GetDB()/GetSessionId()) -> ForeverDump registers BugGrabber_BugGrabbed, never fights over the handler, and
--         FD_Logs OFF copies BugGrabber's session errors. Path C: BugGrabber without CallbackHandler -> poll mode.
package.path = "./tests/?.lua;" .. package.path
local addonDir = arg[1] or "ForeverDump"
local mode = arg[2]
local failures = 0
local function check(cond, msg)
    if cond then print("  ok   " .. msg) else failures = failures + 1 print("  FAIL " .. msg) end
end
local function tocFiles()
    local files = {}
    for line in io.lines(addonDir .. "/ForeverDump.toc") do
        if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
    end
    return files
end

if not mode then
    -- run each path in its own process (the harness keeps global state)
    local ok = true
    for _, m in ipairs({ "chain", "callbacks", "poll" }) do
        local r = os.execute("lua5.1 tests/buggrabber.lua " .. addonDir .. " " .. m)
        if r ~= 0 and r ~= true then ok = false end
    end
    print(ok and "BUGGRABBER OK" or "BUGGRABBER FAILED")
    os.exit(ok and 0 or 1)
end

local W = require("wowenv")

local function fakeBugGrabber(withCallbacks)
    local real_set = seterrorhandler
    local db, session, callbacks, registry = {}, 7, nil, {}
    local addon = {}
    local function fire(event, ...)
        for _, fn in pairs(registry[event] or {}) do fn(event, ...) end
    end
    local function grab(msg)
        local o = { message = tostring(msg), stack = "[string \"Interface/AddOns/Other/x.lua\"]:1: in main chunk",
            locals = "x = 1", session = session, time = "2026/10/07 19:00:00", counter = 1 }
        db[#db + 1] = o
        fire("BugGrabber_BugGrabbed", o)
    end
    addon.setupCallbacks = function()
        if not callbacks and withCallbacks then
            callbacks = true
            addon.RegisterCallback = function(self, event, fn) registry[event] = registry[event] or {} registry[event][self] = fn end
            addon.UnregisterCallback = function(self, event) if registry[event] then registry[event][self] = nil end end
        end
    end
    function addon:GetDB() return db end
    function addon:GetSessionId() return session end
    addon.grab = grab
    addon.db = db
    db[1] = { message = "old error from session 6", session = 6, counter = 3 }
    real_set(grab)
    seterrorhandler = function() end -- BugGrabber makes it a no-op
    _G.BugGrabber = setmetatable({}, { __index = addon, __newindex = function() error("Modifications not allowed.") end })
    return addon, function() real_set(grab) end -- PLAYER_LOGIN re-install
end

local bg, relogin
if mode ~= "chain" then
    bg, relogin = fakeBugGrabber(mode == "callbacks")
end
local ns = W.loadAddon(addonDir, tocFiles(), "ForeverDump")
W.fire("ADDON_LOADED", "ForeverDump")
if relogin then relogin() end
W.fire("PLAYER_LOGIN")

print("path: " .. mode)
if mode == "chain" then
    check(ns.Errors.Mode() == "chain", "no BugGrabber: chained mode")
    local before = W.state.errorsShown or 0
    W.raiseError("Interface/AddOns/Other/a.lua:1: boom")
    check(#ForeverDumpLogDB.errors == 1 and ForeverDumpLogDB.errors[1].addon == "Other", "error captured via seterrorhandler")
    check((W.state.errorsShown or 0) == before + 1, "previous handler still called")
else
    check(ns.Errors.Mode() == (mode == "callbacks" and "buggrabber" or "buggrabber-poll"), "BugGrabber detected: mode " .. tostring(ns.Errors.Mode()))
    W.raiseError("Interface/AddOns/Other/b.lua:2: kaboom")
    check(#bg.db == 2, "BugGrabber still owns the handler (stored the error)")
    if mode == "callbacks" then
        check(#ForeverDumpLogDB.errors == 1 and ForeverDumpLogDB.errors[1].source == "BugGrabber"
            and ForeverDumpLogDB.errors[1].addon == "Other", "error captured through BugGrabber_BugGrabbed")
    else
        check(#ForeverDumpLogDB.errors == 0, "poll mode: nothing captured live")
    end
    -- FD_Logs ON/OFF copies BugGrabber's current-session errors
    W.slash("logs on")
    W.runUntilIdle(ns)
    -- v2.2.11: ON wiped the main log, so the pre-ON error is gone from it (BugGrabber keeps it)
    check(#ForeverDumpLogDB.errors == 0, "ON wiped the pre-ON error from the main log (" .. #ForeverDumpLogDB.errors .. ")")
    W.raiseError("Interface/AddOns/Other/c.lua:3: kaboom2")
    check(#bg.db == 3, "BugGrabber still owns the handler during capture")
    W.slash("logs off")
    local imp = ForeverDumpLogDB.bugGrabber
    check(imp and imp.session == 7 and #imp.errors == 2 and imp.errors[1].message:find("kaboom") and imp.errors[2].message:find("kaboom2"),
        "OFF copied BugGrabber session 7 errors only")
    check(#ForeverDumpLogDB.errors == 1 and ForeverDumpLogDB.errors[1].message:find("kaboom2"),
        "in-capture error present once in the main log, pre-ON error not re-imported (" .. #ForeverDumpLogDB.errors .. ")")
    W.slash("errors bg")
    check(ForeverDumpLogDB.bugGrabber.reason == "command", "/fdump errors bg re-imports")
    check(ForeverDumpLogDB.errors[1].count == 1, "re-import does not inflate counts")
end
check(#(ForeverDumpDB.errors or {}) == 0, "ForeverDump itself logged no errors")
if failures > 0 then print("FAILED " .. failures) os.exit(1) end
print("path " .. mode .. " OK")
