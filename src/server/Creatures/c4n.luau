--!strict
-- c4n 운구대 (4장 폐병원 · 비인간형) — 사양서: roster/v5/ch4/c4n_spec.md
-- 영안실 운반 카트(바퀴 4) 위에 엎드린 채 등 솔기로 하나로 꿰매진 세 구의 몸. 머리는 맨 앞 하나만 남아 카트 앞끝 밖으로
-- 늘어져 바닥을 본다(정수리에 톱 자국 한 줄). 여섯 팔이 카트 양옆으로 늘어져 바닥을 노 젓듯 밀어 카트째 굴러간다.
-- 뒤로는 종아리째 들린 두 발, 왼 엄지발가락에 붉은 영안실 이름표(유일한 붉은 선).
-- 뼈: tray → caster×4 / spine0(뒤 골반) → spine1(뒤 몸) → spine2(가운데 몸) → spine3(앞 몸) → neck → head,
--     sh/el/wr{1..3}{L,R}(spine1..3 마다 팔 한 쌍), shinL/R → footL/R(spine0), tag(footL)
-- 공포 장치 「직선 돌진」: 쫓는 대상이 시야 직선(6~40) 안에 있거나, 직선 안에서 음파·달리기 소리가 나면
--   0.6초 "철썩" 예고(Slap 속성) 뒤 그 방향으로 잠근 채 22로 돌진한다(방향 못 바꿈, 최대 2.6초).
--   막히면(벽) 2초 멈춤(Crash 속성) 뒤 다시 기본 AI. 돌진 사이 3초 쉼.
local Rig = require(script.Parent.Rig)

local M = {}
M.cfg = {
	WanderSpeed = 3, -- 물결 젓기(앞 → 가운데 → 뒤)
	InvestigateSpeed = 7,
	ChaseSpeed = 9, -- 직선이 아닐 땐 느리다(조향이 어렵다). 직선에선 돌진 22
	AgentRadius = 1.6,
	AgentHeight = 5,
	CatchDistance = 3.2,
}
M.spawnLift = 2
M.voice = "4" -- (소리: 전용 소리 전까지 '쿵 걸음' 계열 — 손바닥 철썩·카트 덜컹)

local HIP = 1
local FLOOR = -(HIP + 1)
local CHARGE_SPEED = 22
local WINDUP = 0.6
local CRASH_STOP = 2
local REST = 3

-- 시안 좌표(x 옆, y 바닥에서, z 앞 = +) → 루트 기준(앞 = -Z)
local function W(x: number, y: number, z: number): Vector3
	return Vector3.new(x, FLOOR + y, -z)
end

local function ik(a: Vector3, c: Vector3, l1: number, l2: number, pole: Vector3): Vector3
	local d = c - a
	local dist = math.clamp(d.Magnitude, 0.05, l1 + l2 - 0.01)
	local dir = d.Unit
	local x = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
	local h = math.sqrt(math.max(0, l1 * l1 - x * x))
	local side = pole - a
	side = side - dir * side:Dot(dir)
	if side.Magnitude < 1e-3 then
		side = Vector3.new(0, 1, 0)
	end
	return a + dir * x + side.Unit * h
end

