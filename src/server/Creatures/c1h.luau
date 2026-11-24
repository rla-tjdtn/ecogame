--!strict
-- c1h 발맞춤 (1장 지하 시설 · 사람형) — 사양서: art/creatures/sheets/ch1/c1h_spec.md (+ QA1 수정 지시 반영)
-- 보행 동기화 실험의 피험체. 스스로 서지 못하는 몸을 외골격이 세운다: 골반 띠 → 등 뒤 세로 레일(척추를 클립으로 걺) →
-- 오른 어깨만 받치는 L 자 버팀대, 왼팔은 끈에 매달려 처짐. 두건 씌운 머리는 쐐기 받침·턱 걸쇠에 핀으로 박혀 천장을 본다.
-- 3차(최신): 공 머리 → 젖혀진 옆얼굴 + 턱 밑, 관절 마커 공·골반 고리 제거, 오른팔은 받침에 묶여 앞으로, 멈추면 무릎 높이로 발을 들고 숙인 채 굳음.
-- QA1: T 자 멍에(십자·허수아비) 대신 비대칭 L 버팀대 · 머리 고리(후광) 대신 쐐기 받침 — 정면에선 얼굴 없는 턱 밑과 목 앞면 ·
--      마커 공은 7개(골반·무릎·발목·손목)만 · 무릎은 캡슐이 아니라 슬개골 쐐기 + 버팀대 경첩 · 선 120 이하.
-- 뼈: HipRing → Pelvis → ThighL/R → ShinL/R → FootL/R,  Pelvis → Lumbar → Thorax → Neck,
--      HipRing → Rail → Yoke(L 버팀대) → UpperArmR → ForearmR → HandR,  Rail → UpperArmL(끈) → ForearmL → HandL,
--      Rail → Clamp(쐐기 받침) → Head,  Rail → Cable1 → Cable2 → Cable3(붉은 동기 케이블)
-- 붉은 선: 등 레일에서 바닥으로 끌리는 동기 케이블 한 줄.
-- 공포 장치 「발맞춤」: 가까운(50) 플레이어가 실제로 움직인 속도만큼만 움직인다(멈추면 같이 멈춤 — 한 발 든 채 굳는 건 클라이언트).
--   달리면 같이 빨라진다(상한 18). 멈춘 뒤 0.6초에 한 걸음 더(클라이언트). 3 안에서 머리 받침째 앞으로 꺾여 얼굴이 처음 보임.
--   (플레이어 발소리에 겹쳐 재생하는 0.12초 지연 발소리는 소리 담당 몫 — 빠짐)
local Players = game:GetService("Players")
local Rig = require(script.Parent.Rig)

local M = {}
M.cfg = {
	WanderSpeed = 6,
	InvestigateSpeed = 8,
	ChaseSpeed = 18,
	AgentRadius = 1.4,
	AgentHeight = 9,
	CatchDistance = 3,
}
M.spawnLift = 4.2
M.voice = "2" -- (소리: 전용 소리 전까지 — 맨발 걸음 계열)

local HIP = 3
local FLOOR = -(HIP + 1)
local RANGE = 50

local function P(x: number, y: number, z: number): Vector3
	return Vector3.new(x, FLOOR + y, z)
end

