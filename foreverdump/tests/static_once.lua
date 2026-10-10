-- v2.2.7 static data in its own SavedVariables table (ForeverDumpStaticDB). v2.2.11 (user decision): NO automatic run -
-- not at login, not for a new client build, not from /fdump all or FD_Logs; ONLY `/fdump static run` (force = alias).
-- usage: lua5.1 tests/static_once.lua ForeverDump
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
local files = tocFiles(addonDir)
local svPath = os.tmpname()
local function fileSize(p) local f = io.open(p) local n = f:seek("end") f:close() return n end
local function svSize() W.writeSavedVariables(svPath, W.SV_NAMES) return fileSize(svPath) end
local function settle(ns, n) for _ = 1, n or 400 do W.tick(1) if not ns.IsBusy() and not ns.Static.IsRunning() then break end end end

-- pre-2.2.7 layout on disk: static sections + v1 keys inside ForeverDumpDB (current build) -> migrated, not re-saved there
check(W.SV_NAMES[2] == "ForeverDumpStaticDB" and not table.concat(W.SV_NAMES, ","):find("DocsDB"),
    "toc SavedVariables: ForeverDumpStaticDB declared, ForeverDumpDocsDB/StringsDB no longer saved")
local _, build = GetBuildInfo()
ForeverDumpDB = { sections = { api = { meta = { build = tostring(build) }, namespaces = { C_Old = { functions = { "X" } } } },
    probe = { keep = true } }, apis = { "OldApi" }, cvarNames = { "x" } }
