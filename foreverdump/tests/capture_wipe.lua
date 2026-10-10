-- v2.2.11 (user decision): FD_Logs ON starts every capture CLEAN.
--   ON wipes: all ForeverDumpLogDB tables, recorder + combat recorder sessions, ForeverDumpDB verify / secretsObs /
--   secretsLive / tokenscan / identities, sections.probe/profile; prints one chat line saying what was wiped.
--   ON keeps: the learned store (learned, knowledge, timing, drift, baselines), config/macro/markers, ForeverDumpStaticDB.
--   OFF never wipes; resume after /reload never wipes; ON in combat is refused (nothing wiped); new capture data lands
--   in the live tables (nothing written into dropped tables).
-- usage: lua5.1 tests/capture_wipe.lua ForeverDump
package.path = "./tests/?.lua;" .. package.path
local addonDir = arg[1] or "ForeverDump"
local fails, passed = 0, 0
local function check(c, m) if c then passed = passed + 1 print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end
local W = require("wowenv")
local S = W.state
local files = {}
for line in io.lines(addonDir .. "/ForeverDump.toc") do
    if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
end
local ns = W.loadAddon(addonDir, files, "ForeverDump")
W.fire("ADDON_LOADED", "ForeverDump")
W.fire("PLAYER_LOGIN")
W.fire("PLAYER_ENTERING_WORLD", true, false)
for _ = 1, 30 do W.tick(1) end
ns.config.logs.autoReload = false
local function chatHas(from, needle)
    for i = from + 1, #W.chat do if tostring(W.chat[i]):find(needle, 1, true) then return W.chat[i] end end
end
local function capture()
    W.slash("logs on") W.tick(2)
    S.combat = true
    W.fire("PLAYER_REGEN_DISABLED")
    W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-1234-0-0-133-000000000A", 133)
    W.fire("UNIT_COMBAT", "target", "WOUND", "", W.SECRET, 1)
    S.combat = false
    W.fire("PLAYER_REGEN_ENABLED")
    W.tick(3)
    W.slash("logs off") W.tick(2)
end

