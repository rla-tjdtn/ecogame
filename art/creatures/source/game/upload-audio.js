// 챕터 소리 묶음(out/sounds/pack_ch<N>.ogg)을 로블록스 계정에 오디오 에셋으로 올린다 → sounds_map.json packs[N].assetId
const fs = require('fs'), path = require('path'), os = require('os');
const KEY = fs.readFileSync(path.join(os.homedir(), '.roblox_key.txt'), 'utf8').trim();
const USER_ID = '11895954688';
const MAPF = path.join(__dirname, 'sounds_map.json'); const MAP = JSON.parse(fs.readFileSync(MAPF, 'utf8'));
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  for (const ch of (process.argv.slice(2).length ? process.argv.slice(2) : Object.keys(MAP.packs))) {
    const P = MAP.packs[ch]; if (P.assetId && !process.env.FORCE) { console.log('ch' + ch, 'already', P.assetId); continue; }
    const form = new FormData();
    form.append('request', JSON.stringify({ assetType: 'Audio', displayName: `Echophobia creatures ch${ch}`, description: 'Echophobia creature voices (Freesound CC0, see sounds_map.json)', creationContext: { creator: { userId: USER_ID } } }));
    form.append('fileContent', new Blob([fs.readFileSync(path.join(__dirname, 'out', 'sounds', P.file))], { type: 'audio/ogg' }), P.file);
    const r = await fetch('https://apis.roblox.com/assets/v1/assets', { method: 'POST', headers: { 'x-api-key': KEY }, body: form });
    const j = await r.json().catch(() => ({}));
    if (!r.ok) { console.log('FAIL ch' + ch, r.status, JSON.stringify(j).slice(0, 300)); continue; }
    let id = null;
    for (let k = 0; k < 60 && !id; k++) { await sleep(3000); const o = await (await fetch('https://apis.roblox.com/assets/v1/' + j.path, { headers: { 'x-api-key': KEY } })).json(); if (o.done) { id = o.response && o.response.assetId; if (!id) console.log('FAIL ch' + ch, JSON.stringify(o).slice(0, 300)); break; } }
    if (id) { P.assetId = Number(id); fs.writeFileSync(MAPF, JSON.stringify(MAP, null, 1)); console.log('ch' + ch, 'audio', id); }
  }
})();
