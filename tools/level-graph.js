// 레벨 디자인 검증기: 맵을 "길 그래프"로 보고, 괴물이 길을 막아도 진행할 수 있는지 자동으로 잰다.
//   node tools/level-graph.js              (모든 스테이지, 요약)
//   node tools/level-graph.js 3 [--json out.json] [--png out.png] [--runs 300]
//   node tools/level-graph.js --pngdir tools/maps     (스테이지마다 길 지도 그림 stageN-routes.png)
// 2층: 겹쳐 쌓은 2층(Rows2, 1층과 같은 크기)과 옛 방식(UpperRects) 모두 읽는다. 칸(cell) = (층, 열, 행), 층 0 = 1층(구덩이 포함), 1 = 2층.
// 검사(모두 시드 고정이라 같은 맵이면 같은 결과가 나온다. 실패는 좌표와 함께 적는다 → 그대로 재현 가능. 2층 칸은 "2F r행c열"):
//   reach      시작에서 모든 뒤지는 곳(Z) 앞 칸·출구에 갈 수 있는가(소품·가구를 막힌 것으로)
//   single     괴물 하나(3x3 칸, 복도 폭 전체)를 어디에 세워도: 시작 → 각 Z, 각 Z → 출구, 시작 → 출구가 끊기지 않는가
//              (목표 바로 앞 EXEMPT 칸 안은 "목표에 서 있는 것"이라 뺀다. 시작 방 안도 뺀다 — 괴물은 시작점 가까이 안 들어온다)
//   mincut     시작 → 출구를 끊는 데 괴물이 몇 마리 필요한가(1, 2, 3 이상 — 빠짐없이 찾는다). 1 이면 실패, 2 면 경고(출구 앞 마지막 방은 뺀다)
//   routes     서로 다른 길(앞 길 둘레를 비싸게 쳐서 다시 찾기, 참고용 — 그림)
//   pair       괴물 둘이 서로 다른 통로(5칸 이상 떨어져)에 동시에 서 있을 때 끊기는 비율(시작 → 출구, 각 Z → 출구, 무작위 표본)
//   dynamic    괴물 N마리(스테이지 설정 수)가 돌아다니는 동안 플레이어 흉내: 가장 가까운 안 뒤진 Z 로 가서 열쇠 3개를 찾고 출구로.
//              괴물 둘레 3x3 을 피해서만 움직인다. 피해 갈 길이 하나도 없어 "기다릴 수밖에 없는" 순간(forced wait)을 센다.
//              네 판에 한 판은 괴물 하나가 플레이어를 쫓는다(chase). 판 수 --runs.
//   monster    괴물이 갈 수 없는 바닥(좁은 다리 n 너머)
//   zones      문(D/A)으로 나뉜 구역 그래프: 구역 수, 고리 수(독립 순환 = E - V + 1), 다리(bridge) 문
//   bigcut     괴물 둘로 끊기는 자리 중 가장 넓게 끊는 것이 출구 둘레(마지막 방) 크기를 크게 넘으면 실패(맵 한가운데 목)
//   straight   한 줄을 따라 문·벽·막는 소품 없이 30칸 넘게 곧게 열린 시야가 폭(중앙값) 6칸 이하 복도에 있으면 실패(벽감은 못 끊는다)
//   many       너무 다중이면 안 된다: 서로 다른 길 4개 이상 + 고리 16개 넘음, 또는 고리 22개 넘음 → 경고
//   width      시작 → 출구 가장 짧은 길 중 폭 1칸(양옆이 벽) 구간 비율
const fs = require("fs");
const path = require("path");
const cp = require("child_process");
const { loadStage, stageIds } = require("./stage-file");
const ROOT = path.join(__dirname, "..");
const D4 = [[1, 0], [-1, 0], [0, 1], [0, -1]];
const EXEMPT = 3; // 목표에서 이 BFS 거리 안의 칸은 막아 보지 않는다
const EXIT_ROOM = 6; // 괴물 둘·셋 검사에서 출구 앞 이 거리 안(마지막 방)은 "목표에 서 있는 것"으로 본다
const CUT_R = 1; // 괴물이 막는 반경(칸, 체비셰프): 1 → 3x3
const KEYS = 3;

function rng(seed) {
	let s = seed >>> 0 || 1;
	return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296);
}

function monstersOf(id) {
	const cfg = fs.readFileSync(path.join(ROOT, "src", "shared", "Config.luau"), "utf8");
	const m = cfg.match(new RegExp(`\\{ Id = ${id}, [^}]*Monsters = (\\d+)`));
	return m ? +m[1] : 2;
}

