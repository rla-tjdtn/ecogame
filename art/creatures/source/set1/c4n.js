// 4장 비인간형 — 뒤집힌 환자(사용자 승인 컨셉 4S 를 새 엔진으로 다시 조각): 배를 하늘로, 몸을 뒤로 젖힌 다리. 거꾸로 매달린 얼굴이 앞.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'c4n', name: '뒤집힌 환자', kind: '비인간형 · 4장 폐병원', H: 4.6, build(p = {}) {
  const B = new Body(), w = p.walk || 0, S = Math.sin(w * Math.PI * 2);
  // 몸통 다리(아치): 어깨가 앞(+z), 골반이 뒤
  const sh = [0, 2.75, 1.35], ch = [0, 3.65, .55], bl = [0, 3.95, -.45], pv = [0, 3.35, -1.55];
  // 가슴·배: 위를 본다(y = 배쪽)
  const chest = Frame.along([0, 3.28, .85], V.sub(ch, sh), [0, 1, .2]).rot(0, 0, 0); // y: 어깨→골반 방향, z: 하늘
  const CF = new Frame(chest.o, chest.x, V.mul(chest.y, -1), chest.z); // y = 어깨 쪽
  A.torso(B, CF, { w: .72, d: .45, h: 1.6, n: 8, r: .05 });
  B.group({ k: .25, kg: .3, amp: .012, freq: 4 }); B.tube([[0, 3.5, .35], bl, [0, 3.75, -1.0], pv], [.45, .34, .36, .45]); for (let i = 0; i < 6; i++) { const t = i / 5, z = .25 - t * 1.6, y = 3.98 + Math.sin(t * 3.1) * .28 - t * .12; A.fold(B, [[-.42, y - .28, z], [-.2, y - .02, z + .03], [0, y + .03, z - .02], [.2, y - .02, z + .03], [.42, y - .28, z]], .018, { k: .05 }); }
  const PF = new Frame(pv, [1, 0, 0], V.norm([0, .45, .9]), V.norm([0, .9, -.45])); A.pelvis(B, PF, { w: .62, d: .4 });
  // 배꼽 위 세로 수술 자국(붉은) + 실밥
  B.group({ mat: 1, k: .01 }); B.tube([[0, 3.9, .45], [.02, 4.12, .0], [-.01, 4.3, -.45], [.01, 4.14, -1.0]], [.03, .04, .04, .02]);
  B.group({ k: .01 }); for (let i = 0; i < 8; i++) { const t = i / 7, y = 3.88 + Math.sin(t * Math.PI) * .3 + t * .12, z = .5 - t * 1.45; B.tube([[-.13, y - .02, z + .03], [0, y + .06, z], [.13, y - .02, z - .03]], .016); }
  // 팔: 어깨가 뒤집혀 손바닥을 뒤로 짚음(앞다리). 다리: 뒤에서 무릎을 높이 세움
  for (const m of [-1, 1]) {
    const lift = Math.max(0, S * m) * .5, stride = Math.cos(w * Math.PI * 2) * m * .45 * (p.walk != null ? 1 : 0);
    const s = [m * .82, 2.85, 1.2], e = [m * 1.42, 2.15 + lift * .4, 1.55 + stride * .5], wr = [m * 1.22, .3 + lift, 1.75 + stride]; const a = A.arm(B, s, e, wr, .23, { m: .8 });
    A.hand(B, new Frame(wr, [m * .25, 0, -.97].map(x => x * 1), V.norm([m * .5, -.16, .84]), V.norm([0, .98, .18])), 1.6, { curl: 14, spread: 13, thin: .8, len: 1.15 });
    const l2 = Math.max(0, -S * m) * .5, h = [m * .48, 3.1, -1.7], k = [m * 1.12, 3.95 + l2 * .3, -2.75 - stride * .3], an = [m * .95, .28 + l2, -3.05 - stride]; A.leg(B, h, k, an, .33, { m: 1.05, front: [m * .2, .5, -1] });
    A.foot(B, new Frame(an, [m, 0, 0].map(Math.abs), [0, 1, 0], V.norm([m * .25, 0, -1])).rot(0, 0, 0), 1.05, {});
  }
  // 목: 어깨 사이에서 아래로 늘어져 앞으로 — 머리가 거꾸로(정수리가 바닥) 얼굴이 앞(+z)
  const nk = [0, 2.1, 1.95], hd = [0, 1.45, 2.2]; A.neck(B, [0, 2.9, 1.5], nk, .24, { front: [0, .5, .85], mid: [0, 2.5, 1.82] });
  const HF = new Frame([0, 1.5, 2.2], [-1, 0, 0], V.norm([0, -1, .12]), V.norm([0, .12, 1])).rot(0, p.headYaw || 0, p.headRoll ?? 9);
  A.head(B, HF, 1.5, { jaw: p.jaw ?? 34, gaunt: 1.2, eyes: 'pin', eyeSize: 1.15, eyeH: .075, teeth: 11, toothLen: .055, nose: 'human', mouthW: 1.15, ears: true });
  // 젖은 머리카락: 정수리에서 바닥으로
  const R = []; for (let i = 0; i < 44; i++) { const a = i / 44 * Math.PI * 2, rr = .2 + .12 * ((i * 7) % 3) / 2, x = Math.cos(a) * rr, z = Math.sin(a) * rr - .12, j = Math.sin(i * 5.1); const b = HF.p([x * .8, .3, z * .8]); R.push([b, [b[0] + x * -.3, b[1] - .18, b[2] + z * .3], [b[0] - x * .4 + j * .06, Math.max(.22, b[1] - .5), b[2] + z * .7 + .05], [b[0] - x * .3 + j * .14, .04 + (i % 4) * .03, b[2] + z * 1.2 + .12]]); } A.hair(B, R, { r: [.05, .03, .018, .005] });
  // 환자복 남은 자락: 골반에서 늘어진 끈
  B.group({ k: .02, kg: .04 }); for (const m of [-1, 1]) B.tube([[m * .6, 3.35, -1.2], [m * .78, 2.9, -1.15], [m * .74, 2.3, -1.3], [m * .82, 1.8, -1.2]], [.05, .035, .03, .012]);
  return B;
} };
