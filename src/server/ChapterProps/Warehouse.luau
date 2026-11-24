--!strict
-- 챕터 2 물류 창고 전용 소품(구역마다 실제로 있어야 할 장비). MapKit 부품만 쓴다(직접 만든 에셋).
--   H·h 팔레트 랙(가로·세로 줄): 줄 하나(등을 맞댄 두 줄이면 두 줄)를 머리 칸에서 한 덩어리로 짓는다 — 기둥은 두 칸마다, 보는 줄 길이 하나.
--       (예전 칸마다 짓던 랙은 칸당 부품 약 20개 → 지금은 칸당 약 2개, 음파 선도 긴 보 몇 줄로 깔끔하다)
--   k 박스 흐름 선반(피킹 메자닌, 세로 줄, 낮고 비스듬한 판)   u 컨베이어(줄 하나를 한 덩어리로)
--   F 지게차(랜드마크: 마스트·포크·운전석 지붕)    J 팔레트 적재(랩 감은 상자 더미)
--   g 지게차 충전기(벽 쪽 캐비닛 + 케이블)        e 냉동기 증발기(천장 쪽 벽걸이 팬 — 지나갈 수 있음)
--   R 서버 랙(전산실)    Y 포장대·검수대(작업대 + 모니터 + 상자)    W 랩 감는 기계(회전판 + 기둥 + 감긴 팔레트)
--   B 정비 작업대(바이스 + 공구판)    d 도크 문(말아 올린 셔터 + 도크 레벨러 — 지나갈 수 있음)
--   x 내려온 화재 셔터(벽 틈을 막은 철판, 막힘)    K 탑차(줄 머리에서 짐칸·운전석·바퀴)    G 정문 경비 초소    q 화물 승강기
-- 각 함수는 StageBuilder 의 ctx 와 타일 좌표(i, j)를 받는다(i = 열 = X, j = 행 = Z). ctx.at 으로 이웃 칸 문자를 본다.


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

-- ── 줄로 짓는 설비(랙·선반·컨베이어) ──
-- 머리 칸: 줄 방향 앞 칸도, 옆(두께) 방향 앞 칸도 같은 문자가 아닌 칸. 머리에서 줄 길이 n, 두께 deep(1 또는 2)을 재서 한 번에 짓는다.
type RunInfo = { n: number, deep: number, axis: Vector3, across: Vector3, center: Vector3 }
local function runHead(ctx, i: number, j: number, alongX: boolean): RunInfo?
	local ch = ctx.at(i, j)
	local di, dj = if alongX then 1 else 0, if alongX then 0 else 1
	local ci, cj = dj, di
	if ctx.at(i - di, j - dj) == ch or ctx.at(i - ci, j - cj) == ch then
		return nil
	end
	local n = 1
	while n < 40 and ctx.at(i + di * n, j + dj * n) == ch do
		n += 1
	end
	local deep = if ctx.at(i + ci, j + cj) == ch then 2 else 1
	local axis = Vector3.new(di, 0, dj)
	local across = Vector3.new(ci, 0, cj)
	local c = base(ctx, i, j) + axis * ((n - 1) * ctx.T / 2) + across * ((deep - 1) * ctx.T / 2)
	return { n = n, deep = deep, axis = axis, across = across, center = c }
end

