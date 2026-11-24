// 시안4 1장 비인간형 — 추적견: 시설 경비용으로 길러진 가죽 없는 사냥개. 눈 자리는 처음부터 없고 콧구멍 틈으로만 사냥한다. 앞다리가 너무 길어 어깨가 사람 머리 높이에 온다. 목에는 아직 시설 목줄과 인식표.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
const I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]);
module.exports = { id: 'f1n', name: '추적견', kind: '비인간형 · 1장 지하 시설', H: 6.2, build(p = {}) {
  const B = new Body(), w = p.walk ?? .25, ph = w * Math.PI * 2, low = p.low ?? 0, jaw = p.jaw ?? 18;
  const ring = (c, d, r, t, o = {}) => { const F = Frame.along(c, d, o.front || [0, 0, 1]); const pts = []; for (let i = 0; i <= 22; i++) { const a = i / 22 * 6.283; pts.push(F.p([Math.cos(a) * r * (o.fx ?? 1), .01 * Math.sin(i * 2.7), Math.sin(a) * r])); } B.group({ k: .02, kg: o.kg ?? .04, mat: o.mat ?? 0 }); B.tube(pts, t, { per: 1 }); };
  // ── 몸: 높은 어깨에서 낮은 엉덩이로 비탈진 등
  const wi = [0, 5.35 - low * .6, 1.15], th = [0, 4.55 - low * .4, -.2], lu = [0, 3.65 - low * .2, -1.35], pv = [0, 3.15, -2.25];
  // 가슴통: 가죽 없는 근육 위로 갈비가 드러남
  const CF = new Frame(V.lerp(wi, th, .45), [1, 0, 0], V.norm(V.sub(wi, lu)), null); CF.z = V.cross(CF.x, CF.y); const C0 = CF.at([0, 0, .0]);
  B.group({ k: .2, kg: .2, amp: .01, freq: 4 }); B.ell(C0.at([0, -.1, .3]), [.5, 1.1, .85]); B.ell(C0.at([0, .7, .15]), [.55, .55, .7]);
  B.group({ k: .05, kg: .1 }); A.ribs(B, C0.at([0, -.1, .42]), { n: 9, w: .6, d: .85, h: 1.9, r: .055 });
  B.group({ k: .16, kg: .2, amp: .012, freq: 4 }); B.tube([th, lu, pv], [.55, .4, .5]); B.ell(I(V.add(lu, [0, -.12, .1])), [.36, .3, .7]);
  // 엉덩이·뒷다리 근육
  A.pelvis(B, I(V.add(pv, [0, .05, 0])).rot(-20, 0, 0), { w: .5, d: .45 });
  // 등뼈 돌기
  A.spine(B, [V.add(wi, [0, .35, -.1]), V.add(th, [0, .5, 0]), V.add(lu, [0, .42, 0]), V.add(pv, [0, .45, -.1]), [0, 2.95, -3.0]], .13, { n: 19, back: [0, 1, 0], out: .02, wing: 1 });
  // 근육 판: 등심·어깨·목·배 — 결이 보이는 가죽 벗긴 살
  for (const m of [-1, 1]) {
    A.muscle(B, V.add(wi, [m * .22, .25, -.15]), V.add(pv, [m * .25, .32, .2]), .2, { n: 9, up: [0, 1, 0], tw: .1 });
  }
  // ── 다리: 뒷다리는 개의 굽은 뒷다리, 앞다리는 사람 팔처럼 너무 길다
  for (const m of [-1, 1]) {
    const s = Math.sin(ph + (m > 0 ? 0 : Math.PI)), s2 = Math.sin(ph + (m > 0 ? Math.PI : 0)) ;
    // 뒷다리
    const h = V.add(pv, [m * .5, -.15, -.05]), k = [m * .6, 1.95, -1.55 + s * .35], hk = [m * .55, 1.05 + Math.max(0, s) * .25, -2.55 + s * .45], pw = [m * .55, .2 + Math.max(0, s) * .3, -2.2 + s * .7];
    A.leg(B, h, k, hk, .3, { m: 1.1, front: [0, -.3, 1] }); A.muscle(B, V.add(pv, [m * .4, .35, -.2]), V.add(k, [0, .1, .1]), .3, { n: 10, up: [m, 0, 0], tw: .3 }); A.muscle(B, V.add(pv, [m * .38, .1, -.5]), V.add(k, [0, -.1, -.25]), .26, { n: 9, up: [m, 0, 0], tw: -.3 }); B.group({ k: .06, kg: .1 }); B.tube([hk, V.lerp(hk, pw, .5), pw], [.17, .12, .13]); B.ball(V.add(hk, [0, .05, -.14]), .14);
    A.muscle(B, V.add(hk, [0, .1, -.12]), V.add(k, [0, -.1, -.2]), .14, { n: 6, up: [m, 0, 0] });
    A.hand(B, new Frame(pw, [-m, 0, 0], V.norm([0, -.25, 1]), V.norm([0, 1, .25])), .85, { curl: [-6, 4, 0, 8], spread: 6, thumb: false, claw: .1, thin: 1.25, vein: 0 });
    // 앞다리: 어깨뼈 → 팔꿈치(뒤로) → 손목 → 길쭉한 손가락 발
    const sh = V.add(wi, [m * .62, -.75, .2]), el = [m * .72, 3.15 - low * .5, .55 + s2 * .3], wr = [m * .64, .95 + Math.max(0, s2) * .35, 1.55 + s2 * .65];
    B.group({ k: .1, kg: .14 }); B.ell(Frame.along(V.add(wi, [m * .5, -.35, -.05]), V.sub(sh, V.add(wi, [m * .4, .3, -.3])), [m, 0, 0]), [.12, .62, .4]);
    A.arm(B, sh, el, wr, .31, { m: 1.1 }); A.muscle(B, V.lerp(el, wr, .05), V.lerp(el, wr, .6), .17, { n: 7, up: [m, 0, 0], tw: .5 }); A.muscle(B, V.add(wi, [m * .45, .1, -.3]), V.lerp(sh, el, .5), .2, { n: 7, up: [m, 0, 0], tw: .4 });
    const pa = V.add(wr, [0, -.72, .35]); B.group({ k: .05, kg: .1 }); B.tube([wr, V.lerp(wr, pa, .5), pa], [.15, .12, .12]);
    A.hand(B, new Frame(pa, [-m, 0, 0], V.norm([0, -.35, 1]), V.norm([0, 1, .35])), 1.25, { curl: [-12, 2, -6, 8], spread: 10, thumb: false, claw: .15, thin: 1.15, len: 1.35, vein: 0 });
  }
  // ── 목: 가죽 없는 굵은 목 근육, 머리는 땅 가까이로 늘어뜨림
  const HF = I([0, 3.75 - low * .9, 3.15 + low * .2]).rot(32 + low * 18 + (p.nod || 0), p.headYaw || 0, p.tilt ?? 6).sc(1.3), hd = v => HF.p(v);
  for (const m of [-1, 1]) { A.muscle(B, V.add(wi, [m * .3, .2, -.2]), hd([m * .22, .22, -.35]), .27, { n: 9, up: [m, .3, 0], tw: .2 }); A.muscle(B, V.add(th, [m * .4, -.5, 1.0]), hd([m * .2, -.32, -.1]), .19, { n: 7, up: [m, 0, 0], tw: -.2 }); }
  B.group({ k: .2, kg: .2 }); B.tube([V.add(wi, [0, -.15, .1]), V.lerp(V.add(wi, [0, -.15, .2]), hd([0, 0, -.3]), .5), hd([0, -.05, -.3])], [.42, .34, .3]);
  // 기관(목 아래 드러난 숨관)
  B.group({ k: .03, kg: .05 }); { const a = V.add(th, [0, -.4, 1.2]), b = hd([0, -.42, .05]); B.tube([a, V.add(V.lerp(a, b, .5), [0, -.15, 0]), b], .09); A.rings(B, [a, V.add(V.lerp(a, b, .5), [0, -.15, 0]), b], 12, .015, .025, .12, { tilt: .02, bow: 0 }); }
  // ── 머리: 눈 없는 긴 개 두개골, 콧구멍 틈
  B.group({ k: .14, kg: .16, amp: .006, freq: 6 }); B.ell(HF.at([0, .04, -.12]), [.4, .38, .52]); B.ell(HF.at([0, .2, .05]), [.24, .22, .4]); B.ell(HF.at([0, -.04, .55]), [.25, .23, .52]); B.ell(HF.at([0, -.06, .98]), [.19, .17, .3]);
  B.tube([hd([0, .38, -.45]), hd([0, .42, -.05]), hd([0, .3, .3])], [.04, .06, .03], { k: .06 }); // 정수리 능선
  for (const m of [-1, 1]) B.tube([hd([m * .25, -.2, .15]), hd([m * .24, -.21, .6]), hd([m * .17, -.2, 1.05]), hd([m * .08, -.2, 1.25])], [.09, .1, .08, .06], { op: 1, k: .04 }); // 젖혀진 입술: 잇몸 드러냄
  for (let i = 0; i < 9; i++) { const a = -1 + i * .25; B.groove(hd([Math.sin(a) * .3, .3, -.15]), HF.d([Math.cos(a), 0, -Math.sin(a) * .3]), .008, .02, .35, { bow: .4, wob: .2, wf: 3 }); } // 가죽 없는 두피 결
  for (const m of [-1, 1]) { B.ell(HF.at([m * .27, .1, .28]).rot(0, m * 30, 0), [.07, .08, .12], { op: 1, k: .1 }); B.tube([hd([m * .36, -.05, -.15]), hd([m * .35, -.12, .12]), hd([m * .24, -.2, .4])], [.06, .07, .05], { k: .07 }); } // 눈 자리: 매끈한 오목
  // 콧구멍 틈(콧등 끝에 비스듬한 두 줄)
  B.ball(hd([0, -.03, 1.27]), .12, { k: .06 }); for (const m of [-1, 1]) B.tube([hd([m * .03, .0, 1.37]), hd([m * .08, .06, 1.27]), hd([m * .1, .1, 1.13])], [.012, .022, .01], { op: 1, k: .012 }); B.groove(hd([0, -.06, 1.36]), HF.x, .01, .02, .1, { wob: 0 });
  for (let i = 0; i < 5; i++) B.groove(hd([0, .2 - i * .01, .2 + i * .12]), HF.d([0, .2, 1]), .01, .018, .3, { bow: .5, wob: .1 });
  // 가죽 없는 볼 근육(교근·측두근)
  for (const m of [-1, 1]) { A.muscle(B, hd([m * .3, .36, -.3]), hd([m * .33, -.25, .22]), .1, { n: 8, up: [m, 0, 0], tw: .2 }); A.muscle(B, hd([m * .3, -.05, -.25]), hd([m * .25, -.28, .5]), .08, { n: 6, up: [m, 0, 0], tw: -.2 }); }
  // 귀: 짧게 잘린 그루터기 + 귀표
  for (const m of [-1, 1]) { B.group({ k: .04, kg: .08 }); B.ell(HF.at([m * .3, .34, -.42]).rot(-50, m * 20, m * -40), [.1, .05, .16]); B.groove(hd([m * .38, .42, -.4]), HF.d([0, 1, .3]), .01, .02, .12, { wob: .3, wf: 8 }); }
  B.group({ k: .01, kg: .02 }); B.box(HF.at([.42, .5, -.4]).rot(0, 0, -25), [.02, .08, .06], .015); B.ball(hd([.4, .58, -.4]), .03, { op: 1, k: .01 });
  // 아래턱: 벌어짐
  const JF = HF.at([0, -.2, .0]).rot(jaw, 0, 0), jd = v => JF.p(v);
  B.group({ k: .08, kg: .1 }); for (const m of [-1, 1]) B.tube([jd([m * .26, .05, -.1]), jd([m * .2, -.08, .4]), jd([m * .11, -.08, .95]), jd([m * .04, -.07, 1.15])], [.09, .085, .07, .06]); B.ell(JF.at([0, -.07, .55]), [.18, .11, .5]); B.ell(JF.at([0, -.08, 1.0]), [.1, .08, .18]);
  // 입: 젖혀진 입술, 붉은 잇몸과 혀(이 괴물의 붉은 곳 하나)
  B.group({ mat: 2, k: .04 }); B.ell(HF.at([0, -.26, .55]), [.17, .06 + jaw * .004, .6]);
  B.group({ mat: 1, k: .03, kg: .03 }); for (const m of [-1, 1]) { B.tube([hd([m * .2, -.2, .2]), hd([m * .19, -.22, .6]), hd([m * .12, -.21, 1.05]), hd([m * .05, -.2, 1.2])], .035); B.tube([jd([m * .19, .0, .25]), jd([m * .14, .0, .7]), jd([m * .05, .0, 1.1])], .03); } { const t0 = jd([.14, .02, 1.0]); B.tube([jd([0, .0, .3]), jd([.03, .03, .7]), t0, V.add(t0, [.08, -.3, .12]), V.add(t0, [.1, -.6, .1]), V.add(t0, [.08, -.78, .02])], [.09, .085, .075, .06, .045, .025]); }
  B.group({ mat: 4, k: .004 }); for (const m of [-1, 1]) for (let i = 0; i < 7; i++) { const t = i / 6, z = .3 + t * .88, x = m * (.21 - t * .14), L = i === 6 ? .2 : i === 5 ? .11 : .08 + .025 * Math.sin(i * 3); B.cone(hd([x, -.22, z]), hd([x * 1.02, -.22 - L, z + .02]), .025 + (i === 6 ? .015 : 0), .004); const L2 = i === 6 ? .14 : .05 + .02 * Math.cos(i * 2); B.cone(jd([x * .95, .0, z - .03]), jd([x * .95, L2, z - .01]), .022 + (i === 6 ? .012 : 0), .004); }
  // ── 시설 목줄: 두꺼운 가죽띠, 버클, 인식표, 끊어진 사슬
  const NC = V.lerp(V.add(wi, [0, -.15, .2]), hd([0, -.05, -.3]), .55), ND = V.norm(V.sub(hd([0, -.05, -.3]), V.add(wi, [0, -.15, .2])));
  { const F = Frame.along(NC, ND, [0, -1, 0]); B.group({ k: .02, kg: .04 }); for (let i = 0; i < 26; i++) { const a = i / 26 * 6.283, a2 = (i + 1) / 26 * 6.283, r = .52; const q0 = F.p([Math.cos(a) * r, 0, Math.sin(a) * r]), q1 = F.p([Math.cos(a2) * r, 0, Math.sin(a2) * r]); B.box(Frame.along(V.lerp(q0, q1, .5), V.sub(q1, q0), V.norm(V.sub(V.lerp(q0, q1, .5), NC))), [.14, V.len(V.sub(q1, q0)) * .55, .035], .02); }
    for (let i = 0; i < 8; i++) { const a = i / 8 * 6.283 + .2; B.ball(F.p([Math.cos(a) * .56, 0, Math.sin(a) * .56]), .03); }
    const bk = F.p([0, 0, .56]); B.box(new Frame(bk, F.x, F.y, F.z), [.1, .1, .03], .02); B.box(new Frame(bk, F.x, F.y, F.z), [.06, .06, .05], .01, { op: 1 });
    const dr = F.p([0, -.02, .6]); ring(V.add(dr, F.d([0, 0, .05])), F.x, .08, .02, { front: F.z }); const tg = V.add(dr, F.d([0, 0, .17])); B.group({ k: .01, kg: .02 }); B.box(Frame.along(V.add(tg, [0, -.14, 0]), [0, 1, 0], [0, 0, 1]).rot(0, 20, 0), [.13, .17, .02], .03); for (let i = 0; i < 3; i++) B.groove(V.add(tg, [0, -.08 - i * .06, .02]), [0, 1, 0], .006, .008, .07, { wob: 0 });
    // 끊어진 사슬 세 고리
    let c = V.add(dr, F.d([0, 0, .12])); for (let i = 0; i < 3; i++) { const d = V.norm([.15 * Math.sin(i), -1, .2]); c = V.add(c, V.mul(d, .14)); ring(c, i % 2 ? [1, 0, 0] : [0, 0, 1], .07, .022, { fx: 1.6 }); } }
  // 꼬리: 잘린 뭉툭한 그루터기 + 꿰맨 자국
  B.group({ k: .06, kg: .1 }); B.tube([V.add(pv, [0, .3, -.5]), [0, 3.25, -3.0], [0, 2.95, -3.25]], [.15, .12, .11]); A.stitch(B, [[-.1, 2.98, -3.3], [0, 2.92, -3.36], [.1, 2.98, -3.3]], .04, .01, [0, 0, -1], { n: 5 });
  return B;
} };
