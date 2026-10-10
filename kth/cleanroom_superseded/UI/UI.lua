-- K.T.H. Forever - UI/UI.lua : own message frame, nameplate markers, healer list, alerts, slash commands.
-- All frames are insecure and K.T.H.-owned; nothing protected is called, so nothing needs InCombatLockdown,
-- except that we never touch forbidden (friendly-in-instance) nameplates.
local _, ns = ...
local S, E, D = ns.S, ns.E, ns.D
local UI = {}
ns.UI = UI
local call, str, bool = S.call, S.str, S.bool

local ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local CROSS = { 0.5, 0.75, 0.25, 0.5 }       -- raid icon 7 (cross)
local COLOR = { E = { 1, 0.15, 0.15 }, F = { 0.2, 1, 0.3 } }
local SOUND_TARGET, SOUND_NEW = 8959, 8174

-------------------------------------------------------------------------------- message frame
local function makeMsgFrame()
    local f = CreateFrame("ScrollingMessageFrame", "KTHForeverMessageFrame", UIParent)
    f:SetSize(460, 110)
    f:SetPoint("TOP", UIParent, "TOP", 0, -140)
    f:SetFontObject(GameFontNormal)
    f:SetJustifyH("CENTER")
    f:SetFading(true)
    f:SetFadeDuration(2)
    f:SetTimeVisible(8)
    f:SetMaxLines(100)
    f:SetInsertMode("BOTTOM")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(s) if not ns.db.locked then s:StartMoving() end end)
    f:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local p, _, rp, x, y = s:GetPoint()
        ns.db.msgPos = { p, rp, x, y }
    end)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.35)
    bg:Hide()
    f.bg = bg
    return f
end

function UI.setLocked(locked)
    ns.db.locked = locked
    local f = UI.msgFrame
    f:EnableMouse(not locked)
    if locked then f.bg:Hide() else f.bg:Show() end
    if UI.list then UI.list:EnableMouse(true) end
end

-------------------------------------------------------------------------------- nameplate markers
local markers = {}   -- token -> frame
local pool = {}

local function getMarker()
    local m = table.remove(pool)
    if not m then
        m = CreateFrame("Frame", nil, UIParent)
        m:SetSize(30, 30)
        m:SetFrameStrata("HIGH")
        m.tex = m:CreateTexture(nil, "OVERLAY")
        m.tex:SetAllPoints()
        m.tex:SetTexture(ICON)
        m.tex:SetTexCoord(CROSS[1], CROSS[2], CROSS[3], CROSS[4])
    end
    return m
end

local function hideMarker(tok)
    local m = markers[tok]
    if m then m:Hide(); m:ClearAllPoints(); markers[tok] = nil; pool[#pool + 1] = m end
end

local function wanted(rec)
    if not rec then return false end
    if rec.side == "F" and not ns.db.friendly then return false end
    return rec.claim == "HEALER" or (ns.db.probable and rec.claim == "PROBABLE")
end

function UI.updatePlate(tok)
    if not ns.db.plates then hideMarker(tok); return end
    local rec = D.ident(tok)
    if not wanted(rec) then hideMarker(tok); return end
    local plate = C_NamePlate and call(C_NamePlate.GetNamePlateForUnit, tok)
    if type(plate) ~= "table" then hideMarker(tok); return end
    if plate.IsForbidden and bool(call(plate.IsForbidden, plate)) then hideMarker(tok); return end
    local m = markers[tok] or getMarker()
    markers[tok] = m
    local c = COLOR[rec.side]
    local a = rec.claim == "HEALER" and 1 or 0.45
    m.tex:SetVertexColor(c[1], c[2], c[3], a)
    m:ClearAllPoints()
    if pcall(m.SetPoint, m, "BOTTOM", plate, "TOP", 0, 4) then m:Show() else hideMarker(tok) end
end

function UI.plateAdded(tok) UI.updatePlate(tok) end
function UI.plateRemoved(tok) hideMarker(tok) end

function UI.rescan()
    for i = 1, 40 do
        local tok = "nameplate" .. i
        if bool(call(UnitExists, tok)) then UI.updatePlate(tok) else hideMarker(tok) end
    end
    UI.refreshList()
end

-------------------------------------------------------------------------------- list window
local function makeList()
    local f = CreateFrame("Frame", "KTHForeverListFrame", UIParent)
    f:SetSize(220, 40)
    f:SetPoint("RIGHT", UIParent, "RIGHT", -60, 120)
    f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(s) s:StartMoving() end)
    f:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local p, _, rp, x, y = s:GetPoint()
        ns.db.listPos = { p, rp, x, y }
    end)
    local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 0.5)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetPoint("TOPLEFT", 6, -6)
    f.text:SetJustifyH("LEFT")
    return f
