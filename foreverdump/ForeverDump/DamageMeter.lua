-- ForeverDump v2.2.6 - C_DamageMeter deep mine for offline CLEU correlation + HSM self-reconcile.
-- Release (<1%): event counts + HSM timing + one in-combat classify + light post-combat me/others totals.
-- Capture/test (<=10%): every DAMAGE_METER_* on the replay tape; throttled structure classification (~2/s/type);
--   post-combat full read of EVERY Enum.DamageMeterType — all sources (raw GUID + raw name + kind:<raw> key, kind,
--   class, creatureID, isLocalPlayer, totals, per-second, deathRecap), per-spell breakdowns, combatSpellDetails (raw
--   unitName, kind/class/isPet/isMob/amount). v2.2.21: raw identities stored as read. No secret values stored.
local _, ns = ...
local DM = {}
ns.DamageMeter = DM

local function g(n) return rawget(_G, n) end
local function cfg() return (ns.config and ns.config.damageMeter) or {} end
local function code(v) return ns.ClassifyValue(v) end
-- v2.2.7 (run 6b): every API value goes through ns.Clear*/ns.IsTrue/ns.IsNil (classify first, never truth-test raw values)
local function clearNum(v) return ns.ClearNum(v) end
local function clearBool(v) return ns.ClearBool(v) end
local function clearStr(v) return ns.ClearStr(v) end
local isNil, isTrue = ns.IsNil, ns.IsTrue
local function now() return (g("GetTime") or os.clock)() end
local function capture() return ns.ReplayLog and ns.ReplayLog.IsTest and ns.ReplayLog.IsTest() end

DM.TYPES = { DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, Absorbs = 4, Interrupts = 5, Dispels = 6, DamageTaken = 7,
    AvoidableDamageTaken = 8, Deaths = 9, EnemyDamageTaken = 10 }
-- every type, including Dps/Hps/Avoidable/Enemy (capture deep read)
DM.ALL = { "DamageDone", "Dps", "HealingDone", "Hps", "Absorbs", "Interrupts", "Dispels", "DamageTaken",
    "AvoidableDamageTaken", "Deaths", "EnemyDamageTaken" }
DM.READ = { "DamageDone", "HealingDone", "Absorbs", "Interrupts", "Dispels", "DamageTaken", "Deaths", "EnemyDamageTaken" }

local function enumType(name)
    local E = g("Enum")
    local t = type(E) == "table" and rawget(E, "DamageMeterType")
    return (type(t) == "table" and t[name]) or DM.TYPES[name]
end
local function currentSession()
    local E = g("Enum")
    local t = type(E) == "table" and rawget(E, "DamageMeterSessionType")
    return (type(t) == "table" and t.Current) or 1
end

local function db()
    local log = g("ForeverDumpLogDB")
    if type(log) ~= "table" then return nil end
    log.damageMeter = log.damageMeter or { v = 2 }
    return log.damageMeter
end
DM.DB = db

local function api() local D = g("C_DamageMeter") if type(D) ~= "table" then return nil end return D end

local function field(t, k)
    -- v2.2.7: a secret table VALUE is never indexed. v2.2.22 (audit): a "T" struct (issecrettable / some secret
    -- fields) IS indexed with pcall so every field gets its own code (was: whole struct -> every field "N")
    if type(t) ~= "table" or ns.IsSecretValue(t) then return nil end
    local ok, v = pcall(function() return t[k] end)
    -- v2.2.7: `ok and v or nil` tested v's truthiness -> "boolean test on a secret boolean" (run 6, DamageMeter.lua:51)
    if not ok then return nil end
    return v
end

