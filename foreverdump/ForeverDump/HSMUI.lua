-- ForeverDump v2.2 - live window for the hybrid state machine: /fdump hsm (toggle). FD_Logs ON opens it when
-- hsm.autoShow is true (default) and OFF closes it. Plain insecure frames parented to UIParent (no secure templates,
-- no hooks of Blizzard frames); Escape closes it via UISpecialFrames; movable + resizable, position/size saved in
-- ForeverDumpDB.hsmUI.
-- v2.2.3 (run 4 perf fix): dirty-only, throttled redraws. The OnUpdate script is installed only while there is work
-- (HSM state changed, an engine bar event arrived, a predicted bar is running or a countdown is shown) and removes
-- itself when idle; text is rebuilt at most every hsm.updateInterval (0.5 s) and only when the HSM version moved
-- (countdowns: 1 Hz); engine bars (cast, cooldown, health) are refreshed from their events, not polled. The old loop
-- rebuilt the whole text 5x per second and resolved every spell name through Knowledge.DB() -> ns.Meta() -> a walk
-- over all 52k globals, so its cost grew with every prediction/cooldown/aura line (= with every cast).
-- Secret values are shown ONLY through sanctioned passthrough widgets (StatusBar:SetTimerDuration / SetValue,
-- FontString:SetText, Cooldown:SetCooldownFromDurationObject), labelled "secret (engine-displayed)": our Lua never
-- reads them. Colours: green observed, yellow inferred, grey unknown/cached, red contradiction.
local _, ns = ...
local H = {}
ns.HSMUI = H

local function g(n) return rawget(_G, n) end
local function cfg() return (ns.config and ns.config.hsm) or {} end
local function now() return (g("GetTime") or os.clock)() end
local GREEN, YELLOW, GREY, RED, WHITE = "|cff33ff33", "|cffffd100", "|cff999999", "|cffff4040", "|cffffffff"
local COL = { observed = GREEN, inferred = YELLOW, unknown = GREY, cached = GREY }
H.COL = COL
local SCHOOL = { [1] = "physical", [2] = "holy", [4] = "fire", [8] = "nature", [16] = "frost", [32] = "shadow", [64] = "arcane" }
local RNAMES = { [0] = "Combat", "Encounter", "ChallengeMode", "PvPMatch", "Map", "Chat" }
local SNAMES = { [0] = "Inactive", "Activating", "Active" }

local frame
local function uiDB()
    local db = ns.db
    if type(db) ~= "table" then return {} end
    db.hsmUI = db.hsmUI or {}
    return db.hsmUI
end

local function savePos()
    if not frame then return end
    local d = uiDB()
    local ok, p, _, rp, x, y = pcall(frame.GetPoint, frame, 1)
    if ok and p then d.point, d.relPoint, d.x, d.y = p, rp, x, y end
    local okS, w, h = pcall(frame.GetSize, frame)
    if okS and type(w) == "number" then d.w, d.h = w, h end
end

-- a labelled bar row: predicted (clear numbers from the HSM) and real (engine passthrough)
-- v2.2.2: labels get their own fixed column (run 3: "player cast (secret, en" was cut off by the bar drawn over it at x=120);
-- each bar carries a value text on its right end (clear predicted numbers, or the engine passthrough for secrets)
local LABEL_W = 190
local ROW = 14
local function bar(parent, y, label, color)
    local b = CreateFrame("StatusBar", nil, parent)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", LABEL_W + 12, y)
    b:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, y)
    b:SetHeight(11)
    pcall(b.SetStatusBarTexture, b, "Interface\\TargetingFrame\\UI-StatusBar")
    pcall(b.SetStatusBarColor, b, color[1], color[2], color[3])
    pcall(b.SetMinMaxValues, b, 0, 1)
    pcall(b.SetValue, b, 0)
    local t = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y + 1)
    pcall(t.SetWidth, t, LABEL_W)
    pcall(t.SetJustifyH, t, "LEFT")
    pcall(t.SetWordWrap, t, false)
    t:SetText(label)
    b.label = t
    b.value = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.value:SetPoint("RIGHT", b, "RIGHT", -2, 0)
    pcall(b.value.SetJustifyH, b.value, "RIGHT")
    return b
end

local H_dirty, H_flags = true, { hp = true, cast = true, cd = true }
-- v2.2.21: unit keys are shown raw (player:<GUID>, npc:<id>, raw GUID)
local function unitLabel(hs, u)
    if hs and hs.ScrubKey then return tostring(hs:ScrubKey(u)) end
    return tostring(u)
end
local lastVersion, lastText, acc = -1, -100, 0
local onUpdate

-- install the OnUpdate only when there is work (no idle OnUpdate, PERFORMANCE.md)
function H.MarkDirty(flag)
    if flag then H_flags[flag] = true else H_dirty = true end
    if frame and frame:IsShown() and onUpdate and frame:GetScript("OnUpdate") ~= onUpdate then frame:SetScript("OnUpdate", onUpdate) end
end

