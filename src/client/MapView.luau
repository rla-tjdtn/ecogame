--!strict
-- 지도(Q): 나와 팀원의 음파가 닿은 곳이 그려지고, 그 스테이지가 끝날 때까지 남는다(게임 화면의 선은 그대로 사라진다).
-- 검은 바탕에 벽 윤곽을 흰 선으로, 내 위치는 빨간 칸, 팀원은 흰 테두리 칸. 출구는 음파가 닿았을 때만 표시.
-- 2층 건물(스테이지 속성 Rows2, 1층과 같은 크기)은 1층·2층 지도를 따로 그린다: 지금 서 있는 층이 보이고, 위쪽 "1층 / 2층" 버튼으로 바꿔 본다.
-- 칸 번호: 행*1024 + 열, 2층 칸은 +100000(서버 팀 공유도 같은 번호).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local World = require(script.Parent:WaitForChild("SonarWorld"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- 팀 지도 공유: 내가 새로 밝힌 칸을 서버에 보내고, 서버가 모은 팀 전체 기록을 받는다(멀리 있는 팀원·다시 살아남·재접속도 같은 지도)
local MapShare = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MapShare") :: RemoteEvent
local currentBuild: number? = nil

local Map = {}

local player = Players.LocalPlayer
local T = 8 -- 맵 한 칸(스터드), StageBuilder 와 같다
local LINE = 2 -- 선 굵기(픽셀)

local rows: { string } = {}
local floorRows: { { string } } = { {}, {} } -- [1] 1층, [2] 2층(없으면 빈 표)
local hasUpper = false
local viewFloor = 1 -- 지금 보여 주는 층
local manualFloor = false -- 버튼으로 층을 골랐는가(지도를 다시 열면 내 층으로)
local exitFloor = 1
local W, H = 0, 0
local UPPER_Y = 9 -- 이 높이(스터드)보다 위면 2층(2층 바닥 12)
local explored: { [number]: boolean } = {}
local drawn: { [number]: boolean } = {}
local lineCount = 0
local exploredCount = 0
local isOpen = false

-- ── 화면 ──
local gui = Instance.new("ScreenGui")
gui.Name = "SonarMap"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Enabled = false

local back = Instance.new("Frame")
back.Name = "Back"
back.Size = UDim2.fromScale(1, 1)
back.BackgroundColor3 = Color3.new(0, 0, 0)
back.BackgroundTransparency = 0.04
back.BorderSizePixel = 0
back.Parent = gui

local canvas = Instance.new("Frame")
canvas.Name = "Canvas"
canvas.AnchorPoint = Vector2.new(0.5, 0.5)
canvas.Position = UDim2.fromScale(0.5, 0.52)
canvas.Size = UDim2.fromScale(0.9, 0.86)
canvas.BackgroundTransparency = 1
canvas.Parent = back
local aspect = Instance.new("UIAspectRatioConstraint")
aspect.AspectRatio = 1
aspect.Parent = canvas

local floorLines: { Folder } = {}
for f = 1, 2 do
	local fo = Instance.new("Folder")
	fo.Name = "Lines" .. f
	fo.Parent = canvas
	floorLines[f] = fo
end

local function square(color: Color3, px: number, z: number): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(px, px)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = z
	f.Visible = false
	f.Parent = canvas
	return f
end
local me = square(Color3.fromRGB(226, 75, 74), 10, 3)
-- 내가 바라보는 방향: 내 칸 가운데에서 앞쪽으로 퍼지는 반투명 원뿔(시야, 약 70°). 멀어질수록 흐려진다.
-- 가운데를 축으로 도는 투명 틀(look) 안에, 가운데에서 뻗는 가는 빛줄기를 부채꼴로 겹쳐 그린다
local look = Instance.new("Frame")
look.Name = "Look"
look.AnchorPoint = Vector2.new(0.5, 0.5)
look.Size = UDim2.fromOffset(110, 110)
look.BackgroundTransparency = 1
look.ZIndex = 2
look.Visible = false
look.Parent = canvas
do
	local CONE = Color3.fromRGB(226, 75, 74)
	local HALF = 35 -- 원뿔 반각(도)
	local RAYS = 15
	for k = 0, RAYS - 1 do
		local ang = -HALF + (2 * HALF) * k / (RAYS - 1)
		local holder = Instance.new("Frame")
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(0.5, 0.5)
		holder.Size = UDim2.fromScale(1, 1)
		holder.BackgroundTransparency = 1
		holder.Rotation = ang
		holder.ZIndex = 2
		holder.Parent = look
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.new(0.5, 0, 0, 5)
		ray.BackgroundColor3 = CONE
		ray.BorderSizePixel = 0
		ray.ZIndex = 2
		ray.Parent = holder
		-- 가까울수록 진하고 멀수록 사라진다(빛줄기가 겹쳐 가운데가 더 진해 보이게 한 줄은 꽤 투명하게)
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.72), NumberSequenceKeypoint.new(0.6, 0.85), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = ray
	end
end
-- 팀원 표시(흰 테두리 칸), 필요한 만큼 만든다
local mates: { Frame } = {}
local function mateMark(i: number): Frame
	local f = mates[i]
	if not f then
		f = square(Color3.new(0, 0, 0), 10, 3)
		local st = Instance.new("UIStroke")
		st.Color = Color3.new(1, 1, 1)
		st.Thickness = 2
		st.Parent = f
		mates[i] = f
	end
	return f
end
local exitMark = square(Color3.new(1, 1, 1), 8, 2)
-- 마지막 열쇠 힌트(노란 마름모): ReplicatedStorage 속성 KeyHintPos(팀 공유)
local keyMark = square(Color3.fromRGB(239, 190, 70), 11, 4)
keyMark.Rotation = 45

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 24, 0, 16)
title.Size = UDim2.new(0.6, 0, 0, 24)
title.Font = Enum.Font.GothamMedium
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(150, 150, 150)
title.Text = "지도  ·  나와 팀원의 음파가 닿은 곳이 기록됩니다  ·  Q 닫기"
title.Parent = back

