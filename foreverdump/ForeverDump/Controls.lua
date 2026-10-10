-- ForeverDump v2.2 - secrets controls, "what can you do with a secret" matrix, forced-restriction sweep, debug CVars.
--
-- Controls batch (FD_Logs ON, first combat of a capture, FD_Logs OFF; /fdump secrets controls):
--   positive: pcall(secretwrap, 1) -> issecretvalue (secretwrap may be nil: recorded);
--   always-secret: issecretvalue(UnitHealth("player")) (expected true even out of combat on 70245);
--   negative: issecretvalue(1), issecretvalue(UnitHealthMax("player")) (expected false);
--   container: C_Spell.GetSpellCooldownDuration(id):HasSecretValues() for 61304 (GCD) / 8690 / 20608 / 1752;
--   whitelist: C_Secrets.GetSpellCooldownSecrecy(id) for the same ids (0 NeverSecret, 1 Always, 2 Contextual).
--   Results are booleans/codes only. Expected values come from the research notes and are marked as such; the run
--   decides (e.g. the 2026-10-07 SV already shows GetSpellCooldownSecrecy(8690) == 2, not 0).
-- Ops matrix: for UnitHealth/UnitPower("player"), UnitHealthMax("player") and a secretwrap(1) value, which operations
--   succeed (pcall): arithmetic, comparison, tostring, string.format('%d'), concatenation, table key, print,
--   FontString:SetText + GetText (is the read-back secret?), StatusBar:SetValue. Stored: ok + error text only
--   (error text dropped if it is itself secret). Once per context (ooc/combat/encounter) per capture.
-- Forced sweep (/fdump secrets forced, opt-in, out of combat only): for each addon<Type>RestrictionsForced CVar:
--   record the original, set 1, wait a frame, re-probe (restriction states, predicates, flip probe set, controls),
--   restore the original. Originals are persisted in ForeverDumpDB.forcedSweep before the first change and restored
--   on abort (combat starts), on PLAYER_LOGOUT, and at the next login if a sweep was interrupted.
-- Debug CVars (/fdump debug on [level] | off): taintLog (default 2) + taintLogObjectSecrets 1; originals persisted and
--   restored by /fdump debug off (or at the next login after an interrupted session when debug.autoRestore is set).
local _, ns = ...
local C = {}
ns.Controls = C

local function g(name) return rawget(_G, name) end
local function isSecret(v) return ns.IsSecret(v) end
local function code(v) return ns.ClassifyValue(v) end
local function errText(e)
    if e == nil then return nil end
    if isSecret(e) then return "<secret error text>" end
    local s = tostring(e)
    if isSecret(s) then return "<secret error text>" end
    return #s > 160 and s:sub(1, 160) or s
end
local function getCVar(name)
    local get = (g("C_CVar") and C_CVar.GetCVar) or g("GetCVar")
    if type(get) ~= "function" then return nil end
    local ok, v = pcall(get, name)
    if ok and not isSecret(v) then return v end
end
local function setCVar(name, value)
    local set = (g("C_CVar") and C_CVar.SetCVar) or g("SetCVar")
    if type(set) ~= "function" then return false, "SetCVar missing" end
    local ok, err = pcall(set, name, tostring(value))
    return ok, err
end
C.GetCVar, C.SetCVar = getCVar, setCVar

local function ctxName()
    if ns.Secrets and ns.Secrets.InEncounter and ns.Secrets.InEncounter() then return "enc" end
    return ns.InCombat() and "combat" or "ooc"
end

----------------------------------------------------------------------------
-- controls
----------------------------------------------------------------------------
local SPELLS = { 61304, 8690, 20608, 1752 }
C.SPELLS = SPELLS
local PRIMITIVES = { "issecretvalue", "issecrettable", "hasanysecretvalues", "canaccessvalue", "canaccessallvalues",
    "canaccesssecrets", "canaccesstable", "scrubsecretvalues", "scrub", "mapvalues", "dropsecretaccess", "secretwrap",
    "secretunwrap", "issecure", "securecallfunction", "forceinsecure" }

local function call(fn, ...)
    if type(fn) ~= "function" then return false, "missing" end
    return pcall(fn, ...)
end

local function check(list, name, expected, observed, note)
    list[#list + 1] = { name = name, expected = expected, observed = observed,
        pass = (expected == nil or observed == nil) and nil or (expected == observed), note = note }
end

