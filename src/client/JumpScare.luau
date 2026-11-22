--!strict
-- 괴물에게 잡혔을 때: 그 스테이지 괴물의 얼굴(흰 선)이 화면 가득 확 튀어나오며 흔들린다(점프스케어). 약 0.9초 뒤 YOU DIED.
-- 메인 괴물 얼굴은 괴물 머리와 같은 공용 모양(Shared/MonsterFaces, 3차 시안): 1 삼각 · 2 사각 · 3 원 · 4 별 · 5 육각.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Faces = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MonsterFaces"))

local JumpScare = {}
JumpScare.count = 0
JumpScare.Duration = 0.9
JumpScare.lastKind = "monster"

local player = Players.LocalPlayer


local gui = Instance.new("ScreenGui")
gui.Name = "JumpScare"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 50
gui.Enabled = false

local back = Instance.new("Frame")
back.Size = UDim2.fromScale(1, 1)
back.BackgroundColor3 = Color3.new(0, 0, 0)
back.BorderSizePixel = 0
back.Parent = gui

local face = Instance.new("Frame")
face.Name = "Face"
face.AnchorPoint = Vector2.new(0.5, 0.5)
face.Position = UDim2.fromScale(0.5, 0.5)
face.Size = UDim2.fromScale(0.95, 0.95)
face.BackgroundTransparency = 1
face.Parent = back
local aspect = Instance.new("UIAspectRatioConstraint")
aspect.AspectRatio = 1
aspect.Parent = face
local scale = Instance.new("UIScale")
scale.Parent = face

gui.Parent = player:WaitForChild("PlayerGui")

local WHITE = Color3.new(1, 1, 1)

-- 메인 괴물: 괴물 머리와 똑같은 얼굴(공용 MonsterFaces). 기울어진 그대로 화면을 거의 채운다
local function draw(shape: number)
	for _, c in face:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local size = face.AbsoluteSize.X
	if size < 10 then
		size = math.min(back.AbsoluteSize.X, back.AbsoluteSize.Y) * 0.95
	end
	local f = Faces.build(shape)
	local c, s = math.cos(math.rad(f.deg)), math.sin(math.rad(f.deg))
	local function rot(u: number, v: number): (number, number)
		u, v = u * f.scale, v * f.scale
		return u * c - v * s, u * s + v * c
	end
	-- 얼굴 전체가 들어가는 크기(혀·침까지)
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	for _, l in f.lines do
		for _, q in l.pts do
			local x, y = rot(q[1], q[2])
			minX, minY, maxX, maxY = math.min(minX, x), math.min(minY, y), math.max(maxX, x), math.max(maxY, y)
		end
	end
	local cx, cy = (minX + maxX) / 2, (minY + maxY) / 2
	local k = 0.9 / math.max(maxX - minX, maxY - minY)
	local thick = math.max(4, size * 0.012)
	local function px(x: number, y: number): Vector2
		return Vector2.new((0.5 + (x - cx) * k) * size, (0.5 + (y - cy) * k) * size)
	end
	local function line(a: Vector2, b: Vector2, w: number, color: Color3?)
		local d = b - a
		local fr = Instance.new("Frame")
		fr.BackgroundColor3 = color or WHITE
		fr.BorderSizePixel = 0
		fr.AnchorPoint = Vector2.new(0.5, 0.5)
		fr.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
		fr.Size = UDim2.fromOffset(d.Magnitude + w, w)
		fr.Rotation = math.deg(math.atan2(d.Y, d.X))
		fr.Parent = face
	end
	for _, l in f.lines do
		local w = thick * math.clamp(l.r / 0.03, 0.4, 1)
		local n = #l.pts
		for i = 1, (if l.closed then n else n - 1) do
			local a, b = l.pts[i], l.pts[i % n + 1]
			local ax, ay = rot(a[1], a[2])
			local bx, by = rot(b[1], b[2])
			line(px(ax, ay), px(bx, by), w, l.tint) -- 이빨은 붉은색
		end
	end
	for _, e in f.circles do
		local x, y = rot(e.u, e.v)
		local p = px(x, y)
		local d = math.max(e.rad * f.scale * k * size * 2, thick * 1.5)
		local fr = Instance.new("Frame")
		fr.AnchorPoint = Vector2.new(0.5, 0.5)
		fr.Position = UDim2.fromOffset(p.X, p.Y)
		fr.Size = UDim2.fromOffset(d, d)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = fr
		if e.pupil then
			-- 눈동자: 꽉 찬 점
			fr.BackgroundColor3 = WHITE
			fr.BorderSizePixel = 0
		else
			fr.BackgroundTransparency = 1
			local st = Instance.new("UIStroke")
			st.Color = WHITE
			st.Thickness = thick * 0.8
			st.Parent = fr
		end
		fr.Parent = face
	end
