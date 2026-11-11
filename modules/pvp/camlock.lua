--[[
    Darling X - Camlock Module (Classic v2.5 / v2.6 Inspired Engine)
    Clean, deterministic, user-controlled camera locking:
    - Starts in OFF state when enabled in UI (LOCK: OFF).
    - When turned ON (via widget or keybind C), locks onto the enemy currently in crosshairs/front.
    - Stays locked onto that exact person until explicitly turned OFF.
    - When turned OFF, camera returns to 100% normal immediately and stays normal.
    - If the target dies, leaves, or moves >800 studs, it turns OFF cleanly without jumping.
    - Zero emojis, zero third-party references.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Camlock = {
    Enabled = false,
    Active = false,
    Keybind = "C",
    CameraFOV = 70,
    Smoothness = 1,
    MaxDistance = 800,
    Target = nil,
    RenderConn = nil,
    InputConn = nil,
}

local function isEnemy(player)
    if not player or player == LocalPlayer then return false end
    local myChar = LocalPlayer.Character
    if not myChar then return false end

    local myTeam = LocalPlayer.Team
    local theirTeam = player.Team
    if myTeam and theirTeam and myTeam == theirTeam and myTeam.Name == "Marines" then
        return false
    end
    return true
end

local function isAlive(char)
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

-- Find the target enemy: crosshair priority first, then closest in world (v2.5/2.6 standard)
local function findTarget()
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil, nil end

    local cam = Workspace.CurrentCamera or Camera
    local maxDist = Camlock.MaxDistance or 800
    local bestPlayer = nil
    local bestPart = nil
    local shortestScreenDist = math.huge

    local vpX = (cam and cam.ViewportSize and cam.ViewportSize.X) or 1920
    local vpY = (cam and cam.ViewportSize and cam.ViewportSize.Y) or 1080
    local centerX = vpX / 2
    local centerY = vpY / 2

    -- Pass 1: Enemy on screen closest to crosshair / center
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isEnemy(p) and isAlive(p.Character) then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart") or p.Character:FindFirstChild("Head")
            if hrp then
                local worldDist = (hrp.Position - myHRP.Position).Magnitude
                if worldDist <= maxDist then
                    local onScreen = true
                    local screenDist = worldDist

                    if cam and cam.WorldToViewportPoint then
                        local ok, sp, vis = pcall(function() return cam:WorldToViewportPoint(hrp.Position) end)
                        if ok and sp then
                            onScreen = (vis == true) or (sp.Z and sp.Z > 0)
                            if onScreen and sp.X and sp.Y then
                                local dx = sp.X - centerX
                                local dy = sp.Y - centerY
                                screenDist = math.sqrt(dx * dx + dy * dy)
                            end
                        end
                    end

                    if onScreen and screenDist < shortestScreenDist then
                        shortestScreenDist = screenDist
                        bestPlayer = p
                        bestPart = hrp
                    end
                end
            end
        end
    end

    if bestPlayer and bestPart then
        return bestPlayer, bestPart
    end

    -- No enemy on screen in front of player: do NOT lock onto anyone in world
    return nil, nil
end

-- Stop locking: disconnects loop, frees camera completely to 100% normal
function Camlock.Unlock()
    if Camlock.RenderConn then
        pcall(function() Camlock.RenderConn:Disconnect() end)
        Camlock.RenderConn = nil
    end

    Camlock.Active = false
    Camlock.Target = nil
    _G.DarlingX_Camlock = false
    _G.DarlingX_CamlockTargetName = nil

    local ew = _G.DarlingX_ExtraWidgets
    if ew and ew.UpdateCamlockVisual then
        pcall(ew.UpdateCamlockVisual, false)
    end

    pcall(function()
        local cam = Workspace.CurrentCamera or Camera
        if cam and LocalPlayer and LocalPlayer.Character then
            local char = LocalPlayer.Character
            local hum = (char.FindFirstChildOfClass and char:FindFirstChildOfClass("Humanoid")) or (char.FindFirstChild and char:FindFirstChild("Humanoid"))
            if hum and cam.CameraSubject ~= hum then
                cam.CameraSubject = hum
            end
        end
    end)

    return false
end

-- Start locking: locks onto the target under crosshair and tracks them until turned off
function Camlock.Lock(targetPlayer, targetPart)
    if not targetPlayer or not targetPart then
        targetPlayer, targetPart = findTarget()
    end

    if not targetPlayer or not targetPart then
        Camlock.Unlock()
        return false
    end

    Camlock.Target = targetPlayer
    Camlock.Active = true
    _G.DarlingX_Camlock = true
    _G.DarlingX_CamlockTargetName = targetPlayer.DisplayName or targetPlayer.Name

    local ew = _G.DarlingX_ExtraWidgets
    if ew and ew.UpdateCamlockVisual then
        pcall(ew.UpdateCamlockVisual, true)
    end

    if Camlock.RenderConn then
        pcall(function() Camlock.RenderConn:Disconnect() end)
        Camlock.RenderConn = nil
    end

    -- Real-time tracking loop: tracks ONLY this specific target until turned off or target drops
    Camlock.RenderConn = RunService.RenderStepped:Connect(function()
        if not Camlock.Active or not _G.DarlingX_Camlock then
            Camlock.Unlock()
            return
        end

        local tPlayer = Camlock.Target
        if not tPlayer or not tPlayer.Character or not isAlive(tPlayer.Character) then
            -- Target died or left: release camera cleanly, DO NOT jump to someone else
            Camlock.Unlock()
            return
        end

        local myChar = LocalPlayer.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local eHRP = tPlayer.Character:FindFirstChild("HumanoidRootPart") or tPlayer.Character:FindFirstChild("Head")

        if not myHRP or not eHRP then
            Camlock.Unlock()
            return
        end

        local dist = (eHRP.Position - myHRP.Position).Magnitude
        if dist > Camlock.MaxDistance then
            -- Out of range: release camera cleanly
            Camlock.Unlock()
            return
        end

        local cam = Workspace.CurrentCamera or Camera
        if cam and eHRP.Position then
            local camPos = cam.CFrame.Position
            local aimPos = eHRP.Position + Vector3.new(0, 1.5, 0)
            if (camPos.X == camPos.X) and (aimPos.X == aimPos.X) and (aimPos - camPos).Magnitude > 0.5 then
                pcall(function()
                    if Camlock.Smoothness and Camlock.Smoothness < 1 and Camlock.Smoothness > 0 then
                        cam.CFrame = cam.CFrame:Lerp(CFrame.new(camPos, aimPos), Camlock.Smoothness)
                    else
                        cam.CFrame = CFrame.new(camPos, aimPos)
                    end
                end)
            end
        end
    end)

    return true
end

-- Toggle function: flips cleanly between Lock and Unlock
function Camlock.Toggle()
    if Camlock.Active or _G.DarlingX_Camlock then
        return Camlock.Unlock()
    else
        return Camlock.Lock()
    end
end

-- Master enable: shows widget, but starts with camera lock in OFF state
function Camlock.SetEnabled(state)
    Camlock.Enabled = (state == true)
    _G.DarlingX_CamlockEnabled = Camlock.Enabled

    local ew = _G.DarlingX_ExtraWidgets
    if ew and ew.SetCamlockWidgetVisible then
        pcall(ew.SetCamlockWidgetVisible, Camlock.Enabled)
    end

    -- Always unlock camera when master toggle changes
    Camlock.Unlock()

    if _G.DarlingX_SyncCamlockUI then
        pcall(_G.DarlingX_SyncCamlockUI, Camlock.Enabled)
    end
end

-- Backward-compatibility aliases
function Camlock.SetActive(state)
    if state then
        return Camlock.Lock()
    else
        return Camlock.Unlock()
    end
end

function Camlock.ToggleActive()
    return Camlock.Toggle()
end

function Camlock.StartLoop()
    return Camlock.Lock()
end

function Camlock.StopLoop()
    return Camlock.Unlock()
end

function Camlock.SetKeybind(key)
    Camlock.Keybind = tostring(key or "None")
end

function Camlock.SetCameraFOV(val)
    local num = tonumber(val) or 70
    Camlock.CameraFOV = num
    local cam = Workspace.CurrentCamera or Camera
    if cam then
        cam.FieldOfView = num
    end
end

function Camlock.SetSmoothness(val)
    Camlock.Smoothness = tonumber(val) or 1
end

-- Keybind listener
local function setupInputHook()
    if Camlock.InputConn then return end
    Camlock.InputConn = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local key = input.KeyCode.Name
        if Camlock.Keybind ~= "None" and key == Camlock.Keybind then
            Camlock.Toggle()
        end
    end)
end

setupInputHook()

_G.DarlingX_CamlockMod = Camlock
_G.DarlingX_ToggleCamlock = function() return Camlock.Toggle() end
_G.DarlingX_SetCamlock = function(s) return Camlock.SetActive(s) end

return Camlock
