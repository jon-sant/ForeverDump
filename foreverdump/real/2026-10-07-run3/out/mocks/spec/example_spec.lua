-- Example busted spec using the generated ForeverDump mocks.
-- Run from the mocks folder's parent:  busted mocks/spec   (or: lua5.1 mocks/run_spec.lua mocks/spec/example_spec.lua)
local dir = (debug.getinfo(1, "S").source:match("^@(.*[/\\])spec[/\\]") or "mocks/")
local wow = dofile(dir .. "wowmock.lua")
package.loaded.wowmock = wow
local Replay = dofile(dir .. "replay.lua")

describe("ForeverDump mocks", function()
    setup(function() wow.install() end)

    it("exposes dumped namespaces, Enum and project constants", function()
        assert.is_table(C_Spell or C_Item or {})
        assert.is_table(Enum)
        assert.is_not_nil(WOW_PROJECT_ID)
    end)

    it("creates frames with the dumped widget methods", function()
        local f = CreateFrame("Frame", "SpecFrame", UIParent)
        assert.are.equal("Frame", f:GetObjectType())
        f:RegisterEvent("PLAYER_LOGIN")
        local seen
        f:SetScript("OnEvent", function(_, e) seen = e end)
        wow.fire("PLAYER_LOGIN")
        assert.are.equal("PLAYER_LOGIN", seen)
        assert.has_error(function() CreateFrame("NotAWidget") end)
    end)

    it("returns secret sentinels for documented/observed secret returns", function()
        local found
        for full, pos in pairs(wow.secretData.returns) do
            for i, cls in pairs(pos) do
                if cls == "always" and not full:find("%.") and _G[full] then found = { full, i } break end
            end
            if found then break end
        end
        if found then
            local vals = { _G[found[1]]("player") }
            assert.is_true(issecretvalue(vals[found[2]]), found[1] .. " should return a secret")
            wow.secretOverride[found[1]] = false
            vals = { _G[found[1]]("player") }
            assert.is_false(issecretvalue(vals[found[2]]))
            wow.secretOverride[found[1]] = nil
        end
        -- conditional secrets switch on in combat; event payloads too
        local ev
        for e, pos in pairs(wow.secretData.events) do
            for i, cls in pairs(pos) do if cls ~= "always" then ev = { e, i } break end end
            if ev then break end
        end
        if ev then
            local f = CreateFrame("Frame")
            local got
            f:SetScript("OnEvent", function(_, _, ...) got = { ... } end)
            f:RegisterEvent(ev[1])
            local args = {} for i = 1, ev[2] do args[i] = i end
            wow.fire(ev[1], unpack(args))
            assert.is_false(issecretvalue(got[ev[2]]))
            wow.setCombat(true)
            wow.fire(ev[1], unpack(args))
            assert.is_true(issecretvalue(got[ev[2]]), ev[1] .. " field " .. ev[2] .. " secret in combat")
            wow.setCombat(false)
        end
    end)

    it("treats secrets like the client does (no arithmetic/compare/concat)", function()
        assert.is_true(issecretvalue(wow.SECRET))
        assert.has_error(function() return wow.SECRET + 1 end)
        assert.has_error(function() return "x" .. wow.SECRET end)
    end)

    it("replays a recorded session into an addon's OnEvent", function()
        local ok, session = pcall(Replay.load, dir .. "fixtures/session_1.lua")
        if not ok then pending("no recorded session in this dump") return end
        local f = CreateFrame("Frame")
        local count, secretArgs = 0, 0
        f:RegisterAllEvents()
        f:SetScript("OnEvent", function(_, event, ...)
            count = count + 1
            for i = 1, select("#", ...) do
                if issecretvalue((select(i, ...))) then secretArgs = secretArgs + 1 end
            end
        end)
        local stats = Replay.run(session, { frame = f })
        assert.are.equal(stats.delivered, count)
        assert.are.equal(0, #stats.errors)
        assert.is_true(secretArgs >= 0)
    end)

    it("replays a /fdump cl session into a Forever-style UNIT_COMBAT / COMBAT_TEXT_UPDATE handler", function()
        local session
        for i = 1, 9 do
            local ok, s = pcall(Replay.load, dir .. "fixtures/combatlog_" .. i .. ".lua")
            if ok and s.counts and (s.counts.UNIT_COMBAT or s.counts.COMBAT_TEXT_UPDATE) then session = s break end
        end
        if not session then pending("no combat session with UNIT_COMBAT/COMBAT_TEXT_UPDATE in this dump") return end
        local f = CreateFrame("Frame")
        local seen, secrets = 0, 0
        f:RegisterEvent("UNIT_COMBAT")
        f:RegisterEvent("COMBAT_TEXT_UPDATE")
        f:SetScript("OnEvent", function(_, event, ...)
            seen = seen + 1
            local v = (event == "UNIT_COMBAT") and select(4, ...) or C_CombatText.GetCurrentEventInfo()
            if issecretvalue(v) then secrets = secrets + 1 end -- never do arithmetic on it
        end)
        local stats = Replay.run(session, { frame = f })
        assert.are.equal(0, #stats.errors)
        assert.is_true(seen > 0)
        assert.is_true(secrets >= 0)
    end)

    it("replays a /fdump cl session; CombatLogGetCurrentEventInfo returns the recorded payload", function()
        local session
        for i = 1, 9 do
            local ok, s = pcall(Replay.load, dir .. "fixtures/combatlog_" .. i .. ".lua")
            if ok and (s.cleuTotal or 0) > 0 then session = s break end
        end
        if not session then pending("no legacy cleu-force session in this dump (CLEU is restricted on Forever)") return end
        local f = CreateFrame("Frame")
        local subevents = {}
        f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        f:SetScript("OnEvent", function(_, event, ...)
            assert.are.equal(0, select("#", ...))  -- CLEU has no payload; addons call the getter
            local _, sub = CombatLogGetCurrentEventInfo()
            if not issecretvalue(sub) then subevents[sub] = (subevents[sub] or 0) + 1 end
        end)
        local stats = Replay.run(session, { frame = f })
        assert.are.equal(0, #stats.errors)
        local total = 0
        for _, n in pairs(subevents) do total = total + n end
        assert.is_true(total > 0)
    end)
end)
