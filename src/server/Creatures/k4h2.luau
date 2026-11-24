--!strict
-- 4장 메인 괴물: 무영등 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k4h2",
	hip = 2,
	voice = "k4h2",
	cfg = { WanderSpeed = 5, InvestigateSpeed = 9, ChaseSpeed = 11, AgentRadius = 1.6, AgentHeight = 6 },
})
