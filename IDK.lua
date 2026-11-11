-- ==========================================
-- СЕРВИСЫ И АНТИ-ДЕТЕКТ
-- ==========================================
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local GuiName = "SUND3R1DAYS_UI_" .. tostring(math.random(1000, 9999))
if CoreGui:FindFirstChild(GuiName) then CoreGui[GuiName]:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = GuiName
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999 
ScreenGui.Parent = CoreGui

-- 🎨 ТЕМА (Тёмный ImGui)
local Theme = {
    Bg = Color3.fromRGB(18, 18, 18),
    Panel = Color3.fromRGB(24, 24, 24),
    Element = Color3.fromRGB(32, 32, 32),
    Text = Color3.fromRGB(230, 230, 230),
    TextMuted = Color3.fromRGB(150, 150, 150),
    Accent = Color3.fromRGB(90, 150, 255),
    Red = Color3.fromRGB(255, 80, 80),
    Green = Color3.fromRGB(80, 255, 80)
}

-- ==========================================
-- ВАТЕРМАРКА (Watermark)
-- ==========================================
local Watermark = Instance.new("Frame")
Watermark.Parent = ScreenGui
Watermark.BackgroundColor3 = Theme.Bg
Watermark.Position = UDim2.new(0, 10, 0, 10) -- В левом верхнем углу
Watermark.Size = UDim2.new(0, 350, 0, 25)
Watermark.BorderSizePixel = 0

local WMStroke = Instance.new("UIStroke")
WMStroke.Color = Theme.Accent
WMStroke.Thickness = 1
WMStroke.Parent = Watermark

local WMLabel = Instance.new("TextLabel")
WMLabel.Parent = Watermark
WMLabel.BackgroundTransparency = 1
WMLabel.Size = UDim2.new(1, 0, 1, 0)
WMLabel.Font = Enum.Font.Code
WMLabel.TextColor3 = Theme.Text
WMLabel.TextSize = 12
WMLabel.Text = "SUND3R1DAYS | Loading..."

-- Радужная линия над текстом (заглушка, включается в настройках)
local RainbowLine = Instance.new("Frame")
RainbowLine.Parent = Watermark
RainbowLine.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
RainbowLine.Position = UDim2.new(0, 0, 0, -2)
RainbowLine.Size = UDim2.new(1, 0, 0, 2)
RainbowLine.BorderSizePixel = 0
RainbowLine.Visible = false

-- Обновление ватермарки (FPS и Пинг)
RunService.RenderStepped:Connect(function()
    local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
    local fps = math.floor(1 / RunService.RenderStepped:Wait())
    WMLabel.Text = string.format("SUND3R1DAYS | %s | %d fps | %d ms | default.cfg", LocalPlayer.Name, fps, ping)
end)

-- ==========================================
-- ГЛАВНОЕ ОКНО
-- ==========================================
local MainFrame = Instance.new("Frame")
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Theme.Bg
MainFrame.Position = UDim2.new(0.5, -350, 0.5, -220)
MainFrame.Size = UDim2.new(0, 700, 0, 440)
MainFrame.BorderSizePixel = 0
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 6)
UICorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Theme.Panel
MainStroke.Thickness = 1
MainStroke.Parent = MainFrame

-- Верхняя панель (Заголовок)
local TopBar = Instance.new("Frame")
TopBar.Parent = MainFrame
TopBar.BackgroundColor3 = Theme.Panel
TopBar.Size = UDim2.new(1, 0, 0, 30)
TopBar.BorderSizePixel = 0

local Title = Instance.new("TextLabel")
Title.Parent = TopBar
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 10, 0, 0)
Title.Size = UDim2.new(1, -60, 1, 0)
Title.Font = Enum.Font.Code
Title.Text = "SUND3R1DAYS | v2.0"
Title.TextColor3 = Theme.Text
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton")
CloseBtn.Parent = TopBar
CloseBtn.BackgroundTransparency = 1
CloseBtn.Position = UDim2.new(1, -30, 0, 0)
CloseBtn.Size = UDim2.new(0, 30, 1, 0)
CloseBtn.Font = Enum.Font.Code
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Theme.Red
CloseBtn.TextSize = 14
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

