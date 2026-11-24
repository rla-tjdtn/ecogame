--!strict
-- STAGE 10 — 폐영화관 (47x43칸, tools/places/cinema.js 로 생성)
-- 실제 멀티플렉스 구조를 가로 띠 셋으로 갈지자로 지난다(2층 = UpperRects 영사실 층, 계단 1·2). 띠마다 갈래가 셋 이상이라 막힌 곳은 돌아간다.
-- 남쪽 띠: 매표소(시작) → 로비(매점 섬 카운터 C·팝콘 기계 M 을 사이에 두고 북·남 두 줄, 검표대 g·줄 기둥 r·포스터 F)와
-- 아래 방 줄(남녀 화장실·청소도구함·직원 휴게실·창고, 샛문으로 이어짐) → 서쪽 넓은 복도, 또는 검표구 옆 샛문으로 비상구 복도.
-- 가운데 띠: 메인 복도(뒷문) · 상영관 4개(경사 좌석 u, 남쪽 스크린 W, 양옆 통로)와 직원 통로 2개 · 비상구 복도(앞문)가 서로 엮이고,
-- 그 위 2층 영사실 층(영사 복도 + 영사실 1·필름 창고·영사실 2·되감기실·영사실 3 이 샛문으로 이어짐)이 나란히 동쪽으로 간다.
-- 계단 둘: 로비 쪽 계단(메인 복도 서쪽 끝 → 2층), 영사실 비상계단(2층 동쪽 → 북쪽 띠). 1층만으로도(동쪽 직원 복도), 2층으로도 북쪽 띠에 닿는다.
-- 북쪽 띠(직원 구역): 북쪽 직원 통로 · 뒤 복도 사이에 직원 사무실·관리실·필름 하역 창고·기계실·직원 휴게실이 샛문으로 이어져 서쪽 하역장(출구).
-- 출구까지 최단 약 141칸.
local Props = require(script.Parent.Parent.Props)

local function base(ctx: any, i: number, j: number): Vector3
	return ctx.center(i, j) + Vector3.new(0, ctx.floorY(i, j), 0)
end

-- 가장 가까운 벽 방향(없으면 nil)
local function wallDir(ctx: any, i: number, j: number): Vector3?
	for _, d in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
		if ctx.isWall(i + d[1], j + d[2]) then
			return Vector3.new(d[1], 0, d[2])
		end
	end
	return nil
end

-- ── 좌석 줄: 한 칸에 의자 3개. 스크린에서 멀수록 높은 단(계단식 객석) 위에 놓인다 ──
local function seats(ctx: any, i: number, j: number, dz: number)
	local Kit = ctx.Kit
	local T = ctx.T
	local p = base(ctx, i, j)
	-- 스크린 쪽 벽까지 칸 수 → 단 높이
	local n = 1
	while n < 20 and not ctx.isWall(i, j + dz * n) do
		n += 1
	end
	local h = math.max(0, n - 3) * 1.0
	local face = Vector3.new(0, 0, dz) -- 의자가 바라보는 쪽(스크린)
	local back = -face
	local m = Instance.new("Model")
	m.Name = "TheaterSeats"
	m.Parent = ctx.props
	if h > 0.05 then
		Kit.box(m, CFrame.new(p + Vector3.new(0, h / 2, 0)), Vector3.new(T, h, T), { blocks = false, name = "SeatRiser" })
	end
	local y = p.Y + h
	local row = Vector3.new(p.X, y, p.Z) + back * 0.8
	-- 받침 + 방석 + 등받이(뒤로 살짝 젖힘)
	Kit.box(m, CFrame.lookAt(row + Vector3.new(0, 0.7, 0), row + Vector3.new(0, 0.7, 0) + face), Vector3.new(T - 0.6, 1.4, 1.2), { blocks = false })
	local cush = row + Vector3.new(0, 1.65, 0) - back * 0.2
	Kit.box(m, CFrame.lookAt(cush, cush + face), Vector3.new(T - 0.3, 0.5, 2.0), { blocks = false })
	local bk = row + Vector3.new(0, 3.0, 0) + back * 1.0
	Kit.box(m, CFrame.lookAt(bk, bk + face) * CFrame.Angles(-0.18, 0, 0), Vector3.new(T - 0.3, 2.4, 0.35), { blocks = false })
	-- 팔걸이(의자 사이): 왼쪽 끝은 늘, 오른쪽 끝은 옆 칸이 좌석이 아닐 때만
	local here = ctx.at(i, j)
	for k = 0, 3 do
		local x = -T / 2 + 0.15 + k * (T - 0.3) / 3
		if k < 3 or ctx.at(i + 1, j) ~= here then
			local a = row + Vector3.new(x, 2.2, 0)
			Kit.box(m, CFrame.new(a), Vector3.new(0.3, 0.25, 2.0), { blocks = false, collide = false })
		end
	end
	-- 들어가지 못하게 막는 투명 충돌 상자
	Kit.box(m, CFrame.new(p + Vector3.new(0, (h + 4) / 2, 0)), Vector3.new(T, h + 4, T), { invisible = true, tag = false })
