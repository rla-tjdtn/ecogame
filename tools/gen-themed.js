// 챕터별로 "그 장소처럼 보이는" 구조를 직접 짓는 생성기(gen-stages.js 의 방+미로 방식 대신).
//   node tools/gen-themed.js sewer      → src/server/Stages/Stage3.luau 의 Rows 를 다시 쓴다
//   node tools/gen-themed.js sewer --dry (출력만)
// 1칸 = 8스터드. 문자는 StageBuilder 와 같다(# 벽, . 바닥, w 수로(아래층), b 다리, A 아치, D 문, L 숨는 곳, Z 뒤지는 곳 …).
const fs = require("fs");
const path = require("path");

function grid(W, H) {
	return Array.from({ length: H }, () => Array(W).fill("#"));
}
function setIf(g, x, y, ch, only) {
	if (y <= 0 || y >= g.length - 1 || x <= 0 || x >= g[0].length - 1) return;
	if (only && !only.includes(g[y][x])) return;
	g[y][x] = ch;
}
function room(g, x0, y0, x1, y1, fill = ".") {
	for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) setIf(g, x, y, fill);
}

// ── 하수도: 벽돌 아치 터널(가운데 수로 + 양쪽 보행로)이 지그재그로 맵을 가로지르고, 터널 사이 암반에 펌프실·저수조·창고 ──
function sewer() {
	const W = 43, H = 41;
	const g = grid(W, H);
	// 수로 중심선(지그재그 4줄): 위에서 시작해 아래 왼쪽 배수구(출구)로
	const line = [[3, 7], [39, 7], [39, 17], [3, 17], [3, 27], [39, 27], [39, 37], [3, 37]];
	const water = [];
	for (let k = 0; k + 1 < line.length; k++) {
		const [ax, ay] = line[k], [bx, by] = line[k + 1];
		const dx = Math.sign(bx - ax), dy = Math.sign(by - ay);
		for (let x = ax, y = ay; ; x += dx, y += dy) {
			water.push([x, y]);
			if (x === bx && y === by) break;
		}
	}
	for (const [x, y] of water) g[y][x] = "w";
	for (const [x, y] of water) for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) setIf(g, x + dx, y + dy, ".", ["#"]);
	// 수로를 건너는 철제 다리
	for (const x of [11, 21, 31]) for (const y of [7, 17, 27, 37]) g[y][x] = "b";
	g[12][39] = "b"; g[22][3] = "b"; g[32][39] = "b";

	// 시작 방(안전 구역, 위 왼쪽) → 아치 → 첫 터널 보행로
	room(g, 1, 1, 6, 4);
	g[1][1] = "S"; g[1][2] = "S"; g[2][1] = "S"; g[2][2] = "S";
	g[5][3] = "A";
	g[1][6] = "Z"; g[4][6] = "L";
	// 위쪽 관제실(배수 조절실): 기계 + 사물함
	room(g, 10, 1, 21, 4);
	g[5][15] = "D";
	g[1][11] = "m"; g[1][13] = "m"; g[1][18] = "v"; g[4][11] = "c"; g[4][12] = "c"; g[1][21] = "Z"; g[4][21] = "L"; g[2][16] = "f";
	// 위쪽 오른쪽 저장고
	room(g, 26, 2, 34, 4);
	g[5][30] = "A";
	g[2][26] = "c"; g[2][27] = "c"; g[4][26] = "c"; g[2][34] = "Z"; g[4][34] = "c"; g[3][30] = "f";

	// 1번 암반(9~15행): 펌프실, 원형 저수조, 지름길 창고(위·아래 문)
	room(g, 7, 10, 13, 14);
	g[9][10] = "D";
	g[11][8] = "m"; g[11][12] = "m"; g[13][8] = "v"; g[14][10] = "c"; g[10][13] = "Z"; g[14][13] = "L";
	room(g, 17, 10, 25, 14);
	g[9][21] = "A";
	for (const [x, y] of [[19, 11], [23, 11], [19, 13], [23, 13]]) g[y][x] = "O";
	g[12][21] = "f"; g[10][17] = "Z"; g[14][25] = "L"; g[14][17] = "c";
	room(g, 29, 10, 35, 14);
	g[9][32] = "D"; g[15][32] = "D";
	g[10][29] = "c"; g[10][30] = "c"; g[14][29] = "c"; g[10][35] = "Z"; g[14][35] = "L"; g[12][32] = "f";

	// 2번 암반(19~25행): 지름길 밸브실(왼쪽, 위·아래 문), 정비 작업장, 수문실
	room(g, 6, 20, 12, 24);
	g[19][9] = "D"; g[25][9] = "D";
	g[20][6] = "m"; g[24][6] = "v"; g[20][12] = "Z"; g[24][12] = "L"; g[22][9] = "f";
	room(g, 16, 20, 24, 24);
	g[25][20] = "D";
	g[20][16] = "c"; g[20][17] = "c"; g[21][16] = "c"; g[20][24] = "Z"; g[24][16] = "L"; g[20][20] = "m"; g[22][22] = "f";
	room(g, 28, 20, 36, 24);
	g[19][32] = "A";
	g[20][28] = "m"; g[20][36] = "m"; g[24][28] = "Z"; g[24][36] = "L"; g[22][32] = "v";

	// 3번 암반(29~35행): 배수 펌프 홀, 공구 창고, 지름길 분기실(오른쪽, 위·아래 문)
	room(g, 7, 30, 14, 34);
	g[29][10] = "D";
	g[30][7] = "m"; g[30][9] = "m"; g[30][14] = "Z"; g[34][14] = "L"; g[34][7] = "v"; g[32][11] = "f";
	room(g, 18, 30, 25, 34);
	g[35][22] = "A";
	g[30][18] = "c"; g[30][19] = "c"; g[34][18] = "c"; g[30][25] = "Z"; g[34][25] = "L"; g[32][21] = "f";
	room(g, 30, 30, 36, 34);
	g[29][33] = "D"; g[35][33] = "D";
	g[30][30] = "m"; g[34][30] = "Z"; g[30][36] = "c"; g[34][36] = "L";

	// 바깥 터널 벽에 붙은 정비 사물함·공구함(보행로에서 바로)
	for (const [x, y, ch] of [[8, 39, "L"], [17, 39, "Z"], [27, 39, "c"], [35, 39, "L"], [41, 11, "Z"], [41, 33, "L"], [1, 21, "Z"], [1, 25, "c"]]) g[y][x] = ch;
	// 배수구(출구): 마지막 터널 왼쪽 끝
	g[37][1] = "E";
	return { file: "Stage3.luau", rows: g.map((r) => r.join("")) };
}

