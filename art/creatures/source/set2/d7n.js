// 시안2 7장 비인간형 — 정글짐: 놀이터 정글짐 쇠틀에 온몸이 꿰여 엉킨 아이들. 틀이 주사위처럼 넘어지며 굴러 오고, 칸마다 다른 손과 얼굴이 나온다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'd7n', name: '정글짐', kind: '비인간형 · 7장 학교', H: 6.2, build(p = {}) {
  const B = new Body(), tp = (p.tip || 0) * 90, G = 1.75, N = 3, L = G * N; const piv = new Frame([0, .12, tp > 0 ? L / 2 : 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]).rot(tp, 0, 0), C = tp > 0 ? piv.at([0, L / 2, -L / 2]) : new Frame([0, L / 2 + .12, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]); const c = (i, j, k) => C.p([(i - N / 2) * G, (j - N / 2) * G, (k - N / 2) * G]);
  // 쇠틀(바깥 모서리와 몇 개의 안쪽 봉, 일부는 휘어짐)
  const bar = (a, b, r, bend) => { B.group({ k: .02, kg: .01 }); bend ? B.tube([a, V.add(V.lerp(a, b, .5), bend), b], r, { per: 4 }) : B.cone(a, b, r, r); };
  for (let a = 0; a <= N; a++) for (let b2 = 0; b2 <= N; b2++) { const edge = (a === 0 || a === N) && (b2 === 0 || b2 === N), face = a === 0 || a === N || b2 === 0 || b2 === N; if (!edge && !face) continue; const bd = !edge && (a + b2) % 3 === 1 ? C.d([.12, .16 * Math.sin(a * 3 + b2), .14]) : null; const r = edge ? .085 : .065; bar(c(a, b2, 0), c(a, b2, N), r, bd); bar(c(a, 0, b2), c(a, N, b2), r, bd); bar(c(0, a, b2), c(N, a, b2), r, bd); }
  for (let i = 0; i <= N; i += N) for (let j = 0; j <= N; j += N) for (let k = 0; k <= N; k += N) { B.group({ k: .03 }); B.ball(c(i, j, k), .15); }
  // 가운데 긴 몸: 틀 사이를 뱀처럼이 아니라 매듭처럼 통과(가슴이 앞면 가운데)
  const X = C.x, Y = C.y, Z = C.z, P = (x, y, z) => C.p([x, y, z]);
  A.torso(B, new Frame(P(0, .25, 1.55), X, V.norm(V.add(Y, V.mul(Z, .25))), V.norm(V.add(Z, V.mul(Y, -.25)))), { w: .72, d: .48, h: 1.5, n: 8, r: .05 }); B.group({ k: .18, kg: .25, amp: .008, freq: 4 }); B.tube([P(0, -.4, 1.35), P(.25, -1.05, .7), P(.6, -1.0, -.3), P(.4, -.2, -1.1)], [.5, .42, .4, .46]); A.rings(B, [P(0, -.5, 1.3), P(.6, -1.0, -.2)], 8, .024, .05, .8, { tilt: .15 });
  // 팔다리: 칸마다 뻗어 나와 봉을 쥐거나 바닥을 짚음
  const lim = (s, e, wr, dir, up, o = {}) => { A.arm(B, P(...s), P(...e), P(...wr), o.r || .18, { m: .9 }); const D = C.d(V.norm(dir)), U = C.d(V.norm(up)); const F = Frame.along(P(...wr), D, U); A.hand(B, new Frame(P(...wr), F.x, D, F.z), 1.12, { curl: o.curl ?? 55, spread: o.sp ?? 8, thin: .88 }); };
  lim([.8, .85, 1.6], [1.75, 1.35, 2.2], [1.0, 2.35, 2.55], [-.3, .9, .2], [-.2, 0, 1], { curl: 48, r: .22 }); lim([-.8, .85, 1.6], [-1.95, .55, 2.1], [-2.3, -.55, 2.75], [-.2, -1, .1], [0, 0, 1], { curl: 46, r: .22 });
  lim([-.6, -.6, 0], [-2.2, -1.2, .4], [-3.0, -2.3, .9], [-.5, -.5, .4], [0, 1, .2], { curl: 10, sp: 14 }); lim([.9, -.3, -.2], [2.2, .1, .3], [3.1, .9, .3], [.7, .6, .3], [0, 1, 0], { curl: [8, 14, 10, 18], sp: 14 }); lim([.2, .9, -.6], [-.4, 2.1, -.2], [-.9, 3.2, .4], [-.3, .9, .3], [0, 0, 1], { curl: [6, 12, 10, 16], sp: 14 }); lim([-.3, -.8, .8], [-.8, -1.7, 1.7], [-.6, -2.2, 2.75], [.1, -.5, .85], [0, 1, .3], { curl: 10, sp: 13 }); lim([.6, .2, -1.0], [1.4, 1.6, -1.4], [2.0, 2.7, -1.0], [.3, .9, .2], [1, 0, 0], { curl: 40 });
  const leg = (h, k, a, fr, toe) => { A.leg(B, P(...h), P(...k), P(...a), .25, { m: .9, front: C.d(fr) }); A.foot(B, new Frame(P(...a), C.x, C.d([0, .5, .3]), C.d(V.norm(toe))), .95, {}); }; leg([.4, -.5, -1.1], [1.8, -1.4, -1.2], [2.6, -2.35, -.4], [.5, .3, .5], [.6, -.3, .6]); leg([.1, -.4, -1.1], [-1.2, .6, -1.7], [-2.5, .3, -1.6], [0, 1, 0], [-.8, -.3, .3]);
  // 얼굴 셋: 앞면 가운데 큰 얼굴, 위 칸, 옆 칸
  A.neck(B, P(0, 1.05, 1.75), P(.1, 1.45, 2.15), .2, { front: Z }); A.head(B, new Frame(P(.12, 1.75, 2.45), X, V.norm(V.add(Y, V.mul(Z, -.1))), Z).rot(6, p.headYaw || 0, -24), 1.35, { jaw: 36, gaunt: 1.1, eyes: 'pin', pin: .016, eyeSize: 1.15, nose: 'human', teeth: 10 });
  A.head(B, new Frame(P(-1.4, .95, 1.9), V.norm(V.add(X, V.mul(Y, .4))), V.norm(V.add(Y, V.mul(X, -.4))), Z), 1.0, { jaw: 8, gaunt: 1, eyes: 'hollow', nose: 'human', teeth: 7 }); A.neck(B, P(-.5, .4, .9), P(-1.25, .6, 1.6), .16, { front: Z });
  A.head(B, new Frame(P(1.55, -.85, 2.0), V.norm(V.add(X, V.mul(Y, -.8))), V.norm(V.add(Y, V.mul(X, .8))), Z), .95, { jaw: 26, gaunt: .8, eyes: 'skin', nose: 'human', teeth: 7 }); A.neck(B, P(.5, -.7, 1.0), P(1.35, -.8, 1.65), .15, { front: Z });
  // 붉은 줄넘기: 봉에 감겨 늘어짐
  B.group({ mat: 1, k: .01 }); B.tube([P(-2.5, 2.62, 2.55), P(-2.1, 1.9, 2.85), P(-1.2, 1.5, 2.95), P(-.4, 1.95, 2.9), P(.3, 2.62, 2.62)], .045);
  return B;
} };
