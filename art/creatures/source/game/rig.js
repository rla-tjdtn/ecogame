// 시안 조각 몸 → 뼈 넣은 3D 메시(웨이트 포함) + 자세별 뼈 움직임
//   node rig.js k4h1 ...  → out/mesh/<id>.glb (로블록스 가져오기용, 게임 좌표: 앞 = -Z, 바닥 y = 0)
//                          + src/shared/CreatureRigs/<id>.luau (뼈 이름 · 쉬는 자리 · 걷기 8 · 추격 8 · 덮침 · 대기 프레임)
// 뼈: 디자인 그룹마다 관(tube) 줄기를 휘는 곳에서 끊은 마디 하나하나 + 그룹의 나머지 덩어리(타원체·공·상자) 하나. 아주 작은 그룹(얼굴 부속 등)은 가장 가까운 뼈에 합친다.
// 웨이트: 정점마다 각 뼈의 도형 표면까지 거리 → 가장 가까운 뼈 4개에 exp(-(d - dmin) / σ) 로 부드럽게 나눈다(관절에서 자연스럽게 섞임).
// 자세: 디자인 매개변수(걷기 위상·추격·덮침)로 다시 조각한 도형들에 뼈마다 강체 맞춤(Kabsch) → 회전 + 이동.
const fs = require('fs'), path = require('path');
const { CFG } = require('./bake.js');
// 괴물별 손보기(fixes/*.json: { id: { walk?, chase?, attack?, stride?, phase?, phaseAmp?, phaseBase?, rigidTol?, sigma? } }) — 검토 담당이 나눠 쓴다
const FIXD = require('path').join(__dirname, 'fixes'); if (fs.existsSync(FIXD)) for (const f of fs.readdirSync(FIXD)) if (f.endsWith('.json')) { const F = JSON.parse(fs.readFileSync(require('path').join(FIXD, f), 'utf8')); for (const id in F) if (CFG[id]) Object.assign(CFG[id], F[id]); }
const { sdfGrid } = require('./sdfgrid.js');
const { surfaceNets } = require('./mesher.js');
const { MeshoptSimplifier: SIMP } = require('meshoptimizer');
const SRC = path.join(__dirname, '..');
const META = Object.assign({}, require(path.join(SRC, 'set1/meta.js')), require(path.join(SRC, 'set2/meta2.js')), require(path.join(SRC, 'set3/meta3.js')), require(path.join(SRC, 'set4/meta4.js')));
const OUTD = path.join(__dirname, 'out', 'mesh'); fs.mkdirSync(OUTD, { recursive: true });
const LUAD = path.join(__dirname, '..', '..', '..', '..', 'src', 'shared', 'CreatureRigs'); fs.mkdirSync(LUAD, { recursive: true });
const VOX = +(process.env.VOX || .03), TRIS = +(process.env.TRIS || 19500), SIGMA = .05, N_WALK = 8;

const V = { sub: (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]], add: (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]], mul: (a, k) => [a[0] * k, a[1] * k, a[2] * k], dot: (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2], len: a => Math.hypot(a[0], a[1], a[2]), cross: (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]] };
const qaxes = q => { const [x, y, z, w] = q; return [[1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w)], [2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w)], [2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y)]]; };

function prims(C, p) { const B = C.build(p); const out = []; B.groups.forEach((g, gi) => g.prims.forEach(pr => out.push({ ...pr, g: gi }))); return out; }
// 도형의 표본 점(강체 맞춤용)
function samples(p) {
  if (p.t === 0) return V.len(V.sub(p.b, p.a)) < 1e-4 ? [p.a] : [p.a, p.b];
  const ax = qaxes(p.q || [0, 0, 0, 1]); return [p.a, ...[0, 1, 2].map(i => V.add(p.a, V.mul(ax[i], p.b[i])))];
}
// 점 → 도형 표면 거리(근사)
function dist(p, x) {
  if (p.t === 0) { const ba = V.sub(p.b, p.a), l2 = V.dot(ba, ba); let h = l2 < 1e-8 ? 0 : Math.max(0, Math.min(1, V.dot(V.sub(x, p.a), ba) / l2)); return V.len(V.sub(x, V.add(p.a, V.mul(ba, h)))) - (p.ra + (p.rb - p.ra) * h); }
  const ax = qaxes(p.q || [0, 0, 0, 1]), d = V.sub(x, p.a), q = [V.dot(d, ax[0]), V.dot(d, ax[1]), V.dot(d, ax[2])];
  if (p.t === 1) { const k0 = Math.hypot(q[0] / p.b[0], q[1] / p.b[1], q[2] / p.b[2]), k1 = Math.hypot(q[0] / (p.b[0] * p.b[0]), q[1] / (p.b[1] * p.b[1]), q[2] / (p.b[2] * p.b[2])); return k0 * (k0 - 1) / Math.max(k1, 1e-4); } // (시안 렌더러와 같은 타원체 거리)
  const e = q.map((v, i) => Math.abs(v) - p.b[i]); return Math.hypot(Math.max(e[0], 0), Math.max(e[1], 0), Math.max(e[2], 0)) + Math.min(Math.max(...e), 0);
}

