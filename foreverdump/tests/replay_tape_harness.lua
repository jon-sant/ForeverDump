-- Produce a synthetic ForeverDumpLogDB.replay session by running the real addon (FD_Logs capture)
-- through a known event sequence, then write tape JSON + HSM input events for offline re-exec.
-- usage: lua5.1 tests/replay_tape_harness.lua [out_dir]
local outDir = arg[1] or "tests/out/replay_tape"
os.execute("mkdir -p " .. outDir)

package.path = "tests/?.lua;" .. package.path
local W = dofile("tests/wowenv.lua")
local S = W.state

local function tocFiles(dir)
    local files = {}
    for line in io.lines(dir .. "/ForeverDump.toc") do
        if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
    end
    return files
end

local ns = W.loadAddon("ForeverDump", tocFiles("ForeverDump"), "ForeverDump")
W.fire("ADDON_LOADED", "ForeverDump")
W.fire("PLAYER_LOGIN")
W.fire("PLAYER_ENTERING_WORLD", true, false)
ns.config.logs.fullDump = false
ns.config.logs.autoReload = false
if ns.config.replay then ns.config.replay.captureLevel = "test" end

W.slash("logs on")
for _ = 1, 30 do S.time = S.time + 0.05 W.tick(1) end

-- scripted sequence that exercises cast + heal attribution + dm type 7 + totem-ish heal
local inputs = {}  -- Forever-style events for hsm_replay.lua
local function note(e) inputs[#inputs + 1] = e end

S.combat = true
W.fire("PLAYER_REGEN_DISABLED")
note({ t = S.time, k = "combat", on = true })

-- own cast Earth Shock
local sid = 8042
W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", sid)
note({ t = S.time, k = "cast", ev = "UNIT_SPELLCAST_SUCCEEDED", unit = "player", spell = sid, player = true, target = "target" })
for _ = 1, 3 do S.time = S.time + 0.016 W.tick(1) end

-- damage on target (mine via cast-frame)
W.fire("UNIT_COMBAT", "target", "WOUND", "", 120, 16)
note({ t = S.time, k = "uc", unit = "target", action = "WOUND", flag = "", amount = 120, school = 16, player = false })

-- DM type 7 then wound on player (shadow dm-type7)
W.fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 7, 0)
note({ t = S.time, k = "dm", type = 7 })
S.time = S.time + 0.01 W.tick(1)
W.fire("UNIT_COMBAT", "player", "WOUND", "", 40, 1)
note({ t = S.time, k = "uc", unit = "player", action = "WOUND", flag = "", amount = 40, school = 1, player = true })

-- summon (totem) then heal cadence
W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-totem", 5394)  -- Healing Stream
note({ t = S.time, k = "cast", ev = "UNIT_SPELLCAST_SUCCEEDED", unit = "player", spell = 5394, player = true, target = "player" })
-- teach HSM a summon via Learn-like: OnTotemUpdate if available
if ns.Inference and ns.Inference.hs and ns.Inference.hs.OnTotemUpdate then
    ns.Inference.hs:OnTotemUpdate(1, true, "Healing Stream Totem", S.time, 60)
end
note({ t = S.time, k = "learn", spell = 5394, summon = { duration = 60 } })
S.time = S.time + 2.0
for _ = 1, 5 do W.tick(1) S.time = S.time + 0.05 end
W.fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 2, 0)
note({ t = S.time, k = "dm", type = 2 })
W.fire("UNIT_COMBAT", "player", "HEAL", "", 25, 8)
note({ t = S.time, k = "uc", unit = "player", action = "HEAL", flag = "", amount = 25, school = 8, player = true })

-- more own casts for decide volume
for i = 2, 8 do
    S.time = S.time + 1.5
    W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-" .. i, sid)
    note({ t = S.time, k = "cast", ev = "UNIT_SPELLCAST_SUCCEEDED", unit = "player", spell = sid, player = true, target = "target" })
    W.fire("UNIT_COMBAT", "target", "WOUND", "", 100 + i, 16)
    note({ t = S.time, k = "uc", unit = "target", action = "WOUND", flag = "", amount = 100 + i, school = 16, player = false })
    for _ = 1, 2 do S.time = S.time + 0.016 W.tick(1) end
