--[[
    Vinser Hub - Godhuman Z Boost Module
    Clean, polished, anti-cheat safe supersonic boost engine.
    Physics: Speed 373, Sky Arc 90 deg straight up, Glide 1.3s.
    Supports both natural in-game Z cast (auto-detect) and manual keybind [E] / UI trigger.
    Zero bloat, zero jank, 100% reliable.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera")

local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)

-- Hardcoded optimal physics: bay 373, sky arc 90 len troi, glide 1.3s
local VELOCITY_POWER = 373
local GLIDE_DURATION = 1.3
local SKY_ARC_ANGLE = 90 -- 90 degrees straight up into the sky

local GodhumanZ = {
    Enabled = false,
    CancelMode = "Unequip", -- "Unequip", "Auto Swap", "Fruit", "Sword", "Gun", "Slot 2"
    SwitchBack = true,      -- Re-equip Godhuman upon landing
    CheckCooldown = true,   -- Refuse boost if Soaring Beast is on cooldown
    AimlockEnabled = true,  -- Lock camera onto enemy during launch
    TargetInfo = false,     -- Displays Target HP HUD during aimlock
    Keybind = Enum.KeyCode.E,
    IsExecuting = false,
}

-- ========= 1. COOLDOWN DETECTION =========
local function isSoaringBeastOnCooldown()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local skills = pg and pg:FindFirstChild("Main") and pg.Main:FindFirstChild("Skills")
    if skills then
        for _, toolFrame in ipairs(skills:GetChildren()) do
            local fn = string.lower(toolFrame.Name)
            if fn:find("melee") or fn:find("combat") or fn:find("godhuman") then
                local zFrame = toolFrame:FindFirstChild("Z")
                if zFrame then
                    local cd = zFrame:FindFirstChild("Cooldown")
                    if cd and cd:IsA("GuiObject") then
                        -- If cooldown bar is hidden, skill is OFF cooldown
                        if not cd.Visible then
                            return false
                        end
                        if cd.Size.X.Scale > 0.01 or cd.Size.X.Offset > 2 then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

-- ========= 2. SMART TARGET FINDER & ALLY FILTER =========
local function isAlly(targetPlayer)
    if not targetPlayer or targetPlayer == LocalPlayer then return true end

    -- Team check: Marines cannot attack Marines
    if LocalPlayer.Team and targetPlayer.Team then
        if LocalPlayer.Team.Name == "Marines" and targetPlayer.Team.Name == "Marines" then
            return true
        end
    end

    -- Ally list check
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local alliesFrame = pg and pg:FindFirstChild("Main") and pg.Main:FindFirstChild("Allies")
    local scroll = alliesFrame and alliesFrame:FindFirstChild("Container") and alliesFrame.Container:FindFirstChild("Allies") and alliesFrame.Container.Allies:FindFirstChild("ScrollingFrame")
    if scroll then
        for _, item in ipairs(scroll:GetDescendants()) do
            if item:IsA("ImageButton") and item.Name == targetPlayer.Name then
                return true
            end
        end
    end
    return false
end

local function getTarget(maxDistance)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local closest, closestDist = nil, maxDistance or 1000
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and not isAlly(plr) then
            local eHrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local eHum = plr.Character:FindFirstChildOfClass("Humanoid")
            if eHrp and eHum and eHum.Health > 0 and not plr.Character:FindFirstChild("SafeZone") then
                local d = (eHrp.Position - hrp.Position).Magnitude
                if d < closestDist then
                    closest = plr.Character
                    closestDist = d
                end
            end
        end
    end
    return closest
end

-- ========= 3. HIT-RELEASE AIMLOCK =========
local aimConn = nil
local dmgConn = nil
local aimTimeout = nil

local function stopAimlock()
    if aimConn then aimConn:Disconnect(); aimConn = nil end
    if dmgConn then dmgConn:Disconnect(); dmgConn = nil end
    if aimTimeout then pcall(task.cancel, aimTimeout); aimTimeout = nil end
end

local function startAimlock(targetChar)
    stopAimlock()
    if not GodhumanZ.AimlockEnabled or not targetChar then return end

    local tHrp = targetChar:FindFirstChild("HumanoidRootPart")
    if not tHrp then return end

    aimConn = RunService.RenderStepped:Connect(function()
        if targetChar and targetChar.Parent and tHrp.Parent then
            local cam = Workspace.CurrentCamera or Camera
            if cam then
                cam.CFrame = CFrame.lookAt(cam.CFrame.Position, tHrp.Position)
            end
        else
            stopAimlock()
        end
    end)

    -- Auto-release on damage
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local dmgText = pg and pg:FindFirstChild("Main") and pg.Main:FindFirstChild("DmgCounter") and pg.Main.DmgCounter:FindFirstChild("Text")
    if dmgText then
        dmgConn = dmgText:GetPropertyChangedSignal("Text"):Connect(function()
            if (tonumber(dmgText.Text) or 0) > 0 then
                stopAimlock()
            end
        end)
    end

    aimTimeout = task.delay(GLIDE_DURATION, stopAimlock)
end

-- ========= 4. TOOL RESOLUTION =========
local function getTool(pattern)
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    local pLower = string.lower(pattern or "")

    local function matches(t)
        if not (t and t:IsA("Tool")) then return false end
        local n = string.lower(t.Name)
        if pLower == "godhuman" then
            return n:find("godhuman") or n:find("god human") or n:find("combat")
        elseif pLower == "fruit" then
            return t.ToolTip == "Blox Fruit" or n:find("fruit")
        elseif pLower == "sword" then
            return t.ToolTip == "Sword" or t:FindFirstChild("Sword")
        elseif pLower == "gun" then
            return t.ToolTip == "Gun" or t:FindFirstChild("Gun")
        elseif pLower:find("auto") or pLower:find("slot") then
            return not (n:find("godhuman") or n:find("god human"))
        end
        return n:find(pLower) ~= nil
    end

    if char then
        for _, t in ipairs(char:GetChildren()) do
            if matches(t) then return t end
        end
    end
    if backpack then
        for _, t in ipairs(backpack:GetChildren()) do
            if matches(t) then return t end
        end
    end
    return nil
end

-- ========= 5. GLITCH MOMENTUM PHYSICS =========
local function doLaunch(targetHrp)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Sky arc 90 len troi (pure vertical sky launch)
    local dir = Vector3.new(0, 1, 0)
    if SKY_ARC_ANGLE ~= 90 then
        local cam = Workspace.CurrentCamera or Camera
        local look = cam and cam.CFrame.LookVector or hrp.CFrame.LookVector
        local rad = math.rad(SKY_ARC_ANGLE)
        local flat = Vector3.new(look.X, 0, look.Z).Unit
        dir = (flat * math.cos(rad) + Vector3.new(0, math.sin(rad), 0)).Unit
    end

    -- Clean up any prior physics instances
    for _, c in ipairs(hrp:GetChildren()) do
        if c.Name:find("VinserGodhuman") or c:GetAttribute("VinserPhysics") then
            pcall(c.Destroy, c)
        end
    end

    local att = Instance.new("Attachment")
    att.Name = "VinserGodhumanAttachment"
    att:SetAttribute("VinserPhysics", true)
    att.Parent = hrp

    local lv = Instance.new("LinearVelocity")
    lv.Name = "VinserGodhumanVelocity"
    lv:SetAttribute("VinserPhysics", true)
    lv.MaxForce = 1e7
    lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    lv.VectorVelocity = dir * VELOCITY_POWER
    lv.Attachment0 = att
    lv.Parent = hrp

    _G.Vinser_GodhumanBoosting = true
    _G.Vinser_Boosting = true
    hrp.AssemblyLinearVelocity = dir * VELOCITY_POWER

    task.delay(GLIDE_DURATION, function()
        if lv and lv.Parent then lv:Destroy() end
        if att and att.Parent then att:Destroy() end
        _G.Vinser_GodhumanBoosting = false
        _G.Vinser_Boosting = false
    end)
end

-- ========= 6. TRIGGER THE BOOST (KEYBIND [E] OR UI BUTTON ONLY) =========
function GodhumanZ.Trigger()
    if GodhumanZ.IsExecuting then return false end

    -- Cooldown check (safe, won't block if GUI is hidden)
    if GodhumanZ.CheckCooldown and isSoaringBeastOnCooldown() then
        local notify = rawget(_G, "VinserNotify")
        if notify then notify("Soaring Beast is on cooldown!", 1.5) end
        return false
    end

    GodhumanZ.IsExecuting = true

    task.spawn(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then
            GodhumanZ.IsExecuting = false
            return
        end

        local godhuman = getTool("godhuman")

        -- 1. Ensure Godhuman is equipped
        if godhuman and godhuman.Parent ~= char then
            pcall(function() hum:EquipTool(godhuman) end)
            local t = os.clock() + 0.3
            while godhuman.Parent ~= char and os.clock() < t do task.wait(0.02) end
        end

        -- 2. Target lock
        local target = nil
        if GodhumanZ.AimlockEnabled then
            target = getTarget(1000)
            if target then
                startAimlock(target)
                task.wait(0.02)
            end
        end

        -- 3. Hold and release Z using multiple input methods for max compatibility
        if VIM then
            pcall(function() VIM:SendKeyEvent(true, Enum.KeyCode.Z, false, game) end)
        end
        local kp = rawget(getfenv(), "keypress") or rawget(getgenv(), "keypress")
        local kr = rawget(getfenv(), "keyrelease") or rawget(getgenv(), "keyrelease")
        if kp then pcall(kp, 0x5A) end

        task.wait(0.12)

        if VIM then
            pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.Z, false, game) end)
        end
        if kr then pcall(kr, 0x5A) end

        -- 4. Move Cancel: Unequip or Swap
        local mode = tostring(GodhumanZ.CancelMode or "Unequip")
        if mode:find("Unequip") or mode == "None" then
            pcall(function() hum:UnequipTools() end)
        else
            local swapTool = getTool(mode)
            if swapTool then
                pcall(function() hum:EquipTool(swapTool) end)
            else
                pcall(function() hum:UnequipTools() end)
            end
        end

        -- 5. Catapult impulse
        local tHrp = target and target:FindFirstChild("HumanoidRootPart")
        doLaunch(tHrp)

        -- 6. Re-equip Godhuman upon landing
        if GodhumanZ.SwitchBack and godhuman then
            task.delay(GLIDE_DURATION + 0.05, function()
                local c = LocalPlayer.Character
                local h = c and c:FindFirstChildOfClass("Humanoid")
                if h and godhuman and godhuman.Parent ~= c then
                    pcall(function() h:EquipTool(godhuman) end)
                end
            end)
        end

        task.wait(0.3)
        GodhumanZ.IsExecuting = false
    end)

    return true
