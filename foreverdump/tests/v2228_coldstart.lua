-- v2.2.28 cold start of the aura-presence candidate list (run 22: a whole BG with 0 candidates).
-- ACCEPTANCE: replay run 22's stored ForeverDumpDB (tests/fixtures/run22_db.lua, build 70338, no /fdump static run)
--   (A) as it was (same build) and (B) as a FRESH build 70400 with the offline file switched off
--   -> non-empty candidate list from the FIRST tick of a capture started in BG prep.
-- Mechanisms: (1) existing learners (refLearned.auraDur, knowledge), (2) automatic spellCache build on
-- PLAYER_ENTERING_WORLD spread over timer steps, out of combat only, (3) cross-build carry-over tagged prev-build until
-- re-confirmed, (4) generated library Data/LearnedAuras.lua (schema 2: per-entry builds, provisional when unconfirmed; + switch),
-- (6) rank grouping, (7) library pairs / aura-before-cast pairing, (5) empty-list warning + SV flag.
-- usage: lua5.1 tests/v2228_coldstart.lua ForeverDump
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
local FIX = dofile("tests/fixtures/run22_db.lua")
local function deep(t) if type(t) ~= "table" then return t end local o = {} for k, v in pairs(t) do o[k] = deep(v) end return o end

-- the player's spellbook = the run-22 knowledge spells (IDs, names, descriptions as stored)
local KS = FIX.knowledge["70338"].spells
local IDS = {}
for sid in pairs(KS) do IDS[#IDS + 1] = sid end
table.sort(IDS)
local function mockSpellbook(on)
    if not on then C_SpellBook = nil return end
    C_SpellBook = {
        GetNumSpellBookSkillLines = function() return 1 end,
        GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = #IDS } end,
        GetSpellBookItemType = function(idx) return 1, nil, IDS[idx] end,
    }
    C_Spell = C_Spell or {}
    C_Spell.GetSpellName = function(sid) return KS[sid] and KS[sid].data["info.name"] end
    C_Spell.GetSpellDescription = function(sid) return KS[sid] and KS[sid].data.description end
end

local itype = "pvp"
local function fresh(buildNo, db, opts)
    opts = opts or {}
    S.frames, S.timers, S.onUpdate = {}, {}, {}
    for _, n in ipairs(W.SV_NAMES or {}) do _G[n] = nil end
    ForeverDumpDB = db
    GetBuildInfo = function() return "1.60.1", buildNo, "Oct 10 2026", 16001, "", "", 16001 end
    mockSpellbook(opts.spellbook ~= false)
    UnitClass = function() return "Shaman", "SHAMAN", 7 end
    local ns = W.loadAddon(addonDir, files, "ForeverDump")
    if opts.noOffline then ns.LearnedAuras = nil end
    IsInInstance = function() return itype ~= "none", itype end
    IsInGroup = function() return true end
    W.fire("ADDON_LOADED", "ForeverDump")
    W.fire("PLAYER_LOGIN")
    ns.InvalidateEnv()
    ns.LabActive = function() return true end
    ns.db.logs = ns.db.logs or {}
    ns.db.logs.on = true
    C_Timer.NewTicker = function() return { Cancel = function() end } end
    UnitExists = function(u) return u == "player" end
    UnitIsPlayer = function(u) return u == "player" end
    C_UnitAuras.GetAuraSlots = function() error("Auras cannot be accessed when secret while tainted by 'ForeverDump'") end
    C_UnitAuras.GetUnitAuraBySpellID = function() return nil end
    return ns, ns.AuraPresence
end
local function srcs(AP)
    local c = {}
    for _, s in ipairs(AP.List()) do c[s[3]] = (c[s[3]] or 0) + 1 end
    local t = {}
    for k, v in pairs(c) do t[#t + 1] = k .. "=" .. v end
    table.sort(t)
    return table.concat(t, ",")
end

print("(A) ACCEPTANCE run 22 as it was: build 70338, no static run, in a BG, no offline file")
local ns, AP = fresh("70338", deep(FIX), { noOffline = true, spellbook = false })
check(ns.Build() == "70338", "build 70338")
check(AP.Start() == true, "capture start")
AP.Tick()
local d = ForeverDumpLogDB.auraPresence
check(d.list.n > 0, "first tick: " .. d.list.n .. " candidates (" .. srcs(AP) .. "); v2.2.27 had 0")
check(d.emptyAtStart == nil, "no empty warning")
check(AP.inList[8056] == "knowledge", "own Frost Shock 8056 from knowledge")

print("(B) ACCEPTANCE fresh build 70400, offline off, spellbook readable: carry-over + auto spellCache")
ns, AP = fresh("70400", deep(FIX), { noOffline = true })
check(ns.Build() == "70400", "build 70400 (fresh)")
check(AP.Start() == true, "capture start in a BG, out of combat")
AP.Tick()
d = ForeverDumpLogDB.auraPresence
local s1 = srcs(AP)
check(d.list.n > 0, "FIRST tick: " .. d.list.n .. " candidates (" .. s1 .. ")")
check(s1:find("ooclearn=") and s1:find("knowledge="), "previous build's refLearned + knowledge used provisionally")
local _, from = AP.RefAuraDur()
check(from == "70338", "refLearned fallback from 70338")
-- (2) automatic spellCache: PLAYER_ENTERING_WORLD -> 3 s timer -> chunked steps
W.fire("PLAYER_ENTERING_WORLD", false, true)
local steps = 0
for _ = 1, 50 do
    if #S.timers == 0 then break end
    local ts = S.timers S.timers = {}
    for _, fn in ipairs(ts) do fn() end
    steps = steps + 1
end
local C = AP.Store("spellCache")
local n = 0
for _ in pairs(C.SHAMAN and C.SHAMAN.spells or {}) do n = n + 1 end
check(n == #IDS and C.SHAMAN.how == "auto:login" and steps >= math.ceil(#IDS / AP.AUTO_CHUNK), "auto spellCache: " .. n .. " spells in " .. steps .. " timer steps (" .. AP.AUTO_CHUNK .. "/step)")
check(C.SHAMAN.spells[8056].aura == true and C.SHAMAN.spells[8056].dur == 8 and ns.db.spellCache["70400"] ~= nil, "8056 aura 8 s from description, stored under 70400")
AP.listDirty = true
check(AP.List() and AP.inList[8056] ~= nil and srcs(AP):find("knowledge="), "list after auto cache: " .. srcs(AP))

print("(2b) auto cache pauses in combat, skips when present")
ns.db.spellCache["70400"] = nil
S.combat = true ns.InvalidateEnv()
check(AP.AutoSpellCache("test") == true, "job started")
check(AP.AutoRunning() and #S.timers == 1, "in combat: no spell read, re-queued")
S.combat = false ns.InvalidateEnv()
for _ = 1, 50 do if #S.timers == 0 then break end local ts = S.timers S.timers = {} for _, fn in ipairs(ts) do fn() end end
check(not AP.AutoRunning() and AP.Store("spellCache").SHAMAN, "finished out of combat")
check(AP.AutoSpellCache("again") == false, "present -> no second build")

print("(3) cross-build carry-over")
local db3 = deep(FIX)
db3.auraLearned = { ["70338"] = { [18070] = { n = 5, dur = 30, name = "Earthborer Acid", self = 2, seen = 1 } } }
db3.auraPairs = { ["70338"] = { [17364] = { [1238931] = { n = 9, self = 9, name = "Improved Stormstrike" } } } }
ns, AP = fresh("70400", db3, { noOffline = true, spellbook = false })
local L = AP.Store("auraLearned")
check(L[18070] and L[18070].prov == "prev-build:70338" and L[18070].n == 0 and L[18070].dur == 30, "18070 carried from 70338, provisional")
check(AP.Store("auraPairs")[17364][1238931].prov == "prev-build:70338", "pair carried, provisional")
check(ns.db.auraCarry["70400:auraLearned"].from == "70338" and ns.db.auraLearned["70338"][18070].n == 5, "carry recorded; old build untouched")
AP.listDirty = true AP.List()
check(AP.inList[18070] == "prev-build", "candidate source prev-build")
AP.Learn(18070, "Earthborer Acid", 30, { self = true })
AP.List()
check(L[18070].prov == nil and L[18070].confirmed and AP.inList[18070] == "learned", "clear read on 70400 confirms it -> learned")

print("(4) offline Data/LearnedAuras.lua")
ns, AP = fresh("70338", {}, { spellbook = false })
local LA = ns.LearnedAuras
check(type(LA) == "table" and LA.schema == 2 and LA.spells[18070] and LA.spells[18070].builds:find("70338"), "generated library loaded (schema 2, 18070 confirmed on 70338)")
local src = io.open(addonDir .. "/Data/LearnedAuras.lua"):read("*l")
check(src:find("^%-%- GENERATED by tools/fdump/learnedauras.py"), "file header says GENERATED")
AP.listDirty = true AP.List()
check(AP.inList[18070] == "offline", "confirmed on this build -> source offline")
check(select(2, AP.Duration(1238931)) == "offline" and AP.Duration(1238931) == 15, "library duration 1238931 = 15 s")
ns.config.auraPresence = { offline = false }
AP.listDirty = true
check(#AP.List() == 0, "auraPresence.offline = false switches it off")
ns.config.auraPresence = nil
ns, AP = fresh("70999", {}, { spellbook = false })
AP.listDirty = true AP.List()
check(AP.inList[905] == "offline-prov", "unconfirmed on the running build -> offline-prov (905: " .. tostring(AP.inList[905]) .. ")")
check(select(2, AP.Duration(18070)) == "offline-prov", "provisional duration tagged")

print("(6) ranks (v2.2.29): grouped per ability, NEVER dropped; the tier decides how often")
ns, AP = fresh("70338", {}, { spellbook = false })
AP.listDirty = true
local list = AP.List()
local nLib = AP.Count(AP.OfflineAuras())
local ls = 0
for _, e in ipairs(list) do if (e[2] or ""):lower() == "lightning shield" then ls = ls + 1 end end
local lsLib = 0
for _, r in pairs(AP.OfflineAuras()) do if r.name == "Lightning Shield" then lsLib = lsLib + 1 end end
check(#list == nLib and nLib >= 582, "every library ID listed: " .. #list .. " of " .. nLib)
check(ls == lsLib and ls >= 3 and AP.inList[905] and AP.inList[325] and AP.inList[324], "all " .. ls .. " Lightning Shield ranks listed")
local db6 = deep(FIX)
db6.auraLearned = { ["70338"] = { [945] = { n = 3, dur = 600, name = "Lightning Shield", seen = 1 } } }
ns, AP = fresh("70338", db6, { spellbook = false })
AP.listDirty = true AP.List()
local pl = AP.Plan(nil, nil)
local tierOf = {}
for _, t in ipairs({ "H", "W", "C" }) do for _, sid in ipairs(pl[t]) do tierOf[sid] = t end end
check(AP.inList[945] == "learned" and tierOf[945] == "H", "rank seen live: tier H (every visit)")
check(AP.inList[905] == "knowledge" and tierOf[905] == "H" and tierOf[325] == "H", "own-spellbook ranks (knowledge): tier H")
-- Entangling Roots, library only, 5 ranks, unit class/level unknown: most seen 5195 W, the other 4 C (all checked)
check(tierOf[5195] == "W" and tierOf[19973] == "C" and tierOf[1062] == "C" and tierOf[19975] == "C" and tierOf[19974] == "C",
    "class/level unknown: most-seen rank W, other ranks C (every " .. AP.TIER_EVERY.C .. " visits, not dropped)")

print("(7) library cast->aura pairs + aura-before-cast pairing")
ns, AP = fresh("70338", {}, { spellbook = false })
AP.Start()
AP.OnOwnCast(17364)
local hit = false
for _, r in ipairs(ForeverDumpLogDB.auraPresence.derived or {}) do if r:find("|17364|1238931|player|") then hit = true end end
check(hit, "17364 Stormstrike -> 1238931 Improved Stormstrike on self (library pair, no live pair yet)")
AP.lastCast = nil
AP.PairFromAura("player", 1238931, "Improved Stormstrike")
AP.OnOwnCast(17364)
local P = AP.Store("auraPairs")
check(P[17364] and P[17364][1238931] and P[17364][1238931].n == 1 and P[17364][1238931].self == 1, "aura seen just before its cast still pairs")

print("(5) empty-list warning at capture start")
ns, AP = fresh("70999", {}, { noOffline = true, spellbook = false })
check(AP.Start() == true, "start")
d = ForeverDumpLogDB.auraPresence
check(d.emptyAtStart and d.emptyAtStart:find("|bg/ooc/") and d.emptyAtStart:find("learned=0,ooclearn=0,knowledge=0,offline=0"), "SV flag: " .. tostring(d.emptyAtStart))
check(d.warnCount and d.warnCount.empty == 1 and d.warnings[1]:find("|empty|0 aura candidates at capture start"), "warning logged")
local shown = false
for _, l in ipairs(ns.chatQueue and ns.chatQueue.lines or {}) do if l:find("0 aura candidates") then shown = true end end
check(shown, "shown in the FD message frame")

print(string.format("v2228_coldstart: %d passed, %d failed", passed, fails))
os.exit(fails == 0 and 0 or 1)
