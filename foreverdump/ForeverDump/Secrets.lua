-- ForeverDump v2.2 - secrets map + live VERIFIER (runtime side). Everything persists in ForeverDumpDB:
--  secretsObs[kind..":"..name] = { [pos] = { oN, oS, cN, cS, eN, eS },          -- seen/secret out of combat / combat / encounter
--                                  x = { [pos] = { [ctx] = { n, s, inaccessible } } } }
--     ctx = "<ooc|combat|enc>/<instanceType>/<self|other|none>", at most secrets.maxCtx per position.
--     kind: event (every event the recorder / combat recorder sees, tallied live with issecretvalue and
--     canaccessvalue before any throttling), api (probe calls, sweep calls, C_CombatText getter), field (struct fields).
--  secretsObs._sessions[sid] = { anchor, endAnchor, sweepCalls, events }   -- per capture session timebase
--  secretsLive = { contradictions = { {key, pos, doc, observed, ctx, sid, t, epoch, count} ... }, recent = {...} }
--     contradictions are detected in real time against the documented class from ForeverDumpDocsDB:
--     documented never-secret but observed secret, documented always-secret but observed clear,
--     undocumented (no annotation) but observed secret.
--  Getter sweep (FD_Logs, or /fdump secrets sweep on): documented conditionally/always-secret getters that take no
--     arguments or just a unit token are called with "player" (and "target" when it exists) on a throttled timer.
--  section "secrets": secret-related API presence + current restriction state; /fdump secrets: live panel.
local _, ns = ...
local Secrets = {}
ns.Secrets = Secrets

local inEncounter = false
local instanceType = "none"
local function updateInstance()
    local f = rawget(_G, "IsInInstance")
    if type(f) == "function" then
        local ok, inside, kind = pcall(f)
        if ok and not ns.IsSecret(kind) then instanceType = (inside and type(kind) == "string") and kind or "none" end
    end
end
ns.On("ENCOUNTER_START", function() inEncounter = true end)
ns.On("ENCOUNTER_END", function() inEncounter = false end)
ns.On("PLAYER_ENTERING_WORLD", function() inEncounter = false updateInstance() end)
ns.On("ZONE_CHANGED_NEW_AREA", updateInstance)
function Secrets.InEncounter() return inEncounter end

local MAX_POS = 24
local function scfg() return (ns.config and ns.config.secrets) or ns.defaults.secrets end

local UNIT_PATTERNS = { "^player$", "^pet$", "^vehicle$", "^target", "^focus", "^mouseover", "^party%d", "^raid%d",
    "^nameplate%d", "^boss%d", "^arena%d", "^softenemy", "^softfriend", "^softinteract", "^none$", "^npc$" }
local function unitClass(v)
    if type(v) ~= "string" or ns.IsSecret(v) then return "none" end
    if v == "player" or v == "vehicle" then return "self" end
    for _, p in ipairs(UNIT_PATTERNS) do if string.find(v, p) then return "other" end end
    return "none"
end
Secrets.UnitClass = unitClass

local function slotAndState()
    if inEncounter then return 5, "enc" end
    if ns.InCombat() then return 3, "combat" end
    return 1, "ooc"
end

-- documented class lookup (built lazily from ForeverDumpDocsDB): docClass["api:Name"] = { [pos] = class }
local docClass
local function classOf(node, parent)
    if node.SecretValue then return "always" end
    if node.NeverSecret then return "never" end
    if node.ConditionalSecret or node.ConditionalSecretContents then return "conditional" end
    return parent
end
local function parentClass(node)
    if node.SecretReturns or node.SecretValue or node.SecretPayloads then return "always" end
    for k, v in pairs(node) do
        if v and type(k) == "string" and (string.find(k, "^SecretWhen") or string.find(k, "^SecretIn")) then return "conditional" end
    end
    if node.SecretReturnsForAspect or node.ConstSecretAccessor then return "conditional" end
    if node.ReturnsNeverSecret then return "never" end
    return "unspecified"
end
Secrets.ParentClass = parentClass

local function condTag(node)
    for k, v in pairs(node) do
        if v and type(k) == "string" and (string.find(k, "^SecretWhen") or string.find(k, "^SecretIn") or string.find(k, "^SecretOn")) then
            return k
        end
    end
end
local function fieldMap(structs, typeName, pc)
    local st = structs[typeName]
    if not st then return nil end
    local out = {}
    for _, f in ipairs(st) do
        if type(f.Name) == "string" then out[f.Name] = classOf(f, pc) end
    end
    return out
