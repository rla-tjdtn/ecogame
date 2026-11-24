// 시안3 1장 비인간형 — 나무: 거꾸로 심긴 사람. 잘린 목에서 팔이 뿌리처럼 퍼져 손가락으로 걷고, 다리는 가지가 되어 갈라져 자란다. 배꼽이 있던 자리에 얼굴이 있다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'e1n', name: '나무', kind: '비인간형 · 1장 지하 시설', H: 11.5, build(p = {}) {
  const B = new Body(), w = p.walk ?? .1, sw = p.sway ?? 0, X = y => sw * (y / 10) ** 2 * 1.6;
  // 줄기 = 거꾸로 선 몸통(가슴 아래, 골반 위). 살이 나무껍질처럼 비틀림
  B.group({ k: .2, kg: .3, amp: .02, freq: 2.5, rid: .01, rf: 1.6 }); B.tube([[0, 2.6, 0], [X(3.6), 3.6, .05], [X(4.8), 4.8, 0], [X(6), 6.0, -.05], [X(6.8), 6.8, 0]], [.62, .78, .6, .56, .72]);
  for (let i = 0; i < 9; i++) { const a0 = i / 9 * 6.283, pts = [], rs = []; for (let j = 0; j <= 7; j++) { const t = j / 7, a = a0 + t * 1.7, r = .5 + .22 * Math.sin(t * 3.1) - .08 * Math.sin(t * 6.2); pts.push([X(2.4 + t * 4.4) + Math.cos(a) * r, 2.4 + t * 4.4, Math.sin(a) * r * .85]); rs.push(.1 + .07 * Math.sin(t * 5 + i)); } B.tube(pts, rs, { per: 2, k: .09 }); }
  A.ribs(B, new Frame([X(3.6), 3.55, 0], [1, 0, 0], [0, -1, 0], [0, 0, 1]), { w: .85, d: .68, h: 1.5, n: 7, r: .055 });
  // 뿌리 = 팔 아홉
  const N = 9; for (let i = 0; i < N; i++) { const a = i / N * 6.283 + .35, c = Math.cos(a), s = Math.sin(a), q = Math.sin((w + i * .31) * 6.283), lf = Math.max(0, q) * .45, R = 2.1 + .6 * Math.abs(Math.sin(i * 2.3)); const sh = [c * .5, 2.35, s * .45], e = [c * R * .55 - s * .3 * Math.sin(i), 1.55 + lf * .6 + .3 * Math.sin(i * 1.9), s * R * .55 + c * .3 * Math.sin(i)], wr = [c * R - s * q * .25, .3 + lf, s * R + c * q * .25]; A.arm(B, sh, e, wr, .24 + .05 * Math.sin(i * 3), { m: .95 }); A.hand(B, new Frame(wr, V.norm([-s, 0, c]), V.norm([c, -.16, s]), [0, 1, 0]), 1.35, { curl: 14, spread: 18, thin: .85, len: 1.3 }); }
  // 잘린 목 밑: 혀처럼 늘어진 식도
  B.group({ mat: 1, k: .04 }); B.tube([[0, 2.2, .3], [.1, 1.7, .55], [-.05, 1.2, .5], [.08, .75, .62]], [.16, .15, .11, .03]);
  // 배의 얼굴: 정면으로 크게(줄기에서 배어 나옴)
  const HF = new Frame([X(5.2), 5.15, .42], [1, 0, 0], V.norm([0, 1, -.06]), V.norm([0, .06, 1])).rot(0, p.headYaw || 0, -6); A.face(B, HF, 1.75, { jaw: p.jaw ?? 30, eyes: 'real', ears: false, gaunt: .9, teeth: 12, kg: .4, w: 1.05, iris: .014 });
  A.face(B, new Frame([X(4.2) - .5, 4.3, .5], V.norm([.9, 0, .45]), [0, 1, 0], V.norm([-.45, 0, .9])).rot(0, 0, 28), .85, { jaw: 12, eyes: 'shut', ears: false, kg: .3, rid: 0, gaunt: .4 }); A.face(B, new Frame([X(6.1) + .5, 6.1, .35], V.norm([.85, 0, -.5]), [0, 1, 0], V.norm([.5, 0, .85])).rot(0, 0, -20), .8, { jaw: 22, eyes: 'empty', ears: false, kg: .3, rid: 0 });
  // 가지 = 다리: 허벅지 둘 → 무릎에서 둘씩 갈라짐 → 발
  const limb = (h, dir, L, r, depth, seed) => { const k = V.add(h, V.mul(dir, L)); const splits = depth > 0 ? 2 : 0; if (!splits) { const an = k; A.foot(B, Frame.along(an, V.mul(dir, -1), V.norm([dir[0] * .3 + .2 * Math.sin(seed), .1, 1])), .85, { toe: 1.4 }); return; } const spread = .62; for (const m of [-1, 1]) { const ax = V.norm(V.cross(dir, [Math.sin(seed * 2.1), .1, Math.cos(seed * 1.3)])); const d2 = V.norm(V.add(V.add(dir, V.mul(ax, m * spread)), [0, .25, .12 * Math.sin(seed + m)])); const L2 = L * (.82 + .1 * Math.sin(seed * 3 + m)), k2 = V.add(k, V.mul(d2, L2)); A.leg(B, V.lerp(h, k, .02), k, k2, r, { m: .9, front: V.norm(V.add(ax, [0, 0, .6])) }); limb(k, d2, L2, r * .72, depth - 1, seed * 1.7 + m); } };
  for (const m of [-1, 1]) { const h = [X(7) + m * .4, 6.9, 0], d = V.norm([m * .55 + sw * .3, 1, .12 * m]); limb(h, d, 1.75, .36, 2, 1.3 + m * .7); }
  B.group({ k: .25, kg: .3 }); B.ell(new Frame([X(6.95), 6.95, -.05], [1, 0, 0], [0, 1, 0], [0, 0, 1]), [.75, .42, .5]);
  return B;
} };
