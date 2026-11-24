// 챕터 9 지하 주차장 — 같은 크기 두 층을 겹쳐 쌓는다: Rows = 지하 2층(가장 깊은 층, 시작), Rows2 = 지하 1층(출구 게이트).
// 엘리베이터가 지하 2층에서 멈췄다. 지하 2층 남서쪽 엘리베이터 홀(시작)에서 지하 1층 남서쪽 출차 게이트(E, 시작 바로 위층)까지 올라간다.
// 뼈대(QA 2차): 층 면적의 대부분이 하나의 큰 주차장이다 — 기둥 격자(x10~40, y1~40) 안에 동서 차로 일곱, 남북 차로 셋
//   (서쪽 회차로 x10~11, 가운데 횡단 차로 x23~24, 동쪽 순환 차로 x39~40), 그 사이 맞댄 주차 줄 여섯 + 남쪽 벽 줄 하나.
//   설비실·관리실은 가장자리(서쪽 띠 x1~8, 동쪽 띠 x42~45)의 작은 방이고, 주차장 안의 벽 상자는 실제 구조물(동 출입구 코어 둘,
//   비상계단실, 남동쪽 세대 창고·재활용 집하장)뿐이다.
// 수직 연결 셋(QA 3차: 한 구석에 몰리지 않게): 램프 B(북동쪽 끝, 두 차로) / 램프 A(동쪽 띠 위쪽, 두 차로) / 남동 비상계단(동쪽 띠 남쪽 끝 —
//   지하 1층에서는 동쪽 뒤편 설비 줄(통신실 → 관리 창고 → 팬룸)을 지나 순환 차로로 나온다: 최단이 무너지지 않게).
// 남북 차로 셋 위의 급배기 샤프트(두 층을 꿰뚫는 벽 상자)가 차로를 한 차로 꺾어 긴 직선 시야를 끊는다.
// 차는 두 칸(머리 Q·W·I + 꼬리 q), 빈 칸은 l + y(바닥선만, 지나갈 수 있다). 빈 칸은 늘 둘 이상 붙어 비어 있다(한 칸짜리 막다른 틈 없음 —
//   옛 Studio 측정에서 괴물이 그런 틈에 걸렸다). 기둥 열은 X·B·X·X(맞댄 줄 네 칸을 다 막음, 기둥 B 는 이음선 위)라 기둥 앞 한 칸 홈도 없다.
//   node tools/places/parking.js [--dry] [--print]      (STAGE_OUT_DIR 로 다른 폴더에)
const fs = require("fs");
const path = require("path");
const { Grid, report } = require("./lib");

