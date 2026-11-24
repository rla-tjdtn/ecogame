// v6 조각 엔진: JS 로 프리미티브(둥근 원뿔·타원체·둥근 상자)를 쌓아 몸을 조각하고, WebGL 레이마칭 → 깊이·법선 → 선화
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const V = {
  add: (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]], sub: (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]], mul: (a, k) => [a[0] * k, a[1] * k, a[2] * k],
  dot: (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2], cross: (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]],
  len: a => Math.hypot(a[0], a[1], a[2]), lerp: (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t],
};
V.norm = a => { const l = V.len(a) || 1; return [a[0] / l, a[1] / l, a[2] / l]; };
// 틀: 원점 + 축(x 괴물의 왼쪽(+x), y 위, z 앞)
class Frame {
  constructor(o = [0, 0, 0], x = [1, 0, 0], y = [0, 1, 0], z = [0, 0, 1]) { Object.assign(this, { o, x, y, z }); }
  d(v) { return V.add(V.add(V.mul(this.x, v[0]), V.mul(this.y, v[1])), V.mul(this.z, v[2])); }
  p(v) { return V.add(this.o, this.d(v)); }
  at(v) { return new Frame(this.p(v), this.x, this.y, this.z); }
  rot(rx = 0, ry = 0, rz = 0) { // ry: 좌우, rx: +면 앞으로 숙임(y→z), rz: +면 x→y
    const D = Math.PI / 180; const r = (f, u, w, a) => { const c = Math.cos(a * D), s = Math.sin(a * D); const n = new Frame(f.o, f.x, f.y, f.z); n[u] = V.add(V.mul(f[u], c), V.mul(f[w], s)); n[w] = V.sub(V.mul(f[w], c), V.mul(f[u], s)); return n; };
    let f = this; if (ry) f = r(f, 'z', 'x', ry); if (rx) f = r(f, 'y', 'z', rx); if (rz) f = r(f, 'x', 'y', rz); return f;
  }
  sc(k) { return new Frame(this.o, V.mul(this.x, k), V.mul(this.y, k), V.mul(this.z, k)); }
  mir() { return new Frame(this.o, V.mul(this.x, -1), this.y, this.z); }
  static along(o, dir, front = [0, 0, 1]) { const y = V.norm(dir); let x = V.cross(y, front); if (V.len(x) < 1e-3) x = V.cross(y, [1, 0, 0]); x = V.norm(x); return new Frame(o, x, y, V.cross(x, y)); } // y = dir, z ≈ front
}
function quat(x, y, z) {
  const m = [[x[0], y[0], z[0]], [x[1], y[1], z[1]], [x[2], y[2], z[2]]], t = m[0][0] + m[1][1] + m[2][2];
  if (t > 0) { const s = Math.sqrt(t + 1) * 2; return [(m[2][1] - m[1][2]) / s, (m[0][2] - m[2][0]) / s, (m[1][0] - m[0][1]) / s, s / 4]; }
  if (m[0][0] > m[1][1] && m[0][0] > m[2][2]) { const s = Math.sqrt(1 + m[0][0] - m[1][1] - m[2][2]) * 2; return [s / 4, (m[0][1] + m[1][0]) / s, (m[0][2] + m[2][0]) / s, (m[2][1] - m[1][2]) / s]; }
  if (m[1][1] > m[2][2]) { const s = Math.sqrt(1 + m[1][1] - m[0][0] - m[2][2]) * 2; return [(m[0][1] + m[1][0]) / s, s / 4, (m[1][2] + m[2][1]) / s, (m[0][2] - m[2][0]) / s]; }
  const s = Math.sqrt(1 + m[2][2] - m[0][0] - m[1][1]) * 2; return [(m[0][2] + m[2][0]) / s, (m[1][2] + m[2][1]) / s, s / 4, (m[1][0] - m[0][1]) / s];
}
function fq(f) { const L = [V.len(f.x), V.len(f.y), V.len(f.z)], x = V.norm(f.x), y = V.norm(f.y); return { L, q: quat(x, y, V.cross(x, y)) }; }
class Body {
  constructor() { this.groups = []; this.g = null; }
  // 그룹: k 안쪽 부드러움, kg 앞 그룹들과 섞는 부드러움(0 = 딱 끊김), amp/freq 울퉁불퉁, mat 0 살 1 붉은 2 어두운 속 4 흰 뼈
  group(o = {}) { this.g = Object.assign({ mat: 0, k: .12, kg: 0, amp: 0, freq: 3, prims: [] }, o); this.groups.push(this.g); return this; }
  _(p) { if (!this.g) this.group(); if (p.k == null) p.k = this.g.k; p.op = p.op || 0; this.g.prims.push(p); return this; }
  cone(a, b, ra, rb, o = {}) { return this._({ t: 0, a, b, ra, rb: rb == null ? ra : rb, ...o }); }
  ball(c, r, o = {}) { return this._({ t: 0, a: c, b: c, ra: r, rb: r, ...o }); }
  ell(f, r, o = {}) { const { L, q } = fq(f); return this._({ t: 1, a: f.o, b: [r[0] * L[0], r[1] * L[1], r[2] * L[2]], q, ra: 0, rb: 0, ...o }); }
  box(f, h, r = .05, o = {}) { const { L, q } = fq(f); return this._({ t: 2, a: f.o, b: [h[0] * L[0], h[1] * L[1], h[2] * L[2]], q, ra: r, rb: 0, ...o }); }
  // 주름 홈: c 중심, n 홈을 가로지르는 방향, w 반폭, dep 깊이, R 영향 반경
  groove(c, n, w, dep, R, o = {}) { n = V.norm(n); return this._({ t: 3, op: 2, k: 0, a: c, ra: w, b: n, rb: dep, q: [o.bow || 0, o.wob ?? .12, o.wf ?? 4, R] }); }
  // 곡선 관(캣멀롬 → 둥근 원뿔들). rs = 점마다 반지름
  tube(pts, rs, o = {}) {
    const n = pts.length, per = (o.per || 4) + 1; const cm = (a, b, c, d, t) => .5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t * t * t);
    const r = i => Array.isArray(rs) ? rs[Math.min(i, rs.length - 1)] : rs; let prev = null, pr = 0; const start = (this.g || this.group().g).prims.length;
    for (let i = 0; i < n - 1; i++) {
      const I = [Math.max(0, i - 1), i, i + 1, Math.min(n - 1, i + 2)], P = I.map(j => pts[j]), R = I.map(r);
      for (let j = 0; j <= per; j++) { if (i > 0 && j === 0) continue; const t = j / per, q = [0, 1, 2].map(k => cm(P[0][k], P[1][k], P[2][k], P[3][k], t)), rad = Math.max(.004, cm(R[0], R[1], R[2], R[3], t)); if (prev) this.cone(prev, q, pr, rad, o); prev = q; pr = rad; }
    }
    const ps = this.g.prims, m = ps.length - start; for (let i = 0; i < m; i++) ps[start + i].ex = m < 2 ? 0 : i === 0 ? 1 : i === m - 1 ? 3 : 2;
    return this;
  }
  data() {
    const prims = [], groups = [];
    for (const g of this.groups) {
      if (!g.prims.length) continue; const start = prims.length; let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9];
      for (const p of g.prims) { prims.push(p); if (p.op) continue; const rr = p.t === 0 ? [[p.a, p.ra], [p.b, p.rb]] : [[p.a, p.t === 1 ? Math.max(...p.b) : V.len(p.b)]]; for (const [c, r] of rr) for (let i = 0; i < 3; i++) { mn[i] = Math.min(mn[i], c[i] - r); mx[i] = Math.max(mx[i], c[i] + r); } }
      const c = V.mul(V.add(mn, mx), .5); groups.push({ start, n: g.prims.length, c, r: V.len(V.sub(mx, c)) + g.amp + g.k * .3 + .02, mn, mx, amp: g.amp, freq: g.freq, mat: g.mat, kg: g.kg, rid: g.rid || 0, rf: g.rf || 6 });
    }
    const P = [], G = []; for (const p of prims) P.push(p.t, p.op, p.k, p.ex || 0, ...p.a, p.ra, ...p.b, p.rb, ...(p.q || [0, 0, 0, 1]));
    for (const g of groups) G.push(g.start, g.n, g.amp, g.freq, ...g.c, g.r, g.mat, g.kg, g.rid, g.rf);
    let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9]; for (const g of groups) for (let i = 0; i < 3; i++) { mn[i] = Math.min(mn[i], g.mn[i] - .2); mx[i] = Math.max(mx[i], g.mx[i] + .2); }
    return { P: P.map(x => +x.toFixed(4)), G: G.map(x => +x.toFixed(4)), np: prims.length, ng: groups.length, mn, mx };
  }
}
function render(spec, file) {
  file = path.resolve(file); const html = fs.readFileSync(path.join(__dirname, 'view.html'), 'utf8').replace('/*SPEC*/', () => 'const SPEC=' + JSON.stringify(spec) + ';'), h = file.replace(/\.png$/, '.html'); fs.writeFileSync(h, html);
  const tmp = path.join(process.env.TEMP, 'edge-sculpt-' + process.pid);
  try { fs.unlinkSync(file); } catch (e) {}
  execFileSync('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', ['--headless=new', '--use-angle=' + (process.env.ANGLE || 'd3d11'), '--mute-audio', '--hide-scrollbars', '--force-device-scale-factor=1', `--window-size=${spec.W},${spec.H}`, '--timeout=240000', `--user-data-dir=${tmp}`, `--screenshot=${file}`, 'file:///' + encodeURI(h.split(path.sep).join('/'))], { stdio: 'ignore', timeout: 300000 });
  fs.unlinkSync(h); try { fs.rmSync(tmp, { recursive: true, force: true }); } catch (e) {}
  return fs.existsSync(file);
}
module.exports = { V, Frame, Body, render };