// ── 그래프. 칸 c = 층*A + 행*W + 열 (A = W*H), 노드 = c*2 + 높이(0 바닥, 1 구덩이) ──
function buildGraph(st) {
	const { rows, rows2, upper, pits } = st;
	const H = rows.length, W = rows[0].length, A = W * H;
	const stacked = !!rows2;
	// 지나갈 수 있는 문자: 바닥·문·구덩이·계단 + 벽에 붙인 상자 더미(c)·모서리 배관(v)(칸 반 이상이 비어 있다) + Walkable 소품
	const OPEN = new Set([".", "S", "E", "D", "A", "f", "p", "b", "n", "s", "1", "2", "c", "v", ...pits, ...st.walk]);
	for (const k of st.noWalk || []) OPEN.delete(k); // (Walkable = false: 구덩이 높이의 막는 소품)
	const isUp = (i, j) => upper.some(([a, b, c, d]) => i >= a && i <= c && j >= b && j <= d);
	const raw = (rs, i, j) => (j < 0 || j >= H || i < 0 || i >= W || !rs ? "#" : rs[j][i]);
	const ch = (f, i, j) => (f === 1 && stacked ? raw(rows2, i, j) : raw(rows, i, j));
	const exists = (f, i, j) => {
		const c = ch(f, i, j);
		if (!OPEN.has(c)) return false;
		if (stacked) return true;
		const up = c === "2" || (isUp(i, j) && c !== "1");
		return f === 1 ? up : !up;
	};
	const levels = (f, i, j) => {
		const c = ch(f, i, j);
		if (f === 1 || c === "1" || c === "2" || !pits.has(c)) return [0];
		return c === "b" || c === "n" ? [0] : c === "s" ? [0, 1] : [1];
	};
	const cell = (f, i, j) => f * A + j * W + i;
	const N = 2 * A * 2;
	const adjP = Array.from({ length: N }, () => []);
	const adjM = Array.from({ length: N }, () => []);
	const link = (u, f, i, j, l, viaN) => {
		if (!exists(f, i, j) || !levels(f, i, j).includes(l)) return;
		const v = cell(f, i, j) * 2 + l;
		adjP[u].push(v);
		if (!viaN) adjM[u].push(v);
	};
	for (const f of [0, 1]) for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) {
		if (!exists(f, i, j)) continue;
		const c = ch(f, i, j);
		for (const l of levels(f, i, j)) {
			const u = cell(f, i, j) * 2 + l;
			if (c === "s") for (const L of [0, 1]) if (L !== l) { adjP[u].push(cell(f, i, j) * 2 + L); adjM[u].push(cell(f, i, j) * 2 + L); }
			for (const [a, b] of D4) {
				const ni = i + a, nj = j + b;
				if (stacked) {
					if (f === 0 && c === "2") {
						if (ch(0, ni, nj) === "1") link(u, 0, ni, nj, 0, false);
						else if (ch(0, i - a, j - b) === "1") link(u, 1, ni, nj, 0, false);
						continue;
					}
					if (f === 0 && ch(0, ni, nj) === "2" && c !== "1") continue; // (계단 위 칸은 옆·앞에서 못 들어간다)
					if (f === 1 && ch(1, ni, nj) === "o") {
						if (ch(0, ni, nj) === "2" && ch(0, ni + a, nj + b) === "1") link(u, 0, ni, nj, 0, false);
						continue;
					}
					const n = ch(f, ni, nj);
					link(u, f, ni, nj, l, c === "n" || n === "n");
				} else {
					const n = ch(f, ni, nj);
					let nf = f, nl = l;
					if ((c === "1" && n === "2") || (c === "2" && n === "1")) { nf = n === "2" ? 1 : 0; nl = 0; }
					link(u, nf, ni, nj, nl, c === "n" || n === "n");
				}
			}
		}
	}
	const wall = (f, i, j) => ch(f, i, j) === "#";
	const S = [], Z = [];
	let E = null;
	for (const f of stacked ? [0, 1] : [0]) for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) {
		const c = ch(f, i, j);
		const ff = stacked ? f : isUp(i, j) ? 1 : 0;
		if (c === "S") S.push([i, j, ff]);
		if (c === "E") E = [i, j, ff];
		if (c === "Z") {
			const d = D4.find(([a, b]) => wall(f, i + a, j + b) && !wall(f, i - a, j - b));
			Z.push({ at: [i, j, ff], front: d ? [i - d[0], j - d[1], ff] : null });
		}
	}
	const node = (i, j, f) => { for (const l of levels(f, i, j)) return cell(f, i, j) * 2 + l; return -1; };
	const label = (c) => { const f = Math.floor(c / A), t = c % A; return `${f ? "2F " : ""}r${Math.floor(t / W)}c${t % W}`; };
	const xyf = (c) => { const f = Math.floor(c / A), t = c % A; return [t % W, Math.floor(t / W), f]; };
	return { W, H, A, N, stacked, hasUpper: stacked || upper.length > 0, ch, exists, levels, cell, adjP, adjM, S, E, Z, node, label, xyf, OPEN, isUp };
}

// BFS: blocked = Uint8Array(2A) 칸 막기. 돌려주는 값 Int32Array 거리(-1 = 못 감)
function bfs(G, adj, srcNodes, blocked) {
	const dist = new Int32Array(G.N).fill(-1);
	const q = new Int32Array(G.N);
	let h = 0, t = 0;
	for (const s of srcNodes) if (s >= 0 && !(blocked && blocked[s >> 1]) && dist[s] < 0) { dist[s] = 0; q[t++] = s; }
	while (h < t) {
		const u = q[h++];
		for (const v of adj[u]) {
			if (dist[v] >= 0 || (blocked && blocked[v >> 1])) continue;
			dist[v] = dist[u] + 1;
			q[t++] = v;
		}
	}
	return dist;
}
const cellDist = (dist, c) => { const a = dist[c * 2], b = dist[c * 2 + 1]; return a < 0 ? b : b < 0 ? a : Math.min(a, b); };
// (도구 호환: 열·행·층으로)
const tileDist = (G, dist, i, j, f = 0) => cellDist(dist, G.cell(f, i, j));
// 가장 짧은 길(목표 → 출발로 되짚기): 칸 번호 목록
function backtrack(G, adj, dist, goalNode) {
	if (goalNode < 0 || dist[goalNode] < 0) return null;
	const out = [];
	let u = goalNode;
	while (dist[u] > 0) {
		out.push(u >> 1);
		let nxt = -1;
		for (const v of adj[u]) if (dist[v] === dist[u] - 1) { nxt = v; break; }
		if (nxt < 0) break; // (adj 는 대칭)
		u = nxt;
	}
	out.push(u >> 1);
	return out;
}
// 칸 c 둘레(같은 층) 반경 r 을 막는다
function square(G, c, r, mask, protect) {
	const [ci, cj, f] = G.xyf(c);
	for (let a = -r; a <= r; a++) for (let b = -r; b <= r; b++) {
		const i = ci + a, j = cj + b;
		if (i < 0 || j < 0 || i >= G.W || j >= G.H) continue;
		const k = G.cell(f, i, j);
		if (protect && protect[k]) continue;
		mask[k] = 1;
	}
}
const around = (G, cells, r = 1) => { const s = new Set(); for (const c of cells) { const [i, j, f] = G.xyf(c); for (let a = -r; a <= r; a++) for (let b = -r; b <= r; b++) { const x = i + a, y = j + b; if (x >= 0 && y >= 0 && x < G.W && y < G.H) s.add(G.cell(f, x, y)); } } return [...s]; };
// 칸 비용 1 (+8: penal 칸, 보호 칸 제외)인 가장 싼 길(칸 번호 목록)
function dijkstra(G, src, goal, penal, prot) {
	const dist = new Int32Array(G.N).fill(1e9), prev = new Int32Array(G.N).fill(-1);
	const buckets = [[]];
	for (const s of src) { dist[s] = 0; buckets[0].push(s); }
	for (let c = 0; c < buckets.length; c++) {
		const bk = buckets[c];
		if (!bk) continue;
		for (let h = 0; h < bk.length; h++) {
			const u = bk[h];
			if (dist[u] !== c) continue;
			if (u === goal) { const out = []; let x = u; while (x >= 0) { out.push(x >> 1); x = prev[x]; } return out; }
			for (const v of G.adjP[u]) {
				const t = v >> 1;
				const w = 1 + (penal[t] && !prot[t] ? 8 : 0);
				if (c + w < dist[v]) { dist[v] = c + w; prev[v] = u; (buckets[c + w] ||= []).push(v); }
			}
		}
	}
	return null;
}

