-- ForeverDump v2.2.4 - identity correlation + ledger feeder ("collect while available, retain, resolve later").
-- Whenever a unit token's identity is CLEAR it is recorded into the HSM ledger (Lib/HybridState.lua): token -> GUID,
-- GUID -> name / class / level / max health / max power / player / friend, nameplateN -> GUID, plus an out-of-combat
-- aura scan (auraInstanceID -> spellId) of player and target. When a GUID is secret the token resolves through
-- (1) UnitIsUnit(token, player|target) if that comparison is clear (alias), (2) a clear-signal fingerprint
-- (class:level:maxHP:isPlayer:friend) matched against identities recorded while clear, (3) the token's last clear GUID
-- (stale once the token changed). Chained tokens (targettarget, focustarget, partyNtarget, pettarget, ...) have no events
-- of their own: they are refreshed on UNIT_TARGET of their base unit and polled at 1 Hz ONLY while one exists.
-- Survey: per context x chained token x chain composition (each link: me / party / friendly-player / hostile-player /
-- hostile-npc / friendly-npc / neutral-npc / ?) the five-state code of each signal (codes only, never values).
-- v2.2.21: the tape map delta stores the raw GUID (g) next to its key; no scrubbing.
local _, ns = ...
local ID = {}
ns.Identity = ID

local function g(n) return rawget(_G, n) end
local function code(v) return ns.ClassifyValue(v) end
-- v2.2.7: classify first, hand out clear scalars / clear containers only (no `and v or nil` truth test on v)
local function clear(v)
    local c = code(v)
    if c == "C" or c == "K" then return v end
    return nil
end
local function now() return (g("GetTime") or os.clock)() end
local function cfg() return (ns.config and ns.config.identity) or {} end
local function ctxName() return ns.CombatProbe and ns.CombatProbe.Context() or (ns.InCombat() and "combat" or "ooc") end
local function hs() return ns.Inference and ns.Inference.hs end
local function ledger() local h = hs() return h and h.ledger end
local function dirty() if ns.HSMUI and ns.HSMUI.MarkDirty then ns.HSMUI.MarkDirty() end end

-- chained token -> its links (base first); base unit -> chained tokens refreshed on its UNIT_TARGET
local CHAINS = {
    targettarget = { "target", "targettarget" }, targettargettarget = { "target", "targettarget", "targettargettarget" },
    focustarget = { "focus", "focustarget" }, focustargettarget = { "focus", "focustarget", "focustargettarget" },
    pettarget = { "pet", "pettarget" }, mouseovertarget = { "mouseover", "mouseovertarget" },
}
for i = 1, 4 do CHAINS["party" .. i .. "target"] = { "party" .. i, "party" .. i .. "target" } end
ID.CHAINS = CHAINS
local BY_BASE = {
    target = { "target", "targettarget", "targettargettarget" }, focus = { "focus", "focustarget", "focustargettarget" },
    pet = { "pet", "pettarget" }, mouseover = { "mouseover", "mouseovertarget" }, player = { "target", "targettarget", "targettargettarget" },
}
for i = 1, 4 do BY_BASE["party" .. i] = { "party" .. i, "party" .. i .. "target" } end
ID.BY_BASE = BY_BASE
local BASES = { "player", "target", "focus", "pet", "mouseover", "party1", "party2", "party3", "party4" }

-- signal name, function path, args builder, which return to classify
local SIGNALS = {
    { "UnitGUID", "UnitGUID", function(t) return t end, 1 },
    { "UnitName", "UnitName", function(t) return t end, 1 },
    { "UnitIsUnit(player)", "UnitIsUnit", function(t) return t, "player" end, 1 },
    { "UnitIsUnit(target)", "UnitIsUnit", function(t) return t, "target" end, 1 },
    { "UnitIsPlayer", "UnitIsPlayer", function(t) return t end, 1 },
    { "UnitIsFriend", "UnitIsFriend", function(t) return "player", t end, 1 },
    { "UnitCanAttack", "UnitCanAttack", function(t) return "player", t end, 1 },
    { "UnitInParty", "UnitInParty", function(t) return t end, 1 },
    { "UnitClass", "UnitClass", function(t) return t end, 2 },
    { "UnitLevel", "UnitLevel", function(t) return t end, 1 },
    { "UnitHealthMax", "UnitHealthMax", function(t) return t end, 1 },
    { "UnitPowerMax", "UnitPowerMax", function(t) return t end, 1 },
}
ID.SIGNALS = SIGNALS

