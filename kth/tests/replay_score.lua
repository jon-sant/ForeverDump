local WROOT = os.getenv("WOWDEV_ROOT") or (function() -- portable root (handoff)
  local s = debug.getinfo(1, "S").source:sub(2)
  if s:sub(1, 1) ~= "/" then local p = io.popen("pwd"); s = p:read("*l") .. "/" .. s; p:close() end
  return s:match("^(.*)/kth/") or s:match("^(.*)/foreverdump/") or ".."
end)()
-- Replay a ForeverDump BG stream (tests/replay/<run>.lua) through K.T.H. Forever loaded in the Forever mock and
-- record, per scoreboard player, the first time K.T.H.'s own nameplate verdict (CheckUnitIsHealer) marks them.
-- usage: lua5.1 replay_score.lua <KTH.toc> <stream.lua> <out.json> [mode]   mode: port (default) | original-mn
-- Unit model follows the baseline BG diag (2026-10-10): enemy UnitClass/UnitGUID/UnitHealthMax SECRET, UnitName clear
-- first-name-only, UnitPowerType clear, UnitCanAttack clear; GetScoreInfo table clear with name/classToken/faction
-- clear and talentSpec/roleAssigned/guid/healingDone/damageDone SECRET (in-match).
package.path = WROOT .. "/foreverdump/tests/?.lua;" .. WROOT .. "/kth/tests/?.lua;" .. package.path
local W = dofile(WROOT .. "/foreverdump/tests/wowenv.lua"); _G.__W = W
local TF = require("tocfiles")
dofile(WROOT .. "/kth/tests/mockextra.lua")
local SECRET = W.SECRET
local tocPath, streamPath, outPath, mode = arg[1], arg[2], arg[3], arg[4] or "port"
local D = dofile(streamPath)
local errors = {}
seterrorhandler(function(m) errors[#errors + 1] = tostring(m) end)

if mode == "original-mn" then
    -- original K.T.H. on Forever data, Midnight path forced (what retail K.T.H. logic would do with Forever's values)
    GetBuildInfo = function() return "12.0.1", "70334", "", 120001, "", "", 120001 end
end

-- ---------------------------------------------------------------- unit model
local ZONE = os.getenv("KTH_ZONE") or "pvp"
local ENEMY_CLASS_CLEAR = os.getenv("KTH_ENEMY_CLASS") == "clear"
local roster = D.roster
local U, POWER = {}, {}           -- token -> roster index (0 = player); roster index -> power token
local PT = { MANA = 0, RAGE = 1, FOCUS = 2, ENERGY = 3, HAPPINESS = 4 }
-- forever.3: UNIT_POWER_UPDATE also reports secondary powers (COMBO_POINTS, HOLY_POWER, ...); only primary types
-- can be a UnitPowerType. (A form-shifted druid's MANA ticks still look like MANA: known model limit.)
local PRIMARY = { MANA = true, RAGE = true, FOCUS = true, ENERGY = true, RUNIC_POWER = true }
local function R(tok) local i = U[tok] if i and i > 0 then return roster[i], i end end
UnitExists = function(u) return u == "player" or U[u] ~= nil end
UnitIsPlayer = function(u) return u == "player" or R(u) ~= nil end
-- forever.4: UnitName's 2nd return is the scoreboard surname on Forever (D5b, measured runs 17+18 59/59). A replay
-- carries real full names (meta.board = true: run 16 via tools/realnames.py, runs 17/18 from the KTH diag board) or
-- none at all (meta.board = false: runs 10-13, first names as logged, no scoreboard, no classes). Nothing synthetic.
local BOARD = (D.meta.board ~= false)
for _, r in ipairs(roster) do if r.full == nil then BOARD = false end end
local function surname(r) if not BOARD or not r.full then return nil end return r.full:match("^%S+ (.+)$") end
UnitName = function(u) if u == "player" then return "Owner", nil end local r = R(u) if r then return r.first, surname(r) end end
UnitGUID = function(u) if u == "player" then return "Player-1-OWNER" end if R(u) then return SECRET end end
UnitCanAttack = function(a, b) local r = R(b) if r then return r.side == "E" end return false end
UnitIsFriend = function(a, b) local r = R(b) if r then return r.side == "F" end return true end
UnitIsEnemy = function(a, b) local r = R(b) return r and r.side == "E" or false end
UnitClass = function(u)
    local r = R(u)
    if not r then return "Shaman", "SHAMAN", 7 end
    if r.side == "E" and not ENEMY_CLASS_CLEAR then return SECRET, SECRET, SECRET end -- measured in BGs: 750/750 secret
    return r.class, r.class, 1                                        -- friendly: not measured (no friendly plates seen)
end
UnitPowerType = function(u) local _, i = R(u) if not i then return 0, "MANA" end local p = POWER[i] or "MANA" return PT[p] or 0, p end
UnitIsUnit = function(a, b) return U[a] ~= nil and U[a] == U[b] end
UnitIsDead = function() return false end
UnitHealthMax = function(u) if u == "player" then return 4000 end return SECRET end
UnitFactionGroup = function() return "Horde", "Horde" end
-- forever.3 F7: non-BG scenarios. KTH_ZONE = pvp (default) | arena | none (open world) | party ; KTH_ENEMY_CLASS =
-- secret (default, measured in BGs) | clear (world/arena readability is NOT measured: both models are tested)
IsInInstance = function() if ZONE == "none" then return false, "none" end return true, ZONE end
GetInstanceInfo = function() return "Zone", ZONE, 0, "", 5, 0, false, (ZONE == "none") and 0 or 1234 end
local plates = {}
C_NamePlate = C_NamePlate or {}
C_NamePlate.GetNamePlateForUnit = function(u)
    if not U[u] or not u:match("^nameplate") then return nil end
    plates[u] = plates[u] or CreateFrame("Frame", nil, UIParent)
    return plates[u]
end
C_NamePlate.GetNamePlates = function() local t = {} for _, p in pairs(plates) do t[#t + 1] = p end return t end
GetNumBattlefieldScores = function() if not BOARD or ZONE == "none" or ZONE == "party" then return 0 end return #roster end -- no scoreboard outside BG/arena, none for board-less runs
C_PvP = C_PvP or {}
C_PvP.GetScoreInfo = function(i)
    local r = BOARD and roster[i]
    if not r then return nil end
    return { name = r.full, classToken = r.class, className = r.class, faction = (r.side == "F") and 0 or 1,
             talentSpec = SECRET, roleAssigned = SECRET, guid = SECRET, healingDone = SECRET, damageDone = SECRET,
             killingBlows = SECRET, deaths = SECRET }
end
GetBattlefieldScore = function(i)
    local r = BOARD and roster[i]
    if not r then return nil end
    return r.full, SECRET, SECRET, SECRET, SECRET, (r.side == "F") and 0 or 1, "Race", r.class, r.class,
        SECRET, SECRET, SECRET, SECRET, nil, SECRET, SECRET, SECRET
end
RequestBattlefieldScoreData = function() end
-- forever.7: UnitLevel (FD: clear on hostile plates; values not captured, so real replays carry none -> nil).
UnitLevel = function(u) local r = R(u) if r then return r.level end if u == "player" then return 60 end end
-- forever.7 spec sources, only for SYNTHETIC fixtures that declare them (no capture holds their values):
-- meta.arenaSpecs = { {gi, specID}, ... } -> arenaN tokens + GetArenaOpponentSpec; meta.groupRoles = { {gi, role}, ... }
-- -> raidN tokens + UnitGroupRolesAssigned.
local AS, GR = D.meta.arenaSpecs, D.meta.groupRoles
GetNumArenaOpponentSpecs = function() return AS and #AS or 0 end
GetArenaOpponentSpec = function(i) local x = AS and AS[i] return x and x[2] or nil end
IsInRaid = function() return GR ~= nil end
GetNumGroupMembers = function() return GR and #GR or 0 end
UnitGroupRolesAssigned = function(u) local i = tonumber((u or ""):match("^raid(%d+)$")) local x = GR and i and GR[i] return x and x[2] or "NONE" end
if AS then for i, x in ipairs(AS) do U["arena" .. i] = x[1] end end
if GR then for i, x in ipairs(GR) do U["raid" .. i] = x[1] end end
-- forever.5: C_DamageMeter from the run's own FD snapshots (tests/replay/<run>.dm.lua, raw; "<secret>" = was secret).
-- FD read GetCombatSessionFromType(Current, type) on PLAYER_REGEN_ENABLED; the harness fires PLAYER_REGEN_ENABLED at
-- each snapshot's GetTime() and serves that snapshot. Before the first kept snapshot (FD ring = last 21) there is no
-- meter data at all (returns nil): missing, not zero. KTH_NO_METER=1 replays without the meter.
local DMPATH = streamPath:gsub("%.lua$", ".dm.lua")
local DM = nil
if not os.getenv("KTH_NO_METER") then local fh = io.open(DMPATH, "r") if fh then fh:close() DM = dofile(DMPATH) end end
local DMCUR = nil
Enum = Enum or {}
Enum.DamageMeterType = { DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, Absorbs = 4, Interrupts = 5, Dispels = 6,
    DamageTaken = 7, AvoidableDamageTaken = 8, Deaths = 9, EnemyDamageTaken = 10 }
Enum.DamageMeterSessionType = { Overall = 0, Current = 1, Expired = 2 }
local DMNAME = {} for k, v in pairs(Enum.DamageMeterType) do DMNAME[v] = k end
local function unsecret(v)
    if v == "<secret>" then return SECRET end
    if type(v) == "table" then local o = {} for k, x in pairs(v) do o[k] = unsecret(x) end return o end
    return v
end
C_DamageMeter = C_DamageMeter or {}
C_DamageMeter.GetCombatSessionFromType = function(st, ty)
    if st ~= Enum.DamageMeterSessionType.Current or not DMCUR then return nil end
    local s = DMCUR.byType[DMNAME[ty] or ""]
    if not s then return nil end
    return unsecret(s)
end

-- forever.3: real tickers (K.T.H.'s 1 s nameplate scan and the scoreboard scanner run on C_Timer.NewTicker; a
-- no-op ticker left icons stale in the replay). Run in stream time by runTickers().
local TICKERS = {}
C_Timer.NewTicker = function(sec, fn, n)
    local tk = { sec = sec, fn = fn, n = n, next = GetTime() + sec }
    tk.Cancel = function() tk.dead = true end
    tk.IsCancelled = function() return tk.dead end
    TICKERS[#TICKERS + 1] = tk
    return tk
end
-- forever.11 perf: KTH_PERF=1 times K.T.H.'s handlers per event name, its tickers and the plate-log tick (os.clock, CPU s)
local PERF = os.getenv("KTH_PERF") and {} or nil
local function perfAdd(name, dt)
    local p = PERF[name]; if not p then p = { n = 0, total = 0, max = 0 }; PERF[name] = p end
    p.n = p.n + 1; p.total = p.total + dt; if dt > p.max then p.max = dt end
end
local function runTickers()
    local now = GetTime()
    for _, tk in ipairs(TICKERS) do
        local guard = 0
        while not tk.dead and tk.next <= now and guard < 5 do
            guard = guard + 1; tk.next = tk.next + tk.sec
            local c0 = PERF and os.clock()
            local ok, e = pcall(tk.fn, tk)
            if PERF then perfAdd("ticker:" .. tostring(tk.sec) .. "s", os.clock() - c0) end
            if not ok then errors[#errors + 1] = "TICKER " .. tostring(e) end
            if tk.n then tk.n = tk.n - 1; if tk.n <= 0 then tk.dead = true end end
        end
        if tk.next <= now then tk.next = now + tk.sec end
    end
end

-- forever.3: sound hook installed before load (Announcer captures PlaySoundFile as an upvalue)
local moSound, moStats = 0, { hovers = 0, verdictTrue = 0, alerted = 0, alertedNoVerdict = 0, missed = 0 }
local _PSF = PlaySoundFile
local tlSound = 0
PlaySoundFile = function(id, ...) if id == 567458 then moSound = moSound + 1 end if id == 567482 then tlSound = tlSound + 1 end if _PSF then return _PSF(id, ...) end return true end

-- ---------------------------------------------------------------- load
local ns = {}
for _, f in ipairs(TF.files(tocPath)) do
    local chunk, err = loadfile(f)
    if not chunk then errors[#errors + 1] = "COMPILE " .. err
    else local ok, e = pcall(chunk, "KTH", ns) if not ok then errors[#errors + 1] = "LOAD " .. f .. ": " .. tostring(e) end end
end
local function fire(...)
    local c0 = PERF and os.clock()
    local ok, e = pcall(W.fire, ...)
    if PERF then perfAdd("event:" .. tostring((...)), os.clock() - c0) end
    if not ok then errors[#errors + 1] = "FIRE " .. tostring(e) end
end
fire("ADDON_LOADED", "KTH")
IsLoggedIn = function() return true end
fire("PLAYER_LOGIN")
local A = LibStub("AceAddon-3.0"):GetAddon("K.T.H.")
local check = A.MN_CheckUnitIsHealer
if os.getenv("KTH_PVE") == "off" and A.db then A.db.global.Pve = false end -- forever.3 F7: K.T.H.'s own Pve option

-- ---------------------------------------------------------------- replay
local ev = D.ev
local t0 = ev[1][1]
W.state.time = 1000
-- forever.6 backtest variants: KTH_CFG="key=number,..." overrides ForeverEvidence.CFG (thresholds only; no data change)
if os.getenv("KTH_CFG") and A.ForeverEvidence and A.ForeverEvidence.CFG then
    for k, v in os.getenv("KTH_CFG"):gmatch("([%w_]+)=([%d%.%-]+)") do A.ForeverEvidence.CFG[k] = tonumber(v) end
end
-- forever.11: KTH_SETTINGS="healerSharePct=N,debug=0|1,ov.PRIEST=N,ov.PRIEST:Holy=N" sets the user's saved settings
-- (KTH_NameplateSettings) before the match starts: healer-threshold GUI values and the debug checkbox.
if os.getenv("KTH_SETTINGS") then
    local S = _G.KTH_NameplateSettings
    if type(S) ~= "table" then S = {}; _G.KTH_NameplateSettings = S end
    for k, v in os.getenv("KTH_SETTINGS"):gmatch("([%w_%.:]+)=([%d%.%-]+)") do
        if k == "debug" then S.debugEnabled = (v ~= "0")
        elseif k:match("Enabled$") then S[k] = (v ~= "0") -- forever.12 toggles (elimEnabled, formTieEnabled)
        elseif k:sub(1, 3) == "ov." then S.healerShareOverrides = S.healerShareOverrides or {}; S.healerShareOverrides[k:sub(4)] = tonumber(v)
        else S[k] = tonumber(v) end
    end
end
fire("PLAYER_ENTERING_WORLD", false, false)
fire("UPDATE_BATTLEFIELD_SCORE")
if AS then fire("ARENA_PREP_OPPONENT_SPECIALIZATIONS") end
if GR then fire("GROUP_ROSTER_UPDATE") end
local marks, seen, wrongMarks, lastSeen = {}, {}, {}, {}
-- forever.3 F3 regression: every sweep, hover each enemy plate (mouseover = that unit) and record K.T.H.'s announcer
-- reaction (HHTD_HEALER_MOUSE_OVER -> PlaySoundFile(567458)); compare with the nameplate verdict for that unit.
local moAlertedPlayers, moMissedPlayers = {}, {}
local last, flips, flipWhy, offFlips = {}, {}, {}, {}
local nextSweep = 0
local function sweep(t)
    for tok, i in pairs(U) do
        if i and i > 0 and tok:match("^nameplate%d+$") then
            if not seen[i] then seen[i] = t end
            lastSeen[i] = t
            local ok, isHealer, isFriend, method, cls = pcall(check, tok)
            if ok and isHealer and not marks[i] then marks[i] = { t = t, method = method, iconClass = cls or false } end
            -- flip tracking (forever.3): verdict changes for the same player while their plate stays up
            local key = tok .. "#" .. i
            local v = (ok and isHealer) and true or false
            if last[key] == true and v == false then offFlips[i] = (offFlips[i] or 0) + 1 end
            if last[key] ~= nil and last[key] ~= v then flips[i] = (flips[i] or 0) + 1; flipWhy[i] = flipWhy[i] or {}; flipWhy[i][#flipWhy[i] + 1] = (v and "on:" or "off:") .. tostring(POWER[i]) end
            last[key] = v
            if not ok then errors[#errors + 1] = "CHECK " .. tostring(isHealer) end
            if U[tok] and roster[i].side == "E" then
                U["mouseover"] = i
                local before = moSound
                fire("UPDATE_MOUSEOVER_UNIT")
                local alerted = moSound > before
                moStats.hovers = moStats.hovers + 1
                if v then moStats.verdictTrue = moStats.verdictTrue + 1 end
                if alerted then moStats.alerted = moStats.alerted + 1; moAlertedPlayers[i] = true
                    -- then click it: K.T.H. plays the target-lock sound when the hovered healer becomes the target
                    if os.getenv("KTH_TARGET_TEST") then
                        local oldT, tb = U["target"], tlSound
                        U["target"] = i; fire("PLAYER_TARGET_CHANGED")
                        moStats.targetLocked = (moStats.targetLocked or 0) + ((tlSound > tb) and 1 or 0)
                        U["target"] = oldT
                    end
                end
                if alerted and not v then moStats.alertedNoVerdict = moStats.alertedNoVerdict + 1 end
                local isTarget = U["target"] == i -- K.T.H. design: no mouse-over alert on the current target (TARGET_LOCKED path)
                if v and not alerted and isTarget then moStats.onTarget = (moStats.onTarget or 0) + 1
                elseif v and not alerted then moStats.missed = moStats.missed + 1; moMissedPlayers[i] = true end
                U["mouseover"] = nil
            end
        end
    end
end
local counts = { C = 0, U = 0, A = 0, M = 0 }
local dmi = 1
for _, e in ipairs(ev) do
    local t, k, tok, gi, a = e[1], e[2], e[3], e[4], e[5]
    while DM and DM.snaps[dmi] and DM.snaps[dmi].g <= t do
        W.state.time = 1000 + (DM.snaps[dmi].g - t0)
        DMCUR = DM.snaps[dmi]; dmi = dmi + 1; counts.M = counts.M + 1
        fire("PLAYER_REGEN_ENABLED")
    end
    W.state.time = 1000 + (t - t0)
    runTickers()
    if t - t0 >= nextSweep then
        if A.ForeverEvidence then A.ForeverEvidence.flush() end
        sweep(t); nextSweep = (t - t0) + 1
        if A.ForeverEvidence and A.ForeverEvidence.plateLogTick then
            local c0 = PERF and os.clock()
            A.ForeverEvidence.updateZone(); A.ForeverEvidence.plateLogTick()
            if PERF then perfAdd("tick:plateLog+updateZone", os.clock() - c0) end
        end
    end
    if k == "S" then fire("UPDATE_BATTLEFIELD_SCORE")
    elseif k == "T" then -- target change: nothing to model
    elseif tok then
        if k == "R" then
            fire("NAME_PLATE_UNIT_REMOVED", tok); U[tok] = nil
        else
            U[tok] = gi
            if k == "A" then fire("NAME_PLATE_UNIT_ADDED", tok); counts.A = counts.A + 1
            elseif k == "P" then if gi and a and PRIMARY[a] then POWER[gi] = a end
            elseif k == "C" then counts.C = counts.C + 1; fire("UNIT_SPELLCAST_SUCCEEDED", tok, "Cast-x", (a == "SECRET" or a == nil) and SECRET or a)
            elseif k == "U" then counts.U = counts.U + 1; fire("UNIT_COMBAT", tok, a, "", SECRET, 1) end
        end
    end
end
if A.ForeverEvidence then A.ForeverEvidence.flush() end
sweep(ev[#ev][1])

local out = { mode = mode, errors = errors, counts = counts, marks = {}, seen = {}, t0 = t0, t1 = ev[#ev][1],
              stats = A.ForeverEvidence and A.ForeverEvidence.stats or nil }
out.recs = {}
if A.ForeverEvidence then for k, r in pairs(A.ForeverEvidence.R) do out.recs[k] = { heal = r.heal, dmg = r.dmg, casts = r.casts, claim = r.claim, claimT = r.claimT, firstClaimT = r.firstClaimT, contradicted = r.contradicted, why = r.why, offs = r.offs, offWhy = r.offWhy, dmVote = r.dmVote, dmH = r.dmH, dmD = r.dmD, healT1 = r.healT1, spec = r.spec, specWhy = r.specWhy, specT = r.specT } end end
out.dmClass = A.ForeverEvidence and A.ForeverEvidence.dmClass or nil
out.meter = DM and (DM.meta.n or #DM.snaps) or 0
out.mouseover = moStats
out.zone = ZONE
out.board = BOARD
out.rosterSize = 0
if A.ForeverEvidence then for _ in pairs(A.ForeverEvidence.roster) do out.rosterSize = out.rosterSize + 1 end end
-- forever.3 F2/F6 regression: icon state vs verdict in the plate log (a healer verdict with no icon = intermittent icon)
local plog = A.db and A.db.global.ForeverPlateLog or {}
local pl = { changes = #plog, healerNoIcon = 0, iconNoHealer = 0 }
for _, e in ipairs(plog) do
    local h = e.v ~= "no" and e.v ~= "err"
    if h and not e.icon then pl.healerNoIcon = pl.healerNoIcon + 1 end
    if e.icon and not h then pl.iconNoHealer = pl.iconNoHealer + 1 end
end
out.platelog = pl
out.platelogRows = {}
for k, e in ipairs(plog) do out.platelogRows[k] = string.format("%.1f %s %s %s %s icon=%s %s", e.t - t0, e.who, e.v, tostring(e.pwr), tostring(e.cls), tostring(e.icon), e.tok) end
print("platelog changes/healerNoIcon/iconNoHealer", pl.changes, pl.healerNoIcon, pl.iconNoHealer)
out.moAlerted, out.moMissed = {}, {}
for i in pairs(moAlertedPlayers) do out.moAlerted[#out.moAlerted + 1] = i end
for i in pairs(moMissedPlayers) do out.moMissed[#out.moMissed + 1] = i end
out.flips = {}
for i, n in pairs(flips) do out.flips[tostring(i)] = { n = n, off = offFlips[i] or 0, why = table.concat(flipWhy[i], ","):sub(1, 200) } end
for i, m in pairs(marks) do out.marks[tostring(i)] = m end
-- forever.9: icon check. Drive K.T.H.'s own ApplyIndicatorStyle with a recording texture for every side x class
-- (+ nil and a SECRET class) and record exactly what reaches SetTexture / SetTexCoord.
-- forever.9b: /kthg GUI (KTH_Options.lua). Every icon select (friend, enemy, per-class override) must offer hhtd and
-- hhtdmin; selecting through the widgets' own set() must reach MidnightNameplates' live SETTINGS and draw the sprite cell.
do
    local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
    local opts = reg and reg:GetOptionsTable("KTH_Nameplates", "dialog", "KTHTest-1.0")
    if opts then
        local sel = {}
        local function walk(t, path)
            if type(t) ~= "table" then return end
            if t.type == "select" and type(t.values) == "table" and (t.values.cross or t.values.hhtd) then sel[#sel + 1] = { path = path, w = t } end
            if type(t.args) == "table" then for k, v in pairs(t.args) do walk(v, path .. "." .. k) end end
        end
        walk(opts, "")
        local G = { selects = 0, missing = {}, roundtrip = {} }
        for _, x in ipairs(sel) do
            G.selects = G.selects + 1
            if not (x.w.values.hhtd and x.w.values.hhtdmin) then G.missing[#G.missing + 1] = x.path end
        end
        local function find(suffix) for _, x in ipairs(sel) do if x.path:sub(-#suffix) == suffix then return x.w end end end
        local fi, ei = find(".friendIcon"), find(".enemyIcon")
        local ci; for _, x in ipairs(sel) do if x.path:match("PRIEST") and x.path:match("classIcon$") then ci = x.w end end
        local function draw(isFriend, cls)
            local rec = {}
            local tex = { SetTexture = function(_, p) rec.path = p end, SetTexCoord = function(_, a, b, c, d) rec.cell = { math.floor(a * 4 + 0.5), math.floor(c * 4 + 0.5) } end, SetVertexColor = function() end }
            pcall(A.MN_ApplyIndicatorStyle, { texture = tex, SetSize = function() end }, isFriend, cls)
            return rec
        end
        if fi and ei and ci and A.MN_ApplyIndicatorStyle then
            fi.set(nil, "hhtdmin"); ei.set(nil, "skull"); ci.set(nil, "hhtd")
            local S = _G.KTH_NameplateSettings
            G.saved = { friendIcon = S.friendIcon, enemyIcon = S.enemyIcon, priestOverride = S.classOverrides.PRIEST and S.classOverrides.PRIEST.icon }
            G.roundtrip.friendDruid = draw(true, "DRUID")      -- hhtdmin sheet, cell (1,0)
            G.roundtrip.enemyPriest = draw(false, "PRIEST")    -- PRIEST override hhtd -> full sheet, enemy priest cell (2,2)
            G.roundtrip.enemyShaman = draw(false, "SHAMAN")    -- no override -> skull raid marker
            G.roundtrip.enemyNone = draw(false, nil)           -- no class -> enemy setting (skull)
            ci.set(nil, ""); fi.set(nil, "hhtd"); ei.set(nil, "hhtd")
            G.reset = { friendIcon = S.friendIcon, enemyIcon = S.enemyIcon, priestOverride = S.classOverrides.PRIEST and S.classOverrides.PRIEST.icon or false }
        end
        out.gui = G
    end
end
if A.MN_ApplyIndicatorStyle then
    out.icons = {}
    for _, side in ipairs({ true, false }) do
        for _, c in ipairs({ "DRUID", "MONK", "PALADIN", "PRIEST", "SHAMAN", "EVOKER", "WARRIOR", "NONE", "SECRET" }) do
            local rec = {}
            local tex = { SetTexture = function(_, p) rec.path = p; rec.pathSecret = W.issecret and W.issecret(p) or (p == SECRET) end,
                          SetTexCoord = function(_, ...) rec.tc = { ... }; for _, v in ipairs(rec.tc) do if v == SECRET or type(v) ~= "number" then rec.badTc = true end end end,
                          SetVertexColor = function() end }
            local ind = { texture = tex, SetSize = function() end }
            local cls = (c == "NONE") and nil or (c == "SECRET" and SECRET or c)
            local okS, err = pcall(A.MN_ApplyIndicatorStyle, ind, side, cls)
            rec.ok = okS; rec.err = okS and nil or tostring(err)
            out.icons[(side and "F:" or "E:") .. c] = rec
        end
    end
end
for i, t in pairs(seen) do out.seen[tostring(i)] = t end
do -- forever.11: what the debug switch captured (meter reads in the timeline, plate-log rows)
    local g = A.db and A.db.global or {}; local reads = 0
    if type(g.ForeverDebug) == "table" then for _, ss in ipairs(g.ForeverDebug.sessions or {}) do reads = reads + #(ss.meter or {}) end end
    local pl = 0; if type(g.ForeverPlateLog) == "table" then pl = #g.ForeverPlateLog end
    out.debugCapture = { meterReads = reads, plateLogRows = pl }
end
if PERF then out.perf = PERF end
out.lastSeen = {}; for i, t in pairs(lastSeen) do out.lastSeen[tostring(i)] = t end
-- minimal JSON writer
local function J(v)
    local tv = type(v)
    if tv == "table" then
        local isArr = #v > 0 or next(v) == nil
        local parts = {}
        if isArr then for _, x in ipairs(v) do parts[#parts + 1] = J(x) end return "[" .. table.concat(parts, ",") .. "]" end
        for kk, x in pairs(v) do parts[#parts + 1] = string.format("%q", tostring(kk)) .. ":" .. J(x) end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif tv == "string" then return string.format("%q", v)
    elseif tv == "number" or tv == "boolean" then return tostring(v) end
    return "null"
end
local f = io.open(outPath, "w") f:write(J(out)) f:close()
print(mode, streamPath:match("[^/]+$"), "errors", #errors, "marks", (function() local n = 0 for _ in pairs(marks) do n = n + 1 end return n end)(),
    "mouseover hovers/verdict/alerted/missed/onTarget/alertNoVerdict", moStats.hovers, moStats.verdictTrue, moStats.alerted, moStats.missed, moStats.onTarget or 0, moStats.alertedNoVerdict)
for i = 1, math.min(5, #errors) do print("  ERR " .. errors[i]:sub(1, 200)) end
