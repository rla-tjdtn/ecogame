--!strict
-- c10h 안내원 (10장 폐영화관 · 사람형) — 사양서: roster/v5/ch10/c10h_spec.md (+ QA1 수정 지시 반영)
-- 허리를 90° 숙인 인사 자세로 굳은 극장 안내원. 등은 탁자처럼 수평(높이 약 5.6), 높은 깃에서 가는 목이 아래로 늘어져
-- 얼굴 없는 길쭉한 머리가 가슴 밑에 매달린다. 왼손은 예절대로 등 위에 얹고, 오른손은 손가락이 붙은 '손전등 손'.
-- 눈 대신 손전등 끝에서 곧게 뻗은 붉은 선 한 줄이 시선이다(등받이 꼭대기 높이 ~3.4).
-- 뼈(이름 = 사양서처럼 끝 관절): pelvis → spine1 → spine2 → neck → head → headTip,  spine2 → shoulderR → elbowR → wristR → lensR,
--      spine2 → shoulderL → elbowL → wristL → handL,  pelvis → hipR/L → kneeR/L → ankleR/L → toeR/L,  pelvis → tailR/L
-- 공포 장치 「시선 선」: 서버가 손전등 위치에서 시선 방향으로 레이캐스트(30). 처음 맞는 것이 서 있는 플레이어면 들킴 →
--   일어서기(Rise, 0.4초) 후 추격. 등받이(3.4) 뒤에 웅크리면 레이가 등받이에 막혀 안전.
--   멈춰 있을 땐 상체를 ±40° 돌려 훑고(Aim 속성, 클라이언트가 같은 각도로 돌림), 소리가 나면 2초 동안 그쪽으로 빔을 돌린다.
--   배회 땐 1.4초 걷고 0.6초 멈추는 박자. (빔 길이를 맞은 곳까지 늘이는 것은 빠짐 — 보이는 붉은 선은 7 고정)
local Players = game:GetService("Players")
local Rig = require(script.Parent.Rig)

local M = {}
M.cfg = {
	WanderSpeed = 3.5,
	InvestigateSpeed = 6,
	ChaseSpeed = 9,
	AgentRadius = 1.4,
	AgentHeight = 7,
	CatchDistance = 3,
}
M.spawnLift = 3.2
M.voice = "1" -- (소리: 전용 소리 전까지 — 발 끌기 계열)

local HIP = 2
local FLOOR = -(HIP + 1)
local BEAM_RANGE = 30
local SWEEP = math.rad(40)
local function P(x: number, y: number, z: number): Vector3
	return Vector3.new(x, FLOOR + y, z)
end
local LENS = P(0.55, 3.47, -5.5)