// ── 건물형(학교·병원): 긴 복도 3동(본관·별관…)이 끝에서 연결 복도로 이어지고, 복도 양쪽에 방이 줄지어 있다 ──
// 동 k 의 세로 배치(b = 1 + 13k): 위쪽 방 b..b+3, 벽 b+4(문), 복도 b+5..b+6, 벽 b+7(문), 아래쪽 방 b+8..b+11, 벽 b+12
// 연결: 1동→2동 오른쪽 끝, 2동→3동 왼쪽 끝(지그재그). 출구는 3동 오른쪽 끝.
function building(W, H, theme) {
	const g = grid(W, H);
	const B = [1, 14, 27];
	const corr = (k) => [B[k] + 5, B[k] + 6];
	// 복도
	for (let k = 0; k < 3; k++) {
		const x0 = k === 0 ? 1 : 1, x1 = k === 2 ? W - 4 : W - 2;
		room(g, x0, corr(k)[0], x1, corr(k)[1]);
	}
	// 연결 복도(2칸 폭): 오른쪽(1→2동), 왼쪽(2→3동)
	room(g, W - 3, corr(0)[0], W - 2, corr(1)[1]);
	room(g, 1, corr(1)[0], 2, corr(2)[1]);
	// 출구(현관): 3동 복도 오른쪽 끝
	g[corr(2)[0]][W - 3] = "E";
	// 방 줄: 각 동 위·아래. 연결 복도와 겹치는 쪽은 비켜서 시작/끝
	const slots = [];
	for (let k = 0; k < 3; k++) {
		for (const side of ["up", "down"]) {
			const y0 = side === "up" ? B[k] : B[k] + 8;
			const doorY = side === "up" ? B[k] + 4 : B[k] + 7;
			// 이 줄과 겹치는 연결 복도
			let xs = 1, xe = W - 2;
			if ((k === 0 && side === "down") || (k === 1 && side === "up")) xe = W - 5; // 오른쪽 연결 복도 자리
			if ((k === 1 && side === "down") || (k === 2 && side === "up")) xs = 4; // 왼쪽 연결 복도 자리
			if (k === 2) xe = W - 5; // (3동 오른쪽 끝은 현관)
			slots.push({ k, side, y0, y1: y0 + 3, doorY, xs, xe, inward: side === "up" ? 1 : -1 });
		}
	}
	theme(g, slots, corr, W, H);
	return g.map((r) => r.join(""));
}

