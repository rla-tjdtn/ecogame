// 시안2 2장 인간형 — 포크: 두 팔이 지게차 쇠발로 바뀐 작업자. 등에서 솟은 마스트 기둥 사이에 머리가 끼어 있고, 쇠발로 사람을 떠 올린다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'd2h', name: '포크', kind: '인간형 · 2장 물류 창고', H: 10.5, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .35 : Math.sin(w * Math.PI * 2), lift = p.lift ?? 0;
  for (const m of [-1, 1]) { const st = m * S, h = [m * .62, 3.5, -.2], k = [m * .95, 1.95, .35 + st * .45], an = [m * .8, .36 + Math.max(0, -st) * .12, -.25 + st * .8]; A.leg(B, h, k, an, .5, { m: 1.0, front: [m * .25, 0, 1] }); A.foot(B, new Frame(an, [1, 0, 0], [0, 1, 0], V.norm([m * .3, 0, 1])), 1.35, {}); }
  A.pelvis(B, new Frame([0, 3.7, -.2], [1, 0, 0], V.norm([0, 1, .3]), V.norm([0, -.3, 1])), { w: .78, d: .5 });
  B.group({ k: .22, kg: .3, amp: .01, freq: 3.5 }); B.tube([[0, 3.8, -.2], [0, 4.6, .05], [0, 5.4, .3]], [.66, .62, .74]); A.rings(B, [[0, 4.0, .1], [0, 5.0, .2]], 5, .028, .045, 1.3, { bow: .25 });
  A.torso(B, new Frame([0, 5.95, .35], [1, 0, 0], V.norm([0, .95, .32]), V.norm([0, -.32, .95])), { w: 1.0, d: .6, h: 1.7, n: 7, r: .06, scap: true });
  // 마스트: 등에 박힌 두 기둥 + 가로대 + 체인
  for (const x of [-.62, .62]) { B.group({ k: .02, kg: .02 }); B.box(new Frame([x, 7.6, -.35], [1, 0, 0], V.norm([0, 1, -.06]), V.norm([0, .06, 1])), [.13, 2.9, .2], .04); B.box(new Frame([x, 7.6, -.2], [1, 0, 0], V.norm([0, 1, -.06]), V.norm([0, .06, 1])), [.05, 2.95, .18], .02, { op: 1, k: .02 }); }
  B.group({ k: .02 }); for (const y of [5.2, 8.4, 10.35]) B.box(new Frame([0, y, -.4 - (y - 7) * .05], [1, 0, 0], [0, 1, 0], [0, 0, 1]), [.8, .12, .14], .04);
  for (const x of [-.22, .22]) { B.group({ k: .01 }); for (let i = 0; i < 15; i++) { const y = 10.2 - i * .23; B.ell(new Frame([x, y, -.2], i % 2 ? [1, 0, 0] : [0, 0, 1], [0, 1, 0], i % 2 ? [0, 0, 1] : [-1, 0, 0]), [.07, .13, .03]); } }
  // 기둥이 살을 뚫은 자리
  for (const m of [-1, 1]) { B.group({ k: .08, kg: .14, amp: .01, freq: 5 }); for (let i = 0; i < 3; i++) B.tube([[m * .35, 5.6 + i * .5, -.1], [m * .62, 5.65 + i * .5, -.12], [m * .88, 5.5 + i * .5, -.2]], [.2, .13, .16]); }
  // 머리: 마스트 사이에 끼어 뒤로 젖혀짐, 입에 체인이 물려 있음
  A.neck(B, [0, 6.75, .35], [0, 7.35, .3], .36, { mid: [0, 7.05, .42] }); const HF = new Frame([0, 7.85, .3], [1, 0, 0], V.norm([0, .97, -.25]), V.norm([0, .25, .97])).rot(0, p.headYaw || 0, 5); const H = A.head(B, HF, 1.35, { jaw: 26, gaunt: 1.1, eyes: 'hollow', eyeSize: 1.05, eyeH: .055, nose: 'human', teeth: 9, w: 1.0, ears: false });
  B.group({ k: .01 }); for (const m of [-1, 1]) for (let i = 0; i < 6; i++) { const t = i / 5, q = V.lerp(H.P([m * .1, -.33, .36]), [m * .5, 8.35, .05], t); q[1] -= Math.sin(t * 3.14) * .18; B.ell(new Frame(q, i % 2 ? [1, 0, 0] : [0, 0, 1], V.norm([m * .6, .5, -.4]), i % 2 ? [0, 0, 1] : [-1, 0, 0]), [.055, .1, .028]); }
  // 팔 → 쇠발: 위팔은 살, 팔꿈치 아래부터 L 자 강철 포크
  for (const m of [-1, 1]) { const s = [m * 1.12, 6.55, .45], e = [m * 1.3, 4.75 + lift * .9, .35], c = [m * .95, 3.35 + lift * 2.2, .85]; A.arm(B, s, e, c, .38, { m: 1.1 });
    B.group({ k: .03, kg: .02 }); const F = new Frame(c, [1, 0, 0], [0, 1, 0], [0, 0, 1]).rot(lift ? -6 : 3, 0, 0); B.box(F.at([0, .05, .05]), [.36, .85, .13], .04); B.box(F.at([0, -.78, 1.75]), [.34, .085, 1.85], .04); B.cone(F.p([-.2, -.78, 3.5]), F.p([-.06, -.8, 4.1]), .085, .02); B.cone(F.p([.2, -.78, 3.5]), F.p([.06, -.8, 4.1]), .085, .02); B.cone(F.p([0, -.78, 3.4]), F.p([0, -.8, 4.12]), .12, .02); for (const y of [.5, -.2]) B.ball(F.p([0, y, .16]), .1, { k: .02 }); for (let i = 0; i < 4; i++) B.groove(F.p([.1 * Math.sin(i * 3), -.7, 1 + i * .6]), [1, 0, Math.sin(i * 2)], .014, .02, .3, { wob: .2, wf: 5 });
    B.group({ k: .06, kg: .14, amp: .01, freq: 6 }); for (let i = 0; i < 6; i++) { const a = i / 6 * 6.283; B.tube([V.add(c, [Math.cos(a) * .3, .75, Math.sin(a) * .26]), V.add(c, [Math.cos(a) * .42, .35 + .15 * Math.sin(i * 3), .05 + Math.sin(a) * .2])], [.14, .03]); } }
  // 쇠발 끝의 마른 피(붉은) — 한쪽만
  { const F = new Frame([.95, 3.35 + lift * 2.2, .85], [1, 0, 0], [0, 1, 0], [0, 0, 1]).rot(lift ? -6 : 3, 0, 0); B.group({ mat: 1, k: .02 }); B.tube([F.p([.1, -.69, 3.2]), F.p([-.05, -.69, 3.6]), F.p([.05, -.71, 3.95])], [.03, .06, .02]); }
  // 안전모 끈처럼 늘어진 작업 조끼 조각
  for (const m of [-1, 1]) { A.strap(B, [[m * .5, 6.75, .75], [m * .62, 6.0, .95], [m * .55, 5.1, .85], [m * .62, 4.4, .7]], .14, .03, [0, .1, 1]); }
  return B;
} };
