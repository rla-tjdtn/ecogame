// 시안2 1장 비인간형 — 양두: 허리에서 맞붙은 두 상반신. 다리가 없고 팔 넷으로 양쪽 어디로든 걷는다. 한쪽 머리가 자면 다른 쪽이 깬다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'd1n', name: '양두', kind: '비인간형 · 1장 지하 시설', H: 4.6, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .3 : Math.sin(w * Math.PI * 2), up = p.up ?? 0;
  for (const f of [1, -1]) { // f: 앞(+z) / 뒤(−z) 상반신
    const Z = v => [v[0] * f, v[1], v[2] * f], lf = f > 0 ? up : 0;
    A.torso(B, new Frame(Z([0, 3.0 + lf * .7, 1.55]), [f, 0, 0], V.norm(Z([0, -.28 + lf * .8, 1])), V.norm(Z([0, -1, -.28]))), { w: .8, d: .5, h: 1.8, n: 8, r: .052, scap: true });
    B.group({ k: .2, kg: .3, amp: .008, freq: 4 }); B.tube([Z([0, 3.2 + lf * .3, .95]), Z([0, 3.35, .45]), [0, 3.4, 0]], [.56, .42, .36]);
    A.spine(B, [[0, 3.4, 0], Z([0, 3.3 + lf * .3, 1.0]), Z([0, 2.95 + lf * .9, 2.2])], .12, { n: 9, back: [0, 1, 0], out: .4, wing: true, k: .03 });
    for (const m of [-1, 1]) { const t = m * f * S, s = Z([m * .92, 2.85 + lf * .9, 2.15]), e = Z([m * 1.55, 1.75 + Math.max(0, t) * .3 + lf * 1.0, 1.75 + t * .35]), wr = Z([m * 1.3, .4 + Math.max(0, t) * .4 + lf * 1.6, 2.55 + t * .75 + lf * .6]); A.arm(B, s, e, wr, .32, { m: 1.0 }); A.hand(B, new Frame(wr, V.norm(Z([-m, 0, .15])), V.norm(Z([m * .15, -.15, .97])), V.norm([0, 1, .1 * f])), 1.5, { curl: lf ? 30 : 11, spread: 13, thin: .95 }); }
    const n0 = Z([0, 2.75 + lf * 1.0, 2.5]), hc = Z([0, 2.55 + lf * 1.3 - (f < 0 ? .75 : 0), 3.35 - (f < 0 ? .1 : 0)]); A.neck(B, n0, V.lerp(n0, hc, .7), .28, { front: Z([0, -1, .2]) });
    const HF = new Frame(hc, [f, 0, 0], V.norm(Z([0, f < 0 ? .55 : .95, f < 0 ? .8 : -.2])), V.norm(Z([0, f < 0 ? -.8 : .2, f < 0 ? .55 : .95]))).rot(0, p.headYaw || 0, f > 0 ? -10 : 18); A.head(B, HF, 1.3, f > 0 ? { jaw: p.jaw ?? 30, gaunt: 1.2, eyes: 'pin', eyeSize: 1.15, pin: .015, nose: 'human', teeth: 11, mouthW: 1.1 } : { jaw: 2, gaunt: 1.1, eyes: 'skin', nose: 'human' });
    if (f < 0) { const R = []; for (let i = 0; i < 34; i++) { const a = i / 34 * Math.PI * 1.5 + .75 * Math.PI, x = Math.cos(a) * .33, z = Math.sin(a) * .4 - .06, j = Math.sin(i * 5.3); R.push([HF.p([x * .4, .45, z * .5]), HF.p([x * 1.02, .28, z * 1.02]), V.add(HF.p([x * 1.1, -.05, z * 1.1]), [0, -.25, 0]), V.add(HF.p([x * 1.1 + j * .06, -.2, z * 1.1]), [0, -.8 - .3 * Math.abs(j), 0])]); } A.hair(B, R, { r: [.045, .034, .024, .006] }); }
  }
  // 이음: 비틀린 허리 살 + 큰 바늘땀(붉은 솔기)
  B.group({ k: .06, kg: .2, amp: .004, freq: 5 }); for (let i = 0; i < 8; i++) { const a0 = i / 8 * 6.283, pts = [], rs = []; for (let j = 0; j <= 6; j++) { const t = j / 6, a = a0 + (t - .5) * 2.2, r = .34 + Math.pow(Math.abs(t * 2 - 1), 1.6) * .2; pts.push([Math.cos(a) * r, 3.38 + Math.sin(a) * r * .9, (t - .5) * 1.7]); rs.push(.11 + Math.abs(t - .5) * .14); } B.tube(pts, rs, { per: 2 }); }
  B.group({ mat: 1, k: .01 }); { const pts = []; for (let i = 0; i <= 12; i++) { const a = -2.2 + i / 12 * 4.4; pts.push([Math.sin(a) * .5, 3.4 + Math.cos(a) * .47, Math.sin(i * 1.7) * .05]); } B.tube(pts, .035, { per: 2 }); }
  B.group({ k: .012 }); for (let i = 0; i < 11; i++) { const a = -2.1 + i / 10 * 4.2, q = [Math.sin(a) * .5, 3.4 + Math.cos(a) * .47, 0], n = [Math.sin(a) * .1, Math.cos(a) * .1, 0]; B.tube([V.add(q, [0, 0, -.24]), V.add(V.add(q, n), [0, 0, 0]), V.add(q, [0, 0, .24])], .03, { per: 3 }); }
  return B;
} };