local function call(path, ...)
    local f = ns.Resolve and ns.Resolve(path) or g(path)
    if type(f) ~= "function" then return nil, "N", true end
    local res = ns.Pack(pcall(f, ...))
    if not res[1] then return nil, "E" end
    return res, nil
end

-- one read of every signal for a token: values (clear only) + codes
local function read(tok)
    local v, c = {}, {}
    for _, s in ipairs(SIGNALS) do
        local res, err, absent = call(s[2], s[3](tok))
        if absent then c[s[1]] = nil
        elseif err then c[s[1]] = err
        else
            local x = res[1 + s[4]]
            c[s[1]] = code(x)
            v[s[1]] = clear(x)
        end
    end
    return v, c
end

-- link class from clear signals only
local function linkClass(v)
    if v["UnitIsUnit(player)"] == true then return "me" end
    local isP, fr, atk = v.UnitIsPlayer, v.UnitIsFriend, v.UnitCanAttack
    if isP == nil then return "?" end
    if isP then
        if v.UnitInParty == true then return "party" end
        if fr == true then return "friendly-player" end
        if atk == true or fr == false then return "hostile-player" end
        return "?"
    end
    if atk == true then return "hostile-npc" end
    if fr == true then return "friendly-npc" end
    if fr == false and atk == false then return "neutral-npc" end
    return "?"
end
ID.LinkClass = linkClass

local function fingerprint(v)
    local cls, lvl, hp, isP, fr = v.UnitClass, v.UnitLevel, v.UnitHealthMax, v.UnitIsPlayer, v.UnitIsFriend
    if cls == nil or lvl == nil or hp == nil or isP == nil then return nil end
    return table.concat({ tostring(cls), tostring(lvl), tostring(hp), isP and "P" or "N", fr == true and "F" or (fr == false and "H" or "?") }, ":")
end
ID.Fingerprint = fingerprint

local function db()
    local log = rawget(_G, "ForeverDumpLogDB")
    if type(log) ~= "table" then return nil end
    log.identity = type(log.identity) == "table" and log.identity or { v = 1 }
    local d = log.identity
    d.chains = d.chains or {}
    d.res = d.res or {}
    return d
end
ID.DB = db

ID.state = {}       -- [token] = { guid = <in memory only>, how = live|alias|fingerprint|cached|none, conf, t, link }
local last = {}     -- [token] = time of last read (per-token throttle)
local ticker, frame
local exists = {}   -- chained tokens that existed at the last check

local function survey(ctx, tok, comp, c)
    local d = db()
    if not d then return end
    d.chains[ctx] = d.chains[ctx] or {}
    local byTok = d.chains[ctx][tok] or {}
    d.chains[ctx][tok] = byTok
    local r = byTok[comp]
    if not r then r = { n = 0, sig = {} } byTok[comp] = r end
    r.n = r.n + 1
    for name, k in pairs(c) do
        local s = r.sig[name]
        if not s then s = {} r.sig[name] = s end
        s[k] = (s[k] or 0) + 1
    end
end

local function resolved(how)
    local d = db()
    if d then d.res[how] = (d.res[how] or 0) + 1 end
end

