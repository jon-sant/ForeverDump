-- ForeverDump v2.2 - FD_Logs: ONE macro that captures everything.  /fdump logs [on|off|status|macro]
--
-- Click ON  (out of combat): client logging (combat log, chat log, advancedCombatLogging, scriptErrors, taintLog),
--           event recorder, combat recorder, error capture, out-of-combat probe, profiler snapshot; queues
--           /fdump all if this build has no full dump yet. The first PLAYER_REGEN_DISABLED of each recording
--           session takes an in-combat probe automatically. Survives /reload: recording resumes after login.
-- Click OFF (out of combat): stops the recorders (combat recorder takes its damage meter snapshot), final
--           probe + profiler snapshot, logging off (CVars restored, taintLog 0), summary - ALL synchronously,
--           because the macro's last line is /reload, which saves SavedVariables right after this handler.
--
-- Macro body (rewritten by the addon after every click, out of combat; EditMacro is refused in combat):
--   /fdump logs
--   /stopmacro [combat]      <- secure command; in combat nothing below runs (addon also refuses in combat)
--   /combatlog               <- only if the combat log is not yet in the target state (Blizzard toggle)
--   /chatlog                 <- only if the chat log is not yet in the target state (Blizzard toggle)
--   /reload                  <- only while capture is ON, i.e. on the OFF click
-- The addon never calls LoggingCombat/LoggingChat itself by default (protection unverified on Forever; a blocked
-- call shows a popup). /combatlog and /chatlog run in Blizzard's handlers on a human click. No /run is used,
-- so GetScriptsDisallowedForBeta() does not matter.  /stopmacro, /reload, /combatlog, /chatlog verified in
-- Blizzard_ChatFrameBase/Shared/SlashCommands.lua (forever branch, build 70245).
local _, ns = ...
local Logs = {}
ns.Logs = Logs

local MACRO_NAME = "FD_Logs"
local MACRO_ICON = "INV_Misc_Note_01"
local MAX_MACRO_CHARS = 255
local pendingMacro = false
-- v2.2.9: one deferred macro refresh at a time (FD_Logs click, or a /combatlog|/chatlog system message)
local refreshQueued = false
local combatProbed = false

local function cfg() return ns.config.logs end
local function state()
    if type(ns.db.logs) ~= "table" then ns.db.logs = { on = false } end
    return ns.db.logs
end
local function now() return time and time() or nil end

local function cvarGet(name)
    local C = rawget(_G, "C_CVar")
    local f = (type(C) == "table" and C.GetCVar) or rawget(_G, "GetCVar")
    if type(f) ~= "function" then return nil end
    local ok, v = pcall(f, name)
    if ok and not ns.IsSecret(v) then return v end
end

local function cvarSet(name, value)
    local C = rawget(_G, "C_CVar")
    local f = (type(C) == "table" and C.SetCVar) or rawget(_G, "SetCVar")
    if type(f) ~= "function" then return false, "SetCVar missing" end
    local ok, res = pcall(f, name, tostring(value))
    if ok and res == false then return false, "SetCVar returned false" end
    return ok, res
end

-- Current client logging state; nil when not readable (never calls LoggingCombat/LoggingChat unless allowed).
function Logs.ClientState()
    local C = rawget(_G, "C_ChatInfo")
    local combat, chat
    if type(C) == "table" and type(C.IsLoggingCombat) == "function" then
        local ok, v = pcall(C.IsLoggingCombat)
        if ok and not ns.IsSecret(v) then combat = v end
    end
    if type(C) == "table" and type(C.IsLoggingChat) == "function" then
        local ok, v = pcall(C.IsLoggingChat)
        if ok and not ns.IsSecret(v) then chat = v end
    end
    if cfg().callLogging then
        local lc, lch = rawget(_G, "LoggingCombat"), rawget(_G, "LoggingChat")
        if combat == nil and type(lc) == "function" then
            local ok, v = pcall(lc) if ok then combat = v end
        end
        if chat == nil and type(lch) == "function" then
            local ok, v = pcall(lch) if ok then chat = v end
        end
    end
    return combat, chat
end

