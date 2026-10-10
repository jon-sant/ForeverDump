-- ForeverDump v2 - docs: full Blizzard_APIDocumentation walk.
-- Copies every documentation node generically (all scalar fields + nested
-- tables), so new flags such as SecretArguments, HasRestrictions,
-- IsProtectedFunction, SecretWhen*, Requires* are captured without being
-- hardcoded. Writes ForeverDumpDocsDB.
local _, ns = ...

-- Back-references Blizzard adds when it registers docs (would form cycles).
local SKIP_KEYS = { System = true, Function = true, Event = true, Table = true, Parent = true }

local function copyNode(node, depth, path)
    if depth > 6 then return "<depth>" end
    local out = {}
    path[node] = true
    for k, v in next, node do
        local kt, vt = type(k), type(v)
        if (kt == "string" or kt == "number") and not SKIP_KEYS[k] then
            if vt == "table" then
                if not path[v] and not ns.IsFrame(v) then
                    out[k] = copyNode(v, depth + 1, path)
                end
            elseif vt == "string" then
                out[k] = (#v > 2000) and (string.sub(v, 1, 2000) .. "<...>") or v
            elseif vt == "number" then
                out[k] = ns.CleanNumber(v)
            elseif vt == "boolean" then
                out[k] = v
            end -- functions (mixin methods) and userdata are skipped
        end
    end
    path[node] = nil
    return out
end
ns.CopyDocNode = function(node) return copyNode(node, 0, {}) end

local function isPresent(namespace, name)
    if namespace and namespace ~= "" then
        local t = rawget(_G, namespace)
        return type(t) == "table" and type(rawget(t, name)) == "function"
    end
    return type(rawget(_G, name)) == "function"
end

ns.RegisterSection({
    name = "docs",
    desc = "full APIDocumentation walk (functions, events, tables, flags) + documented/present cross-check",
    inAll = true,
    run = function()
        local docs, loadErr = ns.Legacy.LoadDocs()
        if not docs then
            error("Blizzard_APIDocumentation could not be loaded or has no systems (" .. tostring(loadErr) .. ")")
        end
        local isValid = C_EventUtils and C_EventUtils.IsEventValid
        local out = {
            schemaVersion = ns.SCHEMA,
            meta = ns.Meta(),
            systems = {},
            sharedTables = {},   -- documentation tables registered without a system
            missing = {},        -- documented functions not present in this client
            undocumented = {},   -- present C_ functions without documentation
            undocumentedGlobals = {}, -- secure global functions without documentation
            invalidEvents = {},  -- documented events C_EventUtils.IsEventValid rejects
            counts = {},
        }
        local documented = {}      -- "Ns.Func" / "Func" -> true
        local nFunc, nEvent, nTable = 0, 0, 0
        local systems = docs.systems
        for i = 1, #systems do
            local sys = systems[i]
            local copy = copyNode(sys, 0, {})
            local namespace = sys.Namespace
            local isScriptObject = sys.Type == "ScriptObject"
            if type(copy.Functions) == "table" then
                for _, f in ipairs(copy.Functions) do
                    nFunc = nFunc + 1
                    if not isScriptObject and f.Name then
                        local full = namespace and (namespace .. "." .. f.Name) or f.Name
                        documented[full] = true
                        local present = isPresent(namespace, f.Name)
                        f._present = present
                        if not present then out.missing[#out.missing + 1] = full end
                    end
                end
            end
            if type(copy.Events) == "table" then
                for _, e in ipairs(copy.Events) do
                    nEvent = nEvent + 1
                    if isValid and e.LiteralName then
                        local ok, valid = pcall(isValid, e.LiteralName)
                        e._valid = ok and valid or false
                        if not e._valid then out.invalidEvents[#out.invalidEvents + 1] = e.LiteralName end
                    end
                end
            end
            if type(copy.Tables) == "table" then nTable = nTable + #copy.Tables end
            out.systems[#out.systems + 1] = copy
            ns.Progress("docs systems", i, #systems)
            ns.Yield()
        end

        -- tables registered without a system (shared structures/enums)
        if type(docs.tables) == "table" then
            for _, t in ipairs(docs.tables) do
                if type(t) == "table" and t.System == nil then
                    out.sharedTables[#out.sharedTables + 1] = copyNode(t, 0, {})
                    nTable = nTable + 1
                end
                ns.Yield()
            end
        end

        -- present but undocumented
        -- perf-ok: dump-only job (chunked runner, out of combat)
        for name, value in pairs(_G) do
            if type(name) == "string" and string.sub(name, 1, 2) == "C_" and type(value) == "table" then
                for k, v in next, value do
                    if type(k) == "string" and type(v) == "function" and not documented[name .. "." .. k] then
                        out.undocumented[#out.undocumented + 1] = name .. "." .. k
                    end
                end
            end
        end
        ns.Yield()
        -- perf-ok: dump-only job (chunked runner, out of combat)
        for name, value in pairs(_G) do
            if type(name) == "string" and type(value) == "function" and not documented[name] then
                local ok, secure = pcall(issecurevariable, name)
                if ok and secure then out.undocumentedGlobals[#out.undocumentedGlobals + 1] = name end
            end
        end
        table.sort(out.missing)
        table.sort(out.undocumented)
        table.sort(out.undocumentedGlobals)
        table.sort(out.invalidEvents)
        out.counts = {
            systems = #out.systems, functions = nFunc, events = nEvent, tables = nTable,
            missing = #out.missing, undocumented = #out.undocumented,
            undocumentedGlobals = #out.undocumentedGlobals, sharedTables = #out.sharedTables,
        }
        ForeverDumpDocsDB = out
        if ns.Static then ns.Static.Put("docs", out) end
        ns.docsIndex = documented
        ns.SaveSection("docs", { counts = out.counts, storedIn = "ForeverDumpDocsDB" })
        ns.Print(string.format("docs: %d systems, %d functions (%d missing in client), %d events, %d tables, %d undocumented C_ functions",
            out.counts.systems, nFunc, #out.missing, nEvent, nTable, #out.undocumented))
    end,
})
