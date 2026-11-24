--!nonstrict
-- 챕터 6 호텔 전용 소품(구역마다 실제로 있어야 할 장비·가구). MapKit 부품만 쓴다(직접 만든 에셋).
--   F 프런트 데스크(로비 랜드마크: 길게 이어지는 카운터 + 높은 접수대 + 모니터)
--   G 짐 카트(황동 새장 모양 트롤리: 아치 손잡이 + 기둥 넷)       w 소파(로비·라운지·스위트 거실)
--   q 바 카운터(라운지 바, 손님 쪽 바 의자)                       U 원형 테이블 + 의자 넷(연회장·레스토랑·직원 식당)
--   K 업소용 화구(가스레인지 + 위 후드·덕트: 주방 랜드마크)        P 스테인리스 조리대(아래 선반)
--   W 업소용 세탁기(둥근 문)                                       j 린넨 선반(접힌 수건·시트 더미)
--   l 직원 사물함 줄(좁은 문 셋)                                   h 하우스키핑 카트(선반 + 빨래 자루 + 손잡이)
--   V 제빙기·자판기(층 제빙기실)                                   e 엘리베이터 문(문틀 + 두 짝 문 + 층 표시판 + 호출 버튼)
--   ── 객실(재작업 2차: 실제 객실 한 칸 = 욕실 · 침대와 협탁 · 책상·TV · 짐 받침대 · 옷장) ──
--   R 더블 침대(머리판 + 양옆 협탁·스탠드)   r 트윈 침대(가운데 협탁)   u 욕실(칸막이 + 욕조·변기·세면대·거울)
--   T 책상 + 의자 + 벽걸이 TV + 스탠드        y 짐 받침대 + 여행 가방     a 붙박이 옷장(숨는 곳 아닌 것)
--   ── 로비·연회장 ──  Y 분수(3x3 가운데 칸이 짓는다, i = 분수가 덮는 빈 칸)  N 샹들리에(천장에 매달림, 지나갈 수 있다)  z 연회 무대
-- 각 함수는 StageBuilder 의 ctx 와 타일 좌표(i, j)를 받는다. 1층 천장은 11(2층 건물)이라 모든 소품은 바닥에서 10 아래.

local Kit = require(script.Parent.Parent.MapKit)
local PM = require(script.Parent.Parent.PropMesh) -- 다 지은 소품을 메시 에셋으로 바꿔 입힌다(없으면 기본 도형 그대로)

local P = {}

local function base(ctx, i: number, j: number): Vector3
	return ctx.center(i, j) + Vector3.new(0, ctx.floorY(i, j), 0)
end

-- 가장 가까운 벽 쪽(없으면 기본값)
local function wallSide(ctx, i: number, j: number, default: Vector3?): Vector3
	for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		if ctx.isWall(i + d[1], j + d[2]) then
			return Vector3.new(d[1], 0, d[2])
		end
	end
	return default or Vector3.new(0, 0, -1)
end

