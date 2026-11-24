--!nonstrict
-- 챕터 6 호텔 전용 소품(구역마다 실제로 있어야 할 장비·가구). MapKit 부품만 쓴다(직접 만든 에셋).
--   F 프런트 데스크(로비 랜드마크: 길게 이어지는 카운터 + 높은 접수대 + 모니터)
--   G 짐 카트(황동 새장 모양 트롤리: 아치 손잡이 + 기둥 넷)       w 소파(로비·라운지·스위트 거실)
--   q 바 카운터(라운지 바, 손님 쪽 바 의자)                       U 원형 테이블 + 의자 넷(연회장·레스토랑·직원 식당)
--   K 업소용 화구(가스레인지 + 위 후드·덕트: 주방 랜드마크)        P 스테인리스 조리대(아래 선반)
--   W 업소용 세탁기(둥근 문)                                       j 린넨 선반(접힌 수건·시트 더미)
--   l 직원 사물함 줄(좁은 문 셋)                                   h 하우스키핑 카트(선반 + 빨래 자루 + 손잡이)
--   V 제빙기·자판기(층 제빙기실)                                   e 엘리베이터 문(문틀 + 두 짝 문 + 층 표시판 + 호출 버튼)
-- 각 함수는 StageBuilder 의 ctx 와 타일 좌표(i, j)를 받는다. 1층 천장은 11(2층 건물)이라 모든 소품은 바닥에서 10 아래.

local Kit = require(script.Parent.Parent.MapKit)

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
	-- 손님 쪽: 가로 줄이면 남쪽(+Z), 세로 줄이면 동쪽(+X)
	local front = if math.abs(axis.X) > 0.5 then Vector3.new(0, 0, 1) else Vector3.new(1, 0, 0)
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
end

