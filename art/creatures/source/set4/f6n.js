// 시안4 6장 비인간형 — 젖은 투숙객: 욕실에서 기어 나온 투숙객. 젖은 가운을 등에 걸친 채 엉덩이를 높이 든 네발 자세로 기고, 한쪽 팔꿈치는 반대로 꺾였다. 바닥까지 늘어진 젖은 머리카락 틈으로 부릅뜬 눈 하나.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
const I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]);
module.exports = { id: 'f6n', name: '젖은 투숙객', kind: '비인간형 · 6장 호텔', H: 3.6, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .25 : Math.sin(w * Math.PI * 2), hump = p.hump ?? 1, lift = p.lift ?? 0;
  const L = V.lerp, jit = i => Math.sin(i * 12.9898) * .5 + Math.sin(i * 4.1) * .5;
  // 척추 선: 골반(높이 듦) → 허리(굽은 등) → 가슴 → 목밑(낮음)
  const sp = [[0, 2.85 + .2 * hump, -1.75], [0, 3.05 + .35 * hump, -.95], [0, 2.75 + .15 * hump, -.1], [0, 2.35 + lift * .4, .6]];
  const spAt = t => { const u = Math.min(.999, Math.max(0, t)) * 3, j = Math.floor(u); return L(sp[j], sp[j + 1], u - j); };
  // 몸: 가운 밑 몸통(살짝 보이는 갈비 옆구리)
  B.group({ k: .3, kg: .3, amp: .006, freq: 3 }); B.ell(new Frame(L(sp[0], sp[1], .4), [1, 0, 0], V.norm(V.sub(sp[1], sp[0])), [0, -1, 0]), [.6, .65, .42]); B.ell(new Frame(L(sp[2], sp[3], .2), [1, 0, 0], V.norm(V.sub(sp[3], sp[2])), [0, -1, 0]), [.72, .6, .42]); B.tube(sp, [.5, .4, .48, .36]);
  // 다리: 발끝으로 선 채 무릎을 벌림(발꿈치가 들림)
  for (const m of [-1, 1]) { const st = m * S, h = [m * .42, 2.75 + .2 * hump, -1.75], k = [m * 1.05, 1.65, -.95 + st * .35], an = [m * .78, .58 + Math.max(0, st) * .2, -2.35 + st * .4]; A.leg(B, h, k, an, .3, { m: .85, front: [m * .35, -.2, 1] }); A.foot(B, new Frame(an, [1, 0, 0], [0, 1, 0], V.norm([m * .15, 0, 1])).rot(52, 0, 0), 1.2, { toe: 1.1 }); }
  // 왼팔(+x): 앞으로 뻗어 바닥을 짚음
  { const st = S, s = [.68, 2.4, .55], e = [1.25, 1.55, 1.25 + st * .2], wr = [1.1, .3, 2.05 + st * .45]; A.arm(B, s, e, wr, .2, { m: .85 }); A.hand(B, new Frame(wr, [-1, 0, 0], V.norm([.15, -.08, 1]), [0, 1, 0]), 1.35, { curl: [12, 8, 16, 22], spread: 13, thin: .82, len: 1.25 }); }
  // 오른팔(−x): 팔꿈치가 반대로 꺾여 위·뒤로 솟음
  { const st = -S, s = [-.68, 2.4, .55], e = [-1.55, 2.6 + st * .15, .1], wr = [-1.3, .42, 1.45 + st * .4]; A.arm(B, s, e, wr, .2, { m: .85 }); B.group({ k: .03, kg: .06 }); B.ball(V.add(e, [-.05, .14, -.08]), .12); A.hand(B, new Frame(wr, [1, 0, 0], V.norm([-.35, 0, 1]), [0, 1, 0]), 1.35, { curl: [14, 22, 18, 26], spread: 15, thin: .82, len: 1.25 }); }
  // 목·머리: 어깨보다 낮게 늘어져 얼굴이 바닥을 향함
  const hc = [0, 1.42 - lift * .3, 1.42], HF = I(hc).rot(50 - lift * 25, p.headYaw || 0, p.tilt ?? -8), s = 1.25, hp = v => HF.p(V.mul(v, s));
  A.neck(B, sp[3], hp([0, -.15, -.32]), .19, { front: [0, -1, .2], adam: false, mid: [0, 2.0, 1.15] });
  A.face(B, HF, s, { jaw: p.jaw ?? 24, eyes: ['shut', 'real'], open: 1.25, iris: .02, gaze: [0, .012], gaunt: 1.0, age: .5, teeth: 10, w: .9, lips: .7, vein: false, ears: false });
  B.group({ mat: 1, k: .002 }); { const e = HF.at(V.mul([.128 * .9, -.02, .265], s)).rot(0, 6, 0); B.ball(e.p([0, .012 * s, .047 * s]), .022 * s); } // 눈동자(틈으로 보이는 하나)
  B.group({ mat: 2, k: .001 }); { const e = HF.at(V.mul([.128 * .9, -.02, .265], s)).rot(0, 6, 0); B.ball(e.p([0, .013 * s, .066 * s]), .008 * s); }
  // 젖은 머리카락: 정수리에서 머리를 덮고 이마·관자 선에서 떨어져 젖은 다발로 뭉쳐 바닥에 고임. 왼눈 앞만 갈라진 틈
  { const R = [], hc0 = [0, .1, -.05], onS = (v, r) => { const d = V.norm(V.sub(v, hc0)); return V.add(hc0, V.mul(d, r)); }; let n = 0; const gap = a => a > .12 && a < .62;
    const clump = c => { const a = (c / 8 * 2 - 1) * 1.75, H = hp(onS([Math.sin(a) * .36, .24 * Math.cos(a) - .04, .3 * Math.cos(a) + .04], .44)), jj = jit(c + 50); return V.add(H, [jj * .08 + Math.sin(a) * .1, -.42 - .1 * Math.abs(jj), .12 + .05 * jj]); };
    for (let k = 0; k < 3; k++) for (let i = 0; i < 26; i++) { const a = (i / 25 * 2 - 1) * 1.75 + .03 * k, jj = jit(n++); if (gap(a)) continue; const rr = .43 + k * .025, root = [Math.sin(a) * .12, .5, -.28 + k * .06], H = [Math.sin(a) * (.35 + k * .02), .24 * Math.cos(a) - .04, .3 * Math.cos(a) + .03 + k * .02], M = onS(V.lerp(root, H, .5), rr), H2 = onS(H, rr - .02);
      const wH = hp(H2), ci = Math.max(0, Math.min(8, Math.round((a / 1.75 + 1) / 2 * 8))), cl = clump(gap((ci / 8 * 2 - 1) * 1.75) ? (a < .37 ? ci - 1 : ci + 1) : ci), drop = V.lerp(V.add(wH, [0, -.3, .05]), cl, .75), fl = [cl[0] * 1.25 + jj * .14, .035, cl[2] + .35 + .2 * Math.abs(jj)], fl2 = V.add(fl, [cl[0] * .4 + jj * .25, -.005, .3 + .35 * Math.abs(jj)]);
      R.push([hp(root), hp(M), wH, drop, V.add(L(drop, fl, .55), [jj * .04, .05, 0]), fl, fl2]); }
    for (let i = 0; i < 14; i++) { const a = (i / 13 - .5) * 3.4, jj = jit(i + 100), root = [Math.sin(a) * .1, .45, -.38], side = onS([Math.sin(a) * .5, .05, -.25], .45), ws = hp(side); R.push([hp(root), hp(onS([Math.sin(a) * .35, .35, -.32], .45)), ws, V.add(ws, [Math.sin(a) * .15, -.55, .08 * jj]), [ws[0] * 1.35 + jj * .12, .03, ws[2] + .25], [ws[0] * 1.7 + jj * .15, .02, ws[2] + .5]]); }
    B.group({ k: .03, kg: .05 }); R.forEach((pts, i) => { const t = .03 + .012 * Math.abs(jit(i + 7)); B.tube(pts, [t * .8, t, t * 1.1, t * .9, t * .8, t * .6, .006], { per: 3 }); }); }
  // 바닥에 고인 물: 얕은 웅덩이와 퍼지는 고리
  B.group({ k: .05, kg: .02 }); B.ell(I([0, -.02, 1.6]), [1.7, .045, 1.5]); for (const r of [2.05]) { const pts = []; for (let i = 0; i <= 28; i++) { const a = i / 28 * 6.283; pts.push([Math.cos(a) * r * 1.05, .0, 1.6 + Math.sin(a) * r * .9]); } B.tube(pts, .012, { per: 1 }); }
  // 젖은 목욕 가운: 등에 들러붙은 판 + 양옆·뒤로 늘어진 주름(관을 나란히 녹여 만든 천)
  B.group({ k: .12, kg: .16, amp: .01, freq: 3 }); for (let i = 0; i <= 8; i++) { const t = i / 8, c = spAt(t); const q = Math.max(0, (t - .5) / .5); B.ell(new Frame(V.add(c, [-.32 * q, .12 - .04 * q, 0]), [1, 0, 0], [0, 1, 0], [0, 0, 1]), [.78 - .1 * Math.sin(t * 3) - .12 * q, .32, .42]); }
  for (let i = 0; i < 9; i++) B.groove(V.add(spAt(i / 8), [.25 * Math.sin(i * 2.7), .42, 0]), V.norm([.3 * Math.sin(i), .1, 1]), .015, .04, .55, { bow: .4 * Math.sin(i * 1.3), wob: .25 }); // 등 주름
  for (const m of [-1, 1]) { B.group({ k: .16, kg: .2, amp: .008, freq: 4 }); for (let i = 0; i <= 13; i++) { const t = i / 13; if (m > 0 && t > .6) continue; const c = spAt(t * .92 + .02), jj = jit(i * 3 + m), hem = .95 + .35 * Math.sin(t * 4 + m) + (t < .3 ? -.25 : 0), top = V.add(c, [m * .74, .1, 0]), bot = [m * (1.08 + .1 * jj + (t > .75 ? .15 : 0)), hem, c[2] + .1 * jj - (t < .2 ? .25 : 0)]; B.tube([top, L(top, bot, .45).map((q, k) => q + (k === 0 ? m * .12 : 0)), bot], [.12, .1 + .03 * jj, .09]); } }
  // 흘러내린 왼어깨: 젖은 가운 가장자리 접힘 + 드러난 어깨뼈·등뼈 돌기
  B.group({ k: .1, kg: .14, amp: .006 }); B.tube([V.add(sp[3], [-.15, .3, .05]), V.add(spAt(.75), [.25, .42, 0]), V.add(spAt(.58), [.62, .3, 0]), V.add(spAt(.5), [.85, .05, 0]), [1.1, 1.3, spAt(.5)[2] + .05]], [.13, .14, .13, .12, .1]);
  A.spine(B, [spAt(.62), spAt(.8), sp[3]], .1, { n: 6, back: [0, 1, 0], out: .1, k: .03 }); B.group({ k: .08, kg: .12 }); B.tube([V.add(spAt(.95), [.62, .2, -.12]), V.add(spAt(.88), [.3, .36, -.05]), V.add(spAt(.7), [.25, .3, .05]), V.add(spAt(.82), [.6, .22, .02])], [.08, .07, .05, .06]); for (let i = 0; i < 3; i++) B.groove(V.add(spAt(.66 + i * .06), [.4, .3, 0]), [0, .3, 1], .01, .02, .35, { bow: .4 });
  // 가운 뒷자락: 엉덩이에서 바닥으로 흘러 끌림
  B.group({ k: .16, kg: .2, amp: .008, freq: 4 }); for (let i = 0; i < 9; i++) { const u = i / 8 * 2 - 1, jj = jit(i + 40); B.tube([[u * .6, sp[0][1] + .15, sp[0][2] - .15], [u * .8, 1.9, -2.3 - .05 * jj], [u * .95 + .1 * jj, .6, -2.65], [u * 1.05 + .12 * jj, .09, -3.0 - .12 * Math.abs(jj)], [u * 1.1 + .15 * jj, .08, -3.2 - .12 * Math.abs(jj)]], [.13, .12, .11, .1, .09]); }
  // 넓은 소매: 위팔을 감싸고 젖은 천이 아래로 처져 늘어짐
  for (const [m, e] of [[1, [1.25, 1.55, 1.25]], [-1, [-1.55, 2.6, .1]]]) { const s0 = [m * .72, 2.42, .5], d = V.norm(V.sub(e, s0)); B.group({ k: .12, kg: .16, amp: .008, freq: 5 }); B.tube(m > 0 ? [L(s0, e, .5), L(s0, e, .7), L(s0, e, .85)] : [s0, L(s0, e, .5), L(s0, e, .8)], m > 0 ? [.36, .38, .32] : [.32, .3, .3]); for (let i = m > 0 ? 3 : 0; i < 6; i++) { const t = .15 + i * .13, c = L(s0, e, t), jj = jit(i * 5 + m), lo = Math.max(.75, c[1] - .75 - .25 * t - .15 * jj); B.tube([V.add(c, [0, -.15, 0]), [c[0] + m * .05 + .05 * jj, (c[1] + lo) / 2, c[2] + .05], [c[0] + m * .08 + .08 * jj, lo, c[2] + .08 * jj]], [.16, .12, .08]); } for (let i = 0; i < 4; i++) B.groove(L(s0, e, .2 + i * .17), V.norm(V.add(d, [Math.sin(i * 2) * .5, .2, Math.cos(i * 3) * .5])), .012, .035, .45, { bow: .5, wob: .2 }); }
  // 가슴 쪽 숄 깃 두 자락(앞에서 엇갈림)
  B.group({ k: .06, kg: .1 }); for (const m of [-1, 1]) B.tube([V.add(sp[3], [m * .32, .05, -.05]), V.add(sp[3], [m * .3, -.32, .1]), V.add(sp[2], [-m * .15, -.5, .2]), V.add(sp[2], [-m * .35, -.45, -.2])], [.1, .09, .08, .06]);
  // 숄 깃: 목 둘레 두툼한 깃
  B.group({ k: .1, kg: .14, amp: .006 }); { const pts = []; for (let i = 0; i <= 10; i++) { const a = -1.3 + i / 10 * 2.6 + Math.PI, c = V.add(sp[3], [Math.sin(a) * .55, .1 + .15 * Math.cos(a), Math.cos(a) * .3 - .1]); pts.push(c); } pts.push(V.add(sp[3], [.3, -.35, .35]), V.add(sp[3], [.05, -.55, .4])); B.tube(pts, .15, { per: 2 }); }
  // 풀린 허리끈: 옆구리에서 바닥까지 늘어져 끌림
  A.strap(B, [[-.85, 2.3, -.7], [-1.0, 1.6, -.55], [-1.05, .8, -.3], [-1.0, .06, .1], [-.75, .05, .7], [-.6, .05, 1.1]], .1, .03, q => V.norm([-1, q[1] > .2 ? 0 : 1, 0]).map((x, i) => i === 1 ? (q[1] > .2 ? .2 : 1) : x));
  B.group({ k: .02, kg: .02 }); for (let i = 0; i < 6; i++) B.tube([[-.6 - i * .02, .06, 1.1 + i * .02], [-.55 + .03 * i, .04, 1.25 + i * .03]], .015);
  return B;
} };
