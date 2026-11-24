// glb 쓰기(뼈 메시): rig.js · linebake.js 가 같이 쓴다
const fs = require('fs');
// glb 쓰기(뼈: Root 아래에 평평하게, 스킨 1개)
function writeGLB(file, mesh, bones) {
  const nV = mesh.P.length / 3, nB = bones.length;
  const bufs = []; let off = 0; const views = [], accs = [];
  const add = (arr, target, comp, type, count, extra = {}) => { const b = Buffer.from(arr.buffer, arr.byteOffset, arr.byteLength); const pad = (4 - (b.length % 4)) % 4; views.push({ buffer: 0, byteOffset: off, byteLength: b.length, ...(target ? { target } : {}) }); bufs.push(b, Buffer.alloc(pad)); off += b.length + pad; accs.push({ bufferView: views.length - 1, componentType: comp, count, type, ...extra }); return accs.length - 1; };
  let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9]; for (let i = 0; i < nV; i++) for (let k = 0; k < 3; k++) { mn[k] = Math.min(mn[k], mesh.P[i * 3 + k]); mx[k] = Math.max(mx[k], mesh.P[i * 3 + k]); }
  const aP = add(mesh.P, 34962, 5126, 'VEC3', nV, { min: mn, max: mx });
  const aN = add(mesh.N, 34962, 5126, 'VEC3', nV);
  const aJ = add(mesh.J, 34962, 5123, 'VEC4', nV);
  const aW = add(mesh.W, 34962, 5126, 'VEC4', nV);
  const aC = mesh.C ? add(mesh.C, 34962, 5126, 'VEC4', nV) : null;
  const aI = add(mesh.T, 34963, 5125, 'SCALAR', mesh.T.length);
  const ibm = new Float32Array(16 * (nB + 1)); for (let j = 0; j <= nB; j++) { const c = j === 0 ? [0, 0, 0] : bones[j - 1].c; ibm.set([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -c[0], -c[1], -c[2], 1], 16 * j); }
  const aB = add(ibm, null, 5126, 'MAT4', nB + 1);
  const nodes = [{ name: 'Root', children: bones.map((_, i) => i + 1) }, ...bones.map(b => ({ name: b.name, translation: b.c })), { name: 'Body', mesh: 0, skin: 0 }];
  const gltf = { asset: { version: '2.0', generator: 'echophobia rig.js' }, scene: 0, scenes: [{ nodes: [0, nB + 1] }], nodes, meshes: [{ name: 'Body', primitives: [{ attributes: Object.assign({ POSITION: aP, NORMAL: aN, JOINTS_0: aJ, WEIGHTS_0: aW }, aC !== null ? { COLOR_0: aC } : {}), indices: aI, material: 0 }] }], materials: [{ name: 'Skin', pbrMetallicRoughness: { baseColorFactor: mesh.C ? [1, 1, 1, 1] : [0.05, 0.05, 0.06, 1], metallicFactor: 0, roughnessFactor: 1 } }], skins: [{ joints: [0, ...bones.map((_, i) => i + 1)], skeleton: 0, inverseBindMatrices: aB }], accessors: accs, bufferViews: views, buffers: [{ byteLength: off }] };
  let json = Buffer.from(JSON.stringify(gltf)); json = Buffer.concat([json, Buffer.alloc((4 - json.length % 4) % 4, 0x20)]);
  const bin = Buffer.concat(bufs);
  const head = Buffer.alloc(12); head.writeUInt32LE(0x46546C67, 0); head.writeUInt32LE(2, 4); head.writeUInt32LE(12 + 8 + json.length + 8 + bin.length, 8);
  const ch = (n, t) => { const h = Buffer.alloc(8); h.writeUInt32LE(n, 0); h.writeUInt32LE(t, 4); return h; };
  fs.writeFileSync(file, Buffer.concat([head, ch(json.length, 0x4E4F534A), json, ch(bin.length, 0x004E4942), bin]));
}

module.exports = { writeGLB };
