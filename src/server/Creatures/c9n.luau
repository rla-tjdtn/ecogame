--!strict
-- c9n 깔린 것 (9장 지하 주차장 · 비인간형) — 사양서: roster/v5/ch9/c9n_spec.md
-- 바닥에 오래 깔려 납작해진 몸(두께 0.6): 갈비가 부채처럼 펴져 뼈 끝이 비치는 들쭉날쭉한 판이 되었고,
-- 등을 비스듬히 타이어 자국(트레드 두 줄 + 마디)이 가로지른다. 앞으로 두 팔(다섯 손가락 손), 뒤로 두 다리가 납작하게 끌린다.
-- 옆으로 퍼진 두개골의 앞 가장자리 외곽선 자체가 붉은 입술(유일한 붉은 선) — 들리면 입이 벌어진다.
-- 뼈: spine0(골반) → spine1 → spine2 → spine3 → skull → lip / finL1..3·finR1..3(spine2, 옆 가장자리 물결 사슬)
--     armL→handL·armR→handR(spine3), legL→footL·legR→footR(spine0)
-- 공포 장치 「차 그늘」(차 밑 노드가 없어 '아무 데서나 매복'으로 단순화):
--   배회가 20초 이어지면 그 자리에 10초 엎드려 기다린다(Lurk 속성, 기본 AI 멈춤 — 지나가는 사람은 못 본 척).
--   기다리는 동안 누가 6 안에서 1초 넘게 (거의) 멈춰 서 있으면 입술을 들고 발목을 낚아챈다(Grab 속성 → 1초 튀어나옴 16 + 쫓기).
--   음파에 맞으면 3초 동안 납작해져 멈춘다(Flat 속성) — 타이어 자국과 붉은 호만 남는다. 매복도 풀린다.
local Players = game:GetService("Players")
local Rig = require(script.Parent.Rig)

local M = {}
M.cfg = {
	WanderSpeed = 6, -- 차 밑 미끄러짐
	InvestigateSpeed = 9, -- 통로 가로지르기
	ChaseSpeed = 13,
	AgentRadius = 1.6,
	AgentHeight = 2,
	CatchDistance = 3.2, -- (몸 앞으로 팔이 뻗어 있어 발목까지 닿는다)
}
M.spawnLift = 1.4
M.voice = "3" -- (소리: 전용 소리 전까지 '손톱 톡톡' 계열)

local HIP = 0.3
local FLOOR = -(HIP + 1)
local LURK_AFTER = 20
local LURK_TIME = 10
local FLAT_TIME = 3
local GRAB_R = 6
local LUNGE_SPEED, LUNGE_TIME = 16, 1

-- 판 위의 점(x 옆, z 앞 = -, h 바닥에서 높이)
local function V(x: number, z: number, h: number): Vector3
	return Vector3.new(x, FLOOR + h, z)
end

