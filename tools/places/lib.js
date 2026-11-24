// 장소 맵 생성 도구 모음(챕터 생성기 tools/places/*.js 가 같이 쓴다).
// 1칸 = 8스터드. 문자는 StageBuilder 와 같다. 2층은 같은 격자의 다른 구역(UpperRects)에 높게 짓고,
// 1층 ↔ 2층은 계단 두 칸 "1"(1층 쪽) "2"(2층 쪽)로 오간다. 좌표는 0부터(x = 열, y = 행).
const fs = require("fs");
const path = require("path");

const D4 = [[1, 0], [-1, 0], [0, 1], [0, -1]];
// 지나갈 수 없는 칸(tools/check-layout.js 와 같은 규칙). 스테이지별 소품은 analyze 의 blocked 로 더 넘긴다
const BLOCKED = new Set(["#", "K", "Q", "m", "O", "B", "T", "X", "L", "Z"]);

class Grid {
	constructor(W, H) {
		this.W = W;
		this.H = H;
		this.g = Array.from({ length: H }, () => Array(W).fill("#"));
		this.upper = []; // [x0, y0, x1, y1] (0부터)
	}
	in(x, y) { return x > 0 && y > 0 && x < this.W - 1 && y < this.H - 1; }
	get(x, y) { return x < 0 || y < 0 || x >= this.W || y >= this.H ? "#" : this.g[y][x]; }
	set(x, y, ch) { if (this.in(x, y)) this.g[y][x] = ch; return this; }
	// 바닥으로 파기(테두리는 늘 벽)
	fill(x0, y0, x1, y1, ch = ".") {
		for (let y = Math.min(y0, y1); y <= Math.max(y0, y1); y++) for (let x = Math.min(x0, x1); x <= Math.max(x0, x1); x++) this.set(x, y, ch);
		return this;
	}
	wall(x0, y0, x1, y1) { return this.fill(x0, y0, x1, y1, "#"); }
	// 여러 칸에 한 문자: [[x, y], ...]
	put(ch, pts) { for (const [x, y] of pts) this.set(x, y, ch); return this; }
	// 빈 바닥(.)일 때만 놓기
	soft(x, y, ch) { if (this.get(x, y) === ".") this.set(x, y, ch); return this; }
	markUpper(x0, y0, x1, y1) { this.upper.push([x0, y0, x1, y1]); return this; }
	isUpper(x, y) { return this.upper.some(([a, b, c, d]) => x >= a && x <= c && y >= b && y <= d); }
	// 계단: (x, y) 가 1층 쪽 끝 칸 "1", 방향 (dx, dy) 로 한 칸 더 가면 "2", 그다음 칸이 2층
	// 겹쳐 쌓은 2층(floor2)이 있으면 2층 격자의 그 두 칸은 계단 구멍 "o", 그다음 칸(도착 칸)은 바닥으로 판다
	stairs(x, y, dx, dy) {
		this.set(x, y, "1");
		this.set(x + dx, y + dy, "2");
		if (this.up) {
			this.up.set(x, y, "o").set(x + dx, y + dy, "o");
			if (this.up.get(x + 2 * dx, y + 2 * dy) === "#") this.up.set(x + 2 * dx, y + 2 * dy, ".");
			this.set(x + 2 * dx, y + 2 * dy, "#"); // (1층에서 계단 꼭대기 앞은 벽: 계단 아래로 들어가지 못하게)
		}
		return this;
	}
	// 겹쳐 쌓은 2층: 1층과 같은 크기의 격자(스테이지 파일 Rows2). 처음 부르면 만든다
	floor2() {
		if (!this.up) { this.up = new Grid(this.W, this.H); this.up.lower = this; }
		return this.up;
	}
	rows() { return this.g.map((r) => r.join("")); }
}

// ── 분석: 층, 길찾기, 막힌 길, 넓은 공간 ──
function levelsOf(rows, upper, x, y, pits) {
	const c = rows[y][x];
	if (c === "1") return [0];
	if (c === "2") return [2];
	if (upper.some(([a, b, cc, d]) => x >= a && x <= cc && y >= b && y <= d)) return [2];
	if (pits.has(c)) return c === "b" || c === "n" ? [0] : c === "s" ? [0, 1] : [1];
	return [0];
}

