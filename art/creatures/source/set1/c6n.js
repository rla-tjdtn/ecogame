// 6장 비인간형 — 여행가방: 세워진 가방 속에 접혀 들어간 투숙객. 안에서 손가락으로 뚜껑을 벌리고 거꾸로 접힌 얼굴이 내다본다. 가방 밑으로 나온 두 다리로 쪼그려 뛴다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'c6n', name: '여행가방', kind: '비인간형 · 6장 호텔', H: 5.6, build(p = {}) {
  const B = new Body(), hop = p.hop || 0, op = p.open ?? 46, by = 2.75 + hop * 1.4, tl = p.tilt ?? -6;
  const base = new Frame([0, by, -.1], [1, 0, 0], [0, 1, 0], [0, 0, 1]).rot(0, 0, tl), b = v => base.p(v);
  const W = 1.25, H = 1.85, D = .62; // 반폭·반높이·반깊이
  const shell = (F, up) => { B.group({ k: .05, kg: 0, amp: .004, freq: 3 }); B.box(F.at([0, 0, up * D * .5]), [W, H, D * .55], .22); B.box(F.at([0, 0, up * D * -.12]), [W - .13, H - .13, D * .55], .16, { op: 1, k: .03 }); for (const y of [-1.0, 1.0]) B.groove(F.p([0, y, 0]), F.y, .14, -.03, 3, { wob: 0 }); for (let i = 0; i < 6; i++) B.groove(F.p([-.5 + i * .22, -.9 + i * .4, up * D]), V.norm(V.add(F.x, V.mul(F.y, Math.sin(i * 2.4)))), .014, .02, .4 + .25 * Math.abs(Math.sin(i)), { wob: .3, wf: 3 }); B.group({ k: .02 }); for (const x of [-W + .06, W - .06]) for (const y of [-H + .06, H - .06]) B.ell(F.at([x, y, up * D * .72]), [.22, .22, .24], { k: .05 }); };
  shell(base, -1);
  const hinge = base.at([-W, 0, .04]).rot(0, -op, 0), lid = hinge.at([W, 0, 0]); shell(lid, 1);
  B.group({ k: .03 }); B.tube([b([-.36, H, -.3]), b([-.32, H + .32, -.3]), b([.32, H + .32, -.3]), b([.36, H, -.3])], .075); for (const y of [-1.0, 1.0]) { B.group({ k: .02 }); B.box(base.at([W + .03, y, -.05]), [.05, .14, .12], .03); B.box(lid.at([W + .03, y, .08]), [.05, .14, .14], .03); }
  // 속: 어둠 + 접힌 몸(등뼈가 위쪽 절반을 채움)
  B.group({ mat: 2, k: .05 }); B.box(base.at([0, 0, -.3]), [W - .2, H - .2, .2], .1);
  B.group({ k: .16, kg: .06, amp: .006, freq: 4 }); B.tube([b([-.75, -.2, -.15]), b([-.8, .7, 0]), b([-.3, 1.3, .12]), b([.4, 1.28, .12]), b([.8, .65, 0]), b([.72, -.3, -.15])], [.3, .36, .42, .42, .36, .28]); A.rings(B, [b([-.8, .2, 0]), b([-.3, 1.3, .1]), b([.4, 1.28, .1]), b([.8, .2, 0])], 12, .024, .05, .7, { tilt: .12 });
  A.spine(B, [b([-.8, .2, 0]), b([-.6, 1.05, .08]), b([0, 1.4, .12]), b([.6, 1.05, .08]), b([.8, .2, 0])], .085, { n: 15, back: base.z, out: .36, wing: true, k: .03 });
  // 거꾸로 접힌 얼굴
  const HF = new Frame(b([.08, .05, op < 20 ? -.12 : .55]), V.norm(V.add(V.mul(base.x, -1), V.mul(base.y, .1))), V.norm(V.add(V.mul(base.y, -1), V.mul(base.x, -.1))), base.z).rot(0, p.headYaw ?? 8, 0); A.neck(B, b([.05, .95, .15]), HF.p([0, -.28, -.25]), .2, { front: base.z }); A.head(B, HF, 1.5, { jaw: p.jaw ?? 24, gaunt: 1.25, eyes: 'pin', eyeSize: 1.2, eyeH: .085, pin: .015, nose: 'human', teeth: 11, w: 1.0 });
  const R = []; for (let i = 0; i < 44; i++) { const a = i / 44 * Math.PI * 2, x = Math.cos(a) * .3, z = Math.sin(a) * .36 - .06, j = Math.sin(i * 4.7), q = HF.p([x * .6, .34, z * .7]); R.push([q, V.add(HF.p([x * 1.02, .42, z]), [0, -.05, 0]), V.add(q, [-x * .3 + j * .04, -.9, .12 + z * .2]), V.add(q, [-x * .35 + j * .14, -1.35 - .4 * Math.abs(j), .14 + j * .08])]); } A.hair(B, R, { r: [.06, .042, .028, .006] });
  // 무릎 둘이 머리 양옆에 끼어 있음
  for (const m of [-1, 1]) { B.group({ k: .1, kg: .06, amp: .004, freq: 6 }); B.tube([b([m * .55, 1.0, .15]), b([m * .95, .1, op < 20 ? .1 : .42]), b([m * .72, -.75, .25])], [.26, .25, .18]); B.ball(b([m * .98, .08, op < 20 ? .1 : .56]), .17, { k: .1 }); }
  // 뚜껑과 몸통 가장자리를 안에서 쥔 손
  const grip = (o, along, into, out) => { for (let i = 0; i < 4; i++) { B.group({ k: .02, kg: .03 }); const c = V.add(o, V.mul(along, (i - 1.5) * .19)); B.tube([V.add(c, V.mul(into, .28)), V.add(c, V.mul(out, .1)), V.add(V.add(c, V.mul(out, .12)), V.mul(into, -.22)), V.add(V.add(c, V.mul(out, .02)), V.mul(into, -.48))], [.085, .08, .07, .045]); B.ball(V.add(c, V.add(V.mul(out, .13), V.mul(into, -.06))), .09, { k: .03 }); } };
  grip(b([W, .55, .08]), base.y, V.mul(base.x, -1), base.z); grip(b([W, -.7, .08]), base.y, V.mul(base.x, -1), base.z); grip(lid.p([W, -.2, 0]), lid.y, V.mul(lid.x, -1), V.mul(lid.z, -1));
  // 다리: 밑에서 나와 크게 쪼그림
  for (const m of [-1, 1]) { const h = b([m * .75, -H + .1, -.2]), k = [m * 2.15, 2.55 + hop * .6, .75 - hop * .5], an = [m * 1.65, .36 + hop * 1.1, .15 - hop * .6]; A.leg(B, h, k, an, .36, { m: 1.05, front: [m * .6, .3, 1] }); A.foot(B, new Frame(an, [1, 0, 0], [0, 1, 0], V.norm([m * .5, -hop * .6, 1])), 1.4, { toe: 1.3 }); }
  // 팔 하나: 바닥을 짚고 몸을 끈다
  { const s = b([W - .2, -1.35, .2]), e = [2.1, 1.65 + hop * .6, 1.7], wr = [1.35, .4 + hop, 2.35]; A.arm(B, s, e, wr, .24, { m: .9 }); A.hand(B, new Frame(wr, V.norm([-1, 0, 0]), V.norm([-.15, -.15, .97]), [0, 1, .1]), 1.45, { curl: 11, spread: 14, thin: .8, len: 1.15 }); }
  // 짐표(붉은)
  B.group({ mat: 1, k: .01 }); B.tube([b([.36, H + .05, -.3]), b([.7, H + .12, -.15]), b([.85, H - .3, .0])], .018); B.box(Frame.along(b([.9, H - .56, .02]), [.1, 1, 0], [.2, 0, 1]), [.17, .27, .02], .02);
  return B;
} };
