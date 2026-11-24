--!strict
-- 챕터 3 하수도 전용 소품(타일 문자 → 함수). Stage3.luau 의 Props 줄에서 쓴다.
-- MapKit 부품만(검은 무광, 음파 윤곽선). 굵은 윤곽 위주, 소품 하나 25개 이하. 막는 소품은 보이지 않는 충돌 상자를 둔다.
--   w 수로(물 + 터널이면 세 칸마다 벽에서 벽까지 아치 갈비: 간선 5칸 폭·지선 3칸 폭 모두)     Q 낙차 유입관(벽·천장 관에서 떨어지는 오수, 물 칸)
--   K 배관 다리(수로 위를 가로지르는 굵은 관 — 랜드마크, 물 칸)    U 월류 위어(수로를 막은 낮은 둑, 물 칸)
--   l 맨홀 사다리(벽에 붙은 철제 사다리 + 천장 맨홀 테, 지나갈 수 있음)    R 맨홀 수직갱(바닥 갱구 + 천장 원통, 막힘)
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

-- ── 물길 칸(아래층 높이, Stage3 의 PitTiles) ──
local WATERY = { w = true, H = true, Q = true, U = true, K = true, b = true }
local function watery(ctx, i: number, j: number): boolean
	return WATERY[ctx.at(i, j)] == true
end
-- 물 흐르는 방향과 직각(터널 가로) 방향. 모퉁이·홀이면 nil
local function acrossOf(ctx, i: number, j: number): Vector3?
	local fx = watery(ctx, i - 1, j) or watery(ctx, i + 1, j)
	local fz = watery(ctx, i, j - 1) or watery(ctx, i, j + 1)
	if fx and not fz then
		return Vector3.new(0, 0, 1)
	elseif fz and not fx then
		return Vector3.new(1, 0, 0)
	end
	return nil
end
-- 가로 방향 양쪽 벽까지(칸 수, 4칸 안). 터널이 아니면(홀) nil
local function tunnelSpan(ctx, i: number, j: number, across: Vector3): (number?, number?)
	local function reach(s: number): number?
		for d = 1, 4 do
			if ctx.isWall(i + across.X * s * d, j + across.Z * s * d) then
				return d
			end
		end
		return nil
	end
	return reach(-1), reach(1)
end

-- w 수로: 얕은 물 + 터널이면 세 칸마다 벽에서 벽까지 벽돌 아치 갈비(간선 5칸 폭은 넓고 낮은 아치, 지선 3칸 폭은 둥근 아치).
--   갈비는 충돌·가림이 없고, 벽 쪽 발치도 보행로 머리 위(6.5 스터드)에서 시작한다: 보행로 길찾기를 막지 않는다
function Sewer.Channel(ctx, i: number, j: number)
	Props.Water(ctx, i, j)
	if (i + j) % 3 ~= 0 then
		return
	end
	local across = acrossOf(ctx, i, j)
	if not across then
		return
	end
	local a, b = tunnelSpan(ctx, i, j, across)
	if not a or not b then
		return
	end
	local T = ctx.T
	local c = ctx.center(i, j) + across * ((b - a) * T / 2)
	local half = (a + b - 1) * T / 2 - 0.3
	local spring = 6.5
	local rise = math.max(1.5, math.min(7.0, ctx.H - spring - 0.6))
	local m = model(ctx, "ArchRib")
	local prev: Vector3? = nil
	local N = 8
	for k = 0, N do
		local t = math.pi * k / N
		local p = c + across * (half * math.cos(t)) + Vector3.new(0, spring + rise * math.sin(t), 0)
		if prev then
			local mid = (prev + p) / 2
			Kit.box(m, CFrame.lookAt(mid, p), Vector3.new(0.8, 0.6, (p - prev).Magnitude + 0.15), { collide = false, blocks = false })
		end
		prev = p
	end
end

