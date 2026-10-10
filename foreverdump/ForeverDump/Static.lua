-- ForeverDump v2.2.11 - static client data in its own SavedVariables table, collected ONLY on request.
-- The static boilerplate (API docs, C_ namespaces, globals, string globals, widgets, templates, frames, addons, CVars,
-- protected-function map, extras; ~11.6 MB / ~545k SV lines on build 70291) lives in ForeverDumpStaticDB:
--   * v2.2.11 (user decision): NO automatic run - not after login, not once per new build, not from /fdump all, not
--     from FD_Logs. The ONLY trigger is the slash command `/fdump static run` (`force` = alias). tests/static_once.lua +
--     tests/test_v2211_static.py fail if any other code path reaches ST.Start.
--   * `/fdump static status|check` report what is held and whether it matches the current client signature
--     (GetBuildInfo + C_* namespace/function hash + Enum count); a new build only shows "stale - /fdump static run".
--   * whatever is in ForeverDumpStaticDB PERSISTS in SavedVariables\ForeverDump.lua (every save, every capture) until
--     `/fdump static clear`; the build marker (ForeverDumpDB.static) stays.
-- Runtime readers keep working: ForeverDumpDocsDB / ForeverDumpStringsDB are plain runtime globals (not
-- SavedVariables) aliased to the static tables, and ns.db.sections / ns.db fall back (metatable __index, never
-- serialized) to the static sections and v1 keys.
local _, ns = ...
local ST = {}
ns.Static = ST

ST.SECTIONS = { "docs", "api", "globals", "strings", "widgets", "templates", "frames", "addons", "cvars", "protected", "extras" }
local IS_STATIC = {}
for _, n in ipairs(ST.SECTIONS) do IS_STATIC[n] = true end
ST.V1 = { "apis", "events", "enums", "cvars", "cvarNames", "commands", "build", "version", "buildNumber", "toc" }
local IS_V1 = {}
for _, n in ipairs(ST.V1) do IS_V1[n] = true end
function ST.IsStatic(name) return IS_STATIC[name] == true end

local function g(n) return rawget(_G, n) end
local function now() local f = g("GetTime") if type(f) == "function" then return f() end return 0 end
local function epoch() local f = g("time") if type(f) == "function" then return f() end return nil end
local function after(s, f) local ct = g("C_Timer") if type(ct) == "table" and ct.After then ct.After(s, f) end end

function ST.DB()
    local s = g("ForeverDumpStaticDB")
    if type(s) ~= "table" then s = {} ForeverDumpStaticDB = s end
    if type(s.sections) ~= "table" then s.sections = {} end
    if type(s.v1) ~= "table" then s.v1 = {} end
    s.schemaVersion = ns.SCHEMA
    return s
end
function ST.Sections() return ST.DB().sections end
function ST.Put(kind, tbl)
    local s = ST.DB()
    if kind == "docs" then s.docs = tbl ForeverDumpDocsDB = tbl
    elseif kind == "strings" then s.strings = tbl ForeverDumpStringsDB = tbl end
end
function ST.StoreV1(fields)
    local v1 = ST.DB().v1
    for k, v in pairs(fields) do v1[k] = v end
end

----------------------------------------------------------------------------- signature
local function djb(h, s)
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
    return h
