-- busted spec (v2.2.2): container-state schema walker on mocked mixed tables / objects. Needs FORE_DOCS (wowenv).
package.path = "./tests/?.lua;" .. package.path
local W = require("wowenv")
local function tocFiles(dir)
    local out = {}
    for line in io.lines(dir .. "/ForeverDump.toc") do
        if line:match("%.lua%s*$") and not line:match("^#") then out[#out + 1] = line:match("^%s*(.-)%s*$") end
    end
    return out
end
local ns = W.loadAddon("ForeverDump", tocFiles("ForeverDump"), "ForeverDump")
local CT = ns.Containers
local SECRET = W.SECRET

describe("Containers.Walk", function()
    it("classifies a clear scalar, nil and a secret", function()
        assert.are.equal("C", CT.Walk(5).s)
        assert.are.equal("N", CT.Walk(nil).s)
        assert.are.equal("S", CT.Walk(SECRET).s)
    end)
    it("marks a clear container with secret fields as T (partial secret) and keeps per-field codes", function()
        local aura = { auraInstanceID = 3, isFromPlayerOrPlayerPet = true, sourceUnit = "player", applications = 0,
            expirationTime = SECRET, dispelName = nil, spellId = SECRET, name = SECRET, icon = SECRET }
        local n = CT.Walk(aura)
        assert.are.equal("T", n.s)
        for _, k in ipairs({ "auraInstanceID", "isFromPlayerOrPlayerPet", "sourceUnit", "applications" }) do assert.are.equal("C", n.f[k].s, k) end
        for _, k in ipairs({ "expirationTime", "spellId", "name", "icon" }) do assert.are.equal("S", n.f[k].s, k) end
        assert.is_nil(n.f.dispelName)                -- nil field = absent key in a Lua table
        assert.are.equal(4, n.nc)
        assert.are.equal(8, #n.keys)
        assert.is_false(n.fl.issecrettable)
    end)
    it("walks duration objects through their getters and records HasSecretValues", function()
        local d = { HasSecretValues = function() return true end, IsZero = function() return false end,
            GetRemainingDuration = function() return SECRET end, GetTotalDuration = function() return 8 end }
        local n = CT.Walk(d)
        assert.is_true(n.fl.HasSecretValues)
        assert.are.equal("S", n.f["GetRemainingDuration()"].s)
        assert.are.equal("C", n.f["GetTotalDuration()"].s)
        assert.are.equal("C", n.f["IsZero()"].s)
    end)
    it("summarises arrays (first elements) with the clear length", function()
        local n = CT.Walk({ { spellId = SECRET }, { spellId = 9 }, { spellId = SECRET }, { spellId = 1 } })
        assert.are.equal(4, n.len)
        assert.are.equal(3, n.arr.obs)
        assert.are.equal(2, n.arr.f.spellId.s.S)
        assert.are.equal(1, n.arr.f.spellId.s.C)
    end)
    it("records multiple returns as ret1..retN with the select('#') count", function()
        local n = CT.WalkReturns(ns.Pack(true, "Lesser Healing Wave", SECRET, nil))
        assert.are.equal("R", n.s)
        assert.are.equal(3, n.n)
        assert.are.equal("C", n.f.ret1.s) assert.are.equal("S", n.f.ret2.s) assert.are.equal("N", n.f.ret3.s)
    end)
    it("merges observations into state counts and never stores a value", function()
        local a = CT.Merge(nil, CT.Walk({ x = 1, y = SECRET }))
        a = CT.Merge(a, CT.Walk({ x = SECRET }))
        assert.are.equal(2, a.obs)
        assert.are.same({ C = 1, S = 1 }, a.f.x.s)
        assert.are.equal(1, a.f.y.obs)            -- absent once
        local function noSecret(v, seen)
            seen = seen or {}
            if issecretvalue(v) then return false end
            if type(v) == "table" and not seen[v] then seen[v] = true for k, x in pairs(v) do if not noSecret(k, seen) or not noSecret(x, seen) then return false end end end
            return true
        end
        assert.is_true(noSecret(a))
    end)
end)
