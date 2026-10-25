--[[
    H3Y0 M0NST3R v9
    Gradient Mode: Solid / Rainbow / Animated / Linear / Mirror Linear / Pulse
    Neon: симметричный ореол вокруг линии (плюс и минус offset)
    Квадратная палитра, drag за заголовок, dropdown шрифтов,
    Hide Game Crosshair, CFG Manager, AutoLoad, Unload, RightShift
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ROOT = "H3Y0_M0NST3R"
local CFG_DIR = ROOT .. "/cfg"
local AUTOLOAD_FILE = ROOT .. "/autoload.txt"

local hasFS = (type(writefile) == "function" and type(readfile) == "function")
if hasFS and type(makefolder) == "function" then
    pcall(function()
        if not isfolder(ROOT) then makefolder(ROOT) end
        if not isfolder(CFG_DIR) then makefolder(CFG_DIR) end
    end)
end

local GRAD_MODES = { "Solid", "Rainbow", "Animated", "Linear", "Mirror Linear", "Pulse" }
local TEXT_COLOR_MODES = { "Follow", "Solid" }
local FONTS = {
    UI        = Drawing.Fonts.UI,
    System    = Drawing.Fonts.System,
    Plex      = Drawing.Fonts.Plex,
    Monospace = Drawing.Fonts.Monospace,
}
local FONT_NAMES = { "UI", "System", "Plex", "Monospace", "Minecraft", "Fortnite" }

local function DefaultCfg()
    return {
        Enabled = true,
        Length = 8, Thickness = 2, Gap = 6,
        Rotate = false, RotSpeed = 2,
        Pulse = false, PulseSpeed = 3, PulseRange = 2,
        HideCursor = true, HideGameCrosshair = true,

        Neon = true,
        NeonWidth = 4,
        NeonLayers = 4,
        NeonAlpha = 0.55,

        GradientMode = "Rainbow",
        GradientSpeed = 1,
        SolidColor = Color3.fromRGB(255, 255, 255),
        GradientColors = {
            Color3.fromRGB(255, 40, 90),
            Color3.fromRGB(180, 40, 255),
            Color3.fromRGB(40, 200, 255),
        },

        TextEnabled = true,
        Text = "H3Y0 M0NST3R",
        TextSize = 14,
        TextColorMode = "Follow",
        TextColor = Color3.fromRGB(255, 255, 255),
        TextFont = "Plex",
        TextNeon = true,

        ToggleKey = Enum.KeyCode.RightShift,
        AutoLoad = false,
    }
end

local Cfg = DefaultCfg()

local function GetFontFace(name)
    if name == "Minecraft" then return FONTS.Monospace end
    if name == "Fortnite"  then return FONTS.Plex      end
    return FONTS[name] or FONTS.Plex
end

local function BlendColors(colors, t)
    if not colors or #colors == 0 then return Color3.new(1,1,1) end
    if #colors == 1 then return colors[1] end
    local n = #colors
    local pos = (t % 1) * n
    local i1 = math.floor(pos) + 1
    local i2 = (i1 % n) + 1
    local frac = pos - math.floor(pos)
    return colors[i1]:Lerp(colors[i2], frac)
end

local function EncodeColor(c) return { c.R, c.G, c.B } end
local function DecodeColor(t) return Color3.new(t[1], t[2], t[3]) end

-- ============================================
-- ГРАДИЕНТ
-- ============================================
local function EvalGradient(mode, t01, phase)
    if mode == "Solid" then
        return Cfg.SolidColor
    elseif mode == "Rainbow" then
        -- HSV радуга, крутится по времени + смещение вдоль линии
        return Color3.fromHSV((phase + t01 * 0.5) % 1, 1, 1)
    elseif mode == "Animated" then
        -- твоя палитра, плавно двигается
        return BlendColors(Cfg.GradientColors, phase + t01 * 0.3)
    elseif mode == "Linear" then
        -- статично, от начала к концу
        return BlendColors(Cfg.GradientColors, t01)
    elseif mode == "Mirror Linear" then
        -- симметрично от центра (0 -> 1 -> 0)
        return BlendColors(Cfg.GradientColors, 1 - math.abs(t01 * 2 - 1))
    elseif mode == "Pulse" then
        -- вся палитра синхронно, независимо от позиции
        return BlendColors(Cfg.GradientColors, phase)
    else
        return Cfg.SolidColor
    end
end

-- ============================================
-- CFG
-- ============================================
local function SerializeCfg()
    local data = {}
    for k, v in pairs(Cfg) do
        if k == "ToggleKey" then data[k] = v.Name
        elseif k == "GradientColors" then
            data[k] = {}
            for i, c in ipairs(v) do data[k][i] = EncodeColor(c) end
        elseif typeof(v) == "Color3" then data[k] = EncodeColor(v)
        else data[k] = v end
    end
    return data
end
local function ApplyCfg(data)
    if type(data) ~= "table" then return end
    for k, v in pairs(data) do
        if k == "ToggleKey" then Cfg[k] = Enum.KeyCode[v] or Cfg[k]
        elseif k == "GradientColors" and type(v) == "table" then
            Cfg[k] = {}
            for _, t in ipairs(v) do
                if type(t) == "table" then table.insert(Cfg[k], DecodeColor(t)) end
            end
        elseif Cfg[k] ~= nil then Cfg[k] = v end
    end
end
local function SaveCfgFile(name)
    if not hasFS then return false, "no filesystem" end
    local ok, json = pcall(function()
        return game:GetService("HttpService"):JSONEncode(SerializeCfg())
    end)
    if not ok then return false, "encode error" end
    pcall(writefile, CFG_DIR .. "/" .. name .. ".json", json)
    return true
end
local function LoadCfgFile(name)
    if not hasFS then return false, "no filesystem" end
    local path = CFG_DIR .. "/" .. name .. ".json"
    if not isfile(path) then return false, "no file" end
    local ok, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(readfile(path))
    end)
    if not ok then return false, "decode error" end
    ApplyCfg(data); return true
end
local function DeleteCfgFile(name)
    if not hasFS then return false end
    local path = CFG_DIR .. "/" .. name .. ".json"
    if not isfile(path) then return false end
    pcall(delfile, path); return true
end
local function ListCfgFiles()
    local out = {}
    if not hasFS or type(listfiles) ~= "function" then return out end
    local ok, files = pcall(listfiles, CFG_DIR)
    if not ok then return out end
    for _, f in ipairs(files) do
        local name = f:match("([^/\\]+)%.json$")
        if name then table.insert(out, name) end
    end
    return out
end
local function SetAutoLoad(name)
    if not hasFS then return end
    pcall(writefile, AUTOLOAD_FILE, name or "")
end
local function GetAutoLoad()
    if not hasFS or type(isfile) ~= "function" then return nil end
    if not isfile(AUTOLOAD_FILE) then return nil end
    local ok, s = pcall(readfile, AUTOLOAD_FILE)
    if not ok or s == "" then return nil end
    return s
end

-- ============================================
-- HIDE GAME CROSSHAIR
-- ============================================
local HiddenGuiInstances = {}
local function HideGameCrosshair()
    pcall(function() StarterGui:SetCore("TopbarEnabled", false) end)
    local function hideIfMatch(obj)
        if not obj or not obj.Parent then return end
        local n = string.lower(obj.Name)
        if n:find("crosshair") or n:find("reticle") or n:find("aim") then
            if obj.Visible ~= false then
                obj.Visible = false
                table.insert(HiddenGuiInstances, obj)
            end
        end
    end
    for _, obj in ipairs(PlayerGui:GetDescendants()) do hideIfMatch(obj) end
    pcall(function()
        for _, obj in ipairs(game:GetService("CoreGui"):GetDescendants()) do hideIfMatch(obj) end
    end)
end
local function RestoreGameCrosshair()
    for _, obj in ipairs(HiddenGuiInstances) do
        pcall(function() obj.Visible = true end)
    end
    HiddenGuiInstances = {}
end
local function ApplyHideGameCrosshair(enabled)
    if enabled then HideGameCrosshair() else RestoreGameCrosshair() end
end

local pgConn = PlayerGui.DescendantAdded:Connect(function(obj)
    if Cfg.HideGameCrosshair then
        local n = string.lower(obj.Name)
        if n:find("crosshair") or n:find("reticle") or n:find("aim") then
            task.defer(function()
                if obj.Parent and obj.Visible ~= false then
                    obj.Visible = false
                    table.insert(HiddenGuiInstances, obj)
                end
            end)
        end
    end
end)

-- ============================================
-- DRAWING
-- ============================================
local SEG = 12
local MAX_NEON_LAYERS = 6
local TEXT_GLOW_COPIES = 8
local TEXT_GLOW_RADIUS = 1.5

local CoreSegs = {}
local NeonPos, NeonNeg = {}, {}   -- два набора ring-линий (положительный и отрицательный offset)

for i = 1, 4 do
    CoreSegs[i] = {}
    NeonPos[i] = {}
    NeonNeg[i] = {}
    for s = 1, SEG do
        CoreSegs[i][s] = Drawing.new("Line")
        CoreSegs[i][s].Visible = false

        NeonPos[i][s] = {}
        NeonNeg[i][s] = {}
        for l = 1, MAX_NEON_LAYERS do
            local p = Drawing.new("Line"); p.Visible = false
            local n = Drawing.new("Line"); n.Visible = false
            NeonPos[i][s][l] = p
            NeonNeg[i][s][l] = n
        end
    end
end

local TextLayers = {}
local function BuildTextLayers()
    for _, t in ipairs(TextLayers) do pcall(function() t:Remove() end) end
    TextLayers = {}
    local face = GetFontFace(Cfg.TextFont)
    for i = 1, 1 + TEXT_GLOW_COPIES do
        local t = Drawing.new("Text")
        t.Center = true
        t.Font = face
        t.Outline = (i == 1)
        t.OutlineColor = Color3.new(0, 0, 0)
        t.Transparency = 1
        t.Visible = false
        TextLayers[i] = t
    end
end
BuildTextLayers()

local angle, pulseTime, gradPhase = 0, 0, 0
local Unloaded = false
local ActiveConnections = { pgConn }
local ScreenGui

local function SetCursorHidden(hidden)
    UserInputService.MouseIconEnabled = not hidden
end

local function Unload()
    if Unloaded then return end
    Unloaded = true
    for _, c in ipairs(ActiveConnections) do pcall(function() c:Disconnect() end) end
    for i = 1, 4 do
        for s = 1, SEG do
            pcall(function() CoreSegs[i][s]:Remove() end)
            for l = 1, MAX_NEON_LAYERS do
                pcall(function() NeonPos[i][s][l]:Remove() end)
                pcall(function() NeonNeg[i][s][l]:Remove() end)
            end
        end
    end
    for _, t in ipairs(TextLayers) do pcall(function() t:Remove() end) end
    pcall(function() UserInputService.MouseIconEnabled = true end)
    RestoreGameCrosshair()
    if ScreenGui then pcall(function() ScreenGui:Destroy() end) end
end

local function HideAll()
    for i = 1, 4 do
        for s = 1, SEG do
            CoreSegs[i][s].Visible = false
            for l = 1, MAX_NEON_LAYERS do
                NeonPos[i][s][l].Visible = false
                NeonNeg[i][s][l].Visible = false
            end
        end
    end
    for _, t in ipairs(TextLayers) do t.Visible = false end
end

-- ============================================
-- RENDER
-- ============================================
local renderConn = RunService.RenderStepped:Connect(function(dt)
    if Unloaded then return end

    if not Cfg.Enabled then
        HideAll()
        SetCursorHidden(false)
        return
    end

    SetCursorHidden(Cfg.HideCursor)

    local m = UserInputService:GetMouseLocation()
    local cx, cy = m.X, m.Y

    if Cfg.Rotate then angle = (angle + Cfg.RotSpeed * dt * 60) % 360 end
    if Cfg.Pulse then pulseTime = pulseTime + Cfg.PulseSpeed * dt end
    local pulse = Cfg.Pulse and math.sin(pulseTime * 6) * Cfg.PulseRange or 0

    if Cfg.GradientMode == "Rainbow" or Cfg.GradientMode == "Animated" or Cfg.GradientMode == "Pulse" then
        gradPhase = (gradPhase + Cfg.GradientSpeed * dt * 0.4) % 1
    end

    local gap = Cfg.Gap + pulse
    local len = Cfg.Length + pulse * 0.5

    local neonLayers = math.clamp(math.floor(Cfg.NeonLayers + 0.5), 1, MAX_NEON_LAYERS)
    local neonWidth = Cfg.NeonWidth
    local neonAlpha = math.clamp(Cfg.NeonAlpha, 0, 0.95)
    local step = neonWidth / (neonLayers + 1)

    for i = 1, 4 do
        local a = math.rad(angle + (i - 1) * 90)
        local dx, dy = math.cos(a), math.sin(a)
        local normalX = -dy
        local normalY = dx

        local fromX, fromY = cx + dx * gap,         cy + dy * gap
        local toX,   toY   = cx + dx * (gap + len), cy + dy * (gap + len)

        for s = 1, SEG do
            local t1 = (s - 1) / SEG
            local t2 = s / SEG
            local sx1 = fromX + (toX - fromX) * t1
            local sy1 = fromY + (toY - fromY) * t1
            local sx2 = fromX + (toX - fromX) * t2
            local sy2 = fromY + (toY - fromY) * t2

            local col = EvalGradient(Cfg.GradientMode, t1, gradPhase)

            -- ядро
            local core = CoreSegs[i][s]
            core.From = Vector2.new(sx1, sy1)
            core.To   = Vector2.new(sx2, sy2)
            core.Thickness = Cfg.Thickness
            core.Color = col
            core.Transparency = 1
            core.Visible = true

            -- ореол: симметрично с двух сторон линии
            if Cfg.Neon then
                for l = 1, neonLayers do
                    local offset = step * l
                    local thickness = math.max(Cfg.Thickness * (1 - (l - 1) / (neonLayers + 1)), 0.5)
                    local alpha = neonAlpha * (1 - (l - 1) / (neonLayers + 1))

                    local p = NeonPos[i][s][l]
                    p.From = Vector2.new(sx1 + normalX * offset, sy1 + normalY * offset)
                    p.To   = Vector2.new(sx2 + normalX * offset, sy2 + normalY * offset)
                    p.Thickness = thickness
                    p.Color = col
                    p.Transparency = 1 - alpha
                    p.Visible = alpha > 0.02

                    local n = NeonNeg[i][s][l]
                    n.From = Vector2.new(sx1 - normalX * offset, sy1 - normalY * offset)
                    n.To   = Vector2.new(sx2 - normalX * offset, sy2 - normalY * offset)
                    n.Thickness = thickness
                    n.Color = col
                    n.Transparency = 1 - alpha
                    n.Visible = alpha > 0.02
                end
                for l = neonLayers + 1, MAX_NEON_LAYERS do
                    NeonPos[i][s][l].Visible = false
                    NeonNeg[i][s][l].Visible = false
                end
            else
                for l = 1, MAX_NEON_LAYERS do
                    NeonPos[i][s][l].Visible = false
                    NeonNeg[i][s][l].Visible = false
                end
            end
        end
    end

    -- Текст
    local hideAllText = not (Cfg.TextEnabled and Cfg.Text ~= "")
    if not hideAllText then
        local textY = cy + gap + len + 8
        local tcol
        if Cfg.TextColorMode == "Solid" then
            tcol = Cfg.TextColor
        else
            if Cfg.GradientMode == "Solid" then
                tcol = Cfg.SolidColor
            elseif Cfg.GradientMode == "Rainbow" then
                tcol = Color3.fromHSV((gradPhase + 0.25) % 1, 1, 1)
            else
                tcol = BlendColors(Cfg.GradientColors, gradPhase)
            end
        end

        local main = TextLayers[1]
        if main then
            main.Text = Cfg.Text
            main.Size = Cfg.TextSize
            main.Position = Vector2.new(cx, textY)
            main.Color = tcol
            main.Transparency = 1
            main.Visible = true
        end
        for j = 1, TEXT_GLOW_COPIES do
            local t = TextLayers[j + 1]
            if t then
                local ang = (j / TEXT_GLOW_COPIES) * math.pi * 2
                local ox = math.cos(ang) * TEXT_GLOW_RADIUS
                local oy = math.sin(ang) * TEXT_GLOW_RADIUS
                t.Text = Cfg.Text
                t.Size = Cfg.TextSize
                t.Position = Vector2.new(cx + ox, textY + oy)
                t.Color = tcol
                t.Outline = false
                t.Transparency = Cfg.TextNeon and 0.45 or 1
                t.Visible = Cfg.TextNeon
            end
        end
    else
        for _, t in ipairs(TextLayers) do t.Visible = false end
    end
end)
table.insert(ActiveConnections, renderConn)

-- ============================================
-- UI
-- ============================================
ScreenGui = Instance.new("ScreenGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 440, 0, 520)
Main.Position = UDim2.new(0, 20, 0, 60)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Main.BorderSizePixel = 0
Main.Active = false
Main.Draggable = false
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 28)
Title.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
Title.Text = "H3Y0 M0NST3R"
Title.TextColor3 = Color3.fromRGB(200, 100, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.Active = true
Title.Parent = Main
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 8)

do
    local dragStart, startPos
    Title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragStart = input.Position
            startPos = Main.Position
            local conn
            conn = UserInputService.InputChanged:Connect(function(e)
                if e.UserInputType == Enum.UserInputType.MouseMovement
                or e.UserInputType == Enum.UserInputType.Touch then
                    local delta = e.Position - dragStart
                    Main.Position = UDim2.new(
                        startPos.X.Scale, startPos.X.Offset + delta.X,
                        startPos.Y.Scale, startPos.Y.Offset + delta.Y
                    )
                end
            end)
            local endConn
            endConn = UserInputService.InputEnded:Connect(function(e)
                if e.UserInputType == Enum.UserInputType.MouseButton1
                or e.UserInputType == Enum.UserInputType.Touch then
                    if conn then conn:Disconnect() end
                    if endConn then endConn:Disconnect() end
                end
            end)
        end
    end)