const W = 47, H = 43;
const g = new Grid(W, H); // 지하 2층
const up = g.floor2(); // 지하 1층
const floors = [g, up];
let seed = 9200;
const rnd = () => ((seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648);

// ══ 두 층 공통 골조: 주차장 ══
// 서쪽 블록 x12~22(기둥 14·18·22), 가운데 횡단 차로 x23~24, 동쪽 블록 x25~38(기둥 27·31·35), 순환 차로 x39~40
// 동서 차로 y1~2, 7~8, 13~14, 19~20, 25~26, 31~32, 37~38 / 맞댄 줄 y3~6, 9~12, 15~18, 21~24, 27~30, 33~36 / 남쪽 벽 줄 y39~40
const PX = [14, 18, 22, 27, 31, 35];
const BLOCKS = [[12, 22], [25, 38]];
const DRS = [3, 9, 15, 21, 27, 33];
for (const f of floors) f.fill(10, 1, 40, 40);

// 블록 안의 주차 칸 묶음(기둥 사이 칸들): [[x...], ...]
function bays(x0, x1) {
	const out = [];
	let cur = [];
	for (let x = x0; x <= x1; x++) {
		if (PX.includes(x)) { if (cur.length) out.push(cur); cur = []; } else cur.push(x);
	}
	if (cur.length) out.push(cur);
	return out;
}
const carKind = () => (rnd() < 0.25 ? "W" : "Q"); // W = 덮개 씌운 장기 주차 차
function stall(f, x, yh, yt, car) {
	if (car) f.set(x, yh, car).set(x, yt, "q");
	else f.set(x, yh, "l").set(x, yt, "y");
}
// 한쪽 줄의 칸 묶음 하나를 채운다: 꽉(차 셋) / 한쪽 끝 둘이 빈(빈 칸 둘이 붙어서) / 다 빈. 빈 칸은 둘 이상 붙는다(한 칸 틈 없음)
function bayPattern(n, empty) {
	if (empty) return Array(n).fill(false);
	const r = rnd();
	if (n < 3) return Array(n).fill(r < 0.7);
	if (r < 0.32) return Array(n).fill(true);
	if (r < 0.54) return [false, false, ...Array(n - 2).fill(true)];
	if (r < 0.76) return [...Array(n - 2).fill(true), false, false];
	return Array(n).fill(false);
}
// 맞댄 두 줄(y0 위 머리, y0+1 위 꼬리, y0+2 아래 꼬리, y0+3 아래 머리).
// skip = 이 줄을 차지하는 벽 상자(코어·계단실)의 x 범위, cross = 위·아래 다 빈 칸 묶음(첫 x) — 차로 사이를 가로지르는 세 칸 폭 건널목
function doubleRow(f, y0, { skip = [], cross = [], blocks = BLOCKS }) {
	const inSkip = (x) => skip.some(([a, b]) => x >= a && x <= b);
	for (const [x0, x1] of blocks) {
		for (const x of PX) {
			if (x < x0 || x > x1 || inSkip(x)) continue;
			f.set(x, y0, "X").set(x, y0 + 1, "B").set(x, y0 + 2, "X").set(x, y0 + 3, "X");
		}
		for (const bay of bays(x0, x1)) {
			if (bay.some(inSkip)) continue;
			const cr = cross.includes(bay[0]);
			const top = bayPattern(bay.length, cr), bot = bayPattern(bay.length, cr);
			bay.forEach((x, k) => {
				stall(f, x, y0, y0 + 1, top[k] ? carKind() : null);
				stall(f, x, y0 + 3, y0 + 2, bot[k] ? carKind() : null);
			});
		}
	}
}
// 남쪽 벽 줄(머리 y39, 꼬리 y40 — 남벽에 붙은 한 줄): 기둥은 벽 기둥(B 만, 꼬리 자리)
function wallRow(f, x0, x1) {
	for (const x of PX) if (x >= x0 && x <= x1) f.set(x, 39, "X").set(x, 40, "B");
	for (const bay of bays(x0, x1)) {
		const row = bayPattern(bay.length, false);
		bay.forEach((x, k) => stall(f, x, 39, 40, row[k] ? carKind() : null));
	}
}
// 동 출입구 코어(위 아파트 동으로 오르는 계단·승강기. 주차장 쪽 방풍실만 열려 있다): 칸 묶음 하나(3칸 폭) 벽 상자 + 문 하나 + 사물함
function core(f, x0, y0, door) {
	f.wall(x0, y0, x0 + 2, y0 + 3).fill(x0 + 1, y0 + 1, x0 + 1, y0 + 2);
	if (door === "N") f.set(x0 + 1, y0, "D").set(x0 + 1, y0 + 2, "L");
	else f.set(x0 + 1, y0 + 3, "D").set(x0 + 1, y0 + 1, "L");
}
// 남동쪽 방(세대 창고 / 재활용 집하장): 안 x26~37, y34~40. 문 셋(북 차로, 서 횡단 차로, 동 순환 차로) — 열쇠 상자를 둘 수 있다
function seRoom(f) {
	f.wall(25, 33, 38, 40).fill(26, 34, 37, 40);
	f.put("D", [[31, 33], [25, 37], [38, 37]]);
}

// ══════════ 지하 2층 (Rows, 시작 층) ══════════
seed = 9201;
// (QA 3차: 북동쪽 비상계단실을 남동쪽 끝으로 옮겼다 — 이 칸 묶음 x36~38 은 다시 주차 칸. 위 줄 차 셋, 아래 줄 빈 칸 셋)
doubleRow(g, 3, { skip: [[36, 38]], cross: [19] });
for (const x of [36, 37, 38]) { stall(g, x, 3, 4, x === 38 ? "W" : "Q"); stall(g, x, 6, 5, null); }
doubleRow(g, 9, { cross: [28] });
doubleRow(g, 15, { skip: [[15, 17]], cross: [32] });
core(g, 15, 15, "N");
doubleRow(g, 21, { cross: [12, 36] });
doubleRow(g, 27, { skip: [[28, 30]], cross: [19]  });
core(g, 28, 27, "S");
doubleRow(g, 33, { blocks: [[12, 22]], cross: [15] });
wallRow(g, 12, 22);
seRoom(g);
// 세대 창고(남동쪽 방): 가운데 철망 창고 칸 줄(a) — 위·아래 두 통로, 양 끝으로 돈다. 손수레 u, 상자 c
g.put("a", [[28, 37], [29, 37], [30, 37], [31, 37], [32, 37], [33, 37], [34, 37], [35, 37]]);
g.put("a", [[29, 40], [30, 40], [33, 40], [34, 40]]).set(35, 34, "u").put("c", [[26, 40], [37, 34]]);
g.put("Z", [[26, 34], [37, 40]]).set(31, 40, "L");
// 차로 위: 사고 차량(차로 4 를 가로막고 멈춘 차 I + q, 라바콘), 천장 안내 표지 N, 제트 팬 j, 소화전 h(벽)
g.set(26, 19, "I").set(26, 20, "q").put("i", [[25, 20], [27, 19]]);
g.put("N", [[16, 1], [30, 13], [11, 25], [33, 31], [24, 8]]).put("j", [[20, 7], [33, 19], [17, 31], [30, 25]]).put("h", [[10, 6], [10, 30], [40, 10], [40, 36]]);
// 순환 차로: 과속 방지턱 w, 라바콘
g.put("w", [[39, 28], [40, 28]]).set(39, 34, "i");
// 열쇠 상자(공구함) Z: 주차장 바깥벽의 차로 모퉁이(차로가 만나는 넓은 곳이라 길을 좁히지 않는다)
g.put("Z", [[10, 2], [23, 1], [40, 25], [24, 40], [10, 25]]); // ((10,2) = 북서 모퉁이: 북쪽 차로 줄 시야도 끊는다)
// 북쪽 차로 2(y7~8)의 두 번째 사고 차량(QA 3차 straight: 36칸 시야를 끊는 섬) — 양옆 빈 주차 칸(x36~38)으로 돌아간다
g.set(37, 7, "I").set(37, 8, "q").put("i", [[36, 8], [38, 7]]);

// ── 동쪽 띠(x41 벽, x42~45): 램프 둘 + 작은 설비실 ──
// 램프 B(북동쪽 끝): 두 차로(x42·x45, 가운데 두 칸 분리대 x43~44), 북쪽으로 오른다. 앞마당 y5~8(바닥 화살표 r)
g.stairs(42, 4, 0, -1).stairs(45, 4, 0, -1).fill(42, 5, 45, 8).fill(41, 5, 41, 8);
g.put("r", [[42, 6], [45, 6]]).set(43, 5, "Z");
// 램프 A(순환 차로 가운데): 두 차로, 북쪽으로 오른다(y13 → y12 → 지하 1층 y11). 앞마당 y14~18
g.stairs(42, 13, 0, -1).stairs(45, 13, 0, -1).fill(42, 14, 45, 18).fill(41, 14, 41, 18);
g.put("r", [[42, 15], [45, 15]]);
// 오수·배수 펌프실(x42~45, y20~26, 문 하나(41,20) — 샤프트 북쪽: 숨는 곳만): 집수정 덮개 M, 배관 v
g.fill(42, 20, 45, 26).set(41, 20, "D").put("M", [[44, 21], [44, 25]]).set(45, 23, "v").set(42, 26, "L");
// 소방 창고(x42~45, y28~33, 문 하나): 서류장 k, 상자 c
g.fill(42, 28, 45, 33).set(41, 30, "D").put("c", [[45, 28], [45, 33]]).set(42, 33, "L").set(45, 31, "k");
// 남동 비상계단실(QA 3차: 수직 연결을 북동 구석에서 떼어 남동쪽 끝으로. 전기 EPS 를 겸한다, x42~45, y35~40, 문 하나 = 순환 차로):
// 계단은 동벽 x45 를 따라 북쪽으로 오른다(남쪽 끝 (45,40) 에서 밟는다. g.stairs 는 지하 1층 통신실을 깐 다음, 아래 지하 1층 절 끝에서 놓는다). 배전반 R, 사물함
g.fill(42, 35, 45, 40).set(41, 37, "D").put("R", [[45, 35], [45, 36]]).set(42, 35, "L").put("#", [[44, 38], [44, 39]]); // (계단 옆벽)

// 서쪽 회차로의 급배기 샤프트(DA, x10~11 y15~18, 두 층을 꿰뚫는 벽 상자): 회차로 40칸 직선 시야를 끊는다(QA 3차 straight).
// 회차로는 여기서 기둥 열 x14 쪽으로 한 차로 꺾여(x12~13, 그 자리 주차 칸을 비웠다) 샤프트를 돌아간다
// 동쪽 순환 차로에도 같은 샤프트(x39~40 y21~24): 순환 차로는 x36~38(그 자리 주차 칸을 비웠다)로 꺾여 돈다. (지하 1층은 그 층 주차 줄 뒤에 같은 자리로)
// 가운데 횡단 차로에도 하나(x23~24 y27~30, 동 출입구 코어 옆): 횡단 차로는 x25~26 으로 꺾인다
const shafts = (f) => f.wall(10, 15, 11, 18).fill(12, 15, 13, 18).wall(39, 21, 40, 24).fill(36, 21, 38, 24).wall(23, 27, 24, 30).fill(25, 27, 26, 30);
shafts(g);

// ── 서쪽 띠(x1~8, x9 벽): 작은 설비실 넷 + 엘리베이터 홀 ──
// 기계실(공조, 문 하나): 공조기 m(벽에 붙여), 급배기 팬 V, 덕트 d
g.fill(1, 1, 8, 7).set(9, 4, "D");
g.put("m", [[1, 2], [1, 5]]).put("V", [[5, 1], [8, 7]]).set(5, 4, "d").set(1, 7, "L");
// 비상 발전기실(문 하나): 발전기 G 둘(두 칸씩 띄워), 배전반 R, 연료 탱크 F
g.fill(1, 9, 8, 14).set(9, 12, "D");
g.put("G", [[3, 11], [6, 11]]).set(1, 14, "R").set(8, 9, "F").set(1, 9, "L");
// 수변전실(문 둘): 배전반 R 줄(서벽), 변압기 m(가운데, 둘레 두 칸 이상)
g.fill(1, 16, 8, 23).put("D", [[9, 19], [9, 22]]); // (북쪽 문은 샤프트 남쪽 (9,19) 로)
g.put("R", [[1, 17], [1, 18], [1, 19]]).set(5, 20, "m").put("Z", [[1, 23]]).set(8, 16, "L");
// 저수조실(서쪽 가장자리로 옮기고 줄임): 패널 탱크 H 넷, 배관 v. 문 둘: 서쪽 회차로 / 엘리베이터 홀 북쪽 점검문(5,33) —
// 시작 홀에서 나가는 셋째 길(홀 앞 회차로 두 문을 괴물 둘이 막아도 저수조실로 돌아 나간다)
g.fill(1, 25, 8, 32).put("D", [[9, 28], [5, 33]]);
g.put("H", [[3, 27], [6, 27], [3, 30], [6, 30]]).put("v", [[1, 25], [8, 25]]).set(1, 32, "L");
// 엘리베이터 홀(시작, x1~8, y34~41): 엘리베이터 셋(남벽), 사전 정산기, 소화전 (문 둘: 서쪽 회차로의 북·남)
g.fill(1, 34, 8, 41).put("D", [[9, 35], [9, 40]]);
g.put("S", [[3, 38], [4, 38]]).put("e", [[2, 41], [4, 41], [6, 41]]).set(8, 37, "J").set(1, 34, "h");

// ══════════ 지하 1층 (Rows2, 출구 층) ══════════
seed = 9301;
doubleRow(up, 3, { skip: [[36, 38]], cross: [25] });
for (const x of [36, 37, 38]) { stall(up, x, 3, 4, null); stall(up, x, 6, 5, x === 36 ? "W" : "Q"); } // (옛 비상계단 자리 → 주차 칸)
doubleRow(up, 9, { cross: [15] });
doubleRow(up, 15, { skip: [[15, 17]], cross: [36]  });
core(up, 15, 15, "S");
doubleRow(up, 21, { cross: [19, 28] });
doubleRow(up, 27, { skip: [[28, 30]], cross: [12] });
core(up, 28, 27, "N");
doubleRow(up, 33, { blocks: [[12, 22]], cross: [19] });
wallRow(up, 12, 22);
seRoom(up);
shafts(up);
// 재활용 집하장(남동쪽 방): 벽을 따라 수거함 Y, 카트 u, 파레트 잭 z, 상자 c
up.put("Y", [[26, 34], [27, 34], [28, 34], [33, 40], [34, 40], [35, 40]]).set(37, 35, "u").set(31, 37, "z").put("c", [[26, 40], [37, 34]]);
up.put("Z", [[32, 34], [28, 40]]).set(37, 40, "L");
// 차로 위
up.set(32, 25, "I").set(32, 26, "q").put("i", [[33, 26], [31, 25]]);
up.put("N", [[30, 1], [14, 13], [33, 19], [11, 31], [24, 26]]).put("j", [[18, 7], [30, 13], [20, 25], [33, 31]]).put("h", [[10, 3], [10, 27], [40, 26], [40, 33]]);
up.put("w", [[39, 30], [40, 30], [16, 37], [16, 38]]).set(39, 38, "i");
up.put("Z", [[10, 19], [24, 1], [40, 13], [40, 37], [24, 40]]); // (차로 모퉁이 공구함)
// 북쪽 차로 1(y1~2): 램프 B 앞에서 멈춘 사고 차량(36칸 시야를 끊는 섬) — 남쪽 빈 주차 칸(x36~38 y3)으로 돌아간다
up.set(37, 1, "I").set(37, 2, "q").put("i", [[36, 2], [38, 1]]);

// ── 동쪽 띠 ──
// 램프 B 위: 도착 칸 y2, 앞마당 y1~2
up.fill(41, 1, 45, 2).put("r", [[42, 1], [45, 1]]);
// 전기 EPS 실(x42~45, y6~7, 문 하나)
up.fill(42, 6, 45, 7).set(41, 7, "D").put("R", [[45, 6], [44, 6]]).set(42, 6, "L");
// 램프 A 위: 도착 칸 y11(x42·x45), 앞마당 y9~11
up.fill(41, 9, 45, 11).put("r", [[42, 10], [45, 10]]).set(43, 9, "Z");
// 동쪽 뒤편 설비 줄(QA 3차): 남동 비상계단은 지하 1층에서 주차장으로 바로 나오지 않고, 통신실 → 관리 창고 → 팬룸을 거쳐
// 팬룸 북서쪽 문(41,16)으로 순환 차로에 나온다(램프 A 앞마당과 따로 — 괴물 둘이 램프 둘·계단을 한꺼번에 막지 못하게).
// (통신실·관리 창고의 주차장 쪽 문은 닫았다 — 계단이 출구 게이트로 가는 지름길이 되지 않게: 최단 128 이상)
// 급배기 팬룸(x42~45, y15~22, 문 둘: 순환 차로 북쪽 끝 / 남 관리 창고): 급배기 팬 V, 덕트 d
up.fill(42, 15, 45, 22).put("D", [[41, 16], [43, 23]]).put("V", [[45, 15], [45, 19]]).set(43, 21, "d").set(42, 22, "L");
// 정산 관리 창고(x42~45, y24~30, 문 둘: 북 팬룸 / 남 통신실): 서류장 k, 상자 c
up.fill(42, 24, 45, 30).set(43, 31, "D").put("k", [[45, 24], [45, 25]]).set(42, 30, "L").set(45, 30, "c");
// 통신실(x42~45, y32~40, 문 하나 + 남동 비상계단 도착 칸 (45,37)): 배전반 R(통신 랙), 책상 T
up.fill(42, 32, 45, 40).put("R", [[45, 32], [45, 33], [45, 34]]).set(42, 38, "T").set(45, 40, "L");
g.stairs(45, 39, 0, -1); // 남동 비상계단: 지하 2층 (45,40) → (45,39)·(45,38) → 지하 1층 통신실 (45,37)

// ── 서쪽 띠(x1~8): 방재실 · 관리사무소 · 하역장 · 정산원 대기실 · 출차 게이트 ──
// 방재실(문 둘): CCTV 콘솔 C(서벽), 책상 T, 서류장 k
up.fill(1, 1, 8, 7).put("D", [[9, 2], [9, 6]]);
up.put("C", [[1, 3], [1, 4]]).set(4, 4, "T").put("k", [[7, 1], [8, 1]]).put("Z", [[1, 7]]).set(8, 7, "L");
// 관리사무소(문 하나): 책상 T, 서류장 k, 사물함
up.fill(1, 9, 8, 15).set(9, 12, "D");
up.put("T", [[3, 11], [3, 14], [6, 11]]).put("k", [[1, 9], [2, 9]]).set(8, 15, "L");
// 하역장(문 둘, 서쪽 가장자리로 옮겼다): 탑차 U 둘(세로 두 칸, 운전석 북쪽), 남벽 셔터 x, 파레트 잭 z, 상자 c
up.fill(1, 17, 8, 26).put("D", [[9, 21], [9, 25]]); // (북쪽 문은 샤프트를 피해 (9,21) 로)
up.put("U", [[3, 22], [3, 23], [6, 22], [6, 23]]).put("x", [[2, 26], [4, 26], [6, 26]]).set(7, 19, "z").put("c", [[1, 17], [8, 26]]).put("Z", [[1, 20]]);
// 정산원 대기실: 서류장 k, 책상 T, 사물함 L. 문 둘: 서쪽 회차로(9,29) / 남쪽 게이트 정산 부스 쪽 직원문(4,33) —
// 게이트로 드는 셋째 길(회차로 남쪽 끝을 괴물 둘이 막아도 대기실로 돌아 들어간다)
up.fill(1, 28, 8, 32).put("D", [[9, 29], [4, 33]]);
up.put("k", [[1, 28], [2, 28]]).set(5, 30, "T").put("L", [[8, 32], [1, 32]]);
// 출차 게이트(x1~8, y34~41): 출구 E(1,38) = 지상으로 오르는 출차 램프 입구. 차단기 g, 정산기 J, 정산 부스(벽 상자), 과속 방지턱 w
// 들어오는 곳 둘: 서쪽 회차로의 북(9,35)·남(9,40) — 회차로는 그 사이에서 남쪽 차로(y37~38)로 갈라진다
up.fill(1, 34, 8, 41).set(1, 37, "#").set(1, 39, "#").set(1, 38, "E").put("D", [[9, 35], [9, 40]]);
up.wall(4, 40, 6, 41).set(3, 38, "g").set(5, 39, "J").put("w", [[6, 37], [6, 38]]).set(8, 34, "L");

// ══ 내보내기 ══
const PROPS = {
	Q: "CP.Car", W: "CP.CoveredCar", I: "CP.CrashedCar", q: "CP.Blank", l: "CP.EmptyStall", y: "CP.Blank", B: "CP.Pillar", X: "CP.Blank",
	u: "CP.Cart", h: "CP.Hydrant", e: "CP.Elevator", x: "CP.Shutter", g: "CP.Barrier", J: "CP.PayMachine", r: "CP.RampMark",
	T: "Props.Desk", k: "Props.Cabinet", C: "CP.CctvDesk", N: "CP.HangSign", j: "CP.JetFan", d: "CP.Duct", i: "CP.Cone", w: "CP.SpeedBump",
	G: "CP.Generator", R: "CP.Switchgear", H: "CP.WaterTank", V: "CP.FanUnit", U: "CP.Truck", z: "CP.PalletJack", Y: "CP.RecycleBin",
	M: "CP.SumpPit", F: "CP.FuelTank", a: "CP.Cage",
};
const WALK = ["l", "y", "h", "e", "x", "g", "N", "j", "d", "i", "w", "r"];
const opts = { id: 9, walkable: WALK, blocked: Object.keys(PROPS).filter((k) => !WALK.includes(k)) };
const r = report("지하 주차장", g, opts);
if (process.argv.includes("--print")) for (const [name, gr] of [["지하 2층(Rows)", g], ["지하 1층(Rows2)", up]]) console.log(name + "\n" + gr.rows().map((row, i) => String(i).padStart(2) + " " + row).join("\n"));
const count = {};
for (const gr of floors) for (const row of gr.rows()) for (const ch of row) count[ch] = (count[ch] || 0) + 1;
const cars = (count.Q || 0) + (count.W || 0) + (count.I || 0);
const blockedProps = Object.keys(PROPS).filter((k) => !WALK.includes(k)).reduce((s, k) => s + (count[k] || 0), 0);
const open = floors.reduce((s, gr) => s + gr.rows().join("").replace(/#/g, "").length, 0);
// 주차장(x10~40, y1~40 중 벽 아닌 칸) 넓이 / 층 바닥 넓이
let park = 0;
for (const gr of floors) for (let y = 1; y <= 40; y++) for (let x = 10; x <= 40; x++) if (gr.get(x, y) !== "#" && !(x >= 25 && x <= 38 && y >= 33)) park++;
console.log(`차 ${cars}대(덮개 ${count.W || 0}, 사고 ${count.I || 0}) · 빈 칸 ${count.l || 0} · 기둥 ${count.B || 0} · Z ${count.Z || 0} · L ${count.L || 0} · 막는 소품 칸 ${blockedProps}/${open} (${((blockedProps / open) * 100).toFixed(0)}%) · 주차장 ${park}/${open} (${((park / open) * 100).toFixed(0)}%)`);
if (!process.argv.includes("--dry")) {
	const text = [
		"--!strict",
		"-- STAGE 9 — 지하 주차장 (47x43칸 두 층: Rows = 지하 2층(시작), Rows2 = 같은 크기로 겹쳐 쌓은 지하 1층(출구). tools/places/parking.js 로 생성)",
		"-- 엘리베이터가 지하 2층에서 멈췄다. 층마다 바닥 대부분이 하나의 큰 주차장(기둥 격자, 동서 차로 일곱 · 남북 차로 셋, 맞댄 주차 줄 여섯 + 벽 줄),",
		"-- 가장자리에 작은 방: 지하 2층 서쪽 기계실·발전기실·수변전실·저수조실·엘리베이터 홀(시작), 동쪽 오수 펌프실·소방 창고·EPS, 남동쪽 세대 창고.",
		"-- 지하 1층 서쪽 방재실·관리사무소·하역장·정산원 대기실·출차 게이트(E, 지상 출차 램프 입구), 동쪽 EPS·팬룸·관리 창고·통신실, 남동쪽 재활용 집하장.",
		"-- 오르는 길 셋: 북동쪽 끝 램프 B(두 차로) / 동쪽 띠 램프 A(두 차로) / 남동쪽 끝 비상계단(지하 1층 동쪽 뒤편 설비 줄로 나온다). 램프는 벽으로 둘러싼 통로라 아래층이 내려다보이지 않는다.",
		"-- 남북 차로 셋 위에 급배기 샤프트(두 층을 꿰뚫는 벽 상자) — 차로가 그 옆으로 한 차로 꺾여 돈다.",
		`-- 차는 두 칸(머리 Q·W·I, 꼬리 q), 빈 칸 l·y 는 바닥선만. 기둥 열 X·B·X·X(기둥 B 는 맞댄 줄 이음선). 세대 창고 철망 칸 a. 전용 소품 ChapterProps/Parking. 출구까지 최단 약 ${r.exit}칸.`,
		"local Props = require(script.Parent.Parent.Props)",
		"local CP = require(script.Parent.Parent.ChapterProps.Parking)",
		"return {",
		"\tSeed = 91,",
		"\tPipeChance = 0.25,",
		'\tHideStyle = "locker", -- 숨는 곳(L): 철제 사물함',
		'\tSearchStyle = "toolbox", -- 뒤지는 곳(Z): 공구함, 그중 한 곳에 열쇠',
		`\tProps = { ${Object.entries(PROPS).map(([k, v]) => `${k} = ${v}`).join(", ")} },`,
		`\tWalkable = { ${WALK.map((k) => `${k} = true`).join(", ")} }, -- (빈 주차 칸·바닥 표시·천장 설비·벽 설비만. 차·기둥·장비는 막힘)`,
		"\tRows = { -- 지하 2층",
		...g.rows().map((row) => `\t\t"${row}",`),
		"\t},",
		"\tRows2 = { -- 지하 1층(지하 2층 위에 같은 크기로 겹쳐 쌓는다. o = 계단·램프 구멍)",
		...up.rows().map((row) => `\t\t"${row}",`),
		"\t},",
		"}",
		"",
	].join("\n");
	const dir = process.env.STAGE_OUT_DIR || path.join(__dirname, "..", "..", "src", "server", "Stages");
	fs.writeFileSync(path.join(dir, "Stage9.luau"), text);
}
