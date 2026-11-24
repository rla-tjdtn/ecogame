--!strict
-- STAGE 9 — 지하 주차장 (47x43칸, tools/places/parking.js 로 생성)
-- 지하 1층 북쪽: 엘리베이터 홀(시작)·방재실·주차 구역 A/B(차 Q, 빈 칸 l, 굵은 기둥 B, 칸막이 아치).
-- 동쪽 3칸 폭 차량 램프와 비상계단 둘(s)로 지하 2층(구덩이 높이: 차 K, 빈 칸 y, 기둥 X)으로 내려간다. 지하 2층 주차 줄 사이에는
-- 침수 대비로 한 단 올린 비상 발전기실·소화펌프실이 있어 지나갈 수도 있다(문마다 계단). 서쪽 끝은 좁은 배관 통로.
-- 서쪽 3칸 폭 램프와 비상계단 둘로 지하 1층 남쪽(기계실·전기실·하역장)으로 올라와, 급배기 팬룸 또는 네 칸 폭 트럭 차로로
-- 정산 구역, 차단기(g)가 달린 차량 출구 게이트(E)로. 맞댄 주차 줄의 한 줄은 굵은 콘크리트 벽 기둥(#)이라 넓은 구역이 음파 크기로 끊긴다.
-- 전용 소품은 ChapterProps/Parking. 숨는 곳(L)은 사물함, 뒤지는 곳(Z)은 공구함(지하 2층은 올린 방에만). 출구까지 최단 약 122칸.
local Props = require(script.Parent.Parent.Props)
local CP = require(script.Parent.Parent.ChapterProps.Parking)
return {
	Seed = 91,
	PipeChance = 0.3,
	HideStyle = "locker", -- 숨는 곳(L): 철제 사물함
	SearchStyle = "toolbox", -- 뒤지는 곳(Z): 공구함, 그중 한 곳에 열쇠
	Props = { Q = CP.Car, K = CP.Car, l = CP.EmptyStall, y = CP.EmptyStall, B = CP.Pillar, X = CP.Pillar, u = CP.Cart, h = CP.Hydrant, e = CP.Elevator, x = CP.Shutter, g = CP.Barrier, J = CP.PayMachine, s = CP.Ramp, T = Props.Desk, k = Props.Cabinet, C = CP.CctvDesk, t = CP.EvCharger, N = CP.HangSign, q = CP.HangSign, j = CP.JetFan, a = CP.JetFan, d = CP.Duct, i = CP.Cone, w = CP.SpeedBump, G = CP.Generator, R = CP.Switchgear, P = CP.FirePump, H = CP.WaterTank, V = CP.FanUnit, U = CP.Truck, z = CP.PalletJack, Y = CP.RecycleBin },
	PitTiles = { K = true, X = true, y = true, a = true, q = true },
	Walkable = { l = true, y = true, u = true, h = true, e = true, x = true, g = true, k = true, N = true, q = true, j = true, a = true, d = true, i = true, w = true, K = false, X = false },
	Rows = {
		"###############################################",
		"#.e.e.e.J#Z.lQQQBQlllBQQQQB#QQQBQQQQBlQQQBQQ.Z#",
		"#........#.................A..................#",
		"#.SS.....D.N..............u#..................#",
		"#........#..#QQl#Q.Q#QlQ#Q.#.#llQ#lQ.#lQl#QQ.Z#",
		"#L......h#h.BllQBQ.QBlllBQ.#.BllQBQQ.BQQlBll..#",
		"#####D####..........j.....Z#Z.....j..........h#",
		"#..Z....k#t................AN...............i.#",
		"#C......k#t.lQ.QQQBQlQ.lQQ.#.QQB.QlBlQQB.QQB..#",
		"#C..T....#..QQ.QQQ#lQQ.QQQ.#.QQ#.QQ#QlQ#.lQ#.L#",
		"#.....T..D.................#u.........i.......#",
		"#L.......#.................A............N.....#",
		"#..L..Z.L#Z.QQBQQlQBQQlQBQl#QQBllll...........#",
		"####################################s##sss##s##",
		"#ppKXKKKKXyKKyXKKKyXyKKppppppppppppppppppppppp#",
		"#p#ppppppppppppppppppppp#ppppppppppppppppppppp#",
		"#p#pppapppppppppppqppppp#pppppppppppppppappppp#",
		"#p#KKypKK#######pyKpyKKp#pK#yp#######pKKKpKypp#",
		"#p#KKKpKK#Z.G.R#pKKpKKKp#pKXKp#Z.PP.#pKKKpKKpp#",
		"#p#pppppp#.....#pppppppp#ppppp#.....#ppppppppp#",
		"#pppppppsA.....AspppppqppppppsA.....Aspppppppp#",
		"#p#pppppp#.....#pppppppppppppp#.....#ppppppppp#",
		"#p#KXpKKX#L.G.Z#pXKypXyp#pKKKp#L.H.Z#pKXpKKXpp#",
		"#p#K#pKK########p#KKp#Kp#pyKyp#######pK#pyK#pp#",
		"#p#ppppppppppppppppppppp#ppppppppppppppppppppp#",
		"#p#pppppppppppppppppapppppqpppppppappppppppppp#",
		"#ppppppppppppppppppppppppppppppppppppppppppppp#",
		"#pppppppppppppXKKKKXKKKp#pKyKXKKyKXyKyyXKKyyXp#",
		"##sss###s####s#################################",
		"#.....h............h......L#.YYY..#L######...L#",
		"#Z..............u..........#......D.#####J....#",
		"######D#####...........U...#L.....#.D..Z#....h#",
		"#Z........L#Z..........U...#..Y..L#.#C..D.....#",
		"#.m.m......#........z.....c########.#####....Z#",
		"#..........D.....#####.....#..V.V.#...........#",
		"#.....f....#.....#####.....D...d..D......B..###",
		"#v......V..#.c....z.......Z#Z....L#.....N...gE#",
		"####D#######............u..########.........###",
		"#.........Z#..................w.......B..ii...#",
		"#k.........#..U.............N.w...............#",
		"#..........D..U...............w...............#",
		"#L.Z..RRR..#Z.x..x..x..x......w........Z...QQ.#",
		"###############################################",
	},
}
