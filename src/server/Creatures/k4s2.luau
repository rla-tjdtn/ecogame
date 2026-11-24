--!strict
-- 4장 서브 괴물: 거꾸로 기는 환자 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k4s2",
	hip = 1,
	voice = "k4s2",
	gimmick = "freeze",
	cfg = { WanderSpeed = 6, InvestigateSpeed = 10, ChaseSpeed = 12, AgentRadius = 1.6, AgentHeight = 6 },
})
