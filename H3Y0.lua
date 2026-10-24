--!strict
-- H3Y0 HUB v4.0 — Crosshair RGB/Rotate/Pulse + Label
-- Requires: Drawing (for crosshair), loadstring, writefile/readfile (optional)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

assert(LocalPlayer, "H3Y0: client only")

local parentGui = (pcall(function() return game:GetService("CoreGui") end) and game:GetService("CoreGui"))
    or LocalPlayer:WaitForChild("PlayerGui")

local hasFs = (typeof(writefile) == "function") and (typeof(readfile) == "function") and (typeof(isfile) == "function")
local hasDrawing = (typeof(Drawing) == "table" and typeof(Drawing.new) == "function")

--============================================================
-- STATE
--============================================================
local State = {
    -- Aimbot
    aimbotEnabled = false,
    aimbotKey = "MouseButton2",
    aimbotTeamCheck = false,
    aimbotAliveCheck = true,
    aimbotWallCheck = false,
    aimbotSensitivity = 0.15,
    aimbotThirdPerson = false,
    aimbotThirdPersonSens = 3,
    aimbotLockPart = "Head",
    -- FOV
    fovEnabled = true,
    fovVisible = true,
    fovAmount = 90,
    fovColor = Color3.fromRGB(255, 255, 255),
    fovLockedColor = Color3.fromRGB(255, 70, 70),
    fovTransparency = 0.5,
    fovThickness = 1,
    fovFilled = false,
    -- ESP
    espEnabled = false,
    espTeamCheck = false,
    espAliveCheck = true,
    espColor = Color3.fromRGB(0, 220, 255),
    espTransparency = 0.4,
    -- Crosshair (extended)
    crosshairEnabled = false,
    crosshairColor = Color3.fromRGB(255, 255, 255),
    crosshairRainbow = false,
    crosshairRainbowSpeed = 0.005,
    crosshairRainbowSaturation = 1,
    crosshairRainbowValue = 1,
    crosshairRotate = false,
    crosshairRotateSpeed = 1,
    crosshairPulse = false,
    crosshairPulseSpeed = 1,
    crosshairPulseAmount = 0.35,
    crosshairSize = 12,
    crosshairThickness = 1,
    crosshairGap = 4,
    crosshairTransparency = 0.5,
    crosshairCenterDot = true,
    crosshairDotSize = 2,
    crosshairStyle = "Cross", -- Cross / X / Circle
    -- Crosshair Label
    labelEnabled = false,
    labelText = "H3Y0",
    labelColor = Color3.fromRGB(255, 255, 255),
    labelRainbow = false,
    labelSize = 14,
    labelOffset = 18,
    labelTransparency = 0.2,
    -- RGB UI
    rgbUI = true,
    rgbSpeed = 0.005,
    -- Misc
    walkSpeed = 16,
    jumpPower = 50,
    fullbright = false,
    notifications = true,
    toggleKey = "RightShift",
}

--============================================================
-- PERSIST
--============================================================
local function saveJson(path, data)
    if not hasFs then return end
    pcall(function() writefile(path, HttpService:JSONEncode(data)) end)
end

local function loadJson(path)
    if not hasFs then return {} end
    local ok, d = pcall(function() if isfile(path) then return HttpService:JSONDecode(readfile(path)) end return {} end)
    return (ok and type(d) == "table") and d or {}
end

local function serializeState()
    local out = {}
    for k, v in pairs(State) do
        if typeof(v) == "Color3" then out[k] = {__c=true,r=v.R,g=v.G,b=v.B}
        else out[k] = v end
    end
    return out
end

local function deserializeState(d)
    for k, v in pairs(d) do
        if type(v) == "table" and v.__c then State[k] = Color3.new(v.r, v.g, v.b)
        elseif State[k] ~= nil then State[k] = v end
    end
end

local function saveConfig() saveJson("H3Y0_config.json", serializeState()) end

--============================================================
-- UTIL
--============================================================
local function new(cls, props)
    local i = Instance.new(cls)
    for k, v in pairs(props or {}) do i[k] = v end
    return i
end

