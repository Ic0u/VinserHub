--[[
    Darling Hub - FOV Circle Module
    ScreenGui FOV implementation with UIGradient and UIStroke.
    100% reliable across all executors and platforms (PC, Mobile, Console).
]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local FOV = {}
local isEnabled = false
local renderConnection = nil

-- Configuration State
local currentRadius = 150
local currentThickness = 2
local currentColor = Color3.fromRGB(255, 255, 255)
local currentMode = "Mouse" -- "Mouse" or "Center"
local rainbowEnabled = true
local currentAimMode = "360"

local function isAimModeFov()
    local dx = rawget(_G, "DarlingX")
    if dx and dx.Settings and dx.Settings.Aim and dx.Settings.Aim.Mode then
        return tostring(dx.Settings.Aim.Mode):upper() == "FOV"
    end
    return tostring(currentAimMode):upper() == "FOV"
end

-- ScreenGui Element References
local overlayGui = nil
local ringFrame = nil
local ringStroke = nil
local ringGradient = nil

local function safeParentGui(gui)
    if not gui then return false end
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h and typeof(h) == "Instance" then
            local okP = pcall(function() gui.Parent = h end)
            if okP and gui.Parent == h then return true end
        end
    end
    local lp = LocalPlayer or Players.LocalPlayer
    if lp then
        local pg = lp:FindFirstChildOfClass("PlayerGui") or lp:FindFirstChild("PlayerGui")
        if pg then
            local okP = pcall(function() gui.Parent = pg end)
            if okP and gui.Parent == pg then return true end
        end
    end
    if CoreGui then
        local okP = pcall(function() gui.Parent = CoreGui end)
        if okP and gui.Parent == CoreGui then return true end
    end
    return gui.Parent ~= nil
end

local function makeRainbowSequence()
    local kps = {}
    for i = 0, 6 do
        kps[#kps + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 0.85, 1))
    end
    return ColorSequence.new(kps)
end

local function makeSolidSequence(color)
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0, color),
        ColorSequenceKeypoint.new(1, color),
    })
end

local function cleanupGui()
    if renderConnection then
        pcall(function() renderConnection:Disconnect() end)
        renderConnection = nil
    end
    if overlayGui then
        pcall(function() overlayGui:Destroy() end)
        overlayGui = nil
    end
    ringFrame = nil
    ringStroke = nil
    ringGradient = nil
end

local function buildFovGui()
    if overlayGui and overlayGui.Parent and ringFrame and ringFrame.Parent then
        return true
    end

    cleanupGui()

    local gui = Instance.new("ScreenGui")
    gui.Name = "DarlingHub_FOV"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 1000000
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Enabled = true

    if syn and syn.protect_gui then
        pcall(syn.protect_gui, gui)
    end

    local frame = Instance.new("Frame")
    frame.Name = "Ring"
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Active = false
    frame.Size = UDim2.fromOffset(currentRadius * 2, currentRadius * 2)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.Visible = true
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = currentThickness
    stroke.Color = rainbowEnabled and Color3.fromRGB(255, 255, 255) or currentColor
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Transparency = 0
    stroke.Parent = frame

    local gradient = Instance.new("UIGradient")
    if rainbowEnabled then
        gradient.Color = makeRainbowSequence()
    else
        gradient.Color = makeSolidSequence(currentColor)
    end
    gradient.Parent = stroke

    local okParent = safeParentGui(gui)
    if not okParent then return false end

    overlayGui = gui
    ringFrame = frame
    ringStroke = stroke
    ringGradient = gradient
    return true
end

-- Drawing API fallback
local drawingCircle = nil
local hasDrawing = (typeof(Drawing) == "table" or typeof(Drawing) == "userdata") and (typeof(Drawing.new) == "function")

local function updateDrawingCircle(posX, posY, col)
    if not hasDrawing then return end
    if not drawingCircle then
        pcall(function()
            drawingCircle = Drawing.new("Circle")
            drawingCircle.Filled = false
            drawingCircle.Transparency = 1
        end)
    end
    if drawingCircle then
        pcall(function()
            drawingCircle.Visible = isEnabled and isAimModeFov()
            drawingCircle.Radius = currentRadius
            drawingCircle.Thickness = currentThickness
            drawingCircle.Position = Vector2.new(posX, posY)
            drawingCircle.Color = col
        end)
    end
end

