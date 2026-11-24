--!strict
-- c7h 손든 아이 (7장 학교 · 사람형) — 사양서: roster/v5/ch7/c7h_spec.md (+ QA1 수정 지시 반영)
-- 복도에서 뛰다 걸려 두 손을 머리 위로 든 채 굳은 아이. 팔과 허리만 늘어났고(손끝 11.9), 다리·발·손은 아이 크기.
-- 어깨가 귀 위까지 솟아 머리를 덮어 정면에서는 '머리 없는 몸' — 어깨 골짜기에 머리카락 끝만 보인다.
-- 재킷은 갈비까지 말려 올라가 늘어난 허리(갈비 자국)가 드러나고, 왼팔에 붉은 선도부 완장.
-- 뼈: Pelvis → Spine → Chest → ShoulderShrugL/R → UpperArmL/R(→ ArmbandL) → ForearmL/R,  ForearmL → Clasp(맞댄 두 손 한 뼈),
--      Chest → Jacket,  Chest → NeckDrop → Head,  Pelvis → ThighL/R → ShinL/R → FootL/R → SlipperL/R
-- 공포 장치 「복도에서 뛰지 마라」: 걷기·웅크리기 발소리는 무시한다. 40 안에서 보이는 자리의 누가 달리면(StepRun)
--   0.35초 만에 돌아서서(Turn) 행진 추격. 6 안에서 쏜 음파에도 돌아선다(더 먼 음파는 무시).
--   (교실 문 높이로 못 들어오는 규칙은 길찾기 높이를 바꿔야 해서 빠짐 — 기본 AI 안정 우선)
local Rig = require(script.Parent.Rig)

local M = {}
M.cfg = {
	WanderSpeed = 7, -- 플레이어 걷기 10 × 0.7
	InvestigateSpeed = 8,
	ChaseSpeed = 17.1, -- 플레이어 달리기 18 × 0.95
	AgentRadius = 1.2,
	AgentHeight = 8,
	CatchDistance = 3.6,
}
M.spawnLift = 3.2
M.voice = "4" -- (소리: 전용 소리 전까지 — 찰싹 걸음 대신 쿵 걸음 계열)

local HIP = 2
local FLOOR = -(HIP + 1)
local function P(x: number, y: number, z: number): Vector3
	return Vector3.new(x, FLOOR + y, z)
end

