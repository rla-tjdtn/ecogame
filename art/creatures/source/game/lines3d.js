// 시안 흰 선을 3D 로 그대로: 시안 렌더러로 16방향 선 그림을 찍고, 선 픽셀마다 같은 셰이더로 원래 곡면 위 3D 점을 구해(linepts.js)
// 표면에 붙은 아주 작은 흰 조각(점)을 촘촘히 박아 선을 만든다. 몸과 같은 뼈·웨이트(가장 가까운 몸 정점의 것)로 움직인다.
// 방향마다 생기는 외곽선(옆으로 누운 면)은 빼고(바깥 테두리는 게임의 흰 윤곽선이 그린다), 몸에 새겨진 선만 남는다.
//   node lines3d.js k4h1 ...  (rig.js 다음) → out/mesh/<id>.glb (Body + Lines…) + _anim.json 의 L(미리보기)
const fs = require('fs'), path = require('path');
const { PNG } = require('pngjs');
const { CFG } = require('./bake.js');
const { writeGLB } = require('./glb.js');
const { linePoints } = require('./linepts.js');
const { sdfGrid } = require('./sdfgrid.js');
const { surfaceNets } = require('./mesher.js');
const { MeshoptSimplifier: SIMP } = require('meshoptimizer');
const SRC = path.join(__dirname, '..');
const META = Object.assign({}, require(path.join(SRC, 'set1/meta.js')), require(path.join(SRC, 'set2/meta2.js')), require(path.join(SRC, 'set3/meta3.js')), require(path.join(SRC, 'set4/meta4.js')));
const PW = 1280, PH = 2048, COLS = 4;
const VIEWS = [];
for (let k = 0; k < 8; k++) VIEWS.push([k * 45, 8]);
for (let k = 0; k < 4; k++) VIEWS.push([k * 90 + 45, 42]);
for (let k = 0; k < 4; k++) VIEWS.push([k * 90, -30]);
const V = { sub: (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]], add: (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]], mul: (a, k) => [a[0] * k, a[1] * k, a[2] * k], dot: (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2], cross: (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]] };
const norm = a => { const l = Math.hypot(...a) || 1; return a.map(x => x / l); };
const G = v => [-v[0], v[1], -v[2]];
const CELL = +(process.env.CELL || .015), DOT = +(process.env.DOT || .0075), LIFT = .006, MAXTRI = 78000; // (점 간격·반지름(스터드), 선 삼각형 한도: 부품 4개)

