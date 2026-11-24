--!nonstrict
-- 챕터 5 심층 미로(버려진 지하 채석장 납골당 = 카타콤) 전용 소품. 모두 MapKit 부품만 쓴다(검은 무광 + 음파 윤곽).
-- 각 함수는 StageBuilder 의 ctx 와 타일 좌표(i, j)를 받는다. 1칸 = 8스터드, 사람 키 약 5스터드, 천장 14.
--   B 석조 보강 기둥       U 뼈 더미 벽(섬)       u 벽면에 붙여 쌓은 뼈(얇음, 밟고 지나감)   Q 해골 원통(랜드마크)
--   K 석회암 석재 블록     W 손 권양기            R 광차                                  r 광차 레일(바닥, 밟고 지나감)
--   N 갱도 이름 벽 명판    P 예배당 신도석        J 제단 + 벽 십자가                       Y 채석공 우물
--   G 수직갱 권양탑        I 지상으로 오르는 나선 계단(입구)                               V 석관
local Kit = require(script.Parent.Parent.MapKit)

local M = {}

local function base(ctx, i: number, j: number): Vector3
	return ctx.center(i, j) + Vector3.new(0, ctx.floorY(i, j), 0)
end

-- 가장 가까운 벽 방향(없으면 nil)
local function wallSide(ctx, i: number, j: number): Vector3?
	for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
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

local function height(ctx, i: number, j: number): number
	return ctx.H - ctx.floorY(i, j)
end

