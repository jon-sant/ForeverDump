-- ForeverDump v2.2 - combat probe set + detectability layer.
-- Runs automatically during an FD_Logs capture: at ON (out of combat), at combat start, on restriction flips, on
-- target changes and when a probed unit starts casting (all throttled, bounded). For every unit class
-- (player, target:hostile-npc, target:friendly-player, party:..., nameplate:..., pet, focus, mouseover, targettarget)
-- and every item (health, power, casting, movement, identity, auras, dispels, threat/range/markers, damage meter):
-- the five-state code per return / struct field (N nil, S secret, T container w/ secrets, K container clear, C clear,
-- E error), the documented expectation from the 70245 docs and the matching C_Secrets.Should* result. Only codes,
-- counts and booleans are stored - never values. Missing APIs are recorded as absent (runtime or undocumented).
-- Detectability answers (yes / partial / no / n/a) per unit class x context for: casting?, which spell?, any aura?,
-- my aura?, what aura?, stacks/duration?, dispellable? - with the evidence codes that decided it.
local _, ns = ...
local CP = {}
ns.CombatProbe = CP

local function g(n) return rawget(_G, n) end
local function code(v) return ns.ClassifyValue(v) end
local function isClear(v) local c = code(v) return c == "C" or c == "K" end
local function fn(path) local f = ns.Resolve(path) return type(f) == "function" and f or nil end
local function cfg() return (ns.config and ns.config.combatProbe) or {} end
local function capturing() return ns.db and ns.db.logs and ns.db.logs.on and ns.db.logs.session ~= nil end

-- context: enc / combat / restricted (a restriction Active out of combat) / ooc
-- v2.2.3: cached per frame (GetTime() is constant within a frame); Inference called this ~10x per UNIT_AURA (6 pcalls each)
local ctxT, ctxV
function CP.InvalidateContext() ctxT = nil end
function CP.Context()
    local t = (g("GetTime") or os.clock)()
    if ctxT == t and ctxV then return ctxV end
    ctxV = CP.ContextNow()
    ctxT = t
    return ctxV
end
function CP.ContextNow()
    if ns.Secrets and ns.Secrets.InEncounter and ns.Secrets.InEncounter() then return "enc" end
    if ns.InCombat() then return "combat" end
    local cra = g("C_RestrictedActions")
    if type(cra) == "table" and type(cra.GetAddOnRestrictionState) == "function" then
        for t = 0, 5 do
            local ok, st = pcall(cra.GetAddOnRestrictionState, t)
            if ok and not ns.IsSecret(st) and st == 2 then return "restricted" end
        end
    end
    return "ooc"
end

local function family(tok) return (tok:gsub("%d+", "")) end

-- unit class from readable facts only; "?" parts when the fact itself is secret
function CP.UnitClass(tok)
    if tok == "player" then return "player" end
    local fam = family(tok)
    local ue = fn("UnitExists")
    local ok, ex = pcall(ue or function() return nil end, tok)
    if not ok then return nil end
    if ns.IsSecret(ex) then return fam .. ":unknown" end
    if not ex then return nil end
    local function b(path, ...)
        local f = fn(path)
        if not f then return nil end
        local okB, v = pcall(f, ...)
        if not okB or ns.IsSecret(v) then return "?" end
        return v and true or false
    end
    if b("UnitIsUnit", tok, "player") == true then return fam .. ":self" end
    local atk, isP = b("UnitCanAttack", "player", tok), b("UnitIsPlayer", tok)
    local rel = (atk == "?" and "?") or (atk and "hostile" or "friendly")
    local kind = (isP == "?" and "?") or (isP and "player" or "npc")
    return fam .. ":" .. rel .. "-" .. kind
end

