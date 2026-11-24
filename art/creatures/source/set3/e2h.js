// 시안3 2장 인간형 — 진열장: 가슴과 배가 선반처럼 벌어져 칸마다 잘린 얼굴이 진열된 몸. 가격표가 달려 있고, 맨 아래 칸은 비어 있다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'e2h', name: '진열장', kind: '인간형 · 2장 물류 창고', H: 10.4, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .4 : Math.sin(w * Math.PI * 2), aw = p.awake ?? .5;
  for (const m of [-1, 1]) { const st = m * S, h = [m * .7, 3.6, -.1], k = [m * .8, 2.0, .25 + st * .45], an = [m * .72, .36 + Math.max(0, -st) * .15, -.15 + st * .8]; A.leg(B, h, k, an, .45, { m: 1.0, front: [m * .15, 0, 1] }); A.foot(B, new Frame(an, [1, 0, 0], [0, 1, 0], V.norm([m * .2, 0, 1])), 1.3, {}); }
  A.pelvis(B, new Frame([0, 3.8, -.1], [1, 0, 0], [0, 1, 0], [0, 0, 1]), { w: .85, d: .45 });
  // 등판 + 양옆 살 벽(세로로 길게 늘어난 몸통)
  B.group({ k: .16, kg: .25, amp: .01, freq: 3 }); B.box(new Frame([0, 6.1, -.55], [1, 0, 0], V.norm([0, 1, .02]), [0, 0, 1]), [1.2, 2.3, .22], .2); for (const m of [-1, 1]) B.tube([[m * 1.0, 3.9, -.1], [m * 1.28, 4.8, .1], [m * 1.34, 6.2, .15], [m * 1.25, 7.6, .1], [m * .9, 8.3, 0]], [.3, .26, .25, .27, .36]); B.tube([[-1.0, 8.3, -.1], [0, 8.45, -.15], [1.0, 8.3, -.1]], [.34, .36, .34]); B.tube([[-.9, 3.95, 0], [0, 3.9, .1], [.9, 3.95, 0]], [.28, .3, .28]);
  for (const m of [-1, 1]) { for (let i = 0; i < 9; i++) B.groove([m * 1.4, 4.4 + i * .42, .1], V.norm([m * .2, 1, .3 * Math.sin(i * 2)]), .025, .05, .5, { bow: .4, wob: .2, wf: 3 }); A.veins(B, [[m * 1.45, 4.5, .25], [m * 1.5, 5.4, .3], [m * 1.48, 6.4, .34], [m * 1.4, 7.4, .28]], .03); }
  // 선반 = 갈비 묶음(칸 4개)
  const ys = [4.35, 5.4, 6.42, 7.4]; for (const y of ys) { for (let j = 0; j < 4; j++) { const z = -.3 + j * .28; B.group({ k: .03, kg: .06 }); B.tube([[-1.25, y - .02, z - .06], [-.6, y + .04 * Math.sin(j * 2 + y), z], [0, y - .03, z + .03], [.6, y + .04 * Math.cos(j * 3), z], [1.25, y - .02, z - .06]], [.1, .075, .07, .075, .1]); } B.group({ k: .05, kg: .08 }); for (const m of [-1, 1]) B.tube([[m * 1.25, y + .25, .3], [m * 1.1, y + .02, .5], [m * .85, y - .03, .56]], [.14, .1, .05]); }
  // 칸 속 어둠
  B.group({ mat: 2, k: .02 }); B.box(new Frame([0, 6.1, -.36], [1, 0, 0], [0, 1, 0], [0, 0, 1]), [1.1, 2.1, .06], .05);
  // 진열된 얼굴들
  const items = [[-.55, 5.4, 1.0, 8, 0], [.52, 5.4, .95, -10, 1], [-.6, 6.42, .92, -14, 2], [.5, 6.42, 1.02, 6, 3], [-.5, 7.4, .85, 12, 4], [.5, 7.4, .88, -6, 5]]; items.forEach(([x, y, s, r, i]) => { const op = i / 6 < aw; A.face(B, new Frame([x, y + .1 + s * .48, .12], [1, 0, 0], V.norm([0, 1, -.06]), V.norm([0, .06, 1])).rot(0, -x * 12, r), s, { jaw: op ? [20, 4, 30, 10, 16, 36][i] : 0, eyes: op ? ['real', ['real', 'shut'], 'empty', 'real', 'sewn', 'real'][i] : 'shut', gaunt: 1 + .1 * i, teeth: 8, w: .95 + .03 * (i % 3), nose: i === 2 ? 'hole' : 'human' }); B.group({ k: .05, kg: .06 }); for (let j = 0; j < 6; j++) { const a = j / 6 * 6.283; B.tube([[x + Math.cos(a) * .16 * s, y + .2, .05 + Math.sin(a) * .14 * s], [x + Math.cos(a) * .24 * s, y + .1, .08 + Math.sin(a) * .2 * s], [x + Math.cos(a) * .28 * s, y + .05, .1 + Math.sin(a) * .24 * s]], [.06, .04, .012]); } });
  // 가격표
  for (const [x, y, red] of [[-.95, 6.28, 0], [.2, 5.26, 1], [.95, 7.26, 0]]) { B.group({ k: .006, mat: red }); B.tube([[x, y, .62], [x + .02, y - .12, .68]], .012, { per: 2 }); B.box(new Frame([x + .03, y - .26, .7], V.norm([1, .1, .1]), V.norm([-.1, 1, .1]), [0, -.1, 1]), [.15, .13, .015], .012); }
  // 빈 칸(맨 아래): 손이 안에서 나와 자리를 쓸고 있음
  { const s = [.7, 4.75, -.35], e = [.2, 4.95, .35], wr = [-.3, 4.62, .62]; A.arm(B, s, e, wr, .13, { m: .85 }); A.hand(B, new Frame(wr, V.norm([0, -.3, .9]), V.norm([-.8, -.35, .4]), V.norm([.2, .9, .3])), .95, { curl: 24, spread: 11, thin: .85 }); }
  // 팔: 길고 물건을 집는 손(하나는 잘린 머리카락을 쥠 → 새 얼굴을 들고 있음)
  for (const m of [-1, 1]) { const s = [m * 1.25, 7.9, -.05], e = [m * 1.9, 6.1, .35], wr = [m * 1.45, 4.5, 1.15 + (m > 0 ? 0 : S * .3)]; A.arm(B, s, e, wr, .27, { m: .95 }); A.hand(B, new Frame(wr, V.norm([0, .2, 1]), V.norm([-m * .15, -1, .25]), V.norm([m, 0, .1])), 1.45, { curl: m > 0 ? 62 : [14, 22, 18, 28], spread: 8, thin: .9, len: 1.1 }); }
  { const hx = new Frame([1.5, 2.75, 1.4], V.norm([1, .1, 0]), V.norm([-.1, 1, .05]), [0, 0, 1]).rot(0, 12, 8); A.face(B, hx, 1.0, { jaw: 34, eyes: 'real', teeth: 8, gaunt: 1.1, gaze: [0, .015] }); const R = []; for (let i = 0; i < 26; i++) { const a = i / 26 * 6.283; R.push([hx.p([Math.cos(a) * .24, .34, Math.sin(a) * .28 - .06]), hx.p([Math.cos(a) * .18, .62, Math.sin(a) * .2 - .06]), [1.42 + Math.cos(a) * .08, 3.7, 1.28 + Math.sin(a) * .08], [1.4 + Math.cos(a) * .06, 4.0, 1.25]]); } A.hair(B, R, { r: [.03, .024, .022, .02] }); }
  // 머리: 작고 위에 얹힘, 계산원처럼 다정한 얼굴
  A.neck(B, [0, 8.45, -.1], [0, 9.05, .1], .25, {}); const HF = new Frame([0, 9.6, .15], [1, 0, 0], V.norm([0, 1, .03]), [0, 0, 1]).rot(4, p.headYaw || 0, 12); A.face(B, HF, 1.25, { jaw: p.jaw ?? 6, eyes: 'real', gaunt: 1.2, teeth: 10, iris: .012, w: .95 });
  return B;
} };
