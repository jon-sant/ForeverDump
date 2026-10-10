-- ForeverDump v2.2.19 - proactive out-of-combat fill + full unit-token sweep (capture level lab; collect first,
-- perf measured not capped). Two jobs:
--  1. FILL: whenever values read clear (out of combat, BG prep, after combat, graveyard / dead, between fights) every
--     existing unit token is read and its clear facts are cached per identity (Lib/UnitCache.lua): GUID key, name key,
--     class, race, level, faction, sex, max health, power type, max power, player/hostile flags, guild key, owner key
--     (pet tokens), arena spec, auras (spellId / duration / source key). The cache feeds the class engine
--     (ns.Derive.Engine), the HSM ledger (ns.Identity.Observe / ScanAuras) and the per-build learned reference data
--     (aura duration, aura spell -> source class votes). Each fact carries source, time, context and staleness; later
--     clear reads verify it (static contradiction -> unknown, dynamic drift counted).
--  2. SWEEP: readability per token family x field x context (combat / ooc / prep / postcombat / dead / pvp-ooc) for
--     every token the client offers: player, pet, target(target), focus(target), mouseover(target), partyN(target),
--     partypetN, raidN(target), raidpetN, bossN(target), arenaN(target), nameplateN(target). Limits come from the
--     client (group size, MAX_* globals, C_NamePlate.GetNamePlates), never a fixed list.
--  Target chains (XNtarget) give "who targets whom" edges between identity keys -> two SHADOW rules (counted, never
--  claimed): tt-attacker (enemies targeting me when I take a hit) and tt-same-class (same-class friendlies targeting a
--  unit whose auras changed: tie-break corroboration).
-- Secret-safe: every API value passes ns.ClassifyValue / ns.Clear* first; only codes, counts, clear class/race tokens,
-- numbers, spell ids and RAW identities are stored (v2.2.21: GUID, full name with realm as read, guild name; keys are
-- kind:<raw>, the name key realm-stripped as a join helper). Own frame, no Blizzard writes.
local _, ns = ...
local OF = {}
ns.OocFill = OF

local function g(n) return rawget(_G, n) end
local function code(v) return ns.ClassifyValue(v) end
local function now() return (g("GetTime") or os.clock)() end
local function active() return ns.LabActive and ns.LabActive() and ns.db and ns.db.logs and ns.db.logs.on and true or false end
local function idKey(kind, v) return ns.ReplayLog and ns.ReplayLog.IdKey and ns.ReplayLog.IdKey(kind, v) or nil end

OF.SLICE = 24             -- tokens read per tick (sliced sweep)
OF.TICK = 0.2             -- s
OF.OOC_PERIOD = 2         -- s between full out-of-combat sweeps (event-driven sweeps come on top, throttled)
OF.COMBAT_PERIOD = 3      -- s between full in-combat readability sweeps (lab)
OF.EDGE_PERIOD = 1        -- s between in-combat target-edge refreshes
OF.EDGE_FRESH = 2         -- s an edge counts as current for the shadow rules
OF.MAX_EVENTS = 3000      -- shadow-rule event rows kept for the offline log join

OF.FIELDS = { "guid", "name", "class", "race", "level", "faction", "sex", "hpMax", "powerType", "powerMax", "isPlayer",
    "hostile", "guild", "spec", "exists" }

local function db()
    local log = g("ForeverDumpLogDB")
    if type(log) ~= "table" then return nil end
    log.oocfill = log.oocfill or { v = 1 }
    return log.oocfill
end
OF.DB = db

-- context ----------------------------------------------------------------------------------------------------------
local lastRegen = -1000
local function rd(api, pos, ...)
    local f = g(api)
    if type(f) ~= "function" then return "-", nil end
    local res = ns.Pack(pcall(f, ...))
    if not res[1] then return "E", nil end
    local x = res[1 + pos]
    local c = code(x)
    if c ~= "C" then return c, nil end
    return c, x
end
OF.Read = rd
local function inPvp()
    local _, it = rd("IsInInstance", 2)
    return it == "pvp" or it == "arena", it