local function corner(p, r) return new("UICorner", {CornerRadius=UDim.new(0,r or 8),Parent=p}) end
local function stroke(p, c, th) return new("UIStroke", {Color=c or Color3.fromRGB(50,50,60),Thickness=th or 1,Parent=p}) end
local function pad(p, px) return new("UIPadding", {PaddingTop=UDim.new(0,px),PaddingBottom=UDim.new(0,px),PaddingLeft=UDim.new(0,px),PaddingRight=UDim.new(0,px),Parent=p}) end
local function tween(i, props, d) return TweenService:Create(i, TweenInfo.new(d or 0.15, Enum.EasingStyle.Quad), props):Play() end

--============================================================
-- RGB UI
--============================================================
local rgbHue = 0
local rgbParts = {}

local function registerRGB(inst, prop, sat, val)
    table.insert(rgbParts, {inst=inst, prop=prop, sat=sat or 0.7, val=val or 0.9})
end

RunService.RenderStepped:Connect(function()
    if not State.rgbUI then return end
    rgbHue = (rgbHue + State.rgbSpeed) % 1
    for _, p in ipairs(rgbParts) do
        pcall(function() p.inst[p.prop] = Color3.fromHSV(rgbHue, p.sat, p.val) end)
    end
end)

--============================================================
-- AIMBOT
--============================================================
local Aimbot = {locked=nil, fovCircle=nil, origSens=nil}

local function getClosest()
    local maxDist = State.fovEnabled and State.fovAmount or 2000
    local closest, closestDist = nil, maxDist
    local mouse = UserInputService:GetMouseLocation()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer or not plr.Character then continue end
        local part = plr.Character:FindFirstChild(State.aimbotLockPart)
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        if not part or not hum then continue end
        if State.aimbotTeamCheck and plr.TeamColor == LocalPlayer.TeamColor then continue end
        if State.aimbotAliveCheck and hum.Health <= 0 then continue end
        if State.aimbotWallCheck then
            local params = RaycastParams.new()
            params.FilterDescendantsInstances = {LocalPlayer.Character}
            local result = workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, params)
            if result and not result.Instance:IsDescendantOf(plr.Character) then continue end
        end
        local vec, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        local dist = (mouse - Vector2.new(vec.X, vec.Y)).Magnitude
        if dist < closestDist then closestDist = dist; closest = plr end
    end
    return closest
end

local function aimbotStart()
    Aimbot.origSens = UserInputService.MouseDeltaSensitivity
    if hasDrawing and not Aimbot.fovCircle then
        Aimbot.fovCircle = Drawing.new("Circle")
    end
end

local function aimbotStop()
    if Aimbot.fovCircle then Aimbot.fovCircle.Visible = false end
    if Aimbot.origSens then UserInputService.MouseDeltaSensitivity = Aimbot.origSens end
    Aimbot.locked = nil
end

RunService.RenderStepped:Connect(function()
    if not State.aimbotEnabled then
        if Aimbot.fovCircle then Aimbot.fovCircle.Visible = false end
        return
    end
    if Aimbot.fovCircle then
        local m = UserInputService:GetMouseLocation()
        Aimbot.fovCircle.Position = m
        Aimbot.fovCircle.Radius = State.fovAmount
        Aimbot.fovCircle.Visible = State.fovVisible
        Aimbot.fovCircle.Color = State.fovColor
        Aimbot.fovCircle.Transparency = State.fovTransparency
        Aimbot.fovCircle.Thickness = State.fovThickness
        Aimbot.fovCircle.Filled = State.fovFilled
    end
    local target = getClosest()
    if target then
        if Aimbot.locked ~= target then
            Aimbot.locked = target
            if Aimbot.fovCircle then Aimbot.fovCircle.Color = State.fovLockedColor end
        end
        local part = target.Character and target.Character:FindFirstChild(State.aimbotLockPart)
        if part then
            if State.aimbotThirdPerson then
                local vec = Camera:WorldToViewportPoint(part.Position)
                local delta = Vector2.new(vec.X, vec.Y) - UserInputService:GetMouseLocation()
                mousemoverel(delta.X / State.aimbotThirdPersonSens, delta.Y / State.aimbotThirdPersonSens)
            else
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, part.Position), 1 - math.clamp(State.aimbotSensitivity, 0.01, 1))
            end
        end
    elseif Aimbot.locked then
        Aimbot.locked = nil
        if Aimbot.fovCircle then Aimbot.fovCircle.Color = State.fovColor end
    end
