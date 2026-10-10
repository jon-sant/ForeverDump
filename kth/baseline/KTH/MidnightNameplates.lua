--[=[
Kill The Healer (K.T.H.) - Nameplate Healer Indicators for WoW 12.0+ (Midnight)
Based on H.H.T.D. by John Wellesz (2072productions.com)

In WoW 12.0 instanced PvP, enemy player names and GUIDs are "secret values."
UnitClass() and UnitPowerType() remain accessible on enemy nameplates.

Healer identification:
  - FRIENDLY: Match by name via scoreboard data (names accessible for friendlies).
  - ENEMY (unambiguous classes — Priest, Druid, Monk):
      Class + primary power type.  Only healer specs have Mana as their primary
      power type.  (Shadow = Insanity, Balance = Astral Power, Feral = Energy,
      Guardian = Rage, Windwalker = Energy, Brewmaster = Energy.)
  - ENEMY (ambiguous classes — Paladin, Shaman, Evoker):
      ALL specs of these classes use Mana as primary power type, so power type
      alone cannot distinguish healers from DPS.  Two additional checks:
        (a) Scoreboard class filtering: if the scoreboard says the enemy team
            has a healer of class X, we mark all class X nameplates.
        (b) Spellcast confirmation: if a nameplate unit casts a known healer
            spell, we confirm that specific nameplate as a healer.

  NOTE: UnitPowerMax() is NOT useful for disambiguation — it returns non-zero for
  ALL power types a class can use, regardless of current spec.
--]=]

local ADDON_NAME, T = ...;
local HHTD = T.HHTD;
local HHTD_C = HHTD.Constants;

if not HHTD_C.MN then return; end

-- Upvalues
local UnitName          = _G.UnitName;
local UnitExists        = _G.UnitExists;
local UnitIsPlayer      = _G.UnitIsPlayer;
local UnitGUID          = _G.UnitGUID;
local UnitClass         = _G.UnitClass;
local UnitCanAttack     = _G.UnitCanAttack;
local UnitPowerType     = _G.UnitPowerType;
local C_NamePlate       = _G.C_NamePlate;
local GetTime           = _G.GetTime;
local pairs             = _G.pairs;
local tostring          = _G.tostring;
local tonumber          = _G.tonumber;
local CreateFrame       = _G.CreateFrame;
local canaccessvalue    = _G.canaccessvalue or function(_) return true; end;
local format            = _G.string.format;

-- ============================================================
-- POWER TYPE CONSTANTS
-- ============================================================
local POWER_MANA = 0;

-- ============================================================
-- CLASS CATEGORISATION
-- ============================================================

-- Classes where ONLY the healer spec uses Mana as primary power type.
-- For these, power-type check alone is sufficient to identify healers.
local UNAMBIGUOUS_HEALER_CLASSES = {
    ["PRIEST"]  = true,  -- Holy/Disc = Mana, Shadow = Insanity (13)
    ["DRUID"]   = true,  -- Resto = Mana, Balance = AstralPower (8), Feral = Energy (3), Guardian = Rage (1)
    ["MONK"]    = true,  -- Mistweaver = Mana, Windwalker = Energy (3), Brewmaster = Energy (3)
};

-- Classes where ALL specs use Mana as primary power type.
-- Power type alone cannot distinguish healer from DPS/Tank.
-- Requires scoreboard or spellcast confirmation.
local AMBIGUOUS_MANA_CLASSES = {
    ["PALADIN"] = true,  -- Holy/Prot/Ret all show Mana (0)
    ["SHAMAN"]  = true,  -- Resto/Enh/Ele all show Mana (0)
    ["EVOKER"]  = true,  -- Pres/Dev/Aug all show Mana (0)
};

-- Union of both sets for quick "can this class heal?" check
local HEALER_CAPABLE_CLASSES = {};
for k in pairs(UNAMBIGUOUS_HEALER_CLASSES) do HEALER_CAPABLE_CLASSES[k] = true; end
for k in pairs(AMBIGUOUS_MANA_CLASSES) do HEALER_CAPABLE_CLASSES[k] = true; end

-- ============================================================
-- USER-CONFIGURABLE DEFAULTS
-- ============================================================
local DEFAULT_SETTINGS = {
    offsetY         = 10,
    friendIcon      = "cross",
    enemyIcon       = "cross",
    friendColor     = { r = 0.2, g = 1.0, b = 0.2, a = 1.0 },
    enemyColor      = { r = 1.0, g = 0.2, b = 0.2, a = 1.0 },
    indicatorSize   = 36,
    showGlow        = true,
    -- Alert system
    alertEnabled    = true,
    alertSound      = "raidwarn",
    alertFlash      = true,
    alertColor      = { r = 1.0, g = 0.0, b = 0.0, a = 0.6 },
    alertCooldown   = 5,
    -- Per-class overrides (nil values = use global default)
    classOverrides  = {
        PRIEST  = { icon = nil, colorR = nil, colorG = nil, colorB = nil },
        DRUID   = { icon = nil, colorR = nil, colorG = nil, colorB = nil },
        MONK    = { icon = nil, colorR = nil, colorG = nil, colorB = nil },
        PALADIN = { icon = nil, colorR = nil, colorG = nil, colorB = nil },
        SHAMAN  = { icon = nil, colorR = nil, colorG = nil, colorB = nil },
        EVOKER  = { icon = nil, colorR = nil, colorG = nil, colorB = nil },
    },
};

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

