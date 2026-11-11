--[[
    Darling X - Floating Widget Framework
    Movable on-screen pill buttons and toggles with touch and drag support.
    Zero emojis, zero third-party references.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local FloatingWidget = {
    Locked = false,
    AllWidgets = {},
}
FloatingWidget.__index = FloatingWidget

local function getGuiContainer()
    local ok, h = pcall(function() return gethui and gethui() end)
    if ok and h and typeof(h) == "Instance" then return h end
    local ok2, c = pcall(function() return CoreGui end)
    if ok2 and c and typeof(c) == "Instance" then
        local pOk = pcall(function()
            local t = Instance.new("Folder")
            t.Parent = c
            t:Destroy()
        end)
        if pOk then return c end
    end
    local lp = LocalPlayer or Players.LocalPlayer
    return lp and (lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui", 3))
end

local SharedScreenGui = nil

local function getSharedScreenGui()
    if SharedScreenGui and SharedScreenGui.Parent then
        return SharedScreenGui
    end

    local parent = getGuiContainer()
    local existing = parent and parent:FindFirstChild("DarlingFloatingWidgets")
    if existing then
        SharedScreenGui = existing
        return SharedScreenGui
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "DarlingFloatingWidgets"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 2147482000
    if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
    pcall(function() gui.Parent = parent end)
    SharedScreenGui = gui
    return SharedScreenGui
end

function FloatingWidget.LockAll(locked)
    FloatingWidget.Locked = (locked == true)
end

function FloatingWidget.create(config)
    config = config or {}
    local id = config.Id or ("Widget_" .. tostring(os.clock()))
    local label = config.Label or config.Title or "ACT"
    local widgetType = config.Type or "Toggle"
    local enabled = config.Default == true
    local accentColor = config.AccentColor or Color3.fromRGB(255, 255, 255)
    local defaultPos = config.Position or UDim2.new(0.85, 0, 0.45, 0)
    local callback = config.Callback or function() end
    local uiElementKey = config.UIElementKey or id

    local screenGui = getSharedScreenGui()

    local oldPill = screenGui and screenGui:FindFirstChild(id)
    if oldPill then pcall(function() oldPill:Destroy() end) end

    local pill = Instance.new("TextButton")
    pill.Name = id
    pill.Size = UDim2.fromOffset(66, 36)
    pill.AutomaticSize = Enum.AutomaticSize.X
    pill.Position = defaultPos
    pill.BackgroundColor3 = Color3.fromRGB(18, 14, 26)
    pill.BackgroundTransparency = 0.25
    pill.BorderSizePixel = 0
    pill.AutoButtonColor = false
    pill.Text = ""
    pill.Active = true
    pill.Visible = (config.Visible == true)
    if screenGui then pcall(function() pill.Parent = screenGui end) end

    local sizeConstraint = Instance.new("UISizeConstraint")
    sizeConstraint.MinSize = Vector2.new(66, 36)
    sizeConstraint.MaxSize = Vector2.new(200, 36)
    sizeConstraint.Parent = pill

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, (widgetType == "Toggle" and 18 or 10))
    padding.PaddingTop = UDim.new(0, 2)
    padding.PaddingBottom = UDim.new(0, 2)
    padding.Parent = pill

    local pillCorner = Instance.new("UICorner")
    pillCorner.CornerRadius = UDim.new(0, 10)
    pillCorner.Parent = pill

    local stroke = Instance.new("UIStroke")
    stroke.Name = "Stroke"
    stroke.Color = enabled and accentColor or Color3.fromRGB(50, 42, 68)
    stroke.Thickness = 1.2
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = pill

    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "Label"
    textLabel.BackgroundTransparency = 1
    textLabel.Size = UDim2.fromScale(1, 1)
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 10
    textLabel.TextColor3 = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 175, 200)
    textLabel.Text = label
    textLabel.Parent = pill

    local dot = nil
    if widgetType == "Toggle" then
        dot = Instance.new("Frame")
        dot.Name = "StatusDot"
        dot.Size = UDim2.fromOffset(6, 6)
        dot.Position = UDim2.new(1, -6, 0.5, -3)
        dot.BackgroundColor3 = enabled and accentColor or Color3.fromRGB(80, 75, 95)
        dot.BorderSizePixel = 0
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
        dot.Parent = pill
    end

    local self = setmetatable({
        Id = id,
        UIElementKey = uiElementKey,
        Pill = pill,
        Stroke = stroke,
        TextLabel = textLabel,
        Dot = dot,
        Type = widgetType,
        Enabled = enabled,
        BaseLabel = label,
        AccentColor = accentColor,
        Callback = callback,
        Connections = {},
    }, FloatingWidget)

    FloatingWidget.AllWidgets[id] = self

    local function updateVisuals()
        local isAct = self.Enabled
        local col = isAct and self.AccentColor or Color3.fromRGB(50, 42, 68)
        TweenService:Create(self.Stroke, TweenInfo.new(0.18), { Color = col }):Play()
        if self.Dot then
            local dotCol = isAct and self.AccentColor or Color3.fromRGB(80, 75, 95)
            TweenService:Create(self.Dot, TweenInfo.new(0.18), { BackgroundColor3 = dotCol }):Play()
        end
        local txtCol = isAct and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 175, 200)
        TweenService:Create(self.TextLabel, TweenInfo.new(0.18), { TextColor3 = txtCol }):Play()
    end
    self.UpdateVisuals = updateVisuals

    -- Dragging Logic
    local dragging = false
    local dragStart = nil
    local startPos = nil
    local startTime = 0

    table.insert(self.Connections, pill.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not FloatingWidget.Locked then
            dragging = true
            dragStart = input.Position
            startPos = pill.Position
            startTime = os.clock()
        end
    end))

    table.insert(self.Connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            pill.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end))

    table.insert(self.Connections, UserInputService.InputEnded:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            local movedDist = (input.Position - dragStart).Magnitude
            local elapsed = os.clock() - startTime
            if movedDist < 12 and elapsed < 0.4 then
                if self.Type == "Action" then
                    self:TriggerAction()
                else
                    self:Toggle()
                end
            end
        end
    end))

    return self