end)

UserInputService.InputBegan:Connect(function(i, gpe)
    if gpe then return end
    if i.KeyCode.Name == State.aimbotKey or (i.UserInputType == Enum.UserInputType.MouseButton2 and State.aimbotKey == "MouseButton2") then
        State.aimbotEnabled = not State.aimbotEnabled
        if State.aimbotEnabled then aimbotStart() else aimbotStop() end
    end
end)

--============================================================
-- ESP
--============================================================
local espFolder = Instance.new("Folder")
espFolder.Name = "H3Y0_ESP"
espFolder.Parent = workspace
local espConns = {}

local function espClear()
    for _, c in ipairs(espFolder:GetChildren()) do c:Destroy() end
    for _, c in ipairs(espConns) do pcall(function() c:Disconnect() end) end
    espConns = {}
end

local function espAdd(plr)
    if plr == LocalPlayer then return end
    local function update()
        if not State.espEnabled then return end
        if State.espTeamCheck and plr.TeamColor == LocalPlayer.TeamColor then return end
        local char = plr.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum or (State.espAliveCheck and hum.Health <= 0) then return end
        local hl = espFolder:FindFirstChild(plr.Name.."_HL")
        if not hl then
            hl = Instance.new("Highlight")
            hl.Name = plr.Name.."_HL"
            hl.Adornee = char
            hl.OutlineColor = Color3.new(1,1,1)
            hl.Parent = espFolder
        end
        hl.FillColor = State.espColor
        hl.FillTransparency = State.espTransparency
        hl.Enabled = true
    end
    update()
    table.insert(espConns, RunService.Heartbeat:Connect(update))
end

local function espStart()
    espClear()
    for _, p in ipairs(Players:GetPlayers()) do espAdd(p) end
    table.insert(espConns, Players.PlayerAdded:Connect(function(p)
        p.CharacterAdded:Connect(function() task.wait(0.5); if State.espEnabled then espAdd(p) end end)
    end))
end

local function espStop() espClear() end

--============================================================
-- CROSSHAIR (extended)
--============================================================
local CH = {
    lines = {},       -- 4 line objects
    dot = nil,        -- center dot Circle
    label = nil,      -- Text
    angle = 0,        -- rotation angle
    pulsePhase = 0,   -- pulse phase
    hue = 0,          -- crosshair-specific hue
    labelHue = 0,     -- label hue
}

local function crosshairInit()
    if not hasDrawing then return end
    for i = 1, 4 do
        local l = Drawing.new("Line")
        l.Visible = false
        l.Thickness = 1
        l.Transparency = 0.5
        CH.lines[i] = l
    end
    CH.dot = Drawing.new("Circle")
    CH.dot.NumSides = 24
    CH.dot.Filled = true
    CH.dot.Visible = false
    CH.label = Drawing.new("Text")
    CH.label.Center = true
    CH.label.Outline = true
    CH.label.OutlineColor = Color3.new(0, 0, 0)
    CH.label.Visible = false
end