-- read one token now; links = already-read values of its chain links (for the composition)
function ID.Observe(tok, src, linkVals)
    local L = ledger()
    local res = call("UnitExists", tok)
    local ex = res and clear(res[2])
    if ex ~= true then
        if L and ex == false then L:Invalidate("token", tok) end
        if ID.state[tok] then ID.state[tok] = nil dirty() end
        exists[tok] = nil
        return nil
    end
    last[tok] = now()
    local v, c = read(tok)
    local st = { t = last[tok], link = linkClass(v), codes = c, fp = fingerprint(v) }
    local guid = v.UnitGUID
    if guid then
        st.guid, st.how, st.conf = guid, "live", "live"
        if L then
            L:Put("token", tok, { guid = guid }, src)
            L:Put("guid", guid, { name = v.UnitName, class = v.UnitClass, level = v.UnitLevel, hpMax = v.UnitHealthMax,
                powerMax = v.UnitPowerMax, isPlayer = v.UnitIsPlayer, friend = v.UnitIsFriend, link = st.link, token = tok }, src)
            L:PutFingerprint(fingerprint(v), guid)
            local Lib = rawget(_G, "HybridState")
            local nk = Lib and Lib.NpcKey and Lib.NpcKey(guid)
            if nk and nk:find("^npc:") and ns.Verify and (L.data.guid[guid].first == L.data.guid[guid].t) then
                ns.Verify.Unexpected("new-npc", nk)   -- new data found (npc id only)
            end
            if tok:find("^nameplate") then L:Put("plate", tok, { guid = guid }, src) end
            if ns.ReplayLog and ns.ReplayLog.IsTest() then
                local ge = L.data.guid and L.data.guid[guid]
                if ge and ge.first == ge.t then
                    local kind = (v.UnitIsPlayer == true and "player")
                        or (type(guid) == "string" and guid:find("^Creature%-") and "npc")
                        or (type(guid) == "string" and guid:find("^Pet%-") and "pet")
                        or "guid"
                    local idk = ns.ReplayLog.IdKey(kind, guid)   -- v2.2.21: raw kind:<GUID> (was "player" for every player)
                    ns.ReplayLog.OnMapDelta(tok, idk, "live", guid)
                end
            end
        end
    elseif L then
        -- secret GUID: alias through a clear comparison, then fingerprint, then the last clear mapping
        local alias = (v["UnitIsUnit(player)"] == true and "player") or (v["UnitIsUnit(target)"] == true and tok ~= "target" and "target") or nil
        local e = alias and L.data.token and L.data.token[alias]
        if alias == "player" then
            local pe = L.data.token and L.data.token.player
            st.guid, st.how, st.conf = pe and pe.guid or "player", "alias", "high"
        elseif e and e.guid then st.guid, st.how, st.conf = e.guid, "alias", "high"
        else
            local fg, fconf = L:Fingerprint(fingerprint(v))
            if fg then st.guid, st.how, st.conf = fg, "fingerprint", fconf
            else
                local ce, cconf = L:Get("token", tok)
                if ce and ce.guid then st.guid, st.how, st.conf = ce.guid, "cached", cconf == "cached-fresh" and "medium" or "low"
                else st.how, st.conf = "none", "none" end
            end
        end
    end
    resolved(st.how or "none")
    -- secrecy survey per chain composition (codes only)
    local chain = CHAINS[tok]
    local comp
    if chain then
        local parts = {}
        for i, link in ipairs(chain) do
            local lv = linkVals and linkVals[link]
            if link == tok then lv = v end
            parts[i] = lv and linkClass(lv) or "?"
        end
        comp = table.concat(parts, ">")
    else comp = st.link end
    st.comp = comp
    survey(ctxName(), tok, comp, c)
    local prev = ID.state[tok]
    ID.state[tok] = st
    if CHAINS[tok] then exists[tok] = true end
    if not prev or prev.guid ~= st.guid or prev.how ~= st.how then dirty() end
    return v
end

-- read a base unit and its chained tokens in order (links first); throttle = per-token minimum interval
local function observeFamily(base, src, force)
    local list = BY_BASE[base] or { base }
    local vals = {}
    local t, minGap = now(), tonumber(cfg().minInterval) or 0.25
    for _, tok in ipairs(list) do
        if force or not last[tok] or t - last[tok] >= minGap then
            vals[tok] = ID.Observe(tok, src, vals)
        end
    end
end

-- collect while available: out of combat the auras of player/target are clear -> ledger (auraInstanceID -> spellId)
function ID.ScanAuras(unit, src)
    local h = hs()
    if not h or ns.InCombat() or cfg().auraScan == false then return 0 end
    local ua = g("C_UnitAuras")
    if type(ua) ~= "table" or type(ua.GetAuraDataByIndex) ~= "function" then return 0 end
    local key = ns.Inference.KeyOf(unit)
    local n = 0
    for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
        for i = 1, 40 do
            local held, ok, rawA
            if ns.AuraGate then
                held, ok, rawA = ns.AuraGate.Call("GetAuraDataByIndex", "id:" .. (unit:gsub("%d+$", "N")), ua.GetAuraDataByIndex, unit, i, filter)
            else held, ok, rawA = false, pcall(ua.GetAuraDataByIndex, unit, i, filter) end
            if held then break end
            local a = ok and ns.ClearTable(rawA) or nil
            if not a then break end
            local iid, spell = clear(a.auraInstanceID), clear(a.spellId)
            if iid and spell then
                h:RecordAura(key, { iid = iid, spellId = spell, duration = clear(a.duration), expirationTime = clear(a.expirationTime),
                    helpful = filter == "HELPFUL", fromPlayer = clear(a.isFromPlayerOrPlayerPet) }, "scan:" .. (src or "?"))
                n = n + 1
            end
        end
    end
    return n
end

local function anyChain()
    for tok in pairs(CHAINS) do
        local res = call("UnitExists", tok)
        if res and clear(res[2]) == true then return true end
    end
    return false
end

