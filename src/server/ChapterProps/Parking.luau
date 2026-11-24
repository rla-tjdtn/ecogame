--!nonstrict
-- 챕터 9 지하 주차장 전용 소품(타일 문자 → 함수). Stage9.luau 의 Props 줄에서 쓴다. MapKit 부품만(검은 무광, 음파 윤곽선).
--   Q 주차된 차(두 칸: 머리 + 꼬리 q)  W 덮개 씌운 차  I 사고 차량  l 빈 주차 칸(머리 + 꼬리 y)  q·y·X 빈 막힘/꼬리 칸(Blank)
--   B 굵은 기둥(맞댄 줄 이음선, 번호판)  r 램프 앞 바닥 화살표  e 엘리베이터 문  J 정산기  g 차단기  h 소화전  u 카트  x 셔터
--   C CCTV 콘솔  N 천장 안내 표지  j 제트 팬  d 환기 덕트  i 라바콘  w 과속 방지턱  G 비상 발전기  F 연료 탱크  R 배전반
--   P 소화 펌프  K 압력 탱크  H 저수조  M 집수정  V 급배기 팬  U 탑차(세로 두 칸)  z 파레트 잭  Y 재활용 수거함
-- 부품 수(성능): 차 5개 + 바닥선 2~3, 덮개 차 5개, 기둥 약 13개(번호판 한 면), 빈 칸 2~3개.

local Kit = require(script.Parent.Parent.MapKit)
local PM = require(script.Parent.Parent.PropMesh) -- 다 지은 소품을 메시 에셋으로 바꿔 입힌다(없으면 기본 도형 그대로)

-- (ctx.props 에 바로 넣는 소품: 지금 있는 것 기록 → 이 함수가 새로 만든 파트만 PM.dress 에 넘긴다)
local function snap(f: Instance): { [Instance]: boolean }
	local s = {}
	for _, c in f:GetChildren() do
		s[c] = true
	end
	return s
end
local function fresh(f: Instance, s: { [Instance]: boolean }): { BasePart }
	local out = {}
	for _, c in f:GetChildren() do
		if not s[c] and c:IsA("BasePart") then
			table.insert(out, c)
		end
	end
	return out
end

local P = {}

local function base(ctx: any, i: number, j: number): Vector3
	return ctx.center(i, j) + Vector3.new(0, ctx.floorY(i, j), 0)
end

local function wallDir(ctx: any, i: number, j: number): Vector3?
	for _, d in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
		if ctx.isWall(i + d[1], j + d[2]) then
			return Vector3.new(d[1], 0, d[2])
		end
	end
	return nil
end


local LINE = { blocks = false, collide = false }
local SOFT = { blocks = false }

local function model(ctx: any, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = ctx.props
	return m
end

-- ── 주차 칸(두 칸: 머리 Q·W·I·l + 꼬리 q·y) ──
local TAIL = { q = true, y = true }
local HEAD = { Q = true, W = true, I = true, l = true }

-- 머리 칸에서 꼬리 칸 쪽 단위 벡터(꼬리가 없으면 +Z)
local function tailDir(ctx: any, i: number, j: number): Vector3
	for _, d in { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } } do
		if TAIL[ctx.at(i + d[1], j + d[2])] then
			return Vector3.new(d[1], 0, d[2])
		end
	end
	return Vector3.new(0, 0, 1)
end

-- 주차 칸 바닥선: 한쪽 옆선(두 칸 길이) + 옆 칸이 주차 칸이 아니면 반대쪽 옆선 + 꼬리 끝 바퀴 멈춤턱 하나
local function stallLines(ctx: any, i: number, j: number, mid: Vector3, dir: Vector3)
	local T = ctx.T
	local across = Vector3.new(dir.Z, 0, -dir.X)
	for _, s in { -1, 1 } do
		local ni, nj = i + math.round(across.X * s), j + math.round(across.Z * s)
		if s == -1 or not HEAD[ctx.at(ni, nj)] then
			local p = mid + across * s * (T / 2 - 0.15) + Vector3.new(0, 0.04, 0)
			Kit.box(ctx.props, CFrame.lookAt(p, p + dir), Vector3.new(0.25, 0.08, 2 * T - 1), LINE)
		end
	end
	local st = mid + dir * (T - 1.1) + Vector3.new(0, 0.25, 0)
	Kit.box(ctx.props, CFrame.lookAt(st, st + dir), Vector3.new(3.6, 0.5, 0.6), LINE)
end

-- 두 칸 주차 칸의 가운데 바닥점과 방향
local function stallFrame(ctx: any, i: number, j: number): (Vector3, Vector3)
	local dir = tailDir(ctx, i, j)
	return base(ctx, i, j) + dir * (ctx.T / 2), dir
end

-- Q 주차된 차(실제 비율 5.6 x 12.8): 바퀴 띠 + 차체 + 객실 + 앞·뒤 유리 쐐기 = 부품 5개(+ 바닥선 2~3)
function P.Car(ctx: any, i: number, j: number)
	local mid, dir = stallFrame(ctx, i, j)
	stallLines(ctx, i, j, mid, dir)
	local nose = if ctx.hash(i, j, 91) < 0.5 then 1 else -1 -- 1: 앞이 벽(꼬리) 쪽, -1: 앞이 차로 쪽(후진 주차)
	local yaw = (ctx.hash(i, j, 92) - 0.5) * 0.08
	local cf = CFrame.lookAt(mid, mid + dir * nose) * CFrame.Angles(0, yaw, 0) -- 로컬 -Z = 차 앞
	local m = model(ctx, "Car")
	Kit.box(m, cf * CFrame.new(0, 0.7, 0), Vector3.new(5.2, 1.4, 10.2), SOFT) -- 바퀴·차 밑 띠
	Kit.box(m, cf * CFrame.new(0, 2.2, 0), Vector3.new(5.6, 1.8, 12.8), { name = "CarBody" })
	Kit.box(m, cf * CFrame.new(0, 3.9, 0.8), Vector3.new(5.0, 1.6, 5.6), { name = "CarCabin" })
	Kit.wedge(m, cf * CFrame.new(0, 3.9, -3.0), Vector3.new(5.0, 1.6, 2.0), LINE) -- 앞 유리
	Kit.wedge(m, cf * CFrame.new(0, 3.9, 4.3) * CFrame.Angles(0, math.pi, 0), Vector3.new(5.0, 1.6, 1.4), LINE) -- 뒤 유리
	PM.dress(m, "Parking.Car", cf) -- (소품 좌표: 차 바닥 가운데, -Z = 차 앞)