local function crosshairUpdate(dt)
    if not hasDrawing then return end
    if not State.crosshairEnabled then
        for _, l in ipairs(CH.lines) do l.Visible = false end
        if CH.dot then CH.dot.Visible = false end
        if CH.label then CH.label.Visible = false end
        return
    end

    -- rotation phase
    if State.crosshairRotate then
        CH.angle = (CH.angle + dt * State.crosshairRotateSpeed) % (math.pi * 2)
    end

    -- pulse phase (size multiplier)
    local sizeMul = 1
    if State.crosshairPulse then
        CH.pulsePhase = (CH.pulsePhase + dt * State.crosshairPulseSpeed) % (math.pi * 2)
        sizeMul = 1 + math.sin(CH.pulsePhase) * State.crosshairPulseAmount
    end

    -- colors
    local baseColor = State.crosshairColor
    if State.crosshairRainbow then
        CH.hue = (CH.hue + dt * State.crosshairRainbowSpeed) % 1
        baseColor = Color3.fromHSV(CH.hue, State.crosshairRainbowSaturation, State.crosshairRainbowValue)
    end

    local c = UserInputService:GetMouseLocation()
    local s = State.crosshairSize * sizeMul
    local g = State.crosshairGap
    local th = State.crosshairThickness
    local tr = 1 - State.crosshairTransparency

    -- style offsets
    local style = State.crosshairStyle
    local offsets
    if style == "X" then
        local d = (s + g) * 0.7071
        offsets = {
            {Vector2.new(c.X - d, c.Y - d), Vector2.new(c.X - g * 0.7071, c.Y - g * 0.7071)},
            {Vector2.new(c.X + g * 0.7071, c.Y + g * 0.7071), Vector2.new(c.X + d, c.Y + d)},
            {Vector2.new(c.X - d, c.Y + d), Vector2.new(c.X - g * 0.7071, c.Y + g * 0.7071)},
            {Vector2.new(c.X + g * 0.7071, c.Y - g * 0.7071), Vector2.new(c.X + d, c.Y - d)},
        }
    else
        offsets = {
            {Vector2.new(c.X - s - g, c.Y), Vector2.new(c.X - g, c.Y)},
            {Vector2.new(c.X + g, c.Y), Vector2.new(c.X + s + g, c.Y)},
            {Vector2.new(c.X, c.Y - s - g), Vector2.new(c.X, c.Y - g)},
            {Vector2.new(c.X, c.Y + g), Vector2.new(c.X, c.Y + s + g)},
        }
    end

    -- rotation transform around center
    if State.crosshairRotate and CH.angle ~= 0 then
        local ca, sa = math.cos(CH.angle), math.sin(CH.angle)
        for i = 1, 4 do
            local a, b = offsets[i][1] - c, offsets[i][2] - c
            offsets[i][1] = Vector2.new(a.X * ca - a.Y * sa, a.X * sa + a.Y * ca) + c
            offsets[i][2] = Vector2.new(b.X * ca - b.Y * sa, b.X * sa + b.Y * ca) + c
        end
    end

    for i = 1, 4 do
        local l = CH.lines[i]
        l.From = offsets[i][1]
        l.To = offsets[i][2]
        l.Color = baseColor
        l.Thickness = th
        l.Transparency = tr
        l.Visible = true
    end

    -- center dot
    if CH.dot then
        CH.dot.Position = c
        CH.dot.Radius = State.crosshairDotSize * sizeMul
        CH.dot.Color = baseColor
        CH.dot.Transparency = tr
        CH.dot.Visible = State.crosshairCenterDot
    end

    -- label
    if CH.label then
        if State.labelEnabled then
            local labelColor = State.labelColor
            if State.labelRainbow then
                CH.labelHue = (CH.labelHue + dt * 0.5) % 1
                labelColor = Color3.fromHSV(CH.labelHue, 1, 1)
            end
            CH.label.Text = State.labelText
            CH.label.Size = State.labelSize
            CH.label.Color = labelColor
            CH.label.Transparency = 1 - State.labelTransparency
            CH.label.Position = Vector2.new(c.X, c.Y + State.crosshairSize * sizeMul + State.labelOffset)
            CH.label.Visible = true
        else
            CH.label.Visible = false
        end
    end
end

if hasDrawing then crosshairInit() end

--============================================================
-- UI
--============================================================
local T = {
    BG = Color3.fromRGB(18,18,24),
    Surface = Color3.fromRGB(28,28,36),
    SurfaceAlt = Color3.fromRGB(38,38,48),
    Text = Color3.fromRGB(235,235,240),
    TextDim = Color3.fromRGB(140,140,155),
    Accent = Color3.fromRGB(160,90,255),
    Success = Color3.fromRGB(70,210,130),
    Danger = Color3.fromRGB(230,70,90),
    Border = Color3.fromRGB(55,55,68),
}

local H3Y0 = { _gui = nil }

local function notify(text, kind)
    if not State.notifications or not H3Y0._gui then return end
    local c = (kind=="success" and T.Success) or (kind=="error" and T.Danger) or T.Accent
    local t = new("TextLabel",{Size=UDim2.new(0,280,0,32),Position=UDim2.new(1,-300,1,-46),BackgroundColor3=T.Surface,BorderSizePixel=0,Text="  "..text,TextColor3=T.Text,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Parent=H3Y0._gui})
    corner(t,6); stroke(t,c,2)
    task.delay(2.5,function() pcall(function() t:Destroy() end) end)