local function stopTicker() if ticker and ticker.Cancel then ticker:Cancel() end ticker = nil end
-- 1 Hz poll of chained tokens, only while one exists (no idle timer)
local function ensureTicker()
    if ticker or not (type(g("C_Timer")) == "table" and C_Timer.NewTicker) then return end
    if not anyChain() then return end
    ticker = C_Timer.NewTicker(tonumber(cfg().pollInterval) or 1, function()
        local function step()
            local any = false
            for base, list in pairs(BY_BASE) do
                if base ~= "player" then
                    for i = 2, #list do
                        if exists[list[i]] or (i == 2 and ID.state[base]) then any = true observeFamily(base, "poll") break end
                    end
                end
            end
            if not any and not anyChain() then stopTicker() end
        end
        if ns.Perf then ns.Perf.Run("Identity.poll", step) else pcall(step) end
    end)
end

function ID.OnEvent(event, rawA1)
    local a1 = ns.ClearStr(rawA1)   -- v2.2.7: event payloads are API values; unit tokens are used only when clear
    if event == "PLAYER_TARGET_CHANGED" then
        local L = ledger()
        if L then L:Invalidate("token", "target") L:Invalidate("token", "targettarget") L:Invalidate("token", "targettargettarget") end
        observeFamily("target", event, true)
        if not ns.InCombat() then ID.ScanAuras("target", "target") end
    elseif event == "PLAYER_FOCUS_CHANGED" then
        local L = ledger()
        if L then L:Invalidate("token", "focus") L:Invalidate("token", "focustarget") end
        observeFamily("focus", event, true)
    elseif event == "UNIT_TARGET" then
        if type(a1) == "string" and BY_BASE[a1] then
            local L = ledger()
            local list = BY_BASE[a1]
            if L then for i = (a1 == "player") and 1 or 2, #list do L:Invalidate("token", list[i]) end end
            observeFamily(a1, event, false)
        end
    elseif event == "UNIT_PET" then if a1 == "player" then observeFamily("pet", event, true) end
    elseif event == "GROUP_ROSTER_UPDATE" then for i = 1, 4 do observeFamily("party" .. i, event, true) end
    elseif event == "NAME_PLATE_UNIT_ADDED" then if type(a1) == "string" then ID.Observe(a1, event) end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local L = ledger()
        if type(a1) == "string" and L then L:Remove("plate", a1) L:Invalidate("token", a1) end
        ID.state[a1 or ""] = nil
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        -- context flips: re-read everything once (out of combat: refresh identities + aura scan while clear)
        for _, b in ipairs(BASES) do observeFamily(b, event, true) end
        if event == "PLAYER_REGEN_ENABLED" then ID.ScanAuras("player", "regen") ID.ScanAuras("target", "regen") end
    end
    ensureTicker()
end

function ID.Start()
    if cfg().enabled == false or not hs() then return false end
    local d = db()
    if d then d.sid = ns.SessionId and ns.SessionId() or nil end
    for k in pairs(ID.state) do ID.state[k] = nil end
    for k in pairs(last) do last[k] = nil end
    for k in pairs(exists) do exists[k] = nil end
    if not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", function(_, event, a1)
            local ok, err
            if ns.Perf then ok, err = ns.Perf.Run(ns.Perf.Key("Identity", event), ID.OnEvent, event, a1)
            else ok, err = pcall(ID.OnEvent, event, a1) end
            if not ok and ns.NoteSelfError then ns.NoteSelfError("Identity." .. event, err) end
        end)
    end
    for _, ev in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_TARGET", "UNIT_PET", "GROUP_ROSTER_UPDATE",
        "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
        pcall(frame.RegisterEvent, frame, ev)
    end
    for _, b in ipairs(BASES) do observeFamily(b, "start", true) end
    ID.ScanAuras("player", "start")
    ID.ScanAuras("target", "start")
    ensureTicker()
    if ns.Perf then
        ns.Perf.Size("identity.state", function() local n = 0 for _ in pairs(ID.state) do n = n + 1 end return n end, 80)
    end
    return true
end

function ID.Stop()
    if frame then pcall(frame.UnregisterAllEvents, frame) end
    stopTicker()
    local d = db()
    local L = ledger()
    if d and L then d.ledger = L:Export() end
    local n = 0
    for _ in pairs(ID.state) do n = n + 1 end
    return n
end

ns.captureModules = ns.captureModules or {}
ns.captureModules[#ns.captureModules + 1] = { name = "identity ledger (token/GUID correlation)", start = function() return ID.Start() end,
    stop = function()
        local n = ID.Stop()
        local L = ledger()
        return L and string.format("ledger: %d identities, %d token maps, %d aura instances (%d token(s) live at stop)",
            L:Count("guid"), L:Count("token"), L:Count("aura"), n or 0) or nil
    end }