local function note(ctx, path, v)
    local d = db()
    if not d then return end
    d.schema = d.schema or {}
    d.schema[ctx] = d.schema[ctx] or {}
    local cell = d.schema[ctx][path]
    if not cell then cell = {} d.schema[ctx][path] = cell end
    local c = code(v)
    cell[c] = (cell[c] or 0) + 1
    if ns.ObserveArgs and c ~= "N" then
        local struct, fld = path:match("^(%u%a+)%.(%a+)$")
        if struct then ns.ObserveArgs("field", "DamageMeter" .. struct .. "." .. fld, 1, c == "S" and { 1 } or nil)
        elseif path:match("^%u%a+$") then ns.ObserveArgs("api", "C_DamageMeter." .. path, 1, c == "S" and { 1 } or nil) end   -- v2.2.22: T is not secret
    end
    return c
end

local SESSION_FIELDS = { "durationSeconds", "totalAmount", "maxAmount", "combatSources" }
local SOURCE_FIELDS = { "sourceGUID", "name", "classFilename", "isLocalPlayer", "totalAmount", "amountPerSecond", "sourceCreatureID",
    "classification", "specIconID", "deathRecapID", "deathTimeSeconds", "sourceDisplayType", "combatSpells" }
local SPELL_FIELDS = { "spellID", "totalAmount", "amountPerSecond", "overkillAmount", "creatureName", "isAvoidable", "isDeadly", "combatSpellDetails" }
local DETAIL_FIELDS = { "unitName", "unitClassFilename", "classification", "isPet", "isMob", "amount", "specIconID" }

local function classifyStruct(ctx, prefix, t, fields)
    note(ctx, prefix .. ".@container", t)   -- v2.2.22: the struct's own code (K / T / S) next to its per-field codes
    for _, f in ipairs(fields) do note(ctx, prefix .. "." .. f, field(t, f)) end
end

local function first(list)
    if type(list) ~= "table" or code(list) == "S" then return nil end
    return field(list, 1)
end

local function myGUID()
    local f = g("UnitGUID")
    if type(f) ~= "function" then return nil end
    local ok, v = pcall(f, "player")
    if not ok then return nil end
    return clearStr(v)
end

local function idKey(kind, id)   -- callers pass cleared values (clearStr / clearNum) only
    if ns.ReplayLog and ns.ReplayLog.IdKey then return ns.ReplayLog.IdKey(kind, id) end
    if ns.ClearStr(id) == "player" then return "player" end
    return nil
end

-- v2.2.20: name keys are realm-stripped everywhere (plates / scoreboard / ooc fill use the base name; run 15 meter keys
-- never met the plate keys)
local function baseName(v)
    local s = clearStr(v)
    if not s or s == "" then return nil end
    return s:match("^([^%-]+)") or s
end

local function sourceKind(guid)
    local cg = clearStr(guid)
    if not cg then return nil end
    return cg:match("^(%a+)%-")
end

local function lenClear(list)
    if type(list) ~= "table" or code(list) == "S" then return nil end
    local n = 0
    for i = 1, 500 do
        if isNil(field(list, i)) then break end
        n = n + 1
    end
    return n
end

-- structure-only sample (clear lengths / presence); never stores secret values
local function classifyStructure(ctx, tyName)
    local D = api()
    if not D or type(D.GetCombatSessionFromType) ~= "function" then return end
    local ok, s = pcall(D.GetCombatSessionFromType, currentSession(), enumType(tyName))
    note(ctx, "struct." .. tyName .. ".session", s)
    if not ok or code(s) == "S" then return end
    local srcs = field(s, "combatSources")
    note(ctx, "struct." .. tyName .. ".nSources", lenClear(srcs) or srcs)
    local src = first(srcs)
    if not isNil(src) and code(src) ~= "S" then
        local spells = field(src, "combatSpells")
        note(ctx, "struct." .. tyName .. ".nSpells", lenClear(spells) or spells)
        local sp = first(spells)
        if not isNil(sp) and code(sp) ~= "S" then
            note(ctx, "struct." .. tyName .. ".spellID", field(sp, "spellID"))
            note(ctx, "struct." .. tyName .. ".nDetails", lenClear(field(sp, "combatSpellDetails")))
        end
    end
end

