--[[
    Darling X - Soru Controller Module
    Authentic Blox Fruits Soru / Flashstep integration.
    Includes Infinite Soru, Soru Aimbot, and Auto Skill Combo.
    Based on proven patterns with direct R-key & animation listeners.
    Zero emojis, zero third-party references.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local SoruController = {
    MasterEnabled = false,
    InfiniteEnabled = false,
    AimbotEnabled = false,
    TargetMode = "Nearest Player",
    SelectedPlayer = nil,
    MaxDistance = 2000,
    SkillComboEnabled = false,
    SkillWeapon = "Fruit",
    SkillKey = "Z",
    SkillDelay = 0.25,
    
    Hooked = false,
    InfiniteLoopRunning = false,
}

local FLASH_NAMES = { "FlashStepRegular", "FlashStepDraco", "FlashStep", "Flashstep", "Soru" }
local FLASH_IDS = { "17555632156", "18461649274", "616006778", "616010882", "5403485593", "5403491911" }

local function isFlashstepAnim(track)
    if not track then return false end
    local name = track.Name and track.Name:lower() or ""
    for _, n in ipairs(FLASH_NAMES) do
        if name:find(n:lower(), 1, true) then return true end
    end
    local anim = track.Animation
    local id = anim and anim.AnimationId:match("%d+") or ""
    for _, fid in ipairs(FLASH_IDS) do
        if id == fid then return true end
    end
    return false
end

local function getAimbotTarget()
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end

    if SoruController.TargetMode ~= "Nearest Player" and SoruController.SelectedPlayer then
        local targetPlayer = Players:FindFirstChild(SoruController.SelectedPlayer)
        if targetPlayer and targetPlayer.Character then
            local eHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
            local eHum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
            if eHRP and eHum and eHum.Health > 0 then
                local dist = (myHRP.Position - eHRP.Position).Magnitude
                if dist <= SoruController.MaxDistance then
                    return eHRP
                end
            end
        end
    end

    local closestDist = SoruController.MaxDistance
    local bestHRP = nil

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local eHRP = p.Character:FindFirstChild("HumanoidRootPart")
            local eHum = p.Character:FindFirstChildOfClass("Humanoid")
            if eHRP and eHum and eHum.Health > 0 then
                local dist = (myHRP.Position - eHRP.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    bestHRP = eHRP
                end
            end
        end
    end

    return bestHRP
end

local function setupMetamethodHook()
    if SoruController.Hooked then return end
    if not hookmetamethod then return end

    pcall(function()
        local oldIndex = nil
        oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
            if not checkcaller() and self == Mouse and (key == "Hit" or key == "Target") then
                if SoruController.AimbotEnabled then
                    local targetHRP = getAimbotTarget()
                    if targetHRP then
                        if key == "Hit" then
                            return CFrame.new(targetHRP.Position)
                        elseif key == "Target" then
                            return targetHRP
                        end
                    end
                end
            end
            return oldIndex(self, key)
        end))
        SoruController.Hooked = true
    end)
end

local function isToolMatchingType(tool, targetType)
    if not tool or not tool:IsA("Tool") then return false end
    local tt = tool.ToolTip or ""
    local name = tool.Name:lower()
    local tType = (targetType or "Fruit"):lower()

    if tType:find("fruit") then
        return tt:lower():find("fruit") ~= nil or name:find("fruit") ~= nil or name:find("portal") ~= nil
    elseif tType:find("melee") then
        return tt:lower():find("melee") ~= nil or name:find("combat") ~= nil or name:find("fist") ~= nil or name:find("sanguine") ~= nil or name:find("karate") ~= nil
    elseif tType:find("sword") then
        return tt:lower():find("sword") ~= nil or name:find("blade") ~= nil or name:find("katana") ~= nil or name:find("saber") ~= nil
    elseif tType:find("gun") then
        return tt:lower():find("gun") ~= nil or name:find("rifle") ~= nil or name:find("cannon") ~= nil or name:find("flintlock") ~= nil
    end
    return name:find(tType) ~= nil
end

local isComboRunning = false

local function executeSkillCombo()
    if not SoruController.SkillComboEnabled then return end
    if isComboRunning then return end
    isComboRunning = true

    task.spawn(function()
        local d = tonumber(SoruController.SkillDelay) or 0.25
        task.wait(d)
        if not SoruController.SkillComboEnabled then
            isComboRunning = false
            return
        end

        local myChar = LocalPlayer.Character
        local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
        if not hum then
            isComboRunning = false
            return
        end

        local targetToolName = SoruController.SkillWeapon or "Fruit"
        local foundTool = nil

        for _, item in ipairs(myChar:GetChildren()) do
            if isToolMatchingType(item, targetToolName) then
                foundTool = item
                break
            end
        end

        if not foundTool and LocalPlayer:FindFirstChild("Backpack") then
            for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
                if isToolMatchingType(item, targetToolName) then
                    foundTool = item
                    pcall(function() hum:EquipTool(foundTool) end)
                    task.wait(0.08)
                    break
                end
            end
        end

        local key = SoruController.SkillKey or "Z"
        local keyEnum = Enum.KeyCode[key]

        -- Safe VirtualInputManager key event dispatch wrapped in pcall
        pcall(function()
            if keyEnum then
                local vim = game:GetService("VirtualInputManager")
                if vim then
                    vim:SendKeyEvent(true, keyEnum, false, game)
                    task.wait(0.06)
                    vim:SendKeyEvent(false, keyEnum, false, game)
                end
            end
        end)

        task.wait(0.5) -- Debounce cooldown lock
        isComboRunning = false
    end)
end

local function setupCharacter(char)
    if not char then return end

    if SoruController.InfiniteEnabled then
        pcall(function() char:SetAttribute("FlashstepCooldown", 1) end)
        char:GetAttributeChangedSignal("FlashstepCooldown"):Connect(function()
            if SoruController.InfiniteEnabled and char:GetAttribute("FlashstepCooldown") ~= 1 then
                pcall(function() char:SetAttribute("FlashstepCooldown", 1) end)
            end
        end)
    end

    local hum = char:WaitForChild("Humanoid", 4)
    if hum then
        hum.AnimationPlayed:Connect(function(track)
            if isFlashstepAnim(track) then
                executeSkillCombo()
            end
        end)
    end
end

-- Direct R Key listener for Soru
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.R then
        if SoruController.SkillComboEnabled then
            executeSkillCombo()
        end
    end
end)

function SoruController.setInfinite(state)
    SoruController.InfiniteEnabled = (state == true)
    local char = LocalPlayer.Character
    if char then setupCharacter(char) end

    if state then
        if not SoruController.InfiniteLoopRunning then
            SoruController.InfiniteLoopRunning = true
            task.spawn(function()
                while SoruController.InfiniteEnabled do
                    task.wait(0.5)
                    local c = LocalPlayer.Character
                    if c and c:GetAttribute("FlashstepCooldown") ~= 1 then
                        pcall(function() c:SetAttribute("FlashstepCooldown", 1) end)
                    end
                end
                SoruController.InfiniteLoopRunning = false
            end)
        end
    end
end

function SoruController.setAimbot(state)
    SoruController.AimbotEnabled = (state == true)
    if state then setupMetamethodHook() end
end

function SoruController.setSkillCombo(state)
    SoruController.SkillComboEnabled = (state == true)
end

if LocalPlayer.Character then
    setupCharacter(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(setupCharacter)

return SoruController
