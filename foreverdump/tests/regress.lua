-- v2.2 regression + restrictions tracker tests. usage: lua5.1 tests/regress.lua ForeverDump [scenario]
-- Runs each scenario in its own process (the harness keeps global state).
--   b-v21     reproduces bug B with the v2.1 addon (from ForeverDump-v2.1.zip): FD_Logs ON installs
--             hooksecurefunc(EventRegistry, "TriggerEvent"); Blizzard's real CallbackRegistry (ref/ Gethe forever
--             source) then errors in the Forever hook trampoline for secure-dispatched TriggerEvent calls.
--             This scenario is EXPECTED to see errors (it proves the test catches the bug).
--   b-v22     same flow with the current addon: no hooks, zero errors, TriggerEvent untouched; opt-in callbacks
--             recorded through EventRegistry:RegisterCallback (real secureexecuterange dispatch); an error in our
--             callback body never reaches the error handler.
--   restr     restrictions tracker: flips + context markers + flip probes (at event and next frame), stamps, health
--             self-check (detects a foreign wrap of EventRegistry.TriggerEvent), error origins, blocked context,
--             verifier nil handling (documented always-secret getter returning nil is NOT a contradiction).
--   classify  five-state classifier (nil/secret/container-secret/container-clear/clear, duration objects via
--             :HasSecretValues()), field-level SecretWhen* expansion, same-frame predicate contradiction rules.
--   forced    forced-restriction CVar sweep restores every original (finish, combat abort, logout, next login),
--             debug CVar toggle restores taintLog/taintLogObjectSecrets.
--   macro     every macro body ForeverDump generates is <= 255 characters (chat/macro limit).
package.path = "./tests/?.lua;" .. package.path
local addonDir = arg[1] or "ForeverDump"
local scenario = arg[2]
local failures = 0
local function check(cond, msg)
    if cond then print("  ok   " .. msg) else failures = failures + 1 print("  FAIL " .. msg) end
end

if not scenario then
    local ok = true
    for _, s in ipairs({ "b-v21", "b-v22", "restr", "classify", "forced", "macro" }) do
        local r = os.execute("lua5.1 tests/regress.lua " .. addonDir .. " " .. s)
        if r ~= 0 and r ~= true then ok = false end
    end
    print(ok and "REGRESS OK" or "REGRESS FAILED")
    os.exit(ok and 0 or 1)
end

local W = require("wowenv")
local function tocFiles(dir)
    local files = {}
    for line in io.lines(dir .. "/ForeverDump.toc") do
        if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
    end
    return files
end

local dir = addonDir
if scenario == "b-v21" then
    dir = "tests/out/v21/ForeverDump"
    local f = io.open(dir .. "/Recorder.lua", "r")
    if not f then
        os.execute("python3 -c \"import zipfile;z=zipfile.ZipFile('ForeverDump-v2.1.zip');"
            .. "[z.extract(n,'tests/out/v21') for n in z.namelist() if n.startswith('ForeverDump/')]\"")
        f = io.open(dir .. "/Recorder.lua", "r")
    end
    if not f then print("  skip (ForeverDump-v2.1.zip not found)") print("scenario b-v21 OK") os.exit(0) end
    f:close()
end

check(W.realEventRegistry == true, "Blizzard CallbackRegistry.lua + GlobalCallbackRegistry.lua loaded from ref/ (real source)")
local mixinTrigger = CallbackRegistryMixin.TriggerEvent
local ns = W.loadAddon(dir, tocFiles(dir), "ForeverDump")
W.fire("ADDON_LOADED", "ForeverDump")
W.fire("PLAYER_LOGIN")
ns.config.logs.fullDump = false

-- Blizzard-side traffic: a callback owner like MainMenuBarMicroButtons/ObjectiveTracker, GLOBAL_MOUSE_DOWN through
-- EventRegistry.frameEventFrame (secure dispatch), and plain addon-driven TriggerEvent calls
local blizzSeen = 0
EventRegistry:RegisterCallback("GLOBAL_MOUSE_DOWN", function() blizzSeen = blizzSeen + 1 end, {})
EventRegistry:RegisterCallback("Tooltip.OnShown", function() blizzSeen = blizzSeen + 1 end, {})
local function blizzardTraffic()
    local before = W.state.errorsShown or 0
    W.state.secureDispatch = true
    for _ = 1, 5 do EventRegistry:TriggerEvent("GLOBAL_MOUSE_DOWN", "LeftButton") end
    EventRegistry:TriggerEvent("UI.QueryStickyFocusFrames")
    EventRegistry:TriggerEvent("PlunderstormQueueTutorial.Update")
    W.state.secureDispatch = false
    for _ = 1, 3 do EventRegistry:TriggerEvent("Tooltip.OnShown", "GameTooltip") end
    return (W.state.errorsShown or 0) - before + #ForeverDumpLogDB.errors * 0
