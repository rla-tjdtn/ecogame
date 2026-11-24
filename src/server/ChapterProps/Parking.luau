--!nonstrict
-- 챕터 9 지하 주차장 전용 소품(타일 문자 → 함수). Stage9.luau 의 Props 줄에서 쓴다. MapKit 부품만(검은 무광, 음파 윤곽선).
--   Q/K 주차된 차  l/y 빈 주차 칸  B/X 굵은 기둥(번호판)  s 차량 램프(옆으로 이어진 계단을 경사판으로)  e 엘리베이터 문  J 정산기  g 차단기
--   h 소화전  u 카트  x 셔터  C CCTV 콘솔(방재실)  t 전기차 충전기  N/q 천장 안내 표지  j/a 제트 팬  d 환기 덕트  i 라바콘  w 과속 방지턱
--   G 비상 발전기  R 배전반  P 소화 펌프  H 저수조  V 급배기 팬  U 탑차(세로 두 칸)  z 파레트 잭  Y 재활용 수거함

local Kit = require(script.Parent.Parent.MapKit)

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

local STALL = { Q = true, K = true, l = true, y = true }

-- 주차 칸 바닥선: 칸 양옆(x 방향 경계) 흰 선 + 앞쪽 끝선 대신 바퀴 멈춤턱
local function stallLines(ctx: any, i: number, j: number, p: Vector3)
	local Kit = ctx.Kit
	local T = ctx.T
	for _, s in { -1, 1 } do
		-- 오른쪽 경계는 옆 칸이 주차 칸이 아닐 때만(겹치지 않게)
		if s == -1 or not STALL[ctx.at(i + 1, j)] then
			Kit.box(ctx.props, CFrame.new(p + Vector3.new(s * (T / 2 - 0.15), 0.04, 0)), Vector3.new(0.25, 0.08, T - 1), { blocks = false, collide = false })
		end
	end
	local back = if ctx.isWall(i, j - 1) then -1 elseif ctx.isWall(i, j + 1) then 1 else 0
	if back ~= 0 then
		local st = p + Vector3.new(0, 0.25, back * (T / 2 - 1.2))
		for _, s in { -1, 1 } do
			Kit.box(ctx.props, CFrame.new(st + Vector3.new(s * 1.5, 0, 0)), Vector3.new(1.8, 0.5, 0.6), { blocks = false, collide = false })
		end
	end
end

-- 주차된 차(큰 상자형): 바퀴 4개 + 차체 + 객실 + 범퍼·창틀 선
function P.Car(ctx: any, i: number, j: number)
	local Kit = ctx.Kit
	local p = base(ctx, i, j)
	stallLines(ctx, i, j, p)
	local nose = if ctx.hash(i, j, 91) < 0.5 then 1 else -1
	local yaw = (ctx.hash(i, j, 92) - 0.5) * 0.12
	local cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
	local m = Instance.new("Model")
	m.Name = "Car"
	m.Parent = ctx.props
	for _, x in { -2.3, 2.3 } do
		for _, z in { -2.5, 2.5 } do
			local w = cf * CFrame.new(x, 1.05, z)
			Kit.cylinder(m, (w * CFrame.new(-0.35, 0, 0)).Position, (w * CFrame.new(0.35, 0, 0)).Position, 1.05, { blocks = false, collide = false })
		end
	end
	Kit.box(m, cf * CFrame.new(0, 2.0, 0), Vector3.new(4.8, 1.9, 7.4), { name = "CarBody" })
	Kit.box(m, cf * CFrame.new(0, 3.75, -nose * 0.5), Vector3.new(4.2, 1.6, 3.8), { name = "CarCabin" })
	-- 앞·뒤 유리 경사(쐐기)
	Kit.wedge(m, cf * CFrame.new(0, 3.75, nose * 1.95) * CFrame.Angles(0, if nose == 1 then 0 else math.pi, 0), Vector3.new(4.2, 1.6, 0.8), { blocks = false, collide = false })
	-- 창틀 가운데 기둥, 범퍼, 전조등
	for _, s in { -1, 1 } do
		Kit.box(m, cf * CFrame.new(s * 2.12, 3.75, -nose * 0.5), Vector3.new(0.08, 1.4, 0.25), { blocks = false, collide = false })
		Kit.box(m, cf * CFrame.new(0, 1.3, s * 3.78), Vector3.new(5.0, 0.5, 0.25), { blocks = false, collide = false })
		Kit.box(m, cf * CFrame.new(s * 1.6, 2.3, nose * 3.72), Vector3.new(0.9, 0.4, 0.12), { blocks = false, collide = false })
	end
	Kit.box(m, cf * CFrame.new(0, 2.4, 0), Vector3.new(5.0, 4.6, 7.6), { invisible = true, tag = false })
