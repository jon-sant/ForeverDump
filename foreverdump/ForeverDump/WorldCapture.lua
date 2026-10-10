-- ForeverDump v2.2.6 — capture-mode world-state raw logger (logging only; HSM inference next version).
-- Round-robins every valid token family and records five-state ClassifyValue codes + timestamps for:
--   cast/channel, aura slot counts, health/power (codes + clear max), threat, range bands, target-of.
-- Never stores secret values. Runs only while ReplayLog.IsTest(); release impact stays zero.
-- Budget-capped per slice so FD_Logs capture stays ≤10%; tape kind "ws" is droppable under ~30 MB session.
local _, ns = ...
local WC = {}
ns.WorldCapture = WC

local function g(n) return rawget(_G, n) end
local function cfg() return (ns.config and ns.config.worldCapture) or {} end
local function now() return (g("GetTime") or os.clock)() end
local function pclock()
    local d = g("debugprofilestop")
    if type(d) == "function" then return d() end
    return now() * 1000
end
local function code(v) return ns.ClassifyValue(v) end
local function captureOn()
    return ns.ReplayLog and ns.ReplayLog.IsTest and ns.ReplayLog.IsTest()
end

-- token list: reuse Tokens scanner builder when available, else a solid default
local function allTokens()
    local S = ns.Tokens and ns.Tokens.Scan
    if S and S.BuildList then
        local ctx = (S.Context and S.Context()) or { instance = "world", group = "solo" }
        return S.BuildList(ctx)
    end
    local out = { "player", "pet", "target", "focus", "mouseover", "targettarget", "focustarget", "pettarget" }
    local function add(t) out[#out + 1] = t end
    for i = 1, 4 do add("party" .. i) add("party" .. i .. "target") add("partypet" .. i) end
    for i = 1, 40 do add("raid" .. i) add("raid" .. i .. "target") end
    for i = 1, 5 do add("arena" .. i) add("arena" .. i .. "target") end
    for i = 1, 8 do add("boss" .. i) add("boss" .. i .. "target") end
    for i = 1, 40 do add("nameplate" .. i) add("nameplate" .. i .. "target") end
    return out
end

-- field pack: 4 bits each, up to 16 fields -> one number (same scheme as ReplayLog.OnCriticalEvent)
-- order: exists, health, healthMax, power, powerMax, threat, threatDetail, range10, range28, inRange,
--        casting, channeling, notInterruptible, helpfulSlots, harmfulSlots, dead
local FIELD_ORDER = {
    "exists", "health", "healthMax", "power", "powerMax", "threat", "threatDet", "range10", "range28",
    "inRange", "casting", "channeling", "notInt", "buffN", "debuffN", "dead",
}
local CODE_N = { N = 0, S = 1, T = 2, K = 3, C = 4, G = 6 }   -- 5 = E/unknown; 6 = G: not read (combat guard, v2.2.7)

local st = { list = {}, pos = 0, lastPack = {}, lastId = {}, samples = 0, dropped = 0, slices = 0, ms = 0 }
WC.state = st

local fnCache = {}
local function api(path)
    local f = fnCache[path]
    if f == nil then
        if path:find(".", 1, true) then
            local a, b = path:match("^([^.]+)%.(.+)$")
            local root = g(a)
            f = (type(root) == "table" and root[b]) or false
        else
            f = g(path) or false
        end
        fnCache[path] = f
    end
    return f or nil
end

local function fam(tok)
    if type(tok) ~= "string" then return "?" end
    return tok:gsub("%d+", "N")
end

-- v2.2.7 (run 6b): API values only via ns.ClearNum/ClearStr/IsTrue/IsNil (classify first, no raw truth tests)
local function clearNum(v) return ns.ClearNum(v) end
local clearStr, isTrue, isNil = ns.ClearStr, ns.IsTrue, ns.IsNil

-- v2.2.21: raw Creature GUID kept next to the npc:<id> group key (player keys already hold the raw GUID)
local function npcRaw(key, guid)
    if type(key) == "string" and key:find("^npc:") then return guid end
    return nil
end

local function sampleToken(tok, deadline)
    local codes = {}
    local ex = api("UnitExists")
    local ok, exists = false, nil
    if ex then ok, exists = pcall(ex, tok) end
    codes.exists = ok and code(exists) or "E"
    if not (codes.exists == "C" and isTrue(exists)) then
        return codes, nil, nil, true  -- absent: cheap
    end

    -- health / power
    do
        local f = api("UnitHealth")
        if f then local ok2, v = pcall(f, tok); codes.health = ok2 and code(v) or "E"
        else codes.health = "N" end
    end
    if pclock() >= deadline then return codes, nil, nil, false end
    do
        local f = api("UnitHealthMax")
        if f then
            local ok2, v = pcall(f, tok)
            codes.healthMax = ok2 and code(v) or "E"
            st._hpMax = ok2 and clearNum(v) or nil
        else codes.healthMax = "N" end
    end
    if pclock() >= deadline then return codes, nil, nil, false end
    do
        local f = api("UnitPower")
        if f then local ok2, v = pcall(f, tok); codes.power = ok2 and code(v) or "E"
        else codes.power = "N" end
    end
    if pclock() >= deadline then return codes, nil, nil, false end
    do
        local f = api("UnitPowerMax")
        if f then local ok2, v = pcall(f, tok); codes.powerMax = ok2 and code(v) or "E"
        else codes.powerMax = "N" end
    end
    if pclock() >= deadline then return codes, nil, nil, false end

    -- threat vs player
    do
        local f = api("UnitThreatSituation")
        if f then
            local ok2, v = pcall(f, "player", tok)
            codes.threat = ok2 and code(v) or "E"
            st._threat = ok2 and clearNum(v) or nil
        else codes.threat = "N" end
    end
    if pclock() >= deadline then return codes, nil, nil, false end
    do
        local f = api("UnitDetailedThreatSituation")
        if f then
            local ok2, _, _, scaled = pcall(f, "player", tok)
            codes.threatDet = ok2 and code(scaled) or "E"
            st._threatPct = ok2 and clearNum(scaled) or nil
        else codes.threatDet = "N" end
    end
    if pclock() >= deadline then return codes, nil, nil, false end

    -- range bands: CheckInteractDistance 1=inspect(~28yd? actually 1=trade 11.11, 2=inspect 28, 3=duel 9.9, 4=follow 28)
    -- use 2 (28) and 3 (~10)
    -- v2.2.7: CheckInteractDistance is protected in combat (run 6: 6 ADDON_ACTION_BLOCKED from here) -> code "G" (guarded)
    do
        local f = api("CheckInteractDistance")
        if f and st.locked and ns.CombatGuard and ns.CombatGuard("CheckInteractDistance", st.locked) then
            codes.range10, codes.range28 = "G", "G"
            st.guardSkips = (st.guardSkips or 0) + 1
        elseif f then
            local ok2, v = pcall(f, tok, 3); codes.range10 = ok2 and code(v) or "E"
            if pclock() >= deadline then return codes, nil, nil, false end
            ok2, v = pcall(f, tok, 2); codes.range28 = ok2 and code(v) or "E"
        else codes.range10, codes.range28 = "N", "N" end
    end
    if pclock() >= deadline then return codes, nil, nil, false end
    do
        local f = api("UnitInRange")
        if f then local ok2, v = pcall(f, tok); codes.inRange = ok2 and code(v) or "E"
        else codes.inRange = "N" end
    end
    if pclock() >= deadline then return codes, nil, nil, false end

    -- cast / channel (codes only; NeverSecret castBarID / notInterruptible when clear)
    local castBar, spellId
    do
        local f = api("UnitCastingInfo")
        if f then
            -- returns: name, displayName, texture, start, end, isTrade, castID, notInterruptible, spellID, castBarID
            local ok2, name, _, _, _, _, _, _, notInterruptible, sid, bar = pcall(f, tok)
            codes.casting = ok2 and code(name) or "E"
            if ok2 and not isNil(name) then
                codes.notInt = code(notInterruptible)
                spellId = clearNum(sid)
                castBar = clearNum(bar)
            else
                codes.notInt = "N"
            end
        else
            codes.casting, codes.notInt = "N", "N"
        end
    end
    if pclock() >= deadline then return codes, spellId, castBar, false end
    do
        local f = api("UnitChannelInfo")
        if f then
            -- returns: name, displayName, texture, start, end, isTrade, notInterruptible, spellID, isEmpowered, numStages, castBarID
            local ok2, name, _, _, _, _, _, notInterruptible, sid, _, _, bar = pcall(f, tok)
            codes.channeling = ok2 and code(name) or "E"
            if ok2 and not isNil(name) then
                if codes.notInt == "N" or codes.notInt == nil then codes.notInt = code(notInterruptible) end
                spellId = spellId or clearNum(sid)
                castBar = castBar or clearNum(bar)
            end
        else
            codes.channeling = "N"
        end
    end
    if pclock() >= deadline then return codes, spellId, castBar, false end

    -- aura slot counts (GetAuraSlots: continuationToken, slots...; may error when secret)
    do
        local ua = g("C_UnitAuras")
        if type(ua) == "table" and type(ua.GetAuraSlots) == "function" and ns.Pack then
            local res = ns.Pack(pcall(ua.GetAuraSlots, tok, "HELPFUL"))
            if res and res[1] then
                codes.buffN = "C"
                st._buffN = math.max((res.n or 2) - 2, 0)
            else
                codes.buffN = "E"
            end
            res = ns.Pack(pcall(ua.GetAuraSlots, tok, "HARMFUL"))
            if res and res[1] then
                codes.debuffN = "C"
                st._debuffN = math.max((res.n or 2) - 2, 0)
            else
                codes.debuffN = "E"
            end
        else
            codes.buffN, codes.debuffN = "N", "N"
        end
    end
    if pclock() >= deadline then return codes, spellId, castBar, false end

    do
        local f = api("UnitIsDeadOrGhost")
        if f then local ok2, v = pcall(f, tok); codes.dead = ok2 and code(v) or "E"
        else codes.dead = "N" end
    end

    -- identity / target-of (v2.2.21: raw GUID stored as g / tg next to the key; only when the GUID is clear)
    local idKey, tgtKey, clearG, clearTG
    do
        local f = api("UnitGUID")
        local ok2, rawGuid = false, nil
        if f then ok2, rawGuid = pcall(f, tok) end
        local guid = ok2 and clearStr(rawGuid) or nil
        clearG = guid
        if guid and ns.ReplayLog and ns.ReplayLog.IdKey then
            local kind = guid:find("^Player%-") and "player" or (guid:find("^Creature%-") and "npc") or "guid"
            if kind == "npc" then
                idKey = ns.ReplayLog.IdKey("npc", guid)
            else
                idKey = ns.ReplayLog.IdKey(kind, guid)
            end
        end
    end
    if pclock() >= deadline then return codes, spellId, castBar, false end
    -- target-of: UnitGUID(tok.."target") or UnitIsUnit
    do
        local ttok = tok .. "target"
        if tok == "target" then ttok = "targettarget"
        elseif tok == "focus" then ttok = "focustarget"
        elseif tok == "player" then ttok = "target" end
        local f = api("UnitGUID")
        local ok2, rawGuid = false, nil
        if f then ok2, rawGuid = pcall(f, ttok) end
        local guid = ok2 and clearStr(rawGuid) or nil
        clearTG = guid
        if guid and ns.ReplayLog and ns.ReplayLog.IdKey then
            local kind = guid:find("^Player%-") and "player" or (guid:find("^Creature%-") and "npc") or "guid"
            tgtKey = (kind == "npc") and ns.ReplayLog.IdKey("npc", guid) or ns.ReplayLog.IdKey(kind, guid)
        end
        -- who targets me?
        local iu = api("UnitIsUnit")
        if iu then
            local ok3, isMe = pcall(iu, ttok, "player")
            st._tgtIsMe = (ok3 and isTrue(isMe)) or nil
        end
    end

    return codes, spellId, castBar, true, idKey, tgtKey, clearG, clearTG
end

-- v2.2.7 (run 6b): two exact 32-bit words. One 16-field word (64 bits) does not fit a Lua number (53-bit mantissa):
-- 6b decoded exists/health as N for every sample (the low nibbles were rounded away). p = fields 1-8, q = fields 9-16.
local function packCodes(codes)
    local p, q = 0, 0
    for i, name in ipairs(FIELD_ORDER) do
        local c = CODE_N[codes[name] or "?"] or 5
        if i <= 8 then p = p + c * (16 ^ (i - 1)) else q = q + c * (16 ^ (i - 9)) end
        if i >= 16 then break end
    end
    return p, q
end
WC.PackCodes = packCodes
WC.FIELD_ORDER = FIELD_ORDER

function WC.Slice()
    if not captureOn() or cfg().enabled == false then return end
    local budget = tonumber(cfg().budgetMs) or 0.10
    local t0 = pclock()
    local deadline = t0 + budget
    st.locked = true   -- unknown -> locked
    if ns.CombatLocked then st.locked = ns.CombatLocked() end
    if #st.list == 0 then st.list = allTokens(); st.pos = 0 end
    local maxTok = tonumber(cfg().maxTokensPerSlice) or 12
    local hb = tonumber(cfg().heartbeatSec) or 5
    local tnow = now()
    local n = 0
    while n < maxTok and pclock() < deadline do
        st.pos = (st.pos % #st.list) + 1
        local tok = st.list[st.pos]
        n = n + 1
        st._hpMax, st._threat, st._threatPct, st._buffN, st._debuffN, st._tgtIsMe = nil, nil, nil, nil, nil, nil
        local codes, spellId, castBar, _, idKey, tgtKey, clearG, clearTG = sampleToken(tok, deadline)
        if not codes then break end
        -- done=false means budget hit mid-token; still log partial codes
        local pack, pack2 = packCodes(codes)
        local prev, prev2 = st.lastPack[tok], st.lastPack2 and st.lastPack2[tok]
        local force = (not st.lastId[tok]) or (tnow - (st.lastId[tok] or 0) >= hb)
        local changed = prev ~= pack or prev2 ~= pack2 or (idKey and st._lastIdKey and st._lastIdKey[tok] ~= idKey)
        if changed or force then
            st.lastPack[tok] = pack
            st.lastPack2 = st.lastPack2 or {}
            st.lastPack2[tok] = pack2
            st.lastId[tok] = tnow
            st._lastIdKey = st._lastIdKey or {}
            st._lastIdKey[tok] = idKey
            if ns.ReplayLog and ns.ReplayLog.OnWorldSample then
                local ok = ns.ReplayLog.OnWorldSample({
                    tok = fam(tok),
                    p = pack, q = pack2,     -- v2.2.7: fields 1-8 / 9-16 (exact)
                    id = idKey,
                    tgt = tgtKey,
                    g = npcRaw(idKey, clearG),      -- v2.2.21 raw GUID next to an npc:<id> key
                    tg = npcRaw(tgtKey, clearTG),
                    sp = spellId,
                    bar = castBar,
                    hp = st._hpMax,          -- clear max only
                    th = st._threat,         -- clear threat status 0-3
                    tp = st._threatPct,      -- clear scaled %
                    bn = st._buffN, dn = st._debuffN,
                    me = st._tgtIsMe and 1 or nil,
                })
                if ok then st.samples = st.samples + 1 else st.dropped = st.dropped + 1 end
            end
        end
        if st.pos == #st.list then
            -- refresh token list each full sweep (roster/nameplates change)
            st.list = allTokens()
        end
    end
    st.slices = st.slices + 1
    st.ms = st.ms + (pclock() - t0)
end

local ticker
function WC.Start()
    if cfg().enabled == false then return false end
    if not captureOn() then return false end  -- release: no-op
    st.list, st.pos, st.lastPack, st.lastPack2, st.lastId = allTokens(), 0, {}, {}, {}
    st.samples, st.dropped, st.slices, st.ms = 0, 0, 0, 0
    st.guardSkips = 0
    st._lastIdKey = {}
    fnCache = {}
    local ct = g("C_Timer")
    if not ticker and type(ct) == "table" and type(ct.NewTicker) == "function" then
        ticker = ct.NewTicker(tonumber(cfg().interval) or 0.2, function()
            if ns.Perf and ns.Perf.on then ns.Perf.Run("WorldCapture.Slice", WC.Slice) else pcall(WC.Slice) end
        end)
    end
    return true
end

-- v2.2.8: running counters for the replay tape header at OFF (numbers only)
function WC.Stats()
    return { samples = st.samples or 0, slices = st.slices or 0, dropped = st.dropped or 0, guardSkips = st.guardSkips or 0 }
end

function WC.Stop()
    if ticker then ticker:Cancel() ticker = nil end
    local c = { samples = st.samples, dropped = st.dropped, slices = st.slices,
        ms = math.floor(st.ms * 1000 + 0.5) / 1000 }
    st.list, st.lastPack, st.lastPack2 = {}, {}, {}
    return c
end

ns.captureModules = ns.captureModules or {}
ns.captureModules[#ns.captureModules + 1] = {
    name = "world-state capture (casts/auras/hp/threat/range/target-of)",
    start = function() return WC.Start() end,
    stop = function()
        local c = WC.Stop()
        return c and string.format("world-capture %d samples / %d slices (%.2f ms, %d dropped)",
            c.samples, c.slices, c.ms or 0, c.dropped or 0) or nil
    end,
}
