// 시안3 9장 비인간형 — 압축: 폐차 압축기에 눌려 정육면체가 된 사람들. 면마다 눌린 얼굴과 손바닥이 박혀 있고, 삐져나온 팔다리로 굴러 면을 바꾼다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'e9n', name: '압축', kind: '비인간형 · 9장 고가도로', H: 6.8, build(p = {}) {
  const B = new Body(), w = p.walk ?? .1, I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]);
  const C = I([0, 3.5 + (p.lift || 0), 0]).rot(p.roll || 0, 0, p.cant ?? 3), h = 1.9, c = v => C.p(v), D = v => V.norm(C.d(v));
  // 덩어리 본체
  B.group({ k: .25, kg: .1, amp: .03, freq: 1.6, rid: .004, rf: 1.5 }); B.box(C, [h, h, h], .28);
  // 면 다섯: 앞·뒤·좌·우·위. 면 좌표 (u,v,밖)
  const F = [[[1, 0, 0], [0, 1, 0], [0, 0, 1]], [[-1, 0, 0], [0, 1, 0], [0, 0, -1]], [[0, 0, -1], [0, 1, 0], [1, 0, 0]], [[0, 0, 1], [0, 1, 0], [-1, 0, 0]], [[1, 0, 0], [0, 0, -1], [0, 1, 0]]];
  F.forEach(([ux, vy, n], fi) => { const at = (u, v, o) => c(V.add(V.add(V.mul(ux, u), V.mul(vy, v)), V.mul(n, h + o))), U = D(ux), Vv = D(vy), N = D(n); const rnd = k => Math.sin(k * 12.9898 + fi * 78.2) * 43758.5453 % 1;
    // 접히고 눌린 팔다리·몸통이 면을 빽빽이 채움
    const limbs = [[-1.6, 1.45, -.3, 1.55, .9, 1.2, .34], [1.6, .9, 1.45, -.4, .9, -1.1, .36], [-1.65, -.2, -1.5, -1.5, -.6, -1.6, .34], [-.2, -1.55, 1.0, -1.45, 1.6, -1.6, .28], [.3, 1.7, 1.2, 1.5, 1.7, 1.75, .26], [-1.7, .9, -1.0, .35, -1.6, -.1, .26]];
    limbs.forEach(([a, b, d, e, f, g, r], i) => { const s = fi % 2 ? -1 : 1; B.group({ k: .06, kg: .08, amp: .006, freq: 4 }); const pts = [at(a * s, b, -.12), at(d * s, e, .02), at(f * s, g, -.12)]; B.tube(pts, [r * .8, r, r * .8]); B.ball(V.add(pts[1], V.mul(N, .02)), r * 1.02, { k: .1 }); for (let q = 0; q < 2; q++) B.groove(V.lerp(pts[q], pts[q + 1], .5), V.norm(V.add(V.sub(pts[q + 1], pts[q]), V.mul(N, .4))), .02, .035, r * 1.2, { wob: .15, wf: 4 }); });
    // 갈비통 하나
    if (fi !== 4) { const cu = [.95, -.9, .9, -.95][fi] , cv = [.15, .1, -.1, .2][fi]; B.group({ k: .03, kg: .06 }); for (let i = 0; i < 6; i++) B.tube([at(cu - .55, cv + .6 - i * .22, .0), at(cu, cv + .66 - i * .22, .18), at(cu + .55, cv + .56 - i * .22, .0)], [.06, .075, .05]); }
    // 큰 눌린 얼굴
    const fs = [[[-.45, .15, 2.3, 8, 40, 'real'], [.95, -1.05, 1.25, -70, 10, 'shut']], [[.3, .1, 2.0, -24, 20, 'empty'], [-1.0, 1.0, 1.2, 90, 30, 'real']], [[.35, .35, 1.9, 20, 30, 'real'], [-.95, -.95, 1.3, 170, 44, 'empty']], [[-.2, -.1, 2.1, -100, 34, 'real'], [1.0, 1.0, 1.1, 30, 8, 'sewn']], [[-.5, .4, 1.8, 40, 44, 'real'], [.8, -.7, 1.3, -60, 20, 'shut']]][fi];
    fs.forEach(([u, v, s, rz, jaw, eyes], j) => { const G = new Frame(at(u, v, -.12 - s * .05), U, Vv, N).rot(0, 0, rz); A.face(B, G, s, { jaw: j === 0 && fi === 0 ? (p.jaw ?? jaw) : jaw, eyes, gaunt: 1.0, teeth: 10, w: 1.12, ears: false, kg: .2, gaze: [0, 0] }); });
    // 눌린 손바닥
    const hs = [[1.15, 1.15, 1.15, 30], [-1.25, -1.1, 1.1, 160]]; hs.forEach(([u, v, s, rz], j) => { const a = rz * Math.PI / 180 + fi, Y = V.norm(V.add(V.mul(U, -Math.sin(a)), V.mul(Vv, Math.cos(a)))), X = V.norm(V.cross(Y, N)); A.hand(B, new Frame(at(u, v, .02), X, Y, N), s, { curl: 4, spread: 20, thin: .95, kg: .1 }); });
  });
  // 모서리를 조인 쇠띠 둘 + 찢긴 쇳조각
  for (const x of [-.75, 1.05]) { const q = []; const e = h + .12; for (const [y, z] of [[-e, -e], [-e, e], [e, e], [e, -e], [-e, -e]]) q.push([x + .08 * Math.sin(y * 3 + z), y, z]); B.group({ k: .01, kg: .02 }); for (let i = 0; i < 4; i++) { const a = q[i], b = q[i + 1], d = V.norm(V.sub(b, a)), n = V.norm([0, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2]); B.box(new Frame(c(V.lerp(a, b, .5)), D([1, .02, 0]), D(d), D(n)), [.13, V.len(V.sub(b, a)) * .51, .05], .02); } for (let i = 0; i < 4; i++) B.ball(c([x, e - .3 - i * .9, e + .05]), .06); }
  B.group({ k: .01, kg: .04 }); for (let i = 0; i < 9; i++) { const a = i * 2.4, sx = Math.sign(Math.sin(a * 3)) || 1, sy = Math.sin(a * 1.7), sz = Math.sign(Math.cos(a)) || 1; const b = [sx * h * .95, sy * 1.7, sz * h * .9]; const e = V.add(b, [sx * (.5 + .3 * Math.sin(i)), .2 * Math.cos(i * 2), sz * (.35 + .2 * Math.cos(i * 3))]); B.cone(c(b), c(e), .09, .01); B.ell(new Frame(c(V.lerp(b, e, .4)), D([0, 1, 0]), D(V.norm(V.sub(e, b))), D([1, 0, 0])), [.2, .3, .03], { k: .02 }); }
  // 붉은: 박힌 채 깜박이는 깨진 미등
  B.group({ k: .03 }); B.box(c === 0 ? C : C.at([1.22, -.55, h + .05]).rot(0, 0, -14), [.5, .26, .14], .06); B.group({ mat: 1, k: .02 }); B.box(C.at([1.22, -.55, h + .13]).rot(0, 0, -14), [.4, .17, .1], .05); B.group({ k: .01 }); for (let i = 0; i < 4; i++) B.cone(c([.95 + i * .2, -.3, h + .26]), c([1.05 + i * .12, -.82, h + .25]), .014, .014);
  // 삐져나온 팔다리: 아래 여섯으로 걷고 옆·위는 휘젓는다
  const G = [[1, 1], [-1, 1], [1, -1], [-1, -1], [1, 0], [-1, 0]]; G.forEach(([sx, sz], i) => { const q = Math.sin((w + i * .17 + (sx > 0 ? .5 : 0)) * 6.283), lf = Math.max(0, q) * .4; const a = c([sx * 1.35, -h + .15, sz * 1.25]), k = [sx * (2.4 + .15 * Math.sin(i * 3)), 2.0 + lf * .5 + .3 * Math.sin(i * 2), sz * 1.95 + q * .2 + (sz ? 0 : .2)], e = [sx * (2.3 + .25 * Math.cos(i)), .34 + lf, sz * 2.3 + q * .5]; if (i % 3 === 1) { A.leg(B, a, k, e, .32, { m: .85, front: [sx * .6, 0, sz || 1] }); A.foot(B, new Frame(e, [1, 0, 0], [0, 1, 0], V.norm([sx * .6, 0, sz || .6])), 1.2, {}); } else { A.arm(B, a, k, e, .28, { m: .9 }); A.hand(B, new Frame(e, V.norm([-sx, 0, .15 * sz]), V.norm([sx * .4, -.12, sz || .6]), [0, 1, 0]), 1.25, { curl: 11, spread: 15, thin: .9 }); } });
  for (const [a, b, d, s, sp2] of [[[1.4, 1.5, .9], [2.6, 2.5, 1.4], [2.9, 1.5, 2.5], 1.2, 0], [[-1.5, 1.6, .2], [-2.4, 2.9, .5], [-2.1, 4.0, 1.2], 1.15, 1], [[.6, 1.7, -.8], [1.0, 2.9, -1.4], [.4, 3.7, -1.1], 1.0, 2]]) { const wr = c(d), e = c(b); A.arm(B, c(a), e, wr, .22, { m: .85 }); const Y = V.norm(V.add(V.norm(V.sub(wr, e)), [0, 0, .25])), X = V.norm(V.cross(Y, [.2, .1, 1])); A.hand(B, new Frame(wr, X, Y, V.cross(X, Y)), s, { curl: [12, 26, 18, 34], spread: 16, thin: .86, len: 1.2 }); }
  return B;
} };
