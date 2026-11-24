// 시안4 6장 인간형 — 벨보이: 낡은 제복과 둥근 모자의 호텔 벨보이. 허리를 살짝 굽혀 인사한 채 굳은 너무 넓은 미소로, 마름모 열쇠패를 단 객실 열쇠를 내민다. 다른 손엔 주인 없는 낡은 가방.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
const I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]);
module.exports = { id: 'f6h', name: '벨보이', kind: '인간형 · 6장 호텔', H: 9.4, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .1 : Math.sin(w * Math.PI * 2), bow = p.bow ?? 19, off = p.offer ?? 1;
  const ring = (F, r, y, t, n = 18, o = {}) => { const pts = []; for (let i = 0; i <= n; i++) { const a = i / n * 6.283; pts.push(F.p([Math.cos(a) * r, y + (o.wob || 0) * Math.sin(a * 3), Math.sin(a) * r * (o.fz ?? 1)])); } B.tube(pts, t, { per: 1 }); };
  // 바지 다리: 주름 잡힌 통, 옆줄, 구두
  for (const m of [-1, 1]) { const st = m * S, h = [m * .36, 4.55, 0], k = [m * .38, 2.45, .12 + st * .4], an = [m * .36, .5 + Math.max(0, -st) * .15, -.05 + st * .7];
    B.group({ k: .1, kg: .14, amp: .006, freq: 4 }); B.tube([h, V.lerp(h, k, .5), k, V.lerp(k, an, .5), an], [.42, .36, .3, .27, .26]);
    for (let i = 0; i < 4; i++) B.groove(V.add(V.lerp(k, an, .82 + i * .05), [0, 0, .1]), V.norm([.2 * Math.sin(i * 2), 1, .5 * Math.cos(i)]), .012, .03, .35, { bow: .4, wob: .2 }); // 구두 위 접힘
    for (let i = 0; i < 3; i++) B.groove(V.add(V.lerp(h, k, .9 + i * .06), [0, 0, .2]), V.norm([.3 * (i - 1), 1, -.5]), .012, .03, .35, { bow: .5 }); // 무릎 뒤 당김
    B.groove(V.add(V.lerp(h, k, .3), [-m * .08, 0, .3]), [m, .3, .2], .01, .025, .45, { bow: .3 }); // 가랑이 당김
    B.group({ k: .01, kg: .02 }); B.tube([V.add(h, [m * .41, -.1, 0]), V.add(k, [m * .3, 0, 0]), V.add(an, [m * .26, .05, 0])], .025); // 옆줄
    const sf = new Frame(an, [1, 0, 0], [0, 1, 0], V.norm([m * .12, 0, 1])); B.group({ k: .08, kg: .1, amp: .004 }); B.ell(sf.at([0, -.32, .3]), [.24, .17, .55]); B.ell(sf.at([0, -.3, -.12]), [.22, .2, .28]); B.box(sf.at([0, -.45, .2]), [.25, .03, .65], .03, { k: .03 }); B.groove(sf.p([0, -.22, .45]), sf.z, .01, .02, .25, { wob: .1 }); B.groove(sf.p([0, -.3, .65]), [0, 1, 0], .008, .015, .3); // 구두
  }
  // 허리 기준으로 상체를 숙임
  const P0 = [0, 4.7, 0], Fr = I(P0).rot(bow, 0, 0), f = v => Fr.p(v);
  B.group({ k: .2, kg: .2, amp: .005, freq: 4 }); B.ell(I(P0), [.66, .42, .44]); // 엉덩이(바지)
  // 제복 상의: 짧은 재킷, 어깨 패드, 겹여밈
  B.group({ k: .2, kg: .22, amp: .006, freq: 4 }); B.ell(Fr.at([0, 1.7, -.02]), [.76, .86, .46]); B.ell(Fr.at([0, .85, .0]), [.6, .58, .42]); B.ell(Fr.at([0, .32, .0]), [.68, .2, .47]); for (const m of [-1, 1]) B.ell(Fr.at([m * .74, 2.3, -.02]), [.3, .22, .3]);
  B.groove(f([.1, 1.2, .45]), Fr.d([1, 0, .2]), .01, .03, 1.6, { wob: .05 }); // 겹여밈 선
  B.groove(f([0, .2, 0]), Fr.d([0, 1, 0]), .012, .03, .9, { wob: .02 }); // 밑단
  for (let i = 0; i < 4; i++) B.groove(f([.05 + i * .06, .8 + i * .12, .42]), Fr.d([.7, 1, .1]), .01, .025, .5, { bow: .3, wob: .2 }); // 허리 사선 주름
  for (const m of [-1, 1]) for (let i = 0; i < 3; i++) B.groove(f([m * .55, 1.9 - i * .15, .2]), Fr.d([m * .4, 1, .3]), .01, .022, .35, { bow: .5 * m }); // 겨드랑이 주름
  B.ell(Fr.at([-.42, 2.2, .3]), [.12, .3, .15], { op: 1, k: .03 }); // 해진 어깨 솔기 구멍
  // 단추 두 줄(하나 빠지고 하나는 실에 매달림), 견장, 가슴 명찰
  { const bz = (x, y) => { const c = y > 1.2 ? [1.7, .86, .46, .76] : [.85, .58, .42, .6]; const u = (y - c[0]) / c[1], vx = x / c[3]; return .02 + c[2] * Math.sqrt(Math.max(.05, 1 - u * u - vx * vx)); }; B.group({ mat: 4, k: .01, kg: .02 }); for (const m of [-1, 1]) for (let i = 0; i < 5; i++) { const y = .75 + i * .32, x = m * (.26 - i * .015); if (m > 0 && i === 2) continue; B.ell(Fr.at([x, y, bz(x, y)]), [.055, .055, .03]); }
    B.group({ k: .006 }); const hb = f([.25, 1.39, bz(.25, 1.39)]); B.tube([hb, V.add(hb, Fr.d([.02, -.12, .05])), V.add(hb, Fr.d([.04, -.24, .04]))], .008); B.group({ mat: 4, k: .006 }); B.ell(I(V.add(hb, Fr.d([.04, -.28, .05]))), [.05, .05, .03]);
    B.group({ k: .02, kg: .04 }); B.box(Fr.at([-.34, 1.95, bz(-.34, 1.95) - .01]).rot(-12, -18, 0), [.16, .05, .02], .015); }
  for (const m of [-1, 1]) { B.group({ k: .02, kg: .05 }); B.box(Fr.at([m * .58, 2.47, 0]).rot(0, 0, m * -12), [.24, .035, .18], .03); for (let i = 0; i < 5; i++) B.tube([f([m * .82, 2.42, -.16 + i * .08]), f([m * .86, 2.28, -.16 + i * .08])], .018, { k: .01 }); } // 견장
  // 높은 깃 + 너무 긴 목
  const nb = f([0, 2.55, -.02]); B.group({ k: .02, kg: .06 }); B.tube([nb, f([0, 2.78, .0])], [.31, .3]); ring(Fr.at([0, 0, .0]), .31, 2.79, .025); B.groove(f([0, 2.68, .3]), Fr.d([1, 0, 0]), .008, .02, .12);
  const HF = Fr.at([0, 3.72, .18]).rot(-bow - 4 + (p.nod ?? 0), p.headYaw || 0, p.tilt ?? 19), s = 1.45, hp = v => HF.p(V.mul(v, s));
  A.neck(B, f([0, 2.6, 0]), hp([0, -.3, -.05]), .2, { kg: .1 });
  // 얼굴: 부릅뜬 눈, 광대까지 당겨 올라간 너무 넓은 미소(입꼬리가 볼을 파고듦)
  A.face(B, HF, s, { jaw: p.jaw ?? 4, eyes: 'real', open: 1.15, iris: .015, eyeSize: 1.0, gaze: [0, -.003], gaunt: .9, age: .55, teeth: 0, mouthW: .9, w: .95, lips: .45, vein: false });
  const SM = t => { const x = t * .27, y = -.262 + .11 * Math.pow(Math.abs(t), 2.2), z = .372 - .19 * t * t; return [x * .95, y, z]; };
  B.group({ k: .03 * s, kg: .05 * s }); for (const m of [-1, 1]) B.ell(HF.at(V.mul([m * .2, -.13, .27], s)).rot(0, m * 25, m * -30), [.075 * s, .045 * s, .05 * s]); // 들어 올린 광대 살
  B.group({ k: .01 * s, kg: .02 * s }); { const pts = []; for (let i = 0; i <= 12; i++) pts.push(hp(SM(i / 6 - 1))); B.tube(pts, pts.map((_, i) => (.022 - .012 * Math.pow(Math.abs(i / 6 - 1), 3)) * s), { op: 1, per: 2 }); for (const m of [-1, 1]) B.tube([hp(SM(m)), hp([m * .28, -.12, .16]), hp([m * .29, -.06, .1])], [.008 * s, .006 * s, .002 * s], { op: 1 }); }
  B.group({ mat: 2, k: .01 * s }); { const pts = []; for (let i = 0; i <= 12; i++) pts.push(hp(V.add(SM(i / 6 - 1), [0, 0, -.04]))); B.tube(pts, .02 * s, { per: 2 }); }
  B.group({ mat: 4, k: .002 }); for (let i = 0; i < 22; i++) { const t = (i + .5) / 22 * 2 - 1, c = SM(t), c2 = SM(Math.min(1, t + .02)), d = V.norm(V.sub(hp(c2), hp(c))), F = new Frame(hp(V.add(c, [0, 0, -.012])), d, HF.y, V.norm(V.cross(d, HF.y))); B.box(F.at([0, .009 * s, 0]), [.0105 * s, .014 * s, .006 * s], .004 * s); B.box(F.at([0, -.011 * s, 0]), [.0095 * s, .011 * s, .006 * s], .004 * s); } // 위아래 꽉 다문 이
  // 둥근 모자(필박스), 턱끈
  { const C = HF.at(V.mul([.04, .4, -.02], s)).rot(-10, 0, -12), r = .23 * s; B.group({ k: .02, kg: .04 * s, amp: .003 }); B.tube([C.p([0, .1, 0]), C.p([0, .37, 0])], [r, r * .97]); B.box(C.at([0, -.3, 0]), [.6, .38, .6], .01, { op: 1, k: .02 }); B.box(C.at([0, .7, 0]), [.6, .33, .6], .01, { op: 1, k: .02 }); B.ell(C.at([0, .36, 0]), [r * .97, .02, r * .97], { k: .02 }); ring(C, r + .01, .12, .03); ring(C, r * .97 + .01, .34, .025); ring(C, r + .015, .2, .012, 22); for (let i = 0; i < 5; i++) B.groove(C.p([Math.cos(i * 1.3) * r, .15, Math.sin(i * 1.3) * r]), C.y, .006, .015, .08, { wob: .3 }); B.group({ mat: 4, k: .01 }); B.ell(C.at([0, .24, r + .01]), [.05, .05, .02]);
    B.group({ k: .006, kg: .01 }); const ch = []; for (let i = 0; i <= 10; i++) { const a = i / 10 * Math.PI; ch.push(HF.p(V.mul([Math.cos(a) * .27, -.08 - Math.sin(a) * .44, .08 + Math.sin(a) * .08], s))); } B.tube(ch, .014 * s, { per: 2 }); }
  // 머리카락: 기름 바른 짧은 머리, 모자 밑으로 몇 가닥
  { const R = []; for (let i = 0; i < 18; i++) { const m = i % 2 ? 1 : -1, u = i / 18, j = Math.sin(i * 4.7); R.push([hp([m * (.12 + u * .1), .44, -.15 + j * .1]), hp([m * (.3 + .01 * j), .3, -.12 + j * .08]), hp([m * (.32 + .01 * j), .1, -.15 + j * .08])]); } A.hair(B, R, { r: [.025, .022, .008] }); }
  // 소매: 천 통 + 팔꿈치 주름 + 소맷단 두 줄
  const sleeve = (sh, e, wr) => { B.group({ k: .08, kg: .14, amp: .006, freq: 4 }); B.tube([sh, V.lerp(sh, e, .5), e, V.lerp(e, wr, .5), wr], [.27, .23, .21, .2, .21]); const d = V.norm(V.sub(wr, e)); for (let i = 0; i < 4; i++) B.groove(V.lerp(sh, e, .85 + i * .06), V.norm(V.add(V.sub(e, sh), [Math.sin(i * 2.3) * .6, .2, Math.cos(i * 3) * .6])), .01, .028, .3, { bow: .4, wob: .2 }); const F = Frame.along(wr, d, [0, 0, 1]); B.group({ k: .01, kg: .02 }); ring(F, .215, -.2, .018); ring(F, .215, -.1, .018); B.group({ k: .01, kg: .02 }); B.tube([F.p([0, -.02, 0]), F.p([0, .05, 0])], [.19, .17]); };
  // 오른팔: 열쇠를 내민 손(손등 위, 엄지·검지로 고리를 집음)
  { const sh = f([-.8, 2.28, 0]), e = [-1.02, 5.75 + .1 * (1 - off), .35], wr = V.lerp([-.98, 4.6, .55], [-.62, 5.62, 1.6], off); sleeve(sh, e, wr); const fd = V.norm(V.lerp([0, -1, .3], [.18, -.12, 1], off)), up = V.norm(V.lerp([-1, 0, 0], [0, 1, 0], off)); const HD = new Frame(wr, V.norm(V.cross(fd, up)).map(x => -x), fd, up); A.hand(B, HD, 1.35, { curl: [38, 60, 70, 76], spread: 5, thin: 1.08, len: 1.05, vein: 0, thumbOut: 18 });
    // 열쇠: 고리 → 열쇠 → 다이아몬드 열쇠패
    const k0 = HD.p([.1 * 1.35, .52 * 1.35, -.06 * 1.35]); B.group({ mat: 4, k: .006, kg: .01 }); { const r0 = []; for (let i = 0; i <= 12; i++) { const a = i / 12 * 6.283; r0.push(V.add(k0, [Math.cos(a) * .09, -.09 + Math.sin(a) * .09, 0])); } B.tube(r0, .014, { per: 1 }); }
    const kt = V.add(k0, [0, -.2, 0]); B.tube([kt, V.add(kt, [0, -.08, 0])], .03); { const rb = []; for (let i = 0; i <= 12; i++) { const a = i / 12 * 6.283; rb.push(V.add(kt, [Math.cos(a) * .065, -.12 + Math.sin(a) * .06, 0])); } } B.ell(I(V.add(kt, [0, -.06, 0])), [.075, .065, .02]); B.tube([V.add(kt, [0, -.13, 0]), V.add(kt, [0, -.5, 0])], .02); for (let i = 0; i < 3; i++) B.box(I(V.add(kt, [.035, -.36 - i * .05, 0])), [.03, .015, .012], .006);
    const ft = V.add(kt, [0, -.55, 0]); B.group({ mat: 4, k: .006 }); { const r1 = []; for (let i = 0; i <= 10; i++) { const a = i / 10 * 6.283; r1.push(V.add(ft, [Math.cos(a) * .05, -.05 + Math.sin(a) * .05, 0])); } B.tube(r1, .011, { per: 1 }); }
    B.group({ mat: 1, k: .02, kg: .01 }); const FB = I(V.add(ft, [0, -.42, 0])).rot(0, 20, 45); B.box(FB, [.24, .24, .035], .04); B.group({ mat: 1, k: .004 }); B.ell(I(V.add(ft, [0, -.14, 0])), [.035, .035, .06], { op: 1 }); for (let i = 0; i < 3; i++) B.groove(V.add(ft, [-.08 + i * .08, -.42, .04]), [.3, 1, 0], .008, .015, .06, { wob: 0 }); }
  // 왼팔: 늘어뜨려 낡은 여행 가방을 든다
  { const sh = f([.8, 2.28, 0]), e = [1.05, 5.65, -.1], wr = [1.08, 4.05, .02]; sleeve(sh, e, wr); A.hand(B, new Frame(wr, [0, 0, 1], V.norm([.04, -1, .02]), [1, 0, 0]), 1.35, { curl: [70, 76, 80, 84], spread: 3, thin: 1.08, len: 1.05, vein: 0, thumbOut: 14 });
    const hd = [1.15, 3.45, .08], C = I([1.18, 2.72, .08]); B.group({ k: .02, kg: .03 }); B.tube([V.add(hd, [0, -.12, -.24]), V.add(hd, [0, .08, -.18]), V.add(hd, [0, .14, 0]), V.add(hd, [0, .08, .18]), V.add(hd, [0, -.12, .24])], .045); // 손잡이
    B.group({ k: .03, kg: .03, amp: .008, freq: 4 }); B.box(C, [.2, .6, .82], .07); B.ell(C.at([.2, .1, .3]), [.08, .2, .22], { op: 1, k: .1 }); // 찌그러진 면
    B.groove(C.p([0, .45, 0]), [0, 1, 0], .012, .025, 1.2, { wob: .02 }); // 뚜껑 이음
    for (const z of [-.45, .45]) { B.group({ k: .01, kg: .02 }); const pts = []; for (let i = 0; i <= 16; i++) { const a = i / 16 * 6.283; pts.push(C.p([Math.cos(a) * .225 * (Math.abs(Math.cos(a)) > .7 ? 1 : 1), Math.sin(a) * .63, z])); } B.tube(pts, .03, { per: 1 }); B.box(C.at([.23, .38, z]), [.02, .06, .07], .01); } // 가죽끈·버클
    B.group({ mat: 4, k: .01 }); for (const sx of [-1, 1]) for (const sy of [-1, 1]) for (const sz of [-1, 1]) B.ball(C.p([sx * .17, sy * .56, sz * .78]), .045); for (const z of [-.25, .25]) B.box(C.at([.21, .5, z]), [.02, .06, .05], .01); // 모서리 쇠·잠금쇠
    B.group({ k: .006 }); B.tube([C.p([.22, .5, .3]), C.p([.24, .3, .45]), C.p([.22, .05, .4])], .012); // 끊어진 이름표 끈
  }
  return B;
} };
