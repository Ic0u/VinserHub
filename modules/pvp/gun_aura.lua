--[[
    Vinser Hub - M1 Gun Aura Engine
    Autonomous rapid-fire gunfire against nearest enemies and players.
    Supports Dragon Gun, Soul Guitar, Kabucha, Acidum Rifle, Serpent Bow, Flintlocks, etc.
    Zero emojis, zero third-party references.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local GunAura = {
    Enabled = false,
    TargetMode = "Both", -- "Players", "Enemies", "Both"
    MaxDistance = 350,
    ShotsPerFrame = 2,
    AutoEquip = true,
    IgnoreSafeZone = true,

    LoopConn = nil,
}

_G.VinsersHub_GunAura = false
_G.G_DragonGunM1 = false

local Modules = ReplicatedStorage:WaitForChild("Modules", 5)
local Net = Modules and Modules:WaitForChild("Net", 5)
local ShootGunEvent = Net and Net:WaitForChild("RE/ShootGunEvent", 5)
local Validator2 = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Validator2")

local getupval = debug.getupvalue or getupvalue
local setupval = debug.setupvalue or setupvalue
local getupvals = debug.getupvalues or getupvalues

local ShootFunction
local V_Idx = { v26 = 12, v22 = 13, v25 = 14, v21 = 15, v23 = 16, v24 = 17, v27 = 18 }

local function initCombatController()
    local ok, res = pcall(require, ReplicatedStorage:WaitForChild("Controllers", 5):WaitForChild("CombatController", 5))
    if ok and type(res) == "table" and res.Attack and getupval then
        ShootFunction = getupval(res.Attack, 9)
    end
end

local function getNextValidator()
    if not ShootFunction then initCombatController() end
    if not ShootFunction or not getupvals or not setupval then return 0, 0 end
    local upvals = getupvals(ShootFunction)
    if not upvals then return 0, 0 end

    if upvals[V_Idx.v21] ~= 727595 then
        for i, v in pairs(upvals) do
            if v == 727595 then
                local offset = i - 15
                V_Idx.v21 = i; V_Idx.v22 = 13 + offset; V_Idx.v23 = 16 + offset
                V_Idx.v24 = 17 + offset; V_Idx.v26 = 12 + offset; V_Idx.v25 = 14 + offset
                V_Idx.v27 = 18 + offset
                break
            end
        end
    end

    local v1 = getupval(ShootFunction, V_Idx.v21)
    local v2 = getupval(ShootFunction, V_Idx.v22)
    local v3 = getupval(ShootFunction, V_Idx.v23)
    local v4 = getupval(ShootFunction, V_Idx.v24)
    local v5 = getupval(ShootFunction, V_Idx.v25)
    local v6 = getupval(ShootFunction, V_Idx.v26)
    local v7 = getupval(ShootFunction, V_Idx.v27)

    if not (v1 and v2 and v3 and v4 and v5 and v6 and v7) then return 0, 0 end

    local v8 = v6 * v2
    local v9 = (v5 * v2 + v6 * v1) % v3
    v9 = (v9 * v3 + v8) % v4
    v5 = math.floor(v9 / v3)
    v6 = v9 - v5 * v3
    v7 = v7 + 1

    setupval(ShootFunction, V_Idx.v25, v5)
    setupval(ShootFunction, V_Idx.v26, v6)
    setupval(ShootFunction, V_Idx.v27, v7)
    return math.floor(v9 / v4 * 16777215), v7
end

local function isGunTool(tool)
    if not (tool and tool:IsA("Tool")) then return false end
    if tool.ToolTip == "Gun" or tool:GetAttribute("WeaponType") == "Gun" then return true end
    local n = string.lower(tool.Name)
    if n:find("gun") or n:find("rifle") or n:find("guitar") or n:find("cannon") or n:find("bow") or n:find("flintlock") or n:find("kabucha") or n:find("slingshot") or n:find("bazooka") then
        return true
    end
    return false
end

local function getEquippedGun()
    local char = LocalPlayer.Character
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if isGunTool(tool) then return tool end

    if GunAura.AutoEquip and LocalPlayer:FindFirstChild("Backpack") then
        for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do
            if isGunTool(t) then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum:EquipTool(t)
                    return t
                end
            end
        end
    end
    return nil
end

local function getClosestTarget()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local myPos = hrp.Position
    local closestPart = nil
    local shortestDist = GunAura.MaxDistance or 350

    local checkPlayers = (GunAura.TargetMode == "Players" or GunAura.TargetMode == "Both")
    local checkEnemies = (GunAura.TargetMode == "Enemies" or GunAura.TargetMode == "Both")

    -- 1. Check Players
    if checkPlayers then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local eChar = p.Character
                local eHrp = eChar:FindFirstChild("HumanoidRootPart")
                local eHum = eChar:FindFirstChildOfClass("Humanoid")
                if eHrp and eHum and eHum.Health > 0 then
                    -- Safe zone / PvP check
                    local inSafeZone = eChar:FindFirstChild("SafeZone") or (eChar:GetAttribute("SafeZone") == true)
                    if not (GunAura.IgnoreSafeZone and inSafeZone) then
                        local d = (eHrp.Position - myPos).Magnitude
                        if d < shortestDist then
                            shortestDist = d
                            closestPart = eHrp
                        end
                    end
                end
            end
        end
    end

    -- 2. Check NPC Enemies
    if checkEnemies then
        local enemiesFolder = Workspace:FindFirstChild("Enemies")
        if enemiesFolder then
            for _, mob in ipairs(enemiesFolder:GetChildren()) do
                local mHum = mob:FindFirstChildOfClass("Humanoid")
                local mHrp = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart or mob:FindFirstChild("Head")
                if mHum and mHrp and mHum.Health > 0 then
                    local d = (mHrp.Position - myPos).Magnitude
                    if d < shortestDist then
                        shortestDist = d
                        closestPart = mHrp
                    end
                end
            end
        end
    end

    return closestPart
end

local function onRenderStep()
    if not GunAura.Enabled then return end

    local gun = getEquippedGun()
    if not gun then return end

    local targetPart = getClosestTarget()
    if not targetPart then return end

    local shots = math.clamp(GunAura.ShotsPerFrame or 2, 1, 5)
    for _ = 1, shots do
        local code, count = getNextValidator()
        if code ~= 0 and Validator2 then
            pcall(function() Validator2:FireServer(code, count) end)
        end

        pcall(function()
            gun:SetAttribute("LocalOverheat", 0)
            gun:SetAttribute("LocalTotalShots", (gun:GetAttribute("LocalTotalShots") or 0) + 1)
        end)

        if ShootGunEvent then
            pcall(function()
                ShootGunEvent:FireServer(targetPart.Position, { targetPart })
            end)
        else
            local localShoot = gun:FindFirstChild("ShootGunEvent")
            if localShoot and localShoot:IsA("RemoteEvent") then
                pcall(function() localShoot:FireServer(targetPart.Position, { targetPart }) end)
            else
                pcall(function() gun:Activate() end)
            end
        end
    end
end

function GunAura.SetEnabled(state)
    GunAura.Enabled = (state == true)
    _G.VinsersHub_GunAura = GunAura.Enabled
    _G.G_DragonGunM1 = GunAura.Enabled
    _G.DarlingX_DragonM1Enabled = GunAura.Enabled

    if GunAura.Enabled and not GunAura.LoopConn then
        GunAura.LoopConn = RunService.RenderStepped:Connect(onRenderStep)
    elseif not GunAura.Enabled and GunAura.LoopConn then
        pcall(function() GunAura.LoopConn:Disconnect() end)
        GunAura.LoopConn = nil
    end
end

function GunAura.SetTargetMode(mode)
    if mode == "Players" or mode == "Enemies" or mode == "Both" then
        GunAura.TargetMode = mode
    end
end

function GunAura.SetRange(val)
    GunAura.MaxDistance = tonumber(val) or 350
end

function GunAura.SetShotsPerFrame(val)
    GunAura.ShotsPerFrame = tonumber(val) or 2
end

function GunAura.SetAutoEquip(state)
    GunAura.AutoEquip = (state == true)
end

return GunAura
