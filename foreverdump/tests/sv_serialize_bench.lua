-- v2.2.6 SV serialize bench: fill capture-level caps with representative rows, serialize like SavedVariables (Lua
-- table constructor text), report bytes, MB, and wall time. usage: lua5.1 tests/sv_serialize_bench.lua [level]
local level = arg[1] or "test"
local CAPS = {
    release = { tape = 800, record = 4000, combat = 10000, signals = 3000, verify = 600 },
    test    = { tape = 68000, record = 38000, combat = 85000, signals = 6000, verify = 12000 },
    -- v2.2.10: diag has no artificial caps (safety ceilings only), so the bench fills diag with what a REAL 30 min BG
    -- produces (run 8 replayed accelerated through the addon, tests/bg_replay.lua: tape 215k, record 85k, combat 55k
    -- after lossless DM run-length folding) and only REPORTS size and save time.
    diag    = { tape = 215123, record = 85144, combat = 54835, signals = 8000, verify = 16000 },
}
local c = CAPS[level]
local function ser(v, out, n)
    local t = type(v)
    if t == "number" then n = n + 1 out[n] = (v == math.floor(v)) and string.format("%d", v) or string.format("%.3f", v)
    elseif t == "string" then n = n + 1 out[n] = string.format("%q", v)
    elseif t == "boolean" then n = n + 1 out[n] = v and "true" or "false"
    elseif t == "table" then
        n = n + 1 out[n] = "{"
        for k, x in pairs(v) do
            if type(k) == "string" then n = n + 1 out[n] = "[\"" .. k .. "\"]=" else n = n + 1 out[n] = "[" .. k .. "]=" end
            n = ser(x, out, n)
            n = n + 1 out[n] = ","
        end
        n = n + 1 out[n] = "}"
    else n = n + 1 out[n] = "nil" end
    return n
end
-- tape mix for a 40-man BG: keepers ~6%, ws ~35%, sec/api ~35%, dm/map/sig rest
local tape = {}
for i = 1, c.tape do
    local r = i % 100
    local row
    if r < 3 then row = { k = "decide", i = i, d = i * 20, r = 7, c = 3, b = 13, u = "npc:3100", sp = 8046, kind = "damage" }
    elseif r < 5 then row = { k = "verdict", i = i, d = i * 20, kind = "dm-damage", v = "V", src = "match", cf = "high" }
    elseif r < 6 then row = { k = "anchor", i = i, d = i * 20, spell = 403, n = i }
    elseif r < 41 then row = { k = "ws", i = i, d = i * 20, tok = "raidN", p = 1234567890123, id = "player:1a2b3c4d", tgt = "npc:3100", hp = 12000, th = 1, bn = 6, dn = 2 }
    elseif r < 76 then row = { k = "sec", i = i, d = i * 20, e = "UNIT_COMBAT", n = 5, p = 279620 }
    elseif r < 86 then row = { k = "dm", i = i, d = i * 20, ty = 0, sid = 42, st = { "C", "C" } }
    elseif r < 93 then row = { k = "map", i = i, d = i * 20, tok = "nameplateN", id = "npc:3100", how = "live" }
    else row = { k = "sig", i = i, d = i * 20, e = "uc", unit = "target", amt = 120, sch = 1 } end
    tape[i] = row
end
local function ring(n, mk) local t = {} for i = 1, n do t[i] = mk(i) end return t end
local sv = {
    replay = { sessions = { { hdr = { v = 1, verbosity = level }, tape = tape, n = c.tape, head = c.tape } } },
    record = ring(c.record, function(i) return { e = "UNIT_SPELLCAST_SUCCEEDED", t = i * 0.1, a = { "raid1", "Cast-" .. i, 403 } } end),
    combat = ring(c.combat, function(i) return { e = "UNIT_COMBAT", t = i * 0.05, a = { "target", "WOUND", "", 120, 1 } } end),
    signals = ring(c.signals, function(i) return { e = "cast", t = i, unit = "player", sid = 403 } end),
    verify = ring(c.verify, function(i) return { kind = "cooldown", v = "V", t = i, spell = 8046 } end),
}
local t0 = os.clock()
local out = {}
local n = ser(sv, out, 0)
local s = table.concat(out, "", 1, n)
local dt = os.clock() - t0
local mb = #s / 1048576
print(string.format("level=%s bytes=%d MB=%.2f serializeMs=%.0f tape=%d record=%d combat=%d signals=%d verify=%d",
    level, #s, mb, dt * 1000, c.tape, c.record, c.combat, c.signals, c.verify))
-- gates (size): test ring fill must leave >= 4 MB headroom under the ~30 MB SV target (deep DM, learned, tokens, docs);
-- release (what ships to players) must stay small: ring fill <= 4 MB.
-- v2.2.10: diag is report-only (user decision: no artificial limit on diag data collection; in-game cost is gated by
-- tests/bg_replay.lua --assert instead, save time is measured and reported, not capped)
if level == "test" and mb > 26 then print("SV SERIALIZE FAIL: test ring fill " .. string.format("%.2f", mb) .. " MB > 26 MB") os.exit(1) end
if level == "release" and mb > 4 then print("SV SERIALIZE FAIL: release ring fill " .. string.format("%.2f", mb) .. " MB > 4 MB") os.exit(1) end
if level == "diag" then print(string.format("SV SERIALIZE REPORT (diag, not gated): %.2f MB, serialize %.0f ms", mb, dt * 1000)) end
print("SV SERIALIZE OK")