end

-- W 덮개 씌운 장기 주차 차: 차 모양 덩어리 위로 천이 늘어진다 = 부품 5개(+ 바닥선)
function P.CoveredCar(ctx: any, i: number, j: number)
	local mid, dir = stallFrame(ctx, i, j)
	stallLines(ctx, i, j, mid, dir)
	local cf = CFrame.lookAt(mid, mid + dir) * CFrame.Angles(0, (ctx.hash(i, j, 93) - 0.5) * 0.1, 0)
	local m = model(ctx, "CoveredCar")
	Kit.box(m, cf * CFrame.new(0, 1.5, 0), Vector3.new(6.0, 2.8, 13.0), { name = "CarCover" })
	Kit.box(m, cf * CFrame.new(0, 3.6, 0.6), Vector3.new(5.4, 1.4, 6.4), SOFT) -- 덮개 아래 객실 덩어리
	Kit.wedge(m, cf * CFrame.new(0, 3.6, -3.6), Vector3.new(5.4, 1.4, 2.0), LINE)
	Kit.wedge(m, cf * CFrame.new(0, 3.6, 4.6) * CFrame.Angles(0, math.pi, 0), Vector3.new(5.4, 1.4, 1.6), LINE)
	-- 바닥까지 끌린 천 자락(한쪽 옆)
	local s = if ctx.hash(i, j, 94) < 0.5 then 1 else -1
	Kit.box(m, cf * CFrame.new(s * 3.3, 1.2, 1.5) * CFrame.Angles(0, 0, s * 0.25), Vector3.new(0.12, 2.6, 7.0), LINE)
	PM.dress(m, "Parking.CoveredCar", cf)
end

-- I 사고 차량: 차로를 가로질러 비스듬히 멈춘 차(앞이 찌그러지고 문 하나가 바닥에) = 부품 6개
function P.CrashedCar(ctx: any, i: number, j: number)
	local mid, dir = stallFrame(ctx, i, j)
	local cf = CFrame.lookAt(mid, mid + dir) * CFrame.Angles(0, 0.35, 0)
	local m = model(ctx, "CrashedCar")
	Kit.box(m, cf * CFrame.new(0, 0.7, 0.4), Vector3.new(5.2, 1.4, 9.6), SOFT)
	Kit.box(m, cf * CFrame.new(0, 2.2, 0.6), Vector3.new(5.6, 1.8, 11.6), { name = "CarBody" })
	Kit.wedge(m, cf * CFrame.new(0, 2.0, -5.9) * CFrame.Angles(0.25, 0, 0), Vector3.new(5.4, 1.6, 1.8), LINE) -- 찌그러진 앞
	Kit.box(m, cf * CFrame.new(0.3, 3.8, 1.6) * CFrame.Angles(0, 0, 0.12), Vector3.new(4.8, 1.5, 5.2), { name = "CarCabin" })
	Kit.box(m, cf * CFrame.new(-4.6, 0.15, -0.5) * CFrame.Angles(0, 0.6, 0), Vector3.new(0.3, 0.3, 3.4), LINE) -- 떨어진 문짝
	Kit.box(m, cf * CFrame.new(3.6, 0.06, -3.0), Vector3.new(2.6, 0.08, 1.8), LINE) -- 유리 조각 더미
	PM.dress(m, "Parking.CrashedCar", cf)
end

-- l 빈 주차 칸(두 칸 바닥선만)
function P.EmptyStall(ctx: any, i: number, j: number)
	local mid, dir = stallFrame(ctx, i, j)
	stallLines(ctx, i, j, mid, dir)
end

-- q·y·X: 차 꼬리·빈 칸 꼬리·기둥이 걸친 칸(머리 칸이나 기둥이 함께 짓는다)
function P.Blank(_ctx: any, _i: number, _j: number) end

-- 굵은 기둥 + 모서리 보호대 + 네 면 번호판(7세그먼트 숫자 두 자리)
local SEG = {
	["0"] = "abcdef", ["1"] = "bc", ["2"] = "abged", ["3"] = "abgcd", ["4"] = "fgbc",
	["5"] = "afgcd", ["6"] = "afgedc", ["7"] = "abc", ["8"] = "abcdefg", ["9"] = "abcdfg",
}
local function digit(ctx: any, ch: string, origin: Vector3, right: Vector3, out: Vector3, h: number)
	local w, t = h * 0.55, h * 0.13
	local half = h / 2
	local bars = {
		a = { 0, h, w, h }, b = { w, h, w, half }, c = { w, half, w, 0 }, d = { 0, 0, w, 0 },
		e = { 0, half, 0, 0 }, f = { 0, h, 0, half }, g = { 0, half, w, half },
	}
	for k in (SEG[ch] or ""):gmatch(".") do
		local b = bars[k]
		local a = origin + right * b[1] + Vector3.yAxis * b[2] + out * 0.1
		local z = origin + right * b[3] + Vector3.yAxis * b[4] + out * 0.1
		local d = z - a
		ctx.Kit.box(ctx.props, CFrame.fromMatrix((a + z) / 2, d.Unit, out:Cross(d.Unit).Unit), Vector3.new(d.Magnitude + t, t, 0.12), { blocks = false, collide = false })
	end
end

