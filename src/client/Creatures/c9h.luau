--!strict
-- c9h 후방감지: 뒤로 걷는 두 발 보행(몸은 +Z 를 보고 루트는 -Z 로 간다).
-- 뒤로 뻗은 발이 발끝부터 닿고(발목 +24°) 뒤꿈치까지 내려 무게를 옮긴다 — 접지 순간 b.step.
-- 골반은 디딤발 쪽으로 기울고(±3°) 디딤 가운데서 솟는다. 무릎은 얼굴 쪽으로 꺾임(극 = +Z).
-- 손은 진행 쪽으로 더듬고, 거꾸로 매달린 머리는 목 2마디만 흔들린다. Band(센서 단계)가 높을수록 입이 벌어지고 손가락이 오므라듦.
-- 서버 Turn = 음파 뒤 1.8초 돌아서기: 골반을 30° 틀었다가 반대로 틀어 정렬(핸들 꺾기).
local A = require(script.Parent.Parent.CreatureAnim)

local M = {}
local DUTY = 0.5 -- 주기 1.2초: 발끝 닿음 0.3 + 무게 이동 0.3 + 들어 넘김 0.6 (디딤 = 반)
local STRIDE = 3.0

local function rotTo(a: Vector3, b: Vector3): CFrame
	local au, bu = a.Unit, b.Unit
	local c = au:Cross(bu)
	local s = c.Magnitude
	if s < 1e-5 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(c / s, math.atan2(s, au:Dot(bu)))
end

local function setRot(b: A.Body, name: string, cf: CFrame, offset: Vector3?)
	local rx, ry, rz = cf:ToEulerAnglesYXZ()
	A.pose(b, name, rx, ry, rz, offset)
end

-- 2마디 IK(부모 회전 pr): 끝 뼈의 루트 기준 회전을 돌려준다
local function ik2(b: A.Body, upper: string, lower: string, j: Vector3, t: Vector3, pole: Vector3, pr: CFrame): CFrame
	local T0, S0 = b.tip[upper], b.tip[lower]
	local l1, l2 = T0.Magnitude, S0.Magnitude
	local dv = t - j
	local dist = math.clamp(dv.Magnitude, math.abs(l1 - l2) + 0.02, l1 + l2 - 0.01)
	local u = dv.Unit
	local w = pole - u * pole:Dot(u)
	w = if w.Magnitude > 1e-4 then w.Unit else Vector3.zAxis
	local a1 = math.acos(math.clamp((l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist), -1, 1))
	local elbow = j + u * (l1 * math.cos(a1)) + w * (l1 * math.sin(a1))
	local r1 = rotTo(T0, pr:VectorToObjectSpace(elbow - j))
	local r2 = rotTo(S0, (pr * r1):VectorToObjectSpace(j + u * dist - elbow))
	setRot(b, upper, r1)
	setRot(b, lower, r2)
	return pr * r1 * r2
end

local function restAbs(b: A.Body): { [string]: Vector3 }
	local out: { [string]: Vector3 } = {}
	local function get(n: string): Vector3
		local v = out[n]
		if v then
			return v
		end
		local mo = b.m[n]
		local p = mo and mo.Part0
		v = b.rest[n].Position
		if p and string.sub(p.Name, 1, 5) == "Bone_" then
			v += get(string.sub(p.Name, 6))
		end
		out[n] = v
		return v
	end
	for n in b.m do
		get(n)
	end
	return out
end

function M.init(b: A.Body)
	local d = b.data
	d.abs = restAbs(b)
	d.amp = 0
	d.turn = -1
	d.lastTurn = b.model:GetAttribute("Turn")
	d.jaw = 0
end