end

-- 도플갱어: 둥근 머리의 빛나는 두 눈 + 머리에서 배까지 세로로 벌어진 입(양쪽 이빨), 솟은 어깨
-- (좌표는 Monster.luau 도플갱어 시안과 같은 그림에서 가져와, 머리~가슴이 화면을 채우게 맞춘다)
local function drawDoppel()
	for _, c in face:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local size = face.AbsoluteSize.X
	if size < 10 then
		size = math.min(back.AbsoluteSize.X, back.AbsoluteSize.Y) * 0.95
	end
	local thick = math.max(4, size * 0.011)
	local function px(x: number, y: number): Vector2
		-- 시안 픽셀(가운데 x=130, 화면 가운데 y=234) → 화면
		return Vector2.new((0.5 + (x - 130) / 190) * size, (0.5 + (y - 234) / 190) * size)
	end
	local function line(ax: number, ay: number, bx: number, by: number, w: number?)
		local a, b = px(ax, ay), px(bx, by)
		local d = b - a
		local f = Instance.new("Frame")
		f.BackgroundColor3 = WHITE
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
		f.Size = UDim2.fromOffset(d.Magnitude + (w or thick), w or thick)
		f.Rotation = math.deg(math.atan2(d.Y, d.X))
		f.Parent = face
	end
	local function bez(x0: number, y0: number, x1: number, y1: number, x2: number, y2: number, x3: number, y3: number, n: number, w: number?)
		local px0, py0 = x0, y0
		for i = 1, n do
			local t = i / n
			local u = 1 - t
			local x = u * u * u * x0 + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t * t * t * x3
			local y = u * u * u * y0 + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t * y3
			line(px0, py0, x, y, w)
			px0, py0 = x, y
		end
	end
	local function dot(x: number, y: number, r: number)
		local c = px(x, y)
		local f = Instance.new("Frame")
		f.BackgroundColor3 = WHITE
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(c.X, c.Y)
		f.Size = UDim2.fromOffset(r * 2 * size / 190, r * 2 * size / 190)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = f
		f.Parent = face
	end
	-- 머리
	bez(112, 186, 108, 160, 116, 146, 130, 146, 8)
	bez(130, 146, 144, 146, 152, 160, 148, 186, 8)
	bez(148, 186, 146, 198, 140, 206, 135, 207, 4)
	bez(112, 186, 114, 198, 120, 206, 125, 207, 4)
	-- 빛나는 두 눈(벌어진 입 양옆으로 밀려남)
	dot(118, 166, 4.2)
	dot(142, 166, 4.2)
	-- 어깨·목
	line(118, 204, 112, 218)
	line(142, 204, 148, 218)
	bez(112, 218, 98, 220, 86, 226, 78, 240, 4)
	bez(148, 218, 162, 220, 174, 226, 182, 240, 4)
	-- 세로로 벌어진 입(머리~배)
	bez(130, 160, 112, 192, 106, 236, 108, 270, 10)
	bez(108, 270, 110, 300, 118, 318, 130, 334, 6)
	bez(130, 334, 142, 318, 150, 300, 152, 270, 6)
	bez(152, 270, 154, 236, 148, 192, 130, 160, 10)
	-- 이빨(양쪽 가장자리에서 안쪽으로)
	local rows = { { 120, 176 }, { 116, 190 }, { 113, 204 }, { 110, 218 }, { 109, 232 }, { 108, 246 }, { 108, 260 }, { 109, 274 }, { 111, 288 }, { 115, 302 }, { 120, 316 } }
	for k, t in rows do
		local len = 7 + (k % 2) * 3
		line(t[1], t[2], t[1] + len, t[2] + 2, thick * 0.7)
		line(260 - t[1], t[2], 260 - t[1] - len, t[2] + 2, thick * 0.7)
	end
end

