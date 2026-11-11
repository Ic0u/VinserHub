-- aimbot core

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer and LocalPlayer:GetMouse()

local Core = {
    -- Master Toggles
    PlayerAimEnabled = false,
    NPCAimEnabled = false,
    TeamCheck = false,

    -- Settings (360 degrees default)
    AimMode = "360", -- "360", "FOV", "180"
    TargetPriority = "Nearest", -- "Nearest", "Low HP", "Looking At Me"
    TargetPart = "Head", -- "Head", "HumanoidRootPart"
    MaxRange = 1000,
    PredictionEnabled = true,
    PredictionAmount = 0.12,

    -- FOV Settings
    FOV = {
        Visible = false,
        Radius = 100,
        Mode = "Center", -- "Center", "Mouse"
        Color = Color3.fromRGB(255, 255, 255),
        Thickness = 1.5,
    },

    -- Tracer Settings
    Tracers = {
        Visible = false,
        Color = Color3.fromRGB(255, 255, 255),
        Thickness = 1.5,
    },

    -- resolved targets
    CurrentTargetPart = nil,
    CurrentTargetRawPosition = nil,
    CurrentTargetPosition = nil,
    CurrentTargetCharacter = nil,
    CurrentTargetIsPlayer = false,
    LockPlayer = false,
    LockedTargetPlayer = nil,

    -- tool & skill tracking
    CurrentTool = nil,
    CurrentToolCategory = "Melee",
    CurrentSkillKey = nil,
    LastSkillTime = 0,

    -- skill blacklist
    BlacklistedKeys = {
        Melee = { Z = false, X = false, C = false },
        Sword = { Z = false, X = false },
        Fruit = { Z = false, X = false, C = false, V = false, F = false, TAP = false },
        Gun   = { Z = false, X = false },
    },

    -- internal hooks & lifecycle
    IsHooked = false,
    RenderConnection = nil,
    CharConnections = {},
    LastVelocity = nil,
    LastDirection = nil,
}

local SKILL_KEYS = { "Z", "X", "C", "V", "F", "TAP" }

-- tool categorization
function Core.getToolCategory(tool)
    if not tool or not tool:IsA("Tool") then return "Melee" end
    pcall(function()
        local tip = string.lower(tool.ToolTip or "")
        if string.find(tip, "melee") then return "Melee" end
        if string.find(tip, "sword") then return "Sword" end
        if string.find(tip, "fruit") then return "Fruit" end
        if string.find(tip, "gun") then return "Gun" end
    end)
    local name = string.lower(tool.Name)

    local gunNames = { "guitar", "rifle", "cannon", "gun", "slingshot", "kabucha", "bow" }
    for _, g in ipairs(gunNames) do
        if string.find(name, g) then return "Gun" end
    end

    local meleeNames = { "claw", "godhuman", "superhuman", "talon", "step", "karate", "breath", "kung fu", "combat", "fist", "sanguine" }
    for _, m in ipairs(meleeNames) do
        if string.find(name, m) then return "Melee" end
    end

    if tool.ToolTip == "Blox Fruit" or string.find(name, "fruit") or string.find(name, "-") then
        return "Fruit"
    end

    return "Sword"
end

-- blacklist checks
function Core.isKeyBlacklisted(category, key)
    if not key then return false end
    category = category or Core.CurrentToolCategory or "Melee"
    if Core.BlacklistedKeys[category] and Core.BlacklistedKeys[category][key] ~= nil then
        if Core.BlacklistedKeys[category][key] == true then return true end
    end
    if (key == "V" or key == "F" or key == "TAP") and Core.BlacklistedKeys.Fruit and Core.BlacklistedKeys.Fruit[key] == true then
        return true
    end
    -- Fallback to global blacklist table if configured via dropdown
    if _G.DarlingHub and _G.DarlingHub.Settings and _G.DarlingHub.Settings.Blacklist then
        local b = _G.DarlingHub.Settings.Blacklist[category]
        if b and b[key] == true then return true end
    end
    return false
end

function Core.isPlayerBlacklisted(player)
    if not player then return false end
    if _G.DarlingBlacklistedPlayers then
        if _G.DarlingBlacklistedPlayers[player.UserId] == true or _G.DarlingBlacklistedPlayers[player.Name] == true then
            return true
        end
    end
    return false
end

-- ============================================================================
-- HEALTH & HITBOX UTILITIES
-- ============================================================================
local function isAlive(char)
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function getEntityPart(char)
    if not char then return nil end
    local hubSettings = (_G.DarlingHub and _G.DarlingHub.Settings and _G.DarlingHub.Settings.Aim)
    local prefPart = (hubSettings and hubSettings.Hitbox) or Core.TargetHitbox or Core.TargetPart or "HumanoidRootPart"
    return char:FindFirstChild(prefPart)
        or char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("Head")
        or char:FindFirstChildWhichIsA("BasePart")
end

