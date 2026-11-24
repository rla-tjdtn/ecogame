--!nonstrict
-- 챕터 4 폐병원 전용 소품(타일 문자 → 함수). Stage4.luau 의 Props 줄에서 쓴다.
-- MapKit 부품만(검은 무광, 음파 윤곽선). 굵은 윤곽 위주, 막는 소품은 보이지 않는 충돌 상자를 둔다.
--   N 카운터(접수대·간호 스테이션·조제 창구)   w 대기 의자 줄            C 침대 사이 커튼(레일 + 천, 지나감)
--   I 수액 걸이대                               G 바퀴 달린 들것          W 휠체어
--   u 세면대 + 거울                             Y 엑스선 촬영대           F 시신 냉장고(3단 문, 벽 줄)
--   H 약장·차트 선반(양면)                      j 화장실 칸(변기 + 칸막이)  e 엘리베이터 문(벽, 지나감)
--   M 감시 모니터 벽 / 마취 모니터 대
--   U CT 촬영기(고리 갠트리 + 환자 테이블)      Q 멈춘 회전문(원통 몸체 + 날개 넷)  g 유리 바람막이·칸막이(틀 + 판)
--   B 방화 셔터(내려온 철제 셔터, 가로 살)      P 평행봉(재활 보행 훈련)    d 협탁 + 오버베드 테이블
--   a 약품 카트(서랍 + 바퀴)

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

-- 같은 문자가 이어지는 축(세로 이웃이 있으면 z, 아니면 x)
local function runAxis(ctx, i: number, j: number, ch: string): Vector3
	if ctx.at(i, j - 1) == ch or ctx.at(i, j + 1) == ch then
		return Vector3.new(0, 0, 1)
	end
	return Vector3.new(1, 0, 0)
end

-- 벽을 등진 좌표계: 로컬 -Z = 방 안쪽, +Z = 벽 쪽
local function againstWall(ctx, i: number, j: number): (CFrame, Vector3)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j) or Vector3.new(0, 0, -1)
	return CFrame.lookAt(p, p - side), side
end