end

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -12, 0, 28)
TabBar.Position = UDim2.new(0, 6, 0, 32)
TabBar.BackgroundTransparency = 1
TabBar.Parent = Main
local TabBarLayout = Instance.new("UIListLayout")
TabBarLayout.FillDirection = Enum.FillDirection.Horizontal
TabBarLayout.Padding = UDim.new(0, 4)
TabBarLayout.Parent = TabBar

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -12, 1, -68)
Content.Position = UDim2.new(0, 6, 0, 64)
Content.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
Content.BorderSizePixel = 0
Content.Parent = Main
Instance.new("UICorner", Content).CornerRadius = UDim.new(0, 6)

-- фабрики
local function MakeToggle(parent, name, default, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -8, 0, 24)
    f.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -36, 1, 0); l.Position = UDim2.new(0, 8, 0, 0)
    l.BackgroundTransparency = 1; l.Text = name
    l.TextColor3 = Color3.fromRGB(200, 200, 210)
    l.Font = Enum.Font.Gotham; l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 18, 0, 18); b.Position = UDim2.new(1, -22, 0.5, -9)
    b.BackgroundColor3 = default and Color3.fromRGB(100, 60, 160) or Color3.fromRGB(40, 40, 55)
    b.Text = default and "✓" or ""
    b.TextColor3 = Color3.new(1, 1, 1); b.Font = Enum.Font.GothamBold; b.TextSize = 10
    b.Parent = f
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 3)
    local s = default
    local function set(v)
        s = v
        b.BackgroundColor3 = s and Color3.fromRGB(100, 60, 160) or Color3.fromRGB(40, 40, 55)
        b.Text = s and "✓" or ""
    end
    b.MouseButton1Click:Connect(function() set(not s); cb(s) end)
    return set
