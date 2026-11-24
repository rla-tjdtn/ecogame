// Checks stage layouts (src/server/Stages/StageN.luau) before building them in Studio:
// row lengths, door/arch tiles sit between two walls, exit has one entrance, stairs rules, border, unknown tiles,
// every floor tile reachable with props counted as blocked, hide/search spots have a reachable front, start area has 2+ ways out,
// start -> exit reachable for players and for the monster (which cannot cross narrow bridges 'n').
// 2층: 겹쳐 쌓은 2층(Rows2, 1층과 같은 크기)과 옛 방식(UpperRects) 모두.
//   node tools/check-layout.js            (all stages)        STAGES_DIR=... 로 다른 폴더
const { loadStage, stageIds } = require("./stage-file");
const { buildGraph, bfs, cellDist } = require("./level-graph");
const D4 = [[1, 0], [-1, 0], [0, 1], [0, -1]];
let failed = false;
for (const id of stageIds()) {
	const st = loadStage(id);
	const { rows, rows2, upper, pits } = st;
	const H = rows.length, W = rows[0].length;
	const bad = [];
	const isUp = (i, j) => upper.some(([a, b, c, d]) => i >= a && i <= c && j >= b && j <= d);
	const floors = rows2 ? [rows, rows2] : [rows];
	if (rows2 && (rows2.length !== H || rows2.some((r) => r.length !== W))) bad.push("Rows2 size differs from Rows");
	floors.forEach((rs, f) => rs.forEach((r, j) => r.length !== W && bad.push(`${f ? "2F " : ""}row${j} length ${r.length}`)));
	const known = new Set(["#", ".", "S", "E", "D", "A", "p", "b", "n", "s", "1", "2", "O", "c", "m", "v", "f", "L", "Z", ...st.pitExtra, ...st.props]);
	floors.forEach((rs, f) => {
		const tag = f ? "2F " : "";
		const at = (i, j) => (j < 0 || j >= H || i < 0 || i >= W ? "#" : rs[j][i] || "#");
		const wall = (i, j) => at(i, j) === "#";
		const unknown = new Set();
		for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) {
			const c = at(i, j);
			if (!(known.has(c) || (f === 1 && c === "o"))) unknown.add(c);
			if ((i === 0 || j === 0 || i === W - 1 || j === H - 1) && c !== "#") bad.push(`${tag}border open r${j}c${i}`);
			if (c === "D" || c === "A") {
				const wx = wall(i - 1, j) && wall(i + 1, j), wz = wall(i, j - 1) && wall(i, j + 1);
				const ox = !wall(i - 1, j) && !wall(i + 1, j), oz = !wall(i, j - 1) && !wall(i, j + 1);
				if (!((wx && oz) || (wz && ox))) bad.push(`${tag}${c} not between two walls at r${j}c${i}`);
			}
			if (c === "E" && D4.filter(([a, b]) => !wall(i + a, j + b)).length !== 1) bad.push(`${tag}exit has ${D4.filter(([a, b]) => !wall(i + a, j + b)).length} entrances`);
			if (c === "S" && (f === 1 || isUp(i, j))) bad.push("start on upper floor");
			if (f === 1 && (pits.has(c) || c === "1" || c === "2")) bad.push(`2F has ${c} at r${j}c${i} (pits/stairs belong to 1F)`);
			if (c === "s") {
				const ups = D4.filter(([a, b]) => { const n = at(i + a, j + b); return n !== "#" && !pits.has(n); }).length;
				if (ups !== 1) bad.push(`stairs r${j}c${i} has ${ups} upper neighbours`);
			}
			if (f === 0 && (c === "1" || c === "2")) {
				const other = c === "1" ? "2" : "1";
				const d = D4.find(([a, b]) => at(i + a, j + b) === other);
				if (!d) { bad.push(`flight ${c} r${j}c${i} has no ${other}`); continue; }
				if (!wall(i + d[1], j + d[0]) || !wall(i - d[1], j - d[0])) bad.push(`flight ${c} r${j}c${i} sides not walls`);
				const fi = i - d[0], fj = j - d[1]; // 계단 끝 칸
				if (rows2) {
					if (rows2[j][i] !== "o") bad.push(`flight ${c} r${j}c${i}: 2F above must be o`);
					if (c === "1" && (wall(fi, fj) || at(fi, fj) === "2")) bad.push(`flight 1 r${j}c${i} has no ground floor at its end`);
					if (c === "2") {
						const u = fj >= 0 && fj < H && fi >= 0 && fi < W ? rows2[fj][fi] : "#";
						if (u === "#" || u === "o") bad.push(`flight 2 r${j}c${i} has no 2F landing`);
						if (!wall(fi, fj)) bad.push(`flight 2 r${j}c${i}: 1F tile past the top must be wall`);
					}
				} else {
					const f2 = at(fi, fj);
					const okEnd = f2 !== "#" && f2 !== "1" && f2 !== "2" && (c === "1" ? !isUp(fi, fj) : isUp(fi, fj));
					if (!okEnd) bad.push(`flight ${c} r${j}c${i} has no ${c === "1" ? "ground" : "upper"} floor at its end`);
					if (c === "1" && isUp(i, j)) bad.push(`flight 1 r${j}c${i} inside upper rect`);
				}
			}
			if (f === 1 && c === "o" && !"12".includes(rows[j][i])) bad.push(`2F hole o at r${j}c${i} without stairs below`);
			if (!rows2 && c !== "#" && c !== "1" && c !== "2" && !isUp(i, j))
				for (const [a, b] of D4) { const n = at(i + a, j + b); if (n !== "#" && n !== "1" && n !== "2" && isUp(i + a, j + b)) bad.push(`cliff between r${j}c${i} and r${j + b}c${i + a}`); }
		}
		if (unknown.size) bad.push(`${tag}unknown tiles ${[...unknown].join("")}`);
	});
	// 길: level-graph 와 같은 그래프(소품은 막힘, 벽에 붙은 상자 c·배관 v 는 지나감)
	const G = buildGraph(st);
	const sN = G.S.map(([i, j, f]) => G.node(i, j, f));
	if (!sN.length) bad.push("no start");
	const dP = bfs(G, G.adjP, sN, null), dM = bfs(G, G.adjM, sN, null);
	const eN = G.E ? G.node(G.E[0], G.E[1], G.E[2]) : -1;
	const pExit = eN >= 0 ? dP[eN] : -1, mExit = eN >= 0 ? dM[eN] : -1;
	if (pExit < 0) bad.push("exit unreachable");
	const cut = [];
	for (let c = 0; c < 2 * G.A; c++) {
		const [i, j, f] = G.xyf(c);
		if (!G.exists(f, i, j)) continue;
		if ([".", "D", "A", "E", "S"].includes(G.ch(f, i, j)) && cellDist(dP, c) < 0) cut.push(G.label(c));
	}
	if (cut.length) bad.push("floor cut off by props/walls: " + cut.slice(0, 8).join(" "));
	// 숨는 곳·열쇠 상자: 등질 벽을 고르고, 그 앞 칸에 설 수 있어야 한다
	const noFront = [];
	floors.forEach((rs, f) => {
		const at = (i, j) => (j < 0 || j >= H || i < 0 || i >= W ? "#" : rs[j][i]);
		for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) {
			const c = at(i, j);
			if (c !== "L" && c !== "Z") continue;
			const d = D4.find(([a, b]) => at(i + a, j + b) === "#" && at(i - a, j - b) !== "#");
			const ff = rows2 ? f : isUp(i, j) ? 1 : 0;
			if (!d || cellDist(dP, G.cell(ff, i - d[0], j - d[1])) < 0) noFront.push(`${f ? "2F " : ""}${c}@r${j}c${i}`);
		}
	});
	if (noFront.length) bad.push("hide/search spot without a reachable front: " + noFront.join(" "));
	// 시작 구역에서 나가는 길이 둘 이상: 시작 방 밖(시작 칸에서 3칸 이상) 30칸 안의 어느 3x3 을 막아도 출구로 갈 수 있다
	if (pExit >= 0) {
		const prot = new Uint8Array(2 * G.A);
		for (let c = 0; c < 2 * G.A; c++) { const d = cellDist(dP, c); if (d >= 0 && d <= 2) prot[c] = 1; }
		for (let c = 0; c < 2 * G.A; c++) {
			const d = cellDist(dP, c);
			if (d < 3 || d > 30) continue;
			const m = new Uint8Array(2 * G.A);
			const [i, j, f] = G.xyf(c);
			for (let a = -1; a <= 1; a++) for (let b = -1; b <= 1; b++) if (i + a >= 0 && j + b >= 0 && i + a < W && j + b < H) { const k = G.cell(f, i + a, j + b); if (!prot[k]) m[k] = 1; }
			if (bfs(G, G.adjP, sN, m)[eN] < 0) { bad.push(`start area has a single way out near ${G.label(c)}`); break; }
		}
	}
	if (bad.length) failed = true;
	console.log(`Stage${id}.luau ${W}x${H}${rows2 ? " (2층 겹침)" : upper.length ? " (2층 " + upper.length + "구역)" : ""} | exit: player ${pExit} tiles, monster ${mExit < 0 ? "no path" : mExit} | ${bad.join("; ") || "ok"}`);
}
process.exit(failed ? 1 : 0);
