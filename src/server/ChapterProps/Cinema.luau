--!nonstrict
-- 챕터 10 폐영화관 전용 소품(타일 문자 → 함수). Stage10.luau 의 Props 줄에서 쓴다.
-- MapKit 부품만(검은 무광, 음파 윤곽선). 굵은 윤곽 위주, 막는 소품은 보이지 않는 충돌 상자를 둔다.
--   상영관  q 계단식 좌석 줄   W 스크린·무대   a 통로 발밑등·벽 스피커(지나감)  x 쇠사슬 잠긴 비상구(지나감)  j 무너진 좌석 더미
--   로비    C 매점 카운터      M 팝콘 기계     N 음료 기계    Y 메뉴판(벽, 지나감)   t 높은 원탁   w 소파   y 입간판   d 분리수거대
--   매표소  B 매표 창구        H 상영 시간표(벽, 지나감)      k 무인 발권기          r 줄 기둥(지나감)         g 검표대
--   복도    F 포스터 액자(지나감)  h 상영관 번호판(지나감)  i 비상구 표지(지나감)
--   영사실  J 영사기·영사창    G 필름 되감기 대   e 앰프·전원 랙   R 필름 깡통 선반
--   그 밖   V 세면대·거울      U 화장실 칸     Q 짐수레(하역장)

local Kit = require(script.Parent.Parent.MapKit)

local P = {}

local LINE = { blocks = false, collide = false }
local SOFT = { blocks = false }

local function base(ctx, i: number, j: number): Vector3
	return ctx.center(i, j) + Vector3.new(0, ctx.floorY(i, j), 0)
end

local function wallSide(ctx, i: number, j: number): Vector3?
	for _, d in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
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

local function solid(m: Instance, cf: CFrame, size: Vector3)
	Kit.box(m, cf * CFrame.new(0, size.Y / 2, 0), size, { invisible = true, tag = false })
end

-- 같은 문자가 이어지는 방향(없으면 x)
local function runAxis(ctx, i: number, j: number, ch: string): Vector3
	if ctx.at(i, j - 1) == ch or ctx.at(i, j + 1) == ch then
		return Vector3.new(0, 0, 1)
	end
	return Vector3.new(1, 0, 0)
end

-- 벽을 등진 좌표계: 로컬 -Z = 방 안쪽, +Z = 벽 쪽. prefer 방향이 벽이면 그쪽을 쓴다
local function againstWall(ctx, i: number, j: number, prefer: Vector3?): CFrame
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j) or Vector3.new(0, 0, -1)
	if prefer and ctx.isWall(i + prefer.X, j + prefer.Z) then
		side = prefer
	end
	return CFrame.lookAt(p, p - side)
end

local function at(cf: CFrame, x: number, y: number, z: number): Vector3
	return (cf * CFrame.new(x, y, z)).Position
end

-- ── 상영관 ──

-- q 좌석 줄: 한 칸에 의자 3개, 북쪽 스크린을 본다. 스크린에서 멀수록 높은 단(계단식 객석) 위에 놓인다
local STEP = 0.55
function P.Seats(ctx, i: number, j: number)
	local T = ctx.T
	local p = base(ctx, i, j)
	-- 스크린(W)이 북쪽인지 남쪽인지: 좌석 줄을 따라 위아래로 훑어 먼저 만나는 W 쪽을 본다(없으면 북쪽)
	local dz = -1
	for k = 1, 14 do
		if ctx.at(i, j + k) == "W" then
			dz = 1
			break
		elseif ctx.at(i, j - k) == "W" then
			break
		end
	end
	local n = 1 -- 스크린 쪽 벽까지 칸 수
	while n < 20 and not ctx.isWall(i, j + dz * n) do
		n += 1
	end
	local h = math.max(0, n - 4) * STEP
	local m = model(ctx, "TheaterSeats")
	if h > 0.05 then
		Kit.box(m, CFrame.new(p + Vector3.new(0, h / 2, 0)), Vector3.new(T, h, T), { blocks = false, name = "SeatRiser" })
	end
	-- 로컬 -Z = 스크린 쪽. 한 칸 = 긴 의자 한 덩어리(방석 + 등받이) + 팔걸이 선 하나, 줄 끝 칸만 바깥 팔걸이를 더한다(부품 4~5개)
	local cf = CFrame.lookAt(p + Vector3.new(0, h, -dz * 0.8), p + Vector3.new(0, h, -dz * 0.8 + dz))
	Kit.box(m, cf * CFrame.new(0, 1.0, 0.2), Vector3.new(T - 0.3, 2.0, 2.0), SOFT)
	Kit.box(m, cf * CFrame.new(0, 3.0, 1.2) * CFrame.Angles(0.18, 0, 0), Vector3.new(T - 0.3, 2.4, 0.35), SOFT)
	Kit.box(m, cf * CFrame.new(-T / 2 + 0.15, 2.2, 0), Vector3.new(0.3, 0.25, 2.0), LINE)
	-- (줄 끝: 이웃 칸이 좌석이 아니면 그쪽 끝에도 팔걸이. 로컬 +X 가 어느 칸인지는 방향에 따라 바뀌므로 양쪽 다 본다)
	if ctx.at(i + 1, j) ~= "q" or ctx.at(i - 1, j) ~= "q" then
		Kit.box(m, cf * CFrame.new(T / 2 - 0.15, 2.2, 0), Vector3.new(0.3, 0.25, 2.0), LINE)
	end
	solid(m, CFrame.new(p), Vector3.new(T, h + 4, T))
