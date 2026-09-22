--[[
╔══════════════════════════════════════════════════════════════════╗
║  🎯 ONHUB UNIVERSAL PvP — Shooter Edition v1.0                   ║
║  Keyless | Multi-Executor | Auto-Detect Game                     ║
║  github.com/davizin713/ONhub                                     ║
╚══════════════════════════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════════════════════════════════
-- SERVIÇOS
-- ═══════════════════════════════════════════════════════════════════
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ═══════════════════════════════════════════════════════════════════
-- DETECÇÃO DE EXECUTOR
-- ═══════════════════════════════════════════════════════════════════
local ex = {
    nome = "Desconhecido",
    Drawing = (typeof(Drawing) == "table"),
    Writefile = (typeof(writefile) == "function"),
    Readfile = (typeof(readfile) == "function"),
    isfile = (typeof(isfile) == "function"),
    getrawmetatable = (typeof(getrawmetatable) == "function"),
    setclipboard = (typeof(setclipboard) == "function"),
    mouse1click = (typeof(mouse1click) == "function"),
}
pcall(function()
    if identifyexecutor then ex.nome = identifyexecutor() end
end)

-- ═══════════════════════════════════════════════════════════════════
-- DETECÇÃO DE JOGO
-- ═══════════════════════════════════════════════════════════════════
local jogo = {
    nome = "Desconhecido",
    placeId = game.PlaceId,
    temTimes = false,
}

local PLACE_IDS = {
    [286090429]      = "Arsenal",
    [292439477]      = "Phantom Forces",
    [3101667897]     = "Counter Blox",
    [5938036553]     = "Frontlines",
    [3233893879]     = "Bad Business",
    [2119089102]     = "Aimblox",
    [73415949070619] = "Rivals",
}

if PLACE_IDS[game.PlaceId] then
    jogo.nome = PLACE_IDS[game.PlaceId]
else
    pcall(function()
        local nome = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
        if nome then jogo.nome = nome end
    end)
end

for _, p in ipairs(Players:GetPlayers()) do
    if p.Team then jogo.temTimes = true; break end
end

-- ═══════════════════════════════════════════════════════════════════
-- ESTADO GLOBAL
-- ═══════════════════════════════════════════════════════════════════
local S = {
    Aimbot = false, IgnoreTeam = true,
    SilentAim = false,
    Predicao = true, PredicaoFator = 0.15,
    FOV = 250, Smooth = 0.2,
    Hitbox = "Auto", AlvoPrioridade = "Distancia",
    MaxDist = 800,
    AutoShoot = false, TriggerBot = false, TriggerFOV = 30,
    AutoReload = false, NoRecoil = true, NoSpread = false,
    ESP = false, ESPBox = true, ESPNome = true,
    ESPDist = true, ESPHP = true, ESPArma = true,
    ESPWall = false, ESPTime = true,
    Fly = false, FlySpeed = 50,
    Speed = false, SpeedValue = 30,
    Noclip = false, InfJump = false,
    Fullbright = false, FOVCircle = true,
    AntiAFK = true, SafeMode = true,
}

-- ═══════════════════════════════════════════════════════════════════
-- UTIL
-- ═══════════════════════════════════════════════════════════════════
local U = {}

function U.char() return LocalPlayer.Character end
function U.hrp()
    local c = U.char()
    return c and c:FindFirstChild("HumanoidRootPart")
end
function U.hum()
    local c = U.char()
    return c and c:FindFirstChildOfClass("Humanoid")
end
function U.isAlive(model)
    if not model then return false end
    local h = model:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end
function U.mesmoTime(p)
    if not jogo.temTimes then return false end
    if not LocalPlayer.Team or not p.Team then return false end
    return LocalPlayer.Team == p.Team
end
function U.temLinhaVisao(part)
    if not part then return false end
    local origin = Camera.CFrame.Position
    local dir = (part.Position - origin)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {LocalPlayer.Character}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            table.insert(ignore, p.Character)
        end
    end
    params.FilterDescendantsInstances = ignore
    local hit = workspace:Raycast(origin, dir, params)
    return hit == nil
end
function U.getHitbox(char, modo)
    if not char then return nil end
    if modo == "Head" then
        return char:FindFirstChild("Head")
    elseif modo == "Torso" then
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    elseif modo == "Auto" then
        return char:FindFirstChild("Head")
            or char:FindFirstChild("UpperTorso")
            or char:FindFirstChild("Torso")
            or char:FindFirstChild("HumanoidRootPart")
    else
        local melhor, melhorD
        local centro = Camera.ViewportSize / 2
        for _, p in ipairs(char:GetChildren()) do
            if p:IsA("BasePart") then
                local sp, on = Camera:WorldToViewportPoint(p.Position)
                if on then
                    local d = (Vector2.new(sp.X, sp.Y) - centro).Magnitude
                    if not melhorD or d < melhorD then melhor, melhorD = p, d end
                end
            end
        end
        return melhor
    end
end
function U.preverPosicao(part)
    if not part or not S.Predicao then return part.Position end
    local vel = part.AssemblyLinearVelocity or Vector3.zero
    return part.Position + vel * S.PredicaoFator
end

-- ═══════════════════════════════════════════════════════════════════
-- BUSCAR ALVO
-- ═══════════════════════════════════════════════════════════════════
local function isElegivel(p)
    if p == LocalPlayer then return false end
    if S.IgnoreTeam and U.mesmoTime(p) then return false end
    if not U.isAlive(p.Character) then return false end
    return true
end

local function buscarAlvo(fov)
    fov = fov or S.FOV
    local melhor, melhorScore = nil, math.huge
    local centro = Camera.ViewportSize / 2
    local camPos = Camera.CFrame.Position

    for _, p in ipairs(Players:GetPlayers()) do
        if isElegivel(p) then
            local char = p.Character
            local part = U.getHitbox(char, S.Hitbox)
            if part then
                local dist = (part.Position - camPos).Magnitude
                if dist <= S.MaxDist then
                    local pos = U.preverPosicao(part)
                    local sp, on = Camera:WorldToViewportPoint(pos)
                    if on then
                        local d2 = (Vector2.new(sp.X, sp.Y) - centro).Magnitude
                        if d2 <= fov then
                            local score = d2
                            if S.AlvoPrioridade == "HP" then
                                local hum = char:FindFirstChildOfClass("Humanoid")
                                score = hum and hum.Health or 100
                            elseif S.AlvoPrioridade == "Distancia" then
                                score = dist
                            end
                            if score < melhorScore then
                                if not S.ESPWall or U.temLinhaVisao(part) then
                                    melhor = { player = p, part = part, world = pos, dist = dist }
                                    melhorScore = score
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return melhor
end

-- ═══════════════════════════════════════════════════════════════════
-- SILENT AIM
-- ═══════════════════════════════════════════════════════════════════
local alvoSilent = nil

if ex.getrawmetatable then
    pcall(function()
        local mt = getrawmetatable(game)
        local backup = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local metodo = getnamecallmethod()
            if S.SilentAim and alvoSilent then
                if metodo == "FindPartOnRay"
                   or metodo == "FindPartOnRayWithIgnoreList"
                   or metodo == "FindPartOnRayWithWhitelist"
                   or metodo == "Raycast" then
                    local args = {...}
                    if metodo == "Raycast" then
                        if typeof(args[1]) == "CFrame" then
                            args[1] = CFrame.new(args[1].Position, alvoSilent.world)
                        end
                    else
                        if #args >= 2 and typeof(args[2]) == "Ray" then
                            local ray = args[2]
                            args[2] = Ray.new(ray.Origin, (alvoSilent.world - ray.Origin))
                        end
                    end
                    return backup(self, unpack(args))
                end
            end
            return backup(self, ...)
        end)
        setreadonly(mt, true)
    end)
end

-- ═══════════════════════════════════════════════════════════════════
-- WELCOME SCREEN
-- ═══════════════════════════════════════════════════════════════════
local function welcome()
    local gui = Instance.new("ScreenGui")
    gui.Name = "ONhubWelcome"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 1001
    pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
    bg.BorderSizePixel = 0
    bg.Parent = gui

    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, 400, 0, 320)
    box.Position = UDim2.new(0.5, -200, 0.5, -160)
    box.BackgroundTransparency = 1
    box.Parent = bg

    local av = Instance.new("ImageLabel")
    av.Size = UDim2.new(0, 90, 0, 90)
    av.Position = UDim2.new(0.5, -45, 0, 20)
    av.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    av.BorderSizePixel = 0
    av.Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150"
    av.Parent = box
    Instance.new("UICorner", av).CornerRadius = UDim.new(1, 0)

    local nome = Instance.new("TextLabel")
    nome.Size = UDim2.new(1, 0, 0, 26)
    nome.Position = UDim2.new(0, 0, 0, 120)
    nome.BackgroundTransparency = 1
    nome.Text = "@" .. LocalPlayer.Name
    nome.TextColor3 = Color3.fromRGB(0, 200, 255)
    nome.Font = Enum.Font.GothamBold
    nome.TextSize = 18
    nome.Parent = box

    local titulo = Instance.new("TextLabel")
    titulo.Size = UDim2.new(1, 0, 0, 40)
    titulo.Position = UDim2.new(0, 0, 0, 150)
    titulo.BackgroundTransparency = 1
    titulo.Text = "🎯 ONHUB UNIVERSAL"
    titulo.TextColor3 = Color3.fromRGB(255, 255, 255)
    titulo.Font = Enum.Font.GothamBlack
    titulo.TextSize = 26
    titulo.Parent = box

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, 0, 0, 20)
    sub.Position = UDim2.new(0, 0, 0, 195)
    sub.BackgroundTransparency = 1
    sub.Text = "🎮 " .. jogo.nome
    sub.TextColor3 = Color3.fromRGB(150, 150, 170)
    sub.Font = Enum.Font.GothamMedium
    sub.TextSize = 13
    sub.Parent = box

    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(0, 260, 0, 6)
    barBg.Position = UDim2.new(0.5, -130, 0, 230)
    barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    barBg.BorderSizePixel = 0
    barBg.Parent = box
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)

    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    barFill.BorderSizePixel = 0
    barFill.Parent = barBg
    Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, 0, 0, 20)
    status.Position = UDim2.new(0, 0, 0, 245)
    status.BackgroundTransparency = 1
    status.Text = "Iniciando..."
    status.TextColor3 = Color3.fromRGB(120, 120, 140)
    status.Font = Enum.Font.Gotham
    status.TextSize = 11
    status.Parent = box

    local etapas = {
        {0.0, "Verificando executor..."},
        {0.25, "Detectando jogo..."},
        {0.5, "Carregando UI..."},
        {0.75, "Inicializando funções..."},
        {1.0, "Pronto!"},
    }

    for _, e in ipairs(etapas) do
        task.wait(0.25)
        status.Text = e[2]
        TweenService:Create(barFill, TweenInfo.new(0.2), {
            Size = UDim2.new(e[1], 0, 1, 0)
        }):Play()
    end

    task.wait(0.4)
    local t = TweenService:Create(bg, TweenInfo.new(0.4), {BackgroundTransparency = 1})
    t:Play()
    t.Completed:Wait()
    gui:Destroy()
