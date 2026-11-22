--!strict
-- 괴물에게 잡혔을 때: 그 스테이지 괴물의 얼굴(흰 선)이 화면 가득 확 튀어나오며 흔들린다(점프스케어). 약 0.9초 뒤 YOU DIED.
-- 머리 모양은 괴물(Monster.luau HeadSpec)과 같다: 1 삼각형 · 2 사각형 · 3 원 · 4 별 · 5 육각형.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local JumpScare = {}
JumpScare.count = 0
JumpScare.Duration = 0.9
JumpScare.lastKind = "monster"

local player = Players.LocalPlayer

-- 머리 좌표(가운데 0, 위가 +y). eye = {x, y, 반지름}, mouth = {반폭, 윗입술 y, 깊이}
type Spec = { eye: { number }, mouth: { number }, verts: { { number } }?, circle: number?, star: { number }?, hex: number? }
local SPECS: { Spec } = {
	{ eye = { 0.2, 0.0, 0.08 }, mouth = { 0.5, -0.25, 0.35 }, verts = { { -0.85, -0.75 }, { 0.85, -0.75 }, { 0, 0.75 } } },
	{ eye = { 0.28, 0.2, 0.09 }, mouth = { 0.5, -0.1, 0.4 }, verts = { { -0.8, -0.65 }, { 0.8, -0.65 }, { 0.8, 0.65 }, { -0.8, 0.65 } } },
	{ eye = { 0.22, 0.12, 0.09 }, mouth = { 0.45, -0.2, 0.4 }, circle = 0.6 },
	{ eye = { 0.16, 0.12, 0.065 }, mouth = { 0.3, -0.12, 0.25 }, star = { 1.0, 0.48 } },
	{ eye = { 0.26, 0.15, 0.09 }, mouth = { 0.5, -0.12, 0.38 }, hex = 0.72 },
}

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

local function draw(spec: Spec)
	for _, c in face:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local size = face.AbsoluteSize.X
	if size < 10 then
		size = math.min(back.AbsoluteSize.X, back.AbsoluteSize.Y) * 0.95
	end
	local ext = spec.circle or (spec.star and spec.star[1]) or spec.hex or 0.85
	local k = 0.46 / ext -- 머리가 화면을 거의 채운다
	local thick = math.max(4, size * 0.012)
	local function px(x: number, y: number): Vector2
		return Vector2.new((0.5 + x * k) * size, (0.5 - y * k) * size)
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
	local function ring(cx: number, cy: number, r: number, w: number?)
		local c = px(cx, cy)
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(c.X, c.Y)
		f.Size = UDim2.fromOffset(r * k * size * 2, r * k * size * 2)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = f
		local st = Instance.new("UIStroke")
		st.Color = WHITE
		st.Thickness = w or thick
		st.Parent = f
		f.Parent = face
	end
	local function poly(pts: { { number } })
		for i, a in pts do
			local b = pts[i % #pts + 1]
			line(a[1], a[2], b[1], b[2])
		end
	end
	-- 머리
	if spec.verts then
		poly(spec.verts)
	elseif spec.circle then
		ring(0, 0, spec.circle)
	elseif spec.star then
		local pts = {}
		for i = 0, 9 do
			local r = if i % 2 == 0 then spec.star[1] else spec.star[2]
			local a = math.pi / 2 + i * math.pi / 5
			table.insert(pts, { math.cos(a) * r, math.sin(a) * r })
		end
		poly(pts)
	elseif spec.hex then
		local pts = {}
		for i = 0, 5 do
			local a = i * math.pi / 3
			table.insert(pts, { math.cos(a) * spec.hex, math.sin(a) * spec.hex })
		end
		poly(pts)
	end
	-- 눈(크게 뜬 원 + 작은 눈동자)
	local ex, ey, er = spec.eye[1], spec.eye[2], spec.eye[3]
	for _, s in { -1, 1 } do
		ring(s * ex, ey, er * 1.25)
		ring(s * ex, ey, er * 0.35, thick * 0.8)
	end
	-- 이빨 드러낸 입
	local mw, my, mh = spec.mouth[1], spec.mouth[2], spec.mouth[3]
	local function arcY(x: number): number
		return my - mh * (1 - (x / mw) ^ 2) * 0.35 - mh * 0.65
	end
	line(-mw, my, mw, my)
	local prevX, prevY = -mw, my
	for i = 1, 12 do
		local x = -mw + 2 * mw * i / 12
		local y = if i == 12 then my else arcY(x)
		line(prevX, prevY, x, y)
		prevX, prevY = x, y
	end
	for i = 1, 9 do
		local x = -mw * 0.9 + 1.8 * mw * i / 10
		line(x, my, x, arcY(x), thick * 0.6)
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

-- 얼굴을 띄운다(이미 떠 있으면 무시). kind = "doppel" 이면 도플갱어 얼굴
local busy = false
function JumpScare.play(scream: (() -> ())?, kind: string?)
	if busy then
		return
	end
	busy = true
	JumpScare.count += 1
	local si = (ReplicatedStorage:GetAttribute("StageIndex") :: number?) or 1
	gui.Enabled = true
	if kind == "doppel" then
		drawDoppel()
	else
		draw(SPECS[((math.max(1, si) - 1) % #SPECS) + 1])
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
