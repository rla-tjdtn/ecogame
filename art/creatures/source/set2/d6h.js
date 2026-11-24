// 시안2 6장 인간형 — 반쪽: 세로로 갈라진 한 사람의 두 반쪽이 한 뼘 떨어진 채 나란히 걷는다. 사이를 끈적한 실이 잇고, 벌어졌다 붙을 때마다 소리가 난다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'd6h', name: '반쪽', kind: '인간형 · 6장 호텔', H: 9.6, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .4 : Math.sin(w * Math.PI * 2), gp = p.gap ?? .62, lag = p.lag ?? .35;
  for (const m of [-1, 1]) {
    const gx = m * gp, dz = m * lag * .5, dy = m * .12, st = m * S; const H0 = new Body(); const X = v => [v[0] + gx, v[1] + dy, v[2] + dz];
    // 반쪽 몸(안쪽 x=0 면을 잘라냄): 조각들을 임시 바디에 쌓고 자르는 상자를 각 그룹에 추가
    const T = new Body(); const h = [m * .42, 4.15, 0], k = [m * .48, 2.3, .25 + st * .55], an = [m * .44, .34 - dy + Math.max(0, -st) * .2, -.12 + st * .95]; A.leg(T, h, k, an, .34, { m: .85, front: [m * .1, 0, 1] }); A.foot(T, new Frame(an, [1, 0, 0], [0, 1, 0], V.norm([m * .2, 0, 1])), 1.15, {});
    A.pelvis(T, new Frame([0, 4.3, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]), { w: .58, d: .38 }); T.group({ k: .18, kg: .25, amp: .006, freq: 4 }); T.tube([[0, 4.35, 0], [0, 5.1, .08], [0, 5.9, 0]], [.46, .38, .48]); A.rings(T, [[0, 4.5, .1], [0, 5.6, .1]], 5, .024, .04, .9, { bow: .3 });
    A.torso(T, new Frame([0, 6.4, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]), { w: .78, d: .48, h: 1.55, n: 8, r: .052 }); A.neck(T, [0, 7.1, 0], [0, 7.85, .1], .24, { adam: false }); const HF = new Frame([0, 8.4, .15], [1, 0, 0], [0, 1, 0], [0, 0, 1]).rot(m > 0 ? 4 : -3, 0, 0); A.head(T, HF, 1.45, { jaw: m > 0 ? 30 : 16, gaunt: 1.25, eyes: 'pin', pin: .015, eyeSize: 1.15, eyeH: .075, nose: 'human', teeth: 10, kg: .12 });
    const s = [m * .92, 6.98, 0], e = [m * 1.25, 5.35, .1 - st * .2], wr = [m * 1.1, 3.85, .5 - st * .5]; A.arm(T, s, e, wr, .23, { m: .9 }); A.hand(T, new Frame(wr, V.norm([0, 0, 1]), V.norm([0, -1, .1]), V.norm([m, .1, 0])), 1.45, { curl: [14, 20, 18, 26], spread: 9, thin: .82, len: 1.15 });
    for (const g of T.groups) { for (const q of g.prims) { q.a = X(q.a); if (q.t === 0) q.b = X(q.b); } let mn = 1e9; for (const q of g.prims) if (!q.op) mn = Math.min(mn, (q.t === 0 ? Math.min(m * (q.a[0] - gx) - q.ra, m * (q.b[0] - gx) - q.rb) : m * (q.a[0] - gx) - Math.max(...q.b))); if (mn < 0) g.prims.push({ t: 2, op: 1, k: .03, a: [gx - m * 3, 5 + dy, dz], b: [3, 8, 4], q: [0, 0, 0, 1], ra: .02, rb: 0 }); B.groups.push(g); }
    // 단면: 어둠 + 척추 반 + 내장 줄 + 갈비 단면
    const cx = gx + m * .015; B.group({ mat: 2, k: .02 }); B.ell(new Frame([cx + m * .06, 6.3 + dy, dz], [1, 0, 0], [0, 1, 0], [0, 0, 1]), [.05, .62, .3]); B.ell(new Frame([cx + m * .06, 5.0 + dy, dz + .05], [1, 0, 0], [0, 1, 0], [0, 0, 1]), [.05, .5, .26]);
    B.group({ k: .03, kg: .03 }); for (let i = 0; i < 17; i++) { const y = 4.5 + i * .2; B.ell(new Frame([cx, y + dy, dz - .2 - (y > 5 && y < 6 ? .0 : .12)], [1, 0, 0], [0, 1, 0], [0, 0, 1]), [.09, .075, .11]); }
    for (let i = 0; i < 6; i++) B.ell(new Frame([cx, 5.8 + i * .2 + dy, dz + .4], [1, 0, 0], [0, 1, 0], [0, 0, 1]), [.06, .05, .06]);
    B.group({ k: .05, kg: .04 }); const gut = []; for (let i = 0; i <= 12; i++) gut.push([cx - m * .03, 4.55 + i * .07 + dy, dz + .05 + Math.sin(i * 1.5) * .2]); B.tube(gut, [.07, .085, .075, .085, .07], { per: 2 });
    // 머리 단면: 두개 속 + 이빨 줄
    B.group({ mat: 2, k: .02 }); B.ell(new Frame([cx + m * .05, 8.65 + dy, dz + .08], [1, 0, 0], [0, 1, 0], [0, 0, 1]), [.05, .34, .44]); B.ell(new Frame([cx + m * .05, 8.05 + dy, dz + .3], [1, 0, 0], [0, 1, 0], [0, 0, 1]), [.05, .12, .26]); B.group({ k: .02 }); B.tube([[cx, 8.75 + dy, dz - .2], [cx, 8.9 + dy, dz + .05], [cx, 8.7 + dy, dz + .3], [cx, 8.55 + dy, dz + .1], [cx, 8.68 + dy, dz - .1]], .06, { per: 3 });
  }
  // 사이의 실(몇 가닥은 붉다 → 하나만)
  for (let i = 0; i < 22; i++) { const y = 2.9 + i * .28, j = Math.sin(i * 4.7), j2 = Math.cos(i * 2.9); if (y < 4.1 || (i % 3 === 1 && y < 7)) continue; const a = [-gp, y - .12, -lag * .5 + j * .28], b = [gp, y + .12, lag * .5 + j2 * .28]; B.group({ k: .04, kg: .05, mat: i === 12 ? 1 : 0 }); B.tube([a, V.add(V.lerp(a, b, .25), [0, -.1, 0]), V.add(V.lerp(a, b, .5), [0, -.16 - .12 * Math.abs(j), 0]), V.add(V.lerp(a, b, .75), [0, -.1, 0]), b], [.09, .03, .018, .03, .09]); }
  return B;
} };
