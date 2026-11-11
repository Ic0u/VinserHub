-- blacklist

local Blacklist = {}
local Core = nil

local function getCore()
    if Core then return Core end
    local env = (getgenv and getgenv()) or _G
    if env.DarlingCombatCore then
        Core = env.DarlingCombatCore
        return Core
    end
    if _G.DarlingCombatCore then
        Core = _G.DarlingCombatCore
        return Core
    end
    local hub = env.DarlingHub or _G.DarlingHub
    if hub and hub.Require then
        local ok, res = pcall(function()
            return hub:Require("modules/combat/aimbot_core.lua")
        end)
        if ok and res then
            Core = res
            env.DarlingCombatCore = Core
            _G.DarlingCombatCore = Core
            return Core
        end
    end
    local candidatePaths = {
        "DarlingX/modules/combat/aimbot_core.lua",
        "modules/combat/aimbot_core.lua",
        "darling-hub/modules/combat/aimbot_core.lua",
    }
    for _, p in ipairs(candidatePaths) do
        if isfile and isfile(p) then
            local ok, res = pcall(function() return loadstring(readfile(p))() end)
            if ok and res then
                Core = res
                _G.DarlingCombatCore = Core
                return Core
            end
        end
    end
    return nil
end

function Blacklist.set(category, key, state)
    local core = getCore()
    local boolState = (state == true)

    if core and core.BlacklistedKeys and core.BlacklistedKeys[category] then
        core.BlacklistedKeys[category][key] = boolState
    end

    if _G.DarlingHub and _G.DarlingHub.Settings and _G.DarlingHub.Settings.Blacklist then
        local b = _G.DarlingHub.Settings.Blacklist
        if b[category] then
            b[category][key] = boolState
        end
    end
end

function Blacklist.add(category, key)
    return Blacklist.set(category, key, true)
end

function Blacklist.remove(category, key)
    return Blacklist.set(category, key, false)
end

function Blacklist.get(category, key)
    local core = getCore()
    if core and core.BlacklistedKeys and core.BlacklistedKeys[category] then
        if core.BlacklistedKeys[category][key] ~= nil then
            return core.BlacklistedKeys[category][key]
        end
    end
    if _G.DarlingHub and _G.DarlingHub.Settings and _G.DarlingHub.Settings.Blacklist then
        local b = _G.DarlingHub.Settings.Blacklist
        if b[category] and b[category][key] ~= nil then
            return b[category][key]
        end
    end
    return false
end

function Blacklist.reset()
    local core = getCore()
    if core and core.BlacklistedKeys then
        for cat, keys in pairs(core.BlacklistedKeys) do
            for k, _ in pairs(keys) do
                core.BlacklistedKeys[cat][k] = false
            end
        end
    end
    if _G.DarlingHub and _G.DarlingHub.Settings and _G.DarlingHub.Settings.Blacklist then
        local b = _G.DarlingHub.Settings.Blacklist
        for cat, keys in pairs(b) do
            for k, _ in pairs(keys) do
                b[cat][k] = false
            end
        end
    end
end

-- Applies array or map from WindUI multi-dropdown
function Blacklist.apply(selection)
    Blacklist.reset()
    if type(selection) ~= "table" then return end
    for k, v in pairs(selection) do
        local item = nil
        if type(v) == "string" then
            item = v
        elseif v == true and type(k) == "string" then
            item = k
        end
        if item then
            local cat, key = item:match("^(%a+)%s+(%a+)$")
            if cat and key then
                Blacklist.set(cat, key, true)
            end
        end
    end
end

function Blacklist.getTable()
    local core = getCore()
    if core then return core.BlacklistedKeys end
    if _G.DarlingHub and _G.DarlingHub.Settings then
        return _G.DarlingHub.Settings.Blacklist
    end
    return nil
end

return Blacklist
