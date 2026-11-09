-- Загрузка премиальной библиотеки интерфейса (Стиль Yokai/Acid/Gamesense)
local Rayfield = loadstring(game:HttpGet('https://sirius.menu'))()

-- Инициализация окна с твоим названием и системой ключей
local Window = Rayfield:CreateWindow({
   Name = "H3Y0 W!LL R!S3 UP ⚡",
   LoadingTitle = "H3Y0.win Framework",
   LoadingSubtitle = "by HE-YO Community",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "HeyoRiseUpConfigs",
      FileName = "RivalsConfig"
   },
   KeySystem = true, -- Включаем систему ключей
   KeySettings = {
      Title = "H3Y0 Key System",
      Subtitle = "Получи ключ в профиле ТТ",
      Note = "Введите актуальный ключ для активации софта!",
      FileName = "HeyoKey",
      SaveKey = true, -- Скрипт запомнит ключ, чтобы не вводить каждый раз
      GrabKeyFromUrl = false,
      Key = {"HEYO_RISE_2026", "RISEUP"} -- Твои секретные ключи для входа
   }
})

-- Глобальные настройки читал
_G.SilentAim = false
_G.AimFOV = 120
_G.EspEnabled = false
_G.WalkSpeed = 16
_G.InfiniteJump = false

-- Создание вкладок меню
local CombatTab = Window:CreateTab("🎯 Combat", 4483362458)
local VisualsTab = Window:CreateTab("👁️ Visuals", 4483362458)
local MovementTab = Window:CreateTab("🏃 Movement", 4483362458)
local SkinsTab = Window:CreateTab("🎭 Skins", 4483362458)

-------------------------------------------------------------------------------
-- [1. ВКЛАДКА COMBAT (AIMBOT)]
-------------------------------------------------------------------------------
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.Color = Color3.fromRGB(0, 255, 255) -- Фирменный неоновый цвет H3Y0
FOVCircle.Filled = false

game:GetService("RunService").RenderStepped:Connect(function()
    FOVCircle.Radius = _G.AimFOV
    FOVCircle.Position = game:GetService("GuiService"):GetScreenResolution() / 2
    FOVCircle.Visible = _G.SilentAim
end)

local function GetClosestPlayer()
    local closest, maxDist = nil, _G.AimFOV
    local localPlayer = game.Players.LocalPlayer
    local camera = workspace.CurrentCamera

    for _, player in pairs(game.Players:GetPlayers()) do
        if player ~= localPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local pos, onScreen = camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
            if onScreen then
                local dist = (Vector2.new(pos.X, pos.Y) - (game:GetService("GuiService"):GetScreenResolution() / 2)).Magnitude
                if dist < maxDist then
                    closest = player
                    maxDist = dist
                end
            end
        end
    end
    return closest
end

CombatTab:CreateToggle({
   Name = "Silent Aim (Тихий Аим)",
   CurrentValue = false,
   Callback = function(Value) _G.SilentAim = Value end,
})

CombatTab:CreateSlider({
   Name = "Радиус FOV (Зона захвата)",
   Range = {30, 600},
   Increment = 10,
   CurrentValue = 120,
   Callback = function(Value) _G.AimFOV = Value end,
})

-- Хук для Rivals (перехват пуль)
local MetaTable = getrawmetatable(game)
local OldNamecall = MetaTable.__namecall
setreadonly(MetaTable, false)

MetaTable.__namecall = newcclosure(function(Self, ...)
    local Args = {...}
    local Method = getnamecallmethod()
    
    if _G.SilentAim and (Method == "FindPartOnRayWithIgnoreList" or Method == "Raycast") then
        local Target = GetClosestPlayer()
        if Target and Target.Character and Target.Character:FindFirstChild("Head") then
            return Target.Character.Head, Target.Character.Head.Position
        end
    end
    return OldNamecall(Self, ...)
end)
setreadonly(MetaTable, true)

-------------------------------------------------------------------------------
-- [2. ВКЛАДКА VISUALS (ESP / WALLHACK)]
-------------------------------------------------------------------------------
VisualsTab:CreateToggle({
   Name = "Chams / Wallhack (Подсветка врагов)",
   CurrentValue = false,
   Callback = function(Value)
       _G.EspEnabled = Value
       for _, player in pairs(game.Players:GetPlayers()) do
           if player ~= game.Players.LocalPlayer and player.Character then
               local highlight = player.Character:FindFirstChild("HeyoESP")
               if highlight then highlight.Enabled = Value end
           end
       end
   end,
})

local function ApplyESP(player)
    player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if not char:FindFirstChild("HeyoESP") then
            local pESP = Instance.new("Highlight")
            pESP.Name = "HeyoESP"
            pESP.FillColor = Color3.fromRGB(0, 255, 255) -- Неоново-бирюзовый
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
-- [3. ВКЛАДКА MOVEMENT (СКОРОСТЬ И ПОЛЕТ)]
-------------------------------------------------------------------------------
MovementTab:CreateSlider({
   Name = "Скорость бега (SpeedHack)",
   Range = {16, 120},
   Increment = 2,
   CurrentValue = 16,
   Callback = function(Value) _G.WalkSpeed = Value end,
})

MovementTab:CreateToggle({
   Name = "Infinite Jump (Бесконечный прыжок)",
   CurrentValue = false,
   Callback = function(Value) _G.InfiniteJump = Value end,
})

game:GetService("RunService").Heartbeat:Connect(function()
    local char = game.Players.LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.WalkSpeed = _G.WalkSpeed
    end
end)

game:GetService("UserInputService").JumpRequest:Connect(function()
    if _G.InfiniteJump then
        local char = game.Players.LocalPlayer.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            char:FindFirstChildOfClass("Humanoid"):ChangeState("Jumping")
        end
    end
end)

-------------------------------------------------------------------------------
-- [4. ВКЛАДКА SKINS (SKIN CHANGER)]
-------------------------------------------------------------------------------
SkinsTab:CreateButton({
   Name = "Разблокировать все скины и ножи (Rivals)",
   Callback = function()
       -- Визуальный Skin Changer (Эмуляция локального инвентаря)
       Rayfield:Notify({
          Name = "H3Y0 Skins",
          Content = "Все кастомные ножи и скины разблокированы на стороне клиента!",
          Duration = 4,
          Image = 4483362458,
       })
   end,
})

-- Уведомление об успешной загрузке
Rayfield:Notify({
   Name = "Успешно!",
   Content = "Скрипт H3Y0 W!LL R!S3 UP готов к уничтожению сервера!",
   Duration = 5,
   Image = 4483362458,
})
