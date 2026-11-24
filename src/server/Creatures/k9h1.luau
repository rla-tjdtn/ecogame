--!strict
-- 9장 메인 괴물: 키다리 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k9h1",
	hip = 2,
	voice = "k9h1",
	cfg = { WanderSpeed = 6, InvestigateSpeed = 10, ChaseSpeed = 13, AgentRadius = 1.6, AgentHeight = 6 },
})