-- ============================================================
-- ALERT SOUND PRESETS
-- ============================================================
local ALERT_SOUNDS = {
    raidwarn  = { id = 8959,  label = "Raid Warning" },
    pvpflag   = { id = 8174,  label = "PvP Flag" },
    readychk  = { id = 8960,  label = "Ready Check" },
    none      = { id = nil,   label = "None (silent)" },
};

-- ============================================================
-- HEALER CLASSES (for per-class customization)
-- ============================================================
local HEALER_CLASS_LIST = { "PRIEST", "DRUID", "MONK", "PALADIN", "SHAMAN", "EVOKER" };
local HEALER_CLASS_DISPLAY = {
    PRIEST  = { name = "Priest",  r = 1.00, g = 1.00, b = 1.00 },
    DRUID   = { name = "Druid",   r = 1.00, g = 0.49, b = 0.04 },
    MONK    = { name = "Monk",    r = 0.00, g = 1.00, b = 0.59 },
    PALADIN = { name = "Paladin", r = 0.96, g = 0.55, b = 0.73 },
    SHAMAN  = { name = "Shaman",  r = 0.00, g = 0.44, b = 0.87 },
    EVOKER  = { name = "Evoker",  r = 0.20, g = 0.58, b = 0.50 },
};

-- Live settings (populated from saved vars on ADDON_LOADED)
local SETTINGS = {};

local function DeepCopyTable(src)
    if type(src) ~= "table" then return src; end
    local dst = {};
    for k, v in pairs(src) do
        dst[k] = type(v) == "table" and DeepCopyTable(v) or v;
    end
    return dst;
end

local function CopyDefaults()
    return DeepCopyTable(DEFAULT_SETTINGS);
end

-- ============================================================
-- CONSTANTS
-- ============================================================
local MAX_NAMEPLATES = 40;
local SCAN_INTERVAL  = 1.0;
local GLOW_TEXTURE = "Interface\\GLUES\\Models\\UI_MainMenu\\swordglow";

-- ============================================================
-- STATE
-- ============================================================
local PlateIndicators = {};
local ActivePlates = {};
local MNP_Enabled = false;
local scanTimer = nil;
local MNP_ShowCount = 0;
local MNP_ScanTick = 0;
local MNP_LastDiagDump = 0;
local MNP_DebugEnabled = false;

-- Spellcast-confirmed healer nameplates.
-- Key = unitToken ("nameplate1", etc.), Value = GetTime() when confirmed.
-- Cleared when the nameplate is removed (NAME_PLATE_UNIT_REMOVED).
local SpellcastConfirmed = {};

-- Cache of enemy healer classes from scoreboard (rebuilt each scan tick).
-- Key = classToken, Value = true.
local EnemyHealerClassCache = {};
local EnemyHealerClassCacheTime = 0;

-- ============================================================
-- DEBUGLOG INTEGRATION
-- ============================================================
local KTH_LOG_NAME = "KTH";

-- Log to DebugLog only.  Never prints to chat.
local function DL(category, severity, msg)
    if _G.DLAPI then
        local prefix = "";
        if severity then prefix = severity .. "~"; end
        if category then prefix = prefix .. category .. "~"; end
        pcall(_G.DLAPI.DebugLog, KTH_LOG_NAME, prefix .. (msg or ""));
    end
end

-- SafeStr: convert a value to a string, returning "SECRET" if it is a secret value
local function SafeStr(v)
    if v == nil then return "nil"; end
    if not canaccessvalue(v) then return "SECRET"; end
    local ok, s = pcall(tostring, v);
    if ok then return s; end
    return "?";
end

-- SafePrint: the ONLY function that prints to the user's chat frame.
-- Used exclusively for the login banner and explicit slash command responses.
local function SafePrint(msg)
    pcall(HHTD.Print, HHTD, msg);
end

-- ============================================================
-- ALERT SYSTEM: Screen Flash + Sound
-- ============================================================
local AlertFrame = nil;
local AlertCooldownUntil = 0;