// 방 하나를 [x0, x1] 로 파고 복도 쪽 벽에 문을 낸다
function cut(g, s, x0, x1, doors, ch = "D") {
	room(g, x0, s.y0, x1, s.y1);
	for (const dx of doors) g[s.doorY][x0 + dx] = ch;
}
// 방 안 좌표: r = 0 이 복도에서 가장 먼 줄(창가), 3 이 복도 쪽 줄
const rowOf = (s, r) => (s.side === "up" ? s.y0 + r : s.y1 - r);

const fill = {
	classroom(g, s, x0, x1) {
		// 칠판 쪽(왼쪽 끝 열)은 비우고, 책상 2줄 × 여러 개(사이사이 통로)
		for (let x = x0 + 2; x <= x1 - 1; x += 2) {
			g[rowOf(s, 1)][x] = "T";
			g[rowOf(s, 2)][x] = "T";
		}
		g[rowOf(s, 0)][x0] = "Z"; // 교탁 서랍(창가 모서리)
	},
	staffroom(g, s, x0, x1) {
		for (let x = x0 + 1; x <= x1 - 1; x += 2) g[rowOf(s, 2)][x] = "T";
		g[rowOf(s, 0)][x0] = "k";
		g[rowOf(s, 0)][x1] = "Z";
	},
	library(g, s, x0, x1) {
		for (let x = x0 + 1; x <= x1 - 1; x += 2) { g[rowOf(s, 0)][x] = "k"; g[rowOf(s, 1)][x] = "k"; }
		g[rowOf(s, 0)][x1] = "Z";
	},
	science(g, s, x0, x1) {
		for (let x = x0 + 1; x <= x1 - 1; x += 3) { g[rowOf(s, 1)][x] = "T"; g[rowOf(s, 1)][x + 1 <= x1 - 1 ? x + 1 : x] = "T"; }
		g[rowOf(s, 0)][x0] = "k"; g[rowOf(s, 0)][x1] = "Z"; g[rowOf(s, 0)][x0 + 2] = "m";
	},
	restroom(g, s, x0, x1) {
		for (let x = x0; x <= x1; x++) if ((x - x0) % 2 === 0) g[rowOf(s, 0)][x] = "L"; // 칸막이(숨는 곳)
	},
	closet(g, s, x0, x1) {
		g[rowOf(s, 0)][x0] = "L"; g[rowOf(s, 0)][x1] = "c"; g[rowOf(s, 1)][x1] = "c";
	},
	nurse(g, s, x0, x1) {
		g[rowOf(s, 0)][x0] = "R"; g[rowOf(s, 0)][x0 + 2] = "R"; g[rowOf(s, 0)][x1] = "k"; g[rowOf(s, 1)][x1] = "Z";
	},
	// 병원
	ward(g, s, x0, x1) {
		for (let x = x0; x <= x1 - 2; x += 2) g[rowOf(s, 0)][x] = "R"; // 창가 쪽 벽에 침대가 줄지어
		g[rowOf(s, 0)][x1] = "Z"; // 협탁
		if (x1 - x0 >= 5) g[rowOf(s, 2)][x0] = "L"; // 옷장
	},
	exam(g, s, x0, x1) {
		g[rowOf(s, 0)][x0 + 2] = "T"; g[rowOf(s, 0)][x1] = "k"; g[rowOf(s, 2)][x0] = "R"; g[rowOf(s, 0)][x0] = "Z";
	},
	surgery(g, s, x0, x1) {
		const mid = Math.floor((x0 + x1) / 2);
		g[rowOf(s, 1)][mid] = "X"; g[rowOf(s, 0)][x0] = "k"; g[rowOf(s, 0)][x1] = "k"; g[rowOf(s, 0)][mid] = "m"; g[rowOf(s, 0)][x0 + 1] = "Z";
	},
	pharmacy(g, s, x0, x1) {
		for (let x = x0 + 1; x <= x1 - 1; x += 2) g[rowOf(s, 1)][x] = "k";
		for (let x = x0; x <= x1; x += 2) g[rowOf(s, 0)][x] = "k";
		g[rowOf(s, 0)][x1] = "Z";
	},
	morgue(g, s, x0, x1) {
		for (let x = x0; x <= x1; x++) g[rowOf(s, 0)][x] = "k"; // 시신 냉장 서랍 벽
		g[rowOf(s, 2)][x0 + 1] = "X"; g[rowOf(s, 1)][x1] = "L";
	},
};

