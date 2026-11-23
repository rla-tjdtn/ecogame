// Generates the six stage layouts (src/server/Stages/StageN.luau "Rows") from per-chapter themes:
// rooms of several kinds + winding corridors/tunnels between them (rooms-and-mazes), doors/arches on the
// openings, pits / water channels crossed by bridges with stairs down, and chapter props. The exit is put
// where the shortest walk from the start is about TARGET tiles (1 tile = 8 studs; 150 tiles ≈ 2 min walking).
//   node tools/gen-stages.js            (all stages; rewrites the Rows block of each StageN.luau)
//   node tools/gen-stages.js 3 --dry    (one stage, print only)
// Stage 1 keeps the original 20x20 start area in its top-left corner (the automated tests use its tiles).
const fs = require("fs");
const path = require("path");

const TARGET = 160; // 격자 최단 경로(칸). 방 안에서는 대각선으로 가로질러 실제로는 조금 짧다 → 약 2분
const TOL = 6;
const D4 = [[1, 0], [-1, 0], [0, 1], [0, -1]];

const STAGE1_BLOCK = [
	"####################",
	"#S..#.......#...f..#",
	"#S..D..O.O..A..cc..#",
	"#...#.......#......#",
	"##.###A######.####D#",
	"#...#....#....#....#",
	"#.c.#.##.#.##.#.m..#",
	"#...A.#..A..#.A....#",
	"###.###.#####.###.##",
	"#.......#pppppppp..#",
	"#.#####..bbbbbbbb..#",
	"#.#...#.#ppppppps..#",
	"#.#.m.#..spppppp#..#",
	"#.#...D.#########D##",
	"#.##.##.#....#.....#",
	"#.......A.cc.A..O..#",
	"#####.###.v..#.....#",
	"#.....#.##D####.####",
	"#.c.....#.......A..#",
	"####################",
];

// ── 방 꾸미기 ──
// place(x, y, ch) 는 통로를 막지 않을 때만 놓는다.
const deco = {
	pillars(room, place, r, ch = "O") {
		for (let y = room.y + 1; y < room.y + room.h - 1; y += 2) for (let x = room.x + 1; x < room.x + room.w - 1; x += 2) if (r() < 0.8) place(x, y, ch);
	},
	alongWalls(room, place, r, chars, p) {
		for (let x = room.x; x < room.x + room.w; x++) {
			if (r() < p) place(x, room.y, chars[Math.floor(r() * chars.length)]);
			if (r() < p) place(x, room.y + room.h - 1, chars[Math.floor(r() * chars.length)]);
		}
		for (let y = room.y + 1; y < room.y + room.h - 1; y++) {
			if (r() < p) place(room.x, y, chars[Math.floor(r() * chars.length)]);
			if (r() < p) place(room.x + room.w - 1, y, chars[Math.floor(r() * chars.length)]);
		}
	},
	scatter(room, place, r, chars, n) {
		for (let k = 0; k < n; k++) place(room.x + Math.floor(r() * room.w), room.y + Math.floor(r() * room.h), chars[Math.floor(r() * chars.length)]);
	},
	corners(room, place, r, ch) {
		for (const [x, y] of [[room.x, room.y], [room.x + room.w - 1, room.y], [room.x, room.y + room.h - 1], [room.x + room.w - 1, room.y + room.h - 1]]) if (r() < 0.7) { place(x, y, ch); if (r() < 0.5) place(x + (x === room.x ? 1 : -1), y, ch); }
	},
	// 창고 선반 줄: 가로 줄마다 H 를 길게, 가운데·양끝에 통로
	racks(room, place, r) {
		const horiz = room.w >= room.h;
		const len = horiz ? room.w : room.h, wid = horiz ? room.h : room.w;
		for (let k = 1; k < wid - 1; k += 2) {
			const gap = 2 + Math.floor(r() * (len - 4));
			for (let t = 1; t < len - 1; t++) {
				if (t === gap || (len > 9 && Math.abs(t - gap) === 1 && r() < 0.5)) continue;
				const [x, y] = horiz ? [room.x + t, room.y + k] : [room.x + k, room.y + t];
				place(x, y, horiz ? "H" : "h");
			}
		}
	},
	containers(room, place, r) {
		for (let k = 0; k < 2 + Math.floor(r() * 3); k++) {
			const x = room.x + Math.floor(r() * (room.w - 1)), y = room.y + Math.floor(r() * room.h);
			const ch = r() < 0.3 ? "Q" : "K";
			place(x, y, ch);
			place(x + 1, y, ch);
		}
	},
	beds(room, place, r) {
		// 벽 쪽 줄에 침대를 한 칸 걸러
		const top = r() < 0.5;
		for (let x = room.x; x < room.x + room.w; x += 2) place(x, top ? room.y : room.y + room.h - 1, "R");
		if (room.h >= 5) for (let x = room.x; x < room.x + room.w; x += 2) place(x, top ? room.y + room.h - 1 : room.y, "R");
	},
	office(room, place, r) {
		for (let y = room.y + 1; y < room.y + room.h - 1; y += 2) for (let x = room.x + 1; x < room.x + room.w - 1; x += 2) if (r() < 0.7) place(x, y, "T");
		deco.alongWalls(room, place, r, ["k"], 0.25);
	},
	// 머리 위 대형 배관 한 줄(방을 가로질러). 받침 다리 때문에 1칸 통로에는 두지 않는다(괴물이 못 지나간다)
	pipeRun(room, place, r) {
		const y = room.y + Math.floor(room.h / 2);
		for (let x = room.x; x < room.x + room.w; x++) place(x, y, "P");
	},
	surgery(room, place, r) {
		place(room.x + Math.floor(room.w / 2), room.y + Math.floor(room.h / 2), "X");
		if (room.w >= 5) place(room.x + Math.floor(room.w / 2) + 2, room.y + Math.floor(room.h / 2), "X");
		deco.alongWalls(room, place, r, ["k"], 0.3);
	},
};