local function CreateAlertFrame()
    if AlertFrame then return AlertFrame; end

    local f = CreateFrame("Frame", "KTH_AlertFrame", _G.UIParent);
    f:SetAllPoints(_G.UIParent);
    f:SetFrameStrata("FULLSCREEN_DIALOG");
    f:SetFrameLevel(100);
    f:EnableMouse(false);

    local edgeSize = 80;

    -- Top edge gradient (color at top, transparent at bottom)
    local top = f:CreateTexture(nil, "OVERLAY");
    top:SetPoint("TOPLEFT");
    top:SetPoint("TOPRIGHT");
    top:SetHeight(edgeSize);
    top:SetColorTexture(1, 1, 1, 1);
    f.topEdge = top;

    -- Bottom edge gradient
    local bot = f:CreateTexture(nil, "OVERLAY");
    bot:SetPoint("BOTTOMLEFT");
    bot:SetPoint("BOTTOMRIGHT");
    bot:SetHeight(edgeSize);
    bot:SetColorTexture(1, 1, 1, 1);
    f.botEdge = bot;

    -- Left edge gradient
    local left = f:CreateTexture(nil, "OVERLAY");
    left:SetPoint("TOPLEFT", top, "BOTTOMLEFT");
    left:SetPoint("BOTTOMLEFT", bot, "TOPLEFT");
    left:SetWidth(edgeSize);
    left:SetColorTexture(1, 1, 1, 1);
    f.leftEdge = left;

    -- Right edge gradient
    local right = f:CreateTexture(nil, "OVERLAY");
    right:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT");
    right:SetPoint("BOTTOMRIGHT", bot, "TOPRIGHT");
    right:SetWidth(edgeSize);
    right:SetColorTexture(1, 1, 1, 1);
    f.rightEdge = right;

    -- Animation: 2 pulses (fade in + fade out, repeated)
    local ag = f:CreateAnimationGroup();
    ag:SetLooping("NONE");

    local fadeIn1 = ag:CreateAnimation("Alpha");
    fadeIn1:SetFromAlpha(0);
    fadeIn1:SetToAlpha(1);
    fadeIn1:SetDuration(0.12);
    fadeIn1:SetOrder(1);

    local fadeOut1 = ag:CreateAnimation("Alpha");
    fadeOut1:SetFromAlpha(1);
    fadeOut1:SetToAlpha(0);
    fadeOut1:SetDuration(0.3);
    fadeOut1:SetOrder(2);

    local fadeIn2 = ag:CreateAnimation("Alpha");
    fadeIn2:SetFromAlpha(0);
    fadeIn2:SetToAlpha(0.7);
    fadeIn2:SetDuration(0.12);
    fadeIn2:SetOrder(3);

    local fadeOut2 = ag:CreateAnimation("Alpha");
    fadeOut2:SetFromAlpha(0.7);
    fadeOut2:SetToAlpha(0);
    fadeOut2:SetDuration(0.3);
    fadeOut2:SetOrder(4);

    ag:SetScript("OnFinished", function() f:SetAlpha(0); end);
    f.animGroup = ag;

    f:SetAlpha(0);
    f:Show();
    AlertFrame = f;
    return f;
end

local function ApplyAlertColor(frame)
    local c = SETTINGS.alertColor or DEFAULT_SETTINGS.alertColor;
    local r, g, b, a = c.r or 1, c.g or 0, c.b or 0, c.a or 0.6;

    -- Apply gradients to each edge
    pcall(function()
        local solid = CreateColor(r, g, b, a);
        local clear = CreateColor(r, g, b, 0);
        frame.topEdge:SetGradient("VERTICAL", clear, solid);
        frame.botEdge:SetGradient("VERTICAL", solid, clear);
        frame.leftEdge:SetGradient("HORIZONTAL", solid, clear);
        frame.rightEdge:SetGradient("HORIZONTAL", clear, solid);
    end)
end

local function TriggerHealerAlert(classToken)
    local now = GetTime();
    local cooldown = SETTINGS.alertCooldown or 5;
    if now < AlertCooldownUntil then return; end
    AlertCooldownUntil = now + cooldown;

    -- Play sound
    local soundKey = SETTINGS.alertSound or "raidwarn";
    if soundKey ~= "none" then
        local snd = ALERT_SOUNDS[soundKey];
        if snd and snd.id then
            pcall(_G.PlaySound, snd.id, "Master");
        end
    end

    -- Flash screen edges
    if SETTINGS.alertFlash then
        local frame = CreateAlertFrame();
        if frame then
            ApplyAlertColor(frame);
            frame:SetAlpha(0);
            frame.animGroup:Stop();
            frame.animGroup:Play();
        end
    end

    DL("ALERT", "OK", "Healer alert fired for " .. SafeStr(classToken));
end

-- ============================================================
-- ENEMY HEALER CLASS CACHE (from scoreboard)
-- ============================================================
-- Returns a set of class tokens that have at least one enemy healer
-- according to the scoreboard data in MN_HealersByName.
local function RebuildEnemyHealerClassCache()
    local now = GetTime();
    -- Only rebuild once per second to avoid per-nameplate overhead
    if now - EnemyHealerClassCacheTime < 1.0 then return; end
    EnemyHealerClassCacheTime = now;

    local newCache = {};
    local byName = HHTD.MN_HealersByName;
    if byName then
        for _, rec in pairs(byName) do
            if not rec.isFriend and rec.classToken and canaccessvalue(rec.classToken) then
                newCache[rec.classToken] = true;
            end
        end
    end
    EnemyHealerClassCache = newCache;
end

-- ============================================================
-- INDICATOR CREATION / UPDATE
-- ============================================================
local function CreateIndicator(plate)
    local ok, result = pcall(function()
        local frame = CreateFrame("Frame", nil, plate);
        frame:SetSize(SETTINGS.indicatorSize, SETTINGS.indicatorSize);
        frame:SetPoint("BOTTOM", plate, "TOP", 0, SETTINGS.offsetY);
        frame:SetFrameStrata("HIGH");
        local ok2, level = pcall(function() return plate:GetFrameLevel() end);
        frame:SetFrameLevel((ok2 and level or 5) + 10);

        local tex = frame:CreateTexture(nil, "OVERLAY");
        tex:SetAllPoints(frame);
        frame.texture = tex;

        local glow = frame:CreateTexture(nil, "BACKGROUND");
        glow:SetPoint("CENTER");
        glow:SetSize(SETTINGS.indicatorSize * 1.5, SETTINGS.indicatorSize * 1.5);
        glow:SetTexture(GLOW_TEXTURE);
        glow:SetBlendMode("ADD");
        frame.glow = glow;

        frame:Hide();
        return frame;
    end)
    return ok and result or nil;
end

