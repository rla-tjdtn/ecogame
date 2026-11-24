// 조각 디자인(SDF 원시 도형) → 게임 부품 + 포즈 프레임(Luau 데이터)
// node bake.js <설정 이름>   (설정은 아래 CFG)
// 게임에서는 원통(실루엣 2줄)·공(원)·상자 모서리만 음파에 보이므로, 원시 도형 수천 개를 부품 수백 개로 줄인다.
// 디자인은 포즈를 바꿔도 원시 도형 순서가 같으므로, 같은 부품을 포즈마다 다시 계산해 '구운 애니메이션'을 만든다.
const fs = require('fs'), path = require('path');
const SRC = path.join(__dirname, '..');
const OUT = path.join(__dirname, '..', '..', '..', '..', 'src', 'shared', 'CreatureData');
const CFG = {
  // 1장 메인: 흉문 / 척수, 1장 서브: 양두 / 나무
  k1h1: { mod: 'set1/c1h', name: '흉문', budget: 336, walk: {}, chase: { open: 1.2 }, attack: { open: -0.35, lean: 0.9, walk: 0.25 }, stride: 3.2 },
  k1h2: { mod: 'set2/d1h', name: '척수', budget: 336, walk: {}, chase: { sway: 0.6 }, attack: { drop: 1, walk: 0.6 }, stride: 3.6 },
  k1s1: { mod: 'set2/d1n', name: '양두', budget: 320, walk: {}, chase: { up: 0.5 }, attack: { up: 1, walk: 0.3 }, stride: 2.6 },
  // 2장 메인: 갈고리 / 진열장, 2장 서브: 다섯 손가락 / 가위
  k2h1: { mod: 'set1/c2n', name: '갈고리', budget: 336, walk: {}, chase: { strike: -0.25 }, attack: { strike: 1, walk: 0.5 }, stride: 2.4 },
  k2h2: { mod: 'set3/e2h', name: '진열장', budget: 368, walk: { awake: 0.7 }, chase: { awake: 0.7 }, attack: { awake: 0.7, walk: 0.6, headYaw: 10 }, stride: 3.0 },
  k2s1: { mod: 'set2/d2n', name: '다섯 손가락', budget: 384, walk: {}, chase: {}, attack: { walk: 0.7 }, stride: 2.0 },
  k2s2: { mod: 'set3/e2n', name: '가위', budget: 336, walk: { open: 0.75 }, chase: { open: 1 }, attack: { open: 0.35, walk: 0.7 }, stride: 3.0 },
  // 3장 메인: 부은 자 / 수초, 3장 서브: 아가리 / 칠성 (입 벌림 jaw 는 포즈마다 같게 — 바꾸면 얼굴 도형 순서가 바뀐다)
  k3h1: { mod: 'set1/c3h', name: '부은 자', budget: 336, walk: {}, chase: {}, attack: { walk: 0.75 }, stride: 2.4 },
  k3h2: { mod: 'set2/d3h', name: '수초', budget: 480, walk: { open: 0.15 }, chase: { open: 1.05 }, attack: { open: 1.3, walk: 0.6 }, stride: 2.8 },
  k3s1: { mod: 'set1/c3n', name: '아가리', budget: 320, walk: { jaw: 52, headUp: 18 }, chase: { jaw: 52, headUp: 18 }, attack: { jaw: 52, headUp: 26, walk: 0.6 }, stride: 1.8 },
  k3s2: { mod: 'set3/e3h', name: '칠성', budget: 352, walk: { gape: 0.6 }, chase: { gape: 0.9 }, attack: { gape: 1.25, walk: 0.6 }, stride: 3.0 },
  // 4장 메인: 수간호사 / 무영등 / 폐, 4장 서브: 바퀴 / 거꾸로 기는 환자 / 뒤집힌 환자 / 합본
  k4h1: { mod: 'set4/f4h', name: '수간호사', budget: 368, walk: {}, chase: { lean: 14 }, attack: { lean: 18, raise: 1, walk: 0.5 }, stride: 3.4 },
  k4h2: { mod: 'set2/d4h', name: '무영등', budget: 368, walk: {}, chase: { tilt: 20 }, attack: { tilt: 0, walk: 0.5 }, stride: 3.6 },
  k4h3: { mod: 'set3/e4n', name: '폐', budget: 384, walk: { breath: 0.6 }, chase: { breath: 1 }, attack: { breath: 1.25, walk: 0.5 }, stride: 2.6 },
  k4s1: { mod: 'set2/d4n', name: '바퀴', budget: 368, phase: 'roll', walk: {}, chase: {}, attack: { roll: 0.3 }, stride: 6.1 },
  k4s2: { mod: 'set4/f4n', name: '거꾸로 기는 환자', budget: 352, walk: {}, chase: { arch: 0.5 }, attack: { arch: 1, walk: 0.5 }, stride: 2.6 },
  k4s3: { mod: 'set1/c4n', name: '뒤집힌 환자', budget: 336, walk: {}, chase: {}, attack: { walk: 0.5 }, stride: 2.4 },
  k4s4: { mod: 'set1/c4h', name: '합본', budget: 352, walk: {}, chase: { lean: 10 }, attack: { lean: 20, walk: 0.5 }, stride: 3.0 },
  // 5장 메인: 길잡이 / 나선, 5장 서브: 웅크린 것 / 끼인 것 / 청음귀
  k5h1: { mod: 'set2/d5h', name: '길잡이', budget: 384, walk: {}, chase: { point: 1 }, attack: { point: 1, eye: 1, walk: 0.5 }, stride: 3.4 },
  k5h2: { mod: 'set1/c5h', name: '나선', budget: 352, walk: {}, chase: { twist: 1.7 }, attack: { twist: 2.0, walk: 0.5 }, stride: 3.2 },
  k5s1: { mod: 'set1/c5n', name: '웅크린 것', budget: 352, walk: {}, chase: {}, attack: { jawDrop: 1.4, walk: 0.5 }, stride: 2.4 },
  k5s2: { mod: 'set2/d5n', name: '끼인 것', budget: 352, phase: 'turn', walk: {}, chase: {}, attack: { turn: 0.06, jaw: 1 }, stride: 4.0 },
  k5s3: { mod: 'set4/f5n', name: '청음귀', budget: 352, walk: { listen: 0.6 }, chase: { listen: 1, low: 0.5 }, attack: { listen: 1, low: 1, walk: 0.5 }, stride: 2.4 },
  // 6장 메인: 무도회 / 벨보이 / 지배인, 6장 서브: 여행가방 / 반쪽 / 욕조 / 젖은 투숙객
  k6h1: { mod: 'set2/d6n', name: '무도회', budget: 300, walk: {}, chase: {}, attack: { spin: 0.22, bow: 1 }, stride: 2.0 },
  k6h2: { mod: 'set4/f6h', name: '벨보이', budget: 300, walk: { offer: 0, bow: 8 }, chase: { offer: 0.4, bow: 10, tilt: -8 }, attack: { bow: 30, offer: 1, tilt: 26 }, stride: 3.0 },
  k6h3: { mod: 'set1/c6h', name: '지배인', budget: 300, walk: {}, chase: { flare: 1.1 }, attack: { flare: 1.1, headRoll: 30, walk: 0.5 }, stride: 2.6 },
  k6s1: { mod: 'set1/c6n', name: '여행가방', budget: 300, phase: 'hop', walk: { open: 98, jaw: 34, tilt: -8 }, chase: { open: 105, jaw: 40, tilt: -14 }, attack: { open: 105, hop: 0.9, jaw: 40, tilt: -14 }, stride: 2.5 },
  k6s2: { mod: 'set2/d6h', name: '반쪽', budget: 300, walk: {}, chase: { gap: 1.2, lag: 0.7 }, attack: { gap: 1.2, lag: 0.7, walk: 0.6 }, stride: 3.2 },
  k6s3: { mod: 'set3/e6n', name: '욕조', budget: 300, walk: { rise: 0.6 }, chase: { rise: 1 }, attack: { rise: 1, walk: 0.35, jaw: 56 }, stride: 2.6 },
  k6s4: { mod: 'set4/f6n', name: '젖은 투숙객', budget: 300, walk: {}, chase: { lift: 0.5 }, attack: { walk: 0.6, hump: 1.4, jaw: 30 }, stride: 2.4 },
  // 7장 메인: 복도 끝 그 애 / 걸상 / 저요, 7장 서브: 인체모형 / 판서 / 풍금
  k7h1: { mod: 'set4/f7h', name: '복도 끝 그 애', budget: 300, walk: { tilt: 46 }, chase: { tilt: 38, jaw: 14, hairLen: 1.1 }, attack: { walk: 0.3, tilt: 38, jaw: 14, hairLen: 1.1, headYaw: -24 }, stride: 2.6 },
  k7h2: { mod: 'set1/c7h', name: '걸상', budget: 300, walk: {}, chase: { jaw: 42 }, attack: { walk: 0.7, jaw: 42 }, stride: 3.0 },
  k7h3: { mod: 'set1/c7n', name: '저요', budget: 300, phase: 'roll', walk: { jaw: 46 }, chase: { jaw: 46 }, attack: { jaw: 60 }, stride: 3.0 },
  k7s1: { mod: 'set3/e7h', name: '인체모형', budget: 300, walk: { panel: 0.1 }, chase: { jaw: 48 }, attack: { walk: 0.6, jaw: 48, panel: 0.5 }, stride: 3.0 },
  k7s2: { mod: 'set2/d7h', name: '판서', budget: 300, walk: {}, chase: { jaw: 8 }, attack: { walk: 0.6, raise: 1, jaw: 46 }, stride: 3.2 },
  k7s3: { mod: 'set3/e7n', name: '풍금', budget: 300, walk: { sing: 0.1 }, chase: { sing: 0.7, gape: 0.6 }, attack: { sing: 0.7, walk: 0.4, gape: 1.15 }, stride: 2.6 },
  k7h4: { mod: 'set1/c8h', name: '술래', budget: 300, walk: {}, chase: { peek: 0.42, nod: -4 }, attack: { walk: 0.6, peek: 0.42, nod: -4 }, stride: 3.0 }, // (8장 디자인을 7장 학교 메인으로)
  // 8장 메인: 토끼 / 토끼 선생님 / 미끄럼틀, 8장 서브: 누더기 / 흔들말 / 모빌 / 큰 인형
  k8h1: { mod: 'set2/d8h', name: '토끼', budget: 300, walk: {}, chase: { ear: 1 }, attack: { walk: 0.6, hug: 1, mouth: 1 }, stride: 2.8 },
  k8h2: { mod: 'set4/f8h', name: '토끼 선생님', budget: 300, walk: {}, chase: { nod: -4, tilt: -8 }, attack: { walk: 0.6, nod: -4, tilt: -8 }, stride: 3.0 },
  k8h3: { mod: 'set3/e8n', name: '미끄럼틀', budget: 300, walk: { gape: 0.7 }, chase: { gape: 0.5 }, attack: { walk: 0.4, gape: 1 }, stride: 3.0 },
  k8s1: { mod: 'set3/e8h', name: '누더기', budget: 300, walk: {}, chase: { jaw: 30 }, attack: { walk: 0.6, jaw: 54 }, stride: 2.6 },
  k8s2: { mod: 'set2/d8n', name: '흔들말', budget: 300, phase: 'rock', phaseAmp: 13, walk: {}, chase: { jaw: 20 }, attack: { rock: 13, jaw: 34 }, stride: 2.5 },
  k8s3: { mod: 'set1/c8n', name: '모빌', budget: 300, phase: 'spin', walk: {}, chase: {}, attack: { spin: 0.2, drop: 1, jaw: 48 }, stride: 3.0 },
  k8s4: { mod: 'set4/f8n', name: '큰 인형', budget: 300, walk: {}, chase: { nod: 6, tilt: 10 }, attack: { walk: 0.55, nod: 6, tilt: 10 }, stride: 2.6 },
  // 9장 메인: 키다리 / 치인 자 / 압축, 9장 서브: 차밑 / 덮개 / 전조등 / 보닛
  k9h1: { mod: 'set3/e9h', name: '키다리', budget: 300, walk: {}, chase: { tilt: -14 }, attack: { walk: 0.6, drop: 1, jaw: 56 }, stride: 4.5 },
  k9h2: { mod: 'set1/c9h', name: '치인 자', budget: 300, walk: {}, chase: {}, attack: { walk: 0.6, headYaw: 20 }, stride: 2.6 },
  k9h3: { mod: 'set3/e9n', name: '압축', budget: 300, walk: {}, chase: { jaw: 30 }, attack: { walk: 0.4, jaw: 52, cant: -6 }, stride: 2.4 },
  k9s1: { mod: 'set4/f9n', name: '차밑', budget: 300, phase: 'crawl', walk: {}, chase: { lift: 0.4 }, attack: { crawl: 0.6, jaw: 42, lift: 0.8 }, stride: 2.6 },
  k9s2: { mod: 'set2/d9n', name: '덮개', budget: 300, phase: 'open', phaseBase: 0.55, phaseAmp: 0.4, walk: { jaw: 44 }, chase: { jaw: 50 }, attack: { open: 1, jaw: 50 }, stride: 3.0 },
  k9s3: { mod: 'set1/c9n', name: '전조등', budget: 300, walk: {}, chase: {}, attack: { walk: 0.6 }, stride: 2.6 },
  k9s4: { mod: 'set2/d9h', name: '보닛', budget: 300, walk: {}, chase: {}, attack: { walk: 0.65 }, stride: 3.0 },
  // 10장 메인: 뜬눈(3마리), 10장 서브: 잔상 / 만석 / 영사기사
  k10h1: { mod: 'set3/e10h', name: '뜬눈', budget: 300, walk: {}, chase: { tilt: 10 }, attack: { walk: 0.6, jaw: 56, nod: 12 }, stride: 3.0 },
  k10s1: { mod: 'set1/c10h', name: '잔상', budget: 300, walk: { fan: 0.25 }, chase: { fan: 1.25 }, attack: { walk: 0.7, fan: 1.25 }, stride: 3.0 },
  k10s2: { mod: 'set1/c10n', name: '만석', budget: 300, walk: {}, chase: { look: 40 }, attack: { walk: 0.55, look: 40 }, stride: 2.4 },
  k10s3: { mod: 'set2/d10h', name: '영사기사', budget: 300, walk: {}, chase: { tilt: 16, reel: 0.2 }, attack: { walk: 0.65, tilt: 16, reel: 0.2, jaw: 40 }, stride: 3.0 },
  k1s2: { mod: 'set3/e1n', name: '나무', budget: 368, walk: {}, chase: { sway: 0.5 }, attack: { walk: 0.6 }, stride: 2.2 },
};
const N_WALK = 8;
const f2 = x => Math.round(x * 100) / 100, f3 = x => Math.round(x * 1000) / 1000;
const V = { sub: (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]], len: a => Math.hypot(a[0], a[1], a[2]), add: (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]], mul: (a, k) => [a[0] * k, a[1] * k, a[2] * k], dot: (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2] };
const qaxes = q => { const [x, y, z, w] = q; return [[1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w)], [2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w)], [2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y)]]; };