-- probe items: { id, path, args(u) , names (return names), unitless, cat }
local AURA_FILTERS = { "HELPFUL", "HARMFUL", "HELPFUL|PLAYER", "HARMFUL|PLAYER", "HARMFUL|RAID", "HARMFUL|RAID_PLAYER_DISPELLABLE" }
CP.AURA_FILTERS = AURA_FILTERS
local CAST_NAMES = { "name", "text", "texture", "startTimeMS", "endTimeMS", "isTradeSkill", "castID", "notInterruptible", "spellID" }
local CHAN_NAMES = { "name", "text", "texture", "startTimeMS", "endTimeMS", "isTradeSkill", "notInterruptible", "spellID" }
local function U(u) return u end
local ITEMS = {
    { "UnitHealth", "UnitHealth", U, nil, nil, "health" }, { "UnitHealthMax", "UnitHealthMax", U, nil, nil, "health" },
    { "UnitHealthPercent", "UnitHealthPercent", U, nil, nil, "health" }, { "UnitGetIncomingHeals", "UnitGetIncomingHeals", U, nil, nil, "health" },
    { "UnitGetTotalAbsorbs", "UnitGetTotalAbsorbs", U, nil, nil, "health" },
    { "UnitGetTotalHealAbsorbs", "UnitGetTotalHealAbsorbs", U, nil, nil, "health" },
    { "UnitIsDeadOrGhost", "UnitIsDeadOrGhost", U, nil, nil, "health" },
    { "UnitPower", "UnitPower", U, nil, nil, "power" }, { "UnitPowerMax", "UnitPowerMax", U, nil, nil, "power" },
    { "UnitPowerType", "UnitPowerType", U, { "powerType", "powerToken" }, nil, "power" },
    { "UnitCastingInfo", "UnitCastingInfo", U, CAST_NAMES, nil, "casting" },
    { "UnitChannelInfo", "UnitChannelInfo", U, CHAN_NAMES, nil, "casting" },
    { "UnitCastingDuration", "UnitCastingDuration", U, nil, nil, "casting" },
    { "UnitChannelDuration", "UnitChannelDuration", U, nil, nil, "casting" },
    { "UnitSpellTargetName", "UnitSpellTargetName", U, nil, nil, "casting" },
    { "UnitSpellTargetClass", "UnitSpellTargetClass", U, nil, nil, "casting" },
    { "GetUnitSpeed", "GetUnitSpeed", U, { "current", "run", "flight", "swim" }, nil, "movement" },
    { "IsFalling", "IsFalling", function() return end, nil, true, "movement" },
    { "IsFlying", "IsFlying", function() return end, nil, true, "movement" },
    { "IsSwimming", "IsSwimming", function() return end, nil, true, "movement" },
    { "UnitPosition", "UnitPosition", U, { "x", "y", "z", "mapID" }, nil, "movement" },
    { "GetPlayerFacing", "GetPlayerFacing", function() return end, nil, true, "movement" },
    { "C_Map.GetPlayerMapPosition", "C_Map.GetPlayerMapPosition", function(u)
        local f = fn("C_Map.GetBestMapForUnit")
        local ok, m = pcall(f or function() return nil end, "player")
        return (ok and isClear(m)) and m or 0, u
    end, nil, nil, "movement" },
    { "UnitName", "UnitName", U, { "name", "realm" }, nil, "identity" },
    { "UnitFullName", "UnitFullName", U, { "name", "realm" }, nil, "identity" },
    { "UnitGUID", "UnitGUID", U, nil, nil, "identity" },
    { "UnitClass", "UnitClass", U, { "className", "classFile", "classID" }, nil, "identity" },
    { "UnitRace", "UnitRace", U, { "raceName", "raceFile", "raceID" }, nil, "identity" },
    { "UnitLevel", "UnitLevel", U, nil, nil, "identity" },
    { "UnitIsUnit(u,player)", "UnitIsUnit", function(u) return u, "player" end, nil, nil, "identity" },
    { "UnitIsPlayer", "UnitIsPlayer", U, nil, nil, "identity" }, { "UnitExists", "UnitExists", U, nil, nil, "identity" },
    { "UnitCanAttack", "UnitCanAttack", function(u) return "player", u end, nil, nil, "identity" },
    { "UnitReaction", "UnitReaction", function(u) return u, "player" end, nil, nil, "identity" },
    { "UnitIsFriend", "UnitIsFriend", function(u) return "player", u end, nil, nil, "identity" },
    { "UnitIsEnemy", "UnitIsEnemy", function(u) return "player", u end, nil, nil, "identity" },
    { "CanCompareUnitTokens", "C_Secrets.CanCompareUnitTokens", function(u) return u, "player" end, nil, nil, "identity" },
    { "ShouldUnitIdentityBeSecret", "C_Secrets.ShouldUnitIdentityBeSecret", U, nil, nil, "identity" },
    { "UnitThreatSituation", "UnitThreatSituation", function(u) return "player", u end, nil, nil, "other" },
    { "UnitDetailedThreatSituation", "UnitDetailedThreatSituation", function(u) return "player", u end,
        { "isTanking", "status", "scaledPct", "rawPct", "rawThreat" }, nil, "other" },
    { "UnitAffectingCombat", "UnitAffectingCombat", U, nil, nil, "other" },
    { "UnitInRange", "UnitInRange", U, { "inRange", "checked" }, nil, "other" },
    { "CheckInteractDistance", "CheckInteractDistance", function(u) return u, 4 end, nil, nil, "other" },
    { "C_Spell.IsSpellInRange", "C_Spell.IsSpellInRange", function(u) return 6603, u end, nil, nil, "other" },
    { "GetRaidTargetIndex", "GetRaidTargetIndex", U, nil, nil, "other" },
}
CP.ITEMS = ITEMS

