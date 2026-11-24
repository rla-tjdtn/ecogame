--!strict
-- 3장 메인 괴물: 부은 자 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k3h1",
	hip = 2,
	voice = "k3h1",
	cfg = { WanderSpeed = 4, InvestigateSpeed = 8, ChaseSpeed = 10, AgentRadius = 1.6, AgentHeight = 6 },
})
