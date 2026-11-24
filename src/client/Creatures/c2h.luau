--!strict
-- c2h 틈사람: 두 발 무게 이동(뒤꿈치 → 발볼 → 발끝). 위팔은 묶여 고정(팔 흔들기 없음), 머리는 돌지 않는다.
-- 납작한 판 몸이라 걸음마다 Chest 가 옆으로 ±4° 휘청이고, 머리판은 늘 옆(얼굴 쪽)으로 기울어 있다.
-- 서버 속성: Echo(플레이어 발소리 0.15초 뒤 같은 발소리) · Slide(칼날로 서서 틈을 넘어옴: 옆 기울기 22°, 0.6초).
local A = require(script.Parent.Parent.CreatureAnim)

local M = {}
local STRIDE = 3.0 -- 한 주기(두 걸음)에 몸이 가는 거리
local DUTY = 0.6
local LIFT = 0.45
local REF = 6

local function angOf(z: number, y: number): number
	return math.atan2(-z, -y) -- 아래 = 0, 앞(-Z)으로 +
end

-- 옆 평면(Y,Z) 2마디 IK: 무릎은 앞으로 굽는다
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

-- 한 발의 보행 곡선: 디딤(앞 → 뒤, 바닥) / 들기(뒤 → 앞, 들어 올림). contact = 이번 프레임에 착지
local function footCurve(phase: number, prev: number, o: number): (number, number, number, boolean)
	local q, qp = (phase + o) % 1, (prev + o) % 1
	local half = DUTY * STRIDE / 2
	local z, h, pitch
	if q < DUTY then
		local s = q / DUTY
		z = -half + 2 * half * s
		h = 0
		pitch = if s < 0.25 then 0.3 * (1 - s / 0.25) elseif s > 0.7 then -0.55 * (s - 0.7) / 0.3 else 0
	else
		local s = (q - DUTY) / (1 - DUTY)
		z = half - 2 * half * (0.5 - 0.5 * math.cos(s * math.pi))
		h = LIFT * math.sin(s * math.pi)
		pitch = if s < 0.4 then -0.55 * (1 - s / 0.4) else 0.3 * (s - 0.4) / 0.6
	end
	if pitch < 0 then
		h += -pitch * 0.5 -- 발끝으로 밀 때 발목이 들린다
	end
	return z, h, pitch, qp > q
end

function M.init(b: A.Body)
	b.data.amp = 0
	b.data.lastEcho = b.model:GetAttribute("Echo")
	b.data.lastSlide = b.model:GetAttribute("Slide")
	b.data.echoAt = -1
	b.data.slide = -1
	b.data.lean = 0
end

function M.step(b: A.Body, dt: number)
	local d = b.data
	d.amp = A.approach(d.amp, math.clamp(b.speed / REF, 0, 1.3), 6, dt)
	local prev = b.phase
	b.phase = (b.phase + b.speed * dt / STRIDE) % 1
	local amp = math.min(d.amp, 1)
	local dir = if b.vel.Z > 0.5 then -1 else 1 -- 뒷걸음질이면 같은 주기를 거꾸로
	-- 골반: 착지 때 낮고 넘김 때 높다(+0.15), 디딤발 쪽으로 옆 이동
	local ph = b.phase
	local bob = -0.15 * math.cos(ph * math.pi * 4) * amp + 0.02 * math.sin(b.t * 1.7)
	local sway = -0.07 * math.cos((ph - DUTY / 2) * math.pi * 2) * amp
	local pOff = Vector3.new(sway, bob, 0)
	local pRx = 0.05 * amp -- 걸을 때 살짝 앞으로
	A.pose(b, "Pelvis", pRx, 0, sway * 0.6, pOff)
	-- 다리
	local pelvisPos = b.rest.Pelvis.Position + pOff
	for i, n in { "L", "R" } do
		local hip = pelvisPos + b.rest["Thigh" .. n].Position
		local ankle = b.rest.Pelvis.Position + b.rest["Thigh" .. n].Position + b.tip["Thigh" .. n] + b.tip["Shin" .. n]
		local z, h, pitch, contact = footCurve(ph, prev, if i == 1 then 0 else 0.5)
		local target = ankle + Vector3.new(0, h * amp, z * amp * dir)
		local tRx, sRx = legIK(b, "Thigh" .. n, "Shin" .. n, hip, target, pRx)
		A.pose(b, "Thigh" .. n, tRx, 0, 0)
		A.pose(b, "Shin" .. n, sRx, 0, 0)
		A.pose(b, "Foot" .. n, pitch * amp - tRx - sRx - pRx, 0, 0)
		if contact and amp > 0.3 then
			b.step(b.root.CFrame:PointToWorldSpace(target), math.clamp(b.speed / 10, 0.3, 1.3))
		end
	end
	-- 메아리 발소리(서버 Echo): 0.15초 뒤
	local echo = b.model:GetAttribute("Echo")
	if echo ~= d.lastEcho then
		d.lastEcho = echo
		d.echoAt = b.t + 0.15
	end
	if d.echoAt > 0 and b.t >= d.echoAt then
		d.echoAt = -1
		b.step(b.root.Position + Vector3.new(0, -3, 0), 0.6)
	end
	-- 틈 넘어오기(서버 Slide): 칼날로 서서 옆으로 22° 기울었다 돌아옴
	local sl = b.model:GetAttribute("Slide")
	if sl ~= d.lastSlide then
		d.lastSlide = sl
		d.slide = 0
	end
	local leanT = 0
	if d.slide >= 0 then
		d.slide += dt
		leanT = math.rad(22) * math.sin(math.clamp(d.slide / 0.6, 0, 1) * math.pi)
		if d.slide > 0.6 then
			d.slide = -1
		end
	end
	d.lean = A.approach(d.lean, leanT, 12, dt)
	-- 상체: 판이 걸음마다 옆으로 휘청(±4°), 팔은 고정. 쉬는 동안 아주 느린 숨
	local wob = math.rad(4) * math.sin(ph * math.pi * 2) * amp
	A.pose(b, "Spine", 0.03 * math.sin(b.t * 1.1), 0, -sway * 0.4)
	A.pose(b, "Chest", 0, 0, wob + d.lean)
	-- 머리판: 늘 얼굴(+X) 쪽으로 기울어 옆을 본다, 걸음에 늦게 따라 흔들림
	A.pose(b, "Neck", -0.06, 0, math.rad(-12) - wob * 0.6)
	A.pose(b, "HeadPlate", 0.04 * math.sin(b.t * 0.7), 0, math.rad(-6) - wob * 0.4)
	-- 출입증: 진자
	A.pose(b, "Badge", 0.25 * math.sin(ph * math.pi * 4) * amp + 0.05 * math.sin(b.t * 2), 0, 0)
	-- 손: 손끝이 걸음에 따라 엉덩이 옆을 쓸어내린다(아래팔만 살짝)
	A.pose(b, "ForearmL", 0.08 * math.sin(ph * math.pi * 2) * amp, 0, 0)
	A.pose(b, "ForearmR", -0.08 * math.sin(ph * math.pi * 2) * amp, 0, 0)
end

return M
