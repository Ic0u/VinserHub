--[[
    Vinser Hub - Sanguine Boost Module
    Forward velocity impulse triggered ONLY by dedicated keybind.
    Does NOT intercept the natural in-game Z skill at all.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local velocityPower = 400
local boostDuration = 0.9
local isCooldown = false
local sanguineEnabled = false

local function doBoost()
    local character = player.Character
    if not character then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local cam = Workspace.CurrentCamera
    local dir = cam and cam.CFrame.LookVector or hrp.CFrame.LookVector

    local att = Instance.new("Attachment")
    att.Name = "VinserSanguineAttachment"
    att:SetAttribute("VinserPhysics", true)
    att.Parent = hrp

    local lv = Instance.new("LinearVelocity")
    lv.Name = "VinserSanguineVelocity"
    lv:SetAttribute("VinserPhysics", true)
    lv.MaxForce = math.huge
    lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    lv.VectorVelocity = dir * velocityPower
    lv.Attachment0 = att
    lv.Parent = hrp

    _G.Vinser_Boosting = true
    _G.DarlingX_Boosting = true

    task.delay(boostDuration, function()
        if lv and lv.Parent then lv:Destroy() end
        if att and att.Parent then att:Destroy() end
        _G.Vinser_Boosting = false
        _G.DarlingX_Boosting = false
    end)
end

local function triggerBoost()
    if not sanguineEnabled then return end
    if isCooldown then return end
    isCooldown = true
    doBoost()
    task.delay(0.35, function()
        isCooldown = false
    end)
end

local SanguineModule = {
    DoBoost = doBoost,
    Trigger = triggerBoost,
    SetKeybind = function(key)
        -- keybind is handled by main.lua KeyPicker, not internally
    end,
    SetEnabled = function(state)
        sanguineEnabled = (state == true)
        _G.DarlingX_SanguineBoost = sanguineEnabled
        _G.VinsersHub_SanguineBoost = sanguineEnabled
    end,
    SetWidgetVisible = function(state)
        -- widget visibility handled elsewhere
    end,
}

_G.VinsersHub_SanguineBoostMod = SanguineModule

return SanguineModule
