local WROOT = os.getenv("WOWDEV_ROOT") or (function() -- portable root (handoff)
  local s = debug.getinfo(1, "S").source:sub(2)
  if s:sub(1, 1) ~= "/" then local p = io.popen("pwd"); s = p:read("*l") .. "/" .. s; p:close() end
  return s:match("^(.*)/kth/") or s:match("^(.*)/foreverdump/") or ".."
end)()
-- WoW's xpcall forwards extra arguments (Lua 5.2 style); plain Lua 5.1 drops them, which made AceAddon call
-- OnInitialize/OnEnable with self = nil inside the mock.
do
    local x51 = xpcall
    xpcall = function(f, h, ...)
        local n, a = select("#", ...), { ... }
        return x51(function() return f(unpack(a, 1, n)) end, h)
    end
end
-- extra globals the Ace libs / K.T.H. touch that ForeverDump's mock does not provide (test harness only)
local function noop() end
geterrorhandler = function() return _G.__errh or print end
seterrorhandler = function(f) _G.__errh = f end
hooksecurefunc = function(a, b, c)
    if type(a) == "table" then local o = a[b]; a[b] = function(...) local r = { o(...) }; c(...); return unpack(r) end
    else local o = _G[a]; _G[a] = function(...) local r = { o(...) }; b(...); return unpack(r) end end
end
IsLoggedIn = IsLoggedIn or function() return true end
strmatch, strfind, strsub, strlower, strupper, strtrim, format = string.match, string.find, string.sub, string.lower, string.upper,
    function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end, string.format
tinsert, tremove, tconcat = table.insert, table.remove, table.concat
strjoin = strjoin or function(sep, ...) return table.concat({ ... }, sep) end
table.wipe = table.wipe or wipe
securecall = securecall or function(f, ...) if type(f) == "string" then f = _G[f] end return f(...) end
issecurevariable = issecurevariable or function() return true end
UnitFactionGroup = UnitFactionGroup or function() return "Horde", "Horde" end
UnitHealthMax = UnitHealthMax or function() return 5000 end
UnitClass = UnitClass or function() return "Warrior", "WARRIOR", 1 end
UnitIsFriend = UnitIsFriend or function() return false end
UnitCanAttack = UnitCanAttack or function() return false end
UnitIsDead = UnitIsDead or function() return false end
UnitIsUnit = UnitIsUnit or function(a, b) return a == b end
UnitPowerType = UnitPowerType or function() return 0, "MANA" end
UnitSex = UnitSex or function() return 2 end
IsInInstance = function() return _G.__inInstance or false, _G.__instType or "none" end
GetNumBattlefieldScores = function() return _G.__numScores or 0 end
GetBattlefieldScore = GetBattlefieldScore or function() end
RequestBattlefieldScoreData = function() end
GetBattlefieldWinner = function() return _G.__winner end
LocalizedClassList = function() return { WARRIOR = "Warrior", PRIEST = "Priest", DRUID = "Druid",
    PALADIN = "Paladin", SHAMAN = "Shaman", MAGE = "Mage", ROGUE = "Rogue", HUNTER = "Hunter", WARLOCK = "Warlock" } end
LOCALIZED_CLASS_NAMES_MALE = LocalizedClassList()
RAID_CLASS_COLORS = RAID_CLASS_COLORS or setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end })
for k in pairs(LocalizedClassList()) do RAID_CLASS_COLORS[k] = { r = 1, g = 1, b = 1 } end
MAX_CLASSES = MAX_CLASSES or 9
C_CreatureInfo = C_CreatureInfo or {}
do local L = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", nil, "SHAMAN", "MAGE", "WARLOCK", nil, "DRUID" }
   C_CreatureInfo.GetClassInfo = function(id) local f = L[id]; if f then return { classFile = f, className = f:sub(1,1) .. f:sub(2):lower(), classID = id } end end end
