// 시안2 5장 인간형 — 길잡이: 목에서 머리 대신 팔 일곱이 꽃다발처럼 자라 서로 다른 길을 가리킨다. 네가 움직이면 모든 손가락이 너를 가리킨다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'd5h', name: '길잡이', kind: '인간형 · 5장 심층 미로', H: 11, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .4 : Math.sin(w * Math.PI * 2), pt = p.point ?? 0;
  for (const m of [-1, 1]) { const st = m * S, h = [m * .4, 4.3, 0], k = [m * .46, 2.4, .25 + st * .55], an = [m * .42, .34 + Math.max(0, -st) * .2, -.12 + st * .95]; A.leg(B, h, k, an, .33, { m: .8, front: [m * .1, 0, 1] }); A.foot(B, new Frame(an, [1, 0, 0], [0, 1, 0], V.norm([m * .2, 0, 1])), 1.2, {}); }
  A.pelvis(B, new Frame([0, 4.45, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]), { w: .56, d: .36 });
  B.group({ k: .18, kg: .25, amp: .006, freq: 4 }); B.tube([[0, 4.5, 0], [0, 5.3, .1], [0, 6.0, .02]], [.44, .34, .46]); A.rings(B, [[0, 4.7, .1], [0, 5.7, .1]], 6, .024, .04, .9, { bow: .3 });
  A.torso(B, new Frame([0, 6.55, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]), { w: .76, d: .46, h: 1.6, n: 9, r: .05 });
  // 가슴 한가운데 감긴 눈 하나(열리면 붉다)
  { const F = new Frame([0, 6.35, .5], [1, 0, 0], [0, 1, 0], [0, 0, 1]), o = p.eye ?? .1; B.group({ k: .06, kg: .08 }); B.ell(F.at([0, .1 + o * .6, 0]), [.36, .14, .1]); B.ell(F.at([0, -.1 - o * .6, 0]), [.36, .14, .1]); B.group({ mat: 2, k: .01 }); B.ell(F.at([0, 0, -.02]), [.3, .06 + o * .5, .06]); B.group({ mat: 1, k: .01 }); B.ball(F.p([0, 0, .03]), .06 + o * .1); }
  // 목 → 팔 다발
  B.group({ k: .16, kg: .2, amp: .005, freq: 6 }); B.tube([[0, 7.2, 0], [0, 7.75, .03]], [.32, .36]);
  const arms = [[0, 1.2, .25, 0], [-.95, .75, .3, 1], [.95, .8, .2, 1], [-.75, .95, -.55, 2], [.7, .9, -.6, 2], [-1.15, .05, .55, 3], [1.15, .1, .5, 3], [.15, .55, 1.0, 4]];
  arms.forEach(([x, y, z, k], i) => { let d = V.norm([x, y, z]); const tgt = V.norm([x * .25, .18 + .1 * Math.sin(i * 2), 1.0]); d = V.norm(V.lerp(d, tgt, pt * .55)); const s = V.add([0, 7.75, .03], [x * .2, .06 + y * .08, z * .2]), L = 1.35 + .25 * Math.sin(i * 2.1), bend = V.norm(V.cross(d, [.3 * Math.sin(i * 4), .2, 1])); const e = V.add(V.add(s, V.mul(d, L)), V.mul(bend, .28)), fd = V.norm(V.lerp(V.norm(V.add(d, [.25 * Math.sin(i * 5), .15 * Math.cos(i * 3), .2])), tgt, pt)), wr = V.add(e, V.mul(fd, 1.35)); A.arm(B, s, e, wr, .165, { m: .85 }); const up = Math.abs(fd[1]) > .8 ? [0, 0, 1] : [0, 1, 0]; const HF = Frame.along(wr, fd, up); A.hand(B, new Frame(wr, HF.x, fd, HF.z), 1.15, { curl: [4, 68, 72, 76], spread: 4, thin: .85, len: 1.1, thumbOut: 20 }); });
  // 본래 팔 둘: 하나는 뒤를, 하나는 바닥을 가리킴
  { const s = [.9, 7.15, 0], e = [1.35, 5.55, -.15], wr = [1.45, 4.2, .35]; A.arm(B, s, e, wr, .22, { m: .85 }); A.hand(B, new Frame(wr, V.norm([0, 0, 1]), V.norm([.1, -1, .15]), V.norm([1, .1, 0])), 1.35, { curl: [4, 60, 66, 70], spread: 4, thin: .82, len: 1.15 }); }
  { const s = [-.9, 7.15, 0], e = [-1.45, 5.75, -.4 + S * .2], wr = [-1.55, 5.2, -1.7]; A.arm(B, s, e, wr, .22, { m: .85 }); A.hand(B, new Frame(wr, V.norm([0, 1, 0]), V.norm([-.1, -.15, -1]), V.norm([-1, 0, .1])), 1.35, { curl: [4, 60, 66, 70], spread: 4, thin: .82, len: 1.15 }); }
  return B;
} };