end
local function buildDocClass()
    docClass = {}
    local docs = rawget(_G, "ForeverDumpDocsDB")
    if type(docs) ~= "table" or type(docs.systems) ~= "table" then return docClass end
    local structs = {}
    for _, t in ipairs(docs.sharedTables or {}) do
        if type(t) == "table" and t.Type == "Structure" and type(t.Name) == "string" then structs[t.Name] = t.Fields or {} end
    end
    for _, sys in ipairs(docs.systems) do
        for _, t in ipairs(sys.Tables or {}) do
            if type(t) == "table" and t.Type == "Structure" and type(t.Name) == "string" then structs[t.Name] = t.Fields or {} end
        end
    end
    for _, sys in ipairs(docs.systems) do
        if sys.Type ~= "ScriptObject" then
            for _, f in ipairs(sys.Functions or {}) do
                if type(f.Name) == "string" then
                    local pc, row = parentClass(f), {}
                    row.fields = {}
                    for i, r in ipairs(f.Returns or {}) do
                        row[i] = classOf(r, pc)
                        -- function-level SecretWhen* applies to every struct field not marked NeverSecret
                        row.fields[i] = fieldMap(structs, r.Type, classOf(r, pc))
                    end
                    row.parent, row.tag, row.n = pc, condTag(f), #(f.Returns or {})
                    row.nothing = f.MayReturnNothing or nil
                    docClass["api:" .. (sys.Namespace and (sys.Namespace .. "." .. f.Name) or f.Name)] = row
                end
            end
        end
        for _, e in ipairs(sys.Events or {}) do
            if type(e.LiteralName) == "string" then
                local pc, row = parentClass(e), {}
                for i, p in ipairs(e.Payload or {}) do row[i] = classOf(p, pc) end
                row.parent, row.tag, row.n = pc, condTag(e), #(e.Payload or {})
                docClass["event:" .. e.LiteralName] = row
            end
        end
    end
    return docClass
end
function Secrets.DocClass(key, pos)
    local row = (docClass or buildDocClass())[key]
    if not row then return nil end
    return row[pos] or row.parent
end
function Secrets.DocRow(key) return (docClass or buildDocClass())[key] end
-- struct field class: NeverSecret -> never; else the function's class (SecretWhen* propagated)
function Secrets.DocFieldClass(key, pos, field)
    local row = (docClass or buildDocClass())[key]
    if not row then return nil end
    local fm = row.fields and row.fields[pos]
    if fm and fm[field] then return fm[field] end
    return row[pos] or row.parent
end
function Secrets.ResetDocClass() docClass = nil end

----------------------------------------------------------------------------
-- same-frame predicates: tag -> C_Secrets.Should*BeSecret (called with the same args the API got, then no args)
----------------------------------------------------------------------------
local PRED = {
    SecretWhenCooldownsRestricted = { "ShouldSpellCooldownBeSecret", "ShouldCooldownsBeSecret" },
    SecretWhenAurasRestricted = { "ShouldAurasBeSecret" },
    SecretWhenUnitAuraRestricted = { "ShouldUnitAuraIndexBeSecret", "ShouldAurasBeSecret" },
    SecretWhenUnitStatsRestricted = { "ShouldUnitStatsBeSecret" },
    SecretWhenUnitPowerRestricted = { "ShouldUnitPowerBeSecret" },
    SecretWhenUnitPowerMaxRestricted = { "ShouldUnitPowerMaxBeSecret" },
    SecretWhenUnitHealthMaxRestricted = { "ShouldUnitHealthMaxBeSecret" },
    SecretWhenUnitIdentityRestricted = { "ShouldUnitIdentityBeSecret" },
    SecretWhenUnitNameIdentityRestricted = { "ShouldUnitIdentityBeSecret" },
    SecretWhenUnitComparisonRestricted = { "ShouldUnitComparisonBeSecret" },
    SecretWhenUnitSpellCastRestricted = { "ShouldUnitSpellCastBeSecret", "ShouldUnitSpellCastingBeSecret" },
    SecretWhenUnitThreatStateRestricted = { "ShouldUnitThreatStateBeSecret" },
    SecretWhenUnitThreatValuesRestricted = { "ShouldUnitThreatValuesBeSecret" },
    SecretWhenTotemSlotSecret = { "ShouldTotemSlotBeSecret" },
}
local RESTRICTION_PRED = { SecretInChatMessagingLockdown = 5, SecretInActivePvPMatch = 3, SecretOnRestrictedMaps = 4 }
Secrets.PRED = PRED

