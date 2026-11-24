--!nonstrict
-- 챕터 7 학교 전용 소품(타일 문자 → 함수). Stage7.luau 의 Props 줄에서 쓴다.
-- MapKit 부품만(검은 무광, 음파 윤곽선). 굵은 윤곽 위주, 막는 소품은 보이지 않는 충돌 상자를 둔다.
--   T 학생 책상 + 의자        G 칠판 + 교탁(서쪽 앞 벽)   N 게시판(벽, 지나감)      k 사물함·캐비닛(벽, 지나감)
--   W 신발장                  U 화장실 칸                 I 세면대 + 거울           J 실험대(개수대)
--   Y 업라이트 피아노         e 이젤                      M 방송 콘솔               F 급식 식탁(긴 의자)
--   V 배식대                  H 서가                      g 농구대(벽)              u 체육관 단상
--   t 중정 나무(줄기 + 가지)  h 중정 동상(받침대 위 인물)  r 화단(낮은 벽돌 틀)      j 중정 벤치
--   q 뜀틀·매트 더미          x 트로피 진열장(벽)          w 정수기(벽, 지나감)      P 프로젝터 스크린(벽)

local Kit = require(script.Parent.Parent.MapKit)
local PM = require(script.Parent.Parent.PropMesh) -- 다 지은 소품을 메시 에셋으로 바꿔 입힌다(없으면 기본 도형 그대로)

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