end

-- ═══════════════════════════════════════════════════════════════════
-- HUB UI
-- ═══════════════════════════════════════════════════════════════════
local function criarHub()
    local C = {
        bg = Color3.fromRGB(12, 12, 18),
        bgCard = Color3.fromRGB(20, 20, 28),
        bgBtn = Color3.fromRGB(30, 30, 40),
        bgBtnOn = Color3.fromRGB(0, 170, 120),
        accent = Color3.fromRGB(0, 200, 255),
        accent2 = Color3.fromRGB(180, 80, 255),
        text = Color3.fromRGB(230, 230, 240),
        textDim = Color3.fromRGB(140, 140, 160),
        danger = Color3.fromRGB(255, 70, 90),
        warn = Color3.fromRGB(255, 180, 50),
    }

    local gui = Instance.new("ScreenGui")
    gui.Name = "ONhubUniversal"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999
    pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local painel = Instance.new("Frame")
    painel.Name = "Painel"
    painel.Size = UDim2.new(0, 540, 0, 420)
    painel.Position = UDim2.new(0.5, -270, 0.5, -210)
    painel.BackgroundColor3 = C.bg
    painel.BorderSizePixel = 0
    painel.Visible = false
    painel.Active = true
    painel.Draggable = true
    painel.Parent = gui
    Instance.new("UICorner", painel).CornerRadius = UDim.new(0, 12)
    local strokeP = Instance.new("UIStroke", painel)
    strokeP.Color = C.accent
    strokeP.Thickness = 1.5

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 48)
    header.BackgroundColor3 = C.bgCard
    header.BorderSizePixel = 0
    header.Parent = painel
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)
    local coverH = Instance.new("Frame")
    coverH.Size = UDim2.new(1, 0, 0, 12)
    coverH.Position = UDim2.new(0, 0, 1, -12)
    coverH.BackgroundColor3 = C.bgCard
    coverH.BorderSizePixel = 0
    coverH.Parent = header

    local titulo = Instance.new("TextLabel")
    titulo.Size = UDim2.new(1, -130, 1, 0)
    titulo.Position = UDim2.new(0, 16, 0, 0)
    titulo.BackgroundTransparency = 1
    titulo.Text = "🎯 ONHUB — " .. jogo.nome
    titulo.TextColor3 = C.accent
    titulo.Font = Enum.Font.GothamBold
    titulo.TextSize = 14
    titulo.TextXAlignment = Enum.TextXAlignment.Left
    titulo.Parent = header

    local btnClose = Instance.new("TextButton")
    btnClose.Size = UDim2.new(0, 28, 0, 28)
    btnClose.Position = UDim2.new(1, -40, 0.5, -14)
    btnClose.BackgroundColor3 = C.danger
    btnClose.Text = "×"
    btnClose.TextColor3 = Color3.new(1, 1, 1)
    btnClose.TextSize = 20
    btnClose.Font = Enum.Font.GothamBold
    btnClose.BorderSizePixel = 0
    btnClose.Parent = header
    Instance.new("UICorner", btnClose).CornerRadius = UDim.new(0, 8)

    local tabsBar = Instance.new("Frame")
    tabsBar.Size = UDim2.new(1, -24, 0, 36)
    tabsBar.Position = UDim2.new(0, 12, 0, 56)
    tabsBar.BackgroundColor3 = C.bgCard
    tabsBar.BorderSizePixel = 0
    tabsBar.Parent = painel
    Instance.new("UICorner", tabsBar).CornerRadius = UDim.new(0, 8)

    local tabL = Instance.new("UIListLayout", tabsBar)
    tabL.FillDirection = Enum.FillDirection.Horizontal
    tabL.Padding = UDim.new(0, 4)
    tabL.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabL.VerticalAlignment = Enum.VerticalAlignment.Center

    local conteudo = Instance.new("Frame")
    conteudo.Size = UDim2.new(1, -24, 1, -108)
    conteudo.Position = UDim2.new(0, 12, 0, 100)
    conteudo.BackgroundTransparency = 1
    conteudo.Parent = painel

    local abas, btns = {}, {}

    local function aba(nome, icone, w)
        w = w or 78
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, w, 0, 26)
        btn.BackgroundColor3 = C.bgBtn
        btn.Text = icone .. " " .. nome
        btn.TextColor3 = C.textDim
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 10
        btn.BorderSizePixel = 0
        btn.Parent = tabsBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 4
        scroll.ScrollBarImageColor3 = C.accent
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.Visible = false
        scroll.Parent = conteudo

        local layout = Instance.new("UIListLayout", scroll)
        layout.Padding = UDim.new(0, 6)
        layout.SortOrder = Enum.SortOrder.LayoutOrder

        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
        end)

        abas[nome] = scroll
        btns[nome] = btn

        btn.MouseButton1Click:Connect(function()
            for _, s in pairs(abas) do s.Visible = false end
            for _, b in pairs(btns) do
                b.BackgroundColor3 = C.bgBtn
                b.TextColor3 = C.textDim
            end
            scroll.Visible = true
            btn.BackgroundColor3 = C.accent
            btn.TextColor3 = Color3.new(0, 0, 0)
        end)
        return scroll
    end

    local function sec(parent, ord, txt)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -8, 0, 22)
        l.BackgroundTransparency = 1
        l.Text = "▸ " .. txt
        l.TextColor3 = C.accent
        l.Font = Enum.Font.GothamBold
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.LayoutOrder = ord
        l.Parent = parent
    end

    local function toggle(parent, ord, label, est, cb, corOn)
        corOn = corOn or C.bgBtnOn
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -8, 0, 34)
        b.BackgroundColor3 = est and corOn or C.bgBtn
        b.Text = string.format("  %s   %s", label, est and "●" or "○")
        b.TextColor3 = est and Color3.new(1,1,1) or C.textDim
        b.Font = Enum.Font.GothamMedium
        b.TextSize = 12
        b.BorderSizePixel = 0
        b.LayoutOrder = ord
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.Parent = parent
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
        local st = Instance.new("UIStroke", b)
        st.Color = Color3.fromRGB(50, 50, 70)
        st.Thickness = 1

        local atual = est
        local function refresh()
            b.BackgroundColor3 = atual and corOn or C.bgBtn
            b.TextColor3 = atual and Color3.new(1,1,1) or C.textDim
            b.Text = string.format("  %s   %s", label, atual and "●" or "○")
        end

        b.MouseButton1Click:Connect(function()
            atual = not atual
            refresh()
            if cb then cb(atual) end
        end)
        return b
    end

    local function slider(parent, ord, label, min, max, val, cb, suf)
        suf = suf or ""
       jogo.nome = PLACE_IDS[game.PlaceId]
