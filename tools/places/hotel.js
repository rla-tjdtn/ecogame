// 챕터 6 호텔(재작업 2차): 가운데 아트리움 로비를 객실 날개(ㄷ자: 서쪽 날개 · 북쪽 뒤쪽 구역/2층 북쪽 객실 줄 · 동쪽 날개)가 감싸고,
//   직원 구역(백 오브 하우스)이 북쪽 서비스 고리(직원 복도 · 주방 · 연회장 · 하역장)와 남서쪽 직원 구역(휴게실 = 시작)으로 붙는다.
//   node tools/places/hotel.js [--dry] [--print]
// 큰 흐름: 남서쪽 직원 휴게실(시작) → 서쪽 객실 날개 복도를 북쪽으로 → 북쪽 서비스 고리(주방·연회장 또는 직원 복도·하역장)를 동쪽으로
//   → 동쪽 객실 날개 복도를 남쪽으로 → 레스토랑 → 아트리움 로비 → 정문 바람막이(출구).
//   2층 객실층(같은 크기로 겹쳐 쌓음)은 같은 ㄷ자를 한 층 위에서 도는 둘째 길: 남서쪽 직원 계단으로 올라 로비 대계단으로 내려온다.
//   로비(마지막 방)로 들어가는 입구는 둘 — 1층 동쪽 날개 쪽 레스토랑 문(로비 남동쪽)과 2층에서 내려오는 대계단(로비 북동쪽) — 서로 다른 층·구역이다.
// 소품 글자(Stage6 Props 줄) — 호텔 전용(ChapterProps/Hotel.luau):
//   객실: R 더블 침대(머리판 + 양옆 협탁·스탠드), r 트윈 침대, u 욕실(칸막이 + 욕조·변기·세면대), T 책상·의자·벽걸이 TV,
//         y 짐 받침대 + 여행 가방, a 붙박이 옷장(숨는 곳 아님), L 옷장(숨는 곳), Z 객실 서랍장(뒤지는 곳, 문 둘 이상인 방만)
//   로비: F 프런트 데스크, e 엘리베이터 문, Y 분수(3x3 가운데, i = 분수가 덮는 빈 칸), N 샹들리에(천장에 매달림, 지나갈 수 있음),
//         w 소파, G 짐 카트, O 기둥
//   F&B·뒤쪽: K 업소용 화구(후드), P 스테인리스 조리대, j 선반, U 원형 테이블(의자), q 바 카운터, z 연회 무대, W 업소용 세탁기,
//         l 직원 사물함 줄, h 하우스키핑 카트, V 제빙기·자판기, k 캐비닛, c 상자, m 설비(압축기)
const { Grid, report, writeStage } = require("./lib");

const g = new Grid(47, 43);
const up = g.floor2(); // 2층 객실층(1층 위에 같은 크기). 아트리움 로비 위는 2층 바닥이 없는 빈 공간(벽 덩어리)

// ── 객실 한 칸(안쪽 4x4): 복도 쪽(side)에 문 하나. 진짜 객실 배치 —
//   문 옆 욕실(u), 맞은편 옷장(L/a), 칸막이벽에 머리를 둔 침대(R/r, 협탁 포함), 창가 짐 받침대(y)와 책상·TV(T),
//   커넥팅 룸이면 침대 맞은편 벽에 서랍장(Z) + 옆방으로 통하는 커넥팅 문(칸막이벽, 둘째 줄).
//   (ax, ay) = 방 왼쪽 위 칸, side = 복도가 있는 쪽 E/W/N/S, mirror = 좌우 뒤집기(이웃 방과 욕실이 등을 맞댄다)
function room(G, ax, ay, side, o = {}) {
	const pt = (w, d) => {
		const wm = o.mirror ? 3 - w : w;
		if (side === "E") return [ax + 3 - d, ay + wm];
		if (side === "W") return [ax + d, ay + wm];
		if (side === "N") return [ax + wm, ay + d];
		return [ax + wm, ay + 3 - d]; // S
	};
	const put = (w, d, ch) => { const [x, y] = pt(w, d); G.set(x, y, ch); };
	G.fill(ax, ay, ax + 3, ay + 3);
	put(1, -1, "D"); // 복도 문
	if (!o.empty) {
		put(0, 0, "u"); // 욕실(문 바로 옆)
		put(3, 0, o.hide ? "L" : "a"); // 옷장
		put(0, 2, o.twin ? "r" : "R"); // 침대(협탁·스탠드 포함)
		if (!o.noBag) put(0, 3, "y"); // 짐 받침대 + 가방(창가)
		put(3, 3, "T"); // 책상·의자·TV(창가)
		if (o.z) put(3, 2, "Z"); // 서랍장(커넥팅 룸만: 문이 둘)
		if (o.cart) put(2, 1, "h"); // 청소하다 버려 둔 하우스키핑 카트
	}
	if (o.connect) put(4, 1, "D"); // 커넥팅 문(옆방, 칸막이벽)
	return G;
}
// 날개 한 줄(복도 한쪽 객실 줄): ys = 방 윗줄 y 들, 짝수 번째는 그대로 / 홀수 번째는 뒤집어 욕실이 등을 맞대게
function wingRow(G, ax, side, ys, opts) {
	ys.forEach((y, n) => room(G, ax, y, side, { mirror: n % 2 === 1, ...((opts && opts[n]) || {}) }));
}