end
function OF.Context()
    local _, lock = rd("InCombatLockdown", 1)
    if lock == true then return "combat" end
    local _, dead = rd("UnitIsDeadOrGhost", 1, "player")
    if dead == true then return "dead" end
    if now() - lastRegen < 5 then return "postcombat" end
    local pvp = inPvp()
    if pvp then
        local _, rt = rd("GetBattlefieldInstanceRunTime", 1)
        if type(rt) == "number" and rt < 120000 then return "prep" end
        return "pvp-ooc"
    end
    return "ooc"
end

-- token enumeration (dynamic) --------------------------------------------------------------------------------------
local function gnum(name, fallback)
    local v = g(name)
    if type(v) == "number" and v > 0 then return v end
    return fallback
end
local function num0(x)
    if type(x) == "number" then return x end
    return 0
end
local function exists(u)
    local _, e = rd("UnitExists", 1, u)
    return e == true
end
OF.Exists = exists
function OF.Limits()
    local L = { party = 0, raid = 0, boss = gnum("MAX_BOSS_FRAMES", 5), arena = 0, plates = 0 }
    local _, inRaid = rd("IsInRaid", 1)
    local _, nGroup = rd("GetNumGroupMembers", 1)
    local _, nSub = rd("GetNumSubgroupMembers", 1)
    if inRaid == true then L.raid = math.min(num0(nGroup), gnum("MAX_RAID_MEMBERS", 40))
    else L.party = math.min(num0(nSub), gnum("MAX_PARTY_MEMBERS", 4)) end
    local _, nArena = rd("GetNumArenaOpponents", 1)
    local _, nSpecs = rd("GetNumArenaOpponentSpecs", 1)
    local na = math.max(num0(nArena), num0(nSpecs))
    local _, it = rd("IsInInstance", 2)
    if it == "arena" and na == 0 then na = gnum("MAX_ARENA_ENEMIES", 5) end
    L.arena = math.min(na, gnum("MAX_ARENA_ENEMIES", 5))
    return L