-- 짐 카트: 카펫 바닥판 + 바퀴 넷 + 기둥 넷 + 위 아치 손잡이 + 옷걸이 봉 + 여행 가방 둘
function P.LuggageCart(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local yaw = ctx.hash(i, j, 62) * 1.2 - 0.6
	local cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
	local m = model(ctx, "LuggageCart")
	Kit.box(m, cf * CFrame.new(0, 0.9, 0), Vector3.new(2.6, 0.3, 4.4), { blocks = false }) -- 바닥판
	for _, x in { -1.1, 1.1 } do
		for _, z in { -1.9, 1.9 } do
			Kit.cylinder(m, (cf * CFrame.new(x, 0.35, z)).Position, (cf * CFrame.new(x + 0.15 * math.sign(x), 0.35, z)).Position, 0.35, { blocks = false, collide = false })
		end
	end
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
end

-- 원형 테이블 + 의자 넷(연회장·레스토랑)
function P.RoundTable(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local yaw = ctx.hash(i, j, 63) * math.pi
	local cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
	local m = model(ctx, "RoundTable")
	Kit.cylinder(m, (cf * CFrame.new(0, 2.9, 0)).Position, (cf * CFrame.new(0, 3.1, 0)).Position, 2.2, { blocks = false }) -- 상판
	Kit.cylinder(m, (cf * CFrame.new(0, 0, 0)).Position, (cf * CFrame.new(0, 2.9, 0)).Position, 0.25, { blocks = false }) -- 다리
	Kit.cylinder(m, (cf * CFrame.new(0, 0, 0)).Position, (cf * CFrame.new(0, 0.15, 0)).Position, 1.0, { blocks = false, collide = false })
	for k = 0, 3 do
		local a = k * math.pi / 2 + 0.3
		local c = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -3.1)
		Kit.box(m, c * CFrame.new(0, 1.8, 0), Vector3.new(1.5, 0.18, 1.5), { blocks = false, collide = false }) -- 좌판
		Kit.box(m, c * CFrame.new(0, 2.9, -0.7), Vector3.new(1.5, 2.0, 0.15), { blocks = false, collide = false }) -- 등받이
		Kit.box(m, c * CFrame.new(0, 0.9, 0), Vector3.new(0.2, 1.8, 0.2), { blocks = false, collide = false })
	end
	Kit.box(m, CFrame.new(p + Vector3.new(0, 1.5, 0)), Vector3.new(4.6, 3, 4.6), { invisible = true, tag = false })
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
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			Kit.box(m, cf * CFrame.new(x * (L / 2 - 0.2), 1.5, z * 1.3), Vector3.new(0.15, 3.0, 0.15), { blocks = false, collide = false })
		end
	end
	local h = ctx.hash(i, j, 64)
	Kit.box(m, cf * CFrame.new((h - 0.5) * 3, 3.5, 0.4), Vector3.new(1.8, 0.8, 1.2), { blocks = false, collide = false }) -- 통
	Kit.box(m, cf * CFrame.new(0, 1.5, 0), Vector3.new(L, 3, 3), { invisible = true, tag = false })
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
	for _, x in { -1, 1 } do
		for _, z in { -0.9, 0.9 } do
			Kit.box(m, cf * CFrame.new(x * (L / 2 - 0.1), 3.6, back + z), Vector3.new(0.15, 7.2, 0.15), { blocks = false, axis = "Y" })
		end
	end
	for k, y in { 0.4, 2.3, 4.2, 6.1 } do
		Kit.box(m, cf * CFrame.new(0, y, back), Vector3.new(L, 0.1, 2.0), { blocks = false, collide = k == 1, shape = "None" })
		if k < 4 then
			local h = ctx.hash(i * 4 + k, j, 65)
			for q = -1, 1, 2 do
				Kit.box(m, cf * CFrame.new(q * 1.8 + (h - 0.5), y + 0.55, back), Vector3.new(2.6, 0.9 + h * 0.5, 1.6), { blocks = false, collide = false })
			end
		end
	end
	Kit.box(m, cf * CFrame.new(0, 3.6, back), Vector3.new(L, 7.2, 2.0), { invisible = true, tag = false })
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
end

-- 하우스키핑 카트: 선반 셋 상자 + 한쪽 빨래 자루 + 반대쪽 손잡이 + 바퀴
function P.HousekeepingCart(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j)
	local axis = Vector3.new(side.Z, 0, -side.X)
	local cf = frame(p, axis, -side) * CFrame.new(0, 0, ctx.T / 2 - 2.0)
	local m = model(ctx, "HousekeepingCart")
	Kit.box(m, cf * CFrame.new(0, 0.6, 0), Vector3.new(4.6, 0.2, 2.2), { blocks = false })
	Kit.box(m, cf * CFrame.new(0, 2.2, 0), Vector3.new(4.6, 0.15, 2.2), { blocks = false, collide = false })
	Kit.box(m, cf * CFrame.new(0, 3.8, 0), Vector3.new(4.6, 0.2, 2.2), { blocks = false })
	for _, x in { -2.2, 2.2 } do
		Kit.box(m, cf * CFrame.new(x, 2.2, 0), Vector3.new(0.2, 3.4, 2.2), { blocks = false })
	end
	Kit.box(m, cf * CFrame.new(-0.8, 3.0, 0), Vector3.new(1.6, 1.4, 1.6), { blocks = false, collide = false }) -- 수건 더미
	Kit.box(m, cf * CFrame.new(1.0, 4.3, 0), Vector3.new(1.0, 0.8, 0.8), { blocks = false, collide = false }) -- 세제통
	Kit.box(m, cf * CFrame.new(3.3, 2.0, 0), Vector3.new(1.8, 3.2, 2.0), { blocks = false }) -- 빨래 자루
	Kit.cylinder(m, (cf * CFrame.new(-2.9, 3.6, -0.9)).Position, (cf * CFrame.new(-2.9, 3.6, 0.9)).Position, 0.1, { blocks = false, collide = false }) -- 손잡이
	for _, x in { -1.9, 1.9 } do
		Kit.cylinder(m, (cf * CFrame.new(x, 0.3, -1.15)).Position, (cf * CFrame.new(x, 0.3, 1.15)).Position, 0.3, { blocks = false, collide = false })
	end
	Kit.box(m, cf * CFrame.new(0.5, 2.2, 0), Vector3.new(6.6, 4.4, 2.4), { invisible = true, tag = false })
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
end

return P
