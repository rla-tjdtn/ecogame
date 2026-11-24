--!strict
-- c9h 후방감지 (9장 지하 주차장 · 사람형) — 사양서: roster/v5/ch9/c9h_spec.md (+ QA2 수정 지시 반영)
-- 언제나 뒤로 걷는 앙상한 주차요원. 몸은 +Z(얼굴 쪽)를 보고 만들었고, 진행 방향(-Z, 루트의 앞)은 늘 등이다.
-- QA2: 진행 쪽 외곽이 볼록한 C(허리 뒤 = 등이 활처럼 진행 방향으로 내밀림), 얼굴 쪽은 오목하게 꺾인 갈비 ·
--      머리는 어깨 위가 아니라 등 뒤 아래에 거꾸로 매달림(벌린 입 + 눈꺼풀을 가로지르는 비뚤어진 테이프 한 장) ·
--      정강이·무릎은 얼굴 쪽으로 꺾임(진행 쪽에서 보면 역관절) · X 반사띠 없음 — 등뼈에 박힌 센서 원 5개.
-- 뼈: Pelvis → Spine1 → Spine2 → Chest → Neck1 → Neck2 → Head → Jaw,  Chest → UpperArmL/R → ForearmL/R → HandL/R,
--      Pelvis → ThighL/R → ShinL/R → FootL/R   (센서 1~5 는 척추 마디에 박힌 공 — 따로 움직이지 않아 뼈 없이 마디에 붙임)
-- 붉은 선: 센서 3번(등 한가운데).
-- 공포 장치 「후방 감지음」: 등 쪽 140° 부채꼴 · 28 안의 보이는 플레이어를 감지 → 거리 단계(Band 4~1, 클라이언트용)·추격,
--   추격 중 8 안이면 돌진(18). 음파를 맞으면 1.8초 동안 그 자리에서 핸들 꺾듯 돌아선 뒤(Turn) 그쪽을 조사 — 회전이 틈.
--   (얼굴 쪽 사각은 빠짐: 기본 AI 의 가까운 감지는 그대로 — 기본 AI 안정 우선. 삐 소리는 소리 담당이 Band 로)
local Players = game:GetService("Players")
local Rig = require(script.Parent.Rig)

local M = {}
M.cfg = {
	WanderSpeed = 5,
	InvestigateSpeed = 7,
	ChaseSpeed = 9,
	AgentRadius = 1.0,
	AgentHeight = 6.8,
	CatchDistance = 2.8,
}
M.spawnLift = 2.8
M.voice = "2" -- (소리: 전용 소리 전까지 — 끌리는 걸음 계열)

local HIP = 2.6
local FLOOR = -(HIP + 1)
local CHARGE = 18
local FAN = math.cos(math.rad(70))

local function P(x: number, y: number, z: number): Vector3
	return Vector3.new(x, FLOOR + y, z)
end

