--!strict
-- 9장 서브 괴물: 전조등 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k9s3",
	hip = 1,
	voice = "k9s3",
	gimmick = "scare",
	cfg = { WanderSpeed = 6, InvestigateSpeed = 10, ChaseSpeed = 13, AgentRadius = 1.6, AgentHeight = 6 },
})
