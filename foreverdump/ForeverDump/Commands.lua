-- ForeverDump v2 - slash commands. `/fdump` alone keeps the v1 behaviour.
local _, ns = ...

local ALL_ORDER = { "docs", "api", "globals", "strings", "widgets", "templates", "frames", "addons",
                    "cvars", "protected", "secrets", "extras" }

function ns.RunAll()   -- v2.2.11: static sections excluded (only /fdump static run collects them)
    for _, name in ipairs(ALL_ORDER) do
        if not (ns.Static and ns.Static.IsStatic(name)) then ns.RunSection(name) end
    end
end

local function help()
    local p = ns.Print
    p("v" .. ns.VERSION .. " commands (/fdump or /foreverdump):")
    p("  /fdump                 v1 quick dump (APIs, events, enums, CVars) + copy window")
    p("  /fdump all [full]      every section below in order, chunked (out of combat); compact by default, 'full' = everything")
    p("                         (static client data is NOT included: only /fdump static run collects it)")
    p("  /fdump static [status|run|check|clear]   run (= force) collects static client data -> ForeverDumpStaticDB, the")
    p("                         only way it is ever collected; it persists in the saved file until /fdump static clear")
    for _, name in ipairs(ns.sectionOrder) do
        local def = ns.sections[name]
        p(string.format("  /fdump %-15s %s", name, def.desc or ""))
    end
    p("  /fdump record start|stop|status   event recorder (combat-safe)")
    p("  /fdump cl start [file]|stop|status   combat recorder: UNIT_COMBAT, UNIT_SPELLCAST_*, PLAYER_SWING,")
    p("                         COMBAT_TEXT_UPDATE, encounter/regen context, post-combat C_DamageMeter snapshot;")
    p("                         'file' sets advancedCombatLogging; the log file itself: FD_Logs macro or /combatlog")
    p("  /fdump cl cleu-force   legacy CLEU capture - refused unless CombatLogGetCurrentEventInfo exists and the")
    p("                         combat log is unrestricted; restricted clients show a 'disable addon' popup")
    p("  /fdump logs macro      create the account macro FD_Logs - THE way to use ForeverDump: click = capture everything")
    p("                         (all logs, recorders, probes, errors, profiler, full dump if needed); click again = stop, save, /reload")
    p("  /fdump logs [on|off|status]   the same toggle without the macro (no /combatlog, /chatlog, /reload lines)")
    p("  /fdump restrictions [probe]   addon restriction states (C_RestrictedActions) + flips logged; probe = flip probe set now")
    p("  /fdump secrets controls | forced   controls + ops matrix now | opt-in forced-restriction CVar sweep (out of combat; restores)")
    p("  /fdump lab [poll on|off]   workarounds lab: sanctioned secret-value paths (sinks, curves, durations), boundary checks")
    p("  /fdump hsm [start|stop|show|hide]   hybrid state machine window (FD_Logs opens/closes it automatically)")
    p("  /fdump perf          self-perf monitor: top handlers + % of wall time of the current/last capture (rule: < 1% release; <=10% capture)")
    p("  /fdump level [status|release|test|diag|lab|capturelevel test|diag|lab]   replay verbosity (default release; FD_Logs elevates to lab then restores)")
    p("  /fdump combat | tokens | knowledge | baseline   combat probe set | unit token survey | spell knowledge | baseline signature now")
    p("  /fdump debug on [level] | off   taintLog (default 2) + taintLogObjectSecrets 1 -> Logs/taint.log; off restores originals")
    p("  /fdump health          self-check: ForeverDump hooks (none), wrapped Blizzard registries, nil-calls in [C] wrappers")
    p("  /fdump errors [status|on|off|clear|show|bg]   Lua error + ADDON_ACTION_BLOCKED/FORBIDDEN capture (bg: copy BugGrabber's session errors)")
    p("  /fdump probe [combat]  sample tooltips/getters now (or arm for next combat)")
    p("  /fdump probe add|remove item|spell|quest|unit|achievement|currency <id>, probe list")
    p("  /fdump version         running version (also in every line's prefix, the HSM title and FD_Logs ON/OFF)")
    p("  /fdump msgs [n]        show the last n ForeverDump lines again (they never go to chat: BG chat-filter taint)")
    p("  /fdump status          what is collected; /fdump show <status|apis|events|enums|cvars|all|section>")
    p("  /fdump clear <section|docs|strings|record|cl|errors|probe|all>   /fdump cancel   /fdump set <key> <value>")
    p("Then /reload or log out so the client writes WTF\\Account\\<account>\\SavedVariables\\ForeverDump.lua")
