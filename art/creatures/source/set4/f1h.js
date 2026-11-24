// 시안4 1장 인간형 — 방호복: 격리 구역에 마지막까지 남았던 연구원. 방독면이 얼굴에 녹아 붙어 벗겨지지 않고, 끊어진 제 공기 호스를 손에 쥔 채 질질 끌며 순찰을 계속한다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
const I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]);
module.exports = { id: 'f1h', name: '방호복', kind: '인간형 · 1장 지하 시설', H: 9.0, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .35 : Math.sin(w * Math.PI * 2), lean = p.lean ?? 1;
  // 고리 띠(테이프·커프): 축 d 둘레 원
  const ring = (c, d, r, t, o = {}) => { const F = Frame.along(c, d, [0, 0, 1]); const pts = []; for (let i = 0; i <= 20; i++) { const a = i / 20 * 6.283; pts.push(F.p([Math.cos(a) * r, (o.wob ?? .015) * Math.sin(i * 2.7), Math.sin(a) * r * (o.fz ?? 1)])); } B.group({ k: .02, kg: o.kg ?? .05, mat: o.mat ?? 0 }); B.tube(pts, t, { per: 1 }); };
  // 헐렁한 방호복 소매·바지: 굵은 관 + 비스듬히 처진 주름(길고 얕게) + 관절 쪽 접힘
  const sleeve = (pts, rs, n, o = {}) => { B.group({ k: o.k ?? .14, kg: o.kg ?? .14, amp: .012, freq: 2.5 }); B.tube(pts, rs); const N = pts.length - 1; for (let i = 0; i < n; i++) { const t = (i + .5 + .35 * Math.sin(i * 5.1)) / n * N, j = Math.min(N - 1, Math.floor(t)), c = V.lerp(pts[j], pts[j + 1], t - j), d = V.norm(V.sub(pts[j + 1], pts[j])), r = rs[j] + (rs[j + 1] - rs[j]) * (t - j), sd = V.norm(V.cross(d, [0, 0, 1])); const tilt = .7 + .5 * Math.sin(i * 2.3); B.groove(V.add(c, V.mul(sd, r * .3 * Math.sin(i * 3.7))), V.norm(V.add(d, V.add(V.mul(sd, tilt * (i % 2 ? 1 : -1)), [0, 0, .3 * Math.cos(i * 3.1)]))), .016, .035 + .02 * Math.abs(Math.sin(i * 1.9)), r * 1.25, { bow: .9 * Math.sin(i * 2.9), wob: .2, wf: 2.5 }); } };
  // ── 다리: 방호복 바지(무릎 살짝 굽힘) + 고무 장화(테이프 감김)
  for (const m of [-1, 1]) {
    const st = m * S, h = [m * .5, 4.05, 0], k = [m * .6, 2.3, .4 + st * .45], an = [m * .56, .72 + Math.max(0, -st) * .2, -.05 + st * .8];
    sleeve([h, V.lerp(h, k, .5), k, V.lerp(k, an, .55), V.add(an, [0, .35, 0])], [.56, .48, .43, .41, .4], 8);
    B.group({ k: .08, kg: .12 }); B.ell(I(V.add(k, [0, .02, .26])), [.3, .28, .18]); for (let i = 0; i < 3; i++) B.groove(V.add(k, [0, -.1 + i * .12, .38]), V.norm([0, 1, .3 * (i - 1)]), .018, .04, .45, { bow: 1.2, wob: .2 });
    B.group({ k: .07, kg: .12, amp: .004 }); B.tube([V.add(an, [0, .5, 0]), an, V.add(an, [0, -.35, .02])], [.4, .36, .34]); B.ell(I(V.add(an, [m * .02, -.45, .3])).rot(0, m * 6, 0), [.34, .22, .62]); B.box(I(V.add(an, [m * .02, -.66, .3])).rot(0, m * 6, 0), [.36, .05, .66], .05);
    for (let i = 0; i < 6; i++) B.groove(V.add(an, [0, -.68, -.2 + i * .17]), [0, 0, 1], .02, .03, .4, { wob: 0 });
    for (let i = 0; i < 3; i++) B.groove(V.add(an, [m * .1, -.15, .45]), V.norm([.2 * (i - 1), .3, 1]), .015, .03, .3, { bow: 1, wob: .1 });
    ring(V.add(an, [0, .45, 0]), [0, 1, 0], .43, .06, { wob: .03 }); ring(V.add(an, [0, .3, 0]), V.norm([.1 * m, 1, .08]), .42, .05, { wob: .04 });
  }
  // ── 몸통: 앞으로 굽은 부푼 방호복, 가운데 지퍼, 벨트, 출입증
  B.group({ k: .3, kg: .3, amp: .012, freq: 2.5 }); B.ell(I([0, 4.3, 0]), [.92, .58, .6]); B.ell(I([0, 5.25, .05]), [.95, .85, .64]); B.ell(I([0, 6.35, .02 + .05 * lean]).rot(14 * lean, 0, 0), [1.08, .95, .68]); for (const m of [-1, 1]) B.ell(I([m * .98, 6.95, .05 * lean]), [.44, .38, .42]);
  for (let i = 0; i < 9; i++) { const m = i % 2 ? 1 : -1, y = 4.7 + i * .27; B.groove([m * (.5 + .2 * Math.sin(i)), y, .6], V.norm([m * .9, 1, .3 * Math.sin(i * 2)]), .016, .035, .8, { bow: .9 * m, wob: .2, wf: 2.5 }); }
  for (let i = 0; i < 5; i++) B.groove([.0, 6.2 + i * .2, -.6], V.norm([.5 * Math.sin(i * 3), 1, -.3]), .016, .04, 1, { bow: .8, wob: .15 });
  // 지퍼 덮개
  B.group({ k: .02, kg: .06 }); B.tube([[.08, 7.25, .62], [.1, 6.5, .78], [.08, 5.4, .72], [.06, 4.5, .62]], .07); B.group({ k: .006, kg: .02 }); for (let i = 0; i < 22; i++) { const t = i / 21, c = V.lerp([.0, 7.15, .66], [-.02, 4.55, .66], t); c[2] += .14 * Math.sin(t * Math.PI); B.box(I(c), [.035, .018, .02], .008); }
  ring([0, 4.72, .02], [0, 1, .05], .94, .07, { fz: .7, wob: .02 }); B.group({ k: .01, kg: .04 }); B.box(I([0, 4.72, .69]), [.16, .11, .05], .03);
  // 출입증(끈에 매달려 앞으로 늘어짐)
  B.group({ k: .01, kg: .03 }); B.tube([[-.28, 7.2, .62], [-.42, 6.8, .82], [-.5, 6.35, .9]], .02); B.tube([[.25, 7.2, .62], [-.25, 6.75, .86], [-.5, 6.35, .9]], .02); B.box(I([-.52, 6.1, .93]).rot(-2, 0, 8), [.17, .24, .02], .02); B.box(I([-.52, 6.17, .96]).rot(-2, 0, 8), [.11, .1, .01], .01, { op: 1 });
  B.group({ k: .02, kg: .06 }); B.box(I([.55, 6.25, .76]).rot(-16, 18, 0), [.22, .22, .04], .03); B.box(I([.55, 6.46, .8]).rot(-16, 18, 0), [.24, .05, .05], .03);
  // ── 등: 공기통과 멜빵
  const T = I([0, 6.3, -.85]).rot(-2 * lean, 0, 0); B.group({ k: .03, kg: .08 }); B.tube([T.p([0, -1.05, 0]), T.p([0, .95, 0])], .34); B.ball(T.p([0, .95, 0]), .34, { k: .1 }); B.ball(T.p([0, -1.05, 0]), .33, { k: .1 }); B.tube([T.p([0, 1.25, 0]), T.p([0, 1.42, -.02])], .09); B.tube([T.p([-.2, 1.38, 0]), T.p([.2, 1.38, 0])], .06); for (const y of [-.7, .55]) ring(T.p([0, y, 0]), T.y, .36, .045);
  B.group({ k: .02, kg: .06 }); B.box(T.at([0, 0, .32]), [.5, 1.15, .04], .04);
  for (const m of [-1, 1]) A.strap(B, [[m * .55, 7.25, -.5], [m * .62, 7.4, .15], [m * .5, 6.9, .7], [m * .45, 5.8, .72], [m * .55, 4.9, .66]], .1, .04, [0, 0, 1]);
  // ── 목·두건: 목이 앞으로 빠지고 고개가 꺾임
  const nod = p.nod ?? 8, HF = I([-.08, 8.5, .72 + .15 * lean]).rot(nod, p.headYaw ?? 0, p.tilt ?? -14), s = 1.4, hp = v => HF.p(V.mul(v, s));
  B.group({ k: .18, kg: .22 }); B.tube([[0, 7.1, 0], [-.02, 7.55, .3], hp([0, -.25, -.1])], [.5, .44, .42]);
  // 두건 자락: 어깨까지 덮어 내려오는 천, 목 조임끈
  B.group({ k: .25, kg: .25, amp: .01, freq: 3 }); B.ell(I([0, 7.2, .12]), [.9, .32, .66]); B.tube([[0, 7.25, .1], hp([0, -.35, -.15])], [.72, .44 * s]); for (let i = 0; i < 9; i++) { const a = -2.6 + i * .65; B.groove([Math.sin(a) * .6, 7.55, .1 + Math.cos(a) * .45], V.norm([Math.cos(a), .25, -Math.sin(a)]), .016, .035, .5, { bow: .8 * Math.sin(i * 2.1), wob: .2 }); }
  ring(V.lerp([0, 7.35, .15], hp([0, -.35, -.1]), .55), V.norm(V.sub(hp([0, -.35, -.1]), [0, 7.35, .15])), .5, .04, { wob: .04 }); B.group({ k: .01, kg: .03 }); B.tube([V.add(V.lerp([0, 7.35, .15], hp([0, -.35, -.1]), .55), [-.15, -.03, .5]), V.add(V.lerp([0, 7.35, .15], hp([0, -.35, -.1]), .55), [-.2, -.45, .6]), V.add(V.lerp([0, 7.35, .15], hp([0, -.35, -.1]), .55), [-.17, -.75, .66])], .022); B.ball(V.add(V.lerp([0, 7.35, .15], hp([0, -.35, -.1]), .55), [-.17, -.8, .66]), .05);
  const jaw = p.jaw ?? 42;
  A.face(B, HF, s, { jaw, eyes: 'real', gaunt: 1.3, age: 1, teeth: 10, ears: false, iris: .02, open: 1.25, vein: false, eyeSize: 1.15 });
  // 두건(얼굴 구멍은 턱 아래까지 넓게 터짐)
  B.group({ k: .1, kg: .06, amp: .008, freq: 4 }); B.ell(HF.at(V.mul([0, .08, -.12], s)), [.44 * s, .44 * s, .47 * s]); B.ell(HF.at(V.mul([0, .3, -.28], s)).rot(-30, 0, 0), [.3 * s, .22 * s, .3 * s]); B.ell(HF.at(V.mul([0, -.28, -.2], s)), [.4 * s, .34 * s, .36 * s]); B.ell(HF.at(V.mul([0, -.1, .3], s)), [.31 * s, .5 * s, .42 * s], { op: 1, k: .06 });
  for (let i = 0; i < 6; i++) B.groove(hp([.0, .22 - i * .1, -.25]), HF.d([Math.sin(i * 2.1) * .5, 1, .3]), .018, .04, .7, { bow: .6 * Math.sin(i * 1.7), wob: .15 });
  // 두건 테두리 고무 실링(아래쪽은 찢겨 늘어짐)
  { const pts = []; for (let i = 0; i <= 16; i++) { const a = -.35 + i / 16 * (Math.PI + .7); pts.push(hp([Math.cos(a) * .32, -.1 + Math.sin(a) * .5, .25 + .06 * Math.cos(a) ** 2])); } B.group({ k: .03, kg: .06 }); B.tube(pts, .045 * s, { per: 2 }); for (const m of [-1, 1]) B.tube([hp([m * .3, -.27, .27]), hp([m * .27, -.42, .22]), hp([m * .22, -.55, .14])], [.04 * s, .03 * s, .015 * s]); }
  // 방독면: 눈~코를 덮는 고무판(얼굴 크기보다 크다)
  const ex = .14, ey = -.02, lr = .115;
  B.group({ k: .06 * s, kg: .09 * s, amp: .003, freq: 6 }); B.ell(HF.at(V.mul([0, -.03, .31], s)), [.3 * s, .21 * s, .15 * s]); B.ell(HF.at(V.mul([0, -.14, .38], s)), [.13 * s, .08 * s, .1 * s]);
  for (const m of [-1, 1]) B.tube([hp([m * ex, ey, .38]), hp([m * ex * 1.05, ey, .45])], [lr * 1.18 * s, lr * 1.12 * s]); // 렌즈 통
  for (const m of [-1, 1]) B.ell(HF.at(V.mul([m * ex * 1.05, ey, .46], s)).rot(0, m * 10, 0), [lr * s, lr * s, (m > 0 ? .2 : .09) * s], { op: 1, k: .008 });
  for (let i = 0; i < 4; i++) B.groove(hp([0, -.17 - i * .025, .46]), HF.d([0, 1, -.4]), .006 * s, .01 * s, .12 * s, { bow: 2, wob: 0 });
  // 렌즈 테 + 나사
  for (const m of [-1, 1]) { const L = HF.at(V.mul([m * ex * 1.05, ey, .455], s)).rot(0, m * 10, 0); const pts = []; for (let i = 0; i <= 24; i++) { const a = i / 24 * 6.283; pts.push(L.p([Math.cos(a) * lr * s, Math.sin(a) * lr * s, 0])); } B.group({ k: .01, kg: .02 }); B.tube(pts, .026 * s, { per: 1 }); for (let i = 0; i < 6; i++) { const a = i / 6 * 6.283 + .3; B.ball(L.p([Math.cos(a) * lr * s, Math.sin(a) * lr * s, .022 * s]), .015 * s); } }
  // 오른쪽(−x) 렌즈: 김 서린 검은 유리
  { const L = HF.at(V.mul([-ex * 1.05, ey, .395], s)).rot(0, -10, 0); B.group({ mat: 2, k: .01 }); B.ell(L, [lr * .95 * s, lr * .95 * s, .012 * s]); B.group({ mat: 5, k: .001 }); B.ell(L.at([.04 * s, .045 * s, .014 * s]).rot(0, 0, -40), [.03 * s, .009 * s, .004 * s]); }
  // 왼쪽(+x) 렌즈: 깨져 뚫렸고, 그 안을 진짜 눈이 꽉 채움 — 눈꺼풀 살이 테 안쪽까지 자라 붙음
  { const L = HF.at(V.mul([ex * 1.05, ey, .43], s)).rot(0, 10, 0); B.group({ mat: 2, k: .01 }); B.ell(L.at([0, 0, -.06 * s]), [lr * .9 * s, lr * .9 * s, .03 * s]);
    B.group({ mat: 6, k: .006 }); B.ball(L.at([0, 0, -.06 * s]).o, .085 * s); B.group({ mat: 2, k: .002 }); B.ball(L.p([-.012 * s, -.008 * s, .02 * s]), .03 * s); B.group({ mat: 5, k: .001 }); B.ball(L.p([0, .008 * s, .03 * s]), .008 * s);
    B.group({ k: .012 * s, kg: .02 * s }); for (const u of [1, -1]) { const pts = []; for (let i = 0; i <= 10; i++) { const a = (u > 0 ? .15 : 3.3) + i / 10 * 2.85; const rr = lr * (.95 - .22 * Math.sin(i / 10 * Math.PI)); pts.push(L.p([Math.cos(a) * rr * s, Math.sin(a) * rr * s * (u > 0 ? .95 : .9), (-.005 + .02 * Math.sin(i / 10 * Math.PI)) * s])); } B.tube(pts, [.008, .014, .02, .022, .022, .022, .022, .022, .02, .014, .008].map(x => x * s), { per: 2 }); }
    B.group({ k: .002 }); for (const [a0, a1, rr] of [[.4, 1.0, .05], [2.6, 3.0, .04], [4.4, 5.0, .045]]) { const q0 = L.p([Math.cos(a0) * lr * s, Math.sin(a0) * lr * s, .01 * s]), q1 = L.p([Math.cos(a1) * lr * s, Math.sin(a1) * lr * s, .01 * s]), tip = L.p([Math.cos((a0 + a1) / 2) * (lr - rr) * s, Math.sin((a0 + a1) / 2) * (lr - rr) * s, .016 * s]); B.tube([q0, tip, q1], .005 * s, { per: 2 }); } }
  // 피눈물(깨진 렌즈 아래) — 붉은 곳은 여기 하나
  B.group({ mat: 1, k: .01 }); B.tube([hp([ex * 1.05, -.13, .47]), hp([ex * 1.05 + .01, -.19, .46]), hp([ex * 1.05 + .02, -.25, .42]), hp([ex + .03, -.31, .35])], [.012 * s, .017 * s, .014 * s, .006 * s]);
  // 흡기 밸브 주둥이 + 한쪽 정화통(다른 쪽은 떨어져 나간 나사턱)
  const VA = Frame.along(hp([0, -.13, .47]), HF.d([0, -.1, 1]), HF.y); B.group({ k: .015, kg: .05 }); B.tube([VA.o, VA.p([0, .06 * s, 0]), VA.p([0, .1 * s, 0])], [.08 * s, .085 * s, .08 * s]); B.ball(VA.p([0, .1 * s, 0]), .05 * s, { op: 1, k: .01 }); for (let i = 0; i < 8; i++) { const a = i / 8 * 6.283; B.groove(VA.p([Math.cos(a) * .08 * s, .07 * s, Math.sin(a) * .08 * s]), VA.d([-Math.sin(a), 0, Math.cos(a)]), .006 * s, .01 * s, .05 * s, { wob: 0 }); }
  const HC = Frame.along(hp([.25, -.19, .3]), HF.d([.8, -.45, .4]), HF.y); B.group({ k: .02, kg: .04 }); B.tube([HC.o, HC.p([0, .1 * s, 0])], [.075 * s, .08 * s]); B.tube([HC.p([0, .08 * s, 0]), HC.p([0, .14 * s, 0])], .1 * s); for (let i = 0; i < 6; i++) { const a = i / 6 * 6.283; B.box(Frame.along(HC.p([Math.cos(a) * .1 * s, .11 * s, Math.sin(a) * .1 * s]), HC.y, [Math.cos(a), 0, Math.sin(a)]), [.012 * s, .03 * s, .012 * s], .004); }
  { const C = Frame.along(hp([-.25, -.19, .3]), HF.d([-.8, -.4, .45]), HF.y); B.group({ k: .02, kg: .04 }); B.tube([C.o, C.p([0, .07 * s, 0])], .065 * s); B.tube([C.p([0, .07 * s, 0]), C.p([0, .24 * s, 0])], .13 * s); for (let i = 0; i < 4; i++) B.groove(C.p([0, (.1 + i * .035) * s, 0]), C.y, .006 * s, .012 * s, .2 * s, { wob: 0 }); B.ball(C.p([0, .24 * s, 0]), .09 * s, { op: 1, k: .01 }); }
  // 녹아 붙은 가장자리: 고무 위로 핏줄과 살이 기어오름
  B.group({ k: .025 * s, kg: .05 * s }); for (let i = 0; i < 11; i++) { const a = -3.0 + i * .6, x = Math.cos(a) * .3, y = -.03 + Math.sin(a) * .21, ins = .6 + .25 * Math.sin(i * 2.3); B.tube([hp([x * 1.25, y * 1.3 - .03, .22 - Math.abs(x) * .3]), hp([x * 1.02, y * 1.05, .33 - Math.abs(x) * .25]), hp([x * ins + .03 * Math.sin(i * 3), y * ins, .43 - Math.abs(x) * .3])], [.02 * s, .012 * s, .004 * s], { per: 2 }); }
  // 마스크 아래 가장자리와 아랫입술 사이에 늘어난 살 가닥, 아래 테두리를 덮은 살
  B.group({ k: .01 * s, kg: .02 * s }); for (const [x, r] of [[-.09, .012], [-.02, .008], [.06, .014], [.11, .007]]) B.tube([hp([x, -.215, .39]), hp([x * 1.05, -.3, .37]), hp([x * 1.1, -.4, .33])], [r * s, r * .55 * s, r * s], { per: 3 });
  B.group({ k: .03 * s, kg: .05 * s }); B.tube([hp([-.22, -.16, .3]), hp([-.13, -.21, .37]), hp([0, -.215, .4]), hp([.13, -.21, .37]), hp([.22, -.16, .3])], [.02 * s, .03 * s, .028 * s, .03 * s, .02 * s]);
  // ── 끌리는 호스: 주둥이 → 가슴 → 왼손에 쥐임 → 바닥을 따라 뒤로
  const hw = [1.33, 3.66, 1.0 - S * .3];
  { const s0 = HC.p([0, .13 * s, 0]), pts = [s0, HC.p([0, .4 * s, 0]), [.95, 7.1, .95], [.9, 6.2, 1.15], [.85, 5.4, 1.1], [1.2, 4.4, 1.0], hw, [1.45, 2.6, .9], [1.3, 1.3, .9], [1.0, .16, .55], [.9, .14, -.6], [1.3, .14, -1.6], [.9, .13, -2.6]]; B.group({ k: .02, kg: .03, amp: 0 }); B.tube(pts, .1, { per: 6 }); A.rings(B, pts, 70, .012, .03, .14, { tilt: .02, bow: 0, wob: 0 }); B.group({ k: .01, kg: .02 }); B.tube([[.9, .13, -2.6], [.85, .14, -2.85]], [.13, .14]); for (let i = 0; i < 5; i++) { const a = i / 5 * 6.283; B.cone([.85 + .1 * Math.cos(a), .14 + .1 * Math.sin(a), -2.88], [.84 + .16 * Math.cos(a), .14 + .16 * Math.sin(a), -3.05], .02, .008); } }
  // ── 왼팔(+x): 장갑 낀 소매, 손목 테이프, 호스를 쥠
  { const sh = [1.1, 6.95, .05], e = [1.55, 5.45, .35 - S * .2], wr = [1.48, 4.2, .95 - S * .3]; sleeve([[.85, 7.1, .05], sh, V.lerp(sh, e, .5), e, V.lerp(e, wr, .6), wr], [.42, .44, .38, .36, .33, .31], 9); ring(V.add(wr, [0, .14, -.03]), V.sub(e, wr), .33, .05, { wob: .03 }); ring(V.add(wr, [0, .02, 0]), V.sub(e, wr), .31, .045, { wob: .03 });
    B.group({ k: .08, kg: .12 }); B.tube([V.add(wr, [0, .1, -.02]), V.add(wr, [-.02, -.18, .02])], [.31, .24]); A.hand(B, new Frame(V.add(wr, [-.02, -.16, .02]), [0, 0, 1], [0, -1, 0], [1, 0, 0]), 1.5, { curl: [78, 82, 84, 86], spread: 4, thin: 1.35, vein: 0, thumbOut: 10 }); }
  // ── 오른팔(−x): 소매가 팔꿈치에서 찢겨 앙상한 맨팔과 너무 긴 손가락
  { const sh = [-1.1, 6.8, .1], e = [-1.47, 5.15, .5 + S * .2], wr = [-1.32, 3.25, 1.05 + S * .35]; sleeve([[-.85, 7.1, .05], sh, V.lerp(sh, e, .55), V.lerp(sh, e, .85)], [.42, .44, .38, .36], 5);
    for (let i = 0; i < 8; i++) { const a = i / 8 * 6.283 + .4, C = V.lerp(sh, e, .85), d = V.norm(V.sub(e, sh)), F = Frame.along(C, d, [0, 0, 1]), r0 = .34, ln = .2 + .3 * Math.abs(Math.sin(i * 2.7)); const q0 = F.p([Math.cos(a) * r0, 0, Math.sin(a) * r0]), q1 = F.p([Math.cos(a) * r0 * .9, ln * .6, Math.sin(a) * r0 * .9]), q2 = F.p([Math.cos(a + .2) * r0 * .78, ln, Math.sin(a + .2) * r0 * .78]); B.group({ k: .01, kg: .05 }); B.box(Frame.along(V.lerp(q0, q1, .5), V.sub(q1, q0), [Math.cos(a), 0, Math.sin(a)]), [.085, ln * .32, .018], .015); B.box(Frame.along(V.lerp(q1, q2, .5), V.sub(q2, q1), [Math.cos(a), 0, Math.sin(a)]), [.05, ln * .22, .016], .012); }
    A.arm(B, V.lerp(sh, e, .45), e, wr, .23, { m: .8 }); A.hand(B, new Frame(wr, V.norm([0, 0, 1]), V.norm([-.05, -1, .18]), V.norm([-1, 0, 0])), 1.75, { curl: [10, 18, 14, 24], spread: 11, thin: .8, len: 1.35, claw: .05 });
    ring(V.lerp(e, wr, .3), V.sub(wr, e), .19, .03, {}); A.veins(B, [V.add(V.lerp(e, wr, .4), [.12, 0, .12]), V.add(V.lerp(e, wr, .6), [.08, 0, .16]), V.add(V.lerp(e, wr, .85), [.1, 0, .1])], .022); }
  return B;
} };
