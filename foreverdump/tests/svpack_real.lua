-- v2.2.11 SVPack on a REAL SavedVariables file (run 9: 75.5 MB, 321,235 distinct constants, did not load in the client).
-- 1 read the original per top-level variable (each variable loads on its own; together they overflow)
-- 2 PLAYER_LOGOUT-style PackAll, write the file the way the client does (shortest round-trip numbers)
-- 3 the written file must load in stock Lua 5.1 as ONE chunk (what the client does)
-- 4 ADDON_LOADED-style UnpackAll must give back every variable exactly (deep compare, NaN-aware)
-- usage: lua5.1 tests/svpack_real.lua ForeverDump IN.lua OUT.lua [--scale N] [--no-pack]
--   -> prints "svpack_real OK ..." (exit 1 on failure)
-- v2.2.11 speed-up of the 2x/10x density test: --scale N builds the SV directly at N x the constant count of a real
-- capture (each variable gets N-1 perturbed deep copies: every number shifted, every string value suffixed, so the
-- distinct literals scale ~N x with the real shape) instead of replaying the whole addon for 30 min of BG traffic.
-- --no-pack is the control: the scaled data written plainly (expected not to load when over the constant limit).
-- --synth K (IN = "-"): no input file; generate a capture-shaped SV (replay tape sessions, combat ring, recorder
-- events, knowledge/static string-keyed maps) with ~K distinct literals directly at the constant-count level
-- (tests/test_v2211_svpack.py (a): 2x and 10x run 9's 321,237). Prints "literals=<distinct written literals>".
local dir, inPath, outPath = arg[1], arg[2], arg[3]
local scale, noPack, synth = 1, false, nil
do
    local i = 4
    while arg[i] do
        if arg[i] == "--scale" then scale = tonumber(arg[i + 1]) i = i + 2
        elseif arg[i] == "--synth" then synth = tonumber(arg[i + 1]) i = i + 2
        elseif arg[i] == "--no-pack" then noPack = true i = i + 1
        else error("unknown option " .. arg[i]) end
    end
end
local ns = { Print = print, config = {} }
assert(loadfile(dir .. "/SVPack.lua"))("ForeverDump", ns)
local P = ns.SVPack
local clock = os.clock

local orig, names = {}, {}
local t0 = clock()
local text
if synth then
    -- deterministic generator; every record carries ~4 distinct literals (float time, shifted int > 2^31 on some,
    -- per-record strings) plus shared event/field names, like the real tape; a few edge values ride along
    local per = math.floor(synth / 3.3)   -- ~3.3 distinct literals per record on average (measured)
    local seed = 12345
    local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648 return seed end
    local EV = { "UNIT_AURA", "UNIT_HEALTH", "UNIT_SPELLCAST_SUCCEEDED", "NAME_PLATE_UNIT_ADDED", "UNIT_POWER_UPDATE" }
    local function tape(n, off)
        local sess, cur = {}, nil
        for i = 1, n do
            if (i - 1) % 20000 == 0 then cur = { sid = "s" .. (off + i), events = {}, startEpoch = 1790000000 + off + i } sess[#sess + 1] = cur end
            local k = off + i
            local ev = { t = k * 0.0137 + 0.000001 * (rnd() % 1000), e = EV[k % #EV + 1],
                a = { "nameplate" .. (k % 40), k * 3 + 0.5, "Creature-0-" .. k } }
            if k % 97 == 0 then ev.big = 2 ^ 31 + k ev.neg = -k - 0.25 ev.esc = "line\n\"q\"\0" .. k ev.flag = (k % 2 == 0) end
            if k % 1013 == 0 then ev.nan = math.huge - math.huge ev.inf = (k % 2 == 0) and math.huge or -math.huge ev.hole = { 1, nil, 3 } end
            cur.events[#cur.events + 1] = ev
        end
        return sess
    end
    local function map(n, off)
        local m = {}
        for i = 1, n do
            local k = off + i
            m["spell:" .. k] = { id = k, dur = k / 7, name = "Spell " .. k }
        end
        return m
    end
    orig.ForeverDumpLogDB = { schemaVersion = 22, replay = { sessions = tape(math.floor(per * 0.45), 0) } }
    orig.ForeverDumpCombatLogDB = { schemaVersion = 22, sessions = tape(math.floor(per * 0.15), 10000000) }
    orig.ForeverDumpRecordDB = { schemaVersion = 22, sessions = tape(math.floor(per * 0.1), 20000000) }
    orig.ForeverDumpStaticDB = { schemaVersion = 22, spells = map(math.floor(per * 0.2), 30000000) }
    orig.ForeverDumpDB = { schemaVersion = 22, learned = map(math.floor(per * 0.1), 40000000), config = { svpack = true } }
    names = { "ForeverDumpDB", "ForeverDumpStaticDB", "ForeverDumpRecordDB", "ForeverDumpLogDB", "ForeverDumpCombatLogDB" }
else
local f = assert(io.open(inPath, "rb"))
text = f:read("*a")
f:close()
-- split at top-level assignments (column 0 "Name = ")
local starts = {}
for pos, name in text:gmatch("()\n?([%a_][%w_]*) = ") do
    if pos == 1 or text:sub(pos, pos) == "\n" then starts[#starts + 1] = { pos = pos, name = name } end
end
for i, s in ipairs(starts) do
    local e = (starts[i + 1] and starts[i + 1].pos - 1) or #text
    local env = {}
    local fn = assert(loadstring(text:sub(s.pos, e), "=" .. s.name))
    setfenv(fn, env)
    fn()
    orig[s.name] = env[s.name]
    names[#names + 1] = s.name
end
end
text = nil
collectgarbage("collect")
if scale > 1 then
    local function perturb(v, i)
        local t = type(v)
        if t == "number" then
            if v ~= v or v == math.huge or v == -math.huge then return v end
            return v + i * 0.001953125     -- 2^-9: exact in binary, so the value round-trips exactly
        elseif t == "string" then return v .. "~" .. i
        elseif t == "table" then
            local c = {}
            for k, x in pairs(v) do c[k] = perturb(x, i) end
            return c
        end
        return v
    end
    for _, n in ipairs(names) do
        local o = orig[n]
        if type(o) == "table" then
            local c = {}
            for k, x in pairs(o) do c[k] = x end
            for i = 2, scale do c["__density" .. i] = perturb(o, i) end
            orig[n] = c
        end
    end
    collectgarbage("collect")
end
local readMs = (clock() - t0) * 1000
for _, n in ipairs(names) do _G[n] = orig[n] end
-- distinct string/number literals of the data (keys + values, before packing): ~ the constant count a plain write has
do
    local seen, nseen = {}, 0
    local function lit(x) if x == x and not seen[x] then seen[x] = true nseen = nseen + 1 end end
    local function walk(v)
        if type(v) == "table" then for k, x in pairs(v) do lit(k) walk(x) end
        elseif type(v) == "string" or type(v) == "number" then lit(v) end
    end
    for _, n in ipairs(names) do lit(n) walk(orig[n]) end
    print("literals=" .. nseen)
end
-- pack (keep the originals for the comparison: PackAll replaces the globals)
t0 = clock()
local rep = noPack and { vars = {} } or P.PackAll()
local packMs = (clock() - t0) * 1000
-- WoW-like writer with lossless numbers
local function q(s) return string.format("%q", s):gsub("\\\n", "\\n") end
local function write(out, v, indent)
    local t = type(v)
    if t == "string" then out[#out + 1] = q(v)
    elseif t == "number" then out[#out + 1] = P.Num(v)
    elseif t == "boolean" then out[#out + 1] = tostring(v)
    elseif t == "table" then
        out[#out + 1] = "{\n"
        local n = 0
        while v[n + 1] ~= nil do n = n + 1 end
        for i = 1, n do out[#out + 1] = string.rep("\t", indent + 1) write(out, v[i], indent + 1) out[#out + 1] = ", -- [" .. i .. "]\n" end
        for k, x in pairs(v) do
            if not (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)) then
                out[#out + 1] = string.rep("\t", indent + 1) .. "[" .. (type(k) == "string" and q(k) or P.Num(k)) .. "] = "
                write(out, x, indent + 1)
                out[#out + 1] = ",\n"
            end
        end
        out[#out + 1] = string.rep("\t", indent) .. "}"
    else out[#out + 1] = "nil" end
end
t0 = clock()
local out = {}
for _, n in ipairs(names) do
    out[#out + 1] = "\n" .. n .. " = "
    write(out, _G[n], 0)
    out[#out + 1] = "\n"
end
local s = table.concat(out)
out = nil
local w = assert(io.open(outPath, "wb"))
w:write(s)
w:close()
local writeMs = (clock() - t0) * 1000
local bytes = #s
-- 3 one chunk, stock Lua 5.1
for _, n in ipairs(names) do _G[n] = nil end
t0 = clock()
local fn, err = loadstring(s, "=packedSV")
s = nil
local loadMs = (clock() - t0) * 1000
if noPack then
    print(string.format("svpack_real control (no pack, scale %d): file %.1f MB, loads=%s %s", scale, bytes / 1048576,
        tostring(fn ~= nil), fn and "" or tostring(err)))
    os.exit(0)
end
if not fn then print("svpack_real FAILED: packed file does not load: " .. tostring(err)) os.exit(1) end
fn()
-- 4 unpack + exact compare
t0 = clock()
local u = P.UnpackAll()
local unpackMs = (clock() - t0) * 1000
local bad = 0
local tc0 = clock()
for _, n in ipairs(names) do
    -- the path string is only built on a mismatch (building it per element made the 10x compare superlinear: 70 s)
    local ok, why = (function()
        local function eq(a, b)
            if type(a) ~= type(b) then return false, ": type " .. type(a) .. " vs " .. type(b) end
            if type(a) == "number" then
                if a ~= a and b ~= b then return true end
                if a ~= b then return false, string.format(": %.17g vs %.17g", a, b) end
                return true
            end
            if type(a) ~= "table" then if a ~= b then return false, "" end return true end
            for k, v in pairs(a) do local ok, why = eq(v, b[k]) if not ok then return false, "." .. tostring(k) .. why end end
            for k in pairs(b) do if a[k] == nil then return false, "." .. tostring(k) .. " extra" end end
            return true
        end
        local okE, whyE = eq(orig[n], _G[n])
        return okE, (not okE) and (n .. whyE) or nil
    end)()
    if not ok then bad = bad + 1 print("  FAIL " .. tostring(why)) end
end
local cmpMs = (clock() - tc0) * 1000
io.stderr:write(string.format("timing: compare %.0f ms, total cpu %.0f ms\n", cmpMs, clock() * 1000))
local chunks, packed = 0, 0
for _, n in ipairs(names) do
    local r = rep.vars[n]
    if r and r.chunks then chunks, packed = chunks + r.chunks, packed + 1 end
end
if P.lastPackSelf and P.lastPackSelf.chunks then chunks, packed = chunks + P.lastPackSelf.chunks, packed + 1 end
print(string.format("svpack_real %s (scale %d): %d vars (%d packed, %d chunks) exact=%s; file %.1f MB; read %.0f ms, pack %.0f ms, "
    .. "write %.0f ms, load-as-one-chunk %.0f ms, unpack %.0f ms; failed packs %d, unpack failures %d",
    (bad == 0 and not rep.failed and not u.failed) and "OK" or "FAILED", scale, #names, packed, chunks, tostring(bad == 0),
    bytes / 1048576, readMs, packMs, writeMs, loadMs, unpackMs, rep.failed or 0, u.failed or 0))
if bad > 0 or rep.failed or u.failed then os.exit(1) end