-- B 굵은 기둥: 맞댄 주차 줄에서는 이음선(옆 칸 X 쪽으로 반 칸) 위에, 벽 쪽에서는 칸 가운데. 기둥 + 머리 + 보호대 띠 +
-- 차로 쪽 한 면 번호판(7세그먼트 숫자 두 자리) = 부품 약 13개. 두 층 기둥이 같은 자리라 번호가 층마다 같다
function P.Pillar(ctx: any, i: number, j: number)
	local Kit = ctx.Kit
	local p = base(ctx, i, j)
	for _, d in { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } } do
		if ctx.at(i + d[1], j + d[2]) == "X" then
			p += Vector3.new(d[1], 0, d[2]) * (ctx.T / 2)
			break
		end
	end
	local h = ctx.H - ctx.floorY(i, j)
	Kit.box(ctx.geo, CFrame.new(p + Vector3.new(0, h / 2, 0)), Vector3.new(4.0, h, 4.0), { name = "Pillar" })
	Kit.box(ctx.geo, CFrame.new(p + Vector3.new(0, h - 0.8, 0)), Vector3.new(5.0, 1.6, 5.0), { name = "PillarCap" })
	Kit.box(ctx.props, CFrame.new(p + Vector3.new(0, 2.0, 0)), Vector3.new(4.3, 0.5, 4.3), LINE) -- 모서리 보호대 띠
	local label = string.format("%02d", (j * 47 + i) % 97) -- 칸 위치로 정해지는 번호(다시 지어도 같다)
	local f = if ctx.hash(i, j, 5) < 0.5 then Vector3.zAxis else -Vector3.zAxis -- 차로 쪽 한 면
	if ctx.isWall(i, j - 1) then
		f = Vector3.zAxis
	elseif ctx.isWall(i, j + 1) then
		f = -Vector3.zAxis
	end
	local right = Vector3.new(f.Z, 0, -f.X)
	local face = p + f * 2.05 + Vector3.new(0, 5.2, 0)
	Kit.box(ctx.props, CFrame.lookAt(face, face + f), Vector3.new(2.8, 1.9, 0.1), LINE)
	local dh = 1.2
	for n = 1, 2 do
		local o = face + Vector3.new(0, -dh / 2, 0) + right * ((n - 1.5) * dh * 0.95 - dh * 0.27) + f * 0.05
		digit(ctx, label:sub(n, n), o, right, f, dh)
	end
end

-- 손수레(카트): 벽 쪽으로 붙여 둔다
function P.Cart(ctx: any, i: number, j: number)
	local Kit = ctx.Kit
	local side = wallDir(ctx, i, j) or Vector3.new(1, 0, 0)
	local p = base(ctx, i, j) + side * 2.0
	local yaw = ctx.hash(i, j, 7) * 1.2
	local cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
	local m = Instance.new("Model")
	m.Name = "Cart"
	m.Parent = ctx.props
	Kit.box(m, cf * CFrame.new(0, 0.9, 0), Vector3.new(2.4, 0.2, 3.6))
	Kit.crate(m, (cf * CFrame.new(0, 1.0, 0.4)).Position, Vector3.new(2.0, 1.6, 2.0), yaw + 0.1)
	for _, x in { -1.0, 1.0 } do
		for _, z in { -1.5, 1.5 } do
			Kit.cylinder(m, (cf * CFrame.new(x - 0.15, 0.35, z)).Position, (cf * CFrame.new(x + 0.15, 0.35, z)).Position, 0.35, { blocks = false, collide = false })
		end
		Kit.cylinder(m, (cf * CFrame.new(x, 0.9, -1.8)).Position, (cf * CFrame.new(x, 3.6, -1.9)).Position, 0.08, { blocks = false, collide = false })
	end
	Kit.cylinder(m, (cf * CFrame.new(-1.0, 3.6, -1.9)).Position, (cf * CFrame.new(1.0, 3.6, -1.9)).Position, 0.08, { blocks = false, collide = false })
	PM.dress(m, "Parking.Cart", cf)
end

-- 소화전: 벽에 붙은 소화전함 + 바닥 소화전
function P.Hydrant(ctx: any, i: number, j: number)
	local Kit = ctx.Kit
	local s0 = snap(ctx.props)
	local side = wallDir(ctx, i, j) or Vector3.new(0, 0, -1)
	local p = base(ctx, i, j)
	local face = p + side * (ctx.T / 2 - 0.4)
	Kit.box(ctx.props, CFrame.lookAt(face + Vector3.new(0, 4.2, 0), face + Vector3.new(0, 4.2, 0) - side), Vector3.new(2.8, 3.4, 0.8), { blocks = false })
	Kit.box(ctx.props, CFrame.lookAt(face + Vector3.new(0, 4.2, 0) - side * 0.42, face + Vector3.new(0, 4.2, 0) - side), Vector3.new(2.2, 2.8, 0.05), { blocks = false, collide = false })
	local post = face - side * 0.9 + Vector3.new(side.Z, 0, -side.X) * 2.2
	Kit.cylinder(ctx.props, post, post + Vector3.new(0, 2.2, 0), 0.4, { blocks = false })
	Kit.ball(ctx.props, post + Vector3.new(0, 2.3, 0), 0.42, { blocks = false, collide = false })
	Kit.cylinder(ctx.props, post + Vector3.new(0, 1.5, 0) - Vector3.new(side.Z, 0, -side.X) * 0.7, post + Vector3.new(0, 1.5, 0) + Vector3.new(side.Z, 0, -side.X) * 0.7, 0.18, { blocks = false, collide = false })
	PM.dress(ctx.props, "Parking.Hydrant", CFrame.lookAt(face, face - side), nil, fresh(ctx.props, s0), ctx.props) -- (소품 좌표: 벽면 바닥, -Z = 방 안쪽)
end

-- 엘리베이터 문(벽면): 문틀 + 두 짝 + 호출 버튼
function P.Elevator(ctx: any, i: number, j: number)
	local Kit = ctx.Kit
	local s0 = snap(ctx.props)
	local side = wallDir(ctx, i, j) or Vector3.new(0, 0, -1)
	local right = Vector3.new(side.Z, 0, -side.X)
	local face = base(ctx, i, j) + side * (ctx.T / 2 - 0.15)
	for _, s in { -1, 1 } do
		local jp = face + right * s * 2.9 + Vector3.new(0, 4.5, 0)
		Kit.box(ctx.props, CFrame.lookAt(jp, jp - side), Vector3.new(0.6, 9, 0.5), { blocks = false })
		local dp = face + right * s * 1.3 + Vector3.new(0, 4.2, 0) - side * 0.05
		Kit.box(ctx.props, CFrame.lookAt(dp, dp - side), Vector3.new(2.5, 8.2, 0.12), { blocks = false, collide = false })
	end
	local top = face + Vector3.new(0, 9.2, 0)
	Kit.box(ctx.props, CFrame.lookAt(top, top - side), Vector3.new(6.4, 0.8, 0.5), { blocks = false })
	local btn = face + right * 3.8 + Vector3.new(0, 4.0, 0) - side * 0.1
	Kit.box(ctx.props, CFrame.lookAt(btn, btn - side), Vector3.new(0.5, 1.0, 0.15), { blocks = false, collide = false })
	PM.dress(ctx.props, "Parking.Elevator", CFrame.lookAt(face, face - side), nil, fresh(ctx.props, s0), ctx.props)
end

