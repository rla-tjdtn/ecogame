// 시안(e10h.js 뜬눈)을 그대로 고해상도 메시로 뽑는다. 원본 스크립트(rig.js 등)는 실행하지 않고, 같은 도구(sdfgrid·mesher)만 빌려
// 이 폴더 work/ 에만 쓴다.  node tools/design_mesh.js
//  - 부위 묶음: 가운데·왼쪽·오른쪽 몸, 가는 관(손가락·속눈썹·갈비 테·갈고리 등)은 따로 → 손가락이 눈꺼풀 살에 녹아 붙지 않게
//  - 눈알 겉면(눈알 구, 홍채 주름, 동공, 속 얼굴, 핏줄)은 빼고 Blender 쪽에서 따로 된 눈알로 바꾼다
//  - 결과: work/design_hi.bin(굽기용 고해상도), work/design_lo.bin(게임용) + .json 머리말
const fs = require('fs'), path = require('path');
const G = path.resolve(__dirname, '../../../source/game');
const SRC = path.resolve(__dirname, '../../../source');
const { CFG } = require(path.join(G, 'bake.js'));
const { sdfGrid } = require(path.join(G, 'sdfgrid.js'));
const { surfaceNets } = require(path.join(G, 'mesher.js'));
const { MeshoptSimplifier: SIMP } = require(path.join(G, 'node_modules/meshoptimizer'));
const META = Object.assign({}, require(path.join(SRC, 'set3/meta3.js')));
const WORK = path.resolve(__dirname, '../work'); fs.mkdirSync(WORK, { recursive: true });
const VOX_BODY = +(process.env.VOXB || .022), VOX_THIN = +(process.env.VOXT || .01);
const LO = +(process.env.LO || 34000), HI = +(process.env.HI || 600000);