local function getHRP(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("Head")
end

-- ============================================================================
-- ENEMY & TARGET FILTER
-- ============================================================================
local function isSilentAimAlly(player)
    if not player then return false end
    local main = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("Main")
    local frame = main and main:FindFirstChild("Allies")
        and main.Allies:FindFirstChild("Container")
        and main.Allies.Container:FindFirstChild("Allies")
        and main.Allies.Container.Allies:FindFirstChild("ScrollingFrame")
        and main.Allies.Container.Allies.ScrollingFrame:FindFirstChild("Frame")
    if frame and frame:FindFirstChild(player.Name) then return true end
    return false
end

local function isEnemy(targetPlayer)
    if not targetPlayer or targetPlayer == LocalPlayer then return false end
    if Core.isPlayerBlacklisted(targetPlayer) then return false end
    if isSilentAimAlly(targetPlayer) then return false end

    local myTeam = LocalPlayer and LocalPlayer.Team
    local targetTeam = targetPlayer.Team
    if Core.TeamCheck and myTeam and targetTeam and myTeam == targetTeam then
        return false
    end
    if myTeam and targetTeam and myTeam.Name == "Marines" and targetTeam.Name == "Marines" then
        return false
    end
    return true
end

-- ============================================================================
-- FOV & ANGLE VALIDATION
-- ============================================================================
function Core.getFOVCenter()
    Camera = Workspace.CurrentCamera or Camera
    local hubSettings = (_G.DarlingHub and _G.DarlingHub.Settings and _G.DarlingHub.Settings.FOV) or Core.FOV
    if hubSettings.Mode == "Mouse" then
        local p = UserInputService:GetMouseLocation()
        if p.X > 0 and p.Y > 0 then return p end
    end
    return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

function Core.getFOVRadius()
    local hubSettings = (_G.DarlingHub and _G.DarlingHub.Settings and _G.DarlingHub.Settings.FOV) or Core.FOV
    return hubSettings.Radius or Core.FOV.Radius or 100
end

-- ============================================================================
-- PREDICTION ENGINE
-- ============================================================================
function Core.predictPosition(targetPart)
    if not targetPart then return nil end
    local char = targetPart.Parent
    if not isAlive(char) then return targetPart.Position end

    -- Hitscan weapons (swords / Buddy Sword) do not lead with velocity prediction
    local isSword = (Core.CurrentToolCategory == "Sword") or (Core.CurrentTool and (string.find(Core.CurrentTool.Name, "Sword") or string.find(Core.CurrentTool.Name, "Buddy")))
    if isSword then
        return targetPart.Position
    end

    local hubSettings = (_G.DarlingHub and _G.DarlingHub.Settings and _G.DarlingHub.Settings.Aim) or Core
    if hubSettings.Prediction == false or Core.PredictionEnabled == false then
        return targetPart.Position
    end

    local hrp = char:FindFirstChild("HumanoidRootPart") or targetPart
    local vel = hrp.Velocity
    local speed = vel.Magnitude

    if speed < 4 then
        Core.LastVelocity = nil
        Core.LastDirection = nil
        return targetPart.Position
    end

    local currentDir = vel.Unit
    if Core.LastDirection then
        local dot = Core.LastDirection:Dot(currentDir)
        if dot < 0.65 then
            Core.LastVelocity = nil
            Core.LastDirection = nil
            return targetPart.Position
        end
    end

    Core.LastDirection = currentDir
    Core.LastVelocity = vel

    local ping = 0
    pcall(function()
        local serverStats = Stats.Network:FindFirstChild("ServerStatsItem")
        if serverStats and serverStats:FindFirstChild("Data Ping") then
            ping = serverStats["Data Ping"]:GetValue() / 1000
        end
    end)
    ping = math.clamp(ping, 0, 0.25)

    local factor = (hubSettings.PredictionAmount or Core.PredictionAmount or 0.12) + ping
    if speed > 100 then factor = math.min(factor, 0.14) end

    return targetPart.Position + (vel * factor)
end

-- target selection
local function resolvePlayerTarget(lpHRP)
    if not lpHRP then return nil, nil, nil end
    Camera = Workspace.CurrentCamera or Camera

    local hubSettings = (_G.DarlingHub and _G.DarlingHub.Settings and _G.DarlingHub.Settings.Aim) or Core
    local maxRange = hubSettings.MaxRange or Core.MaxRange or 1000
    local aimMode = hubSettings.Mode or Core.AimMode or "360"
    local fovCenter = Core.getFOVCenter()
    local fovRadius = Core.getFOVRadius()
    local priority = hubSettings.Priority or Core.TargetPriority or "Nearest"
    local myPos = lpHRP.Position

    -- 1. Explicit selected player override (from Player List tab)
    if Core.SelectedPlayer and Core.SelectedPlayer ~= LocalPlayer and Core.SelectedPlayer.Character and isAlive(Core.SelectedPlayer.Character) then
        local part = getEntityPart(Core.SelectedPlayer.Character)
        if part and (part.Position - myPos).Magnitude <= maxRange then
            local predPos = Core.predictPosition(part)
            return part, predPos, Core.SelectedPlayer.Character
        end
    end

    -- 2. Lock Player feature: keep target locked onto the acquired player
    if Core.LockPlayer and Core.LockedTargetPlayer and Core.LockedTargetPlayer ~= LocalPlayer and Core.LockedTargetPlayer.Character and isAlive(Core.LockedTargetPlayer.Character) and not Core.isPlayerBlacklisted(Core.LockedTargetPlayer) then
        local part = getEntityPart(Core.LockedTargetPlayer.Character)
        if part and (part.Position - myPos).Magnitude <= maxRange then
            local predPos = Core.predictPosition(part)
            return part, predPos, Core.LockedTargetPlayer.Character
        else
            Core.LockedTargetPlayer = nil
        end
    end

    local bestPart = nil
    local bestScore = math.huge
    local bestChar = nil
    local bestPlayer = nil

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and isEnemy(pl) and not Core.isPlayerBlacklisted(pl) and pl.Character and isAlive(pl.Character) then
            local part = getEntityPart(pl.Character)
            if part then
                local worldDist = (part.Position - myPos).Magnitude
                if worldDist <= maxRange then
                    local allowed = false
                    local distScore = worldDist

                    if aimMode == "FOV" then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                        if onScreen then
                            local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - fovCenter).Magnitude
                            if screenDist <= fovRadius then
                                allowed = true
                                distScore = screenDist
                            end
                        end
                    elseif aimMode == "180" then
                        local dir = (part.Position - myPos).Unit
                        if lpHRP.CFrame.LookVector:Dot(dir) >= 0 then
                            allowed = true
                            distScore = worldDist
                        end
                    else -- "360" (DEFAULT)
                        allowed = true
                        distScore = worldDist
                    end

                    if allowed then
                        local score = distScore
                        if priority == "Low HP" then
                            local hum = pl.Character:FindFirstChildOfClass("Humanoid")
                            score = hum and hum.Health or distScore
                        elseif priority == "Looking At Me" then
                            local plHRP = getHRP(pl.Character)
                            if plHRP then
                                local toMe = (myPos - plHRP.Position).Unit
                                local dot = plHRP.CFrame.LookVector:Dot(toMe)
                                score = 1 - dot
                            end
                        end

                        if score < bestScore then
                            bestScore = score
                            bestPart = part
                            bestChar = pl.Character
                            bestPlayer = pl
                        end
                    end
                end
            end
        end
    end

    if bestPart then
        if Core.LockPlayer and not Core.LockedTargetPlayer then
            Core.LockedTargetPlayer = bestPlayer
        end
        local predPos = Core.predictPosition(bestPart)
        return bestPart, predPos, bestChar
    end
    return nil, nil, nil
