// 스테이지 지도 그림(게임 지도 Q 스타일: 검은 바탕, 벽 경계 흰 선, 출구 빨간 네모, 열쇠 후보 상자 노란 마름모)을 PNG 로 만든다.
//   node tools/map-image.js 6 [out.png]     (SVG 를 만들고 Edge 헤드리스로 스크린샷)
const fs = require("fs"), path = require("path"), cp = require("child_process");
const id = process.argv[2] || "6";
const out = path.resolve(process.argv[3] || `stage${id}-map.png`);
const src = fs.readFileSync(path.join(__dirname, "..", "src", "server", "Stages", `Stage${id}.luau`), "utf8");
const rows = [...src.matchAll(/^\s*"([^"]+)",\s*$/gm)].map((m) => m[1]);
const T = 20, W = rows[0].length, H = rows.length;
const wall = (i, j) => (i < 0 || j < 0 || i >= W || j >= H ? true : rows[j][i] === "#");
let svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W * T}" height="${H * T}" style="background:#000"><rect width="100%" height="100%" fill="#000"/>`;
// 2층 구역(UpperRects)은 남색 바탕 + "2F", 계단 칸은 초록
const upper = [...((src.match(/UpperRects = \{(.*)\},/) || ["", ""])[1].matchAll(/\{\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)\s*\}/g))].map((m) => m.slice(1, 5).map((v) => +v - 1));
for (const [a, b, c, d] of upper) svg += `<rect x="${a * T}" y="${b * T}" width="${(c - a + 1) * T}" height="${(d - b + 1) * T}" fill="#0d2148"/>`;
for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) if (rows[j][i] === "1" || rows[j][i] === "2") svg += `<rect x="${i * T + 2}" y="${j * T + 2}" width="${T - 4}" height="${T - 4}" fill="${rows[j][i] === "1" ? "#1c7c3c" : "#2fbf5f"}"/>`;
const line = (x1, y1, x2, y2) => (svg += `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="#fff" stroke-width="2"/>`);
for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) {
	if (!wall(i, j)) continue;
	if (!wall(i + 1, j)) line((i + 1) * T, j * T, (i + 1) * T, (j + 1) * T);
	if (!wall(i - 1, j)) line(i * T, j * T, i * T, (j + 1) * T);
	if (!wall(i, j + 1)) line(i * T, (j + 1) * T, (i + 1) * T, (j + 1) * T);
	if (!wall(i, j - 1)) line(i * T, j * T, (i + 1) * T, j * T);
}
for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) {
	const c = rows[j][i], x = i * T + T / 2, y = j * T + T / 2;
	if (c === "E") svg += `<rect x="${i * T + 3}" y="${j * T + 3}" width="${T - 6}" height="${T - 6}" fill="#e02020"/>`;
	else if (c === "Z") svg += `<polygon points="${x},${y - 7} ${x + 7},${y} ${x},${y + 7} ${x - 7},${y}" fill="#ffd400"/>`;
	else if (c === "S") svg += `<circle cx="${x}" cy="${y}" r="4" fill="#4cf"/>`;
	else if (c === "D" || c === "A") svg += `<circle cx="${x}" cy="${y}" r="2" fill="#888"/>`;
}
for (const [a, b, c, d] of upper) svg += `<text x="${(a + c + 1) * T / 2}" y="${(b + d + 1) * T / 2}" fill="#4a6fb0" font-size="${T * 3}" font-family="sans-serif" font-weight="bold" text-anchor="middle" dominant-baseline="middle" opacity="0.5">2F</text>`;
svg += "</svg>";
const svgPath = out.replace(/\.png$/, ".svg");
fs.writeFileSync(svgPath, svg);
const edge = ["C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe", "C:/Program Files/Microsoft/Edge/Application/msedge.exe"].find(fs.existsSync);
cp.execFileSync(edge, ["--headless", "--disable-gpu", `--screenshot=${out}`, `--window-size=${W * T},${H * T}`, "file:///" + svgPath.split("\\").join("/")], { stdio: "ignore" });
console.log(out);
