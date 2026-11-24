--!strict
-- c2h 틈사람 (2장 물류 창고 · 사람형) — 사양서: roster/v5/ch2/c2h_spec.md (+ QA1 수정 지시 반영)
-- 선반 틈에 오래 끼어 옆으로 눌린 창고 직원. 몸·머리가 두께 0.5 의 판(X 로 얇고 Z 로 깊다).
-- 정면(진행 방향)에서는 세로 줄 몇 개 + 붉은 찢김 한 줄, 옆에서만 사람 옆모습과 옆면에 눌린 얼굴(+X)이 보인다.
-- 뼈: Pelvis → Spine → Chest(Band1·Band2 → Badge, BoundArmL/R → ForearmL/R → HandL/R, Neck → HeadPlate → FaceSplit)
--      Pelvis → ThighL/R → ShinL/R → FootL/R.  위팔은 띠에 묶여 고정, 머리는 돌지 않는다.
-- 공포 장치 「옆 통로의 걸음」(간단판):
--   ① 가까운(30 안) 플레이어의 속도를 거울처럼 따라 걷는다(멈추면 같이 멈춤).
--   ② 그 플레이어의 발소리 0.15초 뒤에 똑같은 발소리(클라이언트가 Echo 속성으로 b.step).
--   ③ 플레이어가 22 안에서 3초 넘게 멈춰 있으면 몸을 칼날로 세워(Slide) 넘어와 추격한다.
local Players = game:GetService("Players")
local Rig = require(script.Parent.Rig)

local M = {}
M.cfg = {
	WanderSpeed = 6,
	InvestigateSpeed = 10,
	ChaseSpeed = 16.2, -- 플레이어 달리기 18 × 0.9
	AgentRadius = 1.2,
	AgentHeight = 9,
	CatchDistance = 3,
}
M.spawnLift = 3.4
M.voice = "1" -- (소리: 전용 소리 전까지 발 끌기 계열)

local HIP = 2.2
local FLOOR = -(HIP + 1)
local function P(x: number, y: number, z: number): Vector3
	return Vector3.new(x, FLOOR + y, z) -- y = 바닥에서 높이, 앞 = -Z
end