-- 꽃괴물: 뾰족한 꽃잎 6장(바깥 가시)이 화면 가득 펼쳐지고 가운데 작은 눈 7개
local function drawFlower()
	for _, c in face:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local size = face.AbsoluteSize.X
	if size < 10 then
		size = math.min(back.AbsoluteSize.X, back.AbsoluteSize.Y) * 0.95
	end
	local thick = math.max(4, size * 0.011)
	local function px(x: number, y: number): Vector2
		-- 꽃 가운데가 화면 가운데, 꽃잎 길이 62 가 화면 반쯤
		return Vector2.new((0.5 + x / 140) * size, (0.5 + y / 140) * size)
	end
	local function line(ax: number, ay: number, bx: number, by: number, w: number?)
		local a, b = px(ax, ay), px(bx, by)
		local d = b - a
		local fr = Instance.new("Frame")
		fr.BackgroundColor3 = WHITE
		fr.BorderSizePixel = 0
		fr.AnchorPoint = Vector2.new(0.5, 0.5)
		fr.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
		fr.Size = UDim2.fromOffset(d.Magnitude + (w or thick), w or thick)
		fr.Rotation = math.deg(math.atan2(d.Y, d.X))
		fr.Parent = face
	end
	local function bez(p0: { number }, p1: { number }, p2: { number }, p3: { number }, n: number, w: number?)
		local ax, ay = p0[1], p0[2]
		for i = 1, n do
			local t = i / n
			local u = 1 - t
			local x = u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1]
			local y = u * u * u * p0[2] + 3 * u * u * t * p1[2] + 3 * u * t * t * p2[2] + t * t * t * p3[2]
			line(ax, ay, x, y, w)
			ax, ay = x, y
		end
	end
	local function dot(x: number, y: number, r: number)
		local c = px(x, y)
		local fr = Instance.new("Frame")
		fr.BackgroundColor3 = WHITE
		fr.AnchorPoint = Vector2.new(0.5, 0.5)
		fr.Position = UDim2.fromOffset(c.X, c.Y)
		fr.Size = UDim2.fromOffset(r * 2 * size / 140, r * 2 * size / 140)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = fr
		fr.Parent = face
	end
	for k = 0, 5 do
		local a = math.rad(k * 60 + 30)
		local function R(x: number, y: number): { number }
			return { x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a) }
		end
		bez(R(-4, -6), R(-10, -24), R(-8, -46), R(0, -62), 8)
		bez(R(0, -62), R(8, -46), R(10, -24), R(4, -6), 8)
		local m0, m1 = R(0, -14), R(0, -52)
		line(m0[1], m0[2], m1[1], m1[2], thick * 0.6)
		for _, t in { { 6, -30, 11, -32 }, { 6, -40, 11, -43 }, { -6, -30, -11, -32 }, { -6, -40, -11, -43 } } do
			local q0, q1 = R(t[1], t[2]), R(t[3], t[4])
			line(q0[1], q0[2], q1[1], q1[2], thick * 0.7)
		end
	end
	for _, e in { { 0, 0, 3.4 }, { -8, -6, 2.3 }, { 8, -6, 2.3 }, { -10, 4, 2.1 }, { 10, 4, 2.1 }, { -3, 10, 1.8 }, { 3, 10, 1.8 } } do
		dot(e[1], e[2], e[3])
	end
end

-- 얼굴을 띄운다(이미 떠 있으면 무시). kind = "doppel" 이면 도플갱어 얼굴, "flower" 면 꽃괴물
local busy = false
function JumpScare.play(scream: (() -> ())?, kind: string?)
	if busy then
		return
	end
	busy = true
	JumpScare.count += 1

	gui.Enabled = true
	if kind == "doppel" then
		drawDoppel()
	elseif kind == "flower" then
		drawFlower()
	else
		draw(Faces.BONE)
	end
	JumpScare.lastKind = kind or "monster"
	if scream then
		task.spawn(scream)
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		-- 확 다가온다(0.12초) → 세게 흔들림 → 살짝 커지며 사라진다
		local s = if t < 0.12 then 0.35 + (t / 0.12) * 0.9 else 1.25 + t * 0.15
		scale.Scale = s
		local shake = if t < JumpScare.Duration * 0.8 then 0.025 else 0.008
		face.Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * shake, 0.5 + (math.random() - 0.5) * shake)
		back.BackgroundColor3 = if t < 0.05 or (t > 0.25 and t < 0.29) then Color3.fromRGB(60, 60, 60) else Color3.new(0, 0, 0)
		if t >= JumpScare.Duration then
			conn:Disconnect()
			gui.Enabled = false
			face.Position = UDim2.fromScale(0.5, 0.5)
			busy = false
		end
	end)
end

function JumpScare.state()
	return { count = JumpScare.count, showing = gui.Enabled, kind = JumpScare.lastKind }
end

return JumpScare