else
    pcall(function()
        local nome = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
        if nome then jogo.nome = nome end
    end)
end

for _, p in ipairs(Players:GetPlayers()) do
    if p.Team then jogo.temTimes = true; break end
end

-- ═══════════════════════════════════════════════════════════════════
-- ESTADO GLOBAL
-- ═══════════════════════════════════════════════════════════════════
local S = {
    Aimbot = false, IgnoreTeam = true,
    SilentAim = false,
    Predicao = true, PredicaoFator = 0.15,
    FOV = 250, Smooth = 0.2,
    Hitbox = "Auto", AlvoPrioridade = "Distancia",
    MaxDist = 800,
    AutoShoot = false, TriggerBot = false, TriggerFOV = 30,
    AutoReload = false, NoRecoil = true, NoSpread = false,
    ESP = false, ESPBox = true, ESPNome = true,
    ESPDist = true, ESPHP = true, ESPArma = true,
    ESPWall = false, ESPTime = true,
    Fly = false, FlySpeed = 50,
    Speed = false, SpeedValue = 30,
    Noclip = false, InfJump = false,
    Fullbright = false, FOVCircle = true,
    AntiAFK = true, SafeMode = true,
}

-- ═══════════════════════════════════════════════════════════════════
-- UTIL
-- ═══════════════════════════════════════════════════════════════════
local U = {}

