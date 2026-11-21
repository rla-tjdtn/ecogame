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
			if (c === "s") {
				const ups = D4.filter(([a, b]) => { const n = at(i + a, j + b); return n !== "#" && !pits.has(n); }).length;
				if (ups !== 1) bad.push(`stairs r${j}c${i} has ${ups} upper neighbours`);
			}
		}
	const lv = (c) => (pits.has(c) ? (c === "b" || c === "n" ? [0] : c === "s" ? [0, 1] : [1]) : [0]);
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
				if (!pass(c, agent) || !lv(c).includes(l)) continue;
				const k = `${ni},${nj},${l}`;
				if (!seen.has(k)) { seen.set(k, d + 1); q.push([ni, nj, l]); }
			}
		}
		return { exit: seen.get(`${E[0]},${E[1]},0`), seen };
	};
	const p = bfs("player"), m = bfs("monster");
	const un = [];
	for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) { const c = at(i, j); if (pass(c, "player") && !lv(c).some((l) => p.seen.has(`${i},${j},${l}`))) un.push(`r${j}c${i}${c}`); }
	if (p.exit === undefined) bad.push("exit unreachable");
	// ── 엄격한 검사: 모르는 문자, 바깥 테두리, 소품을 전부 막힌 것으로 쳐도 모든 바닥에 갈 수 있는가, 숨는 곳·열쇠 상자 앞에 설 수 있는가 ──
	const propKeys = ((src.match(/Props = \{([^}]*)\}/) || ["", ""])[1].match(/(\w) = /g) || []).map((x) => x[0]);
	const walkKeys = ((src.match(/Walkable = \{([^}]*)\}/) || ["", ""])[1].match(/(\w) = true/g) || []).map((x) => x[0]);
	const known = new Set(["#", ".", "S", "E", "D", "A", "p", "b", "n", "s", "O", "c", "m", "v", "f", "L", "Z", ...pitExtra, ...propKeys]);
	const unknown = new Set();
	for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) if (!known.has(at(i, j))) unknown.add(at(i, j));
	if (unknown.size) bad.push("unknown tiles " + [...unknown].join(""));
	for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) if ((i === 0 || j === 0 || i === W - 1 || j === H - 1) && at(i, j) !== "#") bad.push(`border open r${j}c${i}`);
	const OPEN = new Set([".", "S", "E", "D", "A", "f", "p", "b", "n", "s", ...pitExtra, ...walkKeys]);
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
				if (!OPEN.has(c) || !lv(c).includes(l)) continue;
				const k = `${ni},${nj},${l}`;
				if (!seen.has(k)) { seen.add(k); q.push([ni, nj, l]); }
			}
		}
		return seen;
	})();
	const reachable = (i, j) => lv(at(i, j)).some((l) => strict.has(`${i},${j},${l}`));
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
	console.log(`${file} ${W}x${H} | exit: player ${p.exit} tiles, monster ${m.exit ?? "no path"} | ${bad.join("; ") || "ok"}${un.length ? " | unreachable " + un.join(" ") : ""}`);
}
process.exit(failed ? 1 : 0);