function M.build(cf: CFrame): Model
	local model, root = Rig.shell("Gapman", cf, Vector3.new(1.2, 2, 1.4))
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
	-- 판 몸은 옆(Z)으로만 두께가 있다: 외곽선 두 줄(앞 테·뒤 테), 정면에서는 겹쳐 한 줄처럼
	local function limb(bone: string, a: Vector3, b: Vector3, wa: number, wm: number, wb: number)
		local d = (b - a).Unit
		local s = Vector3.zAxis
		local off = (s - d * s:Dot(d)).Unit
		local m = a:Lerp(b, 0.35)
		for _, k in { -1, 1 } do
			chain(bone, { a + off * (wa * k), m + off * (wm * k), b + off * (wb * k) })
		end
	end
	-- 몸통 판: 앞 테(가슴·배)와 뒤 테(등·평평한 엉덩이). 곧은 외곽 = 눌린 판
	chain("Pelvis", { P(0, 3.85, -0.34), P(0, 4.6, -0.4) })
	chain("Spine", { P(0, 4.6, -0.4), P(0, 5.35, -0.44) })
	chain("Chest", { P(0, 5.35, -0.44), P(0, 6.05, -0.5), P(0, 6.6, -0.36), P(0.02, 6.78, -0.12) })
	chain("Pelvis", { P(0, 3.8, 0.42), P(0, 4.6, 0.4) })
	chain("Spine", { P(0, 4.6, 0.4), P(0, 5.35, 0.42) })
	chain("Chest", { P(0, 5.35, 0.42), P(0, 6.1, 0.46), P(0, 6.62, 0.3), P(0.02, 6.78, 0.08) })
	S("Pelvis", P(0, 3.85, -0.34), P(0, 3.72, 0.06)) -- 사타구니 밑선
	S("Pelvis", P(0, 3.72, 0.06), P(0, 3.8, 0.42))
	-- 눌린 갈비 자국(얼굴 쪽 옆면 +X)
	for i, y in { 5.85, 6.1, 6.35 } do
		S("Chest", P(0.24, y, -0.4), P(0.24, y - 0.08, 0.02 + i * 0.06))
	end
	-- 랩 띠 2줄(몸통과 묶인 위팔을 함께 조인다) + 출입증
	for _, band in { { "Band1", 5.72 }, { "Band2", 6.28 } } do
		local bn, y = band[1] :: string, band[2] :: number
		S(bn, P(-0.36, y, -0.5), P(-0.36, y - 0.05, 0.47))
		S(bn, P(0.36, y + 0.04, -0.5), P(0.36, y - 0.02, 0.47))
	end
	S("Badge", P(0.4, 6.22, -0.26), P(0.42, 5.82, -0.28))
	S("Badge", P(0.42, 5.82, -0.28), P(0.42, 5.82, -0.02))
	-- 팔: 위팔(묶여 고정) → 아래팔 → 손(엉덩이 옆에 납작하게 펼쳐짐). 전부 몸 판 평면 안(x ±0.3)
	for _, sd in { { "L", -1 }, { "R", 1 } } do
		local n, s = sd[1] :: string, sd[2] :: number
		local x = 0.3 * s
		chain("BoundArm" .. n, { P(x, 6.6, 0.08), P(x, 6.0, 0.16), P(x, 5.3, 0.14) })
		chain("Forearm" .. n, { P(x, 5.3, 0.14), P(x * 1.04, 4.7, 0.05), P(x, 4.05, -0.06) })
		S("Hand" .. n, P(x, 4.05, -0.06), P(x * 1.05, 3.55, -0.12)) -- 손바닥
		S("Hand" .. n, P(x * 1.05, 3.55, -0.2), P(x * 1.08, 2.95, -0.28)) -- 손가락 묶음(검지·중지)
		S("Hand" .. n, P(x * 1.05, 3.55, -0.02), P(x * 1.08, 3.0, 0.04)) -- 손가락 묶음(약지·새끼)
		S("Hand" .. n, P(x, 3.88, -0.18), P(x * 1.05, 3.6, -0.36)) -- 엄지
	end
	-- 목(1마디) → 판 머리: 외곽 7변 + 옆면 얼굴(늘어난 눈구멍 2, 비뚤어진 입 1)
	chain("Neck", { P(0.02, 6.78, -0.05), P(0.05, 7.05, -0.08), P(0.07, 7.32, -0.12) })
	chain("Neck", { P(0.02, 6.78, 0.12), P(0.06, 7.3, 0.1) })
	chain("HeadPlate", {
		P(0.07, 7.32, -0.12),
		P(0.08, 7.42, -0.5),
		P(0.1, 7.95, -0.6),
		P(0.11, 8.5, -0.46),
		P(0.1, 8.75, -0.1),
		P(0.09, 8.55, 0.32),
		P(0.08, 7.95, 0.42),
		P(0.06, 7.3, 0.1),
	})
	S("HeadPlate", P(0.25, 8.2, -0.5), P(0.25, 8.17, -0.12)) -- 앞 눈구멍(옆으로 늘어남)
	S("HeadPlate", P(0.25, 8.08, 0.0), P(0.25, 8.05, 0.28)) -- 뒤 눈구멍(높이가 어긋남)
	chain("HeadPlate", { P(0.25, 7.68, -0.48), P(0.25, 7.62, -0.2), P(0.25, 7.7, 0.06) }) -- 비뚤어진 입
	-- 붉은 세로 찢김(머리판 앞 테) — 정면·옆 모두에서 보이는 한 곳
	S("FaceSplit", P(0.12, 7.75, -0.64), P(0.13, 8.45, -0.52), true)
	-- 다리: 허벅지·정강이는 앞뒤 외곽 두 줄(무릎에서 좁아짐), 발은 납작한 판(발바닥·발등)
	for _, sd in { { "L", -1 }, { "R", 1 } } do
		local n, s = sd[1] :: string, sd[2] :: number
		local x = 0.16 * s
		limb("Thigh" .. n, P(x, 4.1, 0.02), P(x, 2.2, -0.55), 0.3, 0.27, 0.13)
		limb("Shin" .. n, P(x, 2.2, -0.55), P(x, 0.32, 0.0), 0.14, 0.17, 0.08)
		S("Shin" .. n, P(x, 2.32, -0.72), P(x, 2.05, -0.72)) -- 무릎뼈 모서리
		chain("Foot" .. n, { P(x, 0.05, 0.22), P(x, 0.03, -0.45), P(x, 0.05, -0.95) }) -- 발바닥
		chain("Foot" .. n, { P(x, 0.4, -0.02), P(x, 0.2, -0.55), P(x, 0.08, -0.95) }) -- 발등
		S("Foot" .. n, P(x, 0.05, 0.22), P(x, 0.36, 0.12)) -- 뒤꿈치
	end
	local bones: { Rig.Bone } = {
		{ name = "Pelvis", joint = P(0, 4.1, 0), tip = P(0, 4.6, 0) },
		{ name = "Spine", parent = "Pelvis", joint = P(0, 4.6, 0), tip = P(0, 5.35, 0) },
		{ name = "Chest", parent = "Spine", joint = P(0, 5.35, 0), tip = P(0, 6.78, 0) },
		{ name = "Band1", parent = "Chest", joint = P(0, 5.72, 0), tip = P(0, 5.72, 0.5) },
		{ name = "Band2", parent = "Chest", joint = P(0, 6.28, 0), tip = P(0, 6.28, 0.5) },
		{ name = "Badge", parent = "Band2", joint = P(0.41, 6.22, -0.2), tip = P(0.42, 5.82, -0.2) },
		{ name = "BoundArmL", parent = "Chest", joint = P(-0.3, 6.6, 0.08), tip = P(-0.3, 5.3, 0.14) },
		{ name = "ForearmL", parent = "BoundArmL", joint = P(-0.3, 5.3, 0.14), tip = P(-0.3, 4.05, -0.06) },
		{ name = "HandL", parent = "ForearmL", joint = P(-0.3, 4.05, -0.06), tip = P(-0.32, 3.0, -0.2) },
		{ name = "BoundArmR", parent = "Chest", joint = P(0.3, 6.6, 0.08), tip = P(0.3, 5.3, 0.14) },
		{ name = "ForearmR", parent = "BoundArmR", joint = P(0.3, 5.3, 0.14), tip = P(0.3, 4.05, -0.06) },
		{ name = "HandR", parent = "ForearmR", joint = P(0.3, 4.05, -0.06), tip = P(0.32, 3.0, -0.2) },
		{ name = "Neck", parent = "Chest", joint = P(0.03, 6.78, 0.02), tip = P(0.07, 7.32, -0.02) },
		{ name = "HeadPlate", parent = "Neck", joint = P(0.07, 7.32, -0.02), tip = P(0.1, 8.75, -0.1) },
		{ name = "FaceSplit", parent = "HeadPlate", joint = P(0.12, 7.75, -0.64), tip = P(0.13, 8.45, -0.52) },
		{ name = "ThighL", parent = "Pelvis", joint = P(-0.16, 4.1, 0.02), tip = P(-0.16, 2.2, -0.55) },
		{ name = "ShinL", parent = "ThighL", joint = P(-0.16, 2.2, -0.55), tip = P(-0.16, 0.32, 0) },
		{ name = "FootL", parent = "ShinL", joint = P(-0.16, 0.32, 0), tip = P(-0.16, 0.05, -0.95) },
		{ name = "ThighR", parent = "Pelvis", joint = P(0.16, 4.1, 0.02), tip = P(0.16, 2.2, -0.55) },
		{ name = "ShinR", parent = "ThighR", joint = P(0.16, 2.2, -0.55), tip = P(0.16, 0.32, 0) },
		{ name = "FootR", parent = "ShinR", joint = P(0.16, 0.32, 0), tip = P(0.16, 0.05, -0.95) },
	}
	Rig.build(model, root, cf, {
		id = "c2h",
		bones = bones,
		lines = lines,
		balls = balls,
		floorY = FLOOR,
		mass = 0.8,
	})
	Rig.humanoid(model, HIP, M.cfg.WanderSpeed)
	return model
