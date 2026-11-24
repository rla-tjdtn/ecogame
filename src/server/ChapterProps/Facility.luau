--!strict
-- 챕터 1 지하 시설 전용 소품(타일 문자 → 함수). Stage1.luau 의 Props 줄에서 쓴다.
-- 각 함수는 StageBuilder 의 ctx 와 타일 좌표(i, j)를 받는다. MapKit 부품만 쓰고(검은 무광, 음파 윤곽선),
-- 굵은 윤곽 위주로 부품 수를 적게(소품 하나 25개 이하) 한다. 막는 소품은 보이지 않는 충돌 상자를 둔다.
--   k 통제 콘솔(모니터 3대 + 경사 조작판 + 의자)      W 상황판(벽에 붙은 대형 화면, 지나갈 수 있음)
--   F 서류 캐비닛 줄(4단 서랍, 앞뒤 양면)              G 비상 발전기(2x2 머리 칸) / g 발전기 나머지 칸
--   P 배전반(고압 차단기 함 + 경고 삼각형)            U 냉각 배관 선반(굵은 배관 3단 + 받침)
--   j 정비 작업대(바이스·공구판)                       Y 공조기(큰 송풍기 둥근 얼굴 + 덕트, 2칸 머리) / y 나머지 칸
--   h 바닥 경고 줄무늬(지나갈 수 있음)

local Kit = require(script.Parent.Parent.MapKit)

local Facility = {}

local function base(ctx, i: number, j: number): Vector3
	return ctx.center(i, j) + Vector3.new(0, ctx.floorY(i, j), 0)
end

local function wallSide(ctx, i: number, j: number): Vector3?
	for _, d in { { 0, -1 }, { 1, 0 }, { -1, 0 }, { 0, 1 } } do
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

-- 막는 소품의 보이지 않는 충돌(타일 안)
local function solid(m: Instance, p: Vector3, size: Vector3)
	Kit.box(m, CFrame.new(p + Vector3.new(0, size.Y / 2, 0)), size, { invisible = true, tag = false })
end

-- 이 칸 둘레에서 같은 문자가 이어지는 축(가로면 x, 세로면 z)
local function runAxis(ctx, i: number, j: number, ch: string): Vector3
	if ctx.at(i, j - 1) == ch or ctx.at(i, j + 1) == ch then
		return Vector3.new(0, 0, 1)
	end
	return Vector3.new(1, 0, 0)
end

-- k 통제 콘솔: 조작원은 남쪽에 앉아 북쪽(상황판 쪽)을 본다
function Facility.Console(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "Console")
	local fwd = Vector3.new(0, 0, -1) -- 화면 쪽
	local cf = CFrame.lookAt(p, p + fwd)
	-- 받침 몸통 + 경사 조작판
	Kit.box(m, cf * CFrame.new(0, 1.4, -0.6), Vector3.new(6.4, 2.8, 2.6))
	Kit.wedge(m, cf * CFrame.new(0, 3.15, 0.2) * CFrame.Angles(0, math.pi, 0), Vector3.new(6.4, 0.7, 1.4), { blocks = false })
	-- 모니터 3대(가운데 정면, 양옆 살짝 안으로)
	for k = -1, 1 do
		local mc = cf * CFrame.new(k * 2.1, 4.6, -1.3) * CFrame.Angles(0, -k * 0.25, 0)
		Kit.box(m, mc, Vector3.new(1.9, 1.3, 0.2), { blocks = false })
		Kit.box(m, mc * CFrame.new(0, -0.95, 0.1), Vector3.new(0.25, 0.7, 0.25), { blocks = false, collide = false })
	end
	-- 의자(바퀴 기둥 + 좌판 + 등판)
	local ch = cf * CFrame.new(0.4, 0, 2.3)
	Kit.cylinder(m, (ch * CFrame.new(0, 0.2, 0)).Position, (ch * CFrame.new(0, 1.7, 0)).Position, 0.15, { blocks = false })
	Kit.box(m, ch * CFrame.new(0, 0.12, 0), Vector3.new(1.8, 0.2, 1.8), { blocks = false, collide = false })
	Kit.box(m, ch * CFrame.new(0, 1.85, 0), Vector3.new(1.7, 0.25, 1.7), { blocks = false })
	Kit.box(m, ch * CFrame.new(0, 3.0, 0.8), Vector3.new(1.7, 2.0, 0.2), { blocks = false })
	solid(m, p, Vector3.new(6.6, 3.2, 6.6))
end

