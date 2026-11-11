--[[
    Vinser Hub - Godhuman Z Glitch & Supersonic Momentum Engine (Enhanced Edition)
    Replicates the exact Blox Fruits Godhuman Z ("Soaring Beast") speed, glide, and aimlock:
      1. Equips Godhuman (Fighting Style)
      2. Initiates Godhuman Z with optimal windup
      3. Aimlock Snap: Locks camera directly onto enemy HumanoidRootPart (with Ally filter)
      4. Instantly swaps to Fruit / Sword to cancel the move's end-lag and grab lock
      5. Catapults the player at supersonic speed with targeted momentum
      6. Auto-releases aimlock the instant hit damage registers via DmgCounter
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
    AimlockEnabled = true,     -- Snaps camera and trajectory toward nearest enemy
    AimlockMaxDist = 1000,     -- Maximum target lock search distance
    TargetInfo = false,        -- Displays on-screen Target HP HUD
    Keybind = Enum.KeyCode.Z,
    IsExecuting = false,
    
    -- Internal state
    GodhumanZActive = false,
    AimlockActive = false,
    NearestTarget = nil,
    AimRenderConn = nil,
    AimTimeoutTask = nil,
    DmgConn = nil,
    UiConn = nil,
}

local function getCharacter()
    local char = LocalPlayer and LocalPlayer.Character
    if not char then return nil, nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
    local hum = char:FindFirstChildOfClass("Humanoid")
    return char, hrp, hum
end

-- ========= SMART ALLY & ENEMY CHECKER (Banana Cat Method) =========
local function isAllyWithMe(targetPlayer)
    if not targetPlayer then return false end
    local myGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not myGui then return false end

    local scrolling = myGui:FindFirstChild("Main")
        and myGui.Main:FindFirstChild("Allies")
        and myGui.Main.Allies:FindFirstChild("Container")
        and myGui.Main.Allies.Container:FindFirstChild("Allies")
        and myGui.Main.Allies.Container.Allies:FindFirstChild("ScrollingFrame")

    if scrolling then
        for _, frame in pairs(scrolling:GetDescendants()) do
            if frame:IsA("ImageButton") and frame.Name == targetPlayer.Name then
                return true
            end
        end
    end

    return false
end

local function isEnemy(targetPlayer)
    if not targetPlayer or targetPlayer == LocalPlayer then
        return false
    end

    local myTeam = LocalPlayer.Team
    local targetTeam = targetPlayer.Team

    if myTeam and targetTeam then
        if myTeam.Name == "Pirates" and targetTeam.Name == "Marines" then
            return true
        elseif myTeam.Name == "Marines" and targetTeam.Name == "Pirates" then
            return true
        end

        if myTeam.Name == "Pirates" and targetTeam.Name == "Pirates" then
            if isAllyWithMe(targetPlayer) then
                return false
            end
            return true
        end

        if myTeam.Name == "Marines" and targetTeam.Name == "Marines" then
            return false
        end
    end

    return true
end

local function getNearestTarget(maxDistance)
    local char, hrp, hum = getCharacter()
    if not hrp then return nil end

    local maxD = tonumber(maxDistance) or GodhumanZ.AimlockMaxDist or 1000
    local closest, closestDist = nil, maxD

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isEnemy(plr) and plr.Character then
            local eHrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local eHum = plr.Character:FindFirstChildOfClass("Humanoid")
            if eHrp and eHum and eHum.Health > 0 then
                -- Check safe zone
                local safeZone = plr.Character:FindFirstChild("SafeZone") or plr.Character:GetAttribute("SafeZone")
                if not safeZone then
                    local dist = (eHrp.Position - hrp.Position).Magnitude
                    if dist < closestDist then
                        closest = plr.Character
                        closestDist = dist
                    end
                end
            end
        end
    end

    return closest
end

-- ========= DAMAGE COUNTER HIT-DETECTOR =========
local function stopAimlock(reason)
    if not GodhumanZ.AimlockActive then return end
    GodhumanZ.AimlockActive = false
    GodhumanZ.NearestTarget = nil
    GodhumanZ.GodhumanZActive = false

    if GodhumanZ.AimRenderConn then
        pcall(function() GodhumanZ.AimRenderConn:Disconnect() end)
        GodhumanZ.AimRenderConn = nil
    end

    if GodhumanZ.AimTimeoutTask then
        pcall(function() task.cancel(GodhumanZ.AimTimeoutTask) end)
        GodhumanZ.AimTimeoutTask = nil
    end
end

local function watchDamageCounter()
    if GodhumanZ.DmgConn then
        pcall(function() GodhumanZ.DmgConn:Disconnect() end)
        GodhumanZ.DmgConn = nil
    end

    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local main = pg and pg:FindFirstChild("Main")
    if not main then return end

    local dmgCounter = main:FindFirstChild("DmgCounter")
    if not dmgCounter then
        local conn
        conn = main.ChildAdded:Connect(function(child)
            if child.Name == "DmgCounter" then
                conn:Disconnect()
                watchDamageCounter()
            end
        end)
        return
    end

    local dmgTextLabel = dmgCounter:FindFirstChild("Text")
    if not dmgTextLabel then
        local conn2
        conn2 = dmgCounter.ChildAdded:Connect(function(child)
            if child.Name == "Text" then
                conn2:Disconnect()
                watchDamageCounter()
            end
        end)
        return
    end

    GodhumanZ.DmgConn = dmgTextLabel:GetPropertyChangedSignal("Text"):Connect(function()
        local dmgText = tonumber(dmgTextLabel.Text) or 0
        if dmgText > 0 and GodhumanZ.AimlockActive then
            stopAimlock("Damage registered on target")
        end
    end)
end

local function startAimlock(target)
    if not GodhumanZ.AimlockEnabled then return end
    if GodhumanZ.AimlockActive then return end

    local targetChar = target or getNearestTarget(GodhumanZ.AimlockMaxDist)
    if not targetChar or not targetChar:FindFirstChild("HumanoidRootPart") then return end

    GodhumanZ.NearestTarget = targetChar
    GodhumanZ.AimlockActive = true

    GodhumanZ.AimRenderConn = RunService.RenderStepped:Connect(function()
        if not GodhumanZ.AimlockActive or not GodhumanZ.NearestTarget then
            stopAimlock("Aimlock ended")
            return
        end

        local tHrp = GodhumanZ.NearestTarget:FindFirstChild("HumanoidRootPart")
        local tHum = GodhumanZ.NearestTarget:FindFirstChildOfClass("Humanoid")
        if not tHrp or not tHum or tHum.Health <= 0 then
            stopAimlock("Target lost or died")
            return
        end

        local cam = Workspace.CurrentCamera
        if cam then
            cam.CFrame = CFrame.lookAt(cam.CFrame.Position, tHrp.Position)
        end
    end)

    -- Auto timeout fail-safe
    GodhumanZ.AimTimeoutTask = task.delay(1.5, function()
        if GodhumanZ.AimlockActive then
            stopAimlock("Timeout reached")
        end
    end)

    watchDamageCounter()
end

-- ========= TARGET HP HUD =========
local targetGui = nil
local targetFrame = nil
local targetName = nil
local hpFill = nil

local function createTargetHUD()
    if targetGui then return end
    local parent = nil
    pcall(function()
        local gethui = (type(gethui) == "function" and gethui) or (getgenv and getgenv().gethui)
        parent = (gethui and gethui()) or LocalPlayer:FindFirstChildOfClass("PlayerGui")
    end)
    if not parent then return end

    targetGui = Instance.new("ScreenGui")
    targetGui.Name = "VinserTargetHUD"
    targetGui.ResetOnSpawn = false
    targetGui.DisplayOrder = 9999
    targetGui.Parent = parent

    targetFrame = Instance.new("Frame")
    targetFrame.Name = "TargetFrame"
    targetFrame.Size = UDim2.new(0, 260, 0, 48)
    targetFrame.Position = UDim2.new(0.5, -130, 0.08, 0)
    targetFrame.BackgroundColor3 = Color3.fromRGB(15, 12, 22)
    targetFrame.BackgroundTransparency = 0.25
    targetFrame.Visible = false
    targetFrame.Parent = targetGui

    local corner = Instance.new("UICorner", targetFrame)
    corner.CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", targetFrame)
    stroke.Color = Color3.fromRGB(168, 85, 247)
    stroke.Thickness = 1.2
    stroke.Transparency = 0.3

    targetName = Instance.new("TextLabel")
    targetName.Name = "TargetName"
    targetName.Size = UDim2.new(1, -16, 0, 20)
    targetName.Position = UDim2.new(0, 8, 0, 4)
    targetName.BackgroundTransparency = 1
    targetName.Font = Enum.Font.GothamBold
    targetName.TextSize = 13
    targetName.TextColor3 = Color3.fromRGB(240, 240, 240)
    targetName.TextXAlignment = Enum.TextXAlignment.Left
    targetName.Text = "Target"
    targetName.Parent = targetFrame

    local hpBg = Instance.new("Frame", targetFrame)
    hpBg.Size = UDim2.new(1, -16, 0, 12)
    hpBg.Position = UDim2.new(0, 8, 0, 28)
    hpBg.BackgroundColor3 = Color3.fromRGB(35, 30, 45)
    hpBg.BorderSizePixel = 0
    Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 6)

    hpFill = Instance.new("Frame", hpBg)
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
    hpFill.BorderSizePixel = 0
    Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 6)
