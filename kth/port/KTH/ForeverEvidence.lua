-- [Forever] K.T.H. Forever port - ForeverEvidence.lua (new file, port helper; not part of the original K.T.H.)
--
-- Why this exists (measured in the baseline BG diag, 2026-10-10, see FOREVER-PORT.md):
--   * enemy nameplate UnitClass is secret (750/750 reads, ooc + combat) -> K.T.H.'s class conditions need the class
--     from somewhere else: the scoreboard (C_PvP.GetScoreInfo name/classToken/faction are clear in every phase);
--   * enemy plate UnitName is clear but first-name-only ("Aerie") while the scoreboard says "Aerie Dunleary" ->
--     join on first word + side, never when that first name is not unique;
--   * [forever.3] D5b: UnitName's 2nd return ("realm") is the scoreboard surname: "Aerie","Dunleary" (ForeverDump runs
--     17+18: 59/59 name-realm == scoreboard "First Surname"; realm clear on nameplate/mouseover/target/raid
--     hostile-player). So the join is exact on name.." "..realm + side; the first-name join (with the duplicate guard)
--     is only the fallback when no realm is returned;
--   * talentSpec/roleAssigned are secret during the match (clear only post-match) and the WOWC spec->role table is
--     empty -> the scoreboard names no healer during the match;
--   * nameplate/party/raid spellIDs are secret (nameplate 20/20) -> K.T.H.'s SPELL confirmation never fires.
-- Substitute for the last two: heal evidence. All events of one client frame share one GetTime(); a cast
-- (UNIT_SPELLCAST_SUCCEEDED) by exactly one identified player in a frame plus a UNIT_COMBAT "HEAL" on another player of
-- the same side in that frame = one heal-on-other link. Enough links (and mostly heals, not damage) confirm that
-- specific player as a healer, the same way SpellcastConfirmed does in K.T.H. Only clear values are used
-- (UnitName, UnitCanAttack, UnitIsPlayer, UnitPowerType, the UNIT_COMBAT action string); amounts are never read.
-- No division anywhere (shares are cross-multiplied).
-- [forever.5] User decision: "having mana does not make one a healer" (resto, feral and balance druids all show MANA).
-- The healer verdict is healing OUTPUT: a player is a healer when the majority of their observed output is healing,
-- or their healing is far above the group's. Class is only a can-heal prerequisite. Sources (all clear reads):
--   * actions: the frame-joined heal/damage links above (+ clear healer-only spellIDs where readable, open world);
--   * amounts: C_DamageMeter Current session, HealingDone vs DamageDone (measured, FD runs 16-18: amounts clear out
--     of combat and secret in combat; friendly rows carry clear names; enemy rows carry a secret name/GUID but a
--     clear class -> joined to the scoreboard only when that class is unique on the enemy team, else class-level);
-- with hysteresis (on at >= 60 percent, off only below 35 percent with more evidence) and minimum evidence (unknown until
-- then). Thresholds tuned on real runs 16-18 (FOREVER-PORT.md, forever.5).
-- K.T.H. is (c) John Wellesz (H.H.T.D.) and Scone (K.T.H.), All Rights Reserved; private port, no redistribution.
local ADDON_NAME, T = ...;
local HHTD = T.HHTD;
local FS = T.FS;
if not (FS and FS.IS_FOREVER) then return; end

local GetTime, pairs, ipairs, type, pcall = GetTime, pairs, ipairs, type, pcall;
local str, num, bool, firstWord = FS.str, FS.num, FS.bool, FS.firstWord;

local E = {};
HHTD.ForeverEvidence = E;

