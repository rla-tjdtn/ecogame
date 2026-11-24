--!strict
-- c1n 청음체 (1장 지하 시설 · 비인간형) — 사양서: roster/v5/ch1/c1n_spec.md (+ QA1 수정 지시 반영)
-- "소리를 더 잘 듣는 몸": 사람 가슴을 갈라 척추만 세우고 갈비를 젖혀 귀바퀴 접시로, 심장 자리에 고막.
-- 다리는 사람 팔 셋(손바닥으로 딛음) — 하나를 들어 바깥으로 크게 돌려 딛으며 몸통이 도는 회전 삼각 보행.
-- QA1: 우산·파라솔 금지 → 갈비 끝이 앞·아래로 말린 깔때기(조개) — 정면에서 벌어진 구멍 · 갈비 14 → 9, 길이·곡률 제각각,
--      비대칭(왼쪽 2개 결손, 오른쪽 R5 크게 부러져 처짐) · 채운 막 대신 막 테두리 한 줄 + 붉은 세로 틈 고막 ·
--      다리는 '팔'로: 팔꿈치가 바깥으로 꺾이고 손목을 젖혀 손바닥 전체로 딛음 · 퇴화한 팔은 하나만(목뼈를 감아쥠).
-- 뼈: Hub → HipA/B/C → ArmA/B/C → ForeA/B/C → HandA/B/C,  Hub → Neck1 → Neck2 → Neck3 → Dish → Ear(고막), Dish → RibL / RibR,
--      Hub → Vest → VestFore(목뼈를 쥔 퇴화한 팔)
-- 붉은 선: 고막(세로로 찢어진 틈 모양 고리 하나).
-- 공포 장치 「겨누는 접시」: 발소리는 못 듣는다(걸음 소리 무시). 40 안의 음파 → 0.8초에 접시를 그쪽으로 겨누고 4초 동안 '듣는 중'
--   (제자리, Listening 속성 + AimAt). 이때 접시 정면 ±35° 안에서 또 쏘면 위치 확정 → 추격, 3 안에서 돌진(22).
--   옆·뒤에서 쏜 음파는 안전(무시).
local Rig = require(script.Parent.Rig)

local M = {}
M.cfg = {
	WanderSpeed = 6,
	InvestigateSpeed = 8,
	ChaseSpeed = 12,
	AgentRadius = 1.6,
	AgentHeight = 8,
	CatchDistance = 2.8,
}
M.spawnLift = 2.8
M.voice = "3" -- (소리: 전용 소리 전까지 — 손바닥 짚는 톡톡 계열)

local HIP = 1.6
local FLOOR = -(HIP + 1)
local HUB = 2.5
local LISTEN = 4.8 -- 겨눔 0.8 + 듣기 4
local CONE = math.cos(math.rad(35))
M.legs = { A = 60, B = -60, C = 180 } -- 다리 방향(도, 0 = 앞 −Z, + = 오른쪽)

local function P(x: number, y: number, z: number): Vector3
	return Vector3.new(x, FLOOR + y, z)
end
local function dir(deg: number): Vector3
	local t = math.rad(deg)
	return Vector3.new(math.sin(t), 0, -math.cos(t))
end

