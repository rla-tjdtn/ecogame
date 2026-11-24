--!strict
-- c3h 마개 (3장 하수도 · 사람형) — 사양서: roster/v5/ch3/c3h_spec.md (+ QA1 수정 지시 반영)
-- 배수관 원형 해치(지름 4.3 주철판)를 갈비 버팀으로 가슴에 붙인 채 짐꾼처럼 무릎을 굽혀 걷는 사람.
-- 정면: 원판(무늬 없이 격자 2줄 + 금 한 줄) + 테 아래쪽을 움켜쥔 손가락 + 테 밖으로 파고든 갈비 끝 + 테 아래로 처진 턱 + 맨발.
-- 뼈: Pelvis → Spine → NeckRod → Hatch → HatchRim / EyeSlit,  Spine → ClavicleL/R → UpperArm → Forearm → RimGrip,
--      Pelvis → Thigh → Shin → Foot → Toe.  머리 뼈 없음(머리는 해치 뒤에 눌려 NeckRod 에 붙음).
-- 공포 장치 「막음」(간단판): 음파에 맞으면 0.4초 멈칫(Brace) → 그 방향으로 해치를 세우고 3칸(24) 직진 돌진(9).
--   (해치 뒤로 음파가 통과하지 않는 규칙은 음파 렌더러 쪽 일이라 여기서는 빠짐)
local Rig = require(script.Parent.Rig)

local M = {}
M.cfg = {
	WanderSpeed = 4,
	InvestigateSpeed = 7,
	ChaseSpeed = 10,
	AgentRadius = 1.8,
	AgentHeight = 7,
	CatchDistance = 3.2,
}
M.spawnLift = 3.2
M.voice = "2" -- (소리: 전용 소리 전까지 나무 삐걱 계열)

local HIP = 2
local FLOOR = -(HIP + 1)
local CHARGE_SPEED = 9
local CHARGE_DIST = 24
local function P(x: number, y: number, z: number): Vector3
	return Vector3.new(x, FLOOR + y, z)
end
local HC = P(0, 4.5, -1.0) -- 해치 중심(앞면 z -1.18)
local HR = 2.15
local function rim(deg: number, r: number?, z: number?): Vector3
	-- 시계 위치처럼: 0° = 12시, 90° = 3시(+X)
	local t = math.rad(deg)
	local rr = r or HR
	return Vector3.new(HC.X + rr * math.sin(t), HC.Y + rr * math.cos(t), z or -1.18)
end

