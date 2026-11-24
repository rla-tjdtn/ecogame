// 시뮬레이터 결과(out/sim/stage*.jsonl)로 소품 종류별 배치 수·파트 수·음파 선(정적 모서리) 수·크기 변화를 표로.
//   node art/props/census.js [> out/census.txt]
const fs = require('fs'), path = require('path');
const OUT = path.join(__dirname, 'out', 'sim');
const ringSeg = r => Math.max(8, Math.min(24, Math.floor(r * 5) + 6));
function edgeCount(p) {
  const shape = (p.a && p.a.SonarShape) || (p.c === 'WedgePart' ? 'Wedge' : p.sh === 'Cylinder' ? 'Cylinder' : p.sh === 'Ball' ? 'Ball' : 'Box');
  if (p.tr >= 1 || !p.tags.includes('SonarRenderable')) return 0;
  const s = p.s;
  switch (shape) {
    case 'None': return 0;
    case 'Line': return 1;
    case 'Disc': return ringSeg(Math.min(s[1], s[2]) / 2);
    case 'Wedge': return 9;
    case 'Ball': return ringSeg(Math.min(...s) / 2);
    case 'Cylinder': { const r = Math.min(s[1], s[2]) / 2; return ringSeg(r) * (2 + ((p.a && p.a.SonarRings) || 0)) + 2; }
    default: return (p.a && p.a.SonarEdgeAxis) ? 4 : 12;
  }
}
function load() {
  const recs = [];
  for (const f of fs.readdirSync(OUT)) if (/^stage\d+\.jsonl$/.test(f)) for (const l of fs.readFileSync(path.join(OUT, f), 'utf8').split('\n')) if (l.trim()) recs.push(JSON.parse(l));
  return recs;
}
module.exports = { load, edgeCount };
if (require.main === module) {
  const recs = load();
  const by = {};
  for (const r of recs) {
    for (const m of r.models) {
      const key = r.fn + '/' + m.name;
      const e = by[key] || (by[key] = { key, stages: new Set(), n: 0, parts: 0, vis: 0, edges: 0, sizes: new Set(), special: 0 });
      e.stages.add(r.stage); e.n++;
      e.parts += m.parts.length;
      e.vis += m.parts.filter(p => p.tr < 1 && p.tags.includes('SonarRenderable')).length;
      e.edges += m.parts.reduce((a, p) => a + edgeCount(p), 0);
      e.special += m.parts.filter(p => p.tags.some(t => t !== 'SonarRenderable') || Object.keys(p.a).some(k => !k.startsWith('Sonar'))).length;
      e.sizes.add(m.parts.length);
    }
  }
  const rows = Object.values(by).sort((a, b) => b.edges - a.edges);
  let tot = { n: 0, parts: 0, edges: 0 };
  console.log('key'.padEnd(40), 'stg', 'count', 'parts/ea', 'vis/ea', 'edges/ea', 'edgesTot', 'variants', 'special');
  for (const e of rows) {
    tot.n += e.n; tot.parts += e.parts; tot.edges += e.edges;
    console.log(e.key.padEnd(40), [...e.stages].join(',').padEnd(4), String(e.n).padStart(5), (e.parts / e.n).toFixed(1).padStart(8), (e.vis / e.n).toFixed(1).padStart(6), (e.edges / e.n).toFixed(0).padStart(8), String(e.edges).padStart(8), String(e.sizes.size).padStart(4), e.special);
  }
  console.log('TOTAL types', rows.length, 'placements', tot.n, 'parts', tot.parts, 'edges', tot.edges);
  const perStage = {};
  for (const r of recs) for (const m of r.models) { const s = perStage[r.stage] || (perStage[r.stage] = { parts: 0, edges: 0 }); s.parts += m.parts.length; s.edges += m.parts.reduce((a, p) => a + edgeCount(p), 0); }
  console.log('per stage', JSON.stringify(perStage));
}
