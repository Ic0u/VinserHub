--[[
    Darling X | Modular UI Foundation
    Liquid Glass Theme with Dynamic Themes, Static Wallpapers, and Combat Engine
    Author: Darling
    Repository: https://github.com/instagramusa/D
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local HttpService = game:GetService("HttpService")

local APP_TITLE = "Darling X"
local APP_VERSION = "v2.1"
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
        if now - lastActivation < 0.10 then return end
        lastActivation = now
        pcall(callback)
    end

    local function attach(target)
        if not target then return end
        pcall(function() target.Activated:Connect(activate) end)
        pcall(function() target.MouseButton1Click:Connect(activate) end)
        pcall(function() target.MouseButton1Down:Connect(activate) end)
        pcall(function() target.TouchTap:Connect(activate) end)
        pcall(function()
            target.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    activate()
                end
            end)
        end)
    end

    attach(button)

    pcall(function()
        for _, desc in ipairs(button:GetDescendants()) do
            if desc:IsA("GuiObject") then
                attach(desc)
            end
        end
        button.DescendantAdded:Connect(function(desc)
            if desc:IsA("GuiObject") then
                attach(desc)
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
local CurrentThemeName = "Purple"
local CurrentAccent = THEMES.Purple
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
end

local function ApplyNextTheme()
    for index, name in ipairs(THEME_ORDER) do
        if name == CurrentThemeName then
            ApplyTheme(THEME_ORDER[(index % #THEME_ORDER) + 1])
            return
        end
    end
    ApplyTheme(THEME_ORDER[1])
end

local function ApplyNextFont()
    for index, name in ipairs(FONT_ORDER) do
        if name == CurrentFontName then
            ApplyFont(FONT_ORDER[(index % #FONT_ORDER) + 1])
            return
        end
    end
    ApplyFont(FONT_ORDER[1])
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
    if exRequest then
        local ok, res = pcall(exRequest, { Url = url, Method = "GET" })
        if ok and res and res.Body and #res.Body > 50 then return res.Body end
    end
    if game.HttpGet then
        local ok, body = pcall(function() return game:HttpGet(url, true) end)
        if ok and body and #body > 50 then return body end
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

    -- Download cache attempt
    if exWriteFile and exGetCustomAsset then
        local cachedPath = "DarlingX/cache/darling_logo.png"
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
        local okAsset, asset = pcall(exGetCustomAsset, cachedPath)
        if okAsset and type(asset) == "string" and #asset > 0 then
            CachedLogoAsset = asset
            return asset
        end
    end

    CachedLogoAsset = DEFAULT_LOGO_ID
    return DEFAULT_LOGO_ID
end

-- ============================================================
-- MODULE LOADER
-- ============================================================
local LoadedModules = {}
local function RequireModule(relPath)
    if LoadedModules[relPath] then
        return LoadedModules[relPath]
    end

    -- 1. Fresh remote fetch with cache-busting timestamp to avoid stale CDN responses
    local cacheBuster = tostring(os.time())
    local remoteUrl = GITHUB_REPO_RAW .. "/" .. relPath .. "?t=" .. cacheBuster
    local body = SafeHttpGet(remoteUrl)
    if body and #body > 0 then
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

    -- 2. Local fallback if offline or remote fetch failed
    local candidatePaths = {
        relPath,
        "DarlingX/" .. relPath,
        "assets/" .. relPath,
        "modules/" .. relPath:gsub("^modules/", ""),
        "darling-hub/" .. relPath
    }

    if isfile and readfile then
        for _, path in ipairs(candidatePaths) do
            local okCheck, exists = pcall(isfile, path)
            if okCheck and exists then
                local okRead, content = pcall(readfile, path)
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
    Aimbot   = "rbxassetid://81872698913435",   -- Lucide: swords
    Mobility = "rbxassetid://139192589041315",  -- Lucide: footprints
    Soru     = "rbxassetid://114551690399915",  -- Lucide: wind
    Esp      = "rbxassetid://100033680381365",  -- Lucide: eye
    Misc     = "rbxassetid://85538382643347",   -- Lucide: sliders-horizontal
    Settings = "rbxassetid://86350350950064",   -- Lucide: palette
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
    { name = "Ashen One (Default)", file = nil, id = DEFAULT_WALLPAPER_ID },
    { name = "None / Clean Dark Glass", file = nil, id = "" },
    { name = "2000s Hacker Room", file = "hacker_room.jpg", id = "rbxassetid://9078772097" },
    { name = "Lycoris Monochrome", file = "lycoris_monochrome.jpg", id = "rbxassetid://6071575925" },
    { name = "Cyan Neko", file = "cyan_neko.jpg", id = "rbxassetid://7040439144" },
    { name = "Frieren Beyond Journey", file = "frieren.jpg", id = "rbxassetid://129497751007547" },
    { name = "Cyberpunk Megalopolis", file = "cyberpunk_megalopolis.jpg", id = "rbxassetid://122087867919987" },
    { name = "Green Night Driving", file = "green_night_driving.jpg", id = "rbxassetid://127123211876541" },
    { name = "Monika Lonely", file = "monika_lonely.jpg", id = "rbxassetid://6071575925" },
    { name = "Neon Purple Midnight", file = "purple_midnight.jpg", id = "rbxassetid://9078772097" },
    { name = "Persona 5 Rainy Tokyo", file = "persona_5_rainy.jpg", id = "rbxassetid://7040439144" },
    { name = "Rainy Tokyo", file = "rainy_tokyo.jpg", id = "rbxassetid://6071575925" },
    { name = "Shorekeeper Blue Sea", file = "shorekeeper.jpg", id = "rbxassetid://129497751007547" },
    { name = "Skirk Neko Genshin", file = "skirk_neko.jpg", id = "rbxassetid://122087867919987" },
    { name = "Snowy Cozy Bedroom", file = "snowy_bedroom.jpg", id = "rbxassetid://6071575925" },
    { name = "Snowy Forest", file = "snowy_forest.jpg", id = "rbxassetid://9078772097" },
    { name = "Dark River Forest", file = "dark_river_forest.jpg", id = "rbxassetid://7040439144" },
    { name = "Witch Cauldron Halloween", file = "witch_cauldron.jpg", id = "rbxassetid://127123211876541" },
    { name = "Deepseek Chan", file = "deepseek_chan.jpg", id = "rbxassetid://129497751007547" },
    { name = "Yuta Cursed Blade", file = "yuta_blade.jpg", id = "rbxassetid://122087867919987" },
    { name = "Zankou Neverness", file = "zankou_nte.jpg", id = "rbxassetid://9078772097" },
    { name = "Anime Theme 1", file = nil, id = "rbxassetid://129497751007547" },
    { name = "Anime Theme 3", file = nil, id = "rbxassetid://122087867919987" },
    { name = "Anime Theme 4", file = nil, id = "rbxassetid://127123211876541" },
}
local currentBgIdx = 1

local function ResolveWallpaperAsset(wp)
    if not wp then return DEFAULT_WALLPAPER_ID end
    if wp.id == "" then return "" end

    if wp.file then
        local localAsset = ResolveCustomAsset("assets/backgrounds/" .. wp.file, nil)
        if localAsset then return localAsset end

        if exWriteFile and exGetCustomAsset then
            local cachedPath = "DarlingX/cache/" .. wp.file
            pcall(function()
                if exMakeFolder then
                    pcall(exMakeFolder, "DarlingX")
                    pcall(exMakeFolder, "DarlingX/cache")
                end
                local rawUrl = GITHUB_REPO_RAW .. "/assets/backgrounds/" .. wp.file .. "?t=" .. tostring(os.time())
                local body = SafeHttpGet(rawUrl)
                if body and #body > 50 then
                    exWriteFile(cachedPath, body)
                end
            end)
            local okAsset, asset = pcall(exGetCustomAsset, cachedPath)
            if okAsset and type(asset) == "string" and #asset > 0 then
                return asset
            end

            -- Flat file fallback for mobile executors without nested folder support
            local flatPath = "darling_bg_" .. wp.file
            pcall(function()
                local rawUrl = GITHUB_REPO_RAW .. "/assets/backgrounds/" .. wp.file .. "?t=" .. tostring(os.time())
                local body = SafeHttpGet(rawUrl)
                if body and #body > 50 then
                    exWriteFile(flatPath, body)
                end
            end)
            local okFlat, flatAsset = pcall(exGetCustomAsset, flatPath)
            if okFlat and type(flatAsset) == "string" and #flatAsset > 0 then
                return flatAsset
            end
        end
    end
    return wp.id or DEFAULT_WALLPAPER_ID
end

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

    task.delay(2.2, function()
        pcall(function()
            if introGui and introGui.Parent then introGui:Destroy() end
        end)
    end)

    task.spawn(function()
        TweenService:Create(scale, TweenInfo.new(0.65, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
        TweenService:Create(title, TweenInfo.new(0.45), { TextTransparency = 0 }):Play()
        TweenService:Create(sub, TweenInfo.new(0.45), { TextTransparency = 0 }):Play()
        TweenService:Create(halo, TweenInfo.new(0.85, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(0, 480, 0, 480) }):Play()
        TweenService:Create(haloStroke, TweenInfo.new(0.85), { Transparency = 1 }):Play()

        task.wait(1.2)

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

local function Notify(titleText, msgText, duration)
    duration = duration or 3.0
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

    TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quart), { BackgroundTransparency = 0.25 }):Play()
    task.delay(duration, function()
        if toast and toast.Parent then
            TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quart), { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0) }):Play()
            task.wait(0.3)
            toast:Destroy()
        end
    end)
end

-- Floating Open Button (Always Displays the Darling Hub Logo)
local FloatingOpen = Instance.new("ImageButton", ScreenGui)
FloatingOpen.Name = "FloatingOpen"
FloatingOpen.Size = UDim2.new(0, 44, 0, 44)
FloatingOpen.Position = UDim2.new(0, 15, 0.20, 0)
FloatingOpen.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
FloatingOpen.BackgroundTransparency = 0
FloatingOpen.Image = GetLogoAsset()
FloatingOpen.ScaleType = Enum.ScaleType.Crop
FloatingOpen.AutoButtonColor = false
FloatingOpen.Active = true
FloatingOpen.Selectable = true
FloatingOpen.ZIndex = 100
FloatingOpen.Visible = false
Instance.new("UICorner", FloatingOpen).CornerRadius = UDim.new(0, 8)

local floatStroke = Instance.new("UIStroke", FloatingOpen)
floatStroke.Color = CurrentAccent
floatStroke.Thickness = 1.8
floatStroke.Transparency = 0
RegisterThemeStroke(floatStroke)

-- Main Window (Liquid Glass Compact 440x300)
local Main = Instance.new("Frame", ScreenGui)
Main.Name = "DarlingX_MainWindow"
Main.Size = UDim2.new(0, 440, 0, 300)
Main.Position = UDim2.new(0.5, -220, 0.5, -150)
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
WallpaperImage.ImageTransparency = 0
WallpaperImage.Image = DEFAULT_WALLPAPER_ID
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

-- Cyber Neon Rain Animation Layer
local rainContainer = Instance.new("Frame", Main)
rainContainer.Name = "RainAnimationLayer"
rainContainer.Size = UDim2.new(1, 0, 1, 0)
rainContainer.BackgroundTransparency = 1
rainContainer.ClipsDescendants = true
rainContainer.Active = false
rainContainer.ZIndex = 2
Instance.new("UICorner", rainContainer).CornerRadius = UDim.new(0, 22)

local activeRainDrops = 0
local RainEnabled = true
local MaxRainDrops = 14
local function createIntenseRainDrop()
    if not IsScriptRunning or not Main.Visible or not RainEnabled or activeRainDrops >= MaxRainDrops then return end
    activeRainDrops = activeRainDrops + 1
    local drop = Instance.new("Frame", rainContainer)
    drop.Size = UDim2.new(0, 2, 0, math.random(14, 26))
    drop.Position = UDim2.new(math.random(1, 99) / 100, 0, -0.15, 0)
    drop.BackgroundColor3 = CurrentAccent
    drop.BackgroundTransparency = math.random(2, 5) / 10
    drop.BorderSizePixel = 0
    drop.Active = false
    Instance.new("UICorner", drop).CornerRadius = UDim.new(1, 0)

    local targetX = drop.Position.X.Scale - (math.random(3, 8) / 100)
    local duration = math.random(4, 9) / 10
    local tw = TweenService:Create(drop, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        Position = UDim2.new(targetX, 0, 1.15, 0),
        BackgroundTransparency = 1
    })
    tw:Play()
    tw.Completed:Connect(function() activeRainDrops = activeRainDrops - 1; drop:Destroy() end)
end

task.spawn(function()
    while IsScriptRunning do
        task.wait(0.04)
        pcall(createIntenseRainDrop)
    end
end)

-- Header Bar
local Header = Instance.new("Frame", Main)
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 42)
Header.BackgroundTransparency = 1
Header.ZIndex = 4

-- Logo Badge
local LogoBadge = Instance.new("ImageLabel", Header)
LogoBadge.Name = "HeaderLogo"
LogoBadge.Size = UDim2.new(0, 24, 0, 24)
LogoBadge.Position = UDim2.new(0, 14, 0.5, -12)
LogoBadge.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
LogoBadge.BackgroundTransparency = 0
LogoBadge.Image = GetLogoAsset()
LogoBadge.ScaleType = Enum.ScaleType.Crop
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

local SubTitle = Instance.new("TextLabel", Header)
SubTitle.Position = UDim2.new(0, 46, 0, 22)
SubTitle.Size = UDim2.new(0, 140, 0, 12)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "by " .. APP_AUTHOR
SubTitle.Font = Enum.Font.GothamMedium
SubTitle.TextSize = 8.5
SubTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
SubTitle.TextXAlignment = Enum.TextXAlignment.Left

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
    btn.ZIndex = 6
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
local function maximizeUI()
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
PageContainer.ZIndex = 4

-- Side Navigation Dock Capsule (Adaptive ScrollingFrame to prevent clipping on mobile)
local BottomDock = Instance.new("ScrollingFrame", Main)
BottomDock.Name = "BottomDock"
BottomDock.Size = UDim2.new(0, 100, 1, -52)
BottomDock.Position = UDim2.new(0, 8, 0, 44)
BottomDock.BackgroundColor3 = Color3.fromRGB(12, 10, 18)
BottomDock.BackgroundTransparency = 0.55
BottomDock.ZIndex = 6
BottomDock.BorderSizePixel = 0
BottomDock.ScrollBarThickness = 0
BottomDock.AutomaticCanvasSize = Enum.AutomaticSize.Y
BottomDock.CanvasSize = UDim2.new(0, 0, 0, 0)
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
    { id = "Aimbot",   name = "Aimbot",   icon = "swords" },
    { id = "Mobility", name = "Mobility", icon = "footprints" },
    { id = "Soru",     name = "Soru",     icon = "wind" },
    { id = "Esp",      name = "Visuals",  icon = "eye" },
    { id = "Misc",     name = "Misc",     icon = "sliders-horizontal" },
    { id = "Themes",   name = "Themes",   icon = "palette" },
}

local TAB_MIN_CANVAS = {
    Home = 950,
    Aimbot = 1450,
    Mobility = 500,
    Soru = 500,
    Esp = 600,
    Misc = 700,
    Themes = 1350
}

local function UpdatePageCanvas(page)
    if not page or not page:IsA("ScrollingFrame") then return end
    local tabKey = page.Name:gsub("Page$", "")
    local minH = TAB_MIN_CANVAS[tabKey] or 500
    local pList = page:FindFirstChildOfClass("UIListLayout")
    local totalHeight = 0
    if pList then
        totalHeight = pList.AbsoluteContentSize.Y
    end
    if totalHeight <= 0 then
        for _, child in ipairs(page:GetChildren()) do
            if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                local h = child.AbsoluteSize.Y
                if h <= 0 then h = child.Size.Y.Offset end
                totalHeight = totalHeight + h + 6
            end
        end
    end
    page.CanvasSize = UDim2.new(0, 0, 0, math.max(totalHeight + 40, minH))
end

local function SelectTabById(targetId)
    if targetId == "Settings" then targetId = "Themes" end
    for _, tabMeta in ipairs(TABS_MANIFEST) do
        local id = tabMeta.id
        local p = Pages[id]
        if p then
            local isTarget = (id == targetId)
            p.Visible = isTarget
            if isTarget then
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

local function BuildTabEntity(tabId, tabName, lucideName, orderIndex)
    local minH = TAB_MIN_CANVAS[tabId] or 500
    local page = Instance.new("ScrollingFrame", PageContainer)
    page.Name = tabId .. "Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = CurrentAccent
    page.ScrollBarImageTransparency = 0.2
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new(0, 0, 0, minH)
    page.ScrollingDirection = Enum.ScrollingDirection.Y
    page.ElasticBehavior = Enum.ElasticBehavior.Always
    page.ClipsDescendants = true
    page.Visible = false
    page.ZIndex = 5

    local pList = Instance.new("UIListLayout", page)
    pList.SortOrder = Enum.SortOrder.LayoutOrder
    pList.Padding = UDim.new(0, 6)
    Instance.new("UIPadding", page).PaddingRight = UDim.new(0, 4)

    pList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, math.max(pList.AbsoluteContentSize.Y + 40, minH))
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
    dockBtn.ZIndex = 7
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
    activePill.ZIndex = 8
    Instance.new("UICorner", activePill).CornerRadius = UDim.new(1, 0)
    RegisterThemeFill(activePill)

    local iconImg = Instance.new("ImageLabel", dockBtn)
    iconImg.Size = UDim2.new(0, 15, 0, 15)
    iconImg.Position = UDim2.new(0, 7, 0.5, -7)
    iconImg.BackgroundTransparency = 1
    iconImg.ImageColor3 = Color3.fromRGB(200, 195, 225)
    iconImg.Active = false
    iconImg.ZIndex = 8
    ApplyTabIcon(iconImg, tabId, lucideName)

    local tabLabel = Instance.new("TextLabel", dockBtn)
    tabLabel.Size = UDim2.new(1, -26, 1, 0)
    tabLabel.Position = UDim2.new(0, 25, 0, 0)
    tabLabel.BackgroundTransparency = 1
    tabLabel.Text = tabName
    tabLabel.Font = Enum.Font.GothamBold
    tabLabel.TextSize = 9.5
    tabLabel.TextColor3 = Color3.fromRGB(240, 235, 255)
    tabLabel.TextXAlignment = Enum.TextXAlignment.Left
    tabLabel.TextTruncate = Enum.TextTruncate.AtEnd
    tabLabel.Active = false
    tabLabel.ZIndex = 8

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

_G.DarlingX.Pages = Pages
_G.DarlingX.SelectTab = SelectTabById

-- Registration Helper (returns pre-built page, safe against runtime ordering)
local function RegisterTab(tabId, tabName, lucideName)
    if tabId == "Settings" then tabId = "Themes" end
    if Pages[tabId] then
        return Pages[tabId]
    end
    TabOrderCounter = TabOrderCounter + 1
    return BuildTabEntity(tabId, tabName or tabId, lucideName, TabOrderCounter)
end

-- ============================================================
-- LUXURY GLASS UI COMPONENTS
-- ============================================================
local function CreateCard(parentPage, cardTitle)
    local card = Instance.new("Frame", parentPage)
    card.Size = UDim2.new(1, 0, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = Color3.fromRGB(12, 10, 18)
    card.BackgroundTransparency = 0.65
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
        local header = Instance.new("TextLabel", card)
        header.Size = UDim2.new(1, 0, 0, 14)
        header.BackgroundTransparency = 1
        header.Text = cardTitle
        header.Font = Enum.Font.GothamBold
        header.TextSize = 9.5
        header.TextColor3 = CurrentAccent
        header.TextXAlignment = Enum.TextXAlignment.Left
        RegisterThemeText(header)
    end

    if parentPage and parentPage:IsA("ScrollingFrame") then
        list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            UpdatePageCanvas(parentPage)
        end)
    end

    return card
end

-- Premium Interactive Glass Button
local function AddButton(parentCard, btnText, callback)
    local btn = Instance.new("TextButton", parentCard)
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.BackgroundColor3 = Color3.fromRGB(22, 18, 32)
    btn.BackgroundTransparency = 0.45
    btn.Text = btnText
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 9.5
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.AutoButtonColor = false
    btn.Active = true
    btn.Selectable = true
    btn.ZIndex = 7
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
    return btn
end

-- Premium Interactive Glass Toggle
local function AddToggle(parentCard, titleText, descText, defaultState, callback)
    local state = defaultState or false

    local row = Instance.new("TextButton", parentCard)
    row.Size = UDim2.new(1, 0, 0, descText and 36 or 28)
    row.BackgroundColor3 = Color3.fromRGB(18, 14, 26)
    row.BackgroundTransparency = 0.6
    row.Text = ""
    row.AutoButtonColor = false
    row.Active = true
    row.Selectable = true
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

    if descText then
        local dLbl = Instance.new("TextLabel", row)
        dLbl.Size = UDim2.new(1, -44, 0, 12)
        dLbl.Position = UDim2.new(0, 0, 0, 19)
        dLbl.BackgroundTransparency = 1
        dLbl.Text = descText
        dLbl.Font = Enum.Font.Gotham
        dLbl.TextSize = 8
        dLbl.TextColor3 = Color3.fromRGB(150, 145, 170)
        dLbl.TextXAlignment = Enum.TextXAlignment.Left
        dLbl.Active = false
    end

    local switch = Instance.new("Frame", row)
    switch.Size = UDim2.new(0, 34, 0, 18)
    switch.Position = UDim2.new(1, -34, 0.5, -9)
    switch.BackgroundColor3 = state and CurrentAccent or Color3.fromRGB(32, 28, 44)
    Instance.new("UICorner", switch).CornerRadius = UDim.new(1, 0)
    switch.Active = false

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
    end

    table.insert(ToggleControls, function(nextState)
        setState(nextState, true)
    end)

    ConnectButton(row, function()
        setState(not state, true)
    end)
    return row
end

-- Premium Interactive Glass Slider with Glowing Track and Numeric Pill Badge
local function AddSlider(parentCard, titleText, minVal, maxVal, defaultVal, stepVal, callback)
    local currentVal = defaultVal or minVal
    stepVal = stepVal or 1

    local container = Instance.new("Frame", parentCard)
    container.Size = UDim2.new(1, 0, 0, 44)
    container.BackgroundColor3 = Color3.fromRGB(18, 14, 26)
    container.BackgroundTransparency = 0.6
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
    tLbl.TextXAlignment = Enum.TextXAlignment.Left

    -- Value Pill Badge
    local vPill = Instance.new("Frame", container)
    vPill.Size = UDim2.new(0, 46, 0, 16)
    vPill.Position = UDim2.new(1, -46, 0, 4)
    vPill.BackgroundColor3 = Color3.fromRGB(24, 20, 34)
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
    RegisterThemeText(vLbl)

    -- Track
    local track = Instance.new("TextButton", container)
    track.Size = UDim2.new(1, 0, 0, 8)
    track.Position = UDim2.new(0, 0, 0, 26)
    track.BackgroundColor3 = Color3.fromRGB(28, 24, 40)
    track.AutoButtonColor = false
    track.Text = ""
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    local trkStroke = Instance.new("UIStroke", track)
    trkStroke.Color = Color3.fromRGB(48, 42, 66)
    trkStroke.Thickness = 0.8

    local fill = Instance.new("Frame", track)
    local initialFrac = math.clamp((currentVal - minVal) / (maxVal - minVal), 0, 1)
    fill.Size = UDim2.new(initialFrac, 0, 1, 0)
    fill.BackgroundColor3 = CurrentAccent
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    RegisterThemeFill(fill)

    local knob = Instance.new("Frame", fill)
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(1, -7, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
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

    function container.SetValue(newVal, runCallback)
        local rawVal = math.clamp(newVal, minVal, maxVal)
        local stepped = math.floor((rawVal / stepVal) + 0.5) * stepVal
        currentVal = math.clamp(stepped, minVal, maxVal)
        local visualFrac = (currentVal - minVal) / (maxVal - minVal)
        fill.Size = UDim2.new(visualFrac, 0, 1, 0)
        vLbl.Text = tostring(currentVal)
        if runCallback and callback then pcall(callback, currentVal) end
    end

    local sliding = false
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            updateValue(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateValue(input.Position.X)
        end
    end)

    return container
end

-- Premium Choice Selector with Value Badge
local function AddChoice(parentCard, label, values, defaultIndex, callback)
    local index = defaultIndex or 1

    local container = Instance.new("TextButton", parentCard)
    container.Size = UDim2.new(1, 0, 0, 28)
    container.BackgroundColor3 = Color3.fromRGB(20, 16, 28)
    container.BackgroundTransparency = 0.5
    container.Text = ""
    container.AutoButtonColor = false
    container.Active = true
    container.Selectable = true
    container.ZIndex = 7
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
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 9.5
    lbl.TextColor3 = Color3.fromRGB(240, 235, 255)
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local badge = Instance.new("Frame", container)
    badge.Size = UDim2.new(0.5, -4, 0, 20)
    badge.Position = UDim2.new(0.5, 4, 0.5, -10)
    badge.BackgroundColor3 = Color3.fromRGB(28, 22, 38)
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
    RegisterThemeText(valLbl)

    local function refresh()
        valLbl.Text = tostring(values[index]) .. "  ›"
    end
    refresh()

    function container.SetIndex(newIdx, runCallback)
        index = math.clamp(newIdx, 1, #values)
        refresh()
        if runCallback and callback then pcall(callback, values[index], index) end
    end

    ConnectButton(container, function()
        index = (index % #values) + 1
        refresh()
        if callback then callback(values[index], index) end
    end)
    return container
end

-- Premium Interactive Glass Text Input
local function AddInput(parentCard, titleText, placeholderText, defaultVal, callback)
    local container = Instance.new("Frame", parentCard)
    container.Size = UDim2.new(1, 0, 0, 48)
    container.BackgroundColor3 = Color3.fromRGB(18, 14, 26)
    container.BackgroundTransparency = 0.6
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
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 9.5
    lbl.TextColor3 = Color3.fromRGB(240, 235, 255)
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local inputFrame = Instance.new("Frame", container)
    inputFrame.Size = UDim2.new(1, 0, 0, 20)
    inputFrame.Position = UDim2.new(0, 0, 0, 22)
    inputFrame.BackgroundColor3 = Color3.fromRGB(24, 20, 34)
    inputFrame.BackgroundTransparency = 0.3
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

    tb.FocusLost:Connect(function(enterPressed)
        if callback then
            callback(tb.Text, enterPressed)
        end
    end)

    return {
        Container = container,
        TextBox = tb,
        GetText = function() return tb.Text end,
        SetText = function(val) tb.Text = tostring(val or "") end
    }
end

local WallpaperListeners = {}
local function RegisterWallpaperListener(fn)
    table.insert(WallpaperListeners, fn)
end

-- Wallpaper Switcher: ONLY changes WallpaperImage, NEVER the LogoBadge or FloatingOpen!
local function SetWallpaper(index, button)
    currentBgIdx = ((index - 1) % #WALLPAPERS) + 1
    local selectedWallpaper = WALLPAPERS[currentBgIdx]
    if button then button.Text = "Background: " .. selectedWallpaper.name end

    if selectedWallpaper.id == "" or selectedWallpaper.name:find("None") then
        WallpaperImage.Image = ""
        WallpaperImage.ImageTransparency = 1
        Notify("Background", "Wallpaper removed (Clean Dark Glass)")
        for _, fn in ipairs(WallpaperListeners) do
            pcall(fn, currentBgIdx, selectedWallpaper)
        end
        return
    end

    local asset = ResolveWallpaperAsset(selectedWallpaper)
    WallpaperImage.Image = asset
    WallpaperImage.ImageTransparency = 0
    pcall(function() ContentProvider:PreloadAsync({ WallpaperImage }) end)
    for _, fn in ipairs(WallpaperListeners) do
        pcall(fn, currentBgIdx, selectedWallpaper)
    end
    Notify("Background", "Wallpaper changed to " .. selectedWallpaper.name)
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

    -- Vitality & Health Status Card (STREAMLINED CYBER NEON HUD - NO NESTED CONTAINER)
    local vitCard = CreateCard(HomePage, "Vitality & Energy Status")

    -- 1. Health Bar Section
    local hpHeader = Instance.new("Frame", vitCard)
    hpHeader.Size = UDim2.new(1, 0, 0, 16)
    hpHeader.BackgroundTransparency = 1

    local hpDot = Instance.new("Frame", hpHeader)
    hpDot.Size = UDim2.new(0, 6, 0, 6)
    hpDot.Position = UDim2.new(0, 0, 0.5, -3)
    hpDot.BackgroundColor3 = Color3.fromRGB(16, 215, 135)
    Instance.new("UICorner", hpDot).CornerRadius = UDim.new(1, 0)

    local vTitle = Instance.new("TextLabel", hpHeader)
    vTitle.Size = UDim2.new(0.5, -12, 1, 0)
    vTitle.Position = UDim2.new(0, 12, 0, 0)
    vTitle.BackgroundTransparency = 1
    vTitle.Text = "HEALTH INTEGRITY"
    vTitle.Font = Enum.Font.GothamBold
    vTitle.TextSize = 9
    vTitle.TextColor3 = Color3.fromRGB(235, 230, 245)
    vTitle.TextXAlignment = Enum.TextXAlignment.Left

    local hpVal = Instance.new("TextLabel", hpHeader)
    hpVal.Size = UDim2.new(0.5, 0, 1, 0)
    hpVal.Position = UDim2.new(0.5, 0, 0, 0)
    hpVal.BackgroundTransparency = 1
    hpVal.Text = "100 / 100 (100%)"
    hpVal.Font = Enum.Font.GothamBold
    hpVal.TextSize = 9.5
    hpVal.TextColor3 = Color3.fromRGB(16, 215, 135)
    hpVal.TextXAlignment = Enum.TextXAlignment.Right

    local hpBarTrack = Instance.new("Frame", vitCard)
    hpBarTrack.Size = UDim2.new(1, 0, 0, 14)
    hpBarTrack.BackgroundColor3 = Color3.fromRGB(20, 16, 30)
    Instance.new("UICorner", hpBarTrack).CornerRadius = UDim.new(0, 7)
    local tStroke = Instance.new("UIStroke", hpBarTrack)
    tStroke.Color = Color3.fromRGB(48, 40, 65)
    tStroke.Thickness = 0.8

    local hpFill = Instance.new("Frame", hpBarTrack)
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.BackgroundColor3 = Color3.fromRGB(16, 215, 135)
    Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 7)

    local hpGleam = Instance.new("Frame", hpFill)
    hpGleam.Size = UDim2.new(1, 0, 0, 2)
    hpGleam.Position = UDim2.new(0, 0, 0, 1)
    hpGleam.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    hpGleam.BackgroundTransparency = 0.7
    hpGleam.BorderSizePixel = 0

    local vSpacer = Instance.new("Frame", vitCard)
    vSpacer.Size = UDim2.new(1, 0, 0, 6)
    vSpacer.BackgroundTransparency = 1

    -- 2. Energy Bar Section
    local energyHeader = Instance.new("Frame", vitCard)
    energyHeader.Size = UDim2.new(1, 0, 0, 14)
    energyHeader.BackgroundTransparency = 1

    local energyDot = Instance.new("Frame", energyHeader)
    energyDot.Size = UDim2.new(0, 6, 0, 6)
    energyDot.Position = UDim2.new(0, 0, 0.5, -3)
    energyDot.BackgroundColor3 = Color3.fromRGB(0, 215, 255)
    Instance.new("UICorner", energyDot).CornerRadius = UDim.new(1, 0)

    local eTitle = Instance.new("TextLabel", energyHeader)
    eTitle.Size = UDim2.new(0.5, -12, 1, 0)
    eTitle.Position = UDim2.new(0, 12, 0, 0)
    eTitle.BackgroundTransparency = 1
    eTitle.Text = "ENERGY RESERVES"
    eTitle.Font = Enum.Font.GothamBold
    eTitle.TextSize = 8.5
    eTitle.TextColor3 = Color3.fromRGB(200, 225, 250)
    eTitle.TextXAlignment = Enum.TextXAlignment.Left

    local energyVal = Instance.new("TextLabel", energyHeader)
    energyVal.Size = UDim2.new(0.5, 0, 1, 0)
    energyVal.Position = UDim2.new(0.5, 0, 0, 0)
    energyVal.BackgroundTransparency = 1
    energyVal.Text = "100%"
    energyVal.Font = Enum.Font.GothamBold
    energyVal.TextSize = 9
    energyVal.TextColor3 = Color3.fromRGB(0, 215, 255)
    energyVal.TextXAlignment = Enum.TextXAlignment.Right

    local energyBarTrack = Instance.new("Frame", vitCard)
    energyBarTrack.Size = UDim2.new(1, 0, 0, 10)
    energyBarTrack.BackgroundColor3 = Color3.fromRGB(20, 16, 30)
    Instance.new("UICorner", energyBarTrack).CornerRadius = UDim.new(0, 5)
    local etStroke = Instance.new("UIStroke", energyBarTrack)
    etStroke.Color = Color3.fromRGB(38, 48, 68)
    etStroke.Thickness = 0.8

    local energyFill = Instance.new("Frame", energyBarTrack)
    energyFill.Size = UDim2.new(1, 0, 1, 0)
    energyFill.BackgroundColor3 = Color3.fromRGB(0, 215, 255)
    Instance.new("UICorner", energyFill).CornerRadius = UDim.new(0, 5)

    local eGleam = Instance.new("Frame", energyFill)
    eGleam.Size = UDim2.new(1, 0, 0, 2)
    eGleam.Position = UDim2.new(0, 0, 0, 1)
    eGleam.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    eGleam.BackgroundTransparency = 0.7
    eGleam.BorderSizePixel = 0

    -- Atmosphere Wallpaper Card (Quick Atmosphere Switcher on Home)
    local wpHomeCard = CreateCard(HomePage, "Atmosphere Wallpaper")

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
    local statsCard = CreateCard(HomePage, "In-Game Attributes")
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
    local netCard = CreateCard(HomePage, "Performance & Network")
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
        pcall(function()
            local ts = game:GetService("TeleportService")
            ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, lp)
        end)
    end)

    AddButton(netCard, "Server Hop (Fast)", function()
        pcall(function()
            Notify("Server", "Searching for low-ping server...")
        end)
    end)

    -- Live Telemetry Thread
    task.spawn(function()
        local startTime = os.clock()
        local fpsCount = 0
        local lastFpsCheck = os.clock()
        RunService.RenderStepped:Connect(function()
            fpsCount = fpsCount + 1
            if os.clock() - lastFpsCheck >= 1 then
                itemFps.Text = fpsCount .. " FPS"
                fpsCount = 0
                lastFpsCheck = os.clock()
            end
        end)

        while IsScriptRunning do
            pcall(function()
                -- Health
                local char = lp and lp.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then
                    local hp = math.max(0, math.floor(hum.Health))
                    local maxHp = math.max(1, math.floor(hum.MaxHealth))
                    local pct = math.floor((hp / maxHp) * 100)
                    local frac = math.clamp(hp / maxHp, 0, 1)

                    hpVal.Text = hp .. " / " .. maxHp .. " (" .. pct .. "%)"
                    TweenService:Create(hpFill, TweenInfo.new(0.3, Enum.EasingStyle.Quart), { Size = UDim2.new(frac, 0, 1, 0) }):Play()

                    if pct > 50 then
                        hpFill.BackgroundColor3 = Color3.fromRGB(16, 215, 135)
                        hpVal.TextColor3 = Color3.fromRGB(16, 215, 135)
                        hpDot.BackgroundColor3 = Color3.fromRGB(16, 215, 135)
                    elseif pct > 25 then
                        hpFill.BackgroundColor3 = Color3.fromRGB(245, 180, 20)
                        hpVal.TextColor3 = Color3.fromRGB(245, 180, 20)
                        hpDot.BackgroundColor3 = Color3.fromRGB(245, 180, 20)
                    else
                        hpFill.BackgroundColor3 = Color3.fromRGB(245, 60, 60)
                        hpVal.TextColor3 = Color3.fromRGB(245, 60, 60)
                        hpDot.BackgroundColor3 = Color3.fromRGB(245, 60, 60)
                    end
                end

                -- Energy / Stamina
                if char then
                    local energyObj = char:FindFirstChild("Energy") or (lp and lp:FindFirstChild("Data") and lp.Data:FindFirstChild("Energy"))
                    if energyObj and energyObj.Value then
                        local maxE = energyObj.MaxValue or 5000
                        local curE = math.floor(energyObj.Value)
                        local eFrac = math.clamp(curE / maxE, 0, 1)
                        local ePct = math.floor(eFrac * 100)
                        energyVal.Text = curE .. " / " .. maxE .. " (" .. ePct .. "%)"
                        TweenService:Create(energyFill, TweenInfo.new(0.3, Enum.EasingStyle.Quart), { Size = UDim2.new(eFrac, 0, 1, 0) }):Play()
                    else
                        energyVal.Text = "100%"
                        energyFill.Size = UDim2.new(1, 0, 1, 0)
                    end
                end

                -- Game Stats
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

                -- Telemetry
                local ping = 0
                local statsService = game:GetService("Stats")
                pcall(function()
                    ping = math.floor(statsService.Network.ServerStatsItem["Data Ping"]:GetValue())
                end)
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
            task.wait(0.4)
        end
    end)
end)

-- 2. AIMBOT TAB (MODULAR COMBAT ENGINE - NO TRACKER)
local AimbotPage = RegisterTab("Aimbot", "Aimbot", "swords")
local okAimbot, errAimbot = pcall(function()
    task.spawn(function()
        pcall(function() RequireModule("modules/combat/aimbot_core.lua") end)
    end)
    -- Silent Aim & Lock Card
    local aimCard = CreateCard(AimbotPage, "Silent Aim & Lock System")

    AddToggle(aimCard, "Player Silent Aim", "Redirects skills and attacks towards enemy players", false, function(state)
        local mod = RequireModule("modules/combat/player_aimbot.lua")
        if mod then
            if state then mod.enable() else mod.disable() end
        end
        Notify("Aimbot", "Player Silent Aim: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(aimCard, "NPC Silent Aim", "Redirects skills and attacks towards mobs and bosses", false, function(state)
        local mod = RequireModule("modules/combat/npc_aimbot.lua")
        if mod then
            if state then mod.enable() else mod.disable() end
        end
        Notify("Aimbot", "NPC Silent Aim: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(aimCard, "Lock Player", "Maintains camera and attack lock on focused enemy player", false, function(state)
        local core = RequireModule("modules/combat/aimbot_core.lua")
        if core and core.setLockPlayer then
            core.setLockPlayer(state)
        end
        Notify("Aimbot", "Lock Player: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(aimCard, "Lock Player Floating Widget", "Displays movable on-screen toggle for player lock", false, function(state)
        pcall(function()
            local fw = RequireModule("modules/pvp/floating_widget.lua")
            if fw and fw.SetWidgetVisible then
                fw.SetWidgetVisible("LockPlayerFloatingPill", state)
            end
        end)
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

    -- 2. FOV Circle Card (Immediate Visual Feedback)
    local fovCard = CreateCard(AimbotPage, "Field of View (FOV Circle)")

    AddToggle(fovCard, "Show FOV Circle", "Displays targeting circle boundary on screen", false, function(state)
        local fovMod = RequireModule("modules/combat/fov.lua")
        if fovMod then
            if state then fovMod.enable() else fovMod.disable() end
        end
        Notify("FOV", "FOV Circle: " .. (state and "Visible" or "Hidden"))
    end)

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
    local tracersCard = CreateCard(AimbotPage, "Target Tracers")

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
    local blCard = CreateCard(AimbotPage, "Skill Redirection Blacklist")
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
    blGrid.Size = UDim2.new(1, 0, 0, 0)
    blGrid.AutomaticSize = Enum.AutomaticSize.Y
    blGrid.BackgroundTransparency = 1
    local blLayout = Instance.new("UIGridLayout", blGrid)
    blLayout.CellSize = UDim2.new(0.5, -4, 0, 26)
    blLayout.CellPadding = UDim2.new(0, 8, 0, 5)

    for _, s in ipairs(blSkills) do
        local isBlacklisted = false
        local bBtn = Instance.new("TextButton", blGrid)
        bBtn.BackgroundColor3 = Color3.fromRGB(22, 18, 30)
        bBtn.BackgroundTransparency = 0.5
        bBtn.Text = s.name .. ": ALLOWED"
        bBtn.TextColor3 = Color3.fromRGB(200, 195, 215)
        bBtn.Font = Enum.Font.GothamBold
        bBtn.TextSize = 8
        bBtn.Active = true
        bBtn.Selectable = true
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
end)
if not okAimbot then
    warn("[Darling X] Failed to initialize AimbotPage: " .. tostring(errAimbot))
end

-- 3. MOBILITY TAB
local MobilityPage = RegisterTab("Mobility", "Mobility", "footprints")
pcall(function()
    local moveCard = CreateCard(MobilityPage, "Movement & Speed Enhancements")

    AddSlider(moveCard, "WalkSpeed Multiplier", 16, 250, 16, 2, function(val)
        pcall(function()
            local char = lp and lp.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = val end
        end)
    end)

    AddSlider(moveCard, "JumpPower Multiplier", 50, 300, 50, 5, function(val)
        pcall(function()
            local char = lp and lp.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.UseJumpPower = true
                hum.JumpPower = val
            end
        end)
    end)

    AddToggle(moveCard, "Infinite Jump", "Allows jumping continuously mid-air without cooldown", false, function(state)
        _G.DarlingX_InfJump = state
        Notify("Mobility", "Infinite Jump: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(moveCard, "Noclip Wallpass", "Walk smoothly through physical geometry and structures", false, function(state)
        _G.DarlingX_Noclip = state
        Notify("Mobility", "Noclip: " .. (state and "Enabled" or "Disabled"))
    end)

    local flyCard = CreateCard(MobilityPage, "Flight & Air Mobility")

    AddToggle(flyCard, "Fly Mode", "Hover and maneuver freely across the 3D space", false, function(state)
        _G.DarlingX_Fly = state
        Notify("Mobility", "Fly Mode: " .. (state and "Enabled" or "Disabled"))
    end)

    AddSlider(flyCard, "Fly Speed", 20, 250, 60, 5, function(val)
        _G.DarlingX_FlySpeed = val
    end)
end)

-- 4. SORU TAB
local SoruPage = RegisterTab("Soru", "Soru", "wind")
pcall(function()
    local soruCard = CreateCard(SoruPage, "Soru & Dash Enhancements")

    AddToggle(soruCard, "Infinite Soru", "Bypasses stamina drain and removes cooldown delay", false, function(state)
        _G.DarlingX_InfSoru = state
        local soruMod = RequireModule("modules/combat/soru.lua")
        if soruMod and soruMod.setInfinite then soruMod.setInfinite(state) end
        Notify("Soru", "Infinite Soru: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(soruCard, "Fast Soru Step", "Instantaneous position warp without dash deceleration", false, function(state)
        _G.DarlingX_FastSoru = state
        Notify("Soru", "Fast Soru: " .. (state and "Enabled" or "Disabled"))
    end)

    AddSlider(soruCard, "Soru Distance Multiplier", 1, 5, 1, 1, function(val)
        _G.DarlingX_SoruDistance = val
    end)

    AddButton(soruCard, "Trigger Soru Flash", function()
        pcall(function()
            local soruMod = RequireModule("modules/combat/soru.lua")
            if soruMod and soruMod.trigger then
                soruMod.trigger()
            else
                Notify("Soru", "Soru Flash triggered")
            end
        end)
    end)
end)

-- 5. ESP TAB
local ESPPage = RegisterTab("Esp", "Esp", "eye")
pcall(function()
    local espCard = CreateCard(ESPPage, "Entity & Player Radar")

    AddToggle(espCard, "Player ESP Boxes", "Draws hardware 2D bounding boxes around enemy players", false, function(state)
        _G.DarlingX_ESPBoxes = state
        local espMod = RequireModule("modules/visuals/esp.lua")
        if espMod and espMod.setBoxes then espMod.setBoxes(state) end
        Notify("ESP", "Player Boxes: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(espCard, "Player Name & Distance", "Displays overhead player name and distance in studs", false, function(state)
        _G.DarlingX_ESPNames = state
        Notify("ESP", "Names & Distance: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(espCard, "Player Health Status", "Shows live health bar indicator on tracked players", false, function(state)
        _G.DarlingX_ESPHealth = state
        Notify("ESP", "Health Status: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(espCard, "Fruit ESP Tracker", "Highlights natural and dropped devil fruits in server", false, function(state)
        _G.DarlingX_ESPFruits = state
        Notify("ESP", "Fruit Tracker: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(espCard, "Chest ESP Tracker", "Displays world treasure chest locations and tiers", false, function(state)
        _G.DarlingX_ESPChests = state
        Notify("ESP", "Chest Tracker: " .. (state and "Enabled" or "Disabled"))
    end)

    AddChoice(espCard, "ESP Accent Color", { "Purple", "White", "Red", "Green", "Blue", "Yellow", "Rainbow" }, 1, function(val)
        _G.DarlingX_ESPColor = val
        Notify("ESP", "ESP Color: " .. val)
    end)
end)

-- 6. MISC TAB
local MiscPage = RegisterTab("Misc", "Misc", "sliders-horizontal")
pcall(function()
    local serverCard = CreateCard(MiscPage, "Server & World Utilities")

    AddButton(serverCard, "Rejoin Current Server", function()
        pcall(function()
            local ts = game:GetService("TeleportService")
            ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, lp)
        end)
    end)

    AddButton(serverCard, "Server Hop (Low Ping)", function()
        pcall(function()
            Notify("Server", "Searching for low-ping server...")
        end)
    end)

    local clientCard = CreateCard(MiscPage, "Client Optimization & Render")

    AddToggle(clientCard, "Fast Textures (FPS Boost)", "Cleans intense particle emitters and textures for higher FPS", false, function(state)
        pcall(function()
            local lighting = game:GetService("Lighting")
            lighting.GlobalShadows = not state
        end)
        Notify("Graphics", "Fast Textures: " .. (state and "Enabled" or "Disabled"))
    end)

    AddToggle(clientCard, "Remove Atmosphere Fog", "Clears distance haze for maximum visual clarity", false, function(state)
        pcall(function()
            local lighting = game:GetService("Lighting")
            lighting.FogEnd = state and 100000 or 1000
        end)
        Notify("Graphics", "Fog: " .. (state and "Removed" or "Restored"))
    end)

    AddToggle(clientCard, "Fullbright Lighting", "Illuminates dark caves, dungeons, and night environments", false, function(state)
        pcall(function()
            local lighting = game:GetService("Lighting")
            lighting.Brightness = state and 2 or 1
            lighting.ClockTime = state and 14 or 12
        end)
        Notify("Lighting", "Fullbright: " .. (state and "Enabled" or "Disabled"))
    end)

    AddSlider(clientCard, "Camera Field of View", 70, 120, 70, 5, function(val)
        if camera then camera.FieldOfView = val end
    end)
end)

-- 7. THEMES & CUSTOMIZATION STUDIO (FULL LUXURY ENGINE)
local ThemesPage = RegisterTab("Themes", "Themes", "palette")
local SettingsPage = ThemesPage
local okThemes, errThemes = pcall(function()
    -- 1. Palette Studio (Presets & Accents)
    local themeCard = CreateCard(ThemesPage, "Accent Color & Theme Studio")

    local tGrid = Instance.new("Frame", themeCard)
    tGrid.Size = UDim2.new(1, 0, 0, 0)
    tGrid.AutomaticSize = Enum.AutomaticSize.Y
    tGrid.BackgroundTransparency = 1
    tGrid.ZIndex = 6
    local tgLayout = Instance.new("UIGridLayout", tGrid)
    tgLayout.CellSize = UDim2.new(0, 60, 0, 26)
    tgLayout.CellPadding = UDim2.new(0, 5, 0, 4)

    for _, name in ipairs(THEME_ORDER) do
        local col = THEMES[name]
        local tBtn = Instance.new("TextButton", tGrid)
        tBtn.BackgroundColor3 = col
        tBtn.Text = name
        tBtn.TextColor3 = (name == "White") and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
        tBtn.Font = Enum.Font.GothamBold
        tBtn.TextSize = 7.5
        tBtn.Active = true
        tBtn.Selectable = true
        tBtn.ZIndex = 7
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
    local wpCustomCard = CreateCard(ThemesPage, "Custom Wallpaper Studio")

    local customInput = AddInput(wpCustomCard, "Roblox Asset ID or Media URL", "e.g. 103674761222554 or rbxassetid://...", "", function(val)
        ApplyCustomWallpaper(val)
    end)

    local btnRow = Instance.new("Frame", wpCustomCard)
    btnRow.Size = UDim2.new(1, 0, 0, 28)
    btnRow.BackgroundTransparency = 1
    local bLayout = Instance.new("UIGridLayout", btnRow)
    bLayout.CellSize = UDim2.new(0.5, -4, 1, 0)
    bLayout.CellPadding = UDim2.new(0, 8, 0, 0)

    local applyBtn = Instance.new("TextButton", btnRow)
    applyBtn.BackgroundColor3 = Color3.fromRGB(24, 20, 36)
    applyBtn.BackgroundTransparency = 0.4
    applyBtn.Text = "Apply Wallpaper"
    applyBtn.Font = Enum.Font.GothamBold
    applyBtn.TextSize = 8.5
    applyBtn.TextColor3 = CurrentAccent
    applyBtn.Active = true
    applyBtn.Selectable = true
    RegisterThemeText(applyBtn)
    Instance.new("UICorner", applyBtn).CornerRadius = UDim.new(0, 6)
    local aStr = Instance.new("UIStroke", applyBtn)
    aStr.Color = CurrentAccent
    aStr.Thickness = 0.8
    RegisterThemeStroke(aStr)
    ConnectButton(applyBtn, function()
        ApplyCustomWallpaper(customInput.GetText())
    end)

    local clearBtn = Instance.new("TextButton", btnRow)
    clearBtn.BackgroundColor3 = Color3.fromRGB(24, 20, 36)
    clearBtn.BackgroundTransparency = 0.4
    clearBtn.Text = "Clear / Dark Glass"
    clearBtn.Font = Enum.Font.GothamBold
    clearBtn.TextSize = 8.5
    clearBtn.TextColor3 = Color3.fromRGB(200, 195, 215)
    clearBtn.Active = true
    clearBtn.Selectable = true
    Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0, 6)
    local cStr = Instance.new("UIStroke", clearBtn)
    cStr.Color = Color3.fromRGB(60, 55, 80)
    cStr.Thickness = 0.8
    ConnectButton(clearBtn, function()
        ApplyCustomWallpaper("none")
    end)

    -- 3. Wallpaper Atmosphere Presets (Full 24 Styles)
    local wpCard = CreateCard(ThemesPage, "Atmosphere Wallpaper Presets (24 Styles)")

    local wpStatus = Instance.new("TextLabel", wpCard)
    wpStatus.Size = UDim2.new(1, 0, 0, 20)
    wpStatus.BackgroundTransparency = 1
    wpStatus.Text = string.format("Active: [%02d/%02d] %s", currentBgIdx, #WALLPAPERS, WALLPAPERS[currentBgIdx].name)
    wpStatus.Font = Enum.Font.GothamBold
    wpStatus.TextSize = 9
    wpStatus.TextColor3 = CurrentAccent
    wpStatus.TextXAlignment = Enum.TextXAlignment.Left
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
    navRow.Size = UDim2.new(1, 0, 0, 28)
    navRow.BackgroundTransparency = 1

    local nLayout = Instance.new("UIGridLayout", navRow)
    nLayout.CellSize = UDim2.new(0.333, -5, 1, 0)
    nLayout.CellPadding = UDim2.new(0, 7, 0, 0)

    local function makeNavBtn(txt, callback)
        local btn = Instance.new("TextButton", navRow)
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
    presetGrid.Size = UDim2.new(1, 0, 0, 0)
    presetGrid.AutomaticSize = Enum.AutomaticSize.Y
    presetGrid.BackgroundTransparency = 1
    local pGLayout = Instance.new("UIGridLayout", presetGrid)
    pGLayout.CellSize = UDim2.new(0.5, -4, 0, 24)
    pGLayout.CellPadding = UDim2.new(0, 8, 0, 4)

    for i, wp in ipairs(WALLPAPERS) do
        local pBtn = Instance.new("TextButton", presetGrid)
        pBtn.BackgroundColor3 = Color3.fromRGB(20, 16, 28)
        pBtn.BackgroundTransparency = 0.55
        pBtn.Text = string.format("[%02d] %s", i, wp.name:sub(1, 16))
        pBtn.Font = Enum.Font.GothamBold
        pBtn.TextSize = 7.5
        pBtn.TextColor3 = Color3.fromRGB(220, 215, 240)
        pBtn.TextXAlignment = Enum.TextXAlignment.Center
        pBtn.Active = true
        pBtn.Selectable = true
        Instance.new("UICorner", pBtn).CornerRadius = UDim.new(0, 5)
        local pStr = Instance.new("UIStroke", pBtn)
        pStr.Color = (i == currentBgIdx) and CurrentAccent or Color3.fromRGB(45, 40, 60)
        pStr.Thickness = 0.8
        ConnectButton(pBtn, function()
            SetWallpaper(i)
        end)
    end

    AddSlider(wpCard, "Background Dimming (%)", 0, 85, math.floor(WallpaperDimOverlay.BackgroundTransparency * 100), 5, function(val)
        WallpaperDimOverlay.BackgroundTransparency = val / 100
    end)

    -- 3. Glass Interface & Visual Effects
    local vfxCard = CreateCard(ThemesPage, "Glass Interface & Visual Effects")

    AddToggle(vfxCard, "Neon Rain Layer", "Toggle animated falling cyber rain streaks", RainEnabled, function(state)
        RainEnabled = state
    end)

    AddSlider(vfxCard, "Raindrop Density", 4, 30, MaxRainDrops, 2, function(val)
        MaxRainDrops = val
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
    local presetCard = CreateCard(ThemesPage, "Aesthetic Studio Presets")

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
    local resetCard = CreateCard(ThemesPage, "Configuration Reset")
    AddButton(resetCard, "Reset All Settings to Factory Defaults", function()
        ResetUIConfig()
        Notify(APP_TITLE, "All UI settings reset to defaults")
    end)
end)
if not okThemes then
    warn("[Darling X] Failed to initialize ThemesPage: " .. tostring(errThemes))
end

-- ============================================================
-- INITIALIZATION
-- ============================================================
SelectTabById("Home")

playCinematicIntro(function()
    maximizeUI()
    Notify(APP_TITLE, "Version " .. APP_VERSION .. " loaded and ready.")
    print("[Darling X] Version " .. APP_VERSION .. " initialized successfully.")
end)

-- Global Mobility Handlers
UserInputService.JumpRequest:Connect(function()
    if _G.DarlingX_InfJump then
        pcall(function()
            local char = lp and lp.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end
end)

RunService.Stepped:Connect(function()
    if _G.DarlingX_Noclip then
        pcall(function()
            local char = lp and lp.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end
end)
