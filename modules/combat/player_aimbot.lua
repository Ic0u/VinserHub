-- player aimbot

local Players = game:GetService("Players")

local PlayerAimbot = {}
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

function PlayerAimbot.enable()
    local core = getCore()
    if not core then return false end
    core.PlayerAimEnabled = true
    core.startLoop()
    return true
end

function PlayerAimbot.disable()
    local core = getCore()
    if not core then return end
    core.PlayerAimEnabled = false
    _G.G_PlayerSilentAim = false
    if not core.NPCAimEnabled and not core.LockPlayer then
        _G.currentSilentAimTarget = nil
        _G.DarlingSilentAimTarget = nil
    end
    core.stopLoop()
end

function PlayerAimbot.setHitbox(part)
    local core = getCore()
    if core and type(part) == "string" then
        core.TargetHitbox = part
        core.TargetPart = part
    end
end

function PlayerAimbot.setTeamCheck(state)
    local core = getCore()
    if core then
        core.TeamCheck = (state == true)
    end
end

function PlayerAimbot.setPriority(prio)
    local core = getCore()
    if core and type(prio) == "string" then
        core.TargetPriority = prio
    end
end

function PlayerAimbot.setAimMode(mode)
    local core = getCore()
    if core and type(mode) == "string" then
        core.AimMode = mode
    end
end

function PlayerAimbot.setSelectedPlayer(name)
    local core = getCore()
    if not core then return end
    if not name or name == "" or name == "None" then
        core.SelectedPlayer = nil
    else
        core.SelectedPlayer = Players:FindFirstChild(name)
    end
end

function PlayerAimbot.setMaxRange(range)
    local core = getCore()
    if core and type(range) == "number" then
        core.MaxRange = range
    end
end

function PlayerAimbot.setPrediction(enabled, amount)
    local core = getCore()
    if core then
        if enabled ~= nil then core.PredictionEnabled = enabled end
        if type(amount) == "number" then core.PredictionAmount = amount end
    end
end

function PlayerAimbot.isEnabled()
    local core = getCore()
    return core and core.PlayerAimEnabled or false
end

return PlayerAimbot
