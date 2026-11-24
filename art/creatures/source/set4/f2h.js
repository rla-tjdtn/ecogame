// 시안4 2장 인간형 — 야간조: 아무도 퇴근 기록을 본 적 없는 야간 근무자. 형광 조끼에 후드를 깊이 눌러써 얼굴은 그늘 속, 키와 팔이 사람보다 한 뼘씩 길다. 손에는 화물 갈고리.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
const I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]);
// 회전 틀 → 사원수([x,y,z,w]) 및 곱: 상체를 통째로 숙이기 위한 후처리용
const quat = (x, y, z) => { const m = [[x[0], y[0], z[0]], [x[1], y[1], z[1]], [x[2], y[2], z[2]]], t = m[0][0] + m[1][1] + m[2][2]; if (t > 0) { const s = Math.sqrt(t + 1) * 2; return [(m[2][1] - m[1][2]) / s, (m[0][2] - m[2][0]) / s, (m[1][0] - m[0][1]) / s, s / 4]; } if (m[0][0] > m[1][1] && m[0][0] > m[2][2]) { const s = Math.sqrt(1 + m[0][0] - m[1][1] - m[2][2]) * 2; return [s / 4, (m[0][1] + m[1][0]) / s, (m[0][2] + m[2][0]) / s, (m[2][1] - m[1][2]) / s]; } if (m[1][1] > m[2][2]) { const s = Math.sqrt(1 + m[1][1] - m[0][0] - m[2][2]) * 2; return [(m[0][1] + m[1][0]) / s, s / 4, (m[1][2] + m[2][1]) / s, (m[0][2] - m[2][0]) / s]; } const s = Math.sqrt(1 + m[2][2] - m[0][0] - m[1][1]) * 2; return [(m[0][2] + m[2][0]) / s, (m[1][2] + m[2][1]) / s, s / 4, (m[1][0] - m[0][1]) / s]; };
const qmul = (a, b) => [a[3] * b[0] + a[0] * b[3] + a[1] * b[2] - a[2] * b[1], a[3] * b[1] - a[0] * b[2] + a[1] * b[3] + a[2] * b[0], a[3] * b[2] + a[0] * b[1] - a[1] * b[0] + a[2] * b[3], a[3] * b[3] - a[0] * b[0] - a[1] * b[1] - a[2] * b[2]];
module.exports = { id: 'f2h', name: '야간조', kind: '인간형 · 2장 물류 창고', H: 10.6, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .3 : Math.sin(w * Math.PI * 2), lift = p.lift ?? 1, stoop = p.stoop ?? 24, PV = [0, 5.2, 0], HB = p.hipBack ?? -.45;
  const ring = (c, d, r, t, o = {}) => { const F = Frame.along(c, d, [0, 0, 1]); const pts = []; for (let i = 0; i <= 22; i++) { const a = i / 22 * 6.283; pts.push(F.p([Math.cos(a) * r * (o.fx ?? 1), (o.wob ?? .015) * Math.sin(i * 2.7), Math.sin(a) * r * (o.fz ?? 1)])); } B.group({ k: .02, kg: o.kg ?? .05, mat: o.mat ?? 0 }); B.tube(pts, t, { per: 1 }); };
  const cloth = (pts, rs, n, o = {}) => { B.group({ k: o.k ?? .1, kg: o.kg ?? .12, amp: .008, freq: 3 }); B.tube(pts, rs); const N = pts.length - 1; for (let i = 0; i < n; i++) { const t = (i + .5 + .3 * Math.sin(i * 5.1)) / n * N, j = Math.min(N - 1, Math.floor(t)), c = V.lerp(pts[j], pts[j + 1], t - j), d = V.norm(V.sub(pts[j + 1], pts[j])), r = rs[j] + (rs[j + 1] - rs[j]) * (t - j), sd = V.norm(V.cross(d, [0, 0, 1])); B.groove(V.add(c, V.mul(sd, r * .25 * Math.sin(i * 3.7))), V.norm(V.add(d, V.add(V.mul(sd, (.6 + .4 * Math.sin(i * 2.3)) * (i % 2 ? 1 : -1)), [0, 0, .3 * Math.cos(i * 3.1)]))), .013, .03 + .015 * Math.abs(Math.sin(i * 1.9)), r * 1.2, { bow: .8 * Math.sin(i * 2.9), wob: .2, wf: 2.5 }); } };
  // ── 다리: 길고 가는 작업 바지, 안전화
  for (const m of [-1, 1]) {
    const st = m * S, h = [m * .42, 5.0, -.05 + HB], k = [m * .48, 2.65, .3 + st * .55], an = [m * .44, .58 + Math.max(0, -st) * .25, -.2 + st * .85];
    cloth([h, V.lerp(h, k, .5), k, V.lerp(k, an, .6), V.add(an, [0, .15, 0])], [.4, .33, .29, .27, .3], 6);
    for (let i = 0; i < 4; i++) B.groove(V.add(k, [m * .05 * (i - 1.5), .1 - i * .1, -.26]), V.norm([.25 * (i - 1.5), 1, -.5]), .014, .04, .45, { bow: 1.4, wob: .2 }); for (let i = 0; i < 3; i++) B.groove(V.add(V.lerp(h, k, .12), [m * .05, -i * .12, .3]), V.norm([-m * .8, 1, .2]), .013, .035, .45, { bow: .9, wob: .2 }); for (let i = 0; i < 2; i++) B.groove(V.add(an, [0, .3 + i * .14, .05]), V.norm([.15 * m, 1, .1 * i]), .014, .035, .5, { bow: .3, wob: .25 }); // 무릎 뒤 구김·사타구니 당김·밑단 겹침
    B.group({ k: .06, kg: .1 }); B.ell(I(V.add(k, [0, 0, .2])), [.22, .25, .14]); B.box(I(V.lerp(h, k, .55)).rot(0, m * 70, 0), [.2, .26, .06], .05); B.box(I(V.add(V.lerp(h, k, .43), [m * .14, 0, 0])).rot(0, m * 70, 0), [.21, .05, .07], .03); // 건빵 주머니
    B.group({ k: .06, kg: .1, amp: .003 }); B.ell(I(V.add(an, [m * .02, -.28, .3])).rot(0, m * 5, 0), [.27, .24, .55]); B.tube([V.add(an, [0, .15, -.02]), V.add(an, [0, -.3, -.05])], [.3, .28]); B.box(I(V.add(an, [m * .02, -.5, .3])).rot(0, m * 5, 0), [.29, .05, .6], .04); B.ell(I(V.add(an, [m * .02, -.25, .7])).rot(0, m * 5, 0), [.24, .17, .2]);
    for (let i = 0; i < 4; i++) B.groove(V.add(an, [m * .02, -.18 + i * .07, .45]), [0, .2, 1], .01, .02, .4, { wob: 0 }); // 끈 구멍
    for (let i = 0; i < 5; i++) B.groove(V.add(an, [0, -.52, -.25 + i * .2]), [0, 0, 1], .02, .025, .35, { wob: 0 });
  }
  const g0 = B.groups.length; // ↓ 상체(몸통·조끼·목·후드): 엉덩이를 축으로 통째로 숙인다
  B.group({ k: .25, kg: .25, amp: .01, freq: 3 }); B.ell(I([0, 5.3, 0]), [.72, .48, .44]); B.ell(I([0, 6.3, .0]), [.68, .9, .44]); B.ell(I([0, 7.55, -.05]).rot(12, 0, 0), [.78, .8, .48]); for (const m of [-1, 1]) B.ell(I([m * .78, 8.05, -.05]), [.32, .28, .3]);
  for (let i = 0; i < 3; i++) B.groove([.0, 5.7 + i * .3, .42], V.norm([.5 * Math.sin(i * 3), 1, .2]), .013, .03, .7, { bow: .6, wob: .2 }); B.box(I([0, 5.85, .44]).rot(-8, 0, 0), [.42, .3, .05], .06); B.groove([0, 6.12, .48], [0, 1, 0], .012, .02, .5, { wob: .1 }); // 앞주머니
  // 조끼: 몸통보다 조금 큰 껍질, 앞 지퍼선, 아래 단
  const VS = I([0, 6.95, -.02]).rot(6, 0, 0), vr = [.83, 1.38, .54]; B.group({ k: .14, kg: .05, amp: .006, freq: 4 }); B.ell(VS, vr); B.ell(I([0, 6.0, .0]), [.76, .62, .5]); for (const m of [-1, 1]) B.ell(I([m * .95, 7.85, -.05]), [.36, .48, .44], { op: 1, k: .06 }); B.ell(I([0, 5.05, 0]), [1, .5, .8], { op: 1, k: .05 }); B.ell(I([0, 8.55, .05]), [.36, .4, .5], { op: 1, k: .08 });
  B.groove(VS.p([0, 0, .55]), [1, 0, 0], .012, .03, 1.6, { wob: .05 }); for (let i = 0; i < 3; i++) B.groove(VS.p([(i % 2 ? .45 : -.45), -.9 + i * .5, .45]), V.norm([i % 2 ? .9 : -.9, 1, .2]), .01, .02, .5, { bow: .5, wob: .2 });
  const vsurf = (x, y, sgn) => { const l = VS.o, u = (y - l[1]) / vr[1], a = vr[0] * Math.sqrt(Math.max(.02, 1 - u * u)), b = vr[2] * Math.sqrt(Math.max(.02, 1 - u * u)), q = Math.max(-.98, Math.min(.98, x / a)); return [x, y, l[2] + sgn * (b * Math.sqrt(1 - q * q) + .015) + (y - l[1]) * .1]; };
  const nrm = c => c[1] < 6.7 ? V.norm([c[0] / .64, 0, c[2] / .3]) : V.norm([c[0] / vr[0] ** 2, (c[1] - VS.o[1]) / vr[1] ** 2 * .3, (c[2] - VS.o[2]) / vr[2] ** 2]);
  // 반사띠: 가로 두 줄(몸통 둘레), 세로 두 줄(앞→어깨→뒤 X)
  for (const [y, ax, az] of [[5.88, .8, .55], [6.5, .8, .57]]) { const pts = []; for (let i = 0; i <= 28; i++) { const t = i / 28 * 6.283; pts.push([Math.cos(t) * ax, y, .0 + Math.sin(t) * az]); } A.strap(B, pts, .07, .018, nrm, { mat: 5, kg: .01 }); }
  for (const m of [-1, 1]) { const f = []; for (let i = 0; i <= 8; i++) { const y = 6.55 + i * .2; f.push(vsurf(m * (.33 + i * .012), y, 1)); } const top = [m * .45, 8.45, .02]; const bk = []; for (let i = 0; i <= 8; i++) { const y = 8.15 - i * .27; bk.push(vsurf(m * (.4 - i * .1), y, -1)); } A.strap(B, [...f, top, ...bk], .07, .018, c => V.norm(V.add(nrm(c), [0, c[1] > 8.2 ? 1 : 0, 0])), { mat: 5, kg: .01 }); }
  // 가슴 명찰(빈칸)과 무전기 집게
  B.group({ k: .01, kg: .03 }); B.box(new Frame(vsurf(-.42, 7.35, 1), [1, 0, 0], [0, 1, 0], [0, 0, 1]).rot(-12, -18, 0), [.17, .07, .015], .015); B.group({ k: .02, kg: .04 }); B.box(new Frame(V.add(vsurf(.45, 7.3, 1), [0, 0, .08]), [1, 0, 0], [0, 1, 0], [0, 0, 1]).rot(-14, 22, 0), [.1, .2, .06], .04); B.tube([V.add(vsurf(.42, 7.5, 1), [0, 0, .12]), V.add(vsurf(.4, 7.75, 1), [0, 0, .12])], .015);
  // 허리: 벨트 + 바코드 스캐너 집
  ring([0, 5.32, 0], [0, 1, 0], .73, .055, { fz: .62 }); B.group({ k: .02, kg: .05 }); B.box(I([.72, 5.15, .05]).rot(0, 80, 0), [.14, .2, .07], .04); B.box(I([0, 5.32, .45]), [.11, .08, .03], .02);
  // ── 목과 후드: 목이 앞으로 길게 빠지고 머리는 숙임
  const HF = I([0, 9.55, .72]).rot(p.nod ?? -24, p.headYaw || 0, p.tilt ?? 18), s = 1.2, hp = v => HF.p(V.mul(v, s));
  B.group({ k: .18, kg: .2 }); B.tube([[0, 8.3, -.05], [0, 8.85, .2], hp([0, -.3, -.12])], [.38, .3, .28]);
  // 얼굴: 후드 그늘 속, 길쭉하고 빈 눈, 입은 살짝 벌어짐
  A.face(B, HF, s, { jaw: p.jaw ?? 12, eyes: 'empty', gaunt: 1.5, age: 1, teeth: 10, ears: false, elong: 1.12, w: .9, vein: false, lips: .6 });
  B.group({ k: .1, kg: .12, amp: .01, freq: 3 }); B.ell(HF.at(V.mul([0, .08, -.1], s)), [.46 * s, .5 * s, .52 * s]); B.ell(HF.at(V.mul([0, .16, .2], s)), [.4 * s, .4 * s, .42 * s]); B.ell(HF.at(V.mul([0, .12, .36], s)), [.36 * s, .36 * s, .3 * s]); for (const m of [-1, 1]) B.ell(HF.at(V.mul([m * .3, -.15, .3], s)), [.12 * s, .3 * s, .25 * s]); B.ell(HF.at(V.mul([0, -.1, .6], s)), [.25 * s, .4 * s, .3 * s], { op: 1, k: .05 }); B.ell(HF.at(V.mul([0, -.05, .25], s)), [.27 * s, .38 * s, .2 * s], { op: 1, k: .05 });
  for (let i = 0; i < 7; i++) B.groove(hp([Math.sin(i * 1.3) * .3, .35 - i * .09, -.1]), HF.d([.5 * Math.sin(i * 2.1), 1, .4]), .016, .035, .6, { bow: .7 * Math.sin(i * 1.7), wob: .2 });
  // 후드 테두리 두꺼운 단 + 끈
  { const pts = []; for (let i = 0; i <= 22; i++) { const a = -Math.PI / 2 + i / 22 * 6.283; pts.push(hp([Math.cos(a) * .27, -.1 + Math.sin(a) * .4, .5 + .03 * Math.cos(a) ** 2 + .05 * Math.max(0, Math.sin(a))])); } B.group({ k: .04, kg: .06 }); B.tube(pts, .05 * s, { per: 1 }); for (const m of [-1, 1]) { B.tube([hp([m * .2, -.45, .32]), V.add(hp([m * .22, -.5, .32]), [m * .02, -.45, .12]), V.add(hp([m * .22, -.5, .32]), [m * .03, -.8, .14])], .022); B.ball(V.add(hp([m * .22, -.5, .32]), [m * .03, -.82, .14]), .035); } }
  // 후드 자락: 어깨까지
  B.group({ k: .2, kg: .2, amp: .01, freq: 3 }); B.tube([[0, 8.4, -.15], hp([0, -.15, -.25])], [.6, .4 * s]); for (let i = 0; i < 6; i++) { const a = -2.4 + i * .95; B.groove([Math.sin(a) * .45, 8.75, -.05 + Math.cos(a) * .32], V.norm([Math.cos(a), .3, -Math.sin(a)]), .014, .03, .4, { bow: .7 * Math.sin(i * 2.1), wob: .2 }); }
  // 후드티 당김 주름: 겨드랑이→배 사선, 허리 아래 처짐
  B.group({ k: .2, kg: .02 }); for (const m of [-1, 1]) { for (let i = 0; i < 3; i++) B.groove([m * (.55 - i * .06), 7.2 - i * .28, .38], V.norm([m * .9, 1, .1]), .013, .035, .55, { bow: .8, wob: .2 }); for (let i = 0; i < 2; i++) B.groove([m * .62, 5.5 + i * .16, .25], V.norm([0, 1, .2]), .013, .03, .4, { bow: .6, wob: .2 }); }
  // ── 상체 숙이기: 위 그룹 전부를 엉덩이 축으로 앞으로 숙이고, 무게를 왼발 쪽으로 살짝
  const T = new Frame(V.add(PV, [0, -.12, HB])).rot(stoop, p.twist ?? -8, (p.roll ?? 4) * (S > 0 ? 1 : -1)), qT = quat(T.x, T.y, T.z), xf = v => T.p(V.sub(v, PV));
  for (let gi = g0; gi < B.groups.length; gi++) for (const q of B.groups[gi].prims) { if (q.t === 0) { q.a = xf(q.a); q.b = xf(q.b); } else if (q.t === 3) { q.a = xf(q.a); q.b = T.d(q.b); } else { q.a = xf(q.a); q.q = qmul(qT, q.q); } }
  // ── 팔: 너무 긴 팔, 목장갑(팔꿈치 안쪽 구김)
  const arm = (m, sh, e, wr, hand) => { cloth([xf([m * .55, 8.2, -.05]), sh, V.lerp(sh, e, .5), e, V.lerp(e, wr, .6), wr], [.32, .32, .27, .24, .22, .21], 7); const bend = V.norm(V.sub(V.lerp(sh, wr, .5), e)); B.group({ k: .02, kg: .0 }); for (let i = 0; i < 4; i++) B.groove(V.add(e, V.mul(bend, .2)), V.norm(V.add(V.sub(sh, e), V.mul(V.sub(wr, e), (i - 1.5) * .3))), .012, .035, .32, { bow: 1.5, wob: .2 }); ring(V.add(wr, V.mul(V.norm(V.sub(e, wr)), .05)), V.sub(e, wr), .22, .04, { wob: .02 }); hand(); };
  // 오른팔(−x): 갈고리를 가슴 높이로 치켜들고 끝을 앞으로
  { const sh = xf([-.85, 8.05, -.05]), e = V.add(sh, [-.45 - .1 * lift, -1.75 + .35 * lift, -.15 - .35 * lift]), rw = V.add(e, [.2 * lift + .05, -1.6 + 1.95 * lift, .4 + 1.0 * lift]);
    arm(-1, sh, e, rw, () => {
      const fy = V.norm(V.lerp([0, -1, .1], [.15, .15, 1], lift)), F0 = Frame.along(V.add(rw, V.mul(fy, .1)), fy, V.lerp([-1, 0, 0], [-.4, 1, 0], lift)); const F = new Frame(F0.o, F0.x, F0.y, V.mul(F0.z, 1)); B.group({ k: .06, kg: .1 }); B.tube([rw, F.o], [.22, .2]); A.hand(B, F, 1.35, { curl: [80, 84, 86, 88], spread: 4, thin: 1.3, vein: 0, thumbOut: 12 });
      // 화물 갈고리: 주먹 속 T자 손잡이 → 쇠 자루(앞으로) → 위로 휜 갈고리
      const g = V.add(F.o, V.add(V.mul(F.y, .32), V.mul(F.z, -.14))); B.group({ k: .02, kg: .03 }); B.tube([V.add(g, V.mul(F.x, -.32)), V.add(g, V.mul(F.x, .32))], .07); for (const z of [-.33, .33]) B.ball(V.add(g, V.mul(F.x, z)), .08);
      const d = V.norm(V.lerp([0, -1, .05], [0, -.35, 1], lift)), n = V.norm(V.cross(V.cross(d, [0, 1, 0]), d)), p2 = V.add(g, V.mul(d, 1.05)); B.group({ k: .01, kg: .02 }); B.tube([V.add(g, V.mul(d, .05)), V.add(g, V.mul(d, .55)), p2], [.06, .058, .058]); ring(V.add(g, V.mul(d, .14)), d, .07, .02);
      const nn = V.mul(n, lift > .5 ? 1 : -1), hk = []; for (let i = 0; i <= 10; i++) { const a = i / 10 * Math.PI * 1.15; hk.push(V.add(p2, V.add(V.mul(d, Math.sin(a) * .42), V.mul(nn, (1 - Math.cos(a)) * .42)))); } B.tube(hk, [.06, .06, .058, .055, .05, .046, .04, .034, .026, .018, .008], { per: 3 });
      // 갈고리 끝의 마른 피 — 붉은 곳 하나
      B.group({ mat: 1, k: .01 }); B.tube(hk.slice(7), [.034, .03, .024, .014], { per: 3 }); B.tube([hk[8], V.add(hk[8], [0, -.1, .0]), V.add(hk[8], [0, -.2, .01])], [.012, .01, .004]);
    }); }
  // 왼팔(+x): 무릎 아래까지 늘어진 빈손, 손가락을 반쯤 오므림
  { const sh = xf([.85, 8.05, -.05]), e = V.add(sh, [.38, -1.95, -.25 - S * .15]), wr = V.add(e, [-.02, -1.9, .3 - S * .2]); arm(1, sh, e, wr, () => { const F = new Frame(V.add(wr, [0, -.12, .02]), [0, 0, 1], V.norm([.05, -1, .12]), [1, 0, 0]); B.group({ k: .06, kg: .1 }); B.tube([wr, F.o], [.22, .2]); A.hand(B, F, 1.55, { curl: [38, 48, 52, 60], spread: 7, thin: 1.2, len: 1.3, vein: 0, claw: .04 }); }); }
  return B;
} };
