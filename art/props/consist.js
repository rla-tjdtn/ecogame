// 같은 종류 소품의 배치끼리 소품 좌표에서 모양이 같은가(기준 좌표계가 일관된가) 검사
const { load } = require('./census.js'); const F = require('./frames.js');
const recs = load(); const by = {};
for (const r of recs) for (const m of r.models) (by[r.fn + '/' + m.name] ||= []).push({ r, m });
for (const [key, list] of Object.entries(by)) {
  const groups = {};
  for (const it of list) (groups[it.m.parts.length] ||= []).push(it);
  let worst = 0, sizeVar = [0, 0, 0];
  const s0 = F.frameOf(list[0].m.parts).size;
  for (const g of Object.values(groups)) {
    const ref = g[0]; const fr = F.frameOf(ref.m.parts); const rl = ref.m.parts.map(p => F.toLocal(fr, p.cf.slice(0, 3)));
    for (const it of g.slice(1)) {
      const f = F.frameOf(it.m.parts);
      it.m.parts.forEach((p, k) => { const l = F.toLocal(f, p.cf.slice(0, 3)); worst = Math.max(worst, Math.hypot(l[0] - rl[k][0], l[1] - rl[k][1], l[2] - rl[k][2])); });
    }
  }
  for (const it of list) { const s = F.frameOf(it.m.parts).size; for (let k = 0; k < 3; k++) sizeVar[k] = Math.max(sizeVar[k], Math.abs(s[k] - s0[k])); }
  console.log(key.padEnd(42), String(list.length).padStart(4), 'groups', Object.keys(groups).length, 'dev', worst.toFixed(2), 'size', s0.map(x => x.toFixed(1)).join('x'), 'var', sizeVar.map(x => x.toFixed(1)).join(','));
}