end

local function seatsNorth(ctx: any, i: number, j: number)
	seats(ctx, i, j, -1)
end
local function seatsSouth(ctx: any, i: number, j: number)
	seats(ctx, i, j, 1)
end

-- ── 스크린 벽: 벽에 붙은 큰 흰 막(찢어진 곳 하나) + 위아래 검은 테두리 + 낮은 무대 ──
local function screen(ctx: any, i: number, j: number)
	local Kit = ctx.Kit
	local T = ctx.T
	local p = base(ctx, i, j)
	local side = if ctx.isWall(i, j - 1) then Vector3.new(0, 0, -1) else Vector3.new(0, 0, 1)
	local m = Instance.new("Model")
	m.Name = "Screen"
	m.Parent = ctx.props
	local wallFace = p + side * (T / 2 - 0.3)
	local sh = ctx.H - 4.5
	local sc = wallFace + Vector3.new(0, 2.5 + sh / 2, 0)
	local torn = ctx.hash(i, j, 101) < 0.25
	if torn then
		-- 찢어져 늘어진 막: 위쪽 반만 + 아래로 기울어진 조각
		Kit.box(m, CFrame.lookAt(sc + Vector3.new(0, sh / 4, 0), sc + Vector3.new(0, sh / 4, 0) - side), Vector3.new(T, sh / 2, 0.15), { blocks = false })
		local flap = sc - Vector3.new(0, sh / 4, 0) - side * 0.8
		Kit.box(m, CFrame.lookAt(flap, flap - side) * CFrame.Angles(0.25, 0, 0.12), Vector3.new(T * 0.7, sh / 2, 0.12), { blocks = false, collide = false })
	else
		Kit.box(m, CFrame.lookAt(sc, sc - side), Vector3.new(T, sh, 0.15), { blocks = false })
	end
	for _, y in { 2.3, 2.5 + sh + 0.2 } do
		local b = wallFace + Vector3.new(0, y, 0) - side * 0.1
		Kit.box(m, CFrame.lookAt(b, b - side), Vector3.new(T, 0.5, 0.4), { blocks = false, collide = false })
	end
	-- 무대(스크린 앞 낮은 단)
	local st = p + side * 1.0 + Vector3.new(0, 0.6, 0)
	Kit.box(m, CFrame.lookAt(st, st - side), Vector3.new(T, 1.2, T - 2.0), { name = "Stage" })
end

-- ── 매점·매표 카운터 ──
local function counter(ctx: any, i: number, j: number)
	local Kit = ctx.Kit
	local T = ctx.T
	local p = base(ctx, i, j)
	local alongX = ctx.at(i - 1, j) == "C" or ctx.at(i + 1, j) == "C"
	local len, dep = T, 3.0
	local size = if alongX then Vector3.new(len, 3.4, dep) else Vector3.new(dep, 3.4, len)
	local m = Instance.new("Model")
	m.Name = "Counter"
	m.Parent = ctx.props
	Kit.box(m, CFrame.new(p + Vector3.new(0, 1.7, 0)), size, { name = "CounterBody" })
	local top = if alongX then Vector3.new(len, 0.25, dep + 0.6) else Vector3.new(dep + 0.6, 0.25, len)
	Kit.box(m, CFrame.new(p + Vector3.new(0, 3.5, 0)), top, { blocks = false })
	-- 유리 진열 가림막
	local glass = if alongX then Vector3.new(len - 0.4, 1.6, 0.1) else Vector3.new(0.1, 1.6, len - 0.4)
	Kit.box(m, CFrame.new(p + Vector3.new(0, 4.5, 0)), glass, { blocks = false, collide = false })
	-- 금전 등록기(군데군데)
	if ctx.hash(i, j, 103) < 0.35 then
		Kit.box(m, CFrame.new(p + Vector3.new(1.2, 4.0, 0)), Vector3.new(1.4, 0.8, 1.2), { blocks = false, collide = false })
	end
