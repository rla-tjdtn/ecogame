// Generates the Rows of STAGE 10 — 폐영화관 (src/server/Stages/Stage10.luau): 실제 멀티플렉스 구조를 손으로 배치한다.
//   맨 아래 로비 띠: 매표소(시작, 동쪽)·매점 카운터(팝콘 기계·서랍)·검표대·기둥·줄 세우기 기둥, 아래쪽에 화장실 2·청소도구함·창고·직원 휴게실.
//   서쪽 넓은 복도(3칸 폭)로 올라가면 가운데 메인 복도(3칸 폭). 복도 아래에 남쪽 상영관 4개(스크린이 남쪽), 위에 북쪽 상영관 3개(스크린이 북쪽).
//   상영관마다 경사진 좌석 줄(q: 스크린이 북쪽, u: 스크린이 남쪽), 앞쪽 스크린 벽(W), 양옆 통로, 뒤쪽 출입문 2개, 뒤 가운데 영사실(P 영사기).
//   상영관 뒷문·영사실 문은 좁은 영사실 통로(북·남 각 1칸 폭)로 이어지고, 그 통로가 문으로 메인 복도와 이어진다(고리).
//   남쪽 상영관 앞문은 스크린 뒤 직원 통로로, 북쪽 상영관 앞문은 상영관 사이 직원 통로로 이어진다(또 고리).
//   가장 큰 3관(북동쪽) 앞문만 위쪽 비상구 복도로 나가고, 비상구 복도를 서쪽으로 따라가면 출구(E).
//   node tools/gen-stage10.js      (Stage10.luau 의 Rows 를 다시 쓴다. 그다음 node tools/check-layout.js)
const fs = require("fs");
const path = require("path");
const W = 47, H = 43;
const g = Array.from({ length: H }, () => Array(W).fill("#"));
const set = (x, y, c) => { if (x > 0 && y > 0 && x < W - 1 && y < H - 1) g[y][x] = c; };
const fill = (x0, y0, x1, y1, c = ".") => { for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) set(x, y, c); };

// ══ 위쪽: 비상구 복도 (y 1..2) ══
fill(11, 1, 45, 2);
set(10, 1, "E"); // 비상구(출구): 복도 서쪽 끝
for (const x of [18, 30, 40]) set(x, 1, "c"); // 쌓아 둔 의자·상자
set(24, 1, "L"); set(36, 1, "Z"); set(12, 2, "F");

// ══ 북쪽 상영관 (y 4..13, 스크린 y 4) ══
// hall: x0..x1 (양 끝 열이 옆 통로), aisle = 가운데 통로 x, seats = 좌석 줄 y, booth = [bx0, bx1] 영사실(뒤 가운데)
function northHall(x0, x1, { aisle = [], seats, booth, screen }) {
	fill(x0, 4, x1, 13);
	for (let x = screen[0]; x <= screen[1]; x++) set(x, 4, "W");
	for (const y of seats) for (let x = x0 + 1; x <= x1 - 1; x++) if (!aisle.includes(x)) set(x, y, "q");
	// 영사실: 벽(y 11 줄 + 양옆 열) 안쪽 y 12..13, 문은 뒷벽(y 14)
	const [bx0, bx1] = booth;
	fill(bx0 - 1, 11, bx1 + 1, 13, "#");
	fill(bx0, 12, bx1, 13);
	const mid = Math.floor((bx0 + bx1) / 2);
	set(bx1 - bx0 >= 4 ? mid : bx0, 12, "P"); // 영사기(상영관 쪽 영사창을 향해)
	set(bx1, 13, "Z"); // 영사기 캐비닛(필름 서랍)
	set(mid, 14, "D");
	// 뒷문 2개(옆 통로 끝)
	set(x0, 14, "D"); set(x1, 14, "D");
	// 뒤 구석 숨는 곳
	set(x0 + 1, 13, "L");
}
northHall(1, 13, { aisle: [7], seats: [6, 7, 9, 10], booth: [5, 9], screen: [3, 11] }); // 1관(중간)
northHall(17, 25, { seats: [6, 7, 9, 10], booth: [20, 22], screen: [19, 23] }); // 2관(작은)
northHall(29, 45, { aisle: [37], seats: [6, 7, 9, 10, 11], booth: [35, 39], screen: [31, 43] }); // 3관(가장 큰)
for (const x of [30, 31, 32, 33, 41, 42, 43, 44]) set(x, 11, "q"); // (3관은 영사실 양옆까지 좌석)
set(44, 13, "L");
// 앞문(스크린 옆): 1·2관은 상영관 사이 직원 통로로, 3관은 서쪽 직원 통로 + 비상구 복도로
fill(15, 4, 15, 14); fill(27, 4, 27, 14); // 상영관 사이 직원 통로(1칸 폭)
set(14, 5, "D"); set(16, 5, "D"); set(26, 5, "D"); set(28, 5, "D");
set(45, 3, "D"); // 3관 앞문 → 비상구 복도
set(15, 4, "L"); set(27, 4, "L"); // 통로 끝 청소도구함

