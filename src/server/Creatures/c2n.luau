--!strict
-- c2n 짐걸이 (2장 물류 창고 · 비인간형) — 사양서: roster/v5/ch2/c2n_spec.md
-- 머리 없는 몸이 배를 위로 하고 높이 12의 (보이지 않는) 빔 밑에 네 J 갈고리로 매달려 간다. 아래에서 보이는 건 등:
-- 골반 쪽이 크고 목 쪽으로 작아지는 등뼈 돌기 7, 견갑 판·골반 날개(팔다리가 여기서 나옴), 랩으로 봉한 목 그루터기.
-- 뼈: Hang(빔 위 매달림 점, 진자) → Pelvis → Spine1 → Spine2 → NeckStump / 팔·다리 3마디(위·아래·갈고리) / Strand 2마디(붉은 랩 가닥)
-- 공포 장치 「매달린 짐」: 음파에 맞으면 즉시 몸을 말아 짐처럼 멈춘다(Wrap 속성). 마지막 음파 뒤 4초가 지나야 풀린다.
-- 멈춘 동안에도 잡기 판정은 그대로라 그 바로 밑(2.5)을 지나가면 떨어져 낚아챈다. 쫓을 땐 1.2초마다 몸을 던진다(속도 출렁임).
local Rig = require(script.Parent.Rig)

local M = {}
M.cfg = {
	WanderSpeed = 3.5, -- 나무늘보처럼 느리게(플레이어 걷기의 1/3)
	InvestigateSpeed = 6,
	ChaseSpeed = 11, -- 평균값. 실제로는 던지기(20) ↔ 다시 걸기(5)를 오간다
	AgentRadius = 1.2,
	AgentHeight = 5,
	CatchDistance = 2.5, -- 위장한 그것 바로 밑 반경
}
M.spawnLift = 2
M.voice = "2" -- (소리: 전용 소리 전까지 나무 딱딱·삐걱 계열 — 갈고리 딸깍 + 랙 삐걱)

local HIP = 1
local FLOOR = -(HIP + 1)
local BEAM = 12.2 -- 빔 윗면 높이(바닥 기준)
local THROW_FAST, THROW_SLOW, THROW_CYCLE = 20, 5, 1.2

-- 시안 좌표(x 옆, y 바닥에서 높이, z 앞 = +) → 루트 기준(앞 = -Z). 몸이 빔(x 0)에서 0.6 옆으로 처져 있어 가운데로 0.3 옮긴다
local function W(x: number, y: number, z: number): Vector3
	return Vector3.new(x - 0.3, FLOOR + y, -z)
end

-- 두 마디 IK: 뿌리 a 에서 끝 c 까지, 길이 l1·l2, 무릎이 pole 쪽으로
local function ik(a: Vector3, c: Vector3, l1: number, l2: number, pole: Vector3): Vector3
	local d = c - a
	local dist = math.clamp(d.Magnitude, 0.05, l1 + l2 - 0.01)
	local dir = d.Unit
	local x = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
	local h = math.sqrt(math.max(0, l1 * l1 - x * x))
	local side = pole - a
	side = side - dir * side:Dot(dir)
	if side.Magnitude < 1e-3 then
		side = Vector3.new(1, 0, 0)
	end
	return a + dir * x + side.Unit * h
end

