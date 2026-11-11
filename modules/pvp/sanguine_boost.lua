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

local boundSanguineKey = Enum.KeyCode.Z

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if UserInputService:GetFocusedTextBox() then return end
    if not (_G.DarlingX_SanguineBoost or _G.VinsersHub_SanguineBoost) then return end

    local match = false
    if typeof(boundSanguineKey) == "EnumItem" then
        match = (input.KeyCode == boundSanguineKey)
    elseif type(boundSanguineKey) == "string" then
        match = (input.KeyCode.Name == boundSanguineKey)
    end

    if match then
        triggerBoostWithVisual()
    end
end)

-- Auto-detect Sanguine Art Z move animation (14586872029) like Aurora X
local function hookSanguineAnim(char)
    if not char then return end
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        hum.AnimationPlayed:Connect(function(track)
            if not (_G.DarlingX_SanguineBoost or _G.VinsersHub_SanguineBoost) then return end
            local anim = track.Animation
            local id = anim and tostring(anim.AnimationId) or ""
            if id:find("14586872029") then
                triggerBoostWithVisual()
            end
        end)
    end
end

if player.Character then hookSanguineAnim(player.Character) end
player.CharacterAdded:Connect(hookSanguineAnim)

local SanguineModule = {
    DoBoost = doBoost,
    Trigger = triggerBoostWithVisual,
    SetKeybind = function(key)
        if typeof(key) == "EnumItem" then
            boundSanguineKey = key
        elseif type(key) == "string" and Enum.KeyCode[key] then
            boundSanguineKey = Enum.KeyCode[key]
        else
            boundSanguineKey = key
        end
    end,
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