function U.char() return LocalPlayer.Character end
function U.hrp()
    local c = U.char()
    return c and c:FindFirstChild("HumanoidRootPart")
end
function U.hum()
    local c = U.char()
    return c and c:FindFirstChildOfClass("Humanoid")
end
function U.isAlive(model)
    if not model then return false end
    local h = model:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end
function U.mesmoTime(p)
    if not jogo.temTimes then return false end
    if not LocalPlayer.Team or not p.Team then return false end
    return LocalPlayer.Team == p.Team
end
function U.temLinhaVisao(part)
    if not part then return false end
    local origin = Camera.CFrame.Position
    local dir = (part.Position - origin)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {LocalPlayer.Character}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            table.insert(ignore, p.Character)
        end
    end
    params.FilterDescendantsInstances = ignore
    local hit = workspace:Raycast(origin, dir, params)
    return hit == nil
end
function U.getHitbox(char, modo)
    if not char then return nil end
    if modo == "Head" then
        return char:FindFirstChild("Head")
    elseif modo == "Torso" then
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    elseif modo == "Auto" then
        return char:FindFirstChild("Head")
            or char:FindFirstChild("UpperTorso")
            or char:FindFirstChild("Torso")
            or char:FindFirstChild("HumanoidRootPart")
    else
        local melhor, melhorD
        local centro = Camera.ViewportSize / 2
        for _, p in ipairs(char:GetChildren()) do
            if p:IsA("BasePart") then
                local sp, on = Camera:WorldToViewportPoint(p.Position)
                if on then
                    local d = (Vector2.new(sp.X, sp.Y) - centro).Magnitude
                    if not melhorD or d < melhorD then melhor, melhorD = p, d end
                end
            end
        end
        return melhor
    end
