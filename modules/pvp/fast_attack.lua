--[[
    Darling X - Fast Attack Engine
    Classic high-speed M1 Fast Attack for Blox Fruits.
    Autonomous remote resolution, direct held tool detection, and Stepped burst firing.
    Zero emojis, zero third-party references.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local FastAttack = {
    Enabled = false,
    Distance = 85,
    ClickDelay = 0,
    Running = false,
}

local RegisterAttack = nil
local RegisterHit = nil

local function resolveRemotes()
    if RegisterAttack and RegisterHit then return true end
    pcall(function()
        local net = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Net")
        if net then
            RegisterAttack = net:FindFirstChild("RE/RegisterAttack") or net:FindFirstChild("RegisterAttack")
            RegisterHit = net:FindFirstChild("RE/RegisterHit") or net:FindFirstChild("RegisterHit")
        end
        if not (RegisterAttack and RegisterHit) then
            for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
                if v:IsA("RemoteEvent") then
                    if v.Name == "RE/RegisterHit" or v.Name == "RegisterHit" then
                        RegisterHit = v
                    elseif v.Name == "RE/RegisterAttack" or v.Name == "RegisterAttack" then
                        RegisterAttack = v
                    end
                end
                if RegisterHit and RegisterAttack then break end
            end
        end
    end)
    return (RegisterAttack ~= nil and RegisterHit ~= nil)
end

resolveRemotes()

local function isAlive(char)
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function collectEnemies()
    local char = LocalPlayer.Character
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
    if not root then return nil, {} end

    local myPos = root.Position
    local enemiesList = {}
    local basePart = nil
    local shortestDist = FastAttack.Distance

    local function processFolder(folder)
        if not folder then return end
        for _, enemy in ipairs(folder:GetChildren()) do
            if enemy ~= char and isAlive(enemy) then
                local head = enemy:FindFirstChild("Head") or enemy:FindFirstChild("HumanoidRootPart")
                if head then
                    local d = (head.Position - myPos).Magnitude
                    if d <= FastAttack.Distance then
                        table.insert(enemiesList, { enemy, head })
                        if d < shortestDist then
                            shortestDist = d
                            basePart = head
                        end
                    end
                end
            end
        end
    end

    processFolder(Workspace:FindFirstChild("Enemies"))
    processFolder(Workspace:FindFirstChild("Characters"))

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local enemyChar = p.Character
            if isAlive(enemyChar) then
                local head = enemyChar:FindFirstChild("Head") or enemyChar:FindFirstChild("HumanoidRootPart")
                if head then
                    local d = (head.Position - myPos).Magnitude
                    if d <= FastAttack.Distance then
                        table.insert(enemiesList, { enemyChar, head })
                        if d < shortestDist then
                            shortestDist = d
                            basePart = head
                        end
                    end
                end
            end
        end
    end

    return basePart, enemiesList
end

local function performAttack(basePart, enemiesList)
    if not basePart or #enemiesList == 0 then return end
    resolveRemotes()
    if RegisterAttack then
        pcall(function() RegisterAttack:FireServer(FastAttack.ClickDelay) end)
    end
    if RegisterHit then
        pcall(function() RegisterHit:FireServer(basePart, enemiesList) end)
    end
end

local attackThread = nil

function FastAttack.enable()
    FastAttack.Enabled = true
    if attackThread then return end
    attackThread = task.spawn(function()
        while FastAttack.Enabled do
            task.wait(0.05)
            pcall(function()
                local char = LocalPlayer.Character
                if not char then return end

                local tool = char:FindFirstChildOfClass("Tool")
                if not tool or tool.ToolTip == "Gun" then return end

                local basePart, enemiesList = collectEnemies()
                if basePart and #enemiesList > 0 then
                    performAttack(basePart, enemiesList)
                end
            end)
        end
        attackThread = nil
    end)
end

function FastAttack.disable()
    FastAttack.Enabled = false
    if attackThread then
        task.cancel(attackThread)
        attackThread = nil
    end
end

function FastAttack.toggle(state)
    if state == nil then state = not FastAttack.Enabled end
    if state then FastAttack.enable() else FastAttack.disable() end
end

return FastAttack