end

local function resolveNPCTarget(lpHRP)
    if not lpHRP then return nil, nil, nil end
    Camera = Workspace.CurrentCamera or Camera

    local hubSettings = (_G.DarlingHub and _G.DarlingHub.Settings and _G.DarlingHub.Settings.Aim) or Core
    local maxRange = hubSettings.MaxRange or Core.MaxRange or 1000
    local aimMode = hubSettings.Mode or Core.AimMode or "360"
    local fovCenter = Core.getFOVCenter()
    local fovRadius = Core.getFOVRadius()

    local closestPart = nil
    local shortestDist = math.huge
    local targetChar = nil
    local myPos = lpHRP.Position

    local function isAttackableEnemy(entity)
        if not entity or not entity:IsA("Model") then return false end
        if Players:GetPlayerFromCharacter(entity) then return false end
        if not isAlive(entity) then return false end
        if entity:FindFirstChildWhichIsA("Dialog") or entity:FindFirstChildWhichIsA("ClickDetector") then return false end
        if entity:FindFirstChild("Quest") or entity:FindFirstChild("QuestGiver") or entity:FindFirstChild("Dialogue") then return false end
        local name = string.lower(entity.Name)
        local nonCombat = { "quest", "dealer", "shop", "spawn", "trainer", "boat", "blacksmith", "recruiter", "hunter", "luxury", "garrick" }
        for _, kw in ipairs(nonCombat) do
            if string.find(name, kw) then return false end
        end
        return true
    end

    local function checkEntity(entity)
        if isAttackableEnemy(entity) then
            local part = getEntityPart(entity)
            if part then
                local worldDist = (part.Position - myPos).Magnitude
                if worldDist <= maxRange then
                    if aimMode == "FOV" then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                        if onScreen then
                            local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - fovCenter).Magnitude
                            if screenDist <= fovRadius and screenDist < shortestDist then
                                shortestDist = screenDist
                                closestPart = part
                                targetChar = entity
                            end
                        end
                    elseif aimMode == "180" then
                        local dir = (part.Position - myPos).Unit
                        if lpHRP.CFrame.LookVector:Dot(dir) >= 0 and worldDist < shortestDist then
                            shortestDist = worldDist
                            closestPart = part
                            targetChar = entity
                        end
                    else -- "360" (DEFAULT)
                        if worldDist < shortestDist then
                            shortestDist = worldDist
                            closestPart = part
                            targetChar = entity
                        end
                    end
                end
            end
        end
    end

    local folders = {
        Workspace:FindFirstChild("Enemies"),
        Workspace:FindFirstChild("Characters"),
    }
    for _, f in ipairs(folders) do
        if f then
            for _, child in ipairs(f:GetChildren()) do
                checkEntity(child)
            end
        end
    end

    if closestPart then
        local predPos = Core.predictPosition(closestPart)
        return closestPart, predPos, targetChar
    end
    return nil, nil, nil