// 뼈 나누기: 디자인 자세들(걷기·추격·덮침)에서 실제로 한 덩어리로 움직이는 도형끼리만 한 뼈로 묶는다.
// → 무릎·팔꿈치·턱처럼 실제로 꺾이는 곳에서 뼈가 나뉜다. (Ps = 자세마다 도형 목록, 순서는 쉬는 자세와 같다)
let RIGID_TOL = .03;
function rigidErr(P0, Ps, idx, extra) {
  const A = idx.flatMap(k => samples(P0[k])), X = samples(P0[extra]); let worst = 0;
  for (const P of Ps) { const B = idx.flatMap(k => samples(P[k])); const { R, t } = fit(A, B); const Y = samples(P[extra]); X.forEach((x, i) => { worst = Math.max(worst, V.len(V.sub(V.add(mat(R, x), t), Y[i]))); }); }
  return worst;
}
function planBones(P0, Ps) {
  const bones = []; let i = 0;
  const blobs = {}; // 그룹마다 덩어리 뼈들
  while (i < P0.length) {
    const p = P0[i];
    if (p.op) { i++; continue; }
    if (p.t === 0 && p.ex === 1) {
      let j = i; while (j + 1 < P0.length && P0[j + 1].ex >= 2 && P0[j + 1].g === p.g) { j++; if (P0[j].ex === 3) break; }
      let run = [i];
      for (let k = i + 1; k <= j; k++) {
        if (rigidErr(P0, Ps, run, k) > RIGID_TOL) { bones.push({ g: p.g, idx: run, chain: true }); run = [k]; } else run.push(k);
      }
      bones.push({ g: p.g, idx: run, chain: true }); i = j + 1; continue;
    }
    // 덩어리(타원체·공·상자·짧은 원뿔): 같은 그룹의 덩어리 뼈 중 함께 움직이는 것에 넣고, 없으면 새 뼈
    const list = blobs[p.g] || (blobs[p.g] = []);
    let put = false;
    for (const bi of list) { if (rigidErr(P0, Ps, bones[bi].idx, i) <= RIGID_TOL) { bones[bi].idx.push(i); put = true; break; } }
    if (!put) { list.push(bones.length); bones.push({ g: p.g, idx: [i] }); }
    i++;
  }
  for (const b of bones) b.size = boneSize(P0, b.idx);
  // 아주 작은 뼈는 함께 움직이는 가까운 뼈에 합친다(함께 움직이지 않으면 따로 둔다: 턱·눈꺼풀 등)
  for (let bi = 0; bi < bones.length; bi++) {
    const b = bones[bi]; if (b.dead || b.size >= .3) continue;
    let best = -1, bd = .25;
    bones.forEach((o, oi) => { if (oi === bi || o.dead) return; for (const k of o.idx) for (const x of b.idx.flatMap(q => samples(P0[q]))) { const d = dist(P0[k], x); if (d < bd && b.idx.every(q => rigidErr(P0, Ps, o.idx, q) <= RIGID_TOL)) { bd = d; best = oi; } } });
    if (best >= 0) { bones[best].idx.push(...b.idx); b.dead = true; }
  }
  return bones.filter(b => !b.dead);
}
function boneSize(P, idx) { let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9]; for (const k of idx) for (const s of samples(P[k])) for (let a = 0; a < 3; a++) { mn[a] = Math.min(mn[a], s[a]); mx[a] = Math.max(mx[a], s[a]); } return V.len(V.sub(mx, mn)) + Math.max(...idx.map(k => P[k].ra || 0)) * 2; }
// 맞닿은 뼈끼리(웨이트를 섞어도 되는 이웃): 한 뼈의 도형 표면에서 다른 뼈 표본 점까지 .06 안
function adjacency(P0, bones) {
  const adj = bones.map(() => new Set());
  const box = bones.map(b => { let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9]; for (const k of b.idx) { const p = P0[k], r = p.t === 0 ? Math.max(p.ra, p.rb) : Math.max(...p.b) * 1.75; for (const x of samples(p)) for (let a = 0; a < 3; a++) { mn[a] = Math.min(mn[a], x[a] - r); mx[a] = Math.max(mx[a], x[a] + r); } } return { mn, mx }; });
  for (let x = 0; x < bones.length; x++) for (let y = x + 1; y < bones.length; y++) {
    const A = box[x], B = box[y]; if (A.mx[0] < B.mn[0] - .1 || B.mx[0] < A.mn[0] - .1 || A.mx[1] < B.mn[1] - .1 || B.mx[1] < A.mn[1] - .1 || A.mx[2] < B.mn[2] - .1 || B.mx[2] < A.mn[2] - .1) continue;
    let touch = false;
    for (const ka of bones[x].idx) { for (const kb of bones[y].idx) { const pb = P0[kb], pa = P0[ka]; const sb = samples(pb), sa = samples(pa); const rb = pb.t === 0 ? [pb.ra, pb.rb] : [0, 0, 0, 0], ra = pa.t === 0 ? [pa.ra, pa.rb] : [0, 0, 0, 0]; if (sb.some((s, i) => dist(pa, s) - (rb[i] || 0) < .06) || sa.some((s, i) => dist(pb, s) - (ra[i] || 0) < .06)) { touch = true; break; } } if (touch) break; }
    if (touch) { adj[x].add(y); adj[y].add(x); }
  }
  return adj;
}
function range(a, b) { const r = []; for (let k = a; k <= b; k++) r.push(k); return r; }

