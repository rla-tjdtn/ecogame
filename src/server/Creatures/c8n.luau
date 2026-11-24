--!strict
-- c8n 둥글게 (8장 폐유치원 · 비인간형) — 사양서: roster/v5/ch8/c8n_spec.md
-- 머리 없는 성인 어깨 여섯(잘린 목 그루터기 + 빗장뼈 + 윗가슴 조각)이 팔 열두 개로 손을 맞잡아 지름 8의 고리를 만든다.
-- 맞잡은 손 다섯 쌍이 바닥을 딛는 발이다. 한 자리만 손이 비어 있고(빈자리 = 너), 그 두 손은 바깥으로 열려 있다 — 왼쪽 손가락이 붉다.
-- 뼈: RingRoot(고리 회전) → Yoke1..6(방사형) → Yoke*_ClavP/M → Arm*{P,M}_Up → Arm*{P,M}_Fore, Clasp1..5(RingRoot 직속 디딤),
--     빈 손 둘만 쥐었다 펴는 손 뼈 Arm6P_Hand·Arm1M_Hand. 머리·척추·다리 없음.
-- 고리는 서버 시계로 초당 25° 돈다(클라이언트와 같은 각도 → 서버가 빈자리 방향을 안다).
-- 공포 장치 「빈 손」: 쫓다가 대상이 고리 안(3.5)에 들어오면 둘러싼 채 대상을 따라 천천히(4) 미끄러지며 반지름을 초당 0.3씩 좁힌다(RingR 속성).
--   2.5 에 닿으면 잡힌다. 고리 밖으로 나가는 길은 빈자리(붉은 손 쪽 틈) 하나 — 거기로 빠지면 1.5초 멈칫, 다른 곳으로 넘으면 팔에 잡힌다.
local Rig = require(script.Parent.Rig)

local M = {}
M.cfg = {
	WanderSpeed = 4,
	InvestigateSpeed = 7,
	ChaseSpeed = 11,
	AgentRadius = 1.8, -- 폭 8 고리: 기는 통로(3)는 못 들어간다
	AgentHeight = 4,
	CatchDistance = 0.9, -- (기본 잡기는 거의 안 쓰임 — 실제 잡기는 고리 규칙)
}
M.spawnLift = 2
M.voice = "5" -- (소리: 전용 소리 전까지 '곤충 걸음' 계열 — 매듭 디딤 톡톡)

local HIP = 1
local FLOOR = -(HIP + 1)
local R0 = 4 -- 고리 반지름
local R_MIN = 2.5
local SHRINK = 0.3
local SPIN = math.rad(25) -- 초당 회전(서버 시계)
local SH_Y = 2.35 -- 어깨 높이
local GAP = math.rad(-90) -- 빈자리 가운데(고리 로컬 각)
local GAP_HALF = math.rad(32) -- 빈자리로 빠졌다고 보는 각도 폭

local function dir(a: number): Vector3
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

local function ik(a: Vector3, c: Vector3, l1: number, l2: number, pole: Vector3): Vector3
	local d = c - a
	local dist = math.clamp(d.Magnitude, 0.05, l1 + l2 - 0.01)
	local dd = d.Unit
	local x = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
	local h = math.sqrt(math.max(0, l1 * l1 - x * x))
	local side = pole - a
	side = side - dd * side:Dot(dd)
	if side.Magnitude < 1e-3 then
		side = Vector3.new(0, 1, 0)
	end
	return a + dd * x + side.Unit * h
end

