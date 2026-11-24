// 시안4 7장 비인간형 — 과학실 인체모형: 반은 살갗, 반은 근육인 실물 크기 해부 모형이 네 발로 기어 다닌다.
// 받침 쇠막대가 등에 꽂힌 채 부러져 있고, 머리뚜껑이 들려 뇌가 보인다. 떼어 낼 수 있는 장기들이 배 밑으로 매달려 끌린다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'f7n', name: '해부 모형', kind: '비인간형 · 7장 학교', H: 6.4, build(p = {}) {
  const B = new Body(), w = p.walk ?? 0, I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]), L = V.lerp, ph = q => Math.sin((w + q) * Math.PI * 2);
  const mus = (a, b, r, o = {}) => A.muscle(B, a, b, r, { n: o.n ?? 9, up: o.up || [0, 1, 0], belly: o.belly ?? .45, flat: o.flat ?? 1, tw: o.tw ?? .3, kg: o.kg ?? r * .35, ph: o.ph });
  // ---- 몸통: 엉덩이가 어깨보다 높은 네발 자세. 몸 앞면(배)이 아래를 본다
  const pel = [0, 4.0, -2.0], chest = [0, 3.55, .25], neckB = [0, 3.7, 1.05];
  const ys = V.norm(V.sub(chest, pel)), zs = V.norm(V.cross([1, 0, 0], ys)); // zs: 배 쪽(아래)
  const TF = new Frame(chest, [1, 0, 0], ys, zs);
  A.torso(B, TF, { w: .78, d: .5, h: 1.6, n: 7, r: .03 });
  A.pelvis(B, new Frame(pel, [1, 0, 0], ys, zs), { w: .62, d: .42 });
  B.group({ k: .25, kg: .25, amp: .006, freq: 4 }); B.tube([L(pel, chest, .1), L(pel, chest, .45), L(pel, chest, .7)], [.56, .48, .6]);
  A.spine(B, [V.add(pel, [0, .38, 0]), V.add(L(pel, chest, .5), [0, .52, 0]), V.add(chest, [0, .62, 0]), V.add(neckB, [0, .32, -.1])], .1, { n: 16, back: [0, 1, 0], out: .02, k: .03 });
  // 벗겨진 오른쪽(−x) 반: 등·옆구리·가슴 근육 섬유
  mus(TF.p([-.08, .55, -.35]), TF.p([-.9, .55, -.1]), .22, { up: zs, n: 10, flat: .5 }); // 승모·어깨
  mus(TF.p([-.1, .2, .45]), TF.p([-.85, .55, .2]), .26, { up: zs, n: 11, flat: .45 }); // 큰가슴근(아래쪽)
  for (let i = 0; i < 4; i++) mus(TF.p([-.72, .15 - i * .28, .18]), TF.p([-.25, -.05 - i * .3, .5]), .1, { up: zs, n: 6, flat: .6, ph: i }); // 앞톱니
  mus(TF.p([-.15, -.1, -.5]), L(pel, chest, .25).map((v, i) => v + [-.45, .3, 0][i]), .3, { up: [0, 1, 0], n: 12, flat: .4 }); // 넓은등근
  for (let i = 0; i < 4; i++) { const c = L(pel, chest, .15 + i * .17); B.group({ k: .04, kg: .08 }); B.box(new Frame(V.add(c, [-.2, -.42, 0]), [1, 0, 0], ys, zs), [.17, .16, .07], .07); } // 배곧은근 마디
  B.group({ k: .03, kg: .03 }); B.tube([V.add(pel, [-.02, .45, .05]), V.add(L(pel, chest, .5), [-.02, .55, 0]), V.add(chest, [-.02, .64, 0]), V.add(neckB, [-.02, .34, -.1])], .035, { op: 1 }); // 반쪽 나눔선(얕은 홈)
  // 배 밑 장기 칸: 떼었다 붙이는 가슴·배 판이 경첩에 매달려 열림, 장기가 아래로 늘어짐
  { const C0 = L(pel, chest, .62), win = new Frame(V.add(C0, V.mul(zs, .48)), [1, 0, 0], ys, zs);
    B.group({ k: .03 }); B.ell(win.at([.05, 0, 0]), [.55, 1.15, .4], { op: 1, k: .04 }); }
  B.group({ mat: 2, k: .02 }); B.ell(new Frame(V.add(L(pel, chest, .62), V.mul(zs, .2)), [1, 0, 0], ys, zs), [.45, 1.0, .15]);
  { const C0 = L(pel, chest, .62), rim = []; for (let i = 0; i <= 30; i++) { const a = i / 30 * 6.283; rim.push(V.add(V.add(C0, V.mul(zs, .42 - .1 * Math.abs(Math.cos(a)))), V.add([.05 + Math.cos(a) * .55, 0, 0], V.mul(ys, Math.sin(a) * 1.12)))); } B.group({ k: .02, kg: .04 }); B.tube(rim, .045, { per: 1 });
    // 떨어진 판: 오른쪽 경첩에서 아래로 늘어짐
    const hg = V.add(C0, V.add([-.55, 0, 0], V.mul(zs, .35))), PF = new Frame(hg, V.norm([.2, -1, 0]), ys, V.norm([-1, -.2, 0])).rot(0, 0, (p.panel ?? 1) * -10);
    B.group({ k: .08, kg: .03, amp: .004, freq: 4 }); for (let i = 0; i < 6; i++) { const y = .95 - i * .38, ww = .5 * Math.sqrt(Math.max(.15, 1 - (y / 1.25) ** 2)); B.box(PF.at([ww * .95, y, .02]), [ww, .2, .05], .045); }
    for (let i = 0; i < 4; i++) B.groove(PF.p([.5, .6 - i * .38, .08]), PF.y, .012, .03, .6, { wob: .2, bow: .5 });
    B.group({ k: .02 }); for (const y of [.7, -.6]) B.tube([PF.p([-.04, y, 0]), PF.p([.08, y, 0])], .07);
    for (const y of [.5, -.1, -.6]) { B.group({ k: .01 }); B.cone(PF.p([.45, y, -.04]), PF.p([.45, y, -.16]), .035, .03); } }
  // 장기: 폐 두 쪽, 간, 위, 창자 다발(아래로 처져 바닥에 끌림), 심장(붉은, 혈관 몇 가닥에 매달려 흔들림)
  { const C0 = L(pel, chest, .62), Q = (x, yy, zz) => V.add(V.add(C0, [x, 0, 0]), V.add(V.mul(ys, yy), V.mul(zs, zz)));
    B.group({ k: .08, kg: .03, amp: .008, freq: 6 }); for (const m of [-1, 1]) { B.ell(new Frame(Q(m * .3, .45, .35), [1, 0, 0], ys, zs), [.24, .55, .28]); for (let i = 0; i < 2; i++) B.groove(Q(m * .3, .2 + i * .45, .5), V.add(ys, [m * .4, 0, 0]), .012, .025, .35, { bow: .5 }); }
    B.ell(new Frame(Q(.1, -.2, .45), V.norm([1, .3, 0]), ys, zs), [.42, .3, .2]); B.ell(new Frame(Q(-.25, -.35, .5), [1, 0, 0], ys, zs), [.22, .2, .2]);
    // 창자: 칸 아래로 고리처럼 처짐
    B.group({ k: .03, kg: .03 }); const g = []; for (let i = 0; i <= 40; i++) { const t = i / 40, sag = Math.sin(t * Math.PI); g.push(V.add(Q(Math.sin(i * 1.05) * .38, -.55 - t * .45 + Math.cos(i * .8) * .12, .5), [0, -sag * 1.6 - .2 * Math.cos(i * 1.3), Math.sin(i * .9) * .2])); } B.tube(g, .1, { per: 2 }); A.rings(B, g, 26, .018, .025, .16, { tilt: .4 });
    const g2 = [Q(-.2, -.75, .5), V.add(Q(-.4, -.8, .5), [0, -.6, -.05]), V.add(Q(-.3, -.95, .5), [0, -1.2, -.1]), V.add(Q(-.05, -1.1, .5), [0, -1.45, 0]), V.add(Q(.2, -1.0, .5), [0, -1.2, .05]), V.add(Q(.3, -.85, .5), [0, -.6, 0]), Q(.2, -.75, .5)]; B.tube(g2, [.1, .11, .11, .11, .11, .1, .1]); A.rings(B, g2, 16, .018, .025, .16, { tilt: .4 });
    // 심장: 대동맥·정맥 가닥에 매달려 가슴 아래로 늘어짐 (포인트)
    const hc = V.add(Q(-.05, .55, .5), [0, -1.25, .1]); B.group({ k: .03, kg: .03 }); for (const [x, z] of [[-.08, 0], [.08, .05], [0, -.08]]) B.tube([Q(x, .6, .45), V.add(Q(x * 1.5, .6, .5), [0, -.5, z]), V.add(hc, [x, .3, z])], [.05, .045, .05]);
    B.group({ mat: 1, k: .08, amp: .004, freq: 8 }); B.ell(new Frame(hc, V.norm([1, .25, 0]), V.norm([-.25, 1, .1]), [0, 0, 1]).rot(0, 0, 18), [.22, .3, .2]); B.ball(V.add(hc, [.08, .22, 0]), .12); B.tube([V.add(hc, [-.05, .2, 0]), V.add(hc, [-.1, .38, .03]), V.add(hc, [.02, .48, .06])], [.08, .07, .06]); B.groove(V.add(hc, [0, 0, .18]), V.norm([1, .6, 0]), .012, .03, .3, { bow: .4 });
    // 장기 꽂이(모형의 플라스틱 핀)
    B.group({ k: .01 }); for (const [x, yy] of [[.3, .9], [-.3, .9], [.2, -.6], [-.35, .0]]) B.cone(Q(x, yy, .3), Q(x, yy, .5), .04, .035); }
  // 번호 핀: 모형 근육에 꽂힌 작은 깃발 핀
  { const pins = [[TF.p([-.75, .5, -.2]), [-.6, .8, -.2]], [L(pel, chest, .3).map((v, i) => v + [-.55, .25, 0][i]), [-.7, .7, 0]], [V.add(pel, [-.85, -.6, .3]), [-.8, .5, .3]], [TF.p([-.5, -.2, .55]), [-.7, -.3, .6]]]; for (const [a, d] of pins) { const n = V.norm(d), b = V.add(a, V.mul(n, .32)); B.group({ k: .004, kg: .01 }); B.cone(a, b, .012, .012); B.ball(b, .035); const fx = V.norm(V.cross(n, [0, 0, 1])); B.box(new Frame(V.add(b, V.mul(fx, .1)), fx, n, V.cross(fx, n)), [.09, .055, .008], .006); } }
  // ---- 받침 쇠막대: 등뼈에 박힌 채 부러져 위로 솟음 + 끊긴 나사 고정쇠
  { const base = V.add(L(pel, chest, .5), [0, .55, 0]); B.group({ k: .03, kg: .06 }); B.tube([V.add(base, [0, -.2, 0]), V.add(base, [.02, .9, -.1]), V.add(base, [.06, 2.0, -.25])], [.1, .09, .085]); B.ell(I(V.add(base, [0, .02, 0])), [.26, .08, .26]); B.groove(V.add(base, [0, .5, 0]), [0, 1, 0], .01, .02, .2, { wob: 0 });
    B.group({ k: .006 }); const tp = V.add(base, [.06, 2.0, -.25]); for (let i = 0; i < 5; i++) { const a = i * 1.26; B.cone(tp, V.add(tp, [Math.cos(a) * .06, .12 + .14 * Math.abs(Math.sin(i * 3.3)), Math.sin(a) * .06]), .05, .006); } }
  // ---- 팔: 왼쪽(+x) 살갗, 오른쪽(−x) 근육. 손바닥으로 바닥을 짚고 팔꿈치가 바깥으로 꺾임
  for (const m of [-1, 1]) {
    const q = ph(m > 0 ? 0 : .5), lift = Math.max(0, q) * .45;
    const s = V.add(TF.p([m * .82, .52, .05]), [0, .05, 0]), e = [m * 1.75, 2.75 + lift * .5, .75 + q * .25], wr = [m * 1.4, .42 + lift, 2.2 + q * .45];
    if (m > 0) { A.arm(B, s, e, wr, .27, { m: 1 }); }
    else { B.group({ k: .05, kg: .06 }); B.tube([s, e, wr], [.2, .16, .11]); mus(V.add(s, [0, .1, .05]), L(s, e, .45), .38, { n: 11, up: [0, 0, 1] }); mus(L(s, e, .15), L(s, e, .95), .27, { n: 9, up: [0, 0, 1], ph: 1 }); mus(V.add(L(s, e, .2), [0, .1, -.12]), V.add(e, [0, .1, -.12]), .25, { n: 8, up: [0, 0, 1], ph: 2 }); mus(V.add(e, [0, .05, .05]), L(e, wr, .9), .25, { n: 9, up: [0, 0, 1], belly: .3 }); mus(V.add(e, [-.05, -.05, -.08]), L(e, wr, .85), .16, { n: 7, up: [0, 0, 1], belly: .3, ph: 2 });
      B.group({ k: .02, kg: .04 }); for (let i = 0; i < 4; i++) B.tube([L(e, wr, .55), V.add(wr, [-.08 + i * .05, .1, .05])], [.025, .02]); B.ball(e, .15, { k: .05 }); }
    { const fy = V.norm([m * .22, -.06, 1]); A.hand(B, new Frame(wr, V.norm(V.cross(fy, [0, 1, 0])).map(v => v * (m > 0 ? 1 : -1)), fy, [0, 1, 0]), 1.5, { curl: [8, 4, 6, 10], spread: 12, thin: m > 0 ? 1 : .8, len: 1.15, vein: m > 0 ? 1 : 0, claw: m < 0 ? .04 : 0 }); }
  }
  // ---- 다리: 엉덩이를 높이 들고 무릎을 앞으로 접은 곰 걸음. 왼쪽 살갗, 오른쪽 근육
  for (const m of [-1, 1]) {
    const q = ph(m > 0 ? .5 : 0), lift = Math.max(0, q) * .4;
    const h = V.add(pel, [m * .55, -.12, -.05]), k = [m * 1.05, 2.15 + lift, -.95 + q * .3], an = [m * .9, .5 + lift, -2.5 + q * .5];
    if (m > 0) A.leg(B, h, k, an, .36, { m: 1, front: [0, -.6, 1] });
    else { B.group({ k: .05, kg: .06 }); B.tube([h, k, an], [.25, .18, .12]); mus(h, L(h, k, .95), .42, { n: 12, up: [0, 1, 0] }); mus(V.add(h, [-.12, .15, -.1]), V.add(k, [-.05, .2, -.15]), .24, { n: 9, ph: 1 }); mus(V.add(h, [.05, -.1, .1]), V.add(k, [.05, -.05, .12]), .2, { n: 8, ph: 2, up: [1, 0, 0] }); mus(V.add(k, [0, -.12, -.1]), L(k, an, .75), .33, { n: 10, belly: .3 }); B.group({ k: .03, kg: .05 }); B.ell(I(V.add(k, [-.02, .02, .2])), [.15, .16, .12]); B.tube([V.add(L(k, an, .7), [0, .05, -.1]), V.add(an, [0, .05, -.2])], [.08, .06]); B.tube([V.add(k, [0, -.05, .18]), V.add(an, [0, .1, .12])], [.07, .05]); }
    const fz = V.norm([m * .15, 0, -1]); A.foot(B, new Frame(an, V.norm(V.cross([0, 1, 0], fz)), [0, 1, 0], fz).rot(-12, 0, 0), 1.3, {}); // 발끝이 뒤로(밀어내는 발)
  }
  // ---- 목과 머리: 고개를 들어 앞을 본다. 왼쪽 반 얼굴은 살갗, 오른쪽 반은 근육과 이, 눈꺼풀 없는 눈
  const s = 1.55, HF = I([0, 4.15, 2.05]).rot(p.nod ?? -8, p.headYaw ?? 0, p.tilt ?? -10), hp = v => HF.p(V.mul(v, s));
  A.neck(B, neckB, hp([0, -.3, -.12]), .27, { front: [0, -.6, 1] });
  for (let i = 0; i < 5; i++) mus(V.add(neckB, [-.08 - i * .05, .1 - i * .06, -.05]), hp([-.2 - i * .03, -.18 - i * .02, -.05 + i * .04]), .07, { n: 5, ph: i, up: [0, 0, 1] });
  const gi = B.groups.length; A.face(B, HF, s, { jaw: p.jaw ?? 22, eyes: ['real', 'none'], gaunt: 1, age: .3, teeth: 11, iris: .018, ears: true, vein: false });
  { B.group({ k: .012 * s, kg: .03 * s }); for (let i = 0; i < 12; i++) { const t = i / 11, x = -.025 - t * .25; B.tube([hp([x * .7, .1 - t * .02, .3 - t * .1]), hp([x * .95, .14 - t * .02, .3 - t * t * .14]), hp([x, .2, .335 - t * t * .15]), hp([-.03 - t * .2, .1, .345 - t * t * .12])], [.004 * s, .012 * s, .013 * s, .005 * s]); }
    for (let i = 0; i < 7; i++) { const t = i / 6; B.tube([hp([-.31 + t * .05, 0 - t * .06, 0 + t * .06]), hp([-.27 + t * .05, -.16 - t * .02, .13 + t * .05]), hp([-.17 + t * .02, -.27 - t * .03, .24 + t * .01])], [.015 * s, .026 * s, .012 * s]); }
    const ring = [[1, 0], [.7, .7], [0, 1], [-.7, .7], [-1, 0], [-.7, -.7], [0, -1], [.7, -.7], [1, 0]]; for (const r of [.085, .115]) B.tube(ring.map(([c, q]) => hp([-.135 + c * r, -.01 + q * r * .85, .335 - Math.abs(c) * .03 - (r - .085) * .7 + Math.min(0, c) * .06])), [.017 * s]);
    B.group({ mat: 6, k: .01 }); B.ball(hp([-.135, -.01, .31]), .078 * s); B.group({ mat: 2, k: .004 }); B.ball(hp([-.135, -.01, .375]), .026 * s); B.group({ mat: 5, k: .001 }); B.ball(hp([-.125, .006, .396]), .008 * s);
    B.group({ mat: 4, k: .003 }); for (let i = 0; i < 5; i++) for (const u of [0, 1]) { const t = i / 4; B.ell(I(hp([-.115 - t * .075, -.24 + t * .035 - u * (.055 + (p.jaw ?? 22) * .0015 * (1 - t)), .325 - t * .11])), [.02 * s, .032 * s, .02 * s]); }
    A.stitch(B, [[0, .14, .3], [0, .1, .36], [0, .02, .38]].map(hp), .03 * s, .008 * s, HF.z, { n: 5 }); }
  // 들린 머리뚜껑(경첩이 뒤통수에) + 뇌 주름
  { B.g = B.groups[gi]; B.ell(new Frame(hp([0, .32, -.06]), HF.x, HF.y, HF.z), [.34 * s, .2 * s, .44 * s], { op: 1, k: .02 });
    B.group({ k: .03, kg: .02, amp: .004, freq: 14 }); for (const m of [-1, 1]) B.ell(new Frame(hp([m * .125, .23, -.06]), HF.x, HF.y, HF.z), [.15 * s, .17 * s, .34 * s]); for (let i = 0; i < 34; i++) { const m = i % 2 ? 1 : -1, u = Math.sin(i * 7.31), v = Math.cos(i * 3.77); B.groove(hp([m * (.08 + .07 * Math.abs(u)), .36 - .05 * Math.abs(v), -.3 + (i / 33) * .55]), HF.d([u, .2, v]), .011 * s, .022 * s, .14 * s, { wob: .5, wf: 9, bow: 3 * u }); } B.group({ k: .02 }); B.tube([hp([0, .36, -.4]), hp([0, .38, .28])], .012 * s, { op: 1 });
    // 잘린 두개 테두리: 두꺼운 뼈 가장자리 + 톱자국 + 경첩 쇠(뚜껑은 떨어져 나감)
    { const rim = []; for (let i = 0; i <= 32; i++) { const a = i / 32 * 6.283; rim.push(hp([Math.sin(a) * .315, .135 + .012 * Math.sin(i * 5.3), Math.cos(a) * .4 - .08])); } B.group({ k: .02, kg: .03 }); B.tube(rim, .03 * s, { per: 1 }); for (let i = 0; i < 18; i++) { const a = i / 18 * 6.283; B.groove(hp([Math.sin(a) * .33, .11, Math.cos(a) * .42 - .08]), HF.y, .006 * s, .01 * s, .04 * s, { wob: 0 }); } B.group({ k: .01 }); B.box(new Frame(hp([0, .14, -.5]), HF.x, HF.y, HF.z), [.08 * s, .03 * s, .02 * s], .01); for (const x of [-.05, .05]) B.cone(hp([x, .13, -.52]), hp([x, .19, -.53]), .012 * s, .008 * s); }
  }
  return B;
} };
