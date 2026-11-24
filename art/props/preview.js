// 소품 메시 미리 보기: 위 줄 = 지금 게임(기본 도형 음파 선), 아래 줄 = 새 메시(음파 선). 선 수(선 파트 수)도 비교.
//   node art/props/preview.js Hospital.Bed [Hospital.Gurney ...]   → art/props/out/preview/<key>.png
//   node art/props/preview.js --group Hospital                       → 그 묶음 전부 + 요약표
// (먼저 node art/props/sim.js 로 시뮬레이터 결과를 새로 만들 것: 빌더에 PropMesh.dress 줄이 있어야 '지금 모습'을 찾는다)
const fs = require('fs'), path = require('path');
const { renderGrid, lineCost } = require('./lib/render.js');
const { fromParts } = require('./lib/prims.js');
const { Model, S } = require('./lib/model.js');
const { models } = require('./models/index.js');
const OUTD = path.join(__dirname, 'out', 'preview'); fs.mkdirSync(OUTD, { recursive: true });

// 시뮬레이터 결과에서 key 로 dress 된 첫 배치
let simCache = null;
function sim() {
  if (simCache) return simCache;
  simCache = {};
  const d = path.join(__dirname, 'out', 'sim');
  for (const f of fs.readdirSync(d)) if (/^stage\d+\.jsonl$/.test(f) || f === 'extra.jsonl') for (const l of fs.readFileSync(path.join(d, f), 'utf8').split('\n')) {
    if (!l.trim()) continue; const r = JSON.parse(l);
    for (const m of r.models) for (const ds of m.dress || []) {
      const e = simCache[ds.key] || (simCache[ds.key] = { n: 0, first: null });
      e.n++; if (!e.first) e.first = { r, m, ds, parts: ds.parts ? ds.parts.map(i => m.parts[i]) : m.parts };
    }
  }
  return simCache;
}
function buildAfter(key, sc) {
  const fn = models[key]; if (!fn) return null;
  const m = new Model(); if (sc && (sc[0] !== 1 || sc[1] !== 1 || sc[2] !== 1)) m.push(S(sc[0], sc[1], sc[2]));
  fn(m); return m.build();
}
function one(key) {
  const s = sim()[key];
  const before = s ? fromParts(s.first.parts, s.first.ds.cf).build() : null;
  const after = buildAfter(key, s ? s.first.ds.sc : null);
  if (!after) { console.log(key, 'no model'); return null; }
  const rows = before ? [{ build: before }, { build: after }] : [{ build: after }];
  fs.writeFileSync(path.join(OUTD, key + '.png'), renderGrid(rows));
  const cb = before ? lineCost(before) : null, ca = lineCost(after);
  const row = { key, placements: s ? s.n : 0, before: cb ? cb.total : null, after: ca.total, afterStatic: ca.static, afterView: ca.view, tris: after.tris };
  console.log(`${key.padEnd(34)} n=${String(row.placements).padStart(4)}  lines before ${String(row.before ?? '-').padStart(4)} → after ${String(row.after).padStart(4)} (static ${ca.static}, view ${ca.view})  tris ${after.tris}`);
  return row;
}
if (require.main === module) {
  const args = process.argv.slice(2);
  let keys = args.filter(a => !a.startsWith('--'));
  const gi = args.indexOf('--group'); if (gi >= 0) keys = Object.keys(models).filter(k => k.startsWith(args[gi + 1] + '.'));
  if (args.includes('--all')) keys = Object.keys(models);
  const rows = keys.map(one).filter(Boolean);
  if (rows.length > 1) { let b = 0, a = 0; for (const r of rows) { b += (r.before || 0) * r.placements; a += r.after * r.placements; } console.log(`TOTAL (x placements) before ${b} → after ${a} (${(a / Math.max(1, b) * 100).toFixed(0)}%)`); }
}
module.exports = { one, sim, buildAfter };
