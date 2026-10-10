-- ForeverDump v2.2.19 - UnitCache: per-identity cached facts (pure library, no game API).
-- Facts are read while clear (out of combat, prep, after combat, graveyard, ...) and kept for in-combat inference.
-- Every fact carries its source (token family / meter / score), first/last time, context, observation count and a
-- staleness TTL. Later clear reads VERIFY it: same value -> verified; a different value of a static fact (class, race,
-- sex, faction) -> CONTRADICTION -> the fact turns unknown (never guessed again for this unit); a different value of a
-- dynamic fact (level, max health/power, power type) -> drift (overwritten, counted).
-- Identity: one unit seen through many tokens merges onto ONE key: the GUID key when known; a name key seen together
-- with a GUID key on the same token is linked as an alias (Link). v2.2.21: keys are raw (kind:<GUID> / name:<base name>,
-- ReplayLog.IdKey) and the raw full name / GUID are cached as facts (name, guid).
local _, ns = ...
local UC = {}

UC.STATIC = { class = true, race = true, sex = true, faction = true, ownerKey = true, guildKey = true }
-- seconds until a fact is stale (nil = never: static facts only change by contradiction)
UC.TTL = { level = 900, hpMax = 600, powerType = 300, powerMax = 600, auras = 120, spec = 1800, isPlayer = nil,
    hostile = 1800 }

local C = {}
C.__index = C

function UC.new(opts)
    opts = opts or {}
    local o = setmetatable({ units = {}, alias = {}, clock = opts.clock or function() return 0 end,
        stats = { puts = 0, new = 0, verified = 0, drift = 0, contradictions = 0, merges = 0, unknownPuts = 0 } }, C)
    return o
end

function C:Resolve(key)
    local n = 0
    while key and self.alias[key] and n < 8 do key = self.alias[key] n = n + 1 end
    return key
end

function C:Unit(key, create)
    key = self:Resolve(key)
    if not key then return nil end
    local u = self.units[key]
    if not u and create then u = { f = {}, first = self.clock(), toks = {} } self.units[key] = u end
    return u, key
end

-- put one fact; returns "new" | "verified" | "drift" | "contradiction" | "unknown"
function C:Put(key, field, v, src, ctx)
    if key == nil or v == nil then return nil end
    local u = self:Unit(key, true)
    local t = self.clock()
    local f = u.f[field]
    self.stats.puts = self.stats.puts + 1
    if not f then
        u.f[field] = { v = v, src = src, t = t, t0 = t, ctx = ctx, n = 1 }
        self.stats.new = self.stats.new + 1
        return "new"
    end
    if f.unknown then
        self.stats.unknownPuts = self.stats.unknownPuts + 1
        return "unknown"
    end
    if f.v == v then
        f.n, f.t, f.src, f.ctx = f.n + 1, t, src, ctx
        f.verified = (f.verified or 0) + 1
        self.stats.verified = self.stats.verified + 1
        return "verified"
    end
    if UC.STATIC[field] then
        f.unknown, f.v, f.conflictSrc, f.t = true, nil, src, t
        self.stats.contradictions = self.stats.contradictions + 1
        return "contradiction"
    end
    f.v, f.t, f.src, f.ctx, f.n = v, t, src, ctx, f.n + 1
    f.drift = (f.drift or 0) + 1
    self.stats.drift = self.stats.drift + 1
    return "drift"
end

-- value, age (s), stale?, source  (nil when unknown / never seen)
function C:Get(key, field)
    local u = self:Unit(key)
    local f = u and u.f[field]
    if not f or f.unknown then return nil end
    local age = self.clock() - f.t
    local ttl = UC.TTL[field]
    return f.v, age, (ttl ~= nil and age > ttl) or false, f.src
end

function C:Fresh(key, field)
    local v, _, stale = self:Get(key, field)
    if v == nil or stale then return nil end
    return v
end

-- link two keys of one unit (GUID key + name key on the same token): b's facts merge into a, b becomes an alias
local GUIDKIND = { player = true, pet = true, guid = true }
local function kindOf(k) return type(k) == "string" and k:match("^(%a+):") or nil end
function C:Link(a, b)
    local nb = b
    if nb and self.ambiguous and self.ambiguous[nb] then return self:Resolve(a) end
    a, b = self:Resolve(a), self:Resolve(b)
    if not a or not b or a == b then return a end
    -- v2.2.20 (run 15: every friendly read collapsed into one identity): two GUID-rooted identities are never merged.
    -- A name key that would join two of them is ambiguous: unlinked, and never linked again this session.
    if GUIDKIND[kindOf(a)] and GUIDKIND[kindOf(b)] then
        self.stats.linkConflicts = (self.stats.linkConflicts or 0) + 1
        if nb and nb ~= b then
            self.ambiguous = self.ambiguous or {}
            self.ambiguous[nb] = true
            self.alias[nb] = nil
        end
        return a
    end
    local ub = self.units[b]
    self.alias[b] = a
    self.stats.merges = self.stats.merges + 1
    if ub then
        local ua = self:Unit(a, true)
        for field, f in pairs(ub.f) do
            if f.unknown then
                if not ua.f[field] then ua.f[field] = f end
            else
                local r = self:Put(a, field, f.v, f.src, f.ctx)
                if r == "new" then ua.f[field].t0, ua.f[field].t = f.t0, f.t end
            end
        end
        for tok, n in pairs(ub.toks) do ua.toks[tok] = (ua.toks[tok] or 0) + n end
        if ub.first < ua.first then ua.first = ub.first end
        self.units[b] = nil
    end
    return a
end

function C:SeenVia(key, fam)
    local u = self:Unit(key, true)
    u.toks[fam] = (u.toks[fam] or 0) + 1
end

function C:Count()
    local n = 0
    for _ in pairs(self.units) do n = n + 1 end
    return n
end

-- SavedVariables view: raw keys and raw values as cached (v2.2.21)
function C:Export(maxUnits)
    local out, n = {}, 0
    for key, u in pairs(self.units) do
        n = n + 1
        if maxUnits and n > maxUnits then break end
        local r = { first = u.first, toks = u.toks, f = {} }
        for field, f in pairs(u.f) do
            r.f[field] = { v = f.v, src = f.src, t = f.t, t0 = f.t0, ctx = f.ctx, n = f.n, verified = f.verified,
                drift = f.drift, unknown = f.unknown }
        end
        out[key] = r
    end
    return out
end

if ns then ns.UnitCache = UC end
return UC