end

local function MakeSlider(parent, name, min, max, default, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -8, 0, 38)
    f.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -16, 0, 14); l.Position = UDim2.new(0, 8, 0, 2)
    l.BackgroundTransparency = 1; l.Text = name .. ": " .. string.format("%.1f", default)
    l.TextColor3 = Color3.fromRGB(200, 200, 210)
    l.Font = Enum.Font.Gotham; l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -16, 0, 5); bar.Position = UDim2.new(0, 8, 0, 24)
    bar.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    bar.Parent = f
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 2)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(100, 60, 160)
    fill.Parent = bar
    local function upd(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local v = min + (max - min) * rel
        fill.Size = UDim2.new(rel, 0, 1, 0)
        l.Text = name .. ": " .. string.format("%.1f", v)
        cb(v)
    end
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            upd(i.Position.X)
            local c
            c = UserInputService.InputChanged:Connect(function(e)
                if e.UserInputType == Enum.UserInputType.MouseMovement then upd(e.Position.X) end
            end)
            UserInputService.InputEnded:Connect(function(e)
                if e.UserInputType == Enum.UserInputType.MouseButton1 and c then c:Disconnect() end
            end)
        end
    end)
end

local function MakeTextBox(parent, placeholder, default, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -8, 0, 26)
    f.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -12, 1, 0); box.Position = UDim2.new(0, 6, 0, 0)
    box.BackgroundTransparency = 1
    box.Text = default or ""; box.PlaceholderText = placeholder
    box.TextColor3 = Color3.fromRGB(200, 200, 210)
    box.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
    box.Font = Enum.Font.Gotham; box.TextSize = 11
    box.ClearTextOnFocus = false
    box.Parent = f
    box.FocusLost:Connect(function() cb(box.Text) end)