function M.build(cf: CFrame): Model
	local model, root = Rig.shell("Reverser", cf, Vector3.new(1.4, 2, 1.0))
	local lines: { Rig.Line } = {}
	local balls: { Rig.Ball } = {}
	local function S(bone: string, a: Vector3, b: Vector3)
		table.insert(lines, { bone = bone, a = a, b = b, r = 0.05 })
	end
	local function chain(bone: string, pts: { Vector3 })
		for i = 1, #pts - 1 do
			S(bone, pts[i], pts[i + 1])
		end
	end
	local function cone(bone: string, a: Vector3, b: Vector3, wa: number, wb: number, side: Vector3)
		local d = (b - a).Unit
		local off = (side - d * side:Dot(d)).Unit
		for _, k in { -1, 1 } do
			S(bone, a + off * (wa * k), b + off * (wb * k))
		end
	end
	-- 등: 진행 쪽(-Z)으로 볼록한 C — 척추 돌기 마디 + 쐐기 세 마디
	local back = { P(0, 3.95, -0.35), P(0, 4.9, -0.85), P(0, 5.8, -0.95), P(0, 6.6, -0.5) }
	S("Spine1", back[1], back[2])
	S("Spine2", back[2], back[3])
	S("Chest", back[3], back[4])
	for i, bone in { "Spine1", "Spine2", "Chest" } do
		local m = back[i]:Lerp(back[i + 1], 0.5)
		S(bone, m, m + Vector3.new(0, -0.05, -0.28)) -- 돌기
	end
	-- 얼굴 쪽(+Z): 오목하게 꺾인 갈비(좌우)
	for _, s in { -1, 1 } do
		S("Spine1", P(0.5 * s, 3.95, 0.3), P(0.45 * s, 4.85, 0.0))
		S("Spine2", P(0.45 * s, 4.85, 0.0), P(0.55 * s, 5.75, 0.1))
		S("Chest", P(0.55 * s, 5.75, 0.1), P(0.75 * s, 6.5, 0.2))
	end
	S("Chest", P(-0.85, 6.55, -0.25), P(0.85, 6.55, -0.25)) -- 어깨(머리 없는 꼭대기)
	-- 골반 쐐기 + 엉덩 가로대
	chain("Pelvis", { P(-0.55, 4.0, -0.3), P(0, 3.45, 0.05), P(0.55, 4.0, -0.3) })
	S("Pelvis", P(-0.55, 3.85, 0.0), P(0.55, 3.85, 0.0))
	-- 센서 5개: 척추에 박힌 원(붉은 것은 3번 하나)
	local sens = { { "Spine1", 4.35, -0.66 }, { "Spine1", 4.85, -0.95 }, { "Spine2", 5.35, -1.02 }, { "Spine2", 5.85, -1.05 }, { "Chest", 6.3, -0.85 } }
	for i, s in sens do
		table.insert(balls, { bone = s[1] :: string, c = P(0, s[2] :: number, s[3] :: number), r = 0.17, red = i == 3 })
	end
	-- 목: 어깨 뒤로 접혀 등 뒤 아래로(주름 고리 2) → 거꾸로 매달린 머리
	local n0, n1, n2 = P(0, 6.55, -0.45), P(0, 6.85, -1.0), P(0, 6.25, -1.35)
	S("Neck1", n0, n1)
	S("Neck2", n1, n2)
	table.insert(lines, { bone = "Neck1", a = P(0, 6.78, -0.82), b = P(0, 6.84, -0.88), r = 0.2, disc = true })
	table.insert(lines, { bone = "Neck2", a = P(0, 6.55, -1.2), b = P(0, 6.5, -1.25), r = 0.2, disc = true })
	local hc = P(0, 5.65, -1.45)
	table.insert(balls, { bone = "Head", c = hc, r = 0.42 })
	S("Head", hc + Vector3.new(-0.3, -0.02, -0.33), hc + Vector3.new(0.32, -0.2, -0.3)) -- 테이프 한 장(사선)
	S("Head", hc + Vector3.new(0.32, -0.2, -0.3), hc + Vector3.new(0.42, -0.08, -0.22)) -- 들린 끝
	chain("Jaw", { hc + Vector3.new(-0.2, 0.36, -0.3), hc + Vector3.new(0, 0.62, -0.42), hc + Vector3.new(0.2, 0.36, -0.3) }) -- 벌린 입(거꾸로라 위)
	-- 팔: 뒤(진행 쪽)로 더듬는 손
	for _, s in { -1, 1 } do
		local n = if s < 0 then "L" else "R"
		local sh, el, wr = P(0.8 * s, 6.45, -0.3), P(1.1 * s, 5.35, -1.2), P(0.95 * s, 4.85, -2.3)
		cone("UpperArm" .. n, sh, el, 0.15, 0.1, Vector3.new(s, 0, 0))
		cone("Forearm" .. n, el, wr, 0.1, 0.07, Vector3.new(s, 0, 0))
		for i = -1, 1 do
			S("Hand" .. n, wr, wr + Vector3.new(0.12 * i, -0.15 + 0.05 * i, -0.45))
		end
	end
	-- 다리: 무릎은 얼굴 쪽(+Z)으로, 발끝도 얼굴 쪽 — 진행 쪽에서 보면 역관절
	for _, s in { -1, 1 } do
		local n = if s < 0 then "L" else "R"
		local hip, knee, ankle = P(0.4 * s, 3.85, 0), P(0.45 * s, 2.0, 0.55), P(0.42 * s, 0.25, -0.1)
		cone("Thigh" .. n, hip, knee, 0.2, 0.13, Vector3.new(s, 0, 0))
		cone("Shin" .. n, knee, ankle, 0.13, 0.08, Vector3.new(s, 0, 0))
		S("Shin" .. n, knee + Vector3.new(0, 0.15, 0.12), knee + Vector3.new(0, -0.25, 0.14)) -- 슬개골 쐐기
		chain("Foot" .. n, { ankle + Vector3.new(0, 0, -0.18), ankle + Vector3.new(0, -0.2, -0.05), ankle + Vector3.new(0, -0.22, 0.75) })
	end
	local bones: { Rig.Bone } = {
		{ name = "Pelvis", joint = P(0, 3.85, 0), tip = P(0, 4.2, -0.4) },
		{ name = "Spine1", parent = "Pelvis", joint = P(0, 3.95, -0.1), tip = P(0, 4.9, -0.5) },
		{ name = "Spine2", parent = "Spine1", joint = P(0, 4.9, -0.5), tip = P(0, 5.8, -0.55) },
		{ name = "Chest", parent = "Spine2", joint = P(0, 5.8, -0.55), tip = P(0, 6.55, -0.4) },
		{ name = "Neck1", parent = "Chest", joint = n0, tip = n1 },
		{ name = "Neck2", parent = "Neck1", joint = n1, tip = n2 },
		{ name = "Head", parent = "Neck2", joint = n2, tip = hc },
		{ name = "Jaw", parent = "Head", joint = hc + Vector3.new(0, 0.3, -0.2), tip = hc + Vector3.new(0, 0.62, -0.42) },
	}
	for _, s in { -1, 1 } do
		local n = if s < 0 then "L" else "R"
		table.insert(bones, { name = "UpperArm" .. n, parent = "Chest", joint = P(0.8 * s, 6.45, -0.3), tip = P(1.1 * s, 5.35, -1.2) })
		table.insert(bones, { name = "Forearm" .. n, parent = "UpperArm" .. n, joint = P(1.1 * s, 5.35, -1.2), tip = P(0.95 * s, 4.85, -2.3) })
		table.insert(bones, { name = "Hand" .. n, parent = "Forearm" .. n, joint = P(0.95 * s, 4.85, -2.3), tip = P(0.95 * s, 4.7, -2.75) })
		table.insert(bones, { name = "Thigh" .. n, parent = "Pelvis", joint = P(0.4 * s, 3.85, 0), tip = P(0.45 * s, 2.0, 0.55) })
		table.insert(bones, { name = "Shin" .. n, parent = "Thigh" .. n, joint = P(0.45 * s, 2.0, 0.55), tip = P(0.42 * s, 0.25, -0.1) })
		table.insert(bones, { name = "Foot" .. n, parent = "Shin" .. n, joint = P(0.42 * s, 0.25, -0.1), tip = P(0.42 * s, 0.03, 0.75) })
	end
	Rig.build(model, root, cf, {
		id = "c9h",
		bones = bones,
		lines = lines,
		balls = balls,
		floorY = FLOOR,
		mass = 0.7,
	})
	Rig.humanoid(model, HIP, M.cfg.WanderSpeed)
	return model
