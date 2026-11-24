// 시안4 4장 인간형 — 수간호사: 폐원 뒤에도 야간 회진을 도는 키 큰 수간호사. 얼굴은 붕대로 감겼고 한쪽 눈만 내다본다. 피로 찬 유리 주사기를 주먹에 쥐고 있다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'f4h', name: '수간호사', kind: '인간형 · 4장 폐병원', H: 10.4, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .3 : Math.sin(w * Math.PI * 2), I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]), raise = p.raise ?? 0;
  // ---- 다리: 흰 스타킹, 무릎 거의 안 굽힌 끄는 걸음
  for (const m of [-1, 1]) {
    const st = m * S * .55, h = [m * .36, 4.4, 0], k = [m * .38, 2.4, .12 + st * .35], an = [m * .36, .42 + Math.max(0, -st) * .06, -.05 + st * .75];
    A.leg(B, h, k, an, .3, { m: .92, det: 0, amp: .002 });
    // 간호화: 둥근 코, 낮은 굽, 끈
    const fd = V.norm([m * .06, 0, 1]), F = new Frame(an, V.norm(V.cross([0, 1, 0], fd)), [0, 1, 0], fd);
    B.group({ k: .06, kg: .1, amp: .002 }); B.ell(F.at([0, -.16, -.05]), [.25, .2, .3]); B.ell(F.at([0, -.24, .38]), [.23, .14, .36]); B.tube([F.p([-.22, -.13, .0]), F.p([0, -.05, .2]), F.p([.22, -.13, .0])], .025);
    B.group({ k: .02, kg: .04 }); B.box(F.at([0, -.36, .16]), [.25, .03, .58], .03); B.box(F.at([0, -.3, -.25]), [.15, .08, .12], .02);
  }
  // ---- 치마: 허리에서 종아리까지 A 라인, 주름이 깊게 패임
  const top = [0, 5.45, -.02], hem = [0, 2.15, .12], R0 = .62, R1 = 1.22, sw = S * .12;
  B.group({ k: .12, kg: .2, amp: .006, freq: 3 });
  B.cone(top, V.add(hem, [sw, 0, 0]), R0, R1); B.box(I([0, 1.0, 0]), [3, 1.15, 3], .01, { op: 1, k: .03 });
  for (let i = 0; i < 14; i++) { const a = i / 14 * 6.283 + .12, c = Math.cos(a), s = Math.sin(a), u = V.add(top, [s * (R0 + .02), -.4, c * (R0 + .02)]), b = V.add(hem, [s * (R1 + .02) + sw, 0, c * (R1 + .02)]), mid = V.lerp(u, b, .62); B.ell(Frame.along(mid, V.sub(b, u), [s, 0, c]), [.1 + .03 * Math.sin(i * 3), 1.5, .12], { op: 1, k: .1 }); }
  // 단: 물결진 두께
  B.group({ k: .03, kg: .06 }); { const pts = []; for (let i = 0; i <= 56; i++) { const a = i / 56 * 6.283 + .12, r = R1 - .06 - .1 * Math.pow(Math.abs(Math.cos(a * 7)), 3); pts.push(V.add(hem, [Math.sin(a) * r + sw, .03 + .02 * Math.sin(a * 3), Math.cos(a) * r])); } B.tube(pts, .045, { per: 1 }); }
  // 앞치마: 치마 앞 판 + 가장자리 + 허리끈 매듭(뒤)
  { const u = V.add(top, [0, -.3, R0 + .06]), b = V.add(hem, [sw * .5, .45, R1 - .02]), Fa = Frame.along(V.lerp(u, b, .5), V.sub(b, u), [0, 0, 1]); B.group({ k: .03, kg: .05, amp: .003 }); B.box(Fa, [.5, V.len(V.sub(b, u)) * .5, .03], .03); for (const m of [-1, 1]) B.tube([Fa.p([m * .5, -1.5, .03]), Fa.p([m * .53, 0, .03]), Fa.p([m * .47, 1.5, .04])], .025); for (let i = 0; i < 3; i++) B.groove(Fa.p([(i - 1) * .3, -.2, .04]), Fa.x, .015, .03, 1.2, { wob: .2, wf: 2, bow: .2 }); B.box(Fa.at([.25, -.4, .05]), [.2, .2, .02], .02); }
  B.group({ k: .03, kg: .05 }); B.tube([[-.66, 5.4, .05], [-.4, 5.42, .55], [0, 5.42, .64], [.4, 5.42, .55], [.66, 5.4, .05], [.45, 5.4, -.5], [0, 5.4, -.62], [-.45, 5.4, -.5], [-.66, 5.4, .05]], .07, { per: 2 });
  for (const m of [-1, 1]) { B.ell(I([m * .22, 5.4, -.68]).rot(0, 0, m * 25), [.22, .1, .06]); B.tube([[m * .05, 5.38, -.68], [m * .18, 4.9, -.75], [m * .26, 4.3, -.95 - .05 * m]], [.05, .045, .04]); } B.ball([0, 5.4, -.68], .07);
  // ---- 몸통: 곧고 좁은 상의, 단추, 깃, 가슴 앞치마
  const lean = p.lean ?? 7, TF = I([0, 6.55, 0]).rot(lean, 0, 0);
  B.group({ k: .2, kg: .14, amp: .004, freq: 3 }); B.ell(TF.at([0, -.75, 0]), [.6, .55, .44]); B.ell(TF.at([0, .1, .0]), [.76, .85, .5]); for (const m of [-1, 1]) { B.ball(TF.p([m * .74, .56, -.04]), .24); B.ell(TF.at([m * .32, .15, .3]).rot(0, m * 15, 0), [.27, .25, .2]); }
  for (const m of [-1, 1]) { B.groove(TF.p([m * .55, .55, .2]), V.norm([m * .6, 1, .2]), .015, .03, .45, { bow: .4 }); B.groove(TF.p([m * .4, -.6, .38]), V.norm([m, .3, 0]), .012, .025, .35, { bow: .5 }); }
  B.group({ k: .02, kg: .04 }); B.box(TF.at([0, -.1, .48]).rot(-4, 0, 0), [.34, .5, .03], .03); for (const m of [-1, 1]) A.strap(B, [TF.p([m * .3, .38, .5]), TF.p([m * .45, .75, .32]), TF.p([m * .5, .9, -.1]), TF.p([m * .35, .3, -.5]), TF.p([m * .2, -1.1, -.5])], .05, .02, q => V.norm(V.sub(q, TF.p([0, 0, 0]))));
  B.group({ k: .01, kg: .02 }); for (let i = 0; i < 4; i++) B.ball(TF.p([0, .72 - i * .2, .48 - i * .01]), .035);
  B.group({ k: .03, kg: .05 }); for (const m of [-1, 1]) B.box(TF.at([m * .17, .92, .3]).rot(-40, m * 30, m * 40), [.17, .12, .025], .025); // 깃
  // 이름표(빈칸)와 시계 줄
  B.group({ k: .01, kg: .02 }); B.box(TF.at([-.42, .32, .45]).rot(-6, -18, 0), [.16, .06, .015], .01); B.tube([TF.p([.38, .4, .44]), TF.p([.4, .1, .48]), TF.p([.36, -.05, .47])], .012); B.ell(TF.at([.36, -.12, .48]), [.07, .07, .02]);
  // ---- 목: 길고 한쪽으로 꺾임
  A.neck(B, TF.p([0, .85, -.05]), TF.p([.06, 1.5, .1]), .2, { adam: false, kg: .12 });
  const s = 1.45, HF = new Frame(TF.p([.32, 2.12, .2]), [1, 0, 0], [0, 1, 0], [0, 0, 1]).rot(p.nod ?? 10, p.headYaw || 0, p.tilt ?? -36), hp = v => HF.p(V.mul(v, s));
  const gF = B.groups.length; A.face(B, HF, s, { w: .92, gaunt: .4, jaw: p.jaw ?? 4, eyes: ['shut', 'real'], iris: .016, open: 1.3, eyeSize: 1.05, ears: false, age: .1, lips: 1.1, teeth: 0, vein: false, elong: 1.05, kg: .04 * s });
  // 붕대: 얼굴 윤곽을 따라 겹겹이(가로·사선 교차) — 왼눈(+x)과 입만 틈
  const tab = (t, y) => { if (y >= t[0][0]) return t[0][1]; for (let i = 1; i < t.length; i++) if (y >= t[i][0]) { const [y0, v0] = t[i - 1], [y1, v1] = t[i]; return v1 + (v0 - v1) * (y - y1) / (y0 - y1); } return t[t.length - 1][1]; };
  const SX = [[.45, .2], [.3, .29], [.1, .3], [-.05, .285], [-.2, .245], [-.35, .19], [-.47, .1]], FZ = [[.45, .15], [.3, .3], [.15, .355], [0, .35], [-.15, .37], [-.27, .375], [-.4, .31], [-.48, .22]], BZ = [[.45, .2], [.3, .4], [.1, .5], [-.1, .46], [-.25, .3], [-.4, .14], [-.48, .05]];
  const band = (y, tilt, ph, skip, wd = 1) => { const pts = [], N = 34; for (let i = 0; i <= N; i++) { const th = i / N * 6.283, yy = y + tilt * Math.sin(th + ph), c = Math.cos(th), off = .022; pts.push([th, [(tab(SX, yy) + off) * Math.sin(th), yy, c > 0 ? (tab(FZ, yy) + off) * c : (tab(BZ, yy) + off) * c - .02]]); }
    B.group({ k: .006, kg: .004 }); for (let i = 0; i < N; i++) { const [t0, a] = pts[i], [, b] = pts[i + 1]; if (skip && skip(t0, a)) continue; const A_ = hp(a), B_ = hp(b), d = V.norm(V.sub(B_, A_)), up = HF.d([0, 1, 0]), out = V.norm(V.cross(d, up)), mid = V.lerp(A_, B_, .5); B.box(new Frame(mid, V.norm(V.cross(V.mul(out, -1), d)), d, V.mul(out, -1)), [.045 * s * wd * (1 + .15 * Math.sin(t0 * 3 + ph)), V.len(V.sub(B_, A_)) * .56, .012 * s], .012, { k: .015 }); } };
  const eyeGap = (th, a) => a[0] > .02 && a[0] < .25 && a[2] > .1, mouthGap = (th, a) => Math.abs(a[0]) < .12 && a[2] > .1;
  // 거즈: 얼굴 위에 덮어 감은 천 — 코·광대·턱이 천 아래로 뭉툭하게 비치고, 왼눈만 틈으로 내다본다
  { const g = B.g; B.g = B.groups[gF]; B.ell(HF.at(V.mul([0, -.13, .16], s)), [.27 * s, .36 * s, .26 * s], { k: .07 * s }); B.ell(HF.at(V.mul([0, .1, .2], s)), [.27 * s, .14 * s, .2 * s], { k: .07 * s }); B.ell(HF.at(V.mul([.125 * .92, -.02, .36], s)), [.09 * s, .065 * s, .12 * s], { op: 1, k: .03 * s }); const E = [[-.43, .05, 0], [-.33, -.06, 1], [-.21, .08, 2], [-.11, -.05, 3], [.12, .06, 5], [.21, -.04, 6], [-.25, .45, 8], [-.02, -.4, 9]]; for (const [y, t, i] of E) B.groove(hp([.02 * Math.sin(i * 3), y, .1]), HF.d([t, 1, .12 * Math.sin(i * 2)]), .005 * s, .009 * s, .6 * s, { wob: .15, wf: 5, bow: .1 * Math.sin(i * 1.7) }); B.groove(hp([0, -.27, .42]), HF.d([0, 1, 0]), .006 * s, .012 * s, .14 * s, { bow: -.6, wob: .2 }); B.g = g; }
  { B.group({ k: .02, kg: .03 }); const e = hp([.118, -.02, .36]); B.tube([V.add(e, HF.d([-.13 * s, .09 * s, -.02])), V.add(e, HF.d([0, .11 * s, .02])), V.add(e, HF.d([.13 * s, .07 * s, -.03]))], .014 * s); B.tube([V.add(e, HF.d([-.12 * s, -.08 * s, -.02])), V.add(e, HF.d([0, -.1 * s, .02])), V.add(e, HF.d([.12 * s, -.07 * s, -.04]))], .012 * s); for (let i = 0; i < 3; i++) B.tube([hp([-.28 + i * .02, .02 - i * .14, .1]), hp([-.1, -.03 - i * .14, .31]), hp([.08, .0 - i * .15, .34])], .009 * s); } // 겹친 거즈 가장자리·눈 틈 둘레
  // 눈 틈 가장자리: 붕대가 눈꺼풀을 눌러 짓무른 자국
  B.group({ k: .01, kg: .02 }); { const e = hp([.128 * .92, -.02, .33]); B.tube([V.add(e, HF.d([-.14, .08, -.02])), V.add(e, HF.d([0, .1, .02])), V.add(e, HF.d([.14, .08, -.03]))], .012 * s); }
  // 머리카락: 빗어 넘긴 머리 + 쪽
  B.group({ k: .05, kg: .06, amp: .004, freq: 8 }); B.ell(HF.at(V.mul([0, .16, -.1], s)), [.33 * s, .27 * s, .42 * s]); B.ball(hp([0, .08, -.52]), .19 * s); for (let i = 0; i < 7; i++) { const a = (i / 6 - .5) * 2.6; B.groove(hp([Math.sin(a) * .3, .32, Math.cos(a) * .2 - .05]), HF.d([Math.cos(a), 0, -Math.sin(a)]), .006 * s, .01 * s, .4 * s, { wob: .1, wf: 4 }); } for (let i = 0; i < 5; i++) B.groove(hp([0, .1, -.52]), HF.d([Math.cos(i * 1.3), Math.sin(i * 1.3), .3]), .006 * s, .012 * s, .22 * s, { bow: 3 });
  // 간호모: 머리 위 휜 앞띠(접힌 단) + 납작한 뒷부분 + 눌린 십자
  { const C = HF.at(V.mul([0, .44, -.06], s)).rot(-24, 0, 0), c = v => C.p(V.mul(v, s)); B.group({ k: .04 * s, kg: .03, amp: .002, freq: 6 });
    B.ell(C.at(V.mul([0, .02, -.08], s)), [.3 * s, .075 * s, .24 * s]); B.ell(C.at(V.mul([0, .06, .05], s)), [.31 * s, .1 * s, .07 * s]); B.tube([c([-.3, .0, .02]), c([-.15, .02, .14]), c([0, .03, .17]), c([.15, .02, .14]), c([.3, .0, .02])], .045 * s); // 둥근 앞단
    for (const m of [-1, 1]) { B.ell(C.at(V.mul([m * .3, .05, -.06], s)).rot(0, m * 20, m * -30), [.05 * s, .1 * s, .13 * s]); B.groove(c([m * .2, .1, -.05]), C.d([m, .3, .6]), .005 * s, .01 * s, .14 * s, { bow: .4 }); }
    B.groove(c([0, .07, .1]), C.d([1, 0, 0]), .005 * s, .01 * s, .05 * s); B.groove(c([0, .07, .1]), C.d([0, 1, 0]), .005 * s, .01 * s, .07 * s); B.groove(c([0, .0, -.1]), C.d([0, .2, 1]), .006 * s, .012 * s, .3 * s, { bow: .5 }); }
  // ---- 팔: 소매·흰 커프스, 길고 마른 손
  const sleeve = (sh, el, wr) => { B.group({ k: .08, kg: .1, amp: .004, freq: 4 }); B.tube([sh, V.lerp(sh, el, .5), el, V.lerp(el, wr, .5), V.lerp(el, wr, .86)], [.3, .26, .23, .2, .18]); A.rings(B, [V.lerp(sh, el, .8), V.lerp(el, wr, .2)], 4, .02, .035, .35, { bow: .4, tilt: .3 }); B.groove(V.lerp(sh, el, .35), V.sub(el, sh), .015, .03, .4, { bow: .5 }); B.group({ k: .02, kg: .04 }); B.tube([V.lerp(el, wr, .82), V.lerp(el, wr, .97)], [.2, .19]); };
  // 오른팔(-x): 주사기를 바늘이 위로 가게 주먹에 쥠
  const rsh = TF.p([-.82, .62, -.02]), rel = [-1.42, 5.95 + raise * .4, -.3], rwr = [-1.3, 6.75 + raise * .5, .7];
  A.arm(B, rsh, rel, rwr, .2, { m: .8, det: 0 }); sleeve(rsh, rel, rwr);
  const nd = V.norm([-.3, -.75 - raise * .3, .6]), hx = V.mul(nd, -1), z0 = [-.6, .2, -.8], hz = V.norm(V.sub(z0, V.mul(hx, V.dot(z0, hx)))), hy = V.cross(hx, hz); A.hand(B, new Frame(rwr, hx, hy, hz), 1.2, { curl: [80, 84, 86, 90], spread: 2, thin: .82, len: 1.05 });
  { const g = V.add(V.add(rwr, V.mul(hy, .42)), V.mul(hz, -.24)), Q = Frame.along(g, nd, [0, 1, 0]), q = v => Q.p(v);
    B.group({ k: .01, kg: .02 }); B.tube([q([0, -.62, 0]), q([0, -.56, 0])], .15); for (const m of [-1, 1]) B.box(Q.at([m * .2, -.58, 0]), [.12, .025, .07], .02); B.tube([q([0, .7, 0]), q([0, .76, 0])], .15); B.cone(q([0, .76, 0]), q([0, .9, 0]), .1, .04); // 금속 테·손가락 걸이
    B.tube([q([0, -.6, 0]), q([0, -1.05, 0])], .035); B.tube([q([-.12, -1.08, 0]), q([0, -1.1, .0]), q([.12, -1.08, 0])], .05); B.ell(Q.at([0, -1.12, 0]), [.14, .025, .14]); // 밀대·엄지판
    B.group({ k: .004 }); B.cone(q([0, .9, 0]), q([0, 1.75, .02]), .016, .006); // 바늘
    B.group({ mat: 1, k: .01, kg: .02 }); B.tube([q([0, -.56, 0]), q([0, .7, 0])], .128); for (let i = 0; i < 9; i++) B.groove(q([.12, -.4 + i * .12, .06]), Q.y, .006, .012, i % 3 ? .08 : .14); B.tube([q([0, .9, 0]), q([.01, 1.0, .02]), q([.03, 1.1, .02])], [.012, .02, .006]); } // 피로 찬 통(유일한 붉은 곳)
  // 왼팔(+x): 몸에 붙여 늘어뜨림, 손가락이 길다
  const lsh = TF.p([.82, .62, -.02]), lel = [1.05, 5.65, -.05 + S * .1], lwr = [1.02, 4.25, .22 + S * .15];
  A.arm(B, lsh, lel, lwr, .2, { m: .8, det: 0 }); sleeve(lsh, lel, lwr);
  A.hand(B, new Frame(lwr, [0, 0, 1], V.norm([.02, -1, .1]), [1, 0, 0]), 1.45, { curl: [10, 16, 14, 22], spread: 6, thin: .72, len: 1.3 });
  return B;
} };
