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

const GEN = { sewer };
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