-- 셔터(하역장 벽면): 말린 셔터 통 + 가로 살
function P.Shutter(ctx: any, i: number, j: number)
	local Kit = ctx.Kit
	local s0 = snap(ctx.props)
	local side = wallDir(ctx, i, j) or Vector3.new(0, 0, 1)
	local right = Vector3.new(side.Z, 0, -side.X)
	local face = base(ctx, i, j) + side * (ctx.T / 2 - 0.2)
	for y = 0.4, 9.0, 0.75 do
		local sp = face + Vector3.new(0, y, 0)
		Kit.box(ctx.props, CFrame.lookAt(sp, sp - side), Vector3.new(ctx.T - 0.2, 0.6, 0.12), { blocks = false, collide = false })
	end
	Kit.cylinder(ctx.props, face + Vector3.new(0, 9.9, 0) - right * (ctx.T / 2) - side * 0.4, face + Vector3.new(0, 9.9, 0) + right * (ctx.T / 2) - side * 0.4, 0.8, { blocks = false, collide = false })
	-- 하역장 바닥 정지선
	local st = face - side * 2.5 + Vector3.new(0, 0.04, 0)
	Kit.box(ctx.props, CFrame.lookAt(st, st - side), Vector3.new(ctx.T - 1, 0.08, 0.35), { blocks = false, collide = false })
	PM.dress(ctx.props, "Parking.Shutter", CFrame.lookAt(face, face - side), nil, fresh(ctx.props, s0), ctx.props)
end

-- 차량 출구 차단기: 벽 쪽 기둥 + 위로 들린 막대
function P.Barrier(ctx: any, i: number, j: number)
	local Kit = ctx.Kit
	local s0 = snap(ctx.props)
	local side = wallDir(ctx, i, j) or Vector3.new(0, 0, -1)
	local p = base(ctx, i, j)
	local post = p + side * (ctx.T / 2 - 1.0)
	Kit.box(ctx.props, CFrame.new(post + Vector3.new(0, 1.9, 0)), Vector3.new(1.3, 3.8, 1.3), { name = "BarrierPost" })
	local hinge = post + Vector3.new(0, 3.4, 0)
	local tip = hinge - side * 1.6 + Vector3.new(0, 6.0, 0)
	Kit.cylinder(ctx.props, hinge, tip, 0.18, { blocks = false, collide = false })
	-- 바닥 정지선
	local axis = Vector3.new(side.Z, 0, -side.X)
	Kit.box(ctx.props, CFrame.lookAt(p + Vector3.new(0, 0.04, 0), p + Vector3.new(0, 0.04, 0) + axis), Vector3.new(ctx.T - 0.5, 0.08, 0.4), { blocks = false, collide = false })
	PM.dress(ctx.props, "Parking.Barrier", CFrame.lookAt(post, post - side), nil, fresh(ctx.props, s0), ctx.props) -- (소품 좌표: 기둥 바닥, -Z = 차로 쪽)
end

-- 주차 정산기(벽에 붙은 키오스크)
function P.PayMachine(ctx: any, i: number, j: number)
	local Kit = ctx.Kit
	local s0 = snap(ctx.props)
	local side = wallDir(ctx, i, j) or Vector3.new(0, 0, -1)
	local p = base(ctx, i, j) + side * (ctx.T / 2 - 1.1)
	Kit.box(ctx.props, CFrame.lookAt(p + Vector3.new(0, 2.6, 0), p + Vector3.new(0, 2.6, 0) - side), Vector3.new(2.6, 5.2, 1.8), { name = "PayMachine" })
	local f = p - side * 0.92
	Kit.box(ctx.props, CFrame.lookAt(f + Vector3.new(0, 3.9, 0), f + Vector3.new(0, 3.9, 0) - side), Vector3.new(1.8, 1.2, 0.06), { blocks = false, collide = false })
	Kit.box(ctx.props, CFrame.lookAt(f + Vector3.new(0, 2.6, 0), f + Vector3.new(0, 2.6, 0) - side), Vector3.new(1.0, 0.2, 0.15), { blocks = false, collide = false })
	Kit.box(ctx.props, CFrame.lookAt(f + Vector3.new(0, 1.3, 0), f + Vector3.new(0, 1.3, 0) - side), Vector3.new(1.6, 0.5, 0.2), { blocks = false, collide = false })
	PM.dress(ctx.props, "Parking.PayMachine", CFrame.lookAt(p, p - side), nil, fresh(ctx.props, s0), ctx.props)
end


local function solid(m: Instance, cf: CFrame, size: Vector3)
	Kit.box(m, cf * CFrame.new(0, size.Y / 2, 0), size, { invisible = true, tag = false })
end
-- 벽을 등진 좌표계: 로컬 -Z = 방 안쪽, +Z = 벽 쪽
local function againstWall(ctx: any, i: number, j: number): CFrame
	local p = base(ctx, i, j)
	local side = wallDir(ctx, i, j) or Vector3.new(0, 0, -1)
	return CFrame.lookAt(p, p - side)
end
local function at(cf: CFrame, x: number, y: number, z: number): Vector3
	return (cf * CFrame.new(x, y, z)).Position
end
-- 이 칸의 바닥에서 천장까지 높이
local function roomH(ctx: any, i: number, j: number): number
	return ctx.H - ctx.floorY(i, j)
end

-- C 방재실 CCTV 콘솔: 책상 + 모니터 벽(2단 3열) + 의자
function P.CctvDesk(ctx: any, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "CctvDesk")
	Kit.box(m, cf * CFrame.new(0, 1.5, 2.0), Vector3.new(7.6, 3.0, 2.4), SOFT)
	Kit.wedge(m, cf * CFrame.new(0, 3.4, 1.7), Vector3.new(7.4, 0.8, 1.6), LINE)
	for k = -1, 1 do
		for r = 0, 1 do
			Kit.box(m, cf * CFrame.new(k * 2.4, 5.0 + r * 1.9, 3.2), Vector3.new(2.1, 1.6, 0.5), LINE)
		end
	end
	local c = cf * CFrame.new((ctx.hash(i, j, 3) - 0.5) * 2, 0, -1.2)
	Kit.cylinder(m, at(c, 0, 0, 0), at(c, 0, 1.8, 0), 0.2, LINE)
	Kit.box(m, c * CFrame.new(0, 1.9, 0), Vector3.new(1.9, 0.3, 1.9), LINE)
	Kit.box(m, c * CFrame.new(0, 3.2, -0.9), Vector3.new(1.8, 2.0, 0.2), LINE)
	solid(m, cf * CFrame.new(0, 0, 2.2), Vector3.new(7.6, 4.2, 2.8))
	PM.dress(m, "Parking.CctvDesk", cf) -- (소품 좌표: 벽 앞 바닥, -Z = 방 안쪽)