end

function Core.resolveAnyTarget()
    Camera = Workspace.CurrentCamera or Camera
    local char = LocalPlayer and LocalPlayer.Character
    local lpHRP = char and getHRP(char)
    if not lpHRP then return nil, nil, nil end

    if Core.PlayerAimEnabled then
        local pPart, pPos, pChar = resolvePlayerTarget(lpHRP)
        if pPart and pPos then return pPart, pPos, pChar end
        if not Core.NPCAimEnabled then
            return nil, nil, nil
        end
    end

    if Core.NPCAimEnabled then
        local nPart, nPos, nChar = resolveNPCTarget(lpHRP)
        if nPart and nPos then return nPart, nPos, nChar end
        return nil, nil, nil
    end

    -- Fallback for Tracers when neither master aimbot toggle is active yet:
    local pPart, pPos, pChar = resolvePlayerTarget(lpHRP)
    if pPart and pPos then return pPart, pPos, pChar end
    return resolveNPCTarget(lpHRP)
end

-- ============================================================================
-- ROTATION TOWARDS TARGET (SAFE ASYNC - NO CRASH)
-- ============================================================================
local lastFaceTargetTick = 0
function Core.faceTarget(targetPos)
    if not targetPos then return end
    local now = os.clock()
    if (now - lastFaceTargetTick) < 0.1 then return end
    lastFaceTargetTick = now
    pcall(function()
        local char = LocalPlayer and LocalPlayer.Character
        local hrp = char and getHRP(char)
        if not hrp or not hrp.Parent then return end

        local currentPos = hrp.Position
        local diff = Vector3.new(targetPos.X, currentPos.Y, targetPos.Z) - currentPos
        if diff.Magnitude < 0.5 then return end

        local look = diff.Unit
        if (look.X == look.X) and (look.Z == look.Z) then
            hrp.CFrame = CFrame.lookAt(currentPos, currentPos + look, Vector3.new(0, 1, 0))
        end
    end)
end

-- skill tracking
function Core.setCurrentSkillKey(key)
    Core.CurrentSkillKey = key
    Core.LastSkillTime = os.clock()

    if (Core.PlayerAimEnabled or Core.NPCAimEnabled) and Core.CurrentTargetPart then
        local targetPart = Core.CurrentTargetPart
        if targetPart and not Core.isKeyBlacklisted(Core.CurrentToolCategory, key) then
            task.spawn(function() Core.faceTarget(targetPart.Position) end)
        end
    end

    task.spawn(function()
        local capturedTime = Core.LastSkillTime
        task.wait(1.5)
        if Core.LastSkillTime == capturedTime and Core.CurrentSkillKey == key then
            Core.CurrentSkillKey = nil
        end
    end)
end

local function getSkillKeyFromArgs(args)
    for _, arg in ipairs(args) do
        if type(arg) == "string" and table.find(SKILL_KEYS, arg) then
            return arg
        end
    end
    return nil
end