-- returns predicate (true/false) and its name, or nil when it can't be evaluated
function Secrets.Predicate(tag, args)
    if type(tag) ~= "string" then return nil end
    if tag == "SecretWhenInCombat" then return ns.InCombat(), "InCombatLockdown" end
    local rt = RESTRICTION_PRED[tag]
    if rt then
        local cra = rawget(_G, "C_RestrictedActions")
        if type(cra) == "table" and type(cra.GetAddOnRestrictionState) == "function" then
            local ok, st = pcall(cra.GetAddOnRestrictionState, rt)
            if ok and not ns.IsSecret(st) then return st == 2, "GetAddOnRestrictionState(" .. rt .. ")" end
        end
        return nil
    end
    local list = PRED[tag]
    local cs = rawget(_G, "C_Secrets")
    if not list or type(cs) ~= "table" then return nil end
    for _, name in ipairs(list) do
        local fn = cs[name]
        if type(fn) == "function" then
            local ok, v
            if args and args.n and args.n > 0 then ok, v = pcall(fn, unpack(args, 1, args.n)) end
            if not ok or type(v) ~= "boolean" then ok, v = pcall(fn) end
            if ok and type(v) == "boolean" and not ns.IsSecret(v) then return v, name end
        end
    end
    return nil
end

local function obsDB()
    local db = ns.db
    if not db then return nil end
    local obs = db.secretsObs
    if type(obs) ~= "table" then obs = { _keys = 0 } db.secretsObs = obs end
    return obs
end

local liveIndex -- id -> contradiction (rebuilt from the persisted list; not saved twice)
local function liveDB()
    local l = ns.db.secretsLive
    if type(l) ~= "table" then l = { contradictions = {}, recent = {} } ns.db.secretsLive = l liveIndex = nil end
    l.contradictions = l.contradictions or {}
    l.recent = l.recent or {}
    l.index = nil
    if not liveIndex then
        liveIndex = {}
        for _, c in ipairs(l.contradictions) do
            liveIndex[tostring(c.key) .. "#" .. tostring(c.pos) .. "#" .. tostring(c.observed) .. "#" .. tostring(c.ctx)] = c
        end
    end
    return l
end
function Secrets.ResetLive() liveIndex = nil end

