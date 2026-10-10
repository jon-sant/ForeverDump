-- ForeverDump v2 - api, globals, strings sections.
local _, ns = ...
local type, next, rawget, pcall, tostring = type, next, rawget, pcall, tostring
local sub, find = string.sub, string.find

-- One-shot snapshot of _G's string keys (no yielding while traversing _G,
-- since other code may add globals between frames).
local function snapshotGlobals()
    local keys = {}
    for k in next, _G do
        if type(k) == "string" then keys[#keys + 1] = k end
    end
    table.sort(keys)
    return keys
end
ns.SnapshotGlobals = snapshotGlobals

local function isSecureGlobal(name)
    local ok, secure = pcall(issecurevariable, name)
    return ok and secure or false
end

local function isSecureField(tbl, key)
    local ok, secure = pcall(issecurevariable, tbl, key)
    return ok and secure or false
end

----------------------------------------------------------------------------
-- api: v1 `apis` list + structured C_ namespaces
----------------------------------------------------------------------------
local function surveyNamespace(tbl, depth)
    local out = { functions = {}, fields = {}, insecure = {} }
    for k, v in next, tbl do
        if type(k) == "string" then
            local vt = type(v)
            if vt == "function" then
                out.functions[#out.functions + 1] = k
                if not isSecureField(tbl, k) then out.insecure[#out.insecure + 1] = k end
            elseif vt == "table" and depth < 2 and not ns.IsFrame(v) then
                out.children = out.children or {}
                out.children[k] = surveyNamespace(v, depth + 1)
            elseif vt == "number" or vt == "boolean" or vt == "string" then
                out.fields[k] = ns.Clean(v, { maxString = 200 })
            else
                out.fields[k] = "<" .. vt .. ">"
            end
        end
    end
    table.sort(out.functions)
    table.sort(out.insecure)
    if #out.insecure == 0 then out.insecure = nil end
    if next(out.fields) == nil then out.fields = nil end
    return out
end

ns.RegisterSection({
    name = "api",
    desc = "v1 APIs list + every C_ namespace (functions, fields, insecure members)",
    inAll = true,
    run = function()
        local apis = ns.Legacy.CollectAPIs()
        ns.Legacy.Store({ apis = apis })
        ns.Yield()
        local keys = snapshotGlobals()
        local namespaces, nFunc = {}, 0
        for i, name in ipairs(keys) do
            if sub(name, 1, 2) == "C_" then
                local v = rawget(_G, name)
                if type(v) == "table" then
                    namespaces[name] = surveyNamespace(v, 0)
                    nFunc = nFunc + #namespaces[name].functions
                end
            end
            if i % 500 == 0 then ns.Yield() end
        end
        local n = 0
        for _ in next, namespaces do n = n + 1 end
        ns.SaveSection("api", { namespaces = namespaces, counts = { namespaces = n, functions = nFunc, apis = #apis } })
        ns.Print(string.format("api: %d namespaces, %d C_ functions, %d secure APIs (v1 list)", n, nFunc, #apis))
    end,
})

----------------------------------------------------------------------------
-- globals: namespace survey, functions secure/insecure, constants, env
----------------------------------------------------------------------------
local MAX_MEMBERS = 400

local function surveyTable(tbl, depth, seen, out)
    out = out or {}
    seen[tbl] = true
    local functions, fields, children = {}, {}, nil
    local n, numeric = 0, 0
    for k, v in next, tbl do
        n = n + 1
        if n > MAX_MEMBERS then out.truncated = true break end
        local kt, vt = type(k), type(v)
        if kt == "number" then
            numeric = numeric + 1
        elseif kt == "string" then
            if vt == "function" then
                functions[#functions + 1] = k
            elseif vt == "table" then
                if ns.IsFrame(v) then
                    fields[k] = "<frame>"
                elseif seen[v] then
                    fields[k] = "<seen>"
                elseif depth < (ns.Full() and 2 or 1) then
                    children = children or {}
                    children[k] = surveyTable(v, depth + 1, seen)
                else
                    fields[k] = "<table>"
                end
            elseif vt == "number" or vt == "boolean" then
                fields[k] = ns.Clean(v)
            elseif vt == "string" then
                fields[k] = ns.Clean(v, { maxString = 120 })
            else
                fields[k] = "<" .. vt .. ">"
            end
        end
    end
    table.sort(functions)
    if #functions > 0 then out.functions = functions end
    if next(fields) then out.fields = fields end
    if children then out.children = children end
    if numeric > 0 then out.arrayCount = numeric end
    out.count = n
    return out
end

local SKIP_TABLES = { APIDocumentation = "dumped by the docs section", _G = "self",
                      Enum = "see globals.enum", Constants = "see globals.constantsTable" }

local function classifyTable(name, tbl)
    if find(name, "Mixin$") then return "mixin" end
    if find(name, "Util$") or find(name, "Utils$") or find(name, "Util%u") then return "util" end
    local mt = getmetatable(tbl)
    if mt ~= nil then return "object" end
    return "table"
end

local LUA_EXTENSIONS = {
    "strsplit", "strjoin", "strtrim", "strconcat", "strsplittable", "strlenutf8", "strcmputf8i",
    "tostringall", "wipe", "tInvert", "tContains", "tDeleteItem", "tAppendAll", "CopyTable",
    "Mixin", "CreateFromMixins", "CreateAndInitFromMixin", "securecall", "securecallfunction",
    "secureexecuterange", "forceinsecure", "issecure", "issecurevariable", "hooksecurefunc",
    "issecretvalue", "issecrettable", "canaccessvalue", "canaccesssecrets", "canaccesstable",
    "hasanysecretvalues", "scrub", "scrubsecretvalues", "secretwrap", "dropsecretaccess",
    "debugstack", "debuglocals", "debugprofilestart", "debugprofilestop", "geterrorhandler",
    "seterrorhandler", "GetTime", "GetTimePreciseSec", "date", "time", "difftime", "gcinfo",
    "collectgarbage", "loadstring", "getfenv", "setfenv", "newproxy", "select", "unpack",
    "xpcall", "pcall", "error", "assert", "rawequal", "rawget", "rawset", "setmetatable",
    "getmetatable", "tonumber", "tostring", "type", "next", "ipairs", "pairs",
    "format", "gsub", "strbyte", "strchar", "strfind", "strlen", "strlower", "strmatch",
    "strrep", "strrev", "strsub", "strupper", "gmatch", "tinsert", "tremove", "sort", "foreach",
    "foreachi", "getn", "abs", "ceil", "floor", "max", "min", "mod", "random", "sqrt", "fastrandom",
    "bit", "C_Timer", "Enum", "Constants", "EventRegistry", "TooltipDataProcessor", "Menu",
    "SecureCmdOptionParse", "RunMacroText", "RegisterAttributeDriver", "RegisterStateDriver",
}

local STD_LIBS = { "string", "table", "math", "coroutine", "bit", "os", "io", "debug", "utf8", "jit", "package" }

local ENV_CALLS = {
    "GetBuildInfo", "GetLocale", "GetCurrentRegion", "GetCurrentRegionName", "GetExpansionLevel",
    "GetServerExpansionLevel", "GetClientDisplayExpansionLevel", "GetMaxLevelForPlayerExpansion",
    "GetMaxLevelForLatestExpansion", "GetAccountExpansionLevel", "IsPublicBuild", "IsTestBuild",
    "IsBetaBuild", "IsDebugBuild", "IsGMClient", "IsOnGlueScreen", "IsTrialAccount", "IsVeteranTrialAccount",
    "IsMacClient", "IsWindowsClient", "IsLinuxClient",
    "GetFramerate", "GetGameTime", "GetServerTime", "GetTimePreciseSec", "GetScreenWidth", "GetScreenHeight",
    "UnitFactionGroup", "C_GameRules.GetActiveGameMode",
    "C_AddOns.GetScriptsDisallowedForBeta", "AreDangerousScriptsAllowed", "C_CVar.GetCVar",
    "C_Secrets.HasSecretRestrictions", "C_Secrets.ShouldAurasBeSecret", "C_Secrets.ShouldCooldownsBeSecret",
    "ClassicExpansionAtLeast", "GetClassicExpansionLevel",
}

local function collectEnv()
    local env = { calls = {}, constants = {}, luaVersion = rawget(_G, "_VERSION") }
    for _, path in ipairs(ENV_CALLS) do
        if type(ns.Resolve(path)) == "function" then
            local argsFor = {
                ["UnitFactionGroup"] = { "player" }, ["C_CVar.GetCVar"] = { "portal" },
            }
            local args = argsFor[path] or {}
            env.calls[path] = ns.SafeCall(ns.Resolve(path), unpack(args))
        else
            env.calls[path] = { ok = false, err = "missing" }
        end
    end
    -- project / flavor constants
    for k, v in next, _G do
        if type(k) == "string" and (find(k, "^WOW_PROJECT_") or find(k, "^LE_EXPANSION_") or find(k, "^EXPANSION_LEVEL")) then
            if type(v) == "number" or type(v) == "string" or type(v) == "boolean" then env.constants[k] = ns.Clean(v) end
        end
    end
    env.stdlib = {}
    for _, lib in ipairs(STD_LIBS) do
        local t = rawget(_G, lib)
        if type(t) == "table" then
            local members = {}
            for k in next, t do if type(k) == "string" then members[#members + 1] = k end end
            table.sort(members)
            env.stdlib[lib] = members
        else
            env.stdlib[lib] = false
        end
    end
    env.extensions = {}
    for _, name in ipairs(LUA_EXTENSIONS) do
        local v = rawget(_G, name)
        env.extensions[name] = v == nil and false or type(v)
    end
    return env
end

ns.RegisterSection({
    name = "globals",
    desc = "non-C_ global tables (mixins, utils, registries), global functions secure/insecure, constants, Enum, env",
    inAll = true,
    run = function()
        local keys = snapshotGlobals()
        local tables, constants = {}, {}
        local secureFns, insecureFns, insecureTables = {}, {}, {}
        local typeCounts, frames = {}, 0
        local aliasOf = {}  -- table -> first global name surveyed
        for i, name in ipairs(keys) do
            local v = rawget(_G, name)
            local vt = type(v)
            typeCounts[vt] = (typeCounts[vt] or 0) + 1
            if vt == "function" then
                if isSecureGlobal(name) then secureFns[#secureFns + 1] = name else insecureFns[#insecureFns + 1] = name end
            elseif vt == "table" then
                if ns.IsFrame(v) then
                    frames = frames + 1
                elseif sub(name, 1, 2) ~= "C_" and name ~= "_G" then
                    local secureName = isSecureGlobal(name)
                    if SKIP_TABLES[name] or sub(name, 1, #ns.ADDON) == ns.ADDON then
                        -- our own SavedVariables / the docs table (dumped by the docs section)
                        tables[name] = { skipped = SKIP_TABLES[name] or "ForeverDump" }
                    elseif not secureName and not ns.Full() then
                        -- created by an addon: name + shape only. Addon tables (SavedVariables, databases) are
                        -- large and may hold character names / realm / personal data. /fdump set dump.full true
                        local n = 0
                        for _ in next, v do n = n + 1 if n >= 100000 then break end end
                        tables[name] = { kind = classifyTable(name, v), insecure = true, count = n }
                        insecureTables[#insecureTables + 1] = name
                    elseif aliasOf[v] then
                        tables[name] = { alias = aliasOf[v] }
                    else
                        aliasOf[v] = name
                        local ok, entry = pcall(surveyTable, v, 0, {}, nil)
                        if ok then
                            entry.kind = classifyTable(name, v)
                            if not isSecureGlobal(name) then
                                entry.insecure = true
                                insecureTables[#insecureTables + 1] = name
                            end
                            tables[name] = entry
                        else
                            tables[name] = { error = tostring(entry) }
                        end
                    end
                end
            elseif vt == "number" or vt == "boolean" then
                constants[name] = ns.Clean(v)
            end
            if i % 200 == 0 then
                ns.Progress("globals", i, #keys)
                ns.Yield()
            end
        end
        local enum = ns.Clean(rawget(_G, "Enum"), { maxDepth = 3, maxKeys = 5000 })
        ns.Yield()
        local constantsTable = ns.Clean(rawget(_G, "Constants"), { maxDepth = 4, maxKeys = 5000 })
        local env = collectEnv()
        local nTables = 0
        for _ in next, tables do nTables = nTables + 1 end
        local nConst = 0
        for _ in next, constants do nConst = nConst + 1 end
        ns.SaveSection("globals", {
            env = env,
            tables = tables,
            functions = { secure = secureFns, insecure = insecureFns },
            insecureTables = insecureTables,
            constants = constants,
            enum = enum,
            constantsTable = constantsTable,
            typeCounts = typeCounts,
            counts = { tables = nTables, secureFunctions = #secureFns, insecureFunctions = #insecureFns,
                       constants = nConst, frames = frames, globals = #keys },
        })
        ns.Print(string.format("globals: %d keys, %d tables, %d secure + %d insecure functions, %d constants, %d frames",
            #keys, nTables, #secureFns, #insecureFns, nConst, frames))
    end,
})

----------------------------------------------------------------------------
-- strings: every string global (GlobalStrings etc.) -> ForeverDumpStringsDB
----------------------------------------------------------------------------
ns.RegisterSection({
    name = "strings",
    desc = "all string globals (ITEM_LEVEL, SLASH_*, ...) into ForeverDumpStringsDB",
    inAll = true,
    run = function()
        local keys = snapshotGlobals()
        local strings, n = {}, 0
        for i, name in ipairs(keys) do
            local v = rawget(_G, name)
            if type(v) == "string" then
                if ns.Full() then
                    strings[name] = ns.Clean(v, { maxString = 8000 })
                else
                    strings[#strings + 1] = name -- compact: names only (values: Ketho GlobalStrings / GlobalStrings.db2)
                end
                n = n + 1
            end
            if i % 1000 == 0 then ns.Yield() end
        end
        if not ns.Full() then table.sort(strings) end
        ForeverDumpStringsDB = { schemaVersion = ns.SCHEMA, meta = ns.Meta(), count = n,
            strings = ns.Full() and strings or nil, names = (not ns.Full()) and strings or nil, compact = not ns.Full() or nil }
        if ns.Static then ns.Static.Put("strings", ForeverDumpStringsDB) end
        ns.SaveSection("strings", { count = n, storedIn = "ForeverDumpStringsDB" })
        ns.Print("strings: " .. n .. " global strings")
    end,
})
