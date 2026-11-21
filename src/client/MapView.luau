--!strict
-- 지도(Q): 내 음파가 닿은 곳만 그려지고, 그 스테이지가 끝날 때까지 남는다(게임 화면의 선은 그대로 사라진다).
-- 검은 바탕에 벽 윤곽을 흰 선으로, 내 위치는 빨간 칸. 출구는 음파가 닿았을 때만 표시.
-- 다른 사람의 음파는 지도에 남지 않는다(Pulses 의 own 음파만 onReach 로 들어온다).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local World = require(script.Parent:WaitForChild("SonarWorld"))

local Map = {}

local player = Players.LocalPlayer
local T = 8 -- 맵 한 칸(스터드), StageBuilder 와 같다
local LINE = 2 -- 선 굵기(픽셀)

local rows: { string } = {}
local W, H = 0, 0
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

local lines = Instance.new("Folder")
lines.Name = "Lines"
lines.Parent = canvas

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
local exitMark = square(Color3.new(1, 1, 1), 8, 2)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 24, 0, 16)
title.Size = UDim2.new(0.6, 0, 0, 24)
title.Font = Enum.Font.GothamMedium
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(150, 150, 150)
title.Text = "지도  ·  음파가 닿은 곳만 기록됩니다  ·  Q 닫기"
title.Parent = back

gui.Parent = player:WaitForChild("PlayerGui")

-- ── 격자 ──
local function at(i: number, j: number): string
	if j < 1 or j > H or i < 1 or i > W then
		return "#"
	end
	return rows[j]:sub(i, i)
end
local function isWall(i: number, j: number): boolean
	return at(i, j) == "#"
end

-- 격자 꼭짓점 (x1,y1)-(x2,y2) 사이 선(가로 또는 세로 한 칸)
local function line(x1: number, y1: number, x2: number, y2: number)
	local key = ((y1 * 1024 + x1) * 2) + (if y1 == y2 then 0 else 1)
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
	f.Parent = lines
end

local function markTile(i: number, j: number)
	local k = j * 1024 + i
	if explored[k] or isWall(i, j) or i < 1 or j < 1 or i > W or j > H then
		return
	end
	explored[k] = true
	exploredCount += 1
	if isWall(i, j - 1) then
		line(i - 1, j - 1, i, j - 1)
	end
	if isWall(i, j + 1) then
		line(i - 1, j, i, j)
	end
	if isWall(i - 1, j) then
		line(i - 1, j - 1, i - 1, j)
	end
	if isWall(i + 1, j) then
		line(i, j - 1, i, j)
	end
	if at(i, j) == "E" then
		exitMark.Position = UDim2.fromScale((i - 0.5) / W, (j - 0.5) / H)
		exitMark.Visible = true
	end
end

-- 새 스테이지: 기록을 지운다
function Map.load(stage: Instance)
	local s = stage:GetAttribute("Rows")
	rows = if type(s) == "string" then string.split(s, "/") else {}
	H = #rows
	W = if H > 0 then #rows[1] else 0
	table.clear(explored)
	table.clear(drawn)
	lines:ClearAllChildren()
	lineCount = 0
	exploredCount = 0
	exitMark.Visible = false
	aspect.AspectRatio = if H > 0 then W / H else 1
end

-- 내 음파가 끝났다: 닿은 복셀의 칸을 기록
function Map.onReach(dist: { [number]: number }, radius: number)
	if W == 0 then
		return
	end
	for idx, d in dist do
		if d <= radius then
			local c = World.cellCenter(idx)
			markTile(math.floor(c.X / T) + 1, math.floor(c.Z / T) + 1)
		end
	end
end

function Map.setOpen(v: boolean)
	isOpen = v
	gui.Enabled = v
end

function Map.toggle()
	Map.setOpen(not isOpen)
end

function Map.state()
	return { open = isOpen, explored = exploredCount, lines = lineCount, exitShown = exitMark.Visible, meShown = me.Visible }
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
	if root then
		me.Position = UDim2.fromScale(root.Position.X / (W * T), root.Position.Z / (H * T))
		me.Visible = true
	else
		me.Visible = false
	end
end)

return Map
