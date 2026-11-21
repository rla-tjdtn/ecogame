// 챕터마다 실제 그 장소처럼 짠 평면도(설계도)로 스테이지 1~4 의 Rows 를 만든다. (5 심층 미로는 tools/gen-stages.js 의 미로)
//   4 폐병원   : 로비 → 긴 복도 3줄(양옆에 병실·진료실·수술실·간호사실·창고·화장실), 복도 끝 엘리베이터 홀/계단으로 다음 복도
//   2 물류 창고: 하역장 있는 큰 창고(선반 줄 사이 통로) → 사무동 복도 → 두 번째 큰 창고 → 하역장 출구
//   3 하수도   : 물길 터널 4줄(양옆 좁은 통로 + 가운데 물, 다리·계단) → 아치 있는 관리 통로 → 펌프실·밸브실·막다른 지선
//   1 지하 시설: 시작 구역(20x20, 자동 테스트용 그대로) → 연구동 복도 2줄(실험실·기계실) → 발전실 홀(구덩이 위 통로) → 창고동 → 비상구
// 출구까지 최단 거리가 TARGET 범위(걸어서 약 2분)가 되는 무작위 변형을 시드를 바꿔 가며 찾는다.
//   node tools/gen-themed.js            (1~4 모두, StageN.luau 의 Rows 를 덮어쓴다)
//   node tools/gen-themed.js 4 --dry    (하나만, 출력만)
const fs = require("fs");
const path = require("path");

const TARGET = [146, 170];
const D4 = [[1, 0], [-1, 0], [0, 1], [0, -1]];
const D8 = [...D4, [1, 1], [1, -1], [-1, 1], [-1, -1]];
const PASS = new Set([".", "S", "E", "D", "A", "f", "P", "p", "w", "b", "n", "s"]);

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
	"#.......#ppppppps..#",
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

function rng(seed) {
	let s = (seed * 2654435761) >>> 0 || 1;
	return () => {
		s ^= s << 13; s >>>= 0; s ^= s >>> 17; s ^= s << 5; s >>>= 0;
		return s / 4294967296;
	};
}
const ri = (r, a, b) => a + Math.floor(r() * (b - a + 1));

// ── 평면 ──
function Plan(W, H, r, pits) {
	const g = Array.from({ length: H }, () => Array(W).fill("#"));
	const reserved = Array.from({ length: H }, () => Array(W).fill(false));
	const rooms = [];
	const pitSet = new Set(["p", "b", "s", "n", ...(pits || [])]);
	const P = {
		W, H, g, r, rooms, reserved, pitSet,
		at: (x, y) => (x < 0 || y < 0 || x >= W || y >= H ? "#" : g[y][x]),
		set: (x, y, c) => { if (x > 0 && y > 0 && x < W - 1 && y < H - 1) g[y][x] = c; },
		carve(x0, y0, x1, y1, c = ".") { for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) P.set(x, y, c); },
		room(x0, y0, x1, y1, kind, door) {
			P.carve(x0, y0, x1, y1);
			const rm = { x: x0, y: y0, w: x1 - x0 + 1, h: y1 - y0 + 1, kind, door: door || null };
			rooms.push(rm);
			return rm;
		},
		roomAt: (x, y) => rooms.find((rm) => x >= rm.x && x < rm.x + rm.w && y >= rm.y && y < rm.y + rm.h),
		// 띠(가로 한 줄 방들)를 폭 wmin~wmax 방으로 나누고 side("up"/"down") 쪽 벽에 문
		band(x0, x1, y0, y1, side, pick) {
			let x = x0;
			const out = [];
			while (x <= x1) {
				let w = ri(r, 3, 7);
				if (x1 - (x + w) < 3) w = x1 - x + 1;
				const kind = pick(w, out.length);
				const rm = P.room(x, y0, x + w - 1, y1, kind);
				const dx = ri(r, x + 1, x + w - 2 >= x + 1 ? x + w - 2 : x + 1);
				const dy = side === "up" ? y0 - 1 : y1 + 1;
				P.set(dx, dy, "D");
				rm.door = { x: dx, y: dy, side };
				out.push(rm);
				x += w + 1;
			}
			return out;
		},
	};
	return P;
}