local EV_UNITS = { player = true, target = true }
local function onEvent(_, event, unit)
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        if unit == nil or EV_UNITS[unit] then H.MarkDirty("hp") end
    elseif event == "PLAYER_TARGET_CHANGED" then H.MarkDirty("hp") H.MarkDirty("cast") H.MarkDirty()
    elseif event == "SPELL_UPDATE_COOLDOWN" then H.MarkDirty("cd")
    else if unit == nil or EV_UNITS[unit] then H.MarkDirty("cast") end end
end
local UI_EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_HEALTH", "UNIT_MAXHEALTH" }
local function registerUI(on)
    if not frame then return end
    local ev = frame.ev
    if not on then pcall(ev.UnregisterAllEvents, ev) return end
    for _, e in ipairs(UI_EVENTS) do
        if not (ev.RegisterUnitEvent and pcall(ev.RegisterUnitEvent, ev, e, "player", "target")) then pcall(ev.RegisterEvent, ev, e) end
    end
    pcall(ev.RegisterEvent, ev, "PLAYER_TARGET_CHANGED")
    pcall(ev.RegisterEvent, ev, "SPELL_UPDATE_COOLDOWN")
end

local linePool = {}   -- body line FontStrings (H.RenderLines)
local function build()
    frame = CreateFrame("Frame", "ForeverDumpHSMFrame", UIParent)
    local d = uiDB()
    frame:SetSize(math.max(d.w or 640, 560), d.h or 480)
    frame:SetPoint(d.point or "CENTER", UIParent, d.relPoint or "CENTER", d.x or 300, d.y or 0)
    frame:SetFrameStrata("HIGH")
    pcall(frame.SetClampedToScreen, frame, true)
    frame:SetMovable(true)
    pcall(frame.SetResizable, frame, true)
    if frame.SetResizeBounds then pcall(frame.SetResizeBounds, frame, 560, 300, 1400, 1100) end
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() savePos() end)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.8)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOPLEFT", 8, -6)
    frame.title:SetText("ForeverDump " .. ns.VERSION .. " - hybrid state machine")
    frame.logLevel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.logLevel:SetPoint("LEFT", frame.title, "RIGHT", 8, 0)
    frame.logLevel:SetText("")
    local close = CreateFrame("Button", nil, frame)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -4, -4)
    close.t = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    close.t:SetPoint("CENTER")
    close.t:SetText("x")
    close:SetScript("OnClick", function() H.Hide() end)
    -- resize grip (bottom right)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    local gt = grip:CreateTexture(nil, "OVERLAY")
    gt:SetAllPoints()
    pcall(gt.SetColorTexture, gt, 0.6, 0.6, 0.6, 0.6)
    grip:SetScript("OnMouseDown", function() pcall(frame.StartSizing, frame, "BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() savePos() end)
    -- v2.2.3 layout (run 4 screenshot: the "player HP, secret (engine-displayed)" line collided with the "real cooldown"
    -- label because both were free-floating at y -128/-132): one fixed 14 px row per item, label column on the left,
    -- bar + right-aligned value on the right; the real cooldown is its own row; the text body starts below the last row.
    local y0 = -26
    local function rowY(i) return y0 - (i - 1) * ROW end
    frame.bars = {
        pCastPred = bar(frame, rowY(1), "player cast (pred)", { 1, 0.82, 0 }),
        pCastReal = bar(frame, rowY(2), "player cast (secret, engine)", { 0.9, 0.9, 0.9 }),
        tCastPred = bar(frame, rowY(3), "target cast (pred)", { 1, 0.82, 0 }),
        tCastReal = bar(frame, rowY(4), "target cast (secret, engine)", { 0.9, 0.9, 0.9 }),
        cdPred = bar(frame, rowY(5), "cooldown (pred, clear)", { 1, 0.82, 0 }),
        pHealth = bar(frame, rowY(7), "player HP (secret, engine)", { 0.2, 0.9, 0.2 }),
        tHealth = bar(frame, rowY(8), "target HP (secret, engine)", { 0.9, 0.2, 0.2 }),
        gcdPred = bar(frame, rowY(11), "GCD (tracker)", { 0.55, 0.75, 1 }),   -- v2.2.4 CooldownTracker
    }
    -- real cooldown row: label column + Cooldown swipe over the spell icon at the bar start (duration-object passthrough)
    frame.cdLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.cdLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, rowY(6) + 1)
    pcall(frame.cdLabel.SetWidth, frame.cdLabel, LABEL_W)
    pcall(frame.cdLabel.SetJustifyH, frame.cdLabel, "LEFT")
    pcall(frame.cdLabel.SetWordWrap, frame.cdLabel, false)
    frame.cdLabel:SetText("real cooldown (secret, engine)")
    frame.cdIcon = frame:CreateTexture(nil, "ARTWORK")
    frame.cdIcon:SetSize(12, 12)
    frame.cdIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", LABEL_W + 12, rowY(6))
    pcall(frame.cdIcon.SetColorTexture, frame.cdIcon, 0.25, 0.25, 0.25, 1)
    frame.cd = CreateFrame("Cooldown", nil, frame)
    frame.cd:SetAllPoints(frame.cdIcon)
    frame.cdValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.cdValue:SetPoint("LEFT", frame.cdIcon, "RIGHT", 6, 0)
    frame.cdValue:SetText("")
    -- v2.2.4 rows 9-10: live source attribution (UNIT_COMBAT + timing rules) and the post-combat C_DamageMeter read.
    -- Text rows in the same grid (label column + value), rebuilt only with the dirty text body.
    local function textRow(i, label)
        local l = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        l:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, rowY(i) + 1)
        pcall(l.SetWidth, l, LABEL_W)
        pcall(l.SetJustifyH, l, "LEFT")
        pcall(l.SetWordWrap, l, false)
        l:SetText(label)
        local v = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        v:SetPoint("TOPLEFT", frame, "TOPLEFT", LABEL_W + 12, rowY(i) + 1)
        v:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
        pcall(v.SetJustifyH, v, "LEFT")
        pcall(v.SetWordWrap, v, false)
        v:SetText(GREY .. "-|r")
        return { label = l, value = v }
    end
    frame.attrRow = textRow(9, "damage on target (live)")
    frame.dmRow = textRow(10, "interrupts / heals / meter")
    -- scrolling text body, below the 11 rows (row 11: GCD bar from the CooldownTracker)
    local bodyTop = rowY(11) - ROW - 4
    frame.layout = { rows = { rowY(1), rowY(2), rowY(3), rowY(4), rowY(5), rowY(6), rowY(7), rowY(8), rowY(9), rowY(10), rowY(11) },
        bodyTop = bodyTop, row = ROW }
    local sf = CreateFrame("ScrollFrame", "ForeverDumpHSMScroll", frame, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 8, bodyTop)
    sf:SetPoint("BOTTOMRIGHT", -28, 18)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(600, 800)
    sf:SetScrollChild(child)
    frame.body = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.body:SetPoint("TOPLEFT", 0, 0)
    frame.body:SetWidth(590)
    pcall(frame.body.SetWordWrap, frame.body, true)
    frame.body:SetJustifyH("LEFT")
    frame.body:SetJustifyV("TOP")
    frame.scroll, frame.child = sf, child
    frame:SetScript("OnSizeChanged", function(self, w)
        if type(w) == "number" then
            pcall(child.SetWidth, child, w - 40) pcall(self.body.SetWidth, self.body, w - 50)
            for _, fs in ipairs(linePool) do pcall(fs.SetWidth, fs, w - 50) end
        end
    end)
    frame.ev = CreateFrame("Frame", nil, frame)
    frame.ev:SetScript("OnEvent", onEvent)
    onUpdate = function(_, dt)
        acc = acc + (dt or 0)
        if acc < 0.1 then return end
        acc = 0
        local ok, busy
        if ns.Perf and ns.Perf.on then
            local t0 = (g("debugprofilestop") or function() return 0 end)()
            ok, busy = pcall(H.Step)
            ns.Perf.Add("HSMUI.Step", (g("debugprofilestop") or function() return 0 end)() - t0)
        else ok, busy = pcall(H.Step) end
        if not ok then ns.NoteSelfError("HSMUI.Update", busy) busy = false end
        if not busy then frame:SetScript("OnUpdate", nil) end   -- idle: no OnUpdate until the next MarkDirty
    end
    frame:Hide()
    if type(g("UISpecialFrames")) == "table" then table.insert(UISpecialFrames, "ForeverDumpHSMFrame") end
    H.frame = frame
    return frame