-- 층 버튼(2층 건물일 때만)
local floorButtons: { TextButton } = {}
local function setView(f: number)
	viewFloor = f
	for k = 1, 2 do
		floorLines[k].Parent = if k == f then canvas else nil
		local b = floorButtons[k]
		if b then
			b.BackgroundColor3 = if k == f then Color3.fromRGB(230, 230, 230) else Color3.fromRGB(30, 30, 30)
			b.TextColor3 = if k == f then Color3.new(0, 0, 0) else Color3.fromRGB(170, 170, 170)
		end
	end
end
for f = 1, 2 do
	local b = Instance.new("TextButton")
	b.Name = "Floor" .. f
	b.AnchorPoint = Vector2.new(1, 0)
	b.Position = UDim2.new(1, -24 - (2 - f) * 76, 0, 12)
	b.Size = UDim2.fromOffset(68, 30)
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 16
	b.Text = f .. "층"
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Visible = false
	b.Parent = back
	local cr = Instance.new("UICorner")
	cr.CornerRadius = UDim.new(0, 6)
	cr.Parent = b
	b.Activated:Connect(function()
		manualFloor = true
		setView(f)
	end)
	floorButtons[f] = b
end
local floorLabel = Instance.new("TextLabel")
floorLabel.BackgroundTransparency = 1
floorLabel.AnchorPoint = Vector2.new(0.5, 0)
floorLabel.Position = UDim2.new(0.5, 0, 0, 14)
floorLabel.Size = UDim2.fromOffset(200, 28)
floorLabel.Font = Enum.Font.GothamBold
floorLabel.TextSize = 22
floorLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
floorLabel.Text = ""
floorLabel.Parent = back
local function myFloor(y: number): number
	return if hasUpper and y > UPPER_Y then 2 else 1
end

