-- ForeverDump v2 - profiling snapshot: /fdump profile
-- C_AddOnProfiler (if present): overall/application metrics + every Enum.AddOnProfilerMetric per loaded addon.
-- Legacy: UpdateAddOnCPUUsage/GetAddOnCPUUsage (only meaningful with CVar scriptProfile=1, needs /reload),
-- UpdateAddOnMemoryUsage/GetAddOnMemoryUsage (KB). Snapshots kept in sections.profile.snapshots (last 10).
local _, ns = ...

local function A(name) return C_AddOns and C_AddOns[name] or rawget(_G, name) end

local function call(f, ...)
    if type(f) ~= "function" then return nil, "missing" end
    local ok, v = pcall(f, ...)
    if not ok then return nil, tostring(v) end
    if ns.IsSecret(v) then return ns.SECRET end
    return ns.CleanNumber and type(v) == "number" and ns.CleanNumber(v) or v
end

local function snapshot()
    local P = rawget(_G, "C_AddOnProfiler")
    local metrics = rawget(Enum or {}, "AddOnProfilerMetric")
    local snap = { time = time and time() or nil, gameTime = GetTime(), inCombat = ns.InCombat(), addons = {} }
    local names = {}
    local num = call(A("GetNumAddOns")) or 0
    for i = 1, num do
        local name = call(A("GetAddOnInfo"), i)
        local loaded = call(A("IsAddOnLoaded"), i)
        if type(name) == "string" and loaded then names[#names + 1] = { i = i, name = name } end
    end
    if type(P) == "table" then
        snap.profiler = { enabled = call(P.IsEnabled), overall = {}, application = {} }
        if type(metrics) == "table" then
            for mName, m in pairs(metrics) do
                snap.profiler.overall[mName] = call(P.GetOverallMetric, m)
                snap.profiler.application[mName] = call(P.GetApplicationMetric, m)
            end
        end
    else
        snap.profiler = { unavailable = "C_AddOnProfiler missing" }
    end
    local scriptProfile = call(C_CVar and C_CVar.GetCVar or rawget(_G, "GetCVar"), "scriptProfile")
    snap.scriptProfile = scriptProfile
    local cpuOn = tostring(scriptProfile) == "1"
    if cpuOn then call(rawget(_G, "UpdateAddOnCPUUsage")) end
    call(rawget(_G, "UpdateAddOnMemoryUsage"))
    for _, a in ipairs(names) do
        local row = {}
        if type(P) == "table" and type(metrics) == "table" and type(P.GetAddOnMetric) == "function" then
            row.metrics = {}
            for mName, m in pairs(metrics) do row.metrics[mName] = call(P.GetAddOnMetric, a.name, m) end
        end
        row.memoryKB = call(rawget(_G, "GetAddOnMemoryUsage"), a.i)
        if cpuOn then row.cpuMs = call(rawget(_G, "GetAddOnCPUUsage"), a.i) end
        snap.addons[a.name] = row
        ns.Yield()
    end
    snap.counts = { addons = #names }
    return snap
end

-- synchronous snapshot (used by FD_Logs ON/OFF); same storage as the "profile" section
ns.Profiler = {}
function ns.Profiler.Snapshot(reason)
    local prev = ns.db.sections.profile
    local snaps = prev and prev.snapshots or {}
    local snap = snapshot()
    snap.reason = reason
    snaps[#snaps + 1] = snap
    while #snaps > 10 do table.remove(snaps, 1) end
    ns.SaveSection("profile", { latest = snap, snapshots = snaps, counts = { snapshots = #snaps, addons = snap.counts.addons } })
    return snap
end

ns.RegisterSection({
    name = "profile",
    desc = "per-addon profiling snapshot (C_AddOnProfiler metrics, memory, legacy CPU when scriptProfile=1)",
    inAll = false,
    combatSafe = true,
    run = function()
        local prev = ns.db.sections.profile
        local snaps = prev and prev.snapshots or {}
        local snap = snapshot()
        snaps[#snaps + 1] = snap
        while #snaps > 10 do table.remove(snaps, 1) end
        ns.SaveSection("profile", { latest = snap, snapshots = snaps, counts = { snapshots = #snaps, addons = snap.counts.addons } })
        ns.Print(string.format("profile: snapshot of %d loaded addons (profiler %s, scriptProfile=%s); %d snapshot(s) kept",
            snap.counts.addons, tostring(snap.profiler.enabled or snap.profiler.unavailable), tostring(snap.scriptProfile), #snaps))
    end,
})