// 강체 맞춤: rest 점들 → pose 점들(회전 R(3×3), 이동 t: x' = R x + t)
function fit(A, B) {
  const n = A.length, ca = [0, 0, 0], cb = [0, 0, 0];
  for (let i = 0; i < n; i++) for (let k = 0; k < 3; k++) { ca[k] += A[i][k] / n; cb[k] += B[i][k] / n; }
  const H = [[0, 0, 0], [0, 0, 0], [0, 0, 0]];
  for (let i = 0; i < n; i++) { const a = V.sub(A[i], ca), b = V.sub(B[i], cb); for (let r = 0; r < 3; r++) for (let c = 0; c < 3; c++) H[r][c] += a[r] * b[c]; }
  let R = horn(H);
  if (!R) { // 점이 한 줄(관 마디): 방향만 맞추는 최소 회전
    let da = [0, 1, 0], db = [0, 1, 0];
    if (n >= 2) { da = V.sub(A[n - 1], A[0]); db = V.sub(B[n - 1], B[0]); }
    R = rotBetween(da, db);
  }
  const t = V.sub(cb, mat(R, ca));
  return { R, t };
}
const mat = (R, v) => [R[0][0] * v[0] + R[0][1] * v[1] + R[0][2] * v[2], R[1][0] * v[0] + R[1][1] * v[1] + R[1][2] * v[2], R[2][0] * v[0] + R[2][1] * v[1] + R[2][2] * v[2]];
function rotBetween(a, b) {
  const la = V.len(a), lb = V.len(b); if (la < 1e-6 || lb < 1e-6) return [[1, 0, 0], [0, 1, 0], [0, 0, 1]];
  const u = V.mul(a, 1 / la), w = V.mul(b, 1 / lb), v = V.cross(u, w), c = V.dot(u, w);
  if (c < -.9999) { let ax = V.cross(u, [1, 0, 0]); if (V.len(ax) < .1) ax = V.cross(u, [0, 1, 0]); ax = V.mul(ax, 1 / V.len(ax)); return quatToMat([ax[0], ax[1], ax[2], 0]); }
  const k = 1 / (1 + c), vx = [[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]];
  const R = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]; for (let r = 0; r < 3; r++) for (let cc = 0; cc < 3; cc++) { let s = vx[r][cc]; for (let m = 0; m < 3; m++) s += vx[r][m] * vx[m][cc] * k; R[r][cc] += s; }
  return R;
}
// Horn 사원수 방법(교차 공분산 H) → 회전 행렬. 점이 한 줄이면 null
function horn(H) {
  const [[Sxx, Sxy, Sxz], [Syx, Syy, Syz], [Szx, Szy, Szz]] = H;
  const N = [[Sxx + Syy + Szz, Syz - Szy, Szx - Sxz, Sxy - Syx], [Syz - Szy, Sxx - Syy - Szz, Sxy + Syx, Szx + Sxz], [Szx - Sxz, Sxy + Syx, -Sxx + Syy - Szz, Syz + Szy], [Sxy - Syx, Szx + Sxz, Syz + Szy, -Sxx - Syy + Szz]];
  // 가장 큰 고유값의 고유벡터(거듭제곱 반복, 음수 고유값 대비 이동)
  let shift = 0; for (const r of N) shift = Math.max(shift, r.reduce((s, v) => s + Math.abs(v), 0));
  const M = N.map((r, i) => r.map((v, j) => v + (i === j ? shift : 0)));
  let q = [1, .1, .1, .1];
  for (let it = 0; it < 200; it++) { const n2 = M.map(r => r[0] * q[0] + r[1] * q[1] + r[2] * q[2] + r[3] * q[3]); const l = Math.hypot(...n2) || 1; q = n2.map(v => v / l); }
  // 퇴화 검사: 두 번째로 큰 고유값과 비슷하면(한 줄) null
  const ev = q.reduce((s, v, i) => s + v * N[i].reduce((a, w, j) => a + w * q[j], 0), 0);
  const tr = Sxx + Syy + Szz, sc = Math.abs(Sxx) + Math.abs(Syy) + Math.abs(Szz) + 1e-9;
  const Hn = Math.hypot(...H.flat()); if (Hn < 1e-9) return null;
  // 공분산의 랭크가 1 이면(점이 한 줄) 축 둘레 회전을 알 수 없다
  const rank2 = (() => { const a = H.map(r => r.slice()); const c1 = V.cross(a[0], a[1]), c2 = V.cross(a[1], a[2]), c3 = V.cross(a[0], a[2]); return Math.max(V.len(c1), V.len(c2), V.len(c3)) > 1e-6 * Hn * Hn; })();
  void ev; void tr; void sc;
  if (!rank2) return null;
  return quatToMat([q[1], q[2], q[3], q[0]]);
}
function quatToMat([x, y, z, w]) { return [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)], [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)], [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]; }
function matToQuat(m) {
  const t = m[0][0] + m[1][1] + m[2][2]; let x, y, z, w;
  if (t > 0) { const s = Math.sqrt(t + 1) * 2; w = s / 4; x = (m[2][1] - m[1][2]) / s; y = (m[0][2] - m[2][0]) / s; z = (m[1][0] - m[0][1]) / s; }
  else if (m[0][0] > m[1][1] && m[0][0] > m[2][2]) { const s = Math.sqrt(1 + m[0][0] - m[1][1] - m[2][2]) * 2; w = (m[2][1] - m[1][2]) / s; x = s / 4; y = (m[0][1] + m[1][0]) / s; z = (m[0][2] + m[2][0]) / s; }
  else if (m[1][1] > m[2][2]) { const s = Math.sqrt(1 + m[1][1] - m[0][0] - m[2][2]) * 2; w = (m[0][2] - m[2][0]) / s; x = (m[0][1] + m[1][0]) / s; y = s / 4; z = (m[1][2] + m[2][1]) / s; }
  else { const s = Math.sqrt(1 + m[2][2] - m[0][0] - m[1][1]) * 2; w = (m[1][0] - m[0][1]) / s; x = (m[0][2] + m[2][0]) / s; y = (m[1][2] + m[2][1]) / s; z = s / 4; }
  const l = Math.hypot(x, y, z, w); return [x / l, y / l, z / l, w / l];
}