end
function U.preverPosicao(part)
    if not part or not S.Predicao then return part.Position end
    local vel = part.AssemblyLinearVelocity or Vector3.zero
    return part.Position + vel * S.PredicaoFator
end

-- ═══════════════════════════════════════════════════════════════════
-- BUSCAR ALVO
-- ═══════════════════════════════════════════════════════════════════
local function isElegivel(p)
    if p == LocalPlayer then return false end
    if S.IgnoreTeam and U.mesmoTime(p) then return false end
    if not U.isAlive(p.Character) then return false end
    return true
end

local function buscarAlvo(fov)
    fov = fov or S.FOV
    local melhor, melhorScore = nil, math.huge
    local centro = Camera.ViewportSize / 2
    local camPos = Camera.CFrame.Position

    for _, p in ipairs(Players:GetPlayers()) do
        if isElegivel(p) then
            local char = p.Character
            local part = U.getHitbox(char, S.Hitbox)
            if part then
                local dist = (part.Position - camPos).Magnitude
                if dist <= S.MaxDist then
                    local pos = U.preverPosicao(part)
                    local sp, on = Camera:WorldToViewportPoint(pos)
                    if on then
                        local d2 = (Vector2.new(sp.X, sp.Y) - centro).Magnitude
                        if d2 <= fov then
                            local score = d2
                            if S.AlvoPrioridade == "HP" then
                                local hum = char:FindFirstChildOfClass("Humanoid")
                                score = hum and hum.Health or 100
                            elseif S.AlvoPrioridade == "Distancia" then
                                score = dist
                            end
                            if score < melhorScore then
                                if not S.ESPWall or U.temLinhaVisao(part) then
                                    melhor = { player = p, part = part, world = pos, dist = dist }
                                    melhorScore = score
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return melhor
end

