// 괴물 3D 파일 내보내기(뼈 + 웨이트 + 동작 클립): node export-anim.js k7h4:sullae k10h1:tteunnun
// 읽는 것: out/mesh/<id>_anim.json(rig.js 결과: 몸 메시 P·N·T + 뼈 웨이트 J·W + 뼈 자세 프레임). 자세하게: TRIS=80000 node rig.js <id>
// 쓰는 것: art/creatures/export/<name>_<id>.glb — 몸 메시 하나(무난한 회색 재질, 텍스처·흰 선·윤곽 없음) + 스킨 1개 + glTF 애니메이션 클립(idle, walk, chase, attack)
// 프레임 { qx,qy,qz,qw, tx,ty,tz } = 게임의 Bone.Transform(쉬는 자리 c 기준 회전 + 이동) → 노드 rotation = q, translation = c + t
// 시간: 게임(RigAnim.luau)과 같게 — 한 걸음 주기 = stride*2 / 속도(c<n>h.luau 의 WanderSpeed·ChaseSpeed), 덮침은 0.35초에 자세로 들어간다(접근 비율 6)
const fs = require('fs'), path = require('path'), os = require('os');
const { writeGLB } = require('./glb.js');
const OUT = path.join(__dirname, 'out/export'); // (중간 결과: 회색 몸 + 뼈 + 클립. 최종은 realify.py 가 art/creatures/export/ 에)
// 괴물별 속도(스터드/초, 게임 설정 그대로) · 걸음 폭
const SPEED = {
  k7h4: { stride: 3, walk: 7, chase: 17.1 }, // c7h.luau WanderSpeed 7, ChaseSpeed 17.1
  k10h1: { stride: 3, walk: 3.5 * 2 / 1.4, chase: 9 }, // c10h.luau 배회 중 걷는 순간 속도 = WanderSpeed*2/1.4, ChaseSpeed 9
};

function readGLB(file) {
  const b = fs.readFileSync(file);
  const jl = b.readUInt32LE(12); const json = JSON.parse(b.slice(20, 20 + jl).toString());
  const bo = 20 + jl; const bl = b.readUInt32LE(bo); const bin = b.slice(bo + 8, bo + 8 + bl);
  return { json, bin };
}
function writeGLBRaw(file, json, bin) {
  let j = Buffer.from(JSON.stringify(json)); j = Buffer.concat([j, Buffer.alloc((4 - j.length % 4) % 4, 0x20)]);
  const bb = Buffer.concat([bin, Buffer.alloc((4 - bin.length % 4) % 4)]);
  const head = Buffer.alloc(12); head.writeUInt32LE(0x46546C67, 0); head.writeUInt32LE(2, 4); head.writeUInt32LE(12 + 8 + j.length + 8 + bb.length, 8);
  const ch = (n, t) => { const h = Buffer.alloc(8); h.writeUInt32LE(n, 0); h.writeUInt32LE(t, 4); return h; };
  fs.writeFileSync(file, Buffer.concat([head, ch(j.length, 0x4E4F534A), j, ch(bb.length, 0x004E4942), bb]));
}

