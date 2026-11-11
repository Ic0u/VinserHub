--[[
    Darling X - Unified Luxury Dark Glass Floating Widgets
    Consolidated draggable floating widgets for:
      1. Super Jump (Impulse Trigger)
      2. Camlock (Aim Lock Toggle)
      3. Dragon Gun M1 (Fast Gun Toggle)
      4. Sanguine Boost (Velocity Dash Trigger)
    Features:
      - Clean transparent dark glass styling
      - 6-stud drag threshold (separating drag from click)
      - Feature-gating (taps only function when menu toggle is enabled)
      - DisplayOrder 99999, safe parenting, touch and mouse support
      - Zero emojis, zero third-party references
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local function getGuiParent()
    local ok, h = pcall(function() return gethui and gethui() end)
    if ok and h and ((typeof and typeof(h) == "Instance") or type(h) == "userdata" or type(h) == "table") then return h end
    local ok2, c = pcall(function() return CoreGui end)
    if ok2 and c and ((typeof and typeof(c) == "Instance") or type(c) == "userdata" or type(c) == "table") then
        local pOk = pcall(function()
            local t = Instance.new("Folder")
            t.Parent = c
            t:Destroy()
        end)
        if pOk then return c end
    end
    local lp = LocalPlayer or Players.LocalPlayer
    if lp then
        local pg = nil
        pcall(function()
            pg = lp:FindFirstChildOfClass("PlayerGui") or lp:FindFirstChild("PlayerGui")
        end)
        if pg then return pg end
        pcall(function()
            pg = lp:WaitForChild("PlayerGui", 2)
        end)
        if pg then return pg end
    end
    return nil
end

local function ensureParent(gui)
    if not gui then return end
    local p = getGuiParent()
    if p and gui.Parent ~= p then
        pcall(function() gui.Parent = p end)
    end
end

local function makeDraggable(targetFrame, dragHandle, onClick)
    dragHandle = dragHandle or targetFrame
    local dragging = false
    local dragStart = nil
    local startPos = nil
    local startTime = 0
    local isDrag = false
    local lastClickTick = 0

    local function fireClick()
        local now = os.clock()
        if now - lastClickTick < 0.25 then return end
        lastClickTick = now
        if onClick then
            pcall(onClick)
        end
    end

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            isDrag = false
            dragStart = input.Position
            startPos = targetFrame.Position
            startTime = os.clock()
        end
    end)

    dragHandle.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            if dragStart and startPos then
                local delta = input.Position - dragStart
                if delta.Magnitude > 28 then
                    isDrag = true
                    targetFrame.Position = UDim2.new(
                        startPos.X.Scale,
                        startPos.X.Offset + delta.X,
                        startPos.Y.Scale,
                        startPos.Y.Offset + delta.Y
                    )
                end
            end
        end
    end)

    dragHandle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                local duration = os.clock() - startTime
                local totalDist = dragStart and (input.Position - dragStart).Magnitude or 0
                if not isDrag or totalDist < 25 or duration < 0.28 then
                    fireClick()
                end
            end
        end
    end)

    pcall(function()
        if dragHandle:IsA("GuiButton") or dragHandle.Activated then
            dragHandle.Activated:Connect(function()
                if not isDrag then
                    fireClick()
                end
            end)
        end
    end)

    pcall(function()
        if dragHandle:IsA("GuiButton") then
            dragHandle.MouseButton1Click:Connect(function()
                if not isDrag then
                    fireClick()
                end
            end)
        end
    end)
end

local function createGlassWidget(name, size, pos)
    local gui = Instance.new("ScreenGui")
    gui.Name = name
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 99999
    gui.IgnoreGuiInset = true
    gui.Enabled = false
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(gui) end
        gui.Parent = getGuiParent()
    end)

    local container = Instance.new("Frame", gui)
    container.Name = name .. "_Container"
    container.Size = size
    container.Position = pos
    container.BackgroundColor3 = Color3.fromRGB(18, 14, 28)
    container.BackgroundTransparency = 0.45
    container.Active = true

    local corner = Instance.new("UICorner", container)
    corner.CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", container)
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 1.0
    stroke.Transparency = 0.6
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local btn = Instance.new("TextButton", container)
    btn.Name = name .. "_Btn"
    btn.Size = UDim2.new(1, -6, 1, -6)
    btn.Position = UDim2.new(0, 3, 0, 3)
    btn.BackgroundColor3 = Color3.fromRGB(48, 38, 72)
    btn.BackgroundTransparency = 0.5
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.AutoButtonColor = false

    local btnCorner = Instance.new("UICorner", btn)
    btnCorner.CornerRadius = UDim.new(0, 8)

    return gui, container, btn
