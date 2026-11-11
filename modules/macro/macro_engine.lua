--[[
    Darling X - Smart Macro Engine (Version 1.3)
    Darling X - Autonomous Cooldown Synchronization Suite
    5 Slots with 6 Blocks each, CATEGORY_TIPS weapon auto-equip,
    Real-time PlayerGui.Main.Skills Cooldown HUD reading with dynamic retry,
    0.045s Tap / Hold casting via VirtualInputManager, post-skill jumps,
    Loop execution, and on-screen draggable mobile button.
]]

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    local s = tick()
    while not LocalPlayer and tick() - s < 3 do
        task.wait(0.05)
        LocalPlayer = Players.LocalPlayer
    end
end

local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)

local MacroEngine = {
    Enabled = false,
    Running = false,
    RunToken = 0,
    ActiveSlot = 1,
    Loop = false,
    TriggerKey = Enum.KeyCode.F,
    ShowMobileButton = false,
    Status = "Idle",
    Slots = {
        {
            Name = "Combo 1",
            Blocks = {
                { Enabled = true,  Weapon = "Melee", Skill = "Z", Mode = "Tap", Hold = 0, Jumps = 0 },
                { Enabled = true,  Weapon = "Sword", Skill = "X", Mode = "Tap", Hold = 0, Jumps = 0 },
                { Enabled = true,  Weapon = "Melee", Skill = "C", Mode = "Tap", Hold = 0, Jumps = 0 },
                { Enabled = false, Weapon = "Gun",   Skill = "Z", Mode = "Tap", Hold = 0, Jumps = 0 },
                { Enabled = false, Weapon = "Fruit", Skill = "V", Mode = "Tap", Hold = 0, Jumps = 0 },
                { Enabled = false, Weapon = "Melee", Skill = "X", Mode = "Tap", Hold = 0, Jumps = 0 },
            }
        },
        {
            Name = "Combo 2",
            Blocks = {
                { Enabled = true,  Weapon = "Sword", Skill = "Z", Mode = "Tap", Hold = 0, Jumps = 0 },
                { Enabled = true,  Weapon = "Melee", Skill = "Z", Mode = "Tap", Hold = 0, Jumps = 0 },
                { Enabled = false, Weapon = "Fruit", Skill = "C", Mode = "Tap", Hold = 0, Jumps = 0 },
                { Enabled = false, Weapon = "Gun",   Skill = "X", Mode = "Tap", Hold = 0, Jumps = 0 },
                { Enabled = false, Weapon = "Melee", Skill = "C", Mode = "Tap", Hold = 0, Jumps = 0 },
                { Enabled = false, Weapon = "Sword", Skill = "X", Mode = "Tap", Hold = 0, Jumps = 0 },
            }
        },
        { Name = "Combo 3", Blocks = {} },
        { Name = "Combo 4", Blocks = {} },
        { Name = "Combo 5", Blocks = {} },
    }
}

-- Ensure all 5 slots and 6 blocks are fully populated
for s = 1, 5 do
    MacroEngine.Slots[s] = MacroEngine.Slots[s] or { Name = "Combo " .. s, Blocks = {} }
    for b = 1, 6 do
        if not MacroEngine.Slots[s].Blocks[b] then
            MacroEngine.Slots[s].Blocks[b] = { Enabled = false, Weapon = "Melee", Skill = "Z", Mode = "Tap", Hold = 0, Jumps = 0 }
        end
    end
end

-- Backward compatibility aliases
MacroEngine.Blocks = MacroEngine.Slots[1].Blocks
MacroEngine.LoopMode = MacroEngine.Loop

local statusCallbacks = {}
local macroThread = nil
local activeKey = nil

local function getActiveSlot()
    return MacroEngine.Slots[MacroEngine.ActiveSlot] or MacroEngine.Slots[1]
end

local function setStatus(t)
    MacroEngine.Status = tostring(t or "Idle")
    for _, cb in ipairs(statusCallbacks) do
        pcall(cb, MacroEngine.Status)
    end
end

