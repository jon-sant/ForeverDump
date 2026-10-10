-- ForeverDump v2.2.11 - SVPack: SavedVariables that always load, whatever the capture size.
--
-- Why: WoW loads ForeverDump.lua (all five SavedVariables) as ONE Lua 5.1 chunk, and every distinct string/number
-- literal in it lands in that chunk's single constant table, capped at 262,143 entries (MAXARG_Bx). Run 9 (30 min BG,
-- diag, uncapped rings) wrote 321,235 distinct constants -> "constant table overflow", the whole file failed to load.
-- Fix (lossless, no caps): at PLAYER_LOGOUT, after every other logout handler, each large SavedVariable is serialized
-- into Lua-source CHUNK STRINGS (each <= CHUNK_LITERALS literals, so each loads as its own function with its own
-- constant table) plus a tiny graft plan. The file then holds a few hundred long strings instead of ~10^5-10^6
-- literals. At ADDON_LOADED the chunks are rebuilt (loadstring + empty environment: data only, C-speed parse) before any
-- module touches the tables, so the rest of the addon never sees the packed form. If rebuilding ever fails, the
-- packed blob is kept inside the fresh table (.packedRescue) and saved again - data is never thrown away.
-- Packed form (format 1):
--   { __fdpack = 1, chunks = { "return{list},{hash},listCount", ... }, nodes = N,
--     cn = { node per chunk }, cb = { list base per chunk }, gp = { parent node }, gk = { key }, gc = { child node },
--     literals = L, bytes = B }
--   node 1 is the root; chunk i merges list items into node cn[i] at cb[i]+1.. and hash pairs as-is; graft j sets
--   node gp[j][gk[j]] = node gc[j]. Offline: tools/fdump/svpack.py (luasv.parse_savedvariables decodes transparently).
-- Safety: runs only plain table walking/string formatting (no API calls, nothing protected, fine in combat); secret
-- scalars/tables (never expected in our tables) are dropped and counted instead of formatted.
local _, ns = ...

local type, pairs, next, tostring, tonumber, rawget, pcall = type, pairs, next, tostring, tonumber, rawget, pcall
local format, concat, floor, huge = string.format, table.concat, math.floor, math.huge

local P = {}
ns.SVPack = P
P.FORMAT = 1
P.LUA51_MAXK = 262143
P.CHUNK_LITERALS = 50000      -- per chunk (one function each): far under 262,143 even if every literal were unique
P.CHUNK_BYTES = 1048576       -- soft byte cap per chunk string
P.PLAIN_MAX = 4000            -- a SavedVariable with at most this many literals stays plain (readable)
P.WARN_AT = 200000            -- in-game guard: warn at FD_Logs OFF when the plain part would exceed this (limit 262,143)

local function names()
    return { "ForeverDumpDB", "ForeverDumpStaticDB", "ForeverDumpRecordDB", "ForeverDumpLogDB", "ForeverDumpCombatLogDB" }
end
P.Names = names

local issv = rawget(_G, "issecretvalue")
local isst = rawget(_G, "issecrettable")
local function secretScalar(v)
    if type(issv) ~= "function" then return false end
    local ok, r = pcall(issv, v)
    if not ok then return true end
    return r == true
end
local function secretTable(v)
    if type(isst) ~= "function" then return false end
    local ok, r = pcall(isst, v)
    if not ok then return true end
    return r == true
end

local function isPacked(v) return type(v) == "table" and rawget(v, "__fdpack") ~= nil end
P.IsPacked = isPacked

------------------------------------------------------------------------ counting
-- literals a table contributes when written plainly (keys outside the 1..n list part + scalar values), recursive;
-- also a byte estimate. Memoized per pack run; cycles raise.
local function listLen(t)
    local n = 0
    while rawget(t, n + 1) ~= nil do n = n + 1 end
    return n
end

