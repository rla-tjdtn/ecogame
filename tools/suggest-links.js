// 그래프 검사(level-graph)에 걸린 목·괴물 둘로 끊기는 자리를 메울 문(D) 후보를 찾고, 하나씩 더해 가며 다시 잰다.
//   node tools/suggest-links.js 1 [--min 120] [--max 8] [--avoid x0,y0,x1,y1 ...]      (STAGES_DIR 로 다른 폴더)
// 후보: 같은 층에서 양옆이 벽이고 앞뒤가 같은 높이 바닥인 벽 1칸(문) 또는 2칸(문 + 바닥). 끊긴 쪽과 갈 수 있는 쪽을 잇는 것만.
// 고르는 기준: 고쳐지는가 → 가장 짧은 길이 --min 아래로 줄지 않는가 → 덜 줄어드는 것. (길을 너무 많이 만들지 않게 꼭 필요한 만큼만 더한다)
// 결과는 생성기에 옮겨 적을 g.set(...) 줄로 출력한다(파일은 바꾸지 않는다).
const { loadStage, analyzeStage, bfs, cellDist, square } = require("./level-graph");
const args = process.argv.slice(2);
const id = +args[0];
const opt = (k, d) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : d; };
const MIN = +opt("--min", 118), MAX = +opt("--max", 8);
const avoid = []; args.forEach((a, i) => { if (a === "--avoid") avoid.push(args[i + 1].split(",").map(Number)); });
const st = loadStage(id);
const added = [];
const setCh = (rows, x, y, c) => { rows[y] = rows[y].slice(0, x) + c + rows[y].slice(x + 1); };
for (let round = 0; round < MAX; round++) {
	const R = analyzeStage(id, { st, quick: true });
	const G = R.G;
	const single = R.chokes[0];
	const cut = single ? [single.raw[0]] : R.minCutSE.k < 3 ? R.minCutSE.raw : null;
	if (!cut) { console.log(`ok after ${added.length} link(s): 최단 ${R.exitLen}`); break; }
	const what = single ? `single ${single.cells[0]} (${single.pairs[0]})` : `mincut ${R.minCutSE.at.join("+")}`;
	const mask = new Uint8Array(2 * G.A);
	for (const c of cut) square(G, c, 1, mask, null);
	let src = G.S.map(([i, j, f]) => G.node(i, j, f));
	if (single && !single.pairs[0].startsWith("S→")) { const zi = R.zInfo.find((z) => single.pairs[0].startsWith(`Z ${z.label}→`)); if (zi) src = [zi.n]; }
	const d1 = bfs(G, G.adjP, src, mask), d0 = bfs(G, G.adjP, G.S.map(([i, j, f]) => G.node(i, j, f)), null);
	const side = (f, i, j) => { if (!G.exists(f, i, j) || mask[G.cell(f, i, j)]) return 0; const c = G.cell(f, i, j); if (cellDist(d1, c) >= 0) return 1; if (cellDist(d0, c) >= 0) return 2; return 0; };
	const inAvoid = (i, j) => avoid.some(([a, b, c, d]) => i >= a && i <= c && j >= b && j <= d);
	const cands = [];
	for (const f of G.stacked ? [0, 1] : [0]) for (let j = 1; j < G.H - 1; j++) for (let i = 1; i < G.W - 1; i++) {
		if (G.ch(f, i, j) !== "#" || inAvoid(i, j)) continue;
		for (const [a, b] of [[1, 0], [0, 1]]) for (const len of [1, 2]) {
			const ok = [...Array(len).keys()].every((k) => { const x = i + a * k, y = j + b * k; return G.ch(f, x, y) === "#" && G.ch(f, x + b, y + a) === "#" && G.ch(f, x - b, y - a) === "#" && !inAvoid(x, y); });
			if (!ok) continue;
			const ax = i - a, ay = j - b, bx = i + a * len, by = j + b * len;
			// (옛 방식 2층 구역은 같은 층끼리만)
			const fa = G.stacked ? f : G.isUp(ax, ay) ? 1 : 0, fb = G.stacked ? f : G.isUp(bx, by) ? 1 : 0;
			if (fa !== fb) continue;
			const sa = side(fa, ax, ay), sb = side(fb, bx, by);
			if (!sa || !sb || sa === sb) continue;
			if (G.levels(fa, ax, ay).join() !== "0" || G.levels(fb, bx, by).join() !== "0") continue;
			if (["1", "2", "s", "E", "S"].includes(G.ch(fa, ax, ay)) || ["1", "2", "s", "E", "S"].includes(G.ch(fb, bx, by))) continue;
			cands.push({ f: G.stacked ? f : 0, cells: [...Array(len).keys()].map((k) => [i + a * k, j + b * k]) });
		}
	}
	let best = null;
	for (const cd of cands) {
		const st2 = { ...st, rows: st.rows.slice(), rows2: st.rows2 ? st.rows2.slice() : null };
		const target = cd.f === 1 ? st2.rows2 : st2.rows;
		cd.cells.forEach(([x, y], k) => setCh(target, x, y, k === 0 ? "D" : "."));
		const R2 = analyzeStage(id, { st: st2, quick: true });
		const fixed = single ? !R2.chokes.some((c) => c.raw.includes(single.raw[0])) : R2.minCutSE.k >= 3 || R2.minCutSE.at.join() !== R.minCutSE.at.join();
		if (!fixed || R2.exitLen < MIN) continue;
		const score = R2.exitLen - R2.chokes.length * 50 + (R2.minCutSE.k >= 3 ? 30 : 0);
		if (!best || score > best.score) best = { ...cd, score, len: R2.exitLen, st2 };
	}
	if (!best) { console.log(`${what}: no candidate keeps 최단 ≥ ${MIN} (${cands.length} candidates)`); break; }
	st.rows = best.st2.rows;
	st.rows2 = best.st2.rows2;
	added.push(best);
	console.log(`${what} → ${best.f ? "2층 " : ""}문 ${best.cells.map(([x, y]) => `(${x},${y})`).join(" ")}  최단 ${best.len}`);
}
console.log("\n// 생성기에 옮길 줄(g = 1층, up = 2층):");
for (const a of added) console.log(a.cells.map(([x, y], k) => `${a.f ? "up" : "g"}.set(${x}, ${y}, "${k === 0 ? "D" : "."}");`).join(" "));
