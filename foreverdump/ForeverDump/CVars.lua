-- ForeverDump v2 - cvars: v1 data (cvars/cvarNames/commands) + defaults diff.
local _, ns = ...

ns.RegisterSection({
    name = "cvars",
    desc = "CVars (value/default/flags/help/category), console commands, CVars changed from default",
    inAll = true,
    run = function()
        local count = 0
        local nested, flat, commands = ns.Legacy.CollectCVars(function()
            count = count + 1
            if count % 100 == 0 then ns.Yield() end
        end)
        ns.Legacy.Store({ cvars = nested, cvarNames = flat, commands = commands })
        local changed = {}
        for cat, rows in pairs(nested) do
            for name, row in pairs(rows) do
                if row.current ~= nil and row.default ~= nil and tostring(row.current) ~= tostring(row.default) then
                    changed[#changed + 1] = { name = name, category = cat, current = row.current, default = row.default }
                end
            end
        end
        table.sort(changed, function(a, b) return a.name < b.name end)
        ns.SaveSection("cvars", {
            storedIn = "ForeverDumpStaticDB.v1.cvars / cvarNames / commands (v1 shape)",
            changedFromDefault = changed,
            counts = { cvars = #flat, commands = #commands, changed = #changed },
        })
        ns.Print(string.format("cvars: %d CVars (%d differ from default), %d console commands", #flat, #changed, #commands))
    end,
})