function M.build(cf: CFrame): Model
	local model, root = Rig.shell("Hanger", cf, Vector3.new(1, 2, 1))
	local lines: { Rig.Line } = {}
	local balls: { Rig.Ball } = {}
	local bones: { Rig.Bone } = {}
	local function L(bone: string, a: Vector3, b: Vector3, r: number, red: boolean?)
		-- 음파에서 원통은 한 획(Line)이고, 아주 짧은 것만 원 하나(Disc)다: 획이 원으로 바뀌지 않게 반지름을 길이에 맞춘다
		local len = (b - a).Magnitude
		local disc = len < 0.12
		table.insert(lines, { bone = bone, a = a, b = b, r = if disc then r else math.min(r, len / 4.2), red = red, disc = if disc then true else nil })
	end
	-- 가늘어지는 관(점 사이마다 원통, 반지름은 점마다)
	local function tube(bone: string, pts: { Vector3 }, rs: { number })
		for i = 1, #pts - 1 do
			L(bone, pts[i], pts[i + 1], rs[i])
		end
	end
	local function bone(name: string, parent: string?, joint: Vector3, tip: Vector3)
		table.insert(bones, { name = name, parent = parent, joint = joint, tip = tip })
	end

	-- 몸 축: 골반 P(뒤) → 허리(처짐) → 가슴 C(앞). 배가 위(up = +Y), 등이 아래
	local P = W(0.6, 9.6, -1.4)
	local C = W(0.6, 9.45, 1.1)
	local mid = (P + C) / 2 - Vector3.new(0, 0.5, 0)
	local ax = (C - P).Unit
	local up = Vector3.new(0, 1, 0)
	local lat = ax:Cross(up).Unit
	local hangAt = Vector3.new(0, FLOOR + BEAM, mid.Z)

	bone("Hang", nil, hangAt, mid)
	bone("Pelvis", "Hang", P, P - ax * 0.4)
	bone("Spine1", "Pelvis", P, mid)
	bone("Band1", "Spine1", P:Lerp(mid, 0.55), P:Lerp(mid, 0.55) + up * 0.5)
	bone("Spine2", "Spine1", mid, C)
	bone("Band2", "Spine2", mid:Lerp(C, 0.5), mid:Lerp(C, 0.5) + up * 0.5)
	local nb = C + ax * 0.3
	local hc = C + Vector3.new(0.03, -0.59, 0) + ax * 0.47
	bone("NeckStump", "Spine2", nb, hc)

	-- 몸통: 음파에는 선 하나가 한 획이라, 몸의 양옆 외곽선 두 줄로 그린다(골반 덩어리 → 잘록한 허리 → 넓은 가슴).
	-- 외곽은 등 쪽(아래)으로 살짝 내려 몸의 두께가 보이게. 끝(골반 뒤·가슴 앞)은 짧은 가로선으로 닫는다
	local P0, C1 = P - ax * 0.35, C + ax * 0.3
	local spine = { P0, P, P:Lerp(mid, 0.6), mid, mid:Lerp(C, 0.5), C, C1 }
	local half = { 0.3, 0.46, 0.38, 0.33, 0.44, 0.52, 0.36 }
	local owner = { "Pelvis", "Spine1", "Spine1", "Spine2", "Spine2", "Spine2" }
	for _, sg in { 1, -1 } do
		for i = 1, #spine - 1 do
			local a = spine[i] + lat * (sg * half[i]) - up * 0.12
			local b = spine[i + 1] + lat * (sg * half[i + 1]) - up * 0.12
			L(owner[i], a, b, 0.1)
		end
	end
	L("Pelvis", P0 + lat * 0.3 - up * 0.12, P0 - lat * 0.3 - up * 0.12, 0.08)
	L("Spine2", C1 + lat * 0.36 - up * 0.12, C1 - lat * 0.36 - up * 0.12, 0.08)
	-- 등 가운데 고랑(척추선): 골반에서 가슴까지
	tube("Spine1", { P - up * 0.3, P:Lerp(mid, 0.5) - up * 0.34, mid - up * 0.32 }, { 0.07, 0.07 })
	tube("Spine2", { mid - up * 0.32, C - up * 0.3 }, { 0.07 })
	-- 등뼈 돌기 7: 등선(아래)에서 솟은 가시 마디, 골반 쪽이 크고 목 쪽으로 작아진다
	for i = 0, 6 do
		local t = 0.12 + i * 0.12
		local q = if t < 0.5 then P:Lerp(mid, t * 2) else mid:Lerp(C, (t - 0.5) * 2)
		local sz = 0.3 - i * 0.03
		local b0 = q - up * 0.32
		L(if t < 0.5 then "Spine1" else "Spine2", b0, b0 - up * sz - ax * 0.08, 0.09 - i * 0.008)
	end
	-- 견갑 판·골반 날개: 팔다리가 여기서 나온다
	for _, sg in { 1, -1 } do
		L("Spine2", C + lat * (sg * 0.15) - ax * 0.35, C + lat * (sg * 0.55) + up * 0.15, 0.2)
		L("Pelvis", P + lat * (sg * 0.1) + ax * 0.3, P + lat * (sg * 0.5) + up * 0.08, 0.22)
		-- 옆구리 갈비 2줄
		for _, t in { 0.66, 0.8 } do
			local q = P:Lerp(C, t) - up * 0.2
			L("Spine2", q + lat * (sg * 0.28) - up * 0.15, q + lat * (sg * 0.45) + up * 0.12, 0.05)
		end
	end
	-- 끊어진 랩 띠 두 줄(허리·가슴을 감은 고리)
	L("Band1", P:Lerp(mid, 0.55) - ax * 0.03, P:Lerp(mid, 0.55) + ax * 0.03, 0.44)
	L("Band2", mid:Lerp(C, 0.5) - ax * 0.03, mid:Lerp(C, 0.5) + ax * 0.03, 0.42)

	-- 팔다리: 뿌리(견갑/골반 날개) → IK 팔꿈치·무릎 → 손목(빔 바로 밑) → J 갈고리가 빔 위를 감아 넘어 뒤로 손톱
	local limbs = {
		{ key = "FL", root = C + lat * 0.48 + up * 0.12, w = W(0.28, 11.55, 1.9), l1 = 1.35, l2 = 1.3, arm = true, s = 1 },
		{ key = "FR", root = C - lat * 0.48 + up * 0.12, w = W(0.28, 11.55, 0.9), l1 = 1.35, l2 = 1.3, arm = true, s = -1 },
		{ key = "BL", root = P + lat * 0.42 + up * 0.05, w = W(0.28, 11.55, -1.55), l1 = 1.45, l2 = 1.35, arm = false, s = 1 },
		{ key = "BR", root = P - lat * 0.42 + up * 0.05, w = W(0.28, 11.55, -2.35), l1 = 1.45, l2 = 1.35, arm = false, s = -1 },
	}
	for _, lb in limbs do
		local upper = if lb.arm then "UpperArm" .. lb.key else "Thigh" .. lb.key
		local lower = if lb.arm then "Forearm" .. lb.key else "Shin" .. lb.key
		local hook = "Hook" .. lb.key
		local pole = lb.root + lat * (lb.s * 1.2) - up * 0.6 + ax * (if lb.arm then -0.6 else 0.9)
		local knee = ik(lb.root, lb.w, lb.l1, lb.l2, pole)
		local w = lb.w
		bone(upper, if lb.arm then "Spine2" else "Pelvis", lb.root, knee)
		bone(lower, upper, knee, w)
		bone(hook, lower, w, w + up * 0.6)
		local k = if lb.arm then 1 else 1.12
		tube(upper, { lb.root, lb.root:Lerp(knee, 0.5), knee }, { 0.23 * k, 0.19 * k })
		table.insert(balls, { bone = upper, c = knee, r = 0.17 * k })
		tube(lower, { knee, knee:Lerp(w, 0.55), w }, { 0.15 * k, 0.12 * k })
		-- 붙은 손가락 J: 앞쪽으로 빔 윗면을 감아 넘고 → 빔 뒤로 내려가 가늘어지는 손톱
		local x0 = w.X
		local function hp(dx: number, y: number, dz: number): Vector3
			return Vector3.new(x0 + dx, FLOOR + y, w.Z + dz)
		end
		tube(hook, { w, hp(0.02, 11.95, -0.03), hp(-0.04, BEAM + 0.12, -0.05), hp(-0.22, BEAM + 0.2, -0.06), hp(-0.4, BEAM + 0.1, -0.06), hp(-0.48, BEAM - 0.15, -0.05), hp(-0.44, BEAM - 0.4, -0.04) }, { 0.13 * k, 0.11 * k, 0.09 * k, 0.075 * k, 0.055 * k, 0.03 * k })
		-- 엄지 가시(뒷발톱)
		local back = w + Vector3.new(0.1, -0.12, 0.18) * k
		L(hook, w + Vector3.new(0, 0.02, 0.04), back, 0.05)
		L(hook, back, back + Vector3.new(0.02, -0.12, 0.05) * k, 0.03)
	end

	-- 목: 머리 없음. 가슴에서 이어진 목 → 랩·테이프를 여러 번 감아 봉한 그루터기(고리 두 줄)
	local hdir = (hc - nb).Unit
	tube("NeckStump", { nb - ax * 0.3, nb, nb:Lerp(hc, 0.5), hc, hc + hdir * 0.25 }, { 0.32, 0.25, 0.22, 0.2 })
	table.insert(balls, { bone = "NeckStump", c = hc + hdir * 0.22, r = 0.19 })
	L("NeckStump", nb:Lerp(hc, 0.55) - hdir * 0.02, nb:Lerp(hc, 0.55) + hdir * 0.02, 0.27)
	L("NeckStump", nb:Lerp(hc, 0.85) - hdir * 0.02, nb:Lerp(hc, 0.85) + hdir * 0.02, 0.27)

	-- 붉은 랩 가닥(유일한 붉은 선): 골반에서 3.2 늘어진 2마디 진자. 위장 중에도 남는 단 하나의 단서
	local s0 = P - up * 0.3
	local s1 = s0 + Vector3.new(0.07, -1.55, 0.25)
	local s2 = s0 + Vector3.new(0.25, -3.3, 0.6)
	bone("Strand1", "Pelvis", s0, s1)
	bone("Strand2", "Strand1", s1, s2)
	L("Strand1", s0, s1, 0.05, true)
	L("Strand2", s1, s1:Lerp(s2, 0.5) + Vector3.new(0.04, 0, -0.05), 0.045, true)
	L("Strand2", s1:Lerp(s2, 0.5) + Vector3.new(0.04, 0, -0.05), s2, 0.04, true)

	Rig.build(model, root, cf, {
		id = "c2n",
		bones = bones,
		lines = lines,
		balls = balls,
		floorY = FLOOR,
		mass = 0.5,
	})
	Rig.humanoid(model, HIP, M.cfg.WanderSpeed)
	return model