function M.build(cf: CFrame): Model
	local model, root = Rig.shell("InStep", cf, Vector3.new(1.6, 2, 1.2))
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
	-- 골반 띠(3차): 뒤쪽 반 고리 + 레일 용접 쐐기(정면에 고리가 안 보임) + 살 골반 쐐기
	chain("HipRing", { P(1, 4.1, 0.1), P(0.7, 4.1, 0.66), P(0, 4.1, 0.9), P(-0.7, 4.1, 0.66), P(-1, 4.1, 0.1) })
	chain("HipRing", { P(-0.2, 4.1, 0.9), P(0, 4.5, 0.95), P(0.2, 4.1, 0.9) })
	chain("Pelvis", { P(-0.55, 4.25, -0.2), P(0, 3.7, -0.35), P(0.55, 4.25, -0.2) })
	S("Pelvis", P(-0.55, 4.25, -0.2), P(0.55, 4.25, -0.2))
	-- 다리(안짱 무릎) + 바깥 버팀대(무릎 경첩·발목 고리) + 슬개골 쐐기 + 맨발
	for _, s in { -1, 1 } do
		local n = if s < 0 then "L" else "R"
		local hip, knee, ankle = P(0.45 * s, 3.95, 0), P(0.38 * s, 2.0, -0.15), P(0.45 * s, 0.3, 0.05)
		cone("Thigh" .. n, hip, knee, 0.24, 0.15, Vector3.new(s, 0, 0))
		cone("Shin" .. n, knee, ankle, 0.15, 0.09, Vector3.new(s, 0, 0))
		if s > 0 then -- 버팀대는 오른다리만(비대칭)
			S("ThighR", P(0.95, 4.05, 0.05), P(0.68, 2.0, -0.1))
			S("ShinR", P(0.68, 2.0, -0.1), P(0.64, 0.4, 0.05))
		end
		S("Shin" .. n, knee + Vector3.new(0, 0.2, -0.2), knee + Vector3.new(0, -0.25, -0.18)) -- 슬개골
		chain("Foot" .. n, { ankle + Vector3.new(0, -0.05, 0.25), ankle + Vector3.new(0, -0.25, 0.1), ankle + Vector3.new(0, -0.25, -0.75) })
	end
	-- 살 척추(앞으로 처짐) + 갈비 우리
	S("Lumbar", P(0, 4.2, 0.25), P(0, 5.55, 0.3))
	S("Thorax", P(0, 5.55, 0.3), P(0, 7.0, 0.2))
	for _, s in { -1, 1 } do
		S("Lumbar", P(0.5 * s, 4.3, 0.0), P(0.55 * s, 5.55, -0.1))
		chain("Thorax", { P(0.55 * s, 5.55, -0.1), P(0.7 * s, 6.4, -0.15), P(0.8 * s, 6.95, 0.05) })
		chain("Thorax", { P(0.15 * s, 6.35, -0.42), P(0.6 * s, 6.0, -0.25) }) -- 갈비
		chain("Thorax", { P(0.15 * s, 5.95, -0.4), P(0.55 * s, 5.6, -0.2) })
	end
	-- 목 앞면(턱 밑이 정면을 봄)
	for _, s in { -1, 1 } do
		S("Neck", P(0.22 * s, 6.95, 0.0), P(0.2 * s, 7.7, -0.15))
	end
	-- 등 뒤 세로 레일 + 척추 클립 2
	S("Rail", P(0, 4.1, 0.95), P(0, 8.9, 0.85))
	S("Rail", P(0, 5.0, 0.92), P(0, 5.0, 0.35))
	S("Rail", P(0, 6.5, 0.88), P(0, 6.5, 0.3))
	-- 오른 어깨만 받치는 L 버팀대, 왼팔을 매단 끈
	chain("Yoke", { P(0, 7.15, 0.85), P(1.05, 7.15, 0.75), P(1.12, 6.6, 0.1), P(1.15, 6.5, -1.2) })
	S("Rail", P(0, 7.35, 0.85), P(-0.9, 6.7, 0.15))
	-- 쐐기 받침(레일 꼭대기 → 이마) + 턱 걸쇠 + 핀 2, 두건 머리(뒤로 72° 젖혀 천장을 봄)
	local hc = P(0, 8.15, 0.35)
	chain("Clamp", { P(0, 8.9, 0.85), P(0, 8.75, 0.25), P(0, 8.5, -0.15) })
	chain("Clamp", { P(-0.32, 7.72, -0.32), P(0, 7.6, -0.45), P(0.32, 7.72, -0.32) })
	S("Clamp", P(-0.32, 7.72, -0.32), P(-0.42, 8.2, 0.3)) -- 걸쇠 옆 끈
	-- 젖혀진 옆얼굴(3차): 턱 → 입 → 코(위) → 이마 → 뒤통수. 정면에선 턱 밑 쐐기가 보인다
	local prof = {}
	for _, q in { { -0.12, -0.55 }, { 0.3, -0.62 }, { 0.36, -0.42 }, { 0.62, -0.1 }, { 0.46, 0.08 }, { 0.5, 0.45 }, { 0.05, 0.62 }, { -0.42, 0.28 }, { -0.12, -0.55 } } do
		table.insert(prof, hc + Vector3.new(0, q[1], q[2]))
	end
	chain("Head", prof)
	chain("Head", { hc + Vector3.new(-0.38, 0.1, 0.1), hc + Vector3.new(-0.22, -0.08, -0.45), hc + Vector3.new(0, -0.14, -0.58), hc + Vector3.new(0.22, -0.08, -0.45), hc + Vector3.new(0.38, 0.1, 0.1) }) -- 턱뼈(말굽)
	chain("Head", { hc + Vector3.new(-0.38, 0.1, 0.1), hc + Vector3.new(0, 0.5, 0.35), hc + Vector3.new(0.38, 0.1, 0.1) }) -- 두개 폭
	-- 팔: 오른팔은 버팀대에 묶여 늘어짐, 왼팔은 끈에 매달려 더 처짐. 손가락 쐐기 2
	local arms = {
		R = { P(1.1, 6.95, 0.05), P(1.15, 6.75, -1.25), P(1.1, 5.25, -1.35) }, -- (받침에 묶여 앞으로 뻗고 아래팔은 늘어짐)
		L = { P(-0.9, 6.6, 0.1), P(-1.0, 5.1, 0.05), P(-0.95, 3.6, -0.1) },
	}
	for n, a in arms do
		local s = if n == "L" then -1 else 1
		cone("UpperArm" .. n, a[1], a[2], 0.17, 0.11, Vector3.new(s, 0, 0))
		cone("Forearm" .. n, a[2], a[3], 0.11, 0.07, Vector3.new(s, 0, 0))
		S("Hand" .. n, a[3], a[3] + Vector3.new(0.05 * s, -0.7, -0.12))
		S("Hand" .. n, a[3], a[3] + Vector3.new(-0.08 * s, -0.55, 0.1))
	end
	-- 붉은 동기 케이블: 레일 뒤 → 바닥으로 끌림
	local cab = { P(0, 7.6, 1.45), P(0.1, 5.8, 1.6), P(0.15, 3.8, 1.75), P(0.1, 1.8, 2.1), P(0, 0.1, 2.8), P(0, 0.05, 3.8) }
	S("Rail", P(0, 7.5, 0.88), cab[1]) -- 케이블 받침대(레일 뒤로 0.6)
	chain("Cable1", { cab[1], cab[2], cab[3] }, true)
	chain("Cable2", { cab[3], cab[4], cab[5] }, true)
	chain("Cable3", { cab[5], cab[6] }, true)
	local bones: { Rig.Bone } = {
		{ name = "HipRing", joint = P(0, 4.1, 0.1), tip = P(0, 4.1, -0.9) },
		{ name = "Pelvis", parent = "HipRing", joint = P(0, 4.05, 0), tip = P(0, 3.75, 0) },
		{ name = "Lumbar", parent = "Pelvis", joint = P(0, 4.2, 0.25), tip = P(0, 5.55, 0.3) },
		{ name = "Thorax", parent = "Lumbar", joint = P(0, 5.55, 0.3), tip = P(0, 7.0, 0.2) },
		{ name = "Neck", parent = "Thorax", joint = P(0, 6.95, 0.1), tip = P(0, 7.7, -0.1) },
		{ name = "Rail", parent = "HipRing", joint = P(0, 4.1, 0.95), tip = P(0, 8.9, 0.85) },
		{ name = "Yoke", parent = "Rail", joint = P(0, 7.15, 0.85), tip = P(1.05, 7.15, 0.75) },
		{ name = "Clamp", parent = "Rail", joint = P(0, 7.95, 0.45), tip = P(0, 8.5, -0.15) },
		{ name = "Head", parent = "Clamp", joint = P(0, 7.95, 0.4), tip = hc },
		{ name = "UpperArmR", parent = "Yoke", joint = arms.R[1], tip = arms.R[2] },
		{ name = "UpperArmL", parent = "Rail", joint = arms.L[1], tip = arms.L[2] },
		{ name = "Cable1", parent = "Rail", joint = cab[1], tip = cab[3] },
		{ name = "Cable2", parent = "Cable1", joint = cab[3], tip = cab[5] },
		{ name = "Cable3", parent = "Cable2", joint = cab[5], tip = cab[6] },
	}
	for _, s in { -1, 1 } do
		local n = if s < 0 then "L" else "R"
		local a = arms[n]
		table.insert(bones, { name = "Forearm" .. n, parent = "UpperArm" .. n, joint = a[2], tip = a[3] })
		table.insert(bones, { name = "Hand" .. n, parent = "Forearm" .. n, joint = a[3], tip = a[3] + Vector3.new(0, -0.7, -0.1) })
		table.insert(bones, { name = "Thigh" .. n, parent = "Pelvis", joint = P(0.45 * s, 3.95, 0), tip = P(0.38 * s, 2.0, -0.15) })
		table.insert(bones, { name = "Shin" .. n, parent = "Thigh" .. n, joint = P(0.38 * s, 2.0, -0.15), tip = P(0.45 * s, 0.3, 0.05) })
		table.insert(bones, { name = "Foot" .. n, parent = "Shin" .. n, joint = P(0.45 * s, 0.3, 0.05), tip = P(0.45 * s, 0.05, -0.75) })
	end
	Rig.build(model, root, cf, {
		id = "c1h",
		bones = bones,
		lines = lines,
		balls = balls,
		floorY = FLOOR,
		mass = 0.8,
	})
	Rig.humanoid(model, HIP, M.cfg.WanderSpeed)
	return model
