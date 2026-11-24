// 챕터 9 지하 주차장(1층 격자 + 구덩이 높이의 지하 2층).
// 지하 1층 북쪽: 엘리베이터 홀(시작)·방재실·주차 구역 A/B → 동쪽(차량 램프 3칸 폭 + 비상계단 둘)으로 지하 2층(구덩이 높이)
// → 지하 2층 주차 구역 C/D(침수 대비로 한 단 올린 발전기실·소화펌프실을 지나갈 수도 있다) → 서쪽(차량 램프 3칸 폭 + 비상계단 둘)으로 지하 1층 남쪽
// → 기계실·전기실·하역장 → 급배기 팬룸 / 네 칸 폭 트럭 차로 → 정산 구역 → 차량 출구 게이트(E).
//   node tools/places/parking.js [--dry] [--print]      (STAGE_OUT_DIR 로 다른 폴더에)
// 주의: 지하 2층의 차(K)·기둥(X)은 구덩이 높이라서 PitTiles 에 있고, level-graph 는 PitTiles 를 지나갈 수 있는 칸으로 본다.
//   그래서 실제(막힘) 기준은 K·X 를 벽으로 바꿔 따로 잰다(docs/levels/stage9.md). 열쇠 상자·숨는 곳은 구덩이 높이에 못 두므로 한 단 올린 방에 둔다.
const fs = require("fs");
const path = require("path");
const { Grid, report } = require("./lib");

