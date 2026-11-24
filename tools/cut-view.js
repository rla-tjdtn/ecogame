// 괴물이 서 있을 때 시작에서 못 가게 되는 구역을 글자 지도로 보여 준다(맵 고칠 자리 찾기용, level-graph 와 같은 그래프).
//   node tools/cut-view.js 1 r34c26 "2F r38c24"     (STAGES_DIR 로 다른 폴더)
// 표시: M 괴물 3x3, * 시작에서 못 가게 된 바닥(출구 포함), 나머지는 원래 문자. 2층 건물은 1층 다음에 2층을 찍는다.
const { loadStage, buildGraph, bfs, cellDist, square } = require("./level-graph");
const [id, ...cuts] = process.argv.slice(2);
const G = buildGraph(loadStage(id));
const mask = new Uint8Array(2 * G.A);
for (const c of cuts) { const m = c.match(/(2F )?r(\d+)c(\d+)/); square(G, G.cell(m[1] ? 1 : 0, +m[3], +m[2]), 1, mask, null); }
const sN = G.S.map(([i, j, f]) => G.node(i, j, f));
const d0 = bfs(G, G.adjP, sN, null), d1 = bfs(G, G.adjP, sN, mask);
for (const f of G.stacked ? [0, 1] : [0]) {
	if (G.stacked) console.log(`── ${f + 1}층`);
	console.log("    " + Array.from({ length: G.W }, (_, i) => i % 10).join(""));
	for (let j = 0; j < G.H; j++) {
		let line = "";
		for (let i = 0; i < G.W; i++) {
			const ch = G.ch(f, i, j);
			const ff = G.stacked ? f : G.isUp(i, j) ? 1 : 0;
			const c = G.cell(ff, i, j);
			line += mask[c] && ch !== "#" ? "M" : G.exists(ff, i, j) && cellDist(d0, c) >= 0 && cellDist(d1, c) < 0 ? "*" : ch;
		}
		console.log(String(j).padStart(3) + " " + line);
	}
}