end

-- j 무너진 좌석 더미: 뜯겨 넘어진 의자 줄 두 개
function P.BrokenSeats(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local yaw = (ctx.hash(i, j, 7) - 0.5) * 1.2
	local m = model(ctx, "BrokenSeats")
	for k = 0, 1 do
		local cf = CFrame.new(p + Vector3.new(0, 0.5 + k * 1.5, (k - 0.5) * 2.4)) * CFrame.Angles(0.3 + k * 0.8, yaw + k * 0.7, 0.15)
		Kit.box(m, cf, Vector3.new(6.0, 0.5, 2.0), SOFT)
		Kit.box(m, cf * CFrame.new(0, 1.3, 1.0), Vector3.new(6.0, 2.2, 0.35), SOFT)
		for _, x in { -2.9, -1, 1, 2.9 } do
			Kit.box(m, cf * CFrame.new(x, 0.6, 0), Vector3.new(0.3, 0.25, 2.0), LINE)
		end
	end
	solid(m, CFrame.new(p), Vector3.new(6.6, 3.6, 5.6))
end

-- W 스크린 벽: 벽에 붙은 큰 막(군데군데 찢어짐) + 위아래 테두리 + 낮은 무대, 줄 끝에는 막 옆 커튼
function P.Screen(ctx, i: number, j: number)
	local T = ctx.T
	local cf = againstWall(ctx, i, j, Vector3.new(0, 0, -1))
	local m = model(ctx, "Screen")
	local z = T / 2 - 0.3
	local sh = (if ctx.ceilAt then ctx.ceilAt(i, j) else ctx.H) - 4.5 -- (상영관은 두 층 높이: 지붕 아래까지 큰 스크린)
	local cy = 2.5 + sh / 2
	if ctx.hash(i, j, 101) < 0.25 then
		-- 찢어져 늘어진 막: 위쪽 반만 + 아래로 기울어진 조각
		Kit.box(m, cf * CFrame.new(0, cy + sh / 4, z), Vector3.new(T, sh / 2, 0.15), SOFT)
		Kit.box(m, cf * CFrame.new(0, cy - sh / 4, z - 0.8) * CFrame.Angles(0.25, 0, 0.12), Vector3.new(T * 0.7, sh / 2, 0.12), LINE)
	else
		Kit.box(m, cf * CFrame.new(0, cy, z), Vector3.new(T, sh, 0.15), SOFT)
	end
	for _, y in { 2.3, 2.5 + sh + 0.2 } do
		Kit.box(m, cf * CFrame.new(0, y, z - 0.1), Vector3.new(T, 0.5, 0.4), LINE)
	end
	for _, s in { -1, 1 } do
		if ctx.at(i + s, j) ~= "W" then
			-- 막 옆 커튼 주름 셋
			for k = 0, 2 do
				local q = base(ctx, i, j) + Vector3.new(s * (T / 2 - 0.5 - k * 0.9), (ctx.H - 0.6) / 2, -cf.LookVector.Z * (T / 2 - 0.9))
				Kit.box(m, CFrame.new(q) * CFrame.Angles(0, if k % 2 == 0 then 0.5 else -0.5, 0), Vector3.new(1.1, ctx.H - 1.6, 0.25), LINE)
			end
		end
	end
	Kit.box(m, cf * CFrame.new(0, 0.6, 1.0), Vector3.new(T, 1.2, T - 2.0), { name = "Stage" })
end

-- a 통로 발밑등(작은 등 + 바닥 선) + 벽 스피커: 양옆 통로, 지나갈 수 있다
function P.AisleLight(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "AisleLight")
	local z = ctx.T / 2
	Kit.box(m, cf * CFrame.new(0, 0.7, z - 0.2), Vector3.new(1.0, 0.5, 0.3), LINE)
	Kit.box(m, cf * CFrame.new(0, 7.4, z - 1.0) * CFrame.Angles(0.25, 0, 0), Vector3.new(2.0, 2.8, 1.4), LINE)
	Kit.box(m, cf * CFrame.new(0, 7.6, z - 0.2), Vector3.new(0.4, 0.4, 0.6), LINE)
end

-- x 잠긴 비상구: 두 짝 문 + 손잡이 봉에 감긴 쇠사슬·자물쇠 + EXIT 표지(지나갈 수 있는 칸, 문은 안 열린다)
function P.LockedExit(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j, Vector3.new(0, 0, -1))
	local m = model(ctx, "LockedExit")
	local z = ctx.T / 2
	for _, s in { -1, 1 } do
		Kit.box(m, cf * CFrame.new(s * 1.6, 3.6, z - 0.2), Vector3.new(3.1, 7.2, 0.3), LINE)
		Kit.cylinder(m, at(cf, s * 0.4, 3.4, z - 0.55), at(cf, s * 2.6, 3.4, z - 0.55), 0.14, LINE)
	end
	for k = 0, 2 do -- 쇠사슬(엇갈린 막대 셋)
		Kit.box(m, cf * CFrame.new(0, 3.4 + (k - 1) * 0.5, z - 0.7) * CFrame.Angles(0, 0, if k % 2 == 0 then 0.5 else -0.5), Vector3.new(3.0, 0.16, 0.16), LINE)
	end
	Kit.box(m, cf * CFrame.new(0, 2.5, z - 0.8), Vector3.new(0.8, 0.9, 0.3), LINE) -- 자물쇠
	Kit.word(m, "EXIT", at(cf, 0, 8.6, z - 0.3), -cf.RightVector, cf.LookVector, 1.4)
end

-- i 비상구 표지: 열리는 비상문 앞 천장에 매달린 표지판
function P.ExitSign(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "ExitSign")
	local y = ctx.H - 1.9
	Kit.box(m, CFrame.new(p + Vector3.new(0, y, 0)), Vector3.new(5.0, 1.8, 0.2), LINE)
	for _, x in { -1.8, 1.8 } do
		Kit.cylinder(m, p + Vector3.new(x, y + 0.9, 0), p + Vector3.new(x, ctx.H, 0), 0.08, LINE)
	end
	Kit.word(m, "EXIT", p + Vector3.new(0, y, 0.1), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), 1.2)