// ══ 북쪽 영사실 통로 (y 15) + 메인 복도 (y 17..19) ══
fill(1, 15, 45, 15);
for (const x of [3, 11, 24, 33, 43]) set(x, 16, "D");
fill(1, 17, 45, 19);
for (const x of [6, 18, 30, 40]) set(x, 17, "F"); // 복도 포스터 액자
for (const x of [12, 36]) set(x, 19, "O");
set(45, 17, "Z"); set(45, 19, "L");

// ══ 서쪽 넓은 복도 (x 1..3, y 20..41): 로비 → 메인 복도 ══
fill(1, 20, 3, 41);
for (const y of [24, 29]) set(1, y, "F");
set(3, 41, "L"); set(1, 41, "Z");

// ══ 남쪽 영사실 통로 (y 21) ══
fill(5, 21, 45, 21);
set(4, 21, "D");
for (const x of [9, 24, 35, 44]) set(x, 20, "D");

// ══ 남쪽 상영관 (y 23..30, 스크린 y 30) ══
function southHall(x0, x1, { aisle = [], booth, screen }) {
	fill(x0, 23, x1, 30);
	for (let x = screen[0]; x <= screen[1]; x++) set(x, 30, "W");
	for (const y of [25, 26, 27, 28]) for (let x = x0 + 1; x <= x1 - 1; x++) if (!aisle.includes(x)) set(x, y, "u");
	const [bx0, bx1] = booth;
	fill(bx0 - 1, 23, bx1 + 1, 25, "#");
	fill(bx0, 23, bx1, 24);
	const mid = Math.floor((bx0 + bx1) / 2);
	set(bx0, 24, "P"); // 영사기(문 옆을 비워 둔다)
	set(bx1, 23, "Z");
	set(mid, 22, "D");
	set(x0, 22, "D"); set(x1, 22, "D"); // 뒷문 2개
	set(x0, 31, "D"); set(x1, 31, "D"); // 앞문 2개(스크린 옆) → 직원 통로
	set(x1 - 1, 23, "L");
}
southHall(5, 13, { booth: [8, 10], screen: [7, 11] }); // 4관
southHall(15, 26, { aisle: [], booth: [19, 22], screen: [17, 24] }); // 5관(큰)
southHall(28, 35, { booth: [30, 32], screen: [30, 33] }); // 6관(작은)
southHall(37, 45, { booth: [40, 42], screen: [39, 43] }); // 7관

// ══ 직원 통로 (y 32, 스크린 뒤) ══
fill(5, 32, 45, 32);
set(4, 32, "D");
set(45, 32, "Z");

// ══ 로비 띠 (y 34..41) ══
// 로비 큰 홀 x 5..38, y 34..38
fill(5, 34, 38, 38);
set(4, 35, "A"); set(4, 37, "A"); // 서쪽 넓은 복도로(검표대 앞)
set(7, 36, "g"); // 검표대
for (const x of [12, 30]) set(x, 37, "O");
// 매점: 카운터(y 36) 뒤 직원 줄(y 35), 벽 쪽 팝콘·음료 기계(y 34)
for (let x = 16; x <= 26; x++) set(x, 36, "C");
for (const x of [17, 20, 25]) set(x, 34, "M");
set(22, 34, "Z"); set(16, 34, "Z");
// 줄 세우기 기둥(벨트) 과 포스터
for (let x = 28; x <= 35; x++) set(x, 38, "r");
for (const x of [6, 9, 12, 29, 33, 37]) set(x, 34, "F");
// 아래쪽 방들 (y 40..41, 문은 y 39)
fill(5, 40, 11, 41); set(8, 39, "D"); for (const x of [5, 7, 9]) set(x, 41, "L"); set(11, 41, "V"); // 남자 화장실(칸막이 = 숨는 곳)
fill(13, 40, 19, 41); set(16, 39, "D"); for (const x of [13, 15, 17]) set(x, 41, "L"); set(19, 41, "V"); // 여자 화장실
fill(21, 40, 22, 41); set(21, 39, "D"); set(22, 40, "L"); set(22, 41, "L"); // 청소도구함
fill(24, 40, 31, 41); set(27, 39, "D"); for (const x of [24, 25, 30, 31]) set(x, 41, "c"); set(28, 41, "Z"); // 창고
fill(33, 40, 38, 41); set(35, 39, "D"); set(36, 40, "T"); set(33, 41, "L"); set(38, 41, "Z"); // 직원 휴게실
// 매표소(시작): x 40..45, y 34..41. 로비로 문 하나 + 매표 창구 카운터(숨는 곳은 창구 뒤)
fill(40, 34, 45, 41);
set(39, 36, "D");
for (const y of [38, 39]) set(40, y, "C"); set(40, 40, "L"); set(45, 41, "Z"); set(43, 40, "T");
set(43, 35, "S"); set(44, 35, "S"); set(43, 36, "S"); set(44, 36, "S");

// ── 출력 ──
const rows = g.map((row) => row.join(""));
const file = path.join(__dirname, "..", "src", "server", "Stages", "Stage10.luau");
const src = fs.readFileSync(file, "utf8");
const out = src.replace(/Rows = \{[\s\S]*?\n\t\},/, "Rows = {\n" + rows.map((x) => `\t\t"${x}",`).join("\n") + "\n\t},");
fs.writeFileSync(file, out);
console.log(rows.join("\n"));
