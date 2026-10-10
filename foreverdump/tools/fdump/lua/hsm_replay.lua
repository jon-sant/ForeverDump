-- Offline HSM replay: feeds a Forever-observable event stream into the SAME library the addon uses
-- (ForeverDump/Lib/HybridState.lua) and prints predictions / inferences / contradictions as JSON.
-- usage: lua5.1 hsm_replay.lua <HybridState.lua> <events.lua>   (events.lua returns { events = { ... } })
--   { t=, k="cast", ev="UNIT_SPELLCAST_SUCCEEDED", unit="player"|key, spell=id|nil, player=true, target=key }
--   { t=, k="aura", unit=key, added={ {iid=, spellId=, fromPlayer=, helpful=, duration=} }, removed={iid...} }
--   { t=, k="count", unit=key, filter="HELPFUL|PLAYER", count=n }
--   { t=, k="learn", spell=id, aura={duration=, helpful=, self=}, cooldown=s, amount={min=,max=,kind=} }
--   { t=, k="tick" }
-- v2.2.4 (HybridState MINOR 3, live attribution):
--   { t=, k="combat", on=bool }  { t=, k="swing" }  { t=, k="dm", type=n }  { t=, k="interrupt", unit=key }
--   { t=, k="uc", unit=key, action=, flag=, amount=, school=, player=bool }
--   { t=, k="dmrec", damage=, healing=, interrupts=, spells={ [id]=n } }
--   { t=, k="aura", ..., addedSecret=true }   data.legacy = true replays the v2.2.3 behaviour
-- v2.2.4 (MINOR 4):
--   { t=, k="ecast", ev="UNIT_SPELLCAST_START"|..., unit=guid, bar= }   enemy cast timing (npc key from the GUID)
--   { t=, k="failed", spell=, ev= }   { t=, k="hpevt", unit="player" }   { t=, k="hpmax", unit="player", v= }
--   { t=, k="probe", units={ "player", guid } }   ledger: cached auras believed present (scored against the log)
-- v2.2.16: { t=, k="census", sameClass=n, sameClassEnemy=n }   same-class actors (live: Inference census signal)
local libPath, evPath = arg[1], arg[2]
_G.HybridState = nil
local Lib = dofile(libPath)
local data = dofile(evPath)
local now = 0
local verdicts, decides = {}, {}
local function confN(c)
    return (c == "observed" and 4) or (c == "high" and 3) or (c == "medium" and 2) or (c == "low" and 1) or 0
