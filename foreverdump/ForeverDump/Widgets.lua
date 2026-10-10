-- ForeverDump v2 - widgets: instantiate every widget / region / animation type
-- and list the methods on its metatable __index, plus IsObjectType inheritance.
local _, ns = ...

-- Creatable on Forever 1.60.1.70245 (confirmed by the 2026-10-07 in-game run: CreateFrame succeeded for all of these).
local FRAME_TYPES = {
    "Frame", "Button", "CheckButton", "EditBox", "ScrollFrame", "Slider", "StatusBar", "Cooldown",
    "GameTooltip", "MessageFrame", "ScrollingMessageFrame", "SimpleHTML", "ColorSelect",
    "Model", "PlayerModel", "DressUpModel", "CinematicModel", "TabardModel", "ModelScene",
    "FogOfWarFrame", "UnitPositionFrame", "QuestPOIFrame", "ScenarioPOIFrame", "ArchaeologyDigSiteFrame",
    "OffScreenFrame",
}
-- Documented in APIDocumentation (Simple*/FrameAPI* widget systems) but NOT creatable with CreateFrame on Forever 70245.
-- CreateFrame fails inside pcall, but the client ALSO prints a LUA_WARNING to Logs/Client.log / chat for the first three
-- (pcall cannot stop a warning; it is not a Lua error and never reaches geterrorhandler). So normal runs never call
-- CreateFrame for them: they are documented from an existing instance (EnumerateFrames) when one exists, else recorded
-- as notCreatable. `/fdump widgets risky` still tries them.
local NOT_CREATABLE = {
    MapScene = { reason = "LUA_WARNING 'Unable to create frame type: MapScene'", doc = "SimpleMapSceneAPI" },
    VectorGraphics = { reason = "LUA_WARNING 'Unknown frame type: VectorGraphics'", doc = "SimpleVectorGraphicsAPI" },
    ModelFFX = { reason = "LUA_WARNING 'Unable to create frame type: ModelFFX'", doc = "SimpleModelFFXAPI" },
    Blob = { reason = "CreateFrame(): Unknown frame type 'Blob' (no warning)", doc = "FrameAPIBlob" },
    PingPinFrame = { reason = "CreateFrame(): Unknown frame type 'PingPinFrame' (no warning)", doc = "PingPinFrameAPI" },
}
local NOT_CREATABLE_ORDER = { "MapScene", "VectorGraphics", "ModelFFX", "Blob", "PingPinFrame" }
ns.WidgetNotCreatable = NOT_CREATABLE
-- Opt-in only (`/fdump widgets risky`): heavy or singleton-ish types, plus the not-creatable ones above.
local RISKY_TYPES = { "Browser", "Checkout", "MovieFrame", "Minimap", "WorldFrame", "NamePlate",
    "MapScene", "VectorGraphics", "ModelFFX", "Blob", "PingPinFrame" }

local ANIM_TYPES = {
    "Animation", "Alpha", "Translation", "LineTranslation", "Scale", "LineScale", "Rotation",
    "Path", "FlipBook", "VertexColor", "TextureCoordTranslation", "RadialProgress",
}

-- Abstract/base names checked with IsObjectType to reconstruct the hierarchy.
local ABSTRACT = {
    "Object", "ScriptObject", "ScriptRegion", "Region", "LayeredRegion", "TextureBase", "FontInstance",
    "Frame", "Model", "PlayerModel", "Animation", "AnimationGroup", "ControlPoint", "Font",
    "Texture", "MaskTexture", "Line", "FontString", "ModelSceneFrameActorBase", "TabardModelBase",
    "CharacterModelBase", "Button", "SimpleScrollFrame", "POIFrame",
}

