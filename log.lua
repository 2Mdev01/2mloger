-- SHAKA LOGGER v3.0 - Delta Executor
-- Versão Ultra Simplificada
local _ = nil
wait(2)

print("=================================")
print("SHAKA sLOGGER v3.0 Iniciando...")
print("=================================")

wait(1)

-- Criar tabela global
if not getgenv then
    getgenv = function() return _G end
end

getgenv().Shaka = {}
local L = getgenv().Shaka

-- Dados
L.Events = {}
L.Logs = {}
L.Blocked = {}
L.IsOpen = false
L.Tab = "Home"

-- Config
local KEY = Enum.KeyCode.F
local MAX = 30

-- Colors
local C = {
    BG = Color3.new(0.06, 0.06, 0.08),
    Card = Color3.new(0.1, 0.1, 0.14),
    Main = Color3.new(0.39, 0.4, 0.95),
    Good = Color3.new(0.13, 0.77, 0.37),
    Bad = Color3.new(0.94, 0.27, 0.27),
    Warn = Color3.new(0.98, 0.57, 0.24),
    Text = Color3.new(0.97, 0.98, 0.99),
    Gray = Color3.new(0.58, 0.64, 0.72)
}

-- Services
local Plr = game:GetService("Players")
local Run = game:GetService("RunService")
local Inp = game:GetService("UserInputService")
local Tw = game:GetService("TweenService")

-- Funções
local function Log(txt)
    print("[SHAKA]", txt)
    table.insert(L.Logs, 1, {T = os.date("%H:%M:%S"), M = txt})
    while #L.Logs > MAX do
        table.remove(L.Logs)
    end
end

