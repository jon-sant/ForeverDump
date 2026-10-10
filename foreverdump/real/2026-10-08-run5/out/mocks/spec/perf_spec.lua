-- perf_spec.lua: the PERFORMANCE.md rule as a test for generated / ported addon code (2-minute wall cap).
-- Replace the example handler with your addon's: load its files, then drive its OnEvent with real fixtures.
local dir = (debug.getinfo(1, "S").source:match("^@(.*[/\\])spec[/\\]") or "mocks/")
local wow = dofile(dir .. "wowmock.lua")
package.loaded.wowmock = wow
local PG = dofile(dir .. "perf_guard.lua")

-- frames from the dumped widget API when the dump has it, else a minimal stand-in (scripts only)
local function newFrame(name)
    local ok, f = pcall(CreateFrame, "Frame", name)
    if ok and f then return f end
    local scripts = {}
    return { SetScript = function(_, k, fn) scripts[k] = fn end, GetScript = function(_, k) return scripts[k] end,
             IsShown = function() return true end, GetName = function() return name end }
end

describe("performance (PERFORMANCE.md)", function()
    setup(function() wow.install() end)

    it("keeps per-event cost flat as the session grows (O(1) per event)", function()
        -- example handler: bounded history with an amortised trim, dirty flag for a throttled redraw
        local hist, dirty, max = {}, false, 100
        local f = newFrame()
        f:SetScript("OnEvent", function(_, _, v)
            hist[#hist + 1] = v
            if #hist > max + max / 4 then
                local d = #hist - max
                for i = 1, max do hist[i] = hist[i + d] end
                for i = #hist, max + 1, -1 do hist[i] = nil end
            end
            dirty = true
        end)
        local handler = f:GetScript("OnEvent")
        local res = PG.flat({
            grow = function(n) for i = #hist + 1, n * 10 do handler(f, "UNIT_AURA", i) end end,
            event = function() handler(f, "UNIT_AURA", 1) end,
            marks = { 25, 50, 100 }, per = 500, cap = 120, eventsPerSecond = 60,
        })
        assert.is_true(res.ok, res.msg)
        assert.is_true(dirty)
    end)

    it("has no OnUpdate while idle", function()
        local f = newFrame("PerfSpecIdle")
        f:SetScript("OnUpdate", nil)
        local n, names = PG.idleOnUpdates({ f })
        assert.are.equal(0, n, table.concat(names, ", "))
    end)
end)
