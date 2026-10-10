-- v2.2.7 regression (run 6): no combat-protected API from capture/hot paths while combat-locked, deferred blocked prints,
-- no `os` dependency, read-only UI signature. usage: lua5.1 tests/combat_guard.lua ForeverDump
package.path = "./tests/?.lua;" .. package.path
local addonDir = arg[1] or "ForeverDump"
local fails, passed = 0, 0
local function check(c, m) if c then passed = passed + 1 print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end
local W = require("wowenv")
local S = W.state
local function tocFiles(dir)
    local files = {}
    for line in io.lines(dir .. "/ForeverDump.toc") do
        if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
    end
    return files
end
-- mock: CheckInteractDistance counts calls per combat state; in combat it behaves like the client (blocked event)
local calls = { out = 0, combat = 0, affecting = 0 }
local affecting = false
UnitAffectingCombat = function(u) return u == "player" and (S.combat or affecting) end
CheckInteractDistance = function()
    if S.combat then calls.combat = calls.combat + 1 W.fire("ADDON_ACTION_BLOCKED", "ForeverDump", "UNKNOWN()")
    elseif affecting then calls.affecting = calls.affecting + 1
    else calls.out = calls.out + 1 end
    return true
end
local ns = W.loadAddon(addonDir, tocFiles(addonDir), "ForeverDump")
W.fire("ADDON_LOADED", "ForeverDump")
W.fire("PLAYER_LOGIN")
W.fire("PLAYER_ENTERING_WORLD", true, false)
ns.config.logs.fullDump = false
ns.config.logs.autoReload = false
W.slash("logs on")
for _ = 1, 20 do W.tick(1) end
local Scan, WC = ns.Tokens and ns.Tokens.Scan, ns.WorldCapture
check(Scan and Scan.Slice and WC and WC.Slice, "token scanner + world capture loaded")
-- guard API
check(ns.CombatGuard("CheckInteractDistance", false) == nil, "CombatGuard: out of combat -> allowed")
check(ns.CombatGuard("CheckInteractDistance", true) == "combat-protected", "CombatGuard: locked -> combat-protected")
check(ns.CombatGuard("UnitHealth", true) == nil, "CombatGuard: unprotected API allowed in combat")
-- out of combat: protected range read is used (range bands keep working)
for _ = 1, 200 do pcall(Scan.Slice) pcall(WC.Slice) end
check(calls.out > 0, "out of combat: CheckInteractDistance read by scanner/world capture (" .. calls.out .. " calls)")
-- combat (lockdown): zero calls, zero ADDON_ACTION_BLOCKED
local blocked0 = #(ForeverDumpLogDB.blocked or {})
S.combat = true
W.fire("PLAYER_REGEN_DISABLED")
local printed, realPrint = 0, ns.Print
ns.Print = function(...) printed = printed + 1 return realPrint(...) end
for _ = 1, 400 do pcall(Scan.Slice) pcall(WC.Slice) end
check(calls.combat == 0, "in combat (lockdown): 0 CheckInteractDistance calls from capture paths (got " .. calls.combat .. ")")
local nb = 0
for i = blocked0 + 1, #(ForeverDumpLogDB.blocked or {}) do
    if (ForeverDumpLogDB.blocked[i].event or "") == "ADDON_ACTION_BLOCKED" then nb = nb + 1 end
end
check(nb == 0, "in combat: no ADDON_ACTION_BLOCKED recorded (" .. nb .. ")")
check((Scan.cur and (Scan.cur.guardSkips or 0) or 0) > 0 and (WC.state.guardSkips or 0) > 0,
    "guard skips counted (scanner " .. tostring(Scan.cur and Scan.cur.guardSkips) .. ", world " .. tostring(WC.state.guardSkips) .. ")")
-- combat flag from UnitAffectingCombat before lockdown (the first frames of a pull)
S.combat = false
affecting = true
for _ = 1, 200 do pcall(Scan.Slice) pcall(WC.Slice) end
check(calls.affecting == 0, "player affecting combat (no lockdown yet): 0 calls (got " .. calls.affecting .. ")")
affecting = false
-- blocked event (synthetic): recorded with own site, printed deferred + throttled (never inside the blocked call)
printed = 0
S.timers = {}
for _ = 1, 10 do W.fire("ADDON_ACTION_BLOCKED", "ForeverDump", "UNKNOWN()") end
check(printed == 0, "ADDON_ACTION_BLOCKED: no synchronous print (" .. printed .. ")")
for _, fn in ipairs(S.timers) do pcall(fn) end
check(printed <= 1, "ADDON_ACTION_BLOCKED x10: at most one deferred line (" .. printed .. ")")
ns.Print = realPrint
-- no os table (WoW): Drift decay + perf clock fallback keep working
local savedOs = os
_G.os = nil
local okD, conf = pcall(ns.Drift.Decay, "high", ns.Build(), "2026-01-01")
_G.os = savedOs
check(okD and type(conf) == "string", "Drift.Decay without `os` (run 6: attempt to index global 'os'): " .. tostring(conf))
-- read-only UI signature: '=' when instance method is the mixin's, 'W' when wrapped; never writes
BonusObjectiveTrackerMixin = { LayoutContents = function() end }
BonusObjectiveTracker = { LayoutContents = BonusObjectiveTrackerMixin.LayoutContents }
local sig1 = ns.UISig()
local orig = BonusObjectiveTracker.LayoutContents
BonusObjectiveTracker.LayoutContents = function(...) return orig(...) end   -- what a hooksecurefunc trampoline looks like
local sig2 = ns.UISig()
check(sig1:find("Bonus=", 1, true) and sig2:find("BonusW", 1, true), "UISig: Bonus '=' then 'W' after a wrap (" .. sig1 .. " | " .. sig2 .. ")")
check(BonusObjectiveTrackerMixin.LayoutContents ~= nil and rawget(BonusObjectiveTracker, "LayoutContents") ~= nil, "UISig wrote nothing")
W.slash("logs off")
local ui = ForeverDumpLogDB.uiIntegrity or {}
local haveOn, haveOff = false, false
for _, r in ipairs(ui) do if r.where == "capture:on:after" then haveOn = true end if r.where == "capture:off" then haveOff = true end end
check(haveOn and haveOff, "uiIntegrity recorded at capture ON and OFF (" .. #ui .. " rows)")
print(string.format("combat_guard: %d passed, %d failed", passed, fails))
os.exit(fails == 0 and 0 or 1)
