-- v2.2.8 regression (runs 6/6b follow-up, proposals 1 + 8): the live HSM survives a failing helper module, a dead
-- engine is shown (chat line, HSM window, tape header), and the guard + engine counters land in the replay tape header
-- at OFF. usage: lua5.1 tests/hsm_health.lua ForeverDump degraded|down|guard
package.path = "./tests/?.lua;" .. package.path
local addonDir, mode = arg[1] or "ForeverDump", arg[2] or "degraded"
local fails, passed = 0, 0
local function check(c, m) if c then passed = passed + 1 print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end
local W = require("wowenv")
local S = W.state
local exit, clock = os.exit, os.clock
local files = {}
for line in io.lines(addonDir .. "/ForeverDump.toc") do
    if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
end
debugprofilestop = function() return clock() * 1000 end
_G.os = nil   -- the client has no os table
local MOB = "Creature-0-0000-0000-00000-3260-0000000001"
local realGUID = UnitGUID
UnitGUID = function(u) if u == "target" then return MOB end return realGUID(u) end
UnitExists = function(u) return u == "player" or u == "target" end
UnitCanAttack = function(_, u) return u == "target" end
UnitAffectingCombat = function(u) return u == "player" and S.combat end
local cidCombat = 0
CheckInteractDistance = function() if S.combat then cidCombat = cidCombat + 1 end return true end
local ns = W.loadAddon(addonDir, files, "ForeverDump")
W.fire("ADDON_LOADED", "ForeverDump") W.fire("PLAYER_LOGIN") W.fire("PLAYER_ENTERING_WORLD", true, false)
ns.config.logs.fullDump = false ns.config.logs.autoReload = false
if ns.config.static then ns.config.static.auto = false end
local lines, realPrint = {}, ns.Print
ns.Print = function(...) lines[#lines + 1] = table.concat({ ... }, " ") return realPrint(...) end
local function printed(pat) for _, l in ipairs(lines) do if l:find(pat) then return true end end return false end
if mode == "degraded" then
    ns.Timing.Attach = function() error("injected: Timing.Attach failed (the run-6 Drift/os class)") end
elseif mode == "down" then
    local Lib = rawget(_G, "HybridState")
    Lib.New = function() error("injected: HybridState.New failed") end
end
local okOn, errOn = pcall(W.slash, "logs on")
check(okOn, "capture ON does not raise (" .. tostring(errOn) .. ")")
for _ = 1, 30 do W.tick(1) end
local I = ns.Inference
local H = I and I.Health and I.Health()
W.fire("PLAYER_TARGET_CHANGED")
S.combat = true
W.fire("PLAYER_REGEN_DISABLED")
for i = 1, 6 do
    S.time = S.time + 1.5
    W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-" .. i, 8042)
    W.fire("UNIT_COMBAT", "target", "WOUND", "", 40 + i, 8)
    W.fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 0, 1)
    W.tick(2)
end
if mode == "guard" then
    for _ = 1, 300 do pcall(ns.Tokens.Scan.Slice) pcall(ns.WorldCapture.Slice) end
end
local f = I.hs and I.hs.fights and I.hs.fights[#I.hs.fights]
local mine = f and f.dmg and f.dmg.mine or 0
local uiText = ns.HSMUI and ns.HSMUI.Text and select(2, pcall(ns.HSMUI.Text)) or ""
S.combat = false
W.fire("PLAYER_REGEN_ENABLED")
for _ = 1, 10 do W.tick(1) end
W.slash("logs off")
for _ = 1, 10 do W.tick(1) end
local tapes = ForeverDumpLogDB.replay and ForeverDumpLogDB.replay.sessions or {}
local hdr = tapes[#tapes] and tapes[#tapes].hdr or {}
local st = hdr.stats or {}
check(type(hdr.stats) == "table" and hdr.stats.v == 1, "tape header carries stats at OFF")
check(type(st.guard) == "table" and type(st.guard.worldCapture) == "number" and type(st.guard.tokenScan) == "number",
    "guard counters saved (tokenScan " .. tostring(st.guard and st.guard.tokenScan) .. ", worldCapture " .. tostring(st.guard and st.guard.worldCapture) .. ")")
check(type(st.selfErrors) == "number", "selfError count for this capture saved (" .. tostring(st.selfErrors) .. ")")
if mode == "degraded" then
    check(H and H.state == "degraded", "helper failure -> state degraded (" .. tostring(H and H.state) .. ")")
    check(I.hs ~= nil and mine > 0, "HSM still attributes my hits with Timing failed (mine=" .. tostring(mine) .. ")")
    check(printed("engine degraded") and printed("Timing"), "one chat line names the failed helper")
    check(uiText:find("engine degraded", 1, true) ~= nil, "HSM window shows engine degraded")
    check(st.hsm == "degraded" and st.hsmFailed and st.hsmFailed[1] == "Timing", "tape header: hsm=degraded, failed={Timing}")
    check(type(st.counters) == "table" and (st.counters.inferences or 0) > 0, "tape header: HSM counters saved")
    local nSelf = 0
    for _, e in ipairs(ForeverDumpLogDB.selfErrors or {}) do if tostring(e.where) == "hsm:Timing" then nSelf = nSelf + 1 end end
    check(nSelf == 1 and st.selfErrors >= 1, "failure recorded as selfError where=hsm:Timing")
elseif mode == "down" then
    check(H and H.state == "down", "HybridState.New failure -> state down (" .. tostring(H and H.state) .. ")")
    check(I.hs == nil and not I.running, "no half-started engine")
    check(printed("ENGINE DOWN"), "chat line ENGINE DOWN")
    check(uiText:find("ENGINE DOWN", 1, true) ~= nil, "HSM window shows ENGINE DOWN")
    check(st.hsm == "down" and st.hsmRunning == false, "tape header: hsm=down, not running")
    local nDown = 0
    for _, l in ipairs(lines) do if l:find("ENGINE DOWN", 1, true) then nDown = nDown + 1 end end
    check(nDown == 1, "warned exactly once (" .. nDown .. ")")
elseif mode == "guard" then
    check(H and H.state == "up", "healthy capture -> state up (" .. tostring(H and H.state) .. ")")
    check(not printed("ENGINE DOWN") and not printed("engine degraded"), "no health warning when healthy")
    check(cidCombat == 0, "0 CheckInteractDistance calls in combat (" .. cidCombat .. ")")
    check((st.guard.worldCapture or 0) > 0 and (st.guard.tokenScan or 0) > 0, "guard skips in combat persisted in the tape header")
    check(st.hsm == "up" and (st.counters.inferences or 0) > 0, "tape header: hsm=up with counters")
end
print(string.format("hsm health (%s): %d passed, %d failed", mode, passed, fails))
exit(fails == 0 and 0 or 1)
