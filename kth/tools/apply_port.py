import sys; sys.path.insert(0,'tools')
from patch import sub
C='port/KTH/Core.lua'; M='port/KTH/MidnightNameplates.lua'; TOC='port/KTH/KTH.toc'

# D1 TOC
sub(TOC, '## Interface: 120000, 120001', '## Interface: 16001')
sub(TOC, '## Title: K.T.H. |cff888888(Kill The Healer)|r\n', '## Title: K.T.H. |cff888888(Kill The Healer)|r Forever\n')
sub(TOC, '## Version: 1.0.0-kth\n', '## Version: 1.0.0-kth-forever.2\n## X-Forever-Port: private port of K.T.H. 1.0.0-kth to WoW Forever 1.60.1 (toc 16001); every change is listed in FOREVER-PORT.md\n')
sub(TOC, 'Localization.lua\nCore.lua\n', 'Localization.lua\nForeverSafe.lua\nCore.lua\n')
sub(TOC, 'Announcer.lua', 'Announcer.lua\n\nForeverEvidence.lua\nForeverChat.lua')

# D2 Midnight path on Forever
sub(C, 'HHTD_C.MN = tocversion >= 120000\n',
'''HHTD_C.MN = tocversion >= 120000
-- [Forever] D2: WoW Forever (toc 16001, WOW_PROJECT_ID 18) has Midnight-style secrets. Baseline diag: MN=false sent K.T.H.
-- down the classic branch, whose RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") raised ADDON_ACTION_FORBIDDEN
-- (AceEvent30Frame:RegisterEvent) and the "blocked from an action only available to the Blizzard UI" popup;
-- CombatLogGetCurrentEventInfo and C_CombatLogInternal are both absent. So Forever takes the Midnight path.
HHTD_C.FOREVER = T.FS and T.FS.IS_FOREVER or false
if HHTD_C.FOREVER then HHTD_C.MN = true end
''')

# D3 /hhtd without AceConfigCmd chat output
sub(C, '''        LibStub("AceConfig-3.0"):RegisterOptionsTable(tostring(self), self.GetOptions, {"hhtd", "H.H.T.D."});
''', '''        if HHTD_C.FOREVER then
            -- [Forever] D3: AceConfigCmd answers /hhtd by printing into DEFAULT_CHAT_FRAME; open the options window instead
            LibStub("AceConfig-3.0"):RegisterOptionsTable(tostring(self), self.GetOptions);
            self:RegisterChatCommand('hhtd', function() LibStub("AceConfigDialog-3.0"):Open(tostring(self)) end, true);
        else
            LibStub("AceConfig-3.0"):RegisterOptionsTable(tostring(self), self.GetOptions, {"hhtd", "H.H.T.D."});
        end
''')

# D7 expose RegisterHealer for heal evidence
sub(C, '''    -- === Midnight Scoreboard-based Healer Detection === {{{''',
'''    -- [Forever] D7: heal evidence (ForeverEvidence.lua) registers confirmed healers through the same pipeline
    HHTD._MN_RegisterHealer = function(...) return RegisterHealer(...) end

    -- === Midnight Scoreboard-based Healer Detection === {{{''')

# D4/D5 scoreboard
sub(C, '''        local playerFaction = HHTD_C.PLAYER_FACTION;
        local scannedCount = 0;''', '''        local playerFaction = HHTD_C.PLAYER_FACTION;
        -- [Forever] D5: roster of every row (first name + side -> class) for the nameplate class join
        if HHTD.MN_RosterSweep then pcall(HHTD.MN_RosterSweep); end
        local scannedCount = 0;''')
sub(C, '''            local scoreName, scoreGUID, scoreClassToken, scoreTalentSpec, scoreFaction, scoreRoleAssigned;
''', '''            local scoreName, scoreGUID, scoreClassToken, scoreTalentSpec, scoreFaction, scoreRoleAssigned;
            local scoreHealingDone, scoreDamageDone; -- [Forever] D6
''')
sub(C, '''                    scoreRoleAssigned = scoreData.roleAssigned;
                else''', '''                    scoreRoleAssigned = scoreData.roleAssigned;
                    scoreHealingDone = scoreData.healingDone; -- [Forever] D6
                    scoreDamageDone = scoreData.damageDone;
                else''')