local function onRender()
    if not isEnabled then return end

    if not isAimModeFov() then
        if ringFrame and ringFrame.Visible then
            ringFrame.Visible = false
        end
        if drawingCircle and drawingCircle.Visible then
            pcall(function() drawingCircle.Visible = false end)
        end
        return
    end

    local activeColor = currentColor
    if rainbowEnabled then
        activeColor = Color3.fromHSV((os.clock() * 0.25) % 1, 0.85, 1)
        if ringGradient then
            ringGradient.Rotation = (os.clock() * 90) % 360
        end
        if ringStroke then
            ringStroke.Color = activeColor
        end
    elseif ringStroke then
        ringStroke.Color = currentColor
    end

    local screenPos = Vector2.new(0, 0)
    local cam = Workspace.CurrentCamera
    if UserInputService.TouchEnabled or currentMode == "Center" then
        if ringFrame then ringFrame.Position = UDim2.fromScale(0.5, 0.5) end
        if cam then
            screenPos = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
        end
    else
        local mousePos = UserInputService:GetMouseLocation()
        screenPos = mousePos
        if ringFrame then
            ringFrame.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
        end
    end

    if ringFrame and not ringFrame.Visible then
        ringFrame.Visible = true
    end

    updateDrawingCircle(screenPos.X, screenPos.Y, activeColor)
end

function FOV.enable()
    if isEnabled then return end
    isEnabled = true

    buildFovGui()
    if ringFrame then
        ringFrame.Size = UDim2.fromOffset(currentRadius * 2, currentRadius * 2)
        ringFrame.Visible = isAimModeFov()
    end

    if not renderConnection then
        renderConnection = RunService.RenderStepped:Connect(onRender)
    end

    -- Sincronizar radio con el core de combate
    pcall(function()
        local hub = _G.DarlingHub or (getgenv and getgenv().DarlingHub)
        local core = (_G.DarlingCombatCore) or (getgenv and getgenv().DarlingCombatCore) or (hub and hub.Require and hub:Require("modules/combat/aimbot_core.lua"))
        if core and core.setFOVRadius then
            core.setFOVRadius(currentRadius)
        end
    end)
end

function FOV.disable()
    isEnabled = false
    if drawingCircle then
        pcall(function() drawingCircle.Visible = false end)
    end
    cleanupGui()
end

function FOV.toggle(state)
    if state == nil then state = not isEnabled end
    if state then
        FOV.enable()
    else
        FOV.disable()
    end
    return isEnabled
end

function FOV.setRadius(radius)
    currentRadius = math.clamp(tonumber(radius) or 150, 10, 1200)
    if ringFrame then
        ringFrame.Size = UDim2.fromOffset(currentRadius * 2, currentRadius * 2)
    end
    pcall(function()
        local hub = _G.DarlingHub or (getgenv and getgenv().DarlingHub)
        local core = hub and hub.Require and hub:Require("modules/combat/aimbot_core.lua")
        if core and core.setFOVRadius then
            core.setFOVRadius(currentRadius)
        end
    end)
end

function FOV.setColor(color)
    if color == "Rainbow" or (typeof(color) == "string" and color:lower() == "rainbow") then
        FOV.setRainbow(true)
    elseif typeof(color) == "Color3" then
        rainbowEnabled = false
        currentColor = color
        if ringGradient then
            ringGradient.Color = makeSolidSequence(color)
            ringGradient.Rotation = 0
        end
    end
end

function FOV.setThickness(thickness)
    currentThickness = math.clamp(tonumber(thickness) or 2, 1, 10)
    if ringStroke then
        ringStroke.Thickness = currentThickness
    end
end

function FOV.setMode(mode)
    if mode == "Center" or mode == "Mouse" then
        currentMode = mode
    end
end

function FOV.setRainbow(enabled)
    rainbowEnabled = (enabled == true)
    if ringGradient then
        if rainbowEnabled then
            ringGradient.Color = makeRainbowSequence()
        else
            ringGradient.Color = makeSolidSequence(currentColor)
            ringGradient.Rotation = 0
        end
    end
end

function FOV.getRadius()
    return currentRadius
end

function FOV.isEnabled()
    return isEnabled
end

function FOV.setAimMode(mode)
    currentAimMode = tostring(mode or "")
    local shouldShow = isEnabled and isAimModeFov()
    if ringFrame then
        ringFrame.Visible = shouldShow
    end
    if drawingCircle then
        pcall(function()
            drawingCircle.Visible = shouldShow
        end)
    end
end

FOV.isAimModeFov = isAimModeFov

function FOV.destroy()
    FOV.disable()
end

return FOV
