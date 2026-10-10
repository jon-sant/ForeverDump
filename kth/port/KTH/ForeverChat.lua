-- [Forever] K.T.H. Forever port - ForeverChat.lua (new file, port helper; not part of the original K.T.H.)
-- K.T.H. prints through AceConsole (HHTD:Print -> DEFAULT_CHAT_FRAME). On Forever, addon writes into Blizzard chat
-- frames can taint ChatFrame1 and break BattlegroundChatFilters, so every K.T.H. Print/Printf goes to K.T.H.'s own
-- message frame instead. Nothing else about the messages changes. /kthlog shows/hides the frame.
-- K.T.H. is (c) John Wellesz (H.H.T.D.) and Scone (K.T.H.), All Rights Reserved; private port, no redistribution.
local ADDON_NAME, T = ...;
local HHTD = T.HHTD;
if not (T.FS and T.FS.IS_FOREVER) then return; end

local f;
local function Frame()
    if f then return f; end
    f = CreateFrame("ScrollingMessageFrame", "KTH_ForeverMessageFrame", UIParent);
    f:SetSize(420, 110);
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -180);
    pcall(f.SetFontObject, f, _G.GameFontHighlightSmall or _G.ChatFontNormal);
    f:SetJustifyH("LEFT");
    f:SetFading(true);
    f:SetFadeDuration(3);
    f:SetTimeVisible(20);
    f:SetMaxLines(200);
    f:SetMovable(true);
    f:EnableMouse(false);
    return f;
end

local tostring, select, type, format = tostring, select, type, string.format;

local function Print(self, ...)
    local first = ...;
    local n, start = select("#", ...), 1;
    if type(first) == "table" and first.AddMessage then start = 2; end -- an explicit chat frame is ignored too
    local parts = {};
    for i = start, n do parts[#parts + 1] = tostring((select(i, ...))); end
    Frame():AddMessage("|cff33ff99K.T.H.|r: " .. table.concat(parts, " "));
end

local function Printf(self, ...)
    local first = ...;
    if type(first) == "table" and first.AddMessage then return Print(self, format(select(2, ...))); end
    return Print(self, format(...));
end

HHTD.Print, HHTD.Printf = Print, Printf;
for _, module in HHTD:IterateModules() do
    module.Print, module.Printf = Print, Printf;
    if module.IterateModules then
        for _, sub in module:IterateModules() do sub.Print, sub.Printf = Print, Printf; end
    end
end
if HHTD.MODULE_PROTOTYPE then HHTD.MODULE_PROTOTYPE.Print, HHTD.MODULE_PROTOTYPE.Printf = Print, Printf; end

HHTD.ForeverMessageFrame = Frame;
SLASH_KTHLOG1 = "/kthlog";
SlashCmdList["KTHLOG"] = function()
    local fr = Frame();
    if fr:IsShown() then fr:Hide(); else fr:Show(); end
end

-- [Forever] F4 (diagnostic only, no behaviour change): /kthsound plays K.T.H.'s five alert sounds and writes each call's
-- willPlay result to K.T.H.'s own frame. The sound-kit IDs (8959/8174/8960, nameplate alert) and file IDs
-- (567458/567482, mouseover/target announcer) are not in ForeverDump's static data, so whether Forever ships them is
-- unmeasured; this measures it in game. Results are also kept in HHTD.ForeverSoundTest.
SLASH_KTHSOUND1 = "/kthsound";
SlashCmdList["KTHSOUND"] = function()
    local res = {};
    HHTD.ForeverSoundTest = res;
    local tests = {
        { "PlaySound", 8959, "nameplate alert raidwarn" }, { "PlaySound", 8174, "nameplate alert pvpflag" },
        { "PlaySound", 8960, "nameplate alert readychk" }, { "PlaySoundFile", 567458, "mouseover announcer" },
        { "PlaySoundFile", 567482, "target-lock announcer" },
    };
    Frame():Show();
    for i, t in ipairs(tests) do C_Timer.After((i - 1) * 2, function() -- one sound every 2 s
        local fn = _G[t[1]];
        local ok, willPlay = false, "missing";
        if type(fn) == "function" then ok, willPlay = pcall(fn, t[2], "Master"); end
        local wp = (T.FS and T.FS.bool(willPlay));
        res[i] = { api = t[1], id = t[2], what = t[3], ok = ok, willPlay = wp, raw = tostring(T.FS and T.FS.clear(willPlay)) };
        Print(HHTD, ("%s(%d) [%s]: ok=%s willPlay=%s"):format(t[1], t[2], t[3], tostring(ok), tostring(wp == nil and res[i].raw or wp)));
    end) end
end

-- [Forever] forever.7 (diagnostic only) / forever.11: /kthdebug = alias of the /kthg General "Enable Debug Logging"
-- checkbox (HHTD.KTH_DebugOn / HHTD.MNP_SetDebug, MidnightNameplates.lua). (none) flips it; on | off set it;
-- status shows it; clear empties the meter/verdict log kept in K.T.H.'s SavedVariables.
local function DebugOn()
    if HHTD.KTH_DebugOn then return HHTD.KTH_DebugOn(); end
    local g = HHTD.db and HHTD.db.global;
    return not (type(g) == "table" and g.ForeverDebugOff);
end
local function SetDebug(v)
    if HHTD.MNP_SetDebug then HHTD.MNP_SetDebug(v); return; end
    local g = HHTD.db and HHTD.db.global;
    if type(g) == "table" then g.ForeverDebugOff = (not v) or nil; end
end
SLASH_KTHDEBUG1 = "/kthdebug";
SlashCmdList["KTHDEBUG"] = function(msg)
    local g = HHTD.db and HHTD.db.global;
    if type(g) ~= "table" then return; end
    msg = type(msg) == "string" and msg:lower():gsub("^%s+", ""):gsub("%s+$", "") or "";
    if msg == "off" then SetDebug(false);
    elseif msg == "on" then SetDebug(true);
    elseif msg == "clear" then g.ForeverDebug = nil;
    elseif msg == "" then SetDebug(not DebugOn()); end
    local root = g.ForeverDebug;
    local n, reads = 0, 0;
    if type(root) == "table" and type(root.sessions) == "table" then
        n = #root.sessions;
        for _, s in ipairs(root.sessions) do reads = reads + #(s.meter or {}); end
    end
    Frame():Show();
    Print(HHTD, ("debug %s: %d session(s), %d meter read(s)"):format(DebugOn() and "ON" or "OFF", n, reads));
end