const g = new Grid(47, 43);
let seed = 9100;
const rnd = () => ((seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648);
// 주차 줄: every 칸마다 기둥(wall = 벽 기둥 #), 나머지는 차 또는 빈 칸. gaps = 사람이 지나는 틈
function carRow(x0, x1, y, { pit = false, gaps = [], every = 5, phase = 0, empty = 0.25, wall = false }) {
	for (let x = x0; x <= x1; x++) {
		if (gaps.includes(x)) continue;
		if ((x - x0 + phase) % every === 0) g.set(x, y, wall ? "#" : pit ? "X" : "B");
		else g.set(x, y, rnd() < empty ? (pit ? "y" : "l") : pit ? "K" : "Q");
	}
}

// ══ 지하 1층 북쪽 (y 1~12) ══
// 엘리베이터 홀(시작): 엘리베이터 셋, 사전 정산기 (나가는 문 둘: 주차 구역, 방재실)
g.fill(1, 1, 8, 5).set(9, 3, "D").set(5, 6, "D");
g.put("S", [[2, 3], [3, 3]]).put("e", [[2, 1], [4, 1], [6, 1]]).set(8, 1, "J").set(1, 5, "L").set(8, 5, "h");
// 방재실(관리 사무소): CCTV 콘솔, 책상, 서류장, 사물함
g.fill(1, 7, 8, 12).set(9, 10, "D");
g.put("C", [[1, 8], [1, 9]]).put("T", [[4, 9], [6, 10]]).put("k", [[8, 7], [8, 8]]).put("L", [[1, 11], [3, 12], [8, 12]]).put("Z", [[3, 7], [6, 12]]);
// 주차 구역 A(서) · B(동): 가운데 칸막이 벽, 차 통로 아치 셋
g.fill(10, 1, 45, 12).wall(27, 1, 27, 12).put("A", [[27, 2], [27, 7], [27, 11]]);
carRow(12, 26, 1, { phase: 1 });
carRow(28, 43, 1, { phase: 2 });
for (const y of [4, 5]) {
	carRow(12, 25, y, { gaps: [18], every: 4, wall: y === 4 });
	carRow(29, 43, y, { gaps: [36], every: 4, wall: y === 4 });
}
for (const y of [8, 9]) {
	carRow(12, 25, y, { gaps: [14, 22], every: 4, phase: 2, wall: y === 9 });
	carRow(29, 43, y, { gaps: [32, 40], every: 4, phase: 2, wall: y === 9 });
}
carRow(12, 26, 12, { phase: 3, empty: 0.3 });
carRow(28, 37, 12, { gaps: [35, 36, 37], phase: 3, empty: 0.3 });
g.put("t", [[10, 7], [10, 8]]).put("h", [[45, 6]]).set(26, 3, "u").set(28, 10, "u"); // 전기차 충전기, 소화전, 카트
g.put("N", [[11, 3], [28, 7], [40, 11]]).put("j", [[20, 6], [34, 6]]).put("i", [[38, 10], [44, 7]]).set(10, 5, "h");
g.put("Z", [[10, 1], [45, 1], [45, 4], [10, 12], [26, 6], [28, 6]]).set(11, 12, ".").set(45, 9, "L");
// 아래로: 차량 램프(3칸 폭) + 비상계단 둘
g.put("s", [[39, 13], [40, 13], [41, 13], [36, 13], [44, 13]]);

// ══ 지하 2층 (구덩이 높이 p, y 14~27) ══
g.fill(1, 14, 45, 27, "p").wall(24, 14, 24, 27);
g.put("p", [[24, 14], [24, 20], [24, 21], [24, 25], [24, 26]]); // 방화 구획 틈 셋
for (const y of [17, 18]) {
	carRow(3, 8, y, { pit: true, every: 4, phase: 1, gaps: [6], wall: y === 17 });
	carRow(17, 22, y, { pit: true, every: 4, phase: 2, gaps: [19], wall: y === 17 });
	carRow(26, 28, y, { pit: true, every: 4, phase: 3, wall: y === 17 });
	carRow(38, 43, y, { pit: true, every: 4, phase: 1, gaps: [41], wall: y === 17 });
}
for (const y of [22, 23]) {
	carRow(3, 8, y, { pit: true, every: 4, phase: 3, gaps: [5], wall: y === 23 });
	carRow(17, 22, y, { pit: true, every: 4, phase: 0, gaps: [20], wall: y === 23 });
	carRow(26, 28, y, { pit: true, every: 4, phase: 1, wall: y === 23 });
	carRow(38, 43, y, { pit: true, every: 4, phase: 3, gaps: [40], wall: y === 23 });
}
carRow(14, 22, 27, { pit: true, empty: 0.3 });
carRow(26, 44, 27, { pit: true, phase: 2, empty: 0.3 });
carRow(3, 22, 14, { pit: true, phase: 4, empty: 0.3 });
// 서쪽 끝 좁은 배관 통로(벽 사이 한 칸 폭)
g.fill(1, 14, 1, 27, "p").wall(2, 15, 2, 25).set(2, 26, "p").set(2, 20, "p");
// 비상 발전기실(침수 대비로 한 단 올림): 양쪽 계단 + 문
g.wall(9, 17, 15, 23).fill(10, 18, 14, 22).put("A", [[9, 20], [15, 20]]).put("s", [[8, 20], [16, 20]]);
g.put("G", [[12, 18], [12, 22]]).put("R", [[14, 18]]).set(10, 22, "L").put("Z", [[10, 18], [14, 22]]);
// 소화펌프실·저수조(한 단 올림)
g.wall(30, 17, 36, 23).fill(31, 18, 35, 22).put("A", [[30, 20], [36, 20]]).put("s", [[29, 20], [37, 20]]);
g.put("P", [[33, 18], [34, 18]]).put("H", [[33, 22]]).set(31, 22, "L").put("Z", [[31, 18], [35, 22]]);
g.put("a", [[6, 16], [20, 25], [40, 16], [34, 25]]).put("q", [[22, 20], [26, 25], [18, 16]]); // 제트 팬, 천장 표지
// 위로: 차량 램프(3칸 폭) + 비상계단 둘
g.put("s", [[2, 28], [3, 28], [4, 28], [8, 28], [13, 28]]);

// ══ 지하 1층 남쪽 (y 29~41) ══
// 램프 착지 통로 → 하역장(두 칸 폭), 기계실
g.fill(1, 29, 10, 30).fill(11, 29, 11, 30);
g.set(1, 30, "Z").set(6, 29, "h");
// 기계실: 공조기·배관·환기 덕트(착지 통로·하역장·전기실 문)
g.fill(1, 32, 10, 36).set(6, 31, "D").set(11, 34, "D");
g.put("m", [[2, 33], [4, 33]]).put("V", [[8, 36]]).set(1, 36, "v").set(10, 32, "L").put("Z", [[1, 32]]).set(6, 35, "f");
// 전기실: 배전반 줄(기계실·하역장 문)
g.fill(1, 38, 10, 41).set(4, 37, "D").set(11, 40, "D");
g.put("R", [[6, 41], [7, 41], [8, 41]]).put("k", [[1, 39]]).set(1, 41, "L").set(10, 38, "Z").set(3, 41, "Z");
// 하역장: 하역 플랫폼, 셔터, 트럭 두 대
g.fill(12, 29, 26, 41).wall(17, 34, 21, 35);
g.put("x", [[14, 41], [17, 41], [20, 41], [23, 41]]).put("U", [[14, 39], [14, 40], [23, 31], [23, 32]]);
g.put("c", [[13, 36], [26, 33]]).put("z", [[18, 36], [20, 33]]).put("u", [[16, 30], [24, 37]]).set(26, 29, "L").set(12, 41, "Z").set(26, 36, "Z").set(12, 32, "Z").set(19, 29, "h");
// 재활용 집하장(막다른 선택 방: 숨는 곳만, 열쇠 상자 없음)
g.fill(28, 29, 33, 32).set(34, 30, "D");
g.put("Y", [[29, 29], [30, 29], [31, 29], [30, 32]]).set(28, 31, "L").set(33, 32, "L");
// 급배기 팬룸(북쪽 갈래)
g.fill(28, 34, 33, 36).put("D", [[27, 35], [34, 35]]);
g.put("V", [[30, 34], [32, 34]]).set(28, 36, "Z").set(33, 36, "L").set(31, 35, "d");
// 트럭 차로(남쪽 갈래): 네 칸 폭, 과속 방지턱
g.fill(27, 38, 34, 41).put("w", [[30, 38], [30, 39], [30, 40], [30, 41]]).set(28, 39, "N");
// 정산 구역 / 출구 차로: 정산소(문 둘), 출구 게이트
g.fill(35, 29, 45, 41).wall(36, 29, 41, 29).wall(36, 30, 40, 33).fill(37, 31, 39, 32).put("D", [[36, 31], [40, 32]]);
g.set(39, 31, "Z").set(37, 32, "C");
g.put("#", [[44, 35], [45, 35], [44, 37], [45, 37]]).set(45, 36, "E").set(44, 36, "g").set(41, 30, "J");
g.put("B", [[41, 35], [38, 38]]).set(45, 33, "Z").set(39, 41, "Z").set(35, 29, "L").set(45, 31, "h").set(45, 29, "L").put("Q", [[43, 41], [44, 41]]).put("i", [[41, 38], [42, 38]]).set(40, 36, "N");

if (process.argv.includes("--print")) console.log(g.rows().map((row, i) => String(i).padStart(2) + " " + row).join("\n"));
const PROPS = {
	Q: "CP.Car", K: "CP.Car", l: "CP.EmptyStall", y: "CP.EmptyStall", B: "CP.Pillar", X: "CP.Pillar", u: "CP.Cart", h: "CP.Hydrant", e: "CP.Elevator",
	x: "CP.Shutter", g: "CP.Barrier", J: "CP.PayMachine", s: "CP.Ramp", T: "Props.Desk", k: "Props.Cabinet",
	C: "CP.CctvDesk", t: "CP.EvCharger", N: "CP.HangSign", q: "CP.HangSign", j: "CP.JetFan", a: "CP.JetFan", d: "CP.Duct", i: "CP.Cone", w: "CP.SpeedBump",
	G: "CP.Generator", R: "CP.Switchgear", P: "CP.FirePump", H: "CP.WaterTank", V: "CP.FanUnit", U: "CP.Truck", z: "CP.PalletJack", Y: "CP.RecycleBin",
};
const PIT = ["K", "X", "y", "a", "q"];
const WALK = ["l", "y", "u", "h", "e", "x", "g", "k", "N", "q", "j", "a", "d", "i", "w"];
const r = report("지하 주차장", g, { pits: PIT, walkable: WALK, blocked: Object.keys(PROPS).filter((k) => !WALK.includes(k) && k !== "s") });
if (!process.argv.includes("--dry")) {
	// 스테이지 파일 전체를 한 번에 쓴다(Props 줄 포함)
	const text = [
		"--!strict",
		"-- STAGE 9 — 지하 주차장 (47x43칸, tools/places/parking.js 로 생성)",
		"-- 지하 1층 북쪽: 엘리베이터 홀(시작)·방재실·주차 구역 A/B(차 Q, 빈 칸 l, 굵은 기둥 B, 칸막이 아치).",
		"-- 동쪽 3칸 폭 차량 램프와 비상계단 둘(s)로 지하 2층(구덩이 높이: 차 K, 빈 칸 y, 기둥 X)으로 내려간다. 지하 2층 주차 줄 사이에는",
		"-- 침수 대비로 한 단 올린 비상 발전기실·소화펌프실이 있어 지나갈 수도 있다(문마다 계단). 서쪽 끝은 좁은 배관 통로.",
		"-- 서쪽 3칸 폭 램프와 비상계단 둘로 지하 1층 남쪽(기계실·전기실·하역장)으로 올라와, 급배기 팬룸 또는 네 칸 폭 트럭 차로로",
		"-- 정산 구역, 차단기(g)가 달린 차량 출구 게이트(E)로. 맞댄 주차 줄의 한 줄은 굵은 콘크리트 벽 기둥(#)이라 넓은 구역이 음파 크기로 끊긴다.",
		`-- 전용 소품은 ChapterProps/Parking. 숨는 곳(L)은 사물함, 뒤지는 곳(Z)은 공구함(지하 2층은 올린 방에만). 출구까지 최단 약 ${r.exit}칸.`,
		"local Props = require(script.Parent.Parent.Props)",
		"local CP = require(script.Parent.Parent.ChapterProps.Parking)",
		"return {",
		"\tSeed = 91,",
		"\tPipeChance = 0.3,",
		'\tHideStyle = "locker", -- 숨는 곳(L): 철제 사물함',
		'\tSearchStyle = "toolbox", -- 뒤지는 곳(Z): 공구함, 그중 한 곳에 열쇠',
		`\tProps = { ${Object.entries(PROPS).map(([k, v]) => `${k} = ${v}`).join(", ")} },`,
		`\tPitTiles = { ${PIT.map((k) => `${k} = true`).join(", ")} },`,
		`\tWalkable = { ${WALK.map((k) => `${k} = true`).join(", ")}, K = false, X = false },`,
		"\tRows = {",
		...g.rows().map((row) => `\t\t"${row}",`),
		"\t},",
		"}",
		"",
	].join("\n");
	const dir = process.env.STAGE_OUT_DIR || path.join(__dirname, "..", "..", "src", "server", "Stages");
	fs.writeFileSync(path.join(dir, "Stage9.luau"), text);
}