function analyzeStage(id, opts = {}) {
	const st = opts.st || loadStage(id);
	const G = buildGraph(st);
	const NC = 2 * G.A;
	const R = { id, size: `${G.W}x${G.H}${G.stacked ? " 2층" : G.hasUpper ? " (2층 구역)" : ""}`, monsters: monstersOf(id), fails: [], warn: [] };
	const sNodes = G.S.map(([i, j, f]) => G.node(i, j, f));
	const eNode = G.E ? G.node(G.E[0], G.E[1], G.E[2]) : -1;
	const base = bfs(G, G.adjP, sNodes, null);
	R.exitLen = eNode >= 0 ? base[eNode] : -1;
	if (R.exitLen < 0) { R.fails.push("reach: exit unreachable"); R.G = G; R.chokes = []; R.minCutSE = { k: 0, at: [] }; R.zInfo = []; return R; }
	const zs = G.Z.filter((z) => z.front);
	for (const z of G.Z) if (!z.front) R.fails.push(`reach: Z ${G.label(G.cell(z.at[2], z.at[0], z.at[1]))} has no front`);
	const zLabel = (z) => G.label(G.cell(z.at[2], z.at[0], z.at[1]));
	for (const z of zs) if (tileDist(G, base, z.front[0], z.front[1], z.front[2]) < 0) R.fails.push(`reach: Z ${zLabel(z)} front unreachable`);
	R.searchSpots = zs.length;
	R.upperSpots = zs.filter((z) => z.at[2] === 1).length;
	const near = (dist, r) => { const m = new Uint8Array(NC); for (let c = 0; c < NC; c++) { const d = cellDist(dist, c); if (d >= 0 && d <= r) m[c] = 1; } return m; };
	const or = (a, b) => { const m = new Uint8Array(a.length); for (let k = 0; k < a.length; k++) m[k] = a[k] | b[k]; return m; };
	// 시작 방 보호 칸(시작 칸에서 거리 2 이하) — 괴물이 안 들어오는 곳
	const startProtect = near(base, 2);
	const eNear = near(bfs(G, G.adjP, [eNode], null), EXEMPT);
	const zInfo = zs.map((z) => { const n = G.node(z.front[0], z.front[1], z.front[2]); return { z, n, label: zLabel(z), near: near(bfs(G, G.adjP, [n], null), EXEMPT) }; });
	const pairs = [["S→E", sNodes, eNode, or(startProtect, eNear)]];
	for (const zi of zInfo) {
		pairs.push([`S→Z ${zi.label}`, sNodes, zi.n, or(startProtect, zi.near)]);
		pairs.push([`Z ${zi.label}→E`, [zi.n], eNode, or(or(zi.near, eNear), startProtect)]);
	}
	const standable = (c, prot) => !prot[c] && G.exists(Math.floor(c / G.A), ...G.xyf(c).slice(0, 2));
	// single: 괴물 하나
	const singleFails = new Map(); // 칸 → [쌍 이름]
	let singleTests = 0;
	for (const [name, src, goal, prot] of pairs) {
		const p = backtrack(G, G.adjP, bfs(G, G.adjP, src, null), goal);
		if (!p) continue;
		for (const c of around(G, p, CUT_R)) {
			if (!standable(c, prot)) continue;
			const m = new Uint8Array(NC);
			square(G, c, CUT_R, m, prot);
			singleTests++;
			if (bfs(G, G.adjP, src, m)[goal] < 0) { if (!singleFails.has(c)) singleFails.set(c, []); singleFails.get(c).push(name); }
		}
	}
	R.singleTests = singleTests;
	R.chokes = clusterCells(G, [...singleFails.keys()]).map((cl) => ({ cells: cl.map(G.label), raw: cl, pairs: [...new Set(cl.flatMap((k) => singleFails.get(k)))] }));
	for (const c of R.chokes) R.fails.push(`single: monster at ${c.cells[0]}${c.cells.length > 1 ? ` (+${c.cells.length - 1})` : ""} cuts ${c.pairs.slice(0, 4).join(", ")}${c.pairs.length > 4 ? ` …${c.pairs.length}` : ""}`);
	// routes: 앞서 찾은 길 둘레(±1칸)를 지나면 비싸게(칸당 +8) 쳐서 다시 찾는다. 앞 길과 겹치는 칸이 35% 미만이고
	// 길이가 가장 짧은 길의 1.5배 안이면 다른 길로 센다(참고용 — 그림)
	const routes = (src, goal, prot, maxK = 4) => {
		const used = new Uint8Array(NC), on = new Uint8Array(NC);
		const lens = [], paths = [];
		let first = 0;
		for (let k = 0; k < maxK + 2 && lens.length < maxK; k++) {
			const p = dijkstra(G, src, goal, used, prot);
			if (!p) break;
			if (k === 0) first = p.length - 1;
			const overlap = p.filter((c) => on[c] && !prot[c]).length / p.length;
			if (p.length - 1 > first * 1.5) break; // (주 경로의 1.5배를 넘는 우회는 길로 안 친다)
			if (overlap < 0.35) { lens.push(p.length - 1); paths.push(p); }
			for (const c of p) on[c] = 1;
			for (const c of around(G, p, 1)) used[c] = 1;
		}
		return { lens, routes: lens.length, paths };
	};
	R.routesSE = routes(sNodes, eNode, pairs[0][3]);
	// minCut: 끊는 데 필요한 괴물 수. 둘째 괴물은 첫째를 세운 뒤 남은 가장 짧은 길 둘레에서 모두 찾아본다(빠짐없이)
	const minCut = (src, goal, prot) => {
		const P0 = backtrack(G, G.adjP, bfs(G, G.adjP, src, null), goal);
		if (!P0) return { k: 0, at: [] };
		const c1s = around(G, P0).filter((c) => standable(c, prot));
		for (const c1 of c1s) {
			const m1 = new Uint8Array(NC); square(G, c1, CUT_R, m1, prot);
			if (bfs(G, G.adjP, src, m1)[goal] < 0) return { k: 1, at: [G.label(c1)], raw: [c1] };
		}
		// 괴물 둘로 끊기는 자리를 빠짐없이 보고, 그중 가장 많은 칸을 끊는 것(worst)을 고른다(어느 한 마리는 첫 길 둘레에 있어야 한다)
		const d0 = bfs(G, G.adjP, src, null);
		let base0 = 0;
		for (let c = 0; c < NC; c++) if (cellDist(d0, c) >= 0) base0++;
		let first = null, worst = null;
		for (const c1 of c1s) {
			const m1 = new Uint8Array(NC); square(G, c1, CUT_R, m1, prot);
			const P1 = backtrack(G, G.adjP, bfs(G, G.adjP, src, m1), goal);
			for (const c2 of around(G, P1)) {
				if (!standable(c2, prot)) continue;
				const m2 = m1.slice(); square(G, c2, CUT_R, m2, prot);
				const d2 = bfs(G, G.adjP, src, m2);
				if (d2[goal] >= 0) continue;
				let left = 0;
				for (let c = 0; c < NC; c++) if (cellDist(d2, c) >= 0) left++;
				const lost = base0 - left;
				const hit = { k: 2, at: [G.label(c1), G.label(c2)], raw: [c1, c2], lost, left };
				if (!first) first = hit;
				// 가장 "가운데"인 컷: 끊긴 쪽(lost)과 시작 쪽(left) 중 작은 쪽이 가장 큰 것
				if (!worst || Math.min(lost, left) > Math.min(worst.lost, worst.left)) worst = hit;
			}
		}
		if (first) return { ...first, worst };
		return { k: 3, at: [] };
	};
	const exitRoom = or(startProtect, near(bfs(G, G.adjP, [eNode], null), EXIT_ROOM));
	R.minCutSE = minCut(sNodes, eNode, exitRoom);
	// 괴물 하나로 끊기면 실패(목). 둘로 끊기는 자리는 경고만 — 길을 셋 넘게 늘리면 미로가 된다(사용자: 너무 다중이면 안 된다).
	// 괴물 여럿에 대한 판정은 pair(끊기는 비율)·dynamic(기다림)이 한다
	if (R.minCutSE.k < 2) R.fails.push(`mincut: ${R.minCutSE.k} monster(s) at ${R.minCutSE.at.join(" + ")} cut start→exit (need ≥2)`);
	else if (R.minCutSE.k === 2) {
		// 괴물 둘로 끊기는 건 출구 앞 마지막 방이면 괜찮다. 그보다 훨씬 넓게(맵 한가운데에서) 끊기면 실패:
		// 끊긴 칸 수가 출구 둘레(EXIT_ROOM 거리) 칸 수의 2배 + 20 을 넘으면 가운데 목이다
		// 출구 쪽(lost)과 시작 쪽(left)이 둘 다 넓으면 맵 한가운데 목이다. 한쪽이 마지막 방·시작 방 크기(둘레 6칸 ×2 + 20)면 괜찮다
		const areaN = (n) => { const m = near(bfs(G, G.adjP, n, null), EXIT_ROOM); let k = 0; for (const v of m) k += v; return k; };
		const eLim = areaN([eNode]) * 2 + 20, sLim = areaN(sNodes) * 2 + 20;
		const w = R.minCutSE.worst;
		R.bigCut = { lost: w.lost, left: w.left, eLim, sLim, at: w.at };
		if (w.lost > eLim && w.left > sLim) R.fails.push(`bigcut: two monsters at ${w.at.join(" + ")} split the map (${w.left} tiles on the start side, ${w.lost} incl. the exit; allowed only near the exit ≤${eLim} or the start ≤${sLim}) — a mid-map chokepoint`);
		else R.warn.push(`mincut: two monsters standing exactly at ${w.at.join(" + ")} would cut ${w.lost <= eLim ? "the last " + w.lost + " tiles before the exit" : "the start area (" + w.left + " tiles)"}`);
	}
	R.zInfo = zInfo;
	R.G = G;
	if (opts.quick) return R;
	// pair: 괴물 둘
	const rand = rng(id * 7919 + 1);
	const pairTest = (src, goal, prot, samples) => {
		const d0 = bfs(G, G.adjP, src, null);
		const cells = [];
		for (let c = 0; c < NC; c++) if (standable(c, prot) && cellDist(d0, c) >= 0) cells.push(c);
		let cut = 0, n = 0;
		const where = [];
		for (let s = 0; s < samples; s++) {
			const a = cells[(rand() * cells.length) | 0], b = cells[(rand() * cells.length) | 0];
			const [ai, aj, af] = G.xyf(a), [bi, bj, bf] = G.xyf(b);
			if (af === bf && Math.max(Math.abs(ai - bi), Math.abs(aj - bj)) < 5) continue;
			const m = new Uint8Array(NC);
			square(G, a, CUT_R, m, prot);
			square(G, b, CUT_R, m, prot);
			n++;
			if (bfs(G, G.adjP, src, m)[goal] < 0) { cut++; if (where.length < 5) where.push(`${G.label(a)}+${G.label(b)}`); }
		}
		return { rate: n ? cut / n : 0, n, examples: where };
	};
	const samples = opts.pairSamples || 1500;
	R.pairSE = pairTest(sNodes, eNode, exitRoom, samples);
	let worstZ = { rate: 0 };
	for (const zi of zInfo) {
		const r = pairTest([zi.n], eNode, or(or(zi.near, eNear), startProtect), Math.round(samples / 4));
		if (r.rate > worstZ.rate) worstZ = { ...r, z: zi.label };
	}
	R.pairWorstZ = worstZ;
	if (R.pairSE.rate > 0.03) R.fails.push(`pair: two monsters cut S→E in ${(R.pairSE.rate * 100).toFixed(1)}% of placements (max 3%) e.g. ${R.pairSE.examples[0]}`);
	if (worstZ.rate > 0.08) R.warn.push(`pair: two monsters cut Z ${worstZ.z}→E in ${(worstZ.rate * 100).toFixed(1)}%`);
	// dynamic
	R.dynamic = simulate(G, id, R.monsters, sNodes, eNode, zInfo, startProtect, opts.runs || 200);
	if (R.dynamic.forcedWaitRuns / R.dynamic.runs > 0.1) R.fails.push(`dynamic: ${R.dynamic.forcedWaitRuns}/${R.dynamic.runs} runs had to wait (no route around monsters) — hot spots ${R.dynamic.hot.slice(0, 3).join(" ")}`);
	if (R.dynamic.unfinished > 0) R.fails.push(`dynamic: ${R.dynamic.unfinished} runs could not finish`);
	// monster nav: 괴물이 못 가는 바닥(좁은 다리 n 너머)
	const dM = bfs(G, G.adjM, sNodes, null);
	let mUn = 0;
	for (let c = 0; c < NC; c++) { const [i, j, f] = G.xyf(c); if ([".", "D", "A", "f", "p", "b"].includes(G.ch(f, i, j)) && G.exists(f, i, j) && cellDist(base, c) >= 0 && cellDist(dM, c) < 0) mUn++; }
	R.monsterUnreach = mUn;
	if (mUn > 0) R.warn.push(`monster: ${mUn} floor tiles the monster cannot reach (narrow bridges)`);
	// 2층: 2층이 진짜 다른 길인가(2층 칸을 다 막으면 / 꼭 지날 때)
	if (G.hasUpper) {
		const m = new Uint8Array(NC);
		for (let c = G.A; c < NC; c++) m[c] = 1;
		const d = bfs(G, G.adjP, sNodes, m);
		R.withoutUpper = d[eNode];
	}
	R.zones = zoneGraph(G);
	// 긴 직선 시야(복도): 한 줄(lane)을 따라 문·벽·막는 소품 없이 곧게 열린 칸이 STRAIGHT 칸 넘게 이어지고,
	// 그 구간의 통로 폭(수직으로 열린 칸 수)의 중앙값이 6칸 이하면(= 큰 홀이 아니라 복도) 실패.
	// 줄마다 따로 잰다: 벽에 한 칸 판 벽감·옆 문은 시야를 끊지 못하고, 진짜 문·셔터·벽·소품 섬만 끊는다(QA 3차 지적)
	{
		const STRAIGHT = 30, MAXW = 6; // (주차장 차로·하수도 본관처럼 실제로 긴 곳도 있어 30칸: QA 가 지적한 34칸 넘는 복도를 잡는다)
		const openT = (f, i, j) => G.exists(f, i, j) && G.ch(f, i, j) !== "D";
		let best = { len: 0 };
		for (const f of G.stacked ? [0, 1] : [0]) for (const ax of [1, 0]) {
			const nA = ax ? G.H : G.W, nB = ax ? G.W : G.H;
			for (let a = 0; a < nA; a++) {
				let widths = [], startB = 0;
				const flush = (b) => {
					if (widths.length > STRAIGHT) {
						const w = [...widths].sort((x, y) => x - y)[Math.floor(widths.length / 2)];
						if (w <= MAXW && widths.length > best.len) best = { len: widths.length, w, at: `${f ? "2F " : ""}${ax ? `r${a}c${startB}→c${b - 1}` : `c${a}r${startB}→r${b - 1}`}` };
					}
					widths = [];
				};
				for (let b = 0; b <= nB; b++) {
					const i = ax ? b : a, j = ax ? a : b;
					if (b < nB && openT(f, i, j)) {
						let w = 1;
						for (let k = 1; k < 9 && openT(f, i + (ax ? 0 : k), j + (ax ? k : 0)); k++) w++;
						for (let k = 1; k < 9 && openT(f, i - (ax ? 0 : k), j - (ax ? k : 0)); k++) w++;
						if (widths.length === 0) startB = b;
						widths.push(w);
					} else flush(b);
				}
			}
		}
		R.longest = best;
		if (best.len > STRAIGHT) R.fails.push(`straight: ${best.len}-tile straight sightline in a ${best.w}-wide corridor at ${best.at} (max ${STRAIGHT}; break it with a real door/shutter, a wall jog or a prop island across the lane)`);
	}
	// 너무 다중이면 안 된다: 주·보조·대체 세 갈래가 기준. 갈래가 4개 이상이고 고리가 많으면 미로처럼 흩어진 것
	if (R.routesSE.routes >= 4 && R.zones.loops > 16) R.warn.push(`too many routes: ${R.routesSE.routes} separate routes and ${R.zones.loops} loops (aim: 3 routes, loops ≤ 16)`);
	else if (R.zones.loops > 22) R.warn.push(`too many loops: ${R.zones.loops} (aim ≤ 16)`);
	const p0 = backtrack(G, G.adjP, base, eNode) || [];
	const narrow = p0.filter((c) => { const [i, j, f] = G.xyf(c); const w = (a, b) => !G.exists(f, a, b); return (w(i - 1, j) && w(i + 1, j)) || (w(i, j - 1) && w(i, j + 1)); }).length;
	R.narrowRatio = p0.length ? narrow / p0.length : 0;
	R.mainPath = p0;
	return R;
}

