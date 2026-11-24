// 시안2 3장 인간형 — 수초: 머리부터 발끝까지 젖은 머리카락 기둥. 안에서 나온 두 손이 커튼을 젖히면 세로로 늘어선 입 셋이 있다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'd3h', name: '수초', kind: '인간형 · 3장 하수도', H: 9.2, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .4 : Math.sin(w * Math.PI * 2), op = p.open ?? 1.0, sw = S * .12;
  for (const m of [-1, 1]) { const st = m * S, h = [m * .34, 3.4, 0], k = [m * .4, 1.9, .25 + st * .45], an = [m * .36, .32 + Math.max(0, -st) * .15, -.1 + st * .75]; A.leg(B, h, k, an, .27, { m: .75, front: [m * .1, 0, 1] }); A.foot(B, new Frame(an, [1, 0, 0], [0, 1, 0], V.norm([m * .15, 0, 1])), 1.15, { toe: 1.2 }); }
  // 속몸: 검은 기둥 + 갈라진 틈의 갈비
  B.group({ k: .2, kg: .2, amp: .006, freq: 4 }); B.tube([[0, 3.3, 0], [0, 4.6, 0], [0, 6.0, .02], [0, 7.2, .1], [0, 7.9, .2]], [.36, .34, .42, .4, .3]); A.ribs(B, new Frame([0, 5.9, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]), { w: .5, d: .4, h: 1.6, n: 8, r: .04 });
  // 입 셋: 세로로(얼굴·목·명치)
  const mouth = (c, s, jaw, tilt) => { const F = new Frame(c, [1, 0, 0], V.norm([0, 1, -tilt]), V.norm([0, tilt, 1])).sc(s), f = v => F.p(v); B.group({ k: .1, kg: .22 }); B.ell(F.at([0, jaw * .95, .0]), [.36, .12, .14]); B.ell(F.at([0, -jaw * .95, .0]), [.34, .13, .15]); for (const m of [-1, 1]) B.tube([f([m * .3, jaw * .9, .0]), f([m * .37, 0, .02]), f([m * .28, -jaw * .9, .02])], [.1 * s, .05 * s, .1 * s]); B.group({ mat: 2, k: .02 }); B.ell(F.at([0, 0, .0]), [.33, jaw * .98, .12]); B.group({ mat: 4, k: .003 }); for (let i = 0; i < 9; i++) { const u = i / 8 * 2 - 1, q = 1 + .35 * Math.sin(i * 6.1); B.cone(f([u * .27, jaw * Math.sqrt(1 - u * u * .7), .13]), f([u * .25, jaw * Math.sqrt(1 - u * u * .7) - .13 * q, .14]), .045 * s, .02 * s); B.cone(f([u * .25, -jaw * Math.sqrt(1 - u * u * .7), .12]), f([u * .24, -jaw * Math.sqrt(1 - u * u * .7) + .12 * q, .13]), .042 * s, .02 * s); } };
  mouth([0, 8.0, .52], .95, .3, -.1); mouth([.02, 6.95, .52], 1.05, .4, 0); mouth([-.02, 5.75, .5], 1.15, .5, .05);
  B.group({ mat: 1, k: .05 }); B.tube([[0, 5.5, .5], [.06, 5.35, .72], [0, 5.0, .82], [.04, 4.7, .78]], [.12, .13, .1, .03]);
  // 정수리
  B.group({ k: .1, kg: .12 }); B.ell(new Frame([0, 8.5, .12], [1, 0, 0], V.norm([0, 1, .1]), [0, 0, 1]), [.48, .5, .52]);
  // 머리카락: 겹겹이, 앞은 손이 벌린 만큼 갈라짐
  const layers = [[64, .5, 0, 1], [56, .72, .3, .92], [44, .9, .6, .8]]; for (const [N, rad, off, ln] of layers) { const R = []; for (let i = 0; i < N; i++) { let a = i / N * 6.283 + off; let x = Math.sin(a), z = Math.cos(a); const j = Math.sin(i * 7.31 + off * 9), fr = Math.max(0, z); const part = fr > .2 ? op * (x >= 0 ? 1 : -1) * Math.min(1, fr * 1.2) : 0; const gx = y => { const u = Math.max(0, 1 - Math.abs(y - 6.9) / 2.2); return part * .8 * Math.pow(u, .7); }; const end = .25 + (1 - ln) * 6 + Math.abs(j) * 1.1; const pt = (y, r) => [x * r + gx(y) + sw * (9 - y) * .2, y, z * r * (.85 + (z < 0 ? .25 : 0)) + .08]; R.push([pt(8.85, .16), pt(8.62, rad * .72), pt(7.6, rad * .9 + j * .03), pt(6.4, rad * 1.0 + j * .05), pt(4.6, rad * 1.12 + j * .08), pt(2.6, rad * 1.28 + j * .12), pt(end, rad * 1.42 + j * .22)]); } A.hair(B, R, { r: [.07, .075, .07, .062, .052, .038, .008] }); }
  // 팔: 안에서 나와 커튼을 젖힘(긴 손가락이 머리카락을 움켜쥠)
  for (const m of [-1, 1]) { const s = [m * .55, 7.1, .1], e = [m * 1.45, 5.75, .55], wr = [m * (.75 + op * .75), 6.75, 1.05]; A.arm(B, s, e, wr, .19, { m: .8 }); A.hand(B, new Frame(wr, V.norm([0, .5, .85]), V.norm([-m * .55, .75, .1]), V.norm([m * .5, .3, .8])), 1.5, { curl: [42, 38, 40, 46], spread: 11, thin: .75, len: 1.3 }); }
  // 물에 끌리는 자락
  { const R = []; for (let i = 0; i < 26; i++) { const x = (i / 25 - .5) * 2.1, j = Math.sin(i * 5.1); R.push([[x * .55, 1.3, -.75], [x * .8, .5, -1.1], [x * 1.05 + j * .1, .14, -1.8], [x * 1.25 + j * .25, .06, -2.7 - Math.abs(j) * .7]]); } A.hair(B, R, { r: [.06, .06, .045, .008] }); }
  return B;
} };