end
H.ROW, H.LABEL_W = ROW, LABEL_W

local function fmt(s) if type(s) ~= "number" then return "?" end return string.format("%.1fs", s) end

-- v2.2.3: cached (the knowledge DB lookup used to cost a full _G walk per call, see Core.lua ns.ProjectInfo)
local names, namesV = {}, nil
local function spellName(id)
    if type(id) ~= "number" then return "?" end
    local hs = ns.Inference and ns.Inference.hs
    local kv = hs and hs.kver or 0
    if namesV ~= kv then names, namesV = {}, kv end
    local n = names[id]
    if n then return n end
    local kdb = ns.Knowledge and ns.Knowledge.DB()
    local e = kdb and kdb.spells and kdb.spells[id]
    local nm = e and e.data and e.data["info.name"]
    n = (type(nm) == "string" and nm or "spell") .. " #" .. id
    names[id] = n
    return n
end
H.SpellName = spellName

-- predicted progress (clear numbers only)
-- dirty-only: an idle bar is drawn once (no per-step widget calls / string building); a running bar redraws only when
-- its 0.1 s text changes
local function predBar(b, start, ends, idle)
    local t = now()
    if start and ends and ends > start and t < ends then
        local len = ends - start
        local el = math.min(t - start, len)
        local tenth = math.floor(el * 10)
        if b._s ~= start or b._e ~= ends or b._t ~= tenth then
            if b._s ~= start or b._e ~= ends then b:SetMinMaxValues(0, len) end
            b._s, b._e, b._t, b._idle = start, ends, tenth, nil
            b:SetValue(el)
            b.value:SetText(string.format("%.1f / %.1fs", el, len))
        end
        return true
    end
    idle = idle or "idle"
    if b._idle ~= idle then
        b._idle, b._s, b._e, b._t = idle, nil, nil, nil
        b:SetMinMaxValues(0, 1) b:SetValue(0) b.value:SetText(GREY .. idle .. "|r")
    end
    return false
