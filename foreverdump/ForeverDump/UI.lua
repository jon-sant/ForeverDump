-- ForeverDump v2 - copy UI (v1 window kept; text is capped so the EditBox never freezes the client).
local _, ns = ...
local UI = {}
ns.UI = UI

local frame, edit

local function cap(text)
    local max = ns.config and ns.config.uiMaxChars or 120000
    if #text > max then
        return ns.Utf8Cut(text, max) .. "\n\n-- [ForeverDump] view truncated at " .. max ..
            " characters; the full data is in SavedVariables (ForeverDump.lua)."
    end
    return text
end

local function legacyData()
    local db = ns.db or {}
    local v = ns.legacyView or {}
    return {
        header = v.header or db.build or "-- ForeverDump (run /fdump or /fdump api to collect)",
        apis = v.apis or db.apis or {},
        events = v.events or db.events or {},
        enums = v.enums or db.enums or {},
        cvarsNested = v.cvarsNested or db.cvars or {},
    }
end

local function statusText()
    local lines = { "==== FOREVERDUMP STATUS ====", "addon " .. ns.VERSION .. ", schema " .. ns.SCHEMA }
    local m = ns.Meta()
    lines[#lines + 1] = string.format("client %s build %s toc %s locale %s", tostring(m.version), tostring(m.build),
        tostring(m.toc), tostring(m.locale))
    lines[#lines + 1] = string.format("WOW_PROJECT_ID %s (%s)", tostring(m.projectID), tostring(m.projectName or "no WOW_PROJECT_* match"))
    local pc = {}
    for k, v in pairs(m.projectConstants or {}) do pc[#pc + 1] = k .. "=" .. tostring(v) end
    table.sort(pc)
    lines[#lines + 1] = "  " .. table.concat(pc, " ")
    lines[#lines + 1] = "C_AddOns.GetScriptsDisallowedForBeta() = " .. tostring(m.scriptsDisallowedForBeta) ..
        ((m.scriptsDisallowedForBeta == true) and "  (/run, /dump, /tinspect do nothing on this client)" or "")
    lines[#lines + 1] = ""
    for _, name in ipairs(ns.sectionOrder) do
        local s = ns.db and ns.db.sections[name]
        if s then
            local counts = {}
            for k, v in pairs(s.counts or {}) do counts[#counts + 1] = k .. "=" .. tostring(v) end
            table.sort(counts)
            lines[#lines + 1] = string.format("%-10s build %s at %s  %s", name, tostring(s.meta and s.meta.build),
                tostring(s.meta and s.meta.date), table.concat(counts, " "))
        else
            lines[#lines + 1] = string.format("%-10s (not collected)", name)
        end
    end
    local probe = ns.db and ns.db.sections.probe
    lines[#lines + 1] = string.format("%-10s outOfCombat=%s inCombat=%s", "probe",
        tostring(probe and probe.outOfCombat ~= nil), tostring(probe and probe.inCombat ~= nil))
    lines[#lines + 1] = string.format("%-10s %d saved session(s)", "record",
        ForeverDumpRecordDB and ForeverDumpRecordDB.sessions and #ForeverDumpRecordDB.sessions or 0)
    lines[#lines + 1] = string.format("%-10s %d saved session(s), running=%s", "cl",
        ForeverDumpCombatLogDB and ForeverDumpCombatLogDB.sessions and #ForeverDumpCombatLogDB.sessions or 0,
        tostring(ns.CombatLog.IsActive()))
    lines[#lines + 1] = string.format("%-10s %d unique error(s), %d blocked/forbidden/warning event(s), handler=%s", "errors",
        ForeverDumpLogDB and ForeverDumpLogDB.errors and #ForeverDumpLogDB.errors or 0,
        ForeverDumpLogDB and ForeverDumpLogDB.blocked and #ForeverDumpLogDB.blocked or 0, tostring(ns.Errors.IsInstalled()))
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Remember: /reload or log out to write SavedVariables to disk."
    return table.concat(lines, "\n")
end

local function sectionText(name)
    local s = ns.db and ns.db.sections[name]
    if not s then return "-- section '" .. name .. "' not collected; run /fdump " .. name end
    local lines = { "==== " .. string.upper(name) .. " (summary; full data in SavedVariables) ====" }
    local function walk(t, prefix, depth)
        for _, k in ipairs(ns.SortedKeys(t)) do
            local v = t[k]
            if type(v) == "table" then
                local n = 0
                for _ in pairs(v) do n = n + 1 end
                lines[#lines + 1] = prefix .. tostring(k) .. " = {" .. n .. " entries}"
                if depth < 1 then walk(v, prefix .. "  ", depth + 1) end
            else
                lines[#lines + 1] = prefix .. tostring(k) .. " = " .. tostring(v)
            end
            if #lines > 5000 then return end
        end
    end
    walk(s, "", 0)
    return table.concat(lines, "\n")
end

function UI.Show(kind)
    UI.Ensure()
    local d = legacyData()
    local text
    if kind == "apis" then
        text = "==== APIS ====\n" .. table.concat(d.apis, "\n")
    elseif kind == "events" then
        text = "==== EVENTS ====\n" .. table.concat(d.events, "\n")
    elseif kind == "enums" then
        text = "==== ENUMS ====\n" .. table.concat(d.enums, "\n")
    elseif kind == "cvars" then
        text = ns.Legacy.CVarText(d.cvarsNested)
    elseif kind == "status" then
        text = statusText()
    elseif kind == "all" then
        text = table.concat({
            d.header,
            "==== APIS ====\n" .. table.concat(d.apis, "\n"),
            "==== EVENTS ====\n" .. table.concat(d.events, "\n"),
            "==== ENUMS ====\n" .. table.concat(d.enums, "\n"),
            ns.Legacy.CVarText(d.cvarsNested),
        }, "\n\n")
    elseif kind == "errors" then
        text = ns.Errors.Text()
    elseif ns.sections[kind] then
        text = sectionText(kind)
    else
        text = statusText()
    end
    edit:SetText(cap(text))
    edit:HighlightText()
    edit:SetFocus()
    frame.TitleText:SetText("ForeverDump - " .. tostring(kind) .. "  (Ctrl+C)")
    frame:Show()
end

function UI.Ensure()
    if frame then return end
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
    if type(rawget(_G, "UISpecialFrames")) == "table" then table.insert(UISpecialFrames, "ForeverDumpFrame") end
    if not frame.TitleText then
        frame.TitleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.TitleText:SetPoint("TOP", 0, -5)
    end

    local x = 0
    local function Btn(label, kind, width)
        local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        b:SetSize(width or 70, 22)
        b:SetPoint("TOPLEFT", 12 + x, -32)
        b:SetText(label)
        b:SetScript("OnClick", function() UI.Show(kind) end)
        x = x + (width or 70) + 4
    end
    Btn("Status", "status")
    Btn("APIs", "apis")
    Btn("Events", "events")
    Btn("Enums", "enums")
    Btn("CVars", "cvars")
    Btn("All", "all", 50)
    Btn("Docs", "docs", 54)
    Btn("Globals", "globals")
    Btn("Widgets", "widgets")

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