-- T 학생 책상 + 의자(교탁이 있는 서쪽을 본다). 몇 개는 삐뚤거나 의자가 넘어졌다
function P.StudentDesk(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local yaw = (ctx.hash(i, j, 3) - 0.5) * 0.3
	local cf = CFrame.lookAt(p, p + Vector3.new(-1, 0, 0)) * CFrame.Angles(0, yaw, 0) -- 로컬 -Z = 앞(서쪽)
	local m = model(ctx, "StudentDesk")
	Kit.box(m, cf * CFrame.new(0, 2.6, -0.8), Vector3.new(2.8, 0.18, 1.9), SOFT)
	Kit.box(m, cf * CFrame.new(0, 2.1, -0.8), Vector3.new(2.3, 0.6, 1.5), LINE) -- 서랍
	for _, x in { -1.2, 1.2 } do
		Kit.box(m, cf * CFrame.new(x, 1.25, -0.8), Vector3.new(0.12, 2.5, 1.5), LINE) -- 다리 틀
	end
	local fallen = ctx.hash(i, j, 4) > 0.82
	local ch = if fallen then cf * CFrame.new(0.4, 0.8, 1.8) * CFrame.Angles(math.pi / 2, 0.5, 0) else cf * CFrame.new(0, 0, 1.2)
	Kit.box(m, ch * CFrame.new(0, 1.6, 0), Vector3.new(1.6, 0.15, 1.5), SOFT)
	Kit.box(m, ch * CFrame.new(0, 2.8, 0.75), Vector3.new(1.6, 0.9, 0.12), SOFT)
	for _, x in { -0.7, 0.7 } do
		Kit.box(m, ch * CFrame.new(x, 1.6, 0.75), Vector3.new(0.1, 3.0, 0.1), LINE)
		Kit.box(m, ch * CFrame.new(x, 0.8, -0.65), Vector3.new(0.1, 1.6, 0.1), LINE)
	end
	solid(m, cf * CFrame.new(0, 0, 0), Vector3.new(3, 2.8, 4))
	PM.dress(m, if fallen then "School.StudentDeskFallen" else "School.StudentDesk", cf) -- (바닥 가운데, -Z = 앞(교탁 쪽), 의자는 +Z)
end

-- G 칠판(벽 가운데, 세로로 세 칸 길이) + 분필 받침 + 교탁
function P.Blackboard(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j, Vector3.new(-1, 0, 0))
	local m = model(ctx, "Blackboard")
	local z = ctx.T / 2 - 0.25
	Kit.box(m, cf * CFrame.new(0, 5.6, z), Vector3.new(15, 4.4, 0.2), LINE)
	Kit.box(m, cf * CFrame.new(0, 5.6, z - 0.14), Vector3.new(14.2, 3.6, 0.08), LINE)
	Kit.box(m, cf * CFrame.new(0, 3.3, z - 0.35), Vector3.new(15, 0.18, 0.6), LINE) -- 분필 받침
	for _, x in { -5.4, -5.0, 1.0 } do -- 분필 낙서 선 몇 줄
		Kit.box(m, cf * CFrame.new(x, 5.8, z - 0.2) * CFrame.Angles(0, 0, x * 0.2), Vector3.new(0.12, 1.6, 0.05), LINE)
	end
	-- 교탁
	local t = cf * CFrame.new(0, 0, -0.4)
	Kit.box(m, t * CFrame.new(0, 1.8, 0), Vector3.new(3.4, 3.6, 1.8), SOFT)
	Kit.box(m, t * CFrame.new(0, 3.75, 0) * CFrame.Angles(0.15, 0, 0), Vector3.new(3.8, 0.2, 2.2), SOFT)
	solid(m, t, Vector3.new(3.8, 4, 2.2))
	PM.dress(m, "School.Blackboard", cf) -- (칸 가운데 바닥, +Z = 벽)
end

-- N 게시판(벽면): 판 + 종이 몇 장
function P.NoticeBoard(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "NoticeBoard")
	local z = ctx.T / 2 - 0.2
	Kit.box(m, cf * CFrame.new(0, 5.6, z), Vector3.new(6.4, 3.2, 0.15), LINE)
	for k = 0, 2 do
		local r = ctx.hash(i, j, 90 + k)
		Kit.box(m, cf * CFrame.new(-2 + k * 2, 5.4 + r * 0.6, z - 0.1) * CFrame.Angles(0, 0, (r - 0.5) * 0.5), Vector3.new(1.1, 1.5, 0.05), LINE)
	end
	PM.dress(m, "School.NoticeBoard", cf)
end

-- k 학생 사물함(벽면 낮은 2단, 칸 반이 빈다)
function P.Locker(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "Locker")
	local z = ctx.T / 2 - 1.0
	Kit.box(m, cf * CFrame.new(0, 2.2, z), Vector3.new(7.2, 4.4, 1.8))
	Kit.box(m, cf * CFrame.new(0, 2.2, z - 0.93), Vector3.new(7.0, 0.12, 0.08), LINE)
	for k = -1, 1 do
		Kit.box(m, cf * CFrame.new(k * 1.8, 2.2, z - 0.93), Vector3.new(0.1, 4.2, 0.08), LINE)
	end
	PM.dress(m, "School.Locker", cf)
end

-- W 신발장: 현관의 낮은 칸칸이 선반
function P.ShoeLocker(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local axis = runAxis(ctx, i, j, "W")
	local cf = CFrame.lookAt(p, p + axis)
	local m = model(ctx, "ShoeLocker")
	local L = ctx.T
	local h = 4.6
	Kit.box(m, cf * CFrame.new(0, h / 2, 0), Vector3.new(2.6, h, L))
	for _, s in { -1, 1 } do
		for k = 1, 3 do
			Kit.box(m, cf * CFrame.new(s * 1.34, k * h / 4, 0), Vector3.new(0.08, 0.1, L - 0.2), LINE)
		end
		for k = -1, 1 do
			Kit.box(m, cf * CFrame.new(s * 1.34, h / 2, k * L / 4), Vector3.new(0.08, h - 0.2, 0.1), LINE)
		end
	end
	PM.dress(m, "School.ShoeLocker", cf) -- (Z = 늘어선 방향)
end

-- U 화장실 칸
function P.ToiletStall(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j, Vector3.new(1, 0, 0))
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
	PM.dress(m, "School.ToiletStall", cf)
end

-- I 세면대 + 거울
function P.Sink(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "Sink")
	local z = ctx.T / 2 - 1.1
	Kit.box(m, cf * CFrame.new(0, 2.7, z), Vector3.new(6.4, 0.9, 2.0), SOFT)
	for _, x in { -1.8, 1.8 } do
		Kit.box(m, cf * CFrame.new(x, 3.18, z - 0.1), Vector3.new(1.8, 0.05, 1.2), LINE)
		Kit.cylinder(m, at(cf, x, 3.1, z + 0.6), at(cf, x, 4.0, z + 0.6), 0.1, LINE)
		Kit.cylinder(m, at(cf, x, 4.0, z + 0.6), at(cf, x, 3.9, z - 0.1), 0.1, LINE)
	end
	Kit.box(m, cf * CFrame.new(0, 6.2, ctx.T / 2 - 0.25), Vector3.new(6.2, 2.4, 0.1), LINE)
	solid(m, cf * CFrame.new(0, 0, z), Vector3.new(6.6, 3.3, 2.2))
	PM.dress(m, "School.Sink", cf)
end

-- J 과학 실험대: 검은 상판 + 개수대 + 수도 + 비커 몇 개
function P.LabBench(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.new(p)
	local m = model(ctx, "LabBench")
	Kit.box(m, cf * CFrame.new(0, 1.6, 0), Vector3.new(6.0, 3.2, 2.8), SOFT)
	Kit.box(m, cf * CFrame.new(0, 3.3, 0), Vector3.new(6.6, 0.25, 3.2), SOFT)
	Kit.cylinder(m, at(cf, 2.2, 3.4, 0.8), at(cf, 2.2, 4.8, 0.8), 0.1, LINE)
	Kit.cylinder(m, at(cf, 2.2, 4.8, 0.8), at(cf, 2.2, 4.6, 0), 0.1, LINE)
	for k = 0, 1 do -- 비커
		local c = at(cf, -1.8 + k * 1.3, 3.4, (ctx.hash(i, j, 12 + k) - 0.5) * 1.6)
		Kit.cylinder(m, c, c + Vector3.new(0, 1.0 - k * 0.3, 0), 0.4, LINE)
	end
	for _, x in { -1.2, 1.2 } do -- 둥근 의자
		local c = at(cf, x, 0, 2.6)
		Kit.cylinder(m, c, c + Vector3.new(0, 1.9, 0), 0.15, LINE)
		Kit.cylinder(m, c + Vector3.new(0, 1.9, 0), c + Vector3.new(0, 2.1, 0), 0.7, LINE)
	end
	solid(m, cf, Vector3.new(6.6, 3.5, 3.2))
	PM.dress(m, "School.LabBench", cf)
end

-- Y 업라이트 피아노 + 의자
function P.Piano(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.lookAt(p, p + Vector3.new(-1, 0, 0))
	local m = model(ctx, "Piano")
	Kit.box(m, cf * CFrame.new(0, 2.6, -1.2), Vector3.new(6.0, 5.2, 1.6))
	Kit.box(m, cf * CFrame.new(0, 2.7, 0.2), Vector3.new(5.8, 0.4, 1.6), SOFT) -- 건반 선반
	for k = -3, 3 do
		Kit.box(m, cf * CFrame.new(k * 0.75, 2.95, 0.4), Vector3.new(0.18, 0.1, 0.9), LINE)
	end
	Kit.box(m, cf * CFrame.new(0, 4.2, -0.3) * CFrame.Angles(-0.2, 0, 0), Vector3.new(2.6, 1.4, 0.1), LINE) -- 악보대
	for _, x in { -2.7, 2.7 } do
		Kit.box(m, cf * CFrame.new(x, 1.3, 0.8), Vector3.new(0.4, 2.6, 0.4), LINE)
	end
	Kit.box(m, cf * CFrame.new(0, 1.8, 2.4), Vector3.new(2.4, 0.4, 1.2), SOFT)
	for _, x in { -1, 1 } do
		Kit.box(m, cf * CFrame.new(x, 0.8, 2.4), Vector3.new(0.2, 1.6, 1.0), LINE)
	end
	solid(m, cf * CFrame.new(0, 0, -0.4), Vector3.new(6.2, 5.2, 3.2))
	PM.dress(m, "School.Piano", cf) -- (-Z = 피아노 뒤판, +Z = 의자)
end

-- e 이젤 + 캔버스
function P.Easel(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.new(p) * CFrame.Angles(0, (ctx.hash(i, j, 15) - 0.5) * 1.4, 0)
	local m = model(ctx, "Easel")
	Kit.cylinder(m, at(cf, -1.3, 0, -0.6), at(cf, -0.3, 6.4, 0), 0.12, LINE)
	Kit.cylinder(m, at(cf, 1.3, 0, -0.6), at(cf, 0.3, 6.4, 0), 0.12, LINE)
	Kit.cylinder(m, at(cf, 0, 0, 1.8), at(cf, 0, 6.2, 0.1), 0.12, LINE)
	Kit.box(m, cf * CFrame.new(0, 4.3, -0.4) * CFrame.Angles(0.1, 0, 0), Vector3.new(3.0, 3.4, 0.15), SOFT)
	Kit.box(m, cf * CFrame.new(0, 2.5, -0.55), Vector3.new(3.0, 0.2, 0.5), LINE)
	solid(m, cf, Vector3.new(3, 6, 2.6))
	PM.dress(m, "School.Easel", cf)
end

-- M 방송 콘솔: 조절판 + 스피커 + 마이크
function P.BroadcastDesk(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "BroadcastDesk")
	Kit.box(m, cf * CFrame.new(0, 1.5, 2.2), Vector3.new(7.6, 3.0, 2.6), SOFT)
	Kit.wedge(m, cf * CFrame.new(0, 3.5, 2.2), Vector3.new(7.4, 1.0, 2.2), SOFT)
	for k = -3, 3 do -- 조절 손잡이
		Kit.box(m, cf * CFrame.new(k * 0.9, 3.75, 1.9), Vector3.new(0.2, 0.5, 0.3), LINE)
	end
	for _, x in { -2.8, 2.8 } do -- 벽 스피커
		Kit.box(m, cf * CFrame.new(x, 6.6, ctx.T / 2 - 0.8), Vector3.new(1.6, 2.4, 1.2), SOFT)
	end
	Kit.cylinder(m, at(cf, 0.4, 3.8, 1.6), at(cf, 0, 5.2, 0.7), 0.08, LINE)
	Kit.ball(m, at(cf, 0, 5.3, 0.6), 0.3, LINE)
	solid(m, cf * CFrame.new(0, 0, 2.2), Vector3.new(7.6, 4, 2.8))
	PM.dress(m, "School.BroadcastDesk", cf)
end

-- F 급식 식탁: 긴 상 + 붙은 긴 의자
function P.LunchTable(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local axis = runAxis(ctx, i, j, "F")
	local cf = CFrame.lookAt(p, p + axis)
	local m = model(ctx, "LunchTable")
	local L = ctx.T
	Kit.box(m, cf * CFrame.new(0, 2.7, 0), Vector3.new(2.6, 0.22, L), SOFT)
	for _, s in { -1, 1 } do
		Kit.box(m, cf * CFrame.new(s * 2.3, 1.5, 0), Vector3.new(1.0, 0.18, L), SOFT)
	end
	for _, z in { -2.6, 2.6 } do
		Kit.box(m, cf * CFrame.new(0, 1.35, z), Vector3.new(0.3, 2.7, 0.3), LINE)
		Kit.box(m, cf * CFrame.new(0, 0.7, z), Vector3.new(4.8, 0.2, 0.25), LINE)
	end
	if ctx.hash(i, j, 22) > 0.6 then -- 남은 식판
		Kit.box(m, cf * CFrame.new(0.4, 2.9, 1.2) * CFrame.Angles(0, 0.4, 0), Vector3.new(1.4, 0.15, 1.0), LINE)
	end
	solid(m, cf, Vector3.new(5.2, 2.9, L))
	PM.dress(m, if ctx.hash(i, j, 22) > 0.6 then "School.LunchTableTray" else "School.LunchTable", cf)
end

-- V 배식대: 카운터 + 유리 가림막 틀 + 국통
function P.ServingCounter(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local axis = runAxis(ctx, i, j, "V")
	local cf = CFrame.lookAt(p, p + axis)
	local m = model(ctx, "ServingCounter")
	local L = ctx.T
	Kit.box(m, cf * CFrame.new(0, 1.7, 0), Vector3.new(2.8, 3.4, L), SOFT)
	Kit.box(m, cf * CFrame.new(0, 3.5, 0), Vector3.new(3.4, 0.2, L), SOFT)
	for _, z in { -L / 2 + 0.3, L / 2 - 0.3 } do
		Kit.box(m, cf * CFrame.new(0, 4.8, z), Vector3.new(0.2, 2.6, 0.2), LINE)
	end
	Kit.box(m, cf * CFrame.new(0, 6.1, 0), Vector3.new(2.2, 0.2, L), LINE) -- 가림막 윗판
	local c = at(cf, 0, 3.6, (ctx.hash(i, j, 25) - 0.5) * 3)
	Kit.cylinder(m, c, c + Vector3.new(0, 1.0, 0), 0.9, LINE)
	solid(m, cf, Vector3.new(3.4, 3.6, L))
	PM.dress(m, "School.ServingCounter", cf)
end

-- H 서가: 양면 5단 책꽂이
function P.Bookshelf(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local axis = runAxis(ctx, i, j, "H")
	local cf = CFrame.lookAt(p, p + axis)
	local m = model(ctx, "Bookshelf")
	local L = ctx.T
	local h = 7.4
	Kit.box(m, cf * CFrame.new(0, h / 2, 0), Vector3.new(0.3, h, L))
	for _, z in { -L / 2 + 0.15, L / 2 - 0.15 } do
		Kit.box(m, cf * CFrame.new(0, h / 2, z), Vector3.new(2.8, h, 0.25), SOFT)
	end
	for k = 0, 4 do
		Kit.box(m, cf * CFrame.new(0, 0.4 + k * 1.75, 0), Vector3.new(2.8, 0.15, L - 0.4), LINE)
	end
	for k = 0, 3 do -- 남은 책 묶음
		local r = ctx.hash(i, j, 40 + k)
		Kit.box(m, cf * CFrame.new(if r > 0.5 then 0.8 else -0.8, 1.15 + k * 1.75, (ctx.hash(i, j, 50 + k) - 0.5) * (L - 3.4)), Vector3.new(0.9, 1.3, 2.4), LINE)
	end
	solid(m, cf, Vector3.new(2.8, h, L))
	PM.dress(m, "School.Bookshelf", cf)
end

-- g 농구대(벽): 벽 지지대 + 백보드 + 림
function P.Hoop(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "Hoop")
	local z = ctx.T / 2
	local y = math.min(ctx.H - 3.2, 10)
	Kit.box(m, cf * CFrame.new(0, y, z - 2.4), Vector3.new(6.4, 4.0, 0.25), SOFT)
	Kit.box(m, cf * CFrame.new(0, y - 0.5, z - 2.6), Vector3.new(2.2, 1.6, 0.08), LINE)
	for _, x in { -1.6, 1.6 } do
		Kit.cylinder(m, at(cf, x, y + 0.6, z - 0.2), at(cf, x, y + 0.6, z - 2.3), 0.15, LINE)
	end
	local n = 8
	for k = 0, n - 1 do -- 림
		local a0, a1 = k * 2 * math.pi / n, (k + 1) * 2 * math.pi / n
		Kit.cylinder(m, at(cf, math.cos(a0) * 1.1, y - 1.4, z - 4.0 + math.sin(a0) * 1.1), at(cf, math.cos(a1) * 1.1, y - 1.4, z - 4.0 + math.sin(a1) * 1.1), 0.08, LINE)
	end
	-- 벽 아래 안전 매트(막힌 칸인 까닭)
	Kit.box(m, cf * CFrame.new(0, 2.6, z - 0.6), Vector3.new(7.6, 5.2, 1.0))
	solid(m, cf * CFrame.new(0, 0, z - 0.6), Vector3.new(7.6, 5.2, 1.1))
	PM.dress(m, if y < 9 then "School.HoopLow" else "School.Hoop", cf)
end

-- u 체육관 단상: 무대 한 칸(낮은 단 + 앞판 선 + 뒤 막)
function P.Stage(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.new(p)
	local m = model(ctx, "GymStage")
	local L = ctx.T
	Kit.box(m, cf * CFrame.new(0, 1.7, 0), Vector3.new(L, 3.4, L))
	Kit.box(m, cf * CFrame.new(0, 3.3, L / 2 + 0.05), Vector3.new(L, 0.25, 0.15), LINE)
	for _, x in { -L / 4, L / 4 } do
		Kit.box(m, cf * CFrame.new(x, 1.6, L / 2 + 0.05), Vector3.new(0.12, 2.8, 0.1), LINE)
	end
	for k = 0, 2 do -- 뒤쪽 막 주름
		Kit.box(m, cf * CFrame.new(-2.7 + k * 2.7, 3.4 + (ctx.H - 4.6) / 2, -L / 2 + 0.5) * CFrame.Angles(0, if k % 2 == 0 then 0.25 else -0.25, 0), Vector3.new(2.6, ctx.H - 4.6, 0.12), LINE)
	end
	PM.dress(m, if ctx.H < 12.5 then "School.StageLow" else "School.Stage", cf)
end

-- t 중정 나무: 굵은 줄기 + 사방 가지(잎 없는 겨울나무 — 음파에 가지 선이 또렷하다)
function P.Tree(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "Tree")
	local top = math.min(ctx.H - 0.6, 10.5)
	Kit.cylinder(m, p, p + Vector3.new(0.3, top * 0.6, 0.2), 0.7, SOFT)
	local fork = p + Vector3.new(0.3, top * 0.6, 0.2)
	for k = 0, 3 do
		local a = k * math.pi / 2 + ctx.hash(i, j, 60 + k) * 0.8
		local tip = fork + Vector3.new(math.cos(a) * 3.0, top * 0.35 + ctx.hash(i, j, 70 + k), math.sin(a) * 3.0)
		Kit.cylinder(m, fork, tip, 0.22, LINE)
	end
	Kit.box(m, CFrame.new(p + Vector3.new(0, 0.3, 0)), Vector3.new(4.4, 0.6, 4.4), LINE) -- 나무 둘레 보호틀
	solid(m, CFrame.new(p), Vector3.new(2.2, top, 2.2))
	PM.dress(m, "School.Tree", CFrame.new(p))
end

-- h 중정 동상: 두 단 받침대 + 책을 든 인물(머리·몸·팔 덩어리) — 중정 한가운데 랜드마크
function P.Statue(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.lookAt(p, p + Vector3.new(0, 0, 1))
	local m = model(ctx, "Statue")
	Kit.box(m, cf * CFrame.new(0, 0.6, 0), Vector3.new(6.4, 1.2, 6.4))
	Kit.box(m, cf * CFrame.new(0, 2.4, 0), Vector3.new(3.6, 2.4, 3.6))
	Kit.box(m, cf * CFrame.new(0, 4.6, 0), Vector3.new(1.8, 2.0, 1.1), SOFT) -- 다리·옷자락
	Kit.box(m, cf * CFrame.new(0, 6.6, 0), Vector3.new(2.2, 2.2, 1.2), SOFT) -- 몸
	Kit.ball(m, at(cf, 0, 8.3, 0), 0.75, SOFT) -- 머리
	Kit.box(m, cf * CFrame.new(1.2, 6.9, 0.7) * CFrame.Angles(-0.9, 0, 0), Vector3.new(0.5, 2.0, 0.5), SOFT) -- 책 든 팔
	Kit.box(m, cf * CFrame.new(1.2, 7.4, 1.4), Vector3.new(1.4, 1.0, 0.25), LINE) -- 책
	solid(m, cf, Vector3.new(6.4, 9, 6.4))
	PM.dress(m, "School.Statue", cf)
end

-- r 화단: 무릎 높이 벽돌 틀 + 마른 줄기 몇 개
function P.FlowerBed(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local axis = runAxis(ctx, i, j, "r")
	local cf = CFrame.lookAt(p, p + axis)
	local m = model(ctx, "FlowerBed")
	local L = ctx.T
	Kit.box(m, cf * CFrame.new(0, 0.9, 0), Vector3.new(4.6, 1.8, L))
	Kit.box(m, cf * CFrame.new(0, 1.85, 0), Vector3.new(3.8, 0.1, L - 0.8), LINE)
	for k = -1, 1 do
		local x = (ctx.hash(i, j, 80 + k) - 0.5) * 2.4
		Kit.cylinder(m, at(cf, x, 1.8, k * 2.4), at(cf, x * 1.2, 3.4, k * 2.6), 0.08, LINE)
	end
	PM.dress(m, "School.FlowerBed", cf)
end

-- j 중정 벤치: 앉는 판 + 등판 + 다리 둘
function P.Bench(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "Bench")
	Kit.box(m, cf * CFrame.new(0, 1.7, 1.2), Vector3.new(6.4, 0.25, 1.8), SOFT)
	Kit.box(m, cf * CFrame.new(0, 2.9, 2.1) * CFrame.Angles(-0.15, 0, 0), Vector3.new(6.4, 1.4, 0.2), SOFT)
	for _, x in { -2.6, 2.6 } do
		Kit.box(m, cf * CFrame.new(x, 0.85, 1.2), Vector3.new(0.3, 1.7, 1.6), LINE)
	end
	solid(m, cf * CFrame.new(0, 0, 1.2), Vector3.new(6.6, 2.0, 2.0))
	PM.dress(m, "School.Bench", cf)
end

-- q 뜀틀 + 접은 매트 더미(체육관 창고에서 끌어낸 것)
function P.VaultBox(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.new(p) * CFrame.Angles(0, (ctx.hash(i, j, 33) - 0.5) * 0.6, 0)
	local m = model(ctx, "VaultBox")
	for k = 0, 3 do -- 뜀틀 단(위로 갈수록 좁다)
		Kit.box(m, cf * CFrame.new(-1.2, 0.5 + k * 0.95, 0), Vector3.new(3.4 - k * 0.3, 0.9, 5.2 - k * 0.3), if k == 3 then SOFT else nil)
	end
	Kit.box(m, cf * CFrame.new(2.2, 0.9, 0) * CFrame.Angles(0, 0, 0.12), Vector3.new(2.4, 1.8, 5.6), SOFT) -- 접은 매트
	solid(m, cf, Vector3.new(7, 4, 6))
	PM.dress(m, "School.VaultBox", cf)
end

-- x 트로피 진열장(벽): 유리장 틀 + 선반 셋 + 트로피 몇 개
function P.TrophyCase(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "TrophyCase")
	local z = ctx.T / 2 - 1.1
	local h = math.min(ctx.H - 1.5, 8)
	Kit.box(m, cf * CFrame.new(0, h / 2, z), Vector3.new(6.6, h, 2.0), SOFT)
	for k = 1, 3 do
		Kit.box(m, cf * CFrame.new(0, k * h / 4, z - 0.2), Vector3.new(6.2, 0.12, 1.6), LINE)
		local x = (ctx.hash(i, j, 100 + k) - 0.5) * 4
		local c = at(cf, x, k * h / 4, z - 0.2)
		Kit.cylinder(m, c, c + Vector3.new(0, 1.2, 0), 0.35, LINE)
	end
	solid(m, cf * CFrame.new(0, 0, z), Vector3.new(6.6, h, 2.1))
	PM.dress(m, if h < 7.5 then "School.TrophyCaseLow" else "School.TrophyCase", cf)
end

-- w 정수기(벽, 지나감): 몸통 + 물통 + 컵 받침
function P.WaterCooler(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "WaterCooler")
	local z = ctx.T / 2 - 1.0
	Kit.box(m, cf * CFrame.new(1.8, 2.2, z), Vector3.new(1.8, 4.4, 1.8), SOFT)
	Kit.cylinder(m, at(cf, 1.8, 4.4, z), at(cf, 1.8, 6.0, z), 0.8, LINE)
	Kit.box(m, cf * CFrame.new(1.8, 3.0, z - 1.0), Vector3.new(1.2, 0.12, 0.3), LINE)
	PM.dress(m, "School.WaterCooler", cf)
end

-- P 프로젝터 스크린(시청각실 앞 벽): 내려온 스크린 막 + 위 통 + 아래 교탁
function P.ProjectorScreen(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "ProjectorScreen")
	local z = ctx.T / 2 - 0.3
	local top = ctx.H - 1.2
	Kit.box(m, cf * CFrame.new(0, top, z), Vector3.new(14, 0.6, 0.6), SOFT)
	Kit.box(m, cf * CFrame.new(0, top - 3.4, z - 0.1), Vector3.new(13, 6.2, 0.08), LINE)
	Kit.box(m, cf * CFrame.new(-2.2, 1.6, z - 2.2), Vector3.new(2.4, 3.2, 1.6), SOFT)
	solid(m, cf * CFrame.new(-2.2, 0, z - 2.2), Vector3.new(2.6, 3.4, 1.8))
	PM.dress(m, if ctx.H < 12.5 then "School.ProjectorScreenLow" else "School.ProjectorScreen", cf)
end

return P
