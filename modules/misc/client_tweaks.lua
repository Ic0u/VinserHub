--[[
    Darling X - Client Tweaks & FFlags Optimization Suite
    Rendering optimization, FPS unlocking, and animation stabilization.
    Zero emojis, zero third-party references.
    Strict gating: zero active loops or connections when disabled.
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local ClientTweaks = {
    FFlags1Enabled = false,
    NoAnimEnabled = false,

    FFlagsAddedConn = nil,
    FFlagsThread = nil,
    NoAnimConn = nil,
}

local function getExecutorFunc(name)
    if typeof(rawget) == "function" and rawget(_G, name) then return _G[name] end
    if typeof(getgenv) == "function" and getgenv()[name] then return getgenv()[name] end
    return nil
end

local function isCharacterPart(obj)
    local char = LocalPlayer and LocalPlayer.Character
    if char and obj:IsDescendantOf(char) then return true end
    for _, p in ipairs(Players:GetPlayers()) do
        local c = p.Character
        if c and obj:IsDescendantOf(c) then return true end
    end
    return false
end

local function optimizePart(obj)
    pcall(function()
        if isCharacterPart(obj) then return end

        if obj:IsA("BasePart") then
            obj.Material = Enum.Material.SmoothPlastic
            obj.Reflectance = 0
            obj.CastShadow = false
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = 1
        elseif obj:IsA("ParticleEmitter") then
            obj.Rate = math.min(obj.Rate, 1)
            obj.Speed = NumberRange.new(0)
        elseif obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
            obj.Enabled = false
        elseif obj:IsA("Trail") or obj:IsA("Beam") then
            obj.Enabled = false
        end
    end)
end

local function clearAtmosphere()
    pcall(function()
        Lighting.FogStart = 0
        Lighting.FogEnd = 1e5
        Lighting.Brightness = 1
        Lighting.GlobalShadows = false
        for _, effect in ipairs(Lighting:GetDescendants()) do
            if effect:IsA("Atmosphere") then
                effect.Density = 0
                effect.Haze = 0
                effect.Glare = 0
                effect.Offset = 0
            elseif effect:IsA("BlurEffect") then
                effect.Size = 0
            elseif effect:IsA("BloomEffect") then
                effect.Intensity = 0
                effect.Size = 0
                effect.Threshold = 1
            elseif effect:IsA("DepthOfFieldEffect") then
                effect.InFocusRadius = 1e5
            elseif effect:IsA("SunRaysEffect") then
                effect.Intensity = 0
            elseif effect:IsA("ColorCorrectionEffect") then
                effect.Brightness = 0
                effect.Contrast = 0
                effect.Saturation = 0
            end
        end
    end)
end

local DEBRIS_SIZE = 2
local function handleDebris(obj)
    if not obj:IsA("BasePart") or obj.Anchored or isCharacterPart(obj) then return end
    local size = obj.Size
    if size.X < DEBRIS_SIZE and size.Y < DEBRIS_SIZE and size.Z < DEBRIS_SIZE then
        pcall(function()
            obj.Transparency = 1
            obj.CanCollide = false
        end)
    end
end

-- ========================================================================
-- 1. FFLAGS 1 PERFORMANCE & RENDERING BOOSTER
-- ========================================================================
function ClientTweaks.SetFFlags1(state)
    local target = (state == true)
    if ClientTweaks.FFlags1Enabled == target then return end
    ClientTweaks.FFlags1Enabled = target

    if ClientTweaks.FFlags1Enabled then
        pcall(function()
            local setfps = (type(setfpscap) == "function" and setfpscap) or getExecutorFunc("setfpscap")
            if setfps then pcall(setfps, 120) end
        end)

        pcall(function()
            local sff = (type(setfflag) == "function" and setfflag) or getExecutorFunc("setfflag")
            if sff then
                pcall(sff, "DFIntTaskSchedulerTargetFps", "120")
                pcall(sff, "FIntRenderShadowIntensity", "0")
                pcall(sff, "FFlagGlobalWindRendering", "False")
                pcall(sff, "FIntFRMMinGrassDistance", "0")
                pcall(sff, "FIntFRMMaxGrassDistance", "0")
                pcall(sff, "FFlagDebugGraphicsDisableDirect3D11", "False")
            end
        end)

        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Disabled
        end)

        pcall(function()
            local userSettings = UserSettings():GetService("UserGameSettings")
            if userSettings then
                userSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
            end
        end)

        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            pcall(function()
                terrain.WaterWaveSize = 0
                terrain.WaterWaveSpeed = 0
                terrain.WaterReflectance = 0
                terrain.WaterTransparency = 0
            end)
        end

        clearAtmosphere()

        for _, v in ipairs(Workspace:GetDescendants()) do
            optimizePart(v)
            handleDebris(v)
        end

        if not ClientTweaks.FFlagsAddedConn then
            ClientTweaks.FFlagsAddedConn = Workspace.DescendantAdded:Connect(function(v)
                if not ClientTweaks.FFlags1Enabled then return end
                RunService.Heartbeat:Wait()
                optimizePart(v)
                handleDebris(v)
            end)
        end

        if not ClientTweaks.FFlagsThread then
            ClientTweaks.FFlagsThread = task.spawn(function()
                while ClientTweaks.FFlags1Enabled do
                    clearAtmosphere()
                    task.wait(2.5)
                end
                ClientTweaks.FFlagsThread = nil
            end)
        end
    else
        if ClientTweaks.FFlagsAddedConn then
            pcall(function() ClientTweaks.FFlagsAddedConn:Disconnect() end)
            ClientTweaks.FFlagsAddedConn = nil
        end
        if ClientTweaks.FFlagsThread then
            pcall(task.cancel, ClientTweaks.FFlagsThread)
            ClientTweaks.FFlagsThread = nil
        end

        pcall(function()
            Lighting.GlobalShadows = true
            Lighting.FogStart = 0
            Lighting.FogEnd = 100000
            Lighting.Brightness = 2
        end)

        pcall(function()
            local terrain = Workspace:FindFirstChildOfClass("Terrain")
            if terrain then
                terrain.WaterWaveSize = 0.15
                terrain.WaterWaveSpeed = 10
                terrain.WaterReflectance = 0.05
                terrain.WaterTransparency = 1
            end
        end)

        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
            settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Default
        end)

        pcall(function()
            local userSettings = UserSettings():GetService("UserGameSettings")
            if userSettings then
                userSettings.SavedQualityLevel = Enum.SavedQualitySetting.Automatic
            end
        end)

        pcall(function()
            local setfps = (type(setfpscap) == "function" and setfpscap) or getExecutorFunc("setfpscap")
            if setfps then pcall(setfps, 60) end
        end)

        pcall(function()
            local sff = (type(setfflag) == "function" and setfflag) or getExecutorFunc("setfflag")
            if sff then
                pcall(sff, "DFIntTaskSchedulerTargetFps", "60")
                pcall(sff, "FIntRenderShadowIntensity", "100")
                pcall(sff, "FFlagGlobalWindRendering", "True")
            end
        end)
    end
