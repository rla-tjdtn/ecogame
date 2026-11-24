--!strict
-- c8h 눈높이 (8장 폐유치원 · 사람형) — 사양서: roster/v5/ch8/c8h_spec.md (+ QA1 수정 지시 반영)
-- 아이와 눈높이를 맞추려 무릎 꿇은 자세로 굳은 어른 선생님. 무릎으로 걷고, 정강이는 바닥에 끌리고, 발바닥은 위를 본다.
-- 목 2마디가 어깨 앞으로 꺾여 길쭉한 어른 머리가 가슴 앞(어깨보다 낮게)에 매달리고, 얼굴만 들어 올려다본다(무표정).
-- 오른손은 아이 손 높이로 내밀어 손바닥이 위(붉은 크레용 문지른 자국 한 줄), 왼손은 손등으로 바닥을 끈다.
-- 뼈: Pelvis → Spine → NeckBend1 → NeckBend2 → Head → FaceAim,  Spine → UpperArmR/L → ForearmR/L → HandR/L,
--      Pelvis → ThighL/R → KneeContactL/R(접지점) · ShinSkidL/R(끌리는 정강이) → FootUpL/R
-- 공포 장치 「눈높이」: 바닥에서 4 아래에 있는 것만 본다. 서서 걷는 플레이어(머리 4.4~5)는 시선(lineOfSight) 밖이라
--   옆을 지나가도 시야로는 못 알아챈다. 웅크리면(또는 머리가 4 아래면) 보인다. 쫓는 중에는 놓치지 않는다.
--   (기본 감각의 '아주 가까우면(7) 알아챔'은 그대로 — 몸에 닿을 만큼 가까우면 들킨다)
local Players = game:GetService("Players")
local Rig = require(script.Parent.Rig)

local M = {}
M.cfg = {
	WanderSpeed = 2.5,
	InvestigateSpeed = 4,
	ChaseSpeed = 6.5, -- 사양 5 → 웅크려 도망치는 사람(5)을 따라잡게 조금 올림
	AgentRadius = 1.3,
	AgentHeight = 3.5,
	CatchDistance = 2.8,
}
M.spawnLift = 1.6
M.voice = "3" -- (소리: 전용 소리 전까지 — 손톱 톡톡 계열)

local HIP = 0.4
local FLOOR = -(HIP + 1)
local EYE_LIMIT = 4
local function P(x: number, y: number, z: number): Vector3
	return Vector3.new(x, FLOOR + y, z)
end

