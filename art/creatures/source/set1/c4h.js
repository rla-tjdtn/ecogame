// 4장 사람형 — 합본: 한 사람의 열린 목에서 다른 사람의 상반신이 자라 있다. 윗사람이 아랫사람의 얼굴을 두 손으로 붙들고 걷는다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'c4h', name: '합본', kind: '사람형 · 4장 폐병원', H: 10.6, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .4 : Math.sin(w * Math.PI * 2), ln = p.lean ?? 0, ub = [Math.sin((w || 0) * 6.28) * .12 + .12, 0, 0];
  for (const m of [-1, 1]) { const st = m * S, h = [m * .45, 3.75, 0], k = [m * .55, 2.05, .3 + st * .5], an = [m * .48, .34 + Math.max(0, -st) * .18, -.15 + st * .85]; A.leg(B, h, k, an, .36, { m: .9, front: [m * .15, 0, 1] }); A.foot(B, new Frame(an, [1, 0, 0], [0, 1, 0], V.norm([m * .2, 0, 1])), 1.15, {}); }
  A.pelvis(B, new Frame([0, 3.9, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]), { w: .62, d: .4 });
  // 아래 몸
  B.group({ k: .2, kg: .3, amp: .006, freq: 4 }); B.tube([[0, 3.95, 0], [0, 4.5, .06], [0, 5.0, .0]], [.5, .42, .55]); A.rings(B, [[0, 4.1, .1], [0, 4.7, .1]], 4, .025, .04, 1.0, { bow: .3 });
  A.torso(B, new Frame([0, 5.35, -.02], [1, 0, 0], V.norm([0, 1, -.06]), V.norm([0, .06, 1])), { w: .78, d: .5, h: 1.45, n: 7, r: .05 });
  // 아래 몸의 머리: 목이 앞으로 꺾여 가슴에 매달림, 윗사람 손이 턱을 쥠
  A.neck(B, [0, 6.0, .35], [0, 5.75, 1.05], .24, { front: [0, 1, .3], mid: [0, 6.1, .75] }); const H1 = new Frame([0, 5.55, 1.28], [1, 0, 0], V.norm([0, .9, .42]), V.norm([0, -.42, .9])).rot(0, 0, -14); A.head(B, H1, 1.12, { jaw: 34, gaunt: 1.2, eyes: 'hollow', eyeSize: 1.1, nose: 'human', teeth: 9, toothLen: .05 });
  // 아래 몸의 팔: 위로 올려 윗몸 허리를 껴안음
  for (const m of [-1, 1]) { const s = [m * .92, 5.95, 0], e = [m * 1.42, 6.75, .35], wr = [m * .62, 7.15, .62]; A.arm(B, s, e, wr, .23, { m: .9 }); A.hand(B, new Frame(wr, V.norm([0, -1, .2]), V.norm([-m * .95, .25, .1]), V.norm([0, .15, 1])), 1.15, { curl: 30, spread: 9, thin: .9 }); }
  // 이음: 열린 목 살이 꽃받침처럼 윗허리를 물고 있음 + 실밥(붉은)
  B.group({ k: .1, kg: .16, amp: .015, freq: 4 }); for (let i = 0; i < 12; i++) { const a = i / 12 * Math.PI * 2, r = .5 + .06 * Math.sin(i * 2.6); B.tube([[Math.cos(a) * .62, 6.0, Math.sin(a) * .45], [Math.cos(a) * r, 6.35 + .08 * Math.sin(i * 3.1), Math.sin(a) * r * .8], [Math.cos(a) * r * 1.12, 6.52 + .1 * Math.sin(i * 3.1), Math.sin(a) * r * .95]], [.2, .12, .04]); }
  B.group({ mat: 1, k: .01 }); for (let i = 0; i < 14; i++) { const a = i / 14 * Math.PI * 2; B.tube([[Math.cos(a) * .56, 6.18, Math.sin(a) * .5], [Math.cos(a + .12) * .62, 6.42, Math.sin(a + .12) * .55], [Math.cos(a + .06) * .46, 6.68, Math.sin(a + .06) * .42]], .022, { per: 3 }); }
  // 윗몸
  const u = v => V.add(v, V.add(ub, [0, 0, ln])); B.group({ k: .18, kg: .25, amp: .006, freq: 4 }); B.tube([[0, 6.1, 0], u([0, 6.8, .02]), u([.04, 7.4, -.02])], [.46, .36, .46]); A.rings(B, [[0, 6.6, 0], u([0, 7.2, 0])], 4, .025, .04, .9, { bow: .3 });
  A.torso(B, new Frame(u([.06, 7.95, -.02]), V.norm([1, -.1, 0]), V.norm([.1, 1, .04]), [0, 0, 1]), { w: .72, d: .46, h: 1.4, n: 8, r: .05 });
  // 윗몸의 팔: 길게 내려와 아랫머리 양쪽을 붙듦
  for (const m of [-1, 1]) { const s = u([m * .86, 8.55, 0]), e = u([m * 1.5, 7.1 + m * .1, .55]), wr = [m * .52, 6.0, 1.28]; A.arm(B, s, e, wr, .22, { m: .85 }); A.hand(B, new Frame(wr, V.norm([0, .3, .95]), V.norm([-m * .32, -.92, .12]), V.norm([m * .95, -.2, .2])), 1.3, { curl: [22, 18, 20, 26], spread: 8, thin: .85, len: 1.1 }); }
  // 윗머리: 옆으로 꺾임
  A.neck(B, u([.08, 8.65, .0]), u([.34, 9.3, .16]), .2, { mid: u([.12, 9.0, .04]) }); const H2 = new Frame(u([.5, 9.68, .22]), V.norm([1, -.5, 0]), V.norm([.5, 1, .05]), [0, 0, 1]).rot(0, p.headYaw || 0, 0); A.head(B, H2, 1.2, { jaw: 5, gaunt: 1.3, eyes: 'pin', eyeSize: 1.1, nose: 'human', mouth: true, elong: 1.12 });
  const R = []; for (let i = 0; i < 36; i++) { const a = (i / 36) * Math.PI * 1.35 + Math.PI * .82, x = Math.cos(a) * .33, z = Math.sin(a) * .4 - .06, j = Math.sin(i * 5.7); R.push([H2.p([x * .3, .46, z * .35]), H2.p([x * 1.0, .3, z * 1.0]), V.add(H2.p([x * 1.15, -.1, z * 1.15]), [0, -.3, 0]), V.add(H2.p([x * 1.1 + j * .08, -.3, z * 1.2]), [0, -1.1 - .5 * Math.abs(j), 0])]); } A.hair(B, R, { r: [.05, .034, .024, .006] });
  return B;
} };
