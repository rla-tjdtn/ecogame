// 뼈 메시(out/mesh/<id>.glb)를 로블록스 계정에 모델 에셋으로 올린다(Open Cloud Assets API).
//   node upload.js k4h1 ...   (키 = 사용자가 직접 만든 C:\Users\User\.roblox_key.txt, 스크립트는 읽기만 한다)
// 결과 에셋 번호는 meshids.json 에 적고, node rig.js 를 다시 돌리지 않아도 되게 src/shared/CreatureRigs/<id>.luau 의 meshId 도 고친다.
const fs = require('fs'), path = require('path'), os = require('os');
const KEY = fs.readFileSync(path.join(os.homedir(), '.roblox_key.txt'), 'utf8').trim();
const USER_ID = '11895954688'; // 게임 소리 에셋을 올린 계정(platypus4795)
const IDS_FILE = path.join(__dirname, 'meshids.json');
const LUAD = path.join(__dirname, '..', '..', '..', '..', 'src', 'shared', 'CreatureRigs');
const { CFG } = require('./bake.js');
const sleep = ms => new Promise(r => setTimeout(r, ms));

async function upload(id) {
  const file = path.join(__dirname, 'out', 'mesh', id + '.glb');
  const form = new FormData();
  form.append('request', JSON.stringify({ assetType: 'Model', displayName: `Echophobia ${id} ${CFG[id] ? CFG[id].name : ''}`.slice(0, 50), description: 'Echophobia chapter creature (skinned mesh)', creationContext: { creator: { userId: USER_ID } } }));
  form.append('fileContent', new Blob([fs.readFileSync(file)], { type: 'model/gltf-binary' }), id + '.glb');
  const r = await fetch('https://apis.roblox.com/assets/v1/assets', { method: 'POST', headers: { 'x-api-key': KEY }, body: form });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(id + ' upload ' + r.status + ' ' + JSON.stringify(j).slice(0, 300));
  const op = j.path || ('operations/' + j.operationId);
  for (let k = 0; k < 60; k++) {
    await sleep(3000);
    const o = await (await fetch('https://apis.roblox.com/assets/v1/' + op, { headers: { 'x-api-key': KEY } })).json();
    if (o.done) { if (o.response && o.response.assetId) return o.response.assetId; throw new Error(id + ' op ' + JSON.stringify(o).slice(0, 300)); }
  }
  throw new Error(id + ' timeout');
}

(async () => {
  const ids = JSON.parse(fs.existsSync(IDS_FILE) ? fs.readFileSync(IDS_FILE, 'utf8') : '{}');
  for (const id of process.argv.slice(2)) {
    if (ids[id] && !process.env.FORCE) { console.log(id, 'already', ids[id]); continue; }
    try {
      const a = await upload(id);
      ids[id] = Number(a); fs.writeFileSync(IDS_FILE, JSON.stringify(ids, null, 1));
      const lf = path.join(LUAD, id + '.luau');
      if (fs.existsSync(lf)) fs.writeFileSync(lf, fs.readFileSync(lf, 'utf8').replace(/meshId = \d+,/, `meshId = ${a},`));
      console.log(id, 'asset', a);
    } catch (e) { console.log('FAIL', e.message); }
  }
})();
