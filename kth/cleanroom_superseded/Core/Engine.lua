-- K.T.H. Forever - Core/Engine.lua
-- Pure-Lua evidence engine. Inputs are already-clear values (names, sides, class tokens, timestamps).
-- No WoW API here, so it replays offline unchanged. No division anywhere (ratios are cross-multiplied).
local _, ns = ...
local E = {}
ns.E = E

E.HEALER_CLASS = { PRIEST = true, PALADIN = true, SHAMAN = true, DRUID = true }

-- Defaults chosen before scoring (see docs/README.md); /kth set <k> <v> can tune them in game.
E.CFG = {
    healMin = 2,        -- unique heal-on-other moments (frame-joined) needed for a claim
    healPct = 60,       -- heal moments must be >= healPct % of (heal + damage) moments
    unknownHealMin = 3, -- stricter when the class is unknown (no scoreboard join)
    probableMin = 1,    -- probable tier (display off by default)
    expire = 0,         -- 0 = claims last the whole match
}

local R = {}          -- key -> record
E.R = R
E.listeners = {}

local function key(side, name) return side .. ":" .. name end
E.key = key

function E.reset()
    for k in pairs(R) do R[k] = nil end
    E.roster = {}
    E.stats = { joinFrames = 0, joinAmbig = 0, healLinks = 0, dmgLinks = 0, contradictions = 0 }
end
E.reset()

local function notify(rec, what)
    for _, f in ipairs(E.listeners) do pcall(f, rec, what) end
end

function E.get(side, name)
    if not side or not name then return nil end
    local k = key(side, name)
    local r = R[k]
    if not r then
        r = { key = k, side = side, name = name, heal = 0, dmg = 0, casts = 0, mana = 0, nomana = 0,
              lastHealT = -1e9, lastDmgT = -1e9 }
        R[k] = r
        local ro = E.roster[k]
        if ro then r.class, r.full, r.ambiguous = ro.class, ro.full, ro.ambiguous end
    end
    return r
end

-- Scoreboard row (clear fields only). Same side + same first name twice -> ambiguous, never joined.
function E.rosterRow(side, first, full, classToken, t)
    if not side or not first then return end
    local k = key(side, first)
    local ro = E.roster[k]
    if ro and ro.full ~= full then
        ro.ambiguous = true
    elseif not ro then
        E.roster[k] = { full = full, class = classToken, side = side, first = first, t = t }
        ro = E.roster[k]
    elseif classToken and not ro.class then
        ro.class = classToken
    end
    local r = R[k]
    if r then r.class, r.full, r.ambiguous = ro.class, ro.full, ro.ambiguous; E.evaluate(r, t) end
end

function E.classOf(r)
    if r.ambiguous then return nil end
    return r.class
end

function E.power(r, isMana)
    if not r then return end
    if isMana then r.mana = r.mana + 1 else r.nomana = r.nomana + 1 end
end

-- One frame bucket: casters = { key -> rec }, heals/wounds = list of target recs.
function E.join(t, casters, nCasters, heals, wounds)
    if nCasters == 0 then return end
    E.stats.joinFrames = E.stats.joinFrames + 1
    if nCasters > 1 then E.stats.joinAmbig = E.stats.joinAmbig + 1; return end
    local c
    for _, r in pairs(casters) do c = r end
    c.casts = c.casts + 1
    local healed, hurt = false, false
    for _, tr in ipairs(heals) do
        if tr ~= c and tr.side == c.side then healed = true end
    end
    for _, tr in ipairs(wounds) do
        if tr.side ~= c.side then hurt = true end
    end
    if healed then
        c.heal = c.heal + 1; c.lastHealT = t; E.stats.healLinks = E.stats.healLinks + 1
        if not c.firstHealT then c.firstHealT = t end
    end
    if hurt then c.dmg = c.dmg + 1; c.lastDmgT = t; E.stats.dmgLinks = E.stats.dmgLinks + 1 end
    if healed or hurt then E.evaluate(c, t) end
end

-- Direct evidence from a clear source (clear spellID of a healer-signature spell, clear scoreboard healing).
function E.direct(r, t, reason, strength)
    if not r then return end
    r.direct = (r.direct or 0) + (strength or 1)
    r.directReason = reason
    E.evaluate(r, t)
end

function E.manual(r, t, on)
    if not r then return end
    r.manual = on and true or nil
    E.evaluate(r, t)
end

function E.evaluate(r, t)
    local cfg = E.CFG
    local cls = E.classOf(r)
    local before = r.claim
    local claim, why = nil, nil
    if cls and not E.HEALER_CLASS[cls] then
        if r.heal >= cfg.healMin and not r.contradicted then
            r.contradicted = true; E.stats.contradictions = E.stats.contradictions + 1
        end
    else
        local need = cls and cfg.healMin or cfg.unknownHealMin
        local share = r.heal * 100 >= cfg.healPct * (r.heal + r.dmg)
        if r.direct and r.direct >= 1 then
            claim, why = "HEALER", r.directReason or "direct"
        elseif r.heal >= need and share then
            claim, why = "HEALER", "heal-links " .. r.heal .. "/" .. (r.heal + r.dmg)
        elseif r.heal >= cfg.probableMin and share then
            claim, why = "PROBABLE", "heal-links " .. r.heal .. "/" .. (r.heal + r.dmg)
        end
    end
    if r.manual then claim, why = "HEALER", "manual" end
    -- false-claim discipline: once HEALER, a confirmed claim only drops if damage evidence overtakes it
    if before == "HEALER" and claim ~= "HEALER" and not r.manual then
        if cls and not E.HEALER_CLASS[cls] then claim = nil
        elseif r.heal * 100 >= cfg.healPct * (r.heal + r.dmg) or (r.direct and r.direct >= 1) then claim = "HEALER" end
    end
    r.claim, r.why = claim, why or r.why
    if claim == "HEALER" and not r.claimT then r.claimT = t end
    if claim ~= before then notify(r, claim) end
end

-- iterator over claimed records
function E.healers(side, includeProbable)
    local out = {}
    for _, r in pairs(R) do
        if (not side or r.side == side) and (r.claim == "HEALER" or (includeProbable and r.claim == "PROBABLE")) then
            out[#out + 1] = r
        end
    end
    table.sort(out, function(a, b) return a.key < b.key end)
    return out
end
