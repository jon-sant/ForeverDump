-- ForeverDump v2.2 - workarounds lab: measures the SANCTIONED paths for using secret values, as boundary diagnostics.
-- /fdump lab [poll on|off]; also runs once out of combat and once in combat during an FD_Logs capture (addon code,
-- clean C_Timer callback, everything pcall'd). Stored: availability, ok/error text, and whether outputs/readbacks are
-- secret (five-state codes) - never a secret, never a value derived from one. Every API/method is checked against
-- the 70245 docs (ForeverDumpDocsDB) and the runtime first; missing ones are recorded as absent.
-- Not done on purpose: any side-channel extraction (e.g. deriving numbers from rendered widths). Width/alpha/color
-- readbacks are only tested for "is the readback secret".
local _, ns = ...
local L = {}
ns.Lab = L

local function g(n) return rawget(_G, n) end
-- resolved lazily (undefined in older clients / the mock): only used after item() confirmed they exist
local function UnitHealthPercent(...) return g("UnitHealthPercent")(...) end
local function UnitIsUnit(...) return g("UnitIsUnit")(...) end
local C_CurveUtil = setmetatable({}, { __index = function(_, k) return (g("C_CurveUtil") or {})[k] end })
local function code(v) return ns.ClassifyValue(v) end
local function sec(v) local c = code(v) return c == "S" or c == "T" end
local function errText(e)
    if e == nil then return nil end
    if ns.IsSecret(e) then return "<secret error text>" end
    local s = tostring(e)
    return #s > 160 and s:sub(1, 160) or s
end
local function ctxName()
    if ns.Secrets and ns.Secrets.InEncounter and ns.Secrets.InEncounter() then return "enc" end
    return ns.InCombat() and "combat" or "ooc"
end

-- docs: functions via Secrets.DocRow, widget methods via ScriptObject systems
local methodDocs
local function docMethod(name)
    if not methodDocs then
        methodDocs = {}
        local docs = g("ForeverDumpDocsDB")
        for _, sys in ipairs((type(docs) == "table" and docs.systems) or {}) do
            if sys.Type == "ScriptObject" then
                for _, f in ipairs(sys.Functions or {}) do if type(f.Name) == "string" then methodDocs[f.Name] = true end end
            end
        end
    end
    return methodDocs[name] == true or next(methodDocs) == nil   -- no docs dumped yet: trust the runtime
end
local function docFunc(path)
    if not (ns.Secrets and ns.Secrets.DocRow) then return true end
    local docs = g("ForeverDumpDocsDB")
    if type(docs) ~= "table" or type(docs.systems) ~= "table" then return true end
    return ns.Secrets.DocRow("api:" .. path) ~= nil
end
local function fn(path)
    local f = ns.Resolve(path)
    return type(f) == "function" and f or nil
end

local frame, fs, bar, cd, tex
local function widgets()
    if frame then return true end
    return pcall(function()
        frame = CreateFrame("Frame", nil, UIParent)
        frame:Hide()
        fs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        bar = CreateFrame("StatusBar", nil, frame)
        cd = CreateFrame("Cooldown", nil, frame)
        tex = frame:CreateTexture(nil, "ARTWORK")
    end)
end
local function reset(o) if o and type(o.SetToDefaults) == "function" then pcall(o.SetToDefaults, o) end end

-- one lab item: required = { "api:Path" | "method:Name" ... }; body returns a table of non-secret fields
local function item(out, group, id, approach, required, body)
    local r = { group = group, id = id, approach = approach }
    for _, req in ipairs(required or {}) do
        local kind, name = req:match("^(%w+):(.+)$")
        local ok = (kind == "api" and fn(name) and docFunc(name)) or (kind == "method" and docMethod(name))
        if not ok then
            r.absent = r.absent or {}
            r.absent[#r.absent + 1] = name .. ((kind == "api" and fn(name)) and " (undocumented in 70245)" or "")
        end
    end
    if r.absent then r.available = false out[#out + 1] = r return r end
    r.available = true
    if ns.ProbeMark then ns.ProbeMark("Lab", tostring(r.id or r.approach or "?")) end
    local ok, res = pcall(body)
    if ns.ProbeDone then ns.ProbeDone() end
    r.ok = ok
    if ok and type(res) == "table" then for k, v in pairs(res) do r[k] = v end
    elseif not ok then r.err = errText(res) end
    out[#out + 1] = r
    return r
end

local function H() local f = g("UnitHealth") return f and f("player") end
local function HM() local f = g("UnitHealthMax") return f and f("player") end

function L.Run(reason)
    if ns.SelfThrottled and ns.SelfThrottled() then return nil end
    local items = {}
    local haveW = widgets()
    -- 1) widget passthrough (sinks)
    item(items, "widget", "statusbar", "StatusBar:SetMinMaxValues(0, UnitHealthMax) + SetValue(UnitHealth)",
        { "method:SetMinMaxValues", "method:SetValue", "method:GetValue" }, function()
            assert(haveW, "test widgets unavailable")
            local okA, eA = pcall(bar.SetMinMaxValues, bar, 0, HM())
            local okB, eB = pcall(bar.SetValue, bar, H())
            local okG, v = pcall(bar.GetValue, bar)
            local r = { setMinMax = okA, setMinMaxErr = (not okA) and errText(eA) or nil, setValue = okB,
                setValueErr = (not okB) and errText(eB) or nil, getValueState = okG and code(v) or "E", outputSecret = okG and sec(v) or nil }
            reset(bar)
            return r
        end)
    item(items, "widget", "fontstring-settext", "FontString:SetText(secret) then GetText / GetStringWidth",
        { "method:SetText", "method:GetText", "method:GetStringWidth" }, function()
            assert(haveW, "test widgets unavailable")
            local ok, e = pcall(fs.SetText, fs, H())
            local okT, t = pcall(fs.GetText, fs)
            local okW, w = pcall(fs.GetStringWidth, fs)
            local r = { set = ok, setErr = (not ok) and errText(e) or nil, getTextState = okT and code(t) or "E",
                stringWidthState = okW and code(w) or "E", outputSecret = okT and sec(t) or nil }
            reset(fs) pcall(fs.SetText, fs, "")
            return r
        end)
    item(items, "widget", "fontstring-formatted", "FontString:SetFormattedText('%d', secret) then GetText",
        { "method:SetFormattedText", "method:GetText" }, function()
            assert(haveW, "test widgets unavailable")
            local ok, e = pcall(fs.SetFormattedText, fs, "%d", H())
            local okT, t = pcall(fs.GetText, fs)
            local r = { set = ok, setErr = (not ok) and errText(e) or nil, getTextState = okT and code(t) or "E", outputSecret = okT and sec(t) or nil }
            reset(fs) pcall(fs.SetText, fs, "")
            return r
        end)
    item(items, "widget", "cooldown-duration", "Cooldown:SetCooldownFromDurationObject(C_Spell.GetSpellCooldownDuration(61304))",
        { "method:SetCooldownFromDurationObject", "api:C_Spell.GetSpellCooldownDuration" }, function()
            assert(haveW, "test widgets unavailable")
            local d = C_Spell.GetSpellCooldownDuration(61304)
            local ok, e = pcall(cd.SetCooldownFromDurationObject, cd, d)
            local r = { durationState = code(d), set = ok, setErr = (not ok) and errText(e) or nil }
            if type(cd.GetCooldownTimes) == "function" then
                local okT, s1 = pcall(cd.GetCooldownTimes, cd)
                r.getCooldownTimesState = okT and code(s1) or "E"
            end
            reset(cd)
            return r
        end)
    item(items, "widget", "texture-readbacks", "Texture:SetAlpha(curve(UnitHealthPercent)) then GetAlpha (boundary: is the readback secret)",
        { "method:SetAlpha", "method:GetAlpha", "api:UnitHealthPercent", "api:C_CurveUtil.CreateCurve" }, function()
            assert(haveW, "test widgets unavailable")
            local curve = C_CurveUtil.CreateCurve()
            curve:AddPoint(0, 0.2) curve:AddPoint(1, 1)
            local okP, a = pcall(UnitHealthPercent, "player", true, curve)
            local ok, e = pcall(tex.SetAlpha, tex, a)
            local okA, av = pcall(tex.GetAlpha, tex)
            local r = { percentState = okP and code(a) or "E", setAlpha = ok, setAlphaErr = (not ok) and errText(e) or nil,
                getAlphaState = okA and code(av) or "E", outputSecret = okA and sec(av) or nil }
            if type(tex.HasSecretValues) == "function" then local okH, h = pcall(tex.HasSecretValues, tex) r.textureHasSecretValues = okH and h == true end
            reset(tex)
            return r
        end)
    -- 2) engine-side math
    item(items, "engine", "healthpercent", "UnitHealthPercent('player') (no curve)", { "api:UnitHealthPercent" }, function()
        local ok, v = pcall(UnitHealthPercent, "player")
        return { state = ok and code(v) or "E", err = (not ok) and errText(v) or nil, outputSecret = ok and sec(v) or nil }
    end)
    item(items, "engine", "healthpercent-curve", "UnitHealthPercent('player', true, numberCurve)",
        { "api:UnitHealthPercent", "api:C_CurveUtil.CreateCurve" }, function()
        local curve = C_CurveUtil.CreateCurve()
        curve:AddPoint(0, 0) curve:AddPoint(1, 100)
        local ok, v = pcall(UnitHealthPercent, "player", true, curve)
        return { state = ok and code(v) or "E", err = (not ok) and errText(v) or nil, outputSecret = ok and sec(v) or nil }
    end)
    item(items, "engine", "curve-evaluate", "LuaCurveObject:Evaluate(clear x) / Evaluate(secret x)", { "api:C_CurveUtil.CreateCurve" }, function()
        local curve = C_CurveUtil.CreateCurve()
        curve:AddPoint(0, 0) curve:AddPoint(1, 1)
        local okC, c = pcall(curve.Evaluate, curve, 0.5)
        local okS, s = pcall(curve.Evaluate, curve, H())
        local okH, hs = pcall(curve.HasSecretValues, curve)
        return { clearInputState = okC and code(c) or "E", secretInputState = okS and code(s) or "E", secretInputErr = (not okS) and errText(s) or nil,
            curveHasSecretValues = okH and hs == true, outputSecret = okS and sec(s) or nil }
    end)
    item(items, "engine", "colorcurve", "C_CurveUtil.CreateColorCurve + UnitHealthPercent(player, true, colorCurve)",
        { "api:C_CurveUtil.CreateColorCurve", "api:UnitHealthPercent" }, function()
            local cc = C_CurveUtil.CreateColorCurve()
            local mk = g("CreateColor")
            assert(type(mk) == "function", "CreateColor missing")
            cc:AddPoint(0, mk(1, 0, 0, 1)) cc:AddPoint(1, mk(0, 1, 0, 1))
            local ok, col = pcall(UnitHealthPercent, "player", true, cc)
            return { state = ok and code(col) or "E", err = (not ok) and errText(col) or nil, outputSecret = ok and sec(col) or nil }
        end)
    item(items, "engine", "duration-methods", "C_Spell.GetSpellCooldownDuration(1752): GetRemainingDuration / IsZero / HasSecretValues",
        { "api:C_Spell.GetSpellCooldownDuration" }, function()
            local d = C_Spell.GetSpellCooldownDuration(1752)
            local r = { durationState = code(d) }
            if d ~= nil then
                for _, m in ipairs({ "GetRemainingDuration", "GetTotalDuration", "GetRemainingPercent", "IsZero", "HasExpired", "HasSecretValues" }) do
                    local okM, f = pcall(function() return d[m] end)
                    if okM and type(f) == "function" then local okR, v = pcall(f, d) r[m] = okR and code(v) or "E" else r[m] = "absent" end
                end
            end
            return r
        end)
    item(items, "engine", "compare-units", "UnitIsUnit('player','player') / C_Secrets.CanCompareUnitTokens('player','target')",
        { "api:UnitIsUnit", "api:C_Secrets.CanCompareUnitTokens" }, function()
            local okU, u = pcall(UnitIsUnit, "player", "player")
            local okC, c = pcall(C_Secrets.CanCompareUnitTokens, "player", "target")
            return { unitIsUnitState = okU and code(u) or "E", canCompareState = okC and code(c) or "E",
                canCompare = okC and not sec(c) and c or nil }
        end)
    -- 3) non-secret neighbours
    local NEIGHBOURS = {
        { "UnitHealthMax", "player" }, { "UnitPowerMax", "player" }, { "UnitIsDeadOrGhost", "player" }, { "UnitAffectingCombat", "player" },
        { "UnitThreatSituation", "player", "target" }, { "UnitDetailedThreatSituation", "player", "target" },
        { "GetSpellBaseCooldown", 1752 }, { "C_DamageMeter.IsDamageMeterAvailable" }, { "C_DamageMeter.GetSessionDurationSeconds", 1 },
        { "C_DamageMeter.GetCombatSessionFromType", 0, 0 },
    }
    for _, n in ipairs(NEIGHBOURS) do
        item(items, "neighbour", n[1], n[1] .. "(" .. table.concat({ select(2, unpack(n)) }, ",") .. ")", { "api:" .. n[1] }, function()
            local res = ns.SafeCall(fn(n[1]), select(2, unpack(n)))
            local r = { ok = res.ok, err = res.err and errText(res.err) or nil, states = res.states and table.concat(res.states) or nil }
            if res.fstates and res.fstates[1] then
                local parts = {}
                for k, v in pairs(res.fstates[1]) do parts[#parts + 1] = k .. "=" .. v end
                table.sort(parts)
                r.fields = table.concat(parts, " ")
            end
            r.outputSecret = r.states and r.states:find("[ST]") ~= nil or false
            return r
        end)
    end
    item(items, "neighbour", "cooldown-neverSecret", "C_Spell.GetSpellCooldown(1752) NeverSecret fields (isEnabled/isActive/isOnGCD)",
        { "api:C_Spell.GetSpellCooldown" }, function()
            local res = ns.SafeCall(C_Spell.GetSpellCooldown, 1752)
            local f = res.fstates and res.fstates[1] or {}
            return { isEnabled = f.isEnabled, isActive = f.isActive, isOnGCD = f.isOnGCD, startTime = f.startTime, duration = f.duration,
                outputSecret = (f.startTime == "S") }
        end)
    -- boundary: a secret string (tostring of a secret) - every op pcall'd, only ok/err/resultSecret kept
    item(items, "boundary", "secret-string", "s = tostring(UnitHealth('player')); string ops on s", { "api:UnitHealth" }, function()
        local h = H()
        local hc = code(h)
        if hc ~= "C" then return { healthState = hc, skipped = "UnitHealth " .. hc .. ": tostring/string ops not attempted (no operation on a secret)" } end
        local okS, s = pcall(tostring, h)
        local r = { healthState = hc, tostringOk = okS, tostringState = okS and code(s) or "E" }
        if not okS then r.tostringErr = errText(s) return r end
        -- v2.2.11 (run 9 taint.log: len/index/compare blocked at the ops below): string ops only on a clear string;
        -- a secret string (the live case) is recorded, never operated on
        if r.tostringState ~= "C" then r.opsSkipped = "string " .. r.tostringState .. ": ops not attempted (no operation on a secret)" return r end
        local OPS = {
            { "len", function() return string.len(s) end }, { "hash", function() return #s end },
            { "byte", function() return s:byte(1) end }, { "sub", function() return s:sub(1, 1) end },
            { "eq", function() return s == "x" end }, { "lt", function() return s < "x" end },
            { "format", function() return string.format("%s", s) end }, { "concat", function() return s .. "x" end },
            { "find", function() return s:find("1") end }, { "gsub", function() return (s:gsub("1", "2")) end },
            { "upper", function() return s:upper() end }, { "tonumber", function() return tonumber(s) end },
        }
        r.ops = {}
        for _, op in ipairs(OPS) do
            local ok, v = pcall(op[2])
            r.ops[op[1]] = { ok = ok, err = (not ok) and errText(v) or nil, resultState = ok and code(v) or nil }
        end
        return r
    end)
    local rec = { reason = reason, ctx = ctxName(), execution = "addon", items = items }
    if ns.Restrictions then local okV, v = pcall(ns.Restrictions.Vector) if okV then rec.vector = v end end
    local okD, dead = pcall(g("UnitIsDeadOrGhost") or function() return nil end, "player")
    rec.dead = okD and not ns.IsSecret(dead) and dead or nil
    ns.Stamp(rec)
    local log = ForeverDumpLogDB
    if type(log) == "table" then
        log.lab = log.lab or {}
        log.lab[#log.lab + 1] = rec
        while #log.lab > 12 do table.remove(log.lab, 1) end
    end
    return rec
end

----------------------------------------------------------------------------
-- polling (opt-in, lab.poll): UnitHealth/UnitPower("player") state every lab.pollInterval s during a capture;
-- run-length encoded (a sample is stored only when a state changes) -> readable windows on the xref timeline
----------------------------------------------------------------------------
local polling = false
local function pollDB()
    local log = ForeverDumpLogDB
    if type(log) ~= "table" then return nil end
    log.poll = log.poll or { changes = {}, samples = 0 }
    return log.poll
end
local last = {}
local function pollTick()
    if not polling then return end
    local p = pollDB()
    if p and not (ns.SelfThrottled and ns.SelfThrottled()) then
        local uh, up = g("UnitHealth"), g("UnitPower")
        local okH, h = pcall(uh, "player")
        local okP, pw = pcall(up, "player")
        local hc, pc = okH and code(h) or "E", okP and code(pw) or "E"
        p.samples = (p.samples or 0) + 1
        local key = hc .. pc .. (ns.InCombat() and "c" or "o")
        if key ~= last.key and #p.changes < 2000 then
            p.changes[#p.changes + 1] = ns.Stamp({ h = hc, p = pc, combat = ns.InCombat() or nil })
            last.key = key
        end
    end
    local after = g("C_Timer") and C_Timer.After
    if type(after) == "function" then after(tonumber(ns.config.lab.pollInterval) or 0.5, pollTick) end
end
function L.StartPoll()
    if polling then return end
    polling = true
    last = {}
    pollTick()
end
function L.StopPoll() polling = false end
function L.Polling() return polling end

-- FD_Logs integration: lab once out of combat at ON, once in the first combat (next frames, clean callback)
local labCombatSid
ns.On("PLAYER_REGEN_DISABLED", function()
    local logs = ns.db and ns.db.logs
    if not (logs and logs.on and logs.session) or ns.config.lab.auto == false then return end
    if labCombatSid == logs.session.sid then return end
    labCombatSid = logs.session.sid
    local after = g("C_Timer") and C_Timer.After
    if type(after) == "function" then after(1, function() pcall(L.Run, "combat") end) end
end)