end

if scenario == "b-v21" or scenario == "b-v22" then
    local base = blizzardTraffic()
    check(base == 0 and blizzSeen == 8, "baseline (capture OFF): Blizzard registry dispatch clean, " .. blizzSeen .. " callbacks")
    local errs0 = 0
    for _, e in ipairs(ForeverDumpLogDB.errors) do errs0 = errs0 + (e.count or 1) end
    W.slash("logs on")
    W.tick(3)
    blizzSeen = 0
    blizzardTraffic()
    local errs = 0
    for _, e in ipairs(ForeverDumpLogDB.errors) do errs = errs + (e.count or 1) end
    errs = errs - errs0
    if scenario == "b-v21" then
        check(errs == 7, "v2.1 REPRODUCES bug B: 'attempt to call a nil value' x" .. errs .. " in the TriggerEvent trampoline")
        check(EventRegistry.TriggerEvent ~= mixinTrigger, "v2.1 replaced EventRegistry.TriggerEvent (hook installed at FD_Logs ON)")
        check(blizzSeen == 3, "v2.1: secure-dispatched calls never reached Blizzard's own callbacks (UI broken): " .. blizzSeen)
    else
        check(errs == 0, "regression B: no errors while capturing (" .. errs .. ")")
        check(blizzSeen == 8, "Blizzard callbacks all ran during capture: " .. blizzSeen)
        check(EventRegistry.TriggerEvent == mixinTrigger,
            "EventRegistry.TriggerEvent untouched (no hooksecurefunc / replacement)")
        local hooked = 0
        for _, h in ipairs(W.hooks) do if h.tbl == EventRegistry or h.tbl == CallbackRegistryMixin then hooked = hooked + 1 end end
        check(hooked == 0 and #W.hooks == 0, "ForeverDump installed no hooksecurefunc at all (" .. #W.hooks .. ")")
        check(ns.config.record.callbacks == false, "record.callbacks defaults to false")
        check(ns.Restrictions.Health().ok == true and ns.Restrictions.Health().replaced == nil, "health self-check OK")
        -- opt-in callbacks
        W.slash("logs off")
        ns.config.record.callbacks = true
        ns.config.record.callbackEvents = { "Tooltip.OnShown", "GLOBAL_MOUSE_DOWN" }
        W.slash("logs on")
        W.tick(2)
        W.state.secureDispatch = true
        EventRegistry:TriggerEvent("GLOBAL_MOUSE_DOWN", "RightButton")
        W.state.secureDispatch = false
        EventRegistry:TriggerEvent("Tooltip.OnShown", "GameTooltip")
        -- a failing callback body (simulated) must be contained by our pcall
        local realPack = ns.SerializeArg
        ns.SerializeArg = function() error("boom in our callback") end
        local e0 = W.state.errorsShown or 0
        EventRegistry:TriggerEvent("Tooltip.OnShown", "GameTooltip")
        ns.SerializeArg = realPack
        local leaked = (W.state.errorsShown or 0) - e0
        W.slash("logs off")
        local sess = ForeverDumpRecordDB.sessions[#ForeverDumpRecordDB.sessions]
        local cb = {}
        for _, ev in ipairs(sess.events) do if ev.cb then cb[ev.e] = (cb[ev.e] or 0) + 1 end end
        check(cb["Tooltip.OnShown"] and cb.GLOBAL_MOUSE_DOWN, "opt-in RegisterCallback recorded Tooltip.OnShown + GLOBAL_MOUSE_DOWN")
        check(sess.callbacksRegistered == 2, "2 callbacks registered via the public API (" .. tostring(sess.callbacksRegistered) .. ")")
        check(leaked == 0, "error inside our callback contained (never reached the error handler)")
        local owners = 0
        for _, t in pairs(EventRegistry:GetCallbackTables()) do
            for _, byOwner in pairs(t) do if byOwner[ns.Recorder.CallbackOwner] then owners = owners + 1 end end
        end
        check(owners == 0, "callbacks unregistered at capture OFF")
        check(EventRegistry.TriggerEvent == mixinTrigger, "still no hook after opt-in capture")
    end
elseif scenario == "restr" then
    W.state.restr = { [0] = 0, 0, 0, 0, 0, 0 }
    C_RestrictedActions.GetAddOnRestrictionState = function(t) return W.state.restr[t] end
    W.slash("logs on")
    W.tick(3)
    local sid = ForeverDumpDB.logs.session.sid
    local rs = ForeverDumpLogDB.restrictions
    check(rs and rs.sessions and rs.sessions[#rs.sessions].sid == sid and rs.sessions[#rs.sessions].probeAtStart,
        "capture ON: restrictions session baseline (states + probe) with capture sid")
    -- combat start: Activating fires before InCombatLockdown is true (seen in the real run: inCombat=false, state 1)
    W.state.restr[0] = 1
    W.fire("ADDON_RESTRICTION_STATE_CHANGED", 0, 1)
    W.state.combat = true
    W.state.restr[0] = 2
    W.fire("PLAYER_REGEN_DISABLED")
    W.tick(1)
    local f1 = rs.flips[#rs.flips]
    check(f1 and f1.typeName == "Combat" and f1.stateName == "Activating" and f1.sid == sid and f1.t and f1.server and f1.epoch,
        "flip logged with type/state names and common timebase stamp")
    check(f1.ctx and f1.ctx.instance and f1.states and f1.states.Combat == 1, "flip carries trigger context + all restriction states")
    if os.getenv("DEBUG") then for k, v in pairs(f1.probeAt or {}) do print("   at", k, tostring(v)) end
        for k, v in pairs(f1.probeAfter or {}) do print("   after", k, tostring(v)) end end
    check(f1.probeAt and f1.probeAt.UnitHealth == "C", "probe at the event: UnitHealth still clear (Activating not enforced)")
    check(f1.probeAfter and f1.probeAfter.UnitHealth == "S" and f1.statesAfter.Combat == 2,
        "probe next frame: UnitHealth secret, Combat=Active")
    check(f1.probeAfter.predicates and f1.probeAfter.predicates.ShouldAurasBeSecret == true, "C_Secrets predicates snapshotted at the flip")
    check(rs.markers[#rs.markers].event == "PLAYER_REGEN_DISABLED" and rs.markers[#rs.markers].sid == sid, "PLAYER_REGEN_DISABLED marker")
    W.fire("ENCOUNTER_START", 1234, "Mock Boss", 1, 5)
    W.state.restr[1] = 1
    W.fire("ADDON_RESTRICTION_STATE_CHANGED", 1, 1)
    local f2 = rs.flips[#rs.flips]
    check(f2.typeName == "Encounter" and f2.ctx.encounter and f2.ctx.encounter.id == 1234 and f2.ctx.lastMarker == "ENCOUNTER_START",
        "encounter flip knows the encounter + last marker")
    W.fire("ENCOUNTER_END", 1234, "Mock Boss", 1, 5, 1)
    W.state.restr[1] = 0
    W.fire("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
    W.state.combat = false
    W.state.restr[0] = 0
    W.fire("ADDON_RESTRICTION_STATE_CHANGED", 0, 0)
    W.fire("PLAYER_REGEN_ENABLED")
    W.tick(1)
    check(rs.counts["Combat:Activating"] == 1 and rs.counts["Combat:Inactive"] == 1 and rs.counts["Encounter:Inactive"] == 1, "flip counts")
    check(#rs.markers >= 4, "context markers: " .. #rs.markers)
    -- error origins + blocked context
    local ds = debugstack
    local n = 0
    debugstack = function()
        n = n + 1
        return "[Interface/AddOns/ForeverDump/Errors.lua]:74: in function <x>\n[C]: ?\n[C]: in function 'TriggerEvent'\n"
            .. (n % 2 == 0 and "[Interface/AddOns/Blizzard_SharedXMLBase/GlobalCallbackRegistry.lua]:11: in function <y>"
                or "[Interface/AddOns/Blizzard_MicroMenu/Mainline/MainMenuBarMicroButtons.lua]:1503: in function 'UpdateMicroButton'")
    end
    for _ = 1, 4 do W.raiseError("attempt to call a nil value") end
    debugstack = ds
    local e
    for _, x in ipairs(ForeverDumpLogDB.errors) do if x.message == "attempt to call a nil value" then e = x end end
    local no = 0
    for _ in pairs(e and e.origins or {}) do no = no + 1 end
    check(e and e.count == 4 and no == 2 and e.duringCapture == 4, "same message from 2 call sites -> 2 origins, duringCapture counted")
    W.fire("ADDON_ACTION_BLOCKED", "TweaksForever", "CastSpellByName()")
    local b = ForeverDumpLogDB.blocked[#ForeverDumpLogDB.blocked]
    check(b.duringCapture and b.restrictions == "none" and b.taintLog ~= nil, "blocked action carries capture flag, restriction states, taintLog")
    local h = ns.Restrictions.Health()
    check(h.nilCallInCFunction and h.nilCallInCFunction.TriggerEvent == 4, "health: nil-calls inside [C] TriggerEvent classified")
    check(h.blockedByAddon and h.blockedByAddon.TweaksForever, "health: blocked actions attributed per addon")
    -- someone else wraps EventRegistry.TriggerEvent -> detected
    local orig = EventRegistry.TriggerEvent
    EventRegistry.TriggerEvent = function(...) return orig(...) end
    check(ns.Restrictions.Health().replaced and ns.Restrictions.Health().replaced["EventRegistry.TriggerEvent"],
        "health detects a foreign replacement of EventRegistry.TriggerEvent")
    EventRegistry.TriggerEvent = nil
    -- verifier: nil is not "clear"
    ns.Secrets.ObserveResult("C_Secrets.MockAlwaysSecret", { ok = true, n = 2, values = { "<nil>", 5 } })
    local row = ForeverDumpDB.secretsObs["api:C_Secrets.MockAlwaysSecret"]
    check(row and row.nl and row.nl[1] == 1 and row[1][1] + row[1][3] + row[1][5] == 0 and row[2][1] + row[2][3] + row[2][5] == 1,
        "verifier: nil return counted as absent (row.nl), not as clear")
    W.slash("logs off")
    local last = ForeverDumpDB.logs.lastSession
    check(last.health and last.restrictions and last.sid == sid, "OFF summary carries health + restrictions + sid")
    check(rs.sessions[#rs.sessions].ended and rs.sessions[#rs.sessions].flips == 4, "restrictions session closed with 4 flips")
    W.writeSavedVariables("tests/out/ForeverDump-restr.lua", { "ForeverDumpDB", "ForeverDumpLogDB", "ForeverDumpRecordDB", "ForeverDumpCombatLogDB" })
end
if scenario == "classify" then
    local SECRET = W.SECRET
    local function dur(secretInside)
        local u = newproxy(true)
        getmetatable(u).__index = { HasSecretValues = function() return secretInside end }
        return u
    end
    local cv = ns.ClassifyValue
    check(cv(nil) == "N" and cv(SECRET) == "S" and cv(1) == "C" and cv("x") == "C", "scalars: nil N, secret S, clear C")
    check(cv({ a = SECRET }) == "T" and cv({ a = 1, b = "x" }) == "K", "tables: secret contents T, clear contents K")
    check(cv(dur(true)) == "T" and cv(dur(false)) == "K", "duration object: HasSecretValues() true -> T, false -> K (issecretvalue(obj) is false)")
    local f = ns.ClassifyFields({ startTime = SECRET, isEnabled = true })
    check(f and f.startTime == "S" and f.isEnabled == "C", "struct fields classified one level deep")
    local r = ns.SafeCall(function() return nil, SECRET, dur(true), { duration = SECRET, isActive = false } end)
    check(r.states[1] == "N" and r.states[2] == "S" and r.states[3] == "T" and r.states[4] == "T"
        and r.fstates[4].duration == "S" and r.fstates[4].isActive == "C", "SafeCall records per-return states + struct field states")
    -- mini docs: an always-secret API (Nilable), a container API, a conditional struct API with NeverSecret fields
    ForeverDumpDocsDB = { sharedTables = { { Name = "MockCooldownInfo", Type = "Structure", Fields = {
            { Name = "startTime", Type = "number" }, { Name = "isEnabled", Type = "bool", NeverSecret = true } } } },
        systems = { { Name = "Mock", Namespace = "C_Mock", Functions = {
            { Name = "AlwaysSecret", SecretReturns = true, Returns = { { Name = "result", Type = "number", Nilable = true } } },
            { Name = "Duration", SecretReturns = true, MayReturnNothing = true, Returns = { { Name = "d", Type = "LuaDurationObject" } } },
            { Name = "Cooldown", SecretWhenCooldownsRestricted = true, Returns = { { Name = "info", Type = "MockCooldownInfo" } } },
        }, Events = {}, Tables = {} } } }
    ns.Secrets.ResetDocClass()
    ns.db.secretsLive = nil
    ns.Secrets.ResetLive()
    local predicate = false
    C_Secrets.ShouldSpellCooldownBeSecret = function() return predicate end
    local O = ns.Secrets.ObserveResult
    O("C_Mock.AlwaysSecret", ns.SafeCall(function() return nil end), "target", { n = 1, "target" })
    O("C_Mock.AlwaysSecret", ns.SafeCall(function() return SECRET end), "player", { n = 1, "player" })
    O("C_Mock.Duration", ns.SafeCall(function() return dur(false) end), "player", { n = 1, "player" })
    O("C_Mock.Duration", ns.SafeCall(function() end), "player", { n = 1, "player" })
    local obs = ForeverDumpDB.secretsObs
    local a = obs["api:C_Mock.AlwaysSecret"]
    check(a.nl[1] == 1 and a[1][1] + a[1][3] + a[1][5] == 1 and a[1][2] + a[1][4] + a[1][6] == 1,
        "always-secret API: nil -> row.nl, only the present (secret) value is counted")
    local d = obs["api:C_Mock.Duration"]
    check(d.ct and d.ct[1][1] == 1 and d.ct[1][2] == 0 and d.ab and d.ab[1] == 1, "container counted in row.ct, empty return counted as absent")
    check(#ns.db.secretsLive.contradictions == 0, "no live contradiction for nil / container returns (v2.1 false positives)")
    -- conditional struct: predicate false + clear (ok), predicate true + secret fields (ok), NeverSecret clear (ok)
    O("C_Mock.Cooldown", ns.SafeCall(function() return { startTime = 0, isEnabled = true } end), nil, { n = 1, 61304 })
    predicate = true
    O("C_Mock.Cooldown", ns.SafeCall(function() return { startTime = SECRET, isEnabled = true } end), nil, { n = 1, 1752 })
    local ft = obs["field:C_Mock.Cooldown#1.startTime"]
    check(ft and ft.pv and ft.pv[1][1] == 1 and ft.pv[1][4] == 1 and ft.pv[1][2] == 0 and ft.pv[1][3] == 0,
        "field-level expansion: startTime follows the function's SecretWhenCooldownsRestricted predicate (same frame)")
    check(ns.Secrets.DocFieldClass("api:C_Mock.Cooldown", 1, "isEnabled") == "never"
        and ns.Secrets.DocFieldClass("api:C_Mock.Cooldown", 1, "startTime") == "conditional", "DocFieldClass: NeverSecret vs propagated tag")
    check(#ns.db.secretsLive.contradictions == 0, "documented behaviour -> no contradiction")
    -- real contradictions: predicate false but secret; NeverSecret field secret
    predicate = false
    O("C_Mock.Cooldown", ns.SafeCall(function() return { startTime = SECRET, isEnabled = SECRET } end), nil, { n = 1, 1752 })
    local kinds = {}
    for _, c in ipairs(ns.db.secretsLive.contradictions) do kinds[c.key .. "/" .. c.observed] = true end
    check(kinds["field:C_Mock.Cooldown#1.startTime/secret-while-predicate-false"], "contradiction: secret while Should*BeSecret said false")
    check(kinds["field:C_Mock.Cooldown#1.isEnabled/secret"], "contradiction: NeverSecret field observed secret")
    -- always-secret API returning a present clear scalar is still a contradiction
    O("C_Mock.AlwaysSecret", ns.SafeCall(function() return 5 end), "player", { n = 1, "player" })
    kinds = {}
    for _, c in ipairs(ns.db.secretsLive.contradictions) do kinds[c.key .. "/" .. c.observed] = true end
    check(kinds["api:C_Mock.AlwaysSecret/clear"], "contradiction: documented SecretReturns, present clear value")
elseif scenario == "forced" then
    local names = { "addonCombatRestrictionsForced", "addonEncounterRestrictionsForced", "addonChallengeModeRestrictionsForced",
        "addonPvPMatchRestrictionsForced", "addonMapRestrictionsForced", "addonChatRestrictionsForced" }
    for _, n in ipairs(names) do W.CVARS[n] = { "0", "0" } end
    W.CVARS.addonMapRestrictionsForced[1] = "1"   -- a non-default original must come back as "1"
    W.CVARS.taintLogObjectSecrets = { "0", "0" }
    local seen = {}
    local realSet = C_CVar.SetCVar
    C_CVar.SetCVar = function(n, v) seen[n] = seen[n] or {} seen[n][#seen[n] + 1] = tostring(v) return realSet(n, v) end
    W.state.combat = true
    W.slash("secrets forced")
    check(ns.db.forcedSweep == nil or ns.db.forcedSweep.inProgress == nil, "refused in combat")
    W.state.combat = false
    W.slash("secrets forced")
    check(ns.db.forcedSweep.inProgress and ns.db.forcedSweep.originals.addonMapRestrictionsForced == "1", "originals persisted before any change")
    W.tick(20)
    local run = ns.db.forcedSweep.runs[#ns.db.forcedSweep.runs]
    check(run.finished and #run.types == 6 and run.types[1].result and run.types[1].valueAfterSet == "1", "6 types swept, each probed after a frame")
    local allBack = true
    for _, n in ipairs(names) do if W.CVARS[n][1] ~= (n == "addonMapRestrictionsForced" and "1" or "0") then allBack = false end end
    check(allBack and ns.db.forcedSweep.inProgress == nil and ns.db.forcedSweep.originals == nil, "finish: every CVar back to its original")
    check(seen.addonCombatRestrictionsForced and seen.addonCombatRestrictionsForced[1] == "1" and seen.addonCombatRestrictionsForced[2] == "0",
        "set 1 then restored per step")
    -- abort when combat starts mid-sweep
    W.slash("secrets forced")
    W.tick(1)
    W.state.combat = true
    W.fire("PLAYER_REGEN_DISABLED")
    allBack = true
    for _, n in ipairs(names) do if W.CVARS[n][1] ~= (n == "addonMapRestrictionsForced" and "1" or "0") then allBack = false end end
    check(allBack and ns.db.forcedSweep.runs[#ns.db.forcedSweep.runs].aborted, "combat abort: all restored, run marked aborted")
    W.state.combat = false
    -- logout mid-sweep
    W.slash("secrets forced")
    W.fire("PLAYER_LOGOUT")
    check(W.CVARS.addonCombatRestrictionsForced[1] == "0" and ns.db.forcedSweep.restored.why == "logout", "PLAYER_LOGOUT mid-sweep restores")
    -- crash: SV says a sweep was in progress -> restored at the next login
    ns.db.forcedSweep.inProgress = true
    ns.db.forcedSweep.originals = { addonChatRestrictionsForced = "0" }
    W.CVARS.addonChatRestrictionsForced[1] = "1"
    W.fire("PLAYER_LOGIN")
    check(W.CVARS.addonChatRestrictionsForced[1] == "0" and ns.db.forcedSweep.restored.why:find("interrupted"), "next login restores an interrupted sweep")
    -- debug CVars
    W.CVARS.taintLog[1] = "0"
    W.slash("debug on")
    check(W.CVARS.taintLog[1] == "2" and W.CVARS.taintLogObjectSecrets[1] == "1", "debug on: taintLog 2 + taintLogObjectSecrets 1")
    W.slash("logs on") W.tick(2) W.slash("logs off")
    check(W.CVARS.taintLog[1] == "2", "FD_Logs leaves the debug taintLog alone")
    W.slash("debug off")
    check(W.CVARS.taintLog[1] == "0" and W.CVARS.taintLogObjectSecrets[1] == "0", "debug off restores originals")
    W.CVARS.taintLog[1] = "3"
    W.slash("logs on") W.tick(2) W.slash("logs off")
    check(W.CVARS.taintLog[1] == "3", "FD_Logs restores the user's own taintLog value (was reset to 0 in v2.1)")
elseif scenario == "macro" then
    W.slash("logs macro")
    local bodies = {}
    for _, m in ipairs(W.state.macros) do bodies[#bodies + 1] = m.body end
    W.clickMacro("FD_Logs") W.tick(2)
    for _, m in ipairs(W.state.macros) do bodies[#bodies + 1] = m.body end
    W.clickMacro("FD_Logs") W.tick(2)
    for _, m in ipairs(W.state.macros) do bodies[#bodies + 1] = m.body end
    local maxLen, all = 0, true
    for _, b in ipairs(bodies) do maxLen = math.max(maxLen, #b) if #b > 255 then all = false end end
    check(#bodies >= 3 and all, "every generated macro body <= 255 chars (max " .. maxLen .. ", " .. #bodies .. " bodies)")
end
if failures > 0 then print("FAILED " .. failures) os.exit(1) end
print("scenario " .. scenario .. " OK")
