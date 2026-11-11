--[[
    Vinsers Hub | Blox Fruits Edition
    Powered by Linoria UI Library (with ThemeManager & SaveManager)
    Modular Combat, PvP Tech, Mobility, Visuals, Soru, and Automation Suite.
]]

-- ============================================================
-- CORE SERVICES & PLAYER SETUP
-- ============================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local StatsService = game:GetService("Stats")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    local t = os.clock()
    while not LocalPlayer and (os.clock() - t < 5) do
        task.wait(0.1)
        LocalPlayer = Players.LocalPlayer
    end
end

-- ============================================================
-- HUB IDENTITY & GLOBAL STATE
-- ============================================================
local APP_NAME = "Vinser Hub"
local APP_VERSION = "v1.0"
local GITHUB_REPO_RAW = "https://raw.githubusercontent.com/Ic0u/VinserHub/main"

_G.VinsersHub = {
    Name = APP_NAME,
    Version = APP_VERSION,
    Settings = {
        Aim = {
            Priority = "Nearest",
            Mode = "360",
            MaxRange = 1000,
            TargetPart = "HumanoidRootPart",
            Prediction = true,
            PredictionAmount = 0.12
        },
        FOV = {
            Radius = 100,
            Mode = "Center",
            Color = Color3.fromRGB(255, 255, 255)
        },
        Tracers = {
            Type = "Both",
            Origin = "Player",
            Color = Color3.fromRGB(255, 255, 255)
        },
        Blacklist = {
            Melee = {},
            Sword = {},
            Fruit = {},
            Gun = {}
        }
    },
    Require = function(self, path)
        return RequireModule(path)
    end
}

-- Backward compatibility aliases for existing modules
_G.DarlingX = _G.VinsersHub
_G.DarlingHub = _G.VinsersHub
_G.VinsersHub_GetModule = function(path) return RequireModule(path) end
_G.DarlingX_GetModule = function(path) return RequireModule(path) end

if getgenv then
    pcall(function()
        getgenv().VinsersHub = _G.VinsersHub
        getgenv().DarlingX = _G.VinsersHub
        getgenv().DarlingHub = _G.VinsersHub
    end)
end

-- Feature state flags
_G.VinsersHub_IgnoreAllies = true
_G.VinsersHub_IgnorePvPOff = true
_G.VinsersHub_IgnoreSafeZone = true
_G.DarlingX_IgnoreAllies = true
_G.DarlingX_IgnorePvPOff = true
_G.DarlingX_IgnoreSafeZone = true

-- ============================================================
-- MODULE LOADER (Local-First with Remote Fallback)
-- ============================================================
local LoadedModules = {}

local function SafeHttpGet(url)
    local ok, res = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and res and #res > 0 then
        return res
    end
    return nil
end

function RequireModule(relPath)
    if LoadedModules[relPath] then
        return LoadedModules[relPath]
    end

    -- 1. Check local executor disk storage first (dev/offline support)
    local isfileFn = isfile or (syn and syn.isfile)
    local readfileFn = readfile or (syn and syn.readfile)
    if isfileFn and readfileFn then
        local candidatePaths = {
            relPath,
            "VinserHub/" .. relPath,
            "VinsersHub/" .. relPath,
            "DarlingX/" .. relPath,
            "modules/" .. relPath:gsub("^modules/", ""),
            "D-main/" .. relPath,
        }
        for _, path in ipairs(candidatePaths) do
            local okCheck, exists = pcall(isfileFn, path)
            if okCheck and exists then
                local okRead, content = pcall(readfileFn, path)
                if okRead and content and #content > 0 then
                    local okCompile, fn = pcall(loadstring, content)
                    if okCompile and fn then
                        local okRun, result = pcall(fn)
                        if okRun and result then
                            LoadedModules[relPath] = result
                            return result
                        end
                    end
                end
            end
        end
    end

    -- 2. Fresh remote fetch from GitHub repository
    local cacheBuster = tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
    local remoteUrl = GITHUB_REPO_RAW .. "/" .. relPath .. "?t=" .. cacheBuster
    local body = SafeHttpGet(remoteUrl)
    if body and #body > 50 then
        local okCompile, fn = pcall(loadstring, body)
        if okCompile and fn then
            local okRun, result = pcall(fn)
            if okRun and result then
                LoadedModules[relPath] = result
                pcall(function()
                    local makeFolder = makefolder or (syn and syn.makefolder)
                    local writefile = writefile or (syn and syn.writefile)
                    local isfolder = isfolder or (syn and syn.isfolder)
                    if isfolder and makeFolder and not isfolder("VinsersHub") then
                        makeFolder("VinsersHub")
                    end
                    if writefile then
                        writefile("VinsersHub/" .. relPath, body)
                    end
                end)
                return result
            end
        end
    end

    return nil
end

-- Module Quick Accessor Table
local M = {
    get = function(path) return RequireModule(path) end,
    getFastAttack = function() return RequireModule("modules/pvp/fast_attack.lua") end,
    getDragonGun = function() return RequireModule("modules/pvp/dragon_gun_m1.lua") end,
    getGunAura = function() return RequireModule("modules/pvp/gun_aura.lua") end,
    getAntiStun = function() return RequireModule("modules/pvp/anti_stun.lua") end,
    getSanguineBoost = function() return RequireModule("modules/pvp/sanguine_boost.lua") end,
    getGodhumanZ = function() return RequireModule("modules/pvp/godhuman_z_boost.lua") end,
    getExtraWidgets = function() return RequireModule("modules/pvp/extra_widgets.lua") end,
    getAutoCombat = function() return RequireModule("modules/pvp/auto_combat.lua") end,
    getCamlock = function() return RequireModule("modules/pvp/camlock.lua") end,
    getMoveMod = function() return RequireModule("modules/mobility/movement_engine.lua") end,
    getESP = function() return RequireModule("modules/esp/esp_pvp.lua") end,
    getSoru = function() return RequireModule("modules/soru/soru_controller.lua") end,
    getMacro = function() return RequireModule("modules/macro/macro_engine.lua") end,
    getClientTweaks = function() return RequireModule("modules/misc/client_tweaks.lua") end,
}

-- Ensure Core Combat reference is ready for modules
task.spawn(function()
    local core = RequireModule("modules/combat/aimbot_core.lua")
    if core then
        _G.VinsersCombatCore = core
        _G.DarlingCombatCore = core
        if getgenv then
            getgenv().VinsersCombatCore = core
            getgenv().DarlingCombatCore = core
        end
    end
end)

-- ============================================================
-- COMBAT TARGET FILTERING HOOKS
-- ============================================================
local function isPlayerAlly(player)
    if not player or player == LocalPlayer then return false end
    local ok, ally = pcall(function()
        local main = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("Main")
        local frame = main and main:FindFirstChild("Allies")
            and main.Allies:FindFirstChild("Container")
            and main.Allies.Container:FindFirstChild("Allies")
            and main.Allies.Container.Allies:FindFirstChild("ScrollingFrame")
            and main.Allies.Container.Allies.ScrollingFrame:FindFirstChild("Frame")
        if frame and frame:FindFirstChild(player.Name) then return true end

        local myTeam = LocalPlayer and LocalPlayer.Team
        local targetTeam = player.Team
        if myTeam and targetTeam and myTeam == targetTeam then return true end
        if myTeam and targetTeam and myTeam.Name == "Marines" and targetTeam.Name == "Marines" then return true end
        return false
    end)
    return ok and ally
end

local function isPlayerPvPEnabled(player)
    if not player or player == LocalPlayer then return false end
    local ok, enabled = pcall(function()
        if player:GetAttribute("PvpDisabled") == true then return false end
        local char = player.Character
        if char then
            if char:FindFirstChildOfClass("ForceField") then return false end
            if char:GetAttribute("PvpDisabled") == true then return false end
        end
        return true
    end)
    return not ok or enabled
end

local function isPlayerInSafeZone(player)
    if not player or player == LocalPlayer then return false end
    local ok, inZone = pcall(function()
        local char = player.Character
        if not char then return false end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Sit == true then return true end
        if char:FindFirstChildOfClass("ForceField") then return true end
        if char:GetAttribute("SafeZone") == true then return true end
        if player:GetAttribute("SafeZone") == true then return true end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        local hrpPos = hrp.Position

        local function checkFolder(folder)
            if not folder then return false end
            for _, zone in ipairs(folder:GetChildren()) do
                if zone:IsA("BasePart") then
                    local mesh = zone:FindFirstChild("Mesh")
                    local radius = 0
                    if mesh and mesh:IsA("SpecialMesh") then
                        radius = (zone.Size.X * mesh.Scale.X) / 2
                    else
                        radius = math.min(zone.Size.X, zone.Size.Z) / 2
                    end
                    if radius > 500 then radius = 350 end
                    if radius <= 0 then radius = 350 end
                    if (zone.Position - hrpPos).Magnitude <= radius then return true end

                    local localPos = zone.CFrame:PointToObjectSpace(hrpPos)
                    local halfSize = zone.Size / 2
                    if math.abs(localPos.X) <= halfSize.X and math.abs(localPos.Y) <= halfSize.Y + 25 and math.abs(localPos.Z) <= halfSize.Z then
                        return true
                    end
                end
            end
            return false
        end

        local wo = Workspace:FindFirstChild("_WorldOrigin")
        if wo and checkFolder(wo:FindFirstChild("SafeZones")) then return true end
        if wo and checkFolder(wo:FindFirstChild("TempSafeZones")) then return true end
        if checkFolder(Workspace:FindFirstChild("SafeZones")) then return true end
        local map = Workspace:FindFirstChild("Map")
        if map and checkFolder(map:FindFirstChild("SafeZones")) then return true end
        return false
    end)
    return ok and inZone
