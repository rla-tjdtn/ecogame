// 스테이지 방 안 구성 바꾸기 + 갈림길 조금 더하기. 맵 모양(벽·복도·방 배치)은 그대로 둔다.
//
//   node tools/redecorate.js            (스테이지 1~4: 방 소품을 테마에 맞게 다시 배치 + 갈림길, 5: 갈림길만)
//   node tools/redecorate.js 4 --dry    (하나만, 출력만)
//
// 1) 방 찾기: 벽·문·아치로 둘러싸인 바닥 덩어리 중 직사각형에 가까운 것(3x3 이상)
// 2) 방 안의 일반 소품(상자·기계·기둥 등)을 치우고, 크기와 스테이지 테마에 맞는 방 종류로 다시 채운다
//    (숨는 곳 L·열쇠 상자 Z·구덩이·물길·계단은 그대로)
//    - 1 지하 시설: 창고(상자) · 실험실(장비+책상) · 관제실(책상 줄) · 기계실(기계+기둥)
//    - 2 물류 창고: 사무실(책상) · 재고실(컨테이너·상자) · 하역장(컨테이너 줄+지게차). 선반이 있는 홀은 그대로
//    - 3 하수도: 밸브실(배관) · 펌프실(머리 위 대형 배관+펌프)
//    - 4 폐병원: 창고(약품장) · 병실(침대 줄) · 진료실(책상+약품장) · 수술실(수술대) · 대기실(기둥+접수대)
// 3) 백룸처럼 갈림길: 벽 너머 가깝지만 걸어서 먼 두 곳을 아치·문으로 조금만 잇는다(출구 최단 거리는 크게 안 줄게)
// 소품은 길을 막지 않을 때만 놓는다(닿을 수 있는 바닥이 정확히 한 칸만 줄고, 방이 둘로 갈라지지 않을 때).

const fs = require("fs");
const path = require("path");

const D4 = [[1, 0], [-1, 0], [0, 1], [0, -1]];
const D8 = [...D4, [1, 1], [1, -1], [-1, 1], [-1, -1]];
const PASS = new Set([".", "S", "E", "D", "A", "f", "P", "p", "w", "b", "n", "s"]);

function rng(seed) {
	let s = (seed * 2654435761) >>> 0 || 1;
	return () => {
		s ^= s << 13; s >>>= 0; s ^= s >>> 17; s ^= s << 5; s >>>= 0;
		return s / 4294967296;
	};
}

