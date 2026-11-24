--!strict
-- c6h 등맞댄 손님 (6장 호텔 · 사람형) — 사양서: art/creatures/sheets/ch6/c6h_spec.md (QA1 반영 절이 최신)
-- 등이 붙은 두 투숙객이 골반 하나와 다리 둘을 나눠 쓴다. A 다리는 무릎이 앞(−Z), B 다리는 무릎이 뒤(+Z).
-- 두 척추는 골반에서 갈라져 V(A 는 앞으로, B 는 뒤로 기욺) + 서로 반대로 11° 비틀려 정면에서도 어깨선 4개가 엇갈린다.
-- QA1: 치마 금지 — 가운은 B 몸통·소매만 덮고 골반 위에서 찢긴 단으로 끝남(허벅지·골반이 드러남) · 허리띠 위 두 척추 사이를
--      살 막(꿰맨 세로선 + 가로 땀)이 메움 · 달걀 머리 대신 두개골 공 + 턱 · A 는 젖은 머리카락, B 는 수건 터번 · 무릎은 슬개골.
-- 뼈: Pelvis → ThighA → ShinA → FootA,  Pelvis → ThighB → ShinB → FootB,  Pelvis → Belt(붉은 허리띠),  Pelvis → Web(등 사이 살 막),
--      Pelvis → SpineA → ChestA → NeckA → HeadA,  ChestA → UpperArmAL/AR → ForearmAL/AR,
--      Pelvis → SpineB → ChestB → NeckB → HeadB,  ChestB → UpperArmBL/BR → ForearmBL/BR
-- 붉은 선: 가운 허리띠 고리 + 늘어진 끈(한 덩어리).
-- 공포 장치 「뒤가 없다」: 절대 돌아서지 않는다(AutoRotate 끔). 서버가 몸을 진행 '축'에만 맞추고, 반대로 갈 땐 돌지 않고
--   그대로 반대로 걷는다 — 앞장서는 얼굴이 A ↔ B 로 바뀐다(클라이언트가 진행 방향으로 판단). 감지는 양 끝 모두(기본 AI 감지가
--   전 방향이라 '등 뒤로 몰래 지나가기'가 통하지 않음). (옆 사각·문 알코브 안전·들여다보기는 빠짐 — 기본 AI 안정 우선)
local Rig = require(script.Parent.Rig)

local M = {}
M.cfg = {
	WanderSpeed = 5.5,
	InvestigateSpeed = 8,
	ChaseSpeed = 13,
	AgentRadius = 1.2,
	AgentHeight = 7.8,
	CatchDistance = 3,
}
M.spawnLift = 3.6
M.voice = "4" -- (소리: 전용 소리 전까지 — 쿵 걸음 계열)

local HIP = 2.5
local FLOOR = -(HIP + 1)
local TURN = math.rad(25) -- 한 틱(0.1초)에 축을 맞추는 최대 각

local function P(x: number, y: number, z: number): Vector3
	return Vector3.new(x, FLOOR + y, z)
end

