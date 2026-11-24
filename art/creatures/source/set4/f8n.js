// 시안4 8장 비인간형 — 큰 인형: 놀이방 구석의 사람만 한 자기(磁器) 구체관절 인형. 길쭉한 머리가 움푹 꺼져 금이 갔고, 관자놀이 한 조각이 떨어져 속이 비어 보인다.
// 한 눈은 빠진 검은 구멍, 남은 유리눈은 깊이 박혀 깜박이지 않는다. 팔다리가 길어 팔꿈치·무릎을 몸 위로 꺾고, 몸을 바닥에 붙인 채 거미처럼 기어 온다.
// 관절마다 공과 틈이 있고, 틈 사이로 팽팽한 고무줄이 보인다. 가발은 엉겨 붙어 듬성듬성 빠졌고 정수리 구멍이 드러났다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'f8n', name: '큰 인형', kind: '비인간형 · 8장 폐유치원', H: 4.6, build(p = {}) {
  const B = new Body(), w = p.walk ?? 0, I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]), L = V.lerp, ph = q => Math.sin((w + q) * Math.PI * 2);
  const PC = 0;
  // 구체 관절 마디: 양 끝이 오목하게 파여 관절 공과 틈이 생긴다. 틈 사이 고무줄
  const seg = (a, b, ra, rb, o = {}) => { const d = V.norm(V.sub(b, a)), gap = o.gap ?? 1; B.group({ mat: PC, k: .05, kg: .01 }); B.cone(V.add(a, V.mul(d, ra * 1.05 * gap)), V.sub(b, V.mul(d, rb * 1.05 * gap)), ra, rb); B.ball(V.add(a, V.mul(d, ra * .45)), ra * .9, { op: 1, k: .02 }); B.ball(V.sub(b, V.mul(d, rb * .45)), rb * .9, { op: 1, k: .02 }); B.groove(L(a, b, .5), d, .01, .012, ra * 1.4, { wob: 0 }); if (o.cr) { const sd = V.norm(V.cross(d, [0, 1, 0])); let q = L(a, b, .3); const pts = [q]; for (let i = 0; i < 6; i++) { q = V.add(q, V.add(V.mul(d, V.len(V.sub(b, a)) * .07), V.mul(sd, (i % 2 ? 1 : -1) * ra * .25))); pts.push(V.add(q, V.mul(sd, ra * .0))); } B.tube(pts.map(z => V.add(z, [0, ra * .9, 0])), .016, { op: 1, k: .006, per: 1 }); }
    B.group({ k: .008, kg: .01 }); B.tube([V.add(a, V.mul(d, -ra * .2)), V.add(a, V.mul(d, ra * 1.3)), V.sub(b, V.mul(d, rb * 1.3)), V.add(b, V.mul(d, rb * .2))], .028, { per: 1 }); };
  const joint = (c, r) => { B.group({ mat: PC, k: .02, kg: .0 }); B.ball(c, r * .78); B.groove(c, [0, 1, 0], r * .05, r * .05, r, { wob: 0 }); };
  // ---- 몸통: 가슴이 엉덩이보다 낮다(바닥에 붙인 몸)
  const pel = [0, 2.0, -1.75], chest = [0, 1.55, .3], ys = V.norm(V.sub(chest, pel)), zs = V.norm(V.cross([1, 0, 0], ys));
  const TF = new Frame(chest, [1, 0, 0], ys, zs);
  B.group({ mat: PC, k: .2, kg: .02 }); B.ell(TF.at([0, .05, 0]), [.66, .6, .46]); B.ell(new Frame(L(pel, chest, .08), [1, 0, 0], ys, zs), [.62, .42, .5]); B.ell(new Frame(L(pel, chest, .48), [1, 0, 0], ys, zs), [.36, .45, .32]);
  joint(L(pel, chest, .7), .42);
  // 원피스: 몸통을 덮고 배 아래로 처져 바닥을 쓴다
  B.group({ k: .12, kg: .06, amp: .006, freq: 5 }); B.ell(TF.at([0, .1, .06]), [.74, .66, .56]); for (const m of [-1, 1]) B.ell(TF.at([m * .66, .45, .05]), [.3, .26, .28]);
  B.ell(new Frame(L(pel, chest, .22), [1, 0, 0], ys, zs), [.78, .66, .64]);
  { const hem = []; for (let i = 0; i <= 30; i++) { const a = i / 30 * 6.283, x = Math.cos(a) * 1.0, zz = Math.sin(a) * 1.35; hem.push([x * (1 + .05 * Math.sin(i * 3)), .14 + .12 * Math.abs(Math.sin(i * 2.2)) + (zz < 0 ? .55 : 0), L(pel, chest, .32)[2] + zz]); }
    for (let i = 0; i < 30; i++) { const top = V.add(L(pel, chest, .1 + (i % 6) * .1), [Math.cos(i / 30 * 6.283) * .5, -.2, 0]); B.tube([top, L(top, hem[i], .5).map((v, j) => v + [0, -.05, 0][j]), hem[i]], [.11, .14, .1], { k: .15 }); }
    for (let i = 0; i < 6; i++) B.groove(V.add(hem[i * 5], [0, .35, 0]), [0, 1, 0], .02, .04, .45, { wob: .3 });
    B.group({ k: .02, kg: .04 }); const fr = []; for (let i = 0; i <= 120; i++) { const u = i / 120 * 30, j = Math.min(29, Math.floor(u)), c = L(hem[j], hem[j + 1], u - j); if (i > 40 && i < 52) { B.tube(fr, .04, { per: 1 }); fr.length = 0; continue; } fr.push(V.add(c, [0, .07 * Math.sin(i * 1.9), 0])); } B.tube(fr, .04, { per: 1 });
    B.group({ k: .03, kg: .04, amp: .004, freq: 6 }); const bc = V.add(L(pel, chest, .3), [0, .58, 0]); B.ball(bc, .11); for (const m of [-1, 1]) B.ell(new Frame(V.add(bc, [m * .28, .02, -.05]), V.norm([1, 0, m * .3]), V.norm([m * .3, 0, -1]), [0, 1, 0]), [.28, .15, .07]); B.tube([bc, V.add(bc, [.15, -.4, -.4]), V.add(bc, [.3, -1.2, -.9]), [.4, .06, -2.6]], [.06, .06, .05, .045]);
    B.group({ k: .02, kg: .03 }); for (let i = 0; i < 14; i++) { const a = (i / 13 - .5) * 3.4, c = TF.p([Math.sin(a) * .5, .6, Math.cos(a) * .34]); B.ell(new Frame(c, V.norm([Math.cos(a), 0, -Math.sin(a)]), V.norm([0, .3, 1]), V.norm([Math.sin(a), -1, Math.cos(a) * .3])), [.12, .16, .03]); } }
  // ---- 팔: 길다. 팔꿈치를 몸보다 높이 바깥으로 꺾고 손을 멀리 앞으로 짚는다. 오른팔(−x) 팔꿈치는 빠져 고무줄만 늘어남
  for (const m of [-1, 1]) {
    const q = ph(m > 0 ? 0 : .5), lift = Math.max(0, q) * .55;
    const s = TF.p([m * .74, .42, .05]), e = [m * 2.05, 2.55 + lift * .4, .85 + q * .25], wr = [m * 1.75, .3 + lift, 2.75 + q * .5];
    joint(s, .32); seg(s, e, .22, .19, { cr: m > 0 ? 1 : 0 });
    if (m < 0) { const e2 = V.add(e, [-.08, -.45, .22]); joint(e, .22); B.group({ k: .006, kg: .01 }); B.tube([V.add(e, [0, -.1, .05]), L(e, e2, .5).map((v, i) => v + [.04, -.02, 0][i]), V.add(e2, [0, .1, -.05])], .03, { per: 3 }); joint(e2, .2); seg(e2, wr, .17, .13, { cr: 1 }); }
    else { joint(e, .22); seg(e, wr, .17, .13); }
    joint(wr, .16);
    const fy = V.norm([m * .15, -.1, 1]), g0 = B.groups.length; A.hand(B, new Frame(wr, V.norm(V.cross(fy, [0, 1, 0])).map(v => v * (m > 0 ? 1 : -1)), fy, [0, 1, 0]), 1.45, { curl: [22, 14, 18, 26], spread: 10, thin: .95, len: 1.2, vein: 0 }); for (let i = g0; i < B.groups.length; i++) B.groups[i].mat = PC;
  }
  // ---- 다리: 무릎을 몸 위로 세운 거미 자세. 발바닥을 뒤쪽 바닥에 붙인다
  for (const m of [-1, 1]) {
    const q = ph(m > 0 ? .5 : 0), lift = Math.max(0, q) * .4;
    const h = V.add(pel, [m * .48, -.15, -.05]), k = [m * 1.55, 2.35 + lift * .4, -1.25 + q * .3], an = [m * 1.35, .42 + lift * .6, -2.85 + q * .45];
    joint(h, .36); seg(h, k, .28, .22, { cr: m < 0 ? 1 : 0 }); joint(k, .26); seg(k, an, .2, .14); joint(an, .17);
    B.group({ mat: PC, k: .08, kg: .01 }); const fz = V.norm([m * .2, -.15, -1]); B.tube([V.add(an, [0, -.08, 0]), V.add(V.add(an, V.mul(fz, .3)), [0, -.25, 0]), V.add(V.add(an, V.mul(fz, .62)), [0, -.32, 0])], [.13, .13, .07]); B.ell(Frame.along(V.add(V.add(an, V.mul(fz, .32)), [0, -.24, 0]), fz), [.15, .36, .1]);
  }
  // ---- 머리: 길쭉한 자기 머리를 바닥 가까이 내밀고 아래에서 올려다본다
  const R = 1.12, HF = I([.05, 2.15, 2.0]).rot(p.nod ?? -16, p.headYaw ?? 0, p.tilt ?? 28), h = v => HF.p(v);
  B.group({ k: .06, kg: .02 }); B.cone(TF.p([0, .6, 0]), h([0, -1.0, -.35]), .2, .18); B.group({ k: .008 }); B.tube([TF.p([0, .6, 0]), h([0, -1.1, -.3])], .035);
  joint(h([0, -1.02, -.3]), .3);
  B.group({ mat: PC, k: .22, kg: .02 }); const head = B.groups.length - 1;
  B.ell(HF.at([0, .12, -.08]), [R * .78, R * 1.08, R * .86]); B.ell(HF.at([0, -.5, .3]), [.56, .58, .58]); for (const m of [-1, 1]) B.ell(HF.at([m * .34, -.44, .5]), [.24, .24, .26]); B.ell(HF.at([0, -.9, .5]), [.18, .14, .16], { k: .18 });
  B.ell(HF.at([0, -.34, .96]), [.05, .09, .06], { k: .06 }); for (const m of [-1, 1]) B.ball(h([m * .03, -.42, .97]), .012, { op: 1, k: .01 });
  // 깊은 눈구멍
  for (const m of [-1, 1]) B.ell(new Frame(h([m * .3, -.02, .86]), HF.x, HF.y, HF.z).rot(0, m * 16, 0), [.2, .17, .26], { op: 1, k: .05 });
  // 이마가 움푹 꺼짐(찍힌 자국) + 왼쪽(−x) 관자놀이 조각이 떨어져 나감 → 속 빈 껍질
  B.ell(new Frame(h([.18, .62, .86]), HF.x, HF.y, HF.z), [.26, .2, .12], { op: 1, k: .08 });
    B.ell(HF.at([0, .1, -.08]), [R * .68, R * .98, R * .76], { op: 1, k: .01 }); // 속 비움 (두께가 깨진 가장자리에 드러남)
  // 금: 찍힌 자국에서 방사형 + 깨진 구멍에서
  const sc = (u, v) => h([R * .78 * Math.cos(v) * Math.sin(u), .12 + R * 1.08 * Math.sin(v), -.08 + R * .86 * Math.cos(v) * Math.cos(u)]);
  const crackS = (u0, v0, du, dv, n, ph0) => { const pts = []; let u = u0, v = v0; for (let i = 0; i <= n; i++) { pts.push(sc(u, v)); const z = (i % 2 ? 1 : -1) * (.5 + .5 * Math.abs(Math.sin(i * 7.7 + ph0))); u += du - dv * z * .7; v += dv + du * z * .7; if (i === Math.floor(n / 2)) { const br = []; let bu = u, bv = v; for (let j = 0; j < 4; j++) { br.push(sc(bu, bv)); bu += dv * .9 + (j % 2 ? .02 : -.02); bv -= du * .9; } B.tube(br, .016, { op: 1, k: .006, per: 1 }); } } B.tube(pts, .021, { op: 1, k: .006, per: 1 }); };
  B.g = B.groups[head]; for (const [u, v, rr] of [[-.55, .5, .26], [-.75, .38, .2], [-.42, .68, .18], [-.7, .62, .15], [-.38, .4, .12], [-.9, .5, .14], [-.3, .55, .07], [-.48, .3, .08], [-.62, .78, .07], [-.85, .3, .08], [-.6, .25, .06], [-.52, .8, .06]]) B.ell(new Frame(sc(u, v), HF.x, HF.y, HF.z).rot(v * -40, u * 57, u * 80), [rr, rr * .8, .28], { op: 1, k: .006 }); // 떨어져 나간 조각
  for (let i = 0; i < 7; i++) { const a = i / 7 * 6.283 + .3; crackS(.2 + Math.cos(a) * .2, .55 + Math.sin(a) * .16, Math.cos(a) * .07, Math.sin(a) * .07, 6 + (i % 3), i); }
  crackS(-.62, .2, .1, -.05, 8, 9); crackS(-.7, -.05, .06, -.1, 8, 10); crackS(-.55, .55, .1, .05, 6, 11); crackS(.5, -.2, .03, -.1, 7, 12);
  // 빠진 눈에서 흘러내린 때 자국
  for (const [x0, l] of [[-.3, .65], [-.26, .42], [-.36, .5]]) B.tube([h([x0, -.17, .9]), h([x0 + .02, -.17 - l * .5, .93 - l * .1]), h([x0 + .01, -.17 - l, .86 - l * .25])], [.022, .016, .006], { op: 1, k: .01, per: 3 });
  // 입: 살짝 벌어진 칠한 입술, 작은 이
  B.ell(HF.at([0, -.66, .93]), [.08, .04, .1], { op: 1, k: .02 });
  B.group({ mat: 2, k: .01 }); B.ell(HF.at([0, -.66, .86]), [.08, .045, .06]);
  B.group({ k: .02, kg: .03 }); B.tube([h([-.1, -.645, .9]), h([-.045, -.62, .945]), h([0, -.63, .955]), h([.045, -.62, .945]), h([.1, -.645, .9])], [.01, .024, .018, .024, .01], { per: 3 }); B.tube([h([-.075, -.675, .91]), h([0, -.71, .945]), h([.075, -.675, .91])], [.01, .028, .01], { per: 3 });
  B.group({ mat: 5, k: .004 }); for (let i = 0; i < 4; i++) B.box(new Frame(h([-.045 + i * .03, -.645, .93]), HF.x, HF.y, HF.z), [.011, .018, .01], .006);
  // 남은 유리눈(+x): 작고 깊이 박혀 정면을 고정 응시. 빠진 쪽은 깊은 어둠
  { const e = new Frame(h([.3, -.02, .72]), HF.x, HF.y, HF.z).rot(0, 10, 0); B.group({ mat: 6, k: .01 }); B.ball(e.o, .155); B.group({ k: .004 }); B.ball(e.p([0, 0, .1]), .075); B.group({ k: .004 }); B.tube(Array.from({ length: 17 }, (_, i) => e.p([Math.cos(i / 16 * 6.283) * .1, Math.sin(i / 16 * 6.283) * .1, .135])), .01, { per: 1 }); for (let i = 0; i < 14; i++) { const a = i / 14 * 6.283; B.groove(e.p([Math.cos(a) * .055, Math.sin(a) * .055, .14]), e.d([-Math.sin(a), Math.cos(a), 0]), .005, .005, .035, { wob: 0 }); } B.group({ mat: 2, k: .003 }); B.ball(e.p([0, 0, .15]), .025); B.group({ mat: 5, k: .001 }); B.ball(e.p([.03, .035, .15]), .012); }
  { const e = new Frame(h([-.3, -.02, .72]), HF.x, HF.y, HF.z); B.group({ mat: 2, k: .03 }); B.ball(e.p([0, 0, -.06]), .22); }
  B.group({ mat: 2, k: .03 }); B.ell(HF.at([0, .1, -.08]), [R * .62, R * .9, R * .68]); // 껍질 안 어둠
  // 정수리 구멍(자기 머리의 열린 정수리): 가발이 벗겨져 드러남
  B.g = B.groups[head]; B.ell(new Frame(h([-.15, 1.18, -.2]), HF.x, HF.y, HF.z).rot(-20, 0, 10), [.36, .2, .42], { op: 1, k: .02 });
  // 가발: 엉겨 붙은 굵은 타래가 두피에 들러붙어 흘러내리고, 바닥에 끌린다. 듬성듬성 빠짐
  { const R2 = [], clumps = [];
    for (let i = 0; i < 26; i++) { const u = -2.6 + (i % 13) / 12 * 5.2 + (i > 12 ? .2 : 0), v = i > 12 ? .55 : .95; if (Math.abs(u + .3) < .45 && v > .9) continue; if (u < -1.6 && u > -2.3) continue; if (u > -1.15 && u < -.1) continue; clumps.push([u, v, i]); }
    for (const [u, v, i] of clumps) { const j = Math.sin(i * 12.9898), r0 = sc(u, v), r1 = sc(u * 1.05, v - .45), r2 = sc(u * 1.08, Math.max(-.3, v - .95)), out = V.norm(V.sub(r2, h([0, .1, -.08]))), r3 = V.add(r2, V.add(V.mul(out, .1), [0, -.4, 0])); const end = [r3[0] + j * .2, .06, r3[2] - .4 - .4 * Math.abs(j)]; if (Math.abs(u) < .9 && Math.cos(u) > .3 && v < .7) continue; for (let k = 0; k < 3; k++) { const o = [Math.sin(i + k * 2.1) * .04, 0, Math.cos(i + k * 2.1) * .04]; R2.push([V.add(r0, o), V.add(r1, o), V.add(r2, o), V.add(r3, o), V.add(L(r3, end, .6), [k * .03, .02, j * .1]), V.add(end, [k * .05, 0, k * .04])]); } }
    B.group({ k: .045, kg: .03, amp: .004, freq: 12 }); for (const q of R2) B.tube(q.map(z => [z[0], Math.max(.05, z[1]), z[2]]), [.05, .05, .05, .045, .04, .015], { per: 3 });
    // 앞머리: 이마에 엉겨 붙은 몇 가닥
    for (let i = 0; i < 5; i++) { const u = .15 + i * .14; B.tube([sc(u, .95), sc(u + .03, .75), sc(u + .06 + .03 * Math.sin(i), .5)], [.05, .045, .015], { per: 3 }); } }
  return B;
} };
