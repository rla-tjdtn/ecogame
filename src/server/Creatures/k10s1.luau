--!strict
-- 10장 서브 괴물: 잔상 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k10s1",
	hip = 2,
	voice = "k10s1",
	gimmick = "scare",
	cfg = { WanderSpeed = 6, InvestigateSpeed = 10, ChaseSpeed = 13, AgentRadius = 1.6, AgentHeight = 6 },
})
