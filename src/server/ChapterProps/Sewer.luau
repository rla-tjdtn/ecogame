--!strict
-- 챕터 3 하수도 전용 소품(타일 문자 → 함수). Stage3.luau 의 Props 줄에서 쓴다.
-- MapKit 부품만(검은 무광, 음파 윤곽선). 굵은 윤곽 위주, 소품 하나 25개 이하. 막는 소품은 보이지 않는 충돌 상자를 둔다.
--   l 맨홀 사다리(벽에 붙은 철제 사다리 + 천장 맨홀 테, 지나갈 수 있음)
--   M 원심 펌프(모터 + 펌프 몸통 + 토출관이 천장으로)       V 밸브 스탠드(기둥 + 큰 손바퀴)
--   Y 계기 제어반(둥근 압력계 줄 + 스위치)                  G 수문 승강기(문틀 + 나사봉 + 손바퀴)
--   H 협잡물 스크린(수로 칸: 물 + 비스듬한 철창, 아래층 칸)  J 정비 작업대
--   I 배관 자재 더미(굵은 관 토막을 쌓아 묶음)

local Kit = require(script.Parent.Parent.MapKit)
local Props = require(script.Parent.Parent.Props)

local Sewer = {}

local function base(ctx, i: number, j: number): Vector3
	return ctx.center(i, j) + Vector3.new(0, ctx.floorY(i, j), 0)
end

local function wallSide(ctx, i: number, j: number): Vector3?
	for _, d in { { 0, -1 }, { 1, 0 }, { -1, 0 }, { 0, 1 } } do
		if ctx.isWall(i + d[1], j + d[2]) then
			return Vector3.new(d[1], 0, d[2])
		end
	end
	return nil
end

