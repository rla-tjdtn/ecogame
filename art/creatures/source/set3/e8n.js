// 시안3 8장 비인간형 — 미끄럼틀: 거대한 머리를 젖혀 벌린 입에서 혀가 미끄럼틀처럼 내려온다. 뒤는 갈비 사다리, 다리는 쇠기둥처럼 마른 아이 팔 여섯.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'e8n', name: '미끄럼틀', kind: '비인간형 · 8장 놀이터', H: 9.2, build(p = {}) {
  const B = new Body(), w = p.walk ?? .1, gp = p.gape ?? 1, I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]);
  // 머리: 위에서 입이 앞을 향해 크게 벌어짐
  const HF = new Frame([0, 7.0, -1.2], [1, 0, 0], V.norm([0, .96, -.28]), V.norm([0, .28, .96])).rot(-6, p.headYaw || 0, 0); const J = A.face(B, HF, 4.2, { jaw: 24 + 30 * gp, eyes: 'real', gaunt: 1.2, teeth: 16, mouthW: 1.45, w: 1.15, iris: .011, kg: .3, age: 1, rf: 5 });
  // 혀 미끄럼틀: 가운데 골, 양옆 난간처럼 말림
  const M = v => HF.p(V.mul(v, 4.2)), pts = [M([0, -.36, .06]), M([0, -.4, .3]), [0, 4.75, 1.45], [0, 3.5, 2.45], [.03, 2.0, 3.45], [0, .95, 4.4], [0, .42, 5.4], [0, .3, 6.3]];
  const cr = (t) => { const n = pts.length - 1, u = Math.min(n - 1e-4, t * n), k = Math.floor(u), f = u - k, g = q => pts[Math.max(0, Math.min(n, q))], a = g(k - 1), b = g(k), c = g(k + 1), d = g(k + 2); return [0, 1, 2].map(x => .5 * (2 * b[x] + (c[x] - a[x]) * f + (2 * a[x] - 5 * b[x] + 4 * c[x] - d[x]) * f * f + (3 * b[x] - a[x] - 3 * c[x] + d[x]) * f * f * f)); };
  const N = 60, Q = []; for (let k = 0; k <= N; k++) { const t = k / N, a = cr(t), d = V.norm(V.sub(cr(Math.min(1, t + .01)), cr(Math.max(0, t - .01)))), up = V.norm(V.cross([1, 0, 0], d)), ww = (.5 + .34 * Math.min(1, t * 5) - t * t * .3); Q.push([a, d, up[2] < 0 && up[1] < 0 ? V.mul(up, -1) : up, ww, t]); }
  B.group({ mat: 1, k: .16 }); for (let l = -3; l <= 3; l++) B.tube(Q.map(([a, d, up, ww], k) => V.add(a, V.add([l / 3 * ww, 0, 0], V.mul(up, .02 * Math.sin(k * .7 + l * 2))))), .13);
  for (const m of [-1, 1]) B.tube(Q.map(([a, d, up, ww]) => V.add(a, V.add([m * ww, 0, 0], V.mul(up, -.16)))), .16, { k: .08 });
  B.tube(Q.slice(4).map(([a, d, up]) => V.add(a, V.mul(up, -.12))), .035, { op: 1, k: .08 }); for (let k = 0; k < 40; k++) { const [a, d, up, ww] = Q[8 + k]; B.ball(V.add(a, V.add([Math.sin(k * 4.7) * ww * .7, 0, 0], V.mul(up, -.13))), .06 + .025 * Math.sin(k * 2.3), { k: .04 }); }
  // 목에서 이어지는 갈비 사다리 (뒤)
  const L0 = [0, 5.6, -1.9], L1 = [0, .3, -4.6]; for (const m of [-1, 1]) { const q = [[m * .5, 5.9, -1.7], [m * .85, 4.8, -2.35], [m * .95, 2.6, -3.4], [m * 1.0, .12, -4.6]]; B.group({ k: .08, kg: .3 }); B.tube(q, [.3, .22, .18, .14]); A.spine(B, q, .13, { n: 18, back: [m, .3, -.4], out: .05, k: .03, kg: .05 }); }
  for (let i = 0; i < 8; i++) { const t = (i + .8) / 8.6, c = V.lerp(L0, L1, t), ww = .78 + t * .2; B.group({ k: .03, kg: .08 }); B.tube([V.add(c, [-ww, 0, 0]), V.add(c, [-ww * .45, -.06, .12]), V.add(c, [0, .03, .14]), V.add(c, [ww * .45, -.06, .12]), V.add(c, [ww, 0, 0])], [.1, .12, .1, .12, .1]); }
  // 사다리를 오르는 아이 손들
  for (const [i, x, r] of [[1, -.4, .9], [3, .35, 1], [5, -.3, .9], [2, .5, .85]]) { const t = (i + .8) / 8.6, c = V.add(V.lerp(L0, L1, t), [x, .06, -.1]); const wr = V.add(c, [0, -.5, -.35]); B.group({ k: .06, kg: .03 }); B.tube([V.add(wr, [0, -.8, -.1]), V.add(wr, [.05, -.35, -.15]), wr], [.03, .1, .1]); A.hand(B, new Frame(wr, V.norm([1, 0, 0]), V.norm([0, .8, .6]), V.norm([0, -.6, .8])), r * .85, { curl: [50, 56, 52, 58], spread: 8, thin: .95, vein: 0 }); }
  // 목·어깨 혹
  B.group({ k: .4, kg: .6, amp: .02, freq: 2, rid: .004, rf: 2 }); B.ell(I([0, 5.6, -1.9]), [1.25, 1.0, .9]); for (const m of [-1, 1]) B.ell(I([m * 1.0, 5.2, -1.7]), [.75, .6, .6]);
  // 다리: 가는 팔 여섯
  for (const m of [-1, 1]) for (let i = 0; i < 3; i++) { const q = Math.sin((w + i * .33 + (m > 0 ? .5 : 0)) * 6.283), lf = Math.max(0, q) * .5; const a = [m * 1.2, 5.0 - i * .15, -1.3 - i * .45], e = [m * (2.55 + .2 * i), 3.9 + lf * .4, -.3 - i * 1.1 + q * .2], wr = [m * (2.3 + .25 * i), .34 + lf, .8 - i * 1.7 + q * .5]; A.arm(B, a, e, wr, .3, { m: .85 }); A.hand(B, new Frame(wr, V.norm([-m, 0, .1]), V.norm([m * .35, -.12, .9 - i * .6]), [0, 1, 0]), 1.35, { curl: 10, spread: 15, thin: .92 }); }
  // 정수리 머리카락: 젖은 채 뒤로
  const R = []; for (let i = 0; i < 70; i++) { const u = i / 69 - .5, j = Math.sin(i * 5.3); R.push([HF.p([u * 1.6, 1.85 - u * u * 1.6, .2 - .2 * Math.abs(j)]), HF.p([u * 2.7, 1.5 - u * u * 2, -1.1]), HF.p([u * 3.2, .3 - Math.abs(j) * .2, -1.9]), V.add(HF.p([u * 3.4 + j * .1, -.6, -1.9]), [0, -.8 - .6 * Math.abs(j), 0])]); } A.hair(B, R, { r: [.06, .07, .05, .01] });
  return B;
} };