function M.build(cf: CFrame): Model
	local model, root = Rig.shell("RaisedHands", cf, Vector3.new(1.4, 2, 1.0))
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
	-- 다리(짧은 아이 다리, 무릎 거의 폄) + 작은 실내화(밑창·발등·뒤축)
	for _, s in { -1, 1 } do
		local n = if s < 0 then "L" else "R"
		local hip, knee, ankle = P(0.3 * s, 3.7, 0), P(0.31 * s, 2.0, -0.08), P(0.3 * s, 0.35, 0.02)
		limb("Thigh" .. n, hip, knee, 0.26, 0.25, 0.17, Vector3.new(0.75 * s, 0, 0.65))
		limb("Shin" .. n, knee, ankle, 0.17, 0.18, 0.13, Vector3.new(0.75 * s, 0, 0.65))
		chain("Slipper" .. n, { ankle + Vector3.new(0, -0.32, 0.22), ankle + Vector3.new(0, -0.33, -0.55), ankle + Vector3.new(0, -0.16, -0.75) })
		S("Foot" .. n, ankle + Vector3.new(0, 0.0, -0.05), ankle + Vector3.new(0, -0.15, -0.72))
		S("Slipper" .. n, ankle + Vector3.new(0, -0.3, 0.22), ankle + Vector3.new(0, -0.08, 0.2)) -- 들리는 뒤축
	end
	-- 바지 윗단 + 늘어난 허리(옆선이 끊기지 않게 바지 → 허리 → 재킷 밑단) + 갈비 자국
	S("Pelvis", P(-0.55, 3.95, -0.2), P(0.55, 3.95, -0.2))
	S("Pelvis", P(-0.55, 3.95, -0.2), P(-0.5, 3.4, 0.0))
	for _, s in { -1, 1 } do
		chain("Spine", { P(0.55 * s, 3.95, -0.05), P(0.42 * s, 4.9, -0.02), P(0.5 * s, 5.75, 0.0) })
	end
	for i = 0, 2 do
		local y = 5.0 + i * 0.25
		S("Spine", P(-0.36 + i * 0.02, y, -0.3), P(-0.08, y + 0.12, -0.33))
	end
	-- 재킷(말려 올라감): 밑단 · 옆선 · 지퍼 · 이름표
	S("Jacket", P(-0.62, 5.8, -0.32), P(0.62, 5.75, -0.32))
	S("Jacket", P(-0.62, 5.8, 0.32), P(0.62, 5.78, 0.32))
	for _, s in { -1, 1 } do
		chain("Chest", { P(0.62 * s, 5.78, 0.0), P(0.6 * s, 6.55, 0.0), P(0.7 * s, 7.1, 0.0) })
	end
	S("Chest", P(0.02, 5.8, -0.34), P(0.0, 6.95, -0.32))
	S("Chest", P(0.2, 6.55, -0.33), P(0.46, 6.55, -0.32))
	-- 솟은 어깨: 귀 위까지 올라가 머리를 덮는 덩어리(앞·옆 외곽)
	for _, s in { -1, 1 } do
		local n = if s < 0 then "L" else "R"
		chain("ShoulderShrug" .. n, { P(0.12 * s, 7.0, -0.3), P(0.32 * s, 7.75, -0.2), P(0.68 * s, 7.85, 0.0), P(0.74 * s, 7.2, 0.05) })
		S("ShoulderShrug" .. n, P(0.12 * s, 7.0, 0.3), P(0.32 * s, 7.75, 0.2))
	end
	-- 어깨 골짜기 속 머리: 정수리 호 + 머리카락 끝 4가닥만
	chain("Head", { P(-0.2, 7.35, -0.12), P(0, 7.45, -0.16), P(0.2, 7.35, -0.12) })
	for i, x in { -0.15, -0.05, 0.06, 0.16 } do
		S("Head", P(x, 7.42, -0.16), P(x * 1.3, 7.05 - (i % 2) * 0.12, -0.3))
	end
	-- 팔: 들린 어깨에서 곧게 위로, 팔꿈치는 살짝 뒤로 꺾임(과신전)
	for _, s in { -1, 1 } do
		local n = if s < 0 then "L" else "R"
		local sh, el, wr = P(0.55 * s, 7.6, 0.0), P(0.44 * s, 9.6, 0.16), P(0.14 * s, 11.15, 0.02)
		limb("UpperArm" .. n, sh, el, 0.2, 0.19, 0.13, Vector3.new(0.7 * s, 0, 0.7))
		limb("Forearm" .. n, el, wr, 0.13, 0.15, 0.09, Vector3.new(0.7 * s, 0, 0.7))
	end
	-- 붉은 완장(왼 위팔을 두른 고리 하나)
	table.insert(lines, { bone = "ArmbandL", a = P(-0.51, 8.25, 0.06), b = P(-0.51, 8.28, 0.06), r = 0.23, red = true, disc = true })
	-- 맞댄 두 손(한 덩어리): 손바닥 외곽 + 맞댄 선
	chain("Clasp", { P(-0.16, 11.1, 0.0), P(-0.1, 11.7, 0.0), P(0.0, 11.95, 0.0), P(0.1, 11.7, 0.0), P(0.16, 11.1, 0.0) })
	S("Clasp", P(0, 11.15, -0.02), P(0, 11.85, -0.02))
	local bones: { Rig.Bone } = {
		{ name = "Pelvis", joint = P(0, 3.7, 0), tip = P(0, 4.0, 0) },
		{ name = "Spine", parent = "Pelvis", joint = P(0, 3.9, 0), tip = P(0, 5.75, 0) },
		{ name = "Chest", parent = "Spine", joint = P(0, 5.75, 0), tip = P(0, 7.1, 0) },
		{ name = "Jacket", parent = "Chest", joint = P(0, 6.4, 0), tip = P(0, 5.78, 0) },
		{ name = "NeckDrop", parent = "Chest", joint = P(0, 7.0, 0.05), tip = P(0, 7.2, -0.1) },
		{ name = "Head", parent = "NeckDrop", joint = P(0, 7.2, -0.1), tip = P(0, 7.45, -0.16) },
		{ name = "ShoulderShrugL", parent = "Chest", joint = P(-0.12, 7.0, 0), tip = P(-0.55, 7.6, 0) },
		{ name = "UpperArmL", parent = "ShoulderShrugL", joint = P(-0.55, 7.6, 0), tip = P(-0.44, 9.6, 0.16) },
		{ name = "ArmbandL", parent = "UpperArmL", joint = P(-0.51, 8.25, 0.06), tip = P(-0.5, 8.5, 0.08) },
		{ name = "ForearmL", parent = "UpperArmL", joint = P(-0.44, 9.6, 0.16), tip = P(-0.14, 11.15, 0.02) },
		{ name = "Clasp", parent = "ForearmL", joint = P(0, 11.12, 0.02), tip = P(0, 11.95, 0) },
		{ name = "ShoulderShrugR", parent = "Chest", joint = P(0.12, 7.0, 0), tip = P(0.55, 7.6, 0) },
		{ name = "UpperArmR", parent = "ShoulderShrugR", joint = P(0.55, 7.6, 0), tip = P(0.44, 9.6, 0.16) },
		{ name = "ForearmR", parent = "UpperArmR", joint = P(0.44, 9.6, 0.16), tip = P(0.14, 11.15, 0.02) },
	}
	for _, s in { -1, 1 } do
		local n = if s < 0 then "L" else "R"
		table.insert(bones, { name = "Thigh" .. n, parent = "Pelvis", joint = P(0.3 * s, 3.7, 0), tip = P(0.31 * s, 2.0, -0.08) })
		table.insert(bones, { name = "Shin" .. n, parent = "Thigh" .. n, joint = P(0.31 * s, 2.0, -0.08), tip = P(0.3 * s, 0.35, 0.02) })
		table.insert(bones, { name = "Foot" .. n, parent = "Shin" .. n, joint = P(0.3 * s, 0.35, 0.02), tip = P(0.3 * s, 0.05, -0.72) })
		table.insert(bones, { name = "Slipper" .. n, parent = "Foot" .. n, joint = P(0.3 * s, 0.05, 0.2), tip = P(0.3 * s, 0.03, -0.75) })
	end
	Rig.build(model, root, cf, {
		id = "c7h",
		bones = bones,
		lines = lines,
		balls = balls,
		floorY = FLOOR,
		mass = 0.8,
	})
	Rig.humanoid(model, HIP, M.cfg.WanderSpeed)
	return model