function prims(C, p) { const B = C.build(p); const out = []; B.groups.forEach((g, gi) => g.prims.forEach(pr => out.push({ ...pr, g: gi }))); return out; }

// 기본 포즈에서 '부품' 목록을 정한다(인덱스 기준) → 다른 포즈에도 같은 규칙 적용
function plan(P) {
  const items = []; let i = 0;
  while (i < P.length) {
    const p = P[i];
    if (p.op) { i++; continue; } // 빼기·홈은 선이 안 됨
    if (p.t === 0 && p.ex === 1) { // 관(tube) 한 줄: 휘는 곳에서 끊어 합친다
      let j = i; while (j + 1 < P.length && P[j + 1].ex >= 2 && P[j + 1].g === p.g) { j++; if (P[j].ex === 3) break; }
      let s = i, dir0 = null, L = 0;
      for (let k = i; k <= j; k++) {
        const q = P[k], d = V.sub(q.b, q.a), l = V.len(d); const u = l > 1e-6 ? V.mul(d, 1 / l) : [0, 1, 0];
        if (!dir0) dir0 = u;
        const bend = V.dot(u, dir0) < Math.cos(24 * Math.PI / 180), rr = Math.abs(q.rb - P[s].ra) > Math.max(P[s].ra, .05) * .6;
        if (k > s && (bend || L + l > 2.2 || rr)) { items.push({ k: 'seg', s, e: k - 1, g: p.g }); s = k; dir0 = u; L = 0; }
        L += l;
      }
      items.push({ k: 'seg', s, e: j, g: p.g }); i = j + 1; continue;
    }
    if (p.t === 0) items.push({ k: V.len(V.sub(p.b, p.a)) < 1e-4 ? 'ball' : 'seg', s: i, e: i, g: p.g });
    else if (p.t === 1) items.push({ k: 'ell', s: i, g: p.g });
    else if (p.t === 2) items.push({ k: 'box', s: i, g: p.g });
    i++;
  }
  return items;
}
// 부품 하나의 모양(포즈 P 기준)
function geom(it, P) {
  if (it.k === 'seg') { let r = 0, n = 0; for (let k = it.s; k <= it.e; k++) { r += P[k].ra + P[k].rb; n += 2; } return { t: 'c', a: P[it.s].a, b: P[it.e].b, r: r / n }; }
  if (it.k === 'ball') return { t: 'b', a: P[it.s].a, r: P[it.s].ra };
  const p = P[it.s], ax = qaxes(p.q || [0, 0, 0, 1]);
  if (it.k === 'ell') { // 가장 긴 축을 따라 원통(굵기 = 나머지 두 축 평균), 거의 구면 공
    const r = p.b, order = [0, 1, 2].sort((x, y) => r[y] - r[x]), m = order[0], r2 = (r[order[1]] + r[order[2]]) / 2;
    void m; void r2; void ax; return { t: 'e', a: p.a, h: p.b, q: p.q || [0, 0, 0, 1] }; // 타원체 그대로(게임: 구 메시를 늘림)
  }
  return { t: 'x', a: p.a, h: p.b, q: p.q || [0, 0, 0, 1] }; // 상자
}
const size = g => g.t === 'c' ? V.len(V.sub(g.b, g.a)) * Math.sqrt(g.r) + g.r * 2 : g.t === 'b' ? g.r * 3 : g.t === 'e' ? (g.h[0] + g.h[1] + g.h[2]) * 1.1 : Math.max(...g.h) * 2;
const K_GROUPS = 7; // 윤곽선 묶음(게임 Highlight: 한 화면 31개 제한 → 괴물마다 7)
const LINE_R = .045; // 이보다 가는 관은 흰 선(네온)으로 그린다
// 디자인 그룹들을 위치로 K 묶음(가중 k-평균, 결정적)
function cluster(items, K) {
  const gs = {}; for (const it of items) { const g = it.g0, c = g.t === 'c' ? V.mul(V.add(g.a, g.b), .5) : g.a, w = size(g); const e = gs[it.g] || (gs[it.g] = { s: [0, 0, 0], w: 0 }); e.s = V.add(e.s, V.mul(c, w)); e.w += w; }
  const keys = Object.keys(gs), pts = keys.map(k => ({ k, c: V.mul(gs[k].s, 1 / gs[k].w), w: gs[k].w }));
  K = Math.min(K, pts.length); const cs = [[...pts].sort((a, b) => b.c[1] - a.c[1])[0].c];
  while (cs.length < K) { let best = null, bd = -1; for (const p of pts) { const d = Math.min(...cs.map(c => V.len(V.sub(p.c, c)))) * Math.sqrt(p.w); if (d > bd) { bd = d; best = p; } } cs.push(best.c); }
  const as = {}; for (let n = 0; n < 20; n++) { const acc = cs.map(() => ({ s: [0, 0, 0], w: 0 })); for (const p of pts) { let bi = 0, bd = 1e9; cs.forEach((c, i) => { const d = V.len(V.sub(p.c, c)); if (d < bd) { bd = d; bi = i; } }); as[p.k] = bi; acc[bi].s = V.add(acc[bi].s, V.mul(p.c, p.w)); acc[bi].w += p.w; } acc.forEach((a, i) => { if (a.w) cs[i] = V.mul(a.s, 1 / a.w); }); }
  return as;
}