end

local function hookAimbotTargetFilter()
    pcall(function()
        local core = RequireModule("modules/combat/aimbot_core.lua")
        if core and not core._VinsersFilterHooked then
            core._VinsersFilterHooked = true
            local origBlacklisted = core.isPlayerBlacklisted
            core.isPlayerBlacklisted = function(player)
                if not player then return false end
                if origBlacklisted and origBlacklisted(player) then return true end

                if _G.VinsersHub_IgnoreAllies and isPlayerAlly(player) then
                    return true
                end
                if _G.VinsersHub_IgnorePvPOff and not isPlayerPvPEnabled(player) then
                    return true
                end
                if _G.VinsersHub_IgnoreSafeZone and isPlayerInSafeZone(player) then
                    return true
                end
                return false
            end
        end
    end)
end
task.spawn(hookAimbotTargetFilter)

-- Helper: Format Large Numbers
local function FormatNumber(val)
    local n = tonumber(val) or 0
    if n >= 1e9 then
        return string.format("%.2fB", n / 1e9)
    elseif n >= 1e6 then
        return string.format("%.2fM", n / 1e6)
    elseif n >= 1e3 then
        return string.format("%.1fK", n / 1e3)
    end
    return tostring(n)
end

-- ============================================================
-- LOAD LINORIA UI LIBRARY & MANAGERS
-- ============================================================
local repo = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"

local function fetchRepo(file)
    local urls = {
        repo .. file,
        "https://raw.githubusercontent.com/wally-rblx/LinoriaLib/main/" .. file
    }
    for _, u in ipairs(urls) do
        local ok, content = pcall(game.HttpGet, game, u)
        if ok and content and #content > 0 then
            return content
        end
    end
    error("Failed to fetch Linoria file: " .. file)
end

local Library = loadstring(fetchRepo("Library.lua"))()
local ThemeManager = loadstring(fetchRepo("addons/ThemeManager.lua"))()
local SaveManager = loadstring(fetchRepo("addons/SaveManager.lua"))()

-- ============================================================
-- DYNAMIC WINDOW TITLE RESOLUTION
-- Format: Vinser Hub (executor - version-gitCommit) username / robloxchannel
-- Example: Vinser Hub (Pottasium - version-a2fb906f52d742d233c1) builderman123 / zlive
-- ============================================================
local function GetExecutorName()
    local name = nil
    pcall(function()
        if type(identifyexecutor) == "function" then
            name = identifyexecutor()
        elseif type(getexecutorname) == "function" then
            name = getexecutorname()
        end
    end)
    if name and #tostring(name) > 0 then
        local str = tostring(name):gsub("^%s*(.-)%s*$", "%1")
        return str
    end
    if syn then return "Synapse" end
    if KRNL_LOADED then return "Krnl" end
    if fluxus then return "Fluxus" end
    if is_sirhurt_closure then return "Sirhurt" end
    if shadow then return "Shadow" end
    if delta then return "Delta" end
    if codex then return "Codex" end
    if arceus then return "Arceus" end
    return "Pottasium"
end

local function GetRobloxChannel()
    local channel = nil
    pcall(function()
        if RunService.GetRobloxChannel then
            channel = RunService:GetRobloxChannel()
        end
    end)
    if channel and #tostring(channel) > 0 and tostring(channel):lower() ~= "unknown" then
        return tostring(channel):lower()
    end
    return "zlive"
end

local function GetGitVersion()
    local gitVer = "a2fb906f52d742d233c1"
    pcall(function()
        local raw = game:HttpGet("https://api.github.com/repos/Ic0u/VinserHub/commits/main")
        if raw and #raw > 0 then
            local data = HttpService:JSONDecode(raw)
            if data and data.sha then
                gitVer = tostring(data.sha):sub(1, 20)
            end
        end
    end)
    return gitVer
end

local function GetUsername()
    local name = LocalPlayer and LocalPlayer.Name
    if not name or #tostring(name) == 0 then
        name = "builderman123"
    end
    return tostring(name)
end

local CurrentExecutor = GetExecutorName()
local CurrentGitVersion = GetGitVersion()

-- Format: Vinser Hub (executor - version-gitCommit) stripped down player name & channel to prevent overflow
local WINDOW_TITLE = string.format("Vinser Hub (%s - version-%s)", CurrentExecutor, CurrentGitVersion)

-- Create Window
local Window = Library:CreateWindow({
    Title = WINDOW_TITLE,
    Center = true,
    AutoShow = true,
    TabPadding = 5,
    MenuFadeTime = 0.2
})

-- Navigation Tabs
local Tabs = {
    Dashboard = Window:AddTab("Dashboard"),
    Combat = Window:AddTab("Combat"),
    PvP = Window:AddTab("PvP & Tech"),
    Movement = Window:AddTab("Movement"),
    Visuals = Window:AddTab("Visuals"),
    Soru = Window:AddTab("Soru"),
    Macro = Window:AddTab("Macro"),
    Misc = Window:AddTab("Misc"),
    ["UI Settings"] = Window:AddTab("UI Settings"),
}

-- Synchronize Camlock UI if changed outside the menu
_G.DarlingX_SyncCamlockUI = function(state)
    if Toggles and Toggles.Camlock and Toggles.Camlock.Value ~= state then
        Toggles.Camlock:SetValue(state)
    end
end
_G.VinsersHub_SyncCamlockUI = _G.DarlingX_SyncCamlockUI

-- ============================================================
-- TAB 1: DASHBOARD
-- ============================================================
local ProfileBox = Tabs.Dashboard:AddLeftGroupbox("Player Profile")

local PlayerNameLabel = ProfileBox:AddLabel(LocalPlayer and (LocalPlayer.DisplayName .. " (@" .. LocalPlayer.Name .. ")") or "Player")
local AccountAgeLabel = ProfileBox:AddLabel("Account: " .. (LocalPlayer and tostring(LocalPlayer.AccountAge) .. " days" or "--") .. " | UID: " .. (LocalPlayer and tostring(LocalPlayer.UserId) or "0"))
ProfileBox:AddDivider()

local LevelLabel = ProfileBox:AddLabel("Level: --")
local BeliLabel = ProfileBox:AddLabel("Beli: --")
local BountyLabel = ProfileBox:AddLabel("Bounty: --")
local FruitLabel = ProfileBox:AddLabel("Devil Fruit: None")
local RaceLabel = ProfileBox:AddLabel("Race: --")
local TeamLabel = ProfileBox:AddLabel("Faction: --")

local TelemetryBox = Tabs.Dashboard:AddLeftGroupbox("Server & Telemetry")
local PingLabel = TelemetryBox:AddLabel("Ping: 0 ms")
local FPSLabel = TelemetryBox:AddLabel("FPS: 60")
local PlayersLabel = TelemetryBox:AddLabel("Players: 0/0")
local UptimeLabel = TelemetryBox:AddLabel("Server Uptime: 0m 0s")
TelemetryBox:AddDivider()

TelemetryBox:AddButton({
    Text = "Copy Server JobId",
    Func = function()
        pcall(function()
            if setclipboard then
                setclipboard(tostring(game.JobId))
                Library:Notify("JobId copied to clipboard!", 3)
            end
        end)
    end
})

TelemetryBox:AddButton({
    Text = "Rejoin Server",
    Func = function()
        if #Players:GetPlayers() <= 1 then
            LocalPlayer:Kick("\nRejoining current server...")
            task.wait()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        else
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end
    end
})

local QuickBox = Tabs.Dashboard:AddRightGroupbox("Quick Combat & Movement")

QuickBox:AddToggle("QuickFastAttack", {
    Text = "Fast Attack",
    Default = false,
    Tooltip = "High-speed weapon hit bursts",
    Callback = function(Value)
        _G.VinsersHub_FastAttack = Value
        _G.DarlingX_FastAttack = Value
        local fa = M.getFastAttack()
        if fa then if Value then fa.enable() else fa.disable() end end
        if Toggles.FastAttack and Toggles.FastAttack.Value ~= Value then
            Toggles.FastAttack:SetValue(Value)
        end
    end
})

QuickBox:AddToggle("QuickCamlock", {
    Text = "Camlock",
    Default = false,
    Tooltip = "Lock camera directly onto enemy player",
    Callback = function(Value)
        local cl = M.getCamlock()
        if cl then cl.SetEnabled(Value) end
        if Toggles.Camlock and Toggles.Camlock.Value ~= Value then
            Toggles.Camlock:SetValue(Value)
        end
    end
})

