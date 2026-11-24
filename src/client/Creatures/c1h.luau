--!strict
-- c1h 발맞춤: 사람 두 발 보행(뒤꿈치 → 발바닥 → 발끝). 골반 띠가 디딤발 쪽으로 3° 기울고 좌우 0.12 흔들리며 디딤 가운데서 솟음.
-- 보행 위상은 루트의 실제 이동 거리에 묶여 있어(관성 없음) 서버가 속도 0 을 주는 순간 그 자세 그대로 굳는다 — 한 발 든 채.
-- 멈춘 뒤 0.6초에 딱 한 번 발소리(마지막 걸음). 달리면 보폭이 1.5배. 아래팔은 다리 반대 위상 진자(±20°).
-- 추격 중 3 안이면 쐐기 받침째 머리가 앞으로 84° 꺾여 얼굴이 처음 보인다. 붉은 케이블은 늦게 따라 흔들리는 사슬.
local Players = game:GetService("Players")
local A = require(script.Parent.Parent.CreatureAnim)

local M = {}
local DUTY = 0.6
local STRIDE = 2.2

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
	w = if w.Magnitude > 1e-4 then w.Unit else -Vector3.zAxis
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

function M.init(b: A.Body)
	local d = b.data
	d.abs = restAbs(b)
	d.amp = 0
	d.still = 0
	d.moving = false
	d.extraAt = -1
	d.snap = 0
	d.check = 0
	d.close = false
	d.freeze = 0
	d.c1, d.c1v, d.c2, d.c2v = 0, 0, 0, 0
end

