// 시안4 4장 비인간형 — 거꾸로 기는 환자: 영안실에서 사라진 입원 환자. 배를 하늘로 뒤집어 허리를 활처럼 휜 채(브리지) 손발을 바닥에 붙이고 머리 쪽으로 긴다. 뒤로 꺾인 머리는 거꾸로 매달려 앞을 본다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'f4n', name: '거꾸로 기는 환자', kind: '비인간형 · 4장 폐병원', H: 4.4, build(p = {}) {
  const B = new Body(), w = p.walk ?? .15, I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]), ar = p.arch ?? 0;
  const lift = ph => Math.max(0, Math.sin((w + ph) * 6.283)), sw = ph => Math.cos((w + ph) * 6.283);
  // ---- 몸통: 배가 위. 가슴은 어깨 위, 배가 가장 높고, 골반은 낮게(사람이 버틸 수 있는 브리지)
  const ch = [0, 3.12 + ar * .1, .45], bl = [0, 3.3 + ar * .3, -.55], pv = [0, 2.42 + ar * .1, -1.45];
  const TF = new Frame(ch, [-1, 0, 0], V.norm([0, .1, 1]), V.norm([0, 1, -.1])); // y = 머리 쪽, z = 가슴(위)
  B.group({ k: .2, kg: .15, amp: .005, freq: 3 });
  B.ell(I(ch), [.8, .42, .72]); B.ell(I(bl).rot(-8, 0, 0), [.6, .33, .62]); B.ell(I(pv).rot(-25, 0, 0), [.74, .42, .52]); B.tube([pv, bl, ch, [0, 2.95, 1.1]], [.46, .38, .46, .34]);
  A.ribs(B, TF, { n: 7, w: .73, d: .43, h: 1.15, r: .045, po: { k: .06 } }); // 얇은 환자복 아래로 비치는 갈비
  B.ell(I(V.add(bl, [0, -.12, .1])), [.42, .2, .3], { op: 1, k: .2 }); // 꺼진 배
  for (const m of [-1, 1]) B.ell(I([m * .5, 2.65, -1.5]).rot(0, 0, m * 20), [.08, .2, .25], { op: 0, k: .1 }); // 골반 뼈 돌출
  for (let i = 0; i < 7; i++) B.groove([.28 * Math.sin(i * 2.2), 3.4, -1.35 + i * .33], V.norm([1, .1, .4 * Math.sin(i * 1.7)]), .014, .03, .5, { bow: .4, wob: .2, wf: 2 }); // 천 주름
  for (const m of [-1, 1]) B.groove([m * .46, 3.4, -.2], [0, 0, 1], .014, .03, .45, { bow: .6, wob: .15 });
  B.group({ k: .02, kg: .04 }); B.tube([[.08, 2.75, -1.25], [.1, 3.55, -.5], [.06, 3.5, .2], [-.02, 3.42, .85]], .028); B.tube([[-.5, 3.2, .95], [-.25, 3.35, 1.08], [0, 3.35, 1.12], [.25, 3.35, 1.08], [.5, 3.2, .95]], .04);
  for (const m of [-1, 1]) { B.group({ k: .03, kg: .05 }); B.tube([[m * .08, 3.3, 1.05], [m * .4, 3.38, .98], [m * .78, 3.22, .9]], [.05, .045, .055]); } // 쇄골
  // ---- 옆으로 처진 환자복 자락
  for (const m of [-1, 1]) { B.group({ k: .2, kg: .18, amp: .006, freq: 4 }); for (let i = 0; i <= 14; i++) { const z = -1.85 + i * .19, j = Math.sin(i * 2.3 + m), yt = 3.0 - .5 * Math.max(0, -z - .5), top = [m * .66, yt, z], hem = yt - 1.05 - .2 * Math.sin(i * 1.3 + m); if (Math.abs(z - .9) < .22 || Math.abs(z + 1.45) < .25) continue; B.tube([top, [m * (.84 + .04 * j), yt - .55, z + .03 * j], [m * (.9 + .06 * j), hem, z + .05 * j]], [.1, .095, .07]); } }
  B.group({ k: .2, kg: .18, amp: .006, freq: 4 }); for (let i = 0; i <= 7; i++) { const x = -.5 + i * .145, j = Math.sin(i * 2.7); B.tube([[x, 2.25, -1.8], [x * 1.1, 1.8, -1.9 + .04 * j], [x * 1.15, 1.3 + .15 * j, -1.95]], [.1, .095, .07]); }
  B.group({ k: .01, kg: .02 }); for (let i = 0; i < 3; i++) for (const m of [-1, 1]) { const o = [m * .16, 2.45 + i * .27, -.9 + i * .65]; B.tube([o, V.add(o, [m * .05, -.45, .05]), V.add(o, [m * .02 + .04 * i, -.85 - .12 * i, 0])], [.024, .021, .017]); } // 등 끈
  // ---- 목과 거꾸로 매달린 머리: 정수리가 바닥 쪽, 얼굴은 앞
  A.neck(B, [0, 3.0, 1.05], [0, 2.45, 1.6], .22, { front: [0, 1, .3], kg: .2 });
  const s = 1.45, HF = new Frame([0, 1.82, 1.72], [-1, 0, 0], V.norm([0, -1, -.15]), V.norm([0, -.15, 1])).rot(p.nod ?? -4, p.headYaw || 0, p.tilt ?? 10), hp = v => HF.p(V.mul(v, s));
  A.face(B, HF, s, { w: .95, gaunt: 1.5, jaw: p.jaw ?? 44, eyes: 'real', iris: .014, open: 1.4, eyeSize: 1.1, teeth: 10, age: .7, lips: .8, mouthW: 1.05 });
  // 피: 입가에서 (거꾸로라) 이마 쪽으로 흘러 바닥에 고임 — 유일한 붉은 곳
  B.group({ mat: 1, k: .012, kg: .02 }); for (const m of [-1, 1]) { const a = hp([m * .1, -.27, .31]), b = hp([m * .15, -.12, .32]), c = hp([m * .19, .08, .27]), d = hp([m * .2, .22, .22]); B.tube([a, b, c, d, V.add(d, [0, -.3, 0])], [.012, .018, .016, .014, .005].map(x => x * s)); } B.tube([hp([0, -.15, .43]), hp([.02, .0, .38]), hp([.03, .15, .35]), V.add(hp([.03, .25, .3]), [0, -.2, 0])], [.012, .016, .014, .005].map(x => x * s)); B.ell(I([.12, .02, 2.0]), [.32, .015, .26]);
  // 긴 머리카락: 정수리에서 바닥으로 쏟아져 쌓임
  { const R = []; for (let i = 0; i < 46; i++) { const a = i / 46 * 6.283, j = Math.sin(i * 5.3), rx = .3 * Math.sin(a), rz = .36 * Math.cos(a) - .08; if (Math.cos(a) > .55) continue; const root = hp([rx * .95, .3 + .06 * Math.cos(a), rz * .95]), tip = [root[0] * 1.5 + j * .25, .03, root[2] + .3 * Math.cos(a) + j * .15]; const j2 = Math.sin(i * 2.1), cl = Math.round(i / 4) * .9; R.push([root, V.add(root, [rx * .3, -.15, rz * .2]), V.add(V.lerp(root, tip, .45), [Math.sin(cl) * .1 + j * .05, 0, Math.cos(cl) * .08]), tip, V.add(tip, [Math.sin(a) * (.45 + .45 * Math.abs(j2)) + j * .2, 0, Math.cos(a) * .55 + j2 * .3])]); } A.hair(B, R, { r: [.022, .03, .028, .02, .008] }); }
  // ---- 팔: 사람 길이(약 1.15배). 어깨에서 바닥으로, 팔꿈치는 바깥으로 꺾이고 손바닥을 평평히 짚음
  for (const m of [-1, 1]) {
    const ph = m > 0 ? 0 : .5, lf = lift(ph), f = sw(ph), sh = [m * .8, 3.05, .88], wr = [m * 1.5, .32 + lf * .45, 1.45 + f * .45], el = [m * 1.68, 1.62 + lf * .3, .85 + f * .2];
    A.arm(B, sh, el, wr, .19, { m: .85 });
    B.group({ k: .06, kg: .1, amp: .004, freq: 4 }); B.tube([V.lerp(sh, el, -.05), V.lerp(sh, el, .32)], [.31, .29]); A.rings(B, [sh, V.lerp(sh, el, .3)], 3, .02, .03, .35, { bow: .3 }); // 짧은 소매
    B.group({ k: .04, kg: .06 }); B.ball(V.add(el, [m * .1, .02, -.08]), .1); // 팔꿈치 뼈
    { const hy = V.norm([m * .4, -.08, .9]), hz = V.norm([0, 1, .05]), hx = V.mul(V.norm(V.cross(hy, hz)), m); A.hand(B, new Frame(wr, hx, hy, V.cross(hx, hy).map(v => v * m)), 1.05, { curl: [4, 8, 10, 14], spread: 12, thin: .85, len: 1.12 }); }
    const cw = V.lerp(el, wr, .9);
    if (m > 0) { B.group({ k: .01, kg: .02 }); const q = (a, b) => V.add(cw, [a, 0, b]); B.tube([q(-.15, -.1), q(.15, -.1), q(.15, .1), q(-.15, .1), q(-.15, -.1)], .03, { per: 1 }); B.box(new Frame(q(.17, 0), [0, 0, 1], [0, 1, 0], [1, 0, 0]), [.06, .04, .012], .01); } // 환자 팔찌
    else { const c = V.lerp(el, wr, .4); B.group({ k: .01, kg: .03 }); B.box(new Frame(V.add(c, [-.16, 0, 0]), [0, 0, 1], V.norm(V.sub(el, wr)), [-1, 0, 0]), [.09, .12, .012], .01); B.group({ k: .006 }); B.tube([V.add(c, [-.18, .05, 0]), V.add(c, [-.35, -.3, -.15]), V.add(c, [-.4, -.8, -.4]), [-1.95, .05, -.2], [-1.5, .03, -1.2], [-1.6, .03, -2.4], [-1.2, .03, -3.6]], .02); } // 수액 바늘(테이프)과 끌리는 줄
  }
  // ---- 다리: 골반 낮게, 무릎이 위로 솟고 정강이는 바닥으로, 발바닥을 붙임
  for (const m of [-1, 1]) {
    const ph = m > 0 ? .5 : 0, lf = lift(ph), f = sw(ph), h = [m * .5, 2.3, -1.5], k = [m * .95, 2.9 + lf * .35, -3.5 + f * .25], an = [m * 1.02, .44 + lf * .45, -3.25 + f * .45];
    A.leg(B, h, k, an, .27, { m: .88, front: [m * .2, 1, -.5] });
    const fd = V.norm([m * .25, 0, -1]); A.foot(B, new Frame(an, V.norm(V.cross([0, 1, 0], fd)), [0, 1, 0], fd), 1.2, {});
    if (m < 0) { const T = new Frame(an, V.norm(V.cross([0, 1, 0], fd)), [0, 1, 0], fd).sc(1.2), t = v => T.p(v); B.group({ k: .006, kg: .01 }); B.tube([t([.1, -.2, .62]), t([.2, -.12, .55]), t([.32, -.18, .6])], .012); B.box(new Frame(t([.38, -.12, .58]), fd, V.norm([.3, -1, 0]), V.norm([1, .3, 0])), [.12, .2, .01], .01); B.group({ mat: 2, k: .002 }); B.ball(t([.38, .0, .58]), .025); } // 발가락 이름표(영안실)
  }
  return B;
} };