-- documented class + tag + same-frame predicate for an API
local function docOf(path, args)
    local S = ns.Secrets
    local row = S and S.DocRow and S.DocRow("api:" .. path)
    if not row then return nil, nil, nil end
    local cls = row[1] or row.parent or "unspecified"
    local pred
    if row.tag and S.Predicate then pred = S.Predicate(row.tag, args) end
    return cls, row.tag, pred
end

local function docsLoaded()
    local d = g("ForeverDumpDocsDB")
    return type(d) == "table" and type(d.systems) == "table" and #d.systems > 0
end

local function db()
    local log = g("ForeverDumpLogDB")
    if type(log) ~= "table" then return nil end
    log.combatProbe = log.combatProbe or { v = 1, cells = {}, det = {}, absent = {}, ops = {}, runs = {}, events = {}, timeLeft = {} }
    return log.combatProbe
end
CP.DB = db

local function bump(t, k) t[k] = (t[k] or 0) + 1 end
local function cellOf(d, ctx, ucls, item)
    d.cells[ctx] = d.cells[ctx] or {}
    d.cells[ctx][ucls] = d.cells[ctx][ucls] or {}
    local c = d.cells[ctx][ucls][item]
    if not c then
        d.nCells = (d.nCells or 0) + 1
        if d.nCells > (tonumber(cfg().maxCells) or 4000) then d.dropped = (d.dropped or 0) + 1 return nil end
        c = { n = 0, r = {} }
        d.cells[ctx][ucls][item] = c
    end
    return c
end

-- record one call outcome into a cell; returns the raw packed result for local use (never stored)
-- v2.2.2: APIs that raise ADDON_ACTION_BLOCKED from addon code in combat. Run 3 (live): 36 blocks "UNKNOWN()", exactly one
-- per friendly/self unit class per in-combat run and never for hostile units, from this record() call (taint.log stack
-- CombatProbe.lua:163 <- :412). That matches CheckInteractDistance: protected in combat for insecure code since the
-- 2023-11-16 hotfix, enemy units unrestricted again on 2023-12-11 (warcraft.wiki.gg/wiki/API_CheckInteractDistance); it was
-- also the only ITEMS path still returning a value (false) while blocked. "nonhostile" = skipped in combat unless the unit
-- is attackable. Paths learned from a real block (ns.LearnBlocked) and docs rows tagged protected/restricted are skipped too.
local COMBAT_SKIP = { CheckInteractDistance = "nonhostile" }
CP.COMBAT_SKIP = COMBAT_SKIP
local function inLockdown()
    local il = g("InCombatLockdown")
    local ok, v = pcall(il or function() return false end)
    return (ok and v == true) or (ns.InCombat and ns.InCombat()) or false
end
local function hostile(unit)
    if type(unit) ~= "string" then return false end
    local uca = g("UnitCanAttack")
    local ok, v = pcall(uca or function() return false end, "player", unit)
    return ok and not ns.IsSecret(v) and v == true
end
local function combatSkip(path, unit)
    local rule = COMBAT_SKIP[path]
    if rule == "nonhostile" and not hostile(unit) then return "protected in combat for non-hostile units (ADDON_ACTION_BLOCKED, run 3)" end
    if ns.PathBlocked and ns.PathBlocked(path) then return "learned: ADDON_ACTION_BLOCKED" end
    local row = ns.Secrets and ns.Secrets.DocRow and ns.Secrets.DocRow("api:" .. path)
    local tag = type(row) == "table" and type(row.tag) == "string" and row.tag or ""
    if tag:find("Protected") or tag:find("HasRestrictions") or tag:find("RequiresNonCombat") then return "docs: " .. tag end
