--!strict
-- STAGE 5 — 심층 미로
-- 거대한 지하 구조물: 큰 구덩이 여러 개를 잇는 다리(b)와 괴물이 건널 수 없는 좁은 다리(n), 계단(s)으로 오르내리는 복층,
-- 대형 기둥(B), 수직 배관, 긴 복도. 괴물 4마리가 여러 방향에서 접근한다.
local Props = require(script.Parent.Parent.Props)

local function bigPillar(ctx, i, j)
	local Kit = ctx.Kit
	local p = ctx.center(i, j) + Vector3.new(0, ctx.floorY(i, j), 0)
	local h = ctx.H - ctx.floorY(i, j)
	Kit.box(ctx.geo, CFrame.new(p + Vector3.new(0, h / 2, 0)), Vector3.new(4.4, h, 4.4), { name = "BigPillar" })
	Kit.box(ctx.geo, CFrame.new(p + Vector3.new(0, 0.6, 0)), Vector3.new(6, 1.2, 6))
	Kit.box(ctx.geo, CFrame.new(p + Vector3.new(0, 1.6, 0)), Vector3.new(5.2, 0.8, 5.2))
	Kit.box(ctx.geo, CFrame.new(p + Vector3.new(0, h - 1.2, 0)), Vector3.new(6, 2.4, 6))
	for _, s in { -1, 1 } do
		Kit.box(ctx.geo, CFrame.new(p + Vector3.new(s * 2.4, h / 2, 0)), Vector3.new(0.5, h - 4, 1.4), { blocks = false })
		Kit.box(ctx.geo, CFrame.new(p + Vector3.new(0, h / 2, s * 2.4)), Vector3.new(1.4, h - 4, 0.5), { blocks = false })
	end
end

return {
	Seed = 53,
	PipeChance = 0.5,
	Props = { B = bigPillar, P = Props.BigPipe },
	Walkable = { P = true },
	Rows = {
		"########################",
		"#SS..#........#........#",
		"#....D..B..B..A..v..B..#",
		"#SS..#........#........#",
		"###.#####.##.###.####.##",
		"#.......#...........#..#",
		"#.B.....A..ppsppppp.A..#",
		"#.......#..nnnnnnnn.#..#",
		"####.####..psppppsp.#..#",
		"#......................#",
		"####.###.####.#####.####",
		"#..........#...........#",
		"#.pppppspppppp.#.......#",
		"#.bbbbbbbbbbbb.D.......#",
		"#.spppppppppps.#..B....#",
		"##############.#####.###",
		"#.v....A....#.PPPP.m...#",
		"#.B....#....D.....###.##",
		"#......#....#......A..E#",
		"########################",
	},
}
