--!strict
-- 1장 서브 괴물: 나무 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k1s2",
	hip = 1,
	voice = "k1s2",
	gimmick = "freeze",
	cfg = { WanderSpeed = 3, InvestigateSpeed = 6, ChaseSpeed = 9, AgentRadius = 1.6, AgentHeight = 6 },
})
