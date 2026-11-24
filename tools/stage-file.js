// 스테이지 파일(src/server/Stages/StageN.luau) 읽기: 도구들이 같이 쓴다.
//   rows   1층 격자(Rows)
//   rows2  겹쳐 쌓은 2층 격자(Rows2, 1층과 같은 크기) 또는 null
//   upper  (옛 방식) 같은 격자 안 2층 구역 UpperRects [i0, j0, i1, j1] (0부터)
//   pits   아래층 높이 문자, walk 괴물 배회 소품 문자, props 스테이지 소품 문자
const fs = require("fs");
const path = require("path");
const DIR = process.env.STAGES_DIR || path.join(__dirname, "..", "src", "server", "Stages");

function block(src, name) {
	const m = src.match(new RegExp(`\\n\\t${name} = \\{[^\\n]*\\n([\\s\\S]*?)\\n\\t\\},`));
	return m ? [...m[1].matchAll(/^\s*"([^"]+)",\s*$/gm)].map((x) => x[1]) : null;
}

function parse(src) {
	src = src.replace(/\r\n/g, "\n");
	const rows = block(src, "Rows");
	const rows2 = block(src, "Rows2");
	const list = (re) => ((src.match(re) || ["", ""])[1].match(/(\w) = /g) || []).map((x) => x[0]);
	const pitExtra = ((src.match(/PitTiles = \{([^}]*)\}/) || ["", ""])[1].match(/(\w) = true/g) || []).map((x) => x[0]);
	const walk = ((src.match(/Walkable = \{([^}]*)\}/) || ["", ""])[1].match(/(\w) = true/g) || []).map((x) => x[0]);
	const upper = [...((src.match(/UpperRects = \{(.*)\},/) || ["", ""])[1].matchAll(/\{\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)\s*\}/g))].map((m) => m.slice(1, 5).map((v) => +v - 1));
	// Walkable 에서 false 로 적은 문자(구덩이 높이에 놓인 막는 소품 등)는 막힌 칸
	const noWalk = ((src.match(/Walkable = \{([^}]*)\}/) || ["", ""])[1].match(/(\w) = false/g) || []).map((x) => x[0]);
	return { rows, rows2, upper, pits: new Set(["p", "b", "s", "n", ...pitExtra]), pitExtra, walk, noWalk, props: list(/Props = \{([^}]*)\}/), src };
}

function loadStage(fileOrId, dir = DIR) {
	const file = typeof fileOrId === "number" || /^\d+$/.test(fileOrId) ? `Stage${fileOrId}.luau` : fileOrId;
	return parse(fs.readFileSync(path.join(dir, file), "utf8"));
}

function stageIds(dir = DIR) {
	return fs.readdirSync(dir).map((f) => f.match(/^Stage(\d+)\.luau$/)).filter(Boolean).map((m) => +m[1]).sort((a, b) => a - b);
}

module.exports = { parse, loadStage, stageIds, DIR };
