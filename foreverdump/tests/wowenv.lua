-- Minimal WoW client mock for smoke-testing ForeverDump in plain Lua 5.1.
-- Widget methods and C_ namespaces are generated from the real Forever
-- Blizzard_APIDocumentationGenerated files (Gethe/wow-ui-source, branch "forever").
local M = {}
local DOCS_ROOT = assert(os.getenv("FORE_DOCS"), "set FORE_DOCS to .../Interface/AddOns")

M.state = { combat = false, time = 1000, frames = {}, onUpdate = {}, timers = {}, touchedSecret = 0,
    restrictedRegistrations = {}, registerAllCalls = 0 }
local S = M.state

-- a secret value: any use other than issecretvalue/rawequal/type errors
local SECRET = newproxy(true)
do
    local mt = getmetatable(SECRET)
    -- every touch is counted (v2.2.11: no exemption for the ops matrix / lab boundary any more)
    local function boom()
        local tb = debug.traceback()
        -- deliberate touches: ops matrix (Controls.lua) and lab boundary ops (Lab.lua)
        -- v2.2.11 (run 9 taint.log): the ops matrix / lab boundary no longer operate on secrets either, so a touch
        -- from Controls.lua / Lab.lua counts as a violation too (touchedByControls keeps the site split for messages)
        if tb:find("Controls.lua", 1, true) or tb:find("Lab.lua", 1, true) then S.touchedByControls = (S.touchedByControls or 0) + 1 end
        S.touchedSecret = S.touchedSecret + 1
        if os.getenv("FD_TRACE") then io.stderr:write(debug.traceback("secret touched", 2), "\n") end
        error("attempt to perform arithmetic on a secret number value", 2)
    end
    mt.__index, mt.__newindex, mt.__tostring, mt.__concat, mt.__len = boom, boom, boom, boom, boom
    mt.__call, mt.__unm, mt.__add, mt.__lt, mt.__le = boom, boom, boom, boom, boom
end
M.SECRET = SECRET
issecretvalue = function(v) return rawequal(v, SECRET) end
issecrettable = function(v) return false end
canaccessvalue = function(v) return not rawequal(v, SECRET) end

------------------------------------------------------------------ docs (private copy for mocks)
local function vivify()
    return setmetatable({}, { __index = function(t, k)
        local v = setmetatable({}, { __index = function() return 0 end })
        rawset(t, k, v)
        return v
    end })