end

-- 가장 가까운 살아 있는 플레이어(같은 층)
local function nearest(self: any, range: number): (Player?, BasePart?, number)
	local my = self.root.Position
	local bestP, bestR, bestD = nil, nil, range
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Status") == "Alive" and not p:GetAttribute("Hidden") then
			local char = p.Character
			local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r and math.abs(r.Position.Y - my.Y) < 9 then
				local d = (r.Position - my).Magnitude
				if d < bestD then
					bestP, bestR, bestD = p, r, d
				end
			end
		end
	end
	return bestP, bestR, bestD
end

function M.tick(self: any, now: number): boolean
	local d = self.cdata
	local st = self.state
	if st == "Chase" or st == "Alert" then
		d.mirror = false
		d.stillSince = nil
		return false
	end
	local p, r = nearest(self, 30)
	if p and r then
		local v = r.AssemblyLinearVelocity
		local sp = Vector3.new(v.X, 0, v.Z).Magnitude
		-- ① 거울 걸음: 같은 속도(달리기 × 0.9 까지), 멈추면 같이 멈춘다
		self.hum.WalkSpeed = math.clamp(sp, 0, M.cfg.ChaseSpeed)
		d.mirror = true
		-- ③ 3초 넘게 멈춰 있으면 칼날로 서서 틈을 넘어온다
		if sp < 1 and (r.Position - self.root.Position).Magnitude < 22 then
			d.stillSince = d.stillSince or now
			if now - d.stillSince >= 3 then
				d.stillSince = nil
				self.model:SetAttribute("Slide", now)
				self:startChase(p, r.Position)
			end
		else
			d.stillSince = nil
		end
	elseif d.mirror then
		d.mirror = false
		d.stillSince = nil
		self:setState(st) -- 원래 상태 속도로 되돌림
	end
	return false
end

-- ② 메아리 발소리: 가까운 플레이어의 발소리를 들으면 클라이언트가 0.15초 뒤 같은 발소리를 낸다
function M.hear(self: any, pos: Vector3, _radius: number, source: Player?, kind: string): boolean
	if source and self.state ~= "Chase" and (kind == "StepWalk" or kind == "StepRun" or kind == "StepCrouch") then
		if (pos - self.root.Position).Magnitude < 30 then
			local n = self.model:GetAttribute("Echo")
			self.model:SetAttribute("Echo", (if typeof(n) == "number" then n else 0) + 1)
		end
	end
	return false
end

return M