function loopify(rows, o) {
	const g = rows.map((row) => row.split(""));
	const H = g.length, W = g[0].length, r = o.r;
	const pitSet = new Set(["p", "b", "s", "n", ...(o.pits || [])]);
	const at = (x, y) => (x < 0 || y < 0 || x >= W || y >= H ? "#" : g[y][x]);
	const lv = (c) => (pitSet.has(c) ? (c === "b" || c === "n" ? [0] : c === "s" ? [0, 1] : [1]) : [0]);
	const bfs = (sx, sy, monster) => {
		const dist = new Map([[`${sx},${sy},0`, 0]]);
		const q = [[sx, sy, 0]];
		for (let h = 0; h < q.length; h++) {
			const [x, y, l] = q[h];
			const d = dist.get(`${x},${y},${l}`);
			if (g[y][x] === "s") for (const L of [0, 1]) if (!dist.has(`${x},${y},${L}`)) { dist.set(`${x},${y},${L}`, d); q.push([x, y, L]); }
			for (const [dx, dy] of D4) {
				const nx = x + dx, ny = y + dy, c = at(nx, ny);
				if (!PASS.has(c) || (monster && c === "n") || !lv(c).includes(l)) continue;
				const k = `${nx},${ny},${l}`;
				if (!dist.has(k)) { dist.set(k, d + 1); q.push([nx, ny, l]); }
			}
		}
		return dist;
	};
	let S = null, E = null;
	for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { if (g[y][x] === "S" && !S) S = [x, y]; if (g[y][x] === "E") E = [x, y]; }
	const exitD = (monster) => bfs(S[0], S[1], monster).get(`${E[0]},${E[1]},0`);
	const RACK = new Set(["H", "h"]);
	const keep = new Set(["L", "Z", "D", "A", "E", "S", "s"]);
	const cands = [];
	for (let y = 1; y < H - 1; y++)
		for (let x = 1; x < W - 1; x++)
			for (const [dx, dy] of [[1, 0], [0, 1]]) {
				if (at(x - dx, y - dy) !== ".") continue;
				for (let len = 1; len <= (o.maxLen || 3); len++) {
					const tiles = [];
					for (let k = 0; k < len; k++) tiles.push([x + dx * k, y + dy * k]);
					const rack = len === 1 && RACK.has(at(x, y));
					const bx = x + dx * len, by = y + dy * len;
					if (bx < 1 || by < 1 || bx > W - 2 || by > H - 2 || at(bx, by) !== ".") { if (tiles.every(([tx, ty]) => at(tx, ty) === "#")) continue; else break; }
					const ok = tiles.every(([tx, ty]) => {
						const c = at(tx, ty);
						if (!(c === "#" || (rack && RACK.has(c))) || (o.reserved && o.reserved(tx, ty))) return false;
						const side = (c2) => c2 === "#" || (rack && RACK.has(c2));
						if (!side(at(tx + dy, ty + dx)) || !side(at(tx - dy, ty - dx))) return false; // 옆이 벽이어야 문·아치가 선다
						return !D8.some(([ex, ey]) => keep.has(at(tx + ex, ty + ey)));
					});
					if (ok) cands.push({ tiles, a: [x - dx, y - dy], b: [bx, by], rack, k: r() });
					break;
				}
			}
	const gain = (c) => {
		const d = bfs(c.a[0], c.a[1]).get(`${c.b[0]},${c.b[1]},0`);
		return d === undefined ? -1 : d - c.tiles.length - 1;
	};
	// 출구까지 거리를 거의 줄이지 않는 고리(옆길·우회로)부터: 그래야 고리를 많이 만들 수 있다
	const base = exitD(false);
	const apply = (c) => c.tiles.forEach(([tx, ty]) => (g[ty][tx] = "."));
	for (const c of cands) {
		c.g = gain(c);
		if (c.g < o.minGain) { c.red = 1e9; continue; }
		const old = c.tiles.map(([tx, ty]) => at(tx, ty));
		apply(c);
		c.red = base - (exitD(false) ?? base);
		c.tiles.forEach(([tx, ty], k) => (g[ty][tx] = old[k]));
	}
	cands.sort((p, q) => p.red - q.red || q.g + q.k * 4 - (p.g + p.k * 4));
	let made = 0;
	for (const c of cands) {
		if (made >= o.budget) break;
		if (!c.tiles.every(([tx, ty]) => (at(tx, ty) === "#" || (c.rack && RACK.has(at(tx, ty)))) && !D8.some(([ex, ey]) => keep.has(at(tx + ex, ty + ey))))) continue;
		if (gain(c) < o.minGain) continue;
		const old = c.tiles.map(([tx, ty]) => at(tx, ty));
		c.tiles.forEach(([tx, ty], k) => {
			g[ty][tx] = c.rack ? "." : k === 0 ? (c.tiles.length === 1 && r() < o.doors ? "D" : "A") : k % 3 === 0 && k < c.tiles.length - 1 ? "A" : ".";
		});
		const pd = exitD(false), md = exitD(true);
		if (pd === undefined || md === undefined || pd < o.min) c.tiles.forEach(([tx, ty], k) => (g[ty][tx] = old[k]));
		else made++;
	}
	return { rows: g.map((row) => row.join("")), made, dist: exitD(false), monster: exitD(true) };
}

function validate(rows, pitExtra) {
	const H = rows.length, W = rows[0].length, bad = [];
	const at = (i, j) => (j < 0 || j >= H || i < 0 || i >= W ? "#" : rows[j][i]);
	const wall = (i, j) => at(i, j) === "#";
	const pits = new Set(["p", "b", "s", "n", ...pitExtra]);
	let exits = 0;
	for (let j = 0; j < H; j++)
		for (let i = 0; i < W; i++) {
			const c = at(i, j);
			if (c === "D" || c === "A") {
				const wx = wall(i - 1, j) && wall(i + 1, j), wz = wall(i, j - 1) && wall(i, j + 1);
				const ox = !wall(i - 1, j) && !wall(i + 1, j), oz = !wall(i, j - 1) && !wall(i, j + 1);
				if (!((wx && oz) || (wz && ox))) bad.push(`${c}@${i},${j}`);
			}
			if (c === "E") {
				exits++;
				if (D4.filter(([a, b]) => !wall(i + a, j + b)).length !== 1) bad.push("exit entrances");
			}
			if (c === "s" && D4.filter(([a, b]) => { const n = at(i + a, j + b); return n !== "#" && !pits.has(n); }).length !== 1) bad.push(`stairs@${i},${j}`);
		}
	if (exits !== 1) bad.push("exits " + exits);
	return bad;
}