QuickBox:AddToggle("QuickDragonM1", {
    Text = "Dragon Gun M1",
    Default = false,
    Tooltip = "Rapid fire M1 gun shots",
    Callback = function(Value)
        _G.VinsersHub_DragonM1Enabled = Value
        _G.DarlingX_DragonM1Enabled = Value
        local dg = M.getDragonGun()
        local ew = M.getExtraWidgets()
        if dg then dg.SetEnabled(Value) end
        if ew then
            ew.SetDragonM1WidgetVisible(Value)
            ew.UpdateDragonM1Visual(Value)
        end
        if Toggles.DragonGunM1 and Toggles.DragonGunM1.Value ~= Value then
            Toggles.DragonGunM1:SetValue(Value)
        end
    end
})

QuickBox:AddToggle("QuickSanguineBoost", {
    Text = "Sanguine Boost",
    Default = false,
    Tooltip = "Forward velocity impulse dash",
    Callback = function(Value)
        _G.VinsersHub_SanguineBoost = Value
        _G.DarlingX_SanguineBoost = Value
        local sb = M.getSanguineBoost()
        local ew = M.getExtraWidgets()
        if sb then sb.SetEnabled(Value) end
        if ew then ew.SetSanguineWidgetVisible(Value) end
        if Toggles.SanguineBoost and Toggles.SanguineBoost.Value ~= Value then
            Toggles.SanguineBoost:SetValue(Value)
        end
    end
})

QuickBox:AddToggle("QuickGodhumanZ", {
    Text = "Godhuman Z Glitch",
    Default = false,
    Tooltip = "Godhuman Z momentum launch & swap-cancel glitch",
    Callback = function(Value)
        local gz = M.getGodhumanZ()
        if gz then gz.SetEnabled(Value) end
        if Toggles.GodhumanZBoost and Toggles.GodhumanZBoost.Value ~= Value then
            Toggles.GodhumanZBoost:SetValue(Value)
        end
    end
})

QuickBox:AddToggle("QuickAntiStun", {
    Text = "Anti Stun",
    Default = false,
    Tooltip = "Clears stun objects, unfreezes character, and cancels knockback",
    Callback = function(Value)
        local as = M.getAntiStun()
        if as then
            as.SetAntiStun(Value)
            as.SetAntiKnockback(Value)
        end
        if Toggles.AntiStun and Toggles.AntiStun.Value ~= Value then
            Toggles.AntiStun:SetValue(Value)
        end
        if Toggles.AntiKnockback and Toggles.AntiKnockback.Value ~= Value then
            Toggles.AntiKnockback:SetValue(Value)
        end
    end
})

QuickBox:AddToggle("QuickSoulGuitarDash", {
    Text = "Soul Guitar Dash Glitch",
    Default = false,
    Tooltip = "Sets DashLength to 121 studs for infinite distance dashes",
    Callback = function(Value)
        local mm = M.getMoveMod()
        if mm and mm.SetSoulGuitarDash then mm.SetSoulGuitarDash(Value) end
        if Toggles.SoulGuitarDash and Toggles.SoulGuitarDash.Value ~= Value then
            Toggles.SoulGuitarDash:SetValue(Value)
        end
    end
})

QuickBox:AddToggle("QuickSuperJump", {
    Text = "Super Jump",
    Default = false,
    Tooltip = "High jump leap impulse",
    Callback = function(Value)
        local mm = M.getMoveMod()
        if mm then mm.SetSuperJump(Value) end
        if Toggles.SuperJump and Toggles.SuperJump.Value ~= Value then
            Toggles.SuperJump:SetValue(Value)
        end
    end
})

QuickBox:AddToggle("QuickWalkSpeed", {
    Text = "Custom WalkSpeed",
    Default = false,
    Tooltip = "Speed up player movement",
    Callback = function(Value)
        local mm = M.getMoveMod()
        if mm then mm.SetWalkSpeed(Value) end
        if Toggles.CustomWalkSpeed and Toggles.CustomWalkSpeed.Value ~= Value then
            Toggles.CustomWalkSpeed:SetValue(Value)
        end
    end
})

QuickBox:AddToggle("QuickFFlags", {
    Text = "FFlags 1 (FPS Booster)",
    Default = false,
    Tooltip = "120 FPS cap, smooth plastic textures, removes fog, hides debris",
    Callback = function(Value)
        local ct = M.getClientTweaks()
        if ct then ct.SetFFlags1(Value) end
        if Toggles.FFlags1 and Toggles.FFlags1.Value ~= Value then
            Toggles.FFlags1:SetValue(Value)
        end
    end
})

-- ============================================================
-- TAB 2: COMBAT (SILENT AIM, FOV, TRACERS, BLACKLIST)
-- ============================================================
local SilentAimBox = Tabs.Combat:AddLeftGroupbox("Silent Aim Engine")

SilentAimBox:AddToggle("PlayerSilentAim", {
    Text = "Player Silent Aim",
    Default = false,
    Tooltip = "Redirects weapon and fruit attacks toward enemy players",
    Callback = function(Value)
        local mod = RequireModule("modules/combat/player_aimbot.lua")
        if mod then if Value then mod.enable() else mod.disable() end end
        Library:Notify("Player Silent Aim: " .. (Value and "Enabled" or "Disabled"), 2)
    end
})

SilentAimBox:AddToggle("NPCSilentAim", {
    Text = "NPC Silent Aim",
    Default = false,
    Tooltip = "Redirects attacks toward nearby mobs and raid bosses",
    Callback = function(Value)
        local mod = RequireModule("modules/combat/npc_aimbot.lua")
        if mod then if Value then mod.enable() else mod.disable() end end
        Library:Notify("NPC Silent Aim: " .. (Value and "Enabled" or "Disabled"), 2)
    end
})

SilentAimBox:AddToggle("ShowFOV", {
    Text = "Show FOV Circle",
    Default = false,
    Tooltip = "Display aim boundary circle on screen",
    Callback = function(Value)
        local fovMod = RequireModule("modules/combat/fov.lua")
        if fovMod then if Value then fovMod.enable() else fovMod.disable() end end
    end
})

SilentAimBox:AddToggle("IgnoreAllies", {
    Text = "Ignore Allies / Crew",
    Default = true,
    Tooltip = "Do not target crew or faction allies",
    Callback = function(Value)
        _G.VinsersHub_IgnoreAllies = Value
        _G.DarlingX_IgnoreAllies = Value
        hookAimbotTargetFilter()
    end
})

SilentAimBox:AddToggle("IgnorePvPOff", {
    Text = "Ignore PvP Disabled",
    Default = true,
    Tooltip = "Do not target players with PvP mode turned off",
    Callback = function(Value)
        _G.VinsersHub_IgnorePvPOff = Value
        _G.DarlingX_IgnorePvPOff = Value
        hookAimbotTargetFilter()
    end
})

SilentAimBox:AddToggle("IgnoreSafeZone", {
    Text = "Ignore Safe Zone",
    Default = true,
    Tooltip = "Do not target players resting inside safe zones",
    Callback = function(Value)
        _G.VinsersHub_IgnoreSafeZone = Value
        _G.DarlingX_IgnoreSafeZone = Value
        hookAimbotTargetFilter()
    end
})

SilentAimBox:AddDropdown("TargetPriority", {
    Values = { "Nearest", "Low HP", "Looking At Me" },
    Default = 1,
    Multi = false,
    Text = "Target Priority",
    Callback = function(Value)
        local core = RequireModule("modules/combat/aimbot_core.lua")
        if core then core.TargetPriority = Value end
        _G.VinsersHub.Settings.Aim.Priority = Value
    end
})

SilentAimBox:AddDropdown("AimMode", {
    Values = { "360", "FOV", "180" },
    Default = 1,
    Multi = false,
    Text = "Aim Mode",
    Callback = function(Value)
        local core = RequireModule("modules/combat/aimbot_core.lua")
        if core then core.AimMode = Value end
        _G.VinsersHub.Settings.Aim.Mode = Value
        local fovMod = RequireModule("modules/combat/fov.lua")
        if fovMod and fovMod.setAimMode then fovMod.setAimMode(Value) end
    end
})

SilentAimBox:AddDropdown("TargetHitbox", {
    Values = { "HumanoidRootPart", "Head", "UpperTorso" },
    Default = 1,
    Multi = false,
    Text = "Target Hitbox",
    Callback = function(Value)
        local core = RequireModule("modules/combat/aimbot_core.lua")
        if core then
            core.TargetHitbox = Value
            core.TargetPart = Value
        end
        _G.VinsersHub.Settings.Aim.TargetPart = Value
    end
})

SilentAimBox:AddSlider("MaxRange", {
    Text = "Max Aim Range",
    Default = 1000,
    Min = 100,
    Max = 3000,
    Rounding = 0,
    Callback = function(Value)
        local core = RequireModule("modules/combat/aimbot_core.lua")
        if core then core.MaxRange = Value end
        _G.VinsersHub.Settings.Aim.MaxRange = Value
    end
})

SilentAimBox:AddToggle("TargetPrediction", {
    Text = "Target Velocity Prediction",
    Default = true,
    Tooltip = "Calculates lead trajectory vector based on velocity and network ping",
    Callback = function(Value)
        local core = RequireModule("modules/combat/aimbot_core.lua")
        if core then core.PredictionEnabled = Value end
        _G.VinsersHub.Settings.Aim.Prediction = Value
    end
})

