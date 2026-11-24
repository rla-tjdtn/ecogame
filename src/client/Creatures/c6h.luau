--!strict
-- c6h 등맞댄 손님: 3박 절뚝 보행 "쿵 — 스윽 — (멈칫)".
-- 앞장선 몸의 다리가 뒤꿈치로 '쿵' 딛고(체중 전부, 골반이 그쪽으로 3° 기욺), 뒤 몸의 다리는 무릎이 반대라 발끝을 바닥에 끌며
-- 앞으로 당겨 옴('스윽', 골반 −5° 롤), 두 발이 다 닿은 채 잠깐 멈칫. 진행 방향이 바뀌면(돌아서지 않음) 같은 주기를 B 가 거울처럼.
-- 앞장 얼굴이 바뀌는 순간 두 머리가 움찔(0.15초). 두 머리는 서로 반대 위상으로 흔들리고, 앞장 팔은 허리 높이로 더듬고
-- 뒤 팔은 진자처럼 늘어진다. 추격 중 3.5 안이면 앞장 상체가 덮치듯 숙여진다.
local Players = game:GetService("Players")
local A = require(script.Parent.Parent.CreatureAnim)

local M = {}
local DUTY = 0.55
local STRIDE = 2.4
local START = { lead = 0, drag = 0.85 } -- 디딤 시작 위상

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

local function ik2(b: A.Body, upper: string, lower: string, j: Vector3, t: Vector3, pole: Vector3, pr: CFrame): CFrame
	local T0, S0 = b.tip[upper], b.tip[lower]
	local l1, l2 = T0.Magnitude, S0.Magnitude
	local dv = t - j
	local dist = math.clamp(dv.Magnitude, math.abs(l1 - l2) + 0.02, l1 + l2 - 0.01)
	local u = dv.Unit
	local w = pole - u * pole:Dot(u)
	w = if w.Magnitude > 1e-4 then w.Unit else pole.Unit
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

-- 발 하나: 디딤 시작 위상 s0. u = 진행 방향 앞(+) 거리, h = 높이, pitch = 발끝 내림(+), contact = 이번 프레임에 딛음
local function foot(ph: number, prev: number, s0: number, half: number, drag: boolean): (number, number, number, boolean)
	local q, qp = (ph - s0) % 1, (prev - s0) % 1
	local u, h, pitch
	if q < DUTY then
		local k = q / DUTY
		u = half - 2 * half * k
		h = 0
		pitch = 0
	else
		local k = (q - DUTY) / (1 - DUTY)
		u = -half + 2 * half * (0.5 - 0.5 * math.cos(k * math.pi))
		if drag then
			h = 0.03
			pitch = 0.5 * math.sin(k * math.pi) -- 발끝을 바닥에 끌며
		else
			h = 0.4 * math.sin(k * math.pi)
			pitch = -0.2 * k
		end
	end
	return u, h, pitch, qp > q
end

function M.init(b: A.Body)
	local d = b.data
	d.abs = restAbs(b)
	d.amp = 0
	d.dir = -1 -- −1 = −Z 로 감(A 앞장), +1 = +Z(B 앞장)
	d.rev = 0
	d.lunge = 0
	d.check = 0
	d.close = false
end

