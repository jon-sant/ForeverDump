-- busted spec: replay the RAW real Forever 1.60.1.70245 capture (fixtures/forever-70245) through SampleAddon.
-- The fixture pack is produced by `python3 tools/fdump.py fixtures DUMP --file WoWCombatLog.txt --taint taint.log`.
local MOCKS = os.getenv("MOCKS_DIR") or "tests/out/conv/mocks/"
local FX = os.getenv("FOREVER_FIXTURES") or "fixtures/forever-70245/"

local function fresh()
    package.loaded.wowmock = nil
    local wow = dofile(MOCKS .. "wowmock.lua")
    package.loaded.wowmock = wow
    wow.install()
    local Replay = dofile(MOCKS .. "replay.lua")
    local ns = wow.loadAddon("tests/sample_addon/SampleAddon", "SampleAddon")
    return wow, Replay, ns
end

local function slurp(p)
    local f = assert(io.open(p, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

describe("raw Forever 70245 fixture pack", function()
    it("replays the real (raw) combat log through a legacy CLEU handler without errors", function()
        local _, Replay, ns = fresh()
        local fx = Replay.load(FX .. "combatlog_file.lua")
        local stats = Replay.run(fx, { frame = ns.frame })
        assert.are.equal(0, #stats.errors)
        assert.are.equal(377, ns.events.SPELL_AURA_APPLIED)
        assert.are.equal(19, ns.events.SWING_DAMAGE)
        assert.are.equal(2, ns.events.UNIT_DIED)
        local total = 0
        for guid, amount in pairs(ns.damage) do
            total = total + amount
            -- v2.2.21 raw: real GUIDs as logged (no Player-0000- / Pet-0-0000- placeholders)
            assert.is_truthy(guid:find("^Player%-%d+%-%x+$") or guid:find("^Creature%-") or guid:find("^Pet%-")
                or guid:find("^Vehicle%-"), guid)
            assert.is_nil(guid:find("^Player%-0000%-"), guid)
        end
        assert.is_true(total > 0)
    end)

    it("ships the API surface: legacy globals absent, Forever replacements present", function()
        local api = slurp(FX .. "api-surface.json")
        assert.is_nil(api:find('"CombatLogGetCurrentEventInfo"', 1, true))
        assert.is_nil(api:find('"GetSpellInfo"', 1, true))
        assert.is_truthy(api:find('"GetMouseFoci"', 1, true))
        assert.is_truthy(api:find('"C_Spell"', 1, true))
        local env = slurp(FX .. "environment.json")
        assert.is_truthy(env:find('"toc": 16001', 1, true))
        assert.is_truthy(env:find('"projectID": 18', 1, true))
    end)

    it("keeps the documented secrets map and no runtime/user data", function()
        local s = slurp(FX .. "secrets-documented.json")
        assert.is_truthy(s:find('"UnitHealth"', 1, true))
        assert.is_nil(s:find('"liveContradictions"', 1, true))   -- runtime sections are stripped
        assert.is_nil(s:find('"sessions"', 1, true))
        assert.is_truthy(s:find('"keys":0', 1, true))             -- headline: no runtime observations shipped
        -- v2.2.21: the combat log is RAW - real player GUIDs kept verbatim (no Player-0000- placeholders)
        local log = slurp(FX .. "WoWCombatLog.txt")
        local real, placeholder = 0, 0
        for g in log:gmatch("Player%-%d+%-%x+") do
            if g:find("^Player%-0000%-") then placeholder = placeholder + 1 else real = real + 1 end
        end
        assert.is_true(real > 0)
        assert.are.equal(0, placeholder)
    end)
end)