local function contradiction(key, pos, doc, observed, ctx)
    local l = liveDB()
    local id = key .. "#" .. pos .. "#" .. observed .. "#" .. ctx
    local c = liveIndex[id]
    if c then c.count = c.count + 1 c.lastT = GetTime() return end
    if #l.contradictions >= (tonumber(scfg().maxLive) or 200) then l.dropped = (l.dropped or 0) + 1 return end
    c = ns.Stamp({ key = key, pos = pos, doc = doc, observed = observed, ctx = ctx, count = 1 })
    l.contradictions[#l.contradictions + 1] = c
    liveIndex[id] = c
end

-- core tally (v2.2). o = { states = { [pos] = "N"|"S"|"T"|"K"|"C" }, inacc = { [pos] = true }, pred = bool|nil,
-- predName = string, docKey = "api:X" (field rows: doc lookup through the parent), field = "name", fieldPos = n }
-- Only present values (S/T/K/C) enter the seen/secret counters; nil -> row.nl, absent -> row.ab, containers -> row.ct.
-- v2.2.22 (audit): "T" (container with SOME secret contents) is not a secret value: it is counted separately in
-- row.ct (containers / with secret contents) and its fields are classified where they are read. Counting T as secret
-- made whole structs look secret in the observation rows / guide.
local CODE_SECRET = { S = true }
local function bump(t, pos) t[pos] = (t[pos] or 0) + 1 end
local keyMemo, keyMemoN = {}, 0
local ctxMemo = {}
local function ctxKey(state, it, uc)
    local a = ctxMemo[state]
    if not a then a = {} ctxMemo[state] = a end
    local b = a[it]
    if not b then b = {} a[it] = b end
    local k = b[uc]
    if not k then k = state .. "/" .. it .. "/" .. uc b[uc] = k end
    return k
end
local function tally(kind, name, n, o, unitArg)
    local cfgS = scfg()
    if cfgS.observe == false then return end
    local obs = obsDB()
    if not obs or type(name) ~= "string" then return end
    local km = keyMemo[kind]
    if not km then km = {} keyMemo[kind] = km end
    local key = km[name]
    if not key then key = kind .. ":" .. name km[name] = key keyMemoN = keyMemoN + 1 if keyMemoN > 8192 then keyMemo, keyMemoN = {}, 0 end end
    local row = obs[key]
    if not row then
        if (obs._keys or 0) >= (tonumber(cfgS.maxKeys) or 4000) then obs._dropped = (obs._dropped or 0) + 1 return end
        row = {}
        obs[key] = row
        obs._keys = (obs._keys or 0) + 1
    end
    local slot, state = slotAndState()
    local ctx = ctxKey(state, instanceType, unitClass(unitArg))   -- memoised (no string build per event)
    n = math.min(tonumber(n) or 0, MAX_POS)
    local states = o.states or {}
    local docRow = (kind == "api" or kind == "event") and Secrets.DocRow(key) or nil
    -- absent: documented return slots the call did not produce (MayReturnNothing / variadic)
    if docRow and docRow.n and docRow.n > n then
        row.ab = row.ab or {}
        for pos = n + 1, math.min(docRow.n, MAX_POS) do
            bump(row.ab, pos)
            if not row[pos] then row[pos] = { 0, 0, 0, 0, 0, 0 } end
        end
    end
    if n == 0 and not (docRow and docRow.n and docRow.n > 0) then n = 1 states[1] = states[1] or "N" end
    for pos = 1, n do if not row[pos] then row[pos] = { 0, 0, 0, 0, 0, 0 } end end  -- keep the array dense
    row.x = row.x or {}
    local maxCtx = tonumber(cfgS.maxCtx) or 16
    local anySecret, secretPos = false, nil
    if o.predName then row.pn = o.predName end
    for pos = 1, n do
        local code = states[pos] or "C"
        if code == "N" then
            row.nl = row.nl or {}
            bump(row.nl, pos)
        else
            local c = row[pos]
            local sec = CODE_SECRET[code] == true
            c[slot] = c[slot] + 1
            if sec then c[slot + 1] = c[slot + 1] + 1 end
            if code == "T" or code == "K" then
                row.ct = row.ct or {}
                local ct = row.ct[pos] or { 0, 0 }
                row.ct[pos] = ct
                ct[1] = ct[1] + 1
                if code == "T" then ct[2] = ct[2] + 1 end
            end
            if o.pred ~= nil then
                row.pv = row.pv or {}
                local pv = row.pv[pos] or { 0, 0, 0, 0 }   -- predTrue: secret, clear | predFalse: secret, clear
                row.pv[pos] = pv
                local i = (o.pred and 1 or 3) + (sec and 0 or 1)
                pv[i] = pv[i] + 1
            end
            local xp = row.x[pos]
            if not xp then xp = { _n = 0 } row.x[pos] = xp end
            local b = xp[ctx]
            if not b and xp._n < maxCtx then b = { 0, 0, 0 } xp[ctx] = b xp._n = xp._n + 1 end
            if b then
                b[1] = b[1] + 1
                if sec then b[2] = b[2] + 1 end
                if o.inacc and o.inacc[pos] then b[3] = b[3] + 1 end
            end
            -- live contradictions, v2.2 rules
            local doc
            if kind == "field" and o.docKey then doc = Secrets.DocFieldClass(o.docKey, o.fieldPos or 1, o.field)
            elseif docRow then doc = docRow[pos] or docRow.parent end
            if doc then
                if sec and doc == "never" then
                    contradiction(key, pos, doc, "secret", ctx)
                elseif sec and doc == "unspecified" then
                    contradiction(key, pos, doc, "secret", ctx)          -- undocumented secret
                elseif doc == "always" and code == "C" then
                    contradiction(key, pos, doc, "clear", ctx)           -- present scalar; nil/containers excluded
                elseif doc == "conditional" and o.pred ~= nil then
                    if sec and o.pred == false then contradiction(key, pos, doc, "secret-while-predicate-false", ctx)
                    elseif code == "C" and o.pred == true then contradiction(key, pos, doc, "clear-while-predicate-true", ctx) end
                end
            end
            if sec then
                anySecret = true
                secretPos = secretPos and (secretPos .. "," .. pos) or tostring(pos)
            end
        end
    end
    -- recent list for the live panel (bounded)
    if kind == "event" or kind == "api" then
        local l = liveDB()
        local rec = l.recent
        local found
        if rec[1] and rec[1].key == key then found = rec[1]   -- same key as last time (event storms): O(1), no reorder
        else
            for i = 1, #rec do if rec[i].key == key then found = table.remove(rec, i) break end end
            found = found or { key = key, n = 0, s = 0 }
            table.insert(rec, 1, found)
            while #rec > 15 do table.remove(rec) end
        end
        found.n = found.n + 1
        if anySecret then found.s = found.s + 1 found.sp = secretPos end
        found.ctx = ctx
        l.ctx = l.ctx or {}
        local cs = l.ctx[ctx]
        if not cs then
            local nctx = 0
            for _ in pairs(l.ctx) do nctx = nctx + 1 end
            if nctx < 32 then cs = { n = 0, s = 0, ev = 0, api = 0 } l.ctx[ctx] = cs end
        end
        if cs then
            cs.n = cs.n + 1
            if anySecret then cs.s = cs.s + 1 end
            cs[kind == "event" and "ev" or "api"] = cs[kind == "event" and "ev" or "api"] + 1
        end
    end
end
Secrets.Tally = tally

-- live values (event payloads): five-state classification per position
-- scratch tables reused per call (tally reads them, never keeps them): no garbage per observed event
local liveStates, liveObs, liveLim = {}, {}, 0
local liveKeyMemo = {}   -- kind -> name -> "kind:name" (names are event/API names: bounded set)
function ns.ObserveLive(kind, name, ...)
    local n = select("#", ...)
    local states, inacc = liveStates, nil
    local lim = math.min(n, MAX_POS)
    for i = lim + 1, liveLim do states[i] = nil end
    liveLim = lim
    local can = rawget(_G, "canaccessvalue")
    for i = 1, lim do
        local v = select(i, ...)
        local st = ns.ClassifyValue(v)
        states[i] = st
        -- v2.2.10: "C" already passed canaccessvalue inside ClassifyValue (a false there is "S"), so only containers
        -- (T/K: ClassifyValue never asks canaccessvalue) need the second probe; identical result, one pcall less per arg
        if st ~= "S" and st ~= "N" and st ~= "C" and can then
            local ok, r = pcall(can, v)
            if ok and r == false then inacc = inacc or {} inacc[i] = true end
        end
    end
    local pred, predName
    local km = liveKeyMemo[kind]   -- v2.2.10: no key string build per event (hot: every recorded event)
    if not km then km = {} liveKeyMemo[kind] = km end
    local dk = km[name]
    if not dk then dk = kind .. ":" .. tostring(name) km[name] = dk end
    local row = Secrets.DocRow(dk)
    if row and row.tag and (kind == "event") then pred, predName = Secrets.Predicate(row.tag, { n = 1, (select(1, ...)) }) end
    local o = liveObs
    o.states, o.inacc, o.pred, o.predName = states, inacc, pred, predName
    tally(kind, name, n, o, (select(1, ...)))
    o.inacc, o.pred, o.predName = nil, nil, nil
    if n == 0 then states[1] = nil end   -- tally may fill slot 1 with "N" for a no-arg event
    -- v2.2.10: the per-position ClassifyValue codes (reused buffer, valid until the next call) so the recorder doesn't
    -- classify the same arguments twice more (critical-event codes + packArgs). Read-only for callers.
    return states, lim
end

-- pre-computed observations (packed positions list; recorder CLEU): no nil information
function ns.ObserveArgs(kind, name, n, secretPositions, unitArg)
    local states = {}
    for i = 1, math.min(tonumber(n) or 0, MAX_POS) do states[i] = "C" end
    if type(secretPositions) == "table" then for _, p in ipairs(secretPositions) do states[p] = "S" end end
    tally(kind, name, n, { states = states }, unitArg)
end

-- SafeCall result -> observation (+ struct fields, one level). args = { n = k, ... } as passed to the API: the
-- matching C_Secrets.Should*BeSecret predicate is evaluated right here, in the same frame, with the same args.
function Secrets.ObserveResult(path, res, unitArg, args)
    if type(res) ~= "table" or not res.ok then return end
    local key = "api:" .. path
    local states = {}
    for i = 1, math.min(res.n or 0, MAX_POS) do
        local st = res.states and res.states[i]
        if not st then
            local v = res.values and res.values[i]
            if v == nil or v == "<nil>" then st = "N"
            elseif v == ns.SECRET or v == ns.SECRET_TABLE then st = "S"
            else st = "C" end
            for _, p in ipairs(res.secret or {}) do if p == i then st = "S" end end
        end
        states[i] = st
    end
    local row = Secrets.DocRow(key)
    local pred, predName
    if row and row.tag then pred, predName = Secrets.Predicate(row.tag, args or (unitArg and { n = 1, unitArg }) or nil) end
    tally("api", path, res.n, { states = states, pred = pred, predName = predName }, unitArg)
    for i = 1, math.min(res.n or 0, 4) do
        local fs = res.fstates and res.fstates[i]
        if not fs then
            local v = res.values and res.values[i]
            if type(v) == "table" then
                fs = {}
                for k, fv in pairs(v) do
                    if type(k) == "string" then fs[k] = (fv == ns.SECRET or fv == ns.SECRET_TABLE) and "S" or "C" end
                end
            end
        end
        for k, code in pairs(fs or {}) do
            tally("field", path .. "#" .. i .. "." .. k, 1, { states = { code }, pred = pred, predName = predName,
                docKey = key, field = k, fieldPos = i }, unitArg)
        end
    end
end

----------------------------------------------------------------------------
-- getter sweep
----------------------------------------------------------------------------
local SAFE_PREFIX = { "Get", "Is", "Has", "Can", "Should", "Are", "Does", "Unit", "Player" }
local function safeName(name)
    for _, p in ipairs(SAFE_PREFIX) do if string.sub(name, 1, #p) == p then return true end end
    return false
end
local function isUnitArg(a)
    local t, n = tostring(a.Type or ""), string.lower(tostring(a.Name or ""))
    return string.find(t, "UnitToken") or n == "unit" or n == "unittoken" or n == "unitid"
end

function Secrets.SweepCandidates()
    local out = {}
    local docs = rawget(_G, "ForeverDumpDocsDB")
    if type(docs) ~= "table" or type(docs.systems) ~= "table" then return out end
    for _, sys in ipairs(docs.systems) do
        if sys.Type ~= "ScriptObject" then
            for _, f in ipairs(sys.Functions or {}) do
                local name = f.Name
                local ok = type(name) == "string" and safeName(name) and not f.HasRestrictions and not f.IsProtectedFunction
                if ok then
                    for k in pairs(f) do if type(k) == "string" and string.find(k, "^Require") then ok = false break end end
                end
                if ok then
                    local pc = parentClass(f)
                    local secretish = pc == "always" or pc == "conditional"
                    for _, r in ipairs(f.Returns or {}) do if r.SecretValue or r.ConditionalSecret then secretish = true end end
                    local args = f.Arguments or {}
                    local unitFirst = args[1] and isUnitArg(args[1])
                    local rest = true
                    for i = unitFirst and 2 or 1, #args do
                        if not (args[i].Nilable or args[i].Default ~= nil) then rest = false break end
                    end
                    if secretish and rest and (#args == 0 or unitFirst) then
                        local path = sys.Namespace and (sys.Namespace .. "." .. name) or name
                        if type(ns.Resolve(path)) == "function" then out[#out + 1] = { path = path, unit = unitFirst and true or false } end
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.path < b.path end)
    return out
end

local sweeping, sweepList, sweepPos, sweepCalls, sweepSession = false, nil, 1, 0, nil

local function unitExists(u)
    if u == "player" then return true end
    local f = rawget(_G, "UnitExists")
    if type(f) ~= "function" then return false end
    local ok, r = pcall(f, u)
    return ok and not ns.IsSecret(r) and r and true or false
end

function Secrets.SweepTick(maxCalls)
    if ns.SelfThrottled and ns.SelfThrottled() then return 0 end
    if not sweepList then sweepList = Secrets.SweepCandidates() sweepPos = 1 end
    if #sweepList == 0 then return 0 end
    local calls = 0
    maxCalls = maxCalls or tonumber(scfg().sweepPerTick) or 25
    local units = { "player" }
    if unitExists("target") then units[2] = "target" end
    local guard = 0
    while calls < maxCalls and guard < #sweepList do
        guard = guard + 1
        local c = sweepList[sweepPos]
        sweepPos = sweepPos % #sweepList + 1
        local fn = ns.Resolve(c.path)
        if type(fn) == "function" then
            if c.unit then
                for _, u in ipairs(units) do
                    Secrets.ObserveResult(c.path, ns.SafeCall(fn, u), u, { n = 1, u })
                    calls = calls + 1
                end
            else
                Secrets.ObserveResult(c.path, ns.SafeCall(fn), nil, { n = 0 })
                calls = calls + 1
            end
        end
    end
    sweepCalls = sweepCalls + calls
    if sweepSession then sweepSession.sweepCalls = (sweepSession.sweepCalls or 0) + calls end
    return calls
end

local function schedule()
    local after = rawget(_G, "C_Timer") and C_Timer.After
    if not after then return end
    after(tonumber(scfg().sweepInterval) or 5, function()
        if not sweeping then return end
        pcall(Secrets.SweepTick)
        schedule()
    end)
end

local function sessionRecord()
    local obs = obsDB()
    obs._sessions = obs._sessions or {}
    local sid = ns.SessionId()
    local s = obs._sessions[sid]
    if not s then
        local n = 0
        for _ in pairs(obs._sessions) do n = n + 1 end
        if n >= 50 then return nil end
        s = { anchor = ns.TimeAnchor(), sweepCalls = 0, started = 0 }
        obs._sessions[sid] = s
    end
    return s
end

function Secrets.StartSweep()
    if sweeping then return true end
    sweepList = Secrets.SweepCandidates()
    sweepPos, sweepCalls = 1, 0
    sweepSession = sessionRecord()
    if sweepSession then sweepSession.started = sweepSession.started + 1 sweepSession.candidates = #sweepList end
    if #sweepList == 0 then return false end
    sweeping = true
    pcall(Secrets.SweepTick)
    schedule()
    return true
end

function Secrets.StopSweep()
    if not sweeping then return 0 end
    sweeping = false
    if sweepSession then sweepSession.endAnchor = ns.TimeAnchor(true) end
    return sweepCalls
end
function Secrets.IsSweeping() return sweeping end

ns.On("PLAYER_LOGOUT", function()
    if sweeping then Secrets.StopSweep() end
end)

----------------------------------------------------------------------------
-- state snapshot
----------------------------------------------------------------------------
local PRIMS = { "issecretvalue", "issecrettable", "canaccessvalue", "canaccesssecrets", "canaccesstable",
    "hasanysecretvalues", "scrubsecretvalues", "scrub", "secretwrap", "secretunwrap", "dropsecretaccess",
    "issecure", "issecurevariable", "forceinsecure", "securecallfunction", "InCombatLockdown" }
local STATE_PATTERN = { "Restrict", "Secret", "Lockdown", "Declassif" }
local CVAR_PATTERN = { "secret", "restrict", "lockdown", "taint", "scripterror", "addonperformance", "protected" }

local function matchesAny(s, pats)
    local l = string.lower(s)
    for _, p in ipairs(pats) do if string.find(l, string.lower(p), 1, true) then return true end end
    return false
end

local function stateGetters()
    local out = {}
    local docs = rawget(_G, "ForeverDumpDocsDB")
    if type(docs) ~= "table" or type(docs.systems) ~= "table" then return out end
    for _, sys in ipairs(docs.systems) do
        if sys.Type ~= "ScriptObject" and type(sys.Functions) == "table" then
            for _, f in ipairs(sys.Functions) do
                local name = f.Name
                if type(name) == "string" and (not f.Arguments or #f.Arguments == 0) and not f.HasRestrictions
                    and not f.IsProtectedFunction and matchesAny(name, STATE_PATTERN)
                    and (string.find(name, "^Is") or string.find(name, "^Should") or string.find(name, "^Has")
                        or string.find(name, "^Get") or string.find(name, "^Are") or string.find(name, "^Can")) then
                    out[#out + 1] = sys.Namespace and (sys.Namespace .. "." .. name) or name
                end
            end
        end
    end
    table.sort(out)
    return out
end

function Secrets.State()
    local st = ns.Stamp({ inCombat = ns.InCombat(), inEncounter = inEncounter, instanceType = instanceType, primitives = {},
        getters = {}, restrictions = {}, cvars = {} })
    for _, name in ipairs(PRIMS) do st.primitives[name] = type(rawget(_G, name)) end
    local CS = rawget(_G, "C_Secrets")
    if type(CS) == "table" then
        st.cSecrets = {}
        for name, fn in next, CS do if type(fn) == "function" then st.cSecrets[#st.cSecrets + 1] = name end end
        table.sort(st.cSecrets)
    end
    for _, path in ipairs(stateGetters()) do
        local res = ns.SafeCall(ns.Resolve(path))
        st.getters[path] = res
        Secrets.ObserveResult(path, res, nil, { n = 0 })
    end
    local RA = rawget(_G, "C_RestrictedActions")
    local types = rawget(rawget(_G, "Enum") or {}, "AddOnRestrictionType")
    if type(RA) == "table" and type(RA.GetAddOnRestrictionState) == "function" and type(types) == "table" then
        for tname, v in pairs(types) do st.restrictions[tname] = ns.SafeCall(RA.GetAddOnRestrictionState, v) end
    end
    local CL = rawget(_G, "C_CombatLog")
    if type(CL) == "table" then st.combatLogRestricted = ns.SafeCall(CL.IsCombatLogRestricted) end
    local names = ns.db and ns.db.cvarNames
    if type(names) ~= "table" or #names == 0 then
        names = { "taintLog", "scriptErrors", "scriptProfile", "addonPerformanceMsgWarning", "addonChallengeModeRestrictionsForced",
                  "addonCombatRestrictionsForced", "addonEncounterRestrictionsForced", "addonMapRestrictionsForced",
                  "addonPvPMatchRestrictionsForced", "addonChatRestrictionsForced" }
    end
    local get = (rawget(_G, "C_CVar") and C_CVar.GetCVar) or rawget(_G, "GetCVar")
    for _, name in ipairs(names) do
        if type(name) == "string" and matchesAny(name, CVAR_PATTERN) and type(get) == "function" then
            local ok, v = pcall(get, name)
            if ok and not ns.IsSecret(v) then st.cvars[name] = v end
        end
    end
    return ns.Clean(st, { maxDepth = 6, maxKeys = 2000 })
end

function Secrets.Snapshot(reason)
    local sct = ns.db.sections.secrets or {}
    local key = inEncounter and "inEncounter" or (ns.InCombat() and "inCombat" or "outOfCombat")
    local st = Secrets.State()
    st.reason = reason
    sct[key] = st
    ns.db.sections.secrets = sct
    return key, st
end

----------------------------------------------------------------------------
-- live panel
----------------------------------------------------------------------------
local panel
local function panelText()
    local l = liveDB()
    local lines = { "|cff33ff99ForeverDump secrets verifier|r  " .. (sweeping and "sweep ON" or "sweep off")
        .. string.format("  (%s, %s)", ns.InCombat() and "in combat" or "out of combat", instanceType) }
    lines[#lines + 1] = "recent (calls with a secret / seen; secret arg positions):"
    for i = 1, math.min(#l.recent, 10) do
        local r = l.recent[i]
        lines[#lines + 1] = string.format("  %s  %d/%d%s", r.key, r.s, r.n, r.sp and ("  |cffffcc00secret #" .. r.sp .. "|r") or "")
    end
    local keys = {}
    for k in pairs(l.ctx or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    if #keys > 0 then lines[#lines + 1] = "per context (secret/seen, events+api):" end
    for i = 1, math.min(#keys, 6) do
        local cs = l.ctx[keys[i]]
        lines[#lines + 1] = string.format("  %s: %d/%d (ev %d, api %d)", keys[i], cs.s, cs.n, cs.ev, cs.api)
    end
    lines[#lines + 1] = string.format("contradictions: %d", #l.contradictions)
    for i = math.max(1, #l.contradictions - 5), #l.contradictions do
        local c = l.contradictions[i]
        if c then lines[#lines + 1] = string.format("  |cffff5555%s #%d|r doc %s, seen %s (%s) x%d", c.key, c.pos, c.doc, c.observed, c.ctx, c.count) end
    end
    return table.concat(lines, "\n")
end
Secrets.PanelText = panelText

function Secrets.TogglePanel(show)
    if not panel then
        panel = CreateFrame("Frame", "ForeverDumpSecretsPanel", UIParent)
        panel:SetSize(460, 340)
        panel:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -200)
        panel:SetFrameStrata("HIGH")
        if panel.SetMovable then panel:SetMovable(true) panel:EnableMouse(true) panel:RegisterForDrag("LeftButton")
            panel:SetScript("OnDragStart", panel.StartMoving) panel:SetScript("OnDragStop", panel.StopMovingOrSizing) end
        local bg = panel:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.7)
        panel.text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        panel.text:SetPoint("TOPLEFT", 8, -8)
        panel.text:SetPoint("BOTTOMRIGHT", -8, 8)
        panel.text:SetJustifyH("LEFT")
        panel.text:SetJustifyV("TOP")
        -- "HSM" button: opens the hybrid state machine window
        local hb = CreateFrame("Button", nil, panel)
        hb:SetSize(40, 16)
        hb:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -4)
        hb.t = hb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hb.t:SetPoint("CENTER")
        hb.t:SetText("[HSM]")
        hb:SetScript("OnClick", function() if ns.HSMUI then ns.HSMUI.Toggle() end end)
        panel.hsmButton = hb
        local acc = 0
        panel:SetScript("OnUpdate", function(self, dt)
            acc = acc + (dt or 0)
            if acc >= 1 then acc = 0 self.text:SetText(panelText()) end
        end)
        panel:Hide()
    end
    if show == nil then show = not panel:IsShown() end
    if show then panel.text:SetText(panelText()) panel:Show() else panel:Hide() end
    return show
end

ns.RegisterSection({
    name = "secrets",
    desc = "secret/restriction state (C_Secrets predicates, restriction states, getters, CVars); "
        .. "/fdump secrets [panel|state|sweep on|off|now|status]: live verifier panel",
    inAll = true,
    combatSafe = true,
    run = function(_, args)
        local sub = args and string.lower(args[1] or "") or nil
        if sub == "controls" then
            local rec = ns.Controls.Run("command", true)
            if rec and rec.controls and rec.controls.checks then
                for _, c in ipairs(rec.controls.checks) do
                    ns.Print(string.format("  %s %s: observed %s, expected %s", c.pass == true and "|cff33ff99ok|r"
                        or (c.pass == false and "|cffff5555DIFF|r" or "--"), c.name, tostring(c.observed), tostring(c.expected)))
                end
            end
            ns.Print("controls + ops matrix stored in ForeverDumpLogDB.controls (converter: fdump.py secrets-ops).")
            return
        elseif sub == "forced" then
            ns.Controls.ForcedSweep()
            return
        elseif sub == "sweep" then
            local w = string.lower(args[2] or "status")
            if w == "on" then ns.Print(Secrets.StartSweep() and "secrets sweep running" or "secrets sweep: no candidates (run /fdump docs first)")
            elseif w == "off" then ns.Print(string.format("secrets sweep stopped (%d calls)", Secrets.StopSweep()))
            elseif w == "now" then ns.Print(string.format("secrets sweep: %d calls", Secrets.SweepTick(200)))
            else ns.Print(string.format("secrets sweep %s, %d candidates, %d calls", sweeping and "ON" or "off",
                #(sweepList or Secrets.SweepCandidates()), sweepCalls)) end
            return
        end
        if sub == "panel" or sub == "" then
            Secrets.TogglePanel()
            if sub == "panel" then return end
        end
        local key, st = Secrets.Snapshot("section")
        local nG = 0
        for _ in pairs(st.getters or {}) do nG = nG + 1 end
        local sct = ns.db.sections.secrets
        local obs = obsDB()
        sct.counts = { getters = nG, observedKeys = obs and obs._keys or 0, contradictions = #liveDB().contradictions }
        ns.SaveSection("secrets", sct)
        ns.Print(string.format("secrets: state stored under secrets.%s (%d state getters); %d keys observed, %d live contradictions",
            key, nG, sct.counts.observedKeys, sct.counts.contradictions))
    end,
})