gui.Parent = player:WaitForChild("PlayerGui")

-- ── 격자 ──
local function at(i: number, j: number, f: number?): string
	local rs = floorRows[f or 1]
	if j < 1 or j > H or i < 1 or i > W or not rs[j] then
		return "#"
	end
	return rs[j]:sub(i, i)
end
-- (2층의 계단 구멍 o 도 지도에서는 벽처럼 윤곽을 친다)
local function isWall(i: number, j: number, f: number?): boolean
	local c = at(i, j, f)
	return c == "#" or c == "o"
end

-- 격자 꼭짓점 (x1,y1)-(x2,y2) 사이 선(가로 또는 세로 한 칸)
local function line(x1: number, y1: number, x2: number, y2: number, fl: number)
	local key = ((y1 * 1024 + x1) * 2) + (if y1 == y2 then 0 else 1) + (fl - 1) * 1000000
	if drawn[key] then
		return
	end
	drawn[key] = true
	lineCount += 1
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BorderSizePixel = 0
	if y1 == y2 then
		f.Position = UDim2.new(x1 / W, -LINE / 2, y1 / H, -LINE / 2)
		f.Size = UDim2.new((x2 - x1) / W, LINE, 0, LINE)
	else
		f.Position = UDim2.new(x1 / W, -LINE / 2, y1 / H, -LINE / 2)
		f.Size = UDim2.new(0, LINE, (y2 - y1) / H, LINE)
	end
	f.Parent = floorLines[fl]
end

local function markTile(i: number, j: number, f: number?): boolean
	local fl = f or 1
	if fl == 2 and not hasUpper then
		return false
	end
	local k = j * 1024 + i + (fl - 1) * 100000
	if explored[k] or isWall(i, j, fl) or i < 1 or j < 1 or i > W or j > H then
		return false
	end
	explored[k] = true
	exploredCount += 1
	if isWall(i, j - 1, fl) then
		line(i - 1, j - 1, i, j - 1, fl)
	end
	if isWall(i, j + 1, fl) then
		line(i - 1, j, i, j, fl)
	end
	if isWall(i - 1, j, fl) then
		line(i - 1, j - 1, i - 1, j, fl)
	end
	if isWall(i + 1, j, fl) then
		line(i, j - 1, i, j, fl)
	end
	if at(i, j, fl) == "E" then
		exitMark.Position = UDim2.fromScale((i - 0.5) / W, (j - 0.5) / H)
		exitMark.Visible = true
		exitFloor = fl
	end
	return true
