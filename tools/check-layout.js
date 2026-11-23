// Checks stage layouts (src/server/Stages/StageN.luau) before building them in Studio:
// row lengths, door/arch tiles sit between two walls, exit has one entrance, stairs have one upper neighbour,
// start -> exit is reachable for players and for the monster (which cannot cross narrow bridges 'n').
//   node tools/check-layout.js            (all stages)
const fs = require("fs");
const path = require("path");
const dir = path.join(__dirname, "..", "src", "server", "Stages");
let failed = false;
for (const file of fs.readdirSync(dir).filter((f) => /^Stage\d+\.luau$/.test(f)).sort()) {
	const src = fs.readFileSync(path.join(dir, file), "utf8");
	const rows = [...src.matchAll(/^\s*"([^"]+)",\s*$/gm)].map((m) => m[1]);
	const pitExtra = ((src.match(/PitTiles = \{([^}]*)\}/) || ["", ""])[1].match(/(\w) = true/g) || []).map((x) => x[0]);
	const pits = new Set(["p", "b", "s", "n", ...pitExtra]);
	const blocked = new Set(["#", "K", "Q", "m", "O", "B", "T", "X", "L", "Z"]); // (선반 H/h 는 양옆 통로로 지나간다)
	const H = rows.length, W = rows[0].length;
	// 2층 구역(UpperRects, 1부터) → 0부터
	const upperRects = [...((src.match(/UpperRects = \{(.*)\},/) || ["", ""])[1].matchAll(/\{\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)\s*\}/g))].map((m) => m.slice(1, 5).map((v) => +v - 1));
	const isUp = (i, j) => upperRects.some(([a, b, c, d]) => i >= a && i <= c && j >= b && j <= d);
	const bad = [];
	rows.forEach((r, j) => r.length !== W && bad.push(`row${j} length ${r.length}`));
	const at = (i, j) => (j < 0 || j >= H || i < 0 || i >= W ? "#" : rows[j][i] || "#");
	const wall = (i, j) => at(i, j) === "#";
	const D4 = [[1, 0], [-1, 0], [0, 1], [0, -1]];
	for (let j = 0; j < H; j++)
		for (let i = 0; i < W; i++) {
			const c = at(i, j);
			if (c === "D" || c === "A") {
				const wx = wall(i - 1, j) && wall(i + 1, j), wz = wall(i, j - 1) && wall(i, j + 1);
				const ox = !wall(i - 1, j) && !wall(i + 1, j), oz = !wall(i, j - 1) && !wall(i, j + 1);
				if (!((wx && oz) || (wz && ox))) bad.push(`${c} not between two walls at r${j}c${i}`);
			}
			if (c === "E") {
				const n = D4.filter(([a, b]) => !wall(i + a, j + b)).length;
				if (n !== 1) bad.push(`exit has ${n} entrances`);
			}
			if (c === "1" || c === "2") {
				// 2층 계단: 1 은 2 와 1층 칸 사이, 2 는 1 과 2층 칸 사이(일직선), 옆은 벽
				const other = c === "1" ? "2" : "1";
				const d = D4.find(([a, b]) => at(i + a, j + b) === other);
				if (!d) bad.push(`flight ${c} r${j}c${i} has no ${other}`);
				else {
					const fi = i - d[0], fj = j - d[1], f = at(fi, fj);
					const okEnd = f !== "#" && f !== "1" && f !== "2" && (c === "1" ? !isUp(fi, fj) : isUp(fi, fj));
					if (!okEnd) bad.push(`flight ${c} r${j}c${i} has no ${c === "1" ? "ground" : "upper"} floor at its end`);
					if (!wall(i + d[1], j + d[0]) || !wall(i - d[1], j - d[0])) bad.push(`flight ${c} r${j}c${i} sides not walls`);
				}
				if (c === "1" && isUp(i, j)) bad.push(`flight 1 r${j}c${i} inside upper rect`);
			}
			if (c !== "#" && c !== "1" && c !== "2" && !isUp(i, j))
				for (const [a, b] of D4) { const n = at(i + a, j + b); if (n !== "#" && n !== "1" && n !== "2" && isUp(i + a, j + b)) bad.push(`cliff between r${j}c${i} and r${j + b}c${i + a}`); }
			if (c === "S" && isUp(i, j)) bad.push("start on upper floor");
			if (c === "s") {
				const ups = D4.filter(([a, b]) => { const n = at(i + a, j + b); return n !== "#" && !pits.has(n); }).length;
				if (ups !== 1) bad.push(`stairs r${j}c${i} has ${ups} upper neighbours`);
			}
		}
	const lv0 = (c) => (pits.has(c) ? (c === "b" || c === "n" ? [0] : c === "s" ? [0, 1] : [1]) : [0]);
	const lvAt = (i, j) => { const c = at(i, j); if (c === "1") return [0]; if (c === "2" || isUp(i, j)) return [2]; return lv0(c); };
	// 다음 칸의 층(계단 1 ↔ 2 를 건너면 층이 바뀐다)
	const nextL = (i, j, ni, nj, l) => { const a = at(i, j), b = at(ni, nj); return (a === "1" && b === "2") || (a === "2" && b === "1") ? lvAt(ni, nj)[0] : l; };
	const pass = (c, agent) => !blocked.has(c) && !(agent === "monster" && c === "n");
	const bfs = (agent) => {
		let S = null, E = null;
		for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) { if (at(i, j) === "S" && !S) S = [i, j]; if (at(i, j) === "E") E = [i, j]; }
		const seen = new Map([[`${S[0]},${S[1]},0`, 0]]);
		const q = [[S[0], S[1], 0]];
		while (q.length) {
			const [i, j, l] = q.shift();
			const d = seen.get(`${i},${j},${l}`);
			if (at(i, j) === "s") for (const L of [0, 1]) if (!seen.has(`${i},${j},${L}`)) { seen.set(`${i},${j},${L}`, d); q.push([i, j, L]); }
			for (const [a, b] of D4) {
				const ni = i + a, nj = j + b, c = at(ni, nj);
				const nl = nextL(i, j, ni, nj, l);
				if (!pass(c, agent) || !lvAt(ni, nj).includes(nl)) continue;
				const k = `${ni},${nj},${nl}`;
				if (!seen.has(k)) { seen.set(k, d + 1); q.push([ni, nj, nl]); }
			}
		}
		return { exit: seen.get(`${E[0]},${E[1]},0`), seen };
	};
	const p = bfs("player"), m = bfs("monster");
	const un = [];
	for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) { const c = at(i, j); if (pass(c, "player") && c !== "#" && !lvAt(i, j).some((l) => p.seen.has(`${i},${j},${l}`))) un.push(`r${j}c${i}${c}`); }
	if (p.exit === undefined) bad.push("exit unreachable");
	// ── 엄격한 검사: 모르는 문자, 바깥 테두리, 소품을 전부 막힌 것으로 쳐도 모든 바닥에 갈 수 있는가, 숨는 곳·열쇠 상자 앞에 설 수 있는가 ──
	const propKeys = ((src.match(/Props = \{([^}]*)\}/) || ["", ""])[1].match(/(\w) = /g) || []).map((x) => x[0]);
	const walkKeys = ((src.match(/Walkable = \{([^}]*)\}/) || ["", ""])[1].match(/(\w) = true/g) || []).map((x) => x[0]);
	const known = new Set(["#", ".", "S", "E", "D", "A", "p", "b", "n", "s", "1", "2", "O", "c", "m", "v", "f", "L", "Z", ...pitExtra, ...propKeys]);
	const unknown = new Set();
	for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) if (!known.has(at(i, j))) unknown.add(at(i, j));
	if (unknown.size) bad.push("unknown tiles " + [...unknown].join(""));
	for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) if ((i === 0 || j === 0 || i === W - 1 || j === H - 1) && at(i, j) !== "#") bad.push(`border open r${j}c${i}`);
	const OPEN = new Set([".", "S", "E", "D", "A", "f", "p", "b", "n", "s", "1", "2", ...pitExtra, ...walkKeys]);
	const strict = (() => {
		let S = null;
		for (let j = 0; j < H && !S; j++) for (let i = 0; i < W; i++) if (at(i, j) === "S") { S = [i, j]; break; }
		const seen = new Set([`${S[0]},${S[1]},0`]);
		const q = [[S[0], S[1], 0]];
		for (let h = 0; h < q.length; h++) {
			const [i, j, l] = q[h];
			if (at(i, j) === "s") for (const L of [0, 1]) if (!seen.has(`${i},${j},${L}`)) { seen.add(`${i},${j},${L}`); q.push([i, j, L]); }
			for (const [a, b] of D4) {
				const ni = i + a, nj = j + b, c = at(ni, nj);
				const nl = nextL(i, j, ni, nj, l);
				if (!OPEN.has(c) || !lvAt(ni, nj).includes(nl)) continue;
				const k = `${ni},${nj},${nl}`;
				if (!seen.has(k)) { seen.add(k); q.push([ni, nj, nl]); }
			}
		}
		return seen;
	})();
	const reachable = (i, j) => lvAt(i, j).some((l) => strict.has(`${i},${j},${l}`));
	const cut = [];
	for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) if ([".", "D", "A", "E", "S"].includes(at(i, j)) && !reachable(i, j)) cut.push(`r${j}c${i}${at(i, j)}`);
	if (cut.length) bad.push("floor cut off by props/walls: " + cut.slice(0, 8).join(" "));
	// 숨는 곳·열쇠 상자: StageBuilder 처럼 등질 벽을 고르고, 그 앞 칸에 설 수 있어야 한다
	const noFront = [];
	for (let j = 0; j < H; j++)
		for (let i = 0; i < W; i++) {
			const c = at(i, j);
			if (c !== "L" && c !== "Z") continue;
			const d = D4.find(([a, b]) => wall(i + a, j + b) && !wall(i - a, j - b));
			const fi = d ? i - d[0] : -1, fj = d ? j - d[1] : -1;
			if (!d || !OPEN.has(at(fi, fj)) || !reachable(fi, fj)) noFront.push(`${c}@r${j}c${i}`);
		}
	if (noFront.length) bad.push("hide/search spot without a reachable front: " + noFront.join(" "));
	if (bad.length) failed = true;
	console.log(`${file} ${W}x${H}${upperRects.length ? " (2층 " + upperRects.length + "구역)" : ""} | exit: player ${p.exit} tiles, monster ${m.exit ?? "no path"} | ${bad.join("; ") || "ok"}${un.length ? " | unreachable " + un.join(" ") : ""}`);
}
process.exit(failed ? 1 : 0);
