--[[
    PvP ESP Module
    Strictly player-only combat visuals.
    Dual Style Architecture:
      - Style 1: "2D Boxes" (2D Boxes, Dynamic Health Bars, Names, Distances, Tracers)
      - Style 2: "Overhead Billboard" (Overhead Billboard Tags with Team, Level, PvP status, Fruit, Bounty, Distance, HP%)
    Plus custom Player Highlight / Chams.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local ESP = {
    Enabled = false,
    Style = "2D Boxes", -- "2D Boxes" or "Overhead Billboard"
    
    -- Toggles
    Boxes = true,
    Names = true,
    Health = true,
    Distance = true,
    Fruit = true,
    Bounty = true,
    Level = true,
    Tool = true,
    PvPStatus = true,
    Chams = false,
    Tracers = false,
    
    -- Styling
    BoxColor = Color3.fromRGB(255, 255, 255),
    NameColor = Color3.fromRGB(255, 255, 255),
    TracerColor = Color3.fromRGB(255, 255, 255),
    ChamsColor = Color3.fromRGB(244, 63, 94),
    TextSize = 13,
    
    Cache = {},
    RenderConnection = nil,
}

local function getGuiParent()
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h and typeof(h) == "Instance" then return h end
    end
    if CoreGui then
        local testOk = pcall(function()
            local t = Instance.new("Folder")
            t.Parent = CoreGui
            t:Destroy()
        end)
        if testOk then return CoreGui end
    end
    local lp = LocalPlayer or Players.LocalPlayer
    return lp and lp:FindFirstChildOfClass("PlayerGui")
end

local OverlayGui = nil
local function getOverlayGui()
    if OverlayGui and OverlayGui.Parent then return OverlayGui end
    local parent = getGuiParent()
    local existing = parent and parent:FindFirstChild("DarlingPvPESPOverlay")
    if existing then
        OverlayGui = existing
        return OverlayGui
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "DarlingPvPESPOverlay"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 2147480000
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
    gui.Parent = parent
    OverlayGui = gui
    return gui
end

local function getTeamInfo(player)
    local team = player.Team and player.Team.Name or "Neutral"
    local color = Color3.fromRGB(255, 255, 255)
    if team:find("Pirate") then
        color = Color3.fromRGB(245, 60, 60)
    elseif team:find("Marine") then
        color = Color3.fromRGB(60, 140, 255)
    end
    return team, color
end

local function getPlayerData(player)
    local level = "--"
    local fruit = "None"
    local bounty = 0
    pcall(function()
        local data = player:FindFirstChild("Data")
        if data then
            local lvl = data:FindFirstChild("Level")
            if lvl then level = tostring(lvl.Value) end
            local df = data:FindFirstChild("DevilFruit")
            if df and df.Value and #tostring(df.Value) > 0 then
                fruit = tostring(df.Value):gsub("-%w+", "")
            end
        end
        local ls = player:FindFirstChild("leaderstats")
        if ls then
            local b = ls:FindFirstChild("Bounty/Honor") or ls:FindFirstChild("Bounty")
            if b then bounty = b.Value end
        end
    end)
    return level, fruit, bounty
end

local function cleanupEntry(entry)
    if not entry then return end
    if entry.Highlight then pcall(function() entry.Highlight:Destroy() end) end
    if entry.Container then pcall(function() entry.Container:Destroy() end) end
    if entry.BoxOutline then pcall(function() entry.BoxOutline:Destroy() end) end
    if entry.Billboard then pcall(function() entry.Billboard:Destroy() end) end
    if entry.TracerLine then pcall(function() entry.TracerLine:Destroy() end) end
end

local function createPlayerEntry(player)
    local overlay = getOverlayGui()
    if not overlay then return nil end

    local entry = {
        Player = player,
        BoxOutline = nil,
        Box = nil,
        HealthBarBg = nil,
        HealthBar = nil,
        NameLabel = nil,
        InfoLabel = nil,
        Billboard = nil,
        BillLabel = nil,
        Highlight = nil,
        TracerLine = nil,
    }

    -- 1. 2D Box System (Independent Container Frame)
    local container = Instance.new("Frame", overlay)
    container.Name = "PlayerESPContainer"
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    container.Visible = false

    local boxOutline = Instance.new("Frame", container)
    boxOutline.Name = "BoxOutline"
    boxOutline.BackgroundTransparency = 1
    boxOutline.BorderSizePixel = 0
    boxOutline.Size = UDim2.fromScale(1, 1)
    boxOutline.Visible = false

    local strokeOut = Instance.new("UIStroke", boxOutline)
    strokeOut.Color = Color3.fromRGB(0, 0, 0)
    strokeOut.Thickness = 2.0
    strokeOut.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local box = Instance.new("Frame", boxOutline)
    box.Name = "Box"
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Size = UDim2.fromScale(1, 1)

    local strokeIn = Instance.new("UIStroke", box)
    strokeIn.Color = ESP.BoxColor
    strokeIn.Thickness = 1.0
    strokeIn.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local hpBg = Instance.new("Frame", container)
    hpBg.Name = "HPBg"
    hpBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    hpBg.BorderSizePixel = 0
    hpBg.Size = UDim2.new(0, 3, 1, 0)
    hpBg.Position = UDim2.new(0, -6, 0, 0)

    local hpFill = Instance.new("Frame", hpBg)
    hpFill.Name = "HPFill"
    hpFill.BackgroundColor3 = Color3.fromRGB(16, 215, 135)
    hpFill.BorderSizePixel = 0
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.AnchorPoint = Vector2.new(0, 1)
    hpFill.Position = UDim2.new(0, 0, 1, 0)

    local nameLbl = Instance.new("TextLabel", container)
    nameLbl.Name = "NameLabel"
    nameLbl.BackgroundTransparency = 1
    nameLbl.Size = UDim2.new(1, 0, 0, 14)
    nameLbl.Position = UDim2.new(0, 0, 0, -16)
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = ESP.TextSize
    nameLbl.TextColor3 = ESP.NameColor
    nameLbl.TextStrokeTransparency = 0
    nameLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLbl.Text = player.DisplayName

    local infoLbl = Instance.new("TextLabel", container)
    infoLbl.Name = "InfoLabel"
    infoLbl.BackgroundTransparency = 1
    infoLbl.Size = UDim2.new(1, 0, 0, 13)
    infoLbl.Position = UDim2.new(0, 0, 1, 2)
    infoLbl.Font = Enum.Font.Gotham
    infoLbl.TextSize = math.max(ESP.TextSize - 2, 9)
    infoLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    infoLbl.TextStrokeTransparency = 0
    infoLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

    -- 2. Overhead Billboard System
    local bbg = Instance.new("BillboardGui")
    bbg.Name = "DarlingOverheadESP"
    bbg.Size = UDim2.new(0, 240, 0, 70)
    bbg.StudsOffset = Vector3.new(0, 3.2, 0)
    bbg.AlwaysOnTop = true
    bbg.MaxDistance = math.huge
    bbg.LightInfluence = 0
    bbg.Enabled = false
    bbg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local bLbl = Instance.new("TextLabel", bbg)
    bLbl.Size = UDim2.fromScale(1, 1)
    bLbl.BackgroundTransparency = 1
    bLbl.Font = Enum.Font.GothamBold
    bLbl.TextSize = ESP.TextSize
    bLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    bLbl.TextStrokeTransparency = 0
    bLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    bLbl.RichText = true
    bLbl.TextYAlignment = Enum.TextYAlignment.Bottom

    -- 3. Tracer Line
    local tracer = Instance.new("Frame", overlay)
    tracer.Name = "Tracer"
    tracer.BorderSizePixel = 0
    tracer.BackgroundColor3 = ESP.TracerColor
    tracer.BackgroundTransparency = 0.2
    tracer.AnchorPoint = Vector2.new(0.5, 0.5)
    tracer.Visible = false

    entry.Container = container
    entry.BoxOutline = boxOutline
    entry.Box = box
    entry.HealthBarBg = hpBg
    entry.HealthBar = hpFill
    entry.NameLabel = nameLbl
    entry.InfoLabel = infoLbl
    entry.Billboard = bbg
    entry.BillLabel = bLbl
    entry.TracerLine = tracer

    return entry
end

local function updateEntry(entry)
    local player = entry.Player
    if not player or not player.Parent then
        cleanupEntry(entry)
        return false
    end

    local char = player.Character
    if not char then
        if entry.Container then entry.Container.Visible = false end
        if entry.BoxOutline then entry.BoxOutline.Visible = false end
        if entry.Billboard then entry.Billboard.Enabled = false end
        if entry.TracerLine then entry.TracerLine.Visible = false end
        return true
    end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    local head = char:FindFirstChild("Head")

    if not hrp or not hum or hum.Health <= 0 then
        if entry.Container then entry.Container.Visible = false end
        if entry.BoxOutline then entry.BoxOutline.Visible = false end
        if entry.Billboard then entry.Billboard.Enabled = false end
        if entry.TracerLine then entry.TracerLine.Visible = false end
        return true
    end

    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local dist = myHRP and math.floor((hrp.Position - myHRP.Position).Magnitude) or 0
    local hpPct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
    local level, fruit, bounty = getPlayerData(player)
    local team, teamCol = getTeamInfo(player)

    -- Chams / Highlight
    if ESP.Chams then
        if not entry.Highlight or entry.Highlight.Parent ~= char then
            if entry.Highlight then pcall(function() entry.Highlight:Destroy() end) end
            pcall(function()
                local hl = Instance.new("Highlight")
                hl.Name = "DarlingChams"
                hl.FillColor = ESP.ChamsColor
                hl.FillTransparency = 0.4
                hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                hl.OutlineTransparency = 0.1
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Adornee = char
                hl.Parent = char
                entry.Highlight = hl
            end)
        else
            pcall(function()
                entry.Highlight.FillColor = ESP.ChamsColor
                entry.Highlight.Enabled = true
            end)
        end
    else
        if entry.Highlight then
            pcall(function() entry.Highlight.Enabled = false end)
        end
    end

    if ESP.Style == "Overhead Billboard" then
        -- Hide 2D Box
        if entry.Container then entry.Container.Visible = false end
        if entry.BoxOutline then entry.BoxOutline.Visible = false end

        -- Attach Billboard
        local parentTarget = head or hrp
        pcall(function()
            if entry.Billboard.Adornee ~= parentTarget then
                entry.Billboard.Adornee = parentTarget
                entry.Billboard.Parent = parentTarget
            end
        end)

        local pvpState = "[PVP ON]"
        if player:GetAttribute("PvpDisabled") == true then
            pvpState = "[PVP OFF]"
        end

        local bountyStr = math.floor(bounty / 1000000) .. "M"
        if bounty < 1000000 then bountyStr = math.floor(bounty / 1000) .. "K" end

        local textParts = {}
        if ESP.Names then
            local nStr = string.format("[%s] %s", team, player.DisplayName)
            if ESP.Level then nStr = nStr .. string.format(" [Lv.%s]", level) end
            table.insert(textParts, nStr)
        end
        if ESP.PvPStatus then
            table.insert(textParts, pvpState)
        end
        if ESP.Tool then
            local heldTool = char:FindFirstChildOfClass("Tool")
            if heldTool then table.insert(textParts, "Tool: " .. heldTool.Name) end
        end
        if ESP.Fruit and fruit ~= "None" then
            table.insert(textParts, "Fruit: " .. fruit)
        end
        if ESP.Bounty and bounty > 0 then
            table.insert(textParts, "Bounty: " .. bountyStr)
        end
        if ESP.Distance or ESP.Health then
            local sub = ""
            if ESP.Distance then sub = sub .. dist .. "m" end
            if ESP.Distance and ESP.Health then sub = sub .. " | " end
            if ESP.Health then sub = sub .. "HP " .. math.floor(hpPct * 100) .. "%" end
            table.insert(textParts, sub)
        end

        entry.BillLabel.Text = table.concat(textParts, "\n")
        entry.BillLabel.TextColor3 = teamCol
        entry.BillLabel.TextSize = ESP.TextSize
        entry.Billboard.Enabled = true

    else
        -- Style 1: 2D Boxes
        if entry.Billboard then entry.Billboard.Enabled = false end

        local cam = Workspace.CurrentCamera
        if not cam then return true end

        local hrpPos, onScreen = cam:WorldToViewportPoint(hrp.Position)
        if not onScreen or hrpPos.Z <= 0 then
            if entry.Container then entry.Container.Visible = false end
            if entry.BoxOutline then entry.BoxOutline.Visible = false end
            if entry.TracerLine then entry.TracerLine.Visible = false end
            return true
        end

        local headPos = cam:WorldToViewportPoint(hrp.Position + Vector3.new(0, 2.8, 0))
        local footPos = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.2, 0))
        local rawHeight = math.abs(headPos.Y - footPos.Y)
        local height = math.clamp(rawHeight, 14, 2000)
        local width = math.clamp(height * 0.65, 10, 1400)

        local boxX = hrpPos.X - width / 2
        local boxY = hrpPos.Y - height / 2

        if entry.Container then
            entry.Container.Position = UDim2.fromOffset(boxX, boxY)
            entry.Container.Size = UDim2.fromOffset(width, height)
            entry.Container.Visible = (ESP.Boxes or ESP.Health or ESP.Names or (ESP.Distance or ESP.Fruit or ESP.Tool or ESP.Bounty))
        end

        entry.BoxOutline.Visible = ESP.Boxes

        local inStroke = entry.Box:FindFirstChildOfClass("UIStroke")
        if inStroke then inStroke.Color = ESP.BoxColor end

        -- Health bar
        entry.HealthBarBg.Visible = ESP.Health
        if ESP.Health then
            entry.HealthBar.Size = UDim2.new(1, 0, hpPct, 0)
            if hpPct > 0.5 then
                entry.HealthBar.BackgroundColor3 = Color3.fromRGB(16, 215, 135)
            elseif hpPct > 0.25 then
                entry.HealthBar.BackgroundColor3 = Color3.fromRGB(245, 180, 20)
            else
                entry.HealthBar.BackgroundColor3 = Color3.fromRGB(245, 60, 60)
            end
        end

        -- Name label
        entry.NameLabel.Visible = ESP.Names
        if ESP.Names then
            local nStr = player.DisplayName
            if ESP.Level then nStr = nStr .. string.format(" [Lv.%s]", level) end
            entry.NameLabel.Text = nStr
            entry.NameLabel.TextColor3 = ESP.NameColor
            entry.NameLabel.TextSize = ESP.TextSize
        end

        -- Info label (Multi-info below feet)
        entry.InfoLabel.Visible = (ESP.Distance or ESP.Fruit or ESP.Tool or ESP.Bounty)
        if entry.InfoLabel.Visible then
            local infoParts = {}
            if ESP.Distance then table.insert(infoParts, dist .. " studs") end
            if ESP.Tool then
                local heldTool = char:FindFirstChildOfClass("Tool")
                if heldTool then table.insert(infoParts, heldTool.Name) end
            end
            if ESP.Fruit and fruit ~= "None" then table.insert(infoParts, fruit) end
            if ESP.Bounty and bounty > 0 then table.insert(infoParts, bountyStr) end
            entry.InfoLabel.Text = table.concat(infoParts, " | ")
        end
    end

    -- Tracers
    if ESP.Tracers and entry.TracerLine then
        local cam = Workspace.CurrentCamera
        local hrpPos, onScreen = cam:WorldToViewportPoint(hrp.Position)
        if onScreen then
            local origin = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
            local target = Vector2.new(hrpPos.X, hrpPos.Y)
            local delta = target - origin
            local len = delta.Magnitude
            local angle = math.atan2(delta.Y, delta.X)

            entry.TracerLine.Position = UDim2.fromOffset(origin.X + delta.X / 2, origin.Y + delta.Y / 2)
            entry.TracerLine.Size = UDim2.fromOffset(len, 1.5)
            entry.TracerLine.Rotation = math.deg(angle)
            entry.TracerLine.BackgroundColor3 = ESP.TracerColor
            entry.TracerLine.Visible = true
        else
            entry.TracerLine.Visible = false
        end
    else
        if entry.TracerLine then entry.TracerLine.Visible = false end
    end

    return true