sub(C, '''                if scoreTalentSpec and scoreClassToken
                    and canaccessvalue(scoreTalentSpec) and canaccessvalue(scoreClassToken)
                    and HHTD_C.CLASS_SPEC_TO_ROLE[scoreClassToken] then''', '''                -- [Forever] D4: canaccessvalue before the truth test (talentSpec is secret prep/ooc/combat per the diag)
                if canaccessvalue(scoreTalentSpec) and canaccessvalue(scoreClassToken)
                    and scoreTalentSpec and scoreClassToken
                    and HHTD_C.CLASS_SPEC_TO_ROLE[scoreClassToken] then''')
sub(C, '''                if not specChecked and scoreRoleAssigned and canaccessvalue(scoreRoleAssigned) and scoreRoleAssigned == 2 then
                    isHealer = true;
                end
''', '''                if not specChecked and canaccessvalue(scoreRoleAssigned) and scoreRoleAssigned and scoreRoleAssigned == 2 then -- [Forever] D4 order
                    isHealer = true;
                end

                -- [Forever] D6: the WOWC spec->role table is empty and roleAssigned is secret in-match, so the scoreboard
                -- never names a healer. healingDone/damageDone are clear post-match (diag: 60/60): a player who healed at
                -- least as much as they damaged is a healer.
                if HHTD_C.FOREVER and not isHealer then
                    local h, d = T.FS.num(scoreHealingDone), T.FS.num(scoreDamageDone);
                    if h and d and h > 0 and h >= d then isHealer = true; end
                end
''')
sub(C, '''                    if scoreFaction and canaccessvalue(scoreFaction) then
                        if playerFaction''', '''                    if canaccessvalue(scoreFaction) and scoreFaction then -- [Forever] D4 order
                        if playerFaction''')
sub(C, '''                    if not guid or not canaccessvalue(guid) then
                        guid = "Scoreboard-" .. scoreName;''', '''                    if not canaccessvalue(guid) or not guid then -- [Forever] D4 order (guid secret in-match)
                        guid = "Scoreboard-" .. scoreName;''')
sub(C, '''                    local shortName = scoreName:match("^([^-]+)") or scoreName;
                    if not HHTD.MN_HealersByName[shortName] then''', '''                    local shortName = scoreName:match("^([^-]+)") or scoreName;
                    -- [Forever] D5: plates give "First", the scoreboard "First Surname": key on the first word when unique
                    if HHTD_C.FOREVER and HHTD.MN_ShortKey then shortName = HHTD.MN_ShortKey(scoreName); end
                    if not HHTD.MN_HealersByName[shortName] then''')
sub(C, '''                            guid = (scoreGUID and canaccessvalue(scoreGUID)) and scoreGUID or nil,''',
'''                            guid = (canaccessvalue(scoreGUID) and scoreGUID) and scoreGUID or nil, -- [Forever] D4 order''')
sub(C, '''                        if scoreClassToken and canaccessvalue(scoreClassToken)
                            and scoreTalentSpec and canaccessvalue(scoreTalentSpec) then''', '''                        if canaccessvalue(scoreClassToken) and scoreClassToken -- [Forever] D4 order
                            and canaccessvalue(scoreTalentSpec) and scoreTalentSpec then''')

# D4 spellcast handler order
sub(C, '''         if not unitTarget or not spellID then return end
''', '''         if type(unitTarget) == "nil" or type(spellID) == "nil" then return end -- [Forever] D4: no truth test on a secret spellID
''')
sub(C, '''         if not guid or not canaccessvalue(guid) then''', '''         if not canaccessvalue(guid) or not guid then -- [Forever] D4 order''')
sub(C, '''         if not sourceName or not canaccessvalue(sourceName) then''', '''         if not canaccessvalue(sourceName) or not sourceName then -- [Forever] D4 order''')