function M.build(cf: CFrame): Model
	local model, root = Rig.shell("Ring", cf, Vector3.new(1.4, 2, 1.4))
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
	local up = Vector3.new(0, 1, 0)
	local y0 = FLOOR + SH_Y
	bone("RingRoot", nil, Vector3.new(0, y0, 0), Vector3.new(0, y0, -1))
	-- 맞잡은 손(디딤) 다섯: 두 요크 사이, 바닥
	local claspAt: { Vector3 } = {}
	for k = 1, 5 do
		local a = GAP + math.rad(60 * k)
		local c = dir(a) * R0 + Vector3.new(0, FLOOR + 0.18, 0)
		claspAt[k] = c
		bone("Clasp" .. k, "RingRoot", c, c + up * 0.4)
		-- 겹친 손 하나의 단순 외곽: 손등 덩어리(원) + 손가락 마디가 엇갈린 짧은 선
		table.insert(balls, { bone = "Clasp" .. k, c = c + Vector3.new(0, 0.05, 0), r = 0.22 })
		local t = Vector3.new(-math.sin(a), 0, math.cos(a))
		L("Clasp" .. k, c - t * 0.3 + dir(a) * 0.12, c + t * 0.3 - dir(a) * 0.12, 0.05)
	end
	-- 요크 여섯
	for i = 1, 6 do
		local a = GAP + math.rad(30 + 60 * (i - 1))
		local u, t = dir(a), Vector3.new(-math.sin(a), 0, math.cos(a))
		local yc = u * R0 + Vector3.new(0, y0, 0)
		local yn = "Yoke" .. i
		bone(yn, "RingRoot", yc, yc + up * 0.5)
		-- 잘린 목 그루터기: 짧은 목 + 단면(원)
		local nb = yc + up * 0.08
		L(yn, nb, nb + up * 0.42 + u * 0.05, 0.2)
		L(yn, nb + up * 0.42 + u * 0.05 - up * 0.02, nb + up * 0.44 + u * 0.05, 0.22)
		-- 잘려 나간 윗가슴: 닫힌 상자(인형 몸통)가 아니라 어깨 끝에서 겨드랑이로 떨어지는 삼각근 두 획 + 등의 견갑 두 획(가운데가 낮은 V)
		local sp, sm = yc + t * 0.78 - up * 0.08, yc - t * 0.78 - up * 0.08
		L(yn, sp, sp - up * 0.5 - t * 0.12 + u * 0.05, 0.1)
		L(yn, sm, sm - up * 0.5 + t * 0.12 + u * 0.05, 0.1)
		local back = yc + u * 0.3 - up * 0.55
		L(yn, yc + t * 0.6 + u * 0.22 - up * 0.12, back, 0.06)
		L(yn, yc - t * 0.6 + u * 0.22 - up * 0.12, back, 0.06)
		-- 빗장뼈 둘(목 밑에서 양 어깨 끝으로) = 뼈 ClavP(+t, 다음 요크 쪽)·ClavM(-t)
		for _, s in { { "P", 1, sp }, { "M", -1, sm } } do
			local tag, sg, tipP = s[1] :: string, s[2] :: number, s[3] :: Vector3
			local cn = yn .. "_Clav" .. tag
			bone(cn, yn, nb, tipP)
			L(cn, nb - u * 0.08, tipP, 0.09)
			-- 팔: 어깨 끝 → 팔꿈치(바깥 위로 꺾임) → 손. 빈자리 양옆 팔(6P·1M)은 바깥으로 손을 연다
			local empty = (i == 6 and tag == "P") or (i == 1 and tag == "M")
			local upN, foreN = "Arm" .. i .. tag .. "_Up", "Arm" .. i .. tag .. "_Fore"
			local l1, l2 = 1.31, 1.78
			local hand: Vector3
			if empty then
				l1, l2 = 1.3, 1.12
				hand = dir(GAP - sg * math.rad(13)) * (R0 + 0.9) + Vector3.new(0, FLOOR + 1.35, 0)
			else
				hand = claspAt[if tag == "P" then i else i - 1] + up * 0.05
			end
			local el = ik(tipP, hand, l1, l2, tipP + u * 0.5 + up * 1.2)
			bone(upN, cn, tipP, el)
			bone(foreN, upN, el, hand)
			-- 마른 사람 팔: 위팔·아래팔 한 획씩, 팔꿈치는 꺾임으로만(공 없음)
			L(upN, tipP, el, 0.12)
			L(foreN, el, hand, 0.1)
			if empty then
				-- 빈 손: 손바닥이 바깥을 향해 열리고 손가락 넷 + 엄지가 벌어진다. 왼쪽(6P) 손이 붉다
				local hn = "Arm" .. i .. tag .. "_Hand"
				local out = dir(GAP - sg * math.rad(13))
				local side = Vector3.new(-out.Z, 0, out.X) * sg
				local palm = hand + out * 0.4
				bone(hn, foreN, hand, palm)
				local red = i == 6
				L(hn, hand, palm, 0.09, red)
				for f = 1, 4 do
					local spread = (f - 2.5) * 0.17
					local fd = (out + side * spread + up * (0.12 - math.abs(spread) * 0.2)).Unit
					L(hn, palm + side * spread * 0.4, palm + side * spread * 0.4 + fd * (if f == 2 or f == 3 then 0.55 else 0.45), 0.04, red)
				end
				L(hn, hand + out * 0.12 - side * 0.12, hand + out * 0.3 - side * 0.42 + up * 0.08, 0.04, red) -- 엄지
			end
		end
	end
	Rig.build(model, root, cf, {
		id = "c8n",
		bones = bones,
		lines = lines,
		balls = balls,
		floorY = FLOOR,
		mass = 0.8,
	})
	Rig.humanoid(model, HIP, M.cfg.WanderSpeed)
	return model