GetSpecializationInfoForClassID = GetSpecializationInfoForClassID or function() end
GetSpecializationRoleByID = GetSpecializationRoleByID or function() end
StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopup_Show = StaticPopup_Show or noop
UIErrorsFrame = UIErrorsFrame or { AddMessage = function(_, m) local W = _G.__W; if W then W.blizzChat[#W.blizzChat + 1] = "UIErrorsFrame: " .. tostring(m) end end }
RaidWarningFrame = RaidWarningFrame or {}
RaidNotice_AddMessage = function(_, m) local W = _G.__W; if W then W.blizzChat[#W.blizzChat + 1] = "RaidWarningFrame: " .. tostring(m) end end
ChatTypeInfo = ChatTypeInfo or setmetatable({}, { __index = function() return {} end })
SELECTED_CHAT_FRAME = nil
InterfaceOptionsFramePanelContainer = InterfaceOptionsFramePanelContainer or CreateFrame("Frame")
GameFontHighlightLarge = GameFontHighlightLarge or GameFontNormal
BINDING_HEADER_HHTD = nil
LE_PARTY_CATEGORY_HOME, LE_PARTY_CATEGORY_INSTANCE = 1, 2
COMBATLOG_OBJECT_AFFILIATION_OUTSIDER, COMBATLOG_OBJECT_REACTION_HOSTILE, COMBATLOG_OBJECT_REACTION_FRIENDLY = 8, 64, 16
COMBATLOG_OBJECT_TYPE_NPC, COMBATLOG_OBJECT_TYPE_PLAYER = 2048, 1024
bit = { band = function(a, b) local r, p = 0, 1; while a > 0 and b > 0 do if a % 2 == 1 and b % 2 == 1 then r = r + p end a = math.floor(a / 2); b = math.floor(b / 2); p = p * 2 end return r end,
        bor = function(a, b) local r, p = 0, 1; while a > 0 or b > 0 do if a % 2 == 1 or b % 2 == 1 then r = r + p end a = math.floor(a / 2); b = math.floor(b / 2); p = p * 2 end return r end }
-- record what lands in the diagnostic frame and in K.T.H.'s own frame
local origCF = CreateFrame
CreateFrame = function(kind, name, ...)
    local o = origCF(kind, name, ...)
    if type(kind) == "string" and kind:lower() == "scrollingmessageframe" then
        o.AddMessage = function(_, m)
            if name == "KTHForeverDiagFrame" then _G.__diagLines = _G.__diagLines or {}; table.insert(_G.__diagLines, m)
            elseif name == "KTH_MessageFrame" then _G.__kthLines = _G.__kthLines or {}; table.insert(_G.__kthLines, m) end
        end
        o.ScrollUp, o.ScrollDown, o.Clear = noop, noop, noop
    end
    return o
end
C_Timer = C_Timer or {}
C_Timer.NewTicker = C_Timer.NewTicker or function(_, fn) return { Cancel = noop } end
C_Timer.NewTimer = C_Timer.NewTimer or function(_, fn) return { Cancel = noop } end
FOREIGN_SERVER_LABEL = FOREIGN_SERVER_LABEL or " (*)"
NumberFont_Shadow_Small = NumberFont_Shadow_Small or GameFontNormal
GameFontHighlight = GameFontHighlight or GameFontNormal
GameFontNormalSmall = GameFontNormalSmall or GameFontNormal
GameFontDisableSmall = GameFontDisableSmall or GameFontNormal
GameTooltip = GameTooltip or CreateFrame("GameTooltip", "GameTooltip")

-- texture getters (AceConfigDialog popup buttons) return a no-op texture stub in this mock
do
    local stub = setmetatable({}, { __index = function() return function() end end })
    local CF = CreateFrame
    CreateFrame = function(...)
        local f = CF(...)
        for _, m in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
            local orig = f[m]
            f[m] = function(self, ...) local t = orig and orig(self, ...) return t or stub end
        end
        local am = f.AddMessage
        if am then f.AddMessage = function(self, msg, ...) self.__lines = self.__lines or {}; self.__lines[#self.__lines + 1] = msg; return am(self, msg, ...) end end
        return f
    end
end

-- metadata: only addons that are actually loaded have metadata (the real client returns nil for others, e.g. "HHTD")
do
    local orig = C_AddOns.GetAddOnMetadata
    C_AddOns.GetAddOnMetadata = function(n, f)
        if n == "HHTD" then return nil end
        return orig(n, f)
    end
    if GetAddOnMetadata then GetAddOnMetadata = C_AddOns.GetAddOnMetadata end
end

-- Settings panel API (Forever ships the modern Settings UI: SettingsInbound attributes in ForeverDump run6b/7/9 globals)
Settings = Settings or {}
do
    local function cat(name) return { ID = name, name = name, GetID = function(self) return self.ID end } end
    Settings.RegisterCanvasLayoutCategory = Settings.RegisterCanvasLayoutCategory or function(_, name) return cat(name) end
    Settings.RegisterCanvasLayoutSubcategory = Settings.RegisterCanvasLayoutSubcategory or function(_, _, name) return cat(name) end
    Settings.RegisterAddOnCategory = Settings.RegisterAddOnCategory or function() end
    Settings.GetCategory = Settings.GetCategory or function(id) return cat(id) end
    Settings.OpenToCategory = Settings.OpenToCategory or function() end
end

-- BackdropTemplate (Forever has it: the user's /kthg created AceGUI's Frame container, which calls SetBackdrop, before
-- failing later in CheckBox). Templates are mixed in on CreateFrame like the client does.
do
    local CF = CreateFrame
    local noop = function() end
    CreateFrame = function(kind, name, parent, template, ...)
        local f = CF(kind, name, parent, template, ...)
        if type(template) == "string" and template:find("BackdropTemplate") then
            f.SetBackdrop, f.SetBackdropColor, f.SetBackdropBorderColor, f.ApplyBackdrop = noop, noop, noop, noop
            f.GetBackdrop = function() return nil end
            f.GetBackdropColor = function() return 0, 0, 0, 1 end
            f.GetBackdropBorderColor = function() return 1, 1, 1, 1 end
        end
        return f
    end
end

-- Forever API strictness (from ForeverDump's static dump, tests/forever_globals.lua): global FUNCTIONS the mock defines
-- but Forever does not are removed, and every read of an undefined global is recorded in __W.undefinedReads so a
-- call to a retail-only helper (e.g. SetDesaturation) shows up in tests instead of only in game.
do
    local FG = dofile(WROOT .. "/kth/tests/forever_globals.lua")
    local keep = {}
    for k in ("assert collectgarbage dofile error getfenv getmetatable ipairs load loadfile loadstring next pairs pcall print rawequal rawget rawset select setfenv setmetatable tonumber tostring type unpack xpcall require module gcinfo newproxy secretunwrap tconcat"):gmatch("%S+") do keep[k] = true end
    local removed = {}
    for k, v in pairs(_G) do
        if type(v) == "function" and not FG[k] and not keep[k] then removed[#removed + 1] = k end
    end
    for _, k in ipairs(removed) do _G[k] = nil end
    __W.removedNonForever = removed
    __W.undefinedReads = {}
    setmetatable(_G, { __index = function(_, k)
        if type(k) == "string" then __W.undefinedReads[k] = (__W.undefinedReads[k] or 0) + 1 end
        return nil
    end })
end

-- geometry / misc getters the docs-generated stubs leave nil (AceGUI layouts do arithmetic on them)
do
    local num = { GetWidth = 100, GetHeight = 20, GetStringWidth = 60, GetStringHeight = 12, GetLeft = 0, GetRight = 100,
        GetTop = 100, GetBottom = 0, GetScale = 1, GetEffectiveScale = 1, GetNumPoints = 1, GetLineHeight = 12,
        GetNumLines = 1, GetValue = 0, GetMinMaxValues = 0, GetValueStep = 1, GetVerticalScroll = 0,
        GetHorizontalScroll = 0, GetVerticalScrollRange = 0, GetHorizontalScrollRange = 0, GetAlpha = 1, GetID = 0 }
    local patched = {}
    __W.foreverWidgets = dofile(WROOT .. "/kth/tests/forever_widgets.lua")
    local function patch(o)
        local mt = getmetatable(o); local m = mt and mt.__index
        if type(m) ~= "table" or patched[m] then return end
        patched[m] = true
        for k, v in pairs(num) do
            if k == "GetMinMaxValues" then m[k] = function(self) return 0, 100 end
            else m[k] = function(self) return rawget(self, "__" .. k) or v end end
        end
        m.GetSize = function(self) return m.GetWidth(self), m.GetHeight(self) end
        m.SetWidth = function(self, w) self.__GetWidth = w end
        m.SetHeight = function(self, h) self.__GetHeight = h end
        m.SetSize = function(self, w, h) self.__GetWidth, self.__GetHeight = w, h end
        m.SetValue = function(self, v) self.__GetValue = v end
        m.GetTexture = m.GetTexture or function() return nil end
        m.IsMouseOver = function() return false end
        if m.SetText and m.SetNormalFontObject then
            m.GetFontString = function(self)
                if not rawget(self, "__fs") then local fs = self:CreateFontString() rawset(self, "__fs", fs) end
                return rawget(self, "__fs")
            end
        end
        -- Forever widget method set (static dump): add the methods the docs-generated mock lacks (no-op), and drop the
        -- ones Forever does not have, so a retail-only method call fails in the mock like it does in game.
        local kind = o.GetObjectType and o:GetObjectType()
        local FW = __W.foreverWidgets and kind and __W.foreverWidgets[kind]
        if FW then
            for name in pairs(FW) do if m[name] == nil then m[name] = function() end end end
            local drop = {}
            for name in pairs(m) do if type(name) == "string" and not FW[name] and name:match("^[A-Z]") then drop[#drop + 1] = name end end
            for _, name in ipairs(drop) do m[name] = nil end
            __W.droppedMethods = __W.droppedMethods or {}
            __W.droppedMethods[kind] = drop
        end
        local cft = m.CreateFontString
        if cft then m.CreateFontString = function(...) local o2 = cft(...) patch(o2) return o2 end end
        local ct = m.CreateTexture
        if ct then m.CreateTexture = function(...) local o2 = ct(...) patch(o2) return o2 end end
    end
    local CF = CreateFrame
    CreateFrame = function(...) local f = CF(...) patch(f) return f end
    __W.patchGeometry = patch
end
PlaySound = PlaySound or function() return true end
PlaySoundFile = PlaySoundFile or function() return true end
GetCVar = GetCVar or function() return "0" end
GetCVarBool = GetCVarBool or function() return false end
GetMouseFocus = nil -- retail removed it (GetMouseFoci); not in the Forever static dump either
CloseSpecialWindows = CloseSpecialWindows or function() return false end
-- WoW's string library extensions (string.split = strsplit, string.join = strjoin, string.trim = strtrim)
string.split = string.split or strsplit
string.join = string.join or strjoin
string.trim = string.trim or strtrim