-- metatable hooks
function Core.installHooks()
    if Core.IsHooked then return end
    Core.IsHooked = true

    -- Hook 1: Mouse.__index (Hit, Target, UnitRay, Origin, Direction)
    local mouse = LocalPlayer and LocalPlayer:GetMouse()
    if mouse then
        local okHook, _ = pcall(function()
            local oldIndex
            oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
                -- Fast-exit 1: Must be LocalPlayer mouse object
                if self ~= mouse or (checkcaller and checkcaller()) then
                    return oldIndex(self, key)
                end
                -- Fast-exit 2: Only intercept targeting properties
                if key ~= "Hit" and key ~= "Target" and key ~= "UnitRay" and key ~= "Origin" and key ~= "Direction" then
                    return oldIndex(self, key)
                end
                local target = Core.CurrentTargetPart or _G.currentSilentAimTarget or _G.DarlingSilentAimTarget
                if (Core.LockPlayer or Core.PlayerAimEnabled or Core.NPCAimEnabled or _G.G_SilentAimM1R or _G.G_SilentAimSkill) and target then
                    local activeKey = Core.CurrentSkillKey
                    if activeKey and Core.isKeyBlacklisted(Core.CurrentToolCategory, activeKey) then
                        return oldIndex(self, key)
                    end
                    local isSword = (Core.CurrentToolCategory == "Sword") or (Core.CurrentTool and (string.find(Core.CurrentTool.Name, "Sword") or string.find(Core.CurrentTool.Name, "Buddy")))
                    local tp = (isSword and Core.CurrentTargetRawPosition) or (target and target.Position) or Core.CurrentTargetPosition or Core.CurrentTargetRawPosition
                    if tp and (tp.X == tp.X) then
                        local cam = Camera or Workspace.CurrentCamera
                        local cp = cam and cam.CFrame.Position or Vector3.zero
                        if key == "Hit" then
                            return CFrame.new(tp)
                        elseif key == "Target" then
                            return target
                        elseif key == "UnitRay" then
                            local diff = tp - cp
                            if diff.Magnitude > 0.01 then
                                return Ray.new(cp, diff.Unit)
                            end
                        elseif key == "Origin" then
                            return CFrame.new(cp, tp)
                        elseif key == "Direction" then
                            local diff = tp - cp
                            if diff.Magnitude > 0.01 then
                                return diff.Unit
                            end
                        end
                    end
                end
                return oldIndex(self, key)
            end))
        end)

        if not okHook then
            local rawMt = getrawmetatable(game)
            if rawMt then
                local oldIndex = rawMt.__index
                pcall(setreadonly, rawMt, false)
                rawMt.__index = newcclosure(function(t, k)
                    if t ~= mouse or (checkcaller and checkcaller()) then
                        return oldIndex(t, k)
                    end
                    if k ~= "Hit" and k ~= "Target" and k ~= "UnitRay" and k ~= "Origin" and k ~= "Direction" then
                        return oldIndex(t, k)
                    end
                    local target = Core.CurrentTargetPart or _G.currentSilentAimTarget or _G.DarlingSilentAimTarget
                    if (Core.PlayerAimEnabled or Core.NPCAimEnabled or Core.LockPlayer or _G.G_SilentAimM1R or _G.G_SilentAimSkill) and target then
                        local activeKey = Core.CurrentSkillKey
                        if activeKey and Core.isKeyBlacklisted(Core.CurrentToolCategory, activeKey) then
                            return oldIndex(t, k)
                        end
                        local isSword = (Core.CurrentToolCategory == "Sword") or (Core.CurrentTool and (string.find(Core.CurrentTool.Name, "Sword") or string.find(Core.CurrentTool.Name, "Buddy")))
                        local tp = (isSword and Core.CurrentTargetRawPosition) or (target and target.Position) or Core.CurrentTargetPosition or Core.CurrentTargetRawPosition
                        if tp and (tp.X == tp.X) then
                            local cam = Camera or Workspace.CurrentCamera
                            local cp = cam and cam.CFrame.Position or Vector3.zero
                            if k == "Hit" then
                                return CFrame.new(tp)
                            elseif k == "Target" then
                                return target
                            elseif k == "UnitRay" then
                                local diff = tp - cp
                                if diff.Magnitude > 0.01 then
                                    return Ray.new(cp, diff.Unit)
                                end
                            elseif k == "Origin" then
                                return CFrame.new(cp, tp)
                            elseif k == "Direction" then
                                local diff = tp - cp
                                if diff.Magnitude > 0.01 then
                                    return diff.Unit
                                end
                            end
                        end
                    end
                    return oldIndex(t, k)
                end)
                pcall(setreadonly, rawMt, true)
            end
        end
    end

    -- Hook 2: ReplicatedStorage.Mouse module (Blox Fruits skill targeting)
    local function hookMouseModule()
        local mouseModInstance = ReplicatedStorage:FindFirstChild("Mouse")
        if not mouseModInstance then
            pcall(function() mouseModInstance = ReplicatedStorage:WaitForChild("Mouse", 2) end)
        end
        if mouseModInstance then
            local ok, mouseMod = pcall(require, mouseModInstance)
            if ok and typeof(mouseMod) == "table" then
                local realStore = { Hit = rawget(mouseMod, "Hit"), Target = rawget(mouseMod, "Target") }
                local mmt = getrawmetatable(mouseMod) or {}
                pcall(setreadonly, mmt, false)
                rawset(mouseMod, "Hit", nil)
                rawset(mouseMod, "Target", nil)
                mmt.__index = function(self, key)
                    local target = Core.CurrentTargetPart or _G.currentSilentAimTarget or _G.DarlingSilentAimTarget
                    if (Core.PlayerAimEnabled or Core.NPCAimEnabled or _G.G_SilentAimSkill) and target then
                        local activeKey = Core.CurrentSkillKey
                        if activeKey and Core.isKeyBlacklisted(Core.CurrentToolCategory, activeKey) then
                            return realStore[key] or rawget(self, key)
                        end
                        local isSword = (Core.CurrentToolCategory == "Sword") or (Core.CurrentTool and (string.find(Core.CurrentTool.Name, "Sword") or string.find(Core.CurrentTool.Name, "Buddy")))
                        local tp = (isSword and Core.CurrentTargetRawPosition) or (target and target.Position) or Core.CurrentTargetPosition or Core.CurrentTargetRawPosition
                        if tp then
                            if key == "Hit" then return CFrame.new(tp) end
                            if key == "Target" then return target end
                        end
                    end
                    return realStore[key] or rawget(self, key)
                end
                mmt.__newindex = function(self, key, value)
                    if key == "Hit" or key == "Target" then
                        realStore[key] = value
                    else
                        rawset(self, key, value)
                    end
                end
                setmetatable(mouseMod, mmt)
                pcall(setreadonly, mmt, true)
            end
        end
    end
    hookMouseModule()
    task.spawn(function()
        task.wait(1)
        hookMouseModule()
    end)

    -- Hook 3: Remote interception (__namecall for FireServer & InvokeServer)
    local okNamecall = false
    if hookmetamethod then
        local ok, _ = pcall(function()
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
                local method = getnamecallmethod()
                local args = { ... }

                if args[1] == "TAP" then
                    return oldNamecall(self, ...)
                end

                local skillKey = getSkillKeyFromArgs(args)
                if skillKey then
                    Core.setCurrentSkillKey(skillKey)
                end

                local activeKey = skillKey or Core.CurrentSkillKey
                local isBlacklisted = false
                if activeKey and Core.isKeyBlacklisted(Core.CurrentToolCategory, activeKey) then
                    isBlacklisted = true
                end

                if not isBlacklisted and (Core.LockPlayer or Core.PlayerAimEnabled or Core.NPCAimEnabled) and Core.CurrentTargetPart then
                    local isSword = (Core.CurrentToolCategory == "Sword") or (Core.CurrentTool and (string.find(Core.CurrentTool.Name, "Sword") or string.find(Core.CurrentTool.Name, "Buddy")))
                    local targetPos = (isSword and Core.CurrentTargetRawPosition) or Core.CurrentTargetPosition or Core.CurrentTargetRawPosition
                    if targetPos then
                        if method == "FireServer" or method == "InvokeServer" then
                            local sName = tostring(self)
                            if sName == "RemoteEvent" or sName == "CommE" or sName == "RemoteFunction" or sName == "CommF_" then
                                for i, v in ipairs(args) do
                                    if typeof(v) == "Vector3" then
                                        args[i] = targetPos
                                    end
                                end

                                -- sword invokeserver redirection
                                if method == "InvokeServer" and (type(args[1]) == "string" and table.find(SKILL_KEYS, args[1])) then
                                    args[2] = targetPos
                                end
                            end
                        end
                    end
                end

                return oldNamecall(self, unpack(args))
            end))
            okNamecall = true
        end)
    end

    if not okNamecall then
        local rawMt = getrawmetatable(game)
        if rawMt then
            local oldNamecall = rawMt.__namecall
            pcall(setreadonly, rawMt, false)

            rawMt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                local args = { ... }

                if args[1] == "TAP" then
                    return oldNamecall(self, ...)
                end

                local skillKey = getSkillKeyFromArgs(args)
                if skillKey then
                    Core.setCurrentSkillKey(skillKey)
                end

                local activeKey = skillKey or Core.CurrentSkillKey
                local isBlacklisted = false
                if activeKey and Core.isKeyBlacklisted(Core.CurrentToolCategory, activeKey) then
                    isBlacklisted = true
                end

                if not isBlacklisted and (Core.LockPlayer or Core.PlayerAimEnabled or Core.NPCAimEnabled) and Core.CurrentTargetPart then
                    local isSword = (Core.CurrentToolCategory == "Sword") or (Core.CurrentTool and (string.find(Core.CurrentTool.Name, "Sword") or string.find(Core.CurrentTool.Name, "Buddy")))
                    local targetPos = (isSword and Core.CurrentTargetRawPosition) or Core.CurrentTargetPosition or Core.CurrentTargetRawPosition
                    if targetPos then
                        if method == "FireServer" or method == "InvokeServer" then
                            local sName = tostring(self)
                            if sName == "RemoteEvent" or sName == "CommE" or sName == "RemoteFunction" or sName == "CommF_" then
                                for i, v in ipairs(args) do
                                    if typeof(v) == "Vector3" then
                                        args[i] = targetPos
                                    end
                                end

                                -- sword invokeserver redirection
                                if method == "InvokeServer" and (type(args[1]) == "string" and table.find(SKILL_KEYS, args[1])) then
                                    args[2] = targetPos
                                end
                            end
                        end
                    end
                end

                return oldNamecall(self, unpack(args))
            end)

            pcall(setreadonly, rawMt, true)
        end
    end
