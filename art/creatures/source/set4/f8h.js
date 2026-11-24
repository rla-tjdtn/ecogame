// 시안4 8장 인간형 — 토끼 선생님: 앞치마를 두른 유치원 선생님이 너무 큰 낡은 토끼 탈을 쓰고 있다. 탈은 목에 꿰매져 벗을 수 없고,
// 실로 꿰맨 웃는 입 틈으로 진짜 사람 눈이 내다본다. 손에는 빈 손잡이만 줄줄이 달린 산책 줄을 끌고 다닌다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'f8h', name: '토끼 선생님', kind: '인간형 · 8장 폐유치원', H: 10.6, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .25 : Math.sin(w * Math.PI * 2), I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]), L = V.lerp;
  const sew = (pts, n, wd, up, o = {}) => { B.group({ k: .006, kg: .01, mat: o.mat ?? 0 }); const N = pts.length - 1; for (let i = 0; i < n; i++) { const u = (i + .5) / n * N, j = Math.min(N - 1, Math.floor(u)), c = L(pts[j], pts[j + 1], u - j), d = V.norm(V.sub(pts[j + 1], pts[j])), uu = typeof up === 'function' ? up(c) : up, sd = V.norm(V.cross(d, uu)), t = wd * (.8 + .4 * Math.abs(Math.sin(i * 2.9))); if (o.x) { for (const q of [-1, 1]) B.tube([V.add(c, V.add(V.mul(sd, -t), V.mul(d, -q * t * .7))), V.add(c, V.mul(uu, .03)), V.add(c, V.add(V.mul(sd, t), V.mul(d, q * t * .7)))], o.r ?? .018, { per: 2 }); } else B.tube([V.add(c, V.mul(sd, -t)), V.add(c, V.mul(uu, .03)), V.add(c, V.mul(sd, t))], o.r ?? .014, { per: 2 }); } };
  // ---- 다리 + 실내화 (긴 치마 아래로 종아리만)
  for (const m of [-1, 1]) { const st = m * S, h = [m * .36, 4.2, 0], k = [m * .38, 2.35, .18 + st * .45], an = [m * .36, .4 + Math.max(0, -st) * .2, -.1 + st * .8]; A.leg(B, h, k, an, .3, { m: .85, front: [m * .1, 0, 1] }); const fz = V.norm([m * .15, 0, 1]), FF = new Frame(an, V.norm(V.cross([0, 1, 0], fz)), [0, 1, 0], fz); A.foot(B, FF, 1.05, {}); B.group({ k: .06, kg: .04, amp: .004, freq: 6 }); B.ell(FF.at([0, -.2, .28]), [.22, .16, .38]); B.box(FF.at([0, -.34, .15]), [.21, .04, .5], .04); B.ell(FF.at([0, -.06, .2]), [.17, .1, .22], { op: 1, k: .03 }); }
  // ---- 긴 치마(종아리 중간까지) + 세로 주름
  { const top = 5.0, bot = 1.55; B.group({ k: .1, kg: .08, amp: .004, freq: 4 }); B.cone([0, top, 0], [0, bot, .05 + S * .1], .55, 1.0, { k: .05 }); B.box(I([0, bot - 1.2, 0]), [2, 1.2, 2], .01, { op: 1, k: .04 });
    for (let i = 0; i < 14; i++) { const a = i / 14 * 6.283 + .2, r0 = .56, r1 = 1.02 + .03 * Math.sin(i * 2.7); B.tube([[Math.sin(a) * r0, top - .2, Math.cos(a) * r0 * .9], [Math.sin(a + .03 * S) * (r0 + r1) * .5, (top + bot) / 2, Math.cos(a) * (r0 + r1) * .45 + .02], [Math.sin(a + .06 * S) * r1, bot + .02, Math.cos(a) * r1 * .9 + .05 + S * .1]], [.03, .07, .1], { k: .12 }); }
    for (let i = 0; i < 14; i++) { const a = (i + .5) / 14 * 6.283 + .2; B.groove([Math.sin(a) * .95, 2.2, Math.cos(a) * .86], [Math.cos(a), 0, -Math.sin(a)], .016, .04, 1.4, { wob: .1 }); } }
  // ---- 몸통: 니트 셔츠
  const T = I([0, 6.0, 0]);
  B.group({ k: .2, kg: .2, amp: .003, freq: 6 }); B.ell(T.at([0, -.75, 0]), [.6, .55, .38]); B.ell(T.at([0, .2, -.02]), [.72, .72, .42]); for (const m of [-1, 1]) { B.ell(T.at([m * .62, .7, -.04]), [.3, .24, .3]); B.ell(T.at([m * .24, .1, .26]), [.25, .25, .2], { k: .18 }); }
  for (const m of [-1, 1]) for (let i = 0; i < 3; i++) B.groove([m * .55, 5.7 + i * .3, .15], V.norm([m * .4, 1, 0]), .014, .025, .4, { wob: .15, bow: .4 });
  // 앞치마: 가슴받이 + 치마폭(앞으로 둥글게) + 큰 주머니 + 어깨끈 + 허리끈 매듭(뒤)
  { const ap = (y, x) => { const z = y > 5 ? .4 + .06 * Math.cos(x * 2) - (y - 5.9) * (y - 5.9) * .05 : .62 + (5 - y) * .14 - x * x * .25; return [x, y, z]; };
    B.group({ k: .16, kg: .05, amp: .003, freq: 5 }); for (let i = 0; i < 7; i++) { const u = i / 6 * 2 - 1, col = []; for (let j = 0; j <= 8; j++) { const y = 6.55 - j * .52, hw = y > 5.05 ? .42 : .6 + (5.05 - y) * .1; col.push(V.add(ap(y, u * hw), [0, 0, -.06 + .03 * Math.cos(i * 2.3 + j)])); } B.tube(col, [.1, .1, .1, .09, .1, .11, .12, .12, .12], { per: 3 }); }
    for (let i = 0; i < 5; i++) B.groove(ap(3.4 - (i % 2) * .4, -.5 + i * .25), [1, 0, .1], .015, .03, 1.2, { wob: .12 });
    B.group({ k: .03, kg: .04 }); B.box(new Frame(ap(4.25, 0), [1, 0, 0], [0, 1, 0], V.norm([0, -.15, 1])), [.5, .3, .04], .04); B.groove(V.add(ap(4.25, 0), [0, .3, .05]), [0, 1, 0], .015, .03, .6, { wob: 0 }); B.groove(V.add(ap(4.2, 0), [0, 0, .05]), [1, 0, 0], .012, .02, .35, { wob: 0 });
    // 주머니에 꽂힌 크레파스·이름표
    B.group({ k: .01, kg: .02 }); for (let i = 0; i < 4; i++) B.cone(V.add(ap(4.4, -.3 + i * .09), [0, 0, .02]), V.add(ap(4.4, -.3 + i * .09), [Math.sin(i) * .05, .38 + .08 * Math.sin(i * 3), .02]), .035, .03); B.box(new Frame(V.add(ap(4.6, .28), [0, 0, .02]), V.norm([1, -.3, 0]), V.norm([.3, 1, 0]), [0, 0, 1]), [.12, .17, .012], .01);
    // 꽃 이름표
    B.group({ k: .01, kg: .02 }); const fc = V.add(ap(6.3, -.25), [0, 0, .04]); B.ball(fc, .07); for (let i = 0; i < 6; i++) { const a = i / 6 * 6.283; B.ell(new Frame(V.add(fc, [Math.cos(a) * .1, Math.sin(a) * .1, -.01]), [Math.cos(a), Math.sin(a), 0], [-Math.sin(a), Math.cos(a), 0], [0, 0, 1]), [.07, .045, .02]); }
    // 어깨끈(앞→어깨→등에서 엇갈림), 허리끈 매듭
    for (const m of [-1, 1]) { B.group({ k: .02, kg: .03 }); const pts = [ap(6.55, m * .4), [m * .5, 6.95, .25], [m * .52, 7.0, -.2], [m * .1, 6.3, -.45], [-m * .45, 5.4, -.4]]; B.tube(pts, .04, { per: 3 }); B.tube([[m * .62, 5.1, .1], [m * .5, 5.1, -.35], [m * .1, 5.08, -.47]], .05); }
    B.group({ k: .02, kg: .03 }); for (const m of [-1, 1]) { B.ell(new Frame([m * .15, 5.1, -.52], V.norm([m, .3, 0]), V.norm([-.3 * m, 1, 0]), [0, 0, 1]), [.16, .08, .04]); B.tube([[m * .04, 5.05, -.5], [m * .14, 4.6, -.56], [m * .2, 4.1, -.58]], [.045, .04, .03]); } B.ball([0, 5.1, -.5], .06);
    // 앞치마의 작은 큰 손자국 (포인트) — 아이 키 높이에서 움켜쥔 자국
    { const hc = V.add(ap(3.55, .3), [0, 0, .035]), n = V.norm([.15, 0, 1]), xa = V.norm(V.cross([0, 1, 0], n)), HF2 = new Frame(hc, xa, V.norm([.25, 1, 0]), n); B.group({ mat: 1, k: .01, kg: .015 }); B.ell(HF2, [.1, .11, .015]); for (let i = 0; i < 4; i++) { const x = -.06 + i * .04; B.tube([HF2.p([x, .08, 0]), HF2.p([x * 1.3, .17 + .02 * Math.sin(i * 2), 0]), HF2.p([x * 1.5, .23 - Math.abs(i - 1.5) * .02, 0])], [.018, .016, .014], { per: 2 }); } B.tube([HF2.p([.09, .0, 0]), HF2.p([.16, .07, 0])], [.018, .015], { per: 2 }); B.tube([HF2.p([.0, -.08, 0]), HF2.p([-.05, -.3, 0]), HF2.p([-.03, -.45, 0])], [.02, .012, .006], { per: 2 }); } }
  // ---- 팔: 소매를 팔꿈치까지 걷어 올림. 맨 아래팔은 가늘고 길다
  const arms = [];
  for (const m of [-1, 1]) {
    const s = [m * .82, 6.7, -.04], e = m < 0 ? [-1.15, 5.15, .25 - S * .15] : [1.1, 5.25, .1 + S * .15], wr = m < 0 ? [-1.25, 3.7, .75 - S * .3] : [1.0, 3.75, .55 + S * .3];
    A.arm(B, s, e, wr, .19, { m: .8 });
    B.group({ k: .08, kg: .07, amp: .004, freq: 6 }); B.tube([V.add(s, [m * .02, .06, 0]), L(s, e, .5), L(s, e, .92)], [.29, .26, .24]); B.ell(Frame.along(L(s, e, .97), V.sub(e, s)), [.3, .12, .3]); for (let i = 0; i < 2; i++) B.ell(Frame.along(L(s, e, .9 + i * .07), V.sub(e, s)).rot(8 * (i ? 1 : -1), 0, 10 * m), [.3 - i * .02, .07, .29], { k: .05 }); for (let i = 0; i < 4; i++) B.ell(Frame.along(V.add(L(s, e, .45 + i * .1), [0, 0, .14]), V.sub(e, s)).rot(0, 0, 30 * (i % 2 ? 1 : -1)), [.12, .05, .08], { k: .08 });
    for (let i = 0; i < 3; i++) B.groove(L(s, e, .3 + i * .2), V.norm(V.add(V.sub(e, s), [0, 0, .5 * (i % 2 ? 1 : -1)])), .014, .025, .35, { bow: .5, wob: .15 });
    arms.push({ m, s, e, wr });
  }
  // 오른손(−x): 산책 줄을 쥠 / 왼손(+x): 손가락을 벌려 내려뜨림
  A.hand(B, new Frame([-1.25, 3.7, .75 - S * .3], [0, 0, 1], V.norm([-.05, -1, .1]), [-1, 0, 0]), 1.3, { curl: [62, 70, 72, 76], spread: 4, thin: .8, len: 1.2 });
  A.hand(B, new Frame([1.0, 3.75, .55 + S * .3], [0, 0, 1], V.norm([.1, -1, .2]), [1, 0, 0]), 1.3, { curl: [12, 18, 15, 24], spread: 12, thin: .78, len: 1.3 });
  // ---- 산책 줄: 주먹에서 바닥으로 늘어져 뒤로 끌림, 빈 고리 손잡이가 일정 간격으로
  { const g0 = [-1.32, 3.35, .95 - S * .3], pts = [g0, [-1.45, 2.4, 1.05], [-1.55, 1.2, .8], [-1.6, .3, .2], [-1.62, .07, -.6], [-1.5, .07, -1.8], [-1.7, .07, -3.0], [-1.55, .07, -4.2], [-1.75, .07, -5.4]];
    B.group({ k: .02, kg: .03 }); B.tube(pts, .07, { per: 6 }); A.rings(B, pts, 40, .008, .015, .1, { tilt: .5, bow: .1 });
    const N = pts.length - 1, at = t => { const u = t * N, j = Math.min(N - 1, Math.floor(u)); return [L(pts[j], pts[j + 1], u - j), V.norm(V.sub(pts[j + 1], pts[j]))]; };
    for (let i = 0; i < 6; i++) { const t = .28 + i * .13, [c, d] = at(t), side = i % 2 ? 1 : -1, n = V.norm(V.cross(d, [0, 1, 0])), lay = c[1] < .3; const F = lay ? new Frame(c, d, V.mul(n, side), [0, 1, 0]).rot(0, 0, 0) : new Frame(c, d, V.norm(V.add(V.mul(n, side), [0, -.6, 0])), V.norm(V.cross(d, V.add(V.mul(n, side), [0, -.6, 0])))); const ring = []; for (let k = 0; k <= 14; k++) { const a = k / 14 * 6.283; ring.push(F.p([Math.sin(a) * .26, .32 + Math.cos(a) * .3 - .02, lay ? .05 : 0])); } B.group({ k: .015, kg: .03 }); B.tube(ring, .045, { per: 1 }); B.tube([c, F.p([0, .05, 0])], .055); } }
  // ---- 목: 사람의 가는 목. 탈 아래 천이 목살에 굵은 실로 꿰매져 있다
  const HF = I([.08, 8.55, .3]).rot(p.nod ?? 12, p.headYaw ?? 0, p.tilt ?? -26), R = 1.2, h = v => HF.p(v);
  A.neck(B, [0, 6.85, -.02], h([0, -.95, -.15]), .24, {});
  B.group({ k: .06, kg: .1, amp: .02, freq: 7 }); { const c = h([0, -1.0, -.1]), pts = []; for (let i = 0; i <= 20; i++) { const a = i / 20 * 6.283; pts.push(V.add(c, HF.d([Math.cos(a) * .42, .1 * Math.sin(a * 3) - .05, Math.sin(a) * .38]))); } B.tube(pts, .12, { per: 1 }); }
  { const c = h([0, -1.1, -.1]), pts = []; for (let i = 0; i <= 16; i++) { const a = i / 16 * 6.283; pts.push(V.add(c, HF.d([Math.cos(a) * .3, -.05 * Math.sin(a * 2), Math.sin(a) * .28]))); } sew(pts, 16, .1, q => V.norm(V.sub(q, c)), { r: .022 }); }
  // ---- 토끼 탈: 낡아 털이 뭉친 큰 머리, 주둥이, 코
  B.group({ k: .2, kg: .12, amp: .014, freq: 6 }); B.ell(HF.at([0, 0, -.05]), [R * .98, R * .92, R * .9]); B.ell(HF.at([0, -.4, .55]), [.62, .44, .5]); for (const m of [-1, 1]) B.ell(HF.at([m * .3, -.3, .82]), [.3, .24, .26]); B.ell(HF.at([0, .45, .1]), [.8, .5, .7]);
  // 입: 볼 아래로 크게 찢어 꿰맨 웃음. 틈 안은 어둡고 사람 얼굴이 있다
  const mouth = t => h([t * .78, -.5 + .26 * t * t * t * t + .08 * t * t, 1.04 - t * t * .55]);
  for (let i = 0; i <= 16; i++) { const t = i / 16 * 2 - 1; B.ball(mouth(t), .15 - .07 * t * t, { op: 1, k: .03 }); }
  B.ell(HF.at([0, -.5, 1.0]), [.4, .14, .32], { op: 1, k: .04 });
  for (const [x, y, z, rr] of [[.05, -.98, .62, .3], [-.2, -.92, .72, .2], [.25, -.95, .58, .18], [.0, -.84, .82, .15]]) B.ell(HF.at([x, y, z]), [rr * 1.3, rr, rr * 1.2], { op: 1, k: .02 }); // 목 쪽 솔기가 터짐
  B.group({ k: .03, kg: .06, amp: .03, freq: 13 }); for (let i = 0; i < 9; i++) { const a = i / 8 * 3.3 - 1.65; B.ball(h([Math.sin(a) * .42, -.88 - .08 * Math.cos(a * 3), .55 + Math.cos(a) * .25]), .06 + .03 * Math.abs(Math.sin(i * 2.7))); } // 터진 자리 솜
  B.group({ k: .006, kg: .01 }); for (let i = 0; i < 5; i++) { const x = -.3 + i * .15, top = h([x, -.82, .78 - Math.abs(x) * .3]); B.tube([top, V.add(top, [.02 * Math.sin(i * 3), -.25 - .15 * Math.abs(Math.sin(i * 1.7)), .04]), V.add(top, [.05 * Math.sin(i * 5), -.45 - .3 * Math.abs(Math.sin(i * 1.7)), .02])], [.014, .012, .006], { per: 3 }); } // 끊어진 실밥
  for (let i = 0; i < 6; i++) B.groove(h([(i - 2.5) * .3, .3 + Math.sin(i * 2.1) * .3, .9]), HF.d([Math.sin(i * 3), 1, .2]), .02, .05, .4, { wob: .5, wf: 4 }); // 뭉친 털
  for (let i = 0; i < 5; i++) { const u = i * 2.39 + .7, v = .2 + .5 * Math.abs(Math.sin(i * 1.9)); B.ell(new Frame(h([Math.sin(u) * Math.cos(v) * 1.12, Math.sin(v) * 1.08, Math.cos(u) * Math.cos(v) * 1.05 - .05]), HF.x, HF.y, HF.z).rot(i * 30, i * 50, 0), [.22, .05, .16], { op: 1, k: .05 }); } // 털 빠진 자리
  B.group({ k: .05, kg: .1, amp: .035, freq: 9 }); for (let i = 0; i < 26; i++) { const u = i * 2.39996, v = -.5 + 1.4 * ((i * .618) % 1); if (Math.cos(u) > .55 && v < .5 && v > -.6) continue; B.ell(new Frame(h([Math.sin(u) * Math.cos(v) * 1.1, Math.sin(v) * 1.04, Math.cos(u) * Math.cos(v) * 1.02 - .05]), HF.x, HF.y, HF.z).rot(i * 23, u * 57, i * 41), [.17 + .06 * Math.sin(i), .1, .13], { k: .06 }); } // 뭉친 털 덩어리
  sew([h([0, 1.08, .3]), h([0, .85, .8]), h([0, .4, 1.1]), h([0, -.05, 1.18])], 8, .05, HF.z, { r: .012 }); // 가운데 솔기
  B.group({ mat: 2, k: .03 }); B.ell(HF.at([0, -.48, .35]), [.6, .2, .25]);
  // 사람 얼굴: 탈 안에서 입 틈에 눈을 맞춤 (눈만 보인다)
  A.face(B, HF.at([0, -.48, .64]).rot(-4, 0, 0), .95, { eyes: 'real', jaw: 0, iris: .02, eyeSize: 1.35, open: 1.3, gaze: [.0, .012], age: .35, gaunt: .8, ears: false, vein: false, kg: .02, rid: 0 });
  // 꿰맨 실: 입 틈을 가로지르는 굵은 X 바늘땀, 두 땀은 끊어져 늘어짐
  B.group({ k: .006, kg: .01 }); for (const [i, t] of [[0, -.85], [1, -.6], [2, -.36], [3, 0], [4, .36], [5, .6], [6, .85]]) { const c = mouth(t), up = HF.d([0, 1, -.1]); if (i === 2 || i === 5) { B.tube([V.add(c, V.mul(up, .14)), V.add(c, V.add(V.mul(up, .1), HF.d([.03, 0, .06]))), V.add(c, V.add(V.mul(up, -.2), HF.d([.04, 0, .1])))], .016, { per: 2 }); continue; } for (const q of [-1, 1]) B.tube([V.add(c, V.add(V.mul(up, .15), HF.d([-q * .07, 0, -.02]))), V.add(c, HF.d([0, 0, .07])), V.add(c, V.add(V.mul(up, -.15), HF.d([q * .07, 0, -.02])))], .015, { per: 2 }); }
  // 코: 꿰맨 세모 천 조각
  B.group({ k: .03, kg: .04 }); B.ell(new Frame(h([0, -.22, 1.04]), HF.x, HF.y, HF.z).rot(-25, 0, 0), [.13, .09, .07]); sew([h([-.12, -.18, 1.05]), h([0, -.3, 1.08]), h([.12, -.18, 1.05])], 5, .03, HF.z, { r: .01 });
  // 단추 눈: 왼쪽은 박혀 있고, 오른쪽은 실 한 가닥에 매달려 뺨까지 늘어짐(빈 자리엔 솜)
  const button = (c, n, r) => { const z = V.norm(n), x = V.norm(V.cross([0, 1, 0], z)), F = new Frame(c, x, V.cross(z, x), z); B.group({ mat: 4, k: .02, kg: .02 }); B.ell(F, [r, r, r * .3]); B.ell(F.at([0, 0, r * .3]), [r * .72, r * .72, r * .14], { op: 1, k: .03 }); for (const [a, b2] of [[.25, .25], [-.25, .25], [.25, -.25], [-.25, -.25]]) B.ell(F.at([a * r, b2 * r, r * .2]), [r * .1, r * .1, r * .5], { op: 1, k: .005 }); B.group({ k: .004, kg: .01 }); B.tube([F.p([.25 * r, .25 * r, r * .2]), F.p([-.25 * r, -.25 * r, r * .2])], .014); B.tube([F.p([-.25 * r, .25 * r, r * .2]), F.p([.25 * r, -.25 * r, r * .2])], .014); return F; };
  button(h([.43, .1, .98]), HF.d([.35, .05, 1]), .24);
  { const sock = h([-.43, .1, .98]); B.group({ k: .03, kg: .05, amp: .03, freq: 12 }); for (let i = 0; i < 7; i++) B.ball(V.add(sock, HF.d([Math.sin(i * 2.4) * .12, Math.cos(i * 1.9) * .1, .04 + .04 * Math.sin(i)])), .07 + .02 * Math.sin(i * 3));
    const hang = V.add(h([-.62, -.55, 1.12]), [0, -1.05 - S * .05, .2]); B.group({ k: .004, kg: .01 }); B.tube([V.add(sock, HF.d([0, 0, .1])), V.add(L(sock, hang, .5), HF.d([-.05, 0, .35])), hang], .016, { per: 4 }); button(V.add(hang, [0, -.22, .04]), [-.2, .1, 1], .23); }
  // 귀: 왼쪽은 서 있지만 끝이 꺾였고, 오른쪽은 가운데가 찢겨 어깨까지 늘어짐
  const ear = (pts, wd, m) => { B.group({ k: .1, kg: .14, amp: .01, freq: 6 }); const N = pts.length - 1; for (let i = 0; i < N * 3; i++) { const t = i / (N * 3), u = t * N, j = Math.floor(u), c = L(pts[j], pts[j + 1], u - j), d = V.norm(V.sub(pts[j + 1], pts[j])), ww = wd * (1 - Math.pow(t * 2 - .8, 2) * .35) * (t > .85 ? (1 - t) * 6 : 1); B.ell(new Frame(c, V.norm(V.cross(d, HF.z)), d, HF.z), [Math.max(.06, ww), .3, .09]); } B.group({ k: .03, kg: .04 }); for (let i = 1; i < N; i++) B.ell(new Frame(V.add(pts[i], HF.d([0, 0, .07])), V.norm(V.cross(V.norm(V.sub(pts[i + 1], pts[i - 1])), HF.z)), V.norm(V.sub(pts[i + 1], pts[i - 1])), HF.z), [wd * .45, .32, .05], { op: 1, k: .05 }); };
  ear([h([.4, .9, -.05]), h([.5, 1.7, -.1]), h([.6, 2.45, -.15]), h([.95, 2.75, .05]), h([1.3, 2.6, .25])], .34, 1);
  ear([h([-.4, .9, -.05]), h([-.75, 1.4, -.1]), h([-1.15, 1.35, -.1])], .34, -1);
  { const tear = h([-1.15, 1.35, -.1]), tip = V.add(tear, [-.35, -1.9 - S * .1, .2]); B.group({ k: .08, kg: .1, amp: .02, freq: 6 }); B.tube([tear, V.add(L(tear, tip, .4), [-.15, 0, 0]), tip], [.2, .22, .14]); for (let i = 0; i < 3; i++) B.ell(new Frame(L(tear, tip, .25 + i * .3), [1, 0, 0], V.norm(V.sub(tip, tear)), [0, 0, 1]), [.26 - i * .04, .35, .08]); B.group({ k: .02, kg: .04, amp: .025, freq: 14 }); for (let i = 0; i < 6; i++) B.ball(V.add(tear, [Math.sin(i * 2.1) * .14, -.08 + Math.cos(i * 1.7) * .1, Math.sin(i * 3.3) * .1]), .08); sew([V.add(tear, [.05, .15, .12]), V.add(tear, [-.15, -.15, .14]), V.add(L(tear, tip, .3), [-.15, 0, .14])], 5, .08, [0, 0, 1], { r: .014 }); }
  // 덧댄 헝겊 조각
  { const c = h([.62, .55, .72]), n = V.norm(V.sub(c, h([0, 0, 0]))), xa = V.norm(V.cross([0, 1, 0], n)), F = new Frame(c, xa, V.cross(n, xa), n).rot(0, 0, 14); B.group({ k: .02, kg: .03 }); B.box(F, [.22, .2, .025], .02); const q = [[-.22, -.2], [.22, -.2], [.22, .2], [-.22, .2], [-.22, -.2]].map(([a, b2]) => F.p([a, b2, .02])); sew(q, 14, .035, n, { r: .01 }); }
  // 굽은 등: 허리 위를 앞으로 숙이고 머리를 떨군다(허리 아래는 그대로)
  { const y0 = 5.1, st = p.stoop ?? 1, f = q => { const d = Math.min(1.9, Math.max(0, q[1] - y0)); return [q[0], q[1] - .07 * d * d * st, q[2] + .38 * d * st]; }; for (const g of B.groups) for (const q of g.prims) { if (q.t === 0) { const ny = q.a[1] > y0 || q.b[1] > y0; if (ny) { q.a = f(q.a); q.b = f(q.b); } } else if (q.a[1] > y0) q.a = f(q.a); } }
  return B;
} };