// 줄(slot)을 방 너비 목록대로 나눈다. 방 사이 벽 1칸
function lay(g, s, plan) {
	let x = s.xs;
	for (const [w, kind, doors] of plan) {
		const x0 = x, x1 = Math.min(x + w - 1, s.xe);
		if (x1 - x0 < 2) break;
		cut(g, s, x0, x1, doors.filter((d) => x0 + d <= x1));
		if (fill[kind]) fill[kind](g, s, x0, x1);
		x = x1 + 2;
		if (x > s.xe - 2) break;
	}
}

function school() {
	const W = 47, H = 43;
	const rows = building(W, H, (g, slots, corr) => {
		const S = (k, side) => slots.find((s) => s.k === k && s.side === side);
		// 1동(본관): 교무실(시작·안전) · 교실 줄 / 아래: 교실 · 화장실 · 교실 · 도서관
		const a = S(0, "up");
		cut(g, a, 1, 6, [2]); // 시작 방 = 교무실
		g[a.y0][1] = "S"; g[a.y0][2] = "S"; g[a.y0 + 1][1] = "S"; g[a.y0 + 1][2] = "S";
		g[a.y0][6] = "Z"; g[a.y0 + 3][6] = "k"; g[a.y0 + 2][4] = "T";
		lay(g, { ...a, xs: 8 }, [[7, "classroom", [1, 5]], [7, "classroom", [1, 5]], [3, "restroom", [1]], [7, "classroom", [1, 5]], [7, "classroom", [1, 5]], [5, "closet", [2]]]);
		lay(g, { ...S(0, "down"), xe: 35 }, [[7, "classroom", [1, 5]], [7, "classroom", [1, 5]], [11, "library", [1, 9]], [3, "restroom", [1]], [5, "closet", [2]]]);
		lay(g, { ...S(0, "down"), xs: 40 }, [[3, "closet", [1]]]);
		// 2동(별관): 과학실 · 보건실 · 교실 / 아래: 교실 · 창고 · 음악실(교실)
		lay(g, { ...S(1, "up"), xe: 35 }, [[7, "science", [1, 5]], [5, "nurse", [2]], [7, "classroom", [1, 5]], [7, "classroom", [1, 5]], [6, "science", [1, 4]]]);
		lay(g, { ...S(1, "up"), xs: 40 }, [[2, "closet", [0]]]);
		lay(g, S(1, "down"), [[7, "classroom", [1, 5]], [7, "classroom", [1, 5]], [5, "closet", [2]], [7, "classroom", [1, 5]], [7, "classroom", [1, 5]], [6, "staffroom", [1, 4]]]);
		// 3동: 급식실(큰 방, 식탁 줄) · 교실 / 아래: 체육관(아주 큰 방, 기둥)
		const c = S(2, "up");
		cut(g, c, 4, 18, [2, 7, 12]);
		for (let x = 6; x <= 16; x += 3) { g[c.y0 + 1][x] = "T"; g[c.y0 + 2][x] = "T"; }
		g[c.y0][4] = "m"; g[c.y0][5] = "m"; g[c.y0][18] = "Z"; g[c.y0][10] = "k";
		lay(g, { ...c, xs: 20 }, [[7, "classroom", [1, 5]], [7, "classroom", [1, 5]], [3, "restroom", [1]], [7, "classroom", [1, 5]]]);
		const d = S(2, "down");
		cut(g, d, 8, 34, [3, 13, 23]);
		for (const x of [10, 16, 22, 28, 32]) { g[d.y0 + 3][x] = "O"; }
		g[d.y0 + 3][8] = "Z"; g[d.y0 + 3][34] = "L"; g[d.y0][20] = "c"; g[d.y0][21] = "c";
		lay(g, { ...d, xs: 1 }, [[6, "closet", [2]]]);
		lay(g, { ...d, xs: 36 }, [[7, "classroom", [1, 5]]]);
		// 복도 사물함(숨는 곳): 복도 벽에 붙여 군데군데
		for (const [k, xs] of [[0, [12, 26, 33]], [1, [8, 22, 34]], [2, [14, 30]]]) {
			for (const x of xs) {
				const y = corr(k)[1];
				if (g[y + 1][x] === "#" && g[y][x] === ".") g[y][x] = "L";
			}
		}
		// 지름길 계단실: 1동 오른쪽 가까이에서 2동으로(복도 끝까지 안 가도 된다)
		for (let y = corr(0)[1] + 1; y < corr(1)[0]; y++) { g[y][37] = "."; g[y][38] = "."; }
	});
	return { file: "Stage7.luau", rows };
}

