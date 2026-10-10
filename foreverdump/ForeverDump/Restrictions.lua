-- ForeverDump v2.2 - restrictions tracker + diagnostics self-check.
--
-- Restrictions (C_RestrictedActions, RestrictedActionsDocumentation.lua / RestrictedActionsConstantsDocumentation.lua):
--   event ADDON_RESTRICTION_STATE_CHANGED(type: Enum.AddOnRestrictionType, state: Enum.AddOnRestrictionState)
--   C_RestrictedActions.GetAddOnRestrictionState(type) -> state
--   types  0 Combat, 1 Encounter, 2 ChallengeMode, 3 PvPMatch, 4 Map, 5 Chat
--   states 0 Inactive, 1 Activating (during dispatch of the event; NOT enforced until dispatch completes), 2 Active
-- Every flip is logged into ForeverDumpLogDB.restrictions.flips with the common timebase (ns.Stamp: sid + GetTime +
-- epoch + GetServerTime), the trigger context (InCombatLockdown, UnitAffectingCombat, current encounter, instance
-- type/difficulty/map, challenge mode / PvP match flags, the last context marker) and all six restriction states.
-- While a capture (FD_Logs) is ON each flip also re-runs a small, harmless probe set twice: at the event (state
-- "Activating" is not enforced yet) and on the next frame (enforced), so the converter can name the APIs/fields that
-- turn secret or start erroring ("forbidden") at that flip. Context markers (PLAYER_REGEN_*, ENCOUNTER_*,
-- CHALLENGE_MODE_*, PVP_MATCH_*, zone changes) are logged too, so xref can put flips on the per-fight timeline.
-- Nothing here hooks, replaces or calls protected code; all calls are pcall-wrapped getters; secret values are
-- only tested with issecretvalue/canaccessvalue, never compared, concatenated or stored.
local _, ns = ...
local R = {}
ns.Restrictions = R

local TYPE_NAMES = { [0] = "Combat", [1] = "Encounter", [2] = "ChallengeMode", [3] = "PvPMatch", [4] = "Map", [5] = "Chat" }
local STATE_NAMES = { [0] = "Inactive", [1] = "Activating", [2] = "Active" }
R.TYPE_NAMES, R.STATE_NAMES = TYPE_NAMES, STATE_NAMES

local CONTEXT_EVENTS = {
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_IN_COMBAT_CHANGED", "ENCOUNTER_START", "ENCOUNTER_END",
    "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET",
    "PVP_MATCH_ACTIVE", "PVP_MATCH_COMPLETE", "PVP_MATCH_INACTIVE",
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
}

local function cfg() return (ns.config and ns.config.restrictions) or {} end
local function db()
    local log = ForeverDumpLogDB
    if type(log) ~= "table" then return nil end
    local r = log.restrictions
    if type(r) ~= "table" or r.flips == nil then
        r = type(r) == "table" and r or {}
        r.flips = r.flips or {}
        r.markers = r.markers or {}
        r.counts = r.counts or {}
        log.restrictions = r
    end
    return r
end
local function capturing() return ns.db and ns.db.logs and ns.db.logs.on and ns.db.logs.session ~= nil end
local function isSecret(v) return ns.IsSecret(v) end
local function g(name) return rawget(_G, name) end

local encounter -- { id, name, difficulty, size, start }

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local r = ns.Pack(pcall(fn, ...))
    if not r[1] then return nil end
    return unpack(r, 2, r.n)
end
local function clear(v) if isSecret(v) then return "<secret>" end return v end

function R.States()
    local cra = g("C_RestrictedActions")
    local get = type(cra) == "table" and cra.GetAddOnRestrictionState
    if type(get) ~= "function" then return nil end
    local out = {}
    for t = 0, 5 do
        local ok, st = pcall(get, t)
        if ok and not isSecret(st) then out[TYPE_NAMES[t]] = st end
    end
    return out
end