end

function FloatingWidget:TriggerAction()
    TweenService:Create(self.Pill, TweenInfo.new(0.08), { BackgroundTransparency = 0 }):Play()
    task.delay(0.1, function()
        TweenService:Create(self.Pill, TweenInfo.new(0.15), { BackgroundTransparency = 0.25 }):Play()
    end)
    if self.Callback then pcall(self.Callback) end
end

function FloatingWidget:Set(state, suppressCallback)
    self.Enabled = (state == true)
    self.UpdateVisuals()
    if not suppressCallback and self.Callback then
        pcall(self.Callback, self.Enabled)
    end
end

function FloatingWidget:SetState(state)
    self.Enabled = (state == true)
    self.UpdateVisuals()
end

function FloatingWidget:Toggle()
    self:Set(not self.Enabled)
end

function FloatingWidget:SetVisible(visible)
    if self.Pill and self.Pill.Parent then
        self.Pill.Visible = (visible == true)
    end
end

function FloatingWidget:SetLabel(lbl)
    self.BaseLabel = lbl
    if self.TextLabel then self.TextLabel.Text = lbl end
end

function FloatingWidget:Destroy()
    for _, conn in ipairs(self.Connections) do pcall(function() conn:Disconnect() end) end
    table.clear(self.Connections)
    if self.Pill and self.Pill.Parent then pcall(function() self.Pill:Destroy() end) end
end

function FloatingWidget.GetWidget(id)
    return FloatingWidget.AllWidgets[id]
end

function FloatingWidget.SetWidgetVisible(id, visible)
    local w = FloatingWidget.GetWidget(id)
    if w then
        w:SetVisible(visible)
    end
end

return FloatingWidget
