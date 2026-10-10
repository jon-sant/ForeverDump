-- Smoke test: load ForeverDump into the mock client, run every command path,
-- assert nothing errors / no secret is touched, and write a sample
-- SavedVariables file for the converter tests.
-- usage: FORE_DOCS=.../Interface/AddOns lua5.1 tests/smoke.lua <addonDir> <outSV>
package.path = "./tests/?.lua;" .. package.path
local W = require("wowenv")
local addonDir, outPath = arg[1] or "ForeverDump", arg[2] or "tests/out/ForeverDump.lua"

local files = {}
for line in io.lines(addonDir .. "/ForeverDump.toc") do
    if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
end
local ns = W.loadAddon(addonDir, files, "ForeverDump")
W.fire("ADDON_LOADED", "Blizzard_DebugTools")
W.fire("ADDON_LOADED", "ForeverDump")
W.fire("PLAYER_LOGIN")

local failures = 0
local function check(cond, msg)
    if cond then print("  ok   " .. msg) else failures = failures + 1; print("  FAIL " .. msg) end
end
local function errorsLogged() return ForeverDumpDB.errors and #ForeverDumpDB.errors or 0 end

print("v1 compatibility")
W.slash("")
check(type(ForeverDumpDB.apis) == "table" and #ForeverDumpDB.apis > 100, "/fdump (v1) wrote apis: " .. #(ForeverDumpDB.apis or {}))
check(type(ForeverDumpDB.events) == "table" and #ForeverDumpDB.events > 100, "v1 events: " .. #(ForeverDumpDB.events or {}))
check(type(ForeverDumpDB.cvars) == "table", "v1 cvars nested")
check(ForeverDumpDB.cvars.Net.accountName.current ~= "<redacted>", "v2.2.21: accountName CVar stored raw (identity, not a credential)")
check(_G.ForeverDumpFrame ~= nil, "copy UI created")

print("help / status")
W.slash("help")
W.slash("status")

print("combat refusal")
W.state.combat = true
W.slash("all")
check(not ns.IsBusy(), "/fdump all refused in combat")
W.state.combat = false

print("/fdump all + /fdump static run")
W.slash("all")
local ticks = W.runUntilIdle(ns)
-- v2.2.11: /fdump all no longer collects static data; the explicit slash command does
check(not ns.Static.IsRunning() and rawget(ForeverDumpStaticDB.sections, "api") == nil, "/fdump all collected no static section")
W.slash("static run")
for _ = 1, 400 do W.tick(1) if not ns.Static.IsRunning() and not ns.IsBusy() then break end W.runUntilIdle(ns) end
ticks = ticks + W.runUntilIdle(ns)
check(errorsLogged() == 0, "no job errors (" .. errorsLogged() .. ")" ..
    (ForeverDumpDB.errors and (" first: " .. tostring(ForeverDumpDB.errors[1].err)) or ""))
print("    finished after " .. ticks .. " frames")
for _, s in ipairs({ "docs", "api", "globals", "strings", "widgets", "templates", "frames", "addons", "cvars", "protected", "extras" }) do
    check(ForeverDumpDB.sections[s] ~= nil, "section " .. s)
end
local docs = ForeverDumpDocsDB
check(docs.counts and docs.counts.systems > 300, "docs systems: " .. tostring(docs.counts and docs.counts.systems))
check(docs.counts.functions > 5000, "docs functions: " .. docs.counts.functions)
local foundMissing, foundUndoc = false, false
for _, n in ipairs(docs.missing) do if n == "C_Item.GetItemCooldown" then foundMissing = true end end
for _, n in ipairs(docs.undocumented) do if n == "C_Item.UndocumentedMockFunction" then foundUndoc = true end end
check(foundMissing, "documented-but-missing detected")
check(foundUndoc, "present-but-undocumented detected")
local fn = docs.systems[1].Functions and docs.systems[1].Functions[1]
check(fn == nil or fn.System == nil, "no System back-reference copied")
local flagFound = false
for _, sys in ipairs(docs.systems) do
    for _, f in ipairs(sys.Functions or {}) do if f.SecretArguments then flagFound = true break end end
    if flagFound then break end
end
check(flagFound, "generic flags (SecretArguments) captured")
local w = ForeverDumpDB.sections.widgets
check(w.types.Frame and w.types.Frame.count > 50, "widget Frame methods: " .. tostring(w.types.Frame and w.types.Frame.count))
check(w.notCreatable and w.notCreatable.Blob and w.notCreatable.MapScene and w.failures.MapScene == nil,
    "not-creatable widget types documented without calling CreateFrame (MapScene, Blob, ...)")
check(W.state.luaWarnings == nil, "regression A: normal /fdump all raises no 'Unable to create frame type' LUA_WARNING")
check(w.types["Anim:Alpha"] ~= nil and w.failures["Anim:RadialProgress"] ~= nil, "animation types + failure")
check(ForeverDumpDB.sections.frames.frames.ForbiddenTestFrame.forbidden == true, "forbidden frame flagged")
check(ForeverDumpDB.sections.frames.frames.ProtectedTestButton.protected == true, "protected frame flagged")
do
    local found = false
    for _, n in ipairs(ForeverDumpStringsDB.names or {}) do if n == "ITEM_LEVEL" then found = true end end
    check(found and ForeverDumpStringsDB.strings == nil and ForeverDumpStringsDB.compact, "compact global strings: names only")
    check(ForeverDumpDB.sections.globals.tables.APIDocumentation == nil or ForeverDumpDB.sections.globals.tables.APIDocumentation.skipped,
        "APIDocumentation table not duplicated in globals")
    check(ForeverDumpDB.sections.globals.tables.ForeverDumpDB.skipped, "own SavedVariables not dumped into globals")
    local pf = ForeverDumpDB.sections.protected
    check(pf.counts.plainSecureOmitted > 0, "compact protected: plain secure functions omitted (" .. pf.counts.plainSecureOmitted .. ")")
end
check(ForeverDumpDB.sections.protected.counts.restricted > 0, "protected: restricted functions from docs")
check(ForeverDumpDB.sections.globals.constants.NUM_BAG_SLOTS == 4, "globals constants")
local insecure = false
for _, n in ipairs(ForeverDumpDB.sections.globals.functions.insecure) do if n == "TaintedAddonGlobalFunction" then insecure = true end end
check(insecure, "insecure global function split")
check(ForeverDumpDB.sections.extras.slash.commands.FRAMESTACK ~= nil, "slash commands from SLASH_* strings")

print("widgets risky + getters")
W.slash("widgets risky")
W.runUntilIdle(ns)
check(ForeverDumpDB.sections.widgets.failures.MapScene ~= nil and #(W.state.luaWarnings or {}) == 3,
    "widgets risky still tries MapScene/VectorGraphics/ModelFFX (3 LUA_WARNINGs, opt-in)")
W.slash("getters")
W.runUntilIdle(ns)
check(ForeverDumpDB.sections.getters and ForeverDumpDB.sections.getters.counts.called > 50,
    "getters called: " .. tostring(ForeverDumpDB.sections.getters and ForeverDumpDB.sections.getters.counts.called))

print("probe")
W.slash("probe add item 12345")
W.slash("probe list")
W.slash("probe")
local p = ForeverDumpDB.sections.probe
check(p.outOfCombat ~= nil, "probe outOfCombat")
W.slash("probe combat")
W.state.combat = true
W.fire("PLAYER_REGEN_DISABLED")
W.tick(2)
check(p.inCombat ~= nil, "armed probe ran in combat")
local hp = p.inCombat.units.player.UnitHealth
check(hp.values[1] == "<secret>" and hp.secret[1] == 1, "secret return recorded as <secret>")
local auraErr = p.inCombat.auras.target.HELPFUL[1]
check(auraErr.ok == false, "aura access error recorded, not raised")
local pname = p.outOfCombat.units.player.UnitName.values[1]
check(pname ~= nil and pname ~= "<player-name>", "v2.2.21: player name stored raw: " .. tostring(pname))
check(tostring(p.outOfCombat.units.player.UnitGUID.values[1]):find("^Player%-%d+%-%x+$") ~= nil, "v2.2.21: player GUID stored raw")

print("recorder")
ns.config.record.callbacks = true   -- opt-in since v2.2
ns.config.record.callbackEvents = { "MockCallback.Event" }
W.slash("record start")
W.fire("UNIT_HEALTH", "target", W.SECRET)
for _ = 1, 50 do W.fire("UNIT_AURA", "player", { addedAuras = {} }) end
W.fire("CHAT_MSG_WHISPER", "hello", "Someone-Realm")
W.fire("SPELL_UPDATE_COOLDOWN")
EventRegistry:TriggerEvent("MockCallback.Event", 1, "two")
W.state.combat = false
W.slash("record status")
W.slash("record stop")
local sess = ForeverDumpRecordDB.sessions[#ForeverDumpRecordDB.sessions]
check(sess and sess.kept > 0, "recording saved: " .. tostring(sess and sess.kept))
local sawSecret, sawChat, sawCB = false, false, false
for _, e in ipairs(sess.events) do
    if e.e == "UNIT_HEALTH" and e.a[2] == "<secret>" and e.s and e.s[1] == 2 and e.c then sawSecret = true end
    if e.e == "CHAT_MSG_WHISPER" and e.redacted then sawChat = true end
    if e.cb and e.e == "MockCallback.Event" then sawCB = true end
end
check(sawSecret, "secret event arg recorded as <secret> with combat flag")
check(not sawChat, "v2.2.21: chat event stored raw (redactChat off by default)")
check(sawCB, "EventRegistry callback recorded")
check((sess.dropped.UNIT_AURA or 0) > 0, "throttle dropped spam: " .. tostring(sess.dropped.UNIT_AURA))

print("combat recorder (Forever-safe events)")
W.slash("set cl.maxSessions 6") -- keep every session for the converter fixtures
do
    check(next(W.state.restrictedRegistrations) == nil and W.state.registerAllCalls == 0,
        "so far nothing registered COMBAT_LOG_EVENT* or called RegisterAllEvents")
    W.slash("cl start file")
    check(W.state.logging == false and W.state.protectedCalls == 0 and W.CVARS.advancedCombatLogging[1] == "1",
        "cl start file: advancedCombatLogging on, LoggingCombat NOT called by default")
    W.fire("ENCOUNTER_START", 2902, "Mock Boss", 14, 20)
    W.state.combat = true
    W.fire("PLAYER_REGEN_DISABLED")
    W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-1234-0-0-133-000000000A", 133)
    W.fire("UNIT_COMBAT", "target", "WOUND", "", W.SECRET, 1)
    W.fire("PLAYER_SWING", 2.6, 0)
    W.state.ctInfo = { n = 2, W.SECRET, "Fire" }
    W.fire("COMBAT_TEXT_UPDATE", "DAMAGE")
    W.state.ctInfo = nil
    W.fireCLEU(1791409800.123, "SPELL_DAMAGE", false, "Player-1234-0ABCDEF0", "Mockchar", 0x511, 0,
        "Creature-0-1-2-3-4-5", "Mock Boss", 0x10a48, 0, 133, "Fireball", 4, 1234, -1, 4, nil, nil, nil, true, false, false, false)
    W.fire("ENCOUNTER_END", 2902, "Mock Boss", 14, 20, 1)
    W.state.combat = false
    W.fire("PLAYER_REGEN_ENABLED")
    W.tick(2) -- C_Timer.After -> post-combat damage meter snapshot
    W.slash("cl status")
    W.slash("cl stop")
    check(W.CVARS.advancedCombatLogging[1] == "0", "advanced CVar restored")
    check(next(W.state.restrictedRegistrations) == nil, "default combat recorder never registers COMBAT_LOG_EVENT*")
    local cs = ForeverDumpCombatLogDB.sessions[#ForeverDumpCombatLogDB.sessions]
    check(cs.cleuTotal == 0 and (cs.counts.COMBAT_LOG_EVENT_UNFILTERED or 0) == 0, "CLEU not captured by default")
    check(cs.counts.UNIT_COMBAT == 1 and cs.counts.UNIT_SPELLCAST_SUCCEEDED == 1 and cs.counts.PLAYER_SWING == 1
        and cs.counts.COMBAT_TEXT_UPDATE == 1, "UNIT_COMBAT / UNIT_SPELLCAST_* / PLAYER_SWING / COMBAT_TEXT_UPDATE captured")
    local uc, ct, sw, enc, regen
    for _, e in ipairs(cs.events) do
        if e.e == "UNIT_COMBAT" then uc = e end
        if e.e == "COMBAT_TEXT_UPDATE" then ct = e end
        if e.e == "PLAYER_SWING" then sw = e end
        if e.e == "ENCOUNTER_START" then enc = e end
        if e.e == "PLAYER_REGEN_DISABLED" then regen = e end
    end
    check(uc and uc.a[4] == "<secret>" and uc.s and uc.s[1] == 4 and uc.c, "UNIT_COMBAT secret amount recorded as <secret> + combat flag")
    local g = ct and ct.g and ct.g["C_CombatText.GetCurrentEventInfo"]
    check(g and g.a[1] == "<secret>" and g.a[2] == "Fire" and g.s[1] == 1, "C_CombatText.GetCurrentEventInfo captured with secrets")
    check(sw and sw.range and sw.range.MainHand == true and sw.range.Ranged == false, "PLAYER_SWING + C_SwingTimer range")
    check(enc and enc.ctx and enc.instance and enc.a[2] == "Mock Boss", "ENCOUNTER_START context with instance info")
    check(regen and regen.restricted == true and regen.restrictions and regen.restrictions.Combat == 1, "restriction state at combat start")
    local dm = cs.damageMeter and cs.damageMeter[1]
    check(dm and dm.reason == "PLAYER_REGEN_ENABLED" and dm.byType.DamageDone and dm.byType.DamageDone.totalAmount == 1234,
        "post-combat C_DamageMeter snapshot (not secret)")
    check(cs.skipped == nil and cs.notAvailable ~= nil and cs.registered and #cs.registered > 20, "registered list recorded")
    check(cs.utcOffsetSec ~= nil and cs.fileLogging.error and cs.fileLogging.error:find("FD_Logs", 1, true), "utc offset + file logging skip reason recorded")

    -- in-combat stop: no damage meter read while secret
    W.slash("cl start")
    W.state.combat = true
    W.slash("cl stop")
    W.state.combat = false
    local cs2 = ForeverDumpCombatLogDB.sessions[#ForeverDumpCombatLogDB.sessions]
    check(#cs2.damageMeter == 0, "no C_DamageMeter read while in combat")

    -- ring buffer
    W.slash("set cl.maxEvents 100")
    W.slash("cl start")
    for i = 1, 150 do W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-" .. i, 2061) end
    W.slash("cl stop")
    local rs = ForeverDumpCombatLogDB.sessions[#ForeverDumpCombatLogDB.sessions]
    check(#rs.events == 100 and rs.overwritten == 50 and rs.counts.UNIT_SPELLCAST_SUCCEEDED == 150, "ring buffer bounded, counts complete")
    check(rs.events[1].a[2] == "Cast-51", "ring linearized oldest-first")
    W.slash("set cl.maxEvents 20000")
    check(next(W.state.restrictedRegistrations) == nil and W.state.registerAllCalls == 0,
        "still no COMBAT_LOG_EVENT* registration / RegisterAllEvents after recorder + combat recorder")

    -- legacy opt-in: refused without getter or when restricted
    local getter = CombatLogGetCurrentEventInfo
    CombatLogGetCurrentEventInfo = nil
    W.slash("cl cleu-force")
    W.slash("cl stop")
    local r1 = ForeverDumpCombatLogDB.sessions[#ForeverDumpCombatLogDB.sessions]
    check(r1.cleu.refused and r1.cleu.refused:find("CombatLogGetCurrentEventInfo missing", 1, true)
        and next(W.state.restrictedRegistrations) == nil, "cleu-force refused when getter missing (no registration)")
    CombatLogGetCurrentEventInfo = getter
    local restrictedFn = C_CombatLog.IsCombatLogRestricted
    C_CombatLog.IsCombatLogRestricted = function() return true end
    W.slash("cl cleu-force")
    W.slash("cl stop")
    local r2 = ForeverDumpCombatLogDB.sessions[#ForeverDumpCombatLogDB.sessions]
    check(r2.cleu.refused and r2.cleu.refused:find("IsCombatLogRestricted", 1, true) and next(W.state.restrictedRegistrations) == nil,
        "cleu-force refused when combat log restricted")
    C_CombatLog.IsCombatLogRestricted = restrictedFn
    -- unrestricted legacy client: capture full CLEU payloads (for testing older addons)
    W.slash("set cl.redactPlayers true")
    W.slash("cl cleu-force")
    W.state.combat = true
    W.fireCLEU(1791409800.123, "SPELL_DAMAGE", false, "Player-1234-0ABCDEF0", "Mockchar", 0x511, 0,
        "Creature-0-1-2-3-4-5", "Mock Boss", 0x10a48, 0, 133, "Fireball", 4, 1234, -1, 4, nil, nil, nil, true, false, false, false)
    W.fireCLEU(1791409800.5, "SWING_DAMAGE", false, "Creature-0-1-2-3-4-5", W.SECRET, 0xa48, 0,
        "Player-1234-0ABCDEF0", "Mockchar", 0x511, 0, W.SECRET, -1, 1, nil, nil, nil, false, false, false, false)
    W.state.combat = false
    W.slash("cl stop")
    W.slash("set cl.redactPlayers false")
    local lc = ForeverDumpCombatLogDB.sessions[#ForeverDumpCombatLogDB.sessions]
    check(W.state.restrictedRegistrations.COMBAT_LOG_EVENT_UNFILTERED == 1, "cleu-force registers CLEU only when explicitly allowed")
    local dmg, swing
    for _, e in ipairs(lc.events) do
        if e.sub == "SPELL_DAMAGE" then dmg = e end
        if e.sub == "SWING_DAMAGE" then swing = e end
    end
    check(lc.cleuTotal == 2 and dmg and dmg.n == 24 and dmg.a[12] == 133 and dmg.a[15] == 1234 and dmg.a[18] == "<nil>",
        "legacy CLEU payload incl. suffix args and nil placeholders")
    check(dmg and dmg.a[4] == "Player-#1" and dmg.a[5] == "<player>", "cl.redactPlayers redacts player GUID/name")
    check(swing and swing.s and swing.s[1] == 5 and swing.s[2] == 12, "secret CLEU args recorded as <secret>")
    W.state.restrictedRegistrations = {}
end

print("recorder event registration")
do
    W.slash("record start")
    W.slash("record stop")
    local rsess = ForeverDumpRecordDB.sessions[#ForeverDumpRecordDB.sessions]
    check(rsess.registered and rsess.registered > 1000, "recorder registered documented events individually: " .. tostring(rsess.registered))
    check(rsess.skippedEvents and rsess.skippedEvents.COMBAT_LOG_EVENT_UNFILTERED and rsess.skippedEvents.COMBAT_LOG_EVENT,
        "COMBAT_LOG_EVENT* skipped: " .. tostring(rsess.skippedEvents and rsess.skippedEvents.COMBAT_LOG_EVENT_UNFILTERED))
    check(rsess.skippedEvents.MINIMAP_PING == "docs: HasRestrictions", "HasRestrictions events skipped generically")
    check(rsess.skippedEvents.UNIT_PING_PIN_ADDED ~= nil, "SecureOnly-system events skipped: " .. tostring(rsess.skippedEvents.UNIT_PING_PIN_ADDED))
    check(next(W.state.restrictedRegistrations) == nil and W.state.registerAllCalls == 0, "recorder: no restricted registration, no RegisterAllEvents")
end

print("FD_Logs macro: capture everything")
W.slash("set cl.maxSessions 12")
do
    local function chatHas(from, needle)
        for i = from + 1, #W.chat do if W.chat[i]:find(needle, 1, true) then return true end end
        return false
    end
    local function heldHas(needle)
        for _, l in ipairs(ns.chatQueue.lines) do if l:find(needle, 1, true) then return true end end
        return false
    end
    local function body() return W.state.macros[GetMacroIndexByName("FD_Logs")].body end
    local function nCL() return #ForeverDumpCombatLogDB.sessions end
    local function nRec() return #ForeverDumpRecordDB.sessions end
    W.slash("logs macro")
    local idx = GetMacroIndexByName("FD_Logs")
    local m = W.state.macros[idx]
    check(idx > 0 and m.body == "/fdump logs\n/stopmacro [combat]\n/combatlog\n/chatlog" and #m.body <= 255 and m.perChar == nil,
        "FD_Logs created account-wide (OFF state, no /reload): " .. tostring(m and m.body:gsub("\n", " | ")))
    W.slash("logs macro")
    check(#W.state.macros == 1 and ForeverDumpDB.macro.action == "updated", "second run updates, no duplicate")

    -- click 1: ON while the static marker is stale (older client signature): ON must NOT queue the static dump (v2.2.7)
    local savedMarker = ForeverDumpDB.static and ForeverDumpDB.static.key
    ForeverDumpDB.static = ForeverDumpDB.static or {}
    ForeverDumpDB.static.key = "1.0|1|1|00000000"
    check(not ns.Logs.HaveFullDump() and not ns.Static.Done(), "stale static marker detected (different client signature)")
    local c0, cl0, rec0 = #W.chat, nCL(), nRec()
    -- v2.2.11: this ON wipes the sessions recorded by the manual /fdump record|cl sections above; the converter fixture
    -- keeps them (re-added in front of the main capture's sessions after the auxiliary cycles below)
    local function deep0(v) if type(v) ~= "table" then return v end local o = {} for k, x in pairs(v) do o[k] = deep0(x) end return o end
    local preMain = { rec = deep0(ForeverDumpRecordDB.sessions), cl = deep0(ForeverDumpCombatLogDB.sessions) }
    check(not ns.Recorder.IsActive() and not ns.CombatLog.IsActive(), "recorders idle before ON")
    W.clickMacro("FD_Logs")
    check(ns.Recorder.IsActive() and ns.CombatLog.IsActive() and ns.Errors.IsInstalled(), "ON started event recorder, combat recorder, error capture")
    check(ForeverDumpDB.sections.probe.outOfCombat.reason == "capture:on", "ON took an out-of-combat probe")
    check(ForeverDumpDB.sections.profile.latest.reason == "capture:on", "ON took a profiler snapshot")
    -- v2.2.7/v2.2.11: ON never queues the static dump (only /fdump static run does)
    local queuedByOn = ns.IsBusy() or ns.Static.IsRunning()
    local lt = ForeverDumpDB.logs.lastToggle
    check(not queuedByOn and lt.fullDump == nil and lt.static ~= nil,
        "ON queued nothing (static dump only via /fdump static run; lastToggle.static=" .. tostring(lt.static) .. ")")
    -- v2.2.11: the check for the stale marker only reports; nothing is scheduled
    check(ns.Static.Check():find("^stale") ~= nil, "check: new client signature reported stale, nothing scheduled")
    for _ = 1, 30 do W.tick(1) end
    check(not ns.IsBusy() and not ns.Static.IsRunning(), "no static dump started by the check")
    W.slash("static run")   -- the explicit slash command runs even during a capture
    W.runUntilIdle(ns)
    for _ = 1, 50 do W.tick(1) if not ns.Static.IsRunning() then break end W.runUntilIdle(ns) end
    check(ns.Logs.HaveFullDump() and ForeverDumpDB.static.key ~= "1.0|1|1|00000000",
        "static dump completed via /fdump static run (marker = current signature)")
    check(savedMarker == nil or savedMarker == ForeverDumpDB.static.key, "marker matches the earlier run")
    W.tick(2)
    check(W.state.logging and W.state.chatLogging and W.CVARS.advancedCombatLogging[1] == "1" and W.CVARS.scriptErrors[1] == "1"
        and W.CVARS.taintLog[1] == "1" and ForeverDumpDB.logs.on == true, "click 1: all client logging ON")
    check(W.state.protectedCalls == 0, "addon never called LoggingCombat/LoggingChat itself")
    check(chatHas(c0, "ForeverDump " .. ns.VERSION .. " logging: ON"), "own-frame line 'ForeverDump <version> logging: ON'")
    check(body() == "/fdump logs\n/stopmacro [combat]\n/combatlog\n/chatlog\n/reload", "macro rewritten for OFF, ends with /reload")

    -- combat: automatic in-combat probe once per recording session; clicks refused
    W.state.combat = true
    W.fire("PLAYER_REGEN_DISABLED")
    W.fire("UNIT_COMBAT", "player", "WOUND", "", W.SECRET, 1)
    W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-1234-0-0-133-000000000B", 133)
    W.tick(45)   -- v2.2.15: the in-combat probe is staged, one step per frame (~33 steps)
    check(ForeverDumpDB.sections.probe.inCombat and ForeverDumpDB.sections.probe.inCombat.reason == "capture:combat",
        "in-combat probe taken automatically at first PLAYER_REGEN_DISABLED")
    W.fire("PLAYER_REGEN_ENABLED") W.fire("PLAYER_REGEN_DISABLED") W.tick(2)
    check(ForeverDumpDB.logs.session.combatProbes == 1, "only one automatic combat probe per session")
    local c1 = #W.chat
    local r = W.clickMacro("FD_Logs")
    check(r == "stopped" and ForeverDumpDB.logs.on == true and W.state.logging and not W.state.reloadRequested
        and #W.blizzChat == 0 and chatHas(c1, "in combat - capture stays ON") and heldHas("in combat - capture stays ON"),
        "click in combat: refused, /stopmacro [combat] skips toggles and /reload; the refusal line is in our own frame, "
        .. "never in Blizzard chat (v2.2.14 chat-frame taint)")
    W.state.combat = false
    W.fire("PLAYER_REGEN_ENABLED")
    W.tick(2)

    -- /reload while ON: sessions saved at PLAYER_LOGOUT, capture resumes after login
    local c2 = #W.chat
    ns = W.reload(addonDir, files, "ForeverDump")
    W.tick(3)
    -- v2.2.11: ON wiped the earlier sessions, so this capture's segment is the only one (cl0/rec0 were counted before ON)
    check(nCL() == 1 and ForeverDumpCombatLogDB.sessions[nCL()].endedBy == "logout"
        and nRec() == 1 and ForeverDumpRecordDB.sessions[nRec()].endedBy == "logout",
        "sessions saved at logout and survived the reload (previous " .. cl0 .. "/" .. rec0 .. " wiped at ON)")
    check(ns.Recorder.IsActive() and ns.CombatLog.IsActive() and ns.Errors.IsInstalled() and ForeverDumpDB.logs.session.resumes == 1,
        "capture resumed after reload")
    check(chatHas(c2, "capture is still ON"), "chat says capture resumed")
    W.state.combat = true W.fire("PLAYER_REGEN_DISABLED") W.tick(2) W.state.combat = false W.fire("PLAYER_REGEN_ENABLED") W.tick(1)
    check(ForeverDumpDB.logs.session.combatProbes == 2, "new combat probe in the resumed session")
    check(body():find("/reload", 1, true), "macro still ends with /reload after the reload")

    -- click 2: OFF - all work must be done synchronously before the macro's /reload line
    local c3 = #W.chat
    local pendingTimers = #W.state.timers
    r = W.clickMacro("FD_Logs")
    check(r == "reload" and W.state.reloadRequested, "OFF click ran /reload as the last macro line")
    -- no ticks: everything below must already be true when /reload runs
    check(not ns.Recorder.IsActive() and not ns.CombatLog.IsActive(), "OFF stopped both recorders synchronously")
    check(ForeverDumpCombatLogDB.sessions[nCL()].endedBy == "off" and ForeverDumpRecordDB.sessions[nRec()].endedBy == "off",
        "OFF saved both sessions")
    check(#(ForeverDumpCombatLogDB.sessions[nCL()].damageMeter or {}) >= 1, "OFF took the damage meter snapshot")
    check(ForeverDumpDB.sections.probe.outOfCombatEnd and ForeverDumpDB.sections.profile.latest.reason == "capture:off", "final probe + profiler snapshot")
    check(not W.state.logging and not W.state.chatLogging and W.CVARS.advancedCombatLogging[1] == "0" and W.CVARS.taintLog[1] == "0"
        and W.CVARS.scriptErrors[1] == "1" and ForeverDumpDB.logs.on == false, "OFF: logging off, CVars restored, taintLog 0")
    check(chatHas(c3, "ForeverDump " .. ns.VERSION .. " logging: OFF") and chatHas(c3, "reloads the UI now"), "OFF summary + reload notice printed")
    check(ForeverDumpDB.logs.lastSession.combatProbes == 2 and ForeverDumpDB.logs.lastSession.resumes == 1, "summary stored in SV")
    check(#W.state.timers - pendingTimers <= 1, "only the (optional) macro refresh is deferred")
    local c4 = #W.chat
    ns = W.reload(addonDir, files, "ForeverDump")
    W.tick(3)
    check(not ns.Recorder.IsActive() and chatHas(c4, "capture OFF, files saved"), "after reload: OFF verified, not resumed")
    check(body() == "/fdump logs\n/stopmacro [combat]\n/combatlog\n/chatlog", "macro back to the ON body (no /reload)")

    -- v2.2.11: the typed ON below wipes the capture data (every capture starts clean). The converter fixture this smoke
    -- writes must still be the MAIN capture above, so keep a copy and put it back after the auxiliary typed cycles
    -- (the wipe itself is asserted here and in tests/capture_wipe.lua).
    local function deep(v) if type(v) ~= "table" then return v end local o = {} for k, x in pairs(v) do o[k] = deep(x) end return o end
    local keepMain = { log = deep(ForeverDumpLogDB), rec = deep(ForeverDumpRecordDB), cl = deep(ForeverDumpCombatLogDB), db = {} }
    for _, k in ipairs(ns.Logs.WIPE_DB) do keepMain.db[k] = deep(rawget(ForeverDumpDB, k)) end
    for _, k in ipairs(ns.Logs.WIPE_SECTIONS) do keepMain.db["section:" .. k] = deep(rawget(ForeverDumpDB.sections, k)) end
    local mainSessions = #ForeverDumpCombatLogDB.sessions
    -- typed commands (no macro): no toggles, no reload; mismatch reported
    local c5 = #W.chat
    W.slash("logs on") W.tick(2)
    check(mainSessions >= 1 and #ForeverDumpCombatLogDB.sessions == 0 and ns.CombatLog.IsActive() and ForeverDumpLogDB.controls ~= keepMain.log.controls
        and chatHas(c5, "previous capture data wiped"), "typed ON wiped the previous capture (" .. mainSessions .. " saved combat session(s) -> "
        .. #ForeverDumpCombatLogDB.sessions .. ", new one recording)")
    check(ForeverDumpDB.logs.mismatch == true and ns.CombatLog.IsActive(), "typed 'logs on': recorders on, file-log mismatch reported")
    W.slash("logs off")
    check(chatHas(c5, "Type /reload") and not ns.CombatLog.IsActive(), "typed 'logs off': asks for /reload")
    W.tick(2)
    -- macro edits deferred in combat
    W.state.combat = true
    W.slash("logs macro")
    check(ForeverDumpDB.macro.ok == false and ForeverDumpDB.macro.err:find("combat", 1, true), "macro edit refused in combat")
    W.state.combat = false
    W.fire("PLAYER_REGEN_ENABLED")
    check(ForeverDumpDB.macro.ok == true, "deferred macro update after combat")
    -- no free slot
    local saved = W.state.macros
    W.state.macros, W.state.macroSlotsUsed = {}, 120
    W.slash("logs macro")
    check(ForeverDumpDB.macro.ok == false and ForeverDumpDB.macro.err:find("no free account macro slot", 1, true), "free-slot check")
    W.state.macros, W.state.macroSlotsUsed = saved, 3
    -- opt-in direct calls
    W.slash("set logs.callLogging true")
    W.slash("logs on") W.tick(2)
    check(W.state.protectedCalls > 0 and not body():find("/combatlog", 1, true), "logs.callLogging=true: addon calls LoggingCombat, macro has no toggles")
    W.slash("logs off") W.tick(2)
    W.slash("set logs.callLogging false")
    W.state.protectedCalls = 0
    W.slash("logs macro")
    -- restore the main capture for the rest of the smoke + the converter fixture (see above)
    ForeverDumpLogDB, ForeverDumpRecordDB, ForeverDumpCombatLogDB = keepMain.log, keepMain.rec, keepMain.cl
    for i = #preMain.cl, 1, -1 do table.insert(ForeverDumpCombatLogDB.sessions, 1, preMain.cl[i]) end
    for i = #preMain.rec, 1, -1 do table.insert(ForeverDumpRecordDB.sessions, 1, preMain.rec[i]) end
    for _, k in ipairs(ns.Logs.WIPE_DB) do ForeverDumpDB[k] = keepMain.db[k] end
    for _, k in ipairs(ns.Logs.WIPE_SECTIONS) do rawset(ForeverDumpDB.sections, k, keepMain.db["section:" .. k]) end
end

print("errors / taint events")
do
    check(ns.Errors.IsInstalled() == true, "error handler chained at ADDON_LOADED")
    local shown = W.state.errorsShown or 0
    W.raiseError("Interface/AddOns/Buggy/Buggy.lua:12: attempt to index a nil value")
    W.raiseError("Interface/AddOns/Buggy/Buggy.lua:12: attempt to index a nil value")
    W.raiseError(W.SECRET)
    check((W.state.errorsShown or 0) == shown + 3, "previous handler still called")
    W.state.errorsShown = shown
    local e1 = ForeverDumpLogDB.errors[1]
    check(e1 and e1.count == 2 and e1.addon == "Buggy" and e1.stack and e1.locals, "error logged with count/addon/stack/locals")
    check(ForeverDumpLogDB.errors[2] and ForeverDumpLogDB.errors[2].message == "<secret>", "secret error message not touched")
    -- real 70245 case: a Blizzard error ("attempt to call a nil value", no path in the message) whose stack starts with
    -- ForeverDump's own handler frames; v2.0 blamed ForeverDump
    local ds = debugstack
    debugstack = function() return "[Interface/AddOns/ForeverDump/Errors.lua]:64: in function <Interface/AddOns/ForeverDump/Errors.lua:41>\n"
        .. "[C]: in function 'pcall'\n[C]: in function 'LayoutContents'\n"
        .. "[Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerModule.lua]:147: in function 'Update'" end
    W.raiseError("attempt to call a nil value")
    debugstack = ds
    local e3 = ForeverDumpLogDB.errors[3]
    check(e3 and e3.addon == "Blizzard_ObjectiveTracker", "error attributed past ForeverDump's own frames: " .. tostring(e3 and e3.addon))
    local blocked0 = #ForeverDumpLogDB.blocked   -- v2.2.11: counted here (ON wipes the log)
    W.fire("ADDON_ACTION_BLOCKED", "Buggy", "CastSpellByName()")
    W.fire("ADDON_ACTION_FORBIDDEN", "Buggy", "UseAction()")
    W.fire("MACRO_ACTION_BLOCKED", "TargetUnit()")
    W.fire("LUA_WARNING", "Mock warning")
    local b = {}
    for i = blocked0 + 1, #ForeverDumpLogDB.blocked do b[#b + 1] = ForeverDumpLogDB.blocked[i] end
    check(#b == 4 and b[1].args.addon == "Buggy" and b[1].args["function"] == "CastSpellByName()",
        "ADDON_ACTION_BLOCKED etc. logged: " .. #b)
    W.slash("errors status")
    W.slash("errors show")
    W.slash("errors off")
    check(ns.Errors.IsInstalled() == false and geterrorhandler() ~= nil, "errors off restores previous handler")
    W.slash("errors on")
    check(ns.Errors.IsInstalled() == true, "errors on re-installs")
end

print("profile")
W.slash("profile")
W.runUntilIdle(ns)
local prof = ForeverDumpDB.sections.profile
check(prof and prof.latest.profiler.enabled == true and prof.latest.addons.ForeverDump and prof.latest.addons.ForeverDump.memoryKB == 123.5,
    "profile snapshot with C_AddOnProfiler metrics + memory")
check(prof and prof.latest.addons.ForeverDump.metrics and prof.latest.addons.ForeverDump.metrics.PeakTime ~= nil, "per-addon metric by Enum name")

print("secrets map (runtime)")
do
    -- v2.2.11: FD_Logs ON wipes the per-capture observations, so feed the map again here (same events as the combat
    -- recorder section above: encounter, in-combat secret UNIT_COMBAT, secret combat text) + an armed combat probe
    W.slash("probe combat")
    W.slash("cl start")
    W.fire("ENCOUNTER_START", 2902, "Mock Boss", 14, 20)
    W.state.combat = true
    W.fire("PLAYER_REGEN_DISABLED")
    W.tick(2)   -- the armed probe runs
    W.fire("UNIT_COMBAT", "target", "WOUND", "", W.SECRET, 1)
    W.state.ctInfo = { n = 2, W.SECRET, "Fire" }
    W.fire("COMBAT_TEXT_UPDATE", "DAMAGE")
    W.state.ctInfo = nil
    W.fire("ENCOUNTER_END", 2902, "Mock Boss", 14, 20, 1)
    W.fire("UNIT_COMBAT", "target", "WOUND", "", W.SECRET, 1)   -- in combat, outside the encounter (cN/cS)
    W.state.combat = false
    W.fire("PLAYER_REGEN_ENABLED")
    W.tick(2)
    W.slash("cl stop")
    W.runUntilIdle(ns)
    local obs = ForeverDumpDB.secretsObs
    local uc = obs and obs["event:UNIT_COMBAT"]
    check(uc and uc[4] and uc[4][3] >= 1 and uc[4][4] >= 1, "UNIT_COMBAT amount observed secret in combat (cN/cS)")
    check(uc and uc[1] and uc[1][4] == 0, "UNIT_COMBAT unit token never secret")
    local ct = obs["api:C_CombatText.GetCurrentEventInfo"]
    check(ct and ct[1] and ct[1][6] >= 1 and ct[1][5] >= 1, "C_CombatText getter return 1 observed secret during the encounter (eN/eS)")
    local dm = obs["api:C_DamageMeter.GetCombatSessionFromType"]
    check(dm and dm[1] and dm[1][1] >= 1, "damage meter observed out of combat")
    local probeKey = false
    for k in pairs(obs) do if k:find("^api:UnitHealth$") then probeKey = true end end
    check(probeKey, "probe calls feed the map (api:UnitHealth)")
    W.slash("secrets")
    W.runUntilIdle(ns)
    local sct = ForeverDumpDB.sections.secrets
    check(sct and sct.outOfCombat and sct.outOfCombat.primitives.issecretvalue == "function", "secrets section: primitives recorded")
    check(sct.outOfCombat.restrictions.Combat and sct.outOfCombat.combatLogRestricted, "secrets section: restriction states")
    check(ForeverDumpDB.sections.probe.inCombat.secretState and ForeverDumpDB.sections.probe.inCombat.secretState.inCombat == true,
        "combat probe stores the in-combat secret state")
    W.state.combat = true W.fire("ENCOUNTER_START", 1, "Boss", 1, 5) W.fire("UNIT_COMBAT", "player", "WOUND", "", W.SECRET, 1)
    W.fire("ENCOUNTER_END", 1, "Boss", 1, 5, 1) W.state.combat = false
end

print("secrets verifier (live tally, sweep, contradictions)")
do
    local S = ns.Secrets
    S.ResetDocClass()
    -- find a documented event payload field marked NeverSecret, and an always-secret API
    local neverEv, neverPos, alwaysApi
    for _, sys in ipairs(ForeverDumpDocsDB.systems or {}) do
        for _, e in ipairs(sys.Events or {}) do
            for i, pl in ipairs(e.Payload or {}) do
                if pl.NeverSecret and not neverEv and i <= 4 then neverEv, neverPos = e.LiteralName, i end
            end
        end
        for _, f in ipairs(sys.Functions or {}) do
            if f.SecretReturns and not sys.Namespace and not alwaysApi and _G[f.Name] then alwaysApi = f.Name end
        end
    end
    check(neverEv ~= nil and alwaysApi ~= nil, "docs give a NeverSecret payload field (" .. tostring(neverEv) .. " #" .. tostring(neverPos)
        .. ") and an always-secret API (" .. tostring(alwaysApi) .. ")")
    -- deliberate contradiction 1: NeverSecret payload field arrives secret
    local args = { "player", "x", "y", "z" }
    args[neverPos] = W.SECRET
    ns.ObserveLive("event", neverEv, unpack(args, 1, 4))
    -- deliberate contradiction 2: always-secret API returns a clear value out of combat
    S.ObserveResult(alwaysApi, ns.SafeCall(function() return 1234 end), "player")
    local live = ForeverDumpDB.secretsLive
    local found1, found2
    for _, c in ipairs(live.contradictions) do
        if c.key == "event:" .. neverEv and c.pos == neverPos and c.doc == "never" and c.observed == "secret" then found1 = c end
        if c.key == "api:" .. alwaysApi and c.pos == 1 and c.doc == "always" and c.observed == "clear" then found2 = c end
    end
    check(found1 and found1.ctx == "ooc/none/self" and found1.sid and found1.t, "contradiction: NeverSecret field observed secret (ctx ooc/none/self, stamped)")
    check(found2 ~= nil, "contradiction: always-secret API observed clear")
    -- context buckets: same event in combat with another unit
    W.state.combat = true
    args[1] = "target"
    ns.ObserveLive("event", neverEv, unpack(args, 1, 4))
    W.state.combat = false
    local row = ForeverDumpDB.secretsObs["event:" .. neverEv]
    check(row.x[neverPos]["ooc/none/self"][2] == 1 and row.x[neverPos]["combat/none/other"][2] == 1, "per-context buckets (state/instance/unit)")
    check(row[1][1] >= 1 and row[1][3] >= 1 and row[1][2] == 0, "position 1 (unit) counted clear in and out of combat")
    -- canaccessvalue path is exercised (inaccessible counter exists)
    check(row.x[1]["ooc/none/self"][3] == 0, "canaccessvalue counter present")
    -- sweep
    local cands = S.SweepCandidates()
    check(#cands > 10, "sweep candidates from docs: " .. #cands)
    local calls = S.SweepTick(40)
    check(calls >= 20, "sweep tick made " .. calls .. " getter calls")
    local swept = 0
    for _, c in ipairs(cands) do if ForeverDumpDB.secretsObs["api:" .. c.path] then swept = swept + 1 end end
    check(swept >= 10, "sweep results tallied per API (" .. swept .. ")")
    check(S.StartSweep() and S.IsSweeping(), "sweep starts")
    W.tick(3)
    check(S.StopSweep() > calls, "sweep runs on the timer and stops")
    -- panel
    S.TogglePanel(true)
    check(_G.ForeverDumpSecretsPanel and _G.ForeverDumpSecretsPanel:IsShown(), "live panel shows")
    check(S.PanelText():find("contradictions: %d") ~= nil, "panel text lists contradictions")
    S.TogglePanel(false)
    W.slash("secrets sweep status")
    -- bounded counters
    local cfgS = ns.config.secrets
    local oldMax = cfgS.maxCtx
    cfgS.maxCtx = 2
    for i = 1, 6 do ns.ObserveLive("event", "FD_TEST_EVENT", "party" .. i) W.state.combat = (i % 2 == 0) end
    W.state.combat = false
    local nCtx = 0
    for k in pairs(ForeverDumpDB.secretsObs["event:FD_TEST_EVENT"].x[1]) do if k ~= "_n" then nCtx = nCtx + 1 end end
    check(nCtx <= 2, "context buckets bounded by secrets.maxCtx")
    cfgS.maxCtx = oldMax
end

print("compact vs full dump")
do
    local t = ForeverDumpDB.sections.globals.tables.TaintedAddonDB
    check(t and t.insecure and t.fields == nil and t.children == nil and t.count == 2, "compact: addon table = name + shape only (no personal data)")
    W.slash("set dump.full true")
    for _, sct in ipairs({ "globals", "strings", "protected", "frames" }) do W.slash(sct) end
    W.runUntilIdle(ns)
    t = ForeverDumpDB.sections.globals.tables.TaintedAddonDB
    check(t and t.children and t.children.profileKeys, "full: addon table surveyed")
    check(ForeverDumpStringsDB.strings and ForeverDumpStringsDB.strings.ITEM_LEVEL == "Item Level %d", "full: global string values")
    check(ForeverDumpDB.sections.protected.counts.plainSecureOmitted == 0, "full: every protected row kept")
    W.slash("set dump.full false")
    for _, sct in ipairs({ "globals", "strings", "protected", "frames" }) do W.slash(sct) end
    W.runUntilIdle(ns)
    check(ForeverDumpStringsDB.compact == true, "back to compact")
end

print("ui / clear / set")
for _, v in ipairs({ "status", "apis", "events", "enums", "cvars", "all", "docs", "globals", "widgets" }) do W.slash("show " .. v) end
W.slash("set frameBudgetMs 8")
check(ForeverDumpDB.config.frameBudgetMs == 8, "/fdump set")

check(W.state.touchedSecret == 0, "no secret value was ever touched, controls matrix and lab included (" .. W.state.touchedSecret .. ")")
do
    local found
    for _, rec in ipairs(ForeverDumpLogDB.controls or {}) do
        local m = rec.ops and rec.ops["UnitHealth(player)"]
        if rec.ctx == "combat" and m and m.arith then found = m end
    end
    -- v2.2.11 (run 9 taint.log): a secret operand is classified and skipped, never operated on
    local clearRow
    for _, rec in ipairs(ForeverDumpLogDB.controls or {}) do
        local m = rec.ops and rec.ops["UnitHealth(player)"]
        if rec.ctx ~= "combat" and m and m.state == "C" then clearRow = m end
    end
    check(found == nil, "ops matrix (combat): no operation attempted on the secret UnitHealth")
    local sk
    for _, rec in ipairs(ForeverDumpLogDB.controls or {}) do
        local m = rec.ops and rec.ops["UnitHealth(player)"]
        if rec.ctx == "combat" and m then sk = m end
    end
    check(sk and sk.state == "S" and sk.skipped and sk.arith == nil and sk.tostring == nil and sk.print == nil,
        "ops matrix (combat): UnitHealth secret recorded as S + skipped (no arith/tostring/print)")
    check(clearRow and clearRow.arith and clearRow.arith.ok == true and clearRow.tostring,
        "ops matrix (ooc): clear UnitHealth still runs every op")
    check((W.state.touchedByControls or 0) == 0, "controls matrix / lab touched no secret: " .. tostring(W.state.touchedByControls))
end
os.execute("mkdir -p " .. outPath:match("^(.*)/"))
W.writeSavedVariables(outPath, W.SV_NAMES)   -- exactly the toc's SavedVariables (what the client writes)
local f = io.open(outPath); local size = f:seek("end"); f:close()
print(string.format("wrote %s (%.1f MB)", outPath, size / 1048576))
if os.getenv("SHOW_CHAT") then for _, m in ipairs(W.chat) do print("    chat: " .. m) end end
do
    local m = ForeverDumpDB.meta or (ForeverDumpDB.sections.api and ForeverDumpDB.sections.api.meta)
    check(m and m.projectID == 18 and m.projectName == "WOW_PROJECT_CAMELOT", "meta records Camelot project id/name")
    check(m and m.projectConstants and m.projectConstants.WOW_PROJECT_MAINLINE == 1, "meta records all WOW_PROJECT_* constants")
    check(m and m.scriptsDisallowedForBeta == true, "meta records scriptsDisallowedForBeta")
end
print(failures == 0 and "SMOKE OK" or ("SMOKE FAILED: " .. failures))
os.exit(failures == 0 and 0 or 1)