function analyze(rows, upper, opts = {}) {
	const H = rows.length, W = rows[0].length;
	const pits = new Set(["p", "b", "s", "n", ...(opts.pits || [])]);
	const blocked = new Set([...BLOCKED, ...(opts.blocked || [])]);
	for (const k of opts.walkable || []) blocked.delete(k);
	const at = (x, y) => (x < 0 || y < 0 || x >= W || y >= H ? "#" : rows[y][x]);
	const lv = (x, y) => levelsOf(rows, upper, x, y, pits);
	const pass = (x, y) => !blocked.has(at(x, y));
	let S = null, E = null;
	for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { if (at(x, y) === "S" && !S) S = [x, y]; if (at(x, y) === "E") E = [x, y]; }
	const bfs = (skip) => {
		const dist = new Map([[`${S[0]},${S[1]},0`, 0]]);
		const q = [[S[0], S[1], 0]];
		for (let h = 0; h < q.length; h++) {
			const [x, y, l] = q[h];
			const d = dist.get(`${x},${y},${l}`);
			if (at(x, y) === "s") for (const L of [0, 1]) if (!dist.has(`${x},${y},${L}`)) { dist.set(`${x},${y},${L}`, d); q.push([x, y, L]); }
			for (const [a, b] of D4) {
				const nx = x + a, ny = y + b;
				if (!pass(nx, ny) || (skip && skip(nx, ny))) continue;
				let nl = l;
				const here = at(x, y), there = at(nx, ny);
				if ((here === "1" && there === "2") || (here === "2" && there === "1")) nl = lv(nx, ny)[0];
				if (!lv(nx, ny).includes(nl)) continue;
				const k = `${nx},${ny},${nl}`;
				if (!dist.has(k)) { dist.set(k, d + 1); q.push([nx, ny, nl]); }
			}
		}
		return dist;
	};
	const dist = bfs();
	const exitD = dist.get(`${E[0]},${E[1]},0`);
	// 최단 경로 되짚기
	const pathTiles = [];
	if (exitD !== undefined) {
		let cur = [E[0], E[1], 0], d = exitD;
		while (d > 0) {
			pathTiles.push(cur);
			const [x, y, l] = cur;
			let next = null;
			for (const [a, b] of D4) for (const L of [0, 1, 2]) if (dist.get(`${x + a},${y + b},${L}`) === d - 1) next = [x + a, y + b, L];
			if (!next) break;
			cur = next; d--;
		}
	}
	// 꼭 지나야 하는 칸(이 칸을 막으면 출구로 못 간다): 한 방향 길의 길이를 잰다
	let choke = 0;
	for (const [x, y] of pathTiles.slice(1)) {
		const dd = bfs((a, b) => a === x && b === y);
		if (dd.get(`${E[0]},${E[1]},0`) === undefined) choke++;
	}
	// 갈 수 있는 바닥 중 못 가는 칸
	const un = [];
	for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (pass(x, y) && at(x, y) !== "#" && !lv(x, y).some((l) => dist.has(`${x},${y},${l}`))) un.push(`${x},${y}${at(x, y)}`);
	// 가장 넓은 열린 정사각형(벽만 막힌 것으로): 음파 한 번에 다 보이는지 가늠
	const sq = Array.from({ length: H }, () => Array(W).fill(0));
	let maxSq = 0, maxAt = null;
	for (let y = 1; y < H; y++) for (let x = 1; x < W; x++) {
		if (at(x, y) === "#" || at(x, y) === "D") continue;
		sq[y][x] = 1 + Math.min(sq[y - 1][x], sq[y][x - 1], sq[y - 1][x - 1]);
		if (sq[y][x] > maxSq) { maxSq = sq[y][x]; maxAt = [x, y]; }
	}
	// 막다른 칸 수(바닥 이웃 1개)
	let dead = 0;
	for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (pass(x, y) && at(x, y) !== "#" && D4.filter(([a, b]) => pass(x + a, y + b)).length === 1) dead++;
	return { exit: exitD, choke, pathLen: pathTiles.length, unreachable: un, maxSquare: maxSq, maxSquareAt: maxAt, deadEnds: dead };
}