end

-- 위장 중: 그 자리에 멈춘다(기본 AI 건너뜀). 잡기 판정은 Monster 쪽에서 계속 돈다 = 밑을 지나가면 떨어진다
function M.tick(self: any, now: number): boolean
	local d = self.cdata
	if d.wrapUntil then
		if now < d.wrapUntil then
			self.hum:MoveTo(self.root.Position)
			return true
		end
		d.wrapUntil = nil
		self.model:SetAttribute("Wrap", false)
		self:setState(self.state) -- (상태에 맞는 속도로 되돌림)
	end
	if self.state == "Chase" then
		-- 던지기: 앞 갈고리 둘만 걸고 몸을 앞으로 던진다(1.2초마다), 그다음 다시 거는 동안 느림
		local cyc = (now % THROW_CYCLE) / THROW_CYCLE
		self.hum.WalkSpeed = if cyc < 0.4 then THROW_FAST else THROW_SLOW
	end
	return false
end

-- 음파에 맞는 순간 몸을 말아 짐으로 위장(0.4초, 클라이언트). 음파를 다시 맞을 때마다 4초 연장
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
	if kind ~= "Sonar" then
		return false
	end
	if not sonarHit(self, pos, radius) then
		return false
	end
	local d = self.cdata
	if not d.wrapUntil then
		self.model:SetAttribute("Wrap", true)
	end
	d.wrapUntil = os.clock() + 4
	self.hum:MoveTo(self.root.Position)
	return true
end

return M
