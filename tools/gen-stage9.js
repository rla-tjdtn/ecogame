// Generates the Rows of STAGE 9 — 지하 주차장 (src/server/Stages/Stage9.luau) by hand-placed blocks:
// 지하 1층 북쪽 주차 구역(시작 엘리베이터 홀·관리 사무소) → 동쪽 램프/비상계단으로 지하 2층(구덩이 높이) →
// 서쪽 램프/비상계단으로 다시 지하 1층 남쪽(기계실·전기실·하역장·배관 통로·정산소) → 차량 출구 게이트(E).
//   node tools/gen-stage9.js      (writes the Rows block in Stage9.luau, then run node tools/check-layout.js)
const fs = require("fs");
const path = require("path");
const W = 47, H = 43;
const g = Array.from({ length: H }, () => Array(W).fill("#"));
const set = (x, y, c) => { if (x > 0 && y > 0 && x < W - 1 && y < H - 1) g[y][x] = c; };
const fill = (x0, y0, x1, y1, c) => { for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) set(x, y, c); };
const get = (x, y) => g[y][x];

// ── 주차 구역: 두 줄 맞댄 주차 칸(차 + 빈 칸) 사이사이 굵은 기둥, 군데군데 사람이 지나는 틈 ──
// car/empty/pillar = 이 층에서 쓰는 문자, gaps = 틈(통로) x 좌표들, rnd = 빈 칸 확률
let seed = 9100;
const r = () => ((seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648);
function carRow(x0, x1, y, { car, empty, pillar, gaps = [], every = 5, phase = 0, rnd = 0.2 }) {
	for (let x = x0; x <= x1; x++) {
		if (gaps.includes(x)) continue;
		if ((x - x0 + phase) % every === 0) set(x, y, pillar);
		else set(x, y, r() < rnd ? empty : car);
	}
}

// ══ 지하 1층 북쪽 (y 1..12) ══
// 엘리베이터 홀(시작)
fill(1, 1, 8, 5, ".");
set(2, 2, "S"); set(3, 2, "S");
for (const x of [2, 4, 6]) set(x, 1, "e"); // 엘리베이터 문(북쪽 벽)
set(8, 5, "h");
set(9, 3, "D"); // → 주차 구역
// 관리 사무소
fill(1, 7, 8, 12, ".");
set(5, 6, "D"); // 엘리베이터 홀 ↔ 관리 사무소
set(1, 8, "L"); set(1, 10, "L"); set(1, 12, "L");
set(4, 12, "L"); set(8, 12, "L");
set(3, 9, "T"); set(6, 9, "T");
set(8, 7, "k"); set(8, 8, "k");
set(6, 12, "Z"); set(4, 7, "Z");
set(9, 10, "D"); // → 주차 구역
// 주차 구역 A (x 10..45)
fill(10, 1, 45, 12, ".");
// 칸막이 벽 x=27, 통로 아치 3곳
fill(27, 1, 27, 12, "#");
set(27, 2, "A"); set(27, 7, "A"); set(27, 11, "A");
// 북쪽 벽면 주차
carRow(11, 26, 1, { car: "Q", empty: "l", pillar: "B", gaps: [], every: 5, phase: 1, rnd: 0.25 });
carRow(28, 44, 1, { car: "Q", empty: "l", pillar: "B", every: 5, phase: 2, rnd: 0.25 });
// 가운데 두 줄
for (const y of [4, 5]) {
	carRow(12, 25, y, { car: "Q", empty: "l", pillar: "B", gaps: [18], every: 4, rnd: 0.2 });
	carRow(29, 43, y, { car: "Q", empty: "l", pillar: "B", gaps: [36], every: 4, rnd: 0.2 });
}
for (const y of [8, 9]) {
	carRow(12, 25, y, { car: "Q", empty: "l", pillar: "B", gaps: [14, 22], every: 4, phase: 2, rnd: 0.2 });
	carRow(29, 43, y, { car: "Q", empty: "l", pillar: "B", gaps: [32, 40], every: 4, phase: 2, rnd: 0.2 });
}
// 남쪽 벽면 주차(램프·비상계단 앞은 비운다)
carRow(11, 26, 12, { car: "Q", empty: "l", pillar: "B", every: 5, phase: 3, rnd: 0.3 });
carRow(28, 44, 12, { car: "Q", empty: "l", pillar: "B", gaps: [40, 41, 42, 44], every: 5, phase: 3, rnd: 0.3 });
set(10, 6, "h"); set(45, 6, "h"); set(26, 3, "u"); set(28, 10, "u");
// 램프(3칸 폭, 아래로) + 비상계단
for (const x of [40, 41, 42]) set(x, 13, "s");
set(44, 13, "s");
set(45, 11, "Z"); set(10, 12, "Z"); set(11, 12, "l");

// ══ 지하 2층 (구덩이 높이, y 14..27) ══
fill(1, 14, 45, 27, "p");
// 칸막이 벽 x=24 (아치 3곳)
fill(24, 14, 24, 27, "#");
set(24, 15, "p"); set(24, 20, "p"); set(24, 21, "p"); set(24, 26, "p"); // (구덩이 높이라 아치 대신 뚫린 틈)
for (const y of [17, 18]) {
	carRow(3, 22, y, { car: "K", empty: "y", pillar: "X", gaps: [9, 16], every: 4, phase: 1, rnd: 0.2 });
	carRow(26, 43, y, { car: "K", empty: "y", pillar: "X", gaps: [31, 38], every: 4, phase: 1, rnd: 0.2 });
}
for (const y of [22, 23]) {
	carRow(3, 22, y, { car: "K", empty: "y", pillar: "X", gaps: [6, 13, 19], every: 4, phase: 3, rnd: 0.2 });
	carRow(26, 43, y, { car: "K", empty: "y", pillar: "X", gaps: [29, 35, 41], every: 4, phase: 3, rnd: 0.2 });
}
// 벽면 주차(동쪽 램프 착지점은 비운다)
carRow(2, 22, 27, { car: "K", empty: "y", pillar: "X", gaps: [2, 3, 4, 8], every: 5, phase: 0, rnd: 0.3 });
carRow(26, 44, 27, { car: "K", empty: "y", pillar: "X", every: 5, phase: 2, rnd: 0.3 });
carRow(2, 22, 14, { car: "K", empty: "y", pillar: "X", every: 5, phase: 4, rnd: 0.3 });
// 좁은 배관 통로(지하 2층 서쪽 끝, 벽 사이 한 칸 폭)
fill(1, 14, 1, 27, "p");
fill(2, 15, 2, 25, "#");
set(2, 26, "p");
// 램프(서쪽, 위로) + 비상계단
for (const x of [2, 3, 4]) set(x, 28, "s");
set(8, 28, "s");

// ══ 지하 1층 남쪽 (y 29..41) ══
// 램프 착지 통로
fill(1, 29, 10, 30, ".");
// 기계실 (x 1..10, y 32..36)
fill(1, 32, 10, 36, ".");
set(5, 31, "D");
set(2, 33, "m"); set(5, 33, "m"); set(8, 33, "m"); set(2, 35, "v");
set(10, 36, "L"); set(1, 36, "Z");
set(6, 36, "f");
// 전기실 (x 1..10, y 38..41)
fill(1, 38, 10, 41, ".");
set(4, 37, "D");
set(1, 39, "k"); set(1, 40, "k"); set(10, 39, "k"); set(10, 40, "k");
set(6, 41, "m"); set(3, 41, "L"); set(8, 41, "Z");
set(11, 40, "D"); // 전기실 → 하역장
// 하역장 (x 12..26, y 29..41)
fill(12, 29, 26, 41, ".");
set(11, 29, "A"); set(11, 30, "#"); // 램프 착지 → 하역장 (아치는 한 칸)
for (const x of [14, 17, 20, 23]) set(x, 41, "x"); // 셔터(남쪽 벽)
set(13, 34, "c"); set(13, 37, "c"); set(26, 33, "c"); set(26, 38, "c");
fill(17, 34, 21, 34, "c"); fill(17, 36, 21, 36, "c");
set(19, 34, "."); set(19, 36, ".");
set(16, 30, "u"); set(24, 40, "u"); set(26, 35, "L"); set(12, 41, "Z");
set(15, 29, "h");
// 배관 통로 (하역장 동쪽, 한 칸 폭으로 꺾이며 정산 구역으로)
const duct = [[27, 31], [28, 31], [29, 31], [29, 32], [29, 33], [30, 33], [31, 33], [31, 34], [31, 35], [31, 36], [32, 36], [33, 36], [33, 37], [33, 38], [34, 38], [35, 38]];
for (const [x, y] of duct) set(x, y, ".");
set(27, 31, "D");
set(29, 32, "f"); set(31, 35, "f");
// 큰길(하역장 → 출구 차로): 남쪽
fill(27, 40, 34, 40, ".");
set(27, 40, "D");
// 정산 구역 / 출구 차로 (x 35..45)
fill(35, 29, 45, 41, ".");
fill(36, 30, 40, 33, "#"); // 정산소 건물 덩어리
fill(37, 31, 39, 32, "."); set(38, 33, "D"); set(37, 31, "J"); set(39, 31, "Z");
set(42, 29, "L");
fill(41, 35, 45, 35, "#"); fill(41, 37, 45, 37, "#");
fill(41, 36, 44, 36, "."); set(45, 36, "E"); set(43, 36, "g");
set(1, 4, "L"); set(26, 29, "L"); set(16, 41, "Z");
set(36, 41, "Z"); set(45, 30, "h"); set(44, 40, "Q"); set(42, 40, "Q"); set(35, 34, "u");
// 남쪽 구역 기둥
for (const [x, y] of [[15, 32], [23, 32], [15, 38], [23, 38], [43, 32], [38, 38]]) set(x, y, "B");

// ── 출력 ──
const rows = g.map((row) => row.join(""));
const file = path.join(__dirname, "..", "src", "server", "Stages", "Stage9.luau");
const src = fs.readFileSync(file, "utf8");
const out = src.replace(/Rows = \{[\s\S]*?\n\t\},/, "Rows = {\n" + rows.map((x) => `\t\t"${x}",`).join("\n") + "\n\t},");
fs.writeFileSync(file, out);
console.log(rows.join("\n"));