end

function UI.refreshList()
    local f = UI.list
    if not f or not f:IsShown() then return end
    local lines = { "|cffff5555K.T.H. Forever|r" }
    for _, side in ipairs({ "E", "F" }) do
        if side == "E" or ns.db.friendly then
            lines[#lines + 1] = side == "E" and "|cffff8080Enemy healers|r" or "|cff80ff80Friendly healers|r"
            for _, r in ipairs(E.healers(side, ns.db.probable)) do
                local tag = r.claim == "HEALER" and "" or " |cff888888(probable)|r"
                lines[#lines + 1] = "  " .. r.name .. " |cffaaaaaa" .. (E.classOf(r) or "?") .. "|r" .. tag
            end
        end
    end
    f.text:SetText(table.concat(lines, "\n"))
    f:SetHeight(f.text:GetStringHeight() + 12)
end
UI.refresh = UI.refreshList

-------------------------------------------------------------------------------- alerts
local lastSound = -100
local function sound(id)
    if not ns.db.sound then return end
    local t = GetTime()
    if t - lastSound < 3 then return end
    lastSound = t
    call(PlaySound, id, "Master")
end

function UI.onClaim(rec, claim)
    if claim == "HEALER" then
        if rec.side == "E" then
            ns.msg("|cffff8080Enemy healer|r " .. rec.name .. " (" .. (E.classOf(rec) or "?") .. ") - " .. (rec.why or ""))
            sound(SOUND_NEW)
        elseif ns.db.friendly then
            ns.msg("|cff80ff80Friendly healer|r " .. rec.name .. " (" .. (E.classOf(rec) or "?") .. ")")
        end
    end
    for i = 1, 40 do
        local tok = "nameplate" .. i
        local r = D.ident(tok)
        if r == rec then UI.updatePlate(tok) end
    end
    UI.refreshList()
end

function UI.targetChanged()
    local rec = D.ident("target")
    if rec and rec.side == "E" and rec.claim == "HEALER" then
        ns.msg("Target is an enemy |cffff8080HEALER|r: " .. rec.name)
        sound(SOUND_TARGET)
    end
end

-------------------------------------------------------------------------------- slash
local function applyMarks()
    for k, on in pairs(ns.db.marks) do
        local side, name = k:match("^([EF]):(.+)$")
        if side and on then E.manual(E.get(side, name), GetTime(), true) end
    end
end
UI.applyMarks = applyMarks

local HELP = {
    "/kth list - toggle healer list", "/kth msg - toggle message frame", "/kth lock - lock/unlock message frame",
    "/kth sound - toggle sounds", "/kth probable - toggle PROBABLE tier", "/kth friendly - toggle friendly healers",
    "/kth plates - toggle nameplate markers", "/kth mark <name> [e|f] / unmark <name> [e|f] - custom mark",
    "/kth announce [channel] - send enemy healer list (default INSTANCE_CHAT)", "/kth status - evidence table",
    "/kth set <key> <n> - tune (healMin, healPct, unknownHealMin)", "/kth test - demo marker/message",
    "/kth debug - toggle debug lines", "/kth anywhere - also run outside battlegrounds",
}

local function toggle(k) ns.db[k] = not ns.db[k]; ns.msg(k .. " = " .. tostring(ns.db[k])); UI.rescan() end

function UI.slash(input)
    input = str(input) or ""
    local cmd, rest = input:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    if cmd == "" or cmd == "help" then
        for _, l in ipairs(HELP) do ns.msg(l) end
        UI.msgFrame:Show()
    elseif cmd == "list" then
        if UI.list:IsShown() then UI.list:Hide() else UI.list:Show(); UI.refreshList() end
        ns.db.listShown = UI.list:IsShown()
    elseif cmd == "msg" then
        ns.db.msgShown = not ns.db.msgShown
        if ns.db.msgShown then UI.msgFrame:Show() else UI.msgFrame:Hide() end
    elseif cmd == "lock" then UI.setLocked(not ns.db.locked); ns.msg(ns.db.locked and "locked" or "unlocked - drag me")
    elseif cmd == "sound" or cmd == "probable" or cmd == "friendly" or cmd == "plates" or cmd == "debug" or cmd == "anywhere" then
        toggle(cmd)
    elseif cmd == "mark" or cmd == "unmark" then
        local name, side = rest:match("^(%S+)%s*(%a?)")
        if not name then ns.msg("usage: /kth " .. cmd .. " <name> [e|f]"); return end
        side = (side and side:lower() == "f") and "F" or "E"
        name = S.firstWord(name)
        if not name then return end
        name = name:sub(1, 1):upper() .. name:sub(2):lower()
        ns.db.marks[side .. ":" .. name] = (cmd == "mark") or nil
        E.manual(E.get(side, name), GetTime(), cmd == "mark")
        ns.msg((cmd == "mark" and "marked " or "unmarked ") .. side .. ":" .. name)
    elseif cmd == "announce" then
        local names = {}
        for _, r in ipairs(E.healers("E")) do names[#names + 1] = r.name end
        local text = "Enemy healers: " .. (#names > 0 and table.concat(names, ", ") or "none known")
        local chan = rest ~= "" and rest:upper() or "INSTANCE_CHAT"
        local ok = pcall(SendChatMessage, text, chan)
        ns.msg((ok and "sent: " or "could not send: ") .. text)
    elseif cmd == "status" then
        local n = 0
        for _, r in pairs(E.R) do
            if r.heal > 0 or r.claim then
                n = n + 1
                ns.msg(string.format("%s %s %s heal=%d dmg=%d casts=%d mana=%d/%d %s", r.key, E.classOf(r) or "?",
                    r.claim or "-", r.heal, r.dmg, r.casts, r.mana, r.mana + r.nomana, r.why or ""))
            end
        end
        local st = E.stats
        ns.msg(string.format("inBG=%s records=%d joinFrames=%d ambiguous=%d heal=%d dmg=%d contra=%d",
            tostring(D.inBG), n, st.joinFrames, st.joinAmbig, st.healLinks, st.dmgLinks, st.contradictions))
    elseif cmd == "set" then
        local k, v = rest:match("^(%S+)%s+(%d+)$")
        if k and E.CFG[k] ~= nil then
            E.CFG[k] = tonumber(v); ns.db.cfg = ns.db.cfg or {}; ns.db.cfg[k] = E.CFG[k]
            ns.msg(k .. " = " .. v)
        else ns.msg("usage: /kth set <healMin|healPct|unknownHealMin|probableMin> <n>") end
    elseif cmd == "test" then
        ns.msg("test: enemy healer |cffff8080Testname|r (PRIEST) - demo")
        sound(SOUND_NEW)
        local tok = bool(call(UnitExists, "target")) and "target" or nil
        if tok then
            local plate = C_NamePlate and call(C_NamePlate.GetNamePlateForUnit, tok)
            if type(plate) == "table" and not bool(call(plate.IsForbidden, plate)) then
                local m = getMarker(); m.tex:SetVertexColor(1, 0.15, 0.15, 1)
                if pcall(m.SetPoint, m, "BOTTOM", plate, "TOP", 0, 4) then
                    m:Show(); C_Timer.After(5, function() m:Hide(); m:ClearAllPoints(); pool[#pool + 1] = m end)
                end
            end
        end
    else
        ns.msg("unknown command - /kth help")
    end
end

function UI.init()
    UI.msgFrame = makeMsgFrame()
    if ns.db.msgPos then
        local p = ns.db.msgPos
        UI.msgFrame:ClearAllPoints(); UI.msgFrame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end
    UI.setLocked(ns.db.locked ~= false)
    if not ns.db.msgShown then UI.msgFrame:Hide() end
    UI.list = makeList()
    if ns.db.listPos then
        local p = ns.db.listPos
        UI.list:ClearAllPoints(); UI.list:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end
    if not ns.db.listShown then UI.list:Hide() end
    SLASH_KTHFOREVER1 = "/kth"
    SLASH_KTHFOREVER2 = "/killthehealer"
    SlashCmdList.KTHFOREVER = UI.slash
    ns.flushPending()
    ns.msg("Forever " .. ns.VERSION .. " loaded - /kth help")
end

-- re-apply custom marks whenever a battleground starts
local prevUpdateZone = D.updateZone
D.updateZone = function()
    local was = D.inBG
    prevUpdateZone()
    if D.inBG and not was then applyMarks() end
end