function hospital() {
	const W = 45, H = 41;
	const rows = building(W, H, (g, slots, corr) => {
		const S = (k, side) => slots.find((s) => s.k === k && s.side === side);
		// 1동(외래·응급): 시작 = 응급 접수실
		const a = S(0, "up");
		cut(g, a, 1, 6, [3]);
		g[a.y0][1] = "S"; g[a.y0][2] = "S"; g[a.y0 + 1][1] = "S"; g[a.y0 + 1][2] = "S";
		g[a.y0][6] = "Z"; g[a.y0 + 2][5] = "R";
		lay(g, { ...a, xs: 8 }, [[5, "exam", [2]], [5, "exam", [2]], [5, "exam", [2]], [7, "pharmacy", [3]], [5, "exam", [2]], [6, "exam", [2]]]);
		lay(g, { ...S(0, "down"), xe: 34 }, [[8, "ward", [4]], [8, "ward", [4]], [6, "surgery", [2]], [8, "ward", [4]]]);
		lay(g, { ...S(0, "down"), xs: 39 }, [[2, "closet", [0]]]);
		// 2동(입원 병동): 병실이 양쪽으로 줄지어
		lay(g, { ...S(1, "up"), xe: 34 }, [[8, "ward", [4]], [8, "ward", [4]], [8, "ward", [4]], [8, "ward", [4]]]);
		lay(g, { ...S(1, "up"), xs: 39 }, [[2, "closet", [0]]]);
		lay(g, S(1, "down"), [[8, "ward", [4]], [8, "ward", [4]], [8, "ward", [4]], [8, "ward", [4]], [7, "ward", [3]]]);
		// 3동(수술·지하): 수술실, 영안실, 그리고 출구 쪽 큰 중앙 로비(기둥)
		lay(g, S(2, "up"), [[6, "surgery", [2]], [6, "surgery", [2]], [8, "morgue", [3]], [6, "exam", [2]]]);
		const lobbyTop = S(2, "up");
		cut(g, lobbyTop, 32, W - 2, [3, 8]);
		for (const x of [34, 38, 42]) g[lobbyTop.y0 + 1][x] = "O";
		g[lobbyTop.y0][W - 2] = "Z"; g[lobbyTop.y0][32] = "k";
		const d = S(2, "down");
		lay(g, d, [[8, "morgue", [3]], [6, "pharmacy", [2]], [8, "ward", [4]], [6, "exam", [2]], [7, "ward", [3]]]);
		// 간호사실: 각 동 복도 가운데가 넓어지며 가운데에 둥근 접수대(캐비닛 k)
		for (let k = 0; k < 3; k++) {
			const [y0, y1] = corr(k);
			const cx = k === 1 ? 20 : 22;
			g[y0][cx - 1] = "k"; g[y0][cx] = "k"; g[y0][cx + 1] = "k";
		}
		// 복도 벽의 들것·휠체어 자리 → 숨는 곳(복도에 놓인 낡은 옷장)
		for (const [k, xs] of [[0, [12, 33]], [1, [8, 33]], [2, [10, 27]]]) for (const x of xs) { const y = corr(k)[1]; if (g[y + 1][x] === "#" && g[y][x] === ".") g[y][x] = "L"; }
		// 비상계단(지름길): 1동 오른쪽에서 2동으로
		for (let y = corr(0)[1] + 1; y < corr(1)[0]; y++) { g[y][36] = "."; g[y][37] = "."; }
	});
	return { file: "Stage4.luau", rows };
}

