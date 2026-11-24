// 서브 괴물 자리 소품(src/server/HomeProps.luau) 메시. 좌표 = 칸 가운데 바닥(HomeProps.place 의 cf), y 위, -z = 칸 뒤쪽(벽 쪽).
const { T, Rx, Ry, Rz, roundRect, circle2, arc2 } = require('../lib/model.js');

const flat = (m, poly, y0, h, o = {}) => m.with(Rx(-Math.PI / 2), () => m.extrude(poly.map(([x, z]) => [x, -z]), h, { z0: y0, ...o }));
const side = (m, poly, x, t, o = {}) => m.with(T(x, 0, 0).mul(Ry(-Math.PI / 2)), () => m.extrude(poly, t, { z0: -t / 2, ...o }));
const front = (m, poly, z, t, o = {}) => m.extrude(poly, t, { z0: z - t / 2, ...o });
const rect = (x0, y0, x1, y1) => [[x0, y0], [x1, y0], [x1, y1], [x0, y1]];
const loop = (poly, y) => poly.map(([x, z]) => [x, y, z]);
// 별·달·구름 모양(모빌 인형)
function star(r) { const o = []; for (let i = 0; i < 10; i++) { const a = Math.PI / 2 + i * Math.PI / 5, rr = i % 2 ? r * 0.45 : r; o.push([Math.cos(a) * rr, Math.sin(a) * rr]); } return o; }
function moon(r) { return [...arc2(0, 0, r, Math.PI * 0.35, Math.PI * 1.65, 7), ...arc2(r * 0.45, 0, r * 0.8, Math.PI * 1.45, Math.PI * 0.55, 5).slice(1, -1)].reverse(); }
function cloud(r) { return [...arc2(-r * 0.5, 0, r * 0.45, Math.PI * 1.5, Math.PI * 0.6, 3), ...arc2(0, r * 0.25, r * 0.5, Math.PI * 0.85, Math.PI * 0.15, 3), ...arc2(r * 0.5, 0, r * 0.45, Math.PI * 0.4, -Math.PI * 0.5, 3)].reverse(); }