// ── 방 꾸미기(통로를 막지 않을 때만 놓는다) ──
// back: 문 반대쪽 벽 줄(침대·캐비닛을 붙인다)
const backRow = (rm) => (rm.door && rm.door.side === "up" ? rm.y + rm.h - 1 : rm.y);
const frontRow = (rm) => (rm.door && rm.door.side === "up" ? rm.y : rm.y + rm.h - 1);
const D = {
	ward(rm, place, r) {
		const y = backRow(rm);
		for (let k = 0; k < rm.w; k++) {
			const x = rm.x + k;
			if (k % 2 === 0) place(x, y, "R");
			else if (k === 1) place(x, y, "Z");
		}
		place(rm.x + rm.w - 1, frontRow(rm), "L");
	},
	office(rm, place, r) {
		place(rm.x + Math.floor(rm.w / 2), rm.y + Math.floor(rm.h / 2), "T");
		place(rm.x, backRow(rm), "k");
		place(rm.x + rm.w - 1, backRow(rm), "Z");
	},
	surgery(rm, place) {
		place(rm.x + Math.floor(rm.w / 2), rm.y + Math.floor(rm.h / 2), "X");
		for (let k = 0; k < rm.w; k += 2) place(rm.x + k, backRow(rm), "k");
	},
	storage(rm, place) {
		for (let k = 0; k < rm.w; k++) if (k !== Math.floor(rm.w / 2)) place(rm.x + k, backRow(rm), "k");
		place(rm.x, frontRow(rm), "L");
	},
	nurse(rm, place) {
		for (let k = 1; k < rm.w - 1; k++) place(rm.x + k, rm.y + Math.floor(rm.h / 2), "T");
		place(rm.x + rm.w - 1, backRow(rm), "Z");
	},
	bath() {},
	lobby(rm, place) {
		for (let k = 2; k < rm.w - 1; k += 3) place(rm.x + k, rm.y + rm.h - 2, "O");
		place(rm.x + rm.w - 2, rm.y, "T");
		place(rm.x + rm.w - 3, rm.y, "T");
	},
	// 창고
	stock(rm, place, r) {
		for (let k = 0; k < rm.w; k += 2) place(rm.x + k, backRow(rm), r() < 0.5 ? "c" : "K");
		place(rm.x + rm.w - 1, frontRow(rm), "Z");
	},
	whOffice(rm, place) {
		place(rm.x + Math.floor(rm.w / 2), rm.y + Math.floor(rm.h / 2), "T");
		place(rm.x, backRow(rm), "L");
		place(rm.x + rm.w - 1, backRow(rm), "Z");
	},
	breakRoom(rm, place) {
		place(rm.x + 1, rm.y + Math.floor(rm.h / 2), "T");
		place(rm.x + rm.w - 1, backRow(rm), "m");
	},
	// 창고 큰 홀: 벽가에 컨테이너(2단 포함)·상자·지게차
	hallA(rm, place, r) {
		for (let x = rm.x + 20; x < rm.x + rm.w - 1; x += 2) place(x, rm.y, r() < 0.35 ? "Q" : "K");
		for (let x = rm.x + 6; x < rm.x + 18; x += 3) place(x, rm.y, "c");
		place(rm.x + 12, rm.y + 1, "m");
	},
	hallB(rm, place, r) {
		const y = rm.y + rm.h - 1;
		for (let x = rm.x + 1; x < rm.x + rm.w - 6; x += 2) place(x, y, r() < 0.4 ? "Q" : r() < 0.7 ? "K" : "c");
		for (let x = rm.x + 3; x < rm.x + rm.w - 8; x += 5) place(x, y - 1, "m");
	},
	// 하수도
	pump(rm, place) {
		const y = rm.y + Math.floor(rm.h / 2);
		for (let x = rm.x; x < rm.x + rm.w; x++) place(x, y, "P");
		place(rm.x, rm.y, "m");
		place(rm.x + rm.w - 1, rm.y + rm.h - 1, "m");
		place(rm.x + rm.w - 1, rm.y, "Z");
	},
	valve(rm, place) {
		place(rm.x + 1, rm.y, "v");
		place(rm.x + rm.w - 2, rm.y + rm.h - 1, "v");
		place(rm.x, rm.y + rm.h - 1, "L");
		place(rm.x + rm.w - 1, rm.y, "Z");
	},
	// 시설
	lab(rm, place, r) {
		for (let k = 0; k < rm.w; k += 2) place(rm.x + k, backRow(rm), r() < 0.6 ? "m" : "v");
		place(rm.x + Math.floor(rm.w / 2), rm.y + Math.floor(rm.h / 2), "T");
		place(rm.x + rm.w - 1, frontRow(rm), "Z");
	},
	machine(rm, place) {
		for (let k = 0; k < rm.w; k += 2) place(rm.x + k, backRow(rm), "m");
		place(rm.x, frontRow(rm), "L");
	},
	control(rm, place) {
		for (let k = 1; k < rm.w - 1; k += 2) place(rm.x + k, backRow(rm), "T");
		place(rm.x + rm.w - 1, frontRow(rm), "Z");
	},
	crates(rm, place, r) {
		for (let k = 0; k < rm.w; k++) if (r() < 0.6) place(rm.x + k, backRow(rm), "c");
		place(rm.x, frontRow(rm), "L");
		place(rm.x + rm.w - 1, frontRow(rm), "Z");
	},
};

