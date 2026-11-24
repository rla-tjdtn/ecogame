// 모든 소품 메시 모델: models/<묶음>.js 가 { "<묶음>.<이름>": (m) => { ... } } 를 내보낸다(m = lib/model.js 의 Model).
// (한 파일에 오류가 있어도 다른 묶음은 계속 쓸 수 있게 파일마다 따로 불러온다)
const fs = require('fs'), path = require('path');
const models = {};
for (const f of fs.readdirSync(__dirname)) {
  if (!f.endsWith('.js') || f === 'index.js' || f.startsWith('_')) continue;
  let mod;
  try { mod = require(path.join(__dirname, f)); } catch (e) { console.warn('[models] ' + f + ' failed to load: ' + String(e.message).split('\n')[0]); continue; }
  for (const [k, v] of Object.entries(mod)) { if (models[k]) throw new Error('duplicate model ' + k); models[k] = v; }
}
module.exports = { models };