end
function ST.Signature()
    local okB, version, _, bdate, toc = pcall(function() return GetBuildInfo() end)
    if not okB then version, bdate, toc = nil, nil, nil end
    local names = {}
    for k, v in next, _G do
        if type(k) == "string" and k:sub(1, 2) == "C_" and type(v) == "table" then names[#names + 1] = k end
    end
    table.sort(names)
    local h, nFn = 5381, 0
    for _, k in ipairs(names) do
        local c = 0
        for _, f in next, _G[k] do if type(f) == "function" then c = c + 1 end end
        nFn = nFn + c
        h = djb(h, k .. ":" .. c .. ";")
    end
    local nEnum = 0
    local E = g("Enum")
    if type(E) == "table" then for _ in next, E do nEnum = nEnum + 1 end end
    h = djb(h, "enum:" .. nEnum)
    local sig = {
        version = ns.ClearStr(version), build = ns.Build(), buildDate = ns.ClearStr(bdate), toc = ns.ClearNum(toc),
        namespaces = #names, functions = nFn, enums = nEnum, apiHash = string.format("%08x", h),
    }
    sig.key = table.concat({ tostring(sig.version), tostring(sig.build), tostring(sig.toc), sig.apiHash }, "|")
    return sig
end

----------------------------------------------------------------------------- marker / state
function ST.Marker() return ns.db and ns.db.static end
function ST.Done(sig)
    local m = ST.Marker()
    sig = sig or ST.sig
    return type(m) == "table" and m.done == true and sig ~= nil and m.key == sig.key
end
function ST.HaveData()
    local s = g("ForeverDumpStaticDB")
    return type(s) == "table" and type(s.sections) == "table" and next(s.sections) ~= nil
end
ST.state = { phase = "idle" }   -- idle | waiting | running | done | cleared

local pending, running, reason = {}, false, nil
local function capturing() return ns.db and ns.db.logs and ns.db.logs.on == true end

local function finish()
    running = false
    local s = ST.DB()
    local sig = ST.sig or ST.Signature()
    local n = 0
    for _ in pairs(s.sections) do n = n + 1 end
    s.sig, s.done, s.finishedAt, s.reason = sig, true, epoch(), reason
    ns.db.static = { key = sig.key, build = sig.build, version = sig.version, toc = sig.toc, apiHash = sig.apiHash,
        namespaces = sig.namespaces, functions = sig.functions, done = true, time = epoch(), sections = n, reason = reason }
    ST.state = { phase = "done", sections = n, finished = now() }
    -- v2.2.27: the per-build spellbook cache (aura-presence candidates) is rebuilt by this run only
    if ns.AuraPresence and ns.AuraPresence.BuildSpellCache then
        local okC, cnt = pcall(ns.AuraPresence.BuildSpellCache)
        ST.state.spellCache = okC and cnt or ("error: " .. tostring(cnt))
    end
    ns.Print(string.format("static client data for build %s collected once (%d sections) into ForeverDumpStaticDB; "
        .. "/reload to save, ingest, then /fdump static clear. Captures no longer re-save it.", tostring(sig.build), n))
end

local function step()
    if not running then return end
    -- deferred until idle: out of combat, no capture running (forced runs ignore capture), scheduler free
    if ns.InCombat() or ns.IsBusy() or (reason ~= "manual" and capturing()) then
        ST.state.phase = "waiting"
        after(ns.IsBusy() and 1 or 5, step)
        return
    end
    local name = table.remove(pending, 1)
    if name then
        ST.state.phase, ST.state.current = "running", name
        ns.RunSection(name)
        after(0.5, step)
        return
    end
    finish()
end

-- start the static dump. v2.2.11: called ONLY from the `/fdump static run|force` slash command (Commands.lua).
function ST.Start(why)
    if why ~= "slash" then return false, "static dump runs only via /fdump static run" end
    if running then return false, "already running" end
    reason = "manual"
    ST.sig = ST.sig or ST.Signature()
    pending = {}
    for _, n in ipairs(ST.SECTIONS) do if ns.sections[n] then pending[#pending + 1] = n end end
    local s = ST.DB()
    s.startedAt, s.sig, s.done = epoch(), ST.sig, false
    running = true
    ST.state = { phase = "waiting", total = #pending, started = now(), reason = reason }
    after(0, step)
    return true
end
function ST.IsRunning() return running end

-- v2.2.11: report only (never starts anything): "done" (held data matches this client), "cleared" (collected for this
-- client, then cleared), "stale" (held/marked for another client signature), "none" (never collected)
function ST.Check()
    ST.sig = ST.Signature()
    local m = ST.Marker()
    if ST.Done(ST.sig) then ST.state.phase = ST.HaveData() and "done" or "cleared" return ST.state.phase end
    if type(m) == "table" and m.key then
        ST.state.newBuild = { from = m.key, to = ST.sig.key }
        return "stale (client signature changed: build " .. tostring(ST.sig.build) .. "; /fdump static run to collect)"
    end
    return "none (/fdump static run to collect)"
end

function ST.Clear()
    local s = g("ForeverDumpStaticDB")
    local kept = type(s) == "table" and s.sig or nil
    ForeverDumpStaticDB = { schemaVersion = ns.SCHEMA, sections = {}, v1 = {}, sig = kept, cleared = epoch() }
    ForeverDumpDocsDB, ForeverDumpStringsDB = {}, {}
    if ns.db and type(ns.db.static) == "table" then ns.db.static.cleared = epoch() end
    ST.state.phase = "cleared"
end

function ST.StatusLine()
    local m = ST.Marker()
    local s = g("ForeverDumpStaticDB")
    local n = 0
    if type(s) == "table" and type(s.sections) == "table" then for _ in pairs(s.sections) do n = n + 1 end end
    return string.format("static: %s; marker build %s api %s%s; %d static sections held%s. Collected only by /fdump static "
        .. "run; held data persists in SavedVariables\\ForeverDump.lua (every save) until /fdump static clear.",
        ST.state.phase or "?", tostring(type(m) == "table" and m.build), tostring(type(m) == "table" and m.apiHash),
        (type(m) == "table" and m.done) and " (done)" or "", n,
        running and (" (pending " .. #pending .. ", current " .. tostring(ST.state.current) .. ")") or "")
end

----------------------------------------------------------------------------- init / migration
-- called from ns.InitDB: moves pre-2.2.7 static data out of ForeverDumpDB, aliases the runtime globals and installs
-- the read fallbacks (metatables are not serialized: the capture SV holds only the marker)
function ST.Init(db)
    local s = ST.DB()
    local build = ns.Build()
    if type(db.sections) == "table" then
        for _, n in ipairs(ST.SECTIONS) do
            local sct = rawget(db.sections, n)
            if sct ~= nil then
                if type(sct) == "table" and type(sct.meta) == "table" and tostring(sct.meta.build) == build and s.sections[n] == nil then
                    s.sections[n] = sct
                end
                db.sections[n] = nil
            end
        end
    end
    for _, k in ipairs(ST.V1) do
        local v = rawget(db, k)
        if v ~= nil then
            if s.v1[k] == nil then s.v1[k] = v end
            db[k] = nil
        end
    end
    -- runtime aliases (ForeverDumpDocsDB / ForeverDumpStringsDB are not SavedVariables any more)
    local docs, strings = g("ForeverDumpDocsDB"), g("ForeverDumpStringsDB")
    if type(s.docs) == "table" then ForeverDumpDocsDB = s.docs
    elseif type(docs) ~= "table" then ForeverDumpDocsDB = {} end
    if type(s.strings) == "table" then ForeverDumpStringsDB = s.strings
    elseif type(strings) ~= "table" then ForeverDumpStringsDB = {} end
    setmetatable(db.sections, { __index = function(_, k)
        if IS_STATIC[k] then local cur = g("ForeverDumpStaticDB") return type(cur) == "table" and type(cur.sections) == "table" and cur.sections[k] or nil end
    end })
    setmetatable(db, { __index = function(_, k)
        if IS_V1[k] then local cur = g("ForeverDumpStaticDB") return type(cur) == "table" and type(cur.v1) == "table" and cur.v1[k] or nil end
    end })
end

-- v2.2.11: no PLAYER_LOGIN hook any more (the automatic once-per-build run is gone).