end

-- ── 팝콘 기계(벽 쪽): 아래 수납장 + 유리 상자(네 기둥) + 안쪽 솥 + 위 간판 ──
local function popcorn(ctx: any, i: number, j: number)
	local Kit = ctx.Kit
	local T = ctx.T
	local p = base(ctx, i, j)
	local side = wallDir(ctx, i, j) or Vector3.new(0, 0, -1)
	local c = p + side * (T / 2 - 1.8)
	local m = Instance.new("Model")
	m.Name = "Popcorn"
	m.Parent = ctx.props
	Kit.box(m, CFrame.lookAt(c + Vector3.new(0, 1.8, 0), c + Vector3.new(0, 1.8, 0) - side), Vector3.new(4.0, 3.6, 3.0), { name = "PopcornBase" })
	local across = Vector3.new(side.Z, 0, -side.X)
	for _, a in { -1, 1 } do
		for _, b in { -1, 1 } do
			local q = c + across * (a * 1.8) + side * (b * 1.3)
			Kit.box(m, CFrame.new(q + Vector3.new(0, 5.4, 0)), Vector3.new(0.2, 3.6, 0.2), { blocks = false, collide = false })
		end
	end
	Kit.box(m, CFrame.lookAt(c + Vector3.new(0, 7.4, 0), c + Vector3.new(0, 7.4, 0) - side), Vector3.new(4.0, 0.4, 3.0), { blocks = false })
	Kit.cylinder(m, c + Vector3.new(0, 5.8, 0), c + Vector3.new(0, 6.8, 0), 0.9, { blocks = false, collide = false })
	Kit.cylinder(m, c + Vector3.new(0, 6.8, 0), c + Vector3.new(0, 7.2, 0), 0.12, { blocks = false, collide = false })
	-- 바닥에 쏟아진 팝콘 무더기
	Kit.box(m, CFrame.new(c + Vector3.new(0, 3.8, 0)), Vector3.new(3.4, 0.3, 2.4), { blocks = false, collide = false })
	Kit.box(m, CFrame.lookAt(c + Vector3.new(0, 8.3, 0), c + Vector3.new(0, 8.3, 0) - side), Vector3.new(3.6, 1.4, 0.25), { blocks = false, collide = false })
end

-- ── 영사기: 받침대 + 몸체 + 렌즈(영사창 쪽) + 필름 릴 두 개 ──
local function projector(ctx: any, i: number, j: number)
	local Kit = ctx.Kit
	local p = base(ctx, i, j)
	local fwd = if ctx.isWall(i, j - 1) then Vector3.new(0, 0, -1) else Vector3.new(0, 0, 1)
	local m = Instance.new("Model")
	m.Name = "Projector"
	m.Parent = ctx.props
	Kit.box(m, CFrame.lookAt(p + Vector3.new(0, 1.6, 0), p + Vector3.new(0, 1.6, 0) + fwd), Vector3.new(2.4, 3.2, 3.0), { name = "ProjectorStand" })
	local body = p + Vector3.new(0, 4.4, 0)
	Kit.box(m, CFrame.lookAt(body, body + fwd), Vector3.new(1.8, 2.4, 3.6))
	Kit.cylinder(m, body + fwd * 1.8, body + fwd * 3.2, 0.45, { blocks = false, collide = false, rings = 1 })
	for _, z in { -1.0, 1.2 } do
		local r = body + Vector3.new(0, 2.6, 0) + fwd * z
		Kit.cylinder(m, r - Vector3.new(0.15, 0, 0), r + Vector3.new(0.15, 0, 0), 1.3, { blocks = false, collide = false, rings = 1 })
	end
	-- 영사창(벽에 뚫린 작은 창틀)
	local port = p + fwd * (ctx.T / 2 - 0.1) + Vector3.new(0, 4.6, 0)
	Kit.box(m, CFrame.lookAt(port, port + fwd), Vector3.new(2.4, 1.6, 0.3), { blocks = false, collide = false })