local function Fmt(a)
    if not a then return "{}" end
    local t = {}
    for i = 1, math.min(3, #a) do
        local v = a[i]
        if type(v) == "string" then
            table.insert(t, '"' .. tostring(v):sub(1, 10) .. '"')
        elseif type(v) == "number" then
            table.insert(t, tostring(v))
        elseif typeof(v) == "Instance" then
            table.insert(t, v.Name)
        else
            table.insert(t, tostring(v):sub(1, 8))
        end
    end
    return "{" .. table.concat(t, ",") .. "}"
end

-- Captura
function L:Cap(r, t, a)
    if not r or not r.Parent then return end
    
    local p = r:GetFullName()
    if self.Blocked[p] then return end
    
    local e = {
        N = r.Name,
        T = t,
        P = p,
        R = r,
        A = a or {},
        Time = os.date("%H:%M:%S"),
        Loop = false
    }
    
    table.insert(self.Events, 1, e)
    while #self.Events > MAX do
        table.remove(self.Events)
    end
    
    if self.IsOpen then
        task.spawn(function() self:Ref() end)
    end
end

-- Hook
function L:Hook()
    Log("Instalando hook...")
    
    -- Método 1
    if hookmetamethod and getnamecallmethod then
        pcall(function()
            local old
            old = hookmetamethod(game, "__namecall", function(s, ...)
                local m = getnamecallmethod()
                if m == "FireServer" or m == "InvokeServer" then
                    task.spawn(function()
                        if typeof(s) == "Instance" then
                            L:Cap(s, m == "FireServer" and "RE" or "RF", {...})
                        end
                    end)
                end
                return old(s, ...)
            end)
            Log("Hook OK!")
        end)
    end
    
    -- Método 2
    task.spawn(function()
        for _, o in ipairs(game:GetDescendants()) do
            if o:IsA("RemoteEvent") then
                pcall(function()
                    local old = o.FireServer
                    o.FireServer = function(s, ...)
                        task.spawn(function() L:Cap(s, "RE", {...}) end)
                        return old(s, ...)
                    end
                end)
            elseif o:IsA("RemoteFunction") then
                pcall(function()
                    local old = o.InvokeServer
                    o.InvokeServer = function(s, ...)
                        task.spawn(function() L:Cap(s, "RF", {...}) end)
                        return old(s, ...)
                    end
                end)
            end
        end
    end)
end

-- Replay
function L:Rep(e, n)
    task.spawn(function()
        for i = 1, n do
            pcall(function()
                if e.T == "RE" then
                    e.R:FireServer(unpack(e.A))
                else
                    e.R:InvokeServer(unpack(e.A))
                end
            end)
            if i < n then wait(0.2) end
        end
        Log("Replay x" .. n)
    end)
end

-- Loop
function L:Loop(e)
    e.Loop = not e.Loop
    
    if e.Loop then
        Log("Loop ON")
        task.spawn(function()
            while e.Loop do
                pcall(function()
                    if e.R and e.R.Parent then
                        e.R:FireServer(unpack(e.A))
                    else
                        e.Loop = false
                    end
                end)
                wait(0.5)
            end
        end)
    else
        Log("Loop OFF")
    end
    
    return e.Loop
end

-- Block
function L:Block(p)
    if self.Blocked[p] then
        self.Blocked[p] = nil
        Log("Desbloqueado")
    else
        self.Blocked[p] = true
        Log("Bloqueado")
    end
end

-- Exec
function L:Exec(c)
    if not c or c == "" then
        Log("Código vazio!")
        return
    end
    
    Log("Executando...")
    task.spawn(function()
        local s, e = pcall(function()
            local f = loadstring(c)
            if f then
                f()
                Log("✅ Sucesso!")
            end
        end)
        if not s then
            Log("❌ Erro: " .. tostring(e))
        end
    end)
end

-- UI
function L:UI()
    Log("Criando UI...")
    
    local sg = Instance.new("ScreenGui")
    sg.Name = "Shaka"
    sg.ResetOnSpawn = false
    
    pcall(function()
        sg.Parent = game:GetService("CoreGui")
    end)
    
    if not sg.Parent then
        sg.Parent = Plr.LocalPlayer:WaitForChild("PlayerGui")
    end
    
    -- Main
    local m = Instance.new("Frame")
    m.Name = "Main"
    m.Size = UDim2.new(0, 700, 0, 500)
    m.Position = UDim2.new(0.5, -350, 0.5, -250)
    m.BackgroundColor3 = C.BG
    m.BorderSizePixel = 0
    m.Visible = false
    m.Parent = sg
    
    self.Main = m
    
    local mc = Instance.new("UICorner")
    mc.CornerRadius = UDim.new(0, 10)
    mc.Parent = m
    
    -- Header
    local h = Instance.new("Frame")
    h.Size = UDim2.new(1, 0, 0, 45)
    h.BackgroundColor3 = Color3.new(0.08, 0.08, 0.12)
    h.BorderSizePixel = 0
    h.Parent = m
    
    local hc = Instance.new("UICorner")
    hc.CornerRadius = UDim.new(0, 10)
    hc.Parent = h
    
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -80, 1, 0)
    t.Position = UDim2.new(0, 10, 0, 0)
    t.BackgroundTransparency = 1
    t.Text = "⚡ SHAKA LOGGER v3.0"
    t.TextColor3 = C.Text
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Font = Enum.Font.GothamBold
    t.TextSize = 16
    t.Parent = h
    
    -- Close
    local x = Instance.new("TextButton")
    x.Size = UDim2.new(0, 35, 0, 35)
    x.Position = UDim2.new(1, -40, 0, 5)
    x.BackgroundColor3 = C.Bad
    x.Text = "X"
    x.TextColor3 = C.Text
    x.Font = Enum.Font.GothamBold
    x.TextSize = 14
    x.BorderSizePixel = 0
    x.Parent = h
    
    local xc = Instance.new("UICorner")
    xc.CornerRadius = UDim.new(0, 6)
    xc.Parent = x
    
    x.MouseButton1Click:Connect(function()
        self:Tog()
    end)
    
    -- Tabs
    local tb = Instance.new("Frame")
    tb.Size = UDim2.new(1, -20, 0, 35)
    tb.Position = UDim2.new(0, 10, 0, 50)
    tb.BackgroundTransparency = 1
    tb.Parent = m
    
    local tl = Instance.new("UIListLayout")
    tl.FillDirection = Enum.FillDirection.Horizontal
    tl.Padding = UDim.new(0, 5)
    tl.Parent = tb
    
    self.TBtns = {}
    local tabs = {"Home", "Events", "Exec", "Logs"}
    
    for _, n in ipairs(tabs) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 160, 1, 0)
        b.BackgroundColor3 = C.Card
        b.Text = n
        b.TextColor3 = C.Gray
        b.Font = Enum.Font.GothamBold
        b.TextSize = 12
        b.BorderSizePixel = 0
        b.Parent = tb
        
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 6)
        bc.Parent = b
        
        b.MouseButton1Click:Connect(function()
            self:SwTab(n)
        end)
        
        self.TBtns[n] = b
    end
    
    -- Content
    local ct = Instance.new("Frame")
    ct.Size = UDim2.new(1, -20, 1, -95)
    ct.Position = UDim2.new(0, 10, 0, 90)
    ct.BackgroundTransparency = 1
    ct.Parent = m
    
    self.Frames = {}
    
    for _, n in ipairs(tabs) do
        local f = Instance.new("ScrollingFrame")
        f.Name = n
        f.Size = UDim2.new(1, 0, 1, 0)
        f.BackgroundTransparency = 1
        f.ScrollBarThickness = 5
        f.ScrollBarImageColor3 = C.Main
        f.Visible = false
        f.CanvasSize = UDim2.new(0, 0, 0, 0)
        f.AutomaticCanvasSize = Enum.AutomaticSize.Y
        f.BorderSizePixel = 0
        f.Parent = ct
        
        local l = Instance.new("UIListLayout")
        l.Padding = UDim.new(0, 8)
        l.Parent = f
        
        self.Frames[n] = f
    end
    
    Log("UI OK!")