// ── 설계도 ──
const ARCH = {};

// 4 폐병원 (45x41): 복도 3줄을 지그재그로(엘리베이터 홀은 오른쪽, 계단은 왼쪽)
ARCH[4] = (r) => {
	const P = Plan(45, 41, r);
	const xEnd = ri(r, 41, 43);
	P.carve(1, 6, 43, 7); // 1층 복도
	P.carve(1, 19, 43, 20); // 2층 복도
	P.carve(1, 32, xEnd - 1, 33); // 3층 복도
	P.set(xEnd, 32, "E"); // 비상구
	for (let x = xEnd; x <= 43; x++) P.set(x, 33, "#");
	P.room(41, 8, 43, 18, "hall"); // 엘리베이터 홀(1층 → 2층)
	P.room(1, 21, 3, 31, "hall"); // 계단(2층 → 3층)
	const lobbyW = ri(r, 9, 12);
	const lobby = P.room(1, 1, lobbyW, 4, "lobby", { side: "down" });
	P.carve(2, 5, lobbyW - 1, 5); // 로비는 복도로 트여 있다
	for (const [x, y] of [[1, 1], [2, 1], [1, 3], [2, 3]]) P.set(x, y, "S");
	let surg = 0, nurse = 0;
	const pick = (w, i) => {
		if (w >= 5 && surg < 2 && r() < 0.18) { surg++; return "surgery"; }
		if (w >= 5 && nurse < 2 && r() < 0.15) { nurse++; return "nurse"; }
		if (w >= 5) return r() < 0.75 ? "ward" : "storage";
		if (w === 3) return r() < 0.4 ? "bath" : r() < 0.5 ? "storage" : "office";
		return r() < 0.6 ? "office" : "storage";
	};
	P.band(lobbyW + 2, 43, 1, 4, "down", pick);
	P.band(1, 39, 9, 12, "up", pick);
	P.band(1, 39, 14, 17, "down", pick);
	P.band(5, 43, 22, 25, "up", pick);
	P.band(5, 43, 27, 30, "down", pick);
	P.band(1, 43, 35, 38, "up", pick);
	return P;
};