SilentAimBox:AddSlider("PredictionAmount", {
    Text = "Prediction Amount",
    Default = 12,
    Min = 5,
    Max = 30,
    Rounding = 0,
    Callback = function(Value)
        local core = RequireModule("modules/combat/aimbot_core.lua")
        local factor = Value / 100
        if core then core.PredictionAmount = factor end
        _G.VinsersHub.Settings.Aim.PredictionAmount = factor
    end
})

local FOVBox = Tabs.Combat:AddRightGroupbox("Field of View (FOV)")

FOVBox:AddSlider("FOVRadius", {
    Text = "FOV Radius",
    Default = 100,
    Min = 20,
    Max = 600,
    Rounding = 0,
    Callback = function(Value)
        local fovMod = RequireModule("modules/combat/fov.lua")
        if fovMod and fovMod.setRadius then fovMod.setRadius(Value) end
        local core = RequireModule("modules/combat/aimbot_core.lua")
        if core and core.setFOVRadius then core.setFOVRadius(Value) end
        _G.VinsersHub.Settings.FOV.Radius = Value
    end
})

FOVBox:AddDropdown("FOVPosition", {
    Values = { "Center", "Mouse" },
    Default = 1,
    Multi = false,
    Text = "FOV Position",
    Callback = function(Value)
        local fovMod = RequireModule("modules/combat/fov.lua")
        if fovMod and fovMod.setMode then fovMod.setMode(Value) end
        _G.VinsersHub.Settings.FOV.Mode = Value
    end
})

FOVBox:AddSlider("FOVThickness", {
    Text = "Circle Thickness",
    Default = 2,
    Min = 1,
    Max = 8,
    Rounding = 0,
    Callback = function(Value)
        local fovMod = RequireModule("modules/combat/fov.lua")
        if fovMod and fovMod.setThickness then fovMod.setThickness(Value) end
    end
})

FOVBox:AddToggle("RainbowFOV", {
    Text = "Rainbow Chroma Mode",
    Default = false,
    Callback = function(Value)
        local fovMod = RequireModule("modules/combat/fov.lua")
        if fovMod and fovMod.setRainbow then fovMod.setRainbow(Value) end
    end
})

FOVBox:AddLabel("FOV Color"):AddColorPicker("FOVColorPicker", {
    Default = Color3.fromRGB(255, 255, 255),
    Title = "FOV Color",
    Callback = function(Value)
        local fovMod = RequireModule("modules/combat/fov.lua")
        if fovMod and fovMod.setColor then fovMod.setColor(Value) end
        _G.VinsersHub.Settings.FOV.Color = Value
    end
})

local TracersBox = Tabs.Combat:AddRightGroupbox("Hardware Tracers")

TracersBox:AddToggle("ShowTracers", {
    Text = "Enable Tracers",
    Default = false,
    Tooltip = "Renders hardware 3D Beams and 2D lines to locked target",
    Callback = function(Value)
        local mod = RequireModule("modules/combat/tracers.lua")
        if mod then if Value then mod.enable() else mod.disable() end end
        Library:Notify("Tracers: " .. (Value and "Enabled" or "Disabled"), 2)
    end
})

TracersBox:AddDropdown("TracerMode", {
    Values = { "Both", "3D Beam", "2D Line" },
    Default = 1,
    Multi = false,
    Text = "Tracer Mode",
    Callback = function(Value)
        local mod = RequireModule("modules/combat/tracers.lua")
        if mod and mod.setType then mod.setType(Value) end
        _G.VinsersHub.Settings.Tracers.Type = Value
    end
})

TracersBox:AddDropdown("TracerOrigin", {
    Values = { "Player", "Bottom", "Center", "Mouse" },
    Default = 1,
    Multi = false,
    Text = "Tracer Origin",
    Callback = function(Value)
        local mod = RequireModule("modules/combat/tracers.lua")
        if mod and mod.setOrigin then mod.setOrigin(Value) end
        _G.VinsersHub.Settings.Tracers.Origin = Value
    end
})

TracersBox:AddSlider("TracerThickness", {
    Text = "Tracer Thickness",
    Default = 2,
    Min = 1,
    Max = 6,
    Rounding = 0,
    Callback = function(Value)
        local mod = RequireModule("modules/combat/tracers.lua")
        if mod and mod.setThickness then mod.setThickness(Value) end
    end
})

TracersBox:AddToggle("RainbowTracers", {
    Text = "Rainbow Tracers",
    Default = false,
    Callback = function(Value)
        local mod = RequireModule("modules/combat/tracers.lua")
        if mod and mod.setRainbow then mod.setRainbow(Value) end
    end
})

TracersBox:AddLabel("Tracer Color"):AddColorPicker("TracerColorPicker", {
    Default = Color3.fromRGB(255, 255, 255),
    Title = "Tracer Color",
    Callback = function(Value)
        local mod = RequireModule("modules/combat/tracers.lua")
        if mod and mod.setColor then mod.setColor(Value) end
        _G.VinsersHub.Settings.Tracers.Color = Value
    end
})

local BlacklistBox = Tabs.Combat:AddLeftGroupbox("Skill Blacklist")

BlacklistBox:AddDropdown("BLMelee", {
    Values = { "Z", "X", "C" },
    Default = {},
    Multi = true,
    Text = "Exclude Melee Skills",
    Tooltip = "Selected skills will bypass Silent Aim redirection",
    Callback = function(Values)
        local bl = RequireModule("modules/combat/blacklist.lua")
        if bl then
            for _, k in ipairs({ "Z", "X", "C" }) do
                if Values[k] then bl.add("Melee", k) else bl.remove("Melee", k) end
            end
        end
    end
})

BlacklistBox:AddDropdown("BLSword", {
    Values = { "Z", "X" },
    Default = {},
    Multi = true,
    Text = "Exclude Sword Skills",
    Callback = function(Values)
        local bl = RequireModule("modules/combat/blacklist.lua")
        if bl then
            for _, k in ipairs({ "Z", "X" }) do
                if Values[k] then bl.add("Sword", k) else bl.remove("Sword", k) end
            end
        end
    end
})

BlacklistBox:AddDropdown("BLFruit", {
    Values = { "Z", "X", "C", "V", "F", "TAP" },
    Default = {},
    Multi = true,
    Text = "Exclude Fruit Skills",
    Callback = function(Values)
        local bl = RequireModule("modules/combat/blacklist.lua")
        if bl then
            for _, k in ipairs({ "Z", "X", "C", "V", "F", "TAP" }) do
                if Values[k] then bl.add("Fruit", k) else bl.remove("Fruit", k) end
            end
        end
    end
})

BlacklistBox:AddDropdown("BLGun", {
    Values = { "Z", "X" },
    Default = {},
    Multi = true,
    Text = "Exclude Gun Skills",
    Callback = function(Values)
        local bl = RequireModule("modules/combat/blacklist.lua")
        if bl then
            for _, k in ipairs({ "Z", "X" }) do
                if Values[k] then bl.add("Gun", k) else bl.remove("Gun", k) end
            end
        end
    end
})

-- ============================================================
-- TAB 3: PVP & TECH
-- ============================================================
local AutoCombatBox = Tabs.PvP:AddLeftGroupbox("Auto Combat")

AutoCombatBox:AddToggle("FastAttack", {
    Text = "Fast Attack (Burst M1)",
    Default = false,
    Tooltip = "Rapid weapon and melee strike bursts",
    Callback = function(Value)
        _G.VinsersHub_FastAttack = Value
        _G.DarlingX_FastAttack = Value
        local fa = M.getFastAttack()
        if fa then if Value then fa.enable() else fa.disable() end end
        if Toggles.QuickFastAttack and Toggles.QuickFastAttack.Value ~= Value then
            Toggles.QuickFastAttack:SetValue(Value)
        end
        Library:Notify("Fast Attack: " .. (Value and "Enabled" or "Disabled"), 2)
    end
})

AutoCombatBox:AddToggle("AutoBuso", {
    Text = "Auto Buso Haki",
    Default = false,
    Tooltip = "Maintains Armament Haki permanently active",
    Callback = function(Value)
        local ac = M.getAutoCombat()
        if ac then ac.SetAutoBuso(Value) end
        Library:Notify("Auto Buso: " .. (Value and "Enabled" or "Disabled"), 2)
    end
})

AutoCombatBox:AddToggle("AutoV3", {
    Text = "Auto Race V3",
    Default = false,
    Tooltip = "Automatically activates Race V3 skill in combat",
    Callback = function(Value)
        local ac = M.getAutoCombat()
        if ac then ac.SetAutoV3(Value) end
        Library:Notify("Auto Race V3: " .. (Value and "Enabled" or "Disabled"), 2)
    end
})

AutoCombatBox:AddToggle("AutoV4", {
    Text = "Auto Race V4 Awakening",
    Default = false,
    Tooltip = "Triggers Race V4 awakening instantly when gauge is full",
    Callback = function(Value)
        local ac = M.getAutoCombat()
        if ac then ac.SetAutoV4(Value) end
        Library:Notify("Auto Race V4: " .. (Value and "Enabled" or "Disabled"), 2)
    end
})