end

-- engine passthrough: the duration object / secret value goes straight into the widget, never into our Lua math
local function realCast(b, unit)
    local f = g("UnitCastingDuration")
    local okD, d = pcall(f or function() return nil end, unit)
    if (not okD or d == nil) then
        local fc = g("UnitChannelDuration")
        okD, d = pcall(fc or function() return nil end, unit)
    end
    if okD and d ~= nil and b.SetTimerDuration then
        if not pcall(b.SetTimerDuration, b, d) then b:SetValue(0) end
        b.value:SetText("engine")
        return true
    end
    b:SetMinMaxValues(0, 1) b:SetValue(0)
    b.value:SetText(GREY .. "not casting|r")
    return false
end
local function realHealth(b, unit)
    local okM, mx = pcall(g("UnitHealthMax") or function() return nil end, unit)
    local okH, hv = pcall(g("UnitHealth") or function() return nil end, unit)
    if okM and okH and mx ~= nil and hv ~= nil then
        -- UnitHealthMax is clear and UnitHealth secret (run 3): both go to the widget unchanged; no unit -> empty bar
        pcall(b.SetMinMaxValues, b, 0, mx)
        pcall(b.SetValue, b, hv)
        pcall(b.value.SetText, b.value, hv)   -- FontString passthrough, never read back
        return hv
    end
    pcall(b.SetMinMaxValues, b, 0, 1) pcall(b.SetValue, b, 0) b.value:SetText(GREY .. "no unit|r")
    return nil
end