// ── 방 찾기: 바닥(벽·문·아치·구덩이·출입구 제외)에서 가장 큰 직사각형(3x3 이상)을 차례로 떼어 낸다 ──
//    복도는 폭이 1~2칸이라 걸리지 않고, 길쭉한 3칸 폭 통로(한쪽이 너무 긴 것)도 방으로 치지 않는다.
function findRooms(g, skip) {
	const H = g.length, W = g[0].length;
	const free = (x, y) => !"#DApwbnsSEHhB".includes(g[y][x]) && !skip(x, y);
	const used = Array.from({ length: H }, () => Array(W).fill(false));
	const rooms = [];
	for (;;) {
		// 누적 합으로 직사각형 안이 전부 쓸 수 있는 칸인지 O(1)에 확인
		const ps = Array.from({ length: H + 1 }, () => Array(W + 1).fill(0));
		for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) ps[y + 1][x + 1] = ps[y][x + 1] + ps[y + 1][x] - ps[y][x] + (free(x, y) && !used[y][x] ? 1 : 0);
		const sum = (x0, y0, w, h) => ps[y0 + h][x0 + w] - ps[y0][x0 + w] - ps[y0 + h][x0] + ps[y0][x0];
		let best = null;
		for (let y0 = 1; y0 < H - 3; y0++)
			for (let x0 = 1; x0 < W - 3; x0++)
				for (let h = 3; y0 + h < H && h <= 12; h++) {
					if (sum(x0, y0, 3, h) !== 3 * h) break;
					for (let w = 3; x0 + w < W && w <= 14; w++) {
						if (sum(x0, y0, w, h) !== w * h) break;
						const long = Math.max(w, h), short = Math.min(w, h);
						if (long > short * 3 || (short === 3 && long > 7)) continue;
						if (!best || w * h > best.w * best.h) best = { x: x0, y: y0, w, h };
					}
				}
		if (!best) break;
		const cells = [];
		for (let y = best.y; y < best.y + best.h; y++) for (let x = best.x; x < best.x + best.w; x++) { used[y][x] = true; cells.push([x, y]); }
		// 둘레 한 칸도 다른 방이 못 쓰게(방끼리 붙어 하나로 보이지 않게)
		for (let y = best.y - 1; y <= best.y + best.h; y++) for (let x = best.x - 1; x <= best.x + best.w; x++) if (y >= 0 && x >= 0 && y < H && x < W) used[y][x] = true;
		rooms.push({ ...best, area: best.w * best.h, cells });
	}
	return rooms;
}

// 방 네 변을 문·통로가 적은 순으로(소품은 막힌 벽을 등지게 놓는다)
function backLine(g, rm) {
	const at = (x, y) => (y < 0 || y >= g.length || x < 0 || x >= g[0].length ? "#" : g[y][x]);
	const sides = [
		{ cells: [...Array(rm.w)].map((_, k) => [rm.x + k, rm.y]), out: [0, -1] },
		{ cells: [...Array(rm.w)].map((_, k) => [rm.x + k, rm.y + rm.h - 1]), out: [0, 1] },
		{ cells: [...Array(rm.h)].map((_, k) => [rm.x, rm.y + k]), out: [-1, 0] },
		{ cells: [...Array(rm.h)].map((_, k) => [rm.x + rm.w - 1, rm.y + k]), out: [1, 0] },
	];
	for (const s of sides) s.open = s.cells.filter(([x, y]) => at(x + s.out[0], y + s.out[1]) !== "#").length;
	sides.sort((a, b) => a.open - b.open || b.cells.length - a.cells.length);
	return sides;
}

