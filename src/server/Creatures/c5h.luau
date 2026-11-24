--!strict
-- c5h 모서리 (5장 심층 미로 · 사람형) — 사양서: roster/v5/ch5/c5h_spec.md (+ QA1 수정 지시 반영)
-- 옆으로 눌려 두께 0.34 의 한 평면(시상면)이 된 키 11 의 사람. 진행 방향(정면)에서 보면 세로선 두 줄 = 미로의 벽 모서리.
-- 옆에서만 얼굴이 썰려 나간 머리(붉은 잘린 가장자리), 갈비 틈 3, 부채처럼 눌린 손이 보인다.
-- 정면 두 줄: 앞 외곽은 x = −0.17, 뒤 외곽은 x = +0.17 에 그려 판 두께만큼 떨어진 세로선 두 줄이 된다.
-- 뼈(사람 리그와 공유 없음, 모든 관절은 X 축 하나): pelvis → spine1 → spine2 → neck → head → crown,
--      spine2 → shoulder → elbowN/F → wristN/F → palmN/F,  pelvis → kneeN/F → ankleN/F → toeN/F  (N = 가까운 쪽, F = 먼 쪽 사슬)
--      (뼈 이름은 사양서처럼 '끝 관절' 이름: kneeN = 허벅지, ankleN = 정강이, toeN = 발)
-- 공포 장치 「선 한 줄」(간단판): 음파에 맞으면 0.25초 만에 쏜 사람 쪽으로 몸을 돌려 칼날(정면 = 선)을 맞춘다(Align).
--   그 뒤 10초 동안(보이는 동안) 그 사람 쪽 직선으로만 다가온다 → 선이 제자리에서 길어지고 출렁일 뿐.
--   (두 사람 사이각 협동 반격·열주실 선호는 빠짐)
local Rig = require(script.Parent.Rig)

local M = {}
M.cfg = {
	WanderSpeed = 7,
	InvestigateSpeed = 9,
	ChaseSpeed = 11,
	AgentRadius = 1.2,
	AgentHeight = 10,
	CatchDistance = 2.8,
}
M.spawnLift = 3.2
M.voice = "5" -- (소리: 전용 소리 전까지 — 가벼운 마찰 걸음 계열)

local HIP = 2
local FLOOR = -(HIP + 1)
local T = 0.17 -- 판 두께의 반
local function P(x: number, y: number, z: number): Vector3
	return Vector3.new(x, FLOOR + y, z)
end

