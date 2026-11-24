// 시안4 3장 비인간형 — 쥐왕: 하수도에 빠져 죽은 사람의 갈비 속에서 수십 마리 쥐가 꼬리로 한 매듭에 묶였다. 매듭이 심장처럼 뛰고, 무더기 전체가 한 몸처럼 굴러온다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'f3n', name: '쥐왕', kind: '비인간형 · 3장 하수도', H: 6.2, build(p = {}) {
  const B = new Body(), w = p.walk ?? .15, sg = p.surge ?? .3, rk = p.rock ?? 0, I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]);
  const W = I([0, 0, 0]).rot(rk * 6, 0, rk * 4); // 무더기 전체 흔들림
  const K = W.p([0, 3.05, .15]); // 꼬리 매듭(갈비 속)
  // ---- 쥐 한 마리: o 몸 중심, fwd 머리 방향, up 등 방향, s 크기, gape 입 벌림
  const rat = (o, fwd, up, s, q = {}) => {
    const z = V.norm(fwd), x = V.norm(V.cross(up, z)), y = V.cross(z, x), F = new Frame(o, x, y, z), f = F.sc(s), P = v => f.p(v), ph = q.ph || 0, arch = q.arch ?? .0;
    B.group({ k: .09 * s, kg: .05 * s, amp: .012 * s, freq: 11 / s, rid: 0 });
    B.ell(f.at([0, .02 + arch, -.08]), [.28, .26, .44]); B.ell(f.at([0, .04, -.42]), [.3, .27, .3]); B.ell(f.at([0, -.01, .24]), [.22, .2, .28]);
    const hd = f.at([0, .02, .55]).rot(q.nod ?? 8, q.turn ?? 0, 0), H = v => hd.p(v);
    B.ell(hd.at([0, .02, 0]), [.19, .17, .23]); B.cone(H([0, .02, .1]), H([0, -.05, .4]), .14 * s, .05 * s); B.ball(H([0, -.05, .42]), .05 * s);
    for (const m of [-1, 1]) { B.ell(hd.at([m * .12, .15, -.04]).rot(-15, m * 30, m * -25), [.085, .1, .018], { k: .02 * s }); B.ell(hd.at([m * .13, .15, -.03]).rot(-15, m * 30, m * -25), [.05, .065, .02], { op: 1, k: .02 * s }); }
    // 다리
    B.group({ k: .03 * s, kg: .06 * s }); const lg = [[.15, .32, 1], [-.15, .32, 1], [.2, -.36, -1], [-.2, -.36, -1]];
    lg.forEach(([lx, lz, fr], i) => { const st = Math.sin((w + ph) * 6.283 + i * 1.6) * .1, a = P([lx, -.08, lz]), kn = P([lx * 1.4, -.18, lz - fr * .05 + st]), ft = P([lx * 1.35, -.27, lz + .12 + st]); B.tube([a, kn, ft], [.07 * s * (fr < 0 ? 1.4 : 1), .045 * s, .03 * s]); for (let t = -1; t <= 1; t++) B.cone(ft, P([lx * 1.35 + t * .04, -.28, lz + .2 + st]), .018 * s, .01 * s); });
    // 눈·이
    B.group({ mat: 2, k: .005 }); for (const m of [-1, 1]) B.ball(H([m * .1, .08, .1]), .035 * s);
    if (q.gape) { B.group({ mat: 4, k: .003 }); for (const m of [-1, 1]) B.cone(H([m * .016, -.1, .36]), H([m * .016, -.2, .37]), .014 * s, .008 * s); }
    // 수염
    B.group({ k: .002, kg: 0 }); for (const m of [-1, 1]) for (let i = 0; i < 3; i++) B.tube([H([m * .06, -.03, .36]), H([m * (.2 + i * .04), -.05 + i * .04, .42 + i * .02]), H([m * (.34 + i * .05), -.09 + i * .06, .36])], .006 * s, { per: 2 });
    // 꼬리: 엉덩이 → 무더기 속 → 매듭
    const t0 = P([0, .0, -.7]), t1 = P([0, -.05, -1.05]), mid = V.lerp(t1, K, .5); B.group({ k: .02 * s, kg: .03 * s });
    B.tube([t0, t1, V.add(mid, [Math.sin(ph * 7) * .3, -.25, Math.cos(ph * 5) * .3]), V.lerp(mid, K, .6), V.add(K, [Math.sin(ph * 3) * .3, Math.cos(ph * 4) * .25, Math.sin(ph * 6) * .25])], [.07 * s, .06 * s, .05 * s, .045 * s, .04 * s], { per: 5 });
  };
  // ---- 사람의 남은 것: 기울어진 갈비 우리, 척추, 해골, 뼈 팔 하나
  const TF = W.at([0, 2.85, -.15]).rot(-16, 16, 7);
  B.group({ mat: 4, k: .04, kg: .02 }); A.ribs(B, TF, { n: 8, w: .9, d: .62, h: 2.0, r: .065, open: .35, po: { k: .04 } });
  B.tube([TF.p([0, 1.15, .62]), TF.p([0, .55, .7]), TF.p([0, .05, .62])], [.07, .09, .06]); // 흉골
  const sp = [TF.p([0, -1.6, -.55]), TF.p([0, -.6, -.68]), TF.p([0, .5, -.66]), TF.p([0, 1.3, -.5]), TF.p([0, 1.9, -.2])]; A.spine(B, sp, .13, { n: 15, back: TF.d([0, 0, -1]), out: .03, wing: true, k: .03, kg: .02 }); B.group({ mat: 4, k: .04 }); B.tube(sp, .085);
  for (const m of [-1, 1]) { B.group({ mat: 4, k: .03, kg: .03 }); B.tube([TF.p([m * .1, 1.2, .55]), TF.p([m * .55, 1.3, .45]), TF.p([m * 1.05, 1.22, .05])], [.04, .035, .05]); B.tube([TF.p([m * .95, 1.25, -.1]), TF.p([m * .55, 1.05, -.7]), TF.p([m * .5, .35, -.65]), TF.p([m * .95, .95, -.4])], [.06, .05, .04, .05]); } // 쇄골·어깨뼈
  // 해골: 앞으로 떨궈져 매달림, 턱이 빠져 있음
  const HF = new Frame(TF.p([.05, 2.55, .3]), TF.x, TF.y, TF.z).rot(30 + (p.nod ?? 0), -20 + (p.headYaw || 0), -14);
  const g0 = B.groups.length; A.head(B, HF, 1.35, { gaunt: 2.6, nose: 'skull', jaw: p.jaw ?? 30, teeth: 12, toothLen: .07, ears: false, wrinkle: false, eyeSize: 1.7, eyeH: .085, eyeTilt: -14, kg: .04, amp: .006, mouthW: 1.1 }); const bone = a => { for (let i = a; i < B.groups.length; i++) if (!B.groups[i].mat) B.groups[i].mat = 4; }; bone(g0);
  B.group({ mat: 4, k: .03, kg: .05 }); for (const m of [-1, 1]) B.tube([HF.p(V.mul([m * .2, -.08, .26], 1.35)), HF.p(V.mul([m * .3, -.06, .1], 1.35)), HF.p(V.mul([m * .31, -.02, -.05], 1.35))], .045 * 1.35); B.group({ mat: 2, k: .01 }); B.ell(HF.at(V.mul([0, -.12, .36], 1.35)), [.06 * 1.35, .08 * 1.35, .06 * 1.35]); // 광대뼈·콧구멍
  B.group({ mat: 4, k: .03, kg: .03 }); B.tube([TF.p([0, 1.9, -.25]), V.lerp(TF.p([0, 1.9, -.25]), HF.p(V.mul([0, -.2, -.22], 1.35)), .5), HF.p(V.mul([0, -.2, -.22], 1.35))], [.08, .07, .08]); for (let i = 0; i < 3; i++) { const c = V.lerp(TF.p([0, 1.9, -.25]), HF.p(V.mul([0, -.2, -.22], 1.35)), .2 + i * .3); B.ball(c, .12); B.cone(c, V.add(c, TF.d([0, -.05, -.2])), .07, .03); }
  { B.group({ mat: 4, k: .01 }); const hs = 1.35, q = v => HF.p(V.mul(v, hs)); B.groove(q([0, .46, -.05]), HF.d([1, 0, 0]), .006 * hs, .012 * hs, .5 * hs, { wob: .6, wf: 22 }); B.groove(q([0, .38, .12]), HF.d([0, .3, 1]), .006 * hs, .012 * hs, .6 * hs, { wob: .6, wf: 22, bow: .3 }); B.groove(q([.18, .3, .25]), HF.d([.6, .7, .2]), .005 * hs, .014 * hs, .18 * hs, { wob: .9, wf: 30 }); }
  // 뼈 팔: 무더기 밖으로 뻗어 바닥을 짚음
  { const g1 = B.groups.length; const s = TF.p([-1.05, 1.15, 0]), e = W.p([-2.05, 3.45, .7]), wr = W.p([-2.55, 1.35, 1.55]); B.group({ mat: 4, k: .04, kg: .04 }); B.tube([s, V.lerp(s, e, .5), e], [.1, .07, .1]); B.ball(e, .12); B.tube([e, V.lerp(e, wr, .5), wr], [.08, .05, .07]); B.tube([V.add(e, [0, -.05, .08]), V.add(V.lerp(e, wr, .5), [.05, 0, .07]), V.add(wr, [.04, 0, .04])], [.06, .04, .05]);
    A.hand(B, new Frame(wr, [0, 0, 1].map((v, i) => [ -.3, 0, .95][i]), V.norm([-.15, -.9, .45]), V.norm([0, .45, .9])).rot(0, 0, 0), 1.25, { curl: [30, 18, 40, 55], spread: 14, thin: .55, len: 1.25, vein: 0, claw: 0 }); bone(g1); }
  // ---- 무더기 속 어둠(틈으로 보이는 깊이)
  B.group({ mat: 2, k: .3 }); B.ell(W.at([0, 1.25, .05]), [1.45, .95, 1.35]); B.ell(W.at([0, 2.1, -.1]), [1.15, .85, 1.0]);
  // ---- 쥐 무더기: 층마다 둘러싸고, 바닥 쥐는 밖으로 기어 나감
  const L = [[.3, 2.6, 14, 0], [.95, 2.3, 12, .4], [1.3, 2.15, 9, 1.6], [1.6, 1.95, 11, .9], [1.95, 1.75, 8, 2.4], [2.25, 1.5, 9, .2], [2.85, 1.0, 6, .6], [3.35, .5, 3, 1.3]]; let idx = 0;
  for (const [y, R, n, a0] of L) for (let i = 0; i < n; i++) {
    idx++; const a = a0 + i / n * 6.283 + Math.sin(idx * 3.7) * .18, c = Math.cos(a), sn = Math.sin(a), ph = idx * .37, s = .95 + .2 * Math.sin(idx * 2.3), out = [c, 0, sn];
    if (y < .5) { // 바닥: 밖으로 기어 나감(surge 가 크면 더 멀리)
      const r = R + sg * .5 + .25 * Math.sin(idx * 1.9), o = W.p([c * r, .3 * s, sn * r]), turn = Math.sin(idx * 2.9) * .8; rat(o, V.norm([c + Math.cos(a + 1.57) * turn * .6, 0, sn + Math.sin(a + 1.57) * turn * .6]), [0, 1, 0], s, { ph, gape: idx % 3 === 0, turn: Math.sin(idx) * 20 });
    } else { // 비탈: 등을 밖으로, 위·옆·아래로 제각각
      const nrm = V.norm([c * 1.0, (y / 2.9) * 1.1, sn * 1.0]), o = W.p([c * R, y, sn * R]), tang = [-sn, 0, c], k = idx % 5, dir = k === 0 ? [0, 1, 0] : k === 1 ? V.add(V.mul(tang, 1), [0, -.4, 0]) : k === 3 ? V.add(V.mul(tang, -1), [0, -.5, 0]) : V.add(V.mul(out, .6), [Math.sin(idx) * .3, -1, 0]);
      const fw = V.norm(V.sub(dir, V.mul(nrm, V.dot(dir, nrm)))); rat(o, fw, nrm, s, { ph, gape: idx % 4 === 2, nod: k === 0 ? 10 : -12, turn: Math.sin(idx * 1.3) * 25, arch: .04 });
    }
  }
  // 갈비를 타고 오르는 쥐 몇 마리, 해골 눈구멍에서 머리를 내민 쥐
  rat(TF.p([.98, .55, .2]), TF.d([.1, 1, .2]), TF.d([1, 0, .2]), 1.0, { ph: 1.1, gape: true, nod: -14 });
  rat(TF.p([-.92, .2, .45]), TF.d([.2, .8, .5]), TF.d([-1, 0, .3]), .95, { ph: 2.3, turn: -20 });
  rat(TF.p([.45, 1.45, -.75]), TF.d([.3, .2, 1]), TF.d([0, 1, -.2]), .85, { ph: 3.1, nod: 20 });
  { const e = HF.p(V.mul([-.125, -.02, .5], 1.35)); rat(V.add(e, HF.d([0, 0, -.55])), HF.d([.1, -.15, 1]), HF.d([0, 1, 0]), .62, { ph: 4.2, gape: true, nod: -4 }); }
  // ---- 매듭: 꼬리들이 엉켜 굳은 덩어리(붉은 단 한 곳) — 갈비 틈으로 보인다
  B.group({ mat: 1, k: .05, kg: .02, amp: .01, freq: 8 }); const beat = 1 + (p.beat ?? .5) * .12;
  for (let j = 0; j < 7; j++) { const pts = []; for (let i = 0; i <= 18; i++) { const t = i / 18 * 6.283; pts.push(V.add(K, V.mul([Math.sin(t * 2 + j) * .42 + Math.sin(t * 3 + j * 2) * .12, Math.cos(t * 3 + j * .7) * .38, Math.sin(t * 2 + j * 1.3 + 1) * .34], beat))); } B.tube(pts, .07, { per: 2 }); }
  return B;
} };
