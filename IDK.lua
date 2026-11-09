-- Загрузка стабильной и легкой библиотеки интерфейса Orion (она стабильнее на мобилках и ПК)
local OrionLib = loadstring(game:HttpGet(('https://githubusercontent.com')))()

-- Инициализация окна
local Window = OrionLib:MakeWindow({
    Name = "H3Y0 W!LL R!S3 UP ⚡", 
    HidePremium = true, 
    SaveConfig = false, 
    IntroText = "H3Y0.win Framework"
})

-- Глобальные настройки
_G.SilentAim = false
_G.AimFOV = 100
_G.EspEnabled = false
_G.WalkSpeed = 16
_G.InfiniteJump = false

-- Создание вкладок
local CombatTab = Window:MakeTab({Name = "🎯 Combat", Icon = "rbxassetid://4483362458", Premium = false})
local VisualsTab = Window:MakeTab({Name = "👁️ Visuals", Icon = "rbxassetid://4483362458", Premium = false})
local MovementTab = Window:MakeTab({Name = "🏃 Movement", Icon = "rbxassetid://4483362458", Premium = false})

-------------------------------------------------------------------------------
-- [1. COMBAT - УЛЬТРА-СТАБИЛЬНЫЙ АИМ]
-------------------------------------------------------------------------------
local Camera = workspace.CurrentCamera
local LocalPlayer = game.Players.LocalPlayer

local function GetClosestPlayer()
    local closest, maxDist = nil, _G.AimFOV
    for _, player in pairs(game.Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then
            local pos, onScreen = Camera:WorldToViewportPoint(player.Character.Head.Position)
            if onScreen then
                local dist = (Vector2.new(pos.X, pos.Y) - Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)).Magnitude
                if dist < maxDist then
                    closest = player
                    maxDist = dist
                end
            end
        end
    end
    return closest
end

CombatTab:AddToggle({
    Name = "Silent Aim (Мягкий Аим)",
    Default = false,
    Callback = function(Value) _G.SilentAim = Value end
})

CombatTab:AddSlider({
    Name = "Радиус FOV",
    Min = 30, Max = 500, Increment = 5, Default = 100,
    Callback = function(Value) _G.AimFOV = Value end
})

-- Легкий и безопасный способ доводки камеры при стрельбе (без крашей)
game:GetService("RunService").RenderStepped:Connect(function()
    if _G.SilentAim then
        local target = GetClosestPlayer()
        if target and target.Character and target.Character:FindFirstChild("Head") then
            -- Плавное направление камеры на голову врага
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Character.Head.Position)
        end
    end
end)

-------------------------------------------------------------------------------
-- [2. VISUALS - ХАЙЛАЙТ ESP]
-------------------------------------------------------------------------------
VisualsTab:AddToggle({
    Name = "Wallhack / Chams",
    Default = false,
    Callback = function(Value)
        _G.EspEnabled = Value
        for _, player in pairs(game.Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local highlight = player.Character:FindFirstChild("HeyoESP")
                if highlight then highlight.Enabled = Value end
            end
        end
    end
})

local function ApplyESP(player)
    player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if not char:FindFirstChild("HeyoESP") then
            local pESP = Instance.new("Highlight")
            pESP.Name = "HeyoESP"
            pESP.FillColor = Color3.fromRGB(0, 255, 255)
            pESP.OutlineColor = Color3.fromRGB(255, 255, 255)
            pESP.FillTransparency = 0.4
            pESP.Enabled = _G.EspEnabled
            pESP.Parent = char
        end
    end)
end

for _, p in pairs(game.Players:GetPlayers()) do ApplyESP(p) end
game.Players.PlayerAdded:Connect(ApplyESP)

-------------------------------------------------------------------------------
-- [3. MOVEMENT - СКОРОСТЬ И ПРЫЖКИ]
-------------------------------------------------------------------------------
MovementTab:AddSlider({
    Name = "Скорость бега",
    Min = 16, Max = 100, Increment = 1, Default = 16,
    Callback = function(Value) _G.WalkSpeed = Value end
})

MovementTab:AddToggle({
    Name = "Бесконечный прыжок",
    Default = false,
    Callback = function(Value) _G.InfiniteJump = Value end
})

game:GetService("RunService").Heartbeat:Connect(function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = _G.WalkSpeed
    end
end)

game:GetService("UserInputService").JumpRequest:Connect(function()
    if _G.InfiniteJump and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState("Jumping")
    end
end)

OrionLib:Init()