// 테마별 방 꾸미기: place(x, y, ch)는 길을 막으면 알아서 안 놓는다
const THEME = {
	1: (rm, sides, place, r) => {
		const back = sides[0].cells;
		const cx = rm.x + Math.floor(rm.w / 2), cy = rm.y + Math.floor(rm.h / 2);
		if (rm.area <= 12) {
			for (const [x, y] of back) if (r() < 0.7) place(x, y, "c");
			return "창고";
		}
		if (rm.area >= 40) {
			for (let y = rm.y + 1; y < rm.y + rm.h - 1; y += 2) for (let x = rm.x + 1; x < rm.x + rm.w - 1; x += 3) place(x, y, "O");
			back.forEach(([x, y], k) => k % 2 === 0 && place(x, y, "m"));
			place(cx, cy, "f");
			return "기계실";
		}
		if (r() < 0.5) {
			back.forEach(([x, y], k) => place(x, y, k % 2 ? "v" : "m"));
			place(cx, cy, "T");
			return "실험실";
		}
		back.forEach(([x, y], k) => k % 2 === 1 && place(x, y, "T"));
		if (sides[1].open === 0) sides[1].cells.forEach(([x, y], k) => k % 2 === 0 && place(x, y, "m"));
		return "관제실";
	},
	2: (rm, sides, place, r) => {
		const back = sides[0].cells;
		const cx = rm.x + Math.floor(rm.w / 2), cy = rm.y + Math.floor(rm.h / 2);
		if (rm.area <= 16) {
			place(cx, cy, "T");
			back.forEach(([x, y], k) => k % 3 === 0 && place(x, y, "c"));
			return "사무실";
		}
		if (rm.area >= 40) {
			// (컨테이너는 선이 많아 음파 비용이 커서 띄엄띄엄)
			back.forEach(([x, y], k) => k % 3 === 0 && place(x, y, r() < 0.3 ? "Q" : "K"));
			if (sides[1].open === 0) sides[1].cells.forEach(([x, y], k) => k % 3 === 1 && place(x, y, "c"));
			place(cx, cy, "m");
			return "하역장";
		}
		back.forEach(([x, y], k) => k % 2 === 0 && place(x, y, k % 4 === 0 && r() < 0.5 ? "K" : "c"));
		if (sides[1].open === 0) sides[1].cells.forEach(([x, y], k) => k % 2 === 1 && place(x, y, "c"));
		return "재고실";
	},
	3: (rm, sides, place, r) => {
		const back = sides[0].cells;
		if (rm.area <= 12) {
			back.forEach(([x, y], k) => k % 2 === 0 && place(x, y, "v"));
			return "밸브실";
		}
		// 펌프실: 머리 위로 지나가는 대형 배관 줄(지나갈 수 있음) + 구석의 펌프
		const horiz = rm.w >= rm.h;
		const mid = horiz ? rm.y + Math.floor(rm.h / 2) : rm.x + Math.floor(rm.w / 2);
		if (horiz) for (let x = rm.x; x < rm.x + rm.w; x++) place(x, mid, "P");
		else for (let y = rm.y; y < rm.y + rm.h; y++) place(mid, y, "P");
		back.forEach(([x, y], k) => (k === 0 || k === back.length - 1) && place(x, y, "m"));
		if (rm.area >= 30) back.forEach(([x, y], k) => k > 0 && k < back.length - 1 && k % 2 === 0 && place(x, y, "v"));
		return "펌프실";
	},
	4: (rm, sides, place, r) => {
		const back = sides[0].cells;
		const cx = rm.x + Math.floor(rm.w / 2), cy = rm.y + Math.floor(rm.h / 2);
		if (rm.area <= 10) {
			back.forEach(([x, y], k) => k !== 1 && place(x, y, "k"));
			return "창고";
		}
		if (rm.area >= 45) {
			for (let x = rm.x + 1; x < rm.x + rm.w - 1; x += 2) {
				place(x, rm.y + 1, "O");
				place(x, rm.y + rm.h - 2, "O");
			}
			back.slice(1, 4).forEach(([x, y]) => place(x, y, "T"));
			return "대기실";
		}
		const roll = r();
		if (roll < 0.5 && back.length >= 3) {
			back.forEach(([x, y], k) => k % 2 === 0 && place(x, y, "R"));
			return "병실";
		}
		if (roll < 0.75) {
			place(cx, cy, "T");
			back.forEach(([x, y], k) => k % 2 === 0 && place(x, y, "k"));
			return "진료실";
		}
		place(cx, cy, "X");
		back.forEach(([x, y], k) => k % 2 === 1 && place(x, y, "k"));
		return "수술실";
	},
};

