--!nonstrict
-- 챕터 8 폐유치원 전용 소품(타일 문자 → 함수). Stage8.luau 의 Props 줄에서 쓴다.
-- MapKit 부품만(검은 무광, 음파 윤곽선). 모든 것이 어른 허리보다 낮다 — 괴물이 오히려 커 보이게. 막는 소품은 보이지 않는 충돌 상자를 둔다.
--   W 신발장(현관)      r 안내 창구         T 모둠 책상 + 작은 의자 넷    B 칠판 + 자석 글자판(벽)   k 가방장(벽)
--   P 풍금 + 의자       h 앞면 책장         M 쌓인 낮잠 매트              i 놀이집(지붕 있는 작은 집) X 큰 스펀지 블록
--   x 보건실 침대       I 어린이 세면대(벽)  a 유희실 무대                 F 낮은 식탁(긴 의자)       V 배식대
--   R 조리대 + 후드(벽) K 조리 작업대        J 정글짐                      w 그네                    e 시소
--   H 스프링 목마       g 모래밭(지나감)     u 화분 상자(벽)
--   Q 낮은 나무 울타리(마당)  l 가로등(후문, 지나감)  t 마른 나무(마당)

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

-- 같은 문자가 이어지는 방향(세로면 Z, 아니면 X)
local function runAxis(ctx, i: number, j: number, ch: string): Vector3
	if ctx.at(i, j - 1) == ch or ctx.at(i, j + 1) == ch then
		return Vector3.new(0, 0, 1)
	end
	return Vector3.new(1, 0, 0)
end

-- 벽을 등진 좌표계: 로컬 -Z = 방 안쪽, +Z = 벽 쪽
local function againstWall(ctx, i: number, j: number): CFrame
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j) or Vector3.new(0, 0, -1)
	return CFrame.lookAt(p, p - side)
end

local function at(cf: CFrame, x: number, y: number, z: number): Vector3
	return (cf * CFrame.new(x, y, z)).Position
end

-- 낮은 어린이 의자(등받이 한 장)
local function kidChair(m: Instance, cf: CFrame)
	Kit.box(m, cf * CFrame.new(0, 1.1, 0), Vector3.new(1.1, 0.14, 1.1), LINE)
	Kit.box(m, cf * CFrame.new(0, 1.75, 0.5), Vector3.new(1.1, 1.0, 0.12), LINE)
	Kit.box(m, cf * CFrame.new(0, 0.55, 0), Vector3.new(0.8, 1.1, 0.12), LINE)
end

