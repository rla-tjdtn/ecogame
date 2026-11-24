// 시안 선화를 3D 메시 정점 색으로 입힌다: 시안 렌더러(setN/view.html)로 쉬는 자세를 16방향에서 선만 찍고,
// 메시 정점을 그 그림들에 투영(가려진 면·옆으로 누운 면은 빼고)해 선 밝기 평균 → 흰 선 / 검은 몸 정점 색(COLOR_0).
// 방향마다 생기는 외곽선(보는 쪽에 따라 바뀌는 선)은 정면을 향한 면만 세어서 빠지고, 몸에 새겨진 선(주름·홈·경계)만 남는다.
//   node linebake.js k4h1 ...  (rig.js 다음에) → out/mesh/<id>.glb 를 색 넣어 다시 쓴다
const fs = require('fs'), path = require('path');
const { PNG } = require('pngjs');
const { CFG } = require('./bake.js');
const { writeGLB } = require('./glb.js');
const SRC = path.join(__dirname, '..');
const META = Object.assign({}, require(path.join(SRC, 'set1/meta.js')), require(path.join(SRC, 'set2/meta2.js')), require(path.join(SRC, 'set3/meta3.js')), require(path.join(SRC, 'set4/meta4.js')));
const PW = 1280, PH = 2048, COLS = 4; // (방향마다 1280×2048: 얼굴의 가는 선까지 남게 2배 해상도, 한 줄(4방향)씩 따로 찍는다)
const VIEWS = [];
for (let k = 0; k < 8; k++) VIEWS.push([k * 45, 8]);
for (let k = 0; k < 4; k++) VIEWS.push([k * 90 + 45, 42]);
for (let k = 0; k < 4; k++) VIEWS.push([k * 90, -30]);
const V = { sub: (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]], add: (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]], mul: (a, k) => [a[0] * k, a[1] * k, a[2] * k], dot: (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2], cross: (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]] };
const norm = a => { const l = Math.hypot(...a) || 1; return a.map(x => x / l); };
const G = v => [-v[0], v[1], -v[2]];

