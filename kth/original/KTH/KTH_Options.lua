--[=[
K.T.H. (Kill The Healer) - WoW Add-on
Based on H.H.T.D. by John Wellesz (hhtd@2072productions.com)
Midnight adaptation by Scone (sconed42@gmail.com)

-----
    KTH_Options.lua
-----

GUI settings panel for the K.T.H. Midnight nameplate indicator system.
Registers an AceConfig options group that appears as its own panel in the
WoW Interface > AddOns menu, and is also accessible via /kthg.

Settings are persisted in the KTH_NameplateSettings saved variable
(managed by MidnightNameplates.lua). This file reads and writes that
table directly.

--]=]

local ADDON_NAME, T = ...;
local HHTD = T.HHTD;
local HHTD_C = HHTD.Constants;

-- Only load in Midnight mode
if not HHTD_C.MN then return; end

local pairs    = _G.pairs;
local tostring = _G.tostring;
local tonumber = _G.tonumber;
local format   = _G.string.format;

-- ============================================================
-- ICON PRESETS (must mirror MidnightNameplates.lua exactly)
-- ============================================================
local ICON_PRESETS = {
    cross    = { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7", label = "Cross (X)" },
    skull    = { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", label = "Skull" },
    star     = { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", label = "Star" },
    circle   = { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2", label = "Circle" },
    diamond  = { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3", label = "Diamond" },
    triangle = { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4", label = "Triangle" },
    moon     = { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5", label = "Moon" },
    square   = { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6", label = "Square" },
};

-- Build the values table for AceConfig select widgets
local ICON_VALUES = {};
for key, preset in pairs(ICON_PRESETS) do
    ICON_VALUES[key] = preset.label;
end

-- Icon values with a "Default" option for per-class overrides
local ICON_VALUES_WITH_DEFAULT = { [""] = "(Use global default)" };
for key, preset in pairs(ICON_PRESETS) do
    ICON_VALUES_WITH_DEFAULT[key] = preset.label;
end

-- Alert sound values
local ALERT_SOUND_VALUES = {};

-- Healer class display info
local HEALER_CLASS_LIST = {};
local HEALER_CLASS_DISPLAY = {};

-- Populate from MidnightNameplates.lua exports (available after it loads)
local function LoadExports()
    if HHTD.MNP_ALERT_SOUNDS then
        for key, snd in pairs(HHTD.MNP_ALERT_SOUNDS) do
            ALERT_SOUND_VALUES[key] = snd.label;
        end
    else
        ALERT_SOUND_VALUES = {
            raidwarn = "Raid Warning",
            pvpflag  = "PvP Flag",
            readychk = "Ready Check",
            none     = "None (silent)",
        };
    end
    if HHTD.MNP_HEALER_CLASS_LIST then
        HEALER_CLASS_LIST = HHTD.MNP_HEALER_CLASS_LIST;
    else
        HEALER_CLASS_LIST = { "PRIEST", "DRUID", "MONK", "PALADIN", "SHAMAN", "EVOKER" };
    end
    if HHTD.MNP_HEALER_CLASS_DISPLAY then
        HEALER_CLASS_DISPLAY = HHTD.MNP_HEALER_CLASS_DISPLAY;
    else
        HEALER_CLASS_DISPLAY = {
            PRIEST  = { name = "Priest",  r = 1.00, g = 1.00, b = 1.00 },
            DRUID   = { name = "Druid",   r = 1.00, g = 0.49, b = 0.04 },
            MONK    = { name = "Monk",    r = 0.00, g = 1.00, b = 0.59 },
            PALADIN = { name = "Paladin", r = 0.96, g = 0.55, b = 0.73 },
            SHAMAN  = { name = "Shaman",  r = 0.00, g = 0.44, b = 0.87 },
            EVOKER  = { name = "Evoker",  r = 0.20, g = 0.58, b = 0.50 },
        };
    end
end

-- ============================================================
-- Helper: get the live settings table (created by MidnightNameplates.lua)
-- ============================================================
local function GetSettings()
    if type(_G.KTH_NameplateSettings) ~= "table" then
        _G.KTH_NameplateSettings = {
            offsetY       = 10,
            friendIcon    = "cross",
            enemyIcon     = "cross",
            friendColor   = { r = 0.2, g = 1.0, b = 0.2, a = 1.0 },
            enemyColor    = { r = 1.0, g = 0.2, b = 0.2, a = 1.0 },
            indicatorSize = 36,
            showGlow      = true,
            alertEnabled  = true,
            alertSound    = "raidwarn",
            alertFlash    = true,
            alertColor    = { r = 1.0, g = 0.0, b = 0.0, a = 0.6 },
            alertCooldown = 5,
            classOverrides = {},
        };
    end
    -- Ensure sub-tables exist
    if type(_G.KTH_NameplateSettings.alertColor) ~= "table" then
        _G.KTH_NameplateSettings.alertColor = { r = 1.0, g = 0.0, b = 0.0, a = 0.6 };
    end
    if type(_G.KTH_NameplateSettings.classOverrides) ~= "table" then
        _G.KTH_NameplateSettings.classOverrides = {};
    end
    return _G.KTH_NameplateSettings;
end

-- Ensure a class override sub-table exists
local function GetClassOverride(classToken)
    local s = GetSettings();
    if type(s.classOverrides[classToken]) ~= "table" then
        s.classOverrides[classToken] = { icon = nil, colorR = nil, colorG = nil, colorB = nil };
    end
    return s.classOverrides[classToken];
end

-- ============================================================
-- Helper: build per-class override args for a single class
-- ============================================================
local function BuildClassArgs(classToken, orderBase)
    local display = HEALER_CLASS_DISPLAY[classToken] or { name = classToken, r = 0.5, g = 0.5, b = 0.5 };
    local colorHex = format("%02x%02x%02x",
        math.floor(display.r * 255),
        math.floor(display.g * 255),
        math.floor(display.b * 255));

    return {
        type = "group",
        name = "|cff" .. colorHex .. display.name .. "|r",
        order = orderBase,
        inline = true,
        args = {
            classIcon = {
                type = "select",
                name = "Icon Override",
                desc = "Choose a specific icon for " .. display.name .. " healers, or leave as default.",
                values = ICON_VALUES_WITH_DEFAULT,
                order = 1,
                width = "double",
                get = function()
                    local ov = GetClassOverride(classToken);
                    return ov.icon or "";
                end,
                set = function(_, v)
                    local ov = GetClassOverride(classToken);
                    ov.icon = (v ~= "") and v or nil;
                end,
            },
            classColorR = {
                type = "range",
                name = "Red",
                desc = "Override red channel (0 = use global default).",
                min = 0, max = 1, step = 0.01,
                order = 2,
                get = function()
                    local ov = GetClassOverride(classToken);
                    return ov.colorR or 0;
                end,
                set = function(_, v)
                    local ov = GetClassOverride(classToken);
                    ov.colorR = (v > 0) and v or nil;
                end,
            },
            classColorG = {
                type = "range",
                name = "Green",
                desc = "Override green channel (0 = use global default).",
                min = 0, max = 1, step = 0.01,
                order = 3,
                get = function()
                    local ov = GetClassOverride(classToken);
                    return ov.colorG or 0;
                end,
                set = function(_, v)
                    local ov = GetClassOverride(classToken);
                    ov.colorG = (v > 0) and v or nil;
                end,
            },
            classColorB = {
                type = "range",
                name = "Blue",
                desc = "Override blue channel (0 = use global default).",
                min = 0, max = 1, step = 0.01,
                order = 4,
                get = function()
                    local ov = GetClassOverride(classToken);
                    return ov.colorB or 0;
                end,
                set = function(_, v)
                    local ov = GetClassOverride(classToken);
                    ov.colorB = (v > 0) and v or nil;
                end,
            },
            resetClass = {
                type = "execute",
                name = "Reset " .. display.name,
                desc = "Clear all overrides for " .. display.name .. " (revert to global defaults).",
                order = 5,
                func = function()
                    GetSettings().classOverrides[classToken] = { icon = nil, colorR = nil, colorG = nil, colorB = nil };
                    HHTD:Print("|cff00ff00[K.T.H.]|r " .. display.name .. " overrides cleared.");
                end,
            },
        },
    };
end

-- ============================================================
-- OPTIONS TABLE
-- ============================================================
local function GetKTHOptions()
    -- Load exports from MidnightNameplates on first call
    LoadExports();

    -- Build per-class args
    local classArgs = {
        classDesc = {
            type = "description",
            name = "Override the indicator icon and color for specific healer classes.\n"
                 .. "Leave sliders at 0 to use the global enemy/friendly color.\n"
                 .. "Set any color slider above 0 to activate the override.\n",
            fontSize = "medium",
            order = 0,
        },
    };
    for i, classToken in pairs(HEALER_CLASS_LIST) do
        classArgs[classToken] = BuildClassArgs(classToken, i);
    end

    return {
        type = "group",
        name = "|cff00ff00K.T.H.|r Nameplate Indicators",
        desc = "Configure healer nameplate indicators for Kill The Healer (Midnight mode)",
        childGroups = "tab",
        args = {
            description = {
                type = "description",
                name = "|cff00ff00K.T.H. (Kill The Healer)|r marks healer nameplates in PvP.\n"
                     .. "These settings control the Midnight nameplate indicator appearance.\n"
                     .. "Changes take effect on the next nameplate scan tick (~1 second).\n",
                fontSize = "medium",
                order = 0,
            },
            -- ==================== GENERAL ====================
            general = {
                type = "group",
                name = "General",
                order = 1,
                args = {
                    offsetHeader = {
                        type = "header",
                        name = "Position & Size",
                        order = 1,
                    },
                    offsetY = {
                        type = "range",
                        name = "Vertical Offset (Y)",
                        desc = "Distance in pixels above the nameplate bar.",
                        min = -20, max = 60, step = 1, bigStep = 2,
                        order = 2,
                        width = "double",
                        get = function() return GetSettings().offsetY end,
                        set = function(_, v) GetSettings().offsetY = v end,
                    },
                    indicatorSize = {
                        type = "range",
                        name = "Indicator Size",
                        desc = "Size of the healer indicator icon in pixels.",
                        min = 8, max = 128, step = 1, bigStep = 4,
                        order = 3,
                        width = "double",
                        get = function() return GetSettings().indicatorSize end,
                        set = function(_, v) GetSettings().indicatorSize = v end,
                    },
                    glowHeader = {
                        type = "header",
                        name = "Effects",
                        order = 10,
                    },
                    showGlow = {
                        type = "toggle",
                        name = "Show Glow Halo",
                        desc = "Display a soft glow behind the indicator icon.",
                        order = 11,
                        get = function() return GetSettings().showGlow end,
                        set = function(_, v) GetSettings().showGlow = v end,
                    },
                    debugHeader = {
                        type = "header",
                        name = "Diagnostics",
                        order = 20,
                    },
                    debugEnabled = {
                        type = "toggle",
                        name = "Enable Debug Logging",
                        desc = "Send diagnostic information to the DebugLog addon.",
                        order = 21,
                        width = "double",
                        get = function()
                            return HHTD.MNP_GetDebug and HHTD.MNP_GetDebug() or false;
                        end,
                        set = function(_, v)
                            if HHTD.MNP_SetDebug then HHTD.MNP_SetDebug(v); end
                            if v then
                                HHTD:Print("|cff00ff00[K.T.H.]|r Diagnostics |cff00ff00ON|r.");
                            else
                                HHTD:Print("|cff00ff00[K.T.H.]|r Diagnostics |cffff0000OFF|r.");
                            end
                        end,
                    },
                },
            },
            -- ==================== FRIENDLY ====================
            friendly = {
                type = "group",
                name = "Friendly Healers",
                order = 2,
                args = {
                    friendIconHeader = {
                        type = "header",
                        name = "Friendly Healer Icon",
                        order = 1,
                    },
                    friendIcon = {
                        type = "select",
                        name = "Icon Preset",
                        desc = "Choose the icon displayed above friendly healers.",
                        values = ICON_VALUES,
                        order = 2,
                        width = "double",
                        get = function() return GetSettings().friendIcon end,
                        set = function(_, v) GetSettings().friendIcon = v end,
                    },
                    friendColorHeader = {
                        type = "header",
                        name = "Friendly Indicator Color",
                        order = 10,
                    },
                    friendColorR = {
                        type = "range", name = "Red",
                        min = 0, max = 1, step = 0.01, order = 11,
                        get = function() return GetSettings().friendColor.r end,
                        set = function(_, v) GetSettings().friendColor.r = v end,
                    },
                    friendColorG = {
                        type = "range", name = "Green",
                        min = 0, max = 1, step = 0.01, order = 12,
                        get = function() return GetSettings().friendColor.g end,
                        set = function(_, v) GetSettings().friendColor.g = v end,
                    },
                    friendColorB = {
                        type = "range", name = "Blue",
                        min = 0, max = 1, step = 0.01, order = 13,
                        get = function() return GetSettings().friendColor.b end,
                        set = function(_, v) GetSettings().friendColor.b = v end,
                    },
                    friendColorA = {
                        type = "range", name = "Alpha (Opacity)",
                        min = 0, max = 1, step = 0.01, order = 14,
                        get = function() return GetSettings().friendColor.a end,
                        set = function(_, v) GetSettings().friendColor.a = v end,
                    },
                },
            },
            -- ==================== ENEMY ====================
            enemy = {
                type = "group",
                name = "Enemy Healers",
                order = 3,
                args = {
                    enemyIconHeader = {
                        type = "header",
                        name = "Enemy Healer Icon",
                        order = 1,
                    },
                    enemyIcon = {
                        type = "select",
                        name = "Icon Preset",
                        desc = "Choose the icon displayed above enemy healers.",
                        values = ICON_VALUES,
                        order = 2,
                        width = "double",
                        get = function() return GetSettings().enemyIcon end,
                        set = function(_, v) GetSettings().enemyIcon = v end,
                    },
                    enemyColorHeader = {
                        type = "header",
                        name = "Enemy Indicator Color",
                        order = 10,
                    },
                    enemyColorR = {
                        type = "range", name = "Red",
                        min = 0, max = 1, step = 0.01, order = 11,
                        get = function() return GetSettings().enemyColor.r end,
                        set = function(_, v) GetSettings().enemyColor.r = v end,
                    },
                    enemyColorG = {
                        type = "range", name = "Green",
                        min = 0, max = 1, step = 0.01, order = 12,
                        get = function() return GetSettings().enemyColor.g end,
                        set = function(_, v) GetSettings().enemyColor.g = v end,
                    },
                    enemyColorB = {
                        type = "range", name = "Blue",
                        min = 0, max = 1, step = 0.01, order = 13,
                        get = function() return GetSettings().enemyColor.b end,
                        set = function(_, v) GetSettings().enemyColor.b = v end,
                    },
                    enemyColorA = {
                        type = "range", name = "Alpha (Opacity)",
                        min = 0, max = 1, step = 0.01, order = 14,
                        get = function() return GetSettings().enemyColor.a end,
                        set = function(_, v) GetSettings().enemyColor.a = v end,
                    },
                },
            },
            -- ==================== ALERTS ====================
            alerts = {
                type = "group",
                name = "Alerts",
                order = 4,
                args = {
                    alertDesc = {
                        type = "description",
                        name = "Configure audio and visual alerts when an enemy healer's\n"
                             .. "nameplate first appears on screen.\n",
                        fontSize = "medium",
                        order = 0,
                    },
                    enableHeader = {
                        type = "header",
                        name = "Alert Toggle",
                        order = 1,
                    },
                    alertEnabled = {
                        type = "toggle",
                        name = "Enable Healer Alerts",
                        desc = "Play a sound and/or flash screen edges when an enemy healer appears nearby.",
                        order = 2,
                        width = "double",
                        get = function() return GetSettings().alertEnabled end,
                        set = function(_, v) GetSettings().alertEnabled = v end,
                    },
                    soundHeader = {
                        type = "header",
                        name = "Sound",
                        order = 10,
                    },
                    alertSound = {
                        type = "select",
                        name = "Alert Sound",
                        desc = "Sound to play when an enemy healer appears.",
                        values = ALERT_SOUND_VALUES,
                        order = 11,
                        width = "double",
                        get = function() return GetSettings().alertSound or "raidwarn" end,
                        set = function(_, v) GetSettings().alertSound = v end,
                    },
                    flashHeader = {
                        type = "header",
                        name = "Screen Flash",
                        order = 20,
                    },
                    alertFlash = {
                        type = "toggle",
                        name = "Flash Screen Edges",
                        desc = "Display a colored vignette pulse around screen edges.",
                        order = 21,
                        get = function() return GetSettings().alertFlash end,
                        set = function(_, v) GetSettings().alertFlash = v end,
                    },
                    alertColorR = {
                        type = "range", name = "Flash Red",
                        min = 0, max = 1, step = 0.01, order = 22,
                        get = function() return GetSettings().alertColor.r end,
                        set = function(_, v) GetSettings().alertColor.r = v end,
                    },
                    alertColorG = {
                        type = "range", name = "Flash Green",
                        min = 0, max = 1, step = 0.01, order = 23,
                        get = function() return GetSettings().alertColor.g end,
                        set = function(_, v) GetSettings().alertColor.g = v end,
                    },
                    alertColorB = {
                        type = "range", name = "Flash Blue",
                        min = 0, max = 1, step = 0.01, order = 24,
                        get = function() return GetSettings().alertColor.b end,
                        set = function(_, v) GetSettings().alertColor.b = v end,
                    },
                    alertColorA = {
                        type = "range", name = "Flash Intensity",
                        desc = "How opaque the edge flash is at peak.",
                        min = 0.1, max = 1, step = 0.05, order = 25,
                        get = function() return GetSettings().alertColor.a end,
                        set = function(_, v) GetSettings().alertColor.a = v end,
                    },
                    cooldownHeader = {
                        type = "header",
                        name = "Cooldown",
                        order = 30,
                    },
                    alertCooldown = {
                        type = "range",
                        name = "Alert Cooldown (seconds)",
                        desc = "Minimum seconds between alerts to prevent spam.",
                        min = 1, max = 30, step = 1, bigStep = 1,
                        order = 31,
                        width = "double",
                        get = function() return GetSettings().alertCooldown or 5 end,
                        set = function(_, v) GetSettings().alertCooldown = v end,
                    },
                    testHeader = {
                        type = "header",
                        name = "Preview",
                        order = 40,
                    },
                    testAlert = {
                        type = "execute",
                        name = "Test Alert",
                        desc = "Fire a test alert with current settings.",
                        order = 41,
                        func = function()
                            if HHTD.MNP_TestAlert then
                                HHTD.MNP_TestAlert();
                            else
                                HHTD:Print("|cff00ff00[K.T.H.]|r Alert system not loaded.");
                            end
                        end,
                    },
                },
            },
            -- ==================== PER-CLASS ====================
            perClass = {
                type = "group",
                name = "Per-Class",
                order = 5,
                args = classArgs,
            },
            -- ==================== RESET ====================
            resetSection = {
                type = "group",
                name = "Reset",
                order = 10,
                args = {
                    resetAll = {
                        type = "execute",
                        name = "Reset All to Defaults",
                        desc = "Restore all K.T.H. settings to their defaults.",
                        confirm = true,
                        confirmText = "Reset all K.T.H. nameplate settings to defaults?",
                        func = function()
                            _G.KTH_NameplateSettings = nil;
                            HHTD:Print("|cff00ff00[K.T.H.]|r Settings reset to defaults.");
                        end,
                        order = 1,
                    },
                },
            },
        },
    };
end

-- ============================================================
-- REGISTRATION
-- ============================================================
local AceConfig = LibStub("AceConfig-3.0");
local AceConfigDialog = LibStub("AceConfigDialog-3.0");

local KTH_OPTIONS_NAME = "KTH_Nameplates";

AceConfig:RegisterOptionsTable(KTH_OPTIONS_NAME, GetKTHOptions);
AceConfigDialog:AddToBlizOptions(KTH_OPTIONS_NAME, "K.T.H. Nameplates");

-- Slash command to open the GUI directly
SLASH_KTHG1 = "/kthg";
SlashCmdList["KTHG"] = function()
    AceConfigDialog:Open(KTH_OPTIONS_NAME);
end

-- Also update /kth to mention the GUI
local origKTHSlash = SlashCmdList["KTH"];
if origKTHSlash then
    local wrapped = origKTHSlash;
    SlashCmdList["KTH"] = function(msg)
        if (msg or "") == "" then
            wrapped(msg);
            pcall(HHTD.Print, HHTD, "  Type |cffffffff/kthg|r to open the graphical settings panel.");
        else
            wrapped(msg);
        end
    end
end

-- EOF padding (guards against file-sync truncation)
-- DO NOT REMOVE THESE LINES
-- EOF
-- EOF