end
CP.CombatSkip = combatSkip
local function record(d, ctx, ucls, item, path, ...)
    local f = fn(path)
    if not f or (docsLoaded() and not (ns.Secrets and ns.Secrets.DocRow and ns.Secrets.DocRow("api:" .. path))) then
        d.absent[path] = f and "undocumented" or "runtime"
        return nil
    end
    if inLockdown() then
        local why = combatSkip(path, CP.curUnit)
        if why then
            d.skipped = d.skipped or {}
            d.skipped[path] = why
            return nil
        end
    end
    local c = cellOf(d, ctx, ucls, item)
    if ns.ProbeMark then ns.ProbeMark("CombatProbe", path, CP.curUnit) end
    local res = ns.Pack(pcall(f, ...))
    if ns.ProbeDone then ns.ProbeDone() end
    if not c then return res end
    c.n = c.n + 1
    if not res[1] then
        c.e = (c.e or 0) + 1
        if not c.err then local e = res[2] c.err = ns.IsSecret(e) and "<secret error>" or tostring(e):sub(1, 140) end
        return res
    end
    local names = item.names
    local cnt = math.max(res.n - 1, 1)
    for i = 1, math.min(cnt, 12) do
        local v = res[i + 1]
        local key = (names and names[i]) or i
        c.r[key] = c.r[key] or {}
        local st = code(v)
        bump(c.r[key], st)
        if st == "T" or st == "K" then
            local fs = ns.ClassifyFields(v)
            if fs then
                c.f = c.f or {}
                local nf = 0
                for k, fc in pairs(fs) do
                    nf = nf + 1
                    if nf > 32 then break end
                    c.f[k] = c.f[k] or {}
                    bump(c.f[k], fc)
                end
            end
            if type(v) == "table" or type(v) == "userdata" then
                local okH, hm = pcall(function() return v.HasSecretValues end)
                if okH and type(hm) == "function" then
                    local okR, hv = pcall(hm, v)
                    c.hsv = c.hsv or {}
                    bump(c.hsv, okR and (ns.IsSecret(hv) and "S" or tostring(hv == true)) or "E")
                end
            end
        end
    end
    if not c.doc then
        local cls, tag, _ = docOf(path)
        c.doc = cls and (cls .. (tag and (":" .. tag) or "")) or "undocumented"
    end
    local _, tag, pred = docOf(path, ns.Pack(...))
    if tag and pred ~= nil then c.p = c.p or {} bump(c.p, pred and "t" or "f") end
    return res
end
CP.record = function(...) return record(...) end

local function rv(res, i) return res and res[1] and res[i + 1] or nil end

-- duration object: HasSecretValues + remaining-time methods (codes only)
local function durationCodes(d)
    local out = { state = code(d) }
    if d == nil or out.state == "S" then return out end
    for _, m in ipairs({ "HasSecretValues", "GetRemainingDuration", "GetTotalDuration", "GetRemainingPercent", "IsZero" }) do
        local okM, f = pcall(function() return d[m] end)
        if okM and type(f) == "function" then local okR, v = pcall(f, d) out[m] = okR and code(v) or "E" else out[m] = "absent" end
    end
    return out
end

local function detBump(d, ctx, ucls, q, ans, ev)
    d.det[ctx] = d.det[ctx] or {}
    d.det[ctx][ucls] = d.det[ctx][ucls] or {}
    local r = d.det[ctx][ucls][q]
    if not r then r = {} d.det[ctx][ucls][q] = r end
    bump(r, ans)
    if ev then r.ev = ev end
end

-- auras for one unit: every filter x API + detectability
-- GetAuraDispelTypeColor(unit, auraInstanceID, curve) needs a color curve (live usage error without it)
function CP.DispelCurve()
    if CP.curve ~= nil then return CP.curve or nil end
    local cu = g("C_CurveUtil")
    local ok, c = pcall(function() return cu and cu.CreateColorCurve and cu.CreateColorCurve() end)
    CP.curve = (ok and c) or false
    return CP.curve or nil
