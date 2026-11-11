--[[
    Vinser Hub - Anti Stun & Anti Knockback Engine
    Autonomous Stun neutralization, Attribute cleanser, and Hostile Knockback canceller.
    Zero emojis, zero third-party references.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local AntiStun = {
    AntiStunEnabled = false,
    AntiKnockbackEnabled = false,
    
    CharAddedConn = nil,
    ChildAddedConn = nil,
    HrpChildConn = nil,
    AttrConn = nil,
    HrpAttrConn = nil,
    HeartbeatConn = nil,
}

local STUN_NAMES = {
    "stun", "busy", "freeze", "slow", "disabled", "shock", "ice", "ragdoll", "web", "sleep"
}

local STUN_ATTRS = {
    "Stun", "Stunned", "Busy", "Disabled", "Frozen", "Action", "InCombat", "Ragdoll", "NoJump", "NoAttack"
}

local function isStunObject(name)
    local lower = string.lower(name or "")
    for _, s in ipairs(STUN_NAMES) do
        if lower:find(s, 1, true) then return true end
    end
    return false
end

local function cleanStunAttributes(inst)
    if not inst then return end
    for _, attr in ipairs(STUN_ATTRS) do
        if inst:GetAttribute(attr) ~= nil then
            pcall(function() inst:SetAttribute(attr, nil) end)
        end
    end
end

local function isOurPhysics(inst)
    if not inst then return false end
    if inst:GetAttribute("VinserPhysics") or inst:GetAttribute("DarlingPhysics") then
        return true
    end
    local name = string.lower(inst.Name or "")
    if name:find("vinser") or name:find("darling") or name:find("godhuman") or name:find("sanguine") then
        return true
    end
    return false
end

local function hookCharacter(char)
    if not char then return end

    -- Disconnect old per-character listeners
    if AntiStun.ChildAddedConn then
        pcall(function() AntiStun.ChildAddedConn:Disconnect() end)
        AntiStun.ChildAddedConn = nil
    end
    if AntiStun.AttrConn then
        pcall(function() AntiStun.AttrConn:Disconnect() end)
        AntiStun.AttrConn = nil
    end
    if AntiStun.HrpChildConn then
        pcall(function() AntiStun.HrpChildConn:Disconnect() end)
        AntiStun.HrpChildConn = nil
    end
    if AntiStun.HrpAttrConn then
        pcall(function() AntiStun.HrpAttrConn:Disconnect() end)
        AntiStun.HrpAttrConn = nil
    end

    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    local hum = char:WaitForChild("Humanoid", 5)

    -- 1. Anti Stun: Listen to objects added to Character
    AntiStun.ChildAddedConn = char.ChildAdded:Connect(function(child)
        if not AntiStun.AntiStunEnabled then return end
        if isStunObject(child.Name) then
            task.defer(function()
                pcall(function() child:Destroy() end)
            end)
        end
    end)

    -- 2. Anti Stun: Listen to attribute changes on Character
    AntiStun.AttrConn = char.AttributeChanged:Connect(function(attr)
        if not AntiStun.AntiStunEnabled then return end
        for _, sAttr in ipairs(STUN_ATTRS) do
            if attr == sAttr and char:GetAttribute(attr) ~= nil then
                task.defer(function()
                    pcall(function() char:SetAttribute(attr, nil) end)
                end)
            end
        end
    end)

    -- 3. Anti Knockback: Listen to physics constraints inserted into HumanoidRootPart
    if hrp then
        AntiStun.HrpChildConn = hrp.ChildAdded:Connect(function(child)
            if not AntiStun.AntiKnockbackEnabled then return end
            if child:IsA("BodyVelocity") or child:IsA("LinearVelocity") or child:IsA("VectorForce") or child:IsA("BodyPosition") then
                if not isOurPhysics(child) then
                    task.defer(function()
                        pcall(function() child:Destroy() end)
                    end)
                end
            end
        end)

        AntiStun.HrpAttrConn = hrp.AttributeChanged:Connect(function(attr)
            if not AntiStun.AntiStunEnabled then return end
            for _, sAttr in ipairs(STUN_ATTRS) do
                if attr == sAttr and hrp:GetAttribute(attr) ~= nil then
                    task.defer(function()
                        pcall(function() hrp:SetAttribute(attr, nil) end)
                    end)
                end
            end
        end)
    end

    -- Initial sweep of existing objects
    if AntiStun.AntiStunEnabled then
        for _, c in ipairs(char:GetChildren()) do
            if isStunObject(c.Name) then
                pcall(function() c:Destroy() end)
            end
        end
        cleanStunAttributes(char)
        if hrp then cleanStunAttributes(hrp) end
    end
end

local function checkActiveGating()
    local needActive = AntiStun.AntiStunEnabled or AntiKnockbackEnabled

    if needActive then
        if not AntiStun.CharAddedConn then
            AntiStun.CharAddedConn = LocalPlayer.CharacterAdded:Connect(hookCharacter)
        end
        if LocalPlayer.Character then
            hookCharacter(LocalPlayer.Character)
        end

        if not AntiStun.HeartbeatConn then
            AntiStun.HeartbeatConn = RunService.Heartbeat:Connect(function()
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not char or not hum or not hrp or hum.Health <= 0 then return end

                -- Anti Stun State Guard
                if AntiStun.AntiStunEnabled then
                    if hum.PlatformStand then
                        hum.PlatformStand = false
                    end
                    if hum.Sit then
                        local seat = hum.SeatPart
                        if not seat then
                            hum.Sit = false
                        end
                    end
                    local state = hum:GetState()
                    if state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.Ragdoll then
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end
                end

                -- Anti Knockback Velocity Guard
                if AntiStun.AntiKnockbackEnabled then
                    local isOurBoost = rawget(_G, "Vinser_Boosting") 
                        or rawget(_G, "DarlingX_Boosting") 
                        or rawget(_G, "Vinser_GodhumanBoosting")
                        or rawget(_G, "DarlingX_SanguineBoost")

                    if not isOurBoost then
                        local vel = hrp.AssemblyLinearVelocity
                        local horizSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
                        -- Cancel abnormal explosive knockback bursts
                        if horizSpeed > 180 then
                            hrp.AssemblyLinearVelocity = Vector3.new(0, math.clamp(vel.Y, -100, 100), 0)
                        end
                    end
                end
            end)
        end
    else
        if AntiStun.CharAddedConn then
            pcall(function() AntiStun.CharAddedConn:Disconnect() end)
            AntiStun.CharAddedConn = nil
        end
        if AntiStun.HeartbeatConn then
            pcall(function() AntiStun.HeartbeatConn:Disconnect() end)
            AntiStun.HeartbeatConn = nil
        end
        if AntiStun.ChildAddedConn then
            pcall(function() AntiStun.ChildAddedConn:Disconnect() end)
            AntiStun.ChildAddedConn = nil
        end
        if AntiStun.AttrConn then
            pcall(function() AntiStun.AttrConn:Disconnect() end)
            AntiStun.AttrConn = nil
        end
        if AntiStun.HrpChildConn then
            pcall(function() AntiStun.HrpChildConn:Disconnect() end)
            AntiStun.HrpChildConn = nil
        end
        if AntiStun.HrpAttrConn then
            pcall(function() AntiStun.HrpAttrConn:Disconnect() end)
            AntiStun.HrpAttrConn = nil
        end
    end
end

function AntiStun.SetAntiStun(state)
    AntiStun.AntiStunEnabled = (state == true)
    _G.VinsersHub_AntiStun = AntiStun.AntiStunEnabled
    _G.DarlingX_AntiStun = AntiStun.AntiStunEnabled
    checkActiveGating()
end

function AntiStun.SetAntiKnockback(state)
    AntiStun.AntiKnockbackEnabled = (state == true)
    _G.VinsersHub_AntiKnockback = AntiStun.AntiKnockbackEnabled
    _G.DarlingX_AntiKnockback = AntiStun.AntiKnockbackEnabled
    checkActiveGating()
end

return AntiStun