// 이웃한(같은 층) 실패 칸을 한 덩어리(같은 목)로 묶는다
function clusterCells(G, cells) {
	const seen = new Set(), out = [];
	for (const c of cells) {
		if (seen.has(c)) continue;
		const cl = [], q = [c];
		seen.add(c);
		while (q.length) {
			const x = q.pop();
			cl.push(x);
			const [xi, xj, xf] = G.xyf(x);
			for (const o of cells) { if (seen.has(o)) continue; const [oi, oj, of] = G.xyf(o); if (of === xf && Math.abs(oi - xi) <= 1 && Math.abs(oj - xj) <= 1) { seen.add(o); q.push(o); } }
		}
		out.push(cl);
	}
	return out;
}

// 괴물이 돌아다니는 동안 플레이어 흉내(칸 단위, 한 걸음 = 1칸). 괴물은 무작위 배회 목표로 걷고(플레이어 속도의 0.6),
// chase 판에서는 한 마리가 플레이어를 쫓는다(0.75). 플레이어는 괴물 둘레 3x3 을 밟지 않는 가장 짧은 길로 간다.
function simulate(G, id, nMon, sNodes, eNode, zInfo, startProtect, runs) {
	const rand = rng(id * 104729 + 7);
	const NC = 2 * G.A;
	const dS = bfs(G, G.adjM, sNodes, null);
	const walkNodes = [];
	for (let n = 0; n < G.N; n++) if (dS[n] >= 0 && !startProtect[n >> 1]) walkNodes.push(n);
	// 괴물은 시작점에서 거리 6칸(약 45스터드) 안으로 안 들어온다
	const keepOut = new Uint8Array(NC);
	for (let c = 0; c < NC; c++) { const d = cellDist(dS, c); if (d >= 0 && d <= 6) keepOut[c] = 1; }
	const far = walkNodes.filter((n) => dS[n] >= 9);
	let forcedWaitRuns = 0, unfinished = 0, caught = 0, totalSteps = 0, totalWaits = 0;
	const hot = new Map();
	for (let r = 0; r < runs; r++) {
		const chase = r % 4 === 3;
		const keyIdx = new Set();
		while (keyIdx.size < Math.min(KEYS, zInfo.length)) keyIdx.add((rand() * zInfo.length) | 0);
		const searched = new Set();
		let keys = 0;
		let p = sNodes[0];
		const mons = [];
		for (let m = 0; m < nMon; m++) mons.push({ at: far[(rand() * far.length) | 0], goal: -1, acc: 0 });
		let waits = 0, steps = 0, done = false, got = false;
		for (let t = 0; t < 2500 && !done; t++) {
			for (let mi = 0; mi < mons.length; mi++) {
				const m = mons[mi];
				const isChaser = chase && mi === 0;
				m.acc += isChaser ? 0.75 : 0.6;
				while (m.acc >= 1) {
					m.acc -= 1;
					let target = isChaser ? p : m.goal;
					if (!isChaser && (target < 0 || target === m.at)) { m.goal = walkNodes[(rand() * walkNodes.length) | 0]; target = m.goal; }
					const d = bfs(G, G.adjM, [target], keepOut);
					let best = m.at, bd = d[m.at] < 0 ? 1e9 : d[m.at];
					for (const v of G.adjM[m.at]) if (!keepOut[v >> 1] && d[v] >= 0 && d[v] < bd) { bd = d[v]; best = v; }
					if (best === m.at && !isChaser) m.goal = -1;
					m.at = best;
				}
			}
			const mask = new Uint8Array(NC);
			for (const m of mons) square(G, m.at >> 1, 1, mask, null);
			if (mask[p >> 1]) { caught++; got = true; break; }
			const d = bfs(G, G.adjP, [p], mask);
			let goal = -1;
			if (keys >= Math.min(KEYS, zInfo.length)) goal = d[eNode] >= 0 ? eNode : -1;
			else {
				let bd = 1e9;
				zInfo.forEach((zi, k) => { if (!searched.has(k) && d[zi.n] >= 0 && d[zi.n] < bd) { bd = d[zi.n]; goal = zi.n; } });
			}
			if (goal < 0) {
				waits++;
				const k = G.label(p >> 1);
				hot.set(k, (hot.get(k) || 0) + 1);
				continue;
			}
			if (goal === p) {
				if (goal === eNode) { done = true; break; }
				zInfo.forEach((zi, kk) => { if (zi.n === p && !searched.has(kk)) { searched.add(kk); if (keyIdx.has(kk)) keys++; } });
				continue;
			}
			const dg = bfs(G, G.adjP, [goal], mask);
			let best = p;
			for (const v of G.adjP[p]) if (dg[v] >= 0 && dg[v] < (dg[best] < 0 ? 1e9 : dg[best])) best = v;
			p = best;
			steps++;
		}
		if (waits > 0) forcedWaitRuns++;
		totalWaits += waits;
		totalSteps += steps;
		if (!done && !got) unfinished++;
	}
	return { runs, forcedWaitRuns, totalWaits, caught, unfinished, avgSteps: Math.round(totalSteps / runs), hot: [...hot.entries()].sort((a, b) => b[1] - a[1]).map(([k, v]) => `${k}×${v}`) };
}