function M.build(cf: CFrame): Model
	local model, root = Rig.shell("Edge", cf, Vector3.new(0.8, 2, 1.6))
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
	-- 눌린 뼈 판: 관절에서 좁고 사이에서 넓은 외곽 두 줄(앞 = −X 면, 뒤 = +X 면), 직선 위주
	local function slab(bone: string, a: Vector3, b: Vector3, wa: number, wm: number, wb: number)
		local d = (b - a).Unit
		local off = (Vector3.zAxis - d * Vector3.zAxis:Dot(d)).Unit
		local m = a:Lerp(b, 0.45)
		for _, k in { -1, 1 } do
			local x = Vector3.new(k * T, 0, 0)
			chain(bone, { a + off * (wa * k) + x, m + off * (wm * k) + x, b + off * (wb * k) + x })
		end
	end
	-- 몸통 판: 앞 외곽(배·가슴)과 뒤 외곽(굽은 등)
	chain("spine1", { P(-T, 5.85, -0.42), P(-T, 6.9, -0.5) })
	chain("spine2", { P(-T, 6.9, -0.5), P(-T, 7.9, -0.72), P(-T, 8.75, -0.62) })
	chain("pelvis", { P(T, 5.75, 0.45), P(T, 6.9, 0.55) })
	chain("spine2", { P(T, 6.9, 0.55), P(T, 8.0, 0.62), P(T, 8.95, 0.3) })
	S("pelvis", P(-T, 5.85, -0.42), P(T, 5.75, 0.45)) -- 판 밑단
	-- 갈비 틈 3(같은 간격·같은 각도)
	for i = 0, 2 do
		local y = 7.55 + i * 0.32
		S("spine2", P(0, y, -0.55), P(0, y + 0.1, -0.05))
	end
	-- 목: 앞으로 숙여 머리가 늘 아래를 본다
	slab("neck", P(0, 8.85, 0.05), P(0, 9.95, -0.85), 0.2, 0.16, 0.14)
	-- 머리: 옆에서 본 두개골 윤곽, 이마–코 자리가 평평하게 썰려 나간 면(붉은 잘린 가장자리)
	local hd = {
		P(T, 10.05, -0.75),
		P(T, 10.75, -0.55),
		P(T, 11.15, -0.95),
		P(T, 11.2, -1.6),
		P(-T, 10.85, -2.2),
		P(-T, 10.25, -2.35),
	}
	chain("head", hd)
	S("crown", P(-T, 10.25, -2.35), P(-T, 9.75, -1.4), true) -- 썰린 얼굴 가장자리(붉은 선 하나)
	chain("crown", { P(-T, 9.75, -1.4), P(-T, 9.82, -0.95), P(T, 10.05, -0.75) })
	-- 팔(N·F 같은 평면, 서로 0.03 어긋남): 위팔 → 아래팔 판, 부채 손(손바닥 + 손가락 3갈래, 끝이 모임)
	for _, arm in { { "N", -0.03, P(0, 7.75, -0.85), P(0, 6.1, -1.55), P(0, 5.55, -1.85) }, { "F", 0.03, P(0, 7.75, -0.3), P(0, 5.95, -0.42), P(0, 5.36, -0.5) } } do
		local n, dx = arm[1] :: string, arm[2] :: number
		local el, wr, pm = arm[3] :: Vector3, arm[4] :: Vector3, arm[5] :: Vector3
		local sx = Vector3.new(dx, 0, 0)
		slab("elbow" .. n, P(dx, 9.35, -0.5), el + sx, 0.16, 0.2, 0.1)
		slab("wrist" .. n, el + sx, wr + sx, 0.1, 0.15, 0.08)
		chain("palm" .. n, { wr + sx + Vector3.new(0, 0, -0.12), pm + sx + Vector3.new(0, 0, -0.18) })
		chain("palm" .. n, { wr + sx + Vector3.new(0, 0, 0.1), pm + sx + Vector3.new(0, 0, 0.08) })
		for f = -1, 1 do
			S("palm" .. n, pm + sx + Vector3.new(0, 0, f * 0.12), pm + sx + Vector3.new(0, -0.62 + math.abs(f) * 0.1, f * 0.22 - 0.12))
		end
	end
	-- 다리(N·F 같은 평면): 허벅지·정강이 판, 발은 바닥에 눌린 얇은 쐐기(발끝 뾰족)
	for _, lg in { { "N", -0.03 }, { "F", 0.03 } } do
		local n, dx = lg[1] :: string, lg[2] :: number
		local hip, knee, ankle = P(dx, 5.9, 0.05), P(dx, 3.2, -0.3), P(dx, 0.5, 0.05)
		slab("knee" .. n, hip, knee, 0.34, 0.36, 0.14)
		slab("ankle" .. n, knee, ankle, 0.14, 0.2, 0.08)
		chain("toe" .. n, { ankle + Vector3.new(0, 0, 0.3), ankle + Vector3.new(0, -0.45, 0.12), ankle + Vector3.new(0, -0.47, -1.25) }) -- 뒤꿈치 → 발바닥 → 발끝
		S("toe" .. n, ankle + Vector3.new(0, 0.05, -0.08), ankle + Vector3.new(0, -0.45, -1.25)) -- 발등 쐐기
	end
	local bones: { Rig.Bone } = {
		{ name = "pelvis", joint = P(0, 5.9, 0.05), tip = P(0, 6.9, 0.05) },
		{ name = "spine1", parent = "pelvis", joint = P(0, 6.0, 0.05), tip = P(0, 6.9, 0.0) },
		{ name = "spine2", parent = "spine1", joint = P(0, 6.9, 0.0), tip = P(0, 8.75, 0.0) },
		{ name = "neck", parent = "spine2", joint = P(0, 8.85, 0.05), tip = P(0, 9.95, -0.85) },
		{ name = "head", parent = "neck", joint = P(0, 9.95, -0.85), tip = P(0, 10.6, -1.4) },
		{ name = "crown", parent = "head", joint = P(0, 10.4, -1.6), tip = P(0, 10.25, -2.35) },
		{ name = "shoulder", parent = "spine2", joint = P(0, 8.6, -0.2), tip = P(0, 9.35, -0.5) },
		{ name = "elbowN", parent = "shoulder", joint = P(-0.03, 9.35, -0.5), tip = P(-0.03, 7.75, -0.85) },
		{ name = "wristN", parent = "elbowN", joint = P(-0.03, 7.75, -0.85), tip = P(-0.03, 6.1, -1.55) },
		{ name = "palmN", parent = "wristN", joint = P(-0.03, 6.1, -1.55), tip = P(-0.03, 5.55, -1.85) },
		{ name = "elbowF", parent = "shoulder", joint = P(0.03, 9.35, -0.5), tip = P(0.03, 7.75, -0.3) },
		{ name = "wristF", parent = "elbowF", joint = P(0.03, 7.75, -0.3), tip = P(0.03, 5.95, -0.42) },
		{ name = "palmF", parent = "wristF", joint = P(0.03, 5.95, -0.42), tip = P(0.03, 5.36, -0.5) },
	}
	for _, lg in { { "N", -0.03 }, { "F", 0.03 } } do
		local n, dx = lg[1] :: string, lg[2] :: number
		table.insert(bones, { name = "knee" .. n, parent = "pelvis", joint = P(dx, 5.9, 0.05), tip = P(dx, 3.2, -0.3) })
		table.insert(bones, { name = "ankle" .. n, parent = "knee" .. n, joint = P(dx, 3.2, -0.3), tip = P(dx, 0.5, 0.05) })
		table.insert(bones, { name = "toe" .. n, parent = "ankle" .. n, joint = P(dx, 0.5, 0.05), tip = P(dx, 0.03, -1.25) })
	end
	Rig.build(model, root, cf, {
		id = "c5h",
		bones = bones,
		lines = lines,
		balls = balls,
		floorY = FLOOR,
		mass = 0.7,
	})
	Rig.humanoid(model, HIP, M.cfg.WanderSpeed)
	return model