end

-- 1. Super Jump Widget
local SuperJumpUI = nil
local jumpBtnRef = nil

local function doSuperJump()
    if not _G.DarlingX_SuperJump then return end
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local force = _G.DarlingX_SuperJumpPower or 216
            hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, force, hrp.AssemblyLinearVelocity.Z)
        end
    end)
end

local function initSuperJumpUI()
    if SuperJumpUI and SuperJumpUI.Parent then return end
    local gui, container, btn = createGlassWidget("SuperJumpWidget", UDim2.new(0, 92, 0, 38), UDim2.new(0.85, 0, 0.58, 0))
    SuperJumpUI = gui
    jumpBtnRef = btn
    btn.Text = "JUMP"
    btn.TextSize = 12

    makeDraggable(container, btn, function()
        doSuperJump()
    end)
end

-- 2. Camlock Widget
local CamlockUI = nil
local lockBtnRef = nil

local function updateLockVisual(state)
    if not lockBtnRef then return end
    local active = (state ~= nil) and state or (_G.DarlingX_Camlock == true)
    if active then
        lockBtnRef.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
        lockBtnRef.BackgroundTransparency = 0.2
        local targetName = rawget(_G, "DarlingX_CamlockTargetName")
        if targetName and tostring(targetName) ~= "" then
            local cleanName = tostring(targetName)
            if #cleanName > 8 then
                cleanName = cleanName:sub(1, 7) .. ".."
            end
            lockBtnRef.Text = "LOCK: " .. cleanName
        else
            lockBtnRef.Text = "LOCK: ON"
        end
    else
        lockBtnRef.BackgroundColor3 = Color3.fromRGB(36, 30, 50)
        lockBtnRef.BackgroundTransparency = 0.5
        lockBtnRef.Text = "LOCK: OFF"
    end
end


local function initCamlockUI()
    if CamlockUI and CamlockUI.Parent then return end
    local gui, container, btn = createGlassWidget("CamlockWidget", UDim2.new(0, 96, 0, 38), UDim2.new(0.85, 0, 0.50, 0))
    CamlockUI = gui
    lockBtnRef = btn
    updateLockVisual(false)

    makeDraggable(container, btn, function()
        if _G.DarlingX_CamlockMod and _G.DarlingX_CamlockMod.Toggle then
            _G.DarlingX_CamlockMod.Toggle()
        elseif _G.DarlingX_ToggleCamlock then
            _G.DarlingX_ToggleCamlock()
        else
            local cl = rawget(_G, "DarlingX_GetModule") and _G.DarlingX_GetModule("modules/pvp/camlock.lua")
            if cl and cl.Toggle then
                cl.Toggle()
            end
        end
    end)
end

-- 3. Dragon Gun M1 Widget
local DragonM1UI = nil
local m1BtnRef = nil

local function updateDragonM1Visual(state)
    if not m1BtnRef then return end
    local active = (state ~= nil) and state or (_G.G_DragonGunM1 == true)
    if active then
        m1BtnRef.BackgroundColor3 = Color3.fromRGB(0, 190, 90)
        m1BtnRef.BackgroundTransparency = 0.3
        m1BtnRef.Text = "M1: ON"
    else
        m1BtnRef.BackgroundColor3 = Color3.fromRGB(48, 38, 72)
        m1BtnRef.BackgroundTransparency = 0.5
        m1BtnRef.Text = "M1: OFF"
    end
end

