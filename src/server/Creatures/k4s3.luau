--!strict
-- 4장 서브 괴물: 뒤집힌 환자 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k4s3",
	hip = 1,
	voice = "k4s3",
	gimmick = "scare",
	cfg = { WanderSpeed = 6, InvestigateSpeed = 10, ChaseSpeed = 13, AgentRadius = 1.6, AgentHeight = 6 },
})
