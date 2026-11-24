// node sheet.js id... — 괴물별 최종 디자인 시트(대표·4방향·얼굴·동작·음파·목업) + 대표 그림 단독
const { render } = require('./sculpt.js'), M = require('./meta.js'), path = require('path');
const OUT = path.join(__dirname, '..', '..', 'v6'); require('fs').mkdirSync(OUT, { recursive: true });
const LOW = { c3n: 20, c4n: 13, c9n: 22, c5n: 10, c10n: 10, c1n: 8 };
function fit(b, w, h, yaw, pitch = 0, m = .9) { // 투영한 상자 기준 배율·중심
  const y = yaw * Math.PI / 180, c = Math.cos(y), s = Math.sin(y), hx = (b.mx[0] - b.mn[0]) / 2, hz = (b.mx[2] - b.mn[2]) / 2, hy = (b.mx[1] - b.mn[1]) / 2; const W = Math.abs(c) * hx + Math.abs(s) * hz, H = hy + Math.sin(pitch * Math.PI / 180) * Math.hypot(hx, hz) * .5; return { scale: Math.min(w * m / 2 / (W * .9), h * m / 2 / H), target: b.mn.map((v, i) => (v + b.mx[i]) / 2) };
}
const wrap = (t, n) => { const o = []; let s = ''; for (const w of t.split(' ')) { if ((s + ' ' + w).length > n) { o.push(s); s = w; } else s = s ? s + ' ' + w : w; } if (s) o.push(s); return o; };
for (const id of process.argv.slice(2)) {
  const C = require('./' + id + '.js'), m = M[id], P = m.poses, hp = m.hero || (P[0][1]); const bs = [C.build(hp).data(), ...P.map(q => C.build(q[1]).data())], b = bs[0]; const panels = [], text = [];
  const floor = [(b.mn[0] + b.mx[0]) / 2, 0, (b.mn[2] + b.mx[2]) / 2], ceil = id === 'c8n';
  const hero = (x, y, w, h, ss) => ({ x, y, w, h, body: 0, yaw: m.yaw, pitch: LOW[id] || 5, ...fit(b, w, h, m.yaw, LOW[id] || 5, .95), bg: 'hero', lw: w / 480, ss, glow: .25, segs: ceil ? [] : [[[floor[0] - 9, 0, floor[2] + 9 * Math.tan(m.yaw / 57.3)], [floor[0] + 9, 0, floor[2] - 9 * Math.tan(m.yaw / 57.3)], .16]] });
  render({ W: 1200, H: 1400, bodies: [b], panels: [hero(0, 0, 1200, 1400, 2)], text: [{ t: `${m.ch}장 ${C.name}`, x: 40, y: 64, s: 30, b: 1 }, { t: C.kind.split('·')[0].trim() + ' · ' + m.place, x: 40, y: 96, s: 17, c: '#8d97a6' }] }, path.join(OUT, id + '_hero.png'));
  panels.push(hero(0, 110, 860, 1000, 2));
  [['정면', 0], ['3/4', 45], ['측면', 90], ['뒷면', 180]].forEach(([t, yw], i) => panels.push({ x: 870 + i * 284, y: 110, w: 278, h: 330, body: 0, yaw: yw, pitch: 2, ...fit(b, 278, 300, yw, 2, .88), bg: 1, lw: 1.25, title: t, glow: .15 }));
  panels.push({ x: 870, y: 446, w: 420, h: 420, body: 0, yaw: m.face[2], pitch: 2, scale: m.face[1], target: m.face[0], bg: 1, lw: 2, title: '핵심 부위', glow: .2 });
  P.forEach(([t], i) => panels.push({ x: 1296 + i * 237, y: 446, w: 232, h: 420, body: 1 + i, yaw: m.yaw, pitch: LOW[id] || 4, ...fit(bs[1 + i], 232, 400, m.yaw, LOW[id] || 4, .92), bg: 1, lw: 1.15, title: '동작 — ' + t, glow: .15 }));
  // 음파: 채움 없이 선만 (가까이 · 멀리 · 일부)
  const cz = (b.mn[2] + b.mx[2]) / 2, cx = (b.mn[0] + b.mx[0]) / 2, ey = 5, H = b.mx[1]; const look = d => ({ eye: [cx + Math.sin(.38) * d, ey, cz + Math.cos(.38) * d], look: [cx, Math.min(5, H * .52), cz], fov: 62 });
  [['음파 · 12스터드', 12, null], ['음파 · 28스터드', 28, null], ['음파 · 일부만', 11, [150, 150, 92]]].forEach(([t, d, clip], i) => panels.push({ x: 870 + i * 215, y: 872, w: 210, h: 238, body: 1, persp: look(d), bg: 1, lw: 1.1, fill: 0, title: t, fade: 38, glow: .3, clip }));
  // 목업: 어두운 복도 1인칭
  const segs = []; const zn = cz + 15; for (const x of [-5, 5]) for (const y of [0, 14]) segs.push([[cx + x, y, zn], [cx + x, y, cz - 30]]); for (let z = cz + 8; z > cz - 30; z -= 8) { segs.push([[cx - 5, 0, z], [cx - 5, 14, z], .6], [[cx + 5, 0, z], [cx + 5, 14, z], .6], [[cx - 5, 14, z], [cx + 5, 14, z], .5], [[cx - 5, 0, z], [cx + 5, 0, z], .4]); }
  const dist = Math.max(11, Math.hypot(b.mx[0] - b.mn[0], b.mx[1]) * 1.25); panels.push({ x: 1515, y: 872, w: 493, h: 238, body: 3, persp: { eye: [cx + 1.2, 5, cz + dist], look: [cx - .2, Math.min(5, H * .5), cz], fov: 66 }, bg: 1, lw: 1.1, fill: 0, title: '게임 화면 — 음파 직후', fade: 40, segs, far: 40, glow: .35 });
  text.push({ t: `${m.ch}장 ${m.place} — ${C.name}`, x: 24, y: 52, s: 32, b: 1 }, { t: C.kind.split('·')[0].trim() + ' 이동', x: 24, y: 86, s: 17, c: '#d9a54a' });
  let y = 1148; for (const [k, v] of [['콘셉트', m.concept], ['공포 원리', m.fear], ['움직임', m.move], ['음파 포인트', m.sonar]]) { text.push({ t: k, x: 24, y, s: 16, b: 1, c: '#d9a54a' }); text.push({ t: v, x: 130, y, s: 16, c: '#d5dae2' }); y += 32; }
  console.log(id, render({ W: 2012, H: 1270, bodies: bs, panels, text }, path.join(OUT, id + '_sheet.png')));
}
