-- v2.2.9 regression (run 8, battleground): ForeverDump's error handler frames never make an error "ours", and the
-- FD_Logs macro never carries a stale /combatlog toggle.
--   stack: every stored stack used to start with Errors.lua frames + [C] pcall + "[C]: ?"; Health counted all 3354 BG
--          errors (TweaksForever/Questie/ObjectiveTracker) as own errors and the tracker nil-call as "inside [C] pcall".
--   macro: the macro body was written at login with "/combatlog" (log was off); the user typed /combatlog by hand; the
--          ON click then switched the BG combat log OFF (WoWCombatLog.txt ends at the ON click).
-- usage: lua5.1 tests/run8_regress.lua ForeverDump stack|macro
package.path = "./tests/?.lua;" .. package.path
local addonDir, mode = arg[1] or "ForeverDump", arg[2] or "stack"
local fails, passed = 0, 0
local function check(c, m) if c then passed = passed + 1 print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end
local W = require("wowenv")
local S = W.state
local exit, clock = os.exit, os.clock
debugprofilestop = function() return clock() * 1000 end
local files = {}
for line in io.lines(addonDir .. "/ForeverDump.toc") do
    if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
end
_G.os = nil   -- the client has no os table
local ns = W.loadAddon(addonDir, files, "ForeverDump")
W.fire("ADDON_LOADED", "ForeverDump") W.fire("PLAYER_LOGIN") W.fire("PLAYER_ENTERING_WORLD", true, false)
ns.config.logs.fullDump = false
if ns.config.static then ns.config.static.auto = false end
local lines, realPrint = {}, ns.Print
ns.Print = function(...) lines[#lines + 1] = table.concat({ ... }, " ") return realPrint(...) end
local function printed(pat) for _, l in ipairs(lines) do if l:find(pat) then return true end end return false end
for _ = 1, 5 do W.tick(1) end

if mode == "stack" then
    -- exact run-8 shape: our handler prefix, then the real frames
    local PREFIX = "[Interface/AddOns/ForeverDump/Errors.lua]:119: in function <Interface/AddOns/ForeverDump/Errors.lua:78>\n"
        .. "[C]: in function 'pcall'\n"
        .. "[Interface/AddOns/ForeverDump/Errors.lua]:251: in function <Interface/AddOns/ForeverDump/Errors.lua:247>\n"
        .. "[C]: ?\n"
    local REAL = {
        nilcall = "[C]: in function 'LayoutContents'\n"
            .. "[Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerModule.lua]:147: in function 'Update'\n",
        tweaks = "[Interface/AddOns/TweaksForever/UI/Tooltips.lua]:201: in function <Interface/AddOns/TweaksForever/UI/Tooltips.lua:196>\n"
            .. "[C]: in function 'securecallfunction'\n",
        own = "[Interface/AddOns/ForeverDump/Tokens.lua]:42: in function 'Slice'\n[C]: in function 'pcall'\n",
    }
    local cur
    local ds = debugstack
    debugstack = function() return PREFIX .. REAL[cur] end
    cur = "nilcall" for _ = 1, 115 do W.raiseError("attempt to call a nil value") end
    cur = "tweaks"
    for _ = 1, 30 do
        W.raiseError("Interface/AddOns/TweaksForever/UI/Tooltips.lua:201: attempt to perform arithmetic on upvalue 'r' (a secret number value)")
    end
    debugstack = ds
    local byMsg = {}
    for _, e in ipairs(ForeverDumpLogDB.errors) do byMsg[e.message] = e end
    local nc = byMsg["attempt to call a nil value"]
    check(nc and type(nc.stack) == "string" and not nc.stack:find("ForeverDump", 1, true),
        "stored stack has no ForeverDump handler frames (" .. tostring(nc and nc.stack and nc.stack:sub(1, 40)) .. ")")
    check(nc and nc.stack:find("^%[C%]: in function 'LayoutContents'") ~= nil, "stored stack starts at the real frame")
    local okey
    for k in pairs(nc and nc.origins or {}) do okey = k end
    check(okey and not okey:find("pcall", 1, true) and okey:find("LayoutContents", 1, true) ~= nil,
        "origin is the real call site, not our pcall (" .. tostring(okey) .. ")")
    check(nc and nc.addon == "Blizzard_ObjectiveTracker", "nil-call attributed to Blizzard_ObjectiveTracker (" .. tostring(nc and nc.addon) .. ")")
    local h = ns.Restrictions.Health()
    check(h.ownErrors == 0, "Health: 0 own errors when every error is another addon's (got " .. tostring(h.ownErrors) .. ")")
    check(h.nilCallInCFunction and h.nilCallInCFunction.LayoutContents == 115 and not h.nilCallInCFunction.pcall,
        "Health: nil-call classified inside [C] LayoutContents, not pcall")
    local once = ns.Errors.StripOwn(PREFIX .. REAL.own)
    check(once == REAL.own:gsub("\n$", "") and ns.Errors.StripOwn(once) == once, "StripOwn removes only the handler prefix and is idempotent")
    check(ns.Errors.IsOwn({ message = "x", stack = PREFIX .. REAL.tweaks }) == false, "IsOwn: legacy v2.2.7 stack with our prefix is not own")
    -- a genuine ForeverDump error still counts (message names our file, or our frame below the handler prefix)
    local self0 = ns.selfErrors or 0
    cur = "own" debugstack = function() return PREFIX .. REAL[cur] end
    W.raiseError("attempt to index a nil value")
    debugstack = ds
    local own = nil
    for _, e in ipairs(ForeverDumpLogDB.errors) do if e.message == "attempt to index a nil value" then own = e end end
    check(own and own.addon == "ForeverDump", "own error (ForeverDump frame below the prefix) attributed to ForeverDump")
    check((ns.selfErrors or 0) > self0, "own error counted toward the self-protection limit")
    check(ns.Restrictions.Health().ownErrors == 1, "Health: exactly the one own error")
    check(ns.Errors.IsOwn({ message = "Interface/AddOns/ForeverDump/Core.lua:1: boom" }), "IsOwn: message naming our file")
elseif mode == "macro" then
    S.logging, S.chatLogging = false, false
    ns.Logs.EnsureMacro(true)
    local function body() return S.macros[GetMacroIndexByName("FD_Logs")].body end
    check(body():find("/combatlog", 1, true) ~= nil, "macro written while the combat log is off carries /combatlog")
    -- the user switches the combat log on by hand (Blizzard's /combatlog prints the system message)
    SlashCmdList.COMBATLOG("")
    for _ = 1, 5 do W.tick(1) end
    check(S.logging == true, "combat log on by hand")
    check(not body():find("/combatlog", 1, true), "macro refreshed: no stale /combatlog after the hand toggle")
    W.clickMacro("FD_Logs")
    for _ = 1, 5 do W.tick(1) end
    check(ns.db.logs.on == true, "ON click started the capture")
    check(S.logging == true, "ON click left the hand-enabled combat log ON (run 8 switched it OFF)")
    -- no system message (e.g. the log was switched without the chat line): the click must say so loudly
    ns.config.logs.autoReload = false
    W.clickMacro("FD_Logs")   -- OFF
    for _ = 1, 5 do W.tick(1) end
    S.logging = false
    ns.Logs.EnsureMacro(true)
    S.logging = true            -- changed behind the addon's back; macro still carries /combatlog
    lines = {}
    W.clickMacro("FD_Logs")
    for _ = 1, 5 do W.tick(1) end
    check(ns.db.logs.staleToggle ~= nil, "stale toggle recorded in the capture state")
    check(printed("already ON, so this click's macro line switches it OFF"), "red warning printed before the toggle runs")
    check(printed("FD_Logs switched it off because it was already on"), "verify line names the cause and the fix")
    check(ns.Logs.IsLogToggleMessage("Combat being logged to Logs\\WoWCombatLog.txt") and not ns.Logs.IsLogToggleMessage("You have joined"),
        "log-toggle system messages recognised, others ignored")
end
print(string.format("run8 %s: %d passed, %d failed", mode, passed, fails))
exit(fails == 0 and 0 or 1)
