--!strict
-- 로비 화면: 방 목록, 방 만들기 / 참가 / 나가기 / 시작(방장).
-- 1인칭이라 마우스가 가운데 묶여 있으므로 Tab 으로 메뉴를 열면 마우스가 풀린다(다시 Tab 이면 둘러보기).
-- 방 목록은 서버가 ReplicatedStorage 속성 "Rooms"(JSON)로, 내 방은 Player 속성 "RoomId" 로 알려 준다.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LobbyUI = {}

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RoomAction = Remotes:WaitForChild("RoomAction") :: RemoteEvent

local WHITE = Color3.fromRGB(235, 235, 235)
local GREY = Color3.fromRGB(140, 140, 140)

local gui = Instance.new("ScreenGui")
gui.Name = "Lobby"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Enabled = false

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -24, 0.5, 0)
panel.Size = UDim2.fromOffset(340, 420)
panel.BackgroundColor3 = Color3.new(0, 0, 0)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Parent = gui
local stroke = Instance.new("UIStroke")
stroke.Color = GREY
stroke.Thickness = 1
stroke.Parent = panel

local function label(text: string, y: number, size: number, color: Color3, h: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(16, y)
	l.Size = UDim2.new(1, -32, 0, h or (size + 6))
	l.Font = Enum.Font.GothamMedium
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = text
	l.Parent = panel
	return l
end

local title = label("로비 — 방", 14, 20, WHITE)
local hint = label("Tab: 메뉴 열기 (마우스)", 42, 14, GREY)
local msg = label("", 380, 14, Color3.fromRGB(226, 75, 74), 30)

local list = Instance.new("Frame")
list.BackgroundTransparency = 1
list.Position = UDim2.fromOffset(16, 70)
list.Size = UDim2.new(1, -32, 0, 230)
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local bar = Instance.new("Frame")
bar.BackgroundTransparency = 1
bar.Position = UDim2.fromOffset(16, 316)
bar.Size = UDim2.new(1, -32, 0, 44)
bar.Parent = panel
local barLayout = Instance.new("UIListLayout")
barLayout.FillDirection = Enum.FillDirection.Horizontal
barLayout.Padding = UDim.new(0, 8)
barLayout.Parent = bar

-- 메뉴가 열려 있을 때 마우스를 풀어 주는 버튼(Modal)
local modal = Instance.new("TextButton")
modal.Name = "MouseFree"
modal.Modal = true
modal.BackgroundTransparency = 1
modal.Text = ""
modal.Size = UDim2.fromOffset(0, 0)
modal.Visible = false
modal.Parent = gui

gui.Parent = player:WaitForChild("PlayerGui")

type Btn = { button: TextButton, run: () -> () }
local buttons: { [string]: Btn } = {}

local function button(parent: Instance, text: string, width: number, run: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(width, 36)
	b.BackgroundColor3 = Color3.new(0, 0, 0)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 15
	b.TextColor3 = WHITE
	b.Text = text
	b.AutoButtonColor = true
	local s = Instance.new("UIStroke")
	s.Color = WHITE
	s.Thickness = 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = b
	b.Activated:Connect(run)
	b.Parent = parent
	buttons[text] = { button = b, run = run }
	return b
end

local menuOpen = false
local message = ""
local msgUntil = 0

function LobbyUI.act(action: string, arg: any?)
	RoomAction:FireServer(action, arg)
end

local function rooms(): { any }
	local s = ReplicatedStorage:GetAttribute("Rooms")
	if type(s) ~= "string" then
		return {}
	end
	local ok, v = pcall(HttpService.JSONDecode, HttpService, s)
	return if ok and type(v) == "table" then v else {}
end

local function render()
	table.clear(buttons)
	for _, c in list:GetChildren() do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	for _, c in bar:GetChildren() do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	local myId = player:GetAttribute("RoomId")
	local mine = nil
	local all = rooms()
	for i, r in all do
		if r.id == myId then
			mine = r
		end
		local row = Instance.new("Frame")
		row.LayoutOrder = i
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 36)
		row.Parent = list
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, -86, 1, 0)
		t.Font = Enum.Font.Gotham
		t.TextSize = 14
		t.TextColor3 = if r.id == myId then WHITE else GREY
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextTruncate = Enum.TextTruncate.AtEnd
		t.Text = string.format("방 %d · %s · %d/%d%s", r.id, r.host, #r.names, r.max, if r.started then " · 시작 중" else "")
		t.Parent = row
		if r.id ~= myId and not r.started and #r.names < r.max then
			local b = button(row, "참가 " .. r.id, 78, function()
				LobbyUI.act("join", r.id)
			end)
			b.Position = UDim2.new(1, -78, 0, 0)
			b.Size = UDim2.fromOffset(78, 34)
		end
	end
	if #all == 0 then
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, 30)
		t.Font = Enum.Font.Gotham
		t.TextSize = 14
		t.TextColor3 = GREY
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Text = "열린 방이 없습니다. 방을 만들어 보세요."
		t.Parent = list
	end
	if mine then
		title.Text = string.format("방 %d — %s", mine.id, table.concat(mine.names, ", "))
		button(bar, "나가기", 100, function()
			LobbyUI.act("leave")
		end)
		if mine.hostId == player.UserId then
			button(bar, "시작", 100, function()
				LobbyUI.act("start")
			end)
		else
			local w = Instance.new("TextLabel")
			w.BackgroundTransparency = 1
			w.Size = UDim2.fromOffset(160, 36)
			w.Font = Enum.Font.Gotham
			w.TextSize = 14
			w.TextColor3 = GREY
			w.Text = "방장이 시작하기를 기다리는 중"
			w.Parent = bar
		end
	else
		title.Text = "로비 — 방"
		button(bar, "방 만들기", 140, function()
			LobbyUI.act("create")
		end)
	end
	msg.Text = if os.clock() < msgUntil then message else ""
	hint.Text = if menuOpen then "Tab: 메뉴 닫기 (둘러보기)" else "Tab: 메뉴 열기 (마우스)"
end

local function inLobby(): boolean
	return ReplicatedStorage:GetAttribute("RoundState") == "Lobby"
end

local function refresh()
	local show = inLobby()
	gui.Enabled = show
	if not show then
		menuOpen = false
	end
	modal.Visible = show and menuOpen
	if show then
		render()
	end
end

function LobbyUI.setMenu(open: boolean)
	menuOpen = open and inLobby()
	refresh()
end

function LobbyUI.message(text: string, seconds: number?)
	message = text
	msgUntil = os.clock() + (seconds or 4)
	refresh()
	task.delay((seconds or 4) + 0.05, refresh)
end

-- (테스트) 지금 보이는 버튼을 누른 것과 같게
function LobbyUI.click(text: string): boolean
	local b = buttons[text]
	if b and b.button.Visible and gui.Enabled then
		b.run()
		return true
	end
	return false
end

function LobbyUI.state()
	local names = {}
	for t in buttons do
		table.insert(names, t)
	end
	table.sort(names)
	return { visible = gui.Enabled, menuOpen = menuOpen, mouseFree = modal.Visible, rooms = #rooms(), myRoom = player:GetAttribute("RoomId"), buttons = names, title = title.Text, message = msg.Text }
end

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.Tab and inLobby() then
		LobbyUI.setMenu(not menuOpen)
	end
end)
ReplicatedStorage:GetAttributeChangedSignal("Rooms"):Connect(refresh)
ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(refresh)
player:GetAttributeChangedSignal("RoomId"):Connect(refresh)
refresh()

return LobbyUI
