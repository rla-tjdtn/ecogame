--!strict
-- c4h 견인 환자 (4장 폐병원 · 사람형) — 사양서: roster/v5/ch4/c4h_spec.md (+ QA1 수정 지시 반영)
-- 경추 견인을 몇 년 받아 목이 세 마디로 늘어난 채 일어선 환자. 정수리 고리에 묶인 붉은 견인줄이 뒤로 늘어진다.
-- 발끝으로 들린 걸음, 고정틀(일리자로프)을 찬 왼다리는 바깥으로 휘돌려 끈다. 왼손은 앞 기둥을 쥐고, 오른손은 늘어짐.
-- 뼈: pelvis → lumbar → chest → neck1 → neck2 → neck3 → head → crown → cord0 → cord1 → cord2,  head → haloRing,
--      chest → vest, chest → shoulderL/R → elbow → wrist,  pelvis → hipL/R → knee → ankle,  kneeL → fixatorL
-- 공포 장치 「견인줄」(간단판): 지나온 길(최근 약 130 스터드)에 보이지 않는 줄이 남는다.
--   플레이어가 그 줄(발목~가슴 높이)에 닿으면 헤일로가 울리고(Ring, 1.2초 멈춤) 돌아서서 16 으로 감아 당기며 돌진한다.
--   (맵 걸이점·침대 도르래까지 이어지는 실제 줄 표시는 빠짐 — 몸에 붙은 붉은 줄 3마디만 보인다)
local Players = game:GetService("Players")
local Rig = require(script.Parent.Rig)

local M = {}
M.cfg = {
	WanderSpeed = 4.5,
	InvestigateSpeed = 7,
	ChaseSpeed = 7,
	AgentRadius = 1.2,
	AgentHeight = 9,
	CatchDistance = 3,
}
M.spawnLift = 3.2
M.voice = "5" -- (소리: 전용 소리 전까지 — 금속성 걸음 계열)

local HIP = 2
local FLOOR = -(HIP + 1)
local DASH_SPEED = 16
local TRAIL_STEP = 5
local TRAIL_MAX = 26
local function P(x: number, y: number, z: number): Vector3
	return Vector3.new(x, FLOOR + y, z)
end