end

function GodhumanZ.SetTargetInfo(state)
    GodhumanZ.TargetInfo = (state == true)
    if GodhumanZ.TargetInfo then
        createTargetHUD()
        if not GodhumanZ.UiConn then
            GodhumanZ.UiConn = RunService.RenderStepped:Connect(function()
                if not GodhumanZ.TargetInfo or not targetFrame then return end
                local t = GodhumanZ.NearestTarget or getNearestTarget(GodhumanZ.AimlockMaxDist)
                if t and t:FindFirstChild("Humanoid") then
                    local hum = t.Humanoid
                    targetName.Text = t.Name .. " (" .. math.floor(hum.Health) .. " / " .. math.floor(hum.MaxHealth) .. ")"
                    local ratio = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
                    hpFill.Size = UDim2.new(ratio, 0, 1, 0)
                    targetFrame.Visible = true
                else
                    targetFrame.Visible = false
                end
            end)
        end
    else
        if GodhumanZ.UiConn then
            pcall(function() GodhumanZ.UiConn:Disconnect() end)
            GodhumanZ.UiConn = nil
        end
        if targetFrame then targetFrame.Visible = false end
    end
end

-- ========= TOOL FINDERS =========
local function findToolByPattern(pattern)
    local char = LocalPlayer and LocalPlayer.Character
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

    if backpack then
        for _, t in ipairs(backpack:GetChildren()) do
            if t:IsA("Tool") and not isGodhuman(t) then
                return t
            end
        end
    end

    return nil