local function isRunning(token)
    return MacroEngine.Running and MacroEngine.RunToken == token
end

local function waitFor(duration, token)
    local deadline = os.clock() + math.max(0, duration or 0)
    while os.clock() < deadline do
        if not isRunning(token) then return false end
        task.wait()
    end
    return isRunning(token)
end

local CATEGORY_TIPS = {
    Melee = { "Melee" },
    Sword = { "Sword" },
    Fruit = { "Blox Fruit", "Fruit" },
    Gun   = { "Gun" },
}

local function toolMatches(tool, category)
    if not (tool and tool:IsA("Tool")) then return false end
    local tips = CATEGORY_TIPS[category]
    if not tips then return false end

    local tip = tostring(tool.ToolTip or "")
    local wType = tostring(tool:GetAttribute("WeaponType") or tool:GetAttribute("ItemType") or "")
    for _, t in ipairs(tips) do
        if tip == t or wType == t then return true end
    end

    local name = string.lower(tool.Name)
    if category == "Melee" then
        if name:find("godhuman") or name:find("superhuman") or name:find("karate") or name:find("claw") or name:find("talon") or name:find("step") or name:find("sanguine") or name:find("combat") or name:find("breath") or name:find("kung fu") then
            return true
        end
    elseif category == "Sword" then
        if name:find("blade") or name:find("katana") or name:find("saber") or name:find("scythe") or name:find("anchor") or name:find("trident") or name:find("dagger") or name:find("cutlass") or name:find("sword") or tool:FindFirstChild("Sword") then
            return true
        end
    elseif category == "Fruit" then
        if name:find("fruit") or name:find("-") or tool:FindFirstChild("Fruit") then
            return true
        end
    elseif category == "Gun" then
        if name:find("rifle") or name:find("cannon") or name:find("bow") or name:find("gun") or name:find("guitar") or name:find("kabucha") or name:find("slingshot") or name:find("bazooka") or tool:FindFirstChild("Gun") or tool:FindFirstChild("RemoteFunctionShoot") then
            return true
        end
    end

    return false
end

local function equipWeaponCategory(category, token)
    if not category or category == "None" then
        local char = LocalPlayer.Character
        return char and char:FindFirstChildOfClass("Tool")
    end
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not char then return nil end

    local held = char:FindFirstChildOfClass("Tool")
    if held and toolMatches(held, category) then return held end

    local target = nil
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if toolMatches(tool, category) then
                target = tool
                break
            end
        end
    end

    if not target then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end

    pcall(function() hum:EquipTool(target) end)
    local deadline = os.clock() + 0.6
    while os.clock() < deadline do
        if not isRunning(token) then return nil end
        if target.Parent == char then return target end
        task.wait()
    end
    return target.Parent == char and target or nil
end

local smartCooldownCache = {}
local smartReadyCache = {}

local function smartCooldownWidth(cd)
    if not (cd and cd.Parent) then return 0, "none" end
    local x = cd.Size.X
    if math.abs(x.Scale) > 0.002 then return math.abs(x.Scale), "scale" end
    if math.abs(x.Offset) > 1 then return math.abs(x.Offset), "offset" end
    return 0, "none"
end

local function smartCooldownActive(cd)
    return smartCooldownWidth(cd) > 0
end

local function findSmartCooldown(toolName, skill, fresh)
    local key = tostring(toolName or "") .. "\0" .. tostring(skill or "")
    local cached = smartCooldownCache[key]
    if not fresh and cached and cached.Parent then return cached end

    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local main = pg and pg:FindFirstChild("Main")
    local skills = main and main:FindFirstChild("Skills")
    local frame = skills and skills:FindFirstChild(toolName or "")
    if not frame and skills then
        local norm = string.lower(tostring(toolName or "")):gsub("[^%w]", "")
        for _, child in ipairs(skills:GetChildren()) do
            local n = string.lower(child.Name):gsub("[^%w]", "")
            if n == norm or n == norm .. norm or norm == n .. n then
                frame = child
                break
            end
        end
    end

    local sk = frame and frame:FindFirstChild(tostring(skill or ""))
    local cd = sk and sk:FindFirstChild("Cooldown")
    if not (cd and cd:IsA("GuiObject")) then
        return nil, "cooldown panel was not found for " .. tostring(toolName) .. " " .. tostring(skill)
    end
    smartCooldownCache[key] = cd
    return cd