// 2 물류 창고 (45x41): 창고 A(선반 줄 지그재그) → 사무동 복도 → 창고 B → 하역장 출구
ARCH[2] = (r) => {
	const P = Plan(45, 41, r);
	P.room(1, 1, 43, 12, "hallA");
	// 선반 줄: 한쪽 끝만 트여 있어 줄 사이 통로를 지그재그로 지나간다(가운데 틈도 가끔)
	const racks = (x0, x1, rows, firstGapRight) => {
		rows.forEach((y, i) => {
			const gapRight = (i % 2 === 0) === firstGapRight;
			const gw = ri(r, 2, 3);
			for (let x = x0; x <= x1; x++) {
				const inGap = gapRight ? x > x1 - gw : x < x0 + gw;
				if (!inGap) P.set(x, y, "H");
			}
			if (r() < 0.45) {
				const mx = ri(r, x0 + 8, x1 - 8);
				P.set(mx, y, "."); P.set(mx + 1, y, ".");
			}
		});
	};
	const aRows = r() < 0.5 ? [4, 8] : [4, 7, 10];
	racks(1, 43, aRows, true);
	for (const [x, y] of [[1, 1], [2, 1], [3, 1], [4, 1]]) P.set(x, y, "S");
	// 하역장 컨테이너(창고 A 왼쪽 아래)
	P.carve(42, 13, 43, 17); // 창고 A → 사무동(오른쪽 통로)
	P.carve(1, 18, 43, 19); // 사무동 복도
	P.band(1, 40, 14, 16, "down", (w) => (w <= 4 ? "whOffice" : r() < 0.5 ? "stock" : "breakRoom"));
	P.carve(1, 20, 2, 24); // 사무동 → 창고 B(왼쪽 통로)
	P.band(4, 43, 21, 23, "up", (w) => (w <= 4 ? "whOffice" : "stock"));
	P.room(1, 25, 42, 39, "hallB");
	const bRows = [];
	for (let y = ri(r, 27, 28); y <= 37; y += ri(r, 3, 4)) bRows.push(y);
	racks(1, 42, bRows, true);
	P.set(43, ri(r, 37, 39), "E"); // 하역장 문
	return P;
};

