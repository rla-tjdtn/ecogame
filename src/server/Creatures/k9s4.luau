--!strict
-- 9장 서브 괴물: 보닛 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k9s4",
	hip = 2,
	voice = "k9s4",
	gimmick = "blind",
	cfg = { WanderSpeed = 6, InvestigateSpeed = 11, ChaseSpeed = 14, AgentRadius = 1.6, AgentHeight = 6 },
})