local function model(ctx, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = ctx.props
	return m
end

local function same(ctx, i: number, j: number, ch: string): boolean
	local ok, v = pcall(ctx.at, i, j)
	return ok and v == ch
end

-- 같은 글자가 이어진 방향(카운터 줄): 가로로 이웃이 있으면 X, 세로면 Z, 혼자면 벽과 나란히
local function runAxis(ctx, i: number, j: number, ch: string): Vector3
	if same(ctx, i - 1, j, ch) or same(ctx, i + 1, j, ch) then
		return Vector3.new(1, 0, 0)
	elseif same(ctx, i, j - 1, ch) or same(ctx, i, j + 1, ch) then
		return Vector3.new(0, 0, 1)
	end
	local s = wallSide(ctx, i, j)
	return Vector3.new(s.Z, 0, -s.X)
end

-- 축(axis)·앞(front)·위로 세운 CFrame: 로컬 X = axis, 로컬 Z = -front(앞이 -Z)
local function frame(p: Vector3, axis: Vector3, front: Vector3): CFrame
	return CFrame.lookAt(p, p + front)
end

-- ── 로비 ──
-- 프런트 데스크: 칸마다 한 토막(8 길이). 손님 쪽(앞)은 높은 접수대, 직원 쪽은 낮은 작업대. 줄 끝에는 옆판
function P.FrontDesk(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local axis = runAxis(ctx, i, j, "F")
	-- 손님 쪽: 가로 줄이면 남쪽(+Z), 세로 줄이면 동쪽(+X). 그쪽 두 칸 앞이 벽이면(데스크 뒤 직원 통로 + 벽) 반대쪽이 손님 쪽
	local front = if math.abs(axis.X) > 0.5 then Vector3.new(0, 0, 1) else Vector3.new(1, 0, 0)
	if ctx.isWall(i + math.round(front.X) * 2, j + math.round(front.Z) * 2) then
		front = -front
	end
	local cf = frame(p, axis, front) -- 로컬 -Z = 앞
	local m = model(ctx, "FrontDesk")
	local L = ctx.T
	Kit.box(m, cf * CFrame.new(0, 2.0, -0.9), Vector3.new(L, 4.0, 0.5), { blocks = false }) -- 앞 판(손님 쪽 벽)
	Kit.box(m, cf * CFrame.new(0, 4.1, -0.9), Vector3.new(L, 0.2, 1.2), { blocks = false }) -- 높은 접수대
	Kit.box(m, cf * CFrame.new(0, 2.8, 0.4), Vector3.new(L, 0.2, 2.2), { blocks = false }) -- 직원 작업대
	Kit.box(m, cf * CFrame.new(0, 0.2, -0.6), Vector3.new(L, 0.4, 1.4), { blocks = false, collide = false }) -- 발판 띠
	local h = ctx.hash(i, j, 61)
	if h > 0.35 then -- 모니터(칸마다 있지는 않다)
		local mp = cf * CFrame.new((h - 0.65) * 3, 3.9, 0.5)
		Kit.box(m, mp, Vector3.new(1.6, 1.0, 0.12), { blocks = false, collide = false })
		Kit.box(m, cf * CFrame.new((h - 0.65) * 3, 3.1, 0.6), Vector3.new(0.6, 0.12, 0.5), { blocks = false, collide = false })
	end
	for _, s in { -1, 1 } do
		local ni = i + math.round(axis.X) * s
		local nj = j + math.round(axis.Z) * s
		if not same(ctx, ni, nj, "F") then
			Kit.box(m, cf * CFrame.new(s * (L / 2 - 0.2), 2.1, -0.2), Vector3.new(0.4, 4.2, 2.6), { blocks = false }) -- 옆판
		end
	end
	if h < 0.25 then -- 호출 벨
		Kit.cylinder(m, (cf * CFrame.new(0.5, 4.2, -1.0)).Position, (cf * CFrame.new(0.5, 4.55, -1.0)).Position, 0.3, { blocks = false, collide = false })
	end
	Kit.box(m, cf * CFrame.new(0, 2.1, -0.2), Vector3.new(L, 4.2, 2.8), { invisible = true, tag = false })
	local endL = not same(ctx, i - math.round(axis.X), j - math.round(axis.Z), "F")
	local endR = not same(ctx, i + math.round(axis.X), j + math.round(axis.Z), "F")
	PM.dress(m, if endL and endR then "Hotel.FrontDeskSolo" elseif endL then "Hotel.FrontDeskEndL" elseif endR then "Hotel.FrontDeskEndR" else "Hotel.FrontDesk", cf) -- (바닥 가운데, -Z = 손님 쪽, 옆판 = 줄 끝)
end

-- 짐 카트: 카펫 바닥판 + 바퀴 넷 + 기둥 넷 + 위 아치 손잡이 + 옷걸이 봉 + 여행 가방 둘
function P.LuggageCart(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local yaw = ctx.hash(i, j, 62) * 1.2 - 0.6
	local cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
	local m = model(ctx, "LuggageCart")
	Kit.box(m, cf * CFrame.new(0, 0.9, 0), Vector3.new(2.6, 0.3, 4.4), { blocks = false }) -- 바닥판
	for _, z in { -1.9, 1.9 } do
		for _, x in { -1.1, 1.1 } do
			Kit.cylinder(m, (cf * CFrame.new(x, 1.0, z)).Position, (cf * CFrame.new(x, 5.6, z)).Position, 0.09, { blocks = false, collide = false })
		end
		Kit.cylinder(m, (cf * CFrame.new(-1.1, 5.6, z)).Position, (cf * CFrame.new(0, 6.4, z)).Position, 0.09, { blocks = false, collide = false }) -- 아치
		Kit.cylinder(m, (cf * CFrame.new(1.1, 5.6, z)).Position, (cf * CFrame.new(0, 6.4, z)).Position, 0.09, { blocks = false, collide = false })
	end
	Kit.cylinder(m, (cf * CFrame.new(0, 6.4, -1.9)).Position, (cf * CFrame.new(0, 6.4, 1.9)).Position, 0.08, { blocks = false, collide = false }) -- 옷걸이 봉
	Kit.box(m, cf * CFrame.new(0, 2.2, -0.9), Vector3.new(2.0, 2.4, 1.0), { blocks = false }) -- 가방
	Kit.box(m, cf * CFrame.new(0.2, 1.7, 0.9) * CFrame.Angles(0, 0.2, 0), Vector3.new(1.8, 1.4, 1.4), { blocks = false })
	Kit.box(m, cf * CFrame.new(0, 2.5, 0), Vector3.new(2.6, 5, 4.4), { invisible = true, tag = false })
	PM.dress(m, "Hotel.LuggageCart", cf) -- (바닥 가운데, 긴 쪽 = Z)
end

-- 소파: 등받이는 벽 쪽(없으면 북쪽), 팔걸이 둘, 방석
function P.Sofa(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j, Vector3.new(0, 0, -1))
	local axis = Vector3.new(side.Z, 0, -side.X)
	local cf = frame(p, axis, -side) -- 로컬 -Z = 앞(방 안쪽), +Z = 벽 쪽
	local m = model(ctx, "Sofa")
	local off = ctx.T / 2 - 1.8
	Kit.box(m, cf * CFrame.new(0, 0.9, off - 0.2), Vector3.new(6.2, 1.2, 2.8), { blocks = false }) -- 좌판
	Kit.box(m, cf * CFrame.new(0, 2.4, off + 1.0), Vector3.new(6.2, 2.0, 0.7), { blocks = false }) -- 등받이
	for _, s in { -1, 1 } do
		Kit.box(m, cf * CFrame.new(s * 3.0, 1.6, off - 0.1), Vector3.new(0.6, 1.4, 3.0), { blocks = false }) -- 팔걸이
	end
	Kit.box(m, cf * CFrame.new(-1.5, 1.6, off - 0.3), Vector3.new(2.8, 0.3, 2.2), { blocks = false, collide = false }) -- 방석 둘
	Kit.box(m, cf * CFrame.new(1.5, 1.6, off - 0.3), Vector3.new(2.8, 0.3, 2.2), { blocks = false, collide = false })
	Kit.box(m, cf * CFrame.new(0, 1.6, off), Vector3.new(6.4, 3.2, 3.2), { invisible = true, tag = false })
	PM.dress(m, "Hotel.Sofa", cf * CFrame.new(0, 0, off)) -- (바닥 가운데, -Z = 앉는 쪽, +Z = 등받이)
end

-- ── 라운지 바 ──
-- 바 카운터: 칸마다 한 토막(벽 쪽이 바텐더 자리), 앞에 바 의자 둘, 벽에 술병 선반
function P.BarCounter(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j, Vector3.new(0, 0, -1))
	local axis = Vector3.new(side.Z, 0, -side.X)
	local cf = frame(p, axis, -side)
	local m = model(ctx, "BarCounter")
	local L = ctx.T
	Kit.box(m, cf * CFrame.new(0, 1.9, -0.2), Vector3.new(L, 3.8, 1.6), { blocks = false }) -- 카운터 몸
	Kit.box(m, cf * CFrame.new(0, 3.9, -0.4), Vector3.new(L, 0.2, 2.4), { blocks = false }) -- 상판
	Kit.box(m, cf * CFrame.new(0, 5.6, L / 2 - 0.5), Vector3.new(L - 0.4, 0.15, 0.9), { blocks = false, collide = false }) -- 술병 선반
	for k = -2, 2 do
		local b = cf * CFrame.new(k * 1.4, 6.3, L / 2 - 0.5)
		Kit.cylinder(m, b.Position - Vector3.new(0, 0.6, 0), b.Position + Vector3.new(0, 0.5, 0), 0.22, { blocks = false, collide = false })
	end
	for _, x in { -1.9, 1.9 } do -- 바 의자
		local s = cf * CFrame.new(x, 0, -2.6)
		Kit.cylinder(m, s.Position, s.Position + Vector3.new(0, 2.8, 0), 0.12, { blocks = false, collide = false })
		Kit.cylinder(m, s.Position + Vector3.new(0, 2.8, 0), s.Position + Vector3.new(0, 3.05, 0), 0.75, { blocks = false, collide = false })
	end
	Kit.box(m, cf * CFrame.new(0, 2, -0.3), Vector3.new(L, 4, 2.6), { invisible = true, tag = false })
	PM.dress(m, "Hotel.BarCounter", cf) -- (칸 가운데 바닥, -Z = 손님 쪽, +Z = 벽 술병 선반)
end

-- 원형 테이블 + 의자 넷(연회장·레스토랑)
function P.RoundTable(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local yaw = ctx.hash(i, j, 63) * math.pi
	local cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
	local m = model(ctx, "RoundTable")
	Kit.cylinder(m, (cf * CFrame.new(0, 2.9, 0)).Position, (cf * CFrame.new(0, 3.1, 0)).Position, 2.2, { blocks = false }) -- 상판
	Kit.cylinder(m, (cf * CFrame.new(0, 0, 0)).Position, (cf * CFrame.new(0, 2.9, 0)).Position, 0.25, { blocks = false }) -- 다리
	for k = 0, 3 do
		local a = k * math.pi / 2 + 0.3
		local c = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -3.1)
		Kit.box(m, c * CFrame.new(0, 0.95, 0), Vector3.new(1.5, 1.9, 1.5), { blocks = false, collide = false }) -- 의자(좌판까지, 4차)
		Kit.box(m, c * CFrame.new(0, 2.9, -0.7), Vector3.new(1.5, 2.0, 0.15), { blocks = false, collide = false }) -- 등받이
	end
	Kit.box(m, CFrame.new(p + Vector3.new(0, 1.5, 0)), Vector3.new(4.6, 3, 4.6), { invisible = true, tag = false })
	PM.dress(m, "Hotel.RoundTable", cf) -- (테이블 다리 밑 바닥)
end

-- ── 주방 ──
-- 업소용 화구: 벽 쪽 레인지(화구 넷, 오븐 문 선) + 위 후드 + 천장으로 가는 덕트
function P.Range(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j)
	local axis = Vector3.new(side.Z, 0, -side.X)
	local cf = frame(p, axis, -side)
	local m = model(ctx, "Range")
	local back = ctx.T / 2 - 1.6
	Kit.box(m, cf * CFrame.new(0, 1.6, back), Vector3.new(7.4, 3.2, 3.0)) -- 몸통
	for _, x in { -2.2, 2.2 } do
		for _, z in { -0.6, 0.6 } do
			local c = (cf * CFrame.new(x * 0.8, 3.2, back + z)).Position
			Kit.cylinder(m, c, c + Vector3.new(0, 0.12, 0), 0.45, { blocks = false, collide = false }) -- 화구
		end
	end
	Kit.box(m, cf * CFrame.new(0, 1.5, back - 1.52), Vector3.new(6.6, 0.08, 0.08), { blocks = false, collide = false }) -- 오븐 문 손잡이
	Kit.box(m, cf * CFrame.new(0, 7.0, back + 0.2), Vector3.new(7.8, 1.4, 3.4), { blocks = false }) -- 후드
	Kit.wedge(m, cf * CFrame.new(0, 8.2, back + 0.6) * CFrame.Angles(0, math.pi, 0), Vector3.new(7.0, 1.0, 2.6), { blocks = false, collide = false })
	Kit.box(m, cf * CFrame.new(0, 9.6, back + 1.0), Vector3.new(2.0, 1.8, 1.6), { blocks = false, collide = false }) -- 덕트
	PM.dress(m, "Hotel.Range", cf * CFrame.new(0, 0, back)) -- (레인지 몸통 밑 바닥, -Z = 요리사 쪽)
end

-- 스테인리스 조리대: 상판 + 다리 넷 + 아래 선반 + 위 선반(양념통)
function P.PrepTable(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local axis = runAxis(ctx, i, j, "P")
	local cf = frame(p, axis, Vector3.new(axis.Z, 0, -axis.X))
	local m = model(ctx, "PrepTable")
	local L = ctx.T - 0.6
	Kit.box(m, cf * CFrame.new(0, 3.0, 0), Vector3.new(L, 0.15, 3.0), { blocks = false })
	Kit.box(m, cf * CFrame.new(0, 0.9, 0), Vector3.new(L - 0.4, 0.1, 2.6), { blocks = false, collide = false })
	for _, x in { -1, 1 } do -- 다리(양 끝 한 판씩, 4차)
		Kit.box(m, cf * CFrame.new(x * (L / 2 - 0.2), 1.5, 0), Vector3.new(0.15, 3.0, 2.6), { blocks = false, collide = false })
	end
	local h = ctx.hash(i, j, 64)
	Kit.box(m, cf * CFrame.new((h - 0.5) * 3, 3.5, 0.4), Vector3.new(1.8, 0.8, 1.2), { blocks = false, collide = false }) -- 통
	Kit.box(m, cf * CFrame.new(0, 1.5, 0), Vector3.new(L, 3, 3), { invisible = true, tag = false })
	PM.dress(m, "Hotel.PrepTable", cf) -- (바닥 가운데, 긴 쪽 = X)
end

-- ── 세탁실·린넨실·하우스키핑 ──
-- 업소용 세탁기: 큰 상자 + 앞의 둥근 문(원통 테두리) + 위 조작판
function P.Washer(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j)
	local axis = Vector3.new(side.Z, 0, -side.X)
	local cf = frame(p, axis, -side)
	local m = model(ctx, "Washer")
	local back = ctx.T / 2 - 2.6
	Kit.box(m, cf * CFrame.new(0, 3.0, back), Vector3.new(5.6, 6.0, 5.0)) -- 몸통
	local doorC = cf * CFrame.new(0, 2.8, back - 2.5)
	Kit.cylinder(m, doorC.Position, (doorC * CFrame.new(0, 0, -0.35)).Position, 1.7, { blocks = false, collide = false }) -- 둥근 문
	Kit.cylinder(m, (doorC * CFrame.new(0, 0, -0.35)).Position, (doorC * CFrame.new(0, 0, -0.5)).Position, 1.1, { blocks = false, collide = false })
	Kit.box(m, cf * CFrame.new(0, 5.4, back - 2.55), Vector3.new(4.4, 0.8, 0.15), { blocks = false, collide = false }) -- 조작판
	PM.dress(m, "Hotel.Washer", cf * CFrame.new(0, 0, back)) -- (몸통 밑 바닥, -Z = 둥근 문 쪽)
end

-- 린넨 선반: 철망 선반(기둥 넷 + 선반 넷) + 접힌 수건·시트 더미
function P.LinenShelf(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j)
	local axis = Vector3.new(side.Z, 0, -side.X)
	local cf = frame(p, axis, -side)
	local m = model(ctx, "LinenShelf")
	local back = ctx.T / 2 - 1.2
	local L = ctx.T - 0.8
	-- (4차 부품 줄이기: 기둥 넷 → 옆판 둘, 선반 넷 → 셋, 더미는 선반마다 하나)
	for _, x in { -1, 1 } do
		Kit.box(m, cf * CFrame.new(x * (L / 2 - 0.1), 3.6, back), Vector3.new(0.2, 7.2, 2.0), { blocks = false, axis = "Y" })
	end
	for k, y in { 0.4, 3.0, 5.6 } do
		Kit.box(m, cf * CFrame.new(0, y, back), Vector3.new(L, 0.1, 2.0), { blocks = false, collide = k == 1, shape = "None" })
		local h = ctx.hash(i * 4 + k, j, 65)
		Kit.box(m, cf * CFrame.new((h - 0.5) * 2, y + 0.6, back), Vector3.new(L - 1.8, 1.0 + h * 0.4, 1.6), { blocks = false, collide = false })
	end
	Kit.box(m, cf * CFrame.new(0, 3.6, back), Vector3.new(L, 7.2, 2.0), { invisible = true, tag = false })
	PM.dress(m, "Hotel.LinenShelf", cf * CFrame.new(0, 0, back)) -- (선반 밑 바닥, -Z = 앞)
end

-- 직원 사물함 줄: 벽에 붙은 좁은 사물함 셋(문 틈 선 + 환기 구멍 줄)
function P.StaffLockers(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j)
	local axis = Vector3.new(side.Z, 0, -side.X)
	local cf = frame(p, axis, -side)
	local m = model(ctx, "StaffLockers")
	local back = ctx.T / 2 - 1.0
	Kit.box(m, cf * CFrame.new(0, 3.6, back), Vector3.new(7.4, 7.2, 1.9))
	for _, x in { -1.23, 1.23 } do
		Kit.box(m, cf * CFrame.new(x, 3.6, back - 0.97), Vector3.new(0.08, 6.8, 0.08), { blocks = false, collide = false }) -- 문 틈
	end
	for _, x in { -2.46, 0, 2.46 } do
		Kit.box(m, cf * CFrame.new(x, 6.3, back - 0.97), Vector3.new(1.2, 0.5, 0.08), { blocks = false, collide = false }) -- 환기 구멍
		Kit.box(m, cf * CFrame.new(x + 0.8, 3.6, back - 1.0), Vector3.new(0.12, 0.6, 0.12), { blocks = false, collide = false }) -- 손잡이
	end
	Kit.box(m, cf * CFrame.new(0, 0.9, back - 2.2), Vector3.new(6.0, 0.25, 1.2), { blocks = false, collide = false }) -- 앞 긴 의자 상판
	for _, x in { -2.6, 2.6 } do
		Kit.box(m, cf * CFrame.new(x, 0.45, back - 2.2), Vector3.new(0.25, 0.9, 1.0), { blocks = false, collide = false })
	end
	PM.dress(m, "Hotel.StaffLockers", cf * CFrame.new(0, 0, back)) -- (사물함 밑 바닥, -Z = 문 쪽)
end

-- 하우스키핑 카트: 선반 셋 상자 + 한쪽 빨래 자루 + 반대쪽 손잡이 + 바퀴
function P.HousekeepingCart(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j)
	local axis = Vector3.new(side.Z, 0, -side.X)
	local cf = frame(p, axis, -side) * CFrame.new(0, 0, ctx.T / 2 - 2.0)
	local m = model(ctx, "HousekeepingCart")
	Kit.box(m, cf * CFrame.new(0, 2.2, 0), Vector3.new(4.6, 3.4, 2.2), { blocks = false }) -- 선반 상자(한 덩어리, 4차: 선반판·옆판·수건·바퀴 뺌)
	Kit.box(m, cf * CFrame.new(1.0, 4.3, 0), Vector3.new(1.0, 0.8, 0.8), { blocks = false, collide = false }) -- 세제통
	Kit.box(m, cf * CFrame.new(3.3, 2.0, 0), Vector3.new(1.8, 3.2, 2.0), { blocks = false }) -- 빨래 자루
	Kit.cylinder(m, (cf * CFrame.new(-2.9, 3.6, -0.9)).Position, (cf * CFrame.new(-2.9, 3.6, 0.9)).Position, 0.1, { blocks = false, collide = false }) -- 손잡이
	Kit.box(m, cf * CFrame.new(0.5, 2.2, 0), Vector3.new(6.6, 4.4, 2.4), { invisible = true, tag = false })
	PM.dress(m, "Hotel.HousekeepingCart", cf) -- (선반 상자 밑 바닥, +X = 빨래 자루, -X = 손잡이)
end

-- 제빙기·자판기: 키 큰 상자 + 앞 비스듬한 얼음 칸 문 + 앞면 패널 선
function P.IceMachine(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j)
	local axis = Vector3.new(side.Z, 0, -side.X)
	local cf = frame(p, axis, -side)
	local m = model(ctx, "IceMachine")
	local back = ctx.T / 2 - 1.8
	local tall = ctx.hash(i, j, 66) > 0.5
	if tall then -- 자판기
		Kit.box(m, cf * CFrame.new(0, 3.5, back), Vector3.new(4.2, 7.0, 3.2))
		Kit.box(m, cf * CFrame.new(-0.6, 4.4, back - 1.62), Vector3.new(2.6, 4.0, 0.08), { blocks = false, collide = false }) -- 진열 창
		Kit.box(m, cf * CFrame.new(1.4, 4.4, back - 1.62), Vector3.new(0.6, 1.6, 0.08), { blocks = false, collide = false }) -- 버튼 판
		Kit.box(m, cf * CFrame.new(-0.6, 1.2, back - 1.62), Vector3.new(2.4, 0.8, 0.08), { blocks = false, collide = false }) -- 꺼내는 곳
	else -- 제빙기
		Kit.box(m, cf * CFrame.new(0, 2.4, back), Vector3.new(4.0, 4.8, 3.2))
		Kit.box(m, cf * CFrame.new(0, 5.6, back + 0.2), Vector3.new(3.6, 1.6, 2.6), { blocks = false })
		Kit.wedge(m, cf * CFrame.new(0, 3.6, back - 1.8) * CFrame.Angles(0, math.pi, 0), Vector3.new(3.4, 1.6, 0.5), { blocks = false, collide = false })
		Kit.box(m, cf * CFrame.new(0, 1.0, back - 1.62), Vector3.new(3.2, 0.5, 0.08), { blocks = false, collide = false }) -- 바람 구멍
	end
	PM.dress(m, if tall then "Hotel.VendingMachine" else "Hotel.IceMachine", cf * CFrame.new(0, 0, back)) -- (몸통 밑 바닥, -Z = 앞)
end

-- 엘리베이터 문: 벽에 붙은 문틀 + 두 짝 문(가운데 틈) + 위 층 표시판 + 옆 호출 버튼
function P.Elevator(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j)
	local axis = Vector3.new(side.Z, 0, -side.X)
	local cf = frame(p, axis, -side)
	local m = model(ctx, "Elevator")
	local wz = ctx.T / 2 - 0.3 -- 벽 바로 앞
	for _, s in { -1, 1 } do
		Kit.box(m, cf * CFrame.new(s * 2.7, 4.0, wz), Vector3.new(0.6, 8.0, 0.6), { blocks = false, axis = "Y" }) -- 문틀 기둥
		Kit.box(m, cf * CFrame.new(s * 1.2, 3.75, wz + 0.1), Vector3.new(2.3, 7.5, 0.2), { blocks = false }) -- 문짝
	end
	Kit.box(m, cf * CFrame.new(0, 8.2, wz), Vector3.new(6.0, 0.6, 0.6), { blocks = false }) -- 문틀 위
	Kit.box(m, cf * CFrame.new(0, 9.1, wz + 0.1), Vector3.new(2.0, 0.7, 0.15), { blocks = false, collide = false }) -- 층 표시판
	Kit.box(m, cf * CFrame.new(3.4, 4.2, wz + 0.1), Vector3.new(0.5, 1.0, 0.12), { blocks = false, collide = false }) -- 호출 버튼
	Kit.box(m, cf * CFrame.new(0, 4.0, wz), Vector3.new(6.0, 8.0, 1.0), { invisible = true, tag = false })
	PM.dress(m, "Hotel.Elevator", cf * CFrame.new(0, 0, wz)) -- (문틀 밑 바닥, -Z = 복도 쪽)
end

-- ── 객실 ──
-- 벽 쪽 방향들(없으면 빈 목록)
local function wallDirs(ctx, i: number, j: number): { Vector3 }
	local out = {}
	for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		if ctx.isWall(i + d[1], j + d[2]) then
			table.insert(out, Vector3.new(d[1], 0, d[2]))
		end
	end
	return out
end

-- 침대 하나(머리판 쪽이 로컬 +Z): 너비 w, 길이 6.4, 가운데 x
local function bedAt(m: Model, cf: CFrame, x: number, w: number)
	local head = 3.75
	local mid = head - 3.3
	-- (4차 부품 줄이기: 틀·매트리스·이불을 한 덩어리로 — 음파 윤곽은 같다)
	Kit.box(m, cf * CFrame.new(x, 0.9, mid), Vector3.new(w, 1.8, 6.4), { blocks = false }) -- 침대(틀 + 매트리스)
	Kit.box(m, cf * CFrame.new(x, 1.95, head - 0.9), Vector3.new(w - 0.8, 0.45, 1.0), { blocks = false, collide = false }) -- 베개
	Kit.box(m, cf * CFrame.new(x, 2.4, head + 0.05), Vector3.new(w + 0.2, 3.4, 0.3), { blocks = false }) -- 머리판
end

-- 협탁 + 스탠드(로컬 좌표 x, 머리판 옆)
local function nightstand(m: Model, cf: CFrame, x: number)
	Kit.box(m, cf * CFrame.new(x, 1.0, 3.1), Vector3.new(1.2, 2.0, 1.3), { blocks = false })
	local b = (cf * CFrame.new(x, 2.0, 3.2)).Position
	Kit.cylinder(m, b, b + Vector3.new(0, 1.2, 0), 0.45, { blocks = false, collide = false }) -- 스탠드(갓 하나)
end

-- 더블 침대: 머리판은 칸막이벽에, 양옆에 협탁과 스탠드
function P.GuestBed(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j, Vector3.new(0, 0, -1))
	local axis = Vector3.new(side.Z, 0, -side.X)
	local cf = frame(p, axis, -side) -- 로컬 +Z = 벽(머리 쪽)
	local m = model(ctx, "GuestBed")
	bedAt(m, cf, 0, 5.0)
	for _, s in { -1, 1 } do
		nightstand(m, cf, s * 3.25)
	end
	Kit.box(m, cf * CFrame.new(0, 1.4, 0.45), Vector3.new(5.2, 2.8, 6.6), { invisible = true, tag = false })
	PM.dress(m, "Hotel.GuestBed", cf) -- (칸 가운데 바닥, +Z = 머리판 벽)
end

-- 트윈 침대: 싱글 침대 둘 사이에 협탁 하나
function P.TwinBeds(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j, Vector3.new(0, 0, -1))
	local axis = Vector3.new(side.Z, 0, -side.X)
	local cf = frame(p, axis, -side)
	local m = model(ctx, "TwinBeds")
	for _, s in { -1, 1 } do
		bedAt(m, cf, s * 2.2, 2.6)
	end
	nightstand(m, cf, 0)
	Kit.box(m, cf * CFrame.new(0, 1.4, 0.45), Vector3.new(7.2, 2.8, 6.6), { invisible = true, tag = false })
	PM.dress(m, "Hotel.TwinBeds", cf) -- (칸 가운데 바닥, +Z = 머리판 벽)
end

-- 욕실: 칸 안을 칸막이로 막고(입구 쪽 칸막이에 문틈), 벽을 따라 욕조 · 변기 · 세면대
--   (4차 부품 줄이기: 문짝·욕조 테·수전·물탱크·세면 볼·거울을 뺐다. 칸막이 윤곽과 큰 설비 셋만 — 작은 부품은 음파 선 잡음이었다)
function P.Bathroom(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "Bathroom")
	local T = ctx.T
	local hgt = math.min(ctx.H, 11) - 1.4
	local walls = wallDirs(ctx, i, j)
	-- 칸막이: 벽이 아닌 쪽 가장자리마다. 문(D) 옆 칸 쪽이면 문틈을 낸다
	for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local ni, nj = i + d[1], j + d[2]
		if not ctx.isWall(ni, nj) then
			local dir = Vector3.new(d[1], 0, d[2])
			local along = Vector3.new(d[2], 0, -d[1])
			local entry = false
			for _, e in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				if same(ctx, ni + e[1], nj + e[2], "D") then
					entry = true
				end
			end
			local c = p + dir * (T / 2 - 0.2)
			local cf = CFrame.lookAt(c, c + dir)
			if entry then
				-- 문틈(3.2)은 벽에서 먼 쪽 끝: 칸막이 한 토막 + 문 위 인방 + 반쯤 열린 문짝
				local s = 1
				for _, w in walls do
					if w:Dot(along) > 0.5 then
						s = -1
					end
				end
				local len = T - 3.2
				Kit.box(m, CFrame.new(c + along * (-s * (T / 2 - len / 2)) + Vector3.new(0, hgt / 2, 0)) * cf.Rotation, Vector3.new(len, hgt, 0.4))
				Kit.box(m, CFrame.new(c + along * (s * (T / 2 - 1.6)) + Vector3.new(0, hgt - 0.6, 0)) * cf.Rotation, Vector3.new(3.2, 1.2, 0.4), { blocks = false })
			else
				Kit.box(m, CFrame.new(c + Vector3.new(0, hgt / 2, 0)) * cf.Rotation, Vector3.new(T, hgt, 0.4))
			end
		end
	end
	-- 설비: 첫째 벽(a)을 따라 욕조, 둘째 벽(b, 있으면)을 따라 변기와 세면대
	local a = walls[1] or Vector3.new(0, 0, -1)
	local b = walls[2]
	if not b or math.abs(b:Dot(a)) > 0.5 then
		b = Vector3.new(a.Z, 0, -a.X)
	end
	local function at(u: number, v: number, y: number): Vector3
		return p + a * u + b * v + Vector3.new(0, y, 0)
	end
	local rot = CFrame.lookAt(Vector3.zero, a).Rotation
	local n0 = #m:GetChildren() -- (여기부터 설비: 메시로 입힌다. 칸막이는 벽 판이라 기본 도형 그대로)
	local tubLong = if math.abs(b.X) > 0.5 then Vector3.new(5.4, 1.8, 2.6) else Vector3.new(2.6, 1.8, 5.4)
	Kit.box(m, CFrame.new(at(T / 2 - 1.6, -1.0, 0.9)), tubLong, { blocks = false }) -- 욕조
	-- 변기(둘째 벽 쪽, 욕조에서 먼 쪽)
	Kit.cylinder(m, at(-0.6, T / 2 - 1.6, 0), at(-0.6, T / 2 - 1.6, 1.3), 0.7, { blocks = false }) -- 변기
	-- 세면대 + 거울
	Kit.box(m, CFrame.new(at(-2.6, T / 2 - 0.9, 1.4)) * rot, Vector3.new(2.2, 2.8, 1.6), { blocks = false }) -- 세면대 장
	local fixtures = {}
	for k, x in m:GetChildren() do
		if k > n0 and x:IsA("BasePart") then
			table.insert(fixtures, x)
		end
	end
	local fcf = CFrame.fromMatrix(p, b, Vector3.yAxis) -- (소품 좌표: X = 둘째 벽 b, Z = b × 위 = ±첫째 벽 a)
	PM.dress(m, if fcf.ZVector:Dot(a) > 0 then "Hotel.BathFixtures" else "Hotel.BathFixturesM", fcf, nil, fixtures)
end

-- 책상(창가 벽) + 의자 + 벽걸이 TV + 스탠드
function P.WritingDesk(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j)
	local axis = Vector3.new(side.Z, 0, -side.X)
	local cf = frame(p, axis, -side) -- 로컬 +Z = 벽
	local m = model(ctx, "WritingDesk")
	local back = ctx.T / 2 - 1.3
	Kit.box(m, cf * CFrame.new(0, 3.0, back), Vector3.new(5.0, 0.2, 2.2), { blocks = false }) -- 상판
	Kit.box(m, cf * CFrame.new(-1.6, 1.45, back), Vector3.new(1.6, 2.9, 2.0), { blocks = false }) -- 서랍 받침(옆판 둘 대신 하나, 4차)
	Kit.box(m, cf * CFrame.new(0, 5.6, ctx.T / 2 - 0.15), Vector3.new(3.8, 2.2, 0.2), { blocks = false, collide = false }) -- 벽걸이 TV
	local ch = cf * CFrame.new(0.6, 0, back - 2.0) * CFrame.Angles(0, ctx.hash(i, j, 67) * 0.8 - 0.4, 0)
	Kit.box(m, ch * CFrame.new(0, 0.95, 0), Vector3.new(1.7, 1.9, 1.7), { blocks = false, collide = false }) -- 의자(좌판까지 한 덩어리)
	Kit.box(m, ch * CFrame.new(0, 2.9, -0.8), Vector3.new(1.7, 2.0, 0.15), { blocks = false, collide = false }) -- 등받이
	Kit.box(m, cf * CFrame.new(0, 1.6, back - 0.6), Vector3.new(5.0, 3.2, 3.4), { invisible = true, tag = false })
	PM.dress(m, "Hotel.WritingDesk", cf) -- (칸 가운데 바닥, +Z = 벽)
end

-- 짐 받침대(접이식 다리) + 여행 가방
function P.LuggageRack(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j)
	local axis = Vector3.new(side.Z, 0, -side.X)
	local cf = frame(p, axis, -side) * CFrame.new(0, 0, ctx.T / 2 - 1.4)
	local m = model(ctx, "LuggageRack")
	Kit.box(m, cf * CFrame.new(0, 1.0, 0), Vector3.new(3.0, 2.1, 1.6), { blocks = false }) -- 받침대(다리 + 끈 한 덩어리, 4차)
	local open = ctx.hash(i, j, 68) > 0.6
	Kit.box(m, cf * CFrame.new(0, 2.65, 0), Vector3.new(2.8, if open then 0.6 else 1.1, 1.7), { blocks = false }) -- 가방
	if open then -- 열린 채 버려진 가방: 뚜껑이 벽에 기대 있다
		Kit.box(m, cf * CFrame.new(0, 3.6, 1.1) * CFrame.Angles(0.35, 0, 0), Vector3.new(2.8, 1.8, 0.25), { blocks = false, collide = false })
	end
	Kit.box(m, cf * CFrame.new(0, 1.6, 0), Vector3.new(3.0, 3.2, 1.9), { invisible = true, tag = false })
	PM.dress(m, if open then "Hotel.LuggageRackOpen" else "Hotel.LuggageRack", cf) -- (받침대 밑 바닥, +Z = 벽)
end

-- 붙박이 옷장(숨는 곳이 아닌 것): 벽에 붙은 키 큰 상자 + 문 틈 + 손잡이 둘
function P.Wardrobe(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j)
	local axis = Vector3.new(side.Z, 0, -side.X)
	local cf = frame(p, axis, -side)
	local m = model(ctx, "Wardrobe")
	local back = ctx.T / 2 - 1.1
	Kit.box(m, cf * CFrame.new(0, 3.8, back), Vector3.new(4.4, 7.6, 2.2))
	Kit.box(m, cf * CFrame.new(0, 3.8, back - 1.12), Vector3.new(0.08, 7.0, 0.08), { blocks = false, collide = false }) -- 문 틈
	PM.dress(m, "Hotel.Wardrobe", cf * CFrame.new(0, 0, back)) -- (옷장 밑 바닥, -Z = 문 쪽)
end

-- ── 로비 ──
-- 분수: 3x3 칸 가운데에서 지름 20 의 둥근 수반 + 가운데 기둥 + 위 받침 접시 + 꼭대기 장식
function P.Fountain(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "Fountain")
	Kit.cylinder(m, p, p + Vector3.new(0, 1.8, 0), 10.2) -- 수반 테두리(막힌다)
	Kit.cylinder(m, p + Vector3.new(0, 1.8, 0), p + Vector3.new(0, 1.95, 0), 9.4, { blocks = false, collide = false }) -- 수면
	Kit.cylinder(m, p + Vector3.new(0, 1.8, 0), p + Vector3.new(0, 4.6, 0), 1.0, { blocks = false })
	Kit.cylinder(m, p + Vector3.new(0, 4.6, 0), p + Vector3.new(0, 5.2, 0), 3.6, { blocks = false }) -- 위 접시
	Kit.cylinder(m, p + Vector3.new(0, 5.2, 0), p + Vector3.new(0, 7.0, 0), 0.45, { blocks = false, collide = false })
	Kit.ball(m, p + Vector3.new(0, 7.3, 0), 0.6, { blocks = false, collide = false })
	PM.dress(m, "Hotel.Fountain", CFrame.new(p)) -- (수반 가운데 바닥)
end

-- 분수가 덮는 빈 칸(아무것도 짓지 않는다: 막힌 칸 표시만)
function P.Blank(_ctx, _i: number, _j: number) end

-- 샹들리에: 천장에서 내려온 사슬 + 위아래 둥근 고리 둘 + 가운데 수정 방울(머리 위라 지나갈 수 있다)
function P.Chandelier(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "Chandelier")
	local top = math.min(ctx.H, 14) - 0.1
	Kit.cylinder(m, p + Vector3.new(0, top, 0), p + Vector3.new(0, top - 2.2, 0), 0.08, { blocks = false, collide = false })
	Kit.cylinder(m, p + Vector3.new(0, top - 2.4, 0), p + Vector3.new(0, top - 2.1, 0), 3.0, { blocks = false, collide = false })
	Kit.cylinder(m, p + Vector3.new(0, top - 3.3, 0), p + Vector3.new(0, top - 3.0, 0), 1.9, { blocks = false, collide = false })
	Kit.cylinder(m, p + Vector3.new(0, top - 4.2, 0), p + Vector3.new(0, top - 2.1, 0), 0.35, { blocks = false, collide = false })
	PM.dress(m, "Hotel.Chandelier", CFrame.new(p + Vector3.new(0, top - 13.9, 0))) -- (천장 13.9 기준 바닥, 낮은 천장이면 통째로 내린다)
end

-- ── 연회장 ──
-- 연회 무대: 칸마다 낮은 단(높이 1.6) + 앞 가장자리 띠, 해시로 연설대 하나
function P.BanquetStage(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j, Vector3.new(0, 0, -1))
	local m = model(ctx, "BanquetStage")
	Kit.box(m, CFrame.new(p + Vector3.new(0, 0.8, 0)), Vector3.new(ctx.T, 1.6, ctx.T))
	local edge = p - side * (ctx.T / 2 - 0.1) + Vector3.new(0, 1.0, 0)
	Kit.box(m, CFrame.lookAt(edge, edge + side), Vector3.new(ctx.T, 0.3, 0.2), { blocks = false, collide = false })
	if ctx.hash(i, j, 69) > 0.6 then
		local lp = p + Vector3.new(0, 1.6, 0)
		Kit.box(m, CFrame.lookAt(lp + Vector3.new(0, 1.9, 0), lp + Vector3.new(0, 1.9, 0) - side), Vector3.new(1.8, 3.8, 1.2), { blocks = false })
	end
	PM.dress(m, if ctx.hash(i, j, 69) > 0.6 then "Hotel.BanquetStagePodium" else "Hotel.BanquetStage", CFrame.lookAt(p, p - side)) -- (단 가운데 바닥, -Z = 객석 쪽)
end

return P