end

-- ============================================================================
-- RENDER LOOP (TARGET UPDATES - OPTIMIZED FOR 60-144 FPS)
-- ============================================================================
local lastTargetScanTick = 0
local TARGET_SCAN_INTERVAL = 0.08 -- 12.5 Hz entity re-scan interval

local function isCurrentTargetValid(targetPart, targetChar, lpHRP, maxRange)
    if not targetPart or not targetPart.Parent or not targetChar or not targetChar.Parent then
        return false
    end
    local hum = targetChar:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        return false
    end
    local dist = (targetPart.Position - lpHRP.Position).Magnitude
    if dist > (maxRange + 50) then
        return false
    end
    return true
end

local function updateTargetCycle()
    pcall(function()
        Camera = Workspace.CurrentCamera or Camera
    local char = LocalPlayer and LocalPlayer.Character
    local lpHRP = char and getHRP(char)

    if not lpHRP or (not Core.LockPlayer and not Core.PlayerAimEnabled and not Core.NPCAimEnabled) then
        Core.CurrentTargetPart = nil
        Core.CurrentTargetRawPosition = nil
        Core.CurrentTargetPosition = nil
        Core.CurrentTargetCharacter = nil
        return
    end

    local hubSettings = (_G.DarlingHub and _G.DarlingHub.Settings and _G.DarlingHub.Settings.Aim) or Core
    local maxRange = hubSettings.MaxRange or Core.MaxRange or 1000
    local now = os.clock()

    -- 0. Lock Player & Real-time CamLock Mode
    if Core.LockPlayer then
        if not Core.LockedTargetPlayer or not isAlive(Core.LockedTargetPlayer.Character) then
            local myPos = lpHRP.Position
            local closestPlayer = nil
            local closestDist = maxRange
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and isEnemy(p) and not Core.isPlayerBlacklisted(p) and p.Character and isAlive(p.Character) then
                    local pHRP = getHRP(p.Character)
                    if pHRP then
                        local d = (pHRP.Position - myPos).Magnitude
                        if d < closestDist then
                            closestDist = d
                            closestPlayer = p
                        end
                    end
                end
            end
            if closestPlayer then
                Core.LockedTargetPlayer = closestPlayer
                pcall(function()
                    local fw = _G.DarlingHub and _G.DarlingHub.Require and _G.DarlingHub:Require("modules/pvp/floating_widget.lua")
                    local widget = fw and fw.GetWidget and fw.GetWidget("LockPlayerFloatingPill")
                    if widget and Core.LockedTargetPlayer then
                        widget:SetLabel("LOCK: " .. tostring(Core.LockedTargetPlayer.DisplayName or Core.LockedTargetPlayer.Name))
                    end
                end)
            end
        end

        if Core.LockedTargetPlayer and isAlive(Core.LockedTargetPlayer.Character) then
            local tPart = getEntityPart(Core.LockedTargetPlayer.Character)
            if tPart then
                Core.CurrentTargetPart = tPart
                Core.CurrentTargetRawPosition = tPart.Position
                Core.CurrentTargetPosition = Core.predictPosition(tPart)
                Core.CurrentTargetCharacter = Core.LockedTargetPlayer.Character
                Core.CurrentTargetIsPlayer = true
                _G.DarlingSilentAimTarget = tPart
                _G.currentSilentAimTarget = tPart

                -- Real-time CamLock directly tracking target part (NaN safe)
                if Workspace.CurrentCamera and tPart and tPart.Parent then
                    local cam = Workspace.CurrentCamera
                    local camPos = cam.CFrame.Position
                    local aimPos = tPart.Position + Vector3.new(0, 1.5, 0)
                    local diff = aimPos - camPos
                    if diff.Magnitude > 0.5 and (aimPos.X == aimPos.X) and (camPos.X == camPos.X) then
                        pcall(function()
                            cam.CFrame = CFrame.lookAt(camPos, aimPos)
                        end)
                    end
                end
                return
            end
        else
            Core.LockedTargetPlayer = nil
        end
    end

    -- 1. Fast path: if current target is still valid and within interval, update lead prediction directly at native FPS
    if Core.CurrentTargetPart and isCurrentTargetValid(Core.CurrentTargetPart, Core.CurrentTargetCharacter, lpHRP, maxRange) then
        if not (Core.PlayerAimEnabled and not Core.CurrentTargetIsPlayer) then
            if (now - lastTargetScanTick) < TARGET_SCAN_INTERVAL then
                Core.CurrentTargetRawPosition = Core.CurrentTargetPart.Position
                Core.CurrentTargetPosition = Core.predictPosition(Core.CurrentTargetPart)
                return
            end
        end
    end

    -- 2. Scan path: periodically or when target is invalid/lost, find the optimal target
    lastTargetScanTick = now
    local targetPart, predictedPos, targetChar = nil, nil, nil

    if Core.PlayerAimEnabled then
        targetPart, predictedPos, targetChar = resolvePlayerTarget(lpHRP)
        if targetPart then Core.CurrentTargetIsPlayer = true end
    end

    if not targetPart and Core.NPCAimEnabled then
        targetPart, predictedPos, targetChar = resolveNPCTarget(lpHRP)
        if targetPart then Core.CurrentTargetIsPlayer = false end
    end

    Core.CurrentTargetPart = targetPart
    Core.CurrentTargetRawPosition = targetPart and targetPart.Position or nil
    Core.CurrentTargetPosition = predictedPos
    Core.CurrentTargetCharacter = targetChar
    _G.DarlingSilentAimTarget = targetPart
    _G.currentSilentAimTarget = targetPart
    end)
