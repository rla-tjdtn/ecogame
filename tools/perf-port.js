// tools/perf-build.sh 가 부른다: 복사한 default.project.json 에 ServerStorage 속성 TestPort 를 넣는다
// (그 플레이스를 연 Studio 의 SonarTestRunner 플러그인이 그 포트로 테스트를 받는다 → Studio 여러 창을 동시에)
//   node tools/perf-port.js <project.json> <port>
const fs = require("fs");
const [file, port] = process.argv.slice(2);
const j = JSON.parse(fs.readFileSync(file, "utf8"));
const ss = j.tree.ServerStorage || {};
ss["$className"] = "ServerStorage";
ss["$attributes"] = Object.assign(ss["$attributes"] || {}, { TestPort: { Float64: Number(port) } });
j.tree.ServerStorage = ss;
fs.writeFileSync(file, JSON.stringify(j, null, 1));
