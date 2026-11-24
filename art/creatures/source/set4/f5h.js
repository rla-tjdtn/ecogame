// 시안4 5장 인간형 — 미궁지기: 황소 두개골을 투구처럼 쓴 앙상한 거인. 손목에 끊어진 족쇄 사슬, 오른손에 바닥을 긁는 큰 식칼. 미로에 갇힌 채 미로를 지키는 사냥꾼.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
const I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]);
module.exports = { id: 'f5h', name: '미궁지기', kind: '인간형 · 5장 심층 미로', H: 10, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .35 : Math.sin(w * Math.PI * 2), lean = p.lean ?? 22;
  // 사슬 고리
  const link = (c, d, up, r = .16, t = .036) => { const s = V.norm(V.cross(d, up)), pts = []; for (let i = 0; i <= 12; i++) { const a = i / 12 * 6.283; pts.push(V.add(c, V.add(V.mul(d, Math.cos(a) * r * 1.45), V.mul(s, Math.sin(a) * r)))); } B.tube(pts, t, { per: 2 }); };
  const chain = (pts, o = {}) => { B.group({ k: .006, kg: o.kg ?? .01 }); const seg = []; for (let i = 0; i < pts.length - 1; i++) { const a = pts[i], b = pts[i + 1], n = Math.max(1, Math.round(V.len(V.sub(b, a)) / .36)); for (let j = 0; j < n; j++) seg.push([V.lerp(a, b, (j + .5) / n), V.norm(V.sub(b, a))]); } seg.forEach(([c, d], i) => { const up0 = Math.abs(d[1]) > .8 ? [0, 0, 1] : [0, 1, 0]; const up = i % 2 ? V.norm(V.cross(d, up0)) : up0; link(c, d, up, o.r ?? .13, o.t ?? .034); }); };
  const cuff = (c, d, r) => { const F = Frame.along(c, d, [0, 0, 1]); B.group({ k: .02, kg: .03, amp: .006, freq: 9 }); B.tube([F.p([0, -.16, 0]), F.p([0, .16, 0])], [r, r]); for (const y of [-.17, .17]) { const pts = []; for (let i = 0; i <= 16; i++) { const a = i / 16 * 6.283; pts.push(F.p([Math.cos(a) * r, y, Math.sin(a) * r])); } B.tube(pts, .035, { per: 1 }); } for (let i = 0; i < 6; i++) { const a = i / 6 * 6.283 + .3; B.ball(F.p([Math.cos(a) * (r + .01), 0, Math.sin(a) * (r + .01)]), .045); } B.ell(F.at([r * 1.05, 0, 0]), [.08, .12, .09]); return F.p([r + .14, 0, 0]); };
  // 다리: 넓게 벌린 무거운 걸음
  for (const m of [-1, 1]) { const st = m * S, h = [m * .56, 4.75, -.15], k = [m * .72, 2.65, .35 + st * .55], an = [m * .66, .42 + Math.max(0, -st) * .22, -.25 + st * .95]; A.leg(B, h, k, an, .4, { m: .82, front: [m * .2, 0, 1] }); A.foot(B, new Frame(an, [1, 0, 0], [0, 1, 0], V.norm([m * .25, 0, 1])), 1.45, {}); }
  A.pelvis(B, I([0, 4.85, -.12]), { w: .66, d: .42 });
  // 몸통: 앞으로 굽은 앙상한 갈비통, 꺼진 배
  const TF = I([0, 6.55, .25]).rot(lean, 0, 0);
  B.group({ k: .18, kg: .26, amp: .006, freq: 4 }); B.tube([[0, 4.95, -.12], [0, 5.45, -.02], TF.p([0, -.75, -.05])], [.5, .38, .48]); A.rings(B, [[0, 5.0, .2], TF.p([0, -.6, .3])], 5, .02, .05, .7, { bow: .45 });
  A.torso(B, TF, { w: .98, d: .55, h: 1.95, n: 8, r: .042 }); B.group({ k: .15, kg: .14, amp: .004, freq: 5 }); B.ell(TF.at([0, .1, -.02]), [.99, 1.0, .58]); B.ell(TF.at([0, -.55, .05]), [.66, .4, .42]); // 갈비에 들러붙은 가죽
  A.spine(B, [[0, 5.0, -.55], TF.p([0, -.5, -.62]), TF.p([0, .4, -.66]), TF.p([0, 1.15, -.45])], .13, { n: 14, back: TF.z.map(x => -x), out: .02, k: .03 });
  // 어깨 승모근·쇄골 위 굵은 목 힘줄
  const SH = m => TF.p([m * 1.02, 1.1, .02]); B.group({ k: .2, kg: .2, amp: .006 }); for (const m of [-1, 1]) { B.tube([TF.p([m * .2, 1.4, -.25]), TF.p([m * .65, 1.25, -.15]), SH(m)], [.3, .26, .24]); B.ell(Frame.along(V.add(SH(m), [m * .08, -.1, 0]), [m * .3, -1, 0]), [.34, .42, .36]); }
  // 머리 틀: 목이 앞으로 꺾여 머리가 어깨보다 낮게 들이밀림
  const nk0 = TF.p([0, 1.25, .1]), HF = I([0, 8.55, 1.55]).rot(p.nod ?? 14, p.headYaw || 0, p.tilt ?? 0), hp = v => HF.p(v);
  A.neck(B, nk0, hp([0, -.42, -.2]), .33, { mid: V.add(V.lerp(nk0, hp([0, -.42, -.2]), .5), [0, .22, -.05]) });
  // 사람 얼굴: 위는 두개골에 덮이고 턱과 이만 보인다
  A.face(B, HF, 1.4, { jaw: p.jaw ?? 28, eyes: 'none', nose: 'none', teeth: 12, gaunt: 1.3, age: .9, ears: false, w: 1.0, vein: false, sharp: 0, toothLen: .06 });
  // 황소 두개골 투구(흰 뼈): 넓고 납작한 이마, 옆으로 난 눈구멍, 길게 좁아지는 주둥이
  B.group({ mat: 4, k: .07, kg: .05, amp: .005, freq: 6 });
  B.tube([hp([-.58, .5, .16]), hp([0, .56, .2]), hp([.58, .5, .16])], [.17, .2, .17]); B.ell(HF.at([0, .42, -.02]), [.5, .2, .42]); // 뿔 사이 뒷마루
  B.ell(HF.at([0, .2, .55]).rot(-8, 0, 0), [.46, .4, .16]); // 이마판
  for (const m of [-1, 1]) { const O = HF.at([m * .43, .0, .48]).rot(0, m * 55, 0); const rim = []; for (let i = 0; i <= 14; i++) { const a = i / 14 * 6.283; rim.push(O.p([Math.cos(a) * .17, Math.sin(a) * .14 + (Math.sin(a) > 0 ? .02 : 0), 0])); } B.tube(rim, [.05, .06, .07, .06, .05, .05, .045, .05, .05, .05, .045, .05, .06, .06, .05], { per: 1, k: .03 }); B.tube([hp([m * .42, .22, .5]), hp([m * .3, .26, .6]), hp([m * .12, .22, .66])], [.06, .05, .03], { k: .06 }); } // 눈구멍 테·눈썹뼈
  B.tube([hp([0, .02, .66]), hp([0, -.28, .76]), hp([0, -.56, .78])], [.24, .19, .14], { k: .09 }); B.ell(HF.at([0, -.2, .68]).rot(-12, 0, 0), [.28, .38, .14]); // 콧등
  for (const m of [-1, 1]) B.tube([hp([m * .34, -.1, .48]), hp([m * .25, -.38, .6]), hp([m * .15, -.62, .7])], [.1, .09, .08], { k: .07 }); // 위턱뼈
  B.ell(HF.at([0, -.68, .74]), [.19, .08, .14], { k: .05 }); // 앞니뼈 끝
  for (const m of [-1, 1]) { B.ell(HF.at([m * .47, .0, .52]).rot(0, m * 55, 0), [.13, .11, .2], { op: 1, k: .03 }); B.ell(HF.at([m * .12, -.46, .86]).rot(0, 0, m * -6), [.045, .17, .08], { op: 1, k: .02 }); for (let i = 0; i < 4; i++) B.groove(hp([m * .2, -.32 - i * .09, .63]), HF.d([0, 1, .2]), .008, .014, .07, { wob: .2 }); } // 눈구멍·콧구멍·이빨 자국
  B.groove(hp([0, -.22, .82]), HF.d([1, 0, 0]), .008, .016, .3, { wob: .1 }); // 콧뼈 이음
  for (let i = 0; i < 5; i++) B.groove(hp([-.2 + i * .08, .3 + Math.sin(i * 2.1) * .07, .7]), HF.d([1, .5 * Math.sin(i * 3), .2]), .008, .02, .12, { wob: .4, wf: 6 }); B.groove(hp([.12, .22, .72]), HF.d([.25, 1, .1]), .011, .028, .4, { wob: .5, wf: 5 }); // 금
  B.group({ mat: 2, k: .02 }); for (const m of [-1, 1]) { B.ball(hp([m * .4, .0, .46]), .11); B.ell(HF.at([m * .12, -.46, .78]), [.04, .15, .05]); }
  // 뿔: 옆으로 뻗어 앞으로 휜 굵은 뿔, 마디 고리. 왼뿔은 끝이 부러짐
  for (const m of [-1, 1]) { const hp2 = [hp([m * .5, .5, .2]), hp([m * 1.0, .62, .18]), hp([m * 1.55, .58, .42]), hp([m * 1.78, .82, .86]), hp([m * 1.66, 1.12, 1.2])], use = m > 0 ? hp2.slice(0, 4) : hp2; B.group({ mat: 4, k: .04, kg: .08, amp: .004, freq: 8 }); B.tube(use, m > 0 ? [.2, .17, .12, .09] : [.2, .17, .12, .07, .025]); A.rings(B, use.slice(0, 3), 9, .012, .03, .3, { bow: .2 }); if (m > 0) { B.ell(new Frame(hp2[3], HF.x, HF.y, HF.z).rot(20, 0, 30), [.1, .05, .1], { op: 1, k: .02 }); } }
  // 묶은 가죽끈: 두개골 → 뒤통수·턱 밑
  { const ring = []; for (let i = 0; i <= 14; i++) { const a = i / 14 * Math.PI; ring.push(hp([Math.cos(a) * .5, .12 - Math.sin(a) * .02, .22 - Math.sin(a) * .62])); } ring.reverse(); A.strap(B, ring.slice(1, -1), .06, .03, q => V.norm(V.sub(q, hp([0, .1, -.1])))); const ch = []; for (let i = 0; i <= 10; i++) { const a = i / 10 * Math.PI; ch.push(hp([Math.cos(a) * .48, -.05 - Math.sin(a) * .68, .2 - Math.sin(a) * .08])); } A.strap(B, ch.slice(1, -1), .05, .025, q => V.norm(V.sub(q, hp([0, -.2, 0])))); }
  // 뒤통수에서 늘어진 빠진 머리카락
  { const R = []; for (let i = 0; i < 22; i++) { const u = i / 21 - .5, j = Math.sin(i * 5.3); R.push([hp([u * .7, .3, -.3]), hp([u * .9, .0, -.62]), V.add(hp([u * 1.0 + j * .05, -.5, -.72]), [0, -.1, 0]), V.add(hp([u * 1.05, -.6, -.7]), [j * .08, -.6 - .4 * Math.abs(j), -.15])]); } A.hair(B, R, { r: [.03, .03, .022, .006] }); }
  // 허리: 쇠 버클 가죽 띠 + 무릎까지 늘어진 가죽 조각들
  { const bp = []; for (let i = 0; i <= 18; i++) { const a = i / 18 * 6.283; bp.push([Math.sin(a) * .74, 5.05 + .08 * Math.cos(a), -.12 + Math.cos(a) * .52]); } A.strap(B, bp, .13, .04, q => V.norm([q[0], 0, q[2] + .12])); B.group({ k: .02 }); B.box(I([0, 5.13, .43]), [.14, .12, .04], .03);
    for (let i = 0; i < 11; i++) { const a = (i / 11 - .5) * 5.6, m = Math.sign(Math.sin(a)) || 1, top = [Math.sin(a) * .76, 5.0, -.12 + Math.cos(a) * .54], st = m * S, ln = 1.55 + .3 * Math.sin(i * 2.7), bot = V.add(top, [Math.sin(a) * .28, -ln, Math.cos(a) * .25 + (Math.abs(Math.sin(a)) > .3 ? st * .3 : 0)]), d = V.sub(bot, top), out = V.norm([Math.sin(a), 0, Math.cos(a)]), F = Frame.along(V.lerp(top, bot, .5), d, out); B.group({ k: .03, kg: .02, amp: .01, freq: 5 }); B.box(F, [.2 - .03 * Math.sin(i), V.len(d) * .5, .03], .025); B.groove(F.p([0, -V.len(d) * .3, .03]), F.y, .01, .02, .2, { wob: .3 }); if (i % 3 === 0) B.ell(F.at([0, -V.len(d) * .5, 0]), [.13, .1, .1], { op: 1, k: .03 }); } }
  // 왼팔(+x): 축 늘어뜨린 팔, 족쇄에서 사슬이 바닥까지 끌림
  { const s = V.add(SH(1), [.05, -.05, 0]), e = [1.62, 5.95, .55 - S * .25], wr = [1.58, 4.35, 1.05 - S * .4]; A.arm(B, s, e, wr, .27, { m: .85 }); A.hand(B, new Frame(wr, [0, 0, 1], V.norm([.05, -1, .25]), [1, 0, 0]), 1.65, { curl: [22, 30, 26, 38], spread: 12, thin: .85, len: 1.2 }); const c0 = cuff(V.lerp(e, wr, .83), V.sub(wr, e), .2); chain([c0, V.add(c0, [.15, -1.2, -.05]), V.add(c0, [.3, -2.6, -.45]), [2.0, .28, -.4], [2.05, .1, -1.4], [1.85, .1, -2.4]]); }
  // 오른팔(−x): 큰 식칼 손잡이를 쥐고 끈다. 끊긴 사슬 몇 고리
  const wr = [-1.5, 4.45, .4 - S * .2]; { const s = V.add(SH(-1), [-.05, -.05, 0]), e = [-1.68, 6.0, .35 + S * .15]; A.arm(B, s, e, wr, .29, { m: .9 }); const HD = new Frame(wr, [0, 0, 1], V.norm([-.05, -1, -.05]), [-1, 0, 0]); A.hand(B, HD, 1.7, { curl: [62, 66, 68, 72], spread: 4, thin: .95, len: 1.1, thumbOut: 20 }); const c1 = cuff(V.lerp(e, wr, .83), V.sub(wr, e), .21); chain([c1, V.add(c1, [-.15, -.6, .05]), V.add(c1, [-.1, -.95, .25])]); }
  // 큰 식칼: 손잡이 → 넓은 날, 끝이 바닥에 닿아 긁힘
  { const G = [-1.38, 3.72, .44 - S * .2], tip = [-1.8, 1.15, -4.3], d = V.norm(V.sub(tip, G)), F0 = Frame.along(G, d, [1, 0, 0]), q = v => F0.p(v), L = V.len(V.sub(tip, G));
    B.group({ k: .02, kg: .02, amp: .006, freq: 7 }); B.tube([q([0, -.3, 0]), q([0, .9, 0])], [.1, .11]); A.rings(B, [q([0, -.2, 0]), q([0, .8, 0])], 7, .012, .025, .15, { tilt: .4 }); B.ell(F0.at([0, -.34, 0]), [.13, .07, .13]); // 손잡이·쇠머리
    B.group({ k: .02, kg: .03 }); B.box(F0.at([.12, 1.0, 0]), [.3, .07, .14], .03); // 날밑
    const bl = (y0, y1, w0, w1) => { const n = 6; for (let i = 0; i < n; i++) { const a = y0 + (y1 - y0) * i / n, b = y0 + (y1 - y0) * (i + 1) / n, ww = w0 + (w1 - w0) * (i + .5) / n; B.box(F0.at([ww * .5 - .05, (a + b) / 2, 0]), [ww * .5, (b - a) * .52, .05], .025); } };
    B.group({ k: .03, kg: .02, amp: .01, freq: 3, rid: .002, rf: 5 }); bl(1.05, L - .1, .7, 1.05); B.box(F0.at([.95, L - .2, 0]).rot(0, 0, 24), [.18, .16, .05], .025); // 끝 모서리
    B.tube([q([-.03, 1.05, .055]), q([-.03, L - .2, .055])], .03, { k: .01 }); B.tube([q([-.03, 1.05, -.055]), q([-.03, L - .2, -.055])], .03, { k: .01 }); // 등 두께
    for (let i = 0; i < 5; i++) { const y = 1.6 + i * .85, ww = .7 + .35 * (y - 1.05) / (L - 1.15); B.ell(F0.at([ww - .04, y, 0]).rot(0, 0, 10 * Math.sin(i * 2)), [.09 + .03 * Math.sin(i * 3), .07, .2], { op: 1, k: .02 }); } // 이 빠진 날
    B.ell(F0.at([.25, 1.55, 0]), [.09, .09, .2], { op: 1, k: .015 }); // 매다는 구멍
    for (let i = 0; i < 7; i++) B.groove(q([.3 + .4 * Math.sin(i * 1.9), 1.6 + i * .6, .06]), F0.d([.3 * Math.sin(i * 2.4), 1, 0]), .008, .015, .3, { wob: .3, wf: 5 }); // 긁힌 자국
    // 날 끝에 엉겨 붙은 피
    B.group({ mat: 1, k: .025, kg: .01 }); for (const zz of [.05, -.05]) B.tube([q([.86, L - 2.6, zz]), q([.92, L - 1.7, zz * 1.1]), q([.98, L - .8, zz * 1.15]), q([1.02, L - .3, zz])], [.02, .07, .08, .05]); for (let i = 0; i < 2; i++) { const e0 = q([.97 + i * .03, L - 1.6 + i * .9, .05]); B.tube([e0, V.add(e0, [0, -.1, .01]), V.add(e0, [0, -.16 - .06 * i, .015])], [.035, .03, .04]); }
  }
  return B;
} };