// ── 물류 창고: 아주 큰 보관동 3개(긴 선반 줄)가 위아래로 쌓이고, 오른쪽·왼쪽 끝 하역문으로 번갈아 이어진다.
// 왼쪽 띠에 사무실·경비실·휴게실, 마지막 동 오른쪽은 컨테이너 하역장과 화물 출입구(출구) ──
function warehouse() {
	const W = 45, H = 41;
	const g = grid(W, H);
	const halls = [[1, 12], [14, 26], [28, 39]];
	for (const [y0, y1] of halls) room(g, 8, y0, 42, y1);
	// 하역문(넓은 틈): A→B 오른쪽, B→C 왼쪽
	for (const x of [39, 40, 41]) g[13][x] = ".";
	for (const x of [9, 10, 11]) g[27][x] = ".";
	// 긴 선반 줄(H): 각 동에 2칸 간격, 양 끝과 가운데 한두 곳은 가로 통로
	halls.forEach(([y0, y1], h) => {
		const cross = h === 1 ? [21, 30] : [17, 26, 34];
		for (let y = y0 + 2; y <= y1 - 2; y += 2) {
			for (let x = 11; x <= 39; x++) {
				if (cross.some((c) => Math.abs(c - x) <= 0) && ((y - y0) / 2 + h) % 2 === 0) continue;
				if (cross.includes(x)) continue;
				g[y][x] = "H";
			}
		}
	});
	// 마지막 동 오른쪽: 선반 대신 컨테이너 하역장
	for (let y = 29; y <= 38; y++) for (let x = 33; x <= 42; x++) if (g[y][x] === "H") g[y][x] = ".";
	for (const [x, y, ch] of [[34, 30, "K"], [35, 30, "K"], [38, 30, "Q"], [39, 30, "Q"], [34, 33, "Q"], [35, 33, "Q"], [38, 36, "K"], [39, 36, "K"], [34, 37, "K"], [35, 37, "K"], [41, 29, "c"], [42, 29, "c"]]) g[y][x] = ch;
	g[34][43] = "E";
	// 동마다 벽 쪽 상자·공구 캐비닛
	for (const [x, y, ch] of [[42, 1, "Z"], [8, 12, "Z"], [42, 12, "L"], [25, 1, "c"], [26, 1, "c"], [42, 14, "Z"], [8, 14, "L"], [8, 26, "c"], [42, 26, "Z"], [25, 26, "c"], [20, 39, "Z"], [8, 39, "L"], [42, 39, "L"], [28, 28, "c"], [29, 28, "c"]]) g[y][x] = ch;
	// 왼쪽 띠: 경비실(시작) · 사무실 · 탈의실 · 휴게실 · 자재실 · 관리실 — 각자 옆 동으로 문 하나
	const offices = [[1, 5, "start"], [7, 11, "office"], [15, 19, "locker"], [21, 25, "break"], [29, 33, "stock"], [35, 39, "office"]];
	for (const [y0, y1, kind] of offices) {
		room(g, 1, y0, 6, y1);
		g[y0 + 2][7] = "D";
		if (kind === "start") { g[1][1] = "S"; g[1][2] = "S"; g[2][1] = "S"; g[2][2] = "S"; g[5][6] = "Z"; g[5][1] = "T"; }
		if (kind === "office") { g[y0 + 1][2] = "T"; g[y0 + 1][4] = "T"; g[y0][1] = "Z"; g[y1][1] = "L"; }
		if (kind === "locker") { for (const x of [1, 3, 5]) g[y0][x] = "L"; g[y1][1] = "Z"; }
		if (kind === "break") { g[y0 + 2][3] = "T"; g[y0][1] = "c"; g[y1][6] = "Z"; }
		if (kind === "stock") { g[y0][1] = "c"; g[y0][2] = "c"; g[y1][1] = "c"; g[y1][6] = "Z"; g[y0][6] = "L"; }
	}
	return { file: "Stage2.luau", rows: g.map((r) => r.join("")) };
}

