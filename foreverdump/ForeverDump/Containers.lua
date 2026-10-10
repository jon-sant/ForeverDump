-- ForeverDump v2.2.2: container-state schema probe (permanent probe set).
-- For every probed API return, walk tables / objects recursively and record per field the five-state classification
--   A absent (key seen in other observations, missing here; derived from counts), N nil, S secret, K/T container
--   (T = container with secret contents), C clear, E error
-- plus container flags (issecrettable, canaccesstable, hasanysecretvalues over the field values, obj:HasSecretValues()),
-- the clear length (#t when readable), the clear field count and the key list. Aggregated per build / context
-- (ooc, combat, restricted, enc + active restriction types) / unit class (CombatProbe.UnitClass) / probe.
-- Only codes, booleans, key names and clear lengths are stored: never a value, never anything derived from a secret.
-- Runs from clean callbacks (capture ON, first combat per context, restriction flips, UNIT_AURA payloads) and skips
-- protected / combat-blocked reads in combat (CombatProbe.CombatSkip, learned ADDON_ACTION_BLOCKED paths).
local _, ns = ...
local CT = {}
ns.Containers = CT

local function g(n) return rawget(_G, n) end
local function cfg() ns.config.containers = ns.config.containers or {} return ns.config.containers end
local MAX_DEPTH, MAX_KEYS, MAX_ARR = 3, 48, 3
-- zero-argument getters of duration / curve / cooldown objects (only called when present)
CT.METHODS = { "HasSecretValues", "IsZero", "GetRemainingDuration", "GetTotalDuration", "GetElapsedDuration", "GetRemainingPercent",
    "GetElapsedPercent", "GetStartTime", "GetEndTime", "GetModRate", "GetPointCount" }

local function code(v) return ns.ClassifyValue(v) end
local function isSecret(v) return ns.IsSecret(v) end

-- boolean-ish result of a predicate: true/false, "S" when the answer itself is secret, "E" on error
local function pred(f, ...)
    if type(f) ~= "function" then return nil end
    local ok, r = pcall(f, ...)
    if not ok then return "E" end
    if isSecret(r) then return "S" end
    return r and true or false
end

-- one observation -> schema node { s = code, ty, fl = {flag = bool|"S"|"E"}, len, nk, nc, keys = {...}, f = {k = node}, arr = node }
function CT.Walk(v, depth)
    depth = depth or 0
    local c = code(v)
    local node = { s = c }
    if c == "S" or c == "N" or c == "C" then
        if c == "C" then node.ty = type(v) end
        return node
    end
    local ty = type(v)
    node.ty = ty
    local fl = {}
    if ty == "table" then
        fl.issecrettable = pred(g("issecrettable"), v)
        fl.canaccesstable = pred(g("canaccesstable"), v)
    end
    local okM, m = pcall(function() return v.HasSecretValues end)
    if okM and type(m) == "function" then fl.HasSecretValues = pred(m, v) end
    node.fl = next(fl) and fl or nil
    if depth >= MAX_DEPTH then node.trunc = true return node end
    local f, keys, nk, nc, vals = {}, {}, 0, 0, {}
    if ty == "table" then
        local okL, len = pcall(function() return #v end)
        if okL and not isSecret(len) then node.len = len else node.lenState = okL and "S" or "E" end
        local okI = pcall(function()
            for k, x in next, v do
                if isSecret(k) then node.secretKeys = (node.secretKeys or 0) + 1
                elseif type(k) == "string" then
                    nk = nk + 1
                    if nk <= MAX_KEYS then
                        keys[#keys + 1] = k
                        local child = CT.Walk(x, depth + 1)
                        f[k] = child
                        if child.s == "C" then nc = nc + 1 end
                        if #vals < 40 then vals[#vals + 1] = x end
                    end
                elseif type(k) == "number" then
                    if k >= 1 and k <= MAX_ARR then
                        local child = CT.Walk(x, depth + 1)
                        node.arr = node.arr and CT.Merge(node.arr, child) or CT.Merge(nil, child)
                    end
                    if #vals < 40 then vals[#vals + 1] = x end
                    node.nIdx = (node.nIdx or 0) + 1
                end
            end
        end)
        if not okI then node.iterErr = true end
        local hv = g("hasanysecretvalues")
        if type(hv) == "function" and #vals > 0 then fl.hasanysecretvalues = pred(hv, unpack(vals)) node.fl = fl end
    end
    -- object getters (duration objects are userdata or tables with methods)
    for _, name in ipairs(CT.METHODS) do
        local okG, meth = pcall(function() return v[name] end)
        if okG and type(meth) == "function" then
            local res = ns.Pack(pcall(meth, v))
            local k = name .. "()"
            keys[#keys + 1] = k
            f[k] = res[1] and CT.Walk(res[2], depth + 1) or { s = "E" }
            if f[k].s == "C" then nc = nc + 1 end
        end
    end
    table.sort(keys)
    node.keys = #keys > 0 and keys or nil
    node.f = next(f) and f or nil
    node.nk, node.nc = nk, nc
    return node
end

-- several returns -> one pseudo-container node ("R"): ret1..retN, plus the select('#') count
function CT.WalkReturns(res)
    if not res[1] then return { s = "E", err = true } end
    local node = { s = "R", ty = "returns", n = res.n - 1, f = {}, keys = {} }
    local nc = 0
    for i = 2, res.n do
        local k = "ret" .. (i - 1)
        node.keys[#node.keys + 1] = k
        node.f[k] = CT.Walk(res[i], 1)
        if node.f[k].s == "C" then nc = nc + 1 end
    end
    node.nc = nc
    return node
end

-- aggregate: counts per state / flag value, union of keys, max clear length, recursive
local function bump(t, k) k = tostring(k) t[k] = (t[k] or 0) + 1 end
function CT.Merge(agg, node)
    agg = agg or { s = {}, obs = 0 }
    agg.obs = agg.obs + 1
    bump(agg.s, node.s)
    if node.ty then agg.ty = node.ty end
    if node.fl then
        agg.fl = agg.fl or {}
        for k, v in pairs(node.fl) do agg.fl[k] = agg.fl[k] or {} bump(agg.fl[k], v) end
    end
    if node.len then agg.lenMax = math.max(agg.lenMax or 0, node.len) agg.lenClear = (agg.lenClear or 0) + 1 end
    if node.lenState then agg.lenSecret = (agg.lenSecret or 0) + 1 end
    if node.n then agg.nMax = math.max(agg.nMax or 0, node.n) end
    if node.nc then agg.ncMax = math.max(agg.ncMax or 0, node.nc) end
    if node.secretKeys then agg.secretKeys = (agg.secretKeys or 0) + 1 end
    if node.iterErr then agg.iterErr = (agg.iterErr or 0) + 1 end
    if node.trunc then agg.trunc = true end
    if node.err then agg.err = node.err end
    if node.f then
        agg.f = agg.f or {}
        for k, child in pairs(node.f) do agg.f[k] = CT.Merge(agg.f[k], child) end
    end
    if node.arr then
        -- node.arr is already an aggregate (merged elements of one observation)
        agg.arr = agg.arr or { s = {}, obs = 0 }
        local a = node.arr
        agg.arr.obs = agg.arr.obs + (a.obs or 1)
        for k, n in pairs(a.s or {}) do agg.arr.s[k] = (agg.arr.s[k] or 0) + n end
        if a.f then agg.arr.f = agg.arr.f or {} for k, child in pairs(a.f) do agg.arr.f[k] = CT.MergeAgg(agg.arr.f[k], child) end end
    end
    return agg
end
-- merge two aggregates (array element schemas)
function CT.MergeAgg(a, b)
    if not a then return b end
    a.obs = (a.obs or 0) + (b.obs or 0)
    a.s = a.s or {}
    for k, n in pairs(b.s or {}) do a.s[k] = (a.s[k] or 0) + n end
    if b.f then a.f = a.f or {} for k, child in pairs(b.f) do a.f[k] = CT.MergeAgg(a.f[k], child) end end
    return a
end

----------------------------------------------------------------------------
-- probe set
----------------------------------------------------------------------------
local AURA_FILTERS = { "HELPFUL", "HARMFUL", "HELPFUL|PLAYER", "HARMFUL|PLAYER" }
CT.UNITS = { "player", "target", "focus", "pet", "party1", "party2", "raid1", "targettarget" }

local function db()
    local L = ForeverDumpLogDB
    if type(L) ~= "table" then return nil end
    local build = ns.Build()
    local d = L.containers
    if type(d) ~= "table" or d.v ~= 1 or d.build ~= build then
        d = { v = 1, build = build, schema = {}, runs = 0, keys = {} }
        L.containers = d
    end
    return d
end
CT.DB = db

local function inLockdown()
    local il = g("InCombatLockdown")
    local ok, v = pcall(il or function() return false end)
    return (ok and v == true) or (ns.InCombat and ns.InCombat()) or false
end

local cctxT, cctxV
function CT.Context()
    local t = (g("GetTime") or os.clock)()
    if cctxT == t and cctxV then return cctxV end
    cctxV, cctxT = CT.ContextNow(), t
    return cctxV
end
function CT.ContextNow()
    local base = (ns.CombatProbe and ns.CombatProbe.Context and ns.CombatProbe.Context()) or (ns.InCombat() and "combat" or "ooc")
    local cra = g("C_RestrictedActions")
    local act = {}
    if type(cra) == "table" and type(cra.GetAddOnRestrictionState) == "function" then
        for t = 0, 5 do
            local ok, st = pcall(cra.GetAddOnRestrictionState, t)
            if ok and isSecret(st) then act[#act + 1] = t .. "?"
            elseif ok and type(st) == "number" and st > 0 then act[#act + 1] = tostring(t) end
        end
    end
    return #act > 0 and (base .. "|r" .. table.concat(act, ",")) or base
end

local function put(d, ctx, ucls, probe, node)
    d.schema[ctx] = d.schema[ctx] or {}
    d.schema[ctx][ucls] = d.schema[ctx][ucls] or {}
    local byP = d.schema[ctx][ucls]
    byP[probe] = CT.Merge(byP[probe], node)
end

-- call path(...) unless it is combat-skipped; returns the schema node and the raw Pack (for chaining, never stored)
local function call(d, ctx, ucls, probe, path, ...)
    local f = ns.Resolve(path)
    if type(f) ~= "function" then return nil end
    if inLockdown() and ns.CombatProbe and ns.CombatProbe.CombatSkip then
        local why = ns.CombatProbe.CombatSkip(path, CT.curUnit)
        if why then d.skipped = d.skipped or {} d.skipped[path] = why return nil end
    end
    if ns.ProbeMark then ns.ProbeMark("Containers", path, CT.curUnit) end
    local res = ns.Pack(pcall(f, ...))
    if ns.ProbeDone then ns.ProbeDone() end
    local node
    if not res[1] then node = { s = "E" }
        d.errors = d.errors or {}
        local e = res[2]
        d.errors[path] = (type(e) == "string" and not isSecret(e)) and e:sub(1, 160) or "error"
    elseif res.n <= 2 then node = CT.Walk(res[2], 0)
    else node = CT.WalkReturns(res) end
    put(d, ctx, ucls, probe, node)
    return node, res
end
CT.Call = call

local function clear(v) if v ~= nil and not isSecret(v) then return v end end

local function auraProbes(d, ctx, ucls, u)
    for _, filter in ipairs(AURA_FILTERS) do
        local _, res = call(d, ctx, ucls, "C_UnitAuras.GetAuraDataByIndex(u,1," .. filter .. ")", "C_UnitAuras.GetAuraDataByIndex", u, 1, filter)
        local a = res and res[1] and res[2]
        local iid = type(a) == "table" and code(a) ~= "S" and clear(a.auraInstanceID) or nil
        if iid then
            call(d, ctx, ucls, "C_UnitAuras.GetAuraDuration(u,iid)", "C_UnitAuras.GetAuraDuration", u, iid)
            call(d, ctx, ucls, "C_UnitAuras.GetAuraApplicationDisplayCount(u,iid)", "C_UnitAuras.GetAuraApplicationDisplayCount", u, iid)
        end
        call(d, ctx, ucls, "C_UnitAuras.GetAuraSlots(u," .. filter .. ")", "C_UnitAuras.GetAuraSlots", u, filter)
        call(d, ctx, ucls, "C_UnitAuras.GetUnitAuras(u," .. filter .. ")", "C_UnitAuras.GetUnitAuras", u, filter)
        -- count by iteration: index until a clear nil (countable), a secret (identity hidden), or an error
        local ua = g("C_UnitAuras")
        if type(ua) == "table" and type(ua.GetAuraDataByIndex) == "function" then
            local state, n = "C", 0
            if ns.ProbeMark then ns.ProbeMark("Containers", "C_UnitAuras.GetAuraDataByIndex#iterate", u) end
            for i = 1, 40 do
                local ok, x = pcall(ua.GetAuraDataByIndex, u, i, filter)
                if not ok then state = "E" break end
                if x == nil then break end
                if isSecret(x) then state = "S" break end
                n = n + 1
            end
            if ns.ProbeDone then ns.ProbeDone() end
            -- stored: whether a clear count was obtainable (state) and its clear value only when state == "C"
            put(d, ctx, ucls, "count:GetAuraDataByIndex-iterate(" .. filter .. ")", { s = state, ty = "count", len = state == "C" and n or nil })
        end
    end
end

local function unitProbes(d, ctx, ucls, u)
    auraProbes(d, ctx, ucls, u)
    call(d, ctx, ucls, "UnitCastingInfo(u)", "UnitCastingInfo", u)
    call(d, ctx, ucls, "UnitChannelInfo(u)", "UnitChannelInfo", u)
    call(d, ctx, ucls, "UnitCastingDuration(u)", "UnitCastingDuration", u)
    call(d, ctx, ucls, "UnitChannelDuration(u)", "UnitChannelDuration", u)
    call(d, ctx, ucls, "UnitHealth(u)", "UnitHealth", u)
    call(d, ctx, ucls, "UnitHealthMax(u)", "UnitHealthMax", u)
    call(d, ctx, ucls, "UnitPower(u)", "UnitPower", u)
    call(d, ctx, ucls, "UnitName(u)", "UnitName", u)
    call(d, ctx, ucls, "UnitGUID(u)", "UnitGUID", u)
end

-- player-only: spell cooldown / charges / info objects for a few known spells, totem slots
local function playerProbes(d, ctx)
    local ids = { 61304 }   -- global cooldown
    local kdb = ns.Knowledge and ns.Knowledge.DB and ns.Knowledge.DB()
    for id in pairs((kdb and kdb.spells) or {}) do
        if #ids >= (tonumber(cfg().spells) or 4) then break end
        if type(id) == "number" then ids[#ids + 1] = id end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local tag = id == 61304 and "gcd" or "spell"
        call(d, ctx, "player", "C_Spell.GetSpellCooldown(" .. tag .. ")", "C_Spell.GetSpellCooldown", id)
        call(d, ctx, "player", "C_Spell.GetSpellCooldownDuration(" .. tag .. ")", "C_Spell.GetSpellCooldownDuration", id)
        call(d, ctx, "player", "C_Spell.GetSpellCharges(" .. tag .. ")", "C_Spell.GetSpellCharges", id)
        call(d, ctx, "player", "C_Spell.GetSpellInfo(" .. tag .. ")", "C_Spell.GetSpellInfo", id)
    end
    for slot = 1, 4 do call(d, ctx, "player", "GetTotemInfo(slot)", "GetTotemInfo", slot) end
end

function CT.Run(reason)
    if cfg().enabled == false then return nil end
    if ns.SelfThrottled and ns.SelfThrottled() then return nil end
    local d = db()
    if not d then return nil end
    local ctx = CT.Context()
    local sid = ns.db and ns.db.logs and ns.db.logs.session and ns.db.logs.session.sid or 0
    -- once per context per capture session (the schema only changes with context), bounded per capture
    local once = sid .. "|" .. ctx
    if d.keys[once] and reason ~= "manual" then return nil end
    if (d.capRuns or 0) >= (tonumber(cfg().maxRunsPerCapture) or 8) and reason ~= "manual" then return nil end
    d.keys[once] = true
    d.capRuns = (d.capRuns or 0) + 1
    d.runs = (d.runs or 0) + 1
    d.ctxRuns = d.ctxRuns or {}
    d.ctxRuns[ctx] = (d.ctxRuns[ctx] or 0) + 1
    local seen = {}
    local ucf = ns.CombatProbe and ns.CombatProbe.UnitClass
    for _, u in ipairs(CT.UNITS) do
        local ucls = ucf and ucf(u)
        if ucls and not seen[ucls] then
            seen[ucls] = true
            CT.curUnit = u
            unitProbes(d, ctx, ucls, u)
        end
    end
    CT.curUnit = "player"
    playerProbes(d, ctx)
    CT.curUnit = nil
    d.last = { reason = reason, ctx = ctx, t = time and time() or nil }
    return ctx
end

-- event payloads (UNIT_AURA updateInfo): called from Inference's clean event handler, sampled per context/unit class
local evDone = {}   -- v2.2.3: units whose payload samples are complete in a context -> O(1) early exit per UNIT_AURA
function CT.ObserveEvent(event, unit, payload)
    if cfg().enabled == false or cfg().events == false then return end
    local cctx = ns.CombatProbe and ns.CombatProbe.Context and ns.CombatProbe.Context() or "?"
    if cctx ~= CT.evCtx then evDone = {} CT.evCtx = cctx end   -- new context: sample again
    local dk = unit
    if evDone[dk] then return end
    local d = db()
    if not d then return end
    local ctx = CT.Context()
    local ucf = ns.CombatProbe and ns.CombatProbe.UnitClass
    local ucls = (ucf and ucf(unit)) or "?"
    d.evN = d.evN or {}
    local k = ctx .. "|" .. ucls .. "|" .. event
    d.evN[k] = (d.evN[k] or 0) + 1
    if d.evN[k] > (tonumber(cfg().eventSamples) or 25) then evDone[dk] = true return end
    put(d, ctx, ucls, "event:" .. event, CT.Walk(payload, 0))
end

-- scheduling: capture ON (ooc), first combat per context (+1.5 s, after the combat probe), restriction flips
local frame
local function after(s, f) if type(g("C_Timer")) == "table" then C_Timer.After(s, f) else f() end end
function CT.Start()
    if cfg().enabled == false then return false end
    local d = db()
    if not d then return false end
    d.capRuns = 0
    if not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", function(_, event)
            local delay = event == "PLAYER_REGEN_DISABLED" and 1.5 or 0.3
            after(delay, function()
                local ok, err
                if ns.Perf then ok, err = ns.Perf.Run("Containers.Run", CT.Run, event) else ok, err = pcall(CT.Run, event) end
                if not ok then ns.NoteSelfError("Containers." .. event, err) end
            end)
        end)
    end
    for _, ev in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ADDON_RESTRICTION_STATE_CHANGED", "ENCOUNTER_START" }) do
        pcall(frame.RegisterEvent, frame, ev)
    end
    local ok, err = pcall(CT.Run, "capture:on")
    if not ok then ns.NoteSelfError("Containers.Run", err) end
    return true
end
function CT.Stop()
    if frame then pcall(frame.UnregisterAllEvents, frame) end
    local d = db()
    if not d then return nil end
    local n = 0
    for _, byU in pairs(d.schema) do for _, byP in pairs(byU) do for _ in pairs(byP) do n = n + 1 end end end
    return { runs = d.capRuns or 0, probes = n }
end

ns.captureModules = ns.captureModules or {}
ns.captureModules[#ns.captureModules + 1] = { name = "container schema", start = function() return CT.Start() end,
    stop = function() local r = CT.Stop() return r and string.format("containers %d run(s), %d probe cells", r.runs, r.probes) end }
