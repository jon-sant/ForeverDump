-- ForeverDump v2 - protected: what can be safely determined about each global
-- and C_ function without calling it: issecurevariable (taint), presence, and
-- every restriction/secret flag the documentation carries.
local _, ns = ...

-- Standard doc keys; anything else on a function node is treated as a flag.
local STANDARD = { Name = true, Type = true, Arguments = true, Returns = true, Documentation = true,
                   _present = true }

local function flagsOf(f)
    local flags
    for k, v in pairs(f) do
        if type(k) == "string" and not STANDARD[k] and type(v) ~= "table" then
            flags = flags or {}
            flags[k] = v
        end
    end
    return flags
end

ns.RegisterSection({
    name = "protected",
    desc = "per function: secure (issecurevariable), present, documentation restriction/secret flags (run 'docs' first)",
    inAll = true,
    run = function()
        local docs = ForeverDumpDocsDB
        local functions, restricted, protectedFns, insecureBlizzard = {}, {}, {}, {}
        local haveDocs = type(docs) == "table" and type(docs.systems) == "table"
        if haveDocs then
            for _, sys in ipairs(docs.systems) do
                if sys.Type ~= "ScriptObject" and type(sys.Functions) == "table" then
                    for _, f in ipairs(sys.Functions) do
                        local full = sys.Namespace and (sys.Namespace .. "." .. f.Name) or f.Name
                        local flags = flagsOf(f)
                        local row = { present = f._present, flags = flags, system = sys.Name }
                        if flags then
                            if flags.IsProtectedFunction or flags.HasRestrictions then
                                restricted[#restricted + 1] = full
                            end
                            if flags.IsProtectedFunction then protectedFns[#protectedFns + 1] = full end
                        end
                        functions[full] = row
                    end
                end
                ns.Yield()
            end
        end
        -- taint state for every present function (global + C_ one level)
        local keys = ns.SnapshotGlobals()
        local nSecure, nInsecure = 0, 0
        for i, name in ipairs(keys) do
            local v = rawget(_G, name)
            if type(v) == "function" then
                local ok, secure = pcall(issecurevariable, name)
                secure = ok and secure or false
                local row = functions[name] or {}
                row.secure = secure
                row.present = true
                functions[name] = row
                if secure then nSecure = nSecure + 1 else nInsecure = nInsecure + 1 end
            elseif type(v) == "table" and string.sub(name, 1, 2) == "C_" then
                for k, fn in next, v do
                    if type(k) == "string" and type(fn) == "function" then
                        local full = name .. "." .. k
                        local ok, secure = pcall(issecurevariable, v, k)
                        secure = ok and secure or false
                        local row = functions[full] or {}
                        row.secure = secure
                        row.present = true
                        functions[full] = row
                        if not secure then insecureBlizzard[#insecureBlizzard + 1] = full end
                    end
                end
            end
            if i % 500 == 0 then ns.Yield() end
        end
        -- compact: plain secure+present functions without doc flags are implied by globals.functions.secure
        local omitted = 0
        if not ns.Full() then
            for name, row in pairs(functions) do
                if row.present and row.secure and not row.flags then
                    functions[name] = nil
                    omitted = omitted + 1
                end
            end
        end
        table.sort(restricted)
        table.sort(protectedFns)
        table.sort(insecureBlizzard)
        ns.SaveSection("protected", {
            functions = functions,
            restricted = restricted,          -- HasRestrictions or IsProtectedFunction in docs
            protectedFunctions = protectedFns, -- IsProtectedFunction in docs
            insecureNamespaceFunctions = insecureBlizzard, -- C_ members replaced/tainted by addons
            haveDocs = haveDocs,
            counts = { restricted = #restricted, protected = #protectedFns, secureGlobals = nSecure,
                       insecureGlobals = nInsecure, plainSecureOmitted = omitted },
        })
        ns.Print(string.format("protected: %d restricted, %d IsProtectedFunction (docs%s), %d secure / %d insecure globals",
            #restricted, #protectedFns, haveDocs and "" or " NOT loaded - run /fdump docs first", nSecure, nInsecure))
    end,
})