function DM.Classify(ctx)
    local D = api()
    if not D then return false end
    local cur = currentSession()
    -- v2.2.7: was `type(..) == "function" and select(2, pcall(..)) or nil` -> truth-tested a possibly secret boolean
    if type(D.IsDamageMeterAvailable) == "function" then
        local okA, avail = pcall(D.IsDamageMeterAvailable)
        if okA then note(ctx, "IsDamageMeterAvailable", avail) else note(ctx, "IsDamageMeterAvailable", nil) end
    else note(ctx, "IsDamageMeterAvailable", nil) end
    if type(D.GetSessionDurationSeconds) == "function" then
        local okD, dur = pcall(D.GetSessionDurationSeconds, cur)
        if okD then note(ctx, "GetSessionDurationSeconds", dur) else note(ctx, "GetSessionDurationSeconds", nil) end
    end
    if type(D.GetAvailableCombatSessions) == "function" then
        local ok, list = pcall(D.GetAvailableCombatSessions)
        if ok then
            note(ctx, "GetAvailableCombatSessions", list)
            note(ctx, "nAvailableSessions", lenClear(list))
            local s1 = first(list)
            if not isNil(s1) and code(s1) ~= "S" then
                for _, f in ipairs({ "sessionID", "name", "durationSeconds" }) do note(ctx, "AvailableCombatSession." .. f, field(s1, f)) end
            end
        else note(ctx, "error:GetAvailableCombatSessions", true) end
    end
    if type(D.GetCombatSessionFromType) == "function" then
        local ok, s = pcall(D.GetCombatSessionFromType, cur, enumType("DamageDone"))
        if ok then
            note(ctx, "GetCombatSessionFromType", s)
            if code(s) ~= "S" then
                classifyStruct(ctx, "CombatSession", s, SESSION_FIELDS)
                local src = first(field(s, "combatSources"))
                if not isNil(src) and code(src) ~= "S" then classifyStruct(ctx, "CombatSource", src, SOURCE_FIELDS) end
            end
        else note(ctx, "error:GetCombatSessionFromType", true) end
    end
    local guid = myGUID()
    if guid and type(D.GetCombatSessionSourceFromType) == "function" then
        local ok, s = pcall(D.GetCombatSessionSourceFromType, cur, enumType("DamageDone"), guid)
        if ok then
            note(ctx, "GetCombatSessionSourceFromType", s)
            if code(s) ~= "S" then
                note(ctx, "CombatSessionSource.totalAmount", field(s, "totalAmount"))
                note(ctx, "CombatSessionSource.combatSpells", field(s, "combatSpells"))
                local sp = first(field(s, "combatSpells"))
                if not isNil(sp) and code(sp) ~= "S" then
                    classifyStruct(ctx, "CombatSpell", sp, SPELL_FIELDS)
                    local det = first(field(sp, "combatSpellDetails"))
                    if not isNil(det) and code(det) ~= "S" then classifyStruct(ctx, "CombatSpellUnitDetails", det, DETAIL_FIELDS) end
                end
            end
        else note(ctx, "error:GetCombatSessionSourceFromType", true) end
    end
    return true
end

local function scrubDetail(det)
    local unitName = clearStr(field(det, "unitName"))
    local class = clearStr(field(det, "unitClassFilename"))
    local amt = clearNum(field(det, "amount"))
    local isPet, isMob = clearBool(field(det, "isPet")), clearBool(field(det, "isMob"))
    local out = { class = class, isPet = isPet, isMob = isMob, amount = amt, classification = clearStr(field(det, "classification")) }
    if unitName then
        out.unitName = unitName                    -- v2.2.21 raw, as read
        out.unitKey = idKey("name", unitName)
    end
    return out
end

