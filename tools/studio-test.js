// Runs an automated play test inside the open Roblox Studio and prints the result.
//
//   node tools/studio-test.js [testName] [timeoutSeconds]
//   (env PLAYERS=4: a local server with that many clients; WATCH_SECONDS: how long the "watch" test plays)
//
// Installs tools/SonarTestRunner.plugin.lua into Studio's local plugins folder (once), serves one test request on
// http://localhost:34902, waits for the plugin to run it (a real Play session; src/server/TestHarness.server.luau
// plays the scenario) and prints the JSON it reports. Exit code 1 if any check failed or the test did not finish.

const http = require("http");
const fs = require("fs");
const path = require("path");
const os = require("os");

const name = process.argv[2] || "core";
const timeout = Number(process.argv[3] || 240) * 1000;

const pluginSrc = path.join(__dirname, "SonarTestRunner.plugin.lua");
const pluginDir = path.join(process.env.LOCALAPPDATA || path.join(os.homedir(), "AppData", "Local"), "Roblox", "Plugins");
const pluginDst = path.join(pluginDir, "SonarTestRunner.lua");
fs.mkdirSync(pluginDir, { recursive: true });
if (!fs.existsSync(pluginDst) || fs.readFileSync(pluginDst, "utf8") !== fs.readFileSync(pluginSrc, "utf8")) {
	fs.copyFileSync(pluginSrc, pluginDst);
	console.log("installed plugin -> " + pluginDst + " (restart Studio if it was open before)");
}

const players = Number(process.env.PLAYERS || 1);
const job = { id: String(Date.now()), players, args: { Test: name, Seconds: Number(process.env.WATCH_SECONDS || 150), Players: players } };
let handed = false;
const server = http.createServer((req, res) => {
	let body = "";
	req.on("data", (c) => (body += c));
	req.on("end", () => {
		if (req.url === "/next") {
			res.end(handed ? "" : JSON.stringify(job));
			if (!handed) console.log(`test "${name}" handed to Studio, playing...`);
			handed = true;
		} else if (req.url === "/started") {
			res.end("ok");
		} else if (req.url === "/result") {
			res.end("ok");
			const data = JSON.parse(body || "{}");
			console.log(JSON.stringify(data.result, null, 1));
			const checks = (data.result && data.result.checks) || [];
			const failed = !data.ok || checks.some((c) => !c.ok) || !(data.result && data.result.finished);
			server.close();
			process.exit(failed ? 1 : 0);
		} else {
			res.statusCode = 404;
			res.end();
		}
	});
});
server.listen(34902, "127.0.0.1", () => console.log("waiting for Studio (plugin polls every 2 s)..."));
setTimeout(() => {
	console.log(handed ? "TIMEOUT: Studio took the test but did not report back" : "TIMEOUT: Studio never asked for the test (plugin not loaded, or HTTP not allowed for it)");
	process.exit(2);
}, timeout);