AutoCombatBox:AddToggle("AntiStun", {
    Text = "Anti Stun",
    Default = false,
    Tooltip = "Instantly clears stun objects, attributes, and unfreezes character",
    Callback = function(Value)
        local as = M.getAntiStun()
        if as then as.SetAntiStun(Value) end
        if Toggles.QuickAntiStun and Toggles.QuickAntiStun.Value ~= Value then
            Toggles.QuickAntiStun:SetValue(Value)
        end
        Library:Notify("Anti Stun: " .. (Value and "Enabled" or "Disabled"), 2)
    end
})

AutoCombatBox:AddToggle("AntiKnockback", {
    Text = "Anti Knockback",
    Default = false,
    Tooltip = "Cancels hostile BodyVelocity, LinearVelocity, and explosive knockback bursts",
    Callback = function(Value)
        local as = M.getAntiStun()
        if as then as.SetAntiKnockback(Value) end
        Library:Notify("Anti Knockback: " .. (Value and "Enabled" or "Disabled"), 2)
    end
})

local GunAuraBox = Tabs.PvP:AddLeftGroupbox("M1 Gun Aura Engine")

local GunAuraToggle = GunAuraBox:AddToggle("GunAuraEnabled", {
    Text = "M1 Gun Aura",
    Default = false,
    Tooltip = "Rapid auto gunfire at nearest enemies / players (High speed zero lag)",
    Callback = function(Value)
        local ga = M.getGunAura()
        if ga then ga.SetEnabled(Value) end
        if Toggles.DragonGunM1 and Toggles.DragonGunM1.Value ~= Value then
            Toggles.DragonGunM1:SetValue(Value)
        end
        Library:Notify("M1 Gun Aura: " .. (Value and "Enabled" or "Disabled"), 2)
    end
})

GunAuraToggle:AddKeyPicker("GunAuraKeybind", {
    Default = "G",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Gun Aura Keybind",
    Callback = function()
        local ga = M.getGunAura()
        if ga then
            ga.SetEnabled(not ga.Enabled)
            Toggles.GunAuraEnabled:SetValue(ga.Enabled)
        end
    end
})

GunAuraBox:AddDropdown("GunAuraTarget", {
    Values = { "Both", "Players", "Enemies" },
    Default = 1,
    Multi = false,
    Text = "Target Selection",
    Callback = function(Value)
        local ga = M.getGunAura()
        if ga then ga.SetTargetMode(Value) end
    end
})

GunAuraBox:AddSlider("GunAuraRange", {
    Text = "Max Range (Studs)",
    Default = 350,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        local ga = M.getGunAura()
        if ga then ga.SetRange(Value) end
    end
})

GunAuraBox:AddSlider("GunAuraShots", {
    Text = "Shots Per Frame",
    Default = 2,
    Min = 1,
    Max = 5,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        local ga = M.getGunAura()
        if ga then ga.SetShotsPerFrame(Value) end
    end
})

GunAuraBox:AddToggle("GunAuraAutoEquip", {
    Text = "Auto-Equip Gun",
    Default = true,
    Tooltip = "Automatically equips any gun from Backpack if not holding one",
    Callback = function(Value)
        local ga = M.getGunAura()
        if ga then ga.SetAutoEquip(Value) end
    end
})

AutoCombatBox:AddToggle("DragonGunM1", {
    Text = "Dragon Gun M1",
    Default = false,
    Tooltip = "Rapid fire M1 gun shots",
    Callback = function(Value)
        _G.VinsersHub_DragonM1Enabled = Value
        _G.DarlingX_DragonM1Enabled = Value
        local dg = M.getDragonGun()
        local ew = M.getExtraWidgets()
        if dg then dg.SetEnabled(Value) end
        if ew then
            ew.SetDragonM1WidgetVisible(Value)
            ew.UpdateDragonM1Visual(Value)
        end
        if Toggles.QuickDragonM1 and Toggles.QuickDragonM1.Value ~= Value then
            Toggles.QuickDragonM1:SetValue(Value)
        end
        Library:Notify("Dragon Gun M1: " .. (Value and "Enabled" or "Disabled"), 2)
    end
})

local CamlockTechBox = Tabs.PvP:AddRightGroupbox("Camlock & Combat Tech")

local CamlockToggle = CamlockTechBox:AddToggle("Camlock", {
    Text = "Camlock",
    Default = false,
    Tooltip = "Locks camera smoothly onto enemy character",
    Callback = function(Value)
        local cl = M.getCamlock()
        if cl then cl.SetEnabled(Value) end
        if Toggles.QuickCamlock and Toggles.QuickCamlock.Value ~= Value then
            Toggles.QuickCamlock:SetValue(Value)
        end
    end
})

CamlockToggle:AddKeyPicker("CamlockKeybind", {
    Default = "C",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Camlock Keybind",
    Callback = function()
        local cl = M.getCamlock()
        if cl and cl.Toggle then cl.Toggle() end
    end
})

CamlockTechBox:AddSlider("CameraFOV", {
    Text = "Camera FOV",
    Default = 70,
    Min = 70,
    Max = 120,
    Rounding = 0,
    Callback = function(Value)
        local cl = M.getCamlock()
        if cl then cl.SetCameraFOV(Value) end
    end
})

local SanguineToggle = CamlockTechBox:AddToggle("SanguineBoost", {
    Text = "Sanguine Boost",
    Default = false,
    Tooltip = "Forward velocity impulse boost",
    Callback = function(Value)
        _G.VinsersHub_SanguineBoost = Value
        _G.DarlingX_SanguineBoost = Value
        local sb = M.getSanguineBoost()
        local ew = M.getExtraWidgets()
        if sb then sb.SetEnabled(Value) end
        if ew then ew.SetSanguineWidgetVisible(Value) end
        if Toggles.QuickSanguineBoost and Toggles.QuickSanguineBoost.Value ~= Value then
            Toggles.QuickSanguineBoost:SetValue(Value)
        end
        Library:Notify("Sanguine Boost: " .. (Value and "Active" or "Inactive"), 2)
    end
})

SanguineToggle:AddKeyPicker("SanguineKeybind", {
    Default = "Z",
    SyncToggleState = false,
    Mode = "Press",
    Text = "Sanguine Keybind",
    Callback = function()
        local sb = M.getSanguineBoost()
        if sb and sb.Trigger then sb.Trigger() end
    end
})

CamlockTechBox:AddButton({
    Text = "Trigger Sanguine Boost",
    Func = function()
        local sb = M.getSanguineBoost()
        if sb and sb.Trigger then sb.Trigger() end
    end
})

CamlockTechBox:AddDivider()

local GodhumanZToggle = CamlockTechBox:AddToggle("GodhumanZBoost", {
    Text = "Godhuman Z Glitch / Boost",
    Default = false,
    Tooltip = "Automates Godhuman Z Soaring Beast momentum launch & swap-cancel glitch",
    Callback = function(Value)
        local gz = M.getGodhumanZ()
        if gz then gz.SetEnabled(Value) end
        if Toggles.QuickGodhumanZ and Toggles.QuickGodhumanZ.Value ~= Value then
            Toggles.QuickGodhumanZ:SetValue(Value)
        end
        Library:Notify("Godhuman Z Glitch: " .. (Value and "Active" or "Inactive"), 2)
    end
})

GodhumanZToggle:AddKeyPicker("GodhumanZKeybind", {
    Default = "Z",
    SyncToggleState = false,
    Mode = "Press",
    Text = "Godhuman Z Keybind",
    Callback = function()
        local gz = M.getGodhumanZ()
        if gz and gz.Enabled then gz.Trigger() end
    end
})

CamlockTechBox:AddDropdown("GodhumanZCancel", {
    Values = { "Auto", "Fruit", "Sword", "Gun", "Slot 2" },
    Default = 1,
    Multi = false,
    Text = "Swap Cancel Weapon",
    Tooltip = "Switches to this tool to cancel move end-lag and activate flight",
    Callback = function(Value)
        local gz = M.getGodhumanZ()
        if gz then gz.SetCancelWeapon(Value) end
    end
})

CamlockTechBox:AddToggle("GodhumanZSkyPitch", {
    Text = "Auto Sky Arc (+35° Pitch)",
    Default = true,
    Tooltip = "Elevates trajectory upward to glide cleanly across ocean waters",
    Callback = function(Value)
        local gz = M.getGodhumanZ()
        if gz then gz.SetAutoPitch(Value) end
    end
})

CamlockTechBox:AddToggle("GodhumanZSwitchBack", {
    Text = "Re-Equip Godhuman Upon Landing",
    Default = false,
    Tooltip = "Automatically switches back to Godhuman after the glide ends",
    Callback = function(Value)
        local gz = M.getGodhumanZ()
        if gz then gz.SetSwitchBack(Value) end
    end
})

CamlockTechBox:AddToggle("GodhumanZAimlock", {
    Text = "Godhuman Z Aimlock Snap",
    Default = true,
    Tooltip = "Snaps camera directly onto nearest enemy during Z launch and auto-releases on hit damage",
    Callback = function(Value)
        local gz = M.getGodhumanZ()
        if gz and gz.SetAimlock then gz.SetAimlock(Value) end
    end
})