end

-- ── 매점 ──

-- (길이 방향 +X 를 보는 좌표계에서 로컬 +X = 남쪽 = 손님 쪽)
-- C 카운터(매점·라운지 바): 몸통 + 상판 + 유리 진열 가림막, 군데군데 금전 등록기
function P.Counter(ctx, i: number, j: number)
	local T = ctx.T
	local p = base(ctx, i, j)
	local axis = runAxis(ctx, i, j, "C")
	local cf = CFrame.lookAt(p, p + axis) -- 로컬 Z = 카운터 길이 방향
	local m = model(ctx, "Counter")
	Kit.box(m, cf * CFrame.new(0, 1.7, 0), Vector3.new(3.0, 3.4, T), { name = "CounterBody" })
	Kit.box(m, cf * CFrame.new(0, 3.5, 0), Vector3.new(3.6, 0.25, T), SOFT)
	Kit.box(m, cf * CFrame.new(0, 4.5, 0), Vector3.new(0.1, 1.6, T - 0.4), LINE)
	local r = ctx.hash(i, j, 103)
	if r < 0.3 then
		Kit.box(m, cf * CFrame.new(-0.9, 4.0, 1.2), Vector3.new(1.2, 0.8, 1.4), LINE) -- 금전 등록기
	elseif r > 0.75 then
		Kit.cylinder(m, at(cf, -0.9, 3.6, -1.4), at(cf, -0.9, 5.0, -1.4), 0.6, LINE) -- 남은 팝콘 통
	end
end

-- M 팝콘 기계(벽 쪽): 아래 수납장 + 유리 상자(네 기둥) + 안쪽 솥 + 위 간판
function P.Popcorn(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j, Vector3.new(0, 0, -1)) * CFrame.new(0, 0, ctx.T / 2 - 1.8)
	local m = model(ctx, "Popcorn")
	Kit.box(m, cf * CFrame.new(0, 1.8, 0), Vector3.new(4.0, 3.6, 3.0), { name = "PopcornBase" })
	for _, a in { -1.8, 1.8 } do
		for _, b in { -1.3, 1.3 } do
			Kit.box(m, cf * CFrame.new(a, 5.4, b), Vector3.new(0.2, 3.6, 0.2), LINE)
		end
	end
	Kit.box(m, cf * CFrame.new(0, 7.4, 0), Vector3.new(4.0, 0.4, 3.0), SOFT)
	Kit.cylinder(m, at(cf, 0, 5.8, 0), at(cf, 0, 6.8, 0), 0.9, LINE)
	Kit.cylinder(m, at(cf, 0, 6.8, 0), at(cf, 0, 7.2, 0), 0.12, LINE)
	Kit.box(m, cf * CFrame.new(0, 3.8, 0), Vector3.new(3.4, 0.3, 2.4), LINE) -- 남은 팝콘
	Kit.box(m, cf * CFrame.new(0, 8.3, 0), Vector3.new(3.6, 1.4, 0.25), LINE)
	solid(m, cf, Vector3.new(4.0, 7.6, 3.0))