local function scrubSpell(sp, maxDetails)
    local id, amt = clearNum(field(sp, "spellID")), clearNum(field(sp, "totalAmount"))
    if not id then return nil end
    local row = {
        spell = id, amount = amt, aps = clearNum(field(sp, "amountPerSecond")),
        overkill = clearNum(field(sp, "overkillAmount")),
        avoidable = clearBool(field(sp, "isAvoidable")), deadly = clearBool(field(sp, "isDeadly")),
    }
    local cname = clearStr(field(sp, "creatureName"))
    if cname then row.creatureName, row.creatureKey = cname, idKey("name", cname) end   -- v2.2.21 raw name too
    local dets = field(sp, "combatSpellDetails")
    if type(dets) == "table" and code(dets) ~= "S" then
        row.targets = {}
        for i = 1, (maxDetails or 40) do
            local det = field(dets, i)
            if isNil(det) then break end
            if code(det) ~= "S" then row.targets[#row.targets + 1] = scrubDetail(det) end
        end
        if #row.targets == 0 then row.targets = nil end
    end
    return row
end

local function scrubSource(src, maxSpells, maxDetails)
    local guid = clearStr(field(src, "sourceGUID"))
    local kind = sourceKind(guid)
    local cid = clearNum(field(src, "sourceCreatureID"))
    local isMe = clearBool(field(src, "isLocalPlayer"))
    local row = {
        id = (isMe == true and "player")
            or (kind == "Creature" and cid and ("npc:" .. cid))
            or (guid and idKey(kind == "Player" and "player" or (kind or "guid"):lower(), guid))
            or nil,
        kind = kind, class = clearStr(field(src, "classFilename")), creatureID = cid,
        isLocalPlayer = isMe, total = clearNum(field(src, "totalAmount")),
        aps = clearNum(field(src, "amountPerSecond")),
        deathRecapID = clearNum(field(src, "deathRecapID")),
        deathTime = clearNum(field(src, "deathTimeSeconds")),
        classification = clearStr(field(src, "classification")),
        displayType = clearNum(field(src, "sourceDisplayType")),
        -- v2.2.21: raw GUID + raw name (as read) are the identity; nameKey (name:<base name>) is a derived join helper
        -- for plate / scoreboard units (realm-stripped)
        guid = guid, name = clearStr(field(src, "name")),
        nameKey = idKey("name", baseName(field(src, "name"))),
        nameCode = code(field(src, "name")), guidCode = code(field(src, "sourceGUID")),
    }
    local spells = field(src, "combatSpells")
    if type(spells) == "table" and code(spells) ~= "S" then
        row.spells = {}
        for i = 1, (maxSpells or 80) do
            local sp = field(spells, i)
            if isNil(sp) then break end
            if code(sp) ~= "S" then
                local sr = scrubSpell(sp, maxDetails)
                if sr then row.spells[#row.spells + 1] = sr end
            end
        end
        if #row.spells == 0 then row.spells = nil end
    end
    return row
end

-- light release read: me vs others totals, no full source list
local function readTypeLight(D, cur, name)
    local ok, s = pcall(D.GetCombatSessionFromType, cur, enumType(name))
    if not ok then return { err = true } end
    if code(s) == "S" then return { secret = true } end
    local r = { total = clearNum(field(s, "totalAmount")), dur = clearNum(field(s, "durationSeconds")), me = 0, others = 0, n = 0, kinds = {} }
    local list = field(s, "combatSources")
    if type(list) == "table" and code(list) ~= "S" then
        for i = 1, 40 do
            local src = field(list, i)
            if isNil(src) then break end
            local amt = clearNum(field(src, "totalAmount"))
            -- v2.2.7: was `isMe == true` on the raw field (a compare on a possibly secret boolean)
            local isMe = isTrue(field(src, "isLocalPlayer"))
            r.n = r.n + 1
            if amt then
                if isMe then r.me = r.me + amt else r.others = r.others + amt end
            else r.secretAmounts = (r.secretAmounts or 0) + 1 end
            local k = sourceKind(field(src, "sourceGUID")) or ((clearNum(field(src, "sourceCreatureID")) and "Creature") or "?")
            r.kinds[k] = (r.kinds[k] or 0) + 1
        end
    end
    return r
end

local function readTypeDeep(D, cur, name)
    local ok, s = pcall(D.GetCombatSessionFromType, cur, enumType(name))
    if not ok then return { err = true } end
    if code(s) == "S" then return { secret = true } end
    local maxSrc = tonumber(cfg().maxSources) or 200
    local maxSp = tonumber(cfg().maxSpells) or 80
    local maxDet = tonumber(cfg().maxDetails) or 40
    local r = {
        total = clearNum(field(s, "totalAmount")), max = clearNum(field(s, "maxAmount")),
        dur = clearNum(field(s, "durationSeconds")), me = 0, others = 0, n = 0, kinds = {}, sources = {},
    }
    local list = field(s, "combatSources")
    if type(list) == "table" and code(list) ~= "S" then
        for i = 1, maxSrc do
            local src = field(list, i)
            if isNil(src) then break end
            if code(src) == "S" then r.secretSources = (r.secretSources or 0) + 1
            else
                local row = scrubSource(src, maxSp, maxDet)
                r.n = r.n + 1
                if row.total then
                    if row.isLocalPlayer == true then r.me = r.me + row.total else r.others = r.others + row.total end
                else r.secretAmounts = (r.secretAmounts or 0) + 1 end
                if row.kind then r.kinds[row.kind] = (r.kinds[row.kind] or 0) + 1 end
                r.sources[#r.sources + 1] = row
            end
        end
    end
    if #r.sources == 0 then r.sources = nil end
    return r
end

local function readSpellsMine(D, cur, name, guid)
    local ok, s = pcall(D.GetCombatSessionSourceFromType, cur, enumType(name), guid)
    if not ok or code(s) == "S" then return nil end
    local list = field(s, "combatSpells")
    if type(list) ~= "table" or code(list) == "S" then return nil end
    local out, n = {}, 0
    for i = 1, (tonumber(cfg().maxSpells) or 80) do
        local sp = field(list, i)
        if isNil(sp) then break end
        local id, amt = clearNum(field(sp, "spellID")), clearNum(field(sp, "totalAmount"))
        if id and amt then
            n = n + 1
            out[id] = { amount = amt, overkill = clearNum(field(sp, "overkillAmount")) }
        end
    end
    if n == 0 then return nil end
    return out
end

local function readSessionHistory(D)
    if type(D.GetAvailableCombatSessions) ~= "function" then return nil end
    local ok, list = pcall(D.GetAvailableCombatSessions)
    if not ok or type(list) ~= "table" or code(list) == "S" then return nil end
    local out = {}
    for i = 1, 30 do
        local s = field(list, i)
        if isNil(s) then break end
        if code(s) ~= "S" then
            local rawName = field(s, "name")
            local name = clearStr(rawName)
            out[#out + 1] = {
                id = clearNum(field(s, "sessionID")),
                dur = clearNum(field(s, "durationSeconds")),
                name = name,   -- v2.2.21 raw
                nameCode = code(rawName),
                nameKey = name and idKey("session", name) or nil,
            }
            if type(D.GetCombatSessionFromID) == "function" and out[#out].id then
                local ok2, full = pcall(D.GetCombatSessionFromID, out[#out].id, enumType("DamageDone"))
                if ok2 and code(full) ~= "S" then
                    out[#out].total = clearNum(field(full, "totalAmount"))
                    out[#out].nSources = lenClear(field(full, "combatSources"))
                end
            end
        end
    end
    if #out == 0 then return nil end
    return out
end

function DM.ReadClear(reason)
    local D = api()
    local d = db()
    if not (D and d) then return nil end
    if ns.InCombat() then return nil end
    local cur = currentSession()
    local deep = capture() and cfg().deepRead ~= false
    local rec = {
        reason = reason, t = now(), epoch = g("time") and time() or nil, sid = d.sid,
        deep = deep or nil, types = {}, v = 2,
    }
    if type(D.GetCombatSessionFromType) == "function" then
        local names = deep and DM.ALL or DM.READ
        for _, name in ipairs(names) do
            rec.types[name] = deep and readTypeDeep(D, cur, name) or readTypeLight(D, cur, name)
        end
    end
    local guid = myGUID()
    if guid and type(D.GetCombatSessionSourceFromType) == "function" then
        rec.spells = readSpellsMine(D, cur, "DamageDone", guid)
        rec.healSpells = readSpellsMine(D, cur, "HealingDone", guid)
        if deep then
            rec.takenSpells = readSpellsMine(D, cur, "DamageTaken", guid)
            rec.interruptSpells = readSpellsMine(D, cur, "Interrupts", guid)
            rec.dispelSpells = readSpellsMine(D, cur, "Dispels", guid)
        end
    end
    if deep then rec.sessions = readSessionHistory(D) end
    DM.Classify("after-combat")
    d.fights = d.fights or {}
    d.fights[#d.fights + 1] = rec
    while #d.fights > (tonumber(cfg().maxFights) or 20) do table.remove(d.fights, 1) end
    DM.last = rec
    local hs = ns.Inference and ns.Inference.hs
    if hs and hs.ReconcileDM then
        local spells
        if rec.spells then spells = {} for id, v in pairs(rec.spells) do spells[id] = v.amount end end
        local dd, hd, it = rec.types.DamageDone, rec.types.HealingDone, rec.types.Interrupts
        local dt, dp = rec.types.DamageTaken, rec.types.Dispels
        -- per-type source lists (IdKey'd) for world-unit reconcile when deep capture read ran
        local sources
        if deep then
            sources = {}
            for _, name in ipairs(DM.ALL) do
                local ty = rec.types[name]
                if ty and ty.sources then sources[name] = ty.sources end
            end
            if not next(sources) then sources = nil end
        end
        hs:ReconcileDM({
            damage = dd and dd.me, others = dd and dd.others, healing = hd and hd.me,
            interrupts = it and it.me, dispels = dp and dp.me, taken = dt and dt.me,
            spells = spells, takenSpells = rec.takenSpells, interruptSpells = rec.interruptSpells,
            dispelSpells = rec.dispelSpells, duration = dd and dd.dur, deep = deep,
            sources = sources,
            enemyTaken = rec.types.EnemyDamageTaken and rec.types.EnemyDamageTaken.sources or nil,
        })
    end
    if ns.HSMUI and ns.HSMUI.MarkDirty then ns.HSMUI.MarkDirty() end
    return rec
end

----------------------------------------------------------------------------
-- events
----------------------------------------------------------------------------
local frame
local probedCombat, inCombatSince = false, nil
local lastClassify = {}  -- [type] = GetTime

local function deferredClassify()
    if not DM.running then return end
    local ctx = (ns.CombatProbe and ns.CombatProbe.Context and ns.CombatProbe.Context()) or (ns.InCombat() and "combat" or "ooc")
    DM.Classify(ctx)
end

-- v2.2.15: the structure read is coalesced and deferred: the event only marks its type dirty; one C_Timer job per
-- frame classifies ONE dirty type (Perf "DamageMeter.struct") and re-arms itself while others are dirty. The event
-- handler itself stays O(1) and allocation-free on this path (run-8 BG replay: it was the most frequent allocating
-- handler, so it absorbed most incremental-GC steps).
local structDirty, structDirtyN, structPending = {}, 0, false
local EVKEY = {}
local TYPE_NAME = {}
for n, v in pairs(DM.TYPES) do TYPE_NAME[v] = n end
local function structJob()
    structPending = false
    local ty = next(structDirty)
    if ty == nil then return end
    structDirty[ty] = nil
    structDirtyN = structDirtyN - 1
    local name = TYPE_NAME[ty]
    if name and capture() then classifyStructure("combat-struct", name) end
    if structDirtyN > 0 and type(g("C_Timer")) == "table" then
        structPending = true
        C_Timer.After(0, function()
            if ns.Perf then ns.Perf.Run("DamageMeter.struct", structJob) else pcall(structJob) end
        end)
    end
end
local function throttledStruct(ty)
    if not capture() or ty == nil then return end
    local hz = tonumber(cfg().classifyHz) or 2
    local t = now()
    local last = lastClassify[ty]
    if last and (t - last) < (1 / math.max(0.5, hz)) then return end
    lastClassify[ty] = t
    if not structDirty[ty] then structDirty[ty] = true structDirtyN = structDirtyN + 1 end
    if structPending or type(g("C_Timer")) ~= "table" then return end
    structPending = true
    C_Timer.After(0, function()
        if ns.Perf then ns.Perf.Run("DamageMeter.struct", structJob) else pcall(structJob) end
    end)
end

-- v2.2.18 class engine: every source row of one meter type right now (both teams in a BG): class (always clear),
-- name key / GUID key when clear, display type, local flag. No amounts. -> list or nil
function DM.Roster(tyName, maxSrc)
    local D = api()
    if not (D and type(D.GetCombatSessionFromType) == "function") then return nil end
    local ok, s = pcall(D.GetCombatSessionFromType, currentSession(), enumType(tyName or "DamageDone"))
    if not ok or code(s) == "S" then return nil end
    local list = field(s, "combatSources")
    if type(list) ~= "table" or code(list) == "S" then return nil end
    local out = {}
    for i = 1, (maxSrc or 80) do
        local src = field(list, i)
        if isNil(src) then break end
        if code(src) ~= "S" then
            local guid = clearStr(field(src, "sourceGUID"))
            local kind = sourceKind(guid)
            out[#out + 1] = {
                class = clearStr(field(src, "classFilename")), displayType = clearNum(field(src, "sourceDisplayType")),
                isLocal = isTrue(field(src, "isLocalPlayer")), kind = kind,
                guidKey = guid and idKey(kind == "Player" and "player" or "guid", guid) or nil,
                name = clearStr(field(src, "name")),   -- v2.2.21 raw
                nameKey = idKey("name", baseName(field(src, "name"))),
                nameCode = code(field(src, "name")), guidCode = code(field(src, "sourceGUID")),
                creatureID = clearNum(field(src, "sourceCreatureID")), guid = guid,   -- v2.2.21 raw GUID (stored)
            }
        end
    end
    return out
end

-- v2.2.18: spell ids of one source (clear only; out of combat most are) -> { [spellID] = true } or nil
function DM.SourceSpells(tyName, guid)
    local D = api()
    if not (D and guid and type(D.GetCombatSessionSourceFromType) == "function") then return nil end
    local sp = readSpellsMine(D, currentSession(), tyName or "DamageDone", guid)
    if not sp then return nil end
    local out = {}
    for id in pairs(sp) do out[id] = true end
    return out
end

-- v2.2.15 lab: my per-spell breakdown of one meter type right now (in or out of combat; clear values only, else nil)
-- plus the readability code of the source record. Called throttled from LabProbes at DAMAGE_METER session updates.
function DM.LabSnap(tyName)
    local D = api()
    local guid = myGUID()
    if not (D and guid and type(D.GetCombatSessionSourceFromType) == "function") then return nil end
    local ok, s = pcall(D.GetCombatSessionSourceFromType, currentSession(), enumType(tyName), guid)
    local rec = { c = ok and code(s) or "E" }
    if ok and code(s) ~= "S" then
        rec.total = clearNum(field(s, "totalAmount"))
        rec.spells = readSpellsMine(D, currentSession(), tyName, guid)
    end
    return rec
end

function DM.OnEvent(event, a1, a2)
    local d = db()
    if not d then return end
    if event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
        local ty = clearNum(a1)
        local sid = clearNum(a2)
        d.events = d.events or {}
        local k = ty and (EVKEY[ty] or tostring(ty)) or "?"   -- v2.2.15: cached keys (no string per event)
        if ty and not EVKEY[ty] then EVKEY[ty] = k end
        d.events[k] = (d.events[k] or 0) + 1
        local c1, c2 = code(a1), code(a2)
        if c1 ~= "C" or c2 ~= "C" then d.secretArgs = (d.secretArgs or 0) + 1 end
        if ns.ReplayLog and ns.ReplayLog.OnDmUpdate then
            ns.ReplayLog.OnDmUpdate(ty, sid, { c1, c2 })
        end
        local hs = ns.Inference and ns.Inference.hs
        if hs and hs.OnDamageMeter and ty then hs:OnDamageMeter(ty) end
        throttledStruct(ty)
        if cfg().probe ~= false and not probedCombat and inCombatSince and now() - inCombatSince >= 1 then
            probedCombat = true
            if type(g("C_Timer")) == "table" then C_Timer.After(0, deferredClassify) end
        end
    elseif event == "DAMAGE_METER_CURRENT_SESSION_UPDATED" or event == "DAMAGE_METER_RESET" then
        d.events = d.events or {}
        d.events[event] = (d.events[event] or 0) + 1
        if ns.ReplayLog and ns.ReplayLog.OnDmUpdate then
            ns.ReplayLog.OnDmUpdate(event == "DAMAGE_METER_RESET" and -1 or -2, nil, { code(a1) })
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        probedCombat, inCombatSince, lastClassify = false, now(), {}
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombatSince = nil
        if type(g("C_Timer")) == "table" then C_Timer.After(0.5, function() if DM.running then DM.ReadClear("regen") end end) end
    end
end

function DM.Start()
    if cfg().enabled == false then return false end
    local d = db()
    if not d then return false end
    for k in pairs(d) do if k ~= "v" and k ~= "fights" then d[k] = nil end end
    d.sid = ns.SessionId and ns.SessionId() or nil
    d.v = 2
    local D = api()
    if not D then d.unavailable = "C_DamageMeter missing" return false end
    d.functions = {}
    for _, f in ipairs({ "GetAvailableCombatSessions", "GetCombatSessionFromID", "GetCombatSessionFromType", "GetCombatSessionSourceFromID",
        "GetCombatSessionSourceFromType", "GetSessionDurationSeconds", "IsDamageMeterAvailable", "ResetAllCombatSessions" }) do
        d.functions[f] = type(D[f]) == "function"
    end
    if not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", function(_, event, ...)
            local ok, err
            if ns.Perf then ok, err = ns.Perf.Run(ns.Perf.Key("DamageMeter", event), DM.OnEvent, event, ...)
            else ok, err = pcall(DM.OnEvent, event, ...) end
            if not ok then ns.NoteSelfError("DamageMeter." .. event, err) end
        end)
    end
    for _, ev in ipairs({ "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED", "DAMAGE_METER_RESET",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
        local ok = pcall(frame.RegisterEvent, frame, ev)
        if not ok then d.registerFailed = d.registerFailed or {} d.registerFailed[ev] = true end
    end
    DM.running = true
    probedCombat, inCombatSince = false, ns.InCombat() and now() or nil
    DM.Classify(ns.InCombat() and "combat" or "ooc")
    return true
end

function DM.Stop()
    DM.running = false
    if frame then pcall(frame.UnregisterAllEvents, frame) end
    -- final clear read if out of combat (capture stop)
    if not ns.InCombat() then pcall(DM.ReadClear, "capture:off") end
    local d = db()
    return d and d.fights and #d.fights or 0
end

ns.captureModules = ns.captureModules or {}
ns.captureModules[#ns.captureModules + 1] = { name = "damage meter evidence (C_DamageMeter)",
    start = function() return DM.Start() end,
    stop = function() local n = DM.Stop() return string.format("DamageMeter %d post-combat read(s)", n) end }
