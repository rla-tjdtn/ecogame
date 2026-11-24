--!strict
-- 2장 메인 괴물: 진열장 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k2h2",
	hip = 2,
	voice = "k2h2",
	cfg = { WanderSpeed = 5, InvestigateSpeed = 9, ChaseSpeed = 11, AgentRadius = 1.6, AgentHeight = 6 },
})