end

function L:SwTab(n)
    self.Tab = n
    
    for nm, b in pairs(self.TBtns) do
        b.BackgroundColor3 = (nm == n) and C.Main or C.Card
        b.TextColor3 = (nm == n) and C.Text or C.Gray
    end
    
    for nm, f in pairs(self.Frames) do
        f.Visible = (nm == n)
    end
    
    self:Ref()
end

function L:Ref()
    local f = self.Frames[self.Tab]
    if not f then return end
    
    for _, c in ipairs(f:GetChildren()) do
        if not c:IsA("UIListLayout") then
            c:Destroy()
        end
    end
    
    if self.Tab == "Home" then
        self:BHome(f)
    elseif self.Tab == "Events" then
        self:BEvt(f)
    elseif self.Tab == "Exec" then
        self:BExec(f)
    elseif self.Tab == "Logs" then
        self:BLog(f)
    end
end

function L:BHome(p)
    local c = Instance.new("Frame")
    c.Size = UDim2.new(1, 0, 0, 100)
    c.BackgroundColor3 = C.Card
    c.BorderSizePixel = 0
    c.Parent = p
    
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 8)
    cc.Parent = c
    
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -20, 1, -20)
    t.Position = UDim2.new(0, 10, 0, 10)
    t.BackgroundTransparency = 1
    t.Text = string.format("📊 STATS\n\nEventos: %d\nBloqueados: %d", #self.Events, #self.Blocked)
    t.TextColor3 = C.Text
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextYAlignment = Enum.TextYAlignment.Top
    t.Font = Enum.Font.Gotham
    t.TextSize = 13
    t.Parent = c
    
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, 35)
    b.Position = UDim2.new(0, 10, 0, 0)
    b.BackgroundColor3 = C.Bad
    b.Text = "🗑️ Limpar"
    b.TextColor3 = C.Text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.BorderSizePixel = 0
    b.Parent = p
    
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 6)
    bc.Parent = b
    
    b.MouseButton1Click:Connect(function()
        self.Events = {}
        Log("Limpo")
        self:Ref()
    end)
