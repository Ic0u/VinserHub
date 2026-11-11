--[[
    Darling X - Movement Engine Module
    Event-driven player mobility, physics enhancements, and agility controls.
    Zero emojis, zero third-party references.
    Strict gating: zero active loops or connections when features are disabled.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local MovementEngine = {
    -- State properties
    WalkSpeedEnabled = false,
    WalkSpeedValue = 150,

    DashLengthEnabled = false,
    DashLengthValue = 30,
    SoulGuitarDashEnabled = false,

    SuperJumpEnabled = false,
    SuperJumpPower = 216,

    InfiniteJumpEnabled = false,
    NoclipEnabled = false,
    WalkOnWaterEnabled = false,
    AntiLavaEnabled = false,
    FlyEnabled = false,
    FlySpeed = 70,

    -- Internal connection & thread references
    SteppedConn = nil,
    JumpRequestConn = nil,
    WaterConn = nil,
    AntiLavaConn = nil,
    FlyConn = nil,
    FlyInputBeganConn = nil,
    FlyInputEndedConn = nil,
    FlyKeys = { W = false, A = false, S = false, D = false, Space = false, LeftShift = false },
    FlyBodyVelocity = nil,
    FlyBodyGyro = nil,
    DashThread = nil,
    WaterPlatform = nil,
}

local function getCharacter()
    local char = LocalPlayer and LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        return char, hum, hrp
    end
    return nil, nil, nil
end

-- ========================================================================
-- 1. UNIFIED STEPPED CONNECTION (WALKSPEED & NOCLIP GATING)
-- ========================================================================
local function checkSteppedGating()
    local needStepped = MovementEngine.WalkSpeedEnabled or MovementEngine.NoclipEnabled

    if needStepped and not MovementEngine.SteppedConn then
        MovementEngine.SteppedConn = RunService.Stepped:Connect(function()
            local char, hum, hrp = getCharacter()
            if not char or not hum or not hrp or hum.Health <= 0 then return end

            -- Custom WalkSpeed physics injection
            if MovementEngine.WalkSpeedEnabled and hum.MoveDirection.Magnitude > 0 then
                local spd = MovementEngine.WalkSpeedValue or 150
                hum.WalkSpeed = spd
                local curY = hrp.AssemblyLinearVelocity.Y
                hrp.AssemblyLinearVelocity = Vector3.new(hum.MoveDirection.X * spd, curY, hum.MoveDirection.Z * spd)
            end

            -- Noclip wall collision bypass
            if MovementEngine.NoclipEnabled then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end)
    elseif not needStepped and MovementEngine.SteppedConn then
        pcall(function() MovementEngine.SteppedConn:Disconnect() end)
        MovementEngine.SteppedConn = nil
    end
end

-- ========================================================================
-- 2. WALKSPEED CONTROLLER
-- ========================================================================
function MovementEngine.SetWalkSpeed(enabled, value)
    MovementEngine.WalkSpeedEnabled = (enabled == true)
    if value then
        MovementEngine.WalkSpeedValue = tonumber(value) or 150
    end
    _G.DarlingX_CustomWalkSpeed = MovementEngine.WalkSpeedEnabled
    _G.DarlingX_WalkSpeedVal = MovementEngine.WalkSpeedValue

    if not MovementEngine.WalkSpeedEnabled then
        pcall(function()
            local _, hum = getCharacter()
            if hum then hum.WalkSpeed = 16 end
        end)
    end

    checkSteppedGating()
end

function MovementEngine.SetWalkSpeedValue(val)
    MovementEngine.WalkSpeedValue = tonumber(val) or 150
    _G.DarlingX_WalkSpeedVal = MovementEngine.WalkSpeedValue
end

-- ========================================================================
-- 3. CUSTOM DASH LENGTH
-- ========================================================================
function MovementEngine.SetDashLength(enabled, value)
    MovementEngine.DashLengthEnabled = (enabled == true)
    if value then
        MovementEngine.DashLengthValue = tonumber(value) or 30
    end
    _G.DarlingX_DashLengthEnabled = MovementEngine.DashLengthEnabled
    _G.DarlingX_DashLength = MovementEngine.DashLengthValue

    if MovementEngine.DashThread then
        pcall(task.cancel, MovementEngine.DashThread)
        MovementEngine.DashThread = nil
    end

    if MovementEngine.DashLengthEnabled then
        MovementEngine.DashThread = task.spawn(function()
            while MovementEngine.DashLengthEnabled do
                local char = LocalPlayer and LocalPlayer.Character
                if char then
                    local targetLen = MovementEngine.DashLengthValue or 30
                    if char:GetAttribute("DashLength") ~= targetLen then
                        pcall(function()
                            char:SetAttribute("DashLength", targetLen)
                            char:SetAttribute("DashLengthAir", targetLen)
                        end)
                    end
                end
                task.wait(0.2)
            end
            MovementEngine.DashThread = nil
        end)
    else
        pcall(function()
            local char = LocalPlayer and LocalPlayer.Character
            if char then
                char:SetAttribute("DashLength", 1)
                char:SetAttribute("DashLengthAir", 1)
            end
        end)
    end
end

function MovementEngine.SetDashDistance(val)
    MovementEngine.DashLengthValue = tonumber(val) or 30
    _G.DarlingX_DashLength = MovementEngine.DashLengthValue
end

function MovementEngine.SetSoulGuitarDash(enabled)
    MovementEngine.SoulGuitarDashEnabled = (enabled == true)
    _G.VinsersHub_SoulGuitarDash = MovementEngine.SoulGuitarDashEnabled
    _G.DarlingX_SoulGuitarDash = MovementEngine.SoulGuitarDashEnabled

    if MovementEngine.SoulGuitarDashEnabled then
        MovementEngine.SetDashLength(true, 121)
    else
        MovementEngine.SetDashLength(false, 1)
    end
end

-- ========================================================================
-- 4. SUPER JUMP (BURST LEAP)
-- ========================================================================
function MovementEngine.DoSuperJump()
    local char, hum, hrp = getCharacter()
    if not char or not hum or not hrp or hum.Health <= 0 then return end

    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
        hum.Jump = true

        local existing = hrp:FindFirstChild("DarlingSuperJump")
        if existing then existing:Destroy() end

        local power = MovementEngine.SuperJumpPower or 216
        local bv = Instance.new("BodyVelocity")
        bv.Name = "DarlingSuperJump"
        bv.MaxForce = Vector3.new(0, 1e7, 0)
        bv.Velocity = Vector3.new(0, power, 0)
        bv.Parent = hrp

        local vel = hrp.AssemblyLinearVelocity or Vector3.zero
        hrp.AssemblyLinearVelocity = Vector3.new(vel.X, power, vel.Z)

        task.delay(0.18, function()
            if bv and bv.Parent then pcall(function() bv:Destroy() end) end
        end)
    end)
end

function MovementEngine.SetSuperJump(enabled, power)
    MovementEngine.SuperJumpEnabled = (enabled == true)
    if power then
        MovementEngine.SuperJumpPower = tonumber(power) or 216
    end
    _G.DarlingX_SuperJump = MovementEngine.SuperJumpEnabled
    _G.DarlingX_SuperJumpPower = MovementEngine.SuperJumpPower

    local ew = _G.DarlingX_ExtraWidgets
    if ew and ew.SetSuperJumpWidgetVisible then
        pcall(ew.SetSuperJumpWidgetVisible, MovementEngine.SuperJumpEnabled)
    end
end

function MovementEngine.SetSuperJumpPower(power)
    MovementEngine.SuperJumpPower = tonumber(power) or 216
    _G.DarlingX_SuperJumpPower = MovementEngine.SuperJumpPower
end

-- ========================================================================
-- 5. INFINITE JUMP
-- ========================================================================
function MovementEngine.SetInfiniteJump(enabled)
    MovementEngine.InfiniteJumpEnabled = (enabled == true)
    _G.DarlingX_InfJump = MovementEngine.InfiniteJumpEnabled

    if MovementEngine.InfiniteJumpEnabled and not MovementEngine.JumpRequestConn then
        MovementEngine.JumpRequestConn = UserInputService.JumpRequest:Connect(function()
            if not MovementEngine.InfiniteJumpEnabled then return end
            local _, hum = getCharacter()
            if hum and hum.Health > 0 then
                pcall(function()
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end)
            end
        end)
    elseif not MovementEngine.InfiniteJumpEnabled and MovementEngine.JumpRequestConn then
        pcall(function() MovementEngine.JumpRequestConn:Disconnect() end)
        MovementEngine.JumpRequestConn = nil
    end
end

-- ========================================================================
-- 6. NOCLIP WALLPASS
-- ========================================================================
function MovementEngine.SetNoclip(enabled)
    MovementEngine.NoclipEnabled = (enabled == true)
    _G.DarlingX_Noclip = MovementEngine.NoclipEnabled
    checkSteppedGating()
end

-- ========================================================================
-- 7. WALK ON WATER
-- ========================================================================
local function getWaterPlatform()
    if MovementEngine.WaterPlatform and MovementEngine.WaterPlatform.Parent then
        return MovementEngine.WaterPlatform
    end
    local plat = Instance.new("Part")
    plat.Name = "DarlingWaterPlatform"
    plat.Size = Vector3.new(200, 1, 200)
    plat.Transparency = 1
    plat.Anchored = true
    plat.CanCollide = false
    plat.CanTouch = false
    plat.CanQuery = false
    plat.CastShadow = false
    plat.Parent = Workspace
    MovementEngine.WaterPlatform = plat
    return plat
end

function MovementEngine.SetWalkOnWater(enabled)
    MovementEngine.WalkOnWaterEnabled = (enabled == true)
    _G.DarlingX_WalkOnWater = MovementEngine.WalkOnWaterEnabled

    if MovementEngine.WalkOnWaterEnabled and not MovementEngine.WaterConn then
        MovementEngine.WaterConn = RunService.Heartbeat:Connect(function()
            if not MovementEngine.WalkOnWaterEnabled then return end
            local _, _, hrp = getCharacter()
            local plat = getWaterPlatform()
            if hrp and plat then
                if hrp.Position.Y >= 8.5 then
                    plat.Position = Vector3.new(hrp.Position.X, 8.8, hrp.Position.Z)
                    plat.CanCollide = true
                else
                    plat.CanCollide = false
                end
            elseif plat then
                plat.CanCollide = false
            end
        end)
    elseif not MovementEngine.WalkOnWaterEnabled and MovementEngine.WaterConn then
        pcall(function() MovementEngine.WaterConn:Disconnect() end)
        MovementEngine.WaterConn = nil
        if MovementEngine.WaterPlatform then
            pcall(function() MovementEngine.WaterPlatform:Destroy() end)
            MovementEngine.WaterPlatform = nil
        end
    end
end

-- ========================================================================
-- 8. ANTI-LAVA DAMAGE
-- ========================================================================
function MovementEngine.SetAntiLava(enabled)
    MovementEngine.AntiLavaEnabled = (enabled == true)
    _G.DarlingX_AntiLava = MovementEngine.AntiLavaEnabled

    if MovementEngine.AntiLavaEnabled then
        if not MovementEngine.AntiLavaConn then
            local timer = 0
            MovementEngine.AntiLavaConn = RunService.Stepped:Connect(function(_, dt)
                timer = timer + dt
                if timer < 0.25 then return end
                timer = 0
                if not MovementEngine.AntiLavaEnabled then return end
                pcall(function()
                    local char = LocalPlayer and LocalPlayer.Character
                    if char then
                        for _, part in ipairs(char:GetDescendants()) do
                            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart"
                            and part.Name ~= "Torso" and part.Name ~= "UpperTorso"
                            and part.Name ~= "LowerTorso" and part.Name ~= "Head" then
                                part.CanTouch = false
                            end
                        end
                    end
                end)
            end)
        end
        pcall(function()
            for _, v in ipairs(Workspace:GetDescendants()) do
                if v.Name == "Lava" or v.Name == "LavaParts" then
                    pcall(function() v:Destroy() end)
                end
            end
        end)
    else
        if MovementEngine.AntiLavaConn then
            pcall(function() MovementEngine.AntiLavaConn:Disconnect() end)
            MovementEngine.AntiLavaConn = nil
        end
        pcall(function()
            local char = LocalPlayer and LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanTouch = true
                    end
                end
            end
        end)
    end
end

-- ========================================================================
-- 9. FLY SYSTEM
-- ========================================================================
local function updateFlyMovement()
    if not MovementEngine.FlyEnabled then return end
    local char, hum, hrp = getCharacter()
    if not char or not hum or not hrp or hum.Health <= 0 then return end
    if not MovementEngine.FlyBodyVelocity or not MovementEngine.FlyBodyGyro then return end

    local cam = Workspace.CurrentCamera
    if not cam then return end
    MovementEngine.FlyBodyGyro.CFrame = cam.CFrame

    local moveDir = Vector3.new(0, 0, 0)
    local camCF = cam.CFrame

    -- Mobile thumbstick and PC unified via Humanoid.MoveDirection
    local m = hum.MoveDirection
    if m.Magnitude > 0 then
        local fwd = m:Dot(camCF.LookVector)
        local rgt = m:Dot(camCF.RightVector)
        moveDir = (camCF.LookVector * fwd + camCF.RightVector * rgt)
    end

    -- PC Keyboard Direct Controls
    local keys = MovementEngine.FlyKeys
    if keys.W then moveDir = moveDir + camCF.LookVector end
    if keys.S then moveDir = moveDir - camCF.LookVector end
    if keys.A then moveDir = moveDir - camCF.RightVector end
    if keys.D then moveDir = moveDir + camCF.RightVector end
    if keys.Space then moveDir = moveDir + Vector3.new(0, 1, 0) end
    if keys.LeftShift then moveDir = moveDir - Vector3.new(0, 1, 0) end

    local spd = MovementEngine.FlySpeed or 70
    if moveDir.Magnitude > 0 then
        MovementEngine.FlyBodyVelocity.Velocity = moveDir.Unit * spd
    else
        MovementEngine.FlyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
    end
end

function MovementEngine.SetFly(enabled, speed)
    MovementEngine.FlyEnabled = (enabled == true)
    if speed then
        MovementEngine.FlySpeed = tonumber(speed) or 70
    end
    _G.DarlingX_Fly = MovementEngine.FlyEnabled
    _G.DarlingX_FlySpeed = MovementEngine.FlySpeed

    if MovementEngine.FlyEnabled then
        local char, hum, hrp = getCharacter()
        if not char or not hum or not hrp then return end

        local cam = Workspace.CurrentCamera

        -- BodyVelocity
        if not MovementEngine.FlyBodyVelocity or not MovementEngine.FlyBodyVelocity.Parent then
            local bv = Instance.new("BodyVelocity")
            bv.Name = "DarlingFlyVelocity"
            bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = hrp
            MovementEngine.FlyBodyVelocity = bv
        end

        -- BodyGyro
        if not MovementEngine.FlyBodyGyro or not MovementEngine.FlyBodyGyro.Parent then
            local bg = Instance.new("BodyGyro")
            bg.Name = "DarlingFlyGyro"
            bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
            bg.P = 10000
            if cam then bg.CFrame = cam.CFrame end
            bg.Parent = hrp
            MovementEngine.FlyBodyGyro = bg
        end

        hum.PlatformStand = true

        -- Input listeners
        if not MovementEngine.FlyInputBeganConn then
            MovementEngine.FlyInputBeganConn = UserInputService.InputBegan:Connect(function(inp, gpe)
                if inp.KeyCode == Enum.KeyCode.W then MovementEngine.FlyKeys.W = true end
                if inp.KeyCode == Enum.KeyCode.A then MovementEngine.FlyKeys.A = true end
                if inp.KeyCode == Enum.KeyCode.S then MovementEngine.FlyKeys.S = true end
                if inp.KeyCode == Enum.KeyCode.D then MovementEngine.FlyKeys.D = true end
                if inp.KeyCode == Enum.KeyCode.Space then MovementEngine.FlyKeys.Space = true end
                if inp.KeyCode == Enum.KeyCode.LeftShift then MovementEngine.FlyKeys.LeftShift = true end
            end)
        end
        if not MovementEngine.FlyInputEndedConn then
            MovementEngine.FlyInputEndedConn = UserInputService.InputEnded:Connect(function(inp, gpe)
                if inp.KeyCode == Enum.KeyCode.W then MovementEngine.FlyKeys.W = false end
                if inp.KeyCode == Enum.KeyCode.A then MovementEngine.FlyKeys.A = false end
                if inp.KeyCode == Enum.KeyCode.S then MovementEngine.FlyKeys.S = false end
                if inp.KeyCode == Enum.KeyCode.D then MovementEngine.FlyKeys.D = false end
                if inp.KeyCode == Enum.KeyCode.Space then MovementEngine.FlyKeys.Space = false end
                if inp.KeyCode == Enum.KeyCode.LeftShift then MovementEngine.FlyKeys.LeftShift = false end
            end)
        end

        -- Stepped hook
        if not MovementEngine.FlyConn then
            MovementEngine.FlyConn = RunService.Stepped:Connect(function()
                updateFlyMovement()
            end)
        end
    else
        -- Teardown
        if MovementEngine.FlyConn then
            pcall(function() MovementEngine.FlyConn:Disconnect() end)
            MovementEngine.FlyConn = nil
        end
        if MovementEngine.FlyInputBeganConn then
            pcall(function() MovementEngine.FlyInputBeganConn:Disconnect() end)
            MovementEngine.FlyInputBeganConn = nil
        end
        if MovementEngine.FlyInputEndedConn then
            pcall(function() MovementEngine.FlyInputEndedConn:Disconnect() end)
            MovementEngine.FlyInputEndedConn = nil
        end
        for k, _ in pairs(MovementEngine.FlyKeys) do
            MovementEngine.FlyKeys[k] = false
        end
        if MovementEngine.FlyBodyVelocity then
            pcall(function() MovementEngine.FlyBodyVelocity:Destroy() end)
            MovementEngine.FlyBodyVelocity = nil
        end
        if MovementEngine.FlyBodyGyro then
            pcall(function() MovementEngine.FlyBodyGyro:Destroy() end)
            MovementEngine.FlyBodyGyro = nil
        end

        local char, hum, hrp = getCharacter()
        if hum then
            hum.PlatformStand = false
            hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
    end
end

function MovementEngine.SetFlySpeed(speed)
    MovementEngine.FlySpeed = tonumber(speed) or 70
    _G.DarlingX_FlySpeed = MovementEngine.FlySpeed
end

-- ========================================================================
-- 10. RESET ALL MOBILITY STATE
-- ========================================================================
function MovementEngine.ResetAll()
    MovementEngine.SetWalkSpeed(false, 150)
    MovementEngine.SetDashLength(false, 30)
    MovementEngine.SetSuperJump(false, 216)
    MovementEngine.SetInfiniteJump(false)
    MovementEngine.SetNoclip(false)
    MovementEngine.SetWalkOnWater(false)
    MovementEngine.SetAntiLava(false)
    MovementEngine.SetFly(false, 70)

    pcall(function()
        local _, hum = getCharacter()
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
        end
    end)
end

return MovementEngine