function C.Checks()
    local out = { checks = {}, primitives = {}, cooldowns = {} }
    for _, p in ipairs(PRIMITIVES) do out.primitives[p] = type(g(p)) == "function" end
    local isv = g("issecretvalue")
    local function isS(v) if type(isv) ~= "function" then return nil end local ok, r = pcall(isv, v) return ok and r == true end
    -- positive control
    local sw = g("secretwrap")
    out.secretwrap = { present = type(sw) == "function" }
    if type(sw) == "function" then
        local ok, v = pcall(sw, 1)
        out.secretwrap.ok, out.secretwrap.err = ok, (not ok) and errText(v) or nil
        out.secretwrap.isSecret = ok and isS(v) or nil
        local ok2, v2 = pcall(sw, "x")
        out.secretwrap.okString, out.secretwrap.isSecretString = ok2, ok2 and isS(v2) or nil
    end
    check(out.checks, "issecretvalue(secretwrap(1))", true, out.secretwrap.isSecret, out.secretwrap.present and nil or "secretwrap is nil")
    local okH, h = call(g("UnitHealth"), "player")
    check(out.checks, "issecretvalue(UnitHealth('player'))", true, okH and isS(h) or nil, "SecretReturns: unconditional")
    check(out.checks, "issecretvalue(1)", false, isS(1))
    local okM, hm = call(g("UnitHealthMax"), "player")
    check(out.checks, "issecretvalue(UnitHealthMax('player'))", false, okM and isS(hm) or nil, "player max health is not restricted")
    local okP, pw = call(g("UnitPower"), "player")
    check(out.checks, "issecretvalue(UnitPower('player'))", nil, okP and isS(pw) or nil, "SecretWhenUnitPowerRestricted (observed always secret in run 2)")
    local cs, sp = g("C_Secrets"), g("C_Spell")
    for _, id in ipairs(SPELLS) do
        local r = {}
        if type(cs) == "table" then
            local ok, v = call(cs.GetSpellCooldownSecrecy, id)
            r.secrecy = ok and not isSecret(v) and v or nil
            local okS, sv = call(cs.ShouldSpellCooldownBeSecret, id)
            r.shouldBeSecret = okS and type(sv) == "boolean" and sv or nil
        end
        if type(sp) == "table" then
            local ok, d = call(sp.GetSpellCooldownDuration, id)
            if ok then
                r.durationType = type(d)
                r.durationState = code(d)    -- T = container with secrets, K = container clear, N = nothing
                if d ~= nil then
                    local okM2, m = pcall(function() return d.HasSecretValues end)
                    if okM2 and type(m) == "function" then
                        local okHS, hs = pcall(m, d)
                        r.hasSecretValues = okHS and not isSecret(hs) and hs or nil
                    end
                end
            else r.durationErr = errText(d) end
        end
        out.cooldowns[tostring(id)] = r
    end
    local c61304 = out.cooldowns["61304"] or {}
    check(out.checks, "GetSpellCooldownSecrecy(61304) (GCD, research: whitelisted)", 0, c61304.secrecy, "expected from research notes")
    check(out.checks, "GetSpellCooldownDuration(61304):HasSecretValues()", false, c61304.hasSecretValues, "expected from research notes")
    for _, id in ipairs({ 8690, 20608 }) do
        check(out.checks, "GetSpellCooldownSecrecy(" .. id .. ") (research: whitelisted since 12.0.1)", 0,
            (out.cooldowns[tostring(id)] or {}).secrecy, "run 2 SV observed 2 for 8690")
    end
    check(out.checks, "GetSpellCooldownSecrecy(1752)", 2, (out.cooldowns["1752"] or {}).secrecy, "class spell: contextual")
    -- project id: recorded, never assumed
    out.project = { id = g("WOW_PROJECT_ID"), mainline = g("WOW_PROJECT_MAINLINE"), camelot = g("WOW_PROJECT_CAMELOT") }
    return out
end

----------------------------------------------------------------------------
-- ops matrix
----------------------------------------------------------------------------
local testFrame, testFS, testBar
local function widgets()
    if testFrame then return true end
    local ok = pcall(function()
        testFrame = CreateFrame("Frame", nil, UIParent)
        testFrame:Hide()
        testFS = testFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        testBar = CreateFrame("StatusBar", nil, testFrame)
        testBar:SetMinMaxValues(0, 1)
    end)
    return ok
end
local function reset(obj)
    if obj and type(obj.SetToDefaults) == "function" then pcall(obj.SetToDefaults, obj) end
end

