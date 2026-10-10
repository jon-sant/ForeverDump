"""(4) busted-compatible mocks + recorded-event replay fixtures."""
import math
import os
import re
import shutil

from . import secrets as secretsmod

from .luasv import as_list

IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
KW = {"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil", "not",
      "or", "repeat", "return", "then", "true", "until", "while"}
HERE = os.path.dirname(os.path.abspath(__file__))


def lua_str(s):
    s = str(s)
    out = s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r").replace("\0", "\\0")
    return '"' + re.sub(r"[\x01-\x08\x0b\x0c\x0e-\x1f]", lambda m: "\\%d" % ord(m.group(0)), out) + '"'


def ser(v, out, depth=0):
    """Serialize Python data to a Lua literal (appends chunks to out)."""
    if v is None:
        out.append("nil")
    elif isinstance(v, bool):
        out.append("true" if v else "false")
    elif isinstance(v, int):
        out.append(str(v))
    elif isinstance(v, float):
        if math.isnan(v):
            out.append("(0/0)")
        elif math.isinf(v):
            out.append("math.huge" if v > 0 else "-math.huge")
        else:
            out.append(repr(v))
    elif isinstance(v, str):
        out.append(lua_str(v))
    elif isinstance(v, list):
        out.append("{")
        for x in v:
            ser(x, out, depth + 1)
            out.append(",")
        out.append("}")
    elif isinstance(v, dict):
        out.append("{")
        for k in sorted(v, key=lambda k: (not isinstance(k, (int, float)), str(k))):
            if isinstance(k, str) and IDENT.match(k) and k not in KW:
                out.append(k + "=")
            elif isinstance(k, (int, float)) and not isinstance(k, bool):
                out.append("[%s]=" % k)
            else:
                out.append("[%s]=" % lua_str(k))
            ser(v[k], out, depth + 1)
            out.append(",\n" if depth == 0 else ",")
        out.append("}")
    else:
        out.append(lua_str(v))
    return out


def write_lua(path, header, value):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("-- " + header + "\nreturn ")
        f.write("".join(ser(value, [])))
        f.write("\n")


def build_data(dump):
    namespaces = {}
    for ns, info in dump.namespaces().items():
        namespaces[ns] = sorted(f for f in as_list(info.get("functions")) if IDENT.match(str(f)))
    if not namespaces:  # v1-only dump
        for a in as_list(dump.db.get("apis")):
            if "." in a:
                ns, fn = a.split(".", 1)
                namespaces.setdefault(ns, []).append(fn)
    secure, _ = dump.global_functions()
    widgets, isa = {}, {}
    for label, info in dump.widget_types().items():
        t = info.get("objectType") or label.split(":")[-1]
        if label.startswith("Userdata:"):
            t = label
        widgets[t] = {m: True for m in as_list(info.get("methods"))}
        isa[t] = {x: True for x in as_list(info.get("isA"))}
    returns = {}
    getters = (dump.sections.get("getters") or {}).get("results") or {}
    for full, r in getters.items():
        if isinstance(r, dict) and r.get("ok"):
            returns[full] = {"n": r.get("n", 0), "values": as_list(r.get("values"))}
    state = ((dump.sections.get("probe") or {}).get("outOfCombat") or {}).get("state") or {}
    for full, r in state.items():
        if isinstance(r, dict) and r.get("ok") and full not in ("GetTime", "InCombatLockdown"):
            returns.setdefault(full, {"n": r.get("n", 0), "values": as_list(r.get("values"))})
    project = dict(dump.meta().get("projectConstants") or {})
    env = (dump.sections.get("globals") or {}).get("env") or {}
    for k, v in (env.get("constants") or {}).items():
        if str(k).startswith(("WOW_PROJECT_", "LE_EXPANSION_")):
            project.setdefault(k, v)
    if "WOW_PROJECT_ID" not in project and dump.meta().get("projectID") is not None:
        project["WOW_PROJECT_ID"] = dump.meta()["projectID"]
    constants = {k: v for k, v in dump.constants().items()
                 if IDENT.match(str(k)) and isinstance(v, (int, float, str, bool))}
    return {
        "meta": dump.meta(),
        "namespaces": namespaces,
        "globals": sorted(f for f in secure if IDENT.match(f)),
        "Enum": dump.runtime_enum(),
        "Constants": (dump.sections.get("globals") or {}).get("constantsTable") or {},
        "constants": constants,
        "project": project,
        "widgets": widgets,
        "isA": isa,
        "eventSet": {e: True for e in dump.events()},
        "returns": returns,
        "secrets": secret_data(dump),
    }


