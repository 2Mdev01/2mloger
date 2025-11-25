--[[
    SHAKA LOGGER PRO v4.0
    Logger profissional para captura de RemoteEvents/Functions
    USO APENAS EM AMBIENTES CONTROLADOS E AUTORIZADOS
]]

-- Inicialização
local startTime = tick()
print("🔷 SHAKA LOGGER PRO v4.0")
print("⏳ Inicializando...")

-- Criar namespace global
if not getgenv then
    getgenv = function() return _G end
end

getgenv().ShakaLogger = getgenv().ShakaLogger or {}
local Shaka = getgenv().ShakaLogger

-- ============================================================================
-- CONFIGURAÇÃO
-- ============================================================================
local CONFIG = {
    ToggleKey = Enum.KeyCode.F,
    MaxEvents = 100,
    MaxLogs = 50,
    SaveDelay = 0.1,
    NotificationDuration = 5
}

-- ============================================================================
-- CORES
-- ============================================================================
local COLORS = {
    Background = Color3.fromRGB(15, 15, 20),
    Card = Color3.fromRGB(25, 25, 35),
    CardHover = Color3.fromRGB(30, 30, 40),
    Primary = Color3.fromRGB(99, 102, 241),
    Success = Color3.fromRGB(34, 197, 94),
    Warning = Color3.fromRGB(251, 146, 60),
    Danger = Color3.fromRGB(239, 68, 68),
    Text = Color3.fromRGB(248, 250, 252),
    TextDim = Color3.fromRGB(148, 163, 184),
    Border = Color3.fromRGB(51, 65, 85)
}

-- ============================================================================
-- SERVIÇOS
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

-- ============================================================================
-- DADOS
-- ============================================================================
Shaka.Events = Shaka.Events or {}
Shaka.Logs = Shaka.Logs or {}
Shaka.Blocked = Shaka.Blocked or {}
Shaka.Loops = Shaka.Loops or {}
Shaka.IsOpen = false
Shaka.CurrentTab = "Events"
Shaka.SearchFilter = ""
Shaka.Stats = Shaka.Stats or {
    TotalCaptured = 0,
    RemoteEvents = 0,
    RemoteFunctions = 0,
    Blocked = 0
}

-- ============================================================================
-- UTILITÁRIOS
-- ============================================================================
local function CreateLog(message, logType)
    logType = logType or "INFO"
    local log = {
        Time = os.date("%H:%M:%S"),
        Message = message,
        Type = logType
    }
    
    table.insert(Shaka.Logs, 1, log)
    
    while #Shaka.Logs > CONFIG.MaxLogs do
        table.remove(Shaka.Logs)
    end
    
    print(string.format("[SHAKA][%s] %s", logType, message))
end

