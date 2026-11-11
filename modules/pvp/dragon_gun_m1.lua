--[[
    Darling X - Dragon Gun M1 Ultra Fast Engine
    Exact upvalue resolution and RenderStepped burst loop.
    Zero emojis, zero third-party references.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

_G.G_DragonGunM1 = false
_G.G_AttackMobs = true
_G.G_AttackPlayers = true
_G.G_AttackSeaEvents = true
_G.G_MaxDistance = 400
_G.G_ShotsPerFrame = 3

local Modules = ReplicatedStorage:WaitForChild("Modules", 5)
local DragonNet = Modules and Modules:WaitForChild("Net", 5)
local ShootGunEvent = DragonNet and DragonNet:WaitForChild("RE/ShootGunEvent", 5)
local Validator2 = ReplicatedStorage:WaitForChild("Remotes", 5):WaitForChild("Validator2", 5)

local getupval = debug.getupvalue or getupvalue
local setupval = debug.setupvalue or setupvalue
local getupvals = debug.getupvalues or getupvalues

local ShootFunction
local V_Idx = { v26 = 12, v22 = 13, v25 = 14, v21 = 15, v23 = 16, v24 = 17, v27 = 18 }

local function InitDragonGun()
    local success, result = pcall(require, ReplicatedStorage:WaitForChild("Controllers"):WaitForChild("CombatController"))
    if success and type(result) == "table" and result.Attack then
        ShootFunction = getupval(result.Attack, 9)
    end
end

local function GetNextValidator()
    if not ShootFunction then InitDragonGun() end
    if not ShootFunction then return 0, 0 end
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

local function GetEntityPart(entity)
    return entity:FindFirstChild("HumanoidRootPart") 
        or entity:FindFirstChild("Engine") 
        or entity:FindFirstChild("Head") 
        or entity:FindFirstChild("Base") 
        or entity.PrimaryPart
end

local function GetClosestTarget()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    
    local closest, dist = nil, _G.G_MaxDistance
    local myPos = root.Position

    if _G.G_AttackMobs then
        local enemies = workspace:FindFirstChild("Enemies")
        if enemies then
            for _, enemy in ipairs(enemies:GetChildren()) do
                local hum = enemy:FindFirstChildOfClass("Humanoid")
                local r = GetEntityPart(enemy)
                if hum and hum.Health > 0 and r then
                    local d = (r.Position - myPos).Magnitude
                    if d < dist then dist = d; closest = r end
                end
            end
        end
    end

    if _G.G_AttackSeaEvents then
        local seaFolders = { workspace:FindFirstChild("SeaBeasts"), workspace:FindFirstChild("SeaEvents") }
        for _, folder in ipairs(seaFolders) do
            if folder then
                for _, seaMob in ipairs(folder:GetChildren()) do
                    local hum = seaMob:FindFirstChildOfClass("Humanoid")
                    local r = GetEntityPart(seaMob)
                    if r and (not hum or hum.Health > 0) then
                        local d = (r.Position - myPos).Magnitude
                        if d < dist then dist = d; closest = r end
                    end
                end
            end
        end

        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and obj ~= char then
                local name = obj.Name:lower()
                if name:find("ship") or name:find("boat") or name:find("beast") or name:find("terror") or name:find("piranha") or name:find("leviathan") then
                    local hum = obj:FindFirstChildOfClass("Humanoid")
                    local r = GetEntityPart(obj)
                    if r and (not hum or hum.Health > 0) then
                        local d = (r.Position - myPos).Magnitude
                        if d < dist then dist = d; closest = r end
                    end
                end
            end
        end
    end

    if _G.G_AttackPlayers then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local hum = player.Character:FindFirstChildOfClass("Humanoid")
                local r = player.Character:FindFirstChild("HumanoidRootPart")
                if hum and hum.Health > 0 and r then
                    local d = (r.Position - myPos).Magnitude
                    if d < dist then dist = d; closest = r end
                end
            end
        end
    end

    return closest
end

-- RenderStepped attack loop
RunService.RenderStepped:Connect(function()
    if not _G.G_DragonGunM1 then return end
    
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    
    if tool and tool.ToolTip == "Gun" then
        local target = GetClosestTarget()
        if target then
            for i = 1, _G.G_ShotsPerFrame do
                local code, count = GetNextValidator()
                if code ~= 0 and Validator2 then 
                    Validator2:FireServer(code, count) 
                end
                
                tool:SetAttribute("LocalOverheat", 0)
                tool:SetAttribute("LocalTotalShots", (tool:GetAttribute("LocalTotalShots") or 0) + 1)
                
                if ShootGunEvent then
                    ShootGunEvent:FireServer(target.Position, { target })
                end
            end
        end
    end
end)

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

-- Keybind G support
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.G and _G.DarlingX_DragonM1Enabled then
        _G.G_DragonGunM1 = not _G.G_DragonGunM1
        local widgets = getWidgets()
        if widgets and widgets.UpdateDragonM1Visual then
            widgets.UpdateDragonM1Visual(_G.G_DragonGunM1)
        end
    end
end)

local DragonGunModule = {
    SetEnabled = function(state)
        _G.G_DragonGunM1 = (state == true)
        local widgets = getWidgets()
        if widgets and widgets.UpdateDragonM1Visual then
            widgets.UpdateDragonM1Visual(_G.G_DragonGunM1)
        end
    end,
    SetWidgetVisible = function(state)
        local widgets = getWidgets()
        if widgets and widgets.SetDragonM1WidgetVisible then
            widgets.SetDragonM1WidgetVisible(state == true)
        end
    end,
    UpdateVisual = function(state)
        local widgets = getWidgets()
        if widgets and widgets.UpdateDragonM1Visual then
            widgets.UpdateDragonM1Visual(state)
        end
    end,
}

return DragonGunModule
