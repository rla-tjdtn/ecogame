--!strict
-- 챕터 2 물류 창고 전용 소품(구역마다 실제로 있어야 할 장비). MapKit 부품만 쓴다(직접 만든 에셋).
--   F 지게차(랜드마크: 마스트·포크·운전석 지붕)    P 팔레트 적재(랩 감은 상자 더미)
--   u 컨베이어(롤러 줄 + 다리, 포장실)            g 지게차 충전기(벽 쪽 캐비닛 + 케이블)
--   e 냉동기 증발기(천장 쪽 벽걸이 팬 — 지나갈 수 있음) R 서버 랙(전산실)
-- 각 함수는 StageBuilder 의 ctx 와 타일 좌표(i, j)를 받는다.

local Kit = require(script.Parent.Parent.MapKit)

local W = {}

local function base(ctx, i: number, j: number): Vector3
	return ctx.center(i, j) + Vector3.new(0, ctx.floorY(i, j), 0)
end

-- 가장 가까운 벽 쪽(없으면 -Z)
local function wallSide(ctx, i: number, j: number): Vector3
	for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		if ctx.isWall(i + d[1], j + d[2]) then
			return Vector3.new(d[1], 0, d[2])
		end
	end
	return Vector3.new(0, 0, -1)
end

local function model(ctx, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = ctx.props
	return m
end

-- 지게차: 차체·운전석 지붕 기둥·마스트·포크(벽 반대쪽을 본다)
function W.Forklift(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local fwd = -wallSide(ctx, i, j)
	local yaw = ctx.hash(i, j, 21) * 0.4 - 0.2
	local cf = CFrame.lookAt(p, p + fwd) * CFrame.Angles(0, yaw, 0)
	local m = model(ctx, "Forklift")
	Kit.box(m, cf * CFrame.new(0, 1.6, 0.6), Vector3.new(3.4, 2.2, 4.6), { blocks = false }) -- 차체
	Kit.box(m, cf * CFrame.new(0, 2.9, 2.4), Vector3.new(3.2, 1.4, 1.2), { blocks = false }) -- 균형추
	for _, x in { -1.5, 1.5 } do
		for _, z in { -0.6, 2.4 } do
			Kit.box(m, cf * CFrame.new(x, 4.6, z), Vector3.new(0.2, 3.4, 0.2), { blocks = false }) -- 지붕 기둥
		end
		Kit.cylinder(m, (cf * CFrame.new(x * 1.08, 0.75, -0.9)).Position, (cf * CFrame.new(x * 1.18, 0.75, -0.9)).Position, 0.75, { blocks = false, collide = false })
		Kit.cylinder(m, (cf * CFrame.new(x * 1.08, 0.6, 2.2)).Position, (cf * CFrame.new(x * 1.18, 0.6, 2.2)).Position, 0.6, { blocks = false, collide = false })
	end
	Kit.box(m, cf * CFrame.new(0, 6.35, 0.9), Vector3.new(3.4, 0.15, 3.4), { blocks = false }) -- 지붕
	for _, x in { -1.0, 1.0 } do
		Kit.box(m, cf * CFrame.new(x, 3.4, -1.9), Vector3.new(0.3, 6.6, 0.3), { blocks = false, axis = "Y" }) -- 마스트
		Kit.box(m, cf * CFrame.new(x * 0.8, 0.45, -3.3), Vector3.new(0.35, 0.12, 2.8), { blocks = false, collide = false }) -- 포크
	end
	Kit.box(m, cf * CFrame.new(0, 1.0, -2.0), Vector3.new(2.4, 1.4, 0.15), { blocks = false, collide = false }) -- 포크 등판
	Kit.box(m, cf * CFrame.new(0, 1.8, 0.2), Vector3.new(3.4, 3.6, 6.4), { invisible = true, tag = false })
end

-- 팔레트 적재: 나무 팔레트 + 랩 감은 상자 더미(높이 제각각)
function W.PalletStack(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "PalletStack")
	local h = ctx.hash(i, j, 22)
	for k, off in { Vector3.new(-1.9, 0, 0), Vector3.new(1.9, 0, 0) } do
		local q = p + off
		Kit.box(m, CFrame.new(q + Vector3.new(0, 0.3, 0)), Vector3.new(3.4, 0.6, 3.4), { blocks = false }) -- 팔레트
		local tall = 2 + ((k + math.floor(h * 4)) % 3) * 1.2
		Kit.box(m, CFrame.new(q + Vector3.new(0, 0.6 + tall / 2, 0)) * CFrame.Angles(0, (h - 0.5) * 0.2, 0), Vector3.new(3.1, tall, 3.1), { blocks = false })
	end
	Kit.box(m, CFrame.new(p + Vector3.new(0, 2, 0)), Vector3.new(7.4, 4, 3.6), { invisible = true, tag = false })
end

-- 컨베이어: 허리 높이 롤러 줄(긴 옆판 두 줄 + 롤러) + 다리. 벽과 나란히
function W.Conveyor(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j)
	local axis = Vector3.new(side.Z, 0, -side.X)
	local m = model(ctx, "Conveyor")
	local c = p - side * 1.0
	for _, s in { -1, 1 } do
		local rail = c + side * (s * 1.1) + Vector3.new(0, 3.0, 0)
		Kit.box(m, CFrame.lookAt(rail, rail + axis), Vector3.new(0.2, 0.5, 8), { blocks = false, axis = "Z" })
		for _, a in { -3.2, 3.2 } do
			local leg = c + side * (s * 1.0) + axis * a + Vector3.new(0, 1.4, 0)
			Kit.box(m, CFrame.new(leg), Vector3.new(0.25, 2.8, 0.25), { blocks = false })
		end
	end
	for k = -3, 3 do
		local r = c + axis * (k * 1.1) + Vector3.new(0, 3.05, 0)
		Kit.cylinder(m, r - side * 1.0, r + side * 1.0, 0.18, { blocks = false, collide = false })
	end
	-- 상자 하나(포장 중)
	Kit.box(m, CFrame.lookAt(c + Vector3.new(0, 3.9, 0) + axis * 1.4, c + Vector3.new(0, 3.9, 0) + axis * 2.4), Vector3.new(1.6, 1.4, 1.8), { blocks = false })
	Kit.box(m, CFrame.lookAt(c + Vector3.new(0, 1.6, 0), c + Vector3.new(0, 1.6, 0) + axis), Vector3.new(2.6, 3.2, 8), { invisible = true, tag = false })
end

-- 지게차 충전기: 벽에 붙은 캐비닛 + 표시창 + 바닥으로 늘어진 케이블
function W.Charger(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j)
	local m = model(ctx, "Charger")
	local c = p + side * (ctx.T / 2 - 1.0)
	Kit.box(m, CFrame.lookAt(c + Vector3.new(0, 2.6, 0), c + Vector3.new(0, 2.6, 0) - side), Vector3.new(2.6, 5.2, 1.6))
	Kit.box(m, CFrame.lookAt(c - side * 0.85 + Vector3.new(0, 4.0, 0), c - side * 1.85 + Vector3.new(0, 4.0, 0)), Vector3.new(1.4, 0.8, 0.1), { blocks = false, collide = false })
	local a = c - side * 0.8 + Vector3.new(0.6, 2.2, 0)
	Kit.cylinder(m, a, a - side * 2.2 - Vector3.new(0, 2.0, 0), 0.15, { blocks = false, collide = false })
	Kit.cylinder(m, a - side * 2.2 - Vector3.new(0, 2.0, 0), a - side * 3.4 - Vector3.new(0, 2.1, 0), 0.15, { blocks = false, collide = false })
	-- 바닥 정차 표시(낮은 선)
	Kit.box(m, CFrame.lookAt(p - side * 1.5 + Vector3.new(0, 0.05, 0), p - side * 2.5 + Vector3.new(0, 0.05, 0)), Vector3.new(4.5, 0.1, 0.2), { blocks = false, collide = false })
end

-- 냉동기 증발기: 벽 위쪽에 매단 팬 상자(지나갈 수 있음)
function W.Evaporator(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j)
	local m = model(ctx, "Evaporator")
	local c = p + side * (ctx.T / 2 - 1.3) + Vector3.new(0, ctx.H - 2.4, 0)
	local across = Vector3.new(side.Z, 0, -side.X)
	Kit.box(m, CFrame.lookAt(c, c - side), Vector3.new(6.0, 2.2, 2.4), { blocks = false, collide = false })
	for _, s in { -1.5, 1.5 } do
		local f = c - side * 1.25 + across * s
		Kit.cylinder(m, f, f - side * 0.1, 0.9, { blocks = false, collide = false, rings = 1 })
	end
end

-- 서버 랙: 키 큰 캐비닛 + 앞면 줄(장비 칸)
function W.ServerRack(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j)
	local m = model(ctx, "ServerRack")
	local c = p + side * 1.4
	Kit.box(m, CFrame.lookAt(c + Vector3.new(0, 3.6, 0), c + Vector3.new(0, 3.6, 0) - side), Vector3.new(2.6, 7.2, 3.2))
	for k = 0, 5 do
		local y = 1.0 + k * 1.05
		Kit.box(m, CFrame.lookAt(c - side * 1.62 + Vector3.new(0, y, 0), c - side * 2.62 + Vector3.new(0, y, 0)), Vector3.new(2.2, 0.12, 0.08), { blocks = false, collide = false })
	end
end

return W
