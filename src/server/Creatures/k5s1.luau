--!strict
-- 5장 서브 괴물: 웅크린 것 (자동 생성: art/creatures/source/game/gen-game.js)
local Baked = require(script.Parent.Baked)
return Baked.creature({
	id = "k5s1",
	hip = 1,
	voice = "k5s1",
	gimmick = "scare",
	cfg = { WanderSpeed = 6, InvestigateSpeed = 10, ChaseSpeed = 13, AgentRadius = 1.6, AgentHeight = 6 },
})