end

-- 등 쪽 부채꼴(진행 방향 = 루트 LookVector) 안, 28 안, 보이는 가장 가까운 플레이어
local function sensed(self: any): (Player?, Vector3?, number)
	local my = self.root.Position
	local look = self.root.CFrame.LookVector
	local bestP: Player?, bestPos: Vector3?, bestD = nil, nil, math.huge
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Status") == "Alive" and not p:GetAttribute("Hidden") then
			local char = p.Character
			local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r then
				local to = r.Position - my
				local flat = Vector3.new(to.X, 0, to.Z)
				local dist = flat.Magnitude
				if dist < 28 and dist < bestD and math.abs(to.Y) < 8 and (dist < 0.5 or flat.Unit:Dot(look) >= FAN) and self:lineOfSight(r.Position) then
					bestP, bestPos, bestD = p, r.Position, dist
				end
			end
		end
	end
	return bestP, bestPos, bestD
end

function M.init(self: any)
	self.model:SetAttribute("Band", 0)
end

function M.tick(self: any, now: number): boolean
	local d = self.cdata
	-- 음파 뒤 돌아서기(1.8초 멈춤) → 그쪽 조사
	if d.turnUntil then
		if now < d.turnUntil then
			self.hum:MoveTo(self.root.Position)
			return true
		end
		local at: Vector3 = d.turnAt
		d.turnUntil, d.turnAt = nil, nil
		self:investigate(at)
	end
	-- 센서: 거리 단계(28~16 → 1, 16~8 → 2, 8~3 → 3, 3 미만 → 4)
	local p, pos, dist = sensed(self)
	local band = if not p then 0 elseif dist < 3 then 4 elseif dist < 8 then 3 elseif dist < 16 then 2 else 1
	if self.model:GetAttribute("Band") ~= band then
		self.model:SetAttribute("Band", band)
	end
	if p and pos and self.state ~= "Chase" then
		self:startChase(p, pos)
	end
	-- 추격 중 마지막 두 칸(8)에서는 돌진
	if self.state == "Chase" then
		local want = if band >= 3 then CHARGE else M.cfg.ChaseSpeed
		if self.hum.WalkSpeed ~= want then
			self.hum.WalkSpeed = want
		end
	end
	return false
end

function M.hear(self: any, pos: Vector3, _radius: number, source: Player?, kind: string): boolean
	if kind ~= "Sonar" or source == nil or self.state == "Chase" or self.cdata.turnUntil then
		return false
	end
	if (pos - self.root.Position).Magnitude > 60 then
		return false
	end
	local now = os.clock()
	self.cdata.turnUntil = now + 1.8
	self.cdata.turnAt = pos
	self.model:SetAttribute("Turn", now)
	return true
end

return M