// ── 챕터 테마 ──
const THEMES = {
	1: {
		file: "Stage1.luau", W: 47, H: 41, seed: 1100, block: STAGE1_BLOCK, hides: 9, hidePrefer: ["machine", "storage"], searches: 8, searchPrefer: ["storage", "machine"],
		winding: 0.45, extra: 0.06, keepDead: 0.35, door: 0.3, arch: 0.35, corrArch: 0.04, corrDoor: 0.01, fans: 0.03,
		pits: "p",
		kinds: [
			{ name: "pillarHall", w: [5, 9], h: [5, 7], weight: 2, decorate: (rm, pl, r) => { deco.pillars(rm, pl, r); deco.corners(rm, pl, r, "c"); } },
			{ name: "machine", w: [3, 7], h: [3, 5], weight: 3, decorate: (rm, pl, r) => { deco.alongWalls(rm, pl, r, ["m", "m", "v"], 0.35); } },
			{ name: "storage", w: [3, 5], h: [3, 5], weight: 3, decorate: (rm, pl, r) => { deco.corners(rm, pl, r, "c"); deco.scatter(rm, pl, r, ["c"], 2); } },
			{ name: "pit", w: [7, 11], h: [7, 7], count: 2, band: { rows: 3, bridge: () => "b" }, weight: 0 },
		],
		rooms: 15,
	},
	2: {
		file: "Stage2.luau", W: 45, H: 41, seed: 2300, hides: 10, hidePrefer: ["office", "stock"], searches: 9, searchPrefer: ["stock", "yard", "office"],
		start: [5, 5], winding: 0.25, extra: 0.1, keepDead: 0.25, door: 0.45, arch: 0.25, corrArch: 0.0, corrDoor: 0.0, fans: 0.0,
		pits: "p",
		kinds: [
			{ name: "rackHall", w: [9, 15], h: [7, 11], count: 4, weight: 0, decorate: (rm, pl, r) => { deco.racks(rm, pl, r); } },
			{ name: "yard", w: [7, 11], h: [7, 9], count: 2, weight: 0, decorate: (rm, pl, r) => { deco.containers(rm, pl, r); deco.containers(rm, pl, r); deco.scatter(rm, pl, r, ["c"], 3); } },
			{ name: "office", w: [3, 5], h: [3, 5], weight: 3, decorate: (rm, pl, r) => { deco.alongWalls(rm, pl, r, ["c", "m"], 0.25); } },
			{ name: "stock", w: [3, 7], h: [3, 5], weight: 2, decorate: (rm, pl, r) => { deco.scatter(rm, pl, r, ["c", "c", "K"], 4); } },
		],
		rooms: 16,
	},
	3: {
		file: "Stage3.luau", W: 43, H: 41, seed: 3700, hides: 8, hidePrefer: ["pump", "junction"], searches: 8, searchPrefer: ["pump", "junction"],
		start: [5, 5], winding: 0.7, extra: 0.05, keepDead: 0.45, door: 0.05, arch: 0.55, corrArch: 0.07, corrDoor: 0.0, fans: 0.0,
		pits: "w",
		kinds: [
			{ name: "channel", w: [11, 15], h: [7, 7], count: 2, weight: 0, band: { rows: 3, bridge: (r) => (r() < 0.5 ? "n" : "b") } },
			{ name: "junction", w: [3, 5], h: [3, 5], weight: 4, decorate: (rm, pl, r) => { if (r() < 0.6) deco.pipeRun(rm, pl, r); deco.scatter(rm, pl, r, ["v", "m"], 2); } },
			{ name: "pump", w: [5, 7], h: [3, 5], weight: 2, decorate: (rm, pl, r) => { deco.pipeRun(rm, pl, r); deco.alongWalls(rm, pl, r, ["m", "v"], 0.3); } },
		],
		rooms: 14,
	},
	4: {
		file: "Stage4.luau", W: 45, H: 41, seed: 5892, hides: 14, hidePrefer: ["ward", "office"], searches: 10, searchPrefer: ["ward", "office", "surgery"],
		start: [5, 5], winding: 0.05, extra: 0.12, keepDead: 0.2, door: 0.8,
		halls: [[1, 11, 27, 1], [17, 21, 27, 1], [1, 31, 25, 1], [31, 1, 1, 15]], arch: 0.05, corrArch: 0.0, corrDoor: 0.03, fans: 0.0,
		pits: "p",
		kinds: [
			{ name: "ward", w: [5, 7], h: [3, 5], weight: 4, decorate: (rm, pl, r) => { deco.beds(rm, pl, r); } },
			{ name: "office", w: [3, 5], h: [3, 5], weight: 3, decorate: (rm, pl, r) => { deco.office(rm, pl, r); } },
			{ name: "surgery", w: [5, 7], h: [5, 5], weight: 1, count: 2, decorate: (rm, pl, r) => { deco.surgery(rm, pl, r); } },
			{ name: "lobby", w: [9, 13], h: [5, 5], weight: 0, count: 2, decorate: (rm, pl, r) => { deco.pillars(rm, pl, r); } },
			{ name: "lowerWard", w: [7, 9], h: [7, 9], count: 1, weight: 0, band: { rows: 3, bridge: () => null } },
		],
		rooms: 34,
	},
	5: {
		file: "Stage5.luau", W: 47, H: 43, seed: 5300, hides: 9, hidePrefer: ["cell"], searches: 9, searchPrefer: ["cell", "colonnade"],
		start: [5, 5], winding: 0.6, extra: 0.04, keepDead: 0.6, door: 0.15, arch: 0.35, corrArch: 0.05, corrDoor: 0.0, fans: 0.0,
		pits: "p",
		kinds: [
			{ name: "chasm", w: [9, 15], h: [7, 7], count: 3, weight: 0, band: { rows: 3, bridge: (r) => (r() < 0.6 ? "n" : "b") } },
			{ name: "colonnade", w: [7, 11], h: [5, 7], count: 2, weight: 0, decorate: (rm, pl, r) => { deco.pillars(rm, pl, r, "B"); } },
			{ name: "cell", w: [3, 3], h: [3, 3], weight: 3, decorate: (rm, pl, r) => { if (r() < 0.4) deco.pipeRun(rm, pl, r); deco.scatter(rm, pl, r, ["v", "m"], 1); } },
		],
		rooms: 10,
	},
	6: {
		file: "Stage6.luau", W: 45, H: 43, seed: 6100, hides: 12, hidePrefer: ["guest", "kitchen", "laundry"], searches: 10, searchPrefer: ["guest", "lobby", "banquet"],
		start: [5, 5], winding: 0.1, extra: 0.1, keepDead: 0.25, door: 0.75,
		halls: [[1, 11, 29, 1], [13, 21, 29, 1], [1, 31, 27, 1], [33, 1, 1, 17]], arch: 0.08, corrArch: 0.0, corrDoor: 0.02, fans: 0.0,
		pits: "p",
		kinds: [
			{ name: "guest", w: [3, 5], h: [3, 5], weight: 5, decorate: (rm, pl, r) => { deco.beds(rm, pl, r); deco.alongWalls(rm, pl, r, ["k"], 0.2); } },
			{ name: "lobby", w: [9, 13], h: [5, 7], weight: 0, count: 1, decorate: (rm, pl, r) => { deco.pillars(rm, pl, r); deco.scatter(rm, pl, r, ["T"], 2); } },
			{ name: "banquet", w: [9, 11], h: [5, 7], weight: 0, count: 1, decorate: (rm, pl, r) => { for (let y = rm.y + 1; y < rm.y + rm.h - 1; y += 2) for (let x = rm.x + 1; x < rm.x + rm.w - 1; x += 3) if (r() < 0.8) pl(x, y, "T"); } },
			{ name: "kitchen", w: [5, 7], h: [3, 5], weight: 0, count: 1, decorate: (rm, pl, r) => { deco.alongWalls(rm, pl, r, ["m", "m", "c"], 0.45); } },
			{ name: "laundry", w: [5, 5], h: [3, 5], weight: 0, count: 1, decorate: (rm, pl, r) => { deco.alongWalls(rm, pl, r, ["m", "c"], 0.4); } },
			{ name: "boiler", w: [9, 11], h: [7, 7], count: 1, band: { rows: 3, bridge: () => "b" }, weight: 0 },
		],
		rooms: 34,
	},
};