local function FormatArguments(args)
    if not args or #args == 0 then return "{}" end
    
    local formatted = {}
    local maxArgs = math.min(5, #args)
    
    for i = 1, maxArgs do
        local arg = args[i]
        local argType = type(arg)
        local argTypeof = typeof(arg)
        
        if argType == "string" then
            table.insert(formatted, string.format('"%s"', tostring(arg):sub(1, 20)))
        elseif argType == "number" then
            table.insert(formatted, tostring(arg))
        elseif argType == "boolean" then
            table.insert(formatted, tostring(arg))
        elseif argTypeof == "Instance" then
            table.insert(formatted, arg:GetFullName())
        elseif argTypeof == "Vector3" then
            table.insert(formatted, string.format("Vector3(%d, %d, %d)", arg.X, arg.Y, arg.Z))
        elseif argTypeof == "CFrame" then
            table.insert(formatted, "CFrame")
        elseif argType == "table" then
            table.insert(formatted, "Table[" .. #arg .. "]")
        else
            table.insert(formatted, tostring(argTypeof))
        end
    end
    
    if #args > maxArgs then
        table.insert(formatted, "...")
    end
    
    return "{" .. table.concat(formatted, ", ") .. "}"
end

local function SafeFireRemote(remote, args, remoteType)
    local success, err = pcall(function()
        if remoteType == "RemoteEvent" then
            remote:FireServer(unpack(args))
        elseif remoteType == "RemoteFunction" then
            remote:InvokeServer(unpack(args))
        end
    end)
    
    if not success then
        CreateLog("Erro ao executar: " .. tostring(err), "ERROR")
    end
    
    return success
end

-- ============================================================================
-- CAPTURA DE EVENTOS
-- ============================================================================
function Shaka:CaptureEvent(remote, remoteType, args)
    if not remote or not remote.Parent then return end
    
    local fullPath = remote:GetFullName()
    
    -- Verificar se está bloqueado
    if self.Blocked[fullPath] then return end
    
    -- Criar evento
    local event = {
        ID = HttpService:GenerateGUID(false),
        Name = remote.Name,
        Type = remoteType,
        Path = fullPath,
        Remote = remote,
        Arguments = args or {},
        Time = os.date("%H:%M:%S"),
        Timestamp = tick(),
        Count = 1,
        IsLooping = false
    }
    
    -- Verificar duplicatas recentes
    for i, existingEvent in ipairs(self.Events) do
        if existingEvent.Path == fullPath and 
           (tick() - existingEvent.Timestamp) < 2 then
            existingEvent.Count = existingEvent.Count + 1
            existingEvent.Time = os.date("%H:%M:%S")
            existingEvent.Timestamp = tick()
            return
        end
    end
    
    -- Adicionar novo evento
    table.insert(self.Events, 1, event)
    
    -- Atualizar estatísticas
    self.Stats.TotalCaptured = self.Stats.TotalCaptured + 1
    if remoteType == "RemoteEvent" then
        self.Stats.RemoteEvents = self.Stats.RemoteEvents + 1
    else
        self.Stats.RemoteFunctions = self.Stats.RemoteFunctions + 1
    end
    
    -- Limitar eventos
    while #self.Events > CONFIG.MaxEvents do
        table.remove(self.Events)
    end
    
    -- Atualizar UI se aberta
    if self.IsOpen and self.CurrentTab == "Events" then
        task.defer(function()
            if self.RefreshEvents then
                self:RefreshEvents()
            end
        end)
    end
end

-- ============================================================================
-- SISTEMA DE HOOKS
-- ============================================================================
function Shaka:InstallHooks()
    CreateLog("Instalando hooks...", "INFO")
    
    local hookedCount = 0
    
    -- Hook 1: Metamethod (mais eficiente)
    if hookmetamethod and getnamecallmethod then
        local success = pcall(function()
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                local args = {...}
                
                if method == "FireServer" or method == "InvokeServer" then
                    task.spawn(function()
                        if typeof(self) == "Instance" and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
                            local remoteType = self:IsA("RemoteEvent") and "RemoteEvent" or "RemoteFunction"
                            Shaka:CaptureEvent(self, remoteType, args)
                        end
                    end)
                end
                
                return oldNamecall(self, ...)
            end)
            
            hookedCount = hookedCount + 1
            CreateLog("✓ Metamethod hook instalado", "SUCCESS")
        end)
        
        if not success then
            CreateLog("✗ Falha no metamethod hook", "ERROR")
        end
    end
    
    -- Hook 2: Método direto em remotes existentes
    task.spawn(function()
        local function hookRemote(remote)
            if remote:IsA("RemoteEvent") then
                pcall(function()
                    local oldFire = remote.FireServer
                    remote.FireServer = function(self, ...)
                        task.spawn(function()
                            Shaka:CaptureEvent(self, "RemoteEvent", {...})
                        end)
                        return oldFire(self, ...)
                    end
                    hookedCount = hookedCount + 1
                end)
            elseif remote:IsA("RemoteFunction") then
                pcall(function()
                    local oldInvoke = remote.InvokeServer
                    remote.InvokeServer = function(self, ...)
                        task.spawn(function()
                            Shaka:CaptureEvent(self, "RemoteFunction", {...})
                        end)
                        return oldInvoke(self, ...)
                    end
                    hookedCount = hookedCount + 1
                end)
            end
        end
        
        -- Hook remotes existentes
        for _, descendant in ipairs(game:GetDescendants()) do
            hookRemote(descendant)
        end
        
        -- Hook novos remotes
        game.DescendantAdded:Connect(function(descendant)
            task.wait()
            hookRemote(descendant)
        end)
        
        CreateLog(string.format("✓ %d remotes hookados diretamente", hookedCount), "SUCCESS")
    end)
    
    CreateLog("Hooks instalados com sucesso!", "SUCCESS")
end

-- ============================================================================
-- AÇÕES DE EVENTOS
-- ============================================================================
function Shaka:ReplayEvent(event, count)
    count = count or 1
    
    task.spawn(function()
        for i = 1, count do
            local success = SafeFireRemote(event.Remote, event.Arguments, event.Type)
            
            if not success then
                CreateLog(string.format("Falha no replay %d/%d", i, count), "ERROR")
                break
            end
            
            if i < count then
                task.wait(0.1)
            end
        end
        
        CreateLog(string.format("Replay x%d executado", count), "SUCCESS")
    end)
end

function Shaka:ToggleLoop(event)
    if event.IsLooping then
        -- Parar loop
        event.IsLooping = false
        if self.Loops[event.ID] then
            self.Loops[event.ID] = nil
        end
        CreateLog("Loop desativado: " .. event.Name, "INFO")
    else
        -- Iniciar loop
        event.IsLooping = true
        
        self.Loops[event.ID] = task.spawn(function()
            while event.IsLooping and event.Remote and event.Remote.Parent do
                SafeFireRemote(event.Remote, event.Arguments, event.Type)
                task.wait(0.5)
            end
            event.IsLooping = false
        end)
        
        CreateLog("Loop ativado: " .. event.Name, "SUCCESS")
    end
    
    return event.IsLooping
end

function Shaka:BlockEvent(event)
    local path = event.Path
    
    if self.Blocked[path] then
        self.Blocked[path] = nil
        self.Stats.Blocked = math.max(0, self.Stats.Blocked - 1)
        CreateLog("Desbloqueado: " .. event.Name, "INFO")
    else
        self.Blocked[path] = true
        self.Stats.Blocked = self.Stats.Blocked + 1
        CreateLog("Bloqueado: " .. event.Name, "WARNING")
    end
end

function Shaka:ClearEvents()
    self.Events = {}
    self.Stats.TotalCaptured = 0
    self.Stats.RemoteEvents = 0
    self.Stats.RemoteFunctions = 0
    CreateLog("Eventos limpos", "INFO")
    
    if self.RefreshEvents then
        self:RefreshEvents()
    end
end

function Shaka:ExportDump()
    local dump = {
        GameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name,
        PlaceId = game.PlaceId,
        Timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        Stats = self.Stats,
        Events = {}
    }
    
    for _, event in ipairs(self.Events) do
        table.insert(dump.Events, {
            Name = event.Name,
            Type = event.Type,
            Path = event.Path,
            Arguments = FormatArguments(event.Arguments),
            Count = event.Count
        })
    end
    
    local json = HttpService:JSONEncode(dump)
    
    if setclipboard then
        setclipboard(json)
        CreateLog("Dump copiado para clipboard!", "SUCCESS")
    else
        CreateLog("Dump gerado (clipboard não disponível)", "WARNING")
        print(json)
    end
    
    return json
end

-- ============================================================================
-- EXECUTOR DE CÓDIGO
-- ============================================================================
function Shaka:ExecuteCode(code)
    if not code or code == "" then
        CreateLog("Código vazio!", "ERROR")
        return
    end
    
    CreateLog("Executando código...", "INFO")
    
    task.spawn(function()
        local func, loadErr = loadstring(code)
        
        if not func then
            CreateLog("Erro de sintaxe: " .. tostring(loadErr), "ERROR")
            return
        end
        
        local success, execErr = pcall(func)
        
        if success then
            CreateLog("✓ Código executado com sucesso!", "SUCCESS")
        else
            CreateLog("✗ Erro na execução: " .. tostring(execErr), "ERROR")
        end
    end)
end

-- ============================================================================
-- INTERFACE GRÁFICA
-- ============================================================================
function Shaka:CreateUI()
    CreateLog("Criando interface...", "INFO")
    
    -- Criar ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ShakaLoggerPro"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Tentar colocar no CoreGui
    local success = pcall(function()
        screenGui.Parent = game:GetService("CoreGui")
    end)
    
    if not success then
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    
    self.ScreenGui = screenGui
    
    -- Container principal
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 850, 0, 600)
    mainFrame.Position = UDim2.new(0.5, -425, 0.5, -300)
    mainFrame.BackgroundColor3 = COLORS.Background
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = false
    mainFrame.Parent = screenGui
    
    self.MainFrame = mainFrame
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = mainFrame
    
    -- Barra superior
    self:CreateHeader(mainFrame)
    
    -- Abas
    self:CreateTabs(mainFrame)
    
    -- Container de conteúdo
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "Content"
    contentFrame.Size = UDim2.new(1, -20, 1, -110)
    contentFrame.Position = UDim2.new(0, 10, 0, 100)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = mainFrame
    
    self.ContentFrame = contentFrame
    
    -- Criar páginas
    self:CreateEventsPage()
    self:CreateExecutorPage()
    self:CreateDumpPage()
    self:CreateLogsPage()
    
    -- Tornar arrastável
    self:MakeDraggable(mainFrame)
    
    CreateLog("Interface criada com sucesso!", "SUCCESS")