(async () => { await SIMP.ready;
for (const id of process.argv.slice(2)) {
  const c = CFG[id], A = JSON.parse(fs.readFileSync(path.join(__dirname, 'out/mesh', id + '_anim.json'), 'utf8'));
  const setDir = path.join(SRC, path.dirname(c.mod)), C = require(path.join(SRC, c.mod + '.js')), { render: render0 } = require(path.join(setDir, 'sculpt.js')), REUSE = !!process.env.REUSE, render = REUSE ? () => {} : render0; // (REUSE=1: 지난번 그림·광선 결과를 다시 써서 거르기 값만 빨리 바꿔 본다)
  const m = META[path.basename(c.mod)] || {}, base = { ...(m.hero || (m.poses && m.poses[0] && m.poses[0][1]) || {}) }; const PK = c.phase || 'walk'; delete base[PK];
  const restP = { ...base, ...c.walk, [PK]: c.phaseAmp ? (c.phaseBase || 0) : 0 };
  // 얼굴 자리: 디자인이 얼굴·머리를 만들 때 부르는 anat.face / anat.head 의 틀(가운데·크기)을 기록
  const AN = require(path.join(setDir, 'anat.js')), faces = [];
  for (const fn of ['face', 'head']) if (typeof AN[fn] === 'function' && !AN[fn].__rec) { const orig = AN[fn]; AN[fn] = function (B, F, sz, ...rest) { (AN.__faces || []).push({ o: F && F.o, z: F && F.z, s: typeof sz === 'number' ? sz : 1 }); return orig.call(this, B, F, sz, ...rest); }; AN[fn].__rec = true; }
  AN.__faces = faces;
  const b = C.build(restP).data();
  AN.__faces = null;
  const nV = A.P.length / 3, P = [];
  for (let i = 0; i < nV; i++) P.push(G([A.P[i * 3], A.P[i * 3 + 1], A.P[i * 3 + 2]]));
  let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9]; for (const p of P) for (let a = 0; a < 3; a++) { mn[a] = Math.min(mn[a], p[a]); mx[a] = Math.max(mx[a], p[a]); }
  const target = mn.map((v, a) => (v + mx[a]) / 2), Rxz = Math.hypot(mx[0] - mn[0], mx[2] - mn[2]) / 2;
  const scale = Math.min(PW * .47 / Rxz, PH * .46 / Math.hypot(mx[1] - mn[1], Rxz));
  // 1) 시안 선 그림(한 줄 = 4방향)
  const cams = VIEWS.map(([yaw, pitch]) => { const y = yaw * Math.PI / 180, pt = pitch * Math.PI / 180, D = [Math.sin(y) * Math.cos(pt), Math.sin(pt), Math.cos(y) * Math.cos(pt)], F = D.map(v => -v), R = norm(V.cross(F, [0, 1, 0])), U = V.cross(R, F); return { eye: target.map((v, a) => v + D[a] * 40), R, U, F, scale }; });
  const pix = [];
  for (let row = 0; row < (process.env.NODOTS ? 0 : Math.ceil(VIEWS.length / COLS)); row++) { // (NODOTS=1: 점 선 건너뛰기 — texbake.js 가 시안 그림을 텍스처로 입힌다)
    const panels = VIEWS.slice(row * COLS, row * COLS + COLS).map(([yaw, pitch], col) => ({ x: col * PW, y: 0, w: PW, h: PH, body: 0, yaw, pitch, scale, target, lw: 1.3, ss: 2, glow: 0, fill: 0, line: 1, border: 0 }));
    const png = path.join(__dirname, 'out/mesh', id + '_l3d' + row + '.png');
    render({ W: COLS * PW, H: PH, bg: '#000', bodies: [b], panels }, png);
    const img = PNG.sync.read(fs.readFileSync(png));
    for (let col = 0; col < panels.length; col++) {
      const k = row * COLS + col;
      for (let y = 0; y < PH; y++) for (let x = 0; x < PW; x++) {
        const o = (y * img.width + col * PW + x) * 4, l = Math.max(img.data[o], img.data[o + 1], img.data[o + 2]);
        if (l > +(process.env.LUM || 150)) pix.push(x + .5 - PW / 2, PH / 2 - (y + .5), k);
      }
    }
  }
  // 1b) 얼굴 근접: 얼굴 가운데를 3배쯤 크게 14방향(앞쪽 반구)에서 → 얼굴의 가는 선(붕대·눈·입·주름)을 많이·정확히
  const fc = faces.length ? faces.reduce((a, f) => (a && a.s >= f.s ? a : f), null) : null;
  const H0 = mx[1] - mn[1];
  const faceC = fc && fc.o ? fc.o : [target[0], mx[1] - H0 * .12, target[2]], faceR = fc ? Math.max(.25, fc.s * .45) : H0 * .1; // (anat 얼굴 크기 1 ≈ 얼굴 반지름 0.45)
  const FW = 1280, fScale = FW * .45 / faceR, faceViews = [];
  // 얼굴이 보는 쪽(틀의 z)을 가운데로 앞쪽 반구
  const fz = fc && fc.z ? norm(fc.z) : [0, 0, 1], yaw0 = Math.atan2(fz[0], fz[2]) * 180 / Math.PI, pitch0 = Math.asin(Math.max(-1, Math.min(1, fz[1]))) * 180 / Math.PI;
  for (const pt of [8, -18]) for (const yw of [-60, -40, -20, 0, 20, 40, 60]) faceViews.push([yaw0 + yw, Math.max(-80, Math.min(80, pitch0 + pt)), fScale, 1]);
  // 1c) 머리 전체(머리카락·뿔·목 둘레, 반지름 HEADK·faceR): 중간 배율로 빙 둘러 12방향 → 머리 줄무늬 같은 가는 선도 끊기지 않게
  const HR = faceR * +(process.env.HEADK || 2.6), hScale = FW * .45 / HR;
  for (const pt of [25, 0, -15]) for (let yw = 0; yw < 360; yw += 45) faceViews.push([yaw0 + yw + (pt === 0 ? 22 : 0), Math.max(-80, Math.min(80, pitch0 + pt)), hScale, 2]);
  const nBody = cams.length;
  for (const [yaw, pitch, sc] of faceViews) { const y = yaw * Math.PI / 180, pt = pitch * Math.PI / 180, D = [Math.sin(y) * Math.cos(pt), Math.sin(pt), Math.cos(y) * Math.cos(pt)], F = D.map(v => -v), Rr = norm(V.cross(F, [0, 1, 0])), U = V.cross(Rr, F); cams.push({ eye: faceC.map((v, a) => v + D[a] * 40), R: Rr, U, F, scale: sc }); }
  for (let row = 0; row < (process.env.NODOTS ? 0 : Math.ceil(faceViews.length / COLS)); row++) {
    const fvs = faceViews.slice(row * COLS, row * COLS + COLS);
    const panels = fvs.map(([yaw, pitch, sc], col) => ({ x: col * FW, y: 0, w: FW, h: FW, body: 0, yaw, pitch, scale: sc, target: faceC, lw: 1.3, ss: 2, glow: 0, fill: 0, line: 1, border: 0 }));
    const png = path.join(__dirname, 'out/mesh', id + '_l3f' + row + '.png');
    render({ W: COLS * FW, H: FW, bg: '#000', bodies: [b], panels }, png);
    const img = PNG.sync.read(fs.readFileSync(png));
    for (let col = 0; col < panels.length; col++) {
      const k = nBody + row * COLS + col;
      for (let y = 0; y < FW; y++) for (let x = 0; x < FW; x++) { const o = (y * img.width + col * FW + x) * 4, l = Math.max(img.data[o], img.data[o + 1], img.data[o + 2]); if (l > +(process.env.LUM || 150)) pix.push(x + .5 - FW / 2, FW / 2 - (y + .5), k); }
    }
  }
  const d2F = p => (p[0] - faceC[0]) ** 2 + (p[1] - faceC[1]) ** 2 + (p[2] - faceC[2]) ** 2;
  const tierOf = p => { const d = d2F(p); return d < (faceR * 1.15) ** 2 ? 1 : d < (HR * .92) ** 2 ? 2 : 0; }; // 1 얼굴 · 2 머리 · 0 몸
  // 2) 선 픽셀 → 원래 곡면 위 3D 점(GPU). 너무 많으면 나눠서
  const pts = [], DB = { tot: 0, miss: 0, t0: 0, t1: 0, t2: 0 };
  const CH = 600000 * 3;
  for (let s0 = 0; s0 < pix.length; s0 += CH) {
    const part = new Float32Array(pix.slice(s0, s0 + CH));
    const cf = path.join(__dirname, 'out/mesh', id + '_r7_' + s0 + '.bin');
    const R7 = REUSE && fs.existsSync(cf) ? new Float32Array(fs.readFileSync(cf).buffer.slice(0)) : linePoints(setDir, b, cams, part);
    if (!REUSE) fs.writeFileSync(cf, Buffer.from(R7.buffer, R7.byteOffset, R7.byteLength));
    for (let i = 0; i < part.length / 3; i++) {
      const dbgH = process.env.DBG && part[i * 3 + 2] >= nBody && faceViews[part[i * 3 + 2] - nBody][3] === 2; if (dbgH) DB.tot++;
      if (R7[i * 7 + 6] < .5) { if (dbgH) DB.miss++; continue; }
      const k = part[i * 3 + 2], n = [R7[i * 7 + 3], R7[i * 7 + 4], R7[i * 7 + 5]];
      const vt = k >= nBody ? faceViews[k - nBody][3] : 0;
      if (-V.dot(n, cams[k].F) < (vt === 1 ? .5 : vt === 2 ? +(process.env.HFACING || .4) : +(process.env.FACING || .62))) continue; // 옆으로 누운 면의 선 = 그 방향 외곽선(흰 껍질이 맡는다)
      const pp = [R7[i * 7], R7[i * 7 + 1], R7[i * 7 + 2]];
      if (dbgH && -V.dot(n, cams[k].F) >= .4) DB['t' + tierOf(pp)]++;
      if (vt !== tierOf(pp)) continue; // (얼굴은 얼굴 근접에서만, 머리는 머리 그림에서만, 나머지는 몸 그림에서만)
      pts.push([...pp, ...n, vt]);
    }
  }
  if (process.env.DBG) console.log('head-view pixels', JSON.stringify(DB));
  { const tc = [0, 0, 0]; for (const q of pts) tc[q[6]]++; console.log(id, 'points body/face/head', tc.join('/'), 'HR', HR.toFixed(2)); }
  // 3) 격자로 합치기(여러 방향에서 본 같은 선 → 하나)
  const cells = new Map();
  for (const q of pts) { const cs = q[6] === 1 ? CELL * .45 : q[6] === 2 ? CELL * .8 : CELL; const key = (q[6] ? 'f' + q[6] : '') + Math.round(q[0] / cs) + ',' + Math.round(q[1] / cs) + ',' + Math.round(q[2] / cs); const e = cells.get(key); if (e) { for (let a = 0; a < 6; a++) e.s[a] += q[a]; e.n++; } else cells.set(key, { s: q.slice(0, 6), n: 1, face: q[6] }); }
  const MINN = +(process.env.MINN || 2); // (두 방향 이상에서 함께 확인된 점만: 방향마다 살짝 어긋난 부스러기를 지운다)
  let dots = [...cells.values()].filter(e => e.n >= (e.face === 1 ? 2 : e.face === 2 ? +(process.env.HMINN || 3) : MINN)).map(e => { const p = [e.s[0] / e.n, e.s[1] / e.n, e.s[2] / e.n], n = norm([e.s[3], e.s[4], e.s[5]]); return { p, n, w: e.face === 1 ? 2e6 + e.n : e.face === 2 ? 1e6 + e.n : e.n, face: e.face }; });
  if (dots.length * 2 > MAXTRI) { dots.sort((a, b) => b.w - a.w); dots = dots.slice(0, Math.floor(MAXTRI / 2)); }
  // 4) 웨이트: 가장 가까운 몸 정점의 것(격자 해시)
  const HC = .08, grid = new Map(); P.forEach((p, i) => { const key = Math.floor(p[0] / HC) + ',' + Math.floor(p[1] / HC) + ',' + Math.floor(p[2] / HC); (grid.get(key) || grid.set(key, []).get(key)).push(i); });
  const nearest = p => { let best = -1, bd = 1e9; for (let r = 0; r < 4 && best < 0; r++) { const cx = Math.floor(p[0] / HC), cy = Math.floor(p[1] / HC), cz = Math.floor(p[2] / HC); for (let x = cx - r; x <= cx + r; x++) for (let y = cy - r; y <= cy + r; y++) for (let z = cz - r; z <= cz + r; z++) { const L = grid.get(x + ',' + y + ',' + z); if (!L) continue; for (const i of L) { const d = (P[i][0] - p[0]) ** 2 + (P[i][1] - p[1]) ** 2 + (P[i][2] - p[2]) ** 2; if (d < bd) { bd = d; best = i; } } } } return best < 0 ? 0 : best; };
  // 5) 점 → 표면에 붙은 작은 정사각형(삼각형 2개), 게임 좌표로
  const parts = [];
  for (let s0 = 0; s0 < dots.length; s0 += 9750) {
    const LP = [], LN = [], LJ = [], LW = [], LT = [];
    for (const d of dots.slice(s0, s0 + 9750)) {
      const vi = nearest(d.p), nv = d.face === 1 || process.env.SDFN ? d.n : norm(G([A.N[vi * 3], A.N[vi * 3 + 1], A.N[vi * 3 + 2]])); // (몸·머리 점은 거친 몸 메시의 면 방향으로 눕혀 메시 위로 띄운다: 홈 바닥 점이 메시에 묻히거나 옆으로 서서 끊겨 보이지 않게)
      const n = nv, t1 = norm(Math.abs(n[1]) < .9 ? V.cross(n, [0, 1, 0]) : V.cross(n, [1, 0, 0])), t2 = V.cross(n, t1);
      const bur = d.face === 1 ? 0 : Math.min(.08, Math.max(0, V.dot(V.sub(P[vi], d.p), n))), c0 = V.add(d.p, V.mul(n, LIFT + bur)), base = LP.length / 3, ds = d.face === 1 ? DOT * .6 : d.face === 2 ? DOT * +(process.env.HDOT || 1) : DOT;
      for (const [u, v] of [[-1, -1], [1, -1], [1, 1], [-1, 1]]) {
        LP.push(...G(V.add(V.add(c0, V.mul(t1, u * ds)), V.mul(t2, v * ds)))); LN.push(...G(n));
        for (let k = 0; k < 4; k++) { LJ.push(A.J[vi * 4 + k]); LW.push(A.W[vi * 4 + k]); }
      }
      LT.push(base, base + 1, base + 2, base, base + 2, base + 3);
    }
    parts.push({ name: parts.length ? 'Lines' + (parts.length + 1) : 'Lines', P: new Float32Array(LP), N: new Float32Array(LN), J: new Uint16Array(LJ), W: new Float32Array(LW), T: new Uint32Array(LT), color: [1, 1, 1, 1] });
  }
  // 6) 파일: 몸(검정) + 선 부품들. 로블록스는 glTF 를 앞뒤 180° 돌려 들이므로 파일에는 디자인 좌표(x·z 되돌림)로
  const flip = arr => { const o = new Float32Array(arr.length); for (let i = 0; i < arr.length; i += 3) { o[i] = -arr[i]; o[i + 1] = arr[i + 1]; o[i + 2] = -arr[i + 2]; } return o; };
  const bodyM = { name: 'Body', P: flip(new Float32Array(A.P)), N: flip(new Float32Array(A.N)), J: new Uint16Array(A.J), W: new Float32Array(A.W), T: new Uint32Array(A.T), color: [0.02, 0.02, 0.025, 1] };
  // 7) 얼굴 고해상도: 얼굴 둘레(반지름 1.25·faceR)를 몸보다 훨씬 촘촘한 격자로 다시 뽑아 몸 메시의 그 부분을 바꿔 끼운다
  //    → 눈구멍·이빨·코·붕대 골 같은 굴곡이 메시에 그대로 있어서 흰 껍질 외곽선이 시안처럼 그 테두리를 그린다
  const RF = faceR * 1.25, fvox = Math.max(.006, RF / 70);
  const fb = { ...b, mn: faceC.map(v => v - RF), mx: faceC.map(v => v + RF) };
  const FR = surfaceNets(sdfGrid(setDir, fb, fvox));
  const inF = (p, r) => (p[0] - faceC[0]) ** 2 + (p[1] - faceC[1]) ** 2 + (p[2] - faceC[2]) ** 2 < r * r;
  const keepT = []; for (let t = 0; t < FR.T.length; t += 3) { const c3 = [0, 1, 2].map(k => (FR.P[FR.T[t] * 3 + k] + FR.P[FR.T[t + 1] * 3 + k] + FR.P[FR.T[t + 2] * 3 + k]) / 3); if (inF(c3, RF * .98)) keepT.push(FR.T[t], FR.T[t + 1], FR.T[t + 2]); }
  const [fidx] = keepT.length > 19000 * 3 ? SIMP.simplify(new Uint32Array(keepT), FR.P, 3, 19000 * 3, .004, ["LockBorder"]) : [new Uint32Array(keepT)]; // (이미 작으면 그대로)
  const fmap = new Map(), FP = [], FN = [], FT = [];
  for (const i of fidx) { if (!fmap.has(i)) { fmap.set(i, FP.length / 3); FP.push(FR.P[i * 3], FR.P[i * 3 + 1], FR.P[i * 3 + 2]); FN.push(FR.N[i * 3], FR.N[i * 3 + 1], FR.N[i * 3 + 2]); } FT.push(fmap.get(i)); }
  const BT = []; for (let t = 0; t < A.T.length; t += 3) { const c3 = [0, 1, 2].map(k => (P[A.T[t]][k] + P[A.T[t + 1]][k] + P[A.T[t + 2]][k]) / 3); if (!inF(c3, RF * .95)) BT.push(A.T[t], A.T[t + 1], A.T[t + 2]); }
  const nF = FP.length / 3, FJ = new Uint16Array(nF * 4), FWt = new Float32Array(nF * 4);
  for (let i = 0; i < nF; i++) { const vi = nearest([FP[i * 3], FP[i * 3 + 1], FP[i * 3 + 2]]); for (let k = 0; k < 4; k++) { FJ[i * 4 + k] = A.J[vi * 4 + k]; FWt[i * 4 + k] = A.W[vi * 4 + k]; } }
  const Gp = arr => { const o = new Float32Array(arr.length); for (let i = 0; i < arr.length; i += 3) { o[i] = -arr[i]; o[i + 1] = arr[i + 1]; o[i + 2] = -arr[i + 2]; } return o; };
  const faceGame = { P: Gp(FP), N: Gp(FN), T: new Uint32Array(FT) };
  bodyM.T = new Uint32Array(BT);
  const faceM = { name: 'FaceBody', P: flip(faceGame.P), N: flip(faceGame.N), J: FJ, W: FWt, T: faceGame.T, color: [0.02, 0.02, 0.025, 1] };
  // 8) 외곽선 껍질(Outline·FaceOutline): 몸을 법선 방향으로 조금 부풀리고 삼각형을 뒤집은 흰 메시(뒷면만 보임) → 바깥·겹침 테두리 + 얼굴 굴곡 테두리
  const shell = (Pg, Ng, T, t) => { const oP = new Float32Array(Pg.length); for (let i = 0; i < Pg.length; i++) oP[i] = Pg[i] + Ng[i] * t; const oT2 = new Uint32Array(T.length); for (let i = 0; i < T.length; i += 3) { oT2[i] = T[i]; oT2[i + 1] = T[i + 2]; oT2[i + 2] = T[i + 1]; } const oN = new Float32Array(Ng.length); for (let i = 0; i < Ng.length; i++) oN[i] = -Ng[i]; return { P: oP, N: oN, T: oT2 }; };
  const OT = +(process.env.OUTLINE || .022), OTF = +(process.env.FOUTLINE || .009);
  const sB = shell(new Float32Array(A.P), new Float32Array(A.N), bodyM.T, OT), sF = shell(faceGame.P, faceGame.N, faceGame.T, OTF);
  const outlineM = { name: 'Outline', P: flip(sB.P), N: flip(sB.N), J: new Uint16Array(A.J), W: new Float32Array(A.W), T: sB.T, color: [1, 1, 1, 1] };
  const faceOutlineM = { name: 'FaceOutline', P: flip(sF.P), N: flip(sF.N), J: FJ, W: FWt, T: sF.T, color: [1, 1, 1, 1] };
  writeGLB(path.join(__dirname, 'out/mesh', id + '.glb'), [bodyM, faceM, outlineM, faceOutlineM, ...parts.map(L => ({ ...L, P: flip(L.P), N: flip(L.N) }))], A.bones.map(bn => ({ name: bn.name, c: G(bn.c) })));
  const oT = sB.T;
  A.F = { P: Array.from(faceGame.P, x => +x.toFixed(4)), N: Array.from(faceGame.N, x => +x.toFixed(3)), J: Array.from(FJ), W: Array.from(FWt, x => +x.toFixed(3)), T: Array.from(faceGame.T), t: OTF };
  A.BT = Array.from(bodyM.T);
  A.O = { T: Array.from(oT), t: OT };
  { const P2 = [], J2 = [], W2 = [], T2 = []; for (const L of parts) { const bs = P2.length / 3; for (const x of L.P) P2.push(+x.toFixed(4)); for (const x of L.J) J2.push(x); for (const x of L.W) W2.push(+x.toFixed(3)); for (const t of L.T) T2.push(t + bs); } A.L = { P: P2, J: J2, W: W2, T: T2 }; }
  fs.writeFileSync(path.join(__dirname, 'out/mesh', id + '_anim.json'), JSON.stringify(A));
  console.log(id, 'face', fc ? 'anat' : 'top', 'r', faceR.toFixed(2), 'face tris', FT.length / 3, 'line pixels', pix.length / 3, 'surface points', pts.length, 'dots', dots.length, 'tris', dots.length * 2, 'parts', parts.length);
}
})();