function M.build(cf: CFrame): Model
	local model, root = Rig.shell("Listener", cf, Vector3.new(1.6, 2, 1.6))
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
	local function cone(bone: string, a: Vector3, b: Vector3, wa: number, wb: number, side: Vector3)
		local d = (b - a).Unit
		local off = (side - d * side:Dot(d)).Unit
		for _, k in { -1, 1 } do
			S(bone, a + off * (wa * k), b + off * (wb * k))
		end
	end
	local hub = P(0, HUB, 0)
	-- 매듭(골반+흉골)
	table.insert(balls, { bone = "Hub", c = hub, r = 0.45 })
	chain("Hub", { hub + Vector3.new(-0.5, -0.2, 0.2), hub + Vector3.new(0, -0.55, 0.05), hub + Vector3.new(0.5, -0.2, 0.2) })
	local bones: { Rig.Bone } = {
		{ name = "Hub", joint = hub, tip = hub + Vector3.new(0, 0.8, 0) },
	}
	-- 다리 셋 = 사람 팔: 위팔은 바깥·위로(팔꿈치가 무릎처럼 솟음), 아래팔은 거의 수직, 손목을 젖혀 손바닥 전체로 딛음
	for name, deg in M.legs do
		local u = dir(deg)
		local side = Vector3.yAxis:Cross(u)
		local sh = hub + u * 0.4
		local el = P(0, 3.0, 0) + u * 1.55
		local wr = P(0, 0.35, 0) + u * 2.05
		cone("Arm" .. name, sh, el, 0.2, 0.14, side)
		cone("Fore" .. name, el, wr, 0.14, 0.09, side)
		-- 손바닥 판(바깥으로 젖힘) + 손가락 3(마디가 솟음)
		local palm = wr + u * 0.45 + Vector3.new(0, -0.3, 0)
		chain("Hand" .. name, { wr + side * 0.2, palm + side * 0.25, palm - side * 0.25, wr - side * 0.2 })
		for i = -1, 1 do
			local f0 = palm + side * (0.2 * i)
			local f1 = f0 + u * 0.3 + side * (0.08 * i) + Vector3.new(0, 0.15, 0)
			chain("Hand" .. name, { f0, f1, f1 + u * 0.3 + side * (0.05 * i) + Vector3.new(0, -0.16, 0) })
		end
		table.insert(bones, { name = "Hip" .. name, parent = "Hub", joint = hub, tip = sh })
		table.insert(bones, { name = "Arm" .. name, parent = "Hip" .. name, joint = sh, tip = el })
		table.insert(bones, { name = "Fore" .. name, parent = "Arm" .. name, joint = el, tip = wr })
		table.insert(bones, { name = "Hand" .. name, parent = "Fore" .. name, joint = wr, tip = palm })
	end
	-- 목뼈 3마디 + 접시 척추
	local n1, n2, n3, dtop = P(0, 3.25, 0.05), P(0, 3.7, 0.05), P(0, 4.15, 0.0), P(0, 7.6, 0.15)
	S("Neck1", hub + Vector3.new(0, 0.45, 0), n1)
	S("Neck2", n1, n2)
	S("Neck3", n2, n3)
	chain("Dish", { n3, P(0, 5.0, 0.1), P(0, 5.9, 0.18), P(0, 6.8, 0.2), dtop })
	-- 갈비 9개: 등(척추)에서 옆으로 → 앞·아래로 말려 깔때기(정면에 구멍). 왼쪽은 2개 결손, 오른쪽 R5 는 부러져 처짐
	local ribs = {
		{ -1, 7.2, 1.3 }, { -1, 6.55, 2.1 }, { -1, 5.4, 2.4 }, { -1, 4.75, 1.6 },
		{ 1, 7.3, 1.2 }, { 1, 6.75, 1.9 }, { 1, 6.15, 2.5 }, { 1, 5.55, 2.2 }, { 1, 4.9, 1.7 },
	}
	for i, r in ribs do
		local s, y, w = r[1], r[2], r[3]
		local bone = if s < 0 then "RibL" else "RibR"
		local a = P(0.12 * s, y, 0.2)
		local b = P(w * s, y + 0.35, 0.35)
		local c = P(w * 0.95 * s, y - 0.15, -1.0 - w * 0.15)
		local tip = P(w * 0.55 * s, y - 0.75, -1.45 - w * 0.2)
		if i == 9 then
			c = P(w * 1.05 * s, y - 0.6, -0.2)
			tip = P(w * 1.1 * s, y - 1.6, -0.55) -- R5: 부러져 아래로 처짐
		end
		chain(bone, { a, b, c, tip })
	end
	-- 막 테두리(흉골 잔해에서 갈비 안쪽으로 당겨진 얇은 막) + 붉은 고막(세로로 찢어진 틈)
	local rim, ear = {}, {}
	for k = 0, 6 do
		local t = k / 6 * math.pi * 2
		table.insert(rim, P(math.sin(t) * 0.75, 5.95 + math.cos(t) * 1.35, -0.35))
		table.insert(ear, P(math.sin(t) * 0.16, 5.95 + math.cos(t) * 0.65, -0.42))
	end
	chain("Dish", rim)
	chain("Ear", ear, true)
	-- 퇴화한 팔 하나: 매듭 옆에서 올라와 손가락이 목뼈를 감아쥠
	local ve0, ve1, ve2 = hub + Vector3.new(-0.45, 0.15, 0.15), P(-0.85, 3.4, 0.3), P(-0.15, 3.55, 0.05)
	S("Vest", ve0, ve1)
	S("VestFore", ve1, ve2)
	for _, k in { -1, 0, 1 } do
		S("VestFore", ve2 + Vector3.new(0, 0.12 * k, 0), ve2 + Vector3.new(0.3, 0.12 * k - 0.05, -0.2))
	end
	for _, bdef in {
		{ name = "Neck1", parent = "Hub", joint = hub + Vector3.new(0, 0.45, 0), tip = n1 },
		{ name = "Neck2", parent = "Neck1", joint = n1, tip = n2 },
		{ name = "Neck3", parent = "Neck2", joint = n2, tip = n3 },
		{ name = "Dish", parent = "Neck3", joint = n3, tip = dtop },
		{ name = "Ear", parent = "Dish", joint = P(0, 5.95, -0.38), tip = P(0, 6.25, -0.42) },
		{ name = "RibL", parent = "Dish", joint = P(-0.12, 6.0, 0.2), tip = P(-2.0, 6.0, -1.0) },
		{ name = "RibR", parent = "Dish", joint = P(0.12, 6.0, 0.2), tip = P(2.0, 6.0, -1.0) },
		{ name = "Vest", parent = "Hub", joint = ve0, tip = ve1 },
		{ name = "VestFore", parent = "Vest", joint = ve1, tip = ve2 },
	} :: { Rig.Bone } do
		table.insert(bones, bdef)
	end
	Rig.build(model, root, cf, {
		id = "c1n",
		bones = bones,
		lines = lines,
		balls = balls,
		floorY = FLOOR,
		mass = 0.8,
	})
	Rig.humanoid(model, HIP, M.cfg.WanderSpeed)
	return model