local FORCED_CVARS = { "addonCombatRestrictionsForced", "addonEncounterRestrictionsForced", "addonChallengeModeRestrictionsForced",
    "addonPvPMatchRestrictionsForced", "addonMapRestrictionsForced", "addonChatRestrictionsForced" }
local function cvar(name)
    local get = (g("C_CVar") and C_CVar.GetCVar) or g("GetCVar")
    if type(get) ~= "function" then return nil end
    local ok, v = pcall(get, name)
    if ok and not isSecret(v) then return v end
end
local function bool(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok and type(v) == "boolean" and not isSecret(v) then return v end
    return nil
end

-- context vector logged with every probe batch (flip at-event / next frame, markers, controls, forced sweep)
function R.Vector()
    local v = { states = R.States(), combat = ns.InCombat() or false }
    local cra = g("C_RestrictedActions")
    if type(cra) == "table" and type(cra.IsAddOnRestrictionActive) == "function" then
        v.active = {}
        for t = 0, 5 do v.active[TYPE_NAMES[t]] = bool(cra.IsAddOnRestrictionActive, t) end
    end
    v.affecting = bool(g("UnitAffectingCombat"), "player")
    v.encounterInProgress = bool(g("IsEncounterInProgress"))
    local cm = g("C_ChallengeMode")
    v.challengeMode = type(cm) == "table" and bool(cm.IsChallengeModeActive) or nil
    local pvp = g("C_PvP")
    v.activeBattlefield = type(pvp) == "table" and bool(pvp.IsActiveBattlefield) or nil
    local ii = g("IsInInstance")
    if type(ii) == "function" then
        local ok, inside, itype = pcall(ii)
        if ok then v.inInstance = (not isSecret(inside)) and inside or nil v.instanceType = (not isSecret(itype)) and itype or nil end
    end
    local map = g("C_Map")
    if type(map) == "table" and type(map.GetBestMapForUnit) == "function" then
        local ok, id = pcall(map.GetBestMapForUnit, "player")
        if ok and not isSecret(id) then v.mapID = id end
    end
    local sec = g("C_Secrets")
    if type(sec) == "table" then
        v.hasSecretRestrictions = bool(sec.HasSecretRestrictions)
        v.should = { auras = bool(sec.ShouldAurasBeSecret), cooldowns = bool(sec.ShouldCooldownsBeSecret),
            unitStats = bool(sec.ShouldUnitStatsBeSecret), identityTarget = bool(sec.ShouldUnitIdentityBeSecret, "target"),
            healthMaxTarget = bool(sec.ShouldUnitHealthMaxBeSecret, "target"), powerPlayer = bool(sec.ShouldUnitPowerBeSecret, "player") }
    end
    local cl = g("C_CombatLog")
    v.combatLogRestricted = type(cl) == "table" and bool(cl.IsCombatLogRestricted) or nil
    local chat = g("C_ChatInfo")
    v.addonChatRestricted = type(chat) == "table" and bool(chat.AreOutgoingAddonChatMessagesRestricted) or nil
    v.forced = {}
    for _, n in ipairs(FORCED_CVARS) do v.forced[n] = cvar(n) end
    v.taintLog, v.taintLogObjectSecrets = cvar("taintLog"), cvar("taintLogObjectSecrets")
    return v
end

-- the two always-on restrictions that are not AddOnRestrictionTypes: log every change of their value
local function trackAlwaysOn(v, why)
    local r = db()
    if not r or not v then return end
    r.alwaysOn = r.alwaysOn or {}
    for _, k in ipairs({ "combatLogRestricted", "addonChatRestricted" }) do
        local a = r.alwaysOn[k] or { changes = {} }
        r.alwaysOn[k] = a
        if v[k] ~= nil and a.value ~= v[k] then
            if #a.changes < 100 then a.changes[#a.changes + 1] = ns.Stamp({ from = a.value, to = v[k], why = why }) end
            a.value = v[k]
        end
        a.samples = (a.samples or 0) + 1
    end
end
R.TrackAlwaysOn = trackAlwaysOn

function R.Context()
    local c = { combat = ns.InCombat() or nil }
    local uac = g("UnitAffectingCombat")
    local a = call(uac, "player")
    if a ~= nil and not isSecret(a) then c.affecting = a and true or nil end
    local name, itype, diff, diffName, maxPlayers, _, _, mapID = call(g("GetInstanceInfo"))
    c.instance = { name = clear(name), type = clear(itype), difficulty = clear(diff), difficultyName = clear(diffName),
        maxPlayers = clear(maxPlayers), mapID = clear(mapID) }
    c.zone = clear(call(g("GetRealZoneText")))
    local cm = g("C_ChallengeMode")
    if type(cm) == "table" then
        local active = call(cm.IsChallengeModeActive)
        if active ~= nil and not isSecret(active) then c.challengeMode = active or nil end
    end
    local pvp = g("C_PvP")
    if type(pvp) == "table" then
        local st = call(pvp.GetActiveMatchState)
        if st ~= nil and not isSecret(st) then c.pvpMatchState = st end
    end
    if encounter then c.encounter = { id = encounter.id, name = encounter.name, difficulty = encounter.difficulty } end
    local r = db()
    local m = r and r.markers[#r.markers]
    if m then c.lastMarker = m.event c.lastMarkerAgo = m.t and GetTime and (GetTime() - m.t) or nil end
    return c
end

----------------------------------------------------------------------------
-- flip probe set: small, harmless getters on player/target. Per entry: status per return position.
-- "S" secret, "C" clear (value present, accessible), "N" nil, "X" inaccessible (canaccessvalue false), "E" error
----------------------------------------------------------------------------
local AURA_FIELDS = { "spellId", "name", "icon", "applications", "duration", "expirationTime", "sourceUnit", "auraInstanceID" }
local CD_FIELDS = { "startTime", "duration", "isEnabled", "modRate" }
local PROBES = {
    { "UnitHealth", function() return call(g("UnitHealth"), "player") end, "player" },
    { "UnitHealthMax", function() return call(g("UnitHealthMax"), "player") end, "player" },
    { "UnitPower", function() return call(g("UnitPower"), "player") end, "player" },
    { "UnitHealth(target)", function() return call(g("UnitHealth"), "target") end, "target" },
    { "UnitGUID(target)", function() return call(g("UnitGUID"), "target") end, "target" },
    { "UnitName(target)", function() return call(g("UnitName"), "target") end, "target" },
    { "GetRaidTargetIndex(target)", function() return call(g("GetRaidTargetIndex"), "target") end, "target" },
    { "UnitThreatSituation", function() return call(g("UnitThreatSituation"), "player", "target") end, "target" },
    { "GetUnitChargedPowerPoints", function() return call(g("GetUnitChargedPowerPoints"), "player") end, "player" },
}
local FIELD_PROBES = {
    { "C_Spell.GetSpellCooldown(6603)", function()
        local cs = g("C_Spell")
        return type(cs) == "table" and type(cs.GetSpellCooldown) == "function" and pcall(cs.GetSpellCooldown, 6603) end, CD_FIELDS },
    { "C_UnitAuras.GetAuraDataByIndex(player,1)", function()
        local ua = g("C_UnitAuras")
        return type(ua) == "table" and type(ua.GetAuraDataByIndex) == "function" and pcall(ua.GetAuraDataByIndex, "player", 1, "HELPFUL") end,
        AURA_FIELDS },
    { "C_UnitAuras.GetAuraDataByIndex(target,1)", function()
        local ua = g("C_UnitAuras")
        return type(ua) == "table" and type(ua.GetAuraDataByIndex) == "function" and pcall(ua.GetAuraDataByIndex, "target", 1, "HARMFUL") end,
        AURA_FIELDS },
}
local PREDICATES = { "ShouldAurasBeSecret", "ShouldCooldownsBeSecret", "ShouldSpellCooldownBeSecret", "ShouldUnitHealthMaxBeSecret",
    "ShouldUnitPowerBeSecret", "ShouldUnitComparisonBeSecret", "ShouldUnitIdentityBeSecret", "ShouldSpellAuraBeSecret" }
R.PROBES, R.FIELD_PROBES = PROBES, FIELD_PROBES

local function status(v, present)
    if isSecret(v) then return "S" end
    if not present then return "N" end
    local can = g("canaccessvalue")
    if type(can) == "function" then
        local ok, acc = pcall(can, v)
        if ok and acc == false then return "X" end
    end
    return "C"
end

function R.Probe()
    local out = {}
    local hasTarget = call(g("UnitExists"), "target")
    if isSecret(hasTarget) then hasTarget = true end
    for _, p in ipairs(PROBES) do
        if p[3] ~= "target" or hasTarget then
            local res = ns.Pack(pcall(p[2]))
            local codes = {}
            if not res[1] then codes[1] = "E"
            else
                local n = math.max(res.n - 1, 1)
                for i = 1, math.min(n, 6) do codes[i] = status(res[i + 1], res[i + 1] ~= nil) end
            end
            out[p[1]] = table.concat(codes)
        end
    end
    for _, p in ipairs(FIELD_PROBES) do
        local res = ns.Pack(pcall(p[2]))
        -- p[2] returns (pcallOk, value) or false
        if res[1] and res[2] == true and type(res[3]) == "table" and not isSecret(res[3]) then
            local codes = {}
            for _, f in ipairs(p[3]) do
                local okF, v = pcall(function() return res[3][f] end)
                codes[#codes + 1] = f .. "=" .. (okF and status(v, v ~= nil) or "E")
            end
            out[p[1]] = table.concat(codes, " ")
        elseif res[1] and res[2] == false then
            out[p[1]] = "E:" .. tostring(ns.Clean(res[3], { maxString = 120 }))
        elseif res[1] and res[2] == true then
            out[p[1]] = res[3] == nil and "N" or (isSecret(res[3]) and "S" or "C")
        end
    end
    local sec = g("C_Secrets")
    if type(sec) == "table" then
        local pr = {}
        for _, name in ipairs(PREDICATES) do
            local fn = sec[name]
            if type(fn) == "function" then
                local ok, v = pcall(fn)
                if ok and not isSecret(v) and type(v) == "boolean" then pr[name] = v end
            end
        end
        if next(pr) then out.predicates = pr end
    end
    local chat = g("C_ChatInfo")
    if type(chat) == "table" and type(chat.AreOutgoingAddonChatMessagesRestricted) == "function" then
        local ok, v = pcall(chat.AreOutgoingAddonChatMessagesRestricted)
        if ok and type(v) == "boolean" then out.addonChatRestricted = v end
    end
    return out
end

----------------------------------------------------------------------------
-- event handling
----------------------------------------------------------------------------
local function enabled() return cfg().enabled ~= false end

local function onFlip(_, rtype, rstate)
    if not enabled() then return end
    local r = db()
    if not r then return end
    if isSecret(rtype) or isSecret(rstate) then return end
    r.current = r.current or {}
    local tname = TYPE_NAMES[rtype] or tostring(rtype)
    local prev = r.current[tname]
    r.current[tname] = rstate
    local ck = tname .. ":" .. tostring(STATE_NAMES[rstate] or rstate)
    r.counts[ck] = (r.counts[ck] or 0) + 1
    local max = tonumber(cfg().maxFlips) or 400
    if #r.flips >= max then r.dropped = (r.dropped or 0) + 1 return end
    local rec = { type = rtype, typeName = tname, state = rstate, stateName = STATE_NAMES[rstate], prev = prev,
        capturing = capturing() or nil, ctx = R.Context(), states = R.States() }
    -- v2.2.26 (f): env tag + combat flag at dispatch, counted per env (BG / dungeon / open world ...)
    rec.env = ns.EnvTag and ns.EnvTag() or nil
    rec.inCombat = ns.InCombat and ns.InCombat() or false
    -- v2.2.29: a Combat activation precedes InCombatLockdown: count it as combat (rec.inCombatLockdown keeps the raw read)
    if ns.CombatAtFlip and not rec.inCombat and ns.CombatAtFlip(rtype, rstate) then
        rec.inCombatLockdown, rec.inCombat, rec.combatBy = false, true, "flip"
        if rec.env then rec.env = rec.env:gsub("/ooc/", "/combat/") end
    end
    r.byEnv = r.byEnv or {}
    local be = r.byEnv[rec.env or "?"] or {}
    r.byEnv[rec.env or "?"] = be
    local bk = ck .. (rec.inCombat and ":combat" or ":ooc")
    be[bk] = (be[bk] or 0) + 1
    -- documented: IsAddOnRestrictionActive is always false during dispatch of this event; recorded to confirm
    local cra = g("C_RestrictedActions")
    if type(cra) == "table" then rec.activeInHandler = bool(cra.IsAddOnRestrictionActive, rtype) end
    ns.Stamp(rec)
    r.flips[#r.flips + 1] = rec
    local probeMax = tonumber(cfg().maxProbedFlips) or 150
    local okVec, vec = pcall(R.Vector)
    if okVec then trackAlwaysOn(vec, "flip " .. ck) end
    if capturing() and cfg().probe ~= false and (r.probed or 0) < probeMax and not (ns.SelfThrottled and ns.SelfThrottled()) then
        r.probed = (r.probed or 0) + 1
        local okP, p = pcall(R.Probe)
        rec.probeAt = okP and p or { error = tostring(p) }
        if okVec then rec.vectorAt = vec end
        -- "Activating" is only enforced after dispatch completes: probe again next frame
        local after = g("C_Timer") and C_Timer.After
        if type(after) == "function" then
            after(0, function()
                local okA, pa = pcall(R.Probe)
                rec.probeAfter = okA and pa or { error = tostring(pa) }
                rec.statesAfter = R.States()
                rec.tAfter = GetTime and GetTime() or nil
                rec.latency = rec.tAfter and rec.t and (rec.tAfter - rec.t) or nil
                local okV2, v2 = pcall(R.Vector)
                if okV2 then rec.vectorAfter = v2 trackAlwaysOn(v2, "after " .. ck) end
                if cra and type(cra.IsAddOnRestrictionActive) == "function" then rec.activeAfter = bool(cra.IsAddOnRestrictionActive, rtype) end
            end)
        end
    end
end

local function onContext(event, ...)
    if not enabled() then return end
    local r = db()
    if not r then return end
    if event == "ENCOUNTER_START" then
        local id, name, diff, size = ...
        encounter = { id = clear(id), name = clear(name), difficulty = clear(diff), size = clear(size), start = GetTime and GetTime() }
    end
    local max = tonumber(cfg().maxMarkers) or 600
    if #r.markers >= max then r.droppedMarkers = (r.droppedMarkers or 0) + 1
    else
        local m = { event = event }
        if event == "ENCOUNTER_START" or event == "ENCOUNTER_END" then
            local id, name, diff, size, success = ...
            m.encounter = { id = clear(id), name = clear(name), difficulty = clear(diff), size = clear(size),
                success = event == "ENCOUNTER_END" and clear(success) or nil }
        elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event:find("^CHALLENGE_MODE")
            or event:find("^PVP_MATCH") then
            local c = R.Context()
            m.instance, m.zone, m.challengeMode, m.pvpMatchState = c.instance, c.zone, c.challengeMode, c.pvpMatchState
        end
        if event == "PLAYER_IN_COMBAT_CHANGED" then local ic = ... if not isSecret(ic) then m.inCombat = ic end end
        m.combat = ns.InCombat() or nil
        m.states = R.States()
        if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD"
            or event == "ZONE_CHANGED_NEW_AREA" then
            local okV, v = pcall(R.Vector)
            if okV then trackAlwaysOn(v, event) m.combatLogRestricted, m.addonChatRestricted = v.combatLogRestricted, v.addonChatRestricted end
        end
        ns.Stamp(m)
        r.markers[#r.markers + 1] = m
    end
    if event == "ENCOUNTER_END" then encounter = nil end
end
R.OnFlip, R.OnContext = onFlip, onContext

-- UNIT_AURA_BLOCKED (auraInstanceID documented SecretValue): counted per unit class, payload classified
local function onAuraBlocked(event, unit, ...)
    if not enabled() then return end
    local r = db()
    if not r then return end
    r.counts = r.counts or {}
    local u = (type(unit) == "string" and not isSecret(unit)) and (unit == "player" and "player" or "other") or "?"
    r.counts["UNIT_AURA_BLOCKED:" .. u] = (r.counts["UNIT_AURA_BLOCKED:" .. u] or 0) + 1
    if ns.ObserveLive and not (ns.Recorder and ns.Recorder.Covers and ns.Recorder.Covers(event)) then ns.ObserveLive("event", event, unit, ...) end
end

-- ns.On registers on ForeverDump's own private event frame; unknown events are pcall-registered there
ns.On("UNIT_AURA_BLOCKED", onAuraBlocked)
ns.On("ADDON_RESTRICTION_STATE_CHANGED", onFlip)
local regFailed = {}
R.RegisterFailed = regFailed
for _, ev in ipairs(CONTEXT_EVENTS) do
    local ok, err = pcall(ns.On, ev, onContext)
    if not ok then regFailed[ev] = tostring(err) end
end

-- session boundary: called by Logs on capture ON (baseline states + probe) and OFF (summary)
function R.Begin(sid)
    local r = db()
    if not r then return end
    r.sessions = r.sessions or {}
    local s = { sid = sid, statesAtStart = R.States(), ctxAtStart = R.Context(), flipsAtStart = #r.flips,
        markersAtStart = #r.markers, registerFailed = next(regFailed) and regFailed or nil }
    local ok, p = pcall(R.Probe)
    if ok then s.probeAtStart = p else s.probeAtStart = nil end
    local okV, v = pcall(R.Vector)
    if okV then s.vectorAtStart = v trackAlwaysOn(v, "capture start") end
    ns.Stamp(s)
    r.sessions[#r.sessions + 1] = s
    while #r.sessions > 10 do table.remove(r.sessions, 1) end
    r.probed = 0
end

function R.End()
    local r = db()
    local s = r and r.sessions and r.sessions[#r.sessions]
    if not s or s.ended then return nil end
    s.ended = true
    s.flips = #r.flips - (s.flipsAtStart or 0)
    s.markers = #r.markers - (s.markersAtStart or 0)
    s.statesAtEnd = R.States()
    s.endT = GetTime and GetTime() or nil
    return s
end

----------------------------------------------------------------------------
-- health self-check: ForeverDump installs no hooks on Blizzard code since v2.2. Verify that at runtime and spot the
-- v2.1 failure class (client hook wrappers raising "attempt to call a nil value" with a bare [C] frame on top).
----------------------------------------------------------------------------
local WRAPPED = {
    { "EventRegistry.TriggerEvent", function() local e, m = g("EventRegistry"), g("CallbackRegistryMixin")
        return type(e) == "table" and type(m) == "table" and e.TriggerEvent ~= m.TriggerEvent end },
}
function R.Health()
    local h = { ownHooks = 0, time = time and time() or nil, version = ns.VERSION }
    h.recorderCallbacks = ns.config and ns.config.record and ns.config.record.callbacks or false
    for _, w in ipairs(WRAPPED) do
        local ok, v = pcall(w[2])
        if ok and v then h.replaced = h.replaced or {} h.replaced[w[1]] = true end
    end
    local get = (g("C_CVar") and C_CVar.GetCVar) or g("GetCVar")
    if type(get) == "function" then
        local ok, v = pcall(get, "taintLog")
        if ok and not isSecret(v) then h.taintLog = v end
    end
    -- classify captured errors
    local nilWrapper, own, byAddon = {}, 0, {}
    for _, e in ipairs((ForeverDumpLogDB and ForeverDumpLogDB.errors) or {}) do
        local msg = e.message or ""
        local Err = ns.Errors
        -- v2.2.9: classify on the stack WITHOUT our handler prefix (v2.2.7 counted every error as own: 3354 in run 8)
        local st = (Err and Err.StripOwn and Err.StripOwn(e.stack)) or e.stack or ""
        if type(st) ~= "string" or isSecret(st) then st = "" end
        if e.addon then byAddon[e.addon] = (byAddon[e.addon] or 0) + (e.count or 1) end
        if Err and Err.IsOwn then
            if Err.IsOwn(e) then own = own + (e.count or 1) end
        elseif e.addon == ns.ADDON then own = own + (e.count or 1) end
        if msg:find("attempt to call a nil value", 1, true) then
            local fn = st:match("%[C%]: in function [`']([%w_%.:]+)'")
            if fn then nilWrapper[fn] = (nilWrapper[fn] or 0) + (e.count or 1) end
        end
    end
    local blockedBy = {}
    for _, b in ipairs((ForeverDumpLogDB and ForeverDumpLogDB.blocked) or {}) do
        if b.event and b.event:find("_ACTION_") and type(b.args) == "table" then
            local who = type(b.args.addon) == "string" and b.args.addon or "?"
            blockedBy[who] = blockedBy[who] or {}
            blockedBy[who][b.event] = (blockedBy[who][b.event] or 0) + 1
        end
    end
    h.blockedByAddon = next(blockedBy) and blockedBy or nil
    if blockedBy[ns.ADDON] then own = own + 1 end
    h.ownErrors = own
    h.nilCallInCFunction = next(nilWrapper) and nilWrapper or nil
    h.errorsByAddon = next(byAddon) and byAddon or nil
    h.ok = own == 0 and h.replaced == nil
    -- record counts per SavedVariables table (cheap; byte sizes: `fdump.py size`)
    local counts = {}
    local function n(t) local c = 0 if type(t) == "table" then for _ in pairs(t) do c = c + 1 end end return c end
    counts.sections = n(ns.db and ns.db.sections)
    counts.errors = n(ForeverDumpLogDB and ForeverDumpLogDB.errors)
    counts.blocked = n(ForeverDumpLogDB and ForeverDumpLogDB.blocked)
    counts.recordSessions = n(ForeverDumpRecordDB and ForeverDumpRecordDB.sessions)
    counts.combatSessions = n(ForeverDumpCombatLogDB and ForeverDumpCombatLogDB.sessions)
    counts.secretsObsKeys = ns.db and ns.db.secretsObs and ns.db.secretsObs._keys or 0
    local r = db()
    counts.restrictionFlips = r and #r.flips or 0
    counts.restrictionMarkers = r and #r.markers or 0
    h.counts = counts
    return h
end

function R.HealthText()
    local h = R.Health()
    local parts = { string.format("own hooks %d, own errors %d, taintLog=%s", h.ownHooks, h.ownErrors, tostring(h.taintLog)) }
    if h.replaced then for k in pairs(h.replaced) do parts[#parts + 1] = "|cffff8800" .. k .. " is wrapped by some addon|r" end end
    if h.nilCallInCFunction then
        for k, v in pairs(h.nilCallInCFunction) do parts[#parts + 1] = string.format("nil-call in [C] %s x%d", k, v) end
    end
    return (h.ok and "|cff33ff99health OK|r: " or "|cffff8800health:|r ") .. table.concat(parts, "; ")
end

function R.StatusText()
    local r = db() or { flips = {}, markers = {} }
    local st = R.States() or {}
    local act = {}
    for t = 0, 5 do local nm = TYPE_NAMES[t] if st[nm] and st[nm] ~= 0 then act[#act + 1] = nm .. "=" .. (STATE_NAMES[st[nm]] or st[nm]) end end
    return string.format("restrictions: %s; %d flip(s), %d context marker(s) logged%s", #act > 0 and table.concat(act, ", ") or "none active",
        #r.flips, #r.markers, r.dropped and (", " .. r.dropped .. " dropped") or "")
end
