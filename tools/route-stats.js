// (예전 도구) 길 갈래·목 검사는 tools/level-graph.js 로 옮겼다 — 겹쳐 쌓은 2층(Rows2)과 괴물 막기 검사까지 한다.
//   node tools/route-stats.js [N]   →   node tools/level-graph.js [N] 와 같다
require("child_process").execFileSync(process.execPath, [require("path").join(__dirname, "level-graph.js"), ...process.argv.slice(2)], { stdio: "inherit" });
