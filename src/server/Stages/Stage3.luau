--!strict
-- STAGE 3 — 하수도 (47x43칸, tools/places/sewer.js 로 생성)
-- 벽돌 아치 터널(보행로 / 수로 w / 보행로, 갈비 아치) 세 줄이 S자로 이어지고, 가운데 띠 한복판에 원형 저수조(물웅덩이·기둥, 둘레 보행로 고리)가 있다.
-- 수로는 6스터드 낮은 물길: 철제 다리(b)로만 반대편 보행로로 건넌다. 띠마다 터널과 나란한 방 줄이 있어 두세 갈래로 갈린다.
-- 위 띠: 정비 출입구(시작)에서 위 터널(가운데 무너짐) 또는 공구 창고·펌프실·밸브실·관리 사무실 방 줄로 동쪽. 동쪽 터널 또는 배수 제어실로 꺾어
-- 가운데 띠: 동쪽 가지 터널 / 펌프 제어실 / 침전조 세 갈래가 저수조 고리(북·남 반원)로 모이고, 서쪽 가지 터널 / 정비 작업장 / 침사지로 갈려 수문실 쪽 서쪽으로.
-- 서쪽 터널 또는 수문실 아래 문으로 꺾어 아래 띠: 아래 터널(가운데 무너짐) 또는 공구 창고·자재실·오수 펌프장·저장고·배수 점검실 방 줄로 동쪽,
-- 아래 터널 동쪽 끝 배수구(출구). 어느 칸을 막아도 돌아가는 길이 있다(목 0). 출구까지 최단 약 137칸.
local Props = require(script.Parent.Parent.Props)
local CP = require(script.Parent.Parent.ChapterProps.Sewer) -- 챕터 3 전용 소품(펌프·밸브·수문·스크린·사다리 …)

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
	Props = { w = sewerWater, P = Props.BigPipe, l = CP.Ladder, M = CP.Pump, V = CP.ValveStand, Y = CP.GaugePanel, G = CP.SluiceGate, H = CP.BarScreen, J = CP.Workbench, I = CP.PipeStack, T = Props.Desk, C = Props.Cabinet },
	PitTiles = { w = true, H = true },
	Walkable = { P = true, l = true }, -- (수로는 괴물 배회 지점에서 뺀다: 보행로로만 다닌다)
	Rows = {
		"###############################################",
		"#SSl.Z#cc..Z#L...........Z#......v#C...Z.L..c##",
		"#SS...#.....#..M.M.M.M.M..#.V.V.V.#.........c##",
		"#.....D.....D.....f.......D.......D..T..f....##",
		"#.....#.....#....PPPPP....#.......#.......T..##",
		"#c...L#L...c#v...........v#L.....Z#C.........##",
		"##A######D######D#######D#####D#####D######D###",
		"##..........l....c##.........................##",
		"##.wwwwwwwbwwwwwww##wwwwwwwwbwwwwwwwwbwwww.w.##",
		"##.w.......................................w.##",
		"##.w.#################################D###.w.##",
		"##.w.###############################Y...Y#.w.##",
		"##.w.#m.J..J.v###############YY...Y#.....#.wl##",
		"##ccc#........#L#############.....Z#L....#.w.##",
		"######.......Z#.#############......#..f.Z#.w.##",
		"######L...f...#.#############...f..D.....#.b.##",
		"######........#.####.....####L.....#.....#.w.L#",
		"######........D.............D......#.....#.w.##",
		"######........####.O.....O.##.....v#v...v#.w.##",
		"#########D#######....www....###D######D###.w.##",
		"##..................wwwww..................w.##",
		"##.w.wwwwwbwwwwwwHbwwwwwwwbHwwwwwwwbwwwwwwbw.##",
		"##.w................wwwww....................##",
		"##.w.####D#######....www....####D######D#######",
		"##.w.#m.G....v####.O.....O.###...........######",
		"##.w.#.......v#####..........D..........Z######",
		"#L.w.#V.......######.....#####...........######",
		"##.b.D....f...########D#######..wwwwwww..######",
		"##.w.#.......L#c..........Zc##...........######",
		"##.w.#........D.............D..O...O...O.######",
		"##.w.#........#.Zv.L.......v##L.........c######",
		"##.w.#c......Z#################################",
		"##.w.####D######L##############################",
		"#Z.....................c##...................##",
		"##.wwwwwbwwwwwwwbwwwwwww##wwwwwwwbwwwwwwbwww.E#",
		"##..................................l........##",
		"######D########D#####D######D#####D#########D##",
		"######.....c#L...Z#L..........Z#Z....L#Z.....##",
		"######......#.....#...PP..PP...#......#......##",
		"######L.....D.....D.....MM.....D......D......##",
		"######......#.III.#............#......#......##",
		"######cc...Z#.....#M.M........M#c....c#L...mY##",
		"###############################################",
	},
}
