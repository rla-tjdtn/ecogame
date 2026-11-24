// 시안 그림을 메시에 그대로 입히기(투영 텍스처): 시안 렌더러로 여러 방향의 그림을 찍고, 메시 삼각형마다
// "가려지지 않고 가장 정면으로 보이는 방향"의 그림을 골라 그 그림 픽셀을 그대로 UV 로 붙인다.
// 그림은 발광(emissive) 텍스처 → 로블록스가 SurfaceAppearance 발광 마스크로 바꿔 빛 없이도 시안 밝기 그대로 보인다.
//   node texbake.js k6h1 ...   (lines3d.js 다음: 얼굴 고해상도 메시 A.F·A.BT 가 필요) → out/mesh/<id>.glb, out/tex/<id>_*.png
//   PREVIEW=1 → out/tex/<id>_prev.png (게임에서 보일 모습: 텍스처 메시 + 흰 외곽선 껍질을 소프트웨어로 그린 것)
const fs = require('fs'), path = require('path');
const { PNG } = require('pngjs');
const { CFG } = require('./bake.js');
const { writeGLB } = require('./glb.js');
const SRC = path.join(__dirname, '..');
const META = Object.assign({}, require(path.join(SRC, 'set1/meta.js')), require(path.join(SRC, 'set2/meta2.js')), require(path.join(SRC, 'set3/meta3.js')), require(path.join(SRC, 'set4/meta4.js')));
const OUT = path.join(__dirname, 'out', 'tex'); fs.mkdirSync(OUT, { recursive: true });
const V = { sub: (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]], add: (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]], mul: (a, k) => [a[0] * k, a[1] * k, a[2] * k], dot: (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2], cross: (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]] };
const norm = a => { const l = Math.hypot(...a) || 1; return a.map(x => x / l); };
const G = v => [-v[0], v[1], -v[2]];
const S = 1024;                                  // 그림 한 장 = 텍스처 한 장(로블록스 최대 1024)
const LW = +(process.env.LW || 2.2), FILL = +(process.env.FILL || 1);

function camOf(yaw, pitch, target, scale) {
  const y = yaw * Math.PI / 180, pt = pitch * Math.PI / 180, D = [Math.sin(y) * Math.cos(pt), Math.sin(pt), Math.cos(y) * Math.cos(pt)];
  const F = D.map(v => -v), R = norm(V.cross(F, [0, 1, 0])), U = V.cross(R, F);
  return { yaw, pitch, target, scale, D, F, R, U, proj: p => { const d = V.sub(p, target); return [S / 2 + V.dot(d, R) * scale - .5, S / 2 - V.dot(d, U) * scale - .5, V.dot(d, D)]; } };
}

// 삼각형 래스터(z 버퍼): 깊이 = 카메라 쪽으로 얼마나 나와 있나(클수록 앞)
function zbuffer(cam, Ps, T) {
  const Z = new Float32Array(S * S).fill(-1e9), pr = Ps.map(cam.proj);
  for (let t = 0; t < T.length; t += 3) raster(pr[T[t]], pr[T[t + 1]], pr[T[t + 2]], (x, y, z) => { const i = y * S + x; if (z > Z[i]) Z[i] = z; });
  return { Z, pr };
}
function raster(a, b, c, f) {
  const x0 = Math.max(0, Math.floor(Math.min(a[0], b[0], c[0]))), x1 = Math.min(S - 1, Math.ceil(Math.max(a[0], b[0], c[0])));
  const y0 = Math.max(0, Math.floor(Math.min(a[1], b[1], c[1]))), y1 = Math.min(S - 1, Math.ceil(Math.max(a[1], b[1], c[1])));
  const ar = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]); if (Math.abs(ar) < 1e-9) return;
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
    const w0 = ((b[0] - x) * (c[1] - y) - (b[1] - y) * (c[0] - x)) / ar, w1 = ((c[0] - x) * (a[1] - y) - (c[1] - y) * (a[0] - x)) / ar, w2 = 1 - w0 - w1;
    if (w0 < -1e-4 || w1 < -1e-4 || w2 < -1e-4) continue;
    f(x, y, w0 * a[2] + w1 * b[2] + w2 * c[2], w0, w1, w2);
  }
}

