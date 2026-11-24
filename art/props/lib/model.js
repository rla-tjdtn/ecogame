// 소품 메시 모델링 라이브러리(절차적 모델링 → 메시 + 음파 선 데이터).
// 좌표 = 소품 좌표계(로블록스 스터드, x 오른쪽, y 위, -z = 소품이 '보는' 방향 = PropMesh.dress 에 넘긴 CFrame 의 LookVector).
// 각 기본 도형은 (1) 검은 몸 메시(삼각형) (2) 그 도형다운 음파 선(정적 선분) (3) 보는 위치에 따라 달라지는 실루엣(원통·원뿔·구)을 낸다.
// 다른 단단한 도형 속에 묻힌 선 구간은 build() 에서 잘라 낸다(SonarWorld 의 묻힌 모서리 제거와 같은 생각).
//
//   const m = new Model();
//   m.box([0, 1, 0], [2, 2, 2], { bevel: 0.08 });
//   m.cyl([0, 0, 0], [0, 3, 0], 0.2);
//   m.push(m.T(1, 0, 0).mul(m.Ry(Math.PI / 4))); ... m.pop();
//   const out = m.build(); // { P, N, I, seg: [[ax,ay,az,bx,by,bz]...], view: [{t:'c'|'b', a, b, r1, r2}] }

// ── 3x4 변환(열 X·Y·Z + 위치) ──
class Xf {
  constructor(m) { this.m = m || [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]; } // [Xx,Xy,Xz, Yx,Yy,Yz, Zx,Zy,Zz, px,py,pz]
  mul(o) { const a = this.m, b = o.m, r = new Array(12);
    for (let c = 0; c < 3; c++) for (let k = 0; k < 3; k++) r[c * 3 + k] = a[k] * b[c * 3] + a[3 + k] * b[c * 3 + 1] + a[6 + k] * b[c * 3 + 2];
    for (let k = 0; k < 3; k++) r[9 + k] = a[k] * b[9] + a[3 + k] * b[10] + a[6 + k] * b[11] + a[9 + k];
    return new Xf(r); }
  p(v) { const a = this.m; return [a[0] * v[0] + a[3] * v[1] + a[6] * v[2] + a[9], a[1] * v[0] + a[4] * v[1] + a[7] * v[2] + a[10], a[2] * v[0] + a[5] * v[1] + a[8] * v[2] + a[11]]; }
  v(v) { const a = this.m; return [a[0] * v[0] + a[3] * v[1] + a[6] * v[2], a[1] * v[0] + a[4] * v[1] + a[7] * v[2], a[2] * v[0] + a[5] * v[1] + a[8] * v[2]]; }
  inv() { const a = this.m; const r = [a[0], a[3], a[6], a[1], a[4], a[7], a[2], a[5], a[8], 0, 0, 0]; const x = new Xf(r); const t = x.v([a[9], a[10], a[11]]); r[9] = -t[0]; r[10] = -t[1]; r[11] = -t[2]; return x; }
  // (축마다 길이가 다를 수 있다: scale)
}
const T = (x, y, z) => new Xf([1, 0, 0, 0, 1, 0, 0, 0, 1, x, y, z]);
const Rx = a => { const c = Math.cos(a), s = Math.sin(a); return new Xf([1, 0, 0, 0, c, s, 0, -s, c, 0, 0, 0]); };
const Ry = a => { const c = Math.cos(a), s = Math.sin(a); return new Xf([c, 0, -s, 0, 1, 0, s, 0, c, 0, 0, 0]); };
const Rz = a => { const c = Math.cos(a), s = Math.sin(a); return new Xf([c, s, 0, -s, c, 0, 0, 0, 1, 0, 0, 0]); };
const S = (x, y, z) => new Xf([x, 0, 0, 0, y, 0, 0, 0, z, 0, 0, 0]);

// ── 벡터 ──
const add = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const mulv = (a, s) => [a[0] * s, a[1] * s, a[2] * s];
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const len = a => Math.hypot(a[0], a[1], a[2]);
const norm = a => { const l = len(a) || 1; return [a[0] / l, a[1] / l, a[2] / l]; };
const lerp = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
// 축 d 에 수직인 두 단위 벡터
function basis(d) { const up = Math.abs(d[1]) > 0.95 ? [1, 0, 0] : [0, 1, 0]; const u = norm(cross(d, up)); const w = norm(cross(d, u)); return [u, w]; }
// 게임과 같은 원 조각 수(SonarGeometry ringSegments)
const ringSeg = r => Math.max(8, Math.min(24, Math.floor(r * 5) + 6));