// 3 하수도 (43x41): 물길 터널 4줄 + 관리 통로(아치) + 펌프실·밸브실
ARCH[3] = (r) => {
	const P = Plan(43, 41, r, ["w"]);
	const tunnels = [2, 12, 22, 32];
	tunnels.forEach((y, k) => {
		const x0 = k === 0 ? 1 : ri(r, 1, 4), x1 = ri(r, 37, 40);
		P.carve(x0, y, x1, y); // 위 통로
		P.carve(x0, y + 1, x1, y + 2, "w"); // 물길
		P.carve(x0, y + 3, x1, y + 3); // 아래 통로
		// 건너는 곳: 다리 1~2개 + 물로 내려가는 계단
		const nb = ri(r, 1, 2);
		const bxs = [];
		for (let i = 0; i < nb; i++) {
			const bx = ri(r, x0 + 4, x1 - 4);
			if (bxs.some((o) => Math.abs(o - bx) < 6)) continue; // 다리 사이 물길이 너무 좁지 않게
			bxs.push(bx);
			P.set(bx, y + 1, r() < 0.35 ? "n" : "b");
			P.set(bx, y + 2, P.at(bx, y + 1));
		}
		// 다리 사이 물길 구간마다 계단(위 통로 쪽 1개 + 아래 통로 쪽 1개): 물에 빠져도 언제나 올라올 수 있다
		let seg = [];
		const flush = () => {
			if (seg.length >= 3) {
				const inner = seg.slice(1, -1);
				const sx = inner[Math.floor(r() * inner.length)];
				P.set(sx, y + 1, "s");
				const rest = inner.filter((x) => x !== sx);
				const sx2 = rest.length ? rest[Math.floor(r() * rest.length)] : sx === inner[0] ? seg[seg.length - 1] : seg[0];
				P.set(sx2, y + 2, "s");
			}
			seg = [];
		};
		for (let x = x0; x <= x1 + 1; x++) {
			if (x <= x1 && P.at(x, y + 1) === "w" && P.at(x, y + 2) === "w") seg.push(x);
			else flush();
		}
	});
	for (const [x, y] of [[1, 2], [2, 2], [3, 2], [4, 2]]) P.set(x, y, "S");
	// 관리 통로: 아래 통로 끝 → 다음 터널 위 통로(번갈아 오른쪽·왼쪽 끝)
	for (let k = 0; k < 3; k++) {
		const y0 = tunnels[k] + 3, y1 = tunnels[k + 1];
		let x = k % 2 === 0 ? 37 : 4;
		while (P.at(x, y0) !== "." && x > 1 && x < 41) x += k % 2 === 0 ? -1 : 1;
		let x2 = x;
		while (P.at(x2, y1) !== "." && x2 > 1 && x2 < 41) x2 += k % 2 === 0 ? -1 : 1;
		const xc = k % 2 === 0 ? Math.min(x, x2) : Math.max(x, x2);
		P.carve(xc, y0 + 1, xc, y1 - 1);
		for (let y = y0 + 2; y < y1 - 1; y += 3) P.set(xc, y, "A");
	}
	// 출구: 마지막 터널 아래 통로 끝의 사다리
	const ly = tunnels[3] + 3;
	let ex = 41;
	while (P.at(ex - 1, ly) !== "." && ex > 3) ex--;
	P.set(ex, ly, "E");
	for (let x = ex + 1; x <= 41; x++) P.set(x, ly, "#");
	// 터널 사이 띠에 펌프실·밸브실(통로로 이어진다) + 막다른 지선
	for (let k = 0; k < 4; k++) {
		const top = tunnels[k] + 5, bot = k < 3 ? tunnels[k + 1] - 2 : 39;
		if (bot - top < 2) continue;
		const n = ri(r, 1, 2);
		for (let i = 0; i < n; i++) {
			const w = ri(r, 4, 6), h = Math.min(bot - top + 1, ri(r, 3, 4));
			const x0 = ri(r, 6, 34 - w);
			if (P.at(x0 - 1, top) !== "#" || P.at(x0 + w, top) !== "#") continue;
			let clash = false;
			for (let y = top - 1; y <= top + h; y++) for (let x = x0 - 1; x <= x0 + w; x++) if (P.at(x, y) !== "#") clash = true;
			if (clash) continue;
			const rm = P.room(x0, top, x0 + w - 1, top + h - 1, r() < 0.6 ? "pump" : "valve");
			// 위쪽 터널 아래 통로로 이어지는 짧은 통로 + 아치
			const dx = ri(r, x0 + 1, x0 + w - 2);
			P.carve(dx, tunnels[k] + 4, dx, top - 1);
			P.set(dx, tunnels[k] + 4, "A");
			rm.door = { x: dx, y: top - 1, side: "up" };
		}
	}
	// 막다른 지선: 통로에서 갈라져 몇 칸 들어가다 끝난다(끝에 숨는 곳이나 공구함)
	for (let k = 0; k < 4; k++) {
		const y = tunnels[k] + 3;
		const tries = ri(r, 1, 3);
		for (let i = 0; i < tries; i++) {
			const x = ri(r, 6, 34);
			const len = ri(r, 2, 4), side = r() < 0.5 ? -1 : 1, run = ri(r, 3, 6);
			const cells = [];
			for (let d = 1; d <= len; d++) cells.push([x, y + d]);
			for (let d = 1; d <= run; d++) cells.push([x + side * d, y + len]);
			let ok = P.at(x, y) === ".";
			for (const [cx, cy] of cells) {
				for (let yy = cy - 1; yy <= cy + 1; yy++) for (let xx = cx - 1; xx <= cx + 1; xx++) {
					if (cells.some(([a, b]) => a === xx && b === yy) || yy <= y) continue;
					if (P.at(xx, yy) !== "#") ok = false;
				}
				if (cy >= P.H - 2 || cx <= 1 || cx >= P.W - 2) ok = false;
			}
			if (!ok) continue;
			for (const [cx, cy] of cells) P.set(cx, cy, ".");
			P.set(x, y + 2, "A");
			const [ex, ey] = cells[cells.length - 1];
			P.set(ex, ey, r() < 0.5 ? "L" : "Z");
		}
	}
	// 우회 터널(ㄷ자): 통로에서 빠져나가 바위 속을 지나 같은 통로로 돌아온다 — 괴물을 피해 돌아갈 길
	const bypass = (ly, dir) => {
		for (let t = 0; t < 8; t++) {
			const a = ri(r, 4, 30), b = a + ri(r, 5, 10);
			const cells = [[a, ly + dir], [b, ly + dir]];
			for (let x = a; x <= b; x++) cells.push([x, ly + dir * 2]);
			const has = (x, y) => cells.some(([cx, cy]) => cx === x && cy === y);
			let ok = P.at(a, ly) === "." && P.at(b, ly) === ".";
			for (const [cx, cy] of cells)
				for (const [dx, dy] of D8) {
					const nx = cx + dx, ny = cy + dy;
					if (has(nx, ny) || ny === ly) continue;
					if (P.at(nx, ny) !== "#") ok = false;
				}
			if (!ok) continue;
			for (const [cx, cy] of cells) P.set(cx, cy, ".");
			P.set(a, ly + dir, "A");
			P.set(b, ly + dir, "A");
			return;
		}
	};
	for (let k = 0; k < 4; k++) {
		bypass(tunnels[k] + 3, 1); // 아래 통로에서 아래로
		if (k > 0) bypass(tunnels[k], -1); // 위 통로에서 위로
		bypass(tunnels[k] + 3, 1);
	}
	return P;
};