end

-- t 전기차 충전기: 기둥 + 화면 + 늘어진 케이블 + 바닥 보호대
function P.EvCharger(ctx: any, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "EvCharger")
	Kit.box(m, cf * CFrame.new(0, 2.8, 2.6), Vector3.new(2.2, 5.6, 1.4))
	Kit.box(m, cf * CFrame.new(0, 4.4, 1.86), Vector3.new(1.4, 1.0, 0.08), LINE)
	Kit.box(m, cf * CFrame.new(0, 5.9, 2.4), Vector3.new(2.6, 0.5, 1.9), LINE)
	Kit.cylinder(m, at(cf, 1.2, 3.6, 2.4), at(cf, 1.9, 1.2, 1.6), 0.12, LINE)
	Kit.cylinder(m, at(cf, 1.9, 1.2, 1.6), at(cf, 1.3, 2.6, 1.4), 0.12, LINE)
	for _, x in { -2.2, 2.2 } do
		Kit.cylinder(m, at(cf, x, 0, 0.4), at(cf, x, 2.6, 0.4), 0.3, SOFT)
	end
	solid(m, cf * CFrame.new(0, 0, 1.8), Vector3.new(4.8, 4, 3.2))
	PM.dress(m, "Parking.EvCharger", cf)
end

-- N(위층)·q(지하 2층) 천장 안내 표지: 매단 판 + 화살표 + EXIT
function P.HangSign(ctx: any, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "HangSign")
	local top = roomH(ctx, i, j)
	local y = math.min(top - 2.2, 11)
	local axis = if ctx.hash(i, j, 2) < 0.5 then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
	local cf = CFrame.lookAt(p, p + axis)
	Kit.box(m, cf * CFrame.new(0, y, 0), Vector3.new(6.4, 1.8, 0.3), LINE)
	for _, x in { -2.4, 2.4 } do
		Kit.cylinder(m, at(cf, x, y + 0.9, 0), at(cf, x, top, 0), 0.07, LINE)
	end
	-- 앞면(로컬 -Z)에서 보면 오른쪽은 -RightVector 다
	Kit.word(m, "EXIT", at(cf, 0.9, y, -0.16), -cf.RightVector, cf.LookVector, 0.9)
	-- 화살표
	Kit.box(m, cf * CFrame.new(-2.2, y, -0.2), Vector3.new(1.2, 0.18, 0.1), LINE)
	for _, s in { -1, 1 } do
		Kit.box(m, cf * CFrame.new(-2.6, y + s * 0.2, -0.2) * CFrame.Angles(0, 0, s * 0.8), Vector3.new(0.6, 0.18, 0.1), LINE)
	end
	PM.dress(m, if top < 12 then "Parking.HangSign11" else "Parking.HangSign", cf) -- (천장 11 / 14: 매단 높이가 달라 두 가지)
end

-- j(위층)·a(지하 2층) 제트 팬: 천장에 매단 긴 원통 + 걸쇠
function P.JetFan(ctx: any, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "JetFan")
	local y = roomH(ctx, i, j) - 2.0
	local ax = Vector3.new(1, 0, 0)
	Kit.cylinder(m, p - ax * 3.4 + Vector3.new(0, y, 0), p + ax * 3.4 + Vector3.new(0, y, 0), 1.1, LINE)
	for _, s in { -1, 1 } do
		Kit.cylinder(m, p + ax * (s * 2.4) + Vector3.new(0, y, 0), p + ax * (s * 3.6) + Vector3.new(0, y, 0), 1.3, LINE)
		Kit.box(m, CFrame.new(p + ax * (s * 1.6) + Vector3.new(0, y + 1.5, 0)), Vector3.new(0.2, 1.0, 2.4), LINE)
	end
	PM.dress(m, "Parking.JetFan", CFrame.new(p + Vector3.new(0, y, 0))) -- (소품 좌표: 팬 축 가운데, 천장 = +2.0)
end

-- d 환기 덕트: 천장의 네모 덕트 + 이음 띠 + 아래로 열린 취출구
function P.Duct(ctx: any, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "Duct")
	local y = roomH(ctx, i, j) - 1.8
	local T = ctx.T
	Kit.box(m, CFrame.new(p + Vector3.new(0, y, 0)), Vector3.new(T * 3, 1.8, 3.0), LINE)
	for k = -1, 1 do
		Kit.box(m, CFrame.new(p + Vector3.new(k * T, y, 0)), Vector3.new(0.4, 2.1, 3.3), LINE)
	end
	Kit.box(m, CFrame.new(p + Vector3.new(0, y - 1.2, 0)), Vector3.new(2.6, 0.6, 2.2), LINE)
	PM.dress(m, "Parking.Duct", CFrame.new(p + Vector3.new(0, y, 0))) -- (소품 좌표: 덕트 가운데, 천장 = +1.8)
end

-- i 라바콘 셋(걸어서 지나간다)
function P.Cone(ctx: any, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "Cones")
	for k = 0, 2 do
		local c = p + Vector3.new((k - 1) * 2.3, 0, (ctx.hash(i, j, 4 + k) - 0.5) * 2)
		Kit.box(m, CFrame.new(c + Vector3.new(0, 0.1, 0)), Vector3.new(1.4, 0.2, 1.4), LINE)
		for n = 0, 2 do
			Kit.cylinder(m, c + Vector3.new(0, 0.2 + n * 0.7, 0), c + Vector3.new(0, 0.9 + n * 0.7, 0), 0.5 - n * 0.16, LINE)
		end
	end
	PM.dress(m, "Parking.Cone", CFrame.new(p))
end

-- w 과속 방지턱(차로를 가로지른다, 세로로 이어짐)
function P.SpeedBump(ctx: any, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "SpeedBump")
	local T = ctx.T
	Kit.box(m, CFrame.new(p + Vector3.new(0, 0.18, 0)), Vector3.new(1.8, 0.36, T), LINE)
	for _, s in { -1, 1 } do
		Kit.box(m, CFrame.new(p + Vector3.new(s * 1.4, 0.1, 0)) * CFrame.Angles(0, 0, -s * 0.22), Vector3.new(1.3, 0.1, T), LINE)
	end
	Kit.box(m, CFrame.new(p + Vector3.new(3.2, 0.04, 0)), Vector3.new(0.35, 0.08, T - 2), LINE)
	PM.dress(m, "Parking.SpeedBump", CFrame.new(p))
