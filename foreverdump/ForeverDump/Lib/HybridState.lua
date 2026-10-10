-- HybridState-1.0: a reusable "hybrid state machine" for addons on secret-value clients (WoW Forever 1.60+).
-- Predicts and tracks combat state from READABLE inputs only:
--   * UNIT_SPELLCAST_* events (event timing always arrives; spellID only when the client reports it non-secret)
--   * UNIT_AURA updateInfo (auraInstanceIDs / counts / fields when non-secret)
--   * readable aura counts (e.g. GetAuraSlots(unit, "HELPFUL|PLAYER") when the count is not secret)
--   * restriction state, and spell knowledge cached while readable (durations, cooldowns, tooltip ranges)
-- It never reads secrets, never parses secret text, never uses the combat log (CLEU) and never derives numbers from
-- rendered widgets. Every inference carries the rule that produced it and a confidence tag.
--
-- Usage (any addon; no ForeverDump dependency):
--   local HS = HybridState.New({ now = GetTime, onPredict = fn, onInfer = fn, onContradiction = fn })
--   HS:Learn(spellID, { aura = { duration = 30, helpful = true }, cooldown = 8, amount = { min = 10, max = 12, kind = "damage" } })
--   HS:OnCast(event, unitKey, spellID|nil, isPlayer, targetKey)      -- from UNIT_SPELLCAST_* (spellID nil when secret)
--   HS:OnAura(unitKey, { full = bool, added = { { iid=, spellId=, fromPlayer=, helpful=, duration=, applications= } },
--                        addedCount = n, removed = { iid, ... }, removedCount = n })  -- unreadable fields = nil
--   HS:OnCount(unitKey, filter, count)                                   -- readable aura count for a filter
--   HS:Tick()                                                            -- expire predicted auras/cooldowns
--   HS:UnitState(unitKey), HS:CastState(unitKey), HS:Cooldown(spellID), HS.predictions, HS.inferences, HS.counters
-- MINOR 5 (v2.2.4, cooldown review): CooldownTracker. Per-spell cooldown + GCD state fused from every readable signal:
--   HS:CDInfo(spellID, { cooldown = s, gcd = s, category = n, srCategory = n })   -- static (knowledge, read out of combat)
--   HS:CDPayload(spellID, baseSpellID, category, startRecoveryCategory)        -- SPELL_UPDATE_COOLDOWN payload (clear, run 5)
--   HS:CDActive() -> { spellID, ... }                                          -- the k spells worth re-checking (O(k))
--   HS:CDCheckList(horizon, budget) -> { spellID, ... }                        -- per-event subset: due + GCD + budget RR
--   HS:CDObserve(spellID, isActive, isOnGCD, remaining|nil, duration|nil)      -- C_Spell.GetSpellCooldown NeverSecret fields
--   HS:GCDObserve(remaining, duration)                                         -- clear GCD read (61304 when it exists)
--   HS:Cooldown(spellID) -> { state = "ready"|"cooling"|"gcd", ends, remaining, confidence, source }
--   HS:GCD() -> { ends, spell, length, remaining, source } | nil
--   own UNIT_SPELLCAST_SUCCEEDED starts the spell's cooldown (+ its shared category) and the GCD with that spell's baseGCD;
--   isActive false outside the GCD = observed ready (learns the true cooldown); isOnGCD true -> false = observed GCD end
--   (learns the per-spell GCD); verdicts "cd-ready" and "gcd" go to the live verification ring.
-- MINOR 4 (v2.2.4, run-5 review): Ledger (collect-while-clear identity/aura cache), enemy cast-duration model per NPC
--   (OnEnemyCast / EnemyCast: interrupt window), interrupt dedupe across tokens, UNIT_SPELLCAST_FAILED as cooldown
--   evidence (OnCastFailed), running health estimate + overheal estimate for the player (OnHealthMax / OnHealthEvent)
-- MINOR 3 (ForeverDump v2.2.4, run 5): source attribution from clear event timing only
--   HS:OnCombatState(inCombat)                    -- PLAYER_REGEN_DISABLED/ENABLED: opens/closes a fight record
--   HS:OnSwing()                                  -- PLAYER_SWING (clear): my melee swing happened now
--   HS:OnDamageMeter(dmType)                      -- DAMAGE_METER_COMBAT_SESSION_UPDATED type arg (clear): my/group meter moved
--   HS:OnUnitCombat(unitKey, action, flag, amount, school, isPlayerUnit)  -- UNIT_COMBAT (clear on 1.60.1, run 5)
--   HS:OnInterrupt(unitKey)                       -- UNIT_SPELLCAST_INTERRUPTED on a hostile unit
--   HS:ReconcileDM(rec)                           -- post-combat C_DamageMeter totals (clear after combat) vs live attribution
--   HS.fights (newest last), HS:Fight()           -- per-fight mine/other damage, heals, interrupts, auras
-- Embedding: copy this file into your addon and load it before your code. It registers the global `HybridState`
-- (or returns the table when loaded with a module loader); a newer MINOR replaces an older one.
local MAJOR, MINOR = "HybridState-1.0", 5
local existing = rawget(_G, "HybridState")
if type(existing) == "table" and (existing.MINOR or 0) >= MINOR then return existing end

local Lib = { MAJOR = MAJOR, MINOR = MINOR }
local M = {}
M.__index = M

local function defaultNow()
    local f = rawget(_G, "GetTime")
    return type(f) == "function" and f() or os.clock()
end

local CONF = { observed = 3, high = 2, medium = 1, low = 0 }
Lib.CONF = CONF