CamlockTechBox:AddToggle("GodhumanZTargetInfo", {
    Text = "Target Health HUD",
    Default = false,
    Tooltip = "Displays top-center target name and HP bar for the locked enemy",
    Callback = function(Value)
        local gz = M.getGodhumanZ()
        if gz and gz.SetTargetInfo then gz.SetTargetInfo(Value) end
    end
})

CamlockTechBox:AddSlider("GodhumanZPower", {
    Text = "Launch Power / Speed",
    Default = 650,
    Min = 200,
    Max = 1500,
    Rounding = 25,
    Callback = function(Value)
        local gz = M.getGodhumanZ()
        if gz then gz.SetPower(Value) end
    end
})

CamlockTechBox:AddSlider("GodhumanZDuration", {
    Text = "Glide Duration (s)",
    Default = 1.2,
    Min = 0.3,
    Max = 3.0,
    Rounding = 0.1,
    Callback = function(Value)
        local gz = M.getGodhumanZ()
        if gz then gz.SetDuration(Value) end
    end
})

CamlockTechBox:AddButton({
    Text = "Trigger Godhuman Z Bug (Launch)",
    Func = function()
        local gz = M.getGodhumanZ()
        if gz then gz.Trigger() end
    end
})

CamlockTechBox:AddToggle("FloatingWidgets", {
    Text = "Show Mobile Floating Widgets",
    Default = false,
    Tooltip = "Draggable on-screen touch buttons for Camlock, Dragon Gun, Sanguine, and Super Jump",
    Callback = function(Value)
        local ew = M.getExtraWidgets()
        if ew then
            ew.SetCamlockWidgetVisible(Value)
            ew.SetDragonM1WidgetVisible(Value)
            ew.SetSanguineWidgetVisible(Value)
            ew.SetSuperJumpWidgetVisible(Value)
        end
    end
})

-- ============================================================
-- TAB 4: MOVEMENT & AGILITY
-- ============================================================
local SpeedBox = Tabs.Movement:AddLeftGroupbox("Speed & Jump Physics")

SpeedBox:AddToggle("CustomWalkSpeed", {
    Text = "Custom WalkSpeed",
    Default = false,
    Callback = function(Value)
        local mm = M.getMoveMod()
        if mm then mm.SetWalkSpeed(Value) end
        if Toggles.QuickWalkSpeed and Toggles.QuickWalkSpeed.Value ~= Value then
            Toggles.QuickWalkSpeed:SetValue(Value)
        end
    end
})

SpeedBox:AddSlider("WalkSpeedValue", {
    Text = "WalkSpeed Value",
    Default = 150,
    Min = 16,
    Max = 500,
    Rounding = 0,
    Callback = function(Value)
        local mm = M.getMoveMod()
        if mm then mm.SetWalkSpeedValue(Value) end
    end
})

SpeedBox:AddToggle("CustomDashLength", {
    Text = "Custom Dash Length",
    Default = false,
    Callback = function(Value)
        local mm = M.getMoveMod()
        if mm then mm.SetDashLength(Value) end
    end
})

SpeedBox:AddSlider("DashDistance", {
    Text = "Dash Distance",
    Default = 30,
    Min = 15,
    Max = 150,
    Rounding = 0,
    Callback = function(Value)
        local mm = M.getMoveMod()
        if mm then mm.SetDashDistance(Value) end
    end
})

SpeedBox:AddToggle("SoulGuitarDash", {
    Text = "Soul Guitar Dash Glitch",
    Default = false,
    Tooltip = "Bypasses dash physics and sets DashLength to 121 studs for infinite distance dashes",
    Callback = function(Value)
        local mm = M.getMoveMod()
        if mm and mm.SetSoulGuitarDash then mm.SetSoulGuitarDash(Value) end
        if Toggles.QuickSoulGuitarDash and Toggles.QuickSoulGuitarDash.Value ~= Value then
            Toggles.QuickSoulGuitarDash:SetValue(Value)
        end
        Library:Notify("Soul Guitar Dash Glitch: " .. (Value and "Active" or "Inactive"), 2)
    end
})

SpeedBox:AddToggle("SuperJump", {
    Text = "Super Jump",
    Default = false,
    Callback = function(Value)
        local mm = M.getMoveMod()
        if mm then mm.SetSuperJump(Value) end
        if Toggles.QuickSuperJump and Toggles.QuickSuperJump.Value ~= Value then
            Toggles.QuickSuperJump:SetValue(Value)
        end
    end
})

SpeedBox:AddSlider("SuperJumpForce", {
    Text = "Super Jump Force",
    Default = 216,
    Min = 50,
    Max = 350,
    Rounding = 0,
    Callback = function(Value)
        local mm = M.getMoveMod()
        if mm then mm.SetSuperJumpPower(Value) end
    end
})

SpeedBox:AddToggle("InfiniteJump", {
    Text = "Infinite Air Jump",
    Default = false,
    Tooltip = "Allows jumping continuously while in mid-air",
    Callback = function(Value)
        local mm = M.getMoveMod()
        if mm then mm.SetInfiniteJump(Value) end
    end
})

local EnvBox = Tabs.Movement:AddRightGroupbox("Flight & Environment")

EnvBox:AddToggle("Fly", {
    Text = "Flight Glide",
    Default = false,
    Callback = function(Value)
        local mm = M.getMoveMod()
        if mm then mm.SetFly(Value) end
    end
})

EnvBox:AddSlider("FlySpeed", {
    Text = "Flight Speed",
    Default = 70,
    Min = 20,
    Max = 500,
    Rounding = 0,
    Callback = function(Value)
        local mm = M.getMoveMod()
        if mm then mm.SetFlySpeed(Value) end
    end
})

EnvBox:AddToggle("Noclip", {
    Text = "Noclip (Wallpass)",
    Default = false,
    Tooltip = "Pass freely through solid walls and geometry",
    Callback = function(Value)
        local mm = M.getMoveMod()
        if mm then mm.SetNoclip(Value) end
    end
})

EnvBox:AddToggle("WalkOnWater", {
    Text = "Walk on Water",
    Default = false,
    Tooltip = "Walk across ocean waters without sinking",
    Callback = function(Value)
        local mm = M.getMoveMod()
        if mm then mm.SetWalkOnWater(Value) end
    end
})

EnvBox:AddToggle("AntiLava", {
    Text = "Anti-Lava Damage Immunity",
    Default = false,
    Tooltip = "Prevents damage from lava and hazards",
    Callback = function(Value)
        local mm = M.getMoveMod()
        if mm then mm.SetAntiLava(Value) end
    end
})

-- ============================================================
-- TAB 5: VISUALS (PVP RADAR & CHAMS)
-- ============================================================
local ESPLeft = Tabs.Visuals:AddLeftGroupbox("Player Radar Elements")

ESPLeft:AddToggle("MasterESP", {
    Text = "Master Visuals Overlay",
    Default = false,
    Callback = function(Value)
        local em = M.getESP()
        if em and em.toggle then em.toggle(Value) end
        Library:Notify("Player ESP: " .. (Value and "Enabled" or "Disabled"), 2)
    end
})

ESPLeft:AddDropdown("ESPStyle", {
    Values = { "2D Boxes", "Overhead Billboard" },
    Default = 1,
    Multi = false,
    Text = "Radar Style",
    Callback = function(Value)
        local em = M.getESP()
        if em then em.Style = Value:find("Billboard") and "Overhead Billboard" or "2D Boxes" end
    end
})

local espElements = {
    { id = "ESPBoxes", text = "2D Bounding Boxes", prop = "Boxes", def = true },
    { id = "ESPNames", text = "Player Names", prop = "Names", def = true },
    { id = "ESPHealth", text = "Health Status & HP%", prop = "Health", def = true },
    { id = "ESPDistance", text = "Distance in Studs", prop = "Distance", def = true },
    { id = "ESPTool", text = "Equipped Weapon / Tool", prop = "Tool", def = true },
    { id = "ESPFruit", text = "Devil Fruit Tracker", prop = "Fruit", def = true },
    { id = "ESPBounty", text = "Bounty / Honor Value", prop = "Bounty", def = true },
    { id = "ESPLevel", text = "Player Level Display", prop = "Level", def = true },
    { id = "ESPPvPStatus", text = "Combat PvP Status", prop = "PvPStatus", def = true },
}

for _, el in ipairs(espElements) do
    ESPLeft:AddToggle(el.id, {
        Text = el.text,
        Default = el.def,
        Callback = function(Value)
            local em = M.getESP()
            if em then em[el.prop] = Value end
        end
    })
end

local ESPRight = Tabs.Visuals:AddRightGroupbox("Chams & Tracers")

local ChamsToggle = ESPRight:AddToggle("PlayerChams", {
    Text = "Player Chams Highlight",
    Default = false,
    Tooltip = "Highlights character silhouettes through obstacles",
    Callback = function(Value)
        local em = M.getESP()
        if em then em.Chams = Value end
    end
})

ChamsToggle:AddColorPicker("ChamsColorPicker", {
    Default = Color3.fromRGB(244, 63, 94),
    Title = "Chams Highlight Color",
    Callback = function(Value)
        local em = M.getESP()
        if em then em.ChamsColor = Value end
    end
})

local ESPTracerToggle = ESPRight:AddToggle("PlayerTracersVisual", {
    Text = "Screen Bottom Tracers",
    Default = false,
    Callback = function(Value)
        local em = M.getESP()
        if em then em.Tracers = Value end
    end
})

