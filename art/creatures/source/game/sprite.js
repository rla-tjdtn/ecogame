// 시안 그림을 게임에 그대로: 시안을 만든 바로 그 조각 몸 + 그 렌더러(setN/view.html)로
// 8방향 × 9자세(걷기 4 · 추격 4 · 덮침 1)를 찍어 투명 배경 시트(1024×1024, 칸 256×341, 4×3 = 12칸)로 묶는다.
//   node sprite.js k1h1 ...   → out/sprites/<id>_<n>.png (n = 1..6) + src/shared/CreatureSprites/<id>.luau(칸 배치·크기)
// 칸 번호 i = 방향 * 9 + 자세 (방향 0 = 정면, 45°씩 괴물 기준 시계 반대(+yaw)), 시트 = floor(i / 12)
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const { CFG } = require('./bake.js');
const SRC = path.join(__dirname, '..');
// 시안 대표 그림의 자세(meta hero, 없으면 첫 동작)를 기본으로: 걷기·추격·덮침은 그 위에 얹는다
const META = Object.assign({}, require(path.join(SRC, 'set1/meta.js')), require(path.join(SRC, 'set2/meta2.js')), require(path.join(SRC, 'set3/meta3.js')), require(path.join(SRC, 'set4/meta4.js')));
const OUTD = path.join(__dirname, 'out', 'sprites'); fs.mkdirSync(OUTD, { recursive: true });
const LUAD = path.join(__dirname, '..', '..', '..', '..', 'src', 'shared', 'CreatureSprites'); fs.mkdirSync(LUAD, { recursive: true });
const YAWS = 8, PITCH = 6, PER = 12, LAYOUTS = [[6, 2], [4, 3], [3, 4], [2, 6]]; // 시트당 12칸: 괴물 모양에 맞춰 칸 비율을 고른다
const EDGE = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';

function shot(setDir, spec, file) {
  const html = fs.readFileSync(path.join(setDir, 'view.html'), 'utf8').replace('<body style="margin:0;background:#050608">', '<body style="margin:0;background:transparent">').replace('/*SPEC*/', () => 'const SPEC=' + JSON.stringify(spec) + ';');
  const h = file.replace(/\.png$/, '.html'); fs.writeFileSync(h, html);
  const tmp = path.join(process.env.TEMP, 'edge-sprite-' + process.pid);
  try { fs.unlinkSync(file); } catch (e) {}
  execFileSync(EDGE, ['--headless=new', '--use-angle=d3d11', '--mute-audio', '--hide-scrollbars', '--force-device-scale-factor=1', '--default-background-color=00000000', `--window-size=${spec.W},${spec.H}`, '--timeout=300000', `--user-data-dir=${tmp}`, `--screenshot=${file}`, 'file:///' + encodeURI(h.split(path.sep).join('/'))], { stdio: 'ignore', timeout: 400000 });
  fs.unlinkSync(h); try { fs.rmSync(tmp, { recursive: true, force: true }); } catch (e) {}
  if (!fs.existsSync(file)) throw new Error('render failed ' + file);
}

