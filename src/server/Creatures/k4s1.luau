--!strict
-- 4장 서브 괴물: 바퀴 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k4s1",
	hip = 1,
	voice = "k4s1",
	gimmick = "blind",
	cfg = { WanderSpeed = 6, InvestigateSpeed = 11, ChaseSpeed = 14, AgentRadius = 1.6, AgentHeight = 6 },
})