end

local function MakeDropdown(parent, name, list, default, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -8, 0, 24)
    f.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -12, 1, 0); b.Position = UDim2.new(0, 6, 0, 0)
    b.BackgroundTransparency = 1
    b.Text = name .. ": " .. tostring(default)
    b.TextColor3 = Color3.fromRGB(200, 200, 210)
    b.Font = Enum.Font.Gotham; b.TextSize = 11
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Parent = f

    local listFrame = Instance.new("Frame")
    listFrame.Size = UDim2.new(1, -8, 0, #list * 22 + 4)
    listFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    listFrame.BorderSizePixel = 0
    listFrame.Visible = false
    listFrame.ZIndex = 10
    listFrame.Parent = parent
    Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 4)
    local ll = Instance.new("UIListLayout")
    ll.Padding = UDim.new(0, 2)
    ll.Parent = listFrame

    local function set(v)
        b.Text = name .. ": " .. tostring(v)
        cb(v)
        listFrame.Visible = false
    end

    for _, item in ipairs(list) do
        local ib = Instance.new("TextButton")
        ib.Size = UDim2.new(1, -4, 0, 20)
        ib.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        ib.Text = item
        ib.TextColor3 = Color3.fromRGB(200, 200, 210)
        ib.Font = Enum.Font.Gotham
        ib.TextSize = 11
        ib.ZIndex = 11
        ib.Parent = listFrame
        Instance.new("UICorner", ib).CornerRadius = UDim.new(0, 3)
        ib.MouseButton1Click:Connect(function() set(item) end)
    end

    b.MouseButton1Click:Connect(function()
        listFrame.Visible = not listFrame.Visible
    end)
    return set