end

-- N 음료 기계(벽 쪽): 몸통 + 앞으로 나온 머리 + 꼭지 넷 + 컵 탑
function P.Drink(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j, Vector3.new(0, 0, -1)) * CFrame.new(0, 0, ctx.T / 2 - 1.8)
	local m = model(ctx, "DrinkMachine")
	Kit.box(m, cf * CFrame.new(0, 1.6, 0), Vector3.new(5.0, 3.2, 3.0), { name = "DrinkBase" })
	Kit.box(m, cf * CFrame.new(0, 5.2, 0.8), Vector3.new(4.4, 4.0, 1.2), SOFT)
	Kit.box(m, cf * CFrame.new(0, 6.6, -0.3), Vector3.new(4.4, 1.6, 2.2), SOFT)
	for k = 0, 3 do
		local x = -1.5 + k
		Kit.cylinder(m, at(cf, x, 5.8, -0.9), at(cf, x, 5.1, -0.9), 0.15, LINE)
	end
	Kit.cylinder(m, at(cf, 1.9, 3.2, -0.8), at(cf, 1.9, 4.8, -0.8), 0.35, LINE)
	solid(m, cf, Vector3.new(5.0, 7.4, 3.0))
end

-- Y 메뉴판(벽 높이 달린 판 + 글줄): 지나갈 수 있다
function P.MenuBoard(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j, Vector3.new(0, 0, -1))
	local m = model(ctx, "MenuBoard")
	local z = ctx.T / 2
	Kit.box(m, cf * CFrame.new(0, 7.6, z - 0.4) * CFrame.Angles(0.12, 0, 0), Vector3.new(7.0, 3.0, 0.25), LINE)
	for k = -1, 1 do
		Kit.box(m, cf * CFrame.new(-0.6 + k * 0.4, 7.6 + k * 0.8, z - 0.65), Vector3.new(4.2, 0.18, 0.1), LINE)
	end
end

-- t 높은 원탁(서서 먹는 탁자): 기둥 + 둥근 판 + 남은 컵
function P.HighTable(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "HighTable")
	Kit.cylinder(m, p, p + Vector3.new(0, 0.2, 0), 1.2, LINE)
	Kit.cylinder(m, p, p + Vector3.new(0, 3.8, 0), 0.25, LINE)
	Kit.cylinder(m, p + Vector3.new(0, 3.8, 0), p + Vector3.new(0, 4.05, 0), 2.0, SOFT)
	local c = p + Vector3.new((ctx.hash(i, j, 31) - 0.5) * 2, 4.05, 0.6)
	Kit.cylinder(m, c, c + Vector3.new(0, 1.1, 0), 0.4, LINE)
	solid(m, CFrame.new(p), Vector3.new(3.4, 4.2, 3.4))
end