module.exports = { CFG };
if (require.main === module) for (const id of process.argv.slice(2)) {
  const c = CFG[id]; const C = require(path.join(SRC, c.mod + '.js'));
  const PK = c.phase || 'walk'; const ph = (o, v) => ({ ...o, [PK]: v });
  const P0 = prims(C, ph(c.walk, 0));
  let items = plan(P0).map(it => ({ ...it, g0: geom(it, P0) })).filter(it => (it.g0.t !== 'c' || it.g0.r > .018) && size(it.g0) > .09);
  // 그룹마다 가장 큰 것 2개는 꼭 넣고(얼굴·손 같은 작은 부위가 빠지지 않게), 나머지는 크기 순으로 예산까지
  const byG = {}; for (const it of items) (byG[it.g] = byG[it.g] || []).push(it);
  const keep = new Set(); for (const g in byG) byG[g].sort((a, b) => size(b.g0) - size(a.g0)).slice(0, 2).forEach(it => keep.add(it));
  items.sort((a, b) => size(b.g0) - size(a.g0)); for (const it of items) { if (keep.size >= c.budget) break; keep.add(it); }
  items = items.filter(it => keep.has(it));
  // 관 줄기 안에서 앞뒤로 이어지는가(이음매를 공으로 메운다)
  items.forEach((it, i) => { it.capA = !(i > 0 && items[i - 1].k === 'seg' && it.k === 'seg' && items[i - 1].e + 1 === it.s && items[i - 1].g === it.g); });
  items.forEach((it, i) => { it.capB = !(i + 1 < items.length && items[i + 1].k === 'seg' && it.k === 'seg' && !items[i + 1].capA); });
  const grp = cluster(items, K_GROUPS);
  const gi = it => (it.g0.t === 'c' && it.g0.r < LINE_R) ? 0 : grp[it.g] + 1;
  const pdef = (g, i) => { const it = items[i], G = gi(it); return g.t === 'c' ? ['c', f2(g.r), G, (it.capA ? 1 : 0) + (it.capB ? 2 : 0)] : g.t === 'b' ? ['b', f2(g.r), G] : [g.t, ...g.h.map(f2), G]; };
  // 포즈 프레임
  const frameOf = p => { const P = prims(C, p); if (P.length !== P0.length) throw new Error(id + ' 포즈마다 원시 도형 수가 다름: ' + JSON.stringify(p)); return items.map(it => geom(it, P)); };
  const walkN = [...Array(N_WALK)].map((_, k) => frameOf(ph(c.walk, k / N_WALK)));
  const chaseN = [...Array(N_WALK)].map((_, k) => frameOf(ph(c.chase, k / N_WALK)));
  const attack = frameOf(c.attack), idle = frameOf(ph(c.walk, 0));
  const fl = fr => fr.map(g => g.t === 'c' ? [...g.a, ...g.b].map(f2) : g.t === 'b' ? g.a.map(f2) : [...g.a.map(f2), ...g.q.map(f3)]).flat();
  const parts = idle.map((g, i) => '{' + pdef(g, i).map(v => typeof v === 'string' ? '"' + v + '"' : v).join(',') + '}');
  let floor = 1e9; for (const g of idle) floor = Math.min(floor, g.t === 'c' ? Math.min(g.a[1], g.b[1]) - g.r : g.a[1] - (g.r || (g.h ? Math.max(...g.h) : 0))); floor = f2(Math.min(floor, 0));
  const lua = `--!strict\n-- 자동 생성(art/creatures/source/game/bake.js): ${c.name} — 디자인 ${c.mod}. 손으로 고치지 말 것\nreturn {\n\tid = "${id}", name = "${c.name}", floor = ${floor}, stride = ${c.stride},\n` +
    `\tgroups = ${K_GROUPS},\n\tparts = { ${parts.join(', ')} },\n\t-- 프레임: 부품마다 원통 = a,b(6수) / 공 = 중심(3) / 타원체·상자 = 중심(3) + 회전 사원수(4). 부품 = { 종류, 크기…, 묶음(0 = 흰 선), 이음 공(원통: 1 = a 끝, 2 = b 끝) }\n` +
    `\tidle = { ${fl(idle).join(',')} },\n\tattack = { ${fl(attack).join(',')} },\n` +
    `\twalk = {\n${walkN.map(f => '\t\t{ ' + fl(f).join(',') + ' },').join('\n')}\n\t},\n\tchase = {\n${chaseN.map(f => '\t\t{ ' + fl(f).join(',') + ' },').join('\n')}\n\t},\n}\n`;
  fs.mkdirSync(OUT, { recursive: true }); fs.writeFileSync(path.join(OUT, id + '.luau'), lua);
  fs.mkdirSync(path.join(__dirname, 'out'), { recursive: true }); fs.writeFileSync(path.join(__dirname, 'out', id + '.json'), JSON.stringify({ name: c.name, groups: K_GROUPS, parts: idle.map(pdef), idle: fl(idle), attack: fl(attack), walk: walkN.map(fl), chase: chaseN.map(fl) }));
  const cnt = { c: 0, b: 0, e: 0, x: 0, line: 0 }; items.forEach(it => { if (gi(it) === 0) cnt.line++; }); idle.forEach(g => cnt[g.t]++);
  console.log(id, c.name, 'parts', items.length, JSON.stringify(cnt), 'floor', floor, (lua.length / 1024).toFixed(0) + 'KB');
}
