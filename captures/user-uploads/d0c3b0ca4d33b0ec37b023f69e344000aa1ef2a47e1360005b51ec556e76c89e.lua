ForeverDumpDB = ForeverDumpDB or {}

local CATEGORY_FALLBACK = {
    [0] = "Debug",
    [1] = "Graphics",
    [2] = "Console",
    [3] = "Combat",
    [4] = "Game",
    [5] = "Default",
    [6] = "Net",
    [7] = "Sound",
    [8] = "Gm",
    [9] = "Reveal",
    [10] = "None",
}

local function CategoryName(id)
    if Enum and Enum.ConsoleCategory then
        for name, value in pairs(Enum.ConsoleCategory) do
            if value == id then
                return name
            end
        end
    end
    return CATEGORY_FALLBACK[id] or tostring(id)
end

local function SortedKeys(t)
    local keys = {}
    for k in pairs(t) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
    return keys
end

local function CollectAPIs()
    local list, seen = {}, {}
    local function add(name)
        if name and not seen[name] then
            seen[name] = true
            list[#list + 1] = name
        end
    end
    for name, value in pairs(_G) do
        if type(name) == "string" then
            if type(value) == "function" then
                if issecurevariable(name) then
                    add(name)
                end
            elseif string.sub(name, 1, 2) == "C_" and type(value) == "table" then
                for k, v in pairs(value) do
                    if type(k) == "string" and type(v) == "function" then
                        add(name .. "." .. k)
                    end
                end
            end
        end
    end
    table.sort(list)
    return list
end

local function CollectEvents()
    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_APIDocumentation")
        pcall(C_AddOns.LoadAddOn, "Blizzard_APIDocumentationGenerated")
    end
    local docs = _G.APIDocumentation
    local list, seen = {}, {}
    if type(docs) ~= "table" or type(docs.systems) ~= "table" then
        return list
    end
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
    if type(tbl) ~= "table" then
        return
    end
    for _, k in ipairs(SortedKeys(tbl)) do
        local v = tbl[k]
        local path = prefix .. "." .. tostring(k)
        if type(v) == "table" then
            Flatten(path, v, out)
        else
            out[#out + 1] = path .. " = " .. tostring(v)
        end
    end
end

local function CollectEnums()
    local out = {}
    Flatten("Enum", _G.Enum, out)
    Flatten("Constants", _G.Constants, out)
    return out
end

local function GetCVarBundle(name)
    local current, default, account, character, locked, secure, readonly
    if C_CVar and C_CVar.GetCVarInfo then
        current, default, account, character, locked, secure, readonly = C_CVar.GetCVarInfo(name)
    elseif GetCVarInfo then
        current, default, account, character, locked, secure, readonly = GetCVarInfo(name)
    end
    if current == nil and GetCVar then
        current = GetCVar(name)
    end
    if default == nil and GetCVarDefault then
        default = GetCVarDefault(name)
    end
    return {
        current = current,
        default = default,
        account = account,
        character = character,
        locked = locked,
        secure = secure,
        readonly = readonly,
    }
end

local function CollectCVars()
    local nested, flat, commands = {}, {}, {}
    if type(ConsoleGetAllCommands) ~= "function" then
        return nested, flat, commands
    end
    local ok, all = pcall(ConsoleGetAllCommands)
    if not ok or type(all) ~= "table" then
        return nested, flat, commands
    end
    local cvarType = Enum and Enum.ConsoleCommandType and Enum.ConsoleCommandType.Cvar or 0
    for i = 1, #all do
        local info = all[i]
        if type(info) == "table" and info.command then
            if info.commandType == cvarType then
                local cat = CategoryName(info.category)
                local row = GetCVarBundle(info.command)
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
                    category = CategoryName(info.category),
                    commandType = info.commandType,
                    scriptContents = info.scriptContents,
                    scriptParameters = info.scriptParameters,
                }
            end
        end
    end
    table.sort(flat)
    table.sort(commands, function(a, b) return a.name < b.name end)
    return nested, flat, commands
end

local function CVarText(nested)
    local lines = { "==== CVARS ====" }
    for _, cat in ipairs(SortedKeys(nested)) do
        lines[#lines + 1] = ""
        lines[#lines + 1] = "[" .. cat .. "]"
        for _, name in ipairs(SortedKeys(nested[cat])) do
            local c = nested[cat][name]
            lines[#lines + 1] = string.format(
                "%s\tcurrent=%s\tdefault=%s\taccount=%s\tcharacter=%s\tlocked=%s\tsecure=%s\treadonly=%s\t%s",
                name,
                tostring(c.current),
                tostring(c.default),
                tostring(c.account),
                tostring(c.character),
                tostring(c.locked),
                tostring(c.secure),
                tostring(c.readonly),
                string.gsub(c.help or "", "[%c]", " ")
            )
        end
    end
    return table.concat(lines, "\n")
end

local data, frame, edit

local function Show(kind)
    if not data then
        return
    end
    local text
    if kind == "apis" then
        text = "==== APIS ====\n" .. table.concat(data.apis, "\n")
    elseif kind == "events" then
        text = "==== EVENTS ====\n" .. table.concat(data.events, "\n")
    elseif kind == "enums" then
        text = "==== ENUMS ====\n" .. table.concat(data.enums, "\n")
    elseif kind == "cvars" then
        text = CVarText(data.cvarsNested)
    else
        text = table.concat({
            data.header,
            "==== APIS ====\n" .. table.concat(data.apis, "\n"),
            "==== EVENTS ====\n" .. table.concat(data.events, "\n"),
            "==== ENUMS ====\n" .. table.concat(data.enums, "\n"),
            CVarText(data.cvarsNested),
        }, "\n\n")
    end
    edit:SetText(text)
    edit:HighlightText()
    edit:SetFocus()
    frame.TitleText:SetText("ForeverDump — " .. kind .. "  (Ctrl+C)")
    frame:Show()
end

local function EnsureUI()
    if frame then
        return
    end
    frame = CreateFrame("Frame", "ForeverDumpFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(860, 580)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    table.insert(UISpecialFrames, "ForeverDumpFrame")

    local function Btn(label, x, kind)
        local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        b:SetSize(80, 22)
        b:SetPoint("TOPLEFT", 12 + x, -32)
        b:SetText(label)
        b:SetScript("OnClick", function() Show(kind) end)
    end
    Btn("APIs", 0, "apis")
    Btn("Events", 86, "events")
    Btn("Enums", 172, "enums")
    Btn("CVars", 258, "cvars")
    Btn("All", 344, "all")

    local selectAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    selectAll:SetSize(90, 22)
    selectAll:SetPoint("TOPRIGHT", -12, -32)
    selectAll:SetText("Select all")
    selectAll:SetScript("OnClick", function()
        edit:SetFocus()
        edit:HighlightText()
    end)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -62)
    scroll:SetPoint("BOTTOMRIGHT", -34, 16)

    edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetFontObject(GameFontHighlightSmall)
    edit:SetWidth(790)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(0)
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        frame:Hide()
    end)
    scroll:SetScrollChild(edit)
end

local function Dump()
    local apis = CollectAPIs()
    local events = CollectEvents()
    local enums = CollectEnums()
    local nested, flat, commands = CollectCVars()
    local version, build, _, toc = GetBuildInfo()
    local header = string.format(
        "-- ForeverDump %s %s toc %s | %s | %d APIs, %d events, %d enums, %d CVars",
        tostring(version), tostring(build), tostring(toc),
        date("%Y-%m-%d %H:%M:%S"),
        #apis, #events, #enums, #flat
    )

    data = {
        header = header,
        apis = apis,
        events = events,
        enums = enums,
        cvarsNested = nested,
    }

    ForeverDumpDB = {
        build = header,
        version = version,
        buildNumber = build,
        toc = toc,
        apis = apis,
        events = events,
        enums = enums,
        cvars = nested,
        cvarNames = flat,
        commands = commands,
    }

    print("|cff33ff99ForeverDump|r " .. header)
    print("|cff33ff99ForeverDump|r written to SavedVariables. Logout to character select to flush the file.")
    print("|cff33ff99ForeverDump|r then copy:")
    print("  WTF\\Account\\<account>\\SavedVariables\\ForeverDump.lua")

    EnsureUI()
    Show("cvars")
end

SLASH_FOREVERDUMP1 = "/fdump"
SLASH_FOREVERDUMP2 = "/foreverdump"
SlashCmdList.FOREVERDUMP = Dump