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
const PW = 640, PH = 1024, COLS = 4;
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
  const panels = VIEWS.map(([yaw, pitch], k) => ({ x: (k % COLS) * PW, y: Math.floor(k / COLS) * PH, w: PW, h: PH, body: 0, yaw, pitch, scale, target, lw: 1.4, ss: 2, glow: 0, fill: 0, line: 1, border: 0 }));
  const W = COLS * PW, H = Math.ceil(VIEWS.length / COLS) * PH;
  const png = path.join(__dirname, 'out/mesh', id + '_lines.png');
  render({ W, H, bg: '#000', bodies: [b], panels }, png);
  const img = PNG.sync.read(fs.readFileSync(png));
  const lum = (x, y) => { if (x < 0 || y < 0 || x >= img.width || y >= img.height) return 0; const o = (y * img.width + x) * 4; return Math.max(img.data[o], img.data[o + 1], img.data[o + 2]) / 255; };
  const sum = new Float32Array(nV), cnt = new Float32Array(nV);
  VIEWS.forEach(([yaw, pitch], k) => {
    const y = yaw * Math.PI / 180, pt = pitch * Math.PI / 180, D = [Math.sin(y) * Math.cos(pt), Math.sin(pt), Math.cos(y) * Math.cos(pt)], F = D.map(v => -v), R = norm(V.cross(F, [0, 1, 0])), U = V.cross(R, F), eye = target.map((v, a) => v + D[a] * 40);
    const ox = (k % COLS) * PW + PW / 2, oy = Math.floor(k / COLS) * PH + PH / 2;
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
  const Pg = new Float32Array(A.P), Ng = new Float32Array(A.N), J = new Uint16Array(A.J), Wt = new Float32Array(A.W), T = new Uint32Array(A.T);
  writeGLB(path.join(__dirname, 'out/mesh', id + '.glb'), { P: Pg, N: Ng, J, W: Wt, T, C: Cc }, A.bones);
  A.C = Array.from(Cc.filter((_, k) => k % 4 === 0), x => +x.toFixed(2)); fs.writeFileSync(path.join(__dirname, 'out/mesh', id + '_anim.json'), JSON.stringify(A));
  console.log(id, 'lines', lit, '/', nV, 'vertices white');
}