end

-- G 비상 발전기: 엔진 덩어리 + 방열판 + 배기관 + 축전지
function P.Generator(ctx: any, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "Generator")
	local cf = CFrame.new(p)
	Kit.box(m, cf * CFrame.new(0, 0.4, 0), Vector3.new(7.4, 0.8, 4.2), SOFT)
	Kit.box(m, cf * CFrame.new(-0.8, 2.5, 0), Vector3.new(4.4, 3.4, 3.2))
	Kit.box(m, cf * CFrame.new(2.7, 2.6, 0), Vector3.new(0.8, 3.8, 3.8), SOFT) -- 방열판
	for k = -2, 2 do
		Kit.box(m, cf * CFrame.new(3.15, 2.6 + k * 0.7, 0), Vector3.new(0.08, 0.12, 3.6), LINE)
	end
	Kit.cylinder(m, at(cf, -2.6, 2.4, 0), at(cf, -3.6, 2.4, 0), 1.3, SOFT) -- 발전 코일
	Kit.cylinder(m, at(cf, 0.2, 4.2, 0), at(cf, 0.2, roomH(ctx, i, j), 0), 0.5, SOFT) -- 배기관
	Kit.cylinder(m, at(cf, 0.2, 5.6, 0), at(cf, 0.2, 8.2, 0), 0.95, LINE) -- 소음통
	Kit.box(m, cf * CFrame.new(-0.8, 1.2, 2.2), Vector3.new(2.4, 1.2, 0.9), LINE) -- 축전지
	solid(m, cf, Vector3.new(7.4, 4.4, 4.2))
	PM.dress(m, if ctx.H < 12 then "Parking.Generator11" else "Parking.Generator", cf)
end

-- R 배전반: 벽에 붙은 키 큰 철제 함 + 문 두 짝 + 계기 + 천장 전선관
function P.Switchgear(ctx: any, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "Switchgear")
	Kit.box(m, cf * CFrame.new(0, 4.2, 2.6), Vector3.new(7.6, 8.4, 2.4))
	Kit.box(m, cf * CFrame.new(0, 4.2, 1.36), Vector3.new(0.12, 7.8, 0.08), LINE)
	for _, x in { -1.9, 1.9 } do
		Kit.box(m, cf * CFrame.new(x, 6.6, 1.36), Vector3.new(2.0, 1.2, 0.1), LINE) -- 계기창
		Kit.box(m, cf * CFrame.new(x * 0.35, 4.0, 1.3), Vector3.new(0.25, 1.4, 0.25), LINE) -- 손잡이
		for k = 0, 2 do
			Kit.box(m, cf * CFrame.new(x, 1.0 + k * 0.5, 1.36), Vector3.new(2.4, 0.12, 0.08), LINE) -- 통풍 살
		end
		Kit.cylinder(m, at(cf, x, 8.4, 2.8), at(cf, x, ctx.H, 2.8), 0.4, LINE)
	end
	solid(m, cf * CFrame.new(0, 0, 2.6), Vector3.new(7.6, 8.4, 2.6))
	PM.dress(m, if ctx.H < 12 then "Parking.Switchgear11" else "Parking.Switchgear", cf)
end

-- P 소화 펌프: 받침 + 모터 원통 + 펌프 몸통 + 위로 오르는 굵은 배관 + 밸브 바퀴
function P.FirePump(ctx: any, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "FirePump")
	local cf = CFrame.lookAt(p, p + Vector3.new(1, 0, 0))
	Kit.box(m, cf * CFrame.new(0, 0.5, 0), Vector3.new(3.0, 1.0, 6.0), SOFT)
	Kit.cylinder(m, at(cf, 0, 2.0, 2.6), at(cf, 0, 2.0, 0.2), 1.1)
	Kit.cylinder(m, at(cf, 0, 2.0, 0.2), at(cf, 0, 2.0, -0.6), 0.4, LINE)
	Kit.cylinder(m, at(cf, -0.8, 2.0, -1.6), at(cf, 0.8, 2.0, -1.6), 1.4, SOFT)
	Kit.cylinder(m, at(cf, 0, 3.2, -1.6), at(cf, 0, roomH(ctx, i, j), -1.6), 0.6, SOFT)
	Kit.cylinder(m, at(cf, 0, 6.0, -1.6), at(cf, 0, 6.3, -1.6), 1.0, LINE)
	Kit.cylinder(m, at(cf, 0, 5.0, -1.6), at(cf, 1.6, 5.0, -1.6), 0.15, LINE)
	Kit.cylinder(m, at(cf, 1.6, 5.0, -1.6), at(cf, 1.75, 5.0, -1.6), 0.9, LINE)
	solid(m, cf, Vector3.new(3.2, 4, 6))
	PM.dress(m, if ctx.H < 12 then "Parking.FirePump11" else "Parking.FirePump", cf)
end

-- H 저수조: 칸을 채우는 큰 패널 탱크(가로세로 이음 선 + 사다리)
function P.WaterTank(ctx: any, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "WaterTank")
	local cf = CFrame.new(p)
	local w, h = 7.2, 8.0
	Kit.box(m, cf * CFrame.new(0, h / 2 + 0.6, 0), Vector3.new(w, h, w))
	for _, y in { 0.6, 3.3, 5.9, 8.6 } do
		Kit.box(m, cf * CFrame.new(0, y, 0), Vector3.new(w + 0.2, 0.18, w + 0.2), LINE)
	end
	for _, x in { -1.8, 1.8 } do
		Kit.box(m, cf * CFrame.new(x, h / 2 + 0.6, 0), Vector3.new(0.18, h, w + 0.2), LINE)
	end
	for _, x in { -0.6, 0.6 } do -- 사다리(북쪽 면)
		Kit.cylinder(m, at(cf, x, 0, -w / 2 - 0.3), at(cf, x, h + 1.4, -w / 2 - 0.3), 0.08, LINE)
	end
	for k = 1, 6 do
		Kit.cylinder(m, at(cf, -0.6, k * 1.3, -w / 2 - 0.3), at(cf, 0.6, k * 1.3, -w / 2 - 0.3), 0.06, LINE)
	end
	PM.dress(m, "Parking.WaterTank", cf)
end