for (const id of process.argv.slice(2)) {
  const c = CFG[id]; if (!c) throw new Error('no cfg ' + id);
  const setDir = path.join(SRC, path.dirname(c.mod)), C = require(path.join(SRC, c.mod + '.js'));
  const m = META[path.basename(c.mod)] || {}, base = { ...(m.hero || (m.poses && m.poses[0] && m.poses[0][1]) || {}) }; delete base[c.phase || 'walk'];
  const PK = c.phase || 'walk', ph = (o, v) => ({ ...base, ...o, [PK]: c.phaseAmp ? (c.phaseBase || 0) + c.phaseAmp * Math.sin(v * 2 * Math.PI) : v }); // (흔들말: 각도라서 사인으로)
  const poses = [0, 1, 2, 3].map(k => ph(c.walk, k / 4)).concat([0, 1, 2, 3].map(k => ph(c.chase, k / 4)), [{ ...base, ...c.attack }]);
  const bodies = poses.map(p => C.build(p).data());
  // 모든 자세를 담는 상자 → 한 괴물은 모든 칸에서 같은 배율·같은 기준점(바닥 가운데)
  let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9]; for (const b of bodies) for (let i = 0; i < 3; i++) { mn[i] = Math.min(mn[i], b.mn[i] + .2); mx[i] = Math.max(mx[i], b.mx[i] - .2); }
  const cx = 0, cz = (mn[2] + mx[2]) / 2; // 몸은 x = 0 기준 좌우 대칭 축
  const R = Math.max(...[[mn[0], mn[2]], [mn[0], mx[2]], [mx[0], mn[2]], [mx[0], mx[2]]].map(([x, z]) => Math.hypot(x - cx, z - cz)));
  const floor = Math.min(0, mn[1]), top = mx[1];
  const pt = PITCH * Math.PI / 180, Hproj = (top - floor) * Math.cos(pt) + 2 * R * Math.sin(pt);
  let best = null; for (const [cols, rows] of LAYOUTS) { const cw = Math.floor(1024 / cols), ch = Math.floor(1024 / rows), sc = Math.min(cw * .96 / (2 * R), ch * .96 / Hproj); if (!best || sc > best.sc) best = { cols, rows, cw, ch, sc }; }
  const { cols: COLS, rows: ROWS, cw: CW, ch: CH, sc: scale } = best; // scale = 화면 px / 스터드
  // 기준점: 바닥 가운데(cx, floor, cz)가 칸에서 놓이는 곳 → 위아래 가운데 정렬
  const target = [cx, (floor + top) / 2, cz];
  const nSheets = Math.ceil(YAWS * poses.length / PER);
  for (let s = 0; s < nSheets; s++) {
    const panels = [];
    for (let k = 0; k < PER; k++) {
      const i = s * PER + k; if (i >= YAWS * poses.length) break;
      const yaw = Math.floor(i / poses.length) * 360 / YAWS, pose = i % poses.length;
      panels.push({ x: (k % COLS) * CW, y: Math.floor(k / COLS) * CH, w: CW, h: CH, body: pose, yaw, pitch: PITCH, scale, target, lw: Math.max(1.1, scale / 30), ss: 3, glow: .25, border: 0 });
    }
    const file = path.join(OUTD, `${id}_${s + 1}.png`);
    shot(setDir, { W: 1024, H: 1024, bg: 'rgba(0,0,0,0)', bodies, panels }, file);
    console.log(id, 'sheet', s + 1, '/', nSheets);
  }
  // 칸 크기(스터드)·기준점: 칸 가운데가 target, 바닥 가운데는 칸 가운데에서 아래로 (target.y - floor)
  const lua = `--!strict\n-- 자동 생성(art/creatures/source/game/sprite.js): ${c.name} 시안 그림 시트. 손으로 고치지 말 것\n` +
    `-- 칸 i = 방향 * ${poses.length} + 자세(0~3 걷기, 4~7 추격, 8 덮침), 방향 0 = 정면부터 ${360 / YAWS}°씩. 시트 = i // ${PER} + 1, 칸 안 = i % ${PER}\n` +
    `return {\n\tid = "${id}", name = "${c.name}",\n\tsheets = { ${Array(nSheets).fill(0).map(() => 0).join(', ')} }, -- 로블록스 이미지 에셋 번호(올린 뒤 채운다)\n` +
    `\tcols = ${COLS}, rows = ${ROWS}, cellPx = { ${CW}, ${CH} }, yaws = ${YAWS}, poses = ${poses.length},\n` +
    `\tsize = { ${(CW / scale).toFixed(3)}, ${(CH / scale).toFixed(3)} }, -- 칸 하나의 크기(스터드)\n` +
    `\tcenterY = ${(target[1] - floor).toFixed(3)}, -- 바닥에서 칸 가운데까지(스터드)\n\tcenterZ = ${cz.toFixed(3)}, -- 몸 기준(디자인 앞 +Z) 칸 가운데의 앞뒤 위치\n\tstride = ${c.stride},\n}\n`;
  fs.writeFileSync(path.join(LUAD, id + '.luau'), lua);
}