function rng(seed) {
	let s = (seed * 2654435761) >>> 0 || 1;
	return () => {
		s ^= s << 13; s >>>= 0; s ^= s >>> 17; s ^= s << 5; s >>>= 0;
		return s / 4294967296;
	};
}
const oddIn = (r, a, b) => { const lo = a % 2 ? a : a + 1; const n = Math.floor((b - lo) / 2) + 1; return lo + 2 * Math.floor(r() * Math.max(1, n)); };

function generate(theme, seed) {
	const r = rng(seed);
	const { W, H } = theme;
	const g = Array.from({ length: H }, () => Array(W).fill("#"));
	const reg = Array.from({ length: H }, () => Array(W).fill(-1));
	const reserved = Array.from({ length: H }, () => Array(W).fill(false));
	const rooms = [];
	let nreg = 0;
	const inb = (x, y) => x >= 0 && y >= 0 && x < W && y < H;
	const at = (x, y) => (inb(x, y) ? g[y][x] : "#");

	// 고정 블록(1스테이지 시작 구역)
	let blockReg = -1;
	if (theme.block) {
		blockReg = nreg++;
		theme.block.forEach((row, y) => [...row].forEach((c, x) => { g[y][x] = c; reserved[y][x] = true; if (c !== "#") reg[y][x] = blockReg; }));
	}
	const overlaps = (x, y, w, h) => {
		for (let yy = y - 1; yy <= y + h; yy++) for (let xx = x - 1; xx <= x + w; xx++) if (!inb(xx, yy) || reserved[yy][xx] || g[yy][xx] !== "#") return true;
		if (theme.block && x <= theme.block[0].length && y <= theme.block.length) return true;
		return false;
	};
	const addRoom = (x, y, w, h, kind) => {
		const id = nreg++;
		for (let yy = y; yy < y + h; yy++) for (let xx = x; xx < x + w; xx++) { g[yy][xx] = "."; reg[yy][xx] = id; }
		const room = { x, y, w, h, kind, id };
		if (kind && kind.band) {
			const top = 1 + Math.floor(r() * Math.max(1, h - kind.band.rows - 1));
			room.band = { y0: y + top, rows: kind.band.rows, bridge: kind.band.bridge(r) };
		}
		rooms.push(room);
		return room;
	};
	let startRoom = null;
	if (!theme.block) {
		startRoom = addRoom(1, 1, theme.start[0], theme.start[1], null);
		for (const [x, y] of [[1, 1], [2, 1], [1, 3], [2, 3]]) g[y][x] = "S";
	}
	// 긴 복도(병원 등): 정해진 자리
	for (const [x, y, w, h] of theme.halls || []) if (!overlaps(x, y, w, h)) addRoom(x, y, w, h, { name: "hall" });
	// 정해진 수의 특별한 방 먼저, 나머지는 가중치로
	const special = theme.kinds.filter((k) => k.count);
	const plain = theme.kinds.filter((k) => !k.count && k.weight);
	const wsum = plain.reduce((a, k) => a + k.weight, 0);
	const tryPlace = (kind, tries) => {
		for (let t = 0; t < tries; t++) {
			const w = oddIn(r, kind.w[0], kind.w[1]), h = oddIn(r, kind.h[0], kind.h[1]);
			const x = oddIn(r, 1, W - w - 1), y = oddIn(r, 1, H - h - 1);
			if (x + w > W - 1 || y + h > H - 1) continue;
			if (!overlaps(x, y, w, h)) return addRoom(x, y, w, h, kind);
		}
		return null;
	};
	for (const k of special) for (let n = 0; n < k.count; n++) if (!tryPlace(k, 400)) return null;
	for (let n = 0; n < theme.rooms; n++) {
		let pick = r() * wsum, kind = plain[0];
		for (const k of plain) { pick -= k.weight; if (pick <= 0) { kind = k; break; } }
		tryPlace(kind, 200);
	}

	// 통로(미로) 채우기
	const isMazeTile = Array.from({ length: H }, () => Array(W).fill(false));
	const canCarve = (x, y, dx, dy) => {
		if (!inb(x + dx * 3, y + dy * 3)) return false;
		const tx = x + dx * 2, ty = y + dy * 2;
		return !reserved[ty][tx] && !reserved[y + dy][x + dx] && g[ty][tx] === "#";
	};
	for (let y = 1; y < H; y += 2)
		for (let x = 1; x < W; x += 2) {
			if (g[y][x] !== "#" || reserved[y][x]) continue;
			const id = nreg++;
			const carve = (cx, cy) => { g[cy][cx] = "."; reg[cy][cx] = id; isMazeTile[cy][cx] = true; };
			carve(x, y);
			const cells = [[x, y]];
			let last = null;
			while (cells.length) {
				const [cx, cy] = cells[cells.length - 1];
				const opts = D4.filter(([dx, dy]) => canCarve(cx, cy, dx, dy));
				if (!opts.length) { cells.pop(); last = null; continue; }
				const d = last && opts.some((o) => o[0] === last[0] && o[1] === last[1]) && r() > theme.winding ? last : opts[Math.floor(r() * opts.length)];
				carve(cx + d[0], cy + d[1]);
				carve(cx + d[0] * 2, cy + d[1] * 2);
				cells.push([cx + d[0] * 2, cy + d[1] * 2]);
				last = d;
			}
		}

	const roomAt = (x, y) => rooms.find((rm) => x >= rm.x && x < rm.x + rm.w && y >= rm.y && y < rm.y + rm.h);
	const inBand = (x, y) => { const rm = roomAt(x, y); return rm && rm.band && y >= rm.band.y0 && y < rm.band.y0 + rm.band.rows; };

	// 연결 후보: 벽 한 칸을 사이에 둔 서로 다른 영역
	const connectors = [];
	for (let y = 1; y < H - 1; y++)
		for (let x = 1; x < W - 1; x++) {
			if (g[y][x] !== "#" || reserved[y][x]) continue;
			for (const [dx, dy] of [[1, 0], [0, 1]]) {
				const a = [x - dx, y - dy], b = [x + dx, y + dy];
				const ra = reg[a[1]][a[0]], rb = reg[b[1]][b[0]];
				if (ra < 0 || rb < 0 || ra === rb) continue;
				if (inBand(a[0], a[1]) || inBand(b[0], b[1])) continue;
				if ((ra === blockReg && g[a[1]][a[0]] !== ".") || (rb === blockReg && g[b[1]][b[0]] !== ".")) continue;
				connectors.push({ tiles: [[x, y]], regions: [ra, rb], side: [a, b] });
			}
		}
	// 고정 블록의 오른쪽·아래 벽(두 칸 두께)
	if (theme.block) {
		const bw = theme.block[0].length, bh = theme.block.length;
		for (let y = 1; y < bh - 1; y++)
			if (g[y][bw - 2] === "." && reg[y][bw + 1] >= 0) connectors.push({ tiles: [[bw - 1, y], [bw, y]], regions: [blockReg, reg[y][bw + 1]], side: [[bw - 2, y], [bw + 1, y]], block: true });
		for (let x = 1; x < bw - 1; x++)
			if (g[bh - 2][x] === "." && inb(x, bh + 1) && reg[bh + 1][x] >= 0) connectors.push({ tiles: [[x, bh - 1], [x, bh]], regions: [blockReg, reg[bh + 1][x]], side: [[x, bh - 2], [x, bh + 1]], block: true });
	}

	const merged = Array.from({ length: nreg }, (_, i) => i);
	const find = (i) => (merged[i] === i ? i : (merged[i] = find(merged[i])));
	const opened = [];
	const open = (c) => { for (const [x, y] of c.tiles) { g[y][x] = "."; } opened.push(c); };
	const nearOpened = (c) => opened.some((o) => o.tiles.some(([ox, oy]) => c.tiles.some(([x, y]) => Math.abs(ox - x) + Math.abs(oy - y) <= 2)));
	let pool = connectors.slice();
	// 블록 연결은 덜 고르게(블록이 첫 영역)
	while (pool.length) {
		const c = pool[Math.floor(r() * pool.length)];
		const ra = find(c.regions[0]), rb = find(c.regions[1]);
		if (ra !== rb) { open(c); merged[rb] = ra; find(rb); }
		pool = pool.filter((o) => {
			if (find(o.regions[0]) !== find(o.regions[1])) return true;
			if (o !== c && r() < theme.extra && !nearOpened(o) && !o.block) open(o);
			return false;
		});
	}
	// 띠(구덩이·수로) 방은 위쪽·아래쪽 모두 입구가 있어야 다리가 의미가 있다
	for (const rm of rooms.filter((q) => q.band)) {
		const part = (y) => (y < rm.band.y0 ? "top" : "bottom");
		const has = { top: false, bottom: false };
		const touches = (c) => c.side.find(([x, y]) => x >= rm.x && x < rm.x + rm.w && y >= rm.y && y < rm.y + rm.h);
		for (const c of opened) { const s = touches(c); if (s) has[part(s[1])] = true; }
		for (const p of ["top", "bottom"]) {
			if (has[p]) continue;
			const cands = connectors.filter((c) => { const s = touches(c); return s && part(s[1]) === p && !nearOpened(c); });
			if (!cands.length) return null;
			open(cands[Math.floor(r() * cands.length)]);
		}
	}

	// 막다른 길 줄이기(일부는 남긴다)
	const isOpen = (x, y) => at(x, y) !== "#";
	const openN = (x, y) => D4.filter(([dx, dy]) => isOpen(x + dx, y + dy)).length;
	const keep = new Set();
	for (let y = 1; y < H - 1; y++)
		for (let x = 1; x < W - 1; x++)
			if (isMazeTile[y][x] && isOpen(x, y) && openN(x, y) === 1 && r() < theme.keepDead) {
				let [cx, cy] = [x, y], prev = null;
				for (let s = 0; s < 200; s++) {
					keep.add(cx + "," + cy);
					const nxt = D4.map(([dx, dy]) => [cx + dx, cy + dy]).filter(([nx, ny]) => isOpen(nx, ny) && !(prev && nx === prev[0] && ny === prev[1]));
					if (nxt.length !== 1 || !isMazeTile[nxt[0][1]][nxt[0][0]] || openN(nxt[0][0], nxt[0][1]) > 2) break;
					prev = [cx, cy]; [cx, cy] = nxt[0];
				}
			}
	for (let changed = true; changed; ) {
		changed = false;
		for (let y = 1; y < H - 1; y++)
			for (let x = 1; x < W - 1; x++)
				if (isOpen(x, y) && !reserved[y][x] && !roomAt(x, y) && openN(x, y) <= 1 && !keep.has(x + "," + y)) { g[y][x] = "#"; changed = true; }
	}

	// 문·아치
	const between = (x, y) => {
		const wx = at(x - 1, y) === "#" && at(x + 1, y) === "#", wz = at(x, y - 1) === "#" && at(x, y + 1) === "#";
		const ox = at(x - 1, y) !== "#" && at(x + 1, y) !== "#", oz = at(x, y - 1) !== "#" && at(x, y + 1) !== "#";
		return (wx && oz) || (wz && ox);
	};
	const nearDoor = (x, y) => D4.some(([dx, dy]) => "DA".includes(at(x + dx, y + dy)));
	for (const c of opened) {
		if (c.block) continue;
		const [x, y] = c.tiles[0];
		if (g[y][x] !== "." || !between(x, y) || nearDoor(x, y)) continue;
		const q = r();
		if (q < theme.door) g[y][x] = "D";
		else if (q < theme.door + theme.arch) g[y][x] = "A";
	}
	for (let y = 1; y < H - 1; y++)
		for (let x = 1; x < W - 1; x++) {
			if (g[y][x] !== "." || reserved[y][x] || roomAt(x, y) || !between(x, y) || nearDoor(x, y)) continue;
			const q = r();
			if (q < theme.corrArch) g[y][x] = "A";
			else if (q < theme.corrArch + theme.corrDoor) g[y][x] = "D";
		}

	// 띠 찍기: 구덩이/수로 + 다리 + 계단
	for (const rm of rooms.filter((q) => q.band)) {
		const { y0, rows, bridge } = rm.band;
		for (let y = y0; y < y0 + rows; y++) for (let x = rm.x; x < rm.x + rm.w; x++) g[y][x] = theme.pits;
		const bc = rm.x + Math.floor(rm.w / 2) + (r() < 0.5 ? -1 : 1) * Math.floor(r() * (rm.w / 4));
		if (bridge) for (let y = y0; y < y0 + rows; y++) g[y][bc] = bridge;
		const left = rm.x + 1 + Math.floor(r() * Math.max(1, bc - rm.x - 2));
		g[y0][left] = "s";
		g[y0 + rows - 1][bridge ? Math.min(bc - 1, left + 1 + Math.floor(r() * 2)) : left + 2] = "s";
		if (bridge) g[y0 + (r() < 0.5 ? 0 : rows - 1)][Math.min(rm.x + rm.w - 2, bc + 2 + Math.floor(r() * 2))] = "s";
	}

	// 머리 위 소품(통로를 막지 않는다)
	for (let y = 1; y < H - 1; y++)
		for (let x = 1; x < W - 1; x++) {
			if (g[y][x] !== "." || reserved[y][x]) continue;
			if (theme.fans && r() < theme.fans) g[y][x] = "f";
		}

	const pitSet = new Set(["p", "b", "s", "n", theme.pits]);
	const PASS = new Set([".", "S", "E", "D", "A", "f", "P", "p", "w", "b", "n", "s"]);
	const lv = (c) => (pitSet.has(c) ? (c === "b" || c === "n" ? [0] : c === "s" ? [0, 1] : [1]) : [0]);
	const bfs = (agent) => {
		let S = null;
		for (let y = 0; y < H && !S; y++) for (let x = 0; x < W; x++) if (g[y][x] === "S") { S = [x, y]; break; }
		const dist = new Map([[`${S[0]},${S[1]},0`, 0]]);
		const q = [[S[0], S[1], 0]];
		while (q.length) {
			const [x, y, l] = q.shift();
			const d = dist.get(`${x},${y},${l}`);
			if (g[y][x] === "s") for (const L of [0, 1]) if (!dist.has(`${x},${y},${L}`)) { dist.set(`${x},${y},${L}`, d); q.push([x, y, L]); }
			for (const [dx, dy] of D4) {
				const nx = x + dx, ny = y + dy, c = at(nx, ny);
				if (!PASS.has(c) || (agent === "monster" && c === "n") || !lv(c).includes(l)) continue;
				const k = `${nx},${ny},${l}`;
				if (!dist.has(k)) { dist.set(k, d + 1); q.push([nx, ny, l]); }
			}
		}
		return dist;
	};
	const reachCount = () => bfs("player").size;

	// 방 꾸미기(막히면 되돌린다)
	const avoid = (x, y) => D4.some(([dx, dy]) => "DASEsbnpw".includes(at(x + dx, y + dy)) && at(x + dx, y + dy) !== ".") || reserved[y][x];
	let base = reachCount();
	// 소품이 방을 둘로 가르면 안 된다(가르면 지나가던 방을 돌아가게 되어 실제 경로와 달라진다)
	const roomWhole = (rm) => {
		const free = [];
		for (let y = rm.y; y < rm.y + rm.h; y++) for (let x = rm.x; x < rm.x + rm.w; x++) if (PASS.has(g[y][x])) free.push([x, y]);
		if (!free.length) return true;
		const seen = new Set([free[0].join(",")]);
		const q = [free[0]];
		while (q.length) {
			const [x, y] = q.pop();
			for (const [dx, dy] of D4) {
				const nx = x + dx, ny = y + dy, k = nx + "," + ny;
				if (nx < rm.x || ny < rm.y || nx >= rm.x + rm.w || ny >= rm.y + rm.h || seen.has(k) || !PASS.has(g[ny][nx])) continue;
				seen.add(k);
				q.push([nx, ny]);
			}
		}
		return seen.size === free.length;
	};
	const place = (x, y, ch) => {
		if (!inb(x, y) || g[y][x] !== "." || avoid(x, y)) return;
		const rm = roomAt(x, y);
		if (rm && D4.some(([dx, dy]) => at(x + dx, y + dy) !== "#" && roomAt(x + dx, y + dy) !== rm)) return; // 방 입구 바로 안쪽
		g[y][x] = ch;
		const n = reachCount();
		if (n === base - 1 && (!rm || roomWhole(rm))) base = n;
		else g[y][x] = ".";
	};
	for (const rm of rooms) if (rm.kind && rm.kind.decorate && !rm.band) rm.kind.decorate(rm, place, r);

	// 숨는 곳(L): 벽에 등을 대고 방 안쪽을 보는 칸. 어울리는 방을 먼저, 막다른 통로 끝도 가끔
	const hides = [];
	const backWall = (x, y) => D4.some(([dx, dy]) => at(x + dx, y + dy) === "#" && at(x - dx, y - dy) !== "#");
	const cands = [];
	for (let y = 1; y < H - 1; y++)
		for (let x = 1; x < W - 1; x++) {
			if (g[y][x] !== "." || reserved[y][x] || avoid(x, y) || !backWall(x, y)) continue;
			const rm = roomAt(x, y);
			if (rm && (rm.band || rm === startRoom || (rm.kind && rm.kind.name === "hall"))) continue;
			if (!rm && openN(x, y) !== 1) continue; // 통로는 막다른 끝만
			const pref = rm && rm.kind && (theme.hidePrefer || []).includes(rm.kind.name) ? 0 : rm ? 1 : 2;
			cands.push({ x, y, k: pref + r() });
		}
	cands.sort((a, b) => a.k - b.k);
	for (const c of cands) {
		if (hides.length >= (theme.hides || 0)) break;
		if (hides.some((h) => Math.abs(h.x - c.x) + Math.abs(h.y - c.y) < 7)) continue;
		place(c.x, c.y, "L");
		if (g[c.y][c.x] === "L") hides.push(c);
	}

	// 뒤질 수 있는 상자·서랍(Z): 그중 하나에 열쇠(서버가 라운드마다 고른다). 맵 곳곳에 흩어 놓는다
	const searches = [];
	const zc = [];
	for (let y = 1; y < H - 1; y++)
		for (let x = 1; x < W - 1; x++) {
			if (g[y][x] !== "." || reserved[y][x] || avoid(x, y) || !backWall(x, y)) continue;
			const rm = roomAt(x, y);
			if (rm && (rm.band || rm === startRoom || (rm.kind && rm.kind.name === "hall"))) continue;
			if (!rm && openN(x, y) !== 1) continue;
			const pref = rm && rm.kind && (theme.searchPrefer || []).includes(rm.kind.name) ? 0 : rm ? 0.6 : 1.2;
			zc.push({ x, y, k: pref + r() });
		}
	zc.sort((a, b) => a.k - b.k);
	for (const c of zc) {
		if (searches.length >= (theme.searches || 0)) break;
		if (searches.some((h) => Math.abs(h.x - c.x) + Math.abs(h.y - c.y) < 8)) continue;
		if (hides.some((h) => Math.abs(h.x - c.x) + Math.abs(h.y - c.y) < 2)) continue;
		place(c.x, c.y, "Z");
		if (g[c.y][c.x] === "Z") searches.push(c);
	}

	// 닿지 않는 곳은 벽으로
	const reach = bfs("player");
	for (let y = 0; y < H; y++)
		for (let x = 0; x < W; x++)
			if (PASS.has(g[y][x]) && !reserved[y][x] && ![0, 1].some((l) => reach.has(`${x},${y},${l}`))) g[y][x] = "#";

	// 출구: 열린 칸 하나에만 붙은 벽 칸, 최단 거리가 TARGET 에 가장 가까운 곳
	const pd = bfs("player"), md = bfs("monster");
	let best = null;
	for (let y = 1; y < H - 1; y++)
		for (let x = 1; x < W - 1; x++) {
			if (g[y][x] !== "#" || reserved[y][x]) continue;
			const ns = D4.map(([dx, dy]) => [x + dx, y + dy]).filter(([nx, ny]) => at(nx, ny) !== "#");
			if (ns.length !== 1) continue;
			const [nx, ny] = ns[0];
			if (g[ny][nx] !== "." || !pd.has(`${nx},${ny},0`) || !md.has(`${nx},${ny},0`)) continue;
			const d = pd.get(`${nx},${ny},0`) + 1;
			const score = Math.abs(d - TARGET) <= TOL ? -(Math.abs(x - 1) + Math.abs(y - 1)) : 1000 + Math.abs(d - TARGET);
			if (!best || score < best.score) best = { x, y, d, score };
		}
	if (!best || Math.abs(best.d - TARGET) > TOL) return { fail: "exit", maxd: best && best.d };
	g[best.y][best.x] = "E";
	const deadEnds = (() => { let n = 0; for (let y = 1; y < H - 1; y++) for (let x = 1; x < W - 1; x++) if (g[y][x] === "." && openN(x, y) === 1) n++; return n; })();
	return { rows: g.map((row) => row.join("")), dist: best.d, rooms: rooms.length, deadEnds, hides: hides.length, searches: searches.length, monsterDist: md.get(`${D4.map(([dx, dy]) => [best.x + dx, best.y + dy]).find(([nx, ny]) => at(nx, ny) !== "#").join(",")},0`) + 1 };
}