for (const id of process.argv.slice(2)) {
  const t0 = Date.now();
  const c = CFG[id], A = JSON.parse(fs.readFileSync(path.join(__dirname, 'out/mesh', id + '_anim.json'), 'utf8'));
  if (!A.F || !A.BT) throw new Error(id + ': lines3d.js 먼저(얼굴 메시 없음)');
  const setDir = path.join(SRC, path.dirname(c.mod)), C = require(path.join(SRC, c.mod + '.js')), { render } = require(path.join(setDir, 'sculpt.js'));
  const m = META[path.basename(c.mod)] || {}, base = { ...(m.hero || (m.poses && m.poses[0] && m.poses[0][1]) || {}) }; const PK = c.phase || 'walk'; delete base[PK];
  const restP = { ...base, ...c.walk, [PK]: c.phaseAmp ? (c.phaseBase || 0) : 0 };
  const AN = require(path.join(setDir, 'anat.js')), faces = [];
  for (const fn of ['face', 'head']) if (typeof AN[fn] === 'function' && !AN[fn].__rec) { const orig = AN[fn]; AN[fn] = function (B, F, sz, ...rest) { (AN.__faces || []).push({ o: F && F.o, z: F && F.z, s: typeof sz === 'number' ? sz : 1 }); return orig.call(this, B, F, sz, ...rest); }; AN[fn].__rec = true; }
  AN.__faces = faces; const b = C.build(restP).data(); AN.__faces = null;

  // 메시(디자인 좌표): 몸(얼굴 부분 뺀 것) + 얼굴 고해상도. 정점 = 위치·법선·뼈·웨이트
  const src = [];
  { const nV = A.P.length / 3; for (let i = 0; i < nV; i++) src.push({ p: G([A.P[i * 3], A.P[i * 3 + 1], A.P[i * 3 + 2]]), n: G([A.N[i * 3], A.N[i * 3 + 1], A.N[i * 3 + 2]]), j: A.J.slice(i * 4, i * 4 + 4), w: A.W.slice(i * 4, i * 4 + 4) }); }
  const nBodyV = src.length;
  { const F = A.F, nV = F.P.length / 3; for (let i = 0; i < nV; i++) src.push({ p: G([F.P[i * 3], F.P[i * 3 + 1], F.P[i * 3 + 2]]), n: G([F.N[i * 3], F.N[i * 3 + 1], F.N[i * 3 + 2]]), j: F.J.slice(i * 4, i * 4 + 4), w: F.W.slice(i * 4, i * 4 + 4), face: 1 }); }
  const T = [...A.BT, ...A.F.T.map(i => i + nBodyV)], nT = T.length / 3, Ps = src.map(v => v.p);
  const triFace = new Uint8Array(nT); for (let t = 0; t < nT; t++) triFace[t] = src[T[t * 3]].face ? 1 : 0;

  // 카메라: 몸 16방향(그림 한 장에 몸 전체), 얼굴 7방향(얼굴 메시 지름이 그림을 꽉 채우게)
  let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9]; for (const p of Ps) for (let a = 0; a < 3; a++) { mn[a] = Math.min(mn[a], p[a]); mx[a] = Math.max(mx[a], p[a]); }
  const target = mn.map((v, a) => (v + mx[a]) / 2), Rb = Math.hypot(mx[0] - mn[0], mx[1] - mn[1], mx[2] - mn[2]) / 2, bScale = S * .49 / Rb;
  const cams = [];
  for (let k = 0; k < 8; k++) cams.push(camOf(k * 45, 8, target, bScale));
  for (let k = 0; k < 4; k++) cams.push(camOf(k * 90 + 45, 50, target, bScale));
  for (let k = 0; k < 4; k++) cams.push(camOf(k * 90, -45, target, bScale));
  const nBodyCams = cams.length;
  const fc = faces.length ? faces.reduce((a, f) => (a && a.s >= f.s ? a : f), null) : null;
  let fmn = [1e9, 1e9, 1e9], fmx = [-1e9, -1e9, -1e9]; for (let i = nBodyV; i < src.length; i++) for (let a = 0; a < 3; a++) { fmn[a] = Math.min(fmn[a], src[i].p[a]); fmx[a] = Math.max(fmx[a], src[i].p[a]); }
  const faceC = fmn.map((v, a) => (v + fmx[a]) / 2), RFm = Math.hypot(fmx[0] - fmn[0], fmx[1] - fmn[1], fmx[2] - fmn[2]) / 2, fScale = S * .49 / RFm;
  const fz = fc && fc.z ? norm(fc.z) : [0, 0, 1], yaw0 = Math.atan2(fz[0], fz[2]) * 180 / Math.PI, pitch0 = Math.asin(Math.max(-1, Math.min(1, fz[1]))) * 180 / Math.PI;
  for (const [dy, dp] of [[0, 0], [-40, 0], [40, 0], [-75, 0], [75, 0], [0, 35], [0, -35]]) cams.push(Object.assign(camOf(yaw0 + dy, Math.max(-80, Math.min(80, pitch0 + dp)), faceC, fScale), { kind: 'face' }));
  // 머리 전체(머리카락·뿔·귀·목): 얼굴 메시 반지름의 HEADK 배 구 안의 삼각형만, 몸 그림보다 몇 배 촘촘하게 빙 둘러
  const HRad = RFm * +(process.env.HEADK || 2.4), hScale = S * .49 / HRad, inHead = p => (p[0] - faceC[0]) ** 2 + (p[1] - faceC[1]) ** 2 + (p[2] - faceC[2]) ** 2 < (HRad * .95) ** 2;
  if (hScale > bScale * 1.3) for (const [dy, dp] of [[0, 15], [60, 15], [120, 15], [180, 15], [240, 15], [300, 15], [30, 70], [210, 70]]) cams.push(Object.assign(camOf(yaw0 + dy, dp, faceC, hScale), { kind: 'head' }));

  // 1) 그림 찍기(한 장 = 4방향 나란히, 각 1024²)
  const imgs = [];
  for (let r = 0; r < Math.ceil(cams.length / 4); r++) {
    const cs = cams.slice(r * 4, r * 4 + 4), png = path.join(OUT, id + '_v' + r + '.png');
    if (!(process.env.REUSE && fs.existsSync(png))) render({ W: cs.length * S, H: S, bg: '#000', bodies: [b], panels: cs.map((cm, col) => ({ x: col * S, y: 0, w: S, h: S, body: 0, yaw: cm.yaw, pitch: cm.pitch, scale: cm.scale, target: cm.target, lw: LW, ss: 2, glow: 0, fill: FILL, line: 1, border: 0 })) }, png);
    const im = PNG.sync.read(fs.readFileSync(png));
    cs.forEach((_, col) => { const g = new Uint8Array(S * S); for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) { const o = (y * im.width + col * S + x) * 4; g[y * S + x] = Math.max(im.data[o], im.data[o + 1], im.data[o + 2]); } imgs.push(g); });
  }

  // 2) 삼각형마다 고르기: 보이는(z 버퍼 통과) 방향 중 (정면도 × 해상도)가 가장 큰 것
  const triN = new Array(nT), triC = new Array(nT);
  for (let t = 0; t < nT; t++) { const a = Ps[T[t * 3]], b2 = Ps[T[t * 3 + 1]], c2 = Ps[T[t * 3 + 2]]; let n = V.cross(V.sub(b2, a), V.sub(c2, a)); const vn = V.add(V.add(src[T[t * 3]].n, src[T[t * 3 + 1]].n), src[T[t * 3 + 2]].n); if (V.dot(n, vn) < 0) n = V.mul(n, -1); triN[t] = norm(n); triC[t] = V.mul(V.add(V.add(a, b2), c2), 1 / 3); }
  const score = new Float32Array(nT * cams.length);
  cams.forEach((cm, k) => {
    const { Z, pr } = zbuffer(cm, Ps, T), isFaceCam = cm.kind === 'face';
    const pc = triC.map(cm.proj);
    for (let t = 0; t < nT; t++) {
      if (isFaceCam && !triFace[t]) continue; // (얼굴 그림은 얼굴 메시에만)
      if (cm.kind === 'head' && !inHead(triC[t])) continue; // (머리 그림은 머리 둘레에만)
      const f = V.dot(triN[t], cm.D); if (f < .2) continue;
      // 보임: 가운데와 세 꼭짓점 중 3곳 이상이 z 버퍼 맨 앞(조금 여유)
      let vis = 0; const tol = 2.5 / cm.scale + .01;
      for (const q of [pc[t], pr[T[t * 3]], pr[T[t * 3 + 1]], pr[T[t * 3 + 2]]]) { const x = Math.round(q[0]), y = Math.round(q[1]); if (x < 0 || y < 0 || x >= S || y >= S) continue; if (q[2] >= Z[y * S + x] - tol) vis++; }
      if (vis < 3) continue;
      // 그림 가장자리(테두리 10px 안)는 피한다
      const q = pc[t]; if (q[0] < 10 || q[1] < 10 || q[0] > S - 10 || q[1] > S - 10) continue;
      score[t * cams.length + k] = f * f * cm.scale * (isFaceCam ? 1 : 1);
    }
  });
  const pick = new Int16Array(nT).fill(-1);
  for (let t = 0; t < nT; t++) { let best = -1, bs = 0; for (let k = 0; k < cams.length; k++) { const s = score[t * cams.length + k]; if (s > bs) { bs = s; best = k; } } pick[t] = best; }
  // 이웃끼리 같은 그림을 쓰게 다듬기(조각난 경계 = 선 어긋남 줄이기): 이웃 다수가 쓰는 그림이 나쁘지 않으면(점수 70% 이상) 그것으로
  const edgeMap = new Map(), adj = Array.from({ length: nT }, () => []);
  for (let t = 0; t < nT; t++) for (let e = 0; e < 3; e++) { const a = T[t * 3 + e], b2 = T[t * 3 + (e + 1) % 3]; const key = a < b2 ? a + ',' + b2 : b2 + ',' + a; const o = edgeMap.get(key); if (o !== undefined) { adj[t].push(o); adj[o].push(t); } else edgeMap.set(key, t); }
  for (let it = 0; it < 4; it++) for (let t = 0; t < nT; t++) {
    if (pick[t] < 0) continue; const cnt = new Map(); for (const o of adj[t]) if (pick[o] >= 0) cnt.set(pick[o], (cnt.get(pick[o]) || 0) + 1);
    let bk = pick[t], bc = cnt.get(pick[t]) || 0; for (const [k, n] of cnt) if (n > bc && score[t * cams.length + k] >= .7 * score[t * cams.length + pick[t]]) { bk = k; bc = n; }
    pick[t] = bk;
  }

  // 3) 그림마다 부품 하나: 쓰인 영역만 잘라 텍스처로, UV = 그 그림 위 위치. 어디서도 안 보이는 삼각형 = 텍스처 없는 검정 부품
  const meshes = [], texInfo = [];
  const groups = new Map(); for (let t = 0; t < nT; t++) { const k = pick[t]; (groups.get(k) || groups.set(k, []).get(k)).push(t); }
  const flipP = p => p; // (glb 파일 = 디자인 좌표: lines3d 와 같게)
  for (const [k, tris] of [...groups.entries()].sort((a, b2) => a[0] - b2[0])) {
    for (let s0 = 0; s0 < tris.length; s0 += 19000) {
      const ts = tris.slice(s0, s0 + 19000), vmap = new Map(), P = [], N = [], J = [], W = [], UV = [], TT = [];
      const cm = k >= 0 ? cams[k] : null;
      let bx0 = 1e9, by0 = 1e9, bx1 = -1e9, by1 = -1e9;
      for (const t of ts) for (let e = 0; e < 3; e++) { const vi = T[t * 3 + e]; if (!vmap.has(vi)) { vmap.set(vi, P.length / 3); const v = src[vi]; P.push(...flipP(v.p)); N.push(...flipP(v.n)); J.push(...v.j); W.push(...v.w); if (cm) { const q = cm.proj(v.p); UV.push(q[0], q[1]); bx0 = Math.min(bx0, q[0]); by0 = Math.min(by0, q[1]); bx1 = Math.max(bx1, q[0]); by1 = Math.max(by1, q[1]); } } TT.push(vmap.get(vi)); }
      const mesh = { name: cm ? 'Tex' + meshes.length : 'Plain' + meshes.length, P: new Float32Array(P), N: new Float32Array(N), J: new Uint16Array(J), W: new Float32Array(W), T: new Uint32Array(TT), color: [0.02, 0.02, 0.025, 1] };
      if (cm) {
        const x0 = Math.max(0, Math.floor(bx0) - 4), y0 = Math.max(0, Math.floor(by0) - 4), x1 = Math.min(S, Math.ceil(bx1) + 5), y1 = Math.min(S, Math.ceil(by1) + 5), w = x1 - x0, h = y1 - y0;
        const out = new PNG({ width: w, height: h }), g = imgs[k];
        for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { const v = g[(y0 + y) * S + x0 + x], o = (y * w + x) * 4; out.data[o] = out.data[o + 1] = out.data[o + 2] = v; out.data[o + 3] = 255; }
        const file = path.join(OUT, `${id}_t${meshes.length}.png`); const buf = PNG.sync.write(out); fs.writeFileSync(file, buf);
        const uv = new Float32Array(UV.length); for (let i = 0; i < UV.length; i += 2) { uv[i] = (UV[i] + .5 - x0) / w; uv[i + 1] = (UV[i + 1] + .5 - y0) / h; }
        mesh.UV = uv; mesh._png = buf; if (process.env.EMBED) mesh.emissivePNG = buf; mesh.color = [0, 0, 0, 1]; // (텍스처는 glb 에 안 넣는다: Open Cloud 모델 업로드가 못 옮김 → upload-tex.js + gen-tex.js)
        texInfo.push({ part: mesh.name, view: k, kind: cm.kind || 'body', tris: ts.length, w, h });
      }
      meshes.push(mesh);
    }
  }
  // 4) 흰 외곽선 껍질(lines3d 와 같은 것: 몸 = OT, 얼굴 = OTF)
  const shell = (Pg, Ng, Tt, th) => { const oP = new Float32Array(Pg.length); for (let i = 0; i < Pg.length; i++) oP[i] = Pg[i] + Ng[i] * th; const oT2 = new Uint32Array(Tt.length); for (let i = 0; i < Tt.length; i += 3) { oT2[i] = Tt[i]; oT2[i + 1] = Tt[i + 2]; oT2[i + 2] = Tt[i + 1]; } const oN = new Float32Array(Ng.length); for (let i = 0; i < Ng.length; i++) oN[i] = -Ng[i]; return { P: oP, N: oN, T: oT2 }; };
  const flipArr = arr => { const o = new Float32Array(arr.length); for (let i = 0; i < arr.length; i += 3) { o[i] = -arr[i]; o[i + 1] = arr[i + 1]; o[i + 2] = -arr[i + 2]; } return o; };
  const OT = A.O ? A.O.t : .022, OTF = A.F.t || .009;
  const trimOpen = (Tt, rings) => { // (잘린 가장자리(열린 모서리) 근처 껍질 삼각형 빼기: 얼굴·몸 이음매에 흰 조각이 안 보이게)
    const ec = new Map(); for (let i = 0; i < Tt.length; i += 3) for (let e = 0; e < 3; e++) { const a = Tt[i + e], b2 = Tt[i + (e + 1) % 3], key = a < b2 ? a + ',' + b2 : b2 + ',' + a; ec.set(key, (ec.get(key) || 0) + 1); }
    let mark = new Set(); for (const [key, n] of ec) if (n === 1) for (const v of key.split(',')) mark.add(+v);
    for (let r = 0; r < rings; r++) { const nm = new Set(mark); for (let i = 0; i < Tt.length; i += 3) if (mark.has(Tt[i]) || mark.has(Tt[i + 1]) || mark.has(Tt[i + 2])) { nm.add(Tt[i]); nm.add(Tt[i + 1]); nm.add(Tt[i + 2]); } mark = nm; }
    const o = []; for (let i = 0; i < Tt.length; i += 3) if (!(mark.has(Tt[i]) && mark.has(Tt[i + 1]) && mark.has(Tt[i + 2]))) o.push(Tt[i], Tt[i + 1], Tt[i + 2]); return new Uint32Array(o); };
  const sB = shell(new Float32Array(A.P), new Float32Array(A.N), (process.env.TRIMB ? trimOpen(new Uint32Array(A.BT), +process.env.TRIMB) : new Uint32Array(A.T)) /* 몸 외곽선 = 몸 전체(얼굴 자리 포함, 잘린 데 없음) → 목·턱 테두리 끊김 없음 */, OT), sF = shell(new Float32Array(A.F.P), new Float32Array(A.F.N), trimOpen(new Uint32Array(A.F.T), +(process.env.TRIMF || 3)), OTF);
  if (!process.env.NOSHELL) {
    meshes.push({ name: 'Outline', P: flipArr(sB.P), N: flipArr(sB.N), J: new Uint16Array(A.J), W: new Float32Array(A.W), T: sB.T, color: [1, 1, 1, 1] });
    meshes.push({ name: 'FaceOutline', P: flipArr(sF.P), N: flipArr(sF.N), J: new Uint16Array(A.F.J), W: new Float32Array(A.F.W), T: sF.T, color: [1, 1, 1, 1] });
  }
  writeGLB(path.join(__dirname, 'out/mesh', id + '.glb'), meshes, A.bones.map(bn => ({ name: bn.name, c: G(bn.c) })));
  fs.writeFileSync(path.join(OUT, id + '.json'), JSON.stringify({ id, parts: texInfo, plain: meshes.filter(m => m.name.startsWith('Plain')).map(m => m.T.length / 3) }, null, 1));
  const hidden = groups.get(-1) ? groups.get(-1).length : 0;
  console.log(id, 'tris', nT, 'textured parts', texInfo.length, 'hidden tris', hidden, 'sec', ((Date.now() - t0) / 1000).toFixed(0));

  // 5) 미리보기: 게임에서처럼(검정 몸 + 발광 텍스처 + 흰 껍질) 정해진 방향에서 소프트웨어로 그리기
  if (process.env.PREVIEW) {
    const pv = [[0, 8, target, bScale], [35, 8, target, bScale], [90, 8, target, bScale], [0, 0, faceC, fScale * .8], [30, 5, faceC, fScale * .8]];
    const W2 = S * pv.length, out = new PNG({ width: W2, height: S });
    for (let i = 0; i < out.data.length; i += 4) { out.data[i] = 5; out.data[i + 1] = 6; out.data[i + 2] = 8; out.data[i + 3] = 255; }
    pv.forEach(([yw, ptc, tg, sc], col) => {
      const cm = camOf(yw + (col >= 3 ? yaw0 : 0), ptc + (col >= 3 ? pitch0 : 0), tg, sc), Z = new Float32Array(S * S).fill(-1e9);
      const put = (x, y, z, v) => { const i = y * S + x; if (z > Z[i]) { Z[i] = z; const o = (y * W2 + col * S + x) * 4; out.data[o] = v * .97 + 5 * (1 - v / 255); out.data[o + 1] = v * .96 + 6 * (1 - v / 255); out.data[o + 2] = v * .93 + 8 * (1 - v / 255); } };
      for (const mesh of meshes) {
        const nv = mesh.P.length / 3, pr = []; for (let i = 0; i < nv; i++) pr.push(cm.proj([mesh.P[i * 3], mesh.P[i * 3 + 1], mesh.P[i * 3 + 2]]));
        const isShell = mesh.name.includes('Outline'); let tex = null, tw = 0, th = 0; if (mesh._png) { const im = PNG.sync.read(mesh._png); tex = im.data; tw = im.width; th = im.height; }
        for (let t = 0; t < mesh.T.length; t += 3) {
          const a = pr[mesh.T[t]], b2 = pr[mesh.T[t + 1]], c2 = pr[mesh.T[t + 2]];
          // 앞면만(껍질은 원래 바깥 법선이 카메라 반대쪽인 곳만 = 뒤집힌 껍질의 보이는 부분)
          const pa = [mesh.P[mesh.T[t] * 3], mesh.P[mesh.T[t] * 3 + 1], mesh.P[mesh.T[t] * 3 + 2]], pb = [mesh.P[mesh.T[t + 1] * 3], mesh.P[mesh.T[t + 1] * 3 + 1], mesh.P[mesh.T[t + 1] * 3 + 2]], pcc = [mesh.P[mesh.T[t + 2] * 3], mesh.P[mesh.T[t + 2] * 3 + 1], mesh.P[mesh.T[t + 2] * 3 + 2]];
          const nd = V.dot(V.cross(V.sub(pb, pa), V.sub(pcc, pa)), cm.D) * (process.env.WIND ? -1 : 1); // (감김 방향으로 뒷면 버리기 = 로블록스와 같게)
          if (nd <= 0) continue;
          raster(a, b2, c2, (x, y, z, w0, w1, w2) => {
            let v = process.env.PLAINGRAY && !tex && !isShell ? 90 : 0; if (isShell) v = 255; else if (tex) { const ia = mesh.T[t], ib = mesh.T[t + 1], ic = mesh.T[t + 2]; const u = w0 * mesh.UV[ia * 2] + w1 * mesh.UV[ib * 2] + w2 * mesh.UV[ic * 2], vv = w0 * mesh.UV[ia * 2 + 1] + w1 * mesh.UV[ib * 2 + 1] + w2 * mesh.UV[ic * 2 + 1]; const tx = Math.min(tw - 1, Math.max(0, Math.floor(u * tw))), ty = Math.min(th - 1, Math.max(0, Math.floor(vv * th))); v = tex[(ty * tw + tx) * 4]; }
            put(x, y, z - (isShell ? 1e-4 : 0), v);
          });
        }
      }
    });
    fs.writeFileSync(path.join(OUT, id + '_prev.png'), PNG.sync.write(out));
  }
}
