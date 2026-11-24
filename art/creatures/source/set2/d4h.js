// 시안2 4장 인간형 — 무영등: 머리 대신 수술실 조명이 달린 집도자. 등불 일곱 개마다 안쪽에 눈꺼풀이 있고, 등에서 나온 관절 팔이 그것을 받친다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'd4h', name: '무영등', kind: '인간형 · 4장 폐병원', H: 10.6, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .4 : Math.sin(w * Math.PI * 2), tl = p.tilt ?? 34, tn = p.turn ?? 0;
  for (const m of [-1, 1]) { const st = m * S, h = [m * .4, 3.95, 0], k = [m * .46, 2.2, .25 + st * .5], an = [m * .42, .34 + Math.max(0, -st) * .18, -.1 + st * .85]; A.leg(B, h, k, an, .31, { m: .8, front: [m * .1, 0, 1] }); A.foot(B, new Frame(an, [1, 0, 0], [0, 1, 0], V.norm([m * .2, 0, 1])), 1.1, {}); }
  A.pelvis(B, new Frame([0, 4.1, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]), { w: .54, d: .36 });
  B.group({ k: .18, kg: .25, amp: .006, freq: 4 }); B.tube([[0, 4.2, 0], [0, 5.0, .06], [0, 5.7, 0]], [.42, .36, .48]); A.torso(B, new Frame([0, 6.2, -.02], [1, 0, 0], [0, 1, 0], [0, 0, 1]), { w: .76, d: .46, h: 1.5, n: 8, r: .05 });
  // 수술복 앞자락: 목에 걸려 무릎까지, 주름
  B.group({ k: .14, kg: .05, amp: .008, freq: 3 }); for (let i = 0; i < 11; i++) { const u = i / 10 - .5; B.tube([[u * .5, 6.95, .42 - Math.abs(u) * .2], [u * 1.25, 6.0, .58 - Math.abs(u) * .25], [u * 1.2, 4.6, .58 - Math.abs(u) * .2], [u * 1.6, 3.0, .75 - Math.abs(u) * .3], [u * 1.9 + .05 * Math.sin(i * 3), 1.75 + .12 * Math.sin(i * 2.3), .8 - Math.abs(u) * .3]], [.07, .085, .085, .085, .035]); } for (let i = 0; i < 7; i++) B.groove([-.55 + i * .18, 3.2 + .5 * Math.sin(i * 2), .85], V.norm([1, .15 * Math.sin(i * 3), 0]), .022, .04, .9 + .3 * Math.sin(i), { wob: .25, wf: 2 });
  B.group({ mat: 1, k: .03 }); B.tube([[.2, 5.15, .72], [.1, 4.7, .75], [.28, 4.2, .78], [.16, 3.6, .86]], [.02, .07, .05, .012]);
  // 목: 잘린 자리에서 위로 관절 팔
  B.group({ k: .08, kg: .16, amp: .008, freq: 5 }); B.tube([[0, 6.8, 0], [0, 7.15, .02]], [.28, .25]); for (let i = 0; i < 8; i++) { const a = i / 8 * 6.283; B.tube([[Math.cos(a) * .22, 7.05, Math.sin(a) * .2], [Math.cos(a) * .3, 7.22 + .08 * Math.sin(i * 3), Math.sin(a) * .28], [Math.cos(a) * .22, 7.34 + .08 * Math.sin(i * 3), Math.sin(a) * .2]], [.09, .06, .02]); }
  const j1 = [0, 8.3, -.85], j2 = [0, 9.75, .05], hc = [0, 9.35, 1.0]; B.group({ k: .03, kg: .02 }); B.tube([[0, 6.6, -.1], [0, 7.4, -.3], j1], [.13, .13, .13]); B.ball(j1, .24); B.cone(j1, j2, .13, .12); B.ball(j2, .22); B.cone(j2, V.add(hc, [0, .35, -.3]), .11, .11); for (const y of [.3, .7]) B.groove(V.lerp(j1, j2, y), V.sub(j2, j1), .04, .04, .4, { wob: 0 });
  // 등판 + 등불 일곱
  const F = new Frame(hc, [1, 0, 0], [0, 1, 0], [0, 0, 1]).rot(tl, tn, 0), f = v => F.p(v); B.group({ k: .12, kg: 0, amp: .004, freq: 3 }); B.ell(F.at([0, 0, -.22]), [1.55, 1.55, .36]);
  const spots = [[0, 0]]; for (let i = 0; i < 6; i++) { const a = i / 6 * 6.283 + .52; spots.push([Math.cos(a) * 1.02, Math.sin(a) * 1.02]); }
  for (const [x, y] of spots) B.cone(f([x, y, .5]), f([x, y, -.1]), .42, .33, { op: 1, k: .03 });
  for (const [i, [x, y]] of spots.entries()) { B.group({ mat: 2, k: .01 }); B.cone(f([x, y, -.02]), f([x, y, -.1]), .33, .3); B.group({ k: .015, kg: .02 }); const pts = []; for (let j = 0; j <= 16; j++) { const a = j / 16 * 6.283; pts.push(f([x + Math.cos(a) * .43, y + Math.sin(a) * .43, .12])); } B.tube(pts, .05, { per: 2 }); const sh = i === 0 ? (p.eye ?? .2) : .05 + .1 * Math.abs(Math.sin(i * 2.7)); B.group({ k: .03, kg: .02 }); B.ell(F.at([x, y + .17 + sh, -.02]), [.33, .17, .1]); B.ell(F.at([x, y - .17 - sh, -.02]), [.33, .17, .1]); B.group({ mat: 5, k: .002 }); B.ball(f([x, y, .0]), i === 0 ? .07 : .032); }
  // 팔 넷: 두 팔은 살, 두 팔은 등의 관절 팔 끝 손(집게·메스)
  for (const m of [-1, 1]) { const s = [m * .9, 6.8, 0], e = [m * 1.25, 5.25, .35], wr = [m * .85, 4.35, 1.35]; A.arm(B, s, e, wr, .22, { m: .85 }); A.hand(B, new Frame(wr, V.norm([0, .6, .5]), V.norm([-m * .25, -.2, .95]), V.norm([m * .6, .75, .25])), 1.35, { curl: [20, 30, 26, 34], spread: 9, thin: .8, len: 1.2 });
    const a1 = [m * 1.35, 7.65, -.9], a2 = [m * 2.1, 6.1, .25], a3 = [m * 1.55, 5.75, 1.75]; B.group({ k: .03, kg: .04 }); B.tube([[m * .4, 6.8, -.4], [m * .9, 7.3, -.75], a1], .11); B.ball(a1, .19); B.cone(a1, a2, .11, .1); B.ball(a2, .17); B.cone(a2, a3, .09, .08); for (let i = 0; i < 3; i++) { const q = V.add(a3, [m * (i - 1) * .16, .1 * (i - 1), .1]); B.group({ k: .01, kg: .02 }); B.cone(a3, q, .06, .05); B.tube([q, V.add(q, [0, -.08, .55]), V.add(q, [0, -.02, i === 1 ? 1.3 : .95])], [.045, .035, .004]); } }
  return B;
} };