end

local function words(msg)
    local out = {}
    for w in string.gmatch(msg or "", "%S+") do out[#out + 1] = w end
    return out
end

local function clear(what)
    local db = ns.db
    if what == "all" then
        local config = ns.config
        ForeverDumpDB = { config = config }
        ForeverDumpDocsDB, ForeverDumpStringsDB, ForeverDumpRecordDB = {}, {}, {}
        ForeverDumpStaticDB = {}
        ForeverDumpLogDB, ForeverDumpCombatLogDB = {}, {}
        ns.InitDB()
    elseif what == "docs" then
        ForeverDumpDocsDB = {}
        if ns.Static then local s = ns.Static.DB() s.docs = nil s.sections.docs = nil end
        rawset(db.sections, "docs", nil)
    elseif what == "strings" then
        ForeverDumpStringsDB = {}
        if ns.Static then local s = ns.Static.DB() s.strings = nil s.sections.strings = nil end
        rawset(db.sections, "strings", nil)
    elseif what == "static" then
        ns.Static.Clear()
    elseif what == "record" then
        ForeverDumpRecordDB = { sessions = {} }
    elseif what == "cl" or what == "combatlog" then
        ForeverDumpCombatLogDB = { sessions = {} }
        ns.InitDB()
    elseif what == "errors" or what == "log" then
        ns.Errors.Clear()
    elseif what and db.sections[what] then
        db.sections[what] = nil
    else
        ns.Print("nothing to clear for '" .. tostring(what) .. "'")
        return
    end
    ns.Print("cleared " .. tostring(what))
end

local SETTABLE = { frameBudgetMs = true, progressEverySec = true, uiMaxChars = true, svpack = true,
    ["record.maxEvents"] = true, ["record.perEventPerSec"] = true, ["record.maxSessions"] = true,
    ["record.callbacks"] = true, ["record.redactChat"] = true, ["probe.maxAuras"] = true,
    ["probe.redactPlayers"] = true, ["cl.maxEvents"] = true, ["cl.maxSessions"] = true, ["cl.maxArgs"] = true,
    ["cl.maxString"] = true, ["cl.redactPlayers"] = true, ["cl.damageMeter"] = true, ["cl.advanced"] = true,
    ["logs.chat"] = true, ["logs.advanced"] = true, ["logs.scriptErrors"] = true, ["logs.taintLog"] = true,
    ["logs.callLogging"] = true, ["dump.full"] = true, ["logs.recorder"] = true, ["logs.combat"] = true, ["logs.errors"] = true,
    ["logs.probe"] = true, ["logs.combatProbe"] = true, ["logs.profile"] = true, ["logs.fullDump"] = true,
    ["logs.autoReload"] = true, ["logs.autoBG"] = true,
    ["logs.bgReminder"] = true, ["errors.maxErrors"] = true, ["errors.maxBlocked"] = true, ["errors.captureLocals"] = true,
    ["errors.maxLocals"] = true, ["errors.maxStack"] = true, ["restrictions.enabled"] = true, ["restrictions.probe"] = true,
    ["restrictions.maxFlips"] = true, ["lab.auto"] = true, ["lab.poll"] = true, ["lab.pollInterval"] = true,
    ["secrets.controls"] = true, ["secrets.opsPrint"] = true, ["restrictions.maxMarkers"] = true, ["restrictions.maxProbedFlips"] = true,
    ["combatProbe.enabled"] = true, ["combatProbe.minInterval"] = true, ["combatProbe.maxRunsPerCapture"] = true,
    ["combatProbe.nameplates"] = true, ["tokens.enabled"] = true, ["knowledge.enabled"] = true, ["knowledge.maxSpells"] = true,
    ["hsm.enabled"] = true, ["hsm.autoShow"] = true, ["hsm.updateInterval"] = true, ["hsm.window"] = true, ["hsm.signals"] = true }

local function set(key, value)
    if not SETTABLE[key] then
        local keys = ns.SortedList(SETTABLE)
        ns.Print("settable: " .. table.concat(keys, ", "))
        return
    end
    local v
    if value == "true" then v = true elseif value == "false" then v = false else v = tonumber(value) end
    if v == nil then ns.Print("bad value") return end
    local a, b = string.match(key, "^(%w+)%.(%w+)$")
    if a then ns.config[a][b] = v else ns.config[key] = v end
    ns.Print(key .. " = " .. tostring(v))
end

local function handler(msg)
    if not ns.db then ns.InitDB() end
    local w = words(msg)
    local cmd = string.lower(w[1] or "")
    local rest = { select(2, unpack(w)) }
    if cmd == "" then
        ns.Legacy.Dump()
    elseif cmd == "help" or cmd == "?" then
        help()
    elseif cmd == "all" then
        if ns.InCombat() then ns.Print("|cffff5555refusing full dump in combat.|r") return end
        if ns.IsBusy() then ns.Print("already running; /fdump cancel to stop.") return end
        if string.lower(rest[1] or "") == "full" then
            ns.config.dump.full = true
            ns.Print("full dump: dump.full=true (everything, ~2x SavedVariables size). /fdump set dump.full false to go back.")
        end
        -- v2.2.11: /fdump all never runs the static dump (only /fdump static run does); non-static sections only
        for _, name in ipairs(ALL_ORDER) do if not (ns.Static and ns.Static.IsStatic(name)) then ns.RunSection(name) end end
        if ns.Static then ns.Print("static client data is not part of /fdump all: /fdump static run collects it.") end
    elseif cmd == "static" then
        local sub = string.lower(rest[1] or "status")
        if sub == "clear" then
            ns.Static.Clear()
            ns.Print("static client data cleared (ForeverDumpStaticDB emptied; the build marker stays). /reload to shrink the "
                .. "SavedVariables file. /fdump static run collects it again.")
        elseif sub == "run" or sub == "force" then
            local ok, why = ns.Static.Start("slash")   -- v2.2.11: the ONLY trigger of the static dump
            ns.Print(ok and "static dump started (chunked, out of combat)." or ("static dump: " .. tostring(why)))
        elseif sub == "check" then
            ns.Print("static: " .. tostring(ns.Static.Check()))
        else ns.Print(ns.Static.StatusLine()) end
    elseif cmd == "record" then
        local sub = string.lower(rest[1] or "status")
        if sub == "start" then ns.Recorder.Start()
        elseif sub == "stop" then ns.Recorder.Stop()
        else ns.Recorder.Status() end
    elseif cmd == "cl" or cmd == "combatlog" then
        local sub = string.lower(rest[1] or "status")
        local opt = string.lower(rest[2] or "")
        if sub == "start" then ns.CombatLog.Start({ file = opt == "file", cleuForce = opt == "cleu-force" })
        elseif sub == "cleu-force" then ns.CombatLog.Start({ cleuForce = true, file = opt == "file" })
        elseif sub == "stop" then ns.CombatLog.Stop()
        else ns.CombatLog.Status() end
    elseif cmd == "logs" or cmd == "macro" or cmd == "macros" then
        if cmd ~= "logs" then rest = { "macro" } end
        ns.Logs.Command(rest)
    elseif cmd == "errors" then
        local sub = string.lower(rest[1] or "status")
        if sub == "on" then
            ns.config.errors.enabled = true
            ns.Errors.Install()
            ns.Errors.Status()
        elseif sub == "off" then
            ns.config.errors.enabled = false
            ns.Errors.Uninstall()
            ns.Errors.Status()
        elseif sub == "clear" then ns.Errors.Clear() ns.Print("errors cleared")
        elseif sub == "show" then ns.UI.Show("errors")
        elseif sub == "bg" or sub == "buggrabber" then
            local r = ns.Errors.ImportBugGrabber("command")
            if r then ns.Print(string.format("copied %d BugGrabber error(s) from session %s into ForeverDumpLogDB.bugGrabber",
                #r.errors, tostring(r.session)))
            else ns.Print("BugGrabber is not loaded (or has no database yet).") end
        else ns.Errors.Status() end
    elseif cmd == "restrictions" or cmd == "restr" then
        local sub = string.lower(rest[1] or "")
        if sub == "probe" then
            local p = ns.Restrictions.Probe()
            for _, k in ipairs(ns.SortedKeys(p)) do
                if type(p[k]) ~= "table" then ns.Print(string.format("  %s: %s", k, tostring(p[k]))) end
            end
        else ns.Print(ns.Restrictions.StatusText()) end
    elseif cmd == "secrets" and (string.lower(rest[1] or "") == "forced" or string.lower(rest[1] or "") == "controls") then
        -- run directly (not through the section queue): the forced sweep must start/stop synchronously
        local sec = ns.sections and ns.sections.secrets
        if sec and sec.run then sec.run(nil, rest) end
    elseif cmd == "lab" then
        local sub, onoff = string.lower(rest[1] or ""), string.lower(rest[2] or "")
        if sub == "poll" then
            ns.config.lab.poll = (onoff == "on")
            if onoff == "on" then ns.Lab.StartPoll() else ns.Lab.StopPoll() end
            ns.Print("secrecy polling " .. (onoff == "on" and "ON" or "off") .. " (lab.poll, every " .. tostring(ns.config.lab.pollInterval) .. "s)")
        else
            local rec = ns.Lab.Run("command")
            local n, absent = 0, 0
            for _, it in ipairs(rec and rec.items or {}) do n = n + 1 if it.available == false then absent = absent + 1 end end
            ns.Print(string.format("lab (%s): %d approaches measured, %d absent in this build -> ForeverDumpLogDB.lab (converter: fdump.py lab)",
                rec and rec.ctx or "?", n - absent, absent))
        end
    elseif cmd == "hsm" then
        local sub = string.lower(rest[1] or "")
        if sub == "start" then ns.Inference.Start() ns.HSMUI.Show() ns.Print("HSM running (until /fdump hsm stop or the next FD_Logs OFF)")
        elseif sub == "stop" then ns.Inference.Stop() ns.Print("HSM stopped; predictions saved to ForeverDumpLogDB.inference")
        elseif sub == "show" then ns.HSMUI.Show()
        elseif sub == "hide" then ns.HSMUI.Hide()
        else ns.HSMUI.Toggle() end
    elseif cmd == "level" or cmd == "verbosity" then
        if ns.ReplayLog then ns.ReplayLog.Command(table.concat(rest, " "))
        else ns.Print("ReplayLog not loaded") end
    elseif cmd == "perf" then
        if ns.Perf then ns.Perf.Print() end
    elseif cmd == "combat" or cmd == "combatprobe" then
        local rec = ns.CombatProbe.Run("command", true)
        ns.Print(string.format("combat probe (%s): %d unit class(es) -> ForeverDumpLogDB.combatProbe (fdump.py combat)",
            rec and rec.ctx or "?", rec and #rec.classes or 0))
    elseif cmd == "tokens" then
        local rec = ns.Tokens.Survey("command", true)
        local n = 0
        for _ in pairs(rec and rec.families or {}) do n = n + 1 end
        ns.Print(string.format("unit token survey: %d families -> ForeverDumpLogDB.tokens (fdump.py tokens)", n))
    elseif cmd == "knowledge" then
        if ns.Knowledge.Run("command") then ns.Print("spell knowledge pass queued (chunked) -> ForeverDumpDB.knowledge[build]")
        else ns.Print("spell knowledge: already running or disabled") end
    elseif cmd == "baseline" then
        local sig, alert = ns.Baseline.Capture("command")
        ns.Print(string.format("baseline signature v%d stored for build %s%s", sig.v, tostring(sig.build), alert and "" or " (no drift)"))
    elseif cmd == "debug" then
        local sub = string.lower(rest[1] or "status")
        if sub == "on" then ns.Print(ns.Controls.Debug(true, rest[2]))
        elseif sub == "off" then ns.Print(ns.Controls.Debug(false))
        else ns.Print("debug CVars: " .. (ns.Controls.DebugOn() and "ON" or "off") .. " (taintLog=" .. tostring(ns.Controls.GetCVar("taintLog"))
            .. ", taintLogObjectSecrets=" .. tostring(ns.Controls.GetCVar("taintLogObjectSecrets")) .. "). /fdump debug on [level] | off") end
    elseif cmd == "health" then
        ns.Print(ns.Restrictions.HealthText())
    elseif cmd == "probe" then
        local sub = string.lower(rest[1] or "")
        if sub == "" or sub == "now" then ns.Probe.Run("manual")
        elseif sub == "combat" then ns.Probe.Arm()
        elseif sub == "add" or sub == "remove" then ns.Probe.Edit(sub, string.lower(rest[2] or ""), rest[3])
        elseif sub == "list" then ns.Probe.List()
        else help() end
    elseif cmd == "version" then
        ns.Print("running ForeverDump " .. ns.VERSION .. " (SavedVariables last written by "
            .. tostring(ns.versionChange and ns.versionChange.from or ns.VERSION) .. ")")
    elseif cmd == "msgs" or cmd == "messages" then
        ns.ReplayMessages(rest[1])
    elseif cmd == "status" then
        local m = ns.Meta()
        ns.Print("|cffffff00ForeverDump version " .. ns.VERSION .. "|r")
        ns.Print(string.format("client %s.%s toc %s, WOW_PROJECT_ID=%s (%s), scriptsDisallowedForBeta=%s",
            tostring(m.version), tostring(m.build), tostring(m.toc), tostring(m.projectID),
            tostring(m.projectName or "?"), tostring(m.scriptsDisallowedForBeta)))
        ns.UI.Show("status")
        ns.Recorder.Status()
        ns.CombatLog.Status()
        ns.Errors.Status()
        ns.Logs.Status()
        if ns.ReplayLog then ns.ReplayLog.Command("status") end
    elseif cmd == "show" then
        ns.UI.Show(string.lower(rest[1] or "status"))
    elseif cmd == "clear" then
        clear(string.lower(rest[1] or ""))
    elseif cmd == "cancel" then
        ns.CancelAll()
        ns.Print("cancelled queued jobs.")
    elseif cmd == "set" then
        set(rest[1], rest[2])
    elseif ns.sections[cmd] then
        if ns.IsBusy() then ns.Print("queued after the running job.") end
        ns.RunSection(cmd, rest)
    else
        ns.Print("unknown command '" .. cmd .. "'")
        help()
    end
end

SLASH_FOREVERDUMP1 = "/fdump"
SLASH_FOREVERDUMP2 = "/foreverdump"
SlashCmdList.FOREVERDUMP = handler
ns.HandleSlash = handler