end
local function plateTokens(out)
    local NP = g("C_NamePlate")
    local f = type(NP) == "table" and NP.GetNamePlates or nil
    local n = 0
    if type(f) == "function" then
        local ok, rawPlates = pcall(f)
        local plates = ok and ns.ClearTable(rawPlates) or nil
        if plates then
            for _, p in ipairs(plates) do
                local okT, tok = pcall(function() return p.namePlateUnitToken or (p.UnitFrame and p.UnitFrame.unit) end)
                local s = okT and ns.ClearStr(tok) or nil
                if s then out[#out + 1] = s out[#out + 1] = s .. "target" n = n + 1 end
            end
            return n
        end
    end
    -- fallback: walk nameplateN until a gap of 10 missing tokens
    local gap, i = 0, 0
    while gap < 10 and i < 200 do
        i = i + 1
        if exists("nameplate" .. i) then out[#out + 1] = "nameplate" .. i out[#out + 1] = "nameplate" .. i .. "target" n = n + 1 gap = 0
        else gap = gap + 1 end
    end
    return n
end
function OF.Tokens()
    local L = OF.Limits()
    local out = { "player", "pet", "pettarget", "target", "targettarget", "focus", "focustarget", "mouseover", "mouseovertarget" }
    for i = 1, L.party do out[#out + 1] = "party" .. i out[#out + 1] = "party" .. i .. "target" out[#out + 1] = "partypet" .. i end
    for i = 1, L.raid do out[#out + 1] = "raid" .. i out[#out + 1] = "raid" .. i .. "target" out[#out + 1] = "raidpet" .. i end
    for i = 1, L.boss do out[#out + 1] = "boss" .. i out[#out + 1] = "boss" .. i .. "target" end
    for i = 1, L.arena do out[#out + 1] = "arena" .. i out[#out + 1] = "arena" .. i .. "target" end
    L.plates = plateTokens(out)
    return out, L
end
local function fam(u) return (u:gsub("%d+", "N")) end
OF.Family = fam
-- the base token of a *target token, the owner token of a pet token
local function baseOf(u)
    if u == "targettarget" then return "target" end
    return u:match("^(.+)target$")
end
local function ownerOf(u)
    if u == "pet" then return "player" end
    local i = u:match("^partypet(%d+)$")
    if i then return "party" .. i end
    i = u:match("^raidpet(%d+)$")
    if i then return "raid" .. i end
    return nil
end
OF.BaseOf, OF.OwnerOf = baseOf, ownerOf

-- cache --------------------------------------------------------------------------------------------------------------
local cache
function OF.Cache()
    if not cache and ns.UnitCache then cache = ns.UnitCache.new({ clock = now }) end
    return cache
end

-- identity of a token: GUID key and name key (players), linked when both are clear on the same read
local tokKey = {}       -- [token] = { key, t }
local function identify(u)
    local _, guid = rd("UnitGUID", 1, u)
    local _, nm = rd("UnitName", 1, u)
    local _, isP = rd("UnitIsPlayer", 1, u)
    local gk, nk
    if type(guid) == "string" then
        local kind = (guid:find("^Player%-") and "player") or (guid:find("^Pet%-") and "pet") or "guid"
        gk = idKey(kind, guid)
    end
    local full
    if type(nm) == "string" and nm ~= "" then
        local _, realm = rd("UnitName", 2, u)
        full = (type(realm) == "string" and realm ~= "") and (nm .. "-" .. realm) or nm
        if isP == true then nk = idKey("name", nm:match("^([^%-]+)") or nm) end
    end
    local c = OF.Cache()
    local key = gk or nk
    if c and gk and nk then key = c:Link(gk, nk) end
    if c and key then key = c:Resolve(key) end
    if key then tokKey[u] = { key = key, t = now() } end
    local gs = nil
    if type(guid) == "string" then gs = guid end
    return key, nk, gk, isP == true, full, gs
end
OF.Identify = identify
function OF.KeyOf(u)
    local e = tokKey[u]
    if e and now() - e.t <= OF.EDGE_FRESH * 2 then return e.key end
    return (identify(u))
end

local function bump(t, key, c)
    local r = t[key]
    if not r then r = {} t[key] = r end
    r[c] = (r[c] or 0) + 1
end
local function learned()
    local D = ns.Derive
    return D and D.Learned and D.Learned() or nil
end

-- read one token: readability matrix + cache fill + engine / HSM feed --------------------------------------------
function OF.ReadToken(u, ctx)
    local d = db()
    if not d then return end
    d.read = d.read or {}
    local f = fam(u)
    local okE, ex = rd("UnitExists", 1, u)
    bump(d.read, f .. "|exists|" .. ctx, okE)
    if ex ~= true then return nil end
    d.seen = d.seen or {}
    bump(d.seen, f, ctx)
    local key, nk, gk, isPlayer, fullName, guidStr = identify(u)
    local c = OF.Cache()
    local codes = {}
    codes.guid = rd("UnitGUID", 1, u)
    codes.name = rd("UnitName", 1, u)
    local cc, class = rd("UnitClass", 2, u)
    local rc, race = rd("UnitRace", 2, u)
    local lc, level = rd("UnitLevel", 1, u)
    local fc, faction = rd("UnitFactionGroup", 1, u)
    local sc, sex = rd("UnitSex", 1, u)
    local hc, hpMax = rd("UnitHealthMax", 1, u)
    local pc, ptoken = rd("UnitPowerType", 2, u)
    local mc, powerMax = rd("UnitPowerMax", 1, u)
    local ac, hostile = rd("UnitCanAttack", 1, "player", u)
    local gc, guild = rd("GetGuildInfo", 1, u)
    codes.class, codes.race, codes.level, codes.faction, codes.sex = cc, rc, lc, fc, sc
    codes.hpMax, codes.powerType, codes.powerMax, codes.hostile, codes.guild = hc, pc, mc, ac, gc
    codes.isPlayer = rd("UnitIsPlayer", 1, u)
    local spec
    local ai = u:match("^arena(%d+)$")
    if ai then
        local spc, sp = rd("GetArenaOpponentSpec", 1, tonumber(ai))
        codes.spec, spec = spc, sp
    end
    for fld, k in pairs(codes) do bump(d.read, f .. "|" .. fld .. "|" .. ctx, k) end
    if not (c and key) then return nil end
    c:SeenVia(key, f)
    local src = f
    local res = {}
    local function put(field, v) if v ~= nil then res[field] = c:Put(key, field, v, src, ctx) end end
    if type(class) == "string" and class ~= "" then put("class", class) end
    if type(race) == "string" and race ~= "" then put("race", race) end
    if type(level) == "number" and level > 0 then put("level", level) end
    if type(faction) == "string" and faction ~= "" then put("faction", faction) end
    if type(sex) == "number" then put("sex", sex) end
    if type(hpMax) == "number" and hpMax > 0 then put("hpMax", hpMax) end
    if type(ptoken) == "string" and ptoken ~= "" then put("powerType", ptoken) end
    if type(powerMax) == "number" and powerMax > 0 then put("powerMax", powerMax) end
    put("isPlayer", isPlayer)
    if type(hostile) == "boolean" then put("hostile", hostile) end
    if type(guild) == "string" and guild ~= "" then put("guild", guild) put("guildKey", idKey("guild", guild)) end
    put("name", fullName)   -- v2.2.21 raw full name (with realm when the client gives one)
    put("guid", guidStr)   -- v2.2.21 raw GUID
    if type(spec) == "number" and spec > 0 then put("spec", spec) end
    local own = ownerOf(u)
    if own then
        local ok = OF.KeyOf(own)
        if ok then put("ownerKey", ok) end
    end
    d.result = d.result or {}
    for _, r in pairs(res) do d.result[r] = (d.result[r] or 0) + 1 end
    -- feeds: class engine (players: name key, as Derive keys hostile players), HSM ledger (out of combat)
    local cls = c:Fresh(key, "class")
    if cls and isPlayer then
        local D = ns.Derive
        local e = D and D.Engine and D.Engine() or nil
        local ekey = nk or key
        if e then
            if hostile == true then e:MarkEnemy(ekey) end
            if e:Get(ekey) ~= cls then e:Assign(ekey, cls, "cache:" .. f) end
        end
    end
    if ctx ~= "combat" then
        local ID = ns.Identity
        if ID and ID.Observe and u ~= "player" then pcall(ID.Observe, u, "oocfill") end
        OF.ScanAuras(u, key, ctx)
    end
    return key, gk, nk
end

-- auras out of combat: spellId / duration / source key -> cache summary, learned aura durations and source-class votes
function OF.ScanAuras(u, key, ctx)
    local ua = g("C_UnitAuras")
    if type(ua) ~= "table" or type(ua.GetAuraDataByIndex) ~= "function" then return 0 end
    local d = db()
    d.aura = d.aura or {}
    local L = learned()
    local n, sig = 0, {}
    for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
        for i = 1, 40 do
            -- v2.2.25: env-keyed breaker (ns.AuraGate): held 30 s after an access error in this env/combat/phase
            local held, ok, rawA
            if ns.AuraGate then held, ok, rawA = ns.AuraGate.Call("GetAuraDataByIndex", "oof:" .. fam(u), ua.GetAuraDataByIndex, u, i, filter)
            else held, ok, rawA = false, pcall(ua.GetAuraDataByIndex, u, i, filter) end
            if held then bump(d.aura, fam(u) .. "|" .. ctx, "held") break end
            if not ok then bump(d.aura, fam(u) .. "|" .. ctx, "E") break end
            local a = ns.ClearTable(rawA)
            if not a then bump(d.aura, fam(u) .. "|" .. ctx, code(rawA)) break end
            local sid, dur = ns.ClearNum(a.spellId), ns.ClearNum(a.duration)
            local srcTok = ns.ClearStr(a.sourceUnit)
            -- v2.2.22 (audit): the spellId field's own code (was: anything non-clear coarse-coded "S"); T structs counted
            if code(rawA) == "T" then bump(d.aura, fam(u) .. "|" .. ctx .. "|struct", "T") end
            local okS, rs = pcall(function() return a.spellId end)
            bump(d.aura, fam(u) .. "|" .. ctx, okS and code(rs) or "E")
            if sid then
                n = n + 1
                sig[#sig + 1] = sid
                if L then
                    if dur and dur > 0 then
                        L.auraDur = L.auraDur or {}
                        local r = L.auraDur[sid] or { n = 0 }
                        L.auraDur[sid] = r
                        r.n = r.n + 1
                        r.min = r.min and math.min(r.min, dur) or dur
                        r.max = r.max and math.max(r.max, dur) or dur
                    end
                    if srcTok then
                        local _, sp = rd("UnitIsPlayer", 1, srcTok)
                        local _, scls = rd("UnitClass", 2, srcTok)
                        if sp == true and type(scls) == "string" and scls ~= "" then
                            local v = L.spellClass[sid]
                            if not v then v = {} L.spellClass[sid] = v end
                            v[scls] = (v[scls] or 0) + 1
                        end
                    end
                end
            end
        end
    end
    local c = OF.Cache()
    if c and key and n > 0 then
        table.sort(sig)
        c:Put(key, "auras", table.concat(sig, ","), fam(u), ctx)
    end
    return n
end

-- target edges + shadow rules -------------------------------------------------------------------------------------
local edges = {}        -- [fromKey] = { to = key, t = time, fam = token family of the target token }
OF.edges = edges
function OF.ReadEdge(tt)
    local base = baseOf(tt)
    if not base then return end
    if not exists(tt) then
        local fk = base and OF.KeyOf(base)
        if fk then edges[fk] = nil end
        return
    end
    local fk, tk = OF.KeyOf(base), OF.KeyOf(tt)
    if fk and tk then edges[fk] = { to = tk, t = now(), fam = fam(tt) } end
end
local function shadowLog(rule, outcome, extra, hint)
    local d = db()
    d.shadow = d.shadow or {}
    local s = d.shadow[rule] or {}
    d.shadow[rule] = s
    s[outcome] = (s[outcome] or 0) + 1
    d.events = d.events or {}
    if #d.events < OF.MAX_EVENTS then
        d.events[#d.events + 1] = { t = math.floor(now() * 1000 + 0.5) / 1000, r = rule, o = outcome, n = extra, pt = hint }
    end
end
local function targeting(key)
    local out, t = {}, now()
    for from, e in pairs(edges) do
        if e.to == key and t - e.t <= OF.EDGE_FRESH then out[#out + 1] = from end
    end
    return out
end
OF.Targeting = targeting
-- external facts (meter roster, scoreboard): name key + clear class -> cache (verified against later token reads)
function OF.Note(key, field, v, src)
    local c = OF.Cache()
    if not (c and key and v ~= nil) then return nil end
    return c:Put(key, field, v, src, OF.Context())
end
-- tt-attacker: I took a hit -> hostile units currently targeting me (0 / 1 / several candidates)
function OF.OnWound()
    local me = OF.KeyOf("player")
    if not me then return end
    local c = OF.Cache()
    local n, one = 0, nil
    for _, k in ipairs(targeting(me)) do
        if c and c:Get(k, "hostile") == true then n, one = n + 1, k end
    end
    -- v2.2.20: the single candidate's cached power type rides along (offline: checked against the log attacker's class)
    local hint = (n == 1 and c) and c:Get(one, "powerType") or nil
    shadowLog("tt-attacker", n == 0 and "none" or (n == 1 and "single" or "multi"), n, hint)
end
-- tt-same-class: auras of unit u changed -> same-class-as-me friendlies targeting it (does it single out me / another)
function OF.OnAura(u)
    local key = OF.KeyOf(u)
    local me = OF.KeyOf("player")
    if not key or not me or key == me then return end
    local c = OF.Cache()
    local myClass = c and c:Get(me, "class")
    if not myClass then return end
    local mine, others = false, 0
    for _, k in ipairs(targeting(key)) do
        if k == me then mine = true
        elseif c:Get(k, "class") == myClass and c:Get(k, "hostile") ~= true then others = others + 1 end
    end
    local o = (mine and others == 0 and "me-only") or (mine and "me+other") or (others == 1 and "other-single")
        or (others > 1 and "other-multi") or "none"
    shadowLog("tt-same-class", o, others)
end

-- prefill coverage: at a unit's first in-combat event, was class / max health / level already cached? ------------
local fightN, firstSeen = 0, {}
function OF.FirstInCombat(u)
    local key = OF.KeyOf(u)
    if not key or firstSeen[key] then return end
    firstSeen[key] = true
    local c = OF.Cache()
    if not c then return end
    local d = db()
    d.prefill = d.prefill or {}
    local kind = (c:Get(key, "isPlayer") == true and (c:Get(key, "hostile") == true and "enemyPlayer" or "friendlyPlayer"))
        or (c:Get(key, "isPlayer") == false and "npc") or "unknown"
    local p = d.prefill[kind] or { n = 0, class = 0, hpMax = 0, level = 0, any = 0 }
    d.prefill[kind] = p
    p.n = p.n + 1
    local any = false
    for _, fld in ipairs({ "class", "hpMax", "level" }) do
        if c:Fresh(key, fld) then p[fld] = p[fld] + 1 any = true end
    end
    if any then p.any = p.any + 1 end
end

-- sweeps (sliced) -----------------------------------------------------------------------------------------------------
local queue, qctx, lastFull, lastEdge, frame, ticker = {}, "ooc", -1000, -1000, nil, nil
function OF.QueueSweep(reason)
    local toks, L = OF.Tokens()
    local d = db()
    if d then
        d.limits = d.limits or {}
        for k, v in pairs(L) do d.limits[k] = math.max(d.limits[k] or 0, v) end
        d.sweeps = d.sweeps or {}
        d.sweeps[reason or "?"] = (d.sweeps[reason or "?"] or 0) + 1
    end
    queue = toks
    qctx = OF.Context()
    lastFull = now()
end
function OF.Step()
    local t, ctx = now(), OF.Context()
    if #queue == 0 then
        local period = ctx == "combat" and OF.COMBAT_PERIOD or OF.OOC_PERIOD
        if t - lastFull >= period then OF.QueueSweep("tick:" .. ctx) end
        if ctx == "combat" and t - lastEdge >= OF.EDGE_PERIOD then
            lastEdge = t
            local toks = OF.Tokens()
            for _, u in ipairs(toks) do if baseOf(u) then OF.ReadEdge(u) end end
        end
    end
    if ctx ~= qctx then qctx = ctx end
    local n = 0
    while #queue > 0 and n < OF.SLICE do
        local u = table.remove(queue)
        OF.ReadToken(u, qctx)
        if baseOf(u) then OF.ReadEdge(u) end
        if qctx == "combat" then OF.FirstInCombat(u) end
        n = n + 1
    end
end

local EVENTS = { "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "GROUP_ROSTER_UPDATE", "NAME_PLATE_UNIT_ADDED",
    "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UPDATE_MOUSEOVER_UNIT", "UNIT_TARGET", "ARENA_OPPONENT_UPDATE",
    "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "UNIT_PET", "PLAYER_ENTERING_WORLD", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
    "UNIT_COMBAT", "UNIT_AURA", "UPDATE_BATTLEFIELD_SCORE" }
OF.EVENTS = EVENTS
local lastEv = {}
local function throttled(k, gap)
    local t = now()
    if lastEv[k] and t - lastEv[k] < gap then return true end
    lastEv[k] = t
    return false
end
function OF.OnEvent(event, rawA1, rawA2)
    local a1 = ns.ClearStr(rawA1)
    local d = db()
    if not d then return end
    d.ev = d.ev or {}
    d.ev[event] = (d.ev[event] or 0) + 1
    if event == "PLAYER_REGEN_ENABLED" then
        lastRegen = now()
        firstSeen = {}
        OF.QueueSweep("regen-enabled")
        local D = ns.Derive
        if D and D.MeterSweep then pcall(D.MeterSweep, "oocfill") end
    elseif event == "PLAYER_REGEN_DISABLED" then
        fightN = fightN + 1
        firstSeen = {}
        d.fights = fightN
        local c = OF.Cache()
        d.cachedAtPull = d.cachedAtPull or {}
        d.cachedAtPull[#d.cachedAtPull + 1] = c and c:Count() or 0
        OF.QueueSweep("regen-disabled")
    elseif event == "UNIT_COMBAT" then
        if a1 == "player" then
            local w = ns.ClearStr(rawA2)
            if w == "WOUND" then OF.OnWound() end
        elseif a1 then
            local _, lock = rd("InCombatLockdown", 1)
            if lock == true then OF.FirstInCombat(a1) end
        end
    elseif event == "UNIT_AURA" then
        local _, lock = rd("InCombatLockdown", 1)
        if a1 and lock == true and not throttled("aura:" .. a1, 0.25) then OF.OnAura(a1) end
    elseif event == "UNIT_TARGET" then
        if a1 then OF.ReadEdge(a1 == "player" and "target" or (a1 .. "target")) end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if a1 then OF.ReadToken(a1, OF.Context()) end
    elseif event == "UPDATE_BATTLEFIELD_SCORE" then
        local D = ns.Derive
        if D and D.ScoreSweep and not throttled("score", 5) then pcall(D.ScoreSweep) end
    elseif not throttled("sweep", 1) then
        OF.QueueSweep(event)
    end
end

local started = false
function OF.Start()
    started = false
    if not active() then return false end
    local d = db()
    if not d then return false end
    for k in pairs(d) do d[k] = nil end
    d.v = 1
    cache, queue, fightN, firstSeen, lastFull = nil, {}, 0, {}, -1000
    for k in pairs(edges) do edges[k] = nil end
    for k in pairs(tokKey) do tokKey[k] = nil end
    if not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", function(_, event, ...)
            if not active() then return end
            local ok, err
            if ns.Perf then ok, err = ns.Perf.Run(ns.Perf.Key("OocFill", event), OF.OnEvent, event, ...)
            else ok, err = pcall(OF.OnEvent, event, ...) end
            if not ok and ns.NoteSelfError then ns.NoteSelfError("OocFill." .. event, err) end
        end)
    end
    for _, ev in ipairs(EVENTS) do pcall(frame.RegisterEvent, frame, ev) end
    local ct = g("C_Timer")
    if type(ct) == "table" and type(ct.NewTicker) == "function" then
        ticker = ct.NewTicker(OF.TICK, function()
            if not active() then return end
            if ns.Perf then ns.Perf.Run("OocFill.step", OF.Step) else pcall(OF.Step) end
        end)
    end
    OF.QueueSweep("start")
    started = true
    return true
end

function OF.Stop()
    -- v2.2.20: a stop with nothing gathered (capture off at logout, or a /reload mid-capture: modules do not resume)
    -- must not write empty stub tables into the SV, nor overwrite what the pre-reload session saved
    if not started and not cache then return nil end
    started = false
    if frame then pcall(frame.UnregisterAllEvents, frame) end
    if ticker and ticker.Cancel then ticker:Cancel() end
    ticker = nil
    local d = db()
    if not d then return nil end
    local c = OF.Cache()
    if c then
        d.cache = c:Export(2000)
        d.cacheStats = c.stats
        d.units = c:Count()
    end
    -- v2.2.20 identity check (run 15: all friendly reads collapsed into one key): raid tokens vs distinct keys now
    local rt, rk, seenK = 0, 0, {}
    for tok, e in pairs(tokKey) do
        if tok:find("^raid%d+$") then
            rt = rt + 1
            local k = c and c:Resolve(e.key) or e.key
            if not seenK[k] then seenK[k] = true rk = rk + 1 end
        end
    end
    d.identCheck = { raidTokens = rt, raidKeys = rk, linkConflicts = c and c.stats.linkConflicts or 0 }
    local s = { units = d.units or 0, contradictions = c and c.stats.contradictions or 0, verified = c and c.stats.verified or 0,
        drift = c and c.stats.drift or 0, merges = c and c.stats.merges or 0 }
    d.summary = s
    return s
end

ns.captureModules = ns.captureModules or {}
ns.captureModules[#ns.captureModules + 1] = { name = "ooc fill + unit-token sweep (capture level lab)", start = function() return OF.Start() end,
    stop = function()
        local s = OF.Stop()
        return s and string.format("oocfill: %d unit(s), %d verified, %d drift, %d contradiction(s), %d merge(s)",
            s.units, s.verified, s.drift, s.contradictions, s.merges)
    end }