end

local function waitForSmartCooldownReady(toolName, skill, token, timeout)
    local key = tostring(toolName or "") .. "\0" .. tostring(skill or "")
    local deadline = os.clock() + math.max(0.3, tonumber(timeout) or 1.5)
    local candidate, seenAt = nil, 0
    local reason = "cooldown panel was not found"

    while isRunning(token) and os.clock() < deadline do
        local cd, err = findSmartCooldown(toolName, skill, true)
        if cd then
            local p1 = cd.Parent
            local p2 = p1 and p1.Parent
            if p1 and p2 and (not p1:IsA("GuiObject") or p1.Visible) and (not p2:IsA("GuiObject") or p2.Visible) then
                if smartReadyCache[key] == cd then return cd, "" end
                if candidate ~= cd then
                    candidate, seenAt = cd, os.clock()
                elseif os.clock() - seenAt >= 0.03 then
                    smartReadyCache[key] = cd
                    return cd, ""
                end
            else
                candidate, seenAt, reason = nil, 0, "skill HUD is still opening"
            end
        else
            candidate, seenAt, reason = nil, 0, err or reason
        end
        task.wait(0.015)
    end
    return nil, reason
end

local function waitForSmartCooldown(cd, token, timeout, toolName, skill)
    local ackDeadline = os.clock() + math.max(0.25, tonumber(timeout) or 1.5)
    local nextLookup = 0
    local started, peak, mode, progressDeadline = false, 0, "none", nil

    while isRunning(token) do
        if os.clock() >= nextLookup then
            local fresh = findSmartCooldown(toolName, skill, true)
            if fresh and fresh ~= cd then
                if started then peak, mode = 0, "none" end
                cd = fresh
            end
            nextLookup = os.clock() + 0.05
        end

        local w, m = smartCooldownWidth(cd)
        if w > 0 then
            if not started then
                started, peak, mode, progressDeadline = true, w, m, os.clock() + 6
            elseif m ~= mode then
                peak, mode = w, m
            else
                if w > peak then peak = w end
                local threshold = (m == "offset") and 1 or 0.003
                if threshold < peak - w then
                    return true, "", true
                end
            end
        elseif started and peak > 0 then
            return true, "", true
        end

        if not started and os.clock() >= ackDeadline then
            if not (cd and cd.Parent) then
                return false, "cooldown HUD was replaced", false
            end
            return false, "cast was not acknowledged by cooldown HUD", false
        end

        if started and progressDeadline and os.clock() >= progressDeadline then
            return false, "cooldown HUD did not begin progressing", true
        end

        task.wait(0.015)
    end
    return false, "playback was stopped", started
end

local function releaseActiveKey()
    if activeKey and VIM then
        local k = activeKey
        pcall(function() VIM:SendKeyEvent(false, k, false, game) end)
    end
    activeKey = nil
end

local function castSmartStep(block, token)
    if not isRunning(token) then return false, "playback stopped" end
    local keyCode = Enum.KeyCode[block.Skill or "Z"]
    if not keyCode or not VIM then
        return false, "ability input unavailable [" .. tostring(block.Skill) .. "]"
    end

    local duration = 0.045
    if block.Mode == "Hold" then
        duration = math.clamp(tonumber(block.Hold) or 0, 0, 10)
        if duration == 0 then duration = 0.045 end
    end

    local ok = pcall(function() VIM:SendKeyEvent(true, keyCode, false, game) end)
    if not ok then return false, "key event failed" end

    activeKey = keyCode
    local alive = waitFor(duration, token)
    releaseActiveKey()
    return alive, alive and "" or "playback was stopped"
end

