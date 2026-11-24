// 소품 메시 내보내기: models/*.js → 묶음마다 out/glb/<묶음>.glb(메시 노드 = 키, '.' → '_') + src/shared/PropMeshData/<묶음>.luau(선 데이터).
//   node art/props/export.js [묶음 ...]     (없으면 전부)
// 에셋 번호는 art/props/assets.json(upload.js 가 적는다)에서 읽어 데이터 모듈에 넣는다. glb 내용이 바뀌면 hash 가 달라져 upload.js 가 다시 올린다.
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const { Model } = require('./lib/model.js');
const { lineCost } = require('./lib/render.js');
const { models } = require('./models/index.js');
const ROOT = path.join(__dirname, '..', '..');
const GLBD = path.join(__dirname, 'out', 'glb'); fs.mkdirSync(GLBD, { recursive: true });
const DATAD = path.join(ROOT, 'src', 'shared', 'PropMeshData');
const ASSETS = path.join(__dirname, 'assets.json');

function writeGLB(file, meshes) {
  const bufs = []; let off = 0; const views = [], accs = [];
  const add = (arr, target, comp, type, count, extra = {}) => { const b = Buffer.from(arr.buffer, arr.byteOffset, arr.byteLength); const pad = (4 - (b.length % 4)) % 4; views.push({ buffer: 0, byteOffset: off, byteLength: b.length, ...(target ? { target } : {}) }); bufs.push(b, Buffer.alloc(pad)); off += b.length + pad; accs.push({ bufferView: views.length - 1, componentType: comp, count, type, ...extra }); return accs.length - 1; };
  const gm = [], nodes = [];
  meshes.forEach((m, i) => {
    const nV = m.P.length / 3; const mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9];
    for (let v = 0; v < nV; v++) for (let k = 0; k < 3; k++) { mn[k] = Math.min(mn[k], m.P[v * 3 + k]); mx[k] = Math.max(mx[k], m.P[v * 3 + k]); }
    const attributes = { POSITION: add(m.P, 34962, 5126, 'VEC3', nV, { min: mn, max: mx }), NORMAL: add(m.N, 34962, 5126, 'VEC3', nV) };
    gm.push({ name: m.name, primitives: [{ attributes, indices: add(m.I, 34963, 5125, 'SCALAR', m.I.length), material: 0 }] });
    nodes.push({ name: m.name, mesh: i, translation: m.at });
  });
  const gltf = { asset: { version: '2.0', generator: 'echophobia art/props/export.js' }, scene: 0, scenes: [{ nodes: nodes.map((_, i) => i) }], nodes, meshes: gm,
    materials: [{ name: 'Black', pbrMetallicRoughness: { baseColorFactor: [0.02, 0.02, 0.02, 1], metallicFactor: 0, roughnessFactor: 1 } }],
    accessors: accs, bufferViews: views, buffers: [{ byteLength: off }] };
  let json = Buffer.from(JSON.stringify(gltf)); json = Buffer.concat([json, Buffer.alloc((4 - json.length % 4) % 4, 0x20)]);
  const bin = Buffer.concat(bufs);
  const head = Buffer.alloc(12); head.writeUInt32LE(0x46546C67, 0); head.writeUInt32LE(2, 4); head.writeUInt32LE(12 + 8 + json.length + 8 + bin.length, 8);
  const ch = (n, t) => { const h = Buffer.alloc(8); h.writeUInt32LE(n, 0); h.writeUInt32LE(t, 4); return h; };
  const data = Buffer.concat([head, ch(json.length, 0x4E4F534A), json, ch(bin.length, 0x004E4942), bin]);
  fs.writeFileSync(file, data);
  return crypto.createHash('sha1').update(data).digest('hex').slice(0, 12);
}

const r2 = x => Math.round(x * 100) / 100;
const numList = a => a.map(x => { const v = r2(x); return Object.is(v, -0) ? '0' : String(v); }).join(',');

function exportGroup(group, assets) {
  const keys = Object.keys(models).filter(k => k.startsWith(group + '.')).sort();
  const meshes = [], items = [];
  let col = 0;
  for (const key of keys) {
    const m = new Model(); models[key](m); const b = m.build();
    if (!b.tris) { console.log('  skip (no mesh)', key); continue; }
    if (b.tris > 18000) throw new Error(key + ' too many triangles ' + b.tris);
    const mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9];
    for (let i = 0; i < b.P.length; i += 3) for (let k = 0; k < 3; k++) { mn[k] = Math.min(mn[k], b.P[i + k]); mx[k] = Math.max(mx[k], b.P[i + k]); }
    const c = [0, 1, 2].map(k => (mn[k] + mx[k]) / 2), size = [0, 1, 2].map(k => Math.max(0.05, mx[k] - mn[k]));
    const P = new Float32Array(b.P.length); for (let i = 0; i < P.length; i += 3) for (let k = 0; k < 3; k++) P[i + k] = b.P[i + k] - c[k];
    // (노드끼리 겹치지 않게 옆으로 늘어놓는다: 가져온 모델을 Studio 에서 볼 때 보기 좋게. 게임은 위치를 쓰지 않는다)
    meshes.push({ name: key.replace(/\./g, '_'), P, N: b.N, I: b.I, at: [col, 0, 0] }); col += size[0] + 2;
    const seg = [], view = [];
    for (const s of b.seg) seg.push(s[0] - c[0], s[1] - c[1], s[2] - c[2], s[3] - c[0], s[4] - c[1], s[5] - c[2]);
    for (const v of b.view) view.push(v.t === 'b' ? 1 : 0, v.a[0] - c[0], v.a[1] - c[1], v.a[2] - c[2], v.b[0] - c[0], v.b[1] - c[1], v.b[2] - c[2], v.r1, v.r2);
    const cost = lineCost(b);
    items.push(`\t[${JSON.stringify(key)}] = { -- 삼각형 ${b.tris}, 선 ${cost.total}\n\t\tz = { ${numList(size)} },\n\t\tc = { ${numList(c)} },\n\t\ts = { ${numList(seg)} },\n\t\tv = { ${numList(view)} },\n\t},`);
  }
  if (!meshes.length) return null;
  const hash = writeGLB(path.join(GLBD, group + '.glb'), meshes);
  const a = assets[group] || {};
  const asset = a.hash === hash ? a.id || 0 : 0; // (내용이 바뀌었으면 다시 올릴 때까지 0 = 기본 도형 그대로)
  const lua = `--!nocheck\n-- 자동 생성(art/props/export.js) — 손으로 고치지 말 것. 묶음 ${group}: 메시 ${meshes.length}개, glb ${hash}\nreturn {\n\tasset = ${asset},\n\thash = "${hash}",\n\titems = {\n${items.join('\n')}\n\t},\n}\n`;
  fs.writeFileSync(path.join(DATAD, group + '.luau'), lua);
  console.log(`${group}: ${meshes.length} meshes, glb ${hash}, asset ${asset || '(not uploaded)'}`);
  return { group, hash, asset };
}
module.exports = { exportGroup };
if (require.main === module) {
  const assets = fs.existsSync(ASSETS) ? JSON.parse(fs.readFileSync(ASSETS, 'utf8')) : {};
  let groups = process.argv.slice(2);
  if (!groups.length) groups = [...new Set(Object.keys(models).map(k => k.split('.')[0]))];
  for (const g of groups) exportGroup(g, assets);
}
