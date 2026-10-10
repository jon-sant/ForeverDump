"""v2.2.3 checks: static perf lint (rules fire on a bad addon, ForeverDump is clean), migrate carries the perf section,
generated mocks ship perf_guard.lua + spec/perf_spec.lua (and it passes), PERF.md growth/impact flags (v2.2.3 sessions and
legacy profile snapshots), taint reclassification (own message frame = contained, chat fading = benign-chat).
Needs tests/out/hsm_sv.lua (tests/hsm.lua)."""
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from fdump import perfcheck, perf as perfmod, taintlog, migrate, mocks  # noqa: E402
from fdump.dump import Dump  # noqa: E402

N = [0]


def ok(cond, msg):
    N[0] += 1
    if not cond:
        raise SystemExit("FAIL: " + msg)


# ---------------------------------------------------------------- perfcheck: every rule fires on a bad addon
tmp = tempfile.mkdtemp()
bad = os.path.join(tmp, "BadAddon")
os.makedirs(bad)
with open(os.path.join(bad, "BadAddon.toc"), "w") as f:
    f.write("## Interface: 16001\n## Title: BadAddon\nBad.lua\nGood.lua\n")
with open(os.path.join(bad, "Bad.lua"), "w") as f:
    f.write('''local f = CreateFrame("Frame")
local hist = {}
local function meta()
    local n = 0
    for k in pairs(_G) do n = n + 1 end
    return n
end
f:SetScript("OnUpdate", function(self, elapsed)
    self.text = "n=" .. #hist
    table.sort(hist)
end)
f:SetScript("OnEvent", function(self, event, ...)
    hist[#hist + 1] = event
    if #hist > 50 then table.remove(hist, 1) end
    local m = meta()
    UpdateAddOnMemoryUsage()
end)
f:RegisterAllEvents()
local t = C_Timer.NewTicker(1, function() end)
''')
with open(os.path.join(bad, "Good.lua"), "w") as f:
    f.write('''local f = CreateFrame("Frame")
local acc, dirty = 0, false
local function onUpdate(self, elapsed)
    acc = acc + elapsed
    if acc < 0.1 then return end
    acc = 0
    if not dirty then self:SetScript("OnUpdate", nil) return end
    dirty = false
end
local function mark() dirty = true f:SetScript("OnUpdate", onUpdate) end
f:SetScript("OnEvent", function() mark() end)
-- perf-ok: cached once per session
for k in pairs(_G) do end
local tk = C_Timer.NewTicker(5, function() end)
tk:Cancel()
''')
fs = perfcheck.scan(bad)
rules = {(x["file"], x["rule"], x["level"]) for x in fs}
for rule, level in (("onupdate-every-frame", "error"), ("global-walk", "error"), ("heavy-call", "error"), ("sort-in-handler", "warn"),
                    ("string-build-onupdate", "warn"), ("queue-shift", "warn"), ("register-all-events", "error")):
    ok(("Bad.lua", rule, level) in rules, "perfcheck flags %s (%s) in Bad.lua: %s" % (rule, level, sorted(rules)))
ok(("Bad.lua", "ticker-no-cancel", "warn") in rules, "perfcheck flags an uncancelled NewTicker")
ok(not [x for x in fs if x["file"] == "Good.lua"], "throttled, self-removing OnUpdate + annotated walk + cancelled ticker: clean: %s" %
   [x for x in fs if x["file"] == "Good.lua"])
heavy = [x for x in fs if x["rule"] == "heavy-call"]
ok(any("meta" in x["message"] for x in heavy) and any("UpdateAddOnMemoryUsage" in x["message"] for x in heavy),
   "heavy-call names the _G walker and the expensive client API")
fd = perfcheck.scan(os.path.join(ROOT, "ForeverDump"))
c = perfcheck.summary(fd)
ok(c["error"] == 0 and c["warn"] == 0, "ForeverDump passes its own perf lint (0 errors, 0 warnings): %s" %
   [(x["file"], x["line"], x["rule"]) for x in fd if x["level"] != "note"])
md = perfcheck.markdown(fs, "Performance lint", "BadAddon")
ok("no idle OnUpdate" in md and "**error**" in md, "perfcheck markdown states the rule and findings")
r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "fdump.py"), "perfcheck", bad], capture_output=True, text=True)
ok(r.returncode == 1 and "perfcheck:" in r.stdout, "fdump.py perfcheck exits 1 on errors")
r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "fdump.py"), "perfcheck", os.path.join(ROOT, "ForeverDump"), "--strict"],
                   capture_output=True, text=True)
ok(r.returncode == 0, "fdump.py perfcheck --strict passes on ForeverDump: " + r.stdout[-300:])

# ---------------------------------------------------------------- migrate + generated mocks carry the perf checks
sv = os.path.join(ROOT, "tests", "out", "hsm_sv.lua")
d = Dump.load(sv)
rep = migrate.Migrator(d).scan(bad)
ok(rep["performanceCounts"]["error"] >= 4, "migrate report includes perf lint counts: %s" % rep["performanceCounts"])
mmd = migrate.markdown(rep)
ok("## Performance (PERFORMANCE.md)" in mmd and "perf_spec.lua" in mmd, "MIGRATION.md has the Performance section")
mo = os.path.join(tmp, "mocks")
files = mocks.generate(d, mo)
ok("perf_guard.lua" in files and "spec/perf_spec.lua" in files, "generated mocks ship perf_guard.lua + spec/perf_spec.lua")
r = subprocess.run(["lua5.1", os.path.join(mo, "run_spec.lua"), os.path.join(mo, "spec", "perf_spec.lua")], capture_output=True,
                   text=True, timeout=120)