local sections = {}
local ns = W.loadAddon(addonDir, files, "ForeverDump")
local realRun = ns.RunSection
ns.RunSection = function(name, ...) sections[#sections + 1] = name return realRun(name, ...) end
W.fire("ADDON_LOADED", "ForeverDump")
check(rawget(ForeverDumpDB.sections, "api") == nil and rawget(ForeverDumpDB, "apis") == nil and rawget(ForeverDumpDB.sections, "probe"),
    "migration: static section + v1 keys moved out of ForeverDumpDB (capture data kept)")
check(ForeverDumpStaticDB.sections.api and ForeverDumpStaticDB.v1.apis[1] == "OldApi" and ForeverDumpDB.sections.api.namespaces.C_Old,
    "migration: moved into ForeverDumpStaticDB, still readable through ns.db (read fallback)")

-- v2.2.11: first login with no static data, out of combat and idle: NOTHING runs (no automatic dump)
local nStatic = #ns.Static.SECTIONS
W.fire("PLAYER_LOGIN")
W.fire("PLAYER_ENTERING_WORLD", true, false)
for _ = 1, 40 do W.tick(1) end
settle(ns, 4000)
for _ = 1, 2000 do W.tick(1) end   -- well past the old 15 s login delay
check(#sections == 0 and not ns.Static.IsRunning(), "login, no static data, idle: no static section ran (no automatic dump)")
check(ns.Static.Check():find("^none") or ns.Static.Check():find("^stale"), "check reports only: " .. tostring(ns.Static.Check()))
check(#sections == 0 and not ns.Static.IsRunning(), "/fdump static check did not start anything")
check(ns.Static.Start("auto") == false and ns.Static.Start("manual") == false and not ns.Static.IsRunning(),
    "ST.Start refuses every caller except the slash command")
-- /fdump all: no static section
W.slash("all")
settle(ns, 4000)
local nAll = 0
for _, n in ipairs(sections) do if ns.Static.IsStatic(n) then nAll = nAll + 1 end end
check(nAll == 0 and not ns.Static.IsRunning(), "/fdump all ran no static section (" .. nAll .. ")")
sections = {}
-- the slash command collects (in combat it waits, then runs once out of combat)
S.combat = true
W.slash("static run")
for _ = 1, 40 do W.tick(1) end
check(ns.Static.IsRunning() and #sections == 0, "/fdump static run in combat: waits, nothing ran yet")
S.combat = false
W.fire("PLAYER_REGEN_ENABLED")
settle(ns, 4000)
check(#sections == nStatic and not ns.Static.IsRunning(), "/fdump static run: " .. #sections .. "/" .. nStatic .. " static sections ran once")
check(ForeverDumpDB.static and ForeverDumpDB.static.done == true and ns.Static.Done(), "marker: done for this client signature")
check(ns.Static.StatusLine():find("until /fdump static clear", 1, true) ~= nil, "status says the data persists until /fdump static clear")
local stLocal = 0
for _, n in ipairs(ns.Static.SECTIONS) do if rawget(ForeverDumpDB.sections, n) then stLocal = stLocal + 1 end end
check(stLocal == 0 and ForeverDumpStaticDB.docs and ForeverDumpStaticDB.docs.systems and ForeverDumpStaticDB.strings,
    "static data only in ForeverDumpStaticDB (docs, strings, sections); none raw in ForeverDumpDB")
check(ForeverDumpDocsDB == ForeverDumpStaticDB.docs, "runtime alias ForeverDumpDocsDB -> static docs (readers unchanged)")
local withStatic = svSize()

-- a capture: ON never queues the dump; the SV of the capture still carries the static tables until they are cleared
sections = {}
ns.config.logs.autoReload = false
W.slash("logs on")
for _ = 1, 20 do W.tick(1) end
check(#sections == 0 and not ns.Static.IsRunning(), "FD_Logs ON queued no static section")
W.slash("logs off")
for _ = 1, 5 do W.tick(1) end
local captureWithStatic = svSize()

-- reload, same signature: nothing re-runs
ns = W.reload(addonDir, files, "ForeverDump", svPath)
realRun = ns.RunSection
sections = {}
ns.RunSection = function(name, ...) sections[#sections + 1] = name return realRun(name, ...) end
for _ = 1, 60 do W.tick(1) end
check(#sections == 0 and ns.Static.Check() == "done", "reload, same signature: no static section re-run")
check(ForeverDumpStaticDB.sections.api and ForeverDumpDB.sections.api, "static data survived the SV round trip (until cleared)")

-- /fdump static clear after ingest: SV shrinks to the marker; never collected again for the same signature
W.slash("static clear")
local cleared = svSize()
check(ForeverDumpDB.static.done and next(ForeverDumpStaticDB.sections) == nil and ForeverDumpStaticDB.docs == nil,
    "static clear: tables wiped, marker kept")
ns = W.reload(addonDir, files, "ForeverDump", svPath)
realRun = ns.RunSection
sections = {}
ns.RunSection = function(name, ...) sections[#sections + 1] = name return realRun(name, ...) end
for _ = 1, 60 do W.tick(1) end
W.slash("logs on") for _ = 1, 20 do W.tick(1) end W.slash("logs off") for _ = 1, 5 do W.tick(1) end
local captureCleared = svSize()
check(#sections == 0, "after clear + reload + capture: still no re-run (marker)")
check(captureCleared < captureWithStatic / 3, string.format("capture SV: %.2f MB with static tables -> %.2f MB after clear",
    captureWithStatic / 1048576, captureCleared / 1048576))
print(string.format("    SV sizes (mock client): dump %.2f MB | capture+static %.2f MB | cleared %.2f MB | capture after clear %.2f MB",
    withStatic / 1048576, captureWithStatic / 1048576, cleared / 1048576, captureCleared / 1048576))

-- new client signature (an API namespace appeared): v2.2.11 the next login does NOT collect; check reports "stale"
C_ForeverNewThing = { DoIt = function() end }
ns = W.reload(addonDir, files, "ForeverDump", svPath)
realRun = ns.RunSection
sections = {}
ns.RunSection = function(name, ...) sections[#sections + 1] = name return realRun(name, ...) end
settle(ns, 4000)
for _ = 1, 2000 do W.tick(1) end
settle(ns, 4000)
check(#sections == 0 and not ns.Static.IsRunning() and ns.Static.Check():find("^stale") ~= nil,
    "new API signature at login: nothing ran; check says stale (" .. tostring(ns.Static.Check()) .. ")")
-- /fdump static force = alias of run
W.slash("static force")
settle(ns, 4000)
local nForced = 0
for _, n in ipairs(sections) do if ns.Static.IsStatic(n) then nForced = nForced + 1 end end
check(nForced == nStatic and ns.Static.Done(), "/fdump static force (alias of run) collected (" .. nForced .. " static sections)")
os.remove(svPath)
print(string.format("static once: %d passed, %d failed", passed, fails))
os.exit(fails == 0 and 0 or 1)
