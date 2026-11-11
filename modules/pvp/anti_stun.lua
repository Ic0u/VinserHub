--[[
    Vinser Hub - Anti Stun & Anti Knockback Engine
    Clean, non-invasive Stun neutralizer.
    Clears hostile stun objects without breaking player's own skills (Gun, Fruit, Melee, Sword).
    Zero bloat, zero skill interference, zero flings.
]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local AntiStun = {
    AntiStunEnabled = false,
    AntiKnockbackEnabled = false,
    CharAddedConn = nil,
    ChildAddedConn = nil,
}

local function clearStun(char)
    if not char then return end
    -- Blox Fruits stun is an object named "Stun" inside Character
    local s = char:FindFirstChild("Stun")
    if s then
        pcall(function() s:Destroy() end)
    end
    -- Clean stun attribute if present
    if char:GetAttribute("Stun") ~= nil then
        pcall(function() char:SetAttribute("Stun", nil) end)
    end
    if char:GetAttribute("Stunned") ~= nil then
        pcall(function() char:SetAttribute("Stunned", nil) end)
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
    end
end

local function hookCharacter(char)
    if not char then return end

    if AntiStun.ChildAddedConn then
        pcall(function() AntiStun.ChildAddedConn:Disconnect() end)
        AntiStun.ChildAddedConn = nil
    end

    AntiStun.ChildAddedConn = char.ChildAdded:Connect(function(child)
        if not AntiStun.AntiStunEnabled then return end
        if child.Name == "Stun" then
            task.defer(function()
                pcall(function() child:Destroy() end)
            end)
        end
    end)

    if AntiStun.AntiStunEnabled then
        clearStun(char)
    end
end

function AntiStun.SetAntiStun(enabled)
    AntiStun.AntiStunEnabled = (enabled == true)
    _G.VinsersHub_AntiStun = AntiStun.AntiStunEnabled

    if AntiStun.AntiStunEnabled then
        local char = LocalPlayer.Character
        if char then hookCharacter(char) end

        if not AntiStun.CharAddedConn then
            AntiStun.CharAddedConn = LocalPlayer.CharacterAdded:Connect(hookCharacter)
        end
    else
        if AntiStun.ChildAddedConn then
            pcall(function() AntiStun.ChildAddedConn:Disconnect() end)
            AntiStun.ChildAddedConn = nil
        end
        if AntiStun.CharAddedConn then
            pcall(function() AntiStun.CharAddedConn:Disconnect() end)
            AntiStun.CharAddedConn = nil
        end
    end
end

function AntiStun.SetAntiKnockback(enabled)
    AntiStun.AntiKnockbackEnabled = (enabled == true)
    _G.VinsersHub_AntiKnockback = AntiStun.AntiKnockbackEnabled
end

_G.VinsersHub_AntiStunMod = AntiStun
_G.DarlingX_AntiStunMod = AntiStun

return AntiStun