end

-- ========= SUPERSONIC LAUNCH VECTOR IMPULSE =========
local function launchGlitchMomentum(power, duration, usePitch, targetHrp)
    local char, hrp, hum = getCharacter()
    if not hrp then return end

    local cam = Workspace.CurrentCamera
    local dir = cam and cam.CFrame.LookVector or hrp.CFrame.LookVector

    if targetHrp and targetHrp.Parent then
        -- Track straight toward target position
        local toTarget = (targetHrp.Position - hrp.Position).Unit
        dir = toTarget
    elseif usePitch then
        local flat = Vector3.new(dir.X, 0, dir.Z).Unit
        dir = (flat * 0.82 + Vector3.new(0, 0.57, 0)).Unit
    end

    local att = Instance.new("Attachment")
    att.Name = "VinserGodhumanZAttachment"
    att:SetAttribute("VinserPhysics", true)
    att.Parent = hrp

    local lv = Instance.new("LinearVelocity")
    lv.Name = "VinserGodhumanZVelocity"
    lv:SetAttribute("VinserPhysics", true)
    lv.MaxForce = 1e9
    lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    lv.VectorVelocity = dir * power
    lv.Attachment0 = att
    lv.Parent = hrp

    _G.Vinser_GodhumanBoosting = true
    _G.Vinser_Boosting = true

    hrp.AssemblyLinearVelocity = dir * (power * 0.9)

    local flightConn = nil
    local startTime = os.clock()
    flightConn = RunService.Heartbeat:Connect(function()
        if os.clock() - startTime > duration or not lv.Parent then
            if flightConn then flightConn:Disconnect(); flightConn = nil end
            return
        end
        if hrp.Position.Y < 15 then
            hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 35, hrp.AssemblyLinearVelocity.Z)
        end
    end)

    task.delay(duration, function()
        pcall(function()
            if flightConn then flightConn:Disconnect(); flightConn = nil end
            if lv and lv.Parent then lv:Destroy() end
            if att and att.Parent then att:Destroy() end
            _G.Vinser_GodhumanBoosting = false
            _G.Vinser_Boosting = false
        end)
    end)
