-- v2.2.14 permanent regression for the in-BG taint error (live 2026-10-08 count 1433; run 11 2026-10-09 count 1099):
--   "attempted to iterate a table that cannot be accessed while tainted (execution tainted by 'ForeverDump')",
--   Locals: BattlegroundChatFilters <BattlegroundChatFilters.xml:3>, while "N players have joined the battle" repeats.
-- Real mechanism (1.60.1.70245 source, verified v2.2.14; the v2.2.12 model of fading state that resets was wrong):
--   BattlegroundChatFilters OnUpdate: loop 1 counts ADDED_PLAYERS (restricted: secret-name keys) ->
--   DEFAULT_CHAT_FRAME:AddMessage(summary) -> ScrollingMessageFrameMixin:AddMessage -> historyBuffer:PushFront ->
--   headIndex:Increment() = SetValue(GetValue() + 1); SetValue writes SecureNumber.value in the CALLER's context ->
--   loop 2 `for i in next, ADDED_PLAYERS` errors if that read was tainted. One addon AddMessage on the frame writes
--   `value` tainted; each later secure AddMessage reads it tainted and writes it back tainted -> it never heals.
--   (taint log 10/8: "Execution tainted by ForeverDump while reading field value - SecureTypes.lua:279 ... PushFront")
-- The test models exactly that (control: ONE addon line an hour before the BG still reproduces the error), then
-- drives the addon through a whole session (open world + BG) and requires zero lines into Blizzard chat.
-- usage: lua5.1 tests/bg_chat_taint.lua ForeverDump
package.path = "./tests/?.lua;" .. package.path
local addonDir = arg[1] or "ForeverDump"
local out = function(s) io.write(s, "\n") end
local fails, passed = 0, 0
local function check(c, m) if c then passed = passed + 1 out("  ok   " .. m) else fails = fails + 1 out("  FAIL " .. m) end end
local W = require("wowenv")
local S = W.state

-- real-source model of ChatFrame1's history buffer head index (SecureTypes.SecureNumber)
local CF = DEFAULT_CHAT_FRAME
local secureDepth = 0
local head = { value = 0, taint = nil }
CF.addonLines = 0
local baseAdd = CF.AddMessage
local function addMessage(self, msg, ...)
    local exec = nil                                             -- caller's taint
    if secureDepth == 0 then exec = "addon" end
    if secureDepth == 0 then self.addonLines = self.addonLines + 1 end
    local v = head.value                                         -- GetValue (securecallfunction): reads the field
    if head.taint then exec = exec or head.taint end             -- reading a tainted field taints execution
    head.value, head.taint = v + 1, exec                         -- SetValue in the caller's context
    baseAdd(self, msg, ...)
    return exec                                                  -- the caller's execution taint after the call
end
CF.AddMessage = addMessage
-- print() lands in DEFAULT_CHAT_FRAME on the client
local realPrint = print
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
    return CF:AddMessage(table.concat(t, " ")) end

-- BattlegroundChatFilters OnUpdate, reduced to the failing path (loop 1, AddMessage, loop 2)
local BG = { added = {}, restricted = false, errors = 0, printed = 0 }
function BG.joined(name) BG.added[name] = true BG.restricted = true end
function BG.onUpdate()
    secureDepth = secureDepth + 1
    local n = 0
    for _ in next, BG.added do n = n + 1 end
    if n > 0 then
        local taint = CF:AddMessage(string.format("%d players have joined the battle.", n))
        BG.printed = BG.printed + 1
        if taint and BG.restricted then
            BG.errors = BG.errors + 1   -- loop 2: "attempted to iterate a table that cannot be accessed while tainted"
        else
            for k in next, BG.added do BG.added[k] = nil end
            BG.restricted = false
        end
    end
    secureDepth = secureDepth - 1
end
local function blizzLine(m) secureDepth = secureDepth + 1 CF:AddMessage(m) secureDepth = secureDepth - 1 end

-- control: ONE addon line in the open world, an hour of normal Blizzard chat, then a BG -> still the live error
CF:AddMessage("addon line in the open world")
S.time = S.time + 3600
for i = 1, 50 do blizzLine("guild chat " .. i) end
for i = 1, 3 do BG.joined("p" .. i) end
BG.onUpdate() BG.onUpdate()
check(BG.errors == 2 and BG.printed == 2, "control: one open-world addon line an hour earlier still breaks the BG filter every update ("
    .. BG.errors .. ") - the taint never fades")
-- control 2: a clean session never errors
head.value, head.taint = 0, nil
BG.errors, BG.printed, BG.added, BG.restricted = 0, 0, {}, false
for i = 1, 3 do BG.joined("p" .. i) end
BG.onUpdate()
check(BG.errors == 0 and BG.printed == 1, "control: clean chat frame -> summary printed, table cleared, no error")
head.value, head.taint, CF.addonLines = 0, nil, 0
BG.printed = 0
print = realPrint

-- the addon, a whole session: login in the open world, FD_Logs ON/OFF, slash commands, errors, then a BG
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
    return CF:AddMessage(table.concat(t, " ")) end
local files = {}
for line in io.lines(addonDir .. "/ForeverDump.toc") do
    if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