-- W 상황판: 북쪽 벽(가장 가까운 벽)에 붙은 3x2 화면 + 테두리. 낮은 곳이 비어 있어 칸은 지나갈 수 있다
function Facility.VideoWall(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j) or Vector3.new(0, 0, -1)
	local across = Vector3.new(side.Z, 0, -side.X)
	local m = model(ctx, "VideoWall")
	local c = p + side * (ctx.T / 2 - 0.3) + Vector3.new(0, 7.2, 0)
	local cf = CFrame.lookAt(c, c - side)
	Kit.box(m, cf, Vector3.new(7.6, 4.6, 0.3), { collide = false, blocks = false })
	for a = -1, 1 do
		for b = -1, 1, 2 do
			Kit.box(m, cf * CFrame.new(a * 2.45, b * 1.1, -0.25), Vector3.new(2.3, 2.1, 0.2), { collide = false, blocks = false })
		end
	end
	-- 천장에서 내려온 받침 두 줄
	for _, s in { -1, 1 } do
		local t = c + across * (s * 3.2) + Vector3.new(0, 2.3, 0)
		Kit.cylinder(m, t, t + Vector3.new(0, math.max(0.5, ctx.H - 9.5), 0), 0.12, { collide = false, blocks = false })
	end
end

-- F 서류 캐비닛 줄: 이어진 방향으로 길게, 양면 4단 서랍
function Facility.FileCabinet(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local axis = runAxis(ctx, i, j, "F")
	local m = model(ctx, "FileCabinet")
	local len, h = ctx.T - 0.2, 6
	local cf = CFrame.lookAt(p + Vector3.new(0, h / 2, 0), p + Vector3.new(0, h / 2, 0) + axis)
	Kit.box(m, cf, Vector3.new(3.0, h, len))
	-- 서랍 줄(양면, 4단) + 칸 나눔
	for _, s in { -1, 1 } do
		for k = 1, 3 do
			Kit.box(m, cf * CFrame.new(s * 1.55, -h / 2 + k * h / 4, 0), Vector3.new(0.08, 0.1, len - 0.3), { blocks = false, collide = false })
		end
		Kit.box(m, cf * CFrame.new(s * 1.55, 0, 0), Vector3.new(0.08, h - 0.4, 0.12), { blocks = false, collide = false })
	end
	-- 위에 쌓인 상자 하나(칸마다 다르게)
	if ctx.hash(i, j, 11) > 0.5 then
		Kit.crate(m, p + Vector3.new(0, h, 0) + axis * ((ctx.hash(i, j, 12) - 0.5) * 3), Vector3.new(2.2, 1.4, 2.6), ctx.hash(i, j, 13) * 0.6)
	end
end

-- G 비상 발전기(2x2 칸, 이 칸이 왼쪽 위): 받침 스키드, 엔진 몸통, 방열기, 배기 굴뚝, 제어함
function Facility.Generator(ctx, i: number, j: number)
	local p = (base(ctx, i, j) + base(ctx, i + 1, j + 1)) / 2
	local m = model(ctx, "Generator")
	local T = ctx.T
	Kit.box(m, CFrame.new(p + Vector3.new(0, 0.5, 0)), Vector3.new(2 * T - 1.6, 1.0, 2 * T - 4.5), { name = "Skid" })
	Kit.box(m, CFrame.new(p + Vector3.new(-1.0, 3.6, 0)), Vector3.new(8.5, 5.2, 7.0), { name = "Engine" })
	-- 엔진 위 실린더 머리 줄
	for k = -1, 1 do
		Kit.box(m, CFrame.new(p + Vector3.new(-1.0 + k * 2.6, 6.6, 0)), Vector3.new(1.8, 0.8, 5.6), { blocks = false })
	end
	-- 방열기(한쪽 끝, 격자 무늬)
	local r = p + Vector3.new(5.0, 3.8, 0)
	Kit.box(m, CFrame.new(r), Vector3.new(1.6, 6.4, 7.6), { name = "Radiator" })
	for k = -2, 2 do
		Kit.box(m, CFrame.new(r + Vector3.new(0.85, k * 1.2, 0)), Vector3.new(0.1, 0.15, 7.0), { blocks = false, collide = false })
	end
	-- 배기 굴뚝(천장까지)
	local ex = p + Vector3.new(-4.0, 6.2, 2.0)
	Kit.cylinder(m, ex, ex + Vector3.new(0, 1.4, 0), 0.9, { blocks = false })
	Kit.pipe(m, ex + Vector3.new(0, 1.4, 0), Vector3.new(ex.X, ctx.H, ex.Z), 0.6, { 0.1, 0.9 }, false)
	-- 제어함 + 굵은 전선
	local cb = p + Vector3.new(-1.0, 3.0, -4.3)
	Kit.box(m, CFrame.new(cb), Vector3.new(2.6, 3.0, 0.9), { blocks = false })
	Kit.cylinder(m, cb + Vector3.new(1.0, -1.5, 0), p + Vector3.new(3.2, 0.3, -6.5), 0.22, { blocks = false, collide = false })
	solid(m, p, Vector3.new(2 * T - 1.2, 7.5, 2 * T - 1.2))
end

-- g 발전기 나머지 칸(G 가 다 짓는다)
function Facility.Filler(_ctx, _i: number, _j: number) end

-- P 배전반: 벽에 등을 댄 차단기 함 3칸, 손잡이, 경고 삼각형, 천장으로 올라가는 전선관
function Facility.Switchgear(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j) or Vector3.new(0, 0, -1)
	local across = Vector3.new(side.Z, 0, -side.X)
	local m = model(ctx, "Switchgear")
	local c = p + side * (ctx.T / 2 - 1.3) + Vector3.new(0, 3.6, 0)
	local cf = CFrame.lookAt(c, c - side)
	Kit.box(m, cf, Vector3.new(7.4, 7.2, 2.4))
	for k = -1, 1 do
		-- 문 테두리 + 손잡이
		Kit.box(m, cf * CFrame.new(k * 2.45, 0, -1.25), Vector3.new(2.2, 6.6, 0.1), { blocks = false, collide = false })
		Kit.box(m, cf * CFrame.new(k * 2.45 + 0.8, 0.2, -1.4), Vector3.new(0.15, 1.0, 0.2), { blocks = false, collide = false })
	end
	-- 경고 삼각형(가운데 문 위쪽)
	local t = cf * CFrame.new(0, 2.4, -1.35)
	for _, a in { 0, 2 * math.pi / 3, 4 * math.pi / 3 } do
		Kit.box(m, t * CFrame.Angles(0, 0, a) * CFrame.new(0, -0.3, 0), Vector3.new(1.05, 0.14, 0.08), { blocks = false, collide = false })
	end
	-- 전선관(천장으로)
	for _, s in { -1, 1 } do
		local a = c + across * (s * 2.5) + Vector3.new(0, 3.6, 0) + side * 0.4
		Kit.cylinder(m, a, Vector3.new(a.X, ctx.H, a.Z), 0.3, { blocks = false, collide = false })
	end
	solid(m, p + side * (ctx.T / 2 - 1.5), Vector3.new(if side.X ~= 0 then 3 else 7.6, 7.2, if side.X ~= 0 then 7.6 else 3))
end

-- U 냉각 배관 선반: 굵은 배관 3단이 이어진 방향으로 지나간다(벽 대신 서 있는 배관 벽)
function Facility.PipeRack(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local axis = Vector3.new(1, 0, 0)
	local x = function(ch: string): boolean
		return ch == "U" or ch == "v" or ch == "#"
	end
	if not (x(ctx.at(i - 1, j)) or x(ctx.at(i + 1, j))) and (x(ctx.at(i, j - 1)) or x(ctx.at(i, j + 1))) then
		axis = Vector3.new(0, 0, 1)
	end
	local across = Vector3.new(axis.Z, 0, -axis.X)
	local m = model(ctx, "PipeRack")
	local half = ctx.T / 2
	for k, y in { 1.6, 4.6, 7.8 } do
		local r = if k == 2 then 1.3 else 1.0
		local off = across * (if k == 2 then 0.6 else -0.5)
		Kit.pipe(m, p - axis * half + off + Vector3.new(0, y, 0), p + axis * half + off + Vector3.new(0, y, 0), r, if (i + j + k) % 2 == 0 then { 0.5 } else nil, false)
	end
	-- 받침 H 틀(칸 가운데)
	for _, s in { -1, 1 } do
		local leg = p + across * (s * 1.9)
		Kit.box(m, CFrame.new(leg + Vector3.new(0, 4.8, 0)), Vector3.new(0.35, 9.6, 0.35), { blocks = false })
	end
	Kit.box(m, CFrame.lookAt(p + Vector3.new(0, 9.6, 0), p + Vector3.new(0, 9.6, 0) + axis), Vector3.new(4.2, 0.35, 0.4), { blocks = false })
	-- 보이지 않는 충돌(배관 사이로 넘어가지 않게, 천장까지)
	Kit.box(m, CFrame.lookAt(p + Vector3.new(0, ctx.H / 2, 0), p + Vector3.new(0, ctx.H / 2, 0) + axis), Vector3.new(4.4, ctx.H, ctx.T), { invisible = true, tag = false })
end

-- j 정비 작업대: 철제 작업대 + 바이스 + 서랍, 벽 쪽 공구판
function Facility.Workbench(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j) or Vector3.new(0, 0, -1)
	local m = model(ctx, "Workbench")
	local c = p + side * (ctx.T / 2 - 1.9)
	local cf = CFrame.lookAt(c, c - side)
	Kit.box(m, cf * CFrame.new(0, 3.2, 0), Vector3.new(6.8, 0.3, 3.2))
	for _, x in { -3.1, 3.1 } do
		for _, z in { -1.4, 1.4 } do
			Kit.box(m, cf * CFrame.new(x, 1.5, z), Vector3.new(0.25, 3.0, 0.25), { blocks = false })
		end
	end
	Kit.box(m, cf * CFrame.new(-1.9, 2.1, 0), Vector3.new(2.4, 1.8, 2.8), { blocks = false }) -- 서랍함
	Kit.box(m, cf * CFrame.new(0, 0.5, 0), Vector3.new(6.4, 0.15, 2.8), { blocks = false, collide = false }) -- 아래 선반
	-- 바이스
	Kit.box(m, cf * CFrame.new(2.4, 3.75, -1.2), Vector3.new(1.0, 0.8, 1.2), { blocks = false })
	Kit.cylinder(m, (cf * CFrame.new(2.4, 3.75, -1.8)).Position, (cf * CFrame.new(2.4, 3.75, -2.5)).Position, 0.08, { blocks = false, collide = false })
	-- 공구판(벽면)
	local board = cf * CFrame.new(0, 6.0, 1.7)
	Kit.box(m, board, Vector3.new(6.4, 3.2, 0.12), { blocks = false, collide = false })
	for k = -2, 2 do
		Kit.box(m, board * CFrame.new(k * 1.2, -0.2 + (k % 2) * 0.5, -0.15), Vector3.new(0.18, 1.3, 0.12), { blocks = false, collide = false })
	end
	solid(m, c, Vector3.new(if side.X ~= 0 then 3.4 else 7, 4, if side.X ~= 0 then 7 else 3.4))
end

-- Y 공조기(2칸, 이 칸이 서쪽 끝, y 가 동쪽 칸): 상자 몸통, 남쪽으로 향한 둥근 송풍기 얼굴, 천장으로 올라가는 큰 덕트
function Facility.AirHandler(ctx, i: number, j: number)
	local p = (base(ctx, i, j) + base(ctx, i + 1, j)) / 2
	local m = model(ctx, "AirHandler")
	local fwd = Vector3.new(0, 0, 1)
	Kit.box(m, CFrame.new(p + Vector3.new(0, 3.6, -0.8)), Vector3.new(13.4, 7.2, 5.6), { name = "AHU" })
	-- 둥근 송풍기(앞면) 2개
	for _, s in { -1, 1 } do
		local f = p + Vector3.new(s * 3.3, 3.8, 2.0)
		Kit.cylinder(m, f, f + fwd * 0.4, 2.4, { blocks = false, rings = 2 })
		for k = 0, 2 do
			local a = k * math.pi / 3
			local bp = f + fwd * 0.5
			Kit.box(m, CFrame.lookAt(bp, bp + fwd) * CFrame.Angles(0, 0, a), Vector3.new(4.4, 0.18, 0.1), { blocks = false, collide = false })
		end
	end
	-- 덕트(천장으로)
	local d = p + Vector3.new(0, 7.2, -1.2)
	Kit.box(m, CFrame.new(Vector3.new(d.X, (d.Y + ctx.H) / 2, d.Z)), Vector3.new(5.0, math.max(1, ctx.H - d.Y), 3.4), { blocks = false })
	solid(m, p + Vector3.new(0, 0, -0.4), Vector3.new(14, 7.5, 7))
end

-- h 바닥 경고 줄무늬(화물 엘리베이터 앞·구덩이 둘레): 바닥에 얕게 솟은 빗금 판. 걸어서 지나간다
function Facility.Hazard(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "Hazard")
	for k = -1, 1 do
		local c = p + Vector3.new(k * 2.6, 0.04, 0)
		Kit.box(m, CFrame.new(c) * CFrame.Angles(0, math.pi / 4, 0), Vector3.new(1.0, 0.08, ctx.T * 0.6), { collide = false, blocks = false })
	end
end

return Facility