// ── 2D 다각형 ──
function polyArea(pts) { let a = 0; for (let i = 0; i < pts.length; i++) { const p = pts[i], q = pts[(i + 1) % pts.length]; a += p[0] * q[1] - q[0] * p[1]; } return a / 2; }
function earcut(pts) {
  // 단순 귀 자르기(반시계 다각형) → 삼각형 인덱스
  const idx = pts.map((_, i) => i); if (polyArea(pts) < 0) idx.reverse();
  const tris = []; let guard = 0;
  const inTri = (p, a, b, c) => { const s = (u, v, w) => (v[0] - u[0]) * (w[1] - u[1]) - (v[1] - u[1]) * (w[0] - u[0]); const d1 = s(p, a, b), d2 = s(p, b, c), d3 = s(p, c, a); return !((d1 < 0 || d2 < 0 || d3 < 0) && (d1 > 0 || d2 > 0 || d3 > 0)); };
  while (idx.length > 3 && guard++ < 10000) {
    let cut = false;
    for (let i = 0; i < idx.length; i++) {
      const ia = idx[(i + idx.length - 1) % idx.length], ib = idx[i], ic = idx[(i + 1) % idx.length];
      const a = pts[ia], b = pts[ib], c = pts[ic];
      if ((b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]) <= 1e-9) continue;
      let ok = true; for (const j of idx) if (j !== ia && j !== ib && j !== ic && inTri(pts[j], a, b, c)) { ok = false; break; }
      if (!ok) continue;
      tris.push([ia, ib, ic]); idx.splice(i, 1); cut = true; break;
    }
    if (!cut) break;
  }
  if (idx.length === 3) tris.push([idx[0], idx[1], idx[2]]);
  return tris;
}
function pointInPoly(x, y, pts) { let c = false; for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) { const a = pts[i], b = pts[j]; if ((a[1] > y) !== (b[1] > y) && x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0]) c = !c; } return c; }
// 둥근 모서리 사각형 등 2D 도우미
function roundRect(w, h, r, n = 4) { const out = []; const cs = [[w / 2 - r, h / 2 - r, 0], [-w / 2 + r, h / 2 - r, 1], [-w / 2 + r, -h / 2 + r, 2], [w / 2 - r, -h / 2 + r, 3]];
  for (const [cx, cy, q] of cs) for (let i = 0; i <= n; i++) { const a = (q + i / n) * Math.PI / 2; out.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]); } return r > 0 ? out : [[w / 2, h / 2], [-w / 2, h / 2], [-w / 2, -h / 2], [w / 2, -h / 2]]; }
function circle2(r, n = 16, cx = 0, cy = 0) { const o = []; for (let i = 0; i < n; i++) { const a = i / n * Math.PI * 2; o.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]); } return o; }
function arc2(cx, cy, r, a0, a1, n) { const o = []; for (let i = 0; i <= n; i++) { const a = a0 + (a1 - a0) * i / n; o.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]); } return o; }

class Model {
  constructor() { this.stack = [new Xf()]; this.prims = []; }
  get X() { return this.stack[this.stack.length - 1]; }
  push(x) { this.stack.push(this.X.mul(x)); return this; }
  pop() { this.stack.pop(); return this; }
  with(x, fn) { this.push(x); try { fn(this); } finally { this.pop(); } return this; }
  // 좌우 대칭 복제: fn(s) 를 s = -1, 1 로
  mirrorX(fn) { for (const s of [-1, 1]) { this.push(S(s, 1, 1)); fn(s); this.pop(); } return this; }
  _prim(p) { p.xf = this.X; p.solid = p.o.solid !== false; this.prims.push(p); return p; }