function M.build(cf: CFrame): Model
	local model, root = Rig.shell("Gurney", cf, Vector3.new(2, 2, 3))
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
	local TY, HW, HL, WR = 2.0, 1.15, 3.2, 0.36
	local BY = TY + 0.55 -- 몸 바닥(엎드린 가슴) 높이
	-- ── 카트: 쟁반 테두리 + 다리 4 + 아래 선반 + 바퀴(6각 원 + 바퀴살, 다리 끝 포크에 붙음) ──
	bone("tray", nil, W(0, TY, 0), W(0, TY, 1))
	local c = { W(HW, TY, HL), W(-HW, TY, HL), W(-HW, TY, -HL), W(HW, TY, -HL) }
	for i = 1, 4 do
		L("tray", c[i], c[i % 4 + 1], 0.06)
	end
	local sh = { W(HW - 0.15, 1.0, HL - 0.35), W(-(HW - 0.15), 1.0, HL - 0.35), W(-(HW - 0.15), 1.0, -(HL - 0.35)), W(HW - 0.15, 1.0, -(HL - 0.35)) }
	for i = 1, 4 do
		L("tray", sh[i], sh[i % 4 + 1], 0.05)
	end
	for _, w in { { "casterFL", 1, 1 }, { "casterFR", -1, 1 }, { "casterRL", 1, -1 }, { "casterRR", -1, -1 } } do
		local name, x, z = w[1] :: string, w[2] :: number, w[3] :: number
		local top = W(x * (HW - 0.15), TY - 0.12, z * (HL - 0.35))
		local hub = W(x * (HW - 0.15), WR, z * (HL - 0.35) - 0.18)
		L("tray", top, W(x * (HW - 0.15), 0.62, z * (HL - 0.35)), 0.06) -- 다리
		bone(name, "tray", hub, hub + Vector3.new(0, WR, 0))
		L(name, W(x * (HW - 0.15), 0.62, z * (HL - 0.35)), hub, 0.05) -- 포크
		L(name, hub - Vector3.new(0.05, 0, 0), hub + Vector3.new(0.05, 0, 0), WR) -- 바퀴(원)
		L(name, hub + Vector3.new(0, WR * 0.9, 0), hub - Vector3.new(0, WR * 0.9, 0), 0.03) -- 바퀴살(구름이 보이게)
	end
	-- ── 세 몸: 뒤(spine1, z -1.75) · 가운데(spine2, 0) · 앞(spine3, 1.75). 몸마다 어깨 → 잘록한 허리 → 골반 외곽(양옆),
	--    등줄기 고랑, 솟은 견갑, 몸 사이엔 뒤 몸 골반에 맞닿은 앞 몸의 잘린 목 자리(원) + 가로 솔기 두 줄 ──
	bone("spine0", "tray", W(0, BY + 0.3, -2.95), W(0, BY + 0.3, -1.75))
	local Z3 = { -1.75, 0, 1.75 }
	for k = 1, 3 do
		local zc = Z3[k]
		local name = "spine" .. k
		bone(name, if k == 1 then "spine0" else "spine" .. (k - 1), W(0, BY + 0.4, zc - 1.0), W(0, BY + 0.4, zc + 0.6))
		local prof = { { zc + 0.62, 0.78 }, { zc + 0.2, 1.0 }, { zc - 0.45, 0.66 }, { zc - 1.05, 0.84 }, { zc - 1.38, 0.62 } }
		for _, s in { 1, -1 } do
			for i = 1, #prof - 1 do
				L(name, W(s * prof[i][2], BY + 0.38, prof[i][1]), W(s * prof[i + 1][2], BY + 0.38, prof[i + 1][1]), 0.1)
			end
			-- 솟은 견갑뼈
			L(name, W(s * 0.16, BY + 0.92, zc + 0.42), W(s * 0.6, BY + 0.8, zc - 0.1), 0.08)
		end
		-- 등줄기 고랑: 어깨에서 골반까지
		L(name, W(0, BY + 0.95, zc + 0.55), W(0, BY + 0.72, zc - 1.2), 0.07)
		if k < 3 then
			-- 다음(앞) 몸의 잘린 목 자리 + 가로 솔기 두 줄
			local sz = Z3[k + 1] + 0.72
			L("spine" .. (k + 1), W(0, BY + 0.62, sz + 0.1), W(0, BY + 0.62, sz + 0.16), 0.4)
			for _, dz in { -0.12, 0.08 } do
				L("spine" .. (k + 1), W(0.78, BY + 0.5, sz + dz), W(-0.78, BY + 0.5, sz + dz), 0.05)
			end
		end
	end
	-- ── 목 + 머리: 카트 앞끝 밖으로 꺾여 바닥을 향해 늘어짐. 정수리를 두른 톱 자국 한 줄 ──
	local neckA, neckJ = W(0, BY + 0.55, 2.45), W(0, BY + 0.15, 3.15)
	local headC = W(0.04, BY - 0.85, 3.55)
	bone("neck", "spine3", neckA, neckJ)
	bone("head", "neck", neckJ, headC)
	L("neck", neckA, neckJ, 0.28)
	L("head", neckJ, headC + Vector3.new(0, 0.42, 0), 0.24)
	table.insert(balls, { bone = "head", c = headC, r = 0.44 })
	L("head", headC + Vector3.new(-0.42, 0.1, 0.12), headC + Vector3.new(0.42, 0.1, 0.12), 0.03) -- 톱 자국(옆으로 둘러)
	-- ── 여섯 팔: 어깨(견갑 옆) → 팔꿈치(위로 꺾임) → 손목 → 평평한 손바닥 + 벌린 손가락. 손은 바닥 ──
	for k = 1, 3 do
		local zc = Z3[k]
		for _, s in { 1, -1 } do
			local side = if s > 0 then "L" else "R"
			local shp = W(s * 0.92, BY + 0.02, zc + 0.1)
			local hand = W(s * 2.05, 0.1, zc + 0.15)
			local el = ik(shp, hand, 1.42, 1.36, shp + Vector3.new(s * 0.6, 1, 0.5)) -- (마른 팔: 팔꿈치가 위로 꺾임)
			local hEnd = hand + Vector3.new(s * 0.2, -0.04, -0.4)
			local shN, elN, wrN = "sh" .. k .. side, "el" .. k .. side, "wr" .. k .. side
			bone(shN, "spine" .. k, shp, el)
			bone(elN, shN, el, hand)
			bone(wrN, elN, hand, hEnd)
			L(shN, shp, el, 0.14)
			L(elN, el, hand, 0.11)
			table.insert(balls, { bone = elN, c = el, r = 0.1 })
			-- 손바닥(평평) + 벌린 손가락 둘(바깥·앞)
			L(wrN, hand, hEnd, 0.08)
			L(wrN, hEnd, hEnd + Vector3.new(s * 0.32, -0.02, -0.12), 0.04)
			L(wrN, hEnd, hEnd + Vector3.new(-s * 0.05, -0.02, -0.36), 0.04)
		end
	end
	-- ── 들린 두 발(종아리째) + 왼 엄지발가락의 붉은 이름표(끈 + 종이표 네 변) ──
	for _, f in { { "L", 1 }, { "R", -1 } } do
		local s = f[2] :: number
		local shinJ = W(s * 0.31, BY + 0.15, -3.02)
		local foot = W(s * 1.05, BY + 1.05, -3.85) -- (뒤·바깥으로 벌어져 정면에서 귀처럼 서 보이지 않게)
		local shinN, footN = "shin" .. f[1], "foot" .. f[1]
		bone(shinN, "spine0", shinJ, foot)
		L(shinN, shinJ, foot, 0.16)
		local toe = foot + Vector3.new(s * 0.15, 0.25, 0.85) -- 발가락이 뒤(+Z)·위로: 발바닥이 하늘을 본다
		bone(footN, shinN, foot, toe)
		L(footN, foot, toe, 0.12)
		-- 하늘을 보는 발바닥(뒤꿈치 가로 + 발가락 쪽 가로)
		L(footN, foot + Vector3.new(-0.2, 0.02, 0.05), foot + Vector3.new(0.2, 0.02, 0.05), 0.05)
		L(footN, toe + Vector3.new(-0.24, -0.05, -0.1), toe + Vector3.new(0.24, -0.05, -0.1), 0.05)
	end
	local toe = W(1.05, BY + 1.05, -3.85) + Vector3.new(0.15, 0.25, 0.85)
	local tg = toe + Vector3.new(0.05, -0.85, 0.25)
	bone("tag", "footL", toe, tg)
	L("tag", toe, toe + Vector3.new(0.03, -0.35, 0.12), 0.03, true)
	L("tag", toe + Vector3.new(0.03, -0.35, 0.12), tg, 0.03, true)
	local tp = { tg + Vector3.new(-0.3, 0, 0), tg + Vector3.new(0.3, 0, 0), tg + Vector3.new(0.32, -0.75, 0.08), tg + Vector3.new(-0.28, -0.75, 0.08) }
	for i = 1, 4 do
		L("tag", tp[i], tp[i % 4 + 1], 0.03, true)
	end
	Rig.build(model, root, cf, {
		id = "c4n",
		bones = bones,
		lines = lines,
		balls = balls,
		floorY = FLOOR,
		mass = 1.2,
	})
	Rig.humanoid(model, HIP, M.cfg.WanderSpeed)
	return model
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- 예고(철썩 두 번) 시작: 방향은 지금 대상 쪽으로 잠근다
local function windup(self: any, at: Vector3, now: number)
	local d = self.cdata
	local dir = flat(at - self.root.Position)
	if dir.Magnitude < 1 then
		return
	end
	d.mode = "windup"
	d.dir = dir.Unit
	d.modeEnd = now + WINDUP
	self.model:SetAttribute("Slap", now)
	self.hum:MoveTo(self.root.Position + d.dir * 0.3) -- (그쪽을 바라봄)