-- B: 석조 보강 기둥(채석 갱도 천장을 받치는 쌓은 돌 기둥) — 받침·몸·머리 세 덩어리, 줄눈 띠 둘
function M.Pillar(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local h = height(ctx, i, j)
	local m = model(ctx, "MasonryPillar")
	Kit.box(m, CFrame.new(p + Vector3.new(0, h / 2, 0)), Vector3.new(4.4, h, 4.4), { name = "Pillar" })
	Kit.box(m, CFrame.new(p + Vector3.new(0, 0.6, 0)), Vector3.new(6, 1.2, 6))
	Kit.box(m, CFrame.new(p + Vector3.new(0, h - 1.2, 0)), Vector3.new(6, 2.4, 6))
	for _, y in { h * 0.38, h * 0.66 } do
		Kit.box(m, CFrame.new(p + Vector3.new(0, y, 0)), Vector3.new(4.7, 0.25, 4.7), { blocks = false, collide = false })
	end
end

-- 해골 한 줄(뼈 벽 앞면): from → to 사이에 공 n 개
local function skullRow(m: Instance, a: Vector3, b: Vector3, n: number, r: number)
	for k = 0, n - 1 do
		local t = if n == 1 then 0.5 else k / (n - 1)
		Kit.ball(m, a:Lerp(b, t), r, { blocks = false, collide = false })
	end
end

-- U: 뼈 더미 벽(통로 가운데 섬) — 정강이뼈를 벽돌처럼 쌓고 해골 띠 두 줄을 박은 낮은 담. 어른 키보다 조금 높다
function M.BoneStack(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "BoneStack")
	local h = 6.2
	Kit.box(m, CFrame.new(p + Vector3.new(0, h / 2, 0)), Vector3.new(7.2, h, 5.6), { name = "Bones" })
	-- 해골 띠(긴 쪽 양면) + 위를 덮은 뼈 갓돌
	for _, s in { -1, 1 } do
		local z = s * 2.85
		skullRow(m, p + Vector3.new(-2.8, 2.2, z), p + Vector3.new(2.8, 2.2, z), 4, 0.45)
		skullRow(m, p + Vector3.new(-2.8, 4.6, z), p + Vector3.new(2.8, 4.6, z), 4, 0.45)
	end
	Kit.box(m, CFrame.new(p + Vector3.new(0, h + 0.2, 0)), Vector3.new(7.4, 0.4, 5.9), { blocks = false })
end

-- u: 벽면에 붙여 쌓은 뼈(두께 1.1) — 벽 장식이라 칸은 그대로 밟고 지나간다
function M.BoneFacing(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j)
	if not side then
		return
	end
	local m = model(ctx, "BoneFacing")
	local along = Vector3.new(side.Z, 0, -side.X)
	local c = p + side * (ctx.T / 2 - 0.55)
	Kit.box(m, CFrame.lookAt(c + Vector3.new(0, 3, 0), c + Vector3.new(0, 3, 0) - side), Vector3.new(ctx.T, 6, 1.1), { blocks = false })
	local f = c - side * 0.6
	skullRow(m, f + Vector3.new(0, 2.4, 0) - along * 2.8, f + Vector3.new(0, 2.4, 0) + along * 2.8, 4, 0.42)
	skullRow(m, f + Vector3.new(0, 4.8, 0) - along * 2.8, f + Vector3.new(0, 4.8, 0) + along * 2.8, 4, 0.42)
end

-- Q: 해골 원통(납골 회랑의 랜드마크) — 뼈를 둥글게 쌓아 올린 기둥, 해골 고리 둘
function M.SkullBarrel(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "SkullBarrel")
	Kit.cylinder(m, p, p + Vector3.new(0, 7, 0), 2.6, { name = "Barrel", rings = 2 })
	Kit.cylinder(m, p + Vector3.new(0, 7, 0), p + Vector3.new(0, 7.4, 0), 2.9, { blocks = false })
	for _, y in { 2.4, 5.0 } do
		for k = 0, 7 do
			local a = k * math.pi / 4
			Kit.ball(m, p + Vector3.new(math.cos(a) * 2.6, y, math.sin(a) * 2.6), 0.5, { blocks = false, collide = false })
		end
	end
end

-- K: 잘라 낸 석회암 블록 두세 개(아래 큰 것, 위 작은 것)
function M.StoneBlocks(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "StoneBlocks")
	local h = ctx.hash(i, j, 11)
	local yaw = (h - 0.5) * 0.5
	Kit.box(m, CFrame.new(p + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, yaw, 0), Vector3.new(6, 2.8, 4.2), { name = "Block" })
	Kit.box(m, CFrame.new(p + Vector3.new(-0.6, 3.9, 0.2)) * CFrame.Angles(0, yaw + 0.3, 0), Vector3.new(3.6, 2.2, 3), { name = "Block" })
	if h > 0.45 then
		Kit.box(m, CFrame.new(p + Vector3.new(2.2, 0.9, 2.6)) * CFrame.Angles(0, -0.4, 0), Vector3.new(2, 1.8, 1.6), { blocks = false })
	end
end

-- W: 손 권양기 — 양쪽 A자 나무 틀, 감는 드럼, 손잡이, 아래로 늘어진 밧줄과 갈고리
function M.Winch(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "Winch")
	for _, x in { -2.4, 2.4 } do
		Kit.box(m, CFrame.new(p + Vector3.new(x, 2.4, -1.0)) * CFrame.Angles(0.35, 0, 0), Vector3.new(0.5, 5.2, 0.5), { blocks = false })
		Kit.box(m, CFrame.new(p + Vector3.new(x, 2.4, 1.0)) * CFrame.Angles(-0.35, 0, 0), Vector3.new(0.5, 5.2, 0.5), { blocks = false })
		Kit.box(m, CFrame.new(p + Vector3.new(x, 0.25, 0)), Vector3.new(0.6, 0.5, 4.2), { blocks = false })
	end
	Kit.cylinder(m, p + Vector3.new(-2.2, 4.4, 0), p + Vector3.new(2.2, 4.4, 0), 0.9, { name = "Drum" })
	Kit.box(m, CFrame.new(p + Vector3.new(2.9, 4.4, 0.8)), Vector3.new(0.3, 0.3, 1.8), { blocks = false, collide = false })
	Kit.cylinder(m, p + Vector3.new(0.6, 4.4, 0.9), p + Vector3.new(0.6, 1.2, 0.9), 0.08, { blocks = false, collide = false })
	Kit.box(m, CFrame.new(p + Vector3.new(0.6, 1.0, 0.9)), Vector3.new(0.6, 0.5, 0.2), { blocks = false, collide = false })
	Kit.box(m, CFrame.new(p + Vector3.new(0, 2.5, 0)), Vector3.new(5.4, 5, 3.4), { invisible = true, tag = false })
end

-- 광차 방향: 이웃 레일(r)이 동서에 있으면 X 축
local function railAxis(ctx, i: number, j: number): Vector3
	if ctx.at(i - 1, j) == "r" or ctx.at(i + 1, j) == "r" then
		return Vector3.new(1, 0, 0)
	end
	if ctx.at(i, j - 1) == "r" or ctx.at(i, j + 1) == "r" then
		return Vector3.new(0, 0, 1)
	end
	return Vector3.new(1, 0, 0)
end

-- R: 광차(돌 싣는 쇠 수레) — 위가 넓은 통, 바퀴 넷, 레일 두 줄
function M.MineCart(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local ax = railAxis(ctx, i, j)
	local m = model(ctx, "MineCart")
	local cf = CFrame.lookAt(p, p + ax)
	Kit.box(m, cf * CFrame.new(0, 2.4, 0), Vector3.new(3.6, 2.4, 5.4), { name = "Tub" })
	Kit.box(m, cf * CFrame.new(0, 3.7, 0), Vector3.new(4.0, 0.3, 5.8), { blocks = false })
	for _, x in { -1.5, 1.5 } do
		for _, z in { -1.8, 1.8 } do
			local c = (cf * CFrame.new(x, 0.8, z)).Position
			Kit.cylinder(m, c - cf.RightVector * 0.2, c + cf.RightVector * 0.2, 0.75, { blocks = false })
		end
	end
	for _, x in { -1.5, 1.5 } do
		Kit.box(m, cf * CFrame.new(x, 0.1, 0), Vector3.new(0.3, 0.2, ctx.T), { blocks = false, collide = false })
	end
	Kit.box(m, cf * CFrame.new(0, 1.2, 0.4), Vector3.new(2.0, 0.9, 2.2), { blocks = false }) -- (실린 돌)
end

-- r: 광차 레일(바닥) — 침목 셋 + 레일 두 줄, 충돌 없음
function M.Rail(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local ax = railAxis(ctx, i, j)
	local m = model(ctx, "Rail")
	local cf = CFrame.lookAt(p, p + ax)
	for _, x in { -1.5, 1.5 } do
		Kit.box(m, cf * CFrame.new(x, 0.15, 0), Vector3.new(0.3, 0.3, ctx.T), { blocks = false, collide = false, axis = "Z" })
	end
	for _, z in { -2.6, 0, 2.6 } do
		Kit.box(m, cf * CFrame.new(0, 0.06, z), Vector3.new(4.2, 0.12, 0.8), { blocks = false, collide = false, shape = "None" })
	end
end

-- N: 갱도 이름을 새긴 벽 명판(카타콤 갱도마다 위 지상 거리 이름을 새겨 둔 판) — 벽면에 붙은 얇은 판
function M.Plaque(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j)
	if not side then
		return
	end
	local m = model(ctx, "Plaque")
	local c = p + side * (ctx.T / 2 - 0.15) + Vector3.new(0, 6.2, 0)
	Kit.box(m, CFrame.lookAt(c, c - side), Vector3.new(3.4, 1.4, 0.3), { blocks = false, collide = false })
	Kit.box(m, CFrame.lookAt(c - side * 0.2, c - side * 1.2), Vector3.new(2.6, 0.18, 0.12), { blocks = false, collide = false })
end

-- P: 예배당 신도석(등받이 나무 의자, 동쪽 제단을 바라본다)
function M.Pew(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "Pew")
	local face = Vector3.new(1, 0, 0) -- (제단은 동쪽)
	local cf = CFrame.lookAt(p, p + face)
	Kit.box(m, cf * CFrame.new(0, 1.7, 0), Vector3.new(ctx.T - 0.4, 0.3, 1.8), { blocks = false })
	Kit.box(m, cf * CFrame.new(0, 3.0, 1.0), Vector3.new(ctx.T - 0.4, 2.6, 0.25), { blocks = false })
	for _, x in { -3.4, 3.4 } do
		Kit.box(m, cf * CFrame.new(x, 1.6, 0.4), Vector3.new(0.3, 3.2, 2.4), { blocks = false })
	end
	Kit.box(m, cf * CFrame.new(0, 1.6, 0.3), Vector3.new(ctx.T - 0.4, 3.2, 2.4), { invisible = true, tag = false })
end

-- J: 제단(돌 제단 + 촛대 둘 + 뒤 벽 십자가) — 예배당 동쪽 끝 랜드마크
function M.Altar(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j) or Vector3.new(1, 0, 0)
	local along = Vector3.new(side.Z, 0, -side.X)
	local m = model(ctx, "Altar")
	local c = p + side * 1.2
	Kit.box(m, CFrame.lookAt(c + Vector3.new(0, 1.8, 0), c + Vector3.new(0, 1.8, 0) - side), Vector3.new(6.4, 3.6, 2.8), { name = "Altar" })
	Kit.box(m, CFrame.lookAt(c + Vector3.new(0, 3.75, 0), c + Vector3.new(0, 3.75, 0) - side), Vector3.new(7.0, 0.3, 3.2), { blocks = false })
	for _, s in { -1, 1 } do
		local cs = c + along * (s * 2.6) + Vector3.new(0, 3.9, 0)
		Kit.cylinder(m, cs, cs + Vector3.new(0, 1.6, 0), 0.15, { blocks = false, collide = false })
		Kit.cylinder(m, cs, cs + Vector3.new(0, 0.2, 0), 0.5, { blocks = false, collide = false })
	end
	local w = p + side * (ctx.T / 2 - 0.25) + Vector3.new(0, 8.4, 0)
	Kit.box(m, CFrame.lookAt(w, w - side), Vector3.new(0.6, 5.0, 0.4), { blocks = false, collide = false })
	Kit.box(m, CFrame.lookAt(w + Vector3.new(0, 1.0, 0), w + Vector3.new(0, 1.0, 0) - side), Vector3.new(3.0, 0.6, 0.4), { blocks = false, collide = false })
end

-- Y: 채석공 우물 — 둥근 돌 우물 턱, 나무 기둥 둘 + 도르래 보, 늘어진 밧줄과 두레박
function M.Well(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "Well")
	Kit.cylinder(m, p, p + Vector3.new(0, 2.6, 0), 3.0, { name = "WellCurb", rings = 2 })
	Kit.cylinder(m, p + Vector3.new(0, 2.6, 0), p + Vector3.new(0, 2.65, 0), 2.3, { blocks = false, collide = false, shape = "None" })
	for _, x in { -3.0, 3.0 } do
		Kit.box(m, CFrame.new(p + Vector3.new(x, 4.2, 0)), Vector3.new(0.5, 8.4, 0.5), { blocks = false })
	end
	Kit.box(m, CFrame.new(p + Vector3.new(0, 8.2, 0)), Vector3.new(6.6, 0.5, 0.5), { blocks = false })
	Kit.cylinder(m, p + Vector3.new(0, 8.2, -0.3), p + Vector3.new(0, 8.2, 0.3), 0.6, { blocks = false, collide = false })
	Kit.cylinder(m, p + Vector3.new(0, 7.6, 0), p + Vector3.new(0, 4.2, 0), 0.07, { blocks = false, collide = false })
	Kit.cylinder(m, p + Vector3.new(0, 3.4, 0), p + Vector3.new(0, 4.2, 0), 0.5, { blocks = false, collide = false })
end

-- G: 수직갱 권양탑 다리(출구 승강기 케이지를 매단 철골 탑) — 기둥 넷 + 가새 + 꼭대기 도르래 바퀴
function M.Headframe(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local h = height(ctx, i, j) - 0.6
	local m = model(ctx, "Headframe")
	for _, x in { -2.2, 2.2 } do
		for _, z in { -2.2, 2.2 } do
			Kit.box(m, CFrame.new(p + Vector3.new(x, h / 2, z)), Vector3.new(0.6, h, 0.6), { blocks = false })
		end
	end
	for _, y in { 4.0, 8.5 } do
		for _, z in { -2.2, 2.2 } do
			Kit.box(m, CFrame.new(p + Vector3.new(0, y, z)), Vector3.new(4.8, 0.4, 0.4), { blocks = false })
		end
		for _, x in { -2.2, 2.2 } do
			Kit.box(m, CFrame.new(p + Vector3.new(x, y, 0)), Vector3.new(0.4, 0.4, 4.8), { blocks = false })
		end
	end
	Kit.box(m, CFrame.new(p + Vector3.new(-2.2, 6.2, 0)) * CFrame.Angles(0.9, 0, 0), Vector3.new(0.3, 5.6, 0.3), { blocks = false, collide = false })
	Kit.cylinder(m, p + Vector3.new(-0.3, h - 1.6, 0), p + Vector3.new(0.3, h - 1.6, 0), 1.5, { blocks = false, collide = false, rings = 1 })
	Kit.box(m, CFrame.new(p + Vector3.new(0, 2.5, 0)), Vector3.new(5, 5, 5), { invisible = true, tag = false })
end

-- I: 지상으로 오르는 나선 계단(입구 계단실) — 가운데 돌기둥 + 천장으로 감겨 오르는 디딤판
function M.SpiralStair(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local h = height(ctx, i, j)
	local m = model(ctx, "SpiralStair")
	Kit.cylinder(m, p, p + Vector3.new(0, h, 0), 0.7, { name = "Newel" })
	local n = 10
	for k = 0, n - 1 do
		local a = k * (math.pi * 2 / 8)
		local y = 0.6 + k * (h - 1) / n
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local c = p + d * 1.9 + Vector3.new(0, y, 0)
		Kit.box(m, CFrame.lookAt(c, c + d), Vector3.new(1.6, 0.3, 2.6), { blocks = false })
	end
	Kit.cylinder(m, p + Vector3.new(0, 0.05, 0), p + Vector3.new(0, 0.1, 0), 3.4, { blocks = false, collide = false, shape = "None" })
	Kit.box(m, CFrame.new(p + Vector3.new(0, h / 2, 0)), Vector3.new(6.4, h, 6.4), { invisible = true, tag = false })
end

-- V: 석관(돌 관 + 비스듬히 밀린 뚜껑 + 뚜껑 위 십자)
function M.Sarcophagus(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "Sarcophagus")
	Kit.box(m, CFrame.new(p + Vector3.new(0, 1.5, 0)), Vector3.new(3.2, 3.0, 6.6), { name = "Coffin" })
	local lid = CFrame.new(p + Vector3.new(0.5, 3.25, 0.4)) * CFrame.Angles(0, 0.18, 0)
	Kit.box(m, lid, Vector3.new(3.4, 0.5, 6.8), { blocks = false })
	Kit.box(m, lid * CFrame.new(0, 0.35, -0.6), Vector3.new(0.4, 0.2, 3.4), { blocks = false, collide = false })
	Kit.box(m, lid * CFrame.new(0, 0.35, -1.4), Vector3.new(1.8, 0.2, 0.4), { blocks = false, collide = false })
end

return M