end

-- 고리 회전(서버 시계 — 클라이언트와 같은 값)
local function spinNow(): number
	return (workspace:GetServerTimeNow() * SPIN) % (math.pi * 2)
end

local function endRing(self: any)
	local d = self.cdata
	d.ring = false
	self.model:SetAttribute("RingR", R0)
	self:setState(self.state)
end

local function caught(self: any, p: Player, at: Vector3)
	endRing(self)
	self:note("ring closed on " .. p.Name)
	self.onCatch(p, self)
	self.target = nil
	self.searchCenter = at
	self.searchUntil = os.clock() + 9
	self:setState("Search")
	self.waypoints = {}
end

function M.tick(self: any, now: number): boolean
	local d = self.cdata
	local dt = math.clamp(now - (d.last or now), 0, 0.5)
	d.last = now
	if d.stunUntil then
		if now < d.stunUntil then
			self.hum:MoveTo(self.root.Position)
			return true
		end
		d.stunUntil = nil
		self:setState(self.state)
	end
	local t = self.target
	local char = t and t.Character
	local troot = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local valid = self.state == "Chase" and troot ~= nil and t:GetAttribute("Status") == "Alive" and t:GetAttribute("Hidden") ~= true
	if valid and self.isSafe and self.isSafe(troot.Position) then
		valid = false
	end
	if not d.ring then
		if valid then
			local my = self.root.Position
			local tp = troot.Position
			local flat = Vector3.new(tp.X - my.X, 0, tp.Z - my.Z).Magnitude
			if flat < R0 - 0.5 and math.abs(tp.Y - my.Y) < 5 then
				-- 둘러쌌다
				d.ring = true
				d.r = R0
				self.model:SetAttribute("RingR", R0)
				self:note("ring around " .. t.Name)
			end
		end
		if not d.ring then
			return false
		end
	end
	if not valid then
		endRing(self)
		return false
	end
	local my = self.root.Position
	local tp = troot.Position
	local off = Vector3.new(tp.X - my.X, 0, tp.Z - my.Z)
	local flat = off.Magnitude
	d.r = math.max(R_MIN, d.r - SHRINK * dt)
	if math.abs((self.model:GetAttribute("RingR") or R0) - d.r) > 0.04 then
		self.model:SetAttribute("RingR", d.r)
	end
	self.lastSeen = now
	self.lastKnown = tp
	if flat > d.r + 0.6 then
		-- 고리를 넘어 나갔다: 빈자리(지금 회전한 각도)로 빠졌는가
		local gl = GAP - spinNow()
		local gapW = self.root.CFrame:VectorToWorldSpace(dir(gl))
		local ang = math.acos(math.clamp(off.Unit:Dot(Vector3.new(gapW.X, 0, gapW.Z).Unit), -1, 1))
		if ang < GAP_HALF then
			self:note("slipped out through the gap")
			endRing(self)
			d.stunUntil = now + 1.5
			self.model:SetAttribute("Stun", now)
			self.hum:MoveTo(my)
			return true
		end
		caught(self, t, tp)
		return true
	end
	if d.r <= R_MIN + 0.01 and flat < d.r then
		caught(self, t, tp)
		return true
	end
	-- 둘러싼 채 대상을 따라 천천히 돌며 미끄러진다(가운데에 가까우면 그 자리에서 돌며 좁히기만)
	self.hum.WalkSpeed = 4
	self.hum:MoveTo(if flat > 1.2 then tp else my)
	return true
end

return M
