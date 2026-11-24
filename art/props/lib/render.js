// 음파 화면처럼 그려 보기: 검은 몸(깊이 버퍼) + 흰 선(가려진 곳 빼고). 소품 하나를 여러 각도로.
//   renderViews(items, opts) → PNG Buffer.  items = [{ build: Model.build() 결과, label }]  (행 = 항목, 열 = 각도)
const path = require('path');
const { PNG } = require(path.join(__dirname, '..', '..', 'creatures', 'source', 'game', 'node_modules', 'pngjs'));
const { sub, add, mulv, dot, cross, len, norm, ringSeg } = require('./model.js');

// 보는 위치에 따른 실루엣(게임 SonarGeometry 와 같은 식)
function silhouettes(view, cam) {
  const out = [];
  for (const v of view) {
    if (v.t === 'b') {
      const r = v.r1, c = v.a, toC = sub(c, cam), D = len(toC); if (D <= r * 1.05) continue;
      const dir = mulv(toC, 1 / D), cc = sub(c, mulv(dir, r * r / D)), rr = r * Math.sqrt(1 - r * r / (D * D));
      let u = cross(dir, [0, 1, 0]); if (len(u) < 0.01) u = cross(dir, [1, 0, 0]); u = norm(u); const w = norm(cross(dir, u));
      const k = ringSeg(r); let prev = null;
      for (let i = 0; i <= k; i++) { const t = i / k * Math.PI * 2; const p = add(cc, add(mulv(u, Math.cos(t) * rr), mulv(w, Math.sin(t) * rr))); if (prev) out.push([prev, p]); prev = p; }
      continue;
    }
    const a = v.a, b = v.b, d = sub(b, a), L = len(d); if (L < 1e-4) continue;
    const X = mulv(d, 1 / L); const up = Math.abs(X[1]) > 0.95 ? [1, 0, 0] : [0, 1, 0]; const Y = norm(cross(X, up)), Z = norm(cross(X, Y));
    const mid = mulv(add(a, b), 0.5); const lv = sub(cam, mid); const ly = dot(lv, Y), lz = dot(lv, Z);
    const r = (v.r1 + v.r2) / 2; const dd = Math.hypot(ly, lz); if (dd <= r * 1.02) continue;
    const phi0 = Math.atan2(lz, ly), th = Math.acos(r / dd);
    for (const s of [-1, 1]) { const ph = phi0 + s * th; const n = add(mulv(Y, Math.cos(ph)), mulv(Z, Math.sin(ph))); out.push([add(a, mulv(n, v.r1)), add(b, mulv(n, v.r2))]); }
    if (r < 0.3) { const n1 = add(mulv(Y, Math.cos(phi0 + th)), mulv(Z, Math.sin(phi0 + th))), n2 = add(mulv(Y, Math.cos(phi0 - th)), mulv(Z, Math.sin(phi0 - th)));
      out.push([add(a, mulv(n1, v.r1)), add(a, mulv(n2, v.r1))]); out.push([add(b, mulv(n1, v.r2)), add(b, mulv(n2, v.r2))]); }
  }
  return out;
}

function bboxOf(builds) {
  let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9];
  for (const b of builds) { for (const s of b.seg) for (const p of [s.slice(0, 3), s.slice(3)]) for (let k = 0; k < 3; k++) { mn[k] = Math.min(mn[k], p[k]); mx[k] = Math.max(mx[k], p[k]); }
    for (let i = 0; i < b.P.length; i += 3) for (let k = 0; k < 3; k++) { mn[k] = Math.min(mn[k], b.P[i + k]); mx[k] = Math.max(mx[k], b.P[i + k]); } }
  return { mn, mx };
}

