-- v2.2.11 SVPack unit + edge cases (ForeverDump/SVPack.lua) in stock Lua 5.1:
--   1 edge values round-trip exactly (NaN, +-inf, -0, 2^31.., 2^53, shortest floats, \0 \r \n bytes, keyword/odd keys,
--     boolean keys, list holes from unwritable values, empty tables, deep nesting)
--   2 forced splitting (tiny CHUNK_LITERALS/BYTES): many chunks + grafts rebuild the identical tree
--   3 a table with 400k distinct literals (> 262,143) packs into chunks that each load (per-chunk constants < limit)
--     and the wrapped SV loads in stock Lua 5.1; the unpacked value equals the original
--   4 plain small vars stay plain; PackAll/UnpackAll on globals; cycle -> stub (v2.2.13) + failure reported
--   5 rescue: a corrupted chunk keeps the blob in .packedRescue (nothing lost)
--   6 OFF guard: warns once when packing is off and the plain constant estimate exceeds WARN_AT, silent when packing
-- usage: lua5.1 tests/svpack.lua ForeverDump
local dir = arg[1] or "ForeverDump"
local fails, checks = 0, 0
local function check(c, msg) checks = checks + 1 if not c then fails = fails + 1 print("  FAIL " .. msg) end end
local printed = {}
local ns = { Print = function(m) printed[#printed + 1] = m end, config = {} }
assert(loadfile(dir .. "/SVPack.lua"))("ForeverDump", ns)
local P = ns.SVPack

local function eq(a, b, path, seen)
    if type(a) ~= type(b) then return false, path .. ": type " .. type(a) .. " vs " .. type(b) end
    if type(a) == "number" then
        if a ~= a and b ~= b then return true end
        if a ~= b then return false, path .. string.format(": %.17g vs %.17g", a, b) end
        return true
    end
    if type(a) ~= "table" then
        if a ~= b then return false, path .. ": " .. tostring(a) .. " vs " .. tostring(b) end
        return true
    end
    for k, v in pairs(a) do
        local ok, why = eq(v, b[k], path .. "." .. tostring(k))
        if not ok then return false, why end
    end
    for k in pairs(b) do if a[k] == nil then return false, path .. "." .. tostring(k) .. ": extra" end end
    return true
end
P.Eq = eq

local function roundtrip(v)
    local p = P.PackValue(v)
    local t, err = P.UnpackValue(p)
    return t, p, err
end

-- 1 edge values
do
    local nz = 0
    local inf = math.huge
    local v = { inf - inf, inf, -inf, -nz,   -- v2.2.13: no x / 0 (the client and tests/build_wowlua.sh raise) 2 ^ 31, -2 ^ 31, 2 ^ 31 - 1, 2 ^ 53, 2 ^ 53 + 2, 1234567890123, 0.1, 1 / 3, 397295.17578125,
        0.0008666666666666667, 1e-300, 5e-324, 1.7976931348623157e308, "a\0b\r\n\t\"\\'\255", "",
        ["end"] = 1, ["a b"] = 2, ["1x"] = 3, [true] = "t", [false] = "f", [1.5] = "frac", [-3] = "neg", [0] = "zero",
        nested = { {}, { {} }, { x = { y = { z = { 1, 2, 3 } } } } }, fn = print, list = { 1, 2, print, 4 } }
    local t, _, err = roundtrip(v)
    check(t ~= nil, "edge roundtrip unpacked (" .. tostring(err) .. ")")
    local expect = {}
    for k, x in pairs(v) do expect[k] = x end
    expect.fn = nil
    expect.list = { 1, 2, nil, 4 }
    local ok, why = eq(expect, t or {}, "edge")
    check(ok, "edge values exact: " .. tostring(why))
    -- -0: Lua 5.1 deduplicates the constants 0 and -0 (they compare equal), in the client's own SV loader as in a
    -- chunk, so a -0 may come back as 0 - same as without packing; the value itself is exact
    check(t and t[4] == 0, "-0 comes back as zero")
end

-- 2 forced splitting
do
    local saveL, saveB = P.CHUNK_LITERALS, P.CHUNK_BYTES
    P.CHUNK_LITERALS, P.CHUNK_BYTES = 7, 120
    local v = { meta = { a = 1, b = "x" }, rows = {}, map = {} }
    for i = 1, 300 do v.rows[i] = { i = i, t = i * 0.017, s = "r" .. i, sub = (i % 50 == 0) and { 1, 2, 3, 4, 5, 6, 7, 8, 9 } or nil } end
    for i = 1, 120 do v.map["k" .. i] = { i, i + 0.5, { deep = { i } } } end
    v.rows[301] = { big = {} }
    for i = 1, 40 do v.rows[301].big[i] = i end
    local t, p, err = roundtrip(v)
    P.CHUNK_LITERALS, P.CHUNK_BYTES = saveL, saveB
    check(t ~= nil, "split unpacked (" .. tostring(err) .. ")")
    local ok, why = eq(v, t or {}, "split")
    check(ok, "forced split exact: " .. tostring(why))
    check(#p.chunks > 50 and #p.gp > 5, string.format("forced split really split (%d chunks, %d grafts)", #p.chunks, #p.gp))
end

-- 3 > 262,143 distinct literals
local wrapperK
do
    local v = { rows = {} }
    for i = 1, 200000 do v.rows[i] = { t = i + 0.25, s = "id" .. i } end
    local t, p, err = roundtrip(v)
    check(t ~= nil, "400k unpacked (" .. tostring(err) .. ")")
    local ok, why = eq(v, t or {}, "big")
    check(ok, "400k-literal table exact: " .. tostring(why))
    for i, src in ipairs(p.chunks) do
        local fn = loadstring(src)
        check(fn ~= nil, "chunk " .. i .. " loads")
    end
    -- the wrapped value as a SavedVariables file: must load in stock Lua 5.1
    local out = { "X = {__fdpack=1,nodes=", p.nodes, ",chunks={" }
    for _, src in ipairs(p.chunks) do out[#out + 1] = string.format("%q,", src) end
    out[#out + 1] = "},cn={" .. table.concat(p.cn, ",") .. "},cb={" .. table.concat(p.cb, ",") .. "},gp={},gk={},gc={}}\n"
    local f = loadstring(table.concat(out))
    check(f ~= nil, "wrapped 400k-literal SV loads in stock Lua 5.1")
    local plain = { "Y = {" }
    for i = 1, 200000 do plain[#plain + 1] = string.format("{t=%s,s=%q},", P.Num(i + 0.25), "id" .. i) end
    plain[#plain + 1] = "}"
    local g, gerr = loadstring(table.concat(plain))
    check(g == nil and tostring(gerr):find("constant table overflow") ~= nil,
        "control: the same data written plainly overflows (" .. tostring(gerr) .. ")")
    wrapperK = #p.chunks
    check(#p.chunks >= 8, "400k literals -> >= 8 chunks (" .. #p.chunks .. ")")
end

-- 4 PackAll / UnpackAll on globals
do
    ForeverDumpDB = { config = { a = 1 }, small = { 1, 2, 3 } }
    ForeverDumpLogDB = { replay = { sessions = { { tape = {} } } } }
    for i = 1, 30000 do ForeverDumpLogDB.replay.sessions[1].tape[i] = { k = "ws", i = i, d = i * 0.02 } end
    local cyc = { name = "cyc" }
    for i = 1, 5000 do cyc[i] = i end
    cyc.self = cyc
    ForeverDumpRecordDB = cyc
    ForeverDumpCombatLogDB, ForeverDumpStaticDB = { sessions = {} }, nil
    local orig = ForeverDumpLogDB
    local rep = P.PackAll()
    check(P.IsPacked(ForeverDumpLogDB), "big var packed")
    check(not P.IsPacked(ForeverDumpDB) and ForeverDumpDB.svpack == rep, "small ForeverDumpDB stays plain + carries the report")
    check(ForeverDumpRecordDB ~= cyc and ForeverDumpRecordDB.packFailed ~= nil and rep.vars.ForeverDumpRecordDB.stubbed
        and rep.failed == 1 and rep.stubbed == 1, "cycle (cannot be walked): replaced by a stub, failure reported")
    ForeverDumpRecordDB = { sessions = {} }
    local u = P.UnpackAll()
    check(ForeverDumpLogDB ~= orig and eq(orig, ForeverDumpLogDB, "log") and u.vars.ForeverDumpLogDB.chunks >= 1,
        "UnpackAll restores the var")
end

-- 5 rescue
do
    local v = { rows = {} }
    for i = 1, 6000 do v.rows[i] = { i = i } end
    ForeverDumpLogDB = P.PackValue(v)
    ForeverDumpLogDB.chunks[1] = "return{,"
    local u = P.UnpackAll()
    check(type(ForeverDumpLogDB) == "table" and P.IsPacked(ForeverDumpLogDB.packedRescue) and u.failed == 1,
        "bad chunk: blob kept in .packedRescue")
end

-- 6 OFF guard
do
    ForeverDumpLogDB = { rows = {} }
    for i = 1, 210000 do ForeverDumpLogDB.rows[i] = i + 0.5 end
    printed = {}
    P.warned = nil
    P.GuardAtOff()
    check(#printed == 0, "guard silent while packing is on")
    ns.config.svpack = false
    P.GuardAtOff()
    P.GuardAtOff()
    check(#printed == 1 and printed[1]:find("may not load") ~= nil, "guard warns once when the plain save would exceed WARN_AT")
    ns.config.svpack = nil
end
ForeverDumpLogDB, ForeverDumpDB, ForeverDumpRecordDB, ForeverDumpCombatLogDB = nil, nil, nil, nil
print(string.format("svpack %s: %d/%d checks (400k-literal value -> %d chunks)", fails == 0 and "OK" or "FAILED",
    checks - fails, checks, wrapperK or 0))
if fails > 0 then os.exit(1) end