local function model(ctx, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = ctx.props
	return m
end

local function solid(m: Instance, p: Vector3, size: Vector3)
	Kit.box(m, CFrame.new(p + Vector3.new(0, size.Y / 2, 0)), size, { invisible = true, tag = false })
end

-- l 맨홀 사다리: 벽면 사다리(두 기둥 + 가로대) 가 천장 맨홀 테까지
function Sewer.Ladder(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j) or Vector3.new(0, 0, -1)
	local across = Vector3.new(side.Z, 0, -side.X)
	local m = model(ctx, "Ladder")
	local w = p + side * (ctx.T / 2 - 0.55)
	local top = ctx.H - ctx.floorY(i, j)
	for _, s in { -1, 1 } do
		local a = w + across * (s * 0.9)
		Kit.cylinder(m, a, a + Vector3.new(0, top, 0), 0.1, { blocks = false, collide = false })
	end
	for k = 1, 9 do
		local c = w + Vector3.new(0, k * top / 10, 0)
		Kit.cylinder(m, c - across * 0.9, c + across * 0.9, 0.07, { blocks = false, collide = false })
	end
	-- 천장 맨홀 테(둥근 구멍 둘레)
	local h = w - side * 0.9 + Vector3.new(0, top - 0.2, 0)
	Kit.cylinder(m, h - Vector3.new(0, 0.3, 0), h, 1.9, { blocks = false, collide = false, rings = 2 })
end

-- M 원심 펌프: 받침 위 모터(원통) + 달팽이 몸통 + 토출관(위로, 천장 배관으로)
function Sewer.Pump(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "Pump")
	local ax = if ctx.hash(i, j, 7) > 0.5 then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
	Kit.box(m, CFrame.lookAt(p + Vector3.new(0, 0.4, 0), p + Vector3.new(0, 0.4, 0) + ax), Vector3.new(3.6, 0.8, 6.6), { name = "PumpBase" })
	-- 모터(눕힌 원통) + 냉각 띠
	local m0 = p - ax * 2.8 + Vector3.new(0, 2.4, 0)
	local m1 = p - ax * 0.2 + Vector3.new(0, 2.4, 0)
	Kit.cylinder(m, m0, m1, 1.5, { rings = 3 })
	-- 펌프 몸통(달팽이: 세운 원통)
	local body = p + ax * 1.6 + Vector3.new(0, 2.4, 0)
	local across = Vector3.new(ax.Z, 0, -ax.X)
	Kit.cylinder(m, body - across * 0.9, body + across * 0.9, 1.9, { rings = 2 })
	-- 흡입관(옆) + 토출관(위, 플랜지)
	Kit.pipe(m, body + across * 0.9, body + across * 3.6, 0.8, { 0 }, true)
	Kit.pipe(m, body + Vector3.new(0, 1.9, 0), Vector3.new(body.X, ctx.H, body.Z), 0.75, { 0.15, 0.85 }, true)
	solid(m, p, Vector3.new(6.6, 4.4, 6.6))
end

-- V 밸브 스탠드: 바닥 플랜지에서 솟은 기둥, 위에 큰 손바퀴(바큇살 넷)
function Sewer.ValveStand(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "ValveStand")
	Kit.box(m, CFrame.new(p + Vector3.new(0, 0.3, 0)), Vector3.new(2.6, 0.6, 2.6))
	Kit.cylinder(m, p + Vector3.new(0, 0.6, 0), p + Vector3.new(0, 4.4, 0), 0.45, { blocks = false })
	local hub = p + Vector3.new(0, 4.6, 0)
	Kit.cylinder(m, hub - Vector3.new(0, 0.15, 0), hub + Vector3.new(0, 0.15, 0), 2.0, { blocks = false, collide = false, rings = 1 })
	for k = 0, 1 do
		local a = k * math.pi / 2
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		Kit.cylinder(m, hub - d * 1.9, hub + d * 1.9, 0.1, { blocks = false, collide = false })
	end
	-- 바닥 아래로 내려가는 관(바닥 위로 조금 보이는 플랜지)
	Kit.pipe(m, p + Vector3.new(1.8, 0, 0), p + Vector3.new(1.8, 2.2, 0), 0.6, { 1 }, true)
	solid(m, p, Vector3.new(4.4, 5, 4.4))
end

-- Y 계기 제어반: 벽에 붙은 키 큰 함, 둥근 압력계 2x3, 스위치 줄
function Sewer.GaugePanel(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j) or Vector3.new(0, 0, -1)
	local m = model(ctx, "GaugePanel")
	local c = p + side * (ctx.T / 2 - 1.1) + Vector3.new(0, 3.4, 0)
	local cf = CFrame.lookAt(c, c - side)
	Kit.box(m, cf, Vector3.new(6.2, 6.8, 2.0))
	for a = -1, 1 do
		for b = 0, 1 do
			local g = (cf * CFrame.new(a * 1.9, 1.0 + b * 1.7, -1.0)).Position
			Kit.cylinder(m, g, g - side * 0.25, 0.65, { blocks = false, collide = false, rings = 1 })
		end
	end
	for a = -2, 2 do
		Kit.box(m, cf * CFrame.new(a * 1.0, -1.4, -1.15), Vector3.new(0.3, 0.6, 0.3), { blocks = false, collide = false })
	end
	solid(m, p + side * (ctx.T / 2 - 1.3), Vector3.new(if side.X ~= 0 then 2.6 else 6.4, 6.8, if side.X ~= 0 then 6.4 else 2.6))
end

-- G 수문 승강기: 벽 쪽 문틀(두 기둥 + 들보), 가운데 닫힌 철판 수문, 위로 솟은 나사봉 + 손바퀴
function Sewer.SluiceGate(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j) or Vector3.new(0, 0, -1)
	local across = Vector3.new(side.Z, 0, -side.X)
	local m = model(ctx, "SluiceGate")
	local c = p + side * (ctx.T / 2 - 1.2)
	for _, s in { -1, 1 } do
		local a = c + across * (s * 3.2)
		Kit.box(m, CFrame.new(a + Vector3.new(0, 4.8, 0)), Vector3.new(0.8, 9.6, 0.8))
	end
	Kit.box(m, CFrame.lookAt(c + Vector3.new(0, 9.8, 0), c + Vector3.new(0, 9.8, 0) + across), Vector3.new(1.0, 0.8, 7.2))
	local gate = c + Vector3.new(0, 3.2, 0)
	Kit.box(m, CFrame.lookAt(gate, gate - side), Vector3.new(5.6, 6.4, 0.4), { name = "Gate" })
	for k = 1, 3 do
		Kit.box(m, CFrame.lookAt(gate, gate - side) * CFrame.new(0, -3.2 + k * 1.6, -0.3), Vector3.new(5.6, 0.25, 0.2), { blocks = false, collide = false })
	end
	-- 나사봉 + 손바퀴
	local st = c + Vector3.new(0, 6.4, 0)
	Kit.cylinder(m, st, st + Vector3.new(0, 4.6, 0), 0.18, { blocks = false, collide = false })
	local hub = c - side * 0.9 + Vector3.new(0, 10.6, 0)
	Kit.cylinder(m, hub, hub - side * 0.2, 1.3, { blocks = false, collide = false, rings = 1 })
	solid(m, c, Vector3.new(if side.X ~= 0 then 2.6 else 7.4, 10, if side.X ~= 0 then 7.4 else 2.6))
end

-- H 협잡물 스크린(수로 칸): 물 + 수로를 가로지르는 비스듬한 철창(쓰레기를 걸러 낸다)
function Sewer.BarScreen(ctx, i: number, j: number)
	Props.Water(ctx, i, j)
	local c = ctx.center(i, j)
	local m = model(ctx, "BarScreen")
	-- 물길 방향: 양옆(가로)이 벽이 아니면 가로로 흐른다
	local flow = if not ctx.isWall(i - 1, j) and not ctx.isWall(i + 1, j) then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
	local across = Vector3.new(flow.Z, 0, -flow.X)
	local y0 = ctx.PIT_Y
	for k = -3, 3 do
		local a = c + across * (k * 1.05) + Vector3.new(0, y0, 0) - flow * 1.4
		Kit.cylinder(m, a, a + flow * 2.6 + Vector3.new(0, 6.4, 0), 0.1, { blocks = false })
	end
	-- 위 가로대(보행로 높이)
	local t = c + flow * 1.2 + Vector3.new(0, 0.4, 0)
	Kit.box(m, CFrame.lookAt(t, t + across), Vector3.new(0.5, 0.5, ctx.T), { blocks = false })
end

-- J 정비 작업대: 철제 작업대 + 바이스 + 벽 공구판
function Sewer.Workbench(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j) or Vector3.new(0, 0, -1)
	local m = model(ctx, "Workbench")
	local c = p + side * (ctx.T / 2 - 1.9)
	local cf = CFrame.lookAt(c, c - side)
	Kit.box(m, cf * CFrame.new(0, 3.2, 0), Vector3.new(6.8, 0.3, 3.2))
	for _, x in { -3.1, 3.1 } do
		for _, z in { -1.4, 1.4 } do
			Kit.box(m, cf * CFrame.new(x, 1.5, z), Vector3.new(0.25, 3.0, 0.25), { blocks = false })
		end
	end
	Kit.box(m, cf * CFrame.new(2.4, 3.75, -1.2), Vector3.new(1.0, 0.8, 1.2), { blocks = false })
	local board = cf * CFrame.new(0, 6.0, 1.7)
	Kit.box(m, board, Vector3.new(6.4, 3.2, 0.12), { blocks = false, collide = false })
	for k = -2, 2 do
		Kit.box(m, board * CFrame.new(k * 1.2, -0.2 + (k % 2) * 0.5, -0.15), Vector3.new(0.18, 1.3, 0.12), { blocks = false, collide = false })
	end
	solid(m, c, Vector3.new(if side.X ~= 0 then 3.4 else 7, 4, if side.X ~= 0 then 7 else 3.4))
end

-- I 배관 자재 더미: 굵은 관 토막 3+2 단(받침목 위), 고정 띠
function Sewer.PipeStack(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "PipeStack")
	local ax = if ctx.at(i - 1, j) == "I" or ctx.at(i + 1, j) == "I" then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
	local across = Vector3.new(ax.Z, 0, -ax.X)
	local half = ctx.T / 2 - 0.4
	for _, s in { -1, 1 } do
		local b = p + ax * (s * 2.4) + Vector3.new(0, 0.25, 0)
		Kit.box(m, CFrame.lookAt(b, b + across), Vector3.new(0.5, 0.5, 6.4), { blocks = false })
	end
	local r = 0.95
	for k = -1, 1 do
		local c = p + across * (k * 2 * r) + Vector3.new(0, 0.5 + r, 0)
		Kit.cylinder(m, c - ax * half, c + ax * half, r, { rings = 1 })
	end
	for k = 0, 1 do
		local c = p + across * ((k - 0.5) * 2 * r) + Vector3.new(0, 0.5 + r * 2.7, 0)
		Kit.cylinder(m, c - ax * half, c + ax * half, r, { rings = 1 })
	end
	solid(m, p, Vector3.new(6.6, 4.6, 6.6))
end

return Sewer