function M.build(cf: CFrame): Model
	local model, root = Rig.shell("Traction", cf, Vector3.new(1.6, 2, 1.2))
	local lines: { Rig.Line } = {}
	local balls: { Rig.Ball } = {}
	local function S(bone: string, a: Vector3, b: Vector3, red: boolean?)
		table.insert(lines, { bone = bone, a = a, b = b, r = 0.05, red = red })
	end
	local function chain(bone: string, pts: { Vector3 }, red: boolean?)
		for i = 1, #pts - 1 do
			S(bone, pts[i], pts[i + 1], red)
		end
	end
	local function limb(bone: string, a: Vector3, b: Vector3, wa: number, wm: number, wb: number, side: Vector3)
		local d = (b - a).Unit
		local off = (side - d * side:Dot(d)).Unit
		local m = a:Lerp(b, 0.4)
		for _, k in { -1, 1 } do
			chain(bone, { a + off * (wa * k), m + off * (wm * k), b + off * (wb * k) })
		end
	end
	local function ring(bone: string, c: Vector3, r: number, n: number, phase: number)
		for i = 0, n - 1 do
			local a0, a1 = phase + i * math.pi * 2 / n, phase + (i + 1) * math.pi * 2 / n
			S(bone, c + Vector3.new(math.cos(a0) * r, 0, math.sin(a0) * r), c + Vector3.new(math.cos(a1) * r, 0, math.sin(a1) * r))
		end
	end
	-- 다리: 앙상한 정강이·튀어나온 무릎뼈, 발끝으로 선 발
	for _, s in { -1, 1 } do
		local n = if s < 0 then "L" else "R"
		local hip, knee, ankle = P(0.32 * s, 4.42, 0), P(0.36 * s, 2.42, -0.2), P(0.36 * s, 0.6, 0.05)
		limb("hip" .. n, hip, knee, 0.2, 0.18, 0.09, Vector3.new(0.7 * s, 0, 0.7))
		limb("knee" .. n, knee, ankle, 0.08, 0.1, 0.05, Vector3.new(0.7 * s, 0, 0.7))
		S("knee" .. n, knee + Vector3.new(0, 0.14, -0.13), knee + Vector3.new(0, -0.18, -0.12)) -- 무릎뼈
		chain("ankle" .. n, { ankle + Vector3.new(0, 0, 0.08), ankle + Vector3.new(0, -0.52, -0.42), ankle + Vector3.new(0, -0.58, -0.7) }) -- 발등 → 발끝
		S("ankle" .. n, ankle + Vector3.new(0, -0.12, 0.12), ankle + Vector3.new(0, -0.56, -0.44)) -- 발바닥(뒤꿈치 들림)
	end
	-- 고정틀(왼 정강이): 고리 2개 + 막대 3개
	local kl = P(-0.36, 2.42, -0.2)
	local fixC = { kl:Lerp(P(-0.36, 0.6, 0.05), 0.25), kl:Lerp(P(-0.36, 0.6, 0.05), 0.75) }
	for _, c in fixC do
		table.insert(lines, { bone = "fixatorL", a = c, b = c + Vector3.new(0, 0.03, 0), r = 0.42, disc = true })
	end
	for i = 0, 2 do
		local t = math.rad(90 + i * 120)
		local o = Vector3.new(math.cos(t) * 0.42, 0, math.sin(t) * 0.42)
		S("fixatorL", fixC[1] + o + Vector3.new(0, 0.25, 0), fixC[2] + o - Vector3.new(0, 0.2, 0))
	end
	-- 환자복: 위가 좁은 사다리꼴(옆선 2 · 끝단 3 · 목둘레 2) + 등 뒤로 처진 끈 2
	for _, s in { -1, 1 } do
		chain("lumbar", { P(0.62 * s, 6.75, 0.02), P(0.75 * s, 5.0, 0.05), P(0.98 * s, 3.0, 0.1) })
		S("chest", P(0.2 * s, 7.05, -0.12), P(0.62 * s, 6.92, 0.0)) -- 목둘레 → 어깨
	end
	chain("pelvis", { P(-0.98, 3.0, 0.1), P(-0.35, 3.15, -0.42), P(0.3, 2.95, -0.4), P(0.98, 3.0, 0.1) })
	S("lumbar", P(-0.15, 5.4, 0.5), P(-0.22, 4.3, 0.62))
	S("lumbar", P(0.12, 5.4, 0.5), P(0.25, 4.6, 0.66))
	-- 쇄골·견갑 나사판(vest) + 헤일로 기둥 4(앞 두 기둥은 얼굴 양옆 바깥으로 벌어짐)
	S("vest", P(-0.62, 7.05, -0.32), P(0.62, 7.05, -0.32))
	S("vest", P(-0.62, 7.05, 0.32), P(0.62, 7.05, 0.32))
	local postTop = {
		P(-0.92, 9.95, -0.55),
		P(0.92, 9.95, -0.55),
		P(-0.7, 9.95, 0.68),
		P(0.7, 9.95, 0.68),
	}
	local postBot = { P(-0.6, 7.05, -0.32), P(0.6, 7.05, -0.32), P(-0.6, 7.05, 0.32), P(0.6, 7.05, 0.32) }
	for i = 1, 4 do
		S("vest", postBot[i], postTop[i])
	end
	-- 목 3마디(가늘고 길게, 마디마다 살짝 앞으로 꺾임)
	local nk = { P(0, 7.05, 0.0), P(0, 8.2, -0.12), P(0, 9.0, -0.05), P(0, 9.62, 0.0) }
	local nw = { 0.17, 0.12, 0.11, 0.12 }
	for i = 1, 3 do
		local bn = "neck" .. i
		for _, k in { -1, 1 } do
			S(bn, nk[i] + Vector3.new(nw[i] * k, 0, 0), nk[i + 1] + Vector3.new(nw[i + 1] * k, 0, 0))
		end
	end
	-- 머리: 길쭉한 머리(옆 외곽 + 앞 외곽), 거즈가 입 자리로 빨려 든 홈
	local hc = P(0, 10.05, -0.05)
	local side = { { 0.0, -0.5 }, { 0.32, -0.42 }, { 0.55, -0.05 }, { 0.4, 0.32 }, { -0.1, 0.42 }, { -0.42, 0.22 }, { -0.5, -0.3 } }
	for i = 1, #side do
		local a, c = side[i], side[i % #side + 1]
		S("head", hc + Vector3.new(0, a[1], a[2]), hc + Vector3.new(0, c[1], c[2]))
	end
	local front = { { 0.0, 0.32 }, { 0.38, 0.28 }, { 0.55, 0.0 }, { 0.3, -0.27 }, { -0.45, -0.18 }, { -0.5, 0.18 } }
	for i = 1, #front do
		local a, c = front[i], front[i % #front + 1]
		S("head", hc + Vector3.new(a[2], a[1], -0.1), hc + Vector3.new(c[2], c[1], -0.1))
	end
	chain("head", { hc + Vector3.new(-0.16, -0.22, -0.46), hc + Vector3.new(0, -0.3, -0.36), hc + Vector3.new(0.15, -0.21, -0.46) }) -- 입 홈
	S("head", hc + Vector3.new(-0.3, -0.05, -0.43), hc + Vector3.new(0.3, -0.08, -0.43)) -- 거즈 띠
	-- 헤일로 고리(8각) + 두개골 핀 4
	local haloC = P(0, 9.95, 0.06)
	ring("haloRing", haloC, 0.98, 8, math.pi / 8)
	for _, t in { 45, 135, 225, 315 } do
		local a = math.rad(t)
		local o = Vector3.new(math.cos(a), 0, math.sin(a))
		S("haloRing", haloC + o * 0.98, haloC + o * 0.5 + Vector3.new(0, 0.12, 0))
	end
	-- 팔: 왼손은 앞 기둥을 쥐고(어깨 → 팔꿈치 아래 → 손이 위로), 오른손은 늘어짐
	limb("shoulderL", P(-0.68, 6.88, 0.0), P(-1.12, 5.55, -0.45), 0.13, 0.14, 0.08, Vector3.new(0, 0.6, 0.8))
	limb("elbowL", P(-1.12, 5.55, -0.45), P(-0.72, 7.6, -0.48), 0.08, 0.1, 0.06, Vector3.new(0.8, 0, 0.6))
	S("wristL", P(-0.72, 7.6, -0.48), P(-0.64, 7.82, -0.58))
	chain("wristL", { P(-0.86, 7.7, -0.58), P(-0.66, 7.85, -0.68), P(-0.5, 7.7, -0.55) }) -- 기둥을 감은 손가락
	limb("shoulderR", P(0.68, 6.88, 0.0), P(0.9, 5.28, 0.12), 0.13, 0.14, 0.08, Vector3.new(0, 0, 1))
	limb("elbowR", P(0.9, 5.28, 0.12), P(0.94, 3.8, -0.06), 0.08, 0.1, 0.06, Vector3.new(0, 0, 1))
	S("wristR", P(0.94, 3.8, -0.06), P(0.97, 3.3, -0.14))
	S("wristR", P(0.92, 3.5, -0.16), P(0.96, 2.95, -0.24))
	S("wristR", P(0.98, 3.5, 0.0), P(1.0, 3.0, 0.02))
	-- 붉은 견인줄: 정수리 → 위 → 뒤로 늘어짐(3마디)
	S("cord0", P(0, 10.6, 0.0), P(0, 11.25, 0.35), true)
	S("cord1", P(0, 11.25, 0.35), P(0, 11.35, 2.4), true)
	S("cord2", P(0, 11.35, 2.4), P(0, 10.2, 4.6), true)
	local bones: { Rig.Bone } = {
		{ name = "pelvis", joint = P(0, 4.42, 0), tip = P(0, 5.0, 0) },
		{ name = "lumbar", parent = "pelvis", joint = P(0, 4.6, 0), tip = P(0, 5.85, 0) },
		{ name = "chest", parent = "lumbar", joint = P(0, 5.85, 0), tip = P(0, 7.05, 0) },
		{ name = "vest", parent = "chest", joint = P(0, 7.05, 0), tip = P(0, 7.33, 0) },
		{ name = "neck1", parent = "chest", joint = P(0, 7.05, 0), tip = P(0, 8.2, -0.12) },
		{ name = "neck2", parent = "neck1", joint = P(0, 8.2, -0.12), tip = P(0, 9.0, -0.05) },
		{ name = "neck3", parent = "neck2", joint = P(0, 9.0, -0.05), tip = P(0, 9.62, 0) },
		{ name = "head", parent = "neck3", joint = P(0, 9.62, 0), tip = P(0, 10.05, 0) },
		{ name = "crown", parent = "head", joint = P(0, 10.55, 0), tip = P(0, 10.6, 0) },
		{ name = "haloRing", parent = "head", joint = P(0, 9.95, 0.06), tip = P(0, 10.07, 0.06) },
		{ name = "cord0", parent = "crown", joint = P(0, 10.6, 0), tip = P(0, 11.25, 0.35) },
		{ name = "cord1", parent = "cord0", joint = P(0, 11.25, 0.35), tip = P(0, 11.35, 2.4) },
		{ name = "cord2", parent = "cord1", joint = P(0, 11.35, 2.4), tip = P(0, 10.2, 4.6) },
		{ name = "shoulderL", parent = "chest", joint = P(-0.68, 6.88, 0), tip = P(-1.12, 5.55, -0.45) },
		{ name = "elbowL", parent = "shoulderL", joint = P(-1.12, 5.55, -0.45), tip = P(-0.72, 7.6, -0.48) },
		{ name = "wristL", parent = "elbowL", joint = P(-0.72, 7.6, -0.48), tip = P(-0.64, 7.82, -0.58) },
		{ name = "shoulderR", parent = "chest", joint = P(0.68, 6.88, 0), tip = P(0.9, 5.28, 0.12) },
		{ name = "elbowR", parent = "shoulderR", joint = P(0.9, 5.28, 0.12), tip = P(0.94, 3.8, -0.06) },
		{ name = "wristR", parent = "elbowR", joint = P(0.94, 3.8, -0.06), tip = P(0.97, 3.0, -0.14) },
	}
	for _, s in { -1, 1 } do
		local n = if s < 0 then "L" else "R"
		table.insert(bones, { name = "hip" .. n, parent = "pelvis", joint = P(0.32 * s, 4.42, 0), tip = P(0.36 * s, 2.42, -0.2) })
		table.insert(bones, { name = "knee" .. n, parent = "hip" .. n, joint = P(0.36 * s, 2.42, -0.2), tip = P(0.36 * s, 0.6, 0.05) })
		table.insert(bones, { name = "ankle" .. n, parent = "knee" .. n, joint = P(0.36 * s, 0.6, 0.05), tip = P(0.36 * s, 0.02, -0.7) })
	end
	table.insert(bones, { name = "fixatorL", parent = "kneeL", joint = P(-0.36, 1.97, -0.14), tip = P(-0.36, 1.05, -0.01) })
	Rig.build(model, root, cf, {
		id = "c4h",
		bones = bones,
		lines = lines,
		balls = balls,
		floorY = FLOOR,
		mass = 0.9,
	})
	Rig.humanoid(model, HIP, M.cfg.WanderSpeed)
	return model
end

-- 점 p 에서 선분 ab 까지 수평 거리
local function flatDist(p: Vector3, a: Vector3, b: Vector3): number
	local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
	local l2 = ab:Dot(ab)
	local t = if l2 > 1e-4 then math.clamp(ap:Dot(ab) / l2, 0, 1) else 0
	return (ap - ab * t).Magnitude
end

function M.init(self: any)
	self.cdata.trail = { self.root.Position }
end

function M.tick(self: any, now: number): boolean
	local d = self.cdata
	-- 헤일로 울림: 1.2초 멈춤 → 접촉한 사람에게 감아 당기며 돌진
	if d.ringUntil then
		if now < d.ringUntil then
			self.hum.WalkSpeed = 0
			self.hum:MoveTo(self.root.Position)
			return true
		end
		local p, at = d.ringWho, d.ringAt
		d.ringUntil, d.ringWho, d.ringAt = nil, nil, nil
		if p and p.Parent and p:GetAttribute("Status") == "Alive" then
			self.cfg.ChaseSpeed = DASH_SPEED -- (이 괴물만: cfg 는 괴물마다 따로인 표)
			d.dashUntil = now + 3
			self:startChase(p, at)
		else
			self:setState(self.state)
		end
		return false
	end
	if d.dashUntil and now > d.dashUntil then
		d.dashUntil = nil
		self.cfg.ChaseSpeed = nil
		if self.state == "Chase" then
			self:setState("Chase")
		end
	end
	-- 지나온 길에 줄을 남긴다
	local trail: { Vector3 } = d.trail
	local my = self.root.Position
	if (my - trail[#trail]).Magnitude > TRAIL_STEP then
		table.insert(trail, my)
		if #trail > TRAIL_MAX then
			table.remove(trail, 1)
		end
	end
	if self.state == "Chase" or (d.nextRing and now < d.nextRing) or #trail < 4 then
		return false
	end
	-- 줄에 닿았나(몸 가까운 마지막 두 마디는 빼고): 수평 1.1 안, 줄 높이(발목~가슴) 안
	for _, pl in Players:GetPlayers() do
		if pl:GetAttribute("Status") == "Alive" and not pl:GetAttribute("Hidden") then
			local char = pl.Character
			local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r then
				local pp = r.Position
				for i = 1, #trail - 3 do
					local a, b = trail[i], trail[i + 1]
					if math.abs(pp.Y - (a.Y + b.Y) / 2) < 4 and flatDist(pp, a, b) < 1.1 then
						d.ringUntil = now + 1.2
						d.ringWho = pl
						d.ringAt = pp
						d.nextRing = now + 8
						self.model:SetAttribute("Ring", now)
						return true
					end
				end
			end
		end
	end
	return false
end

return M