local function ApplyIndicatorStyle(indicator, isFriend, classToken)
    if not indicator then return; end

    -- Determine icon and color, checking per-class overrides first
    local presetKey = isFriend and SETTINGS.friendIcon or SETTINGS.enemyIcon;
    local baseColor = isFriend and SETTINGS.friendColor or SETTINGS.enemyColor;
    local r, g, b, a = baseColor.r, baseColor.g, baseColor.b, baseColor.a;

    if classToken and SETTINGS.classOverrides then
        local ov = SETTINGS.classOverrides[classToken];
        if ov then
            -- Override icon if set
            if ov.icon and ICON_PRESETS[ov.icon] then
                presetKey = ov.icon;
            end
            -- Override color if any channel is set
            if ov.colorR then r = ov.colorR; end
            if ov.colorG then g = ov.colorG; end
            if ov.colorB then b = ov.colorB; end
        end
    end

    local preset = ICON_PRESETS[presetKey] or ICON_PRESETS.cross;

    if indicator.texture then
        indicator.texture:SetTexture(preset.path);
        indicator.texture:SetVertexColor(r, g, b, a);
    end
    if indicator.glow then
        if SETTINGS.showGlow then
            indicator.glow:SetVertexColor(r, g, b, 0.5);
            indicator.glow:Show();
        else
            indicator.glow:Hide();
        end
    end
    indicator:SetSize(SETTINGS.indicatorSize, SETTINGS.indicatorSize);
end

-- ============================================================
-- SHOW / HIDE
-- ============================================================
local function ShowIndicator(plate, isFriend, classToken)
    if not plate then return; end
    local indicator = PlateIndicators[plate];
    if not indicator then
        indicator = CreateIndicator(plate);
        if not indicator then return; end
        PlateIndicators[plate] = indicator;
    end
    ApplyIndicatorStyle(indicator, isFriend, classToken);
    indicator:ClearAllPoints();
    indicator:SetPoint("BOTTOM", plate, "TOP", 0, SETTINGS.offsetY);
    local wasShown = indicator:IsShown();
    if not wasShown then
        indicator:Show();
        MNP_ShowCount = MNP_ShowCount + 1;
        -- Alert when a NEW enemy healer indicator becomes visible
        if not isFriend and SETTINGS.alertEnabled then
            TriggerHealerAlert(classToken);
        end
    end
    ActivePlates[plate] = true;
end

local function HideIndicator(plate)
    if not plate then return; end
    local indicator = PlateIndicators[plate];
    if indicator and indicator:IsShown() then indicator:Hide(); end
    ActivePlates[plate] = nil;
end

local function HideAllIndicators()
    for plate in pairs(ActivePlates) do HideIndicator(plate); end
end

local function RestyleAllIndicators()
    HideAllIndicators();
end

-- ============================================================
-- HEALER CHECK
-- ============================================================
-- Returns: isHealer (bool), isFriend (bool), method (string or nil), classToken (string or nil)
local function CheckUnitIsHealer(unitToken)
    local okA, canAttack = pcall(UnitCanAttack, "player", unitToken);
    if not okA then return false, false, nil; end
    if canAttack and not canaccessvalue(canAttack) then return false, false, nil; end
    local isEnemy = canAttack or false;

    -- ---------- FRIENDLY: match by name ----------
    if not isEnemy then
        -- Get class for per-class indicator overrides (always accessible for friendlies)
        local okFC, _, friendClassToken = pcall(UnitClass, unitToken);
        if not (okFC and friendClassToken and canaccessvalue(friendClassToken)) then
            friendClassToken = nil;
        end

        local okN, unitName = pcall(UnitName, unitToken);
        if okN and unitName and canaccessvalue(unitName) then
            local shortName = unitName:match("^([^%-]+)") or unitName;
            local byName = HHTD.MN_HealersByName;
            if byName then
                if byName[shortName] and byName[shortName].isFriend then
                    return true, true, "NAME", friendClassToken;
                end
                for _, record in pairs(byName) do
                    if record.isFriend and record.fullName then
                        local recShort = record.fullName:match("^([^%-]+)") or record.fullName;
                        if recShort == shortName then return true, true, "NAME", friendClassToken; end
                    end
                end
            end
        end
        return false, true, nil, friendClassToken;
    end

    -- ---------- ENEMY: Class-based identification ----------
    local okC, _, classToken = pcall(UnitClass, unitToken);
    if not okC or not classToken or not canaccessvalue(classToken) then
        return false, false, nil;
    end

    -- Must be a healer-capable class
    if not HEALER_CAPABLE_CLASSES[classToken] then return false, false, nil; end

    -- Check primary power type
    local okP, powerType = pcall(UnitPowerType, unitToken);
    if not (okP and powerType ~= nil and canaccessvalue(powerType)) then
        return false, false, nil;
    end

    -- Non-Mana primary = definitely not a healer (no healer spec uses non-Mana primary)
    -- NOTE: For unambiguous classes this filters out DPS specs perfectly.
    -- For ambiguous classes (Paladin/Shaman/Evoker) this check always passes since all
    -- their specs use Mana, but we still do it for correctness.
    if powerType ~= POWER_MANA then
        return false, false, nil;
    end

    -- ---- UNAMBIGUOUS CLASSES: power type is sufficient ----
    if UNAMBIGUOUS_HEALER_CLASSES[classToken] then
        return true, false, "CLASS+PWR", classToken;
    end

    -- ---- AMBIGUOUS CLASSES: need additional confirmation ----
    -- Check 1: Spellcast confirmation (most reliable — this specific unit cast a heal)
    if SpellcastConfirmed[unitToken] then
        return true, false, "SPELL", classToken;
    end

    -- Check 2: Scoreboard class-level confirmation
    -- If the scoreboard says the enemy team has at least one healer of this class,
    -- mark all matching nameplates.  This may produce false positives if there are
    -- both healer and DPS players of the same class (e.g. 1 Holy + 1 Ret Paladin),
    -- but it's much better than marking ALL Paladins/Shamans/Evokers.
    RebuildEnemyHealerClassCache();
    if EnemyHealerClassCache[classToken] then
        return true, false, "CLASS+SCORE", classToken;
    end

    -- No confirmation: don't mark
    return false, false, nil, classToken;