// ════════════════════════ 1층 ════════════════════════
// ══ 북쪽 서비스 고리(뒤쪽): 직원 복도(y1~2) · 주방(x9~20) · 그랜드 볼룸(x22~37) · 하역장(x42~45), 북서쪽 하우스키핑·린넨 ══
g.fill(1, 1, 41, 2); // 직원 복도(북쪽 벽을 따라 주방·볼룸 뒤를 잇는 서비스 통로)
g.set(22, 1, "#").set(22, 2, "D"); // 가운데 방화문(시야를 20칸 안으로 끊는다)
g.fill(42, 1, 45, 10); // 하역장(트럭 대는 곳): 직원 복도 동쪽 끝이 그대로 넓어진다
g.put("c", [[45, 1], [45, 8], [45, 10]]).put("m", [[42, 10]]).set(44, 7, "h").set(43, 10, "L"); // 팔레트·쓰레기 압축기·카트
g.put("c", [[12, 1], [33, 1]]); // 직원 복도: 상자 몇 개만
// 북서쪽 하우스키핑·린넨실(서비스 엘리베이터)
g.fill(1, 4, 4, 10).set(2, 3, "D"); // (직원 복도로 문 하나: 열쇠 상자 없음)
g.put("e", [[1, 7]]).put("j", [[1, 9], [1, 10]]).set(3, 10, "h").set(4, 8, "L");
// 북서쪽 비상계단(서쪽 날개 복도 북쪽 끝 문 → 2층 북서쪽 계단참). 북동쪽도 같은 비상계단(동쪽 날개 복도 → 2층 북동쪽)
g.set(5, 5, "D").wall(3, 4, 4, 4).wall(3, 6, 4, 6);
g.set(41, 5, "D").wall(42, 4, 43, 4).wall(42, 6, 43, 6);
// 메인 주방: 북쪽 벽 화구 줄(K, 후드) · 가운데 조리대 섬(P) · 설거지대 · 건자재 선반,
//   문 셋(직원 복도 쪽 주방 문 · 볼룸 배식 문 · 남쪽 직원 서비스 통로 문). 손님 쪽(날개 복도)에서 주방으로 바로 들어가는 문은 없다
g.fill(9, 4, 20, 10).set(14, 3, "D").set(21, 7, "D").set(14, 11, "D");
g.put("K", [[10, 4], [11, 4], [12, 4], [17, 4], [18, 4]]).put("P", [[11, 7], [12, 7], [16, 7], [17, 7]]);
g.put("j", [[9, 10], [10, 10]]).put("P", [[15, 10], [16, 10]]).set(20, 4, "Z").set(20, 9, "L");
// 그랜드 볼룸(연회장): 기둥 넷, 원탁, 동쪽 끝 무대(z), 가운데 샹들리에. 문 둘(주방 배식 문 · 직원 복도 연회 서비스 문)
//   (볼룸에서 동쪽 날개로 바로 나가는 문은 없다: 있으면 주방 → 볼룸 → 동쪽 날개가 지름길이 된다)
g.fill(22, 4, 37, 10).set(30, 3, "D");
g.put("O", [[26, 6], [33, 6], [26, 9], [33, 9]]).put("U", [[24, 5], [29, 8], [24, 9], [36, 9]]).put("z", [[35, 4], [36, 4], [37, 4]]);
g.put("N", [[29, 6]]).set(22, 10, "Z").set(37, 6, "Z").set(22, 4, "L");

