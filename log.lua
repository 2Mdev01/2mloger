-- Aviso Estilizado na Tela
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Criar a mensagem
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = PlayerGui

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 350, 0, 120)
Frame.Position = UDim2.new(0.5, -175, 0.3, -60)
Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
Frame.BorderSizePixel = 0
Frame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = Frame

local TextLabel = Instance.new("TextLabel")
TextLabel.Size = UDim2.new(1, 0, 1, 0)
TextLabel.BackgroundTransparency = 1
TextLabel.Text = "🎯 SCRIPT EXECUTADO!\n\n✅ Código carregado com sucesso!"
TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TextLabel.TextSize = 18
TextLabel.Font = Enum.Font.GothamBold
TextLabel.TextWrapped = true
TextLabel.Parent = Frame

-- Animação de entrada
Frame.Position = UDim2.new(0.5, -175, 0.2, -60)
local Tween = TweenService:Create(Frame, TweenInfo.new(0.5), {Position = UDim2.new(0.5, -175, 0.3, -60)})
Tween:Play()

-- Fazer desaparecer após 4 segundos
task.wait(4)
local TweenOut = TweenService:Create(Frame, TweenInfo.new(0.5), {Position = UDim2.new(0.5, -175, 0.2, -60)})
TweenOut:Play()

task.wait(0.5)
ScreenGui:Destroy()

print("✅ Aviso mostrado na tela!")