function hotel() {
	const W = 45, H = 43;
	fill.guest = (g, s, x0, x1) => {
		g[rowOf(s, 0)][x0 + 2] = "R"; // 침대(머리를 창가 벽에)
		g[rowOf(s, 1)][x0] = "L"; // 옷장
		g[rowOf(s, 0)][x1] = "Z"; // 서랍장
	};
	fill.linen = (g, s, x0, x1) => { g[rowOf(s, 0)][x0] = "c"; g[rowOf(s, 0)][x0 + 1] = "c"; g[rowOf(s, 0)][x1] = "L"; g[rowOf(s, 2)][x1] = "Z"; };
	const rows = building(W, H, (g, slots, corr) => {
		const S = (k, side) => slots.find((s) => s.k === k && s.side === side);
		const guests = (n) => Array.from({ length: n }, () => [5, "guest", [2]]);
		// 시작 = 2층 직원 사무실
		const a = S(0, "up");
		cut(g, a, 1, 5, [2]);
		g[a.y0][1] = "S"; g[a.y0][2] = "S"; g[a.y0 + 1][1] = "S"; g[a.y0 + 1][2] = "S"; g[a.y0][5] = "Z";
		lay(g, { ...a, xs: 7 }, [...guests(6), [4, "linen", [1]]]);
		lay(g, { ...S(0, "down"), xe: 35 }, guests(6));
		lay(g, { ...S(0, "down"), xs: 39 }, [[2, "linen", [0]]]);
		lay(g, { ...S(1, "up"), xe: 35 }, [[4, "linen", [1]], ...guests(5)]);
		lay(g, { ...S(1, "up"), xs: 39 }, [[2, "linen", [0]]]);
		lay(g, S(1, "down"), [...guests(6), [5, "linen", [2]]]);
		// 3동(1층): 연회장(기둥·원탁) · 주방 / 아래: 세탁실 · 프런트 로비(출구 쪽)
		const c = S(2, "up");
		cut(g, c, 4, 22, [3, 9, 15]);
		for (const x of [7, 12, 17]) { g[c.y0 + 1][x] = "T"; }
		for (const x of [5, 21]) g[c.y0][x] = "O";
		g[c.y0][13] = "Z"; g[c.y0 + 3][22] = "L";
		cut(g, c, 24, 31, [2]);
		g[c.y0][24] = "m"; g[c.y0][25] = "m"; g[c.y0][27] = "m"; g[c.y0 + 2][28] = "T"; g[c.y0][31] = "Z"; g[c.y0 + 3][31] = "c";
		lay(g, { ...c, xs: 33 }, guests(2));
		const d = S(2, "down");
		cut(g, d, 1, 9, [3, 7]);
		for (const x of [2, 4, 6]) g[d.y1][x] = "m";
		g[d.y0][1] = "c"; g[d.y0][2] = "c"; g[d.y1][9] = "Z"; g[d.y0][9] = "L";
		lay(g, { ...d, xs: 11 }, guests(3));
		cut(g, d, 28, W - 5, [3, 9]);
		for (const x of [30, 34, 38]) g[d.y0 + 2][x] = "O";
		for (const x of [31, 32, 33]) g[d.y1][x] = "k"; // 프런트 데스크
		g[d.y1][W - 5] = "Z"; g[d.y1][28] = "L";
		// 엘리베이터 홀: 각 동 복도 가운데 벽의 기둥 쌍
		for (let k = 0; k < 3; k++) { const y = corr(k)[1]; for (const x of [20, 24]) if (g[y + 1][x] === "#") g[y][x] = "O"; }
		// 비상계단(지름길): 1동 오른쪽에서 2동으로
		for (let y = corr(0)[1] + 1; y < corr(1)[0]; y++) { g[y][37] = "."; g[y][38] = "."; }
	});
	delete fill.guest; delete fill.linen;
	return { file: "Stage6.luau", rows };
}

const GEN = { sewer, school, hospital, warehouse, hotel };
const which = process.argv[2];
if (!GEN[which]) {
	console.log("usage: node tools/gen-themed.js <" + Object.keys(GEN).join("|") + "> [--dry]");
	process.exit(1);
}
const out = GEN[which]();
if (process.argv.includes("--dry")) {
	console.log(out.rows.join("\n"));
} else {
	const f = path.join(__dirname, "..", "src", "server", "Stages", out.file);
	const src = fs.readFileSync(f, "utf8").replace(/\r\n/g, "\n");
	const body = out.rows.map((r) => `\t\t"${r}",`).join("\n");
	const next = src.replace(/(\tRows = \{\n)([\s\S]*?)(\n\t\},)/, (_, a, _b, c) => a + body + c);
	fs.writeFileSync(f, next);
	console.log(out.rows.join("\n"));
}
