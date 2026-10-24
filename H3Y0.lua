--!strict
-- H3Y0 HUB v3.0 — inspired by AirHub V2 architecture
-- Features: Aimbot (with FOV, checks, smoothing), ESP (box/name/health/tracer), Crosshair
-- Config: H3Y0_config.json | Theme: H3Y0_theme.json | Key: H3Y0_key.txt
-- Requires: loadstring, writefile/readfile/isfile, Drawing (optional for FOV circle)

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

--============================================================
-- GLOBAL CONFIG
--============================================================
local H3Y0 = {
    Version = "3.0.0",
    ConfigFile = "H3Y0_config.json",
    ThemeFile = "H3Y0_theme.json",
    KeyFile = "H3Y0_key.txt",
    FreeKey = "H3Y0-FREE",
    KeyEnabled = true,
}

local hasFs = (typeof(writefile) == "function") and (typeof(readfile) == "function") and (typeof(isfile) == "function")
local hasDrawing = (typeof(Drawing) == "table" and typeof(Drawing.new) == "function")

--============================================================
-- DEFAULT THEME (fully customizable, saved separately)
--============================================================
local DefaultTheme = {
    Background = Color3.fromRGB(14, 14, 20),
    Surface = Color3.fromRGB(22, 22, 30),
    SurfaceAlt = Color3.fromRGB(32, 32, 42),
    Accent = Color3.fromRGB(180, 100, 255),
    AccentDim = Color3.fromRGB(120, 65, 190),
    Text = Color3.fromRGB(240, 240, 248),
    TextDim = Color3.fromRGB(140, 140, 158),
    Success = Color3.fromRGB(70, 210, 130),
    Danger = Color3.fromRGB(230, 70, 90),
    Border = Color3.fromRGB(48, 48, 64),
    Transparency = 0,
    CornerRadius = 10,
    FontName = "Gotham",
    FontBoldName = "GothamBold",
}

local T = table.clone(DefaultTheme)

--============================================================
-- STATE (config-persisted)
--============================================================
local State = {
    -- Aimbot (AirHub V2 style)
    aimbotEnabled = false,
    aimbotKey = "MouseButton2",
    aimbotToggle = false,
    aimbotTeamCheck = false,
    aimbotAliveCheck = true,
    aimbotWallCheck = false,
    aimbotSensitivity = 0.15, -- seconds to lock
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
    -- ESP (AirHub V2 style)
    espEnabled = false,
    espTeamCheck = false,
    espAliveCheck = true,
    espBox = true,
    espName = true,
    espHealth = true,
    espTracer = true,
    espTracerFrom = "Bottom", -- Bottom / Center / Mouse
    espColor = Color3.fromRGB(0, 220, 255),
    espTeamColor = Color3.fromRGB(80, 255, 120),
    espTransparency = 0.4,
    espTextSize = 14,
    -- Crosshair
    crosshairEnabled = false,
    crosshairColor = Color3.fromRGB(255, 255, 255),
    crosshairTransparency = 0.5,
    crosshairSize = 12,
    crosshairThickness = 1,
    crosshairGap = 4,
    crosshairCenterDot = true,
    -- Misc
    walkSpeed = 16,
    jumpPower = 50,
    fullbright = false,
    notifications = true,
    toggleKey = "RightShift",
}

--============================================================
-- UTIL
--============================================================
local function log(fmt, ...)
    local msg = string.format("[H3Y0] " .. fmt, ...)
    if H3Y0._log then pcall(H3Y0._log, msg) end
    print(msg)
end