end
local function collectDocs()
    local systems, tables = {}, {}
    Enum, Constants = vivify(), vivify()
    local saved = APIDocumentation
    APIDocumentation = { AddDocumentationTable = function(_, t)
        if t.Name then systems[#systems + 1] = t else for _, x in ipairs(t.Tables or {}) do tables[#tables + 1] = x end end
    end }
    local toc = io.open(DOCS_ROOT .. "/Blizzard_APIDocumentationGenerated/Blizzard_APIDocumentationGenerated.toc")
    for line in toc:lines() do
        if line:match("%.lua%s*$") then dofile(DOCS_ROOT .. "/Blizzard_APIDocumentationGenerated/" .. line:match("^%s*(.-)%s*$")) end
    end
    toc:close()
    APIDocumentation = saved
    return systems, tables
end
local DOC_SYSTEMS, DOC_TABLES = collectDocs()
-- rebuild real Enum / Constants from the documentation tables
Enum, Constants = {}, {}
local function addTable(t)
    if t.Type == "Enumeration" and t.Fields then
        Enum[t.Name] = Enum[t.Name] or {}
        for _, f in ipairs(t.Fields) do Enum[t.Name][f.Name] = f.EnumValue end
    elseif t.Type == "Constants" and t.Values then
        Constants[t.Name] = Constants[t.Name] or {}
        for _, v in ipairs(t.Values) do
            if type(v.Value) ~= "table" then Constants[t.Name][v.Name] = v.Value end
        end
    end
end
for _, sys in ipairs(DOC_SYSTEMS) do for _, t in ipairs(sys.Tables or {}) do addTable(t) end end
for _, t in ipairs(DOC_TABLES) do addTable(t) end
local BY_NAME = {}
for _, s in ipairs(DOC_SYSTEMS) do BY_NAME[s.Name] = s end
M.docSystems = DOC_SYSTEMS

local function sample(ret)
    local t = ret.Type
    if t == "bool" then return false end
    if t == "number" or t == "luaIndex" or t == "fileID" then return 1 end
    if t == "string" or t == "cstring" then return "x" end
    if t == "table" then return {} end
    return nil
end
local function stubFor(f)
    local rets = f.Returns or {}
    return function()
        local out = {}
        for i, r in ipairs(rets) do out[i] = sample(r) end
        return unpack(out, 1, #rets)
    end
end

------------------------------------------------------------------ widgets
local CHAIN = {
    Object = { "SimpleObjectAPI" }, FSO = { "Object", "SimpleFrameScriptObjectAPI" },
    ScriptRegion = { "FSO", "SimpleScriptRegionAPI", "SimpleScriptRegionResizingAPI" },
    Region = { "ScriptRegion", "SimpleRegionAPI" }, Frame = { "ScriptRegion", "SimpleFrameAPI" },
    Button = { "Frame", "SimpleButtonAPI" }, CheckButton = { "Button", "SimpleCheckboxAPI" },
    EditBox = { "Frame", "SimpleEditBoxAPI" }, ScrollFrame = { "Frame", "SimpleScrollFrameAPI" },
    Slider = { "Frame", "SimpleSliderAPI" }, StatusBar = { "Frame", "SimpleStatusBarAPI" },
    Cooldown = { "Frame", "FrameAPICooldown" }, GameTooltip = { "Frame", "FrameAPITooltip" },
    MessageFrame = { "Frame", "SimpleMessageFrameAPI" }, ScrollingMessageFrame = { "Frame" },
    SimpleHTML = { "Frame", "SimpleHTMLAPI" }, ColorSelect = { "Frame", "SimpleColorSelectAPI" },
    Model = { "Frame", "SimpleModelAPI" }, PlayerModel = { "Model", "FrameAPICharacterModelBase" },
    DressUpModel = { "PlayerModel", "FrameAPIDressUpModel" }, CinematicModel = { "PlayerModel", "FrameAPICinematicModel" },
    TabardModel = { "PlayerModel", "FrameAPITabardModelBase", "FrameAPITabardModel" },
    ModelScene = { "Frame", "FrameAPIModelSceneFrame" }, FogOfWarFrame = { "Frame", "FrameAPIFogOfWarFrame" },
    UnitPositionFrame = { "Frame", "FrameAPIUnitPositionFrame" }, QuestPOIFrame = { "Frame", "FrameAPIQuestPOI" },
    ScenarioPOIFrame = { "Frame", "FrameAPIScenarioPOI" }, ArchaeologyDigSiteFrame = { "Frame", "FrameAPIArchaeologyDigsite" },
    OffScreenFrame = { "Frame", "SimpleOffScreenFrameAPI" }, MapScene = { "Frame", "SimpleMapSceneAPI" },
    PingPinFrame = { "Frame", "PingPinFrameAPI" }, VectorGraphics = { "Frame", "SimpleVectorGraphicsAPI" },
    ModelFFX = { "Frame", "SimpleModelFFXAPI" },
    Texture = { "Region", "SimpleTextureBaseAPI", "SimpleTextureAPI" },
    MaskTexture = { "Region", "SimpleTextureBaseAPI", "SimpleMaskTextureAPI" },
    Line = { "Region", "SimpleTextureBaseAPI", "SimpleLineAPI" }, FontString = { "Region", "SimpleFontStringAPI" },
    AnimationGroup = { "FSO", "SimpleAnimGroupAPI" }, Animation = { "FSO", "SimpleAnimAPI" },
    Alpha = { "Animation", "SimpleAnimAlphaAPI" }, Translation = { "Animation", "SimpleAnimTranslationAPI" },
    LineTranslation = { "Animation", "SimpleAnimTranslationLineAPI" }, Scale = { "Animation", "SimpleAnimScaleAPI" },
    LineScale = { "Animation", "SimpleAnimScaleLineAPI" }, Rotation = { "Animation", "SimpleAnimRotationAPI" },
    Path = { "Animation", "SimpleAnimPathAPI" }, FlipBook = { "Animation", "SimpleAnimFlipBookAPI" },
    VertexColor = { "Animation", "SimpleAnimVertexColorAPI" },
    TextureCoordTranslation = { "Animation", "SimpleAnimTextureCoordTranslationAPI" },
    ControlPoint = { "FSO", "SimpleControlPointAPI" }, Font = { "FSO", "SimpleFontAPI" },
    Duration = { "LuaDurationObjectAPI" }, Curve = { "LuaCurveObjectBaseAPI", "LuaCurveObjectAPI" },
}
local ABSTRACT_OF = { Object = true, FSO = true, ScriptRegion = true, Region = true }
local REAL_NAME = { FSO = "ScriptObject" }

local methodCache, isACache = {}, {}
local function buildMethods(kind, acc, isa)
    for _, part in ipairs(CHAIN[kind] or {}) do
        if CHAIN[part] then
            isa[REAL_NAME[part] or part] = true
            buildMethods(part, acc, isa)
        elseif BY_NAME[part] then
            for _, f in ipairs(BY_NAME[part].Functions or {}) do acc[f.Name] = stubFor(f) end
        end
    end
    isa[kind] = true
    return acc, isa
end

local newObject
local function methodsFor(kind)
    if methodCache[kind] then return methodCache[kind], isACache[kind] end
    local m, isa = buildMethods(kind, {}, {})
    -- behaviour needed by the addon / harness
    m.GetObjectType = function() return kind end
    m.IsObjectType = function(_, t) return isa[t] == true end
    m.GetName = function(self) return rawget(self, "__name") end
    m.SetScript = function(self, s, fn) self.__scripts = self.__scripts or {}; self.__scripts[s] = fn
        if s == "OnUpdate" then S.onUpdate[self] = fn end end
    m.GetScript = function(self, s) return self.__scripts and self.__scripts[s] end
    m.HookScript = m.SetScript
    m.SetAttribute = function(self, k, v)
        self.__attrs = self.__attrs or {}; self.__attrs[k] = v
        local h = self.__scripts and self.__scripts.OnAttributeChanged
        if h then h(self, k, v) end
    end
    m.GetAttribute = function(self, k) return self.__attrs and self.__attrs[k] end
    m.SetForbidden = function(self) self.__forbidden = true end
    m.HasScript = function() return true end
    m.RegisterEvent = function(self, e)
        if e == "COMBAT_LOG_EVENT" or e == "COMBAT_LOG_EVENT_UNFILTERED" then
            -- real client: ADDON_ACTION_FORBIDDEN + "disable addon" popup (pcall does not help)
            S.restrictedRegistrations[e] = (S.restrictedRegistrations[e] or 0) + 1
        end
        self.__events = self.__events or {}; self.__events[e] = true
    end
    m.RegisterUnitEvent = function(self, e, ...)
        self.__events = self.__events or {}; self.__events[e] = true
        self.__unitFilter = self.__unitFilter or {}
        local u = {}
        for i = 1, select("#", ...) do u[select(i, ...)] = true end
        self.__unitFilter[e] = u
    end
    m.UnregisterEvent = function(self, e) if self.__events then self.__events[e] = nil end end
    m.RegisterAllEvents = function(self) S.registerAllCalls = S.registerAllCalls + 1; self.__all = true end
    m.UnregisterAllEvents = function(self) self.__all = nil; self.__events = {} end
    m.Show = function(self) self.__shown = true end
    m.Hide = function(self) self.__shown = false end
    m.IsShown = function(self) return self.__shown ~= false end
    m.IsVisible = m.IsShown
    m.IsForbidden = function(self) return self.__forbidden == true end
    m.IsProtected = function(self) return self.__protected == true, self.__protected == true end
    m.GetParent = function(self) return self.__parent end
    m.GetSize = function() return 100, 50 end
    m.GetFrameStrata = function() return "MEDIUM" end
    m.GetFrameLevel = function() return 1 end
    m.SetText = function(self, t) self.__text = t end
    m.GetText = function(self) return self.__text end
    m.CreateTexture = function(self) return newObject("Texture", nil, self) end
    m.CreateMaskTexture = function(self) return newObject("MaskTexture", nil, self) end
    m.CreateLine = function(self) return newObject("Line", nil, self) end
    m.CreateFontString = function(self) return newObject("FontString", nil, self) end
    m.CreateAnimationGroup = function(self) return newObject("AnimationGroup", nil, self) end
    m.CreateAnimation = function(self, t)
        t = t or "Animation"
        if t == "RadialProgress" then error("unknown animation type " .. t) end
        return newObject(t, nil, self)
    end
    m.CreateControlPoint = function(self) return newObject("ControlPoint", nil, self) end
    m.GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end
    m.StartMoving, m.StopMovingOrSizing = function() end, function() end
    methodCache[kind], isACache[kind] = m, isa
    return m, isa
end

local metas = {}
newObject = function(kind, name, parent)
    if not metas[kind] then metas[kind] = { __index = (methodsFor(kind)) } end
    local o = setmetatable({ [0] = newproxy(false), __name = name, __parent = parent }, metas[kind])
    S.frames[#S.frames + 1] = o
    if name then _G[name] = o end
    return o
end
M.newObject = newObject

local CREATABLE = {}
for k in pairs(CHAIN) do if not ABSTRACT_OF[k] then CREATABLE[k] = true end end
for _, k in ipairs({ "Texture", "MaskTexture", "Line", "FontString", "AnimationGroup", "Animation", "Alpha",
    "Translation", "LineTranslation", "Scale", "LineScale", "Rotation", "Path", "FlipBook", "VertexColor",
    "TextureCoordTranslation", "ControlPoint", "Font", "Duration", "Curve" }) do CREATABLE[k] = nil end

-- Forever 70245 (2026-10-07 run): documented but not creatable. The first three also print a LUA_WARNING that pcall
-- cannot suppress (fired as an event; ForeverDump logs it into ForeverDumpLogDB.blocked).
local FOREVER_NOT_CREATABLE = { MapScene = "Unable to create frame type: MapScene", VectorGraphics = "Unknown frame type: VectorGraphics",
    ModelFFX = "Unable to create frame type: ModelFFX", Blob = false, PingPinFrame = false }
M.FOREVER_NOT_CREATABLE = FOREVER_NOT_CREATABLE
local CANON = {}
for k in pairs(CHAIN) do CANON[string.lower(k)] = k end
function CreateFrame(kind, name, parent, template)
    if type(kind) == "string" then kind = CANON[string.lower(kind)] or kind end -- the client is case-insensitive
    if FOREVER_NOT_CREATABLE[kind] ~= nil then
        if FOREVER_NOT_CREATABLE[kind] then
            S.luaWarnings = S.luaWarnings or {}
            S.luaWarnings[#S.luaWarnings + 1] = FOREVER_NOT_CREATABLE[kind]
            M.fire("LUA_WARNING", FOREVER_NOT_CREATABLE[kind])
        end
        error("CreateFrame: Unknown frame type '" .. tostring(kind) .. "'")
    end
    if not CREATABLE[kind] then error("CreateFrame: Unknown frame type '" .. tostring(kind) .. "'") end
    local o = newObject(kind, name, parent)
    -- v2.2.14: ForeverDump's own message frame is where ns.Print lines land (W.chat = what the user sees);
    -- DEFAULT_CHAT_FRAME lines go to W.blizzChat (must stay empty: tests/bg_chat_taint.lua)
    if kind == "ScrollingMessageFrame" then
        o.AddMessage = function(_, msg) if name == "ForeverDumpMessageFrame" then M.chat[#M.chat + 1] = msg end end
        o.Clear = function() end
    end
    return o
end
function CreateFont(name) return newObject("Font", name) end

------------------------------------------------------------------ globals
UIParent = newObject("Frame", "UIParent")
WorldFrame = newObject("Frame", "WorldFrame")
local forbidden = newObject("Frame", "ForbiddenTestFrame"); forbidden.__forbidden = true
local protected = newObject("Button", "ProtectedTestButton", UIParent); protected.__protected = true
GameFontHighlightSmall = newObject("Font", "GameFontHighlightSmall")
GameFontNormal = newObject("Font", "GameFontNormal")
M.chat, M.blizzChat = {}, {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) M.blizzChat[#M.blizzChat + 1] = msg end, SetMaxLines = function() end }
UISpecialFrames = {}
SlashCmdList = {}
hash_SlashCmdList = {}
SLASH_DUMP1 = "/dump"
SLASH_FRAMESTACK1 = "/fstack"
ITEM_LEVEL = "Item Level %d"
NUM_BAG_SLOTS = 4
LE_EXPANSION_CLASSIC = 0
-- Newer Forever builds: WOW_PROJECT_ID == WOW_PROJECT_CAMELOT (18) (Ketho/BlizzardInterfaceResources forever, 70205).
WOW_PROJECT_MAINLINE = 1
WOW_PROJECT_CLASSIC = 2
WOW_PROJECT_CAMELOT = 18
WOW_PROJECT_ID = WOW_PROJECT_CAMELOT
SOUNDKIT = { IG_MAINMENU_OPEN = 850 }
bit = { band = function(a, b) return a end }
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
strsplit = function(sep, s) local out = {} for p in string.gmatch(s, "[^" .. sep .. "]+") do out[#out + 1] = p end return unpack(out) end
GetTime = function() return S.time end
date = os.date
time = os.time
debugprofilestop = function() return os.clock() * 1000 end
GetBuildInfo = function() return "1.60.1", "70245", "Oct 6 2026", 16001, "", "", 16001 end
GetLocale = function() return "enUS" end
GetCurrentRegion = function() return 1 end
GetRealmName = function() return "Mockrealm" end
InCombatLockdown = function() return S.combat end
IsPublicBuild = function() return true end
GetFonts = function() return { "GameFontNormal", "GameFontHighlightSmall" } end
EnumerateFrames = function(f)
    local idx = 0
    if f then for i, x in ipairs(S.frames) do if x == f then idx = i break end end end
    return S.frames[idx + 1]
end
GameTooltip_Hide = function() end
TaintedAddonGlobalFunction = function() end -- insecure on purpose
TaintedAddonDB = { profileKeys = { ["Somebody - Realm"] = "Default" }, count = 1 } -- addon SavedVariables (insecure)



-- Model of the Forever 70245 behaviour seen in the 2026-10-07 run (Client.log + ForeverDumpLogDB.errors): with an
-- addon post-hook on a CallbackRegistry method (EventRegistry.TriggerEvent), the client's hook trampoline raised
-- "attempt to call a nil value" ([C]: ? directly under [C]: in function 'TriggerEvent', no addon frame) for every call
-- that arrives through a secure dispatch path (GLOBAL_MOUSE_DOWN from EventRegistry.frameEventFrame, UI.QueryStickyFocusFrames,
-- PlunderstormQueueTutorial.Update, ...), while other calls ran the hook. The C internals are not visible from Lua, so the
-- mock reproduces the observable contract: S.secureDispatch = true marks such a call; the trampoline then errors.
M.hooks = {}
hooksecurefunc = function(a, b, c)
    local tbl, name, fn = a, b, c
    if type(a) == "string" then tbl, name, fn = _G, a, b end
    M.hooks[#M.hooks + 1] = { tbl = tbl, name = name }
    if type(tbl) == "table" and tbl.callbackTables and name == "TriggerEvent" then
        local orig = tbl[name]
        tbl[name] = function(...)
            if S.secureDispatch then
                geterrorhandler()("attempt to call a nil value")
                return
            end
            local r = { orig(...) }
            fn(...)
            return unpack(r)
        end
        return
    end
    local orig = tbl[name]
    tbl[name] = function(...)
        local r = { orig(...) }
        fn(...)
        return unpack(r)
    end
end
issecurevariable = function(t, k)
    if k == nil then k, t = t, _G end
    if type(k) ~= "string" then return true end
    if t == _G then return not (k:find("^TaintedAddon") or k:find("^ForeverDump") or k == "SLASH_FOREVERDUMP1") end
    return true
end

-- C_ namespaces + documented global functions, stubbed from the docs
local MISSING = { ["C_Item.GetItemCooldown"] = true } -- documented but absent: exercised by docs.missing
for _, sys in ipairs(DOC_SYSTEMS) do
    if sys.Type ~= "ScriptObject" then
        local target = _G
        if sys.Namespace then
            _G[sys.Namespace] = _G[sys.Namespace] or {}
            target = _G[sys.Namespace]
        end
        for _, f in ipairs(sys.Functions or {}) do
            local full = sys.Namespace and (sys.Namespace .. "." .. f.Name) or f.Name
            if not MISSING[full] and target[f.Name] == nil then target[f.Name] = stubFor(f) end
        end
    end
end
C_Item.UndocumentedMockFunction = function() end
Enum.ConsoleCommandType = { Cvar = 0, Command = 1, Macro = 2, Script = 3 }
Enum.ConsoleCategory = { Debug = 0, Graphics = 1, Console = 2, Combat = 3, Game = 4, Default = 5 }
Enum.SpellBookSpellBank = { Player = 0, Pet = 1 }
Enum.TooltipDataType = { Item = 0, Spell = 1, Unit = 2 }
Constants.Mock = { A = 1, B = { C = 2 } }

-- behaviour overrides that matter to the addon
C_Timer = { After = function(sec, fn) S.timers[#S.timers + 1] = fn end }
C_EventUtils.IsEventValid = function(e) return e ~= "PLAYER_ENTERING_WORLD_MOCK_INVALID" end
C_AddOns.GetNumAddOns = function() return 2 end
C_AddOns.GetScriptsDisallowedForBeta = function() return true end
local ADDONS = { { "ForeverDump", "ForeverDump" }, { "SomeAddon", "Some Addon" } }
C_AddOns.GetAddOnInfo = function(i)
    if type(i) == "number" then local a = ADDONS[i]; return a[1], a[2], "notes", true, nil, "INSECURE", false end
    if i == "Blizzard_DebugTools" or i == "Blizzard_APIDocumentation" or i == "Blizzard_APIDocumentationGenerated" then
        return i, i, "", true, nil, "SECURE", false end
    error("Couldn't find addon " .. tostring(i))
end
C_AddOns.IsAddOnLoaded = function() return true, true end
C_AddOns.GetAddOnDependencies = function(n) if n == "Blizzard_APIDocumentationGenerated" then return "Blizzard_APIDocumentation" end end
C_AddOns.GetAddOnMetadata = function(n, f) if f == "Version" then return "1.0" end end
local docsLoaded = false
C_AddOns.LoadAddOn = function(name)
    if name == "Blizzard_APIDocumentation" and not docsLoaded then
        docsLoaded = true
        local base = DOCS_ROOT .. "/Blizzard_APIDocumentation/"
        for _, f in ipairs({ "BaseAPIMixin.lua", "FieldsAPIMixin.lua", "FunctionsAPIMixin.lua", "SystemsAPIMixin.lua",
                             "TablesAPIMixin.lua", "EventsAPIMixin.lua", "Blizzard_APIDocumentation.lua" }) do
            dofile(base .. f)
        end
        local toc = io.open(DOCS_ROOT .. "/Blizzard_APIDocumentationGenerated/Blizzard_APIDocumentationGenerated.toc")
        for line in toc:lines() do
            if line:match("%.lua%s*$") then dofile(DOCS_ROOT .. "/Blizzard_APIDocumentationGenerated/" .. line:match("^%s*(.-)%s*$")) end
        end
        toc:close()
    end
    return true
end
Mixin = function(obj, ...) for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do obj[k] = v end end return obj end
CreateFromMixins = function(...) return Mixin({}, ...) end

ConsoleGetAllCommands = function()
    return {
        { command = "scriptErrors", commandType = 0, category = 2, help = "Lua errors" },
        { command = "taintLog", commandType = 0, category = 0, help = "taint log" },
        { command = "accountName", commandType = 0, category = 6, help = "account" },
        { command = "reloadui", commandType = 1, category = 2, help = "reload" },
    }
end
local CVARS = { scriptErrors = { "1", "0" }, taintLog = { "0", "0" }, accountName = { "me@example.com", "" },
    advancedCombatLogging = { "0", "0" }, scriptProfile = { "0", "0" } }
M.CVARS = CVARS
C_CVar.GetCVarInfo = function(n) local c = CVARS[n]; if c then return c[1], c[2], true, false, false, false, false end end
C_CVar.GetCVar = function(n) local c = CVARS[n]; return c and c[1] end
C_CVar.SetCVar = function(n, v) if CVARS[n] then CVARS[n][1] = tostring(v) return true end return false end

C_XMLUtil.GetTemplates = function() return { { name = "UIPanelButtonTemplate", type = "Button" },
    { name = "SecureActionButtonTemplate", type = "Button" } } end
C_XMLUtil.GetTemplateInfo = function(n) return { type = "Button", width = 0, height = 0, keyValues = {},
    sourceLocation = "Interface/AddOns/Mock.xml:1" } end

UnitExists = function(u) return u == "player" or u == "target" end
UnitName = function(u) if u == "player" then return "Mockchar", nil end if u == "target" then return SECRET end end
UnitGUID = function(u) return u == "player" and "Player-1234-0ABCDEF0" or SECRET end
UnitIsPlayer = function(u) return u == "player" end
UnitHealth = function(u) return S.combat and SECRET or 100 end
C_UnitAuras.GetAuraDataByIndex = function(unit, i, filter)
    if S.combat and unit == "target" then error("Auras cannot be accessed when secret while tainted.") end
    if i <= 2 then return { name = "Mock Aura", spellId = 1459 + i, duration = S.combat and SECRET or 3600 } end
end
C_TooltipInfo.GetItemByID = function(id) return { type = 0, id = id, lines = { { leftText = "Hearthstone", type = 0,
    leftColor = { r = 1, g = 1, b = 1, GetRGB = function() end } } } } end
C_TooltipInfo.GetUnit = function(u) return { type = 2, guid = UnitGUID(u), lines = { { leftText = (u == "player") and "Mockchar" or SECRET } } } end
C_Secrets.ShouldAurasBeSecret = function() return S.combat end

C_Map.GetMapChildrenInfo = function() return { { mapID = 1414, name = "Kalimdor", mapType = 2 } } end
C_Map.GetMapInfo = function(id) return { mapID = id, name = "Map" .. id } end
GetNumClasses = function() return 1 end
GetClassInfo = function() return "Warrior", "WARRIOR", 1 end
GetNumBindings = function() return 1 end
GetBinding = function() return "MOVEFORWARD", "BINDING_HEADER_MOVEMENT", "W", "UP" end

------------------------------------------------------------------ Blizzard EventRegistry (real source when available)
-- Loads Blizzard_SharedXMLBase/CallbackRegistry.lua + GlobalCallbackRegistry.lua from the Gethe forever branch (ref/)
-- so the recorder is tested against Blizzard's real CallbackRegistryMixin (secureexecuterange/securecallfunction
-- dispatch, owner/function callback tables, deferred callbacks). Falls back to a minimal stub.
Mixin = Mixin or function(object, ...)
    for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do object[k] = v end end
    return object
end
CreateFromMixins = CreateFromMixins or function(...) return Mixin({}, ...) end
tInvert = tInvert or function(t) local o = {} for k, v in pairs(t) do o[v] = k end return o end
EnumUtil = EnumUtil or { MakeEnum = function(...) return tInvert({ ... }) end }
CreateCounter = CreateCounter or function(n) n = n or 0 return function() n = n + 1 return n end end
GetOrCreateTableEntry = GetOrCreateTableEntry or function(t, k) local v = t[k] if v == nil then v = {} t[k] = v end return v end
GenerateClosure = GenerateClosure or function(f, ...) local a = { n = select("#", ...), ... }
    return function(...) local b = { unpack(a, 1, a.n) } local n = a.n
        for i = 1, select("#", ...) do b[n + i] = (select(i, ...)) end return f(unpack(b, 1, n + select("#", ...))) end end
-- secure dispatch helpers: errors go to the error handler and do not propagate (like the client)
securecallfunction = securecallfunction or function(fn, ...)
    local r = { pcall(fn, ...) }
    if not r[1] then geterrorhandler()(r[2]) return end
    return unpack(r, 2, table.maxn(r))
end
secureexecuterange = secureexecuterange or function(tbl, fn, ...)
    local keys = {}
    for k in pairs(tbl) do keys[#keys + 1] = k end
    for _, k in ipairs(keys) do
        local ok, err = pcall(fn, k, tbl[k], ...)
        if not ok then geterrorhandler()(err) end
    end
end
local refBase = os.getenv("FORE_SHAREDXML") or "ref/wusf/Interface/AddOns/Blizzard_SharedXMLBase"
local function tryLoad(path)
    local f = io.open(path, "r")
    if not f then return false end
    f:close()
    local chunk = assert(loadfile(path))
    chunk()
    return true
end
M.realEventRegistry = tryLoad(refBase .. "/CallbackRegistry.lua") and tryLoad(refBase .. "/GlobalCallbackRegistry.lua")
if not M.realEventRegistry then
    CallbackRegistryMixin = { TriggerEvent = function() end, RegisterCallback = function() end, UnregisterCallback = function() end }
    EventRegistry = CreateFromMixins(CallbackRegistryMixin)
end
------------------------------------------------------------------ errors, combat log, profiler
local errorHandler = function(msg) S.errorsShown = (S.errorsShown or 0) + 1 end
geterrorhandler = function() return errorHandler end
seterrorhandler = function(f) assert(type(f) == "function", "seterrorhandler needs a function") errorHandler = f end
debugstack = function() return "Interface/AddOns/Buggy/Buggy.lua:12: in function <Interface/AddOns/Buggy/Buggy.lua:10>\n[C]: ?" end
debuglocals = function() return "self = <table> {}\nx = 1" end
function M.raiseError(msg) return errorHandler(msg) end -- what the client does when a script errors

S.cleu = nil
CombatLogGetCurrentEventInfo = function() if S.cleu then return unpack(S.cleu, 1, S.cleu.n) end end
function M.setCLEU(...) S.cleu = { n = select("#", ...), ... } end
function M.fireCLEU(...) M.setCLEU(...) M.fire("COMBAT_LOG_EVENT_UNFILTERED") S.cleu = nil end
S.logging, S.chatLogging, S.protectedCalls = false, false, 0
-- Forever: unverified whether these are protected for addons. The mock treats addon calls as "protected"
-- (counted; on a real client that would be ADDON_ACTION_BLOCKED/FORBIDDEN + popup) unless S.secureCall is set.
local function protectedCall(name) if not S.secureCall then S.protectedCalls = S.protectedCalls + 1 S.lastProtected = name end end
LoggingCombat = function(on) protectedCall("LoggingCombat") if on ~= nil then S.logging = on and true or false end return S.logging end
LoggingChat = function(on) protectedCall("LoggingChat") if on ~= nil then S.chatLogging = on and true or false end return S.chatLogging end
C_ChatInfo.IsLoggingCombat = function() return S.logging, M.CVARS.advancedCombatLogging[1] == "1" end
C_ChatInfo.IsLoggingChat = function() return S.chatLogging end
-- Blizzard's secure slash handlers (Forever SlashCommands.lua: toggles + system message)
local function secure(f) S.secureCall = true local r = f() S.secureCall = false return r end
SlashCmdList.COMBATLOG = function()
    secure(function() if LoggingCombat() then LoggingCombat(false) else LoggingCombat(true) end end)
    M.chat[#M.chat + 1] = S.logging and "Combat being logged to Logs/WoWCombatLog" or "Combat logging disabled"
    M.fire("CHAT_MSG_SYSTEM", M.chat[#M.chat], "")   -- the real client prints COMBATLOGENABLED/DISABLED as a system message
end
SlashCmdList.CHATLOG = function()
    secure(function() if LoggingChat() then LoggingChat(false) else LoggingChat(true) end end)
    M.chat[#M.chat + 1] = S.chatLogging and "Chat being logged to Logs/WoWChatLog.txt" or "Chat logging disabled"
    M.fire("CHAT_MSG_SYSTEM", M.chat[#M.chat], "")
end
-- macros (account-wide only in this mock)
S.macros, S.macroSlotsUsed = {}, 3
GetNumMacros = function() return S.macroSlotsUsed + #S.macros, 0 end
GetMacroIndexByName = function(name) for i, m in ipairs(S.macros) do if m.name == name then return i end end return 0 end
CreateMacro = function(name, icon, body, perChar)
    if S.combat then error("Cannot create macros in combat") end
    assert(#body <= 255, "macro body too long")
    S.macros[#S.macros + 1] = { name = name, icon = icon, body = body, perChar = perChar }
    return #S.macros
end
EditMacro = function(i, name, icon, body)
    if S.combat then error("Cannot edit macros in combat") end
    assert(#body <= 255, "macro body too long")
    S.macros[i] = { name = name, icon = icon, body = body }
    return i
end
-- a human clicking the macro: run each line through the slash dispatcher
function M.clickMacro(name)
    local m = S.macros[GetMacroIndexByName(name)]
    assert(m, "no macro " .. name)
    for line in m.body:gmatch("[^\n]+") do
        local cmd, rest = line:match("^/(%S+)%s*(.*)$")
        cmd = cmd:lower()
        if cmd == "fdump" then SlashCmdList.FOREVERDUMP(rest)
        elseif cmd == "stopmacro" then
            assert(rest == "[combat]", "unexpected /stopmacro condition " .. rest)
            if S.combat then S.stoppedMacros = (S.stoppedMacros or 0) + 1 return "stopped" end
        elseif cmd == "combatlog" then SlashCmdList.COMBATLOG(rest)
        elseif cmd == "chatlog" then SlashCmdList.CHATLOG(rest)
        elseif cmd == "reload" then S.reloadRequested = true return "reload"
        else error("unexpected macro line " .. line) end
    end
end
-- the toc's SavedVariables (v2.2.7: ForeverDumpDocsDB / ForeverDumpStringsDB are runtime aliases into ForeverDumpStaticDB)
M.SV_NAMES = {}
do
    local toc = io.open((os.getenv("FD_ADDON_DIR") or "ForeverDump") .. "/ForeverDump.toc")
    if toc then
        for line in toc:lines() do
            local list = line:match("^## SavedVariables:%s*(.-)%s*$")
            if list then for n in list:gmatch("[%w_]+") do M.SV_NAMES[#M.SV_NAMES + 1] = n end end
        end
        toc:close()
    end
    if #M.SV_NAMES == 0 then
        M.SV_NAMES = { "ForeverDumpDB", "ForeverDumpStaticDB", "ForeverDumpRecordDB", "ForeverDumpLogDB", "ForeverDumpCombatLogDB" }
    end
end
-- /reload: PLAYER_LOGOUT, write SavedVariables to disk, throw away the Lua state of the addon, read the SV file
-- back (true round trip), load the addon again, ADDON_LOADED + PLAYER_LOGIN. Server/client state (macros, CVars,
-- logging) survives, like on the real client.
function M.reload(dir, files, name, svPath)
    M.fire("PLAYER_LOGOUT")
    svPath = svPath or os.tmpname()
    M.writeSavedVariables(svPath, M.SV_NAMES)
    S.frames, S.timers, S.onUpdate = {}, {}, {}
    errorHandler = function(msg) S.errorsShown = (S.errorsShown or 0) + 1 end
    SlashCmdList.FOREVERDUMP = nil
    for _, n in ipairs(M.SV_NAMES) do _G[n] = nil end
    _G.ForeverDumpFrame = nil
    assert(loadfile(svPath))()
    S.reloadRequested, S.reloads = false, (S.reloads or 0) + 1
    local ns = M.loadAddon(dir, files, name)
    M.fire("ADDON_LOADED", name)
    M.fire("PLAYER_LOGIN")
    return ns
end
C_CombatLog.IsCombatLogRestricted = function() return S.combat end
C_RestrictedActions.GetAddOnRestrictionState = function(t) return (S.combat and t == 0) and 1 or 0 end
S.ctInfo = nil
C_CombatText.GetCurrentEventInfo = function() if S.ctInfo then return unpack(S.ctInfo, 1, S.ctInfo.n) end end
C_SwingTimer.IsTargetWithinSwingRange = function(t) return t ~= 2 end
C_DamageMeter.IsDamageMeterAvailable = function() return true, "" end
C_DamageMeter.GetAvailableCombatSessions = function() return { { sessionID = 1, name = "Current", durationSeconds = 10 } } end
C_DamageMeter.GetSessionDurationSeconds = function() return S.combat and SECRET or 10 end
C_DamageMeter.GetCombatSessionFromType = function(st, t)
    if S.combat then return SECRET end  -- SecretWhenInCombat
    return { totalAmount = 1234 + t, maxAmount = 1234, durationSeconds = 10,
        combatSources = { { name = "Mockchar", totalAmount = 1234 + t, classFilename = "MAGE", isLocalPlayer = true, sourceGUID = "Player-1-0000ABCD" },
            { name = "Partymate", totalAmount = 100, classFilename = "WARRIOR", isLocalPlayer = false, sourceGUID = "Player-1-0000BEEF" } } }
end
C_DamageMeter.GetCombatSessionSourceFromType = function(st, t, guid)
    if S.combat then return SECRET end
    return { totalAmount = 1234 + t, combatSpells = { { spellID = 8056, totalAmount = 500, amountPerSecond = 50, overkillAmount = 7,
        combatSpellDetails = { { unitName = "Mob", amount = 500, isMob = true } } }, { spellID = 17364, totalAmount = 734 + t } } }
end
C_AddOnProfiler.IsEnabled = function() return true end
C_AddOnProfiler.GetAddOnMetric = function(name, m) return 0.25 * (m + 1) end
C_AddOnProfiler.GetOverallMetric = function(m) return 1.5 end
C_AddOnProfiler.GetApplicationMetric = function(m) return 16.6 end
UpdateAddOnMemoryUsage = function() end
GetAddOnMemoryUsage = function(i) return 123.5 end
UpdateAddOnCPUUsage = function() end
GetAddOnCPUUsage = function(i) return 9.5 end

SettingsPanel = { GetAllCategories = function() return { { GetName = function() return "Mock" end, GetID = function() return 1 end } } end }

------------------------------------------------------------------ driving
function M.loadAddon(dir, files, name)
    local ns = {}
    for _, f in ipairs(files) do
        local chunk = assert(loadfile(dir .. "/" .. f:gsub("\\", "/")))
        chunk(name, ns)
    end
    M.ns = ns
    return ns
end

function M.fire(event, ...)
    for _, f in ipairs(S.frames) do
        local uf = f.__unitFilter and f.__unitFilter[event]
        if (f.__all or (f.__events and f.__events[event])) and f.__scripts and f.__scripts.OnEvent and (not uf or uf[(...)]) then
            f.__scripts.OnEvent(f, event, ...)
        end
    end
end

function M.tick(n)
    for _ = 1, n or 1 do
        S.time = S.time + 0.016
        for f, fn in pairs(S.onUpdate) do
            if f.__scripts and f.__scripts.OnUpdate == fn then fn(f, 0.016) else S.onUpdate[f] = nil end
        end
        local timers = S.timers
        S.timers = {}
        for _, fn in ipairs(timers) do fn() end
    end
end

function M.runUntilIdle(ns, max)
    for i = 1, max or 100000 do
        if not ns.IsBusy() then return i end
        M.tick(1)
    end
    error("jobs did not finish")
end

function M.slash(msg) SlashCmdList.FOREVERDUMP(msg) end

------------------------------------------------------------------ SavedVariables writer (WoW-like format)
local function q(s)
    s = s:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\n", "\\n"):gsub("\r", "\\r")
    s = s:gsub("%c", function(c) return string.format("\\%03d", c:byte()) end)
    return "\"" .. s .. "\""
end
local function num(n)
    if n == math.floor(n) and math.abs(n) < 2^53 then return string.format("%d", n) end
    return string.format("%.14g", n)
end
local PATH = {}
local function write(out, v, indent)
    local t = type(v)
    if t == "string" then out[#out + 1] = q(v)
    elseif t == "number" then out[#out + 1] = num(v)
    elseif t == "boolean" then out[#out + 1] = tostring(v)
    elseif t == "table" then
        out[#out + 1] = "{\n"
        local n = 0
        while v[n + 1] ~= nil do n = n + 1 end
        for i = 1, n do
            out[#out + 1] = string.rep("\t", indent + 1)
            PATH[#PATH+1]=tostring(i) write(out, v[i], indent + 1) PATH[#PATH]=nil
            out[#out + 1] = ", -- [" .. i .. "]\n"
        end
        local keys = {}
        for k in pairs(v) do
            if not (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)) then keys[#keys + 1] = k end
        end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do
            out[#out + 1] = string.rep("\t", indent + 1) .. "[" .. (type(k) == "string" and q(k) or num(k)) .. "] = "
            PATH[#PATH+1]=tostring(k) write(out, v[k], indent + 1) PATH[#PATH]=nil
            out[#out + 1] = ",\n"
        end
        out[#out + 1] = string.rep("\t", indent) .. "}"
    else
        error("cannot save value of type " .. t .. " at " .. table.concat(PATH, "."))
    end
end
function M.writeSavedVariables(path, names)
    local out = {}
    for _, name in ipairs(names) do
        out[#out + 1] = "\n" .. name .. " = "
        if _G[name] == nil then out[#out + 1] = "nil" else write(out, _G[name], 0) end
        out[#out + 1] = "\n"
    end
    local f = assert(io.open(path, "w"))
    f:write(table.concat(out))
    f:close()
end

return M