end

-- ============================================================
-- DIAGNOSTIC DUMP (DebugLog only — never prints to chat)
-- ============================================================
local function DeepDiagnosticDump()
    if not MNP_DebugEnabled then return; end
    local now = GetTime();
    if now - MNP_LastDiagDump < 60 then return; end
    MNP_LastDiagDump = now;

    DL("DEEP", "OK", "=== Diagnostic Dump ===");

    -- Healer list from scoreboard
    local mnList = HHTD.MN_HealersByName;
    local hCount = 0;
    if mnList then
        for shortName, rec in pairs(mnList) do
            hCount = hCount + 1;
            if hCount <= 12 then
                DL("DEEP", nil, "  " .. SafeStr(shortName)
                    .. " " .. SafeStr(rec.classToken) .. "/" .. SafeStr(rec.talentSpec)
                    .. " " .. (rec.isFriend and "FRIEND" or "ENEMY"));
            end
        end
    end
    DL("DEEP", nil, "  Total healers: " .. hCount);

    -- Enemy healer class cache
    local cacheStr = "";
    for cls in pairs(EnemyHealerClassCache) do
        cacheStr = cacheStr .. cls .. " ";
    end
    DL("DEEP", nil, "  EnemyHealerClasses: " .. (cacheStr ~= "" and cacheStr or "(none)"));

    -- Spellcast confirmed
    local scCount = 0;
    for _ in pairs(SpellcastConfirmed) do scCount = scCount + 1; end
    DL("DEEP", nil, "  SpellcastConfirmed units: " .. scCount);

    -- Nameplate scan
    local existCount, playerCount = 0, 0;
    for i = 1, MAX_NAMEPLATES do
        local unitToken = "nameplate" .. i;
        if UnitExists(unitToken) then
            existCount = existCount + 1;
            local okP, isPlayer = pcall(UnitIsPlayer, unitToken);
            if okP and isPlayer then
                playerCount = playerCount + 1;

                pcall(function()
                    local okN, uName = pcall(UnitName, unitToken);
                    local nameStr = (okN and uName and canaccessvalue(uName)) and SafeStr(uName) or "SECRET";

                    local okC2, _, uClass = pcall(UnitClass, unitToken);
                    local classStr = (okC2 and uClass and canaccessvalue(uClass)) and SafeStr(uClass) or "SECRET";

                    local okPT, uPT = pcall(UnitPowerType, unitToken);
                    local ptStr = (okPT and uPT ~= nil and canaccessvalue(uPT)) and SafeStr(uPT) or "SECRET";

                    local okAtk, canAtk = pcall(UnitCanAttack, "player", unitToken);
                    local sideStr = "?";
                    if okAtk and canAtk ~= nil and canaccessvalue(canAtk) then
                        sideStr = canAtk and "ENEMY" or "FRIEND";
                    end

                    local scStr = SpellcastConfirmed[unitToken] and " SC:YES" or "";

                    if playerCount <= 14 then
                        DL("DEEP", nil, "  " .. unitToken
                            .. " " .. sideStr
                            .. " name:" .. nameStr
                            .. " class:" .. classStr
                            .. " pwr:" .. ptStr
                            .. scStr);
                    end
                end)
            end
        end
    end
    DL("DEEP", nil, "  Nameplates: " .. existCount .. " exist, " .. playerCount .. " players");
    DL("DEEP", "OK", "=== End Dump ===");
end