(async () => {
  await SIMP.ready;
  const c = CFG.k10h1, C = require(path.join(SRC, c.mod + '.js')), setDir = path.join(SRC, path.dirname(c.mod));
  const m = META.e10h || {}; const base = { ...(m.hero || (m.poses && m.poses[0] && m.poses[0][1]) || {}) }; delete base.walk;
  const rest = { ...base, ...c.walk, walk: 0 };
  const B = C.build(rest), gAll = B.groups.slice();
  // 눈알 틀(HF): e10h.js 와 같은 값 — 중심 (0, 8.45, .2), R0 1.12
  const EC = [0, 8.45, .2], R0 = 1.12;
  const pts = p => p.t === 0 ? [p.a, p.b] : [p.a];
  const dE = q => Math.hypot(q[0] - EC[0], q[1] - EC[1], q[2] - EC[2]);
  const isEye = g => {
    if (g.mat === 6) return true;
    const ps = g.prims.filter(p => !p.op); if (!ps.length) return false;
    if (ps.every(p => pts(p).every(q => dE(q) < R0 + .07 && (q[2] - EC[2]) / Math.max(dE(q), 1e-6) > .55))) return true;
    // 동공 속 얼굴(A.face) 처럼 눈 앞 가운데에 몰린 그룹: 점 평균이 동공 쪽 정면 캡 안
    const all = ps.flatMap(pts), m = [0, 1, 2].map(k => all.reduce((s, q) => s + q[k], 0) / all.length);
    return dE(m) < R0 + .15 && (m[2] - EC[2]) / Math.max(dE(m), 1e-6) > .8;
  };
  const thin = g => { const ps = g.prims.filter(p => !p.op); return ps.length > 0 && ps.every(p => p.t === 0 && Math.max(p.ra, p.rb) < .12); };
  const sideOf = g => { let sx = 0, n = 0; for (const p of g.prims) if (!p.op) { sx += p.t === 0 ? (p.a[0] + p.b[0]) / 2 : p.a[0]; n++; } const x = n ? sx / n : 0; return x > .12 ? 'L' : x < -.12 ? 'R' : 'C'; };
  // 빼는 그룹(design_dump.js 번호): 관자 쇠틀 76·79, 갈고리 77·78·80·81, 눈 밑 눈물 관 114(사용자 요청: 눈 옆 촉수 같은 것 없앰),
  // 시안 손(손바닥 84·92·100·108 + 손가락·엄지) — 사람 손으로 retex.py(hands.py)에서 새로 만든다
  const DROP = new Set([76, 77, 78, 79, 80, 81, 114, 44, 45, 46, 60, 61, 62]);   // 44~46·60~62 = 눈 둘레 굵은 눈꺼풀 주름 관(사용자 요청으로 뺌, 속눈썹은 남김)
  for (const h of [84, 92, 100, 108]) for (let k = 0; k < 6; k++) DROP.add(h + k);
  for (const a of [82, 83, 90, 91, 98, 99, 106, 107]) DROP.add(a);   // 시안 팔 → limbs.py
  for (let a = 47; a <= 59; a++) DROP.add(a);
  for (let a = 63; a <= 75; a++) DROP.add(a);   // 시안 굵은 속눈썹(떠 있음) → lids.py 가 눈꺼풀 가장자리에 박은 속눈썹
  const tag = gAll.map((g, i) => DROP.has(i) || isEye(g) ? 'EYE' : (thin(g) ? 'T' : '') + sideOf(g));
  const names = [...new Set(tag)].filter(t => t !== 'EYE');
  console.log('groups', gAll.length, 'eye groups', tag.filter(t => t === 'EYE').length, 'buckets', names.map(n => n + ':' + tag.filter(t => t === n).length).join(' '));
  const raws = [];
  for (const nm of names) {
    const vox = nm.startsWith('T') ? VOX_THIN : VOX_BODY;
    // 가는 관 묶음은 그룹마다 작은 격자로 따로(격자가 몸 전체만큼 커지지 않게), 몸 묶음은 한 번에
    const sets = nm.startsWith('T') ? gAll.map((g, i) => [i]).filter(([i]) => tag[i] === nm) : [gAll.map((g, i) => i).filter(i => tag[i] === nm)];
    let t = Date.now(), tris = 0;
    for (const set of sets) {
      B.groups = set.map(i => gAll[i]);
      const R = surfaceNets(sdfGrid(setDir, B.data(), vox));
      if (R.T.length) { raws.push({ nm, R }); tris += R.T.length / 3; }
    }
    console.log(nm, 'vox', vox, 'pieces', sets.length, 'raw tris', tris, (Date.now() - t) + 'ms');
  }
  B.groups = gAll;
  const total = raws.reduce((a, r) => a + r.R.T.length / 3 * (r.nm.startsWith('T') ? 1.6 : 1), 0);
  for (const [label, target] of [['hi', HI], ['lo', LO]]) {
    const Pd = [], Md = [], Bk = [], T = [];
    for (const { nm, R } of raws) {
      const share = R.T.length / 3 * (nm.startsWith('T') ? 1.6 : 1) / total;
      const want = Math.min(R.T.length / 3, Math.max(60, Math.floor(target * share)));
      const [idx] = SIMP.simplify(R.T, R.P, 3, want * 3, label === 'hi' ? .002 : .03, []);
      const map = new Int32Array(R.P.length / 3).fill(-1);
      for (const i of idx) {
        if (map[i] < 0) { map[i] = Pd.length / 3; Pd.push(R.P[i * 3], R.P[i * 3 + 1], R.P[i * 3 + 2]); Md.push(R.M[i]); Bk.push(names.indexOf(nm)); }
        T.push(map[i]);
      }
    }
    const P = Float32Array.from(Pd), Tu = Uint32Array.from(T), M = Uint8Array.from(Md), K = Uint8Array.from(Bk);
    const f = path.join(WORK, 'design_' + label + '.bin');
    fs.writeFileSync(f, Buffer.concat([Buffer.from(P.buffer), Buffer.from(Tu.buffer), Buffer.from(M.buffer), Buffer.from(K.buffer)]));
    fs.writeFileSync(f.replace('.bin', '.json'), JSON.stringify({ nv: P.length / 3, nt: Tu.length / 3, buckets: names, eye: { c: EC, r: R0 } }));
    console.log(label, 'verts', P.length / 3, 'tris', Tu.length / 3);
  }
})().catch(e => { console.error(e); process.exit(1); });
