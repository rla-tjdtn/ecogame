// node look.js <id> [yaw pitch scale] — 빠른 확인(3/4 크게 + 앞·옆·뒤 작게)
const { render } = require('./sculpt.js'); const id = process.argv[2], C = require('./' + id + '.js'); const pose = process.argv[6] ? JSON.parse(process.argv[6]) : {};
const b = C.build(pose).data(), cy = (b.mn[1] + b.mx[1]) / 2, sz = Math.max(b.mx[1] - b.mn[1], (b.mx[0] - b.mn[0]), (b.mx[2] - b.mn[2]));
const c = [(b.mn[0] + b.mx[0]) / 2, cy, (b.mn[2] + b.mx[2]) / 2]; const k = (w, h) => Math.min(h * .88 / (b.mx[1] - b.mn[1]), w * .88 / Math.hypot(b.mx[0] - b.mn[0], b.mx[2] - b.mn[2])); console.log(id, 'prims', b.np, 'groups', b.ng, b.mn.map(x => x.toFixed(1)).join(','), b.mx.map(x => x.toFixed(1)).join(','));
const y0 = +(process.argv[3] ?? 35), p0 = +(process.argv[4] ?? 6), s0 = +(process.argv[5] || 1);
const P = [{ x: 0, y: 0, w: 900, h: 1000, yaw: y0, pitch: p0, scale: k(900, 1000) * s0, target: c, bg: 'hero', lw: 2.3 }];
[[0, '앞'], [90, '옆'], [180, '뒤']].forEach(([yaw, t], i) => P.push({ x: 900, y: i * 334, w: 420, h: 333, yaw, pitch: 2, scale: k(420, 333), target: c, bg: 1, lw: 1.5, title: t }));
const t = Date.now(); console.log(render({ W: 1320, H: 1002, bodies: [b], panels: P }, `out/${id}_look.png`), Date.now() - t + 'ms');