end

function L:BEvt(p)
    if #self.Events == 0 then
        local e = Instance.new("TextLabel")
        e.Size = UDim2.new(1, 0, 0, 60)
        e.BackgroundColor3 = C.Card
        e.Text = "Nenhum evento\nInteraja com o jogo"
        e.TextColor3 = C.Gray
        e.Font = Enum.Font.Gotham
        e.TextSize = 12
        e.BorderSizePixel = 0
        e.Parent = p
        
        local ec = Instance.new("UICorner")
        ec.CornerRadius = UDim.new(0, 8)
        ec.Parent = e
        return
    end
    
    for i, ev in ipairs(self.Events) do
        if i > 8 then break end
        
        local c = Instance.new("Frame")
        c.Size = UDim2.new(1, 0, 0, 85)
        c.BackgroundColor3 = C.Card
        c.BorderSizePixel = 0
        c.Parent = p
        
        local cc = Instance.new("UICorner")
        cc.CornerRadius = UDim.new(0, 8)
        cc.Parent = c
        
        local n = Instance.new("TextLabel")
        n.Size = UDim2.new(1, -180, 0, 18)
        n.Position = UDim2.new(0, 8, 0, 6)
        n.BackgroundTransparency = 1
        n.Text = "📡 " .. ev.N
        n.TextColor3 = C.Main
        n.TextXAlignment = Enum.TextXAlignment.Left
        n.Font = Enum.Font.GothamBold
        n.TextSize = 12
        n.Parent = c
        
        local pa = Instance.new("TextLabel")
        pa.Size = UDim2.new(1, -180, 0, 13)
        pa.Position = UDim2.new(0, 8, 0, 26)
        pa.BackgroundTransparency = 1
        pa.Text = ev.P
        pa.TextColor3 = C.Gray
        pa.TextXAlignment = Enum.TextXAlignment.Left
        pa.Font = Enum.Font.Code
        pa.TextSize = 8
        pa.TextTruncate = Enum.TextTruncate.AtEnd
        pa.Parent = c
        
        local a = Instance.new("TextLabel")
        a.Size = UDim2.new(1, -180, 0, 13)
        a.Position = UDim2.new(0, 8, 0, 41)
        a.BackgroundTransparency = 1
        a.Text = Fmt(ev.A)
        a.TextColor3 = C.Warn
        a.TextXAlignment = Enum.TextXAlignment.Left
        a.Font = Enum.Font.Code
        a.TextSize = 8
        a.TextTruncate = Enum.TextTruncate.AtEnd
        a.Parent = c
        
        -- Botões
        local b1 = Instance.new("TextButton")
        b1.Size = UDim2.new(0, 45, 0, 22)
        b1.Position = UDim2.new(0, 8, 0, 58)
        b1.BackgroundColor3 = C.Good
        b1.Text = "▶️"
        b1.TextColor3 = C.Text
        b1.Font = Enum.Font.GothamBold
        b1.TextSize = 11
        b1.BorderSizePixel = 0
        b1.Parent = c
        
        local b1c = Instance.new("UICorner")
        b1c.CornerRadius = UDim.new(0, 5)
        b1c.Parent = b1
        
        b1.MouseButton1Click:Connect(function()
            self:Rep(ev, 1)
        end)
        
        local b2 = Instance.new("TextButton")
        b2.Size = UDim2.new(0, 48, 0, 22)
        b2.Position = UDim2.new(0, 58, 0, 58)
        b2.BackgroundColor3 = C.Main
        b2.Text = "⚡5"
        b2.TextColor3 = C.Text
        b2.Font = Enum.Font.GothamBold
        b2.TextSize = 10
        b2.BorderSizePixel = 0
        b2.Parent = c
        
        local b2c = Instance.new("UICorner")
        b2c.CornerRadius = UDim.new(0, 5)
        b2c.Parent = b2
        
        b2.MouseButton1Click:Connect(function()
            self:Rep(ev, 5)
        end)
        
        local b3 = Instance.new("TextButton")
        b3.Size = UDim2.new(0, 48, 0, 22)
        b3.Position = UDim2.new(0, 111, 0, 58)
        b3.BackgroundColor3 = ev.Loop and C.Bad or C.Warn
        b3.Text = ev.Loop and "⏹️" or "🔁"
        b3.TextColor3 = C.Text
        b3.Font = Enum.Font.GothamBold
        b3.TextSize = 10
        b3.BorderSizePixel = 0
        b3.Parent = c
        
        local b3c = Instance.new("UICorner")
        b3c.CornerRadius = UDim.new(0, 5)
        b3c.Parent = b3
        
        b3.MouseButton1Click:Connect(function()
            local l = self:Loop(ev)
            b3.Text = l and "⏹️" or "🔁"
            b3.BackgroundColor3 = l and C.Bad or C.Warn
        end)
        
        local b4 = Instance.new("TextButton")
        b4.Size = UDim2.new(0, 48, 0, 22)
        b4.Position = UDim2.new(0, 164, 0, 58)
        b4.BackgroundColor3 = C.Bad
        b4.Text = "🚫"
        b4.TextColor3 = C.Text
        b4.Font = Enum.Font.GothamBold
        b4.TextSize = 10
        b4.BorderSizePixel = 0
        b4.Parent = c
        
        local b4c = Instance.new("UICorner")
        b4c.CornerRadius = UDim.new(0, 5)
        b4c.Parent = b4
        
        b4.MouseButton1Click:Connect(function()
            self:Block(ev.P)
            wait(0.1)
            self:Ref()
        end)
    end