end

local function MakeButton(parent, text, cb, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -8, 0, 24)
    b.BackgroundColor3 = color or Color3.fromRGB(45, 35, 60)
    b.Text = text
    b.TextColor3 = Color3.fromRGB(220, 180, 255)
    b.Font = Enum.Font.Gotham; b.TextSize = 11
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    b.MouseButton1Click:Connect(cb)
    return b
end

-- ============================================
-- ВКЛАДКИ
-- ============================================
local Tabs, TabButtons = {}, {}
local function MakeTab(name)
    local scrolling = Instance.new("ScrollingFrame")
    scrolling.Size = UDim2.new(1, -12, 1, -12)
    scrolling.Position = UDim2.new(0, 6, 0, 6)
    scrolling.BackgroundTransparency = 1
    scrolling.BorderSizePixel = 0
    scrolling.ScrollBarThickness = 3
    scrolling.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrolling.Visible = false
    scrolling.Parent = Content
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.Parent = scrolling
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrolling.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end)
    Tabs[name] = scrolling

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 80, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(200, 200, 210)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = TabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    TabButtons[name] = btn

    btn.MouseButton1Click:Connect(function()
        for tabName, scroll in pairs(Tabs) do
            scroll.Visible = tabName == name
            TabButtons[tabName].BackgroundColor3 = tabName == name
                and Color3.fromRGB(100, 60, 160)
                or Color3.fromRGB(28, 28, 38)
        end
    end)
    return scrolling
end