-- capture 1 fills everything
capture()
W.raiseError("mock error for the log")
local db = ForeverDumpDB
-- persistent stores the wipe must keep (seeded with recognizable content)
local b = ns.Build()
db.learned = db.learned or {} db.learned[b] = db.learned[b] or {} db.learned[b].marker = "keep-learned"
db.knowledge = db.knowledge or {} db.knowledge[b] = db.knowledge[b] or {} db.knowledge[b].marker = "keep-knowledge"
db.timing = db.timing or {} db.timing[b] = db.timing[b] or {} db.timing[b].marker = "keep-timing"
db.drift = db.drift or {} db.drift[b] = db.drift[b] or {} db.drift[b].marker = "keep-drift"
-- baselines[current build] is re-signed at every capture by design (versioned per build): keep-check an older build
db.baselines = db.baselines or {} db.baselines["70000"] = { marker = "keep-baselines" }
ForeverDumpStaticDB.sections = ForeverDumpStaticDB.sections or {}
ForeverDumpStaticDB.sections.api = { marker = "keep-static" }
local staticRef = ForeverDumpStaticDB
db.verify = db.verify or {} db.verify[b] = db.verify[b] or { ring = { 1 } }
db.secretsObs = db.secretsObs or { _keys = 1 }
db.tokenscan = db.tokenscan or { [b] = {} }
db.identities = db.identities or { x = {} }
local nLog = 0
for k in pairs(ForeverDumpLogDB) do if k ~= "schemaVersion" then nLog = nLog + 1 end end
local nCl, nRec = #ForeverDumpCombatLogDB.sessions, #ForeverDumpRecordDB.sessions
check(nLog >= 5 and nCl >= 1 and nRec >= 1 and #(ForeverDumpLogDB.errors or {}) >= 1 and ForeverDumpLogDB.replay ~= nil,
    string.format("capture 1 produced data (%d log tables, %d combat + %d recorder sessions, %d error(s))", nLog, nCl, nRec,
        #(ForeverDumpLogDB.errors or {})))

-- OFF does not wipe (a second OFF on an idle capture)
local logRef, errRef = ForeverDumpLogDB, ForeverDumpLogDB.errors
W.slash("logs off") W.tick(2)
check(ForeverDumpLogDB == logRef and ForeverDumpLogDB.errors == errRef and #ForeverDumpCombatLogDB.sessions == nCl
    and db.verify and db.secretsObs, "OFF wiped nothing")

-- ON in combat: refused, nothing wiped
S.combat = true
W.slash("logs on")
check(ForeverDumpLogDB == logRef and #ForeverDumpCombatLogDB.sessions == nCl and not db.logs.on, "ON in combat refused, nothing wiped")
S.combat = false
W.fire("PLAYER_REGEN_ENABLED")

-- ON wipes
local c0 = #W.chat
local sweepsBefore = ns.Static.IsRunning()
W.slash("logs on") W.tick(2)
local line = chatHas(c0, "previous capture data wiped")
check(line ~= nil and line:find("kept: learned store", 1, true) ~= nil, "ON printed one wipe line: " .. tostring(line))
local n = 0
for i = c0 + 1, #W.chat do if tostring(W.chat[i]):find("previous capture data wiped", 1, true) then n = n + 1 end end
check(n == 1, "exactly one wipe line (" .. n .. ")")
check(ForeverDumpLogDB ~= logRef and #(ForeverDumpLogDB.errors or {}) == 0 and ForeverDumpLogDB.errors ~= errRef,
    "ON: error log wiped")
check(#ForeverDumpCombatLogDB.sessions == 0 and #ForeverDumpRecordDB.sessions == 0, "ON: combat + recorder sessions wiped")
local replayOld = logRef.replay and logRef.replay.sessions and #logRef.replay.sessions or 0
local rp = ForeverDumpLogDB.replay
check(replayOld >= 1 and (rp == nil or #(rp.sessions or {}) <= 1), "ON: replay tape sessions wiped (" .. replayOld .. " before)")
for _, k in ipairs({ "inference", "damageMeter", "perf", "restrictions", "controls", "tokens", "blocked", "handlerEvents" }) do
    local old = logRef[k]
    check(old == nil or ForeverDumpLogDB[k] ~= old, "ON: LogDB." .. k .. " is a fresh table")
end
check(db.verify == nil or db.verify[b] == nil or db.verify[b].ring[1] ~= 1, "ON: verify ring wiped")
check(db.secretsObs == nil or db.secretsObs._keys ~= 1 or next(db.secretsObs, nil) ~= nil, "ON: secretsObs replaced")
check(db.identities == nil or db.identities.x == nil, "ON: raw identities wiped")
check(db.tokenscan == nil or db.tokenscan[b] == nil or next(db.tokenscan[b]) ~= nil, "ON: token scan wiped")
for _, k in ipairs({ "learned", "knowledge", "timing", "drift", "baselines" }) do
    local key = k == "baselines" and "70000" or b
    check(type(db[k]) == "table" and type(db[k][key]) == "table" and db[k][key].marker == "keep-" .. k, "ON kept ForeverDumpDB." .. k)
end
check(ForeverDumpStaticDB == staticRef and ForeverDumpStaticDB.sections.api.marker == "keep-static", "ON kept ForeverDumpStaticDB")
check(db.config and db.macro ~= nil and db.logs.on == true, "ON kept config/macro, capture is on")
check(not ns.Static.IsRunning() or sweepsBefore, "ON did not start the static dump")

-- the new capture writes into the live tables
S.combat = true
W.fire("PLAYER_REGEN_DISABLED")
W.fire("UNIT_COMBAT", "target", "WOUND", "", W.SECRET, 1)
S.combat = false
W.fire("PLAYER_REGEN_ENABLED")
W.tick(3)
W.raiseError("second capture error")
-- resume after /reload does not wipe
local errsBeforeReload = #(ForeverDumpLogDB.errors or {})
ns = W.reload(addonDir, files, "ForeverDump")
W.tick(3)
check(db ~= ForeverDumpDB and ForeverDumpDB.logs.on == true and #(ForeverDumpLogDB.errors or {}) == errsBeforeReload
    and errsBeforeReload >= 1, "resume after /reload wiped nothing (" .. errsBeforeReload .. " error(s) kept)")
ns.config.logs.autoReload = false
W.slash("logs off") W.tick(2)
check(#ForeverDumpCombatLogDB.sessions >= 2 and #ForeverDumpRecordDB.sessions >= 2 and ForeverDumpLogDB.replay
    and #ForeverDumpLogDB.replay.sessions >= 1, string.format("new capture landed in the live tables (%d combat, %d recorder, %d tape sessions)",
        #ForeverDumpCombatLogDB.sessions, #ForeverDumpRecordDB.sessions, ForeverDumpLogDB.replay and #ForeverDumpLogDB.replay.sessions or 0))
check(ForeverDumpDB.learned[b].marker == "keep-learned" and ForeverDumpStaticDB.sections.api.marker == "keep-static",
    "learned + static survived the reload")
print(string.format("capture wipe: %d passed, %d failed", passed, fails))
os.exit(fails == 0 and 0 or 1)