// 디자인 좌표(앞 +Z) → 게임 좌표(앞 -Z): x, z 뒤집기(Y 축 180° 회전)
const G = v => [-v[0], v[1], -v[2]];
const Gq = q => [-q[0], q[1], -q[2], q[3]];

const { writeGLB } = require('./glb.js');
function meshIdOf(id) { try { return JSON.parse(fs.readFileSync(path.join(__dirname, 'meshids.json'), 'utf8'))[id] || 0; } catch (e) { return 0; } }
(async () => {
  await SIMP.ready;
  for (const id of process.argv.slice(2)) {
    const c = CFG[id]; if (!c) throw new Error('no cfg ' + id);
    RIGID_TOL = c.rigidTol || .03; const SIG = c.sigma || SIGMA;
    const C = require(path.join(SRC, c.mod + '.js')), setDir = path.join(SRC, path.dirname(c.mod));
    const m = META[path.basename(c.mod)] || {}, base = { ...(m.hero || (m.poses && m.poses[0] && m.poses[0][1]) || {}) }; const PK = c.phase || 'walk'; delete base[PK];
    const ph = (o, v) => ({ ...base, ...o, [PK]: c.phaseAmp ? (c.phaseBase || 0) + c.phaseAmp * Math.sin(v * 2 * Math.PI) : v });
    const restP = ph(c.walk, 0);
    const P0 = prims(C, restP);
    // 자세들(도형 수가 다르면 입 벌림 같은 얼굴 매개변수를 빼고 다시)
    const FACE = ['jaw', 'gape', 'mouth', 'jawDrop', 'open', 'sing', 'hug'];
    const poseOf = p => { let q = { ...p }; for (let tries = 0; tries <= FACE.length; tries++) { const P = prims(C, q); if (P.length === P0.length) return P; const k = FACE.find(f => q[f] !== undefined && q[f] !== restP[f]); if (!k) break; q = { ...q, [k]: restP[k] }; } console.warn(id, '자세 도형 수가 달라 쉬는 자세로 대체', JSON.stringify(p)); return P0; };
    // 메시(쉬는 자세)
    let t = Date.now();
    const Bfull = C.build(restP), gAll = Bfull.groups.slice();
    const bd0 = Bfull.data(), vol = (bd0.mx[0] - bd0.mn[0]) * (bd0.mx[1] - bd0.mn[1]) * (bd0.mx[2] - bd0.mn[2]);
    const vox = Math.max(VOX, Math.cbrt(vol / 5.5e6)); // (큰 몸은 격자 간격을 키워 계산량을 일정하게)
    // split: 왼쪽(+x)·가운데·오른쪽 그룹을 따로 메시로 → 쉬는 자세에서 맞닿은 두 다리·얼굴 위 손 같은 곳이 한 덩어리로 붙지 않는다
    const sideOf = g => { let sx = 0, n = 0; for (const p of g.prims) if (!p.op) { sx += p.t === 0 ? (p.a[0] + p.b[0]) / 2 : p.a[0]; n++; } const x = n ? sx / n : 0; return x > .12 ? 'L' : x < -.12 ? 'R' : 'C'; };
    // splitThin: 가는 관(손가락·머리카락 등) 그룹은 따로 'F' 메시 → 얼굴 위에 얹힌 손가락이 떨어질 때 얼굴 살이 늘어나지 않는다
    const thin = g => { const ps = g.prims.filter(p => !p.op); return ps.length > 0 && ps.every(p => p.t === 0 && Math.max(p.ra, p.rb) < .12); };
    const baseSide = g => { const p = g.prims.find(q => !q.op); return p && p.a[0] < 0 ? 'R' : 'L'; }; // (손가락은 시작점(손목 쪽)이 어느 쪽인지로 왼손·오른손)
    const gSide = gAll.map(g => (c.split ? (c.splitThin && thin(g) ? 'F' + baseSide(g) : sideOf(g)) : 'C'));
    const parts = (c.split ? ['C', 'L', 'R', 'FL', 'FR'] : ['C']).map(sd => ({ sd, groups: gAll.filter((_, gi) => gSide[gi] === sd) })).filter(p => p.groups.length);
    const raws = parts.map(p => { Bfull.groups = p.groups; const R = surfaceNets(sdfGrid(setDir, Bfull.data(), vox)); return { sd: p.sd, R }; });
    Bfull.groups = gAll;
    const rawTotal = raws.reduce((a, r) => a + r.R.T.length, 0);
    const Pd = [], Nd = [], T = [], Vside = [];
    for (const { sd, R } of raws) {
      if (!R.T.length) continue;
      const [idx] = SIMP.simplify(R.T, R.P, 3, Math.max(300, Math.floor(TRIS * R.T.length / rawTotal)) * 3, .02, []);
      const map = new Int32Array(R.P.length / 3).fill(-1);
      for (const i of idx) { if (map[i] < 0) { map[i] = Pd.length; Pd.push([R.P[i * 3], R.P[i * 3 + 1], R.P[i * 3 + 2]]); Nd.push([R.N[i * 3], R.N[i * 3 + 1], R.N[i * 3 + 2]]); Vside.push(sd); } T.push(map[i]); }
    }
    console.log(id, c.name, 'vox', vox.toFixed(3), 'mesh', Pd.length, 'verts', T.length / 3, 'tris', (Date.now() - t) + 'ms');
    // 자세들의 도형(뼈 나누기·프레임에 같이 쓴다)
    const walkP = [...Array(N_WALK)].map((_, k) => poseOf(ph(c.walk, k / N_WALK)));
    const chaseP = [...Array(N_WALK)].map((_, k) => poseOf(ph(c.chase, k / N_WALK)));
    const attackP = poseOf({ ...base, ...c.attack });
    // 뼈
    t = Date.now();
    const bones = planBones(P0, [...walkP.filter((_, k) => k % 2 === 1), ...chaseP.filter((_, k) => k % 2 === 0), attackP]);
    let adj = adjacency(P0, bones);
    // 뼈가 너무 많으면(로블록스 메시 한 개에 안전한 수) 작은 뼈를 맞닿은 뼈 중 가장 함께 움직이는 것에 합친다
    const MAXB = c.maxBones || 240;
    if (bones.length > MAXB) {
      const Ps = [...walkP.filter((_, k) => k % 2 === 1), ...chaseP.filter((_, k) => k % 2 === 0), attackP];
      const alive = bones.map(() => true); let n = bones.length;
      const order = bones.map((b, i) => i).sort((a, b) => bones[a].size - bones[b].size);
      for (const bi of order) {
        if (n <= MAXB) break; if (!alive[bi]) continue;
        let best = -1, be = 1e9;
        for (const oi of adj[bi]) { if (!alive[oi]) continue; const e = Math.max(...bones[bi].idx.map(k => rigidErr(P0, Ps, bones[oi].idx, k))); if (e < be) { be = e; best = oi; } }
        if (best < 0) continue;
        bones[best].idx.push(...bones[bi].idx); bones[best].size = Math.max(bones[best].size, bones[bi].size); alive[bi] = false; n--;
        for (const x of adj[bi]) if (x !== best) { adj[best].add(x); adj[x].add(best); adj[x].delete(bi); }
      }
      const keep = bones.map((b, i) => i).filter(i => alive[i]); const nb = keep.map(i => bones[i]); bones.length = 0; bones.push(...nb);
      adj = adjacency(P0, bones);
    }
    console.log(id, 'bones', bones.length, (Date.now() - t) + 'ms');
    bones.forEach((b, i) => { const pts = b.idx.flatMap(k => samples(P0[k])); b.c0 = pts.reduce((s, p) => V.add(s, V.mul(p, 1 / pts.length)), [0, 0, 0]); b.name = 'B' + (i + 1); });
    // 웨이트
    t = Date.now();
    const J = new Uint16Array(Pd.length * 4), W = new Float32Array(Pd.length * 4);
    const boneOfPrim = new Int32Array(P0.length).fill(-1); bones.forEach((b, bi) => b.idx.forEach(k => { boneOfPrim[k] = bi; }));
    const live = P0.map((p, k) => k).filter(k => boneOfPrim[k] >= 0);
    // 도형 경계 상자(빠른 거르기)
    const pb = live.map(k => { const p = P0[k]; const r = p.t === 0 ? Math.max(p.ra, p.rb) : Math.max(...p.b) * (p.t === 2 ? 1.75 : 1); const s = samples(p); let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9]; for (const x of s) for (let a = 0; a < 3; a++) { mn[a] = Math.min(mn[a], x[a] - r); mx[a] = Math.max(mx[a], x[a] + r); } return { k, mn, mx }; });
    for (let v = 0; v < Pd.length; v++) {
      const x = Pd[v]; const bd = new Map();
      let reach = .45;
      for (let pass = 0; pass < 3 && bd.size === 0; pass++, reach *= 3) {
        for (const e of pb) { if (x[0] < e.mn[0] - reach || x[0] > e.mx[0] + reach || x[1] < e.mn[1] - reach || x[1] > e.mx[1] + reach || x[2] < e.mn[2] - reach || x[2] > e.mx[2] + reach) continue; let d = dist(P0[e.k], x); if (d < -.2) continue; d = Math.abs(d); const bi = boneOfPrim[e.k]; if (!bd.has(bi) || d < bd.get(bi)) bd.set(bi, d); /* (표면 정점이 도형 깊숙이 안에 있으면 그 도형은 깎여 나간 곳: 빼고 본다) */ }
      }
      // 가장 가까운 뼈 + 그 뼈와 맞닿은 뼈들만(떨어진 다리·팔끼리는 섞지 않는다)
      const vs = Vside[v]; // (갈라 만든 메시: 왼쪽 메시 정점은 오른쪽 뼈를 따라가지 않는다)
      const okB = bi => { const bs = gSide[bones[bi].g]; if (vs[0] === 'F') return bs === vs || bs === vs[1]; if (bs[0] === 'F') return false; return vs === 'C' || bs === vs || bs === 'C'; };
      const all = [...bd.entries()].filter(([bi]) => okB(bi)).sort((a, b) => a[1] - b[1]);
      const top = all.length ? all.filter(([bi], n) => n === 0 || adj[all[0][0]].has(bi)).slice(0, 4) : [];
      if (!top.length) { J[v * 4] = 1; W[v * 4] = 1; continue; }
      const d0 = top[0][1]; let ws = top.map(([, d]) => Math.exp(-(d - d0) / SIG)); ws = ws.map(w => (w < .02 ? 0 : w)); const s = ws.reduce((a, b) => a + b, 0);
      top.forEach(([bi], k) => { J[v * 4 + k] = bi + 1; W[v * 4 + k] = ws[k] / s; });
    }
    console.log(id, 'weights', (Date.now() - t) + 'ms');
    // 자세 프레임: 뼈마다 강체 맞춤 → (사원수, 이동) 게임 좌표. Transform = 뼈 원점 기준 회전 + (D(c) - c)
    const frameOf = P => bones.map(b => { const A = b.idx.flatMap(k => samples(P0[k])), B = b.idx.flatMap(k => samples(P[k])); const { R: Rm, t: tv } = fit(A, B); const q = Gq(matToQuat(Rm)); const dc = V.sub(V.add(mat(Rm, b.c0), tv), b.c0); return [...q.map(x => Math.round(x * 1e4) / 1e4), ...G(dc).map(x => Math.round(x * 1e3) / 1e3)]; });
    const walk = walkP.map(frameOf), chase = chaseP.map(frameOf), attack = frameOf(attackP);
    // 자동 검사: 스킨으로 옮긴 정점이 실제 디자인 자세의 표면에 붙어 있는가(걷기 2·추격 2·덮침). 오차가 크면 경고
    {
      const qrot = (q, r) => { const u = [q[0], q[1], q[2]], t2 = V.mul(V.cross(u, r), 2); return V.add(V.add(r, V.mul(t2, q[3])), V.cross(u, t2)); };
      const errs = [], per = [];
      for (const [F, PP] of [[walk[2], walkP[2]], [chase[2], chaseP[2]], [attack, attackP]]) {
        const live2 = live.map(k => PP[k]);
        for (let v = 0; v < Pd.length; v += 3) {
          const xg = G(Pd[v]); let o = [0, 0, 0];
          for (let k = 0; k < 4; k++) { const j = J[v * 4 + k], w = W[v * 4 + k]; if (!w) continue; if (j === 0) { o = V.add(o, V.mul(xg, w)); continue; } const f = F[j - 1], cc = G(bones[j - 1].c0); o = V.add(o, V.mul(V.add(V.add(qrot(f, V.sub(xg, cc)), cc), [f[4], f[5], f[6]]), w)); }
          const y = G(o); let best = 9; for (const p of live2) { const d = dist(p, y); if (d >= -.2 && Math.abs(d) < best) best = Math.abs(d); } errs.push(best); if (best > .12) per.push([PP === attackP ? "attack" : PP === chaseP[2] ? "chase" : "walk", v, Pd[v].map(x => x.toFixed(2)).join(","), J.slice(v * 4, v * 4 + 4).join("/"), Array.from(W.slice(v * 4, v * 4 + 4), x => x.toFixed(2)).join("/"), best.toFixed(2)]);
        }
      }
      if (process.env.QADBG) console.log(per.slice(0, 25).map(x => x.join(" ")).join(String.fromCharCode(10)), per.length);
      errs.sort((x, y) => x - y);
      const p90 = errs[Math.floor(errs.length * .9)], p99 = errs[Math.floor(errs.length * .99)];
      console.log(id, 'QA p90', p90.toFixed(3), 'p99', p99.toFixed(3), p99 > .18 ? 'WARN' : 'ok');
      fs.writeFileSync(path.join(OUTD, id + '_qa.json'), JSON.stringify({ p90, p99, bones: bones.length }));
    }
    // 내보내기(게임 좌표)
    const PG = new Float32Array(Pd.length * 3), NG = new Float32Array(Pd.length * 3);
    Pd.forEach((p, i) => PG.set(G(p), i * 3)); Nd.forEach((n, i) => NG.set(G(n), i * 3));
    // 감기 방향: x·z 를 뒤집어도(회전) 방향은 그대로
    const TT = new Uint32Array(T);
    const gb = bones.map(b => ({ name: b.name, c: G(b.c0).map(x => Math.round(x * 1e3) / 1e3) }));
    writeGLB(path.join(OUTD, id + '.glb'), { P: PG, N: NG, J, W, T: TT }, gb);
    fs.writeFileSync(path.join(OUTD, id + '_anim.json'), JSON.stringify({ bones: gb, walk, chase, attack, P: Array.from(PG, x => +x.toFixed(3)), N: Array.from(NG, x => +x.toFixed(2)), T: Array.from(TT), J: Array.from(J), W: Array.from(W, x => +x.toFixed(3)) }));
    const f7 = fr => '{ ' + fr.map(b => '{' + b.join(',') + '}').join(', ') + ' }';
    let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9]; for (const p of Pd) { const g = G(p); for (let a = 0; a < 3; a++) { mn[a] = Math.min(mn[a], g[a]); mx[a] = Math.max(mx[a], g[a]); } }
    const lua = `--!strict\n-- 자동 생성(art/creatures/source/game/rig.js): ${c.name} — 디자인 ${c.mod}. 손으로 고치지 말 것\n` +
      `-- 뼈 = 메시(out/mesh/${id}.glb)의 Root 아래 B1..B${gb.length}. 프레임: 뼈마다 { qx,qy,qz,qw, tx,ty,tz } = Bone.Transform(쉬는 자리 기준, 게임 좌표)\n` +
      `return {\n\tid = "${id}", name = "${c.name}", stride = ${c.stride},\n\tmeshId = ${meshIdOf(id)}, -- 로블록스 에셋 번호(upload.js 가 meshids.json 에 적는다)\n` +
      `\tbounds = { ${mn.map(v => v.toFixed(3)).join(', ')}, ${mx.map(v => v.toFixed(3)).join(', ')} }, -- 메시 경계(게임 좌표, 바닥 y = 0)\n` +
      `\tbones = { ${gb.map(b => `{ ${b.c.join(', ')} }`).join(', ')} },\n` +
      `\tattack = ${f7(attack)},\n\twalk = {\n${walk.map(f => '\t\t' + f7(f) + ',').join('\n')}\n\t},\n\tchase = {\n${chase.map(f => '\t\t' + f7(f) + ',').join('\n')}\n\t},\n}\n`;
    fs.writeFileSync(path.join(LUAD, id + '.luau'), lua);
    console.log(id, 'done', (fs.statSync(path.join(OUTD, id + '.glb')).size / 1024).toFixed(0) + 'KB glb', (lua.length / 1024).toFixed(0) + 'KB lua');
  }
})();
