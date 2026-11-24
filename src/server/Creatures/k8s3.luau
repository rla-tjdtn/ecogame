--!strict
-- 8장 서브 괴물: 모빌 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k8s3",
	hip = 2,
	voice = "k8s3",
	gimmick = "near",
	cfg = { WanderSpeed = 5, InvestigateSpeed = 9, ChaseSpeed = 11, AgentRadius = 1.6, AgentHeight = 6 },
})
