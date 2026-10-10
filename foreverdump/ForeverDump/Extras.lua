-- ForeverDump v2 - extras: bindings, slash commands, settings, fonts, sound
-- kits, maps, classes/specs/races, spellbook, talents/traits, currencies.
-- Plus the opt-in `getters` sweep of documented zero-argument getters.
local _, ns = ...

local function try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local res = ns.Pack(pcall(fn, ...))
    if res[1] then return unpack(res, 2, res.n) end
end
local R = ns.Resolve

local function collectBindings()
    local out = {}
    local n = try(R("GetNumBindings")) or 0
    for i = 1, n do
        local r = ns.Pack(try(R("GetBinding"), i))
        out[#out + 1] = ns.Clean({ command = r[1], category = r[2], keys = { unpack(r, 3, r.n) } })
        if i % 200 == 0 then ns.Yield() end
    end
    return out
end

local function collectSlash()
    local commands = {}
    local function entry(key)
        commands[key] = commands[key] or { slashes = {} }
        return commands[key]
    end
    local list = rawget(_G, "SlashCmdList")
    if type(list) == "table" then
        for key, fn in next, list do
            if type(key) == "string" then
                local e = entry(key)
                e.inSlashCmdList = true
                local ok, secure = pcall(issecurevariable, list, key)
                e.secure = ok and secure or false
                e.callable = type(fn) == "function"
            end
        end
    end
    -- SLASH_<KEY><n> strings, including secure commands that are not in SlashCmdList
    for name, value in next, _G do
        if type(name) == "string" and type(value) == "string" then
            local key, idx = string.match(name, "^SLASH_(.-)(%d+)$")
            if key and key ~= "" then
                local e = entry(key)
                e.slashes[tonumber(idx)] = value
            end
        end
    end
    local hash = rawget(_G, "hash_SlashCmdList")
    local hashed = {}
    if type(hash) == "table" then
        for k in next, hash do if type(k) == "string" then hashed[#hashed + 1] = k end end
        table.sort(hashed)
    end
    local cmdTable = ns.Clean(rawget(_G, "SLASH_COMMAND"), { maxDepth = 2, maxKeys = 2000 })
    local categories = ns.Clean(rawget(_G, "SLASH_COMMAND_CATEGORY"), { maxDepth = 2 })
    -- convert slashes maps to arrays
    for _, e in pairs(commands) do
        local arr = {}
        for _, i in ipairs(ns.SortedKeys(e.slashes)) do arr[#arr + 1] = e.slashes[i] end
        e.slashes = arr
    end
    return { commands = commands, hashed = hashed, SLASH_COMMAND = cmdTable, SLASH_COMMAND_CATEGORY = categories }
end

local function collectSettings()
    local out = {}
    local panel = rawget(_G, "SettingsPanel")
    if type(panel) == "table" and type(panel.GetAllCategories) == "function" then
        local ok, cats = pcall(panel.GetAllCategories, panel)
        if ok and type(cats) == "table" then
            for _, cat in ipairs(cats) do
                local row = {}
                row.name = try(cat.GetName, cat)
                row.id = try(cat.GetID, cat)
                local parent = try(cat.GetParentCategory, cat)
                row.parent = parent and try(parent.GetName, parent) or nil
                out[#out + 1] = ns.Clean(row)
            end
        end
    end
    return out
end

local function collectFonts()
    local fonts = {}
    local names = try(R("GetFonts"))
    if type(names) == "table" then
        for _, name in ipairs(names) do
            local obj = rawget(_G, name)
            local row = { name = name }
            if type(obj) == "table" and type(obj.GetFont) == "function" then
                local path, size, flags = try(obj.GetFont, obj)
                row.file, row.size, row.flags = path, size, flags
            end
            fonts[#fonts + 1] = ns.Clean(row)
        end
    end
    return fonts
end

local function collectMaps()
    local out = { maps = {} }
    local CM = rawget(_G, "C_Map")
    if type(CM) ~= "table" then return out end
    out.bestMapForPlayer = try(CM.GetBestMapForUnit, "player")
    local roots = { 946, 947 } -- Cosmic, Azeroth
    local seen = {}
    for _, root in ipairs(roots) do
        local info = try(CM.GetMapInfo, root)
        if type(info) == "table" and not seen[root] then
            seen[root] = true
            out.maps[#out.maps + 1] = ns.Clean(info)
        end
        local children = try(CM.GetMapChildrenInfo, root, nil, true)
        if type(children) == "table" then
            for i, child in ipairs(children) do
                if type(child) == "table" and child.mapID and not seen[child.mapID] then
                    seen[child.mapID] = true
                    out.maps[#out.maps + 1] = ns.Clean(child)
                end
                if i % 200 == 0 then ns.Yield() end
            end
        end
    end
    out.instance = ns.SafeCall(R("GetInstanceInfo"))
    out.zone = { zoneText = try(R("GetZoneText")), subZone = try(R("GetSubZoneText")), realZone = try(R("GetRealZoneText")) }
    return ns.Clean(out, { maxDepth = 5, maxKeys = 20000 })
end

local function collectClasses()
    local out = { classes = {}, races = {}, specs = {} }
    local n = try(R("GetNumClasses")) or 0
    for i = 1, n do
        local r = ns.Pack(try(R("GetClassInfo"), i))
        out.classes[#out.classes + 1] = ns.Clean({ name = r[1], file = r[2], id = r[3] })
        local numSpecs = try(R("GetNumSpecializationsForClassID"), i) or try(R("C_SpecializationInfo.GetNumSpecializationsForClassID"), i) or 0
        for s = 1, numSpecs do
            local sp = ns.Pack(try(R("GetSpecializationInfoForClassID"), i, s))
            if sp.n > 0 then
                out.specs[#out.specs + 1] = ns.Clean({ classID = i, index = s, id = sp[1], name = sp[2],
                    description = sp[3], icon = sp[4], role = sp[5] })
            end
        end
    end
    local CI = rawget(_G, "C_CreatureInfo")
    if type(CI) == "table" then
        for id = 1, 100 do
            local info = try(CI.GetRaceInfo, id)
            if type(info) == "table" then out.races[#out.races + 1] = ns.Clean(info) end
        end
    end
    out.player = ns.Clean({
        class = { try(R("UnitClass"), "player") }, race = { try(R("UnitRace"), "player") },
        level = try(R("UnitLevel"), "player"), faction = { try(R("UnitFactionGroup"), "player") },
        spec = try(R("GetSpecialization")) or try(R("C_SpecializationInfo.GetSpecialization")),
    })
    return out
end

local function collectSpellbook()
    local out = { skillLines = {}, items = {} }
    local SB = rawget(_G, "C_SpellBook")
    if type(SB) ~= "table" then out.unavailable = true return out end
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local n = try(SB.GetNumSpellBookSkillLines) or 0
    for i = 1, n do
        local line = try(SB.GetSpellBookSkillLineInfo, i)
        if type(line) == "table" then
            out.skillLines[#out.skillLines + 1] = ns.Clean(line)
            local offset = line.itemIndexOffset or 0
            for j = offset + 1, offset + (line.numSpellBookItems or 0) do
                local item = try(SB.GetSpellBookItemInfo, j, bank)
                if type(item) == "table" then
                    item.slot = j
                    item.skillLine = i
                    out.items[#out.items + 1] = ns.Clean(item)
                end
                if j % 50 == 0 then ns.Yield() end
            end
        end
    end
    return out
end

local function collectTalents()
    local out = {}
    local CT, T = rawget(_G, "C_ClassTalents"), rawget(_G, "C_Traits")
    if type(CT) ~= "table" or type(T) ~= "table" then out.unavailable = true return out end
    local configID = try(CT.GetActiveConfigID)
    out.activeConfigID = configID
    if not configID then return out end
    local config = try(T.GetConfigInfo, configID)
    out.config = ns.Clean(config)
    out.trees = {}
    if type(config) == "table" and type(config.treeIDs) == "table" then
        for _, treeID in ipairs(config.treeIDs) do
            local tree = { treeID = treeID, nodes = {} }
            tree.info = ns.Clean(try(T.GetTreeInfo, configID, treeID))
            local nodes = try(T.GetTreeNodes, treeID)
            if type(nodes) == "table" then
                for i, nodeID in ipairs(nodes) do
                    local node = try(T.GetNodeInfo, configID, nodeID)
                    if type(node) == "table" then
                        local row = ns.Clean(node, { maxDepth = 3 })
                        row.entries = {}
                        for _, entryID in ipairs(node.entryIDs or {}) do
                            local entry = try(T.GetEntryInfo, configID, entryID)
                            local e = ns.Clean(entry) or {}
                            e.entryID = entryID
                            if type(entry) == "table" and entry.definitionID then
                                e.definition = ns.Clean(try(T.GetDefinitionInfo, entry.definitionID))
                            end
                            row.entries[#row.entries + 1] = e
                        end
                        tree.nodes[#tree.nodes + 1] = row
                    end
                    if i % 25 == 0 then ns.Yield() end
                end
            end
            out.trees[#out.trees + 1] = tree
        end
    end
    return out
end

local function collectCurrencies()
    local out = {}
    local CC = rawget(_G, "C_CurrencyInfo")
    if type(CC) ~= "table" then return out end
    local n = try(CC.GetCurrencyListSize) or 0
    for i = 1, n do
        local info = try(CC.GetCurrencyListInfo, i)
        if type(info) == "table" then
            local link = try(CC.GetCurrencyListLink, i)
            info.currencyID = link and tonumber(string.match(link, "currency:(%d+)")) or nil
            out[#out + 1] = ns.Clean(info)
        end
    end
    return out
end

ns.RegisterSection({
    name = "extras",
    desc = "keybindings, slash commands, settings categories, fonts, SOUNDKIT, maps, classes/specs/races, spellbook, talents, currencies",
    inAll = true,
    run = function()
        local data = {}
        local parts = {
            { "bindings", collectBindings }, { "slash", collectSlash }, { "settings", collectSettings },
            { "fonts", collectFonts }, { "maps", collectMaps }, { "classes", collectClasses },
            { "spellbook", collectSpellbook }, { "talents", collectTalents }, { "currencies", collectCurrencies },
        }
        data.errors = {}
        for _, part in ipairs(parts) do
            -- no pcall here (collectors may yield); each collector guards its own API calls
            data[part[1]] = part[2]()
            ns.Yield()
        end
        data.soundkit = ns.Clean(rawget(_G, "SOUNDKIT"), { maxDepth = 2, maxKeys = 20000 })
        data.professions = { try(R("GetProfessions")) }
        data.mountCount = try(R("C_MountJournal.GetNumMounts"))
        data.petCount = try(R("C_PetJournal.GetNumPets"))
        data.toyCount = try(R("C_ToyBox.GetNumToys"))
        ns.SaveSection("extras", ns.Clean(data, { maxDepth = 8, maxKeys = 50000 }))
        ns.Print("extras: bindings, slash commands, settings, fonts, sound kits, maps, classes, spellbook, talents, currencies")
    end,
})

----------------------------------------------------------------------------
-- getters (opt-in): call every documented zero-argument getter without
-- restriction flags in an allowlist of read-only prefixes. Out of combat only.
----------------------------------------------------------------------------
local GETTER_PREFIXES = { "Get", "Is", "Has", "Can", "Should", "Are", "Does" }
local DENY = {
    -- anything that opens UI, requests server data in bulk, or is known noisy
    ["C_AddOns.GetAddOnInfo"] = true,
}
local function isGetterName(name)
    for _, p in ipairs(GETTER_PREFIXES) do
        if string.sub(name, 1, #p) == p then return true end
    end
    return false
end

ns.RegisterSection({
    name = "getters",
    desc = "(opt-in) calls documented zero-arg Get*/Is*/Has*/Should* functions without restriction flags; records returns + secrecy",
    inAll = false,
    run = function()
        local docs = ForeverDumpDocsDB
        if type(docs) ~= "table" or type(docs.systems) ~= "table" then
            error("run /fdump docs first (getters uses the documentation to pick zero-argument functions)")
        end
        local results, n = {}, 0
        for _, sys in ipairs(docs.systems) do
            if sys.Type ~= "ScriptObject" and type(sys.Functions) == "table" then
                for _, f in ipairs(sys.Functions) do
                    local full = sys.Namespace and (sys.Namespace .. "." .. f.Name) or f.Name
                    local noArgs = (type(f.Arguments) ~= "table") or (#f.Arguments == 0)
                    local restricted = f.HasRestrictions or f.IsProtectedFunction
                    if noArgs and not restricted and f._present and isGetterName(f.Name) and not DENY[full] then
                        results[full] = ns.SafeCall(ns.Resolve(full))
                        n = n + 1
                        if n % 25 == 0 then ns.Yield() end
                    end
                end
            end
        end
        ns.SaveSection("getters", { results = results, counts = { called = n } })
        ns.Print("getters: called " .. n .. " documented zero-argument getters")
    end,
})
