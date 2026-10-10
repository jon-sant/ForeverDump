-- v2.2.11 (run 9 taint.log "Execution tainted by ForeverDump while reading field isdst"): ns.TimeAnchor().utcOffset is
-- now plain arithmetic on the two date() tables (nothing written into a client table, no time(table) call). It must
-- equal the old time(l with isdst=false) - time(u) result's intent: local wall clock minus UTC wall clock.
-- Run under several TZ values by tests/run_converter_tests.sh. usage: lua5.1 tests/utcoffset.lua ForeverDump
local dir = arg[1] or "ForeverDump"
local src = assert(io.open(dir .. "/Core.lua")):read("*a")
local body = src:match("(local function utcOffset%(%).-\nend)\n")
assert(body, "utcOffset not found")
assert(not body:find("isdst", 1, true) and not body:find("time%("), "utcOffset must not write isdst or call time(table)")
date = os.date   -- the client global
local f = assert(loadstring(body .. "\nreturn utcOffset"))()
local l, u = os.date("*t"), os.date("!*t")
local expect = (l.yday - u.yday) * 86400 + (l.hour - u.hour) * 3600 + (l.min - u.min) * 60
if l.year ~= u.year then expect = (l.year > u.year and 1 or -1) * 86400 + (l.hour - u.hour) * 3600 + (l.min - u.min) * 60 end
-- independent reference: os.time() of the UTC wall clock read as local time
local ref = os.time() - os.time(os.date("!*t"))
if os.date("*t").isdst then ref = ref + 3600 end
local got = f()
local ok = got == expect and got == ref
print(string.format("utcoffset %s: TZ=%s offset %s (arith %d, os.time reference %d)", ok and "OK" or "FAILED",
    tostring(os.getenv("TZ")), tostring(got), expect, ref))
if not ok then os.exit(1) end
