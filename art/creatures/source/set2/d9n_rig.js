// 시안2 9장 비인간형 — 덮개: 천장 배관에 발로 매달린 것. 접으면 자동차 덮개 천 같고, 펴면 팔과 옆구리 사이 살막이 박쥐 날개처럼 주차 칸 하나를 덮는다.
// (리그용 사본: 막 분할 수 K 를 펼친 자세(open 1) 기준으로 고정 → open 을 바꿔도 도형 수·순서가 같아 뼈가 날개 펄럭임을 따라간다. 모양은 d9n 과 같다. game/fixes/teamD.json 의 k9s2 mod 가 쓴다)
let KT = [], KI = 0, KREC = false;
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'd9n', name: '덮개', kind: '비인간형 · 9장 지하 주차장', H: 11, build(p = {}) {
  KI = 0; const B = new Body(), o = p.open ?? .85, top = 11.4;
  // 배관
  B.group({ k: .02 }); B.cone([-5.2, top, 0], [5.2, top, 0], .22, .22); for (const x of [-3.4, 0, 3.4]) { B.cone([x - .12, top, 0], [x + .12, top, 0], .3, .3); B.cone([x, top, 0], [x, top + .9, 0], .05, .05); }
  // 다리: 발가락이 배관을 감음
  for (const m of [-1, 1]) { const an = [m * .55, top - .55, .05], k = [m * .95, 9.55, .55], h = [m * .42, 8.35, 0]; A.leg(B, h, k, an, .3, { m: .85, front: [m * .3, 0, 1] }); for (let i = 0; i < 5; i++) { B.group({ k: .03, kg: .05 }); const x = m * .55 + (i - 2) * .13; B.tube([[x, top - .5, .05], [x, top - .12, .36], [x, top + .24, .22], [x, top + .25, -.16]], [.1, .09, .075, .03]); } }
  A.pelvis(B, new Frame([0, 8.2, 0], [1, 0, 0], [0, -1, 0], [0, 0, 1]), { w: .54, d: .36 }); B.group({ k: .18, kg: .25, amp: .006, freq: 4 }); B.tube([[0, 8.2, 0], [0, 7.4, .06], [0, 6.7, 0]], [.44, .34, .46]); A.rings(B, [[0, 8.1, 0], [0, 7.0, 0]], 7, .024, .045, .9, { bow: -.25 });
  A.torso(B, new Frame([0, 6.1, 0], [1, 0, 0], [0, -1, .02], [0, 0, 1]), { w: .76, d: .48, h: 1.6, n: 9, r: .05 });
  // 팔 = 날개 뼈: 길게 옆으로, 손가락이 우산살처럼
  for (const m of [-1, 1]) {
    const s = [m * .92, 5.5, 0], e = [m * (1.0 + o * 1.35), 4.9 + o * 1.1, .25 + (1 - o) * .55], wr = [m * (1.15 + o * 2.4), 4.1 + o * 2.6, .35 + (1 - o) * .9]; A.arm(B, s, e, wr, .24, { m: .9 });
    const tips = []; for (let i = 0; i < 4; i++) { const a = (-.15 + i * .5) * o + .12, L = [3.2, 3.9, 4.0, 3.6][i] * (.75 + .25 * o); const d = V.norm([m * Math.cos(a + (1 - o) * 1.45) * o + m * .05, -Math.sin(a) - (1 - o) * 1.3, .1]); const t1 = V.add(wr, V.mul(d, L * .4)), t2 = V.add(V.add(wr, V.mul(d, L * .75)), [0, -.22, .12]), t3 = V.add(V.add(wr, V.mul(d, L)), [0, -.6, .02]); tips.push([t1, t2, t3]); B.group({ k: .02, kg: .05 }); B.tube([wr, V.lerp(wr, t1, .5), t1], [.11, .07, .065]); B.tube([t1, V.lerp(t1, t2, .5), t2], [.065, .05, .045]); B.tube([t2, t3], [.045, .012]); for (const q of [t1, t2]) B.ball(q, .085, { k: .03 }); }
    { B.group({ k: .02, kg: .04 }); const h = V.add(wr, [m * .1, .55, .15]); B.tube([wr, V.add(wr, [m * .18, .32, .15]), h, V.add(h, [-m * .25, .12, .12])], [.09, .075, .06, .012]); } // 엄지 갈고리
    // 막: 손가락 사이 + 손목~옆구리~허벅지. 얇은 타원 판을 잇달아
    const mem = (a, b, c2, d2, n, sag) => { const wd = Math.max(V.len(V.sub(b, a)), V.len(V.sub(c2, d2))), K = KREC ? (KT.push(Math.max(3, Math.ceil(wd / .2))), KT[KT.length - 1]) : KT[KI++]; B.group({ k: .26, kg: .12, amp: .006, freq: 3 }); for (let i = 0; i <= K; i++) { const u = i / K, p0 = V.lerp(a, b, u), p1 = V.lerp(d2, c2, u), sg = Math.sin(u * 3.14) * sag; B.tube([p0, V.add(V.lerp(p0, p1, .35), [0, -sg * .6, -sg * .5]), V.add(V.lerp(p0, p1, .7), [0, -sg, -sg * .6]), V.add(p1, [0, -sg * -.5, 0])], [.06, .075, .075, .04], { per: 2 }); } };
    for (let i = 0; i < 3; i++) mem(wr, wr, tips[i + 1][2], tips[i][2], 4, .12 * o + .05); mem(wr, e, [m * .85, 6.2, -.05], tips[3][2], 5, .25); mem(tips[3][2], [m * .85, 6.2, -.05], [m * .5, 8.0, -.05], [m * (.9 + o * .8), 5.9, 0], 4, .15);
  }
  // 머리: 아래로, 얼굴은 납작 눌려 전조등처럼 빛나는 눈 두 점
  A.neck(B, [0, 5.35, .02], [0, 4.75, .2], .2, { front: [0, .2, 1] }); const HF = new Frame([0, 4.3, .28], [-1, 0, 0], V.norm([0, -1, .08]), V.norm([0, .08, 1])).rot(0, p.headYaw || 0, -6); A.head(B, HF, 1.35, { jaw: p.jaw ?? 34, gaunt: 1.2, eyes: 'pin', pin: .03, eyeSize: 1.1, eyeH: .05, nose: 'skull', teeth: 12, toothLen: .07, w: 1.1, mouthW: 1.2, ears: false });
  // 늘어진 덮개 끈(붉은)
  B.group({ mat: 1, k: .01 }); B.tube([[.5, 7.8, .3], [.75, 7.0, .5], [.6, 6.0, .55], [.8, 4.9, .6], [.7, 4.0, .55]], [.05, .04, .04, .035, .012]);
  return B;
} };

KREC = true; module.exports.build({ open: 1, jaw: 44 }); KREC = false;