  // 상자: c = 가운데, s = 크기. o.bevel 모따기, o.lines: 'all'|'none'|'X'|'Y'|'Z'|'XZ' 등(그 축 방향 모서리만)|'top'|'outline'
  box(c, s, o = {}) { return this._prim({ k: 'box', c, s, o }); }
  // 바닥 높이 y0 에서 위로 h 인 상자(x,z 가운데)
  slab(x, y0, z, sx, h, sz, o) { return this.box([x, y0 + h / 2, z], [sx, h, sz], o); }
  // 원통 a→b 반지름 r. o.seg, o.rings: [t...] 중간 원, o.caps false 면 끝 원 없음, o.line true 면 한 줄(가는 막대)
  cyl(a, b, r, o = {}) { return this._prim({ k: 'cone', a, b, r1: r, r2: r, o: o.line ? { ...o, solid: false } : o }); }
  cone(a, b, r1, r2, o = {}) { return this._prim({ k: 'cone', a, b, r1, r2, o }); }
  sphere(c, r, o = {}) { return this._prim({ k: 'sphere', c, r, o }); }
  // 회전체: profile = [[r, y]...] (아래→위), y 축 둘레. o.seg, o.at([x,y,z]) 가운데
  lathe(profile, o = {}) { return this._prim({ k: 'lathe', profile, o }); }
  // 2D 다각형(xy 평면, 반시계) 을 z 로 depth 만큼 밀어낸 기둥(가운데 z=0). o.z0 시작 z
  extrude(poly, depth, o = {}) { return this._prim({ k: 'extrude', poly, depth, o }); }
  // 관(점 목록을 잇는 원통들, 마디에 구). r 이 아주 작으면 선 한 줄
  tube(pts, r, o = {}) { for (let i = 0; i + 1 < pts.length; i++) this.cyl(pts[i], pts[i + 1], r, { ...o, caps: o.caps ?? false, ends: i === 0 ? 'a' : i === pts.length - 2 ? 'b' : '' });
    if (r >= 0.06) for (let i = 1; i + 1 < pts.length; i++) this.sphere(pts[i], r, { lines: false, seg: o.seg }); return this; }
  // 도넛: c 가운데, 축 axis(단위), 큰 반지름 R, 관 반지름 r
  torus(c, axis, R, r, o = {}) { return this._prim({ k: 'torus', c, axis, R, r, o }); }
  // 둥근 상자(쿠션·매트리스): 모서리 반지름 rad
  cushion(c, s, rad, o = {}) { return this._prim({ k: 'cushion', c, s, rad, o }); }
  // 몸 없는 장식 선(이음매·글자·홈)
  line(pts, o = {}) { return this._prim({ k: 'line', pts, o: { ...o, solid: false } }); }
  // 몸만(선 없음) 이나 선만인 것은 o.lines = 'none' / o.solid = false

  // ── 빌드 ──
  build() {
    const tri = [], seg = [], view = [];
    for (const p of this.prims) {
      const t0 = tri.length; emit(p, tri, seg, view);
      // 거울 변환(행렬식 < 0)이면 삼각형 감김을 뒤집는다(한쪽 면만 그려지는 메시)
      const m = p.xf.m; const det = m[0] * (m[4] * m[8] - m[5] * m[7]) - m[3] * (m[1] * m[8] - m[2] * m[7]) + m[6] * (m[1] * m[5] - m[2] * m[4]);
      if (det < 0) for (let i = t0; i < tri.length; i++) { const t = tri[i]; tri[i] = [t[0], t[2], t[1]]; }
    }
    // 묻힌 선 자르기: 선분 위 점이 (자기 말고) 다른 단단한 도형 안이면 그 구간을 뺀다
    const solids = this.prims.filter(p => p.solid);
    const insideAny = (pt, self) => { for (const q of solids) if (q !== self && inside(q, pt)) return true; return false; };
    const out = [];
    for (const s of seg) {
      const a = s.a, b = s.b, L = len(sub(b, a)); if (L < 0.03) continue;
      const n = Math.max(2, Math.ceil(L / 0.06));
      let runStart = null;
      for (let i = 0; i <= n; i++) {
        const t = i / n; const pt = lerp(a, b, t);
        const keep = i < n ? !insideAny(pt, s.p) : false;
        const keepEnd = i === n ? !insideAny(pt, s.p) : keep;
        if (i < n) { if (keep && runStart === null) runStart = t; if (!keep && runStart !== null) { if ((t - runStart) * L > 0.06) out.push([lerp(a, b, runStart), lerp(a, b, t)]); runStart = null; } }
        else if (runStart !== null) { if ((1 - runStart) * L > 0.06) out.push([lerp(a, b, runStart), keepEnd ? b : lerp(a, b, 1 - 0.5 / n)]); }
      }
    }
    // 같은 선 겹침 제거
    const key = (a, b) => { const r = v => v.map(x => Math.round(x * 50)).join(','); const ka = r(a), kb = r(b); return ka < kb ? ka + '|' + kb : kb + '|' + ka; };
    const seen = new Set(), segs = [];
    for (const [a, b] of out) { const k = key(a, b); if (!seen.has(k)) { seen.add(k); segs.push([...a, ...b]); } }
    // 삼각형 → 버퍼(면 법선, 정점 공유 없음)
    const P = new Float32Array(tri.length * 9), N = new Float32Array(tri.length * 9), I = new Uint32Array(tri.length * 3);
    tri.forEach((t, i) => { const n = norm(cross(sub(t[1], t[0]), sub(t[2], t[0]))); for (let k = 0; k < 3; k++) { P.set(t[k], i * 9 + k * 3); N.set(n, i * 9 + k * 3); I[i * 3 + k] = i * 3 + k; } });
    return { P, N, I, tris: tri.length, seg: segs, view };
  }
}

