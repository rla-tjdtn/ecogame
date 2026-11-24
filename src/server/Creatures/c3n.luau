--!strict
-- c3n 홍예 (3장 하수도 · 비인간형) — 사양서: roster/v5/ch3/c3n_spec.md
-- 척추뼈 열한 개가 홍예(무지개다리)로 굳은 몸. 양 끝은 손이라 통로 두 벽을 짚고 걸쳐 있고(손목 사이 7),
-- 꼭대기 쐐기돌 자리에는 머리 대신 손 하나가 목뼈 세 마디에 매달려 있다. 바닥을 딛지 않는다.
-- 뼈: Root(아치 전체: 벽-벽 버팀 걸음의 회전·기울기) → Vert01..Vert11 사슬, HandA_Wrist(Vert01)·HandB_Wrist(Vert11),
--     Neck1..3(Vert06) → CrownHand. 다리·골반·머리 없음.
-- 공포 장치 「테 하나 더」: 한동안 배회하면 그 자리에서 아치 테처럼 굳는다(Mimic 속성, 기본 AI 멈춤).
--   굳은 동안 음파 1회는 무시(12 안이면 매달린 손이 움찔 — Reveal 속성), 2회째에 깨어나 10초 쫓는다.
--   그 밑(4.5 안)으로 지나가면 매달린 손이 내려와 붙잡는다(Grab 속성 → 쫓기 + 잡기 거리 3).
-- 라운드 처음 15초와 쫓은 직후에는 배회(기본 AI)라서 게임 흐름·테스트를 막지 않는다.
local Players = game:GetService("Players")
local Rig = require(script.Parent.Rig)

local M = {}
M.cfg = {
	WanderSpeed = 3.3, -- 버팀 걸음 한 주기(0.9초)에 3스터드
	InvestigateSpeed = 6,
	ChaseSpeed = 12, -- 몸 던지기가 섞인 버팀 걸음
	AgentRadius = 1.6,
	AgentHeight = 6,
	CatchDistance = 3, -- 아치 밑(매달린 손이 닿는 곳)
}
M.spawnLift = 2
M.voice = "1" -- (소리: 전용 소리 전까지 '머리 돌 때 뼈 소리' 계열 — 손 짚기 철썩 + 뼈 딱)

local HIP = 1
local FLOOR = -(HIP + 1)
local RC = 3.5 -- 아치 반지름(손목 사이 7)
local CY = 6.9 -- 아치 중심 높이(바닥 기준) → 꼭대기 10.4
local MIMIC_AFTER = 15 -- 배회가 이만큼 이어지면 굳는다
local AWAKE_TIME = 10
local UNDER = 4.5

-- 아치 위의 점: θ(도, 180 = 왼손, 0 = 오른손), 반지름 r, 앞뒤 z
local function A(deg: number, r: number, z: number?): Vector3
	local t = math.rad(deg)
	return Vector3.new(r * math.cos(t), FLOOR + CY + r * math.sin(t), z or 0)
end