ESPTracerToggle:AddColorPicker("ESPTracerColorPicker", {
    Default = Color3.fromRGB(255, 255, 255),
    Title = "ESP Tracer Color",
    Callback = function(Value)
        local em = M.getESP()
        if em then em.TracerColor = Value end
    end
})

ESPRight:AddSlider("ESPTextSize", {
    Text = "ESP Text Font Size",
    Default = 13,
    Min = 10,
    Max = 22,
    Rounding = 0,
    Callback = function(Value)
        local em = M.getESP()
        if em then em.TextSize = Value end
    end
})

ESPRight:AddDivider()

ESPRight:AddButton({
    Text = "Enable All Visuals",
    Func = function()
        if Toggles.MasterESP then Toggles.MasterESP:SetValue(true) end
        for _, el in ipairs(espElements) do
            if Toggles[el.id] then Toggles[el.id]:SetValue(true) end
        end
        Library:Notify("All ESP Visuals: Enabled", 2)
    end
})

ESPRight:AddButton({
    Text = "Disable All Visuals",
    Func = function()
        if Toggles.MasterESP then Toggles.MasterESP:SetValue(false) end
        for _, el in ipairs(espElements) do
            if Toggles[el.id] then Toggles[el.id]:SetValue(false) end
        end
        Library:Notify("All ESP Visuals: Disabled", 2)
    end
})

-- ============================================================
-- TAB 6: SORU (FLASHSTEP AUTOMATION)
-- ============================================================
local SoruLeft = Tabs.Soru:AddLeftGroupbox("Flashstep Engine")

SoruLeft:AddToggle("InfiniteSoru", {
    Text = "Infinite Soru",
    Default = false,
    Tooltip = "Removes Soru flashstep cooldown completely",
    Callback = function(Value)
        local sm = M.getSoru()
        if sm and sm.setInfinite then sm.setInfinite(Value) end
        Library:Notify("Infinite Soru: " .. (Value and "Enabled" or "Disabled"), 2)
    end
})

SoruLeft:AddToggle("SoruAimbot", {
    Text = "Soru Combat Aimbot",
    Default = false,
    Tooltip = "Teleports flashstep directly onto enemy character",
    Callback = function(Value)
        local sm = M.getSoru()
        if sm and sm.setAimbot then sm.setAimbot(Value) end
        Library:Notify("Soru Aimbot: " .. (Value and "Enabled" or "Disabled"), 2)
    end
})

SoruLeft:AddDropdown("SoruTargetMode", {
    Values = { "Nearest Player", "Selected Player" },
    Default = 1,
    Multi = false,
    Text = "Target Selection Mode",
    Callback = function(Value)
        local sm = M.getSoru()
        if sm then sm.TargetMode = Value end
    end
})

local function getPlayerNamesList()
    local list = { "None" }
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(list, p.Name)
        end
    end
    return list
end

SoruLeft:AddDropdown("SoruTargetPlayer", {
    Values = getPlayerNamesList(),
    Default = 1,
    Multi = false,
    Text = "Selected Target Player",
    Callback = function(Value)
        local sm = M.getSoru()
        if sm then sm.SelectedPlayer = (Value ~= "None" and Value or nil) end
    end
})

SoruLeft:AddButton({
    Text = "Refresh Player List",
    Func = function()
        if Options.SoruTargetPlayer then
            Options.SoruTargetPlayer:SetValues(getPlayerNamesList())
            Options.SoruTargetPlayer:SetValue("None")
        end
        Library:Notify("Refreshed player targets", 2)
    end
})

SoruLeft:AddSlider("MaxSoruRange", {
    Text = "Max Soru Range",
    Default = 2000,
    Min = 200,
    Max = 3000,
    Rounding = 50,
    Callback = function(Value)
        local sm = M.getSoru()
        if sm then sm.MaxDistance = Value end
    end
})

local SoruRight = Tabs.Soru:AddRightGroupbox("Soru Skill Combo")

SoruRight:AddToggle("AutoSkillOnSoru", {
    Text = "Auto Skill on Soru",
    Default = false,
    Tooltip = "Fires selected weapon skill immediately upon flashstep landing",
    Callback = function(Value)
        local sm = M.getSoru()
        if sm and sm.setSkillCombo then sm.setSkillCombo(Value) end
        Library:Notify("Auto Skill on Soru: " .. (Value and "Enabled" or "Disabled"), 2)
    end
})

SoruRight:AddDropdown("SoruSkillWeapon", {
    Values = { "Fruit", "Melee", "Sword", "Gun" },
    Default = 1,
    Multi = false,
    Text = "Combo Weapon",
    Callback = function(Value)
        local sm = M.getSoru()
        if sm then sm.SkillWeapon = Value end
    end
})

SoruRight:AddDropdown("SoruSkillKey", {
    Values = { "Z", "X", "C", "V", "F" },
    Default = 1,
    Multi = false,
    Text = "Combo Skill Key",
    Callback = function(Value)
        local sm = M.getSoru()
        if sm then sm.SkillKey = Value end
    end
})

SoruRight:AddSlider("SoruSkillDelay", {
    Text = "Post-Soru Skill Delay (ms)",
    Default = 300,
    Min = 50,
    Max = 800,
    Rounding = 25,
    Callback = function(Value)
        local sm = M.getSoru()
        if sm then sm.SkillDelay = Value / 1000 end
    end
})

-- ============================================================
-- TAB 7: MACRO AUTOMATION SUITE
-- ============================================================
local MacroCtrlBox = Tabs.Macro:AddLeftGroupbox("Macro Controller")

local MacroToggle = MacroCtrlBox:AddToggle("MacroEnabled", {
    Text = "Macro Master Toggle",
    Default = false,
    Tooltip = "Enables keyboard keybind trigger and combo loop execution",
    Callback = function(Value)
        local mm = M.getMacro()
        if mm and mm.toggle then mm.toggle(Value) end
        Library:Notify("Macro: " .. (Value and "Enabled" or "Disabled"), 2)
    end
})

MacroToggle:AddKeyPicker("MacroTriggerKey", {
    Default = "F",
    SyncToggleState = false,
    Mode = "Press",
    Text = "Macro Trigger Keybind",
    Callback = function()
        local mm = M.getMacro()
        if mm then
            if mm.Running then
                mm.stopMacro()
            else
                mm.Enabled = true
                mm.startMacro()
            end
        end
    end
})

MacroCtrlBox:AddDropdown("MacroSlot", {
    Values = { "Slot 1", "Slot 2", "Slot 3", "Slot 4", "Slot 5" },
    Default = 1,
    Multi = false,
    Text = "Active Combo Slot",
    Callback = function(Value)
        local num = tonumber(tostring(Value):match("%d+")) or 1
        local mm = M.getMacro()
        if mm then mm.ActiveSlot = num end
        Library:Notify("Active slot changed to " .. tostring(Value), 2)
    end
})

MacroCtrlBox:AddToggle("MacroLoop", {
    Text = "Loop Sequence Continuously",
    Default = false,
    Callback = function(Value)
        local mm = M.getMacro()
        if mm then
            mm.Loop = Value
            mm.LoopMode = Value
        end
    end
})

MacroCtrlBox:AddToggle("MacroAutoStartOnX", {
    Text = "Auto Start on X",
    Default = false,
    Tooltip = "Runs the combo sequence right after you cast any X skill",
    Callback = function(Value)
        local mm = M.getMacro()
        if mm and mm.setAutoStartOnX then
            mm.setAutoStartOnX(Value)
        end
    end
})

MacroCtrlBox:AddToggle("MacroMobileButton", {
    Text = "Mobile Floating Button",
    Default = false,
    Tooltip = "Draggable on-screen one-touch button to trigger combo",
    Callback = function(Value)
        local mm = M.getMacro()
        if mm and mm.ensureMobileButton then
            mm.ensureMobileButton(Value)
        end
    end
})

MacroCtrlBox:AddDivider()

MacroCtrlBox:AddButton({
    Text = "Start Combo Sequence",
    Func = function()
        local mm = M.getMacro()
        if mm then
            mm.Enabled = true
            mm.startMacro()
        end
    end
})

MacroCtrlBox:AddButton({
    Text = "Stop Combo Sequence",
    Func = function()
        local mm = M.getMacro()
        if mm then mm.stopMacro() end
    end
})

-- Right Tabbox for Combo Blocks 1-6
local MacroSeqTabbox = Tabs.Macro:AddRightTabbox()
local TabBlocks1to3 = MacroSeqTabbox:AddTab("Steps 1-3")
local TabBlocks4to6 = MacroSeqTabbox:AddTab("Steps 4-6")

