// 7장 비인간형 — 저요: 서로 손을 들다 하나로 뭉친 아이들. 수십 개의 팔로 굴러다니는 공 한가운데 큰 입 하나가 이름을 부른다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'c7n', name: '저요', kind: '비인간형 · 7장 학교', H: 6.4, build(p = {}) {
  const B = new Body(), roll = p.roll || 0, c = [0, 3.05, 0], R0 = 1.25; const rx = v => { const a = roll * Math.PI * 2, y = v[1] * Math.cos(a) - v[2] * Math.sin(a), z = v[1] * Math.sin(a) + v[2] * Math.cos(a); return [v[0], y, z]; };
  // 살덩이: 어깨·등·머리통이 뭉친 공
  B.group({ k: .35, kg: .2, amp: .02, freq: 2 }); B.ball(c, R0 * .92); const N = 22, dirs = []; for (let i = 0; i < N; i++) { const y = 1 - (i + .5) / N * 2, r = Math.sqrt(1 - y * y), a = i * 2.399963; dirs.push([Math.cos(a) * r, y, Math.sin(a) * r]); }
  dirs.forEach((d, i) => { const n = rx(d); B.ell(Frame.along(V.add(c, V.mul(n, R0 * .82)), n), [.46, .42, .46], { k: .2 }); if (i % 3 === 1) B.tube([V.add(c, V.mul(n, R0 * 1.0)), V.add(c, V.mul(rx(V.norm(V.add(d, [.4, .2, .1]))), R0 * 1.18)), V.add(c, V.mul(rx(V.norm(V.add(d, [.8, .3, .1]))), R0 * .98))], [.1, .12, .09], { k: .12 }); });
  for (let i = 0; i < 14; i++) B.groove(V.add(c, V.mul(rx(dirs[i]), R0)), rx([Math.sin(i * 3), Math.cos(i * 5), Math.sin(i * 7)]), .022, .04, .8, { bow: .3, wob: .4, wf: 2 });
  // 큰 얼굴: 공 앞면 가득, 이름을 부르며 벌어진 입
  { const F = new Frame(V.add(c, rx([0, .1, .72])), [1, 0, 0], rx([0, 1, 0]), rx([0, 0, 1])); A.head(B, F, 2.55, { jaw: p.jaw ?? 36, gaunt: .5, eyes: 'hollow', eyeSize: 1.1, eyeH: .075, eyeTilt: -24, nose: 'human', teeth: 14, toothLen: .05, ears: false, kg: .3, w: 1.1, mouthW: 1.25, mouthMat: 2 }); B.group({ mat: 1, k: .05 }); B.tube([F.p([0, -1.0, .35]), F.p([.06, -1.12, .6]), F.p([-.03, -1.28, .78])], [.16, .17, .06]); }
  // 작은 얼굴 셋(눈 감은 아이들)
  for (const [d, s] of [[[.85, .45, .35], .72], [[-.75, -.25, .62], .7], [[-.45, .85, .25], .66], [[.6, -.7, .4], .62]]) { const n = rx(V.norm(d)), F = Frame.along(V.add(c, V.mul(n, R0 * 1.02)), rx([0, 1, .1]), n); A.head(B, F, s * 1.25, { jaw: 0, gaunt: 0, eyes: 'skin', nose: 'human', ears: false, kg: .18, wrinkle: false }); }
  // 팔: 아래 것들은 바닥을 짚고, 나머지는 위로 뻗어 손을 듦
  const M = 17; for (let i = 0; i < M; i++) { const y = .96 - i / (M - 1) * 1.92, r = Math.sqrt(1 - y * y), a = i * 2.399963 + .7; let d = [Math.cos(a) * r, y, Math.sin(a) * r]; let n = rx(d); if (n[2] > .78 && Math.abs(n[1]) < .5) { n = V.norm([n[0] + (n[0] >= 0 ? .9 : -.9), n[1], n[2] - .5]); } const s = V.add(c, V.mul(n, R0 * .86)), L = 1.55 + .5 * Math.abs(Math.sin(i * 2.1)); let e, wr; if (n[1] < -.28) { e = V.add(c, [n[0] * 2.3, n[1] * .9 + .55, n[2] * 2.3]); wr = [c[0] + n[0] * 2.65, .38, c[2] + n[2] * 2.65]; } else { const side = V.norm(V.cross(n, [.3, 1, .2])); e = V.add(V.add(c, V.mul(n, R0 + L * .55)), V.mul(side, .32 * (i % 2 ? 1 : -1))); wr = V.add(V.add(c, V.mul(n, R0 + L * 1.15)), [0, .35, 0]); }
    A.arm(B, s, e, wr, .17, { m: .8 }); const dir = n[1] < -.28 ? V.norm([n[0], -.12, n[2]]) : V.norm(V.add(V.sub(wr, e), [0, .6, 0])); const up = n[1] < -.28 ? [0, 1, 0] : V.norm([-n[0], .1, -n[2] + .01]); const HF = Frame.along(wr, dir, up); A.hand(B, new Frame(wr, HF.x, dir, HF.z), 1.05 + .1 * (i % 3), { curl: n[1] < -.28 ? 10 : [4, 10, 6, 12], spread: 12, thin: .85 }); }
  return B;
} };