end

-- post-combat meter reconcile (addon DamageMeter does this on capture stop / regen)
if ns.Inference and ns.Inference.hs and ns.Inference.hs.ReconcileDM then
    ns.Inference.hs:ReconcileDM({ damage = 0, healing = 0, interrupts = 0, spells = {} })
end
note({ t = S.time, k = "dmrec", damage = 0, healing = 0, interrupts = 0, spells = {} })
S.combat = false
W.fire("PLAYER_REGEN_ENABLED")
note({ t = S.time, k = "combat", on = false })
for _ = 1, 10 do S.time = S.time + 0.05 W.tick(1) end
W.slash("logs off")
for _ = 1, 20 do S.time = S.time + 0.05 W.tick(1) end

local rep = ForeverDumpLogDB and ForeverDumpLogDB.replay
assert(rep and rep.sessions and #rep.sessions >= 1, "no replay session recorded")
local sess = rep.sessions[#rep.sessions]
assert(sess.tape and (sess.n or 0) > 0, "empty tape")

-- JSON encoder (minimal)
local function enc(v, depth)
    depth = depth or 0
    local ty = type(v)
    if ty == "nil" then return "null" end
    if ty == "boolean" then return tostring(v) end
    if ty == "number" then return string.format("%.17g", v) end
    if ty == "string" then return '"' .. v:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end) .. '"' end
    if ty == "table" and depth < 12 then
        local n = #v
        if n > 0 or next(v) == nil then
            local parts = {}
            for i = 1, n do parts[i] = enc(v[i], depth + 1) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local parts = {}
        for k, x in pairs(v) do
            if type(k) == "string" or type(k) == "number" then
                parts[#parts + 1] = enc(tostring(k), depth + 1) .. ":" .. enc(x, depth + 1)
            end
        end
        table.sort(parts)
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
end

-- flatten ring tape to array
local flat = {}
if type(sess.tape) == "table" then
    for _, rec in pairs(sess.tape) do
        if type(rec) == "table" and rec.i then flat[#flat + 1] = rec end
    end
    table.sort(flat, function(a, b) return a.i < b.i end)
end
sess.tape = flat

local f = assert(io.open(outDir .. "/tape.json", "w"))
f:write(enc({ session = sess, hdr = sess.hdr, rules = sess.rules }))
f:close()

-- events.lua for hsm_replay
local ef = assert(io.open(outDir .. "/events.lua", "w"))
ef:write("return {\n  window = 0.6,\n  events = {\n")
for _, e in ipairs(inputs) do
    ef:write("    {")
    local parts = {}
    for k, v in pairs(e) do
        if type(v) == "string" then parts[#parts + 1] = string.format("%s=%q", k, v)
        elseif type(v) == "boolean" then parts[#parts + 1] = string.format("%s=%s", k, tostring(v))
        elseif type(v) == "number" then parts[#parts + 1] = string.format("%s=%.17g", k, v)
        elseif type(v) == "table" then
            local inner = {}
            for ik, iv in pairs(v) do
                if type(iv) == "number" then inner[#inner + 1] = string.format("%s=%.17g", ik, iv) end
            end
            parts[#parts + 1] = k .. "={" .. table.concat(inner, ",") .. "}"
        end
    end
    ef:write(table.concat(parts, ", ") .. "},\n")
end
ef:write("  },\n}\n")
ef:close()

local nDecide, nVerdict = 0, 0
for _, r in ipairs(flat) do
    if r.k == "decide" then nDecide = nDecide + 1 end
    if r.k == "verdict" then nVerdict = nVerdict + 1 end
end
io.stdout:write(string.format("replay_tape_harness: tape records=%d decide=%d verdict=%d shadowDm7=%s shadowTotem=%s -> %s\n",
    #flat, nDecide, nVerdict,
    tostring(ns.Inference and ns.Inference.hs and ns.Inference.hs.shadowDm7N),
    tostring(ns.Inference and ns.Inference.hs and ns.Inference.hs.shadowTotemHealN),
    outDir))
assert(nDecide >= 1, "expected at least one decide on tape")