end

local function onRender()
    if not ESP.Enabled then return end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local entry = ESP.Cache[p]
            if not entry then
                entry = createPlayerEntry(p)
                if entry then ESP.Cache[p] = entry end
            end
            if entry then
                updateEntry(entry)
            end
        end
    end
end

function ESP.enable()
    if ESP.Enabled then return end
    ESP.Enabled = true
    if not ESP.RenderConnection then
        ESP.RenderConnection = RunService.RenderStepped:Connect(onRender)
    end
end

function ESP.disable()
    ESP.Enabled = false
    if ESP.RenderConnection then
        pcall(function() ESP.RenderConnection:Disconnect() end)
        ESP.RenderConnection = nil
    end
    for p, entry in pairs(ESP.Cache) do
        cleanupEntry(entry)
    end
    table.clear(ESP.Cache)
    if OverlayGui then
        pcall(function() OverlayGui:Destroy() end)
        OverlayGui = nil
    end
end

function ESP.toggle(state)
    if state == nil then state = not ESP.Enabled end
    if state then ESP.enable() else ESP.disable() end
end

Players.PlayerRemoving:Connect(function(p)
    if ESP.Cache[p] then
        cleanupEntry(ESP.Cache[p])
        ESP.Cache[p] = nil
    end
end)

return ESP