end

-- ── 포스터 액자(벽에 걸린 라이트박스): 지나갈 수 있다 ──
local function poster(ctx: any, i: number, j: number)
	local Kit = ctx.Kit
	local T = ctx.T
	local p = base(ctx, i, j)
	local side = wallDir(ctx, i, j)
	if not side then
		return
	end
	local c = p + side * (T / 2 - 0.25) + Vector3.new(0, 5.2, 0)
	local tilt = (ctx.hash(i, j, 105) - 0.5) * 0.12
	local cf = CFrame.lookAt(c, c - side) * CFrame.Angles(0, 0, tilt)
	Kit.box(ctx.props, cf, Vector3.new(3.6, 5.2, 0.35), { blocks = false, collide = false, name = "PosterFrame" })
	Kit.box(ctx.props, cf * CFrame.new(0, 0, -0.2), Vector3.new(3.0, 4.6, 0.08), { blocks = false, collide = false, name = "Poster" })
end

-- ── 줄 세우기 기둥(벨트로 이어짐): 지나갈 수 있게 벨트는 충돌 없음 ──
local function stanchion(ctx: any, i: number, j: number)
	local Kit = ctx.Kit
	local T = ctx.T
	local p = base(ctx, i, j)
	local a = p + Vector3.new(-T / 2 + 0.5, 0, 0)
	Kit.cylinder(ctx.props, a, a + Vector3.new(0, 3.2, 0), 0.15, { blocks = false })
	Kit.cylinder(ctx.props, a, a + Vector3.new(0, 0.2, 0), 0.6, { blocks = false, collide = false })
	if ctx.hash(i, j, 107) < 0.8 then
		local b = p + Vector3.new(T / 2 - 0.5, 0, 0)
		local sag = if ctx.hash(i, j, 108) < 0.3 then 1.6 else 0.2
		Kit.box(ctx.props, CFrame.lookAt((a + b) / 2 + Vector3.new(0, 2.9 - sag, 0), b + Vector3.new(0, 2.9 - sag, 0)), Vector3.new(0.05, 0.25, (b - a).Magnitude), { blocks = false, collide = false })
	end
	if ctx.at(i + 1, j) ~= "r" then
		local b = p + Vector3.new(T / 2 - 0.5, 0, 0)
		Kit.cylinder(ctx.props, b, b + Vector3.new(0, 3.2, 0), 0.15, { blocks = false })
	end
end

-- ── 검표대: 작은 연단 + 기울어진 윗판 ──
local function ticketStand(ctx: any, i: number, j: number)
	local Kit = ctx.Kit
	local p = base(ctx, i, j)
	Kit.box(ctx.props, CFrame.new(p + Vector3.new(0, 1.9, 0)), Vector3.new(2.6, 3.8, 2.0), { name = "TicketStand" })
	Kit.box(ctx.props, CFrame.new(p + Vector3.new(0, 4.0, 0)) * CFrame.Angles(0.3, 0, 0), Vector3.new(3.0, 0.2, 2.4), { blocks = false, collide = false })
	-- 넘어진 안내판
	Kit.box(ctx.props, CFrame.new(p + Vector3.new(2.4, 0.2, 1.5)) * CFrame.Angles(0, 0.5, 0), Vector3.new(2.2, 0.3, 3.0), { blocks = false, collide = false })
end

