-- ForeverDump v2.2.18 - class (and spec where possible) evidence engine. Pure Lua 5.1, no WoW API: the driver
-- (Derive.lua) feeds readable observations, the engine keeps per identity a candidate class set + an evidence chain.
-- Identity keys are raw (v2.2.21): kind:<GUID> or name:<base name> (realm-stripped join key); the driver stores the
-- full names / GUIDs seen per key (Derive units[key].names / .guids).
-- Signals and their effect (all measured readable in BG runs 9-14, see docs/HSM-STATUS.md section 6):
--   direct      UnitClass clear (group members, out of combat)            -> assign (confidence high)
--   meter       C_DamageMeter source classFilename joined by name key      -> assign (high)
--   score       BG scoreboard class joined by name key (probe-dependent)   -> assign (high)
--   color       plate health-bar colour == a RAID_CLASS_COLORS entry       -> assign (medium; probe-dependent)
--   power       powerType: 0 mana / 1 rage / 2 focus / 3 energy           -> eliminate (never assigns alone)
--   comp        enemy team composition from the meter (classes present)   -> provisional only (v2.2.20: run 15 made
--               6+ false SHAMAN assignments from a partial per-session comp; it never settles a unit now)
--   summon      a summon / totem owned by the unit (RefData.summons)       -> eliminate to the owner class
--   spell       a CLEAR spellId cast by the unit (RefData.spells class)    -> assign (high)
-- A unit is assigned when one candidate is left or an assigning signal arrives. A contradiction (assigning signal
-- outside the candidate set, or an empty set) is recorded and the unit falls back to unknown: never guess.
local CE = {}
CE.__index = CE

CE.CLASSES = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }
CE.POWER = { [0] = { MAGE = true, PRIEST = true, WARLOCK = true, PALADIN = true, SHAMAN = true, HUNTER = true, DRUID = true },
             [1] = { WARRIOR = true, DRUID = true }, [3] = { ROGUE = true, DRUID = true }, [2] = { HUNTER = true } }
CE.POWER_NAMES = { MANA = 0, RAGE = 1, FOCUS = 2, ENERGY = 3 }
CE.ASSIGNING = { direct = true, meter = true, score = true, spell = true, color = true }

function CE.new(opts)
    opts = opts or {}
    local o = setmetatable({}, CE)
    o.units = {}
    o.clock = opts.clock or function() return 0 end
    o.ref = opts.ref           -- ns.RefData (optional): spells[id] = { classCode, ... }, summons[npcId] = classCode
    o.maxChain = opts.maxChain or 12
    o.stats = { assigned = 0, contradictions = 0, signals = 0 }
    o.comp = nil               -- enemy composition: set of classes present (nil = unknown)
    o.onAssign = opts.onAssign -- callback(key, class, via)
    return o
end

local function all()
    local s = {}
    for _, c in ipairs(CE.CLASSES) do s[c] = true end
    return s
end
local function count(s)
    local n, last = 0, nil
    for c in pairs(s) do n, last = n + 1, c end
    return n, last
end

local provisional   -- defined with Composition below

function CE:unit(key)
    local u = self.units[key]
    if not u then
        u = { cand = all(), chain = {}, first = self.clock() }
        self.units[key] = u
    end
    return u
end

local function note(self, u, via, v)
    self.stats.signals = self.stats.signals + 1
    local ch = u.chain
    if #ch < self.maxChain then ch[#ch + 1] = via .. "=" .. tostring(v) end
end

local function settle(self, key, u, via)
    if u.class then return end
    local n, last = count(u.cand)
    if n == 1 and u.contested and not CE.ASSIGNING[via] then return end   -- v2.2.20: after an elimination conflict
    if n == 1 then
        u.class, u.via, u.t = last, via, self.clock()
        self.stats.assigned = self.stats.assigned + 1
        if self.onAssign then self.onAssign(key, last, via) end
    elseif n == 0 then
        u.contradiction = (u.contradiction or 0) + 1
        self.stats.contradictions = self.stats.contradictions + 1
        u.cand = all()   -- fall back to unknown, never guess
        u.contested = true
    end
end

-- an assigning signal: the class itself
function CE:Assign(key, class, via)
    if not (key and type(class) == "string" and class ~= "") then return nil end
    local u = self:unit(key)
    note(self, u, via, class)
    if u.class then
        if u.class ~= class then
            u.contradiction = (u.contradiction or 0) + 1
            self.stats.contradictions = self.stats.contradictions + 1
            -- v2.2.20: a class settled by elimination yields to a reading source (run 15: clear reads contradicted
            -- comp-made classes 671 times and lost every time)
            if CE.ASSIGNING[via] and not CE.ASSIGNING[u.via] then
                self.stats.overridden = (self.stats.overridden or 0) + 1
                u.class, u.via, u.t, u.overrode = class, via, self.clock(), u.via
                if self.onAssign then self.onAssign(key, class, via) end
            end
        end
        return u.class
    end
    if not u.cand[class] then
        u.contradiction = (u.contradiction or 0) + 1
        self.stats.contradictions = self.stats.contradictions + 1
        -- an assigning source outranks elimination evidence: reset and take it (eliminations are the weaker kind)
    end
    u.cand = { [class] = true }
    settle(self, key, u, via)
    return u.class
end