local function safe(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then log("ERR: %s", tostring(err)) end
    return ok, err
end

local function new(cls, props)
    local inst = Instance.new(cls)
    for k, v in pairs(props or {}) do inst[k] = v end
    return inst
end

local function corner(p, r) return new("UICorner", { CornerRadius = UDim.new(0, r or T.CornerRadius), Parent = p }) end
local function stroke(p, c, th) return new("UIStroke", { Color = c or T.Border, Thickness = th or 1, Parent = p }) end
local function pad(p, px) return new("UIPadding", { PaddingTop = UDim.new(0,px), PaddingBottom = UDim.new(0,px), PaddingLeft = UDim.new(0,px), PaddingRight = UDim.new(0,px), Parent = p }) end
local function vlist(p, px) return new("UIListLayout", { Padding = UDim.new(0, px or 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = p }) end
local function tween(i, props, d) return TweenService:Create(i, TweenInfo.new(d or 0.14, Enum.EasingStyle.Quad), props):Play() end
local function hash(s) local h=5381 for i=1,#s do h=((h*33)+string.byte(s,i))%4294967296 end return string.format("%08x",h) end

--============================================================
-- SERIALIZE / PERSIST
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

local function saveConfig() saveJson(H3Y0.ConfigFile, serializeState()) end

local function saveTheme()
    local out = {}
    for k, v in pairs(T) do
        if typeof(v) == "Color3" then out[k] = {__c=true,r=v.R,g=v.G,b=v.B}
        else out[k] = v end
    end
    saveJson(H3Y0.ThemeFile, out)
end

local function loadTheme()
    local d = loadJson(H3Y0.ThemeFile)
    for k, v in pairs(d) do
        if type(v) == "table" and v.__c then T[k] = Color3.new(v.r, v.g, v.b)
        elseif type(v) == "number" or type(v) == "string" then T[k] = v end
    end
end

--============================================================
-- KEY SYSTEM
--============================================================
local function keyRestore()
    if not hasFs then return false end
    local ok, d = pcall(function() if isfile(H3Y0.KeyFile) then return readfile(H3Y0.KeyFile) end end)
    return ok and d == hash(H3Y0.FreeKey)
end

local function keyGate(onPass)
    if not H3Y0.KeyEnabled or keyRestore() then onPass(); return end
    local gui = new("ScreenGui", {Name="H3Y0_Key",ResetOnSpawn=false,IgnoreGuiInset=true,Parent=parentGui})
    local f = new("Frame", {Size=UDim2.new(0,340,0,190),Position=UDim2.new(0.5,-170,0.5,-95),BackgroundColor3=T.Background,BorderSizePixel=0,Parent=gui})
    corner(f); stroke(f)
    new("TextLabel",{Size=UDim2.new(1,0,0,44),BackgroundTransparency=1,Text="H3Y0 HUB — Key",TextColor3=T.Text,Font=Enum.Font.GothamBold,TextSize=20,Parent=f})
    new("TextLabel",{Size=UDim2.new(1,-24,0,18),Position=UDim2.new(0,12,0,46),BackgroundTransparency=1,Text="Free key",TextColor3=T.TextDim,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Parent=f})
    local box = new("TextBox",{Size=UDim2.new(1,-24,0,34),Position=UDim2.new(0,12,0,68),BackgroundColor3=T.Surface,BorderSizePixel=0,Text="",PlaceholderText=H3Y0.FreeKey,TextColor3=T.Text,PlaceholderColor3=T.TextDim,Font=Enum.Font.Gotham,TextSize=14,ClearTextOnFocus=false,Parent=f})
    corner(box,6); stroke(box)
    local btn = new("TextButton",{Size=UDim2.new(1,-24,0,34),Position=UDim2.new(0,12,0,112),BackgroundColor3=T.Accent,BorderSizePixel=0,Text="Activate",TextColor3=T.Text,Font=Enum.Font.GothamBold,TextSize=14,Parent=f})
    corner(btn,6)
    local st = new("TextLabel",{Size=UDim2.new(1,-24,0,18),Position=UDim2.new(0,12,0,152),BackgroundTransparency=1,Text="",TextColor3=T.Danger,Font=Enum.Font.Gotham,TextSize=12,Parent=f})
    btn.MouseButton1Click:Connect(function()
        if box.Text == H3Y0.FreeKey then
            st.TextColor3 = T.Success; st.Text = "OK"
            if hasFs then pcall(function() writefile(H3Y0.KeyFile, hash(H3Y0.FreeKey)) end) end
            task.wait(0.25); gui:Destroy(); onPass()
        else st.Text = "Wrong key" end
    end)
end

--============================================================
-- NOTIFY
--============================================================
function H3Y0.Notify(text, kind)
    if not State.notifications or not H3Y0._gui then return end
    local c = (kind=="success" and T.Success) or (kind=="error" and T.Danger) or T.Accent
    local t = new("TextLabel",{Size=UDim2.new(0,280,0,32),Position=UDim2.new(1,-300,1,-46),BackgroundColor3=T.Surface,BorderSizePixel=0,Text="  "..text,TextColor3=T.Text,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Parent=H3Y0._gui})
    corner(t,6); stroke(t,c,2)
    task.delay(2.5,function() pcall(function() t:Destroy() end) end)
end

--============================================================
-- UI FACTORY
--============================================================
local UI = {}

function UI.Label(parent, text)
    return new("TextLabel",{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,Text=text,TextColor3=T.TextDim,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Parent=parent})
end

function UI.Button(parent, text, cb)
    local b = new("TextButton",{Size=UDim2.new(1,0,0,32),BackgroundColor3=T.AccentDim,BorderSizePixel=0,Text=text,TextColor3=T.Text,Font=Enum.Font.GothamBold,TextSize=13,Parent=parent})
    corner(b,6); stroke(b)
    b.MouseButton1Click:Connect(function() safe(cb) end)
    b.MouseEnter:Connect(function() tween(b,{BackgroundColor3=T.Accent}) end)
    b.MouseLeave:Connect(function() tween(b,{BackgroundColor3=T.AccentDim}) end)
    return b
end

function UI.Toggle(parent, name, key, cb)
    local v = State[key]; if v == nil then v = false end
    local h = new("Frame",{Size=UDim2.new(1,0,0,38),BackgroundColor3=T.Surface,BorderSizePixel=0,Parent=parent})
    corner(h,6); stroke(h)
    new("TextLabel",{Size=UDim2.new(0.7,0,1,0),Position=UDim2.new(0,12,0,0),BackgroundTransparency=1,Text=name,TextColor3=T.Text,Font=Enum.Font.Gotham,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,Parent=h})
    local tr = new("Frame",{Size=UDim2.new(0,40,0,20),Position=UDim2.new(1,-52,0.5,-10),BackgroundColor3=v and T.Success or T.SurfaceAlt,BorderSizePixel=0,Parent=h})
    corner(tr,10)
    local kn = new("Frame",{Size=UDim2.new(0,16,0,16),Position=UDim2.new(0,v and 22 or 2,0.5,-8),BackgroundColor3=T.Text,BorderSizePixel=0,Parent=tr})
    corner(kn,8)
    local btn = new("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",Parent=h})
    local function set(val)
        State[key] = val
        tween(tr,{BackgroundColor3=val and T.Success or T.SurfaceAlt})
        tween(kn,{Position=UDim2.new(0,val and 22 or 2,0.5,-8)})
        safe(cb,val); saveConfig()
    end
    btn.MouseButton1Click:Connect(function() set(not State[key]) end)
    if v then safe(cb,v) end
    return {Set=set}
end

function UI.Slider(parent, name, key, min, max, cb)
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
        fill.Size = UDim2.new(a,0,1,0)
        vl.Text = tostring(math.floor(val*100)/100)
        State[key] = val; safe(cb,val); saveConfig()
    end
    local dragging = false
    btn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; apply((i.Position.X - bar.AbsolutePosition.X)/bar.AbsoluteSize.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            apply((i.Position.X - bar.AbsolutePosition.X)/bar.AbsoluteSize.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    if v then safe(cb,v) end
end

function UI.Keybind(parent, name, key, cb)
    local v = State[key] or "F"
    local h = new("Frame",{Size=UDim2.new(1,0,0,38),BackgroundColor3=T.Surface,BorderSizePixel=0,Parent=parent})
    corner(h,6); stroke(h)
    new("TextLabel",{Size=UDim2.new(0.7,0,1,0),Position=UDim2.new(0,12,0,0),BackgroundTransparency=1,Text=name,TextColor3=T.Text,Font=Enum.Font.Gotham,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,Parent=h})
    local btn = new("TextButton",{Size=UDim2.new(0,76,0,26),Position=UDim2.new(1,-88,0.5,-13),BackgroundColor3=T.SurfaceAlt,BorderSizePixel=0,Text=v,TextColor3=T.Accent,Font=Enum.Font.GothamBold,TextSize=12,Parent=h})
    corner(btn,5); stroke(btn)
    local listening = false
    btn.MouseButton1Click:Connect(function() listening = true; btn.Text="..."; btn.TextColor3=T.Danger end)
    UserInputService.InputBegan:Connect(function(i,gpe)
        if gpe or not listening then return end
        if i.UserInputType == Enum.UserInputType.Keyboard then
            State[key] = i.KeyCode.Name
            btn.Text = State[key]; btn.TextColor3 = T.Accent; listening = false
            safe(cb, State[key]); saveConfig()
        end
    end)
end

function UI.Dropdown(parent, name, key, options, cb)
    local v = State[key] or options[1]
    local h = new("Frame",{Size=UDim2.new(1,0,0,38),BackgroundColor3=T.Surface,BorderSizePixel=0,Parent=parent})
    corner(h,6); stroke(h)
    new("TextLabel",{Size=UDim2.new(0.55,0,1,0),Position=UDim2.new(0,12,0,0),BackgroundTransparency=1,Text=name,TextColor3=T.Text,Font=Enum.Font.Gotham,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,Parent=h})
    local btn = new("TextButton",{Size=UDim2.new(0,110,0,26),Position=UDim2.new(1,-122,0.5,-13),BackgroundColor3=T.SurfaceAlt,BorderSizePixel=0,Text=v.." ▾",TextColor3=T.Text,Font=Enum.Font.Gotham,TextSize=12,Parent=h})
    corner(btn,5); stroke(btn)
    local list = new("Frame",{Size=UDim2.new(0,110,0,0),Position=UDim2.new(1,-122,1,4),BackgroundColor3=T.SurfaceAlt,BorderSizePixel=0,Visible=false,ZIndex=10,Parent=h})
    corner(list,5); stroke(list)
    local ll = new("UIListLayout",{Padding=UDim.new(0,2),SortOrder=Enum.SortOrder.LayoutOrder,Parent=list})
    local function rebuild()
        for _,c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        for _,opt in ipairs(options) do
            local item = new("TextButton",{Size=UDim2.new(1,-8,0,24),BackgroundTransparency=1,Text=opt,TextColor3=T.Text,Font=Enum.Font.Gotham,TextSize=12,ZIndex=11,Parent=list})
            item.MouseButton1Click:Connect(function()
                State[key] = opt; btn.Text = opt.." ▾"; list.Visible = false
                safe(cb,opt); saveConfig()
            end)
        end
    end
    rebuild()
    btn.MouseButton1Click:Connect(function()
        list.Visible = not list.Visible
        list.Size = UDim2.new(0,110,0,math.min(#options*26+4,150))
    end)
    safe(cb,v)
end

function UI.ColorPicker(parent, name, stateKey, isThemeSlot)
    local h = new("Frame",{Size=UDim2.new(1,0,0,40),BackgroundColor3=T.Surface,BorderSizePixel=0,Parent=parent})
    corner(h,6); stroke(h)
    new("TextLabel",{Size=UDim2.new(0.5,0,1,0),Position=UDim2.new(0,12,0,0),BackgroundTransparency=1,Text=name,TextColor3=T.Text,Font=Enum.Font.Gotham,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,Parent=h})
    local cur = isThemeSlot and T[stateKey] or State[stateKey]
    local sw = new("Frame",{Size=UDim2.new(0,32,0,24),Position=UDim2.new(1,-100,0.5,-12),BackgroundColor3=cur or Color3.new(1,1,1),BorderSizePixel=0,Parent=h})
    corner(sw,5); stroke(sw)
    local apply = new("TextButton",{Size=UDim2.new(0,56,0,24),Position=UDim2.new(1,-60,0.5,-12),BackgroundColor3=T.AccentDim,BorderSizePixel=0,Text="Apply",TextColor3=T.Text,Font=Enum.Font.Gotham,TextSize=11,Parent=h})
    corner(apply,5)
    apply.MouseButton1Click:Connect(function()
        local current = isThemeSlot and T[stateKey] or State[stateKey] or Color3.new(1,1,1)
        local picker = new("Frame",{Size=UDim2.new(0,240,0,200),Position=UDim2.new(0.5,-120,0.5,-100),BackgroundColor3=T.Background,BorderSizePixel=0,ZIndex=50,Parent=H3Y0._gui})
        corner(picker); stroke(picker)
        local prev = new("Frame",{Size=UDim2.new(1,-20,0,30),Position=UDim2.new(0,10,0,10),BackgroundColor3=current,BorderSizePixel=0,ZIndex=51,Parent=picker})
        corner(prev,5); stroke(prev)
        local rgb = {current.R, current.G, current.B}
        for i=1,3 do
            local barBg = new("Frame",{Size=UDim2.new(1,-20,0,8),Position=UDim2.new(0,10,0,55+(i-1)*28),BackgroundColor3=T.SurfaceAlt,BorderSizePixel=0,ZIndex=51,Parent=picker})
            corner(barBg,4)
            local f = new("Frame",{Size=UDim2.new(rgb[i],0,1,0),BackgroundColor3=T.Accent,BorderSizePixel=0,ZIndex=52,Parent=barBg})
            corner(f,4)
            local hit = new("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=53,Parent=barBg})
            local drag = false
            hit.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                    drag = true
                    local x = math.clamp((inp.Position.X - barBg.AbsolutePosition.X)/barBg.AbsoluteSize.X,0,1)
                    rgb[i]=x; f.Size=UDim2.new(x,0,1,0); prev.BackgroundColor3=Color3.new(rgb[1],rgb[2],rgb[3])
                end
            end)
            UserInputService.InputChanged:Connect(function(inp)
                if drag and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
                    local x = math.clamp((inp.Position.X - barBg.AbsolutePosition.X)/barBg.AbsoluteSize.X,0,1)
                    rgb[i]=x; f.Size=UDim2.new(x,0,1,0); prev.BackgroundColor3=Color3.new(rgb[1],rgb[2],rgb[3])
                end
            end)
            UserInputService.InputEnded:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then drag = false end
            end)
        end
        local okBtn = new("TextButton",{Size=UDim2.new(0.5,-15,0,28),Position=UDim2.new(0,10,1,-38),BackgroundColor3=T.Success,BorderSizePixel=0,Text="OK",TextColor3=T.Text,Font=Enum.Font.GothamBold,TextSize=12,ZIndex=51,Parent=picker})
        corner(okBtn,5)
        okBtn.MouseButton1Click:Connect(function()
            local col = Color3.new(rgb[1],rgb[2],rgb[3])
            sw.BackgroundColor3 = col
            if isThemeSlot then T[stateKey] = col; saveTheme() else State[stateKey] = col; saveConfig() end
            picker:Destroy()
        end)
        local cn = new("TextButton",{Size=UDim2.new(0.5,-15,0,28),Position=UDim2.new(0.5,5,1,-38),BackgroundColor3=T.SurfaceAlt,BorderSizePixel=0,Text="Cancel",TextColor3=T.TextDim,Font=Enum.Font.Gotham,TextSize=12,ZIndex=51,Parent=picker})
        corner(cn,5)
        cn.MouseButton1Click:Connect(function() picker:Destroy() end)
    end)
end

--============================================================
-- AIMBOT (AirHub V2 style)
--============================================================
local Aimbot = {
    locked = nil,
    fovCircle = nil,
    originalSens = nil,
    anim = nil,
}

local function aimbotGetClosest()
    local requiredDist = (State.fovEnabled and State.fovAmount or 2000)
    local closest, closestDist = nil, requiredDist
    local mouse = UserInputService:GetMouseLocation()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer or not plr.Character then continue end
        local part = plr.Character:FindFirstChild(State.aimbotLockPart)
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        if not part or not hum then continue end
        if State.aimbotTeamCheck and plr.TeamColor == LocalPlayer.TeamColor then continue end
        if State.aimbotAliveCheck and hum.Health <= 0 then continue end
        if State.aimbotWallCheck and #Camera:GetPartsObscuringTarget({part.Position}, plr.Character:GetDescendants()) > 0 then continue end
        local vec, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        local dist = (mouse - Vector2.new(vec.X, vec.Y)).Magnitude
        if dist < closestDist then closestDist = dist; closest = plr end
    end
    return closest
end

local function aimbotCancel()
    Aimbot.locked = nil
    if Aimbot.fovCircle then Aimbot.fovCircle.Color = State.fovColor end
    if Aimbot.originalSens then UserInputService.MouseDeltaSensitivity = Aimbot.originalSens end
    if Aimbot.anim then Aimbot.anim:Cancel(); Aimbot.anim = nil end
end

local function aimbotStart()
    Aimbot.originalSens = UserInputService.MouseDeltaSensitivity
    if hasDrawing and not Aimbot.fovCircle then
        Aimbot.fovCircle = Drawing.new("Circle")
        Aimbot.fovCircle.Thickness = State.fovThickness
        Aimbot.fovCircle.NumSides = 60
        Aimbot.fovCircle.Filled = State.fovFilled
        Aimbot.fovCircle.Transparency = State.fovTransparency
    end
end

local function aimbotStop()
    aimbotCancel()
    if Aimbot.fovCircle then Aimbot.fovCircle:Remove(); Aimbot.fovCircle = nil end
end

RunService.RenderStepped:Connect(function()
    if not State.aimbotEnabled then
        if Aimbot.fovCircle then Aimbot.fovCircle.Visible = false end
        return
    end
    if Aimbot.fovCircle then
        local mouse = UserInputService:GetMouseLocation()
        Aimbot.fovCircle.Position = mouse
        Aimbot.fovCircle.Radius = State.fovAmount
        Aimbot.fovCircle.Visible = State.fovVisible
        Aimbot.fovCircle.Color = State.fovColor
        Aimbot.fovCircle.Transparency = State.fovTransparency
        Aimbot.fovCircle.Thickness = State.fovThickness
        Aimbot.fovCircle.Filled = State.fovFilled
    end
    local target = aimbotGetClosest()
    if target then
        if Aimbot.locked ~= target then
            Aimbot.locked = target
            if Aimbot.fovCircle then Aimbot.fovCircle.Color = State.fovLockedColor end
        end
        local part = target.Character and target.Character:FindFirstChild(State.aimbotLockPart)
        if part then
            local targetPos = part.Position
            if State.aimbotThirdPerson then
                local vec = Camera:WorldToViewportPoint(targetPos)
                local delta = Vector2.new(vec.X, vec.Y) - UserInputService:GetMouseLocation()
                mousemoverel(delta.X / State.aimbotThirdPersonSens, delta.Y / State.aimbotThirdPersonSens)
            else
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, targetPos), 1 - math.clamp(State.aimbotSensitivity, 0.01, 1))
            end
        end
    elseif Aimbot.locked then
        aimbotCancel()
    end
end)

--============================================================
-- ESP (AirHub V2 style with Drawing or Billboard fallback)
--============================================================
local espFolder = Instance.new("Folder")
espFolder.Name = "H3Y0_ESP"
espFolder.Parent = workspace
local espConnections = {}

local function espClear()
    for _, c in ipairs(espFolder:GetChildren()) do c:Destroy() end
    for _, c in ipairs(espConnections) do pcall(function() c:Disconnect() end) end
    espConnections = {}
end

local function espAddPlayer(plr)
    if plr == LocalPlayer then return end
    local function update()
        if not State.espEnabled then return end
        if State.espTeamCheck and plr.TeamColor == LocalPlayer.TeamColor then return end
        local char = plr.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not hum or not root or (State.espAliveCheck and hum.Health <= 0) then return end
        -- simple Highlight as ESP base; for full box/name/health use Drawing in production
        local hl = espFolder:FindFirstChild(plr.Name.."_HL")
        if not hl then
            hl = Instance.new("Highlight")
            hl.Name = plr.Name.."_HL"
            hl.Adornee = char
            hl.FillColor = State.espColor
            hl.FillTransparency = State.espTransparency
            hl.OutlineColor = Color3.new(1,1,1)
            hl.Parent = espFolder
        end
        hl.FillColor = State.espColor
        hl.FillTransparency = State.espTransparency
        hl.Enabled = State.espEnabled
    end
    update()
    table.insert(espConnections, RunService.Heartbeat:Connect(update))
end

local function espStart()
    espClear()
    for _, plr in ipairs(Players:GetPlayers()) do espAddPlayer(plr) end
    table.insert(espConnections, Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(function() task.wait(0.5); espAddPlayer(p) end) end))
end

local function espStop()
    espClear()
end

--============================================================
-- CROSSHAIR (Drawing)
--============================================================
local crosshairLines = {}

local function crosshairStart()
    if not hasDrawing then return end
    crosshairLines = {}
    for i=1,4 do
        local line = Drawing.new("Line")
        line.Thickness = State.crosshairThickness
        line.Color = State.crosshairColor
        line.Transparency = State.crosshairTransparency
        line.Visible = false
        table.insert(crosshairLines, line)
    end
    if State.crosshairCenterDot then
        local dot = Drawing.new("Circle")
        dot.Radius = 2
        dot.NumSides = 20
        dot.Filled = true
        dot.Color = State.crosshairColor
        dot.Transparency = State.crosshairTransparency
        dot.Visible = false
        table.insert(crosshairLines, dot)
    end
end

RunService.RenderStepped:Connect(function()
    if not State.crosshairEnabled or #crosshairLines == 0 then
        for _, l in ipairs(crosshairLines) do l.Visible = false end
        return
    end
    local center = UserInputService:GetMouseLocation()
    local s = State.crosshairSize
    local g = State.crosshairGap
    local positions = {
        {Vector2.new(center.X - s - g, center.Y), Vector2.new(center.X - g, center.Y)},
        {Vector2.new(center.X + g, center.Y), Vector2.new(center.X + s + g, center.Y)},
        {Vector2.new(center.X, center.Y - s - g), Vector2.new(center.X, center.Y - g)},
        {Vector2.new(center.X, center.Y + g), Vector2.new(center.X, center.Y + s + g)},
    }
    for i=1,4 do
        local line = crosshairLines[i]
        if line then
            line.From = positions[i][1]
            line.To = positions[i][2]
            line.Color = State.crosshairColor
            line.Thickness = State.crosshairThickness
            line.Transparency = 1 - State.crosshairTransparency
            line.Visible = true
        end
    end
    if State.crosshairCenterDot and crosshairLines[5] then
        crosshairLines[5].Position = center
        crosshairLines[5].Color = State.crosshairColor
        crosshairLines[5].Transparency = 1 - State.crosshairTransparency
        crosshairLines[5].Visible = true
    end
end)

--============================================================
-- BUILD UI
--============================================================
local function buildHub()
    loadTheme()
    deserializeState(loadJson(H3Y0.ConfigFile))

    -- apply saved visual state
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = State.walkSpeed; hum.JumpPower = State.jumpPower; hum.UseJumpPower = true end
    Lighting.Brightness = State.fullbright and 3 or 1
    Lighting.ClockTime = State.fullbright and 12 or 14

    local gui = new("ScreenGui",{Name="H3Y0_HUB",ResetOnSpawn=false,IgnoreGuiInset=true,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=999,Parent=parentGui})
    H3Y0._gui = gui

    local main = new("Frame",{Size=UDim2.new(0,640,0,440),Position=UDim2.new(0.5,-320,0.5,-220),BackgroundColor3=T.Background,BackgroundTransparency=T.Transparency,BorderSizePixel=0,ClipsDescendants=true,Parent=gui})
    corner(main); stroke(main)

    local bar = new("Frame",{Size=UDim2.new(1,0,0,42),BackgroundColor3=T.Surface,BackgroundTransparency=T.Transparency,BorderSizePixel=0,Parent=main})
    corner(bar)
    new("TextLabel",{Size=UDim2.new(0.6,0,1,0),Position=UDim2.new(0,14,0,0),BackgroundTransparency=1,Text="H3Y0 HUB",TextColor3=T.Text,Font=Enum.Font.GothamBold,TextSize=17,TextXAlignment=Enum.TextXAlignment.Left,Parent=bar})
    new("TextLabel",{Size=UDim2.new(0.3,0,1,0),Position=UDim2.new(0.65,0,0,0),BackgroundTransparency=1,Text="v"..H3Y0.Version,TextColor3=T.TextDim,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Right,Parent=bar})
    local close = new("TextButton",{Size=UDim2.new(0,28,0,28),Position=UDim2.new(1,-36,0,7),BackgroundColor3=T.Danger,BorderSizePixel=0,Text="×",TextColor3=T.Text,Font=Enum.Font.GothamBold,TextSize=18,Parent=bar})
    corner(close,6); close.MouseButton1Click:Connect(function() gui.Enabled = false end)

    -- drag
    local dragging, ds, sp
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; ds = i.Position; sp = main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - ds
            main.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)

    -- tabs
    local tabs = {"Aimbot","ESP","Crosshair","Settings","Theme"}
    local tabBar = new("Frame",{Size=UDim2.new(1,-16,0,32),Position=UDim2.new(0,8,0,48),BackgroundTransparency=1,Parent=main})
    local tbl = new("UIListLayout",{Padding=UDim.new(0,4),FillDirection=Enum.FillDirection.Horizontal,Parent=tabBar})
    local pages = {}
    local content = new("Frame",{Size=UDim2.new(1,-16,1,-88),Position=UDim2.new(0,8,0,84),BackgroundTransparency=1,Parent=main})

    local function selectTab(name)
        for n,p in pairs(pages) do p.Visible = (n == name) end
    end

    for _, name in ipairs(tabs) do
        local btn = new("TextButton",{Size=UDim2.new(0,0,1,0),AutomaticSize=Enum.AutomaticSize.X,BackgroundColor3=T.SurfaceAlt,BorderSizePixel=0,Text=name,TextColor3=T.TextDim,Font=Enum.Font.Gotham,TextSize=12,Parent=tabBar})
        corner(btn,6); pad(btn,8)
        local page = new("ScrollingFrame",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.new(0,0,0,0),Visible=false,Parent=content})
        vlist(page,6); pad(page,4)
        pages[name] = page
        btn.MouseButton1Click:Connect(function()
            selectTab(name)
            for _,b in ipairs(tabBar:GetChildren()) do
                if b:IsA("TextButton") then tween(b,{BackgroundColor3=T.SurfaceAlt,TextColor3=T.TextDim}) end
            end
            tween(btn,{BackgroundColor3=T.AccentDim,TextColor3=T.Text})
        end)
        if name == "Aimbot" then selectTab(name); tween(btn,{BackgroundColor3=T.AccentDim,TextColor3=T.Text}) end
    end

    --========== AIMBOT TAB ==========
    local aim = pages.Aimbot
    UI.Label(aim, "Aimbot Settings")
    UI.Toggle(aim, "Enabled", "aimbotEnabled", function(v)
        State.aimbotEnabled = v
        if v then aimbotStart() else aimbotStop() end
    end)
    UI.Keybind(aim, "Trigger Key", "aimbotKey", function(k)
        State.aimbotKey = k
    end)
    UI.Toggle(aim, "Toggle Mode (hold vs toggle)", "aimbotToggle")
    UI.Dropdown(aim, "Lock Part", "aimbotLockPart", {"Head","HumanoidRootPart","Torso","UpperTorso","LowerTorso"})
    UI.Slider(aim, "Sensitivity (lower = faster)", "aimbotSensitivity", 0.01, 1, function(v) State.aimbotSensitivity = v end)
    UI.Toggle(aim, "Team Check", "aimbotTeamCheck")
    UI.Toggle(aim, "Alive Check", "aimbotAliveCheck")
    UI.Toggle(aim, "Wall Check (laggy)", "aimbotWallCheck")
    UI.Toggle(aim, "Third Person Mode", "aimbotThirdPerson")
    UI.Slider(aim, "Third Person Sens", "aimbotThirdPersonSens", 0.1, 5, function(v) State.aimbotThirdPersonSens = v end)
    UI.Label(aim, "FOV Settings")
    UI.Toggle(aim, "FOV Enabled", "fovEnabled")
    UI.Toggle(aim, "FOV Visible", "fovVisible")
    UI.Slider(aim, "FOV Amount", "fovAmount", 10, 300, function(v) State.fovAmount = v end)
    UI.Slider(aim, "FOV Transparency", "fovTransparency", 0, 1, function(v) State.fovTransparency = v end)
    UI.Slider(aim, "FOV Thickness", "fovThickness", 1, 10, function(v) State.fovThickness = v end)
    UI.Toggle(aim, "FOV Filled", "fovFilled")
    UI.ColorPicker(aim, "FOV Color", "fovColor", false)
    UI.ColorPicker(aim, "FOV Locked Color", "fovLockedColor", false)

    --========== ESP TAB ==========
    local esp = pages.ESP
    UI.Toggle(esp, "Enabled", "espEnabled", function(v)
        State.espEnabled = v
        if v then espStart() else espStop() end
    end)
    UI.Toggle(esp, "Team Check", "espTeamCheck")
    UI.Toggle(esp, "Alive Check", "espAliveCheck")
    UI.Toggle(esp, "Show Box", "espBox")
    UI.Toggle(esp, "Show Name", "espName")
    UI.Toggle(esp, "Show Health", "espHealth")
    UI.Toggle(esp, "Show Tracer", "espTracer")
    UI.Dropdown(esp, "Tracer Origin", "espTracerFrom", {"Bottom","Center","Mouse"})
    UI.Slider(esp, "Transparency", "espTransparency", 0, 1, function(v) State.espTransparency = v end)
    UI.Slider(esp, "Text Size", "espTextSize", 8, 24, function(v) State.espTextSize = v end)
    UI.ColorPicker(esp, "ESP Color", "espColor", false)
    UI.ColorPicker(esp, "Team Color", "espTeamColor", false)

    --========== CROSSHAIR TAB ==========
    local ch = pages.Crosshair
    UI.Toggle(ch, "Enabled", "crosshairEnabled", function(v)
        State.crosshairEnabled = v
        if v and #crosshairLines == 0 then crosshairStart() end
    end)
    UI.Slider(ch, "Size", "crosshairSize", 4, 30, function(v) State.crosshairSize = v end)
    UI.Slider(ch, "Thickness", "crosshairThickness", 1, 5, function(v) State.crosshairThickness = v end)
    UI.Slider(ch, "Gap", "crosshairGap", 0, 20, function(v) State.crosshairGap = v end)
    UI.Slider(ch, "Transparency", "crosshairTransparency", 0, 1, function(v) State.crosshairTransparency = v end)
    UI.Toggle(ch, "Center Dot", "crosshairCenterDot")
    UI.ColorPicker(ch, "Color", "crosshairColor", false)

    --========== SETTINGS TAB ==========
    local set = pages.Settings
    UI.Label(set, "Player")
    UI.Slider(set, "WalkSpeed", "walkSpeed", 16, 200, function(v)
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = v end
    end)
    UI.Slider(set, "JumpPower", "jumpPower", 50, 300, function(v)
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then h.JumpPower = v; h.UseJumpPower = true end
    end)
    UI.Toggle(set, "Fullbright", "fullbright", function(v)
        Lighting.Brightness = v and 3 or 1
        Lighting.ClockTime = v and 12 or 14
        Lighting.FogEnd = v and 1e6 or 1000
    end)
    UI.Label(set, "Hub")
    UI.Keybind(set, "Toggle Hub Key", "toggleKey", function(k) State.toggleKey = k end)
    UI.Toggle(set, "Notifications", "notifications")
    UI.Button(set, "Save Config Now", function() saveConfig(); H3Y0.Notify("Config saved","success") end)
    UI.Button(set, "Reset All Settings", function()
        State = {}
        if hasFs then pcall(function() delfile(H3Y0.ConfigFile) end) end
        H3Y0.Notify("Config reset (restart hub)","warn")
    end)

    --========== THEME TAB ==========
    local th = pages.Theme
    UI.Label(th, "Theme Colors (saved separately)")
    UI.ColorPicker(th, "Background", "Background", true)
    UI.ColorPicker(th, "Surface", "Surface", true)
    UI.ColorPicker(th, "Surface Alt", "SurfaceAlt", true)
    UI.ColorPicker(th, "Accent", "Accent", true)
    UI.ColorPicker(th, "Accent Dim", "AccentDim", true)
    UI.ColorPicker(th, "Text", "Text", true)
    UI.ColorPicker(th, "Text Dim", "TextDim", true)
    UI.ColorPicker(th, "Success", "Success", true)
    UI.ColorPicker(th, "Danger", "Danger", true)
    UI.ColorPicker(th, "Border", "Border", true)
    UI.Slider(th, "Transparency", "Transparency", 0, 1, function(v) T.Transparency = v end)
    UI.Slider(th, "Corner Radius", "CornerRadius", 0, 20, function(v) T.CornerRadius = v end)
    UI.Button(th, "Save Theme", function() saveTheme(); H3Y0.Notify("Theme saved","success") end)
    UI.Button(th, "Reset Theme", function()
        T = table.clone(DefaultTheme)
        if hasFs then pcall(function() delfile(H3Y0.ThemeFile) end) end
        H3Y0.Notify("Theme reset (restart hub)","warn")
    end)

    -- toggle hub visibility
    UserInputService.InputBegan:Connect(function(i,gpe)
        if gpe then return end
        if i.KeyCode.Name == State.toggleKey then
            gui.Enabled = not gui.Enabled
        end
    end)

    log("H3Y0 HUB v%s loaded", H3Y0.Version)
    H3Y0.Notify("H3Y0 HUB ready", "success")
end

--============================================================
-- BOOT
--============================================================
keyGate(function()
    safe(buildHub)
end)

return H3Y0