// ══ 객실 날개(1층): 서쪽 날개 복도 x6~7, 동쪽 날개 복도 x39~40 (y3~31, 가운데 방화문 y21) ══
g.fill(6, 3, 7, 31).fill(39, 3, 40, 31);
g.set(6, 21, "D").set(7, 21, "#").set(39, 21, "D").set(40, 21, "#"); // 복도 가운데 방화문(긴 시야 끊기)
const Y1 = [12, 17, 22, 27]; // 객실 줄(4칸 + 칸막이벽)
// 서쪽 날개: 바깥쪽 객실(x1~4, 문 x5)·안쪽 객실(x9~12, 문 x8). 커넥팅: 바깥쪽 아래 한 쌍, 안쪽 위 한 쌍
wingRow(g, 1, "E", Y1, [{ hide: true }, { twin: true }, { z: true, connect: true, hide: true }, { z: true, twin: true }]);
wingRow(g, 9, "W", Y1, [{ hide: true, cart: true }, { empty: true }, { twin: true }, { hide: true }]);
// 동쪽 날개: 안쪽 객실(x34~37, 문 x38)·바깥쪽 객실(x42~45, 문 x41). 커넥팅: 바깥쪽 위 한 쌍, 안쪽 아래 한 쌍
wingRow(g, 34, "E", Y1, [{ hide: true }, { twin: true }, { cart: true }, { twin: true, hide: true }]);
wingRow(g, 42, "W", Y1, [{ hide: true }, { empty: true }, { z: true, connect: true, hide: true }, { z: true, twin: true }]);
// 날개 가운데 비상계단(1층 객실 한 칸 자리 → 2층 같은 날개 객실 한 칸 자리): 긴 날개 복도를 1층·2층 사이에서 가운데로도 오가게
g.wall(10, 19, 10, 20).wall(12, 19, 12, 20).wall(43, 19, 43, 20).wall(45, 19, 45, 20);

// ══ 남서쪽 직원 구역(뒤쪽): 직원 통로(y33~34), 직원 휴게실(시작), 락커실, 직원 계단실(2층 서비스 로비로) ══
g.fill(1, 33, 14, 34).set(6, 32, "D"); // 서쪽 날개 복도 끝 "STAFF ONLY" 문
// 직원 서비스 통로(x14, y12~32): 서쪽 날개 안쪽 객실과 로비 사이 벽 속 뒤쪽 복도(룸서비스·하우스키핑 동선).
//   남서쪽 직원 구역 ↔ 주방을 잇는 백 오브 하우스 고리의 서쪽 변. 로비 쪽 문은 없다. 가운데 방화문(14,22)
g.fill(14, 12, 14, 32).set(14, 22, "D");
g.fill(1, 36, 4, 41).set(1, 35, "D").set(5, 40, "D"); // 직원 휴게실: 직원 통로 · 락커실로 문 둘(방 양 끝)
g.put("S", [[1, 40], [2, 40], [1, 41], [2, 41]]).put("U", [[3, 38]]).put("V", [[4, 41]]).set(4, 36, "L"); // (서쪽 벽 줄 x1 은 비워 둔다: 문 둘로 가는 길이 따로)
g.fill(6, 36, 8, 41).set(7, 35, "D").set(9, 39, "D"); // 락커실: 사물함 줄(l) + 숨는 사물함
g.put("l", [[6, 41], [7, 41], [8, 41]]).set(8, 36, "L").set(6, 36, "Z");
g.fill(10, 36, 13, 41).set(10, 35, "D"); // 직원 계단실
g.wall(11, 36, 11, 37).wall(13, 36, 13, 37);
g.put("h", [[13, 41]]).put("c", [[10, 41]]).set(13, 39, "Z");