for b = 1, 6 do
    local parentTab = (b <= 3) and TabBlocks1to3 or TabBlocks4to6
    local defEnabled = (b <= 3)
    local defWeaponIdx = (b <= 2 and 1 or 2)
    local defKeyIdx = ({ 1, 2, 3, 1, 4, 2 })[b]

    parentTab:AddToggle("MacroB" .. b .. "_Enabled", {
        Text = string.format("Enable Step %d", b),
        Default = defEnabled,
        Callback = function(Value)
            local mm = M.getMacro()
            if mm then mm.setSlot(b, nil, nil, Value) end
        end
    })

    parentTab:AddDropdown("MacroB" .. b .. "_Weapon", {
        Values = { "Melee", "Sword", "Fruit", "Gun" },
        Default = defWeaponIdx,
        Multi = false,
        Text = string.format("Step %d Weapon", b),
        Callback = function(Value)
            local mm = M.getMacro()
            if mm then mm.setSlot(b, Value, nil, nil) end
        end
    })

    parentTab:AddDropdown("MacroB" .. b .. "_Key", {
        Values = { "Z", "X", "C", "V", "F" },
        Default = defKeyIdx,
        Multi = false,
        Text = string.format("Step %d Skill Key", b),
        Callback = function(Value)
            local mm = M.getMacro()
            if mm then mm.setSlot(b, nil, Value, nil) end
        end
    })

    parentTab:AddDropdown("MacroB" .. b .. "_Mode", {
        Values = { "Tap", "Hold" },
        Default = 1,
        Multi = false,
        Text = string.format("Step %d Mode", b),
        Callback = function(Value)
            local mm = M.getMacro()
            if mm then mm.setSlot(b, nil, nil, nil, Value) end
        end
    })

    parentTab:AddSlider("MacroB" .. b .. "_Hold", {
        Text = string.format("Step %d Hold Duration (s)", b),
        Default = 0.00,
        Min = 0.00,
        Max = 3.00,
        Rounding = 2,
        Compact = true,
        Callback = function(Value)
            local mm = M.getMacro()
            if mm then mm.setSlot(b, nil, nil, nil, nil, Value) end
        end
    })

    if b == 1 or b == 2 or b == 4 or b == 5 then
        parentTab:AddDivider()
    end
end

-- ============================================================
-- TAB 8: MISC & PERFORMANCE
-- ============================================================
local PerformanceBox = Tabs.Misc:AddLeftGroupbox("Client Optimization")

PerformanceBox:AddToggle("FFlags1", {
    Text = "FFlags 1 (FPS Booster)",
    Default = false,
    Tooltip = "120 FPS cap, smooth plastic textures, removes fog, hides debris",
    Callback = function(Value)
        local ct = M.getClientTweaks()
        if ct then ct.SetFFlags1(Value) end
        if Toggles.QuickFFlags and Toggles.QuickFFlags.Value ~= Value then
            Toggles.QuickFFlags:SetValue(Value)
        end
        Library:Notify("FPS Booster: " .. (Value and "Active" or "Disabled"), 2)
    end
})

PerformanceBox:AddToggle("NoAnimations", {
    Text = "Disable Non-Attack Animations",
    Default = false,
    Tooltip = "Stops idle and non-attack animations to prevent sideways glitches and freeze bugs",
    Callback = function(Value)
        local ct = M.getClientTweaks()
        if ct then ct.SetNoAnimations(Value) end
        Library:Notify("Animation Limiter: " .. (Value and "Active" or "Disabled"), 2)
    end
})

PerformanceBox:AddButton({
    Text = "Apply Fast FFlags Now",
    Func = function()
        pcall(function()
            local setfflag = (type(setfflag) == "function" and setfflag)
            if setfflag then
                setfflag("DFIntTaskSchedulerTargetFps", "120")
                setfflag("FIntRenderShadowIntensity", "0")
                setfflag("FFlagGlobalWindRendering", "False")
            end
            local setfps = (type(setfpscap) == "function" and setfpscap)
            if setfps then setfps(120) end
        end)
        Library:Notify("Fast FFlags applied successfully (120 FPS cap)", 3)
    end
})

local ServerToolsBox = Tabs.Misc:AddRightGroupbox("Server & World Tools")

ServerToolsBox:AddButton({
    Text = "Copy Server JobId",
    Func = function()
        pcall(function()
            if setclipboard then
                setclipboard(tostring(game.JobId))
                Library:Notify("Server JobId copied to clipboard!", 3)
            end
        end)
    end
})

ServerToolsBox:AddButton({
    Text = "Rejoin Current Server",
    Func = function()
        if #Players:GetPlayers() <= 1 then
            LocalPlayer:Kick("\nRejoining...")
            task.wait()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        else
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end
    end
})

ServerToolsBox:AddButton({
    Text = "Server Hop (Next Best)",
    Func = function()
        pcall(function()
            local sfUrl = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100", tostring(game.PlaceId))
            local req = game:HttpGet(sfUrl)
            local data = HttpService:JSONDecode(req)
            if data and data.data then
                for _, s in ipairs(data.data) do
                    if s.playing < s.maxPlayers and s.id ~= game.JobId then
                        Library:Notify("Teleporting to server: " .. tostring(s.id), 3)
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                        return
                    end
                end
            end
            Library:Notify("No alternative server found", 3)
        end)
    end
})

-- ============================================================
-- TAB 9: UI SETTINGS & CONFIG MANAGER
-- ============================================================
local MenuSettingsBox = Tabs["UI Settings"]:AddLeftGroupbox("Menu Settings")

MenuSettingsBox:AddButton({
    Text = "Unload Vinsers Hub",
    Func = function()
        Library:Unload()
    end
})

MenuSettingsBox:AddLabel("Menu Keybind"):AddKeyPicker("MenuKeybind", {
    Default = "End",
    NoUI = true,
    Text = "Menu Keybind"
})

Library.ToggleKeybind = Options.MenuKeybind

MenuSettingsBox:AddToggle("ShowWatermark", {
    Text = "Show Watermark",
    Default = true,
    Tooltip = "Toggles top-left watermark and real-time FPS/Ping telemetry",
    Callback = function(Value)
        Library:SetWatermarkVisibility(Value)
    end
})

-- Initialize Theme & Save Managers
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SetFolder("VinsersHub")
SaveManager:SetFolder("VinsersHub/BloxFruits")

SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])

-- ============================================================
-- WATERMARK & LIVE TELEMETRY THREAD
-- ============================================================
Library:SetWatermarkVisibility(true)

task.spawn(function()
    local frameCount = 0
    local lastCheck = os.clock()
    local fps = 60
    local startTime = os.clock()

    RunService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        if os.clock() - lastCheck >= 1 then
            fps = frameCount
            frameCount = 0
            lastCheck = os.clock()

            local ping = 0
            pcall(function()
                ping = math.floor(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue())
            end)
            if ping == 0 and LocalPlayer then
                pcall(function() ping = math.floor(LocalPlayer:GetNetworkPing() * 1000) end)
            end

            Library:SetWatermark(string.format("Vinser Hub (%s) | %d FPS | %d ms", CurrentExecutor, fps, ping))

            if PingLabel then PingLabel:SetText(string.format("Ping: %d ms", ping)) end
            if FPSLabel then FPSLabel:SetText(string.format("FPS: %d", fps)) end
        end
    end)

    while task.wait(1.5) do
        pcall(function()
            local elapsed = math.floor(os.clock() - startTime)
            local mins = math.floor(elapsed / 60)
            local secs = elapsed % 60
            if UptimeLabel then
                UptimeLabel:SetText(string.format("Server Uptime: %dm %ds", mins, secs))
            end

            if PlayersLabel then
                PlayersLabel:SetText(string.format("Players: %d / %d", #Players:GetPlayers(), Players.MaxPlayers))
            end

            local data = LocalPlayer and (LocalPlayer:FindFirstChild("Data") or LocalPlayer:FindFirstChild("leaderstats"))
            if data then
                local lvl = data:FindFirstChild("Level")
                if LevelLabel then LevelLabel:SetText("Level: " .. (lvl and tostring(lvl.Value) or "--")) end

                local beli = data:FindFirstChild("Beli")
                if BeliLabel then BeliLabel:SetText("Beli: " .. (beli and ("$" .. FormatNumber(beli.Value)) or "--")) end

                local bnty = data:FindFirstChild("Bounty") or data:FindFirstChild("Bounty/Honor")
                if BountyLabel then BountyLabel:SetText("Bounty: " .. (bnty and FormatNumber(bnty.Value) or "--")) end

                local df = data:FindFirstChild("DevilFruit")
                if FruitLabel then FruitLabel:SetText("Devil Fruit: " .. (df and tostring(df.Value):gsub("-%w+", "") or "None")) end

                local race = data:FindFirstChild("Race")
                if RaceLabel then RaceLabel:SetText("Race: " .. (race and tostring(race.Value) or "--")) end
            end

            if TeamLabel and LocalPlayer and LocalPlayer.Team then
                TeamLabel:SetText("Faction: " .. tostring(LocalPlayer.Team.Name))
            end
        end)
    end
end)

-- Preload modules in background for instant responsiveness
task.spawn(function()
    pcall(function()
        M.getFastAttack()
        M.getDragonGun()
        M.getGunAura()
        M.getAntiStun()
        M.getSanguineBoost()
        M.getGodhumanZ()
        M.getExtraWidgets()
        M.getAutoCombat()
        M.getCamlock()
        M.getMoveMod()
        M.getESP()
        M.getSoru()
        M.getMacro()
        M.getClientTweaks()
    end)
end)

-- Load auto-saved config profile if exists
SaveManager:LoadAutoloadConfig()

Library:Notify("Welcome to Vinser Hub!", 4)