end

function Shaka:CreateHeader(parent)
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 50)
    header.BackgroundColor3 = COLORS.Card
    header.BorderSizePixel = 0
    header.Parent = parent
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 12)
    headerCorner.Parent = header
    
    -- Título
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 300, 1, 0)
    title.Position = UDim2.new(0, 15, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "⚡ SHAKA LOGGER PRO"
    title.TextColor3 = COLORS.Text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Parent = header
    
    -- Versão
    local version = Instance.new("TextLabel")
    version.Size = UDim2.new(0, 100, 1, 0)
    version.Position = UDim2.new(0, 220, 0, 0)
    version.BackgroundTransparency = 1
    version.Text = "v4.0"
    version.TextColor3 = COLORS.Primary
    version.TextXAlignment = Enum.TextXAlignment.Left
    version.Font = Enum.Font.GothamBold
    version.TextSize = 12
    version.Parent = header
    
    -- Botão fechar
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 40, 0, 40)
    closeBtn.Position = UDim2.new(1, -45, 0, 5)
    closeBtn.BackgroundColor3 = COLORS.Danger
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = COLORS.Text
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = header
    
    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 8)
    closeBtnCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        self:ToggleUI()
    end)
end

function Shaka:CreateTabs(parent)
    local tabFrame = Instance.new("Frame")
    tabFrame.Name = "Tabs"
    tabFrame.Size = UDim2.new(1, -20, 0, 40)
    tabFrame.Position = UDim2.new(0, 10, 0, 55)
    tabFrame.BackgroundTransparency = 1
    tabFrame.Parent = parent
    
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 8)
    tabLayout.Parent = tabFrame
    
    self.TabButtons = {}
    
    local tabs = {
        {Name = "Events", Icon = "📡", Desc = "Eventos capturados"},
        {Name = "Executor", Icon = "⚙️", Desc = "Executar código"},
        {Name = "Dump", Icon = "📊", Desc = "Exportar dados"},
        {Name = "Logs", Icon = "📝", Desc = "Registro de ações"}
    }
    
    for _, tab in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 200, 1, 0)
        btn.BackgroundColor3 = COLORS.Card
        btn.Text = string.format("%s %s", tab.Icon, tab.Name)
        btn.TextColor3 = COLORS.TextDim
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 13
        btn.BorderSizePixel = 0
        btn.Parent = tabFrame
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            self:SwitchTab(tab.Name)
        end)
        
        self.TabButtons[tab.Name] = btn
    end
