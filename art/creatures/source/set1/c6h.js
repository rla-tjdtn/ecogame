// 6장 사람형 — 지배인: 허리를 직각으로 굽힌 채 걷는다. 등 뒤로 꺾어 올린 두 팔, 바닥까지 갈라진 연미복 꼬리가 바퀴벌레 날개처럼 떨린다. 꺾인 목 끝의 얼굴만 너를 똑바로 본다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'c6h', name: '지배인', kind: '사람형 · 6장 호텔', H: 6.8, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .45 : Math.sin(w * Math.PI * 2), fl = p.flare ?? .35;
  for (const m of [-1, 1]) { const st = m * S, h = [m * .4, 4.5, -.7], k = [m * .48, 2.5, -.2 + st * .55], an = [m * .44, .36 + Math.max(0, -st) * .2, -.75 + st * .95];
    B.group({ k: .12, kg: .2, amp: .008, freq: 4 }); B.tube([h, V.lerp(h, k, .5), k, V.lerp(k, an, .5), V.add(an, [0, .18, 0])], [.36, .27, .2, .19, .2]); for (let i = 0; i < 3; i++) { B.groove(V.add(k, [0, .12 - i * .13, 0]), [m * .5 * Math.sin(i * 2 + 1), 1, .7 - i * .5], .02, .035, .42, { bow: .6, wob: .2, wf: 4 }); B.groove(V.add(an, [0, .45 - i * .12, 0]), [.4 * Math.sin(i * 3), 1, .35 * Math.cos(i * 2)], .02, .035, .34, { bow: .5, wob: .2, wf: 5 }); } B.groove(V.lerp(h, k, .5), [0, .02, 1], .012, .02, 1.6, { wob: .05 });
    B.group({ k: .04, kg: .03 }); const F = new Frame(an, [1, 0, 0], [0, 1, 0], V.norm([m * .12, 0, 1])), f = v => F.p(v); B.tube([f([0, .1, -.12]), f([0, -.14, -.05]), f([0, -.2, .45]), f([0, -.23, .85]), f([0, -.22, 1.12])], [.17, .2, .16, .11, .03]); B.box(F.at([0, -.31, .4]), [.14, .04, .62], .03); B.box(F.at([0, -.31, -.12]), [.13, .09, .12], .03); }
  A.pelvis(B, new Frame([0, 4.65, -.7], [1, 0, 0], V.norm([0, .75, .65]), V.norm([0, -.65, .75])), { w: .5, d: .38 });
  // 앞으로 뻗은 상체(재킷) — 거의 수평
  const T = new Frame([0, 5.15, .75], [1, 0, 0], V.norm([0, .22, 1]), V.norm([0, -1, .22])), t = v => T.p(v); // y = 머리 쪽, z = 배(아래)
  B.group({ k: .18, kg: .22, amp: .006, freq: 4 }); B.tube([[0, 4.75, -.6], [0, 5.0, .1], t([0, .1, -.05]), t([0, .75, -.1])], [.5, .44, .58, .6]); B.ell(T.at([0, .25, -.05]), [.76, .95, .5]); B.ell(T.at([0, .75, -.08]), [.86, .35, .42]);
  A.rings(B, [[0, 4.8, -.3], [0, 5.05, .35]], 5, .025, .04, 1.0, { tilt: .3 }); for (const m of [-1, 1]) { A.fold(B, [t([m * .12, .95, .4]), t([m * .34, .5, .5]), t([m * .1, -.45, .5])], .022); A.fold(B, [t([m * .7, .7, -.3]), t([m * .5, .0, -.48]), t([m * .25, -.9, -.45])], .02); }
  // 등뼈가 옷을 밀어 올림
  B.group({ k: .06, kg: .1 }); for (let i = 0; i < 9; i++) B.ell(T.at([0, -1.15 + i * .25, -.54 + .06 * Math.abs(i - 5) * .4]), [.07, .09, .1]);
  // 연미복 꼬리 = 날개: 허리에서 뒤로 길게, 벌어짐
  for (const m of [-1, 1]) { const a = [m * .28, 5.1, -.75], mid = [m * (.5 + fl * .8), 4.1 + fl * .4, -2.1], tip = [m * (.42 + fl * 1.0), 1.15 + fl * .6, -2.7]; B.group({ k: .05, kg: .08, amp: .005, freq: 5 }); const n = 9; for (let i = 0; i < n; i++) { const u = i / (n - 1) - .5, sp = u * .95; B.tube([V.add(a, [sp * .45, 0, -.02 - Math.abs(u) * .08]), V.add(mid, [sp * 1.15, u * m * .2, Math.abs(u) * -.15]), V.add(V.lerp(mid, tip, .6), [sp * .85, -Math.abs(u) * .1, .0]), V.add(tip, [sp * .22, Math.abs(u) * 1.0, 0])], [.08, .085, .07, .025], { k: .05 }); } for (let i = 0; i < 4; i++) B.groove(V.lerp(a, tip, .25 + i * .17), V.norm([m * .9, .1 * i, .2]), .02, .04, 1.2, { wob: .2, wf: 2 }); }
  // 팔: 등 뒤로 꺾여 올라감, 손가락이 깍지 끼어 더듬이처럼 펴짐
  for (const m of [-1, 1]) { const s = t([m * .88, .75, -.1]), e = [m * 1.35, 6.55, .55], wr = [m * .32, 6.35, -.6]; B.group({ k: .1, kg: .2, amp: .006, freq: 5 }); B.tube([s, V.lerp(s, e, .5), e], [.27, .21, .2]); B.tube([e, V.lerp(e, wr, .5), wr], [.2, .18, .15]); A.rings(B, [V.lerp(s, e, .75), e, V.lerp(e, wr, .25)], 6, .022, .035, .5, { tilt: .35 }); B.group({ k: .02, kg: .02 }); B.cone(V.lerp(e, wr, .93), V.lerp(e, wr, 1.04), .17, .17); B.group({ k: .01 }); A.hand(B, new Frame(wr, V.norm([0, -.4, -.9]), V.norm([-m * .25, .75, -.62]), V.norm([m * .5, .6, .6])), 1.6, { curl: [4, 8, 6, 2], spread: 14, thin: .72, len: 1.4 }); }
  // 셔츠 깃 + 나비넥타이(붉은)
  const nb = t([0, 1.02, -.02]); B.group({ k: .03, kg: .05 }); for (const m of [-1, 1]) B.tube([t([m * .3, .92, -.22]), t([m * .28, 1.08, .05]), t([m * .06, 1.02, .34])], [.07, .075, .04]); B.group({ mat: 1, k: .03 }); for (const m of [-1, 1]) B.cone(t([m * .05, .98, .4]), t([m * .3, .96, .42]), .06, .14); B.ball(t([0, .98, .41]), .07);
  // 목: 위로 꺾여 얼굴이 정면
  A.neck(B, nb, [0, 5.75, 2.25], .2, { front: [0, 0, 1], mid: [0, 5.4, 2.2], adam: true });
  const HF = new Frame([0, 6.12, 2.28], [1, 0, 0], V.norm([0, 1, .05]), V.norm([0, -.05, 1])).rot(0, p.headYaw || 0, p.headRoll ?? 16); const H = A.head(B, HF, 1.3, { jaw: 0, gaunt: 1.35, eyes: 'pin', eyeSize: 1.1, eyeH: .075, pin: .014, nose: 'human', mouth: false, elong: 1.08, w: .94, wrinkle: true });
  // 귀까지 찢어진 다문 미소 + 이
  B.group({ mat: 2, k: .02 }); B.tube([H.P([-.28, -.1, .12]), H.P([-.19, -.24, .25]), H.P([0, -.31, .325]), H.P([.19, -.24, .25]), H.P([.28, -.1, .12])], [.01, .055, .07, .055, .01].map(x => x * 1.3)); B.group({ mat: 4, k: .004 }); for (let i = 0; i < 17; i++) { const u = i / 16 * 2 - 1, x = u * .25, y = -.31 + u * u * .19, z = .365 - u * u * .19; B.cone(H.P([x, y + .035, z]), H.P([x, y - .045, z]), .024, .02); }
  // 포마드로 넘긴 머리: 두개에 새긴 빗질 홈
  for (const g of B.groups) if (g.prims.some(q => q.op === 1 && q.t === 1) && g.mat === 0 && g.prims.length > 24 && g.freq > 4) { B.g = g; for (let i = 0; i < 13; i++) B.groove(H.P([(i - 6) * .052, .26, -.1]), HF.x, .008, .02, .58, { wob: .03, wf: 3, bow: (i - 6) * .02 }); B.groove(H.P([0, .2, .0]), V.add(V.mul(HF.y, .55), V.mul(HF.z, -.83)), .02, .03, .62, { wob: .04 }); break; }
  return B;
} };
