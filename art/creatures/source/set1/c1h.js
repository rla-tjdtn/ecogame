// 1장 사람형 — 흉문(胸門): 가슴이 양옆으로 열려 갈비가 손가락처럼 앞으로 뻗는다. 머리는 뒤로 꺾여 등에 매달려 있다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'c1h', name: '흉문', kind: '사람형 · 1장 지하 시설', H: 8.6, build(p = {}) {
  const B = new Body(), w = p.walk, sw = w == null ? .25 : Math.sin(w * Math.PI * 2), open = p.open ?? 1, lean = p.lean ?? 0;
  const pv = [0, 4.35, 0], sp = [pv, [0, 5.1, .16 + lean * .2], [0, 6.0, .02 + lean * .5], [0, 6.9, -.42 + lean * .8], [0, 7.35, -.85 + lean]];
  // 다리(까치발, 마른 다리)
  for (const m of [-1, 1]) { const st = m * sw, h = [m * .42, 4.15, 0], k = [m * .5, 2.35, .42 + st * .55], an = [m * .46, .95 + Math.max(0, -st) * .25, -.1 + st * 1.0]; A.leg(B, h, k, an, .34, { m: .72, front: [m * .12, 0, 1] }); A.foot(B, new Frame(an, [1, 0, 0], [0, 1, 0], [0, 0, 1]).rot(44, m * 6, 0), 1.15, { h: .24 }); }
  A.pelvis(B, Frame.along(pv, [0, 1, .1]), { w: .58, d: .36 });
  // 척추 줄기 + 등 가죽(앞이 텅 빈 껍질)
  B.group({ k: .14, kg: .22, amp: .008, freq: 5 }); B.tube(sp, [.34, .26, .34, .36, .26]); for (let i = 0; i < 5; i++) A.fold(B, [[-.4, 4.75 + i * .16, .2], [0, 4.7 + i * .16, .5], [.4, 4.75 + i * .16, .2]], .016, { k: .05 });
  B.group({ k: .12, kg: .2, amp: .035, freq: 2.6 }); B.ell(new Frame([0, 6.35, -.2 + lean * .6], [1, 0, 0], V.norm([0, 1, -.5]), V.norm([0, .5, 1])), [.82, 1.05, .5]);
  B.ell(new Frame([0, 6.3, .28 + lean * .6], [1, 0, 0], V.norm([0, 1, -.5]), V.norm([0, .5, 1])), [.62, .95, .55], { op: 1, k: .1 });
  for (const m of [-1, 1]) { A.fold(B, [[m * .3, 7.0, -.9], [m * .5, 6.5, -.75], [m * .62, 5.9, -.4]], .02); A.fold(B, [[m * .14, 6.9, -1.0], [m * .2, 6.3, -.85], [m * .22, 5.7, -.5]], .022); }
  // 속: 어둠 + 척추뼈 + 붉은 심장 틈
  B.group({ mat: 2, k: .05 }); B.ell(new Frame([0, 6.3, .0 + lean * .6], [1, 0, 0], V.norm([0, 1, -.5]), V.norm([0, .5, 1])), [.6, .9, .42]);
  B.group({ k: .03, kg: .03 }); for (let i = 0; i < 9; i++) { const t = i / 8, y = 5.45 + t * 1.6, z = .42 - t * .75 + lean * (.4 + t * .4); B.ell(Frame.along([0, y, z], [0, 1, -.45]), [.13, .075, .12]); for (const m of [-1, 1]) B.cone([m * .08, y, z], [m * .27, y + .04, z - .06], .045, .025); }
  B.group({ mat: 1, k: .05 }); B.tube([[.05, 6.65, .22 + lean * .6], [.16, 6.4, .36 + lean * .6], [.08, 6.1, .42 + lean * .6], [.14, 5.85, .46 + lean * .6]], [.03, .085, .07, .02]);
  // 열린 갈비 = 앞으로 뻗은 손가락(마디 있음)
  for (const m of [-1, 1]) for (let i = 0; i < 8; i++) {
    const t = i / 7, y = 7.05 - t * 1.75, z = -.5 + t * .55 + lean * (.9 - t * .5), ln = .75 + Math.sin((.18 + t * .7) * Math.PI) * .75, tw = Math.sin(i * 2.3 + m) * .1, o = open * (.8 + .25 * Math.sin(i * 1.7));
    const a = [m * .5, y, z], b = [m * (1.02 + o * .32), y + .12 + tw, z + .28], c = [m * (1.12 + o * .55), y + .08 - t * .25 + tw, z + .6 + ln * .5], d = [m * (.82 + o * .5), y - .12 - t * .3, z + .75 + ln * 1.0], e = [m * (.45 + o * .28), y - .42 - t * .28, z + .6 + ln * 1.32];
    B.group({ k: .05, kg: .12, amp: .004, freq: 8 }); B.tube([a, b, c, d, e], [.13, .105, .09, .065, .012], { per: 4 }); B.ball(b, .125, { k: .05 }); B.ball(c, .112, { k: .04 }); B.ball(d, .085, { k: .03 });
  }
  // 갈비 사이 찢긴 막
  for (const m of [-1, 1]) { B.group({ k: .06, kg: .1 }); for (let i = 0; i < 6; i++) { const t = i / 6, y = 6.95 - t * 1.5, z = -.35 + t * .5 + lean * .7; B.tube([[m * .62, y, z], [m * (.95 + open * .22), y - .1, z + .26], [m * .78, y - .24, z + .12]], [.05, .022, .05], { per: 3 }); } }
  // 어깨·팔: 뒤로 꺾여 끈에 묶인 채 늘어짐
  for (const m of [-1, 1]) { const s = [m * .72, 6.95, -.62 + lean * .8], e = [m * 1.02, 5.6, -1.25 + lean * .6], wr = [m * .42, 4.55, -1.15 + lean * .4]; A.arm(B, s, e, wr, .2, { m: .7 }); A.hand(B, new Frame(wr, [-m * .9, 0, -.3], V.norm([m * -.05, -1, .05]), V.norm([-m * .1, 0, -1])), 1.15, { curl: 22, spread: 8, thin: .85 }); }
  A.strap(B, [[-.5, 4.72, -1.2], [0, 4.66, -1.32], [.5, 4.72, -1.2], [.5, 4.6, -1.02], [-.5, 4.6, -1.02], [-.5, 4.72, -1.2]], .06, .03, [0, 0, -1]);
  // 목·머리: 뒤로 완전히 꺾여 거꾸로
  A.neck(B, [0, 7.25, -.72 + lean * .9], [0, 7.2, -1.38 + lean * .9], .2, { front: [0, 1, .2], mid: [0, 7.5, -1.05 + lean * .9], adam: true });
  const HF = new Frame([0, 6.72, -1.55 + lean * .9], [1, 0, 0], V.norm([0, -1, -.15]), V.norm([0, .15, -1])).rot(0, 0, p.headRoll ?? -10); HF.x = [-1, 0, 0].map((v, i) => -HF.x[i]);
  A.head(B, HF, 1.15, { jaw: 22, gaunt: 1.3, eyes: 'skin', nose: 'human', teeth: 9, ears: true });
  return B;
} };
