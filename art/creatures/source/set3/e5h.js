// 시안3 5장 인간형 — 겹사람: 가슴과 배가 쌍여닫이문처럼 열리면 안에 같은 사람이 서 있고, 그 사람의 가슴도 열려 또 안에 사람이 있다. 다가올수록 한 겹씩 더 열린다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'e5h', name: '겹사람', kind: '인간형 · 5장 심층 미로', H: 11.2, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .4 : Math.sin(w * Math.PI * 2), op = p.open ?? 1;
  const I = (o) => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]);
  // 한 사람: c = 골반 중심, s = 크기, 몸통 높이 3.6s
  const person = (c, s, o, depth) => { const f = v => [c[0] + v[0] * s, c[1] + v[1] * s, c[2] + v[2] * s];
    // 몸통 통(뒤판 + 옆벽), 앞은 파임
    B.group({ k: .16 * s, kg: .2 * s, amp: .008 * s, freq: 3 / s }); B.ell(I(f([0, 1.0, -.05])), [.82 * s, 1.25 * s, .62 * s]); B.ell(I(f([0, 2.55, -.08])), [1.04 * s, 1.35 * s, .68 * s]); for (const m of [-1, 1]) { B.ell(I(f([m * .95, 3.35, -.1])), [.42 * s, .32 * s, .36 * s]); B.tube([f([m * .15, 3.65, .2]), f([m * .6, 3.75, .22]), f([m * 1.15, 3.55, .0])], [.07 * s, .075 * s, .06 * s], { k: .05 * s }); }
    if (depth < 2) { for (const m of [-1, 1]) for (let i = 0; i < 8; i++) { const y = 3.2 - i * .27; B.tube([f([m * (.2 + i * .01), y + .1, .56 - i * .01]), f([m * .62, y + .04, .46]), f([m * (.95 - Math.max(0, i - 4) * .05), y - .12, .05]), f([m * .7, y - .05, -.45])], [.03 * s, .05 * s, .055 * s, .03 * s], { k: .06 * s }); } for (const m of [-1, 1]) { B.ell(I(f([m * .55, 3.72, .18])), [.3 * s, .1 * s, .16 * s], { op: 1, k: .08 * s }); B.groove(f([m * .5, 3.3, .6]), V.norm([m * .5, 1, 0]), .025 * s, .05 * s, .5 * s, { wob: .1 }); } for (let i = 0; i < 5; i++) B.groove(f([0, .3 + i * .16, .5]), V.norm([.1 * Math.sin(i * 3), 1, .2]), .02 * s, .05 * s, .8 * s, { wob: .1, bow: .3 }); }
    const hole = o > .05; if (hole) { B.ell(I(f([0, 1.95, .55])), [.86 * s * Math.min(1, o + .2), 1.75 * s, .85 * s], { op: 1, k: .07 * s }); B.group({ mat: 2, k: .02 * s, kg: .01 }); B.ell(I(f([0, 1.95, -.22])), [.74 * s, 1.5 * s, .22 * s]);
      // 안쪽 갈비 선
      B.group({ k: .02 * s, kg: .02 * s }); for (const m of [-1, 1]) for (let i = 0; i < 6; i++) { const y = 3.0 - i * .36; B.tube([f([m * .1, y + .1, -.1]), f([m * .5, y + .02, .02]), f([m * .78, y - .1, .3])], [.035 * s, .045 * s, .03 * s]); } B.group({ k: .03 * s, kg: .02 }); for (let i = 0; i < 10; i++) B.ell(I(f([0, .7 + i * .27, -.02])), [.1 * s, .1 * s, .09 * s]);
      // 문짝 둘
      for (const m of [-1, 1]) { const H = I(f([m * .88, 1.95, .42])).rot(0, m * (20 + 92 * o), 0), hp = v => H.p(V.mul(v, s)); B.group({ k: .1 * s, kg: .06 * s, amp: .006 * s, freq: 4 / s }); for (let i = 0; i < 9; i++) { const y = 1.45 - i * .36, ww = .8 * Math.sqrt(Math.max(.1, 1 - (y / 1.75) ** 2)); B.box(H.at([-m * ww * .5 * s, y * s, .0]), [ww * .5 * s, .22 * s, .05 * s], .05 * s); }
        // 안쪽 면: 갈비·젖은 근막, 겉면: 젖꼭지·근육
        B.group({ k: .03 * s, kg: .04 * s }); for (let i = 0; i < 7; i++) { const y = 1.15 - i * .33; B.tube([hp([0, y + .05, -.06]), hp([-m * .35, y, -.11]), hp([-m * .72 * Math.sqrt(Math.max(.1, 1 - (y / 1.75) ** 2)), y - .09, -.05])], [.05 * s, .055 * s, .02 * s]); } for (let i = 0; i < 5; i++) { const y = 1.0 - i * .4; A.veins(B, [hp([0, y, .06]), hp([-m * .25, y - .1, .08]), hp([-m * .5, y - .03, .06])], .016 * s); } B.group({ k: .03 * s, kg: .05 * s }); B.tube([hp([-m * .2, .75, .05]), hp([-m * .42, .6, .12]), hp([-m * .65, .78, .05])], [.06 * s, .12 * s, .04 * s]);
        // 찢어진 이음새 이빨
        B.group({ k: .02 * s, kg: .02 * s }); for (let i = 0; i < 9; i++) { const y = 1.35 - i * .34, ww = .8 * Math.sqrt(Math.max(.1, 1 - (y / 1.75) ** 2)); B.cone(hp([-m * ww * .95, y, 0]), hp([-m * (ww + .2), y - .05, -.06]), .05 * s, .008 * s); } } } else { B.group({ k: .03 * s, kg: .05 * s }); A.ribs && 0; B.groove(f([0, 1.95, .62]), [1, 0, 0], .02 * s, .06 * s, 1.6 * s, { wob: .2, wf: 5 }); }
    // 목과 얼굴(온전함)
    A.neck(B, f([0, 3.6, -.1]), f([0, 4.15, .0]), .27 * s, { kg: .15 * s }); A.face(B, I(f([0, 4.72, .12])).rot(8, (p.headYaw || 0) * (depth ? .4 : 1), [6, -14, 10, 0][depth]), 1.32 * s, { jaw: [p.jaw ?? 46, 8, 34, 0][depth], eyes: 'real', gaunt: 1.15, teeth: 10, w: 1, iris: .013, kg: .1 * s, rid: depth ? 0 : undefined, vein: depth < 1 }); };
  person([0, 4.1, 0], 1.25, op, 0);
  if (op > .15) person([0, 4.55, .62], .62, Math.max(0, op * 1.1 - .1), 1);
  if (op > .45) person([0, 4.82, .98], .29, Math.max(0, op - .25) * 1.1, 2);
  if (op > .45) { const c = [0, 5.35, 1.16]; B.group({ mat: 1, k: .03 }); B.ell(I(c), [.07, .1, .06]); B.tube([c, [.03, 5.15, 1.2], [0, 4.98, 1.22]], [.045, .03, .012]); }
  // 작은 사람들의 팔: 제 문짝과 바깥 문짝을 밀어 엶
  for (const m of [-1, 1]) { if (op < .15) continue; const a = [m * .68, 6.72, .6], b = [m * 1.1, 6.15, 1.15], c = [m * 1.25, 6.75, 1.5]; A.arm(B, a, b, c, .14, { m: .85 }); A.hand(B, new Frame(c, V.norm([0, -.2, 1]), V.norm([m * .25, .96, .1]), V.norm([-m, .2, 0])), .78, { curl: [12, 18, 16, 22], spread: 14, thin: .85 }); if (op < .45) continue; const a2 = [m * .32, 5.82, .98], b2 = [m * .46, 5.5, 1.25], c2 = [m * .36, 5.25, 1.5]; A.arm(B, a2, b2, c2, .065, { m: .85 }); A.hand(B, new Frame(c2, V.norm([0, .3, 1]), V.norm([-m * .3, -.9, .25]), V.norm([m, 0, .2])), .4, { curl: 22, spread: 12, thin: .85, vein: 0 }); }
  // 바깥 사람의 다리·골반·긴 팔
  A.pelvis(B, I([0, 4.2, 0]), { w: .85, d: .5 }); for (const m of [-1, 1]) { const st = m * S, h = [m * .62, 4.05, 0], k = [m * .72, 2.25, .25 + st * .5], an = [m * .66, .36 + Math.max(0, -st) * .18, -.15 + st * .9]; A.leg(B, h, k, an, .42, { m: .95, front: [m * .15, 0, 1] }); A.foot(B, new Frame(an, [1, 0, 0], [0, 1, 0], V.norm([m * .25, 0, 1])), 1.3, {}); const s = [m * 1.42, 8.3, -.12], e = [m * 2.25, 6.2, -.15 - m * S * .2], wr = [m * 2.1, 4.1, .5 - m * S * .4]; A.arm(B, s, e, wr, .3, { m: .95 }); A.hand(B, new Frame(wr, V.norm([0, 0, 1]), V.norm([0, -1, .1]), V.norm([m, 0, 0])), 1.6, { curl: [14, 20, 18, 26], spread: 10, thin: .88, len: 1.2 }); }
  return B;
} };