-- Вкладки сверху
local TabContainer = Instance.new("Frame")
TabContainer.Parent = MainFrame
TabContainer.BackgroundColor3 = Theme.Panel
TabContainer.Position = UDim2.new(0, 0, 0, 30)
TabContainer.Size = UDim2.new(1, 0, 0, 25)

local TabLayout = Instance.new("UIListLayout")
TabLayout.Parent = TabContainer
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.Padding = UDim.new(0, 2)

-- Контент
local Content = Instance.new("Frame")
Content.Parent = MainFrame
Content.BackgroundColor3 = Theme.Bg
Content.Position = UDim2.new(0, 0, 0, 55)
Content.Size = UDim2.new(1, 0, 1, -55)

-- ==========================================
-- СИСТЕМА ВКЛАДОК
-- ==========================================
local Pages = {}
local TabNames = {"combat", "esp", "visual", "world", "settings"}
local TabButtons = {}

local function SelectTab(tabName)
    for name, page in pairs(Pages) do
        page.Visible = false
        if TabButtons[name] then
            TabButtons[name].TextColor3 = Theme.TextMuted
            TabButtons[name].BackgroundColor3 = Theme.Panel
        end
    end
    Pages[tabName].Visible = true
    TabButtons[tabName].TextColor3 = Color3.fromRGB(255, 255, 255)
    TabButtons[tabName].BackgroundColor3 = Theme.Bg
end

for _, name in ipairs(TabNames) do
    local page = Instance.new("Frame")
    page.Parent = Content
    page.BackgroundTransparency = 1
    page.Size = UDim2.new(1, 0, 1, 0)
    page.Visible = false
    Pages[name] = page
    
    local btn = Instance.new("TextButton")
    btn.Parent = TabContainer
    btn.BackgroundColor3 = Theme.Panel
    btn.Size = UDim2.new(0, 70, 1, 0)
    btn.Font = Enum.Font.Code
    btn.Text = name
    btn.TextColor3 = Theme.TextMuted
    btn.TextSize = 11
    btn.MouseButton1Click:Connect(function() SelectTab(name) end)
    TabButtons[name] = btn
end
SelectTab("esp")

-- ==========================================
-- КОМПОНЕНТЫ (Toggle, Button, Slider)
-- ==========================================
local function CreateToggle(parent, text, xPos, yPos, callback)
    local Frame = Instance.new("Frame")
    Frame.Parent = parent
    Frame.BackgroundColor3 = Theme.Element
    Frame.Position = UDim2.new(0, xPos, 0, yPos)
    Frame.Size = UDim2.new(0, 180, 0, 30)
    Frame.BorderSizePixel = 0
    
    local Label = Instance.new("TextLabel")
    Label.Parent = Frame
    Label.BackgroundTransparency = 1
    Label.Position = UDim2.new(0, 8, 0, 0)
    Label.Size = UDim2.new(1, -30, 1, 0)
    Label.Font = Enum.Font.Code
    Label.Text = text
    Label.TextColor3 = Theme.Text
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    
    local Switch = Instance.new("TextButton")
    Switch.Parent = Frame
    Switch.BackgroundColor3 = Theme.Bg
    Switch.Position = UDim2.new(1, -25, 0.5, -8)
    Switch.Size = UDim2.new(0, 18, 0, 16)
    Switch.Text = ""
    Switch.BorderSizePixel = 0
    
    local isToggled = false
    Switch.MouseButton1Click:Connect(function()
        isToggled = not isToggled
        Switch.BackgroundColor3 = isToggled and Theme.Accent or Theme.Bg
        if callback then callback(isToggled) end
    end)
end