-- Q 낙차 유입관: 물 + 벽에서 튀어나온 큰 관 입구(플랜지) + 수로로 떨어지는 오수 기둥 + 물보라 테.
--   벽이 없는 곳(저류조 한가운데)은 천장에서 내려온 관에서 떨어진다
function Sewer.DropInlet(ctx, i: number, j: number)
	Props.Water(ctx, i, j)
	local c = ctx.center(i, j)
	local m = model(ctx, "DropInlet")
	local side = wallSide(ctx, i, j)
	local mouth: Vector3
	if side then
		local wallP = c + side * (ctx.T / 2) + Vector3.new(0, 5.5, 0)
		mouth = wallP - side * 2.6
		Kit.cylinder(m, wallP, mouth, 1.7, { rings = 2 })
		Kit.cylinder(m, mouth + side * 0.2, mouth - side * 0.15, 2.15, { blocks = false, collide = false, rings = 1 })
		mouth -= side * 1.4 + Vector3.new(0, 1.4, 0)
	else
		local top = c + Vector3.new(0, ctx.H, 0)
		mouth = c + Vector3.new(0, 8.5, 0)
		Kit.cylinder(m, top, mouth, 1.6, { rings = 2 })
		Kit.cylinder(m, mouth + Vector3.new(0, 0.2, 0), mouth - Vector3.new(0, 0.15, 0), 2.1, { blocks = false, collide = false, rings = 1 })
	end
	local water = Vector3.new(mouth.X, c.Y + ctx.PIT_Y + 1.2, mouth.Z)
	Kit.cylinder(m, mouth, water, 0.9, { blocks = false, collide = false })
	Kit.cylinder(m, water, water + Vector3.new(0, 0.12, 0), 2.6, { blocks = false, collide = false, rings = 2 })
end

-- K 배관 다리(랜드마크): 물 + 수로 위를 벽에서 벽까지 가로지르는 굵은 관(보행로 머리 위 높이 — 밑으로 걸어 지나간다) + 매달이 띠 둘 + 플랜지
function Sewer.PipeBridge(ctx, i: number, j: number)
	Props.Water(ctx, i, j)
	local across = acrossOf(ctx, i, j) or Vector3.new(1, 0, 0)
	local a, b = tunnelSpan(ctx, i, j, across)
	local T = ctx.T
	local aa, bb = a or 3, b or 3
	local c = ctx.center(i, j) + across * ((bb - aa) * T / 2) + Vector3.new(0, math.min(9.0, ctx.H - 3.0), 0)
	local half = (aa + bb - 1) * T / 2 - 0.2
	local m = model(ctx, "PipeBridge")
	Kit.cylinder(m, c - across * half, c + across * half, 1.5, { rings = 3, collide = false })
	for _, s in { -1, 1 } do
		local f = c + across * (s * T * 0.5)
		Kit.cylinder(m, f - across * 0.2, f + across * 0.2, 1.95, { blocks = false, collide = false })
		local hanger = c + across * (s * (T / 2 + 2.0)) + Vector3.new(0, 2.4, 0)
		Kit.box(m, CFrame.new(hanger), Vector3.new(0.3, 3.2, 0.3), { blocks = false, collide = false })
	end
end

-- U 월류 위어: 물 + 수로를 가로막은 낮은 콘크리트 둑(보행로 바로 아래까지) + 수위 눈금 막대
function Sewer.Weir(ctx, i: number, j: number)
	Props.Water(ctx, i, j)
	local across = acrossOf(ctx, i, j) or Vector3.new(1, 0, 0)
	local c = ctx.center(i, j)
	local m = model(ctx, "Weir")
	local wallC = c + Vector3.new(0, ctx.PIT_Y + 2.1, 0)
	Kit.box(m, CFrame.lookAt(wallC, wallC + Vector3.new(across.Z, 0, across.X)), Vector3.new(ctx.T, 4.2, 1.2), { name = "Weir" })
	local staff = c + Vector3.new(across.Z, 0, across.X) * 1.0 + across * 2.6
	Kit.box(m, CFrame.new(staff + Vector3.new(0, ctx.PIT_Y + 4.5, 0)), Vector3.new(0.3, 9, 0.3), { blocks = false, collide = false, axis = "Y" })
end

-- R 맨홀 수직갱: 바닥의 둥근 갱구(턱 + 막는 충돌) + 천장으로 솟은 원통 갱(지상 맨홀까지)
function Sewer.ManholeShaft(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "ManholeShaft")
	Kit.cylinder(m, p, p + Vector3.new(0, 0.9, 0), 3.2, { rings = 2 })
	Kit.cylinder(m, p + Vector3.new(0, 0.9, 0), p + Vector3.new(0, 1.0, 0), 2.6, { blocks = false, collide = false, rings = 1 })
	Kit.cylinder(m, p + Vector3.new(0, 9.0, 0), p + Vector3.new(0, ctx.H, 0), 2.8, { rings = 2 })
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		local q = p + Vector3.new(math.cos(a) * 3.0, 0, math.sin(a) * 3.0)
		Kit.cylinder(m, q + Vector3.new(0, 0.9, 0), q + Vector3.new(0, 3.6, 0), 0.12, { blocks = false })
	end
	solid(m, p, Vector3.new(6.8, 3.6, 6.8))
end

return Sewer