// 1 지하 시설 (47x41): 시작 구역 → 연구동 복도 A/B → 연결 통로 → 남쪽 복도 C → 발전실 홀(구덩이 위 통로) → 비상구
ARCH[1] = (r) => {
	const P = Plan(47, 41, r);
	STAGE1_BLOCK.forEach((row, y) => [...row].forEach((c, x) => { P.g[y][x] = c; P.reserved[y][x] = true; }));
	P.carve(19, 3, 20, 3); // 시작 구역 → 복도 A
	P.reserved[3][19] = false;
	P.carve(21, 3, 45, 4); // 연구동 복도 A
	P.carve(44, 5, 45, 13); // 오른쪽 연결
	P.carve(21, 14, 45, 15); // 연구동 복도 B
	P.carve(21, 16, 22, 21); // 왼쪽 연결
	P.carve(21, 22, 45, 23); // 남쪽 복도 C
	P.carve(44, 24, 45, 30); // 오른쪽 연결
	P.carve(32, 31, 45, 32); // 복도 D(발전실로)
	// 실험실·기계실·관제실
	const pick = (w) => (w >= 5 ? (r() < 0.5 ? "lab" : "machine") : r() < 0.5 ? "control" : "crates");
	P.band(21, 42, 6, 8, "up", pick); // 복도 A 아래
	P.band(21, 42, 10, 12, "down", pick); // 복도 B 위
	P.band(24, 45, 17, 20, "up", pick); // 복도 B 아래
	P.band(1, 42, 25, 29, "up", (w) => (w >= 5 ? "machine" : "crates")); // 복도 C 아래(창고동)
	P.carve(1, 22, 20, 23); // 남쪽 복도 C 를 왼쪽 끝까지(시작 구역 밑, 창고동 앞)
	// 발전실 홀: 구덩이 위 철제 통로로 건넌다(구덩이에는 계단으로 내려갈 수 있다)
	const hx0 = 8, hx1 = 30, hy0 = 31, hy1 = 38;
	P.room(hx0, hy0, hx1, hy1, "genhall");
	P.set(hx1 + 1, 31, "D");
	const px0 = ri(r, 14, 16), px1 = px0 + ri(r, 5, 7);
	P.carve(px0, hy0, px1, hy1, "p");
	const by = ri(r, 33, 36);
	for (let x = px0; x <= px1; x++) P.set(x, by, "b");
	P.set(px0, hy0, "s");
	P.set(px1, hy1, "s");
	for (let x = hx0 + 1; x < px0 - 1; x += 3) P.set(x, hy0 + 1, "O");
	for (let x = px1 + 2; x < hx1; x += 3) P.set(x, hy1 - 1, "O");
	// 창고동(복도 D 아래)
	P.band(32, 45, 34, 38, "up", () => "crates");
	// 비상구(발전실 왼쪽 문 바로 밖)
	P.carve(2, 31, hx0 - 1, 31);
	P.set(hx0 - 1, 31, "D");
	P.set(1, 31, "E");
	return P;
};

