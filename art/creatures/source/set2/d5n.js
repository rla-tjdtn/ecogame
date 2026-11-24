// 시안2 5장 비인간형 — 끼인 것: 복도 벽 사이에 X자로 버티고 공중에 떠 있다. 팔다리로 벽을 밀며 옆구르기하듯 돌아 온다. 배 전체가 세로로 갈라진 입.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'd5n', name: '끼인 것', kind: '비인간형 · 5장 심층 미로', H: 11, build(p = {}) {
  const B = new Body(), rz = (p.turn ?? .04) * 360, jw = p.jaw ?? .62, C = new Frame([0, 5.9, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]).rot(0, 0, rz), c = v => C.p(v);
  // 몸통: 납작하게 팽팽히 당겨진 살
  A.torso(B, new Frame(c([0, .95, -.05]), C.x, C.y, C.z), { w: .86, d: .46, h: 1.6, n: 7, r: .05 });
  B.group({ k: .2, kg: .3, amp: .008, freq: 4 }); B.tube([c([0, .6, 0]), c([0, -.3, .05]), c([0, -1.1, 0])], [.56, .5, .5]); for (const m of [-1, 1]) { B.tube([c([m * .75, 1.3, 0]), c([m * .5, 0, 0]), c([m * .6, -1.2, 0])], [.2, .16, .2]); A.fold(B, [c([m * .5, 1.0, .35]), c([m * .42, 0, .45]), c([m * .4, -1.0, .35])], .025); }
  A.pelvis(B, new Frame(c([0, -1.3, -.02]), C.x, C.y, C.z), { w: .62, d: .38 });
  // 배의 세로 입: 살을 파내고 가장자리를 말아 올림
  B.ell(new Frame(c([0, -.1, .55]), C.x, C.y, C.z), [jw * .95, 1.3, .45], { op: 1, k: .12 });
  B.group({ k: .1, kg: .2 }); const N = 18; const rim = t => { const a = t * 6.283; return c([Math.sin(a) * jw * (.75 + .2 * Math.sin(a * 2)), -.1 + Math.cos(a) * 1.25, .5 - Math.abs(Math.cos(a)) * .08]); }; for (let i = 0; i < N; i++) B.cone(rim(i / N), rim((i + 1) / N), .085 + .03 * Math.abs(Math.sin(i * 2.3)), .085 + .03 * Math.abs(Math.sin(i * 2.3 + 2.3))); B.group({ mat: 2, k: .05 }); B.ell(new Frame(c([0, -.1, .2]), C.x, C.y, C.z), [jw * .85, 1.2, .12]);
  B.group({ mat: 4, k: .004 }); for (let i = 0; i < 24; i++) { const t = (i + .5) / 24, q = rim(t), a = t * 6.283, L = .26 + .16 * Math.abs(Math.sin(i * 3.7)); B.cone(V.add(q, V.mul(C.z, .05)), V.add(V.add(q, V.mul(C.x, -Math.sin(a) * L)), V.add(V.mul(C.y, -Math.cos(a) * L * .5), V.mul(C.z, .1))), .07, .008); }
  B.group({ mat: 1, k: .06 }); B.tube([c([0, -.8, .35]), c([.1, -.5, .62]), c([-.08, -.1, .85]), c([.05, .25, .9])], [.12, .12, .09, .02]);
  // 팔다리: 벽까지 뻗어 손발바닥이 벽에 붙음
  const wall = 3.9; const limb = (sx, sy, isArm) => { const d = C.d([sx, sy, 0]), st = isArm ? c([sx * .95, 1.45, 0]) : c([sx * .45, -1.35, 0]); const dir = V.norm([Math.sign(d[0]) || 1, d[1] * 1.05, 0]); const end = [Math.sign(d[0] || 1) * wall, st[1] + (d[1] > 0 ? 1 : -1) * (isArm ? 1.7 : 2.0), isArm ? .35 : .1]; const mid = V.add(V.lerp(st, end, .48), [0, isArm ? -.5 : .75, isArm ? 1.5 : 1.45]); const pl = [-Math.sign(end[0]), 0, 0]; if (isArm) { A.arm(B, st, mid, end, .24, { m: .95 }); A.hand(B, new Frame(end, V.norm([0, 0, 1]), V.norm([0, Math.sign(end[1] - st[1]), .25 * sx]), V.norm(pl)), 1.5, { curl: 4, spread: 18, thin: .85, len: 1.15 }); } else { A.leg(B, st, mid, end, .31, { m: .95, front: [0, .2, 1] }); A.foot(B, new Frame(end, V.norm([0, 0, 1]), V.norm(pl), V.norm([0, Math.sign(end[1] - st[1]), .3])), 1.15, {}); } };
  for (const sx of [-1, 1]) { limb(sx, .8, true); limb(sx, -.8, false); }
  // 머리: 뒤로 젖혀져 등 뒤에서 이쪽을 넘겨다봄(작고 조용한 얼굴)
  A.neck(B, c([0, 1.75, .05]), c([0, 1.95, .75]), .2, { mid: c([0, 2.05, .4]) }); const HF = new Frame(c([.05, 1.85, 1.15]), C.x, V.norm(V.add(V.mul(C.y, .92), V.mul(C.z, .4))), V.norm(V.add(V.mul(C.z, .92), V.mul(C.y, -.4)))).rot(0, p.headYaw || 0, 30); A.head(B, HF, 1.25, { jaw: 12, teeth: 8, gaunt: 1.2, eyes: 'pin', eyeSize: 1.1, pin: .016, nose: 'human', mouth: true, elong: 1.05 });
  const R = []; for (let i = 0; i < 34; i++) { const a = i / 34 * Math.PI * 1.5 + .75 * Math.PI, x = Math.cos(a) * .33, z = Math.sin(a) * .4 - .06, j = Math.sin(i * 5.3); R.push([HF.p([x * .4, .45, z * .5]), HF.p([x * 1.03, .28, z * 1.03]), V.add(HF.p([x * 1.15, -.1, z * 1.15]), [0, -.25, 0]), V.add(HF.p([x * 1.15 + j * .06, -.2, z * 1.15]), [0, -.9 - .4 * Math.abs(j), 0])]); } A.hair(B, R, { r: [.045, .034, .024, .006] });
  return B;
} };
