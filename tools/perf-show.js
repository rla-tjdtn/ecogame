// 측정 결과(tools/studio-test.js 출력 파일)를 마크다운 표로.
//   node tools/perf-show.js <result.txt> [before.txt]   — before 를 주면 같은 단계끼리 전/후 비교
const fs = require("fs");
function load(f) {
	const t = fs.readFileSync(f, "utf8");
	const i = t.indexOf("\n{");
	if (i < 0) throw new Error(f + ": no JSON (" + t.slice(0, 200).replace(/\n/g, " ") + ")");
	return JSON.parse(t.slice(i + 1));
}
const md = (rows, keys) => {
	if (!rows.length) return "";
	const head = "| " + keys.join(" | ") + " |\n|" + keys.map(() => "---").join("|") + "|\n";
	return head + rows.map((r) => "| " + keys.map((k) => (r[k] === undefined || r[k] === null ? "" : r[k])).join(" | ") + " |").join("\n") + "\n";
};
const j = load(process.argv[2]);
const b = process.argv[3] ? load(process.argv[3]) : null;
const fails = j.checks.filter((c) => !c.ok);
console.log(`checks: ${j.checks.length - fails.length}/${j.checks.length} pass, finished=${j.finished}, errors=${j.errors.length}`);
for (const c of fails) console.log("- FAIL " + c.name + (c.info ? " — " + c.info : ""));
const errs = [...new Set(j.errors.map((e) => e.slice(0, 140)))];
for (const e of errs.slice(0, 8)) console.log("- ERR " + e);
if (j.info.stress) {
	const K = ["phase", "fired", "luaAvg", "luaP95", "luaP99", "luaWorst", "pulseAvg", "pulseMax", "startAvg", "startMax", "maxActive", "cut", "linesActive", "created", "dropped", "stolen", "soundsPeak"];
	const K2 = ["phase", "fps", "low1", "avgMs", "p95", "p99", "worst", "memMb", "instances", "srvFrame", "srvWorst", "srvHeartbeatMs", "emitMs", "physMs", "physMax", "contacts"];
	if (b && b.info.stress) {
		const bm = Object.fromEntries(b.info.stress.map((r) => [r.phase, r]));
		const C = ["luaAvg", "luaP99", "luaWorst", "pulseAvg", "pulseMax", "dropped", "srvFrame"];
		const rows = j.info.stress.map((r) => {
			const o = { phase: r.phase };
			for (const k of C) o[k] = `${bm[r.phase] ? bm[r.phase][k] : "?"} → ${r[k]}`;
			return o;
		});
		console.log("\n" + md(rows, ["phase", ...C]));
	}
	console.log("\n" + md(j.info.stress, K));
	console.log(md(j.info.stress, K2));
	const sysNames = [...new Set(j.info.stress.flatMap((r) => Object.keys(r.sys)))].sort();
	const srow = j.info.stress.map((r) => {
		const o = { phase: r.phase };
		for (const n of sysNames) o[n] = r.sys[n] ? r.sys[n].split(",")[0].replace(" ms/s", "") : "";
		return o;
	});
	console.log("시스템별 ms/초:\n\n" + md(srow, ["phase", ...sysNames]));
	console.log("spot " + JSON.stringify(j.info.spot) + " animateMsPerFrame=" + j.info.animateMsPerFrame);
}
if (j.info.census) console.log("\n" + md(j.info.census, ["stage", "parts", "segs", "viewParts", "cyl", "mesh", "collide", "decorQuery", "touch", "shadow", "unanchored", "inst", "monsters", "monsterParts", "serverBuildMs", "clientBuildSec", "clientBuildCpu", "clientInst", "serverInst", "memMb", "serverMemMb", "small", "smallCollide", "physMs", "primitives", "contacts", "wsOutsideStage", "topNames"]));
if (j.info.soak) {
	console.log("\n" + md(j.info.soak, Object.keys(j.info.soak[0] || {})));
	console.log("end " + JSON.stringify(j.info.soakEnd));
}
if (j.info.pbench) console.log("\n" + md(j.info.pbench, Object.keys(j.info.pbench[0] || {})));
const other = Object.keys(j.info).filter((k) => !["stress", "spot", "animateMsPerFrame", "census", "soak", "soakEnd", "pbench"].includes(k));
if (other.length) console.log("\ninfo: " + JSON.stringify(Object.fromEntries(other.map((k) => [k, j.info[k]]))).slice(0, 3000));