end

function Shaka:CreateEventsPage()
    local page = Instance.new("ScrollingFrame")
    page.Name = "EventsPage"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 6
    page.ScrollBarImageColor3 = COLORS.Primary
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = self.ContentFrame
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.Parent = page
    
    self.EventsPage = page
    self.EventsLayout = layout
end

function Shaka:CreateExecutorPage()
    local page = Instance.new("Frame")
    page.Name = "ExecutorPage"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = self.ContentFrame
    
    -- TextBox para código
    local codeBox = Instance.new("TextBox")
    codeBox.Size = UDim2.new(1, 0, 1, -50)
    codeBox.BackgroundColor3 = COLORS.Card
    codeBox.Text = ""
    codeBox.PlaceholderText = "-- Cole seu código Lua aqui\n-- Exemplo: print('Hello World!')"
    codeBox.TextColor3 = COLORS.Text
    codeBox.PlaceholderColor3 = COLORS.TextDim
    codeBox.TextXAlignment = Enum.TextXAlignment.Left
    codeBox.TextYAlignment = Enum.TextYAlignment.Top
    codeBox.Font = Enum.Font.Code
    codeBox.TextSize = 12
    codeBox.MultiLine = true
    codeBox.ClearTextOnFocus = false
    codeBox.BorderSizePixel = 0
    codeBox.Parent = page
    
    local codeBoxCorner = Instance.new("UICorner")
    codeBoxCorner.CornerRadius = UDim.new(0, 8)
    codeBoxCorner.Parent = codeBox
    
    self.CodeBox = codeBox
    
    -- Botões
    local btnFrame = Instance.new("Frame")
    btnFrame.Size = UDim2.new(1, 0, 0, 40)
    btnFrame.Position = UDim2.new(0, 0, 1, -40)
    btnFrame.BackgroundTransparency = 1
    btnFrame.Parent = page
    
    local btnLayout = Instance.new("UIListLayout")
    btnLayout.FillDirection = Enum.FillDirection.Horizontal
    btnLayout.Padding = UDim.new(0, 10)
    btnLayout.Parent = btnFrame
    
    -- Botão executar
    local execBtn = Instance.new("TextButton")
    execBtn.Size = UDim2.new(0, 400, 1, 0)
    execBtn.BackgroundColor3 = COLORS.Success
    execBtn.Text = "▶ EXECUTAR"
    execBtn.TextColor3 = COLORS.Text
    execBtn.Font = Enum.Font.GothamBold
    execBtn.TextSize = 14
    execBtn.BorderSizePixel = 0
    execBtn.Parent = btnFrame
    
    local execBtnCorner = Instance.new("UICorner")
    execBtnCorner.CornerRadius = UDim.new(0, 8)
    execBtnCorner.Parent = execBtn
    
    execBtn.MouseButton1Click:Connect(function()
        self:ExecuteCode(codeBox.Text)
    end)
    
    -- Botão limpar
    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0, 200, 1, 0)
    clearBtn.BackgroundColor3 = COLORS.Warning
    clearBtn.Text = "🗑 LIMPAR"
    clearBtn.TextColor3 = COLORS.Text
    clearBtn.Font = Enum.Font.GothamBold
    clearBtn.TextSize = 14
    clearBtn.BorderSizePixel = 0
    clearBtn.Parent = btnFrame
    
    local clearBtnCorner = Instance.new("UICorner")
    clearBtnCorner.CornerRadius = UDim.new(0, 8)
    clearBtnCorner.Parent = clearBtn
    
    clearBtn.MouseButton1Click:Connect(function()
        codeBox.Text = ""
        CreateLog("Editor limpo", "INFO")
    end)
    
    self.ExecutorPage = page
