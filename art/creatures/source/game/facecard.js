// 얼굴은 시안 그림 그대로: 시안 렌더러로 얼굴 정면(쉬는 자세)과 점프스케어용 덮침 자세 정면을 찍는다(투명 배경 PNG).
//   node facecard.js k4h1 ...  → out/face/<id>_face.png, out/face/<id>_scare.png, out/face/<id>.json
// 얼굴 판: 얼굴 틀(anat.face/head 의 가운데·크기·앞쪽)에서 앞쪽으로 직교 투영, 크기 = 2.6 × 얼굴 반지름.
// 게임은 이 판을 얼굴 앞에 붙이고(가장 가까운 뼈를 따라감) 화면 UI 로 그려 빛 없이 시안 밝기 그대로 보인다.
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const { CFG } = require('./bake.js');
const SRC = path.join(__dirname, '..');
const META = Object.assign({}, require(path.join(SRC, 'set1/meta.js')), require(path.join(SRC, 'set2/meta2.js')), require(path.join(SRC, 'set3/meta3.js')), require(path.join(SRC, 'set4/meta4.js')));
const OUTD = path.join(__dirname, 'out', 'face'); fs.mkdirSync(OUTD, { recursive: true });
const EDGE = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const V = { sub: (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]], add: (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]], mul: (a, k) => [a[0] * k, a[1] * k, a[2] * k], dot: (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2], cross: (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]] };
const norm = a => { const l = Math.hypot(...a) || 1; return a.map(x => x / l); };
const G = v => [-v[0], v[1], -v[2]];

function shot(setDir, spec, file) {
  const html = fs.readFileSync(path.join(setDir, 'view.html'), 'utf8').replace('<body style="margin:0;background:#050608">', '<body style="margin:0;background:transparent">').replace('/*SPEC*/', () => 'const SPEC=' + JSON.stringify(spec) + ';');
  const h = file.replace(/\.png$/, '.html'); fs.writeFileSync(h, html);
  const tmp = path.join(process.env.TEMP, 'edge-face-' + process.pid);
  try { fs.unlinkSync(file); } catch (e) {}
  execFileSync(EDGE, ['--headless=new', '--use-angle=d3d11', '--mute-audio', '--hide-scrollbars', '--force-device-scale-factor=1', '--default-background-color=00000000', `--window-size=${spec.W},${spec.H}`, '--timeout=300000', `--user-data-dir=${tmp}`, `--screenshot=${file}`, 'file:///' + encodeURI(h.split(path.sep).join('/'))], { stdio: 'ignore', timeout: 400000 });
  fs.unlinkSync(h); try { fs.rmSync(tmp, { recursive: true, force: true }); } catch (e) {}
  if (!fs.existsSync(file)) throw new Error('render failed ' + file);
}

for (const id of process.argv.slice(2)) {
  const c = CFG[id]; const setDir = path.join(SRC, path.dirname(c.mod)), C = require(path.join(SRC, c.mod + '.js'));
  const m = META[path.basename(c.mod)] || {}, base = { ...(m.hero || (m.poses && m.poses[0] && m.poses[0][1]) || {}) }; const PK = c.phase || 'walk'; delete base[PK];
  const restP = { ...base, ...c.walk, [PK]: c.phaseAmp ? (c.phaseBase || 0) : 0 };
  const AN = require(path.join(setDir, 'anat.js')), faces = [];
  for (const fn of ['face', 'head']) if (typeof AN[fn] === 'function' && !AN[fn].__rec) { const orig = AN[fn]; AN[fn] = function (B, F, sz, ...rest) { (AN.__faces || []).push({ o: F && F.o, z: F && F.z, y: F && F.y, s: typeof sz === 'number' ? sz : 1 }); return orig.call(this, B, F, sz, ...rest); }; AN[fn].__rec = true; }
  AN.__faces = faces; const b = C.build(restP).data(); AN.__faces = null;
  const H = b.mx[1] - b.mn[1];
  const fc = faces.length ? faces.reduce((a, f) => (a && a.s >= f.s ? a : f), null) : null;
  const faceC = fc && fc.o ? fc.o : [(b.mn[0] + b.mx[0]) / 2, b.mx[1] - H * .12, (b.mn[2] + b.mx[2]) / 2];
  const faceR = fc ? Math.max(.3, fc.s * .95) : H * .12;
  const fz = fc && fc.z ? norm(fc.z) : [0, 0, 1];
  const yaw = Math.atan2(fz[0], fz[2]) * 180 / Math.PI, pitch = Math.asin(Math.max(-1, Math.min(1, fz[1]))) * 180 / Math.PI;
  const S = 1024, size = faceR * 2.6, scale = S / size;
  // 1) 얼굴 판: 얼굴 앞쪽에서 직교, 시안과 같은 선 굵기·빛 번짐
  shot(setDir, { W: S, H: S, bg: 'rgba(0,0,0,0)', bodies: [b], panels: [{ x: 0, y: 0, w: S, h: S, body: 0, yaw, pitch, scale, target: faceC, lw: S / 420, ss: 2, glow: .25, border: 0, clip: [S / 2, S / 2, faceR * +(process.env.FACECLIP || .62) * scale] }] }, path.join(OUTD, id + '_face.png')); // (얼굴 둘레만 동그랗게)
  // 2) 점프스케어: 덮침 자세, 얼굴·상체를 정면에서(얼굴 반지름 4배 범위)
  const ba = C.build({ ...base, ...c.attack }).data();
  shot(setDir, { W: S, H: S, bg: 'rgba(0,0,0,0)', bodies: [ba], panels: [{ x: 0, y: 0, w: S, h: S, body: 0, yaw, pitch: pitch + 4, scale: S / (faceR * 3.6), target: V.add(faceC, [0, -faceR * .5, 0]), lw: S / 380, ss: 2, glow: .3, border: 0 }] }, path.join(OUTD, id + '_scare.png'));
  // 판의 자리(게임 좌표: x·z 뒤집기): 가운데 = 얼굴 가운데 + 앞쪽 × 반지름(코끝 앞), 앞 방향, 위 방향
  const camDir = (() => { const y = yaw * Math.PI / 180, p = pitch * Math.PI / 180; return [Math.sin(y) * Math.cos(p), Math.sin(p), Math.cos(y) * Math.cos(p)]; })();
  const R = norm(V.cross(camDir.map(v => -v), [0, 1, 0])), U = V.cross(R, camDir.map(v => -v));
  const center = V.add(faceC, V.mul(camDir, faceR * 1.05));
  const info = { id, faceC: G(faceC), center: G(center), front: G(camDir), up: G(U), size: +size.toFixed(4), r: +faceR.toFixed(4), from: fc ? 'anat' : 'top' };
  fs.writeFileSync(path.join(OUTD, id + '.json'), JSON.stringify(info));
  console.log(id, 'face', info.from, 'size', info.size.toFixed(2));
}