function Lib.New(opts)
    opts = opts or {}
    local o = setmetatable({}, M)
    o.now = opts.now or defaultNow
    o.window = opts.window or 0.6           -- s: cast -> aura correlation window
    o.tolerance = opts.tolerance or 1.5     -- s: early-removal tolerance before calling it a contradiction
    o.maxLog = opts.maxLog or 2000
    o.maxFights = opts.maxFights or 10          -- v2.2.16: lab = no cap (collect first; the Perf backstop reports runaways)
    o.candAuraMax = opts.candAuraMax or 300
    o.onPredict, o.onInfer, o.onContradiction = opts.onPredict, opts.onInfer, opts.onContradiction
    o.knowledge = {}        -- [spellID] = { aura = { duration, helpful }, cooldown, castTime, amount = { min, max, kind } }
    o.units = {}            -- [unitKey] = { auras = { [key] = aura }, counts = { [filter] = n } }
    o.casts = {}            -- [unitKey] = { active, kind, start, spell, ends }
    o.cooldowns = {}        -- [spellID] = { start, ends }
    o.iidMap = {}           -- [unitKey .. "#" .. iid] = { spell, rule, conf }
    o.recent = {}           -- recent player casts { t, spell, target }
    o.unexplained = {}      -- recent auras with unreadable spellId and no explaining cast yet
    o.predictions, o.inferences, o.contradictions = {}, {}, {}
    o.summons, o.totems = {}, {}
    o.counters = { predictions = 0, inferences = 0, contradictions = 0, casts = 0, auraEvents = 0, unreadable = 0 }
    o.restriction = {}
    o.seq = 0
    o.version = 0           -- bumped on every state change (UIs redraw only when it moved: dirty flag)
    o.kver = 0              -- knowledge version (Appliers cache key)
    o.applCache = {}
    -- MINOR 3: attribution (all timing in seconds; defaults trained offline on the run-5 combat log, fdump coverage)
    o.legacy = opts.legacy                  -- true = v2.2.3 behaviour (no attribution, loose secret-timing window)
    o.timingWindow = opts.timingWindow or (o.legacy and o.window * 4 or 0.35)  -- secret aura event -> my cast
    o.sameFrame = opts.sameFrame or 0.06    -- s: same-frame tolerance (spell damage arrives with UNIT_SPELLCAST_SUCCEEDED)
    -- v2.2.12: group size (1 = solo). DAMAGE_METER_COMBAT_SESSION_UPDATED fires for EVERY group member's damage/heal
    -- (run 9 BG, 14-15 members: live "mine" 7-30x the combat log, 80-90 % of it from dm-frame), so the dm-frame rule is
    -- only valid solo. Fed from the clear GetNumGroupMembers() (Inference, GROUP_ROSTER_UPDATE).
    o.groupSize = opts.groupSize or 1
    o.recentFights = {}                     -- v2.2.12: last RECENT_N fights (refs, soft included; not exported) for meter sessions
    o.bornAt = o.now()
    o.dmWindow = opts.dmWindow or 0.03      -- s: DAMAGE_METER_COMBAT_SESSION_UPDATED fires in the frame my damage lands
    o.swingLag = opts.swingLag or { 0.25, 1.1 }  -- s: melee UNIT_COMBAT lags the swing (log: median 0.458, max 0.979)
    o.healPeriod = opts.healPeriod or 2.0   -- s: periodic heal cadence (Healing Stream Totem, log)
    o.healJitter = opts.healJitter or 0.15
    o.ownRecent = {}                        -- my last successful casts (any spellID state) { t, spell }
    o.swings = {}                           -- recent PLAYER_SWING times { t, used }
    o.dmLast = {}                           -- [dmType] = last event time
    -- v2.2.6 capture-mode: shadow (non-acting) evaluation of prior correlate findings
    o.shadowFindings = opts.shadowFindings and true or false
    -- v2.2.15 lab level: parallel candidate rules (shadow, provisional, never acting on the live estimate). Each has its
    -- own ID and logs one prediction verdict per decision ("cand:<id>", v = "P", src = mine/other); heal candidates
    -- also get a per-meter-session live check ("cand-heal:<id>" V/C/U). candLast = this event's claims (replay scorer).
    o.candidates = opts.candidates and true or false
    o.candLast, o.candStats, o.candCost, o.candAura = {}, {}, {}, {}
    o.clock = opts.clock                    -- ms clock (debugprofilestop live): per-kind candidate cost (lab)
    o.candTick = {}                         -- c-cad-amount: last 4 accepted cadence amounts
    o.shadowDm7Expect = nil                 -- GetTime when DAMAGE_METER type 7 fired (enemy-melee finding)
    o.shadowTotemHealN = 0                  -- counts for capture summary
    o.shadowDm7N = 0
    o.lastMineHeal = nil
    -- v2.2.16 attribution safety (crowded BGs, duplicate classes/spells): every "mine" claim passes M:gate() =
    -- 1 target match, 2 spell plausibility (learned spell -> aura/heal/damage link), 3 ambiguity guard (same-class
    -- actors present, or several events on that unit in one frame) -> U ("none") unless corroborated (expected
    -- timing of a learned aura, amount inside the learned band, PLAYER_SWING token). attrStats = per-rule outcome counts.
    o.census = { sameClass = 0, sameClassEnemy = 0, n = 0 }   -- SetCensus (Inference: clear UnitClass of group/plates)
    o.frameEv = {}                  -- [unitKey] = { t = frame start, n = events } (crowd: several events, one frame)
    o.attrStats = {}                -- [rule] = { mine, other, none, implausible, mismatch, ambiguous, corroborated }
    o.attrGuard = opts.attrGuard ~= false
    o.cadGuard = opts.cadGuard == true          -- v2.2.16: cadence ambiguity guard failed the replay gate -> shadow only
    o.selfLink = {}                 -- [spellID] = { casts, hits }: my cast -> an aura on ME in the same frame (learned live)
    o.fights = {}
    o.fight = nil
    -- MINOR 4
    o.ecast = {}                    -- [unitKey] = open enemy cast { start, bar, key, pred, lo, hi }
    o.castModel = {}                -- [npcKey(#spell)] = { d = { last 8 durations }, n } (learned live START -> SUCCEEDED)
    o.castPreds = {}                -- per enemy cast: { t, key, pred, actual | elapsed, outcome } (offline scoring)
    o.lastInterrupt = nil
    o.hp = {}                       -- [unitKey] = { max, cur, anchor, anchorT, unknown, lastEvt, lastUnknownT }
    o.quietFull = opts.quietFull or 3.5   -- s without UNIT_HEALTH out of combat = full health (regen stopped)
    o.inCombat = false
    o.verdicts = {}                 -- [kind|V/C/U/X] = n (live verification counters)
    o.onVerdict = opts.onVerdict
    o.idKey = opts.idKey  -- v2.2.6: ReplayLog.IdKey (v2.2.21: raw kind:<GUID>) for per-unit meter join
    o.cachedIdx = {}                -- [unitKey] = { [ledger aura key] = true } (per-unit index into the ledger)
    -- MINOR 5: CooldownTracker
    o.cd = { spells = {}, active = {}, nActive = 0, cat = {}, gcd = nil, gcdLearn = {}, readies = {}, gcds = {},
        list = {}, pos = {}, heap = {}, due = {}, rr = 0 }   -- incremental indices: active array, ends min-heap, due set
    o.ledger = opts.ledger          -- set below once Lib.NewLedger exists (opts.ledger = false disables it)
    if o.ledger == nil and Lib.NewLedger then o.ledger = Lib.NewLedger({ now = o.now }) end
    return o
end

-- bounded append, amortised O(1): the list may hold up to max + max/4 entries; when it overflows, the newest max are
-- moved down in one pass (v2.2.3; table.remove(list, 1) shifted the whole list on EVERY insert once full)
local function push(list, rec, max)
    local n = #list + 1
    list[n] = rec
    local slack = math.max(8, math.floor(max / 4))
    if n > max + slack then
        local drop = n - max
        for i = 1, max do list[i] = list[i + drop] end
        for i = max + 1, n do list[i] = nil end
    end
    return rec
end
-- v2.2.12: fights kept (by reference, not exported) to cover one C_DamageMeter session. Run 9 BG: a meter session
-- (38-159 s) spans several consecutive live fights (5.6-17.6 s each, soft ones included); 40 covers ~10 min of
-- back-to-back fights. When the session reaches further back than this, the reconcile reports U (coverage), never C.
local RECENT_N = 40
Lib.push = push

function M:Learn(spellID, k)
    if type(spellID) ~= "number" or type(k) ~= "table" then return end
    local cur = self.knowledge[spellID] or {}
    for key, v in pairs(k) do
        if type(v) == "table" and type(cur[key]) == "table" then for a, b in pairs(v) do cur[key][a] = b end else cur[key] = v end
    end
    self.knowledge[spellID] = cur
    self.kver = self.kver + 1
    self.version = self.version + 1
end

-- spells of the player that apply an aura of the given helpfulness ("single applier" rule input)
function M:Appliers(helpful)
    -- cached per knowledge version (v2.2.3: it was rebuilt + sorted on every aura event)
    local ck = (helpful == nil) and "any" or (helpful and "h" or "d")
    local c = self.applCache[ck]
    if c and c.v == self.kver then return c.list end
    local out = {}
    for id, k in pairs(self.knowledge) do
        if k.aura and (helpful == nil or k.aura.helpful == nil or k.aura.helpful == helpful) then out[#out + 1] = id end
    end
    table.sort(out)
    self.applCache[ck] = { v = self.kver, list = out }
    return out
end

function M:unit(key)
    local u = self.units[key]
    if not u then u = { auras = {}, counts = {} } self.units[key] = u end
    return u
end

function M:infer(rec)
    self.seq = self.seq + 1
    rec.id, rec.t = self.seq, rec.t or self.now()
    self.counters.inferences = self.counters.inferences + 1
    self.version = self.version + 1
    push(self.inferences, rec, self.maxLog)
    if self.onInfer then pcall(self.onInfer, rec) end
    return rec
end

-- MINOR 4: live verification loop. Every prediction checked against later readable reality emits one verdict:
-- V verified, C contradicted, U unverified (no readable reality to check against), X unexpected. O(1); the addon's
-- Verify.lua stores them in a capped SV ring (onVerdict). kind = check type, src = evidence signal.
function M:verdict(kind, v, rec)
    rec = rec or {}
    rec.kind, rec.v, rec.t = kind, v, rec.t or self.now()
    local vc = self.verdicts
    local key = kind .. "|" .. v
    vc[key] = (vc[key] or 0) + 1
    if self.onVerdict then pcall(self.onVerdict, rec) end
    return rec
end

-- v2.2.15: one shadow claim of candidate rule `id` (kind = aura-me/heal-me/heal-target/interrupt, src = mine/other)
function M:cand(id, kind, unit, src, amount, spell)
    if not self.candidates then return end
    self.candLast[id] = src
    if kind == "aura-me" then push(self.candAura, { t = self.now(), id = id, src = src }, self.candAuraMax) end   -- post-combat sweep check
    local st = self.candStats[id]
    if not st then st = { n = 0, mine = 0, other = 0, kind = kind } self.candStats[id] = st end
    st.n = st.n + 1
    if src == "mine" then st.mine = st.mine + 1 else st.other = st.other + 1 end
    if (kind == "heal-me" or kind == "heal-target") and src == "mine" and type(amount) == "number" then
        local f = self.fight
        if f then
            f.cand = f.cand or {}
            f.cand[id] = (f.cand[id] or 0) + amount
        end
    end
    local d = nil
    if type(amount) == "number" then d = amount end
    self:verdict("cand:" .. id, "P", { src = src, conf = "shadow", spell = spell, d = d, key = unit })
end

-- per-kind cost of the candidate blocks (ms; n, total, max) - lab cost report per rule family
function M:candCostAdd(kind, t0)
    if not (t0 and self.clock) then return end
    local ms = self.clock() - t0
    local c = self.candCost[kind]
    if not c then c = { n = 0, ms = 0, max = 0 } self.candCost[kind] = c end
    c.n, c.ms = c.n + 1, c.ms + ms
    if ms > c.max then c.max = ms end
end

-- candidate cadence test: heal at `now` on the beat of one of my live summons (phase-locked to the drop time)
function M:summonBeat(now, jitter)
    local P = self.healPeriod
    if P <= 0 then return false end
    for i = #self.summons, 1, -1 do
        local sm = self.summons[i]
        local life = sm.pred and sm.pred.summon and sm.pred.summon.duration or 120
        local d = now - sm.t
        if d >= P - jitter and d <= life + jitter then
            local ph = d % P
            if ph <= jitter or P - ph <= jitter then return true, sm end
        end
    end
    return false
end

function M:contradict(rec)
    rec.t = rec.t or self.now()
    self.counters.contradictions = self.counters.contradictions + 1
    self.version = self.version + 1
    push(self.contradictions, rec, 200)
    if self.onContradiction then pcall(self.onContradiction, rec) end
end

function M:SetRestriction(rtype, state) self.restriction[rtype] = state end

----------------------------------------------------------------------------
-- casts
----------------------------------------------------------------------------
local START = { UNIT_SPELLCAST_START = "cast", UNIT_SPELLCAST_CHANNEL_START = "channel", UNIT_SPELLCAST_EMPOWER_START = "empower" }
local STOP = { UNIT_SPELLCAST_STOP = "stop", UNIT_SPELLCAST_CHANNEL_STOP = "stop", UNIT_SPELLCAST_EMPOWER_STOP = "stop",
    UNIT_SPELLCAST_SUCCEEDED = "succeeded", UNIT_SPELLCAST_INTERRUPTED = "interrupted", UNIT_SPELLCAST_FAILED = "failed" }
Lib.START, Lib.STOP = START, STOP

function M:OnCast(event, unitKey, spellID, isPlayer, targetKey)
    local now = self.now()
    self.counters.casts = self.counters.casts + 1
    self.version = self.version + 1
    if spellID == nil then self.counters.unreadable = self.counters.unreadable + 1
    elseif self.ledger then self.ledger:Put("cast", unitKey, { spell = spellID, event = event }, "UNIT_SPELLCAST") end
    local c = self.casts[unitKey]
    if START[event] then
        local k = spellID and self.knowledge[spellID]
        if isPlayer and spellID then self:cdBegin(spellID, now) end
        self.casts[unitKey] = { active = true, kind = START[event], start = now, spell = spellID,
            ends = k and k.castTime and k.castTime > 0 and (now + k.castTime) or nil }
        self:infer({ rule = "cast-pair", kind = "cast-start", unit = unitKey, spell = spellID, conf = "observed" })
    elseif STOP[event] then
        if c and c.active then
            c.active = false
            self:infer({ rule = "cast-pair", kind = "cast-end", unit = unitKey, spell = spellID or c.spell, outcome = STOP[event],
                started = c.start, conf = "observed" })
        end
        if event == "UNIT_SPELLCAST_SUCCEEDED" and isPlayer then
            local cd = spellID and self.cooldowns[spellID]
            if cd and cd.ends then   -- predicted cooldown vs this successful recast
                if now < cd.ends - 0.15 then
                    self:contradict({ kind = "recast-before-ready", spell = spellID, early = cd.ends - now, rule = "cooldown" })
                    self:verdict("cooldown", "C", { spell = spellID, src = "UNIT_SPELLCAST_SUCCEEDED", conf = "high", d = now - cd.ends })
                else self:verdict("cooldown", "V", { spell = spellID, src = "UNIT_SPELLCAST_SUCCEEDED", conf = "high", d = now - cd.ends }) end
            end
            if spellID then self:CDCast(spellID, now) end
            local kk = spellID and self.knowledge[spellID]
            push(self.ownRecent, { t = now, spell = spellID, target = targetKey, summon = (kk and kk.summon) and true or nil }, 8)
            if spellID then
                local sl = self.selfLink[spellID]
                if not sl then sl = { casts = 0, hits = 0 } self.selfLink[spellID] = sl end
                sl.casts = sl.casts + 1
            end
            if spellID then self:predict(spellID, targetKey, now) end
        end
    end
end

function M:CastState(unitKey) return self.casts[unitKey] end

-- one prediction per successful player cast: aura (+duration), amount range, cooldown end
function M:predict(spellID, targetKey, now)
    local k = self.knowledge[spellID] or {}
    local p = { t = now, spell = spellID, unit = targetKey, known = next(k) ~= nil }
    -- retro correlation: an unexplained aura added within the window BEFORE this cast (UNIT_AURA can precede
    -- UNIT_SPELLCAST_SUCCEEDED) on the cast's aura unit
    if k.aura then
        local aunit = (k.aura.self and "player") or targetKey
        for i = #self.unexplained, 1, -1 do
            local x = self.unexplained[i]
            if now - x.t <= self.window and (aunit == nil or x.unit == aunit)
                and (x.helpful == nil or k.aura.helpful == nil or x.helpful == k.aura.helpful) then
                table.remove(self.unexplained, i)
                local appl = self:Appliers(k.aura.helpful)
                local rule = (#appl == 1) and "single-applier" or "cast-correlation"
                local conf = (#appl == 1 or x.fromPlayer == true) and "high" or "medium"
                local u = self:unit(x.unit)
                local a = u.auras["i" .. tostring(x.iid)]
                if a then
                    a.spell, a.rule, a.conf, a.source = spellID, rule, conf, "inferred"
                    a.duration = a.duration or k.aura.duration
                    a.expires = a.duration and (x.t + a.duration) or nil
                end
                self.iidMap[x.unit .. "#" .. tostring(x.iid)] = { spell = spellID, rule = rule, conf = conf }
                self:infer({ rule = rule, kind = "applied", unit = x.unit, spell = spellID, iid = x.iid, conf = conf,
                    expires = a and a.expires, retro = true, t = x.t })
                p.outcome = "aura seen (" .. rule .. ")"
                break
            end
        end
    end
    if k.aura then
        local aunit = (k.aura.self and "player") or targetKey
        p.aura = { unit = aunit, duration = k.aura.duration, expires = k.aura.duration and (now + k.aura.duration) or nil,
            helpful = k.aura.helpful, id = k.auraId }
    end
    if k.amount then p.amount = { min = k.amount.min, max = k.amount.max, kind = k.amount.kind } end
    -- v2.2.2: totems are summons (a creature with a lifetime), not auras on the target; verified live by
    -- PLAYER_TOTEM_UPDATE/GetTotemInfo when readable (OnTotem), offline by SPELL_SUMMON -> UNIT_DIED/DESTROYED
    if k.summon then
        p.unit = "player"
        p.summon = { name = k.summon.name, duration = k.summon.duration, expires = k.summon.duration and (now + k.summon.duration) or nil }
        self.summons[#self.summons + 1] = { spell = spellID, t = now, pred = p, name = k.summon.name }
        if #self.summons > 8 then table.remove(self.summons, 1) end
    end
    if k.dispel then p.dispel = true end   -- no live truth without CLEU; offline: SPELL_DISPEL/_FAILED/STOLEN
    if k.cooldown and k.cooldown > 1.5 then
        p.cooldownEnds = now + k.cooldown
        self.cooldowns[spellID] = { start = now, ends = p.cooldownEnds, source = "predicted", pred = p }
    end
    self.seq = self.seq + 1
    p.id = self.seq
    self.counters.predictions = self.counters.predictions + 1
    self.version = self.version + 1
    push(self.predictions, p, self.maxLog)
    push(self.recent, { t = now, spell = spellID, target = targetKey, pred = p }, 16)
    if self.onPredict then pcall(self.onPredict, p) end
    return p
end

-- legacy view (MINOR <= 4): the raw predicted-cooldown record or nil
function M:CooldownRecord(spellID)
    local c = self.cooldowns[spellID]
    if c and c.ends and c.ends <= self.now() then self.cooldowns[spellID] = nil return nil end
    return c
end

----------------------------------------------------------------------------
-- auras
----------------------------------------------------------------------------
-- the player cast that best explains an aura appearing on unitKey now (within the window)
function M:explain(unitKey, helpful, now)
    local best
    for i = #self.recent, 1, -1 do
        local r = self.recent[i]
        if now - r.t > self.window then break end
        local k = self.knowledge[r.spell]
        if k and k.aura and (helpful == nil or k.aura.helpful == nil or k.aura.helpful == helpful) then
            local au = r.pred and r.pred.aura and r.pred.aura.unit
            if au == nil or au == unitKey or unitKey == nil then best = r break end
        end
    end
    return best
end

function M:addAura(unitKey, key, a)
    local u = self:unit(unitKey)
    local prev = u.auras[key]
    u.auras[key] = a
    self.version = self.version + 1
    if prev and a.refresh == nil then a.refresh = true end
    return a
end

function M:OnAura(unitKey, info)
    if type(info) ~= "table" then return end
    local now = self.now()
    self.counters.auraEvents = self.counters.auraEvents + 1
    local u = self:unit(unitKey)
    if (info.addedSecret or (info.added and #info.added > 0)) and unitKey == "player" then self:linkHit(now) end
    if info.addedSecret then
        if not self.legacy then self:frameBump(unitKey, now) end
        local p = self:verifyTiming(unitKey, now)
        -- MINOR 3: "not mine" by elimination: a secret added-aura on a non-player unit with no open aura prediction and
        -- no successful cast of mine inside the timing window was applied by someone else (or is a proc of theirs)
        if not p and not self.legacy and unitKey ~= "player" then
            -- v2.2.16: the own cast must be AT this unit and able to apply an aura (run 13 14:58:38: my Lesser Healing
            -- Wave on a friendly + another shaman's aura on it 63 ms later was claimed mine), and unambiguous
            local mine = self:ownFor(now, self.timingWindow, unitKey, "aura-target", true)
            local src, ev = self:gate("own-cast-frame", "aura-target", unitKey, now, mine, nil)
            local f = self:Fight()
            if src == "mine" then
                if f then f.auras.mine = f.auras.mine + 1 end
                self:infer({ rule = "own-cast-frame", kind = "applied", unit = unitKey, src = "mine", spell = mine.spell, conf = "medium", ev = ev })
            elseif src == "none" then
                if f then f.auras.unknown = (f.auras.unknown or 0) + 1 end
                self:infer({ rule = "aura-ambiguous", kind = "applied", unit = unitKey, src = "none", spell = mine and mine.spell, conf = "low", ev = ev })
            else
                if f then f.auras.other = f.auras.other + 1 end
                self:infer({ rule = "elimination", kind = "applied", unit = unitKey, src = "other", conf = "medium", ev = ev })
            end
        elseif p then
            local f = self:Fight()
            if f then f.auras.mine = f.auras.mine + 1 end
        elseif not self.legacy then
            -- on the player: any successful cast of mine in the window (self buffs, totem auras) explains it; without
            -- one it stays unattributed (procs, party buffs and my totems' pulses all arrive without a cast)
            local mine = self:ownWithin(now, self.timingWindow)
            local src, ev = "other", "no-cast"
            if mine and unitKey == "player" then
                -- v2.2.16 gate: a cast at me / self buff / summon, plausible (learned aura), unambiguous; an offensive cast
                -- in the window is U (my proc or someone's buff), never mine by timing alone
                local m2 = self:ownFor(now, self.timingWindow, "player", "aura-me")
                -- expected timing: the aura lands in the frame of my cast of a spell linked to an aura on me
                local cor = m2 and math.abs(now - m2.t) <= (self.linkWindow or 0.1) and self:plausible(m2, "aura-me") == "yes" and "timing" or nil
                -- target mismatch -> "other" (replay runs 9-13: 12 of 13 such auras were someone else's; was U)
                src, ev = self:gate("own-cast-frame", "aura-me", "player", now, m2, cor, "other")
                if src == "mine" then mine = m2 end
            elseif mine then src, ev = "mine", "legacy-unit" end
            if src == "mine" then
                self:infer({ rule = "own-cast-frame", kind = "applied", unit = unitKey, src = "mine", spell = mine.spell, conf = "medium", ev = ev })
            elseif src == "none" then
                self:infer({ rule = "aura-ambiguous", kind = "applied", unit = unitKey, src = "none", spell = mine and mine.spell, conf = "low", ev = ev })
            elseif unitKey == "player" and ev == "tm:no" then
                self:infer({ rule = "aura-me-elim", kind = "applied", unit = unitKey, src = "other", spell = mine and mine.spell, conf = "low", ev = ev })
            elseif unitKey == "player" then
                -- v2.2.15 PROMOTED (candidate c-aura-me-elim): no cast of mine in the window -> someone else's aura (BG:
                -- party/raid buffs, enemy debuffs). Replay aura-on-me 40.3/45.3/37.3/38.8 -> 97.2/87.4/88.8/91.0 % on runs
                -- 9-12, falseSelf unchanged (the "mine" claims are the old rule's). Was: left unattributed ("none").
                self:infer({ rule = "aura-me-elim", kind = "applied", unit = unitKey, src = "other", conf = "low" })
            end
            if self.candidates and unitKey == "player" then
                local t0 = self.clock and self.clock()
                -- c-aura-me-elim: no cast of mine explains it -> someone else's (same elimination the target path uses)
                self:cand("c-aura-me-elim", "aura-me", unitKey, mine and "mine" or "other", nil, mine and mine.spell)
                -- c-aura-me-self: only an own cast AT ME (self buff / totem) explains it; an offensive cast does not
                local selfc = mine and (mine.target == "player" or mine.summon)
                self:cand("c-aura-me-self", "aura-me", unitKey, selfc and "mine" or "other", nil, mine and mine.spell)
                -- c-aura-me-tight: half the timing window (0.35 -> 0.175 s), else other
                local t2 = self:ownWithin(now, self.timingWindow / 2)
                self:cand("c-aura-me-tight", "aura-me", unitKey, t2 and "mine" or "other", nil, t2 and t2.spell)
                self:candCostAdd("aura-me", t0)
            end
        end
    end
    if info.full then
        -- full update: keep inferred auras (they may still exist), drop observed ones we can no longer confirm
        for key, a in pairs(u.auras) do if a.source == "observed" then u.auras[key] = nil end end
        if self.ledger then for lkey in pairs(self.cachedIdx[unitKey] or {}) do self.ledger:Invalidate("aura", lkey) end end
    end
    local L = self.ledger
    for _, ad in ipairs(info.added or {}) do
        local spell, rule, conf = ad.spellId, nil, nil
        local lkey = ad.iid and (unitKey .. "#" .. tostring(ad.iid))
        if spell then
            rule, conf = "observed", "observed"
            if L and lkey then self:RecordAura(unitKey, ad, "UNIT_AURA") end   -- collect while clear
        elseif L and lkey and L.data.aura and L.data.aura[lkey] then
            -- resolve through the ledger: this instance was seen clear earlier (refresh / re-add of a known iid)
            local e, lconf = L:Get("aura", lkey)
            spell, rule, conf = e.spell, "ledger", (lconf == "cached-stale") and "low" or "medium"
            self.counters.ledger = (self.counters.ledger or 0) + 1
        else
            local r = self:explain(unitKey, ad.helpful, now)
            if r then
                local appl = self:Appliers(ad.helpful)
                rule = (#appl == 1) and "single-applier" or "cast-correlation"
                conf = (#appl == 1 or ad.fromPlayer == true) and "high" or "medium"
                spell = r.spell
            end
        end
        if not spell and ad.iid then   -- may be explained by a SUCCEEDED that arrives just after the aura (log order)
            push(self.unexplained, { t = now, unit = unitKey, iid = ad.iid, helpful = ad.helpful, fromPlayer = ad.fromPlayer }, 32)
        end
        local k = spell and self.knowledge[spell]
        local dur = ad.duration or (k and k.aura and k.aura.duration)
        local a = { spell = spell, iid = ad.iid, since = now, duration = dur, expires = dur and dur > 0 and (now + dur) or nil,
            applications = ad.applications, source = (rule == "observed") and "observed" or (rule and "inferred" or "unknown"),
            rule = rule or "none", conf = conf or "low", fromPlayer = ad.fromPlayer }
        self:addAura(unitKey, ad.iid and ("i" .. tostring(ad.iid)) or ("n" .. now), a)
        if ad.iid and spell then self.iidMap[unitKey .. "#" .. tostring(ad.iid)] = { spell = spell, rule = rule, conf = conf } end
        if spell then self:verify(spell, unitKey, rule) end
        if rule and rule ~= "observed" then
            self:infer({ rule = rule, kind = "applied", unit = unitKey, spell = spell, iid = ad.iid, conf = conf, expires = a.expires })
        elseif rule == "observed" then
            self:infer({ rule = "observed", kind = "applied", unit = unitKey, spell = spell, iid = ad.iid, conf = "observed", expires = a.expires })
        end
    end
    -- MINOR 4: a secret removed-list (presence readable) on a unit with exactly one live cached aura removes that one
    -- (ledger elimination); with several candidates they all turn stale (shown grey, not claimed as present)
    if L and info.removedSecret and not self.legacy then
        local cand, n = nil, 0
        for _, a in ipairs(self:CachedAuras(unitKey)) do n = n + 1 cand = a end
        if n == 1 and cand.lkey then
            L:Remove("aura", cand.lkey)
            self.cachedIdx[unitKey][cand.lkey] = nil
            self.counters.ledger = (self.counters.ledger or 0) + 1
            self:infer({ rule = "ledger-elimination", kind = "removed", unit = unitKey, spell = cand.spell, conf = "medium" })
        elseif n > 1 then
            for lkey in pairs(self.cachedIdx[unitKey] or {}) do L:Invalidate("aura", lkey) end
        end
    end
    for _, iid in ipairs(info.removed or {}) do
        local key = "i" .. tostring(iid)
        local a = u.auras[key]
        local m = self.iidMap[unitKey .. "#" .. tostring(iid)]
        local lkey = unitKey .. "#" .. tostring(iid)
        if L and not (a or m) then
            local e, lconf = L:Get("aura", lkey)
            if e then
                self.counters.ledger = (self.counters.ledger or 0) + 1
                self:infer({ rule = "ledger", kind = "removed", unit = unitKey, spell = e.spell, iid = iid,
                    conf = (lconf == "cached-stale") and "low" or "medium", age = now - (e.applied or now) })
            end
        end
        if L then
            L:Remove("aura", lkey)
            if self.cachedIdx[unitKey] then self.cachedIdx[unitKey][lkey] = nil end
        end
        if a or m then
            local spell = (a and a.spell) or (m and m.spell)
            self:infer({ rule = "iid-map", kind = "removed", unit = unitKey, spell = spell, iid = iid,
                conf = (m and m.conf) or (a and a.conf) or "low" })
            local kk = spell and self.knowledge[spell]
            if a and a.expires and now < a.expires - self.tolerance and kk and kk.aura and kk.aura.consumable then
                -- charge-based aura (Lightning Shield balls, ...): consumed early by design -> unverified, no contradiction
                self:verdict("aura-expiry", "U", { spell = spell, src = "UNIT_AURA removed (consumable)", conf = a.conf, d = a.expires - now })
            elseif a and a.expires and now < a.expires - self.tolerance then
                self:contradict({ kind = "aura-gone-early", unit = unitKey, spell = spell, early = a.expires - now, rule = a.rule })
                if a.pred then a.pred.outcome = "contradicted" end
                self:verdict("aura-expiry", "C", { spell = spell, src = "UNIT_AURA removed", conf = a.conf, d = a.expires - now })
            elseif a and a.expires then
                self:verdict("aura-expiry", "V", { spell = spell, src = "UNIT_AURA removed", conf = a.conf, d = a.expires - now })
            end
            u.auras[key] = nil
            self.iidMap[unitKey .. "#" .. tostring(iid)] = nil
        end
    end
end

-- readable count deltas: +n after my cast -> inferred application(s) of that cast's aura
function M:OnCount(unitKey, filter, count)
    if type(count) ~= "number" then self.counters.unreadable = self.counters.unreadable + 1 return end
    local now = self.now()
    local u = self:unit(unitKey)
    local prev = u.counts[filter]
    u.counts[filter] = count
    if prev == nil or count == prev then return end
    local helpful = filter:find("HELPFUL") ~= nil
    if count > prev and filter:find("PLAYER") then
        local r = self:explain(unitKey, helpful, now)
        if r then
            local appl = self:Appliers(helpful)
            local k = self.knowledge[r.spell]
            local dur = k and k.aura and k.aura.duration
            local rule = (#appl == 1) and "single-applier" or "count-delta"
            local a = { spell = r.spell, since = now, duration = dur, expires = dur and (now + dur) or nil, source = "inferred",
                rule = rule, conf = (#appl == 1) and "high" or "medium" }
            self:addAura(unitKey, "c" .. tostring(r.spell), a)
            self:infer({ rule = rule, kind = "applied", unit = unitKey, spell = r.spell, conf = a.conf, expires = a.expires, delta = count - prev })
            self:verify(r.spell, unitKey, rule)
        end
    elseif count < prev then
        self:infer({ rule = "count-delta", kind = "removed", unit = unitKey, conf = "medium", delta = count - prev, filter = filter })
    end
end

-- live verification: the newest open prediction for this spell (and unit when known) gets the rule that confirmed it
function M:verify(spell, unitKey, rule)
    local now = self.now()
    for i = #self.recent, 1, -1 do
        local r = self.recent[i]
        if now - r.t > self.window * 4 then break end
        local p = r.pred
        local unitOk = (p and p.aura and (p.aura.unit == nil or p.aura.unit == unitKey))
            or (p and not p.aura and rule == "observed" and (p.unit == nil or p.unit == unitKey or unitKey == "player"))
        if p and p.spell == spell and p.outcome == nil and unitOk then
            -- v2.2.3: a prediction without aura knowledge (Ghost Wolf, run 4) is confirmed by an observed aura with the
            -- same clear spellId; the aura becomes knowledge (duration 0 = until cancelled)
            p.outcome = "aura seen (" .. tostring(rule) .. ")"
            self.version = self.version + 1
            local u = self.units[unitKey]
            if u then for _, a in pairs(u.auras) do if a.spell == spell and a.since >= p.t then a.pred = p end end end
            return p
        end
    end
end

-- v2.2.3: in combat UNIT_AURA's addedAuras is a wholly secret list or nil (run 3/4). "secret" vs nil is itself a clear
-- yes/no, so an added-aura event on the predicted unit inside the window confirms the newest open aura prediction by
-- event timing only (no field is read). Weaker than "observed": outcome says so, conf medium.
function M:verifyTiming(unitKey, now)
    for i = #self.recent, 1, -1 do
        local r = self.recent[i]
        if now - r.t > self.timingWindow then break end   -- v2.2.4: 0.35 s (was window*4 = 2.4 s: run 5 showed it can
        local p = r.pred                                     -- swallow another player's aura); legacy keeps 2.4 s
        -- v2.2.16 target match: a prediction with no unit only matches an aura on me (self buff / learned self link)
        local um = p and p.aura and (p.aura.unit == unitKey or (p.aura.unit == nil and (not self.attrGuard or unitKey == "player")))
        if um and p.outcome == nil then
            p.outcome = "aura event seen (secret payload, timing)"
            p.timingOnly = true
            -- ambiguity guard: with same-class actors / a crowded frame only a same-frame arrival corroborates
            local src, ev = "mine", "tm,pl,cor:timing"
            if self.attrGuard then
                local amb = self:ambiguity(unitKey, now, unitKey == "player" and "aura-me" or "aura-target")
                if amb and now - r.t > (self.linkWindow or 0.1) then src, ev = "none", "amb:" .. amb
                elseif amb then ev = "amb:" .. amb .. ",cor:timing" end
                local st = self.attrStats["secret-timing"]
                if not st then
                    st = { mine = 0, other = 0, none = 0, implausible = 0, mismatch = 0, ambiguous = 0, corroborated = 0 }
                    self.attrStats["secret-timing"] = st
                end
                st[src] = st[src] + 1
                if amb then st.ambiguous = st.ambiguous + 1 if src == "mine" then st.corroborated = st.corroborated + 1 end end
            end
            self:infer({ rule = "secret-timing", kind = "applied", unit = unitKey, spell = p.spell, conf = "medium",
                auraId = p.aura and p.aura.id,   -- MINOR 4: the debuff/buff spellID my cast applies (learned mapping)
                expires = p.aura.expires, src = src, ev = ev })
            return p
        end
    end
end

function M:Tick()
    local now = self.now()
    if self.shadowFindings and self.shadowDm7Expect and (now - self.shadowDm7Expect) > ((self.dmWindow or 0.03) + 0.1) then
        self:verdict("shadow-dm-type7", "U", { src = "DAMAGE_METER type 7 with no UNIT_COMBAT wound", conf = "medium",
            d = now - self.shadowDm7Expect })
        self.shadowDm7Expect = nil
    end
    for i = #self.recent, 1, -1 do
        local p = self.recent[i].pred
        if p and p.aura and p.outcome == nil and now - p.t > self.window * 4 then p.outcome = "no aura seen" end
    end
    for unitKey, u in pairs(self.units) do
        local any = false
        for key, a in pairs(u.auras) do
            if a.expires and now > a.expires + self.tolerance and a.source ~= "observed" then
                u.auras[key] = nil
                self:verdict("aura-expiry", "U", { spell = a.spell, src = "predicted-expiry (removal not readable)", conf = a.conf })
                self:infer({ rule = "predicted-expiry", kind = "expired", unit = unitKey, spell = a.spell, conf = a.conf })
            elseif not a.expires and a.source ~= "observed" and now - (a.since or now) > (self.unknownTTL or 300) then
                u.auras[key] = nil   -- v2.2.3: unknown-duration auras no longer accumulate forever
                self.version = self.version + 1
            else any = true end
        end
        -- v2.2.3: drop empty per-unit state (one entry per GUID seen used to stay for the whole session)
        if not any and unitKey ~= "player" and not (self.casts[unitKey] and self.casts[unitKey].active) then
            self.units[unitKey] = nil
            self.casts[unitKey] = nil
        end
    end
    for id, c in pairs(self.cooldowns) do if c.ends and c.ends <= now then self.cooldowns[id] = nil self.version = self.version + 1 end end
end

-- ledger: auraInstanceID -> identity, recorded while clear (UNIT_AURA addedAuras, or an out-of-combat full scan).
-- ad = { iid, spellId, duration, expirationTime?, helpful, fromPlayer }
function M:RecordAura(unitKey, ad, src)
    local L = self.ledger
    if not (L and ad and ad.iid and ad.spellId) then return nil end
    local now, dur = self.now(), ad.duration
    local exp = ad.expirationTime
    if not (type(exp) == "number" and exp > 0) then exp = (type(dur) == "number" and dur > 0) and (now + dur) or false end
    local lkey = unitKey .. "#" .. tostring(ad.iid)
    local old = L.data.aura and L.data.aura[lkey]
    if not old and self.onAuraRecord then pcall(self.onAuraRecord, unitKey, ad, now) end   -- learned DB: cast -> aura map
    L:Put("aura", lkey, { spell = ad.spellId, duration = dur, helpful = ad.helpful, fromPlayer = ad.fromPlayer, unit = unitKey,
        applied = old and old.applied or now, expires = exp }, src or "UNIT_AURA")
    self.cachedIdx[unitKey] = self.cachedIdx[unitKey] or {}
    self.cachedIdx[unitKey][lkey] = true
    return lkey
end

-- auras of a unit known from the ledger (seen clear earlier, not removed, not past their cached expiry): what the HSM
-- believes is present during a secret period. Each: { spell, conf ("cached-fresh"/"cached-stale"), age, expires }
function M:CachedAuras(unitKey)
    local out = {}
    local L, idx = self.ledger, self.cachedIdx[unitKey]
    if not (L and idx) then return out end
    local now = self.now()
    for lkey in pairs(idx) do
        local e = L.data.aura and L.data.aura[lkey]
        if not e then idx[lkey] = nil
        elseif e.expires and e.expires ~= false and now > e.expires + self.tolerance then idx[lkey] = nil
        else
            local age = now - (e.t or now)
            -- maybe-removed: an ambiguous secret removal hit this unit since the value was cached (never claimed as present)
            out[#out + 1] = { spell = e.spell, conf = e.stale and "maybe-removed" or (age > L.fresh and "cached-stale" or "cached-fresh"), age = age,
                expires = e.expires ~= false and e.expires or nil, applied = e.applied, lkey = lkey, invalidated = e.stale or nil }
        end
    end
    return out
end

function M:UnitState(unitKey) return self.units[unitKey] end

-- PLAYER_TOTEM_UPDATE(slot) + GetTotemInfo(slot): have/name/start/duration, each nil when unreadable (secret).
-- A new totem verifies the newest open summon prediction (name match when readable, else the newest within the window);
-- a readable engine duration is compared with the predicted lifetime.
function M:OnTotem(slot, have, name, duration)
    local now = self.now()
    self.version = self.version + 1
    local prev = self.totems[slot]
    if have == true then
        if prev and prev.pred and prev.pred.summon then prev.pred.summon.endedAt = now - prev.pred.t end
        if prev then self:infer({ rule = "totem-update", kind = "summon-replaced", unit = "player", spell = prev.spell, slot = slot, conf = "high" }) end
        local best
        for i = #self.summons, 1, -1 do
            local s = self.summons[i]
            if s.pred.outcome == nil and now - s.t <= self.window * 4 and (name == nil or s.name == nil or s.name == name) then best = s break end
        end
        self.totems[slot] = { since = now, name = name, duration = duration, spell = best and best.spell, pred = best and best.pred }
        if best then
            local p = best.pred
            p.outcome = "totem seen (GetTotemInfo)"
            if type(duration) == "number" and duration > 0 then
                p.summon.engineDuration = duration
                if p.summon.duration and math.abs(p.summon.duration - duration) > self.tolerance then
                    self:contradict({ kind = "summon-duration", spell = best.spell, predicted = p.summon.duration, engine = duration })
                end
            end
            self:infer({ rule = "totem-update", kind = "summoned", unit = "player", spell = best.spell, slot = slot, conf = "high",
                expires = p.summon.expires })
        else
            self:infer({ rule = "totem-update", kind = "summoned", unit = "player", slot = slot, conf = "low" })
        end
    elseif have == false and prev then
        local p = prev.pred
        local early = p and p.summon and p.summon.expires and (p.summon.expires - now) or nil
        if p and p.summon then p.summon.endedAt = now - p.t end
        self:infer({ rule = "totem-update", kind = (early and early > self.tolerance) and "summon-ended-early" or "summon-ended",
            unit = "player", spell = prev.spell, slot = slot, conf = "high", early = early })
        self.totems[slot] = nil
    end
end


----------------------------------------------------------------------------
-- Ledger (MINOR 3, v2.2.4): "collect while available, retain, resolve later". Every value seen CLEAR is recorded with a
-- timestamp and source; during secret periods lookups resolve through it with a confidence derived from staleness.
-- Kinds (free-form strings): "guid" (GUID -> name/class/level/hpMax/powerMax/isPlayer/friend), "token" (unit token ->
-- last clear GUID), "aura" (unitKey#auraInstanceID -> spellId/duration/helpful/fromPlayer/applied), "cast" (unitKey ->
-- last clear cast), "plate" (nameplateN -> GUID). Per-kind LRU caps; eviction is an amortised O(1) sweep by access stamp.
-- Values must be clear (the caller checks); nothing here reads the game.
----------------------------------------------------------------------------
local LedgerM = {}
LedgerM.__index = LedgerM
local LEDGER_CAPS = { guid = 300, token = 64, aura = 400, cast = 64, plate = 40, fingerprint = 300 }
Lib.LEDGER_CAPS = LEDGER_CAPS

function Lib.NewLedger(opts)
    opts = opts or {}
    local l = setmetatable({}, LedgerM)
    l.now = opts.now or defaultNow
    l.caps = {}
    for k, v in pairs(LEDGER_CAPS) do l.caps[k] = v end
    for k, v in pairs(opts.caps or {}) do l.caps[k] = v end
    l.fresh = opts.fresh or 10        -- s: younger = "cached-fresh" (high), older = "cached-stale" (low)
    l.data, l.n, l.seq, l.version = {}, {}, 0, 0
    l.stats = { puts = 0, live = 0, fresh = 0, stale = 0, miss = 0, evicted = 0, invalidated = 0 }
    return l
end

function LedgerM:sweep(kind)
    local t, cap = self.data[kind], self.caps[kind] or 100
    local slack = math.max(8, math.floor(cap / 4))
    if (self.n[kind] or 0) <= cap + slack then return end
    -- keep the `cap` most recently touched: stamps are unique and increasing, so everything older than seq - cap goes
    local cut, n = self.seq - cap, 0
    for k, e in pairs(t) do
        if e.seq <= cut then t[k] = nil self.stats.evicted = self.stats.evicted + 1 else n = n + 1 end
    end
    self.n[kind] = n
end

-- record clear fields for (kind, key); fields merge into the entry (nil fields keep the older clear value)
function LedgerM:Put(kind, key, fields, src)
    if key == nil or type(fields) ~= "table" then return nil end
    local t = self.data[kind]
    if not t then t = {} self.data[kind] = t end
    local e = t[key]
    if not e then e = {} t[key] = e self.n[kind] = (self.n[kind] or 0) + 1 end
    local changed = false
    for k, v in pairs(fields) do if e[k] ~= v then e[k] = v changed = true end end
    self.seq = self.seq + 1
    e.seq, e.t, e.src = self.seq, self.now(), src or e.src
    e.first = e.first or e.t
    e.stale = nil
    self.stats.puts = self.stats.puts + 1
    if changed then self.version = self.version + 1 end
    self:sweep(kind)
    return e
end

-- entry, confidence ("live" same frame / "cached-fresh" / "cached-stale"), age in s
function LedgerM:Get(kind, key)
    local t = self.data[kind]
    local e = t and key ~= nil and t[key]
    if not e then self.stats.miss = self.stats.miss + 1 return nil end
    self.seq = self.seq + 1
    e.seq = self.seq
    local age = self.now() - e.t
    local conf = (age <= 0.05 and not e.stale and "live") or ((age <= self.fresh and not e.stale) and "cached-fresh") or "cached-stale"
    self.stats[conf == "live" and "live" or (conf == "cached-fresh" and "fresh" or "stale")] =
        self.stats[conf == "live" and "live" or (conf == "cached-fresh" and "fresh" or "stale")] + 1
    return e, conf, age
end

-- the mapping may no longer hold (token changed while its GUID is unreadable): keep the value, mark it stale
function LedgerM:Invalidate(kind, key)
    local e = self.data[kind] and self.data[kind][key]
    if e and not e.stale then e.stale = true self.stats.invalidated = self.stats.invalidated + 1 self.version = self.version + 1 end
end

function LedgerM:Remove(kind, key)
    local t = self.data[kind]
    if t and t[key] then t[key] = nil self.n[kind] = (self.n[kind] or 1) - 1 self.version = self.version + 1 end
end

function LedgerM:Count(kind) return self.n[kind] or 0 end

-- fingerprint resolution for a secret GUID: clear signals (class, level, hpMax, isPlayer, friend) matched against the
-- GUID entries recorded while clear. Unique match -> medium, several -> low (first returned), none -> nil
function LedgerM:Fingerprint(fp)
    if type(fp) ~= "string" or fp == "" then return nil end
    local e = self.data.fingerprint and self.data.fingerprint[fp]
    if not e then return nil end
    return e.guid, (e.count or 1) == 1 and "medium" or "low"
end
function LedgerM:PutFingerprint(fp, guid)
    if type(fp) ~= "string" or fp == "" or guid == nil then return end
    local e = self.data.fingerprint and self.data.fingerprint[fp]
    if e and e.guid ~= guid then
        self:Put("fingerprint", fp, { guid = guid, count = (e.count or 1) + 1 }, "fingerprint")
    elseif not e then self:Put("fingerprint", fp, { guid = guid, count = 1 }, "fingerprint") end
end

-- SavedVariables-safe summary: counts only (names/GUIDs stay in memory)
function LedgerM:Export()
    local n = {}
    for k, v in pairs(self.n) do n[k] = v end
    local st = {}
    for k, v in pairs(self.stats) do st[k] = v end
    return { counts = n, stats = st, caps = self.caps }
end

----------------------------------------------------------------------------
-- MINOR 3: fights + source attribution (clear inputs only: UNIT_COMBAT, PLAYER_SWING, DAMAGE_METER_* event type,
-- my UNIT_SPELLCAST_SUCCEEDED, UNIT_SPELLCAST_INTERRUPTED timing). Every attribution carries its rule.
----------------------------------------------------------------------------
local function newFight(t)
    return { start = t, dmg = { mine = 0, other = 0, mineN = 0, otherN = 0, crit = 0, miss = 0, rules = {} }, otherSchools = {},
        taken = { amount = 0, n = 0, miss = 0 }, heal = { mine = 0, other = 0, mineN = 0, otherN = 0, rules = {} },
        interrupts = { mine = 0, other = 0 }, dispels = { mine = 0, other = 0 },
        auras = { mine = 0, other = 0 }, power = 0,
        -- v2.2.6: live running estimates (own casts + meter timing + UNIT_COMBAT) for post-combat self-reconcile.
        -- world[unitKey] = per-unit taken/dmg/heal/interrupt/dispel estimates keyed by identity IdKey when known.
        liveEst = { damage = 0, healing = 0, interrupts = 0, dispels = 0, taken = 0, dmTicks = {} },
        world = {} }
end


function M:SetGroupSize(n)
    if type(n) == "number" and n >= 1 then self.groupSize = n end
    return self.groupSize
end

local function worldIdKey(self, unitKey)
    if not unitKey or unitKey == "player" then return "player" end
    if self.idKey then
        local kind = "guid"
        if type(unitKey) == "string" then
            if unitKey:find("^Player%-") then kind = "player"
            elseif unitKey:find("^Creature%-") or unitKey:find("^Vehicle%-") then
                local nid = unitKey:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
                    or unitKey:match("^Vehicle%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
                if nid then return "npc:" .. nid end
                kind = "npc"
            elseif unitKey:find("^Pet%-") then kind = "pet"
            elseif unitKey:find("^npc:") or unitKey:find("^player:") or unitKey:find("^pet:") then return unitKey
            end
        end
        return self.idKey(kind, unitKey) or unitKey
    end
    if type(unitKey) == "string" then
        local nid = unitKey:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
        if nid then return "npc:" .. nid end
    end
    return unitKey
end

local function worldUnit(self, f, unitKey)
    if not unitKey then return nil end
    local w = f.world[unitKey]
    if not w then
        w = { taken = 0, takenN = 0, dmg = 0, dmgN = 0, heal = 0, healN = 0, interrupts = 0, dispels = 0,
            dmTicks = {}, lastTakenT = nil, dtps = 0, idKey = worldIdKey(self, unitKey) }
        f.world[unitKey] = w
        if w.idKey and w.idKey ~= unitKey then f.world[w.idKey] = f.world[w.idKey] or w end
    end
    return w
end

local function liveBump(f, field, amt)
    local e = f.liveEst
    if not e then return end
    e[field] = (e[field] or 0) + (amt or 0)
end

function M:Fight() return self.fight end

function M:OnCombatState(inCombat)
    local now = self.now()
    self.version = self.version + 1
    if self.hp.player then self:hpAnchor(self.hp.player, now) end
    self.inCombat = inCombat and true or false
    if inCombat then
        if self.fight and not self.fight.stop and not self.fight.soft then return self.fight end
        if self.fight and not self.fight.stop then self.fight.stop = now end   -- close an after-combat soft record
        self.fight = newFight(now)
        push(self.fights, self.fight, self.maxFights)
        push(self.recentFights, self.fight, RECENT_N) self.recentPushed = (self.recentPushed or 0) + 1
        self:infer({ rule = "regen", kind = "combat-start", conf = "observed" })
    elseif self.fight and not self.fight.stop then
        self.fight.stop = now
        self:infer({ rule = "regen", kind = "combat-end", conf = "observed", mine = self.fight.dmg.mine, other = self.fight.dmg.other })
    end
    return self.fight
end

-- a successful cast of mine within w seconds before (or the same frame after) now; offensive = only casts that did
-- not land on the player (a self heal in the same frame must not claim another player's hit)
function M:ownWithin(now, w, offensive)
    for i = #self.ownRecent, 1, -1 do
        local r = self.ownRecent[i]
        local dt = now - r.t
        if dt > w then break end
        -- a summon counts as offensive: a totem's debuff (Earthbind) lands on the target with no cast at the target
        if dt >= -self.sameFrame and not (offensive and r.target == "player" and not r.summon) then return r end
    end
end

----------------------------------------------------------------------------
-- v2.2.16 attribution safety gate
----------------------------------------------------------------------------
-- census: same-class actors around me (friendly group members / enemy players with my class; clear UnitClass)
function M:SetCensus(c)
    if type(c) ~= "table" then return end
    local cc = self.census
    cc.sameClass = tonumber(c.sameClass) or cc.sameClass or 0
    cc.sameClassEnemy = tonumber(c.sameClassEnemy) or cc.sameClassEnemy or 0
    cc.n = tonumber(c.n) or cc.n or 0
    cc.t = self.now()
end

-- crowd: events on unitKey inside the current frame (this one included)
function M:frameBump(unitKey, now)
    local fe = self.frameEv[unitKey]
    if fe and now - fe.t <= self.sameFrame then fe.n = fe.n + 1 return fe.n end
    if not fe then fe = {} self.frameEv[unitKey] = fe end
    fe.t, fe.n = now, 1
    return 1
end
function M:frameCount(unitKey, now)
    local fe = self.frameEv[unitKey]
    return (fe and now - fe.t <= self.sameFrame) and fe.n or 0
end

-- learned link "my cast of spell X puts an aura on ME" (self buff, or a self proc of an offensive spell such as
-- Stormstrike): an aura add on me in the same frame as the cast counts a hit; linked after >= 4 casts with a hit
-- rate >= 60 % (a random aura add on me lands in a 60 ms window ~10 % of the time in a BG). Knowledge aura.self seeds it.
function M:linkHit(now)
    for i = #self.ownRecent, 1, -1 do
        local r = self.ownRecent[i]
        local dt = now - r.t
        if dt > self.sameFrame then break end
        if dt >= -self.sameFrame and r.spell and not r.linkHit then
            r.linkHit = true
            local sl = self.selfLink[r.spell]
            if sl then sl.hits = sl.hits + 1 end
        end
    end
end
-- seed (persisted cross-session stats, or the shipped Data/SelfLinkSeed.lua from earlier captures' live signals)
function M:SeedSelfLink(spell, casts, hits)
    if type(spell) ~= "number" or type(casts) ~= "number" or type(hits) ~= "number" then return end
    local sl = self.selfLink[spell]
    if not sl then sl = { casts = 0, hits = 0 } self.selfLink[spell] = sl end
    sl.casts, sl.hits = sl.casts + casts, sl.hits + hits
end
function M:selfLinked(spell)
    local k = spell and self.knowledge[spell]
    if k and k.aura and k.aura.self then return true end
    local sl = spell and self.selfLink[spell]
    return sl ~= nil and sl.casts >= 4 and sl.hits >= 0.6 * sl.casts
end

-- effective target of an own cast: self buffs and summons land on me whatever was targeted
local function effTarget(self, r)
    local k = r.spell and self.knowledge[r.spell]
    if r.summon or (k and (k.summon or (k.aura and k.aura.self))) then return "player" end
    -- v2.2.16 (run 13 14:58:38): a self buff with no aura knowledge was guessed "at my friendly target"; a learned
    -- self link (>= 4 casts, >= 60% same-frame aura on me) overrides the cast-time target guess
    if self.selfLinked and self:selfLinked(r.spell) then return "player" end
    return r.target
end
Lib.effTarget = effTarget

-- spell plausibility of my cast for this change: "yes" | "no" | "unknown" (no learned link either way)
-- what = aura-me | aura-target | heal-me | heal-target | damage | interrupt
function M:plausible(r, what)
    local k = r and r.spell and self.knowledge[r.spell]
    if what == "aura-me" and r and self:selfLinked(r.spell) then return "yes" end
    if not k then return r and r.summon and "yes" or "unknown" end
    local am = k.amount and k.amount.kind
    local healish = am == "heal" or k.helpful == true
    if what == "aura-me" or what == "aura-target" then
        if k.summon then return "yes" end   -- totem auras / pulses (Earthbind on the target, Strength of Earth on me)
        if not k.aura then return (am or k.interrupt) and "no" or "unknown" end   -- a learned heal/damage spell with no aura
        if what == "aura-target" and k.aura.self then return "no" end           -- a self buff never lands on another unit
        return "yes"
    elseif what == "heal-me" or what == "heal-target" then
        if healish or k.summon then return "yes" end
        if am == "damage" or (k.aura and k.aura.helpful == false) or k.interrupt then return "no" end
        return "unknown"
    elseif what == "damage" then
        if healish or (k.aura and k.aura.self and not am) then return "no" end
        if am == "damage" or (k.aura and k.aura.helpful == false) or k.interrupt or k.summon then return "yes" end
        return "unknown"
    elseif what == "interrupt" then
        if k.interrupt then return "yes" end
        if healish or (k.aura and k.aura.self) then return "no" end
        return "unknown"
    end
    return "unknown"
end

-- target match: my cast's (effective) target is the unit that changed
function M:targetMatch(r, what, unitKey)
    if not r then return false end
    local et = effTarget(self, r)
    if what == "aura-me" then return et == "player" or self:selfLinked(r.spell) end
    if what == "heal-me" then return et == "player" end
    local k = r.spell and self.knowledge[r.spell]
    if (what == "aura-target" or what == "damage") and (r.summon or (k and k.summon)) then return true end
    return et ~= "player" and r.target ~= nil and r.target == unitKey
end

-- ambiguity: why a claim on unitKey is not unique (nil = unique). On me only friendly same-class actors compete (an
-- enemy's debuff on me is excluded by target match: my offensive cast was not at me); elsewhere both sides do.
function M:ambiguity(unitKey, now, what)
    if self:frameCount(unitKey, now) >= 2 then return "crowd" end
    local c = self.census
    local n = c.sameClass or 0
    if not (what == "aura-me" or what == "heal-me") then n = n + (c.sameClassEnemy or 0) end
    if n > 0 then return "same-class" end
end

-- amount inside the learned band of my spell (crit stretch like damage-range)
function M:inBand(r, amt, crit)
    local k = r and r.spell and self.knowledge[r.spell]
    local b = k and k.amount
    if not (b and b.min and type(amt) == "number" and amt > 0) then return nil end
    local lo, hi = b.min * (crit and 1.4 or 0.9), (b.max or b.min) * (crit and 2.1 or 1.35)
    return amt >= lo and amt <= hi
end

-- the gate. own = candidate cast (nil = none); cor = corroboration tag already established by the caller (or nil).
-- -> src ("mine" | "other" | "none"), ev (evidence string: tm/pl/amb/cor)
function M:gate(rule, what, unitKey, now, own, cor, onMismatch)
    local st = self.attrStats[rule]
    if not st then st = { mine = 0, other = 0, none = 0, implausible = 0, mismatch = 0, ambiguous = 0, corroborated = 0 } self.attrStats[rule] = st end
    if not own then st.other = st.other + 1 return "other", "no-cast" end
    if not self.attrGuard then st.mine = st.mine + 1 return "mine", "legacy" end
    local pl = self:plausible(own, what)
    if pl == "no" then st.implausible, st.other = st.implausible + 1, st.other + 1 return "other", "pl:no" end
    if not self:targetMatch(own, what, unitKey) then
        st.mismatch = st.mismatch + 1
        local src = onMismatch or "other"
        st[src] = st[src] + 1
        return src, "tm:no"
    end
    local amb = self:ambiguity(unitKey, now, what)
    -- an unlearned spell (plausibility unknown) with a target match and no competitor is allowed: replay of runs 9-13
    -- is identical either way (BGs always carry the ambiguity), and solo/PvE keeps its target-matched claims
    if amb then
        if cor then
            st.corroborated, st.mine = st.corroborated + 1, st.mine + 1
            return "mine", "amb:" .. amb .. ",cor:" .. cor
        end
        st.ambiguous, st.none = st.ambiguous + 1, st.none + 1
        return "none", "amb:" .. amb
    end
    st.mine = st.mine + 1
    return "mine", "tm,pl"
end

-- newest own cast within w that passes target match + plausibility for `what` (else the newest one, for the gate)
function M:ownFor(now, w, unitKey, what, offensive)
    local first
    for i = #self.ownRecent, 1, -1 do
        local r = self.ownRecent[i]
        local dt = now - r.t
        if dt > w then break end
        if dt >= -self.sameFrame and not (offensive and r.target == "player" and not r.summon) then
            first = first or r
            if self:plausible(r, what) ~= "no" and self:targetMatch(r, what, unitKey) then return r, first end
        end
    end
    return first, first
end

function M:OnSwing()
    push(self.swings, { t = self.now() }, 8)
end

function M:OnDamageMeter(dmType)
    if type(dmType) ~= "number" then return end
    local now = self.now()
    self.dmLast[dmType] = now
    local f = self.fight
    if f and f.liveEst then
        f.liveEst.dmTicks[dmType] = (f.liveEst.dmTicks[dmType] or 0) + 1
    end
    -- type 6 = Dispels: join with a recent own dispel-capable cast (no CLEU SPELL_DISPEL live)
    if dmType == 6 and f then
        local own = self:ownWithin(now, self.sameFrame or 0.05, true)
        local k = own and own.spell and self.knowledge[own.spell]
        -- v2.2.17 (run 14: live 18-20 vs meter 8-9 dispels): the meter fires several type-6 updates for ONE dispel
        -- (and for every group member's dispel); one own dispel cast counts at most once
        if own and k and k.dispel and not own.dispelCounted then
            own.dispelCounted = true
            f.dispels.mine = f.dispels.mine + 1
            liveBump(f, "dispels", 1)
            self:infer({ rule = "dispel-cast+dm", kind = "dispel", unit = own.target, src = "mine",
                spell = own.spell, conf = "high" })
        end
    end
    -- shadow: DM type 7 ↔ enemy melee on me (finding dm-type-7); expect a WOUND shortly
    if self.shadowFindings and dmType == 7 then
        self.shadowDm7Expect = now
    end
end

local function dmNear(self, now, types, w)
    for _, ty in ipairs(types) do
        local t = self.dmLast[ty]
        if t and math.abs(now - t) <= w then return ty end
    end
end
local DM_DAMAGE, DM_HEAL, DM_INTERRUPT, DM_TAKEN = { 0, 1, 10 }, { 2, 3 }, { 5 }, { 7 }

local function fightOrOpen(self, now)
    if not self.fight or self.fight.stop then
        -- UNIT_COMBAT outside a REGEN window (e.g. heals ticking after combat): a soft fight record is opened lazily
        self.fight = newFight(now)
        self.fight.soft = true
        push(self.fights, self.fight, self.maxFights)
        push(self.recentFights, self.fight, RECENT_N) self.recentPushed = (self.recentPushed or 0) + 1
    end
    return self.fight
end

local MISS = { MISS = true, DODGE = true, PARRY = true, BLOCK = true, RESIST = true, IMMUNE = true, EVADE = true, ABSORB = true,
    DEFLECT = true, REFLECT = true }
Lib.MISS = MISS

-- the rule that makes a hostile-unit UNIT_COMBAT mine (nil = someone else's)
-- v2.2.16: returns rule, conf, src, ev. src = "mine" | "none" (ambiguous) | nil (someone else's). The cast-frame claim
-- passes the gate (cast at this unit, a damage-capable spell, unambiguous or inside the learned amount band); the
-- melee rules are backed by the PLAYER_SWING token but are U when several hits land on the unit in one frame.
function M:damageRule(now, school, unitKey, amt, crit)
    if self.attrGuard and self.ucFriendly then   -- v2.2.16: damage on a group member (raidN/partyN) is never mine
        local st = self.attrStats["friendly-wound"] or { mine = 0, other = 0, none = 0, implausible = 0, mismatch = 0, ambiguous = 0, corroborated = 0 }
        self.attrStats["friendly-wound"] = st
        st.other = st.other + 1
        return nil
    end
    local any = self:ownWithin(now, self.sameFrame, true)
    if any then
        local own = self:ownFor(now, self.sameFrame, unitKey, "damage", true)
        local band = self:inBand(own, amt, crit)
        local src, ev = self:gate("cast-frame", "damage", unitKey, now, own, band and "band" or nil, "other")
        if src == "mine" then return "cast-frame", "high", "mine", ev, own end
        if src == "none" then return "cast-ambiguous", "low", "none", ev, own end
    end
    if self.groupSize <= 1 and dmNear(self, now, DM_DAMAGE, self.dmWindow) then return "dm-frame", "high", "mine" end
    local crowd = unitKey and self.attrGuard and self:frameCount(unitKey, now) >= 2
    -- v2.2.16 target match for melee: my swing only lands on my target (ucIsTarget false = another unit's hit)
    if self.attrGuard and self.ucIsTarget == false then
        local st = self.attrStats["swing"] or { mine = 0, other = 0, none = 0, implausible = 0, mismatch = 0, ambiguous = 0, corroborated = 0 }
        self.attrStats["swing"] = st
        st.mismatch, st.other = st.mismatch + 1, st.other + 1
        return nil
    end
    for i = #self.swings, 1, -1 do
        local s = self.swings[i]
        local dt = now - s.t
        if math.abs(dt) <= self.sameFrame and not s.used then
            s.used = true
            if crowd then return "swing-ambiguous", "low", "none", "amb:crowd" end
            return "swing-frame", "high", "mine", "token:swing"
        end
    end
    if school == nil or school == 1 then   -- melee lands in combat text ~0.46 s after PLAYER_SWING (physical school)
        for i = 1, #self.swings do
            local s = self.swings[i]
            local dt = now - s.t
            if not s.used and dt >= self.swingLag[1] and dt <= self.swingLag[2] then
                s.used = true
                if crowd then return "swing-ambiguous", "low", "none", "amb:crowd" end
                return "swing-lag", "medium", "mine", "token:swing-lag"
            end
        end
    end
end

function M:OnUnitCombat(unitKey, action, flag, amount, school, isPlayerUnit)
    if self.legacy or type(action) ~= "string" then return nil end
    local now = self.now()
    local f = fightOrOpen(self, now)
    f.lastT = now   -- v2.2.12: last activity (a soft record stays open until the next combat: its stop is not activity)
    local amt = 0
    if type(amount) == "number" then amt = amount end
    self.version = self.version + 1
    -- v2.2.16 shadow c-hp-net: per-unit net HP estimate from readable UNIT_COMBAT amounts + cached max health,
    -- scored live against clear UnitHealth (CandHealthActual) and offline against combat-log health
    if self.candidates and not isPlayerUnit and unitKey ~= nil and amt > 0 and (action == "WOUND" or action == "HEAL") then
        local delta = -amt
        if action == "HEAL" then delta = amt end
        self:hpApply(unitKey, delta, now)
    end
    if isPlayerUnit then
        if action == "HEAL" then
            local rule, conf
            self:frameBump("player", now)
            local own = self:ownWithin(now, self.sameFrame)
            local gsrc, gev
            if own then
                -- v2.2.16 gate: cast at me, a heal spell, unambiguous or inside the learned amount band
                local o2 = self:ownFor(now, self.sameFrame, "player", "heal-me")
                local band = self:inBand(o2, amt, flag == "CRITICAL")
                gsrc, gev = self:gate("cast-frame", "heal-me", "player", now, o2, band and "band" or nil, "other")
                if gsrc == "mine" then own = o2 end
            end
            if own and gsrc == "mine" then rule, conf = "cast-frame", "high"
            elseif gsrc == "none" then rule = nil
            elseif self.groupSize <= 1 and dmNear(self, now, DM_HEAL, self.dmWindow) then rule, conf = "dm-frame", "high"
            else
                local function onBeat(d)
                    if self.healPeriod <= 0 then return false end   -- v2.2.13: never % 0 (the client raises)
                    local ph = d % self.healPeriod
                    return d >= self.healPeriod - self.healJitter and (ph <= self.healJitter or self.healPeriod - ph <= self.healJitter)
                end
                if self.lastMineHeal and now - self.lastMineHeal <= self.healPeriod * 8 + self.healJitter and onBeat(now - self.lastMineHeal) then
                    rule, conf = "heal-cadence", "medium"
                else
                    -- seed: a periodic heal on the beat of one of my live summons (Healing Stream Totem: 2 s from the drop;
                    -- overheals do not move the meter, so the DM rule cannot seed while I am at full health)
                    for i = #self.summons, 1, -1 do
                        local sm = self.summons[i]
                        local life = sm.pred and sm.pred.summon and sm.pred.summon.duration or 120
                        local d = now - sm.t
                        if d <= life + self.healJitter and onBeat(d) and d <= self.healPeriod * 40 then rule, conf = "summon-cadence", "medium" break end
                    end
                end
            end
            -- v2.2.16: cadence claims with same-class actors around (another shaman's Healing Stream Totem beats too) are
            -- U unless the amount matches my own recent cadence ticks (+-20 %)
            -- GATE RESULT (replay runs 9-13): the guard cuts cadence false-self 23 -> 11 but loses accuracy beyond noise on
            -- runs 10/11/13 (33 correct chained HST ticks in run 10 become U), so it is NOT promoted: it runs as the shadow
            -- candidate c-cad-guard (live predicted vs actual) unless opts.cadGuard turns it on.
            if (rule == "heal-cadence" or rule == "summon-cadence") and self.attrGuard then
                local amb = self:ambiguity("player", now, "heal-me")
                local st = self.attrStats[rule] or { mine = 0, other = 0, none = 0, implausible = 0, mismatch = 0, ambiguous = 0, corroborated = 0 }
                self.attrStats[rule] = st
                local ct = self.cadTicks or {}
                self.cadTicks = ct
                local okAmt = false
                if #ct > 0 and amt > 0 then
                    local sum = 0
                    for i = 1, #ct do sum = sum + ct[i] end
                    local m = sum / #ct
                    okAmt = m > 0 and math.abs(amt - m) <= 0.2 * m
                end
                -- phase lock to MY summon's drop time (another shaman's totem beats on its own phase)
                local okPh = (rule == "summon-cadence") and self:summonBeat(now, 0.1)
                local block = amb and not okAmt and not okPh
                self:cand("c-cad-guard", "heal-me", "player", block and "none" or "mine", amt)
                if block and self.cadGuard then
                    st.ambiguous, st.none = st.ambiguous + 1, st.none + 1
                    gsrc, gev, rule = "none", "amb:" .. amb, nil
                elseif block then
                    st.ambiguous, st.mine = st.ambiguous + 1, st.mine + 1
                    gev = "amb:" .. amb .. ",unguarded"
                else
                    st.mine = st.mine + 1
                    if amb then st.corroborated = st.corroborated + 1 gev = "amb:" .. amb .. ",cor:" .. (okAmt and "band" or "phase") end
                    if amt > 0 then ct[#ct + 1] = amt if #ct > 4 then table.remove(ct, 1) end end
                end
            end
            if self.candidates then
                local t0 = self.clock and self.clock()
                local hard = (rule == "cast-frame" or rule == "dm-frame")
                local cad = (rule == "heal-cadence" or rule == "summon-cadence")
                -- c-cad-tight: the live cadence rules with half the jitter (0.15 -> 0.075 s)
                local tight = hard
                if not hard and self.healPeriod > 0 then
                    local J = 0.075
                    local function beat(d) local ph = d % self.healPeriod return d >= self.healPeriod - J and (ph <= J or self.healPeriod - ph <= J) end
                    if self.lastMineHeal and now - self.lastMineHeal <= self.healPeriod * 8 + J and beat(now - self.lastMineHeal) then tight = true
                    elseif self:summonBeat(now, J) then tight = true end
                end
                self:cand("c-cad-tight", "heal-me", "player", tight and "mine" or "other", amt)
                -- c-cad-phase: only the phase lock to a live summon's drop time (no chaining from the last claimed tick)
                local ph = hard or (self:summonBeat(now, 0.1))
                self:cand("c-cad-phase", "heal-me", "player", ph and "mine" or "other", amt)
                -- c-cad-amount: live cadence claims kept only when the amount matches my recent totem ticks (+-20 %)
                local okAmt = hard
                if cad and amt > 0 then
                    local ct = self.candTick
                    if #ct == 0 then okAmt = true
                    else
                        local sum = 0
                        for i = 1, #ct do sum = sum + ct[i] end
                        local m = sum / #ct
                        okAmt = m > 0 and math.abs(amt - m) <= 0.2 * m
                    end
                    if okAmt then ct[#ct + 1] = amt if #ct > 4 then table.remove(ct, 1) end end
                end
                self:cand("c-cad-amount", "heal-me", "player", okAmt and "mine" or "other", amt)
                -- c-cad-phase-amount: both
                local pa = hard or (ph and (not cad or okAmt) and amt > 0)
                self:cand("c-cad-phase-amount", "heal-me", "player", pa and "mine" or "other", amt)
                -- c-heal-me-wide: an own helpful cast on me within 0.35 s (cast-time heals land at SUCCEEDED +- a frame)
                local w = self:ownWithin(now, 0.35)
                self:cand("c-heal-me-wide", "heal-me", "player", (rule or (w and w.target == "player")) and "mine" or "other", amt)
                self:candCostAdd("heal-me", t0)
            end
            if rule == "cast-frame" and self.onAmount then
                if own and own.spell then pcall(self.onAmount, own.spell, "heal", amt, flag == "CRITICAL", school) end
            end
            if rule then
                f.heal.mine, f.heal.mineN = f.heal.mine + amt, f.heal.mineN + 1
                liveBump(f, "healing", amt)
                if rule ~= "cast-frame" then self.lastMineHeal = now end
            elseif gsrc == "none" then f.heal.unknown, f.heal.unknownN = (f.heal.unknown or 0) + amt, (f.heal.unknownN or 0) + 1
            else f.heal.other, f.heal.otherN = f.heal.other + amt, f.heal.otherN + 1 end
            f.heal.rules[rule or (gsrc == "none" and "none" or "other")] = (f.heal.rules[rule or (gsrc == "none" and "none" or "other")] or 0) + 1
            local est = self:hpApply("player", amt, now)
            -- v2.2.7 (run 6b): the meter counts EFFECTIVE healing; UNIT_COMBAT HEAL is gross. Keep the running overheal
            -- estimate of my heals so ReconcileDM compares like with like (6b: live 456 gross = 400 effective + 56 over).
            if rule and est and type(est.over) == "number" and est.conf ~= "low" then
                f.heal.mineOver, f.heal.mineOverN = (f.heal.mineOver or 0) + est.over, (f.heal.mineOverN or 0) + 1
            end
            local unk = (gsrc == "none") and not rule
            local healRec = self:infer({ rule = rule or (unk and "heal-ambiguous" or "elimination"), kind = "heal", unit = "player",
                src = rule and "mine" or (unk and "none" or "other"),
                amount = amt, crit = flag == "CRITICAL" or nil, conf = conf or (unk and "low" or "medium"),
                overhealEst = est and est.over, hpConf = est and est.conf, ev = gev })
            -- shadow: totem-heal (6371) finding — HEAL without own cast while a summon is on its heal beat
            if self.shadowFindings and rule ~= "cast-frame" then
                local totemish = (rule == "summon-cadence" or rule == "heal-cadence" or rule == "dm-frame")
                local hasSummon = false
                for i = #self.summons, 1, -1 do
                    local sm = self.summons[i]
                    local life = sm.pred and sm.pred.summon and sm.pred.summon.duration or 120
                    if now - sm.t <= life + self.healJitter then hasSummon = true break end
                end
                if totemish then
                    self:verdict("shadow-totem-heal", "V", { src = rule or "totem-heal", conf = conf or "medium", spell = 6371 })
                    self.shadowTotemHealN = (self.shadowTotemHealN or 0) + 1
                elseif hasSummon and not rule then
                    -- non-acting: finding would claim mine; live attributed other — unresolved shadow
                    self:verdict("shadow-totem-heal", "U", { src = "summon alive, heal attributed other", conf = "low", spell = 6371 })
                    self.shadowTotemHealN = (self.shadowTotemHealN or 0) + 1
                end
            end
            return healRec
        elseif action == "ENERGIZE" then
            f.power = f.power + 1
            return nil
        end
        f.taken.n = f.taken.n + 1
        if MISS[action] then f.taken.miss = f.taken.miss + 1
        else
            f.taken.amount = f.taken.amount + amt
            liveBump(f, "taken", amt)
            self:hpApply("player", -amt, now)
            local wu = worldUnit(self, f, "player")
            if wu then
                wu.taken, wu.takenN = wu.taken + amt, wu.takenN + 1
                if wu.lastTakenT and now > wu.lastTakenT then
                    local dt = now - wu.lastTakenT
                    if dt > 0.05 and dt < 8 then wu.dtps = amt / dt end
                end
                wu.lastTakenT = now
                -- join DM type 7 (DamageTaken) timing with this wound
                if dmNear(self, now, DM_TAKEN, self.dmWindow or 0.03) then
                    wu.dmTicks[7] = (wu.dmTicks[7] or 0) + 1
                end
            end
        end
        local rec = self:infer({ rule = "unit-combat", kind = "damage-taken", unit = "player", src = "hostile", amount = amt, action = action,
            crit = flag == "CRITICAL" or nil, conf = "observed" })
        if self.shadowFindings and self.shadowDm7Expect and not MISS[action] then
            local dt = now - self.shadowDm7Expect
            if dt >= -self.sameFrame and dt <= (self.dmWindow or 0.03) + 0.05 then
                self:verdict("shadow-dm-type7", "V", { src = "DAMAGE_METER type 7 + UNIT_COMBAT wound", conf = "high", d = dt })
                self.shadowDm7N = (self.shadowDm7N or 0) + 1
                self.shadowDm7Expect = nil
            end
        end
        return rec
    end
    if action == "HEAL" then   -- heals on other units: not attributed live (v2.2.15: candidate rules only)
        if self.candidates then
            local t0 = self.clock and self.clock()
            local own = self:ownWithin(now, self.sameFrame)
            local ownT = own and own.target == unitKey
            self:cand("c-heal-tgt-frame", "heal-target", unitKey, ownT and "mine" or "other", amt, own and own.spell)
            local w = self:ownWithin(now, 0.35)
            self:cand("c-heal-tgt-wide", "heal-target", unitKey, (w and w.target == unitKey) and "mine" or "other", amt, w and w.spell)
            -- my totem's pulse also heals the target: on a summon beat = mine
            local b = self:summonBeat(now, 0.1)
            self:cand("c-heal-tgt-totem", "heal-target", unitKey, (ownT or b) and "mine" or "other", amt, own and own.spell)
            self:candCostAdd("heal-target", t0)
        end
        -- v2.2.15 PROMOTED (candidate c-heal-tgt-frame): a heal on another unit is mine when my own cast AT that unit
        -- succeeded in the same frame, else someone else's. Replay heal-on-target 0 -> 100 % on runs 9/10/11 (n 15/21/16),
        -- falseSelf 0. Attribution only: the meter-healing reconcile still uses heals on me (target heals are checked by
        -- the lab cand-heal verdicts first).
        self:frameBump(unitKey, now)
        local own = self:ownFor(now, self.sameFrame, unitKey, "heal-target")
        -- v2.2.16 gate: target match (as before) + a heal spell + unambiguous or inside the learned amount band
        local band = self:inBand(own, amt, flag == "CRITICAL")
        local gsrc, gev = self:gate("heal-tgt-frame", "heal-target", unitKey, now, own, band and "band" or nil, "other")
        local mineT = gsrc == "mine"
        if mineT then f.heal.tgtMine = (f.heal.tgtMine or 0) + amt
        elseif gsrc == "none" then f.heal.tgtUnknown = (f.heal.tgtUnknown or 0) + amt
        else f.heal.tgtOther = (f.heal.tgtOther or 0) + amt end
        return self:infer({ rule = "heal-tgt-frame", kind = "heal", unit = unitKey, src = gsrc, amount = amt,
            spell = mineT and own.spell or nil, conf = mineT and "high" or "low", ev = gev })
    end
    self:frameBump(unitKey, now)
    local rule, conf, dsrc, dev, gown = self:damageRule(now, school, unitKey, amt, flag == "CRITICAL")
    local src = dsrc or "other"
    if src == "none" then rule = nil end
    if rule == "cast-frame" and not MISS[action] and amt > 0 then   -- predicted damage range vs the clear UNIT_COMBAT amount
        local own = gown
        local k = own and own.spell and self.knowledge[own.spell]
        local r = k and k.amount
        if r and r.kind == "damage" and r.min then
            local crit = flag == "CRITICAL"
            local lo, hi = r.min * (crit and 1.4 or 0.9), (r.max or r.min) * (crit and 2.1 or 1.35)   -- +spell power / crits
            -- above the range = contradiction; below it may be a partial resist / absorb (UNIT_COMBAT does not say):
            -- unverified, not contradicted (run 5: a crit Earth Shock 103 with 17 resisted)
            local v = (amt > hi) and "C" or ((amt < lo) and "U" or "V")
            self:verdict("damage-range", v, { spell = own.spell, src = (v == "U") and "UNIT_COMBAT below range" or "UNIT_COMBAT",
                conf = "medium", d = ((r.max or r.min) > 0) and amt / (r.max or r.min) or nil })
        end
    end
    if rule == "cast-frame" and amt > 0 and not MISS[action] and self.onAmount then   -- learned DB: own damage ranges
        local own = gown
        if own and own.spell then pcall(self.onAmount, own.spell, "damage", amt, flag == "CRITICAL", school) end
    end
    local d = f.dmg
    local wu = worldUnit(self, f, unitKey)
    if src == "none" then
        d.unknown, d.unknownN = (d.unknown or 0) + amt, (d.unknownN or 0) + 1
    elseif rule then
        d.mine, d.mineN = d.mine + amt, d.mineN + 1
        liveBump(f, "damage", amt)
        if wu and not MISS[action] then wu.dmg, wu.dmgN = wu.dmg + amt, wu.dmgN + 1 end
    else
        d.other, d.otherN = d.other + amt, d.otherN + 1
        local sk = tostring(school or "?")
        f.otherSchools[sk] = (f.otherSchools[sk] or 0) + amt
        -- other damage on this token: still counts as that unit's damage-taken live estimate
        if wu and not MISS[action] then
            wu.taken, wu.takenN = wu.taken + amt, wu.takenN + 1
            if wu.lastTakenT and now > wu.lastTakenT then
                local dt = now - wu.lastTakenT
                if dt > 0.05 and dt < 8 then wu.dtps = amt / dt end
            end
            wu.lastTakenT = now
            if dmNear(self, now, DM_DAMAGE, self.dmWindow or 0.03) then
                wu.dmTicks[0] = (wu.dmTicks[0] or 0) + 1
            end
        end
    end
    if flag == "CRITICAL" then d.crit = d.crit + 1 end
    if MISS[action] then d.miss = d.miss + 1 end
    local rk = rule or (src == "none" and "ambiguous" or "other")
    d.rules[rk] = (d.rules[rk] or 0) + 1
    return self:infer({ rule = rule or (src == "none" and "damage-ambiguous" or "elimination"), kind = "damage", unit = unitKey, src = src,
        amount = amt, action = action, school = school, crit = flag == "CRITICAL" or nil, conf = conf or (src == "none" and "low" or "medium"), ev = dev })
end

-- UNIT_SPELLCAST_INTERRUPTED on a hostile: my interrupt when my successful cast (or the meter's Interrupts type) is in
-- the same frame; otherwise someone else's interrupt, a stun, LoS or movement (not attributable live)
function M:OnInterrupt(unitKey)
    if self.legacy then return nil end
    local now = self.now()
    -- MINOR 4: one interrupt per unit per frame (target + focus on the same unit, or a replayed duplicate token);
    -- castBarID is per TOKEN on 1.60.1 (target/nameplate1/softenemy carry different ids for one cast), so not a dedupe key
    local li = self.lastInterrupt
    if li and li.unit == unitKey and math.abs(now - li.t) <= self.sameFrame then return nil end
    self.lastInterrupt = { unit = unitKey, t = now }
    local ec = self.lastClosed
    local elapsed = nil
    if ec and ec.unit == unitKey and ec.outcome == "interrupted" and math.abs(now - ec.tEnd) <= self.sameFrame then elapsed = ec end
    local f = fightOrOpen(self, now)
    local any = self:ownWithin(now, self.sameFrame, true)
    local dm = dmNear(self, now, DM_INTERRUPT, 0.1)
    -- v2.2.16 gate: my cast AT the interrupted unit, an interrupt-capable spell, unambiguous or with the lockout
    -- signature (the meter's Interrupts tick in the same frame)
    local own = any and self:ownFor(now, self.sameFrame, unitKey, "interrupt", true)
    local gsrc, gev = "other", "no-cast"
    if own then gsrc, gev = self:gate("interrupt", "interrupt", unitKey, now, own, dm and "dm-lockout" or nil, "other") end
    local k = own and own.spell and self.knowledge[own.spell]
    local rule, conf, src
    if gsrc == "mine" and (dm or (k and k.interrupt)) then rule, conf, src = "interrupt-cast+dm", "high", "mine"
    elseif gsrc == "mine" then rule, conf, src = "interrupt-cast-frame", "medium", "mine"
    elseif gsrc == "none" then rule, conf, src = "interrupt-ambiguous", "low", "none"
    else rule, conf, src = "elimination", "low", "other" end
    if src ~= "mine" then own = nil end
    if self.candidates then
        -- c-int-wide: an own cast within 0.35 s (kick lands a frame or two after SUCCEEDED) or the DM interrupt tick
        local w = self:ownWithin(now, 0.35, true)
        self:cand("c-int-wide", "interrupt", unitKey, (w or dm) and "mine" or "other", nil, w and w.spell)
    end
    f.interrupts[src] = (f.interrupts[src] or 0) + 1
    if src == "mine" then liveBump(f, "interrupts", 1) end
    local wu = worldUnit(self, f, unitKey)
    if wu then wu.interrupts = wu.interrupts + 1 end
    self:verdict("interrupt-attribution", (rule == "interrupt-cast+dm") and "V" or "U",
        { src = rule, conf = conf, spell = own and own.spell })
    if own and own.spell and src == "mine" then
        local kk = self.knowledge[own.spell] or {}
        if not kk.interrupt then kk.interrupt = true self.knowledge[own.spell] = kk end
    end
    return self:infer({ rule = rule, kind = "interrupt", unit = unitKey, src = src, spell = own and own.spell, conf = conf,
        elapsed = elapsed and elapsed.elapsed, predicted = elapsed and elapsed.pred, ev = gev })
end

-- post-combat C_DamageMeter read (clear after combat): rec = {
--   damage/healing/interrupts/dispels/taken = my totals,
--   others = others' damage Done total,
--   spells = { [id] = amount }, duration = s,
--   sources = { DamageDone = { { id=, total=, isLocalPlayer=, spells= }, ... }, HealingDone=..., ... }
-- }. Reconciles live estimates vs meter; per-unit where sources are present. Verdicts: match / off by X / unexplained.
local function metricCmp(live, dm, tolAbs, tolRel)
    if type(dm) ~= "number" then return "unexplained", nil, nil end
    if type(live) ~= "number" then live = 0 end
    local d = live - dm
    local tol = math.max(tolAbs or 5, math.abs(dm) * (tolRel or 0.02))
    if math.abs(d) <= tol then return "match", d, tol end
    return "off", d, tol
end

-- v2.2.12: live totals + per-unit world over the C_DamageMeter session window ending at fight f's stop.
-- mode "fight": the session is no longer than f (+2 s) -> f alone (solo PvE, runs 6/6b: one fight = one session).
-- mode "session": every kept fight (soft included) starting inside [stop - duration - 1, stop].
-- complete = false when the window starts before this capture (bornAt) or before the oldest kept fight after the
-- ring dropped some, or a kept fight straddles the window start (cannot split it; a soft record counts until its last
-- activity, lastT, not its stop: it stays open until the next combat starts).
local function fightLive(x)
    local h = x.heal
    local eff = h.mine
    if (h.mineOverN or 0) > 0 and h.mineOverN == h.mineN then eff = h.mine - (h.mineOver or 0) end
    return x.dmg.mine, x.dmg.other, eff, h.mine, ((h.mineOverN or 0) > 0 and h.mineOverN == h.mineN) and (h.mineOver or 0) or nil,
        x.interrupts.mine, (x.dispels and x.dispels.mine) or 0, x.taken.amount
end

function M:dmSessionLive(f, duration)
    local stopT = f.stop or self.now()
    local out = { mode = "fight", n = 1, complete = true, live = {}, world = {} }
    local fs = { f }
    if type(duration) == "number" and duration > (stopT - f.start) + 2 then
        out.mode = "session"
        local winStart = stopT - duration - 1
        fs = {}
        local recent = self.recentFights or {}
        for i = 1, #recent do
            local x = recent[i]
            if x.start >= winStart and x.start <= stopT + 0.5 then fs[#fs + 1] = x
            elseif x.start < winStart and ((x.soft and x.lastT) or x.stop or stopT) > winStart + 1 then
                out.complete, out.why = false, "fight straddles session start"
            end
        end
        local found = false
        for i = 1, #fs do if fs[i] == f then found = true end end
        if not found then fs[#fs + 1] = f end
        if (self.bornAt or 0) > winStart + 1 then out.complete, out.why = false, "session started before this capture" end
        if (self.recentPushed or #recent) > #recent and recent[1] and recent[1].start > winStart then
            out.complete, out.why = false, "session older than the kept fights"
        end
        out.n = #fs
    end
    local L = { damage = 0, dmgOther = 0, healing = 0, healingGross = 0, healingOver = 0, interrupts = 0, dispels = 0, taken = 0 }
    local overKnown = true
    local seen = {}
    for i = 1, #fs do
        local x = fs[i]
        local dm, dmo, eff, gross, over, intr, disp, tk = fightLive(x)
        L.damage, L.dmgOther, L.healing, L.healingGross = L.damage + dm, L.dmgOther + dmo, L.healing + eff, L.healingGross + gross
        if over then L.healingOver = L.healingOver + over elseif gross > 0 then overKnown = false end
        L.interrupts, L.dispels, L.taken = L.interrupts + intr, L.dispels + disp, L.taken + tk
        for k, w in pairs(x.world or {}) do
            if not seen[w] then   -- world holds the same entry under the raw key and its IdKey alias
                seen[w] = true
                local id = w.idKey or k
                local a = out.world[id]
                if not a then a = { dmg = 0, heal = 0, taken = 0, interrupts = 0, dispels = 0 } out.world[id] = a end
                a.dmg, a.heal, a.taken = a.dmg + (w.dmg or 0), a.heal + (w.heal or 0), a.taken + (w.taken or 0)
                a.interrupts, a.dispels = a.interrupts + (w.interrupts or 0), a.dispels + (w.dispels or 0)
            end
        end
    end
    if not overKnown then L.healingOver = nil end
    out.fs = fs
    out.live = L
    return out
end

function M:ReconcileDM(rec)
    if type(rec) ~= "table" then return nil end
    local f
    for i = #self.fights, 1, -1 do if not self.fights[i].soft then f = self.fights[i] break end end
    if not f or f.dm then return nil end
    f.dm = rec
    -- sync liveEst from fight totals (authoritative running sums) before compare
    local le = f.liveEst or {}
    le.damage = f.dmg.mine
    -- effective = gross - estimated overheal, only when every heal of mine had an hp estimate (else gross, as before)
    le.healingGross = f.heal.mine
    if (f.heal.mineOverN or 0) > 0 and f.heal.mineOverN == f.heal.mineN then
        le.healing, le.healingOver = f.heal.mine - f.heal.mineOver, f.heal.mineOver
    else
        le.healing, le.healingOver = f.heal.mine, nil
    end
    le.interrupts = f.interrupts.mine
    le.dispels = (f.dispels and f.dispels.mine) or le.dispels or 0
    le.taken = f.taken.amount
    f.liveEst = le

    -- v2.2.12 (run 9 root cause A): the meter record is the CUMULATIVE C_DamageMeter session (durationSeconds), which in
    -- a BG spans several consecutive live fights (meter 38-159 s vs live fights 5.6-17.6 s; meter totals == combat log
    -- over [stop - duration, stop] exactly). Compare like with like: sum every recent fight (soft included) inside the
    -- session window. If the window reaches back before this capture or past the kept fights, coverage is incomplete
    -- and every verdict is U (cannot judge) - never C.
    local agg = self:dmSessionLive(f, rec.duration)
    local A = agg.live
    local out = { rule = "dm-reconcile", kind = "reconcile", conf = "high", metrics = {}, units = {},
        window = { mode = agg.mode, duration = rec.duration, fights = agg.n, complete = agg.complete, why = agg.why } }
    local verdicts = {}

    local function one(name, live, dm, tolAbs)
        local status, d, tol = metricCmp(live, dm, tolAbs, 0.02)
        if not agg.complete and type(dm) == "number" then status = "unexplained" end
        local row = { name = name, live = live, dm = dm, delta = d, status = status, tol = tol }
        out.metrics[name] = row
        verdicts[#verdicts + 1] = row
        if not agg.complete and type(dm) == "number" then
            self:verdict("dm-" .. name, "U", { src = "coverage: " .. agg.why, conf = "low", d = d })
        elseif status == "match" then
            self:verdict("dm-" .. name, "V", { src = "match", conf = "high", d = d })
        elseif status == "off" and d and d > 0 then
            -- damage keeps the historical contradiction kind (tests/hsm.lua + offline scorers)
            local ck = (name == "damage") and "self-attribution-exceeds-dm" or ("self-attribution-exceeds-dm-" .. name)
            self:contradict({ kind = ck, live = live, dm = dm, rule = "dm-reconcile" })
            self:verdict("dm-" .. name, "C", { src = "off by +" .. tostring(d), conf = "high", d = d })
        elseif status == "off" then
            self:verdict("dm-" .. name, "U", { src = "off by " .. tostring(d) .. " (live under meter)", conf = "medium", d = d })
        else
            self:verdict("dm-" .. name, "U", { src = "unexplained (no meter value)", conf = "low" })
        end
        return row
    end

    one("damage", A.damage, rec.damage)
    one("healing", A.healing, rec.healing)
    -- v2.2.15: per-candidate live check against the meter's healing (gross candidate total vs effective meter value:
    -- over the meter by more than tolerance = C; within = V; under = U, like dm-healing)
    if self.candidates and agg.fs and type(rec.healing) == "number" then
        local tot = {}
        for i = 1, #agg.fs do for id, v in pairs(agg.fs[i].cand or {}) do tot[id] = (tot[id] or 0) + v end end
        for id, st in pairs(self.candStats) do
            if st.kind == "heal-me" or st.kind == "heal-target" then
                local v = tot[id] or 0
                local tol = math.max(20, 0.02 * rec.healing)
                local d = v - rec.healing
                local verd = (not agg.complete) and "U" or (math.abs(d) <= tol and "V") or (d > tol and "C") or "U"
                self:verdict("cand-heal:" .. id, verd, { src = st.kind, conf = "shadow", d = d })
            end
        end
    end
    one("interrupts", A.interrupts, rec.interrupts, 0)
    one("dispels", A.dispels, rec.dispels, 0)
    one("taken", A.taken, rec.taken)

    out.dmMine, out.liveMine, out.liveOther = rec.damage, A.damage, A.dmgOther
    out.liveTotal = A.damage + A.dmgOther
    if type(rec.damage) == "number" then
        out.othersOnTarget = math.max(0, out.liveTotal - rec.damage)
    end
    out.dmHeal, out.liveHeal, out.liveHealGross, out.liveHealOver = rec.healing, A.healing, A.healingGross, A.healingOver
    out.dmInterrupts, out.liveInterrupts = rec.interrupts, A.interrupts
    out.dmDispels, out.liveDispels = rec.dispels, A.dispels
    out.dmTaken, out.liveTaken = rec.taken, A.taken

    -- per-unit: meter sources keyed by IdKey / player / npc:ID vs fight.world
    if type(rec.sources) == "table" then
        local byId = {}
        local function ingest(typeName, field)
            local list = rec.sources[typeName]
            if type(list) ~= "table" then return end
            for _, src in ipairs(list) do
                local id = src.id or (src.isLocalPlayer and "player") or nil
                if id then
                    local u = byId[id] or { id = id, kind = src.kind, class = src.class, isMe = src.isLocalPlayer }
                    byId[id] = u
                    if type(src.total) == "number" then u[field] = (u[field] or 0) + src.total end
                end
            end
        end
        ingest("DamageDone", "damage")
        ingest("HealingDone", "healing")
        ingest("Interrupts", "interrupts")
        ingest("Dispels", "dispels")
        ingest("DamageTaken", "taken")
        ingest("EnemyDamageTaken", "enemyTaken")

        -- v2.2.12 (run 9 root cause C): 81 of 132 meter units were never observed live (UNIT_COMBAT only reaches units
        -- behind a token whose GUID was readable), and a missing live value used to compare as 0 -> "off" (C). Other
        -- units' live values are partial observations (lower bounds): C only when live EXCEEDS the meter; a unit never
        -- observed, or observed under the meter, is U. Me: live is complete (taken == combat log exactly) -> both ways.
        for id, meterU in pairs(byId) do
            local liveU = agg.world[id]
            local isMe = id == "player" or meterU.isMe
            if id == "player" then
                liveU = { dmg = A.damage, heal = A.healing, taken = A.taken, interrupts = A.interrupts, dispels = A.dispels }
            end
            local row = { id = id, kind = meterU.kind, isMe = meterU.isMe, meter = meterU, live = liveU, status = {} }
            -- other units: world[u].dmg / heal / interrupts are what *I* did TO u, the meter's DamageDone / HealingDone /
            -- Interrupts are what u DID - different quantities (run 9: compared anyway). Only damage taken BY u is the
            -- same quantity on both sides: live world[u].taken vs meter DamageTaken (group member) / EnemyDamageTaken.
            local fields = isMe and { "damage", "healing", "interrupts", "dispels", "taken" } or { "taken" }
            if not isMe and meterU.taken == nil and meterU.enemyTaken ~= nil then meterU.taken = meterU.enemyTaken end
            for _, fld in ipairs(fields) do
                local liveV = liveU and (liveU[fld] or liveU[(fld == "damage" and "dmg") or (fld == "healing" and "heal") or fld]) or nil
                local tolA = (fld == "interrupts" or fld == "dispels") and 0 or 5
                local st, d = metricCmp(liveV, meterU[fld], tolA, 0.05)
                if type(liveV) ~= "number" and type(meterU[fld]) == "number" then st = "unexplained" end
                if st == "off" and not isMe and d and d < 0 then st = "under" end
                if not agg.complete then st = "unexplained" end
                row.status[fld] = { status = st, live = liveV, dm = meterU[fld], delta = d }
            end
            -- overall: match if all present metrics match; else off / unexplained
            local anyOff, anyUnex, anyMatch = false, false, false
            for _, s in pairs(row.status) do
                if s.dm ~= nil then
                    if s.status == "match" then anyMatch = true
                    elseif s.status == "off" then anyOff = true
                    else anyUnex = true end
                end
            end
            -- "match" needs every metered value matched; a partial match with gaps is unexplained (was: match)
            row.verdict = anyOff and "off" or ((anyMatch and not anyUnex) and "match" or "unexplained")
            out.units[id] = row
            self:verdict("dm-unit-" .. (meterU.isMe and "me" or "other"),
                row.verdict == "match" and "V" or (row.verdict == "off" and "C" or "U"),
                { src = id, conf = meterU.isMe and "high" or "medium" })
        end
    end

    -- per-spell checks (mine)
    if type(rec.spells) == "table" then
        local casts = {}
        for _, p in ipairs(self.predictions) do
            if p.t >= f.start and (not f.stop or p.t <= f.stop + 0.5) then casts[p.spell] = (casts[p.spell] or 0) + 1 end
        end
        local checks = {}
        for id, total in pairs(rec.spells) do
            local amt = type(total) == "table" and total.amount or total
            local k = self.knowledge[id]
            local n = casts[id]
            local c = { spell = id, dm = amt, casts = n }
            if k and k.amount and n and k.amount.min and k.amount.max then
                c.min, c.max = k.amount.min * n, k.amount.max * n
                c.inRange = amt >= c.min * 0.5 and amt <= c.max * 2.5
            end
            checks[#checks + 1] = c
        end
        out.spells = checks
    end

    -- summary for HSM UI / Export
    local nMatch, nOff, nUnex = 0, 0, 0
    for _, r in ipairs(verdicts) do
        if r.status == "match" then nMatch = nMatch + 1
        elseif r.status == "off" then nOff = nOff + 1
        else nUnex = nUnex + 1 end
    end
    out.summary = { match = nMatch, off = nOff, unexplained = nUnex }
    f.reconcile = { metrics = out.metrics, summary = out.summary, t = self.now() }
    self.lastReconcile = f.reconcile
    return self:infer(out)
end

-- compact, SavedVariables-safe export (numbers/strings/booleans only)
----------------------------------------------------------------------------
-- MINOR 4: enemy cast-duration model (interrupt window). On 1.60.1 a hostile's UNIT_SPELLCAST_START/SUCCEEDED/STOP/
-- INTERRUPTED carry a clear unit token + castBarID (per token) while castGUID/spellID are secret: the duration from
-- START to SUCCEEDED is learned per NPC (npcID from the clear or ledger-cached GUID, else a fingerprint key) and
-- predicts the remaining time of the next cast of that NPC. Median of the last 8 durations; window = min..max.
----------------------------------------------------------------------------
function Lib.NpcKey(guid)
    if type(guid) ~= "string" then return nil end
    local kind, npc = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if (kind == "Creature" or kind == "Vehicle") and npc then return "npc:" .. npc end
    if guid:find("^Player%-") then return "player:" .. guid end
    return nil
end

local function median(t)
    local c = {}
    for i = 1, #t do c[i] = t[i] end
    table.sort(c)
    local n = #c
    if n == 0 then return nil end
    if n % 2 == 1 then return c[(n + 1) / 2] end
    return (c[n / 2] + c[n / 2 + 1]) / 2
end

function M:castModelFor(key)
    local m = key and self.castModel[key]
    if not (m and #m.d > 0) then return nil end
    local lo, hi = math.huge, -math.huge
    for _, d in ipairs(m.d) do if d < lo then lo = d end if d > hi then hi = d end end
    return median(m.d), lo, hi, #m.d
end

local CAST_OPEN = { UNIT_SPELLCAST_START = "cast", UNIT_SPELLCAST_CHANNEL_START = "channel" }
function M:OnEnemyCast(event, unitKey, key, bar, spell)
    if unitKey == nil then return nil end
    local now = self.now()
    local mkey = key and (spell and (key .. "#" .. tostring(spell)) or key) or nil
    local c = self.ecast[unitKey]
    if CAST_OPEN[event] then
        if c and c.start and math.abs(now - c.start) <= self.sameFrame then return c end   -- same cast via a 2nd token
        local pred, lo, hi, n = self:castModelFor(mkey)
        if not pred and mkey ~= key then pred, lo, hi, n = self:castModelFor(key) end
        c = { start = now, bar = bar, key = mkey, base = key, kind = CAST_OPEN[event], pred = pred, lo = lo, hi = hi, n = n, unit = unitKey }
        self.ecast[unitKey] = c
        c.rec = push(self.castPreds, { t = now, key = mkey, pred = pred, lo = lo, hi = hi, n = n, kind = c.kind }, 200)
        self.version = self.version + 1
        return c
    end
    if not c then return nil end
    if bar ~= nil and c.bar ~= nil and bar ~= c.bar and event ~= "UNIT_SPELLCAST_STOP" then return nil end
    local dur = now - c.start
    local outcome
    if event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then outcome = "completed"
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then outcome = "interrupted"
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED" then outcome = "stopped"
    else return nil end
    if outcome == "completed" and dur > 0.2 then
        for _, k in ipairs({ c.key, (c.base ~= c.key) and c.base or nil }) do
            if k then
                local m = self.castModel[k] or { d = {}, n = 0 }
                self.castModel[k] = m
                m.n = m.n + 1
                m.d[#m.d + 1] = dur
                if #m.d > 8 then table.remove(m.d, 1) end   -- 8 entries: constant cost
            end
        end
    end
    c.rec.outcome = outcome
    if c.pred and outcome == "completed" then
        local tol = math.max(0.15, ((c.hi or c.pred) - (c.lo or c.pred)) / 2 + 0.05)
        self:verdict("cast-end", math.abs(dur - c.pred) <= tol and "V" or "C",
            { src = "UNIT_SPELLCAST_SUCCEEDED", conf = c.n and c.n >= 3 and "medium" or "low", d = dur - c.pred, key = c.key })
    elseif c.pred then self:verdict("cast-end", "U", { src = event, key = c.key, d = dur }) end
    if outcome == "interrupted" or outcome == "stopped" then c.rec.elapsed = dur else c.rec.actual = dur end
    self.lastClosed = { unit = unitKey, tEnd = now, elapsed = dur, pred = c.pred, outcome = outcome }
    self.ecast[unitKey] = nil
    self.version = self.version + 1
    return c.rec
end

-- open enemy cast on a unit: { start, pred, lo, hi, n, remaining (s, nil without a model) }
function M:EnemyCast(unitKey)
    local c = self.ecast[unitKey]
    if not c then return nil end
    local now = self.now()
    if c.pred and now > c.start + (c.hi or c.pred) + 2 then self.ecast[unitKey] = nil return nil end   -- missed end event
    if not c.pred and now > c.start + 12 then self.ecast[unitKey] = nil return nil end
    c.remaining = c.pred and math.max(0, c.start + c.pred - now) or nil
    c.elapsed = now - c.start
    return c
end

function M:CastModelExport()
    local out = {}
    for k, m in pairs(self.castModel) do
        if not k:find("^player:") then   -- npc ids only (no player GUIDs in SavedVariables exports)
            local pred, lo, hi, n = self:castModelFor(k)
            out[k] = { median = pred, min = lo, max = hi, n = m.n, recent = n }
        end
    end
    return out
end

----------------------------------------------------------------------------
-- MINOR 4: UNIT_SPELLCAST_FAILED (player, clear spellID on 1.60.1) as cooldown evidence. The live event carries no
-- reason: a fail inside the predicted cooldown window confirms it ("fail-inside-cd"); outside it (and outside the GCD)
-- it is recorded as weak "fail-outside-cd" evidence only (range / mana / LoS also fail). Offline the log's
-- SPELL_CAST_FAILED reason ("Not yet recovered") turns that into confirm / contradict.
----------------------------------------------------------------------------
function M:OnCastFailed(spellID, event, dead)
    if type(spellID) ~= "number" then return nil end
    local now = self.now()
    -- v2.2.16 (run 13): a cast that fails because I am dead never reached the cooldown check: no cooldown evidence
    if dead then
        self.counters["fail-dead"] = (self.counters["fail-dead"] or 0) + 1
        self:verdict("cooldown", "U", { spell = spellID, src = event or "UNIT_SPELLCAST_FAILED", conf = "low", why = "dead" })
        return self:infer({ rule = "fail-dead", kind = "cast-failed", spell = spellID, conf = "low" })
    end
    local c = self.cooldowns[spellID]
    if c and c.ends and c.ends <= now - 0.05 then self.cooldowns[spellID] = nil c = nil end
    local rule, conf, remaining
    local tc = self.cd.spells[spellID]       -- MINOR 5: the tracker (learned / observed / shared category) wins
    if tc and tc.cooling and tc.ends and now < tc.ends then
        c = { ends = tc.ends, pred = c and c.pred }
        tc.failConfirm = (tc.failConfirm or 0) + 1
    end
    if c and c.ends and now < c.ends then
        rule, conf, remaining = "fail-inside-cd", "medium", c.ends - now
        if c.pred then c.pred.cdConfirm = (c.pred.cdConfirm or 0) + 1 end
    else
        local last = self.ownRecent[#self.ownRecent]
        if last and now - last.t < 1.5 then rule, conf = "fail-gcd", "low" else rule, conf = "fail-outside-cd", "low" end
    end
    self.counters[rule] = (self.counters[rule] or 0) + 1
    self:verdict("cooldown", rule == "fail-inside-cd" and "V" or "U",
        { spell = spellID, src = event or "UNIT_SPELLCAST_FAILED", conf = conf, d = remaining })
    return self:infer({ rule = rule, kind = "cast-failed", spell = spellID, conf = conf, remaining = remaining,
        quiet = event == "UNIT_SPELLCAST_FAILED_QUIET" or nil })
end

----------------------------------------------------------------------------
-- MINOR 4: running health estimate (player). UnitHealth(player) is secret in and out of combat on 1.60.1, UnitHealthMax
-- is clear (ledger). Anchor: out of combat, no UNIT_HEALTH for quietFull s = regeneration stopped = full health.
-- Then UNIT_COMBAT WOUND (clear amount) subtracts, HEAL adds (gross); overheal estimate = amount above max.
-- UNIT_HEALTH without a same-frame UNIT_COMBAT (regen, drains, absorbs) is counted as unknown and lowers confidence.
----------------------------------------------------------------------------
local function hpState(self, unitKey)
    local h = self.hp[unitKey]
    if not h then h = { unknown = 0 } self.hp[unitKey] = h end
    return h
end

function M:hpAnchor(h, now)
    if h.max and not self.inCombat and h.lastEvt and now - h.lastEvt >= self.quietFull
        and (h.anchor ~= "quiet-full" or h.cur ~= h.max or h.unknown > 0) then
        h.cur, h.unknown, h.anchor, h.anchorT = h.max, 0, "quiet-full", now
    end
end

function M:OnHealthMax(unitKey, max)
    if type(max) ~= "number" or max <= 0 then return end
    local h = hpState(self, unitKey)
    if h.max ~= max then
        if h.cur and h.max then h.cur = math.min(max, h.cur) end
        h.max = max
        if not h.cur then h.cur, h.anchor, h.anchorT = max, "assumed-full", self.now() end
        self.version = self.version + 1
    end
end

function M:OnHealthEvent(unitKey)
    local now = self.now()
    local h = hpState(self, unitKey)
    self:hpAnchor(h, now)
    h.lastEvt = now
    if not (h.lastUC and math.abs(now - h.lastUC) <= self.sameFrame) then
        h.unknown = h.unknown + 1
        h.lastUnknownT = now
    end
end

function M:hpApply(unitKey, delta, now)
    local h = hpState(self, unitKey)
    h.lastUC = now
    if h.lastUnknownT and math.abs(now - h.lastUnknownT) <= self.sameFrame then h.unknown = math.max(0, h.unknown - 1) h.lastUnknownT = nil end
    if not (h.max and h.cur) then return nil end
    local over
    if delta >= 0 then
        over = math.max(0, h.cur + delta - h.max)
        h.cur = math.min(h.max, h.cur + delta)
    else h.cur = math.max(1, h.cur + delta) end
    local conf = (h.anchor == "quiet-full" and h.unknown == 0) and "high" or ((h.unknown <= 2 and h.anchor) and "medium" or "low")
    return { over = over, cur = h.cur, conf = conf }
end

-- v2.2.16 c-hp-net live predicted vs actual: a clear UnitHealth read on a non-player unit scores the estimate
-- (V within 5% of max, else C; d = error fraction) and re-anchors it. Shadow only (lab): nothing acts on it.
function M:CandHealthActual(unitKey, cur, max)
    if not (self.candidates and unitKey ~= nil and type(cur) == "number" and type(max) == "number" and max > 0) then return nil end
    local h = hpState(self, unitKey)
    local v
    if h.cur and h.max and h.anchor ~= nil then
        local err = math.abs(h.cur - cur) / max
        v = err <= 0.05 and "V" or "C"
        local st = self.candStats["c-hp-net"]
        if not st then st = { n = 0, mine = 0, other = 0, kind = "health", V = 0, C = 0, errSum = 0 } self.candStats["c-hp-net"] = st end
        st.n, st[v], st.errSum = st.n + 1, st[v] + 1, st.errSum + err
        self:verdict("cand:c-hp-net", v, { conf = "shadow", d = math.floor(err * 1000 + 0.5) / 1000, key = unitKey })
    end
    h.cur, h.max, h.unknown, h.anchor, h.anchorT = cur, max, 0, "clear", self.now()
    return v
end

function M:Health(unitKey)
    local h = self.hp[unitKey]
    if not h or not h.cur then return nil end
    return h.cur, h.max, (h.anchor == "quiet-full" and h.unknown == 0) and "high" or ((h.unknown <= 2) and "medium" or "low"), h.unknown
end

----------------------------------------------------------------------------
-- MINOR 5: CooldownTracker (per spellID cooldown + GCD). Event-driven only: no OnUpdate; work per SPELL_UPDATE_COOLDOWN
-- is O(k) over the spells currently cooling (+ the GCD spell). Inputs are clear by documentation/observation on 1.60.1:
-- C_Spell.GetSpellCooldown(id).isActive / .isOnGCD / .isEnabled are NeverSecret (run 5 CONTAINERS: C in combat), the
-- SPELL_UPDATE_COOLDOWN payload (spellID, category, startRecoveryCategory) is clear in combat (run 5 RecordDB), and
-- startTime / duration are read ONLY when clear (out of combat) to calibrate. Nothing secret is stored or derived.
----------------------------------------------------------------------------
local CD_TOL, GCD_TOL = 0.25, 0.12
local function cdmed(t)
    if not t or #t == 0 then return nil end
    local c = {}
    for i = 1, #t do c[i] = t[i] end
    table.sort(c)
    return c[math.floor((#c + 1) / 2)]
end
local function ring8(list, v) list[#list + 1] = v if #list > 8 then table.remove(list, 1) end end

function M:cdSpell(id)
    local c = self.cd.spells[id]
    if not c then
        c = { learned = {}, gcdLearned = {} }
        self.cd.spells[id] = c
    end
    return c
end

function M:CDInfo(spellID, info)
    if type(spellID) ~= "number" or type(info) ~= "table" then return end
    local c = self:cdSpell(spellID)
    if type(info.cooldown) == "number" then c.base = info.cooldown end
    if type(info.gcd) == "number" then c.baseGCD = info.gcd end
    if type(info.category) == "number" then self:CDPayload(spellID, nil, info.category, info.srCategory) end
end

-- SPELL_UPDATE_COOLDOWN(spellID, baseSpellID, category, startRecoveryCategory, itemID): learns shared categories
-- (run 5: all shocks share category 19) and which spells trigger the GCD (startRecoveryCategory 133 vs 0)
function M:CDPayload(spellID, baseSpellID, category, srCategory)
    if type(spellID) ~= "number" then return end
    local c = self:cdSpell(spellID)
    if type(category) == "number" and category ~= c.category then
        if c.category and self.cd.cat[c.category] then self.cd.cat[c.category][spellID] = nil end
        if category == 0 then c.category = nil else c.category = category end
        if c.category then
            local m = self.cd.cat[category] or {}
            self.cd.cat[category] = m
            m[spellID] = true
        end
    end
    if type(srCategory) == "number" then c.srCategory = srCategory end
    if type(baseSpellID) == "number" and baseSpellID ~= spellID then c.baseSpell = baseSpellID end
end

-- active set + dense array (O(1) add / swap-remove) for the round-robin re-check
function M:cdActivate(id, on)
    local cd = self.cd
    local a = cd.active
    if on and not a[id] then
        a[id] = true cd.nActive = cd.nActive + 1
        local n = #cd.list + 1
        cd.list[n] = id cd.pos[id] = n
    elseif not on and a[id] then
        a[id] = nil cd.nActive = cd.nActive - 1
        local i, n = cd.pos[id], #cd.list
        if i then
            local last = cd.list[n]
            cd.list[i] = last cd.pos[last] = i
            cd.list[n] = nil cd.pos[id] = nil
        end
        cd.due[id] = nil
    end
end

-- min-heap of predicted ready times (lazy: an entry is stale when the spell's hseq moved on). Every change of c.ends
-- pushes one entry: O(log k) per change, O(1) amortised per event to find the spells that are about to be ready.
local function heapPush(h, e)
    local i = #h + 1
    h[i] = e
    while i > 1 do
        local p = (i - i % 2) / 2
        if h[p][1] <= e[1] then break end
        h[i], h[p] = h[p], e
        i = p
    end
end
local function heapPop(h)
    local n = #h
    local top = h[1]
    local last = h[n]
    h[n] = nil
    n = n - 1
    if n > 0 then
        local i = 1
        while true do
            local l = 2 * i
            if l > n then break end
            local m = (l + 1 <= n and h[l + 1][1] < h[l][1]) and l + 1 or l
            if h[m][1] >= last[1] then break end
            h[i] = h[m]
            i = m
        end
        h[i] = last
    end
    return top
end
function M:cdSchedule(id, c)
    if not (c and c.ends) then return end
    c.hseq = (c.hseq or 0) + 1
    local h = self.cd.heap
    heapPush(h, { c.ends, id, c.hseq })
    if #h > 4 * (self.cd.nActive + 16) then   -- stale entries pile up only under heavy rescheduling: rebuild O(k log k)
        local nh = {}
        for _, aid in ipairs(self.cd.list) do
            local ac = self.cd.spells[aid]
            if ac and ac.ends and ac.hseq then heapPush(nh, { ac.ends, aid, ac.hseq }) end
        end
        self.cd.heap = nh
    end
end

-- static seed (Data/spell-timing.lua, merged offline from earlier captures + known answers): lowest priority below live
function M:CDSeed(spellID, e)
    if type(spellID) ~= "number" or type(e) ~= "table" then return end
    local c = self:cdSpell(spellID)
    -- partial updates keep the other field (a drift override of the GCD must not wipe the seeded cooldown)
    local gv, cv = tonumber(e.gcd or e.observedGCD or e.baseGCD), tonumber(e.cooldown or e.observedCooldown or e.baseCooldown)
    if gv then c.seedGCD = gv end
    if cv then c.seedCD = cv end
    c.seedConf = e.confidence or c.seedConf
    c.seedSrc = e.source == "drift" and "drift" or (e.source == "learned" and "learned-sv" or "seed")
    if type(e.srCategory) == "number" and c.srCategory == nil then c.srCategory = e.srCategory end
    if type(e.category) == "number" and c.category == nil then self:CDPayload(spellID, nil, e.category, nil) end
end

function M:cdLearn(kind, id, v, extra)
    if self.onCDLearn then pcall(self.onCDLearn, kind, id, v, extra) end
end

function M:cdLength(c, id)
    local l = cdmed(c.learned)
    if l then return l, (#c.learned >= 2) and "high" or "medium", "learned" end
    if c.cal then return c.cal, "high", "api-clear" end
    local k = self.knowledge[id]
    local b = c.base or (k and k.cooldown)
    if b and b > 0 then return b, "medium", "baseCooldown" end
    if c.seedCD and c.seedCD > 0 then return c.seedCD, (c.seedSrc == "seed") and "low" or "medium", c.seedSrc or "seed" end
    return nil
end

function M:gcdLength(c, id)
    local l = cdmed(c.gcdLearned)
    if l then return l, "high", "learned" end
    local k = self.knowledge[id]
    local g = c.baseGCD or (k and k.gcd)
    if g then return g, "medium", "baseGCD" end
    if c.seedGCD then return c.seedGCD, (c.seedConf == "high") and "medium" or "low", c.seedSrc or "seed" end
    if c.srCategory == 0 then return 0, "medium", "srCategory" end
    if c.srCategory then return 1.5, "low", "default" end
    return nil
end

-- consecutive own cast begins (START for cast-time spells, SUCCEEDED for instants): the gap after a begin of spell X is
-- an upper bound of X's GCD (the minimum over many casts converges to it; offline it is checked against the log)
function M:cdBegin(id, now)
    local lb = self.cd.lastBegin
    if lb and lb.spell and now - lb.t > 0.05 and now - lb.t < 3 then self:cdLearn("gap", lb.spell, now - lb.t) end
    self.cd.lastBegin = { t = now, spell = id }
end

function M:CDCast(id, now)
    now = now or self.now()
    local c = self:cdSpell(id)
    c.lastCast = now
    local lb = self.cd.lastBegin
    local k = self.knowledge[id]
    if not (lb and lb.spell == id and now - lb.t <= ((k and k.castTime) or 0) + 0.5 and now - lb.t > 0.2) then self:cdBegin(id, now) end
    local len, conf, src = self:cdLength(c, id)
    if len and len > 1.5 then
        c.cooling, c.start, c.ends, c.conf, c.src, c.gcdOnly, c.obs = true, now, now + len, conf, src, nil, nil
        self:cdActivate(id, true)
        self:cdSchedule(id, c)
        self.cd.latest = id   -- most recent cooldown start (UI bar): O(1), re-picked only when it settles
        -- shared category: every member starts the same cooldown (run 5: Earth/Flame/Frost Shock = category 19)
        local m = c.category and self.cd.cat[c.category]
        if m then
            for oid in pairs(m) do
                if oid ~= id then
                    local o = self:cdSpell(oid)
                    o.cooling, o.start, o.ends, o.conf, o.src, o.obs = true, now, now + len, "medium", "category:" .. c.category, nil
                    o.sharedFrom = id
                    self:cdActivate(oid, true)
                    self:cdSchedule(oid, o)
                end
            end
        end
    end
    local g, gconf, gsrc = self:gcdLength(c, id)
    if g and g > 0 then
        self.cd.gcd = { start = now, ends = now + g, spell = id, length = g, conf = gconf, source = gsrc, seenOn = nil }
        self:cdActivate(id, true)
    end
    self.version = self.version + 1
end

-- returns a reused buffer (valid until the next call; callers iterate it immediately): no per-event allocation
function M:CDActive()
    local out, n = self.cd.activeBuf, 0
    if not out then out = {} self.cd.activeBuf = out end
    local now = self.now()
    for id in pairs(self.cd.active) do
        local c = self.cd.spells[id]
        local g = self.cd.gcd
        local keep = c and ((c.cooling and c.ends and now < c.ends + 2) or (g and g.spell == id and now < g.ends + 1))
        if keep then n = n + 1 out[n] = id
        else
            if c and c.cooling and c.ends and now >= c.ends + 2 then c.cooling = false c.readySrc = "predicted" end
            self:cdActivate(id, false)
        end
    end
    for i = n + 1, #out do out[i] = nil end
    return out
end

-- the cooling spell with the latest start (O(k), only when the current latest settles: once per cooldown end)
function M:cdPickLatest()
    local best, bs = nil, nil
    for _, aid in ipairs(self.cd.list) do
        local c = self.cd.spells[aid]
        if c and c.cooling and c.start and c.ends and (not bs or c.start > bs) then best, bs = aid, c.start end
    end
    self.cd.latest = best
end

-- keep an active spell (still cooling / holding the GCD) or retire it (predicted ready + 2 s grace)
local function cdVisit(self, id, now, g)
    local c = self.cd.spells[id]
    local keep = c and ((c.cooling and c.ends and now < c.ends + 2) or (g and g.spell == id and now < g.ends + 1))
    if not keep then
        if c and c.cooling and c.ends and now >= c.ends + 2 then c.cooling = false c.readySrc = "predicted" end
        self:cdActivate(id, false)
        if self.cd.latest == id then self:cdPickLatest() end
        return false
    end
    return true
end

-- per-event re-check list, O(due + budget) independent of how many spells are cooling (perf gate, SPELL_UPDATE_COOLDOWN
-- storm): spells whose predicted ready time is within `horizon` s (from the heap, then kept in the due set until they
-- settle), the GCD spell while the GCD runs, and `budget` far-from-ready active spells round-robin. Expiry pruning (what
-- CDActive does for all k) happens for the visited spells. Returns a reused buffer.
function M:CDCheckList(horizon, budget)
    local cd = self.cd
    local now = self.now()
    local h, due, spells = cd.heap, cd.due, cd.spells
    while h[1] and h[1][1] - now < horizon do
        local e = heapPop(h)
        local c = spells[e[2]]
        if c and c.hseq == e[3] and c.cooling and cd.active[e[2]] then due[e[2]] = true end
    end
    local out, n = cd.checkBuf, 0
    if not out then out = {} cd.checkBuf = out end
    local g = cd.gcd
    for id in pairs(due) do
        if cdVisit(self, id, now, g) then
            local c = spells[id]
            if c and c.cooling and c.ends and c.ends - now >= horizon and not (g and g.spell == id) then due[id] = nil end
            n = n + 1 out[n] = id
        end
    end
    if g and g.spell and not due[g.spell] and cd.active[g.spell] and cdVisit(self, g.spell, now, g) then n = n + 1 out[n] = g.spell end
    local list = cd.list
    local k = #list
    for _ = 1, math.min(budget, k) do
        k = #list
        if k == 0 then break end
        cd.rr = cd.rr % k + 1
        local id = list[cd.rr]
        -- far-from-ready spells (> 2 s from predicted ready): re-read at most once per second each (bounded staleness,
        -- independent of the event rate; due spells are read on every event)
        if id and not due[id] and not (g and g.spell == id) and cdVisit(self, id, now, g) then
            local c = spells[id]
            if now - (c.rrAt or -1e9) >= 1 then c.rrAt = now n = n + 1 out[n] = id end
        end
    end
    for i = n + 1, #out do out[i] = nil end
    return out
end

-- v2.2.12: next time a cooldown re-read is worth doing without an event (run 9: readiness seen 0.3-2 s late because
-- nothing fired at the predicted end). O(due + 1): the due set (<= 2 s from ready) and the heap top only.
-- A spell at/after its predicted end gets a second probe at end + tolerance (a still-cooling sample there proves C).
function M:CDNextSampleAt(now)
    local cd = self.cd
    local best
    local function consider(c)
        if not (c and c.cooling and c.ends) then return end
        local t = c.ends + 0.02
        if t <= now then t = c.ends + CD_TOL + 0.05 end
        if t > now and (not best or t < best) then best = t end
    end
    for id in pairs(cd.due) do consider(cd.spells[id]) end
    -- v2.2.15 (run 12: gcd 2V/17C, all late observation): bracket the predicted GCD end with one sample just before
    -- it (still on) and one just after (off), so the observed end is known to within ~0.1 s
    local g = cd.gcd
    if g and not g.ended and g.ends then
        for _, t in ipairs({ g.ends - 0.05, g.ends + 0.05, g.ends + GCD_TOL + 0.05 }) do
            if t > now and (not best or t < best) then best = t end
        end
    end
    local top = cd.heap[1]
    if top then
        local c = cd.spells[top[2]]
        if c and c.hseq == top[3] then consider(c) end
    end
    return best
end

-- one NeverSecret read of C_Spell.GetSpellCooldown(id) (+ remaining/duration only when clear, out of combat)
function M:CDObserve(id, isActive, isOnGCD, remaining, duration)
    if type(id) ~= "number" then return end
    local now = self.now()
    local c = self:cdSpell(id)
    local g = self.cd.gcd
    -- GCD end: the GCD spell (or any checked spell) reported isOnGCD true, now false / inactive
    if g and not g.ended then
        if isOnGCD == true then g.seenOn = true g.lastOnT = now
        elseif (isOnGCD == false or isActive == false) and g.seenOn and now - g.start > 0.3 then
            local len = now - g.start
            g.ended, g.observedEnd = true, now
            -- v2.2.15: the real end lies in (last sample still on, this sample]; a late first "off" sample is a wide
            -- bracket, not a contradiction. V = the old test (|observed - predicted| <= tol) unchanged; C = the predicted
            -- end lies outside the bracket (+-tol); a wide bracket that contains it = U (unmeasured), not C.
            local lo = g.lastOnT or g.start
            local predEnd = g.start + g.length
            local v
            if math.abs(len - g.length) <= GCD_TOL then v = "V"
            elseif predEnd < lo - GCD_TOL or predEnd > now + GCD_TOL then v = "C"
            else v = "U" end
            local sc = self:cdSpell(g.spell)
            if now - lo <= 2 * GCD_TOL then ring8(sc.gcdLearned, len) self:cdLearn("gcd", g.spell, len) end
            push(self.cd.gcds, { t = g.start, spell = g.spell, pred = g.length, actual = len, src = g.source, lo = lo - g.start }, 100)
            self:verdict("gcd", v, { spell = g.spell, src = "isOnGCD", conf = g.conf, d = len - g.length })
        end
    end
    -- calibration from clear numbers (out of combat): duration beyond the GCD = the real cooldown of this cast
    if type(duration) == "number" and type(remaining) == "number" and duration > 0 then
        if isOnGCD == true then
            if g and g.spell == id and not g.ended then
                g.ends = now + remaining g.source = "api-clear" g.conf = "high"
                if g.calLen ~= duration then g.calLen = duration self:cdLearn("gcdcal", id, duration) end
            end
        elseif duration > 1.5 then
            if c.cal ~= duration then self:cdLearn("cal", id, duration) end
            c.cal = duration
            if c.cooling then c.ends = now + remaining c.src = "api-clear" c.conf = "high" self:cdSchedule(id, c) end
        end
    end
    if isActive == true and c.cooling then c.lastCoolT = now end   -- v2.2.12: last sample still cooling (bracket low end)
    if isActive == true and isOnGCD == false and c.cooling then c.obs = "active" end
    if isActive == true and isOnGCD == true and c.cooling then c.gcdOnly = true end
    if isActive == false and c.cooling and c.start then
        local since = now - c.start
        local gl = (g and g.spell == id and g.length) or 1.5
        if since > gl + 0.05 then
            -- observed ready outside the GCD: learn the true cooldown of this spell (shared members learn their own)
            c.cooling, c.readyAt, c.readySrc = false, now, "isActive"
            if self.cd.latest == id then self:cdPickLatest() end
            if not c.sharedFrom or c.sharedFrom == id then ring8(c.learned, since) self:cdLearn("cd", id, since) end
            local pe = c.ends
            push(self.cd.readies, { t = c.start, spell = id, pred = pe and (pe - c.start), actual = since, src = c.src }, 100)
            -- v2.2.12 (run 9: 75/90 C): readiness is only sampled when an event arrives, so "first sample showing ready"
            -- is (true ready, ready + observation latency]. The true ready time lies in (lastCoolT, now]:
            --   C  ready seen before the predicted end - tolerance (prediction too long), or a sample still showing
            --      cooling after predicted end + tolerance (prediction too short)  -- both are proven errors;
            --   V  |now - pe| <= tolerance (as before);
            --   U  sample came late and nothing proves the prediction wrong (latency, not error).
            -- One verdict per shared-category observation (shocks share category 19: 1 sample = 1 verdict, not 3).
            local dup = false
            if c.category then
                local rv = self.cd.readyVerdictAt or {}
                self.cd.readyVerdictAt = rv
                dup = rv[c.category] == now
                rv[c.category] = now
            end
            if pe and not dup then
                local lo = c.lastCoolT and c.lastCoolT >= c.start and c.lastCoolT or nil
                local v, why
                if pe > now + CD_TOL then v, why = "C", "early"
                elseif lo and lo > pe + CD_TOL then v, why = "C", "late"
                elseif now - pe <= CD_TOL then v, why = "V", nil
                else v, why = "U", "sample-latency" end
                self:verdict("cd-ready", v, { spell = id, src = "isActive", conf = c.conf, d = now - pe,
                    why = why, gap = lo and (now - lo) or nil })
            end
            c.sharedFrom = nil
            self:cdActivate(id, (g and g.spell == id and not g.ended) or false)
        end
    end
    self.version = self.version + 1
end

function M:GCDObserve(remaining, duration)
    local g = self.cd.gcd
    if g and not g.ended and type(remaining) == "number" then
        g.ends = self.now() + remaining
        if type(duration) == "number" and duration > 0 then g.length = duration end
        g.source, g.conf = "api-clear", "high"
    end
end

function M:GCD()
    local g = self.cd.gcd
    if not g then return nil end
    local now = self.now()
    local ends = g.observedEnd or g.ends
    if now >= ends then return nil end
    return { ends = ends, spell = g.spell, length = g.length, remaining = ends - now, source = g.source, confidence = g.conf }
end

function M:Cooldown(spellID)
    local now = self.now()
    local c = self.cd.spells[spellID]
    if c and c.cooling and c.ends and now < c.ends then
        return { state = "cooling", ends = c.ends, remaining = c.ends - now, confidence = c.conf, source = c.src,
            observed = c.obs, shared = c.sharedFrom }
    end
    local g = self:GCD()
    if g and not (c and c.srCategory == 0) then
        local gl = c and select(1, self:gcdLength(c, spellID))
        if gl ~= 0 then return { state = "gcd", ends = g.ends, remaining = g.remaining, confidence = g.confidence, source = "gcd:" .. tostring(g.source) } end
    end
    -- legacy prediction (no tracker entry yet)
    local lc = not (c and c.lastCast) and self:CooldownRecord(spellID)   -- the tracker owns spells it has seen cast
    if lc and lc.ends then return { state = "cooling", ends = lc.ends, remaining = lc.ends - now, confidence = "medium", source = lc.source or "predicted" } end
    return { state = "ready", confidence = c and (c.readySrc == "isActive" and "high" or "medium") or "low", source = c and c.readySrc or "default" }
end

function M:CDExport()
    local out = {}
    for id, c in pairs(self.cd.spells) do
        if c.lastCast or c.category or #c.learned > 0 then
            out[id] = { base = c.base, baseGCD = c.baseGCD, learned = cdmed(c.learned), learnedN = #c.learned, gcd = cdmed(c.gcdLearned),
                gcdN = #c.gcdLearned, category = c.category, srCategory = c.srCategory, cal = c.cal, failConfirm = c.failConfirm }
        end
    end
    return { spells = out, readies = self.cd.readies, gcds = self.cd.gcds }
end

-- v2.2.21 (user decision): raw GUIDs are kept everywhere - ScrubKey / ScrubExport are identity functions now (names
-- kept for API compatibility); export and display show the raw GUID.
local GUID_PREFIX = { "^Player%-", "^Creature%-", "^Pet%-", "^Vehicle%-", "^GameObject%-" }
local function isGuid(v)
    if type(v) ~= "string" then return false end
    for i = 1, #GUID_PREFIX do if v:find(GUID_PREFIX[i]) then return true end end
    return false
end
Lib.IsGuid = isGuid
function M.ScrubKey(_, v)
    return v
end
local function scrubCopy(self, t, depth, seen)
    if type(t) ~= "table" then return self:ScrubKey(t) end
    if seen[t] then return seen[t] end
    if depth > 8 then return nil end
    local c = {}
    seen[t] = c
    for k, v in pairs(t) do
        local nk = self:ScrubKey(k)
        if c[nk] == nil then c[nk] = scrubCopy(self, v, depth + 1, seen) end
    end
    return c
end
function M:ScrubExport(t) return scrubCopy(self, t, 0, {}) end

function M:Export()
    local seen = {}
    local function sc(t) return scrubCopy(self, t, 0, seen) end
    return { predictions = sc(self.predictions), inferences = sc(self.inferences), contradictions = sc(self.contradictions),
        counters = self.counters, fights = sc(self.fights), ledger = self.ledger and self.ledger:Export() or nil,
        casts = sc(self.castPreds), castModel = sc(self:CastModelExport()), verdicts = self.verdicts, cd = sc(self:CDExport()),
        lastReconcile = sc(self.lastReconcile), candStats = sc(self.candStats), candCost = sc(self.candCost),
        knowledgeSpells = (function() local n = 0 for _ in pairs(self.knowledge) do n = n + 1 end return n end)() }
end

-- v2.2.7 (ForeverDump run 6b, secret-boolean class): BOUNDARY GUARD. HybridState never sees a secret value: every public
-- input method gets its arguments scrubbed first - a secret scalar becomes nil, a table with secret fields (two levels
-- deep) is replaced by a copy without them. Clean inputs pass through untouched (no copy, no garbage). Inside the
-- library every truth test / compare therefore runs on clear values only (embedders on secret-value clients included).
local issecret = rawget(_G, "issecretvalue")
-- issecretvalue accepts any value and returns a plain boolean; nil is never secret (skip the C call for absent args)
local function isSecretValue(v)
    if issecret == nil or type(v) == "nil" then return false end   -- type() is safe on secrets; == is not
    return rawequal(issecret(v), true)
end
local function hasSecret(v, depth)
    if isSecretValue(v) then return true end
    if type(v) ~= "table" or depth <= 0 then return false end
    for k, x in next, v do
        if isSecretValue(k) or hasSecret(x, depth - 1) then return true end
    end
    return false
end
local function scrub(v, depth)
    if isSecretValue(v) then return nil end
    if type(v) ~= "table" or depth <= 0 or not hasSecret(v, depth) then return v end
    local out = {}
    for k, x in next, v do
        if not isSecretValue(k) then out[k] = scrub(x, depth - 1) end
    end
    return out
end
Lib.Scrub = function(v) return scrub(v, 3) end
Lib.BOUNDARY = { "Learn", "SetRestriction", "OnCast", "OnAura", "OnCount", "RecordAura", "OnTotem", "OnCombatState", "OnSwing",
    "OnDamageMeter", "OnUnitCombat", "OnInterrupt", "ReconcileDM", "OnEnemyCast", "OnCastFailed", "OnHealthMax", "OnHealthEvent",
    "CDInfo", "CDPayload", "CDSeed", "CDCast", "CDObserve", "GCDObserve", "Cooldown", "UnitState", "CastState", "EnemyCast", "Health",
    "SetGroupSize", "CDNextSampleAt", "SetCensus", "SeedSelfLink", "CandHealthActual" }
Lib.LEDGER_BOUNDARY = { "Put", "Get", "Invalidate", "Remove", "Fingerprint", "PutFingerprint" }
-- argument positions that key a table inside the method: nil there (absent, or scrubbed because it was secret) skips the
-- call instead of raising "table index is nil" (found by tests/secret_inject.lua)
Lib.REQUIRED = { SetRestriction = 1, OnCast = 2, OnAura = 1, OnCount = 1, RecordAura = 1, OnUnitCombat = 1, OnInterrupt = 1,
    OnEnemyCast = 2, OnHealthMax = 1, OnHealthEvent = 1, CDInfo = 1, CDPayload = 1, CDSeed = 1, CDCast = 1, CDObserve = 1,
    Learn = 1, UnitState = 1, CastState = 1, EnemyCast = 1, Health = 1, Cooldown = 1, CandHealthActual = 1,
    Put = 2, Get = 2, Invalidate = 2, Remove = 2, Fingerprint = 1, PutFingerprint = 1 }
-- fixed arity (every BOUNDARY method takes <= 6 named parameters and no varargs; tests/test_v227_secret_lint.py S5 checks
-- it): no select("#")/vararg recursion on the hot path (SPELL_UPDATE_COOLDOWN storm: ~50 CDObserve calls per event)
local MAXARGS = 6
Lib.MAXARGS = MAXARGS
-- named-parameter count of every guarded method (tests/test_v227_secret_lint.py S5 checks it against the signatures):
-- the wrapper only inspects the parameters the method actually has
Lib.ARITY = { Learn = 2, SetRestriction = 2, OnCast = 5, OnAura = 2, OnCount = 3, RecordAura = 3, OnTotem = 4,
    OnCombatState = 1, OnSwing = 0, OnDamageMeter = 1, OnUnitCombat = 6, OnInterrupt = 1, ReconcileDM = 1,
    OnEnemyCast = 5, OnCastFailed = 3, OnHealthMax = 2, OnHealthEvent = 1, CDInfo = 2, CDPayload = 4, CDSeed = 2,
    CDCast = 2, CDObserve = 5, GCDObserve = 2, Cooldown = 1, UnitState = 1, CastState = 1, EnemyCast = 1,
    Health = 1, SetGroupSize = 1, CDNextSampleAt = 1, SetCensus = 1, SeedSelfLink = 3, CandHealthActual = 3,
    Put = 4, Get = 2, Invalidate = 2, Remove = 2, Fingerprint = 1, PutFingerprint = 2 }
local function dirty(v)
    local tv = type(v)
    if tv == "nil" then return false end
    if tv == "table" then return hasSecret(v, 3) end
    return rawequal(issecret(v), true)
end
local function argNil(r, a1, a2, a3, a4, a5, a6)
    if r == 1 then return type(a1) == "nil" elseif r == 2 then return type(a2) == "nil" end
    return type((select(r, a1, a2, a3, a4, a5, a6))) == "nil"
end
local function guard(tbl, name)
    local f = rawget(tbl, name)
    if type(f) ~= "function" then return end
    local req, n = Lib.REQUIRED[name], Lib.ARITY[name] or MAXARGS
    local function drop(self) self.secretDropped = (self.secretDropped or 0) + 1 end
    if n <= 1 then
        tbl[name] = function(self, a1)
            if issecret ~= nil and dirty(a1) then drop(self) a1 = scrub(a1, 3) end
            if req ~= nil and type(a1) == "nil" then return nil end
            return f(self, a1)
        end
    elseif n == 2 then
        tbl[name] = function(self, a1, a2)
            if issecret ~= nil and (dirty(a1) or dirty(a2)) then drop(self) a1, a2 = scrub(a1, 3), scrub(a2, 3) end
            if req ~= nil and argNil(req, a1, a2) then return nil end
            return f(self, a1, a2)
        end
    else
        tbl[name] = function(self, a1, a2, a3, a4, a5, a6)
            if issecret ~= nil and (dirty(a1) or dirty(a2) or dirty(a3) or dirty(a4) or dirty(a5) or dirty(a6)) then
                drop(self)
                a1, a2, a3, a4, a5, a6 = scrub(a1, 3), scrub(a2, 3), scrub(a3, 3), scrub(a4, 3), scrub(a5, 3), scrub(a6, 3)
            end
            if req ~= nil and argNil(req, a1, a2, a3, a4, a5, a6) then return nil end
            return f(self, a1, a2, a3, a4, a5, a6)
        end
    end
end
for _, name in ipairs(Lib.BOUNDARY) do guard(M, name) end
for _, name in ipairs(Lib.LEDGER_BOUNDARY) do guard(LedgerM, name) end
do
    local npcKey = Lib.NpcKey
    Lib.NpcKey = function(guid) if isSecretValue(guid) then return nil end return npcKey(guid) end
end

_G.HybridState = Lib
return Lib
