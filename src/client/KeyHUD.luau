--!strict
-- 열쇠 표시(오른쪽 위): 게임 중에만. 팀이 열쇠를 찾았는가(ReplicatedStorage 속성 HasKey).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local KeyHUD = {}
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "KeyHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(1, 0)
label.Position = UDim2.new(1, -24, 0, 18)
label.Size = UDim2.fromOffset(220, 28)
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamMedium
label.TextSize = 18
label.TextXAlignment = Enum.TextXAlignment.Right
label.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")

local function refresh()
	local playing = ReplicatedStorage:GetAttribute("Mode") == "Game" and ReplicatedStorage:GetAttribute("RoundState") == "Playing" and Config.Key.Required
	gui.Enabled = playing == true
	local has = ReplicatedStorage:GetAttribute("HasKey") == true
	label.Text = if has then "열쇠  있음 — 출구로" else "열쇠  없음"
	label.TextColor3 = if has then Color3.fromRGB(235, 235, 235) else Color3.fromRGB(140, 140, 140)
end

function KeyHUD.state()
	return { visible = gui.Enabled, text = label.Text }
end

for _, a in { "HasKey", "Mode", "RoundState" } do
	ReplicatedStorage:GetAttributeChangedSignal(a):Connect(refresh)
end
refresh()

return KeyHUD
