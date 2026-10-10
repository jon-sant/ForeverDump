-- run_spec.lua: tiny busted-compatible runner (describe/it/setup/before_each/pending + common assert.*)
-- for machines without busted.  Usage: lua5.1 mocks/run_spec.lua mocks/spec/example_spec.lua
local failures, passes, pendings = 0, 0, 0
local befores, setups = {}, {}
local function fmt(v) return type(v) == "string" and string.format("%q", v) or tostring(v) end
assert = setmetatable({}, { __call = function(_, v, msg, ...) if not v then error(msg or "assertion failed", 2) end return v, msg, ... end })
assert.is_true = function(v) if v ~= true then error("expected true, got " .. fmt(v), 2) end end
assert.is_false = function(v) if v ~= false then error("expected false, got " .. fmt(v), 2) end end
assert.is_nil = function(v) if v ~= nil then error("expected nil, got " .. fmt(v), 2) end end
assert.is_not_nil = function(v) if v == nil then error("expected non-nil", 2) end end
assert.is_table = function(v) if type(v) ~= "table" then error("expected table, got " .. type(v), 2) end end
assert.is_function = function(v) if type(v) ~= "function" then error("expected function, got " .. type(v), 2) end end
assert.truthy = function(v) if not v then error("expected truthy", 2) end end
assert.are = { equal = function(a, b) if a ~= b then error("expected " .. fmt(a) .. ", got " .. fmt(b), 2) end end,
               same = function(a, b) if a ~= b then error("not same", 2) end end }
assert.equal = assert.are.equal
assert.has_error = function(f) if pcall(f) then error("expected an error", 2) end end
assert.has_no_error = function(f) local ok, e = pcall(f) if not ok then error("unexpected error: " .. tostring(e), 2) end end
local PENDING = {}
function pending(msg) error(PENDING, 0) end
function setup(f) setups[#setups + 1] = f end
function before_each(f) befores[#befores + 1] = f end
function teardown() end
function after_each() end
local prefix = {}
function describe(name, f) prefix[#prefix + 1] = name f() prefix[#prefix] = nil end
function it(name, f)
    for _, s in ipairs(setups) do s() end
    setups = {}
    for _, b in ipairs(befores) do b() end
    local ok, err = pcall(f)
    local label = table.concat(prefix, " / ") .. " / " .. name
    if ok then passes = passes + 1 print("  ok   " .. label)
    elseif err == PENDING then pendings = pendings + 1 print("  pend " .. label)
    else failures = failures + 1 print("  FAIL " .. label .. "\n       " .. tostring(err)) end
end
for i = 1, #arg do dofile(arg[i]) end
print(string.format("%d passed, %d failed, %d pending", passes, failures, pendings))
os.exit(failures == 0 and 0 or 1)
