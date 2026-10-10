"""v2.2.10 permanent regression: lossless DAMAGE_METER_* run-length compaction.

The addon folds identical DAMAGE_METER_* rows into run rows (rc/q/dt/dq) in the combat ring, the event recorder
and the replay tape. The converter (tools/fdump/dmrle.py, called by Dump) must rebuild EVERY original occurrence:
same order, same ms time, same payload. Proof: the same stream is replayed through the whole addon twice
(tests/bg_replay.lua, with and without RLE) and the expanded RLE streams must equal the raw ones exactly.

* synthetic: a generated BG-like stream (always runs)
* run 8: the real 21.7 min battleground capture, when the private capture is present on this box
  (exported to tests/out only, deleted afterwards; it never leaves the box).
"""
import collections
import json
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from fdump import dmrle  # noqa: E402
sys.path.insert(0, os.path.join(ROOT, "tests"))
from bg_synth import synth_stream  # noqa: E402

RUN8 = os.path.join(ROOT, "real", "2026-10-08-run8-bg")
RUN8_SV = os.path.join(RUN8, "sv", "ForeverDump.lua")


def replay(stream, out, norle, duration):
    cmd = ["lua5.1", "tests/bg_replay.lua", stream, "--duration", str(int(duration)), "--dump-streams", out]
    if norle:
        cmd.append("--no-rle")
    subprocess.run(cmd, cwd=ROOT, check=True, stdout=subprocess.DEVNULL)


def load(p):
    s = {"combat": [], "record": [], "tape": []}
    with open(p) as f:
        for line in f:
            o = json.loads(line)
            s[o["stream"]].append(o["r"])
    return s


def norm(r):
    return {k: (round(v, 3) if k == "t" else v) for k, v in r.items()} if isinstance(r, dict) else r


def dm_tuples(tape):
    return [(r["d"], r.get("ty"), r.get("sid"), tuple(r.get("st") or []))
            for r in sorted(tape, key=lambda r: r["i"]) if r.get("k") == "dm"]


class RoundTrip:
    stream = None
    duration = None

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp(dir=os.path.join(ROOT, "tests", "out"))
        cls.prepare()
        on, off = os.path.join(cls.tmp, "on.jsonl"), os.path.join(cls.tmp, "off.jsonl")
        # v2.2.11 speed-up: the RLE and no-RLE replays are independent processes -> run them side by side
        from concurrent.futures import ThreadPoolExecutor
        with ThreadPoolExecutor(2) as ex:
            list(ex.map(lambda a: replay(cls.stream, a[0], a[1], cls.duration), [(on, False), (off, True)]))
        cls.on, cls.off = load(on), load(off)

    @classmethod
    def tearDownClass(cls):
        for f in os.listdir(cls.tmp):
            os.remove(os.path.join(cls.tmp, f))
        os.rmdir(cls.tmp)

    def test_combat_and_record_exact(self):
        for st in ("combat", "record"):
            stored = self.on[st]
            exp = dmrle.expand_events(stored)
            self.assertLess(len(stored), len(self.off[st]), st + ": nothing folded")
            self.assertEqual(len(exp), len(self.off[st]), st)
            bad = [k for k, (a, b) in enumerate(zip(exp, self.off[st])) if norm(a) != norm(b)]
            self.assertEqual(bad[:5], [], st + " occurrences differ")

    def test_tape_exact(self):
        exp = dmrle.expand_tape(self.on["tape"])
        ids = [r["i"] for r in exp]
        self.assertEqual(sorted(ids), list(range(1, len(ids) + 1)), "tape seq not unique+contiguous after expansion")
        a, b = dm_tuples(exp), dm_tuples(self.off["tape"])
        self.assertGreater(len(b), 0)
        self.assertLess(sum(1 for r in self.on["tape"] if r.get("k") == "dm"), len(b), "tape: nothing folded")
        self.assertEqual(collections.Counter(a), collections.Counter(b))
        self.assertEqual(a, b)


class Synthetic(RoundTrip, unittest.TestCase):
    @classmethod
    def prepare(cls):
        cls.stream = os.path.join(cls.tmp, "synth.lua")
        cls.duration = max(60, synth_stream(cls.stream) + 1)


@unittest.skipUnless(os.path.exists(RUN8_SV), "run 8 capture not on this box")
class Run8(RoundTrip, unittest.TestCase):
    @classmethod
    def prepare(cls):
        cls.stream = os.path.join(cls.tmp, "run8.lua")
        subprocess.run([sys.executable, "-m", "fdump.bgreplay", RUN8_SV, cls.stream], cwd=os.path.join(ROOT, "tools"),
                       check=True, stdout=subprocess.DEVNULL)
        cls.duration = 1800


class Expander(unittest.TestCase):
    def test_hand_built(self):
        rows = [{"e": "A", "t": 1.0}, {"e": "DM", "t": 1.5, "rc": 3, "q": 2, "dt": [10, 0], "dq": [2, 1]},
                {"e": "B", "t": 1.505}]
        exp = dmrle.expand_events(rows)
        self.assertEqual([(r["e"], r["t"]) for r in exp],
                         [("A", 1.0), ("DM", 1.5), ("B", 1.505), ("DM", 1.51), ("DM", 1.51)])


if __name__ == "__main__":
    unittest.main(verbosity=1)