ok(r.returncode == 0, "generated perf_spec passes (flat per-event cost, no idle OnUpdate): " + (r.stdout + r.stderr)[-600:])

# ---------------------------------------------------------------- PERF.md from the mock capture (v2.2.3 perf sessions)
rp = perfmod.analyze(d)
ok(rp["source"] == "perf" and rp["sessions"], "perf sessions read from ForeverDumpLogDB.perf")
s0 = rp["sessions"][-1]
ok(s0["impactPct"] is not None and s0["impactPct"] < 1 and s0["handlers"], "mock capture impact < 1%% (%s%%)" % s0["impactPct"])
ok(any(h["key"].startswith("Inference.") or h["key"].startswith("HSMUI.") for h in s0["handlers"]), "handler keys recorded")
pm = perfmod.markdown(rp)
ok("# PERF" in pm and "of wall time" in pm, "PERF.md written")


class FakeDump:
    def __init__(self, log, sections=None, db=None):
        self.log, self.sections, self.db = log, sections or {}, db or {"addonVersion": "x"}


grow = {"n": 0, "ms": 0, "max": 1, "w": {}}
flat = {"n": 0, "ms": 0, "max": 1, "w": {}}
for wi in range(1, 31):
    grow["w"][wi] = [30, 30 * (0.01 + wi * 0.01)]
    flat["w"][wi] = [30, 30 * 0.02]
for h in (grow, flat):
    h["n"] = sum(v[0] for v in h["w"].values())
    h["ms"] = sum(v[1] for v in h["w"].values())
fdmp = FakeDump({"perf": {"v": 1, "sessions": [{"sid": "t", "version": "2.2.3", "duration": 450, "handlers": {"grow": grow, "flat": flat},
                                                 "samples": [{"t": i * 5, "heapKB": 1000, "sz": {"q": i}} for i in range(40)]}]}})
rs = perfmod.analyze(fdmp)["sessions"][0]
gh = {h["key"]: h for h in rs["handlers"]}
ok(gh["grow"]["growth"]["grows"] and not gh["flat"]["growth"]["grows"], "growth flag: per-call cost rising over the session is flagged, flat is not")
ok(any("grow" in f for f in rs["flags"]) and any("size q" in f for f in rs["flags"]), "flags list growing handler + unbounded size: %s" % rs["flags"])
legacy = FakeDump({}, {"profile": {"snapshots": [
    {"reason": "capture:on", "gameTime": 100, "profiler": {"application": {"RecentAverageTime": 20.7}},
     "addons": {"ForeverDump": {"memoryKB": 46211, "metrics": {"SessionAverageTime": 0.03}}}},
    {"reason": "capture:off", "gameTime": 186, "profiler": {"application": {"RecentAverageTime": 59.3}},
     "addons": {"ForeverDump": {"memoryKB": 70584, "metrics": {"SessionAverageTime": 0.034}}}}]}})
lg = perfmod.analyze(legacy)
ok(lg["source"].startswith("profile") and lg["legacy"][0]["flags"] and "x2.9" in lg["legacy"][0]["flags"][0],
   "legacy (pre-2.2.3) flags the run-4 frame-time rise from the profile snapshots: %s" % lg["legacy"][0]["flags"])

# ---------------------------------------------------------------- taint: own message frame contained, chat fading benign
tl = os.path.join(tmp, "taint.log")
with open(tl, "w") as f:
    f.write("""10/7 22:58:43.317  Execution tainted by ForeverDump while reading field value (<table: 01>) - Interface/AddOns/Blizzard_SharedXMLBase/SecureTypes.lua:279
10/7 22:58:43.317      Interface/AddOns/Blizzard_SharedXMLBase/SecureTypes.lua:279
10/7 22:58:43.317      securecallfunction()
10/7 22:58:43.317      Interface/AddOns/Blizzard_SharedXMLBase/SecureTypes.lua:283 GetValue()
10/7 22:58:43.317      Interface/AddOns/Blizzard_SharedXML/CircularBuffer.lua:49 PushFront()
10/7 22:58:43.317      Interface/AddOns/Blizzard_SharedXML/ScrollingMessageFrame.lua:11 AddMessage()
10/7 22:58:43.317      pcall()
10/7 22:58:43.317      Interface/AddOns/ForeverDump/Controls.lua:195 opsFor()
10/7 22:58:53.561  Execution tainted by ForeverDump while reading field oldestFadingLineTimestamp (<table: 02>) - Interface/AddOns/Blizzard_SharedXML/ScrollingMessageFrame.lua:765 ChatFrame1:UpdateFading()
10/7 22:58:53.561      Interface/AddOns/Blizzard_SharedXML/ScrollingMessageFrame.lua:765 ChatFrame1:UpdateFading()
10/7 22:58:54.000  Execution tainted by ForeverDump while reading field shown (<table: 03>) - Interface/AddOns/Blizzard_UnitFrame/PlayerFrame.lua:10
10/7 22:58:54.000      Interface/AddOns/Blizzard_UnitFrame/PlayerFrame.lua:10 PlayerFrame_Update()
""")
by = taintlog.parse(tl)["summary"]["byClass"]
ok(by == {"contained": 1, "benign-chat": 1, "blizzard-frame": 1}, "taint v2.2.3 classes (own frame contained, chat benign, real Blizzard frame kept): %s" % by)

print("test_v223: %d checks passed" % N[0])
