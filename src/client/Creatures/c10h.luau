--!strict
-- c10h 안내원: 다리만 사람처럼 걷고 등은 늘 수평(골반 출렁임을 상체가 되돌려 등 높이 고정).
-- 머리는 깃에서 매달린 진자(걸음마다 앞뒤 ±6°, 늦게 따라옴), 연미복 꼬리도 흔들림. 추격은 등을 편 채 종종걸음.
-- 서버 Aim(도) = 상체·빔 yaw(훑기·소리 쪽). Rise = 들킨 순간 일어서기(허리 펴짐 0.4초, 머리가 뒤로 꺾여 매달림).
local Players = game:GetService("Players")
local A = require(script.Parent.Parent.CreatureAnim)

local M = {}
local DUTY = 0.6
local REF = 3.5

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

local function footCurve(phase: number, prev: number, o: number, stride: number, lift: number): (number, number, number, boolean)
	local q, qp = (phase + o) % 1, (prev + o) % 1
	local half = DUTY * stride / 2
	local z, h, pitch
	if q < DUTY then
		local s = q / DUTY
		z = -half + 2 * half * s
		h = 0
		pitch = if s < 0.2 then 0.25 * (1 - s / 0.2) elseif s > 0.75 then -0.35 * (s - 0.75) / 0.25 else 0
	else
		local s = (q - DUTY) / (1 - DUTY)
		z = half - 2 * half * (0.5 - 0.5 * math.cos(s * math.pi))
		h = lift * math.sin(s * math.pi)
		pitch = if s < 0.35 then -0.35 * (1 - s / 0.35) else 0.25 * (s - 0.35) / 0.65
	end
	if pitch < 0 then
		h += -pitch * 0.6
	end
	return z, h, pitch, qp > q
end

local function nearestDist(pos: Vector3): number
	local best = math.huge
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r then
			best = math.min(best, (r.Position - pos).Magnitude)
		end
	end
	return best
end

function M.init(b: A.Body)
	b.data.amp = 0
	b.data.yaw = 0
	b.data.head = 0
	b.data.tail = 0
	b.data.lastRise = b.model:GetAttribute("Rise")
	b.data.rise = -1
	b.data.stand = 0
	b.data.check = 0
	b.data.close = false
end

function M.step(b: A.Body, dt: number)
	local d = b.data
	d.amp = A.approach(d.amp, math.clamp(b.speed / REF, 0, 1.6), 7, dt)
	local amp = math.min(d.amp, 1)
	local trot = math.clamp((b.speed - 6) / 3, 0, 1) -- 추격 종종걸음: 보폭은 조금만 늘고 박자가 빨라진다
	local stride = 3.6 + 0.6 * trot
	local prev = b.phase
	b.phase = (b.phase + b.speed * dt / stride) % 1
	local ph = b.phase
	local dir = if b.vel.Z > 0.5 then -1 else 1
	-- 골반: 좌우 0.15 · 위아래(다리가 거의 펴져 있어 보폭에 맞춰 내려감)
	local l = b.tip.kneeL.Magnitude + b.tip.ankleL.Magnitude
	local half = DUTY * stride / 2 * amp
	local dip = l - math.sqrt(math.max(0.1, l * l - half * half))
	local bob = (-dip - 0.04 - 0.1 * math.cos(ph * math.pi * 4)) * amp
	local sway = -0.15 * math.cos((ph - DUTY / 2) * math.pi * 2) * amp
	local pOff = Vector3.new(sway, bob, 0)
	A.pose(b, "pelvis", 0, 0, 0, pOff)
	local pelvisPos = b.rest.pelvis.Position + pOff
	for i, n in { "L", "R" } do
		local hip = pelvisPos + b.rest["hip" .. n].Position + b.rest["knee" .. n].Position
		local ankle = b.rest.pelvis.Position + b.rest["hip" .. n].Position + b.rest["knee" .. n].Position + b.tip["knee" .. n] + b.tip["ankle" .. n]
		local z, h, pitch, contact = footCurve(ph, prev, if i == 1 then 0 else 0.5, stride, 0.35 - 0.1 * trot)
		local target = ankle + Vector3.new(0, h * amp, z * amp * dir)
		local tRx, sRx = legIK(b, "knee" .. n, "ankle" .. n, hip, target, 0)
		A.pose(b, "knee" .. n, tRx, 0, 0)
		A.pose(b, "ankle" .. n, sRx, 0, 0)
		A.pose(b, "toe" .. n, pitch * amp - tRx - sRx, 0, 0)
		if contact and amp > 0.3 then
			b.step(b.root.CFrame:PointToWorldSpace(target), math.clamp(b.speed / 8, 0.4, 1.2)) -- 딱딱한 구두
		end
	end
	-- 일어서기: 들킨 순간(Rise) 0.4초 + 추격 중 아주 가까우면 허리가 펴진다
	local rs = b.model:GetAttribute("Rise")
	if rs ~= d.lastRise then
		d.lastRise = rs
		d.rise = 0
	end
	local standT = 0
	if d.rise >= 0 then
		d.rise += dt
		standT = if d.rise < 0.9 then 1 else 0
		if d.rise >= 0.9 then
			d.rise = -1
		end
	end
	d.check -= dt
	if d.check <= 0 then
		d.check = 0.15
		d.close = b.state == "Chase" and nearestDist(b.root.Position) < 4
	end
	if d.close then
		standT = 1
	end
	d.stand = A.approach(d.stand, standT, if standT > d.stand then 9 else 4, dt)
	-- 상체 yaw(서버 Aim, 도): 빔이 함께 돈다
	local aim = b.model:GetAttribute("Aim")
	local yawT = if typeof(aim) == "number" then math.rad(aim) else 0
	d.yaw = A.approach(d.yaw, yawT, 6, dt)
	-- 등은 수평 유지: 골반 출렁임을 spine1 이 되돌린다. 일어서면 허리가 84° 펴짐
	A.pose(b, "spine1", math.rad(84) * d.stand, d.yaw, -sway * 0.2, Vector3.new(-sway, -bob, 0))
	-- 매달린 머리: 진자(걸음마다 앞뒤 ±6°, 늦게), 일어서면 뒤로 꺾여 매달림
	local headT = math.rad(6) * math.sin((ph - 0.15) * math.pi * 4) * amp + 0.03 * math.sin(b.t * 0.8)
	d.head = A.approach(d.head, headT, 5, dt)
	A.pose(b, "neck", d.head - math.rad(90) * d.stand, 0, d.head * 0.4)
	A.pose(b, "head", d.head * 0.5, 0, 0)
	-- 연미복 꼬리: 걸음·종종걸음에 펄럭
	local tailT = 0.2 * math.sin(ph * math.pi * 4 - 1) * amp + 0.35 * trot
	d.tail = A.approach(d.tail, tailT, 6, dt)
	A.pose(b, "tailL", -d.tail, 0, 0)
	A.pose(b, "tailR", -d.tail * 0.85, 0, 0)
	-- 손전등 팔: 걸을 때도 빔이 등받이 높이에서 흔들리지 않게 거의 고정, 미세한 떨림만
	A.pose(b, "wristR", 0.01 * math.sin(b.t * 3.3), 0, 0)
end

return M