// check-layout.js 와 같은 규칙으로 검사
function validate(rows, pitExtra) {
	const H = rows.length, W = rows[0].length, bad = [];
	const at = (i, j) => (j < 0 || j >= H || i < 0 || i >= W ? "#" : rows[j][i]);
	const wall = (i, j) => at(i, j) === "#";
	const pits = new Set(["p", "b", "s", "n", ...pitExtra]);
	for (let j = 0; j < H; j++)
		for (let i = 0; i < W; i++) {
			const c = at(i, j);
			if (c === "D" || c === "A") {
				const wx = wall(i - 1, j) && wall(i + 1, j), wz = wall(i, j - 1) && wall(i, j + 1);
				const ox = !wall(i - 1, j) && !wall(i + 1, j), oz = !wall(i, j - 1) && !wall(i, j + 1);
				if (!((wx && oz) || (wz && ox))) bad.push(`${c}@${i},${j}`);
			}
			if (c === "E" && D4.filter(([a, b]) => !wall(i + a, j + b)).length !== 1) bad.push("exit entrances");
			if (c === "s" && D4.filter(([a, b]) => { const n = at(i + a, j + b); return n !== "#" && !pits.has(n); }).length !== 1) bad.push(`stairs@${i},${j}`);
		}
	return bad;
}