-- ═══════════════════════════════════════════════════════════════════
-- SILENT AIM
-- ═══════════════════════════════════════════════════════════════════
local alvoSilent = nil

if ex.getrawmetatable then
    pcall(function()
        local mt = getrawmetatable(game)
        local backup = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local metodo = getnamecallmethod()
            if S.SilentAim and alvoSilent then
                if metodo == "FindPartOnRay"
                   or metodo == "FindPartOnRayWithIgnoreList"
                   or metodo == "FindPartOnRayWithWhitelist"
                   or metodo == "Raycast" then
                    local args = {...}
                    if metodo == "Raycast" then
                        if typeof(args[1]) == "CFrame" then
                            args[1] = CFrame.new(args[1].Position, alvoSilent.world)
                        end
                    else
                        if #args >= 2 and typeof(args[2]) == "Ray" then
                            local ray = args[2]
                            args[2] = Ray.new(ray.Origin, (alvoSilent.world - ray.Origin))
                        end
                    end
                    return backup(self, unpack(args))
                end
            end
            return backup(self, ...)
        end)
        setreadonly(mt, true)
    end)
end

-- ═══════════════════════════════════════════════════════════════════
-- WELCOME SCREEN
-- ═══════════════════════════════════════════════════════════════════
local function welcome()
    local gui = Instance.new("ScreenGui")
    gui.Name = "ONhubWelcome"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 1001
    pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
    bg.BorderSizePixel = 0
    bg.Parent = gui

    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, 400, 0, 320)
    box.Position = UDim2.new(0.5, -200, 0.5, -160)
    box.BackgroundTransparency = 1
    box.Parent = bg

    local av = Instance.new("ImageLabel")
    av.Size = UDim2.new(0, 90, 0, 90)
    av.Position = UDim2.new(0.5, -45, 0, 20)
    av.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    av.BorderSizePixel = 0
    av.Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150"
    av.Parent = box
    Instance.new("UICorner", av).CornerRadius = UDim.new(1, 0)

    local nome = Instance.new("TextLabel")
    nome.Size = UDim2.new(1, 0, 0, 26)
    nome.Position = UDim2.new(0, 0, 0, 120)
    nome.BackgroundTransparency = 1
    nome.Text = "@" .. LocalPlayer.Name
    nome.TextColor3 = Color3.fromRGB(0, 200, 255)
    nome.Font = Enum.Font.GothamBold
    nome.TextSize = 18
    nome.Parent = box

    local titulo = Instance.new("TextLabel")
    titulo.Size = UDim2.new(1, 0, 0, 40)
    titulo.Position = UDim2.new(0, 0, 0, 150)
    titulo.BackgroundTransparency = 1
    titulo.Text = "🎯 ONHUB UNIVERSAL"
    titulo.TextColor3 = Color3.fromRGB(255, 255, 255)
    titulo.Font = Enum.Font.GothamBlack
    titulo.TextSize = 26
    titulo.Parent = box

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, 0, 0, 20)
    sub.Position = UDim2.new(0, 0, 0, 195)
    sub.BackgroundTransparency = 1
    sub.Text = "🎮 " .. jogo.nome
    sub.TextColor3 = Color3.fromRGB(150, 150, 170)
    sub.Font = Enum.Font.GothamMedium
    sub.TextSize = 13
    sub.Parent = box

    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(0, 260, 0, 6)
    barBg.Position = UDim2.new(0.5, -130, 0, 230)
    barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    barBg.BorderSizePixel = 0
    barBg.Parent = box
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)

    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    barFill.BorderSizePixel = 0
    barFill.Parent = barBg
    Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, 0, 0, 20)
    status.Position = UDim2.new(0, 0, 0, 245)
    status.BackgroundTransparency = 1
    status.Text = "Iniciando..."
    status.TextColor3 = Color3.fromRGB(120, 120, 140)
    status.Font = Enum.Font.Gotham
    status.TextSize = 11
    status.Parent = box

    local etapas = {
        {0.0, "Verificando executor..."},
        {0.25, "Detectando jogo..."},
        {0.5, "Carregando UI..."},
        {0.75, "Inicializando funções..."},
        {1.0, "Pronto!"},
    }

    for _, e in ipairs(etapas) do
        task.wait(0.25)
        status.Text = e[2]
        TweenService:Create(barFill, TweenInfo.new(0.2), {
            Size = UDim2.new(e[1], 0, 1, 0)
        }):Play()
    end

    task.wait(0.4)
    local t = TweenService:Create(bg, TweenInfo.new(0.4), {BackgroundTransparency = 1})
    t:Play()
    t.Completed:Wait()
    gui:Destroy()