end
local function auraProbe(d, ctx, ucls, u)
    local fieldCodes = {}
    local present = {}
    for _, filter in ipairs(AURA_FILTERS) do
        local resI = record(d, ctx, ucls, "aura:GetAuraDataByIndex[" .. filter .. "]", "C_UnitAuras.GetAuraDataByIndex", u, 1, filter)
        local a = rv(resI, 1)
        present[filter] = (resI and resI[1]) and ((a ~= nil) and "yes" or "none") or "err"
        if type(a) == "table" and code(a) ~= "S" then
            local fs = ns.ClassifyFields(a) or {}
            fieldCodes[filter] = fs
            local iid = a.auraInstanceID
            if isClear(iid) then
                record(d, ctx, ucls, "aura:GetAuraDataByAuraInstanceID[" .. filter .. "]", "C_UnitAuras.GetAuraDataByAuraInstanceID", u, iid)
                local resD = record(d, ctx, ucls, "aura:GetAuraDuration[" .. filter .. "]", "C_UnitAuras.GetAuraDuration", u, iid)
                local dc = durationCodes(rv(resD, 1))
                d.durations = d.durations or {}
                d.durations[ctx .. "|" .. ucls .. "|" .. filter] = dc
                local curve = CP.DispelCurve()
                if curve then
                    record(d, ctx, ucls, "aura:GetAuraDispelTypeColor[" .. filter .. "]", "C_UnitAuras.GetAuraDispelTypeColor", u, iid, curve)
                end
                record(d, ctx, ucls, "aura:GetAuraApplicationDisplayCount[" .. filter .. "]", "C_UnitAuras.GetAuraApplicationDisplayCount", u, iid)
            end
        end
        local resS = record(d, ctx, ucls, "aura:GetAuraSlots[" .. filter .. "]", "C_UnitAuras.GetAuraSlots", u, filter)
        local slot = rv(resS, 2)
        if isClear(slot) and type(slot) == "number" then
            record(d, ctx, ucls, "aura:GetAuraDataBySlot[" .. filter .. "]", "C_UnitAuras.GetAuraDataBySlot", u, slot)
        end
        record(d, ctx, ucls, "aura:GetUnitAuras[" .. filter .. "]", "C_UnitAuras.GetUnitAuras", u, filter)
        -- slot count readability (number of returns): n-1 slots when the returns are clear
        if resS and resS[1] then
            d.slotCounts = d.slotCounts or {}
            local key = ctx .. "|" .. ucls .. "|" .. filter
            -- returns: continuationToken (nilable), slot1, slot2, ...
            local allClear = resS[2] == nil or isClear(resS[2])
            for i = 3, resS.n do if not isClear(resS[i]) then allClear = false end end
            d.slotCounts[key] = d.slotCounts[key] or {}
            bump(d.slotCounts[key], allClear and "readable" or "secret")
        end
    end
    -- player-only: GetPlayerAuraBySpellID using a clear spellId from the first self buff
    if u == "player" then
        local fs = fieldCodes["HELPFUL"]
        local okA, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", 1, "HELPFUL")
        if fs and okA and type(a) == "table" and isClear(a.spellId) then
            record(d, ctx, ucls, "aura:GetPlayerAuraBySpellID", "C_UnitAuras.GetPlayerAuraBySpellID", a.spellId)
            record(d, ctx, ucls, "aura:ShouldSpellAuraBeSecret", "C_Secrets.ShouldSpellAuraBeSecret", a.spellId)
            record(d, ctx, ucls, "aura:GetSpellAuraSecrecy", "C_Secrets.GetSpellAuraSecrecy", a.spellId)
        end
    end
    -- detectability (A): any / mine / what / stacks+duration / dispellable
    local function readable(fs, ...) local n, c = 0, 0 for _, k in ipairs({ ... }) do n = n + 1 if fs and fs[k] == "C" then c = c + 1 end end return c, n end
    local slotKey = function(f) local s = d.slotCounts and d.slotCounts[ctx .. "|" .. ucls .. "|" .. f] return s and (s.readable or 0) > 0 end
    for _, pair in ipairs({ { "anyAura", "HELPFUL", "HARMFUL" }, { "myAura", "HELPFUL|PLAYER", "HARMFUL|PLAYER" } }) do
        local q, f1, f2 = pair[1], pair[2], pair[3]
        local ans, ev
        if slotKey(f1) and slotKey(f2) then ans, ev = "yes", "GetAuraSlots counts readable"
        elseif present[f1] ~= "err" and present[f2] ~= "err" then
            ans, ev = "partial", "GetAuraDataByIndex nil-check only (" .. present[f1] .. "/" .. present[f2] .. ")"
        else ans, ev = "no", "aura APIs error" end
        if q == "myAura" then
            local fsm = fieldCodes[f1] or fieldCodes[f2]
            if fsm and fsm.isFromPlayerOrPlayerPet == "C" and ans ~= "yes" then ans, ev = "yes", "isFromPlayerOrPlayerPet clear" end
        end
        detBump(d, ctx, ucls, q, ans, ev)
    end
    local any = fieldCodes["HELPFUL"] or fieldCodes["HARMFUL"]
    if any then
        local c, n = readable(any, "spellId", "name", "icon")
        detBump(d, ctx, ucls, "whatAura", (c == n and "yes") or (c > 0 and "partial") or "no",
            "spellId=" .. tostring(any.spellId) .. " name=" .. tostring(any.name) .. " icon=" .. tostring(any.icon))
        local cs, ns2 = readable(any, "applications", "duration", "expirationTime")
        local dc = d.durations and (d.durations[ctx .. "|" .. ucls .. "|HELPFUL"] or d.durations[ctx .. "|" .. ucls .. "|HARMFUL"])
        local ans = (cs == ns2 and "yes") or ((cs > 0 or (dc and dc.state ~= "N")) and "partial") or "no"
        detBump(d, ctx, ucls, "stacksDuration", ans, "applications=" .. tostring(any.applications) .. " duration=" .. tostring(any.duration)
            .. " durObj=" .. tostring(dc and dc.state))
    else
        detBump(d, ctx, ucls, "whatAura", "n/a") detBump(d, ctx, ucls, "stacksDuration", "n/a")
    end
    local harm = fieldCodes["HARMFUL"]
    if harm then
        local disp = present["HARMFUL|RAID_PLAYER_DISPELLABLE"]
        detBump(d, ctx, ucls, "dispellable", harm.dispelName == "C" and "yes" or ((disp == "yes" or disp == "none") and "partial" or "no"),
            "dispelName=" .. tostring(harm.dispelName) .. " dispellableFilter=" .. tostring(disp))
    else detBump(d, ctx, ucls, "dispellable", "n/a") end
