-- ForeverDump v2.2 - spell knowledge collector (feeds the hybrid state machine and the guide).
-- For the player's known spells: tooltip lines (C_TooltipInfo.GetSpellByID: leftText/rightText + per-line secrecy),
-- C_Spell.GetSpellDescription, C_Spell.GetSpellInfo (castTime/minRange/maxRange), GetSpellBaseCooldown,
-- C_Spell.GetSpellPowerCost, C_Spell.GetSpellCharges, C_Spell.IsSpellHelpful/Harmful and the C_Secrets secrecy levels.
-- Collected out of combat (clear text kept, numbers parsed from CLEAR text only) and re-checked in combat
-- (classification only) so the per-field secrecy across contexts is part of the answer. Stored per build in
-- ForeverDumpDB.knowledge[build]; chunked over frames (spellsPerTick) so it never spikes.
local _, ns = ...
local K = {}
ns.Knowledge = K

local function g(n) return rawget(_G, n) end
local function code(v) return ns.ClassifyValue(v) end
local function clear(v) local c = code(v) return (c == "C" or c == "K") and v or nil end
local function fn(path) local f = ns.Resolve(path) return type(f) == "function" and f or nil end
local function call(path, ...)
    local f = fn(path)
    if not f then return "absent" end
    return ns.Pack(pcall(f, ...))
end
local function ctxName()
    if ns.Secrets and ns.Secrets.InEncounter and ns.Secrets.InEncounter() then return "enc" end
    return ns.InCombat() and "combat" or "ooc"
end
local function cfg() return (ns.config and ns.config.knowledge) or {} end

function K.Build()
    return ns.Build and ns.Build() or "?"   -- v2.2.3: cached; ns.Meta() walked _G on every call
end
function K.DB()
    local db = ns.db
    if type(db) ~= "table" then return nil end
    db.knowledge = db.knowledge or {}
    local b = K.Build()
    db.knowledge[b] = db.knowledge[b] or { spells = {}, player = {}, v = 1 }
    return db.knowledge[b]
end

-- numbers from CLEAR description/tooltip text (never touched when secret).
-- v2.2.4: every "N sec|min|seconds|minutes" phrase is classified by the clause it belongs to (PARSER RULES, checked by
-- tests/knowledge_parse.lua + `fdump knowledge` semantic lint in every build):
--   lockout  "prevents any spell in that school from being cast for 2 sec", "locks out", "interrupt" -> p.lockout, p.interrupt
--   stun     "stuns ... for N sec"                                  -> p.stun (a debuff: also the aura duration)
--   summon   any clause of a "Summons ..." text                     -> p.summonDuration (never an aura or cast amount)
--   imbue    any clause of an "Imbue ..." text                      -> p.imbueDuration (never an aura or cast amount)
--   period   "every N sec(onds)"                                     -> p.period (a pulse interval, never a duration)
--   cooldown/cast  "N sec cooldown", "N sec cast"                   -> header fields (ParseHeader), never a duration
--   aura     "Lasts N", "for N sec" after an effect verb, "over N sec" -> p.auraDuration
--   anything else                                                   -> p.ambiguous (no duration is set from it)
-- "with N health" (summons) is never an amount; summon/imbue amounts go to summonPulse/imbueAmount, not cast amounts.
local AURA_VERBS = { "increas", "reduc", "decreas", "slow", "absorb", "shield", "surround", "grant", "root", "snare", "silenc",
    "fear", "immobil", "protect", "chance", "damage you deal", "allow", "walk", "breathe", "transform", "detect", "stealth",
    "heals? .- every", "lasts", "resist", "speed", "attack power", "armor" }
local function clauseKind(cl, ctx)
    local l = cl:lower()
    if l:find("prevent") or l:find("lock") or l:find("from being cast") or l:find("interrupt") then return "lockout" end
    if l:find("%f[%a]stun") then return "stun" end
    if ctx.summon then return "summon" end
    if ctx.imbue then return "imbue" end
    for _, v in ipairs(AURA_VERBS) do if l:find(v) then return "aura" end end
    if l:find("over%s+%d") then return "aura" end
    return "ambiguous"
