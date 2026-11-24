// glb 쓰기(뼈 메시): rig.js · linebake.js 가 같이 쓴다
// 뼈: Root 아래에 평평하게, 스킨 1개. 메시 여러 개(몸 Body + 흰 선 Lines)가 같은 스킨(같은 뼈)을 쓴다.
// writeGLB(file, mesh | [mesh...], bones)  mesh = { name?, P, N, J, W, T, C? }
const fs = require('fs');
function writeGLB(file, meshIn, bones) {
  const meshes = Array.isArray(meshIn) ? meshIn : [meshIn];
  const nB = bones.length;
  const bufs = []; let off = 0; const views = [], accs = [];
  const add = (arr, target, comp, type, count, extra = {}) => { const b = Buffer.from(arr.buffer, arr.byteOffset, arr.byteLength); const pad = (4 - (b.length % 4)) % 4; views.push({ buffer: 0, byteOffset: off, byteLength: b.length, ...(target ? { target } : {}) }); bufs.push(b, Buffer.alloc(pad)); off += b.length + pad; accs.push({ bufferView: views.length - 1, componentType: comp, count, type, ...extra }); return accs.length - 1; };
  const gMeshes = [], materials = [], images = [], textures = [];
  meshes.forEach((mesh, mi) => {
    const nV = mesh.P.length / 3;
    let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9]; for (let i = 0; i < nV; i++) for (let k = 0; k < 3; k++) { mn[k] = Math.min(mn[k], mesh.P[i * 3 + k]); mx[k] = Math.max(mx[k], mesh.P[i * 3 + k]); }
    const attributes = { POSITION: add(mesh.P, 34962, 5126, 'VEC3', nV, { min: mn, max: mx }), NORMAL: add(mesh.N, 34962, 5126, 'VEC3', nV), JOINTS_0: add(mesh.J, 34962, 5123, 'VEC4', nV), WEIGHTS_0: add(mesh.W, 34962, 5126, 'VEC4', nV) };
    if (mesh.UV) attributes.TEXCOORD_0 = add(mesh.UV, 34962, 5126, 'VEC2', nV);
    if (mesh.C) attributes.COLOR_0 = add(mesh.C, 34962, 5126, 'VEC4', nV);
    const indices = add(mesh.T, 34963, 5125, 'SCALAR', mesh.T.length);
    const name = mesh.name || (mi === 0 ? 'Body' : 'Mesh' + mi);
    const mat = { name, pbrMetallicRoughness: { baseColorFactor: mesh.color || (mesh.C ? [1, 1, 1, 1] : [0.05, 0.05, 0.06, 1]), metallicFactor: 0, roughnessFactor: 1 } };
    if (mesh.emissivePNG) { // (발광 텍스처: 시안 그림. 로블록스 가져오기가 SurfaceAppearance 발광 마스크로 바꾼다)
      const iv = views.length; const ib = Buffer.from(mesh.emissivePNG); const pad = (4 - ib.length % 4) % 4; views.push({ buffer: 0, byteOffset: off, byteLength: ib.length }); bufs.push(ib, Buffer.alloc(pad)); off += ib.length + pad;
      images.push({ name: name + '_E', mimeType: 'image/png', bufferView: iv }); textures.push({ source: images.length - 1, sampler: 0 });
      mat.emissiveTexture = { index: textures.length - 1 }; mat.emissiveFactor = [1, 1, 1];
    }
    materials.push(mat);
    gMeshes.push({ name, primitives: [{ attributes, indices, material: mi }] });
  });
  const ibm = new Float32Array(16 * (nB + 1)); for (let j = 0; j <= nB; j++) { const c = j === 0 ? [0, 0, 0] : bones[j - 1].c; ibm.set([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -c[0], -c[1], -c[2], 1], 16 * j); }
  const aB = add(ibm, null, 5126, 'MAT4', nB + 1);
  const meshNodes = gMeshes.map((m, mi) => ({ name: m.name, mesh: mi, skin: 0 }));
  const nodes = [{ name: 'Root', children: bones.map((_, i) => i + 1) }, ...bones.map(b => ({ name: b.name, translation: b.c })), ...meshNodes];
  const gltf = { asset: { version: '2.0', generator: 'echophobia rig.js' }, scene: 0, scenes: [{ nodes: [0, ...meshNodes.map((_, i) => nB + 1 + i)] }], nodes, meshes: gMeshes, materials, skins: [{ joints: [0, ...bones.map((_, i) => i + 1)], skeleton: 0, inverseBindMatrices: aB }], accessors: accs, bufferViews: views, ...(images.length ? { images, textures, samplers: [{ magFilter: 9729, minFilter: 9987, wrapS: 33071, wrapT: 33071 }] } : {}), buffers: [{ byteLength: off }] };
  let json = Buffer.from(JSON.stringify(gltf)); json = Buffer.concat([json, Buffer.alloc((4 - json.length % 4) % 4, 0x20)]);
  const bin = Buffer.concat(bufs);
  const head = Buffer.alloc(12); head.writeUInt32LE(0x46546C67, 0); head.writeUInt32LE(2, 4); head.writeUInt32LE(12 + 8 + json.length + 8 + bin.length, 8);
  const ch = (n, t) => { const h = Buffer.alloc(8); h.writeUInt32LE(n, 0); h.writeUInt32LE(t, 4); return h; };
  fs.writeFileSync(file, Buffer.concat([head, ch(json.length, 0x4E4F534A), json, ch(bin.length, 0x004E4942), bin]));
}

module.exports = { writeGLB };
