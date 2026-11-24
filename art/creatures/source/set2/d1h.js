// 시안2 1장 인간형 — 척수: 머리가 등뼈째 뽑혀 나와 몸보다 높이 휘어 있다. 낚시찌처럼 늘어진 얼굴이 위에서 내려다본다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'd1h', name: '척수', kind: '인간형 · 1장 지하 시설', H: 11.4, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .35 : Math.sin(w * Math.PI * 2), dr = p.drop ?? 0, sw = p.sway ?? 0;
  for (const m of [-1, 1]) { const st = m * S, h = [m * .42, 3.95, 0], k = [m * .52, 2.2, .3 + st * .5], an = [m * .46, .34 + Math.max(0, -st) * .2, -.15 + st * .9]; A.leg(B, h, k, an, .34, { m: .8, front: [m * .15, 0, 1] }); A.foot(B, new Frame(an, [1, 0, 0], [0, 1, 0], V.norm([m * .2, 0, 1])), 1.15, {}); }
  A.pelvis(B, new Frame([0, 4.1, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]), { w: .56, d: .36 });
  B.group({ k: .18, kg: .25, amp: .006, freq: 4 }); B.tube([[0, 4.15, 0], [0, 4.9, .1], [0, 5.6, 0]], [.44, .36, .46]); A.rings(B, [[0, 4.3, .1], [0, 5.2, .1]], 5, .024, .04, .9, { bow: .3 });
  A.torso(B, new Frame([0, 6.1, -.02], [1, 0, 0], V.norm([0, 1, -.04]), [0, 0, 1]), { w: .74, d: .46, h: 1.5, n: 8, r: .05 });
  // 머리가 빠져나간 목 구멍: 찢긴 살이 꽃잎처럼
  B.group({ k: .07, kg: .12, amp: .01, freq: 5 }); for (let i = 0; i < 11; i++) { const a = i / 11 * Math.PI * 2, q = .6 + .5 * Math.abs(Math.sin(i * 3.3)); B.tube([[Math.cos(a) * .3, 6.78, Math.sin(a) * .26], [Math.cos(a) * .3, 7.0, Math.sin(a) * .26], [Math.cos(a) * (.42 + .12 * q), 7.05 + .12 * q, Math.sin(a) * (.38 + .12 * q)], [Math.cos(a) * (.52 + .2 * q), 6.92 + .1 * q, Math.sin(a) * (.46 + .2 * q)]], [.13, .1, .07, .015]); }
  B.group({ mat: 2, k: .02 }); B.ball([0, 6.95, 0], .22);
  // 뽑혀 나온 등뼈: 뒤로 솟아 앞으로 휘어 내려옴
  const hd = [sw * .9, 8.7 - dr * 2.6, 2.75 + dr * .4]; const sp = [[0, 6.3, -.15], [0, 7.3, -.35], [sw * .2, 8.9, -.3], [sw * .5, 10.3, .4], [sw * .75, 10.6 - dr * .5, 1.5], [sw * .9, 9.9 - dr * 1.7, 2.4], V.add(hd, [0, .42, -.15])];
  const cm = t => { const N = sp.length - 1, u = Math.min(.9999, t) * N, j = Math.floor(u), f = u - j, P = [sp[Math.max(0, j - 1)], sp[j], sp[j + 1], sp[Math.min(N, j + 2)]]; return [0, 1, 2].map(k => .5 * (2 * P[1][k] + (P[2][k] - P[0][k]) * f + (2 * P[0][k] - 5 * P[1][k] + 4 * P[2][k] - P[3][k]) * f * f + (3 * P[1][k] - P[0][k] - 3 * P[2][k] + P[3][k]) * f * f * f)); };
  B.group({ k: .03, kg: .05 }); B.tube(sp, .07); const M = 26; for (let i = 0; i < M; i++) { const t = .06 + i / M * .92, q = cm(t), d = V.norm(V.sub(cm(t + .012), q)); let s = V.norm(V.cross(d, [1, 0, .05])); const side = V.norm(V.cross(d, s)), r = .23 - i / M * .09, F = new Frame(q, side, d, s); B.group({ k: .035, kg: .015 }); B.ell(F, [r * .9, r * .52, r * .8]); B.tube([q, V.add(q, V.mul(s, -r * 1.2)), V.add(q, V.add(V.mul(s, -r * 2.0), V.mul(d, -r * .7)))], [r * .4, r * .28, r * .1]); for (const m of [-1, 1]) B.cone(q, V.add(q, V.add(V.mul(side, m * r * 1.65), V.mul(s, -r * .4))), r * .34, r * .16); }
  // 신경 다발: 등뼈를 타고 내려온 가는 줄(붉은 하나)
  for (let k = 0; k < 5; k++) { const pts = []; for (let i = 0; i <= 12; i++) { const t = .1 + i / 12 * .85, q = cm(t), a = k * 1.26 + t * 5; pts.push(V.add(q, [Math.cos(a) * .24, Math.sin(a) * .2, Math.sin(a) * .2])); } B.group({ k: .01, mat: k === 0 ? 1 : 0 }); B.tube(pts, k === 0 ? .035 : .024, { per: 2 }); }
  for (let k = 0; k < 9; k++) { const t = .55 + k * .045, q = cm(t), j = Math.sin(k * 4.3); B.group({ k: .01 }); B.tube([q, V.add(q, [j * .2, -.5, .05]), V.add(q, [j * .3, -1.1 - .4 * Math.abs(j), .1 * j])], [.035, .022, .006]); }
  // 머리: 피부가 흘러내린 얼굴, 아래를 향함
  const HF = new Frame(hd, [1, 0, 0], V.norm([0, .82, -.5]), V.norm([0, .5 - dr * .6, .82])).rot(0, p.headYaw || 0, -8 + sw * 14); const H = A.head(B, HF, 1.45, { jaw: p.jaw ?? 20, gaunt: 1.4, eyes: 'pin', eyeSize: 1.15, eyeH: .08, pin: .015, nose: 'human', teeth: 10, elong: 1.08, w: .92 });
  B.group({ k: .06, kg: .08 }); for (const m of [-1, 1]) for (let i = 0; i < 3; i++) B.tube([H.P([m * (.2 + i * .04), -.28, .12 - i * .1]), H.P([m * (.22 + i * .05), -.6, .1 - i * .1]), H.P([m * (.18 + i * .06), -.9 - .12 * i, .06 - i * .08])], [.07, .045, .012].map(x => x * 1.4));
  // 팔: 어깨에서 길게, 손바닥이 앞
  for (const m of [-1, 1]) { const s = [m * .88, 6.72, 0], e = [m * 1.2, 5.1, .1 - m * S * .25], wr = [m * 1.1, 3.5, .5 - m * S * .5]; A.arm(B, s, e, wr, .22, { m: .85 }); A.hand(B, new Frame(wr, V.norm([m, 0, .1]), V.norm([0, -1, .1]), V.norm([0, .1, -1])), 1.4, { curl: [12, 18, 16, 22], spread: 10, thin: .8, len: 1.15 }); }
  return B;
} };
