-- v2.2.7 regression (runs 6 + 6b): the whole capture runs WITHOUT the `os` table (WoW has none) and the live HSM must
-- actually start, see my casts / hits on the target, record signals (target timeline) and export at OFF.
-- Runs 6/6b: Timing.Attach -> Drift.Decay -> os.time raised inside I.NewHSM at every capture start, so the engine
-- never ran (0 of 11 own hits seen live, no decide/verdict records, no signals) and nothing flagged it.
-- usage: lua5.1 tests/hsm_alive.lua ForeverDump
package.path = "./tests/?.lua;" .. package.path
local addonDir = arg[1] or "ForeverDump"
local fails, passed = 0, 0
local function check(c, m) if c then passed = passed + 1 print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end
local W = require("wowenv")
local S = W.state
local exit, clock = os.exit, os.clock
local files = {}
for line in io.lines(addonDir .. "/ForeverDump.toc") do
    if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
end
-- the client has no os table: remove it for the whole addon lifetime (harness keeps private copies)
debugprofilestop = function() return clock() * 1000 end
_G.os = nil
local MOB = "Creature-0-0000-0000-00000-3260-0000000001"
local realGUID = UnitGUID
UnitGUID = function(u) if u == "target" then return MOB end return realGUID(u) end
UnitExists = function(u) return u == "player" or u == "target" end
UnitCanAttack = function(_, u) return u == "target" end
local ns = W.loadAddon(addonDir, files, "ForeverDump")
W.fire("ADDON_LOADED", "ForeverDump")
W.fire("PLAYER_LOGIN")
W.fire("PLAYER_ENTERING_WORLD", true, false)
ns.config.logs.fullDump = false
ns.config.logs.autoReload = false
if ns.config.static then ns.config.static.auto = false end
check(type(ns.SpellTimingSeed) == "table" and next(ns.SpellTimingSeed.spells or {}) ~= nil,
    "shipped spell-timing seed is loaded (its lastSeen dates drive Drift.Decay)")
W.slash("logs on")
for _ = 1, 30 do W.tick(1) end
local I = ns.Inference
local selfErr = {}
for _, e in ipairs(ForeverDumpLogDB.selfErrors or {}) do selfErr[#selfErr + 1] = tostring(e.where) .. ": " .. tostring(e.err) end
check(#selfErr == 0, "no self error at capture start (" .. (selfErr[1] or "none") .. ")")
check(I and I.hs ~= nil and I.running == true, "live HSM started and running during the capture")
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
S.combat = false
W.fire("PLAYER_REGEN_ENABLED")
for _ = 1, 30 do W.tick(1) end
local f = I.hs and I.hs.fights and I.hs.fights[#I.hs.fights]
check(f and f.dmg and f.dmg.mine and f.dmg.mine > 0, "live HSM attributed my hits on the target (mine=" .. tostring(f and f.dmg and f.dmg.mine) .. ")")
W.slash("logs off")
for _ = 1, 10 do W.tick(1) end
local d = ForeverDumpLogDB.inference or {}
local nTarget, nSig = 0, 0
for _, s in ipairs(d.signals or {}) do nSig = nSig + 1 if s.e == "target" then nTarget = nTarget + 1 end end
check(nSig > 0 and nTarget > 0, "signals recorded incl. the target timeline (" .. nSig .. " signals, " .. nTarget .. " target)")
check(type(d.counters) == "table" and type(d.inferences) == "table" and #d.inferences > 0, "HSM exported at OFF (counters + inferences)")
local kinds = {}
local tapes = ForeverDumpLogDB.replay and ForeverDumpLogDB.replay.sessions or {}
local last = tapes[#tapes]
for _, r in ipairs(last and last.tape or {}) do kinds[r.k] = (kinds[r.k] or 0) + 1 end
check((kinds.decide or 0) > 0, "replay tape carries HSM decide records (" .. tostring(kinds.decide) .. ")")
selfErr = {}
for _, e in ipairs(ForeverDumpLogDB.selfErrors or {}) do selfErr[#selfErr + 1] = tostring(e.where) .. ": " .. tostring(e.err) end
check(#selfErr == 0, "no self error during the whole capture (" .. (selfErr[1] or "none") .. ")")
print(string.format("hsm alive: %d passed, %d failed", passed, fails))
exit(fails == 0 and 0 or 1)