function M.build(cf: CFrame): Model
	local model, root = Rig.shell("Plug", cf, Vector3.new(2, 2, 1.6))
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
	-- 팔다리: 대각선 방향 외곽 두 줄(정면·옆 모두 폭이 보임), 관절에서 좁아짐
	local function limb(bone: string, a: Vector3, b: Vector3, wa: number, wm: number, wb: number, side: Vector3)
		local d = (b - a).Unit
		local off = (side - d * side:Dot(d)).Unit
		local m = a:Lerp(b, 0.4)
		for _, k in { -1, 1 } do
			chain(bone, { a + off * (wa * k), m + off * (wm * k), b + off * (wb * k) })
		end
	end
	-- 해치: 앞·뒤 테(원 두 개), 주철 격자 2줄, 리벳 3, 금 한 줄(지그재그), 금 틈 속 붉은 눈 하나
	table.insert(lines, { bone = "HatchRim", a = P(0, 4.5, -1.2), b = P(0, 4.5, -1.16), r = HR, disc = true })
	table.insert(lines, { bone = "HatchRim", a = P(0, 4.5, -0.84), b = P(0, 4.5, -0.8), r = HR - 0.1, disc = true })
	table.insert(lines, { bone = "Hatch", a = P(0, 4.5, -1.21), b = P(0, 4.5, -1.19), r = HR - 0.32, disc = true })
	S("Hatch", rim(-62, HR - 0.32, -1.2), rim(62, HR - 0.32, -1.2))
	S("Hatch", rim(-118, HR - 0.32, -1.2), rim(118, HR - 0.32, -1.2))
	for _, deg in { 20, 140, 260 } do
		local c = rim(deg, HR - 0.16, -1.22)
		table.insert(lines, { bone = "HatchRim", a = c, b = c - Vector3.new(0, 0, 0.03), r = 0.07, disc = true })
	end
	chain("Hatch", { rim(185, HR - 0.32, -1.21), P(0.18, 3.25, -1.21), P(-0.12, 3.75, -1.21), P(0.1, 4.25, -1.21), P(-0.05, 4.7, -1.21) })
	table.insert(balls, { bone = "EyeSlit", c = P(0.04, 3.52, -1.12), r = 0.09, red = true })
	-- 몸통: 등선·배선·옆선(짐꾼처럼 앞으로 숙임), 쇄골
	chain("Spine", { P(0, 3.0, 0.62), P(0, 3.9, 0.66), P(0, 4.75, 0.38), P(0, 5.05, 0.05) })
	chain("Spine", { P(0, 3.0, 0.02), P(0, 3.85, -0.22), P(0, 4.55, -0.42) })
	for _, s in { -1, 1 } do
		chain("Spine", { P(0.5 * s, 3.05, 0.35), P(0.55 * s, 3.9, 0.3), P(0.78 * s, 4.75, 0.15) })
		S("Clavicle" .. (if s < 0 then "L" else "R"), P(0.12 * s, 4.85, 0.05), P(0.82 * s, 4.75, 0.12))
	end
	S("Pelvis", P(-0.52, 3.0, 0.3), P(0.52, 3.0, 0.3)) -- 골반 띠
	-- 갈비 버팀 6개(가슴 → 해치 뒷면), 그중 3개는 끝이 테 밖으로 파고든다
	for i, s in { -1, 1, -1, 1, -1, 1 } do
		local y = 3.7 + math.floor((i - 1) / 2) * 0.42
		local reach = if i <= 3 then 1.0 else 0.75
		S("Spine", P(0.32 * s, y, -0.2), P(reach * s * 1.2, y + 0.25, -0.82))
	end
	S("Hatch", rim(112, HR - 0.05, -0.9), rim(108, HR + 0.32, -0.95)) -- 테 밖으로 나온 갈비 끝
	S("Hatch", rim(-104, HR - 0.05, -0.9), rim(-100, HR + 0.28, -0.95))
	S("Hatch", rim(236, HR - 0.05, -0.9), rim(232, HR + 0.25, -0.95))
	-- 목 막대 → 해치 뒤에 눌린 머리: 턱만 테 아래로 처져 나온다 + 젖은 머리카락 2가닥
	chain("NeckRod", { P(0, 5.0, 0.0), P(0, 4.3, -0.45), P(0, 3.0, -0.62) })
	chain("NeckRod", { P(-0.34, 2.75, -0.78), P(-0.22, 2.12, -0.86), P(0.02, 1.98, -0.9), P(0.24, 2.14, -0.86), P(0.34, 2.72, -0.78) })
	S("NeckRod", P(-0.12, 2.22, -0.92), P(0.12, 2.25, -0.92)) -- 다문 입
	S("NeckRod", P(-0.4, 2.6, -0.7), P(-0.5, 1.55, -0.72))
	S("NeckRod", P(0.38, 2.55, -0.7), P(0.44, 1.75, -0.7))
	-- 팔: 쇄골 → 팔꿈치(테 옆, 3·9시보다 낮게) → 손목(4~5시, 7~8시 테 앞) → 손가락 4개(길이·각도 다르게, 한 마디 꺾임)
	for _, s in { -1, 1 } do
		local n = if s < 0 then "L" else "R"
		local sh, el, wr = P(0.82 * s, 4.75, 0.12), P(2.5 * s, 4.05, -0.3), P(1.72 * s, 2.86, -1.12)
		limb("UpperArm" .. n, sh, el, 0.16, 0.2, 0.1, Vector3.new(0, 0.7, 0.7))
		limb("Forearm" .. n, el, wr, 0.11, 0.15, 0.08, Vector3.new(0, 0.6, -0.8))
		for f = 0, 3 do
			local base = rim(180 - s * (118 + f * 9), HR + 0.06, -1.24)
			local len = ({ 0.42, 0.52, 0.48, 0.36 })[f + 1]
			local inward = (HC - base) * Vector3.new(1, 1, 0)
			local mid = base + inward.Unit * (len * 0.62) + Vector3.new(0, 0, -0.02)
			S("RimGrip" .. n, wr + (base - wr) * 0.2, base)
			S("RimGrip" .. n, base, mid + inward.Unit:Cross(Vector3.zAxis) * (0.05 * s))
		end
	end
	-- 다리: 길고 마른 다리, 깊게 굽은 무릎(짐꾼 하중), 맨발 + 발가락
	for _, s in { -1, 1 } do
		local n = if s < 0 then "L" else "R"
		local hip, knee, ankle = P(0.36 * s, 3.0, 0.32), P(0.4 * s, 1.55, -0.58), P(0.34 * s, 0.3, 0.18)
		limb("Thigh" .. n, hip, knee, 0.2, 0.22, 0.1, Vector3.new(0.6 * s, 0, 0.8))
		limb("Shin" .. n, knee, ankle, 0.1, 0.13, 0.06, Vector3.new(0.6 * s, 0, 0.8))
		S("Shin" .. n, knee + Vector3.new(0, 0.12, -0.12), knee + Vector3.new(0, -0.2, -0.12)) -- 무릎뼈
		chain("Foot" .. n, { ankle + Vector3.new(0, -0.05, 0.22), ankle + Vector3.new(0, -0.26, 0.05), ankle + Vector3.new(0, -0.26, -0.52) })
		S("Foot" .. n, ankle + Vector3.new(0, 0.05, 0), ankle + Vector3.new(0, -0.12, -0.52))
		S("Toe" .. n, ankle + Vector3.new(0, -0.24, -0.52), ankle + Vector3.new(0.02 * s, -0.28, -0.82))
	end
	local bones: { Rig.Bone } = {
		{ name = "Pelvis", joint = P(0, 3.0, 0.32), tip = P(0, 3.3, 0.32) },
		{ name = "Spine", parent = "Pelvis", joint = P(0, 3.1, 0.32), tip = P(0, 4.8, 0.05) },
		{ name = "NeckRod", parent = "Spine", joint = P(0, 4.9, 0.0), tip = P(0, 3.0, -0.62) },
		{ name = "Hatch", parent = "NeckRod", joint = P(0, 4.5, -0.82), tip = P(0, 4.5, -1.18) },
		{ name = "HatchRim", parent = "Hatch", joint = P(0, 4.5, -1.0), tip = P(0, 6.65, -1.0) },
		{ name = "EyeSlit", parent = "Hatch", joint = P(0.04, 3.52, -1.0), tip = P(0.04, 3.52, -1.2) },
		{ name = "ClavicleL", parent = "Spine", joint = P(-0.12, 4.85, 0.05), tip = P(-0.82, 4.75, 0.12) },
		{ name = "UpperArmL", parent = "ClavicleL", joint = P(-0.82, 4.75, 0.12), tip = P(-2.5, 4.05, -0.3) },
		{ name = "ForearmL", parent = "UpperArmL", joint = P(-2.5, 4.05, -0.3), tip = P(-1.72, 2.86, -1.12) },
		{ name = "RimGripL", parent = "ForearmL", joint = P(-1.72, 2.86, -1.12), tip = P(-1.5, 3.0, -1.24) },
		{ name = "ClavicleR", parent = "Spine", joint = P(0.12, 4.85, 0.05), tip = P(0.82, 4.75, 0.12) },
		{ name = "UpperArmR", parent = "ClavicleR", joint = P(0.82, 4.75, 0.12), tip = P(2.5, 4.05, -0.3) },
		{ name = "ForearmR", parent = "UpperArmR", joint = P(2.5, 4.05, -0.3), tip = P(1.72, 2.86, -1.12) },
		{ name = "RimGripR", parent = "ForearmR", joint = P(1.72, 2.86, -1.12), tip = P(1.5, 3.0, -1.24) },
	}
	for _, s in { -1, 1 } do
		local n = if s < 0 then "L" else "R"
		table.insert(bones, { name = "Thigh" .. n, parent = "Pelvis", joint = P(0.36 * s, 3.0, 0.32), tip = P(0.4 * s, 1.55, -0.58) })
		table.insert(bones, { name = "Shin" .. n, parent = "Thigh" .. n, joint = P(0.4 * s, 1.55, -0.58), tip = P(0.34 * s, 0.3, 0.18) })
		table.insert(bones, { name = "Foot" .. n, parent = "Shin" .. n, joint = P(0.34 * s, 0.3, 0.18), tip = P(0.34 * s, 0.04, -0.52) })
		table.insert(bones, { name = "Toe" .. n, parent = "Foot" .. n, joint = P(0.34 * s, 0.06, -0.52), tip = P(0.36 * s, 0.02, -0.82) })
	end
	Rig.build(model, root, cf, {
		id = "c3h",
		bones = bones,
		lines = lines,
		balls = balls,
		floorY = FLOOR,
		mass = 1.3,
	})
	Rig.humanoid(model, HIP, M.cfg.WanderSpeed)
	return model