end

function Shaka:CreateDumpPage()
    local page = Instance.new("Frame")
    page.Name = "DumpPage"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = self.ContentFrame
    
    -- Card de estatísticas
    local statsCard = Instance.new("Frame")
    statsCard.Size = UDim2.new(1, 0, 0, 150)
    statsCard.BackgroundColor3 = COLORS.Card
    statsCard.BorderSizePixel = 0
    statsCard.Parent = page
    
    local statsCorner = Instance.new("UICorner")
    statsCorner.CornerRadius = UDim.new(0, 8)
    statsCorner.Parent = statsCard
    
    local statsText = Instance.new("TextLabel")
    statsText.Size = UDim2.new(1, -20, 1, -20)
    statsText.Position = UDim2.new(0, 10, 0, 10)
    statsText.BackgroundTransparency = 1
    statsText.Text = "Carregando estatísticas..."
    statsText.TextColor3 = COLORS.Text
    statsText.TextXAlignment = Enum.TextXAlignment.Left
    statsText.TextYAlignment = Enum.TextYAlignment.Top
    statsText.Font = Enum.Font.Gotham
    statsText.TextSize = 13
    statsText.Parent = statsCard
    
    self.StatsText = statsText
    
    -- Botão exportar
    local exportBtn = Instance.new("TextButton")
    exportBtn.Size = UDim2.new(1, 0, 0, 50)
    exportBtn.Position = UDim2.new(0, 0, 0, 160)
    exportBtn.BackgroundColor3 = COLORS.Primary
    exportBtn.Text = "📋 EXPORTAR DUMP (COPIAR JSON)"
    exportBtn.TextColor3 = COLORS.Text
    exportBtn.Font = Enum.Font.GothamBold
    exportBtn.TextSize = 15
    exportBtn.BorderSizePixel = 0
    exportBtn.Parent = page
    
    local exportBtnCorner = Instance.new("UICorner")
    exportBtnCorner.CornerRadius = UDim.new(0, 8)
    exportBtnCorner.Parent = exportBtn
    
    exportBtn.MouseButton1Click:Connect(function()
        self:ExportDump()
    end)
    
    self.DumpPage = page
end

function Shaka:CreateLogsPage()
    local page = Instance.new("ScrollingFrame")
    page.Name = "LogsPage"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 6
    page.ScrollBarImageColor3 = COLORS.Primary
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = self.ContentFrame
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.Parent = page
    
    self.LogsPage = page
    self.LogsLayout = layout
end

function Shaka:SwitchTab(tabName)
    self.CurrentTab = tabName
    
    -- Atualizar botões
    for name, btn in pairs(self.TabButtons) do
        if name == tabName then
            btn.BackgroundColor3 = COLORS.Primary
            btn.TextColor3 = COLORS.Text
        else
            btn.BackgroundColor3 = COLORS.Card
            btn.TextColor3 = COLORS.TextDim
        end
    end
    
    -- Atualizar páginas
    if self.EventsPage then self.EventsPage.Visible = (tabName == "Events") end
    if self.ExecutorPage then self.ExecutorPage.Visible = (tabName == "Executor") end
    if self.DumpPage then self.DumpPage.Visible = (tabName == "Dump") end
    if self.LogsPage then self.LogsPage.Visible = (tabName == "Logs") end
    
    -- Atualizar conteúdo
    if tabName == "Events" then
        self:RefreshEvents()
    elseif tabName == "Dump" then
        self:RefreshStats()
    elseif tabName == "Logs" then
        self:RefreshLogs()
    end
end

