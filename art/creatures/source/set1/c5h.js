// 5장 사람형 — 나선: 걸레처럼 비틀어 짜인 몸. 발은 뒤를 향하고 가슴은 앞을 향한다. 다가올수록 한 바퀴씩 더 조여진다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'c5h', name: '나선', kind: '사람형 · 5장 심층 미로', H: 10, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .45 : Math.sin(w * Math.PI * 2), tw = p.twist ?? 1.35;
  // 비틀린 다발: a→b, 반지름 r(t), 회전 수
  const wring = (a, b, r0, rm, r1, turns, n, tr, o = {}) => { const d = V.norm(V.sub(b, a)), L = V.len(V.sub(b, a)); let s = V.norm(V.cross(d, [0, 0, 1])); const q = V.cross(d, s); B.group({ k: tr * .35, kg: o.kg ?? .22, amp: .004, freq: 6 }); B.tube([a, V.lerp(a, b, .5), b], [r0 * .7, rm * .6, r1 * .7]); for (let i = 0; i < n; i++) { const pts = [], rs = []; for (let j = 0; j <= 9; j++) { const t = j / 9, an = i / n * Math.PI * 2 + (t - .5) * turns * Math.PI * 2 + (o.ph || 0), k = Math.abs(t * 2 - 1), r = rm + ((t < .5 ? r0 : r1) - rm) * Math.pow(k, 1.6); pts.push(V.add(V.lerp(a, b, t), V.add(V.mul(s, Math.cos(an) * r), V.mul(q, Math.sin(an) * r)))); rs.push(tr * (.55 + .6 * Math.pow(k, 1.2))); } B.tube(pts, rs, { per: 2 }); } };
  // 다리(발끝은 뒤)
  for (const m of [-1, 1]) { const st = m * S, h = [m * .42, 4.35, 0], k = [m * .46, 2.4, -.25 + st * .55], an = [m * .42, .34 + Math.max(0, -st) * .2, .12 + st * .95]; A.leg(B, h, k, an, .33, { m: .75, front: [m * -.1, 0, -1] }); A.foot(B, new Frame(an, [1, 0, 0], [0, 1, 0], V.norm([m * .2, 0, -1])), 1.2, {}); }
  A.pelvis(B, new Frame([0, 4.5, 0], [-1, 0, 0], [0, 1, 0], [0, 0, -1]), { w: .62, d: .38 });
  // 허리: 꽉 짜임
  wring([0, 4.55, 0], [0, 6.85, .05], .5, .13, .55, tw, 9, .15);
  A.torso(B, new Frame([0, 7.4, .02], [1, 0, 0], V.norm([0, 1, .03]), [0, 0, 1]).rot(0, 14, 0), { w: .74, d: .46, h: 1.45, n: 7, r: .05 });
  for (let i = 0; i < 5; i++) B.groove([0, 6.95 + i * .2, 0], [.35, 1, .25], .025, .045, 1.1, { bow: .1, wob: .1 });
  // 목도 짜임
  wring([0, 8.1, .02], [.06, 9.05, .2], .26, .1, .24, .9, 7, .075, { ph: .6, kg: .14 });
  // 팔: 위팔이 짜이고 손목에서 한 번 더
  for (const m of [-1, 1]) { const s = [m * .86, 8.05, .1], e = [m * 1.15, 6.35, .05 - m * S * .25], wr = [m * 1.0, 4.55, .35 - m * S * .55]; B.group({ k: .12, kg: .22 }); B.ell(new Frame(s, [1, 0, 0], [0, 1, 0], [0, 0, 1]), [.26, .3, .26]); wring(s, e, .2, .09, .17, m * .9, 6, .075); wring(e, wr, .17, .07, .12, -m * .9, 6, .06, { kg: .16 }); A.hand(B, new Frame(wr, V.norm([m * .2, 0, -1]), V.norm([0, -1, .08]), V.norm([-m * 1, 0, -.2])), 1.55, { curl: [10, 16, 12, 20], spread: 10, thin: .75, len: 1.25 }); }
  // 머리: 얼굴도 사선으로 쓸림. 눈은 살에 덮이고 입만 비스듬히 벌어짐
  const HF = new Frame([.08, 9.55, .28], V.norm([1, -.25, 0]), V.norm([.25, 1, .02]), [0, 0, 1]).rot(0, (p.headYaw || 0) - 12, 0); A.head(B, HF, 1.3, { jaw: p.jaw ?? 26, jawTwist: 16, gaunt: 1.35, eyes: 'skin', nose: 'human', elong: 1.12, w: .92, ears: false, wrinkle: false, mouthW: .9, teeth: 8 });
  const hg = B.groups.find(g => g.amp && g.freq > 5 && g.prims.length > 18 && g.kg < .13) || B.g; const keep = B.g; B.g = B.groups[B.groups.length - 1]; B.g = keep;
  // 얼굴을 감는 나선 주름(머리 그룹에 직접)
  for (const g of B.groups) if (g.prims.some(q => q.op === 1 && q.t === 1) && g.mat === 0 && g.prims.length > 20) { B.g = g; for (let i = 0; i < 9; i++) B.groove(HF.p([0, .5 - i * .11, 0]), V.add(HF.y, V.add(V.mul(HF.x, .75), V.mul(HF.z, .25))), .02, .032, .75, { bow: .05, wob: .1, wf: 5 }); break; }
  B.g = null; B.group({ mat: 1, k: .02 }); B.tube([HF.J ? [0, 0, 0] : HF.p([-.06, -.36, .2]), HF.p([.02, -.42, .24]), HF.p([.1, -.38, .2])], [.02, .05, .02]);
  return B;
} };