// ══ 아트리움 로비(가운데, x16~32 y12~34): 마지막 방. 분수 · 샹들리에 · 기둥 · 엘리베이터 뱅크 · 대계단 · 프런트 데스크 ══
g.fill(16, 12, 32, 34);
// 대계단(로비 북동쪽 → 2층 엘리베이터 홀): 양옆 난간벽
g.wall(31, 12, 32, 13).wall(31, 15, 32, 15);
g.stairs(31, 14, 1, 0);
g.put("e", [[16, 14], [16, 16], [16, 18]]); // 서쪽 벽 엘리베이터 뱅크
g.set(24, 22, "Y").put("i", [[23, 21], [24, 21], [25, 21], [23, 22], [25, 22], [23, 23], [24, 23], [25, 23]]); // 분수(3x3)
g.put("N", [[24, 16], [24, 28]]); // 샹들리에(지나갈 수 있다)
g.put("O", [[20, 18], [28, 18], [20, 27], [28, 27]]); // 아트리움 기둥 넷
g.put("w", [[20, 22], [28, 22], [21, 31]]).put("G", [[19, 33], [22, 33]]);
g.put("F", [[25, 33], [26, 33], [27, 33], [28, 33], [29, 33], [30, 33]]); // 프런트 데스크(뒤 y34 는 직원 쪽 통로, 프런트 사무실 문)
g.set(16, 24, "Z").set(32, 24, "Z"); // 로비 벽 콘솔 서랍장
// 남쪽 줄: 정문(출구, 로비 남쪽 벽의 회전문) · 짐 보관실 · 프런트 사무실
g.set(16, 35, "E"); // 정문 회전문(로비에서 바로 나간다: 바람막이 통로가 길면 괴물 하나가 그 앞을 막는다)
g.fill(18, 36, 23, 41).set(21, 35, "D").put("G", [[18, 41]]).put("c", [[22, 41]]).set(23, 38, "L"); // 짐 보관실(벨 데스크 뒤)
g.fill(26, 36, 32, 41).set(29, 35, "D").put("T", [[27, 38], [31, 38]]).put("k", [[26, 41], [32, 37]]).set(32, 41, "L"); // 프런트 사무실

// ══ 남동쪽 레스토랑·라운지 바(x34~45 y33~41): 동쪽 날개 복도 끝 문 · 로비 문 ══
g.fill(34, 33, 45, 41).set(39, 32, "D").set(33, 33, "D");
g.put("q", [[45, 36], [45, 37], [45, 38]]).put("U", [[36, 36], [36, 40], [43, 37], [43, 40]]).put("P", [[42, 33], [43, 33]]);
// 동쪽 날개 끝 비상계단(레스토랑 안쪽 계단실 → 2층 동쪽 날개 복도 남쪽 끝). 2층 동쪽 날개 남쪽 절반이 막다른 곳이 되지 않게
g.wall(39, 38, 39, 39).wall(41, 38, 41, 39);
g.put("w", [[43, 41]]).set(34, 41, "Z").set(45, 33, "Z");

