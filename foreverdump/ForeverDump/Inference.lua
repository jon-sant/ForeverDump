-- ForeverDump v2.2 - inference layer + live hybrid state machine (HSM) during an FD_Logs capture.
-- Inputs (live, readable only): the player's and probed units' UNIT_SPELLCAST_* events, UNIT_AURA updateInfo
-- (auraInstanceIDs / fields only when non-secret), readable aura counts (GetAuraSlots), restriction state and the
-- spell knowledge cached while readable (Knowledge.lua). No CLEU (forbidden live), no side channels, no parsing of
-- secret text. The HSM (Lib/HybridState.lua, reusable) predicts each player cast (aura + duration, amount range,
-- cooldown end) and tracks per-unit state; this module logs the readable signals, the rule-input readability per
-- context, every prediction/inference (with rule + confidence) and live contradictions, so the converter can replay
-- and score them against the WoWCombatLog file offline (fdump.py inference / hsm).
local _, ns = ...
local I = {}
ns.Inference = I

local function g(n) return rawget(_G, n) end
local function code(v) return ns.ClassifyValue(v) end
-- v2.2.7: classify first; never `and v or nil` (that truth-tests v)
local function clear(v)
    local c = code(v)
    if c == "C" or c == "K" then return v end
    return nil
end
local isTrue, isNil = ns.IsTrue, ns.IsNil
local function now() return (g("GetTime") or os.clock)() end
local function cfg() return (ns.config and ns.config.hsm) or {} end
local function capturing() return ns.db and ns.db.logs and ns.db.logs.on and ns.db.logs.session ~= nil end

local UNITS = { player = true, target = true, focus = true, party1 = true, party2 = true, party3 = true, party4 = true, pet = true }
I.UNITS = UNITS

local function db()
    local log = g("ForeverDumpLogDB")
    if type(log) ~= "table" then return nil end
    log.inference = log.inference or { v = 1 }
    return log.inference
end
I.DB = db

local function ctxName() return ns.CombatProbe and ns.CombatProbe.Context() or (ns.InCombat() and "combat" or "ooc") end
local function dirty() if ns.HSMUI and ns.HSMUI.MarkDirty then ns.HSMUI.MarkDirty() end end

-- rule-input readability per context
local function seen(sig, readable)
    local d = db()
    if not d then return end
    local ctx = ctxName()
    d.inputs = d.inputs or {}
    d.inputs[ctx] = d.inputs[ctx] or {}
    local r = d.inputs[ctx][sig]
    if not r then r = { r = 0, u = 0 } d.inputs[ctx][sig] = r end
    if readable then r.r = r.r + 1 else r.u = r.u + 1 I.unreadable = (I.unreadable or 0) + 1 end
    if ns.Verify then ns.Verify.Seen(ctx, sig, readable) end   -- v2.2.4: readability flip vs baseline = unexpected
end
I.Seen = seen

local function guidOf(unit)
    local f = g("UnitGUID")
    if type(f) ~= "function" then return nil end
    local ok, v = pcall(f, unit)
    return ok and clear(v) or nil
end
-- HSM unit key: GUID when readable; v2.2.4 ledger: else the token's last clear GUID while that mapping is not stale
-- (Identity.lua marks it stale when the token changes with an unreadable GUID); else the token itself
local function keyOf(unit)
    if unit == "player" then return "player" end
    local gd = guidOf(unit)
    if gd then return gd end
    local L = I.hs and I.hs.ledger
    if L and L.data.token and L.data.token[unit] and not L.data.token[unit].stale then
        local e = L:Get("token", unit)
        if e and e.guid then I.hs.counters.keyFromLedger = (I.hs.counters.keyFromLedger or 0) + 1 return e.guid end
    end
    return unit
end
I.KeyOf = keyOf

