-- ForeverDump v2.2.15 - lab probes. Run only at capture level "lab" (the FD_Logs default since v2.2.15; user
-- decision 2026-10-09: during an FD_Logs capture perf is MEASURED and reported, not gated; the runaway backstop in
-- Perf.lua turns lab work off if single calls reach 250 ms repeatedly). Never at release level.
-- Everything is secret-safe (values pass ns.Clear*/ClassifyValue first; only codes, counts, clear numbers and
-- histograms are stored) and taint-safe (own frame and own tables only; no Blizzard frame or table is touched).
--   aura     per unit-token class: add/remove counts (also when the payload is secret: presence only) + latency
--            histogram from my last UNIT_SPELLCAST_SUCCEEDED to the next aura add/remove (cast-to-aura timing)
--   heal     per token class: UNIT_COMBAT HEAL/ABSORB counts and clear sums, UNIT_HEAL_PREDICTION,
--            UNIT_ABSORB_AMOUNT_CHANGED, UNIT_HEAL_ABSORB_AMOUNT_CHANGED counts, readability codes of
--            UnitGetIncomingHeals/UnitGetTotalAbsorbs, latency histograms prediction->HEAL, absorb-change->ABSORB,
--            UNIT_COMBAT->UNIT_HEALTH (miner lead: 150-300 ms) and UNIT_DIED->DAMAGE_METER type 9 (deaths)
--   dm       at DAMAGE_METER_COMBAT_SESSION_UPDATED (<= 1/s per type): my per-spell breakdown, also mid-combat
--   sweep    post-combat un-secret sweep at +0/0.1/0.25/0.5/1/2/5/10 s: which getters are clear at each offset,
--            first-clear offset per getter; at the first clear read of my auras, every aura's applied time
--            (expirationTime - duration) and isFromPlayerOrPlayerPet verify the HSM's aura-on-me claims
--            (verdicts "aura-me-sweep" and "cand-aura:<id>": live predicted vs actual, no combat log)
--   sample   every 0.5 s in combat: readability codes of health/power/absorb getters on the extra tokens
-- Cost per probe: every handler runs under Perf ("Lab.<probe>"), reported per capture.
local _, ns = ...
local LP = {}
ns.LabProbes = LP

local function g(n) return rawget(_G, n) end
local function code(v) return ns.ClassifyValue(v) end
local function now() return (g("GetTime") or os.clock)() end
local function active() return ns.LabActive and ns.LabActive() and ns.db and ns.db.logs and ns.db.logs.on and true or false end