end
K.ClauseKind = clauseKind

function K.Parse(text)
    if type(text) ~= "string" or ns.IsSecret(text) then return nil end
    local t = text:gsub(",", "")
    local p = {}
    local sname = t:match("[Ss]ummons? an?%s+(.-[Tt]otem)") or t:match("[Ss]ummons? an?%s+([%a%s]-)%s+[wfat]%a*%s")
    if t:find("[Ss]ummons? ") then p.summon, p.summonName = true, sname end
    if t:find("[Rr]emov%a*%s+%d+.-effects?") or t:find("[Cc]ures?%s+%d+.-effects?") or t:find("[Dd]ispels?%s")
        or t:find("^[Pp]urges?%s") then p.dispel = true end
    if t:find("%f[%a][Ii]mbue") then p.weaponImbue = true end
    local ctx = { summon = p.summon, imbue = p.weaponImbue }
    -- amounts (a summon's "with N health" is stripped first: it is the totem's health, not a heal or damage)
    local ta = t:gsub("with%s+%d+%s+health", "")
    local amt = {}
    local a, b, kind = ta:match("(%d+)%s+to%s+(%d+)%s+([%a]+)%s+damage")
    if a then amt.min, amt.max, amt.kind, p.school = tonumber(a), tonumber(b), "damage", kind end
    if not a then
        a, b = ta:match("(%d+)%s+to%s+(%d+)%s+damage")
        if a then amt.min, amt.max, amt.kind = tonumber(a), tonumber(b), "damage" end
    end
    if not amt.min then   -- "heals ... for N (to M)" first: "Healing Stream Totem ... for 5 min" must not read 5 as the heal
        a, b = ta:match("%f[%a][Hh]eals?%f[%A][^%.]-for%s+(%d+)%s+to%s+(%d+)")
        if not a then a = ta:match("%f[%a][Hh]eals?%f[%A][^%.]-for%s+(%d+)%s+[^ms%d]") b = a end
        if a then amt.min, amt.max, amt.kind = tonumber(a), tonumber(b), "heal" end
    end
    if not amt.min then
        a, b = ta:match("%f[%a][Hh]eal[si]?n?g?%f[%A][^%d]-(%d+)%s+to%s+(%d+)")
        if a then amt.min, amt.max, amt.kind = tonumber(a), tonumber(b), "heal" end
    end
    if not amt.min then
        local dmg = ta:match("(%d+)%s+[%a]*%s*damage")
        local heal = ta:match("%f[%a][Hh]eal[si]?n?g?%f[%A][^%d]-(%d+)")
        a = dmg or heal
        if a then amt.min, amt.max, amt.kind = tonumber(a), tonumber(a), dmg and "damage" or "heal" end
    end
    local over = t:match("over%s+(%d+%.?%d*)%s+sec")
    if over then p.overTime = tonumber(over) end
    local per = t:match("every%s+(%d+%.?%d*)%s+sec")
    if per then p.period = tonumber(per) end
    -- duration phrases, clause by clause (sentences split on ". ")
    p.durations = {}
    local prot = t:gsub("(%d)%.(%d)", "%1#%2")   -- keep decimals ("1.5 sec") inside their sentence
    for raw in prot:gmatch("[^%.!]+") do
        local sentence = raw:gsub("#", ".")
        if sentence:find("%S") then
            for n, unit in sentence:gmatch("(%d+%.?%d*)%s+(%a+)") do
                local u = unit:lower()
                local secs = (u == "sec" or u == "seconds" or u == "second") and tonumber(n)
                    or ((u == "min" or u == "minutes" or u == "minute") and tonumber(n) * 60) or nil
                if secs then
                    local esc = n:gsub("%.", "%%.")
                    local isPeriod = sentence:find("every%s+" .. esc .. "%s+" .. unit)
                    local isHeader = sentence:find(esc .. "%s+" .. unit .. "%s+cooldown") or sentence:find(esc .. "%s+" .. unit .. "%s+cast")
                    local k = (isPeriod and "period") or (isHeader and "header") or clauseKind(sentence, ctx)
                    p.durations[#p.durations + 1] = { n = secs, kind = k }
                end
            end
        end
    end
    for _, d in ipairs(p.durations) do
        if d.kind == "lockout" then p.lockout = p.lockout or d.n p.interrupt = true
        elseif d.kind == "stun" then p.stun = p.stun or d.n p.auraDuration = p.auraDuration or d.n
        elseif d.kind == "summon" then p.summonDuration = p.summonDuration or d.n
        elseif d.kind == "imbue" then p.imbueDuration = p.imbueDuration or d.n
        elseif d.kind == "aura" then p.auraDuration = p.auraDuration or d.n
        elseif d.kind == "ambiguous" then p.ambiguous = (p.ambiguous or 0) + 1 end
    end
    if t:lower():find("interrupts? spellcasting") then p.interrupt = true end
    -- charge-based auras end early by design ("expends one lightning ball", "N charges"): expiry is not a contradiction
    local tl = t:lower()
    if tl:find("expends? one") or tl:find("%d+ charges?") or tl:find("consumes? a charge") then p.consumable = true end
    if #p.durations == 0 then p.durations = nil end
    if amt.min then
        if p.summon then p.summonPulse = { min = amt.min, max = amt.max, kind = amt.kind, period = p.period }
        elseif p.weaponImbue then p.imbueAmount = { min = amt.min, max = amt.max, kind = amt.kind }
        else p.amountMin, p.amountMax, p.amountKind = amt.min, amt.max, amt.kind end
        if p.summon or p.weaponImbue then p.school = nil end
    end
    if next(p) == nil then return nil end
    return p
end

-- v2.2.4 semantic lint of one parse (PERMANENT check: tests/knowledge_parse.lua, `fdump knowledge`, every build).
-- Returns a list of { rule, detail } violations; empty = the parse obeys the parser rules above.
function K.Lint(text, p)
    local out = {}
    if type(text) ~= "string" then return out end
    p = p or {}
    local t = text:gsub(",", "")
    local l = t:lower()
    local function bad(rule, detail) out[#out + 1] = { rule = rule, detail = detail } end
    local lock = l:match("from being cast for (%d+%.?%d*) sec") or l:match("locks? out[^%.]-(%d+%.?%d*) sec")
    if lock and p.auraDuration == tonumber(lock) and not p.stun then bad("lockout-as-aura", "lockout " .. lock .. " s became auraDuration") end
    if lock and not p.interrupt then bad("lockout-missed", "lockout phrase without p.interrupt/p.lockout") end
    if p.summon and (p.auraDuration or p.amountMin) then bad("summon-as-aura-or-amount", "summon lifetime/pulse leaked into aura or cast amount") end
    if p.weaponImbue and (p.auraDuration or p.amountMin) then bad("imbue-as-aura-or-amount", "imbue duration/amount leaked into aura or cast amount") end
    local hp = t:match("with%s+(%d+)%s+health")
    if hp and ((p.amountMin == tonumber(hp)) or (p.summonPulse and p.summonPulse.min == tonumber(hp) and not t:find("for%s+" .. hp .. "%s+every"))) then
        bad("health-as-amount", "'with " .. hp .. " health' read as an amount")
    end
    if p.period and p.auraDuration == p.period and not t:find("[Ll]asts%s+" .. tostring(p.period)) then
        bad("period-as-duration", "pulse interval read as a duration")
    end
    -- every "N sec|min" phrase must be classified (aura / lockout / stun / summon / imbue / period / header) or ambiguous
    local phrases = 0
    local prot = t:gsub("(%d)%.(%d)", "%1#%2")
    for _, unit in prot:gmatch("(%d+#?%d*)%s+(%a+)") do
        local u = unit:lower()
        if u == "sec" or u == "seconds" or u == "second" or u == "min" or u == "minutes" or u == "minute" then phrases = phrases + 1 end
    end
    local classified = p.durations and #p.durations or 0
    if phrases ~= classified then bad("unclassified-duration", phrases .. " duration phrase(s), " .. classified .. " classified") end
    return out
end

-- v2.2.4: the structured tooltip header lines (left/right text of lines 2-3) as a cross-check of the APIs:
-- "N Mana" (any power word), "N yd range", "N sec cooldown" / "N min cooldown", "Instant", "N sec cast", "Channeled"
function K.ParseHeader(lines)
    if type(lines) ~= "table" then return nil end
    local h = {}
    for i = 1, math.min(#lines, 4) do
        local ln = lines[i]
        for _, txt in ipairs({ ln and ln.l, ln and ln.r }) do
            if type(txt) == "string" and not ns.IsSecret(txt) then
                local x = txt:gsub(",", "")
                local c, pw = x:match("^(%d+)%s+(%a+)$")
                if c and pw ~= "yd" then h.cost, h.costWord = tonumber(c), pw end
                local r = x:match("(%d+)%s+yd range") if r then h.range = tonumber(r) end
                if x:find("^Melee Range") then h.range = "melee" end
                local cd, cu = x:match("(%d+%.?%d*)%s+(%a+)%s+cooldown")
                if cd then h.cooldown = tonumber(cd) * ((cu == "min") and 60 or 1) end
                if x == "Instant" then h.castTime = 0 end
                local ct = x:match("^(%d+%.?%d*)%s+sec cast") if ct then h.castTime = tonumber(ct) end
                if x:find("^Channeled") then h.channeled = true end
            end
        end
    end
    return next(h) and h or nil
end

-- the player's spells: spellbook (C_SpellBook) when present, else the configured probe spells
function K.SpellList()
    local out, seen = {}, {}
    local maxN = tonumber(cfg().maxSpells) or 150
    local sb = g("C_SpellBook")
    local bank = (g("Enum") and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
    if type(sb) == "table" and type(sb.GetNumSpellBookSkillLines) == "function" then
        local okN, n = pcall(sb.GetNumSpellBookSkillLines)
        if okN and type(n) == "number" and not ns.IsSecret(n) then
            for i = 1, math.min(n, 12) do
                local okI, info = pcall(sb.GetSpellBookSkillLineInfo, i)
                if okI and type(info) == "table" and not info.shouldHide then
                    local off, num = clear(info.itemIndexOffset), clear(info.numSpellBookItems)
                    for idx = (off or 0) + 1, (off or 0) + (num or 0) do
                        local okT, _, _, sid = pcall(sb.GetSpellBookItemType, idx, bank)
                        if okT and type(clear(sid)) == "number" and not seen[sid] and #out < maxN then
                            seen[sid] = true out[#out + 1] = sid
                        end
                    end
                end
            end
        end
    end
    if #out == 0 then for _, s in ipairs((ns.config.probe and ns.config.probe.spells) or {}) do out[#out + 1] = s end end
    return out
end

local function playerInfo()
    local p = {}
    local r = call("UnitClass", "player")
    if type(r) == "table" and r[1] then p.className, p.class, p.classID = clear(r[2]), clear(r[3]), clear(r[4]) end
    r = call("UnitLevel", "player") if type(r) == "table" and r[1] then p.level = clear(r[2]) end
    r = call("UnitRace", "player") if type(r) == "table" and r[1] then p.race = clear(r[3]) end
    r = call("C_SpecializationInfo.GetSpecialization")
    if type(r) == "table" and r[1] then
        p.specIndex = clear(r[2])
        if type(p.specIndex) == "number" then
            local s = call("C_SpecializationInfo.GetSpecializationInfo", p.specIndex)
            if type(s) == "table" and s[1] then p.specID, p.specName, p.role = clear(s[2]), clear(s[3]), clear(s[6]) end
        end
    else p.specIndex = "absent" end
    return p
end

-- one spell: per-field five-state codes (stored for every context) + clear data (stored out of combat)
function K.Collect(id, withData)
    local codes, data = {}, withData and {} or nil
    local function rec(field, v, keep)
        codes[field] = code(v)
        if data and keep and codes[field] == "C" then
            if type(v) == "string" and #v > 600 then v = v:sub(1, 600) end   -- v2.2.4: 600 (was 300)
            data[field] = v
        end
    end
    local r = call("C_Spell.GetSpellInfo", id)
    if r == "absent" then codes.info = "absent"
    elseif r[1] and type(r[2]) == "table" and (code(r[2]) == "K" or code(r[2]) == "T") then
        -- v2.2.22 (audit): T struct read per field (was K-only: whole struct coded once, no field codes)
        if code(r[2]) == "T" then codes.info = "T" end
        for _, f in ipairs({ "name", "iconID", "castTime", "minRange", "maxRange" }) do
            local okF, v = pcall(function() return r[2][f] end)
            if okF then rec("info." .. f, v, true) else codes["info." .. f] = "E" end
        end
    else codes.info = r[1] and code(r[2]) or "E" end
    r = call("C_Spell.GetSpellDescription", id)
    if r ~= "absent" then rec("description", r[1] and r[2] or nil, true) else codes.description = "absent" end
    r = call("GetSpellBaseCooldown", id)
    if r ~= "absent" then rec("baseCooldown", r[1] and r[2] or nil, true) rec("baseGCD", r[1] and r[3] or nil, true) else codes.baseCooldown = "absent" end
    r = call("C_Spell.GetSpellPowerCost", id)
    if r ~= "absent" then
        codes.powerCost = r[1] and code(r[2]) or "E"
        if r[1] and type(r[2]) == "table" and (codes.powerCost == "K" or codes.powerCost == "T") then
            -- v2.2.4: EVERY cost entry (multi-cost spells), not only [1]. v2.2.22: T list read per entry / field
            local costs = {}
            local okL, nl = pcall(function() return #r[2] end)
            nl = (okL and code(nl) == "C") and nl or 0
            for i = 1, math.min(nl, 6) do
                local okE, c = pcall(function() return r[2][i] end)
                if okE and type(c) == "table" and code(c) ~= "S" then
                    codes["powerCost." .. i] = code(c.cost)
                    costs[#costs + 1] = { type = clear(c.type), cost = clear(c.cost), costPerSec = clear(c.costPerSec), minCost = clear(c.minCost),
                        requiredAuraID = clear(c.requiredAuraID), name = clear(c.name) }
                end
            end
            codes["powerCost.n"] = #costs
            if data then
                data.costs = costs
                if costs[1] then data.cost, data.costType = costs[1].cost, costs[1].type end   -- v2.2.3 fields kept
                codes["powerCost.cost"] = codes["powerCost.1"]
            end
        end
    end
    r = call("C_Spell.GetSpellCharges", id)
    if r ~= "absent" then
        codes.charges = r[1] and code(r[2]) or "E"
        if r[1] and type(r[2]) == "table" and codes.charges ~= "S" then
            rec("charges.max", r[2].maxCharges, true) rec("charges.current", r[2].currentCharges, false)
        end
    end
    for _, h in ipairs({ "IsSpellHelpful", "IsSpellHarmful" }) do
        r = call("C_Spell." .. h, id)
        if r ~= "absent" then rec(h, r[1] and r[2] or nil, true) end
    end
    for _, s in ipairs({ "GetSpellAuraSecrecy", "GetSpellCastSecrecy", "GetSpellCooldownSecrecy", "ShouldSpellAuraBeSecret" }) do
        r = call("C_Secrets." .. s, id)
        if r ~= "absent" then rec("secrecy." .. s, r[1] and r[2] or nil, true) end
    end
    r = call("C_TooltipInfo.GetSpellByID", id)
    if r ~= "absent" then
        codes.tooltip = r[1] and code(r[2]) or "E"
        if r[1] and type(r[2]) == "table" and codes.tooltip ~= "S" then
            local lines = r[2].lines
            if type(lines) == "table" and code(lines) ~= "S" then
                local ls, n, types = {}, 0, {}
                for i = 1, math.min(#lines, 20) do   -- v2.2.4: 20 lines (was 12)
                    local ln = lines[i]
                    if type(ln) == "table" then
                        n = n + 1
                        local lc, rc = code(ln.leftText), code(ln.rightText)
                        ls[#ls + 1] = lc .. rc
                        local ty = clear(ln.type)
                        types[#types + 1] = (type(ty) == "number") and tostring(ty) or code(ln.type)
                        if data then
                            data.tooltip = data.tooltip or {}
                            -- structured fields: type + every clear scalar id/args field (never secret text)
                            local row = { l = (lc == "C") and ln.leftText or nil, r = (rc == "C") and ln.rightText or nil, type = ty }
                            for k2, v2 in pairs(ln) do
                                if k2 ~= "leftText" and k2 ~= "rightText" and k2 ~= "type" and type(k2) == "string"
                                    and (type(v2) == "number" or type(v2) == "boolean") and code(v2) == "C" then
                                    row.f = row.f or {}
                                    row.f[k2] = v2
                                end
                            end
                            data.tooltip[i] = row
                        end
                    end
                end
                codes.tooltipLines = table.concat(ls, ",")
                codes.tooltipN = n
                codes.tooltipTypes = table.concat(types, ",")
            end
        end
    end
    if data then
        local parsed = K.Parse(data.description)
        if not parsed and data.tooltip then
            for _, ln in pairs(data.tooltip) do parsed = parsed or K.Parse(ln.l) end
        end
        data.parsed = parsed
        data.header = K.ParseHeader(data.tooltip)   -- cross-check vs GetSpellBaseCooldown / GetSpellInfo / GetSpellPowerCost
    end
    return codes, data
end

-- HybridState knowledge from the stored data
function K.ToHSM(entry)
    local d = entry and entry.data
    if not d then return nil end
    local p = d.parsed or {}
    local k = {}
    if p.auraDuration then k.aura = { duration = p.auraDuration, helpful = (d.IsSpellHelpful == true) or nil, consumable = p.consumable } end
    if type(d.baseGCD) == "number" then k.gcd = d.baseGCD / 1000 end   -- MINOR 5 CooldownTracker: per-spell GCD
    if d.IsSpellHelpful == true then k.helpful = true elseif d.IsSpellHarmful == true then k.harmful = true end
    if p.summon then k.summon = { duration = p.summonDuration, name = p.summonName } end
    if p.dispel then k.dispel = true end
    if p.interrupt then k.interrupt = true k.lockout = p.lockout end
    if entry.auraMap then   -- v2.2.4: spell -> applied aura spellID learned by correlation (live + combat log)
        local best, bn = nil, 0
        for aid, m in pairs(entry.auraMap) do local c = type(m) == "table" and m.n or m if c > bn then best, bn = tonumber(aid) or aid, c end end
        if best then k.auraId = best end
    end
    if entry.learned and (entry.learned.auraDuration or entry.learned.untilCancelled) then
        k.aura = k.aura or {}
        k.aura.duration = entry.learned.auraDuration or (not entry.learned.untilCancelled and k.aura.duration) or nil
        if entry.learned.helpful ~= nil then k.aura.helpful = entry.learned.helpful end
        if entry.learned.self then k.aura.self = true end
    end
    if type(d.baseCooldown) == "number" and d.baseCooldown > 0 then k.cooldown = d.baseCooldown / 1000 end
    if type(d["info.castTime"]) == "number" then k.castTime = d["info.castTime"] / 1000 end
    if p.amountMin then k.amount = { min = p.amountMin, max = p.amountMax, kind = p.amountKind } end
    return next(k) and k or nil
end

local queue, running
local function tick()
    local db = K.DB()
    if not db or not queue then running = false return end
    local per = tonumber(cfg().spellsPerTick) or 8
    for _ = 1, per do
        local job = table.remove(queue, 1)
        if not job then break end
        local e = db.spells[job.id] or { ctx = {} }
        db.spells[job.id] = e
        local okC, codes, data = pcall(K.Collect, job.id, job.ctx == "ooc")
        if okC then
            e.ctx[job.ctx] = codes
            if data then e.data = data end
            if K.onCollected then pcall(K.onCollected, job.id) end   -- v2.2.3: live HSM learns as knowledge arrives
        else e.err = tostring(codes):sub(1, 160) ns.NoteSelfError("Knowledge.Collect", codes) end
    end
    if #queue > 0 and not (ns.SelfThrottled and ns.SelfThrottled()) then C_Timer.After(0.05, tick)
    else
        running, queue = false, nil
        db.lastRun = ns.Stamp({ ctx = db.lastCtx })
        if K.onDone then pcall(K.onDone, db) end
    end
end

-- queue a pass over the spell list for the current context (chunked)
function K.Run(reason)
    if running or not ns.db then return false end
    if cfg().enabled == false then return false end
    local db = K.DB()
    local ctx = ctxName()
    db.player = playerInfo()
    db.runs = db.runs or {}
    db.runs[#db.runs + 1] = ns.Stamp({ reason = reason, ctx = ctx })
    while #db.runs > 20 do table.remove(db.runs, 1) end
    db.lastCtx = ctx
    queue = {}
    for _, id in ipairs(K.SpellList()) do queue[#queue + 1] = { id = id, ctx = ctx } end
    db.listed = #queue
    running = true
    if type(g("C_Timer")) == "table" then C_Timer.After(0, tick) else tick() end
    return true
end
function K.Running() return running == true end
function K.RunSync(reason) -- tests / slash: whole pass now
    if not K.Run(reason) then return false end
    while running and queue and #queue > 0 do
        local per = cfg().spellsPerTick
        ns.config.knowledge.spellsPerTick = 10000
        tick()
        ns.config.knowledge.spellsPerTick = per
    end
    return true
end

-- learned facts from the live HSM (readable aura applications after own casts)
function K.Learn(spellID, facts)
    local db = K.DB()
    if not db or type(spellID) ~= "number" then return end
    local e = db.spells[spellID] or { ctx = {} }
    db.spells[spellID] = e
    e.learned = e.learned or {}
    for k, v in pairs(facts) do e.learned[k] = v end
end

----------------------------------------------------------------------------
-- v2.2.4 additions
----------------------------------------------------------------------------
-- spell -> applied aura mapping (no API): my successful cast X then, within 0.3 s, a new aura from me with clear spellId Y
-- on the cast target or on me. Counted per (X, Y); the converter merges the combat log's SPELL_CAST_SUCCESS ->
-- SPELL_AURA_APPLIED pairs (same source/dest, 0.3 s) into the same table.
function K.LearnAuraMap(castID, auraID, src)
    local db = K.DB()
    if not db or type(castID) ~= "number" or type(auraID) ~= "number" then return end
    local e = db.spells[castID] or { ctx = {} }
    db.spells[castID] = e
    e.auraMap = e.auraMap or {}
    local m = e.auraMap[auraID]
    if not m then
        local n = 0
        for _ in pairs(e.auraMap) do n = n + 1 end
        if n >= 4 then return end   -- bounded: 4 aura ids per spell
        m = { n = 0 }
        e.auraMap[auraID] = m
    end
    m.n = m.n + 1
    m.src = src or m.src
    if K.onNewMapping and m.n == 1 then pcall(K.onNewMapping, castID, auraID) end
end

-- foreign spell IDs (enemy / other players) seen clear by the ledger: queued (LRU, maxExtra) and collected out of
-- combat only, chunked like the spellbook pass
local extra, extraN, extraSeq = {}, 0, 0
function K.Enqueue(id)
    if type(id) ~= "number" or cfg().foreign == false then return end
    local db = K.DB()
    if not db then return end
    local e = db.spells[id]
    if e and e.data then return end
    extraSeq = extraSeq + 1
    if not extra[id] then
        extraN = extraN + 1
        if ns.Verify then ns.Verify.Unexpected("new-foreign-spell", id) end
    end
    extra[id] = extraSeq
    local cap = tonumber(cfg().maxExtra) or 60
    if extraN > cap + 8 then
        local cut = extraSeq - cap
        for k, v in pairs(extra) do if v <= cut then extra[k] = nil extraN = extraN - 1 end end
    end
end
function K.ExtraCount() return extraN end

local function foreignPass()
    if ns.InCombat() or running or extraN == 0 then return false end
    local db = K.DB()
    if not db then return false end
    queue = {}
    for id in pairs(extra) do queue[#queue + 1] = { id = id, ctx = "ooc", foreign = true } end
    extra, extraN = {}, 0
    running = true
    db.foreign = (db.foreign or 0) + #queue
    if type(g("C_Timer")) == "table" then C_Timer.After(0, tick) else tick() end
    return true
end
K.ForeignPass = foreignPass
ns.On("PLAYER_REGEN_ENABLED", function()
    if type(g("C_Timer")) == "table" and extraN > 0 then C_Timer.After(3, function() pcall(foreignPass) end) end
end)

-- HYPOTHESIS (disabled in the HSM until proven): a cooldown adds one tooltip line in combat (run 5: Earth Shock
-- 'CC,CC,CC,CN' out of combat vs 'CC,CC,CC,SN,CN' in combat; the extra line's text is secret). Known-answer probe in
-- every capture: after my cast of a spell with a base cooldown > 1.5 s, sample the tooltip LINE COUNT + LINE TYPES
-- (never text, never the line's position meaning) at +0.4 s (known on cooldown) and at cooldown + 0.6 s (known ready
-- unless another cooldown spell of mine was cast in between: marked 'mixed'). One probe per spell per 15 s.
local probeLast = {}
local function sampleLines(id)
    local r = call("C_TooltipInfo.GetSpellByID", id)
    if type(r) ~= "table" or not r[1] or type(r[2]) ~= "table" then return nil end
    local lines = r[2].lines
    if type(lines) ~= "table" or code(lines) == "S" then return nil end
    local n, types = 0, {}
    for i = 1, math.min(#lines, 20) do
        local ln = lines[i]
        if type(ln) == "table" then
            n = n + 1
            local ty = clear(ln.type)
            types[#types + 1] = (type(ty) == "number") and tostring(ty) or code(ln.type)
        end
    end
    return n, table.concat(types, ",")
end
K.SampleLines = sampleLines
local cdCasts = 0
function K.OnOwnCast(id)
    if cfg().cdLineProbe == false or type(id) ~= "number" then return end
    local db = K.DB()
    local e = db and db.spells[id]
    local cd = e and e.data and type(e.data.baseCooldown) == "number" and e.data.baseCooldown / 1000 or nil
    if not cd or cd <= 1.5 then return end
    cdCasts = cdCasts + 1
    local now = (g("GetTime") or os.clock)()
    if probeLast[id] and now - probeLast[id] < 15 then return end
    probeLast[id] = now
    if type(g("C_Timer")) ~= "table" then return end
    local mark = cdCasts
    local function rec(phase)
        local n, types = sampleLines(id)
        if not n then return end
        local d = K.DB()
        d.cdLineProbe = d.cdLineProbe or {}
        local sp = d.cdLineProbe[id] or {}
        d.cdLineProbe[id] = sp
        if phase == "ready" and cdCasts ~= mark then phase = "mixed" end
        local key = phase .. "|" .. ctxName() .. "|" .. n .. "|" .. types
        sp[key] = (sp[key] or 0) + 1
    end
    C_Timer.After(0.4, function() pcall(rec, "oncd") end)
    C_Timer.After(cd + 0.6, function() pcall(rec, "ready") end)
end

-- spells that apply auras (parsed or learned), split by helpful/harmful: input of the "single applier" rule
function K.Appliers()
    local db = K.DB()
    local out = { helpful = {}, harmful = {}, unknown = {} }
    for id, e in pairs((db and db.spells) or {}) do
        local k = K.ToHSM(e)
        if k and k.aura then
            local h = k.aura.helpful
            if h == nil and e.data then h = (e.data.IsSpellHarmful == true) and false or nil end
            local list = (h == true and out.helpful) or (h == false and out.harmful) or out.unknown
            list[#list + 1] = id
        end
    end
    for _, l in pairs(out) do table.sort(l) end
    return out
end