-- Macro body for the NEXT click (target = not state().on).
function Logs.MacroBody(target)
    if target == nil then target = not state().on end
    local combat, chat = Logs.ClientState()
    local lines = { "/fdump logs", "/stopmacro [combat]" }
    if not cfg().callLogging then
        if combat == nil or combat ~= target then lines[#lines + 1] = "/combatlog" end
        if cfg().chat and (chat == nil or chat ~= target) then lines[#lines + 1] = "/chatlog" end
    end
    if not target and cfg().autoReload then lines[#lines + 1] = "/reload" end
    local body = table.concat(lines, "\n")
    assert(#body <= MAX_MACRO_CHARS)
    return body
end

local function maxAccountMacros()
    local v = rawget(_G, "MAX_ACCOUNT_MACROS")
    if type(v) ~= "number" and type(rawget(_G, "Constants")) == "table" and type(Constants.MacroConsts) == "table" then
        v = Constants.MacroConsts.MAX_ACCOUNT_MACROS
    end
    return type(v) == "number" and v or 120
end

-- Create or update FD_Logs. onlyUpdate: never create (used at login). Out of combat only.
function Logs.EnsureMacro(silent, onlyUpdate)
    local getIndex, create, edit, num = rawget(_G, "GetMacroIndexByName"), rawget(_G, "CreateMacro"),
        rawget(_G, "EditMacro"), rawget(_G, "GetNumMacros")
    if type(getIndex) ~= "function" or type(create) ~= "function" or type(edit) ~= "function" then
        ns.db.macro = { ok = false, err = "macro API missing", time = now() }
        if not silent then ns.Print("FD_Logs: macro API missing on this client.") end
        return false, "macro API missing"
    end
    local okI, index = pcall(getIndex, MACRO_NAME)
    index = okI and tonumber(index) or 0
    if onlyUpdate and index == 0 then return false, "no macro" end
    local rec = { time = now() }
    ns.db.macro = rec
    if ns.InCombat() then
        pendingMacro = true
        rec.ok, rec.err = false, "in combat (deferred until PLAYER_REGEN_ENABLED)"
        if not silent then ns.Print("FD_Logs: can't edit macros in combat; will update after combat.") end
        return false, rec.err
    end
    local body = Logs.MacroBody()
    rec.body, rec.chars = body, #body
    if index > 0 then
        local ok, res = pcall(edit, index, MACRO_NAME, MACRO_ICON, body)
        rec.ok, rec.action, rec.index = ok, "updated", ok and res or index
        if not ok then rec.err = tostring(res) end
    else
        local numAccount = 0
        if type(num) == "function" then
            local okN, a = pcall(num)
            numAccount = okN and tonumber(a) or 0
        end
        local max = maxAccountMacros()
        rec.slots = { used = numAccount, max = max }
        if numAccount >= max then
            rec.ok, rec.err = false, string.format("no free account macro slot (%d/%d)", numAccount, max)
            ns.Print("FD_Logs: " .. rec.err .. ". Delete a general macro and try again.")
            return false, rec.err
        end
        local ok, res = pcall(create, MACRO_NAME, MACRO_ICON, body, nil) -- nil = account-wide (General tab)
        rec.ok, rec.action, rec.index = ok and res ~= nil, "created", res
        if not ok then rec.err = tostring(res) elseif res == nil then rec.err = "CreateMacro returned nil" end
    end
    pendingMacro = not rec.ok
    if not silent or not rec.ok then
        ns.Print(string.format("FD_Logs macro %s%s. Drag it from /macro (General tab) to a bar: click = capture everything, "
            .. "click again = stop, save and /reload.", rec.ok and (rec.action or "ok") or "FAILED", rec.err and (": " .. rec.err) or ""))
    end
    return rec.ok, rec.err
end

local function setCVars(target, changes)
    local s, c = state(), cfg()
    local function setCVar(name, value)
        local before = cvarGet(name)
        if before == nil then changes[#changes + 1] = name .. " missing" return end
        if tostring(before) == tostring(value) then return before end
        local ok, err = cvarSet(name, value)
        local after = cvarGet(name)
        if ok and tostring(after) == tostring(value) then
            changes[#changes + 1] = string.format("%s %s->%s", name, tostring(before), tostring(value))
        else
            changes[#changes + 1] = string.format("|cffff5555%s not set (%s)|r", name, tostring(err or after))
        end
        return before
    end
    if target then
        local fresh = s.saved == nil -- keep the pre-ON values if ON is requested twice
        s.saved = s.saved or {}
        if c.advanced then
            local before = setCVar("advancedCombatLogging", 1)
            if fresh then s.saved.advancedCombatLogging = before end
        end
        if c.scriptErrors then
            local before = setCVar("scriptErrors", 1)
            if fresh then s.saved.scriptErrors = before end
        end
        local debugOn = ns.Controls and ns.Controls.DebugOn()
        if c.taintLog and c.taintLog > 0 and not debugOn then
            local before = setCVar("taintLog", c.taintLog)
            if fresh then s.saved.taintLog = before end
        end
    else
        local saved = s.saved or {}
        if c.advanced then setCVar("advancedCombatLogging", saved.advancedCombatLogging or "0") end
        if c.scriptErrors then setCVar("scriptErrors", saved.scriptErrors or "0") end
        if not (ns.Controls and ns.Controls.DebugOn()) then setCVar("taintLog", saved.taintLog or 0) end
        s.saved = nil
    end
    if c.callLogging then
        local lc, lch = rawget(_G, "LoggingCombat"), rawget(_G, "LoggingChat")
        if type(lc) == "function" then
            local ok, err = pcall(lc, target)
            if not ok then changes[#changes + 1] = "|cffff5555LoggingCombat failed: " .. tostring(err) .. "|r" end
        end
        if c.chat and type(lch) == "function" then
            local ok, err = pcall(lch, target)
            if not ok then changes[#changes + 1] = "|cffff5555LoggingChat failed: " .. tostring(err) .. "|r" end
        end
    end
end

-- Is there a full dump (docs + api sections) for the running build?
function Logs.HaveFullDump()
    if ns.Static then return ns.Static.Done() end   -- v2.2.7: the static marker for this client signature decides
    local secs = ns.db.sections or {}
    local build = ns.Build()
    for _, name in ipairs({ "docs", "api", "globals", "widgets" }) do
        local sct = secs[name]
        if type(sct) ~= "table" or type(sct.meta) ~= "table" or sct.meta.build ~= build then return false end
    end
    return true
end

-- v2.2.11 (user decision): FD_Logs ON starts every capture CLEAN. Wiped: all of ForeverDumpLogDB (replay tape/sessions,
-- HSM inference + signals + history, damage meter evidence, world capture, perf, restrictions, controls/lab/probes,
-- tokens, containers, identity, baseline signature, errors/blocked/handler events, counters), the event recorder and
-- combat recorder sessions, and the per-capture observations in ForeverDumpDB (verify rings, secretsObs/secretsLive,
-- tokenscan, raw identities, the probe/profile sections). KEPT: the persistent learned store (ForeverDumpDB.learned,
-- knowledge, timing, drift, baselines = per-build versioned values + drift history), config/macro/state/markers, and
-- ForeverDumpStaticDB (only /fdump static clear empties it). Runs only from the ON branch, which refuses in combat;
-- cost = dropping a few table references (O(number of top-level keys), the GC frees the rest later).
Logs.WIPE_DB = { "verify", "secretsObs", "secretsLive", "tokenscan", "identities" }
Logs.WIPE_SECTIONS = { "probe", "profile" }
Logs.KEEP_DB = { "learned", "knowledge", "timing", "drift", "baselines", "config", "macro", "logs", "static", "sections",
    "history", "meta", "blockedPaths", "hsmUI", "lastClientBuild", "lastBaselineBuild", "sessionCounter", "schemaVersion",
    "addonVersion", "svpack", "svunpack" }
function Logs.WipeCaptureData()
    if ns.InCombat() then return nil, "in combat" end
    local wiped, n = {}, 0
    -- recorders that a manual /fdump record|cl start left running would keep writing into dropped tables: stop first
    if ns.Recorder and ns.Recorder.IsActive() then pcall(ns.Recorder.Stop) end
    if ns.CombatLog and ns.CombatLog.IsActive() then pcall(ns.CombatLog.Stop) end
    local perfOn = ns.Perf and ns.Perf.on
    if perfOn then pcall(ns.Perf.Stop) end
    local log = rawget(_G, "ForeverDumpLogDB")
    if type(log) == "table" then
        for k in pairs(log) do if k ~= "schemaVersion" then n = n + 1 end end
        wiped[#wiped + 1] = n .. " log tables"
    end
    ForeverDumpLogDB = { schemaVersion = ns.SCHEMA }
    if ns.Errors and ns.Errors.MarkBugGrabberSeen then pcall(ns.Errors.MarkBugGrabberSeen) end
    local rs = rawget(_G, "ForeverDumpRecordDB")
    local cs = rawget(_G, "ForeverDumpCombatLogDB")
    local nr = type(rs) == "table" and type(rs.sessions) == "table" and #rs.sessions or 0
    local nc = type(cs) == "table" and type(cs.sessions) == "table" and #cs.sessions or 0
    ForeverDumpRecordDB = { schemaVersion = ns.SCHEMA, sessions = {} }
    ForeverDumpCombatLogDB = { schemaVersion = ns.SCHEMA, sessions = {} }
    wiped[#wiped + 1] = string.format("%d recorder + %d combat session(s)", nr, nc)
    local db, nd = ns.db, 0
    if type(db) == "table" then
        for _, k in ipairs(Logs.WIPE_DB) do if rawget(db, k) ~= nil then db[k] = nil nd = nd + 1 end end
        if type(db.sections) == "table" then
            for _, k in ipairs(Logs.WIPE_SECTIONS) do if rawget(db.sections, k) ~= nil then rawset(db.sections, k, nil) nd = nd + 1 end end
        end
    end
    wiped[#wiped + 1] = nd .. " observation store(s) (verify, secrets obs, token scan, identities, probe/profile)"
    ns.InitDB()   -- recreate the empty structure (errors/blocked/... tables, sessions lists)
    if perfOn then pcall(ns.Perf.Start) end
    local line = "previous capture data wiped: " .. table.concat(wiped, ", ")
        .. "; kept: learned store (learned/knowledge/timing/drift/baselines) and static client data"
    return line, wiped
end

-- start every recorder that is not running yet; returns list of what was started
local function startCapture(why)
    local c, started = cfg(), {}
    combatProbed = false
    if c.errors and ns.Errors then
        ns.config.errors.enabled = true
        if not ns.Errors.IsInstalled() then ns.Errors.Install() end
        started[#started + 1] = "error capture"
    end
    if c.recorder and ns.Recorder and not ns.Recorder.IsActive() then
        ns.Recorder.Start()
        if ns.Recorder.IsActive() then started[#started + 1] = "event recorder" end
    end
    if c.combat and ns.CombatLog and not ns.CombatLog.IsActive() then
        ns.CombatLog.Start({})
        if ns.CombatLog.IsActive() then started[#started + 1] = "combat recorder" end
    end
    if c.sweep and ns.Secrets and ns.config.secrets.sweep and not ns.Secrets.IsSweeping() then
        if ns.Secrets.StartSweep() then started[#started + 1] = "secrets verifier sweep" end
    end
    if ns.RecordIdentity and ns.RecordIdentity("capture:" .. tostring(why)) then started[#started + 1] = "player identity" end
    if why == "on" and ns.Restrictions and ns.config.restrictions and ns.config.restrictions.enabled ~= false then
        local okR = pcall(ns.Restrictions.Begin, ns.db.logs and ns.db.logs.session and ns.db.logs.session.sid)
        if okR then started[#started + 1] = "restrictions tracker" end
    end
    if why == "on" and ns.Controls and ns.config.secrets.controls ~= false then
        local okC = pcall(ns.Controls.Run, "capture:on")
        if okC then started[#started + 1] = "secrets controls" end
    end
    if why == "on" and ns.Lab and ns.config.lab.auto ~= false then
        local okL = pcall(ns.Lab.Run, "capture:on")
        if okL then started[#started + 1] = "workarounds lab" end
    end
    if why == "on" then
        -- v2.2 capture modules (combat probe set, token survey, knowledge + HSM inference, HSM window): always on
        if ns.Perf and ns.Perf.Mark then pcall(ns.Perf.Mark, "capture:begin") end
        for _, m in ipairs(ns.captureModules or {}) do
            local okM, res = pcall(m.start, why)
            if okM and res then started[#started + 1] = m.name
            elseif not okM then ns.NoteSelfError("capture:" .. m.name, res) end
            if ns.Perf and ns.Perf.Mark then pcall(ns.Perf.Mark, "start:" .. tostring(m.name)) end
        end
    end
    if ns.Lab and ns.config.lab.poll and not ns.Lab.Polling() then
        ns.Lab.StartPoll()
        started[#started + 1] = "secrecy polling " .. tostring(ns.config.lab.pollInterval) .. "s"
    end
    if why == "on" then
        if c.probe and ns.Probe then
            local ok = pcall(ns.Probe.Run, "capture:on", "outOfCombat", true)
            if ok then started[#started + 1] = "probe (out of combat)" end
        end
        if c.profile and ns.Profiler then
            local ok = pcall(ns.Profiler.Snapshot, "capture:on")
            if ok then started[#started + 1] = "profiler snapshot" end
        end
    end
    return started
end

local function lastSession(db)
    local list = db and db.sessions
    return type(list) == "table" and list[#list] or nil
end

-- running totals over all segments of one capture (a /reload splits a capture into several sessions)
local function addTotals(key, n)
    local sess = ns.db.logs and ns.db.logs.session
    if not sess then return end
    sess.totals = sess.totals or {}
    sess.totals[key] = (sess.totals[key] or 0) + (n or 0)
end

local function stopCapture(reason)
    local c, out = cfg(), {}
    if ns.NoteUISig then pcall(ns.NoteUISig, "capture:off") end
    if ns.CombatLog and ns.CombatLog.IsActive() then
        ns.CombatLog.Stop()  -- includes the post-combat C_DamageMeter snapshot when out of combat
        local cs = lastSession(ForeverDumpCombatLogDB)
        if cs then
            cs.endedBy = reason
            addTotals("combatEvents", cs.total) addTotals("unitEvents", cs.combatEvents)
            addTotals("secretEntries", cs.secretEntries) addTotals("combatSessions", 1)
            addTotals("damageMeter", cs.damageMeter and #cs.damageMeter or 0)
            out.combat = string.format("combat recorder %d events (%d UNIT_COMBAT/UNIT_SPELLCAST, %d with secrets, %d damage meter snapshot(s))",
                cs.total or 0, cs.combatEvents or 0, cs.secretEntries or 0, cs.damageMeter and #cs.damageMeter or 0)
        end
    end
    if ns.Recorder and ns.Recorder.IsActive() then
        ns.Recorder.Stop()
        local rs = lastSession(ForeverDumpRecordDB)
        if rs then
            rs.endedBy = reason
            addTotals("recordEvents", rs.total) addTotals("recordSessions", 1)
            out.record = string.format("event recorder %d events (%d kept)", rs.total or 0, rs.kept or 0)
        end
    end
    if ns.Secrets and ns.Secrets.IsSweeping() then
        local n = ns.Secrets.StopSweep()
        out.sweep = string.format("secrets sweep %d getter calls", n or 0)
    end
    if ns.Lab and ns.Lab.Polling() then ns.Lab.StopPoll() end
    if reason == "off" and ns.Controls and ns.config.secrets.controls ~= false then pcall(ns.Controls.Run, "capture:off") end
    for _, m in ipairs(ns.captureModules or {}) do
        local okM, res = pcall(m.stop, reason)
        if okM and type(res) == "string" then
            out["module:" .. m.name] = res
            if type(m.name) == "string" and m.name:find("replay", 1, true) then out.replay = res end
        end
    end
    if ns.Baseline then
        local okB, sig = pcall(ns.Baseline.Capture, reason)
        if okB and sig then out.baseline = string.format("baseline signature v%d for build %s", sig.v, tostring(sig.build)) end
    end
    if reason == "off" and ns.Restrictions then
        local okR, rs = pcall(ns.Restrictions.End)
        if okR and rs then out.restrictions = string.format("restrictions %d flip(s), %d context marker(s)", rs.flips or 0, rs.markers or 0) end
        local okH, h = pcall(ns.Restrictions.Health)
        if okH then out.health = h end
    end
    if reason == "off" then
        if c.probe and ns.Probe then pcall(ns.Probe.Run, "capture:off", "outOfCombatEnd", true) end
        if c.profile and ns.Profiler then pcall(ns.Profiler.Snapshot, "capture:off") end
        if ns.Errors and ns.Errors.BugGrabber() then
            local okBG, r = pcall(ns.Errors.ImportBugGrabber, "capture:off")
            if okBG and r then out.bugGrabber = string.format("BugGrabber %d session error(s) copied", #r.errors) end
        end
    end
    return out
end

local function errorCounts()
    local log = ForeverDumpLogDB or {}
    local unique, total, mine = 0, 0, 0
    for _, e in ipairs(log.errors or {}) do
        unique, total = unique + 1, total + (e.count or 1)
        if (ns.Errors and ns.Errors.IsOwn and ns.Errors.IsOwn(e)) or e.addon == ns.ADDON then mine = mine + 1 end
    end
    return unique, total, #(log.blocked or {}), mine
end

local function onOff(v) if v == nil then return "unknown" end return v and "ON" or "OFF" end

function Logs.Set(target, source)
    local s, c = state(), cfg()
    if ns.InCombat() then
        s.lastRefused = { time = now(), target = target, source = source }
        ns.Print(string.format("|cffff5555FD_Logs: in combat - capture stays %s.|r The macro stops before its log toggles%s; "
            .. "click FD_Logs again after combat.", onOff(s.on), target and "" or " and /reload"))
        return false
    end
    -- v2.2.9 (run 8): /combatlog and /chatlog are TOGGLES baked into the macro when it was last written. If the user
    -- switched a log by hand since then, this click flips it the wrong way (run 8: the BG combat log was switched OFF
    -- at ON). Read the state BEFORE the macro's toggle lines run and say so loudly.
    local clickBody = (source == "toggle" and ns.db.macro and type(ns.db.macro.body) == "string") and ns.db.macro.body or ""
    local preCombat, preChat = Logs.ClientState()
    local flipsWrong = {}
    if clickBody:find("/combatlog", 1, true) and preCombat == target then flipsWrong[#flipsWrong + 1] = "combat log" end
    if clickBody:find("/chatlog", 1, true) and preChat == target then flipsWrong[#flipsWrong + 1] = "chat log" end
    s.staleToggle = (#flipsWrong > 0) and { time = now(), target = target, logs = flipsWrong } or nil
    if #flipsWrong > 0 then
        ns.Print(string.format("|cffff5555FD_Logs: the %s was already %s, so this click's macro line switches it %s.|r "
            .. "Type /%s once%s.", table.concat(flipsWrong, " and "), onOff(target), onOff(not target),
            flipsWrong[1] == "combat log" and "combatlog" or "chatlog", target and " right after this" or " after the reload"))
    end
    local changes = {}
    setCVars(target, changes)
    if target then
        -- v2.2.11: every capture starts clean (see Logs.WipeCaptureData); the OFF branch never wipes
        local wipeLine = Logs.WipeCaptureData()
        if wipeLine then ns.Print(wipeLine) end
        s = state()
        s.on = true
        s.session = { startedAt = now(), date = date and date("%Y-%m-%d %H:%M:%S") or nil, build = ns.Build(),
            resumes = 0, combatProbes = 0, sid = ns.NewSessionId("cap"), anchor = ns.TimeAnchor(), anchors = {},
            verbosity = (ns.ReplayLog and ns.ReplayLog.Level and ns.ReplayLog.Level()) or "release",
            captureLevel = (ns.config.replay and ns.config.replay.captureLevel) or "lab" }
        if ns.ReplayLog and ns.ReplayLog.ElevateForCapture then ns.ReplayLog.ElevateForCapture() end
        if ns.NoteUISig then pcall(ns.NoteUISig, "capture:on:before") end
        local started = startCapture("on")
        if ns.NoteUISig then pcall(ns.NoteUISig, "capture:on:after") end
        if s.session and ns.ReplayLog and ns.ReplayLog.Level then
            s.session.verbosity = ns.ReplayLog.Level()
            s.session.captureElevated = true
        end
        -- v2.2.7: ON never queues the static dump. It runs once per new client signature at login, automatically, only
        -- when idle and never inside a capture (Static.lua); ON just records where it stands.
        local staticState = ns.Static and ns.Static.state and ns.Static.state.phase or nil
        s.lastToggle = { time = now(), source = source, target = true, changes = changes, started = started, static = staticState }
        ns.Print(string.format("|cff33ff99ForeverDump " .. ns.VERSION .. " logging: ON|r - %s%s", table.concat(started, ", "),
            (#changes > 0) and ("; " .. table.concat(changes, ", ")) or ""))

        ns.Print("Play normally (combat, buffs, whatever you are testing), then click FD_Logs again to stop, save and reload. "
            .. "Before that click: /fdump errors show + screenshot (OFF reloads, no separate /reload).")
        -- the macro's /combatlog and /chatlog lines run right after this: verify, then rewrite the macro for OFF
        local after = rawget(_G, "C_Timer") and C_Timer.After
        local function verify()
            local combat, chat = Logs.ClientState()
            s.client = { combat = combat, chat = chat, checked = now() }
            local bad = {}
            if combat == false then
                bad[#bad + 1] = (s.staleToggle and clickBody:find("/combatlog", 1, true))
                    and "combat log is OFF - FD_Logs switched it off because it was already on (type /combatlog once NOW)"
                    or "combat log is OFF (type /combatlog once)"
            end
            if c.chat and chat == false then bad[#bad + 1] = "chat log is OFF (type /chatlog once)" end
            s.mismatch = #bad > 0 or nil
            refreshQueued = false
            ns.Print(string.format("ForeverDump logging: combat log %s -> Logs/WoWCombatLog*.txt%s%s", onOff(combat),
                c.chat and (", chat log " .. onOff(chat)) or "", #bad > 0 and (" |cffff5555" .. table.concat(bad, "; ") .. "|r") or ""))
            Logs.EnsureMacro(true)
        end
        if type(after) == "function" then refreshQueued = true after(0.3, verify) else verify() end
    else
        -- everything below is synchronous: the macro's next lines may be /combatlog, /chatlog and /reload
        local wasOn = s.on
        local stoppedOut = stopCapture("off")
        s.on = false
        local t = (s.session and s.session.totals) or {}
        local stopped = {
            combat = string.format("combat recorder %d events in %d session(s) (%d UNIT_COMBAT/UNIT_SPELLCAST, %d with secrets, "
                .. "%d damage meter snapshot(s))", t.combatEvents or 0, t.combatSessions or 0, t.unitEvents or 0,
                t.secretEntries or 0, t.damageMeter or 0),
            record = string.format("event recorder %d events in %d session(s)", t.recordEvents or 0, t.recordSessions or 0),
        }
        local unique, total, blocked, mine = errorCounts()
        local combat, chat = Logs.ClientState()
        local body = ns.db.macro and ns.db.macro.body or ""
        local fromMacro = source == "toggle" and body:find("/reload", 1, true) ~= nil
        local sess = s.session or {}
        local summary = {
            time = now(), source = source, changes = changes, combatProbes = sess.combatProbes, resumes = sess.resumes,
            totals = t, errors = unique, errorTotal = total, blocked = blocked,
            ownErrors = mine, combatLog = combat, chatLog = chat, reloading = fromMacro,
            durationSec = sess.startedAt and now() and (now() - sess.startedAt) or nil,
            sid = sess.sid, health = stoppedOut.health, restrictions = stoppedOut.restrictions,
            verbosity = sess.verbosity,
            replay = stoppedOut.replay,
        }
        s.lastSession, s.session = summary, nil
        s.lastToggle = { time = now(), source = source, target = false, changes = changes }
        s.verifyAfterLogin = true
        -- v2.2.11: warn once if the file the client is about to write could still exceed its Lua constant limit
        if ns.SVPack then pcall(ns.SVPack.GuardAtOff) end
        ns.Print(string.format("|cff33ff99ForeverDump " .. ns.VERSION .. " logging: OFF|r%s - %s; %s; %d Lua error(s) (%d unique, %d from ForeverDump), "
            .. "%d blocked/warning event(s); in-combat probes %d%s",
            wasOn and "" or " (was already off)", stopped.combat, stopped.record, total, unique, mine, blocked, sess.combatProbes or 0,
            (#changes > 0) and ("; " .. table.concat(changes, ", ")) or ""))
        if stoppedOut.restrictions then ns.Print(stoppedOut.restrictions) end
        if ns.Restrictions then local okT, ht = pcall(ns.Restrictions.HealthText) if okT then ns.Print(ht) end end
        stopped.bugGrabber = stoppedOut.bugGrabber
        if stopped.bugGrabber then ns.Print(stopped.bugGrabber .. " into ForeverDumpLogDB.bugGrabber") summary.bugGrabber = stopped.bugGrabber end
        local fileNote = (combat and (body:find("/combatlog", 1, true) and source == "toggle")) and "being switched OFF by FD_Logs"
            or onOff(combat)
        ns.Print(string.format("combat log file: %s (Logs\\WoWCombatLog*.txt is complete once the client flushes it on toggle/logout)%s",
            fileNote, (chat and not body:find("/chatlog", 1, true)) and "; chat log still ON (type /chatlog)" or ""))
        if fromMacro then
            ns.Print("|cff33ff99Saving: FD_Logs reloads the UI now.|r Then send WTF\\...\\SavedVariables\\ForeverDump.lua and the Logs folder files.")
        else
            ns.Print("|cffffff00Type /reload (or log out) now|r so the client writes SavedVariables\\ForeverDump.lua.")
        end
        -- if no reload follows (typed command), rewrite the macro a moment later
        local after = rawget(_G, "C_Timer") and C_Timer.After
        if type(after) == "function" then
            refreshQueued = true   -- the click's own /chatlog|/combatlog system message must not queue a second refresh
            after(0.3, function() refreshQueued = false Logs.EnsureMacro(true, true) end)
        end
    end
    return true
end

function Logs.Toggle(source) return Logs.Set(not state().on, source or "toggle") end

-- v2.2.20 (run 15: a whole v2.2.19 battleground went uncaptured - the capture was never switched on, the SV only held
-- run 14): entering a battleground / arena with the capture OFF -> one reminder line in ForeverDump's own message
-- frame (logs.bgReminder, default on; never a Blizzard chat frame) and, opt-in (logs.autoBG), start the capture.
function Logs.OnEnterWorld()
    local c = cfg()
    if state().on then return nil end
    local f = rawget(_G, "IsInInstance")
    if type(f) ~= "function" then return nil end
    local ok, _, it = pcall(f)
    local kind = ok and ns.ClearStr(it) or nil
    -- v2.2.25 (all-environment directive): dungeons / raids / scenarios get the same one-line reminder; autoBG
    -- (auto start) stays battleground + arena only
    local pvpKind = kind == "pvp" or kind == "arena"
    if not pvpKind and kind ~= "party" and kind ~= "raid" and kind ~= "scenario" then return nil end
    local s = state()
    s.bgSeenOff = { time = now(), kind = kind, auto = pvpKind and c.autoBG == true }
    if pvpKind and c.autoBG == true then
        local after = rawget(_G, "C_Timer") and C_Timer.After
        local function go()
            if not state().on and not ns.InCombat() then Logs.Set(true, "autoBG") end
        end
        if after then after(3, go) else go() end
        return "auto"
    end
    if c.bgReminder ~= false then
        local what = kind == "pvp" and "Battleground" or kind == "arena" and "Arena" or kind == "raid" and "Raid"
            or "Dungeon"
        ns.Print("|cffffcc00" .. what .. " entered with capture OFF.|r Click FD_Logs to capture it "
            .. "(or /fdump set logs.autoBG true to start automatically).")
        return "reminder"
    end
    return nil
end
if ns.On then ns.On("PLAYER_ENTERING_WORLD", function() pcall(Logs.OnEnterWorld) end) end

function Logs.Status()
    local s = state()
    local combat, chat = Logs.ClientState()
    local m = ns.db.macro or {}
    ns.Print(string.format("capture: %s%s; client combat log %s, chat log %s; advancedCombatLogging=%s scriptErrors=%s taintLog=%s; "
        .. "event recorder %s, combat recorder %s; macro FD_Logs: %s",
        s.on and "ON" or "OFF", (s.session and s.session.resumes and s.session.resumes > 0) and (" (resumed " .. s.session.resumes .. "x)") or "",
        onOff(combat), onOff(chat), tostring(cvarGet("advancedCombatLogging")), tostring(cvarGet("scriptErrors")),
        tostring(cvarGet("taintLog")), onOff(ns.Recorder and ns.Recorder.IsActive()), onOff(ns.CombatLog and ns.CombatLog.IsActive()),
        m.ok and (m.action or "ok") or (m.err or "not created")))
end

function Logs.Command(rest)
    local sub = string.lower(rest[1] or "")
    if sub == "" or sub == "toggle" then Logs.Toggle("toggle")
    elseif sub == "on" then Logs.Set(true, "slash")
    elseif sub == "off" then Logs.Set(false, "slash")
    elseif sub == "macro" or sub == "macros" then Logs.EnsureMacro()
    else Logs.Status() end
end

-- in-combat probe at the first combat of each recording session
ns.On("PLAYER_REGEN_DISABLED", function()
    local s = ns.db and ns.db.logs
    if not (s and s.on and cfg().combatProbe and ns.Probe) or combatProbed then return end
    combatProbed = true
    if s.session then s.session.combatProbes = (s.session.combatProbes or 0) + 1 end
    local after = rawget(_G, "C_Timer") and C_Timer.After
    local function run() if ns.InCombat() then pcall(ns.Probe.RunStaged, "capture:combat", "inCombat", true) end end   -- v2.2.15: one step per frame
    if type(after) == "function" then after(1, run) else run() end
end)

ns.On("PLAYER_REGEN_ENABLED", function()
    if pendingMacro then Logs.EnsureMacro(true) end
end)

-- /reload or logout: save running recorder sessions (they would otherwise be lost)
-- v2.2.9: a hand-typed /combatlog or /chatlog changes what the next FD_Logs click must toggle; refresh the macro
-- body (out of combat; EnsureMacro defers in combat) so it never carries a stale toggle line.
local LOG_MSGS = { "COMBATLOGENABLED", "COMBATLOGDISABLED", "CHATLOGENABLED", "CHATLOGDISABLED" }
local LOG_PATTERNS = { "^Combat being logged", "^Combat logging disabled", "^Chat being logged", "^Chat logging disabled" }
function Logs.IsLogToggleMessage(msg)
    if type(msg) ~= "string" or ns.IsSecret(msg) then return false end
    for _, k in ipairs(LOG_MSGS) do
        local gs = rawget(_G, k)
        if type(gs) == "string" and not ns.IsSecret(gs) and gs ~= "" and msg == gs then return true end
    end
    for _, p in ipairs(LOG_PATTERNS) do if string.find(msg, p) then return true end end
    return false
end
ns.On("CHAT_MSG_SYSTEM", function(_, msg)
    if refreshQueued or not ns.db or not Logs.IsLogToggleMessage(msg) then return end
    refreshQueued = true
    local function refresh() refreshQueued = false Logs.EnsureMacro(true, true) end
    local after = rawget(_G, "C_Timer") and C_Timer.After
    if type(after) == "function" then after(0.2, refresh) else refresh() end
end)

ns.On("PLAYER_LOGOUT", function()
    if not ns.db then return end
    stopCapture("logout")
end)

-- login / after reload: resume capture if it was ON, verify an OFF, refresh the macro body
ns.On("PLAYER_LOGIN", function()
    if not ns.db then return end
    local s = state()
    if s.on then
        s.session = s.session or { startedAt = now(), resumes = 0, combatProbes = 0 }
        s.session.resumes = (s.session.resumes or 0) + 1
        s.session.anchors = s.session.anchors or {}
        if #s.session.anchors < 50 then s.session.anchors[#s.session.anchors + 1] = ns.TimeAnchor() end
        local started = startCapture("resume")
        ns.Print(string.format("|cff33ff99ForeverDump capture is still ON|r (resumed after reload: %s). Click FD_Logs to stop, save and reload.",
            table.concat(started, ", ")))
    elseif s.verifyAfterLogin then
        s.verifyAfterLogin = nil
        local combat, chat = Logs.ClientState()
        local bad = {}
        if combat then bad[#bad + 1] = "combat log still ON (type /combatlog)" end
        if cfg().chat and chat then bad[#bad + 1] = "chat log still ON (type /chatlog)" end
        ns.Print(string.format("ForeverDump " .. ns.VERSION .. ": capture OFF, files saved (combat log %s, chat log %s)%s", onOff(combat), onOff(chat),
            #bad > 0 and (" |cffff5555" .. table.concat(bad, "; ") .. "|r") or ". Send SavedVariables\\ForeverDump.lua + Logs\\ files."))
    end
    local after = rawget(_G, "C_Timer") and C_Timer.After
    if type(after) == "function" then after(2, function() Logs.EnsureMacro(true, true) end) else Logs.EnsureMacro(true, true) end
end)
