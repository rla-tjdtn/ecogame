--!strict
-- 3장 서브 괴물: 칠성 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k3s2",
	hip = 2,
	voice = "k3s2",
	gimmick = "near",
	cfg = { WanderSpeed = 5, InvestigateSpeed = 9, ChaseSpeed = 11, AgentRadius = 1.6, AgentHeight = 6 },
})