end

-- casting + detectability: casting? which spell? time left (derived vs duration object)
local function castProbe(d, ctx, ucls, u)
    local ci = record(d, ctx, ucls, ITEMS._byId.UnitCastingInfo, "UnitCastingInfo", u)
    local ch = record(d, ctx, ucls, ITEMS._byId.UnitChannelInfo, "UnitChannelInfo", u)
    local active, res, names = nil, nil, nil
    if ci and ci[1] and ci.n > 1 and ci[2] ~= nil then active, res, names = "cast", ci, CAST_NAMES
    elseif ch and ch[1] and ch.n > 1 and ch[2] ~= nil then active, res, names = "channel", ch, CHAN_NAMES end
    if not (ci and ci[1]) and not (ch and ch[1]) then detBump(d, ctx, ucls, "casting", "no", "UnitCastingInfo/UnitChannelInfo error")
    elseif active then detBump(d, ctx, ucls, "casting", "yes", active .. " (non-nil return)")
    else detBump(d, ctx, ucls, "casting", "yes", "idle (nil return is readable)") end
    if active then
        local idx = {}
        for i, nm in ipairs(names) do idx[nm] = res[i + 1] end
        local sc, nc, tc = code(idx.spellID), code(idx.name), code(idx.texture)
        detBump(d, ctx, ucls, "whichSpell", (sc == "C" and "yes") or ((nc == "C" or tc == "C") and "partial") or "no",
            "spellID=" .. sc .. " name=" .. nc .. " texture=" .. tc .. " notInterruptible=" .. code(idx.notInterruptible))
        if sc == "C" then record(d, ctx, ucls, "casting:GetSpellCastSecrecy", "C_Secrets.GetSpellCastSecrecy", idx.spellID) end
        -- cast time left: endTimeMS - GetTime()*1000 (blocked when endTimeMS is secret) vs duration object
        local okT, errT, leftState
        if ns.Controls and ns.Controls.TryTimeLeft then okT, errT, leftState = ns.Controls.TryTimeLeft(idx.endTimeMS) end
        local durRes = record(d, ctx, ucls, ITEMS._byId[active == "cast" and "UnitCastingDuration" or "UnitChannelDuration"],
            active == "cast" and "UnitCastingDuration" or "UnitChannelDuration", u)
        local tl = { kind = active, derivedOk = okT, derivedErr = errT, derivedState = leftState, endTimeState = code(idx.endTimeMS),
            duration = durationCodes(rv(durRes, 1)) }
        d.timeLeft[ctx .. "|" .. ucls] = tl
    else
        detBump(d, ctx, ucls, "whichSpell", "n/a")
    end
end

-- operations matrix on representative values per category (one per context per capture)
local function opsFor(d, ctx, cat, v)
    if v == nil or not (ns.Controls and ns.Controls.OpsFor) then return end
    d.ops[ctx] = d.ops[ctx] or {}
    if d.ops[ctx][cat] then return end
    local ok, r = pcall(ns.Controls.OpsFor, v, false)
    if ok then d.ops[ctx][cat] = r end
end

