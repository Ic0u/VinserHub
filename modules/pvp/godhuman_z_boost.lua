--[[
    Vinser Hub - Godhuman Z Glitch & Supersonic Momentum Engine
    Replicates the exact Blox Fruits Godhuman Z ("Soaring Beast") speed & flight bug:
      1. Equips Godhuman (Fighting Style)
      2. Initiates Godhuman Z with optimal windup
      3. Instantly swaps to Fruit / Sword to cancel the move's end-lag and grab lock
      4. Exploits the momentum vector to catapult the player at supersonic speed across the sea
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

local LocalPlayer = Players.LocalPlayer

local GodhumanZ = {
    Enabled = false,
    Power = 650,               -- Launch velocity impulse
    Duration = 1.2,            -- Gliding duration across the sea
    CancelWeapon = "Auto",     -- "Auto", "Fruit", "Sword", "Gun", "Slot 2"
    AutoSkyPitch = true,       -- Auto-elevates angle ~35° for clean flight arc over water
    SwitchBack = false,        -- Switch back to Godhuman after landing
    Keybind = Enum.KeyCode.Z,
    IsExecuting = false,
}

local function getCharacter()
    local char = LocalPlayer and LocalPlayer.Character
    if not char then return nil, nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
    local hum = char:FindFirstChildOfClass("Humanoid")
    return char, hrp, hum
end

-- Find tool by name or category
local function findToolByPattern(pattern)
    local char, _, _ = getCharacter()
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") and string.find(string.lower(t.Name), string.lower(pattern)) then
                return t
            end
        end
    end
    if LocalPlayer and LocalPlayer:FindFirstChild("Backpack") then
        for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do
            if t:IsA("Tool") and string.find(string.lower(t.Name), string.lower(pattern)) then
                return t
            end
        end
    end
    return nil
end

local function getGodhumanTool()
    return findToolByPattern("godhuman") or findToolByPattern("god human")
end

-- Resolve the secondary tool to cancel Godhuman Z with
local function getCancelTool(mode)
    local char, _, _ = getCharacter()
    local backpack = LocalPlayer and LocalPlayer:FindFirstChild("Backpack")

    local function isGodhuman(t)
        local n = string.lower(t.Name)
        return string.find(n, "godhuman") or string.find(n, "god human")
    end

    if mode == "Slot 2" and backpack then
        local tools = backpack:GetChildren()
        if tools[1] and not isGodhuman(tools[1]) then return tools[1] end
        if tools[2] and not isGodhuman(tools[2]) then return tools[2] end
    end

    local searchOrder = { "Fruit", "Sword", "Gun" }
    if mode == "Fruit" then searchOrder = { "Fruit" }
    elseif mode == "Sword" then searchOrder = { "Sword" }
    elseif mode == "Gun" then searchOrder = { "Gun" }
    end

    for _, cat in ipairs(searchOrder) do
        -- Check backpack first
        if backpack then
            for _, t in ipairs(backpack:GetChildren()) do
                if t:IsA("Tool") and not isGodhuman(t) then
                    if (cat == "Fruit" and (t.ToolTip == "Blox Fruit" or string.find(string.lower(t.Name), "fruit") or string.find(string.lower(t.Name), "dough")))
                    or (cat == "Sword" and (t.ToolTip == "Sword" or t:FindFirstChild("Sword")))
                    or (cat == "Gun" and (t.ToolTip == "Gun" or t:FindFirstChild("Gun"))) then
                        return t
                    end
                end
            end
        end
    end

    -- Fallback: any non-godhuman tool available in backpack
    if backpack then
        for _, t in ipairs(backpack:GetChildren()) do
            if t:IsA("Tool") and not isGodhuman(t) then
                return t
            end
        end
    end

    return nil
end

-- Supersonic launch vector impulse
local function launchGlitchMomentum(power, duration, usePitch)
    local char, hrp, hum = getCharacter()
    if not hrp then return end

    local cam = Workspace.CurrentCamera
    local lookVector = cam and cam.CFrame.LookVector or hrp.CFrame.LookVector

    -- Calculate launch trajectory (with optional sky pitch for oceanic glide)
    local dir = lookVector
    if usePitch then
        local flat = Vector3.new(lookVector.X, 0, lookVector.Z).Unit
        -- 35-degree elevation angle
        dir = (flat * 0.82 + Vector3.new(0, 0.57, 0)).Unit
    end

    local att = Instance.new("Attachment")
    att.Name = "VinserGodhumanZAttachment"
    att.Parent = hrp

    local lv = Instance.new("LinearVelocity")
    lv.Name = "VinserGodhumanZVelocity"
    lv.MaxForce = 1e9
    lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    lv.VectorVelocity = dir * power
    lv.Attachment0 = att
    lv.Parent = hrp

    -- Initial boost kick
    hrp.AssemblyLinearVelocity = dir * (power * 0.9)

    -- Maintain water surface clearance during flight
    local flightConn = nil
    local startTime = os.clock()
    flightConn = RunService.Heartbeat:Connect(function()
        if os.clock() - startTime > duration or not lv.Parent then
            if flightConn then flightConn:Disconnect(); flightConn = nil end
            return
        end
        -- Prevent sinking below sea level
        if hrp.Position.Y < 15 then
            hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 35, hrp.AssemblyLinearVelocity.Z)
        end
    end)

    task.delay(duration, function()
        pcall(function()
            if flightConn then flightConn:Disconnect(); flightConn = nil end
            if lv and lv.Parent then lv:Destroy() end
            if att and att.Parent then att:Destroy() end
        end)
    end)
end

-- Execute the Godhuman Z bug sequence
function GodhumanZ.Trigger()
    if GodhumanZ.IsExecuting then return end
    GodhumanZ.IsExecuting = true

    task.spawn(function()
        local char, hrp, hum = getCharacter()
        if not hrp or not hum then
            GodhumanZ.IsExecuting = false
            return
        end

        local godhuman = getGodhumanTool()
        local cancelTool = getCancelTool(GodhumanZ.CancelWeapon)

        -- Step 1: Ensure Godhuman is in character's hand
        if godhuman and godhuman.Parent ~= char then
            pcall(function() hum:EquipTool(godhuman) end)
            local eqDeadline = os.clock() + 0.35
            while godhuman.Parent ~= char and os.clock() < eqDeadline do
                task.wait(0.02)
            end
        end

        -- Step 2: Trigger Godhuman Z input
        if VirtualInputManager then
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Z, false, game)
            end)
        end

        -- Precise timing: wait for the initial Godhuman Z wind-up charge frame (~0.14 - 0.16s)
        task.wait(0.14)

        if VirtualInputManager then
            pcall(function()
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Z, false, game)
            end)
        end

        -- Step 3: Swap weapon to cancel move recovery and break animation drag
        if cancelTool then
            pcall(function()
                hum:EquipTool(cancelTool)
            end)
        end

        -- Step 4: Catapult momentum impulse
        launchGlitchMomentum(GodhumanZ.Power, GodhumanZ.Duration, GodhumanZ.AutoSkyPitch)

        -- Step 5: Optional re-equip Godhuman after glide
        if GodhumanZ.SwitchBack and godhuman then
            task.delay(GodhumanZ.Duration + 0.1, function()
                pcall(function()
                    local c = LocalPlayer.Character
                    local h = c and c:FindFirstChildOfClass("Humanoid")
                    if h and godhuman then h:EquipTool(godhuman) end
                end)
            end)
        end

        task.wait(0.4)
        GodhumanZ.IsExecuting = false
    end)