for (const id of process.argv.slice(2)) {
  const c = CFG[id], A = JSON.parse(fs.readFileSync(path.join(__dirname, 'out/mesh', id + '_anim.json'), 'utf8'));
  const setDir = path.join(SRC, path.dirname(c.mod)), C = require(path.join(SRC, c.mod + '.js')), { render } = require(path.join(setDir, 'sculpt.js'));
  const m = META[path.basename(c.mod)] || {}, base = { ...(m.hero || (m.poses && m.poses[0] && m.poses[0][1]) || {}) }; const PK = c.phase || 'walk'; delete base[PK];
  const restP = { ...base, ...c.walk, [PK]: c.phaseAmp ? (c.phaseBase || 0) : 0 };
  const b = C.build(restP).data();
  // 메시(디자인 좌표)
  const nV = A.P.length / 3, P = [], N = [];
  for (let i = 0; i < nV; i++) { P.push(G([A.P[i * 3], A.P[i * 3 + 1], A.P[i * 3 + 2]])); N.push(G([A.N[i * 3], A.N[i * 3 + 1], A.N[i * 3 + 2]])); }
  let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9]; for (const p of P) for (let a = 0; a < 3; a++) { mn[a] = Math.min(mn[a], p[a]); mx[a] = Math.max(mx[a], p[a]); }
  const target = mn.map((v, a) => (v + mx[a]) / 2), Rad = Math.hypot(...V.sub(mx, mn)) / 2, Rxz = Math.hypot(mx[0] - mn[0], mx[2] - mn[2]) / 2, scale = Math.min(PW * .47 / Rxz, PH * .46 / Math.hypot(mx[1] - mn[1], Rxz) * 2 * .5 * 2 / 2); void Rad;
  const ROWS = Math.ceil(VIEWS.length / COLS), imgs = [];
  for (let row = 0; row < ROWS; row++) {
    const panels = VIEWS.slice(row * COLS, row * COLS + COLS).map(([yaw, pitch], c) => ({ x: c * PW, y: 0, w: PW, h: PH, body: 0, yaw, pitch, scale, target, lw: 1.8, ss: 2, glow: 0, fill: 0, line: 1, border: 0 }));
    const png = path.join(__dirname, 'out/mesh', id + '_lines' + row + '.png');
    render({ W: COLS * PW, H: PH, bg: '#000', bodies: [b], panels }, png);
    imgs.push(PNG.sync.read(fs.readFileSync(png)));
  }
  let img = imgs[0];
  const lum = (x, y) => { if (x < 0 || y < 0 || x >= img.width || y >= img.height) return 0; const o = (y * img.width + x) * 4; return Math.max(img.data[o], img.data[o + 1], img.data[o + 2]) / 255; };
  const sum = new Float32Array(nV), cnt = new Float32Array(nV);
  const VD = []; // 방향마다 { proj, zb, ox, oy, F } — 잘게 나눈 선 조각을 다시 확인할 때 쓴다
  VIEWS.forEach(([yaw, pitch], k) => {
    const y = yaw * Math.PI / 180, pt = pitch * Math.PI / 180, D = [Math.sin(y) * Math.cos(pt), Math.sin(pt), Math.cos(y) * Math.cos(pt)], F = D.map(v => -v), R = norm(V.cross(F, [0, 1, 0])), U = V.cross(R, F), eye = target.map((v, a) => v + D[a] * 40);
    const ox = (k % COLS) * PW + PW / 2, oy = PH / 2; // (이 방향 그림 = imgs[row] 안의 칸)
    img = imgs[Math.floor(k / COLS)];
    const proj = p => { const d = V.sub(p, eye); return [ox + V.dot(d, R) * scale, oy - V.dot(d, U) * scale, V.dot(d, F)]; };
    // 메시 깊이(이 방향): 삼각형 래스터
    const zb = new Float32Array(PW * PH).fill(1e9), sp = P.map(proj);
    for (let t = 0; t < A.T.length; t += 3) {
      const a = sp[A.T[t]], bb = sp[A.T[t + 1]], cc = sp[A.T[t + 2]];
      const x0 = Math.max(Math.floor(Math.min(a[0], bb[0], cc[0])), ox - PW / 2), x1 = Math.min(Math.ceil(Math.max(a[0], bb[0], cc[0])), ox + PW / 2 - 1);
      const y0 = Math.max(Math.floor(Math.min(a[1], bb[1], cc[1])), oy - PH / 2), y1 = Math.min(Math.ceil(Math.max(a[1], bb[1], cc[1])), oy + PH / 2 - 1);
      const den = (bb[1] - cc[1]) * (a[0] - cc[0]) + (cc[0] - bb[0]) * (a[1] - cc[1]); if (Math.abs(den) < 1e-9) continue;
      for (let py = y0; py <= y1; py++) for (let px = x0; px <= x1; px++) {
        const w0 = ((bb[1] - cc[1]) * (px - cc[0]) + (cc[0] - bb[0]) * (py - cc[1])) / den, w1 = ((cc[1] - a[1]) * (px - cc[0]) + (a[0] - cc[0]) * (py - cc[1])) / den, w2 = 1 - w0 - w1;
        if (w0 < -.01 || w1 < -.01 || w2 < -.01) continue;
        const z = w0 * a[2] + w1 * bb[2] + w2 * cc[2], o = (py - (oy - PH / 2)) * PW + (px - (ox - PW / 2)); if (z < zb[o]) zb[o] = z;
      }
    }
    VD.push({ proj, zb, ox, oy, F, img });
    for (let i = 0; i < nV; i++) {
      const facing = -V.dot(N[i], F); if (facing < .45) continue; // 옆으로 누운 면(외곽선이 생기는 곳)은 세지 않는다
      const [sx, sy, sz] = sp[i], px = Math.round(sx), py = Math.round(sy);
      const o = (py - (oy - PH / 2)) * PW + (px - (ox - PW / 2)); if (px < ox - PW / 2 || px >= ox + PW / 2 || py < oy - PH / 2 || py >= oy + PH / 2) continue;
      let zmin = 1e9; for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) { const q = o + dy * PW + dx; if (q >= 0 && q < zb.length) zmin = Math.min(zmin, zb[q]); }
      if (sz > zmin + .06) continue; // 가려짐
      let l = lum(px, py); for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) l = Math.max(l, lum(px + dx, py + dy) * .7);
      sum[i] += l * facing; cnt[i] += facing;
    }
  });
  const Cc = new Float32Array(nV * 4); let lit = 0;
  for (let i = 0; i < nV; i++) {
    const avg = cnt[i] > 0 ? sum[i] / cnt[i] : 0, L = Math.min(1, Math.max(0, (avg - .3) / .3));
    const body = .07, v = body + (0.97 - body) * L; if (L > .5) lit++;
    Cc.set([v * .97, v * .96, v * .93, 1], i * 4);
  }
  // ── 흰 선 메시(Lines): 선이 지나는 삼각형을 4조각으로 나눠 시안 선 그림에서 다시 확인하고, 선 위 조각만 남겨 표면 바로 바깥(+법선)에 띄운다.
  //    몸과 같은 뼈·웨이트(모서리 웨이트를 섞어 상위 4개)라 같이 움직이고, 게임에서는 흰 네온(빛 없이 스스로 보임)
  const lineAt = (p, n) => {
    // 정면을 향한 방향들 중 선이 잘 보이는 절반의 평균(메시가 원래 곡면과 조금 어긋나 방향마다 선 위치가 살짝 다른 것을 견딘다)
    const vals = [];
    for (const v of VD) {
      img = v.img;
      const facing = -V.dot(n, v.F); if (facing < .45) continue;
      const [sx, sy, sz] = v.proj(p), px = Math.round(sx), py = Math.round(sy);
      if (px < v.ox - PW / 2 || px >= v.ox + PW / 2 || py < v.oy - PH / 2 || py >= v.oy + PH / 2) continue;
      const o = (py - (v.oy - PH / 2)) * PW + (px - (v.ox - PW / 2));
      let zmin = 1e9; for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) { const q = o + dy * PW + dx; if (q >= 0 && q < v.zb.length) zmin = Math.min(zmin, v.zb[q]); }
      if (sz > zmin + .06) continue;
      let l = lum(px, py); for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1]]) l = Math.max(l, lum(px + dx, py + dy) * .8);
      vals.push(l);
    }
    if (vals.length === 0) return 0;
    vals.sort((a, b) => b - a);
    const top = vals.slice(0, Math.max(1, Math.ceil(vals.length / 2)));
    const m = top.reduce((a, b) => a + b, 0) / top.length;
    return Math.min(1, Math.max(0, (m - .3) / .3));
  };
  const Lv = i => Cc[i * 4] > .3 ? 1 : 0;
  const LP = [], LN = [], LJ = [], LW = [], LT = [];
  const OFF = .012;
  const addV = (p, n, wmap) => { const nn = norm(n); LP.push(...G(V.add(p, V.mul(nn, OFF)))); LN.push(...G(nn)); const top = [...wmap.entries()].sort((a, b) => b[1] - a[1]).slice(0, 4); const s = top.reduce((a, e) => a + e[1], 0) || 1; for (let k = 0; k < 4; k++) { LJ.push(top[k] ? top[k][0] : 0); LW.push(top[k] ? top[k][1] / s : 0); } return LP.length / 3 - 1; };
  const wOf = (ws) => { const m = new Map(); for (const [i, f] of ws) for (let k = 0; k < 4; k++) { const j = A.J[i * 4 + k], w = A.W[i * 4 + k] * f; if (w > 0) m.set(j, (m.get(j) || 0) + w); } return m; };
  const lerp3 = (a, b, t) => V.add(a, V.mul(V.sub(b, a), t));
  const cand = [];
  for (let t = 0; t < A.T.length; t += 3) {
    const ia = A.T[t], ib = A.T[t + 1], ic = A.T[t + 2];
    void Lv; // (모든 삼각형을 잘게 나눠 본다: 꼭짓점 사이를 지나는 얼굴의 가는 선도 놓치지 않게)
    // 16조각(두 번 나눔): 무게중심 좌표 (u,v,w) 격자 4×4, 꼭짓점마다 시안 선 그림에서 다시 확인
    const D4 = 4, key = (i, j) => i * 10 + j, vals = new Map(), at = new Map();
    for (let i = 0; i <= D4; i++) for (let j = 0; j <= D4 - i; j++) {
      const u = i / D4, v2 = j / D4, w = 1 - u - v2;
      const p = V.add(V.add(V.mul(P[ia], u), V.mul(P[ib], v2)), V.mul(P[ic], w));
      const nn = norm(V.add(V.add(V.mul(N[ia], u), V.mul(N[ib], v2)), V.mul(N[ic], w)));
      at.set(key(i, j), { p, n: nn, w: [[ia, u], [ib, v2], [ic, w]] }); vals.set(key(i, j), lineAt(p, nn));
    }
    for (let i = 0; i < D4; i++) for (let j = 0; j < D4 - i; j++) {
      for (const tri of [[key(i, j), key(i + 1, j), key(i, j + 1)], ...(j < D4 - i - 1 ? [[key(i + 1, j), key(i + 1, j + 1), key(i, j + 1)]] : [])]) {
        const avg = (vals.get(tri[0]) + vals.get(tri[1]) + vals.get(tri[2])) / 3;
        if (avg < .45) continue;
        cand.push({ avg, k: tri.map(q => at.get(q)) });
      }
    }
  }
  // 로블록스 메시 한도(2만 삼각형): 넘치면 선이 가장 진한 조각부터 남긴다
  // 선 메시는 여러 부품으로 나눈다(부품마다 로블록스 한도 2만 삼각형 안). 너무 많으면 진한 선부터 최대 5만 8500
  cand.sort((a, b) => b.avg - a.avg);
  const kept = cand.slice(0, 58500);
  const lineParts = [];
  for (let s0 = 0; s0 < kept.length; s0 += 19500) {
    LP.length = 0; LN.length = 0; LJ.length = 0; LW.length = 0; LT.length = 0;
    for (const cd of kept.slice(s0, s0 + 19500)) LT.push(...cd.k.map(q => addV(q.p, q.n, wOf(q.w))));
    lineParts.push({ name: lineParts.length ? 'Lines' + (lineParts.length + 1) : 'Lines', P: new Float32Array(LP), N: new Float32Array(LN), J: new Uint16Array(LJ), W: new Float32Array(LW), T: new Uint32Array(LT), color: [1, 1, 1, 1] });
  }
  void lerp3;
  const Pg = new Float32Array(A.P), Ng = new Float32Array(A.N), J = new Uint16Array(A.J), Wt = new Float32Array(A.W), T = new Uint32Array(A.T);
  const lines = lineParts[0] || { name: 'Lines', P: new Float32Array(0), N: new Float32Array(0), J: new Uint16Array(0), W: new Float32Array(0), T: new Uint32Array(0) };
  // 로블록스는 glTF 를 가져올 때 앞뒤를 180° 돌린다(glTF 앞 +Z → 로블록스 앞 -Z). 그래서 파일에는 디자인 좌표(앞 +Z)로 쓴다:
  // 들여온 뒤 부품 공간 = 게임 좌표(앞 -Z)가 되어, 게임 좌표로 만든 뼈 움직임(CreatureRigs)과 맞는다
  const flip = arr => { const o = new Float32Array(arr.length); for (let i = 0; i < arr.length; i += 3) { o[i] = -arr[i]; o[i + 1] = arr[i + 1]; o[i + 2] = -arr[i + 2]; } return o; };
  const bonesD = A.bones.map(b => ({ name: b.name, c: G(b.c) }));
  const bodyM = { name: 'Body', P: flip(Pg), N: flip(Ng), J, W: Wt, T, color: [0.02, 0.02, 0.025, 1] };
  const linesMs = lineParts.map(L => ({ ...L, P: flip(L.P), N: flip(L.N) }));
  writeGLB(path.join(__dirname, 'out/mesh', id + '.glb'), linesMs.length ? [bodyM, ...linesMs] : { ...bodyM, C: Cc }, bonesD);
  // (미리보기용: 선 부품들을 하나로 합쳐 둔다)
  { const P2 = [], J2 = [], W2 = [], T2 = []; for (const L of lineParts) { const base = P2.length / 3; for (const x of L.P) P2.push(+x.toFixed(3)); for (const x of L.J) J2.push(x); for (const x of L.W) W2.push(+x.toFixed(3)); for (const t of L.T) T2.push(t + base); } A.L = { P: P2, J: J2, W: W2, T: T2 }; }
  fs.writeFileSync(path.join(__dirname, 'out/mesh', id + '_anim.json'), JSON.stringify(A));
  console.log(id, 'line mesh', kept.length, 'tris in', lineParts.length, 'parts');
  A.C = Array.from(Cc.filter((_, k) => k % 4 === 0), x => +x.toFixed(2)); fs.writeFileSync(path.join(__dirname, 'out/mesh', id + '_anim.json'), JSON.stringify(A));
  console.log(id, 'lines', lit, '/', nV, 'vertices white');
}
