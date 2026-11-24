--!strict
-- c4h 견인 환자: 줄에 들린 발끝 걸음(뒤꿈치 안 닿음). 오른발은 곧게 딛고, 고정틀 찬 왼다리는 골반을 들어 바깥으로 휘돌린다.
-- 상체는 거의 고정, 긴 목 3마디가 걸음에 늦게 흔들리고 헤일로·줄이 2차로 떨린다.
-- 서버 Ring = 헤일로 울림(고리 떨림 1.2초, 몸이 굳음) → 돌진(빠를 때) 두 손이 번갈아 줄을 감는다.
local A = require(script.Parent.Parent.CreatureAnim)

local M = {}
local STRIDE = 3.6
local DUTY = 0.6
local LIFT = 0.32
local REF = 4.5

local function angOf(z: number, y: number): number
	return math.atan2(-z, -y)
end

local function legIK(b: A.Body, thigh: string, shin: string, hip: Vector3, target: Vector3, parentRx: number): (number, number)
	local T0, S0 = b.tip[thigh], b.tip[shin]
	local l1 = math.sqrt(T0.Y * T0.Y + T0.Z * T0.Z)
	local l2 = math.sqrt(S0.Y * S0.Y + S0.Z * S0.Z)
	local dy, dz = target.Y - hip.Y, target.Z - hip.Z
	local dist = math.clamp(math.sqrt(dy * dy + dz * dz), math.abs(l1 - l2) + 0.01, l1 + l2 - 0.002)
	local phi = angOf(dz, dy)
	local a1 = math.acos(math.clamp((l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist), -1, 1))
	local a2 = math.acos(math.clamp((l2 * l2 + dist * dist - l1 * l1) / (2 * l2 * dist), -1, 1))
	local thighRx = (phi + a1) - angOf(T0.Z, T0.Y) - parentRx
	local shinRx = (phi - a2) - angOf(S0.Z, S0.Y) - thighRx - parentRx
	return thighRx, shinRx
end

-- 발끝 걸음: 디딤 동안 발끝이 바닥, 발 각도는 거의 고정(들린 뒤꿈치)
local function footCurve(phase: number, prev: number, o: number): (number, number, number, number, boolean)
	local q, qp = (phase + o) % 1, (prev + o) % 1
	local half = DUTY * STRIDE / 2
	local z, h, pitch, swing
	if q < DUTY then
		local s = q / DUTY
		z = -half + 2 * half * s
		h = 0
		pitch = -0.12 * s
		swing = 0
	else
		local s = (q - DUTY) / (1 - DUTY)
		z = half - 2 * half * (0.5 - 0.5 * math.cos(s * math.pi))
		h = LIFT * math.sin(s * math.pi)
		pitch = -0.25 * math.sin(s * math.pi) -- 발끝이 늘어진 채 끌려 나간다
		swing = math.sin(s * math.pi)
	end
	return z, h, pitch, swing, qp > q
end

function M.init(b: A.Body)
	b.data.amp = 0
	b.data.lastRing = b.model:GetAttribute("Ring")
	b.data.ring = -1
	b.data.n1 = 0
	b.data.n2 = 0
	b.data.reach = 0
end