end

-- ========= EXECUTE THE GLITCH SEQUENCE =========
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

        -- 1. Equip Godhuman if not equipped
        if godhuman and godhuman.Parent ~= char then
            pcall(function() hum:EquipTool(godhuman) end)
            local eqDeadline = os.clock() + 0.35
            while godhuman.Parent ~= char and os.clock() < eqDeadline do
                task.wait(0.02)
            end
        end

        -- 2. Target acquisition & Aimlock snap
        local target = nil
        if GodhumanZ.AimlockEnabled then
            target = getNearestTarget(GodhumanZ.AimlockMaxDist)
            if target then
                startAimlock(target)
                task.wait(0.03) -- micro-pause for camera alignment
            end
        end

        -- 3. Trigger Godhuman Z input
        if VirtualInputManager then
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Z, false, game)
            end)
        end

        -- Wind-up charge frame window (~0.14 - 0.16s)
        task.wait(0.14)

        if VirtualInputManager then
            pcall(function()
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Z, false, game)
            end)
        end

        -- 4. Swap weapon to cancel move recovery and break animation drag
        if cancelTool then
            pcall(function()
                hum:EquipTool(cancelTool)
            end)
        end

        -- 5. Catapult momentum impulse
        local targetHrp = target and target:FindFirstChild("HumanoidRootPart")
        launchGlitchMomentum(GodhumanZ.Power, GodhumanZ.Duration, GodhumanZ.AutoSkyPitch, targetHrp)

        -- 6. Optional re-equip Godhuman after glide
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
    if not GodhumanZ.Enabled then
        stopAimlock("Disabled")
    end
end

function GodhumanZ.SetAimlock(state)
    GodhumanZ.AimlockEnabled = (state == true)
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
    elseif type(key) == "string" then
        if Enum.KeyCode[key] then
            GodhumanZ.Keybind = Enum.KeyCode[key]
        else
            GodhumanZ.Keybind = key
        end
    end
end

-- Direct Keybind listener (Ignores gameProcessed so keys like E, R, Q work reliably in Blox Fruits)
UserInputService.InputBegan:Connect(function(input, gpe)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if UserInputService:GetFocusedTextBox() then return end
    if not GodhumanZ.Enabled then return end

    local targetKey = GodhumanZ.Keybind
    local match = false

    if typeof(targetKey) == "EnumItem" then
        match = (input.KeyCode == targetKey)
    elseif type(targetKey) == "string" then
        match = (input.KeyCode.Name == targetKey)
    end

    if match then
        GodhumanZ.Trigger()
    end
end)

-- Mobile touch release support (Banana Cat style)
UserInputService.TouchEnded:Connect(function(touch)
    if not GodhumanZ.Enabled or not GodhumanZ.AimlockEnabled then return end
    local cam = Workspace.CurrentCamera
    if not cam or not touch or not touch.Position then return end

    if touch.Position.X > cam.ViewportSize.X / 2 then
        local char = LocalPlayer.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool and string.find(string.lower(tool.Name), "godhuman") then
            if not GodhumanZ.AimlockActive then
                startAimlock()
            end
        end
    end
end)

-- Namecall hook to auto-detect natural in-game Godhuman Z skill casts
pcall(function()
    if hookmetamethod and not getgenv().Vinser_ZSkillHooked then
        getgenv().Vinser_ZSkillHooked = true
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            if (method == "InvokeServer" or method == "FireServer") then
                local a1 = args[1]
                if typeof(a1) == "string" and a1:upper() == "Z" then
                    local char = LocalPlayer.Character
                    local tool = char and char:FindFirstChildOfClass("Tool")
                    if tool and string.find(string.lower(tool.Name), "godhuman") then
                        GodhumanZ.GodhumanZActive = true
                        if GodhumanZ.Enabled and GodhumanZ.AimlockEnabled and not GodhumanZ.AimlockActive then
                            startAimlock()
                        end
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    stopAimlock("Character respawn")
    watchDamageCounter()
end)

if LocalPlayer.Character then
    watchDamageCounter()
end

_G.VinsersHub_GodhumanZMod = GodhumanZ
_G.DarlingX_GodhumanZMod = GodhumanZ

return GodhumanZ