const CLEAR = new Set(["c", "m", "v", "f", "O", "T", "R", "X", "k", "K", "Q", "P"]);
const BLOCKING_NEAR = new Set(["D", "A", "L", "Z", "S", "E", "s"]);

function redecorate(rows, id, r, skip) {
	const g = rows.map((row) => row.split(""));
	const H = g.length, W = g[0].length;
	const at = (x, y) => (x < 0 || y < 0 || x >= W || y >= H ? "#" : g[y][x]);
	const pitSet = new Set(["p", "b", "s", "n", ...(id === 3 ? ["w"] : [])]);
	const lv = (c) => (pitSet.has(c) ? (c === "b" || c === "n" ? [0] : c === "s" ? [0, 1] : [1]) : [0]);
	const reach = () => {
		let S = null;
		for (let y = 0; y < H && !S; y++) for (let x = 0; x < W; x++) if (g[y][x] === "S") { S = [x, y]; break; }
		const seen = new Set([`${S[0]},${S[1]},0`]);
		const q = [[S[0], S[1], 0]];
		for (let h = 0; h < q.length; h++) {
			const [x, y, l] = q[h];
			if (g[y][x] === "s") for (const L of [0, 1]) if (!seen.has(`${x},${y},${L}`)) { seen.add(`${x},${y},${L}`); q.push([x, y, L]); }
			for (const [dx, dy] of D4) {
				const nx = x + dx, ny = y + dy, c = at(nx, ny);
				if (!PASS.has(c) || !lv(c).includes(l)) continue;
				const k = `${nx},${ny},${l}`;
				if (!seen.has(k)) { seen.add(k); q.push([nx, ny, l]); }
			}
		}
		return seen.size;
	};
	const rooms = findRooms(g, skip);
	// 방 안 일반 소품 치우기(숨는 곳·열쇠 상자는 그대로)
	const orig = g.map((row) => row.slice());
	for (const rm of rooms) for (const [x, y] of rm.cells) if (CLEAR.has(g[y][x])) g[y][x] = ".";
	let base = reach();
	const roomWhole = (rm) => {
		const free = rm.cells.filter(([x, y]) => PASS.has(g[y][x]));
		if (!free.length) return true;
		const inRoom = new Set(rm.cells.map((c) => c.join(",")));
		const seen = new Set([free[0].join(",")]);
		const q = [free[0]];
		while (q.length) {
			const [x, y] = q.pop();
			for (const [dx, dy] of D4) {
				const k = x + dx + "," + (y + dy);
				if (!inRoom.has(k) || seen.has(k) || !PASS.has(g[y + dy][x + dx])) continue;
				seen.add(k);
				q.push([x + dx, y + dy]);
			}
		}
		return seen.size === free.length;
	};
	const kinds = {};
	for (const rm of rooms) {
		const inRoom = new Set(rm.cells.map((c) => c.join(",")));
		const place = (x, y, ch) => {
			if (!inRoom.has(x + "," + y) || g[y][x] !== ".") return;
			const passable = PASS.has(ch);
			if (!passable) {
				// 문·아치·숨는 곳·열쇠 상자·계단 바로 앞, 방 밖으로 트인 칸 앞은 비운다
				if (D4.some(([dx, dy]) => BLOCKING_NEAR.has(at(x + dx, y + dy)))) return;
				if (D4.some(([dx, dy]) => at(x + dx, y + dy) !== "#" && !inRoom.has(x + dx + "," + (y + dy)))) return;
			}
			g[y][x] = ch;
			const n = reach();
			if (n === (passable ? base : base - 1) && roomWhole(rm)) base = n;
			else g[y][x] = ".";
		};
		const kind = THEME[id](rm, backLine(g, rm), place, r);
		kinds[kind] = (kinds[kind] || 0) + 1;
	}
	// 치운 칸 중 갇혀서 못 가는 곳(사물함 뒤 등)은 원래 소품으로 되돌린다
	const reachSet = () => {
		let S = null;
		for (let y = 0; y < H && !S; y++) for (let x = 0; x < W; x++) if (g[y][x] === "S") { S = [x, y]; break; }
		const seen = new Set([S.join(",")]);
		const q = [S];
		while (q.length) {
			const [x, y] = q.pop();
			for (const [dx, dy] of D4) {
				const k = x + dx + "," + (y + dy);
				if (seen.has(k) || !PASS.has(at(x + dx, y + dy))) continue;
				seen.add(k);
				q.push([x + dx, y + dy]);
			}
		}
		return seen;
	};
	const rs = reachSet();
	for (const rm of rooms) for (const [x, y] of rm.cells) if (g[y][x] === "." && CLEAR.has(orig[y][x]) && !rs.has(x + "," + y)) g[y][x] = orig[y][x];
	return { rows: g.map((row) => row.join("")), rooms: rooms.length, kinds };
}