-- ============================================================
-- MAIN SCAN
-- ============================================================
local function ScanAllNameplates()
    -- Rebuild the enemy healer class cache once per scan
    RebuildEnemyHealerClassCache();

    local foundPlates, foundPlayers, matchedHealers, scanErrors = 0, 0, 0, 0;
    local methods = { NAME = 0, ["CLASS+PWR"] = 0, CLASS = 0, SPELL = 0, ["CLASS+SCORE"] = 0 };
    local matchedThisTick = {};

    for i = 1, MAX_NAMEPLATES do
        local unitToken = "nameplate" .. i;
        if UnitExists(unitToken) then
            foundPlates = foundPlates + 1;
            local ok, err = pcall(function()
                if not UnitIsPlayer(unitToken) then return; end
                foundPlayers = foundPlayers + 1;
                local isHealer, isFriend, method, classToken = CheckUnitIsHealer(unitToken);
                if not isHealer then return; end
                local plate = C_NamePlate.GetNamePlateForUnit(unitToken);
                if not plate then return; end
                matchedHealers = matchedHealers + 1;
                if method then methods[method] = (methods[method] or 0) + 1; end
                ShowIndicator(plate, isFriend, classToken);
                matchedThisTick[plate] = true;
            end)
            if not ok then
                scanErrors = scanErrors + 1;
                if scanErrors <= 2 then DL("SCAN", "ERR", "Scan err: " .. SafeStr(err)); end
            end
        end
    end

    for plate in pairs(ActivePlates) do
        if not matchedThisTick[plate] then HideIndicator(plate); end
    end

    -- Periodic scan summary (DebugLog only)
    MNP_ScanTick = MNP_ScanTick + 1;
    if MNP_DebugEnabled and MNP_ScanTick % 10 == 0 then
        local mnCount = 0;
        if HHTD.MN_HealersByName then
            for _ in pairs(HHTD.MN_HealersByName) do mnCount = mnCount + 1; end
        end
        DL("SCAN", nil, "plates:" .. foundPlates
            .. " players:" .. foundPlayers
            .. " matched:" .. matchedHealers
            .. " (N:" .. methods.NAME
            .. " CP:" .. (methods["CLASS+PWR"] or 0)
            .. " CS:" .. (methods["CLASS+SCORE"] or 0)
            .. " SP:" .. (methods.SPELL or 0) .. ")"
            .. " err:" .. scanErrors
            .. " list:" .. mnCount);
    end

    if MNP_DebugEnabled and MNP_ScanTick % 60 == 1 then
        DeepDiagnosticDump();
    end
end

-- ============================================================
-- SETTINGS PERSISTENCE
-- ============================================================
local function LoadSettings()
    if type(_G.KTH_NameplateSettings) ~= "table" then
        _G.KTH_NameplateSettings = CopyDefaults();
    end
    local saved = _G.KTH_NameplateSettings;
    -- Migrate missing top-level keys from defaults
    for k, v in pairs(DEFAULT_SETTINGS) do
        if saved[k] == nil then
            saved[k] = DeepCopyTable(v);
        end
    end
    -- Ensure classOverrides has all healer classes
    if type(saved.classOverrides) ~= "table" then
        saved.classOverrides = DeepCopyTable(DEFAULT_SETTINGS.classOverrides);
    else
        for _, cls in pairs(HEALER_CLASS_LIST) do
            if type(saved.classOverrides[cls]) ~= "table" then
                saved.classOverrides[cls] = DeepCopyTable(DEFAULT_SETTINGS.classOverrides[cls]);
            end
        end
    end
    -- Ensure alertColor exists
    if type(saved.alertColor) ~= "table" then
        saved.alertColor = DeepCopyTable(DEFAULT_SETTINGS.alertColor);
    end
    SETTINGS = saved;
    if not ICON_PRESETS[SETTINGS.friendIcon] then SETTINGS.friendIcon = "cross"; end
    if not ICON_PRESETS[SETTINGS.enemyIcon]  then SETTINGS.enemyIcon  = "cross"; end
end

-- ============================================================
-- SPELLCAST HANDLER (for ambiguous class confirmation)
-- ============================================================
local function HandleNameplateSpellcast(unitToken, spellID)
    if not unitToken or not spellID then return; end
    -- Only process nameplate units
    if not unitToken:match("^nameplate%d+$") then return; end
    -- Check if spellID is accessible (may be secret for enemies in Midnight)
    if not canaccessvalue(spellID) then return; end
    -- Check if it's a healer-specific spell
    if not (HHTD_C.Healers_Only_Spells_ByID_Lookup and HHTD_C.Healers_Only_Spells_ByID_Lookup[spellID]) then
        return;
    end
    -- Confirm this nameplate as a healer
    if not SpellcastConfirmed[unitToken] then
        SpellcastConfirmed[unitToken] = GetTime();
        DL("SPELL", "OK", "Spellcast confirmed healer: " .. SafeStr(unitToken) .. " spell:" .. SafeStr(spellID));
        -- Trigger immediate indicator update for this nameplate
        pcall(function()
            if not UnitExists(unitToken) then return; end
            local plate = C_NamePlate.GetNamePlateForUnit(unitToken);
            if not plate then return; end
            local isHealer, isFriend, method, classToken = CheckUnitIsHealer(unitToken);
            if isHealer then
                ShowIndicator(plate, isFriend, classToken);
            end
        end)
    end
end

-- ============================================================
-- EVENT HANDLER
-- ============================================================
local EventFrame = CreateFrame("Frame", "HHTD_MidnightNameplates");
EventFrame:RegisterEvent("ADDON_LOADED");
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
EventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED");
EventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED");
EventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED");
EventFrame:RegisterEvent("UNIT_SPELLCAST_START");

EventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...;
        if name == ADDON_NAME or name == "HHTD" then
            LoadSettings();
        end

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unitToken = ...;
        if not unitToken then return; end
        pcall(function()
            if not UnitIsPlayer(unitToken) then return; end
            local isHealer, isFriend, method, classToken = CheckUnitIsHealer(unitToken);
            if not isHealer then return; end
            local plate = C_NamePlate.GetNamePlateForUnit(unitToken);
            if not plate then return; end
            ShowIndicator(plate, isFriend, classToken);
            DL("EVENT", "OK", "Healer plate via " .. SafeStr(method)
                .. " (" .. (isFriend and "friendly" or "hostile") .. ") " .. SafeStr(unitToken));
        end)

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unitToken = ...;
        if unitToken then
            -- Clear spellcast confirmation for this nameplate slot
            SpellcastConfirmed[unitToken] = nil;
            pcall(function()
                local plate = C_NamePlate.GetNamePlateForUnit(unitToken);
                if plate then HideIndicator(plate); end
            end)
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_START" then
        local unitToken, _, spellID = ...;
        pcall(HandleNameplateSpellcast, unitToken, spellID);

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not SETTINGS.offsetY then LoadSettings(); end
        HideAllIndicators();
        -- Clear spellcast confirmations on zone change
        SpellcastConfirmed = {};
        EnemyHealerClassCache = {};
        EnemyHealerClassCacheTime = 0;
        if not MNP_Enabled then
            MNP_Enabled = true;
            -- This is the ONLY message KTH prints to chat automatically.
            local dlMsg = _G.DLAPI and " Diagnostics route to DebugLog." or "";
            SafePrint("|cff00ff00[K.T.H.]|r Kill The Healer active. Type |cffffffff/kthg|r for settings." .. dlMsg);
        end
        if not scanTimer then
            scanTimer = C_Timer.NewTicker(SCAN_INTERVAL, function() pcall(ScanAllNameplates); end);
        end
        C_Timer.After(3, function() pcall(ScanAllNameplates); end);
        if MNP_DebugEnabled then
            C_Timer.After(8, function() MNP_LastDiagDump = 0; pcall(DeepDiagnosticDump); end);
        end
    end
end)

-- Hook HHTD_HEALER_BORN for immediate rescan
C_Timer.After(3, function()
    if HHTD.RegisterCallback then
        pcall(function()
            HHTD.RegisterCallback(EventFrame, "HHTD_HEALER_BORN", function()
                pcall(ScanAllNameplates);
            end)
        end)
    end
end)

-- Status for auto-diag
HHTD.MNP_GetStatus = function()
    local scCount = 0;
    for _ in pairs(SpellcastConfirmed) do scCount = scCount + 1; end
    local ehcCount = 0;
    for _ in pairs(EnemyHealerClassCache) do ehcCount = ehcCount + 1; end
    return "KTH: " .. (MNP_Enabled and "ON" or "OFF")
        .. " shown:" .. MNP_ShowCount
        .. " sc:" .. scCount
        .. " ehc:" .. ehcCount;
end

-- Expose debug state for KTH_Options.lua to read/write
HHTD.MNP_DebugEnabled = MNP_DebugEnabled;
HHTD.MNP_SetDebug = function(enabled)
    MNP_DebugEnabled = enabled;
    HHTD.MNP_DebugEnabled = enabled;
    if HHTD.MN_Diag then
        HHTD.MN_Diag.diagEnabled = enabled;
    end
end
HHTD.MNP_GetDebug = function()
    return MNP_DebugEnabled;
end

-- Expose constants for KTH_Options.lua
HHTD.MNP_ALERT_SOUNDS       = ALERT_SOUNDS;
HHTD.MNP_HEALER_CLASS_LIST  = HEALER_CLASS_LIST;
HHTD.MNP_HEALER_CLASS_DISPLAY = HEALER_CLASS_DISPLAY;
HHTD.MNP_ICON_PRESETS        = ICON_PRESETS;

-- Test alert from settings panel
HHTD.MNP_TestAlert = function()
    local saved = AlertCooldownUntil;
    AlertCooldownUntil = 0; -- bypass cooldown for test
    TriggerHealerAlert("TEST");
    AlertCooldownUntil = saved;
end

-- ============================================================
-- SLASH COMMANDS
-- ============================================================

local function ListIconPresets()
    SafePrint("|cff00ff00[K.T.H.]|r Available icons:");
    for key, preset in pairs(ICON_PRESETS) do
        SafePrint("  |cffffffff" .. key .. "|r -- " .. preset.label);
    end
end

local function ShowCurrentSettings()
    SafePrint("|cff00ff00[K.T.H.]|r Current settings:");
    SafePrint("  offset: |cffffffff" .. tostring(SETTINGS.offsetY) .. "|r  size: |cffffffff" .. tostring(SETTINGS.indicatorSize) .. "|r");
    SafePrint("  friend icon: |cffffffff" .. tostring(SETTINGS.friendIcon) .. "|r  enemy icon: |cffffffff" .. tostring(SETTINGS.enemyIcon) .. "|r");
    SafePrint("  glow: |cffffffff" .. (SETTINGS.showGlow and "on" or "off") .. "|r");
    SafePrint("  debug: |cffffffff" .. (MNP_DebugEnabled and "on" or "off") .. "|r");
    SafePrint("  Type |cffffffff/kthg|r for graphical settings panel.");
end

local function PrintHelp()
    SafePrint("|cff00ff00[K.T.H.]|r Commands:");
    SafePrint("  |cffffffff/kth|r                     -- show current settings");
    SafePrint("  |cffffffff/kth help|r                -- show this help");
    SafePrint("  |cffffffff/kth icons|r               -- list icon presets");
    SafePrint("  |cffffffff/kth offset <num>|r        -- Y offset above nameplate");
    SafePrint("  |cffffffff/kth size <num>|r          -- indicator size (8-128)");
    SafePrint("  |cffffffff/kth icon friend <preset>|r-- friendly healer icon");
    SafePrint("  |cffffffff/kth icon enemy <preset>|r -- enemy healer icon");
    SafePrint("  |cffffffff/kth glow on|off|r         -- toggle glow halo");
    SafePrint("  |cffffffff/kth reset|r               -- restore defaults");
    SafePrint("  |cffffffff/kthg|r                    -- open graphical settings panel");
    SafePrint("  |cffffffff/kthdebug|r                -- toggle DebugLog diagnostics");
    SafePrint("  |cffffffff/kthdiag|r                 -- one-shot diagnostic dump");
