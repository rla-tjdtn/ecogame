// 장마다 메시 소품 삼각형 합(배치 수 × 메시 삼각형) — 렌더 부담 추정. LOW=1 이면 낮은 폴리 몸
const fs = require('fs'), path = require('path');
const { Model } = require('./lib/model.js');
const { models } = require('./models/index.js');
const cache = {};
const tris = k => { if (cache[k] === undefined) { const fn = models[k]; if (!fn) return (cache[k] = 0); const m = new Model(); if (process.env.LOW) m.low = true; fn(m); cache[k] = m.build().tris; } return cache[k]; };
const d = path.join(__dirname, 'out', 'sim');
for (const f of fs.readdirSync(d).filter(f => /^stage\d+\.jsonl$/.test(f)).sort((a, b) => parseInt(a.slice(5)) - parseInt(b.slice(5)))) {
  let t = 0, n = 0; const top = {};
  for (const l of fs.readFileSync(path.join(d, f), 'utf8').split('\n')) { if (!l.trim()) continue; for (const m of JSON.parse(l).models) for (const ds of m.dress || []) { const x = tris(ds.key); t += x; n++; top[ds.key] = (top[ds.key] || 0) + x; } }
  const best = Object.entries(top).sort((a, b) => b[1] - a[1]).slice(0, 4).map(([k, v]) => k + ' ' + (v / 1000).toFixed(0) + 'k').join(', ');
  console.log(f.replace('.jsonl', ''), 'meshes', n, 'tris', (t / 1000).toFixed(0) + 'k', '|', best);
}
