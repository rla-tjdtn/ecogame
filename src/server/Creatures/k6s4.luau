--!strict
-- 6장 서브 괴물: 젖은 투숙객 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k6s4",
	hip = 1,
	voice = "k6s4",
	gimmick = "scare",
	cfg = { WanderSpeed = 6, InvestigateSpeed = 10, ChaseSpeed = 12, AgentRadius = 1.6, AgentHeight = 6 },
})
