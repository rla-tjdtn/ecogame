--!strict
-- 9장 서브 괴물: 차밑 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k9s1",
	hip = 1,
	voice = "k9s1",
	gimmick = "near",
	cfg = { WanderSpeed = 6, InvestigateSpeed = 10, ChaseSpeed = 12, AgentRadius = 1.6, AgentHeight = 6 },
})
