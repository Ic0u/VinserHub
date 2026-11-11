-- npc aimbot

local NPCAimbot = {}
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

    local paths = {
        "DarlingX/modules/combat/aimbot_core.lua",
        "modules/combat/aimbot_core.lua",
        "darling-hub/modules/combat/aimbot_core.lua",
    }

    for _, p in ipairs(paths) do
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

function NPCAimbot.enable()
    local core = getCore()
    if not core then return false end
    core.NPCAimEnabled = true
    core.startLoop()
    return true
end

function NPCAimbot.disable()
    local core = getCore()
    if not core then return end
    core.NPCAimEnabled = false
    _G.G_NPCSilentAim = false
    if not core.PlayerAimEnabled and not core.LockPlayer then
        _G.currentSilentAimTarget = nil
        _G.DarlingSilentAimTarget = nil
    end
    core.stopLoop()
end

function NPCAimbot.setMaxRange(range)
    local core = getCore()
    if core and type(range) == "number" then
        core.MaxRange = range
    end
end

function NPCAimbot.isEnabled()
    local core = getCore()
    return core and core.NPCAimEnabled or false
end

return NPCAimbot