local function runPostSkillJumps(count, token)
    count = tonumber(count) or 0
    if count <= 0 then return true end
    for _ = 1, count do
        if not isRunning(token) then return false end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        if not waitFor(0.12, token) then return false end
    end
    return true
end

function MacroEngine.stopMacro()
    MacroEngine.Running = false
    MacroEngine.RunToken = (MacroEngine.RunToken or 0) + 1
    releaseActiveKey()

    if macroThread and macroThread ~= coroutine.running() then
        pcall(task.cancel, macroThread)
    end
    macroThread = nil
    setStatus("Idle")

    local b = macroBtn or mobileMacroBtn
    if b then
        b.Text = "MACRO\nOFF"
        b.TextColor3 = Color3.fromRGB(220, 220, 220)
    end
end

local function runBlock(idx, block, token)
    setStatus("Block " .. idx .. " (" .. tostring(block.Weapon) .. " " .. tostring(block.Skill) .. ")")
    local tool = equipWeaponCategory(block.Weapon, token)
    if not isRunning(token) then return false end

    local toolName = tool and tool.Name or ""
    local cd = nil
    if toolName ~= "" then
        cd = waitForSmartCooldownReady(toolName, block.Skill, token, 1.5)
        if not isRunning(token) then return false end
        if cd and smartCooldownActive(cd) then return true end
    end

    local ok = castSmartStep(block, token)
    if not ok then return isRunning(token) end

    if cd then
        local done, _, started = waitForSmartCooldown(cd, token, 1.5, toolName, block.Skill)
        if not done and not started and isRunning(token) then
            if not waitFor(0.035, token) then return false end
            if not castSmartStep(block, token) then return isRunning(token) end
            waitForSmartCooldown(cd, token, 1.5, toolName, block.Skill)
        end
    else
        task.wait()
    end

    return runPostSkillJumps(block.Jumps, token)
end

local function runMacroSequence(token)
    local slot = getActiveSlot()
    repeat
        local anyEnabled = false
        for idx, block in ipairs(slot.Blocks) do
            if not isRunning(token) then break end
            if block.Enabled then
                anyEnabled = true
                local ok, err = pcall(runBlock, idx, block, token)
                if not ok then
                    setStatus("Block " .. idx .. " error")
                end
            end
        end

        if not anyEnabled then
            setStatus("No blocks enabled")
            break
        end

        if MacroEngine.Loop and isRunning(token) then
            task.wait(0.05)
        end
    until not MacroEngine.Loop or not isRunning(token)

    if MacroEngine.RunToken == token then
        macroThread = nil
        MacroEngine.stopMacro()
    end
end

function MacroEngine.startMacro()
    if MacroEngine.Running then
        MacroEngine.stopMacro()
        return
    end

    MacroEngine.RunToken = (MacroEngine.RunToken or 0) + 1
    MacroEngine.Running = true
    local token = MacroEngine.RunToken
    setStatus("Running...")

    local b = macroBtn or mobileMacroBtn
    if b then
        b.Text = "MACRO\nON"
        b.TextColor3 = Color3.fromRGB(255, 75, 145)
    end

    macroThread = task.spawn(runMacroSequence, token)
end

function MacroEngine.toggle(state)
    MacroEngine.Enabled = (state == true)
    if not MacroEngine.Enabled and MacroEngine.Running then
        MacroEngine.stopMacro()
    end
end

function MacroEngine.executeCombo()
    if MacroEngine.Running then
        MacroEngine.stopMacro()
    else
        MacroEngine.startMacro()
    end
end

function MacroEngine.setSlot(blockIndex, weapon, skill, enabled, mode, hold, jumps)
    local slot = getActiveSlot()
    local b = slot.Blocks[blockIndex]
    if not b then return end

    if weapon ~= nil then b.Weapon = weapon end
    if skill ~= nil then b.Skill = skill end
    if enabled ~= nil then b.Enabled = enabled end
    if mode ~= nil then b.Mode = mode end
    if hold ~= nil then b.Hold = tonumber(hold) or 0 end
    if jumps ~= nil then b.Jumps = tonumber(jumps) or 0 end
