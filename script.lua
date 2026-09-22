--[[
╔══════════════════════════════════════════════════════════════════╗
║  🎯 ONHUB UNIVERSAL PvP — Shooter Edition v1.1 (FIX)            ║
║  Keyless | Multi-Executor | Auto-Detect Game                    ║
╚══════════════════════════════════════════════════════════════════╝
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui       = game:GetService("StarterGui")
local TweenService     = game:GetService("TweenService")
local LocalPlayer      = Players.LocalPlayer
local Camera           = workspace.CurrentCamera

-- ═══ DETECÇÃO DE EXECUTOR ═══
local ex = {
    nome = "Desconhecido",
    Drawing = (typeof(Drawing) == "table"),
    Writefile = (typeof(writefile) == "function"),
    Readfile = (typeof(readfile) == "function"),
    isfile = (typeof(isfile) == "function"),
    getrawmetatable = (typeof(getrawmetatable) == "function"),
    mouse1click = (typeof(mouse1click) == "function"),
}
pcall(function()
    if identifyexecutor then ex.nome = identifyexecutor() end
end)

-- ═══ DETECÇÃO DE JOGO ═══
local PLACE_IDS = {
    [286090429]      = "Arsenal",
    [292439477]      = "Phantom Forces",
    [3101667897]     = "Counter Blox",
    [5938036553]     = "Frontlines",
    [3233893879]     = "Bad Business",
    [2119089102]     = "Aimblox",
    [73415949070619] = "Rivals",
}

local jogo = {
    nome = PLACE_IDS[game.PlaceId] or "Desconhecido",
    placeId = game.PlaceId,
    temTimes = false,
}

if jogo.nome == "Desconhecido" then
    pcall(function()
        local n = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
        if n then jogo.nome = n end
    end)
end

for _, p in ipairs(Players:GetPlayers()) do
    if p.Team then jogo.temTimes = true; break end
end

-- ═══ ESTADO GLOBAL ═══
local S = {
    Aimbot = false, IgnoreTeam = true,
    SilentAim = false,
    Predicao = true, PredicaoFator = 0.15,
    FOV = 250, Smooth = 0.2,
    Hitbox = "Auto", AlvoPrioridade = "Distancia",
    MaxDist = 800,
    AutoShoot = false, TriggerBot = false, TriggerFOV = 30,
    ESP = false, ESPBox = true, ESPNome = true,
    ESPDist = true, ESPHP = true, ESPArma = true,
    ESPWall = false, ESPTime = true,
    Fly = false, FlySpeed = 50,
    Speed = false, SpeedValue = 30,
    Noclip = false, InfJump = false,
    Fullbright = false, FOVCircle = true,
    AntiAFK = true,
}

-- ═══ UTIL ═══
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

-- ═══ BUSCAR ALVO ═══
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
            local part = U.getHitbox(p.Character, S.Hitbox)
            if part then
                local dist = (part.Position - camPos).Magnitude
                if dist <= S.MaxDist then
                    local pos = U.preverPosicao(part)
                    local sp, on = Camera:WorldToViewportPoint(pos)
                    if on then
                        local d2 = (Vector2.new(sp.X, sp.Y) - centro).Magnitude
                        if d2 <= fov then
                            local score = S.AlvoPrioridade == "HP"
                                and (p.Character:FindFirstChildOfClass("Humanoid") and p.Character.Humanoid.Health or 100)
                                or (S.AlvoPrioridade == "Distancia" and dist or d2)
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

-- ═══ SILENT AIM HOOK ═══
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
                    if metodo == "Raycast" and typeof(args[1]) == "CFrame" then
                        args[1] = CFrame.new(args[1].Position, alvoSilent.world)
                    elseif #args >= 2 and typeof(args[2]) == "Ray" then
                        args[2] = Ray.new(args[2].Origin, (alvoSilent.world - args[2].Origin))
                    end
                    return backup(self, unpack(args))
                end
            end
            return backup(self, ...)
        end)
        setreadonly(mt, true)
    end)
end

