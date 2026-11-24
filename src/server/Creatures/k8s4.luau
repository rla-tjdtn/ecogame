--!strict
-- 8장 서브 괴물: 큰 인형 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k8s4",
	hip = 1,
	voice = "k8s4",
	gimmick = "blind",
	cfg = { WanderSpeed = 6, InvestigateSpeed = 11, ChaseSpeed = 13, AgentRadius = 1.6, AgentHeight = 6 },
})
