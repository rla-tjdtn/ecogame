--!strict
-- STAGE 3 — 하수도 (47x43칸, tools/places/sewer.js 로 생성)
-- 벽돌 아치 터널(보행로 / 수로 w / 보행로, 갈비 아치)이 맵 바깥을 크게 돌고, 가운데 원형 저수조(물웅덩이·기둥)가 갈림목이다.
-- 수로는 6스터드 낮은 물길: 철제 다리(b)로만 반대편 보행로로 건넌다.
-- 위 띠: 정비 출입구(시작)·공구 창고·펌프실(문 2개)·밸브실·관리 사무실(문 2개). 가운데: 정비 작업장 → 1칸 정비 샛길 → 저수조,
-- 배수 제어실(위 터널 ↔ 동쪽 터널)·침전조(문 2개)·침사지. 아래 띠: 공구 창고·오수 펌프장(문 2개)·저장고·배수 점검실.
-- 살짝 뒤틀린 곳: 위 터널과 아래 터널 가운데가 무너져 펌프실·오수 펌프장으로 돌아가고, 서쪽 터널은 중간이 무너져 막혔다.
-- 저수조로는 세 갈래(작업장 샛길, 가운데 터널, 배수 제어실), 동쪽은 터널 또는 침전조로 갈린다. 서쪽 터널 끝은 수문이 닫혀
-- 수문실을 지나야 배수구(출구)에 닿는다. 출구까지 최단 약 147칸.
local Props = require(script.Parent.Parent.Props)

-- 수로 칸: 물 + 터널 천장의 아치 갈비(양쪽 벽에서 솟아 수로 위에서 만난다). 모퉁이에서는 갈비를 생략
local function sewerWater(ctx, i: number, j: number)
	Props.Water(ctx, i, j)
	local Kit = ctx.Kit
	local across: Vector3? = nil
	if not ctx.isWall(i - 1, j) and not ctx.isWall(i + 1, j) and ctx.isWall(i - 2, j) and ctx.isWall(i + 2, j) then
		across = Vector3.new(1, 0, 0)
	elseif not ctx.isWall(i, j - 1) and not ctx.isWall(i, j + 1) and ctx.isWall(i, j - 2) and ctx.isWall(i, j + 2) then
		across = Vector3.new(0, 0, 1)
	end
	if not across then
		return
	end
	local c = ctx.center(i, j)
	local half = ctx.T * 1.5 - 0.3
	local prev: Vector3? = nil
	local N = 9
	for k = 0, N do
		local a = math.pi * k / N
		local p = c + across * (half * math.cos(a)) + Vector3.new(0, 5.2 + 8.2 * math.sin(a), 0)
		if prev then
			local mid = (prev + p) / 2
			Kit.box(ctx.props, CFrame.lookAt(mid, p), Vector3.new(0.8, 0.6, (p - prev).Magnitude + 0.15), { collide = false, blocks = false })
		end
		prev = p
	end
	-- 수로 가장자리 돌 턱(보행로 끝선)
	for _, s in { -1, 1 } do
		local e = c + across * (s * (ctx.T / 2 - 0.2)) + Vector3.new(0, -0.25, 0)
		Kit.box(ctx.props, CFrame.lookAt(e, e + Vector3.new(across.Z, 0, -across.X)), Vector3.new(0.5, 0.5, ctx.T), { collide = false, blocks = false })
	end
end

return {
	Seed = 37,
	PipeChance = 0.8,
	HideStyle = "rusty", -- 숨는 곳(L): 찌그러진 정비 사물함
	SearchStyle = "toolbox", -- 뒤지는 곳(Z): 공구함, 그중 한 곳에 열쇠
	Props = { w = sewerWater, P = Props.BigPipe },
	PitTiles = { w = true },
	Walkable = { P = true }, -- (수로는 괴물 배회 지점에서 뺀다: 보행로로만 다닌다)
	Rows = {
		"###############################################",
		"#SS..Z#cc..Z#L...........Z#m.m.m.v#c...Z.L..c##",
		"#SS...#.....#..mm..mm..m..#......v#.........c##",
		"#.....#.....#.....f.......#.......#.....f....##",
		"#.....#.....#....PPPPP....#.......#..........##",
		"#c...L#L...c#v...........v#L.....Z#..........##",
		"###A#####D####D#########D#####D#####D######D###",
		"##...............c##.........................##",
		"##.wwwwwwwbwwwwwww##wwwwwwwwbwwwwwwwwbwwwwww.##",
		"##.w..............##c.b....................w.##",
		"#L.w.################.w.#######D######D###.w.##",
		"##.b.#.mm...m.#######.w.####mm....m#L...Z#.w.##",
		"##.w.#........####c##.w.####.......#.....#.w.##",
		"##cw.D........D...Z##.w.####.......#.....#.w.##",
		"##ccc#....f...#.#####.w.####...f..Z#.....#.w.##",
		"######L......Z#.#####.w.####L......#.....#.b.##",
		"######........#.####..w..###.......#....c#.w.L#",
		"######v......v#.###...b...##.......#c...c#.w.##",
		"#########D#####.##.O..w..O.#v.....v#######.w.##",
		"######L.....c##.#....www....###D##########.w.##",
		"######.......##.#...wwwww..................w.##",
		"##...#c.....Z##.A.O.wwwwwwbwwwwwwwwbwwwwwwbw.##",
		"#E.w.############...wwwww..................w.##",
		"##.w.#......v####....www....###D##########.w.##",
		"##.w.#......v#####.O.....O.##...........Z#.w.##",
		"##.w.D.......######...O...###............#.w.##",
		"##cw.#...f...#######.....####..wwwwwwww..#.w.##",
		"######mm.....#########D######..wwwwwwww..#.w.##",
		"######m.....L####v.........c#............#.b.##",
		"##.wc#.......####L..........#.O...O...O..D.w.##",
		"##.w.D.......####..........Z#............#.w.Z#",
		"##.b.#..c...Z####cc........v#L..........c#.w.##",
		"##.w.###########L#########################.w.##",
		"#Z.w...................c##...................##",
		"##.wwwwwbwwwwwwwbwwwwwww##wwwwwwwbwwwwwwbwww.##",
		"##......................##c..................##",
		"#########D###########D######D#####D######D#####",
		"######L.....c######L..........Z#Z....L#.....Z##",
		"######.......######...PP..PP...#......#......##",
		"######.......######.....mm.....#......#......##",
		"######.......######............#.....c#......##",
		"######cc....Z######mm.........m#c....c#L...mm##",
		"###############################################",
	},
}