end

-- 빈 주차 칸(바닥선만)
function P.EmptyStall(ctx: any, i: number, j: number)
	stallLines(ctx, i, j, base(ctx, i, j))
end

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
function P.Pillar(ctx: any, i: number, j: number)
	local Kit = ctx.Kit
	local p = base(ctx, i, j)
	local h = ctx.H - ctx.floorY(i, j)
	Kit.box(ctx.geo, CFrame.new(p + Vector3.new(0, h / 2, 0)), Vector3.new(4.0, h, 4.0), { name = "Pillar" })
	Kit.box(ctx.geo, CFrame.new(p + Vector3.new(0, 0.5, 0)), Vector3.new(4.8, 1.0, 4.8), { name = "PillarBase" })
	Kit.box(ctx.geo, CFrame.new(p + Vector3.new(0, h - 0.8, 0)), Vector3.new(5.0, 1.6, 5.0), { name = "PillarCap" })
	local label = string.format("%02d", (j * 47 + i) % 97) -- 칸 위치로 정해지는 번호(다시 지어도 같다)
	-- 번호판은 마주 보는 두 면에만(부품·선을 줄인다)
	for _, f in { Vector3.xAxis, -Vector3.xAxis } do
		local right = Vector3.new(f.Z, 0, -f.X) -- 번호판을 마주 본 사람의 오른쪽
		local face = p + f * 2.05 + Vector3.new(0, 6.0, 0)
		Kit.box(ctx.props, CFrame.lookAt(face, face + f), Vector3.new(2.8, 1.9, 0.1), { blocks = false, collide = false })
		local dh = 1.2
		for n = 1, 2 do
			local o = face + Vector3.new(0, -dh / 2, 0) + right * ((n - 1.5) * dh * 0.95 - dh * 0.27) + f * 0.05
			digit(ctx, label:sub(n, n), o, right, f, dh)
		end
	end
	-- 모서리 보호대: 기둥을 두르는 띠 두 줄
	for _, y in { 1.6, 2.6 } do
		Kit.box(ctx.props, CFrame.new(p + Vector3.new(0, y, 0)), Vector3.new(4.2, 0.3, 4.2), { blocks = false, collide = false })
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
end

-- 소화전: 벽에 붙은 소화전함 + 바닥 소화전
function P.Hydrant(ctx: any, i: number, j: number)
	local Kit = ctx.Kit
	local side = wallDir(ctx, i, j) or Vector3.new(0, 0, -1)
	local p = base(ctx, i, j)
	local face = p + side * (ctx.T / 2 - 0.4)
	Kit.box(ctx.props, CFrame.lookAt(face + Vector3.new(0, 4.2, 0), face + Vector3.new(0, 4.2, 0) - side), Vector3.new(2.8, 3.4, 0.8), { blocks = false })
	Kit.box(ctx.props, CFrame.lookAt(face + Vector3.new(0, 4.2, 0) - side * 0.42, face + Vector3.new(0, 4.2, 0) - side), Vector3.new(2.2, 2.8, 0.05), { blocks = false, collide = false })
	local post = face - side * 0.9 + Vector3.new(side.Z, 0, -side.X) * 2.2
	Kit.cylinder(ctx.props, post, post + Vector3.new(0, 2.2, 0), 0.4, { blocks = false })
	Kit.ball(ctx.props, post + Vector3.new(0, 2.3, 0), 0.42, { blocks = false, collide = false })
	Kit.cylinder(ctx.props, post + Vector3.new(0, 1.5, 0) - Vector3.new(side.Z, 0, -side.X) * 0.7, post + Vector3.new(0, 1.5, 0) + Vector3.new(side.Z, 0, -side.X) * 0.7, 0.18, { blocks = false, collide = false })
