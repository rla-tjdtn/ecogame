--!strict
-- 6장 서브 괴물: 욕조 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k6s3",
	hip = 1,
	voice = "k6s3",
	gimmick = "blind",
	cfg = { WanderSpeed = 3, InvestigateSpeed = 7, ChaseSpeed = 11, AgentRadius = 1.6, AgentHeight = 6 },
})
