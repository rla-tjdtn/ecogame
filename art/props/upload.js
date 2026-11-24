// 소품 메시 glb(out/glb/<묶음>.glb)를 계정에 모델 에셋으로 올리고(Open Cloud Assets API), 번호를 assets.json 에 적은 뒤
// 데이터 모듈(src/shared/PropMeshData/<묶음>.luau)을 다시 만든다. 내용(hash)이 같으면 다시 올리지 않는다.
//   node art/props/upload.js [묶음 ...]   (키: 사용자가 만든 C:\Users\User\.roblox_key.txt — 읽기만, 출력·저장 금지)
const fs = require('fs'), path = require('path'), os = require('os');
const { exportGroup } = require('./export.js');
const { models } = require('./models/index.js');
const KEY = fs.readFileSync(path.join(os.homedir(), '.roblox_key.txt'), 'utf8').trim();
const USER_ID = '11895954688'; // 게임 에셋을 올리는 계정(괴물 메시·소리와 같은 계정)
const ASSETS = path.join(__dirname, 'assets.json');
const sleep = ms => new Promise(r => setTimeout(r, ms));

async function upload(group) {
  const file = path.join(__dirname, 'out', 'glb', group + '.glb');
  const form = new FormData();
  form.append('request', JSON.stringify({ assetType: 'Model', displayName: `Echophobia props ${group}`.slice(0, 50), description: 'Echophobia map prop meshes (procedurally modeled, own work)', creationContext: { creator: { userId: USER_ID } } }));
  form.append('fileContent', new Blob([fs.readFileSync(file)], { type: 'model/gltf-binary' }), group + '.glb');
  const r = await fetch('https://apis.roblox.com/assets/v1/assets', { method: 'POST', headers: { 'x-api-key': KEY }, body: form });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(group + ' upload ' + r.status + ' ' + JSON.stringify(j).slice(0, 300));
  const op = j.path || ('operations/' + j.operationId);
  for (let k = 0; k < 100; k++) {
    await sleep(3000);
    const o = await (await fetch('https://apis.roblox.com/assets/v1/' + op, { headers: { 'x-api-key': KEY } })).json();
    if (o.done) { if (o.response && o.response.assetId) return Number(o.response.assetId); throw new Error(group + ' op ' + JSON.stringify(o).slice(0, 300)); }
  }
  throw new Error(group + ' timeout');
}
(async () => {
  let groups = process.argv.slice(2);
  if (!groups.length) groups = [...new Set(Object.keys(models).map(k => k.split('.')[0]))];
  for (const g of groups) {
    const assets = fs.existsSync(ASSETS) ? JSON.parse(fs.readFileSync(ASSETS, 'utf8')) : {};
    const ex = exportGroup(g, assets); if (!ex) continue;
    if (assets[g] && assets[g].hash === ex.hash && assets[g].id && !process.env.FORCE) { console.log(g, 'unchanged', assets[g].id); continue; }
    try {
      const id = await upload(g);
      const cur = fs.existsSync(ASSETS) ? JSON.parse(fs.readFileSync(ASSETS, 'utf8')) : {};
      cur[g] = { id, hash: ex.hash, at: new Date().toISOString() };
      fs.writeFileSync(ASSETS, JSON.stringify(cur, null, 1));
      exportGroup(g, cur);
      console.log(g, 'asset', id);
    } catch (e) { console.log('FAIL', e.message); }
  }
})();
