// 시안3 6장 비인간형 — 욕조: 젖은 손 넷으로 걷는 욕조. 안에는 녹아 욕조와 하나가 된 투숙객이 등을 기대고 있고, 머리카락과 팔이 물처럼 넘친다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'e6n', name: '욕조', kind: '비인간형 · 6장 호텔', H: 6.6, build(p = {}) {
  const B = new Body(), w = p.walk ?? .1, rise = p.rise ?? .4, I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]);
  const bob = .06 * Math.sin(w * 12.566), by = 2.75 + bob;
  // 욕조 통: 앞이 낮고 뒤가 높은 나팔형 (z 앞뒤 길이)
  B.group({ k: .1, kg: .1, amp: .008, freq: 3 }); B.ell(I([0, by, 0]), [1.42, 1.15, 2.5]); B.box(I([0, by + .45, 0]), [1.3, .5, 2.25], .45, { k: .3 }); B.box(I([0, by + 1.35, 0]), [1.9, .6, 3.2], .05, { op: 1, k: .03 });
  B.ell(I([0, by + .55, 0]), [1.22, 1.1, 2.25], { op: 1, k: .05 }); B.box(I([0, by + .75, 0]), [1.08, .5, 2.0], .4, { op: 1, k: .06 });
  // 금간 법랑
  for (let i = 0; i < 9; i++) B.groove([Math.sin(i * 2.1) * 1.3, by - .2 + .2 * Math.sin(i * 3), Math.cos(i * 1.7) * 2.0], V.norm([.4 * Math.sin(i * 4), Math.cos(i * 2.3), Math.sin(i * 1.3)]), .012, .02, .75, { wob: .16, wf: 5 });
  const rimP = []; for (let i = 0; i <= 40; i++) { const a = i / 40 * 6.283, c = Math.cos(a), s = Math.sin(a), q = 1 / Math.pow(Math.pow(Math.abs(c), 3.4) + Math.pow(Math.abs(s), 3.4), 1 / 3.4); rimP.push([c * q * 1.32, by + .76 + Math.max(0, -s) * .22, s * q * 2.32]); } B.group({ k: .06, kg: .1 }); B.tube(rimP, .15);
  // 법랑이 피부로 바뀌는 아랫배: 갈비·배꼽
  B.group({ k: .06, kg: .18 }); for (const m of [-1, 1]) for (let i = 0; i < 7; i++) { const z = -1.5 + i * .48; B.tube([[m * 1.3, by + .25, z], [m * 1.22, by - .4, z + .1], [m * .75, by - .95, z + .16], [m * .2, by - 1.12, z + .1]], [.04, .08, .07, .03]); }
  // 속의 물(검은 수면)과 누운 사람
  B.group({ mat: 2, k: .02 }); B.box(I([0, by + .38, 0]), [1.05, .08, 1.95], .06);
  const yb = by + .5 + rise * .35; A.torso(B, new Frame([0, yb + .55, -1.0], [1, 0, 0], V.norm([0, .82, -.57]), V.norm([0, .57, .82])), { w: .72, d: .44, h: 1.5, n: 7, r: .05 }); B.group({ k: .16, kg: .25, amp: .02, freq: 3 }); B.tube([[0, yb + .1, -.3], [0, yb - .15, .3], [0, yb - .35, .9]], [.45, .42, .3]);
  for (const m of [-1, 1]) { B.tube([[m * .28, yb - .25, .3], [m * .42, yb + .35, 1.1], [m * .36, yb - .45, 1.75]], [.28, .25, .18], { k: .1 }); } // 물 위로 솟은 무릎
  // 머리: 뒤로 기대 이쪽을 노려봄, 턱이 녹아 욕조 테두리로 늘어짐
  A.neck(B, [0, yb + 1.1, -1.45], [0, yb + 1.75, -1.45], .24, {}); const HF = new Frame([0, yb + 2.35, -1.3], [1, 0, 0], V.norm([0, 1, .16]), V.norm([0, -.16, 1])).rot(0, p.headYaw || 0, p.tilt ?? -9); A.face(B, HF, 1.55, { jaw: p.jaw ?? 48, eyes: 'real', gaunt: 1.2, teeth: 10, iris: .012, ears: true, lips: .5 });
  B.group({ k: .06, kg: .12 }); for (let i = 0; i < 9; i++) { const u = (i / 8 - .5), j = Math.abs(Math.sin(i * 2.7)); B.tube([HF.p([u * .5, -.95, .25]), HF.p([u * .55, -1.15 - j * .2, .28]), V.add(HF.p([u * .6, -1.3, .3]), [0, -.3 - j * .7, .1])], [.09, .06, .012]); }
  // 젖은 머리카락이 테두리를 넘어 바닥까지
  const R = []; for (let i = 0; i < 90; i++) { const u = i / 89, m = u < .5 ? -1 : 1, v = (u < .5 ? u : 1 - u) * 2, j = Math.sin(i * 5.7), z = -1.6 + v * 2.2 + j * .15; R.push([HF.p([m * .08, .68, -.1]), HF.p([m * .5, .45, -.2 + v * .2]), HF.p([m * .62, -.25, -.15 + v * .2]), [m * (.95 + j * .06), by + 1.05, z * .9 - .2], [m * (1.5 + .03 * j), by + .85, z], [m * (1.6 + .06 * j), by - .4 - v * .3, z + .05 * j], [m * (1.62 + .12 * j), Math.max(.1, by - 1.5 - Math.abs(j) * 1.2), z + .15 * j]]); } A.hair(B, R, { r: [.03, .05, .05, .05, .05, .04, .008] });
  // 안의 사람 두 팔: 테두리를 움켜쥠
  for (const m of [-1, 1]) { const s = [m * .85, yb + 1.0, -1.35], e = [m * 1.35, yb + .95, -.3], wr = [m * 1.38, by + 1.05, .75]; A.arm(B, s, e, wr, .2, { m: .85 }); A.hand(B, new Frame(wr, V.norm([0, 0, 1]), V.norm([m * .95, -.1, .2]), V.norm([.1 * m, 1, 0])), 1.25, { curl: [60, 66, 62, 70], spread: 8, thin: .9, len: 1.15 }); }
  // 물에서 뻗어 나온 다른 손들(앞쪽)
  for (const [x, z, h, yw, sc] of [[-.5, 1.4, .9, -.5, 1.05], [.25, 1.75, 1.25, .2, 1.15], [.75, 1.0, .6, .7, .9], [-.85, .55, .55, -.8, .85]]) { const wr = [x * 1.1, by + .5 + h, z + .15]; B.group({ k: .08, kg: .1 }); B.tube([[x, by + .2, z], [x * 1.1, by + .4 + h * .5, z - .05], wr], [.15, .14, .11]); B.group({ k: .03, kg: .03 }); for (let i = 0; i < 10; i++) { const a = i / 10 * 6.283; B.ball([x + Math.cos(a) * .2, by + .45, z + Math.sin(a) * .2], .05); } const Y = V.norm([yw * .5, 1, .35]), X = V.norm(V.cross(Y, [0, 0, 1])); A.hand(B, new Frame(wr, X, Y, V.cross(X, Y)), sc, { curl: [20, 34, 26, 40], spread: 16, thin: .88, len: 1.15 }); }
  // 다리 = 거대한 사람 손 넷(발톱 욕조 다리 자리)
  const L = [[1, 1], [-1, 1], [1, -1], [-1, -1]]; L.forEach(([sx, sz], i) => { const q = Math.sin((w + [0, .5, .75, .25][i]) * 6.283), lf = Math.max(0, q) * .35; const a = [sx * 1.05, by - .55, sz * 1.55], e = [sx * 1.95, by - .45 + lf * .4, sz * 1.95 + q * .2], wr = [sx * 1.75, .55 + lf, sz * 2.0 + .1 + q * .45]; A.arm(B, a, e, wr, .4, { m: 1.0 }); const Y = V.norm([sx * .3, -.3, .9]), X = V.norm([-sx, 0, .3 * sx * sx * sx]); A.hand(B, new Frame(wr, V.norm([-sx * .95, 0, .3]), Y, V.norm([0, 1, .25])), 1.75, { curl: [16, 20, 18, 24], spread: 16, thin: .95, len: 1.05 }); });
  // 수도꼭지 = 앞쪽에 박힌 목뼈와 벌린 입(붉은 물)
  const tp = [[0, by + .5, 2.3], [0, by + 1.25, 2.35], [0, by + 1.65, 2.0], [0, by + 1.5, 1.6]]; B.group({ k: .04, kg: .08 }); B.tube(tp, [.17, .15, .14, .13]); A.rings(B, tp, 9, .03, .04, .3, { bow: 0, tilt: .05 }); for (const m of [-1, 1]) { B.group({ k: .03 }); B.cone([0, by + .85, 2.4], [m * .5, by + .95, 2.4], .07, .07); for (const u of [-1, 0, 1]) B.cone([m * .5, by + .95 + u * .0, 2.4], [m * .52, by + .95 + Math.cos(u * 2.1) * .22, 2.4 + Math.sin(u * 2.1) * .22], .06, .05); }
  B.group({ mat: 1, k: .02 }); B.tube([[0, by + 1.45, 1.6], [.02, by + 1.1, 1.56], [0, by + .75, 1.58], [.03, by + .45, 1.55]], [.09, .06, .05, .06]);
  return B;
} };
