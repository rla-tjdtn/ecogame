// 시안4 9장 인간형 — 주차 안내원: 후드 우비에 형광 조끼를 걸친 안내원. 낮은 천장 탓에 등을 굽혔지만 펴면 천장보다 크다. 후드 속은 어둠뿐이고 창백한 눈 둘만 떠 있다. 붉게 켜진 경광봉으로 '빈자리'를 가리킨다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
const I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]);
module.exports = { id: 'f9h', name: '주차 안내원', kind: '인간형 · 9장 지하 주차장', H: 8.9, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .35 : Math.sin(w * Math.PI * 2), pt = p.point ?? .5, st0 = p.stoop ?? 0;
  // ---- 다리: 바지 + 장화(우비 자락 아래로만 보임)
  for (const m of [-1, 1]) {
    const st = m * S, h = [m * .42, 5.0, -.05], k = [m * .48, 2.75, .32 + st * .55], an = [m * .44, .42 + Math.max(0, -st) * .22, -.12 + st * .95];
    B.group({ k: .12, kg: .2, amp: .006, freq: 4 }); B.tube([h, V.lerp(h, k, .5), k, V.lerp(k, an, .5), an], [.42, .4, .36, .33, .3]);
    A.rings(B, [V.lerp(h, k, .7), k, V.lerp(k, an, .35)], 6, .03, .05, .5, { bow: .5, tilt: .3 }); B.ball(V.add(k, [0, 0, .2]), .26, { k: .15 });
    // 장화: 통 + 발등 + 밑창, 위 테두리 접힘
    const top = V.add(an, [0, 1.15, -.02]), fd = V.norm([m * .12, 0, 1]), F = new Frame(an, V.norm(V.cross([0, 1, 0], fd)), [0, 1, 0], fd);
    B.group({ k: .07, kg: .05, amp: .004, freq: 5 }); B.tube([V.add(an, [0, -.2, -.05]), V.lerp(an, top, .5), top], [.36, .36, .4]); B.tube([F.p([0, -.2, -.1]), F.p([0, -.25, .35]), F.p([0, -.3, .72])], [.29, .26, .2]);
    B.box(F.at([0, -.38, .22]), [.28, .07, .62], .06); B.groove(V.add(an, [0, .45, .25]), [0, 1, .3], .025, .04, .5, { wob: .2 }); B.groove(V.add(an, [0, .7, .2]), [0, 1, -.2], .025, .04, .5, { wob: .2 });
    B.group({ k: .03, kg: .05 }); const rim = []; for (let i = 0; i <= 16; i++) { const a = i / 16 * 6.283; rim.push(V.add(top, [Math.sin(a) * .43, .04 * Math.sin(a * 3), Math.cos(a) * .43])); } B.tube(rim, .06, { per: 1 });
  }
  // ---- 몸통 틀: 굽은 등
  const lean = 30 + st0 * 10, T = I([0, 6.45, .38]).rot(lean, p.twist || 0, 0), t = v => T.p(v);
  B.group({ k: .25, kg: .3, amp: .006, freq: 3 }); B.ell(I([0, 5.1, -.02]), [.78, .55, .55]); B.ell(T.at([0, -.6, -.05]), [.82, .75, .58]); B.ell(T.at([0, .25, -.08]), [.95, .85, .66]);
  B.ell(T.at([0, .72, -.3]), [.72, .5, .55]); // 굽은 등 혹
  for (const m of [-1, 1]) B.ell(T.at([m * .86, .74, .02]), [.36, .32, .4]);
  for (let i = 0; i < 6; i++) B.groove(t([.3 * Math.sin(i * 2.4), -.9 + i * .3, .62]), T.d([.15 * Math.sin(i * 1.7), 1, .1]), .02, .035, .55, { bow: .6, wob: .2, wf: 3 }); // 앞 주름
  for (let i = 0; i < 4; i++) B.groove(t([.35 * Math.cos(i * 2.1), .2 + i * .2, -.72]), T.d([0, 1, -.3]), .02, .03, .6, { bow: -.5, wob: .2 }); // 등 주름
  // ---- 우비 자락: 허리에서 정강이까지 세로로 처진 천 줄기들(주름)
  const N = 26; for (let q = 0; q < 4; q++) { B.group({ k: .07, kg: .09, amp: .005, freq: 3 });
    for (let i = q; i < N; i += 4) { const a = i / N * 6.283, sa = Math.sin(a), ca = Math.cos(a), j = Math.sin(i * 2.7), sw = S * .25 * Math.sign(sa || 1);
      const p0 = t([sa * .8, -.75, ca * .5 - .05]), p1 = [sa * .85, 4.75, ca * .62 + .02], p2 = [sa * (1.02 + .04 * j), 3.6, ca * .78 + .02 + (ca > 0 ? Math.abs(S) * .08 : 0)], p3 = [sa * (1.2 + .1 * j), 1.95 + .14 * Math.sin(i * 1.9) + (ca > .3 ? .12 : 0), ca * (.92 + .06 * j) - .08 + sw * ca];
      B.tube([p0, p1, p2, p3], [.2, .2, .17 + .04 * Math.abs(j), .12 + .05 * Math.abs(j)]); } }
  // 앞섶 단추띠
  { const pts = [t([0, .7, .74]), t([0, 0, .74]), t([0, -.75, .6]), [0, 4.7, .74], [0, 3.6, .92], [0, 2.1, 1.06]]; B.group({ k: .04, kg: .06 }); B.tube(pts, .07); B.group({ k: .02, kg: .03 }); for (let i = 0; i < 7; i++) { const u = (i + .3) / 6.6 * 5, j = Math.floor(Math.min(4.99, u)); B.ell(Frame.along(V.add(V.lerp(pts[j], pts[j + 1], u - j), [0, 0, .06]), [0, 1, 0]), [.07, .025, .07]); } }
  // ---- 형광 조끼: 밝은 재질(어둠 속에서 먼저 보이는 옷) + 흰 반사띠
  B.group({ mat: 4, k: .06, kg: 0, amp: .004, freq: 4 }); B.ell(T.at([0, -.2, -.04]), [1.1, 1.15, .82]); B.ell(T.at([0, -.85, -.02]), [1.13, .45, .87]); B.ell(T.at([0, .55, -.28]), [.88, .55, .7]);
  for (const m of [-1, 1]) B.ell(T.at([m * 1.03, .42, 0]), [.38, .72, .66], { op: 1, k: .05 }); B.box(T.at([0, 1.22, 0]), [1.5, .42, 1.3], .05, { op: 1, k: .03 }); B.box(T.at([0, -1.68, 0]), [1.5, .45, 1.5], .05, { op: 1, k: .03 }); B.ell(T.at([0, .85, .78]), [.3, .62, .45], { op: 1, k: .05 });
  B.groove(t([0, -.5, .86]), T.x, .012, .035, 1.0, { wob: 0 }); for (let i = 0; i < 5; i++) B.groove(t([(i - 2) * .35, -.3 + .2 * Math.sin(i * 2.3), .8]), T.d([.3 * Math.sin(i * 1.3), 1, .1]), .018, .03, .45, { bow: .8, wob: .25 }); for (const m of [-1, 1]) B.groove(t([m * .95, -.6, 0]), T.d([0, 1, .2]), .02, .035, .5, { bow: .6, wob: .2 });
  const vr = y => { const e = (c, r) => { const u = (y - c) / r[1]; return u * u < 1 ? [r[0] * Math.sqrt(1 - u * u), r[2] * Math.sqrt(1 - u * u)] : [0, 0]; }; const a = e(-.2, [1.1, 1.15, .82]), b = e(-.85, [1.13, .45, .87]); return [Math.max(a[0], b[0]), Math.max(a[1], b[1])]; };
  const vx = (y, a, o = .005) => { const r = vr(y); return t([Math.sin(a) * (r[0] + o), y, -.03 + Math.cos(a) * (r[1] + o)]); };
  const band = pts => { for (let i = 0; i < pts.length - 1; i++) { const a = pts[i], b = pts[i + 1], c = V.lerp(a, b, .5), d = V.norm(V.sub(b, a)); let n = V.sub(c, t([0, 0, -.03])); n = V.norm(V.sub(n, V.mul(d, V.dot(n, d)))); B.box(new Frame(c, V.norm(V.cross(d, n)), d, n), [.075, V.len(V.sub(b, a)) * .58, .018], .014); } };
  B.group({ mat: 5, k: .008, kg: .01 }); for (const y of [-.98, -.62]) { const pts = []; for (let i = 0; i <= 34; i++) pts.push(vx(y, i / 34 * 6.283)); const sd = V.norm(T.x); for (let i = 0; i < 34; i++) { const a = pts[i], b = pts[i + 1], c = V.lerp(a, b, .5), d = V.norm(V.sub(b, a)), n = V.norm(V.cross(d, T.y)); B.box(new Frame(c, d, T.y, V.mul(n, -1)), [V.len(V.sub(b, a)) * .58, .075, .018], .014); } }
  for (const m of [-1, 1]) for (const zs of [1, -1]) { const pts = []; for (let i = 0; i <= 10; i++) pts.push(vx(-.98 + i * .145, Math.atan2(m * .4, zs * .82))); band(pts); }
  // 호루라기 줄
  B.group({ k: .02, kg: .03 }); B.tube([t([-.22, .82, .48]), t([-.3, .3, .72]), t([-.12, .05, .78])], .022); B.cone(t([-.12, .02, .8]), t([-.02, -.08, .86]), .05, .04);
  // ---- 팔: 우비 소매(팔꿈치 주름) + 너무 긴 손
  const sh = m => t([m * .98, .8, .05]);
  { // 왼팔(+x): 늘어뜨림
    const s = sh(1), e = [1.32, 5.05, .7 - S * .25], wr = [1.26, 3.45, .95 - S * .45]; B.group({ k: .12, kg: .2, amp: .005, freq: 4 }); B.tube([s, V.lerp(s, e, .5), e, V.lerp(e, wr, .55), wr], [.31, .29, .27, .27, .3]); A.rings(B, [V.lerp(s, e, .75), e, V.lerp(e, wr, .3)], 3, .016, .03, .36, { bow: 1.1, tilt: .7, wob: .3 }); B.groove(V.lerp(s, e, .3), V.sub(e, s), .02, .03, .45, { bow: -.7, wob: .3 }); A.rings(B, [V.lerp(e, wr, .75), wr], 3, .025, .04, .4);
    B.group({ mat: 2, k: .02 }); B.ball(V.add(wr, [0, -.05, 0]), .2);
    B.group({ k: .06, kg: .08 }); B.tube([V.add(wr, [0, .1, 0]), V.add(wr, [0, -.25, .03])], [.13, .12]); A.hand(B, new Frame(V.add(wr, [0, -.25, .03]), V.norm([0, .1, 1]), V.norm([.06, -1, .08]), V.norm([1, .05, 0])), 1.55, { curl: [10, 16, 22, 30], spread: 9, thin: .72, len: 1.42, vein: 1 }); }
  { // 오른팔(−x): 경광봉으로 가리킴
    const s = sh(-1), e = V.lerp([-1.45, 5.35, 1.05], [-1.5, 6.0, 1.25], pt), wr = V.lerp([-1.55, 4.55, 2.05], [-2.05, 5.6, 2.55], pt); B.group({ k: .12, kg: .2, amp: .005, freq: 4 }); B.tube([s, V.lerp(s, e, .5), e, V.lerp(e, wr, .55), wr], [.31, .29, .27, .27, .3]); A.rings(B, [V.lerp(s, e, .75), e, V.lerp(e, wr, .3)], 3, .016, .03, .36, { bow: 1.1, tilt: .7, wob: .3 }); B.groove(V.lerp(s, e, .3), V.sub(e, s), .02, .03, .45, { bow: -.7, wob: .3 });
    B.group({ mat: 2, k: .02 }); B.ball(V.add(wr, V.mul(V.norm(V.sub(wr, e)), .05)), .2);
    const fo = V.norm(V.sub(wr, e)), hw = V.add(wr, V.mul(fo, .28)), d = V.norm(V.lerp([-.35, -.6, 1], [-.55, -.15, 1], pt)); let y = V.sub(fo, V.mul(d, V.dot(fo, d))); y = V.norm(y); const z = V.mul(V.cross(d, y), -1);
    B.group({ k: .06, kg: .08 }); B.tube([wr, hw], [.13, .12]); const HF = new Frame(hw, d, y, z), s2 = 1.5; A.hand(B, HF, s2, { curl: [52, 56, 60, 64], spread: 4, thin: .8, len: 1.15, thumbOut: 14 });
    // 경광봉: 손잡이(어두운 고무) + 붉게 켜진 관
    const c = HF.p([0, .4 * s2, -.17 * s2]), a = V.add(c, V.mul(d, -.45)), b = V.add(c, V.mul(d, .35)), tip = V.add(b, V.mul(d, 1.25));
    B.group({ k: .02, kg: .02 }); B.cone(a, b, .085, .085); for (let i = 0; i < 4; i++) B.groove(V.lerp(a, b, .15 + i * .2), d, .012, .02, .12, { wob: 0 }); B.cone(V.add(a, V.mul(d, -.05)), a, .1, .1); B.cone(b, V.add(b, V.mul(d, .1)), .11, .11);
    B.group({ mat: 1, k: .02 }); B.cone(V.add(b, V.mul(d, .1)), tip, .13, .1); B.ball(tip, .1); B.group({ k: .01, kg: .02 }); B.cone(V.add(tip, V.mul(d, -.05)), V.add(tip, V.mul(d, .08)), .11, .08); }
  // ---- 목 → 앞으로 빠진 후드
  const HD = I([0, 7.55, 1.72]).rot(16 + (p.nod || 0), p.headYaw || 0, p.tilt || 0), h = v => HD.p(v);
  B.group({ k: .2, kg: .3, amp: .005, freq: 3 }); B.tube([t([0, .85, .1]), V.lerp(t([0, 1.1, .2]), h([0, -.1, -.3]), .5), h([0, -.1, -.2])], [.5, .45, .45]);
  B.group({ k: .1, kg: .18, amp: .005, freq: 3 }); B.ell(HD.at([0, .06, -.08]), [.62, .7, .74]); B.ell(HD.at([0, .2, -.55]), [.38, .5, .42]); B.tube([h([0, .55, -.55]), h([0, .6, -.82]), h([0, .4, -1.0])], [.22, .14, .06]); // 뾰족한 뒤 꼭지
  for (const m of [-1, 1]) B.tube([h([m * .55, -.3, .1]), h([m * .6, -.65, -.2]), t([m * .7, .95, .35])], [.17, .2, .22]); // 어깨로 흘러내림
  B.ell(HD.at([0, -.04, .66]), [.42, .5, .5], { op: 1, k: .06 }); // 얼굴 구멍
  for (let i = 0; i < 5; i++) B.groove(h([.3 * Math.sin(i * 2), .3 - i * .15, -.4]), HD.d([1, .3 * Math.cos(i), .4]), .02, .035, .45, { bow: .5, wob: .2 });
  B.groove(h([0, .62, 0]), [1, 0, 0], .018, .03, .7, { wob: 0 }); // 솔기
  { const rim = []; for (let i = 0; i <= 24; i++) { const a = i / 24 * 6.283; rim.push(h([Math.sin(a) * .45, -.04 + Math.cos(a) * .53, .42 - .1 * Math.cos(a) * Math.cos(a) + (Math.cos(a) > 0 ? .05 * Math.cos(a) : -.04)])); } B.group({ k: .05, kg: .08 }); B.tube(rim, .075, { per: 1 }); }
  // 조임끈 두 가닥
  B.group({ k: .02, kg: .03 }); for (const m of [-1, 1]) { B.tube([h([m * .32, -.42, .5]), h([m * .3, -.75, .52]), h([m * .26, -1.15, .55 + S * .05])], .025); B.ell(Frame.along(h([m * .26, -1.2, .55]), HD.y), [.05, .09, .05]); }
  // 후드 속: 이마는 그늘, 코·입은 검은 마스크, 창백하게 부릅뜬 두 눈만 드러남
  B.group({ mat: 2, k: .06 }); B.ell(HD.at([0, -.06, -.14]), [.46, .56, .4]);
  const FF = HD.at([0, -.05, .04]).rot(-4, 0, 0), Fc = A.face(B, FF, 1.0, { eyes: 'real', iris: .012, open: 1.25, eyeSize: 1.12, gaunt: 1.5, ears: false, age: .55, w: .92, gaze: [0, -.006], vein: false }), mf = Fc.f;
  B.group({ k: .03, kg: .035, amp: .003, freq: 8 }); B.ell(mf.at([0, -.25, .27]), [.26, .21, .17]); for (let i = 0; i < 2; i++) B.groove(mf.p([0, -.2 - i * .09, .43]), mf.d([0, 1, -.1]), .007, .008, .26, { wob: .1, bow: .4 }); for (const m of [-1, 1]) B.tube([mf.p([m * .24, -.17, .2]), mf.p([m * .29, -.08, .05]), mf.p([m * .3, -.02, -.1])], .012);
  return B;
} };
