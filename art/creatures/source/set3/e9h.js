// 시안3 9장 인간형 — 키다리: 천장보다 커서 천장을 따라 등이 접힌 사람. 다리만 여덟 걸음 길이이고, 접힌 몸 끝에서 거꾸로 늘어진 얼굴과 팔이 내려와 길을 막는다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'e9h', name: '키다리', kind: '인간형 · 9장 고가도로', H: 13.6, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .35 : Math.sin(w * Math.PI * 2), dr = p.drop ?? 0;
  const I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]);
  // 다리: 아주 길고 가는, 무릎이 두 번 꺾임
  for (const m of [-1, 1]) { const st = m * S, h = [m * .62, 11.6, -1.2], k = [m * 1.0, 7.4, -.4 + st * 1.1], k2 = [m * .85, 3.6, -1.6 + st * 1.2], an = [m * .9, .4 + Math.max(0, -st) * .35, -1.1 + st * 2.1]; B.group({ k: .16, kg: .3, amp: .008, freq: 3 }); B.tube([h, V.lerp(h, k, .3), V.lerp(h, k, .75), k], [.42, .44, .26, .24]); B.ell(Frame.along(V.add(V.lerp(h, k, .35), [0, 0, .16]), V.sub(k, h)), [.24, 1.4, .24]); B.ball(V.add(k, [0, 0, .12]), .27, { k: .16 }); B.groove(V.add(V.lerp(h, k, .45), [m * .2, 0, .1]), [1, .05, .2], .03, .05, 1.6, { wob: .05 }); B.group({ k: .12, kg: .18, amp: .006, freq: 4 }); B.tube([k, V.lerp(k, k2, .3), V.lerp(k, k2, .75), k2], [.22, .25, .16, .16]); B.tube([V.add(k, [0, 0, .15]), V.add(V.lerp(k, k2, .5), [0, 0, .12]), V.add(k2, [0, 0, .1])], [.1, .09, .08], { k: .05 }); B.ball(V.add(k2, [0, 0, -.1]), .22, { k: .12 }); B.group({ k: .1, kg: .15, amp: .006, freq: 4 }); B.tube([k2, V.lerp(k2, an, .3), V.lerp(k2, an, .8), an], [.16, .2, .11, .12]); B.tube([V.add(V.lerp(k2, an, .55), [0, 0, -.1]), V.add(an, [0, .1, -.2])], [.06, .06], { k: .04 }); A.foot(B, new Frame(an, [1, 0, 0], [0, 1, 0], V.norm([m * .2, 0, 1])), 1.9, { toe: 1.3 }); }
  // 골반 → 천장을 따라 앞으로 눕는 척추
  const P = new Frame([0, 11.7, -1.1], [1, 0, 0], V.norm([0, .75, .66]), V.norm([0, -.66, .75])); A.pelvis(B, P, { w: .78, d: .48 });
  const cy = 12.75, sp = [[0, 11.8, -1.15], [0, 12.6, -.6], [0, cy + .1, .4], [0, cy, 1.6], [0, cy - .1, 2.6]]; B.group({ k: .2, kg: .3, amp: .008, freq: 4 }); B.tube(sp, [.5, .4, .36, .44, .4]); A.rings(B, sp.slice(0, 3), 7, .03, .05, .8, { bow: .4 });
  A.spine(B, sp.map(q => V.add(q, [0, .38, -.1])), .15, { n: 18, back: [0, 1, -.3], out: .06, wing: true, k: .04, kg: .03 });
  const TF = new Frame([0, cy - .15, 2.0], [1, 0, 0], V.norm([0, -.12, 1]), V.norm([0, -1, -.12])); A.torso(B, TF, { w: .95, d: .56, h: 2.0, n: 9, r: .055, scap: true });
  // 목: 어깨에서 아래로 꺾여 늘어짐 → 얼굴은 거꾸로 이쪽을 봄
  const n0 = [0, cy - .25, 3.1], n1 = [0, cy - .9 - dr * .6, 3.75], n2 = [.05, cy - 2.0 - dr * 2.2, 3.7]; B.group({ k: .14, kg: .25 }); B.tube([n0, [0, cy - .3, 3.55], n1, n2], [.34, .27, .22, .24]); A.rings(B, [[0, cy - .3, 3.55], n1, n2], 10, .03, .045, .45, { tilt: .15, bow: 0 }); B.group({ k: .03, kg: .06 }); for (const m of [-1, 1]) B.tube([V.add(n0, [m * .25, 0, .1]), V.add(n1, [m * .16, 0, .12]), V.add(n2, [m * .16, 0, .1])], [.07, .06, .05]);
  const HF = new Frame(V.add(n2, [0, -.75, .12]), [-1, 0, 0], [0, -1, 0], [0, 0, 1]).rot(4, p.headYaw || 0, p.tilt ?? 8); A.face(B, HF, 1.9, { jaw: p.jaw ?? 46, eyes: 'real', gaunt: 1.4, teeth: 12, iris: .011, w: .95, elong: 1.12, eyeSize: 1.1, tongue: 'red', tongueLen: .0 });
  // 머리카락: 거꾸로 매달려 바닥 쪽으로 곧게
  const R = []; for (let i = 0; i < 80; i++) { const a = i / 80 * Math.PI * 2, c = Math.cos(a), s = Math.sin(a), j = Math.sin(i * 5.7); if (s > .55) continue; R.push([HF.p([c * .22, .88, s * .3 - .1]), HF.p([c * .6, .62, s * .72 - .12]), V.add(HF.p([c * .62, .75, s * .72 - .12]), [0, -.9, 0]), V.add(HF.p([c * .5 + j * .05, .8, s * .6 - .12]), [0, -2.2 - 1.3 * Math.abs(j), 0])]); } A.hair(B, R, { r: [.04, .05, .04, .006] });
  // 팔: 천장을 짚는 팔 하나, 아래로 끝없이 늘어진 팔 하나
  { const s = [-1.15, cy - .2, 2.6], e = [-2.5, cy - .95, 3.4], wr = [-2.6, cy + .55, 4.3]; A.arm(B, s, e, wr, .25, { m: .85 }); A.hand(B, new Frame(wr, V.norm([1, 0, .1]), V.norm([-.2, .25, .95]), V.norm([0, -1, .2])), 1.9, { curl: 6, spread: 20, thin: .8, len: 1.4 }); }
  { const s = [1.15, cy - .2, 2.6], e = [1.75, 8.4, 3.0 - S * .3], wr = [1.35, 4.2, 4.0 - S * .5]; A.arm(B, s, e, wr, .26, { m: .7 }); A.hand(B, new Frame(wr, V.norm([0, .1, 1]), V.norm([-.1, -1, .15]), V.norm([1, 0, 0])), 2.2, { curl: [18, 26, 20, 32], spread: 16, thin: .78, len: 1.4 }); }
  // 짧은 두 번째 팔: 얼굴 옆에서 제 뺨을 받침
  for (const m of [-1, 1]) { const s = [m * .7, cy - .5, 2.9], e = [m * 1.35, cy - 1.7, 3.2], wr = V.add(HF.p([-m * .95, .35, .1]), [0, .1, 0]); A.arm(B, s, e, wr, .16, { m: .8 }); A.hand(B, new Frame(wr, V.norm([0, .1, 1]), V.norm([-m * .6, -.8, .15]), V.norm([m * .8, -.6, 0])), 1.2, { curl: 22, spread: 14, thin: .82, len: 1.3 }); }
  return B;
} };
