// 시안 4 설명 + 시트 카메라·포즈: 팀별 파일 meta4_<장>.js 를 합친다
const fs = require('fs'), path = require('path'); const M = {};
for (const f of fs.readdirSync(__dirname)) if (/^meta4_\d+\.js$/.test(f)) Object.assign(M, require(path.join(__dirname, f)));
module.exports = M;