end

function L:BExec(p)
    local c = Instance.new("Frame")
    c.Size = UDim2.new(1, 0, 0, 300)
    c.BackgroundColor3 = C.Card
    c.BorderSizePixel = 0
    c.Parent = p
    
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 8)
    cc.Parent = c
    
    local tb = Instance.new("TextBox")
    tb.Size = UDim2.new(1, -20, 0, 220)
    tb.Position = UDim2.new(0, 10, 0, 10)
    tb.BackgroundColor3 = Color3.new(0.08, 0.08, 0.11)
    tb.Text = ""
    tb.PlaceholderText = "-- Código Lua\nprint('Olá!')"
    tb.TextColor3 = C.Text
    tb.TextXAlignment = Enum.TextXAlignment.Left
    tb.TextYAlignment = Enum.TextYAlignment.Top
    tb.Font = Enum.Font.Code
    tb.TextSize = 11
    tb.MultiLine = true
    tb.ClearTextOnFocus = false
    tb.BorderSizePixel = 0
    tb.Parent = c
    
    local tbc = Instance.new("UICorner")
    tbc.CornerRadius = UDim.new(0, 6)
    tbc.Parent = tb
    
    local be = Instance.new("TextButton")
    be.Size = UDim2.new(0, 270, 0, 35)
    be.Position = UDim2.new(0, 10, 0, 240)
    be.BackgroundColor3 = C.Good
    be.Text = "▶️ EXECUTAR"
    be.TextColor3 = C.Text
    be.Font = Enum.Font.GothamBold
    be.TextSize = 13
    be.BorderSizePixel = 0
    be.Parent = c
    
    local bec = Instance.new("UICorner")
    bec.CornerRadius = UDim.new(0, 6)
    bec.Parent = be
    
    be.MouseButton1Click:Connect(function()
        self:Exec(tb.Text)
    end)
    
    local bcl = Instance.new("TextButton")
    bcl.Size = UDim2.new(0, 130, 0, 35)
    bcl.Position = UDim2.new(0, 290, 0, 240)
    bcl.BackgroundColor3 = C.Warn
    bcl.Text = "🗑️ Limpar"
    bcl.TextColor3 = C.Text
    bcl.Font = Enum.Font.GothamBold
    bcl.TextSize = 12
    bcl.BorderSizePixel = 0
    bcl.Parent = c
    
    local bclc = Instance.new("UICorner")
    bclc.CornerRadius = UDim.new(0, 6)
    bclc.Parent = bcl
    
    bcl.MouseButton1Click:Connect(function()
        tb.Text = ""
        Log("Limpo")
    end)