end

-- 엘리베이터 문(벽면): 문틀 + 두 짝 + 호출 버튼
function P.Elevator(ctx: any, i: number, j: number)
	local Kit = ctx.Kit
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
end

-- 셔터(하역장 벽면): 말린 셔터 통 + 가로 살
function P.Shutter(ctx: any, i: number, j: number)
	local Kit = ctx.Kit
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
end

-- 차량 출구 차단기: 벽 쪽 기둥 + 위로 들린 막대
function P.Barrier(ctx: any, i: number, j: number)
	local Kit = ctx.Kit
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
end

-- 주차 정산기(벽에 붙은 키오스크)
function P.PayMachine(ctx: any, i: number, j: number)
	local Kit = ctx.Kit
	local side = wallDir(ctx, i, j) or Vector3.new(0, 0, -1)
	local p = base(ctx, i, j) + side * (ctx.T / 2 - 1.1)
	Kit.box(ctx.props, CFrame.lookAt(p + Vector3.new(0, 2.6, 0), p + Vector3.new(0, 2.6, 0) - side), Vector3.new(2.6, 5.2, 1.8), { name = "PayMachine" })
	local f = p - side * 0.92
	Kit.box(ctx.props, CFrame.lookAt(f + Vector3.new(0, 3.9, 0), f + Vector3.new(0, 3.9, 0) - side), Vector3.new(1.8, 1.2, 0.06), { blocks = false, collide = false })
	Kit.box(ctx.props, CFrame.lookAt(f + Vector3.new(0, 2.6, 0), f + Vector3.new(0, 2.6, 0) - side), Vector3.new(1.0, 0.2, 0.15), { blocks = false, collide = false })
	Kit.box(ctx.props, CFrame.lookAt(f + Vector3.new(0, 1.3, 0), f + Vector3.new(0, 1.3, 0) - side), Vector3.new(1.6, 0.5, 0.2), { blocks = false, collide = false })
end

-- 램프: 계단(s)이 옆으로 이어진 넓은 곳은 매끈한 경사판 + 가장자리 연석으로 덮는다(비상계단은 계단 그대로)
function P.Ramp(ctx: any, i: number, j: number)
	local wide = ctx.at(i - 1, j) == "s" or ctx.at(i + 1, j) == "s" or ctx.at(i, j - 1) == "s" or ctx.at(i, j + 1) == "s"
	if not wide then
		return
	end
	local Kit = ctx.Kit
	local up = Vector3.new(0, 0, -1)
	for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local n = ctx.at(i + d[1], j + d[2])
		if n ~= "#" and not ctx.isPit(i + d[1], j + d[2]) then
			up = Vector3.new(d[1], 0, d[2])
		end
	end
	local c = ctx.center(i, j)
	local rise = -ctx.PIT_Y
	-- 경사선이 계단 코보다 조금 위로 오도록 아래쪽으로 1.1 밀어 둔다
	local mid = c - up * 1.1 + Vector3.new(0, ctx.PIT_Y + rise / 2, 0)
	Kit.wedge(ctx.props, CFrame.lookAt(mid, mid - up), Vector3.new(ctx.T, rise, ctx.T), { name = "Ramp" })
	local across = Vector3.new(up.Z, 0, -up.X)
	for _, s in { -1, 1 } do
		if ctx.isWall(i + math.round(across.X * s), j + math.round(across.Z * s)) then
			local a = c + across * s * (ctx.T / 2 - 0.4) - up * (ctx.T / 2) + Vector3.new(0, ctx.PIT_Y + 0.5, 0)
			local b = a + up * ctx.T + Vector3.new(0, rise, 0)
			local d = b - a
			Kit.box(ctx.props, CFrame.lookAt((a + b) / 2, b), Vector3.new(0.6, 1.0, d.Magnitude), { blocks = false, collide = false })
		end
	end
end

-- ── 새 장비 ──
local LINE = { blocks = false, collide = false }
local SOFT = { blocks = false }

local function model(ctx: any, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = ctx.props
	return m
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
end

return P