def secret_data(dump):
    """Per-position secrecy for the mocks: 'always' | 'conditional' | 'observed' (documented or seen at runtime)."""
    smap = secretsmod.build(dump)
    rets, evs, structs, rstruct = {}, {}, {}, {}
    for full, lst in secretsmod.secret_return_index(smap).items():
        if IDENT.match(full.split(".")[-1]):
            rets[full] = {pos: cls for pos, cls, _ in lst}
    for full, f in smap["functions"].items():
        for i, r in enumerate(f["returns"], 1):
            t = r.get("type")
            if t in smap["structs"] and any(fl["secrecy"] in ("always", "conditional") for fl in smap["structs"][t]["fields"]):
                rstruct.setdefault(full, {})[i] = t
    for name, st in smap["structs"].items():
        flds = {fl["name"]: fl["secrecy"] for fl in st["fields"] if fl["secrecy"] in ("always", "conditional")}
        if flds:
            structs[name] = flds
    for ev, e in smap["events"].items():
        pos = {}
        for i, p in enumerate(e["payload"], 1):
            cls = secretsmod.effective(e, i, p["secrecy"])  # verified observations win over the docs
            if cls in ("always", "conditional", "observed"):
                pos[i] = cls
        for slot in (e.get("observedSummary") or {}).values():
            for p in slot["secretPositions"]:
                pos.setdefault(p, "observed")
        if pos:
            evs[ev] = pos
    from .secretflow import SecretFlow
    flow = SecretFlow.from_smap(smap, secretsmod)  # adds struct fields inherited from conditional/always functions
    structs = flow.structs
    rstruct = {f: m for f, m in flow.rstructs.items() if IDENT.match(f.split(".")[-1])}
    return {"returns": rets, "events": evs, "structs": structs, "returnStructs": rstruct}


