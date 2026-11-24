--!strict
-- 2장 서브 괴물: 다섯 손가락 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k2s1",
	hip = 1,
	voice = "k2s1",
	gimmick = "blind",
	cfg = { WanderSpeed = 6, InvestigateSpeed = 10, ChaseSpeed = 13, AgentRadius = 1.6, AgentHeight = 6 },
})
