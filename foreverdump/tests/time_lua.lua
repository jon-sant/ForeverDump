-- Time audit 2026-10-10 (Lua side). usage: lua5.1 tests/time_lua.lua ForeverDump   (runner: once per TZ)
-- 1. no addon file writes isdst into a date() table or calls time(table) (run 9 taint) outside Core's TimeAnchor
-- 2. CombatLog.lua utcOffset comes from Core.TimeAnchor; AuraPresence's anchor is Core.TimeAnchor (tick-refined epoch)
-- 3. Drift.DayNumber = civil day count (month / year / leap rollovers), zone-free
local dir = arg[1] or "ForeverDump"
local fails = 0
local function check(c, msg) if not c then fails = fails + 1; print("FAIL " .. msg) end end
local function read(f) local h = assert(io.open(dir .. "/" .. f)); local s = h:read("*a"); h:close(); return s end

for _, f in ipairs({ "CombatLog.lua", "AuraPresence.lua", "Drift.lua", "ReplayLog.lua" }) do
    local ok, s = pcall(read, f)
    if ok then
        local code = s:gsub("%-%-[^\n]*", "")
        check(not code:find("isdst", 1, true), f .. ": writes/reads isdst")
        check(not code:find("time%(%s*[%a_]+%s*%)") or code:find("time%(%s*%)"), f .. ": time(table) call")
        check(not code:find("[^%w_]tf%(%s*{"), f .. ": time{...} call")
    end
end
local cl = read("CombatLog.lua"):match("local function utcOffset%(%).-\nend")
check(cl and cl:find("ns.TimeAnchor", 1, true), "CombatLog utcOffset uses ns.TimeAnchor")
check(read("AuraPresence.lua"):find("d.anchor = ns.TimeAnchor and ns.TimeAnchor()", 1, true), "AuraPresence anchor = ns.TimeAnchor()")

local body = read("Drift.lua"):match("(function D%.DayNumber%(y, m, d%).-\nend)")
check(body, "Drift.DayNumber present")
local D = {}
assert(loadstring("local D = ...\n" .. body))(D)
local function ref(y, m, d) return math.floor(os.time({ year = y, month = m, day = d, hour = 12 }) / 86400) end
check(D.DayNumber(1970, 1, 1) == 0, "epoch day 0")
check(D.DayNumber(2026, 10, 10) == 20736, "2026-10-10 = day 20736")
check(D.DayNumber(2026, 11, 1) - D.DayNumber(2026, 10, 31) == 1, "month rollover")
check(D.DayNumber(2027, 1, 1) - D.DayNumber(2026, 12, 31) == 1, "year rollover")
check(D.DayNumber(2028, 3, 1) - D.DayNumber(2028, 2, 28) == 2, "leap day")
for _, v in ipairs({ { 2026, 1, 1 }, { 2026, 3, 8 }, { 2026, 11, 1 }, { 2030, 6, 15 } }) do
    local y, m, d = v[1], v[2], v[3]
    -- os.time at local noon / 86400 floors to the same civil day in every zone between UTC-12 and UTC+11
    local r = ref(y, m, d)
    check(math.abs(D.DayNumber(y, m, d) - r) <= 1, string.format("DayNumber %d-%d-%d near os.time day %d", y, m, d, r))
end
-- 4. DST (v2.2.26): Core utcOffset just before / after the US fall-back and spring-forward instants, with date()
--    stubbed to that instant in the client's zone (America/New_York rules), whatever TZ the test runs under
local core = read("Core.lua"):match("(local function utcOffset%(%).-\nend)\n")
check(core, "Core utcOffset found")
local function offsetAt(epoch, off)
    local env = { pcall = pcall, type = type, tonumber = tonumber, math = math,
        date = function(fmt) return os.date("!*t", fmt == "!*t" and epoch or epoch + off) end }
    local f = assert(loadstring(core .. "\nreturn utcOffset"))
    setfenv(f, env)
    local fn = f()
    setfenv(fn, env)
    return fn()
end
local E_FALL = 1793512800      -- 2026-11-01 06:00:00 UTC = 02:00 EDT -> 01:00 EST
local E_SPRING = 1772953200    -- 2026-03-08 07:00:00 UTC = 02:00 EST -> 03:00 EDT
check(offsetAt(E_FALL - 1, -14400) == -14400, "utcOffset 1 s before fall-back = -4 h")
check(offsetAt(E_FALL + 1, -18000) == -18000, "utcOffset 1 s after fall-back = -5 h")
check(offsetAt(E_SPRING - 1, -18000) == -18000, "utcOffset 1 s before spring-forward = -5 h")
check(offsetAt(E_SPRING + 1, -14400) == -14400, "utcOffset 1 s after spring-forward = -4 h")
check(D.DayNumber(2026, 11, 2) - D.DayNumber(2026, 11, 1) == 1 and D.DayNumber(2026, 3, 9) - D.DayNumber(2026, 3, 8) == 1,
    "DayNumber: DST days are one day long")
print(string.format("time_lua %s: TZ=%s", fails == 0 and "OK" or "FAILED", tostring(os.getenv("TZ"))))
if fails > 0 then os.exit(1) end