end
local inInstance, itype = false, "none"
IsInInstance = function() return inInstance, itype end
ForeverDumpDB = { addonVersion = "2.2.11" }   -- run 11: the file was last written by a stale install
local blizz0 = #W.blizzChat
local ns = W.loadAddon(addonDir, files, "ForeverDump")
W.fire("ADDON_LOADED", "ForeverDump")
W.fire("PLAYER_LOGIN")
W.fire("PLAYER_ENTERING_WORLD", true, false)
W.tick(5)
W.slash("") W.slash("status") W.slash("version") W.slash("logs on") W.tick(3) W.slash("level status") W.slash("cl status")
W.slash("logs off") W.tick(3) W.slash("msgs 5")
ns.Print("direct ns.Print in the open world")
if ns.Errors and ns.Errors.Capture then pcall(ns.Errors.Capture, "ForeverDump/Test.lua:1: boom") end
S.combat = true W.fire("PLAYER_REGEN_DISABLED") ns.Print("in combat") S.combat = false W.fire("PLAYER_REGEN_ENABLED") W.tick(5)
-- enter a battleground
inInstance, itype = true, "pvp"
W.fire("PLAYER_ENTERING_WORLD", false, false) W.tick(3)
W.slash("logs on") W.tick(3) W.slash("status")
for i = 1, 6 do BG.joined("p" .. i) end
for _ = 1, 5 do BG.onUpdate() end
W.slash("logs off") W.tick(3)
inInstance, itype = false, "none"
W.fire("PLAYER_ENTERING_WORLD", false, false) W.tick(10)
print = realPrint
check(CF.addonLines == 0 and #W.blizzChat - blizz0 == BG.printed, "whole session: no ForeverDump line or print() reached Blizzard chat ("
    .. CF.addonLines .. ")")
check(head.taint == nil, "ChatFrame1 history head index never written by addon code")
check(BG.errors == 0 and BG.printed >= 1, "BattlegroundChatFilters summary + table iteration runs untainted (" .. BG.errors .. " errors)")
local seen = #W.chat
check(seen >= 10, "lines went to our own message frame instead (" .. seen .. ")")
local verLines, notice = 0, false
for _, l in ipairs(W.chat) do
    if l:find("ForeverDump " .. ns.VERSION, 1, true) then verLines = verLines + 1 end
    if l:find("last written by 2.2.11, now running " .. ns.VERSION, 1, true) then notice = true end
end
check(verLines == seen, "every line carries the running version " .. ns.VERSION .. " (" .. verLines .. "/" .. seen .. ")")
check(notice, "login notice: SavedVariables last written by 2.2.11, now running " .. ns.VERSION)

-- static: nothing in the addon names a Blizzard chat frame, chat filter, chat colour table or print()
local function src(f) local h = assert(io.open(addonDir .. "/" .. f:gsub("\\", "/"))) local s = h:read("*a") h:close() return s end
local bad = {}
for _, f in ipairs(files) do
    local s = src(f):gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", ""):gsub('"[^"\n]*"', '""')   -- code only
    for _, pat in ipairs({ "DEFAULT_CHAT_FRAME", "SELECTED_CHAT_FRAME", "ChatFrame%d", "AddMessageEventFilter", "hooksecurefunc",
        "ChatFrameUtil", "ChatTypeInfo", "ChangeChatColor", "ChatFrame_", "FCF_", "SendSystemMessage", "ADDED_PLAYERS",
        "PLAYER_LIST_DELIMITER", "[^%w_%.:]print%s*%(", "pcall%(%s*print%s*,", "rawget%(%s*_G%s*,%s*\"\"%s*%)%s*:%s*AddMessage" }) do
        for _ in s:gmatch(pat) do bad[#bad + 1] = f .. ":" .. pat end
    end
    -- no string-built access to a Blizzard chat frame either
    local raw = src(f):gsub("%-%-[^\n]*", "")
    for _, name in ipairs({ "DEFAULT_CHAT_FRAME", "SELECTED_CHAT_FRAME", "ChatFrame1", "ChatTypeInfo", "ADDED_PLAYERS" }) do
        if raw:find('"' .. name .. '"', 1, true) then bad[#bad + 1] = f .. ":\"" .. name .. "\"" end
    end
end
check(#bad == 0, "static: no reference to Blizzard chat frames / chat filters / ChatTypeInfo / print (" .. table.concat(bad, ", ") .. ")")
-- events: we may listen to CHAT_MSG_SYSTEM on our own frame, but never register it on a Blizzard frame
local regs = {}
for _, f in ipairs(files) do
    local raw = src(f):gsub("%-%-[^\n]*", "")
    for obj in raw:gmatch("([%w_%.]+)%s*:%s*RegisterEvent%s*%(%s*\"CHAT_MSG") do regs[#regs + 1] = f .. ":" .. obj end
end
check(#regs == 0, "static: no direct CHAT_MSG_* RegisterEvent outside ns.On's own event frame (" .. table.concat(regs, ", ") .. ")")
out(string.format("bg_chat_taint: %d passed, %d failed", passed, fails))
if fails > 0 then os.exit(1) end
