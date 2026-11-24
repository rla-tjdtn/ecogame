--!strict
-- 10장 메인 괴물: 뜬눈 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k10h1b",
	sprite = "k10h1",
	hip = 2,
	voice = "k10h1b",
	cfg = { WanderSpeed = 6, InvestigateSpeed = 10, ChaseSpeed = 12, AgentRadius = 1.6, AgentHeight = 6 },
})