end

function M.init(self: any)
	self.cdata.listenUntil = 0
	self.model:SetAttribute("Listening", false)
end

function M.tick(self: any, now: number): boolean
	local d = self.cdata
	if d.listenUntil > 0 then
		if now < d.listenUntil and self.state ~= "Chase" then
			self.hum:MoveTo(self.root.Position) -- 듣는 동안 제자리
			return true
		end
		d.listenUntil = 0
		self.model:SetAttribute("Listening", false)
	end
	if self.state == "Chase" then
		local t: Player? = self.target
		local char = t and t.Character
		local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local close = r ~= nil and (r.Position - self.root.Position).Magnitude < 4
		local want = if close then 22 else M.cfg.ChaseSpeed -- 마지막 3 스터드 돌진
		if self.hum.WalkSpeed ~= want then
			self.hum.WalkSpeed = want
		end
	end
	return false
end

function M.hear(self: any, pos: Vector3, _radius: number, source: Player?, kind: string): boolean
	if string.sub(kind, 1, 4) == "Step" then
		return true -- 걸음 소리는 못 듣는다
	end
	if kind ~= "Sonar" then
		return false
	end
	local my = self.root.Position
	local to = Vector3.new(pos.X - my.X, 0, pos.Z - my.Z)
	if to.Magnitude > 40 then
		return false
	end
	local d = self.cdata
	local now = os.clock()
	if d.listenUntil > 0 and now < d.listenUntil then
		-- 듣는 중: 접시 정면 ±35° 안에서 다시 쏘면 들킴
		if source and to.Magnitude > 0.5 and d.aimDir and to.Unit:Dot(d.aimDir) >= CONE then
			d.listenUntil = 0
			self.model:SetAttribute("Listening", false)
			self:startChase(source, pos)
		end
		return true
	end
	if self.state == "Chase" then
		return false
	end
	d.aimDir = if to.Magnitude > 0.5 then to.Unit else self.root.CFrame.LookVector
	d.listenUntil = now + LISTEN
	self.model:SetAttribute("AimAt", pos)
	self.model:SetAttribute("Listening", true)
	return true
end

return M
