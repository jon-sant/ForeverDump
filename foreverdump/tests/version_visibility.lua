-- v2.2.14 (run 11: the SavedVariables said addonVersion 2.2.11 although 2.2.13 had shipped; the install had not
-- updated and nothing in game showed it). The running version must be impossible to miss.
-- usage: lua5.1 tests/version_visibility.lua ForeverDump
package.path = "./tests/?.lua;" .. package.path
local addonDir = arg[1] or "ForeverDump"
local fails, passed = 0, 0
local function check(c, m) if c then passed = passed + 1 print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end
local W = require("wowenv")
local files, tocVersion = {}, nil
for line in io.lines(addonDir .. "/ForeverDump.toc") do
    if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
    tocVersion = tocVersion or line:match("^## Version:%s*(%S+)")
end
ForeverDumpDB = { addonVersion = "2.2.11" }
local ns = W.loadAddon(addonDir, files, "ForeverDump")
check(ns.VERSION == tocVersion, "toc ## Version (" .. tostring(tocVersion) .. ") == ns.VERSION (" .. tostring(ns.VERSION) .. ")")
W.fire("ADDON_LOADED", "ForeverDump")
W.fire("PLAYER_LOGIN")
W.fire("PLAYER_ENTERING_WORLD", true, false)
W.tick(3)
local function find(from, needle)
    local n, hit = 0, nil
    for i = from + 1, #W.chat do if W.chat[i]:find(needle, 1, true) then n = n + 1 hit = hit or W.chat[i] end end
    return n, hit
end
local V = ns.VERSION
check(find(0, "SavedVariables were last written by 2.2.11, now running " .. V) == 1, "login: version change 2.2.11 -> " .. V .. " announced once")
check(ForeverDumpDB.addonVersion == V and type(ForeverDumpDB.versionHistory) == "table"
    and ForeverDumpDB.versionHistory[#ForeverDumpDB.versionHistory].from == "2.2.11", "SV records the new version and the change")
-- a /reload with the same version: no second notice
local c0 = #W.chat
ns.versionChange = nil
ns.InitDB()
check(ns.versionChange == nil and (ns.VersionNotice() == nil), "same version again: no notice")
W.slash("version")
check(find(c0, "running ForeverDump " .. V) == 1, "/fdump version prints " .. V)
local c1 = #W.chat
W.slash("status")
check(W.chat[c1 + 1] and W.chat[c1 + 1]:find("ForeverDump version " .. V, 1, true) ~= nil, "/fdump status: first line is the version")
local c2 = #W.chat
W.slash("logs on") W.tick(3)
check(find(c2, "ForeverDump " .. V .. " logging: ON") == 1, "FD_Logs ON line shows " .. V)
check(ns.HSMUI and ns.HSMUI.frame and ns.HSMUI.frame.title and tostring(ns.HSMUI.frame.title:GetText()):find("ForeverDump " .. V, 1, true) ~= nil,
    "HSM panel title shows " .. V .. " (" .. tostring(ns.HSMUI and ns.HSMUI.frame and ns.HSMUI.frame.title and ns.HSMUI.frame.title:GetText()) .. ")")
local c3 = #W.chat
W.slash("logs off") W.tick(3)
check(find(c3, "ForeverDump " .. V .. " logging: OFF") == 1, "FD_Logs OFF line shows " .. V)
local all = 0
for _, l in ipairs(W.chat) do if l:find("ForeverDump " .. V, 1, true) == nil and l:find("ForeverDump", 1, true) then all = all + 1 end end
check(all == 0, "every ForeverDump line is prefixed with the version (" .. all .. " without)")
print(string.format("version_visibility: %d passed, %d failed", passed, fails))
if fails > 0 then os.exit(1) end