module.exports = {
  // 다리 달린 욕조(클로풋): 넓은 위 테두리(안쪽 테 한 줄) → 좁은 바닥으로 오므라든 몸통 + 짐승 발 다리 넷 + 서 있는 수전(거위목·손잡이)
  // 길이 6(z) 폭 2.8, 테두리 높이 3.0, -z = 머리 쪽(수전)
  'Home.Bathtub': (m) => {
    const top = roundRect(2.8, 6.0, 1.25, 2), bot = roundRect(2.3, 5.3, 1.0, 2);
    flat(m, bot, 0.7, 2.25, { lines: 'none' });
    flat(m, top, 2.6, 0.4, { caps: 'front', sides: false });
    m.line(loop(bot, 0.7), { closed: true });
    m.line(loop(roundRect(2.4, 5.6, 1.05, 2), 3.0), { closed: true });
    for (const [a, b] of [[[0, -3.0], [0, -2.65]], [[0, 3.0], [0, 2.65]], [[1.4, 0], [1.15, 0]], [[-1.4, 0], [-1.15, 0]]]) m.line([[a[0], 2.6, a[1]], [b[0], 0.7, b[1]]]);
    for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
      const x = sx * 1.0, z = sz * 2.3;
      m.cone([x, 0.8, z], [x * 1.12, 0.3, z * 1.05], 0.2, 0.12, { caps: false });
      m.sphere([x * 1.14, 0.2, z * 1.06], 0.2);
    }
    m.tube([[0, 0, -3.45], [0, 3.9, -3.45], [0, 4.35, -3.25], [0, 4.3, -2.85], [0, 3.95, -2.75]], 0.07, { line: true });
    m.line([[-0.3, 3.3, -3.45], [0.3, 3.3, -3.45]]);
  },

  // 교실 칠판: 테두리 + 칠판 면(3쪽 미닫이 이음) + 분필 받침(분필·지우개) + 분필 낙서(바를 정자 세기) + 경사 교탁
  'Home.Blackboard': (m) => {
    const z = -3.6;
    front(m, rect(-6.3, 3.45, 6.3, 8.55), z + 0.05, 0.12, { caps: 'front', sides: false });
    m.box([0, 6, z], [12, 4.5, 0.25], { lines: 'none' });
    m.line(rect(-6.0, 3.75, 6.0, 8.25).map(([x, y]) => [x, y, z + 0.13]), { closed: true });
    for (const x of [-2.0, 2.0]) m.line([[x, 3.75, z + 0.13], [x, 8.25, z + 0.13]]);
    m.box([0, 3.6, z + 0.35], [12, 0.15, 0.5], { lines: 'top' });
    m.line([[-3.6, 3.71, z + 0.3], [-3.25, 3.71, z + 0.38]]); m.line([[-2.9, 3.71, z + 0.28], [-2.7, 3.71, z + 0.4]]);
    m.box([3.4, 3.78, z + 0.35], [0.8, 0.2, 0.32], { lines: 'top' });
    // 낙서: 세로 넷 + 사선 하나 묶음 셋, 아래 밑줄
    for (let g = 0; g < 3; g++) {
      const x0 = -5.2 + g * 1.3;
      for (let k = 0; k < 4; k++) m.line([[x0 + k * 0.22, 6.6, z + 0.13], [x0 + k * 0.22 + 0.04, 7.6, z + 0.13]]);
      m.line([[x0 - 0.15, 6.75, z + 0.13], [x0 + 0.85, 7.45, z + 0.13]]);
    }
    m.line([[0.6, 7.4, z + 0.13], [1.6, 7.6, z + 0.13], [2.4, 7.1, z + 0.13], [3.3, 7.5, z + 0.13], [4.4, 7.2, z + 0.13]]);
    m.line([[0.8, 6.2, z + 0.13], [4.6, 6.0, z + 0.13]]);
    // 교탁: 학생 쪽(+z)이 조금 높은 경사 상판, 앞판 안쪽 홈, 아래 걸레받이
    side(m, [[-1.4, 0], [0.6, 0], [0.6, 3.6], [-1.4, 3.25]], 0, 4.0);
    m.line(rect(-1.6, 0.6, 1.6, 2.9).map(([x, y]) => [x, y, 0.61]), { closed: true });
    m.line([[-2.0, 0.3, 0.61], [2.0, 0.3, 0.61]]);
  },

  // 풍금(발 페달 오르간): 아래 몸통(무릎판 홈·페달 둘) + 튀어나온 건반(흰 건반 칸·검은 건반) + 건반 양끝 볼 + 음전 손잡이 줄
  // + 위 장식판(둥근 머리·타원 창·악보 받침) + 의자
  'Home.Organ': (m) => {
    const z0 = -2.6; // 몸통 가운데
    m.box([0, 1.45, z0], [5, 2.9, 1.8]);
    m.box([0, 3.35, z0 - 0.15], [5, 0.9, 1.5], { lines: 'XZ' });
    // 무릎판 홈 + 페달(기울어진 발판)
    m.line(rect(-1.9, 0.9, 1.9, 2.5).map(([x, y]) => [x, y, z0 + 0.91]), { closed: true });
    for (const x of [-0.8, 0.8]) m.with(T(x, 0.3, z0 + 1.2).mul(Rx(-0.3)), () => m.box([0, 0, 0], [1.0, 0.15, 1.3], { lines: 'top' }));
    // 건반
    const kz0 = z0 + 0.9, kz1 = z0 + 1.65, ky = 3.2;
    m.box([0, 3.05, (kz0 + kz1) / 2], [4.6, 0.3, kz1 - kz0], { lines: 'none' });
    m.line([[-2.3, ky, kz1], [2.3, ky, kz1]]); m.line([[-2.3, ky - 0.3, kz1], [2.3, ky - 0.3, kz1]]);
    for (let k = -9; k <= 9; k++) m.line([[k * 0.24, ky + 0.01, kz0 + 0.02], [k * 0.24, ky + 0.01, kz1]]);
    const blackAt = [1, 2, 4, 5, 6, 8, 9, 11, 12, 13, 15, 16];
    for (const b of blackAt) { const x = -2.16 + (b - 0.5) * 0.24 + 0.12; if (Math.abs(x) < 2.15) m.box([x, ky + 0.05, kz0 + 0.25], [0.12, 0.1, 0.42], { lines: 'none' }); }
    for (const b of blackAt) { const x = -2.16 + (b - 0.5) * 0.24 + 0.12; if (Math.abs(x) < 2.15) m.line([[x, ky + 0.11, kz0 + 0.06], [x, ky + 0.11, kz0 + 0.44]]); }
    m.mirrorX(() => m.box([2.42, 3.25, (kz0 + kz1) / 2], [0.16, 0.5, kz1 - kz0], { lines: 'all' }));
    for (let k = 0; k < 8; k++) { const x = -1.75 + k * 0.5; m.line([[x, 3.62, z0 + 0.6], [x, 3.62, z0 + 0.82]]); }
    // 위 장식판(둥근 머리) + 타원 창 + 악보 받침
    const head = [[-2.2, 3.8], [2.2, 3.8], [2.2, 4.9], ...arc2(0, 4.6, 2.2, 0.15, Math.PI - 0.15, 8).slice(1, -1).map(([x, y]) => [x, Math.min(y, 5.45)]), [-2.2, 4.9]];
    front(m, head, z0 - 0.3, 0.2, { caps: 'front', sides: false });
    m.line(circle2(1, 12).map(([a, b]) => [a * 0.9, 4.75 + b * 0.38, z0 - 0.19]), { closed: true });
    m.line([[-2.0, 4.05, z0 - 0.05], [2.0, 4.05, z0 - 0.05]]);
    // 의자(피아노 의자)
    m.box([0, 1.2, 0.4], [2.6, 0.3, 1.2]);
    for (const x of [-1.1, 1.1]) for (const z of [-0.05, 0.85]) m.cyl([x, 0, z], [x, 1.05, z], 0.07, { line: true });
  },

  // 아기 침대(나무 기둥 넷 · 위아래 가로대 · 세로 살 · 둥근 머리판/발판 · 매트리스) + 천장에서 내려온 모빌(살 셋 · 줄 · 별·달·구름)
  'Home.CribMobile': (m) => {
    const W = 1.3, L = 2.2;
    for (const x of [-W, W]) for (const z of [-L, L]) m.cyl([x, 0, z], [x, 3.4, z], 0.1, { line: true });
    for (const x of [-W, W]) {
      m.line([[x, 3.0, -L], [x, 3.0, L]]); m.line([[x, 1.15, -L], [x, 1.15, L]]);
      for (let k = -3; k <= 3; k++) m.line([[x, 1.15, k * 0.55], [x, 3.0, k * 0.55]]);
    }
    for (const [z, h] of [[-L, 3.3], [L, 3.0]]) front(m, [[-W, 1.0], [W, 1.0], [W, h - 0.3], ...arc2(0, h - 1.6, Math.hypot(W, 1.3), Math.atan2(1.3, W), Math.PI - Math.atan2(1.3, W), 6).slice(1, -1), [-W, h - 0.3]], z, 0.1, { caps: 'front', sides: false });
    m.box([0, 1.0, 0], [2.5, 0.3, 4.3], { lines: 'none' });
    m.cushion([0, 1.35, 0], [2.4, 0.4, 4.2], 0.12, { lines: 'top' });
    // 모빌
    const hy = 8.6;
    m.line([[0, 13.6, 0], [0, hy, 0]]);
    const shapes = [star(0.55), moon(0.55), cloud(0.65)];
    for (let k = 0; k < 6; k++) {
      const a = k * Math.PI / 3, tx = Math.cos(a) * 2.2, tz = Math.sin(a) * 2.2;
      if (k < 3) m.line([[tx, hy - 0.15, tz], [0, hy, 0], [-tx, hy - 0.15, -tz]]);
      const drop = k % 2 ? 1.6 : 1.3;
      m.line([[tx, hy - 0.15, tz], [tx, hy - drop, tz]]);
      m.with(T(tx, hy - drop - 0.45, tz).mul(Ry(-a + 0.4)), () => front(m, shapes[k % 3], 0, 0.06, { caps: 'front', sides: false }));
    }
  },

  // 천장 가까이 가로지른 봉(3칸, y 12.2) + 천장 고정대 셋(나사 막대 · 봉 감는 고리) + 남은 S 고리
  'Home.HangBar': (m) => {
    m.cyl([0, 12.2, -12], [0, 12.2, 12], 0.25);
    for (const z of [-11.6, 0, 11.6]) {
      m.line([[0, 12.45, z], [0, 14, z]]);
      m.slab(0, 13.95, z, 0.6, 0.05, 0.6, { lines: 'none' });
      m.line(circle2(0.33, 8).map(([x, y]) => [x, 12.2 + y, z]), { closed: true });
    }
    for (const z of [-7.2, -3.1, 4.4, 8.3]) m.line([[0, 12.45, z], [0, 12.0, z + 0.15], [0, 11.75, z], [0, 11.5, z + 0.15]]);
  },
};