local function methodsOf(obj)
    local mt = getmetatable(obj)
    local idx = type(mt) == "table" and rawget(mt, "__index")
    local list = {}
    if type(idx) == "table" then
        for k, v in next, idx do
            if type(k) == "string" and type(v) == "function" then list[#list + 1] = k end
        end
    end
    table.sort(list)
    return list, mt ~= nil, type(idx)
end

local function isA(obj, candidates)
    local out = {}
    if type(obj.IsObjectType) ~= "function" then return out end
    for _, name in ipairs(candidates) do
        local ok, yes = pcall(obj.IsObjectType, obj, name)
        if ok and yes == true then out[#out + 1] = name end
    end
    return out
end

local function record(types, failures, label, ok, obj, candidates)
    if not ok or obj == nil then
        failures[label] = tostring(obj or "nil")
        return
    end
    local methods, hasMt, idxType = methodsOf(obj)
    local okType, objectType = pcall(function() return obj:GetObjectType() end)
    types[label] = {
        objectType = okType and objectType or nil,
        methods = methods,
        count = #methods,
        isA = isA(obj, candidates),
        metatable = hasMt,
        indexType = idxType,
    }
end

local function toSet(list)
    local s = {}
    for _, v in ipairs(list) do s[v] = true end
    return s
end

ns.RegisterSection({
    name = "widgets",
    desc = "widget/region/animation types: metatable methods, IsObjectType chain, overlap ('/fdump widgets risky' adds Browser etc.)",
    inAll = true,
    run = function(_, args)
        local types, failures = {}, {}
        local list = {}
        for _, t in ipairs(FRAME_TYPES) do list[#list + 1] = t end
        if args and args[1] == "risky" then
            for _, t in ipairs(RISKY_TYPES) do list[#list + 1] = t end
        end
        local candidates = {}
        for _, t in ipairs(ABSTRACT) do candidates[#candidates + 1] = t end
        for _, t in ipairs(list) do candidates[#candidates + 1] = t end
        for _, t in ipairs(ANIM_TYPES) do candidates[#candidates + 1] = t end

        local risky = args and args[1] == "risky"
        local notCreatable = {}
        if not risky then
            -- document not-creatable types from an existing instance, without CreateFrame
            local want, found = {}, {}
            for _, t in ipairs(NOT_CREATABLE_ORDER) do want[t] = true end
            local enum = rawget(_G, "EnumerateFrames")
            if type(enum) == "function" then
                local okE, f = pcall(enum)
                local guard = 0
                while okE and f and guard < 200000 do
                    guard = guard + 1
                    local okT, ot = pcall(f.GetObjectType, f)
                    if okT and type(ot) == "string" and want[ot] and not found[ot] then found[ot] = f end
                    okE, f = pcall(enum, f)
                end
            end
            for _, t in ipairs(NOT_CREATABLE_ORDER) do
                local info = NOT_CREATABLE[t]
                notCreatable[t] = { reason = info.reason, documentedBy = info.doc, build = "70245" }
                if found[t] then
                    record(types, failures, t, true, found[t], candidates)
                    if types[t] then
                        local okN, nm = pcall(found[t].GetName, found[t])
                        types[t].source = "existing:" .. tostring(okN and nm or "?")
                    end
                    notCreatable[t].existingInstance = true
                end
            end
        end
        local parent = CreateFrame("Frame", nil, UIParent)
        parent:Hide()
        for _, t in ipairs(list) do
            local template = (t == "GameTooltip") and "GameTooltipTemplate" or nil
            local name = (t == "GameTooltip") and "ForeverDumpWidgetProbeTooltip" or nil
            local ok, obj = pcall(CreateFrame, t, name, parent, template)
            if ok and obj and obj.Hide then pcall(obj.Hide, obj) end
            record(types, failures, t, ok, obj, candidates)
            ns.Yield()
        end
        -- regions
        for _, pair in ipairs({ { "Texture", "CreateTexture" }, { "MaskTexture", "CreateMaskTexture" },
                                { "Line", "CreateLine" }, { "FontString", "CreateFontString" } }) do
            local creator = parent[pair[2]]
            if type(creator) == "function" then
                local ok, obj = pcall(creator, parent)
                record(types, failures, pair[1], ok, obj, candidates)
            else
                failures[pair[1]] = "Frame:" .. pair[2] .. " missing"
            end
        end
        -- animations
        local okG, group = pcall(parent.CreateAnimationGroup, parent)
        record(types, failures, "AnimationGroup", okG, group, candidates)
        if okG and group then
            for _, at in ipairs(ANIM_TYPES) do
                local ok, anim = pcall(group.CreateAnimation, group, at)
                record(types, failures, "Anim:" .. at, ok, anim, candidates)
                if at == "Path" and ok and anim and anim.CreateControlPoint then
                    local okP, cp = pcall(anim.CreateControlPoint, anim)
                    record(types, failures, "ControlPoint", okP, cp, candidates)
                end
            end
        end
        -- font object
        local okF, font = pcall(CreateFont, "ForeverDumpWidgetProbeFont")
        record(types, failures, "Font", okF, font, candidates)
        -- userdata script objects (secret-era helpers), if their factories exist
        -- (factory names from the Forever branch of Blizzard_APIDocumentationGenerated; all take no arguments)
        for _, path in ipairs({ "C_DurationUtil.CreateDuration", "C_DurationUtil.CreateManualClock",
                                "C_CurveUtil.CreateCurve", "C_CurveUtil.CreateColorCurve",
                                "C_StringUtil.CreateAbbreviatedNumberFormatter", "C_StringUtil.CreateNumericRuleFormatter",
                                "C_StringUtil.CreateSecondsFormatter", "CreateUnitHealPredictionCalculator" }) do
            local fn = ns.Resolve(path)
            if type(fn) == "function" then
                local ok, obj = pcall(fn)
                record(types, failures, "Userdata:" .. path, ok, obj, candidates)
            end
        end

        -- overlap: methods shared by everything, Region base, Frame base
        local sets = {}
        for label, info in pairs(types) do sets[label] = toSet(info.methods) end
        local function intersect(labels)
            local acc
            for _, l in ipairs(labels) do
                if sets[l] then
                    if not acc then
                        acc = {}
                        for k in pairs(sets[l]) do acc[k] = true end
                    else
                        for k in pairs(acc) do if not sets[l][k] then acc[k] = nil end end
                    end
                end
            end
            return acc or {}
        end
        local allLabels = ns.SortedKeys(types)
        local common = intersect(allLabels)
        local region = intersect({ "Texture", "FontString", "Line", "MaskTexture" })
        local frameBase = sets.Frame or {}
        local overlap = { commonToAll = ns.SortedList(common), regionBase = ns.SortedList(region),
                          frameBase = ns.SortedList(frameBase), perType = {} }
        for label, info in pairs(types) do
            local base = frameBase
            if sets.Texture and (label == "Texture" or label == "MaskTexture" or label == "Line" or label == "FontString") then
                base = region
            elseif not (info.isA and toSet(info.isA).Frame) then
                base = common
            end
            local own = {}
            for _, m in ipairs(info.methods) do if not base[m] then own[#own + 1] = m end end
            overlap.perType[label] = { own = own, inherited = #info.methods - #own }
        end
        ns.SaveSection("widgets", { types = types, failures = failures, overlap = overlap, notCreatable = notCreatable,
                                     counts = { types = #allLabels } })
        local nf = 0
        for _ in pairs(failures) do nf = nf + 1 end
        ns.Print(string.format("widgets: %d types recorded, %d failed to instantiate", #allLabels, nf))
    end,
})