end

-- 가까운 플레이어(살아 있고 숨지 않음)의 실제 수평 속도
local function nearestSpeed(self: any): number?
	local my = self.root.Position
	local best: number?, bd = nil, RANGE
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Status") == "Alive" and not p:GetAttribute("Hidden") then
			local char = p.Character
			local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r then
				local dd = (r.Position - my).Magnitude
				if dd < bd then
					local v = r.AssemblyLinearVelocity
					best, bd = Vector3.new(v.X, 0, v.Z).Magnitude, dd
				end
			end
		end
	end
	return best
end

function M.tick(self: any, _now: number): boolean
	local d = self.cdata
	if self.state == "Alert" then
		d.sync = false
		return false
	end
	local sp = nearestSpeed(self)
	if sp then
		-- 발맞춤: 네가 걸은 만큼만 걷는다(멈추면 0)
		local want = if sp < 0.6 then 0 else math.clamp(sp, 0, M.cfg.ChaseSpeed)
		if self.hum.WalkSpeed ~= want then
			self.hum.WalkSpeed = want
		end
		d.sync = true
		self.model:SetAttribute("Sync", true)
	elseif d.sync then
		d.sync = false
		self.model:SetAttribute("Sync", false)
		self:setState(self.state) -- 원래 상태 속도로
	end
	return false
end

return M