# ---- MidnightNameplates
sub(M, '''-- Union of both sets for quick "can this class heal?" check''', '''-- [Forever] D8: classic-era powers. DPS priests and DPS druids in caster form are on MANA (replay streams runs 10-16:
-- Dolores, Kietaka, Vilem, nameless 나루토 = DPS priests, MANA only; Sham/Haunt = DPS druids, MANA only), there is
-- no Insanity/Astral Power. Mana never identifies a healer spec on Forever: every healer class is ambiguous there
-- (the non-mana check still drops druids in cat/bear form, warriors, rogues).
if HHTD_C.FOREVER then
    for k in pairs(UNAMBIGUOUS_HEALER_CLASSES) do AMBIGUOUS_MANA_CLASSES[k] = true; end
    UNAMBIGUOUS_HEALER_CLASSES = {};
end

-- Union of both sets for quick "can this class heal?" check''')
sub(M, '''    if canAttack and not canaccessvalue(canAttack) then return false, false, nil; end''',
'''    if not canaccessvalue(canAttack) and canAttack ~= nil then return false, false, nil; end -- [Forever] D4 order''')
sub(M, '''            local shortName = unitName:match("^([^%-]+)") or unitName;
            local byName = HHTD.MN_HealersByName;''', '''            local shortName = unitName:match("^([^%-]+)") or unitName;
            -- [Forever] D7: heal evidence confirms this specific friendly player
            if HHTD_C.FOREVER and HHTD.MN_EvidenceConfirmed and HHTD.MN_EvidenceConfirmed(true, T.FS.firstWord(unitName)) then
                return true, true, "HEAL", friendClassToken;
            end
            local byName = HHTD.MN_HealersByName;''')
sub(M, '''    local okC, _, classToken = pcall(UnitClass, unitToken);
    if not okC or not classToken or not canaccessvalue(classToken) then
        return false, false, nil;
    end
''', '''    local okC, _, classToken = pcall(UnitClass, unitToken);
    local enemyFirst = nil;
    if HHTD_C.FOREVER and not (okC and canaccessvalue(classToken) and classToken) then
        -- [Forever] D5: enemy plate UnitClass is secret (diag 750/750) but UnitName is clear and first-name-only:
        -- class from the scoreboard roster (first name + side, duplicates never joined)
        local okN, unitName = pcall(UnitName, unitToken);
        enemyFirst = okN and T.FS.firstWord(unitName) or nil;
        okC, classToken = true, HHTD.MN_RosterClass and HHTD.MN_RosterClass(false, enemyFirst) or nil;
        -- [Forever] D7: unknown class -> only heal evidence on this specific player can mark it
        if not classToken then
            if HHTD.MN_EvidenceConfirmed and HHTD.MN_EvidenceConfirmed(false, enemyFirst) then return true, false, "HEAL", nil; end
            return false, false, nil;
        end
    end
    if not okC or not canaccessvalue(classToken) or not classToken then -- [Forever] D4 order
        return false, false, nil;
    end
''')
sub(M, '''    -- Check 2: Scoreboard class-level confirmation''', '''    -- [Forever] D7: Check 1b - spellIDs are secret on Forever (nameplate 20/20 in the diag), so Check 1 never fires;
    -- heal evidence on this specific player stands in for it.
    if HHTD_C.FOREVER and HHTD.MN_EvidenceConfirmed then
        if not enemyFirst then local okN, unitName = pcall(UnitName, unitToken); enemyFirst = okN and T.FS.firstWord(unitName) or nil; end
        if HHTD.MN_EvidenceConfirmed(false, enemyFirst) then return true, false, "HEAL", classToken; end
    end

    -- Check 2: Scoreboard class-level confirmation''')
sub(M, '''    local methods = { NAME = 0, ["CLASS+PWR"] = 0, CLASS = 0, SPELL = 0, ["CLASS+SCORE"] = 0 };''',
'''    local methods = { NAME = 0, ["CLASS+PWR"] = 0, CLASS = 0, SPELL = 0, ["CLASS+SCORE"] = 0, HEAL = 0 }; -- [Forever] HEAL''')
sub(M, '''    if not unitToken or not spellID then return; end
    -- Only process nameplate units''', '''    if type(unitToken) ~= "string" or type(spellID) == "nil" then return; end -- [Forever] D4: no truth test on a secret spellID
    -- Only process nameplate units''')
sub(M, '''-- Status for auto-diag''', '''-- [Forever] D7: immediate rescan when heal evidence confirms a healer
HHTD.MN_OnEvidence = function() pcall(ScanAllNameplates); end

-- Status for auto-diag''')
print('ok')