// 문(D/A)으로 나뉜 구역 그래프(층마다): 구역 = 문 칸을 뺀 바닥 덩어리, 간선 = 두 구역을 잇는 문 칸·계단
function zoneGraph(G) {
	const NC = 2 * G.A;
	const comp = new Int32Array(NC).fill(-1);
	let nc = 0;
	const door = (c) => { const [i, j, f] = G.xyf(c); const ch = G.ch(f, i, j); return ch === "D" || ch === "A"; };
	const ok = (c) => { const [i, j, f] = G.xyf(c); return G.exists(f, i, j); };
	for (let c = 0; c < NC; c++) {
		if (!ok(c) || door(c) || comp[c] >= 0) continue;
		const q = [c];
		comp[c] = nc;
		while (q.length) {
			const x = q.pop();
			for (const l of [0, 1]) for (const v of G.adjP[x * 2 + l]) { const y = v >> 1; if (ok(y) && !door(y) && comp[y] < 0) { comp[y] = nc; q.push(y); } }
		}
		nc++;
	}
	const edges = [];
	for (let c = 0; c < NC; c++) {
		if (!ok(c) || !door(c)) continue;
		const cs = [...new Set([0, 1].flatMap((l) => G.adjP[c * 2 + l].map((v) => comp[v >> 1])).filter((x) => x >= 0))];
		if (cs.length === 2) edges.push({ a: cs[0], b: cs[1], at: G.label(c) });
	}
	const adj = Array.from({ length: nc }, () => []);
	edges.forEach((e, k) => { adj[e.a].push([e.b, k]); adj[e.b].push([e.a, k]); });
	const disc = new Int32Array(nc).fill(-1), low = new Int32Array(nc);
	const bridges = [];
	let time = 0;
	const dfs = (u, pe) => {
		disc[u] = low[u] = time++;
		for (const [v, k] of adj[u]) {
			if (k === pe) continue;
			if (disc[v] < 0) { dfs(v, k); low[u] = Math.min(low[u], low[v]); if (low[v] > disc[u]) bridges.push(edges[k].at); }
			else low[u] = Math.min(low[u], disc[v]);
		}
	};
	for (let u = 0; u < nc; u++) if (disc[u] < 0) dfs(u, -1);
	return { zones: nc, doors: edges.length, loops: edges.length - nc + 1, bridges: bridges.length, bridgeDoors: bridges };
}

