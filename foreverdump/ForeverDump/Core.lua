-- ForeverDump v2 - Core: namespace, safe value handling, scheduler, saved variables.
-- Lua 5.1 only. Never yield inside pcall (Lua 5.1 cannot yield across a C boundary).
local ADDON_NAME, ns = ...

-- cut a string to at most n bytes without splitting a UTF-8 sequence (keeps SavedVariables valid UTF-8)
function ns.Utf8Cut(str, n)
    if #str <= n then return str end
    local cut = n
    while cut > 0 do -- step back while the next byte is a continuation byte (10xxxxxx)
        local b = string.byte(str, cut + 1)
        if not b or b < 0x80 or b >= 0xC0 then break end
        cut = cut - 1
    end
    return string.sub(str, 1, cut)
end

ns.ADDON = ADDON_NAME or "ForeverDump"
ns.VERSION = "2.2.29"
ns.SCHEMA = 3
ns.SECRET = "<secret>"
ns.SECRET_TABLE = "<secrettable>"

local type, pairs, next, tostring, rawget, pcall, select =
      type, pairs, next, tostring, rawget, pcall, select
local sort, concat, format = table.sort, table.concat, string.format

----------------------------------------------------------------------------
-- Output
----------------------------------------------------------------------------
-- v2.2.14: every line carries the running version (run 11 was a stale v2.2.11 install nobody noticed)
local PREFIX = "|cff33ff99ForeverDump " .. ns.VERSION .. "|r "
-- v2.2.14 (run 11 BG, re-verified against the real 1.60.1.70245 source + the 10/8 taint log): NO line ever goes into
-- a Blizzard chat frame, anywhere. ScrollingMessageFrameMixin:AddMessage -> historyBuffer:PushFront ->
-- headIndex:Increment() = SetValue(GetValue() + 1) writes the SecureNumber field `value` in the CALLER's context
-- (SecureTypes.lua: only GetValue goes through securecallfunction). One addon AddMessage on ChatFrame1 leaves that
-- field written by ForeverDump (taint log 10/8: 4x "Execution tainted by ForeverDump while reading field value -
-- SecureTypes.lua:279 ... CircularBuffer.lua:49 PushFront"); every later secure AddMessage reads it, is tainted and
-- writes it back tainted, so the taint never fades for the rest of the session. BattlegroundChatFilters' OnUpdate calls
-- DEFAULT_CHAT_FRAME:AddMessage between its two loops over ADDED_PLAYERS (secret names -> restricted table), so the
-- second loop errors on every frame. v2.2.12/13 only deferred lines to the open world, which still tainted the session
-- (any open-world /fdump or FD_Logs line). Now all output goes to our own message frame + an in-memory history
-- (/fdump msgs replays it). tests/bg_chat_taint.lua models the real PushFront/SecureNumber path and fails on any
-- AddMessage/print into Blizzard chat.
local HISTORY_MAX = 300
ns.chatQueue = ns.chatQueue or { lines = {}, dropped = 0, held = 0 }   -- message history (name kept for tests/tools)
local function chatSafe()
    local ii = rawget(_G, "IsInInstance")
    if type(ii) == "function" then
        local ok, inInst = pcall(ii)
        if not ok then return false end
        -- unknown / secret -> treat as unsafe (never test a secret: ns.IsTrue classifies first)
        if inInst == nil then return false end
        if ns.IsTrue then
            if ns.IsTrue(inInst) then return false end
            if ns.ClearOf and ns.ClearOf(inInst) == nil then return false end
        elseif inInst then return false end
    end
    local icl = rawget(_G, "InCombatLockdown")
    if type(icl) == "function" then
        local ok, c = pcall(icl)
        if not ok or (ns.IsTrue and ns.IsTrue(c)) or (not ns.IsTrue and c) then return false end
    end
    return true
end
ns.ChatSafe = chatSafe

local ownFrame
local function ownMessageFrame()
    if ownFrame ~= nil then return ownFrame or nil end
    local cf, parent = rawget(_G, "CreateFrame"), rawget(_G, "UIParent")
    ownFrame = false
    if type(cf) ~= "function" then return nil end
    local ok, f = pcall(cf, "ScrollingMessageFrame", "ForeverDumpMessageFrame", parent)
    if not ok or not f then return nil end
    pcall(f.SetSize, f, 760, 400)
    pcall(f.SetPoint, f, "TOP", parent, "TOP", 0, -120)
    pcall(f.SetFontObject, f, rawget(_G, "GameFontNormal"))
    pcall(f.SetJustifyH, f, "LEFT")
    pcall(f.SetMaxLines, f, 200)
    pcall(f.SetFading, f, true)
    pcall(f.SetTimeVisible, f, 20)
    pcall(f.SetFrameStrata, f, "HIGH")
    pcall(f.EnableMouse, f, false)
    ownFrame = f
    return f
end
ns.MessageFrame = ownMessageFrame

-- v2.2.14: one line per version change (the SavedVariables were last written by another version)
function ns.VersionNotice()
    local vc = ns.versionChange
    if not vc or vc.shown then return nil end
    vc.shown = true
    if vc.from == "none" then return "|cffffff00first run of ForeverDump " .. vc.to .. "|r" end
    return string.format("|cffffff00version changed: SavedVariables were last written by %s, now running %s|r", vc.from, vc.to)
end

-- v2.2.15: lab-only work (shadow candidate rules, lab probes) runs at the "lab" capture level unless the runaway
-- backstop tripped (Perf.lua)
function ns.LabActive()
    local R = ns.ReplayLog
    return R and R.IsLab and R.IsLab() or false   -- v2.2.15: the backstop only reports (user decision 2026-10-09)
end

-- compat no-op (v2.2.12/13 flushed held lines into chat; that flush was itself a taint source)
function ns.FlushChatQueue() return 0 end

function ns.Print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    local msg = PREFIX .. concat(parts, " ")
    local q = ns.chatQueue
    q.held = q.held + 1
    q.lines[#q.lines + 1] = msg
    if #q.lines > HISTORY_MAX then table.remove(q.lines, 1) q.dropped = q.dropped + 1 end
    local f = ownMessageFrame()
    if f then pcall(f.AddMessage, f, msg) end
end

-- /fdump msgs [n]: show the last n lines again (our frame fades after 20 s)
function ns.ReplayMessages(n)
    local q, f = ns.chatQueue, ownMessageFrame()
    n = math.max(0, math.min(tonumber(n) or 14, #q.lines))
    if not f then return 0 end
    for i = #q.lines - n + 1, #q.lines do pcall(f.AddMessage, f, q.lines[i]) end
    return n
end

----------------------------------------------------------------------------
-- Secret values. Only issecretvalue/issecrettable/canaccessvalue ever see a
-- value before we know it is safe; nothing else touches a secret.
----------------------------------------------------------------------------
local issecretvalue = _G.issecretvalue
local issecrettable = _G.issecrettable
local canaccessvalue = _G.canaccessvalue

local function probeSecret(v)
    if issecretvalue and issecretvalue(v) then return true end
    if canaccessvalue and not canaccessvalue(v) then return true end
    if issecrettable and type(v) == "table" and issecrettable(v) then return true end
    return false
end

function ns.IsSecret(v)
    if type(v) == "nil" then return false end -- v2.2.7: type() first; never compare a possibly-secret value
    local ok, res = pcall(probeSecret, v)
    if not ok then return true end -- if we cannot even ask, treat as secret
    return res
end
local IsSecret = ns.IsSecret
-- v2.2.22 (audit): a VALUE-level secret (issecretvalue / canaccessvalue only). Unlike IsSecret it does not fold
-- issecrettable(t) == true into "secret": such a table is a "T" container whose clear fields are still readable
-- field by field (pcall(index) + classify each). Use this before deciding to discard a whole table.
local function probeSecretValue(v)
    if issecretvalue and issecretvalue(v) then return true end
    if canaccessvalue and not canaccessvalue(v) then return true end
    return false
end
function ns.IsSecretValue(v)
    if type(v) == "nil" then return false end
    local ok, res = pcall(probeSecretValue, v)
    if not ok then return true end
    return res
end

-- v2.2 five-state value classifier (never stores the value):
--   "N" nil (slot present, value nil; "absent" = slot beyond select('#') is decided by the caller)
--   "S" secret (issecretvalue, or canaccessvalue == false)
--   "T" container with secret contents: duration/curve objects via obj:HasSecretValues(), tables via issecrettable or
--       a one-level scan with issecretvalue (hasanysecretvalues takes values, not a table)
--   "K" container, all clear     "C" clear scalar
-- issecretvalue(durationObject) is always false (Forever 70245: UnitCastingDuration), hence the container branch.
local function containerSecret(v)
    local okM, m = pcall(function() return v.HasSecretValues end)
    if okM and type(m) == "function" then
        local ok, r = pcall(m, v)
        if ok and not (issecretvalue and issecretvalue(r)) then return r == true end
    end
    if type(v) ~= "table" then return false end
    if issecrettable then
        local ok, r = pcall(issecrettable, v)
        if ok and r == true then return true end
    end
    local okScan, found = pcall(function()
        local n = 0
        for k, x in next, v do
            n = n + 1
            if n > 200 then break end
            if (issecretvalue and (issecretvalue(x) or issecretvalue(k))) then return true end
        end
        return false
    end)
    if not okScan then return true end -- forbidden table: cannot even iterate
    return found
end
function ns.ClassifyValue(v)
    if type(v) == "nil" then return "N" end
    if issecretvalue then
        local ok, r = pcall(issecretvalue, v)
        if not ok then return "S" end
        if r then return "S" end
    end
    local t = type(v)
    if t == "table" or t == "userdata" then
        return containerSecret(v) and "T" or "K"
    end
    if canaccessvalue then
        local ok, r = pcall(canaccessvalue, v)
        if ok and r == false then return "S" end
    end
    return "C"
end
-- v2.2.7 (run 6b DamageMeter.lua:51): the ONLY ways ForeverDump code may consume a value returned by a game API.
-- Classify first, then hand out a clear copy; never truth-test, compare, index or concat the raw value.
function ns.ClearOf(v, want)
    if ns.ClassifyValue(v) ~= "C" then return nil end
    if want ~= nil and type(v) ~= want then return nil end
    return v
end
function ns.ClearNum(v) return ns.ClearOf(v, "number") end
-- hot paths that already hold v's ClassifyValue code c (no second classification)
function ns.ClearWithCode(v, c, want)
    if c ~= "C" then return nil end
    if want ~= nil and type(v) ~= want then return nil end
    return v
end
function ns.ClearStr(v) return ns.ClearOf(v, "string") end
function ns.ClearBool(v) return ns.ClearOf(v, "boolean") end
-- true only for a clear `true` (secret/nil/false/non-boolean -> false)
function ns.IsTrue(v)
    if type(v) ~= "boolean" then return false end
    if ns.ClassifyValue(v) ~= "C" then return false end
    return rawequal(v, true)
end
-- an indexable, non-secret table/struct (fields may still be secret: classify each before use), else nil
function ns.ClearTable(v)
    if type(v) ~= "table" then return nil end
    if ns.ClassifyValue(v) == "S" then return nil end
    return v
end
-- presence without a comparison: secret values are present (not nil) but never compared
function ns.IsNil(v) return type(v) == "nil" end
-- one level into a struct: { field = code }
function ns.ClassifyFields(v)
    if type(v) ~= "table" or (issecretvalue and issecretvalue(v)) then return nil end
    local out, n = {}, 0
    local ok = pcall(function()
        for k, x in next, v do
            if type(k) == "string" and not (issecretvalue and issecretvalue(k)) then
                n = n + 1
                if n > 64 then break end
                out[k] = ns.ClassifyValue(x)
            end
        end
    end)
    if not ok then return nil end
    return out
end

----------------------------------------------------------------------------
-- SavedVariables-safe copies (no functions/userdata/secrets/NaN/inf/cycles)
----------------------------------------------------------------------------
local HUGE = math.huge
local function cleanNumber(v)
    if v ~= v then return "<nan>" end
    if v == HUGE then return "<inf>" end
    if v == -HUGE then return "<-inf>" end
    return v
end
ns.CleanNumber = cleanNumber

function ns.IsFrame(v)
    return type(v) == "table" and type(rawget(v, 0)) == "userdata"
end
local IsFrame = ns.IsFrame

local function frameLabel(v)
    local ok, name = pcall(v.GetName, v)
    if ok and type(name) == "string" and not IsSecret(name) then return "<frame:" .. name .. ">" end
    return "<frame>"
end

-- opts: maxDepth (default 4), maxKeys (default 200), maxString (default 4000)
function ns.Clean(v, opts, depth, path)
    if v == nil then return nil end
    -- v2.2.22 (audit): a table is discarded only when the table VALUE is secret; a "T" container (issecrettable or
    -- some secret fields) is walked per field below (secret fields -> ns.SECRET, clear fields kept)
    if type(v) == "table" then
        if ns.IsSecretValue(v) then return ns.SECRET_TABLE end
    elseif IsSecret(v) then
        return ns.SECRET
    end
    local t = type(v)
    if t == "number" then return cleanNumber(v) end
    if t == "boolean" then return v end
    if t == "string" then
        local maxString = opts and opts.maxString or 4000
        if #v > maxString then return ns.Utf8Cut(v, maxString) .. "<...truncated " .. #v .. ">" end
        return v
    end
    if t == "table" then
        if IsFrame(v) then return frameLabel(v) end
        depth = depth or 0
        local maxDepth = opts and opts.maxDepth or 4
        if depth >= maxDepth then return "<table>" end
        path = path or {}
        if path[v] then return "<cycle>" end
        path[v] = true
        local out, n = {}, 0
        local maxKeys = opts and opts.maxKeys or 200
        local okIter = pcall(function()
        for k, val in next, v do
            n = n + 1
            if n > maxKeys then out["<truncated>"] = true break end
            local kt = type(k)
            local key
            if IsSecret(k) then
                key = nil
            elseif kt == "string" then
                key = k
            elseif kt == "number" then
                key = (k ~= k or k == HUGE or k == -HUGE) and tostring(k) or k
            elseif kt == "boolean" then
                key = "<bool:" .. tostring(k) .. ">"
            else
                key = "<" .. kt .. ">"
            end
            if key ~= nil then
                local cv = ns.Clean(val, opts, depth + 1, path)
                if cv ~= nil then out[key] = cv end
            end
        end
        end)
        path[v] = nil
        if not okIter then
            if next(out) == nil then return ns.SECRET_TABLE end
            out["<iter-error>"] = true
        end
        return out
    end
    return "<" .. t .. ">"
end

function ns.Pack(...) return { n = select("#", ...), ... } end

-- v2.2.10 lossless run-length compaction of DAMAGE_METER_* rows (combat ring, event recorder, replay tape).
-- One ring row per run of identical rows (same event + flags + every argument): rc = occurrences, q = sequence number of
-- the first one, dt[k] = ms since the previous occurrence, dq[k] = sequence numbers since the previous occurrence. The
-- converter (tools/fdump/dmrle.py) expands every occurrence back with its exact ms time, payload and stream position.
-- Only scalar arguments fold (a table argument never folds), so a reused table address can never merge two payloads.
local RLE = {}
ns.RLE = RLE
local function rleMs(t) return math.floor(t * 1000 + 0.5) end
RLE.Ms = rleMs
function RLE.New() return { open = {}, folded = 0, runs = 0 } end
-- key of a packed row; nil when any argument is a table (never folds)
function RLE.Key(e, flags, a, n)
    local parts = { e, flags or "", n or 0 }
    if a ~= nil then
        if type(a) ~= "table" then return nil end
        for i = 1, (n or #a) do
            local v = a[i]
            local tv = type(v)
            if tv == "table" or tv == "function" or tv == "userdata" then return nil end
            parts[#parts + 1] = tv == "string" and ("s" .. v) or tostring(v)
        end
    end
    return table.concat(parts, "\31")
end
-- fold one occurrence into the open run of key (if that run's row is still in ring[slot]); returns true when folded
function RLE.Fold(st, key, ms, seq, ring)
    local run = st and key and st.open[key]
    if not run or ring[run.slot] ~= run.row then return false end
    local row = run.row
    row.rc = row.rc + 1
    local dt, dq = row.dt, row.dq
    dt[#dt + 1] = ms - run.ms
    dq[#dq + 1] = seq - run.seq
    run.ms, run.seq = ms, seq
    st.folded = st.folded + 1
    return true
end
-- the row just stored at ring[slot] starts a new run of key
function RLE.Open(st, key, row, slot, ms, seq)
    if not (st and key) then return end
    row.rc, row.q, row.dt, row.dq = 1, seq, {}, {}
    st.open[key] = { row = row, slot = slot, ms = ms, seq = seq }
    st.runs = st.runs + 1
end
function RLE.Summary(st) return st and { v = 1, folded = st.folded, runs = st.runs } or nil end

-- Pack all returns of a pcall-ed function into a clean array plus count.
function ns.SafeCall(fn, ...)
    if type(fn) ~= "function" then return { ok = false, err = "missing" } end
    local res = ns.Pack(pcall(fn, ...))
    if not res[1] then
        return { ok = false, err = ns.Clean(res[2], { maxString = 300 }) }
    end
    local out = { ok = true, n = 0, values = {}, secret = {} }
    local count = res.n - 1
    out.n = count
    out.states = {}
    for i = 1, count do
        local v = res[i + 1]
        local st = ns.ClassifyValue(v)
        out.states[i] = st
        -- v2.2.22 (audit): only S is a secret return; T (container with some secret fields) is listed in out.partial
        -- and its per-field codes go to out.fstates
        if st == "S" then out.secret[#out.secret + 1] = i
        elseif st == "T" then out.partial = out.partial or {} out.partial[#out.partial + 1] = i end
        if st == "T" or st == "K" then
            local f = ns.ClassifyFields(v)
            if f and next(f) then out.fstates = out.fstates or {} out.fstates[i] = f end
        end
        local cv = ns.Clean(v, { maxDepth = 5, maxKeys = 300 })
        if cv == nil then cv = "<nil>" end
        out.values[i] = cv
    end
    if #out.secret == 0 then out.secret = nil end
    return out
end

function ns.SortedKeys(t)
    local keys = {}
    for k in next, t do keys[#keys + 1] = k end
    sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

function ns.SortedList(set)
    local list = {}
    for k in next, set do list[#list + 1] = k end
    sort(list, function(a, b) return tostring(a) < tostring(b) end)
    return list
end

-- Resolve "C_Item.GetItemInfo" or "GetTime" to a value without metamethods.
function ns.Resolve(path)
    local cur = _G
    for part in string.gmatch(path, "[^%.]+") do
        if type(cur) ~= "table" then return nil end
        cur = rawget(cur, part)
    end
    return cur
end

function ns.Call(path, ...)
    local fn = ns.Resolve(path)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h, i, j, k, l, m, n2, o, p, q, r, s =
        pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d, e, f, g, h, i, j, k, l, m, n2, o, p, q, r, s
end

----------------------------------------------------------------------------
-- Build / meta
----------------------------------------------------------------------------
-- Flavor info. Do NOT assume Mainline: newer Forever builds report WOW_PROJECT_ID == WOW_PROJECT_CAMELOT,
-- older ones (e.g. 70009) reported WOW_PROJECT_MAINLINE. Record every WOW_PROJECT_* constant verbatim.
-- v2.2.3 (run 4 perf root cause): this walks all of _G (52,517 globals on Forever 70245 with a normal addon set,
-- ~17 ms per call in Lua 5.1 on the test box) and used to run on EVERY ns.Meta() call, which hot paths reached through
-- Knowledge.DB() (HSM window, 5x per second per spell line), Containers db() (every UNIT_AURA) and ns.PathBlocked()
-- (every combat-probe read in combat). The project constants cannot change during a session, so the result is cached;
-- hot paths use ns.Build() (GetBuildInfo, cached) and never ns.Meta().
local projectCache
function ns.ProjectInfo(refresh)
    if projectCache and not refresh then return projectCache[1], projectCache[2], projectCache[3] end
    local id, consts, names = ns.ScanProjectInfo()
    projectCache = { id, consts, names }
    return id, consts, names
end
local buildCache
function ns.Build()
    if not buildCache then
        local _, build = ns.Call("GetBuildInfo")
        if build == nil then return "?" end
        buildCache = tostring(build)
    end
    return buildCache
end
function ns.ScanProjectInfo()
    local id = rawget(_G, "WOW_PROJECT_ID")
    local consts, names = {}, {}
    -- perf-ok: the only _G walk outside dump jobs; ns.ProjectInfo caches it once per session (run 4 root cause)
    for k, v in pairs(_G) do
        if type(k) == "string" and string.find(k, "^WOW_PROJECT_") and type(v) ~= "table" and type(v) ~= "function" then
            consts[k] = v
            if v == id and k ~= "WOW_PROJECT_ID" then names[#names + 1] = k end
        end
    end
    table.sort(names)
    return id, consts, (#names > 0) and table.concat(names, ",") or nil
end

-- Returns true/false, or nil if the API is missing / errored (scripts disallowed => /run, /dump, /tinspect are inert).
function ns.ScriptsDisallowed()
    local A = rawget(_G, "C_AddOns")
    local f = type(A) == "table" and A.GetScriptsDisallowedForBeta
    if type(f) ~= "function" then return nil end
    local ok, v = pcall(f)
    if ok and not ns.IsSecret(v) then return v end
    return nil
end

function ns.Meta()
    local version, build, buildDate, toc = ns.Call("GetBuildInfo")
    local projectID, consts, projectName = ns.ProjectInfo()
    local projectConstants = {}
    for k, v in pairs(consts or {}) do projectConstants[k] = v end
    return {
        addonVersion = ns.VERSION,
        schemaVersion = ns.SCHEMA,
        version = version,
        build = build,
        buildDate = buildDate,
        toc = toc,
        locale = ns.Call("GetLocale"),
        projectID = projectID,
        projectName = projectName,
        projectConstants = projectConstants,
        scriptsDisallowedForBeta = ns.ScriptsDisallowed(),
        time = time and time() or nil,
        date = date and date("%Y-%m-%d %H:%M:%S") or nil,
        inCombat = ns.InCombat(),
    }
end

-- v2.2.1 player identity, written to the SV meta on every capture so the converter can pick the combat log owner
-- (by GUID, else name). Every value is classified first (also an
-- empirical test of whether identity is secret for the player); only clear strings/numbers are stored, a secret
-- one is recorded as code "S" plus secret[field] = true and anySecret = true.
local IDENTITY = {
    { "UnitName", { "player" }, { "name", "nameRealm" } },
    { "UnitFullName", { "player" }, { "fullName", "fullNameRealm" } },
    { "GetUnitName", { "player", true }, { "unitNameWithRealm" } },
    { "GetRealmName", {}, { "realm" } },
    { "GetNormalizedRealmName", {}, { "normalizedRealm" } },
    { "UnitGUID", { "player" }, { "guid" } },
    { "UnitClass", { "player" }, { "className", "classFile", "classID" } },
    { "UnitLevel", { "player" }, { "level" } },
    { "UnitRace", { "player" }, { "raceName", "raceFile" } },
}
function ns.PlayerIdentity(reason)
    local id = { v = 1, reason = reason, time = time and time() or nil, codes = {}, secret = {}, anySecret = false,
        inCombat = ns.InCombat and ns.InCombat() or nil }
    for _, spec in ipairs(IDENTITY) do
        local f = rawget(_G, spec[1])
        if type(f) ~= "function" then
            for _, k in ipairs(spec[3]) do id.codes[k] = "absent" end
        else
            local r = { pcall(f, unpack(spec[2])) }
            if not r[1] then
                for _, k in ipairs(spec[3]) do id.codes[k] = "E" end
            else
                for i, k in ipairs(spec[3]) do
                    local v = r[i + 1]
                    local c = ns.ClassifyValue(v)
                    id.codes[k] = c
                    if c == "S" or c == "T" then
                        id.secret[k], id.anySecret = true, true
                    elseif c == "C" and (type(v) == "string" or type(v) == "number") then
                        id[k] = v
                    end
                end
            end
        end
    end
    -- Forever (run 3, live): UnitName/UnitFullName("player") return ("Uglaz", "Doomaxe"): the second return is the LAST
    -- NAME, not the realm; GetUnitName("player", true) = "Uglaz Doomaxe"; the combat log writes "Uglaz-<realm>-".
    if type(id.name) == "string" then
        id.firstName = id.name:match("^(%S+)")
        id.lastName = id.name:match("^%S+%s+(.+)$")
        local second = id.nameRealm or id.fullNameRealm
        if not id.lastName and type(second) == "string" and second ~= "" and second ~= id.realm and second ~= id.normalizedRealm then
            id.lastName = second
        end
        if not id.lastName and type(id.unitNameWithRealm) == "string" then
            id.lastName = id.unitNameWithRealm:match("^" .. id.firstName .. "%s+(.+)$")
        end
        id.displayName = id.lastName and (id.firstName .. " " .. id.lastName) or id.name
    end
    return id
end

-- v2.2.2 probe attribution: every probing module marks the API path it is about to call. ADDON_ACTION_BLOCKED only
-- says "UNKNOWN()" on Forever (run 3: 36x), so Errors.lua attaches the current/last mark and the path is learned as
-- combat-blocked (ForeverDumpDB.blockedPaths[build]) and skipped by the probes in combat from then on.
function ns.ProbeMark(module, path, unit)
    local m = ns.probeMark or {}
    m.module, m.path, m.unit, m.t = module, path, unit, GetTime and GetTime() or nil
    ns.probeMark, ns.probeActive = m, true
end
function ns.ProbeDone() ns.probeActive = false end
function ns.ProbeAttribution()
    local m = ns.probeMark
    if not m then return nil end
    local now = GetTime and GetTime() or nil
    if ns.probeActive or (now and m.t and now - m.t < 0.05) then
        return { module = m.module, path = m.path, unit = m.unit, active = ns.probeActive or nil }
    end
end
function ns.LearnBlocked(attr, inCombat)
    if not (ns.db and attr and attr.path) then return end
    local build = ns.Build()
    ns.db.blockedPaths = type(ns.db.blockedPaths) == "table" and ns.db.blockedPaths or {}
    local b = ns.db.blockedPaths[build] or {}
    ns.db.blockedPaths[build] = b
    local k = attr.path
    local r = b[k] or { n = 0, units = {} }
    r.n, r.module, r.inCombat, r.last = r.n + 1, attr.module, inCombat and true or r.inCombat, time and time() or nil
    if attr.unit then r.units[attr.unit] = (r.units[attr.unit] or 0) + 1 end
    b[k] = r
end
function ns.PathBlocked(path)
    local b = ns.db and ns.db.blockedPaths and ns.db.blockedPaths[ns.Build()]
    return b and b[path] ~= nil or false
end

-- v2.2.7: combat guard for capture/hot paths. Run 6 (build 70291): 47 ADDON_ACTION_BLOCKED "UNKNOWN()" = CheckInteractDistance
-- from the v2.2.6 token scanner (range28 field) and WorldCapture (range10/28), which bypassed CombatProbe's v2.2.2 skip.
-- Every module that may call one of these APIs asks ns.CombatGuard first (tests/test_v227_lint.py enforces it).
ns.COMBAT_PROTECTED = { CheckInteractDistance = true, IsItemInRange = true, ["C_Item.IsItemInRange"] = true }
local function uacPlayer()
    local f = rawget(_G, "UnitAffectingCombat")
    if type(f) ~= "function" then return false end
    local ok, v = pcall(function() return f("player") == true end)   -- comparison inside pcall: never a bare secret test
    return ok and v == true
end
-- true while any combat signal is up (lockdown, player affecting combat, combat restriction state)
function ns.CombatLocked()
    if ns.InCombat() or uacPlayer() then return true end
    local R = rawget(_G, "C_RestrictedActions")
    local f = type(R) == "table" and R.GetAddOnRestrictionState
    if type(f) == "function" then
        local ok, v = pcall(function() return f(0) == 1 end)
        if ok and v == true then return true end
    end
    return false
end
-- nil = safe to call; else the skip reason. locked: precomputed ns.CombatLocked() (one check per slice in hot paths)
function ns.CombatGuard(path, locked)
    local prot = ns.COMBAT_PROTECTED[path]
    if not prot and not ns.PathBlocked(path) then return nil end
    if locked == nil then locked = ns.CombatLocked() end
    if not locked then return nil end
    return prot and "combat-protected" or "learned-blocked"
end

function ns.RecordIdentity(reason)
    if not ns.db then return end
    local ok, id = pcall(ns.PlayerIdentity, reason)
    if not ok or type(id) ~= "table" then return end
    if type(ns.db.meta) ~= "table" then ns.db.meta = ns.Meta() end
    ns.db.meta.identity = id
    if type(ForeverDumpLogDB) == "table" then ForeverDumpLogDB.identity = id end
    local key = id.guid or id.name
    if key then
        ns.db.identities = type(ns.db.identities) == "table" and ns.db.identities or {}
        ns.db.identities[key] = id
    end
    return id
end

-- Events that must never be registered by an addon on Forever/Midnight-era clients: registering them fires
-- ADDON_ACTION_FORBIDDEN and the "blocked from an action only available to the Blizzard UI" popup.
ns.EVENT_DENYLIST = {
    COMBAT_LOG_EVENT = "restricted since 12.0.0 (ADDON_ACTION_FORBIDDEN on register)",
    COMBAT_LOG_EVENT_UNFILTERED = "restricted since 12.0.0 (ADDON_ACTION_FORBIDDEN on register)",
    COMBAT_LOG_EVENT_INTERNAL_UNFILTERED = "internal combat log event",
}

-- Documented events that are safe to register individually. Returns list, skipped{event = reason} or nil, err.
-- Skips: denylist, events with HasRestrictions, events of systems whose Environment is not "All"
-- (e.g. SecureOnly), and events C_EventUtils.IsEventValid rejects.
function ns.SafeEventList()
    local docs, err = ns.Legacy.LoadDocs()
    if not docs then return nil, nil, "Blizzard_APIDocumentation unavailable: " .. tostring(err) end
    local isValid = C_EventUtils and C_EventUtils.IsEventValid
    local list, skipped, seen = {}, {}, {}
    for i = 1, #docs.systems do
        local sys = docs.systems[i]
        local env = type(sys) == "table" and rawget(sys, "Environment")
        local events = type(sys) == "table" and rawget(sys, "Events")
        if type(events) == "table" then
            for j = 1, #events do
                local ev = events[j]
                local name = type(ev) == "table" and (rawget(ev, "LiteralName") or rawget(ev, "Name"))
                if type(name) == "string" and not seen[name] then
                    seen[name] = true
                    if ns.EVENT_DENYLIST[name] then
                        skipped[name] = "denylist: " .. ns.EVENT_DENYLIST[name]
                    elseif rawget(ev, "HasRestrictions") then
                        skipped[name] = "docs: HasRestrictions"
                    elseif env and env ~= "All" then
                        skipped[name] = "docs: system Environment=" .. tostring(env)
                    elseif isValid then
                        local ok, valid = pcall(isValid, name)
                        if ok and valid == false then skipped[name] = "C_EventUtils.IsEventValid=false"
                        else list[#list + 1] = name end
                    else
                        list[#list + 1] = name
                    end
                end
            end
        end
    end
    for name, reason in pairs(ns.EVENT_DENYLIST) do
        if not skipped[name] then skipped[name] = "denylist: " .. reason end
    end
    table.sort(list)
    return list, skipped
end

----------------------------------------------------------------------------
-- Common timebase. Every capture session gets a session ID and an anchor:
--   { gameTime = GetTime(), epoch = time(), server = GetServerTime(), utcOffset = seconds, date = "..." }
-- refined to sub-frame precision: an OnUpdate watches time() tick over and stores epochTick/gameTimeTick, so
--   epoch(t) = epochTick + (t - gameTimeTick)   (local machine clock, the same clock WoWCombatLog.txt uses)
-- Records keep GetTime() as `t` (+ sid); standalone records (errors, probes, contradictions) also keep epoch/server.
----------------------------------------------------------------------------
-- v2.2.11 (run 9 taint.log "Execution tainted by ForeverDump while reading field isdst"): the offset used to be
-- time(l) - time(u) after writing l.isdst = false into the table date() returned, so the client's time() read a field
-- we had written. Now plain arithmetic on the two date tables: nothing written, no time(table) call. Same result
-- (local wall clock minus UTC wall clock, DST included), day/month/year wrap handled via the day-of-year difference.
local function utcOffset()
    if not date then return nil end
    local okL, l = pcall(date, "*t")
    local okU, u = pcall(date, "!*t")
    if not okL or not okU or type(l) ~= "table" or type(u) ~= "table" then return nil end
    local ly, lyd, lh, lm, ls = tonumber(l.year), tonumber(l.yday), tonumber(l.hour), tonumber(l.min), tonumber(l.sec)
    local uy, uyd, uh, um, us = tonumber(u.year), tonumber(u.yday), tonumber(u.hour), tonumber(u.min), tonumber(u.sec)
    if not (ly and lyd and lh and lm and ls and uy and uyd and uh and um and us) then return nil end
    local dd = lyd - uyd
    if ly > uy then dd = 1 elseif ly < uy then dd = -1 end   -- New Year wrap: the two clocks differ by < 1 day
    local off = dd * 86400 + (lh - uh) * 3600 + (lm - um) * 60 + (ls - us)
    return math.floor(off / 60 + 0.5) * 60   -- the two date() calls may straddle a second
end

local refineFrame, pending = nil, {}
local function refine(anchor)
    if not CreateFrame or not time then return end
    pending[#pending + 1] = { anchor = anchor, start = time(), t0 = GetTime() }
    if not refineFrame then
        refineFrame = CreateFrame("Frame")
        refineFrame:SetScript("OnUpdate", function(self)
            local now = time()
            for i = #pending, 1, -1 do
                local p = pending[i]
                if now ~= p.start then
                    p.anchor.epochTick, p.anchor.gameTimeTick, p.anchor.precise = now, GetTime(), true
                    table.remove(pending, i)
                elseif GetTime() - p.t0 > 2.5 then
                    table.remove(pending, i)
                end
            end
            if #pending == 0 then self:Hide() end
        end)
    end
    refineFrame:Show()
end

function ns.TimeAnchor(noRefine)
    local a = { gameTime = GetTime and GetTime() or 0, epoch = time and time() or nil,
        server = rawget(_G, "GetServerTime") and rawget(_G, "GetServerTime")() or nil, utcOffset = utcOffset(),
        date = date and date("%Y-%m-%d %H:%M:%S") or nil }
    if not noRefine then refine(a) end
    return a
end

function ns.NewSessionId(kind)
    local db = ns.db or {}
    db.sessionCounter = (db.sessionCounter or 0) + 1
    return string.format("%s-%s-%d", kind or "s", date and date("%Y%m%d%H%M%S") or "0", db.sessionCounter)
end

-- current capture session (FD_Logs) id, else a per-login id
local loginSid
function ns.SessionId()
    local s = ns.db and ns.db.logs and ns.db.logs.session
    if s and s.sid then return s.sid end
    loginSid = loginSid or ns.NewSessionId("login")
    return loginSid
end

-- stamp for standalone records
function ns.Stamp(rec)
    rec.sid = ns.SessionId()
    rec.t = GetTime and GetTime() or nil
    rec.epoch = rec.epoch or (time and time() or nil)
    rec.server = rawget(_G, "GetServerTime") and rawget(_G, "GetServerTime")() or nil
    return rec
end

function ns.InCombat()
    local f = rawget(_G, "InCombatLockdown")
    if type(f) ~= "function" then return false end
    local ok, v = pcall(f)
    return ok and v == true
end

-- v2.2.25 (user directive: BG, arena, open world solo/party, dungeons, raids): environment of every read / rule.
--   env    world-solo | party (open-world group) | dungeon (party/scenario instance) | raid | arena | bg
--   combat ooc | combat
--   phase  BG / arena: prep | gates | combat | post (ns.EnvPhase, set by Derive.ScorePhase); elsewhere enc | -
-- Memoised per GetTime() frame; every value read through pcall + clear checks (a secret is never tested).
local envT, envV
local function clearString(v) return ns.ClearOf and ns.ClearOf(v, "string") or (type(v) == "string" and v or nil) end
function ns.EnvNow()
    local env = "world-solo"
    local ii = rawget(_G, "IsInInstance")
    local it
    if type(ii) == "function" then
        local ok, _, kind = pcall(ii)
        it = ok and clearString(kind) or nil
    end
    if it == "pvp" then env = "bg"
    elseif it == "arena" then env = "arena"
    elseif it == "party" or it == "scenario" then env = "dungeon"
    elseif it == "raid" then env = "raid"
    else
        local ig = rawget(_G, "IsInGroup")
        if type(ig) == "function" then
            local ok, v = pcall(ig)
            if ok and ns.IsTrue and ns.IsTrue(v) then env = "party" end
        end
    end
    local combat = ns.InCombat() and "combat" or "ooc"
    local phase = "-"
    if env == "bg" or env == "arena" then
        local DV = ns.Derive
        if DV and DV.ScorePhase then
            local ok, p = pcall(DV.ScorePhase)
            if ok and type(p) == "string" then phase = p end
        end
    else
        local S = ns.Secrets
        if S and S.InEncounter then
            local ok, v = pcall(S.InEncounter)
            if ok and v == true then phase = "enc" end
        end
    end
    return { env = env, combat = combat, phase = phase, tag = env .. "/" .. combat .. "/" .. phase, instanceType = it }
end
function ns.Env()
    local gt = rawget(_G, "GetTime")
    local t = type(gt) == "function" and gt() or 0
    if envV and envT == t then return envV end
    envV, envT = ns.EnvNow(), t
    return envV
end
function ns.EnvTag() return ns.Env().tag end
-- v2.2.29: is this ADDON_RESTRICTION_STATE_CHANGED a combat transition? The Combat restriction (type 0) Activating /
-- Active fires at PLAYER_REGEN_DISABLED before InCombatLockdown() turns true (run 22: 24/24 stamped ooc)
ns.RESTRICTION_COMBAT = 0
function ns.CombatAtFlip(rtype, rstate)
    if ns.InCombat() then return true end
    local okT, t = pcall(function() return rtype == ns.RESTRICTION_COMBAT end)
    local okS, st = pcall(function() return rstate == 1 or rstate == 2 end)
    return okT and okS and t == true and st == true
end
function ns.InvalidateEnv() envT = nil end

-- v2.2.25: environment-aware aura circuit breaker (any environment, not BG-only). Aura ENUMERATION APIs raise
-- "Auras cannot be accessed when secret while tainted by '<addon>'" for every addon while auras are secret (run 17/18:
-- every BG call; outside BGs they work). Key = api | unit family | env tag: on that error the key is held for HOLD s,
-- then ONE sample call is let through (keeps measuring; detects the lift). Any other environment / combat state /
-- phase is a different key, so nothing that works elsewhere is switched off. Stats per env tag in
-- ForeverDumpLogDB.auraGate[tag][api|fam] = { calls, ok, err, held }.
ns.AuraGate = ns.AuraGate or {}
local AG = ns.AuraGate
AG.HOLD = 30
AG.PATTERN = "Auras cannot be accessed"
AG.held = AG.held or {}
local function agNow()
    local gt = rawget(_G, "GetTime")
    return type(gt) == "function" and gt() or 0
end
local function agStats(tag, key)
    local log = rawget(_G, "ForeverDumpLogDB")
    if type(log) ~= "table" then return nil end
    log.auraGate = log.auraGate or {}
    local t = log.auraGate[tag]
    if not t then t = {} log.auraGate[tag] = t end
    local s = t[key]
    if not s then s = { calls = 0, ok = 0, err = 0, held = 0 } t[key] = s end
    return s
end
-- true when the call may run now
function AG.Allow(api, fam)
    local tag = ns.EnvTag()
    local key = api .. "|" .. (fam or "-")
    local h = AG.held[tag .. "|" .. key]
    if h and agNow() < h then
        local s = agStats(tag, key)
        if s then s.held = s.held + 1 end
        return false
    end
    return true
end
-- record a call result; err = the pcall error (string) when ok is false
function AG.Note(api, fam, ok, err)
    local tag = ns.EnvTag()
    local key = api .. "|" .. (fam or "-")
    local s = agStats(tag, key)
    if s then
        s.calls = s.calls + 1
        if ok then s.ok = s.ok + 1 else s.err = s.err + 1 end
    end
    if not ok and type(err) == "string" and err:find(AG.PATTERN, 1, true) then
        AG.held[tag .. "|" .. key] = agNow() + AG.HOLD
    elseif ok then
        AG.held[tag .. "|" .. key] = nil
    end
end
-- pcall(fn, ...) through the gate. Returns gated(true when skipped), then pcall's results.
local function agFinish(api, fam, ...)
    AG.Note(api, fam, (...), (select(2, ...)))
    return false, ...
end
function AG.Call(api, fam, fn, ...)
    if not AG.Allow(api, fam) then return true end
    return agFinish(api, fam, pcall(fn, ...))
end
function AG.Reset() AG.held = {} end

----------------------------------------------------------------------------
-- Saved variables
----------------------------------------------------------------------------
ns.defaults = {
    static = {
        auto = false,        -- v2.2.11: unused - no automatic static dump any more (only /fdump static run)
        loginDelay = 15,     -- seconds after PLAYER_LOGIN before the signature check (then waits for idle)
    },
    dump = {
        full = false,        -- false = compact SavedVariables (v2.1 default, ~half the size); true = everything (v2.0 behaviour):
                             --   addon-created (insecure) global tables with fields, all named regions (textures/fontstrings),
                             --   every secure+present function row in 'protected', global string values (not just names)
    },
    frameBudgetMs = 12,      -- per-frame CPU budget for chunked jobs
    progressEverySec = 2,
    uiMaxChars = 120000,     -- copy UI text cap
    record = {
        maxEvents = 4000,    -- ring buffer size (~0.6 MB SV per session at most)
        perEventPerSec = 5,  -- throttle for spammy events (UNIT_*, CLEU, ...)
        maxSessions = 3,
        maxArgs = 20,
        maxString = 300,
        callbacks = false,   -- opt-in: subscribe to callbackEvents via EventRegistry:RegisterCallback (no hooks; v2.1's
                             --   hooksecurefunc(EventRegistry, "TriggerEvent") broke Blizzard UI on Forever, see Recorder.lua)
        callbackEvents = { "Tooltip.OnShown", "Tooltip.OnHidden", "ActionButton.OnActionChanged",
                           "UIParentPanelManager.ShowUIPanel", "UIParentPanelManager.HideUIPanel" },
        redactChat = false,  -- v2.2.21: raw (true: CHAT_MSG_*/BN_*/CLUB_* args replaced by "<redacted>")
    },
    cl = {
        maxEvents = 10000,    -- combat log ring buffer size (entries, incl. context events); ~1 MB SV at most
        maxSessions = 3,
        maxArgs = 40,         -- CLEU payload args kept per entry
        maxString = 200,
        redactPlayers = false, -- true: player names -> "<player>", Player GUIDs -> "Player-#n"
        advanced = true,      -- with "/fdump cl start file": also set advancedCombatLogging=1 (restored on stop)
        damageMeter = true,   -- C_DamageMeter snapshot after PLAYER_REGEN_ENABLED and on stop (secret in combat)
    },
    secrets = {               -- secrets map / verifier (Secrets.lua)
        observe = true,       -- tally issecretvalue per API/event/arg position (bounded counters, never raw values)
        sweep = true,         -- during FD_Logs: call documented conditionally-secret getters on a timer
        sweepInterval = 5,    -- seconds between sweep ticks
        sweepPerTick = 25,    -- getter calls per tick (round-robin over the candidate list)
        maxCtx = 16,          -- context buckets kept per API/event position
        maxKeys = 4000,       -- API/event/field keys kept
        maxLive = 200,        -- live contradictions kept
        controls = true,      -- FD_Logs ON/first combat/OFF: controls batch + "what can you do with a secret" matrix
        opsPrint = true,      -- the matrix tests a message sink with the secret once per context per capture: our own hidden
                              -- ScrollingMessageFrame (v2.2.2; "chat" = old print to ChatFrame1, which taints its fading)
        selfErrorLimit = 20,  -- own errors per session before probes/sweeps/controls pause
    },
    logs = {                  -- /fdump logs + FD_Logs macro
        chat = true,          -- include the chat log (/chatlog -> Logs/WoWChatLog.txt; contains other players' chat!)
        advanced = true,      -- advancedCombatLogging=1 while on
        scriptErrors = true,  -- scriptErrors=1 while on
        taintLog = 1,         -- taintLog level while on (1 blocked actions, 2 global reads/writes); 0 = leave alone
        callLogging = false,  -- true: addon calls LoggingCombat/LoggingChat itself (only if not protected on your build)
        recorder = true,      -- ON starts the event recorder (/fdump record)
        combat = true,        -- ON starts the combat recorder (/fdump cl)
        errors = true,        -- ON turns error capture on
        probe = true,         -- probe snapshot at ON and OFF
        combatProbe = true,   -- probe at the first PLAYER_REGEN_DISABLED of each recording session
        profile = true,       -- profiler snapshot at ON and OFF
        fullDump = true,      -- unused since 2.2.7; v2.2.11: the static dump runs only via /fdump static run (Static.lua)
        autoReload = true,    -- FD_Logs ends with /reload on the OFF click (saves SavedVariables)
        sweep = true,         -- ON starts the secrets getter sweep (secrets.sweep* settings)
        bgReminder = true,    -- v2.2.20: entering a BG/arena with capture OFF -> one line in ForeverDump's own frame
        autoBG = false,       -- v2.2.20 opt-in: entering a BG/arena with capture OFF starts the capture (3 s later)
    },
    lab = {                   -- v2.2 workarounds lab (Lab.lua): sanctioned secret-value paths, boundary diagnostics only
        auto = true,          -- FD_Logs: run once out of combat (ON) and once in the first combat
        poll = false,         -- opt-in: sample UnitHealth/UnitPower("player") secrecy every pollInterval s while capturing
        pollInterval = 0.5,
    },
    combatProbe = {           -- v2.2 combat probe set (CombatProbe.lua): codes only, bounded, part of every FD_Logs capture
        enabled = true,
        minInterval = 3,      -- s between runs (target/focus changes, flips, combat start)
        maxRunsPerCapture = 80,
        maxCells = 4000,
        nameplates = 3,       -- nameplate units probed per run
        -- v2.2.27: dispel spells come from the per-build spellbook cache (/fdump static run), no ID list; set
        -- dispelSpells = { ... } via config only to override
    },
    tokens = { enabled = true },  -- v2.2 unit token survey (Tokens.lua): once per context per capture
    knowledge = {             -- v2.2 spell knowledge collector (Knowledge.lua): per build, ForeverDumpDB.knowledge
        enabled = true, maxSpells = 150, spellsPerTick = 8,
        foreign = true, maxExtra = 60, -- v2.2.4: clear foreign spellIDs (enemies / other players) collected out of combat (LRU)
        cdLineProbe = true,   -- v2.2.4 known-answer probe of the tooltip-line cooldown hypothesis (line count/types only)
    },
    hsm = {                   -- v2.2 hybrid state machine (Lib/HybridState.lua + Inference.lua + HSMUI.lua)
        enabled = true,       -- run the live HSM + inference logging during FD_Logs
        autoShow = true,      -- FD_Logs ON opens the HSM window, OFF closes it
        updateInterval = 0.5,  -- v2.2.4 (was 0.25): max text refresh rate (s); text is rebuilt only when the HSM state changed (dirty)
                              --   or a shown countdown needs its 1 Hz tick; bars 10 Hz only while a predicted bar runs.
                              --   No OnUpdate at all while idle or hidden (PERFORMANCE.md)
        window = 0.6,         -- s: cast -> aura correlation window
        signals = true, maxSignals = 3000,
        keepSessions = 4,     -- v2.2.2: previous capture sessions kept in ForeverDumpLogDB.inference.history
        tooltipCooldownSignal = false, -- v2.2.4 HYPOTHESIS, disabled until proven (tooltip line count tracks cooldown)
        combatSignals = true, -- v2.2.4: UNIT_COMBAT (player/target) signals for the offline replay (bounded by maxSignals)
    },
    worldCapture = {          -- v2.2.6 capture-only broad world-state logger (WorldCapture.lua): casts/auras/hp/power/
        enabled = true,       --   threat/range/target-of across all tokens; five-state codes + IdKeys on tape (kind ws).
        interval = 0.2,       --   Release: module no-ops. Capture budget separate from tokenscan; both under <=10%.
        budgetMs = 0.10,      -- per-slice wall-ms cap (debugprofilestop)
        maxTokensPerSlice = 12,
        heartbeatSec = 5,     -- re-log unchanged tokens at least this often
    },
    damageMeter = {           -- v2.2.6 C_DamageMeter deep mine (DamageMeter.lua): capture-mode full post-combat read of
        enabled = true,       --   every Enum.DamageMeterType + all sources/spells/details (raw GUIDs + names);
        probe = true,         --   in combat: tape every DAMAGE_METER_* + throttled structure classification (~2/s/type).
        maxFights = 20,       -- Release: same as v2.2.4 (counts + one classify + me-totals). Capture uses deepRead.
        deepRead = true,      -- full sources when ReplayLog.IsTest(); release ignores and stays light
        classifyHz = 2,       -- capture: max classification passes per type per second while in combat
        maxSources = 200,     -- post-combat source cap (raids/BGs; no silent 40 cutoff)
        maxSpells = 80,       -- per-source spell rows kept
        maxDetails = 40,      -- per-spell combatSpellDetails rows
    },
    verify = {                -- v2.2.4 live verification loop (Verify.lua): ForeverDumpDB.verify[build] ring + unexpected LRU
        enabled = true, ringSize = 600, maxUnexpected = 200,
    },
    replay = {                -- v2.2.6 sealed replay tape + verbosity (ReplayLog.lua)
        -- default level = release (<2%, user 2026-10-08). FD_Logs elevates to captureLevel (v2.2.9 default diag; test|diag, <=10%) then restores.
        -- Capture (test) sized for a full 25 min 40-man BG under ~30 MB SV (incl. WorldCapture ws).
        -- Binding: tapeCap (not byteBudget). Rings lazy. KEEP decide/verdict/anchor/shadow/reconcile;
        -- ws/sec/api thin first with counted overflow in session.dropped.
        level = "release", captureLevel = "lab",   -- v2.2.15: FD_Logs captures run at lab (perf reported, not gated)
        anchorEveryN = 8,     -- release: cast sync every Nth own SUCCEEDED; test/diag: every
        -- v2.2.10: diag (the default capture level) keeps EVERYTHING for a full 20-30 min 40-man BG: its numbers are safety
        -- ceilings against a runaway loop (~10x a 30 min BG), not data budgets. Hitting one prints a warning once.
        -- release keeps its small caps; test keeps the bounded v2.2.6 sizes (<= 26 MB SV gate).
        -- DAMAGE_METER_* rows fold losslessly into run rows (ns.RLE: rc/q/dt/dq) in the combat ring, recorder and tape;
        -- the converter expands them on load (tools/fdump/dmrle.py). Diag SV save time is reported, not capped.
        byteBudgetKB = { release = 512, test = 10240, diag = 4194304, lab = 4194304 },  -- tapeCap still binds row count; budget backs estimateBytes
        tapeCap = { release = 800, test = 68000, diag = 2000000, lab = 2000000 },
        verifyCap = { release = 600, test = 12000, diag = 250000, lab = 250000 },
        ringCaps = {
            release = { record = 4000, combat = 10000, signals = 3000 },
            test    = { record = 38000, combat = 85000, signals = 6000 },
            diag    = { record = 2000000, combat = 1000000, signals = 250000, perEventPerSec = 1000 },
            lab     = { record = 2000000, combat = 1000000, signals = 250000, perEventPerSec = 1000 },
        },
    },
    timing = {                -- v2.2.4 per-spell GCD / cooldown table (Timing.lua): seed Data/spell-timing.lua + learned
        enabled = true,       --   updates per build in ForeverDumpDB.timing[build] (running min/max/sum/count, LRU)
        maxSpells = 300, minSamples = 3,
    },
    learned = {               -- v2.2.4 persistent learned spell / NPC / class DB (Learned.lua): ForeverDumpDB.learned[build],
        enabled = true,       --   every clear spellID from any unit, O(1) per event, info reads out of combat, LRU caps
        maxSpells = 2000, maxNpcs = 800, maxClasses = 20, infoPerTick = 6, infoInterval = 0.5, auraWindow = 1.0,
    },
    drift = {                 -- v2.2.4 drift guard (Drift.lua): seeds are starting points; consistent disagreement -> runtime
        enabled = true,       --   override + changelog (ForeverDumpDB.drift[build]); build change -> re-baseline
        minDisagree = 2.5, ratio = 0.6, decay = 0.9, absTol = 0.15, relTol = 0.10, maxItems = 500, maxChangelog = 200,
    },
    tokenscan = {             -- v2.2.4 group-aware discovery token scanner (Tokens.lua T.Scan): broad round-robin over every
        enabled = true,       --   family under a hard per-slice time budget (ticker, never OnUpdate); cost logged per capture
        interval = 0.1, budgetMs = 0.12, bailMs = 0.04, maxTokensPerSlice = 24,
    },
    identity = {              -- v2.2.4 identity ledger feeder (Identity.lua): token->GUID / GUID->identity while clear,
        enabled = true,       --   alias / fingerprint / cached resolution when secret, chained-token survey per composition
        pollInterval = 1,     -- s: chained tokens (targettarget, focustarget, ...) polled ONLY while one exists
        minInterval = 0.25,   -- s: per-token minimum gap between event-driven reads
        auraScan = true,      -- out-of-combat aura scan of player/target into the ledger (auraInstanceID -> spellId)
    },
    perf = {                  -- v2.2.3 self-perf monitor (Perf.lua): handler timings + 5 s samples in every FD_Logs capture
        enabled = true, sampleInterval = 5, maxSamples = 720, keepSessions = 4,
    },
    containers = {            -- v2.2.2 container-state schema (Containers.lua): codes/flags/keys per field, never values
        enabled = true,       -- run in every FD_Logs capture: ON (ooc), first combat / each restriction context once
        events = true, eventSamples = 25, -- UNIT_AURA payload walks per context/unit class/capture
        maxRunsPerCapture = 8, spells = 4, -- player spell cooldown/charges/info objects: GCD + N known spells
    },
    restrictions = {          -- v2.2 restrictions tracker (Restrictions.lua): event logging only, no hooks
        enabled = true,       -- log ADDON_RESTRICTION_STATE_CHANGED flips + context markers (always, bounded)
        probe = true,         -- while FD_Logs capture is ON: re-run the small flip probe set at each flip (+ next frame)
        maxFlips = 400, maxMarkers = 600, maxProbedFlips = 150,
    },
    errors = {
        enabled = true,       -- chain the Lua error handler at load and log errors (/fdump errors off to disable)
        maxErrors = 200,      -- unique error messages kept
        maxBlocked = 500,     -- ADDON/MACRO_ACTION_BLOCKED/FORBIDDEN + LUA_WARNING entries kept
        captureLocals = true, -- debuglocals() when available
        maxLocals = 4000,
        maxStack = 4000,
    },
    probe = {
        items = { 6948, 2589, 118, 25, 2070, 159 },
        spells = { 6603, 8690, 133, 2050, 1459, 78, 465, 1752 },
        quests = { 783, 7, 33 },
        units = { "player", "target", "focus", "pet", "mouseover", "party1" },
        achievements = { 6, 7 },
        currencies = { 1, 81, 1792 },
        maxAuras = 40,
        redactPlayers = false, -- v2.2.21: raw (true: player names/realm/GUIDs replaced by placeholders)
    },
}

local function mergeDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = {}
                mergeDefaults(dst[k], v)
            elseif v[1] == nil then
                mergeDefaults(dst[k], v)
            end
            -- a default that is a list (callbackEvents, ...) is never merged into the saved list: the
            -- user's list wins whole (v2.2.11: merging padded a 2-entry list with defaults [3..n])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function ns.InitDB()
    if type(ForeverDumpDB) ~= "table" then ForeverDumpDB = {} end
    local db = ForeverDumpDB
    db.schemaVersion = ns.SCHEMA
    -- v2.2.14: remember which version wrote the file last; a change is announced once at login (VersionNotice)
    local prev = db.addonVersion
    if prev ~= ns.VERSION then
        ns.versionChange = { from = (type(prev) == "string" and prev) or "none", to = ns.VERSION }
        if type(db.versionHistory) ~= "table" then db.versionHistory = {} end
        local vh = db.versionHistory
        vh[#vh + 1] = { from = ns.versionChange.from, to = ns.VERSION, time = rawget(_G, "time") and time() or nil }
        while #vh > 20 do table.remove(vh, 1) end
    end
    db.addonVersion = ns.VERSION
    if type(db.config) ~= "table" then db.config = {} end
    -- config migrations: saved values win over new defaults, so flip the ones that changed for safety
    local cv = tonumber(db.config.configVersion) or 0
    if cv < 22 and type(db.config.record) == "table" then
        db.config.record.callbacks = false   -- v2.1 default true installed the EventRegistry hook (see Recorder.lua)
    end
    -- v2.2.15 (user decision 2026-10-09): FD_Logs captures default to the new "lab" level (diag + shadow rules + lab probes)
    if cv < 23 and type(db.config.replay) == "table" and db.config.replay.captureLevel == "diag" then
        db.config.replay.captureLevel = "lab"
    end
    db.config.configVersion = 23
    mergeDefaults(db.config, ns.defaults)
    if type(db.sections) ~= "table" then db.sections = {} end
    if type(db.history) ~= "table" then db.history = {} end
    if type(ForeverDumpDocsDB) ~= "table" then ForeverDumpDocsDB = {} end
    if type(ForeverDumpStringsDB) ~= "table" then ForeverDumpStringsDB = {} end
    -- v2.2.7: static client data lives in ForeverDumpStaticDB (see Static.lua); migrate + alias + read fallbacks
    if ns.Static then ns.Static.Init(db) end
    if type(ForeverDumpRecordDB) ~= "table" then ForeverDumpRecordDB = {} end
    if type(ForeverDumpRecordDB.sessions) ~= "table" then ForeverDumpRecordDB.sessions = {} end
    ForeverDumpRecordDB.schemaVersion = ns.SCHEMA
    if type(ForeverDumpLogDB) ~= "table" then ForeverDumpLogDB = {} end
    for _, k in ipairs({ "errors", "blocked", "handlerEvents", "restrictions" }) do
        if type(ForeverDumpLogDB[k]) ~= "table" then ForeverDumpLogDB[k] = {} end
    end
    ForeverDumpLogDB.schemaVersion = ns.SCHEMA
    if type(ForeverDumpCombatLogDB) ~= "table" then ForeverDumpCombatLogDB = {} end
    if type(ForeverDumpCombatLogDB.sessions) ~= "table" then ForeverDumpCombatLogDB.sessions = {} end
    ForeverDumpCombatLogDB.schemaVersion = ns.SCHEMA
    ns.db = db
    ns.config = db.config
end

function ns.Full() return ns.config and ns.config.dump and ns.config.dump.full == true end

function ns.SaveSection(name, data)
    data.meta = ns.Meta()
    data.compact = not ns.Full() or nil
    if ns.Static and ns.Static.IsStatic(name) then ns.Static.Sections()[name] = data   -- v2.2.7: own SavedVariables table
    else ns.db.sections[name] = data end
    local identity = type(ns.db.meta) == "table" and ns.db.meta.identity or nil
    ns.db.meta = ns.Meta()
    ns.db.meta.identity = identity
    local h = ns.db.history
    h[#h + 1] = { section = name, build = data.meta.build, version = data.meta.version, time = data.meta.time }
    while #h > 100 do table.remove(h, 1) end
end

----------------------------------------------------------------------------
-- Chunked job scheduler (coroutines driven by OnUpdate)
----------------------------------------------------------------------------
local debugprofilestop = _G.debugprofilestop or function() return (os and os.clock and os.clock() or 0) * 1000 end
ns.queue = {}
ns.current = nil
local sliceStart = 0
local lastProgress = 0

-- Collectors call this often. Yields when the frame budget is used up.
function ns.Yield()
    if not ns.current then return end
    if debugprofilestop() - sliceStart >= (ns.config and ns.config.frameBudgetMs or 12) then
        coroutine.yield()
    end
end

function ns.Progress(label, done, total)
    local now = (GetTime and GetTime()) or 0
    if now - lastProgress >= (ns.config and ns.config.progressEverySec or 2) then
        lastProgress = now
        if total and total > 0 then
            ns.Print(format("%s: %d/%d (%d%%)", label, done, total, math.floor(done * 100 / total)))
        else
            ns.Print(format("%s: %d", label, done))
        end
    end
end

-- job = { name=, fn=function(job) end, combatSafe=bool, onDone=function(ok, err) }
function ns.Enqueue(job)
    ns.queue[#ns.queue + 1] = job
    ns.EnsureRunner()
end

function ns.IsBusy() return ns.current ~= nil or #ns.queue > 0 end

local runner
local pausedNotice = false
local function step()
    if not ns.current then
        -- perf-ok: job queue (a handful of entries), one shift per job
        local job = table.remove(ns.queue, 1)
        if not job then
            runner:SetScript("OnUpdate", nil)
            return
        end
        job.co = coroutine.create(job.fn)
        job.started = GetTime and GetTime() or 0
        ns.current = job
        ns.Print("running '" .. job.name .. "'...")
    end
    local job = ns.current
    if not job.combatSafe and ns.InCombat() then
        if not pausedNotice then
            ns.Print("combat started: '" .. job.name .. "' paused until you leave combat.")
            pausedNotice = true
        end
        return
    end
    pausedNotice = false
    sliceStart = debugprofilestop()
    local ok, err = coroutine.resume(job.co, job)
    local status = coroutine.status(job.co)
    if not ok or status == "dead" then
        ns.current = nil
        local secs = (GetTime and GetTime() or 0) - (job.started or 0)
        if ok then
            ns.Print(format("'%s' done in %.1fs.", job.name, secs))
        else
            ns.Print("|cffff5555'" .. job.name .. "' failed:|r " .. tostring(err))
            if ns.db then
                ns.db.errors = ns.db.errors or {}
                ns.db.errors[#ns.db.errors + 1] = { job = job.name, err = tostring(err), time = time and time() }
                -- perf-ok: error list capped at 50, runs once per failed job
                while #ns.db.errors > 50 do table.remove(ns.db.errors, 1) end
            end
        end
        if job.onDone then pcall(job.onDone, ok, err) end
        if #ns.queue == 0 then
            ns.Print("all jobs finished. |cffffff00/reload or log out to write SavedVariables to disk.|r")
        end
    end
end

function ns.EnsureRunner()
    if not runner then runner = CreateFrame("Frame") end
    -- perf-ok: job runner OnUpdate: budgeted coroutine slices of dump jobs, removed when the queue is empty; strings once per job
    runner:SetScript("OnUpdate", step)
end

function ns.CancelAll()
    ns.queue = {}
    ns.current = nil
    if runner then runner:SetScript("OnUpdate", nil) end
end

----------------------------------------------------------------------------
-- Section registry
----------------------------------------------------------------------------
ns.sections = {}
ns.sectionOrder = {}
-- def = { name=, desc=, run=function(job) ... end, combatSafe=, inAll=bool }
function ns.RegisterSection(def)
    ns.sections[def.name] = def
    ns.sectionOrder[#ns.sectionOrder + 1] = def.name
end

-- v2.2.7: read-only UI integrity signature (run 6 bisect). The ObjectiveTracker nil-call in "[C] LayoutContents" means a C
-- trampoline sits where Blizzard defines a Lua method (no Blizzard hook in the 70245 source). Per module: "=" the instance
-- method is the mixin's, "W" it is wrapped/replaced, "0" missing, "-" module absent. Recorded before/after every dump section,
-- at capture ON/OFF and on /fdump health, so the next capture shows exactly which step (if any) changes it. Reads only.
local UI_SIG = {
    { "BonusObjectiveTracker", "BonusObjectiveTrackerMixin" }, { "QuestObjectiveTracker", "QuestObjectiveTrackerMixin" },
    { "WorldQuestObjectiveTracker", "WorldQuestObjectiveTrackerMixin" }, { "AchievementObjectiveTracker", "AchievementObjectiveTrackerMixin" },
    { "ScenarioObjectiveTracker", "ScenarioObjectiveTrackerMixin" }, { "CampaignQuestObjectiveTracker", "QuestObjectiveTrackerMixin" },
}
function ns.UISig()
    local parts = {}
    for _, p in ipairs(UI_SIG) do
        local o, m = rawget(_G, p[1]), rawget(_G, p[2])
        local s = "-"
        if type(o) == "table" then
            local okF, f = pcall(function() return o.LayoutContents end)
            local okM, mf = pcall(function() return type(m) == "table" and m.LayoutContents or nil end)
            if okF and f ~= nil then s = (okM and f == mf) and "=" or "W" else s = "0" end
        end
        parts[#parts + 1] = p[1]:gsub("ObjectiveTracker", "") .. s
    end
    return table.concat(parts, " ")
end
function ns.NoteUISig(where, before)
    local log = rawget(_G, "ForeverDumpLogDB")
    if type(log) ~= "table" then return end
    local after = ns.UISig()
    log.uiIntegrity = type(log.uiIntegrity) == "table" and log.uiIntegrity or {}
    local list = log.uiIntegrity
    local last = list[#list]
    if before == nil or before ~= after or not last or last.sig ~= after or where:find("^capture") then
        list[#list + 1] = ns.Stamp({ where = where, before = before, sig = after, changed = (before ~= nil and before ~= after) or nil })
        while #list > 60 do table.remove(list, 1) end
    end
end

function ns.RunSection(name, args)
    local def = ns.sections[name]
    if not def then ns.Print("unknown section: " .. tostring(name)) return end
    if not def.combatSafe and ns.InCombat() then
        ns.Print("|cffff5555refusing '" .. name .. "' in combat.|r Leave combat and try again.")
        return
    end
    ns.Enqueue({ name = name, combatSafe = def.combatSafe, fn = function(job)
        local before = ns.UISig()
        def.run(job, args)
        ns.NoteUISig("section:" .. name, before)
    end })
end

----------------------------------------------------------------------------
-- Events
----------------------------------------------------------------------------
ns.eventHandlers = {}
ns.registerFailed = {}
function ns.On(event, fn)
    ns.eventHandlers[event] = ns.eventHandlers[event] or {}
    table.insert(ns.eventHandlers[event], fn)
    if ns.eventFrame then
        -- unknown / Forever-only event names throw in RegisterEvent: never let that break loading
        local ok, err = pcall(ns.eventFrame.RegisterEvent, ns.eventFrame, event)
        if not ok then ns.registerFailed[event] = tostring(err) end
    end
end

-- self-protection: ForeverDump's own errors (handler failures, errors with a ForeverDump frame) are counted; past
-- secrets.selfErrorLimit (default 20) probes, sweeps and controls stop for the rest of the session so the client's
-- error reporting cap (~100/session) stays available for real errors.
ns.selfErrors = 0
function ns.NoteSelfError(where, err)
    ns.selfErrors = (ns.selfErrors or 0) + 1
    local log = ForeverDumpLogDB
    if type(log) == "table" then
        log.selfErrors = log.selfErrors or {}
        local se = log.selfErrors
        if #se < 30 then
            local msg = err
            if IsSecret(msg) then msg = "<secret>" end
            se[#se + 1] = { where = where, err = string.sub(tostring(msg), 1, 300), t = GetTime and GetTime() or nil,
                sid = ns.SessionId and ns.SessionId() or nil }
        end
    end
    local limit = tonumber(ns.config and ns.config.secrets and ns.config.secrets.selfErrorLimit) or 20
    if ns.selfErrors == limit then
        ns.Print("|cffff5555ForeverDump hit " .. limit .. " of its own errors this session: probes, sweeps and controls are paused "
            .. "(see ForeverDumpLogDB.selfErrors).|r")
        if ns.Secrets and ns.Secrets.IsSweeping and ns.Secrets.IsSweeping() then pcall(ns.Secrets.StopSweep) end
    end
end
function ns.SelfThrottled()
    local limit = tonumber(ns.config and ns.config.secrets and ns.config.secrets.selfErrorLimit) or 20
    return (ns.selfErrors or 0) >= limit
end

ns.loadedAddOns = {} -- ADDON_LOADED order seen this session (includes Blizzard_*)

local eventFrame = CreateFrame("Frame")
ns.eventFrame = eventFrame
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if type(name) == "string" and not IsSecret(name) then
            ns.loadedAddOns[#ns.loadedAddOns + 1] = name
        end
        if name == ns.ADDON then
            -- v2.2.11: rebuild packed SavedVariables (SVPack.lua) before anything reads them
            if ns.Perf and ns.Perf.Mark then pcall(ns.Perf.Mark, "load:begin") end
            if ns.SVPack then pcall(ns.SVPack.UnpackAll) end
            if ns.Perf and ns.Perf.Mark then pcall(ns.Perf.Mark, "load:svunpack") end   -- v2.2.16 peak bracket
            ns.InitDB()
            if ns.Perf and ns.Perf.Mark then pcall(ns.Perf.Mark, "load:initdb") end
            if ns.SVPack and ns.SVPack.lastUnpack and next(ns.SVPack.lastUnpack.vars) and ns.db then
                ns.db.svunpack = ns.SVPack.lastUnpack
            end
            if ns.VersionNotice then
                local okV, vmsg = pcall(ns.VersionNotice)
                if okV and vmsg then ns.Print(vmsg) end
            end
            -- v2.2.13: the last logout's pack problems (run 10: every pack failed, file written unpacked) are shown once
            if ns.SVPack and ns.SVPack.LoginReport then
                local okR, msg = pcall(ns.SVPack.LoginReport)
                if okR and msg then ns.Print(msg) end
                local lu = ns.SVPack.lastUnpack
                if lu and lu.failed then ns.Print("|cffff5555SavedVariables: " .. lu.failed .. " packed variable(s) could "
                    .. "not be rebuilt; kept as .packedRescue (decode offline).|r") end
            end
        end
    end
    local list = ns.eventHandlers[event]
    if event == "PLAYER_LOGIN" and ns.Perf and ns.Perf.Mark then pcall(ns.Perf.Mark, "login:begin") end
    if list then
        local P = ns.Perf
        for i = 1, #list do
            local ok, err
            if P and P.on then ok, err = P.Run(P.Key("core", event), list[i], event, ...) else ok, err = pcall(list[i], event, ...) end
            if not ok then
                ns.NoteSelfError("handler:" .. event, err)
                if (ns.selfErrors or 0) <= 5 then ns.Print("handler error (" .. event .. "): " .. tostring(err)) end
            end
        end
    end
    if event == "PLAYER_LOGIN" and ns.Perf and ns.Perf.Mark then pcall(ns.Perf.Mark, "login:handlers") end
    -- v2.2.11: after every logout handler has written its data, pack the SavedVariables so the file always loads
    -- (Lua 5.1 constant-table limit, see SVPack.lua). config.svpack = false turns it off (then the OFF guard warns).
    if event == "PLAYER_LOGOUT" and ns.SVPack and not (ns.config and ns.config.svpack == false) then
        local ok, err = pcall(ns.SVPack.PackAll)
        if not ok then ns.NoteSelfError("svpack", err) end
    end
end)