function M.build(cf: CFrame): Model
	local model, root = Rig.shell("Arch", cf, Vector3.new(1, 2, 1))
	local lines: { Rig.Line } = {}
	local balls: { Rig.Ball } = {}
	local bones: { Rig.Bone } = {}
	local function L(bone: string, a: Vector3, b: Vector3, r: number, red: boolean?)
		-- 음파에서 원통은 한 획(Line)이고, 아주 짧은 것만 원 하나(Disc)다: 획이 원으로 바뀌지 않게 반지름을 길이에 맞춘다
		local len = (b - a).Magnitude
		local disc = len < 0.12
		table.insert(lines, { bone = bone, a = a, b = b, r = if disc then r else math.min(r, len / 4.2), red = red, disc = if disc then true else nil })
	end
	local function bone(name: string, parent: string?, joint: Vector3, tip: Vector3)
		table.insert(bones, { name = name, parent = parent, joint = joint, tip = tip })
	end
	local up = Vector3.new(0, 1, 0)
	bone("Root", nil, Vector3.new(0, FLOOR + CY, 0), A(90, RC))
	-- 척추 11마디: 끝 쪽이 가늘고 가운데가 굵다. 마디마다 둥근 추체(짧고 굵은 원통) + 원판 틈 + 바깥으로 뒤로 휜 가시돌기 + 앞뒤 가로돌기
	local N = 11
	local d0, d1 = 174, 6
	local step = (d0 - d1) / N
	local prev: string = "Root"
	for i = 1, N do
		local name = string.format("Vert%02d", i)
		local a0, a1 = d0 - (i - 1) * step, d0 - i * step
		local am = (a0 + a1) / 2
		local mid = math.abs(i - 6) / 5 -- 0 가운데 → 1 끝
		bone(name, prev, A(a0, RC), A(a1, RC))
		prev = name
		local cr = 0.36 - 0.07 * mid
		-- 인대 한 줄(마디끼리 끊김 없이 잇는 아치 중심선 — 정면에서 보면 테 하나) + 추체 둥근 테(원 하나)
		L(name, A(a0, RC), A(a1, RC), 0.12)
		L(name, A(am + 0.3, RC), A(am - 0.3, RC), cr)
		-- 가시돌기: 아치 바깥(등)으로 솟아 앞으로 휜 뿔, 가운데 마디가 가장 길다
		local spineLen = 0.75 - 0.3 * mid
		local base = A(am, RC + cr * 0.8)
		local tipP = A(am - 5, RC + cr * 0.8 + spineLen, -0.12)
		L(name, base, tipP, 0.08)
		-- 가로돌기: 앞뒤(±z)로 짧게, 끝이 살짝 위로
		for _, s in { -1, 1 } do
			L(name, A(am, RC + 0.05, s * cr * 0.7), A(am + 2, RC + 0.22, s * (cr + 0.38)), 0.06)
		end
	end
	-- 붉은 척수줄: 아치 안쪽(배)에서만, 마디 사이로 세 번 처지는 가는 줄 — 아래에서 올려다볼 때만 보인다
	do
		local idx = { 2, 4, 6, 8, 10 }
		local pts = {}
		for k, i in idx do
			local am = d0 - (i - 0.5) * step
			table.insert(pts, { at = A(am, RC - 0.42), bone = string.format("Vert%02d", i) })
			if k < #idx then
				local am2 = d0 - (i + 1.5) * step
				local sag = A((am + am2) / 2, RC - 0.62)
				table.insert(pts, { at = sag, bone = string.format("Vert%02d", i + 1) })
			end
		end
		for k = 1, #pts - 1 do
			L(pts[k].bone, pts[k].at, pts[k + 1].at, 0.045, true)
		end
	end
	-- 두 끝 손: 손목에서 바깥 아래로 꺾여 손바닥이 벽(x ±4.1)에 붙는다. 손가락 넷이 벽을 따라 부채꼴로 벌어짐
	local function wallHand(boneName: string, parent: string, side: number)
		local wrist = A(if side < 0 then d0 else d1, RC) -- (첫·끝 마디에 바로 이어짐)
		local palm = Vector3.new(side * 4.05, wrist.Y - 0.55, 0)
		bone(boneName, parent, wrist, palm)
		L(boneName, wrist, wrist:Lerp(palm, 0.5) + Vector3.new(side * 0.05, 0, 0), 0.19)
		L(boneName, wrist:Lerp(palm, 0.5) + Vector3.new(side * 0.05, 0, 0), palm, 0.16)
		for f = 1, 4 do
			local ang = math.rad(-40 + (f - 1) * 26) -- 벽면 위에서 손가락 방향(아래 → 앞뒤로 벌림)
			local dir = Vector3.new(0, -math.cos(ang), math.sin(ang))
			local len = if f == 2 or f == 3 then 0.62 else 0.52
			local k1 = palm + dir * len * 0.55 + Vector3.new(side * 0.06, 0, 0)
			local k2 = k1 + dir * len * 0.45 + Vector3.new(side * 0.02, 0, 0)
			L(boneName, palm, k1, 0.065)
			L(boneName, k1, k2, 0.045)
		end
		local th = palm + Vector3.new(-side * 0.1, 0.25, -0.32)
		L(boneName, wrist:Lerp(palm, 0.6), th, 0.06)
		L(boneName, th, th + Vector3.new(side * 0.05, 0.25, -0.18), 0.045)
	end
	wallHand("HandA_Wrist", "Vert01", -1)
	wallHand("HandB_Wrist", "Vert11", 1)
	-- 목뼈 세 마디: 쐐기돌 자리(Vert06 아래)에서 늘어진다
	local top = A(90, RC - 0.4)
	local nPrev = "Vert06"
	local y = top.Y
	for k = 1, 3 do
		local name = "Neck" .. k
		local j = Vector3.new(0, y, 0)
		bone(name, nPrev, j, j - up * 0.36)
		L(name, j - up * 0.05, j - up * 0.27, 0.2 - k * 0.02)
		L(name, j - up * 0.3, j - up * 0.34, 0.16) -- 원판
		nPrev = name
		y -= 0.36
	end
	-- 머리 대신 손: 목뼈에 비틀려 붙은 손목, 손바닥은 아래, 손가락 중 둘은 거꾸로(손등 쪽으로) 꺾였다
	local wj = Vector3.new(0, y, 0)
	local palm = wj + Vector3.new(0.12, -0.5, -0.1)
	bone("CrownHand", "Neck3", wj, palm - up * 0.5)
	L("CrownHand", wj, wj:Lerp(palm, 0.5) + Vector3.new(0.06, 0, 0), 0.17)
	L("CrownHand", wj:Lerp(palm, 0.5) + Vector3.new(0.06, 0, 0), palm, 0.2)
	local fingers = {
		{ d = Vector3.new(-0.26, -0.55, -0.18), bend = Vector3.new(-0.05, -0.32, -0.12) }, -- 엄지
		{ d = Vector3.new(-0.12, -0.6, 0.02), bend = Vector3.new(0, -0.38, 0.12) },
		{ d = Vector3.new(0.02, -0.62, 0.06), bend = Vector3.new(0.02, 0.1, 0.4) }, -- 거꾸로 꺾임
		{ d = Vector3.new(0.16, -0.58, 0.02), bend = Vector3.new(0.05, -0.36, 0.14) },
		{ d = Vector3.new(0.28, -0.48, -0.04), bend = Vector3.new(0.12, 0.12, 0.34) }, -- 거꾸로 꺾임
	}
	for _, f in fingers do
		local k1 = palm + f.d * 0.6
		L("CrownHand", palm, k1, 0.065)
		L("CrownHand", k1, k1 + f.bend * 0.8, 0.045)
	end
	table.insert(balls, { bone = "CrownHand", c = palm, r = 0.22 })
	table.insert(balls, { bone = "Vert06", c = A(90, RC - 0.32), r = 0.3 }) -- 목뼈가 붙는 쐐기돌 마디의 혹
	Rig.build(model, root, cf, {
		id = "c3n",
		bones = bones,
		lines = lines,
		balls = balls,
		floorY = FLOOR,
		mass = 0.7,
	})
	Rig.humanoid(model, HIP, M.cfg.WanderSpeed)
	return model