// 길 지도 그림: 벽 흰 선, 서로 다른 길(파랑·초록·보라·주황), 목(괴물 하나로 끊기는 곳) 빨간 X, 괴물 둘로 끊기는 자리 빨간 점선,
// 기다려야 했던 곳 주황 원, Z 노랑, 출구 빨강, 시작 하늘색, 계단 초록 테두리. 2층 건물은 1층(왼쪽)·2층(오른쪽) 두 판.
function drawRoutes(R, out) {
	const G = R.G, T = 20, floors = G.stacked ? [0, 1] : [0], GAP = 30;
	const PW = G.W * T, PH = G.H * T;
	const ox = (f) => (G.stacked ? f * (PW + GAP) : 0);
	const W = floors.length * PW + (floors.length - 1) * GAP;
	let svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${PH + 70}" style="background:#000"><rect width="100%" height="100%" fill="#000"/>`;
	const wallAt = (f, i, j) => { const c = G.ch(G.stacked ? f : 0, i, j); return c === "#" || c === "o" || c === "_"; };
	for (const f of floors) {
		if (G.stacked) svg += `<text x="${ox(f) + 6}" y="${PH + 22}" fill="#9cf" font-size="18" font-family="sans-serif" font-weight="bold">${f + 1}층</text>`;
		for (let j = 0; j < G.H; j++) for (let i = 0; i < G.W; i++) {
			const c = G.ch(f, i, j), x = ox(f) + i * T, y = j * T;
			if (!G.stacked && G.isUp(i, j) && c !== "#") svg += `<rect x="${x}" y="${y}" width="${T}" height="${T}" fill="#0d2148"/>`;
			if (c === "o") svg += `<rect x="${x + 2}" y="${y + 2}" width="${T - 4}" height="${T - 4}" fill="none" stroke="#2fbf5f" stroke-dasharray="3 2"/>`;
			if (c !== "#" && c !== "o" && !G.OPEN.has(c)) svg += `<rect x="${x + 5}" y="${y + 5}" width="${T - 10}" height="${T - 10}" fill="#333"/>`;
			if (c === "1" || c === "2") svg += `<rect x="${x + 4}" y="${y + 4}" width="${T - 8}" height="${T - 8}" fill="none" stroke="#2fbf5f" stroke-width="2"/>`;
			if (!wallAt(f, i, j)) continue;
			const L = (x1, y1, x2, y2) => (svg += `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="#fff" stroke-width="2"/>`);
			if (!wallAt(f, i + 1, j)) L(x + T, y, x + T, y + T);
			if (!wallAt(f, i - 1, j)) L(x, y, x, y + T);
			if (!wallAt(f, i, j + 1)) L(x, y + T, x + T, y + T);
			if (!wallAt(f, i, j - 1)) L(x, y, x + T, y);
		}
	}
	const px = (c, k = 0) => { const [i, j, f] = G.xyf(c); return [ox(G.stacked ? f : 0) + i * T + T / 2 + k, j * T + T / 2 + k]; };
	const colors = ["#3aa0ff", "#3fdc6a", "#c46bff", "#ffa040"];
	R.routesSE.paths.forEach((p, k) => {
		// 층이 바뀌는 곳에서 선을 끊는다
		let seg = [];
		const flush = () => { if (seg.length > 1) svg += `<polyline points="${seg.join(" ")}" fill="none" stroke="${colors[k]}" stroke-width="3" opacity="0.85"/>`; seg = []; };
		let lastF = null;
		for (const c of p) { const f = Math.floor(c / G.A); if (lastF !== null && f !== lastF) flush(); lastF = f; const [x, y] = px(c, (k - 1.5) * 2); seg.push(`${x},${y}`); }
		flush();
	});
	for (const c of R.minCutSE.raw || []) { const [x, y] = px(c); svg += `<rect x="${x - 1.5 * T}" y="${y - 1.5 * T}" width="${3 * T}" height="${3 * T}" fill="none" stroke="#ff2a2a" stroke-width="2" stroke-dasharray="4 3"/>`; }
	for (const zi of R.zInfo) { const [x, y] = px(G.cell(zi.z.at[2], zi.z.at[0], zi.z.at[1])); svg += `<polygon points="${x},${y - 7} ${x + 7},${y} ${x},${y + 7} ${x - 7},${y}" fill="#ffd400"/>`; }
	{ const [x, y] = px(G.cell(G.E[2], G.E[0], G.E[1])); svg += `<rect x="${x - T / 2 + 3}" y="${y - T / 2 + 3}" width="${T - 6}" height="${T - 6}" fill="#e02020"/>`; }
	for (const [i, j, f] of G.S) { const [x, y] = px(G.cell(f, i, j)); svg += `<circle cx="${x}" cy="${y}" r="5" fill="#4cf"/>`; }
	for (const ch of R.chokes) for (const c of ch.raw) { const [x, y] = px(c); svg += `<path d="M${x - 6} ${y - 6} L${x + 6} ${y + 6} M${x + 6} ${y - 6} L${x - 6} ${y + 6}" stroke="#ff2a2a" stroke-width="3"/>`; }
	const parseLabel = (k) => { const m = k.match(/(2F )?r(\d+)c(\d+)/); return G.cell(m[1] ? 1 : 0, +m[3], +m[2]); };
	for (const h of (R.dynamic && R.dynamic.hot) || []) { const [x, y] = px(parseLabel(h.split("×")[0])); svg += `<circle cx="${x}" cy="${y}" r="7" fill="none" stroke="#ff8800" stroke-width="2"/>`; }
	svg += `<text x="8" y="${PH + 52}" fill="#ccc" font-size="16" font-family="sans-serif">STAGE ${R.id} — 길 ${R.routesSE.routes}갈래 (${R.routesSE.lens.join(", ")}) · 끊는 데 괴물 ${R.minCutSE.k >= 3 ? "3+" : R.minCutSE.k}마리 · 괴물 하나로 끊기는 곳 ${R.chokes.length} · 괴물 둘 ${R.pairSE ? (R.pairSE.rate * 100).toFixed(1) : "?"}% · 기다려야 한 판 ${R.dynamic ? R.dynamic.forcedWaitRuns + "/" + R.dynamic.runs : "?"}</text>`;
	svg += "</svg>";
	const svgPath = out.replace(/\.png$/, ".svg");
	fs.writeFileSync(svgPath, svg);
	const edge = ["C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe", "C:/Program Files/Microsoft/Edge/Application/msedge.exe"].find(fs.existsSync);
	cp.execFileSync(edge, ["--headless", "--disable-gpu", `--screenshot=${out}`, `--window-size=${W},${PH + 70}`, "file:///" + svgPath.split("\\").join("/")], { stdio: "ignore" });
	fs.unlinkSync(svgPath);
}

