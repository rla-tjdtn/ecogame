--!strict
-- c5h 모서리: 한 평면 안의 두 발 보행. 두 다리(N·F)가 같은 평면에서 가위처럼 엇갈리고, 옆 흔들림은 0 — 위아래로만 출렁인다.
-- 모든 회전은 X 축 하나(평면이 깨지지 않음). 팔은 다리와 반대로, 머리는 늘 숙인 채 고정.
-- 추격(빠를 때)은 달리지 않고 보폭만 커진다(출렁임이 커짐). 서버 Align = 칼날 맞추기 순간 판이 한 번 떨린다.
local A = require(script.Parent.Parent.CreatureAnim)

local M = {}
local DUTY = 0.58
local REF = 7

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
		pitch = if s < 0.2 then 0.22 * (1 - s / 0.2) elseif s > 0.75 then -0.4 * (s - 0.75) / 0.25 else 0
	else
		local s = (q - DUTY) / (1 - DUTY)
		z = half - 2 * half * (0.5 - 0.5 * math.cos(s * math.pi))
		h = lift * math.sin(s * math.pi)
		pitch = if s < 0.35 then -0.4 * (1 - s / 0.35) else 0.22 * (s - 0.35) / 0.65
	end
	if pitch < 0 then
		h += -pitch * 0.9
	end
	return z, h, pitch, qp > q
end

function M.init(b: A.Body)
	b.data.amp = 0
	b.data.stride = 5.2
	b.data.lastAlign = b.model:GetAttribute("Align")
	b.data.align = -1
end

function M.step(b: A.Body, dt: number)
	local d = b.data
	d.amp = A.approach(d.amp, math.clamp(b.speed / REF, 0, 1.5), 6, dt)
	local amp = math.min(d.amp, 1)
	local chase = math.clamp((b.speed - 8) / 3, 0, 1)
	d.stride = A.approach(d.stride, 5.2 + 1.6 * chase, 3, dt) -- 보폭 2.6 → 3.4(걸음 하나)
	local prev = b.phase
	b.phase = (b.phase + b.speed * dt / d.stride) % 1
	local ph = b.phase
	local dir = if b.vel.Z > 0.5 then -1 else 1
	-- 골반: 위아래만(접지 −0.2, 넘김 +0.3), 좌우 0
	local bobAmp = 0.25 + 0.12 * chase
	-- (다리가 거의 펴져 있어서 위로는 조금만: 접지 때 가장 낮고 보폭이 커지면 더 낮다)
	local bob = (-0.1 - 0.3 * chase - bobAmp * 0.55 * math.cos(ph * math.pi * 4)) * amp + 0.02 * math.sin(b.t * 1.1)
	local pOff = Vector3.new(0, bob, 0)
	A.pose(b, "pelvis", 0, 0, 0, pOff)
	local pelvisPos = b.rest.pelvis.Position + pOff
	local swingN = 0
	for i, n in { "N", "F" } do
		local hip = pelvisPos + b.rest["knee" .. n].Position
		local ankle = b.rest.pelvis.Position + b.rest["knee" .. n].Position + b.tip["knee" .. n] + b.tip["ankle" .. n]
		local z, h, pitch, contact = footCurve(ph, prev, if i == 1 then 0 else 0.5, d.stride, 0.5 + 0.2 * chase)
		if i == 1 then
			swingN = z
		end
		local target = ankle + Vector3.new(0, h * amp, z * amp * dir)
		local tRx, sRx = legIK(b, "knee" .. n, "ankle" .. n, hip, target, 0)
		A.pose(b, "knee" .. n, tRx, 0, 0)
		A.pose(b, "ankle" .. n, sRx, 0, 0)
		A.pose(b, "toe" .. n, pitch * amp - tRx - sRx, 0, 0)
		if contact and amp > 0.3 then
			b.step(b.root.CFrame:PointToWorldSpace(target), math.clamp(b.speed / 12, 0.25, 1.0)) -- 아주 작은 스침
		end
	end
	-- 칼날 맞추기 순간: 판이 한 번 떨림(0.25초)
	local al = b.model:GetAttribute("Align")
	if al ~= d.lastAlign then
		d.lastAlign = al
		d.align = 0
	end
	local shiver = 0
	if d.align >= 0 then
		d.align += dt
		shiver = math.sin(d.align * 70) * 0.06 * math.max(0, 1 - d.align / 0.25)
		if d.align > 0.25 then
			d.align = -1
		end
	end
	-- 상체: 걸음마다 앞뒤로만 살짝(X 축), 머리는 숙인 채 고정
	A.pose(b, "spine1", 0.03 * math.sin(ph * math.pi * 4) * amp + shiver, 0, 0)
	A.pose(b, "spine2", 0.02 * math.sin(b.t * 0.9) - shiver, 0, 0)
	A.pose(b, "neck", -0.02 * math.sin(ph * math.pi * 4) * amp, 0, 0)
	-- 팔: 다리와 반대로(N 팔 ↔ N 다리 반대), 손은 고정
	local sw = math.clamp(swingN / 1.6, -1, 1) * 0.28 * amp
	A.pose(b, "elbowN", -sw, 0, 0)
	A.pose(b, "wristN", -sw * 0.4 - 0.05, 0, 0)
	A.pose(b, "elbowF", sw, 0, 0)
	A.pose(b, "wristF", sw * 0.4, 0, 0)
end

return M