// ── 마무리: 소품·숨는 곳·뒤지는 곳, 닿지 않는 곳 정리, 출구 거리 ──
function finish(P) {
	const { g, W, H, r, rooms, reserved, pitSet } = P;
	const at = P.at;
	const lv = (c) => (pitSet.has(c) ? (c === "b" || c === "n" ? [0] : c === "s" ? [0, 1] : [1]) : [0]);
	const bfs = (agent) => {
		let S = null;
		for (let y = 0; y < H && !S; y++) for (let x = 0; x < W; x++) if (g[y][x] === "S") { S = [x, y]; break; }
		const dist = new Map([[`${S[0]},${S[1]},0`, 0]]);
		const q = [[S[0], S[1], 0]];
		for (let h = 0; h < q.length; h++) {
			const [x, y, l] = q[h];
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
	const reach = () => bfs("player").size;
	let base = reach();
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
	const avoid = (x, y) => reserved[y][x] || D4.some(([dx, dy]) => "DASEsbnpw".includes(at(x + dx, y + dy)) && at(x + dx, y + dy) !== ".");
	const placed = { L: 0, Z: 0 };
	const place = (x, y, ch) => {
		if (x < 1 || y < 1 || x >= W - 1 || y >= H - 1 || g[y][x] !== "." || avoid(x, y)) return;
		if ((ch === "L" || ch === "Z") && D8.some(([dx, dy]) => at(x + dx, y + dy) === "D")) return;
		const rm = P.roomAt(x, y);
		if (rm && D4.some(([dx, dy]) => at(x + dx, y + dy) !== "#" && !P.roomAt(x + dx, y + dy) && at(x + dx, y + dy) !== "D")) {
			// 방이 복도로 트인 곳 바로 안쪽은 비운다
			if (rm.kind !== "lobby" && rm.kind !== "hallA" && rm.kind !== "hallB" && rm.kind !== "genhall") return;
		}
		g[y][x] = ch;
		const n = reach();
		// 막는 소품은 바닥 한 칸이 줄고, 지나갈 수 있는 소품(머리 위 배관 P·환풍기 f)은 그대로
		if (n === (PASS.has(ch) ? base : base - 1) && (!rm || roomWhole(rm))) {
			base = n;
			if (placed[ch] !== undefined) placed[ch]++;
		} else g[y][x] = ".";
	};
	for (const rm of rooms) if (D[rm.kind]) D[rm.kind](rm, place, r);
	// 숨는 곳·뒤지는 곳이 모자라면 방 벽가에 더(방 종류에 맞는 것 우선)
	const fill = (ch, want) => {
		const cands = [];
		for (const rm of rooms) {
			if (!D[rm.kind] || rm.kind === "lobby" || rm.kind === "hall") continue;
			for (let x = rm.x; x < rm.x + rm.w; x++) for (const y of [rm.y, rm.y + rm.h - 1]) cands.push([x, y, r()]);
		}
		cands.sort((a, b) => a[2] - b[2]);
		for (const [x, y] of cands) {
			if (placed[ch] >= want) break;
			place(x, y, ch);
		}
	};
	fill("L", 8);
	fill("Z", 8);
	// 닿지 않는 바닥은 벽으로(물길·구덩이처럼 일부러 둔 곳 제외)
	const pd = bfs("player");
	for (let y = 0; y < H; y++)
		for (let x = 0; x < W; x++)
			if (!reserved[y][x] && (g[y][x] === "." || g[y][x] === "D" || g[y][x] === "A") && ![0, 1].some((l) => pd.has(`${x},${y},${l}`))) g[y][x] = "#";
	let E = null;
	for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (g[y][x] === "E") E = [x, y];
	const md = bfs("monster");
	const pe = E && pd.get(`${E[0]},${E[1]},0`), me = E && md.get(`${E[0]},${E[1]},0`);
	return { rows: g.map((row) => row.join("")), dist: pe, monster: me, hides: placed.L, searches: placed.Z, rooms: rooms.length };
}


// ── 갈림길 만들기(백룸식): 벽 너머 바로 옆인데 걸어서는 멀리 돌아가야 하는 두 곳을 아치·문·통로로 잇는다.
//    고리가 많을수록 괴물을 피해 다른 길로 돌아갈 수 있다. 출구까지 최단 거리는 o.min 아래로 내려가지 않게 한다.
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

function writeRows(file, rows) {
	const src = fs.readFileSync(file, "utf8");
	const nl = src.includes("\r\n") ? "\r\n" : "\n";
	const out = src.replace(/\tRows = \{[\s\S]*?\n\t\},/, "\tRows = {" + nl + rows.map((r) => `\t\t"${r}",`).join(nl) + nl + "\t},");
	fs.writeFileSync(file, out);
}

const SEEDS = { 1: 100, 2: 200, 3: 300, 4: 400 };
// 갈림길: budget = 뚫을 곳 수, min = 출구까지 최단 거리 하한(칸), doors = 한 칸짜리 구멍 중 문 비율
const LOOPS = { 1: { budget: 60, doors: 0.35 }, 2: { budget: 60, doors: 0.4 }, 3: { budget: 40, doors: 0, maxLen: 8 }, 4: { budget: 70, doors: 0.5 }, 5: { budget: 60, doors: 0.2 } };
const LOOP_MIN = 112, LOOP_GAIN = 12;
const args = process.argv.slice(2);
const dry = args.includes("--dry");
const only = args.filter((a) => /^\d$/.test(a)).map(Number);
const stageFile = (id) => path.join(__dirname, "..", "src", "server", "Stages", `Stage${id}.luau`);
const withLoops = (id, rows, seed, reserved) => {
	const pits = id === 3 ? ["w"] : [];
	const out = loopify(rows, { ...LOOPS[id], r: rng(seed * 7 + 1), min: LOOP_MIN, minGain: LOOP_GAIN, pits, reserved });
	const bad = validate(out.rows, pits);
	if (bad.length) throw new Error("loopify broke stage " + id + ": " + bad.slice(0, 4).join(" "));
	return out;
};
for (const id of only.length ? only : [1, 2, 3, 4, 5]) {
	if (id === 5) {
		// 5스테이지는 tools/gen-stages.js 가 만든 미로에 갈림길만 더한다(이미 더했으면 거의 안 바뀐다)
		const src = fs.readFileSync(stageFile(5), "utf8");
		const rows = [...src.match(/\tRows = \{([\s\S]*?)\n\t\},/)[1].matchAll(/"([^"]+)"/g)].map((m) => m[1]);
		const out = withLoops(5, rows, 500);
		console.log(`stage 5: loops +${out.made} exit ${out.dist} tiles (monster ${out.monster})`);
		if (dry) console.log(out.rows.join("\n"));
		else writeRows(stageFile(5), out.rows);
		continue;
	}
	let res = null, last = null;
	for (let s = SEEDS[id]; s < SEEDS[id] + 4000 && !res; s++) {
		// 실패한 설계(문·계단 규칙 위반, 출구까지 거리 범위 밖)는 버리고 다음 시드
		let P;
		try { P = ARCH[id](rng(s)); } catch (e) { last = String(e); continue; }
		const out = finish(P);
		if (!out.dist || out.monster === undefined) { last = "no path"; continue; }
		if (out.dist < TARGET[0] || out.dist > TARGET[1]) { last = "dist " + out.dist; continue; }
		if (out.hides < 6 || out.searches < 6) { last = `hides ${out.hides} searches ${out.searches}`; continue; }
		const bad = validate(out.rows, id === 3 ? ["w"] : []);
		if (bad.length) { last = bad.slice(0, 4).join(" "); continue; }
		res = { ...out, seed: s, reserved: P.reserved };
	}
	if (!res) { console.log(`stage ${id}: FAILED`, last); process.exitCode = 1; continue; }
	const lp = withLoops(id, res.rows, res.seed, (x, y) => res.reserved[y][x]);
	console.log(`stage ${id}: seed ${res.seed} ${res.rows[0].length}x${res.rows.length} rooms ${res.rooms} hides ${res.hides} searches ${res.searches} exit ${res.dist} -> ${lp.dist} tiles with +${lp.made} loops (monster ${lp.monster})`);
	if (dry) console.log(lp.rows.join("\n"));
	else writeRows(stageFile(id), lp.rows);
}
