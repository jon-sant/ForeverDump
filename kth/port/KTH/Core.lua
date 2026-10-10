--[=[
K.T.H. (Kill The Healer) - WoW Add-on
Based on H.H.T.D. by John Wellesz (hhtd@2072productions.com)
Midnight adaptation by Scone (sconed42@gmail.com)

Original H.H.T.D.: Copyright (c) 2009-2018 by John Wellesz. All rights reserved.
K.T.H. modifications are built on the H.H.T.D. framework for WoW 12.0 (Midnight).

More information: https://www.wowace.com/projects/h-h-t-d

-----
    Core.lua
-----

Main add-on core: initialization, healer registry, scoreboard scanner,
combat-log event processing, option panel registration, and module lifecycle.

--]=]

--========= NAMING Convention ==========
--      VARIABLES AND FUNCTIONS (upvalues excluded)
-- global variable                == _NAME_WORD2 (underscore + full uppercase)
-- semi-global (file locals)      == NAME_WORD2 (full uppercase)
-- locals to closures or members  == NameWord2
-- locals to functions            == nameWord2
--
--      TABLES
--  globals                       == NAME__WORD2
--  locals                        == name_word2
--  members                       == Name_Word2

-- Debug templates
local ERROR     = 1;
local WARNING   = 2;
local INFO      = 3;
local INFO2     = 4;

local UNPACKAGED = "@pro" .. "ject-version@";
local VERSION = "1.0.0-kth";

local ADDON_NAME, T = ...;
local GetAddOnMetadata  = _G.C_AddOns and _G.C_AddOns.GetAddOnMetadata or _G.GetAddOnMetadata;
local GetSpellInfo      = _G.C_Spell and _G.C_Spell.GetSpellName or _G.GetSpellInfo;
local GetSpellName      = _G.C_Spell and _G.C_Spell.GetSpellName or function (spellId) return (GetSpellInfo(spellId)) end;
local canaccessvalue    = _G.canaccessvalue or function(_) return true; end

T._FatalError = function (TheError)

    if not StaticPopupDialogs["HHTD_ERROR_FRAME"] then
        StaticPopupDialogs["HHTD_ERROR_FRAME"] = {
            text = "|cFFFF0000KTH Fatal Error:|r\n\n%s",
            button1 = "OK",
            OnAccept = function()
                T._FatalError_Diaplayed = false;
                return false;
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
            showAlert = 1,
            preferredIndex = 3,
        };
    end

    if not T._FatalError_Diaplayed then
        StaticPopup_Show ("HHTD_ERROR_FRAME", TheError);
        if T._DiagStatus then
            T._FatalError_Diaplayed = true;
        end
    end
end

T._MessageBox = function (message)

    if not StaticPopupDialogs["HHTD_MESSAGE_FRAME"] then
        StaticPopupDialogs["HHTD_MESSAGE_FRAME"] = {
            text = "|cFFFF1020K.T.H. Message|r\n\n%s",
            button1 = "OK",
            OnAccept = function()
                T._MessageBox_Diaplayed = false;
                return false;
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 0,
            showAlert = true,
            preferredIndex = 3,
        };
    end

    if not T._MessageBox_Diaplayed then
        StaticPopup_Show ("HHTD_MESSAGE_FRAME", message);

    end
end

local _, _, _, tocversion = GetBuildInfo();
T._tocversion = tocversion;