function summary(R) {
	const z = R.zones || {}, d = R.dynamic || {};
	return `Stage${R.id} ${R.size} 괴물${R.monsters} | 최단 ${R.exitLen}${R.withoutUpper !== undefined ? ` (2층 없이 ${R.withoutUpper < 0 ? "못 감" : R.withoutUpper})` : ""} | 길 ${R.routesSE.routes}갈래(${R.routesSE.lens.join(",")}) | 끊는데 괴물 ${R.minCutSE.k >= 3 ? "3+" : R.minCutSE.k}마리 | Z ${R.searchSpots}곳${R.upperSpots ? `(2층 ${R.upperSpots})` : ""} | 목 ${R.chokes.length} | 괴물둘 S→E ${(R.pairSE.rate * 100).toFixed(1)}% Z최악 ${((R.pairWorstZ.rate || 0) * 100).toFixed(1)}% | 배회 기다림 ${d.forcedWaitRuns}/${d.runs}판(${d.totalWaits}틱) 잡힘 ${d.caught} | 구역 ${z.zones} 문 ${z.doors} 고리 ${z.loops} 다리문 ${z.bridges} | 좁은길 ${(R.narrowRatio * 100) | 0}% | 직선 ${R.longest ? R.longest.len : "?"} | 2마리컷 ${R.bigCut ? Math.min(R.bigCut.lost, R.bigCut.left) + "칸" : "-"} | 괴물못감 ${R.monsterUnreach} | ${R.fails.length ? "FAIL " + R.fails.length : "PASS"}`;
}