end

function MacroEngine.setStatusCallback(cb)
    if type(cb) == "function" then
        table.insert(statusCallbacks, cb)
    end
end

local macroGui = nil
local macroBtn = nil

-- Draggable On-Screen One-Touch Action Widget
function MacroEngine.ensureMobileButton(show)
    if show then
        if not macroGui then
            local parent = nil
            pcall(function()
                local gethui = (type(gethui) == "function" and gethui) or (getgenv and getgenv().gethui)
                parent = (gethui and gethui()) or CoreGui or (LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui"))
            end)
            macroGui = Instance.new("ScreenGui")
            macroGui.Name = "DarlingMacroWidget"
            macroGui.ResetOnSpawn = false
            macroGui.DisplayOrder = 99999
            macroGui.IgnoreGuiInset = true
            pcall(function()
                local syn = (type(syn) == "table" and syn) or (getgenv and getgenv().syn)
                if syn and syn.protect_gui then syn.protect_gui(macroGui) end
            end)
            macroGui.Parent = parent

            local frame = Instance.new("Frame", macroGui)
            frame.Size = UDim2.new(0, 60, 0, 60)
            frame.Position = UDim2.new(0.85, 0, 0.45, 0)
            frame.BackgroundColor3 = Color3.fromRGB(15, 12, 22)
            frame.BackgroundTransparency = 0.3
            frame.Active = true

            local corner = Instance.new("UICorner", frame)
            corner.CornerRadius = UDim.new(0, 16)

            local stroke = Instance.new("UIStroke", frame)
            stroke.Color = Color3.fromRGB(168, 85, 247)
            stroke.Thickness = 1.2
            stroke.Transparency = 0.4

            local btn = Instance.new("TextButton", frame)
            btn.Size = UDim2.new(1, -6, 1, -6)
            btn.Position = UDim2.new(0, 3, 0, 3)
            btn.BackgroundTransparency = 1
            btn.Text = "MACRO\nOFF"
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 10
            btn.TextColor3 = Color3.fromRGB(220, 220, 220)
            macroBtn = btn

            local dragging = false
            local dragStart = nil
            local startPos = nil
            local hasMoved = false

            btn.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    hasMoved = false
                    dragStart = input.Position
                    startPos = frame.Position

                    input.Changed:Connect(function()
                        if input.UserInputState == Enum.UserInputState.End then
                            if dragging and not hasMoved then
                                if MacroEngine.Running then
                                    MacroEngine.stopMacro()
                                else
                                    MacroEngine.executeCombo()
                                end
                            end
                            dragging = false
                        end
                    end)
                end
            end)

            UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    local delta = input.Position - dragStart
                    if delta.Magnitude > 6 then hasMoved = true end
                    frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                end
            end)
        end
        macroGui.Enabled = true
    else
        if macroGui then
            macroGui.Enabled = false
        end
    end
end

MacroEngine.AutoStartOnX = false

function MacroEngine.setAutoStartOnX(state)
    MacroEngine.AutoStartOnX = (state == true)
    _G.VinsersHub_MacroAutoX = MacroEngine.AutoStartOnX
    _G.DarlingX_MacroAutoX = MacroEngine.AutoStartOnX
end

-- Keyboard trigger listener
UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe or inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if UserInputService:GetFocusedTextBox() then return end
    if inp.KeyCode == MacroEngine.TriggerKey and MacroEngine.Enabled then
        if MacroEngine.Running then
            MacroEngine.stopMacro()
        else
            MacroEngine.startMacro()
        end
    elseif inp.KeyCode == Enum.KeyCode.X and MacroEngine.AutoStartOnX and MacroEngine.Enabled and not MacroEngine.Running then
        task.spawn(function()
            task.wait(0.2) -- allow initial X move startup
            if MacroEngine.AutoStartOnX and MacroEngine.Enabled and not MacroEngine.Running then
                MacroEngine.startMacro()
            end
        end)
    end
end)

return MacroEngine
