// Prints script errors/warnings (with stacks) from the newest Roblox Studio log: node tools/studio-errors.js [minutes]
const fs = require("fs"), path = require("path");
const dir = path.join(process.env.LOCALAPPDATA, "Roblox", "logs");
const mins = Number(process.argv[2] || 15);
const files = fs.readdirSync(dir).filter((f) => f.includes("_Studio_")).map((f) => ({ f, t: fs.statSync(path.join(dir, f)).mtimeMs })).sort((a, b) => b.t - a.t).slice(0, 3);
const since = Date.now() - mins * 60000;
for (const { f } of files) {
	for (const line of fs.readFileSync(path.join(dir, f), "utf8").split(/\r?\n/)) {
		if (!/CreatorError|CreatorWarning|CreatorOutput\] Info: Script/.test(line)) continue;
		if (/StyleRule|Redundant/.test(line)) continue;
		const t = Date.parse(line.slice(0, 24));
		if (t < since) continue;
		console.log(line.slice(11, 19), line.replace(/^.*?\[FLog::Creator\w+\] /, "").slice(0, 300));
	}
}