if (require.main === module) {
	const args = process.argv.slice(2);
	const ids = args[0] && /^\d+$/.test(args[0]) ? [+args[0]] : stageIds();
	const opt = (k) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : null; };
	const runs = +(opt("--runs") || 200);
	let failed = false;
	const all = [];
	for (const id of ids) {
		const R = analyzeStage(id, { runs });
		console.log(summary(R));
		for (const f of R.fails) console.log("   ✗ " + f);
		for (const w of R.warn) console.log("   · " + w);
		if (R.fails.length) failed = true;
		if (opt("--png") && ids.length === 1) drawRoutes(R, path.resolve(opt("--png")));
		if (opt("--pngdir")) drawRoutes(R, path.resolve(opt("--pngdir"), `stage${id}-routes.png`));
		const { G, mainPath, zInfo, chokes, ...rest } = R;
		rest.routesSE = { lens: R.routesSE.lens, routes: R.routesSE.routes };
		rest.chokes = chokes.map(({ cells, pairs }) => ({ cells, pairs }));
		all.push(rest);
	}
	if (opt("--json")) fs.writeFileSync(opt("--json"), JSON.stringify(all, null, 1));
	process.exit(failed ? 1 : 0);
}
module.exports = { analyzeStage, summary, drawRoutes, buildGraph, bfs, tileDist, cellDist, backtrack, square, loadStage };
