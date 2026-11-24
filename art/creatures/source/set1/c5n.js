// 5장 비인간형 — 웅크린 것(사용자 승인 컨셉 5S 를 새로 조각): 모퉁이에서 정면으로 기어 나온다. 팔 넷이 거미처럼 꺾이고, 턱이 바닥까지 빠진 긴 얼굴.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'c5n', name: '웅크린 것', kind: '비인간형 · 5장 심층 미로', H: 5.4, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .3 : Math.sin(w * Math.PI * 2);
  // 몸통: 낮게 엎드린 등, 뒤로 빠짐
  const sp = [[0, 2.2, -2.7], [0, 2.9, -2.0], [0, 3.25, -1.1], [0, 3.1, -.2], [0, 2.6, .45]];
  A.torso(B, new Frame([0, 2.85, -.55], [1, 0, 0], V.norm([0, -.1, 1]), V.norm([0, -1, -.1])), { w: .95, d: .5, h: 1.9, n: 9, r: .055, scap: true });
  B.group({ k: .2, kg: .3, amp: .006, freq: 4 }); B.tube([[0, 2.95, -1.3], [0, 2.75, -2.0], [0, 2.3, -2.6]], [.55, .42, .45]); A.rings(B, [[0, 2.9, -1.5], [0, 2.4, -2.5]], 7, .03, .045, .9, { bow: .2 }); A.pelvis(B, new Frame([0, 2.25, -2.75], [1, 0, 0], V.norm([0, .5, .85]), V.norm([0, -.85, .5])), { w: .55, d: .36 });
  A.spine(B, sp, .13, { n: 18, back: [0, 1, 0], out: .38, wing: true, k: .03 });
  // 팔 넷: 앞 둘은 높이 솟았다 앞 바닥, 뒤 둘(원래 다리 자리 앞)은 더 넓게
  for (const m of [-1, 1]) { const t = m * S; { const s = [m * .9, 2.85, .2], e = [m * 2.25, 4.7 + Math.max(0, t) * .2, .25 + t * .3], wr = [m * 2.35, .42 + Math.max(0, t) * .6, 1.15 + t * .8]; A.arm(B, s, e, wr, .3, { m: 1.0 }); A.hand(B, new Frame(wr, V.norm([-m, 0, .1]), V.norm([m * .12, -.2, .97]), V.norm([0, .97, .2])), 1.65, { curl: 12, spread: 15, thin: .75, len: 1.25 }); }
    { const s = [m * .95, 2.75, -.95], e = [m * 2.7, 4.95 + Math.max(0, -t) * .2, -1.0 - t * .3], wr = [m * 3.25, .42 + Math.max(0, -t) * .6, -.55 - t * .8]; A.arm(B, s, e, wr, .3, { m: 1.0 }); A.hand(B, new Frame(wr, V.norm([-m * .6, 0, .8]), V.norm([m * .75, -.2, .62]), V.norm([0, .97, .2])), 1.65, { curl: 12, spread: 15, thin: .75, len: 1.25 }); }
    const h = [m * .42, 2.1, -2.8], k = [m * 1.2, 2.9, -3.4], an = [m * 1.1, .35, -3.9]; A.leg(B, h, k, an, .28, { m: .8, front: [m * .3, .6, -.4] }); A.foot(B, new Frame(an, [1, 0, 0], [0, 1, 0], V.norm([m * .4, 0, -1])), 1.0, {}); }
  // 목·머리: 앞으로 내밀고 턱이 바닥까지
  A.neck(B, [0, 2.6, .45], [0, 2.75, 1.25], .32, { front: [0, -1, .2], mid: [0, 2.75, .9] });
  const F = new Frame([0, 2.75, 1.6], [1, 0, 0], V.norm([0, 1, -.12]), V.norm([0, .12, 1])).rot(0, p.headYaw || 0, 0); A.head(B, F, 1.75, { jaw: 8, nojaw: true, gaunt: 1.2, eyes: 'hollow', eyeSize: 1.2, eyeH: .085, eyeTilt: -16, nose: 'skull', mouth: false, ears: false, elong: 1.1, wrinkle: true });
  // 빠진 아래턱: 길게 늘어난 살 + 바닥의 턱뼈
  const jy = p.jawDrop ?? 1, f = v => F.p(v), J = new Frame([0, 1.95 - jy * 1.15, 1.75], [1, 0, 0], [0, 1, 0], [0, 0, 1]), j = v => J.p(v);
  B.group({ k: .07, kg: .12, amp: .006, freq: 6 }); B.tube([j([-.42, .25, -.25]), j([-.4, 0, .1]), j([-.24, -.08, .42]), j([0, -.1, .52]), j([.24, -.08, .42]), j([.4, 0, .1]), j([.42, .25, -.25])], [.09, .1, .1, .115, .1, .1, .09]); B.ell(J.at([0, -.1, .1]), [.36, .07, .34], { k: .1 });
  for (const m of [-1, 1]) for (let i = 0; i < 4; i++) { const a = f([m * (.24 - i * .02), -.14 - i * .02, -.06 + i * .09]), b = j([m * (.43 - i * .05), .18, -.2 + i * .17]); B.group({ k: .05, kg: .08 }); B.tube([a, V.add(V.lerp(a, b, .5), [-m * (.12 + i * .03), 0, -.06]), b], [.085, .03 + (i === 0 ? .02 : 0), .07]); }
  B.group({ mat: 2, k: .1 }); B.ell(new Frame(V.lerp(f([0, -.2, 0]), j([0, 0, 0]), .5), [1, 0, 0], [0, 1, 0], [0, 0, 1]), [.3, .55 * jy + .2, .2]);
  B.group({ mat: 1, k: .05 }); B.tube([f([0, -.24, .0]), [.06, 1.75, 1.62], [-.05, 1.2, 1.78], j([.04, .02, .35]), j([.0, .1, .62])], [.12, .12, .13, .12, .03]);
  B.group({ mat: 4, k: .004 }); for (let i = 0; i < 13; i++) { const u = i / 12 * 2 - 1, q = 1 + .4 * Math.sin(i * 8.1); B.cone(f([u * .13, -.23, .3 - u * u * .08]), f([u * .125, -.23 - .075 * q, .3 - u * u * .08]), .034, .008); B.cone(j([u * .34, .0, .46 - u * u * .3]), j([u * .33, .18 * q, .47 - u * u * .3]), .036, .008); }
  const R = []; for (let i = 0; i < 40; i++) { const a = i / 40 * Math.PI * 1.5 + .75 * Math.PI, x = Math.cos(a) * .34, z = Math.sin(a) * .42 - .06, jj = Math.sin(i * 5.3); R.push([f([x * .3, .48, z * .4]), f([x * 1.02, .28, z * 1.02]), V.add(f([x * 1.25, -.1, z * 1.25]), [0, -.1, 0]), V.add(f([x * 1.45 + jj * .08, -.5 - .3 * Math.abs(jj), z * 1.3]), [0, -.3, 0])]); } A.hair(B, R, { r: [.06, .04, .028, .008] });
  return B;
} };
