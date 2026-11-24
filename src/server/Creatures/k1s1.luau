--!strict
-- 1장 서브 괴물: 양두 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k1s1",
	hip = 1,
	voice = "k1s1",
	gimmick = "near",
	cfg = { WanderSpeed = 7, InvestigateSpeed = 11, ChaseSpeed = 13, AgentRadius = 1.6, AgentHeight = 6 },
})
