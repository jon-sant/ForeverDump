-- v2.2.20 (run 15): (1) a capture stop without a start writes no oocfill/derive stub tables; (2) entering a BG with
-- the capture OFF prints one reminder in ForeverDump's own frame (no Blizzard chat); (3) opt-in logs.autoBG starts it.
-- usage: lua5.1 tests/bgentry_v2220.lua ForeverDump
package.path = "./tests/?.lua;" .. package.path
local addonDir = arg[1] or "ForeverDump"
local fails, passed = 0, 0
local function check(c, m) if c then passed = passed + 1 print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end
local W = require("wowenv")
local files = {}
for line in io.lines(addonDir .. "/ForeverDump.toc") do
    if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
end
local itype = "none"
local ns = W.loadAddon(addonDir, files, "ForeverDump")
IsInInstance = function() return itype ~= "none", itype end
W.fire("ADDON_LOADED", "ForeverDump")
W.fire("PLAYER_LOGIN")
W.fire("PLAYER_ENTERING_WORLD", true, false)
for _ = 1, 10 do W.tick(1) end
ns.config.logs.autoReload = false

-- (1) stop without start
local L = ForeverDumpLogDB
L.oocfill, L.derive = nil, nil
check(ns.OocFill.Stop() == nil and ns.Derive.Stop() == nil, "Stop without Start returns nil")
check(L.oocfill == nil, "no oocfill stub table")
check(L.derive == nil, "no derive stub table")

-- (2) reminder
local function count(needle) local n = 0 for _, m in ipairs(W.chat) do if tostring(m):find(needle, 1, true) then n = n + 1 end end return n end
local blz0 = #W.blizzChat
W.fire("PLAYER_ENTERING_WORLD", false, false)
check(count("Battleground entered with capture OFF") == 0, "no reminder outside instances")
itype = "pvp"
W.fire("PLAYER_ENTERING_WORLD", false, false)
check(count("Battleground entered with capture OFF") == 1, "one reminder entering a BG with capture off")
check(not ns.db.logs.on, "default: capture not auto-started")
check(#W.blizzChat == blz0, "no Blizzard chat line")

-- (3) opt-in autoBG
ns.config.logs.autoBG = true
W.fire("PLAYER_ENTERING_WORLD", false, false)
for _ = 1, 5 do W.tick(1) end
check(ns.db.logs.on == true, "autoBG: capture ON after entering a BG")
check(ns.db.logs.lastToggle and ns.db.logs.lastToggle.source == "autoBG", "autoBG recorded as the toggle source")
local n = count("Battleground entered with capture OFF")
W.fire("PLAYER_ENTERING_WORLD", false, false)
check(count("Battleground entered with capture OFF") == n, "no reminder while capture is on")
-- after a started capture, Stop writes the real summary
W.slash("logs off") W.tick(2)
check(ForeverDumpLogDB.oocfill and ForeverDumpLogDB.oocfill.summary ~= nil or ns.LabActive and not ns.LabActive(), "started capture: oocfill summary written")
-- (4) identity: a name key never joins two GUID identities (run 15: every friendly read collapsed into one key)
local UC = ns.UnitCache.new({ clock = function() return 1 end })
UC:Put("player:00000001", "class", "PRIEST", "raidN", "pvp-ooc")
UC:Put("player:00000002", "class", "MAGE", "raidN", "pvp-ooc")
local k1 = UC:Link("player:00000001", "name:0000000a")
local k2 = UC:Link("player:00000002", "name:0000000a")   -- same name key, other GUID (e.g. two realms)
check(k1 == "player:00000001" and k2 == "player:00000002", "two GUID identities stay apart")
check(UC:Get("player:00000001", "class") == "PRIEST" and UC:Get("player:00000002", "class") == "MAGE", "no class mixing")
check(UC.stats.linkConflicts == 1 and UC:Resolve("name:0000000a") == "name:0000000a", "conflict counted; ambiguous name key unlinked")
check(UC:Link("player:00000003", "name:0000000a") == "player:00000003" and UC:Resolve("name:0000000a") == "name:0000000a", "ambiguous name key never relinked")
-- (5) channel spellID index (run 15: Derive.lua:197 truth-tested UnitChannelInfo's secret notInterruptible)
local src = io.open(addonDir .. "/Derive.lua"):read("*a")
check(not src:find("clearNum%(channel and r%[8%]") and select(2, src:gsub("r%[channel and 9 or 10%]", "")) == 2, "channel spellID read from r[9] (cast r[10]) in both cast paths")
print(string.format("bgentry_v2220: %d passed, %d failed", passed, fails))
os.exit(fails == 0 and 0 or 1)
