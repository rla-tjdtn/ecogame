// 시안4 10장 인간형 — 안내원: 옛 극장 제복이 헐렁하게 걸린 마르고 키 큰 좌석 안내원. 창백한 사기 가면은 가늘게 웃고 눈구멍은 텅 비었다. 금 간 틈으로 진짜 이가 보인다. 붉은 손전등을 이쪽 얼굴에 들이대고, 다른 손엔 표 펀치.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
const I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]);
module.exports = { id: 'f10h', name: '안내원', kind: '인간형 · 10장 폐영화관', H: 9.8, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .3 : Math.sin(w * Math.PI * 2), lamp = p.lamp ?? 1;
  // ---- 다리: 가는 다리에 헐렁한 제복 바지(무릎·발목 접힘, 옆줄) + 광낸 구두
  for (const m of [-1, 1]) { const st = m * S, h = [m * .34, 4.9, -.05], k = [m * .38, 2.68, .2 + st * .42], an = [m * .36, .45 + Math.max(0, -st) * .12, -.05 + st * .75];
    B.group({ k: .12, kg: .18, amp: .005, freq: 4 }); B.tube([h, V.lerp(h, k, .5), k, V.lerp(k, an, .55), V.add(an, [0, .08, .02])], [.36, .32, .27, .26, .3]);
    A.rings(B, [V.lerp(h, k, .75), k, V.lerp(k, an, .25)], 3, .016, .03, .34, { bow: 1.4, tilt: .9, wob: .4 }); A.rings(B, [V.lerp(k, an, .75), V.add(an, [0, .1, 0])], 3, .016, .03, .3, { bow: 1.2, tilt: .6, wob: .35 }); // 접힘 주름
    B.groove(V.lerp(h, k, .3), [m * .3, 1, .5], .016, .03, .5, { bow: .8, wob: .25 }); B.groove(V.lerp(k, an, .4), [0, 1, -.4], .016, .03, .45, { bow: -.8, wob: .25 });
    B.group({ k: .02, kg: .03 }); B.tube([V.add(h, [m * .35, -.1, 0]), V.add(k, [m * .27, 0, 0]), V.add(an, [m * .27, .3, -.02])], .03); // 옆줄
    const fd = V.norm([m * .08, 0, 1]), F = new Frame(an, V.norm(V.cross([0, 1, 0], fd)), [0, 1, 0], fd); B.group({ k: .06, kg: .06 }); B.ell(F.at([0, -.2, .22]), [.22, .17, .55]); B.ell(F.at([0, -.25, .66]), [.17, .12, .22]); B.ell(F.at([0, -.15, -.1]), [.2, .18, .24]); B.box(F.at([0, -.39, .24]), [.22, .04, .66], .035); B.box(F.at([0, -.36, -.16]), [.17, .07, .14], .03); B.groove(F.p([0, -.15, .55]), F.z, .01, .018, .26, { wob: 0 }); B.tube([F.p([-.09, -.05, .24]), F.p([0, -.02, .3]), F.p([.09, -.05, .24])], .018, { k: .01 }); }
  // ---- 몸통: 앞으로 살짝 굽은 마른 몸, 헐렁한 짧은 상의
  const T = I([0, 6.55, .08]).rot(13, 0, 0), t = v => T.p(v);
  B.group({ k: .22, kg: .22, amp: .004, freq: 4 }); B.ell(I([0, 5.0, -.02]), [.6, .42, .42]); B.ell(I([0, 5.55, .02]), [.55, .5, .4]); B.ell(T.at([0, .05, 0]), [.74, 1.05, .46]); B.ell(T.at([0, .75, -.08]), [.76, .42, .44]); for (const m of [-1, 1]) B.ell(T.at([m * .78, .78, 0]), [.27, .24, .3]);
  for (const m of [-1, 1]) { B.groove(t([m * .45, .35, .42]), T.d([m * -.6, 1, .2]), .018, .035, .7, { bow: .6, wob: .3 }); B.groove(t([m * .4, -.3, .44]), T.d([m * -.5, 1, .1]), .018, .035, .6, { bow: .5, wob: .3 }); B.groove(t([m * .62, .1, .1]), T.d([0, 1, .4]), .02, .04, .6, { bow: .8, wob: .3 }); } // 헐렁한 당김 주름
  for (let i = 0; i < 4; i++) B.groove([(i - 1.5) * .25, 5.32 + .04 * Math.sin(i * 2), .4], [.25 * (i - 1.5), 1, .1], .015, .03, .4, { bow: 1, wob: .3 }); // 허리 주름
  { const rim = []; for (let i = 0; i <= 30; i++) { const a = i / 30 * 6.283, f = Math.max(0, Math.cos(a)); rim.push([Math.sin(a) * .66, 5.25 - Math.pow(f, 6) * .38 + .04 * Math.sin(a * 3), .02 + Math.cos(a) * .47]); } B.group({ k: .03, kg: .06 }); B.tube(rim, .045, { per: 1 }); }
  B.group({ k: .04, kg: .06 }); B.tube([t([0, 1.0, .44]), t([.03, .2, .5]), t([.02, -.6, .5]), [.0, 4.95, .45]], .028);
  B.group({ mat: 4, k: .01, kg: .02 }); for (const m of [-1, 1]) for (let i = 0; i < 5; i++) { const y = .62 - i * .34, z = .46 * Math.sqrt(Math.max(.1, 1 - ((y - .05) / 1.1) ** 2)) + .03; B.ell(T.at([m * (.26 - i * .025), y, z]), [.055, .055, .03]); }
  // 세운 깃 + 견장 + 어깨 장식 끈 + 명찰
  B.group({ k: .03, kg: .06 }); { const c = []; for (let i = 0; i <= 20; i++) { const a = i / 20 * 6.283; c.push(t([Math.sin(a) * .34, 1.15 + .04 * Math.cos(a), Math.cos(a) * .31 - .02])); } const c2 = c.map(q => V.add(q, [0, .2, 0])); B.tube(c, .05, { per: 1 }); B.tube(c2, .045, { per: 1 }); B.tube(c.map((q, i) => V.lerp(q, c2[i], .5)), .06, { per: 1 }); }
  for (const m of [-1, 1]) { const E = T.at([m * .72, 1.0, -.02]).rot(0, 0, m * -18); B.group({ k: .03, kg: .05 }); B.box(E, [.26, .04, .19], .035); B.ell(E.at([m * .25, 0, 0]), [.08, .05, .2]); B.group({ k: .01, kg: .02 }); for (let i = 0; i < 6; i++) { const z = (i - 2.5) * .06; B.tube([E.p([m * .3, -.02, z]), E.p([m * .36, -.15, z * 1.1]), E.p([m * .37, -.28 - .03 * Math.sin(i * 2), z * 1.15])], [.02, .018, .012], { per: 2 }); } }
  B.group({ k: .02, kg: .03 }); for (let j = 0; j < 2; j++) { const pts = []; for (let i = 0; i <= 10; i++) { const u = i / 10; pts.push(V.lerp(t([-.8, .95, .05]), t([-.28, .3, .52]), u).map((v, k2) => v + [0, -Math.sin(u * Math.PI) * (.3 + j * .2), Math.sin(u * Math.PI) * .1][k2])); } B.tube(pts, .03); A.rings(B, pts.slice(1, 9), 9, .01, .018, .06, { tilt: .4 }); }
  B.box(new Frame(t([.4, .5, .44]), [1, 0, 0], T.y, T.z).rot(0, 20, 0), [.17, .055, .02], .018);
  // ---- 팔: 헐렁한 소매(팔꿈치 주름) + 장갑 낀 긴 손
  const arm = (m, s, e, wr) => { B.group({ k: .1, kg: .18, amp: .005, freq: 4 }); B.tube([s, V.lerp(s, e, .5), e, V.lerp(e, wr, .5), wr], [.27, .25, .22, .22, .25]); A.rings(B, [V.lerp(s, e, .6), e, V.lerp(e, wr, .4)], 6, .016, .032, .32, { bow: 1.1, tilt: .7, wob: .35 }); B.groove(V.lerp(s, e, .35), V.sub(e, s), .016, .03, .4, { bow: -.8, wob: .3 }); const d = V.norm(V.sub(wr, e)); B.group({ k: .02, kg: .04 }); const cu = []; const sd = V.norm(V.cross(d, [0, 1, .3])), up = V.cross(sd, d); for (let i = 0; i <= 16; i++) { const a = i / 16 * 6.283; cu.push(V.add(V.add(wr, V.mul(d, -.1)), V.add(V.mul(sd, Math.cos(a) * .25), V.mul(up, Math.sin(a) * .25)))); } B.tube(cu, .03, { per: 1 }); B.group({ mat: 4, k: .01 }); for (let i = 0; i < 2; i++) B.ball(V.add(V.add(wr, V.mul(d, -.22 - i * .12)), V.mul(sd, -m * .25)), .04); return d; };
  const grip = (m, wr, d, ax, sz, o = {}) => { const hw = V.add(wr, V.mul(d, .14)); B.group({ k: .05, kg: .08 }); B.tube([V.add(wr, V.mul(d, -.1)), hw], [.14, .12]); let y = V.sub(d, V.mul(ax, V.dot(d, ax))); y = V.norm(y); const zc = V.cross(ax, y), z = m > 0 ? zc : V.mul(zc, -1), HF = new Frame(hw, ax, y, z); A.hand(B, HF, sz, { curl: o.curl || [50, 55, 60, 64], spread: 4, thin: .72, len: 1.25, vein: 0, thumbOut: 14 }); return HF.p([0, .44 * sz, -.17 * sz]); };
  // 오른팔(−x): 손전등을 들어 이쪽 얼굴을 비춤
  { const s = t([-.8, .82, 0]), e = V.lerp([-1.15, 5.45, .25], [-1.2, 5.5, .75], lamp), wr = V.lerp([-1.1, 4.4, 1.0], [-.8, 6.45, 1.5], lamp); const d = arm(-1, s, e, wr); const L = V.norm(V.lerp([-.15, -.55, 1], [.12, -.08, 1], lamp)), c = grip(-1, wr, d, L, 1.4, { curl: [74, 78, 82, 86] });
    const a = V.add(c, V.mul(L, -.5)), b = V.add(c, V.mul(L, .35)), hd = V.add(b, V.mul(L, .3));
    B.group({ k: .02, kg: .02 }); B.cone(a, b, .1, .1); for (let i = 0; i < 5; i++) B.groove(V.lerp(a, b, .1 + i * .08), L, .01, .02, .13, { wob: 0 }); B.cone(b, hd, .11, .16); B.cone(hd, V.add(hd, V.mul(L, .03)), .17, .17); B.cone(V.add(a, V.mul(L, -.04)), a, .08, .1); B.ball(V.add(V.lerp(a, b, .6), V.mul(V.norm(V.cross(L, [0, 1, 0])), -.1)), .04);
    B.group({ mat: 1, k: .01 }); B.ell(Frame.along(V.add(hd, V.mul(L, .2)), L), [.15, .035, .15]); }
  // 왼팔(+x): 표 펀치(긴 손잡이 둘 · 축 · 둥근 날틀 · 물린 표)
  { const s = t([.8, .82, 0]), e = [1.05, 5.5, .3 - S * .05], wr = [.95, 4.95, 1.2]; const d = arm(1, s, e, wr); const ax = V.norm([-.25, .5, 1]), c = grip(1, wr, d, ax, 1.4, { curl: [62, 66, 70, 74] });
    const up = V.norm(V.cross(ax, [1, 0, 0])), piv = V.add(c, V.mul(ax, .5)); B.group({ k: .02, kg: .02 });
    for (const q of [-1, 1]) { B.tube([V.add(V.add(c, V.mul(ax, -.5)), V.mul(up, q * .13)), V.add(V.add(c, V.mul(ax, -.1)), V.mul(up, q * .08)), V.add(piv, V.mul(up, q * .035))], [.045, .04, .035]); B.ball(V.add(V.add(c, V.mul(ax, -.52)), V.mul(up, q * .14)), .055); }
    B.ball(piv, .07); const j1 = V.add(piv, V.add(V.mul(ax, .3), V.mul(up, .07))), j0 = V.add(piv, V.add(V.mul(ax, .3), V.mul(up, -.07))); B.cone(V.add(piv, V.mul(up, .04)), j1, .05, .045); B.cone(V.add(piv, V.mul(up, -.04)), j0, .05, .045); B.ell(Frame.along(j1, up, ax), [.08, .04, .08]); B.ell(Frame.along(j0, up, ax), [.08, .03, .08]); B.cone(j1, V.add(j1, V.mul(up, -.06)), .03, .02);
    B.group({ mat: 4, k: .004 }); B.box(new Frame(V.add(V.add(piv, V.mul(ax, .42)), V.mul(V.norm(V.cross(ax, up)), -.05)), V.norm(V.cross(ax, up)), ax, up).rot(0, 0, 0), [.08, .2, .005], .004); }
  // ---- 목·머리: 길게 빠진 목, 기운 머리, 빗어 넘긴 머리결, 작은 필박스 모자
  A.neck(B, t([0, 1.0, -.02]), [0, 8.15, .62], .2, { kg: .2 }); B.group({ k: .02, kg: .04 }); for (let i = 0; i < 3; i++) B.groove([0, 7.75 + i * .15, .58 + i * .05], [0, 1, .3], .01, .018, .3, { bow: .6, wob: .2 });
  const HF = I([0, 8.62, .78]).rot(8 + (p.nod || 0), p.headYaw || 0, p.tilt ?? 14), s = 1.3, hp = v => HF.p(V.mul(v, s));
  A.face(B, HF, s, { jaw: p.jaw ?? 7, eyes: 'none', teeth: 10, nose: 'none', ears: false, gaunt: 1.4, age: .5, w: .9 });
  B.group({ k: .03, kg: .06 }); for (let i = 0; i < 22; i++) { const u = i / 21 * 2 - 1; B.tube([hp([u * .2, .4, .18]), hp([u * .27, .43, -.05]), hp([u * .29, .24, -.33]), hp([u * .22, -.02, -.38])], [.012, .02, .02, .01].map(x => x * s), { per: 3 }); }
  // 가면: 창백한 사기(밝은 재질), 가늘게 굳은 미소, 텅 빈 실눈 구멍, 이마에서 턱으로 간 금, 턱 조각 결손
  { const M = HF.at(V.mul([0, -.04, .28], s)).sc(s), mz = (x, y) => .15 * Math.sqrt(Math.max(0, 1 - (x / .29) ** 2 - (y / .43) ** 2)), ms = (x, y, d = 0) => M.p([x, y, mz(x, y) + d]);
    B.group({ mat: 2, k: .02 }); B.ell(M.at([0, .02, -.08]), [.26, .14, .06]);
    B.group({ mat: 4, k: .03, kg: 0, amp: .0012, freq: 9 }); B.ell(M, [.29, .43, .15]); B.ell(M.at([0, -.01, -.05]), [.3, .44, .06]); B.ell(M.at([0, 0, -.09]), [.27, .41, .12], { op: 1, k: .02 });
    B.ell(M.at([0, .0, .115]), [.028, .15, .04], { k: .05 }); for (const m of [-1, 1]) B.ell(M.at([m * .15, -.1, .07]), [.08, .06, .06], { k: .06 }); // 콧날·광대
    for (const m of [-1, 1]) B.ell(M.at([m * .115, .03, .02]).rot(0, 0, m * -7), [.07, .022, .2], { op: 1, k: .008 }); // 실눈 구멍
    { const pts = [-1, -.7, -.35, 0, .35, .7, 1].map(u => ms(u * .14, -.235 + Math.abs(u) ** 3 * .03, .002)); B.tube(pts, .0065 * s, { op: 1, k: .004 * s, per: 2 }); } // 가는 미소
    { const pts = [[.05, .42], [.08, .33], [.05, .24], [.1, .15], [.11, .06], [.15, -.02], [.12, -.1], [.17, -.17], [.13, -.26], [.06, -.3]].map(([x, y]) => ms(x, y, .002)); B.tube(pts, .007 * s, { op: 1, k: .003 * s, per: 1 }); B.tube([ms(.15, -.02, .002), ms(.21, .0, .002), ms(.26, .06, .002)], .005 * s, { op: 1, k: .003 * s, per: 1 }); B.tube([ms(.08, .33, .002), ms(.15, .36, .002)], .005 * s, { op: 1, k: .003 * s, per: 1 }); } // 금
    B.ell(M.at([.04, -.3, .05]).rot(0, 0, 20), [.075, .055, .3], { op: 1, k: .005 }); B.ell(M.at([-.03, -.27, .05]).rot(0, 0, -15), [.05, .04, .3], { op: 1, k: .005 }); // 결손
    B.group({ k: .01, kg: .01 }); for (const m of [-1, 1]) B.tube([M.p([m * .28, .05, -.08]), hp([m * .3, .1, -.08]), hp([m * .25, .12, -.32]), hp([0, .12, -.42])], .016 * s); }
  { const C = HF.at(V.mul([.04, .44, .03], s)).rot(-6, 0, 12); B.group({ k: .02, kg: .05 }); B.cone(C.p([0, -.05, 0]), C.p([0, .1, 0]), .32, .31); B.box(C.at([0, .5, 0]), [.6, .3, .6], .01, { op: 1, k: .03 }); B.box(C.at([0, -.42, 0]), [.6, .3, .6], .01, { op: 1, k: .02 }); B.groove(C.p([0, .2, 0]), C.y, .02, .025, .3, { wob: 0 }); B.group({ k: .01, kg: .02 }); const r = []; for (let i = 0; i <= 20; i++) { const a = i / 20 * 6.283; r.push(C.p([Math.sin(a) * .33, -.02, Math.cos(a) * .33])); } B.tube(r, .03, { per: 1 }); B.group({ mat: 4, k: .01 }); B.ball(C.p([0, .1, .33]), .05); }
  return B;
} };