function Shaka:RefreshEvents()
    if not self.EventsPage then return end
    
    -- Limpar eventos antigos
    for _, child in ipairs(self.EventsPage:GetChildren()) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
    
    if #self.Events == 0 then
        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Size = UDim2.new(1, 0, 0, 100)
        emptyLabel.BackgroundColor3 = COLORS.Card
        emptyLabel.Text = "📡 Nenhum evento capturado\n\nInteraja com o jogo para começar"
        emptyLabel.TextColor3 = COLORS.TextDim
        emptyLabel.Font = Enum.Font.Gotham
        emptyLabel.TextSize = 14
        emptyLabel.BorderSizePixel = 0
        emptyLabel.Parent = self.EventsPage
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = emptyLabel
        return
    end
    
    -- Criar cards de eventos
    for i, event in ipairs(self.Events) do
        if i > 15 then break end -- Limitar exibição
        
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 120)
        card.BackgroundColor3 = COLORS.Card
        card.BorderSizePixel = 0
        card.Parent = self.EventsPage
        
        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 8)
        cardCorner.Parent = card
        
        -- Nome do evento
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -250, 0, 20)
        nameLabel.Position = UDim2.new(0, 10, 0, 8)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = string.format("📡 %s", event.Name)
        nameLabel.TextColor3 = COLORS.Primary
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 13
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Parent = card
        
        -- Tipo + Contador
        local typeLabel = Instance.new("TextLabel")
        typeLabel.Size = UDim2.new(0, 200, 0, 20)
        typeLabel.Position = UDim2.new(1, -210, 0, 8)
        typeLabel.BackgroundTransparency = 1
        typeLabel.Text = string.format("[%s] x%d", event.Type == "RemoteEvent" and "RE" or "RF", event.Count)
        typeLabel.TextColor3 = event.Type == "RemoteEvent" and COLORS.Success or COLORS.Warning
        typeLabel.TextXAlignment = Enum.TextXAlignment.Right
        typeLabel.Font = Enum.Font.GothamBold
        typeLabel.TextSize = 11
        typeLabel.Parent = card
        
        -- Path
        local pathLabel = Instance.new("TextLabel")
        pathLabel.Size = UDim2.new(1, -20, 0, 15)
        pathLabel.Position = UDim2.new(0, 10, 0, 30)
        pathLabel.BackgroundTransparency = 1
        pathLabel.Text = event.Path
        pathLabel.TextColor3 = COLORS.TextDim
        pathLabel.TextXAlignment = Enum.TextXAlignment.Left
        pathLabel.Font = Enum.Font.Code
        pathLabel.TextSize = 9
        pathLabel.TextTruncate = Enum.TextTruncate.AtEnd
        pathLabel.Parent = card
        
        -- Argumentos
        local argsLabel = Instance.new("TextLabel")
        argsLabel.Size = UDim2.new(1, -20, 0, 15)
        argsLabel.Position = UDim2.new(0, 10, 0, 48)
        argsLabel.BackgroundTransparency = 1
        argsLabel.Text = "Args: " .. FormatArguments(event.Arguments)
        argsLabel.TextColor3 = COLORS.Warning
        argsLabel.TextXAlignment = Enum.TextXAlignment.Left
        argsLabel.Font = Enum.Font.Code
        argsLabel.TextSize = 9
        argsLabel.TextTruncate = Enum.TextTruncate.AtEnd
        argsLabel.Parent = card
        
        -- Tempo
        local timeLabel = Instance.new("TextLabel")
        timeLabel.Size = UDim2.new(0, 100, 0, 15)
        timeLabel.Position = UDim2.new(0, 10, 0, 66)
        timeLabel.BackgroundTransparency = 1
        timeLabel.Text = "🕐 " .. event.Time
        timeLabel.TextColor3 = COLORS.TextDim
        timeLabel.TextXAlignment = Enum.TextXAlignment.Left
        timeLabel.Font = Enum.Font.Gotham
        timeLabel.TextSize = 9
        timeLabel.Parent = card
        
        -- Botões
        local btnFrame = Instance.new("Frame")
        btnFrame.Size = UDim2.new(1, -20, 0, 28)
        btnFrame.Position = UDim2.new(0, 10, 1, -38)
        btnFrame.BackgroundTransparency = 1
        btnFrame.Parent = card
        
        local btnLayout = Instance.new("UIListLayout")
        btnLayout.FillDirection = Enum.FillDirection.Horizontal
        btnLayout.Padding = UDim.new(0, 6)
        btnLayout.Parent = btnFrame
        
        -- Botão Replay 1x
        local replayBtn = self:CreateEventButton(btnFrame, "▶", COLORS.Success, 50)
        replayBtn.MouseButton1Click:Connect(function()
            self:ReplayEvent(event, 1)
        end)
        
        -- Botão Replay 10x
        local replay10Btn = self:CreateEventButton(btnFrame, "⚡10", COLORS.Primary, 60)
        replay10Btn.MouseButton1Click:Connect(function()
            self:ReplayEvent(event, 10)
        end)
        
        -- Botão Loop
        local loopBtn = self:CreateEventButton(btnFrame, event.IsLooping and "⏹" or "🔁", event.IsLooping and COLORS.Danger or COLORS.Warning, 50)
        loopBtn.MouseButton1Click:Connect(function()
            local isLooping = self:ToggleLoop(event)
            loopBtn.Text = isLooping and "⏹" or "🔁"
            loopBtn.BackgroundColor3 = isLooping and COLORS.Danger or COLORS.Warning
        end)
        
        -- Botão Block
        local isBlocked = self.Blocked[event.Path]
        local blockBtn = self:CreateEventButton(btnFrame, isBlocked and "✓" or "🚫", isBlocked and COLORS.Success or COLORS.Danger, 50)
        blockBtn.MouseButton1Click:Connect(function()
            self:BlockEvent(event)
            task.wait(0.1)
            self:RefreshEvents()
        end)
        
        -- Botão Copy
        local copyBtn = self:CreateEventButton(btnFrame, "📋", COLORS.Card, 50)
        copyBtn.MouseButton1Click:Connect(function()
            if setclipboard then
                setclipboard(event.Path)
                CreateLog("Path copiado!", "SUCCESS")
            end
        end)
    end
