-- [Forever] K.T.H. Forever port - ForeverSafe.lua (new file, port helper; not part of the original K.T.H.)
-- Secret-value helpers. A raw value is only passed to type()/canaccessvalue() before it is proven clear;
-- nothing is truth-tested, compared, concatenated, keyed or measured until then.
-- K.T.H. is (c) John Wellesz (H.H.T.D.) and Scone (K.T.H.), All Rights Reserved; private port, no redistribution.
local ADDON_NAME, T = ...;

local FS = {};
T.FS = FS;

local type, pcall = type, pcall;
local canaccessvalue = _G.canaccessvalue;
local issecretvalue  = _G.issecretvalue;

-- WoW Forever 1.60.1 (measured in the baseline diag: WOW_PROJECT_ID 18, toc 16001, canaccessvalue present)
local tocversion = select(4, GetBuildInfo());
FS.IS_FOREVER = (_G.WOW_PROJECT_ID == 18) or (type(canaccessvalue) == "function" and tocversion < 120000);

function FS.clear(v)
    if type(v) == "nil" then return nil; end
    if issecretvalue then
        local ok, s = pcall(issecretvalue, v);
        if not ok or s then return nil; end
    end
    if canaccessvalue then
        local ok, a = pcall(canaccessvalue, v);
        if not ok or not a then return nil; end
    end
    return v;
end
local clear = FS.clear;

function FS.str(v)  v = clear(v); if type(v) == "string"  then return v; end end
function FS.num(v)  v = clear(v); if type(v) == "number"  then return v; end end
function FS.bool(v) v = clear(v); if type(v) == "boolean" then return v; end end

-- "Aerie Dunleary" (scoreboard) / "Aerie-Realm" / "Aerie" (plate) -> "Aerie"
function FS.firstWord(s)
    s = FS.str(s);
    if not s then return nil; end
    return s:match("^([^%s%-]+)");
end