// ════════════════════════ 2층 객실층 ════════════════════════
// 북쪽 객실 복도(y6~7) · 서쪽 날개 복도(x6~7) · 동쪽 날개 복도(x39~40)가 ㄷ자로 아트리움 위 빈 공간을 감싼다.
up.fill(6, 6, 40, 7).fill(6, 8, 7, 41).fill(39, 8, 40, 41);
up.set(18, 6, "#").set(18, 7, "D"); // 북쪽 복도 방화문(커넥팅 룸 문 앞을 피해 x18)
up.set(6, 23, "D").set(7, 23, "#").set(39, 23, "D").set(40, 23, "#"); // 날개 복도 가운데 방화문
// 북쪽 객실 줄(y1~4, 문 y5)
const NX = [9, 14, 19, 24, 29, 34];
NX.forEach((x, n) => room(up, x, 1, "S", { mirror: n % 2 === 1, ...[{ hide: true }, { twin: true }, { z: true, connect: true }, { z: true, hide: true }, { hide: true }, { twin: true, hide: true }][n] }));
// 북서쪽 비상계단참(복도로 문) + 린넨 창고
up.fill(1, 4, 4, 7).set(5, 6, "D").put("c", [[4, 7]]).set(1, 7, "L");
up.fill(1, 1, 4, 2).set(2, 3, "D").put("j", [[3, 1], [4, 1]]);
up.fill(6, 1, 7, 4).set(6, 5, "D").put("j", [[6, 1], [7, 1]]).set(7, 4, "h"); // 층 린넨 벽장
// 북동쪽 비상계단참(복도로 문) + 린넨 창고
up.fill(42, 4, 45, 7).set(41, 6, "D").set(45, 7, "L");
up.fill(42, 1, 45, 2).set(43, 3, "D").put("j", [[44, 1], [45, 1]]);
up.fill(39, 1, 40, 4).set(39, 5, "D").put("j", [[39, 1], [40, 1]]);
// 북쪽 복도 남쪽 서비스 줄(y9~11): 층 린넨실 · 제빙기·자판기 · 투숙객 세탁실 · 하우스키핑 사무실 (모두 문 하나)
up.fill(14, 9, 18, 11).set(16, 8, "D").put("j", [[14, 11], [15, 11], [18, 11]]).set(14, 9, "h").set(18, 9, "L");
up.fill(20, 9, 22, 11).set(21, 8, "D").put("V", [[20, 11], [22, 11]]);
up.fill(24, 9, 28, 11).set(26, 8, "D").put("W", [[24, 11], [25, 11], [24, 9]]).set(28, 11, "L");
up.fill(30, 9, 32, 11).set(31, 8, "D").put("T", [[30, 11]]).put("k", [[32, 9]]);
// 날개 객실 줄(2층): y9~12 … y34~37, 맨 아래 y39~41 은 창고
const Y2 = [9, 14, 19, 24, 29, 34];
wingRow(up, 1, "E", Y2, [{ twin: true }, { hide: true }, { hide: true }, { twin: true }, { cart: true }, { hide: true }]);
wingRow(up, 9, "W", Y2.slice(0, 5), [{ hide: true }, { twin: true }, { empty: true }, { twin: true }, { hide: true }]);
wingRow(up, 34, "E", [9], [{ hide: true }]);
wingRow(up, 34, "E", Y2.slice(2), [{ twin: true }, { hide: true }, { hide: true }, { twin: true }]);
wingRow(up, 42, "W", Y2, [{ hide: true }, { twin: true }, { empty: true }, { cart: true }, { z: true, connect: true, hide: true }, { z: true, twin: true }]);
// 2층 서쪽 서비스 로비(직원 계단 도착, x9~12 y34~37): 하우스키핑 카트 대기 칸
up.fill(9, 34, 12, 37).set(8, 35, "D").put("h", [[9, 37], [10, 37]]).set(9, 34, "Z");
// 2층 엘리베이터 홀(대계단 도착, x34~37 y14~17): 엘리베이터 문 · 소파 · 콘솔 서랍장
up.fill(34, 14, 37, 17).set(38, 15, "D").put("e", [[35, 17], [36, 17]]).put("w", [[34, 17]]).set(37, 14, "Z");
// 맨 아래 창고(y39~41)
up.fill(1, 39, 4, 41).set(5, 40, "D").put("j", [[1, 41], [2, 41]]).set(4, 39, "L");
up.fill(9, 39, 12, 41).set(8, 40, "D").put("c", [[12, 41]]).put("j", [[11, 41]]);
up.fill(34, 39, 37, 41).set(38, 40, "D").put("V", [[34, 41]]).set(37, 39, "L");
up.fill(42, 39, 45, 41).set(41, 40, "D").put("j", [[44, 41], [45, 41]]).set(42, 41, "h");

// 직원 계단(1층 직원 계단실 → 2층 서쪽 서비스 로비). 2층 방을 판 뒤에 놓아야 계단 구멍(o)이 남는다
g.stairs(12, 37, 0, -1);
g.stairs(40, 39, 0, -1);
g.stairs(4, 5, -1, 0);
g.stairs(42, 5, 1, 0);
g.stairs(11, 19, 0, 1);
g.stairs(44, 19, 0, 1);