function M.step(b: A.Body, dt: number)
	local d = b.data
	-- 앞장 판단(돌아서지 않으니 진행 방향의 부호만)
	if math.abs(b.vel.Z) > 0.6 then
		local nd = if b.vel.Z < 0 then -1 else 1
		if nd ~= d.dir then
			d.dir = nd
			d.rev = 0.15 -- 반전: 눈 뜨는 순간 두 머리가 움찔
		end
	end
	d.rev = math.max(0, d.rev - dt)
	local leadN = if d.dir < 0 then "A" else "B"
	d.amp = A.approach(d.amp, math.clamp(b.speed / 5.5, 0, 1.3), 6, dt)
	local amp = math.min(d.amp, 1)
	local stride = STRIDE + 0.12 * math.max(0, b.speed - 5.5)
	local prev = b.phase
	b.phase = (b.phase + b.speed * dt / stride) % 1
	local ph = b.phase
	local half = DUTY * stride / 2 * amp
	-- 골반: 쿵(앞장 디딤) 쪽으로 3°, 스윽(끌기) 동안 −5°, 디딤 가운데서 솟음 0.1
	local leadSide = if leadN == "A" then -1 else 1
	local roll
	if ph < 0.4 then
		roll = math.rad(3) * math.sin(ph / 0.4 * math.pi)
	elseif ph < 0.85 then
		roll = -math.rad(5) * math.sin((ph - 0.4) / 0.45 * math.pi)
	else
		roll = 0
	end
	local bob = (0.1 * math.sin(math.min(ph / DUTY, 1) * math.pi) - 0.08) * amp
	local pOff = Vector3.new(0.08 * leadSide * math.sin(ph * math.pi * 2) * amp, bob, 0)
	local pRot = CFrame.fromEulerAnglesYXZ(0, 0, -roll * leadSide * amp)
	setRot(b, "Pelvis", pRot, pOff)
	local pelvisCF = CFrame.new(d.abs.Pelvis + pOff) * pRot
	for _, n in { "A", "B" } do
		local isLead = n == leadN
		local u, h, pitch, contact = foot(ph, prev, if isLead then START.lead else START.drag, half, not isLead)
		local z = u * d.dir -- (앞 = 진행 방향: −Z 로 갈 땐 z = −u)
		local ankle = d.abs["Foot" .. n]
		local target = ankle + Vector3.new(0, h * amp, z)
		local hip = pelvisCF:PointToWorldSpace(d.abs["Thigh" .. n] - d.abs.Pelvis)
		local kz = if n == "A" then -1 else 1 -- 무릎 방향(A 앞, B 뒤)
		local legRot = ik2(b, "Thigh" .. n, "Shin" .. n, hip, target, Vector3.new(0, 0.05, kz), pRot)
		local ps = if n == "A" then -1 else 1 -- 발끝 방향(A −Z, B +Z)
		setRot(b, "Foot" .. n, legRot:Inverse() * CFrame.Angles(ps * pitch * amp, 0, 0))
		if contact and amp > 0.3 then
			b.step(b.root.CFrame:PointToWorldSpace(target), if isLead then math.clamp(b.speed / 7, 0.6, 1.5) else 0.35) -- 쿵 / 스윽
		end
	end
	-- 상체 둘: 서로 반대 위상으로 흔들림, 앞장은 숙여 더듬고 추격 3.5 안이면 덮치듯
	d.check -= dt
	if d.check <= 0 then
		d.check = 0.15
		d.close = b.state == "Chase" and nearestDist(b.root.Position) < 3.5
	end
	d.lunge = A.approach(d.lunge, if d.close then 1 else 0, 8, dt)
	local jolt = math.sin(d.rev * 120) * 0.12 * (d.rev / 0.15)
	for _, n in { "A", "B" } do
		local f = if n == "A" then -1 else 1 -- 얼굴 쪽
		local lead = n == leadN
		local w = math.sin(ph * math.pi * 2 + (if n == "A" then 0 else math.pi))
		local lean = (if lead then 0.12 * amp + 0.45 * d.lunge else -0.04 * amp) -- 앞장 상체는 진행 쪽으로
		A.pose(b, "Spine" .. n, f * lean, 0, 0.03 * w * amp) -- (+rx = 위쪽이 +Z 로: 얼굴 쪽으로 숙임 = f 부호)
		A.pose(b, "Chest" .. n, -f * 0.05 * w * amp, 0, 0)
		A.pose(b, "Head" .. n, -f * (0.08 * w * amp + jolt), jolt * 2, 0)
		for _, s in { "L", "R" } do
			local sw = if s == "L" then 1 else -1
			if lead then
				-- 허리 높이로 더듬기(손가락 벌림)
				A.pose(b, "UpperArm" .. n .. s, -f * (0.25 + 0.1 * math.sin(b.t * 2 + sw) + 0.6 * d.lunge), 0, 0)
				A.pose(b, "Forearm" .. n .. s, -f * (0.15 * math.sin(b.t * 2.6 + sw)), 0, 0)
			else
				A.pose(b, "UpperArm" .. n .. s, f * 0.15 * sw * w * amp, 0, 0) -- 늘어진 진자
				A.pose(b, "Forearm" .. n .. s, f * 0.1 * sw * w * amp, 0, 0)
			end
		end
	end
	-- 등 사이 살 막: 두 상체 벌어짐에 따라 늘어남, 허리띠 끈 흔들림
	A.pose(b, "Web", 0, 0, 0, Vector3.new(0, 0.05 * math.sin(b.t * 1.4), 0))
	A.pose(b, "Belt", 0, 0, 0.12 * math.sin(ph * math.pi * 2 - 0.8) * amp)
end

return M