end

function Shaka:CreateEventButton(parent, text, color, width)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, width, 1, 0)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = COLORS.Text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.BorderSizePixel = 0
    btn.Parent = parent
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn
    
    return btn
end

function Shaka:RefreshStats()
    if not self.StatsText then return end
    
    local statsText = string.format(
        "📊 ESTATÍSTICAS DO SERVIDOR\n\n" ..
        "Total de Eventos: %d\n" ..
        "Remote Events: %d\n" ..
        "Remote Functions: %d\n" ..
        "Eventos Bloqueados: %d\n\n" ..
        "Place ID: %d\n" ..
        "Tempo de Execução: %.1fs",
        self.Stats.TotalCaptured,
        self.Stats.RemoteEvents,
        self.Stats.RemoteFunctions,
        self.Stats.Blocked,
        game.PlaceId,
        tick() - startTime
    )
    
    self.StatsText.Text = statsText
end

function Shaka:RefreshLogs()
    if not self.LogsPage then return end
    
    -- Limpar logs antigos
    for _, child in ipairs(self.LogsPage:GetChildren()) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
    
    if #self.Logs == 0 then
        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Size = UDim2.new(1, 0, 0, 60)
        emptyLabel.BackgroundColor3 = COLORS.Card
        emptyLabel.Text = "📝 Nenhum log"
        emptyLabel.TextColor3 = COLORS.TextDim
        emptyLabel.Font = Enum.Font.Gotham
        emptyLabel.TextSize = 13
        emptyLabel.BorderSizePixel = 0
        emptyLabel.Parent = self.LogsPage
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = emptyLabel
        return
    end
    
    -- Criar cards de logs
    for i, log in ipairs(self.Logs) do
        if i > 20 then break end
        
        local logCard = Instance.new("Frame")
        logCard.Size = UDim2.new(1, 0, 0, 35)
        logCard.BackgroundColor3 = COLORS.Card
        logCard.BorderSizePixel = 0
        logCard.Parent = self.LogsPage
        
        local logCorner = Instance.new("UICorner")
        logCorner.CornerRadius = UDim.new(0, 6)
        logCorner.Parent = logCard
        
        -- Tempo
        local timeLabel = Instance.new("TextLabel")
        timeLabel.Size = UDim2.new(0, 70, 1, 0)
        timeLabel.Position = UDim2.new(0, 8, 0, 0)
        timeLabel.BackgroundTransparency = 1
        timeLabel.Text = log.Time
        timeLabel.TextColor3 = COLORS.TextDim
        timeLabel.Font = Enum.Font.Code
        timeLabel.TextSize = 10
        timeLabel.Parent = logCard
        
        -- Tipo
        local typeColor = COLORS.Text
        if log.Type == "SUCCESS" then
            typeColor = COLORS.Success
        elseif log.Type == "ERROR" then
            typeColor = COLORS.Danger
        elseif log.Type == "WARNING" then
            typeColor = COLORS.Warning
        end
        
        local typeLabel = Instance.new("TextLabel")
        typeLabel.Size = UDim2.new(0, 70, 1, 0)
        typeLabel.Position = UDim2.new(0, 80, 0, 0)
        typeLabel.BackgroundTransparency = 1
        typeLabel.Text = log.Type
        typeLabel.TextColor3 = typeColor
        typeLabel.Font = Enum.Font.GothamBold
        typeLabel.TextSize = 9
        typeLabel.Parent = logCard
        
        -- Mensagem
        local msgLabel = Instance.new("TextLabel")
        msgLabel.Size = UDim2.new(1, -160, 1, 0)
        msgLabel.Position = UDim2.new(0, 155, 0, 0)
        msgLabel.BackgroundTransparency = 1
        msgLabel.Text = log.Message
        msgLabel.TextColor3 = COLORS.Text
        msgLabel.TextXAlignment = Enum.TextXAlignment.Left
        msgLabel.Font = Enum.Font.Gotham
        msgLabel.TextSize = 11
        msgLabel.TextTruncate = Enum.TextTruncate.AtEnd
        msgLabel.Parent = logCard
    end