local inBG = false;       -- battleground: the only context with the measured scoreboard (D5/D5b/D6 apply here only)
local active = false;     -- [Forever] F7: heal-evidence engine on (BG, arena, open world; party/raid only with K.T.H.'s Pve option)
local zoneKey = nil;      -- kind + instance id; any change = new roster/evidence
local zoneKind = "none";
function HHTD.MN_InBG() return inBG; end
function HHTD.MN_ZoneKind() return zoneKind; end

E.HEALER_CLASS = { PRIEST = true, PALADIN = true, SHAMAN = true, DRUID = true, MONK = true, EVOKER = true }; -- can-heal prerequisite only
-- [forever.5] actions: on at healPct with healMin links (unknownHealMin if class unknown); off below offPct with >= offMin links.
-- meter: on when heal >= dmMin and (heal share >= dmSharePct or heal >= dmMedianX x group median); off when heal+damage
-- >= dmOffMin and share < dmOffPct (and not above dmMedianX x median).
E.CFG = { healMin = 2, healPct = 60, unknownHealMin = 3, offPct = 35, offMin = 6,
          dmMin = 1000, dmSharePct = 60, dmMedianX = 6, dmOffPct = 35, dmOffMin = 2000,
          grpSharePct = 63, weakLinkMin = 1,
          -- [forever.10] kWeak: the forever.6 one-player rule needs the class's meter rows to PROVE >= kWeak healer(s)
          -- (sticky minimum over every pairing of the anonymous rows) instead of "some row could be a healer";
          -- elim: mark the class's remaining players by elimination when they are no more than that proven minimum;
          -- formTie: druid class groups whose rows prove >= 1 DPS druid exclude the druid(s) with the most bear/cat power
          -- (RAGE+ENERGY share of plate power samples, >= formMin samples, >= formGap points above the next druid);
          -- linkNet: heal links minus damage links needed for a links-only mark (run 19: feral 梦之旅程 2 heal / 1 damage link).
          -- kSharePct: share a meter row needs to count toward the proven minimum (margin over dmSharePct).
          kWeak = 1, elim = 1, formTie = 1, formMin = 5, formGap = 10, linkNet = 2, kMaxN = 6, kSharePct = 65 };

-- [forever.11] user-set healer threshold (/kthg General: "Healer threshold", KTH_NameplateSettings.healerSharePct) and
-- per class / class+spec overrides (KTH_NameplateSettings.healerShareOverrides["PRIEST"], ["PRIEST:Holy"], ...).
-- It is ONE concept: the share of a player's own output that is healing for "this is a healer". It moves together:
-- healPct (cast links) and dmSharePct (meter row) = S, grpSharePct (class group) = S + 3, kSharePct (proof margin) = S + 5,
-- i.e. the forever.6/10 margins over the base are kept. Not moved: the "off" thresholds (offPct / dmOffPct 35: a mark is
-- withdrawn only below them), amounts (dmMin, dmOffMin), counts and the 6x-median rule. Unset (nil) = E.CFG unchanged.
-- Precedence: class+spec override (spec known) -> class override -> global -> E.CFG.
E.SHARE_MIN, E.SHARE_MAX = 40, 90; -- every setting stays above the 35% off thresholds
local function pctSetting(v)
    v = tonumber(v);
    if not v or v <= 0 then return nil; end -- 0 / nil = "use global"
    return math.max(E.SHARE_MIN, math.min(E.SHARE_MAX, v));
end
function E.sharePct(cls, spec)
    local s = _G.KTH_NameplateSettings;
    if type(s) ~= "table" then return nil; end
    local o = type(s.healerShareOverrides) == "table" and s.healerShareOverrides or nil;
    local v = o and cls and ((type(spec) == "string" and pctSetting(o[cls .. ":" .. spec])) or pctSetting(o[cls])) or nil;
    return v or pctSetting(s.healerSharePct);
end
-- [forever.12] more /kthg General settings over E.CFG, read at use time through the proxy E.cfg (nil = E.CFG value):
--   removeSharePct -> offPct + dmOffPct (a mark is removed below it; clamped >= 5 and <= every healer threshold in use - 5)
--   meterMinHeal   -> dmMin (healing a meter row needs before it can count as a healer's)
--   healsNeeded N  -> linkNet = N (heals minus hits for a mark without the meter) and healMin = N, unknownHealMin = N + 1:
--                     heals - hits >= N already implies heals >= N, so healMin = N keeps the two consistent (defaults 2/2/3)
--   elimEnabled    -> elim (1/0);  formTieEnabled -> formTie (1/0)
E.REMOVE_MIN, E.SHARE_GAP = 5, 5;
local function settingsTable() local t = _G.KTH_NameplateSettings; return type(t) == "table" and t or nil; end
local function lowestHealerPct(st)
    local lo = pctSetting(st.healerSharePct) or E.CFG.dmSharePct;
    if type(st.healerShareOverrides) == "table" then
        for _, x in pairs(st.healerShareOverrides) do x = pctSetting(x); if x and x < lo then lo = x; end end
    end
    return lo;
end
function E.removePct(st)
    st = st or settingsTable();
    local v = st and tonumber(st.removeSharePct);
    if not v then return nil; end
    return math.max(E.REMOVE_MIN, math.min(math.floor(v), lowestHealerPct(st) - E.SHARE_GAP));
end
local function healsNeeded(st)
    local v = tonumber(st.healsNeeded);
    return v and math.max(1, math.min(10, math.floor(v))) or nil;
end
local function toggle(v) if v == nil then return nil; end return v and 1 or 0; end
local SETTING = {
    offPct = E.removePct, dmOffPct = E.removePct,
    dmMin = function(st) local v = tonumber(st.meterMinHeal); return v and math.max(1, math.floor(v)) or nil; end,
    linkNet = healsNeeded, healMin = healsNeeded,
    unknownHealMin = function(st) local n = healsNeeded(st); return n and n + 1 or nil; end,
    elim = function(st) return toggle(st.elimEnabled); end,
    formTie = function(st) return toggle(st.formTieEnabled); end,
};
E.SETTING_KEYS = SETTING;
E.cfg = setmetatable({}, { __index = function(_, k)
    local f, st = SETTING[k], settingsTable();
    if f and st then local v = f(st); if v ~= nil then return v; end end
    return E.CFG[k];
end, __newindex = function() error("E.cfg is read-only; set E.CFG or the saved settings"); end });

-- -> healPct, dmSharePct, grpSharePct, kSharePct for this class / spec
function E.thresholds(cls, spec)
    local cfg = E.cfg;
    local b = E.sharePct(cls, spec);
    if not b then return cfg.healPct, cfg.dmSharePct, cfg.grpSharePct, cfg.kSharePct; end
    return b + (cfg.healPct - cfg.dmSharePct), b, math.min(100, b + (cfg.grpSharePct - cfg.dmSharePct)),
        math.min(100, b + (cfg.kSharePct - cfg.dmSharePct));
end
-- [forever.6] several enemies of one class (rows indistinguishable: secret names):
--   all healers  : >= n heal rows, summed heal >= dmMin x n, class heal share (sum heal / sum heal+damage) >= grpSharePct
--                  (runs 16-18: every all-healer class group >= 0.664, every other group <= 0.592; FOREVER-PORT.md)
--   none healers : >= n damage rows, each >= dmOffMin, and no heal row that could reach dmSharePct even paired with
--                  the smallest damage row
--   otherwise    : "possible" when some heal row >= dmMin could reach dmSharePct; then a player of that class with
--                  >= weakLinkMin heal links and no damage link is marked (run 17 Gorrotar). forever.12 (user): no cap on
--                  the number of healers (the forever.6 teamMax 3 is removed: open world, arena, BG and groups differ)

local R, roster, firstCount, byFull = {}, {}, {}, {};
E.R, E.roster, E.byFull = R, roster, byFull;
E.stats = {};

local function key(isFriend, first) return (isFriend and "F:" or "E:") .. first; end

function E.reset()
    for k in pairs(R) do R[k] = nil; end
    for k in pairs(roster) do roster[k] = nil; end
    for k in pairs(firstCount) do firstCount[k] = nil; end
    for k in pairs(byFull) do byFull[k] = nil; end
    E.stats = { joinFrames = 0, joinAmbig = 0, healLinks = 0, dmgLinks = 0, contradictions = 0, meterReads = 0, revokes = 0 };
    E.dmClass = {}; -- [forever.5] class-level meter vote for enemy classes with more than one player
    E.dmK = {}; -- [forever.10] per enemy class: sticky proven minimum healers / DPS, druid form exclusions, players
end
E.reset();

---------------------------------------------------------------------------------------------------- roster
-- full: clear scoreboard name ("First Surname"), classToken clear, isFriend boolean
function E.rosterAdd(full, classToken, isFriend)
    local first = firstWord(full);
    if not first or type(isFriend) ~= "boolean" then return; end
    local k = key(isFriend, first);
    local ro = roster[k];
    if not ro then
        roster[k] = { full = full, class = classToken, isFriend = isFriend, first = first };
        firstCount[first] = (firstCount[first] or 0) + 1;
    elseif ro.full ~= full then
        ro.ambiguous = true; -- duplicate guard: two players of one side share this first name -> never joined
    elseif classToken and not ro.class then
        ro.class = classToken;
    end
    -- [Forever] D5b: exact entry by full scoreboard name
    local kf = key(isFriend, full);
    local rf = byFull[kf];
    if not rf then
        byFull[kf] = { full = full, class = classToken, isFriend = isFriend, first = first };
    elseif classToken and not rf.class then
        rf.class = classToken;
    end
    local r = R[k];
    if r then E.evaluate(r, GetTime()); end
    r = R[kf];
    if r then E.evaluate(r, GetTime()); end
end

-- who: a full scoreboard name ("First Surname", exact) or a bare first name (unique-only join)
local function rosterRec(isFriend, who)
    if not who then return nil; end
    if who:find(" ", 1, true) then return byFull[key(isFriend, who)]; end
    local ro = roster[key(isFriend, who)];
    if ro and not ro.ambiguous then return ro; end
end
E.rosterRec = rosterRec;

-- [Forever] D5b: the join key of a unit from UnitName's two (clear) returns: "First Surname" when a realm/surname is
-- returned, else the bare first word. Secret or missing name -> nil.
function HHTD.MN_UnitWho(name, realm)
    local first = firstWord(name);
    if not first then return nil; end
    realm = str(realm);
    if realm and realm ~= "" then return first .. " " .. realm; end
    return first;
end

-- class token for a (side, plate first name), nil if unknown or ambiguous
function HHTD.MN_RosterClass(isFriend, first) local ro = rosterRec(isFriend, first); return ro and ro.class or nil; end
function HHTD.MN_RosterFull(isFriend, first)  local ro = rosterRec(isFriend, first); return ro and ro.full or nil; end

-- Key for HHTD.MN_HealersByName: the first word when it is unique among ALL scoreboard rows (K.T.H.'s friendly
-- nameplate lookup is by plate name, which is first-name-only on Forever), else the full scoreboard name (no join).
function HHTD.MN_ShortKey(full)
    local first = firstWord(full);
    if first and firstCount[first] == 1 and (rosterRec(true, first) or rosterRec(false, first)) then
        return first;
    end
    return full:match("^([^-]+)") or full;
end

-- Reads every scoreboard row (name, classToken, faction: clear in every BG phase per the diag).
function HHTD.MN_RosterSweep()
    if not inBG then return; end -- [Forever] F7: scoreboard join in battlegrounds only
    if not (C_PvP and C_PvP.GetScoreInfo) then return; end
    local n = num(GetNumBattlefieldScores and GetNumBattlefieldScores()) or 0;
    local pf = HHTD.Constants.PLAYER_FACTION;
    for i = 1, n do
        local ok, info = pcall(C_PvP.GetScoreInfo, i);
        if ok and type(info) == "table" and FS.clear(info) then
            local name, cls, fac = str(info.name), str(info.classToken), num(info.faction);
            if name and fac then
                local isFriend = (pf == "Horde" and fac == 0) or (pf == "Alliance" and fac == 1) or false;
                E.rosterAdd(name, cls, isFriend);
                -- [forever.7] talentSpec: secret in prep/gates/combat, clear post-match (FD run 18, KTH diags)
                local kind = E.specKindFromName(cls, info.talentSpec);
                if kind then E.setSpec(isFriend, name, kind, "scoreboard spec " .. tostring(str(info.talentSpec)), str(info.talentSpec)); end
            end
        end
    end
end

-- [Forever] F3: mouseover/target hostile-player UnitGUID is secret (ForeverDump runs 16-18, every phase), so
-- HHTD:TestUnit's GUID registry lookup never matches an enemy and HHTD_HEALER_MOUSE_OVER / HHTD_TARGET_LOCKED (and
-- their sounds) never fire. UnitName (both returns) and UnitCanAttack are clear on those tokens (same captures).
-- Resolve the enemy unit to K.T.H.'s own registry record by its exact scoreboard name; if K.T.H. has no record but its
-- nameplate rule marks the unit (the icon the user sees), hand back a record for that unit so the announcer reacts
-- to the same healers the nameplates show. Enemies only: friendly GUIDs are clear and keep the original path.
local plateRecords = {};
function HHTD.MN_ResolveEnemyUnit(unit)
    local okA, canAttack = pcall(UnitCanAttack, "player", unit);
    if not (okA and bool(canAttack)) then return nil; end
    local okN, name, realm = pcall(UnitName, unit);
    local who = okN and HHTD.MN_UnitWho(name, realm) or nil;
    if not who then return nil; end
    local full = HHTD.MN_RosterFull(false, who) or (who:find(" ", 1, true) and who) or nil;
    local reg = HHTD.Registry_by_Name and HHTD.Registry_by_Name[false];
    local rec = reg and full and reg[full] or nil;
    if rec and rec.guid then return rec.guid, rec; end
    if HHTD.MN_CheckUnitIsHealer then
        local ok, isHealer = pcall(HHTD.MN_CheckUnitIsHealer, unit);
        if ok and isHealer == true then
            local g = "Plate-E-" .. (full or who);
            local pr = plateRecords[g];
            if not pr then pr = { guid = g, name = full or who, isFriend = false }; plateRecords[g] = pr; end
            return g, pr;
        end
    end
    return nil;
end

---------------------------------------------------------------------------------------------------- engine
local function get(isFriend, first)
    local k = key(isFriend, first);
    local r = R[k];
    if not r then
        r = { key = k, isFriend = isFriend, first = first, heal = 0, dmg = 0, casts = 0 };
        R[k] = r;
    end
    return r;
end
E.get = get;

local function notify(r)
    if r.claim ~= "HEALER" or r.notified then return; end
    r.notified = true;
    local full = HHTD.MN_RosterFull(r.isFriend, r.first) or r.first;
    r.regGuid = "Scoreboard-" .. full;
    if HHTD._MN_RegisterHealer and HHTD.db then
        pcall(HHTD._MN_RegisterHealer, GetTime(), r.isFriend, r.regGuid, full, true,
            "heal evidence", false, 0, HHTD.db.global, true);
    end
    if HHTD.MN_OnEvidence then HHTD.MN_OnEvidence(); end
    if E.onClaim then pcall(E.onClaim, r); end
    pcall(E.debugVerdict, r, "on");
end

-- [forever.5] hysteresis: a claim is withdrawn only on clear contrary evidence (see CFG); K.T.H.'s registry record goes too
local function revoke(r, t, why)
    r.claim, r.notified, r.offT, r.offWhy = nil, nil, t, why;
    r.offs = (r.offs or 0) + 1; E.stats.revokes = E.stats.revokes + 1;
    pcall(E.debugVerdict, r, "off");
    if r.regGuid and HHTD.Reap then pcall(HHTD.Reap, HHTD, r.regGuid, r.isFriend, true); end
    if HHTD.MN_OnEvidence then HHTD.MN_OnEvidence(); end
end

-- +1 healer, -1 not a healer, 0 not enough evidence (actions: heal links vs damage links, plus clear heal spells)
local function actVote(r, cls)
    local cfg = E.cfg;
    local n = r.heal + r.dmg;
    local healPct = E.thresholds(cls, r.specName);
    if r.heal >= (cls and cfg.healMin or cfg.unknownHealMin) and r.heal * 100 >= healPct * n
        and (cfg.linkNet <= 0 or r.heal - r.dmg >= cfg.linkNet) then return 1; end
    if n >= cfg.offMin and r.heal * 100 < cfg.offPct * n then return -1; end
    return 0;
end
E.actVote = actVote;

-- [forever.10] eliminated = cannot be one of the class's proven healers: druid form exclusion, a readable DPS spec, a
-- decisive link vote against, or damage links with no heal link at all.
local function eliminated(K, ro)
    if K.excl and K.excl[ro.full] then return true; end
    local x = R[key(false, ro.full)] or R[key(false, ro.first or "")];
    if not x then return false; end
    if x.spec == "DPS" then return true; end
    if x.dmg >= 1 and x.heal == 0 then return true; end
    return actVote(x, ro.class) == -1;
end
-- the class's meter rows prove >= K.kmin healers; if at most that many players are left after elimination, they are it
function E.elimCandidate(K, me, cls)
    if not me then return false; end
    local left, mine = 0, false;
    for _, ro in ipairs(K.players) do
        if not eliminated(K, ro) then left = left + 1; if ro == me or ro.full == me.full then mine = true; end end
    end
    return mine and left >= 1 and left <= K.kmin;
end
-- [forever.10] plate power samples (UnitPowerType token on the caster's / combat unit's token; clear on hostile plates)
function E.formShare(r)
    if not r or not r.pw or (r.pwN or 0) < E.cfg.formMin then return nil; end
    return ((r.pw.RAGE or 0) + (r.pw.ENERGY or 0)) / r.pwN;
end
-- [forever.10] min / max number of healers consistent with n players and the class's anonymous heal / damage rows:
-- every assignment of damage rows to heal rows (missing rows = 0); healer = heal >= dmMin and share >= dmSharePct.
function E.kRange(n, hl, dl, cls)
    local cfg = E.cfg;
    local _, dmSharePct, _, kSharePct = E.thresholds(cls, nil);
    if n > cfg.kMaxN or #hl > n or #dl > n then return nil; end
    local H, D = {}, {};
    for i = 1, n do H[i] = hl[i] or 0; D[i] = dl[i] or 0; end
    -- kmin counts a row as a healer only with a margin (kSharePct: positive evidence; run 18's DPS druid Joff paired at
    -- 60.05%); kmax with the plain dmSharePct (proven non-healers stay as few as possible)
    local used, kmin, kmax = {}, n + 1, -1;
    local function rec(i, a, b)
        if i > n then if a < kmin then kmin = a; end if b > kmax then kmax = b; end return; end
        for j = 1, n do
            if not used[j] then
                used[j] = true;
                local h, d = H[i], D[j];
                local big = h >= cfg.dmMin;
                rec(i + 1, a + ((big and h * 100 >= kSharePct * (h + d)) and 1 or 0),
                    b + ((big and h * 100 >= dmSharePct * (h + d)) and 1 or 0));
                used[j] = false;
            end
        end
    end
    rec(1, 0, 0);
    return kmin, kmax;
end

function E.evaluate(r, t)
    local cfg = E.cfg;
    local ro = rosterRec(r.isFriend, r.first);
    local cls = ro and ro.class or nil;
    if cls and not E.HEALER_CLASS[cls] then
        if r.heal >= cfg.healMin and not r.contradicted then
            r.contradicted = true; E.stats.contradictions = E.stats.contradictions + 1;
        end
        if r.claim then revoke(r, t, "class cannot heal"); end
        return;
    end
    local a = actVote(r, cls);
    local d = r.dmVote or 0;
    local K = (cls and not r.isFriend) and E.dmK[cls] or nil;
    local excluded = K and ro and K.excl and K.excl[ro.full] or false;
    if d == 0 and cls and not r.isFriend then
        local cv = E.dmClass[cls];
        if cv and cv.n > 1 then d = cv.v; end
        -- [forever.10] a read proved a non-healing druid and this one has the most bear/cat power: the class rule does not
        -- mark it (tie-break only: no revoke, no vote against; links / own meter row / spec still decide)
        if excluded and d == 1 then d = 0; end
    end
    -- measured amounts outrank link counts: a decisive meter vote decides; links decide only while the meter has none
    -- (run 17: two friendly DPS with 2-6 coincidental heal links and a meter heal share of 9-18 percent)
    local v = (d ~= 0) and d or a;
    local weak = false;
    -- [forever.7] spec layer (authoritative when readable): a readable healer spec, or a cast of a verified healer-only
    -- spell (which sets the spec for this name for the rest of the match), marks at once and overrides every heuristic;
    -- a readable non-healer spec (arena/inspect/scoreboard spec ID or name, never a self-chosen group role) unmarks.
    -- Absence of a spec or of healer-only casts never counts against anyone (low-level healers lack the talents/runes).
    if r.spec == "HEALER" then v = 1; elseif r.spec == "DPS" then v = -1; end
    if v == 0 and cls and not r.isFriend then
        local cv = E.dmClass[cls];
        local proven = (cfg.kWeak > 0) and (K and K.kmin >= cfg.kWeak) or (cfg.kWeak <= 0 and cv and cv.possible);
        if cv and cv.n > 1 and cv.v == 0 and proven and r.heal >= cfg.weakLinkMin and r.dmg == 0 and not excluded then
            v, weak = 1, true;
        end
        if v == 0 and cfg.elim == 1 and K and K.kmin >= 1 and K.players and #K.players > 1 and not excluded then
            if E.elimCandidate(K, ro, cls) then v, weak = 1, "elim"; end
        end
    end
    local on = (v == 1);
    if not r.claim and on then
        r.claim, r.claimT = "HEALER", t;
        r.firstClaimT = r.firstClaimT or t;
        r.why = (r.spec == "HEALER") and ("spec " .. tostring(r.specWhy)) or (weak == "elim") and ("meter min " .. tostring(K and K.kmin) .. " " .. tostring(cls) .. " healer(s), others eliminated") or weak and ("meter-proven " .. tostring(cls) .. " + heal-links " .. r.heal .. "/" .. (r.heal + r.dmg)) or (d == 1) and ("meter " .. tostring(r.dmVote and r.dmWhy or ("class " .. tostring(cls)))) or ("heal-links " .. r.heal .. "/" .. (r.heal + r.dmg));
        notify(r);
    elseif r.claim and v == -1 then
        revoke(r, t, (r.spec == "DPS") and ("spec " .. tostring(r.specWhy)) or (d == -1) and ("meter " .. tostring(r.dmWhy)) or ("heal-links " .. r.heal .. "/" .. (r.heal + r.dmg)));
    end
end

-- one client frame: casters (key -> rec), heals / wounds = lists of target recs
function E.join(t, casters, nCasters, heals, wounds)
    if nCasters == 0 then return; end
    E.stats.joinFrames = E.stats.joinFrames + 1;
    if nCasters > 1 then E.stats.joinAmbig = E.stats.joinAmbig + 1; return; end
    local c;
    for _, r in pairs(casters) do c = r; end
    c.casts = c.casts + 1;
    local healed, hurt = false, false;
    for _, tr in ipairs(heals) do if tr ~= c and tr.isFriend == c.isFriend then healed = true; end end
    for _, tr in ipairs(wounds) do if tr.isFriend ~= c.isFriend then hurt = true; end end
    if healed then c.heal = c.heal + 1; c.healT1 = c.healT1 or t; E.stats.healLinks = E.stats.healLinks + 1; end
    if hurt then c.dmg = c.dmg + 1; E.stats.dmgLinks = E.stats.dmgLinks + 1; end
    if healed or hurt then E.evaluate(c, t); end
end

-- nameplate check: is this (side, plate first name) confirmed by heal evidence?
function HHTD.MN_EvidenceConfirmed(isFriend, first)
    if not first then return false; end
    local r = R[key(isFriend, first)];
    if not r and first:find(" ", 1, true) then
        -- [forever.5] plate gave "First Surname" but the evidence was keyed by the bare first name (no realm returned
        -- at that time): same player only when that first name is unique on this side
        local f1 = firstWord(first); local ro = f1 and roster[key(isFriend, f1)];
        if ro and not ro.ambiguous and ro.full == first then r = R[key(isFriend, f1)]; end
    elseif not r then
        -- bare first name on the plate, evidence keyed by the full name (meter rows, raid tokens): unique first name only
        local ro = rosterRec(isFriend, first);
        if ro and ro.full then r = R[key(isFriend, ro.full)]; end
    end
    return (r and r.claim == "HEALER" and not (roster[r.key] and roster[r.key].ambiguous)) and true or false; -- byFull keys are never ambiguous
end

---------------------------------------------------------------------------------------------------- driver
local identCache, identT = {}, -1;

local function call(f, ...)
    if type(f) ~= "function" then return; end
    local ok, a, b = pcall(f, ...);
    if ok then return a, b; end
end

local function ident(tok)
    tok = str(tok);
    if not tok then return nil; end
    local t = GetTime();
    if t ~= identT then identT = t; for k in pairs(identCache) do identCache[k] = nil; end end
    local c = identCache[tok];
    if c ~= nil then return c or nil; end
    local rec = false;
    if bool(call(UnitIsPlayer, tok)) and not bool(call(UnitIsUnit, tok, "player")) then
        local first = HHTD.MN_UnitWho(call(UnitName, tok)); -- [Forever] D5b: "First Surname" when the realm is returned
        local enemy = bool(call(UnitCanAttack, "player", tok));
        if first and enemy ~= nil then rec = get(not enemy, first); end
    end
    identCache[tok] = rec;
    return rec or nil;
end
E.ident = ident;

local B = { t = nil, casters = {}, n = 0, heals = {}, wounds = {} };
local function flush()
    if B.t and B.n > 0 then E.join(B.t, B.casters, B.n, B.heals, B.wounds); end
    B.t = nil; B.n = 0;
    for k in pairs(B.casters) do B.casters[k] = nil; end
    for i = #B.heals, 1, -1 do B.heals[i] = nil; end
    for i = #B.wounds, 1, -1 do B.wounds[i] = nil; end
end
E.flush = flush;
local function bucket()
    local t = GetTime();
    if B.t ~= t then flush(); B.t = t; end
    return t;
end

local function samplePower(rec, tok) -- [forever.10] druid form tie-break input
    local _, p = call(UnitPowerType, tok);
    p = str(p);
    if p == "MANA" or p == "RAGE" or p == "ENERGY" then rec.pw = rec.pw or {}; rec.pw[p] = (rec.pw[p] or 0) + 1; rec.pwN = (rec.pwN or 0) + 1; end
end
function E.onCast(tok)
    if not active then return; end
    local rec = ident(tok);
    if not rec then return; end
    if not rec.isFriend then samplePower(rec, tok); end
    bucket();
    if not B.casters[rec.key] then B.casters[rec.key] = rec; B.n = B.n + 1; end
end

function E.onCombat(tok, action)
    if not active then return; end
    action = str(action);
    if action ~= "HEAL" and action ~= "WOUND" then return; end
    local rec = ident(tok);
    if not rec then return; end
    if not rec.isFriend then samplePower(rec, tok); end
    bucket();
    local L = (action == "HEAL") and B.heals or B.wounds;
    for _, r in ipairs(L) do if r == rec then return; end end
    L[#L + 1] = rec;
end

-- [forever.5] a clear healer-only spellID cast by this unit (open world / PvE, where spellIDs read clear; nameplate
-- spellIDs are secret in BGs): one heal action toward the verdict, no longer a mark on its own
function E.onHealSpell(tok)
    if not active then return; end
    local rec = ident(tok);
    if not rec then return; end
    rec.heal = rec.heal + 1; rec.spellHeals = (rec.spellHeals or 0) + 1;
    E.evaluate(rec, GetTime());
end

-- [forever.8] healer-only spells = the USER'S authoritative list (domain knowledge), one spec per spell:
--   Discipline priest: Penance, Power Infusion | Holy priest: Prayer of Mending | Holy paladin: Light's Vigil |
--   Restoration druid: Wild Growth | Restoration shaman: Riptide.
-- IDs: every Forever 1.60.1 SpellName row with that exact name (FD DB2 build 1.60.1.70245 == wago.tools 1.60.1.70245;
-- ranks confirmed on wowhead.com/forever), minus rows that are not the ability: the SoD rune-learning spells
-- ("Gain the X ability": 402844, 402832, 409810, 409954) and Riptide 22419 ("Disarmed", an NPC spell sharing the name).
-- Seen in the combat logs of runs 1-18: only Penance 402284 (damage) / 402289 (heal), as SPELL_CAST_SUCCESS; the
-- other five spells were never cast in our captures. Known disagreement: Penance was cast by Severn (run 15, log heal
-- share 0.107, 19 casts), whom our log label calls DPS; the user accepts Penance (likely a Discipline priest dealing damage).
-- Swiftmend and Holy Shock are no longer instant flags (user); they stay ordinary heal evidence via the retail lookup.
-- Live use needs a clear spellID: in every FD capture (runs 6-18) other units' UNIT_SPELLCAST spellIDs were secret.
E.HEALER_ONLY_SPELLS = {};
do
    local L = {
        { "Penance", "Discipline", 402174, 402261, 402277, 402284, 402289, 1240720, 1240721, 1240723, 1240724, 1240727,
          1240730, 1240732, 1240733, 1240734, 1240736, 1316991, 1316992, 1316993, 1316994, 1316995 },
        { "Power Infusion", "Discipline", 10060 },
        { "Prayer of Mending", "Holy", 41637, 401859, 401863, 401877, 401880, 401882, 1240826, 1240827, 1240848, 1240849,
          1240918, 1240919, 1313379, 1313381 },
        { "Light's Vigil", "Holy", 1310909, 1310910, 1310911, 1310912, 1310914, 1311590, 1311591, 1311592, 1311593,
          1311594, 1311595, 1311596, 1311597, 1311598, 1311599, 1311601, 1311806 },
        { "Wild Growth", "Restoration", 408120, 1238214, 1238215 },
        { "Riptide", "Restoration", 405168, 405194, 405321, 405324, 408521, 1239242, 1239243 },
    };
    for _, e in ipairs(L) do
        for i = 3, #e do E.HEALER_ONLY_SPELLS[e[i]] = e[1]; end
    end
    E.HEALER_ONLY_SPEC = { ["Penance"] = "Discipline", ["Power Infusion"] = "Discipline", ["Prayer of Mending"] = "Holy",
        ["Light's Vigil"] = "Holy", ["Wild Growth"] = "Restoration", ["Riptide"] = "Restoration" };
end
function E.onHealerOnlySpell(tok, spellID)
    if not active then return; end
    local rec = ident(tok);
    if not rec then return; end
    rec.specSpell = rec.specSpell or E.HEALER_ONLY_SPELLS[spellID] or tostring(spellID);
    rec.specSpellT = rec.specSpellT or GetTime();
    E.setSpec(rec.isFriend, rec.first, "HEALER", "healer-only spell " .. rec.specSpell
        .. " (" .. tostring(E.HEALER_ONLY_SPEC[rec.specSpell] or "?") .. ")", E.HEALER_ONLY_SPEC[rec.specSpell]);
end

-- [forever.7] spec shortcut. kind = "HEALER" | "DPS"; who = exact "First Surname" when known (else unique first name).
-- Healer specs: Discipline / Holy priest, Holy paladin, Restoration druid, Restoration shaman.
E.HEALER_SPEC_ID = { [256] = true, [257] = true, [65] = true, [105] = true, [264] = true };
E.SPEC_ID_NAME = { [256] = "Discipline", [257] = "Holy", [65] = "Holy", [105] = "Restoration", [264] = "Restoration" }; -- forever.11
E.HEALER_SPEC_NAME = { PRIEST = { Discipline = true, Holy = true }, PALADIN = { Holy = true },
                       DRUID = { Restoration = true }, SHAMAN = { Restoration = true } };
-- [run19 fix] only a known non-healer spec NAME counts as DPS. Forever's post-match GetScoreInfo().talentSpec returned
-- the CLASS name ("Priest", "Druid", "Paladin": run 19 KTH debug log, 10:40:27) and the old "anything else = DPS" rule
-- unmarked every healer on the final scoreboard. Unknown / class-name values are no evidence either way.
E.DPS_SPEC_NAME = { PRIEST = { Shadow = true }, PALADIN = { Protection = true, Retribution = true },
                    DRUID = { Balance = true, Feral = true, ["Feral Combat"] = true, Guardian = true },
                    SHAMAN = { Elemental = true, Enhancement = true } };
-- specName (forever.11, optional): the spec's English name when the source gives it (scoreboard talentSpec, healer-only
-- spell's spec, arena spec ID); used only to pick a per-spec healer-threshold override.
function E.setSpec(isFriend, who, kind, src, specName)
    if type(who) ~= "string" or (kind ~= "HEALER" and kind ~= "DPS") then return; end
    local r = get(isFriend, who);
    if type(specName) == "string" and specName ~= "" then r.specName = specName; end
    if r.spec == "HEALER" and kind ~= "HEALER" and r.specWhy and r.specWhy:find("healer-only spell", 1, true) then
        return; -- an observed healer-only cast is proof; keep it for the match
    end
    if r.spec ~= kind then r.spec, r.specWhy, r.specT = kind, src, GetTime(); E.evaluate(r, GetTime()); end
end
-- spec ID (arena opponent spec, inspect) -> kind; role from GetSpecializationInfoByID when the client provides it
function E.specKindFromID(id)
    id = num(id);
    if not id or id <= 0 then return nil; end
    local f = GetSpecializationInfoByID;
    if type(f) == "function" then
        local ok, _, _, _, _, role = pcall(f, id);
        role = ok and str(role) or nil;
        if role == "HEALER" then return "HEALER"; elseif role == "DAMAGER" or role == "TANK" then return "DPS"; end
    end
    return E.HEALER_SPEC_ID[id] and "HEALER" or nil; -- unknown non-healer IDs are not treated as DPS
end
-- scoreboard talentSpec (measured clear only post-match) -> kind
function E.specKindFromName(cls, spec)
    spec = str(spec);
    if not spec or spec == "" or not cls then return nil; end
    local h = E.HEALER_SPEC_NAME[cls];
    if h and h[spec] then return "HEALER"; end
    local d = E.DPS_SPEC_NAME[cls];
    if d and d[spec] then return "DPS"; end
    return nil;
end
-- arena opponents: GetArenaOpponentSpec(i) (no arena capture yet: every value is read through the clear guard)
function E.readArenaSpecs()
    if not active or zoneKind ~= "arena" then return; end
    local n = num(call(GetNumArenaOpponentSpecs)) or 0;
    for i = 1, math.min(n, 5) do
        local id = call(GetArenaOpponentSpec, i);
        local kind = E.specKindFromID(id);
        local who = kind and HHTD.MN_UnitWho(call(UnitName, "arena" .. i)) or nil;
        if who then E.setSpec(false, who, kind, "arena opponent spec", E.SPEC_ID_NAME[num(id) or 0]); end
    end
end
-- friendly group: UnitGroupRolesAssigned == "HEALER" (positive only: a role is chosen in the queue, not a spec)
function E.readGroupRoles()
    if not active then return; end
    local raid = bool(call(IsInRaid));
    local n = num(call(GetNumGroupMembers)) or 0;
    for i = 1, math.min(n, 40) do
        local u = raid and ("raid" .. i) or ("party" .. i);
        if not raid and i > 4 then break; end
        if not bool(call(UnitIsUnit, u, "player")) then
            local role = str(call(UnitGroupRolesAssigned, u));
            if role == "HEALER" then
                local who = HHTD.MN_UnitWho(call(UnitName, u));
                if who then E.setSpec(true, who, "HEALER", "group role"); end
            end
        end
    end
end

---------------------------------------------------------------------------------------------------- meter
-- [forever.5] C_DamageMeter, Current session, HealingDone vs DamageDone. Measured in FD runs 16-18 (FOREVER-PORT.md):
-- out of combat totalAmount/classFilename/sourceDisplayType are clear, friendly name/GUID clear, enemy name/GUID secret;
-- in combat the amounts are secret (documented SecretWhenInCombat). Read on PLAYER_REGEN_ENABLED, as FD did.
local function meterRows(D, cur, ty)
    if ty == nil then return nil; end
    local ok, s = pcall(D.GetCombatSessionFromType, cur, ty);
    if not ok or type(s) ~= "table" then return nil; end
    local list = {};
    local okR = pcall(function()
        local src = s.combatSources;
        if type(src) ~= "table" then return; end
        for i = 1, 80 do
            local row = src[i];
            if type(row) ~= "table" then break; end
            local amt = num(row.totalAmount);
            if amt then
                list[#list + 1] = { amt = amt, name = str(row.name), cls = str(row.classFilename),
                    dt = num(row.sourceDisplayType), me = bool(row.isLocalPlayer) };
            end
        end
    end);
    if not okR then return nil; end
    return list;
end

local function meterVote(r, h, d, med, t)
    local cfg = E.cfg;
    local hi = med > 0 and h >= cfg.dmMedianX * med;
    local ro = rosterRec(r.isFriend, r.first);
    local _, dmSharePct = E.thresholds(ro and ro.class or nil, r.specName);
    local v;
    if h >= cfg.dmMin and (h * 100 >= dmSharePct * (h + d) or hi) then v = 1;
    elseif (h + d) >= cfg.dmOffMin and h * 100 < cfg.dmOffPct * (h + d) and not hi then v = -1; end
    r.dmH, r.dmD, r.dmMed = h, d, med;
    if v then r.dmVote, r.dmT, r.dmWhy = v, t, "heal " .. h .. " dmg " .. d .. " median " .. med; end
    E.evaluate(r, t);
end

-- [forever.7] debug collection (SavedVariables HHTD_SavedVariables -> global.ForeverDebug): EVERY meter read with its
-- raw clear rows (class, sourceDisplayType, amount, friendly name; enemy names are secret and are not readable), and
-- every claim / revoke with its reason. Gives future backtests every read K.T.H. made (the ForeverDump ring kept only
-- 21 per BG). Bounded: last 5 sessions, 400 reads and 400 verdict changes each. /kthdebug off|on|clear.
local dbg;
local function debugRoot()
    local g = HHTD.db and HHTD.db.global;
    if type(g) ~= "table" then return nil; end
    if HHTD.KTH_DebugOn then if not HHTD.KTH_DebugOn() then return nil; end elseif g.ForeverDebugOff then return nil; end -- forever.11
    g.ForeverDebug = type(g.ForeverDebug) == "table" and g.ForeverDebug or { sessions = {} };
    return g.ForeverDebug;
end
function E.debugSession(kind)
    local root = debugRoot();
    if not root then dbg = nil; return; end
    dbg = { start = (time and time()) or 0, gt = GetTime(), zone = kind, meter = {}, verdicts = {} };
    table.insert(root.sessions, dbg);
    while #root.sessions > 5 do table.remove(root.sessions, 1); end
end
function E.debugMeter(t, H, Dm)
    if not dbg or #dbg.meter >= 400 then return; end
    local function pack(L)
        local out = {};
        for _, x in ipairs(L) do out[#out + 1] = { c = x.cls, d = x.dt, a = x.amt, n = x.name, me = x.me or nil }; end
        return out;
    end
    dbg.meter[#dbg.meter + 1] = { t = t, h = pack(H), dm = pack(Dm) };
end
function E.debugVerdict(r, what)
    if not dbg or #dbg.verdicts >= 400 then return; end
    dbg.verdicts[#dbg.verdicts + 1] = { t = GetTime(), k = r.key, v = what, why = (what == "on") and r.why or r.offWhy,
        heal = r.heal, dmg = r.dmg, casts = r.casts };
end

function E.readMeter()
    if not active then return; end
    local D, EN = C_DamageMeter, Enum;
    local MT = EN and EN.DamageMeterType;
    local ST = EN and EN.DamageMeterSessionType;
    if not (type(D) == "table" and type(D.GetCombatSessionFromType) == "function" and type(MT) == "table") then return; end
    local cur = (type(ST) == "table" and num(ST.Current)) or 1; -- ForeverDump reads the same session
    local H, Dm = meterRows(D, cur, MT.HealingDone), meterRows(D, cur, MT.DamageDone);
    if not (H and Dm) or #H == 0 then return; end
    local t = GetTime();
    E.stats.meterReads = E.stats.meterReads + 1;
    pcall(E.debugMeter, t, H, Dm);
    local hs = {};
    for _, x in ipairs(H) do hs[#hs + 1] = x.amt; end
    table.sort(hs);
    local m = #hs;
    local med = (m % 2 == 1) and hs[(m + 1) / 2] or (hs[m / 2] + hs[m / 2 + 1]) / 2;
    -- friendly rows: clear name ("First Surname"); enemy rows: secret name, clear class, sourceDisplayType ~= 1
    local fH, fD, eH, eD = {}, {}, {}, {};
    local function add(x, F, Ecl)
        if x.me or not x.cls then return; end
        if x.name then F[x.name] = (F[x.name] or 0) + x.amt;
        elseif x.dt ~= 1 then local l = Ecl[x.cls] or {}; Ecl[x.cls] = l; l[#l + 1] = x.amt; end
    end
    for _, x in ipairs(H) do add(x, fH, eH); end
    for _, x in ipairs(Dm) do add(x, fD, eD); end
    for name, h in pairs(fH) do if firstWord(name) then meterVote(get(true, name), h, fD[name] or 0, med, t); end end
    for name, d in pairs(fD) do if not fH[name] and firstWord(name) then meterVote(get(true, name), 0, d, med, t); end end
    if not inBG then return; end -- enemy rows can only be joined through the BG scoreboard (class)
    local byClass = {};
    for _, ro in pairs(byFull) do
        if not ro.isFriend and ro.class then local l = byClass[ro.class] or {}; byClass[ro.class] = l; l[#l + 1] = ro; end
    end
    local cfg = E.cfg;
    for cls, players in pairs(byClass) do
        local hl, dl = eH[cls] or {}, eD[cls] or {};
        local n = #players;
        if n == 1 then
            if (#hl > 0 or #dl > 0) and #hl <= 1 and #dl <= 1 then meterVote(get(false, players[1].full), hl[1] or 0, dl[1] or 0, med, t); end
        else
            -- several enemies of this class: the rows cannot be told apart (secret names). forever.5 rules (every row far
            -- above the group median / every one did real damage and none healed much) plus the forever.6 class-share rules.
            local q = 0;
            local sh, sd, dmin = 0, 0, nil;
            for _, d in ipairs(dl) do sd = sd + d; if not dmin or d < dmin then dmin = d; end end
            if #dl < n then dmin = 0; end -- some player may have no damage row
            local possible = false;
            local _, dmSharePct, grpSharePct = E.thresholds(cls, nil); -- anonymous rows: class-level setting
            for _, h in ipairs(hl) do
                sh = sh + h;
                if h >= cfg.dmMin and med > 0 and h >= cfg.dmMedianX * med then q = q + 1; end
                if h >= cfg.dmMin and h * 100 >= dmSharePct * (h + (dmin or 0)) then possible = true; end
            end
            -- [forever.10] proven healer / DPS counts (sticky over the match: each read is one combat segment)
            local K = E.dmK[cls] or { kmin = 0, minDPS = 0 };
            E.dmK[cls] = K;
            K.players = players;
            local hs, ds = {}, {};
            for i, h in ipairs(hl) do hs[i] = h; end
            for i, d in ipairs(dl) do ds[i] = d; end
            local km, kx = E.kRange(n, hs, ds, cls);
            if km and km > K.kmin then K.kmin = km; end
            K.minDPS = kx and (n - kx) or 0; -- this read only: players that cannot have been healing in this segment
            K.excl = K.excl or {}; -- sticky: once the top bear/cat druid, never class-marked in this match
            if cls == "DRUID" and cfg.formTie == 1 and K.minDPS > 0 then
                local L = {};
                for _, ro in ipairs(players) do L[#L + 1] = { ro = ro, f = E.formShare(R[key(false, ro.full)]) }; end
                table.sort(L, function(a, b) return (a.f or -1) > (b.f or -1); end);
                for i = 1, math.min(K.minDPS, n - 1) do
                    local x, y = L[i], L[i + 1];
                    if x and x.f and (not y or not y.f or (x.f - y.f) * 100 >= cfg.formGap) then K.excl[x.ro.full] = true;
                    else break; end
                end
            end
            local ne = n; -- the all-healers rule still needs every row (the tie-break only removes a druid from the marks)
            local v;
            if q >= ne or (#hl >= ne and sh >= cfg.dmMin * ne and sh * 100 >= grpSharePct * (sh + sd)) then v = 1;
            elseif #dl >= n and not possible and dmin >= cfg.dmOffMin then
                v = -1; -- every player of the class did >= dmOffMin damage and no heal row can reach dmSharePct
            end
            if v == nil and possible then v = 0; end
            if v then
                local prev = E.dmClass[cls];
                -- hysteresis: an ambiguous read never clears an earlier decisive class vote
                if v ~= 0 or not (prev and prev.v ~= 0) then
                    E.dmClass[cls] = { v = v, n = n, t = t, possible = possible, share = (sh + sd) > 0 and sh / (sh + sd) or nil };
                end
            end
            for _, ro in ipairs(players) do E.evaluate(get(false, ro.full), t); end
        end
    end
end

-- [Forever] F7 (user directive: the port must also work in arena, world, party, dungeons, raids):
--   * the scoreboard join (roster, D5/D5b) and D6 apply in battlegrounds only (the only measured scoreboard; in arenas
--     GetScoreInfo().faction is the team, not Horde/Alliance, and no arena capture exists yet);
--   * everywhere else the original K.T.H. paths run unchanged (UnitClass when it is clear), and heal evidence (D7) is
--     the fallback when it is not: arena, open world (world PvP, no scoreboard), and party/raid instances when K.T.H.'s
--     own Pve option is on (K.T.H. ignores PvE healers otherwise);
--   * roster and evidence are reset whenever the zone (kind + instance id) changes.
function E.updateZone()
    local inInst, kind = call(IsInInstance);
    kind = (bool(inInst) and str(kind)) or "none";
    local okI, _, _, _, _, _, _, _, id = pcall(GetInstanceInfo); -- 8th return: instanceID
    id = okI and num(id) or 0;
    local was = (zoneKind == "pvp" or zoneKind == "arena");
    inBG = (kind == "pvp");
    zoneKind = kind;
    local pve = HHTD.db and HHTD.db.global and HHTD.db.global.Pve;
    active = inBG or kind == "arena" or kind == "none" or ((kind == "party" or kind == "raid" or kind == "scenario") and pve and true or false);
    local zk = kind .. ":" .. tostring(id);
    if zk ~= zoneKey then
        local first = (zoneKey == nil);
        zoneKey = zk;
        if not first then E.reset(); flush(); end
        if active then pcall(E.debugSession, kind); end -- [forever.7] one debug session per zone
    end
    if (inBG or kind == "arena") and not was then
        E.reset(); flush();
        -- [Forever] F5: K.T.H. never clears its scoreboard healer list; with D6 (post-match healers) the previous BG's
        -- healers would carry into this one (CLASS+SCORE would mark every enemy of their classes). New BG -> new list.
        for _, t in ipairs({ HHTD.MN_HealersByName, HHTD.MN_HealersByGUID, HHTD.MN_HealersByClassSpec }) do
            for k in pairs(t) do t[k] = nil; end
        end
        if HHTD.MN_HealerCount then HHTD.MN_HealerCount.enemy, HHTD.MN_HealerCount.friendly = 0, 0; end
        if HHTD.MN_OnEvidence then HHTD.MN_OnEvidence(); end
    end
end
function E.setInBG(v) inBG = v and true or false; active = inBG; zoneKind = inBG and "pvp" or "none"; end -- replay harness
function E.setZone(kind) zoneKind = kind; inBG = (kind == "pvp"); active = true; end -- mock tests

local frame = CreateFrame("Frame");
frame:SetScript("OnEvent", function(_, event, a1, a2)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then E.onCast(a1);
    elseif event == "UNIT_COMBAT" then E.onCombat(a1, a2);
    elseif event == "PLAYER_REGEN_ENABLED" then pcall(E.readMeter); -- [forever.5]
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then pcall(E.readGroupRoles); -- [forever.7]
    elseif event == "ARENA_PREP_OPPONENT_SPECIALIZATIONS" or event == "ARENA_OPPONENT_UPDATE" then pcall(E.readArenaSpecs);
    else E.updateZone(); pcall(E.readGroupRoles); end
end);
-- none of these is restricted on Forever (the diag and ForeverDump register them without ADDON_ACTION_FORBIDDEN)
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED");
frame:RegisterEvent("UNIT_COMBAT");
frame:RegisterEvent("PLAYER_ENTERING_WORLD");
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA");
frame:RegisterEvent("PLAYER_REGEN_ENABLED"); -- [forever.5] meter read (FD registered it in the same BGs)
-- [forever.7] spec sources; FD saw GROUP_ROSTER_UPDATE / PLAYER_ROLES_ASSIGNED / ARENA_OPPONENT_UPDATE fire on Forever
-- (run 18); ARENA_PREP_OPPONENT_SPECIALIZATIONS was never captured (no arena run), so it is registered under pcall.
for _, ev in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "ARENA_OPPONENT_UPDATE", "ARENA_PREP_OPPONENT_SPECIALIZATIONS" }) do
    pcall(frame.RegisterEvent, frame, ev);
end
E.frame = frame;

---------------------------------------------------------------------------------------------------- F6 plate log
-- [Forever] F6 (diagnostic only, no behaviour change): the forever.2 report "the nameplate icon sometimes shows,
-- sometimes not" could not be settled from the diag (no per-plate verdict was logged). In a BG, every 2 s, record each
-- enemy plate's verdict when it CHANGES for that player: {t, who, verdict, method, powerToken, roster class, icon
-- shown}. Kept in K.T.H.'s own SavedVariables (HHTD_SavedVariables.global.ForeverPlateLog, last 800 changes).
local lastVerdict = {};
local function plateLogTick()
    if not active or not (HHTD.db and HHTD.db.global and HHTD.MN_CheckUnitIsHealer) then return; end
    if HHTD.KTH_DebugOn and not HHTD.KTH_DebugOn() then return; end -- [forever.11] debug-only capture
    local log = HHTD.db.global.ForeverPlateLog;
    if type(log) ~= "table" then log = {}; HHTD.db.global.ForeverPlateLog = log; end
    local now = GetTime();
    if HHTD.MN_OnEvidence then HHTD.MN_OnEvidence(); end -- run K.T.H.'s own plate scan first so 'icon' is current
    -- F7 data for the next decision: arena readability is not captured yet. Once per arena and arenaN token, record
    -- whether name/realm/class/spec read clear ("C"), secret ("S") or nil ("N") - and the clear values.
    if zoneKind == "arena" then
        log.arena = log.arena or {};
        for i = 1, 5 do
            local tok = "arena" .. i;
            local k = zoneKey .. ":" .. tok;
            if not log.arena[k] and bool(call(UnitExists, tok)) then
                local function st(v) if v == nil then return "N"; end return FS.clear(v) ~= nil and "C" or "S"; end
                local okN, n, r = pcall(UnitName, tok);
                local okC, _, c = pcall(UnitClass, tok);
                local okS, spec = pcall(GetArenaOpponentSpec or function() end, i);
                local okG, g = pcall(UnitGUID, tok);
                log.arena[k] = { t = now, name = okN and st(n) or "E", realm = okN and st(r) or "E", class = okC and st(c) or "E",
                    spec = okS and st(spec) or "E", guid = okG and st(g) or "E",
                    vName = str(n), vRealm = str(r), vClass = str(c), vSpec = num(spec) };
            end
        end
    end
    for i = 1, 40 do
        local tok = "nameplate" .. i;
        if bool(call(UnitExists, tok)) and bool(call(UnitIsPlayer, tok)) and bool(call(UnitCanAttack, "player", tok)) then
            local who = HHTD.MN_UnitWho(call(UnitName, tok));
            if who then
                local ok, isHealer, _, method = pcall(HHTD.MN_CheckUnitIsHealer, tok);
                local v = (ok and isHealer == true) and (method or "?") or (ok and "no" or "err");
                if lastVerdict[who] ~= v then
                    lastVerdict[who] = v;
                    local _, ptok = call(UnitPowerType, tok);
                    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and call(C_NamePlate.GetNamePlateForUnit, tok);
                    local lvl = num(call(UnitLevel, tok)); -- [forever.7] level as context (FD: UnitLevel clear on hostile plates)
                    log[#log + 1] = { t = now, who = who, v = v, pwr = str(ptok), cls = HHTD.MN_RosterClass(false, who), lvl = lvl,
                        icon = HHTD.MN_PlateIconShown and HHTD.MN_PlateIconShown(plate) or false, tok = tok };
                    while #log > 800 do table.remove(log, 1); end
                end
            end
        end
    end
end
E.plateLogTick = plateLogTick;
if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(2, function() pcall(plateLogTick); end); end
