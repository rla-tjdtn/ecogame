// 시안2 3장 비인간형 — 쥐왕: 등뼈가 꼬리처럼 길게 빠져 한 매듭으로 얽힌 다섯 사람. 서로 다른 쪽으로 기려다 원을 그리며 돈다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'd3n', name: '쥐왕', kind: '비인간형 · 3장 하수도', H: 3.2, build(p = {}) {
  const B = new Body(), sp = (p.spin || 0) * 6.283, w = p.walk ?? .12;
  const N = 5; for (let i = 0; i < N; i++) {
    const a = i / N * 6.283 + sp + .63, c = Math.cos(a), s = Math.sin(a), d = [c, 0, s], sd = [-s, 0, c], k = [0, 1.75, 0], q = Math.sin((w + i * .23) * 6.283), up = i === 1 ? (p.rear || 0) : 0; const P = (f, y, t = 0) => [d[0] * f + sd[0] * t, y, d[2] * f + sd[2] * t];
    // 몸통: 낮게 기는 상반신
    const ty = 1.35 + up * .9; A.torso(B, new Frame(P(3.1, ty), sd, V.norm([d[0], .08 + up * .7, d[2]]), [0, -1, 0]), { w: .56, d: .4, h: 1.4, n: 7, r: .042, scap: true });
    B.group({ k: .16, kg: .22, amp: .006, freq: 5 }); B.tube([P(2.5, ty), P(2.0, 1.35), P(1.55, 1.5)], [.4, .28, .18]); A.rings(B, [P(2.6, ty), P(1.8, 1.4)], 5, .022, .04, .6);
    // 꼬리뼈가 길게 빠져 매듭으로
    const tl = [P(1.7, 1.45), P(1.2, 1.75, .2), P(.75, 2.1 + .15 * Math.sin(i * 2), -.18), [c * .25, 2.25 - .2 * Math.cos(i * 3), s * .25], [-c * .4 + .2 * s, 1.7, -s * .4], [-c * .55, 1.25 + .2 * (i % 2), -s * .5 + .2 * c], [c * .15, 1.45, s * .3]]; B.group({ k: .03, kg: .05 }); B.tube(tl, [.17, .15, .14, .13, .12, .1, .06]); A.spine(B, tl, .1, { n: 20, back: [0, 1, 0], out: .1, k: .02, kg: .02, wing: true });
    // 팔: 손톱으로 긁으며 당김
    for (const m of [-1, 1]) { const t = m * q, sh = P(3.5, ty - .05, m * .62), el = P(3.95 + t * .2, 1.15 + Math.max(0, t) * .3 + up * .8, m * 1.15), wr = P(4.65 + t * .45, .32 + Math.max(0, t) * .35 + up * 1.2, m * .85); A.arm(B, sh, el, wr, .2, { m: .9 }); A.hand(B, new Frame(wr, V.norm(V.mul(sd, -m)), V.norm([d[0], -.16, d[2]]), [0, 1, 0]), 1.15, { curl: 16, spread: 13, thin: .85, claw: .12 }); }
    // 머리: 쥐처럼 앞니가 길고 턱이 뾰족, 눈은 작음
    A.neck(B, P(3.75, ty - .02), P(4.05, ty + .02), .19, { front: [0, -1, 0] }); const HF = new Frame(P(4.35, ty + .08), [-sd[0], 0, -sd[2]], V.norm([-d[0] * .15, 1, -d[2] * .15]), V.norm([d[0], .12, d[2]])).rot(0, 0, (i - 2) * 9); const H = A.head(B, HF, 1.1, { jaw: [26, 40, 12, 32, 20][i], gaunt: 1.35, eyes: 'hollow', eyeSize: .85, eyeH: .05, nose: 'skull', teeth: 8, w: .86, elong: .95 });
    B.group({ mat: 4, k: .003 }); for (const m of [-1, 1]) B.tube([H.P([m * .028, -.25, .33]), H.P([m * .026, -.4, .37]), H.P([m * .022, -.5, .34])], [.032, .034, .012]);
    const R = []; for (let j = 0; j < 20; j++) { const u = j / 19 - .5, jj = Math.sin(j * 5.7 + i); R.push([HF.p([u * .4, .42, .05]), HF.p([u * .62, .38, -.3]), V.add(HF.p([u * .75, .1, -.6]), [0, -.1, 0]), V.add(HF.p([u * .8 + jj * .05, -.05, -.95 - .2 * Math.abs(jj)]), [0, -.25, 0])]); } A.hair(B, R, { r: [.03, .03, .022, .006] });
  }
  // 매듭: 뭉친 살 + 뼈 고리(붉은 힘줄 하나)
  B.group({ k: .16, kg: .12, amp: .02, freq: 3 }); B.ell(new Frame([0, 1.65, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]), [.6, .55, .6]); for (let i = 0; i < 9; i++) { const a = i * 2.4; B.tube([[Math.cos(a) * .5, 1.3 + .1 * i, Math.sin(a) * .5], [Math.cos(a + 1.2) * .75, 1.5 + .09 * i, Math.sin(a + 1.2) * .75], [Math.cos(a + 2.4) * .5, 1.4 + .1 * i, Math.sin(a + 2.4) * .5]], .12, { k: .08 }); }
  B.group({ mat: 1, k: .02 }); B.tube([[.5, 2.1, .3], [.1, 2.45, .25], [-.35, 2.3, .1], [-.55, 1.9, -.2]], [.03, .06, .06, .03]);
  return B;
} };
