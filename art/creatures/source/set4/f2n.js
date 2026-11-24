// 시안4 2장 비인간형 — 출고 대기: 무릎 꿇고 웅크린 사람을 랩으로 꽁꽁 감아 팔레트에 실은 화물. 비닐 너머로 비명 지르는 얼굴과 손바닥이 눌려 비치고, 비닐을 뚫고 나온 팔로 팔레트를 붙잡고 바닥을 당겨 기어 온다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
const I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]);
const HF = (o, fy, bz) => { const y = V.norm(fy), x = V.norm(V.cross(y, bz)), z = V.cross(x, y); return new Frame(o, x, y, z); }; // 손 틀: 손가락 방향, 손등 방향
module.exports = { id: 'f2n', name: '출고 대기', kind: '비인간형 · 2장 물류 창고', H: 5.2, build(p = {}) {
  const B = new Body(), w = p.walk ?? .2, ph = w * Math.PI * 2, rise = p.rise ?? 1, pull = Math.sin(ph) * rise, y0 = .04 + .12 * Math.max(0, pull);
  // ── 팔레트(바닥에 끌림, 당길 때 앞이 들림)
  const P = I([0, y0, -.1 * pull]).rot(-4 * Math.max(0, pull), 0, 2 * Math.cos(ph) * rise), pp = v => P.p(v);
  B.group({ k: .01, kg: .02, amp: .004, freq: 9 }); for (let i = 0; i < 7; i++) { const z = -1.0 + i * .333; B.box(P.at([0, .26, z]), [1.25, .04, .12 - (i % 3 === 1 ? .02 : 0)], .015); for (let j = 0; j < 3; j++) B.groove(pp([-1.0 + j * .9 + .3 * Math.sin(i * 3 + j), .3, z]), P.x, .006, .01, .25, { wob: .3, wf: 6 }); for (const x of [-1.15, 0, 1.15]) B.ball(pp([x, .3, z]), .02, { op: 1, k: .005 }); }
  for (const x of [-1.12, 0, 1.12]) for (const z of [-.95, 0, .95]) B.box(P.at([x, .13, z]), [.13, .09, .13], .015); for (const x of [-1.12, 0, 1.12]) { B.box(P.at([x, .19, 0]), [.13, .02, 1.12], .012); B.box(P.at([x, .0, 0]), [.13, .035, 1.12], .012); }
  { const C = I(pp([.95, .2, 1.05])).rot(0, 0, 18); B.box(C, [.12, .05, .06], .01, { op: 1 }); } // 부서진 모서리
  const tear = (c, d, r) => { const F = Frame.along(c, d, [0, 1, 0]); B.group({ k: .01, kg: .06 }); for (let i = 0; i < 9; i++) { const a = i / 9 * 6.283 + .3, ln = .18 + .22 * Math.abs(Math.sin(i * 2.7)); const q0 = F.p([Math.cos(a) * r, -.02, Math.sin(a) * r]), q1 = F.p([Math.cos(a) * r * 1.05, ln, Math.sin(a) * r * 1.05]); B.box(Frame.along(V.lerp(q0, q1, .5), V.sub(q1, q0), [Math.cos(a), 0, Math.sin(a)].map((x, j) => F.x[j] * Math.cos(a) + F.z[j] * Math.sin(a))), [.06 + .02 * Math.sin(i), ln * .5, .012], .01); } };
  // ── 랩 속의 몸: 발뒤꿈치에 앉아 웅크린 사람(앞) + 등을 맞대고 옆으로 웅크린 사람(뒤)
  const base = pp([0, .3, 0]), Q = v => V.add(base, v), nod = p.nod || 0, hy = p.headYaw || 0, jaw = p.jaw ?? 34;
  B.group({ k: .22, kg: .1, amp: .004, freq: 3 });
  // 앞 사람: 접은 다리(허벅지·무릎·정강이), 엉덩이, 둥근 등, 어깨, 숙인 머리
  for (const m of [-1, 1]) { B.tube([Q([m * .48, .7, -.45]), Q([m * .52, .55, .3]), Q([m * .55, .42, .95])], [.42, .38, .3]); B.ball(Q([m * .55, .42, 1.0]), .3); B.tube([Q([m * .55, .3, .95]), Q([m * .5, .22, .1]), Q([m * .45, .2, -.6])], [.26, .27, .18]); B.ell(I(Q([m * .42, .2, -.85])).rot(0, m * 10, 0), [.16, .14, .36]); }
  B.ell(I(Q([0, .85, -.6])), [.82, .55, .5]); for (const m of [-1, 1]) B.ball(Q([m * .38, .75, -.85]), .42);
  { const sp = [Q([0, 1.1, -.75]), Q([0, 1.8, -.85]), Q([0, 2.5, -.6]), Q([0, 3.0, -.15]), Q([0, 3.15, .3])]; B.tube(sp, [.6, .62, .7, .6, .38]); B.ell(I(Q([0, 2.35, -.15])).rot(-28, 0, 0), [.78, .82, .55]); for (let i = 0; i < 9; i++) { const t = i / 8, c = V.lerp(sp[1], sp[3], t); B.ball(V.add(c, [0, .05, -.55 + .3 * t * t - .05 * Math.sin(t * 3)]), .085, { k: .08 }); } for (const m of [-1, 1]) { B.ell(I(Q([m * .4, 2.6, -.55])).rot(-35, m * 20, 0), [.32, .4, .14], { k: .15 }); B.ball(Q([m * .78, 2.85, .1]), .33); } }
  // 앞 사람의 팔: 위팔은 몸 옆으로 내려와 팔꿈치가 불거지고, 아래팔은 얼굴 양옆으로 올라와 손바닥이 비닐을 밀어냄
  for (const m of [-1, 1]) { const sh = Q([m * .8, 2.8, .15]), el = Q([m * .95, 1.85, .85]), wr = Q([m * .6, 2.4, 1.12]); B.tube([sh, V.lerp(sh, el, .5), el], [.25, .22, .17]); B.ball(V.add(el, [m * .02, -.06, -.04]), .17); B.tube([el, V.lerp(el, wr, .5), wr], [.17, .16, .12]); }
  // 뒤 사람: 옆으로 누워 웅크린 등과 엉덩이, 뒤로 솟은 머리
  B.ell(I(Q([.1, 1.05, -1.35])).rot(0, 0, 70), [.55, .9, .45]); B.ball(Q([.75, .75, -1.25]), .45); B.ball(Q([-.55, 1.6, -1.25]), .42); B.ell(I(Q([-.25, .55, -1.55])).rot(0, 0, 80), [.3, .75, .3]);
  // 비닐이 몸 사이 틈을 메워 당겨짐(웹)
  B.ell(I(Q([0, .55, .6])), [.95, .45, .55], { k: .3 }); B.ell(I(Q([0, 1.55, .3])).rot(-20, 0, 0), [.78, .62, .58], { k: .3 }); // 웅크린 가슴·배 B.ell(I(Q([0, 2.75, .82])), [1.0, .7, .36], { k: .3 }); // 얼굴·손 앞 팽팽한 비닐막
  // 랩 겹: 넓은 띠 가장자리가 비스듬히, 조금씩 처지며 겹침(가장자리마다 두 줄 단차)
  for (let i = 0; i < 8; i++) { const y = .25 + i * .42, t = .12 * Math.sin(i * 1.9 + .5), sg = -.35 - .15 * Math.sin(i * 2.7); for (const o of [0, .05]) B.groove(Q([0, y + o, -.2]), V.norm([t, 1, .1 * Math.cos(i * 2.3)]), o ? .009 : .016, o ? .016 : .036, 2.2, { bow: sg, wob: .06, wf: 1.5 }); }
  for (let i = 0; i < 7; i++) { const a = i * .9; B.groove(Q([Math.cos(a) * .8, .9 + .35 * Math.sin(i * 2.3), Math.sin(a) * .7]), V.norm([Math.cos(a + 1.6), .5 * Math.sin(i * 2), Math.sin(a + 1.6)]), .008, .016, .45, { bow: 1.2, wob: .25 }); } // 당겨진 잔주름
  // 비닐 너머 눌린 얼굴(비명) + 양옆 손바닥
  const F1 = I(Q([0, 2.75, 1.02])).rot(14 + nod, hy, 6); A.face(B, F1, 1.2, { jaw, eyes: 'shut', gaunt: .5, age: .5, teeth: 0, ears: false, kg: .28, rid: 0, vein: false, lips: 1.2, mouthW: 1.15 });
  for (const m of [-1, 1]) { A.hand(B, HF(Q([m * .62, 2.35, 1.18]), [-m * .55, .85, -.05], [-m * .15, .05, -1]), .9, { curl: [4, 8, 6, 10], spread: 15, thin: 1.1, vein: 0 }); B.g.kg = .26; }
  // 비닐 안쪽에 미끄러져 번진 피 손자국
  { const H0 = Frame.along(Q([-.42, 1.5, .88]), [0, 1, .3], [-.3, -.2, 1]); B.group({ mat: 1, k: .03 }); B.ell(H0.at([0, .02, 0]).rot(0, 0, 8), [.13, .12, .015]); for (let i = 0; i < 4; i++) { const x = (i - 1.5) * .065, top = .2 + .04 * Math.sin(i * 2.3), bot = -.2 - .35 * Math.abs(Math.sin(i * 1.9 + .5)); B.tube([H0.p([x * 1.1, top, .0]), H0.p([x, .05, .005]), H0.p([x * .9 + .01 * Math.sin(i * 5), bot * .6, .005]), H0.p([x * .85, bot, .0])], [.024, .03, .018, .006], { per: 3 }); } B.tube([H0.p([.13, .0, 0]), H0.p([.2, .09, .005])], [.026, .016]); }
  // 화물 라벨(바코드)
  { const L = Frame.along(Q([1.12, 1.25, -.55]), [0, 1, 0], [1, 0, -.35]); B.group({ k: .01, kg: .03 }); B.box(L, [.3, .22, .012], .01); for (let i = 0; i < 11; i++) B.groove(L.p([-.22 + i * .04 + .01 * Math.sin(i * 7), -.06, .012]), L.x, .006 + .005 * Math.abs(Math.sin(i * 5)), .006, .09, { wob: 0 }); B.groove(L.p([0, .12, .012]), L.y, .008, .006, .25, { wob: 0 }); }
  // 팔레트 위판까지 감아 내린 랩 단 + 처진 비닐 자락
  { const pts = []; for (let i = 0; i <= 30; i++) { const a = i / 30 * 6.283; pts.push(Q([Math.cos(a) * 1.15, .1 + .05 * Math.sin(a * 3), -.25 + Math.sin(a) * 1.15])); } B.group({ k: .08, kg: .15 }); B.tube(pts, .08, { per: 1 }); B.group({ k: .02, kg: .1 }); for (const [x, z] of [[1.1, .5], [-1.15, -.3], [.3, -1.35]]) B.box(Frame.along(Q([x, .05, z]), [0, 1, 0], [x, 0, z]).rot(8, 0, 0), [.35, .16, .012], .01); }
  // ── 비닐을 찢고 나온 팔: 둘은 팔레트 앞 모서리를 움켜쥐고, 둘은 어깨에서 나와 앞 바닥을 짚고 당김
  for (const m of [-1, 1]) { const sh = Q([m * 1.02, .85, .45]), el = Q([m * 1.42, .55, .95]), wr = pp([m * .85, .36, 1.32]); A.arm(B, sh, el, wr, .18, { m: .9, kg: .12 }); tear(sh, V.sub(el, sh), .22); A.hand(B, HF(wr, P.d([0, -.25, 1]), P.d([0, 1, .2])), 1.05, { curl: [70, 78, 76, 82], spread: 6, thin: 1, vein: 0 }); }
  for (const m of [-1, 1]) { const f = m > 0 ? 0 : Math.PI, lf = Math.max(0, Math.sin(ph + f)) * .5 * rise, sh = Q([m * 1.05, 1.65, .3]), el = V.add(Q([m * 1.6, 1.3, 1.45]), [0, lf * .4, 0]), wr = [m * 1.45, .32 + lf, 2.3 + Math.cos(ph + f) * .4 * rise]; A.arm(B, sh, el, wr, .2, { m: .9, kg: .12 }); tear(sh, V.sub(el, sh), .25); A.hand(B, HF(wr, [m * .1, -.3, 1], [0, 1, .3]), 1.2, { curl: [18, 26, 22, 30], spread: 12, thin: .95, len: 1.1 }); }
  // 뒤: 찢고 나온 맨다리가 바닥을 민다
  { const h = Q([.55, .7, -1.5]), k = [.85, 1.25, -2.4], an = [.8, .5, -3.2]; A.leg(B, h, k, an, .22, { m: .85, front: [0, .6, -1], kg: .12 }); tear(h, V.sub(k, h), .28); A.foot(B, new Frame(an, [-1, 0, 0], [0, 1, 0], V.norm([0, -.35, -1])), .95, {}); }
  // 정수리에서 풀려 끌리는 랩 꼬리
  { const pts = []; const s0 = Q([-.4, 2.9, -.75]); for (let i = 0; i <= 22; i++) { const t = i / 22; pts.push(V.add(s0, [-.5 * t + .2 * Math.sin(t * 6), -t * 3.3 + .2 * Math.sin(t * 4), -1.0 * t - 1.0 * t * t])); } pts.forEach(q => { if (q[1] < .04) q[1] = .04; }); B.group({ k: .006, kg: .03 }); for (let i = 0; i < 22; i++) { const t = i / 22, d = V.norm(V.sub(pts[i + 1], pts[i])), u = V.norm([Math.sin(t * 5) * .8, .4, Math.cos(t * 4)]), s = V.norm(V.cross(d, u)); B.box(new Frame(V.lerp(pts[i], pts[i + 1], .5), s, d, V.cross(s, d)), [.26 * (1 - t * .4), V.len(V.sub(pts[i + 1], pts[i])) * .56, .012], .01, { k: .015 }); for (const q of [-1, 1]) B.groove(V.lerp(pts[i], pts[i + 1], .5), V.add(d, V.mul(s, .3 * q)), .004, .006, .1); } }
  return B;
} };
