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
	const blocked = new Set(["#", "K", "Q", "m", "O", "B", "T", "X"]); // (선반 H/h 는 양옆 통로로 지나간다)
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
	if (bad.length) failed = true;
	console.log(`${file} ${W}x${H} | exit: player ${p.exit} tiles, monster ${m.exit ?? "no path"} | ${bad.join("; ") || "ok"}${un.length ? " | unreachable " + un.join(" ") : ""}`);
}
process.exit(failed ? 1 : 0);
