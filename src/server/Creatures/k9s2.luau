--!strict
-- 9장 서브 괴물: 덮개 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k9s2",
	hip = 2,
	voice = "k9s2",
	gimmick = "freeze",
	cfg = { WanderSpeed = 5, InvestigateSpeed = 10, ChaseSpeed = 12, AgentRadius = 1.6, AgentHeight = 6 },
})
