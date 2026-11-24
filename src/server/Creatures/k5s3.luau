--!strict
-- 5장 서브 괴물: 청음귀 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k5s3",
	hip = 1,
	voice = "k5s3",
	gimmick = "blind",
	cfg = { WanderSpeed = 6, InvestigateSpeed = 11, ChaseSpeed = 14, AgentRadius = 1.6, AgentHeight = 6 },
})