function writeRows(file, rows) {
	const src = fs.readFileSync(file, "utf8");
	const out = src.replace(/\tRows = \{[\s\S]*?\n\t\},/, "\tRows = {\n" + rows.map((r) => `\t\t"${r}",`).join("\n") + "\n\t},");
	fs.writeFileSync(file, out);
}

const args = process.argv.slice(2);
const dry = args.includes("--dry");
const only = args.filter((a) => /^\d$/.test(a)).map(Number);
for (const id of only.length ? only : [1, 2, 3, 4, 5, 6]) {
	const theme = THEMES[id];
	let res = null, tries = 0, lastFail = null;
	for (let s = theme.seed; s < theme.seed + 3000 && !res; s++) {
		tries++;
		const out = generate(theme, s);
		if (!out || out.fail) { lastFail = out; continue; }
		const bad = validate(out.rows, theme.pits === "w" ? ["w"] : []);
		if (bad.length) { lastFail = { fail: bad.join(" ") }; continue; }
		res = { ...out, seed: s };
	}
	if (!res) { console.log(`stage ${id}: FAILED after ${tries} seeds`, lastFail); process.exitCode = 1; continue; }
	console.log(`stage ${id}: seed ${res.seed} ${theme.W}x${theme.H} rooms ${res.rooms} hides ${res.hides} searches ${res.searches} exit ${res.dist} tiles (monster ${res.monsterDist}) dead-ends ${res.deadEnds}`);
	if (dry) console.log(res.rows.join("\n"));
	else writeRows(path.join(__dirname, "..", "src", "server", "Stages", theme.file), res.rows);
}
