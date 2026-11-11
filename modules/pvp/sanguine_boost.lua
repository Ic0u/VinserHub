--[[
    Darling X - Sanguine Boost Z Module
    Exact linear velocity impulse and Z keybind.
    Linked to unified glass widget in extra_widgets.lua.
    Zero emojis, zero third-party references.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local velocityPower = 400
local boostDuration = 0.9
local isCooldown = false

local function doBoost()
    local character = player.Character
    if not character then return end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local cam = Workspace.CurrentCamera or camera
    local dir = cam and cam.CFrame.LookVector or hrp.CFrame.LookVector

    local att = Instance.new("Attachment")
    att.Parent = hrp

    local lv = Instance.new("LinearVelocity")
    lv.MaxForce = math.huge
    lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    lv.VectorVelocity = dir * velocityPower
    lv.Attachment0 = att
    lv.Parent = hrp

    task.delay(boostDuration, function()
        if lv and lv.Parent then lv:Destroy() end
        if att and att.Parent then att:Destroy() end
    end)
end

local function getWidgets()
    if rawget(_G, "DarlingX_ExtraWidgets") then
        return _G.DarlingX_ExtraWidgets
    end
    local hub = rawget(_G, "DarlingHub") or (getgenv and getgenv().DarlingHub)
    if hub and hub.Require then
        local w = hub:Require("modules/pvp/extra_widgets.lua")
        if w then return w end
    end
    local req = (typeof(require) == "function") and require
    if req and script and script.Parent then
        local ok, w = pcall(req, script.Parent.extra_widgets)
        if ok and w then return w end
    end
    return nil
end

local function triggerBoostWithVisual()
    if isCooldown then return end
    isCooldown = true

    doBoost()

    local widgets = getWidgets()
    if widgets and widgets.UpdateSanguineVisual then
        widgets.UpdateSanguineVisual(true)
    end

    task.delay(0.35, function()
        local w = getWidgets()
        if w and w.UpdateSanguineVisual then
            w.UpdateSanguineVisual(false)
        end
        isCooldown = false
    end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Z and _G.DarlingX_SanguineBoost then
        triggerBoostWithVisual()
    end
end)

local SanguineModule = {
    DoBoost = doBoost,
    Trigger = triggerBoostWithVisual,
    SetEnabled = function(state)
        _G.DarlingX_SanguineBoost = (state == true)
        local widgets = getWidgets()
        if widgets and widgets.SetSanguineWidgetVisible then
            widgets.SetSanguineWidgetVisible(state == true)
        end
    end,
    SetWidgetVisible = function(state)
        local widgets = getWidgets()
        if widgets and widgets.SetSanguineWidgetVisible then
            widgets.SetSanguineWidgetVisible(state == true)
        end
    end,
}

return SanguineModule