-- v2.2.4: the body is a list of lines rendered into a pool of one-line FontStrings (only changed lines are re-set):
-- no 2.7 KB string built per refresh, SetText only for changed lines. (The bench's aged-session growth of the old
-- one-string body, 0.27 -> 5.4 ms per refresh, turned out to be a host-allocator artifact: glibc consolidates its
-- fastbins on the first >= 1 KB malloc after a large free, see tests/perf_bench.lua. Smaller, fewer allocations
-- still help in game.)
function H.TextLines()
    local L = {}
    local function add(s) L[#L + 1] = s end
    -- restrictions
    local cra = g("C_RestrictedActions")
    local parts = {}
    for t = 0, 5 do
        local st
        if type(cra) == "table" and type(cra.GetAddOnRestrictionState) == "function" then
            local ok, v = pcall(cra.GetAddOnRestrictionState, t)
            st = ok and (ns.IsSecret(v) and "secret" or v) or nil
        end
        local c = (st == 2 and RED) or (st == 1 and YELLOW) or GREEN
        parts[#parts + 1] = c .. RNAMES[t] .. "=" .. tostring(SNAMES[st] or st or "?") .. "|r"
    end
    add(WHITE .. "Restrictions|r " .. table.concat(parts, " "))
    local function bool(path) local f = ns.Resolve(path) if type(f) ~= "function" then return "absent" end
        local ok, v = pcall(f) if not ok then return "err" end if ns.IsSecret(v) then return "secret" end return tostring(v) end
    add("  always-on: combat log restricted=" .. bool("C_CombatLog.IsCombatLogRestricted") .. ", addon chat restricted="
        .. bool("C_ChatInfo.AreOutgoingAddonChatMessagesRestricted"))
    -- v2.2.8: engine health first (runs 6/6b: the HSM was down for whole captures and nothing showed it)
    local hh = ns.Inference and ns.Inference.health
    if type(hh) == "table" and (hh.state == "down" or hh.state == "degraded") then
        local failedNames = {}
        for k in pairs(hh.failed or {}) do failedNames[#failedNames + 1] = k end
        table.sort(failedNames)
        add((hh.state == "down" and (RED .. "ENGINE DOWN") or (YELLOW .. "engine degraded")) .. "|r: "
            .. table.concat(failedNames, ", ") .. " failed (see /fdump errors)")
    end
    local hs = ns.Inference and ns.Inference.hs
    if not hs then
        add(GREY .. "HSM not running (starts with an FD_Logs capture; /fdump hsm start to run it now)|r")
        return L
    end
    local c = hs.counters
    local secrets = ns.Inference.unreadable or 0   -- v2.2.3: running counter (was a walk over all inputs per redraw)
    H.countdown = false
    add(string.format("%sCounters|r predictions %d, inferences %d, %scontradictions %d|r, unreadable inputs %d, casts %d, aura events %d",
        WHITE, c.predictions, c.inferences, c.contradictions > 0 and RED or GREEN, c.contradictions, secrets, c.casts, c.auraEvents))
    -- cast state
    for _, u in ipairs({ "player", "target" }) do
        local cs = hs:CastState(ns.Inference.KeyOf(u))
        if cs and cs.active then
            add(string.format("  %s: %s%s %s|r (since %s%s)", u, GREEN, cs.kind, cs.spell and spellName(cs.spell) or "spell secret",
                fmt(now() - cs.start), cs.ends and (", predicted end in " .. fmt(cs.ends - now())) or ""))
        else add("  " .. u .. ": " .. GREY .. "not casting|r") end
    end
    -- auras per unit
    add(WHITE .. "Auras (known / predicted)|r")
    for _, u in ipairs({ "player", "target", "focus", "party1", "party2", "party3", "party4" }) do
        local key = ns.Inference.KeyOf(u)
        local st = hs:UnitState(key)
        if st then
            local n = 0
            for _, a in pairs(st.auras) do
                n = n + 1
                if n <= 12 then
                    local col = COL[a.source] or GREY
                    local rem = a.expires and fmt(a.expires - now()) or "?"
                    if a.expires then H.countdown = true end
                    add(string.format("  %s%s|r %s%s|r  [%s via %s, conf %s] stacks %s, remaining %s", WHITE, u, col, spellName(a.spell),
                        a.source, a.rule, a.conf, tostring(a.applications or "?"), rem))
                end
            end
            if n == 0 then add("  " .. u .. ": " .. GREY .. "no known auras|r") end
        end
    end
    -- cooldowns (v2.2.4 CooldownTracker: per-spell state fused from cast / isActive / isOnGCD / category / fails)
    add(WHITE .. "Cooldowns (tracker)|r")
    local any = false
    local seen = {}
    local function cdLine(id)
        if seen[id] then return end
        seen[id] = true
        local st = hs.Cooldown and hs:Cooldown(id)
        if st and st.state == "cooling" then
            any = true
            H.countdown = true
            local col = (st.confidence == "high") and GREEN or YELLOW
            add(string.format("  %s%s|r ready in %s (%s, %s%s)", col, spellName(id), fmt(st.remaining), st.source or "?", st.confidence or "?",
                st.shared and (", shared with " .. spellName(st.shared)) or ""))
        end
    end
    -- at most CD_LINES tracker lines per refresh (O(1) text work even with dozens of spells cooling)
    local CD_LINES, shown, more = 8, 0, 0
    for id in pairs((hs.cd and hs.cd.active) or {}) do
        if shown < CD_LINES then local before = #L cdLine(id) if #L > before then shown = shown + 1 end else more = more + 1 end
    end
    if more > 0 then add("  " .. GREY .. "+" .. more .. " more tracked (cooling or GCD)|r") end
    for id in pairs(hs.cooldowns) do cdLine(id) end
    if not any then add("  " .. GREY .. "none cooling|r") end
    local gcd = hs.GCD and hs:GCD()
    if gcd then
        H.countdown = true
        add(string.format("  GCD: %s left of %.2f s (%s, %s)", fmt(gcd.remaining), gcd.length or 0, spellName(gcd.spell), gcd.source or "?"))
    end
    -- last predictions
    add(WHITE .. "Last predictions|r")
    local preds = hs.predictions
    for i = #preds, math.max(1, #preds - 7), -1 do
        local p = preds[i]
        local oc = p.outcome
        local col = (oc == "contradicted" and RED) or (oc and GREEN) or GREY
        local extra = ""
        if p.summon then
            local eng = p.summon.engineDuration and (" (engine " .. fmt(p.summon.engineDuration) .. ")") or ""
            extra = ", summon " .. fmt(p.summon.duration) .. eng
        end
        if p.dispel then extra = extra .. ", dispel" end
        add(string.format("  %s%s|r on %s: aura %s, cd %s, amount %s%s  %s%s|r", WHITE, spellName(p.spell), unitLabel(hs, p.unit),
            p.aura and fmt(p.aura.duration) or "-", p.cooldownEnds and fmt(p.cooldownEnds - p.t) or "-",
            p.amount and (tostring(p.amount.min) .. "-" .. tostring(p.amount.max)) or "-", extra, col,
            oc or ((p.summon or p.dispel or p.amount) and "unverified live (scored offline vs combat log)" or "unverified")))
    end
    -- v2.2.4: source attribution + damage meter
    local f = hs.Fight and hs:Fight()
    add(WHITE .. "Attribution (UNIT_COMBAT + timing; no CLEU)|r")
    if f then
        local sch = {}
        for k, v in pairs(f.otherSchools or {}) do sch[#sch + 1] = (SCHOOL[tonumber(k)] or ("school " .. k)) .. " " .. v end
        table.sort(sch)
        add(string.format("  damage on targets: %smine %d|r (%d hits) / %sother %d|r (%d hits%s); crits %d, misses %d",
            GREEN, f.dmg.mine, f.dmg.mineN, f.dmg.other > 0 and YELLOW or GREY, f.dmg.other, f.dmg.otherN,
            #sch > 0 and (": " .. table.concat(sch, ", ")) or "", f.dmg.crit, f.dmg.miss))
        local r = {}
        for k, v in pairs(f.dmg.rules or {}) do r[#r + 1] = k .. " " .. v end
        table.sort(r)
        if #r > 0 then add("  rules: " .. table.concat(r, ", ")) end
        add(string.format("  heals on me: mine %d / other %d; taken %d (%d hits, %d avoided); interrupts mine %d / other %d; target auras mine %d / other %d",
            f.heal.mine, f.heal.other, f.taken.amount, f.taken.n, f.taken.miss, f.interrupts.mine, f.interrupts.other, f.auras.mine, f.auras.other))
        if f.dm then
            local dmd = f.dm
            add(string.format("  %sdamage meter (after combat, clear)|r: me %s, heal %s, interrupts %s, dispels %s, taken %s -> others on my targets %s",
                WHITE, tostring(dmd.damage), tostring(dmd.healing), tostring(dmd.interrupts),
                tostring(dmd.dispels), tostring(dmd.taken),
                type(dmd.damage) == "number" and tostring(math.max(0, f.dmg.mine + f.dmg.other - dmd.damage)) or "?"))
        end
        local rc = f.reconcile or (hs.lastReconcile)
        if rc and rc.summary then
            local s = rc.summary
            add(string.format("  %sreconcile|r: match %d / off %d / unexplained %d",
                WHITE, s.match or 0, s.off or 0, s.unexplained or 0))
            if rc.metrics then
                for _, name in ipairs({ "damage", "healing", "interrupts", "dispels", "taken" }) do
                    local m = rc.metrics[name]
                    if m then
                        local col = (m.status == "match" and GREEN) or (m.status == "off" and YELLOW) or GREY
                        add(string.format("    %s%s|r live=%s dm=%s Δ=%s (%s)",
                            col, name, tostring(m.live), tostring(m.dm), tostring(m.delta), tostring(m.status)))
                    end
                end
            end
        elseif f.liveEst then
            local e = f.liveEst
            add(string.format("  %slive estimate|r: dmg %s heal %s int %s dispel %s taken %s",
                GREY, tostring(e.damage), tostring(e.healing), tostring(e.interrupts),
                tostring(e.dispels), tostring(e.taken)))
        end
        -- world units (compact): show up to 6 raw keys with live taken/dmg
        if f.world then
            local rows = {}
            for id, w in pairs(f.world) do
                if type(id) == "string" and (id == "player" or id:find("^npc:") or id:find("^player:") or id:find("^pet:")) then
                    rows[#rows + 1] = { id = id, w = w }
                end
            end
            table.sort(rows, function(a, b) return tostring(a.id) < tostring(b.id) end)
            if #rows > 0 then
                add(WHITE .. "  world units (meter keys)|r")
                for i = 1, math.min(6, #rows) do
                    local wu = rows[i]
                    local w = wu.w
                    add(string.format("    %s dmg=%s taken=%s int=%s dtps≈%s",
                        wu.id, tostring(w.dmg), tostring(w.taken), tostring(w.interrupts),
                        w.dtps and string.format("%.0f", w.dtps) or "-"))
                end
            end
        end
    else add("  " .. GREY .. "no fight yet|r") end
    for i = #hs.contradictions, math.max(1, #hs.contradictions - 3), -1 do
        local x = hs.contradictions[i]
        add(string.format("  %scontradiction|r %s %s on %s (%.1fs early, rule %s)", RED, x.kind, spellName(x.spell), unitLabel(hs, x.unit),
            x.early or 0, tostring(x.rule)))
    end
    H.LedgerText(L, hs)
    return L
end

function H.Text() return table.concat(H.TextLines(), "\n") end

-- v2.2.4 ledger section: live (green) vs cached (yellow fresh / grey stale) vs resolved (orange: alias / fingerprint)
local ORANGE = "|cffff9933"
local CONF_COLOR = { live = GREEN, ["cached-fresh"] = YELLOW, ["cached-stale"] = GREY, ["maybe-removed"] = RED,
    alias = ORANGE, fingerprint = ORANGE, cached = YELLOW, none = GREY }
H.CONF_COLOR = CONF_COLOR
function H.LedgerText(L, hs)
    local Ld = hs and hs.ledger
    if not Ld then return end
    L[#L + 1] = ""
    L[#L + 1] = WHITE .. "Ledger|r (" .. GREEN .. "live|r / " .. YELLOW .. "cached|r / " .. GREY .. "stale|r / " .. ORANGE .. "resolved|r)"
    local st = ns.Identity and ns.Identity.state or {}
    for _, tok in ipairs({ "target", "targettarget", "focus", "focustarget", "pet" }) do
        local x = st[tok]
        if x then
            local col = CONF_COLOR[x.how] or GREY
            local e = x.guid and Ld.data.guid and Ld.data.guid[x.guid]
            local name = e and e.name or "?"
            L[#L + 1] = string.format("  %-13s %s%s|r  %s  lvl %s  maxHP %s  [%s, %s]", tok, col, tostring(name), tostring(x.link or "?"),
                tostring(e and e.level or "?"), tostring(e and e.hpMax or "?"), tostring(x.how), tostring(x.comp or "-"))
        end
    end
    local cur, max, conf, unk = nil, nil, nil, nil
    if hs.Health then cur, max, conf, unk = hs:Health("player") end
    if cur then
        local col = conf == "high" and GREEN or (conf == "medium" and YELLOW or GREY)
        L[#L + 1] = string.format("  player HP (est.) %s%d / %d|r  (%s, %d unexplained change(s))", col, cur, max or 0, tostring(conf), unk or 0)
    end
    for _, u in ipairs({ "player", "target" }) do
        local key = (u == "player") and "player" or ns.Inference.KeyOf("target")
        local list = hs.CachedAuras and hs:CachedAuras(key) or {}
        if #list > 0 then
            local parts = {}
            for i = 1, math.min(#list, 6) do
                local a = list[i]
                parts[#parts + 1] = (CONF_COLOR[a.conf] or GREY) .. spellName(a.spell) .. "|r"
            end
            L[#L + 1] = string.format("  cached auras on %s: %s", u, table.concat(parts, ", "))
        end
    end
    local ec = hs.EnemyCast and hs:EnemyCast(ns.Inference.KeyOf("target"))
    if ec then
        L[#L + 1] = string.format("  target casting: %s%s|r elapsed %.1fs%s", ec.pred and YELLOW or GREY, unitLabel(hs, ec.key or "?"), ec.elapsed or 0,
            ec.pred and string.format(", interrupt window %.1fs left (model %.2fs, n=%d)", ec.remaining or 0, ec.pred, ec.n or 0) or ", no model yet")
        H.countdown = true
    end
    local vc = hs.verdicts or {}
    local v, c, u = 0, 0, 0
    for k, n in pairs(vc) do
        local x = k:sub(-1)
        if x == "V" then v = v + n elseif x == "C" then c = c + n elseif x == "U" then u = u + n end
    end
    L[#L + 1] = string.format("  live checks: %s%d verified|r  %s%d contradicted|r  %s%d unverified|r   ledger %d ids / %d auras",
        GREEN, v, c > 0 and RED or GREY, c, GREY, u, Ld:Count("guid"), Ld:Count("aura"))
end

-- rows 9-10 (dirty-only, with the text body)
function H.RowsText(hs)
    if not (frame and frame.attrRow) then return end
    local f = hs and hs.Fight and hs:Fight()
    if not f then
        frame.attrRow.value:SetText(GREY .. "no fight yet|r")
        frame.dmRow.value:SetText(GREY .. "-|r")
        return
    end
    frame.attrRow.value:SetText(string.format("%smine %d|r  %sother %d|r%s", GREEN, f.dmg.mine, f.dmg.other > 0 and YELLOW or GREY, f.dmg.other,
        f.stop and (GREY .. "  (ended)|r") or ""))
    local dm = f.dm
    frame.dmRow.value:SetText(string.format("int %d/%d  heal %d/%d  %s", f.interrupts.mine, f.interrupts.other, f.heal.mine, f.heal.other,
        dm and string.format("DM me %s int %s", tostring(dm.damage), tostring(dm.interrupts)) or (GREY .. "DM after combat|r")))
end

function H.RenderLines(L)
    local child = frame and frame.child
    if not child then return end
    for i = 1, #L do
        local fs = linePool[i]
        if not fs then
            fs = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            if i == 1 then fs:SetPoint("TOPLEFT", 0, 0) else fs:SetPoint("TOPLEFT", linePool[i - 1], "BOTTOMLEFT", 0, 0) end
            pcall(fs.SetWidth, fs, (frame.body and frame.body.GetWidth and frame.body:GetWidth()) or 590)
            pcall(fs.SetWordWrap, fs, true)
            fs:SetJustifyH("LEFT")
            linePool[i] = fs
        end
        if fs._t ~= L[i] then fs._t = L[i] fs:SetText(L[i]) end   -- interned short strings: pointer compare
        if fs._h then fs._h = nil fs:Show() end
    end
    for i = #L + 1, #linePool do
        local fs = linePool[i]
        if not fs._h then fs._h = true fs:Hide() end
    end
    H.lineCount = #L
end

-- one throttled step; returns true while there is more work (keeps the OnUpdate installed)
function H.Step()
    if not frame or not frame:IsShown() then return false end
    local b = frame.bars
    local hs = ns.Inference and ns.Inference.hs
    local busy = false
    -- predicted bars (clear numbers): 10 Hz only while one is running
    local pc = hs and hs:CastState("player")
    if predBar(b.pCastPred, pc and pc.active and pc.start, pc and pc.active and pc.ends, "not casting") then busy = true end
    local tkey = ns.Inference.KeyOf("target")
    local tc = hs and hs:CastState(tkey)
    local ec = hs and hs.EnemyCast and hs:EnemyCast(tkey)
    if ec and ec.pred and not (tc and tc.active and tc.ends) then
        -- v2.2.4 interrupt window: learned per-NPC cast duration (spellID secret, START/SUCCEEDED timing clear)
        if predBar(b.tCastPred, ec.start, ec.start + ec.pred, "not casting") then busy = true end
        if H.tLabel ~= "iw" then H.tLabel = "iw" b.tCastPred.label:SetText("interrupt window (pred)") end
    else
        if predBar(b.tCastPred, tc and tc.active and tc.start, tc and tc.active and tc.ends, "not casting") then busy = true end
        if H.tLabel == "iw" then H.tLabel = nil b.tCastPred.label:SetText("target cast (pred)") end
    end
    local last, lastStart, lastEnds
    for id, cd in pairs((hs and hs.cooldowns) or {}) do if not lastStart or cd.start > lastStart then last, lastStart, lastEnds = id, cd.start, cd.ends end end
    do   -- tracker entry (learned / observed / shared) wins: the latest cooldown start, kept by the tracker (O(1) per step)
        local id = hs and hs.cd and hs.cd.latest
        local c = id and hs.cd.spells[id]
        if c and c.cooling and c.start and c.ends and (not lastStart or c.start >= lastStart) then last, lastStart, lastEnds = id, c.start, c.ends end
    end
    local gcd = hs and hs.GCD and hs:GCD()
    if predBar(b.gcdPred, gcd and (gcd.ends - gcd.length), gcd and gcd.ends, "ready") then busy = true end
    if last then
        if predBar(b.cdPred, lastStart, lastEnds) then busy = true end
        if H.cdSpell ~= last then
            H.cdSpell = last
            b.cdPred.label:SetText("cooldown (pred): " .. spellName(last))
            H_flags.cd = true
        end
    else
        if H.cdSpell ~= false then H.cdSpell = false predBar(b.cdPred) b.cdPred.label:SetText("cooldown (pred, clear)") H_flags.cd = true end
    end
    -- engine bars: only when their events arrived (passthrough; the engine animates duration objects itself)
    if H_flags.cast then
        H_flags.cast = false
        realCast(b.pCastReal, "player")
        realCast(b.tCastReal, "target")
    end
    if H_flags.cd then
        H_flags.cd = false
        local cs = g("C_Spell")
        local shown = false
        if last and type(cs) == "table" then
            if type(cs.GetSpellTexture) == "function" then
                local okT, tex = pcall(cs.GetSpellTexture, last)
                if okT and tex ~= nil then pcall(frame.cdIcon.SetTexture, frame.cdIcon, tex) end
            end
            if type(cs.GetSpellCooldownDuration) == "function" and frame.cd.SetCooldownFromDurationObject then
                local ok, dur = pcall(cs.GetSpellCooldownDuration, last)
                if ok and dur ~= nil and pcall(frame.cd.SetCooldownFromDurationObject, frame.cd, dur) then shown = true end
            end
        end
        frame.cdValue:SetText(shown and ("engine: " .. spellName(last)) or (GREY .. "none|r"))
    end
    if H_flags.hp then
        H_flags.hp = false
        realHealth(b.pHealth, "player")
        realHealth(b.tHealth, "target")
    end
    -- text body: rebuilt when the HSM state moved (dirty) at most every updateInterval; countdowns tick at 1 Hz
    local t = now()
    local ver = hs and hs.version or 0
    local interval = tonumber(cfg().updateInterval) or 0.5
    local want = H_dirty or ver ~= lastVersion
    if want and t - lastText < interval then busy = true
    elseif want or (H.countdown and t - lastText >= 1) then
        H_dirty, lastVersion, lastText = false, ver, t
        if frame.logLevel and ns.ReplayLog and ns.ReplayLog.StatusLine then
            local sl = ns.ReplayLog.StatusLine()
            if frame._logLevel ~= sl then frame._logLevel = sl frame.logLevel:SetText(GREY .. sl .. "|r") end
        end
        H.RenderLines(H.TextLines())
        H.RowsText(hs)
        H.updates = (H.updates or 0) + 1
    end
    if H.countdown then busy = true end
    return busy
end

-- full refresh (Show, tests, /fdump hsm)
function H.Update()
    if not frame or not frame:IsShown() then return end
    H_dirty, H_flags.hp, H_flags.cast, H_flags.cd = true, true, true, true
    lastText = -100
    H.Step()
end

function H.Show()
    if not frame then build() end
    frame:Show()
    registerUI(true)
    pcall(H.Update)
    frame:SetScript("OnUpdate", onUpdate)
    return true
end
function H.Hide()
    if frame then
        frame:Hide()
        frame:SetScript("OnUpdate", nil)
        registerUI(false)
        savePos()
    end
    return false
end
function H.Toggle()
    if frame and frame:IsShown() then return H.Hide() end
    return H.Show()
end
function H.IsShown() return frame ~= nil and frame:IsShown() end

ns.captureModules = ns.captureModules or {}
ns.captureModules[#ns.captureModules + 1] = { name = "HSM window",
    start = function() if cfg().autoShow ~= false then H.Show() return true end return false end,
    stop = function() if H.IsShown() then H.Hide() end return nil end }
