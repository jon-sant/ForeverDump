-- v2.2 tests: HybridState library (pure), combat probe set + detectability, unit token survey, spell knowledge,
-- live HSM inference + window (creation, update loop, Escape, position save, FD_Logs auto open/close), baseline
-- signature + drift alert, and "no secret ever stored". usage: lua5.1 tests/hsm.lua ForeverDump
package.path = "./tests/?.lua;" .. package.path
local addonDir = arg[1] or "ForeverDump"
local failures, passed = 0, 0
local function check(cond, msg)
    if cond then passed = passed + 1 print("  ok   " .. msg) else failures = failures + 1 print("  FAIL " .. msg) end
end

------------------------------------------------------------------ 1) pure library
_G.HybridState = nil
local t = 100
local Lib = dofile(addonDir .. "/Lib/HybridState.lua")
check(type(Lib) == "table" and Lib.MAJOR == "HybridState-1.0", "library loads standalone (no ForeverDump dependency)")
local preds, infs = {}, {}
local hs = Lib.New({ now = function() return t end, onPredict = function(p) preds[#preds + 1] = p end, onInfer = function(i) infs[#infs + 1] = i end })
hs:Learn(1001, { aura = { duration = 30, helpful = true }, cooldown = 8, amount = { min = 10, max = 12, kind = "heal" } })
hs:OnCast("UNIT_SPELLCAST_START", "player", 1001, true, "T1")
check(hs:CastState("player").active == true, "cast-pair: START opens a cast")
t = 101.5
hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 1001, true, "T1")
check(hs:CastState("player").active == false and infs[#infs].kind == "cast-end" and infs[#infs].outcome == "succeeded", "cast-pair: SUCCEEDED closes it")
local p = preds[1]
check(p and p.aura and p.aura.duration == 30 and p.aura.expires == 131.5 and p.cooldownEnds == 109.5 and p.amount.max == 12,
    "prediction: aura + duration, cooldown end, amount range")
check(hs:Cooldown(1001) ~= nil and hs:Cooldown(1001).state == "cooling", "predicted cooldown tracked (CooldownTracker state cooling)")
t = 101.8
hs:OnAura("T1", { added = { { iid = 77, helpful = true } }, addedCount = 1 })   -- spellId secret, instance id readable
local a = hs:UnitState("T1").auras.i77
check(a and a.spell == 1001 and a.rule == "single-applier" and a.conf == "high" and a.source == "inferred",
    "single-applier: secret spellId + readable iid after my only applier -> inferred, high confidence")
check(p.outcome and p.outcome:find("single%-applier"), "prediction verified live (aura seen)")
t = 110
hs:OnAura("T1", { removed = { 77 }, removedCount = 1 })
check(infs[#infs].rule == "iid-map" and infs[#infs].kind == "removed" and infs[#infs].spell == 1001, "iid-map: removal resolves the spell")
check(hs.counters.contradictions == 1 and hs.contradictions[1].kind == "aura-gone-early" and p.outcome == "contradicted",
    "aura gone 21.5s early -> live contradiction, prediction marked contradicted")
hs:Learn(1002, { aura = { duration = 10, helpful = true } })
t = 120
hs:OnCount("T2", "HELPFUL|PLAYER", 0)
hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 1002, true, "T2")
t = 120.3
hs:OnCount("T2", "HELPFUL|PLAYER", 1)
check(infs[#infs].rule == "count-delta" and infs[#infs].spell == 1002 and infs[#infs].conf == "medium",
    "count-delta: +1 readable HELPFUL|PLAYER after my cast (two appliers known -> medium)")
hs:OnAura("T3", { added = { { iid = 5, spellId = 1001, fromPlayer = true, duration = 30 } } })
check(hs:UnitState("T3").auras.i5.source == "observed", "observed aura (readable spellId) -> source observed")
t = 160
hs:Tick()
check(hs:UnitState("T2") == nil or hs:UnitState("T2").auras.c1002 == nil, "predicted expiry removes inferred auras (v2.2.3: empty unit state dropped)")
hs:OnCast("UNIT_SPELLCAST_START", "boss", nil, false)
check(hs.counters.unreadable >= 1 and hs:CastState("boss").active and hs:CastState("boss").spell == nil,
    "secret spellID: cast state still inferred from event timing")
local ex = hs:Export()
check(ex.counters.predictions == 2 and #ex.predictions == 2, "Export: SV-safe predictions/inferences/counters")

------------------------------------------------------------------ 1b) v2.2.4 attribution (HybridState MINOR 3, run 5)
do
    _G.HybridState = nil
    local L3 = dofile(addonDir .. "/Lib/HybridState.lua")
    check(L3.MINOR >= 3, "HybridState MINOR 3 (attribution API)")
    local tt = 0
    local h = L3.New({ now = function() return tt end })
    h:Learn(8056, { aura = { duration = 8 } })
    h:OnCombatState(true)
    tt = 1.000 h:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8056, true, "MOB")
    local r1 = h:OnUnitCombat("MOB", "WOUND", "CRITICAL", 105, 16, false)
    check(r1.src == "mine" and r1.rule == "cast-frame", "UNIT_COMBAT in my cast's frame -> mine (cast-frame)")
    tt = 2.000 h:OnDamageMeter(0)
    local r2 = h:OnUnitCombat("MOB", "WOUND", "", 8, 4, false)
    check(r2.src == "mine" and r2.rule == "dm-frame", "UNIT_COMBAT in a DAMAGE_METER DamageDone frame -> mine (dm-frame: DoT tick)")
    tt = 3.000 h:OnSwing()
    tt = 3.458
    local r3 = h:OnUnitCombat("MOB", "WOUND", "", 119, 1, false)
    check(r3.src == "mine" and r3.rule == "swing-lag", "physical UNIT_COMBAT 0.46 s after PLAYER_SWING -> mine (swing-lag)")
    tt = 3.75
    local r4 = h:OnUnitCombat("MOB", "WOUND", "", 177, 16, false)
    check(r4.src == "other" and r4.rule == "elimination", "frost hit with no cast/DM/swing of mine -> other (the run-5 mage's Frostbolt)")
    local f = h:Fight()
    check(f.dmg.mine == 232 and f.dmg.other == 177 and f.otherSchools["16"] == 177 and f.dmg.crit == 1, "fight totals: mine/other/school/crit")
    tt = 4.0 h:OnUnitCombat("player", "HEAL", "", 6, 8, true)
    check(f.heal.other == 6, "heal with no evidence of mine -> other")
    tt = 5.0 h:OnDamageMeter(2) h:OnUnitCombat("player", "HEAL", "", 6, 8, true)
    tt = 7.02 h:OnUnitCombat("player", "HEAL", "", 6, 8, true)
    check(f.heal.mine == 12 and f.heal.rules["heal-cadence"] == 1, "periodic heal: DM HealingDone seeds it, the 2 s cadence carries it (overheals)")
    tt = 8.0 h:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8046, true, "MOB")
    local ri = h:OnInterrupt("MOB")
    check(ri.src == "mine" and ri.rule:find("interrupt"), "target INTERRUPTED in my cast's frame -> my interrupt")
    tt = 9.5
    check(h:OnInterrupt("MOB").src == "other", "INTERRUPTED with no cast of mine -> other/unknown")
    -- secret aura events: 2.4 s legacy window vs 0.3 s
    tt = 10.0 h:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8056, true, "MOB")
    tt = 11.5 h:OnAura("MOB", { addedSecret = true })
    check(h.inferences[#h.inferences].rule == "elimination" and h.inferences[#h.inferences].src == "other",
        "secret added-aura 1.5 s after my cast -> not mine by elimination (0.35 s timing window)")
    local lg = L3.New({ now = function() return tt end, legacy = true })
    lg:Learn(8056, { aura = { duration = 8 } })
    tt = 20.0 lg:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8056, true, "MOB")
    tt = 21.5 lg:OnAura("MOB", { addedSecret = true })
    check(lg.inferences[#lg.inferences].rule == "secret-timing", "legacy (v2.2.3) 2.4 s window claims the same aura as mine (what v2.2.4 fixes)")
    check(lg:OnUnitCombat("MOB", "WOUND", "", 5, 1, false) == nil and lg:OnInterrupt("MOB") == nil, "legacy: no UNIT_COMBAT / interrupt attribution")
    tt = 30 h:OnCombatState(false)
    h:ReconcileDM({ damage = 200, interrupts = 1, healing = 12 })
    local rc = h.inferences[#h.inferences]
    check(rc.rule == "dm-reconcile" and rc.dmMine == 200 and rc.liveMine == 232 and rc.othersOnTarget == 209,
        "ReconcileDM: DM mine vs live mine; others on target = live total - DM mine")
    check(h.contradictions[#h.contradictions].kind == "self-attribution-exceeds-dm", "live mine > DM mine -> contradiction (false self-attribution)")
    check(h:ReconcileDM({ damage = 1 }) == nil, "ReconcileDM: first post-combat read wins")
    tt = 31 h:OnUnitCombat("player", "HEAL", "", 6, 8, true)
    check(h.fights[#h.fights].soft == true and #h.fights == 2, "after-combat heal tick opens a soft fight record")
    tt = 40 h:OnCombatState(true)
    check(not h:Fight().soft and h.fights[2].stop == 40, "REGEN_DISABLED closes the soft record and opens a real fight")
    local ex3 = h:Export()
    check(type(ex3.fights) == "table" and #ex3.fights == 3, "Export carries the fight records")
end

------------------------------------------------------------------ 2) addon in the mock client
_G.HybridState = nil
local W = require("wowenv")
local function tocFiles(dir)
    local files = {}
    for line in io.lines(dir .. "/ForeverDump.toc") do
        if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
    end
    return files
end
local S = W.state
local SECRET = W.SECRET
-- richer unit/aura/cast mocks for this test
UnitExists = function(u) return u == "player" or u == "target" or u == "nameplate1" or u == "party1" end
UnitCanAttack = function(_, u) return u == "target" or u == "nameplate1" end
UnitIsUnit = function(u1, u2) return u1 == u2 or (S.combat and SECRET or false) end
UnitIsPlayer = function(u) return u == "player" or u == "party1" end
UnitHealthMax = function() return 1345 end
UnitHealth = function() return SECRET end         -- live 2026-10-07: always secret, even out of combat
UnitGUID = function(u) if u == "player" then return "Player-1234-0ABCDEF0" end if u == "target" then return S.combat and SECRET or "Creature-0-1-2-3-3100-0000AAAA" end return SECRET end
local casting = false
UnitCastingInfo = function(u)
    if u == "target" and casting then return SECRET, SECRET, SECRET, SECRET, SECRET, false, SECRET, false, S.combat and SECRET or 133 end
end
UnitCastingDuration = function(u) if u == "target" and casting then return { HasSecretValues = function() return true end, GetRemainingDuration = function() return SECRET end } end end
local auraIID = 900
C_UnitAuras.GetAuraDataByIndex = function(unit, i, filter)
    if i ~= 1 then return nil end
    if unit == "player" and filter:find("HELPFUL") then
        return { name = "Blessing", spellId = 19740, duration = S.combat and SECRET or 300, applications = 0, auraInstanceID = 11,
            isFromPlayerOrPlayerPet = true, dispelName = nil, sourceUnit = "player", icon = 135906, expirationTime = S.combat and SECRET or 400 }
    end
    if unit == "target" and filter:find("HARMFUL") then
        return { name = SECRET, spellId = SECRET, duration = SECRET, applications = SECRET, auraInstanceID = auraIID,
            isFromPlayerOrPlayerPet = SECRET, dispelName = SECRET, sourceUnit = SECRET, icon = SECRET, expirationTime = SECRET }
    end
end
C_UnitAuras.GetAuraSlots = function(unit, filter)
    if S.combat then return nil, SECRET end
    if unit == "player" and filter:find("HELPFUL") then return nil, 1 end
    if unit == "target" and filter:find("HARMFUL") then return nil, SECRET end   -- enemy aura slots: secret
    return nil
end
C_UnitAuras.GetAuraDuration = function() return { HasSecretValues = function() return S.combat end, GetRemainingDuration = function() return S.combat and SECRET or 10 end } end
C_Secrets.ShouldUnitIdentityBeSecret = function(u) return S.combat and u ~= "player" end
C_Secrets.CanCompareUnitTokens = function() return not S.combat end
C_Spell.GetSpellInfo = function(id) return { name = "Spell" .. id, iconID = 1, castTime = 1500, minRange = 0, maxRange = 30, spellID = id } end
C_Spell.GetSpellDescription = function(id)
    if S.combat then return SECRET end
    if id == 19740 then return "Places a Blessing on the friendly target, increasing attack power by 20 for 5 min." end
    if id == 133 then return "Hurls a fiery ball that causes 14 to 23 Fire damage and an additional 2 Fire damage over 4 sec." end
    return "Does something."
end
GetSpellBaseCooldown = function(id) return id == 133 and 0 or 8000, 1500 end
C_TooltipInfo.GetSpellByID = function(id) return { lines = { { leftText = "Spell" .. id, rightText = S.combat and SECRET or "30 yd range" } } } end

local ns = W.loadAddon(addonDir, tocFiles(addonDir), "ForeverDump")
W.fire("ADDON_LOADED", "ForeverDump")
W.fire("PLAYER_LOGIN")
W.fire("PLAYER_ENTERING_WORLD", true, false)
ns.config.logs.fullDump = false
ns.config.logs.autoReload = false
ns.config.probe.spells = { 19740, 133 }
check(type(rawget(_G, "HybridState")) == "table", "Lib/HybridState.lua loaded via the TOC (backslash path)")
W.slash("logs on")
for _ = 1, 30 do W.tick(1) end
local log = ForeverDumpLogDB
check(ns.HSMUI.IsShown(), "FD_Logs ON auto-opens the HSM window (hsm.autoShow default true)")
local idm = ForeverDumpDB.meta and ForeverDumpDB.meta.identity
check(idm and idm.guid == "Player-1234-0ABCDEF0" and idm.name == "Mockchar" and idm.codes.guid == "C" and idm.anySecret == false
    and ForeverDumpLogDB.identity == idm and ForeverDumpDB.identities["Player-1234-0ABCDEF0"] == idm,
    "player identity written to the SV meta at capture start (GUID, name, codes, no secrets)")
check(idm.realm == "Mockrealm" and idm.codes.fullName ~= nil and idm.codes.unitNameWithRealm ~= nil and idm.codes.level ~= nil,
    "identity covers realm, UnitFullName, GetUnitName(player,true), level")
do
    local oldName, oldFull = UnitName, rawget(_G, "UnitFullName")
    UnitName = function(u) if u == "player" then return SECRET, nil end return SECRET end
    UnitFullName = function() return "Mock", "Realm" end
    local sid = ns.RecordIdentity("test:secret-name")
    check(sid.secret.name and sid.codes.name == "S" and sid.name == nil and sid.anySecret == true and sid.fullName == "Mock",
        "a secret identity value is flagged (secret.name, anySecret) and never stored")
    UnitName, UnitFullName = oldName, oldFull
    ns.RecordIdentity("test:restore")
end
local cp = log.combatProbe
check(cp and cp.cells.ooc and cp.cells.ooc.player and cp.cells.ooc.player.UnitHealth, "combat probe ran out of combat at ON")
check(cp.cells.ooc.player.UnitHealth.r[1].S == 1 and cp.cells.ooc.player.UnitHealthMax.r[1].C == 1, "UnitHealth(player) secret, UnitHealthMax clear (live fixture)")
check(cp.cells.ooc["target:hostile-npc"] ~= nil and cp.cells.ooc["party:friendly-player"] ~= nil and cp.cells.ooc["nameplate:hostile-npc"] ~= nil,
    "unit classes from readable facts (target:hostile-npc, party:friendly-player, nameplate:hostile-npc)")
local tf = cp.cells.ooc["target:hostile-npc"]["aura:GetAuraDataByIndex[HARMFUL]"]
check(tf and tf.f and tf.f.spellId and tf.f.spellId.S == 1 and tf.f.auraInstanceID.C == 1, "aura struct fields classified per field (spellId S, auraInstanceID C)")
check(cp.det.ooc.player.whatAura.yes == 1 and cp.det.ooc["target:hostile-npc"].whatAura.no == 1, "detectability: what aura? yes on player, no on target")
check(cp.det.ooc.player.anyAura.yes == 1 and cp.det.ooc["target:hostile-npc"].anyAura.partial == 1, "detectability: any aura? yes via slot count / partial via nil-check")
check(cp.absent ~= nil, "absent APIs recorded")
local tk = log.tokens
check(tk and tk.ctx.ooc and tk.ctx.ooc.families.party.exist == 1 and tk.ctx.ooc.families.raid.notExist == 40 and tk.ctx.ooc.families.raid.checks.UnitExists.none.C == 1,
    "token survey: per family, existing vs non-existent (non-existent sampled once)")
check(tk.ctx.ooc.families.nameplate.exist == 1 and tk.ctx.ooc.families.boss.tokens == 8 and tk.ctx.ooc.families.targettargettarget ~= nil,
    "token survey covers numbered families and compound chains")
local kdb = ns.Knowledge.DB()
check(kdb.spells[19740] and kdb.spells[19740].data and kdb.spells[19740].data.parsed.auraDuration == 300, "knowledge: '5 min' parsed from the clear description")
check(kdb.spells[133].data.parsed.amountMin == 14 and kdb.spells[133].data.parsed.amountMax == 23, "knowledge: damage range parsed")
check(kdb.spells[133].ctx.ooc.tooltipLines == "CC", "knowledge: tooltip line secrecy recorded")
-- combat
S.combat = true
W.fire("PLAYER_REGEN_DISABLED")
W.fire("ADDON_RESTRICTION_STATE_CHANGED", 0, 1)
for _ = 1, 30 do W.tick(1) end
S.time = S.time + 5
W.fire("PLAYER_TARGET_CHANGED")
for _ = 1, 10 do W.tick(1) end
check(cp.cells.combat and cp.cells.combat.player and cp.cells.combat.player.UnitHealth, "combat probe ran in combat")
-- v2.2.4: in combat the budgeted discovery scanner replaces the one-shot survey (heavy work out of combat); the mock has
-- no C_Timer.NewTicker, so drive its slices directly
for _ = 1, 40 do ns.Tokens.Scan.Slice() end
local tsm, tsHit = ForeverDumpDB.tokenscan and ForeverDumpDB.tokenscan[ns.Build()], false
for key, fams in pairs((tsm and tsm.m) or {}) do
    if key:match("^combat|") and fams.target and fams.target.guid and (fams.target.guid.S or 0) >= 1 then tsHit = true end
end
check(tk.ctx.combat == nil and tsHit, "token scanner in combat: target GUID secret (one-shot survey skipped in combat)")
check(kdb.spells[19740].ctx.combat and kdb.spells[19740].ctx.combat.description == "S", "knowledge re-checked in combat: description secret")
-- HSM: my cast + aura with secret spellId but readable iid on target
local okHS = ns.Inference.hs ~= nil
check(okHS, "live HSM instance running")
ns.Inference.hs:Learn(19740, { aura = { duration = 300, helpful = false } })   -- treat as my only harmful applier in this mock
ns.Inference.hs.knowledge[133] = nil
W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 19740)
W.fire("UNIT_AURA", "target", { addedAuras = { { auraInstanceID = 901, spellId = SECRET, isHelpful = false, isFromPlayerOrPlayerPet = SECRET, duration = SECRET } } })
local hsInf = ns.Inference.hs.inferences
local last = hsInf[#hsInf]
check(last and last.kind == "applied" and last.spell == 19740 and last.rule == "single-applier", "live: single-applier inference from my cast + readable iid")
casting = true
W.fire("UNIT_SPELLCAST_START", "target", SECRET, SECRET)
check(ns.Inference.hs:CastState("target") and ns.Inference.hs:CastState("target").active, "target cast state from event timing (secret spellID)")
-- v2.2.11 (run 9 taint.log): a secret endTimeMS is classified and skipped, never subtracted (derivedOk nil, "skipped")
local tlc = cp.timeLeft["combat|target:hostile-npc"]
check(tlc and tlc.derivedOk == nil and tlc.endTimeState == "S" and tostring(tlc.derivedErr):find("skipped", 1, true) and tlc.derivedState == nil,
    "cast time left: secret endTimeMS skipped (no arithmetic on a secret)")
check(cp.det.combat["target:hostile-npc"].whichSpell.no == 1, "detectability: which spell? no (spellID secret in combat)")
-- v2.2.4: UNIT_COMBAT attribution + C_DamageMeter evidence (live, mock)
S.time = S.time + 1.5
-- v2.2.16: the mock's party member shares my class -> the live census sees it (ambiguity guard); this block checks the
-- solo attribution path, so the census is reset to "no same-class actor" here (attr_v2216.lua covers the guarded path)
check((ns.Inference.hs.census.sameClass or 0) >= 1, "live census: same-class group member counted from clear UnitClass")
ns.Inference.hs:SetCensus({ sameClass = 0, sameClassEnemy = 0 })
W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 19740)
W.fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 0, 3)
W.fire("UNIT_COMBAT", "target", "WOUND", "CRITICAL", 105, 16)
W.fire("UNIT_COMBAT", "nameplate1", "WOUND", "CRITICAL", 105, 16)   -- same hit on another token: ignored
S.time = S.time + 0.8
W.fire("UNIT_COMBAT", "target", "WOUND", "", 177, 16)
local fz = ns.Inference.hs:Fight()
check(fz and fz.dmg.mine == 105 and fz.dmg.other == 177 and fz.dmg.mineN == 1, "live: UNIT_COMBAT attribution mine (cast frame) vs other (no evidence); one count per hit")
W.tick(2)
local dmdb = log.damageMeter
check(dmdb and dmdb.events and dmdb.events["0"] == 1 and dmdb.schema and dmdb.schema.combat and dmdb.schema.combat.GetCombatSessionFromType
    and dmdb.schema.combat.GetCombatSessionFromType.S == 1, "DamageMeter: event counted, one deferred in-combat classification (getter secret)")
W.fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 0, 3)
W.tick(2)
check(dmdb.schema.combat.GetCombatSessionFromType.S == 1, "DamageMeter: classification runs once per combat (not per event)")
check(ns.HSMUI.frame.attrRow.value:GetText() ~= nil, "HSM window row 9 shows the live attribution")
-- window update loop
local before = ns.HSMUI.updates or 0
for _ = 1, 40 do W.tick(1) end
check((ns.HSMUI.updates or 0) > before, "window update loop runs (throttled OnUpdate)")
check((ns.HSMUI.updates or 0) - before <= 4, "window updates throttled to ~0.2s (" .. ((ns.HSMUI.updates or 0) - before) .. " in 0.64s)")
local txt = ns.HSMUI.Text()
check(txt:find("Restrictions") and txt:find("Combat=Activating") and txt:find("single%-applier"), "window text: restrictions + inferred aura with rule")
check(txt:find("ffd100"), "inferred aura shown yellow")
local found = false
for _, n in ipairs(UISpecialFrames or {}) do if n == "ForeverDumpHSMFrame" then found = true end end
check(found, "Escape closes it (UISpecialFrames)")
local f = ns.HSMUI.frame
f.GetPoint = function() return "TOPLEFT", UIParent, "TOPLEFT", 50, -60 end
f.__scripts.OnDragStop(f)
check(ns.db.hsmUI.point == "TOPLEFT" and ns.db.hsmUI.x == 50, "position saved in the SV on drag stop")
check(not f:IsProtected(), "window is not a protected frame")
-- secrets panel button
ns.Secrets.TogglePanel(true)
ForeverDumpSecretsPanel.hsmButton.__scripts.OnClick()
check(not ns.HSMUI.IsShown(), "HSM button on the secrets panel toggles the window")
ns.HSMUI.Show()
-- stop
S.combat = false
W.fire("PLAYER_REGEN_ENABLED")
for _ = 1, 3 do W.tick(1) end
local dmf = log.damageMeter.fights and log.damageMeter.fights[#log.damageMeter.fights]
check(dmf and dmf.types.DamageDone.me == 1234 and dmf.types.DamageDone.others == 100 and dmf.spells[8056].amount == 500
    and dmf.spells[8056].overkill == 7, "DamageMeter: post-combat clear read (me vs others, my spell breakdown with overkill)")
check(dmf.types.DamageDone.kinds.Player == 2 and dmf.types.DamageDone.name == nil, "DamageMeter: source kinds only, no names/GUIDs stored")
check(log.damageMeter.schema["after-combat"]["CombatSource.totalAmount"].C >= 1 and log.damageMeter.schema["after-combat"]["CombatSpell.overkillAmount"].C >= 1,
    "DamageMeter: after-combat field classification (clear)")
local rcI
for i = #ns.Inference.hs.inferences, 1, -1 do local x = ns.Inference.hs.inferences[i] if x.rule == "dm-reconcile" then rcI = x break end end
check(rcI and rcI.dmMine == 1234 and rcI.liveMine == 105, "HSM: ReconcileDM at PLAYER_REGEN_ENABLED with the meter's clear totals")
W.slash("logs off")
for _ = 1, 5 do W.tick(1) end
check(not ns.HSMUI.IsShown(), "FD_Logs OFF closes the HSM window")
check(log.inference and log.inference.predictions and #log.inference.predictions >= 1 and log.inference.anchor, "inference persisted (predictions + time anchor)")
check(log.inference.inputs and log.inference.inputs.combat and log.inference.inputs.combat["aura.spellId"].u >= 1, "rule-input readability per context")
check(log.baseline and log.baseline.v == 1 and log.baseline.docs and log.baseline.combat and log.baseline.tokens, "baseline signature stored at OFF")
-- drift alert
ns.db.lastBaselineBuild = "69999"
local printed = {}
local oldPrint = ns.Print
ns.Print = function(s) printed[#printed + 1] = tostring(s) oldPrint(s) end
local _, alert = ns.Baseline.Capture("test")
ns.Print = oldPrint
check(alert and alert:find("69999") and printed[#printed]:find("drift"), "drift alert: one chat line when the build differs")
------------------------------------------------------------------ v2.2.2
-- container schema: stored in every capture, ooc + combat contexts, codes only
local cdb = log.containers
check(cdb and cdb.v == 1 and cdb.schema and cdb.schema.ooc and cdb.schema.ooc.player, "containers: schema stored per context / unit class")
local okC = false
for ctx in pairs(cdb and cdb.schema or {}) do if ctx:find("^combat") then okC = true end end
check(okC, "containers: a combat context was walked (non-protected reads only)")
local pp = cdb.schema.ooc.player
check(pp and pp["UnitHealth(u)"] and pp["UnitHealth(u)"].s, "containers: scalar returns classified (UnitHealth)")
check(pp and pp["count:GetAuraDataByIndex-iterate(HELPFUL)"] ~= nil, "containers: aura count-by-iteration recorded")
-- mixed table: clear container, some secret fields, nested object with HasSecretValues
local obj = { HasSecretValues = function() return true end, GetRemainingDuration = function() return SECRET end, GetTotalDuration = function() return 12 end }
local node = ns.Containers.Walk({ auraInstanceID = 7, spellId = SECRET, name = SECRET, applications = 1, dur = obj, list = { 1, SECRET } })
check(node.s == "T" and node.f.auraInstanceID.s == "C" and node.f.spellId.s == "S" and node.f.applications.s == "C", "containers: mixed table -> T, per-field C/S")
check(node.f.dur.fl and node.f.dur.fl.HasSecretValues == true and node.f.dur.f["GetRemainingDuration()"].s == "S"
    and node.f.dur.f["GetTotalDuration()"].s == "C", "containers: object getters + HasSecretValues flag")
check(node.f.list.len == 2 and node.f.list.arr and node.f.list.arr.s.C == 1 and node.f.list.arr.s.S == 1, "containers: array elements merged with clear length")
check(node.nc == 2 and node.keys and #node.keys == 6, "containers: clear count + key list")
local agg = ns.Containers.Merge(nil, node)
agg = ns.Containers.Merge(agg, ns.Containers.Walk({ auraInstanceID = SECRET }))
check(agg.obs == 2 and agg.f.auraInstanceID.s.C == 1 and agg.f.auraInstanceID.s.S == 1 and agg.f.spellId.obs == 1, "containers: merge counts states (absent = parent obs - field obs)")
-- blocked-action attribution + learned combat skip
ns.ProbeMark("CombatProbe", "CheckInteractDistance", "party1")
W.fire("ADDON_ACTION_BLOCKED", "ForeverDump", "UNKNOWN()")
ns.ProbeDone()
local lastB
for _, e in ipairs((ForeverDumpLogDB.errors and ForeverDumpLogDB.errors.entries) or ns.db.errors or {}) do if e.event == "ADDON_ACTION_BLOCKED" then lastB = e end end
if not lastB then for _, e in pairs(ForeverDumpLogDB.blocked or {}) do if type(e) == "table" and e.resolved then lastB = e end end end
check(lastB and lastB.resolved == "CombatProbe:CheckInteractDistance(party1)", "ADDON_ACTION_BLOCKED UNKNOWN() resolved to the probe path: " .. tostring(lastB and lastB.resolved))
check(ns.PathBlocked("CheckInteractDistance") and ns.CombatProbe.CombatSkip("CheckInteractDistance"), "blocked path learned -> skipped in combat")
check(ns.CombatProbe.COMBAT_SKIP.CheckInteractDistance == "nonhostile" and ns.CombatProbe.CombatSkip("CheckInteractDistance", "player") ~= nil,
    "static combat skip: CheckInteractDistance on non-hostile units")
-- knowledge parser: totems are summons, Purge dispels, "health" is not a heal
local K = ns.Knowledge
local st = K.Parse("Summons a Stoneclaw Totem with 50 health at the feet of the caster for 15 sec that taunts creatures within 8 yards.")
check(st and st.summon and st.summonName == "Stoneclaw Totem" and st.summonDuration == 15 and not st.amountMin and not st.auraDuration, "parse: totem -> summon 15s, no heal/aura")
check(K.Parse("Purges the enemy target, removing 1 beneficial magic effect.").dispel == true, "parse: Purge -> dispel")
check(K.Parse("Returns the spirit to the body, restoring a dead target to life with 120 health and 70 mana.") == nil, "parse: 'health' is not a heal")
local hk = K.ToHSM({ data = { parsed = st, IsSpellHelpful = true } })
check(hk and hk.summon and hk.summon.duration == 15 and not hk.aura and hk.helpful, "ToHSM: summon knowledge")
-- HSM: summon prediction on the player, verified by PLAYER_TOTEM_UPDATE/GetTotemInfo
local th = Lib.New({ now = function() return t end })
th:Learn(5730, hk)
th:Learn(370, { dispel = true, cooldown = 0 })
t = 500
th:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 5730, true, "Creature-1")
local sp = th.predictions[#th.predictions]
check(sp.unit == "player" and sp.summon and sp.summon.expires == 515 and not sp.aura, "HSM: totem predicted as a summon on the player (15s)")
t = 500.2
th:OnTotem(1, true, "Stoneclaw Totem", 15)
check(sp.outcome == "totem seen (GetTotemInfo)" and sp.summon.engineDuration == 15 and th.counters.contradictions == 0, "HSM: GetTotemInfo verifies the summon + lifetime")
t = 505
th:OnTotem(1, false)
check(th.inferences[#th.inferences].kind == "summon-ended-early", "HSM: totem gone 10s early -> summon-ended-early (destroyed, not a contradiction)")
th:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 370, true, "Creature-1")
check(th.predictions[#th.predictions].dispel == true, "HSM: Purge -> dispel prediction (scored offline)")
-- secret print goes to our own hidden message frame, never ChatFrame1
local m = ns.Controls.OpsMatrix("sink")
local pr
for _, r in pairs(m) do if type(r) == "table" and r.print then pr = r.print break end end
check(pr and pr.sink == "own hidden ScrollingMessageFrame", "ops matrix: print test uses our own hidden ScrollingMessageFrame")
-- (v2.2.11: the ON-wipe block below runs on a side copy; the main capture is restored afterwards so
-- tests/out/hsm_sv.lua still holds the ooc+combat capture that test_v222 reads)
local keepLog, keepRec, keepCL = ForeverDumpLogDB, ForeverDumpRecordDB, ForeverDumpCombatLogDB
-- v2.2.11 (user decision): a new FD_Logs ON wipes all previous capture data, inference history included
-- inference history: a restart inside one capture (the logout/reload resume path) keeps the previous inference
-- session; this side capture is saved to tests/out/hsm_history_sv.lua for test_v222's SV history check
W.slash("logs on") for _ = 1, 5 do W.tick(1) end
log = ForeverDumpLogDB
local sid1 = log.inference and log.inference.sid
ns.Inference.hs:Learn(19740, { aura = { duration = 300, helpful = false } })
W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-H1", 19740) W.tick(1)
check(#ns.Inference.hs.predictions >= 1, "capture made a prediction before the restart")
ns.Inference.Stop() ns.Inference.Start() for _ = 1, 2 do W.tick(1) end
check(type(log.inference.history) == "table" and #log.inference.history >= 1 and log.inference.history[#log.inference.history].predictions
    and #log.inference.history[#log.inference.history].predictions >= 1 and log.inference.history[#log.inference.history].sid == sid1,
    "inference history keeps the previous inference session inside one capture")
W.slash("logs off") for _ = 1, 5 do W.tick(1) end
check(#log.inference.history >= 1, "history survives OFF")
W.writeSavedVariables("tests/out/hsm_history_sv.lua", { "ForeverDumpLogDB" })
W.slash("logs on") for _ = 1, 2 do W.tick(1) end
log = ForeverDumpLogDB
check(log ~= keepLog and log.inference and log.inference.sid and (log.inference.history == nil or #log.inference.history == 0),
    "a new FD_Logs ON wipes the previous capture's inference history (v2.2.11)")
W.slash("logs off") for _ = 1, 5 do W.tick(1) end
log = ForeverDumpLogDB
ForeverDumpLogDB, ForeverDumpRecordDB, ForeverDumpCombatLogDB = keepLog, keepRec, keepCL
log = ForeverDumpLogDB
-- identity: Forever UnitName returns (first, last)
local oldUN, oldUFN = UnitName, UnitFullName
UnitName = function(u) if u == "player" then return "Uglaz", "Doomaxe" end end
UnitFullName = function(u) if u == "player" then return "Uglaz", "Doomaxe" end end
local id = ns.PlayerIdentity("test")
UnitName, UnitFullName = oldUN, oldUFN
check(id.firstName == "Uglaz" and id.lastName == "Doomaxe" and id.displayName == "Uglaz Doomaxe", "identity: second UnitName return = last name")

------------------------------------------------------------------ v2.2.3 (run 4: perf + live verification)
do
    -- ns.ProjectInfo walks _G once per session; hot paths use the cached ns.Build()
    local walks = 0
    local realScan = ns.ScanProjectInfo
    ns.ScanProjectInfo = function(...) walks = walks + 1 return realScan(...) end
    for _ = 1, 50 do ns.Meta() ns.Knowledge.DB() ns.PathBlocked("CheckInteractDistance") end
    ns.ScanProjectInfo = realScan
    check(walks == 0, "ns.Meta()/Knowledge.DB()/PathBlocked never re-walk _G (project info cached): " .. walks .. " walks")
    check(ns.Build() == "70245", "ns.Build() cached build string")
    -- bounded push: amortised O(1), never more than max + max/4
    local L = {}
    for i = 1, 5000 do HybridState.push(L, i, 100) end
    check(#L <= 125 and L[#L] == 5000 and L[1] >= 4876, "HybridState push: bounded (" .. #L .. " kept), newest last")
    -- knowledge arrives after Start -> fed into the live HSM (run 4: 16/16 predictions had no knowledge)
    local hs2 = HybridState.New({ now = function() return 500 end })
    ns.Inference.hs, ns.Inference.running = hs2, true
    ns.Knowledge.onCollected = function(sid) ns.Inference.LearnFromKnowledge(hs2, sid) end
    local kdb2 = ns.Knowledge.DB()
    kdb2.spells[905] = { ctx = {}, data = { ["info.name"] = "Lightning Shield", IsSpellHelpful = true,
        parsed = ns.Knowledge.Parse("The caster is surrounded by 3 balls of lightning. Lasts 10 min.") } }
    ns.Knowledge.onCollected(905)
    check(hs2.knowledge[905] and hs2.knowledge[905].aura and hs2.knowledge[905].aura.duration == 600 and hs2.knowledge[905].helpful,
        "knowledge collected after Start reaches the live HSM (Lightning Shield: 10 min aura, helpful)")
    -- secret-payload timing verification (combat: addedAuras secret vs nil is a clear yes/no)
    local tt = 500
    local hs3 = HybridState.New({ now = function() return tt end })
    hs3:Learn(8052, { aura = { duration = 12 }, harmful = true, cooldown = 6 })
    hs3:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8052, true, "Creature-1")
    tt = 500.3
    hs3:OnAura("Creature-1", { addedSecret = true })
    local p3 = hs3.predictions[#hs3.predictions]
    check(p3.outcome == "aura event seen (secret payload, timing)" and p3.timingOnly and hs3.inferences[#hs3.inferences].rule == "secret-timing",
        "combat: secret addedAuras on the predicted unit verifies the prediction by timing (Flame Shock)")
    -- observed aura verifies a prediction without aura knowledge (Ghost Wolf)
    hs3:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 1238640, true, "player")
    tt = 500.5
    hs3:OnAura("player", { added = { { iid = 89, spellId = 1238640, fromPlayer = true, helpful = true, duration = 0 } } })
    local p4 = hs3.predictions[#hs3.predictions]
    check(p4.spell == 1238640 and p4.outcome == "aura seen (observed)", "observed aura (clear spellId) verifies a prediction without aura knowledge")
    -- Appliers cached per knowledge version
    local a1 = hs3:Appliers(nil)
    check(hs3:Appliers(nil) == a1, "Appliers cached until knowledge changes")
    hs3:Learn(9999, { aura = { duration = 5 } })
    check(hs3:Appliers(nil) ~= a1, "Appliers cache invalidated by Learn")
    -- empty units dropped on Tick; unknown-duration auras expire after unknownTTL
    hs3:OnAura("Creature-2", { added = { { iid = 3 } } })
    tt = tt + 400
    hs3:Tick()
    check(hs3.units["Creature-2"] == nil, "Tick drops stale unknown auras and empty per-GUID unit state")
    -- HSM window: dirty-only redraw, no OnUpdate while idle
    ns.Inference.hs = hs3
    ns.HSMUI.Show()
    for _ = 1, 30 do W.tick(1) end
    local hf = ns.HSMUI.frame
    local upd0 = ns.HSMUI.updates or 0
    hs3.cooldowns = {}
    for _, u in pairs(hs3.units) do u.auras = {} end
    ns.HSMUI.MarkDirty()
    for _ = 1, 200 do W.tick(1) end
    check(hf:GetScript("OnUpdate") == nil, "HSM window idle: OnUpdate removed when nothing is pending")
    local upd1 = ns.HSMUI.updates or 0
    for _ = 1, 200 do W.tick(1) end
    check((ns.HSMUI.updates or 0) == upd1 and upd1 > upd0, "no redraw while idle (text rebuilt only when dirty)")
    ns.HSMUI.MarkDirty()
    check(hf:GetScript("OnUpdate") ~= nil, "MarkDirty re-installs the OnUpdate")
    -- layout: one row per item, nothing overlapping (run 4 screenshot)
    local L2, okRows = hf.layout, true
    for i = 2, #L2.rows do if L2.rows[i - 1] - L2.rows[i] < L2.row then okRows = false end end
    check(okRows and #L2.rows == 11 and L2.bodyTop <= L2.rows[11] - L2.row, "HSM layout: 11 fixed rows >= 14 px apart (row 11 GCD), text body below the last row")
    check(hf.attrRow ~= nil and hf.dmRow ~= nil, "HSM layout v2.2.4: attribution + damage-meter rows in the grid")
    check(hf.hpLabel == nil and hf.cdLabel ~= nil, "HSM layout: no free-floating HP line; real cooldown has its own row")
    ns.HSMUI.Hide()
    check(hf:GetScript("OnUpdate") == nil, "hidden window: no OnUpdate")
end

------------------------------------------------------------------ 1c) v2.2.4 MINOR 4: ledger, enemy casts, cooldown fails, health, verdicts
do
    _G.HybridState = nil
    local L4 = dofile(addonDir .. "/Lib/HybridState.lua")
    check(L4.MINOR >= 4, "HybridState MINOR 4 (ledger / enemy cast model / verification API)")
    local tt = 0
    local verdicts = {}
    local h = L4.New({ now = function() return tt end, onVerdict = function(r) verdicts[#verdicts + 1] = r end })
    -- ledger: collect while clear, resolve later with confidence + staleness
    local Ld = h.ledger
    Ld:Put("token", "target", { guid = "Creature-0-1-1-1-4119-0001" }, "test")
    local e, conf = Ld:Get("token", "target")
    check(e and e.guid and conf == "live", "ledger: same-frame read is live")
    tt = 5 e, conf = Ld:Get("token", "target")
    check(conf == "cached-fresh", "ledger: 5 s later the mapping is cached-fresh")
    tt = 20 e, conf = Ld:Get("token", "target")
    check(conf == "cached-stale", "ledger: 20 s later cached-stale")
    Ld:Put("token", "target", { guid = "x" }) Ld:Invalidate("token", "target") e, conf = Ld:Get("token", "target")
    check(conf == "cached-stale" and e.stale, "ledger: Invalidate keeps the value but marks it stale")
    local small = L4.NewLedger({ now = function() return tt end, caps = { guid = 10 } })
    for i = 1, 100 do small:Put("guid", "G" .. i, { n = i }) end
    check(small:Count("guid") <= 10 + 8 and small.data.guid.G100 and not small.data.guid.G1, "ledger: LRU cap bounds memory (amortised sweep)")
    small:PutFingerprint("SHAMAN:30:1455:P:F", "G1") check(small:Fingerprint("SHAMAN:30:1455:P:F") == "G1", "ledger: fingerprint resolves a unique match")
    -- aura identity cached while clear, resolved when the instance comes back without a spellId
    tt = 100
    h:OnAura("player", { added = { { iid = 79, spellId = 905, duration = 600, helpful = true, fromPlayer = true } }, removed = {} })
    tt = 101
    h:OnAura("player", { added = { { iid = 79 } }, removed = {} })
    local lastInf = h.inferences[#h.inferences]
    check(lastInf.rule == "ledger" and lastInf.spell == 905, "ledger: auraInstanceID -> spellId cached while clear resolves a later unreadable add")
    check(#h:CachedAuras("player") == 1 and h:CachedAuras("player")[1].spell == 905, "CachedAuras: what the HSM believes is present")
    h:OnAura("player", { added = {}, removed = {}, removedSecret = true })
    check(#h:CachedAuras("player") == 0 and h.inferences[#h.inferences].rule == "ledger-elimination",
        "secret removed-list + exactly one cached aura -> that one removed (ledger elimination, run 5 Lightning Shield)")
    -- enemy cast model (interrupt window): START -> SUCCEEDED per npc, then a prediction; interrupt dedupe + elapsed
    local mob = "Creature-0-6783-1-536-4119-0000471423"
    check(L4.NpcKey(mob) == "npc:4119", "NpcKey: npcID from a creature GUID")
    for i, d in ipairs({ 3.542, 3.437, 3.500 }) do
        tt = 200 + i * 10 h:OnEnemyCast("UNIT_SPELLCAST_START", mob, "npc:4119", "CastBar-" .. i)
        tt = tt + d h:OnEnemyCast("UNIT_SPELLCAST_SUCCEEDED", mob, "npc:4119", "CastBar-" .. i)
    end
    tt = 300 h:OnEnemyCast("UNIT_SPELLCAST_START", mob, "npc:4119", "CastBar-9")
    local ec = h:EnemyCast(mob)
    check(ec and math.abs(ec.pred - 3.5) < 0.001 and ec.n == 3, "enemy cast: median of learned durations predicts the next cast (3.50 s)")
    tt = 301.458
    h:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8046, true, mob)
    h:OnDamageMeter(5)
    h:OnEnemyCast("UNIT_SPELLCAST_INTERRUPTED", mob, "npc:4119", "CastBar-9")
    local ir = h:OnInterrupt(mob)
    check(ir and ir.src == "mine" and ir.rule == "interrupt-cast+dm" and math.abs(ir.elapsed - 1.458) < 0.001,
        "interrupt in my Earth Shock's frame + meter Interrupts event -> mine, 1.46 s into the cast")
    check(h:OnInterrupt(mob) == nil, "same unit, same frame (second token) -> deduplicated")
    -- cooldown evidence from UNIT_SPELLCAST_FAILED
    h:Learn(8046, { cooldown = 6 })
    tt = 400 h:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8046, true, mob)
    tt = 405.33 local fr = h:OnCastFailed(8046, "UNIT_SPELLCAST_FAILED")
    check(fr.rule == "fail-inside-cd" and math.abs(fr.remaining - 0.67) < 0.01, "UNIT_SPELLCAST_FAILED inside the predicted cooldown confirms it")
    tt = 406.02 h:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8046, true, mob)
    tt = 420 fr = h:OnCastFailed(8046)
    check(fr.rule ~= "fail-inside-cd", "a fail long after the cooldown is not counted as cooldown evidence")
    tt = 430 h:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8046, true, mob)
    tt = 431 h:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8046, true, mob)
    check(h.contradictions[#h.contradictions].kind == "recast-before-ready", "recast 1 s into a 6 s cooldown -> contradiction")
    -- health estimate + overheal: quiet out of combat = full, wounds subtract, gross heal above max = overheal
    h:OnCombatState(false)
    h:OnHealthMax("player", 1455)
    tt = 500 h:OnHealthEvent("player")
    tt = 505 h:OnCombatState(true)
    h:OnHealthEvent("player") h:OnUnitCombat("player", "WOUND", "", 300, 1, true)
    tt = 506 h:OnHealthEvent("player") h:OnUnitCombat("player", "WOUND", "", 98, 1, true)
    tt = 507 h:OnCombatState(false)
    local hr = h:OnUnitCombat("player", "HEAL", "CRITICAL", 572, 8, true)
    check(hr.overhealEst == 174 and hr.hpConf == "high", "overheal estimate: 1455 - 398 taken + 572 heal -> 174 over (run-5 Lesser Healing Wave)")
    -- verdicts
    local kinds = {}
    for _, v in ipairs(verdicts) do kinds[v.kind .. "|" .. v.v] = true end
    check(kinds["cast-end|V"] and kinds["interrupt-attribution|V"] and kinds["cooldown|V"] and kinds["cooldown|C"],
        "live verification: cast-end / interrupt / cooldown verdicts emitted (V and C)")
    check(h:Export().verdicts["cooldown|V"] >= 1, "Export carries verdict counters")
end

-- no secret stored anywhere
local leaks = 0
local seen = {}
local function walk(v)
    if issecretvalue(v) then leaks = leaks + 1 return end
    if type(v) == "table" and not seen[v] then seen[v] = true for k, x in pairs(v) do walk(k) walk(x) end end
end
walk(ForeverDumpLogDB) walk(ForeverDumpDB)
check(leaks == 0, "no secret value stored in ForeverDumpLogDB / ForeverDumpDB")
check(S.touchedSecret == 0, "no accidental secret touch (deliberate ones live in Controls.lua): " .. tostring(S.touchedSecret))
W.writeSavedVariables("tests/out/hsm_sv.lua", { "ForeverDumpLogDB", "ForeverDumpDB" })
------------------------------------------------------------------ 1d) v2.2.4 MINOR 5: CooldownTracker (per-spell cooldown + GCD)
do
    _G.HybridState = nil
    local L5 = dofile(addonDir .. "/Lib/HybridState.lua")
    check(L5.MINOR >= 5, "HybridState MINOR 5 (CooldownTracker)")
    local tt = 0
    local vs, learned = {}, {}
    local h = L5.New({ now = function() return tt end, onVerdict = function(r) vs[#vs + 1] = r end })
    h.onCDLearn = function(kind, sid, v) learned[#learned + 1] = { kind = kind, id = sid, v = v } end
    h:Learn(8046, { cooldown = 6, gcd = 1.5 })
    h:Learn(8052, { cooldown = 6, gcd = 1.5 })
    h:Learn(2484, { cooldown = 15, gcd = 1.0 })
    h:Learn(20572, { cooldown = 120, gcd = 0 })
    -- SPELL_UPDATE_COOLDOWN payload: shocks share category 19, GCD spells srCategory 133 (run 5)
    h:CDPayload(8046, nil, 19, 133)
    h:CDPayload(8052, nil, 19, 133)
    tt = 100
    h:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8046, true, nil)
    local c = h:Cooldown(8046)
    check(c.state == "cooling" and math.abs(c.ends - 106) < 1e-6 and c.source == "baseCooldown", "cast starts the cooldown at base cooldown")
    local sh = h:Cooldown(8052)
    check(sh.state == "cooling" and sh.shared == 8046, "shared category: Flame Shock cooling after Earth Shock")
    local gq = h:GCD()
    check(gq and math.abs(gq.length - 1.5) < 1e-6 and gq.spell == 8046, "GCD window starts with the spell's baseGCD (1.5 s)")
    local act = h:CDActive()
    check(#act == 2, "CDActive: O(k) set of cooling spells (2)")
    -- isOnGCD true -> false flip: observed GCD end
    tt = 100.5 h:CDObserve(8046, true, true)
    tt = 101.45 h:CDObserve(8046, true, true)    -- v2.2.15: due-time bracket sample just before the predicted end
    tt = 101.52 h:CDObserve(8046, true, false)
    check(h:GCD() == nil and vs[#vs].kind == "gcd" and vs[#vs].v == "V", "isOnGCD flip ends the GCD (verdict gcd V)")
    check(learned[#learned].kind == "gcd" and math.abs(learned[#learned].v - 1.52) < 1e-6, "learned GCD 1.52 s reported (onCDLearn)")
    -- isActive false outside the GCD: observed ready, learned cooldown, verdict cd-ready
    tt = 105.9 h:CDObserve(8046, false, false)
    local r = h:Cooldown(8046)
    check(r.state == "ready" and r.source == "isActive" and r.confidence == "high", "isActive false -> ready (source isActive)")
    check(vs[#vs].kind == "cd-ready" and vs[#vs].v == "V", "ready 0.1 s before predicted -> cd-ready V")
    -- the next cast uses the learned cooldown
    tt = 120
    h:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8046, true, nil)
    c = h:Cooldown(8046)
    check(c.source == "learned" and math.abs(c.ends - 125.9) < 1e-6, "next cast predicts with the learned cooldown 5.9 s")
    -- clear out-of-combat read calibrates (remaining + duration)
    tt = 121 h:CDObserve(8046, true, false, 4.5, 6.0)
    c = h:Cooldown(8046)
    check(c.source == "api-clear" and math.abs(c.ends - 125.5) < 1e-6, "clear startTime/duration recalibrates the window")
    -- UNIT_SPELLCAST_FAILED inside the window confirms it
    tt = 122
    local ff = h:OnCastFailed(8046, "UNIT_SPELLCAST_FAILED")
    check(ff and ff.rule == "fail-inside-cd", "UNIT_SPELLCAST_FAILED inside the tracker window = fail-inside-cd")
    local f2 = h:OnCastFailed(8052, "UNIT_SPELLCAST_FAILED")
    check(f2 and f2.rule == "fail-inside-cd", "a fail of a category member inside the shared window confirms it too")
    -- contradiction: ready far earlier than predicted
    tt = 123 h:CDObserve(8046, false, false)
    check(vs[#vs].kind == "cd-ready" and vs[#vs].v == "C", "ready 2.5 s early -> cd-ready C")
    -- totem: 1.0 s GCD (known answer), off-GCD racial (srCategory 0 / baseGCD 0)
    tt = 200
    h:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 2484, true, nil)
    gq = h:GCD()
    check(gq and math.abs(gq.length - 1.0) < 1e-6, "totem GCD 1.0 s (known answer)")
    tt = 201.2
    h:CDPayload(20572, nil, 0, 0)
    h:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 20572, true, nil)
    check(h:GCD() == nil, "baseGCD 0 spell (Blood Fury) does not start a GCD")
    -- cast gaps -> onCDLearn("gap")
    local gaps = 0
    for _, x in ipairs(learned) do if x.kind == "gap" then gaps = gaps + 1 end end
    check(gaps >= 1, "gap between consecutive own cast begins reported for the timing table")
    -- seed (Data/spell-timing.lua): no knowledge -> HS:GCD() still predicts from the seed
    local h2 = L5.New({ now = function() return tt end })
    h2:CDSeed(5394, { gcd = 1.0, confidence = "high" })
    h2:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 5394, true, nil)
    gq = h2:GCD()
    check(gq and math.abs(gq.length - 1.0) < 1e-6 and gq.source == "seed", "seed GCD used when no API/learned value (source seed)")
    local exp = h:Export()
    check(exp.cd and exp.cd.spells[8046] and exp.cd.spells[8046].learned and exp.cd.spells[8046].category == 19, "Export: learned cooldown + category per spellID")
    -- known-answer probe: secret isActive/isOnGCD values are passed as nil and never act as flips
    tt = 300
    h:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8052, true, nil)
    h:CDObserve(8052, nil, nil)
    check(h:Cooldown(8052).state == "cooling", "unreadable (nil) isActive never ends a cooldown")
end
print(string.format("hsm: %d passed, %d failed", passed, failures))
os.exit(failures == 0 and 0 or 1)