local function newCounter(stopAt)
    local memoL, memoB, active = {}, {}, {}
    local function count(t)
        local m = memoL[t]
        if m then return m, memoB[t] end
        if active[t] then error("svpack: cycle") end
        active[t] = true
        local lits, bytes = 0, 2
        local n = listLen(t)
        for k, v in next, t do
            local tk = type(k)
            if not (tk == "number" and k >= 1 and k <= n and k == floor(k)) then
                lits = lits + 1
                bytes = bytes + (tk == "string" and #k + 4 or 12)
            end
            local tv = type(v)
            if tv == "table" then
                local l, b = count(v)
                lits, bytes = lits + l, bytes + b
            elseif tv == "string" then lits, bytes = lits + 1, bytes + #v + 3
            elseif tv == "number" then lits, bytes = lits + 1, bytes + 12
            else bytes = bytes + 6 end
            if stopAt and lits > stopAt then break end
        end
        active[t] = nil
        if not stopAt then memoL[t], memoB[t] = lits, bytes end
        return lits, bytes
    end
    return count
end

------------------------------------------------------------------------ serializing
local IDENT_KW = { ["and"] = 1, ["break"] = 1, ["do"] = 1, ["else"] = 1, ["elseif"] = 1, ["end"] = 1, ["false"] = 1,
    ["for"] = 1, ["function"] = 1, ["if"] = 1, ["in"] = 1, ["local"] = 1, ["nil"] = 1, ["not"] = 1, ["or"] = 1,
    ["repeat"] = 1, ["return"] = 1, ["then"] = 1, ["true"] = 1, ["until"] = 1, ["while"] = 1 }

local function num(v)
    if v ~= v then return "0/0" end
    if v == huge then return "1e999" end
    if v == -huge then return "-1e999" end
    -- %d only inside 32 bits: the Windows client's Lua formats %d through a 32-bit long
    if v == floor(v) and v > -2147483648 and v < 2147483648 then
        if v == 0 and 1 / v < 0 then return "-0" end
        return format("%d", v)
    end
    local s = format("%.14g", v)
    if tonumber(s) == v then return s end
    s = format("%.15g", v)
    if tonumber(s) == v then return s end
    s = format("%.16g", v)
    if tonumber(s) == v then return s end
    return format("%.17g", v)
end
P.Num = num

-- returns nil when the value cannot be written (function/userdata/secret): the entry is skipped (like WoW's writer)
local function new_ser(stats)
    local ser
    local function key(k)
        local tk = type(k)
        if tk == "string" then
            if secretScalar(k) then return nil end
            if not IDENT_KW[k] and k:find("^[%a_][%w_]*$") then return k end
            return "[" .. format("%q", k) .. "]"
        elseif tk == "number" then
            if secretScalar(k) then return nil end
            if k ~= k then return nil end
            return "[" .. num(k) .. "]"
        elseif tk == "boolean" then
            return k and "[true]" or "[false]"
        end
        return nil
    end
    ser = function(v, out, n)
        local tv = type(v)
        if tv == "string" then
            if secretScalar(v) then stats.secrets = stats.secrets + 1 return n, false end
            n = n + 1 out[n] = format("%q", v)
        elseif tv == "number" then
            if secretScalar(v) then stats.secrets = stats.secrets + 1 return n, false end
            n = n + 1 out[n] = num(v)
        elseif tv == "boolean" then
            n = n + 1 out[n] = v and "true" or "false"
        elseif tv == "table" then
            if secretTable(v) then stats.secrets = stats.secrets + 1 return n, false end
            n = n + 1 out[n] = "{"
            local ln = listLen(v)
            for i = 1, ln do
                local ok
                n, ok = ser(v[i], out, n)
                if not ok then n = n + 1 out[n] = "nil" end   -- keep list positions
                n = n + 1 out[n] = ","
            end
            for k, x in next, v do
                local tk = type(k)
                if not (tk == "number" and k >= 1 and k <= ln and k == floor(k)) then
                    local ks = key(k)
                    if ks then
                        local m = n
                        n = n + 1 out[n] = ks
                        n = n + 1 out[n] = "="
                        local ok
                        n, ok = ser(x, out, n)
                        if ok then n = n + 1 out[n] = "," else n = m end
                    else stats.skippedKeys = stats.skippedKeys + 1 end
                end
            end
            n = n + 1 out[n] = "}"
        else
            stats.skipped = stats.skipped + 1
            return n, false
        end
        return n, true
    end
    return ser, key
end

------------------------------------------------------------------------ pack one value
function P.PackValue(root)
    local stats = { secrets = 0, skipped = 0, skippedKeys = 0 }
    local count = newCounter()
    local totalLits, totalBytes = count(root)
    local ser, key = new_ser(stats)
    local LIM, BYT = P.CHUNK_LITERALS, P.CHUNK_BYTES
    local chunks, cn, cb, gp, gk, gc = {}, {}, {}, {}, {}, {}
    local nodes = 1

    local function packNode(t, id)
        local ln = listLen(t)
        -- current slice
        local lout, lnn, hout, hnn, base, lits, bytes, any = {}, 0, {}, 0, 0, 0, 0, false
        local lcount = 0      -- list items in the current slice (positions base+1 .. base+lcount)
        local function flush()
            if any then
                chunks[#chunks + 1] = "return{" .. concat(lout, "", 1, lnn) .. "},{" .. concat(hout, "", 1, hnn) .. "},"
                    .. lcount
                cn[#cn + 1], cb[#cb + 1] = id, base
            end
            lout, lnn, hout, hnn, lits, bytes, any, lcount = {}, 0, {}, 0, 0, 0, false, 0
        end
        local function big(v)
            if type(v) ~= "table" then return false end
            local l, b = count(v)
            return l > LIM or b > BYT
        end
        local function graft(k, v)
            nodes = nodes + 1
            local child = nodes
            gp[#gp + 1], gk[#gk + 1], gc[#gc + 1] = id, k, child
            packNode(v, child)
        end
        for i = 1, ln do
            local v = t[i]
            if big(v) and not secretTable(v) then
                flush()
                graft(i, v)
            else
                local l, b = 1, 12
                if type(v) == "table" then l, b = count(v) end
                if any and (lits + l > LIM or bytes + b > BYT or (lcount > 0 and i ~= base + lcount + 1)) then flush() end
                if lcount == 0 then
                    if any then flush() end   -- a slice's list part must start at its base
                    base = i - 1
                end
                local ok
                lnn, ok = ser(v, lout, lnn)
                if not ok then lnn = lnn + 1 lout[lnn] = "nil" end
                lnn = lnn + 1 lout[lnn] = ","
                lits, bytes, any, lcount = lits + l, bytes + b, true, lcount + 1
            end
        end
        for k, v in next, t do
            local tk = type(k)
            if not (tk == "number" and k >= 1 and k <= ln and k == floor(k)) then
                local ks = key(k)
                if not ks then
                    stats.skippedKeys = stats.skippedKeys + 1
                elseif big(v) and not secretTable(v) then
                    graft(k, v)
                else
                    local l, b = 1, 12
                    if type(v) == "table" then l, b = count(v) end
                    l, b = l + 1, b + #ks
                    if any and (lits + l > LIM or bytes + b > BYT) then flush() end
                    local m = hnn
                    hnn = hnn + 1 hout[hnn] = ks
                    hnn = hnn + 1 hout[hnn] = "="
                    local ok
                    hnn, ok = ser(v, hout, hnn)
                    if ok then
                        hnn = hnn + 1 hout[hnn] = ","
                        lits, bytes, any = lits + l, bytes + b, true
                    else hnn = m end
                end
            end
        end
        flush()
    end
    packNode(root, 1)
    return { __fdpack = P.FORMAT, chunks = chunks, nodes = nodes, cn = cn, cb = cb, gp = gp, gk = gk, gc = gc,
        literals = totalLits, bytes = totalBytes, secretsDropped = stats.secrets, skipped = stats.skipped + stats.skippedKeys }
end

------------------------------------------------------------------------ unpack one value
local function loadChunk(src)
    local ls = rawget(_G, "loadstring")
    if type(ls) ~= "function" then return nil, "loadstring unavailable" end
    if type(src) ~= "string" or src:sub(1, 7) ~= "return{" then return nil, "bad chunk" end
    local fn, err = ls(src, "=FDPack")
    if not fn then return nil, err end
    local sfe = rawget(_G, "setfenv")
    if type(sfe) == "function" then sfe(fn, {}) end   -- data only: no globals reachable
    local ok, a, h, n = pcall(fn)
    if not ok then return nil, a end
    if type(a) ~= "table" or type(h) ~= "table" or type(n) ~= "number" then return nil, "chunk shape" end
    return a, h, n
end

function P.UnpackValue(p)
    if not isPacked(p) then return p end
    if p.__fdpack ~= P.FORMAT then return nil, "unknown pack format " .. tostring(p.__fdpack) end
    local nodes = {}
    local nn = tonumber(p.nodes) or 1
    for i = 1, nn do nodes[i] = {} end
    local chunks, cn, cb = p.chunks or {}, p.cn or {}, p.cb or {}
    for i = 1, #chunks do
        local a, h, n = loadChunk(chunks[i])
        if not a then return nil, "chunk " .. i .. ": " .. tostring(h) end
        local node = nodes[cn[i]]
        if not node then return nil, "chunk " .. i .. ": bad node" end
        local base = cb[i] or 0
        for j = 1, n do node[base + j] = a[j] end
        for k, v in pairs(h) do node[k] = v end
    end
    local gp, gk, gc = p.gp or {}, p.gk or {}, p.gc or {}
    for j = 1, #gp do
        local parent, child = nodes[gp[j]], nodes[gc[j]]
        if not parent or not child then return nil, "graft " .. j .. ": bad node" end
        parent[gk[j]] = child
    end
    return nodes[1]
end

------------------------------------------------------------------------ whole SavedVariables
local function now()
    local dps = rawget(_G, "debugprofilestop")
    if type(dps) == "function" then return dps() end
    return 0
end

-- ADDON_LOADED (before InitDB): rebuild every packed SavedVariable in place; keep a failing blob as .packedRescue
function P.UnpackAll()
    local res = { at = rawget(_G, "time") and time() or nil, vars = {} }
    for _, name in ipairs(names()) do
        local v = rawget(_G, name)
        if isPacked(v) then
            local t0 = now()
            local ok, t, err = pcall(P.UnpackValue, v)
            if ok and type(t) == "table" then
                _G[name] = t
                res.vars[name] = { ms = now() - t0, chunks = #(v.chunks or {}), literals = v.literals }
            else
                _G[name] = { packedRescue = v }
                res.vars[name] = { failed = tostring(ok and err or t) }
                res.failed = (res.failed or 0) + 1
            end
        end
    end
    P.lastUnpack = res
    return res
end

-- PLAYER_LOGOUT (last): pack every SavedVariable above PLAIN_MAX literals. ForeverDumpDB goes last so the pack
-- report (ForeverDumpDB.svpack) is saved too.
function P.PackAll()
    local report = { v = P.FORMAT, vars = {} }
    local order = names()
    table.sort(order, function(a, b)
        if a == "ForeverDumpDB" then return false elseif b == "ForeverDumpDB" then return true end
        return a < b
    end)
    local function one(name)
        local v = rawget(_G, name)
        if type(v) ~= "table" or isPacked(v) then return end
        local t0 = now()
        local okC, lits = pcall(newCounter(P.PLAIN_MAX), v)
        if okC and lits <= P.PLAIN_MAX then report.vars[name] = { plain = true, literals = lits } return end
        local ok, p = pcall(P.PackValue, v)
        -- ForeverDumpDB carries the report and is packed last: its own row stays in memory only (P.lastPack.self)
        local into = name == "ForeverDumpDB" and {} or report.vars
        if ok then
            _G[name] = p
            into[name] = { chunks = #p.chunks, nodes = p.nodes, literals = p.literals, bytes = p.bytes,
                secretsDropped = p.secretsDropped, skipped = p.skipped, ms = now() - t0 }
        else
            into[name] = { failed = tostring(p) }
            report.failed = (report.failed or 0) + 1
        end
        if into ~= report.vars then P.lastPackSelf = into[name] end
    end
    for _, name in ipairs(order) do
        if name == "ForeverDumpDB" then
            local db = rawget(_G, name)
            if type(db) == "table" then db.svpack = report end
        end
        one(name)
    end
    P.lastPack = report
    return report
end

-- constants the client will see in the saved file (upper bound: literals, not deduplicated) given packing as it would
-- run now. Cheap when everything packs: plain vars are counted with an early stop.
function P.Estimate()
    local total, detail = 0, {}
    local canPack = type(rawget(_G, "loadstring")) == "function" and not (ns.config and ns.config.svpack == false)
    for _, name in ipairs(names()) do
        local v = rawget(_G, name)
        if type(v) == "table" then
            local ok, lits = pcall(newCounter(canPack and P.PLAIN_MAX or nil), v)
            if not ok then
                detail[name] = "uncountable: " .. tostring(lits)
                total = total + P.LUA51_MAXK
            elseif canPack and lits > P.PLAIN_MAX then
                local okF, l = pcall(newCounter(), v)
                local n = okF and math.ceil(l / P.CHUNK_LITERALS) * 4 + 16 or P.LUA51_MAXK
                detail[name] = n
                total = total + n
            else
                detail[name] = lits
                total = total + lits
            end
        end
    end
    return total, detail, canPack
end

-- FD_Logs OFF guard: warn once (per session) if the saved file could still exceed the client's constant limit
function P.GuardAtOff()
    if P.warned then return end
    local ok, total, detail, canPack = pcall(P.Estimate)
    if not ok then return end
    P.lastEstimate = { total = total, canPack = canPack }
    if total > P.WARN_AT then
        P.warned = true
        local parts = {}
        for k, v in pairs(detail) do parts[#parts + 1] = k .. "=" .. tostring(v) end
        table.sort(parts)
        if ns.Print then
            ns.Print(format("|cffff5555SavedVariables may not load: ~%d Lua constants (client limit 262143; packing %s). "
                .. "Copy WTF\\...\\SavedVariables\\ForeverDump.lua before logging in again.|r %s",
                total, canPack and "on" or "OFF", concat(parts, ", ")))
        end
    end
end
