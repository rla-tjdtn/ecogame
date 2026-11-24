// 텍스처 이미지 번호(out/tex/<id>_ids.json) → Rojo 모델 src/shared/CreatureTex/<id>.model.json
// (Tex 부품 이름마다 SurfaceAppearance: 색 = 발광 마스크 = 시안 그림. 게임(Baked.luau)이 같은 이름 부품에 복제해 붙인다)
//   node gen-tex.js k6h1 ...
const fs = require('fs'), path = require('path');
const OUTD = path.join(__dirname, '..', '..', '..', '..', 'src', 'shared', 'CreatureTex'); fs.mkdirSync(OUTD, { recursive: true });
const ES = +(process.env.ES || 1.5);
for (const id of process.argv.slice(2)) {
  const ids = JSON.parse(fs.readFileSync(path.join(__dirname, 'out/tex', id + '_ids.json'), 'utf8'));
  const children = Object.entries(ids).map(([name, img]) => ({ name, className: 'SurfaceAppearance', properties: { ColorMap: 'rbxassetid://' + img, EmissiveMaskContent: 'rbxassetid://' + img, EmissiveStrength: ES, EmissiveTint: [1, 1, 1] } }));
  fs.writeFileSync(path.join(OUTD, id + '.model.json'), JSON.stringify({ className: 'Folder', children }, null, 1) + '\n');
  console.log(id, 'surface appearances', children.length);
}
