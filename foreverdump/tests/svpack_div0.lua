-- v2.2.13 regression (run 10): the WoW client's Lua raises "Division by zero" on x / 0 and x % 0; v2.2.11/12 SVPack
-- probed -0 with `1 / v` (and wrote NaN as 0/0), so every pack failed in game and the 331k-constant file was unloadable.
-- Must run under the WoW-like interpreter built by tests/build_wowlua.sh (it refuses to run under stock Lua):
--   1 the interpreter really raises on / 0 and % 0 (else this test proves nothing)
--   2 P.SelfTest() passes (the same probe FD_Logs OFF runs in game)
--   3 a > PLAIN_MAX var with 0, -0, +-inf, NaN round-trips exactly through PackValue / UnpackValue
--   4 PackAll on globals: nothing fails, NaN written (subtraction expression), the report is clean
--   5 fallback 1: a pass that raises is retried with per-scalar pcall -> var still packed, recovered = 1
--   6 fallback 2: a var that cannot be packed and would overflow the file is replaced by a stub (file stays loadable);
--     a small one is left plain; LoginReport names both
-- usage: lua5.1(wow) tests/svpack_div0.lua ForeverDump [--expect-fail]   (--expect-fail: an old SVPack must fail 2-4)
local dir = arg[1] or "ForeverDump"
local expectFail = arg[2] == "--expect-fail"
local fails, checks = 0, 0
local function check(c, msg) checks = checks + 1 if not c then fails = fails + 1 print("  FAIL " .. msg) end end

-- 1
local okD, eD = pcall(function() local z = 0 return 1 / z end)
local okM, eM = pcall(function() local z = 0 return 5 % z end)
if okD or okM or not tostring(eD):find("Division by zero") or not tostring(eM):find("Modulo by zero") then
    print("svpack_div0 FAIL: interpreter does not raise on x/0 / x%0 like the client; use .cache/wowlua/bin/lua5.1 "
        .. "(tests/build_wowlua.sh)")
    os.exit(1)
end
local inf = math.huge
local nan = inf - inf