local OPS = {
    { "arith", function(v) return v + 0 end },
    { "compare", function(v) return v > 0 end },
    { "equal", function(v) return v == 0 end },
    { "tostring", function(v) return tostring(v) end },
    { "format", function(v) return string.format("%d", v) end },
    { "concat", function(v) return "x" .. v end },
    { "tableKey", function(v) local t = {} t[v] = true return next(t) ~= nil end },
    { "truthy", function(v) if v then return true end return false end },
}

function C.TestMessageFrame()
    if C.smf ~= nil then return C.smf or nil end
    local cf = g("CreateFrame")
    local ok, f = pcall(cf or function() return nil end, "ScrollingMessageFrame", nil, g("UIParent"))
    if ok and f then pcall(f.Hide, f) pcall(f.SetMaxLines, f, 4) end
    C.smf = (ok and f) or false
    return C.smf or nil
end
local function opsFor(v, doPrint)
    local r = { state = code(v), type = type(v) }
    -- v2.2.11 (run 9 taint.log: 6x arithmetic/compare blocked at the OPS lines + the print sink's SecureTypes "value"):
    -- ClassifyValue first; operations run only on a clear operand. A secret operand is recorded as state "S" with
    -- skipped=true and is never operated on, printed or added to a message frame (what each op does to a secret is
    -- already proven by runs <= 9 and kept by the master guide)
    if r.state ~= "C" and r.state ~= "K" and r.state ~= "N" then
        r.skipped = "operand " .. r.state .. ": ops not attempted (no operation on a secret)"
        return r
    end
    for _, op in ipairs(OPS) do
        local ok, res = pcall(op[2], v)
        local e = { ok = ok, err = (not ok) and errText(res) or nil, resultSecret = ok and isSecret(res) or nil }
        -- string results: only "is it a numeric string" (never the string), and only when the result is not secret
        if ok and type(res) == "string" and not e.resultSecret then e.numericString = tonumber(res) ~= nil end
        if ok and op[1] == "tostring" and e.resultSecret then
            local okN, nv = pcall(tonumber, res)
            e.tonumberOk, e.tonumberNil = okN, okN and nv == nil or nil   -- live 2026-10-07: tonumber(secret string) -> nil
        end
        r[op[1]] = e
    end
    if doPrint then
        -- v2.2.2: never print a secret into ChatFrame1 (run 3: the stored line tainted ChatFrame1:UpdateFading,
        -- "reading field oldestFadingLineTimestamp"). Test the sink on our own hidden ScrollingMessageFrame;
        -- v2.2.14: the old opsPrint = "chat" sink is gone for good (any addon AddMessage/print into a Blizzard chat frame
        -- taints its history buffer for the whole session -> BattlegroundChatFilters error, see Core.lua Output).
        if doPrint == "chat" then
            r.printChatSkipped = "chat sink removed in v2.2.14 (Blizzard chat-frame taint); own frame used"
        end
        do
            local smf = C.TestMessageFrame()
            if smf then
                local ok, err = pcall(smf.AddMessage, smf, v)
                r.print = { ok = ok, err = (not ok) and errText(err) or nil, sink = "own hidden ScrollingMessageFrame" }
                pcall(smf.Clear, smf)
            end
        end
    end
    if widgets() then
        local ok, err = pcall(testFS.SetText, testFS, v)
        local back = { ok = ok, err = (not ok) and errText(err) or nil }
        if ok then
            local okG, t = pcall(testFS.GetText, testFS)
            back.getTextOk = okG
            back.getTextSecret = okG and isSecret(t) or nil
        end
        r.setText = back
        reset(testFS)
        pcall(testFS.SetText, testFS, "")
        local okB, errB = pcall(testBar.SetValue, testBar, v)
        r.statusBar = { ok = okB, err = (not okB) and errText(errB) or nil }
        if okB then
            local okV, bv = pcall(testBar.GetValue, testBar)
            r.statusBar.getValueSecret = okV and isSecret(bv) or nil
        end
        reset(testBar)
    end
    return r
end

C.OpsFor = opsFor
-- deliberate operation on a possibly-secret operand (all deliberate secret touches live in this file):
-- endTimeMS - GetTime()*1000 -> ok, errorText, resultState. Used by the combat probe for "cast time left".
-- v2.2.11 (run 9 taint.log: 89x "arithmetic" blocked at this line): the operand is classified first and the
-- arithmetic only runs on a clear number; a secret/non-clear endTimeMS returns ok=nil + "skipped" (no secret touched)
function C.TryTimeLeft(endTimeMS)
    local e = ns.ClearNum(endTimeMS)
    if e == nil then return nil, "skipped: endTimeMS not a clear number (" .. code(endTimeMS) .. "); no operation on a secret", nil end
    local ok, v = pcall(function() return e - GetTime() * 1000 end)
    return ok, (not ok) and errText(v) or nil, ok and code(v) or nil
end
function C.OpsMatrix(doPrint)
    local out = {}
    local function add(name, fn, ...)
        if ns.ProbeMark then ns.ProbeMark("Controls", name) end
        local ok, v = call(fn, ...)
        if ns.ProbeDone then ns.ProbeDone() end
        if ok then out[name] = opsFor(v, doPrint) else out[name] = { callError = errText(v) } end
    end
    add("UnitHealth(player)", g("UnitHealth"), "player")
    add("UnitPower(player)", g("UnitPower"), "player")
    add("UnitHealthMax(player)", g("UnitHealthMax"), "player")
    if type(g("secretwrap")) == "function" then add("secretwrap(1)", g("secretwrap"), 1) end
    return out
end

----------------------------------------------------------------------------
-- run + persistence
----------------------------------------------------------------------------
local opsDone = {}  -- [sid .. ctx] = true
local function store(rec)
    local log = ForeverDumpLogDB
    if type(log) ~= "table" then return end
    log.controls = log.controls or {}
    local list = log.controls
    list[#list + 1] = rec
    while #list > 24 do table.remove(list, 1) end
end

function C.Run(reason, force)
    if ns.SelfThrottled and ns.SelfThrottled() then return nil end
    local ctx = ctxName()
    local rec = { reason = reason, ctx = ctx, execution = "addon" }   -- chat /run is force-tainted (ForceTaint_Strong)
    local ok, checks = pcall(C.Checks)
    rec.controls = ok and checks or { error = errText(checks) }
    if ns.Restrictions then
        local okV, v = pcall(ns.Restrictions.Vector)
        if okV then rec.vector = v end
    end
    local sid = ns.SessionId()
    if force or not opsDone[sid .. ctx] then
        opsDone[sid .. ctx] = true
        local op = ns.config.secrets.opsPrint
        local okO, m = pcall(C.OpsMatrix, (op == "chat" and "chat") or (op ~= false and "sink") or false)
        rec.ops = okO and m or { error = errText(m) }
    end
    ns.Stamp(rec)
    store(rec)
    return rec
end

----------------------------------------------------------------------------
-- forced-restriction sweep
----------------------------------------------------------------------------
local FORCED = { { 0, "addonCombatRestrictionsForced" }, { 1, "addonEncounterRestrictionsForced" },
    { 2, "addonChallengeModeRestrictionsForced" }, { 3, "addonPvPMatchRestrictionsForced" },
    { 4, "addonMapRestrictionsForced" }, { 5, "addonChatRestrictionsForced" } }
C.FORCED = FORCED
local sweepState  -- running sweep (in memory); persisted part: ForeverDumpDB.forcedSweep

local function fdb()
    local db = ns.db
    if not db then return nil end
    db.forcedSweep = db.forcedSweep or {}
    return db.forcedSweep
end

function C.RestoreForced(why)
    local f = fdb()
    if not f or type(f.originals) ~= "table" then return 0 end
    local n = 0
    for name, v in pairs(f.originals) do
        local cur = getCVar(name)
        if cur ~= nil and tostring(cur) ~= tostring(v) then setCVar(name, v) end
        n = n + 1
    end
    f.restored = { why = why, time = time and time() or nil, n = n }
    f.inProgress = nil
    f.originals = nil
    sweepState = nil
    return n
end

local function snapshot()
    local s = {}
    if ns.Restrictions then
        local okS, st = pcall(ns.Restrictions.States) s.states = okS and st or nil
        local okP, p = pcall(ns.Restrictions.Probe) s.probe = okP and p or nil
        local okV, v = pcall(ns.Restrictions.Vector) s.vector = okV and v or nil
    end
    local okC, c = pcall(C.Checks)
    s.controls = okC and c and c.checks or nil
    return s
end

local function step()
    local st = sweepState
    if not st then return end
    if ns.InCombat() then
        st.rec.aborted = "combat started"
        C.RestoreForced("abort: combat")
        return
    end
    st.i = st.i + 1
    local item = FORCED[st.i]
    if not item then
        st.rec.finished = true
        C.RestoreForced("finished")
        ns.Print("forced restriction sweep finished; all addon*RestrictionsForced CVars restored (results: ForeverDumpDB.forcedSweep).")
        return
    end
    local name = item[2]
    local orig = getCVar(name)
    local entry = { type = item[1], cvar = name, original = orig }
    st.rec.types[#st.rec.types + 1] = entry
    if orig == nil then entry.skipped = "CVar missing" step() return end
    local ok, err = setCVar(name, 1)
    entry.setOk, entry.setErr = ok, (not ok) and errText(err) or nil
    entry.valueAfterSet = getCVar(name)
    local after = g("C_Timer") and C_Timer.After
    local function measure()
        if not sweepState then return end
        entry.result = snapshot()
        setCVar(name, orig)                       -- ALWAYS restore before the next type
        entry.restoredTo = getCVar(name)
        if type(after) == "function" then after(0, step) else step() end
    end
    if type(after) == "function" then after(0, measure) else measure() end
end

function C.ForcedSweep()
    if ns.InCombat() then ns.Print("|cffff5555forced sweep: out of combat only.|r") return false end
    if sweepState then ns.Print("forced sweep already running.") return false end
    local f = fdb()
    if not f then return false end
    -- persist originals BEFORE changing anything
    f.originals = {}
    for _, item in ipairs(FORCED) do
        local v = getCVar(item[2])
        if v ~= nil then f.originals[item[2]] = v end
    end
    f.inProgress = true
    local rec = ns.Stamp({ baseline = snapshot(), types = {} })
    f.runs = f.runs or {}
    f.runs[#f.runs + 1] = rec
    while #f.runs > 5 do table.remove(f.runs, 1) end
    sweepState = { i = 0, rec = rec }
    ns.Print("forced restriction sweep: 6 CVars, one frame each, originals saved and restored after every step.")
    step()
    return true
end
function C.SweepRunning() return sweepState ~= nil end

ns.On("PLAYER_REGEN_DISABLED", function()
    if sweepState then sweepState.rec.aborted = "combat started" C.RestoreForced("abort: combat") end
end)
ns.On("PLAYER_LOGOUT", function()
    local f = ns.db and ns.db.forcedSweep
    if f and f.inProgress then C.RestoreForced("logout") end
end)

----------------------------------------------------------------------------
-- debug CVars (taintLog + taintLogObjectSecrets)
----------------------------------------------------------------------------
local function ddb()
    if not ns.db then return nil end
    ns.db.debugCVars = ns.db.debugCVars or {}
    return ns.db.debugCVars
end
function C.DebugOn() local d = ns.db and ns.db.debugCVars return d and d.on == true or false end
function C.Debug(on, level)
    local d = ddb()
    if not d then return end
    if on then
        if not d.on then
            d.originals = { taintLog = getCVar("taintLog"), taintLogObjectSecrets = getCVar("taintLogObjectSecrets") }
        end
        d.on = true
        d.level = tonumber(level) or 2
        setCVar("taintLog", d.level)
        if d.originals.taintLogObjectSecrets ~= nil then setCVar("taintLogObjectSecrets", 1) end
        d.since = time and time() or nil
        return string.format("debug ON: taintLog=%s taintLogObjectSecrets=%s (was %s/%s) -> Logs/taint.log. /fdump debug off restores.",
            tostring(getCVar("taintLog")), tostring(getCVar("taintLogObjectSecrets")),
            tostring(d.originals.taintLog), tostring(d.originals.taintLogObjectSecrets))
    else
        if not d.on then return "debug is off" end
        for name, v in pairs(d.originals or {}) do setCVar(name, v) end
        d.on, d.originals = false, nil
        return string.format("debug OFF: taintLog=%s taintLogObjectSecrets=%s restored", tostring(getCVar("taintLog")),
            tostring(getCVar("taintLogObjectSecrets")))
    end
end

-- next login: restore anything a crash / disconnect left behind
ns.On("PLAYER_LOGIN", function()
    local f = ns.db and ns.db.forcedSweep
    if f and f.inProgress then
        local n = C.RestoreForced("interrupted (restored at login)")
        ns.Print(string.format("forced sweep was interrupted last session: %d addon*RestrictionsForced CVar(s) restored.", n))
    end
end)

-- controls at the first combat of each capture (clean callback, next frame after PLAYER_REGEN_DISABLED)
local combatControlsSid
ns.On("PLAYER_REGEN_DISABLED", function()
    local logs = ns.db and ns.db.logs
    if not (logs and logs.on and logs.session) then return end
    if combatControlsSid == logs.session.sid then return end
    combatControlsSid = logs.session.sid
    local after = g("C_Timer") and C_Timer.After
    if type(after) == "function" then after(0.5, function() pcall(C.Run, "combat") end) end
end)