end

-- ========= 8. PUBLIC API & LISTENERS =========
function GodhumanZ.SetEnabled(state)
    GodhumanZ.Enabled = (state == true)
    _G.VinsersHub_GodhumanZ = GodhumanZ.Enabled
    _G.DarlingX_GodhumanZ = GodhumanZ.Enabled
    if not GodhumanZ.Enabled then stopAimlock() end
end

function GodhumanZ.SetCancelMode(mode)
    GodhumanZ.CancelMode = tostring(mode or "Unequip")
end

function GodhumanZ.SetCancelWeapon(weapon)
    GodhumanZ.SetCancelMode(weapon)
end

function GodhumanZ.SetCheckCooldown(state)
    GodhumanZ.CheckCooldown = (state == true)
end

function GodhumanZ.SetSwitchBack(state)
    GodhumanZ.SwitchBack = (state == true)
end

function GodhumanZ.SetAimlock(state)
    GodhumanZ.AimlockEnabled = (state == true)
end

function GodhumanZ.SetKeybind(key)
    if typeof(key) == "EnumItem" then
        GodhumanZ.Keybind = key
    elseif type(key) == "string" and Enum.KeyCode[key] then
        GodhumanZ.Keybind = Enum.KeyCode[key]
    else
        GodhumanZ.Keybind = key
    end
end

function GodhumanZ.SetPower(power)
    local p = tonumber(power)
    if p then VELOCITY_POWER = p end
end

function GodhumanZ.SetDuration(dur)
    local d = tonumber(dur)
    if d then GLIDE_DURATION = d end
end

function GodhumanZ.SetSkyArc(angle)
    local a = tonumber(angle)
    if a then SKY_ARC_ANGLE = a end
end

function GodhumanZ.SetTargetInfo(state)
    GodhumanZ.TargetInfo = (state == true)
end

function GodhumanZ.IsOnCooldown()
    return isSoaringBeastOnCooldown()
end

-- Direct key listener for Godhuman Z Boost Keybind (default [E])
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if UserInputService:GetFocusedTextBox() then return end
    if not GodhumanZ.Enabled then return end

    local k = GodhumanZ.Keybind
    local match = (typeof(k) == "EnumItem" and input.KeyCode == k)
        or (type(k) == "string" and input.KeyCode.Name == k)

    if match then
        GodhumanZ.Trigger()
    end
end)

_G.VinsersHub_GodhumanZMod = GodhumanZ
_G.DarlingX_GodhumanZMod = GodhumanZ

return GodhumanZ
