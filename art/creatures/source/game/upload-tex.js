// 시안 그림 텍스처(out/tex/<id>_t*.png)를 이미지 에셋으로 올린다(Open Cloud Image 형식 = 바로 이미지 번호).
//   node upload-tex.js k6h1 ...  → out/tex/<id>_ids.json { "Tex0": 이미지번호, ... }
// 키 = C:\Users\User\.roblox_key.txt (읽기만)
const fs = require('fs'), path = require('path'), os = require('os');
const KEY = fs.readFileSync(path.join(os.homedir(), '.roblox_key.txt'), 'utf8').trim();
const USER_ID = '11895954688';
const sleep = ms => new Promise(r => setTimeout(r, ms));
async function up(file, name) {
  for (let tryN = 0; tryN < 4; tryN++) {
    const form = new FormData();
    form.append('request', JSON.stringify({ assetType: 'Image', displayName: name.slice(0, 50), description: 'Echophobia creature line texture', creationContext: { creator: { userId: USER_ID } } }));
    form.append('fileContent', new Blob([fs.readFileSync(file)], { type: 'image/png' }), path.basename(file));
    const r = await fetch('https://apis.roblox.com/assets/v1/assets', { method: 'POST', headers: { 'x-api-key': KEY }, body: form });
    const j = await r.json().catch(() => ({}));
    if (r.status === 429 || r.status >= 500) { await sleep(5000 * (tryN + 1)); continue; }
    if (!r.ok) throw new Error(name + ' ' + r.status + ' ' + JSON.stringify(j).slice(0, 300));
    const op = j.path || ('operations/' + j.operationId);
    for (let k = 0; k < 60; k++) {
      await sleep(2000);
      const o = await (await fetch('https://apis.roblox.com/assets/v1/' + op, { headers: { 'x-api-key': KEY } })).json();
      if (o.done) { if (o.response && o.response.assetId) return Number(o.response.assetId); throw new Error(name + ' op ' + JSON.stringify(o).slice(0, 300)); }
    }
    throw new Error(name + ' timeout');
  }
  throw new Error(name + ' rate limited');
}
module.exports = { up };
if (require.main === module) (async () => {
  for (const id of process.argv.slice(2)) {
    const info = JSON.parse(fs.readFileSync(path.join(__dirname, 'out/tex', id + '.json'), 'utf8'));
    const idsF = path.join(__dirname, 'out/tex', id + '_ids.json'), ids = {};
    for (const p of info.parts) {
      const file = path.join(__dirname, 'out/tex', `${id}_t${p.part.replace(/^Tex/, '')}.png`);
      ids[p.part] = await up(file, `Echophobia ${id} ${p.part}`);
    }
    fs.writeFileSync(idsF, JSON.stringify(ids, null, 1));
    console.log(id, 'textures', Object.keys(ids).length);
  }
})().catch(e => { console.log('FAIL', e.message); process.exit(1); });
