// 시안3 7장 비인간형 — 풍금: 이빨이 건반이고 목구멍들이 파이프인 풍금. 여섯 개의 사람 팔로 교실 바닥을 기며, 안에서 손이 나와 스스로를 연주한다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'e7n', name: '풍금', kind: '비인간형 · 7장 폐교', H: 8.2, build(p = {}) {
  const B = new Body(), w = p.walk ?? .1, gp = p.gape ?? 1, I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]);
  // 몸통: 등받이가 솟은 살덩이 (풍금 실루엣)
  B.group({ k: .3, kg: .2, amp: .02, freq: 2, rid: .002, rf: 1.6 }); B.box(I([0, 3.6, -.75]), [2.1, 1.6, .7], .5); B.box(I([0, 2.35, .2]), [2.2, .65, 1.15], .5); B.ell(I([0, 3.0, -1.3]), [1.9, 1.4, .7]); for (const m of [-1, 1]) B.ell(I([m * 2.0, 2.7, .6]), [.5, .75, .8]);
  // 건반 입: 앞으로 튀어나온 위·아래 턱
  B.box(I([0, 3.0, 1.05]), [1.95, .56 * gp, .9], .2, { op: 1, k: .12 });
  B.group({ mat: 2, k: .02 }); B.box(I([0, 3.0, .25]), [1.85, .52 * gp, .35], .15);
  B.group({ k: .07, kg: .18, amp: .01, freq: 5 }); for (const u of [1, -1]) { const pts = []; for (let i = 0; i <= 18; i++) { const t = i / 18 * 2 - 1; pts.push([t * 2.1, 3.0 + u * ((u > 0 ? .62 : .72) * gp + .05 * Math.sin(i * 2.1)) * Math.sqrt(Math.max(.05, 1 - t ** 6)), 1.2 + .18 * (1 - t * t) + (u < 0 ? .12 : 0)]); } B.tube(pts, .17); B.tube(pts.map(q => [q[0] * .97, q[1] - u * .12, q[2] - .06]), .12, { per: 1 }); }
  // 이빨 건반: 흰 건반(아랫니, 길게 앞으로), 검은 건반(사이 썩은 이), 윗니
  B.group({ mat: 4, k: .004 }); for (let i = 0; i < 20; i++) { const x = -1.8 + i * .189, push = [3, 8, 9, 14].includes(i) ? -.1 : 0; B.box(I([x, 2.72 - .05 * gp + push, 1.36 + .07 * Math.sin(i * 2.7)]).rot(-4 + push * 90, 2 * Math.sin(i * 3), 0), [.084, .13, .56], .05, { k: .01 }); } for (let i = 0; i < 20; i++) { const x = -1.75 + i * .184, L = .2 + .1 * Math.abs(Math.sin(i * 3.3)); B.tube([[x, 3.6, 1.25], [x + .01, 3.46 - L * .5, 1.31], [x, 3.44 - L, 1.27]], [.1, .085, .03], { per: 2 }); }
  B.group({ mat: 0, k: .01 }); for (let i = 0; i < 19; i++) { if (i % 7 === 2 || i % 7 === 6) continue; const x = -1.705 + i * .189; B.box(I([x, 2.88 - .05 * gp, 1.15]).rot(-6, 0, 0), [.05, .13, .34], .03); }
  // 잇몸 주름
  B.group({ k: .05, kg: .1 }); for (let i = 0; i < 20; i++) { const x = -1.8 + i * .189; B.ell(I([x, 2.55, 1.42]), [.08, .12, .09]); }
  // 붉은: 건반 사이로 흘러 아래로 떨어지는 줄기
  B.group({ mat: 1, k: .03 }); B.tube([[.48, 2.95, 1.5], [.47, 2.7, 1.85], [.5, 2.2, 1.8], [.46, 1.7, 1.6], [.5, 1.2, 1.5]], [.07, .08, .06, .045, .01]); B.tube([[.66, 2.7, 1.85], [.68, 2.3, 1.8], [.65, 1.95, 1.7]], [.05, .04, .01]);
  // 파이프 = 목구멍(위로 솟은 기관들), 끝마다 벌린 입
  const PN = 9; for (let i = 0; i < PN; i++) { const u = i / (PN - 1) - .5, x = u * 3.7, h = 5.6 + 2.1 * Math.cos(u * 3.0) * (.85 + .15 * Math.sin(i * 2.7)), lean = u * .5, r = .24 + .05 * Math.sin(i * 1.9), z = -.85 + .12 * Math.sin(i * 2.2); const top = [x + lean, h - .6, z + .05], pts = [[x, 4.4, z], [x + lean * .4, (4.4 + h) / 2 - .2, z - .08], top]; B.group({ k: .05, kg: .2 }); B.tube(pts, [r * 1.15, r, r * 1.1]); A.rings(B, pts, 6 + (i % 4), .035, .04, r * 1.9, { tilt: .06, bow: 0, wob: .04 }); const s = r * 4.1, HF = I([top[0], top[1] + s * .42, top[2] + .08]).rot(-22 + 10 * Math.sin(i * 2), u * -20 + (p.headYaw || 0) * .5, u * -22 + 8 * Math.sin(i * 3)); A.face(B, HF, s, { jaw: (p.sing ?? 1) * [46, 30, 52, 20, 50, 34, 48, 26, 44][i], eyes: ['empty', 'sewn', 'real', 'empty', 'real', 'shut', 'empty', 'sewn', 'empty'][i], gaunt: 1.1, teeth: 8, ears: false, kg: .16, w: .92, rid: 0, vein: false }); }
  // 등받이에 눌려 떠오른 얼굴·손
  for (const [x, y, s, r, j] of [[-1.15, 4.25, 1.25, 14, 34], [.1, 4.45, 1.1, -10, 18], [1.2, 4.15, 1.3, -20, 44]]) A.face(B, I([x, y, -.22]).rot(-4, x * 6 + (p.headYaw || 0) * .3, r), s, { jaw: j, eyes: 'shut', gaunt: 1, teeth: 8, ears: false, kg: .35 });
  for (const [x, y, t] of [[-.5, 4.0, .5], [.62, 3.95, -.4], [-1.75, 4.3, -.2], [1.8, 4.6, .3]]) { const Y = V.norm([t, 1, .25]), X = V.norm(V.cross(Y, [0, 0, 1])); A.hand(B, new Frame([x, y - .45, -.15], X, Y, V.cross(X, Y)), .85, { curl: 14, spread: 18, thin: .85, vein: 0, kg: .2 }); }
  // 건반을 치는 안쪽 손 둘
  for (const m of [-1, 1]) { const wr = [m * .85, 3.22, .95 + .1 * m]; B.group({ k: .07, kg: .1 }); B.tube([[m * .6, 3.1, .1], [m * .75, 3.32, .55], wr], [.16, .14, .12]); A.hand(B, new Frame(wr, V.norm([-m, 0, 0]), V.norm([m * .06, -.28, 1]), V.norm([0, 1, .28])), 1.15, { curl: [26, 34, 22, 38], spread: 14, thin: .85, len: 1.25 }); }
  // 옆구리에 박힌 얼굴 하나씩
  for (const m of [-1, 1]) { const HF = new Frame([m * 2.2, 3.55, -.1], V.norm([.35, 0, -m * .94]), [0, 1, 0], V.norm([m * .94, 0, .35])).rot(0, 0, m * 24); A.face(B, HF, 1.25, { jaw: 20, eyes: m > 0 ? 'real' : 'shut', gaunt: 1, teeth: 8, ears: false, kg: .3 }); }
  // 다리 = 팔 여섯
  for (const m of [-1, 1]) for (let i = 0; i < 3; i++) { const q = Math.sin((w + i * .33 + (m > 0 ? .5 : 0)) * 6.283), lf = Math.max(0, q) * .45, t = i - 1; const a = [m * 1.85, 2.2, .55 - i * .85], e = [m * (3.0 + .1 * Math.sin(i)), 2.35 + lf * .5, .9 - i * 1.15 + q * .2], wr = [m * (2.85 + .15 * i % .3), .34 + lf, 1.6 - i * 1.6 + q * .5]; A.arm(B, a, e, wr, .32, { m: .9 }); A.hand(B, new Frame(wr, V.norm([-m, 0, .1]), V.norm([m * .3, -.12, .95 - i * .4]), [0, 1, 0]), 1.4, { curl: 11, spread: 15, thin: .9, len: 1.15 }); }
  // 바람통(풀무) 주름이 양옆 아래
  for (const m of [-1, 1]) { B.group({ k: .05, kg: .1 }); for (let i = 0; i < 6; i++) B.box(new Frame([m * (1.0 + .02 * i), 1.95 - i * .16, .15], [1, 0, 0], V.norm([0, 1, .1 * Math.sin(i)]), [0, 0, 1]), [.62 - (i % 2) * .1, .075, .6 - (i % 2) * .1], .06); }
  return B;
} };
