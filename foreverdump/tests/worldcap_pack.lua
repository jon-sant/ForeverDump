-- v2.2.7 regression (run 6b): WorldCapture five-state codes must survive packing exactly. One 16-nibble word does not fit a
-- Lua number (53-bit mantissa): 6b lost exists/health on every sample. usage: lua5.1 tests/worldcap_pack.lua ForeverDump
package.path = "./tests/?.lua;" .. package.path
local addonDir = arg[1] or "ForeverDump"
local fails, passed = 0, 0
local function check(c, m) if c then passed = passed + 1 print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end
local W = require("wowenv")
local files = {}
for line in io.lines(addonDir .. "/ForeverDump.toc") do
    if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
end
local ns = W.loadAddon(addonDir, files, "ForeverDump")
local WC = ns.WorldCapture
check(WC and type(WC.PackCodes) == "function" and type(WC.FIELD_ORDER) == "table", "WorldCapture exports PackCodes/FIELD_ORDER")
local CODES = { "N", "S", "T", "K", "C", "G" }
local NUM = { N = 0, S = 1, T = 2, K = 3, C = 4, E = 5, G = 6 }
local function unpackWord(w, count)
    local out = {}
    for i = 1, count do out[i] = math.floor(w / 16 ^ (i - 1)) % 16 end
    return out
end
math.randomseed(70291)
local bad, worst = 0, nil
for trial = 1, 5000 do
    local codes, want = {}, {}
    for i, name in ipairs(WC.FIELD_ORDER) do
        local c = CODES[math.random(#CODES)]
        if trial == 1 then c = "G" end            -- all fields at the highest code
        if trial == 2 and i <= 2 then c = "S" end -- the 6b case: low fields set, high fields high
        codes[name] = c
        want[i] = NUM[c]
    end
    local p, q = WC.PackCodes(codes)
    local got = unpackWord(p, 8)
    for i, v in ipairs(unpackWord(q, 8)) do got[8 + i] = v end
    for i = 1, 16 do
        if got[i] ~= want[i] then bad = bad + 1 worst = worst or (trial .. ":" .. WC.FIELD_ORDER[i]) break end
    end
    if p >= 2 ^ 53 or q >= 2 ^ 53 then bad = bad + 1 worst = worst or ("word over 2^53 at trial " .. trial) end
end
check(bad == 0, "5000 random code sets round-trip exactly through p/q (" .. tostring(worst or "no mismatch") .. ")")
-- NPC IdKey = npc:<npcID> (6th GUID field), never the instance id (run 6b: every NPC was "npc:1")
local R = ns.ReplayLog
check(R and R.IdKey("npc", "Creature-0-4621-1-739-4094-0000ABCDEF") == "npc:4094", "IdKey npc -> npcID 4094 ("
    .. tostring(R and R.IdKey("npc", "Creature-0-4621-1-739-4094-0000ABCDEF")) .. ")")
check(R.IdKey("npc", "Vehicle-0-4621-1-739-3573-0000ABCDEF") == "npc:3573", "IdKey vehicle -> npcID 3573")
check(R.IdKey("npc", "Creature-0-4621-1-739-4094-0000ABCDEF") ~= R.IdKey("npc", "Creature-0-4621-1-739-4093-0000ABCDEF"),
    "two NPC types never share an IdKey")
print(string.format("worldcap pack: %d passed, %d failed", passed, fails))
os.exit(fails == 0 and 0 or 1)
