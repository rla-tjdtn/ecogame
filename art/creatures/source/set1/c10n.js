// 10장 비인간형 — 만석: 같은 줄에 앉은 관객 넷이 의자째 하나로 붙어 옆걸음으로 움직인다. 팔걸이 밑에서 나온 팔다리가 게처럼 바닥을 짚고, 고개 넷이 동시에 너를 향한다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'c10n', name: '만석', kind: '비인간형 · 10장 폐영화관', H: 6.2, build(p = {}) {
  const B = new Body(), w = p.walk, ph = w == null ? .15 : w, look = p.look ?? 0; const X = [-2.7, -.9, .9, 2.7], by = Math.abs(Math.sin(ph * 12.56)) * .06;
  X.forEach((x, i) => {
    // 의자: 등받이 + 좌판 + 팔걸이
    B.group({ k: .06, kg: 0, amp: .004, freq: 3 }); B.box(new Frame([x, 3.55 + by, -.62], [1, 0, 0], V.norm([0, 1, -.14]), V.norm([0, .14, 1])), [.8, 1.35, .16], .15); for (let j = 0; j < 4; j++) B.groove([x - .48 + j * .32, 3.6 + by, -.45], [1, 0, 0], .03, .035, 1.3, { wob: .03 }); B.groove([x, 4.2 + by, -.45], [0, 1, 0], .03, .035, .9, { wob: .04 });
    B.group({ k: .06, kg: 0 }); B.box(new Frame([x, 2.28 + by, .1], [1, 0, 0], V.norm([0, 1, .1]), V.norm([0, -.1, 1])), [.76, .2, .72], .15);
    // 앉은 사람: 좌판·등받이에 살이 들러붙음
    const tw = Math.sin(i * 2.7) * .08; A.pelvis(B, new Frame([x, 2.75 + by, -.12], [1, 0, 0], [0, 1, 0], [0, 0, 1]), { w: .48, d: .36 }); B.group({ k: .18, kg: .25, amp: .008, freq: 4 }); B.tube([[x, 2.8 + by, -.1], [x + tw, 3.35 + by, -.05], [x + tw, 3.8 + by, -.12]], [.44, .36, .44]); A.rings(B, [[x, 2.9 + by, 0], [x, 3.5 + by, 0]], 4, .025, .04, .8, { bow: .3 }); A.torso(B, new Frame([x + tw, 4.1 + by, -.12], [1, 0, 0], V.norm([tw, 1, -.05]), [0, 0, 1]), { w: .62, d: .42, h: 1.25, n: 7, r: .045, scap: false });
    for (const m of [-1, 1]) { B.group({ k: .08, kg: .14 }); for (let j = 0; j < 3; j++) B.tube([[x + m * .5, 3.2 + j * .4 + by, -.2], [x + m * .64, 3.15 + j * .42 + by, -.4], [x + m * .62, 3.1 + j * .45 + by, -.5]], [.14, .06, .12]); }
    // 다리: 앞으로 내려와 바닥을 짚고 무릎이 바깥으로(옆걸음)
    for (const m of [-1, 1]) { const q = Math.sin((ph + i * .25 + (m > 0 ? .5 : 0)) * 6.283), lift = Math.max(0, q) * .4; const h = [x + m * .3, 2.6 + by, .2], k = [x + m * .5 + q * .15, 2.75 + lift * .4, 1.35], an = [x + m * .42 + Math.cos((ph + i * .25 + (m > 0 ? .5 : 0)) * 6.283) * .28, .34 + lift, 1.25]; A.leg(B, h, k, an, .25, { m: .85, front: [m * .2, .6, 1] }); A.foot(B, new Frame(an, [1, 0, 0], [0, 1, 0], V.norm([m * .25, 0, 1])), 1.0, {}); }
    // 이웃과 이어진 팔: 팔걸이 위에서 손이 서로를 파고듦
    if (i < 3) { const ax = x + .9; B.group({ k: .05, kg: 0 }); B.box(new Frame([ax, 3.05 + by, .15], [1, 0, 0], [0, 1, 0], [0, 0, 1]), [.13, .1, .72], .08); B.box(new Frame([ax, 2.4 + by, .2], [1, 0, 0], [0, 1, 0], [0, 0, 1]), [.1, .62, .12], .06); A.arm(B, [x + .66, 4.55 + by, -.1], [x + .86, 3.5 + by, -.05], [ax - .03, 3.22 + by, .62], .17, { m: .85 }); A.arm(B, [X[i + 1] - .66, 4.55 + by, -.1], [X[i + 1] - .86, 3.5 + by, -.05], [ax + .03, 3.22 + by, .5], .17, { m: .85 }); A.hand(B, new Frame([ax - .03, 3.22 + by, .62], [1, 0, 0], V.norm([.1, -.25, 1]), [0, 1, .2]), 1.0, { curl: 26, spread: 7, thin: .9 }); B.group({ k: .08, kg: .12 }); B.ell(new Frame([ax, 3.2 + by, .4], [1, 0, 0], [0, 1, 0], [0, 0, 1]), [.2, .12, .34]); }
    // 머리: 모두 같은 쪽으로 꺾어 정면
    A.neck(B, [x + tw, 4.65 + by, -.1], [x + tw * 2, 5.2 + by, .05], .17, {}); const F = new Frame([x + tw * 2.2, 5.62 + by, .1], [1, 0, 0], [0, 1, .02], [0, 0, 1]).rot(0, look, [14, -20, 9, 26][i]); A.head(B, F, 1.12, { jaw: [4, 30, 16, 38][i], gaunt: 1.1 + i * .08, eyes: i === 1 ? 'pin' : i === 2 ? 'skin' : 'hollow', eyeSize: 1.08, nose: i === 3 ? 'skull' : 'human', teeth: 8, elong: 1 + (i % 2) * .07 });
    if (i !== 3) { const R = []; for (let j = 0; j < 22; j++) { const a = j / 22 * Math.PI * 1.4 + .8 * Math.PI, xx = Math.cos(a) * .33, zz = Math.sin(a) * .4 - .06, jj = Math.sin(j * 5.1 + i); R.push([F.p([xx * .4, .46, zz * .5]), F.p([xx * 1.03, .28, zz * 1.03]), F.p([xx * 1.12, -.12, zz * 1.1]), V.add(F.p([xx * 1.12 + jj * .05, -.34, zz * 1.12]), [0, -.1 - (i === 0 ? .7 : .25) * Math.abs(jj), 0])]); } A.hair(B, R, { r: [.045, .034, .024, .006] }); }
  });
  // 양 끝: 바깥 팔이 바닥을 짚는 집게 다리
  for (const m of [-1, 1]) { const q = Math.sin((ph + (m > 0 ? .25 : .75)) * 6.283), lift = Math.max(0, q) * .5; const s = [m * 3.35, 4.5 + by, -.1], e = [m * 4.65, 4.0 + lift * .4, .25], wr = [m * (4.75 + Math.cos((ph + (m > 0 ? .25 : .75)) * 6.283) * .25), .42 + lift, .7]; A.arm(B, s, e, wr, .21, { m: .9 }); A.hand(B, new Frame(wr, V.norm([-m * .3, 0, .95]), V.norm([m * .9, -.2, .35]), [0, 1, .1]), 1.5, { curl: 12, spread: 14, thin: .8, len: 1.2 }); B.group({ k: .05 }); B.box(new Frame([m * 3.55, 3.05 + by, .15], [1, 0, 0], [0, 1, 0], [0, 0, 1]), [.13, .1, .72], .08); B.box(new Frame([m * 3.55, 2.4 + by, .2], [1, 0, 0], [0, 1, 0], [0, 0, 1]), [.1, .62, .12], .06); }
  // 뒤 다리(의자 쇠다리 대신 팔꿈치): 낮게 받침
  for (const x of [-1.8, 1.8]) { A.arm(B, [x, 2.2 + by, -.5], [x * 1.08, 1.5, -1.5], [x * 1.05, .4, -1.2], .2, { m: .9 }); A.hand(B, new Frame([x * 1.05, .4, -1.2], [1, 0, 0], V.norm([0, -.15, -1]), [0, 1, -.1]), 1.2, { curl: 12, spread: 12, thin: .85 }); }
  // 붉은: 한 사람의 손에 찢긴 표
  B.group({ mat: 1, k: .01 }); B.box(new Frame([1.82, 3.3 + by, 1.3], V.norm([1, 0, .3]), V.norm([0, 1, .4]), V.norm([-.3, -.4, 1])), [.2, .12, .015], .012);
  return B;
} };