local function units()
    local out = { "player", "target", "targettarget", "focus", "pet", "mouseover" }
    for i = 1, 4 do out[#out + 1] = "party" .. i end
    for i = 1, 2 do out[#out + 1] = "raid" .. i end
    out[#out + 1] = "boss1"
    local n, ue = 0, fn("UnitExists")
    -- v2.2.25: arena opponents when present (arena env; was never probed)
    for i = 1, 5 do
        local tok = "arena" .. i
        local ok, ex = pcall(ue or function() return nil end, tok)
        if ok and (ns.IsSecret(ex) or ex) then out[#out + 1] = tok end
    end
    for i = 1, 40 do
        local tok = "nameplate" .. i
        local ok, ex = pcall(ue or function() return nil end, tok)
        if ok and (ns.IsSecret(ex) or ex) then out[#out + 1] = tok n = n + 1 end
        if n >= (tonumber(cfg().nameplates) or 3) then break end
    end
    return out
end

local idx = {}
for _, it in ipairs(ITEMS) do it.id, it.path, it.args, it.names, it.unitless, it.cat = it[1], it[2], it[3], it[4], it[5], it[6] idx[it.id] = it end
ITEMS._byId = idx
-- item keys in cells are the item ids
local function key(it) return type(it) == "table" and it.id or it end
local recordRaw = record
record = function(d, ctx, ucls, it, path, ...)
    local k = key(it)
    local names = type(it) == "table" and it.names or nil
    return recordRaw(d, ctx, ucls, { id = k, names = names }, path, ...)
end
-- cellOf receives the item table; normalise to its id
local cellOfRaw = cellOf
cellOf = function(d, ctx, ucls, it) return cellOfRaw(d, ctx, ucls, key(it)) end

function CP.Run(reason, force)
    if ns.SelfThrottled and ns.SelfThrottled() then return nil end
    local d = db()
    if not d then return nil end
    local ctx = CP.Context()
    local now = (g("GetTime") or os.clock)()
    d.runCount = d.runCount or {}
    local maxRuns = tonumber(cfg().maxRunsPerCapture) or 80
    if not force then
        if (d.capRuns or 0) >= maxRuns then return nil end
        if CP.lastRun and now - CP.lastRun < (tonumber(cfg().minInterval) or 3) then return nil end
    end
    CP.lastRun = now
    d.capRuns = (d.capRuns or 0) + 1
    bump(d.runCount, ctx)
    local seen = {}
    local classes = {}
    for _, u in ipairs(units()) do
        local ucls = CP.UnitClass(u)
        if ucls and not seen[ucls] then
            seen[ucls] = true
            CP.curUnit = u
            classes[#classes + 1] = ucls
            for _, it in ipairs(ITEMS) do
                if it.cat ~= "casting" and (not it.unitless or u == "player") then
                    local res = record(d, ctx, ucls, it, it.path, it.args(u))
                    if it.id == "UnitHealth" then opsFor(d, ctx, "health", rv(res, 1)) end
                    if it.id == "UnitPower" then opsFor(d, ctx, "power", rv(res, 1)) end
                    if it.id == "UnitGUID" and u ~= "player" then opsFor(d, ctx, "identity", rv(res, 1)) end
                end
            end
            castProbe(d, ctx, ucls, u)
            if u == "player" or u == "target" or u == "focus" or u:find("^party") or u:find("^nameplate")
                or u:find("^arena") or u:find("^raid") then auraProbe(d, ctx, ucls, u) end
        end
    end
    -- unit-less: damage meter + the player's dispel spells
    record(d, ctx, "global", "C_DamageMeter.GetCombatSessionFromType", "C_DamageMeter.GetCombatSessionFromType", 0, 0)
    record(d, ctx, "global", "C_DamageMeter.IsDamageMeterAvailable", "C_DamageMeter.IsDamageMeterAvailable")
    local dispel = cfg().dispelSpells
    if type(dispel) ~= "table" then
        local okD, lst = pcall(function() return ns.AuraPresence and ns.AuraPresence.DispelSpells() end)
        dispel = okD and lst or {}
    end
    for _, sid in ipairs(dispel) do
        local f = fn("C_SpellBook.IsSpellKnown")
        local okK, known = pcall(f or function() return nil end, sid)
        if okK and known == true then
            record(d, ctx, "global", "dispel:IsSpellUsable(" .. sid .. ")", "C_Spell.IsSpellUsable", sid)
            local r = record(d, ctx, "global", "dispel:GetSpellCooldown(" .. sid .. ")", "C_Spell.GetSpellCooldown", sid)
            opsFor(d, ctx, "cooldown", type(rv(r, 1)) == "table" and rv(r, 1).startTime or nil)
        end
    end
    -- v2.2.25: environment stamp (world-solo/party/dungeon/raid/arena/bg x combat x phase) + per ctx@env counter
    local envTag = ns.EnvTag and ns.EnvTag() or nil
    if envTag then
        d.envCtx = d.envCtx or {}
        local k = ctx .. "@" .. envTag
        d.envCtx[k] = (d.envCtx[k] or 0) + 1
    end
    local runRec = ns.Stamp({ reason = reason, ctx = ctx, env = envTag, classes = classes })
    d.runs[#d.runs + 1] = runRec
    while #d.runs > 100 do table.remove(d.runs, 1) end
    return runRec
end

-- live event payloads per unit class (UNIT_HEALTH/MAXHEALTH, UNIT_SPELLCAST_*, UNIT_AURA updateInfo)
local EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP",
    "UNIT_SPELLCAST_EMPOWER_UPDATE", "UNIT_AURA", "UNIT_AURA_BLOCKED" }
CP.EVENTS = EVENTS
local evThrottle = {}
local function onUnitEvent(event, unit, ...)
    if not capturing() or cfg().enabled == false then return end
    if type(unit) ~= "string" or ns.IsSecret(unit) then return end
    local now = (g("GetTime") or os.clock)()
    local tk = event .. unit
    if evThrottle[tk] and now - evThrottle[tk] < 0.2 then return end
    evThrottle[tk] = now
    local d = db()
    local ucls = CP.UnitClass(unit) or (family(unit) .. ":gone")
    local ctx = CP.Context()
    d.events[ctx] = d.events[ctx] or {}
    d.events[ctx][ucls] = d.events[ctx][ucls] or {}
    local e = d.events[ctx][ucls][event]
    if not e then e = { n = 0, r = {} } d.events[ctx][ucls][event] = e end
    e.n = e.n + 1
    local n = select("#", ...)
    for i = 1, math.min(n, 6) do
        local v = select(i, ...)
        e.r[i + 1] = e.r[i + 1] or {}
        bump(e.r[i + 1], code(v))
        if event == "UNIT_AURA" and i == 1 and type(v) == "table" and code(v) ~= "S" then
            e.f = e.f or {}
            for _, fld in ipairs({ "isFullUpdate", "addedAuras", "updatedAuraInstanceIDs", "removedAuraInstanceIDs" }) do
                local okF, fv = pcall(function() return v[fld] end)
                e.f[fld] = e.f[fld] or {}
                bump(e.f[fld], okF and code(fv) or "E")
                if okF and fld == "addedAuras" and type(fv) == "table" and code(fv) ~= "S" then
                    local okA, first = pcall(function() return fv[1] end)
                    if okA and type(first) == "table" then
                        for k, fc in pairs(ns.ClassifyFields(first) or {}) do
                            e.f["addedAuras[1]." .. k] = e.f["addedAuras[1]." .. k] or {}
                            bump(e.f["addedAuras[1]." .. k], fc)
                        end
                    end
                end
            end
        end
    end
    -- casting start of a probed unit: probe now (fields are live only while the cast runs)
    if (event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START") and unit ~= "player"
        and (unit == "target" or unit == "focus" or unit:find("^nameplate")) then
        local last = CP.lastCastProbe or 0
        if now - last > 2 then
            CP.lastCastProbe = now
            pcall(castProbe, d, ctx, ucls, unit)
        end
    end
end
CP.OnUnitEvent = onUnitEvent

-- frame registered only while capturing
local frame
local function after(s, f) if type(g("C_Timer")) == "table" then C_Timer.After(s, f) else f() end end
function CP.Start()
    if cfg().enabled == false then return false end
    local d = db()
    d.capRuns = 0
    d.sid = ns.db.logs.session and ns.db.logs.session.sid
    if not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", function(_, event, ...)
            local run = ns.Perf and function(r) ns.Perf.Run("CombatProbe.Run", CP.Run, r) end or function(r) pcall(CP.Run, r) end
            if event == "PLAYER_REGEN_DISABLED" then CP.InvalidateContext() after(1, function() run("combat") end)
            elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then CP.InvalidateContext() after(0.1, function() run("flip") end)
            elseif event == "PLAYER_TARGET_CHANGED" or event == "ENCOUNTER_START" or event == "PLAYER_FOCUS_CHANGED" then
                after(0.2, function() run(string.lower(event)) end)
            else
                local ok, err
                if ns.Perf then ok, err = ns.Perf.Run(ns.Perf.Key("CombatProbe", event), onUnitEvent, event, ...)
                else ok, err = pcall(onUnitEvent, event, ...) end
                if not ok then ns.NoteSelfError("CombatProbe." .. event, err) end
            end
        end)
    end
    for _, ev in ipairs(EVENTS) do pcall(frame.RegisterEvent, frame, ev) end
    for _, ev in ipairs({ "PLAYER_REGEN_DISABLED", "ADDON_RESTRICTION_STATE_CHANGED", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
        "ENCOUNTER_START" }) do pcall(frame.RegisterEvent, frame, ev) end
    pcall(CP.Run, "capture:on", true)
    return true
end
function CP.Stop()
    if frame then pcall(frame.UnregisterAllEvents, frame) end
    local d = db()
    if not d then return nil end
    local n = 0
    for _, byU in pairs(d.cells) do for _, byI in pairs(byU) do for _ in pairs(byI) do n = n + 1 end end end
    return { runs = d.capRuns or 0, cells = n }
end

ns.captureModules = ns.captureModules or {}
ns.captureModules[#ns.captureModules + 1] = { name = "combat probe set", start = function() return CP.Start() end,
    stop = function() local r = CP.Stop() return r and string.format("combat probe %d run(s), %d cells", r.runs, r.cells) end }