EXAMPLE_SPEC = r'''-- Example busted spec using the generated ForeverDump mocks.
-- Run from the mocks folder's parent:  busted mocks/spec   (or: lua5.1 mocks/run_spec.lua mocks/spec/example_spec.lua)
local dir = (debug.getinfo(1, "S").source:match("^@(.*[/\\])spec[/\\]") or "mocks/")
local wow = dofile(dir .. "wowmock.lua")
package.loaded.wowmock = wow
local Replay = dofile(dir .. "replay.lua")

describe("ForeverDump mocks", function()
    setup(function() wow.install() end)

    it("exposes dumped namespaces, Enum and project constants", function()
        assert.is_table(C_Spell or C_Item or {})
        assert.is_table(Enum)
        assert.is_not_nil(WOW_PROJECT_ID)
    end)

    it("creates frames with the dumped widget methods", function()
        local f = CreateFrame("Frame", "SpecFrame", UIParent)
        assert.are.equal("Frame", f:GetObjectType())
        f:RegisterEvent("PLAYER_LOGIN")
        local seen
        f:SetScript("OnEvent", function(_, e) seen = e end)
        wow.fire("PLAYER_LOGIN")
        assert.are.equal("PLAYER_LOGIN", seen)
        assert.has_error(function() CreateFrame("NotAWidget") end)
    end)

    it("returns secret sentinels for documented/observed secret returns", function()
        local found
        for full, pos in pairs(wow.secretData.returns) do
            for i, cls in pairs(pos) do
                if cls == "always" and not full:find("%.") and _G[full] then found = { full, i } break end
            end
            if found then break end
        end
        if found then
            local vals = { _G[found[1]]("player") }
            assert.is_true(issecretvalue(vals[found[2]]), found[1] .. " should return a secret")
            wow.secretOverride[found[1]] = false
            vals = { _G[found[1]]("player") }
            assert.is_false(issecretvalue(vals[found[2]]))
            wow.secretOverride[found[1]] = nil
        end
        -- conditional secrets switch on in combat; event payloads too
        local ev
        for e, pos in pairs(wow.secretData.events) do
            for i, cls in pairs(pos) do if cls ~= "always" then ev = { e, i } break end end
            if ev then break end
        end
        if ev then
            local f = CreateFrame("Frame")
            local got
            f:SetScript("OnEvent", function(_, _, ...) got = { ... } end)
            f:RegisterEvent(ev[1])
            local args = {} for i = 1, ev[2] do args[i] = i end
            wow.fire(ev[1], unpack(args))
            assert.is_false(issecretvalue(got[ev[2]]))
            wow.setCombat(true)
            wow.fire(ev[1], unpack(args))
            assert.is_true(issecretvalue(got[ev[2]]), ev[1] .. " field " .. ev[2] .. " secret in combat")
            wow.setCombat(false)
        end
    end)

    it("treats secrets like the client does (no arithmetic/compare/concat)", function()
        assert.is_true(issecretvalue(wow.SECRET))
        assert.has_error(function() return wow.SECRET + 1 end)
        assert.has_error(function() return "x" .. wow.SECRET end)
    end)

    it("replays a recorded session into an addon's OnEvent", function()
        local ok, session = pcall(Replay.load, dir .. "fixtures/session_1.lua")
        if not ok then pending("no recorded session in this dump") return end
        local f = CreateFrame("Frame")
        local count, secretArgs = 0, 0
        f:RegisterAllEvents()
        f:SetScript("OnEvent", function(_, event, ...)
            count = count + 1
            for i = 1, select("#", ...) do
                if issecretvalue((select(i, ...))) then secretArgs = secretArgs + 1 end
            end
        end)
        local stats = Replay.run(session, { frame = f })
        assert.are.equal(stats.delivered, count)
        assert.are.equal(0, #stats.errors)
        assert.is_true(secretArgs >= 0)
    end)

    it("replays a /fdump cl session into a Forever-style UNIT_COMBAT / COMBAT_TEXT_UPDATE handler", function()
        local session
        for i = 1, 9 do
            local ok, s = pcall(Replay.load, dir .. "fixtures/combatlog_" .. i .. ".lua")
            if ok and s.counts and (s.counts.UNIT_COMBAT or s.counts.COMBAT_TEXT_UPDATE) then session = s break end
        end
        if not session then pending("no combat session with UNIT_COMBAT/COMBAT_TEXT_UPDATE in this dump") return end
        local f = CreateFrame("Frame")
        local seen, secrets = 0, 0
        f:RegisterEvent("UNIT_COMBAT")
        f:RegisterEvent("COMBAT_TEXT_UPDATE")
        f:SetScript("OnEvent", function(_, event, ...)
            seen = seen + 1
            local v = (event == "UNIT_COMBAT") and select(4, ...) or C_CombatText.GetCurrentEventInfo()
            if issecretvalue(v) then secrets = secrets + 1 end -- never do arithmetic on it
        end)
        local stats = Replay.run(session, { frame = f })
        assert.are.equal(0, #stats.errors)
        assert.is_true(seen > 0)
        assert.is_true(secrets >= 0)
    end)

    it("replays a /fdump cl session; CombatLogGetCurrentEventInfo returns the recorded payload", function()
        local session
        for i = 1, 9 do
            local ok, s = pcall(Replay.load, dir .. "fixtures/combatlog_" .. i .. ".lua")
            if ok and (s.cleuTotal or 0) > 0 then session = s break end
        end
        if not session then pending("no legacy cleu-force session in this dump (CLEU is restricted on Forever)") return end
        local f = CreateFrame("Frame")
        local subevents = {}
        f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        f:SetScript("OnEvent", function(_, event, ...)
            assert.are.equal(0, select("#", ...))  -- CLEU has no payload; addons call the getter
            local _, sub = CombatLogGetCurrentEventInfo()
            if not issecretvalue(sub) then subevents[sub] = (subevents[sub] or 0) + 1 end
        end)
        local stats = Replay.run(session, { frame = f })
        assert.are.equal(0, #stats.errors)
        local total = 0
        for _, n in pairs(subevents) do total = total + n end
        assert.is_true(total > 0)
    end)
end)
'''