-- V 급배기 팬 유닛: 네모 함 + 둥근 팬 구멍 + 날개 + 천장 덕트
function P.FanUnit(ctx: any, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "FanUnit")
	Kit.box(m, cf * CFrame.new(0, 3.2, 1.2), Vector3.new(6.8, 6.4, 5.0))
	Kit.cylinder(m, at(cf, 0, 3.2, -1.3), at(cf, 0, 3.2, -1.7), 2.6, LINE)
	Kit.cylinder(m, at(cf, 0, 3.2, -1.7), at(cf, 0, 3.2, -1.9), 0.6, LINE)
	for k = 0, 3 do
		Kit.box(m, cf * CFrame.new(0, 3.2, -1.8) * CFrame.Angles(0, 0, k * math.pi / 4 + 0.2), Vector3.new(0.5, 4.8, 0.12), LINE)
	end
	Kit.box(m, cf * CFrame.new(0, (6.4 + ctx.H) / 2, 1.6), Vector3.new(3.4, ctx.H - 6.4, 3.0), SOFT)
	solid(m, cf * CFrame.new(0, 0, 1.2), Vector3.new(6.8, 6.6, 5.2))
	PM.dress(m, if ctx.H < 12 then "Parking.FanUnit11" else "Parking.FanUnit", cf)
end

-- U 탑차(세로 두 칸): 위쪽 칸 = 운전석, 아래쪽 칸 = 짐칸. 뒷문이 반쯤 열려 있다
function P.Truck(ctx: any, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "Truck")
	local cf = CFrame.new(p)
	local T = ctx.T
	for _, x in { -2.6, 2.6 } do
		for _, z in { -1.8, 1.8 } do
			Kit.cylinder(m, at(cf, x - 0.4, 1.2, z), at(cf, x + 0.4, 1.2, z), 1.2, LINE)
		end
	end
	if ctx.at(i, j - 1) == "U" then
		-- 짐칸
		Kit.box(m, cf * CFrame.new(0, 6.0, -0.4), Vector3.new(6.6, 7.6, T - 1.0))
		Kit.box(m, cf * CFrame.new(0, 1.9, -0.4), Vector3.new(6.0, 0.6, T - 0.6), LINE)
		for k = -1, 1 do
			for _, s in { -1, 1 } do
				Kit.box(m, cf * CFrame.new(s * 3.35, 6.0, -0.4 + k * 2.2), Vector3.new(0.1, 7.4, 0.2), LINE)
			end
		end
		Kit.box(m, cf * CFrame.new(-3.2, 6.0, T / 2 - 0.4) * CFrame.Angles(0, -0.9, 0) * CFrame.new(1.5, 0, 0), Vector3.new(3.0, 7.2, 0.2), LINE) -- 열린 문짝
		solid(m, cf, Vector3.new(6.8, 8, T))
		PM.dress(m, "Parking.TruckBox", cf) -- (짐칸: 뒷문 = +Z)
	else
		-- 운전석
		Kit.box(m, cf * CFrame.new(0, 2.9, 0.6), Vector3.new(6.2, 2.6, 5.4))
		Kit.box(m, cf * CFrame.new(0, 5.6, 1.2), Vector3.new(6.0, 2.8, 4.2))
		Kit.box(m, cf * CFrame.new(0, 5.6, -1.0), Vector3.new(5.2, 2.0, 0.12), LINE) -- 앞유리 틀
		Kit.box(m, cf * CFrame.new(0, 1.6, -2.3), Vector3.new(6.4, 0.8, 0.4), LINE) -- 범퍼
		for _, s in { -1, 1 } do
			Kit.box(m, cf * CFrame.new(s * 2.2, 2.6, -2.2), Vector3.new(1.0, 0.6, 0.15), LINE)
			Kit.box(m, cf * CFrame.new(s * 3.6, 5.4, -1.0), Vector3.new(0.5, 1.4, 0.3), LINE) -- 거울
		end
		solid(m, cf * CFrame.new(0, 0, 0.6), Vector3.new(6.6, 7, 6.2))
		PM.dress(m, "Parking.TruckCab", cf) -- (운전석: 앞 = -Z)
	end
end

-- z 핸드 파레트 잭 + 팔레트 + 짐 하나
function P.PalletJack(ctx: any, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "PalletJack")
	local cf = CFrame.new(p) * CFrame.Angles(0, ctx.hash(i, j, 3) * 1.0 - 0.5, 0)
	for _, x in { -1.8, 0, 1.8 } do
		Kit.box(m, cf * CFrame.new(x, 0.3, -0.6), Vector3.new(0.5, 0.6, 4.4), LINE)
	end
	Kit.box(m, cf * CFrame.new(0, 0.7, -0.6), Vector3.new(4.4, 0.2, 4.4), SOFT)
	Kit.crate(m, at(cf, -0.4, 0.8, -0.8), Vector3.new(3.0, 2.4, 2.8), ctx.hash(i, j, 5))
	Kit.box(m, cf * CFrame.new(0, 0.9, 2.2), Vector3.new(2.2, 1.4, 1.0), SOFT)
	Kit.cylinder(m, at(cf, 0, 1.4, 2.4), at(cf, 0, 4.2, 3.4), 0.12, LINE)
	Kit.cylinder(m, at(cf, -0.8, 4.2, 3.4), at(cf, 0.8, 4.2, 3.4), 0.12, LINE)
	solid(m, cf * CFrame.new(0, 0, 0.2), Vector3.new(4.4, 3.2, 5.8))
	PM.dress(m, "Parking.PalletJack", cf)
end

-- Y 재활용 수거함: 바퀴 달린 큰 통 + 기울어진 뚜껑 + 넘친 봉투
function P.RecycleBin(ctx: any, i: number, j: number)
	local cf = againstWall(ctx, i, j)
	local m = model(ctx, "RecycleBin")
	Kit.box(m, cf * CFrame.new(0, 2.6, 1.4), Vector3.new(5.6, 4.0, 3.6))
	Kit.box(m, cf * CFrame.new(0, 4.9, 1.4) * CFrame.Angles(ctx.hash(i, j, 2) * 0.35, 0, 0), Vector3.new(5.9, 0.3, 3.9), LINE)
	for _, x in { -2.2, 2.2 } do
		for _, z in { 0, 2.8 } do
			Kit.cylinder(m, at(cf, x - 0.15, 0.4, z), at(cf, x + 0.15, 0.4, z), 0.4, LINE)
		end
	end
	Kit.box(m, cf * CFrame.new(0, 3.0, -0.44), Vector3.new(4.6, 0.2, 0.1), LINE)
	for k = 0, 1 do
		Kit.ball(m, at(cf, -1.4 + k * 2.6, 0.8, -1.8 + ctx.hash(i, j, 6 + k)), 0.9, LINE)
	end
	solid(m, cf * CFrame.new(0, 0, 1.2), Vector3.new(5.8, 4.8, 4.0))
	PM.dress(m, "Parking.RecycleBin", cf)