function readRows(file) {
	const src = fs.readFileSync(file, "utf8");
	return [...src.match(/\tRows = \{([\s\S]*?)\n\t\},/)[1].matchAll(/"([^"]+)"/g)].map((m) => m[1]);
}
function writeRows(file, rows) {
	const src = fs.readFileSync(file, "utf8");
	const nl = src.includes("\r\n") ? "\r\n" : "\n";
	fs.writeFileSync(file, src.replace(/\tRows = \{[\s\S]*?\n\t\},/, "\tRows = {" + nl + rows.map((r) => `\t\t"${r}",`).join(nl) + nl + "\t},"));
}

// 갈림길: budget = 뚫을 곳 수(조금만), doors = 한 칸 구멍 중 문 비율. 출구 최단 거리는 원래보다 LOOP_DROP 칸 넘게 안 줄인다
const LOOPS = { 1: { budget: 8, doors: 0.4 }, 2: { budget: 8, doors: 0.4 }, 3: { budget: 8, doors: 0 }, 4: { budget: 8, doors: 0.5 }, 5: { budget: 8, doors: 0.2 } };
const LOOP_DROP = 14, LOOP_GAIN = 16;

const args = process.argv.slice(2);
const dry = args.includes("--dry");
const only = args.filter((a) => /^\d$/.test(a)).map(Number);
for (const id of only.length ? only : [1, 2, 3, 4, 5]) {
	const file = path.join(__dirname, "..", "src", "server", "Stages", `Stage${id}.luau`);
	let rows = readRows(file);
	const pits = id === 3 ? ["w"] : [];
	let info = "";
	if (THEME[id]) {
		// 1스테이지 왼쪽 위 20x20(자동 테스트가 쓰는 시작 구역)은 건드리지 않는다
		const skip = (x, y) => id === 1 && x < 20 && y < 20;
		const d = redecorate(rows, id, rng(id * 101), skip);
		rows = d.rows;
		info = `rooms ${d.rooms} ` + Object.entries(d.kinds).map(([k, v]) => `${k}${v}`).join(" ");
	}
	{
		const g = rows.map((row) => row.split(""));
		let fixed = 0;
		for (let y = 1; y < g.length - 1; y++)
			for (let x = 1; x < g[0].length - 1; x++)
				if (g[y][x] === "D" && D8.some(([dx, dy]) => "LZ".includes(g[y + dy][x + dx]))) { g[y][x] = "A"; fixed++; }
		rows = g.map((row) => row.join(""));
		if (fixed) info += ` doors->arch ${fixed}`;
	}
	const before = loopify(rows, { budget: 0, r: rng(1), min: 0, minGain: 99, pits, doors: 0 }).dist;
	const lp = loopify(rows, { ...LOOPS[id], r: rng(id * 7 + 3), min: before - LOOP_DROP, minGain: LOOP_GAIN, pits, maxLen: 2 });
	const bad = validate(lp.rows, pits);
	if (bad.length) {
		console.log(`stage ${id}: FAILED ${bad.slice(0, 4).join(" ")}`);
		process.exitCode = 1;
		continue;
	}
	console.log(`stage ${id}: ${info} | loops +${lp.made} | exit ${before} -> ${lp.dist} tiles (monster ${lp.monster})`);
	if (dry) console.log(lp.rows.join("\n"));
	else writeRows(file, lp.rows);
}