local function CreateSubHeader(parent, text, yPos)
    local lbl = Instance.new("TextLabel")
    lbl.Parent = parent
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 10, 0, yPos)
    lbl.Size = UDim2.new(1, -20, 0, 15)
    lbl.Font = Enum.Font.Code
    lbl.Text = text
    lbl.TextColor3 = Theme.TextMuted
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
end

-- ==========================================
-- НАПОЛНЕНИЕ ВКЛАДОК
-- ==========================================

-- COMBAT
CreateSubHeader(Pages["combat"], "Aimbot", 5)
CreateToggle(Pages["combat"], "Enabled", 10, 25)
CreateToggle(Pages["combat"], "Silent Aim", 10, 60)
CreateToggle(Pages["combat"], "Trigger Bot", 10, 95)

-- ESP
CreateSubHeader(Pages["esp"], "Options", 5)
CreateToggle(Pages["esp"], "Box ESP", 10, 25)
CreateToggle(Pages["esp"], "Skeleton", 10, 60)
CreateToggle(Pages["esp"], "Healthbar", 10, 95)

CreateSubHeader(Pages["esp"], "Aura", 140)
CreateToggle(Pages["esp"], "Enabled", 10, 160, function(state)
    _G.AuraEnabled = state -- Включаем ауру
end)
CreateToggle(Pages["esp"], "Rotating Corners", 10, 195) -- Уголки

-- VISUAL
CreateSubHeader(Pages["visual"], "Spoofer", 5)
CreateToggle(Pages["visual"], "Avatar Spoof", 10, 25)
CreateToggle(Pages["visual"], "Win Streak", 10, 60)
CreateToggle(Pages["visual"], "Level", 10, 95)

CreateSubHeader(Pages["visual"], "China Mode", 140)
CreateToggle(Pages["visual"], "China Hat", 10, 160)
CreateToggle(Pages["visual"], "Katana Wings", 10, 195)

-- WORLD
CreateSubHeader(Pages["world"], "Environment", 5)
CreateToggle(Pages["world"], "Custom Skybox", 10, 25)
CreateToggle(Pages["world"], "Remove Fog", 10, 60)
CreateToggle(Pages["world"], "Atmosphere", 10, 95)
CreateToggle(Pages["world"], "Color Correction", 10, 130)

-- SETTINGS
CreateSubHeader(Pages["settings"], "Config", 5)
CreateToggle(Pages["settings"], "Auto Save", 10, 25)
CreateSubHeader(Pages["settings"], "Watermark", 60)
CreateToggle(Pages["settings"], "Rainbow Line", 10, 80, function(state)
    RainbowLine.Visible = state
end)
CreateToggle(Pages["settings"], "Show FPS/Ping", 10, 115)

-- ==========================================
-- HvH MODE (Заглушка логики)
-- ==========================================
CreateSubHeader(Pages["settings"], "HvH Mode", 160)
CreateToggle(Pages["settings"], "Enable HvH", 10, 180, function(state)
    if state then
        -- Тут будет логика: камера от 3-го лица, персонаж смотрит вниз, крутится
        -- Пока что просто выводим в консоль
        print("HvH Mode: ON")
    else
        print("HvH Mode: OFF")
    end
end)
CreateToggle(Pages["settings"], "Auto Spin", 10, 215)

-- ==========================================
-- ЛОГИКА: АУРА (Уголки) + HvH (Полёт)
-- ==========================================
RunService.RenderStepped:Connect(function()
    -- Логика ауры (Рисуем квадраты вокруг игроков)
    if _G.AuraEnabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = player.Character.HumanoidRootPart
                local screenPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(hrp.Position)
                
                if onScreen then
                    -- Тут должен быть код отрисовки углов (Drawing API)
                    -- Для простоты оставим это на следующий этап
                end
            end
        end
    end
end)

-- ==========================================
-- ПЕРЕТАСКИВАНИЕ ОКНА
-- ==========================================
local dragging, dragInput, dragStart, startPos
local function update(input)
    local delta = input.Position - dragStart
    MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

TopBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then update(input) end
end)

print("SUND3R1DAYS v2.0 (Functional) успешно загружен!")
