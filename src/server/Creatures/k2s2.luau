--!strict
-- 2장 서브 괴물: 가위 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k2s2",
	hip = 2,
	voice = "k2s2",
	gimmick = "scare",
	cfg = { WanderSpeed = 5, InvestigateSpeed = 9, ChaseSpeed = 12, AgentRadius = 1.6, AgentHeight = 6 },
})