-- ═══ HUB UI ═══
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
    }

    local gui = Instance.new("ScreenGui")
    gui.Name = "ONhubUniversal"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999
    pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    -- Painel
    local painel = Instance.new("Frame")
    painel.Name = "Painel"
    painel.Size = UDim2.new(0, 520, 0, 400)
    painel.Position = UDim2.new(0.5, -260, 0.5, -200)
    painel.BackgroundColor3 = C.bg
    painel.BorderSizePixel = 0
    painel.Visible = false
    painel.Active = true
    painel.Draggable = true
    painel.Parent = gui
    Instance.new("UICorner", painel).CornerRadius = UDim.new(0, 12)
    local sp = Instance.new("UIStroke", painel)
    sp.Color = C.accent
    sp.Thickness = 1.5

    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 44)
    header.BackgroundColor3 = C.bgCard
    header.BorderSizePixel = 0
    header.Parent = painel
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

    local titulo = Instance.new("TextLabel")
    titulo.Size = UDim2.new(1, -60, 1, 0)
    titulo.Position = UDim2.new(0, 16, 0, 0)
    titulo.BackgroundTransparency = 1
    titulo.Text = "🎯 ONHUB — " .. jogo.nome
    titulo.TextColor3 = C.accent
    titulo.Font = Enum.Font.GothamBold
    titulo.TextSize = 15
    titulo.TextXAlignment = Enum.TextXAlignment.Left
    titulo.Parent = header

    local fechar = Instance.new("TextButton")
    fechar.Size = UDim2.new(0, 28, 0, 28)
    fechar.Position = UDim2.new(1, -38, 0.5, -14)
    fechar.BackgroundColor3 = C.danger
    fechar.Text = "×"
    fechar.TextColor3 = Color3.new(1,1,1)
    fechar.TextSize = 20
    fechar.Font = Enum.Font.GothamBold
    fechar.BorderSizePixel = 0
    fechar.Parent = header
    Instance.new("UICorner", fechar).CornerRadius = UDim.new(0, 8)

    -- Tabs
    local tabs = Instance.new("Frame")
    tabs.Size = UDim2.new(1, -20, 0, 32)
    tabs.Position = UDim2.new(0, 10, 0, 52)
    tabs.BackgroundColor3 = C.bgCard
    tabs.BorderSizePixel = 0
    tabs.Parent = painel
    Instance.new("UICorner", tabs).CornerRadius = UDim.new(0, 8)

    local tl = Instance.new("UIListLayout", tabs)
    tl.FillDirection = Enum.FillDirection.Horizontal
    tl.Padding = UDim.new(0, 4)
    tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tl.VerticalAlignment = Enum.VerticalAlignment.Center

    local conteudo = Instance.new("Frame")
    conteudo.Size = UDim2.new(1, -20, 1, -96)
    conteudo.Position = UDim2.new(0, 10, 0, 90)
    conteudo.BackgroundTransparency = 1
    conteudo.Parent = painel

    local abas, btns = {}, {}

    local function criarAba(nome, icone)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 82, 0, 24)
        btn.BackgroundColor3 = C.bgBtn
        btn.Text = icone .. " " .. nome
        btn.TextColor3 = C.textDim
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 10
        btn.BorderSizePixel = 0
        btn.Parent = tabs
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
            btn.TextColor3 = Color3.new(0,0,0)
        end)
        return scroll
    end

    local function criarSecao(parent, txt)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -8, 0, 20)
        l.BackgroundTransparency = 1
        l.Text = "▸ " .. txt
        l.TextColor3 = C.accent
        l.Font = Enum.Font.GothamBold
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = parent
    end

    local function criarToggle(parent, label, inicial, cb)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -8, 0, 32)
        b.BackgroundColor3 = inicial and C.bgBtnOn or C.bgBtn
        b.Text = string.format("  %s   %s", label, inicial and "●" or "○")
        b.TextColor3 = inicial and Color3.new(1,1,1) or C.textDim
        b.Font = Enum.Font.GothamMedium
        b.TextSize = 12
        b.BorderSizePixel = 0
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.Parent = parent
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)

        local estado = inicial
        b.MouseButton1Click:Connect(function()
            estado = not estado
            b.BackgroundColor3 = estado and C.bgBtnOn or C.bgBtn
            b.TextColor3 = estado and Color3.new(1,1,1) or C.textDim
            b.Text = string.format("  %s   %s", label, estado and "●" or "○")
            if cb then cb(estado) end
        end)
        return b
    end

    local function criarSlider(parent, label, min, max, val, cb, suf)
        suf = suf or ""
        local h = Instance.new("Frame")
        h.Size = UDim2.new(1, -8, 0, 48)
        h.BackgroundColor3 = C.bgCard
        h.BorderSizePixel = 0
        h.Parent = parent
        Instance.new("UICorner", h).CornerRadius = UDim.new(0, 8)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -16, 0, 18)
        lbl.Position = UDim2.new(0, 10, 0, 4)
        lbl.BackgroundTransparency = 1
        lbl.Text = string.format("%s   %s%s", label, val, suf)
        lbl.TextColor3 = C.text
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = h

        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, -20, 0, 8)
        track.Position = UDim2.new(0, 10, 1, -16)
        track.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        track.BorderSizePixel = 0
        track.Parent = h
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

        local rel = (val - min) / (max - min)
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(rel, 0, 1, 0)
        fill.BackgroundColor3 = C.accent
        fill.BorderSizePixel = 0
        fill.Parent = track
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        local dragging = false
        local function setX(x)
            local r = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local v = min + (max - min) * r
            v = math.floor(v * 10) / 10
            fill.Size = UDim2.new(r, 0, 1, 0)
            lbl.Text = string.format("%s   %s%s", label, v, suf)
            if cb then cb(v) end
        end

        track.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch
               or i.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true; setX(i.Position.X)
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.Touch
               or i.UserInputType == Enum.UserInputType.MouseMovement) then
                setX(i.Position.X)
            end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch
               or i.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
    end

    -- Aba Aimbot
    local aA = criarAba("Aimbot", "🎯")
    criarSecao(aA, "PRINCIPAIS")
    criarToggle(aA, "🎯 Aimbot", S.Aimbot, function(v) S.Aimbot = v end)
    criarToggle(aA, "👥 Ignorar Time", S.IgnoreTeam, function(v) S.IgnoreTeam = v end)
    criarToggle(aA, "🔥 Silent Aim", S.SilentAim, function(v) S.SilentAim = v end)
    criarToggle(aA, "🧠 Predição", S.Predicao, function(v) S.Predicao = v end)
    criarSecao(aA, "MIRA")
    criarSlider(aA, "FOV", 50, 600, S.FOV, function(v) S.FOV = v end)
    criarSlider(aA, "Suavidade", 0, 0.9, S.Smooth, function(v) S.Smooth = v end)

    -- Aba Combat
    local aC = criarAba("Combate", "⚔️")
    criarSecao(aC, "TIRO")
    criarToggle(aC, "⚡ Auto-Shoot", S.AutoShoot, function(v) S.AutoShoot = v end)
    criarToggle(aC, "🎯 Trigger Bot", S.TriggerBot, function(v) S.TriggerBot = v end)
    criarSlider(aC, "Trigger FOV", 5, 100, S.TriggerFOV, function(v) S.TriggerFOV = v end)

    -- Aba ESP
    local aE = criarAba("ESP", "👁️")
    criarSecao(aE, "GERAL")
    criarToggle(aE, "👁️ ESP", S.ESP, function(v) S.ESP = v end)
    criarToggle(aE, "📝 Nome", S.ESPNome, function(v) S.ESPNome = v end)
    criarToggle(aE, "📏 Distância", S.ESPDist, function(v) S.ESPDist = v end)
    criarToggle(aE, "❤️ Health", S.ESPHP, function(v) S.ESPHP = v end)
    criarToggle(aE, "🔫 Arma", S.ESPArma, function(v) S.ESPArma = v end)
    criarToggle(aE, "🛡️ Wall Check", S.ESPWall, function(v) S.ESPWall = v end)

    -- Aba Movimento
    local aM = criarAba("Movimento", "🚀")
    criarSecao(aM, "VELOCIDADE")
    criarToggle(aM, "⚡ Speed", S.Speed, function(v)
        S.Speed = v
        if not v then
            local h = U.hum(); if h then h.WalkSpeed = 16 end
        end
    end)
    criarSlider(aM, "Speed Value", 16, 150, S.SpeedValue, function(v)
        S.SpeedValue = v
        if S.Speed then local h = U.hum(); if h then h.WalkSpeed = v end end
    end)
    criarSecao(aM, "VOO")
    criarToggle(aM, "🕊️ Fly", S.Fly, function(v) S.Fly = v end)
    criarSlider(aM, "Fly Speed", 10, 200, S.FlySpeed, function(v) S.FlySpeed = v end)
    criarSecao(aM, "EXTRA")
    criarToggle(aM, "🚪 Noclip", S.Noclip, function(v) S.Noclip = v end)
    criarToggle(aM, "🦘 Inf Jump", S.InfJump, function(v) S.InfJump = v end)

    -- Aba Visual
    local aV = criarAba("Visual", "🎨")
    criarSecao(aV, "MUNDO")
    criarToggle(aV, "☀️ Fullbright", S.Fullbright, function(v)
        S.Fullbright = v
        pcall(function()
            if v then
                game.Lighting.Ambient = Color3.fromRGB(255,255,255)
                game.Lighting.Brightness = 2
            end
        end)
    end)
    criarToggle(aV, "⭕ FOV Circle", S.FOVCircle, function(v) S.FOVCircle = v end)

    -- Ativa primeira aba
    abas["Aimbot"].Visible = true
    btns["Aimbot"].BackgroundColor3 = C.accent
    btns["Aimbot"].TextColor3 = Color3.new(0,0,0)

    -- Botão flutuante
    local btnF = Instance.new("TextButton")
    btnF.Size = UDim2.new(0, 55, 0, 55)
    btnF.Position = UDim2.new(0, 20, 0.5, -27)
    btnF.BackgroundColor3 = C.bgCard
    btnF.Text = "🎯"
    btnF.TextSize = 24
    btnF.TextColor3 = C.accent
    btnF.Font = Enum.Font.GothamBold
    btnF.BorderSizePixel = 0
    btnF.Active = true
    btnF.Draggable = true
    btnF.Parent = gui
    Instance.new("UICorner", btnF).CornerRadius = UDim.new(0, 12)
    local sf = Instance.new("UIStroke", btnF)
    sf.Color = C.accent
    sf.Thickness = 1.5

    btnF.MouseButton1Click:Connect(function()
        painel.Visible = not painel.Visible
        btnF.Visib