end
-- 칸 번호(서버 팀 공유) → 칸 표시
local function markKey(k: number): boolean
	local fl = if k >= 100000 then 2 else 1
	local r = k % 100000
	return markTile(r % 1024, r // 1024, fl)
end

-- 새 스테이지: 기록을 지운다
function Map.load(stage: Instance)
	local s = stage:GetAttribute("Rows")
	rows = if type(s) == "string" then string.split(s, "/") else {}
	local s2 = stage:GetAttribute("Rows2")
	hasUpper = type(s2) == "string"
	floorRows = { rows, if type(s2) == "string" then string.split(s2, "/") else {} }
	H = #rows
	W = if H > 0 then #rows[1] else 0
	table.clear(explored)
	table.clear(drawn)
	for f = 1, 2 do
		floorLines[f]:ClearAllChildren()
		floorButtons[f].Visible = hasUpper
	end
	floorLabel.Text = ""
	exitFloor = 1
	manualFloor = false
	setView(1)
	lineCount = 0
	exploredCount = 0
	exitMark.Visible = false
	aspect.AspectRatio = if H > 0 then W / H else 1
	-- 팀이 이미 밝힌 칸을 서버에서 받아 온다(다시 살아나거나 다시 들어와도 지도가 이어진다)
	currentBuild = stage:GetAttribute("BuildId") :: number?
	MapShare:FireServer("sync")
end

-- 서버가 보낸 팀원 기록(같은 스테이지일 때만)
MapShare.OnClientEvent:Connect(function(data: any)
	if type(data) ~= "table" or data.build ~= currentBuild or type(data.tiles) ~= "table" or W == 0 then
		return
	end
	for _, k in data.tiles do
		if type(k) == "number" then
			markKey(k)
		end
	end
end)

-- 내 음파가 끝났다: 닿은 복셀의 칸을 기록
function Map.onReach(dist: { [number]: number }, radius: number)
	if W == 0 then
		return
	end
	local fresh = {}
	for idx, d in dist do
		if d <= radius then
			local c = World.cellCenter(idx)
			local i, j = math.floor(c.X / T) + 1, math.floor(c.Z / T) + 1
			local fl = myFloor(c.Y)
			if markTile(i, j, fl) then
				table.insert(fresh, j * 1024 + i + (fl - 1) * 100000)
			end
		end
	end
	-- 새로 밝힌 칸을 팀에 알린다
	if #fresh > 0 and currentBuild then
		MapShare:FireServer({ build = currentBuild, tiles = fresh })
	end
end

function Map.setOpen(v: boolean)
	isOpen = v
	gui.Enabled = v
	if v then
		manualFloor = false -- 열 때는 내가 서 있는 층부터
	end
end

function Map.toggle()
	Map.setOpen(not isOpen)
end

function Map.state()
	local shown = 0
	for _, f in mates do
		if f.Visible then
			shown += 1
		end
	end
	return { open = isOpen, explored = exploredCount, lines = lineCount, exitShown = exitMark.Visible, meShown = me.Visible, matesShown = shown, floors = if hasUpper then 2 else 1, viewFloor = viewFloor }
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q then
		Map.toggle()
	end
end)

RunService.RenderStepped:Connect(function()
	if not isOpen or W == 0 then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	-- 보여 줄 층: 버튼으로 고르지 않았으면 내가 서 있는 층
	if hasUpper and root and not manualFloor then
		local f = myFloor(root.Position.Y)
		if f ~= viewFloor then
			setView(f)
		end
	end
	floorLabel.Text = if hasUpper then viewFloor .. "층" else ""
	exitMark.BackgroundTransparency = if exitFloor == viewFloor then 0 else 1
	local kp = ReplicatedStorage:GetAttribute("KeyHintPos")
	if typeof(kp) == "Vector3" and ReplicatedStorage:GetAttribute("HasKey") ~= true and myFloor(kp.Y) == viewFloor then
		keyMark.Position = UDim2.fromScale(kp.X / (W * T), kp.Z / (H * T))
		keyMark.Visible = true
	else
		keyMark.Visible = false
	end
	if root and myFloor(root.Position.Y) == viewFloor then
		me.Position = UDim2.fromScale(root.Position.X / (W * T), root.Position.Z / (H * T))
		me.Visible = true
		-- 바라보는 방향(카메라가 보는 쪽, 지도는 X → 오른쪽, Z → 아래)
		local cam = workspace.CurrentCamera
		local lv = if cam then cam.CFrame.LookVector else root.CFrame.LookVector
		local flat = Vector2.new(lv.X, lv.Z)
		if flat.Magnitude > 0.05 then
			look.Position = me.Position
			look.Rotation = math.deg(math.atan2(flat.Y, flat.X))
			look.Visible = true
		end
	else
		me.Visible = false
		look.Visible = false
	end
	-- 살아 있는 팀원(같은 게임의 다른 플레이어)
	local n = 0
	for _, p in Players:GetPlayers() do
		if p ~= player and p:GetAttribute("Status") == "Alive" then
			local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r and myFloor(r.Position.Y) == viewFloor then
				n += 1
				local f = mateMark(n)
				f.Position = UDim2.fromScale(r.Position.X / (W * T), r.Position.Z / (H * T))
				f.Visible = true
			end
		end
	end
	for i = n + 1, #mates do
		mates[i].Visible = false
	end
end)

return Map
