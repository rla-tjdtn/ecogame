// 시안4 5장 비인간형 — 청음귀: 미로 가장 깊은 곳에서 자란 눈 없는 창백한 포복자. 눈 자리는 살로 덮였고, 머리 양옆의 거대한 귓바퀴 두 장이 소리 나는 쪽으로 돌아간다. 입은 한 줄 틈.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
const I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]);
module.exports = { id: 'f5n', name: '청음귀', kind: '비인간형 · 5장 심층 미로', H: 3.6, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .3 : Math.sin(w * Math.PI * 2), lis = p.listen ?? .6, low = p.low ?? 0;
  const y0 = 1.25 - low * .45; // 몸 높이
  // 몸통: 엎드린 갈비통(가슴이 바닥을 향함), 등뼈 능선
  const TF = new Frame([0, y0 + .12, .35], [1, 0, 0], [0, 0, 1], [0, -1, 0]).rot(-6, 0, 0);
  A.torso(B, TF, { w: .82, d: .5, h: 2.1, n: 9, r: .04, scap: true });
  B.group({ k: .25, kg: .3, amp: .008, freq: 3 }); B.tube([TF.p([0, -.9, .1]), [0, y0 - .02, -1.0], [0, y0 + .02, -1.7]], [.6, .5, .56]); A.rings(B, [TF.p([0, -.8, .35]), [0, y0 - .35, -1.4]], 6, .02, .04, .6, { bow: .5 });
  B.group({ k: .22, kg: .25, amp: .01, freq: 3 }); B.ell(I([0, y0 + .05, -1.95]), [.78, .48, .62]); for (const m of [-1, 1]) B.ell(I([m * .42, y0 + .2, -2.15]), [.34, .36, .42]); // 골반·엉덩이
  A.spine(B, [[0, y0 + .52, -2.3], [0, y0 + .5, -1.4], TF.p([0, -.6, -.55]), TF.p([0, .4, -.6]), TF.p([0, 1.15, -.45])], .12, { n: 20, back: [0, 1, 0], out: .03, k: .03, wing: 1 });
  for (let i = 0; i < 7; i++) B.groove([0, y0 + .35, -1.9 + i * .5], [0, .3, 1], .012, .025, 1.1, { bow: .3, wob: .2 }); // 등 가죽 주름
  // 앞다리: 팔꿈치가 몸보다 높이 솟은 거미 자세, 긴 손가락이 바닥에 펼쳐짐
  for (const m of [-1, 1]) { const st = m * S, s = TF.p([m * .82, .95, -.05]), e = [m * 2.05, y0 + 1.25 + Math.max(0, st) * .3, 1.35 + st * .25], wr = [m * 2.45, .32 + Math.max(0, st) * .35, 2.15 + st * .55]; A.arm(B, s, e, wr, .25, { m: .85 }); const fy = V.norm([m * .45, -.05, 1]); A.hand(B, new Frame(wr, [-m, 0, 0], fy, [0, 1, 0]), 1.7, { curl: [6, 10, 8, 14], spread: 15, thin: .78, len: 1.45, claw: .05 }); B.group({ k: .14, kg: .2 }); B.ell(Frame.along(V.add(s, [m * .12, .05, 0]), V.sub(e, s)), [.3, .4, .32]); }
  // 뒷다리: 개구리처럼 접혀 무릎이 등보다 높다
  for (const m of [-1, 1]) { const st = -m * S, h = [m * .62, y0 + .05, -2.05], k = [m * 1.95, y0 + 1.45 + Math.max(0, st) * .25, -1.35 + st * .3], an = [m * 2.3, .5 + Math.max(0, st) * .3, -2.55 + st * .5]; A.leg(B, h, k, an, .34, { m: .9, front: [m * .7, .6, .3] }); A.foot(B, new Frame(an, [-m, 0, 0], [0, 1, 0], V.norm([m * .55, 0, -.4])).rot(0, 0, 0), 1.55, { toe: 1.6 }); }
  // 목: 낮게 앞으로
  const HF = I([0, y0 + .3 - low * .2, 2.55]).rot(14 + low * 10, p.headYaw || 0, p.tilt ?? 0), hp = v => HF.p(v), hs = v => HF.p([v[0] * 1.5 * (Math.abs(v[0]) < .3 ? 1.25 : 1), v[1] * 1.5, v[2] * 1.5]);
  A.neck(B, TF.p([0, 1.05, -.1]), hp([0, -.15, -.35]), .36, { front: [0, -.6, .8], adam: false });
  // 얼굴: 눈 없음(살로 덮인 매끈한 이마), 넓게 찢어진 입 틈
  A.face(B, HF, 1.5, { jaw: p.jaw ?? 8, eyes: 'none', nose: 'hole', w: 1.25, mouthW: 1.9, teeth: 0, gaunt: .5, age: .5, ears: false, vein: false, lips: .4 });
  B.group({ k: .1, kg: .15, amp: .004 }); for (const m of [-1, 1]) B.ell(HF.at([m * .26, .0, .5]).rot(0, m * 15, 0), [.16, .1, .12]); // 눈 자리 덮은 살
  for (const m of [-1, 1]) for (let i = 0; i < 2; i++) B.groove(hs([m * .17, -.01 - i * .04, .48]), HF.d([0, 1, 0]), .006, .01, .12, { bow: -2, wob: .1 }); // 흔적 눈꺼풀 주름
  // 입 틈 속: 촘촘한 바늘이와 잇몸
  { const jw = p.jaw ?? 8, mo = Math.sin(jw * Math.PI / 180); B.group({ mat: 1, k: .01 }); B.tube([hs([-.19, -.248, .25]), hs([-.1, -.248, .31]), hs([0, -.248, .33]), hs([.1, -.248, .31]), hs([.19, -.248, .25])], .018); B.group({ mat: 4, k: .002 }); for (let i = 0; i < 22; i++) { const u = i / 21 * 2 - 1, x = u * .2, z = .36 - u * u * .09; B.cone(hs([x, -.255, z - .01]), hs([x, -.27 - mo * .14 - .02 * Math.abs(Math.sin(i * 7)), z]), .012, .002); } }
  for (const m of [-1, 1]) { B.group({ k: .02 }); B.tube([hs([m * .22, -.26, .26]), hs([m * .3, -.24, .12]), hs([m * .34, -.2, -.02])], .01, { op: 1 }); } // 입꼬리가 귀 쪽까지 찢어짐
  // 귓바퀴: 머리 양옆의 거대한 살 깔때기, 안쪽에 겹겹의 연골 주름. listen 이면 앞으로 활짝
  for (const m of [-1, 1]) {
    const E = HF.at([m * .3, .02, -.1]).rot(-6, m * (34 - lis * 26), 0), ep = v => E.p([m * v[0], v[1], v[2]]), EA = v => new Frame(ep(v), E.x, E.y, E.z); const Hh = 1.42, Wd = .7, cx = .7, cy = .82, tl = -.38;
    const T = (x, y) => [x * Math.cos(tl) - y * Math.sin(tl), y * Math.cos(tl) + x * Math.sin(tl)]; // 귀를 바깥으로 기울임
    const eo = (a, r, z = 0) => { const q = T(Math.cos(a) * Wd * r, Math.sin(a) * Hh * r); return ep([cx + q[0], cy + q[1], z]); };
    B.group({ k: .06, kg: .16, amp: .008, freq: 5 });
    B.ell(EA([cx, cy, -.05]).rot(0, 0, m * tl * 57.3), [Wd, Hh, .18]); B.ell(EA([cx + .02, cy + .04, .14]).rot(0, 0, m * tl * 57.3), [Wd * .86, Hh * .88, .18], { op: 1, k: .1 });
    { const t0 = eo(1.75, .78, -.03), t1 = eo(1.72, 1.42, -.1); B.cone(t0, t1, .17, .012, { k: .16 }); } // 뾰족한 귀 끝
    { const rim = []; for (let i = 0; i <= 26; i++) { const a = -2.3 + i / 26 * 5.4; rim.push(eo(a, .97, .09 + .04 * Math.sin(a * 4))); } B.tube(rim, rim.map((_, i) => .03 + .035 * Math.sin(i / 26 * Math.PI)), { per: 1, k: .04 }); }
    for (let k = 0; k < 7; k++) { const u = -.7 + k * .23, hw = Math.sqrt(Math.max(.05, 1 - u * u)) * .8, pts = []; for (let i = 0; i <= 6; i++) { const t = i / 6 * 2 - 1, q = T(t * hw * Wd, u * Hh - .08 * (1 - t * t)); pts.push(ep([cx + q[0], cy + q[1], .02 - .06 * (1 - t * t)])); } B.tube(pts, [.012, .028, .04, .045, .04, .028, .012], { per: 2, k: .04 }); } // 가로 연골 주름(박쥐 귀)
    if (m < 0) { B.ell(new Frame(eo(.3, 1.0), E.x, E.y, E.z), [.16, .1, .3], { op: 1, k: .03 }); B.ell(new Frame(eo(.9, 1.0), E.x, E.y, E.z), [.09, .07, .3], { op: 1, k: .02 }); } // 찢긴 가장자리
    B.group({ k: .06, kg: .12 }); B.tube([ep([0, 0, -.05]), ep([.22, .08, -.04]), ep([.38, .2, -.02])], [.22, .2, .16]); B.group({ mat: 2, k: .02 }); B.ell(EA([.32, .16, .08]), [.11, .13, .08]); // 귀 뿌리·귓구멍
  }
  return B;
} };