end

-- 돌아서기(0.35초 멈춤) → 행진 추격
function M.tick(self: any, now: number): boolean
	local d = self.cdata
	if not d.turnUntil then
		return false
	end
	if now < d.turnUntil then
		self.hum:MoveTo(self.root.Position)
		return true
	end
	local p: Player?, at: Vector3? = d.turnWho, d.turnAt
	d.turnUntil, d.turnWho, d.turnAt = nil, nil, nil
	if p and at and p.Parent and p:GetAttribute("Status") == "Alive" then
		self:startChase(p, at)
	end
	return false
end

function M.hear(self: any, pos: Vector3, _radius: number, source: Player?, kind: string): boolean
	if self.state == "Chase" or self.cdata.turnUntil then
		return false
	end
	local dist = (pos - self.root.Position).Magnitude
	local trigger = false
	if kind == "StepWalk" or kind == "StepCrouch" or kind == "StepLand" then
		return true -- 걷기·웅크리기는 무시
	elseif kind == "StepRun" then
		trigger = source ~= nil and dist <= 40 and self:lineOfSight(pos + Vector3.new(0, 2.5, 0))
	elseif kind == "Sonar" then
		if dist > 6 then
			return true -- 먼 음파는 무시
		end
		trigger = source ~= nil
	end
	if not trigger then
		return false
	end
	local now = os.clock()
	self.cdata.turnUntil = now + 0.35
	self.cdata.turnWho = source
	self.cdata.turnAt = pos
	self.model:SetAttribute("Turn", now)
	-- 소리 쪽으로 몸 전체를 홱(판처럼)
	local my = self.root.Position
	local to = Vector3.new(pos.X - my.X, 0, pos.Z - my.Z)
	if to.Magnitude > 0.5 then
		self.root.CFrame = CFrame.lookAt(my, my + to.Unit)
	end
	return true
end

return M
