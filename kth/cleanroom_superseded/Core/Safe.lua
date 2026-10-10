-- K.T.H. Forever - Core/Safe.lua
-- Minimal standalone secret-value helpers (clean-room, no ForeverDump dependency).
-- Rule: a value is only ever compared, concatenated, used as a key or measured AFTER it passed clear().
-- type() is the only operation applied to a raw value; it is allowed on secrets.
local _, ns = ...
local S = {}
ns.S = S

local issecretvalue, canaccessvalue = issecretvalue, canaccessvalue
local issecrettable, canaccesstable = issecrettable, canaccesstable
local pcall, type, select = pcall, type, select

-- clear(v): v when it is safe to read, nil when it is nil or secret / inaccessible.
function S.clear(v)
    if type(v) == "nil" then return nil end
    if issecretvalue then
        local ok, sec = pcall(issecretvalue, v)
        if not ok or sec then return nil end
    end
    if canaccessvalue then
        local ok, acc = pcall(canaccessvalue, v)
        if not ok or not acc then return nil end
    end
    return v
end
local clear = S.clear

function S.str(v)  v = clear(v); if type(v) == "string" then return v end end
function S.num(v)  v = clear(v); if type(v) == "number" then return v end end
function S.bool(v) v = clear(v); if type(v) == "boolean" then return v end end

-- isSecret(v): true only when v is a real secret (nil is not secret)
function S.isSecret(v)
    if type(v) == "nil" then return false end
    return clear(v) == nil
end

-- tbl(t): t when it is a plain readable table
function S.tbl(t)
    if type(t) ~= "table" then return nil end
    if issecrettable then
        local ok, sec = pcall(issecrettable, t)
        if not ok or sec then return nil end
    end
    if canaccesstable then
        local ok, acc = pcall(canaccesstable, t)
        if not ok or not acc then return nil end
    end
    if clear(t) == nil then return nil end
    return t
end

-- call(f, ...): pcall wrapper; returns nothing on error or when f is missing
local function pack(ok, ...)
    if not ok then return 0 end
    return select("#", ...), ...
end
function S.call(f, ...)
    if type(f) ~= "function" then return end
    local n, a, b, c, d, e, g, h, i, j, k, l, m = pack(pcall(f, ...))
    if n == 0 then return end
    return a, b, c, d, e, g, h, i, j, k, l, m
end

-- callAll(f, ...): like call but returns every value (scoreboard rows)
function S.callAll(f, ...)
    if type(f) ~= "function" then return 0 end
    return pack(pcall(f, ...))
end

-- firstWord("Uglaz Doomaxe") -> "Uglaz"; "Name-Realm" -> "Name". Clear strings only.
function S.firstWord(s)
    s = S.str(s)
    if not s then return nil end
    local w = s:match("^([^%s%-]+)")
    return w
end
