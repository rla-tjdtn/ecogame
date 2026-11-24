// 시안2 4장 비인간형 — 바퀴: 휠체어에 거꾸로 접혀 끼인 환자. 갈비가 바큇살이 되어 돌고, 두 손으로 바퀴를 밀며 바닥에 닿을 듯한 얼굴로 다가온다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'd4n', name: '바퀴', kind: '비인간형 · 4장 폐병원', H: 6.0, build(p = {}) {
  const B = new Body(), r = (p.roll || 0) * 6.283, R0 = 1.95, cy = 1.98;
  // 큰 바퀴 둘: 테 + 갈비 바큇살
  for (const m of [-1, 1]) { const x = m * 1.45, C = a => [x + m * .12 * Math.cos(a * 0), cy + Math.sin(a + r) * R0, Math.cos(a + r) * R0]; const pts = []; for (let i = 0; i <= 40; i++) pts.push(C(i / 40 * 6.283)); B.group({ k: .02 }); B.tube(pts, .12, { per: 1 }); const p2 = pts.map(q => [q[0] + m * .22, cy + (q[1] - cy) * .9, q[2] * .9]); B.tube(p2, .05, { per: 1 }); for (let i = 0; i < 10; i++) { const a = i / 10 * 6.283, q = C(a); B.cone(q, p2[i * 4], .035, .035); }
    for (let i = 0; i < 14; i++) { const a = i / 14 * 6.283, q = C(a), b = [x, cy + Math.sin(a + r) * .24, Math.cos(a + r) * .24], md = [x + m * .16, cy + Math.sin(a + r + .22) * R0 * .55, Math.cos(a + r + .22) * R0 * .55]; B.group({ k: .02, kg: .04 }); B.tube([b, md, V.lerp(q, b, .04)], [.085, .07, .05]); } B.group({ k: .06, kg: .06 }); B.ell(new Frame([x, cy, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]), [.22, .3, .3]); }
  // 차대·등받이·손잡이·작은 앞바퀴
  B.group({ k: .02 }); for (const m of [-1, 1]) { B.tube([[m * 1.05, 2.4, 1.1], [m * 1.05, 2.4, -.95], [m * 1.05, 4.6, -1.35], [m * 1.05, 4.9, -2.0]], .08); B.tube([[m * 1.05, 2.4, 1.1], [m * 1.05, 1.3, 1.6], [m * 1.05, .75, 1.75]], .07); const pts = []; for (let i = 0; i <= 16; i++) { const a = i / 16 * 6.283; pts.push([m * 1.05, .42 + Math.sin(a) * .38, 1.8 + Math.cos(a) * .38]); } B.tube(pts, .07, { per: 2 }); } B.tube([[-1.05, 2.4, .9], [1.05, 2.4, .9]], .06); B.tube([[-1.05, 2.4, -.8], [1.05, 2.4, -.8]], .06);
  B.group({ k: .06, amp: .006, freq: 3 }); B.box(new Frame([0, 2.5, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]), [1.0, .1, .9], .06); B.box(new Frame([0, 3.75, -1.2], [1, 0, 0], V.norm([0, 1, -.2]), V.norm([0, .2, 1])), [1.0, 1.0, .08], .05); for (let i = 0; i < 5; i++) B.groove([-.6 + i * .3, 3.7, -1.1], V.norm([1, .1 * i, 0]), .02, .04, .9, { wob: .2, wf: 2 });
  // 몸: 골반이 등받이 위, 배를 앞으로, 가슴이 자리, 머리가 앞바퀴 사이로 거꾸로
  A.pelvis(B, new Frame([0, 4.95, -.95], [1, 0, 0], V.norm([0, -.85, .5]), V.norm([0, .5, .85])), { w: .58, d: .38 });
  B.group({ k: .18, kg: .25, amp: .006, freq: 4 }); B.tube([[0, 4.8, -.8], [0, 4.4, .05], [0, 3.7, .6]], [.44, .36, .46]); A.rings(B, [[0, 4.7, -.6], [0, 4.0, .4]], 6, .024, .045, .9, { bow: -.3 });
  A.torso(B, new Frame([0, 3.0, .95], [1, 0, 0], V.norm([0, -.9, .4]), V.norm([0, .4, .9])), { w: .74, d: .46, h: 1.5, n: 8, r: .05 });
  // 다리: 등받이 너머로 접혀 앞으로 어깨 위에 얹힘(발이 얼굴 옆으로)
  for (const m of [-1, 1]) { const h = [m * .4, 5.0, -1.0], k = [m * .95, 6.1, .15], an = [m * 1.05, 4.6, 1.55]; A.leg(B, h, k, an, .3, { m: .85, front: [m * .2, .8, .4] }); A.foot(B, new Frame(an, [1, 0, 0], V.norm([0, .4, 1]), V.norm([m * .15, -1, .35])), 1.05, {}); }
  // 정맥줄(붉은): 발목에서 바퀴로
  B.group({ mat: 1, k: .01 }); B.tube([[1.05, 4.65, 1.5], [1.5, 4.2, 1.1], [1.6, 3.2, .5], [1.48, 2.2, .15]], .035);
  // 팔: 바퀴를 움켜쥠
  for (const m of [-1, 1]) { const s = [m * .9, 2.55, 1.2], e = [m * 2.15, 3.3, .95], wr = [m * 1.78, 3.72, .55]; A.arm(B, s, e, wr, .22, { m: .9 }); A.hand(B, new Frame(wr, V.norm([0, 0, 1]), V.norm([-m * .35, .35, -.85]), V.norm([m * .6, .8, .1])), 1.25, { curl: [52, 48, 50, 56], spread: 8, thin: .85 }); }
  // 머리
  A.neck(B, [0, 2.3, 1.3], [0, 1.75, 1.75], .22, { front: [0, .4, .9] }); const HF = new Frame([0, 1.25, 2.0], [-1, 0, 0], V.norm([0, -1, .1]), V.norm([0, .1, 1])).rot(0, p.headYaw || 0, -10); A.head(B, HF, 1.35, { jaw: p.jaw ?? 30, gaunt: 1.25, eyes: 'pin', eyeSize: 1.15, eyeH: .08, pin: .015, nose: 'human', teeth: 11 });
  const R = []; for (let i = 0; i < 40; i++) { const a = i / 40 * 6.283, x = Math.cos(a) * .3, z = Math.sin(a) * .36 - .06, j = Math.sin(i * 4.7), b = HF.p([x * .6, .34, z * .7]); R.push([b, HF.p([x * 1.0, .44, z]), V.add(b, [x * -.3 + j * .04, -.32, .1]), [b[0] - x * .4 + j * .2, .05, b[2] + .2 + j * .3 - i % 3 * .1]]); } A.hair(B, R, { r: [.05, .036, .026, .008] });
  return B;
} };
