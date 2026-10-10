-- busted spec: generated ForeverDump mocks + replay drive tests/sample_addon/SampleAddon.
-- Run via tests/run_converter_tests.sh (sets MOCKS_DIR / FILE_FIXTURE).
local MOCKS = os.getenv("MOCKS_DIR") or "tests/out/conv/mocks/"
local FILE_FIXTURE = os.getenv("FILE_FIXTURE") or "tests/out/conv/combatlog_file.lua"

local function fresh()
    for k in pairs(package.loaded) do if k == "wowmock" then package.loaded[k] = nil end end
    local wow = dofile(MOCKS .. "wowmock.lua")
    package.loaded.wowmock = wow
    wow.install()
    local Replay = dofile(MOCKS .. "replay.lua")
    local ns = wow.loadAddon("tests/sample_addon/SampleAddon", "SampleAddon")
    return wow, Replay, ns
end

describe("SampleAddon under ForeverDump mocks", function()
    it("loads with the dumped API surface", function()
        local wow, _, ns = fresh()
        assert.is_table(ns.frame)
        assert.are.equal("Frame", ns.frame:GetObjectType())
        assert.is_true(ns.frame:IsEventRegistered("COMBAT_LOG_EVENT_UNFILTERED"))
        assert.are.equal(18, WOW_PROJECT_ID)  -- recorded from the dump, not assumed mainline
        assert.is_nil(wow.calls["C_Item.GetItemCooldown"])
    end)

    it("replays a legacy /fdump cl cleu-force capture into a CLEU handler (secrets stay secret)", function()
        local wow, Replay, ns = fresh()
        local session
        for i = 1, 9 do
            local ok, s = pcall(Replay.load, MOCKS .. "fixtures/combatlog_" .. i .. ".lua")
            if ok and s.cleuCounts and s.cleuCounts.SWING_DAMAGE then session = s break end
        end
        assert.is_table(session)
        local stats = Replay.run(session, { frame = ns.frame })
        assert.are.equal(0, #stats.errors)
        assert.are.equal(1234, ns.damage["Player-#1"])  -- captured with cl.redactPlayers=true
        assert.are.equal(1, ns.secrets)           -- SWING_DAMAGE amount was <secret>
        assert.is_true(stats.combat > 0)
        assert.are.equal(0, wow.secretTouches)
        assert.are.equal(1, wow.forbidden.COMBAT_LOG_EVENT_UNFILTERED)  -- SampleAddon's legacy CLEU registration is flagged
    end)

    it("replays a parsed WoWCombatLog.txt fixture through the same handler", function()
        local _, Replay, ns = fresh()
        local fx = Replay.load(FILE_FIXTURE)
        local stats = Replay.run(fx, { frame = ns.frame })
        assert.are.equal(0, #stats.errors)
        assert.are.equal(1234 + 200, ns.damage["Player-1234-0ABCDEF0"])
        assert.are.equal(321, ns.damage["Creature-0-1-2-3-4-5"])
        assert.are.equal("Mock Boss", ns.encounters[1])
        assert.are.equal(1, ns.events.UNIT_DIED)
        assert.is_nil(ns.events.ZONE_CHANGE)
    end)

    it("replays a default (Forever-safe) combat session into Forever-style handlers", function()
        local wow, Replay, ns = fresh()
        local session
        for i = 1, 9 do
            local ok, s = pcall(Replay.load, MOCKS .. "fixtures/combatlog_" .. i .. ".lua")
            if ok and s.counts and s.counts.UNIT_COMBAT then session = s break end
        end
        if not session then pending("dump has no Forever combat session (sessions are capped at 3)") return end
        local stats = Replay.run(session, { frame = ns.foreverFrame })
        assert.are.equal(0, #stats.errors)
        assert.are.equal(1, ns.forever.unitCombat)
        assert.are.equal(1, ns.forever.secretAmounts)       -- UNIT_COMBAT amount was secret in combat
        assert.are.equal(1, ns.forever.combatText)
        assert.are.equal(1, ns.forever.secretText)          -- C_CombatText.GetCurrentEventInfo stubbed from the capture
        assert.are.equal(0, wow.secretTouches)
    end)

    it("drives Forever-style handlers from a WoWCombatLog file fixture (synthetic events, cleu = false)", function()
        local _, Replay, ns = fresh()
        local fx = Replay.load(os.getenv("FILE_FIXTURE_FOREVER") or "tests/out/conv/combatlog_file_forever.lua")
        local stats = Replay.run(fx, { frame = ns.foreverFrame, cleu = false })
        assert.are.equal(0, #stats.errors)
        assert.are.equal(2, ns.forever.unitCombat)
        assert.are.equal(321, ns.forever.wound)
        assert.are.equal(500, ns.forever.heal)
        assert.is_nil(ns.events.SPELL_DAMAGE)                -- legacy CLEU entries were skipped
    end)

    it("strict secrets: arithmetic on a secret errors like the client", function()
        local wow, Replay, ns = fresh()
        local f = CreateFrame("Frame")
        f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        f:SetScript("OnEvent", function()
            local amount = select(12, CombatLogGetCurrentEventInfo())
            return amount + 1   -- naive addon code
        end)
        local session
        for i = 1, 9 do
            local ok, s = pcall(Replay.load, MOCKS .. "fixtures/combatlog_" .. i .. ".lua")
            if ok and s.cleuCounts and s.cleuCounts.SWING_DAMAGE then session = s break end
        end
        local stats = Replay.run(session, { frame = f, events = { COMBAT_LOG_EVENT_UNFILTERED = true } })
        local sawSecretError = false
        for _, e in ipairs(stats.errors) do if e.err:find("secret") then sawSecretError = true end end
        assert.is_true(sawSecretError)
        assert.is_true(wow.secretTouches > 0)
        assert.is_table(ns)
    end)
end)