-- === Add-on basics and variable declarations {{{
T.HHTD = LibStub("AceAddon-3.0"):NewAddon("K.T.H.", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0");
local HHTD = T.HHTD;

--[==[@debug@
_HHTD_DEBUG = HHTD;
--@end-debug@]==]

HHTD.Localized_Text = LibStub("AceLocale-3.0"):GetLocale("H.H.T.D.", true);

local L = HHTD.Localized_Text;

HHTD.Constants = {};
local HHTD_C = HHTD.Constants;
HHTD_C.WOWC = WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE
HHTD_C.MN = tocversion >= 120000
-- [Forever] D2: WoW Forever (toc 16001, WOW_PROJECT_ID 18) has Midnight-style secrets. Baseline diag: MN=false sent K.T.H.
-- down the classic branch, whose RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") raised ADDON_ACTION_FORBIDDEN
-- (AceEvent30Frame:RegisterEvent) and the "blocked from an action only available to the Blizzard UI" popup;
-- CombatLogGetCurrentEventInfo and C_CombatLogInternal are both absent. So Forever takes the Midnight path.
HHTD_C.FOREVER = T.FS and T.FS.IS_FOREVER or false
if HHTD_C.FOREVER then HHTD_C.MN = true end

-- === DebugLog routing helper ===
-- All diagnostic output from Core.lua goes here instead of HHTD:Print().
-- This ensures ONLY the KTH login banner prints to chat.
local function CoreDL(msg, severity)
    if _G.DLAPI then
        local prefix = (severity or "OK") .. "~CORE~";
        pcall(_G.DLAPI.DebugLog, "KTH", prefix .. (msg or ""));
    end
end

-- === Midnight Diagnostic Counters ===
HHTD.MN_Diag = {
    cleuIntFired        = 0,  -- COMBAT_LOG_EVENT_INTERNAL_UNFILTERED fired
    cleuIntGotData      = 0,  -- C_CombatLogInternal.GetCurrentEventInfo returned data
    cleuIntSecretEvent  = 0,  -- event was a secret value
    cleuIntSecretGUID   = 0,  -- sourceGUID was a secret value
    cleuIntSecretFlags  = 0,  -- flags were secret values
    cleuIntSecretSpell  = 0,  -- spellNAME was a secret value
    cleuIntHealEvent    = 0,  -- _HEAL event detected
    cleuIntNoSource     = 0,  -- no sourceGUID / hidden caster
    cleuIntBadTarget    = 0,  -- bad target flags
    cleuIntNotPlayer    = 0,  -- source not player/NPC
    cleuIntRegistered   = 0,  -- healer registered via CLEU internal
    spellcastFired      = 0,  -- UNIT_SPELLCAST_SUCCEEDED/START fired
    spellcastSecretID   = 0,  -- spellID was a secret value
    spellcastNotHealer  = 0,  -- spell not in healer-specific list
    spellcastSecretGUID = 0,  -- GUID was secret
    spellcastRegistered = 0,  -- healer registered via spellcast
    scoreboardPlayers   = 0,  -- players found on scoreboard
    scoreboardScans     = 0,  -- successful scoreboard scans
    scoreboardRegistered = 0, -- healers registered via scoreboard
    lastEvent           = "",  -- last combat log event type seen
    lastSpell           = "",  -- last spell seen in spellcast handler
    diagEnabled         = false, -- whether chat spam is active (toggle with /kthdebug)
};
local MN_Diag = HHTD.MN_Diag;

-- === Midnight Independent Healer List ===
-- Simple healer tracking that bypasses the complex Registry/Reaper system.
-- Populated directly by the scoreboard scanner, read by MidnightNameplates.
-- MN_HealersByName: Key = short name (no realm), Value = healer record
-- MN_HealersByGUID: Key = real GUID (when accessible), Value = healer record
-- MN_HealersByClassSpec: Key = "CLASS:Spec" (e.g. "PALADIN:Holy"), Value = healer record
-- Each record: { isFriend, spec, fullName, classToken, talentSpec, guid }
HHTD.MN_HealersByName = {};
HHTD.MN_HealersByGUID = {};
HHTD.MN_HealersByClassSpec = {};
HHTD.MN_HealerCount = { enemy = 0, friendly = 0 };

--[=[
HHTD_C.Healing_Classes = { -- unused
    ["PRIEST"]  = true,
    ["PALADIN"] = true,
    ["DRUID"]   = true,
    ["SHAMAN"]  = true,
    ["MONK"]    = true,
};
--]=]

HHTD_C.MaxTOC = tonumber(GetAddOnMetadata("HHTD", "X-Max-Interface") or math.huge);

-- Build translation table for classes spec to role
-- needed because WoW API (GetBattlefieldScore) returns a localized specName
do
    -- /spew _HHTD_DEBUG.Constants.CLASS_SPEC_TO_ROLE
    HHTD_C.CLASS_SPEC_TO_ROLE = {}

    local classInfo, classTag, userSpecNum, specID, specName, role
    local foundClass = 0;
    local classID = 0;
    while foundClass < MAX_CLASSES do -- in WOWC class ids are not continuous
        classID = classID + 1;
        classInfo = C_CreatureInfo.GetClassInfo(classID)

        if classInfo then
            classTag = classInfo.classFile
            foundClass = foundClass + 1;

            HHTD_C.CLASS_SPEC_TO_ROLE[classTag] = {}

            if not HHTD_C.WOWC then -- disable for now since WOWC has no easy way to do that... We are back to hardcoded localized values *sigh*
                userSpecNum = 1

                repeat
                    specID, specName = GetSpecializationInfoForClassID(classID, userSpecNum)
                    role = specID and GetSpecializationRoleByID(specID) or nil

                    if role then
                        HHTD_C.CLASS_SPEC_TO_ROLE[classTag][specName] = role
                        userSpecNum = userSpecNum + 1
                    end
                until not role
            end
        end

    end

end


-- The header for HHTD key bindings
BINDING_HEADER_HHTD = "K.T.H.";
BINDING_NAME_HHTDP = L["OPT_POST_ANNOUNCE_ENABLE"];



HHTD.Friendly_Healers_Attacked_by_GUID = {};

HHTD.LOGS = {
    [true] = {}, -- [guid] = healer_log_template
    [false] = {}, -- [guid] = healer_log_template
};

HHTD.DelayedFunctionCallsCount  = 0;
HHTD.DelayedFunctionCalls       = {};

do
    local _, _, _, interface = GetBuildInfo();
    HHTD.MOP = (interface >= 50000);
end

--[=[
local healer_template = {
    guid        = "",
    name        = "unknown",
    isUnique    = true,
    isTrueHeal  = false,
    isHuman     = true,
    healDone    = 0,
    rank        = -1,
    _lastSort    = 0,
};
--]=]

HHTD.Registry_by_GUID = {
    [true] = {}, -- [guid] = healer_template
    [false] = {}, -- [guid] = healer_template
}

HHTD.Registry_by_Name = {
    [true] = {}, -- [name] = healer_template
    [false] = {}, -- [name] = healer_template
}
-- upvalues {{{
local _G                = _G;
local UnitIsPlayer      = _G.UnitIsPlayer;
local UnitIsDead        = _G.UnitIsDead;
local UnitFactionGroup  = _G.UnitFactionGroup;
local UnitGUID          = _G.UnitGUID;
local UnitIsUnit        = _G.UnitIsUnit;
local UnitClass         = _G.UnitClass;
local UnitName          = _G.UnitName;
local UnitInRaid        = _G.UnitInRaid;
local UnitInParty       = _G.UnitInParty;
local UnitSetRole       = _G.UnitSetRole;
local UnitGroupRolesAssigned = _G.UnitGroupRolesAssigned;
local GetTime           = _G.GetTime;
local pairs             = _G.pairs;
local ipairs            = _G.ipairs;
local unpack            = _G.unpack;
local select            = _G.select;
local InCombatLockdown  = _G.InCombatLockdown;
local UnitIsFriend      = _G.UnitIsFriend;
-- }}}

function HHTD:HHTD_HEALER_GONE(selfevent, isFriend, healer)

    self.Friendly_Healers_Attacked_by_GUID[healer.guid] = nil;
    self.Registry_by_GUID[isFriend][healer.guid]        = nil;
    self.Registry_by_Name[isFriend][healer.name]        = nil;

    -- test if there are others with the same name... *sigh* this sucks
    for guid, healerRecord in pairs (self.Registry_by_GUID[isFriend]) do

        if healerRecord.name == healer.name then
            self.Registry_by_Name[isFriend][healer.name] = healerRecord;

            self:Debug(INFO, "replaced record for", healer.name);

            break;
        end

    end

end



function HHTD:HHTD_HEALER_BORN(selfevent, isFriend, healer)

    self:Debug(INFO, "HHTD:HHTD_HEALER_BORN()");

    local ok, err = pcall(function()
        HHTD.Registry_by_GUID[isFriend][healer.guid] = healer;
        HHTD.Registry_by_Name[isFriend][healer.name] = healer;
    end)
    if not ok then
        CoreDL("[BORN-ERROR] Registry assignment failed: " .. tostring(err), "ERR");
    elseif HHTD.MN_Diag and HHTD.MN_Diag.diagEnabled and (HHTD.MN_Diag.healerBornCount or 0) <= 30 then
        -- Verify it actually stuck (only show first batch to reduce spam)
        local check = HHTD.Registry_by_GUID[isFriend] and HHTD.Registry_by_GUID[isFriend][healer.guid];
        CoreDL("[BORN-REG] " .. tostring(healer.name) .. " in Registry[" .. tostring(isFriend) .. "]: " .. tostring(check and "YES" or "NO"));
    end

    --[=[@alpha@
    if InCombatLockdown() then
        self:AddDelayedFunctionCall('test', self.Debug, self, INFO2, "After combat lock down test");
    end
    --@end-alpha@]=]

    -- if the player is human and friendly and is part of our group, set his/her role to HEALER
    if self.db.global.SetFriendlyHealersRole and not HHTD_C.WOWC then

        if isFriend and healer.isHuman and (UnitInRaid(healer.fullName) or UnitInParty(healer.fullName)) and UnitGroupRolesAssigned(healer.fullName) == 'NONE' then
            if (select(2, GetRaidRosterInfo(UnitInRaid("player") or 1))) > 0 then
                self:Debug(INFO, "Setting role to HEALER for", healer.fullName);

                if InCombatLockdown() then
                    self:AddDelayedFunctionCall("SetRole_"..healer.fullName, UnitSetRole, healer.fullName, 'HEALER');
                else
                    UnitSetRole(healer.fullName, 'HEALER'); -- fails in combat, has become protected in 5.2
                end
            end
        end

    end

end


-- local function REGISTER_HEALERS_ONLY_SPELLS_ONCE () -- {{{
local function REGISTER_HEALERS_ONLY_SPELLS_ONCE ()

    if HHTD_C.Healers_Only_Spells_ByName then
        return;
    end

    local Healers_Only_Spells_ByID = {

        -- Priests
        --      Discipline
       -- [047540] = "PRIEST", -- Penance - removed due to strange reports received where this spell is misattributed.
        [109964] = "PRIEST", -- Spirit shell -- not seen in disc
        [033206] = "PRIEST", -- Pain Suppression
        [000527] = "PRIEST", -- Purify
        [081749] = "PRIEST", -- Atonement
        -- [132157] = "PRIEST", -- Holy Nova -- removed in 10.2.5
        --      Holy
        [000596] = "PRIEST", -- Prayer of Healing
        [014914] = "PRIEST", -- Holy Fire
        [002060] = "PRIEST", -- Heal
        [034861] = "PRIEST", -- Circle of Healing
        [064843] = "PRIEST", -- Divine Hymn
        [047788] = "PRIEST", -- Guardian Spirit
        [290112] = "PRIEST", -- Binding Heal
        [077485] = "PRIEST", -- Mastery: Echo of Light -- the passibe ability
        -- [077489] = "PRIEST", -- Echo of Light -- the aura applied by the afformentioned
        -- [000139] = "PRIEST", -- Renew

        -- Druids - Restauration
        --[018562] = "DRUID", -- Swiftmend -- (also available through restoration afinity talent)
        [102342] = "DRUID", -- Ironbark
        [033763] = "DRUID", -- Lifebloom
        [088423] = "DRUID", -- Nature's Cure
        -- [008936] = "DRUID", -- Regrowth -- (also available through restoration afinity talent)
        [033891] = "DRUID", -- Incarnation: Tree of Life
        -- [048438] = "DRUID", -- Wild Growth -- disabled in WoW8: In the feral talents, level 45, you can choose Restoration Affinity, which includes Rejuv, Swiftmend, Wild Growth.
        [000740] = "DRUID", -- Tranquility
        -- [145108] = "DRUID", -- Ysera's Gift -- (also available through restoration afinity talent)
        -- [000774] = "DRUID", -- Rejuvination -- (also available through restoration afinity talent)

        -- Shamans - Restauration
        [061295] = "SHAMAN", -- Riptide
        [077472] = "SHAMAN", -- Healing Wave
        [098008] = "SHAMAN", -- Spirit link totem
        [073920] = "SHAMAN", -- Healing Rain

        -- Paladins - Holy
        [020473] = "PALADIN", -- Holy Shock
        [053563] = "PALADIN", -- Beacon of Light
        [082326] = "PALADIN", -- Holy Light
        [085222] = "PALADIN", -- Light of Dawn

        -- Monks - Mistweaver
--        [115175] = "MONK", -- Soothing Mist
        [115310] = "MONK", -- Revival
        --[116670] = "MONK", -- Vivify all monks have it in WoW8
        [116680] = "MONK", -- Thunder Focus Tea
        [116849] = "MONK", -- Life Cocoon
        -- [119611] = "MONK", -- Renewing mist

        [364343] = "EVOKER", -- Echo (talent)
        [355936] = "EVOKER", -- Dream Breath (talent)
        [363534] = "EVOKER", -- Rewind (talent)
        [373861] = "EVOKER", -- Temporal Anomaly (talent)
        [359816] = "EVOKER", -- Dream Flight (talent)

        --[==[@debug@
        -- test bad spell mitigation
        -- those are not healer specific
        -- [031842] = "PALADIN", -- Avenging Wrath - removed in WOW8
        [019750] = "PALADIN", -- Flash of light
        [002061] = "PRIEST",  -- Flash Heal
        -- [005185] = "DRUID",   -- Healing Touch - removed in WOW8
        --@end-debug@]==]
    };

    if HHTD_C.WOWC then

        Healers_Only_Spells_ByID = {
            -- Druid Restoration
            [18562] = "DRUID",   -- SwiftMend

            -- Priest Holy
            [00724] = "PRIEST", -- Lightwell

            -- Shaman Restoration
           -- [16178] = "SHAMAN", -- Purification --ct removed
            -- [29206] = "SHAMAN", -- Healing way -- mop removed
            [001064] = "SHAMAN", -- Chain Heal
        }

        -- OK, this feature makes no sense in WoW classic...


    end

    HHTD_C.Healers_Only_Spells_ByName = {};
    HHTD_C.Healers_Only_Spells_ByID_Lookup = {}; -- For Midnight UNIT_SPELLCAST detection


    -- /spew _HHTD_DEBUG.Constants.Healers_Only_Spells_ByName
    -- /spew GetSpellName(077485)

    local debug_SpellNumber = 0;
    for spellID, class in pairs(Healers_Only_Spells_ByID) do

        if (GetSpellName(spellID)) then
            HHTD_C.Healers_Only_Spells_ByName[GetSpellName(spellID)] = class;
            HHTD_C.Healers_Only_Spells_ByID_Lookup[spellID] = class;
            debug_SpellNumber = debug_SpellNumber + 1;
        else
            HHTD:Debug(ERROR, "Missing spell (you should check if there is an updated version of HHTD):", spellID);
        end

    end

    HHTD:Debug(INFO, ("%d spells registered!"):format(debug_SpellNumber));
end -- }}}

-- Modules standards configurations {{{

-- Configure default libraries for modules
HHTD:SetDefaultModuleLibraries( "AceConsole-3.0", "AceEvent-3.0")

-- Set the default prototype for modules
HHTD.MODULE_PROTOTYPE   = {
    OnEnable = function(self) self:Debug(INFO, "prototype OnEnable called!") end,

    OnDisable = function(self) self:Debug(INFO, "prototype OnDisable called!") end,

    OnInitialize = function(self)
        self:Debug(INFO, "prototype OnInitialize called!");
    end,

    Debug = function(self, ...) HHTD.Debug(self, ...) end,

    Error = function(self, m) HHTD.Error (self, m) end,

}

HHTD:SetDefaultModulePrototype( HHTD.MODULE_PROTOTYPE )

-- Set modules' default state to "false"
HHTD:SetDefaultModuleState( false )
-- }}}



-- }}}

-- modules handling functions {{{

function HHTD:SetModulesStates ()
    for moduleName, module in self:IterateModules() do
        -- In Midnight mode, disable legacy nameplate modules since MidnightNameplates handles indicators
        if HHTD_C.MN and (moduleName == "NPH" or moduleName == "CM") then
            module:SetEnabledState(false);
            if module.Disable then pcall(module.Disable, module); end
            CoreDL("Disabling legacy module in Midnight mode: " .. moduleName);
        else
            CoreDL("Enabling module: " .. moduleName);
            module:SetEnabledState(self.db.global.Modules[moduleName].Enabled);
        end
    end
end

-- }}}

-- 03 Ghosts I

-- == Options and defaults {{{
do

    local AceOptionAntiStupidity = 0;
    local FormattedLogs = "";

    local function FormatLogs()

        if GetTime() - AceOptionAntiStupidity < 0.1 then
            HHTD:Debug(INFO, "AceOption is stupid");
            return FormattedLogs;
        else
            AceOptionAntiStupidity = GetTime();
        end

        local output        = "";

        for _, isFriend in ipairs({false,true}) do

            local tmp           = {};

            for guid, log in HHTD:pairs_ordered(HHTD.LOGS[isFriend], true, 'healDone') do

                local isActive = HHTD.Registry_by_GUID[isFriend][guid];

                local spellsStats = {}
                local j = 1;

                for spell, spellcount in HHTD:pairs_ordered(log.spells, true) do
                    spellsStats[j] = ("    %s (|cFFAA0000%d|r)"):format(HHTD:ColorText(spell, HHTD_C.Healers_Only_Spells_ByName[spell] and "FFC000C0" or "FFC0C0C0"), spellcount);
                    j = j + 1;
                end

                tmp[#tmp + 1] = ("%s (|cff00dd00%s|r)%s [|cffbbbbbb%s|r]:  %s\n%s\n"):format(
                (HHTD:ColorText("#(%s)|r '%s'", log.isFriend and "FF00FF00" or "FFFF0000")):format(
                    isActive and isActive.rank or '-',
                    HHTD:ColorText(log.name, log.isTrueHeal and HHTD:GetClassHexColor(log.isTrueHeal) or "FFAAAAAA" )
                    ),
                tostring(log.healDone > 0 and log.healDone or L["NO_DATA"]),
                log.healDone > HHTD.HealThreshold and "" or L["LOG_BELOW_THRESHOLD"],
                log.isHuman and L["HUMAN"] or L["NPC"],
                HHTD:ColorText(isActive and L["LOG_ACTIVE"] or L["LOG_IDLE"], isActive and "FF00EE00" or "FFEE0000"),
                table.concat(spellsStats, '\n')
                );

            end

            output = output .. table.concat(tmp, '\n') .. '\n';

        end

        FormattedLogs = output;
        return output;
    end


    local function GetCoreOptions() -- {{{
    return {
        type = 'group',
        get = function (info) return HHTD.db.global[info[#info]]; end,
        set = function (info, value) HHTD:SetHandler(HHTD, info, value) end,
        disabled = function () return not HHTD:IsEnabled(); end,
        childGroups = 'tab',
        name = "K.T.H.",
        args = {
            Description = {
                type = 'description',
                name = L["DESCRIPTION"],
                order = 0,
            },
            On = {
                type = 'toggle',
                name = L["OPT_ON"],
                desc = L["OPT_ON_DESC"],
                set = function(info) HHTD.db.global.Enabled = true; HHTD:Enable(); return HHTD.db.global.Enabled; end,
                get = function(info) return HHTD:IsEnabled(); end,
                hidden = function() return HHTD:IsEnabled(); end,

                disabled = false,
                order = 1,
            },
            Off = {
                type = 'toggle',
                name = L["OPT_OFF"],
                desc = L["OPT_OFF_DESC"],
                set = function(info) HHTD.db.global.Enabled = not HHTD:Disable(); return not HHTD.db.global.Enabled; end,
                get = function(info) return not HHTD:IsEnabled(); end,
                guiHidden = true,
                hidden = function() return not HHTD:IsEnabled(); end,
                order = -1,
            },
            Debug = {
                type = 'toggle',
                name = L["OPT_DEBUG"],
                desc = L["OPT_DEBUG_DESC"],
                guiHidden = true,
                disabled = false,
                order = -2,
            },
            DebugLevel = {
                type = 'range',
                name = L["OPT_DEBUGLEVEL"],
                desc = L["OPT_DEBUGLEVEL_DESC"],
                min = 1,
                max = 3,
                guiHidden = true,
                disabled = false,
                order = -3,
            },

            Version = {
                type = 'execute',
                name = L["OPT_VERSION"],
                desc = L["OPT_VERSION_DESC"],
                guiHidden = true,
                func = function () HHTD:Print(L["VERSION"], '1.0.0-kth,', L["RELEASE_DATE"], '2026-04-04') end,
                order = -5,
            },
            ShowGUI = {
                type = 'execute',
                name = L["OPT_GUI"],
                desc = L["OPT_GUI_DESC"],
                guiHidden = true,
                func = function () LibStub("AceConfigDialog-3.0"):Open(tostring(HHTD)) end,
                order = -6,
            },
            core = {
                type = 'group',
                name =  L["OPT_CORE_OPTIONS"],
                order = 1,
                args = {
                    Info_Header = {
                        type = 'header',
                        name = L["VERSION"] .. ' 1.0.0-kth -- ' .. L["RELEASE_DATE"] .. ' 2026-04-04',
                        order = 1,
                    },
                    Pve = {
                        type = 'toggle',
                        name = L["OPT_PVE"],
                        desc = L["OPT_PVE_DESC"],
                        order = 200,
                    },
                    PvpHSpecsOnly = {
                        type = 'toggle',
                        width = 'double',
                        name = L["OPT_PVPHEALERSSPECSONLY"],
                        desc = L["OPT_PVPHEALERSSPECSONLY_DESC"],
                        disabled = function() return HHTD_C.WOWC end,
                        order = 300,
                    },
                    Log = {
                        type = 'toggle',
                        name = L["OPT_LOG"],
                        desc = L["OPT_LOG_DESC"],
                        disabled = false,
                        order = 350,
                    },
                    ShowChatCommandReminder = {
                        type = 'toggle',
                        name = L["OPT_SHOW_CHAT_COMMAND_REMINDER"],
                        desc = L["OPT_SHOW_CHAT_COMMAND_REMINDER_DESC"],
                        width = 'double',
                        order = 352,
                    },
                    testOnTarget = {
                        type = 'execute',
                        width = 'double',
                        name = L["OPT_TESTONTARGET"],
                        desc = L["OPT_TESTONTARGET_DESC"],
                        func = function ()
                            if (UnitGUID("target")) then
                                HHTD:MakeDummyEvent("target");
                            else
                                HHTD:Print( L["OPT_TESTONTARGET_ENOTARGET"] );
                            end

                        end,
                        order = 355,
                    },
                    Modules = {
                        type = 'group',
                        name = L["OPT_MODULES"],
                        inline = true,
                        handler = {
                            ["hidden"]   = function () return not HHTD:IsEnabled(); end,
                            ["disabled"] = function () return not HHTD:IsEnabled(); end,

                            ["get"] = function (handler, info) return (HHTD:GetModule(info[#info])):IsEnabled(); end,
                            ["set"] = function (handler, info, value)

                                HHTD.db.global.Modules[info[#info]].Enabled = value;
                                local result;

                                if value then
                                    result = HHTD:EnableModule(info[#info]);
                                    if result then
                                        HHTD:Print(info[#info], HHTD:ColorText(L["OPT_ON"], "FF00FF00"));
                                    end
                                else
                                    result = HHTD:DisableModule(info[#info]);
                                    if result then
                                        HHTD:Print(info[#info], HHTD:ColorText(L["OPT_OFF"], "FFFF0000"));
                                    end
                                end

                                return result;
                            end,
                        },
                        -- Enable-modules-check-boxes (filled by modules)
                        args = {},
                        order = 900,
                    },
                    Header1 = {
                        type = 'header',
                        name = "|cFFDD0000"..L["OPT_HEADER_GLOBAL_ENEMY_HEALER_OPTIONS"].."|r",
                        order = 400,
                    },
                    HFT = {
                        type = "range",
                        name = L["OPT_HEALER_FORGET_TIMER"],
                        desc = L["OPT_HEALER_FORGET_TIMER_DESC"],
                        min = 10,
                        max = 60 * 10,
                        step = 1,
                        bigStep = 5,
                        order = 500,
                    },
                    UHMHAP = {
                        type = "toggle",
                        width = 'double',
                        name = L["OPT_USE_HEALER_MINIMUM_HEAL_AMOUNT"],
                        desc = L["OPT_USE_HEALER_MINIMUM_HEAL_AMOUNT_DESC"],
                        order = 600,
                    },
                    HMHAP = {
                        type = "range",
                        width = 'double',
                        disabled = function() return not HHTD.db.global.UHMHAP or not HHTD:IsEnabled(); end,
                        name = function() HHTD:UpdateHealThresholds(); return (L["OPT_HEALER_MINIMUM_HEAL_AMOUNT"]):format(HHTD.HealThreshold) end,
                        desc = L["OPT_HEALER_MINIMUM_HEAL_AMOUNT_DESC"],
                        min = 0.01,
                        max = 6,
                        softMax = 3,
                        step = 0.01,
                        bigStep = 0.03,
                        order = 650,
                        isPercent = true,

                        set = function (info, value)
                            HHTD:SetHandler(HHTD, info, value);
                            HHTD:UpdateHealThresholds();
                        end,
                    },
                    Header2 = {
                        type = 'header',
                        name = "|cFF00DD00"..L["OPT_HEADER_GLOBAL_FRIENDLY_HEALER_OPTIONS"].."|r",
                        order = 655,
                    },
                    SetFriendlyHealersRole = {
                        type = 'toggle',
                        width = 'double',
                        name = L["OPT_SET_FRIENDLY_HEALERS_ROLE"],
                        desc = L["OPT_SET_FRIENDLY_HEALERS_ROLE_DESC"],
                        disabled = function () return HHTD_C.WOWC end,
                        order = 660,
                    },
                    HealerUnderAttackAlerts = {
                        type = 'toggle',
                        name = L["OPT_HEALER_UNDER_ATTACK_ALERTS"],
                        desc = function() HHTD:UpdateHealThresholds(); return (L["OPT_HEALER_UNDER_ATTACK_ALERTS_DESC"]):format(HHTD.ProtectDamageThreshold) end,
                        order = 670,
                    },
                    PHMDAP = {
                        type = "range",
                        width = 'double',
                        disabled = function() return not HHTD.db.global.HealerUnderAttackAlerts or not HHTD:IsEnabled(); end,
                        name = function() HHTD:UpdateHealThresholds(); return (L["OPT_PROTECT_HEALER_MINIMUM_DAMAGE_AMOUNT"]):format(HHTD.ProtectDamageThreshold) end,
                        desc = L["OPT_PROTECT_HEALER_MINIMUM_DAMAGE_AMOUNT_DESC"],
                        min = 0.01,
                        max = 6,
                        softMax = 3,
                        step = 0.01,
                        bigStep = 0.03,
                        order = 675,
                        isPercent = true,

                        set = function (info, value)
                            HHTD:SetHandler(HHTD, info, value);
                            HHTD:UpdateHealThresholds();
                        end,
                    },
                    Header1000 = {
                        type = 'header',
                        name = '',
                        order = 999,
                    },
                },
            },
            Logs = {
                type = 'group',
                name =  L["OPT_LOGS"],
                desc = L["OPT_LOGS_DESC"],
                order = -1,
                hidden = function() return not HHTD.db.global.Log end,
                args = {
                    clear = {
                        type = 'execute',
                        name = L["OPT_CLEAR_LOGS"],
                        confirm = true,
                        func = function ()
                            HHTD.LOGS[true]  = {};
                            HHTD.LOGS[false] = {};
                        end,
                        order = 0,

                    },
                    AccusationFacts = { -- {{{
                        type = 'description',
                        name = FormatLogs,
                        order = 1,
                    }, -- }}}
                },
            },
        },
    };
    end -- }}}

    -- Used in Ace3 option table to get feedback when setting options through command line
    function HHTD:SetHandler (module, info, value)

        module.db.global[info[#info]] = value;

        if info["uiType"] == "cmd" then

            if value == true then
                value = L["OPT_ON"];
            elseif value == false then
                value = L["OPT_OFF"];
            end

            self:Print(HHTD:ColorText(HHTD:GetOPtionPath(info), "FF00DD00"), "=>", HHTD:ColorText(value, "FF3399EE"));
        end
    end


    local Enable_Module_CheckBox = {
        type = 'toggle',
        name = function (info) return L[info[#info]] end, -- it should be the localized module name
        desc = function (info) return L[info[#info] .. "_DESC"] end,
        get = "get",
        set = "set",
        disabled = "disabled",
    };

    -- get the option tables feeding it with the core options and adding modules options
    function HHTD.GetOptions()
        local options = GetCoreOptions();

        -- Add modules enable/disable checkboxes
        for moduleName, module in HHTD:IterateModules() do
            if not options.args.core.args.Modules.args[moduleName] then
                options.args.core.args.Modules.args[moduleName] = Enable_Module_CheckBox;
            else
                error("HHTD: module name collision!");
            end
            -- Add modules specific options
            if module.GetOptions then
                if module:IsEnabled() then
                    if not options.plugins then options.plugins = {} end;
                    options.plugins[moduleName] = module:GetOptions();
                end
            end
        end

        return options;
    end
end


local DEFAULT__CONFIGURATION = {
    global = {
        Modules = {
            ['**'] = {
                Enabled = true, -- Modules are enabled by default
            },
        },
        HFT = 60,
        Enabled = true,
        Debug = false,
        DebugLevel = 1,
        --[=[@alpha@
        Debug = true,
        DebugLevel = 2,
        --@end-alpha@]=]
        Log = false,
        Pve = true,
        PvpHSpecsOnly = false,
        UHMHAP = true,
        HMHAP = 0.5,
        PHMDAP = 0.20,
        SetFriendlyHealersRole = (not HHTD_C.WOWC) and true or false,
        HealerUnderAttackAlerts = true,
        ShowChatCommandReminder = true,
    },
};
-- }}}

-- = Add-on Management functions {{{
do

    function HHTD:OnInitialize()
        -- Catch people updating add-ons while WoW is running before they post "it doesn't work!!!!" comments.
        local versionInTOC = GetAddOnMetadata("HHTD", "Version");
        if versionInTOC and versionInTOC ~= VERSION and versionInTOC ~= UNPACKAGED and VERSION ~= UNPACKAGED then
            T._DiagStatus = 2;
            T._Diagmessage = "You have updated H.H.T.D while WoW was still running in the background.\n\nYou need to restart WoW completely or you might experience various issues with your add-ons until you do.";
            T._FatalError(T._Diagmessage);
        end


        self.db = LibStub("AceDB-3.0"):New("HHTD_SavedVariables", DEFAULT__CONFIGURATION);

        if HHTD_C.FOREVER then
            -- [Forever] D3: AceConfigCmd answers /hhtd by printing into DEFAULT_CHAT_FRAME; open the options window instead
            LibStub("AceConfig-3.0"):RegisterOptionsTable(tostring(self), self.GetOptions);
            self:RegisterChatCommand('hhtd', function() LibStub("AceConfigDialog-3.0"):Open(tostring(self)) end, true);
        else
            LibStub("AceConfig-3.0"):RegisterOptionsTable(tostring(self), self.GetOptions, {"hhtd", "H.H.T.D."});
        end
        --LibStub("AceConfigDialog-3.0"):AddToBlizOptions(tostring(self));
        self:RegisterChatCommand('hhtdg', function() LibStub("AceConfigDialog-3.0"):Open(tostring(self)) end, true);
        self:RegisterChatCommand('hhtddiag', function()
            local d = HHTD.MN_Diag;
            CoreDL("=== HHTD Midnight Diagnostics ===");
            CoreDL("--- CLEU Internal ---");
            CoreDL("  Fired:" .. d.cleuIntFired .. " GotData:" .. d.cleuIntGotData .. " HealEvents:" .. d.cleuIntHealEvent);
            CoreDL("  SecretEvent:" .. d.cleuIntSecretEvent .. " SecretGUID:" .. d.cleuIntSecretGUID .. " SecretFlags:" .. d.cleuIntSecretFlags .. " SecretSpell:" .. d.cleuIntSecretSpell);
            CoreDL("  NoSource:" .. d.cleuIntNoSource .. " BadTarget:" .. d.cleuIntBadTarget .. " NotPlayer:" .. d.cleuIntNotPlayer);
            CoreDL("  Registered healers: " .. d.cleuIntRegistered);
            CoreDL("--- Spellcast Detection ---");
            CoreDL("  Fired:" .. d.spellcastFired .. " SecretID:" .. d.spellcastSecretID .. " NotHealer:" .. d.spellcastNotHealer .. " SecretGUID:" .. d.spellcastSecretGUID);
            CoreDL("  Registered healers: " .. d.spellcastRegistered);
            CoreDL("--- Scoreboard Detection ---");
            CoreDL("  Players:" .. d.scoreboardPlayers .. " Scans:" .. d.scoreboardScans .. " Registered:" .. d.scoreboardRegistered);
            CoreDL("--- Last Seen ---");
            CoreDL("  Event:" .. tostring(d.lastEvent) .. " Spell:" .. tostring(d.lastSpell));
            local enemyCount, friendCount = 0, 0;
            if HHTD.Registry_by_GUID then
                if HHTD.Registry_by_GUID[false] then for _ in pairs(HHTD.Registry_by_GUID[false]) do enemyCount = enemyCount + 1 end end
                if HHTD.Registry_by_GUID[true] then for _ in pairs(HHTD.Registry_by_GUID[true]) do friendCount = friendCount + 1 end end
            end
            CoreDL("--- Public Registry ---");
            CoreDL("  Enemy healers:" .. enemyCount .. " Friendly healers:" .. friendCount);
            CoreDL("  HEALER_BORN dispatched:" .. (d.healerBornCount or 0));
            CoreDL("  diagEnabled:" .. tostring(d.diagEnabled));
            CoreDL("=== End Diagnostics ===");
            HHTD:Print("|cff00ff00[K.T.H.]|r Diagnostic dump sent to DebugLog. Type |cffffffff/dl|r to view.");
        end, true);
        self:RegisterChatCommand('hhtdv', function()
            HHTD.MN_Diag.diagEnabled = not HHTD.MN_Diag.diagEnabled;
            CoreDL("Verbose diag: " .. (HHTD.MN_Diag.diagEnabled and "ON" or "OFF"));
            HHTD:Print("|cff00ff00[K.T.H.]|r Verbose diag: " .. (HHTD.MN_Diag.diagEnabled and "|cff00ff00ON" or "|cffff0000OFF") .. "|r — output to DebugLog.");
        end, true);
        self:RegisterChatCommand('hhtdreset', function()
            for k, v in pairs(HHTD.MN_Diag) do
                if type(v) == "number" then HHTD.MN_Diag[k] = 0 end
                if type(v) == "string" then HHTD.MN_Diag[k] = "" end
            end
            HHTD:Print("|cff00ff00[K.T.H.]|r Diag counters reset.");
        end, true);
        -- Auto-repeating diag: /hhtdauto to toggle sending diag every 10 seconds to DebugLog
        local autoDiagTimer = nil;
        self:RegisterChatCommand('hhtdauto', function()
            if autoDiagTimer then
                HHTD:CancelTimer(autoDiagTimer);
                autoDiagTimer = nil;
                HHTD:Print("|cff00ff00[K.T.H.]|r Auto-diag: |cffff0000OFF|r");
            else
                autoDiagTimer = HHTD:ScheduleRepeatingTimer(function()
                    local d = HHTD.MN_Diag;
                    local enemyCount, friendCount = 0, 0;
                    if HHTD.Registry_by_GUID then
                        if HHTD.Registry_by_GUID[false] then for _ in pairs(HHTD.Registry_by_GUID[false]) do enemyCount = enemyCount + 1 end end
                        if HHTD.Registry_by_GUID[true] then for _ in pairs(HHTD.Registry_by_GUID[true]) do friendCount = friendCount + 1 end end
                    end
                    local mnpStatus = HHTD.MNP_GetStatus and HHTD.MNP_GetStatus() or "MNP:N/A";
                    local mnHealers = HHTD.MN_HealerCount or { enemy = 0, friendly = 0 };
                    CoreDL("[AUTO] SB:" .. d.scoreboardRegistered
                        .. " MN_List(E:" .. mnHealers.enemy .. " F:" .. mnHealers.friendly .. ")"
                        .. " Pub(E:" .. enemyCount .. " F:" .. friendCount .. ")"
                        .. " " .. mnpStatus);
                end, 10);
                HHTD:Print("|cff00ff00[K.T.H.]|r Auto-diag: |cff00ff00ON|r (every 10s to DebugLog, /hhtdauto to stop)");
            end
        end, true);
        self:CreateClassColorTables();


        self:SetEnabledState(self.db.global.Enabled);


        if HHTD_C.WOWC then
            self.db.global.PvpHSpecsOnly = false;
            self.db.global.SetFriendlyHealersRole = false;
        end
    end

    function HHTD:ADDON_LOADED(selfEvent, addOnName)
    end
end

HHTD_C.PLAYER_FACTION = "";
HHTD_C.PLAYER_GUID    = "";
function HHTD:OnEnable()

    if T._DiagStatus == 2 then
        self:Disable();
        return;
    end

    REGISTER_HEALERS_ONLY_SPELLS_ONCE ();

    if not HHTD_C.MN then
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
    else
        -- In 12.0 (Midnight), CLEU was removed and replaced with the internal combat log system
        if C_CombatLogInternal and C_CombatLogInternal.GetCurrentEventInfo then
            self:RegisterEvent("COMBAT_LOG_EVENT_INTERNAL_UNFILTERED");
            CoreDL("[MN] Registered COMBAT_LOG_EVENT_INTERNAL_UNFILTERED.");
        else
            CoreDL("[MN] C_CombatLogInternal not available! Spellcast detection only.", "WARN");
        end
        -- Register spellcast events as supplementary/fallback healer detection
        self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED");
        self:RegisterEvent("UNIT_SPELLCAST_START");
        CoreDL("[MN] Registered UNIT_SPELLCAST_SUCCEEDED + UNIT_SPELLCAST_START.");
    end

    -- Diagnostic info (to DebugLog only)
    CoreDL("Diag: MN=" .. tostring(HHTD_C.MN)
        .. " C_CLI=" .. tostring(C_CombatLogInternal ~= nil)
        .. " cav=" .. tostring(type(canaccessvalue))
        .. " SpellsByID=" .. tostring(HHTD_C.Healers_Only_Spells_ByID_Lookup ~= nil));

    -- Count spells registered
    local spellCount = 0;
    if HHTD_C.Healers_Only_Spells_ByID_Lookup then
        for _ in pairs(HHTD_C.Healers_Only_Spells_ByID_Lookup) do spellCount = spellCount + 1 end
    end
    local nameCount = 0;
    if HHTD_C.Healers_Only_Spells_ByName then
        for _ in pairs(HHTD_C.Healers_Only_Spells_ByName) do nameCount = nameCount + 1 end
    end
    CoreDL("Diag: Healer spells: " .. spellCount .. " by ID, " .. nameCount .. " by name");

    -- Start the scoreboard scanner for Midnight BGs
    if HHTD_C.MN then
        self:StartScoreboardScanner();
    end
    self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE");
    self:RegisterEvent("UPDATE_MOUSEOVER_UNIT", "TestUnit");
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "TestUnit");
    self:RegisterEvent("PLAYER_ALIVE"); -- talents SHOULD be available
    -- self:RegisterEvent("ADDON_LOADED");
    -- self:RegisterEvent("PARTY_MEMBER_DISABLE"); -- useless event, no argument...

    if not T._DiagStatus and self.db.global.ShowChatCommandReminder then
        CoreDL("HHTD core enabled");
    end

    self:SetModulesStates();

    HHTD_C.PLAYER_FACTION = UnitFactionGroup("player");
    HHTD_C.PLAYER_GUID    = UnitGUID("player");

    self:ScheduleRepeatingTimer(self.Undertaker,           10, self);
    self:ScheduleRepeatingTimer(self.UpdateHealThresholds, 50, self);

end

function HHTD:PLAYER_ALIVE()
    self:Debug(INFO, "PLAYER_ALIVE");

    HHTD_C.PLAYER_FACTION = UnitFactionGroup("player");
    HHTD_C.PLAYER_GUID    = UnitGUID("player");
    HHTD:UpdateHealThresholds();

    self:UnregisterEvent("PLAYER_ALIVE");
end

function HHTD:PARTY_MEMBER_DISABLE(e, unit)
    self:Debug(INFO2, "PARTY_MEMBER_DISABLE:", unit);
end

function HHTD:OnDisable()

    if not T._DiagStatus then
        CoreDL("HHTD core disabled");
    end

    if T._DiagStatus == 2 then
        self:Print("|cFFD00000"..T._Diagmessage.."|r");
    end

end
-- }}}

HHTD.HealThreshold = math.huge;
HHTD.ProtectDamageThreshold = math.huge;
local UnitHealthMax = _G.UnitHealthMax;
function HHTD:UpdateHealThresholds()

    local PlayerMaxH = UnitHealthMax('player')

    self.HealThreshold          = math.ceil(self.db.global.HMHAP  * PlayerMaxH);
    self.ProtectDamageThreshold = math.ceil(self.db.global.PHMDAP * PlayerMaxH);
end


-- MouseOver and Target trigger {{{
do
    local LastDetectedGUID = "";
    function HHTD:TestUnit(eventName) -- XXX to check/rewrite

        local unit="";
        local pve = HHTD.db.global.Pve;

        if eventName=="UPDATE_MOUSEOVER_UNIT" then
            unit = "mouseover";
        elseif eventName=="PLAYER_TARGET_CHANGED" then
            unit = "target";
        else
            CoreDL("TestUnit called on invalid event: " .. tostring(eventName), "ERR");
            return;
        end

        local unitGuid = UnitGUID(unit);
        local isFriend = UnitIsFriend(unit, 'player')==1 and true or false;

        --self:Debug(INFO, "HHTD:TestUnit()", unitGuid, isFriend);

        if not unitGuid then
            --self:Debug(WARNING, "No unit GUID");
            return;
        end

        local unitFirstName, unitRealm = UnitName(unit);

        -- [Forever] F3: enemy mouseover/target GUIDs are secret (ForeverDump runs 16-18) -> resolve the unit by its
        -- exact scoreboard name to K.T.H.'s record (or the nameplate verdict); see ForeverEvidence.lua
        local healerRecord = canaccessvalue(unitGuid) and HHTD.Registry_by_GUID[isFriend][unitGuid] or nil;
        if not canaccessvalue(unitGuid) and HHTD_C.FOREVER and HHTD.MN_ResolveEnemyUnit then
            local okR, g, rec = pcall(HHTD.MN_ResolveEnemyUnit, unit);
            if okR and g then unitGuid, healerRecord = g, rec; end
        end

        if canaccessvalue(unitGuid) and healerRecord then

            -- remove dead units
            local okD, isDead = pcall(UnitIsDead, unit); -- [Forever] F3: secret-safe truth test
            if okD and canaccessvalue(isDead) and isDead then
                if HHTD.Registry_by_GUID[isFriend][unitGuid] then self:Reap(unitGuid, isFriend, true); end
                return;
            end

            if LastDetectedGUID == unitGuid and unit == "target" then
                self:SendMessage("HHTD_TARGET_LOCKED", isFriend, healerRecord); -- [Forever] F3: resolved record
                --self:Debug(INFO, "LastDetectedGUID == unitGuid and unit == \"target\""); -- XXX

                return;
            end

            -- Has the unit healed recently?
            local okU, sameUnit = pcall(UnitIsUnit, "mouseover", "target"); -- [Forever] F3: secret-safe
            if okU and canaccessvalue(sameUnit) and not sameUnit and unit == "mouseover" then
                -- Is this sitill true?

                self:SendMessage("HHTD_HEALER_MOUSE_OVER", isFriend, healerRecord); -- [Forever] F3: resolved record
                --self:Debug(INFO, "HHTD_HEALER_UNDER_MOUSE"); -- XXX
                LastDetectedGUID = unitGuid;
            end
        end

    end
end -- }}}


do

    --up values

    local str_match                   = _G.string.match;
    local GetTime                     = _G.GetTime;
    local RequestBattlefieldScoreData = _G.RequestBattlefieldScoreData;

    local pairs                     = _G.pairs;
    local ipairs                    = _G.ipairs;
    local TableWipe                 = _G.table.wipe;
    local TableSort                 = _G.table.sort;

    local WIPRBSD = {false, nil, 0};

    local WOWC_CANT_HEAL_CLASSES = {
        ["MAGE"] = true,
        ["WARRIOR"] = true,
        ["HUNTER"] = true,
        ["ROGUE"] = true,
        ["WARLOCK"] = true,
        ["DEATHKNIGHT"] = true, -- not wowc but still presents in RAID_CLASS_COLORS...
        ["DEMONHUNTER"] = true, -- not wowc but still presents in RAID_CLASS_COLORS...
    };

    function HHTD:UPDATE_BATTLEFIELD_SCORE()
        --[=[@alpha@
        self:Debug(INFO, "UPDATE_BATTLEFIELD_SCORE")
        --@end-alpha@]=]

        WIPRBSD[1] = false
    end

    -- Healer management {{{


    local ReapSchedulers = {};

    local Private_registry_by_GUID = {
        [true] = {}, -- [guid] = healer_template
        [false] = {}, -- [guid] = healer_template
    }
    -- Expose private registry for Midnight nameplate module to use as fallback
    if HHTD_C.MN then
        HHTD._Private_registry_by_Name = nil; -- set below after creation
        HHTD._Private_registry_by_GUID = Private_registry_by_GUID;
    end

    local Private_registry_by_Name = {
        [true] = {}, -- [name] = healer_template
        [false] = {}, -- [name] = healer_template
    }
    if HHTD_C.MN then
        HHTD._Private_registry_by_Name = Private_registry_by_Name;
    end

    local HealerPool;
    local function sortHealerCallBack(a, b)
        if HealerPool[a].healDone > HealerPool[b].healDone then
            return true;
        else
            return false;
        end
    end

    local SortingTray = {};

    local function UpdateRanks(healerPool)

        HealerPool = healerPool;

        TableWipe(SortingTray);

        for guid in pairs (healerPool) do
            SortingTray[#SortingTray + 1] = guid;
        end

        TableSort(SortingTray, sortHealerCallBack);

        for i, guid in ipairs (SortingTray) do
            healerPool[guid].rank = i;
        end
    end


    local ReapFriend = {
        [true] = function(guid) HHTD:Reap(guid, true); end,
        [false] = function(guid) HHTD:Reap(guid, false); end,
    };

    local function ApointReaper(guid, isFriend, lifespan)
        if ReapSchedulers[guid] then
            HHTD:CancelTimer(ReapSchedulers[guid]);
        end

        -- Take an apointment with the reaper
        ReapSchedulers[guid] = HHTD:ScheduleTimer(ReapFriend[isFriend], lifespan, guid);
        HHTD:Debug(INFO, "A reap is scheduled in", lifespan, "seconds");
    end

    -- send them to oblivion
    function HHTD:Reap (guid, isFriend, force)

        local corpse = Private_registry_by_GUID[isFriend][guid]; -- keep it safe for autopsy

        if not corpse then
            self:Debug(ERROR, ":Reap() called on non-monitored unit:", guid, isFriend, force);
            return;
        end

        if force then
            HHTD:CancelTimer(ReapSchedulers[guid]);
        end

        if GetTime() - corpse.lastMove > self.db.global.HFT or force then

            -- remove the scheduler id that brought us here
            ReapSchedulers[guid]                            = nil;
            -- clean the mess
            Private_registry_by_GUID[isFriend][guid]        = nil;
            Private_registry_by_Name[isFriend][corpse.name] = nil;

            -- announce the (un)timely departure of this healer and expose the corpse for all to see
            self:HHTD_HEALER_GONE("HHTD_HEALER_GONE", isFriend, corpse); -- make sure our handler is the first to be called
            self:SendMessage("HHTD_HEALER_GONE", isFriend, corpse);
            self:Debug(INFO2, corpse.name, "reaped");
        else
            ApointReaper(guid, isFriend, self.db.global.HFT - (GetTime() - corpse.lastMove) + 1);
            self:Debug(INFO2, corpse.name, "is still kicking");
        end
    end

    local GetNumBattlefieldScores = _G.GetNumBattlefieldScores
    local GetBattlefieldScore = _G.GetBattlefieldScore
    local ApiChangedCounter = 0
    local function checkPlayerRealRole(PlayerName, spellName)
        if GetNumBattlefieldScores() == 0 then
            return nil
        end

        -- find the player name (so dirty...)
        local playerIndex = nil
        for i=1, GetNumBattlefieldScores() do
            if (GetBattlefieldScore(i)) == PlayerName then
                playerIndex = i
                break
            end
        end

        if not playerIndex then

            -- there is no async data query in progress
            if not WIPRBSD[1] then
                -- print an error message if the async query is supposed to have
                -- succeeded for that player
                if WIPRBSD[2] == PlayerName then
                    HHTD:Debug(WARNING, "RqBttfldScrDt FAILED", PlayerName, " - GBSL:", GetNumBattlefieldScores()," - fns:", GetNumBattlefieldScores() and GetBattlefieldScore(1))
                end

                -- async data query
                RequestBattlefieldScoreData()

                WIPRBSD[1] = true;
                WIPRBSD[2] = PlayerName;
                WIPRBSD[3] = GetTime();

                HHTD:Debug(INFO, "RequestBattlefieldScoreData()")
            elseif GetTime() - WIPRBSD[3] > 30 then
                RequestBattlefieldScoreData()
                WIPRBSD[3] = GetTime();

                -- I got a few reports where this block is triggered, it seems
                -- to happen randomly but quite rarely. Letting this for
                -- unpackaged debug mode only.

                --[==[@debug@
                HHTD:Debug(ERROR, "Still waiting for UPDATE_BATTLEFIELD_SCORE after 30s...")
                --@end-debug@]==]
            end

            return nil
        end

        local classTag = select(9, GetBattlefieldScore(playerIndex)) -- 2016-05-22 seen as nil in one bug report...


        if HHTD_C.WOWC then

            if WOWC_CANT_HEAL_CLASSES[classTag] then
                HHTD:Debug(ERROR, "(HHTD-classic update required) Bad spell class for:", spellName, '(removed) detected:', HHTD_C.Healers_Only_Spells_ByName[spellName], 'real:', classTag)

                HHTD_C.Healers_Only_Spells_ByName[spellName] = nil
                return false;
            else
                return true;
            end

        end

        local spec = select(16, GetBattlefieldScore(playerIndex))

        -- since GetBattlefieldScore() returns so many values, we can be sure it won't
        -- stay stable so make sure it won't break HHTD
        if spec and HHTD_C.CLASS_SPEC_TO_ROLE[classTag] then

            -- is this spell correctly classified?
            if HHTD_C.Healers_Only_Spells_ByName[spellName] ~= classTag then
                -- special case for DK's Dark Simulacrum
                -- From some debug reports, Hunters seem to have a similar ability...
                if classTag == "DEATHKNIGHT" or classTag == "HUNTER" then
                    --[==[@debug@
                    HHTD:Debug(ERROR, "Dark Simulacrum-like detected for", PlayerName, classTag)
                    --@end-debug@]==]
                    return false
                end

                HHTD:Debug(ERROR, "(HHTD update required) Bad spell class for:", spellName, '(removed) detected:', HHTD_C.Healers_Only_Spells_ByName[spellName], 'real:', classTag)

                HHTD_C.Healers_Only_Spells_ByName[spellName] = nil
            end

            if HHTD_C.CLASS_SPEC_TO_ROLE[classTag][spec] ~= "HEALER" then
                HHTD:Debug(ERROR, "(HHTD update required) Invalid healer spec spell (spell removed):", spellName, HHTD_C.CLASS_SPEC_TO_ROLE[classTag][spec], spec)
                HHTD_C.Healers_Only_Spells_ByName[spellName] = nil
                return false
            else
                return true
            end
        else
            ApiChangedCounter = ApiChangedCounter + 1
            -- got a few error reports getting here where the classTag was nil on a Paladin... not sure what to do yet, seems rare.
            -- another one where the spec was nil, probably a spurious bug in the API, using a counter to detect real API changes on the 3rd strike.
            if ApiChangedCounter > 2 then
                HHTD:Debug(ERROR, "(HHTD update required) GetBattlefieldScore() API changed", spec, classTag, GetBattlefieldScore(playerIndex))
            end

            return nil
        end
    end

    -- Neatly add them to our little registry and keep an eye on them
    local record, name;
    local function RegisterHealer (time, isFriend, guid, sourceName, isHuman, spellName, isHealSpell, healDone, configRef, scoreboardConfirmed) -- {{{

        -- this is a new one, let's create a birth certificate
        if not Private_registry_by_GUID[isFriend][guid] then

            if sourceName then
                name = isHuman and str_match(sourceName, "^[^-]+") or sourceName; -- Remove the server's name (plates don't include it)
            else
                -- XXX fatal error out
                HHTD:Debug(WARNING, "RegisterHealer(): sourceName is missing and healer is new", guid);
                return;
            end

            local isUnique;

            if Private_registry_by_Name[isFriend][name] then
                isUnique = false;
            else
                isUnique = true;
            end

            record = {
                guid        = guid,
                name        = name,
                fullName    = sourceName,
                isUnique    = isUnique,
                isTrueHeal  = false, -- updated later
                isHuman     = isHuman,
                healDone    =  0, -- updated later
                rank        = -1, -- updated later
                _lastSort   =  0, -- updated later
                lastMove    =  0, -- updated later
                isFake      =  nil,
            };

            Private_registry_by_GUID[isFriend][guid] = record;
            Private_registry_by_Name[isFriend][name] = record;

            ApointReaper(guid, isFriend, configRef.HFT);

        else
            -- fetch the existing record
            record = Private_registry_by_GUID[isFriend][guid];
        end

        if isHealSpell then
            -- set/update heal done
            record.healDone = record.healDone + healDone;
        end

        record.lastMove = time;

        -- detect a true healer
        if not record.isTrueHeal and not record.isFake then
            if scoreboardConfirmed then
                -- Scoreboard already confirmed this player's spec is a healer role.
                -- No need to check spell tables or scoreboard again.
                record.isTrueHeal = true;
            else
                record.isTrueHeal = HHTD_C.Healers_Only_Spells_ByName[spellName] or false;

                -- Guard against WoW patches or spell translation issues and if
                -- possible verify that this player is indeed a true healer using
                -- the scoreboard.
                -- There is also problems with certain abilities such as DK's Dark
                -- Simulacrum which can mimmic other classes' abilities...

                if isHuman and record.isTrueHeal and false == checkPlayerRealRole(sourceName, spellName) then
                    record.isTrueHeal = false
                    record.isFake = true
                    -- if PvpHSpecsOnly is true then we return but we log first if necessary
                    if configRef.PvpHSpecsOnly and not configRef.Log then
                        return
                    end
                end
            end
        end

        if configRef.Log then -- {{{
            -- also log and keep track of used spells here if option is set
            -- keep in mind that logging can be enabled once a healer has already been registered
            local log;

            if not HHTD.LOGS[isFriend][guid] then
                log = {
                    guid        = guid,
                    name        = name,
                    spells      = {},
                    healDone    = 0,
                    isTrueHeal  = false,
                    isFriend    = isFriend,
                    isHuman     = isHuman,
                };

                HHTD.LOGS[isFriend][guid] = log;
            else
                log = HHTD.LOGS[isFriend][guid];
            end

            if isHealSpell then
                log.healDone = log.healDone + healDone;
            end

            if not log.isTrueHeal then
                log.isTrueHeal  = record.isTrueHeal;
            end

            if not log.spells[spellName] then
                log.spells[spellName] = 1;
            else
                log.spells[spellName] = log.spells[spellName] + 1;
            end

            -- we may get here despite PvpHSpecsOnly if a fake healer was found and
            -- discarded by the scoreboard check. We do log them though
            if not record.isTrueHeal and configRef.PvpHSpecsOnly then
                return
            end
        end -- }}}

        if configRef.UHMHAP and not scoreboardConfirmed and record.healDone < HHTD.HealThreshold then
            --HHTD:Debug(INFO2, sourceName, "is below minimum healed amount:", record.healDone);
            return;
        end

        -- Time-consuming operations every 5 seconds minimum
        if time - record._lastSort > 5 then

            record._lastSort = time;

            -- update the ranks of this healer's side, good or evil
            UpdateRanks(Private_registry_by_GUID[isFriend]);

            if not HHTD.Registry_by_GUID[isFriend][guid] then
                -- Dispatch the news
                --[==[@debug@
                HHTD:Debug(INFO, "Healer detected:", sourceName, 'uhmhap:', configRef.UHMHAP, 'healdone:', record.healDone, 'threshold:', HHTD.HealThreshold);
                --@end-debug@]==]
                if MN_Diag then
                    MN_Diag.healerBornCount = (MN_Diag.healerBornCount or 0) + 1;
                    if MN_Diag.diagEnabled and MN_Diag.healerBornCount <= 30 then
                        CoreDL("[BORN] " .. tostring(record.name) .. " -> "
                            .. (isFriend and "Registry(friendly)" or "Registry(hostile)")
                            .. " scoreboard=" .. tostring(scoreboardConfirmed or false));
                    end
                end
                local bornOk, bornErr = pcall(HHTD.HHTD_HEALER_BORN, HHTD, "HHTD_HEALER_BORN", isFriend, record); -- make sure ours is the first to be called
                if not bornOk and MN_Diag then
                    CoreDL("[BORN-PCALL] Error: " .. tostring(bornErr), "ERR");
                end
                HHTD:SendMessage("HHTD_HEALER_BORN", isFriend, record);
            end

            HHTD:SendMessage("HHTD_HEALER_GROW", isFriend, record);
        end

    end -- }}}

    -- }}}



    -- [Forever] D7: heal evidence (ForeverEvidence.lua) registers confirmed healers through the same pipeline
    HHTD._MN_RegisterHealer = function(...) return RegisterHealer(...) end

    -- === Midnight Scoreboard-based Healer Detection === {{{
    -- In 12.0, CLEU is gone and enemy spellIDs are secret in BGs.
    -- The scoreboard provides spec/role data for all BG participants.
    -- This scanner periodically checks the scoreboard and registers healers by spec.

    local ScoreboardScanner_lastScan = 0;
    local ScoreboardScanner_knownHealerGUIDs = {};

    local function ScoreboardScanForHealers()
        if not HHTD_C.MN then return end -- only needed in Midnight

        local time = GetTime();
        -- Don't scan more than once every 3 seconds
        if time - ScoreboardScanner_lastScan < 3 then return end
        ScoreboardScanner_lastScan = time;

        local configRef = HHTD.db.global;
        local numScores = GetNumBattlefieldScores and GetNumBattlefieldScores() or 0;
        MN_Diag.scoreboardPlayers = numScores;

        if numScores == 0 then return end

        local playerFaction = HHTD_C.PLAYER_FACTION;
        -- [Forever] D5: roster of every row (first name + side -> class) for the nameplate class join
        if HHTD.MN_RosterSweep then pcall(HHTD.MN_RosterSweep); end
        local scannedCount = 0;
        local healersFound = 0;

        for i = 1, numScores do
            local scoreData = nil;
            local scoreName, scoreGUID, scoreClassToken, scoreTalentSpec, scoreFaction, scoreRoleAssigned;
            local scoreHealingDone, scoreDamageDone; -- [Forever] D6

            -- Try C_PvP.GetScoreInfo first (newer API with roleAssigned)
            if C_PvP and C_PvP.GetScoreInfo then
                scoreData = C_PvP.GetScoreInfo(i);
                if scoreData and canaccessvalue(scoreData) then
                    scoreName = scoreData.name;
                    scoreGUID = scoreData.guid;
                    scoreClassToken = scoreData.classToken;
                    scoreTalentSpec = scoreData.talentSpec;
                    scoreFaction = scoreData.faction;
                    scoreRoleAssigned = scoreData.roleAssigned;
                    scoreHealingDone = scoreData.healingDone; -- [Forever] D6
                    scoreDamageDone = scoreData.damageDone;
                else
                    scoreData = nil; -- secret or nil
                end
            end

            -- Fall back to GetBattlefieldScore (legacy, may not have secret restrictions)
            if not scoreData and GetBattlefieldScore then
                local name, _, _, _, _, _, faction, _, classToken, _, _, _, _, _, _, talentSpec = GetBattlefieldScore(i);
                if name and canaccessvalue(name) then
                    scoreName = name;
                    scoreClassToken = classToken;
                    scoreTalentSpec = talentSpec;
                    scoreFaction = faction;
                    -- GetBattlefieldScore doesn't return GUID, we'll match by name
                    scoreGUID = nil;
                end
            end

            if not scoreName or not canaccessvalue(scoreName) then
                -- skip entries we can't read
            else
                scannedCount = scannedCount + 1;

                -- Check if this player has a healer spec
                local isHealer = false;
                local isFriend = false;
                local specChecked = false;

                -- Method 1 (preferred): Check talentSpec against CLASS_SPEC_TO_ROLE
                -- This is the most reliable method since it checks the actual spec name
                -- against the role table built from GetSpecializationInfoForClassID.
                -- [Forever] D4: canaccessvalue before the truth test (talentSpec is secret prep/ooc/combat per the diag)
                if canaccessvalue(scoreTalentSpec) and canaccessvalue(scoreClassToken)
                    and scoreTalentSpec and scoreClassToken
                    and HHTD_C.CLASS_SPEC_TO_ROLE[scoreClassToken] then
                    specChecked = true;
                    if HHTD_C.CLASS_SPEC_TO_ROLE[scoreClassToken][scoreTalentSpec] == "HEALER" then
                        isHealer = true;
                    end
                end

                -- Method 2 (fallback): Check roleAssigned only if spec data wasn't available
                -- roleAssigned can be unreliable in BGs (e.g. Guardian Druids showing role 2)
                if not specChecked and canaccessvalue(scoreRoleAssigned) and scoreRoleAssigned and scoreRoleAssigned == 2 then -- [Forever] D4 order
                    isHealer = true;
                end

                -- [Forever] D6: the WOWC spec->role table is empty and roleAssigned is secret in-match, so the scoreboard
                -- never names a healer. healingDone/damageDone are clear post-match (diag: 60/60): a player who healed at
                -- least as much as they damaged is a healer.
                if HHTD_C.FOREVER and not isHealer and (not HHTD.MN_InBG or HHTD.MN_InBG()) then -- [Forever] F7: BG only
                    local h, d = T.FS.num(scoreHealingDone), T.FS.num(scoreDamageDone);
                    if h and d and h > 0 and h >= d then isHealer = true; end
                end

                if isHealer then
                    -- Determine if friendly or hostile
                    -- faction: 0 = Horde, 1 = Alliance
                    if canaccessvalue(scoreFaction) and scoreFaction then -- [Forever] D4 order
                        if playerFaction == "Horde" then
                            isFriend = (scoreFaction == 0);
                        elseif playerFaction == "Alliance" then
                            isFriend = (scoreFaction == 1);
                        end
                    end

                    -- Generate a pseudo-GUID if we don't have one
                    local guid = scoreGUID;
                    if not canaccessvalue(guid) or not guid then -- [Forever] D4 order (guid secret in-match)
                        guid = "Scoreboard-" .. scoreName;
                    end

                    local specLabel = tostring(scoreTalentSpec or "?") .. " " .. tostring(scoreClassToken or "?");
                    local isNew = not ScoreboardScanner_knownHealerGUIDs[guid];

                    if isNew then
                        ScoreboardScanner_knownHealerGUIDs[guid] = true;
                        healersFound = healersFound + 1;
                        MN_Diag.scoreboardRegistered = (MN_Diag.scoreboardRegistered or 0) + 1;

                        if MN_Diag.diagEnabled and MN_Diag.scoreboardRegistered <= 30 then
                            CoreDL("[SCORE] Healer: " .. tostring(scoreName)
                                .. " spec: " .. specLabel
                                .. " " .. (isFriend and "friendly" or "hostile"));
                        end
                    end

                    -- === INDEPENDENT HEALER LIST (bypasses Registry/Reaper entirely) ===
                    -- This is the definitive healer list that MidnightNameplates reads.
                    -- Stores healers by Name, GUID, and ClassSpec for maximum matching flexibility.
                    local shortName = scoreName:match("^([^-]+)") or scoreName;
                    -- [Forever] D5: plates give "First", the scoreboard "First Surname": key on the first word when unique
                    if HHTD_C.FOREVER and HHTD.MN_ShortKey then shortName = HHTD.MN_ShortKey(scoreName); end
                    if not HHTD.MN_HealersByName[shortName] then
                        local healerRecord = {
                            isFriend = isFriend,
                            spec = specLabel,
                            fullName = scoreName,
                            classToken = scoreClassToken,
                            talentSpec = scoreTalentSpec,
                            guid = (canaccessvalue(scoreGUID) and scoreGUID) and scoreGUID or nil, -- [Forever] D4 order
                        };
                        HHTD.MN_HealersByName[shortName] = healerRecord;

                        -- Also index by real GUID if available
                        if healerRecord.guid then
                            HHTD.MN_HealersByGUID[healerRecord.guid] = healerRecord;
                        end

                        -- Also index by ClassToken:TalentSpec for class-based matching
                        if canaccessvalue(scoreClassToken) and scoreClassToken -- [Forever] D4 order
                            and canaccessvalue(scoreTalentSpec) and scoreTalentSpec then
                            local classSpecKey = scoreClassToken .. ":" .. scoreTalentSpec;
                            if not HHTD.MN_HealersByClassSpec[classSpecKey] then
                                HHTD.MN_HealersByClassSpec[classSpecKey] = {};
                            end
                            HHTD.MN_HealersByClassSpec[classSpecKey][#HHTD.MN_HealersByClassSpec[classSpecKey] + 1] = healerRecord;
                        end

                        if isFriend then
                            HHTD.MN_HealerCount.friendly = HHTD.MN_HealerCount.friendly + 1;
                        else
                            HHTD.MN_HealerCount.enemy = HHTD.MN_HealerCount.enemy + 1;
                        end

                        if MN_Diag.diagEnabled and (MN_Diag.scoreboardRegistered or 0) <= 30 then
                            CoreDL("[SCORE-MN] " .. tostring(shortName)
                                .. " class:" .. tostring(scoreClassToken)
                                .. " spec:" .. tostring(scoreTalentSpec)
                                .. " guid:" .. (healerRecord.guid and "YES" or "NO(secret)")
                                .. " " .. (isFriend and "friend" or "enemy"));
                        end
                    end

                    -- Still call RegisterHealer for the traditional HHTD pipeline
                    RegisterHealer(time, isFriend, guid, scoreName, true, specLabel, false, 0, configRef, true);
                end
            end
        end

        if scannedCount > 0 and healersFound > 0 then
            MN_Diag.scoreboardScans = (MN_Diag.scoreboardScans or 0) + 1;
        end
    end

    -- Override UPDATE_BATTLEFIELD_SCORE to trigger scoreboard scanning in Midnight
    local origUBS = HHTD.UPDATE_BATTLEFIELD_SCORE;
    function HHTD:UPDATE_BATTLEFIELD_SCORE()
        if origUBS then origUBS(self) end

        if HHTD_C.MN then
            ScoreboardScanForHealers();
        end
    end

    -- Also add a periodic scoreboard request timer for Midnight BGs
    function HHTD:StartScoreboardScanner()
        if not HHTD_C.MN then return end

        -- Request scoreboard data periodically (every 10 seconds)
        -- ALWAYS request data and scan — don't gate on GetNumBattlefieldScores()
        -- because scoreboard data can expire, creating a chicken-and-egg problem
        -- where we never re-request because scores==0.
        self:ScheduleRepeatingTimer(function()
            -- Always request fresh data
            if RequestBattlefieldScoreData then
                RequestBattlefieldScoreData();
            end
            -- Always try to scan (ScoreboardScanForHealers checks numScores internally)
            ScoreboardScanForHealers();
        end, 10);

        -- Also do an initial request
        if RequestBattlefieldScoreData then
            RequestBattlefieldScoreData();
        end

        CoreDL("[MN] Scoreboard healer scanner started (10s interval).");
    end
    -- }}}


    -- Combat Event Listener (Main Healer Detection) {{{

    local band                      = _G.bit.band;
    local sub                       = _G.string.sub;
    local UnitInRange               = _G.UnitInRange;

    local HOSTILE_OUTSIDER          = bit.bor (COMBATLOG_OBJECT_AFFILIATION_OUTSIDER, COMBATLOG_OBJECT_REACTION_HOSTILE);
    local HOSTILE                   = COMBATLOG_OBJECT_REACTION_HOSTILE;
    local FRIENDLY                  = COMBATLOG_OBJECT_REACTION_FRIENDLY;

    local HOSTILE_OUTSIDER_NPC      = bit.bor (HOSTILE_OUTSIDER                     , COMBATLOG_OBJECT_TYPE_NPC);
    local FRIENDLY_NPC              = bit.bor (COMBATLOG_OBJECT_REACTION_FRIENDLY   , COMBATLOG_OBJECT_TYPE_NPC);
    local HOSTILE_OUTSIDER_PLAYER   = bit.bor (HOSTILE_OUTSIDER                     , COMBATLOG_OBJECT_TYPE_PLAYER);
    local FRIENDLY_PLAYER           = bit.bor (COMBATLOG_OBJECT_REACTION_FRIENDLY   , COMBATLOG_OBJECT_TYPE_PLAYER);

    local ACCEPTABLE_TARGETS = bit.bor (COMBATLOG_OBJECT_TYPE_PLAYER, COMBATLOG_OBJECT_TYPE_NPC);

    local Source_Is_NPC = false;
    local Source_Is_Human = false;
    local Source_Is_Friendly = false;

    local isHealSpell = false;

    local Registry_by_GUID = HHTD.Registry_by_GUID;


    local registered;

    local prTime, lastAttack_amount_lastAlert


    function HHTD:MakeDummyEvent(unit)
        local destFlags;

        if UnitIsPlayer(unit) then
            if UnitIsFriend(unit, 'player') then
                self:Debug(INFO, "target is a friendly player");
                destFlags = FRIENDLY_PLAYER;
            else
                destFlags = HOSTILE_OUTSIDER_PLAYER;
                self:Debug(INFO, "target is a hostile player");
            end
        else
            if UnitIsFriend(unit, 'player') then
                self:Debug(INFO, "target is a friendly NPC");
                destFlags = FRIENDLY_NPC;
            else
                destFlags = HOSTILE_OUTSIDER_NPC;
                self:Debug(INFO, "target is a hostile NPC");
            end
        end

        local event, srcFlags, srcGUID, srcName, destGUID, destName

        if IsControlKeyDown() and IsShiftKeyDown() then
            event    = "DUMMY_DAMAGE"
            srcFlags = HOSTILE_OUTSIDER_PLAYER
            srcGUID  = 'hostile unit'
            srcName  = 'hostile unit'
            destGUID = UnitGUID(unit);
            destName = UnitName('player') -- so that CheckInteractDistance('unit name', 1) works
            self:Debug(ERROR, "mimicking attack on healer", destName, "(your name so that the alert can be triggered and tested)");
        else
            event    = "DUMMY_HEAL"
            srcFlags = destFlags
            srcGUID  = UnitGUID(unit)
            srcName  = UnitName(unit)
            destGUID = "healed unit"
            destName = "healed unit"
        end

        local class = select(2, UnitClass(unit));
        local dummySpell = ({
            ["DRUID"] = GetSpellName(000740),
            ["SHAMAN"] = GetSpellName(077472),
            ["PRIEST"] = GetSpellName(047788),
            ["PALADIN"] = GetSpellName(085222),
            ["MONK"] = GetSpellName(116849),
            ["EVOKER"] = GetSpellName(364343),
        })[class] or GetSpellName(3273);
        self:COMBAT_LOG_EVENT_UNFILTERED(nil, 0, event, false, srcGUID, srcName, srcFlags, 0, destGUID, destName, destFlags, 0, 0, dummySpell, "", HHTD.HealThreshold + 1);
    end

    -- http://www.wowpedia.org/API_COMBAT_LOG_EVENT
    -- In Midnight (12.0), COMBAT_LOG_EVENT_INTERNAL_UNFILTERED replaces COMBAT_LOG_EVENT_UNFILTERED
    -- and C_CombatLogInternal.GetCurrentEventInfo() replaces CombatLogGetCurrentEventInfo()
    function HHTD:COMBAT_LOG_EVENT_INTERNAL_UNFILTERED(...)
        MN_Diag.cleuIntFired = MN_Diag.cleuIntFired + 1;
        return self:COMBAT_LOG_EVENT_UNFILTERED(...)
    end

    function HHTD:COMBAT_LOG_EVENT_UNFILTERED(e, timestamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, _spellID, spellNAME, _spellSCHOOL, _amount)
        if not canaccessvalue(sourceGUID) then return end -- of course this is only triggered when the "test hhtd behavior on current target" button is used!

        if event == nil then
            -- Use the appropriate combat log API depending on the WoW version
            if HHTD_C.MN and C_CombatLogInternal and C_CombatLogInternal.GetCurrentEventInfo then
                timestamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, _spellID, spellNAME, _spellSCHOOL, _amount = C_CombatLogInternal.GetCurrentEventInfo()
            elseif CombatLogGetCurrentEventInfo then
                timestamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, _spellID, spellNAME, _spellSCHOOL, _amount = CombatLogGetCurrentEventInfo()
            else
                return -- no combat log API available
            end

            if timestamp ~= nil or event ~= nil then
                MN_Diag.cleuIntGotData = MN_Diag.cleuIntGotData + 1;
            end

            -- In Midnight, some values may be "secret" - check critical fields
            if not canaccessvalue(event) then
                MN_Diag.cleuIntSecretEvent = MN_Diag.cleuIntSecretEvent + 1;
                return -- combat log data is restricted in this context
            end
            if not canaccessvalue(sourceGUID) then
                MN_Diag.cleuIntSecretGUID = MN_Diag.cleuIntSecretGUID + 1;
                return
            end

            -- Track last event type
            if event then MN_Diag.lastEvent = tostring(event) end
        end

        -- escape if no source {{{
        -- untraceable events are useless
        if not sourceGUID or hideCaster then
            MN_Diag.cleuIntNoSource = MN_Diag.cleuIntNoSource + 1;

            if event == "UNIT_DIED" and self.Friendly_Healers_Attacked_by_GUID[destGUID] then
                self.Friendly_Healers_Attacked_by_GUID[destGUID] = nil;
            end

            return
        end
        -- }}}

        -- In Midnight, flags may be secret values - check before bitwise operations
        if not canaccessvalue(destFlags) or not canaccessvalue(sourceFlags) then
            MN_Diag.cleuIntSecretFlags = MN_Diag.cleuIntSecretFlags + 1;
            return;
        end

        -- Escape if bad target (not human nor npc) {{{
        -- Healers are only those caring for other players or NPC
        if band(destFlags, ACCEPTABLE_TARGETS) == 0 then
            --[==[@debug@
            --[[
            if self.db.global.Debug and event:sub(-5) == "_HEAL" and sourceGUID ~= destGUID then
                self:Debug(INFO2, "Bad target", sourceName, destName);
            end
            --]]
            --@end-debug@]==]
            return;
        end -- }}}

        local configRef = self.db.global; -- config shortcut

        Source_Is_NPC = false;
        Source_Is_Human = false;
        Source_Is_Friendly = false;

        if band(sourceFlags, HOSTILE_OUTSIDER_NPC) == HOSTILE_OUTSIDER_NPC then
            -- leave here if we don't care about pve healers | caveat: if a friendly healear is attacked by an NPC we won't know about it
            if not configRef.Pve then
                return;
            end
            Source_Is_NPC = true;
        elseif band (sourceFlags, HOSTILE_OUTSIDER_PLAYER) == HOSTILE_OUTSIDER_PLAYER then
            Source_Is_Human = true;
        elseif band (sourceFlags, FRIENDLY_PLAYER) == FRIENDLY_PLAYER then
            Source_Is_Human = true;
            Source_Is_Friendly = true;
        elseif band (sourceFlags, FRIENDLY_NPC) == FRIENDLY_NPC then
            -- leave here if we don't care about pve healers | caveat: none I can think of
            if not configRef.Pve then
                return;
            end
            Source_Is_NPC = true;
            Source_Is_Friendly = true;
        else
            -- not a player or an NPC, why are we even considering this comment?
            MN_Diag.cleuIntNotPlayer = MN_Diag.cleuIntNotPlayer + 1;
            return;
        end


        -- check if a healer is under attack - broadcast the event and return {{{
        -- if the source is hostile AND if its target is a registered friendly healer
        if (not Source_Is_Friendly) and (configRef.HealerUnderAttackAlerts and (Source_Is_NPC or Source_Is_Human) and Registry_by_GUID[true][destGUID]) then


            if event == "SWING_DAMAGE" then
               _amount = _spellID
            end

            -- In Midnight, _amount may be a secret value
            if not canaccessvalue(_amount) then _amount = nil end

            if (_amount and event:sub(-7) == "_DAMAGE") then

                -- the healer is nearby
                if HHTD_C.PLAYER_GUID == destGUID or (UnitInRange(destName)) then

                    -- first attack?
                    if not self.Friendly_Healers_Attacked_by_GUID[destGUID] then
                        self.Friendly_Healers_Attacked_by_GUID[destGUID] = {0, 0, 0};
                    end

                    -- shortcuts
                    lastAttack_amount_lastAlert  = self.Friendly_Healers_Attacked_by_GUID[destGUID]
                    prTime = GetTime()

                    -- less than 5s elapsed since last attacked (influenced below)
                    if prTime - lastAttack_amount_lastAlert[1] < 5 then
                        lastAttack_amount_lastAlert[2] = lastAttack_amount_lastAlert[2] + _amount
                    else
                        lastAttack_amount_lastAlert[2] = _amount
                    end

                    -- register last attack time, put it in the future if the
                    -- attack is more than half the threshold to delay the
                    -- reset by 10s instead of 5s
                    if prTime > lastAttack_amount_lastAlert[1] then
                        lastAttack_amount_lastAlert[1] = prTime + (_amount / self.ProtectDamageThreshold > .5 and 5 or 0)
                    end

                    --[==[@debug@
                    if _amount / self.ProtectDamageThreshold > .5 then
                        self:Debug(WARNING, "amount is huge:", _amount, _amount / self.ProtectDamageThreshold > .5 and 5 or 0);
                    end
                    --@end-debug@]==]

                    -- last alert was more than 30s ago and threshold is reached
                    if prTime - lastAttack_amount_lastAlert[3] > 30 and lastAttack_amount_lastAlert[2] > self.ProtectDamageThreshold then
                        self:SendMessage("HHTD_HEALER_UNDER_ATTACK", sourceName, sourceGUID, destName, destGUID, HHTD_C.PLAYER_GUID == destGUID);

                        lastAttack_amount_lastAlert[3] = GetTime();
                    end

                    --[==[@debug@
                    self:Debug(WARNING, "amount:", _amount, lastAttack_amount_lastAlert[2], event, prTime - lastAttack_amount_lastAlert[3] > 30, lastAttack_amount_lastAlert[2] > self.ProtectDamageThreshold, _amount / self.ProtectDamageThreshold > .5 and 5 or 0);
                    --@end-debug@]==]

                end
            end

            -- it's certainly not a heal so no use to continue past this point.
            return;
        end -- }}}

        -- Escape if bad source (deprecated) {{{
        -- if the source is not a player and if while pve, the source is not an npc, then we don't care about this event
        -- ie: we care if the source is a human player or pve is enaled and the source is an npc.
        --      not (a or (b and c)) ==  !a and (not b or not c)

        ----------if not ( Source_Is_Human or (Source_Is_NPC and configRef.Pve)) then
            ---------return;
        ----------end -- }}}


        -- get a shortcut to the healer profile if it exists
        registered = Private_registry_by_GUID[Source_Is_Friendly][sourceGUID];

        -- In Midnight, spellNAME may be a secret value - check before using as table key
        if not canaccessvalue(spellNAME) then
            MN_Diag.cleuIntSecretSpell = MN_Diag.cleuIntSecretSpell + 1;
            spellNAME = nil; -- treat secret spell names as unknown
        end

        -- Escape if Source_Is_Human and scanning for pure healing specs and the spell doesn't match and the healer is not known as a true healer {{{
        if Source_Is_Human and (configRef.PvpHSpecsOnly and (not spellNAME or not HHTD_C.Healers_Only_Spells_ByName[spellNAME]) and (not registered or not registered.isTrueHeal)) then
            --[==[@debug@
            --self:Debug(INFO2, "Spell", spellNAME, "is not a healer' spell");
            --@end-debug@]==]
            return;
        end -- }}}

        -- a heal but not a self inflicted one
        if sourceGUID ~= destGUID and event:sub(-5) == "_HEAL" then
            isHealSpell = true;
            MN_Diag.cleuIntHealEvent = MN_Diag.cleuIntHealEvent + 1;
        else
            isHealSpell = false;
        end

        -- Esacpe if it's a heal spell toward a unit hostile to the source
        if isHealSpell and ( Source_Is_Friendly and band(destFlags, HOSTILE)~=0 or not Source_Is_Friendly and band(destFlags, FRIENDLY)~=0 ) then
            --[==[@debug@
            self:Debug(INFO2, "Spell", spellNAME, "source and destination awkwardness", sourceName, destName,
                (Source_Is_Friendly and band(destFlags, HOSTILE)),
                (not Source_Is_Friendly and band(destFlags, FRIENDLY)));
            --@end-debug@]==]
            return;
        end

         -- Escape if not a heal spell and (not checking for spec's spells or source is a NPC) {{{
         -- we look for healing spells directed to others
         if not isHealSpell and (Source_Is_NPC or not configRef.PvpHSpecsOnly or not spellNAME or not HHTD_C.Healers_Only_Spells_ByName[spellNAME]) then
             return false;
         end -- }}}

         -- if we are still here it means that this is a HEAL toward another
         -- player or an ability available to specialized healers only


         if not sourceName then
             self:Debug(WARNING, "NO NAME for GUID:", sourceGUID);
             return;
         end

         -- In Midnight, _amount may be a secret value for the heal amount
         if not canaccessvalue(_amount) then _amount = 0 end

         MN_Diag.cleuIntRegistered = MN_Diag.cleuIntRegistered + 1;
         if MN_Diag.diagEnabled and MN_Diag.cleuIntRegistered <= 20 then
             CoreDL("[CLEU] Healer: " .. tostring(sourceName) .. " spell: " .. tostring(spellNAME or "Unknown") .. " heal=" .. tostring(isHealSpell) .. " amt=" .. tostring(_amount));
         end

         RegisterHealer(GetTime(), Source_Is_Friendly, sourceGUID, sourceName, Source_Is_Human, spellNAME or "Unknown", isHealSpell, _amount, configRef);

     end -- }}}

     -- === Midnight (12.0) Spellcast-based Healer Detection === {{{
     -- These handlers supplement COMBAT_LOG_EVENT_INTERNAL_UNFILTERED by detecting
     -- healer-specific spellcasts on visible nameplate units, target, focus, etc.
     -- This works even when combat log data is restricted by secret values.

     local function HandleSpellcastHealer(self, unitTarget, spellID)
         if not HHTD_C.MN then return end -- only needed in Midnight
         MN_Diag.spellcastFired = MN_Diag.spellcastFired + 1;
         if type(unitTarget) == "nil" or type(spellID) == "nil" then return end -- [Forever] D4: no truth test on a secret spellID

         if not canaccessvalue(spellID) then
             MN_Diag.spellcastSecretID = MN_Diag.spellcastSecretID + 1;
             return
         end

         MN_Diag.lastSpell = tostring(unitTarget) .. ":" .. tostring(spellID);

         -- Check if this spell is a healer-specific spell
         local healerClass = HHTD_C.Healers_Only_Spells_ByID_Lookup and HHTD_C.Healers_Only_Spells_ByID_Lookup[spellID];
         if not healerClass then
             MN_Diag.spellcastNotHealer = MN_Diag.spellcastNotHealer + 1;
             return
         end

         local guid = UnitGUID(unitTarget);
         if not canaccessvalue(guid) or not guid then -- [Forever] D4 order
             MN_Diag.spellcastSecretGUID = MN_Diag.spellcastSecretGUID + 1;
             return
         end

         local sourceName = UnitName(unitTarget);
         if not canaccessvalue(sourceName) or not sourceName then -- [Forever] D4 order
             MN_Diag.spellcastSecretGUID = MN_Diag.spellcastSecretGUID + 1;
             return
         end

         local isHuman = UnitIsPlayer(unitTarget);
         local isFriend = UnitIsFriend(unitTarget, "player") or false;

         -- Skip NPCs if PvE mode is disabled
         if not isHuman and not self.db.global.Pve then return end

         local spellName = GetSpellName(spellID);
         if not spellName or not canaccessvalue(spellName) then
             spellName = "Unknown Heal #" .. tostring(spellID);
         end

         MN_Diag.spellcastRegistered = MN_Diag.spellcastRegistered + 1;
         if MN_Diag.diagEnabled and MN_Diag.spellcastRegistered <= 20 then
             CoreDL("[CAST] Healer: " .. tostring(sourceName) .. " (" .. tostring(unitTarget) .. ") spell: " .. tostring(spellName) .. " id=" .. tostring(spellID));
         end

         -- Register via the same path as the CLEU handler
         -- isHealSpell=false because we can't confirm it's a heal (it's a healer-specific cast)
         -- healDone=0 because UNIT_SPELLCAST doesn't tell us heal amounts
         -- The PvpHSpecsOnly check will match since we already validated it's in Healers_Only_Spells
         RegisterHealer(GetTime(), isFriend, guid, sourceName, isHuman, spellName, false, 0, self.db.global);
     end

     function HHTD:UNIT_SPELLCAST_SUCCEEDED(e, unitTarget, castGUID, spellID, castBarID)
         HandleSpellcastHealer(self, unitTarget, spellID);
     end

     function HHTD:UNIT_SPELLCAST_START(e, unitTarget, castGUID, spellID, castBarID)
         HandleSpellcastHealer(self, unitTarget, spellID);
     end
     -- }}}

 end

 -- Undertaker {{{
 -- The Undertaker will garbage collect healers who have not been healing recently (whatever the reason...)
 function HHTD:Undertaker()

     local Time = GetTime();

     local Registry_by_GUID = HHTD.Registry_by_GUID;
     --[==[@debug@
     --self:Debug(INFO2, "cleaning...");
     --@end-debug@]==]

     -- clean attacked healers {{{
     -- should also be cleaned when such healer leaves combat -- no event for those...
     for guid, lastAttack_amount_lastAlert in pairs(self.Friendly_Healers_Attacked_by_GUID) do
         -- if more than 30s elapsed since the last attack or if it's no longer a registered healer
         if Time - lastAttack_amount_lastAlert[1] > 30 or not Registry_by_GUID[true][guid] then
             self.Friendly_Healers_Attacked_by_GUID[guid] = nil;
             self:Debug(INFO2, "removed healer from attack table", guid);
         end
     end -- }}}

     -- delayed execution after combat
     if (not InCombatLockdown() and self.DelayedFunctionCallsCount > 0) then
         for id, funcAndArgs in pairs (self.DelayedFunctionCalls) do

             self:Debug(INFO2, "Running post combat command", id);

             funcAndArgs.func(unpack(funcAndArgs.args));

             self.DelayedFunctionCalls[id] = nil; -- remove it from the list
             self.DelayedFunctionCallsCount = self.DelayedFunctionCallsCount - 1;
         end
     end

end -- }}}