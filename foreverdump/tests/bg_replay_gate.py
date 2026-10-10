"""v2.2.10 diag perf gate (in-game cost only): replay a 30 min battleground through the whole addon, accelerated,
and assert tests/bg_replay.lua --assert (frame-time limits of the perf bench, unchanged; nothing lost).
Drives the load from REAL data when the private run 8 capture is on this box AND included under the unhash 100%
rule (exported to tests/out, deleted after; never packaged), else from the synthetic BG stream (tests/bg_synth.py)."""
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUN8_SV = os.path.join(ROOT, "real", "2026-10-08-run8-bg", "sv", "ForeverDump.lua")
try:
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    from fdump import inclusion as _inc
    _RUN8_INCLUDED = _inc.is_included("2026-10-08-run8-bg")
except Exception:
    _RUN8_INCLUDED = True
sys.path.insert(0, os.path.join(ROOT, "tests"))
from bg_synth import synth_stream  # noqa: E402


def main():
    os.makedirs(os.path.join(ROOT, "tests", "out"), exist_ok=True)
    fd, stream = tempfile.mkstemp(suffix=".lua", dir=os.path.join(ROOT, "tests", "out"))
    os.close(fd)
    try:
        if os.path.exists(RUN8_SV) and _RUN8_INCLUDED:
            src = "run 8 (real)"
            subprocess.run([sys.executable, "-m", "fdump.bgreplay", RUN8_SV, stream], cwd=os.path.join(ROOT, "tools"),
                           check=True, stdout=subprocess.DEVNULL)
        else:
            src = "synthetic" if _RUN8_INCLUDED or not os.path.exists(RUN8_SV) else "synthetic (run8 excluded)"
            synth_stream(stream, n=20000)
        level = sys.argv[sys.argv.index("--level") + 1] if "--level" in sys.argv else "diag"
        p = subprocess.run(["lua5.1", "tests/bg_replay.lua", stream, "--duration", "1800", "--assert", "--level", level], cwd=ROOT,
                           capture_output=True, text=True)
        out = p.stdout.strip().splitlines()
        for line in out:
            if line.startswith("bg_replay "):
                print(line.replace(stream, "<" + src + ">"))
            elif line.startswith("  FAIL") or line.startswith("  info") or "PERF" in line:
                print(line)
        if p.returncode:
            sys.stderr.write(p.stderr[-2000:])
        return p.returncode
    finally:
        os.remove(stream)


if __name__ == "__main__":
    sys.exit(main())