end

function Shaka:MakeDraggable(frame)
    local dragging = false
    local dragInput, dragStart, startPos
    
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

function Shaka:ToggleUI()
    if not self.MainFrame then return end
    
    self.IsOpen = not self.IsOpen
    
    if self.IsOpen then
        self.MainFrame.Visible = true
        self.MainFrame.Size = UDim2.new(0, 0, 0, 0)
        
        local tween = TweenService:Create(
            self.MainFrame,
            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 850, 0, 600)}
        )
        tween:Play()
        
        task.wait(0.3)
        self:SwitchTab(self.CurrentTab)
    else
        local tween = TweenService:Create(
            self.MainFrame,
            TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In),
            {Size = UDim2.new(0, 0, 0, 0)}
        )
        tween:Play()
        
        task.wait(0.2)
        self.MainFrame.Visible = false
    end
end

function Shaka:ShowNotification(text, duration)
    duration = duration or CONFIG.NotificationDuration
    
    local notif = Instance.new("Frame")
    notif.Size = UDim2.new(0, 300, 0, 60)
    notif.Position = UDim2.new(0.5, -150, 0, -70)
    notif.BackgroundColor3 = COLORS.Success
    notif.BorderSizePixel = 0
    notif.Parent = self.ScreenGui
    
    local notifCorner = Instance.new("UICorner")
    notifCorner.CornerRadius = UDim.new(0, 10)
    notifCorner.Parent = notif
    
    local notifText = Instance.new("TextLabel")
    notifText.Size = UDim2.new(1, -20, 1, -20)
    notifText.Position = UDim2.new(0, 10, 0, 10)
    notifText.BackgroundTransparency = 1
    notifText.Text = text
    notifText.TextColor3 = COLORS.Text
    notifText.Font = Enum.Font.GothamBold
    notifText.TextSize = 13
    notifText.TextWrapped = true
    notifText.Parent = notif
    
    -- Animar entrada
    TweenService:Create(
        notif,
        TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, -150, 0, 20)}
    ):Play()
    
    -- Animar saída
    task.delay(duration, function()
        TweenService:Create(
            notif,
            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In),
            {Position = UDim2.new(0.5, -150, 0, -70)}
        ):Play()
        
        task.wait(0.3)
        notif:Destroy()
    end)
end

function Shaka:SetupKeybind()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == CONFIG.ToggleKey then
            self:ToggleUI()
        end
    end)
    
    CreateLog(string.format("Keybind configurada: [%s]", CONFIG.ToggleKey.Name), "SUCCESS")
end

-- ============================================================================
-- INICIALIZAÇÃO
-- ============================================================================
function Shaka:Initialize()
    CreateLog("Iniciando Shaka Logger Pro...", "INFO")
    
    task.wait(0.5)
    
    -- Criar UI
    self:CreateUI()
    task.wait(0.3)
    
    -- Configurar keybind
    self:SetupKeybind()
    task.wait(0.2)
    
    -- Instalar hooks
    self:InstallHooks()
    task.wait(0.5)
    
    -- Mostrar notificação
    CreateLog("✓ Shaka Logger Pro carregado com sucesso!", "SUCCESS")
    self:ShowNotification("⚡ SHAKA LOGGER PRO v4.0\nPressione [F] para abrir", 4)
    
    -- Abrir UI automaticamente
    task.wait(1)
    self:ToggleUI()
    
    print(string.format("\n[SHAKA] ✓ Carregado em %.2fs", tick() - startTime))
    print("[SHAKA] Pressione [F] para abrir/fechar")
    print("[SHAKA] Acesse via: getgenv().ShakaLogger")
end

-- ============================================================================
-- EXECUTAR
-- ============================================================================
local success, err = pcall(function()
    Shaka:Initialize()
end)

if not success then
    warn("[SHAKA] ERRO CRÍTICO:", err)
    print("[SHAKA] Falha na inicialização!")
end

return Shaka