-- ── 화장실 세면대 + 거울 ──
local function sink(ctx: any, i: number, j: number)
	local Kit = ctx.Kit
	local T = ctx.T
	local p = base(ctx, i, j)
	local side = wallDir(ctx, i, j) or Vector3.new(0, 0, -1)
	local c = p + side * (T / 2 - 1.2)
	Kit.box(ctx.props, CFrame.lookAt(c + Vector3.new(0, 2.9, 0), c + Vector3.new(0, 2.9, 0) - side), Vector3.new(T - 0.5, 0.6, 2.2), { name = "SinkTop" })
	Kit.box(ctx.props, CFrame.lookAt(c + Vector3.new(0, 1.3, 0), c + Vector3.new(0, 1.3, 0) - side), Vector3.new(T - 1.5, 2.6, 1.6), { blocks = false })
	local mir = p + side * (T / 2 - 0.1) + Vector3.new(0, 5.6, 0)
	Kit.box(ctx.props, CFrame.lookAt(mir, mir - side), Vector3.new(T - 1.0, 3.0, 0.1), { blocks = false, collide = false })
end

return {
	Seed = 101,
	PipeChance = 0.1,
	HideStyle = "locker", -- 숨는 곳(L): 철제 사물함·청소도구함·화장실 칸
	SearchStyle = "drawers", -- 뒤지는 곳(Z): 매점 서랍·영사기 필름 캐비닛·사무 서랍, 그중 한 곳에 열쇠
	Props = { q = seatsNorth, u = seatsSouth, W = screen, C = counter, M = popcorn, P = projector, F = poster, r = stanchion, g = ticketStand, V = sink, T = Props.Desk },
	Walkable = { F = true, r = true },
	UpperRects = { { 5, 12, 42, 17 } }, -- 2층 구역(타일 좌표 i0, j0, i1, j1)
	Rows = {
		"###############################################",
		"##..................c........................Z#",
		"##...............................c............#",
		"##.c..c.####D#############D##############D##..#",
		"##.....Z#Z.....#mm...Z#c.....c#mm...m#.....Z..#",
		"#E..T...D.T..T.D......D.......D......D..T.....#",
		"##...c..#.....L#L.....#..c..Z.#Z....L#.....L..#",
		"##.c....###########D####D#########D#########..#",
		"##..........................c.................#",
		"##L...........c...............................#",
		"########################################1###..#",
		"####Z.....L#c..c#mL....m#...Z#m...L.Z.m#2###..#",
		"####.......D....D.......D....D.........D..##..#",
		"####..P..P.#...Z#...P...#T...#.P...P...#.c##..#",
		"#######D#####D######D#####D#####D####D##..##..#",
		"####..............c.......................##..#",
		"#####2#........................c..........##..#",
		"#####1######################################..#",
		"#.........F................F.....F............#",
		"#......................c......................#",
		"#..#D########D#D#D#####D#D#######D#D#D####D#..#",
		"#..#........L.#.#.....L.#.......L.#.#....L.#..#",
		"#..#..........#.#.......#.........#.#......#c.#",
		"#..#.uuu.uuuu.#.#.uuuuu.#.uuu.uuu.#.#.uuuu.#..#",
		"#..#.uuu.uuuu.#c#.uuuuu.#.ccu.uuu.#.#.uuuu.#..#",
		"#..#.uuu.uuuu.#.#.uuuuu.#.uuu.uuu.#.#.uuuu.#..#",
		"#..#..........#.#.......#.........#.#......#..#",
		"#..#.ZWWWWWW..#.#.ZWWW..#.ZWWWWW..#.#.ZWW..#..#",
		"#..#D########D#D#D#####D#D#######D#D#D####D#..#",
		"#Z..........c.................................#",
		"#...................F........................L#",
		"#..###D########################################",
		"#..#...F.....F........rrrrrrrrrr...F..Z#.....L#",
		"#..A......g............................D..SS..#",
		"#..#...........O....CCCCCCCCCCC...O....#..SS..#",
		"#..#......g..........M..M...M..........#......#",
		"#..A...........O.......................#......#",
		"#..#L.....g.......F....................#.CCC..#",
		"#..####D######D##########D########D#####......#",
		"#..#Z....V#V.....#c..#......Z#......c..#....T.#",
		"#..D......D......D...D.......D.........D......#",
		"#..#.L.L..#.L.L.Z#..L#L.T.T..#cc......Z#.....Z#",
		"###############################################",
	},
}