end

-- 칼날 맞추기(0.25초 멈춤·회전) → 노출 10초 동안 보이면 직선으로만 다가옴
function M.tick(self: any, now: number): boolean
	local d = self.cdata
	if not d.edgeUntil then
		return false
	end
	local who: Player? = d.edgeWho
	local char = who and who.Character
	local tr = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if now < d.alignUntil then
		self.hum:MoveTo(self.root.Position)
		return true
	end
	if now < d.edgeUntil and tr and who and who:GetAttribute("Status") == "Alive" and not who:GetAttribute("Hidden") then
		local tp = tr.Position
		if self:lineOfSight(tp) then
			if self.state ~= "Chase" then
				self.hum.WalkSpeed = self.cfg.InvestigateSpeed
			end
			self.hum:MoveTo(tp)
			return true
		end
	end
	-- 끝: 보통 AI 로(마지막으로 본 곳 조사)
	local last = if tr then tr.Position else d.edgeFrom
	d.edgeUntil, d.edgeWho, d.edgeFrom = nil, nil, nil
	self.waypoints = {}
	if self.state ~= "Chase" and last then
		self:setState(self.state)
		self:investigate(last)
	end
	return false
end

function M.hear(self: any, pos: Vector3, radius: number, source: Player?, kind: string): boolean
	if kind ~= "Sonar" or not source then
		return false
	end
	local my = self.root.Position
	local to = Vector3.new(pos.X - my.X, 0, pos.Z - my.Z)
	if to.Magnitude > radius or to.Magnitude < 0.5 then
		return false
	end
	local d = self.cdata
	local now = os.clock()
	-- 몸 평면을 쏜 사람의 시선과 나란하게(앞 = −Z 가 그 사람 쪽): 정면에서 선 두 줄만 보인다
	self.root.CFrame = CFrame.lookAt(my, my + to.Unit)
	self.model:SetAttribute("Align", now)
	if self.state == "Chase" then
		return false
	end
	d.alignUntil = now + 0.25
	d.edgeUntil = now + 10
	d.edgeWho = source
	d.edgeFrom = pos
	return true
end

return M
