--!strict
-- 6장 메인 괴물: 벨보이 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k6h2",
	hip = 2,
	voice = "k6h2",
	cfg = { WanderSpeed = 6, InvestigateSpeed = 10, ChaseSpeed = 12, AgentRadius = 1.6, AgentHeight = 6 },
})