function M.build(cf: CFrame): Model
	local model, root = Rig.shell("Usher", cf, Vector3.new(1.4, 2, 1.4))
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
	-- 다리: 몸통보다 확실히 가는 다리 + 바짓단 주름 + 구두
	for _, s in { -1, 1 } do
		local n = if s < 0 then "L" else "R"
		local hip, knee, ankle = P(0.42 * s, 5.05, 0), P(0.43 * s, 2.6, -0.35), P(0.42 * s, 0.32, 0.05)
		limb("knee" .. n, hip, knee, 0.2, 0.18, 0.11, Vector3.new(0.7 * s, 0, 0.7))
		limb("ankle" .. n, knee, ankle, 0.11, 0.13, 0.09, Vector3.new(0.7 * s, 0, 0.7))
		chain("toe" .. n, { ankle + Vector3.new(0, -0.3, 0.22), ankle + Vector3.new(0, -0.3, -0.85), ankle + Vector3.new(0, -0.12, -0.95) })
		S("toe" .. n, ankle + Vector3.new(0, 0.02, -0.1), ankle + Vector3.new(0, -0.14, -0.9))
		S("ankle" .. n, ankle + Vector3.new(-0.12 * s, 0.35, -0.08), ankle + Vector3.new(0.1 * s, 0.25, -0.12)) -- 바짓단 주름
	end
	S("pelvis", P(-0.55, 5.0, 0.15), P(0.55, 5.0, 0.15))
	-- 연미복 꼬리 2장(판: 두 줄씩)
	for _, s in { -1, 1 } do
		local n = if s < 0 then "L" else "R"
		S("tail" .. n, P(0.12 * s, 5.0, 0.35), P(0.2 * s, 3.55, 0.62))
		S("tail" .. n, P(0.42 * s, 5.0, 0.3), P(0.36 * s, 3.65, 0.58))
	end
	-- 수평 등(탁자): 등선 · 배선 · 옆선, 각진 어깨선 · 견장, 높은 깃(고리)
	chain("spine1", { P(0, 5.62, 0.25), P(0, 5.75, -1.1) })
	chain("spine2", { P(0, 5.75, -1.1), P(0, 5.72, -2.95) })
	chain("spine1", { P(0, 4.7, -0.15), P(0, 4.85, -1.2) })
	chain("spine2", { P(0, 4.85, -1.2), P(0, 5.0, -2.75) })
	for _, s in { -1, 1 } do
		chain("spine2", { P(0.62 * s, 5.25, -0.1), P(0.66 * s, 5.35, -1.6), P(0.84 * s, 5.5, -2.85) })
		S("spine2", P(0.84 * s, 5.58, -2.85), P(0.5 * s, 5.62, -3.25)) -- 각진 어깨 → 깃
		S("shoulder" .. (if s < 0 then "L" else "R"), P(0.62 * s, 5.68, -2.65), P(1.0 * s, 5.6, -2.95)) -- 견장
	end
	table.insert(lines, { bone = "spine2", a = P(0, 5.35, -3.12), b = P(0, 5.35, -3.17), r = 0.36, disc = true }) -- 높은 깃
	-- 매달린 가는 목 + 얼굴 없는 길쭉한 머리
	S("neck", P(-0.1, 5.25, -3.2), P(-0.07, 4.62, -3.32))
	S("neck", P(0.1, 5.25, -3.22), P(0.08, 4.62, -3.34))
	local hc = P(0, 3.95, -3.42)
	local sideH = { { 0.7, 0.1 }, { 0.5, -0.24 }, { -0.1, -0.3 }, { -0.68, -0.16 }, { -0.62, 0.2 }, { 0.1, 0.28 } }
	for i = 1, #sideH do
		local a, c = sideH[i], sideH[i % #sideH + 1]
		S("head", hc + Vector3.new(0, a[1], a[2]), hc + Vector3.new(0, c[1], c[2]))
	end
	local frontH = { { 0.7, -0.18 }, { 0.2, -0.3 }, { -0.66, -0.18 }, { -0.62, 0.18 }, { 0.2, 0.3 } }
	for i = 1, #frontH do
		local a, c = frontH[i], frontH[i % #frontH + 1]
		S("headTip", hc + Vector3.new(a[2], a[1], -0.05), hc + Vector3.new(c[2], c[1], -0.05))
	end
	-- 오른팔: 손전등 손(손가락이 붙어 대롱이 됨) + 끝 테 + 붉은 시선 선(손전등 끝에서 앞으로만)
	limb("elbowR", P(0.78, 5.48, -2.94), P(1.38, 4.62, -4.07), 0.13, 0.14, 0.09, Vector3.new(0.6, 0.8, 0))
	limb("wristR", P(1.38, 4.62, -4.07), P(0.55, 3.56, -4.6), 0.09, 0.1, 0.07, Vector3.new(0, 0.6, 0.8))
	S("lensR", P(0.47, 3.6, -4.6), P(0.47, 3.53, -5.45))
	S("lensR", P(0.63, 3.5, -4.6), P(0.63, 3.43, -5.45))
	table.insert(lines, { bone = "lensR", a = P(0.55, 3.47, -5.45), b = P(0.55, 3.47, -5.5), r = 0.13, disc = true })
	S("lensR", LENS, LENS + Vector3.new(0, -0.05, -7), true)
	-- 왼팔: 등 위에 얹은 손(손바닥이 등에 닿음)
	limb("elbowL", P(-0.78, 5.48, -2.94), P(-1.34, 6.2, -1.72), 0.13, 0.14, 0.09, Vector3.new(0, 0.8, 0.6))
	limb("wristL", P(-1.34, 6.2, -1.72), P(-0.15, 5.83, -1.02), 0.09, 0.1, 0.07, Vector3.new(0, 1, 0))
	chain("handL", { P(-0.15, 5.83, -1.12), P(0.45, 5.8, -0.88) })
	chain("handL", { P(-0.12, 5.82, -0.88), P(0.42, 5.8, -0.66) })
	S("handL", P(0.42, 5.8, -0.66), P(0.45, 5.8, -0.88))
	local bones: { Rig.Bone } = {
		{ name = "pelvis", joint = P(0, 5.05, 0), tip = P(0, 5.21, -1.05) },
		{ name = "spine1", parent = "pelvis", joint = P(0, 5.15, 0), tip = P(0, 5.21, -1.05) },
		{ name = "spine2", parent = "spine1", joint = P(0, 5.21, -1.05), tip = P(0, 5.41, -2.34) },
		{ name = "neck", parent = "spine2", joint = P(0, 5.35, -3.15), tip = P(0, 4.62, -3.33) },
		{ name = "head", parent = "neck", joint = P(0, 4.62, -3.33), tip = P(0, 3.3, -3.5) },
		{ name = "headTip", parent = "head", joint = P(0, 3.95, -3.42), tip = P(0, 3.25, -3.5) },
		{ name = "shoulderR", parent = "spine2", joint = P(0.2, 5.45, -2.8), tip = P(0.78, 5.48, -2.94) },
		{ name = "elbowR", parent = "shoulderR", joint = P(0.78, 5.48, -2.94), tip = P(1.38, 4.62, -4.07) },
		{ name = "wristR", parent = "elbowR", joint = P(1.38, 4.62, -4.07), tip = P(0.55, 3.56, -4.6) },
		{ name = "lensR", parent = "wristR", joint = P(0.55, 3.56, -4.6), tip = P(0.55, 3.47, -5.45) },
		{ name = "shoulderL", parent = "spine2", joint = P(-0.2, 5.45, -2.8), tip = P(-0.78, 5.48, -2.94) },
		{ name = "elbowL", parent = "shoulderL", joint = P(-0.78, 5.48, -2.94), tip = P(-1.34, 6.2, -1.72) },
		{ name = "wristL", parent = "elbowL", joint = P(-1.34, 6.2, -1.72), tip = P(-0.15, 5.83, -1.02) },
		{ name = "handL", parent = "wristL", joint = P(-0.15, 5.83, -1.02), tip = P(0.4, 5.82, -0.77) },
		{ name = "tailR", parent = "pelvis", joint = P(0.28, 5.0, 0.32), tip = P(0.28, 3.65, 0.6) },
		{ name = "tailL", parent = "pelvis", joint = P(-0.28, 5.0, 0.32), tip = P(-0.28, 3.65, 0.6) },
	}
	for _, s in { -1, 1 } do
		local n = if s < 0 then "L" else "R"
		table.insert(bones, { name = "hip" .. n, parent = "pelvis", joint = P(0, 5.05, 0), tip = P(0.42 * s, 5.05, 0) })
		table.insert(bones, { name = "knee" .. n, parent = "hip" .. n, joint = P(0.42 * s, 5.05, 0), tip = P(0.43 * s, 2.6, -0.35) })
		table.insert(bones, { name = "ankle" .. n, parent = "knee" .. n, joint = P(0.43 * s, 2.6, -0.35), tip = P(0.42 * s, 0.32, 0.05) })
		table.insert(bones, { name = "toe" .. n, parent = "ankle" .. n, joint = P(0.42 * s, 0.32, 0.05), tip = P(0.42 * s, 0.02, -0.95) })
	end
	Rig.build(model, root, cf, {
		id = "c10h",
		bones = bones,
		lines = lines,
		balls = balls,
		floorY = FLOOR,
		mass = 0.9,
	})
	Rig.humanoid(model, HIP, M.cfg.WanderSpeed)
	return model
end

function M.init(self: any)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { self.model }
	self.cdata.beamParams = rp
	self.cdata.aim = 0
	self.model:SetAttribute("Aim", 0)
end

local function playerOf(inst: Instance): Player?
	local m = inst:FindFirstAncestorOfClass("Model")
	while m do
		local p = Players:GetPlayerFromCharacter(m)
		if p then
			return p
		end
		m = m:FindFirstAncestorOfClass("Model")
	end
	return nil
end

function M.tick(self: any, now: number): boolean
	local d = self.cdata
	-- 일어서기(들킴) 0.4초 → 추격
	if d.riseUntil then
		if now < d.riseUntil then
			self.hum:MoveTo(self.root.Position)
			return true
		end
		local p: Player?, at: Vector3? = d.riseWho, d.riseAt
		d.riseUntil, d.riseWho, d.riseAt = nil, nil, nil
		if p and at and p.Parent and p:GetAttribute("Status") == "Alive" then
			self:startChase(p, at)
		else
			self:setState(self.state)
		end
		return false
	end
	local st = self.state
	-- 배회 박자: 1.4초 걷기 + 0.6초 멈춤(그동안 훑기). 평균 = WanderSpeed
	local still = false
	if st == "Wander" then
		local cyc = now % 2
		still = cyc >= 1.4
		self.hum.WalkSpeed = if still then 0 else M.cfg.WanderSpeed * 2 / 1.4
	end
	-- 빔 방향(상체 yaw): 소리 쪽 > 멈춰 훑기 > 정면
	local aim = 0
	if d.hearUntil and now < d.hearUntil and d.hearYaw then
		aim = d.hearYaw
	elseif st ~= "Chase" then
		local v = self.root.AssemblyLinearVelocity
		if still or Vector3.new(v.X, 0, v.Z).Magnitude < 1 then
			aim = SWEEP * math.sin(now * math.pi / 2) -- 4초에 한 번 왕복(한쪽 2초)
		end
	end
	d.aim = d.aim + (aim - d.aim) * 0.5
	local deg = math.floor(math.deg(d.aim) / 2 + 0.5) * 2
	if self.model:GetAttribute("Aim") ~= deg then
		self.model:SetAttribute("Aim", deg)
	end
	if st == "Chase" then
		return false
	end
	-- 시선 선: 손전등 끝에서 레이캐스트, 처음 맞은 것이 플레이어면 들킴
	local turn = self.root.CFrame * CFrame.Angles(0, math.rad(deg), 0)
	local from = turn:PointToWorldSpace(LENS)
	local dir = turn:VectorToWorldSpace(Vector3.new(0, -0.05 / 7, -1)).Unit
	local hit = workspace:Raycast(from, dir * BEAM_RANGE, d.beamParams)
	if hit then
		local p = playerOf(hit.Instance)
		if p and p:GetAttribute("Status") == "Alive" and not p:GetAttribute("Hidden") then
			d.riseUntil = now + 0.4
			d.riseWho = p
			d.riseAt = hit.Position
			self.model:SetAttribute("Rise", now)
			self.hum:MoveTo(self.root.Position)
			return true
		end
	end
	return false
end

-- 소리가 나면 2초 동안 상체와 빔을 그쪽으로(±70°까지). 기본 반응(조사)은 그대로
function M.hear(self: any, pos: Vector3, radius: number, _source: Player?, kind: string): boolean
	if kind == "Door" then
		return false
	end
	local my = self.root.Position
	if (pos - my).Magnitude > radius then
		return false
	end
	local v = self.root.CFrame:VectorToObjectSpace(pos - my)
	local d = self.cdata
	d.hearYaw = math.clamp(math.atan2(-v.X, -v.Z), -math.rad(70), math.rad(70))
	d.hearUntil = os.clock() + 2
	return false
end

return M
