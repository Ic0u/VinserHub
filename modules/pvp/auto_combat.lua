--[[
    Darling X - Auto Combat Module
    Automated PvP passives: Armament Haki (Buso), Race V3, and Race V4 Awakening.
    Zero emojis, zero third-party references.
    Strict gating: loop only runs while at least one combat passive is enabled.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local AutoCombat = {
    AutoBusoEnabled = false,
    AutoV3Enabled = false,
    AutoV4Enabled = false,

    CombatThread = nil,
}

local function checkLoopGating()
    local needLoop = AutoCombat.AutoBusoEnabled or AutoCombat.AutoV3Enabled or AutoCombat.AutoV4Enabled

    if needLoop and not AutoCombat.CombatThread then
        AutoCombat.CombatThread = task.spawn(function()
            while AutoCombat.AutoBusoEnabled or AutoCombat.AutoV3Enabled or AutoCombat.AutoV4Enabled do
                -- 1. Auto Buso Haki
                if AutoCombat.AutoBusoEnabled then
                    pcall(function()
                        local char = LocalPlayer and LocalPlayer.Character
                        if char and not char:FindFirstChild("HasBuso") then
                            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                            local commF = remotes and (remotes:FindFirstChild("CommF_") or remotes:FindFirstChild("CommF"))
                            if commF then
                                commF:InvokeServer("Buso")
                            end
                        end
                    end)
                end

                -- 2. Auto Race V3
                if AutoCombat.AutoV3Enabled then
                    pcall(function()
                        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                        local commE = remotes and remotes:FindFirstChild("CommE")
                        if commE then
                            commE:FireServer("ActivateAbility")
                        end
                    end)
                end

                -- 3. Auto Race V4 Awakening
                if AutoCombat.AutoV4Enabled then
                    pcall(function()
                        local awk = (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Awakening"))
                            or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Awakening"))
                        if awk and awk:FindFirstChild("RemoteFunction") then
                            awk.RemoteFunction:InvokeServer(true)
                        end
                    end)
                end

                task.wait(1.2)
            end
            AutoCombat.CombatThread = nil
        end)
    elseif not needLoop and AutoCombat.CombatThread then
        pcall(task.cancel, AutoCombat.CombatThread)
        AutoCombat.CombatThread = nil
    end
end

function AutoCombat.SetAutoBuso(state)
    AutoCombat.AutoBusoEnabled = (state == true)
    _G.DarlingX_AutoBuso = AutoCombat.AutoBusoEnabled
    checkLoopGating()
end

function AutoCombat.SetAutoV3(state)
    AutoCombat.AutoV3Enabled = (state == true)
    _G.DarlingX_AutoV3 = AutoCombat.AutoV3Enabled
    checkLoopGating()
end

function AutoCombat.SetAutoV4(state)
    AutoCombat.AutoV4Enabled = (state == true)
    _G.DarlingX_AutoV4 = AutoCombat.AutoV4Enabled
    checkLoopGating()
end

function AutoCombat.ResetAll()
    AutoCombat.SetAutoBuso(false)
    AutoCombat.SetAutoV3(false)
    AutoCombat.SetAutoV4(false)
end

return AutoCombat