-- W 신발장: 현관의 낮은 칸칸이 선반(양면), 위에 실내화 한두 켤레
function P.ShoeCubby(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.lookAt(p, p + runAxis(ctx, i, j, "W"))
	local m = model(ctx, "ShoeCubby")
	local L, h = ctx.T, 3.4
	Kit.box(m, cf * CFrame.new(0, h / 2, 0), Vector3.new(2.6, h, L))
	for _, s in { -1, 1 } do
		Kit.box(m, cf * CFrame.new(s * 1.34, h / 2, 0), Vector3.new(0.08, 0.12, L - 0.2), LINE)
		for k = -1, 1 do
			Kit.box(m, cf * CFrame.new(s * 1.34, h / 2, k * L / 4), Vector3.new(0.08, h - 0.2, 0.12), LINE)
		end
	end
	if ctx.hash(i, j, 3) > 0.4 then
		for _, x in { -0.4, 0.4 } do
			Kit.box(m, cf * CFrame.new(x, h + 0.2, (ctx.hash(i, j, 4) - 0.5) * 4), Vector3.new(0.5, 0.35, 1.1), LINE)
		end
	end
	PM.dress(m, "Kindergarten.ShoeCubby", cf) -- (소품 좌표: 바닥 가운데, Z = 신발장 길이)
end

-- r 안내 창구: 어른 허리 높이 카운터 + 유리 틀 + 출석부
function P.Reception(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.lookAt(p, p + runAxis(ctx, i, j, "r"))
	local m = model(ctx, "Reception")
	local L = ctx.T
	Kit.box(m, cf * CFrame.new(0, 1.7, 0), Vector3.new(2.6, 3.4, L))
	Kit.box(m, cf * CFrame.new(0, 3.5, 0), Vector3.new(3.4, 0.2, L), LINE)
	for _, z in { -L / 2 + 0.2, L / 2 - 0.2 } do
		Kit.box(m, cf * CFrame.new(0, 5.4, z), Vector3.new(0.2, 3.6, 0.2), LINE)
	end
	Kit.box(m, cf * CFrame.new(0, 7.2, 0), Vector3.new(0.2, 0.2, L), LINE)
	Kit.box(m, cf * CFrame.new(0.4, 3.7, 1.2) * CFrame.Angles(0, 0.3, 0), Vector3.new(1.2, 0.15, 1.6), LINE)
	PM.dress(m, "Kindergarten.Reception", cf)
end

-- T 모둠 책상: 육각으로 읽히는 둥근 판 + 작은 의자 넷(하나는 넘어졌다)
function P.KidTable(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.new(p) * CFrame.Angles(0, (ctx.hash(i, j, 3) - 0.5) * 0.8, 0)
	local m = model(ctx, "KidTable")
	Kit.cylinder(m, at(cf, 0, 2.0, 0), at(cf, 0, 2.2, 0), 1.7, SOFT)
	for k = 0, 2 do
		local a = k * 2 * math.pi / 3
		Kit.cylinder(m, at(cf, math.cos(a) * 1.2, 0, math.sin(a) * 1.2), at(cf, math.cos(a) * 1.2, 2.0, math.sin(a) * 1.2), 0.1, LINE)
	end
	local n = 3
	for k = 0, n - 1 do
		kidChair(m, cf * CFrame.Angles(0, k * 2 * math.pi / n + 0.4, 0) * CFrame.new(0, 0, 2.5) * CFrame.Angles(0, (ctx.hash(i, j, 5 + k) - 0.5) * 0.6, 0))
	end
	if ctx.hash(i, j, 9) > 0.5 then
		kidChair(m, cf * CFrame.new(-2.4, 0.6, -1.8) * CFrame.Angles(math.pi / 2, 0.6, 0))
	end
	solid(m, cf, Vector3.new(4.4, 2.4, 4.4))
	PM.dress(m, "Kindergarten.KidTable", cf)
end

-- B 칠판(벽, 낮게) + 자석 글자판 + 아래 교구 선반
function P.Board(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "Board")
	local z = ctx.T / 2 - 0.25
	Kit.box(m, cf * CFrame.new(0, 5.0, z), Vector3.new(13, 3.8, 0.2), LINE)
	Kit.box(m, cf * CFrame.new(0, 5.0, z - 0.14), Vector3.new(12.2, 3.0, 0.08), LINE)
	for k = 0, 3 do -- 자석 글자(네모·세모 조각)
		local r = ctx.hash(i, j, 20 + k)
		Kit.box(m, cf * CFrame.new(-4.2 + k * 1.5, 4.6 + r * 1.2, z - 0.22) * CFrame.Angles(0, 0, r * 2), Vector3.new(0.7, 0.7, 0.06), LINE)
	end
	-- 해 그림(원 하나)
	Kit.cylinder(m, at(cf, 4.2, 5.4, z - 0.2), at(cf, 4.2, 5.4, z - 0.28), 0.8, LINE)
	-- 낮은 교구 선반
	Kit.box(m, cf * CFrame.new(0, 1.2, z - 0.9), Vector3.new(7.2, 2.4, 1.6), SOFT)
	for k = -1, 1 do
		Kit.box(m, cf * CFrame.new(k * 1.8, 1.2, z - 1.74), Vector3.new(0.1, 2.2, 0.08), LINE)
	end
	solid(m, cf * CFrame.new(0, 0, z - 0.9), Vector3.new(7.2, 2.6, 1.8))
	PM.dress(m, "Kindergarten.Board", cf) -- (벽 등진 좌표: +Z = 벽)
end

-- k 가방장: 벽에 붙은 칸칸이 장 + 걸린 가방
function P.BagCubby(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "BagCubby")
	local z = ctx.T / 2 - 0.9
	local h = 4.4
	Kit.box(m, cf * CFrame.new(0, h / 2, z), Vector3.new(7.2, h, 1.6))
	Kit.box(m, cf * CFrame.new(0, h * 0.32, z - 0.84), Vector3.new(7.0, 0.12, 0.08), LINE)
	for k = -1, 1 do
		Kit.box(m, cf * CFrame.new(k * 1.8, h / 2, z - 0.84), Vector3.new(0.1, h - 0.2, 0.08), LINE)
	end
	local s = math.floor(ctx.hash(i, j, 6) * 4)
	local x = -2.7 + s * 1.8
	Kit.box(m, cf * CFrame.new(x, 2.6, z - 1.1), Vector3.new(1.1, 1.3, 0.6), LINE) -- 남은 가방
	solid(m, cf * CFrame.new(0, 0, z), Vector3.new(7.2, h, 1.8))
	PM.dress(m, "Kindergarten.BagCubby", cf)
end

-- P 풍금 + 작은 의자
function P.Organ(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "Organ")
	Kit.box(m, cf * CFrame.new(0, 2.1, 2.6), Vector3.new(5.6, 4.2, 1.8))
	Kit.box(m, cf * CFrame.new(0, 2.4, 1.2), Vector3.new(5.4, 0.35, 1.2), SOFT)
	for k = -3, 3 do
		Kit.box(m, cf * CFrame.new(k * 0.7, 2.62, 1.0), Vector3.new(0.16, 0.1, 0.8), LINE)
	end
	Kit.box(m, cf * CFrame.new(0, 4.9, 2.4) * CFrame.Angles(0.25, 0, 0), Vector3.new(2.6, 1.3, 0.1), LINE)
	for _, x in { -2.5, 2.5 } do
		Kit.box(m, cf * CFrame.new(x, 1.1, 0.8), Vector3.new(0.3, 2.2, 0.3), LINE)
	end
	Kit.box(m, cf * CFrame.new(0, 1.5, -0.8), Vector3.new(2.4, 0.3, 1.2), SOFT)
	for _, x in { -1, 1 } do
		Kit.box(m, cf * CFrame.new(x, 0.7, -0.8), Vector3.new(0.2, 1.4, 1.0), LINE)
	end
	solid(m, cf * CFrame.new(0, 0, 1.8), Vector3.new(5.8, 4.2, 3.2))
	PM.dress(m, "Kindergarten.Organ", cf)
end

-- h 앞면 책장: 낮은 2단(양쪽에서 책 표지가 보이는 경사 선반)
function P.KidShelf(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.lookAt(p, p + runAxis(ctx, i, j, "h"))
	local m = model(ctx, "KidShelf")
	local L, h = ctx.T, 4.2
	for _, z in { -L / 2 + 0.15, L / 2 - 0.15 } do
		Kit.box(m, cf * CFrame.new(0, h / 2, z), Vector3.new(2.6, h, 0.25), SOFT)
	end
	Kit.box(m, cf * CFrame.new(0, h / 2, 0), Vector3.new(0.3, h, L - 0.4))
	for _, y in { 0.3, 2.2 } do
		Kit.box(m, cf * CFrame.new(0, y, 0), Vector3.new(2.6, 0.15, L - 0.4), LINE)
	end
	for k = 0, 3 do -- 세워 둔 그림책 몇 권
		local r = ctx.hash(i, j, 30 + k)
		local s = if k % 2 == 0 then 1 else -1
		Kit.box(m, cf * CFrame.new(s * 0.7, (if k < 2 then 1.1 else 3.0), (r - 0.5) * (L - 3)) * CFrame.Angles(0, 0, s * 0.3), Vector3.new(0.12, 1.4, 1.2), LINE)
	end
	solid(m, cf, Vector3.new(2.6, h, L))
	PM.dress(m, "Kindergarten.KidShelf", cf)
end

-- M 쌓인 낮잠 매트 + 접은 이불
function P.MatPile(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "MatPile")
	for k = 0, 4 do
		local r = ctx.hash(i, j, 10 + k)
		Kit.box(m, cf * CFrame.new((r - 0.5) * 0.7, 0.3 + k * 0.62, 1.6) * CFrame.Angles(0, (r - 0.5) * 0.15, 0), Vector3.new(5.6, 0.55, 3.0), SOFT)
	end
	Kit.box(m, cf * CFrame.new(0.4, 3.5, 1.6) * CFrame.Angles(0, 0.2, 0), Vector3.new(2.6, 0.6, 2.0), LINE)
	solid(m, cf * CFrame.new(0, 0, 1.6), Vector3.new(6, 3.6, 3.4))
	PM.dress(m, "Kindergarten.MatPile", cf)
end

-- i 놀이집: 어린이 키만 한 집(벽 네 장·문 구멍·뾰족 지붕)
function P.Playhouse(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "Playhouse")
	local w, h = 5.6, 4.0
	Kit.box(m, cf * CFrame.new(0, h / 2, 2.6), Vector3.new(w, h, 0.2))
	for _, s in { -1, 1 } do
		Kit.box(m, cf * CFrame.new(s * w / 2, h / 2, 0), Vector3.new(0.2, h, 5.2))
		Kit.box(m, cf * CFrame.new(s * 2.0, h / 2, -2.6), Vector3.new(1.6, h, 0.2), SOFT)
		Kit.box(m, cf * CFrame.new(s * 1.6, h + 1.1, 0) * CFrame.Angles(0, 0, -s * 0.62), Vector3.new(4.2, 0.25, 6.2), SOFT)
	end
	Kit.box(m, cf * CFrame.new(0, 3.6, -2.6), Vector3.new(2.4, 0.8, 0.2), LINE)
	for _, s in { -1, 1 } do -- 창틀
		Kit.box(m, cf * CFrame.new(s * (w / 2 + 0.12), 2.6, 0), Vector3.new(0.06, 1.3, 1.6), LINE)
	end
	-- 안에 앉은 인형
	Kit.ball(m, at(cf, 0.4, 0.8, 1.2), 0.8, LINE)
	Kit.ball(m, at(cf, 0.4, 2.0, 1.2), 0.6, LINE)
	solid(m, cf, Vector3.new(5.8, 5.4, 5.4))
	PM.dress(m, "Kindergarten.Playhouse", cf)
end

-- X 큰 스펀지 블록(아치·원기둥·삼각)
function P.SoftBlocks(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.new(p) * CFrame.Angles(0, math.floor(ctx.hash(i, j, 3) * 4) * math.pi / 2, 0)
	local m = model(ctx, "SoftBlocks")
	Kit.box(m, cf * CFrame.new(-1.8, 1.4, 0), Vector3.new(1.6, 2.8, 2.4), SOFT)
	Kit.box(m, cf * CFrame.new(1.8, 1.4, 0), Vector3.new(1.6, 2.8, 2.4), SOFT)
	Kit.box(m, cf * CFrame.new(0, 3.4, 0), Vector3.new(5.4, 1.2, 2.4), SOFT)
	Kit.wedge(m, cf * CFrame.new(0, 4.8, 0), Vector3.new(2.4, 1.6, 2.6), LINE)
	Kit.cylinder(m, at(cf, -1.2, 1.0, 2.6), at(cf, 1.4, 1.0, 2.6), 1.0, LINE)
	Kit.box(m, cf * CFrame.new(2.4, 0.7, -2.4) * CFrame.Angles(0, 0.5, 0), Vector3.new(1.4, 1.4, 1.4), LINE)
	solid(m, cf, Vector3.new(5.6, 4.2, 4))
	PM.dress(m, "Kindergarten.SoftBlocks", cf)
end

-- x 보건실 어린이 침대 + 걷힌 커튼
function P.SickBed(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "SickBed")
	Kit.box(m, cf * CFrame.new(0, 1.7, 1.0), Vector3.new(3.0, 0.5, 5.0), SOFT)
	Kit.box(m, cf * CFrame.new(0, 2.1, 2.8), Vector3.new(2.0, 0.4, 1.0), LINE)
	for _, x in { -1.4, 1.4 } do
		for _, z in { -1.4, 3.4 } do
			Kit.cylinder(m, at(cf, x, 0, z), at(cf, x, if z > 0 then 3.0 else 2.4, z), 0.1, LINE)
		end
	end
	Kit.box(m, cf * CFrame.new(0, 2.6, 3.4), Vector3.new(2.8, 0.8, 0.1), LINE)
	-- 커튼 레일과 한쪽으로 몰린 커튼
	Kit.cylinder(m, at(cf, 2.6, 7.2, 3.6), at(cf, 2.6, 7.2, -2.6), 0.08, LINE)
	Kit.box(m, cf * CFrame.new(2.6, 4.2, 2.8), Vector3.new(0.5, 5.6, 1.4), LINE)
	solid(m, cf * CFrame.new(0, 0, 1.0), Vector3.new(3.2, 2.6, 5.4))
	PM.dress(m, "Kindergarten.SickBed", cf)
end

-- I 어린이 세면대: 무릎 높이 긴 개수대 + 낮은 거울 + 수도 셋
function P.KidSink(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "KidSink")
	local z = ctx.T / 2 - 1.1
	Kit.box(m, cf * CFrame.new(0, 1.8, z), Vector3.new(7.0, 0.8, 2.0), SOFT)
	Kit.box(m, cf * CFrame.new(0, 0.7, z + 0.4), Vector3.new(6.0, 1.4, 1.0), SOFT)
	for _, x in { -2.2, 0, 2.2 } do
		Kit.cylinder(m, at(cf, x, 2.2, z + 0.7), at(cf, x, 3.0, z + 0.7), 0.1, LINE)
		Kit.cylinder(m, at(cf, x, 3.0, z + 0.7), at(cf, x, 2.9, z), 0.1, LINE)
	end
	Kit.box(m, cf * CFrame.new(0, 4.4, ctx.T / 2 - 0.25), Vector3.new(6.8, 1.8, 0.1), LINE)
	solid(m, cf * CFrame.new(0, 0, z), Vector3.new(7.2, 2.4, 2.2))
	PM.dress(m, "Kindergarten.KidSink", cf)
end

-- a 유희실 무대 한 칸: 무릎 높이 단 + 앞판 + 뒤 막 주름 + 위 장식 띠
function P.Stage(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "Stage")
	local T = ctx.T
	Kit.box(m, cf * CFrame.new(0, 0.9, 0), Vector3.new(T, 1.8, T - 0.6), SOFT)
	Kit.box(m, cf * CFrame.new(0, 0.9, -T / 2 + 0.25), Vector3.new(T - 0.4, 1.4, 0.1), LINE)
	for k = -1, 1 do
		Kit.box(m, cf * CFrame.new(k * 2.6, 5.6, T / 2 - 0.5), Vector3.new(1.2, 7.4, 0.5), LINE)
	end
	Kit.box(m, cf * CFrame.new(0, 9.4, T / 2 - 1.0), Vector3.new(T, 1.0, 0.2), LINE)
	solid(m, cf, Vector3.new(T, 2.0, T - 0.6))
	PM.dress(m, "Kindergarten.Stage", cf)
end

-- F 낮은 식탁: 긴 상 + 붙은 긴 의자, 식판
function P.LunchTable(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.lookAt(p, p + runAxis(ctx, i, j, "F"))
	local m = model(ctx, "KidLunchTable")
	local L = ctx.T
	Kit.box(m, cf * CFrame.new(0, 2.0, 0), Vector3.new(2.4, 0.2, L), SOFT)
	for _, s in { -1, 1 } do
		Kit.box(m, cf * CFrame.new(s * 2.0, 1.1, 0), Vector3.new(0.9, 0.16, L), LINE)
	end
	for _, z in { -2.6, 2.6 } do
		Kit.box(m, cf * CFrame.new(0, 1.0, z), Vector3.new(0.3, 2.0, 0.3), LINE)
		Kit.box(m, cf * CFrame.new(0, 0.5, z), Vector3.new(4.2, 0.2, 0.25), LINE)
	end
	for k = 0, 1 do
		if ctx.hash(i, j, 22 + k) > 0.5 then
			Kit.box(m, cf * CFrame.new(0.4, 2.2, -2 + k * 3.4) * CFrame.Angles(0, 0.3, 0), Vector3.new(1.3, 0.12, 0.9), LINE)
		end
	end
	solid(m, cf, Vector3.new(4.8, 2.2, L))
	PM.dress(m, "Kindergarten.LunchTable", cf)
end

-- V 배식대: 카운터 + 국통 + 위 선반
function P.ServingCounter(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.lookAt(p, p + runAxis(ctx, i, j, "V"))
	local m = model(ctx, "ServingCounter")
	local L = ctx.T
	Kit.box(m, cf * CFrame.new(0, 1.5, 0), Vector3.new(2.8, 3.0, L))
	Kit.box(m, cf * CFrame.new(0, 3.1, 0), Vector3.new(3.4, 0.2, L), LINE)
	for _, z in { -L / 2 + 0.3, L / 2 - 0.3 } do
		Kit.box(m, cf * CFrame.new(0, 4.4, z), Vector3.new(0.2, 2.6, 0.2), LINE)
	end
	Kit.box(m, cf * CFrame.new(0, 5.8, 0), Vector3.new(2.2, 0.2, L), LINE)
	local c = at(cf, 0, 3.2, (ctx.hash(i, j, 25) - 0.5) * 3)
	Kit.cylinder(m, c, c + Vector3.new(0, 1.2, 0), 1.0, LINE)
	PM.dress(m, "Kindergarten.ServingCounter", cf)
end

-- R 조리대(벽): 화구 둘 + 큰 솥 + 배기 후드
function P.Range(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "Range")
	local z = ctx.T / 2 - 1.6
	local y = math.min(ctx.H - 4, 8)
	Kit.box(m, cf * CFrame.new(0, 1.6, z), Vector3.new(7.8, 3.2, 3.0))
	for _, x in { -1.9, 1.9 } do
		Kit.cylinder(m, at(cf, x, 3.25, z), at(cf, x, 3.4, z), 1.1, LINE)
		Kit.box(m, cf * CFrame.new(x, 1.6, z - 1.54), Vector3.new(3.2, 2.2, 0.08), LINE)
	end
	local pot = at(cf, if ctx.hash(i, j, 4) > 0.5 then 1.9 else -1.9, 3.4, z)
	Kit.cylinder(m, pot, pot + Vector3.new(0, 1.8, 0), 1.2, LINE)
	-- 배기 후드와 덕트
	Kit.box(m, cf * CFrame.new(0, y, z), Vector3.new(7.6, 1.4, 3.2), SOFT)
	Kit.box(m, cf * CFrame.new(0, (y + 0.7 + ctx.H) / 2, z + 0.6), Vector3.new(2.0, ctx.H - y - 0.7, 1.6), LINE)
	solid(m, cf * CFrame.new(0, 0, z), Vector3.new(7.8, 3.4, 3.2))
	PM.dress(m, "Kindergarten.Range", cf, Vector3.new(1, ctx.H / 14, 1))
end

-- K 조리 작업대: 스테인리스 상판 + 아래 선반 + 도마·양동이
function P.PrepTable(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.lookAt(p, p + runAxis(ctx, i, j, "K"))
	local m = model(ctx, "PrepTable")
	local L = ctx.T
	Kit.box(m, cf * CFrame.new(0, 3.2, 0), Vector3.new(3.6, 0.3, L), SOFT)
	Kit.box(m, cf * CFrame.new(0, 0.9, 0), Vector3.new(3.2, 0.15, L - 0.4), LINE)
	for _, x in { -1.6, 1.6 } do
		for _, z in { -L / 2 + 0.4, L / 2 - 0.4 } do
			Kit.box(m, cf * CFrame.new(x, 1.6, z), Vector3.new(0.2, 3.2, 0.2), LINE)
		end
	end
	Kit.box(m, cf * CFrame.new(0.3, 3.45, (ctx.hash(i, j, 5) - 0.5) * 4) * CFrame.Angles(0, 0.4, 0), Vector3.new(1.2, 0.15, 1.8), LINE)
	local c = at(cf, -0.2, 1.0, (ctx.hash(i, j, 6) - 0.5) * 4)
	Kit.cylinder(m, c, c + Vector3.new(0, 1.2, 0), 0.8, LINE)
	solid(m, cf, Vector3.new(3.6, 3.4, L))
	PM.dress(m, "Kindergarten.PrepTable", cf)
end

-- J 정글짐: 3x3 기둥 + 두 층 가로대
function P.JungleGym(ctx, i: number, j: number)
	local cf = CFrame.new(base(ctx, i, j))
	local m = model(ctx, "JungleGym")
	local s, h = 2.8, 7.2
	for _, x in { -s, 0, s } do
		for _, z in { -s, s } do
			Kit.cylinder(m, at(cf, x, 0, z), at(cf, x, h, z), 0.14, LINE)
		end
	end
	for _, y in { 2.4, 4.8, 7.2 } do
		for _, z in { -s, s } do
			Kit.cylinder(m, at(cf, -s, y, z), at(cf, s, y, z), 0.11, LINE)
		end
		for _, x in { -s, 0, s } do
			Kit.cylinder(m, at(cf, x, y, -s), at(cf, x, y, s), 0.11, LINE)
		end
	end
	solid(m, cf, Vector3.new(s * 2 + 0.3, h, s * 2 + 0.3))
	PM.dress(m, "Kindergarten.JungleGym", cf)
end

-- w 그네: A 자 다리 + 가로대 + 줄에 매달린 자리(하나는 비뚤어져 멈춰 있다)
function P.Swing(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.lookAt(p, p + Vector3.new(0, 0, -1)) -- 가로대는 X 방향
	local m = model(ctx, "Swing")
	local L, h = ctx.T, 7.4
	for _, x in { -L / 2 + 0.3, L / 2 - 0.3 } do
		for _, z in { -2.0, 2.0 } do
			Kit.cylinder(m, at(cf, x, 0, z), at(cf, x, h, 0), 0.16, LINE)
		end
	end
	Kit.cylinder(m, at(cf, -L / 2 + 0.3, h, 0), at(cf, L / 2 - 0.3, h, 0), 0.16, LINE)
	local off = (ctx.hash(i, j, 4) - 0.5) * 2.4
	for _, x in { -0.9, 0.9 } do
		Kit.cylinder(m, at(cf, x, h, 0), at(cf, x, 1.6 + math.abs(off) * 0.3, off), 0.06, LINE)
	end
	Kit.box(m, cf * CFrame.new(0, 1.5 + math.abs(off) * 0.3, off) * CFrame.Angles(off * 0.15, 0, 0), Vector3.new(2.0, 0.18, 0.9), LINE)
	solid(m, cf, Vector3.new(L - 0.4, 6, 3.4))
	PM.dress(m, "Kindergarten.Swing", cf)
end

-- e 시소: 받침 + 기운 긴 판 + 손잡이
function P.Seesaw(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.new(p) * CFrame.Angles(0, ctx.hash(i, j, 3) * 1.2 - 0.6, 0)
	local m = model(ctx, "Seesaw")
	Kit.wedge(m, cf * CFrame.new(0, 0.9, 0.6), Vector3.new(1.6, 1.8, 1.2), SOFT)
	Kit.wedge(m, cf * CFrame.new(0, 0.9, -0.6) * CFrame.Angles(0, math.pi, 0), Vector3.new(1.6, 1.8, 1.2), SOFT)
	local plank = cf * CFrame.new(0, 2.0, 0) * CFrame.Angles(0.22, 0, 0)
	Kit.box(m, plank, Vector3.new(1.2, 0.22, 7.6), SOFT)
	for _, z in { -2.4, 2.4 } do
		Kit.cylinder(m, at(plank, -0.5, 0, z), at(plank, -0.5, 1.2, z), 0.08, LINE)
		Kit.cylinder(m, at(plank, 0.5, 0, z), at(plank, 0.5, 1.2, z), 0.08, LINE)
		Kit.cylinder(m, at(plank, -0.5, 1.2, z), at(plank, 0.5, 1.2, z), 0.08, LINE)
	end
	solid(m, cf, Vector3.new(2.2, 2.6, 7.2))
	PM.dress(m, "Kindergarten.Seesaw", cf)
end

-- H 스프링 목마: 용수철 + 말 몸통·목·머리
function P.SpringHorse(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local cf = CFrame.new(p) * CFrame.Angles(0, ctx.hash(i, j, 3) * 6.28, 0) * CFrame.new(0, 0, 0)
	local m = model(ctx, "SpringHorse")
	for k = 0, 3 do -- 용수철 고리
		Kit.cylinder(m, at(cf, 0, 0.2 + k * 0.45, 0), at(cf, 0, 0.35 + k * 0.45, 0), 0.7, LINE)
	end
	local body = cf * CFrame.new(0, 2.6, 0) * CFrame.Angles((ctx.hash(i, j, 5) - 0.5) * 0.4, 0, 0)
	Kit.box(m, body, Vector3.new(1.2, 1.3, 3.2), SOFT)
	Kit.box(m, body * CFrame.new(0, 1.2, -1.5) * CFrame.Angles(0.5, 0, 0), Vector3.new(0.8, 2.0, 0.9), LINE)
	Kit.box(m, body * CFrame.new(0, 2.0, -2.2) * CFrame.Angles(-0.4, 0, 0), Vector3.new(0.8, 0.9, 1.6), LINE)
	Kit.cylinder(m, at(body, -1.1, 1.5, -1.5), at(body, 1.1, 1.5, -1.5), 0.1, LINE) -- 손잡이
	Kit.box(m, body * CFrame.new(0, 0.4, 1.8) * CFrame.Angles(0.5, 0, 0), Vector3.new(0.3, 1.4, 0.3), LINE) -- 꼬리
	solid(m, cf, Vector3.new(2.4, 4, 3.6))
	PM.dress(m, "Kindergarten.SpringHorse", cf)
end

-- g 모래밭(지나간다): 가장자리 턱 + 버려진 양동이·삽
function P.Sand(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "Sand")
	for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		if ctx.at(i + d[1], j + d[2]) ~= "g" and not ctx.isWall(i + d[1], j + d[2]) then
			local v = Vector3.new(d[1], 0, d[2])
			local e = p + v * (ctx.T / 2 - 0.3) + Vector3.new(0, 0.25, 0)
			Kit.box(m, CFrame.lookAt(e, e + v), Vector3.new(ctx.T, 0.5, 0.6), LINE)
		end
	end
	local r = ctx.hash(i, j, 8)
	if r > 0.75 then
		local c = p + Vector3.new((r - 0.85) * 12, 0, 1)
		Kit.cylinder(m, c, c + Vector3.new(0, 1.0, 0), 0.6, LINE)
	elseif r < 0.2 then
		Kit.ball(m, p + Vector3.new(0.6, 0.1, -0.8), 1.2, LINE) -- 모래 무더기
	end
end

-- u 화분 상자(벽): 나무 상자 + 마른 줄기
function P.Planter(ctx, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "Planter")
	local z = ctx.T / 2 - 1.2
	Kit.box(m, cf * CFrame.new(0, 0.8, z), Vector3.new(6.2, 1.6, 2.0))
	for k = 0, 3 do
		local r = ctx.hash(i, j, 12 + k)
		Kit.cylinder(m, at(cf, -2.2 + k * 1.5, 1.6, z), at(cf, -2.2 + k * 1.5 + (r - 0.5) * 1.6, 3.2 + r * 1.2, z - (r - 0.3)), 0.08, LINE)
	end
	solid(m, cf * CFrame.new(0, 0, z), Vector3.new(6.2, 2, 2.2))
	PM.dress(m, "Kindergarten.Planter", cf)
end

-- ── 바깥 마당(QA 재작업: 마당이 실내 방이 아니라 바깥으로 읽히게) ──
-- Q 낮은 나무 울타리(허리 높이 3.2): 기둥 + 가로대 둘 + 살 넷. 음파는 너머로 지나가고(blocks = false) 몸은 막는다(보이지 않는 높은 충돌 판)
function P.Fence(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "Fence")
	local ax = runAxis(ctx, i, j, "Q")
	if ax.X ~= 0 and not (ctx.at(i - 1, j) == "Q" or ctx.at(i + 1, j) == "Q") then
		-- 혼자 선 칸: 벽이 있는 쪽과 나란하게
		ax = if ctx.isWall(i, j - 1) or ctx.isWall(i, j + 1) then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
	end
	local cf = CFrame.lookAt(p, p + ax) -- 로컬 Z = 울타리 방향
	local L = ctx.T
	Kit.box(m, cf * CFrame.new(0, 1.0, 0), Vector3.new(0.25, 0.35, L), SOFT)
	Kit.box(m, cf * CFrame.new(0, 2.6, 0), Vector3.new(0.25, 0.35, L), SOFT)
	for k = 0, 3 do
		local z = -L / 2 + 1.0 + k * (L - 2.0) / 3
		Kit.box(m, cf * CFrame.new(0, 1.6, z), Vector3.new(0.3, 3.2, 0.5), LINE)
	end
	Kit.box(m, cf * CFrame.new(0, 3.5, 0), Vector3.new(0.12, 7.0, L), { invisible = true, tag = false }) -- (넘어가지 못하게)
	PM.dress(m, "Kindergarten.Fence", cf)
end

-- l 가로등(후문 양옆, 지나갈 수 있다): 받침 + 기둥 + 팔 + 등갓 = 부품 5개
function P.LampPost(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "LampPost")
	local top = math.min(ctx.H - 1.5, 11)
	local out = if ctx.at(i - 1, j) == "E" or ctx.at(i - 1, j - 1) == "E" then Vector3.new(-1, 0, 0) else Vector3.new(1, 0, 0)
	if ctx.at(i + 1, j - 1) == "E" then
		out = Vector3.new(1, 0, 0)
	end
	Kit.cylinder(m, p, p + Vector3.new(0, 0.6, 0), 0.7, LINE)
	Kit.cylinder(m, p, p + Vector3.new(0, top, 0), 0.22, SOFT)
	local a = p + Vector3.new(0, top - 0.3, 0)
	Kit.cylinder(m, a, a + out * 1.6, 0.1, LINE)
	Kit.wedge(m, CFrame.lookAt(a + out * 1.6 - Vector3.new(0, 0.5, 0), a + out * 1.6 - Vector3.new(0, 0.5, 0) + out), Vector3.new(1.2, 0.6, 1.0), LINE)
	Kit.box(m, CFrame.new(a + out * 1.6 - Vector3.new(0, 0.95, 0)), Vector3.new(0.7, 0.3, 0.7), LINE)
	PM.dress(m, "Kindergarten.LampPost", CFrame.lookAt(p, p + out), Vector3.new(1, top / 11, 1)) -- (-Z = 팔 방향)
end

-- t 마른 나무(마당): 줄기 + 가지 셋 + 듬성한 잎 덩어리 = 부품 6개, 줄기만 막는다
function P.Tree(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "Tree")
	local top = math.min(ctx.H - 2, 11)
	Kit.cylinder(m, p, p + Vector3.new(0, top * 0.6, 0), 0.7)
	for k = 0, 2 do
		local r = ctx.hash(i, j, 20 + k)
		local ang = k * 2.1 + r
		local a = p + Vector3.new(0, top * (0.45 + k * 0.08), 0)
		local b = a + Vector3.new(math.cos(ang) * 2.6, 1.8 + r, math.sin(ang) * 2.6)
		Kit.cylinder(m, a, b, 0.22, LINE)
	end
	Kit.ball(m, p + Vector3.new(0.4, top * 0.85, -0.3), 2.2, LINE)
	Kit.box(m, CFrame.new(p + Vector3.new(0, 0.1, 0)), Vector3.new(3.0, 0.2, 3.0), LINE) -- 나무 둘레 보호판
	PM.dress(m, "Kindergarten.Tree", CFrame.new(p), Vector3.new(1, top / 11, 1))
end

return P
