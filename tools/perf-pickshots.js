// propshot 캡처 고르기: 시험 결과의 "[SHOT] ch<N> <after|before> <key>" 로그 줄(하네스 시간)을 실제 시각으로 바꿔
// 그 장면 고정 시간(약 8초) 가운데 캡처를 propshot-ch<N>-<after|before>-<k>.png 로 복사한다.
//   node tools/perf-pickshots.js <result.txt> <rawDir> <outDir> <resultEpochMs>
//   rawDir 의 파일 이름 = raw-<epochMs>.png (찍은 시각)
const fs = require("fs");
const path = require("path");
const [resFile, rawDir, outDir, resultEpoch] = process.argv.slice(2);
const t = fs.readFileSync(resFile, "utf8");
const j = JSON.parse(t.slice(t.indexOf("\n{") + 1));
const log = j.log || [];
const time = (l) => parseFloat(l.trim().split(/\s+/)[0]);
const end = time(log[log.length - 1]); // "done" 줄 = 결과가 도착한 시각
const raws = fs.readdirSync(rawDir).filter((f) => /^raw-\d+\.png$/.test(f)).map((f) => ({ f, ms: Number(f.slice(4, -4)) }));
const count = {};
const picked = [];
for (const l of log) {
	const m = l.match(/\[SHOT\] (ch\d+) (after|before) (\S+)/);
	if (!m) continue;
	const um = l.match(/unixms=(\d+)/); // (있으면 실제 시각을 그대로 쓴다)
	// unixms 가 있으면 그 순간(시험이 장면 가운데에서 남긴다), 없으면 하네스 시간으로 어림한 고정 8초의 가운데
	const want = um ? Number(um[1]) : Number(resultEpoch) - (end - time(l)) * 1000 + 4000;
	let best = null;
	for (const r of raws) if (!best || Math.abs(r.ms - want) < Math.abs(best.ms - want)) best = r;
	if (!best) continue;
	const k = (count[m[1] + m[2]] = (count[m[1] + m[2]] || 0) + 1);
	const out = `propshot-${m[1]}-${m[2]}-${k}.png`;
	fs.copyFileSync(path.join(rawDir, best.f), path.join(outDir, out));
	picked.push(`${out} ← ${m[3]} (차이 ${((best.ms - want) / 1000).toFixed(1)}초)`);
}
console.log(picked.join("\n"));
