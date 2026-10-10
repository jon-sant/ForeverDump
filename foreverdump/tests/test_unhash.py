"""v2.2.21 unhash: hash32 parity with Lua + salt recovery on a synthetic session."""
import math
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from fdump import unhash as U  # noqa: E402

H32 = os.path.join(ROOT, "tools", "fdump", "h32")


class Hash32Parity(unittest.TestCase):
    def test_python_matches_lua(self):
        cases = [
            (0, "Player-4618-00EB40D8"),
            (1216956013, "Player-4618-00EB40D8"),
            (1216956013, "Uglaz"),
            (42, "Xoxo Il"),
            (2147483647 + 47 * 9973, "a" * 40),
        ]
        lua = os.path.join(tempfile.gettempdir(), "uh_hash32_test.lua")
        with open(lua, "w") as f:
            f.write("""
local function hash32(str)
    str = tostring(str or "")
    local h = 2166136261
    for i = 1, #str do
        h = h + string.byte(str, i)
        h = (h * 16777619 + (h % 65521) * 31) % 4294967296
    end
    return h
end
for line in io.lines() do
    local s, id = line:match("^(.-)\\t(.*)$")
    io.write(string.format("%08x\\n", hash32(tostring(tonumber(s)) .. "|" .. tostring(id))))
end
""")
        inp = "\n".join("%d\t%s" % c for c in cases) + "\n"
        lu = subprocess.check_output(["lua5.1", lua], input=inp, text=True).split()
        for i, (salt, raw) in enumerate(cases):
            self.assertEqual(lu[i], U.idkey_hex(salt, raw), (salt, raw))
            if os.path.exists(H32):
                open("/tmp/uh_id.txt", "w").write(raw + "\n")
                hx = subprocess.check_output([H32, "map", str(salt), "/tmp/uh_id.txt"], text=True).split()[0]
                self.assertEqual(hx, lu[i])

    def test_run15_known_salt(self):
        # empirical: run15 salt + own GUID
        self.assertEqual(U.idkey_hex(1216956013, "Player-4618-00EB40D8"), "70392278")

    def test_recover_synthetic(self):
        salt = 1_126_603_776 + 9 * 9973
        raws = ["Player-4618-00EB40D8", "Player-4619-00AABBCC", "Uglaz", "Otherdude"]
        hashed = __import__("collections").Counter()
        for r in raws:
            hashed[("player", U.idkey_hex(salt, r))] += 1
            hashed[("name", U.idkey_hex(salt, r.split("-")[0] if r.startswith("Player") else r))] += 1
        ids = {k: set() for k in U.KINDS}
        for r in raws:
            if r.startswith("Player-"):
                ids["player"].add(r); ids["guid"].add(r)
            else:
                ids["name"].add(r)
        ids["name"].add("Uglaz")
        t0 = 1126603.776
        rec = U.recover_salt(t0, hashed, ids, [9, 10, 11])
        self.assertIsNotNone(rec)
        self.assertEqual(rec["salt"], salt)
        self.assertGreaterEqual(rec["matches"], 3)


if __name__ == "__main__":
    unittest.main(verbosity=1)