-- CROSSHAIR
local tabCross = MakeTab("Crosshair")
MakeToggle(tabCross, "Enabled", Cfg.Enabled, function(v) Cfg.Enabled = v end)
MakeSlider(tabCross, "Length", 2, 100, Cfg.Length, function(v) Cfg.Length = v end)
MakeSlider(tabCross, "Thickness", 1, 20, Cfg.Thickness, function(v) Cfg.Thickness = v end)
MakeSlider(tabCross, "Gap", 0, 60, Cfg.Gap, function(v) Cfg.Gap = v end)
MakeToggle(tabCross, "Rotate", Cfg.Rotate, function(v) Cfg.Rotate = v end)
MakeSlider(tabCross, "Rot Speed", 1, 15, Cfg.RotSpeed, function(v) Cfg.RotSpeed = v end)
MakeToggle(tabCross, "Pulse", Cfg.Pulse, function(v) Cfg.Pulse = v end)
MakeSlider(tabCross, "Pulse Speed", 1, 15, Cfg.PulseSpeed, function(v) Cfg.PulseSpeed = v end)
MakeSlider(tabCross, "Pulse Range", 1, 20, Cfg.PulseRange, function(v) Cfg.PulseRange = v end)
MakeToggle(tabCross, "Hide Cursor", Cfg.HideCursor, function(v) Cfg.HideCursor = v end)
MakeToggle(tabCross, "Hide Game Crosshair", Cfg.HideGameCrosshair, function(v)
    Cfg.HideGameCrosshair = v
    ApplyHideGameCrosshair(v)
end)

-- NEON
local tabNeon = MakeTab("Neon")
MakeToggle(tabNeon, "Neon", Cfg.Neon, function(v) Cfg.Neon = v end)
MakeSlider(tabNeon, "Neon Width", 1, 12, Cfg.NeonWidth, function(v) Cfg.NeonWidth = v end)
MakeSlider(tabNeon, "Neon Layers", 1, 6, Cfg.NeonLayers, function(v) Cfg.NeonLayers = math.floor(v + 0.5) end)
MakeSlider(tabNeon, "Neon Alpha", 0.1, 0.95, Cfg.NeonAlpha, function(v) Cfg.NeonAlpha = v end)

-- GRADIENT
local tabGrad = MakeTab("Gradient")
MakeDropdown(tabGrad, "Gradient Mode", GRAD_MODES, Cfg.GradientMode, function(v)
    Cfg.GradientMode = v
end)
MakeSlider(tabGrad, "Gradient Speed", 0.2, 6, Cfg.GradientSpeed, function(v) Cfg.GradientSpeed = v end)

local PaletteFrame = Instance.new("Frame")
PaletteFrame.Size = UDim2.new(1, -8, 0, 18)
PaletteFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
PaletteFrame.BorderSizePixel = 0
PaletteFrame.Parent = tabGrad
Instance.new("UICorner", PaletteFrame).CornerRadius = UDim.new(0, 3)
local PaletteGradient = Instance.new("UIGradient")
PaletteGradient.Parent = PaletteFrame

local function RefreshPalette()
    local colors = Cfg.GradientColors
    if #colors == 0 then PaletteGradient.Color = ColorSequence.new(Color3.new(1,1,1))
    elseif #colors == 1 then PaletteGradient.Color = ColorSequence.new(colors[1])
    else
        local kp = {}
        for i, c in ipairs(colors) do
            table.insert(kp, ColorSequenceKeypoint.new((i-1)/(#colors-1), c))
        end
        PaletteGradient.Color = ColorSequence.new(kp)
    end
end

local ColorRow = Instance.new("Frame")
ColorRow.Size = UDim2.new(1, -8, 0, 26)
ColorRow.BackgroundTransparency = 1
ColorRow.Parent = tabGrad
local ColorLayout = Instance.new("UIListLayout")
ColorLayout.FillDirection = Enum.FillDirection.Horizontal
ColorLayout.Padding = UDim.new(0, 4)
ColorLayout.Parent = ColorRow

local function RefreshColorRow()
    for _, c in ipairs(ColorRow:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    for i, col in ipairs(Cfg.GradientColors) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 28, 0, 22)
        b.BackgroundColor3 = col
        b.Text = "×"
        b.TextColor3 = Color3.new(0, 0, 0)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 12
        b.Parent = ColorRow
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 3)
        b.MouseButton1Click:Connect(function()
            table.remove(Cfg.GradientColors, i)
            if #Cfg.GradientColors == 0 then
                Cfg.GradientColors = { Color3.fromRGB(255, 255, 255) }
            end
            RefreshPalette(); RefreshColorRow()
        end)
    end
end
RefreshPalette(); RefreshColorRow()

-- Квадратная палитра
local PickerRow = Instance.new("Frame")
PickerRow.Size = UDim2.new(1, -8, 0, 120)
PickerRow.BackgroundTransparency = 1
PickerRow.Parent = tabGrad

local SV = Instance.new("Frame")
SV.Size = UDim2.new(0, 120, 0, 120)
SV.Position = UDim2.new(0.5, -60, 0, 0)
SV.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
SV.BorderSizePixel = 0
SV.Parent = PickerRow
Instance.new("UICorner", SV).CornerRadius = UDim.new(0, 4)

local SVWhite = Instance.new("Frame")
SVWhite.Size = UDim2.new(1, 0, 1, 0)
SVWhite.BackgroundColor3 = Color3.new(1, 1, 1)
SVWhite.BorderSizePixel = 0
SVWhite.Parent = SV
Instance.new("UICorner", SVWhite).CornerRadius = UDim.new(0, 4)
local SVWhiteG = Instance.new("UIGradient")
SVWhiteG.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0, 0),
    NumberSequenceKeypoint.new(1, 1),
}
SVWhiteG.Parent = SVWhite

