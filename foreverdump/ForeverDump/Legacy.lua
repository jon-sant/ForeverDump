-- ForeverDump v2 - Legacy: the original v1 collectors, kept as-is so `/fdump`
-- (no arguments) and `/foreverdump` behave exactly like v1, and the v1
-- top-level SavedVariables keys (apis, events, enums, cvars, cvarNames,
-- commands, build, version, buildNumber, toc) keep their old shape.
local _, ns = ...
local L = {}
ns.Legacy = L

local CATEGORY_FALLBACK = {
    [0] = "Debug", [1] = "Graphics", [2] = "Console", [3] = "Combat", [4] = "Game",
    [5] = "Default", [6] = "Net", [7] = "Sound", [8] = "Gm", [9] = "Reveal", [10] = "None",
}

function L.CategoryName(id)
    if Enum and Enum.ConsoleCategory then
        for name, value in pairs(Enum.ConsoleCategory) do
            if value == id then return name end
        end
    end
    return CATEGORY_FALLBACK[id] or tostring(id)
end

function L.CollectAPIs()
    local list, seen = {}, {}
    local function add(name)
        if name and not seen[name] then
            seen[name] = true
            list[#list + 1] = name
        end
    end
    -- perf-ok: dump-only job (chunked runner, out of combat)
    for name, value in pairs(_G) do
        if type(name) == "string" then
            if type(value) == "function" then
                if issecurevariable(name) then add(name) end
            elseif string.sub(name, 1, 2) == "C_" and type(value) == "table" then
                for k, v in pairs(value) do
                    if type(k) == "string" and type(v) == "function" then add(name .. "." .. k) end
                end
            end
        end
    end
    table.sort(list)
    return list
end

function L.LoadDocs()
    local loader = C_AddOns and C_AddOns.LoadAddOn or rawget(_G, "LoadAddOn")
    local errs = {}
    if loader then
        for _, name in ipairs({ "Blizzard_APIDocumentation", "Blizzard_APIDocumentationGenerated" }) do
            local ok, loaded, reason = pcall(loader, name)
            if not ok then errs[#errs + 1] = name .. ": " .. tostring(loaded)
            elseif loaded == false then errs[#errs + 1] = name .. ": " .. tostring(reason) end
        end
    end
    local docs = rawget(_G, "APIDocumentation")
    if type(docs) == "table" and type(docs.systems) == "table" and #docs.systems > 0 then return docs end
    return nil, table.concat(errs, "; ")
end

function L.CollectEvents()
    local docs = L.LoadDocs()
    local list, seen = {}, {}
    if not docs then return list end
    local isValid = C_EventUtils and C_EventUtils.IsEventValid
    for i = 1, #docs.systems do
        local events = docs.systems[i] and docs.systems[i].Events
        if type(events) == "table" then
            for j = 1, #events do
                local ev = events[j]
                local name = ev and (ev.LiteralName or ev.Name)
                if name and not seen[name] and (not isValid or isValid(name)) then
                    seen[name] = true
                    list[#list + 1] = name
                end
            end
        end
    end
    table.sort(list)
    return list
end

local function Flatten(prefix, tbl, out)
    if type(tbl) ~= "table" then return end
    for _, k in ipairs(ns.SortedKeys(tbl)) do
        local v = tbl[k]
        local path = prefix .. "." .. tostring(k)
        if type(v) == "table" then
            Flatten(path, v, out)
        else
            out[#out + 1] = path .. " = " .. tostring(v)
        end
    end
end

function L.CollectEnums()
    local out = {}
    Flatten("Enum", rawget(_G, "Enum"), out)
    Flatten("Constants", rawget(_G, "Constants"), out)
    return out
end

-- v2.2.21: identity CVars (account/realm/character/guid/battletag/...) are stored raw. Only credential-type CVars
-- (password / auth token / login ticket) stay redacted - they are credentials, not identity data.
local SENSITIVE = { "password", "authtoken", "logintoken", "ticket" }
function ns.IsSensitiveCVar(name)
    local lower = string.lower(tostring(name))
    for _, s in ipairs(SENSITIVE) do
        if string.find(lower, s, 1, true) then return true end
    end
    return false
end

function L.GetCVarBundle(name)
    local current, default, account, character, locked, secure, readonly
    if C_CVar and C_CVar.GetCVarInfo then
        current, default, account, character, locked, secure, readonly = C_CVar.GetCVarInfo(name)
    elseif rawget(_G, "GetCVarInfo") then
        current, default, account, character, locked, secure, readonly = GetCVarInfo(name)
    end
    if current == nil and rawget(_G, "GetCVar") then current = GetCVar(name) end
    if default == nil and rawget(_G, "GetCVarDefault") then default = GetCVarDefault(name) end
    if ns.IsSensitiveCVar(name) then
        current = (current ~= nil) and "<redacted>" or nil
    end
    return {
        current = ns.Clean(current), default = ns.Clean(default), account = account,
        character = character, locked = locked, secure = secure, readonly = readonly,
    }
end

-- Returns nested[category][name] = row, flat list of CVar names, other commands.
-- `yield` is optional (called between entries when run from a job).
function L.CollectCVars(yield)
    local nested, flat, commands = {}, {}, {}
    if type(rawget(_G, "ConsoleGetAllCommands")) ~= "function" then return nested, flat, commands end
    local ok, all = pcall(ConsoleGetAllCommands)
    if not ok or type(all) ~= "table" then return nested, flat, commands end
    local cvarType = Enum and Enum.ConsoleCommandType and Enum.ConsoleCommandType.Cvar or 0
    for i = 1, #all do
        local info = all[i]
        if type(info) == "table" and info.command then
            if info.commandType == cvarType then
                local cat = L.CategoryName(info.category)
                local okRow, row = pcall(L.GetCVarBundle, info.command)
                if not okRow then row = { error = tostring(row) } end
                row.help = info.help
                row.category = cat
                row.categoryId = info.category
                nested[cat] = nested[cat] or {}
                nested[cat][info.command] = row
                flat[#flat + 1] = info.command
            else
                commands[#commands + 1] = {
                    name = info.command,
                    help = info.help,
                    category = L.CategoryName(info.category),
                    commandType = info.commandType,
                    scriptContents = info.scriptContents,
                    scriptParameters = info.scriptParameters,
                }
            end
        end
        if yield then yield() end
    end
    table.sort(flat)
    table.sort(commands, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return nested, flat, commands
end

function L.CVarText(nested)
    local lines = { "==== CVARS ====" }
    for _, cat in ipairs(ns.SortedKeys(nested)) do
        lines[#lines + 1] = ""
        lines[#lines + 1] = "[" .. cat .. "]"
        for _, name in ipairs(ns.SortedKeys(nested[cat])) do
            local c = nested[cat][name]
            lines[#lines + 1] = string.format(
                "%s\tcurrent=%s\tdefault=%s\taccount=%s\tcharacter=%s\tlocked=%s\tsecure=%s\treadonly=%s\t%s",
                name, tostring(c.current), tostring(c.default), tostring(c.account),
                tostring(c.character), tostring(c.locked), tostring(c.secure), tostring(c.readonly),
                (string.gsub(c.help or "", "[%c]", " ")))
        end
    end
    return table.concat(lines, "\n")
end

-- Writes the v1 keys. Unlike v1 it no longer wipes the rest of ForeverDumpDB.
-- v2.2.7: the v1 keys are static client data -> ForeverDumpStaticDB.v1 (ns.db reads fall back to it)
function L.Store(fields)
    if ns.Static then ns.Static.StoreV1(fields) return end
    local db = ns.db
    for k, v in pairs(fields) do db[k] = v end
end

-- v1 `/fdump`: quick dump of APIs, events, enums, CVars, then show the CVars view.
function L.Dump()
    if ns.InCombat() then
        ns.Print("|cffff5555refusing to dump in combat.|r Leave combat and try again.")
        return
    end
    local apis = L.CollectAPIs()
    local events = L.CollectEvents()
    local enums = L.CollectEnums()
    local nested, flat, commands = L.CollectCVars()
    local version, build, _, toc = GetBuildInfo()
    local header = string.format(
        "-- ForeverDump %s %s toc %s | %s | %d APIs, %d events, %d enums, %d CVars",
        tostring(version), tostring(build), tostring(toc), date("%Y-%m-%d %H:%M:%S"),
        #apis, #events, #enums, #flat)

    ns.legacyView = { header = header, apis = apis, events = events, enums = enums, cvarsNested = nested }
    L.Store({
        build = header, version = version, buildNumber = build, toc = toc,
        apis = apis, events = events, enums = enums, cvars = nested, cvarNames = flat, commands = commands,
    })

    ns.Print(header)
    ns.Print("written to SavedVariables. Logout to character select (or /reload) to flush the file.")
    ns.Print("then copy:  WTF\\Account\\<account>\\SavedVariables\\ForeverDump.lua")
    ns.Print("v2: type |cffffff00/fdump help|r for the full dump sections.")
    if ns.UI then ns.UI.Show("cvars") end
end