function M.build(cf: CFrame): Model
	local model, root = Rig.shell("Flat", cf, Vector3.new(1.2, 2, 1.2))
	local lines: { Rig.Line } = {}
	local balls: { Rig.Ball } = {}
	local bones: { Rig.Bone } = {}
	local function L(bone: string, a: Vector3, b: Vector3, r: number, red: boolean?)
		local len = (b - a).Magnitude
		local disc = len < 0.12
		table.insert(lines, { bone = bone, a = a, b = b, r = if disc then r else math.min(r, len / 4.2), red = red, disc = if disc then true else nil })
	end
	local function bone(name: string, parent: string?, joint: Vector3, tip: Vector3)
		table.insert(bones, { name = name, parent = parent, joint = joint, tip = tip })
	end
	local H = 0.3 -- 판 높이
	bone("spine0", nil, V(0, 2.9, H), V(0, 0.5, H))
	bone("spine1", "spine0", V(0, 0.5, H), V(0, -0.6, H))
	bone("spine2", "spine1", V(0, -0.6, H), V(0, -1.9, H))
	bone("spine3", "spine2", V(0, -1.9, H), V(0, -2.4, H))
	bone("skull", "spine3", V(0, -2.4, H), V(0, -2.85, H))
	bone("lip", "skull", V(0, -2.85, H + 0.05), V(0, -3.4, H + 0.05))
	for _, s in { { "L", -1 }, { "R", 1 } } do
		local n, sg = s[1] :: string, s[2] :: number
		bone("fin" .. n .. "1", "spine2", V(sg * 0.45, -0.3, H), V(sg * 1.3, -0.3, H))
		bone("fin" .. n .. "2", "fin" .. n .. "1", V(sg * 1.3, -0.3, H), V(sg * 1.85, -0.3, H))
		bone("fin" .. n .. "3", "fin" .. n .. "2", V(sg * 1.85, -0.3, H), V(sg * 2.3, -0.3, H))
	end
	-- 외곽: 갈비 끝이 비치는 들쭉날쭉한 판(한쪽 7획). 가장자리 점은 그 자리를 움직이는 뼈(어깨·지느러미·골반)에 붙는다
	local edge = {
		{ 0.9, -2.35, "spine3" },
		{ 1.95, -1.65, "spine3" },
		{ 1.75, -1.05, "fin?2" },
		{ 2.3, -0.45, "fin?3" },
		{ 1.95, 0.2, "fin?3" },
		{ 2.15, 0.95, "fin?2" },
		{ 1.35, 1.95, "spine0" },
		{ 0.55, 3.1, "spine0" },
	}
	for _, s in { { "L", -1 }, { "R", 1 } } do
		local n, sg = s[1] :: string, s[2] :: number
		-- 양옆이 같지 않게(깔린 몸은 대칭이 아니다): 쪽마다 뼈 끝이 다르게 비어져 나옴
		local jit = if sg > 0 then { 0, 0.14, -0.18, 0.12, -0.1, 0.16, 0.05, 0 } else { 0, -0.12, 0.1, -0.16, 0.18, -0.08, 0.12, 0 }
		local function ep(i: number): Vector3
			local e = edge[i]
			return V(sg * ((e[1] :: number) + jit[i]), (e[2] :: number) + jit[i] * 0.7, H)
		end
		for i = 1, #edge - 1 do
			local bn = string.gsub(edge[i][3] :: string, "%?", n)
			L(bn, ep(i), ep(i + 1), 0.08)
		end
		-- 갈비 넷: 등뼈에서 옆으로 펴져 가장자리 쪽으로(안쪽 지느러미 뼈에 붙어 물결과 함께 들림)
		for _, z in { -1.35, -0.65, 0.05, 0.75 } do
			L("fin" .. n .. "1", V(sg * 0.3, z, H + 0.05), V(sg * 1.45, z + 0.22, H + 0.03), 0.05)
		end
		-- 골반 뼈(납작하게 퍼짐)
		L("spine0", V(sg * 0.15, 2.3, H + 0.05), V(sg * 0.95, 2.75, H + 0.02), 0.06)
		-- 어깨(빗장뼈 자리) → 팔 뿌리
		L("spine3", V(sg * 0.15, -2.1, H + 0.05), V(sg * 0.9, -2.35, H + 0.02), 0.06)
	end
	L("spine0", V(0.55, 3.1, H), V(-0.55, 3.1, H), 0.06) -- 뒤 끝
	-- 등줄기(등뼈 고랑)
	L("spine0", V(0, 2.6, H + 0.06), V(0, 0.5, H + 0.06), 0.06)
	L("spine1", V(0, 0.5, H + 0.06), V(0, -0.6, H + 0.06), 0.06)
	L("spine2", V(0, -0.6, H + 0.06), V(0, -1.9, H + 0.06), 0.06)
	-- 타이어 자국: 등을 비스듬히 가로지르는 트레드 두 줄 + 사이의 마디 셋(바닥선과 각이 다르다)
	local t0, t1 = V(-1.9, 1.7, H + 0.04), V(1.7, -1.6, H + 0.04)
	local nrm = Vector3.new(1.7 - -1.9, 0, -1.6 - 1.7).Unit:Cross(Vector3.new(0, 1, 0)) * 0.55
	L("spine1", t0, t1, 0.05)
	L("spine1", t0 + nrm, t1 + nrm, 0.05)
	for _, f in { 0.25, 0.5, 0.75 } do
		L("spine1", t0:Lerp(t1, f), t0:Lerp(t1, f + 0.05) + nrm, 0.04)
	end
	-- 두개골: 옆으로 퍼진 납작한 타원. 뒤쪽 절반은 흰 외곽, 앞쪽 절반(앞 가장자리)이 붉은 입술 — 들리면 입이 벌어진다
	local SC = V(0, -2.85, H + 0.05)
	local function sk(deg: number): Vector3
		local a = math.rad(deg)
		return SC + Vector3.new(0.8 * math.cos(a), 0, 0.55 * math.sin(a))
	end
	for k = 0, 3 do
		L("skull", sk(k * 45), sk((k + 1) * 45), 0.06)
	end
	for k = 4, 7 do
		L("lip", sk(k * 45), sk((k + 1) * 45), 0.05, true)
	end
	-- 팔: 어깨 → 팔꿈치(납작) → 손목, 손바닥 + 다섯 손가락(바닥에 펴짐)
	for _, s in { { "L", -1 }, { "R", 1 } } do
		local n, sg = s[1] :: string, s[2] :: number
		local sh = V(sg * 0.9, -2.35, 0.14)
		local el = sh + Vector3.new(sg * 0.6, 0, -1.15)
		local wr = el + Vector3.new(sg * 0.5, -0.04, -1.25)
		bone("arm" .. n, "spine3", sh, el)
		bone("hand" .. n, "arm" .. n, el, wr + Vector3.new(sg * 0.2, 0, -0.9))
		L("arm" .. n, sh, el, 0.12)
		L("hand" .. n, el, wr, 0.1)
		local palm = wr + Vector3.new(sg * 0.12, 0, -0.38)
		L("hand" .. n, wr, palm, 0.09)
		for f = 1, 5 do
			local a = math.rad(-55 + (f - 1) * 26) -- 엄지(바깥 뒤) → 새끼
			local d = Vector3.new(sg * math.sin(a) * (if f == 1 then 1.3 else 0.6), 0, -math.cos(a))
			L("hand" .. n, palm, palm + d.Unit * (if f == 1 then 0.42 elseif f == 3 then 0.62 else 0.52), 0.035)
		end
	end
	-- 다리: 골반 → 무릎 → 납작하게 끌리는 발
	for _, s in { { "L", -1 }, { "R", 1 } } do
		local n, sg = s[1] :: string, s[2] :: number
		local hip = V(sg * 0.6, 2.85, 0.14)
		local kn = hip + Vector3.new(sg * 0.25, 0, 0.58)
		local ft = kn + Vector3.new(sg * 0.15, -0.04, 1.7)
		bone("leg" .. n, "spine0", hip, kn)
		bone("foot" .. n, "leg" .. n, kn, ft)
		L("leg" .. n, hip, kn, 0.12)
		L("foot" .. n, kn, ft - Vector3.new(0, 0, 0.4), 0.11)
		L("foot" .. n, ft - Vector3.new(0, 0, 0.4), ft + Vector3.new(sg * 0.12, 0, 0), 0.08)
	end
	Rig.build(model, root, cf, {
		id = "c9n",
		bones = bones,
		lines = lines,
		balls = balls,
		floorY = FLOOR,
		mass = 0.6,
	})
	Rig.humanoid(model, HIP, M.cfg.WanderSpeed)
	return model