local SVBlack = Instance.new("Frame")
SVBlack.Size = UDim2.new(1, 0, 1, 0)
SVBlack.BackgroundColor3 = Color3.new(0, 0, 0)
SVBlack.BorderSizePixel = 0
SVBlack.Parent = SV
Instance.new("UICorner", SVBlack).CornerRadius = UDim.new(0, 4)
local SVBlackG = Instance.new("UIGradient")
SVBlackG.Rotation = 90
SVBlackG.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(1, 0),
}
SVBlackG.Parent = SVBlack

local Hue = Instance.new("Frame")
Hue.Size = UDim2.new(1, -8, 0, 16)
Hue.BorderSizePixel = 0
Hue.Parent = tabGrad
Instance.new("UICorner", Hue).CornerRadius = UDim.new(0, 4)
local HueGradient = Instance.new("UIGradient")
local hueKp = {}
for i = 0, 6 do
    table.insert(hueKp, ColorSequenceKeypoint.new(i/6, Color3.fromHSV(i/6, 1, 1)))
end
HueGradient.Color = ColorSequence.new(hueKp)
HueGradient.Parent = Hue

local PreviewRow = Instance.new("Frame")
PreviewRow.Size = UDim2.new(1, -8, 0, 24)
PreviewRow.BackgroundTransparency = 1
PreviewRow.Parent = tabGrad
local PreviewColor = Instance.new("Frame")
PreviewColor.Size = UDim2.new(0, 24, 1, 0)
PreviewColor.BorderSizePixel = 0
PreviewColor.Parent = PreviewRow
Instance.new("UICorner", PreviewColor).CornerRadius = UDim.new(0, 3)
local AddBtn = Instance.new("TextButton")
AddBtn.Size = UDim2.new(1, -30, 1, 0)
AddBtn.Position = UDim2.new(0, 30, 0, 0)
AddBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 160)
AddBtn.Text = "Add this color"
AddBtn.TextColor3 = Color3.new(1, 1, 1)
AddBtn.Font = Enum.Font.GothamBold
AddBtn.TextSize = 11
AddBtn.Parent = PreviewRow
Instance.new("UICorner", AddBtn).CornerRadius = UDim.new(0, 3)

local pickerHue, pickerSat, pickerVal = 0, 1, 1
local function PickerColor() return Color3.fromHSV(pickerHue, pickerSat, pickerVal) end
local function UpdatePickerVisuals()
    SV.BackgroundColor3 = Color3.fromHSV(pickerHue, 1, 1)
    PreviewColor.BackgroundColor3 = PickerColor()
end
UpdatePickerVisuals()

local function HookSV()
    local dragging = true
    local function upd()
        local mp = UserInputService:GetMouseLocation()
        local relX = math.clamp((mp.X - SV.AbsolutePosition.X) / SV.AbsoluteSize.X, 0, 1)
        local relY = math.clamp((mp.Y - SV.AbsolutePosition.Y) / SV.AbsoluteSize.Y, 0, 1)
        pickerSat, pickerVal = relX, 1 - relY
        UpdatePickerVisuals()
    end
    upd()
    local c
    c = UserInputService.InputChanged:Connect(function(e)
        if dragging and e.UserInputType == Enum.UserInputType.MouseMovement then upd() end
    end)
    UserInputService.InputEnded:Connect(function(e)
        if e.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false; if c then c:Disconnect() end
        end
    end)
end
SV.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then HookSV() end
end)

local function HookHue()
    local dragging = true
    local function upd()
        local mp = UserInputService:GetMouseLocation()
        local rel = math.clamp((mp.X - Hue.AbsolutePosition.X) / Hue.AbsoluteSize.X, 0, 1)
        pickerHue = rel
        UpdatePickerVisuals()
    end
    upd()
    local c
    c = UserInputService.InputChanged:Connect(function(e)
        if dragging and e.UserInputType == Enum.UserInputType.MouseMovement then upd() end
    end)
    UserInputService.InputEnded:Connect(function(e)
        if e.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false; if c then c:Disconnect() end
        end
    end)
end
Hue.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then HookHue() end
end)

AddBtn.MouseButton1Click:Connect(function()
    table.insert(Cfg.GradientColors, PickerColor())
    RefreshPalette(); RefreshColorRow()
end)

-- TEXT
local tabText = MakeTab("Text")
MakeToggle(tabText, "Text Enabled", Cfg.TextEnabled, function(v) Cfg.TextEnabled = v end)
MakeTextBox(tabText, "H3Y0 M0NST3R", Cfg.Text, function(v) Cfg.Text = v end)
MakeSlider(tabText, "Text Size", 8, 48, Cfg.TextSize, function(v) Cfg.TextSize = v end)
MakeDropdown(tabText, "Text Color Mode", TEXT_COLOR_MODES, Cfg.TextColorMode, function(v)
    Cfg.TextColorMode = v
end)
MakeDropdown(tabText, "Text Font", FONT_NAMES, Cfg.TextFont, function(v)
    Cfg.TextFont = v
    BuildTextLayers()
end)
MakeToggle(tabText, "Text Neon", Cfg.TextNeon, function(v) Cfg.TextNeon = v end)

