--!strict
-- 1장 메인 괴물: 흉문 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k1h1",
	hip = 2,
	voice = "k1h1",
	cfg = { WanderSpeed = 6, InvestigateSpeed = 10, ChaseSpeed = 12, AgentRadius = 1.6, AgentHeight = 6 },
})
