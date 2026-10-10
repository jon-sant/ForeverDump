import os as _wos  # portable root (handoff): WOWDEV_ROOT or the nearest parent dir holding foreverdump/
def _wowdev_root():
    r = _wos.environ.get("WOWDEV_ROOT")
    if r:
        return r
    d = _wos.path.dirname(_wos.path.abspath(__file__))
    while d != _wos.path.dirname(d) and not _wos.path.isdir(_wos.path.join(d, "foreverdump")):
        d = _wos.path.dirname(d)
    return d
_WROOT = _wowdev_root()
"""Time audit 2026-10-10: run a scorer with the PRE-audit time conversion (box zone) patched back in, to measure what the
bug did. usage: oldemu.py fd <module> args... | oldemu.py kth <script.py> args..."""
import datetime, re, runpy, sys

mode, target, args = sys.argv[1], sys.argv[2], sys.argv[3:]
if mode == "fd":
    sys.path.insert(0, _WROOT + "/foreverdump")
    from tools.fdump import refdata
    refdata.log_utc_offset = lambda path, probe=50: None     # pre-audit: epoch -> log time via time.localtime (box zone)
    sys.argv = [target] + args
    runpy.run_module(target, run_name="__main__")
else:
    sys.path.insert(0, _WROOT + "/kth/tools")
    import logtruth

    def old_parse_ts(s):   # pre-audit logtruth.parse_ts: naive datetime().timestamp() (box zone), suffix ignored
        m = re.match(r'(\d+)/(\d+)/(\d+) (\d+):(\d+):(\d+)\.(\d+)', s)
        mo, d, y, H, M, S, ms = map(int, m.groups())
        return datetime.datetime(y, mo, d, H, M, S).timestamp() + ms / 10.0 ** len(m.group(7))
    logtruth.parse_ts = old_parse_ts
    sys.argv = [target] + args
    runpy.run_path(target, run_name="__main__")