-- 선반 틀: 기둥(두 칸마다, 앞·뒤 줄) + 층마다 앞·뒤 긴 보 + 칸마다 짐 하나 + 보이지 않는 충돌 하나
local function shelfRun(ctx, i: number, j: number, alongX: boolean, o: { name: string, height: number, levels: { number }, depthPad: number, tilt: number, load: Vector3 })
	local r = runHead(ctx, i, j, alongX)
	if not r then
		return
	end
	local T = ctx.T
	local m = model(ctx, o.name)
	local len = r.n * T - 0.6
	local depth = r.deep * T - o.depthPad
	local height = math.min(o.height, ctx.H - 0.8)
	local posts = math.max(1, math.floor(r.n / 2 + 0.5))
	for k = 0, posts do
		local t = -len / 2 + 0.15 + (len - 0.3) * (k / posts)
		for _, s in { -1, 1 } do
			local c = r.center + r.axis * t + r.across * (s * (depth / 2 - 0.15)) + Vector3.new(0, height / 2, 0)
			Kit.box(m, CFrame.lookAt(c, c + r.axis), Vector3.new(0.3, height, 0.3), { blocks = false, axis = "Y" })
		end
	end
	for _, y in o.levels do
		local yy = math.min(y, height - 0.2)
		for _, s in { -1, 1 } do
			-- (박스 흐름 선반은 판이 앞쪽으로 기운다: 뒤 보가 조금 높다)
			local c = r.center + r.across * (s * (depth / 2 - 0.15)) + Vector3.new(0, yy + (if s > 0 then o.tilt else 0), 0)
			Kit.box(m, CFrame.lookAt(c, c + r.axis), Vector3.new(0.25, 0.4, len), { blocks = false, axis = "Z" })
		end
	end
	-- 짐(칸마다 하나, 층·앞뒤는 칸마다 다르게)
	for k = 0, r.n - 1 do
		local h = ctx.hash(i + k * r.axis.X, j + k * r.axis.Z, 31)
		local lv = o.levels[1 + math.floor(h * #o.levels) % #o.levels]
		local side = if r.deep == 2 then (if h < 0.5 then -1 else 1) * T / 2 else 0
		if lv + o.load.Y < height then
			local c = r.center + r.axis * (-len / 2 + (k + 0.5) * T) + r.across * side + Vector3.new(0, lv + 0.25 + o.load.Y / 2, 0)
			Kit.box(m, CFrame.lookAt(c, c + r.axis) * CFrame.Angles(0, (h - 0.5) * 0.2, 0), o.load, { blocks = false })
		end
	end
	-- 보이지 않는 충돌(선반 사이로 들어가거나 올라가지 못하게)
	local cc = r.center + Vector3.new(0, height / 2, 0)
	Kit.box(m, CFrame.lookAt(cc, cc + r.axis), Vector3.new(depth, height, len), { invisible = true, tag = false })
end

local RACK = { name = "Rack", height = 10.2, levels = { 0.2, 3.6, 7.0 }, depthPad = 2.4, tilt = 0, load = Vector3.new(4.6, 2.6, 6.2) }
-- H 팔레트 랙(가로 줄, X 방향)
function W.RackRunX(ctx, i: number, j: number)
	shelfRun(ctx, i, j, true, RACK)
end
-- h 팔레트 랙(세로 줄, Z 방향: 냉장·냉동실)
function W.RackRunZ(ctx, i: number, j: number)
	shelfRun(ctx, i, j, false, RACK)
end
-- k 박스 흐름 선반(피킹 메자닌): 사람 키 높이, 판 셋이 통로 쪽으로 기운다. 세로 줄
local FLOW = { name = "CartonFlow", height = 7.2, levels = { 1.2, 3.4, 5.6 }, depthPad = 3.0, tilt = 0.6, load = Vector3.new(2.4, 1.4, 3.0) }
function W.CartonFlow(ctx, i: number, j: number)
	shelfRun(ctx, i, j, false, FLOW)
end

-- u 컨베이어: 줄 하나를 머리 칸에서 — 옆판 두 줄 + 벨트 판 + 두 칸마다 다리 + 상자 몇 개. 방향은 이웃 u 로 정한다
function W.ConveyorRun(ctx, i: number, j: number)
	local alongX = ctx.at(i + 1, j) == "u" or ctx.at(i - 1, j) == "u"
	local di, dj = if alongX then 1 else 0, if alongX then 0 else 1
	if ctx.at(i - di, j - dj) == "u" then
		return
	end
	local n = 1
	while n < 40 and ctx.at(i + di * n, j + dj * n) == "u" do
		n += 1
	end
	local T = ctx.T
	local axis = Vector3.new(di, 0, dj)
	local across = Vector3.new(dj, 0, di)
	local c = base(ctx, i, j) + axis * ((n - 1) * T / 2)
	local len = n * T - 0.4
	local m = model(ctx, "Conveyor")
	for _, s in { -1, 1 } do
		local rail = c + across * (s * 1.7) + Vector3.new(0, 3.0, 0)
		Kit.box(m, CFrame.lookAt(rail, rail + axis), Vector3.new(0.2, 0.6, len), { blocks = false, axis = "Z" })
	end
	local belt = c + Vector3.new(0, 3.05, 0)
	Kit.box(m, CFrame.lookAt(belt, belt + axis), Vector3.new(3.2, 0.15, len), { blocks = false, shape = "None" })
	local legs = math.max(1, math.floor(n / 2 + 0.5))
	for k = 0, legs do
		local t = -len / 2 + 0.4 + (len - 0.8) * (k / legs)
		for _, s in { -1, 1 } do
			local lp = c + axis * t + across * (s * 1.5) + Vector3.new(0, 1.4, 0)
			Kit.box(m, CFrame.new(lp), Vector3.new(0.25, 2.8, 0.25), { blocks = false })
		end
	end
	for k = 0, n - 1, 3 do
		local h = ctx.hash(i + k * di, j + k * dj, 33)
		local bp = c + axis * (-len / 2 + (k + 0.3 + h * 0.4) * T) + Vector3.new(0, 3.9, 0)
		Kit.box(m, CFrame.lookAt(bp, bp + axis) * CFrame.Angles(0, (h - 0.5) * 0.5, 0), Vector3.new(2.0, 1.5, 2.2), { blocks = false })
	end
	local cc = c + Vector3.new(0, 1.7, 0)
	Kit.box(m, CFrame.lookAt(cc, cc + axis), Vector3.new(3.6, 3.4, len), { invisible = true, tag = false })
end

-- ── 벽 틈 설비(문 칸처럼 양옆이 벽인 칸) ──
-- 틈이 지나가는 방향(통로 축). 양옆(통로 축과 직각) 중 벽이 있는 쪽을 본다
local function gapAxis(ctx, i: number, j: number): Vector3
	if ctx.isWall(i - 1, j) or ctx.isWall(i + 1, j) then
		if not ctx.isWall(i, j - 1) and not ctx.isWall(i, j + 1) then
			return Vector3.new(0, 0, 1)
		end
	end
	return Vector3.new(1, 0, 0)
end

-- d 도크 문: 문 위 벽(문 높이 9 위) + 말아 올린 셔터 통 + 벽 쪽 안내 레일 + 바닥 도크 레벨러 판. 지나갈 수 있다
function W.DockDoor(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local ax = gapAxis(ctx, i, j)
	local across = Vector3.new(ax.Z, 0, ax.X)
	local m = model(ctx, "DockDoor")
	local T, H = ctx.T, ctx.H
	local top = 9.2
	if H - top > 0.2 then
		local hc = p + Vector3.new(0, (top + H) / 2, 0)
		Kit.box(m, CFrame.lookAt(hc, hc + ax), Vector3.new(T, H - top, 1.6), { name = "DoorWall" })
	end
	local drum = p + Vector3.new(0, top - 0.6, 0) + ax * 1.2
	Kit.cylinder(m, drum - across * (T / 2 - 0.2), drum + across * (T / 2 - 0.2), 0.6, { blocks = false, collide = false })
	for _, s in { -1, 1 } do
		if ctx.isWall(i + across.X * s, j + across.Z * s) then
			local gp = p + across * (s * (T / 2 - 0.25)) + Vector3.new(0, top / 2, 0)
			Kit.box(m, CFrame.lookAt(gp, gp + ax), Vector3.new(0.5, top, 0.5), { blocks = false })
		end
	end
	local lev = p + Vector3.new(0, 0.06, 0)
	Kit.box(m, CFrame.lookAt(lev, lev + ax), Vector3.new(T - 1.2, 0.12, T - 1.0), { blocks = false, collide = false })
end

-- x 내려온 화재 셔터: 벽 틈을 바닥까지 막은 철판(막힘) + 가로 줄무늬 + 위쪽 셔터 통 + 양옆 레일
function W.FireShutter(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local ax = gapAxis(ctx, i, j)
	local across = Vector3.new(ax.Z, 0, ax.X)
	local m = model(ctx, "FireShutter")
	local T, H = ctx.T, ctx.H
	local c = p + Vector3.new(0, H / 2, 0)
	Kit.box(m, CFrame.lookAt(c, c + ax), Vector3.new(T, H, 0.6), { blocks = true, name = "Shutter" })
	for _, f in { -1, 1 } do
		for _, y in { 2.5, 5.0, 7.5 } do
			local sp = p + ax * (f * 0.36) + Vector3.new(0, y, 0)
			Kit.box(m, CFrame.lookAt(sp, sp + ax), Vector3.new(T - 0.6, 0.18, 0.12), { blocks = false, collide = false })
		end
		local hp = p + ax * (f * 0.9) + Vector3.new(0, H - 1.0, 0)
		Kit.box(m, CFrame.lookAt(hp, hp + ax), Vector3.new(T, 1.6, 1.0), { blocks = false })
		-- 양옆 레일(벽에 붙은 세로 홈)
		local rp = p + across * (f * (T / 2 - 0.3)) + Vector3.new(0, (H - 1.8) / 2, 0)
		Kit.box(m, CFrame.lookAt(rp, rp + ax), Vector3.new(0.5, H - 1.8, 1.1), { blocks = false, axis = "Y" })
	end
end

-- ── 낱개 장비 ──
-- Y 포장대·검수대: 작업대(판 + 다리 판 둘) + 모니터 + 상자 + 테이프 받침. 벽을 등진다
function W.PackStation(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j)
	local along = Vector3.new(side.Z, 0, -side.X)
	local m = model(ctx, "PackStation")
	local c = p + side * 0.8
	local cf = CFrame.lookAt(c, c - side)
	Kit.box(m, cf * CFrame.new(0, 3.2, 0), Vector3.new(6.4, 0.25, 3.2), { blocks = false })
	for _, x in { -2.9, 2.9 } do
		Kit.box(m, cf * CFrame.new(x, 1.55, 0), Vector3.new(0.25, 3.1, 2.8), { blocks = false })
	end
	Kit.box(m, cf * CFrame.new(1.6, 4.6, 1.0), Vector3.new(2.0, 1.4, 0.15), { blocks = false }) -- 모니터
	Kit.box(m, cf * CFrame.new(1.6, 3.7, 1.1), Vector3.new(0.2, 0.9, 0.2), { blocks = false, collide = false })
	Kit.box(m, cf * CFrame.new(-1.4, 4.1, -0.2) * CFrame.Angles(0, 0.2, 0), Vector3.new(2.2, 1.6, 1.8), { blocks = false }) -- 포장 중인 상자
	Kit.cylinder(m, (cf * CFrame.new(0.2, 3.6, -0.6)).Position - along * 0.4, (cf * CFrame.new(0.2, 3.6, -0.6)).Position + along * 0.4, 0.45, { blocks = false, collide = false }) -- 테이프
	Kit.box(m, cf * CFrame.new(0, 1.8, 0), Vector3.new(6.4, 3.6, 3.2), { invisible = true, tag = false })
end

-- W 랩 감는 기계: 둥근 회전판 + 옆 기둥(마스트) + 필름 수레 + 랩이 감긴 팔레트
function W.StretchWrapper(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j)
	local m = model(ctx, "StretchWrapper")
	Kit.cylinder(m, p + Vector3.new(0, 0.05, 0), p + Vector3.new(0, 0.6, 0), 3.0, { blocks = false, rings = 1 })
	Kit.box(m, CFrame.new(p + Vector3.new(0, 2.85, 0)), Vector3.new(3.2, 4.4, 3.2), { blocks = false }) -- 감긴 짐
	local mast = p + side * 3.4 + Vector3.new(0, 4.5, 0)
	Kit.box(m, CFrame.lookAt(mast, mast - side), Vector3.new(0.9, 9.0, 0.9), { blocks = false, axis = "Y" })
	Kit.box(m, CFrame.lookAt(mast - side * 0.8 + Vector3.new(0, -0.5, 0), mast - side * 2 + Vector3.new(0, -0.5, 0)), Vector3.new(1.8, 1.4, 1.2), { blocks = false }) -- 필름 수레
	Kit.box(m, CFrame.lookAt(p + side * 3.4 + Vector3.new(0, 0.6, 0), p + Vector3.new(0, 0.6, 0)), Vector3.new(2.4, 1.2, 2.0), { blocks = false }) -- 제어함 받침
	Kit.box(m, CFrame.new(p + Vector3.new(0, 2.5, 0)), Vector3.new(6.4, 5, 6.4), { invisible = true, tag = false })
end

-- B 정비 작업대: 두꺼운 판 + 다리 + 바이스 + 벽 공구판(구멍판)
function W.Workbench(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j)
	local m = model(ctx, "Workbench")
	local c = p + side * 1.6
	local cf = CFrame.lookAt(c, c - side)
	Kit.box(m, cf * CFrame.new(0, 3.1, 0), Vector3.new(6.6, 0.4, 2.8), { blocks = false })
	for _, x in { -3.0, 3.0 } do
		Kit.box(m, cf * CFrame.new(x, 1.45, 0), Vector3.new(0.3, 2.9, 2.4), { blocks = false })
	end
	Kit.box(m, cf * CFrame.new(-2.2, 3.7, -1.0), Vector3.new(1.0, 0.8, 1.2), { blocks = false }) -- 바이스
	Kit.box(m, cf * CFrame.new(0, 6.2, 1.3), Vector3.new(6.0, 3.6, 0.12), { blocks = false, collide = false }) -- 공구판
	Kit.box(m, cf * CFrame.new(1.4, 3.75, 0), Vector3.new(1.6, 0.9, 1.0), { blocks = false }) -- 공구함
	Kit.box(m, cf * CFrame.new(0, 1.7, 0), Vector3.new(6.6, 3.4, 2.8), { invisible = true, tag = false })
end

-- K 탑차: 줄(두 칸) 머리에서 — 짐칸 상자, 운전석, 바퀴 넷, 뒷문 이음선. 짐칸 뒤(문)가 도크 문(d) 쪽을 본다
function W.BoxTruck(ctx, i: number, j: number)
	local alongX = ctx.at(i + 1, j) == "K" or ctx.at(i - 1, j) == "K"
	local di, dj = if alongX then 1 else 0, if alongX then 0 else 1
	if ctx.at(i - di, j - dj) == "K" then
		return
	end
	local n = 1
	while n < 4 and ctx.at(i + di * n, j + dj * n) == "K" do
		n += 1
	end
	local T = ctx.T
	local axis = Vector3.new(di, 0, dj)
	-- 뒤(도크 쪽)가 머리 칸 앞이면 운전석은 줄 끝 쪽
	local fwd = if ctx.at(i - di, j - dj) == "d" or ctx.isWall(i - di, j - dj) then axis else -axis
	local c = base(ctx, i, j) + axis * ((n - 1) * T / 2)
	local len = n * T - 0.8
	local m = model(ctx, "BoxTruck")
	local cargoLen = len - 4.4
	local cargoC = c - fwd * (len / 2 - cargoLen / 2) + Vector3.new(0, 1.8 + 3.6, 0)
	Kit.box(m, CFrame.lookAt(cargoC, cargoC + fwd), Vector3.new(6.4, 7.2, cargoLen), { name = "Cargo" })
	local rear = cargoC - fwd * (cargoLen / 2 + 0.05)
	Kit.box(m, CFrame.lookAt(rear, rear + fwd), Vector3.new(0.12, 6.8, 0.1), { blocks = false, collide = false }) -- 뒷문 이음선
	local cabC = c + fwd * (len / 2 - 2.0) + Vector3.new(0, 3.6, 0)
	Kit.box(m, CFrame.lookAt(cabC, cabC + fwd), Vector3.new(6.2, 4.8, 3.6), { name = "Cab" })
	Kit.box(m, CFrame.lookAt(cabC + fwd * 1.85 + Vector3.new(0, 0.9, 0), cabC + fwd * 3 + Vector3.new(0, 0.9, 0)), Vector3.new(5.2, 1.8, 0.1), { blocks = false, collide = false }) -- 앞유리 테
	local across = Vector3.new(axis.Z, 0, axis.X)
	for _, t in { -len / 2 + 2.2, len / 2 - 2.0 } do
		for _, s in { -1, 1 } do
			local w = c + fwd * t + across * (s * 3.1) + Vector3.new(0, 1.3, 0)
			Kit.cylinder(m, w - across * 0.45, w + across * 0.45, 1.3, { blocks = false, collide = false, rings = 1 })
		end
	end
end

-- G 정문 경비 초소: 네 기둥 + 허리 벽 + 지붕 판 + 창틀
function W.GuardBooth(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "GuardBooth")
	for _, x in { -2.6, 2.6 } do
		for _, z in { -2.6, 2.6 } do
			Kit.box(m, CFrame.new(p + Vector3.new(x, 3.8, z)), Vector3.new(0.4, 7.6, 0.4), { blocks = false, axis = "Y" })
		end
	end
	Kit.box(m, CFrame.new(p + Vector3.new(0, 1.6, 0)), Vector3.new(5.4, 3.2, 5.4), { name = "BoothWall" })
	Kit.box(m, CFrame.new(p + Vector3.new(0, 7.8, 0)), Vector3.new(6.6, 0.4, 6.6), { blocks = false })
	Kit.box(m, CFrame.new(p + Vector3.new(0, 5.2, 0)), Vector3.new(5.6, 0.15, 5.6), { blocks = false, collide = false }) -- 창 아래 테
end

-- q 화물 승강기(1층·2층 같은 칸): 승강로 철망 틀(네 기둥 + 위·아래 테) + 앞쪽 접이문 막대 + 운반대. 막힘
function W.GoodsLift(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j)
	local m = model(ctx, "GoodsLift")
	local H = ctx.H
	for _, x in { -3.4, 3.4 } do
		for _, z in { -3.4, 3.4 } do
			Kit.box(m, CFrame.new(p + Vector3.new(x, H / 2, z)), Vector3.new(0.4, H, 0.4), { blocks = false, axis = "Y" })
		end
	end
	Kit.box(m, CFrame.new(p + Vector3.new(0, H - 0.4, 0)), Vector3.new(7.2, 0.5, 7.2), { blocks = false })
	Kit.box(m, CFrame.new(p + Vector3.new(0, 0.3, 0)), Vector3.new(6.6, 0.6, 6.6), { blocks = false }) -- 운반대
	local across = Vector3.new(side.Z, 0, -side.X)
	for k = -2, 2 do
		local g = p - side * 3.5 + across * (k * 1.5) + Vector3.new(0, 4, 0)
		Kit.box(m, CFrame.new(g), Vector3.new(0.15, 8, 0.15), { blocks = false, collide = false }) -- 접이문
	end
	Kit.box(m, CFrame.new(p + Vector3.new(0, H / 2, 0)), Vector3.new(7.2, H, 7.2), { invisible = true, tag = false })
end

return W