end

local function buildUI()
    deserializeState(loadJson("H3Y0_config.json"))

    local gui = new("ScreenGui",{Name="H3Y0_HUB",ResetOnSpawn=false,IgnoreGuiInset=true,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=999,Parent=parentGui})
    H3Y0._gui = gui

    local main = new("Frame",{Size=UDim2.new(0,600,0,440),Position=UDim2.new(0.5,-300,0.5,-220),BackgroundColor3=T.BG,BorderSizePixel=0,ClipsDescendants=true,Parent=gui})
    corner(main,10); stroke(main,T.Border)

    local bar = new("Frame",{Size=UDim2.new(1,0,0,44),BackgroundColor3=T.Surface,BorderSizePixel=0,Parent=main})
    corner(bar,10)
    registerRGB(bar, "BackgroundColor3", 0.6, 0.25)

    new("TextLabel",{Size=UDim2.new(0.6,0,1,0),Position=UDim2.new(0,14,0,0),BackgroundTransparency=1,Text="H3Y0 HUB",TextColor3=T.Text,Font=Enum.Font.GothamBold,TextSize=18,TextXAlignment=Enum.TextXAlignment.Left,Parent=bar})
    new("TextLabel",{Size=UDim2.new(0.3,0,1,0),Position=UDim2.new(0.65,0,0,0),BackgroundTransparency=1,Text="v4.0",TextColor3=T.TextDim,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Right,Parent=bar})

    local close = new("TextButton",{Size=UDim2.new(0,28,0,28),Position=UDim2.new(1,-36,0,8),BackgroundColor3=T.Danger,BorderSizePixel=0,Text="×",TextColor3=T.Text,Font=Enum.Font.GothamBold,TextSize=18,Parent=bar})
    corner(close,6); close.MouseButton1Click:Connect(function() gui.Enabled = false end)

    -- drag
    local dragging, ds, sp
    bar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging=true; ds=i.Position; sp=main.Position end end)
    UserInputService.InputChanged:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then local d=i.Position-ds; main.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging=false end end)

    -- tabs
    local tabs = {"Aimbot","ESP","Crosshair","Settings"}
    local tabBar = new("Frame",{Size=UDim2.new(1,-16,0,30),Position=UDim2.new(0,8,0,50),BackgroundTransparency=1,Parent=main})
    new("UIListLayout",{Padding=UDim.new(0,4),FillDirection=Enum.FillDirection.Horizontal,Parent=tabBar})
    local pages = {}
    local content = new("Frame",{Size=UDim2.new(1,-16,1,-88),Position=UDim2.new(0,8,0,84),BackgroundTransparency=1,Parent=main})

    local function selectTab(name)
        for n,p in pairs(pages) do p.Visible = (n==name) end
    end

    for _, name in ipairs(tabs) do
        local btn = new("TextButton",{Size=UDim2.new(0,0,1,0),AutomaticSize=Enum.AutomaticSize.X,BackgroundColor3=T.SurfaceAlt,BorderSizePixel=0,Text=name,TextColor3=T.TextDim,Font=Enum.Font.Gotham,TextSize=12,Parent=tabBar})
        corner(btn,6); pad(btn,8)
        local page = new("ScrollingFrame",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.new(0,0,0,0),Visible=false,Parent=content})
        new("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder,Parent=page}); pad(page,4)
        pages[name] = page
        btn.MouseButton1Click:Connect(function()
            selectTab(name)
            for _,b in ipairs(tabBar:GetChildren()) do if b:IsA("TextButton") then tween(b,{BackgroundColor3=T.SurfaceAlt,TextColor3=T.TextDim}) end end
            tween(btn,{BackgroundColor3=T.Accent,TextColor3=T.Text})
        end)
        if name == "Aimbot" then selectTab(name); tween(btn,{BackgroundColor3=T.Accent,TextColor3=T.Text}) end
    end

    -- helpers
    local function addToggle(parent, name, key, cb)
        local v = State[key] or false
        local h = new("Frame",{Size=UDim2.new(1,0,0,38),BackgroundColor3=T.Surface,BorderSizePixel=0,Parent=parent})
        corner(h,6); stroke(h)
        new("TextLabel",{Size=UDim2.new(0.7,0,1,0),Position=UDim2.new(0,12,0,0),BackgroundTransparency=1,Text=name,TextColor3=T.Text,Font=Enum.Font.Gotham,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,Parent=h})
        local tr = new("Frame",{Size=UDim2.new(0,40,0,20),Position=UDim2.new(1,-52,0.5,-10),BackgroundColor3=v and T.Success or T.SurfaceAlt,BorderSizePixel=0,Parent=h})
        corner(tr,10)
        local kn = new("Frame",{Size=UDim2.new(0,16,0,16),Position=UDim2.new(0,v and 22 or 2,0.5,-8),BackgroundColor3=T.Text,BorderSizePixel=0,Parent=tr})
        corner(kn,8)
        local btn = new("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",Parent=h})
        local function set(val)
            State[key]=val
            tween(tr,{BackgroundColor3=val and T.Success or T.SurfaceAlt})
            tween(kn,{Position=UDim2.new(0,val and 22 or 2,0.5,-8)})
            if cb then cb(val) end
            saveConfig()
        end
        btn.MouseButton1Click:Connect(function() set(not State[key]) end)
        if v and cb then cb(v) end
    end

    local function addSlider(parent, name, key, min, max, cb)
        local v = State[key] or min
        local h = new("Frame",{Size=UDim2.new(1,0,0,46),BackgroundColor3=T.Surface,BorderSizePixel=0,Parent=parent})
        corner(h,6); stroke(h)
        new("TextLabel",{Size=UDim2.new(0.6,0,0,18),Position=UDim2.new(0,12,0,6),BackgroundTransparency=1,Text=name,TextColor3=T.Text,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Parent=h})
        local vl = new("TextLabel",{Size=UDim2.new(0.25,0,0,18),Position=UDim2.new(0.7,0,0,6),BackgroundTransparency=1,Text=tostring(math.floor(v*100)/100),TextColor3=T.Accent,Font=Enum.Font.GothamBold,TextSize=12,TextXAlignment=Enum.TextXAlignment.Right,Parent=h})
        local bar = new("Frame",{Size=UDim2.new(1,-24,0,6),Position=UDim2.new(0,12,1,-14),BackgroundColor3=T.SurfaceAlt,BorderSizePixel=0,Parent=h})
        corner(bar,3)
        local fill = new("Frame",{Size=UDim2.new((v-min)/(max-min),0,1,0),BackgroundColor3=T.Accent,BorderSizePixel=0,Parent=bar})
        corner(fill,3)
        local btn = new("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",Parent=h})
        local function apply(x)
            local a = math.clamp(x,0,1)
            local val = min + (max-min)*a
            fill.Size = UDim2.new(a,0,1,0); vl.Text = tostring(math.floor(val*100)/100)
            State[key]=val; if cb then cb(val) end; saveConfig()
        end
        local drag=false
        btn.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true; apply((i.Position.X-bar.AbsolutePosition.X)/bar.AbsoluteSize.X) end end)
        UserInputService.InputChanged:Connect(function(i) if drag and i.UserInputType==Enum.UserInputType.MouseMovement then apply((i.Position.X-bar.AbsolutePosition.X)/bar.AbsoluteSize.X) end end)
        UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
        if cb then cb(v) end
    end

    local function addTextbox(parent, name, key, cb)
        local v = State[key] or ""
        local h = new("Frame",{Size=UDim2.new(1,0,0,38),BackgroundColor3=T.Surface,BorderSizePixel=0,Parent=parent})
        corner(h,6); stroke(h)
        new("TextLabel",{Size=UDim2.new(0.4,0,1,0),Position=UDim2.new(0,12,0,0),BackgroundTransparency=1,Text=name,TextColor3=T.Text,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Parent=h})
        local box = new("TextBox",{Size=UDim2.new(0.55,0,0,26),Position=UDim2.new(0.4,0,0.5,-13),BackgroundColor3=T.SurfaceAlt,BorderSizePixel=0,Text=v,TextColor3=T.Text,Font=Enum.Font.Gotham,TextSize=12,ClearTextOnFocus=false,Parent=h})
        corner(box,5); stroke(box)
        box.FocusLost:Connect(function(enter)
            if enter then State[key]=box.Text; if cb then cb(box.Text) end; saveConfig() end
        end)
    end

    local function addDropdown(parent, name, key, options, cb)
        local v = State[key] or options[1]
        local h = new("Frame",{Size=UDim2.new(1,0,0,38),BackgroundColor3=T.Surface,BorderSizePixel=0,Parent=parent})
        corner(h,6); stroke(h)
        new("TextLabel",{Size=UDim2.new(0.55,0,1,0),Position=UDim2.new(0,12,0,0),BackgroundTransparency=1,Text=name,TextColor3=T.Text,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Parent=h})
        local btn = new("TextButton",{Size=UDim2.new(0,110,0,26),Position=UDim2.new(1,-122,0.5,-13),BackgroundColor3=T.SurfaceAlt,BorderSizePixel=0,Text=v.." ▾",TextColor3=T.Text,Font=Enum.Font.Gotham,TextSize=12,Parent=h})
        corner(btn,5); stroke(btn)
        local list = new("Frame",{Size=UDim2.new(0,110,0,0),Position=UDim2.new(1,-122,1,4),BackgroundColor3=T.SurfaceAlt,BorderSizePixel=0,Visible=false,ZIndex=10,Parent=h})
        corner(list,5); stroke(list)
        new("UIListLayout",{Padding=UDim.new(0,2),SortOrder=Enum.SortOrder.LayoutOrder,Parent=list})
        for _, opt in ipairs(options) do
            local item = new("TextButton",{Size=UDim2.new(1,-8,0,24),BackgroundTransparency=1,Text=opt,TextColor3=T.Text,Font=Enum.Font.Gotham,TextSize=12,ZIndex=11,Parent=list})
            item.MouseButton1Click:Connect(function()
                State[key]=opt; btn.Text=opt.." ▾"; list.Visible=false
                if cb then cb(opt) end; saveConfig()
            end)
        end
        btn.MouseButton1Click:Connect(function()
            list.Visible = not list.Visible
            list.Size = UDim2.new(0,110,0,math.min(#options*26+4,150))
        end)
    end

    --========== AIMBOT ==========
    local aim = pages.Aimbot
    new("TextLabel",{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,Text="Aimbot",TextColor3=T.TextDim,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Parent=aim})
    addToggle(aim,"Enabled","aimbotEnabled",function(v) if v then aimbotStart() else aimbotStop() end end)
    addToggle(aim,"Team Check","aimbotTeamCheck")
    addToggle(aim,"Alive Check","aimbotAliveCheck")
    addToggle(aim,"Wall Check","aimbotWallCheck")
    addToggle(aim,"Third Person","aimbotThirdPerson")
    addSlider(aim,"Sensitivity","aimbotSensitivity",0.01,1)
    addSlider(aim,"Third Person Sens","aimbotThirdPersonSens",0.1,5)
    addDropdown(aim,"Lock Part","aimbotLockPart",{"Head","HumanoidRootPart","Torso","UpperTorso","LowerTorso"})
    new("TextLabel",{Size=UDim2.new(1,0,0,18),BackgroundTransparency=1,Text="FOV","TextColor3=T.TextDim,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Parent=aim})
    addToggle(aim,"FOV Enabled","fovEnabled")
    addToggle(aim,"FOV Visible","fovVisible")
    addSlider(aim,"FOV Amount","fovAmount",10,300)
    addSlider(aim,"FOV Transparency","fovTransparency",0,1)
    addToggle(aim,"FOV Filled","fovFilled")

    --========== ESP ==========
    local esp = pages.ESP
    new("TextLabel",{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,Text="ESP","TextColor3=T.TextDim,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Parent=esp})
    addToggle(esp,"Enabled","espEnabled",function(v) if v then espStart() else espStop() end end)
    addToggle(esp,"Team Check","espTeamCheck")
    addToggle(esp,"Alive Check","espAliveCheck")
    addSlider(esp,"Transparency","espTransparency",0,1)

    --========== CROSSHAIR ==========
    local ch = pages.Crosshair
    new("TextLabel",{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,Text="Crosshair","TextColor3=T.TextDim,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Parent=ch})
    addToggle(ch,"Enabled","crosshairEnabled")
    addDropdown(ch,"Style","crosshairStyle",{"Cross","X","Circle"})
    addSlider(ch,"Size","crosshairSize",2,60)
    addSlider(ch,"Thickness","crosshairThickness",1,8)
    addSlider(ch,"Gap","crosshairGap",0,30)
    addSlider(ch,"Transparency","crosshairTransparency",0,1)
    addToggle(ch,"Center Dot","crosshairCenterDot")
    addSlider(ch,"Dot Size","crosshairDotSize",1,8)

    new("TextLabel",{Size=UDim2.new(1,0,0,18),BackgroundTransparency=1,Text="Rainbow","TextColor3=T.TextDim,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Parent=ch})
    addToggle(ch,"Rainbow Color","crosshairRainbow")
    addSlider(ch,"Rainbow Speed","crosshairRainbowSpeed",0.001,0.02)
    addSlider(ch,"Rainbow Saturation","crosshairRainbowSaturation",0,1)
    addSlider(ch,"Rainbow Value","crosshairRainbowValue",0,1)

    new("TextLabel",{Size=UDim2.new(1,0,0,18),BackgroundTransparency=1,Text="Rotation","TextColor3=T.TextDim,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Parent=ch})
    addToggle(ch,"Rotate","crosshairRotate")
    addSlider(ch,"Rotate Speed","crosshairRotateSpeed",0.1,8)

    new("TextLabel",{Size=UDim2.new(1,0,0,18),BackgroundTransparency=1,Text="Pulse","TextColor3=T.TextDim,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Parent=ch})
    addToggle(ch,"Pulse","crosshairPulse")
    addSlider(ch,"Pulse Speed","crosshairPulseSpeed",0.1,6)
    addSlider(ch,"Pulse Amount","crosshairPulseAmount",0.05,1)

    new("TextLabel",{Size=UDim2.new(1,0,0,18),BackgroundTransparency=1,Text="Label","TextColor3=T.TextDim,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Parent=ch})
    addToggle(ch,"Show Label","labelEnabled")
    addTextbox(ch,"Label Text","labelText")
    addToggle(ch,"Label Rainbow","labelRainbow")
    addSlider(ch,"Label Size","labelSize",8,32)
    addSlider(ch,"Label Offset","labelOffset",0,80)
    addSlider(ch,"Label Transparency","labelTransparency",0,1)

    --========== SETTINGS ==========
    local set = pages.Settings
    new("TextLabel",{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,Text="Player","TextColor3=T.TextDim,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Parent=set})
    addSlider(set,"WalkSpeed","walkSpeed",16,200,function(v)
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = v end
    end)
    addSlider(set,"JumpPower","jumpPower",50,300,function(v)
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then h.JumpPower = v; h.UseJumpPower = true end
    end)
    addToggle(set,"Fullbright","fullbright",function(v)
        Lighting.Brightness = v and 3 or 1
        Lighting.ClockTime = v and 12 or 14
    end)
    new("TextLabel",{Size=UDim2.new(1,0,0,18),BackgroundTransparency=1,Text="RGB UI","TextColor3=T.TextDim,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Parent=set})
    addToggle(set,"RGB Enabled","rgbUI")
    addSlider(set,"RGB Speed","rgbSpeed",0.001,0.02,function(v) State.rgbSpeed = v end)
    addToggle(set,"Notifications","notifications")

    -- hotkey
    UserInputService.InputBegan:Connect(function(i,gpe)
        if gpe then return end
        if i.KeyCode.Name == State.toggleKey then gui.Enabled = not gui.Enabled end
    end)

    notify("H3Y0 v4 loaded", "success")
end

--============================================================
-- RENDER LOOP for crosshair (dt-aware)
--============================================================
RunService.RenderStepped:Connect(function(dt)
    local ok, err = pcall(crosshairUpdate, dt)
    if not ok then warn("[H3Y0] crosshair update error:", err) end
end)

--============================================================
-- BOOT
--============================================================
pcall(buildUI)
return true
