-- v2.2.11 permanent regression for run 9's taint.log (97 secret operations blocked, all ForeverDump probes):
--   89x arithmetic at Controls.lua (C.TryTimeLeft: endTimeMS - GetTime()*1000 on a secret endTimeMS)
--    6x arithmetic/compare at Controls.lua (ops matrix OPS on a secret UnitHealth) + print sink "value" (SecureTypes)
--    2x len() at Lab.lua (boundary item: string ops on tostring(secret))
-- Every one now classifies first (ns.ClearNum / ClassifyValue) and never operates on a secret. Asserted at runtime with
-- the mock secret (any touch is counted: wowenv has no Controls/Lab exemption any more) and statically on the source.
-- usage: lua5.1 tests/taint_run9.lua ForeverDump
package.path = "./tests/?.lua;" .. package.path
local addonDir = arg[1] or "ForeverDump"
local fails, passed = 0, 0
local function check(c, m) if c then passed = passed + 1 print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end
local W = require("wowenv")
local S = W.state
local files = {}
for line in io.lines(addonDir .. "/ForeverDump.toc") do
    if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
end
local ns = W.loadAddon(addonDir, files, "ForeverDump")
W.fire("ADDON_LOADED", "ForeverDump")
W.fire("PLAYER_LOGIN")
W.fire("PLAYER_ENTERING_WORLD", true, false)
local SECRET = W.SECRET
local t0 = S.touchedSecret
-- 1 Controls.lua TryTimeLeft
local ok, err, st = ns.Controls.TryTimeLeft(SECRET)
check(ok == nil and type(err) == "string" and err:find("skipped", 1, true) and st == nil and S.touchedSecret == t0,
    "TryTimeLeft(secret endTimeMS): skipped, no arithmetic on the secret (" .. tostring(err) .. ")")
local ok2, _, st2 = ns.Controls.TryTimeLeft(GetTime() * 1000 + 1500)
check(ok2 == true and st2 == "C", "TryTimeLeft(clear endTimeMS) still derives the time left")
-- 2 Controls.lua ops matrix on a secret operand (incl. the print sink)
local r = ns.Controls.OpsFor(SECRET, true)
check(r.state == "S" and r.skipped and r.arith == nil and r.compare == nil and r.print == nil and S.touchedSecret == t0,
    "ops matrix on a secret: state S, skipped, no op and no print sink")
local rc = ns.Controls.OpsFor(100, true)
check(rc.state == "C" and rc.arith and rc.arith.ok == true and rc.compare and rc.print, "ops matrix on a clear value runs every op")
-- 3 Lab.lua secret-string boundary item in combat
S.combat = true
local rec = ns.Lab.Run("test")
S.combat = false
local ss
for _, it in ipairs(rec and rec.items or {}) do if it.id == "secret-string" then ss = it end end
check(ss and ss.healthState == "S" and ss.skipped and ss.ops == nil, "lab secret-string (combat): UnitHealth S, string ops skipped")
check(S.touchedSecret == t0, "no secret touched anywhere (" .. (S.touchedSecret - t0) .. ")")
local rec2 = ns.Lab.Run("test")
local ss2
for _, it in ipairs(rec2 and rec2.items or {}) do if it.id == "secret-string" then ss2 = it end end
check(ss2 and ss2.healthState == "C" and ss2.ops and ss2.ops.len and ss2.ops.len.ok == true, "lab secret-string (ooc, clear): ops still run")
-- 4 static: the classify-first guard precedes the operation in each run-9 site
local function src(f) local h = assert(io.open(addonDir .. "/" .. f)) local s = h:read("*a") h:close() return s end
local cs, ls = src("Controls.lua"), src("Lab.lua")
local tl = cs:match("function C%.TryTimeLeft%(endTimeMS%)(.-)\nend")
check(tl and tl:find("ns.ClearNum(endTimeMS)", 1, true) and not tl:find("endTimeMS -", 1, true)
    and tl:find("ns.ClearNum", 1, true) < tl:find("GetTime", 1, true), "static: TryTimeLeft subtracts only the ClearNum copy")
local of = cs:match("local function opsFor%(v, doPrint%)(.-)\nend")
check(of and of:find('r.state ~= "C"', 1, true) and of:find('r.state ~= "C"', 1, true) < of:find("ipairs(OPS)", 1, true),
    "static: opsFor classifies and returns before any op / print")
local lb = ls:match('"secret%-string"(.-)\n        r%.ops = {}')
check(lb and lb:find('hc ~= "C"', 1, true) and lb:find('hc ~= "C"', 1, true) < lb:find("pcall(tostring, h)", 1, true)
    and lb:find('tostringState ~= "C"', 1, true), "static: lab secret-string classifies UnitHealth and the string first")
print(string.format("taint_run9: %d passed, %d failed", passed, fails))
os.exit(fails == 0 and 0 or 1)