end
local hs = Lib.New({ now = function() return now end, window = data.window or 0.6, legacy = data.legacy,
    shadowFindings = data.shadowFindings, candidates = (data.candidates ~= false) or nil,
    onInfer = function(rec)
        decides[#decides + 1] = {
            t = now, rule = rec.rule, kind = rec.kind, conf = rec.conf, c = confN(rec.conf),
            spell = rec.spell, unit = rec.unit, src = rec.src, id = #decides
        }
    end,
    onVerdict = function(r) verdicts[#verdicts + 1] = { t = r.t, kind = r.kind, v = r.v, src = r.src, conf = r.conf, spell = r.spell, d = r.d, key = r.key } end })
local attributions = {}
local probes = {}
for _, e in ipairs(data.events) do
    now = e.t
    local nAttr = #attributions
    if hs.candLast then hs.candLast = {} end
    if e.k == "cast" then
        if e.player and e.spell and e.ev == "UNIT_SPELLCAST_SUCCEEDED" and hs.Cooldown then   -- tracker state right before my cast
            local st, gq = hs:Cooldown(e.spell), hs.GCD and hs:GCD()
            attributions[#attributions + 1] = { t = now, k = "cdq", spell = e.spell, state = st.state, remaining = st.remaining,
                source = st.source, conf = st.confidence, gcdRem = gq and gq.remaining, gcdSpell = gq and gq.spell }
        end
        hs:OnCast(e.ev, e.unit, e.spell, e.player, e.target)
    elseif e.k == "cdp" and hs.CDPayload then hs:CDPayload(e.spell, nil, e.cat, e.src)
    elseif e.k == "cdseed" and hs.CDSeed then hs:CDSeed(e.spell, e)
    elseif e.k == "cdobs" and hs.CDObserve then hs:CDObserve(e.spell, e.a, e.g, e.r, e.du)
    elseif e.k == "aura" then
        local before = hs.counters.inferences
        hs:OnAura(e.unit, { added = e.added or {}, removed = e.removed or {}, full = e.full, addedSecret = e.addedSecret,
            removedSecret = e.removedSecret })
        if e.addedSecret then
            local last = hs.inferences[#hs.inferences]
            local src = "none"
            if hs.counters.inferences > before and last then
                src = last.src or ((last.rule == "elimination") and "other" or ((last.rule == "secret-timing") and "mine" or "none"))
            end
            attributions[#attributions + 1] = { t = now, k = "aura", unit = e.unit, src = src, rule = last and last.rule, ref = e.ref,
                ev = (hs.counters.inferences > before and last) and last.ev or nil, spell = (hs.counters.inferences > before and last) and last.spell or nil }
        end
    elseif e.k == "combat" and hs.OnCombatState then hs:OnCombatState(e.on)
    elseif e.k == "swing" and hs.OnSwing then hs:OnSwing()
    elseif e.k == "dm" and hs.OnDamageMeter then hs:OnDamageMeter(e.type)
    elseif e.k == "group" and hs.SetGroupSize then hs:SetGroupSize(e.size)   -- v2.2.12: dm-frame is solo-only
    elseif e.k == "census" and hs.SetCensus then hs:SetCensus(e)   -- v2.2.16: same-class actors (ambiguity guard)
    elseif e.k == "linkseed" and hs.SeedSelfLink then hs:SeedSelfLink(e.spell, e.casts, e.hits)
    elseif e.k == "uc" and hs.OnUnitCombat then
        local r = hs:OnUnitCombat(e.unit, e.action, e.flag, e.amount, e.school, e.player)
        attributions[#attributions + 1] = { t = now, k = "uc", unit = e.unit, src = r and r.src or "none", rule = r and r.rule, ref = e.ref,
            kind = r and r.kind, overhealEst = r and r.overhealEst, hpConf = r and r.hpConf, ev = r and r.ev, spell = r and r.spell }
    elseif e.k == "interrupt" and hs.OnInterrupt then
        local r = hs:OnInterrupt(e.unit)
        attributions[#attributions + 1] = { t = now, k = "interrupt", unit = e.unit, src = r and r.src or "none", rule = r and r.rule, ref = e.ref,
            elapsed = r and r.elapsed, predicted = r and r.predicted, deduped = (r == nil) or nil, ev = r and r.ev }
    elseif e.k == "dmrec" and hs.ReconcileDM then
        hs:ReconcileDM({ damage = e.damage, healing = e.healing, interrupts = e.interrupts, spells = e.spells })
    elseif e.k == "ecast" and hs.OnEnemyCast then
        local r = hs:OnEnemyCast(e.ev, e.unit, Lib.NpcKey(e.unit), e.bar, e.spell)
        if r and r.outcome == "interrupted" then r.tEnd = now end
    elseif e.k == "failed" and hs.OnCastFailed then
        local st = hs.Cooldown and hs:Cooldown(e.spell)
        local r = hs:OnCastFailed(e.spell, e.ev)
        attributions[#attributions + 1] = { t = now, k = "failed", spell = e.spell, rule = r and r.rule, remaining = r and r.remaining, ev = e.ev,
            cdState = st and st.state, cdSource = st and st.source }
    elseif e.k == "hpevt" and hs.OnHealthEvent then hs:OnHealthEvent(e.unit)
    elseif e.k == "hpmax" and hs.OnHealthMax then hs:OnHealthMax(e.unit, e.v)
    elseif e.k == "probe" and hs.CachedAuras then
        for _, u in ipairs(e.units or {}) do
            local list = {}
            for _, a in ipairs(hs:CachedAuras(u)) do list[#list + 1] = { spell = a.spell, conf = a.conf } end
            probes[#probes + 1] = { t = now, unit = u, auras = list }
        end
    elseif e.k == "count" then hs:OnCount(e.unit, e.filter, e.count)
    elseif e.k == "learn" then
        local k = {}
        for key, v in pairs(e) do if key ~= "t" and key ~= "k" and key ~= "spell" then k[key] = v end end
        hs:Learn(e.spell, k)
    elseif e.k == "tick" then hs:Tick() end
    -- v2.2.15: candidate (shadow) claims made while handling this event ride on its attribution
    if hs.candLast and next(hs.candLast) and #attributions > nAttr then attributions[#attributions].cand = hs.candLast end
end
hs:Tick()

local function enc(v, depth)
    depth = depth or 0
    local t = type(v)
    if t == "nil" then return "null" end
    if t == "boolean" then return tostring(v) end
    if t == "number" then if v ~= v or v == math.huge or v == -math.huge then return "null" end return string.format("%.17g", v) end
    if t == "string" then return '"' .. v:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end) .. '"' end
    if t == "table" and depth < 8 then
        local n = #v
        if n > 0 or next(v) == nil then
            local parts = {}
            for i = 1, n do parts[i] = enc(v[i], depth + 1) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local parts = {}
        for k, x in pairs(v) do
            if type(x) ~= "function" and type(x) ~= "table" or (type(x) == "table" and k ~= "pred") then
                parts[#parts + 1] = enc(tostring(k)) .. ":" .. enc(x, depth + 1)
            end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
end
local ex = hs:Export()
io.write(enc({ predictions = ex.predictions, inferences = ex.inferences, contradictions = ex.contradictions, counters = ex.counters,
    fights = ex.fights, attributions = attributions, casts = ex.casts, castModel = ex.castModel, probes = probes, ledger = ex.ledger,
    verdicts = verdicts, verdictCounts = ex.verdicts, cd = ex.cd, decides = decides, candStats = hs.candStats, attrStats = hs.attrStats, selfLink = hs.selfLink }))