function M.build(cf: CFrame): Model
	local model, root = Rig.shell("EyeLevel", cf, Vector3.new(1.6, 2, 1.6))
	local lines: { Rig.Line } = {}
	local balls: { Rig.Ball } = {}
	local function S(bone: string, a: Vector3, b: Vector3, red: boolean?)
		table.insert(lines, { bone = bone, a = a, b = b, r = 0.05, red = red })
	end
	local function chain(bone: string, pts: { Vector3 })
		for i = 1, #pts - 1 do
			S(bone, pts[i], pts[i + 1])
		end
	end
	local function limb(bone: string, a: Vector3, b: Vector3, wa: number, wm: number, wb: number, side: Vector3)
		local d = (b - a).Unit
		local off = (side - d * side:Dot(d)).Unit
		local m = a:Lerp(b, 0.45)
		for _, k in { -1, 1 } do
			chain(bone, { a + off * (wa * k), m + off * (wm * k), b + off * (wb * k) })
		end
	end
	-- 다리: 허벅지(골반 → 무릎 접지), 바닥에 끌리는 정강이, 위를 향한 발바닥
	for _, s in { -1, 1 } do
		local n = if s < 0 then "L" else "R"
		local hip, knee, ankle = P(0.34 * s, 1.55, 0.1), P(0.4 * s, 0.16, -0.36), P(0.38 * s, 0.13, 1.0)
		limb("Thigh" .. n, hip, knee, 0.3, 0.3, 0.17, Vector3.new(0.7 * s, 0, 0.7))
		S("KneeContact" .. n, knee + Vector3.new(0, 0.12, -0.16), knee + Vector3.new(0, -0.12, -0.06)) -- 무릎 앞 모서리
		chain("ShinSkid" .. n, { knee + Vector3.new(0, 0.16, 0.05), ankle + Vector3.new(0, 0.12, -0.1) }) -- 정강이 윗선
		chain("ShinSkid" .. n, { knee + Vector3.new(0, -0.13, 0.08), ankle + Vector3.new(0, -0.11, 0) }) -- 바닥에 끌리는 아랫선
		chain("FootUp" .. n, { ankle + Vector3.new(0, 0.12, 0), ankle + Vector3.new(0.02 * s, 0.3, 0.25), ankle + Vector3.new(0.04 * s, 0.14, 0.72) }) -- 위를 향한 발바닥
		S("FootUp" .. n, ankle + Vector3.new(0, -0.1, 0.05), ankle + Vector3.new(0.04 * s, -0.08, 0.72)) -- 바닥에 닿은 발등
	end
	-- 몸통: 둥글게 솟은 등, 배선, 옆선 + 앞치마 앞판 · 허리끈 2
	chain("Spine", { P(0, 1.6, 0.52), P(0, 2.55, 0.42), P(0, 3.25, 0.02), P(0, 3.32, -0.38) })
	chain("Spine", { P(0, 1.55, -0.22), P(0, 2.3, -0.42), P(0, 2.85, -0.62) })
	for _, s in { -1, 1 } do
		chain("Spine", { P(0.48 * s, 1.6, 0.15), P(0.55 * s, 2.5, 0.05), P(0.72 * s, 3.12, -0.35) })
	end
	S("Pelvis", P(-0.5, 1.58, 0.15), P(0.5, 1.58, 0.15))
	chain("Spine", { P(-0.4, 2.7, -0.56), P(-0.45, 1.05, -0.72), P(0.45, 1.05, -0.72), P(0.4, 2.7, -0.56) }) -- 앞치마
	S("Pelvis", P(-0.2, 1.75, 0.5), P(-0.28, 1.15, 0.72))
	S("Pelvis", P(0.15, 1.75, 0.5), P(0.25, 1.25, 0.76))
	-- 목 2마디: 어깨 앞으로 꺾여 내려감(100°)
	chain("NeckBend1", { P(0, 3.15, -0.42), P(0, 3.0, -0.78) })
	chain("NeckBend1", { P(0, 2.9, -0.36), P(0, 2.78, -0.62) })
	chain("NeckBend2", { P(0, 3.0, -0.78), P(0, 2.72, -0.98) })
	-- 머리: 길쭉한 성인 두개골(턱선·광대, 살짝 비대칭) — 옆 외곽 + 앞 외곽
	local hc = P(0.02, 2.42, -1.1)
	local side = { { 0.42, 0.05 }, { 0.3, -0.25 }, { 0.0, -0.36 }, { -0.32, -0.28 }, { -0.5, -0.05 }, { -0.25, 0.3 }, { 0.2, 0.32 } }
	for i = 1, #side do
		local a, c = side[i], side[i % #side + 1]
		S("Head", hc + Vector3.new(0, a[1], a[2]), hc + Vector3.new(0, c[1], c[2]))
	end
	local front = { { 0.42, 0 }, { 0.2, 0.3 }, { -0.15, 0.28 }, { -0.48, 0.1 }, { -0.5, -0.12 }, { -0.12, -0.31 }, { 0.22, -0.28 } }
	for i = 1, #front do
		local a, c = front[i], front[i % #front + 1]
		S("Head", hc + Vector3.new(a[2], a[1], -0.2), hc + Vector3.new(c[2], c[1], -0.2))
	end
	-- 얼굴(무표정): 위 눈꺼풀 2(눈동자는 눈꺼풀에 붙은 작은 점) + 다문 입 1
	S("FaceAim", hc + Vector3.new(-0.26, 0.06, -0.35), hc + Vector3.new(-0.04, 0.08, -0.37))
	S("FaceAim", hc + Vector3.new(0.05, 0.07, -0.37), hc + Vector3.new(0.28, 0.05, -0.35))
	table.insert(balls, { bone = "FaceAim", c = hc + Vector3.new(-0.14, 0.03, -0.37), r = 0.03 })
	table.insert(balls, { bone = "FaceAim", c = hc + Vector3.new(0.15, 0.02, -0.37), r = 0.03 })
	S("FaceAim", hc + Vector3.new(-0.13, -0.3, -0.33), hc + Vector3.new(0.14, -0.31, -0.33))
	-- 오른팔: 앞으로 내밀어 손바닥이 위(마른 성인 팔, 팔꿈치 하나) + 붉은 크레용 자국
	limb("UpperArmR", P(0.68, 3.1, -0.42), P(0.58, 2.25, -1.02), 0.14, 0.15, 0.09, Vector3.new(0.7, 0, 0.7))
	limb("ForearmR", P(0.58, 2.25, -1.02), P(0.38, 1.82, -1.78), 0.09, 0.11, 0.07, Vector3.new(0.6, 0.8, 0))
	chain("HandR", { P(0.24, 1.8, -1.8), P(0.2, 1.78, -2.2), P(0.26, 1.86, -2.48) })
	chain("HandR", { P(0.52, 1.8, -1.8), P(0.5, 1.8, -2.25), P(0.44, 1.88, -2.46) })
	S("HandR", P(0.32, 1.87, -2.0), P(0.36, 1.87, -2.22), true)
	-- 왼팔: 손등으로 바닥을 끈다
	limb("UpperArmL", P(-0.68, 3.1, -0.42), P(-0.88, 1.95, -0.75), 0.14, 0.15, 0.09, Vector3.new(-0.7, 0, 0.7))
	limb("ForearmL", P(-0.88, 1.95, -0.75), P(-0.72, 0.4, -1.05), 0.09, 0.11, 0.07, Vector3.new(-0.7, 0, 0.7))
	chain("HandL", { P(-0.72, 0.4, -1.05), P(-0.7, 0.06, -1.3), P(-0.66, 0.05, -1.75) })
	S("HandL", P(-0.85, 0.08, -1.4), P(-0.84, 0.05, -1.7))
	local bones: { Rig.Bone } = {
		{ name = "Pelvis", joint = P(0, 1.55, 0.1), tip = P(0, 1.85, 0.1) },
		{ name = "Spine", parent = "Pelvis", joint = P(0, 1.6, 0.1), tip = P(0, 3.15, -0.42) },
		{ name = "NeckBend1", parent = "Spine", joint = P(0, 3.15, -0.42), tip = P(0, 3.0, -0.78) },
		{ name = "NeckBend2", parent = "NeckBend1", joint = P(0, 3.0, -0.78), tip = P(0, 2.72, -0.98) },
		{ name = "Head", parent = "NeckBend2", joint = P(0, 2.72, -0.98), tip = P(0.02, 2.42, -1.1) },
		{ name = "FaceAim", parent = "Head", joint = P(0.02, 2.42, -1.1), tip = P(0.02, 2.42, -1.7) },
		{ name = "UpperArmR", parent = "Spine", joint = P(0.68, 3.1, -0.42), tip = P(0.58, 2.25, -1.02) },
		{ name = "ForearmR", parent = "UpperArmR", joint = P(0.58, 2.25, -1.02), tip = P(0.38, 1.82, -1.78) },
		{ name = "HandR", parent = "ForearmR", joint = P(0.38, 1.82, -1.78), tip = P(0.35, 1.85, -2.45) },
		{ name = "UpperArmL", parent = "Spine", joint = P(-0.68, 3.1, -0.42), tip = P(-0.88, 1.95, -0.75) },
		{ name = "ForearmL", parent = "UpperArmL", joint = P(-0.88, 1.95, -0.75), tip = P(-0.72, 0.4, -1.05) },
		{ name = "HandL", parent = "ForearmL", joint = P(-0.72, 0.4, -1.05), tip = P(-0.68, 0.05, -1.72) },
	}
	for _, s in { -1, 1 } do
		local n = if s < 0 then "L" else "R"
		table.insert(bones, { name = "Thigh" .. n, parent = "Pelvis", joint = P(0.34 * s, 1.55, 0.1), tip = P(0.4 * s, 0.16, -0.36) })
		table.insert(bones, { name = "KneeContact" .. n, parent = "Thigh" .. n, joint = P(0.4 * s, 0.16, -0.36), tip = P(0.4 * s, -0.06, -0.36) })
		table.insert(bones, { name = "ShinSkid" .. n, parent = "Thigh" .. n, joint = P(0.4 * s, 0.16, -0.36), tip = P(0.38 * s, 0.13, 1.0) })
		table.insert(bones, { name = "FootUp" .. n, parent = "ShinSkid" .. n, joint = P(0.38 * s, 0.13, 1.0), tip = P(0.42 * s, 0.14, 1.72) })
	end
	Rig.build(model, root, cf, {
		id = "c8h",
		bones = bones,
		lines = lines,
		balls = balls,
		floorY = FLOOR,
		mass = 0.9,
	})
	Rig.humanoid(model, HIP, M.cfg.WanderSpeed)
	return model
end

-- 이 점(감각이 묻는 플레이어 위치)의 주인이 눈높이(바닥 + 4) 아래에 있나
local function lowEnough(self: any, p: Vector3): boolean
	local floorY = self.root.Position.Y - (HIP + 1)
	for _, pl in Players:GetPlayers() do
		local char = pl.Character
		local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if char and r and (r.Position - p).Magnitude < 2.5 then
			if char:GetAttribute("MoveMode") == "Crouch" then
				return true
			end
			local head = char:FindFirstChild("Head") :: BasePart?
			local top = if head then head.Position.Y else r.Position.Y + 1.5
			return top - floorY < EYE_LIMIT
		end
	end
	return true
end

function M.init(self: any)
	-- 이 괴물만 시선 판정을 바꾼다(쫓는 중엔 원래대로)
	local orig = self.lineOfSight
	self.lineOfSight = function(me: any, p: Vector3): boolean
		if me.state ~= "Chase" and not lowEnough(me, p) then
			return false
		end
		return orig(me, p)
	end
end

return M
