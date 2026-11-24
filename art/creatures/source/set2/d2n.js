// 시안2 2장 비인간형 — 다섯 손가락: 거대한 손 하나. 손가락 하나하나가 사람의 상반신이고, 손톱 자리에 얼굴이 있다. 손가락으로 걷는 손처럼 기어 온다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'd2n', name: '다섯 손가락', kind: '비인간형 · 2장 물류 창고', H: 6.4, build(p = {}) {
  const B = new Body(), w = p.walk, ph = w == null ? .1 : w;
  // 손등: 살덩이 + 힘줄
  B.group({ k: .4, kg: .3, amp: .015, freq: 2 }); B.ell(new Frame([0, 4.35, -.9], [1, 0, 0], V.norm([0, 1, .12]), V.norm([0, -.12, 1])), [1.75, .72, 1.6]); B.ell(new Frame([0, 4.3, -2.3], [1, 0, 0], [0, 1, 0], [0, 0, 1]), [1.1, .7, 1.0]);
  for (let i = 0; i < 8; i++) B.groove([-.9 + i * .26, 4.9, -1.1 + .5 * Math.sin(i * 2.1)], [Math.sin(i * 3), .2, Math.cos(i * 2.3)], .022, .04, .7, { bow: .3, wob: .4, wf: 2 });
  // 손목: 잘린 자리 — 뒤엉킨 다리들
  for (let i = 0; i < 6; i++) { const a = i / 6 * 6.283 + .3, c = [Math.cos(a) * .55, 4.25 + Math.sin(a) * .38, -2.9]; A.leg(B, c, V.add(c, [Math.cos(a) * .55, Math.sin(a) * .5 - .1, -1.0]), V.add(c, [Math.cos(a) * .5 + .2 * Math.sin(i), Math.sin(a) * .25 - 1.1, -1.7]), .2, { m: .85, front: [Math.cos(a), Math.sin(a), -.5] }); A.foot(B, new Frame(V.add(c, [Math.cos(a) * .5 + .2 * Math.sin(i), Math.sin(a) * .25 - 1.1, -1.7]), [1, 0, 0], V.norm([0, 1, .4]), V.norm([Math.cos(a) * .3, -.6, -.8])), .7, {}); }
  // 손가락 다섯 = 사람 다섯
  const fin = [[-1.55, -.1, -38, 1.0], [-.75, .5, -14, 1.12], [.1, .65, 2, 1.18], [.95, .45, 18, 1.1], [1.75, -1.1, 66, .95]];
  fin.forEach(([x, z, yaw, s], i) => {
    const q = Math.sin((ph + i * .21) * 6.283), lf = Math.max(0, q) * .55, R = Math.PI / 180, d = [Math.sin(yaw * R), 0, Math.cos(yaw * R)], side = [d[2], 0, -d[0]], b = [x, 4.35, z]; const P = (f, y, sd = 0) => [b[0] + d[0] * f * s + side[0] * sd, y, b[2] + d[2] * f * s + side[2] * sd];
    // 첫 마디(허리~가슴): 위로 솟았다가 / 둘째(팔을 앞으로 모은 상반신)가 꺾여 바닥으로
    const kn = P(1.5, 5.3 + lf * .5), ti = P(2.5 + q * .18, 2.15 + lf);
    B.group({ k: .2, kg: .35, amp: .008, freq: 4 }); B.tube([P(-.4, 4.3), P(.5, 4.85), kn], [.6, .5, .5]); A.rings(B, [P(.3, 4.7), P(1.2, 5.2)], 4, .025, .045, .9, { bow: .25 });
    const dn = V.norm(V.sub(ti, kn)), fr = V.norm(V.add(d, [0, .35, 0])); const TF0 = V.lerp(kn, ti, .38), X = V.norm(V.cross(dn, fr)), Zv = V.norm(V.cross(X, dn)); A.torso(B, new Frame(TF0, X, dn, Zv), { w: .58 * s, d: .42 * s, h: 1.5 * s, n: 7, r: .042, scap: true });
    B.group({ k: .18, kg: .3 }); B.ell(new Frame(kn, X, dn, Zv), [.52, .46, .5]); for (const m of [-1, 1]) B.groove(V.add(kn, V.mul(Zv, .3)), V.add(dn, V.mul(Zv, m * .5)), .03, .06, .6, { bow: .4, wob: .2, wf: 3 });
    // 팔: 손끝처럼 앞바닥을 짚음
    for (const m of [-1, 1]) { const sh = V.add(V.lerp(kn, ti, .62), V.mul(X, m * .62 * s)), gr = P(2.85 + q * .25, .34 + lf * .9, m * .55 * s), el = V.add(V.lerp(sh, gr, .48), V.add(V.mul(X, m * .42), V.mul(d, .25))); A.arm(B, sh, el, gr, .17 * s, { m: .85 }); A.hand(B, new Frame(gr, V.norm(V.mul(X, -m)), V.norm(V.add(d, [0, -.2, 0])), [0, 1, 0]), .95 * s, { curl: 12, spread: 13, thin: .85 }); }
    // 손톱 자리의 얼굴: 앞을 봄
    const hc = V.add(ti, V.add(V.mul(d, .32), [0, -.12, 0])); A.neck(B, V.lerp(kn, ti, .78), V.lerp(ti, hc, .4), .18 * s, { front: d }); const HF = new Frame(hc, side, V.norm([d[0] * -.1, 1, d[2] * -.1]), V.norm(V.add(d, [0, .05, 0]))); A.head(B, new Frame(hc, V.mul(side, 1), HF.y, HF.z).rot(0, 0, (i - 2) * 7), 1.08 * s, { jaw: [8, 34, 22, 40, 14][i], gaunt: 1.15, eyes: i === 2 ? 'pin' : i === 4 ? 'skin' : 'hollow', pin: .016, eyeSize: 1.1, nose: 'human', teeth: 8, ears: i % 2 === 0 });
  });
  // 손등의 송장 꼬리표(붉은)
  B.group({ mat: 1, k: .01 }); B.box(new Frame([.35, 5.02, -1.2], V.norm([1, .05, .2]), V.norm([-.2, .15, 1]), V.norm([0, 1, -.1])), [.36, .24, .02], .015);
  return B;
} };
