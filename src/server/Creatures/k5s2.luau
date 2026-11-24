--!strict
-- 5장 서브 괴물: 끼인 것 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k5s2",
	hip = 2,
	voice = "k5s2",
	gimmick = "freeze",
	cfg = { WanderSpeed = 5, InvestigateSpeed = 9, ChaseSpeed = 11, AgentRadius = 1.6, AgentHeight = 6 },
})
