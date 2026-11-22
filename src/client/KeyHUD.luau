--!strict
-- 오른쪽 위 표시(게임 중에만): 열쇠(팀이 찾았는가, ReplicatedStorage 속성 HasKey), 목숨(내 Lives, 스테이지마다 3개).
-- 위쪽 가운데: 안전 구역(시작 방) 안에 있으면 "안전 구역" 표시.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Shared.Config)

local KeyHUD = {}
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "KeyHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5

local function makeLabel(y: number, size: number): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(1, 0)
	l.Position = UDim2.new(1, -24, 0, y)
	l.Size = UDim2.fromOffset(240, size + 10)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextSize = size
	l.TextXAlignment = Enum.TextXAlignment.Right
	l.Parent = gui
	return l
end
local label = makeLabel(18, 18)
local livesLabel = makeLabel(46, 18)
local hintLabel = makeLabel(74, 15) -- (마지막 열쇠 힌트 안내)
hintLabel.TextColor3 = Color3.fromRGB(239, 200, 110)
hintLabel.Visible = false

local safeLabel = Instance.new("TextLabel")
safeLabel.AnchorPoint = Vector2.new(0.5, 0)
safeLabel.Position = UDim2.new(0.5, 0, 0, 18)
safeLabel.Size = UDim2.fromOffset(420, 26)
safeLabel.BackgroundTransparency = 1
safeLabel.Font = Enum.Font.GothamMedium
safeLabel.TextSize = 16
safeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
safeLabel.TextTransparency = 0.15
safeLabel.Text = "안전 구역  —  괴물이 들어오지 못한다"
safeLabel.Visible = false
safeLabel.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")

local function playing(): boolean
	return ReplicatedStorage:GetAttribute("Mode") == "Game" and ReplicatedStorage:GetAttribute("RoundState") == "Playing"
end

local function refresh()
	gui.Enabled = playing()
	label.Visible = Config.Key.Required
	local has = ReplicatedStorage:GetAttribute("HasKey") == true
	local found = (ReplicatedStorage:GetAttribute("Keys") :: number?) or 0
	local need = (ReplicatedStorage:GetAttribute("KeysNeeded") :: number?) or 1
	-- (팀 공유: 누가 찾든 같은 수)
	label.Text = if has then string.format("열쇠  %d/%d — 출구로", found, need) else string.format("열쇠  %d/%d", found, need)
	label.TextColor3 = if has then Color3.fromRGB(235, 235, 235) else Color3.fromRGB(140, 140, 140)
	-- 목숨: 남은 것은 ♥, 잃은 것은 ♡
	local lives = (player:GetAttribute("Lives") :: number?) or Config.Lives.PerStage
	local hearts = {}
	for i = 1, Config.Lives.PerStage do
		table.insert(hearts, if i <= lives then "♥" else "♡")
	end
	livesLabel.Text = "목숨  " .. table.concat(hearts, " ")
	livesLabel.TextColor3 = if lives <= 1 then Color3.fromRGB(230, 120, 120) else Color3.fromRGB(220, 220, 220)
end

-- 안전 구역 칸(스테이지 폴더 속성 SafeTiles: "x,y;x,y;…")
local safeSet: { [string]: boolean } = {}
local safeSrc: string? = nil
local function inSafe(pos: Vector3): boolean
	local stage = workspace:FindFirstChild("Stage")
	local s = stage and stage:GetAttribute("SafeTiles")
	if type(s) ~= "string" then
		return false
	end
	if s ~= safeSrc then
		safeSrc = s
		table.clear(safeSet)
		for _, k in string.split(s, ";") do
			safeSet[k] = true
		end
	end
	return safeSet[math.floor(pos.X / 8) .. "," .. math.floor(pos.Z / 8)] == true
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.2 then
		return
	end
	acc = 0
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	safeLabel.Visible = Config.SafeZone.Enabled and playing() and root ~= nil and player:GetAttribute("Status") == "Alive" and inSafe(root.Position)
end)

-- 마지막 열쇠 힌트: 준비되면(서버 KeyHintReady) H(휴대폰은 힌트 버튼)로 그 상자 위치를 팀 지도에 표시
local KeyHint = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("KeyHint") :: RemoteEvent
function KeyHUD.hintAvailable(): boolean
	return playing()
		and ReplicatedStorage:GetAttribute("KeyHintReady") == true
		and ReplicatedStorage:GetAttribute("HasKey") ~= true
		and ReplicatedStorage:GetAttribute("KeyHintPos") == nil
		and player:GetAttribute("Status") == "Alive"
end
function KeyHUD.requestHint()
	if KeyHUD.hintAvailable() then
		KeyHint:FireServer()
	end
end
local function refreshHint()
	local shown = ReplicatedStorage:GetAttribute("KeyHintPos") ~= nil and ReplicatedStorage:GetAttribute("HasKey") ~= true
	if KeyHUD.hintAvailable() then
		hintLabel.Text = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "힌트 버튼 — 마지막 열쇠 위치 보기" else "H — 마지막 열쇠 힌트 보기"
		hintLabel.Visible = true
	elseif shown and playing() then
		hintLabel.Text = "마지막 열쇠 위치가 지도(Q)에 표시됨"
		hintLabel.Visible = true
	else
		hintLabel.Visible = false
	end
end
for _, a in { "KeyHintReady", "KeyHintPos" } do
	ReplicatedStorage:GetAttributeChangedSignal(a):Connect(refreshHint)
end
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.H then
		KeyHUD.requestHint()
	end
end)

function KeyHUD.state()
	return { visible = gui.Enabled, text = label.Text, lives = livesLabel.Text, safe = safeLabel.Visible, hint = hintLabel.Visible and hintLabel.Text or nil }
end

for _, a in { "HasKey", "Keys", "KeysNeeded", "Mode", "RoundState" } do
	ReplicatedStorage:GetAttributeChangedSignal(a):Connect(refresh)
	ReplicatedStorage:GetAttributeChangedSignal(a):Connect(refreshHint)
end
player:GetAttributeChangedSignal("Status"):Connect(refreshHint)
refreshHint()
player:GetAttributeChangedSignal("Lives"):Connect(refresh)
refresh()

return KeyHUD