// 한 칸 그리기
function drawCell(img, W, ox, oy, cw, ch, build, cam, target, fov) {
  const F = norm(sub(target, cam)); const R = norm(cross(F, [0, 1, 0])); const U = cross(R, F);
  const f = (ch / 2) / Math.tan(fov / 2);
  const proj = p => { const d = sub(p, cam); const z = dot(d, F); return [ox + cw / 2 + dot(d, R) / z * f, oy + ch / 2 - dot(d, U) / z * f, z]; };
  const zb = new Float32Array(cw * ch).fill(Infinity);
  const P = build.P;
  for (let t = 0; t < P.length; t += 9) {
    const a = proj([P[t], P[t + 1], P[t + 2]]), b = proj([P[t + 3], P[t + 4], P[t + 5]]), c = proj([P[t + 6], P[t + 7], P[t + 8]]);
    if (a[2] < 0.1 || b[2] < 0.1 || c[2] < 0.1) continue;
    const x0 = Math.max(ox, Math.floor(Math.min(a[0], b[0], c[0]))), x1 = Math.min(ox + cw - 1, Math.ceil(Math.max(a[0], b[0], c[0])));
    const y0 = Math.max(oy, Math.floor(Math.min(a[1], b[1], c[1]))), y1 = Math.min(oy + ch - 1, Math.ceil(Math.max(a[1], b[1], c[1])));
    const area = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]); if (Math.abs(area) < 1e-9) continue;
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
      const px = x + 0.5, py = y + 0.5;
      const w0 = ((b[0] - px) * (c[1] - py) - (b[1] - py) * (c[0] - px)) / area, w1 = ((c[0] - px) * (a[1] - py) - (c[1] - py) * (a[0] - px)) / area, w2 = 1 - w0 - w1;
      if (w0 < 0 || w1 < 0 || w2 < 0) continue;
      const iz = w0 / a[2] + w1 / b[2] + w2 / c[2]; const z = 1 / iz; const k = (y - oy) * cw + (x - ox);
      if (z < zb[k]) zb[k] = z;
    }
  }
  // 몸(아주 어두운 회색: 모양 확인용) — 게임에서는 완전 검정
  for (let y = 0; y < ch; y++) for (let x = 0; x < cw; x++) if (zb[y * cw + x] < Infinity) { const i = ((oy + y) * W + ox + x) * 4; img[i] = img[i + 1] = img[i + 2] = 18; }
  const lines = build.seg.map(s => [s.slice(0, 3), s.slice(3)]).concat(silhouettes(build.view, cam));
  for (const [A, B] of lines) {
    const pa = proj(A), pb = proj(B); if (pa[2] < 0.1 || pb[2] < 0.1) continue;
    const n = Math.max(2, Math.ceil(Math.hypot(pb[0] - pa[0], pb[1] - pa[1]) * 2));
    for (let i = 0; i <= n; i++) {
      const t = i / n; const P3 = [A[0] + (B[0] - A[0]) * t, A[1] + (B[1] - A[1]) * t, A[2] + (B[2] - A[2]) * t]; const q = proj(P3);
      const x = Math.floor(q[0]), y = Math.floor(q[1]); if (x < ox || y < oy || x >= ox + cw || y >= oy + ch) continue;
      // 가려짐: 둘레 3x3 중 가장 먼 깊이보다 충분히 앞이면 보임(선은 면 모서리 위에 있다)
      let zmax = 0; for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) { const xx = x + dx - ox, yy = y + dy - oy; if (xx >= 0 && yy >= 0 && xx < cw && yy < ch) zmax = Math.max(zmax, zb[yy * cw + xx]); }
      if (q[2] > zmax + 0.06 + q[2] * 0.004) continue;
      for (const [dx, dy] of [[0, 0], [1, 0], [0, 1], [1, 1]]) { const xx = x + dx, yy = y + dy; if (xx < ox + cw && yy < oy + ch) { const i2 = (yy * W + xx) * 4; img[i2] = img[i2 + 1] = img[i2 + 2] = 255; } }
    }
  }
}

// rows = [{build}], angles = [[yaw°, pitch°]] (yaw 0 = 소품 앞(-z 쪽)에서)
function renderGrid(rows, opts = {}) {
  const angles = opts.angles || [[-35, 22], [40, 30], [180 - 30, 18]];
  const cw = opts.cw || 360, ch = opts.ch || 300, W = cw * angles.length, H = ch * rows.length;
  const png = new PNG({ width: W, height: H }); const img = png.data; for (let i = 0; i < img.length; i += 4) { img[i] = img[i + 1] = img[i + 2] = 0; img[i + 3] = 255; }
  const { mn, mx } = bboxOf(rows.map(r => r.build));
  const ctr = mulv(add(mn, mx), 0.5), rad = Math.max(1, len(sub(mx, mn)) / 2);
  const fov = 40 * Math.PI / 180, dist = rad / Math.sin(fov / 2) * 1.05;
  rows.forEach((r, ri) => angles.forEach(([yd, pd], ai) => {
    const y = yd * Math.PI / 180, p = pd * Math.PI / 180;
    const cam = add(ctr, [Math.sin(y) * Math.cos(p) * dist, Math.sin(p) * dist, -Math.cos(y) * Math.cos(p) * dist]);
    drawCell(img, W, ai * cw, ri * ch, cw, ch, r.build, cam, ctr, fov);
    // 행 구분선(회색)
    for (let x = 0; x < W; x++) { const i = ((ri * ch) * W + x) * 4; if (ri > 0) img[i] = img[i + 1] = img[i + 2] = 70; }
  }));
  for (let ai = 1; ai < angles.length; ai++) for (let y = 0; y < H; y++) { const i = (y * W + ai * cw) * 4; img[i] = img[i + 1] = img[i + 2] = 70; }
  return PNG.sync.write(png);
}

// 게임 음파 선 수(선 파트 수): 정적 선분을 SegmentLength(2.5)로 자른 수 + 실루엣(원통 2줄씩, 구 원 조각)
function lineCost(build, segLen = 2.5) {
  let n = 0; for (const s of build.seg) n += Math.max(1, Math.ceil(Math.hypot(s[3] - s[0], s[4] - s[1], s[5] - s[2]) / segLen));
  let v = 0; for (const it of build.view) { if (it.t === 'b') v += ringSeg(it.r1); else { const L = Math.hypot(it.b[0] - it.a[0], it.b[1] - it.a[1], it.b[2] - it.a[2]); v += 2 * Math.max(1, Math.ceil(L / segLen)) + ((it.r1 + it.r2) / 2 < 0.3 ? 2 : 0); } }
  return { static: n, view: v, total: n + v, segs: build.seg.length, views: build.view.length };
}
module.exports = { renderGrid, silhouettes, lineCost };
