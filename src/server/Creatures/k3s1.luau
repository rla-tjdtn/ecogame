--!strict
-- 3장 서브 괴물: 아가리 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k3s1",
	hip = 1,
	voice = "k3s1",
	gimmick = "blind",
	cfg = { WanderSpeed = 7, InvestigateSpeed = 11, ChaseSpeed = 14, AgentRadius = 1.6, AgentHeight = 6 },
})