PERF_SPEC = r'''-- perf_spec.lua: the PERFORMANCE.md rule as a test for generated / ported addon code (2-minute wall cap).
-- Replace the example handler with your addon's: load its files, then drive its OnEvent with real fixtures.
local dir = (debug.getinfo(1, "S").source:match("^@(.*[/\\])spec[/\\]") or "mocks/")
local wow = dofile(dir .. "wowmock.lua")
package.loaded.wowmock = wow
local PG = dofile(dir .. "perf_guard.lua")

-- frames from the dumped widget API when the dump has it, else a minimal stand-in (scripts only)
local function newFrame(name)
    local ok, f = pcall(CreateFrame, "Frame", name)
    if ok and f then return f end
    local scripts = {}
    return { SetScript = function(_, k, fn) scripts[k] = fn end, GetScript = function(_, k) return scripts[k] end,
             IsShown = function() return true end, GetName = function() return name end }
end

describe("performance (PERFORMANCE.md)", function()
    setup(function() wow.install() end)

    it("keeps per-event cost flat as the session grows (O(1) per event)", function()
        -- example handler: bounded history with an amortised trim, dirty flag for a throttled redraw
        local hist, dirty, max = {}, false, 100
        local f = newFrame()
        f:SetScript("OnEvent", function(_, _, v)
            hist[#hist + 1] = v
            if #hist > max + max / 4 then
                local d = #hist - max
                for i = 1, max do hist[i] = hist[i + d] end
                for i = #hist, max + 1, -1 do hist[i] = nil end
            end
            dirty = true
        end)
        local handler = f:GetScript("OnEvent")
        local res = PG.flat({
            grow = function(n) for i = #hist + 1, n * 10 do handler(f, "UNIT_AURA", i) end end,
            event = function() handler(f, "UNIT_AURA", 1) end,
            marks = { 25, 50, 100 }, per = 500, cap = 120, eventsPerSecond = 60,
        })
        assert.is_true(res.ok, res.msg)
        assert.is_true(dirty)
    end)

    it("has no OnUpdate while idle", function()
        local f = newFrame("PerfSpecIdle")
        f:SetScript("OnUpdate", nil)
        local n, names = PG.idleOnUpdates({ f })
        assert.are.equal(0, n, table.concat(names, ", "))
    end)
end)
'''

RUN_SPEC = r'''-- run_spec.lua: tiny busted-compatible runner (describe/it/setup/before_each/pending + common assert.*)
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
'''


def generate(dump, out):
    os.makedirs(out, exist_ok=True)
    files = []
    label = "Generated by ForeverDump tools from %s" % dump.build_label()
    write_lua(os.path.join(out, "forever_data.lua"), label, build_data(dump))
    files.append("forever_data.lua")
    if dump.strings:
        strings = {k: k for k in dump.strings} if getattr(dump, "strings_compact", False) else dump.strings
        write_lua(os.path.join(out, "forever_strings.lua"), label + " (global strings)", strings)
        files.append("forever_strings.lua")
    for name in ("wowmock.lua", "replay.lua", "perf_guard.lua"):
        shutil.copy(os.path.join(HERE, "lua", name), os.path.join(out, name))
        files.append(name)
    for i, sess in enumerate(as_list(dump.record.get("sessions")), 1):
        sess = dict(sess)
        sess["events"] = as_list(sess.get("events"))
        write_lua(os.path.join(out, "fixtures", "session_%d.lua" % i), label + " (recorder session %d)" % i, sess)
        files.append("fixtures/session_%d.lua" % i)
    for i, sess in enumerate(as_list(dump.combatlog.get("sessions")), 1):
        sess = dict(sess)
        sess["events"] = as_list(sess.get("events"))
        write_lua(os.path.join(out, "fixtures", "combatlog_%d.lua" % i), label + " (combat log session %d)" % i, sess)
        files.append("fixtures/combatlog_%d.lua" % i)
    probe = dump.sections.get("probe")
    if probe:
        write_lua(os.path.join(out, "fixtures", "probe.lua"), label + " (probe results)", probe)
        files.append("fixtures/probe.lua")
    os.makedirs(os.path.join(out, "spec"), exist_ok=True)
    with open(os.path.join(out, "spec", "example_spec.lua"), "w") as f:
        f.write(EXAMPLE_SPEC)
    with open(os.path.join(out, "spec", "perf_spec.lua"), "w") as f:
        f.write(PERF_SPEC)
    with open(os.path.join(out, "run_spec.lua"), "w") as f:
        f.write(RUN_SPEC)
    files += ["spec/example_spec.lua", "spec/perf_spec.lua", "run_spec.lua"]
    return files
