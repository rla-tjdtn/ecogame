// 시안 도형(쉬는 자세)을 그룹별로 JSON 으로 뽑는다 — 뼈 자리(관절) 찾기용. node tools/design_dump.js → work/design_prims.json
const fs = require('fs'), path = require('path');
const SRC = path.resolve(__dirname, '../../../source');
const G = path.join(SRC, 'game');
const { CFG } = require(path.join(G, 'bake.js'));
const META = require(path.join(SRC, 'set3/meta3.js'));
const c = CFG.k10h1, C = require(path.join(SRC, c.mod + '.js'));
const m = META.e10h || {}; const base = { ...(m.hero || (m.poses && m.poses[0] && m.poses[0][1]) || {}) }; delete base.walk;
const B = C.build({ ...base, ...c.walk, walk: 0 });
const out = B.groups.map((g, i) => ({ i, mat: g.mat, k: g.k, prims: g.prims.map(p => ({ t: p.t, op: p.op || 0, a: p.a, b: p.b, ra: p.ra, rb: p.rb, q: p.q })) }));
fs.writeFileSync(path.resolve(__dirname, '../work/design_prims.json'), JSON.stringify(out));
for (const g of out) {
  const ps = g.prims.filter(p => !p.op), pts = ps.flatMap(p => p.t === 0 ? [p.a, p.b] : [p.a]);
  const cc = [0, 1, 2].map(k => (pts.reduce((s, q) => s + q[k], 0) / Math.max(pts.length, 1)).toFixed(2));
  const types = ps.map(p => p.t === 0 ? (Math.hypot(p.a[0] - p.b[0], p.a[1] - p.b[1], p.a[2] - p.b[2]) < 1e-4 ? 'o' : '-') : p.t === 1 ? 'E' : 'X').join('');
  console.log(g.i, 'mat', g.mat, 'n', ps.length, 'c', cc.join(','), types.slice(0, 40));
}
