// 시안4 7장 인간형 — 복도 끝 그 애: 교복 차림의 여학생. 목이 옆으로 꺾여 머리가 어깨에 얹혀 있고, 긴 생머리가 옆으로 곧게 늘어진다.
// 너무 가만히 서 있다. 한 손에는 끈이 끊어진 책가방, 가슴의 큰 리본만 색이 남았다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'f7h', name: '복도 끝 그 애', kind: '인간형 · 7장 학교', H: 9.4, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? 0 : Math.sin(w * Math.PI * 2), I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]), L = V.lerp;
  const panel = (pts, wd, t, fr = [0, .1, 1]) => { B.group({ k: .02, kg: .03 }); for (let i = 0; i < pts.length - 1; i++) { const a = pts[i], b = pts[i + 1], d = V.norm(V.sub(b, a)), x = V.norm(V.cross(d, fr)); B.box(new Frame(L(a, b, .5), x, d, V.cross(x, d)), [wd, V.len(V.sub(b, a)) * .5 + .03, t], t * .8); } };
  // ---- 다리: 가늘고 길다. 무릎을 붙이고 발끝이 살짝 안으로
  for (const m of [-1, 1]) {
    const st = m * S, h = [m * .3, 4.55, 0], k = [m * .25, 2.45, .1 + st * .45], an = [m * .24, .42 + Math.max(0, -st) * .2, -.08 + st * .8];
    A.leg(B, h, k, an, .25, { m: .72, front: [-m * .06, 0, 1] });
    // 무릎 양말: 종아리를 덮는 통 + 접힌 윗단
    B.group({ k: .05, kg: .06, amp: .003, freq: 6 }); B.tube([L(k, an, .14), L(k, an, .35), L(k, an, .7), L(k, an, .97)], [.22, .23, .18, .16]);
    B.tube([L(k, an, .1), L(k, an, .19)], [.24, .235]); A.rings(B, [L(k, an, .55), L(k, an, .95)], 2, .01, .014, .3, { tilt: .3 });
    // 실내화(흰 고무 실내화)
    const fz = V.norm([-m * .1, 0, 1]), FF = new Frame(an, V.norm(V.cross([0, 1, 0], fz)), [0, 1, 0], fz);
    A.foot(B, FF, 1.0, {});
    B.group({ k: .05, kg: .03 }); B.box(FF.at([0, -.34, .2]), [.2, .05, .45], .05); B.ell(FF.at([0, -.18, .32]), [.2, .14, .3]); B.box(FF.at([0, -.26, -.18]), [.18, .1, .12], .06);
    B.ell(FF.at([0, -.1, .25]), [.17, .1, .22], { op: 1, k: .03 }); B.groove(FF.p([0, -.3, .2]), [0, 1, 0], .012, .02, .7, { wob: .02 });
  }
  // ---- 주름 치마(무릎 바로 위): 허리에서 퍼지는 판 주름
  { const top = 5.25, bot = 2.9, N = 28; B.group({ k: .04, kg: .05, amp: .002, freq: 5 }); B.cone([0, top, -.02], [0, bot + .25, .0], .5, .74, { k: .1 });
    for (let i = 0; i < N; i++) { const a = i / N * 6.283, a2 = (i + .5) / N * 6.283, sw = S * .08 * Math.sin(a), rb = .84 + .04 * Math.sin(i * 2.3);
      const t = [Math.sin(a) * .52, top - .05, Math.cos(a) * .48 - .02], b = [Math.sin(a + sw) * rb, bot + .03 * Math.sin(i * 3.1), Math.cos(a + sw) * rb * .9 + .02];
      const d = V.norm(V.sub(b, t)), out = V.norm([Math.sin(a2), 0, Math.cos(a2)]), x0 = V.norm(V.cross(d, out)), x = V.norm(V.add(x0, V.mul(out, i % 2 ? .45 : -.45)));
      B.box(new Frame(L(t, b, .5), x, d, V.cross(x, d)), [.1 * (rb / .84), V.len(V.sub(b, t)) * .5, .026], .02, { k: .03 }); }
    for (let i = 0; i < 5; i++) B.groove([Math.sin(i * 1.3 + .4) * .8, 3.5 + i * .25, Math.cos(i * 1.3 + .4) * .7], [0, 1, 0], .01, .02, .4, { wob: .3, bow: .5 }); // 구김
    B.group({ k: .03, kg: .05 }); B.tube([[-.5, top, 0], [0, top + .02, .5], [.5, top, 0], [0, top, -.5], [-.5, top, 0]].map(q => [q[0], q[1], q[2] * .92 - .02]), .07, { per: 4 }); }
  // ---- 몸통: 블라우스 + 블레이저(좁은 어깨, 처진 어깨선)
  const T = I([0, 6.45, -.02]);
  B.group({ k: .18, kg: .2, amp: .003, freq: 5 });
  B.ell(T.at([0, -1.05, 0]), [.52, .45, .34]); B.ell(T.at([0, -.35, 0]), [.56, .65, .36]); B.ell(T.at([0, .4, -.03]), [.6, .55, .37]);
  for (const m of [-1, 1]) B.ell(T.at([m * .53, .66, -.04]), [.23, .2, .24]);
  for (const m of [-1, 1]) B.ell(T.at([m * .19, .15, .22]), [.22, .2, .17], { k: .15 });
  B.group({ k: .05, kg: .12 }); B.tube([[-.56, 5.15, -.05], [-.42, 5.1, .32], [-.04, 5.05, .4]], .055); B.tube([[.56, 5.15, -.05], [.42, 5.1, .32], [.06, 5.12, .4]], .055); B.tube([[-.56, 5.15, -.05], [0, 5.2, -.38], [.56, 5.15, -.05]], .055);
  for (const m of [-1, 1]) { for (let i = 0; i < 3; i++) B.groove([m * .43, 5.6 + i * .25, .2], V.norm([m * .3, 1, -.2 + i * .1]), .014, .028, .42, { wob: .12, bow: .4 }); B.groove([m * .5, 6.75, .15], V.norm([m * .6, .7, .2]), .014, .028, .38, { wob: .1, bow: .3 }); B.groove([m * .28, 6.0, -.32], V.norm([0, 1, .1]), .014, .028, .5, { wob: .15 }); }
  B.groove([0, 6.3, -.36], [1, 0, 0], .012, .025, .5, { wob: .1 }); // 등 솔기
  // 옷깃(라펠)
  for (const m of [-1, 1]) panel([[m * .19, 7.3, .22], [m * .28, 6.95, .36], [m * .19, 6.45, .4], [m * .05, 5.95, .4]], .1, .024);
  for (const m of [-1, 1]) panel([[m * .32, 7.3, .08], [m * .38, 7.0, .3], [m * .33, 6.8, .37]], .055, .02);
  // 셔츠 칼라 + 단추 + 명찰 + 주머니
  B.group({ k: .02, kg: .03 }); for (const m of [-1, 1]) B.box(new Frame([m * .1, 7.27, .27], [1, 0, 0], [0, 1, 0], [0, 0, 1]).rot(-30, m * -10, m * 32), [.1, .07, .012], .01);
  for (const y of [5.85, 5.45]) B.ball([0, y, .42], .045, { k: .01 });
  B.box(new Frame([.36, 6.62, .36], [1, 0, 0], [0, 1, 0], V.norm([.2, 0, 1])), [.15, .045, .015], .01);
  for (const m of [-1, 1]) B.groove([m * .34, 5.55, .36], [0, 1, .2], .01, .025, .26, { wob: 0 });
  B.box(new Frame([-.34, 6.55, .37], [1, 0, 0], [0, 1, 0], V.norm([-.2, 0, 1])), [.15, .015, .02], .01);
  // 큰 리본: 칼라 밑 나비 매듭 + 늘어진 꼬리 (포인트)
  B.group({ mat: 1, k: .03, kg: .02 }); { const c = [0, 7.08, .34]; B.ball(c, .055); for (const m of [-1, 1]) { B.ell(new Frame(V.add(c, [m * .13, .01, -.01]), V.norm([1, m * .2, 0]), V.norm([-m * .2, 1, 0]), [0, 0, 1]), [.12, .07, .035]); B.tube([V.add(c, [m * .02, -.03, .01]), V.add(c, [m * .07, -.2, .05]), V.add(c, [m * .09, -.38, .04])], [.03, .035, .025]); } }
  // ---- 팔: 소매 + 맨 손. 몸 옆에 곧게, 손가락만 길다
  for (const [m, sw] of [[-1, S * .25], [1, -S * .25]]) {
    const s = [m * .68, 7.1, -.03], e = [m * .84, 5.6, sw * .4], wr = [m * .8, 4.2, .12 + sw];
    A.arm(B, s, e, wr, .15, { m: .75, det: 0 });
    B.group({ k: .07, kg: .07, amp: .003, freq: 5 }); B.tube([V.add(s, [m * .02, .05, 0]), L(s, e, .5), e, L(e, wr, .5), L(e, wr, .84)], [.22, .2, .19, .17, .16]);
    B.tube([L(e, wr, .82), L(e, wr, .88)], [.17, .175], { k: .02 });
    for (let i = 0; i < 4; i++) B.groove(V.add(L(s, e, .9 + i * .06), [0, 0, .12]), V.norm([m * .1 * (i - 1.5), 1, .35]), .014, .028, .28, { bow: .6 * (i % 2 ? 1 : -1), wob: .15 });
    B.groove(V.add(L(s, e, .35), [m * .1, 0, .1]), V.norm([0, 1, .2]), .012, .024, .32, { wob: .2 });
    B.groove(L(e, wr, .3), V.norm([m * .2, 1, -.3]), .012, .02, .28, { wob: .2, bow: .4 });
    if (m < 0) A.hand(B, new Frame(wr, [0, 0, 1], V.norm([-.04, -1, .05]), [-1, 0, 0]), 1.25, { curl: [6, 10, 8, 14], spread: 4, thin: .7, len: 1.35, vein: 0 });
    else A.hand(B, new Frame(wr, [0, 0, 1], V.norm([.05, -1, .1]), [1, 0, 0]), 1.25, { curl: [42, 50, 48, 56], spread: 5, thin: .7, len: 1.35, vein: 0 });
  }
  // 왼손(+x)이 쥔 책가방: 끈 하나가 끊어져 가방이 기울어 매달림
  { const g = [.84, 3.35, .32], C = new Frame([.9, 2.15, .38], V.norm([1, 0, -.15]), V.norm([.12, 1, .05]), V.norm([.15, -.05, 1])).rot(0, 0, -14 + S * 6);
    B.group({ k: .02, kg: .02 }); B.tube([g, [.88, 3.15, .25], C.p([-.25, .62, -.02])], .035); B.tube([g, [.92, 3.1, .42], C.p([.12, .62, .05]), C.p([.22, .5, .08])], .03);
    B.group({ k: .08, kg: .02, amp: .004, freq: 5 }); B.box(C, [.42, .58, .17], .12); B.box(C.at([0, -.1, .2]), [.3, .3, .06], .06); B.groove(C.p([0, .16, .26]), C.y, .01, .02, .4, { wob: .02 }); B.groove(C.p([0, .35, .18]), C.y, .012, .02, .5, { wob: .03 });
    B.group({ k: .01 }); B.ball(C.p([.0, .17, .29]), .035); B.tube([C.p([-.42, .4, -.17]), C.p([-.5, .1, -.2]), C.p([-.42, -.4, -.17])], .03); B.tube([C.p([.36, .4, -.17]), C.p([.5, -.1, -.24]), C.p([.55, -.55, -.12]), C.p([.4, -.9, -.05])], .03); }
  // ---- 목과 꺾인 머리: 목이 늘어나 오른쪽(−x)으로 꺾여 머리가 어깨에 얹힘
  const tilt = p.tilt ?? 58, s = 1.38;
  const HF = I([-.47, 8.07, .12]).rot(p.nod ?? 4, p.headYaw ?? 0, tilt), hp = v => HF.p(V.mul(v, s));
  const nb = [0, 7.2, .0], nt = hp([.05, -.28, -.08]);
  A.neck(B, nb, nt, .16, { mid: [-.1, 7.75, .05], adam: false, kg: .12 });
  B.group({ k: .03, kg: .05 }); for (let i = 0; i < 3; i++) B.groove(L(nb, nt, .35 + i * .14), V.norm(V.sub(nt, nb)), .012, .025, .25, { bow: 1.5, wob: .2 }); // 꺾인 목의 접힌 살
  B.group({ k: .03, kg: .06 }); B.tube([[.13, 7.3, -.02], [.1, 7.6, -.04], hp([.16, -.26, -.12])], [.05, .06, .04]); // 반대쪽으로 팽팽히 당겨진 힘줄
  A.face(B, HF, s, { jaw: p.jaw ?? 0, eyes: 'real', gaunt: .55, age: .12, teeth: 8, w: .9, iris: .014, eyeSize: 1.08, open: 1.15, gaze: p.gaze || [-.012, .006], lips: .8, vein: false, ears: false, rid: .0006 * s });
  // ---- 머리카락: 두피 덮개(얼굴만 열림) + 머리 둘레에서 중력대로 곧게 떨어지는 긴 생머리 커튼
  { const fall = p.hairLen ?? 1, hc = hp([0, .05, -.05]), lowY = 4.4 + (1 - fall) * 2;
    B.group({ k: .04, kg: .03, amp: .002, freq: 9 }); B.ell(new Frame(hp([0, .14, -.13]), HF.x, HF.y, HF.z), [.355 * s, .37 * s, .42 * s]);
    B.ell(new Frame(hp([0, -.12, .43]), HF.x, HF.y, HF.z), [.28 * s, .35 * s, .3 * s], { op: 1, k: .06 });
    for (let i = 0; i < 14; i++) { const a = (i / 13 - .5) * 2.8; B.groove(hp([0, .47, -.06]), HF.d([Math.cos(a), 0, Math.sin(a) * .9]), .005, .007, .6 * s, { wob: .25, wf: 5 }); }
    const R = [];
    for (const [ly, rr, N] of [[.3, .3, 30], [.12, .37, 40], [-.08, .37, 32]]) for (let i = 0; i < N; i++) {
      const a = i / N * 6.283 + ly * 3, j = Math.sin(i * 12.99 + ly * 40), lz = Math.cos(a) * rr * 1.05 - .07, lx = Math.sin(a) * rr * .95;
      if (lz > -.02 && Math.abs(lx) < .3) continue; if (lx > .1 && lz > -.22) continue; // 얼굴 앞은 몇 가닥만(한쪽 눈은 보이게)
      const r0 = hp([lx * .92, ly * .95, lz * .92]), o = V.norm(V.sub(r0, hc)), r1 = V.add(r0, V.add(V.mul(o, .03 + .02 * j), [0, -.08, 0]));
      const yb = lowY + .9 * Math.abs(Math.sin(i * 2.7 + ly * 9)) + (r1[0] > -.35 ? 1.5 : 0); if (r1[1] - yb < .3) continue;
      const r2 = V.add(r1, [o[0] * .05, -(r1[1] - yb) * .25, o[2] * .04]), r3 = [r2[0] + j * .04 + S * .04, yb + (r1[1] - yb) * .25, r2[2] + j * .03], r4 = [r3[0] + j * .05, yb, r3[2] + j * .04];
      R.push([r0, r1, r2, r3, r4]);
    }
    for (let i = 0; i < 7; i++) { const t = i / 6, j = Math.sin(i * 4.3); const a0 = hp([-.05 - t * .16, .36 - t * .05, .24 - t * .04]), a1 = hp([-.08 - t * .17, .2, .36]), a2 = hp([-.1 - t * .16 + j * .02, .0, .4]); const yb = 5.6 + t * .5 + Math.abs(j) * .3; R.push([a0, a1, a2, [a2[0] + .03, (a2[1] + yb) / 2, a2[2] + .05], [a2[0] + j * .04, yb, a2[2] + .04]]); }
    B.group({ k: .05, kg: .04, amp: .002, freq: 12 }); for (const q of R) B.tube(q, [.032, .036, .036, .03, .01], { per: 3 });
  }
  return B;
} };