local function signal(rec)
    local d = db()
    if not d or cfg().signals == false then return end
    d.signals = d.signals or {}
    if #d.signals >= (tonumber(cfg().maxSignals) or 3000) then d.signalsDropped = (d.signalsDropped or 0) + 1 return end
    rec.t = now()
    d.signals[#d.signals + 1] = rec
end

----------------------------------------------------------------------------
-- HSM instance
----------------------------------------------------------------------------
-- v2.2.3 (run 4): the HSM copied the spell knowledge only once at Start. On a fresh SV the knowledge pass runs AFTER
-- Start (chunked), so the whole run-4 session predicted with no knowledge (16/16 predictions known=false: no aura,
-- duration, cooldown or target rule -> everything "unverified"). Knowledge is now fed in as it is collected
-- (Knowledge.onCollected) and looked up lazily on the first cast of a spell.
local function learnFromKnowledge(hs, id)
    if not (hs and ns.Knowledge and type(id) == "number") then return false end
    local kdb = ns.Knowledge.DB()
    local e = kdb and kdb.spells and kdb.spells[id]
    local k = e and ns.Knowledge.ToHSM(e)
    if k then hs:Learn(id, k) return true end
    return false
end
I.LearnFromKnowledge = learnFromKnowledge

-- v2.2.8 (runs 6/6b): engine health. One failing helper (Drift.Decay -> `os` inside Timing.Attach) used to abort
-- I.NewHSM and the live engine never ran, silently. Now every helper attach is isolated: a failure costs that seed /
-- callback only (state "degraded"); only a failed HybridState.New (or a failed I.Start) is "down". Either is shown
-- once in chat, on the HSM window and in the replay tape header (hdr.stats.hsm).
I.health = { state = "off", failed = {} }
local function noteFail(name, err)
    local h = I.health
    h.failed[name] = string.sub(tostring(err), 1, 160)
    if ns.NoteSelfError then ns.NoteSelfError("hsm:" .. name, err) end
end
function I.Health() return I.health end
function I.MarkDown(name, err)
    noteFail(name, err)
    I.health.state = "down"
    I.WarnHealth()
end
function I.WarnHealth()
    local h = I.health
    if h.warned or (h.state ~= "down" and h.state ~= "degraded") then return end
    h.warned = true
    local names = {}
    for k in pairs(h.failed) do names[#names + 1] = k end
    table.sort(names)
    if ns.Print then
        if h.state == "down" then
            ns.Print("|cffff4040ENGINE DOWN|r: the live HSM did not start (" .. table.concat(names, ", ")
                .. "). This capture records raw events only; please report it.")
        else
            ns.Print("|cffffd100engine degraded|r: HSM running without " .. table.concat(names, ", ") .. " (see /fdump errors).")
        end
    end
    if ns.HSMUI and ns.HSMUI.MarkDirty then pcall(ns.HSMUI.MarkDirty) end
end

function I.NewHSM()
    local Lib = g("HybridState")
    if type(Lib) ~= "table" then noteFail("HybridState", "library missing") return nil end
    local shadow = ns.ReplayLog and ns.ReplayLog.IsTest and ns.ReplayLog.IsTest()
    -- v2.2.15: lab level (FD_Logs capture default) runs the parallel candidate rules in shadow mode
    local lab = ns.LabActive and ns.LabActive() or nil
    -- v2.2.16 lab: no arbitrary ring caps (collect first); release/diag keep 2000 / 10 / 300
    local huge = lab and math.huge or nil
    local opts = { now = now, window = tonumber(cfg().window) or 0.6, shadowFindings = shadow or nil, candidates = lab, clock = g("debugprofilestop"),
        maxLog = huge, maxFights = huge, candAuraMax = huge,
        idKey = (ns.ReplayLog and ns.ReplayLog.IdKey) or nil,
        onContradiction = function(c) local d = db() if d then d.live = d.live or {} if lab or #d.live < 200 then d.live[#d.live + 1] = c end end end }
    local hs   -- internal library object, assigned inside the pcall'd closure (only the error string leaves pcall)
    local okN, errMsg = pcall(function() hs = Lib.New(opts) end)
    if not okN then noteFail("HybridState.New", errMsg) return nil end
    if type(hs) ~= "table" then noteFail("HybridState.New", "no state") return nil end
    local function step(name, fn)
        local ok, err = pcall(fn)
        if not ok then noteFail(name, err) end
    end
    if ns.Knowledge then
        step("Knowledge", function()
            local kdb = ns.Knowledge.DB()
            for id, e in pairs((kdb and kdb.spells) or {}) do
                local k = ns.Knowledge.ToHSM(e)
                if k then hs:Learn(id, k) end
            end
        end)
    end
    step("KnowledgePatch", function() I.ApplyKnowledgePatch(hs, ns.KnowledgePatch) end)
    step("SelfLink", function() I.SeedSelfLink(hs) end)   -- v2.2.16: learned cast -> aura-on-me links
    if ns.Timing then step("Timing", function() ns.Timing.Attach(hs) end) end    -- GCD / cooldown seed (CooldownTracker)
    if ns.Learned then step("Learned", function() ns.Learned.Attach(hs) end) end -- cast -> aura map + own damage / heal ranges
    return hs
end

-- v2.2.16 attribution safety: the learned "my cast of X puts an aura on me" statistics (casts, same-frame hits).
-- Seeded from Data/SelfLinkSeed.lua (earlier captures' live signals, generated offline) plus this account's own
-- totals (ForeverDumpDB.hsmSelfLink, spellID -> { casts, hits }; numbers only). Stop() adds this session's counts.
function I.SeedSelfLink(hs)
    if not (hs and hs.SeedSelfLink) then return 0 end
    local n = 0
    local seed = ns.SelfLinkSeed and ns.SelfLinkSeed.spells
    if type(seed) ~= "table" then seed = {} end
    for id, v in pairs(seed) do
        if type(v) == "table" then hs:SeedSelfLink(tonumber(id), tonumber(v[1]), tonumber(v[2])) n = n + 1 end
    end
    local acc = g("ForeverDumpDB")
    if type(acc) == "table" then acc = acc.hsmSelfLink end
    if type(acc) ~= "table" then acc = {} end
    for id, v in pairs(acc) do
        if type(v) == "table" then hs:SeedSelfLink(tonumber(id), tonumber(v.casts), tonumber(v.hits)) n = n + 1 end
    end
    I.selfLinkBase = {}
    for id, v in pairs(hs.selfLink or {}) do I.selfLinkBase[id] = { casts = v.casts, hits = v.hits } end
    return n
end
function I.SaveSelfLink(hs)
    local acc = g("ForeverDumpDB")
    if not (hs and type(acc) == "table" and hs.selfLink) then return end
    acc.hsmSelfLink = acc.hsmSelfLink or {}
    local base = I.selfLinkBase or {}
    for id, v in pairs(hs.selfLink) do
        local b = base[id] or { casts = 0, hits = 0 }
        local dc, dh = v.casts - b.casts, v.hits - b.hits
        if dc > 0 or dh > 0 then
            local a = acc.hsmSelfLink[id] or { casts = 0, hits = 0 }
            a.casts, a.hits = a.casts + math.max(0, dc), a.hits + math.max(0, dh)
            acc.hsmSelfLink[id] = a
        end
        base[id] = { casts = v.casts, hits = v.hits }
    end
    I.selfLinkBase = base
end

-- v2.2.16 census for the ambiguity guard: same-class actors around me, from the clear UnitClass of group members
-- (raidN / partyN) and of enemy players on plates / arena frames (seen in the last 60 s). Counts only leave this
-- function (signal "census"); identities stay in memory, keyed by token-free clear GUIDs when readable.
local censusEnemy, censusLast, censusT = {}, nil, 0
local meterEnemy = { n = 0, t = nil }
function I.SetMeterEnemyCensus(n, t)
    if type(n) ~= "number" then return end
    meterEnemy.n, meterEnemy.t = n, t
end
local function classOf(unit)
    local uc = g("UnitClass")
    if not uc then return nil end
    local ok, _, file = pcall(uc, unit)
    if not ok then return nil end
    return ns.ClearStr and ns.ClearStr(file) or nil
end
function I.Census(force)
    local hs = I.hs
    if not (hs and hs.SetCensus) then return nil end
    local t = now()
    if not force and t - censusT < 2 then return nil end
    censusT = t
    local mine = classOf("player")
    if not mine then return nil end
    local ex, same, n = g("UnitExists"), 0, 0
    local okR, raid = pcall(g("IsInRaid") or error)
    local inRaid = okR and isTrue(raid)
    local prefix, maxN = "party", 4
    if inRaid then prefix, maxN = "raid", 40 end
    for i = 1, maxN do
        local u = prefix .. i
        local okE, e = pcall(ex, u)
        if okE and isTrue(e) then
            local okP, isMe = pcall(g("UnitIsUnit"), u, "player")
            if not (okP and isTrue(isMe)) then
                n = n + 1
                if classOf(u) == mine then same = same + 1 end
            end
        end
    end
    local function enemy(u)
        local okE, e = pcall(ex, u)
        if not (okE and isTrue(e)) then return end
        local okP, pl = pcall(g("UnitIsPlayer"), u)
        local okA, ca = pcall(g("UnitCanAttack"), "player", u)
        if not (okP and isTrue(pl) and okA and isTrue(ca)) or classOf(u) ~= mine then return end
        local okG, guid = pcall(g("UnitGUID"), u)
        local key = okG and ns.ClearStr and ns.ClearStr(guid) or u
        censusEnemy[key] = t
    end
    for i = 1, 40 do enemy("nameplate" .. i) end
    for i = 1, 5 do enemy("arena" .. i) end
    local se = 0
    for k, tt in pairs(censusEnemy) do if t - tt <= 60 then se = se + 1 else censusEnemy[k] = nil end end
    -- v2.2.18 (run 14: plate class is secret in BG -> se was always 0, log said 3): the damage meter lists the enemy
    -- team with a clear classFilename (Derive.lua, lab capture) -> its same-class count, fresh for 120 s
    if meterEnemy.t and t - meterEnemy.t <= 120 and meterEnemy.n > se then se = meterEnemy.n end
    hs:SetCensus({ sameClass = same, sameClassEnemy = se, n = n })
    local key = same .. ":" .. se
    if key ~= censusLast then
        censusLast = key
        signal({ e = "census", same = same, sameEnemy = se, n = n })
    end
    return same, se
end

-- v2.2.4: facts observed in earlier real captures (Data/KnowledgePatch.lua, generated offline by `fdump.py verify-live` /
-- `analyze`). LOWER priority than anything collected live: a field is only filled when the live knowledge lacks it, and
-- a patched NPC cast time is one prior sample that live observations push out of the 8-entry model.
function I.ApplyKnowledgePatch(hs, patch)
    if not (hs and type(patch) == "table") then return 0 end
    local n = 0
    for id, e in pairs(type(patch.spells) == "table" and patch.spells or {}) do
        id = tonumber(id)
        local cur = id and hs.knowledge[id] or {}
        local k = {}
        if type(e.auraId) == "number" and cur.auraId == nil then k.auraId = e.auraId end
        if type(e.auraObserved) == "number" and not (cur.aura and cur.aura.duration) then k.aura = { duration = e.auraObserved, patched = true } end
        if e.interrupt and not cur.interrupt then k.interrupt = true k.lockout = tonumber(e.lockout) end
        if id and next(k) then hs:Learn(id, k) n = n + 1 end
    end
    for npc, c in pairs(type(patch.npcCasts) == "table" and patch.npcCasts or {}) do
        local key = "npc:" .. tostring(npc)
        if type(c) == "table" and type(c.castMedian) == "number" and hs.castModel and not hs.castModel[key] then
            hs.castModel[key] = { d = { c.castMedian }, n = 0, patched = true }
            n = n + 1
        end
    end
    return n
end

----------------------------------------------------------------------------
-- event handlers
----------------------------------------------------------------------------
local tried = {}
-- v2.2.4: cast-model key of a hostile unit: npcID from the clear (or ledger-cached) GUID, else the Identity fingerprint
local function castKeyOf(unit)
    local Lib = rawget(_G, "HybridState")
    local k = keyOf(unit)
    local nk = Lib and Lib.NpcKey and Lib.NpcKey(k)
    if nk then return nk end
    local st = ns.Identity and ns.Identity.state and ns.Identity.state[unit]
    return st and st.fp and ("fp:" .. st.fp) or nil
end
I.CastKeyOf = castKeyOf
local ENEMY_CAST = { UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_SUCCEEDED = true, UNIT_SPELLCAST_INTERRUPTED = true,
    UNIT_SPELLCAST_FAILED = true, UNIT_SPELLCAST_CHANNEL_START = true, UNIT_SPELLCAST_CHANNEL_STOP = true }

local function onCast(event, rawUnit, castGUID, spellID, a4, a5)
    local unit = ns.ClearStr(rawUnit)   -- v2.2.7: event payloads are API values (never index/compare them raw)
    if not unit then return end
    if not UNITS[unit] and not (type(unit) == "string" and unit:find("^nameplate")) then return end
    local sid = clear(spellID)
    if ns.Verify and (unit == "player" or unit == "target") then   -- v2.2.4: payload shape per event + token class
        ns.Verify.Shape(event .. (unit == "player" and ":player" or ":target"),
            code(castGUID) .. code(spellID) .. code(a4) .. (event == "UNIT_SPELLCAST_INTERRUPTED" and code(a5) or ""))
    end
    if I.hs and unit == "player" and (event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET") and I.hs.OnCastFailed then
        local okD, dead = pcall(g("UnitIsDeadOrGhost") or error, "player")   -- v2.2.16: dead -> no cooldown evidence
        I.hs:OnCastFailed(sid, event, okD and isTrue(dead) or nil)   -- v2.2.4: cooldown evidence (spellID is clear for the player on 1.60.1)
    end
    if I.hs and I.hs.OnEnemyCast and ENEMY_CAST[event] and (unit == "target" or unit == "focus") then
        -- v2.2.4: hostile cast timing (unit token + castBarID clear; castGUID/spellID/interruptedBy secret on 1.60.1)
        local uca = g("UnitCanAttack")
        local okA, ca = pcall(uca or function() return nil end, "player", unit)
        if okA and isTrue(ca) then
            local bar = clear(a4)
            if event == "UNIT_SPELLCAST_INTERRUPTED" then bar = clear(a5) end   -- v2.2.7: was `and a5 or a4` (truth test)
            I.hs:OnEnemyCast(event, keyOf(unit), castKeyOf(unit), bar, sid)
            dirty()
        end
    end
    if sid and unit == "player" and I.hs and not I.hs.knowledge[sid] and not tried[sid] then
        tried[sid] = true
        learnFromKnowledge(I.hs, sid)
        if not I.hs.knowledge[sid] and ns.Verify then ns.Verify.Unexpected("unknown-own-spell", sid) end
    end
    local isPlayer = unit == "player"
    seen((isPlayer and "playerCast" or "unitCast") .. ".event", true)
    seen((isPlayer and "playerCast" or "unitCast") .. ".spellID", sid ~= nil)
    seen((isPlayer and "playerCast" or "unitCast") .. ".castGUID", clear(castGUID) ~= nil)
    local target
    if ns.Knowledge then
        if isPlayer and event == "UNIT_SPELLCAST_SUCCEEDED" and ns.Knowledge.OnOwnCast then ns.Knowledge.OnOwnCast(sid) end
        if sid and not isPlayer and ns.Knowledge.Enqueue then ns.Knowledge.Enqueue(sid) end   -- foreign spell seen clear
    end
    if isPlayer and event == "UNIT_SPELLCAST_SUCCEEDED" then
        if ns.ReplayLog and sid then ns.ReplayLog.OnOwnSucceeded(sid, unit) end
        local ue = g("UnitExists")
        local okE, ex = pcall(ue or function() return nil end, "target")
        local k = sid and I.hs and I.hs.knowledge[sid]
        -- v2.2.2: self/helpful/summon spells cast while a hostile is targeted land on the player (run 3: Lesser Healing
        -- Wave and totems were predicted on the creature target)
        local hostile = false
        local uca = g("UnitCanAttack")
        local hasTarget = okE and isTrue(ex)
        if hasTarget and uca then local okA, ca = pcall(uca, "player", "target") hostile = okA and isTrue(ca) end
        if k and ((k.aura and k.aura.self) or k.summon or (k.helpful and (hostile or not hasTarget))) then target = "player"
        else target = hasTarget and keyOf("target") or "player" end
    end
    signal({ e = "cast", ev = event:gsub("^UNIT_SPELLCAST_", ""), unit = unit, guid = guidOf(unit), sid = sid,
        sidState = code(spellID), target = target })
    if I.hs then I.hs:OnCast(event, keyOf(unit), sid, isPlayer, target) end
    if isPlayer or unit == "target" then dirty() end
end

-- PLAYER_TOTEM_UPDATE(slot): GetTotemInfo readability per field (codes only) + clear values to the HSM
local function onTotem(slot)
    local gti = g("GetTotemInfo")
    local s = clear(slot)
    seen("totem.slot", s ~= nil)
    if not (gti and s) then return end
    local res = ns.Pack(pcall(gti, s))
    if not res[1] then seen("totem.info", false) signal({ e = "totem", slot = s, err = true }) return end
    local have, name, start, dur = res[2], res[3], res[4], res[5]
    seen("totem.haveTotem", clear(have) ~= nil) seen("totem.name", clear(name) ~= nil)
    seen("totem.startTime", clear(start) ~= nil) seen("totem.duration", clear(dur) ~= nil)
    signal({ e = "totem", slot = s, have = clear(have), haveState = code(have), nameState = code(name), startState = code(start),
        durState = code(dur), dur = clear(dur) })
    if I.hs then I.hs:OnTotem(s, clear(have), clear(name), clear(dur)) end
end

local SHAPE_KEYS = { "isFullUpdate", "addedAuras", "updatedAuraInstanceIDs", "removedAuraInstanceIDs" }
local function auraSummary(_unit, rawInfo)
    local s = { added = {}, removed = {} }
    local info = ns.ClearTable(rawInfo)   -- v2.2.7: indexed only once classified as a non-secret table
    if not info then seen("aura.updateInfo", false) return nil end
    if ns.Verify then   -- v2.2.4: payload shape (which keys are present, and their codes)
        local sig = {}
        for i, k in ipairs(SHAPE_KEYS) do local v = info[k] if isNil(v) then sig[i] = "-" else sig[i] = code(v) end end
        ns.Verify.Shape("UNIT_AURA", table.concat(sig))
    end
    seen("aura.updateInfo", true)
    local full = clear(info.isFullUpdate)
    s.full = full == true
    local added = info.addedAuras
    if type(added) == "table" and code(added) ~= "S" then
        s.addedCount = #added
        for i = 1, math.min(#added, 16) do
            local a = added[i]
            if type(a) == "table" and code(a) ~= "S" then
                local iid, spell, fromP = clear(a.auraInstanceID), clear(a.spellId), clear(a.isFromPlayerOrPlayerPet)
                local helpful = clear(a.isHelpful)
                local harmful = clear(a.isHarmful)   -- v2.2.7: was `not a.isHarmful` on the raw field
                if helpful == nil and harmful ~= nil then helpful = not harmful end
                seen("aura.auraInstanceID", iid ~= nil) seen("aura.spellId", spell ~= nil) seen("aura.fromPlayer", fromP ~= nil)
                local dur, appl = clear(a.duration), clear(a.applications)
                seen("aura.duration", dur ~= nil) seen("aura.applications", appl ~= nil)
                s.added[#s.added + 1] = { iid = iid, spellId = spell, fromPlayer = fromP, helpful = helpful, duration = dur, applications = appl,
                    expirationTime = clear(a.expirationTime) }
            else seen("aura.added", false) end
        end
    elseif not isNil(added) then
        seen("aura.addedAuras", false)
        if code(added) == "S" then s.addedSecret = true end   -- secret list vs nil: a clear "something was added"
    end
    local rem = info.removedAuraInstanceIDs
    -- v2.2.4: in combat the removed list is a secret table but its PRESENCE is readable ("something was removed")
    if not isNil(rem) and code(rem) ~= "K" and code(rem) ~= "C" then s.removedSecret = true end
    -- v2.2.22 (audit): a "T" removed list (some IDs secret) is read per element; clear IDs are used, secret ones counted
    if type(rem) == "table" and code(rem) ~= "S" then
        local okL, nl = pcall(function() return #rem end)
        nl = okL and clear(nl) or nil
        if type(nl) == "number" then
            s.removedCount = nl
            for i = 1, math.min(nl, 32) do
                local okI, x = pcall(function() return rem[i] end)
                local iid = okI and clear(x) or nil
                seen("aura.removedID", iid ~= nil)
                if iid then s.removed[#s.removed + 1] = iid end
            end
        end
    end
    return s
end

-- v2.2.3: GetAuraSlots raises in combat for tainted code ("Auras cannot be accessed when secret"); a context with an
-- all-error result used to be skipped until the next restriction-state change / capture start, keyed by the probe
-- context only (enc/combat/restricted) with no environment, so a BG error could switch counts off for world/dungeon
-- combat until a restriction event. v2.2.25: ns.AuraGate - keyed by environment x combat x phase, held 30 s after
-- the access error, then re-sampled (one call), so counts come back wherever access is allowed.
local function counts(unit)
    local ua = g("C_UnitAuras")
    if type(ua) ~= "table" or type(ua.GetAuraSlots) ~= "function" then return nil end
    local AG = ns.AuraGate
    local fam = (unit:gsub("%d+$", "N"))
    local out = {}
    for _, filter in ipairs({ "HELPFUL|PLAYER", "HARMFUL|PLAYER" }) do
        local res
        if AG and AG.Call then
            local p = ns.Pack(AG.Call("GetAuraSlots", "inf:" .. fam, ua.GetAuraSlots, unit, filter))
            if p[1] then seen("aura.count", false) return nil end        -- held
            res = { n = p.n - 1 }
            for i = 2, p.n do res[i - 1] = p[i] end
        else
            res = ns.Pack(pcall(ua.GetAuraSlots, unit, filter))
        end
        local readable = res[1]
        for i = 2, res.n do if not clear(res[i]) and not isNil(res[i]) then readable = false end end
        seen("aura.count", readable and true or false)
        out[filter] = readable and math.max(res.n - 2, 0) or nil   -- returns: continuationToken, slot...
    end
    return out
end

local function onAura(rawUnit, info)
    local unit = ns.ClearStr(rawUnit)
    if not unit or not UNITS[unit] then return end
    if ns.Containers then ns.Containers.ObserveEvent("UNIT_AURA", unit, info) end
    local s = auraSummary(unit, info)
    local key = keyOf(unit)
    local c = counts(unit)
    signal({ e = "aura", unit = unit, guid = guidOf(unit), full = s and s.full or nil, add = s and s.addedCount or nil,
        rem = s and s.removedCount or nil, adds = s and #s.added > 0 and s.added or nil, rems = s and #s.removed > 0 and s.removed or nil,
        cH = c and c["HELPFUL|PLAYER"], cD = c and c["HARMFUL|PLAYER"] })
    if not I.hs then return end
    if s then I.hs:OnAura(key, s) end
    if c then
        for f, n in pairs(c) do I.hs:OnCount(key, f, n) end
    end
    -- learn while readable: my aura with clear spellId + duration -> knowledge (per build)
    dirty()
    if s and ns.Knowledge then
        local own = I.hs.ownRecent and I.hs.ownRecent[#I.hs.ownRecent]
        for _, a in ipairs(s.added) do
            -- v2.2.4: spell -> applied aura mapping (my cast X, then within 0.3 s my aura Y on its target or on me)
            if a.spellId and a.fromPlayer == true and own and own.spell and now() - own.t <= 0.3 and ns.Knowledge.LearnAuraMap
                and (unit == "player" or own.target == key) then
                ns.Knowledge.LearnAuraMap(own.spell, a.spellId, "live")
                local kk = I.hs.knowledge[own.spell]
                if kk and not kk.auraId then kk.auraId = a.spellId end
            end
            if a.spellId and a.fromPlayer == false and ns.Knowledge.Enqueue then ns.Knowledge.Enqueue(a.spellId) end
            if a.spellId and a.fromPlayer == true and type(a.duration) == "number" and a.duration >= 0 then
                -- duration 0 = until cancelled (Ghost Wolf, Lightning Shield charges): an aura without an expiry
                local dur = a.duration > 0 and a.duration or nil
                local facts = { auraDuration = dur, untilCancelled = (dur == nil) or nil, helpful = a.helpful, self = (unit == "player") or nil }
                -- v2.2.4 live verification: parsed tooltip duration vs the observed aura duration (knowledge field vs reality)
                local kdb = ns.Knowledge.DB and ns.Knowledge.DB()
                local ke = kdb and kdb.spells[a.spellId]
                local pd = ke and ke.data and ke.data.parsed and (ke.data.parsed.auraDuration or ke.data.parsed.imbueDuration)
                if pd and dur and I.hs.verdict then
                    I.hs:verdict("knowledge-aura", math.abs(pd - dur) <= 0.5 and "V" or "C",
                        { spell = a.spellId, src = "UNIT_AURA addedAuras.duration", conf = "high", d = dur - pd })
                end
                ns.Knowledge.Learn(a.spellId, facts)
                I.hs:Learn(a.spellId, { aura = { duration = dur, helpful = a.helpful, self = facts.self } })
            end
        end
    end
end

-- v2.2.4 (run 5): UNIT_COMBAT is clear on 1.60.1 in combat (action, flagText, amount, schoolMask); it fires for the
-- player and each token showing the unit (target, nameplateN, softenemy, targettarget): only player/target/focus are
-- used so one hit counts once. Attribution (mine vs other) is the HSM's (timing rules, no CLEU).
-- v2.2.6: world HSM — player/target/focus always; capture mode also party/raid/nameplate/pet/boss (dedupe by keyOf)
local UC_UNITS = { player = true, target = true, focus = true, pet = true }
local ucSig, ucSigN = {}, 0   -- v2.2.12: last UNIT_COMBAT payload per unit key (cross-token dedupe)
local function onUnitCombat(rawUnit, action, flag, amount, school)
    local unit = ns.ClearStr(rawUnit)
    if not unit then return end
    local allow = UC_UNITS[unit]
    if not allow and ns.ReplayLog and ns.ReplayLog.IsTest and ns.ReplayLog.IsTest() then
        -- capture: any token that looks like a unit family we care about
        if type(unit) == "string" and (unit:find("^party") or unit:find("^raid") or unit:find("^nameplate")
            or unit:find("^boss") or unit:find("^arena") or unit == "pet" or unit:find("target")) then
            allow = true
        end
    end
    if not allow then return end
    local act, amt, sch, fl = clear(action), clear(amount), clear(school), clear(flag)
    seen("unitCombat.action", act ~= nil) seen("unitCombat.amount", amt ~= nil) seen("unitCombat.school", sch ~= nil)
    if cfg().signals ~= false and cfg().combatSignals ~= false then
        signal({ e = "uc", unit = unit, act = act, amt = amt, sch = sch, crit = (fl == "CRITICAL") or nil })
    end
    if not I.hs then return end
    -- v2.2.12 (run 9): one hit fires UNIT_COMBAT once per token showing the unit (target + nameplateN + raidN ...; in a
    -- BG my own raidN too), and every copy was counted (live per-unit taken 1.4x the meter, own hits multiplied).
    -- Same unit (keyOf, my GUID -> "player"), same frame, same payload, different token = one hit.
    local key = keyOf(unit)
    if unit ~= "player" and key ~= nil and key == guidOf("player") then key = "player" end
    local tn = now()
    local sg = ucSig[key]
    -- a copy = same payload in the same frame from ANOTHER token (the same token twice = two real hits)
    if sg and sg.t == tn and sg.tok ~= unit and sg.act == act and sg.amt == amt and sg.fl == fl and sg.sch == sch then
        I.ucDup = (I.ucDup or 0) + 1
        return
    end
    if not sg then
        ucSigN = ucSigN + 1
        if ucSigN > 256 then ucSig, ucSigN = {}, 1 end
        sg = {}
        ucSig[key] = sg
    end
    if not (sg.t == tn and sg.act == act and sg.amt == amt and sg.fl == fl and sg.sch == sch) then sg.tok = unit end
    sg.t, sg.act, sg.amt, sg.fl, sg.sch = tn, act, amt, fl, sch
    -- v2.2.16 (run 13 dm-damage C's +224/+586/+627): melee/swing rules need the hit to be on MY target; v2.2.15 credited
    -- raid members' and nameplates' WOUNDs inside my cast/swing frame to me. nil = unknown (no target key): rule decides.
    if unit == "target" then I.hs.ucIsTarget = true
    else
        local tk = keyOf("target")
        if tk == nil or key == nil then I.hs.ucIsTarget = nil else I.hs.ucIsTarget = (tk == key) end
    end
    I.hs.ucFriendly = (unit:find("^raid") or unit:find("^party")) and true or nil   -- a group member's WOUND is never my damage
    local rec = I.hs:OnUnitCombat(key, act, fl, amt, sch, key == "player")
    I.hs.ucIsTarget, I.hs.ucFriendly = nil, nil
    -- v2.2.16 probe: my claimed damage per token family (target / nameplate / raid / focus ...) per fight, so a dm-damage
    -- contradiction can be traced to the token that over-claimed (counts and amounts only)
    if rec and rec.src == "mine" and act ~= "HEAL" and type(amt) == "number" then
        local f = I.hs.Fight and I.hs:Fight()
        if f and f.dmg then
            local fam = (unit == "target" and "target") or unit:match("^(%a+)") or "other"
            f.dmg.tok = f.dmg.tok or {}
            f.dmg.tok[fam] = (f.dmg.tok[fam] or 0) + amt
        end
    end
    if rec then dirty() end
end

local function onInterrupted(rawUnit)
    local unit = ns.ClearStr(rawUnit)
    if unit ~= "target" and unit ~= "focus" then return end
    local uca = g("UnitCanAttack")
    local okA, ca = pcall(uca or function() return nil end, "player", unit)
    if not (okA and isTrue(ca)) then return end
    if I.hs and I.hs.OnInterrupt then
        local rec = I.hs:OnInterrupt(keyOf(unit))
        if rec then signal({ e = "interrupt", unit = unit, src = rec.src, rule = rec.rule, sid = rec.spell }) dirty() end
    end
end

local frame, ticker
local CAST_EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_FAILED_QUIET", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_EMPOWER_STOP" }
I.CAST_EVENTS = CAST_EVENTS
function I.OnEvent(event, ...)
    if event == "UNIT_AURA" then onAura(...)
    elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
        if ns.InvalidateEnv then ns.InvalidateEnv() end
        if ns.CombatProbe and ns.CombatProbe.InvalidateContext then ns.CombatProbe.InvalidateContext() end
        dirty()
        local rt, st = ...
        if I.hs then I.hs:SetRestriction(clear(rt), clear(st)) end
        signal({ e = "restriction", rtype = clear(rt), state = clear(st) })
    elseif event == "UNIT_COMBAT" then onUnitCombat(...)
    elseif event == "PLAYER_SWING" then if I.hs and I.hs.OnSwing then I.hs:OnSwing() end
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then

        if event == "PLAYER_REGEN_DISABLED" then I.combatSeq = (I.combatSeq or 0) + 1 end
        if I.hs and I.hs.OnCombatState then I.hs:OnCombatState(event == "PLAYER_REGEN_DISABLED") end
        if ns.CombatProbe and ns.CombatProbe.InvalidateContext then ns.CombatProbe.InvalidateContext() end
        dirty()
        signal({ e = event == "PLAYER_REGEN_DISABLED" and "combat" or "ooc" })
    elseif event == "PLAYER_TARGET_CHANGED" then signal({ e = "target", guid = guidOf("target") }) dirty()
    elseif event == "PLAYER_TOTEM_UPDATE" then onTotem(...)
    elseif event == "UNIT_HEALTH" then
        local u = ns.ClearStr((...))
        if I.hs and I.hs.OnHealthEvent then
            if u == "player" then I.hs:OnHealthEvent("player")
            elseif type(u) == "string" and (I.hs.candidates or (ns.ReplayLog and ns.ReplayLog.IsTest and ns.ReplayLog.IsTest())) then
                local k = keyOf(u)
                I.hs:OnHealthEvent(k)
                -- v2.2.16 lab: c-hp-net scored against the clear health when this unit's health is readable
                if I.hs.candidates and k ~= nil and I.hs.CandHealthActual then
                    local fh, fm = g("UnitHealth"), g("UnitHealthMax")
                    local okH, hv = pcall(fh or error, u)
                    local okM, mv = pcall(fm or error, u)
                    local cur = okH and ns.ClearNum(hv) or nil
                    local mx = okM and ns.ClearNum(mv) or nil
                    if cur and mx then I.hs:CandHealthActual(k, cur, mx) end
                end
            end
        end
    elseif event == "UNIT_MAXHEALTH" then
        local u = ns.ClearStr((...))
        if u == "player" then I.ReadMaxHealth()
        elseif I.hs and I.hs.OnHealthMax and type(u) == "string" then
            local f = g("UnitHealthMax")
            if type(f) == "function" then
                local ok, v = pcall(f, u)
                local mx = ok and ns.ClearNum(v) or nil
                if mx then I.hs:OnHealthMax(keyOf(u), mx) end
            end
        end
    elseif event == "SPELL_UPDATE_COOLDOWN" then I.OnSpellUpdateCooldown(...)
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then I.SyncGroupSize() pcall(I.Census, true)
    else
        onCast(event, ...)
        if event == "UNIT_SPELLCAST_INTERRUPTED" then onInterrupted(...) end
    end
end

-- v2.2.4 CooldownTracker feed (HybridState MINOR 5). SPELL_UPDATE_COOLDOWN is event-driven (no OnUpdate):
--  (b) its payload (spellID, baseSpellID, category, startRecoveryCategory, itemID) is classified per context (codes only)
--      and fed to the tracker when clear (run 5: clear in combat; shocks share category 19, GCD spells srCategory 133);
--  (c) only the k spells currently cooling (+ the GCD spell) are re-read with C_Spell.GetSpellCooldown: isActive /
--      isOnGCD / isEnabled are NeverSecret; startTime / duration are used ONLY when clear (out of combat: calibration);
--  (f) known-answer probe: the first read in each combat asserts isActive and isOnGCD are still clear (verdict
--      "cd-fields-clear"; a flip is an unexpected finding).
local CD_PAYLOAD = { "spellID", "baseSpellID", "category", "startRecoveryCategory", "itemID" }
local CD_FIELDS = { "isActive", "isOnGCD", "isEnabled", "startTime", "duration", "modRate" }
local cdProbeCombat, gcd61304 = nil, nil
local function clearCode(c) return c == "C" or c == "K" end
local cdPayloadCache = {}   -- ctx -> per-field count tables (re-bound when the SV table changes)
local function cdCount(d, key, ctx, field, c)
    local t = d[key] or {}
    d[key] = t
    local x = t[ctx] or {}
    t[ctx] = x
    local f = x[field] or {}
    x[field] = f
    f[c] = (f[c] or 0) + 1
end

local function cdFieldsOf(t) return t.isActive, t.isOnGCD, t.startTime, t.duration end
local CD_BUDGET = 4   -- far-from-ready cooling spells re-checked per event (round-robin); due ones always (perf gate: storm <= 0.5%)
local function readCooldown(f, id, inCombat, ctx, d)
    local ok, t = pcall(f, id)
    if not ok or type(t) ~= "table" then return end
    local okF, ia, ig, st, du = pcall(cdFieldsOf, t)
    if not okF then return end
    local cia, cig, cst, cdu = code(ia), code(ig), code(st), code(du)
    if not d.cdFieldsSeen or not d.cdFieldsSeen[ctx] then   -- full field codes once per context (cheap bookkeeping)
        d.cdFieldsSeen = d.cdFieldsSeen or {}
        d.cdFieldsSeen[ctx] = true
        for _, fl in ipairs(CD_FIELDS) do
            local okV, v = pcall(function() return t[fl] end)
            cdCount(d, "cdFields", ctx, fl, okV and code(v) or "E")
        end
    end
    if inCombat and cdProbeCombat ~= I.combatSeq then      -- known-answer probe, once per combat
        cdProbeCombat = I.combatSeq
        local good = cia == "C" and cig == "C"
        I.hs:verdict("cd-fields-clear", good and "V" or "C", { spell = id, src = "C_Spell.GetSpellCooldown", conf = "high",
            d = good and 0 or 1 })
        if not good and ns.Verify and ns.Verify.Unexpected then
            ns.Verify.Unexpected("secrecy-flip", "C_Spell.GetSpellCooldown.isActive/isOnGCD", cia .. "/" .. cig)
        end
    end
    -- v2.2.7: was `(cia == "C") and ia or nil` (a truth test on ia that also turned a clear false into nil)
    ia, ig = ns.ClearWithCode(ia, cia, "boolean"), ns.ClearWithCode(ig, cig, "boolean")
    local rem, dur
    local cs, cd = ns.ClearWithCode(st, cst, "number"), ns.ClearWithCode(du, cdu, "number")   -- v2.2.7: cleared copies only
    if cs and cd and cd > 0 then
        rem, dur = cs + cd - now(), cd
    end
    I.hs:CDObserve(id, ia, ig, rem, dur)
    -- replay input only on a change of the clear flags (or a clear calibration): no per-event flood into the signal ring
    local c = I.hs.cd.spells[id]
    local key = (ia == nil and "n" or ia and "a" or "r") .. (ig == nil and "n" or ig and "g" or "-")
    if rem or not c or c.lastObsKey ~= key then
        if c then c.lastObsKey = key end
        signal({ e = "cdobs", id = id, a = ia, g = ig, r = rem and math.floor(rem * 1000 + 0.5) / 1000 or nil, du = dur })
    end
end

-- re-read the due / GCD / round-robin cooling spells (from SPELL_UPDATE_COOLDOWN or the v2.2.12 due-time timer)
local function cdRecheck(hs, d, ctx)
    local cs = g("C_Spell")
    local f = type(cs) == "table" and cs.GetSpellCooldown
    if type(f) ~= "function" then return end
    -- several SPELL_UPDATE_COOLDOWN events in one frame (a cast fires one per category member) -> one O(k) re-check
    local tnow = now()
    if I.cdCheckedAt == tnow then dirty() return end
    I.cdCheckedAt = tnow
    local inCombat = ns.InCombat()
    -- O(due + budget), independent of the number of cooling spells: due within 2 s (min-heap), the GCD spell, and
    -- CD_BUDGET far-from-ready spells round-robin (perf gate: SPELL_UPDATE_COOLDOWN storm with 50+ spells cooling)
    local ids = hs.CDCheckList and hs:CDCheckList(2, CD_BUDGET) or hs:CDActive()
    for i = 1, #ids do readCooldown(f, ids[i], inCombat, ctx, d) end
    I.ScheduleCDSample()
    -- GCD spell 61304 (whitelisted on retail): absent on 1.60.1 (run 5: nil in and out of combat) -> tried once, then off
    if gcd61304 ~= false and hs.cd.gcd then
        local ok, t = pcall(f, 61304)
        if not ok or type(t) ~= "table" then gcd61304 = false
        else
            local okF, st, du = pcall(function() return t.startTime, t.duration end)
            local gs, gd = nil, nil
            if okF then gs, gd = ns.ClearNum(st), ns.ClearNum(du) end
            if gs and gd and gd > 0 then
                gcd61304 = true
                hs:GCDObserve(gs + gd - now(), gd)
            end
        end
    end
    dirty()
end

-- v2.2.12: one pending C_Timer at the earliest predicted ready time (+ a probe at end + tolerance) re-runs the due
-- re-check, so "ready" is sampled near the predicted end instead of at the next unrelated SPELL_UPDATE_COOLDOWN
-- (run 9: 14 of 23 contradicted cd-ready verdicts were 0.3-2 s observation latency). At most one timer is pending
-- unless an earlier ready time appears; a stale timer just re-checks (cheap: O(due + budget)).
local cdTimerAt = nil
function I.ScheduleCDSample()
    local hs = I.hs
    local ct = g("C_Timer")
    if not (hs and hs.CDNextSampleAt and type(ct) == "table" and type(ct.After) == "function") then return end
    local tn = now()
    local t = hs:CDNextSampleAt(tn)
    if not t then return end
    if cdTimerAt and cdTimerAt > tn and cdTimerAt <= t + 0.01 then return end
    cdTimerAt = t
    ct.After(math.max(0, t - tn), function()
        if cdTimerAt == t then cdTimerAt = nil end
        if not (I.hs and I.running and I.hs.CDPayload) then return end
        if ns.Perf then ns.Perf.Run("HSM.CDDue", cdRecheck, I.hs, db(), ctxName())
        else pcall(cdRecheck, I.hs, db(), ctxName()) end
    end)
end

-- v2.2.12: group size for the dm-frame rule (DAMAGE_METER updates fire for every group member's damage/heal).
-- Clear GetNumGroupMembers() via ReplayLog.GroupInfo (classified before use); unknown keeps the last value.
function I.SyncGroupSize()
    if not (I.hs and I.hs.SetGroupSize and ns.ReplayLog and ns.ReplayLog.GroupInfo) then return end
    local _, size = ns.ReplayLog.GroupInfo()
    if type(size) == "number" then I.hs:SetGroupSize(size) end
end

function I.OnSpellUpdateCooldown(...)
    local hs = I.hs
    if not (hs and hs.CDPayload) then return end
    local d = db()
    local ctx = ctxName()
    -- payload codes: per-context field tables cached (5 increments, no table walk from the SV root per field)
    local pc = cdPayloadCache[ctx]
    if not pc or pc.d ~= d then
        local t = d.cdPayload or {}
        d.cdPayload = t
        local x = t[ctx] or {}
        t[ctx] = x
        pc = { d = d }
        for i = 1, #CD_PAYLOAD do local fl = CD_PAYLOAD[i] x[fl] = x[fl] or {} pc[i] = x[fl] end
        cdPayloadCache[ctx] = pc
    end
    local v1, v2, v3, v4, v5 = ...
    local c1, c2, c3, c4, c5 = code(v1), code(v2), code(v3), code(v4), code(v5)   -- classified once, reused below
    local f1, f2, f3, f4, f5 = pc[1], pc[2], pc[3], pc[4], pc[5]
    f1[c1] = (f1[c1] or 0) + 1 f2[c2] = (f2[c2] or 0) + 1 f3[c3] = (f3[c3] or 0) + 1
    f4[c4] = (f4[c4] or 0) + 1 f5[c5] = (f5[c5] or 0) + 1
    -- payload values are touched only when their code says clear (no boolean test on a possibly secret value)
    local sid, base, cat, src
    if clearCode(c1) then sid = v1 end
    if clearCode(c2) then base = v2 end
    if clearCode(c3) then cat = v3 end
    if clearCode(c4) then src = v4 end
    if type(sid) == "number" then
        local c = hs.cd.spells[sid]
        local catKey = cat
        if cat == 0 then catKey = nil end
        if not c or c.category ~= catKey or c.srCategory ~= src then
            signal({ e = "cdp", id = sid, cat = cat, src = src })   -- payload changes only (replay input)
            if ns.ReplayLog and ns.ReplayLog.IsTest() then
                ns.ReplayLog.OnApiSample("cdp", sid, { c1, c2, c3, c4 }, { sid, cat, src })
            end
        end
        hs:CDPayload(sid, base, cat, src)
    end
    cdRecheck(hs, d, ctx)
end

-- v2.2.4: UnitHealthMax(player) is clear (UnitHealth is not): health-estimate ceiling + ledger
function I.ReadMaxHealth()
    local f = g("UnitHealthMax")
    if not (I.hs and type(f) == "function") then return nil end
    local ok, v = pcall(f, "player")
    local mx = ok and clear(v)
    if type(mx) ~= "number" then return nil end
    if I.hs.OnHealthMax then I.hs:OnHealthMax("player", mx) end
    if I.hs.ledger then
        local pg = guidOf("player")
        if pg then I.hs.ledger:Put("guid", pg, { hpMax = mx }, "UNIT_MAXHEALTH") end
    end
    signal({ e = "hpmax", unit = "player", v = mx })
    return mx
end

function I.Start()
    if cfg().enabled == false then return false end
    local d = db()
    -- v2.2.2: the previous capture session moves to d.history (newest last, keepSessions=4) instead of being
    -- overwritten (run 3 lost the earlier Flame Shock predictions); the top level stays the latest session
    if d.sid and (d.predictions or d.signals) then
        d.history = type(d.history) == "table" and d.history or {}
        local snap = {}
        for k, v in pairs(d) do if k ~= "v" and k ~= "history" then snap[k] = v end end
        table.insert(d.history, snap)
        local keep = tonumber(cfg().keepSessions) or 4
        while #d.history > keep do table.remove(d.history, 1) end
    end
    for k in pairs(d) do if k ~= "v" and k ~= "history" then d[k] = nil end end
    d.sid = ns.SessionId()
    d.anchor = ns.TimeAnchor()
    d.ctx0 = ctxName()
    d.player = { guid = guidOf("player") }
    if ns.Knowledge then
        local kdb = ns.Knowledge.DB()
        d.player.info = kdb and kdb.player
        d.appliers = ns.Knowledge.Appliers()
    end
    I.health = { state = "starting", failed = {} }
    I.hs = I.NewHSM()
    if not I.hs then
        I.running = false
        I.MarkDown("start", "HybridState not created")
        return false
    end
    if I.hs and ns.ReplayLog then
        I.hs.onInfer = function(rec) ns.ReplayLog.OnInfer(rec) end
        local prevV = I.hs.onVerdict
        I.hs.onVerdict = function(rec)
            if prevV then pcall(prevV, rec) end
            ns.ReplayLog.OnVerdict(rec)
        end
    end
    I.unreadable = 0
    tried = {}

    if ns.Knowledge then
        ns.Knowledge.onCollected = function(id) if I.hs and I.running then learnFromKnowledge(I.hs, id) end end
    end
    if not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", function(_, event, ...)
            local ok, err
            if ns.Perf then ok, err = ns.Perf.Run(ns.Perf.Key("Inference", event), I.OnEvent, event, ...)
            else ok, err = pcall(I.OnEvent, event, ...) end
            if not ok then ns.NoteSelfError("Inference." .. event, err) end
        end)
    end
    for _, ev in ipairs(CAST_EVENTS) do pcall(frame.RegisterEvent, frame, ev) end
    for _, ev in ipairs({ "UNIT_AURA", "ADDON_RESTRICTION_STATE_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED",
        "PLAYER_TOTEM_UPDATE", "PLAYER_SWING", "SPELL_UPDATE_COOLDOWN", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do
        pcall(frame.RegisterEvent, frame, ev)
    end
    -- v2.2.6: UNIT_COMBAT for player/target/focus (+ capture: party/boss/nameplates via RegisterEvent fallback)
    if not pcall(frame.RegisterUnitEvent, frame, "UNIT_COMBAT", "player", "target", "focus", "pet") then
        pcall(frame.RegisterEvent, frame, "UNIT_COMBAT")
    elseif ns.ReplayLog and ns.ReplayLog.IsTest and ns.ReplayLog.IsTest() then
        -- RegisterEvent gets all tokens; UC filter keeps cost bounded. Prefer this in capture for world coverage.
        pcall(frame.UnregisterEvent, frame, "UNIT_COMBAT")
        pcall(frame.RegisterEvent, frame, "UNIT_COMBAT")
    end
    -- v2.2.6: health events — player always (running estimate); capture registers broadly for WorldCapture/HSM feed
    for _, ev in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH" }) do
        if ns.ReplayLog and ns.ReplayLog.IsTest and ns.ReplayLog.IsTest() then
            pcall(frame.RegisterEvent, frame, ev)
        elseif not pcall(frame.RegisterUnitEvent, frame, ev, "player", "target", "focus") then
            pcall(frame.RegisterEvent, frame, ev)
        end
    end
    I.ReadMaxHealth()
    cdProbeCombat, gcd61304 = nil, nil
    I.combatSeq = ns.InCombat() and 1 or 0
    I.running = true
    I.SyncGroupSize()
    censusEnemy, censusLast, censusT = {}, nil, 0
    meterEnemy.n, meterEnemy.t = 0, nil
    pcall(I.Census, true)
    I.health.state = next(I.health.failed) and "degraded" or "up"
    I.WarnHealth()
    if ns.InCombat() and I.hs.OnCombatState then I.hs:OnCombatState(true) end
    if type(g("C_Timer")) == "table" and C_Timer.NewTicker then
        ticker = C_Timer.NewTicker(1, function()
            if not I.hs then return end
            if ns.Perf then ns.Perf.Run("HSM.Tick", I.hs.Tick, I.hs) else pcall(I.hs.Tick, I.hs) end
            if ns.Perf then ns.Perf.Run("HSM.Census", I.Census) else pcall(I.Census) end
        end)
    end
    if ns.Perf then
        local cap = I.hs and I.hs.maxLog ~= math.huge and math.floor(I.hs.maxLog * 1.25) or nil   -- push(): max + max/4 slack (lab: none)
        ns.Perf.Size("hsm.predictions", function() return I.hs and #I.hs.predictions or 0 end, cap)
        ns.Perf.Size("hsm.inferences", function() return I.hs and #I.hs.inferences or 0 end, cap)
        ns.Perf.Size("hsm.units", function() local n = 0 for _ in pairs((I.hs and I.hs.units) or {}) do n = n + 1 end return n end)
        for kind, capN in pairs(I.hs.ledger and I.hs.ledger.caps or {}) do
            ns.Perf.Size("ledger." .. kind, function() return I.hs and I.hs.ledger and I.hs.ledger:Count(kind) or 0 end,
                capN + math.max(8, math.floor(capN / 4)))
        end
        ns.Perf.Size("inference.signals", function() local dd = db() return dd and dd.signals and #dd.signals or 0 end,
            tonumber(cfg().maxSignals) or 3000)
    end
    return true
end

function I.Stop()
    I.running = false
    if I.health.state == "up" or I.health.state == "degraded" then I.health.stopped = true end
    if frame then pcall(frame.UnregisterAllEvents, frame) end
    if ticker and ticker.Cancel then ticker:Cancel() end
    ticker = nil
    local d = db()
    if not (d and I.hs) then return nil end
    local ex = I.hs:Export()
    d.predictions, d.inferences, d.contradictions, d.counters = ex.predictions, ex.inferences, ex.contradictions, ex.counters
    d.knowledgeSpells = ex.knowledgeSpells
    d.fights = ex.fights
    d.casts, d.castModel = ex.casts, ex.castModel   -- enemy cast timing (npc ids, durations; no names/GUIDs)
    d.ledger = ex.ledger            -- counts + resolution stats only (identities stay in memory)
    d.cd = ex.cd                    -- CooldownTracker: learned cooldown/GCD per spellID, readies, GCD windows (numbers only)
    d.cand = { stats = ex.candStats, cost = ex.candCost, on = I.hs.candidates or nil }   -- v2.2.15 lab: shadow rules
    -- v2.2.16 attribution safety: per-rule gate outcomes, last census (counts), learned self links (spellID numbers)
    d.attr = { stats = I.hs.attrStats, census = I.hs.census, selfLink = I.hs.selfLink }
    pcall(I.SaveSelfLink, I.hs)
    d.appliersHSM = { helpful = I.hs:Appliers(true), harmful = I.hs:Appliers(false) }
    return ex.counters
end

-- knowledge pass at ON (out of combat, full data) and in the first combat (classification only)
local function startKnowledge()
    if ns.Knowledge and (ns.config.knowledge == nil or ns.config.knowledge.enabled ~= false) then pcall(ns.Knowledge.Run, "capture:on") end
end
local kCombatSid
ns.On("PLAYER_REGEN_DISABLED", function()
    if not capturing() or not ns.Knowledge then return end
    local sid = ns.db.logs.session.sid
    if kCombatSid == sid then return end
    kCombatSid = sid
    if type(g("C_Timer")) == "table" then C_Timer.After(2, function() pcall(ns.Knowledge.Run, "combat") end) end
end)

ns.captureModules = ns.captureModules or {}
ns.captureModules[#ns.captureModules + 1] = { name = "spell knowledge + HSM inference",
    start = function()
        startKnowledge()
        local res   -- I.Start's own result, assigned inside the closure (only the error string leaves pcall)
        local ok, err = pcall(function() res = I.Start() end)
        if not ok then
            I.running = false
            I.MarkDown("start", err)
            error(err, 0)   -- still reported as capture:<module> (engine_health lead)
        end
        if res == false and cfg().enabled ~= false and I.health.state ~= "down" then I.MarkDown("start", "I.Start returned false") end
        return res
    end,
    stop = function()
        local c = I.Stop()
        return c and string.format("HSM %d prediction(s), %d inference(s), %d live contradiction(s)", c.predictions, c.inferences, c.contradictions)
    end }