-- an eliminating signal: a set of allowed classes
function CE:Allow(key, set, via, v)
    if not (key and type(set) == "table") then return nil end
    local u = self:unit(key)
    note(self, u, via, v)
    if u.class then
        if not set[u.class] then
            u.contradiction = (u.contradiction or 0) + 1
            self.stats.contradictions = self.stats.contradictions + 1
            -- v2.2.22 (run 16): name-key collisions can settle a wrong class via cache:raidN; a later
            -- power/summon elimination that rules that class out must revoke it. ASSIGNING sources
            -- (score/meter/spell/...) stay until another ASSIGNING source overrides via Assign().
            if not CE.ASSIGNING[u.via] then
                self.stats.overridden = (self.stats.overridden or 0) + 1
                u.overrode, u.class, u.via = u.via, nil, nil
                u.cand = all()
                for c in pairs(u.cand) do if not set[c] then u.cand[c] = nil end end
                settle(self, key, u, via)
                if u.enemy then provisional(self, key, u) end
                return u.class
            end
        end
        return u.class
    end
    for c in pairs(u.cand) do if not set[c] then u.cand[c] = nil end end
    settle(self, key, u, via)
    if u.enemy then provisional(self, key, u) end
    return u.class
end

function CE:Power(key, powerType)
    if type(powerType) == "string" then powerType = CE.POWER_NAMES[powerType] end
    local set = CE.POWER[powerType]
    if not set then return nil end
    return self:Allow(key, set, "power", powerType)
end

function CE:Spell(key, spellId)
    local r = self.ref and self.ref.spells and self.ref.spells[spellId]
    local code = r and r[1]
    local class = code and code > 0 and self.ref.classes and self.ref.classes[code]
    if class then return self:Assign(key, class, "spell") end
    return nil
end

function CE:Summon(key, npcId)
    local code = self.ref and self.ref.summons and self.ref.summons[npcId]
    local class = code and self.ref.classes and self.ref.classes[code]
    if class then return self:Allow(key, { [class] = true }, "summon", npcId) end
    return nil
end

-- enemy composition from the meter: { SHAMAN = 3, ... } (counts). v2.2.20: cumulative (a class once seen stays) and
-- PROVISIONAL only: a per-session meter lists only the enemies met so far, so the set is a lower bound of the team and
-- must never eliminate. A unit whose candidates intersect the set in exactly one class gets u.prov (never u.class).
provisional = function(self, _key, u)
    if u.class or not self.comp then return end
    local n, last = 0, nil
    for c in pairs(u.cand) do if self.comp[c] then n, last = n + 1, c end end
    local was = u.prov
    u.prov = (n == 1) and last or nil
    if u.prov and u.prov ~= was then note(self, u, "comp", u.prov) end
end
function CE:Composition(counts)
    if type(counts) ~= "table" then return end
    local any = false
    self.comp = self.comp or {}
    self.compCounts = self.compCounts or {}
    for c, n in pairs(counts) do
        if type(n) == "number" and n > 0 then
            self.comp[c] = true any = true
            if n > (self.compCounts[c] or 0) then self.compCounts[c] = n end
        end
    end
    if not any then return end
    for key, u in pairs(self.units) do
        if u.enemy then provisional(self, key, u) end
    end
end

function CE:MarkEnemy(key)
    local u = self:unit(key)
    -- v2.2.24 (run 18): a unique-first-name scoreboard row on MY faction is authoritative; a transient hostility
    -- (mind control: log flags 0x1148 = hostile pet on a friendly raid member) must not make a team-mate an enemy
    if u.friend then self.stats.enemyVetoed = (self.stats.enemyVetoed or 0) + 1 return end
    if not u.enemy then u.enemy = true end
    provisional(self, key, u)
end

-- v2.2.24: team membership from the scoreboard (faction clear in every phase). Clears a prior (transient) enemy mark.
function CE:MarkFriend(key, why)
    local u = self:unit(key)
    u.friend = why or true
    if u.enemy then
        u.enemy = nil
        u.prov = nil
        self.stats.enemyCleared = (self.stats.enemyCleared or 0) + 1
    end
end

function CE:Provisional(key)
    local u = self.units[key]
    return u and not u.class and u.prov or nil
end

function CE:Get(key)
    local u = self.units[key]
    if not u then return nil end
    return u.class, u.via, u
end

-- same-class enemies: assigned enemy units of that class, or the meter's count when larger
function CE:CountEnemy(class)
    local n = 0
    for _, u in pairs(self.units) do if u.enemy and u.class == class then n = n + 1 end end
    local m = self.compCounts and self.compCounts[class] or 0
    return math.max(n, m)
end

function CE:Summary()
    local out = { units = 0, assigned = 0, enemies = 0, enemyAssigned = 0, byVia = {}, contradictions = self.stats.contradictions,
        overridden = self.stats.overridden or 0, enemyVetoed = self.stats.enemyVetoed or 0,
        enemyCleared = self.stats.enemyCleared or 0 }
    for _, u in pairs(self.units) do
        out.units = out.units + 1
        if u.class then
            out.assigned = out.assigned + 1
            out.byVia[u.via] = (out.byVia[u.via] or 0) + 1
        end
        if u.enemy then
            out.enemies = out.enemies + 1
            if u.class then out.enemyAssigned = out.enemyAssigned + 1
            elseif u.prov then out.enemyProvisional = (out.enemyProvisional or 0) + 1 end
        end
    end
    return out
end

if type(select) == "function" then
    local _, ns = ...
    if type(ns) == "table" then ns.ClassEvidence = CE end
end
return CE