end

function M.init(self: any)
	self.cdata.roamSince = os.clock()
	self.cdata.still = {}
end

local function restore(self: any)
	self:setState(self.state)
end

function M.tick(self: any, now: number): boolean
	local d = self.cdata
	-- 납작(음파): 멈춤
	if d.flatUntil then
		if now < d.flatUntil then
			self.hum:MoveTo(self.root.Position)
			return true
		end
		d.flatUntil = nil
		self.model:SetAttribute("Flat", false)
		d.roamSince = now
		restore(self)
	end
	-- 튀어나옴(발목 잡기): 1초 동안 빠르게, 그다음 기본 쫓기
	if d.lungeUntil then
		if now < d.lungeUntil and self.state == "Chase" then
			self.hum.WalkSpeed = LUNGE_SPEED
		else
			d.lungeUntil = nil
			restore(self)
		end
		return false
	end
	if d.lurkUntil then
		if now >= d.lurkUntil or self.state ~= "Wander" then
			d.lurkUntil = nil
			d.roamSince = now
			self.model:SetAttribute("Lurk", false)
			return false
		end
		self.hum:MoveTo(self.root.Position)
		-- 가까이(6) 1초 넘게 거의 멈춰 선 사람의 발목을 낚아챈다
		local my = self.root.Position
		for _, p in Players:GetPlayers() do
			local r: BasePart? = nil
			if p:GetAttribute("Status") == "Alive" and not p:GetAttribute("Hidden") and p.Character then
				r = p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			end
			local near = false
			if r then
				local q = r.Position
				local v = r.AssemblyLinearVelocity
				near = Vector3.new(q.X - my.X, 0, q.Z - my.Z).Magnitude < GRAB_R and math.abs(q.Y - my.Y) < 4 and Vector3.new(v.X, 0, v.Z).Magnitude < 4
			end
			if near and r then
				d.still[p] = d.still[p] or now
				if now - d.still[p] >= 1 then
					d.still = {}
					d.lurkUntil = nil
					self.model:SetAttribute("Lurk", false)
					self.model:SetAttribute("Grab", now)
					self:startChase(p, r.Position)
					d.lungeUntil = now + LUNGE_TIME
					self.hum.WalkSpeed = LUNGE_SPEED
					return false
				end
			else
				d.still[p] = nil
			end
		end
		return true
	end
	-- 배회가 이어지면 그 자리에 엎드려 기다린다
	if self.state ~= "Wander" then
		d.roamSince = now
	elseif now - d.roamSince > LURK_AFTER then
		d.lurkUntil = now + LURK_TIME
		d.still = {}
		self.model:SetAttribute("Lurk", true)
		self.hum:MoveTo(self.root.Position)
		return true
	end
	return false
end

-- 음파에 맞으면 납작해져 3초 멈춘다(매복도 풀림)
-- 음파에 "맞았는가": 파동이 퍼지는 거리(Config.Sonar.Radius 35) 안이고, 가깝거나(12) 사이가 트여 있음
local SONAR_REACH = 35
local function sonarHit(self: any, pos: Vector3, radius: number): boolean
	local d = (pos - self.root.Position).Magnitude
	if d > math.min(radius, SONAR_REACH) then
		return false
	end
	return d < 12 or self:lineOfSight(pos + Vector3.new(0, 1, 0))
end

function M.hear(self: any, pos: Vector3, radius: number, _source: any, kind: string): boolean
	if kind ~= "Sonar" or not sonarHit(self, pos, radius) then
		return false
	end
	local d = self.cdata
	if d.lurkUntil then
		d.lurkUntil = nil
		self.model:SetAttribute("Lurk", false)
	end
	d.lungeUntil = nil
	d.flatUntil = os.clock() + FLAT_TIME
	self.model:SetAttribute("Flat", true)
	self.hum:MoveTo(self.root.Position)
	return true
end

return M