local function initDragonM1UI()
    if DragonM1UI and DragonM1UI.Parent then return end
    local gui, container, btn = createGlassWidget("DragonM1Widget", UDim2.new(0, 96, 0, 38), UDim2.new(0.85, 0, 0.42, 0))
    DragonM1UI = gui
    m1BtnRef = btn
    updateDragonM1Visual()

    makeDraggable(container, btn, function()
        if not _G.DarlingX_DragonM1Enabled then return end
        _G.G_DragonGunM1 = not _G.G_DragonGunM1
        updateDragonM1Visual(_G.G_DragonGunM1)
    end)
end

-- 4. Sanguine Boost Widget
local SanguineUI = nil
local sanguineBtnRef = nil
local sanguinePulseActive = false

local function doSanguineBoost()
    -- Delegate to the sanguine_boost module instead of duplicating physics code
    if not _G.DarlingX_SanguineBoost then return end
    local mod = rawget(_G, "VinsersHub_SanguineBoostMod")
    if mod and mod.Trigger then
        mod.Trigger()
    end
end

local function updateSanguineVisual(isBoosting)
    if not sanguineBtnRef then return end
    if isBoosting then
        sanguineBtnRef.BackgroundColor3 = Color3.fromRGB(0, 220, 100)
        sanguineBtnRef.BackgroundTransparency = 0.2
        sanguineBtnRef.Text = "BOOST!"
    else
        sanguineBtnRef.BackgroundColor3 = Color3.fromRGB(110, 45, 170)
        sanguineBtnRef.BackgroundTransparency = 0.4
        sanguineBtnRef.Text = "BOOST Z"
    end
end

local function triggerSanguineAction()
    if not _G.DarlingX_SanguineBoost or sanguinePulseActive then return end
    sanguinePulseActive = true
    doSanguineBoost()
    updateSanguineVisual(true)
    task.delay(0.35, function()
        updateSanguineVisual(false)
        sanguinePulseActive = false
    end)
end

local function initSanguineUI()
    if SanguineUI and SanguineUI.Parent then return end
    local gui, container, btn = createGlassWidget("SanguineWidget", UDim2.new(0, 92, 0, 38), UDim2.new(0.85, 0, 0.34, 0))
    SanguineUI = gui
    sanguineBtnRef = btn
    updateSanguineVisual(false)

    makeDraggable(container, btn, function()
        triggerSanguineAction()
    end)
end

-- Initialize widgets lazily on startup
initSuperJumpUI()
initCamlockUI()
initDragonM1UI()
initSanguineUI()

local Widgets = {
    -- Super Jump
    SetSuperJumpWidgetVisible = function(state)
        if not SuperJumpUI or not SuperJumpUI.Parent then initSuperJumpUI() end
        if SuperJumpUI then
            ensureParent(SuperJumpUI)
            SuperJumpUI.Enabled = (state == true)
        end
    end,
    DoSuperJump = doSuperJump,

    -- Camlock
    SetCamlockWidgetVisible = function(state)
        if not CamlockUI or not CamlockUI.Parent then initCamlockUI() end
        if CamlockUI then
            ensureParent(CamlockUI)
            CamlockUI.Enabled = (state == true)
            updateLockVisual(false)
        end
    end,
    UpdateCamlockVisual = updateLockVisual,

    -- Dragon Gun M1
    SetDragonM1WidgetVisible = function(state)
        if not DragonM1UI or not DragonM1UI.Parent then initDragonM1UI() end
        if DragonM1UI then
            ensureParent(DragonM1UI)
            DragonM1UI.Enabled = (state == true)
            updateDragonM1Visual()
        end
    end,
    UpdateDragonM1Visual = updateDragonM1Visual,

    -- Sanguine Boost
    SetSanguineWidgetVisible = function(state)
        if not SanguineUI or not SanguineUI.Parent then initSanguineUI() end
        if SanguineUI then
            ensureParent(SanguineUI)
            SanguineUI.Enabled = (state == true)
            updateSanguineVisual(false)
        end
    end,
    UpdateSanguineVisual = updateSanguineVisual,
    DoSanguineBoost = triggerSanguineAction,
}

_G.DarlingX_ExtraWidgets = Widgets
return Widgets