end

function L:BLog(p)
    if #self.Logs == 0 then
        local e = Instance.new("TextLabel")
        e.Size = UDim2.new(1, 0, 0, 50)
        e.BackgroundColor3 = C.Card
        e.Text = "Sem logs"
        e.TextColor3 = C.Gray
        e.Font = Enum.Font.Gotham
        e.TextSize = 12
        e.BorderSizePixel = 0
        e.Parent = p
        
        local ec = Instance.new("UICorner")
        ec.CornerRadius = UDim.new(0, 8)
        ec.Parent = e
        return
    end
    
    for i, lg in ipairs(self.Logs) do
        if i > 12 then break end
        
        local c = Instance.new("Frame")
        c.Size = UDim2.new(1, 0, 0, 30)
        c.BackgroundColor3 = C.Card
        c.BorderSizePixel = 0
        c.Parent = p
        
        local cc = Instance.new("UICorner")
        cc.CornerRadius = UDim.new(0, 5)
        cc.Parent = c
        
        local tm = Instance.new("TextLabel")
        tm.Size = UDim2.new(0, 55, 1, 0)
        tm.Position = UDim2.new(0, 8, 0, 0)
        tm.BackgroundTransparency = 1
        tm.Text = lg.T
        tm.TextColor3 = C.Gray
        tm.Font = Enum.Font.Code
        tm.TextSize = 9
        tm.Parent = c
        
        local ms = Instance.new("TextLabel")
        ms.Size = UDim2.new(1, -70, 1, 0)
        ms.Position = UDim2.new(0, 65, 0, 0)
        ms.BackgroundTransparency = 1
        ms.Text = lg.M
        ms.TextColor3 = C.Text
        ms.TextXAlignment = Enum.TextXAlignment.Left
        ms.Font = Enum.Font.Gotham
        ms.TextSize = 10
        ms.TextTruncate = Enum.TextTruncate.AtEnd
        ms.Parent = c
    end
end

function L:Tog()
    self.IsOpen = not self.IsOpen
    
    if not self.Main then return end
    
    if self.IsOpen then
        self.Main.Visible = true
        self.Main.Size = UDim2.new(0, 0, 0, 0)
        
        Tw:Create(self.Main, 
            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 700, 0, 500)}):Play()
        
        wait(0.2)
        self:Ref()
    else
        Tw:Create(self.Main, 
            TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In),
            {Size = UDim2.new(0, 0, 0, 0)}):Play()
        
        wait(0.2)
        self.Main.Visible = false
    end
end

function L:Key()
    Inp.InputBegan:Connect(function(i, p)
        if not p and i.KeyCode == KEY then
            self:Tog()
        end
    end)
end

function L:Go()
    Log("Iniciando...")
    
    wait(0.3)
    self:UI()
    
    wait(0.2)
    self:Key()
    Log("Keybind [F]")
    
    wait(0.3)
    self:Hook()
    
    Log("✅ PRONTO!")
    Log("Pressione [F]")
    
    wait(1)
    self:Tog()
    wait(0.2)
    self:SwTab("Home")
end

-- Start
Log("Aguardando...")
wait(1)

local ok, err = pcall(function()
    L:Go()
end)

if not ok then
    Log("ERRO: " .. tostring(err))
    print("[SHAKA] ERRO:", err)
end

print("[SHAKA] ✅ Carregado!")
print("[SHAKA] Use _G.Shaka ou getgenv().Shaka")

return L
