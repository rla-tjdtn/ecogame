--!strict
-- STAGE 9 — 지하 주차장 (47x43칸, tools/gen-stage9.js 로 생성)
-- 지하 1층 북쪽: 엘리베이터 홀(시작)·관리 사무소(사물함 L)·넓은 주차 구역(차 Q, 빈 칸 l, 굵은 기둥 B, 칸막이 아치).
-- 동쪽 3칸 폭 램프와 비상계단(s)으로 지하 2층(구덩이 높이: 차 K, 빈 칸 y, 기둥 X, 서쪽 끝 좁은 배관 통로)으로 내려가고,
-- 서쪽 램프·비상계단으로 다시 지하 1층 남쪽(기계실·전기실·셔터 내린 하역장 x·꺾인 배관 통로·정산소 J)으로 올라온다.
-- 출구(E)는 차단기(g)가 달린 차량 출구 게이트(게이트 기둥이 짧아 정산 구역 어느 쪽에서든 다가간다: 한 줄 차로 목이 없다). 숨는 곳(L)은 관리실 사물함, 뒤지는 곳(Z)은 공구함.
-- 줄지어 선 차와 기둥이 시야·음파를 끊고, 주차 줄 사이 틈과 칸막이 아치로 돌아가는 고리가 여러 개다.
-- 맞댄 주차 줄마다 한 줄은 굵은 콘크리트 벽 기둥(#)이라 넓은 주차 구역이 음파 크기(가장 넓은 정사각형 8)로 끊기고,
-- 하역장 가운데엔 콘크리트 하역 플랫폼과 벽 기둥 4개. 지하 2층에서 올라오는 길은 두 갈래: 서쪽 램프(→ 착지 통로·기계실 쪽)와
-- 하역장으로 바로 올라오는 비상계단. 막다른 곳: 서쪽 배관 통로, 관리 사무소, 기계실·전기실, 꺾인 배관 통로 끝. 출구까지 최단 약 137칸.
local Props = require(script.Parent.Parent.Props)

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
local function car(ctx: any, i: number, j: number)
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
local function emptyStall(ctx: any, i: number, j: number)
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
local function pillar(ctx: any, i: number, j: number)
	local Kit = ctx.Kit
	local p = base(ctx, i, j)
	local h = ctx.H - ctx.floorY(i, j)
	Kit.box(ctx.geo, CFrame.new(p + Vector3.new(0, h / 2, 0)), Vector3.new(4.0, h, 4.0), { name = "Pillar" })
	Kit.box(ctx.geo, CFrame.new(p + Vector3.new(0, 0.5, 0)), Vector3.new(4.8, 1.0, 4.8), { name = "PillarBase" })
	Kit.box(ctx.geo, CFrame.new(p + Vector3.new(0, h - 0.8, 0)), Vector3.new(5.0, 1.6, 5.0), { name = "PillarCap" })
	local label = string.format("%02d", (j * 47 + i) % 97) -- 칸 위치로 정해지는 번호(다시 지어도 같다)
	for _, f in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local right = Vector3.new(f.Z, 0, -f.X) -- 번호판을 마주 본 사람의 오른쪽
		local face = p + f * 2.05 + Vector3.new(0, 6.0, 0)
		Kit.box(ctx.props, CFrame.lookAt(face, face + f), Vector3.new(2.8, 1.9, 0.1), { blocks = false, collide = false })
		local dh = 1.2
		for n = 1, 2 do
			local o = face + Vector3.new(0, -dh / 2, 0) + right * ((n - 1.5) * dh * 0.95 - dh * 0.27) + f * 0.05
			digit(ctx, label:sub(n, n), o, right, f, dh)
		end
		-- 모서리 보호대(아래쪽 띠 두 줄)
		for _, y in { 1.6, 2.6 } do
			Kit.box(ctx.props, CFrame.lookAt(p + f * 2.05 + Vector3.new(0, y, 0), p + f * 3 + Vector3.new(0, y, 0)), Vector3.new(4.0, 0.3, 0.1), { blocks = false, collide = false })
		end
	end
end

-- 손수레(카트): 벽 쪽으로 붙여 둔다
local function cart(ctx: any, i: number, j: number)
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
local function hydrant(ctx: any, i: number, j: number)
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
local function elevator(ctx: any, i: number, j: number)
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
local function shutter(ctx: any, i: number, j: number)
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
local function barrier(ctx: any, i: number, j: number)
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
local function payMachine(ctx: any, i: number, j: number)
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
local function ramp(ctx: any, i: number, j: number)
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

return {
	Seed = 91,
	PipeChance = 0.3,
	HideStyle = "locker", -- 숨는 곳(L): 관리 사무소·기계실 철제 사물함
	SearchStyle = "toolbox", -- 뒤지는 곳(Z): 공구함, 그중 한 곳에 열쇠
	Props = { Q = car, K = car, l = emptyStall, y = emptyStall, B = pillar, X = pillar, u = cart, h = hydrant, e = elevator, x = shutter, g = barrier, J = payMachine, s = ramp, T = Props.Desk, k = Props.Cabinet },
	PitTiles = { K = true, X = true, y = true },
	Walkable = { l = true, y = true, u = true, h = true, e = true, x = true, g = true, k = true, K = false, X = false },
	Rows = {
		"###############################################",
		"#.e.e.e..#.lQQQBQlllBQQQQBQ#QQQBQQQlBQQQQBQQQ.#",
		"#.SS.....#.................A..................#",
		"#........D................u#..................#",
		"#L.......#..#lQQ#Q.Q#QQl#l.#.#QlQ#lQ.#lQQ#ll..#",
		"#.......h#..BQQQBl.lBQQlBl.#.BQQQBQQ.BlllBlQ..#",
		"#####D####h................#.................h#",
		"#...Z...k#.................A..................#",
		"#L......k#..QQ.QQlBQlQ.QQQ.#.QlB.lQBQQQB.QQB..#",
		"#..T..T..#..QQ.QlQ#QQQ.QQQ.#.QQ#.Ql#QlQ#.QQ#..#",
		"#L.......D.................#u.................#",
		"#........#.................A.................Z#",
		"#L..L.Z.L#ZlQBlQQQBlQQlBQQl#llBlQQlBQQlQ...l..#",
		"########################################sss#s##",
		"#pyXKKKKXyKKKXyKKKXKKKyp#ppppppppppppppppppppp#",
		"#p#ppppppppppppppppppppppppppppppppppppppppppp#",
		"#p#ppppppppppppppppppppp#ppppppppppppppppppppp#",
		"#p#KKK#yKp#KKK#ypK#KKK#p#pKKK#KpK#KKK#pKK#KKpp#",
		"#p#KKKXKKpXyyKXKpKXKKKXp#pKKKXKpKXKyKXpyKXyKpp#",
		"#p#ppppppppppppppppppppp#ppppppppppppppppppppp#",
		"#p#ppppppppppppppppppppppppppppppppppppppppppp#",
		"#p#ppppppppppppppppppppppppppppppppppppppppppp#",
		"#p#KXKpKXKKKXpKKXyKpXKKp#pyXKpyXKKypKKyXKpKXpp#",
		"#p#K#KpK#KKK#pKK#KKp#Kyp#py#KpK#KKypKKK#KpK#pp#",
		"#p#ppppppppppppppppppppp#ppppppppppppppppppppp#",
		"#p#ppppppppppppppppppppp#ppppppppppppppppppppp#",
		"#ppppppppppppppppppppppppppppppppppppppppppppp#",
		"#ppppKKXKKyypKKyKXKKKKXp#pyKKXyyyyXKyKyXKKyKXp#",
		"##sss#######s##################################",
		"#..........A...h..........L########.......L...#",
		"#..........#....u..........########.#####....h#",
		"#####D######...............D..#####.#J.Z#.....#",
		"#..........#...#.......#...##f#####.#...#..B..#",
		"#.m..m..m..#..............c##...###.##D##.....#",
		"#..........#.c...#####.....####.###u..........#",
		"#.v........#....c#####c...L####f###.........###",
		"#Z....f...L#.....#####.....####...#.........gE#",
		"####D#######.c.............######.#.........###",
		"#..........#...#.......#..c######.....B.......#",
		"#k........k#...............########...........#",
		"#k........kD............u..D..............Q.Q.#",
		"#..L..m.Z..#Z.x.Zx..x..x...########.Z.........#",
		"###############################################",
	},
}