end


-- r 램프 앞 바닥 화살표(지나갈 수 있다): 가장 가까운 램프 칸(1, 지하 1층은 구멍 o) 쪽을 가리킨다 = 부품 3개
function P.RampMark(ctx: any, i: number, j: number)
	local p = base(ctx, i, j) + Vector3.new(0, 0.05, 0)
	local dir = Vector3.new(0, 0, -1)
	for r = 1, 2 do
		local found = false
		for _, d in { { 0, -1 }, { 0, 1 }, { 1, 0 }, { -1, 0 } } do
			local c = ctx.at(i + d[1] * r, j + d[2] * r)
			if c == "1" or c == "o" then
				dir = Vector3.new(d[1], 0, d[2])
				found = true
				break
			end
		end
		if found then
			break
		end
	end
	local cf = CFrame.lookAt(p, p + dir)
	Kit.box(ctx.props, cf * CFrame.new(0, 0, 0.6), Vector3.new(0.7, 0.08, 4.0), LINE)
	for _, s in { -1, 1 } do
		Kit.box(ctx.props, cf * CFrame.new(s * 0.75, 0, -1.7) * CFrame.Angles(0, s * 0.75, 0), Vector3.new(0.6, 0.08, 2.4), LINE)
	end
end

-- M 집수정: 바닥 철망 덮개(테두리 + 살 둘) + 배수 펌프 모터 + 천장으로 오르는 배관 = 부품 6개
function P.SumpPit(ctx: any, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "SumpPit")
	local cf = CFrame.new(p)
	Kit.box(m, cf * CFrame.new(0, 0.15, 0), Vector3.new(6.4, 0.3, 6.4), SOFT)
	for _, x in { -1.2, 1.2 } do
		Kit.box(m, cf * CFrame.new(x, 0.32, 0), Vector3.new(0.25, 0.1, 6.0), LINE)
	end
	Kit.cylinder(m, at(cf, 1.8, 0.3, 1.8), at(cf, 1.8, 2.6, 1.8), 0.9)
	Kit.cylinder(m, at(cf, 1.8, 2.6, 1.8), at(cf, 1.8, roomH(ctx, i, j), 1.8), 0.35, LINE)
	solid(m, cf, Vector3.new(6.4, 2.8, 6.4))
	PM.dress(m, if ctx.H < 12 then "Parking.SumpPit11" else "Parking.SumpPit", cf)
end

-- K 압력 탱크(세로 원통 + 다리 + 위로 오르는 배관) = 부품 5개
function P.PressureTank(ctx: any, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "PressureTank")
	local cf = CFrame.new(p)
	Kit.cylinder(m, at(cf, 0, 1.0, 0), at(cf, 0, 6.6, 0), 2.0)
	Kit.ball(m, at(cf, 0, 6.6, 0), 2.0, LINE)
	for _, x in { -1.4, 1.4 } do
		Kit.box(m, cf * CFrame.new(x, 0.5, 0), Vector3.new(0.3, 1.0, 3.2), LINE)
	end
	Kit.cylinder(m, at(cf, 0, 8.4, 0), at(cf, 0, roomH(ctx, i, j), 0), 0.4, LINE)
	PM.dress(m, if ctx.H < 12 then "Parking.PressureTank11" else "Parking.PressureTank", cf)
end

-- F 발전기 연료 탱크(눕힌 원통 + 받침 둘 + 주유구) = 부품 5개
function P.FuelTank(ctx: any, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "FuelTank")
	local cf = CFrame.new(p)
	Kit.cylinder(m, at(cf, 0, 2.4, -2.8), at(cf, 0, 2.4, 2.8), 1.9)
	for _, z in { -1.8, 1.8 } do
		Kit.box(m, cf * CFrame.new(0, 0.5, z), Vector3.new(3.6, 1.0, 0.5), LINE)
	end
	Kit.cylinder(m, at(cf, 0, 4.2, 1.0), at(cf, 0, 5.0, 1.0), 0.35, LINE)
	solid(m, cf, Vector3.new(4.0, 4.4, 6.0))
	PM.dress(m, "Parking.FuelTank", cf)
end

-- a 세대 창고 철망 칸(아파트 지하 창고): 네 모서리 기둥 + 위 테두리 + 철망 면(가는 살) + 맹꽁이 자물쇠 + 안쪽 짐 하나 = 부품 약 10개.
-- 칸 하나를 다 채우는 막힘 소품(줄로 세워 창고 통로를 만든다). 철망 살은 음파를 막지 않는다(blocks = false)
function P.Cage(ctx: any, i: number, j: number)
	local p = base(ctx, i, j)
	local m = model(ctx, "Cage")
	local cf = CFrame.new(p)
	local s, h = 3.6, math.min(roomH(ctx, i, j) - 1.0, 8.0)
	for _, x in { -s, s } do
		for _, z in { -s, s } do
			Kit.box(m, cf * CFrame.new(x, h / 2, z), Vector3.new(0.35, h, 0.35), SOFT)
		end
	end
	Kit.box(m, cf * CFrame.new(0, h, 0), Vector3.new(2 * s + 0.35, 0.3, 2 * s + 0.35), SOFT) -- 위 테두리
	for _, y in { h * 0.33, h * 0.66 } do -- 철망 가로 살(네 면을 한 띠로)
		Kit.box(m, cf * CFrame.new(0, y, 0), Vector3.new(2 * s + 0.1, 0.12, 2 * s + 0.1), LINE)
	end
	Kit.box(m, cf * CFrame.new(0, 3.6, -s - 0.12), Vector3.new(0.5, 0.7, 0.2), LINE) -- 자물쇠
	Kit.crate(m, p + Vector3.new((ctx.hash(i, j, 7) - 0.5) * 2, 0, (ctx.hash(i, j, 8) - 0.5) * 2), Vector3.new(3.4, 2.6 + ctx.hash(i, j, 9) * 1.6, 3.0), ctx.hash(i, j, 10))
	solid(m, cf, Vector3.new(2 * s + 0.35, h, 2 * s + 0.35))
	PM.dress(m, "Parking.Cage", cf)
end

return P