function M.step(b: A.Body, dt: number)
	local d = b.data
	d.amp = A.approach(d.amp, math.clamp(b.speed / REF, 0, 1.6), 6, dt)
	local amp = math.min(d.amp, 1)
	local prev = b.phase
	b.phase = (b.phase + b.speed * dt / STRIDE) % 1
	local ph = b.phase
	local dir = if b.vel.Z > 0.5 then -1 else 1
	-- 골반: 오른발 디딤 때 왼쪽 골반을 들어 휘돌림(hike), 위아래 출렁
	local _, _, _, swingL = footCurve(ph, prev, 0)
	local bob = (-0.1 - 0.08 * math.cos(ph * math.pi * 4)) * amp + 0.02 * math.sin(b.t * 1.2) -- (다리가 거의 펴져 있어 아래로만)
	local sway = -0.1 * math.cos((ph - DUTY / 2) * math.pi * 2) * amp
	local hike = math.rad(6) * swingL * amp
	local pOff = Vector3.new(sway, bob, 0)
	A.pose(b, "pelvis", 0, 0, -hike, pOff)
	local pelvisPos = b.rest.pelvis.Position + pOff
	for i, n in { "L", "R" } do
		local hip = pelvisPos + b.rest["hip" .. n].Position
		local ankle = b.rest.pelvis.Position + b.rest["hip" .. n].Position + b.tip["hip" .. n] + b.tip["knee" .. n]
		local z, h, pitch, swing, contact = footCurve(ph, prev, if i == 1 then 0 else 0.5)
		local lift = if i == 1 then h * 0.6 else h -- 왼다리는 들기보다 휘돌림
		local target = ankle + Vector3.new(0, lift * amp, z * amp * dir)
		local tRx, sRx = legIK(b, "hip" .. n, "knee" .. n, hip, target, 0)
		local out = if i == 1 then -math.rad(14) * swing * amp + hike else 0 -- 왼다리 바깥 휘돌림(−X)
		A.pose(b, "hip" .. n, tRx, 0, out)
		A.pose(b, "knee" .. n, sRx, 0, if i == 1 then -out * 0.7 else 0)
		A.pose(b, "ankle" .. n, pitch * amp - tRx - sRx, 0, 0)
		if contact and amp > 0.3 then
			b.step(b.root.CFrame:PointToWorldSpace(target), if i == 1 then 0.6 else 0.9) -- 툭(맨발) — 딸깍(고정틀)
		end
	end
	-- 헤일로 울림
	local rg = b.model:GetAttribute("Ring")
	if rg ~= d.lastRing then
		d.lastRing = rg
		d.ring = 0
	end
	local buzz = Vector3.zero
	local freeze = 0
	if d.ring >= 0 then
		d.ring += dt
		if d.ring < 1.2 then
			local k = 1 - d.ring / 1.2
			buzz = Vector3.new(math.sin(b.t * 251) * 0.03 * k, 0, math.cos(b.t * 233) * 0.03 * k)
			freeze = 1
		else
			d.ring = -1
		end
	end
	-- 긴 목: 걸음에 늦게 따라 흔들림(마디마다 더 늦게), 고개는 못 돌림
	local nk = math.sin((ph - 0.12) * math.pi * 4) * 0.05 * amp
	d.n1 = A.approach(d.n1, nk + sway * 0.5, 6, dt)
	d.n2 = A.approach(d.n2, d.n1, 4, dt)
	A.pose(b, "chest", -0.03 * amp, 0, 0)
	A.pose(b, "neck1", d.n1 * 0.6, 0, -sway * 0.3)
	A.pose(b, "neck2", d.n2, 0, d.n1 * 0.8)
	A.pose(b, "neck3", d.n2 * 0.6 + 0.04 * math.sin(b.t * 0.8), 0, d.n2 * 0.6)
	A.pose(b, "haloRing", 0, 0, 0, buzz)
	-- 견인줄: 움직일수록 뒤로 당겨 펴지고, 천천히 출렁
	A.pose(b, "cord0", 0, 0, 0)
	A.pose(b, "cord1", -0.08 * amp + 0.05 * math.sin(b.t * 1.3), 0.06 * math.sin(b.t * 0.9), 0)
	A.pose(b, "cord2", 0.12 * math.sin(b.t * 1.7 + 0.5) - 0.2 * math.clamp(b.speed / 16, 0, 1), 0, 0)
	-- 팔: 평소 왼손은 기둥을 쥐고 오른팔은 늘어져 흔들림. 울림 땐 굳고, 돌진 땐 두 손이 번갈아 줄을 감아 올린다
	local dash = if b.speed > 10 then 1 else 0
	d.reach = A.approach(d.reach, dash, 6, dt)
	local wind = math.sin(b.t * 12.5) * d.reach
	A.pose(b, "shoulderL", d.reach * (1.2 + 0.4 * wind), 0, 0)
	A.pose(b, "elbowL", -d.reach * 0.6, 0, 0)
	local hang = (0.12 * math.sin(ph * math.pi * 2) * amp) * (1 - freeze)
	A.pose(b, "shoulderR", hang + d.reach * (2.2 - 0.4 * wind), 0, 0.05)
	A.pose(b, "elbowR", d.reach * -0.5 + 0.05 * math.sin(b.t * 1.1), 0, 0)
end

return M