function build(id, name) {
  const A = JSON.parse(fs.readFileSync(path.join(__dirname, 'out/mesh', id + '_anim.json'), 'utf8'));
  const tmp = path.join(os.tmpdir(), 'exp_' + id + '.glb');
  writeGLB(tmp, { name: 'Body', P: new Float32Array(A.P), N: new Float32Array(A.N), T: new Uint32Array(A.T), J: new Uint16Array(A.J), W: new Float32Array(A.W), color: [0.5, 0.5, 0.52, 1] }, A.bones);
  const { json, bin } = readGLB(tmp); fs.unlinkSync(tmp);
  json.materials[0].pbrMetallicRoughness.roughnessFactor = 0.75;
  const S = SPEED[id]; if (!S) throw new Error('SPEED 없음: ' + id);
  const nB = A.bones.length;
  const boneNode = A.bones.map(b => json.nodes.findIndex(n => n.name === b.name));
  if (boneNode.some(i => i < 0)) throw new Error(id + ': 뼈 이름이 glb 와 안 맞음');
  const rest = boneNode.map(i => json.nodes[i].translation);


  const bufs = [bin]; let off = bin.length; const pad4 = () => { const p = (4 - off % 4) % 4; if (p) { bufs.push(Buffer.alloc(p)); off += p; } };
  pad4();
  const acc = (arr, type, extra = {}) => { const b = Buffer.from(arr.buffer, arr.byteOffset, arr.byteLength); json.bufferViews.push({ buffer: 0, byteOffset: off, byteLength: b.length }); bufs.push(b); off += b.length; pad4(); json.accessors.push({ bufferView: json.bufferViews.length - 1, componentType: 5126, count: arr.length / ({ SCALAR: 1, VEC3: 3, VEC4: 4 })[type], type, ...extra }); return json.accessors.length - 1; };

  // keys = [[시간, 프레임(뼈마다 7개)] ...]
  const clip = (cname, keys) => {
    const times = new Float32Array(keys.map(k => k[0]));
    const tA = acc(times, 'SCALAR', { min: [times[0]], max: [times[times.length - 1]] });
    const samplers = [], channels = [];
    for (let b = 0; b < nB; b++) {
      const R = new Float32Array(keys.length * 4), Tr = new Float32Array(keys.length * 3);
      let prev = null; let moves = false;
      keys.forEach(([, F], k) => {
        let q = F[b].slice(0, 4); const l = Math.hypot(...q) || 1; q = q.map(x => x / l);
        if (prev && q[0] * prev[0] + q[1] * prev[1] + q[2] * prev[2] + q[3] * prev[3] < 0) q = q.map(x => -x); // (짧은 쪽으로 돌게)
        prev = q; R.set(q, k * 4);
        Tr.set([rest[b][0] + F[b][4], rest[b][1] + F[b][5], rest[b][2] + F[b][6]], k * 3);
        if (Math.abs(q[3]) < 0.99999 || Math.hypot(F[b][4], F[b][5], F[b][6]) > 1e-4) moves = true;
      });
      // 모든 뼈에 채널을 단다(클립을 바꿀 때 앞 클립 자세가 남지 않게)
      samplers.push({ input: tA, output: acc(R, 'VEC4'), interpolation: 'LINEAR' }); channels.push({ sampler: samplers.length - 1, target: { node: boneNode[b], path: 'rotation' } });
      samplers.push({ input: tA, output: acc(Tr, 'VEC3'), interpolation: 'LINEAR' }); channels.push({ sampler: samplers.length - 1, target: { node: boneNode[b], path: 'translation' } });
    }
    (json.animations = json.animations || []).push({ name: cname, samplers, channels });
    return times[times.length - 1];
  };
  const cycle = (frames, period) => { const n = frames.length; return [...frames.map((F, i) => [i * period / n, F]), [period, frames[0]]]; };
  const W0 = A.walk[0];
  const info = {};
  info.idle = clip('idle', [[0, W0], [2, W0]]); // (게임: 멈추면 걷기 첫 자세로 선다)
  info.walk = clip('walk', cycle(A.walk, S.stride * 2 / S.walk));
  info.chase = clip('chase', cycle(A.chase, S.stride * 2 / S.chase));
  info.attack = clip('attack', [[0, A.chase[0]], [0.35, A.attack], [0.8, A.attack], [1.2, A.chase[0]]]);
  json.buffers = [{ byteLength: off }];
  json.asset.generator = 'echophobia rig.js + export-anim.js';
  fs.mkdirSync(OUT, { recursive: true });
  const file = path.join(OUT, `${name}_${id}.glb`);
  writeGLBRaw(file, json, Buffer.concat(bufs));
  console.log(file, (fs.statSync(file).size / 1e6).toFixed(1) + 'MB', JSON.stringify(info));
}

for (const a of process.argv.slice(2)) { const [id, name] = a.split(':'); build(id, name || id); }
