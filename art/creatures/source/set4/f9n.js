// 시안4 9장 비인간형 — 차밑: 주차된 차 밑 틈에 사는 납작한 사람. 배를 바닥에 붙인 채 거미처럼 팔꿈치를 높이 세우고, 뺨을 바닥에 댄 옆얼굴로 차 밑에서 이쪽 발목을 올려다본다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
const I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]);
module.exports = { id: 'f9n', name: '차밑', kind: '비인간형 · 9장 지하 주차장', H: 2.4, build(p = {}) {
  const B = new Body(), c = p.crawl, S = c == null ? .4 : Math.sin(c * Math.PI * 2), lift = p.lift ?? 0, jaw = p.jaw ?? 22;
  // ---- 몸통: 엎드려 납작하게 눌린 가슴(갈비·견갑이 등에 드러남), 배는 바닥에 붙음
  const TF = new Frame([0, .62 + lift * .3, .25], [1, 0, 0], V.norm([0, .08 + lift * .3, 1]), V.norm([0, -1, .08 + lift * .3]));
  B.group({ k: .22, kg: .25, amp: .004, freq: 4, rid: .0015, rf: 3 }); B.ell(TF.at([0, .1, .02]), [1.08, 1.0, .34]); B.ell(TF.at([0, .72, -.02]), [1.12, .38, .33]); for (const m of [-1, 1]) { B.ell(TF.at([m * 1.02, .68, .02]), [.3, .32, .3]); B.ell(TF.at([m * .5, .45, -.28]).rot(0, 0, m * -12), [.32, .4, .1], { k: .1 }); B.tube([TF.p([m * .22, .85, -.33]), TF.p([m * .62, .82, -.3]), TF.p([m * .82, .55, -.27])], [.05, .06, .04], { k: .08 }); for (let i = 0; i < 4; i++) B.groove(TF.p([m * .95, -.35 + i * .22, -.12]), TF.d([m * .2, 1, -.4]), .016, .025, .45, { bow: .5, wob: .2 }); } B.groove(TF.p([0, .2, -.36]), [1, 0, 0], .03, .04, .25, { wob: .1 });
  B.group({ k: .25, kg: .3, amp: .006, freq: 4 }); B.ell(I([0, .36, -.8]), [.95, .3, .95]); B.ell(I([0, .3, .3]), [1.25, .24, 1.1]); for (const m of [-1, 1]) B.ell(I([m * 1.1, .2, .2]).rot(0, m * 10, 0), [.4, .14, .7]); // 바닥에 퍼진 배·가슴
  A.spine(B, [[0, .62, -1.55], [0, .72, -.7], [0, .9, .2], [0, .92, 1.0]], .11, { n: 20, back: [0, 1, 0], out: .02, k: .03 });
  for (let i = 0; i < 3; i++) B.groove([0, .55, -.6 - i * .28], [0, .3, 1], .02, .03, .7, { bow: .4, wob: .2 }); // 허리 주름
  A.pelvis(B, new Frame([0, .48, -1.45], [1, 0, 0], V.norm([0, .2, 1]), V.norm([0, -1, .2])), { w: .74, d: .32 });
  // ---- 다리: 개구리처럼 옆으로 벌려 접힘, 발바닥이 위를 봄
  for (const m of [-1, 1]) { const st = m * S, h = [m * .5, .45, -1.55], k = [m * 1.75, .62, -1.2 + st * .35], an = [m * 1.4, .2, -2.25 + st * .3];
    A.leg(B, h, k, an, .3, { m: .85, front: [m * .5, .85, 0] }); const fy = [0, -1, 0], fz = V.norm([m * .3, 0, -1]); A.foot(B, new Frame(an, V.mul(V.cross(fy, fz), -m), fy, fz), 1.1, { toe: 1.2 }); }
  // ---- 팔: 거미처럼 높이 세운 팔꿈치, 너무 긴 아래팔, 바닥을 짚은 손
  for (const m of [-1, 1]) { const st = m * S, s = TF.p([m * 1.1, .7, 0]), e = [m * 2.25, 1.15 + st * .15, .9 + st * .5], wr = [m * 2.35, .2, 2.4 + st * .8];
    A.arm(B, s, e, wr, .18, { m: .8 }); B.group({ k: .04, kg: .08 }); B.ball(e, .14); for (let i = 0; i < 3; i++) B.groove(V.add(e, [0, .05, -.1]), V.norm([m * .2, 1, (i - 1) * .4]), .015, .02, .25, { bow: .5 });
    const y = V.norm([m * .12, 0, 1]), z = [0, 1, 0], x0 = V.cross(y, z), x = m > 0 ? x0 : V.mul(x0, -1);
    A.hand(B, new Frame(V.add(wr, [0, -.06, 0]), x, y, z).rot(-6, 0, 0), 1.5, { curl: [8, 4, 6, 12], spread: 15, thin: .74, len: 1.45, thumbOut: 52 }); }
  // ---- 목: 앞으로 길게 늘어남 → 머리는 오른뺨을 바닥에 댄 채 앞을 봄
  const hx = p.headX ?? 0, HF = new Frame([.12 + hx, .53 + lift * .5, 2.7], [0, 1, 0], [-1, 0, 0], [0, 0, 1]).rot(0, p.headYaw ?? -8, lift * 30);
  A.neck(B, TF.p([0, .85, .05]), HF.p([.05, -.42, -.15]), .2, { front: [0, -1, 0], mid: [.0, .55, 1.75] });
  const H = A.face(B, HF, 1.6, { jaw, eyes: 'real', iris: .017, open: 1.15, gaunt: 1.3, teeth: 10, age: .8, gaze: [.012, -.004], w: .95 });
  // 눌린 아래쪽 볼(바닥에 납작)
  B.group({ k: .08, kg: .1 }); B.ell(new Frame([-.05, .1, 2.45], [1, 0, 0], [0, 1, 0], [0, 0, 1]), [.42, .1, .45]);
  // 머리카락: 바닥에 넓게 퍼짐
  { const R = []; for (let i = 0; i < 40; i++) { const a = -2.3 + i / 39 * 4.2, L = 1.3 + .8 * Math.abs(Math.sin(i * 2.7)), r0 = HF.p([Math.sin(a * .5) * .1, .32, -.1 + Math.cos(a) * .15].map((v, j) => v * 1.6)), dir = V.norm([-Math.cos(a) * .9, 0, Math.sin(a) * 1.0]); const pts = [r0]; for (let j = 1; j <= 4; j++) { const t = j / 4, q = V.add(r0, V.mul(dir, L * t)); pts.push([q[0] + Math.sin(i * 1.7 + j * 1.3) * .12 * t, Math.max(.03, r0[1] * (1 - t) ** 2 + .03), q[2] + Math.cos(i * 2.1 + j) * .12 * t]); } R.push(pts); } A.hair(B, R, { r: [.035, .03, .024, .016, .008] }); }
  // 입가에서 바닥으로 흐른 붉은 자국(유일한 붉은 곳)
  B.group({ mat: 1, k: .03 }); { const a = H.J([-.08, -.3, .3]); B.tube([a, V.add(a, [-.06, -.1, .1]), [a[0] - .16, .04, a[2] + .28], [a[0] - .26, .03, a[2] + .6], [a[0] - .3, .025, a[2] + .85]], [.014, .016, .022, .02, .008]); }
  return B;
} };
