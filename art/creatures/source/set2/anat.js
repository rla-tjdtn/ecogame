// v6 해부 부품: 머리·팔다리·손·발·갈비·척추·골반. 전부 Body 에 프리미티브를 쌓는다(앞 +z, 위 +y, 괴물의 왼쪽 +x).
const { V, Frame } = require('./sculpt.js');
const A = {};
const L = V.lerp, rad = Math.PI / 180;
// 팔: 어깨-팔꿈치-손목. 삼각근·이두·팔꿈치 뼈·두 갈래 아래팔(요골·척골)·손목 힘줄
A.arm = (B, s, e, w, r, o = {}) => {
  const m = o.m ?? 1, up = V.norm(V.sub(e, s)), lo = V.norm(V.sub(w, e)); let bend = V.sub(L(s, w, .5), e); bend = V.len(bend) > .05 ? V.norm(bend) : V.norm(V.cross(up, [1, 0, .2])); const side = V.norm(V.cross(up, bend));
  B.group({ k: o.k ?? r * .34, kg: o.kg ?? r * .8, amp: o.amp ?? .004, freq: 5 });
  B.tube([s, L(s, e, .3), L(s, e, .7), e], [r * 1.05, r * .92 * m, r * .78 * m, r * .72]);
  B.ell(Frame.along(L(s, e, .12), up), [r * 1.12 * m, r * 1.7, r * 1.15 * m]);
  B.ell(Frame.along(V.add(L(s, e, .5), V.mul(bend, r * .52)), up), [r * .5 * m, r * 1.9, r * .5 * m]);
  B.ell(Frame.along(V.add(L(s, e, .52), V.mul(bend, -r * .5)), up), [r * .48 * m, r * 2.0, r * .46 * m]);
  B.ball(V.add(e, V.mul(bend, -r * .4)), r * .5, { k: r * .35 }); // 팔꿈치 뼈
  B.ball(V.add(e, V.mul(side, r * .48)), r * .42, { k: r * .4 }); B.ball(V.add(e, V.mul(side, -r * .48)), r * .42, { k: r * .4 });
  if (o.det !== 0) { const md = L(s, e, .5); B.groove(V.add(md, V.mul(side, r * .35)), V.add(side, V.mul(up, .22)), r * .06, r * .09, r * 1.9, { wob: .1, wf: 3 }); B.groove(V.add(md, V.mul(side, -r * .4)), V.add(side, V.mul(up, -.3)), r * .05, r * .07, r * 1.7, { wob: .1, wf: 3 }); for (let i = 0; i < 2; i++) B.groove(V.add(e, V.mul(bend, r * .55)), V.add(up, V.mul(bend, (i - .5) * .6)), r * .06, r * .09, r * .8, { bow: .4, wob: .2, wf: 4 }); }
  if (o.wr) A.rings(B, [L(s, e, .86), e, L(e, w, .06)], 4, r * .05, r * .05, r * 1.5);
  B.group({ k: r * .2, kg: r * 1.15, amp: o.amp ?? .004, freq: 6 });
  B.tube([V.add(L(s, e, .86), V.mul(side, r * .3)), V.add(e, V.mul(side, r * .36)), V.add(L(e, w, .35), V.mul(side, r * .42)), V.add(w, V.mul(side, r * .24))], [r * .3, r * .46, r * .62 * m, r * .34]);
  B.tube([V.add(L(s, e, .86), V.mul(side, -r * .3)), V.add(e, V.mul(side, -r * .36)), V.add(L(e, w, .35), V.mul(side, -r * .3)), V.add(w, V.mul(side, -r * .24))], [r * .3, r * .46, r * .5 * m, r * .36]);
  B.tube([V.add(L(e, w, .1), V.mul(bend, r * .3)), V.add(L(e, w, .5), V.mul(bend, r * .34)), V.add(w, V.mul(bend, r * .18))], [r * .3, r * .24, r * .12]);
  B.ball(V.add(w, V.mul(side, r * .42)), r * .24, { k: r * .2 });
  return { dir: lo, bend, side };
};
// 다리: 엉덩이-무릎-발목. 넓적다리 근육 두 갈래·슬개골·종아리·정강이 능선
A.leg = (B, h, k, a, r, o = {}) => {
  const m = o.m ?? 1, up = V.norm(V.sub(k, h)), lo = V.norm(V.sub(a, k)); let f = o.front || [0, 0, 1]; f = V.norm(V.sub(f, V.mul(up, V.dot(f, up)))); const side = V.norm(V.cross(up, f));
  let f2 = o.front || [0, 0, 1]; f2 = V.norm(V.sub(f2, V.mul(lo, V.dot(f2, lo))));
  B.group({ k: o.k ?? r * .34, kg: o.kg ?? r * .8, amp: o.amp ?? .005, freq: 4 });
  B.tube([h, L(h, k, .4), L(h, k, .8), k], [r * 1.0, r * .8 * m, r * .62 * m, r * .58]);
  for (const s of [-1, 1]) B.ell(Frame.along(V.add(V.add(L(h, k, .55), V.mul(side, s * r * .44)), V.mul(f, r * .4)), up), [r * .38 * m, r * 2.2, r * .42 * m]);
  B.ell(Frame.along(V.add(L(h, k, .5), V.mul(f, -r * .42)), up), [r * .52 * m, r * 2.2, r * .4 * m]);
  if (o.det !== 0) { const md = L(h, k, .52); B.groove(V.add(md, V.mul(f, r * .3)), V.add(side, V.mul(up, .12)), r * .055, r * .1, r * 2.2, { wob: .08, wf: 3 }); for (const q of [-1, 1]) B.groove(V.add(md, V.mul(side, q * r * .55)), V.add(f, V.add(V.mul(side, q * .25), V.mul(up, .2))), r * .05, r * .08, r * 2.0, { wob: .1, wf: 3 }); for (let i = 0; i < 2; i++) B.groove(V.add(L(h, k, .9 + i * .12), V.mul(f, r * .5)), V.add(up, V.mul(f, (.5 - i) * .7)), r * .06, r * .08, r * .75, { bow: .5 * (i ? 1 : -1), wob: .15, wf: 4 }); for (let i = 0; i < 2; i++) B.groove(V.add(L(h, k, .97), V.mul(f, -r * .5)), V.add(up, V.mul(side, (i - .5) * .4)), r * .05, r * .08, r * .7, { wob: .2, wf: 4 }); }
  B.ball(V.add(k, V.mul(f, r * .48)), r * .36, { k: r * .22 }); // 슬개골
  for (const s of [-1, 1]) B.ball(V.add(k, V.mul(side, s * r * .4)), r * .34, { k: r * .3 });
  B.group({ k: r * .2, kg: r * 1.1, amp: o.amp ?? .004, freq: 5 });
  B.tube([L(h, k, .86), k, V.add(L(k, a, .35), V.mul(f2, r * .22)), V.add(L(k, a, .75), V.mul(f2, r * .12)), a], [r * .35, r * .46, r * .34, r * .26, r * .3]); // 정강이
  for (const s of [-1, 1]) B.tube([V.add(L(h, k, .85), V.add(V.mul(f, -r * .2), V.mul(side, s * r * .2))), V.add(k, V.add(V.mul(f2, -r * .25), V.mul(side, s * r * .22))), V.add(L(k, a, .32), V.add(V.mul(f2, -r * .48 * m), V.mul(side, s * r * .24))), V.add(L(k, a, .72), V.mul(f2, -r * .34)), V.add(a, V.mul(f2, -r * .3))], [r * .2, r * .3, r * .42 * m, r * .2, r * .13]);
  for (const s of [-1, 1]) B.ball(V.add(a, V.mul(side, s * r * .34)), r * .24, { k: r * .2 });
  return { dir: lo, front: f2, side };
};
// 손: F.o 손목, y 손가락 방향, z 손등 쪽, x 엄지 쪽. s = 손 길이(손목→가운뎃손가락 끝)
A.hand = (B, F, s, o = {}) => {
  const c = o.curl ?? 25, sp = o.spread ?? 7, thin = o.thin ?? 1, n = o.fingers ?? 4, len = o.len ?? 1, f = F.sc(s);
  B.group({ k: .045 * s, kg: .07 * s, amp: 0 });
  const kn = []; for (let i = 0; i < n; i++) { const u = n > 1 ? i / (n - 1) : .5; kn.push([(.5 - u) * .34, .42 - Math.abs(u - .35) * .07, .02 - Math.abs(u - .4) * .05]); }
  for (const k of kn) B.cone(f.p([k[0] * .45, .02, 0]), f.p(k), .075 * s * thin, .05 * s * thin);
  B.ell(f.at([0, .2, -.035]), [.15, .22, .05]);
  for (const k of kn) { B.tube([f.p([k[0] * .4, .04, .05]), f.p([k[0] * .75, .24, .062]), f.p([k[0], k[1], k[2] + .045])], [.014 * s, .013 * s, .022 * s], { k: .02 * s }); }
  for (let i = 0; i < n; i++) {
    const u = n > 1 ? i / (n - 1) : .5, ll = (.55 - Math.abs(u - .4) * .18) * len * (o.lens ? o.lens[i % o.lens.length] : 1), cc = Array.isArray(c) ? c[i % c.length] : c; let g = f.at(kn[i]).rot(0, 0, (.5 - u) * -sp * 2).rot(-cc * .55, 0, 0); let p = g.o;
    B.group({ k: .012 * s, kg: .03 * s });
    const seg = [.42, .32, .26], r0 = .046 * s * thin; B.ball(p, r0 * 1.25, { k: .03 * s });
    for (let j = 0; j < 3; j++) { const q = g.p([0, seg[j] * ll, 0]); B.cone(p, q, r0 * (1 - j * .16), r0 * (.82 - j * .16)); if (j < 2) B.ball(q, r0 * (1.12 - j * .14), { k: .015 * s }); else if (o.claw) { const t = g.at([0, seg[j] * ll, 0]).rot(-28, 0, 0); B.cone(q, t.p([0, o.claw, 0]), r0 * .5, .004 * s); } else B.ell(g.at([0, seg[j] * ll * .93, r0 / s * .4]), [.02, .04, .012], { k: .004 * s }); p = q; g = g.at([0, seg[j] * ll, 0]).rot(-cc * (j ? .6 : 1), 0, 0); }
  }
  if (o.thumb !== false) { const t0 = [.15, .1, -.03], g0 = f.at(t0).rot(-12, 0, -(o.thumbOut ?? 38)); B.group({ k: .02 * s, kg: .06 * s }); B.cone(f.p([.06, .02, -.02]), f.p(t0), .07 * s * thin, .065 * s * thin); let p = g0.o, g = g0; [.22, .17].forEach((l, j) => { const q = g.p([0, l * len, 0]); B.cone(p, q, .052 * s * thin * (1 - j * .2), .044 * s * thin * (1 - j * .25)); B.ball(q, .046 * s * thin * (1 - j * .3)); p = q; g = g.at([0, l * len, 0]).rot(-14, 0, 22); }); }
};
// 발: F.o 발목, z 발끝, y 위. s = 발 길이
A.foot = (B, F, s, o = {}) => {
  const f = F.sc(s), h = o.h ?? .26; B.group({ k: .08 * s, kg: .1 * s, amp: .006, freq: 8 });
  B.ell(f.at([0, -h + .1, -.16]), [.11, .12, .14]); B.tube([f.p([0, -.03, 0]), f.p([0, -.1, .22]), f.p([0, -h + .09, .42])], [.12 * s, .115 * s, .075 * s]); B.tube([f.p([.06, -h + .07, -.12]), f.p([.1, -h + .06, .3]), f.p([.08, -h + .07, .5])], [.06 * s, .05 * s, .07 * s]); B.tube([f.p([-.06, -h + .07, -.12]), f.p([-.1, -h + .07, .25]), f.p([-.12, -h + .06, .44])], [.06 * s, .05 * s, .06 * s]);
  for (let i = 0; i < 4; i++) B.tube([f.p([.06 - i * .05, -.04, .14]), f.p([.1 - i * .07, -h + .14, .48])], [.016 * s, .012 * s], { k: .02 * s });
  for (let i = 0; i < 5; i++) { const x = .1 - i * .055, z = .54 - i * .022, r = (i ? .036 : .052) * s, tl = (i ? .19 : .2) * (o.toe ?? 1); B.group({ k: .01 * s, kg: .03 * s }); B.tube([f.p([x, -h + .07, z - .06]), f.p([x * 1.08, -h + .085, z + tl * .5]), f.p([x * 1.1, -h + r / s, z + tl])], [r, r * .95, r * .9]); }
};
// 머리: F.o 두개 중심, y 정수리, z 얼굴. s = 정수리~턱 길이
A.head = (B, F, s, o = {}) => {
  const f = F.sc(s), g = o.gaunt ?? 1, jaw = o.jaw ?? 0, w = o.w ?? 1, el = o.elong ?? 1; const jf = f.at([0, -.1, -.1]).rot(jaw, 0, o.jawTwist || 0); const J = v => jf.p([v[0] * w, v[1] + .1, v[2] + .1]); const P = v => f.p([v[0] * w, v[1], v[2]]);
  B.group({ k: .07 * s, kg: o.kg ?? .08 * s, amp: o.amp ?? .004 * s, freq: 7 / s });
  B.ell(f.at([0, .14 * el, -.07]), [.315 * w, .33 * el, .4]); B.ell(f.at([0, .2 * el, .12]), [.26 * w, .2 * el, .22]);
  B.ell(f.at([0, -.08, .12]), [.2 * w, .27, .24]);
  B.tube([P([-.24, .03, .2]), P([-.12, .055, .315]), P([0, .03, .335]), P([.12, .055, .315]), P([.24, .03, .2])], [.04 * s, .045 * s, .035 * s, .045 * s, .04 * s], { k: .05 * s });
  for (const m of [-1, 1]) { B.tube([P([m * .3, -.04, -.04]), P([m * .27, -.09, .14]), P([m * .16, -.13, .28])], [.035 * s, .05 * s, .05 * s], { k: .05 * s }); }
  if (o.nose !== 'none') { B.tube([P([0, .03, .33]), P([0, -.08, .39]), P([0, -.15, .415])], [.035 * s, .034 * s, .048 * s], { k: .04 * s }); for (const m of [-1, 1]) B.ball(P([m * .045, -.165, .375]), .032 * s, { k: .03 * s }); }
  // 윗입술/윗턱
  B.tube([P([-.13, -.24, .26]), P([0, -.235, .345]), P([.13, -.24, .26])], [.045 * s, .05 * s, .045 * s], { k: .05 * s });
  // 아래턱
  if (!o.nojaw) for (const m of [-1, 1]) B.tube([P([m * .27, -.06, -.06]), J([m * .25, -.26, -.03]), J([m * .17, -.4, .12]), J([m * .06, -.46, .25])], [.055 * s, .06 * s, .05 * s, .055 * s], { k: .06 * s });
  if (!o.nojaw) B.ball(J([0, -.45, .275]), .06 * s, { k: .07 * s }); if (!o.nojaw) B.tube([J([-.12, -.34, .24]), J([0, -.33, .315]), J([.12, -.34, .24])], [.04 * s, .045 * s, .04 * s], { k: .05 * s });
  if (o.nojaw) {} else if (jaw < 12) B.ell(f.at([0, -.26, .16]), [.17 * w, .16, .16], { k: .06 * s });
  else { for (const m of [-1, 1]) B.tube([P([m * .19, -.15, .18]), V.lerp(P([m * .2, -.25, .14]), J([m * .2, -.3, .12]), .5), J([m * .17, -.38, .13])], [.035 * s, .022 * s, .035 * s], { k: .04 * s }); } // 늘어난 볼살
  if (o.ears !== false) for (const m of [-1, 1]) { B.ell(f.at([m * .325 * w, -.02, -.06]).rot(0, m * 25, 0), [.025, .085, .05], { k: .02 * s }); B.ell(f.at([m * .345 * w, -.015, -.045]).rot(0, m * 25, 0), [.015, .05, .025], { op: 1, k: .02 * s }); }
  // 파냄: 눈구멍·관자놀이·볼
  const es = o.eyeSize ?? 1; if (o.eyes !== 'skin') for (const m of [-1, 1]) B.ell(f.at([m * .125 * w, -.025, .31]).rot(0, m * 12, m * (o.eyeTilt ?? -8)), [.085 * es, (o.eyeH ?? .062) * es, .11], { op: 1, k: .045 * s });
  else for (const m of [-1, 1]) B.ell(f.at([m * .125 * w, -.03, .35]), [.08, .06, .06], { op: 1, k: .09 * s });
  for (const m of [-1, 1]) { B.ell(f.at([m * .34 * w, .06, .12]), [.06, .13, .12], { op: 1, k: .08 * s }); if (g) B.ell(f.at([m * .25 * w, -.25, .18]), [.05 * g, .11, .11], { op: 1, k: .08 * s }); }
  if (o.nose === 'skull') B.ell(f.at([0, -.13, .4]), [.05, .075, .1], { op: 1, k: .03 * s });
  if (o.mouth !== false && jaw >= 4) { const mo = Math.sin(jaw * rad) * .34; B.ell(f.at([0, -.28 - mo * .5, .3]), [.115 * w * (o.mouthW ?? 1), .02 + mo * .62, .17], { op: 1, k: .03 * s }); }
  else if (o.mouth !== false) B.tube([P([-.13, -.292, .29]), P([0, -.285, .375]), P([.13, -.292, .29])], .009 * s, { op: 1, k: .02 * s });
  // 주름(골)
  if (o.wrinkle !== false) { for (const m of [-1, 1]) { B.tube([P([m * .07, -.15, .385]), P([m * .14, -.23, .33]), P([m * .16, -.31, .27])], .008 * s, { op: 1, k: .025 * s }); B.tube([P([m * .06, -.085, .36]), P([m * .13, -.1, .34]), P([m * .19, -.08, .29])], .006 * s, { op: 1, k: .02 * s }); } for (const y of [.13, .18, .235]) B.tube([P([-.16, y, .3 - (y - .13) * .6]), P([0, y + .015, .355 - (y - .13) * .8]), P([.16, y, .3 - (y - .13) * .6])], .006 * s, { op: 1, k: .018 * s }); }
  // 눈·입 안 어둠
  if (o.eyes !== 'skin') { B.group({ mat: 2, k: .01 }); for (const m of [-1, 1]) B.ball(P([m * .12, -.025, .2]), .075 * s * es); }
  if (o.mouth !== false && jaw >= 4) { const mo = Math.sin(jaw * rad) * .34; B.group({ mat: o.mouthMat ?? 2, k: .05 }); B.ell(f.at([0, -.28 - mo * .5, .13]), [.14 * w, .05 + mo * .55, .15]); }
  if (o.eyes === 'pin') for (const m of [-1, 1]) { const ef = f.at([m * .125 * w, -.025, .265]).rot(...(o.gaze || [0, 0, 0])); B.group({ mat: o.pupil ?? 5, k: .002 }); B.ball(ef.p([0, 0, .02]), (o.pin ?? .017) * s); }
  if (o.teeth) { B.group({ mat: 4, k: .004 * s }); const N = o.teeth; for (let i = 0; i < N; i++) { const u = i / (N - 1) * 2 - 1, x = u * .125, z = .315 - u * u * .09, h = o.toothLen ?? .05, jit = Math.sin(i * 12.9) * .3 + 1; B.cone(P([x, -.262, z]), P([x * .97, -.262 - h * jit, z + .005]), .017 * s, .008 * s); B.cone(J([x * .95, -.33, z - .012]), J([x * .92, -.33 + h * jit * .8, z - .008]), .015 * s, .007 * s); } }
  return { J, P, f };
};
// 몸통: 척추 점들 + 갈비 우리. spine = [골반, 허리, 명치, 가슴, 목밑], F = 가슴 틀
A.ribs = (B, F, o = {}) => {
  const n = o.n ?? 7, w = o.w ?? .7, d = o.d ?? .45, h = o.h ?? 1.5, r = o.r ?? .045, open = o.open ?? 0;
  for (const m of [-1, 1]) for (let i = 0; i < n; i++) { const u = i / (n - 1), y = h * (.5 - u), ww = w * (.62 + .42 * Math.sin((.25 + u * .62) * Math.PI)), dd = d * (.7 + .4 * Math.sin((.2 + u * .6) * Math.PI)); const drop = .16 + .1 * u, fr = (u > .75 ? .55 : 1) * (o.front ?? 1); B.tube([F.p([m * .05, y + .05, -dd]), F.p([m * ww * .7, y + .03, -dd * .75]), F.p([m * ww, y - drop * h * .3, 0]), F.p([m * ww * (.72 + open * .5), y - drop * h * .62, dd * .78 * fr]), F.p([m * .1 * (1 + open * 5) + m * (u > .75 ? ww * .4 : 0), y - drop * h * .55, dd * (1 - open * .1) * fr])], [r * .8, r, r * 1.05, r, r * .75], { per: 3, ...(o.po || {}) }); }
};
A.torso = (B, F, o = {}) => { // 가죽 씌운 갈비통: F 가슴 틀, h 높이
  const w = o.w ?? .7, d = o.d ?? .45, h = o.h ?? 1.5; B.group({ k: o.k ?? .1, kg: o.kg ?? .2, amp: o.amp ?? .003, freq: 4 });
  B.ell(F.at([0, h * .1, 0]), [w * .93, h * .56, d * .9]); B.ell(F.at([0, h * .42, -.02]), [w * .8, h * .25, d * .75]);
  A.ribs(B, F, { ...o, r: o.r ?? .05, po: { k: .06 } });
  B.tube([F.p([0, h * .45, d * .72]), F.p([0, 0, d * .98]), F.p([0, -h * .25, d * .92])], [.05, .06, .04], { k: .06 });
  for (const m of [-1, 1]) { B.tube([F.p([m * .06, h * .5, d * .7]), F.p([m * w * .5, h * .56, d * .68]), F.p([m * w * 1.08, h * .6, 0])], [.05, .045, .06], { k: .04 }); B.ell(F.at([m * w * .5, h * .3, d * .55]).rot(0, m * 15, m * -20), [w * .36, h * .13, d * .28], { k: .1 }); }
  if (o.scap !== false) for (const m of [-1, 1]) { B.tube([F.p([m * w * .95, h * .48, -d * .5]), F.p([m * w * .4, h * .5, -d * .95]), F.p([m * w * .32, -h * .02, -d * 1.0]), F.p([m * w * .8, h * .36, -d * .7])], [.07, .06, .045, .06], { k: .06 }); }
};
A.spine = (B, pts, r, o = {}) => { // 등뼈 돌기: 곡선 따라 돌기. back = 등 방향 함수
  const n = o.n ?? 14, back = o.back || [0, 0, -1]; B.group({ k: o.k ?? .05, kg: o.kg ?? .06 }); const N = pts.length - 1; for (let i = 0; i < n; i++) { const t = i / (n - 1) * N, j = Math.min(N - 1, Math.floor(t)), p = L(pts[j], pts[j + 1], t - j), dir = V.norm(V.sub(pts[j + 1], pts[j])); let b = V.sub(back, V.mul(dir, V.dot(back, dir))); b = V.norm(b); const s = V.cross(dir, b); B.ell(Frame.along(V.add(p, V.mul(b, o.out ?? 0)), b, dir), [r * .6, r * 1.25, r * .75]); if (o.wing) for (const m of [-1, 1]) B.cone(p, V.add(p, V.add(V.mul(s, m * r * 1.6), V.mul(b, r * .3))), r * .45, r * .2); }
};
A.pelvis = (B, F, o = {}) => { const w = o.w ?? .55, d = o.d ?? .35; B.group({ k: o.k ?? .14, kg: o.kg ?? .2, amp: .012, freq: 4 }); B.ell(F.at([0, 0, -.02]), [w * .85, .34, d * .85]); for (const m of [-1, 1]) { B.tube([F.p([m * .08, .02, -d]), F.p([m * w * .75, .3, -d * .5]), F.p([m * w, .24, d * .25]), F.p([m * w * .75, .02, d * .85])], [.07, .09, .085, .06], { k: .08 }); B.ell(F.at([m * w * .45, -.18, -d * .65]), [w * .42, .26, d * .5], { k: .15 }); } B.tube([F.p([-w * .6, -.02, d * .85]), F.p([0, -.24, d * .95]), F.p([w * .6, -.02, d * .85])], [.04, .05, .04], { k: .08 }); };
// 목: 힘줄 두 줄 + 후두
A.neck = (B, a, b, r, o = {}) => { const f = o.front || [0, 0, 1], d = V.norm(V.sub(b, a)), s = V.norm(V.cross(d, f)), mid = o.mid || L(a, b, .5); B.group({ k: r * .5, kg: o.kg ?? r * .9, amp: .008, freq: 7 }); B.tube([a, mid, b], [r * 1.15, r * .85, r * .9]); for (const m of [-1, 1]) B.tube([V.add(a, V.add(V.mul(f, r * .85), V.mul(s, m * r * .2))), V.add(mid, V.add(V.mul(f, r * .55), V.mul(s, m * r * .55))), V.add(b, V.mul(s, m * r * .85))], [r * .16, r * .2, r * .22], { k: r * .18 }); if (o.adam !== false) B.ball(V.add(mid, V.mul(f, r * .82)), r * .22, { k: r * .25 }); };
A.hair = (B, roots, o = {}) => { B.group({ k: .012, kg: 0, mat: o.mat ?? 0 }); for (const pts of roots) B.tube(pts, o.r || [.02, .022, .016, .006], { per: 3 }); };
// 현재 그룹에 골(접힌 주름)을 판다
A.fold = (B, pts, r, o = {}) => B.tube(pts, r, { op: 1, k: o.k ?? r * 2.5, per: 3 });
// 끈·띠: 점들을 따라 납작한 띠
A.strap = (B, pts, w, t, up, o = {}) => { B.group({ k: .01, kg: o.kg ?? .02, mat: o.mat ?? 0 }); for (let i = 0; i < pts.length - 1; i++) { const a = pts[i], b = pts[i + 1], n = 3; for (let j = 0; j <= n; j++) B.ball(L(a, b, j / n), t, { k: t }); const f = Frame.along(L(a, b, .5), V.sub(b, a), typeof up === 'function' ? up(L(a, b, .5)) : up); B.box(f, [w, V.len(V.sub(b, a)) * .54, t], t * .8, { k: .03 }); } };
// 축을 따라 고리 주름 n개(현재 그룹)
A.rings = (B, pts, n, w, dep, R, o = {}) => { const N = pts.length - 1; for (let i = 0; i < n; i++) { const t = (i + .5 + Math.sin(i * 7.7) * .22) / n * N, j = Math.min(N - 1, Math.floor(t)), c = L(pts[j], pts[j + 1], t - j), d = V.norm(V.sub(pts[j + 1], pts[j])), tl = o.tilt ?? .18; B.groove(c, V.add(d, [Math.sin(i * 3.1) * tl, Math.cos(i * 4.7) * tl, Math.sin(i * 5.9) * tl]), w * (.8 + .4 * Math.abs(Math.sin(i * 2.3))), dep * (.6 + .6 * Math.abs(Math.sin(i * 3.7))), R, { bow: (o.bow ?? .25) * Math.sin(i * 2.9), wob: o.wob ?? .16, wf: o.wf ?? 3.5 }); } };
module.exports = A;