end

function Core.startLoop()
    if Core.RenderConnection then return end
    Core.installHooks()
    lastTargetScanTick = 0
    Core.RenderConnection = RunService.RenderStepped:Connect(updateTargetCycle)
end

function Core.stopLoop()
    if Core.PlayerAimEnabled or Core.NPCAimEnabled or Core.LockPlayer then return end
    if Core.RenderConnection then
        Core.RenderConnection:Disconnect()
        Core.RenderConnection = nil
    end
    lastTargetScanTick = 0
    Core.CurrentTargetPart = nil
    Core.CurrentTargetRawPosition = nil
    Core.CurrentTargetPosition = nil
    Core.CurrentTargetCharacter = nil
end

-- ============================================================================
-- INPUT AND CHARACTER HOOKS
-- ============================================================================
local function setupCharacter(char)
    for _, c in ipairs(Core.CharConnections) do pcall(function() c:Disconnect() end) end
    Core.CharConnections = {}

    local function checkTool(child)
        if child:IsA("Tool") then
            Core.CurrentTool = child
            Core.CurrentToolCategory = Core.getToolCategory(child)
            Core.CurrentSkillKey = nil
            table.insert(Core.CharConnections, child.AncestryChanged:Connect(function(_, parent)
                if not parent then Core.CurrentTool = nil end
            end))
        end
    end

    for _, child in ipairs(char:GetChildren()) do checkTool(child) end
    table.insert(Core.CharConnections, char.ChildAdded:Connect(checkTool))
    table.insert(Core.CharConnections, char.ChildRemoved:Connect(function(child)
        if child == Core.CurrentTool then Core.CurrentTool = nil end
    end))
