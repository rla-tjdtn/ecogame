// 시안3 2장 비인간형 — 가위: 골반이 못 하나로 X자로 꿰인 두 몸. 붙은 두 다리는 거대한 날이 되어 그 끝으로 걷고, 머리 위로 맞잡은 팔은 손잡이 고리가 된다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'e2n', name: '가위', kind: '비인간형 · 2장 물류 창고', H: 9.4, build(p = {}) {
  const B = new Body(), w = p.walk, sw = w == null ? 0 : Math.sin(w * Math.PI * 2) * 12, ang = 12 + (p.open ?? .6) * 24, piv = [0, 4.1, 0];
  for (const m of [-1, 1]) {
    const C = new Frame(piv, [1, 0, 0], [0, 1, 0], [0, 0, 1]).rot(0, sw * m * .8, 0).rot(0, 0, m * -ang), z0 = m * .27, c = v => C.p([v[0], v[1], v[2] + z0]), D = v => V.norm(C.d(v));
    // 골반과 홀쭉한 허리, 갈비통
    A.pelvis(B, new Frame(c([0, .3, 0]), C.x, C.y, C.z), { w: .56, d: .3 }); B.group({ k: .16, kg: .25, amp: .008, freq: 4 }); B.tube([c([0, .4, 0]), c([0, 1.0, -.04]), c([0, 1.7, 0])], [.42, .3, .42]); A.rings(B, [c([0, .6, 0]), c([0, 1.5, 0])], 5, .025, .05, .7, { bow: .4 });
    A.torso(B, new Frame(c([0, 2.2, 0]), C.x, C.y, C.z), { w: .76, d: .46, h: 1.7, n: 8, r: .055, scap: true }); A.spine(B, [c([0, .4, -.3]), c([0, 1.2, -.3]), c([0, 2.6, -.42])], .11, { n: 10, back: D([0, 0, -1]), out: .05, wing: true, k: .03 });
    // 머리: 고리 안에서 이쪽을 봄. 세계 기준으로 거의 바로 서서 더 섬뜩함
    const hp = c([0, 3.75, .18]); A.neck(B, c([0, 2.9, -.02]), V.add(hp, C.d([0, -.5, -.1])), .24, {}); A.face(B, new Frame(hp, [1, 0, 0], [0, 1, 0], [0, 0, 1]).rot(6, (p.headYaw || 0) + m * 8, m * (p.tilt ?? 26)), 1.35, { jaw: m > 0 ? (p.jaw ?? 40) : 4, eyes: m > 0 ? 'real' : 'sewn', gaunt: 1.25, teeth: 11, iris: .012, elong: 1.02 });
    // 팔: 머리 위로 고리를 이루고 손을 맞잡음(가위 손잡이)
    const wr = {}; for (const s of [-1, 1]) { const sh = c([s * .86, 2.75, 0]), e = c([s * 1.62, 3.95, .05]); wr[s] = c([s * .5, 5.05, .1]); A.arm(B, sh, e, wr[s], .22, { m: .9 }); A.hand(B, new Frame(wr[s], D([0, s * .35, 1]), D([-s * .93, .2, 0]), D([s * .2, .95, -.3])), 1.15, { curl: [36, 42, 46, 50], spread: 6, thin: .86, len: 1.15 }); }
    // 허벅지 둘이 붙어 날이 됨
    B.group({ k: .14, kg: .25, amp: .006, freq: 4 }); for (const s of [-1, 1]) { B.tube([c([s * .38, .1, 0]), c([s * .32, -.5, .06]), c([s * .16, -1.25, .03])], [.38, .33, .22]); A.muscle; } B.groove(c([0, -.6, .15]), C.x, .025, .06, .75, { wob: .06, wf: 3 }); for (const s of [-1, 1]) for (let i = 0; i < 2; i++) B.groove(c([s * .34, -.3 - i * .4, .2]), D([1, .25 * s, 0]), .02, .04, .4, { wob: .1 });
    const L0 = -.85, L1 = -4.75, N = 22; B.group({ k: .015, kg: .04 }); for (let i = 0; i < N; i++) { const t = i / (N - 1), y = L0 + (L1 - L0) * t, inn = m * (.05 - t * .12), wd = .62 * (1 - t * t * .92) * (t < .12 ? .55 + t * 3.7 : 1); B.ell(new Frame(c([inn + m * wd * .25, y, 0]), C.x, C.y, C.z), [wd * .72, (L0 - L1) / N * 1.25, .13 * (1 - t * .5)], { k: .1 }); }
    // 날 등의 정강이뼈 + 이 빠진 날 + 녹 흠집
    B.group({ k: .03, kg: .05 }); B.tube([c([m * .52, -1.0, .02]), c([m * .58, -2.0, .03]), c([m * .4, -3.3, .02]), c([m * .05, -4.6, 0])], [.12, .1, .075, .02]); B.ball(c([m * .5, -1.0, .08]), .2, { k: .1 }); for (let i = 0; i < 11; i++) { const t = .18 + i * .07, y = L0 + (L1 - L0) * t, wd = .62 * (1 - t * t * .92); B.ball(c([-m * (wd * .5 + .06 + .03 * Math.sin(i * 3)), y, 0]), .07 + .04 * Math.abs(Math.sin(i * 2.7)), { op: 1, k: .02 }); } for (let i = 0; i < 7; i++) B.groove(c([m * .1, -1.7 - i * .34, .1]), D([.3 + .2 * Math.sin(i * 3), 1, 0]), .012, .025, .22 + .1 * Math.sin(i * 2), { wob: .1, wf: 6 });
    // 살이 날로 찢어지는 경계의 힘줄
    B.group({ k: .06, kg: .1, amp: .01, freq: 6 }); for (let i = 0; i < 8; i++) { const u = (i / 7 - .5) * 1.1; for (const z of [.16, -.16]) B.tube([c([u * .9, -.7, z]), c([u * .75 + m * .08, -1.2, z * .9]), c([u * .6 + m * .1, -1.6 - .5 * Math.abs(Math.sin(i * 2.7)), z * .5])], [.1, .075, .015]); }
  }
  // 두 골반을 꿰뚫은 못과 꿰맨 실밥
  B.group({ k: .02 }); B.cone([piv[0], piv[1] + .1, -1.0], [piv[0], piv[1] + .1, 1.0], .16, .16); for (const z of [1.0, -1.0]) B.ell(new Frame([0, piv[1] + .1, z], [1, 0, 0], [0, 1, 0], [0, 0, 1]), [.42, .42, .13]); B.groove([0, piv[1] + .1, 1.12], V.norm([.5, 1, 0]), .05, .07, .5, { wob: 0 }); B.group({ k: .03, kg: .06 }); for (let i = 0; i < 12; i++) { const a = i / 12 * 6.283; B.tube([[Math.cos(a) * .3, piv[1] + .1 + Math.sin(a) * .3, .85], [Math.cos(a) * .52, piv[1] + .1 + Math.sin(a) * .52, .8], [Math.cos(a) * .72, piv[1] + .1 + Math.sin(a) * .72, .55]], [.04, .045, .015]); }
  B.group({ mat: 1, k: .02 }); B.tube([[.05, piv[1] - .25, .98], [.0, piv[1] - .9, .9], [.06, piv[1] - 1.6, .7], [.02, piv[1] - 2.2, .55]], [.07, .055, .05, .012]);
  return B;
} };