LP.BINS = { 25, 50, 100, 150, 200, 300, 450, 700, 1000, 2000 }   -- ms upper bounds; last bucket = more
LP.SWEEP = { 0, 0.1, 0.25, 0.5, 1, 2, 5, 10 }
-- v2.2.16: no snapshot / sweep cap (collect first; run 13's 600 cap dropped 1254 of 1854). The only limit is the Perf
-- runaway backstop (own-frame warning + SV record); LP.MAX_SNAPS / LP.MAX_SWEEPS stay as optional overrides (nil = none)
LP.MAX_SNAPS = nil
LP.MAX_SWEEPS = nil
LP.EXTRA = { "player", "target", "focus", "pet", "party1", "party2", "party3", "party4", "targettarget", "focustarget",
    "mouseover", "softenemy", "softfriend", "boss1", "arena1", "arena2", "arena3" }
local EVENTS = { "UNIT_AURA", "UNIT_COMBAT", "UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED",
    "UNIT_HEALTH", "UNIT_DIED", "UNIT_SPELLCAST_SUCCEEDED", "DAMAGE_METER_COMBAT_SESSION_UPDATED", "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED" }

local function db()
    local log = g("ForeverDumpLogDB")
    if type(log) ~= "table" then return nil end
    log.labProbes = log.labProbes or { v = 1 }   -- (ForeverDumpLogDB.lab belongs to the workarounds lab, Lab.lua)
    return log.labProbes
end
LP.DB = db

-- "nameplate12" -> "nameplateN", "party3" -> "partyN": bounded keys
local classCache = {}
local function cls(unit)
    local c = classCache[unit]
    if not c then c = (unit:gsub("%d+$", "N")) classCache[unit] = c end
    return c
end

local function bin(ms)
    for i, b in ipairs(LP.BINS) do if ms <= b then return i end end
    return #LP.BINS + 1
end
local function hist(t, k, ms)
    if type(ms) ~= "number" or ms < 0 then return end
    local h = t[k]
    if not h then h = {} t[k] = h end
    local i = bin(ms)
    h[i] = (h[i] or 0) + 1
end
local function inc(t, k, n) t[k] = (t[k] or 0) + (n or 1) end
local function bucket(d, sect, c)
    local s = d[sect]
    if not s then s = {} d[sect] = s end
    local b = s[c]
    if not b then b = {} s[c] = b end
    return b
end

local SNAP_NAMES, dmLast, snapDirty, snapDirtyN, snapPending, armSnap   -- deferred meter snapshots (below)
local lastOwnCast = nil      -- GetTime of my last UNIT_SPELLCAST_SUCCEEDED
local lastPred, lastAbs, lastUC = {}, {}, {}   -- [unit] = GetTime
local lastDied = nil
local lastCode = {}          -- [unit] = GetTime of the last readability sample (UnitGetIncomingHeals / absorbs)

local function readCode(fname, unit)
    local f = g(fname)
    if type(f) ~= "function" then return "A" end
    local ok, v = pcall(f, unit)
    if not ok then return "E" end
    return code(v)
end

SNAP_NAMES = { [0] = "DamageDone", [2] = "HealingDone", [4] = "Absorbs", [5] = "Interrupts", [7] = "DamageTaken" }
dmLast, snapDirty, snapDirtyN, snapPending = {}, {}, 0, false
local function snapJob()
    snapPending = false
    local name = next(snapDirty)
    if name == nil or not active() then return end
    snapDirty[name] = nil
    snapDirtyN = snapDirtyN - 1
    local d = db()
    local r = d and ns.DamageMeter and ns.DamageMeter.LabSnap and ns.DamageMeter.LabSnap(name)
    if r then
        local t = now()
        d.dmSnaps = d.dmSnaps or {}
        local n = #d.dmSnaps
        if LP.MAX_SNAPS == nil or n < LP.MAX_SNAPS then
            d.dmSnaps[n + 1] = { t = math.floor(t * 100 + 0.5) / 100, ty = name, c = r.c, total = r.total, spells = r.spells,
                inCombat = ns.InCombat() or nil }
        else inc(d, "dmSnapsDropped") end
        inc(bucket(d, "dmCodes", name), r.c or "?")
    end
    if snapDirtyN > 0 then armSnap() end
end
armSnap = function()
    if snapPending then return end
    local ct = g("C_Timer")
    if type(ct) ~= "table" or type(ct.After) ~= "function" then return end
    snapPending = true
    ct.After(0, function()
        if ns.Perf then ns.Perf.Run("Lab.dmSnap", snapJob) else pcall(snapJob) end
    end)
end

function LP.OnEvent(event, a1, a2, _, a4)
    local d = db()
    if not d then return end
    local t = now()
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if ns.ClearStr(a1) == "player" then lastOwnCast = t inc(d, "ownCasts") end
        return
    end
    if event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
        local ty = ns.ClearNum(a1)
        if ty == 9 and lastDied then hist(d, "diedToDm9", (t - lastDied) * 1000) lastDied = nil end
        -- v2.2.15: coalesced + deferred (dirty-only): mark the type, one snapshot per frame in a C_Timer job
        local name = ty and SNAP_NAMES[ty]
        if name and (not dmLast[name] or t - dmLast[name] >= 1) then
            dmLast[name] = t
            if not snapDirty[name] then snapDirty[name] = true snapDirtyN = snapDirtyN + 1 end
            armSnap()
        end
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then LP.Sweep() return end
    if event == "PLAYER_REGEN_DISABLED" then inc(d, "combats") return end
    local unit = ns.ClearStr(a1)
    if not unit then inc(d, "secretUnit") return end
    if event == "UNIT_DIED" then   -- payload is a GUID, not a token: count by GUID type + v2.2.21 raw GUID list (cap 200)
        lastDied = t
        local b = bucket(d, "died", unit:match("^(%a+)%-") or "other")
        inc(b, "n")
        b.guids = b.guids or {}
        if #b.guids < 200 then b.guids[#b.guids + 1] = unit end
        return
    end
    local c = cls(unit)
    if event == "UNIT_AURA" then
        local b = bucket(d, "aura", c)
        inc(b, "events")
        local info = a2
        do local ci0 = code(info) if ci0 == "S" then inc(b, "secretInfo") elseif ci0 == "T" then inc(b, "infoT") end end   -- v2.2.22: T != secret
        local ci = ns.ClearTable and ns.ClearTable(info)
        local added, removed = false, false
        if ci then
            if ns.IsTrue and ns.IsTrue(ci.isFullUpdate) then inc(b, "full") end
            local ad = ci.addedAuras
            if not ns.IsNil(ad) then
                added = true
                local cad = code(ad)
                if cad == "S" then inc(b, "addSecret")
                elseif type(ad) == "table" then
                    if cad == "T" then inc(b, "addT") end   -- v2.2.22: T list still counted (length via pcall)
                    local okL, nl = pcall(function() return #ad end)
                    if okL and code(nl) == "C" then inc(b, "add", nl) end
                end
            end
            local rm = ci.removedAuraInstanceIDs
            if not ns.IsNil(rm) then
                removed = true
                local crm = code(rm)
                if crm == "S" then inc(b, "remSecret")
                elseif type(rm) == "table" then
                    if crm == "T" then inc(b, "remT") end
                    local okL, nl = pcall(function() return #rm end)
                    if okL and code(nl) == "C" then inc(b, "rem", nl) end
                end
            end
            if not ns.IsNil(ci.updatedAuraInstanceIDs) then inc(b, "upd") end
        end
        if lastOwnCast then
            local ms = (t - lastOwnCast) * 1000
            if added then hist(b, "latAdd", ms) end
            if removed then hist(b, "latRem", ms) end
        end
    elseif event == "UNIT_COMBAT" then
        local b = bucket(d, "heal", c)
        local action = ns.ClearStr(a2)
        local amt = ns.ClearNum(a4)
        inc(b, "uc")
        if action == "HEAL" then
            inc(b, "HEAL") if amt then inc(b, "healAmt", amt) end
            if lastPred[unit] then hist(b, "predToHeal", (t - lastPred[unit]) * 1000) end
        elseif action == "ABSORB" then
            inc(b, "ABSORB")
            if lastAbs[unit] then hist(b, "absToAbsorb", (t - lastAbs[unit]) * 1000) end
        elseif action == nil then inc(b, "actionSecret") end
        lastUC[unit] = t
    elseif event == "UNIT_HEALTH" then
        if lastUC[unit] then
            local b = bucket(d, "heal", c)
            hist(b, "ucToHealth", (t - lastUC[unit]) * 1000)
            lastUC[unit] = nil
        end
    elseif event == "UNIT_HEAL_PREDICTION" or event == "UNIT_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEAL_ABSORB_AMOUNT_CHANGED" then
        local b = bucket(d, "heal", c)
        inc(b, event == "UNIT_HEAL_PREDICTION" and "pred" or (event == "UNIT_ABSORB_AMOUNT_CHANGED" and "absChg" or "healAbsChg"))
        if event == "UNIT_HEAL_PREDICTION" then lastPred[unit] = t else lastAbs[unit] = t end
        if not lastCode[unit] or t - lastCode[unit] >= 0.25 then   -- readability codes, <= 4/s per token
            lastCode[unit] = t
            inc(bucket(b, "codes", "incoming"), readCode("UnitGetIncomingHeals", unit))
            inc(bucket(b, "codes", "absorbs"), readCode("UnitGetTotalAbsorbs", unit))
            inc(bucket(b, "codes", "healAbsorbs"), readCode("UnitGetTotalHealAbsorbs", unit))
        end
    end
end

-- getters checked by the post-combat sweep and the in-combat sampler (codes only)
local SWEEP_GETTERS = {
    { "UnitHealth", "player" }, { "UnitHealth", "target" }, { "UnitHealthMax", "target" }, { "UnitPower", "player" },
    { "UnitGetTotalAbsorbs", "player" }, { "UnitGetIncomingHeals", "player" }, { "UnitHealth", "party1" },
}
local function auraFields(unit, i, filter)
    local UA = g("C_UnitAuras")
    if type(UA) ~= "table" or type(UA.GetAuraDataByIndex) ~= "function" then return "A" end
    local ok, a = pcall(UA.GetAuraDataByIndex, unit, i, filter)
    if not ok then return "E" end
    return code(a), a
end

-- live predicted vs actual for aura-on-me: my clear auras -> applied time + fromPlayer vs the HSM claims at that time
local function verifyAuras(d, hs)
    if not (hs and hs.inferences and hs.verdict) then return 0 end
    local n = 0
    for i = 1, 40 do
        local c, a = auraFields("player", i, "HELPFUL")
        if c ~= "K" and c ~= "C" and c ~= "T" then break end   -- v2.2.22: T aura structs read per field (clear fields only)
        local exp, dur = ns.ClearNum(a.expirationTime), ns.ClearNum(a.duration)
        local fromP = ns.ClearBool and ns.ClearBool(a.isFromPlayerOrPlayerPet)
        if exp and dur and dur > 0 and fromP ~= nil then
            local applied = exp - dur
            -- live HSM claim (aura-on-me inference closest to the applied time, within 0.3 s)
            local best, bd = nil, 0.3
            for j = #hs.inferences, math.max(1, #hs.inferences - 400), -1 do
                local r = hs.inferences[j]
                if r.t and r.t < applied - 1 then break end
                if r.unit == "player" and r.kind == "applied" and r.src and r.t then
                    local dd = math.abs(r.t - applied)
                    if dd <= bd then best, bd = r, dd end
                end
            end
            if best then
                n = n + 1
                local ok = (best.src == "mine") == fromP
                hs:verdict("aura-me-sweep", ok and "V" or "C", { src = best.rule, conf = best.conf, d = best.t - applied })
                inc(bucket(d, "sweepAura", best.rule or "?"), ok and "V" or "C")
            else inc(d, "sweepAuraNoClaim") end
            -- candidate claims (lab): the same check per candidate rule
            for _, r in ipairs(hs.candAura or {}) do
                if math.abs(r.t - applied) <= 0.3 then
                    local ok = (r.src == "mine") == fromP
                    hs:verdict("cand-aura:" .. r.id, ok and "V" or "C", { src = r.src, conf = "shadow", d = r.t - applied })
                end
            end
        end
    end
    return n
end

function LP.Sweep()
    local d = db()
    local ct = g("C_Timer")
    if not (d and type(ct) == "table" and type(ct.After) == "function") then return end
    local t0 = now()
    d.sweeps = d.sweeps or {}
    if LP.MAX_SWEEPS and #d.sweeps >= LP.MAX_SWEEPS then inc(d, "sweepsDropped") return end
    local sw = { t = math.floor(t0 * 100 + 0.5) / 100, at = {}, firstClear = {} }
    -- v2.2.16: where the sweep ran (open world / pvp / party ...: cached values are learned outside BGs too) and the
    -- fight's same-class census + per-rule gate counters (counts only) for the attribution-safety report
    local okI, _, ity = pcall(g("IsInInstance") or error)
    sw.inst = okI and ns.ClearStr and ns.ClearStr(ity) or nil
    local hs = ns.Inference and ns.Inference.hs
    if hs and hs.census then
        sw.census = { same = hs.census.sameClass, sameEnemy = hs.census.sameClassEnemy, n = hs.census.n }
        local a = {}
        for rule, st in pairs(hs.attrStats or {}) do
            a[rule] = { mine = st.mine, other = st.other, none = st.none, amb = st.ambiguous, cor = st.corroborated,
                tm = st.mismatch, pl = st.implausible }
        end
        sw.attr = a
    end
    d.sweeps[#d.sweeps + 1] = sw
    local verified = false
    for _, off in ipairs(LP.SWEEP) do
        ct.After(off, function()
            if not active() then return end
            local function step()
                local row = { inCombat = ns.InCombat() or nil }
                for _, gu in ipairs(SWEEP_GETTERS) do
                    local k = gu[1] .. "(" .. gu[2] .. ")"
                    local c = readCode(gu[1], gu[2])
                    row[k] = c
                    if (c == "C" or c == "K") and not sw.firstClear[k] then sw.firstClear[k] = off end
                end
                local c = auraFields("player", 1, "HELPFUL")
                row["GetAuraDataByIndex(player,1)"] = c
                if (c == "C" or c == "K") and not sw.firstClear.aura then sw.firstClear.aura = off end
                if (c == "C" or c == "K") and not verified and not ns.InCombat() then
                    verified = true
                    sw.auraVerified = verifyAuras(d, ns.Inference and ns.Inference.hs)
                end
                sw.at[tostring(off)] = row
            end
            if ns.Perf then ns.Perf.Run("Lab.sweep", step) else pcall(step) end
        end)
    end
end

-- 0.5 s in-combat sampler: readability codes per extra token (exists / health / power / absorbs)
local ticker
local function sample()
    if not (active() and ns.InCombat()) then return end
    local d = db()
    if not d then return end
    local ex = g("UnitExists")
    for _, u in ipairs(LP.EXTRA) do
        local okE, e = pcall(ex, u)
        local ce = okE and code(e) or "E"
        local b = bucket(d, "sample", u)
        inc(b, "exists:" .. ce)
        if ce == "S" or (ce == "C" and ns.ClearBool and ns.ClearBool(e) == true) then
            inc(b, "UnitHealth:" .. readCode("UnitHealth", u))
            inc(b, "UnitPower:" .. readCode("UnitPower", u))
            inc(b, "UnitGetTotalAbsorbs:" .. readCode("UnitGetTotalAbsorbs", u))
            inc(b, "UnitIsDead:" .. readCode("UnitIsDead", u))
        end
    end
end

LP.Sample = sample

local frame
function LP.Start()
    if not active() then return false end
    local d = db()
    if not d then return false end
    for k in pairs(d) do d[k] = nil end
    d.v, d.sid = 1, ns.db.logs.session and ns.db.logs.session.sid
    d.bins = LP.BINS
    lastOwnCast, lastDied, lastPred, lastAbs, lastUC, lastCode = nil, nil, {}, {}, {}, {}
    dmLast, snapDirty, snapDirtyN = {}, {}, 0
    if not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", function(_, event, ...)
            if not active() then return end
            local ok, err
            if ns.Perf then ok, err = ns.Perf.Run(ns.Perf.Key("Lab", event), LP.OnEvent, event, ...)
            else ok, err = pcall(LP.OnEvent, event, ...) end
            if not ok then ns.NoteSelfError("LabProbes." .. event, err) end
        end)
    end
    for _, ev in ipairs(EVENTS) do pcall(frame.RegisterEvent, frame, ev) end
    if ns.Perf and type(g("collectgarbage")) == "function" then ns.Perf.trackHeap = true end   -- spike GC attribution
    local ct = g("C_Timer")
    if type(ct) == "table" and type(ct.NewTicker) == "function" then
        ticker = ct.NewTicker(0.5, function()
            if ns.Perf then ns.Perf.Run("Lab.sample", sample) else pcall(sample) end
        end)
    end
    return true
end

function LP.Stop()
    if frame then pcall(frame.UnregisterAllEvents, frame) end
    if ns.Perf then ns.Perf.trackHeap = false end
    if ticker and ticker.Cancel then ticker:Cancel() end
    ticker = nil
    local d = db()
    if not d then return nil end
    local n = 0
    for _ in pairs(d.aura or {}) do n = n + 1 end
    return { tokens = n, sweeps = d.sweeps and #d.sweeps or 0, snaps = d.dmSnaps and #d.dmSnaps or 0 }
end

ns.captureModules = ns.captureModules or {}
ns.captureModules[#ns.captureModules + 1] = { name = "lab probes (capture level lab)", start = function() return LP.Start() end,
    stop = function()
        local r = LP.Stop()
        return r and string.format("lab probes: %d aura token class(es), %d sweep(s), %d meter snapshot(s)", r.tokens, r.sweeps, r.snaps)
    end }
