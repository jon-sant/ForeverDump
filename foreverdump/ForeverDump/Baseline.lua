-- ForeverDump v2.2 - baseline signature + in-game drift alert.
-- At every FD_Logs OFF a compact, versioned signature is stored (ForeverDumpLogDB.baseline and
-- ForeverDumpDB.baselines[build], last 6 builds): build, interface (toc), project ID, a hash of the API docs
-- (+ function/event counts), per-API/event/field secrecy outcome per context (ooc/combat/enc letters: S all secret,
-- C all clear, M mixed, - no data), the operations matrix, restriction behaviour, lab results, combat-probe cells,
-- token-survey families, knowledge field secrecy and the frame types seen. The converter's `fdump.py drift` compares
-- two signatures (or two SVs). If the build differs from the last stored baseline, one chat line says so.
local _, ns = ...
local B = {}
ns.Baseline = B
B.VERSION = 1

local function g(n) return rawget(_G, n) end

-- 32-bit FNV-1a over a string list, Lua 5.1 safe (floating point; no bit library needed)
local function hashList(list)
    local h = 2166136261
    for _, s in ipairs(list) do
        for i = 1, #s do
            local b = s:byte(i)
            -- h = (h XOR b) * 16777619 mod 2^32 (XOR emulated per byte)
            local x, hb, r, p = 0, h % 256, b, 1
            for _ = 1, 8 do
                local a1, a2 = hb % 2, r % 2
                if a1 ~= a2 then x = x + p end
                hb, r, p = math.floor(hb / 2), math.floor(r / 2), p * 2
            end
            h = (h - (h % 256) + x)
            -- h * 16777619 mod 2^32 without exceeding 2^53: 16777619 = 2^24 + 403
            h = ((h % 256) * 16777216 + h * 403) % 4294967296
        end
    end
    return string.format("%08x", h)
end
B.Hash = hashList