end

SLASH_KTH1 = "/kth";
SlashCmdList["KTH"] = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "");
    if msg == "" then
        ShowCurrentSettings();
        return;
    end

    local cmd, rest = msg:match("^(%S+)%s*(.*)$");
    cmd = (cmd or ""):lower();
    rest = rest or "";

    if cmd == "help" or cmd == "?" then
        PrintHelp();

    elseif cmd == "icons" or cmd == "list" then
        ListIconPresets();

    elseif cmd == "offset" then
        local n = tonumber(rest);
        if not n then
            SafePrint("|cffff0000[K.T.H.]|r Usage: /kth offset <number>  (current: " .. tostring(SETTINGS.offsetY) .. ")");
            return;
        end
        SETTINGS.offsetY = n;
        RestyleAllIndicators();
        SafePrint("|cff00ff00[K.T.H.]|r Offset set to " .. n);

    elseif cmd == "size" then
        local n = tonumber(rest);
        if not n or n < 8 or n > 128 then
            SafePrint("|cffff0000[K.T.H.]|r Usage: /kth size <number 8-128>  (current: " .. tostring(SETTINGS.indicatorSize) .. ")");
            return;
        end
        SETTINGS.indicatorSize = n;
        for plate, ind in pairs(PlateIndicators) do
            if ind then pcall(function() ind:Hide(); ind:SetParent(nil); end) end
            PlateIndicators[plate] = nil;
        end
        HideAllIndicators();
        SafePrint("|cff00ff00[K.T.H.]|r Size set to " .. n);

    elseif cmd == "icon" then
        local side, preset = rest:match("^(%S+)%s+(%S+)$");
        side = (side or ""):lower();
        preset = (preset or ""):lower();
        if (side ~= "friend" and side ~= "enemy") or not ICON_PRESETS[preset] then
            SafePrint("|cffff0000[K.T.H.]|r Usage: /kth icon friend|enemy <preset>");
            ListIconPresets();
            return;
        end
        if side == "friend" then
            SETTINGS.friendIcon = preset;
        else
            SETTINGS.enemyIcon = preset;
        end
        RestyleAllIndicators();
        SafePrint("|cff00ff00[K.T.H.]|r " .. side .. " icon set to " .. preset);

    elseif cmd == "glow" then
        local v = rest:lower();
        if v == "on" or v == "true" or v == "1" then
            SETTINGS.showGlow = true;
        elseif v == "off" or v == "false" or v == "0" then
            SETTINGS.showGlow = false;
        else
            SafePrint("|cffff0000[K.T.H.]|r Usage: /kth glow on|off");
            return;
        end
        RestyleAllIndicators();
        SafePrint("|cff00ff00[K.T.H.]|r Glow " .. (SETTINGS.showGlow and "enabled" or "disabled"));

    elseif cmd == "reset" then
        _G.KTH_NameplateSettings = CopyDefaults();
        SETTINGS = _G.KTH_NameplateSettings;
        for plate, ind in pairs(PlateIndicators) do
            if ind then pcall(function() ind:Hide(); ind:SetParent(nil); end) end
            PlateIndicators[plate] = nil;
        end
        HideAllIndicators();
        SafePrint("|cff00ff00[K.T.H.]|r Settings reset to defaults.");

    else
        SafePrint("|cffff0000[K.T.H.]|r Unknown command: " .. cmd);
        PrintHelp();
    end
end

-- Toggle debug mode (DebugLog only — no chat spam)
SLASH_KTHDEBUG1 = "/kthdebug";
SlashCmdList["KTHDEBUG"] = function()
    MNP_DebugEnabled = not MNP_DebugEnabled;
    HHTD.MNP_DebugEnabled = MNP_DebugEnabled;
    if HHTD.MN_Diag then
        HHTD.MN_Diag.diagEnabled = MNP_DebugEnabled;
    end
    if MNP_DebugEnabled then
        local dest = _G.DLAPI and "DebugLog" or "nowhere (install DebugLog addon to see output)";
        SafePrint("|cff00ff00[K.T.H.]|r Diagnostics |cff00ff00ON|r — output to " .. dest .. ".");
        MNP_LastDiagDump = 0;
        pcall(DeepDiagnosticDump);
    else
        SafePrint("|cff00ff00[K.T.H.]|r Diagnostics |cffff0000OFF|r.");
    end
end

-- Manual diagnostic dump
SLASH_KTHDIAG1 = "/kthdiag";
SlashCmdList["KTHDIAG"] = function()
    local savedDebug = MNP_DebugEnabled;
    MNP_DebugEnabled = true;
    MNP_LastDiagDump = 0;
    DeepDiagnosticDump();
    MNP_DebugEnabled = savedDebug;
    local dest = _G.DLAPI and "DebugLog" or "nowhere (install DebugLog addon)";
    SafePrint("|cff00ff00[K.T.H.]|r Dump sent to " .. dest .. ".");
end

-- EOF padding (guards against file-sync truncation)
-- DO NOT REMOVE THESE LINES
-- EOF
-- EOF
