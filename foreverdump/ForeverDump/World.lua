-- ForeverDump v2 - templates, frames, addons sections.
local _, ns = ...

----------------------------------------------------------------------------
-- templates: C_XMLUtil.GetTemplates + GetTemplateInfo
----------------------------------------------------------------------------
ns.RegisterSection({
    name = "templates",
    desc = "XML templates via C_XMLUtil (name, type, size, inherits, keyValues, sourceLocation)",
    inAll = true,
    run = function()
        local X = rawget(_G, "C_XMLUtil")
        if type(X) ~= "table" or type(X.GetTemplates) ~= "function" then
            ns.SaveSection("templates", { unavailable = "C_XMLUtil.GetTemplates missing" })
            ns.Print("templates: C_XMLUtil.GetTemplates not available")
            return
        end
        local ok, list = pcall(X.GetTemplates)
        if not ok or type(list) ~= "table" then error("C_XMLUtil.GetTemplates failed: " .. tostring(list)) end
        local templates, secure = {}, {}
        for i = 1, #list do
            local entry = list[i]
            local name = type(entry) == "table" and entry.name or entry
            if type(name) == "string" then
                local row = { type = type(entry) == "table" and entry.type or nil }
                if type(X.GetTemplateInfo) == "function" then
                    local okInfo, info = pcall(X.GetTemplateInfo, name)
                    if okInfo and type(info) == "table" then
                        row.info = ns.Clean(info, { maxDepth = 4, maxKeys = 200, maxString = 500 })
                    end
                end
                templates[name] = row
                if string.find(name, "Secure") then secure[#secure + 1] = name end
            end
            if i % 100 == 0 then
                ns.Progress("templates", i, #list)
                ns.Yield()
            end
        end
        table.sort(secure)
        ns.SaveSection("templates", { templates = templates, secureTemplates = secure, counts = { templates = #list } })
        ns.Print("templates: " .. #list .. " (" .. #secure .. " with 'Secure' in the name)")
    end,
})

----------------------------------------------------------------------------
-- frames: named global frames
----------------------------------------------------------------------------
local REGION_TYPES = { Texture = true, FontString = true, Line = true, MaskTexture = true, ModelSceneActor = true }

local function frameInfo(f)
    local row = {}
    local okF, forbidden = pcall(f.IsForbidden, f)
    if okF and forbidden then
        row.forbidden = true
        return row -- methods on forbidden frames error; record only the flag
    end
    local function try(method, ...)
        local fn = f[method]
        if type(fn) ~= "function" then return nil end
        local ok, a, b = pcall(fn, f, ...)
        if ok then return a, b end
    end
    row.objectType = try("GetObjectType")
    local isProtected, explicit = try("IsProtected")
    row.protected = isProtected or nil
    row.explicitProtected = explicit or nil
    local parent = try("GetParent")
    if parent then
        local okN, pname = pcall(parent.GetName, parent)
        row.parent = okN and pname or "<anonymous>"
    end
    if not ns.Full() then return ns.Clean(row) end -- compact: type, parent, protection only
    row.shown = try("IsShown")
    row.visible = try("IsVisible")
    local w, h = try("GetSize")
    if type(w) == "number" then row.width = ns.CleanNumber(w); row.height = ns.CleanNumber(h) end
    row.strata = try("GetFrameStrata")
    row.level = try("GetFrameLevel")
    return ns.Clean(row)
end

ns.RegisterSection({
    name = "frames",
    desc = "named global frames: object type, parent, protected/forbidden, shown, size, strata",
    inAll = true,
    run = function()
        local keys = ns.SnapshotGlobals()
        local frames, byType, n, skippedRegions = {}, {}, 0, 0
        for i, name in ipairs(keys) do
            local v = rawget(_G, name)
            if ns.IsFrame(v) then
                local ok, row = pcall(frameInfo, v)
                n = n + 1
                local t = ok and row.objectType or "?"
                byType[t] = (byType[t] or 0) + 1
                -- compact: regions (Texture, FontString, Line, MaskTexture...) are only counted; on the 70245 client
                -- they were ~70% of 13.7k named objects (3.1 MB). /fdump set dump.full true keeps them.
                if ns.Full() or not REGION_TYPES[t] then
                    frames[name] = ok and row or { error = tostring(row) }
                else
                    skippedRegions = skippedRegions + 1
                end
            end
            if i % 300 == 0 then
                ns.Progress("frames", i, #keys)
                ns.Yield()
            end
        end
        -- anonymous frame count via EnumerateFrames (cheap walk)
        local total = 0
        if type(EnumerateFrames) == "function" then
            local f = EnumerateFrames()
            while f do
                total = total + 1
                if total % 2000 == 0 then ns.Yield() end
                f = EnumerateFrames(f)
            end
        end
        ns.SaveSection("frames", { frames = frames, byType = byType,
            counts = { named = n, enumerated = total, regionsNotListed = skippedRegions } })
        ns.Print(string.format("frames: %d named, %d total via EnumerateFrames", n, total))
    end,
})

----------------------------------------------------------------------------
-- addons: C_AddOns for user addons + probing of Blizzard addon names
----------------------------------------------------------------------------
local function A(name) return C_AddOns and C_AddOns[name] or rawget(_G, name) end

local function addonRow(idOrName)
    local row = {}
    local info = ns.Pack(pcall(A("GetAddOnInfo"), idOrName))
    if info[1] then
        row.name, row.title, row.notes, row.loadable, row.reason, row.security, row.updateAvailable =
            info[2], info[3], info[4], info[5], info[6], info[7], info[8]
    else
        row.error = tostring(info[2])
        return ns.Clean(row)
    end
    local name = row.name or idOrName
    local function call(fn, ...)
        local f = A(fn)
        if type(f) ~= "function" then return nil end
        local res = ns.Pack(pcall(f, ...))
        if res[1] then return res end
    end
    local lod = call("IsAddOnLoadOnDemand", name)
    row.loadOnDemand = lod and lod[2] or nil
    local loaded = call("IsAddOnLoaded", name)
    if loaded then row.loadedOrLoading, row.loaded = loaded[2], loaded[3] end
    local deps = call("GetAddOnDependencies", name)
    if deps and deps.n > 1 then row.deps = { unpack(deps, 2, deps.n) } end
    local opt = call("GetAddOnOptionalDependencies", name)
    if opt and opt.n > 1 then row.optionalDeps = { unpack(opt, 2, opt.n) } end
    local state = call("GetAddOnEnableState", name)
    row.enableState = state and state[2] or nil
    row.metadata = {}
    for _, field in ipairs({ "Version", "Author", "Interface", "X-Website", "Category", "Group", "AllowLoad",
                             "AllowLoadGameType", "LoadWith", "LoadManagers", "SavedVariables",
                             "SavedVariablesPerCharacter", "IconTexture", "IconAtlas" }) do
        local m = call("GetAddOnMetadata", name, field)
        if m and m[2] ~= nil then row.metadata[field] = m[2] end
    end
    return ns.Clean(row, { maxString = 500 })
end

ns.RegisterSection({
    name = "addons",
    desc = "all addons via C_AddOns (title, loadable, reason, on-demand, deps, metadata) + Blizzard addon probe",
    inAll = true,
    run = function()
        local numFn = A("GetNumAddOns")
        local user, blizzard = {}, {}
        local n = (type(numFn) == "function") and select(2, pcall(numFn)) or 0
        if type(n) ~= "number" then n = 0 end
        for i = 1, n do
            user[#user + 1] = addonRow(i)
            ns.Yield()
        end
        for i, name in ipairs(ns.BLIZZARD_ADDONS or {}) do
            local row = addonRow(name)
            if not row.error then blizzard[name] = row end
            if i % 20 == 0 then ns.Yield() end
        end
        ns.SaveSection("addons", {
            addons = user,
            blizzard = blizzard,
            loadedThisSession = ns.loadedAddOns,
            scriptsDisallowedForBeta = ns.ScriptsDisallowed(),
            counts = { addons = n, blizzardProbed = #(ns.BLIZZARD_ADDONS or {}) },
        })
        ns.Print(string.format("addons: %d user addons, %d Blizzard addons probed, %d ADDON_LOADED seen this session",
            n, #(ns.BLIZZARD_ADDONS or {}), #ns.loadedAddOns))
    end,
})