// 스테이지 파일의 Rows(와 UpperRects)를 바꿔 쓴다. 좌표는 StageBuilder 처럼 1부터로 바꿔 적는다
function writeStage(file, grid, headerLines) {
	const f = path.join(__dirname, "..", "..", "src", "server", "Stages", file);
	const raw = fs.readFileSync(f, "utf8");
	const crlf = raw.includes("\r\n");
	let src = raw.replace(/\r\n/g, "\n");
	const body = grid.rows().map((r) => `\t\t"${r}",`).join("\n");
	src = src.replace(/(\tRows = \{\n)([\s\S]*?)(\n\t\},)/, (_, a, _b, c) => a + body + c);
	src = src.replace(/\tUpperRects = [^\n]*\n/g, "");
	src = src.replace(/\tRows2 = \{[^\n]*\n[\s\S]*?\n\t\},\n/, "");
	if (grid.up) {
		const body2 = grid.up.rows().map((r) => `\t\t"${r}",`).join("\n");
		src = src.replace(/(\tRows = \{\n[\s\S]*?\n\t\},\n)/, (m) => m + `\tRows2 = { -- 2층(1층 위에 같은 크기로 겹쳐 쌓는다. o = 계단 구멍)\n${body2}\n\t},\n`);
	}
	if (grid.upper.length) {
		const ur = grid.upper.map(([a, b, c, d]) => `{ ${a + 1}, ${b + 1}, ${c + 1}, ${d + 1} }`).join(", ");
		src = src.replace(/(\tRows = \{\n)/, `\tUpperRects = { ${ur} }, -- 2층 구역(타일 좌표 i0, j0, i1, j1)\n$1`);
	}
	if (headerLines) {
		// 맨 위 주석 덩어리(--!strict 다음 줄부터 첫 local/return 전까지)를 바꾼다
		src = src.replace(/^(--!strict\n)((?:--[^\n]*\n)*)/, (_, a) => a + headerLines.map((l) => `-- ${l}`).join("\n") + "\n");
	}
	const out = process.env.STAGE_OUT_DIR ? path.join(process.env.STAGE_OUT_DIR, file) : f; // (STAGE_OUT_DIR: 다른 폴더에 써서 시험)
	fs.writeFileSync(out, crlf ? src.replace(/\n/g, "\r\n") : src);
	return out;
}

function report(name, grid, opts) {
	if (grid.up) {
		// 겹쳐 쌓은 2층: 그래프 검사기(level-graph)로 잰다
		const { analyzeStage } = require("../level-graph");
		const st = { rows: grid.rows(), rows2: grid.up.rows(), upper: [], pits: new Set(["p", "b", "s", "n", ...((opts && opts.pits) || [])]), walk: (opts && opts.walkable) || [] };
		const R = analyzeStage((opts && opts.id) || 0, { st, quick: true });
		console.log(`${name}: ${grid.W}x${grid.H} 2층 | 출구까지 ${R.exitLen} 칸 | 목 ${R.chokes.length} | 끊는 데 괴물 ${R.minCutSE.k >= 3 ? "3+" : R.minCutSE.k} | Z ${R.searchSpots}${R.fails.length ? " | " + R.fails.slice(0, 3).join("; ") : ""}`);
		return { exit: R.exitLen, choke: R.chokes.length };
	}
	const r = analyze(grid.rows(), grid.upper, opts);
	console.log(`${name}: ${grid.W}x${grid.H} | 출구까지 ${r.exit} 칸 | 꼭 지나는 칸 ${r.choke} | 가장 넓은 정사각형 ${r.maxSquare} (${r.maxSquareAt}) | 막다른 칸 ${r.deadEnds}${r.unreachable.length ? " | 못 가는 칸 " + r.unreachable.slice(0, 10).join(" ") : ""}`);
	return r;
}

module.exports = { Grid, analyze, writeStage, report, D4 };
