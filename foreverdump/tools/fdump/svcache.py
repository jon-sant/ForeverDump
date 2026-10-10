"""v2.2.11 on-disk cache for expensive per-file results (parsed SavedVariables, constant counts).

Key = sha1 of the file bytes + sha1 of the code that produced the result (the listed module sources) + a kind tag, so
an edited file OR edited parser/counter code always recomputes; identical inputs reuse the pickled result instead of
re-parsing a 36-75 MB SV for ~18 s per test. Lives in <repo>/.cache/svcache (never packaged: tools/package.py skips
.cache; user captures contain names, so the cache stays on the box like real/). FD_SVCACHE=0 disables it."""
import hashlib
import os
import pickle
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DIR = os.path.join(ROOT, ".cache", "svcache")
HERE = os.path.dirname(os.path.abspath(__file__))
_file_hash = {}


def file_sha1(path):
    st = os.stat(path)
    k = (os.path.realpath(path), st.st_size, st.st_mtime_ns)
    h = _file_hash.get(k)
    if h is None:
        d = hashlib.sha1()
        with open(path, "rb") as f:
            for b in iter(lambda: f.read(1 << 22), b""):
                d.update(b)
        h = _file_hash[k] = d.hexdigest()
    return h


def code_sha1(modules):
    d = hashlib.sha1()
    for m in modules:
        with open(os.path.join(HERE, m), "rb") as f:
            d.update(f.read())
    return d.hexdigest()[:16]


def cached(kind, path, modules, compute):
    """compute(path) -> result, memoized on disk by (kind, file sha1, code sha1)."""
    if os.environ.get("FD_SVCACHE", "1") == "0":
        return compute(path)
    key = "%s-%s-%s.pickle" % (kind, file_sha1(path), code_sha1(modules))
    fn = os.path.join(DIR, key)
    if os.path.exists(fn):
        try:
            with open(fn, "rb") as f:
                return pickle.load(f)
        except Exception:  # noqa: BLE001 - a broken cache entry is recomputed
            pass
    res = compute(path)
    os.makedirs(DIR, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=DIR)
    with os.fdopen(fd, "wb") as f:
        pickle.dump(res, f, protocol=pickle.HIGHEST_PROTOCOL)
    os.replace(tmp, fn)
    return res


PARSER = ("luasv.py", "svpack.py")


def parse_file(path, unpack=True):
    """parse_savedvariables(open(path).read()) with the disk cache."""
    from .luasv import parse_savedvariables
    from . import svpack

    def compute(p):
        with open(p, encoding="utf-8", errors="surrogateescape") as f:
            res = parse_savedvariables(f.read(), unpack=unpack)
        return res, dict(svpack.LAST)
    res, last = cached("sv2-unpack" if unpack else "sv2-raw", path, PARSER, compute)
    # svpack.LAST (per-variable decode info) is part of the result: restored on a cache hit too
    svpack.LAST.clear()
    svpack.LAST.update(last)
    return res