end

-- 돌진 중: 멈칫(0.4초) → 직진. 끝나면 원래 AI 로 돌려준다(소리 난 곳 조사)
function M.tick(self: any, now: number): boolean
	local d = self.cdata
	if not d.chargeAt then
		return false
	end
	if now < d.chargeAt then
		self.hum.WalkSpeed = 0
		self.hum:MoveTo(self.root.Position)
		return true
	end
	local pos = self.root.Position
	local flat = Vector3.new(d.chargeGoal.X - pos.X, 0, d.chargeGoal.Z - pos.Z)
	if now < d.chargeEnd and flat.Magnitude > 2 then
		self.hum.WalkSpeed = CHARGE_SPEED
		self.hum:MoveTo(d.chargeGoal)
		return true
	end
	local heard = d.chargeFrom
	d.chargeAt, d.chargeGoal, d.chargeFrom = nil, nil, nil
	self:setState(self.state)
	self.waypoints = {}
	if heard and self.state ~= "Chase" then
		self:investigate(heard)
	end
	return false
end

function M.hear(self: any, pos: Vector3, radius: number, source: Player?, kind: string): boolean
	if kind ~= "Sonar" or not source or self.state == "Chase" then
		return false
	end
	local d = self.cdata
	local now = os.clock()
	local my = self.root.Position
	local to = Vector3.new(pos.X - my.X, 0, pos.Z - my.Z)
	if d.chargeAt or (d.nextCharge and now < d.nextCharge) or to.Magnitude > radius or to.Magnitude < 1 then
		return false
	end
	local dist = math.min(CHARGE_DIST, to.Magnitude + 4)
	d.chargeAt = now + 0.4
	d.chargeEnd = now + 0.4 + dist / CHARGE_SPEED + 0.8
	d.chargeGoal = my + to.Unit * dist
	d.chargeFrom = pos
	d.nextCharge = now + 7
	self.model:SetAttribute("Brace", now)
	return true
end

return M