end

local function finish(self: any, now: number)
	local d = self.cdata
	d.mode = nil
	d.restUntil = now + REST
	self.model:SetAttribute("Charging", false)
	self.waypoints = {}
	self:setState(self.state) -- (상태에 맞는 속도로 되돌림)
end

function M.tick(self: any, now: number): boolean
	local d = self.cdata
	if d.mode == "windup" then
		if now < d.modeEnd then
			self.hum.WalkSpeed = 2
			self.hum:MoveTo(self.root.Position + d.dir * 0.3)
			return true
		end
		d.mode = "charge"
		d.chargeStart = now
		d.modeEnd = now + 2.6
		d.from = self.root.Position
		self.model:SetAttribute("Charging", true)
	end
	if d.mode == "charge" then
		local pos = self.root.Position
		local ahead = pos + d.dir * 3
		local isSafe = self.isSafe
		local vel = flat(self.root.AssemblyLinearVelocity).Magnitude
		if (now - d.chargeStart > 0.4 and vel < 4) or (isSafe and isSafe(ahead)) then
			-- 벽에 박혔다(또는 안전 구역 앞): 2초 멈춤
			d.mode = "crash"
			d.modeEnd = now + CRASH_STOP
			self.model:SetAttribute("Charging", false)
			self.model:SetAttribute("Crash", now)
			self.hum:MoveTo(pos)
			return true
		end
		if now >= d.modeEnd then
			finish(self, now)
			return false
		end
		self.hum.WalkSpeed = CHARGE_SPEED
		self.hum:MoveTo(pos + d.dir * 30)
		return true
	end
	if d.mode == "crash" then
		if now < d.modeEnd then
			self.hum:MoveTo(self.root.Position)
			return true
		end
		finish(self, now)
		return false
	end
	-- 평소: 쫓는 대상이 시야 직선 안이면 돌진
	if self.state == "Chase" and now >= (d.restUntil or 0) then
		local t = self.target
		local char = t and t.Character
		local troot = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if troot and t:GetAttribute("Hidden") ~= true then
			local tp = troot.Position
			local dist = flat(tp - self.root.Position).Magnitude
			if dist > 6 and dist < 40 and math.abs(tp.Y - self.root.Position.Y) < 4 and self:lineOfSight(tp) then
				windup(self, tp, now)
				return true
			end
		end
	end
	return false
end

-- 직선 안에서 음파·달리기 소리: 그쪽을 쫓기 시작하며 곧장 돌진 예고
function M.hear(self: any, pos: Vector3, radius: number, source: Player?, kind: string): boolean
	local d = self.cdata
	if d.mode ~= nil then
		return true -- 돌진·충돌 중엔 다른 소리에 안 끌림
	end
	if not source or (kind ~= "Sonar" and kind ~= "StepRun") then
		return false
	end
	local now = os.clock()
	local dist = flat(pos - self.root.Position).Magnitude
	if dist > radius or dist < 6 or dist > 40 or now < (d.restUntil or 0) then
		return false
	end
	if math.abs(pos.Y - self.root.Position.Y) > 4 or not self:lineOfSight(pos + Vector3.new(0, 1, 0)) then
		return false
	end
	self:startChase(source, pos)
	windup(self, pos, now)
	return true
end

return M