function M.step(b: A.Body, dt: number)
	local d = b.data
	-- 관성 없는 실제 속도(부드럽게 하지 않음): 멈추면 그 프레임에 위상이 선다
	local v = b.root.AssemblyLinearVelocity
	local raw = Vector3.new(v.X, 0, v.Z).Magnitude
	if raw > 0.4 then
		d.still = 0
		d.amp = A.approach(d.amp, 1, 8, dt)
		d.moving = raw > 1
	else
		d.still += dt
		if d.moving then
			d.moving = false
			d.extraAt = b.t + 0.6 -- 멈춘 뒤 한 걸음 더
		end
		if d.still > 6 then
			d.amp = A.approach(d.amp, 0, 0.5, dt) -- 오래 서 있으면 아주 천천히 두 발로 내려선다
		end
	end
	if d.extraAt > 0 and b.t >= d.extraAt then
		d.extraAt = -1
		b.step(b.root.CFrame:PointToWorldSpace(d.abs.FootL), 0.7)
	end
	local amp = d.amp
	local stride = STRIDE * (1 + 0.5 * math.clamp((raw - 10) / 8, 0, 1))
	local prev = b.phase
	b.phase = (b.phase + raw * dt / stride) % 1
	local ph = b.phase
	-- 골반 띠(몸 전체의 부모): 디딤발 쪽 3° · 좌우 0.12 · 디딤 가운데서 +0.15
	local sway = math.sin(ph * math.pi * 2)
	local bob = (0.15 * math.abs(math.cos(ph * math.pi * 2)) - 0.08) * amp
	local rOff = Vector3.new(0.12 * sway * amp, bob, 0)
	-- 멈춤: 들고 있던 발을 무릎 높이까지 들고 상체를 앞으로 숙인 채 굳는다(사람이면 넘어질 자세)
	d.freeze = A.approach(d.freeze, if raw <= 0.4 and d.still < 6 and amp > 0.2 then 1 else 0, if raw <= 0.4 then 4 else 10, dt)
	local fz: number = d.freeze
	local rRot = CFrame.fromEulerAnglesYXZ(-math.rad(14) * fz, 0, math.rad(3) * sway * amp)
	setRot(b, "HipRing", rRot, rOff)
	local ringCF = CFrame.new(d.abs.HipRing + rOff) * rRot
	for i, n in { "L", "R" } do
		local o = if i == 1 then 0 else 0.5
		local q, qp = (ph + o) % 1, (prev + o) % 1
		local half = DUTY * stride / 2 * amp
		local z, h, pitch
		if q < DUTY then
			local k = q / DUTY
			z = -half + 2 * half * k
			h = 0
			-- 뒤꿈치(발끝 들림, +) → 발바닥 → 발끝(뒤꿈치 들림, −)
			pitch = if k < 0.15 then 0.25 * (1 - k / 0.15) elseif k > 0.75 then -0.35 * (k - 0.75) / 0.25 else 0
		else
			local k = (q - DUTY) / (1 - DUTY)
			z = half - 2 * half * (0.5 - 0.5 * math.cos(k * math.pi))
			h = 0.45 * math.sin(k * math.pi)
			pitch = -0.35 * (1 - k) + 0.25 * k
		end
		local ankle = d.abs["Foot" .. n]
		if (i == 1) == (ph >= 0.5) then -- 이 발이 들리는 쪽
			h += 1.2 * fz * (1 - h)
			z -= 1.6 * fz
		end
		local target = ankle + Vector3.new(0, h * amp + math.max(0, -pitch) * 0.3 * amp, z)
		local hip = ringCF:PointToWorldSpace(d.abs["Thigh" .. n] - d.abs.HipRing)
		local legRot = ik2(b, "Thigh" .. n, "Shin" .. n, hip, target, Vector3.new(0, 0, -1), rRot)
		setRot(b, "Foot" .. n, legRot:Inverse() * CFrame.Angles(pitch * amp, 0, 0))
		if qp >= DUTY and q < DUTY and amp > 0.3 then
			b.step(b.root.CFrame:PointToWorldSpace(target), math.clamp(raw / 10, 0.4, 1.4)) -- 맨발 + 경첩 찰칵
		end
	end
	-- 아래팔 진자(다리 반대 위상 ±20°), 왼팔은 끈에 매달려 더 늘어짐
	A.pose(b, "ForearmL", math.rad(20) * sway * amp, 0, 0)
	A.pose(b, "ForearmR", -math.rad(20) * sway * amp, 0, 0)
	A.pose(b, "UpperArmL", 0.08 * sway * amp, 0, 0.05 * math.sin(b.t * 0.8))
	A.pose(b, "Yoke", 0, 0, math.rad(6) * math.sin(ph * math.pi * 2 + 0.6) * amp) -- 버팀대 흔들림
	-- 살 척추는 틀 사이에서 처졌다 당겨짐
	A.pose(b, "Lumbar", 0.04 * math.sin(b.t * 1.2), 0, 0)
	A.pose(b, "Thorax", -0.05 * sway * amp - math.rad(8) * fz, 0, 0.03 * sway * amp)
	-- 고리 꺾임(공격): 쐐기 받침째 머리가 앞으로 84°
	d.check -= dt
	if d.check <= 0 then
		d.check = 0.15
		d.close = b.state == "Chase" and nearestDist(b.root.Position) < 3.4
	end
	d.snap = A.approach(d.snap, if d.close then 1 else 0, if d.close then 14 else 3, dt)
	A.pose(b, "Clamp", -math.rad(84) * d.snap, 0, 0)
	-- 케이블: 두 마디 스프링(걸음 흔들림을 늦게 따라감)
	local push = -sway * amp * 0.6
	d.c1v += (-30 * d.c1 - 4 * d.c1v + push) * dt
	d.c1 += d.c1v * dt
	d.c2v += (-22 * d.c2 - 3 * d.c2v - d.c1 * 10) * dt
	d.c2 += d.c2v * dt
	A.pose(b, "Cable1", 0.05 * d.c1 + math.rad(14) * fz, 0, 0.12 * d.c1)
	A.pose(b, "Cable2", 0.04 * d.c2, 0, 0.15 * d.c2)
	A.pose(b, "Cable3", 0, 0.1 * d.c2, 0)
end

return M
