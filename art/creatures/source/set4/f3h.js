// 시안4 3장 인간형 — 침수 인부: 장마철 배수 작업 중 실종된 하수도 관리원. 가슴 장화를 입은 채 물을 먹고 부풀었다. 깨진 헤드램프만 아직 붉게 켜져 있다.
const { V, Frame, Body } = require('./sculpt.js'), A = require('./anat.js');
module.exports = { id: 'f3h', name: '침수 인부', kind: '인간형 · 3장 하수도', H: 9.6, build(p = {}) {
  const B = new Body(), w = p.walk, S = w == null ? .35 : Math.sin(w * Math.PI * 2), I = o => new Frame(o, [1, 0, 0], [0, 1, 0], [0, 0, 1]), lean = p.lean ?? 16;
  // ---- 가슴 장화(다리): 헐렁한 고무 통, 무릎·발목에 접힌 주름, 장화 발
  for (const m of [-1, 1]) {
    const st = m * S, lift = Math.max(0, -st), h = [m * .52, 4.35, 0], k = [m * .6, 2.45 + lift * .35, .3 + st * .45 + lift * .35], an = [m * .55, .62 + lift * .55, -.1 + st * .8];
    B.group({ k: .14, kg: .25, amp: .012, freq: 2.5 });
    B.tube([h, V.lerp(h, k, .5), k, V.lerp(k, an, .55), an], [.64, .58, .5, .44, .4]);
    A.rings(B, [V.lerp(h, k, .78), V.lerp(k, an, .2)], 4, .03, .06, .75, { bow: .5, tilt: .3 });
    A.rings(B, [V.lerp(k, an, .7), an], 3, .03, .05, .6, { bow: .4, tilt: .25 });
    for (let i = 0; i < 3; i++) B.groove(V.add(V.lerp(h, k, .3 + i * .22), [m * .1, 0, .5]), V.norm([m, .35 * (i - 1), .2]), .025, .05, .55, { bow: .5, wob: .15, wf: 2 });
    // 장화 발: 두꺼운 고무 밑창, 발등 주름
    const fd = V.norm([m * .12, 0, 1]), F = new Frame(an, V.norm(V.cross([0, 1, 0], fd)), [0, 1, 0], fd); const fb = V.add(an, [0, -.42 - lift * .02, 0]);
    B.group({ k: .1, kg: .2, amp: .006, freq: 4 }); B.ell(F.at([0, -.18, .05]), [.42, .38, .5]); B.ell(F.at([0, -.32, .55]), [.36, .2, .42]);
    B.groove(F.p([0, -.15, .5]), F.d([0, 1, .6]), .02, .04, .5, { bow: .5 }); B.groove(F.p([0, -.12, .25]), F.d([0, 1, .3]), .02, .04, .5, { bow: .5 });
    B.group({ k: .03, kg: .05 }); B.box(new Frame(V.add(fb, F.d([0, .06, .3])), F.x, F.y, F.z), [.4, .07, .72], .06); for (let i = 0; i < 6; i++) B.groove(V.add(fb, F.d([0, -.02, -.25 + i * .19])), F.z, .02, .03, .45);
  }
  // ---- 장화 몸통: 허리까지 부푼 고무, 가슴판, 멜빵
  const BF = I([0, 5.2, .05]).rot(lean * .5, 0, 0);
  B.group({ k: .3, kg: .35, amp: .012, freq: 2.5 });
  B.ell(I([0, 4.45, 0]), [1.0, .62, .66]); B.ell(BF.at([0, .25, .12]), [1.08, .95, .92]); B.ell(BF.at([0, .95, .02]), [.98, .6, .74]);
  for (let i = 0; i < 4; i++) { const m = i % 2 ? 1 : -1; B.groove(BF.p([m * (.25 + .12 * i), -.62 - i * .05, .82]), V.norm([m * .35, 1, .2]), .018, .04, .55, { bow: -.5, wob: .2, wf: 2 }); } B.groove(BF.p([0, -.3, .98]), [0, 1, .2], .02, .05, .8, { bow: -.6, wob: .15, wf: 2 });
  for (const m of [-1, 1]) B.groove(BF.p([m * .95, .1, .1]), [0, 1, 0], .025, .05, .7, { bow: .2 });
  B.group({ k: .04, kg: .1 }); B.box(BF.at([0, 1.05, .74]).rot(-14, 0, 0), [.6, .36, .05], .05); B.box(BF.at([0, .98, .8]).rot(-14, 0, 0), [.32, .16, .03], .03); // 가슴판·주머니
  B.group({ k: .03, kg: .04 }); B.tube([BF.p([-1.0, 1.3, -.05]), BF.p([-.7, 1.42, .6]), BF.p([0, 1.42, .78]), BF.p([.7, 1.42, .6]), BF.p([1.0, 1.3, -.05]), BF.p([.6, 1.38, -.68]), BF.p([-.6, 1.38, -.68]), BF.p([-1.0, 1.3, -.05])], .055); // 윗단
  // ---- 작업복 웃옷 위의 부푼 몸
  const TF = I([0, 6.75, -.05]).rot(lean, 0, 0);
  B.group({ k: .22, kg: .12, amp: .01, freq: 3 });
  B.ell(TF.at([0, -.15, .02]), [1.0, .72, .66]); for (const m of [-1, 1]) B.ball(TF.p([m * .98, .22, -.05]), .38); B.ell(TF.at([0, .35, -.12]), [.82, .38, .5]);
  for (let i = 0; i < 6; i++) { const m = i % 2 ? 1 : -1; B.groove(TF.p([m * (.3 + i * .08), -.1 + .05 * i, .55]), V.norm([m * .4, 1, .3]), .02, .05, .5, { bow: .5 * m, wob: .2 }); }
  for (const m of [-1, 1]) B.groove(TF.p([m * .55, .45, -.1]), V.norm([m * .2, .3, 1]), .02, .05, .5, { bow: .4 });
  // 깃·단추
  B.group({ k: .03, kg: .05 }); for (const m of [-1, 1]) B.box(TF.at([m * .2, .62, .32]).rot(-30, m * 25, m * 30), [.2, .15, .03], .03); B.group({ k: .01, kg: .02 }); for (let i = 0; i < 2; i++) B.ball(TF.p([0, .4 - i * .3, .62 - i * .03]), .045);
  // 멜빵 + 고리
  for (const m of [-1, 1]) { A.strap(B, [BF.p([m * .45, 1.32, .76]), TF.p([m * .55, .15, .66]), TF.p([m * .72, .62, .25]), TF.p([m * .7, .55, -.5]), BF.p([m * .45, 1.25, -.68])], .07, .03, q => V.norm(V.sub(q, TF.p([0, -.2, 0])))); B.group({ k: .01, kg: .02 }); B.box(TF.at([m * .55, .1, .7]).rot(-20, 0, 0), [.1, .08, .025], .02); }
  // ---- 목·머리(부푼 얼굴, 앞으로 떨궈짐)
  A.neck(B, TF.p([0, .55, .05]), TF.p([0, 1.0, .45]), .36, { kg: .3 });
  B.group({ k: .2, kg: .3 }); B.ell(TF.at([0, .92, .45]), [.42, .25, .3]); // 이중턱 살
  const s = 1.48, HF = new Frame(TF.p([0, 1.5, .7]), [1, 0, 0], [0, 1, 0], [0, 0, 1]).rot(p.nod ?? 22, p.headYaw || 0, p.tilt ?? -10), hp = v => HF.p(V.mul(v, s));
  A.face(B, HF, s, { w: 1.14, gaunt: 0, jaw: p.jaw ?? 50, eyes: 'real', iris: .008, open: .72, eyeTilt: 9, gaze: [0, .012], lips: 1.6, mouthW: .82, age: .35, teeth: 0, ears: true, kg: .22 * s, vein: false });
  B.group({ k: .14, kg: .16 }); for (const m of [-1, 1]) { B.ell(HF.at(V.mul([m * .22, -.36, .1], s)), [.1 * s, .13 * s, .11 * s]); } // 부은 볼·눈밑 물주머니
  A.hair(B, [-1, 0, 1].map(i => [hp([i * .04, -.3, .22]), hp([i * .06, -.36, .36]), hp([i * .07, -.5, .4]), V.add(hp([i * .09, -.55, .38]), [i * .05, -.6 - .3 * Math.abs(i), .1])]), { r: [.03, .028, .02, .005] }); // 입에서 흘러나온 물풀
  // ---- 안전모: 비뚤어진 돔, 챙, 가운데 등줄, 헤드램프
  const HH = HF.at(V.mul([.02, .36, -.04], s)).rot(-10, 0, 8), hh = v => HH.p(V.mul(v, s));
  B.group({ k: .04, kg: .02, amp: .003, freq: 5 }); B.ell(HH, [.4 * s, .29 * s, .48 * s]); B.ell(HH.at(V.mul([0, -.05, .06], s)), [.52 * s, .03 * s, .64 * s]); B.ell(HH.at(V.mul([0, -.04, .36], s)), [.4 * s, .03 * s, .4 * s]); B.tube([hh([-.44, -.03, .1]), hh([-.3, -.02, .5]), hh([0, -.01, .68]), hh([.3, -.02, .5]), hh([.44, -.03, .1]), hh([.36, -.04, -.4]), hh([0, -.05, -.56]), hh([-.36, -.04, -.4]), hh([-.44, -.03, .1])], .025 * s, { k: .01 });
  B.ell(HH.at(V.mul([0, -.22, 0], s)), [.34 * s, .2 * s, .42 * s], { op: 1, k: .02 });
  B.tube([hh([0, .12, .44]), hh([0, .27, .1]), hh([0, .26, -.2]), hh([0, .1, -.46])], .045 * s, { k: .03 }); for (const m of [-1, 1]) B.tube([hh([m * .18, .06, .4]), hh([m * .2, .2, .08]), hh([m * .2, .18, -.25]), hh([m * .17, .02, -.44])], .025 * s, { k: .03 });
  B.groove(hh([-.2, .14, .25]), HH.d([1, .2, .6]), .006 * s, .02 * s, .25 * s, { bow: 1, wob: .4, wf: 9 }); // 금 간 모
  // 램프 몸통·고정 띠
  const LF = Frame.along(hh([0, .0, .42]), V.norm([0, .1, 1]), [0, 1, 0]), lp = v => LF.p(V.mul(v, s)); B.group({ k: .02, kg: .04 }); B.box(HH.at(V.mul([0, .0, .44], s)), [.14 * s, .1 * s, .05 * s], .03); B.ell(new Frame(lp([0, .12, 0]), LF.x, LF.y, LF.z), [.13 * s, .11 * s, .13 * s]); B.tube([lp([-.13, .2, 0]), lp([0, .21, .135]), lp([.13, .2, 0]), lp([0, .21, -.135]), lp([-.13, .2, 0])], .018 * s, { per: 2 }); B.tube([lp([.12, .21, .03]), lp([.15, .3, .1]), lp([.1, .34, .18])], .012 * s); // 휜 가드
  // 깨진 렌즈 — 유일한 붉은 빛
  B.group({ mat: 1, k: .006 }); B.ell(new Frame(lp([0, .225, 0]), LF.x, LF.y, LF.z), [.105 * s, .04 * s, .105 * s]); for (let i = 0; i < 4; i++) B.groove(lp([.02, .26, .01]), V.sub(LF.p([Math.cos(i * 1.4), 0, Math.sin(i * 1.4)]), LF.o), .004 * s, .012 * s, .1 * s, { wob: .5, wf: 20 });
  // 전선: 모자 뒤 → 등 → 허리 배터리
  B.group({ k: .02, kg: .03 }); B.tube([hh([.1, .05, .5]), hh([.32, .08, .2]), hh([.34, .02, -.3]), TF.p([.4, .7, -.75]), TF.p([.55, -.3, -.78]), BF.p([.6, -.3, -.75])], .035); B.box(I(BF.p([.5, -.45, -.72])).rot(0, 20, 0), [.24, .17, .1], .04);
  // 물풀이 챙과 어깨에서 늘어짐
  const R = []; for (let i = 0; i < 9; i++) { const a = -2.9 + i * .33, j = Math.sin(i * 4.7), base = hh([Math.cos(a) * .5, -.06, Math.sin(a) * .6]); R.push([base, V.add(base, [j * .05, -.4, .02]), V.add(base, [j * .1, -.8 - .4 * Math.abs(j), .05]), V.add(base, [j * .15, -1.1 - .6 * Math.abs(j), .02])]); }
  for (let i = 0; i < 8; i++) { const m = i % 2 ? 1 : -1, j = Math.sin(i * 3.3), base = TF.p([m * (1.05 + .1 * j), .55, -.2 + i * .05]); R.push([base, V.add(base, [m * .05, -.5, .1]), V.add(base, [m * .1 + j * .1, -1.1, .1]), V.add(base, [m * .1 + j * .2, -1.6 - .5 * Math.abs(j), .05])]); }
  A.hair(B, R, { r: [.03, .025, .02, .005] });
  // ---- 오른팔(-x): 갈고리 장대를 짚음
  const rsh = TF.p([-1.05, .22, -.02]), rel = [-1.62, 5.55, .45 - S * .1], rwr = [-1.5, 4.75, 1.35];
  A.arm(B, rsh, rel, rwr, .27, { m: 1.12, amp: .008 }); B.group({ k: .1, kg: .16, amp: .01, freq: 3 }); B.tube([rsh, V.lerp(rsh, rel, .6)], [.44, .38]); A.rings(B, [V.lerp(rsh, rel, .55), V.lerp(rsh, rel, .75)], 3, .03, .06, .5, { bow: .3 }); B.tube([V.lerp(rsh, rel, .62), V.lerp(rsh, rel, .74)], [.41, .39]);
  A.hand(B, new Frame(rwr, [0, 1, 0], V.norm([.12, 0, 1]), V.norm([-1, 0, .12])), 1.35, { curl: [78, 82, 85, 88], spread: 2, thin: 1.4, len: 1.0 });
  // 장대: 손을 지나 바닥과 머리 위로, 꼭대기 갈고리
  const g = V.add(rwr, [.2, 0, .5]), pd = V.norm([.06, 1, -.12]), top = V.add(g, V.mul(pd, 4.3)), bot = V.add(g, V.mul(pd, -g[1] / pd[1] + .02));
  B.group({ k: .01, kg: .02, amp: .002, freq: 8 }); B.tube([bot, g, top], [.07, .075, .065]); for (let i = 0; i < 4; i++) B.groove(V.lerp(bot, top, .12 + i * .25), pd, .02, .03, .2);
  { // 쇠 머리: 소켓 + 곧은 창끝 + 뒤로 휜 갈고리(녹슨 홈)
    const Q = Frame.along(top, pd, [0, 0, 1]), q = v => Q.p(v); B.group({ k: .02, kg: .03, amp: .004, freq: 9 });
    B.cone(q([0, -.35, 0]), q([0, .15, 0]), .085, .1); for (let i = 0; i < 3; i++) B.groove(q([0, -.25 + i * .14, 0]), Q.y, .012, .02, .15);
    B.cone(q([0, .15, 0]), q([0, .95, 0]), .085, .008);
    B.tube([q([0, .1, .05]), q([0, .2, .32]), q([0, .5, .55]), q([0, .85, .5]), q([0, 1.0, .3]), q([0, .92, .14])], [.07, .07, .06, .05, .035, .008]);
  }
  // 장대 위 감긴 물풀
  A.hair(B, [0, 1, 2].map(i => { const b = V.add(top, V.mul(pd, -.2 - i * .15)); return [b, V.add(b, [.1 * Math.sin(i), -.4, .1]), V.add(b, [.15 * Math.sin(i * 2), -.9 - .1 * i, .05])]; }), { r: [.03, .02, .005] });
  // ---- 왼팔(+x): 부어 늘어지고 손끝에서 물풀이 흐름
  const rc = p.reach ?? 0, lsh = TF.p([1.05, .22, -.02]), lel = V.lerp([1.6, 5.4, -.15 + S * .15], [1.45, 6.3, 1.1], rc), lwr = V.lerp([1.55, 4.0, .35 + S * .25], [1.25, 6.55, 2.45], rc);
  A.arm(B, lsh, lel, lwr, .27, { m: 1.12, amp: .008 }); B.group({ k: .1, kg: .16, amp: .01, freq: 3 }); B.tube([lsh, V.lerp(lsh, lel, .6)], [.44, .38]); A.rings(B, [V.lerp(lsh, lel, .55), V.lerp(lsh, lel, .75)], 3, .03, .06, .5, { bow: .3 }); B.tube([V.lerp(lsh, lel, .62), V.lerp(lsh, lel, .74)], [.41, .39]);
  A.hand(B, rc > .5 ? new Frame(lwr, [-1, 0, 0], V.norm([-.1, .05, 1]), [0, 1, 0]) : new Frame(lwr, [0, 0, 1], V.norm([.04, -1, .12]), [1, 0, 0]), 1.4, { curl: rc > .5 ? [30, 36, 42, 50]: [22, 28, 32, 40], spread: 9, thin: 1.45, len: 1.0 });
  A.hair(B, [0, 1, 2, 3].map(i => { const b = V.add(lwr, [-.15 + i * .1, -1.1, .3 + i * .05]); return [b, V.add(b, [.05, -.5, .05]), V.add(b, [.1 * Math.sin(i * 3), -1.1 - .3 * i, .1])]; }), { r: [.025, .018, .004] });
  // 붕 뜬 손목 시계·작업 장갑 대신 부풀어 갈라진 살
  B.group({ k: .02, kg: .04 }); B.tube([V.lerp(lel, lwr, .78), V.lerp(lel, lwr, .84)], .24);
  return B;
} };