local printed = {}
local ns = { Print = function(m) printed[#printed + 1] = m end, config = {} }
assert(loadfile(dir .. "/SVPack.lua"))("ForeverDump", ns)
local P = ns.SVPack

local function eq(a, b, path)
    if type(a) ~= type(b) then return false, path .. ": type " .. type(a) .. " vs " .. type(b) end
    if type(a) == "number" then
        if a ~= a and b ~= b then return true end
        if a ~= b then return false, path .. string.format(": %.17g vs %.17g", a, b) end
        return true
    end
    if type(a) ~= "table" then return a == b, path end
    for k, v in pairs(a) do local ok, why = eq(v, b[k], path .. "." .. tostring(k)) if not ok then return false, why end end
    for k in pairs(b) do if a[k] == nil then return false, path .. "." .. tostring(k) .. ": extra" end end
    return true
end

local function big(n)
    local v = { rows = {} }
    for i = 1, n do v.rows[i] = { i = i, t = i * 0.25, s = "r" .. i } end
    v.edge = { 0, -0, inf, -inf, nan, 2 ^ 53, -2 ^ 31, 0.1, nanKey = nan }
    return v
end

-- 2
local okS, stOk, stErr = pcall(P.SelfTest or function() return P.PackValue({ 0, -0, inf }) and true end)
local selfOk = okS and stOk == true
-- 3
local v = big(3000)
local ok3, p3 = pcall(P.PackValue, v)
local t3, err3
if ok3 then t3, err3 = P.UnpackValue(p3) end
local same3 = t3 and eq(v, t3, "v") or false
local nanBack = t3 and t3.edge[5] ~= t3.edge[5]
-- 4
ForeverDumpDB = { config = {} }
ForeverDumpLogDB = big(6000)
local origLog = ForeverDumpLogDB
ForeverDumpRecordDB, ForeverDumpCombatLogDB, ForeverDumpStaticDB = { sessions = {} }, { sessions = {} }, nil
local ok4, rep4 = pcall(P.PackAll)
local packed4 = ok4 and P.IsPacked and P.IsPacked(ForeverDumpLogDB)

if expectFail then
    local failedAll = not selfOk and not ok3 or not packed4 or (rep4 and (rep4.failed or 0) > 0)
    print(string.format("svpack_div0 (old SVPack, expect fail): selfTest=%s pack=%s (%s) packAll.failed=%s -> %s",
        tostring(selfOk), tostring(ok3), ok3 and "ok" or tostring(p3), tostring(rep4 and rep4.failed),
        failedAll and "FAILS as expected" or "UNEXPECTEDLY PASSES"))
    os.exit(failedAll and 0 or 1)
end

check(selfOk, "SelfTest passes under the WoW-like interpreter (" .. tostring(okS and stErr or stOk) .. ")")
check(ok3, "PackValue with 0, -0, +-inf, NaN does not raise (" .. tostring(ok3 or p3) .. ")")
check(t3 ~= nil and same3, "edge values round-trip exactly (" .. tostring(err3) .. ")")
check(nanBack, "NaN comes back as NaN (written as a subtraction, never 0/0)")
check(t3 and t3.edge.nanKey ~= t3.edge.nanKey, "NaN as a value under a string key round-trips")
for _, src in ipairs(ok3 and p3.chunks or {}) do
    check(not src:find("0/0", 1, true) and not src:find("/", 1, true), "no division in a packed chunk")
end
check(ok4 and packed4 and (rep4.failed or 0) == 0 and not rep4.recovered, "PackAll: LogDB packed, nothing failed")
do
    P.UnpackAll()
    check(eq(origLog, ForeverDumpLogDB, "log"), "PackAll + UnpackAll restores the var exactly")
    check(ForeverDumpDB.svpack and P.LoginReport() == nil, "clean pack -> no login warning")
end

-- 5 fallback 1: the strict pass raises (as v2.2.12 did in game), the safe pass packs
do
    local real = P.PackValue
    P.PackValue = function(x, safe)
        if not safe then error("SVPack.lua:108: Division by zero") end
        return real(x, safe)
    end
    ForeverDumpDB = { config = {} }
    ForeverDumpLogDB = big(6000)
    local orig = ForeverDumpLogDB
    local rep = P.PackAll()
    P.PackValue = real
    check(P.IsPacked(ForeverDumpLogDB) and rep.recovered == 1 and (rep.failed or 0) == 0
        and rep.vars.ForeverDumpLogDB.firstError:find("Division by zero"), "fallback 1: retried safely, var packed")
    local msg = P.LoginReport()
    check(msg and msg:find("ForeverDumpLogDB saved by the fallback pass"), "fallback 1: login report names it")
    P.UnpackAll()
    check(eq(orig, ForeverDumpLogDB, "log"), "fallback 1: exact after unpack")
end

-- 6 fallback 2: every pass fails; the big var would overflow the file -> stub; the small one stays plain
do
    local real = P.PackValue
    P.PackValue = function() error("SVPack.lua:108: Division by zero") end
    ForeverDumpDB = { config = {} }
    ForeverDumpLogDB = big(80000)                       -- ~240k literals: plain, the file would not load
    local rec = big(2000)
    ForeverDumpRecordDB = rec                           -- ~6k literals: written plain, the file still loads
    local rep = P.PackAll()
    P.PackValue = real
    check(type(ForeverDumpLogDB) == "table" and ForeverDumpLogDB.packFailed and not ForeverDumpLogDB.rows
        and rep.vars.ForeverDumpLogDB.stubbed, "fallback 2: the overflowing var is replaced by a stub")
    check(ForeverDumpRecordDB == rec and not rep.vars.ForeverDumpRecordDB.stubbed, "fallback 2: a small failed var is kept plain")
    check(rep.failed == 2 and rep.stubbed == 1, "fallback 2: report counts (failed=2 stubbed=1)")
    local msg = P.LoginReport() or ""
    check(msg:find("ForeverDumpLogDB NOT SAVED") and msg:find("ForeverDumpRecordDB not packed"), "fallback 2: login report: " .. msg)
    local u = P.UnpackAll()
    check((u.failed or 0) == 0 and ForeverDumpLogDB.packFailed, "fallback 2: the stub loads back as a plain table")
end

if fails > 0 then print(string.format("svpack_div0 FAIL: %d/%d checks failed", fails, checks)) os.exit(1) end
print(string.format("svpack_div0 OK: %d/%d checks (WoW-like Lua: / 0 and %% 0 raise)", checks, checks))
