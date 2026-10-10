"""Safe parser for WoW SavedVariables files (a data-only subset of Lua).

Nothing is executed: the file is tokenized and parsed as
`Name = <value>` statements, where values are nil/booleans/numbers/strings/
tables. Anything else (function calls, operators, expressions) is rejected.
"""
import math
import re

__all__ = ["parse_savedvariables", "LuaParseError", "as_list"]


class LuaParseError(ValueError):
    pass


_NUM = re.compile(r"-?(?:0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)")
_NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
_WS = re.compile(r"(?:\s+|--\[(=*)\[.*?\]\1\]|--[^\n]*)+", re.S)
_ESC = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v",
        "\\": "\\", '"': '"', "'": "'", "\n": "\n"}


class _Parser:
    def __init__(self, text):
        self.s = text
        self.i = 0
        self.n = len(text)

    def err(self, msg):
        line = self.s.count("\n", 0, self.i) + 1
        raise LuaParseError("%s at line %d" % (msg, line))

    def ws(self):
        m = _WS.match(self.s, self.i)
        if m:
            self.i = m.end()

    def peek(self):
        self.ws()
        return self.s[self.i] if self.i < self.n else ""

    def expect(self, ch):
        if self.peek() != ch:
            self.err("expected %r, got %r" % (ch, self.s[self.i:self.i + 20]))
        self.i += 1

    def string(self):
        q = self.s[self.i]
        self.i += 1
        out = []
        s = self.s
        while True:
            j = self.i
            while j < self.n and s[j] != q and s[j] != "\\" and s[j] != "\n":
                j += 1
            out.append(s[self.i:j])
            if j >= self.n or s[j] == "\n":
                self.i = j
                self.err("unterminated string")
            if s[j] == q:
                self.i = j + 1
                return "".join(out)
            # escape
            c = s[j + 1] if j + 1 < self.n else ""
            if c.isdigit():
                k = j + 1
                while k < self.n and k < j + 4 and s[k].isdigit():
                    k += 1
                code = int(s[j + 1:k])
                if code > 255:
                    self.i = j
                    self.err("bad escape")
                out.append(chr(code))
                self.i = k
            elif c in _ESC:
                out.append(_ESC[c])
                self.i = j + 2
            else:
                out.append(c)
                self.i = j + 2

    def long_string(self):
        m = re.compile(r"\[(=*)\[").match(self.s, self.i)
        if not m:
            self.err("bad long string")
        close = "]" + m.group(1) + "]"
        end = self.s.find(close, m.end())
        if end < 0:
            self.err("unterminated long string")
        body = self.s[m.end():end]
        if body.startswith("\r\n"):
            body = body[2:]
        elif body.startswith("\n"):
            body = body[1:]
        self.i = end + len(close)
        return body

    def value(self, depth=0):
        if depth > 200:
            self.err("nesting too deep")
        c = self.peek()
        if c == "{":
            return self.table(depth + 1)
        if c in "\"'":
            return self.string()
        if c == "[" and self.s.startswith(("[[", "[="), self.i):
            return self.long_string()
        if c == "(" and self.s.startswith("(1e999-1e999)", self.i):   # v2.2.13 SVPack NaN (no division in the client)
            self.i += 13
            return math.nan
        m = _NUM.match(self.s, self.i)
        if m and (c.isdigit() or c in "-."):
            self.i = m.end()
            t = m.group(0)
            if self.s.startswith("/0", self.i) and t in ("0", "-0"):
                self.i += 2
                return math.nan
            if "x" in t.lower():
                return int(t, 16)
            if re.fullmatch(r"-?\d+", t):
                return int(t)
            return float(t)
        m = _NAME.match(self.s, self.i)
        if m:
            word = m.group(0)
            self.i = m.end()
            if word == "nil":
                return None
            if word == "true":
                return True
            if word == "false":
                return False
            if word in ("inf", "nan"):
                return math.inf if word == "inf" else math.nan
            self.err("unexpected identifier %r (expressions are not allowed)" % word)
        if c == "-" and self.s.startswith(("-inf", "-nan"), self.i):
            self.i += 4
            return -math.inf
        self.err("unexpected %r" % self.s[self.i:self.i + 20])

    def table(self, depth):
        self.expect("{")
        arr = []
        h = {}
        nxt = 1
        while True:
            c = self.peek()
            if c == "}":
                self.i += 1
                break
            if c == "[" and not self.s.startswith(("[[", "[="), self.i):
                self.i += 1
                k = self.value(depth)
                self.expect("]")
                self.expect("=")
                v = self.value(depth)
                if isinstance(k, float) and k.is_integer():
                    k = int(k)
                if v is not None:
                    h[k] = v
            else:
                m = _NAME.match(self.s, self.i)
                save = self.i
                if m:
                    self.i = m.end()
                    if self.peek() == "=" and not self.s.startswith("==", self.i):
                        self.i += 1
                        v = self.value(depth)
                        if v is not None:
                            h[m.group(0)] = v
                        m = "done"
                    else:
                        self.i = save
                        m = None
                if m is None:
                    v = self.value(depth)
                    if v is not None:
                        h[nxt] = v
                    nxt += 1
            c = self.peek()
            if c in ",;":
                self.i += 1
            elif c != "}":
                self.err("expected ',' or '}'")
        # list if keys are exactly 1..n
        if h and all(isinstance(k, int) for k in h):
            keys = sorted(h)
            if keys == list(range(1, len(keys) + 1)):
                return [h[k] for k in keys]
        return h

    def chunk(self):
        out = {}
        while True:
            self.ws()
            if self.i >= self.n:
                return out
            m = _NAME.match(self.s, self.i)
            if not m:
                self.err("expected variable name")
            self.i = m.end()
            self.expect("=")
            out[m.group(0)] = self.value()
            if self.peek() == ";":
                self.i += 1


def parse_savedvariables(text, unpack=True):
    """Return {global_name: value}. Tables become dict or list (1..n). v2.2.11: SavedVariables packed by SVPack.lua
    (constant-limit-safe chunk strings) are decoded transparently (unpack=False returns the packed form)."""
    if text.startswith("\ufeff"):
        text = text[1:]
    raw = _Parser(text).chunk()
    if unpack:
        from .svpack import unpack_all
        unpack_all(raw)
    return raw


def as_list(x):
    """Lua arrays parse as lists; empty tables parse as {}. Normalize."""
    if x is None:
        return []
    if isinstance(x, list):
        return x
    if isinstance(x, dict):
        if not x:
            return []
        if all(isinstance(k, int) for k in x):
            return [x[k] for k in sorted(x)]
    return [x]