// ── 도형별: 메시·선·실루엣 ──
function quad(tri, a, b, c, d) { tri.push([a, b, c], [a, c, d]); }
function lineAxisOk(o, axis) { const l = o.lines ?? 'all'; if (l === 'none') return false; if (l === 'all') return true; if (l === 'top') return axis !== 'Y'; return l.includes(axis); }
function emit(p, tri, seg, view) {
  const X = p.xf, o = p.o;
  const addSeg = (a, b) => seg.push({ a: X.p(a), b: X.p(b), p });
  if (p.k === 'box' || p.k === 'cushion') {
    const [cx, cy, cz] = p.c, [sx, sy, sz] = p.s.map(v => v / 2);
    const bv = Math.min(p.k === 'cushion' ? p.rad : (o.bevel || 0), sx * 0.9, sy * 0.9, sz * 0.9);
    // 메시: 모따기 상자(26면) 또는 그냥 상자. cushion 은 모따기 2단(둥글게)
    const steps = p.k === 'cushion' ? 3 : (bv > 0 ? 1 : 0);
    roundedBoxMesh(tri, X, p.c, [sx, sy, sz], bv, steps);
    // 선: 12 모서리(모따기면 그 가운데), 축 지정이면 그 축 모서리만
    const lo = o.lines ?? 'all';
    if (lo !== 'none') {
      const ins = bv * (steps === 3 ? 0.25 : steps ? 0.3 : 0); // (둥근 모서리: 0.25r 이면 선이 면 밖 0.06r — 0.3r 은 면 속에 묻힌다)
      const ex = sx - ins, ey = sy - ins, ez = sz - ins;
      const want = (ax) => lineAxisOk(o, ax);
      for (const a of [-1, 1]) for (const b of [-1, 1]) {
        if (want('X') && (lo !== 'top' || a > 0)) addSeg([cx - sx + (bv ? ins : 0), cy + a * ey, cz + b * ez], [cx + sx - (bv ? ins : 0), cy + a * ey, cz + b * ez]);
        if (want('Z') && (lo !== 'top' || a > 0)) addSeg([cx + b * ex, cy + a * ey, cz - sz + (bv ? ins : 0)], [cx + b * ex, cy + a * ey, cz + sz - (bv ? ins : 0)]);
        if (want('Y') && lo !== 'top') addSeg([cx + a * ex, cy - sy + (bv ? ins : 0), cz + b * ez], [cx + a * ex, cy + sy - (bv ? ins : 0), cz + b * ez]);
      }
      if (lo === 'top') { /* 위 둘레만(위에서 x, z 방향 4개) — 위 반복문에서 a>0 만 */ }
    }
    return;
  }
  if (p.k === 'cone') {
    const a = p.a, b = p.b, d = sub(b, a), L = len(d); if (L < 1e-4) return;
    // 한 줄 막대(line: true)는 몸 없이 선만: 게임 선 굵기(0.02~0.075)가 막대보다 가늘어 몸 속에 묻혀 안 보인다
    if (o.line && o.lines !== 'none') { addSeg(a, b); return; }
    const dir = mulv(d, 1 / L); const [u, w] = basis(dir);
    const rm = Math.max(p.r1, p.r2);
    const n = o.seg || Math.max(8, Math.min(24, Math.round(rm * 10) + 8));
    const ring = (c, r) => { const pts = []; for (let i = 0; i < n; i++) { const t = i / n * Math.PI * 2; pts.push(add(c, add(mulv(u, Math.cos(t) * r), mulv(w, Math.sin(t) * r)))); } return pts; };
    const A = ring(a, p.r1), B = ring(b, p.r2);
    for (let i = 0; i < n; i++) { const j = (i + 1) % n; quad(tri, X.p(A[i]), X.p(A[j]), X.p(B[j]), X.p(B[i])); }
    if (o.capMesh !== false) for (let i = 1; i + 1 < n; i++) { tri.push([X.p(A[0]), X.p(A[i + 1]), X.p(A[i])]); tri.push([X.p(B[0]), X.p(B[i]), X.p(B[i + 1])]); }
    if (o.lines === 'none') return;
    if (o.line) { addSeg(a, b); return; } // 가는 막대 = 한 줄
    const thin = rm < 0.3;
    const rings = [];
    if (!thin && o.caps !== false) { rings.push([0, p.r1]); rings.push([1, p.r2]); }
    for (const t of o.rings || []) rings.push([t, p.r1 + (p.r2 - p.r1) * t]);
    for (const [t, r] of rings) { if (r < 0.05) continue; const c = lerp(a, b, t); const k = ringSeg(r); let prev = null; for (let i = 0; i <= k; i++) { const q = i / k * Math.PI * 2; const pt = add(c, add(mulv(u, Math.cos(q) * r), mulv(w, Math.sin(q) * r))); if (prev) addSeg(prev, pt); prev = pt; } }
    // 실루엣(보는 위치마다 2줄) — 끝 닫기(가는 것)는 게임 쪽이
    if (o.silhouette !== false) view.push({ t: 'c', a: X.p(a), b: X.p(b), r1: p.r1 * scaleOf(X, u), r2: p.r2 * scaleOf(X, u) });
    return;
  }
  if (p.k === 'sphere') {
    const n = o.seg || 12; const m = Math.max(4, Math.round(n / 2));
    const pt = (i, j) => { const th = i / m * Math.PI, ph = j / n * Math.PI * 2; return X.p(add(p.c, [Math.sin(th) * Math.cos(ph) * p.r, Math.cos(th) * p.r, Math.sin(th) * Math.sin(ph) * p.r])); };
    for (let i = 0; i < m; i++) for (let j = 0; j < n; j++) quad(tri, pt(i, j), pt(i + 1, j), pt(i + 1, j + 1), pt(i, j + 1));
    if (o.lines !== 'none' && o.lines !== false) view.push({ t: 'b', a: X.p(p.c), b: X.p(p.c), r1: p.r * scaleOf(X, [1, 0, 0]), r2: p.r });
    return;
  }
  if (p.k === 'lathe') {
    const pr = p.profile, n = o.seg || 20, c0 = o.at || [0, 0, 0];
    const P3 = (r, y, q) => X.p([c0[0] + Math.cos(q) * r, c0[1] + y, c0[2] + Math.sin(q) * r]);
    for (let s = 0; s + 1 < pr.length; s++) for (let i = 0; i < n; i++) { const q0 = i / n * Math.PI * 2, q1 = (i + 1) / n * Math.PI * 2; quad(tri, P3(pr[s][0], pr[s][1], q0), P3(pr[s + 1][0], pr[s + 1][1], q0), P3(pr[s + 1][0], pr[s + 1][1], q1), P3(pr[s][0], pr[s][1], q1)); }
    if (o.capMesh !== false) for (const e of [0, pr.length - 1]) if (pr[e][0] > 0.01) for (let i = 0; i < n; i++) { const q0 = i / n * Math.PI * 2, q1 = (i + 1) / n * Math.PI * 2; tri.push([X.p([c0[0], c0[1] + pr[e][1], c0[2]]), P3(pr[e][0], pr[e][1], q0), P3(pr[e][0], pr[e][1], q1)]); }
    if (o.lines === 'none') return;
    // 고리: 꺾이는 곳(각 > crease°)과 양 끝
    const crease = (o.crease ?? 28) * Math.PI / 180;
    const ringAt = (r, y) => { if (r < 0.05) return; const k = ringSeg(r); let prev = null; for (let i = 0; i <= k; i++) { const q = i / k * Math.PI * 2; const pt = [c0[0] + Math.cos(q) * r, c0[1] + y, c0[2] + Math.sin(q) * r]; if (prev) addSeg(prev, pt); prev = pt; } };
    const ang = (i) => { const a = pr[i - 1], b = pr[i], c = pr[i + 1]; const d1 = norm([b[0] - a[0], b[1] - a[1], 0]), d2 = norm([c[0] - b[0], c[1] - b[1], 0]); return Math.acos(Math.max(-1, Math.min(1, d1[0] * d2[0] + d1[1] * d2[1]))); };
    const ringIdx = [0, pr.length - 1];
    for (let i = 1; i + 1 < pr.length; i++) if (ang(i) > crease) ringIdx.push(i);
    for (const i of o.rings || []) ringIdx.push(i);
    for (const i of [...new Set(ringIdx)]) ringAt(pr[i][0], pr[i][1]);
    // 실루엣: 꺾임 사이 구간마다 원뿔대 하나(완만한 곡선은 최대 3조각)
    const cuts = [...new Set(ringIdx)].sort((a, b) => a - b);
    for (let k = 0; k + 1 < cuts.length; k++) {
      const i0 = cuts[k], i1 = cuts[k + 1]; const parts = Math.min(3, i1 - i0);
      for (let q = 0; q < parts; q++) {
        const ia = i0 + Math.round((i1 - i0) * q / parts), ib = i0 + Math.round((i1 - i0) * (q + 1) / parts);
        const A = pr[ia], B = pr[ib]; if (Math.abs(B[1] - A[1]) < 0.08) continue; // 수평 원판은 실루엣 없음
        if (Math.max(A[0], B[0]) < 0.03) continue;
        view.push({ t: 'c', a: X.p([c0[0], c0[1] + A[1], c0[2]]), b: X.p([c0[0], c0[1] + B[1], c0[2]]), r1: A[0], r2: B[0] });
      }
    }
    return;
  }
  if (p.k === 'extrude') {
    const poly = p.poly, d = p.depth, z0 = o.z0 ?? -d / 2, z1 = z0 + d;
    const ccw = polyArea(poly) > 0 ? poly : [...poly].reverse();
    const tris2 = earcut(ccw);
    for (const [a, b, c] of tris2) { tri.push([X.p([...ccw[a], z1]), X.p([...ccw[b], z1]), X.p([...ccw[c], z1])]); tri.push([X.p([...ccw[a], z0]), X.p([...ccw[c], z0]), X.p([...ccw[b], z0])]); }
    for (let i = 0; i < ccw.length; i++) { const a = ccw[i], b = ccw[(i + 1) % ccw.length]; quad(tri, X.p([...a, z0]), X.p([...b, z0]), X.p([...b, z1]), X.p([...a, z1])); }
    if (o.lines === 'none') return;
    const crease = (o.crease ?? 28) * Math.PI / 180;
    // caps: true(양 끝 윤곽) | 'front'(z1 쪽만 — 얇은 판은 윤곽 한 줄이 깔끔) | 'back'(z0 쪽만) | false
    const capLines = o.caps ?? true;
    for (let i = 0; i < ccw.length; i++) {
      const a = ccw[i], b = ccw[(i + 1) % ccw.length];
      if (capLines === true || capLines === 'back') addSeg([...a, z0], [...b, z0]);
      if (capLines === true || capLines === 'front') addSeg([...a, z1], [...b, z1]);
      const pv = ccw[(i + ccw.length - 1) % ccw.length];
      const d1 = norm([a[0] - pv[0], a[1] - pv[1], 0]), d2 = norm([b[0] - a[0], b[1] - a[1], 0]);
      if (Math.acos(Math.max(-1, Math.min(1, d1[0] * d2[0] + d1[1] * d2[1]))) > crease && o.sides !== false && (capLines === true || o.sides === true)) addSeg([...a, z0], [...a, z1]);
    }
    return;
  }
  if (p.k === 'torus') {
    const ax = norm(p.axis), [u, w] = basis(ax), n = o.seg || 24, m = o.tseg || 8;
    const pt = (i, j) => { const a = i / n * Math.PI * 2, b = j / m * Math.PI * 2; const dirR = add(mulv(u, Math.cos(a)), mulv(w, Math.sin(a))); return X.p(add(p.c, add(mulv(dirR, p.R + Math.cos(b) * p.r), mulv(ax, Math.sin(b) * p.r)))); };
    for (let i = 0; i < n; i++) for (let j = 0; j < m; j++) quad(tri, pt(i, j), pt(i + 1, j), pt(i + 1, j + 1), pt(i, j + 1));
    if (o.lines === 'none') return;
    for (const rr of (o.ringsAt || [p.R - p.r, p.R + p.r])) { const k = ringSeg(rr); let prev = null; for (let i = 0; i <= k; i++) { const a = i / k * Math.PI * 2; const q = add(p.c, mulv(add(mulv(u, Math.cos(a)), mulv(w, Math.sin(a))), rr)); if (prev) addSeg(prev, q); prev = q; } }
    return;
  }
  if (p.k === 'line') { for (let i = 0; i + 1 < p.pts.length; i++) addSeg(p.pts[i], p.pts[i + 1]); if (o.closed) addSeg(p.pts[p.pts.length - 1], p.pts[0]); return; }
}
function scaleOf(X, v) { return len(X.v(v)); }
// 모따기 상자 메시(steps 0 = 그냥 상자, 1 = 모따기, 3 = 둥글게)
function roundedBoxMesh(tri, X, c, h, r, steps) {
  if (!steps || r <= 0) {
    const v = (a, b, d) => X.p([c[0] + a * h[0], c[1] + b * h[1], c[2] + d * h[2]]);
    quad(tri, v(1, -1, -1), v(1, 1, -1), v(1, 1, 1), v(1, -1, 1)); quad(tri, v(-1, -1, 1), v(-1, 1, 1), v(-1, 1, -1), v(-1, -1, -1));
    quad(tri, v(-1, 1, -1), v(-1, 1, 1), v(1, 1, 1), v(1, 1, -1)); quad(tri, v(-1, -1, 1), v(-1, -1, -1), v(1, -1, -1), v(1, -1, 1));
    quad(tri, v(-1, -1, 1), v(1, -1, 1), v(1, 1, 1), v(-1, 1, 1)); quad(tri, v(1, -1, -1), v(-1, -1, -1), v(-1, 1, -1), v(1, 1, -1));
    return;
  }
  // 정육면체를 잘게 나눈 격자를 '안쪽 상자 + 반지름 r 둥근 껍질'로 투영(steps 마다 모서리 둥글기)
  const n = steps + 1; // 모서리 구간 나눔
  const inner = h.map(x => Math.max(1e-3, x - r));
  const map = (gx, gy, gz) => { // g: 면 위 격자점 → 위치
    const q = [gx, gy, gz];
    const pIn = q.map((s, k) => Math.max(-inner[k], Math.min(inner[k], s)));
    let d = sub(q, pIn); const dl = len(d);
    if (steps === 1) { // 모따기: 맨해튼 거리로
      const m1 = Math.abs(d[0]) + Math.abs(d[1]) + Math.abs(d[2]); if (m1 < 1e-9) return X.p(add(c, q)); return X.p(add(c, add(pIn, mulv(d, r / m1))));
    }
    if (dl < 1e-9) return X.p(add(c, q));
    return X.p(add(c, add(pIn, mulv(d, r / dl))));
  };
  // 각 면을 (가운데 + 양쪽 모서리 n 칸) 격자로
  const axisVals = (k) => { const v = [-h[k]]; for (let i = 1; i <= n; i++) v.push(-inner[k] - r + (r) * i / n); v.pop(); v.push(-inner[k]); v.push(inner[k]); for (let i = 1; i < n; i++) v.push(inner[k] + r * i / n); v.push(h[k]); return [...new Set(v.map(x => +x.toFixed(6)))].sort((a, b) => a - b); };
  const AV = [axisVals(0), axisVals(1), axisVals(2)];
  for (let k = 0; k < 3; k++) for (const s of [-1, 1]) {
    const a1 = (k + 1) % 3, a2 = (k + 2) % 3; const A = AV[a1], B = AV[a2];
    for (let i = 0; i + 1 < A.length; i++) for (let j = 0; j + 1 < B.length; j++) {
      const g = (x, y) => { const q = [0, 0, 0]; q[k] = s * h[k]; q[a1] = x; q[a2] = y; return map(q[0], q[1], q[2]); };
      const p00 = g(A[i], B[j]), p10 = g(A[i + 1], B[j]), p11 = g(A[i + 1], B[j + 1]), p01 = g(A[i], B[j + 1]);
      if (s > 0) quad(tri, p00, p10, p11, p01); else quad(tri, p00, p01, p11, p10);
    }
  }
}
// ── 점이 도형 안인가(묻힌 선 자르기) ──
function inside(p, w) {
  const o = p.o; const e = 0.02;
  if (p.k === 'box' || p.k === 'cushion') { const q = locScaled(p, w); return Math.abs(q[0] - p.c[0]) < p.s[0] / 2 - e && Math.abs(q[1] - p.c[1]) < p.s[1] / 2 - e && Math.abs(q[2] - p.c[2]) < p.s[2] / 2 - e; }
  if (p.k === 'cone') { const q = locScaled(p, w); const d = sub(p.b, p.a), L = len(d); if (L < 1e-4) return false; const t = dot(sub(q, p.a), d) / (L * L); if (t <= 0.005 || t >= 0.995) return false; const r = p.r1 + (p.r2 - p.r1) * t; const perp = len(sub(sub(q, p.a), mulv(d, t))); return perp < r - e; }
  if (p.k === 'sphere') { const q = locScaled(p, w); return len(sub(q, p.c)) < p.r - e; }
  if (p.k === 'lathe') { const q = locScaled(p, w); const c0 = o.at || [0, 0, 0]; const y = q[1] - c0[1], rr = Math.hypot(q[0] - c0[0], q[2] - c0[2]); const pr = p.profile; for (let i = 0; i + 1 < pr.length; i++) { const a = pr[i], b = pr[i + 1]; if ((y - a[1]) * (y - b[1]) <= 0 && a[1] !== b[1]) { const t = (y - a[1]) / (b[1] - a[1]); const r = a[0] + (b[0] - a[0]) * t; if (rr < r - e && y > pr[0][1] + e && y < pr[pr.length - 1][1] - e) return true; } } return false; }
  if (p.k === 'extrude') { const q = locScaled(p, w); const z0 = o.z0 ?? -p.depth / 2; if (q[2] <= z0 + e || q[2] >= z0 + p.depth - e) return false; if (!pointInPoly(q[0], q[1], p.poly)) return false; // 테두리에서 e 안쪽
    for (const [dx, dy] of [[e, 0], [-e, 0], [0, e], [0, -e]]) if (!pointInPoly(q[0] + dx, q[1] + dy, p.poly)) return false; return true; }
  if (p.k === 'torus') { const q = locScaled(p, w); const ax = norm(p.axis); const d = sub(q, p.c); const h = dot(d, ax); const radial = len(sub(d, mulv(ax, h))); return Math.hypot(radial - p.R, h) < p.r - e; }
  return false;
}
// 축척 포함 변환의 역: 정규 직교가 아닐 수 있어 3x3 역행렬로
function locScaled(p, w) {
  const m = p.xf.m; const a = [m[0], m[3], m[6]], b = [m[1], m[4], m[7]], c = [m[2], m[5], m[8]];
  const det = a[0] * (b[1] * c[2] - b[2] * c[1]) - a[1] * (b[0] * c[2] - b[2] * c[0]) + a[2] * (b[0] * c[1] - b[1] * c[0]);
  const d = [w[0] - m[9], w[1] - m[10], w[2] - m[11]];
  // 크라머
  const solve = (k) => { const M = [[a[0], a[1], a[2]], [b[0], b[1], b[2]], [c[0], c[1], c[2]]]; for (let r = 0; r < 3; r++) M[r][k] = d[r]; return (M[0][0] * (M[1][1] * M[2][2] - M[1][2] * M[2][1]) - M[0][1] * (M[1][0] * M[2][2] - M[1][2] * M[2][0]) + M[0][2] * (M[1][0] * M[2][1] - M[1][1] * M[2][0])) / det; };
  return [solve(0), solve(1), solve(2)];
}

module.exports = { Model, Xf, T, Rx, Ry, Rz, S, add, sub, mulv, dot, cross, len, norm, lerp, roundRect, circle2, arc2, ringSeg };
