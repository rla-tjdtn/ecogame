--!strict
-- c3h 마개: 짐꾼 보행(무릎 늘 굽힘, 뒤꿈치 → 발바닥). 무게 이동은 해치 기울기(roll ±8°, 디딤발 쪽)로 보인다.
-- 팔은 테를 쥔 채 고정, 쉬는 동안 손이 번갈아 테를 고쳐 쥔다. 서버 Brace = 멈칫(해치 아랫테를 내리꽂듯 웅크림) → 돌진 자세.
local A = require(script.Parent.Parent.CreatureAnim)

local M = {}
local STRIDE = 3.0
local DUTY = 0.62
local LIFT = 0.3
local REF = 4

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

local function footCurve(phase: number, prev: number, o: number): (number, number, number, boolean)
	local q, qp = (phase + o) % 1, (prev + o) % 1
	local half = DUTY * STRIDE / 2
	local z, h, pitch
	if q < DUTY then
		local s = q / DUTY
		z = -half + 2 * half * s
		h = 0
		pitch = if s < 0.2 then 0.25 * (1 - s / 0.2) elseif s > 0.8 then -0.3 * (s - 0.8) / 0.2 else 0
	else
		local s = (q - DUTY) / (1 - DUTY)
		z = half - 2 * half * (0.5 - 0.5 * math.cos(s * math.pi))
		h = LIFT * math.sin(s * math.pi)
		pitch = if s < 0.35 then -0.3 * (1 - s / 0.35) else 0.25 * (s - 0.35) / 0.65
	end
	if pitch < 0 then
		h += -pitch * 0.4
	end
	return z, h, pitch, qp > q
end

function M.init(b: A.Body)
	b.data.amp = 0
	b.data.lastBrace = b.model:GetAttribute("Brace")
	b.data.brace = -1
	b.data.crouch = 0
	b.data.lean = 0
end

function M.step(b: A.Body, dt: number)
	local d = b.data
	d.amp = A.approach(d.amp, math.clamp(b.speed / REF, 0, 1.4), 6, dt)
	local amp = math.min(d.amp, 1)
	local prev = b.phase
	b.phase = (b.phase + b.speed * dt / STRIDE) % 1
	local ph = b.phase
	local dir = if b.vel.Z > 0.5 then -1 else 1
	-- 멈칫(Brace): 0.4초 동안 웅크려 해치 아랫테를 내림 → 돌진 중엔 앞으로 숙임
	local br = b.model:GetAttribute("Brace")
	if br ~= d.lastBrace then
		d.lastBrace = br
		d.brace = 0
	end
	local crouchT, leanT = 0, 0
	if d.brace >= 0 then
		d.brace += dt
		if d.brace < 0.45 then
			crouchT = 0.45
			leanT = 0.18
		elseif b.speed > 6 then
			leanT = 0.22 -- 돌진: 해치를 세워 앞으로
		elseif d.brace > 1.2 then
			d.brace = -1
		end
	end
	d.crouch = A.approach(d.crouch, crouchT, 14, dt)
	d.lean = A.approach(d.lean, leanT, 8, dt)
	-- 골반: 무거운 짐 — 착지 때 푹 꺼지고(−0.11) 디딤발 쪽으로
	local bob = -0.11 * math.cos(ph * math.pi * 4) * amp - d.crouch + 0.03 * math.sin(b.t * 1.3)
	local sway = -0.12 * math.cos((ph - DUTY / 2) * math.pi * 2) * amp
	local pOff = Vector3.new(sway, bob, 0)
	A.pose(b, "Pelvis", 0, 0, 0, pOff)
	local pelvisPos = b.rest.Pelvis.Position + pOff
	for i, n in { "L", "R" } do
		local hip = pelvisPos + b.rest["Thigh" .. n].Position
		local ankle = b.rest.Pelvis.Position + b.rest["Thigh" .. n].Position + b.tip["Thigh" .. n] + b.tip["Shin" .. n]
		local z, h, pitch, contact = footCurve(ph, prev, if i == 1 then 0 else 0.5)
		local target = ankle + Vector3.new(0, h * amp, z * amp * dir)
		local tRx, sRx = legIK(b, "Thigh" .. n, "Shin" .. n, hip, target, 0)
		A.pose(b, "Thigh" .. n, tRx, 0, 0)
		A.pose(b, "Shin" .. n, sRx, 0, 0)
		A.pose(b, "Foot" .. n, pitch * amp - tRx - sRx, 0, 0)
		A.pose(b, "Toe" .. n, math.max(0, -pitch) * amp * 1.2, 0, 0) -- 밀 때 발가락이 꺾인다
		if contact and amp > 0.3 then
			b.step(b.root.CFrame:PointToWorldSpace(target), math.clamp(b.speed / 7, 0.4, 1.4))
		end
	end
	-- 상체 + 해치: 한 덩어리. 디딤발 쪽으로 roll ±8°, 숨 쉴 때 아주 살짝 들썩
	local roll = math.rad(8) * math.cos((ph - DUTY / 2) * math.pi * 2) * amp
	A.pose(b, "Spine", d.lean + 0.02 * math.sin(b.t * 1.3), 0, roll)
	A.pose(b, "Hatch", 0, 0, -roll * 0.25)
	-- 금 틈 속 눈: 천천히 두리번
	A.pose(b, "EyeSlit", 0, 0, 0, Vector3.new(0.05 * math.sin(b.t * 0.6), 0.03 * math.sin(b.t * 0.9), 0))
	-- 손: 쉬는 동안 0.5초마다 번갈아 테를 고쳐 쥔다
	local idle = 1 - amp
	local g = b.t % 1
	A.pose(b, "RimGripL", if g < 0.25 then 0.35 * math.sin(g / 0.25 * math.pi) * idle else 0, 0, 0)
	A.pose(b, "RimGripR", if g >= 0.5 and g < 0.75 then 0.35 * math.sin((g - 0.5) / 0.25 * math.pi) * idle else 0, 0, 0)
end

return M
