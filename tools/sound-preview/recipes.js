// 괴성 카탈로그(60개): 효과 10종 × 높낮이 3단계 × 끊김 2종. 번호 = Config.ScreamRecipe.
// 이 목록에서 미리듣기 페이지와 Config.luau(ScreamRecipes)가 함께 만들어진다(node tools/sound-preview/build.js).
const FX = [
	// [키, 이름, 소리 원본, [높음, 중간, 낮음] 피치, 겹치는 두 번째 소리]
	["ghost", "귀신 곡소리", "ouch", [1.5, 1.25, 0.9], "wind"],
	["hollow", "공허한 울음", "ouch", [1.0, 0.8, 0.55], "oof"],
	["breath", "바람 숨소리", "wind", [2.4, 2.0, 1.4], "oof"],
	["siren", "떨리는 사이렌", "ouch", [0.9, 0.6, 0.45], null],
	["stutter", "더듬는 사이렌", "ouch", [0.9, 0.6, 0.45], null],
	["echo", "에코 파동", "ouch", [0.7, 0.5, 0.4], null],
	["flange", "플랜저 휘감김", "wind", [2.0, 1.6, 1.1], null],
	["screech", "초음파 비명", "ouch", [1.8, 1.4, 1.1], null],
	["roar", "왜곡 포효", "ouch", [0.6, 0.45, 0.35], "wind"],
	["pulse", "저주파 맥동", "wind", [0.5, 0.35, 0.28], null],
];
const PITCH = ["높은 음", "중간 음", "낮은 음"];
const GATES = [
	["빠르게 끊김", [0.15, 0.1]],
	["느리게 끊김", [0.35, 0.25]],
];
const recipes = [];
for (const [fx, fname, src, pitches, air] of FX)
	PITCH.forEach((pn, pi) =>
		GATES.forEach(([gn, gate]) => recipes.push({ n: recipes.length + 1, name: `${fname} · ${pn} · ${gn}`, fx, src, pitch: pitches[pi], gate, air })),
	);
module.exports = { recipes, FX };