end

if LocalPlayer then
    if LocalPlayer.CharacterAdded then
        LocalPlayer.CharacterAdded:Connect(setupCharacter)
    end
    if LocalPlayer.Character then setupCharacter(LocalPlayer.Character) end
end

if UserInputService and UserInputService.InputBegan then
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        local keyMap = {
            [Enum.KeyCode.Z] = "Z",
            [Enum.KeyCode.X] = "X",
            [Enum.KeyCode.C] = "C",
            [Enum.KeyCode.V] = "V",
            [Enum.KeyCode.F] = "F",
        }
        if input and input.KeyCode then
            local mapped = keyMap[input.KeyCode]
            if mapped then Core.setCurrentSkillKey(mapped) end
        end
    end)
end

-- Mobile buttons hook
task.spawn(function()
    while not LocalPlayer or not LocalPlayer:FindFirstChild("PlayerGui") do task.wait(0.5) end
    local pGui = LocalPlayer.PlayerGui
    local main = pGui:WaitForChild("Main", 10)
    if main then
        local skills = main:WaitForChild("Skills", 10)
        if skills then
            local function hookBtn(b)
                if (b:IsA("ImageButton") or b:IsA("TextButton")) and table.find(SKILL_KEYS, b.Name) then
                    b.Activated:Connect(function() Core.setCurrentSkillKey(b.Name) end)
                end
            end
            for _, wf in ipairs(skills:GetChildren()) do
                if wf:IsA("GuiObject") then
                    for _, b in ipairs(wf:GetChildren()) do hookBtn(b) end
                end
            end
        end
    end
end)

function Core.setLockPlayer(state)
    Core.LockPlayer = (state == true)
    if state then
        local lp = Players.LocalPlayer
        local char = lp and lp.Character
        local lpHRP = char and char:FindFirstChild("HumanoidRootPart")
        if lpHRP then
            local myPos = lpHRP.Position
            local closestPlayer = nil
            local closestDist = 2000
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= lp and isEnemy(p) and not Core.isPlayerBlacklisted(p) and p.Character and isAlive(p.Character) then
                    local pHRP = getHRP(p.Character)
                    if pHRP then
                        local d = (pHRP.Position - myPos).Magnitude
                        if d < closestDist then
                            closestDist = d
                            closestPlayer = p
                        end
                    end
                end
            end
            Core.LockedTargetPlayer = closestPlayer
        end
        Core.startLoop()
    else
        Core.LockedTargetPlayer = nil
        if not Core.PlayerAimEnabled and not Core.NPCAimEnabled then
            Core.stopLoop()
        end
    end

    pcall(function()
        local fw = _G.DarlingHub and _G.DarlingHub.Require and _G.DarlingHub:Require("modules/pvp/floating_widget.lua")
        local widget = fw and fw.GetWidget and fw.GetWidget("LockPlayerFloatingPill")
        if widget then
            if state and Core.LockedTargetPlayer then
                widget:SetLabel("LOCK: " .. tostring(Core.LockedTargetPlayer.DisplayName or Core.LockedTargetPlayer.Name))
            else
                widget:SetLabel("LOCK")
            end
        end
    end)
end

function Core.toggleLockPlayer()
    return Core.setLockPlayer(not Core.LockPlayer)
end

-- Global exposure across both _G and getgenv()
_G.DarlingCombatCore = Core
if getgenv then pcall(function() getgenv().DarlingCombatCore = Core end) end

-- Install hooks synchronously
pcall(function() Core.installHooks() end)

return Core