const opts = { walkable: ["k", "N"], id: 6 };
const r = report("호텔", g, opts);
if (process.argv.includes("--print")) for (const [name, gr] of [["1층", g], ["2층", up]]) console.log(name + "\n" + gr.rows().map((row, i) => String(i).padStart(2) + " " + row).join("\n"));
// 스테이지 파일의 소품 줄과 호텔 전용 소품 모듈 require 줄도 생성기가 맞춘다.
// 임시 폴더에 완성본을 만든 뒤 한 번에 옮긴다(Rojo 가 반쯤 쓴 파일을 읽지 않게)
const fs = require("fs");
const path = require("path");
const sf = path.join(__dirname, "..", "..", "src", "server", "Stages", "Stage6.luau");
const PROPS_LINE =
	"\tProps = { R = CP.GuestBed, r = CP.TwinBeds, u = CP.Bathroom, T = CP.WritingDesk, y = CP.LuggageRack, a = CP.Wardrobe, Y = CP.Fountain, i = CP.Blank, N = CP.Chandelier, z = CP.BanquetStage, k = Props.Cabinet, F = CP.FrontDesk, G = CP.LuggageCart, w = CP.Sofa, q = CP.BarCounter, U = CP.RoundTable, K = CP.Range, P = CP.PrepTable, W = CP.Washer, j = CP.LinenShelf, l = CP.StaffLockers, h = CP.HousekeepingCart, V = CP.IceMachine, e = CP.Elevator },";
const WALK_LINE = "\tWalkable = { k = true, N = true, P = false }, -- (캐비닛은 벽에 붙어 칸 반이 빈다 · 샹들리에는 머리 위: 지나갈 수 있다. 조리대 P 와 나머지 소품은 막힌 칸)";
function patchProps() {
	let s = fs.readFileSync(sf, "utf8");
	const crlf = s.includes("\r\n");
	s = s.replace(/\r\n/g, "\n");
	if (!s.includes("ChapterProps.Hotel")) s = s.replace(/(local Props = require\(script\.Parent\.Parent\.Props\)\n)/, "$1local CP = require(script.Parent.Parent.ChapterProps.Hotel)\n");
	s = s.replace(/\tProps = \{[^\n]*\n/, PROPS_LINE + "\n").replace(/\tWalkable = \{[^\n]*\n/, WALK_LINE + "\n");
	return crlf ? s.replace(/\n/g, "\r\n") : s;
}
if (!process.argv.includes("--dry")) {
	const tmp = path.join(fs.mkdtempSync(path.join(require("os").tmpdir(), "stage6-")), "Stage6.luau");
	fs.writeFileSync(tmp, patchProps());
	const outDir = process.env.STAGE_OUT_DIR;
	delete process.env.STAGE_OUT_DIR;
	writeStage(path.relative(path.dirname(sf), tmp), g, [
		"STAGE 6 — 호텔 (47x43칸, 2층 건물, tools/places/hotel.js 로 생성)",
		"뼈대: 가운데 아트리움 로비를 ㄷ자 객실 날개(서쪽 · 북쪽 · 동쪽, 가운데 복도 양쪽 객실)가 감싸고, 뒤쪽 직원 구역이 붙는다.",
		"1층: 남서쪽 직원 구역(휴게실 = 시작 · 락커실 · 직원 계단) → 서쪽 객실 날개 → 북쪽 서비스 고리(직원 복도 · 주방 · 그랜드 볼룸 · 하역장)",
		"→ 동쪽 객실 날개 → 레스토랑·라운지 바 → 아트리움 로비(분수 · 샹들리에 · 엘리베이터 뱅크 · 프런트 데스크) → 정문 바람막이(출구).",
		"2층(Rows2): 같은 ㄷ자 객실층(북쪽 객실 줄 · 코너 스위트 둘 · 서비스 줄). 직원 계단(남서)으로 올라 대계단(로비 북동)으로 내려온다.",
		"객실: 문 옆 욕실 · 옷장 · 협탁 달린 침대 · 창가 짐 받침대와 책상·TV, 커넥팅 룸만 서랍장(열쇠 상자). 복도 가운데 방화문.",
		`출구까지 최단 약 ${r.exit}칸.`,
	]);
	fs.copyFileSync(tmp, outDir ? path.join(outDir, "Stage6.luau") : sf);
}