end

function M.init(self: any)
	local d = self.cdata
	d.mode = "roam"
	d.roamSince = os.clock()
	d.hits = 0
	d.awakeUntil = 0
end

local function wake(self: any, p: Player?, pos: Vector3?)
	local d = self.cdata
	d.mode = "awake"
	d.awakeUntil = os.clock() + AWAKE_TIME
	d.hits = 0
	self.model:SetAttribute("Mimic", false)
	if p and pos then
		self:startChase(p, pos)
	else
		self:setState("Wander")
	end
end

function M.tick(self: any, now: number): boolean
	local d = self.cdata
	if d.mode == "mimic" then
		self.hum:MoveTo(self.root.Position)
		-- 그 밑을 지나가는 사람: 매달린 손이 내려와 붙잡는다
		local my = self.root.Position
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("Status") == "Alive" and not p:GetAttribute("Hidden") then
				local char = p.Character
				local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if r then
					local q = r.Position
					local flat = Vector3.new(q.X - my.X, 0, q.Z - my.Z).Magnitude
					if flat < UNDER and math.abs(q.Y - my.Y) < 8 then
						self.model:SetAttribute("Grab", now)
						wake(self, p, q)
						return false
					end
				end
			end
		end
		return true
	end
	if d.mode == "awake" then
		if now >= d.awakeUntil and self.state ~= "Chase" then
			d.mode = "roam"
			d.roamSince = now
		end
		return false
	end
	-- 배회: 쫓거나 조사하는 동안은 시계를 되돌리고, 배회만 15초 이어지면 그 자리에서 테처럼 굳는다
	if self.state ~= "Wander" then
		d.roamSince = now
	elseif now - d.roamSince > MIMIC_AFTER then
		d.mode = "mimic"
		d.hits = 0
		self.model:SetAttribute("Mimic", true)
		self.hum:MoveTo(self.root.Position)
		return true
	end
	return false
end

-- 음파에 "맞았는가": 파동이 퍼지는 거리(Config.Sonar.Radius 35) 안이고, 가깝거나(12) 사이가 트여 있음
local SONAR_REACH = 35
local function sonarHit(self: any, pos: Vector3, radius: number): boolean
	local d = (pos - self.root.Position).Magnitude
	if d > math.min(radius, SONAR_REACH) then
		return false
	end
	return d < 12 or self:lineOfSight(pos + Vector3.new(0, 1, 0))
end

function M.hear(self: any, pos: Vector3, radius: number, source: Player?, kind: string): boolean
	local d = self.cdata
	if d.mode ~= "mimic" then
		return false
	end
	if kind == "Sonar" and sonarHit(self, pos, radius) then
		d.hits += 1
		if (pos - self.root.Position).Magnitude < 12 then
			self.model:SetAttribute("Reveal", os.clock())
		end
		if d.hits >= 2 then
			wake(self, source, pos)
		end
	end
	return true -- 굳은 동안은 다른 소리에 끌려가지 않는다
end

return M