-- N 카운터: 이어진 방향으로 한 칸 길이. 앞판 + 높은 선반 + 안쪽 작업대
function P.Counter(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local axis = runAxis(ctx, i, j, "N")
	local cf = CFrame.lookAt(p, p + axis) -- 로컬 Z = 이어진 방향
	local m = model(ctx, "Counter")
	local L = ctx.T
	Kit.box(m, cf * CFrame.new(0, 1.9, 0), Vector3.new(1.0, 3.8, L), SOFT)
	Kit.box(m, cf * CFrame.new(0, 3.95, 0), Vector3.new(2.2, 0.25, L), SOFT)
	Kit.box(m, cf * CFrame.new(1.4, 2.7, 0), Vector3.new(1.8, 0.2, L), SOFT)
	if ctx.hash(i, j, 21) > 0.5 then -- 모니터
		Kit.box(m, cf * CFrame.new(1.4, 3.6, 0) * CFrame.Angles(0, 0.2, 0), Vector3.new(0.15, 1.2, 1.8), LINE)
	else -- 서류철
		Kit.box(m, cf * CFrame.new(0.1, 4.3, 1.2), Vector3.new(1.0, 0.45, 1.4), LINE)
	end
	solid(m, cf, Vector3.new(3.2, 4.1, L))
end

-- w 대기 의자 줄: 한 칸에 의자 셋(연결 다리)
function P.Bench(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "WaitingChairs")
	local axis = runAxis(ctx, i, j, "w")
	local cf = CFrame.lookAt(p, p + Vector3.new(axis.Z, 0, -axis.X)) -- 로컬 X = 줄 방향
	Kit.box(m, cf * CFrame.new(0, 1.2, 0), Vector3.new(7.4, 0.2, 0.3), LINE)
	for k = -1, 1 do
		Kit.box(m, cf * CFrame.new(k * 2.5, 1.7, -0.1), Vector3.new(2.0, 0.2, 1.9), SOFT)
		Kit.box(m, cf * CFrame.new(k * 2.5, 2.8, 0.9) * CFrame.Angles(-0.12, 0, 0), Vector3.new(2.0, 1.7, 0.18), SOFT)
	end
	for _, x in { -3.2, 3.2 } do
		Kit.box(m, cf * CFrame.new(x, 0.6, 0), Vector3.new(0.2, 1.2, 1.8), LINE)
	end
	solid(m, cf, Vector3.new(7.6, 3.4, 2.4))
end

-- C 침대 사이 커튼: 천장 레일 + 세로 주름 천(지나갈 수 있다)
function P.Curtain(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "Curtain")
	local top = math.min(9.2, ctx.H - 1)
	Kit.cylinder(m, (cf * CFrame.new(0, top, 3.8)).Position, (cf * CFrame.new(0, top, -3.2)).Position, 0.1, LINE)
	local n = 5
	for k = 0, n - 1 do -- 주름(지그재그로 선 판)
		local z = 3.4 - k * 1.1
		Kit.box(m, cf * CFrame.new(if k % 2 == 0 then 0.18 else -0.18, (top + 1.2) / 2, z) * CFrame.Angles(0, if k % 2 == 0 then 0.35 else -0.35, 0), Vector3.new(0.1, top - 1.2, 1.1), LINE)
	end
end

-- I 수액 걸이대
function P.IVStand(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "IVStand")
	local c = p + Vector3.new((ctx.hash(i, j, 31) - 0.5) * 2, 0, (ctx.hash(i, j, 32) - 0.5) * 2)
	Kit.cylinder(m, c + Vector3.new(0, 0.3, 0), c + Vector3.new(0, 7.0, 0), 0.12, SOFT)
	for k = 0, 2 do
		local a = k * math.pi * 2 / 3
		Kit.cylinder(m, c + Vector3.new(0, 0.35, 0), c + Vector3.new(math.cos(a) * 1.2, 0.15, math.sin(a) * 1.2), 0.1, LINE)
	end
	Kit.cylinder(m, c + Vector3.new(-0.9, 6.9, 0), c + Vector3.new(0.9, 6.9, 0), 0.08, LINE)
	Kit.box(m, CFrame.new(c + Vector3.new(0.8, 6.0, 0)), Vector3.new(0.9, 1.5, 0.35), LINE) -- 수액 주머니
	Kit.box(m, CFrame.new(c + Vector3.new(0, 3.8, 0.3)), Vector3.new(0.9, 1.1, 0.6), LINE) -- 펌프
	solid(m, CFrame.new(c), Vector3.new(1.8, 7, 1.8))
end

-- G 들것: 매트리스 + 바퀴 다리 + 옆 난간
function P.Gurney(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.new(p) * CFrame.Angles(0, ctx.hash(i, j, 41) * math.pi, 0)
	local m = model(ctx, "Gurney")
	Kit.box(m, cf * CFrame.new(0, 2.8, 0), Vector3.new(2.5, 0.6, 6.4), SOFT)
	Kit.box(m, cf * CFrame.new(0, 3.5, 2.2) * CFrame.Angles(-0.35, 0, 0), Vector3.new(2.5, 0.4, 2.2), SOFT)
	for _, x in { -1.1, 1.1 } do
		for _, z in { -2.6, 2.6 } do
			Kit.cylinder(m, (cf * CFrame.new(x, 2.6, z)).Position, (cf * CFrame.new(x, 0.4, z * 0.85)).Position, 0.1, LINE)
			Kit.cylinder(m, (cf * CFrame.new(x - 0.12, 0.4, z * 0.85)).Position, (cf * CFrame.new(x + 0.12, 0.4, z * 0.85)).Position, 0.4, LINE)
		end
		Kit.cylinder(m, (cf * CFrame.new(x * 1.2, 3.9, -1.8)).Position, (cf * CFrame.new(x * 1.2, 3.9, 1.6)).Position, 0.08, LINE)
	end
	Kit.box(m, cf * CFrame.new(0, 1.0, 0), Vector3.new(2.0, 0.15, 4.6), LINE)
	solid(m, cf, Vector3.new(2.8, 4.2, 6.6))
end

-- W 휠체어
function P.Wheelchair(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.new(p) * CFrame.Angles(0, ctx.hash(i, j, 51) * math.pi * 2, 0)
	local m = model(ctx, "Wheelchair")
	Kit.box(m, cf * CFrame.new(0, 2.0, 0), Vector3.new(2.0, 0.25, 2.0), SOFT)
	Kit.box(m, cf * CFrame.new(0, 3.3, 1.0), Vector3.new(2.0, 2.4, 0.2), SOFT)
	for _, x in { -1.25, 1.25 } do
		Kit.cylinder(m, (cf * CFrame.new(x - 0.1, 1.5, 0.5)).Position, (cf * CFrame.new(x + 0.1, 1.5, 0.5)).Position, 1.5, LINE) -- 큰 바퀴
		Kit.cylinder(m, (cf * CFrame.new(x * 0.85, 0.5, -1.4)).Position, (cf * CFrame.new(x * 0.85 + 0.1, 0.5, -1.4)).Position, 0.5, LINE)
		Kit.cylinder(m, (cf * CFrame.new(x * 0.85, 3.1, 0.9)).Position, (cf * CFrame.new(x * 0.85, 3.1, -0.8)).Position, 0.1, LINE) -- 팔걸이
		Kit.cylinder(m, (cf * CFrame.new(x * 0.8, 4.4, 1.0)).Position, (cf * CFrame.new(x * 0.8, 4.4, 1.7)).Position, 0.1, LINE) -- 손잡이
		Kit.box(m, cf * CFrame.new(x * 0.45, 0.6, -1.9), Vector3.new(0.9, 0.12, 0.9), LINE) -- 발판
	end
	solid(m, cf, Vector3.new(3, 4.4, 3.6))
end

-- u 세면대 + 거울
function P.Sink(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "Sink")
	local z = ctx.T / 2 - 1.1
	Kit.box(m, cf * CFrame.new(0, 2.8, z), Vector3.new(2.8, 0.8, 2.0), SOFT)
	Kit.box(m, cf * CFrame.new(0, 3.22, z - 0.1), Vector3.new(1.9, 0.05, 1.2), LINE)
	Kit.cylinder(m, (cf * CFrame.new(0, 0, z + 0.2)).Position, (cf * CFrame.new(0, 2.4, z + 0.2)).Position, 0.35, SOFT)
	Kit.cylinder(m, (cf * CFrame.new(0, 3.2, z + 0.7)).Position, (cf * CFrame.new(0, 4.1, z + 0.7)).Position, 0.1, LINE)
	Kit.cylinder(m, (cf * CFrame.new(0, 4.1, z + 0.7)).Position, (cf * CFrame.new(0, 4.0, z - 0.1)).Position, 0.1, LINE)
	Kit.box(m, cf * CFrame.new(0, 6.2, ctx.T / 2 - 0.25), Vector3.new(2.4, 2.6, 0.1), LINE) -- 거울
	solid(m, cf * CFrame.new(0, 0, z), Vector3.new(3, 3.4, 2.2))
end

-- Y 엑스선 촬영대: 긴 촬영 침대 + 천장 기둥에 매달린 관구
function P.XRay(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.new(p)
	local m = model(ctx, "XRay")
	Kit.box(m, cf * CFrame.new(0, 2.7, 0), Vector3.new(7.4, 0.5, 2.8), SOFT)
	Kit.box(m, cf * CFrame.new(0, 1.2, 0), Vector3.new(3.0, 2.4, 1.8), SOFT)
	local top = ctx.H
	Kit.cylinder(m, (cf * CFrame.new(1.2, top, -0.2)).Position, (cf * CFrame.new(1.2, 6.8, -0.2)).Position, 0.4, SOFT)
	Kit.box(m, cf * CFrame.new(1.2, 6.2, -0.2), Vector3.new(2.6, 1.4, 1.6), SOFT)
	Kit.cylinder(m, (cf * CFrame.new(1.2, 5.6, -0.2)).Position, (cf * CFrame.new(1.2, 4.7, -0.2)).Position, 0.75, LINE)
	Kit.box(m, cf * CFrame.new(0, top - 0.25, -0.2), Vector3.new(7.6, 0.3, 0.6), LINE) -- 천장 레일
	for _, s in { -1, 1 } do -- 조작 손잡이
		Kit.cylinder(m, (cf * CFrame.new(1.2 + s * 1.3, 6.2, -0.2)).Position, (cf * CFrame.new(1.2 + s * 1.9, 5.6, -1.0)).Position, 0.1, LINE)
	end
	solid(m, cf, Vector3.new(7.4, 3.2, 2.8))
end

-- F 시신 냉장고: 벽을 따라 3단 문 + 손잡이. 가끔 트레이가 나와 있다
function P.MorgueFridge(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "MorgueFridge")
	local z = ctx.T / 2 - 1.6
	local L = ctx.T
	Kit.box(m, cf * CFrame.new(0, 4.5, z), Vector3.new(L, 9, 3.0))
	for k = 0, 2 do
		for _, s in { -1, 1 } do
			local c = cf * CFrame.new(s * L / 4, 1.6 + k * 2.9, z - 1.55)
			Kit.box(m, c, Vector3.new(L / 2 - 0.5, 2.5, 0.12), LINE)
			Kit.box(m, c * CFrame.new(1.1, 0, -0.15), Vector3.new(0.2, 0.9, 0.25), LINE)
		end
	end
	if ctx.hash(i, j, 61) > 0.7 then
		Kit.box(m, cf * CFrame.new(-L / 4, 1.2, z - 2.3), Vector3.new(L / 2 - 0.9, 0.25, 1.6), LINE)
	end
end

-- H 약장·차트 선반: 양면 5단 선반 + 상자 몇 개
function P.MedShelf(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local axis = runAxis(ctx, i, j, "H")
	local cf = CFrame.lookAt(p, p + axis)
	local m = model(ctx, "MedShelf")
	local L = ctx.T
	local h = 7.2
	for _, s in { -1, 1 } do
		Kit.box(m, cf * CFrame.new(0, h / 2, s * (L / 2 - 0.1)), Vector3.new(2.4, h, 0.2), SOFT)
	end
	Kit.box(m, cf * CFrame.new(0, h / 2, 0), Vector3.new(0.15, h, L - 0.3))
	for k = 0, 4 do
		Kit.box(m, cf * CFrame.new(0, 0.5 + k * 1.65, 0), Vector3.new(2.4, 0.14, L - 0.3), LINE)
	end
	for k = 0, 2 do -- 남은 약 상자·차트 몇 개
		local r = ctx.hash(i, j, 70 + k)
		Kit.box(m, cf * CFrame.new(if r > 0.5 then 0.65 else -0.65, 1.1 + math.floor(r * 4) * 1.65, (ctx.hash(i, j, 80 + k) - 0.5) * (L - 2.4)), Vector3.new(0.9, 1.0, 1.6), LINE)
	end
	solid(m, cf, Vector3.new(2.4, h, L))
end

-- j 화장실 칸: 양옆 칸막이 + 반쯤 열린 문 + 변기
function P.ToiletStall(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "ToiletStall")
	local h = 6.6
	for _, s in { -1, 1 } do
		Kit.box(m, cf * CFrame.new(s * 3.2, h / 2 + 0.6, 1.4), Vector3.new(0.15, h, 5.0), SOFT)
	end
	Kit.box(m, cf * CFrame.new(-2.0, h / 2 + 0.6, -1.1) * CFrame.Angles(0, 0.5, 0), Vector3.new(2.4, h, 0.15), SOFT) -- 열린 문
	Kit.box(m, cf * CFrame.new(2.3, h / 2 + 0.6, -1.1), Vector3.new(1.7, h, 0.15), SOFT)
	Kit.cylinder(m, (cf * CFrame.new(0, 0, 1.6)).Position, (cf * CFrame.new(0, 1.6, 1.6)).Position, 0.8, SOFT)
	Kit.cylinder(m, (cf * CFrame.new(0, 1.6, 1.4)).Position, (cf * CFrame.new(0, 1.85, 1.4)).Position, 1.0, LINE)
	Kit.box(m, cf * CFrame.new(0, 2.6, 3.1), Vector3.new(1.8, 1.8, 0.9), SOFT)
	solid(m, cf * CFrame.new(0, 0, 1.4), Vector3.new(6.6, 7, 5.2))
end

-- e 엘리베이터 문(벽면): 문틀 + 두 짝 문 + 층 표시 + 호출 단추
function P.Elevator(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "ElevatorDoor")
	local z = ctx.T / 2 - 0.2
	for _, s in { -1, 1 } do
		Kit.box(m, cf * CFrame.new(s * 3.0, 4.2, z), Vector3.new(0.5, 8.4, 0.5), LINE)
		Kit.box(m, cf * CFrame.new(s * 1.4, 4.0, z + 0.05), Vector3.new(2.7, 8.0, 0.12), LINE)
	end
	Kit.box(m, cf * CFrame.new(0, 8.5, z), Vector3.new(6.5, 0.5, 0.5), LINE)
	Kit.box(m, cf * CFrame.new(0, 9.3, z), Vector3.new(1.8, 0.8, 0.3), LINE)
	Kit.box(m, cf * CFrame.new(3.6, 4.2, z), Vector3.new(0.5, 1.2, 0.2), LINE)
end

-- M 감시 모니터: 바퀴 달린 대 + 화면 둘 + 늘어진 선
function P.Monitor(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j)
	local cf = if side then CFrame.lookAt(p + side * (ctx.T / 2 - 1.5), p) else CFrame.new(p)
	local m = model(ctx, "PatientMonitor")
	Kit.box(m, cf * CFrame.new(0, 2.0, 0), Vector3.new(2.8, 3.2, 1.8), SOFT)
	for k = 0, 1 do
		Kit.box(m, cf * CFrame.new(0, 1.2 + k * 1.3, -0.95), Vector3.new(2.4, 0.1, 0.1), LINE)
	end
	Kit.cylinder(m, (cf * CFrame.new(0, 3.6, 0)).Position, (cf * CFrame.new(0, 5.0, 0)).Position, 0.15, LINE)
	for _, s in { -1, 1 } do
		Kit.box(m, cf * CFrame.new(s * 1.15, 5.4, -0.1) * CFrame.Angles(0, s * 0.25, 0), Vector3.new(2.1, 1.6, 0.25), SOFT)
	end
	Kit.cylinder(m, (cf * CFrame.new(1.2, 4.6, 0.2)).Position, (cf * CFrame.new(1.9, 0.6, 0.6)).Position, 0.08, LINE)
	solid(m, cf, Vector3.new(3.4, 6, 2.2))
end

-- U CT 촬영기: 여덟 조각 고리(갠트리, 음파에 둥근 고리로 보인다) + 고리를 지나는 환자 테이블 + 받침
function P.CTScanner(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.new(p) -- 고리 면 = YZ, 테이블 = X 방향
	local m = model(ctx, "CTScanner")
	local cy, R = 3.6, 2.7
	for k = 0, 7 do
		local a = k * math.pi / 4
		local c = cf * CFrame.new(1.2, cy + math.sin(a) * R, math.cos(a) * R) * CFrame.Angles(a, 0, 0)
		Kit.box(m, c, Vector3.new(1.6, 1.0, 2.35), SOFT)
	end
	Kit.box(m, cf * CFrame.new(1.2, 0.5, 0), Vector3.new(1.8, 1.0, 4.4), SOFT) -- 고리 받침
	Kit.box(m, cf * CFrame.new(-1.0, 2.9, 0), Vector3.new(6.8, 0.35, 1.5), SOFT) -- 테이블 판(고리 안으로 들어간다)
	Kit.box(m, cf * CFrame.new(-2.6, 1.35, 0), Vector3.new(2.4, 2.7, 1.2), SOFT) -- 테이블 받침
	Kit.box(m, cf * CFrame.new(-3.4, 3.2, 0), Vector3.new(0.6, 0.25, 1.2), LINE) -- 머리 받침
	solid(m, cf, Vector3.new(7.2, 6.6, 6.4))
end

-- Q 멈춘 회전문: 지붕·바닥 원판, 양옆 곡면 유리(판 셋씩), 가운데 기둥과 날개 넷. 지나갈 수 없다(옆 여닫이문 E 가 출구)
function P.RevolvingDoor(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "RevolvingDoor")
	local top = math.min(9.5, ctx.H - 1)
	local R = 3.6
	Kit.cylinder(m, p + Vector3.new(0, top, 0), p + Vector3.new(0, top + 0.6, 0), R + 0.3, SOFT) -- 지붕 원판
	Kit.cylinder(m, p + Vector3.new(0, 0.02, 0), p + Vector3.new(0, 0.18, 0), R, LINE) -- 바닥 원판
	Kit.cylinder(m, p + Vector3.new(0, 0, 0), p + Vector3.new(0, top, 0), 0.25, SOFT) -- 가운데 기둥
	for _, s in { 0, 1 } do -- 동·서 곡면 유리(바깥 쪽 반원)
		for k = -1, 1 do
			local a = s * math.pi + k * 0.55
			local c = CFrame.new(p + Vector3.new(math.cos(a) * R, top / 2, math.sin(a) * R)) * CFrame.Angles(0, -a, 0)
			Kit.box(m, c, Vector3.new(0.12, top, 2.0), LINE)
		end
	end
	local yaw = 0.35 -- 멈춘 날개 각도
	for k = 0, 3 do
		local a = yaw + k * math.pi / 2
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local c = CFrame.lookAt(p + d * (R / 2) + Vector3.new(0, top / 2, 0), p + d * R + Vector3.new(0, top / 2, 0))
		Kit.box(m, c, Vector3.new(0.12, top - 0.6, R - 0.3), LINE)
		Kit.box(m, c * CFrame.new(0, 0, 0), Vector3.new(0.3, 0.25, R - 0.3), SOFT) -- 날개 손잡이 가로대
	end
	solid(m, CFrame.new(p), Vector3.new(R * 2, top, R * 2))
end

-- g 유리 바람막이·칸막이: 금속 틀(기둥 둘·위아래 가로대·가운데 띠) + 얇은 판. 이어진 방향으로 한 칸 길이, 막힌다
function P.GlassScreen(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local axis = runAxis(ctx, i, j, "g")
	local cf = CFrame.lookAt(p, p + axis) -- 로컬 Z = 이어진 방향
	local m = model(ctx, "GlassScreen")
	local L = ctx.T
	local h = math.min(9, ctx.H - 1)
	Kit.box(m, cf * CFrame.new(0, h / 2, 0), Vector3.new(0.08, h - 0.4, L - 0.4), LINE) -- 유리판
	for _, s in { -1, 1 } do
		Kit.box(m, cf * CFrame.new(0, h / 2, s * (L / 2 - 0.15)), Vector3.new(0.35, h, 0.3), SOFT) -- 기둥
	end
	Kit.box(m, cf * CFrame.new(0, h, 0), Vector3.new(0.4, 0.35, L), SOFT)
	Kit.box(m, cf * CFrame.new(0, 0.2, 0), Vector3.new(0.4, 0.4, L), SOFT)
	Kit.box(m, cf * CFrame.new(0, 3.4, 0), Vector3.new(0.3, 0.15, L), LINE) -- 손 닿는 높이 띠(부딪힘 방지 표시)
	solid(m, cf, Vector3.new(0.6, h, L))
end

-- B 방화 셔터: 천장 셔터 박스에서 바닥까지 내려온 철판 + 가로 살 줄 + 아래 막대. 줄 끝(벽 쪽)에 안내 레일
function P.FireShutter(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local axis = runAxis(ctx, i, j, "B")
	local cf = CFrame.lookAt(p, p + axis) -- 로컬 Z = 셔터 줄 방향
	local m = model(ctx, "FireShutter")
	local L = ctx.T
	local h = ctx.H
	Kit.box(m, cf * CFrame.new(0, h / 2, 0), Vector3.new(0.35, h, L)) -- 철판(음파·소리를 막는다)
	for k = 1, 7 do -- 가로 살(앞뒤 면에 선이 보이게 살짝 튀어나온 띠)
		Kit.box(m, cf * CFrame.new(0, k * (h - 1.6) / 8, 0), Vector3.new(0.55, 0.12, L), LINE)
	end
	Kit.box(m, cf * CFrame.new(0, h - 0.8, 0), Vector3.new(1.6, 1.6, L), SOFT) -- 셔터 박스
	Kit.box(m, cf * CFrame.new(0, 0.25, 0), Vector3.new(0.7, 0.5, L), SOFT) -- 아래 막대
	for _, s in { -1, 1 } do
		local ni, nj = i + math.round(axis.X) * s, j + math.round(axis.Z) * s
		if ctx.at(ni, nj) ~= "B" then -- 줄 끝: 벽에 붙은 안내 레일
			Kit.box(m, cf * CFrame.new(0, h / 2, s * (L / 2 - 0.2)), Vector3.new(0.9, h, 0.4), SOFT)
		end
	end
end

-- P 평행봉: 바닥 판 + 손잡이 봉 둘(이어진 방향) + 기둥
function P.ParallelBars(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local axis = runAxis(ctx, i, j, "P")
	local cf = CFrame.lookAt(p, p + axis) -- 로컬 Z = 봉 방향
	local m = model(ctx, "ParallelBars")
	local L = ctx.T
	Kit.box(m, cf * CFrame.new(0, 0.1, 0), Vector3.new(3.4, 0.2, L), LINE)
	for _, x in { -1.2, 1.2 } do
		Kit.cylinder(m, (cf * CFrame.new(x, 3.0, -L / 2)).Position, (cf * CFrame.new(x, 3.0, L / 2)).Position, 0.12, SOFT)
		for _, z in { -L / 4, L / 4 } do
			Kit.cylinder(m, (cf * CFrame.new(x, 0.2, z)).Position, (cf * CFrame.new(x, 3.0, z)).Position, 0.1, LINE)
		end
	end
	solid(m, cf, Vector3.new(3.4, 3.2, L))
end

-- d 협탁 + 오버베드 테이블: 벽 쪽 작은 서랍장(서랍 선 둘) + 바퀴 받침의 ㄱ자 식사 테이블
function P.Bedside(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "Bedside")
	local z = ctx.T / 2 - 1.3
	Kit.box(m, cf * CFrame.new(0, 1.4, z), Vector3.new(1.9, 2.8, 1.9), SOFT)
	for k = 1, 2 do
		Kit.box(m, cf * CFrame.new(0, k * 0.9, z - 0.97), Vector3.new(1.6, 0.08, 0.05), LINE)
	end
	Kit.box(m, cf * CFrame.new(0, 3.05, z), Vector3.new(0.5, 0.5, 0.5), LINE) -- 컵·약통
	local tz = z - 2.4
	Kit.box(m, cf * CFrame.new(-1.1, 0.12, tz), Vector3.new(0.5, 0.24, 2.2), LINE) -- 바퀴 받침
	Kit.cylinder(m, (cf * CFrame.new(-1.1, 0.2, tz)).Position, (cf * CFrame.new(-1.1, 3.6, tz)).Position, 0.1, LINE)
	Kit.box(m, cf * CFrame.new(0, 3.7, tz), Vector3.new(2.8, 0.15, 1.3), SOFT) -- 식사 판
	solid(m, cf * CFrame.new(0, 0, z - 1), Vector3.new(3, 3.8, 3.6))
end

-- a 약품 카트: 서랍 몸체(서랍 선 셋) + 위 쟁반 테 + 손잡이 + 바퀴 넷
function P.MedCart(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.new(p) * CFrame.Angles(0, ctx.hash(i, j, 91) * math.pi, 0)
	local m = model(ctx, "MedCart")
	Kit.box(m, cf * CFrame.new(0, 2.0, 0), Vector3.new(3.0, 2.8, 2.0), SOFT)
	for k = 1, 3 do
		Kit.box(m, cf * CFrame.new(0, 0.9 + k * 0.7, -1.02), Vector3.new(2.7, 0.08, 0.05), LINE)
	end
	Kit.box(m, cf * CFrame.new(0, 3.55, 0), Vector3.new(3.2, 0.3, 2.2), LINE) -- 쟁반 테
	Kit.cylinder(m, (cf * CFrame.new(-1.3, 3.5, 1.3)).Position, (cf * CFrame.new(1.3, 3.5, 1.3)).Position, 0.09, LINE) -- 손잡이
	for _, x in { -1.2, 1.2 } do
		for _, zz in { -0.75, 0.75 } do
			Kit.cylinder(m, (cf * CFrame.new(x - 0.1, 0.3, zz)).Position, (cf * CFrame.new(x + 0.1, 0.3, zz)).Position, 0.3, LINE)
		end
	end
	solid(m, cf, Vector3.new(3.2, 3.8, 2.6))
end

return P