end

-- ═══════════════════════════════════════════════════════════════════
-- HUB UI
-- ═══════════════════════════════════════════════════════════════════
local function criarHub()
    local C = {
        bg = Color3.fromRGB(12, 12, 18),
        bgCard = Color3.fromRGB(20, 20, 28),
        bgBtn = Color3.fromRGB(30, 30, 40),
        bgBtnOn = Color3.fromRGB(0, 170, 120),
        accent = Color3.fromRGB(0, 200, 255),
        accent2 = Color3.fromRGB(180, 80, 255),
        text = Color3.fromRGB(230, 230, 240),
        textDim = Color3.fromRGB(140, 140, 160),
        danger = Color3.fromRGB(255, 70, 90),
        warn = Color3.fromRGB(255, 180, 50),
    }

    local gui = Instance.new("ScreenGui")
    gui.Name = "ONhubUniversal"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999
    pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local painel = Instance.new("Frame")
    painel.Name = "Painel"
    painel.Size = UDim2.new(0, 540, 0, 420)
    painel.Position = UDim2.new(0.5, -270, 0.5, -210)
    painel.BackgroundColor3 = C.bg
    painel.BorderSizePixel = 0
    painel.Visible = false
    painel.Active = true
    painel.Draggable = true
    painel.Parent = gui
    Instance.new("UICorner", painel).CornerRadius = UDim.new(0, 12)
    local strokeP = Instance.new("UIStroke", painel)
    strokeP.Color = C.accent
    strokeP.Thickness = 1.5

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 48)
    header.BackgroundColor3 = C.bgCard
    header.BorderSizePixel = 0
    header.Parent = painel
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)
    local coverH = Instance.new("Frame")
    coverH.Size = UDim2.new(1, 0, 0, 12)
    coverH.Position = UDim2.new(0, 0, 1, -12)
    coverH.BackgroundColor3 = C.bgCard
    coverH.BorderSizePixel = 0
    coverH.Parent = header

    local titulo = Instance.new("TextLabel")
    titulo.Size = UDim2.new(1, -130, 1, 0)
    titulo.Position = UDim2.new(0, 16, 0, 0)
    titulo.BackgroundTransparency = 1
    titulo.Text = "🎯 ONHUB — " .. jogo.nome
    titulo.TextColor3 = C.accent
    titulo.Font = Enum.Font.GothamBold
    titulo.TextSize = 14
    titulo.TextXAlignment = Enum.TextXAlignment.Left
    titulo.Parent = header

    local btnClose = Instance.new("TextButton")
    btnClose.Size = UDim2.new(0, 28, 0, 28)
    btnClose.Position = UDim2.new(1, -40, 0.5, -14)
    btnClose.BackgroundColor3 = C.danger
    btnClose.Text = "×"
    btnClose.TextColor3 = Color3.new(1, 1, 1)
    btnClose.TextSize = 20
    btnClose.Font = Enum.Font.GothamBold
    btnClose.BorderSizePixel = 0
    btnClose.Parent = header
    Instance.new("UICorner", btnClose).CornerRadius = UDim.new(0, 8)

    local tabsBar = Instance.new("Frame")
    tabsBar.Size = UDim2.new(1, -24, 0, 36)
    tabsBar.Position = UDim2.new(0, 12, 0, 56)
    tabsBar.BackgroundColor3 = C.bgCard
    tabsBar.BorderSizePixel = 0
    tabsBar.Parent = painel
    Instance.new("UICorner", tabsBar).CornerRadius = UDim.new(0, 8)

    local tabL = Instance.new("UIListLayout", tabsBar)
    tabL.FillDirection = Enum.FillDirection.Horizontal
    tabL.Padding = UDim.new(0, 4)
    tabL.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabL.VerticalAlignment = Enum.VerticalAlignment.Center

    local conteudo = Instance.new("Frame")
    conteudo.Size = UDim2.new(1, -24, 1, -108)
    conteudo.Position = UDim2.new(0, 12, 0, 100)
    conteudo.BackgroundTransparency = 1
    conteudo.Parent = painel

    local abas, btns = {}, {}

    local function aba(nome, icone, w)
        w = w or 78
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, w, 0, 26)
        btn.BackgroundColor3 = C.bgBtn
        btn.Text = icone .. " " .. nome
        btn.TextColor3 = C.textDim
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 10
        btn.BorderSizePixel = 0
        btn.Parent = tabsBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 4
        scroll.ScrollBarImageColor3 = C.accent
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.Visible = false
        scroll.Parent = conteudo

        local layout = Instance.new("UIListLayout", scroll)
        layout.Padding = UDim.new(0, 6)
        layout.SortOrder = Enum.SortOrder.LayoutOrder

        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
        end)

        abas[nome] = scroll
        btns[nome] = btn

        btn.MouseButton1Click:Connect(function()
            for _, s in pairs(abas) do s.Visible = false end
            for _, b in pairs(btns) do
                b.BackgroundColor3 = C.bgBtn
                b.TextColor3 = C.textDim
            end
            scroll.Visible = true
            btn.BackgroundColor3 = C.accent
            btn.TextColor3 = Color3.new(0, 0, 0)
        end)
        return scroll
    end

    local function sec(parent, ord, txt)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -8, 0, 22)
        l.BackgroundTransparency = 1
        l.Text = "▸ " .. txt
        l.TextColor3 = C.accent
        l.Font = Enum.Font.GothamBold
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.LayoutOrder = ord
        l.Parent = parent
    end

    local function toggle(parent, ord, label, est, cb, corOn)
        corOn = corOn or C.bgBtnOn
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -8, 0, 34)
        b.BackgroundColor3 = est and corOn or C.bgBtn
        b.Text = string.format("  %s   %s", label, est and "●" or "○")
        b.TextColor3 = est and Color3.new(1,1,1) or C.textDim
        b.Font = Enum.Font.GothamMedium
        b.TextSize = 12
        b.BorderSizePixel = 0
        b.LayoutOrder = ord
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.Parent = parent
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
        local st = Instance.new("UIStroke", b)
        st.Color = Color3.fromRGB(50, 50, 70)
        st.Thickness = 1

        local atual = est
        local function refresh()
            b.BackgroundColor3 = atual and corOn or C.bgBtn
            b.TextColor3 = atual and Color3.new(1,1,1) or C.textDim
            b.Text = string.format("  %s   %s", label, atual and "●" or "○")
        end

        b.MouseButton1Click:Connect(function()
            atual = not atual
            refresh()
            if cb then cb(atual) end
        end)
        return b
    end

    local function slider(parent, ord, label, min, max, val, cb, suf)
        suf = suf or ""
   