-- SETTINGS
local tabSet = MakeTab("Settings")
local BindLabel = Instance.new("TextLabel")
BindLabel.Size = UDim2.new(1, -8, 0, 24)
BindLabel.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
BindLabel.Text = "Toggle Key: " .. Cfg.ToggleKey.Name
BindLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
BindLabel.Font = Enum.Font.Gotham
BindLabel.TextSize = 11
BindLabel.Parent = tabSet
Instance.new("UICorner", BindLabel).CornerRadius = UDim.new(0, 4)

local waitingBind = false
BindLabel.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if waitingBind then
            waitingBind = false
            BindLabel.Text = "Toggle Key: " .. Cfg.ToggleKey.Name
        else
            waitingBind = true
            BindLabel.Text = "Press any key... (click to cancel)"
        end
    end
end)

MakeTextBox(tabSet, "cfg name", "", function(v) _G._H3Y0_CfgName = v end)
MakeButton(tabSet, "Save CFG", function()
    local name = _G._H3Y0_CfgName
    if not name or name == "" then name = "default" end
    SaveCfgFile(name)
end, Color3.fromRGB(60, 100, 60))

local cfgsListLabel = Instance.new("TextLabel")
cfgsListLabel.Size = UDim2.new(1, -8, 0, 14)
cfgsListLabel.BackgroundTransparency = 1
cfgsListLabel.Text = "CFG files:"
cfgsListLabel.TextColor3 = Color3.fromRGB(200, 140, 255)
cfgsListLabel.Font = Enum.Font.GothamBold
cfgsListLabel.TextSize = 11
cfgsListLabel.TextXAlignment = Enum.TextXAlignment.Left
cfgsListLabel.Parent = tabSet

local cfgsHolder = Instance.new("Frame")
cfgsHolder.Size = UDim2.new(1, -8, 0, 24)
cfgsHolder.BackgroundTransparency = 1
cfgsHolder.Parent = tabSet
local cfgsLayout = Instance.new("UIListLayout")
cfgsLayout.FillDirection = Enum.FillDirection.Horizontal
cfgsLayout.Padding = UDim.new(0, 4)
cfgsLayout.Parent = cfgsHolder

local function RefreshCfgList()
    for _, c in ipairs(cfgsHolder:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    for _, name in ipairs(ListCfgFiles()) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 80, 0, 22)
        b.BackgroundColor3 = Color3.fromRGB(45, 35, 60)
        b.Text = name
        b.TextColor3 = Color3.fromRGB(220, 180, 255)
        b.Font = Enum.Font.Gotham
        b.TextSize = 10
        b.Parent = cfgsHolder
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 3)
        b.MouseButton1Click:Connect(function()
            if LoadCfgFile(name) then
                RefreshPalette(); RefreshColorRow(); BuildTextLayers()
            end
        end)
        b.MouseButton2Click:Connect(function()
            DeleteCfgFile(name); RefreshCfgList()
        end)
    end
end
RefreshCfgList()
MakeButton(tabSet, "Refresh CFG list", function() RefreshCfgList() end)

MakeButton(tabSet, "Set AutoLoad to CFG name", function()
    local name = _G._H3Y0_CfgName
    if not name or name == "" then name = "default" end
    SetAutoLoad(name)
end)
MakeButton(tabSet, "Clear AutoLoad", function() SetAutoLoad(nil) end)
MakeButton(tabSet, "Reset to defaults", function()
    Cfg = DefaultCfg()
    RefreshPalette(); RefreshColorRow(); BuildTextLayers()
end, Color3.fromRGB(120, 90, 40))
MakeButton(tabSet, "Unload H3Y0 M0NST3R", function() Unload() end, Color3.fromRGB(150, 40, 40))

TabButtons["Crosshair"].BackgroundColor3 = Color3.fromRGB(100, 60, 160)
Tabs["Crosshair"].Visible = true

-- ============================================
-- БИНД МЕНЮ
-- ============================================
local bindConn = UserInputService.InputBegan:Connect(function(input, gpe)
    if Unloaded then return end
    if waitingBind then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            Cfg.ToggleKey = input.KeyCode
            BindLabel.Text = "Toggle Key: " .. input.KeyCode.Name
            waitingBind = false
        end
        return
    end
    if gpe then return end
    if input.KeyCode == Cfg.ToggleKey then
        Main.Visible = not Main.Visible
    end
end)
table.insert(ActiveConnections, bindConn)

-- AUTOLOAD
local autoloadName = GetAutoLoad()
if autoloadName then
    LoadCfgFile(autoloadName); RefreshPalette(); RefreshColorRow(); BuildTextLayers()
end
ApplyHideGameCrosshair(Cfg.HideGameCrosshair)

print("[H3Y0 M0NST3R] v9 loaded. Menu: " .. Cfg.ToggleKey.Name)