function M.step(b: A.Body, dt: number)
	local d = b.data
	d.amp = A.approach(d.amp, math.clamp(b.speed / 5, 0, 1.4), 6, dt)
	local amp = math.min(d.amp, 1)
	local stride = STRIDE + 0.12 * math.max(0, b.speed - 5)
	local prev = b.phase
	b.phase = (b.phase + b.speed * dt / stride) % 1
	local ph = b.phase
	-- 돌아서기(핸들 꺾기): 골반 +30° → -10° → 0
	local tn = b.model:GetAttribute("Turn")
	if tn ~= d.lastTurn then
		d.lastTurn = tn
		d.turn = 0
	end
	local twist = 0
	if d.turn >= 0 then
		d.turn += dt
		local t = d.turn
		twist = if t < 0.7 then math.rad(30) * math.sin(t / 0.7 * math.pi / 2) elseif t < 1.4 then math.rad(30 - 40 * (t - 0.7) / 0.7) else math.rad(-10) * (1 - (t - 1.4) / 0.4)
		if t > 1.8 then
			d.turn = -1
			twist = 0
		end
	end
	-- 골반: 디딤발 쪽 기울기 + 디딤 가운데서 솟음(두 번/주기)
	local sway = math.sin(ph * math.pi * 2)
	local bob = (0.08 * math.cos(ph * math.pi * 4) - 0.06) * amp
	local pOff = Vector3.new(0.1 * sway * amp, bob, 0)
	local pRot = CFrame.fromEulerAnglesYXZ(0, twist, math.rad(3) * sway * amp)
	setRot(b, "Pelvis", pRot, pOff)
	local pelvis = d.abs.Pelvis + pOff
	local pelvisCF = CFrame.new(pelvis) * pRot
	for i, n in { "L", "R" } do
		local o = if i == 1 then 0 else 0.5
		local q, qp = (ph + o) % 1, (prev + o) % 1
		local z, h, pitch
		local half = DUTY * stride / 2 * amp
		if q < DUTY then
			-- 디딤: 발끝 닿음(발목 +24°) → 뒤꿈치까지 내려옴 → 발바닥이 몸 앞(+Z)쪽으로 지나감
			local k = q / DUTY
			z = -half + 2 * half * k
			h = 0
			pitch = if k < 0.5 then math.rad(24) * (1 - k / 0.5) else 0
		else
			-- 들어 넘김: 몸 뒤(-Z, 진행 쪽)로 뻗음, 끝에서 발끝을 내림
			local k = (q - DUTY) / (1 - DUTY)
			z = half - 2 * half * (0.5 - 0.5 * math.cos(k * math.pi))
			h = 0.35 * math.sin(k * math.pi)
			pitch = math.rad(24) * math.clamp((k - 0.5) / 0.5, 0, 1)
		end
		local ankle = d.abs["Foot" .. n]
		local target = ankle + Vector3.new(0, (h + pitch * 0.35) * amp, z)
		local hip = pelvisCF:PointToWorldSpace(d.abs["Thigh" .. n] - d.abs.Pelvis)
		local legRot = ik2(b, "Thigh" .. n, "Shin" .. n, hip, target, Vector3.new(0, 0.1, 1), pRot)
		setRot(b, "Foot" .. n, legRot:Inverse() * CFrame.Angles(pitch * amp, 0, 0))
		if qp >= DUTY and q < DUTY and amp > 0.3 then
			b.step(b.root.CFrame:PointToWorldSpace(target), math.clamp(b.speed / 9, 0.4, 1.4)) -- 끽 — 툭
		end
	end
	-- 더듬는 손: 진행 쪽으로 번갈아 뻗음
	local band = (b.model:GetAttribute("Band") :: number?) or 0
	for i, n in { "L", "R" } do
		local s = if i == 1 then 1 else -1
		A.pose(b, "UpperArm" .. n, (-0.12 + 0.18 * s * sway) * amp - 0.05 * band, 0, 0)
		A.pose(b, "Forearm" .. n, 0.1 * math.sin(b.t * 2 + i) - 0.06 * band, 0, 0)
		A.pose(b, "Hand" .. n, 0.25 * math.sin(b.t * 5 + i * 2) * 0.4 + 0.12 * band, 0, 0)
	end
	-- 척추: 숨(등의 활이 조금 더 휘었다 풀림), 거꾸로 매달린 머리는 목 2마디만 흔들림
	local br = math.sin(b.t * 1.4)
	A.pose(b, "Spine1", 0.02 * br, 0, 0)
	A.pose(b, "Spine2", 0.025 * br, 0, 0)
	A.pose(b, "Neck1", 0.06 * math.sin(b.t * 1.1) + 0.05 * sway * amp, 0, 0.04 * sway * amp)
	A.pose(b, "Neck2", 0.08 * math.sin(b.t * 1.1 + 1), 0.06 * math.sin(b.t * 0.7), 0)
	d.jaw = A.approach(d.jaw, 0.1 + 0.12 * band + (if b.state == "Chase" then 0.2 else 0), 4, dt)
	A.pose(b, "Jaw", -d.jaw, 0, 0)
end

return M
