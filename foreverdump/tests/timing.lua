-- Timing.lua (spell timing seed + per-build SV learning): seed load into the CooldownTracker, O(1) running stats,
-- LRU cap, learned values with >= minSamples override the seed, numbers/spell IDs only in the SV.
local addonDir = arg[1] or "ForeverDump"
local passed, failures = 0, 0
local function check(cond, msg)
    if cond then passed = passed + 1 else failures = failures + 1 print("  FAIL " .. msg) end
end
_G.HybridState = nil
local Lib = dofile(addonDir .. "/Lib/HybridState.lua")
local ns = { db = {}, config = { timing = { enabled = true, maxSpells = 20, minSamples = 3 } }, Build = function() return "70245" end }
assert(loadfile(addonDir .. "/Data/spell-timing.lua"))("ForeverDump", ns)
assert(loadfile(addonDir .. "/Timing.lua"))("ForeverDump", ns)
local T = ns.Timing
check(ns.SpellTimingSeed and ns.SpellTimingSeed.schema == "foreverdump.spelltiming/1", "seed file loads (schema)")
check(T.SeedCount() >= 20, "seed has >= 20 spells (runs 3-5 + known answers)")
local s = ns.SpellTimingSeed.spells
check(s[2484] and s[2484].gcd == 1.0 and s[905] and s[905].gcd == 1.5, "known answers in the seed: totem 1.0 s, Lightning Shield 1.5 s")
for id, e in pairs(s) do
    for k, v in pairs(e) do
        if type(v) == "string" and k ~= "source" and k ~= "confidence" and not k:match("Build$") and not k:match("Seen$") then
            check(false, "seed field " .. id .. "." .. k .. " is a free-form string")
        end
    end
end
-- attach: the seed drives HS:GCD() without knowledge or API values
local t = 0
local hs = Lib.New({ now = function() return t end })
local n = T.Attach(hs)
check(n == T.SeedCount() and hs.onCDLearn == T.Learn, "Attach seeds every spell and hooks onCDLearn")
hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 2484, true, nil)
local gq = hs:GCD()
check(gq and math.abs(gq.length - 1.0) < 1e-6, "HS:GCD() from the seed: Earthbind Totem 1.0 s")
-- learning: running stats, O(1)
T.Learn("gcd", 8046, 1.512) T.Learn("gcd", 8046, 1.498) T.Learn("gcd", 8046, 1.505)
T.Learn("cal", 8046, 6.0)
T.Learn("bogus", 8046, 1) T.Learn("gcd", "Earth Shock", 1)
local d = ns.db.timing["70245"]
local e = d.spells[8046]
check(e.gcdN == 3 and math.abs(e.gcdMin - 1.498) < 1e-9 and math.abs(e.gcdMax - 1.512) < 1e-9 and e.cal == 6.0, "running N/min/max + latest clear calibration")
check(d.n == 1 and d.spells["Earth Shock"] == nil, "unknown kinds and non-numeric ids ignored")
for k, v in pairs(e) do check(type(v) == "number", "SV entry holds numbers only (" .. k .. ")") end
-- learned values override the seed on the next Attach
local hs2 = Lib.New({ now = function() return t end })
T.Attach(hs2)
hs2:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8046, true, nil)
gq = hs2:GCD()
check(gq and math.abs(gq.length - 1.505) < 0.01, "learned GCD (3 samples) beats the seed")
-- LRU: cap 20 + slack 10 -> one sweep back to the 20 most recent
for i = 1, 31 do T.Learn("gap", 100000 + i, 1.5) end
check(d.n <= 30 and d.spells[100031] and d.spells[100031].gapN == 1, "LRU sweep keeps the cap (+slack) and the newest entry")
check(d.spells[8046] == nil, "least recently updated spell evicted")
local t0 = os.clock()
for i = 1, 20000 do T.Learn("gap", 200000 + (i % 25), 1.5) end
local per = (os.clock() - t0) / 20000 * 1e6
check(per < 20, string.format("Learn is O(1): %.2f us per update", per))
ns.config.timing.enabled = false
check(T.Attach(Lib.New({})) == 0, "disabled: no seed / no learning")
print(string.format("timing: %d passed, %d failed", passed, failures))
if failures > 0 then os.exit(1) end