end

function GodhumanZ.SetEnabled(state)
    GodhumanZ.Enabled = (state == true)
    _G.VinsersHub_GodhumanZ = GodhumanZ.Enabled
    _G.DarlingX_GodhumanZ = GodhumanZ.Enabled
end

function GodhumanZ.SetPower(power)
    GodhumanZ.Power = tonumber(power) or 650
end

function GodhumanZ.SetDuration(duration)
    GodhumanZ.Duration = tonumber(duration) or 1.2
end

function GodhumanZ.SetCancelWeapon(weapon)
    GodhumanZ.CancelWeapon = tostring(weapon or "Auto")
end

function GodhumanZ.SetAutoPitch(pitch)
    GodhumanZ.AutoSkyPitch = (pitch == true)
end

function GodhumanZ.SetSwitchBack(switchBack)
    GodhumanZ.SwitchBack = (switchBack == true)
end

function GodhumanZ.SetKeybind(key)
    if typeof(key) == "EnumItem" then
        GodhumanZ.Keybind = key
    elseif type(key) == "string" and Enum.KeyCode[key] then
        GodhumanZ.Keybind = Enum.KeyCode[key]
    end
end

-- Keybind listener (Triggers Godhuman Z bug whenever enabled and keybind pressed)
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if not GodhumanZ.Enabled then return end
    if input.KeyCode == GodhumanZ.Keybind then
        GodhumanZ.Trigger()
    end
end)

_G.VinsersHub_GodhumanZMod = GodhumanZ
_G.DarlingX_GodhumanZMod = GodhumanZ

return GodhumanZ
