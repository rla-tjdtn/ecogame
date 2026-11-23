--!strict
-- STAGE 3 — 하수도 (43x41칸, tools/gen-themed.js sewer 로 생성)
-- 벽돌 아치 터널(가운데 수로 w + 양쪽 보행로)이 맵을 지그재그로 4번 가로지른다. 수로는 철제 다리(b)로 건넌다.
-- 터널 사이 암반에 펌프실·원형 저수조(기둥)·밸브실·정비 작업장·수문실·공구 창고, 지름길 방 3곳(양쪽 문).
-- 출구는 마지막 터널 왼쪽 끝의 배수구. 출구까지 최단 약 146칸.
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
		"###########################################",
		"#SS...Z###.m.m....v..Z#####################",
		"#SS....###......f.....####cc......Z########",
		"#......###............####....f....########",
		"#.....L###.cc........L####c.......c########",
		"###A###########D##############A############",
		"##.......................................##",
		"##.wwwwwwwwbwwwwwwwwwbwwwwwwwwwbwwwwwwww.##",
		"##.....................................w.##",
		"##########D##########A##########D#####.w.##",
		"#######......Z###Z........###cc....Z##.w.##",
		"#######.m...m.###..O...O..###.......##.w.Z#",
		"#######.......###....f....###...f...##.b.##",
		"#######.v.....###..O...O..###.......##.w.##",
		"#######...c..L###c.......L###c.....L##.w.##",
		"################################D#####.w.##",
		"##.....................................w.##",
		"##.wwwwwwwwbwwwwwwwwwbwwwwwwwwwbwwwwwwww.##",
		"##.w.....................................##",
		"##.w.####D######################A##########",
		"##.w.#m.....Z###cc..m...Z###m.......m######",
		"#Z.w.#.......###c........###.........######",
		"##.b.#...f...###......f..###....v....######",
		"##.w.#.......###.........###.........######",
		"##.w.#v.....L###L........###Z.......L######",
		"#c.w.####D##########D######################",
		"##.w.....................................##",
		"##.wwwwwwwwbwwwwwwwwwbwwwwwwwwwbwwwwwwww.##",
		"##.....................................w.##",
		"##########D######################D####.w.##",
		"#######m.m....Z###cc.....Z####m.....c#.w.##",
		"#######........###........####.......#.w.##",
		"#######....f...###...f....####.......#.b.##",
		"#######........###........####.......#.w.L#",
		"#######v......L###c......L####Z.....L#.w.##",
		"######################A##########D####.w.##",
		"##.....................................w.##",
		"#E.wwwwwwwwbwwwwwwwwwbwwwwwwwwwbwwwwwwww.##",
		"##.......................................##",
		"########L########Z#########c#######L#######",
		"###########################################",
	},
}
