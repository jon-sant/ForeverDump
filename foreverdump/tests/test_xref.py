"""xref test: synthesize a WoWCombatLog file from the mock-harness capture (tests/out/ForeverDump.lua) and check that
the timeline merges and matches addon UNIT_COMBAT / UNIT_SPELLCAST to file lines within the window."""
import datetime
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from fdump.dump import Dump  # noqa: E402
from fdump import xref  # noqa: E402
from fdump.luasv import as_list  # noqa: E402

SV = os.path.join(ROOT, "tests/out/ForeverDump.lua")
OUT = os.path.join(ROOT, "tests/out/xref")
PLAYER = "Player-1234-0ABCDEF0"
MOB = "Creature-0-1-2-3-4-5"
fails = 0


def check(cond, msg):
    global fails
    print(("  ok   " if cond else "  FAIL ") + msg)
    if not cond:
        fails += 1


def stamp(epoch, offset_h=-4):
    tz = datetime.timezone(datetime.timedelta(hours=offset_h))
    d = datetime.datetime.fromtimestamp(epoch, tz)
    return "%d/%d/%d %02d:%02d:%02d.%04d%+d" % (d.month, d.day, d.year, d.hour, d.minute, d.second, d.microsecond // 100, offset_h)


ADV = "0000000000000000,9000,10000,0,0,0,0,0,0,1,0,100,0,79.10,450.92,2406,5.9426,80"

dump = Dump.load(SV)
os.makedirs(OUT, exist_ok=True)
lines = ["%s  COMBAT_LOG_VERSION,22,ADVANCED_LOG_ENABLED,1,BUILD_VERSION,1.60.1,PROJECT_ID,18" % stamp(1791400000)]
expected = {"UNIT_COMBAT": 0, "UNIT_SPELLCAST_SUCCEEDED": 0}
deliberate_far = 0
for sess in as_list(dump.combatlog.get("sessions")):
    anchor = sess.get("anchor")
    for e in as_list(sess.get("events")):
        ep, _ = xref.anchor_epoch(anchor, e.get("t"), (sess.get("startTime"), sess.get("startEpoch")))
        if ep is None:
            continue
        a = as_list(e.get("a"))
        if e.get("e") == "UNIT_COMBAT" and a:
            amt = a[3] if isinstance(a[3], int) else 777
            dst, dname = (PLAYER, "Mockchar") if a[0] == "player" else (MOB, "Mock Boss")
            src, sname = (MOB, "Mock Boss") if a[0] == "player" else (PLAYER, "Mockchar")
            lines.append("%s  SWING_DAMAGE,%s,\"%s\",0xa48,0x0,%s,\"%s\",0x511,0x0,%s,%s,%d,%d,-1,1,0,0,0,nil,nil,nil,ST"
                         % (stamp(ep + 0.040), src, sname, dst, dname, src, ADV, amt, amt + 50))
            expected["UNIT_COMBAT"] += 1
        elif e.get("e") == "UNIT_SPELLCAST_SUCCEEDED" and a and a[0] == "player" and isinstance(a[2], int):
            lines.append("%s  SPELL_CAST_SUCCESS,%s,\"Mockchar\",0x511,0x0,0000000000000000,nil,0x80000000,0x80000000,%d,\"Spell\",0x4,%s,%s"
                         % (stamp(ep + 0.020), PLAYER, a[2], PLAYER, ADV))
            expected["UNIT_SPELLCAST_SUCCEEDED"] += 1
    # one file line far outside every window: must stay unmatched
    if anchor:
        lines.append("%s  SWING_DAMAGE,%s,\"Mock Boss\",0xa48,0x0,%s,\"Mockchar\",0x511,0x0,%s,%s,5,5,-1,1,0,0,0,nil,nil,nil,ST"
                     % (stamp(anchor["epoch"] + 4000), MOB, PLAYER, MOB, ADV))
        deliberate_far += 1
path = os.path.join(OUT, "WoWCombatLog-synthetic.txt")
with open(path, "w") as f:
    f.write("\n".join(lines) + "\n")
check(expected["UNIT_COMBAT"] >= 2, "synthetic file log: %s lines for %s" % (len(lines), expected))

r = subprocess.run([sys.executable, os.path.join(ROOT, "tools/fdump.py"), "xref", SV, "--file", path, "--player", PLAYER,
                    "-o", OUT], capture_output=True, text=True, cwd=ROOT)
check(r.returncode == 0, "fdump.py xref runs")
if r.returncode:
    print(r.stdout, r.stderr)
rows = [json.loads(l) for l in open(os.path.join(OUT, "timeline.jsonl"))]
srcs = {x["source"] for x in rows}
check({"addon-cl", "file-cl", "addon-event"} <= srcs, "timeline merges sources: %s" % sorted(srcs))
check(all(rows[i]["epoch"] <= rows[i + 1]["epoch"] for i in range(len(rows) - 1)), "timeline ordered by epoch")
uc = [x for x in rows if x["source"] == "addon-cl" and x["event"] == "UNIT_COMBAT"]
matched = [x for x in uc if x.get("match", {}).get("quality") not in (None, "unmatched")]
check(len(matched) == expected["UNIT_COMBAT"], "every addon UNIT_COMBAT matched to its SWING_DAMAGE (%d/%d)" % (len(matched), len(uc)))
check(all(abs(x["match"]["dtMs"] - 40) < 1100 for x in matched), "match offsets near the synthetic +40 ms")
q = {x["match"]["quality"] for x in matched}
check("time-only:secret-amount" in q, "match qualities on the smoke capture: %s" % sorted(q))
# unit-level: clear amounts -> exact / time+amount / amount-differs
items = [
    {"epoch": 100.000, "precise": True, "source": "addon-cl", "event": "UNIT_COMBAT", "a": ["player", "WOUND", "", 321, 1]},
    {"epoch": 200.000, "precise": True, "source": "addon-cl", "event": "UNIT_COMBAT", "a": ["player", "WOUND", "", 50, 1]},
    {"epoch": 300.000, "precise": True, "source": "addon-cl", "event": "UNIT_COMBAT", "a": ["player", "WOUND", "", 70, 1]},
    {"epoch": 100.030, "precise": True, "source": "file-cl", "event": "SWING_DAMAGE", "dst": PLAYER, "src": MOB, "amount": 321},
    {"epoch": 200.400, "precise": True, "source": "file-cl", "event": "SPELL_DAMAGE", "dst": PLAYER, "src": MOB, "amount": 50},
    {"epoch": 300.050, "precise": True, "source": "file-cl", "event": "SPELL_DAMAGE", "dst": PLAYER, "src": MOB, "amount": 99},
]
st = xref.match(items, PLAYER)
check(st == {"exact": 1, "time+amount": 1, "time-only:amount-differs": 1}, "match quality classes: %s" % st)
secret_rows = [x for x in uc if x["secretStatus"] == "secret"]
check(len(secret_rows) >= 1 and all(x["secret"] for x in secret_rows), "secret status carried per line")
far = [x for x in rows if x["source"] == "file-cl" and x.get("amount") == 5 and not x.get("matchedBy")]
check(len(far) == deliberate_far, "far-away file line stays unmatched")
md = open(os.path.join(OUT, "TIMELINE.md")).read()
check("## Combat 1" in md and "| time | source |" in md, "TIMELINE.md has per-combat excerpts")
print("XREF OK" if fails == 0 else "XREF FAILED: %d" % fails)
sys.exit(1 if fails else 0)