function B.DocsHash()
    local docs = g("ForeverDumpDocsDB")
    if type(docs) ~= "table" or type(docs.systems) ~= "table" or #docs.systems == 0 then
        return { missing = true, note = "no docs section dumped yet (FD_Logs queues /fdump all when missing)" }
    end
    local names, nf, ne = {}, 0, 0
    for _, sys in ipairs(docs.systems) do
        local ns_ = tostring(sys.Namespace or sys.Name or "")
        for _, f in ipairs(sys.Functions or {}) do
            nf = nf + 1
            local args = {}
            for _, a in ipairs(f.Arguments or {}) do args[#args + 1] = tostring(a.Type) end
            local rets = {}
            for _, r in ipairs(f.Returns or {}) do rets[#rets + 1] = tostring(r.Type) end
            names[#names + 1] = ns_ .. "." .. tostring(f.Name) .. "(" .. table.concat(args, ",") .. ")" .. table.concat(rets, ",")
        end
        for _, e in ipairs(sys.Events or {}) do ne = ne + 1 names[#names + 1] = "E:" .. tostring(e.LiteralName) end
    end
    table.sort(names)
    return { hash = hashList(names), functions = nf, events = ne, systems = #docs.systems }
end

local function letter(seen, sec)
    if not seen or seen == 0 then return "-" end
    if sec == seen then return "S" end
    if sec == 0 then return "C" end
    return "M"
end

-- per key/pos: "ooc combat enc" letters, e.g. "CS-"
function B.Secrecy()
    local obs = ns.db and ns.db.secretsObs
    local out, n = {}, 0
    if type(obs) ~= "table" then return out end
    for key, row in pairs(obs) do
        if type(key) == "string" and key:sub(1, 1) ~= "_" and type(row) == "table" then
            local parts = {}
            for pos = 1, 12 do
                local c = row[pos]
                if type(c) ~= "table" then break end
                parts[#parts + 1] = letter(c[1], c[2]) .. letter(c[3], c[4]) .. letter(c[5], c[6])
            end
            if #parts > 0 then out[key] = table.concat(parts, " ") n = n + 1 end
            if n > 5000 then break end
        end
    end
    return out
end

local function dominant(counts)
    if type(counts) ~= "table" then return "-" end
    local best, bn = "-", 0
    local total = 0
    for k, v in pairs(counts) do
        if type(v) == "number" then total = total + v if v > bn then best, bn = k, v end end
    end
    if total > bn then return best .. "*" end   -- "*" = mixed observations
    return best
end
B.Dominant = dominant

function B.Signature(reason)
    local m = ns.Meta()
    local log = g("ForeverDumpLogDB") or {}
    local sig = { v = B.VERSION, addon = ns.VERSION, reason = reason, build = m.build, version = m.version, interface = m.toc,
        projectID = m.projectID, projectName = m.projectName, docs = B.DocsHash(), secrecy = B.Secrecy() }
    -- ops matrix: latest controls record per context -> op = ok/err + resultSecret
    local ctl = log.controls
    if type(ctl) == "table" then
        sig.ops = {}
        for _, rec in ipairs(ctl.runs or ctl) do
            if type(rec) == "table" and type(rec.ops) == "table" then
                local ctx = rec.execution and (rec.ctx .. "/" .. rec.execution) or rec.ctx or "?"
                sig.ops[ctx] = sig.ops[ctx] or {}
                for value, res in pairs(rec.ops) do
                    if type(res) == "table" then
                        local row = {}
                        for op, e in pairs(res) do
                            if type(e) == "table" and e.ok ~= nil then row[op] = (e.ok and "ok" or "err") .. (e.resultSecret and "/S" or "") end
                        end
                        sig.ops[ctx][value] = row
                    end
                end
            end
        end
    end
    -- restrictions: flips per type/state + Activating->Active latency
    local r = log.restrictions
    if type(r) == "table" and type(r.flips) == "table" then
        local flips, lat = {}, {}
        local lastAct = {}
        for _, f in ipairs(r.flips) do
            local rt = f.type
            local k = tostring(f.typeName or rt) .. ":" .. tostring(f.stateName or f.state)
            flips[k] = (flips[k] or 0) + 1
            if f.state == 1 and rt ~= nil then lastAct[rt] = f.t end
            if f.state == 2 and rt ~= nil and lastAct[rt] and f.t then lat[#lat + 1] = f.t - lastAct[rt] end
        end
        local avg
        if #lat > 0 then local s = 0 for _, x in ipairs(lat) do s = s + x end avg = s / #lat end
        sig.restrictions = { flips = flips, activatingToActive = avg }
    end
    -- lab: latest per context -> item = available/ok/outputSecret
    if type(log.lab) == "table" then
        sig.lab = {}
        for _, rec in ipairs(log.lab) do
            sig.lab[rec.ctx or "?"] = {}
            for _, it in ipairs(rec.items or {}) do
                sig.lab[rec.ctx or "?"][it.id] = (it.available == false and "absent") or ((it.ok and "ok" or "err")
                    .. (it.outputSecret == true and "/S" or (it.outputSecret == false and "/C" or "")))
            end
        end
    end
    -- combat probe: ctx|class|item|ret -> dominant code
    local cp = log.combatProbe
    if type(cp) == "table" and type(cp.cells) == "table" then
        sig.combat = {}
        local n = 0
        for ctx, byU in pairs(cp.cells) do
            for ucls, byI in pairs(byU) do
                for item, c in pairs(byI) do
                    for ret, counts in pairs(c.r or {}) do
                        n = n + 1
                        if n <= 6000 then sig.combat[ctx .. "|" .. ucls .. "|" .. item .. "|" .. tostring(ret)] = dominant(counts) end
                    end
                    for fld, counts in pairs(c.f or {}) do
                        n = n + 1
                        if n <= 6000 then sig.combat[ctx .. "|" .. ucls .. "|" .. item .. "|." .. fld] = dominant(counts) end
                    end
                end
            end
        end
        sig.combatAbsent = cp.absent
    end
    -- token survey: ctx|family|check -> dominant code over existing tokens (or "none" bucket)
    local tk = log.tokens
    if type(tk) == "table" and type(tk.ctx) == "table" then
        sig.tokens = {}
        for ctx, rec in pairs(tk.ctx) do
            for fam, fr in pairs(rec.families or {}) do
                sig.tokens[ctx .. "|" .. fam .. "|resolves"] = (fr.exist > 0 and "yes") or (fr.existSecret > 0 and "secret") or "no"
                for chk, b in pairs(fr.checks or {}) do
                    local bucket = b.exist or b["exist?"] or b.none
                    sig.tokens[ctx .. "|" .. fam .. "|" .. chk] = dominant(bucket)
                end
            end
        end
    end
    -- knowledge: per field, per context -> dominant code across spells
    local kdb = ns.Knowledge and ns.Knowledge.DB()
    if kdb and type(kdb.spells) == "table" then
        local agg = {}
        for _, e in pairs(kdb.spells) do
            for ctx, codes in pairs(e.ctx or {}) do
                for f, c in pairs(codes) do
                    if f ~= "tooltipLines" then
                        local k = ctx .. "|" .. f
                        agg[k] = agg[k] or {}
                        agg[k][c] = (agg[k][c] or 0) + 1
                    end
                end
            end
        end
        sig.knowledge = {}
        for k, counts in pairs(agg) do sig.knowledge[k] = dominant(counts) end
    end
    -- frame types (widgets section)
    local w = ns.db and ns.db.sections and ns.db.sections.widgets
    if type(w) == "table" then
        sig.frameTypes = {}
        for t in pairs(w.types or {}) do sig.frameTypes[t] = true end
        for t in pairs(w.notCreatable or {}) do sig.frameTypes[t] = "notCreatable" end
    end
    return ns.Stamp(sig)
end

-- store + drift alert (one line)
function B.Capture(reason)
    local sig = B.Signature(reason)
    local log = g("ForeverDumpLogDB")
    if type(log) == "table" then log.baseline = sig end
    local db = ns.db
    local alert
    if type(db) == "table" then
        db.baselines = db.baselines or {}
        local last = db.lastBaselineBuild
        if last and tostring(last) ~= tostring(sig.build) then
            local prev = db.baselines[tostring(last)]
            local newly = 0
            if prev and prev.secrecy then
                for k, v in pairs(sig.secrecy or {}) do
                    local o = prev.secrecy[k]
                    if o and o ~= v and v:find("S") and not o:find("S") then newly = newly + 1 end
                end
            end
            alert = string.format("|cffff9900drift:|r build %s -> %s%s; run `fdump.py drift` on the SV (DRIFT.md)", tostring(last),
                tostring(sig.build), prev and string.format(", %d API position(s) newly secret", newly) or "")
        end
        db.baselines[tostring(sig.build)] = sig
        local builds = {}
        for b in pairs(db.baselines) do builds[#builds + 1] = b end
        table.sort(builds, function(a, b2) return (tonumber(a) or 0) < (tonumber(b2) or 0) end)
        while #builds > 6 do db.baselines[table.remove(builds, 1)] = nil end
        db.lastBaselineBuild = sig.build
        db.lastDriftAlert = alert
    end
    if alert then ns.Print(alert) end
    return sig, alert
end