end

function ClientTweaks.ApplyFastFFlags()
    ClientTweaks.SetFFlags1(true)
end

-- ========================================================================
-- 2. NO ANIMATIONS (FIX CHARACTER FREEZE & SIDEWAYS BUG)
-- ========================================================================
local ATTACK_KEYWORDS = { "attack", "slash", "punch", "m1", "combo", "hit", "tool", "ability", "skill", "kamehameha", "bullet", "gun", "sword", "melee", "fruit" }

local function isAttackAnim(track)
    local name = string.lower(track.Name)
    for _, kw in ipairs(ATTACK_KEYWORDS) do
        if string.find(name, kw) then return true end
    end
    if track.Priority == Enum.AnimationPriority.Action then return true end
    return false
end

function ClientTweaks.SetNoAnimations(state)
    local target = (state == true)
    if ClientTweaks.NoAnimEnabled == target then return end
    ClientTweaks.NoAnimEnabled = target

    if ClientTweaks.NoAnimEnabled and not ClientTweaks.NoAnimConn then
        ClientTweaks.NoAnimConn = RunService.Stepped:Connect(function()
            if not ClientTweaks.NoAnimEnabled then return end
            local char = LocalPlayer and LocalPlayer.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            hum.AutoRotate = true

            local animator = hum:FindFirstChildOfClass("Animator")
            if not animator then return end

            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                if not isAttackAnim(track) then
                    pcall(function() track:Stop(0) end)
                end
            end
        end)
    elseif not ClientTweaks.NoAnimEnabled and ClientTweaks.NoAnimConn then
        pcall(function() ClientTweaks.NoAnimConn:Disconnect() end)
        ClientTweaks.NoAnimConn = nil
    end
end

-- ========================================================================
-- 3. RESET ALL TWEAKS
-- ========================================================================
function ClientTweaks.ResetAll()
    ClientTweaks.SetFFlags1(false)
    ClientTweaks.SetNoAnimations(false)
end

return ClientTweaks