-- w 소파(대기 의자): 앉는 판 + 등받이 + 팔걸이. 남쪽을 본다
function P.Sofa(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.lookAt(p, p + Vector3.new(0, 0, 1)) -- 로컬 -Z = 앞(남쪽)
	local m = model(ctx, "Sofa")
	local T = ctx.T
	Kit.box(m, cf * CFrame.new(0, 1.0, 0), Vector3.new(T - 0.4, 2.0, 3.4), SOFT)
	Kit.box(m, cf * CFrame.new(0, 2.6, 1.5) * CFrame.Angles(0.12, 0, 0), Vector3.new(T - 0.4, 2.4, 0.8), SOFT)
	for _, s in { -1, 1 } do
		if ctx.at(i - s, j) ~= "w" then -- (로컬 x 는 남쪽을 보므로 격자 i 와 반대)
			Kit.box(m, cf * CFrame.new(s * (T / 2 - 0.5), 1.5, 0), Vector3.new(0.7, 3.0, 3.4), SOFT)
		end
	end
	solid(m, cf, Vector3.new(T - 0.4, 3.2, 3.8))
end

-- y 입간판(등신대): 사람 모양 판 + 받침. 어둠 속에서 사람처럼 보인다
function P.Standee(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.new(p) * CFrame.Angles(0, (ctx.hash(i, j, 41) - 0.5) * 0.8, 0)
	local m = model(ctx, "Standee")
	Kit.box(m, cf * CFrame.new(0, 0.2, 0), Vector3.new(4.2, 0.4, 2.0), LINE)
	Kit.box(m, cf * CFrame.new(0, 2.4, 0), Vector3.new(1.8, 4.2, 0.2), SOFT) -- 몸 아래
	Kit.box(m, cf * CFrame.new(0, 5.4, 0), Vector3.new(3.0, 2.2, 0.2), SOFT) -- 어깨
	for _, s in { -1, 1 } do
		Kit.box(m, cf * CFrame.new(s * 1.9, 4.6, 0) * CFrame.Angles(0, 0, s * 0.25), Vector3.new(0.6, 3.6, 0.2), LINE)
	end
	Kit.ball(m, at(cf, 0, 7.3, 0), 0.9, SOFT) -- 머리
	Kit.box(m, cf * CFrame.new(0, 2.0, 0.8) * CFrame.Angles(-0.35, 0, 0), Vector3.new(0.4, 4.2, 0.15), LINE) -- 뒤 버팀대
	solid(m, cf, Vector3.new(3.6, 7.6, 2.0))
end

-- d 분리수거대: 구멍 둘 난 통 + 윗선반에 쌓인 쟁반
function P.BinStation(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j) * CFrame.new(0, 0, ctx.T / 2 - 1.6)
	local m = model(ctx, "BinStation")
	Kit.box(m, cf * CFrame.new(0, 2.0, 0), Vector3.new(5.6, 4.0, 2.6), SOFT)
	for _, x in { -1.4, 1.4 } do
		Kit.box(m, cf * CFrame.new(x, 2.9, -1.33), Vector3.new(1.8, 1.0, 0.1), LINE)
	end
	Kit.box(m, cf * CFrame.new(0, 4.4, 0.3), Vector3.new(2.6, 0.7, 1.6), LINE)
	solid(m, cf, Vector3.new(5.6, 4.2, 2.6))
end

-- ── 매표소 ──

-- B 매표 창구: 카운터 + 유리 칸막이 틀 + 말구멍 + 화면. 한 칸이 창구 하나
function P.TicketWindow(ctx, i: number, j: number)
	local T = ctx.T
	local p = base(ctx, i, j)
	local axis = runAxis(ctx, i, j, "B")
	local cf = CFrame.lookAt(p, p + axis)
	local m = model(ctx, "TicketWindow")
	Kit.box(m, cf * CFrame.new(0, 1.8, 0), Vector3.new(2.8, 3.6, T), { name = "TicketCounter" })
	Kit.box(m, cf * CFrame.new(0, 3.7, 0), Vector3.new(3.4, 0.25, T), SOFT)
	for _, z in { -T / 2 + 0.15, T / 2 - 0.15 } do
		if z > 0 or ctx.at(i + axis.X, j + axis.Z) ~= "B" then
			Kit.box(m, cf * CFrame.new(0, 5.9, z), Vector3.new(0.3, 4.2, 0.3), LINE)
		end
	end
	Kit.box(m, cf * CFrame.new(0, 8.1, 0), Vector3.new(0.4, 0.5, T), LINE) -- 윗보
	Kit.box(m, cf * CFrame.new(0, 4.9, 0), Vector3.new(0.1, 0.12, T - 0.6), LINE) -- 유리 아래 테
	Kit.box(m, cf * CFrame.new(0, 5.6, 1.6) * CFrame.Angles(0, 0.2, 0), Vector3.new(0.3, 1.5, 2.0), LINE) -- 발권 화면
	solid(m, cf, Vector3.new(3.0, 8.2, T))
end

-- H 상영 시간표(벽 위 큰 판 + 줄): 지나갈 수 있다
function P.Showtimes(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j, Vector3.new(0, 0, -1))
	local m = model(ctx, "Showtimes")
	local z = ctx.T / 2
	Kit.box(m, cf * CFrame.new(0, 7.2, z - 0.3), Vector3.new(7.6, 4.2, 0.25), LINE)
	for k = 0, 3 do
		Kit.box(m, cf * CFrame.new((ctx.hash(i, j, 60 + k) - 0.5), 5.9 + k * 0.85, z - 0.5), Vector3.new(5.6, 0.16, 0.1), LINE)
	end
end

-- k 무인 발권기: 기둥 몸통 + 기울어진 화면 + 표 나오는 구멍
function P.Kiosk(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j, Vector3.new(1, 0, 0)) * CFrame.new(0, 0, ctx.T / 2 - 1.6)
	local m = model(ctx, "Kiosk")
	Kit.box(m, cf * CFrame.new(0, 2.0, 0), Vector3.new(2.8, 4.0, 2.2))
	Kit.box(m, cf * CFrame.new(0, 5.2, -0.2) * CFrame.Angles(0.25, 0, 0), Vector3.new(3.0, 2.8, 0.5), SOFT)
	Kit.box(m, cf * CFrame.new(0, 2.8, -1.15), Vector3.new(1.4, 0.3, 0.1), LINE)
	Kit.box(m, cf * CFrame.new(0, 7.2, 0), Vector3.new(2.8, 0.9, 0.4), LINE)
	solid(m, cf, Vector3.new(3.0, 6.6, 2.2))
end

-- r 줄 세우기 기둥(벨트로 이어짐): 지나갈 수 있다(충돌 없음)
function P.Stanchion(ctx, i: number, j: number)
	local T = ctx.T
	local m = model(ctx, "Stanchion")
	local a = base(ctx, i, j) + Vector3.new(-T / 2 + 0.5, 0, 0)
	local b = a + Vector3.new(T - 1, 0, 0)
	local function post(q: Vector3)
		Kit.cylinder(m, q, q + Vector3.new(0, 3.2, 0), 0.15, LINE)
		Kit.cylinder(m, q, q + Vector3.new(0, 0.2, 0), 0.6, LINE)
	end
	post(a)
	if ctx.at(i + 1, j) ~= "r" then
		post(b)
	end
	if ctx.hash(i, j, 107) < 0.8 then
		local sag = if ctx.hash(i, j, 108) < 0.3 then 1.6 else 0.2
		Kit.box(m, CFrame.new((a + b) / 2 + Vector3.new(0, 2.9 - sag, 0)), Vector3.new(T - 1, 0.25, 0.1), LINE)
	end
end

-- g 검표대: 작은 연단 + 기울어진 윗판
function P.TicketStand(ctx, i: number, j: number)
	local cf = CFrame.new(base(ctx, i, j))
	local m = model(ctx, "TicketStand")
	Kit.box(m, cf * CFrame.new(0, 1.9, 0), Vector3.new(2.6, 3.8, 2.0), { name = "TicketStandBody" })
	Kit.box(m, cf * CFrame.new(0, 4.0, 0) * CFrame.Angles(0.3, 0, 0), Vector3.new(3.0, 0.2, 2.4), LINE)
	Kit.box(m, cf * CFrame.new(2.4, 0.2, 1.5) * CFrame.Angles(0, 0.5, 0), Vector3.new(2.2, 0.3, 3.0), LINE) -- 넘어진 안내판
end

-- ── 복도 ──

-- F 포스터 액자(벽에 걸린 라이트박스): 지나갈 수 있다
function P.Poster(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j) * CFrame.new(0, 5.2, ctx.T / 2 - 0.25) * CFrame.Angles(0, 0, (ctx.hash(i, j, 105) - 0.5) * 0.12)
	local m = model(ctx, "PosterFrame")
	Kit.box(m, cf, Vector3.new(3.6, 5.2, 0.35), LINE)
	Kit.box(m, cf * CFrame.new(0, 0, -0.2), Vector3.new(3.0, 4.6, 0.08), LINE)
end

-- h 상영관 번호판: 벽에서 튀어나온 네모 판 + 굵은 숫자(막대 획). 열 위치로 1~4관을 정한다
local SEG = { -- 위, 가운데, 아래, 왼위, 왼아래, 오른위, 오른아래
	{ false, false, false, false, false, true, true },
	{ true, true, true, false, true, true, false },
	{ true, true, true, false, false, true, true },
	{ false, true, false, true, false, true, true },
	{ true, true, true, true, false, false, true },
}
function P.HallSign(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j, Vector3.new(0, 0, -1)) * CFrame.new(0, 6.6, ctx.T / 2 - 0.5)
	local m = model(ctx, "HallSign")
	Kit.box(m, cf, Vector3.new(3.6, 4.6, 0.5), LINE)
	-- 상영관 복도(1층 y19~22): 북쪽 벽 = 2·3·4관(x6~16 / 18~28 / 30~40), 남쪽 벽 = 1관(서)·5관(동). i·j 는 1부터
	local x, y = i - 1, j - 1
	local n
	if y >= 21 then
		n = if x <= 14 then 1 else 5
	else
		n = if x <= 16 then 2 elseif x <= 28 then 3 else 4
	end
	local s = SEG[n]
	-- (로컬 -Z 쪽에서 보면 로컬 +X 가 왼쪽)
	local bars = {
		{ 0, 1.5, true }, { 0, 0, true }, { 0, -1.5, true },
		{ 0.8, 0.75, false }, { 0.8, -0.75, false }, { -0.8, 0.75, false }, { -0.8, -0.75, false },
	}
	for k, b in bars do
		if s[k] then
			Kit.box(m, cf * CFrame.new(b[1], b[2], -0.35), if b[3] then Vector3.new(1.6, 0.35, 0.2) else Vector3.new(0.35, 1.6, 0.2), LINE)
		end
	end
end

-- ── 영사실 ──

-- J 영사기: 받침대 + 몸체 + 렌즈(북쪽 영사창) + 필름 릴 두 개 + 영사창 틀
function P.Projector(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	-- 로컬 -Z = 영사창(상영관 쪽 벽): 북쪽 벽이 있으면 북쪽, 아니면 남쪽(1관·5관 영사실은 남쪽 상영관을 본다)
	-- (2층 영사실 앞은 상영관 위 두 층 높이 빈 곳 _ 일 수 있다: 벽처럼 그쪽을 본다)
	local function front(dj: number): boolean
		return ctx.isWall(i, j + dj) or ctx.at(i, j + dj) == "_"
	end
	local dz = if front(-1) or not front(1) then -1 else 1
	local cf = CFrame.lookAt(p, p + Vector3.new(0, 0, dz))
	local m = model(ctx, "Projector")
	Kit.box(m, cf * CFrame.new(0, 1.6, 0), Vector3.new(2.4, 3.2, 3.0), { name = "ProjectorStand" })
	Kit.box(m, cf * CFrame.new(0, 4.4, 0), Vector3.new(1.8, 2.4, 3.6))
	Kit.cylinder(m, at(cf, 0, 4.4, -1.8), at(cf, 0, 4.4, -3.2), 0.45, { blocks = false, collide = false, rings = 1 })
	for _, z in { -1.2, 1.0 } do
		Kit.cylinder(m, at(cf, -0.15, 7.0, z), at(cf, 0.15, 7.0, z), 1.3, { blocks = false, collide = false, rings = 1 })
	end
	Kit.box(m, cf * CFrame.new(0, 4.6, -ctx.T / 2 + 0.1), Vector3.new(2.4, 1.6, 0.3), LINE)
	solid(m, cf, Vector3.new(2.6, 6, 3.8))
end

-- G 필름 되감기 대: 작업대 + 양끝에 선 릴 둘 + 사이를 잇는 필름 선
function P.RewindBench(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j) * CFrame.new(0, 0, ctx.T / 2 - 1.6)
	local m = model(ctx, "RewindBench")
	Kit.box(m, cf * CFrame.new(0, 3.0, 0), Vector3.new(6.6, 0.3, 2.6), SOFT)
	for _, x in { -3.0, 3.0 } do
		Kit.box(m, cf * CFrame.new(x, 1.5, 0), Vector3.new(0.3, 3.0, 2.2), LINE)
		Kit.cylinder(m, at(cf, x * 0.7, 4.6, 0.15), at(cf, x * 0.7, 4.6, -0.15), 1.3, { blocks = false, collide = false, rings = 1 })
		Kit.box(m, cf * CFrame.new(x * 0.7, 3.8, 0.4), Vector3.new(0.3, 1.6, 0.3), LINE)
	end
	Kit.box(m, cf * CFrame.new(0, 3.5, 0), Vector3.new(4.2, 0.1, 0.1), LINE)
	solid(m, cf, Vector3.new(6.6, 3.6, 2.6))
end

-- e 앰프·전원 랙: 키 큰 장 + 칸 나눔 + 손잡이
function P.AmpRack(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j) * CFrame.new(0, 0, ctx.T / 2 - 1.5)
	local m = model(ctx, "AmpRack")
	Kit.box(m, cf * CFrame.new(0, 3.6, 0), Vector3.new(3.4, 7.2, 2.4))
	for k = 1, 4 do
		Kit.box(m, cf * CFrame.new(0, k * 1.4, -1.25), Vector3.new(3.2, 0.1, 0.1), LINE)
	end
	for _, x in { -1.0, 1.0 } do
		Kit.cylinder(m, at(cf, x, 6.4, -1.2), at(cf, x, 6.4, -1.5), 0.35, LINE) -- 계기
	end
end

-- R 필름 깡통 선반: 기둥 틀 + 선반 셋 + 세워 둔 둥근 필름통
function P.FilmRack(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j) * CFrame.new(0, 0, ctx.T / 2 - 1.4)
	local m = model(ctx, "FilmRack")
	for _, x in { -3.2, 3.2 } do
		Kit.box(m, cf * CFrame.new(x, 3.6, 0), Vector3.new(0.25, 7.2, 2.2), SOFT)
	end
	for k = 0, 2 do
		local y = 0.6 + k * 2.5
		Kit.box(m, cf * CFrame.new(0, y, 0), Vector3.new(6.4, 0.2, 2.2), LINE)
		local x = (ctx.hash(i, j, 70 + k) - 0.5) * 3.6
		for s = 0, 1 do
			Kit.cylinder(m, at(cf, x + s * 0.7, y + 1.1, 0), at(cf, x + s * 0.7 + 0.4, y + 1.1, 0), 1.0, LINE)
		end
	end
	solid(m, cf, Vector3.new(6.6, 7.2, 2.2))
end

-- ── 화장실·하역장 ──

-- V 세면대 + 거울
function P.Sink(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local T = ctx.T
	local m = model(ctx, "Sink")
	local z = T / 2 - 1.2
	Kit.box(m, cf * CFrame.new(0, 2.9, z), Vector3.new(T - 0.5, 0.6, 2.2), SOFT)
	for _, x in { -1.8, 1.8 } do
		Kit.box(m, cf * CFrame.new(x, 3.22, z), Vector3.new(1.8, 0.05, 1.2), LINE)
		Kit.cylinder(m, at(cf, x, 3.2, z + 0.7), at(cf, x, 4.1, z + 0.4), 0.12, LINE)
	end
	Kit.box(m, cf * CFrame.new(0, 1.3, z), Vector3.new(T - 1.5, 2.6, 1.6), LINE)
	Kit.box(m, cf * CFrame.new(0, 6.0, T / 2 - 0.2), Vector3.new(T - 1.0, 3.0, 0.1), LINE)
	solid(m, cf * CFrame.new(0, 0, z), Vector3.new(T - 0.5, 3.4, 2.2))
end

-- U 화장실 칸: 옆 칸막이 + 반쯤 열린 문 + 변기
function P.ToiletStall(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j, Vector3.new(0, 0, 1))
	local m = model(ctx, "ToiletStall")
	local h = 6.6
	for _, s in { -1, 1 } do
		Kit.box(m, cf * CFrame.new(s * 3.2, h / 2 + 0.6, 1.4), Vector3.new(0.15, h, 5.0), SOFT)
	end
	Kit.box(m, cf * CFrame.new(-2.0, h / 2 + 0.6, -1.1) * CFrame.Angles(0, 0.5, 0), Vector3.new(2.4, h, 0.15), SOFT)
	Kit.box(m, cf * CFrame.new(2.3, h / 2 + 0.6, -1.1), Vector3.new(1.7, h, 0.15), SOFT)
	Kit.cylinder(m, at(cf, 0, 0, 1.6), at(cf, 0, 1.6, 1.6), 0.8, SOFT)
	Kit.cylinder(m, at(cf, 0, 1.6, 1.4), at(cf, 0, 1.85, 1.4), 1.0, LINE)
	Kit.box(m, cf * CFrame.new(0, 2.6, 3.1), Vector3.new(1.8, 1.8, 0.9), SOFT)
	solid(m, cf * CFrame.new(0, 0, 1.4), Vector3.new(6.6, 7, 5.2))
end

-- Q 짐수레(하역장): 바닥판 + 손잡이 틀 + 필름 상자 둘
function P.HandCart(ctx, i: number, j: number)
	local cf = CFrame.new(base(ctx, i, j)) * CFrame.Angles(0, (ctx.hash(i, j, 81) - 0.5) * 1.2, 0)
	local m = model(ctx, "HandCart")
	Kit.box(m, cf * CFrame.new(0, 0.9, 0), Vector3.new(3.4, 0.3, 5.4), SOFT)
	for _, x in { -1.5, 1.5 } do
		Kit.cylinder(m, at(cf, x, 1.0, 2.6), at(cf, x, 4.4, 3.0), 0.12, LINE)
		for _, z in { -2.0, 2.0 } do
			Kit.cylinder(m, at(cf, x - 0.1, 0.4, z), at(cf, x + 0.1, 0.4, z), 0.4, LINE)
		end
	end
	Kit.cylinder(m, at(cf, -1.5, 4.4, 3.0), at(cf, 1.5, 4.4, 3.0), 0.12, LINE)
	Kit.box(m, cf * CFrame.new(0.2, 1.9, -1.0) * CFrame.Angles(0, 0.1, 0), Vector3.new(2.6, 1.8, 2.4), SOFT)
	Kit.box(m, cf * CFrame.new(-0.1, 3.4, -0.9) * CFrame.Angles(0, -0.2, 0), Vector3.new(2.0, 1.2, 2.0), SOFT)
	solid(m, cf, Vector3.new(3.6, 4, 6))
end

return P
