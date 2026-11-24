// tools/perf-build.sh 가 부른다: 복사한 default.project.json 에 ServerStorage 속성 TestPort 를 넣는다
// (그 플레이스를 연 Studio 의 SonarTestRunner 플러그인이 그 포트로 테스트를 받는다 → Studio 여러 창을 동시에)
//   node tools/perf-port.js <project.json> <port>
const fs = require("fs");
const [file, port] = process.argv.slice(2);
const j = JSON.parse(fs.readFileSync(file, "utf8"));
const ss = j.tree.ServerStorage || {};
ss["$className"] = "ServerStorage";
const attrs = { TestPort: { Float64: Number(port) } };
// env PROPMESH_OFF=1: 소품 메시 끄기(PropMesh.dress 가 아무것도 안 함 → 예전 부품 그대로) — 전/후 비교용
if (process.env.PROPMESH_OFF) attrs.PropMeshOff = { Bool: true };
ss["$attributes"] = Object.assign(ss["$attributes"] || {}, attrs);
j.tree.ServerStorage = ss;
fs.writeFileSync(file, JSON.stringify(j, null, 1));