function M.build(cf: CFrame): Model
	local model, root = Rig.shell("BackToBack", cf, Vector3.new(1.4, 2, 1.4))
	local lines: { Rig.Line } = {}
	local balls: { Rig.Ball } = {}
	local bones: { Rig.Bone } = {}
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
	local pelvis = P(0, 3.5, 0)
	table.insert(bones, { name = "Pelvis", joint = pelvis, tip = P(0, 3.95, 0) })
	-- 공유 골반(3차): 앞뒤로 튀어나온 엉덩뼈 쐐기 둘 + 가운데 꿰맨 판(둥근 덩어리 아님)
	for _, k in { -1, 1 } do
		chain("Pelvis", { P(-0.42, 3.78, 0.62 * k), P(0.42, 3.78, 0.62 * k), P(0, 3.18, 0.12 * k), P(-0.42, 3.78, 0.62 * k) })
	end
	S("Pelvis", P(0, 3.7, 0), P(0, 3.16, 0))
	-- 다리 둘: A(왼쪽, 무릎 −Z) · B(오른쪽, 무릎 +Z). A 발 = 슬리퍼, B 발 = 맨발
	for _, L in { { "A", -0.32, -1 }, { "B", 0.32, 1 } } do
		local n, x, kz = L[1] :: string, L[2] :: number, L[3] :: number
		local hip, knee, ankle = P(x, 3.4, 0), P(x * 1.05, 1.75, 0.22 * kz), P(x, 0.2, 0)
		cone("Thigh" .. n, hip, knee, 0.24, 0.16, Vector3.new(1, 0, 0))
		cone("Shin" .. n, knee, ankle, 0.16, 0.09, Vector3.new(1, 0, 0))
		S("Shin" .. n, knee + Vector3.new(0, 0.2, 0.14 * kz), knee + Vector3.new(0, -0.25, 0.12 * kz)) -- 슬개골
		local toe = ankle + Vector3.new(0, -0.18, 0.8 * kz)
		chain("Foot" .. n, { ankle + Vector3.new(0, -0.18, -0.2 * kz), toe, ankle + Vector3.new(0, 0.02, 0.15 * kz) })
		table.insert(bones, { name = "Thigh" .. n, parent = "Pelvis", joint = hip, tip = knee })
		table.insert(bones, { name = "Shin" .. n, parent = "Thigh" .. n, joint = knee, tip = ankle })
		table.insert(bones, { name = "Foot" .. n, parent = "Shin" .. n, joint = ankle, tip = toe })
	end
	-- 상체 둘: 골반에서 갈라져 V. f = 얼굴 쪽(A −1, B +1), tw = 비틀림
	for _, T in { { "A", -1, math.rad(11) }, { "B", 1, -math.rad(11) } } do
		local n, f, tw = T[1] :: string, T[2] :: number, T[3] :: number
		local rot = CFrame.new(pelvis) * CFrame.fromEulerAnglesYXZ(0, tw, math.rad(4)) * CFrame.new(-pelvis)
		local function Q(x: number, y: number, z: number): Vector3
			return rot:PointToWorldSpace(P(x, y, z * f))
		end
		local s0, s1, s2, nk, hd = Q(0, 3.75, 0.15), Q(0, 4.95, 0.42), Q(0, 6.1, 0.72), Q(0, 6.55, 0.85), Q(0, 7.1, 0.95)
		table.insert(bones, { name = "Spine" .. n, parent = "Pelvis", joint = s0, tip = s1 })
		table.insert(bones, { name = "Chest" .. n, parent = "Spine" .. n, joint = s1, tip = s2 })
		table.insert(bones, { name = "Neck" .. n, parent = "Chest" .. n, joint = s2 + (nk - s2) * 0.2, tip = nk })
		table.insert(bones, { name = "Head" .. n, parent = "Neck" .. n, joint = nk, tip = hd })
		-- 배·가슴 옆 외곽(좌우) + 쇄골
		for _, s in { -1, 1 } do
			chain("Spine" .. n, { Q(0.5 * s, 3.85, 0.15), Q(0.5 * s, 4.95, 0.4) })
			S("Chest" .. n, Q(0.5 * s, 4.95, 0.4), Q(0.68 * s, 6.05, 0.7))
		end
		S("Chest" .. n, Q(-0.7, 6.1, 0.75), Q(0.7, 6.1, 0.75))
		-- 목 + 두개골 + 턱(옆얼굴 윤곽)
		S("Neck" .. n, Q(-0.16, 6.15, 0.82), Q(-0.14, 6.65, 0.88))
		S("Neck" .. n, Q(0.16, 6.15, 0.82), Q(0.14, 6.65, 0.88))
		local side, front = {}, {}
		for _, q in { { 0.34, -0.42 }, { 0.56, -0.04 }, { 0.4, 0.32 }, { 0.02, 0.54 }, { -0.24, 0.36 }, { -0.52, 0.34 }, { -0.34, -0.02 }, { -0.12, -0.32 }, { 0.34, -0.42 } } do
			table.insert(side, Q(0, 7.22 + q[1], 0.95 + q[2]))
		end
		for _, q in { { 0, 0.56 }, { 0.33, 0.26 }, { 0.27, -0.12 }, { 0, -0.54 }, { -0.27, -0.12 }, { -0.33, 0.26 }, { 0, 0.56 } } do
			table.insert(front, Q(q[1], 7.22 + q[2], 1.07))
		end
		chain("Head" .. n, side)
		chain("Head" .. n, front)
		if n == "A" then
			-- 젖어 두피에 들러붙은 머리카락(이마·뺨으로)
			for _, x in { -0.25, 0.22 } do
				S("HeadA", Q(x, 7.65, 1.15), Q(x * 1.2, 6.95, 1.36))
			end
		else
			-- 수건 터번 자락
			chain("HeadB", { Q(-0.34, 7.52, 1.25), Q(0, 7.34, 1.45), Q(0.34, 7.2, 1.29) }) -- 흘러내려 눈을 덮음
		end
		-- 팔: A 는 허리 높이로 더듬는 맨팔, B 는 가운 소매에 덮여 늘어짐(해진 지그재그 단)
		for _, s in { -1, 1 } do
			local side = if s < 0 then "L" else "R"
			local ua, fa = "UpperArm" .. n .. side, "Forearm" .. n .. side
			local sh = Q(0.72 * s, 6.0, 0.72)
			local el = if n == "A" then Q(0.85 * s, 4.95, 1.15) else Q(0.82 * s, 4.85, 0.75)
			local wr = if n == "A" then Q(0.55 * s, 4.25, 1.9) else Q(0.78 * s, 3.75, 0.95)
			cone(ua, sh, el, 0.17, 0.12, Q(s, 6, 0.7) - Q(0, 6, 0.7))
			if n == "A" then
				cone(fa, el, wr, 0.12, 0.08, Q(s, 5, 0) - Q(0, 5, 0))
				S(fa, wr, wr + (Q(0.1 * s, 3.85, 2.4) - Q(0, 4.25, 1.9)))
				S(fa, wr, wr + (Q(-0.12 * s, 3.9, 2.35) - Q(0, 4.25, 1.9)))
			else
				cone(fa, el, wr, 0.2, 0.24, Q(s, 5, 0) - Q(0, 5, 0))
				chain(fa, { wr + (Q(0.22 * s, 3.7, 0) - Q(0, 3.75, 0)), wr + (Q(0, 3.55, 0.12) - Q(0, 3.75, 0)), wr + (Q(-0.22 * s, 3.7, 0) - Q(0, 3.75, 0)) })
			end
			table.insert(bones, { name = ua, parent = "Chest" .. n, joint = sh, tip = el })
			table.insert(bones, { name = fa, parent = ua, joint = el, tip = wr })
		end
		if n == "B" then
			-- 가운: 깃 + 골반 위에서 찢긴 단(허벅지는 드러남)
			chain("ChestB", { Q(-0.45, 6.15, 0.95), Q(0, 5.5, 1.05), Q(0.45, 6.15, 0.95) })
			chain("SpineB", { Q(-0.6, 4.0, 0.3), Q(-0.1, 3.8, 0.45), Q(0.2, 4.05, 0.4), Q(0.6, 3.85, 0.3) })
		end
	end
	-- 등 사이 살 막(허리띠 위 V 공간): 윗단 꺾은선 + 꿰맨 세로선 + 가로 땀
	chain("Web", { P(-0.3, 5.6, -0.55), P(0, 5.2, 0), P(0.3, 5.6, 0.55) })
	S("Web", P(0, 3.95, 0), P(0, 5.2, 0))
	S("Web", P(-0.2, 4.4, -0.12), P(0.2, 4.4, 0.12))
	S("Web", P(-0.2, 4.85, -0.15), P(0.2, 4.85, 0.15))
	table.insert(bones, { name = "Web", parent = "Pelvis", joint = P(0, 3.95, 0), tip = P(0, 5.2, 0) })
	-- 붉은 허리띠: 고리 + 늘어진 끈
	table.insert(lines, { bone = "Belt", a = P(0, 3.88, 0), b = P(0, 3.95, 0), r = 0.72, disc = true, red = true })
	chain("Belt", { P(0.68, 3.9, -0.2), P(0.8, 3.3, -0.3), P(0.75, 2.75, -0.25) }, true)
	table.insert(bones, { name = "Belt", parent = "Pelvis", joint = P(0, 3.9, 0), tip = P(0.75, 2.75, -0.25) })
	Rig.build(model, root, cf, {
		id = "c6h",
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
	self.hum.AutoRotate = false -- 돌아서지 않는다
end

-- 몸을 진행 '축'에만 맞춘다: 앞·뒤 중 지금 보는 쪽에 가까운 방향으로(반대로 갈 땐 돌지 않고 그대로 뒷걸음 = B 가 앞장)
function M.tick(self: any, _now: number): boolean
	local v = self.root.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	if flat.Magnitude > 1 then
		local cfr = self.root.CFrame
		local lv = cfr.LookVector
		local look = Vector3.new(lv.X, 0, lv.Z)
		if look.Magnitude > 0.1 then
			look = look.Unit
			local want = flat.Unit
			if want:Dot(look) < 0 then
				want = -want
			end
			local ang = math.acos(math.clamp(want:Dot(look), -1, 1))
			if ang > 0.05 then
				local sgn = if look:Cross(want).Y >= 0 then 1 else -1
				local nl = CFrame.Angles(0, sgn * math.min(ang, TURN), 0):VectorToWorldSpace(look)
				local pos = cfr.Position
				self.root.CFrame = CFrame.lookAt(pos, pos + nl)
			end
		end
	end
	return false
end

return M
