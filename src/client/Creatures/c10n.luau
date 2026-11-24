--!strict
-- c10n 앞줄 손님: 앉은 L 자 덩어리 그대로 움직인다(다리 관절 없음).
-- 서버 Vault = 한 줄 넘기: 잡기 0.3(두 팔을 뒤로 꺾어 팔꿈치가 머리 위로 솟고 손이 제 등받이 꼭대기를 쥠) →
--   넘기 0.4(덩어리째 등받이 축으로 −105° 통째 회전, 몸을 굽히지 않음) → 앉기 0.2(제자리로 떨어지며 '탕' = b.step 크게).
-- 평지 끌기: 손목을 바닥 쪽으로 뻗어 번갈아 당기고 덩어리가 앞뒤로 흔들림(당길 때마다 b.step 작게).
-- 긴 목은 스프링처럼 늦게 따라 흔들리고 머리는 늘 화면 쪽(+Z).
local A = require(script.Parent.Parent.CreatureAnim)

local M = {}
local GRIP, FLIP, LAND = 0.3, 0.4, 0.2
local PULL = 1.2 -- 한 번 당길 때 나아가는 거리

local function rotTo(a: Vector3, b: Vector3): CFrame
	local au, bu = a.Unit, b.Unit
	local c = au:Cross(bu)
	local s = c.Magnitude
	if s < 1e-5 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(c / s, math.atan2(s, au:Dot(bu)))
end

local function setRot(b: A.Body, name: string, cf: CFrame)
	local rx, ry, rz = cf:ToEulerAnglesYXZ()
	A.pose(b, name, rx, ry, rz)
end

-- 2마디 IK(Mass 기준 쉬는 자세 좌표 — 팔의 부모 뼈들은 돌리지 않는다)
local function ik2(b: A.Body, upper: string, lower: string, j: Vector3, t: Vector3, pole: Vector3)
	local T0, S0 = b.tip[upper], b.tip[lower]
	local l1, l2 = T0.Magnitude, S0.Magnitude
	local dv = t - j
	local dist = math.clamp(dv.Magnitude, math.abs(l1 - l2) + 0.02, l1 + l2 - 0.01)
	local u = dv.Unit
	local w = pole - u * pole:Dot(u)
	w = if w.Magnitude > 1e-4 then w.Unit else Vector3.yAxis
	local a1 = math.acos(math.clamp((l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist), -1, 1))
	local elbow = j + u * (l1 * math.cos(a1)) + w * (l1 * math.sin(a1))
	local r1 = rotTo(T0, elbow - j)
	setRot(b, upper, r1)
	setRot(b, lower, rotTo(S0, r1:VectorToObjectSpace(j + u * dist - elbow)))
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
	d.vault = -1
	d.lastVault = b.model:GetAttribute("Vault")
	d.amp = 0
	d.n1, d.n1v = 0, 0
	d.landed = false
end

function M.step(b: A.Body, dt: number)
	local d = b.data
	local va = b.model:GetAttribute("Vault")
	if va ~= d.lastVault then
		d.lastVault = va
		d.vault = 0
		d.landed = false
	end
	local massRx, massOff = 0, Vector3.zero
	local grip = 0 -- 0 = 대기 팔, 1 = 등받이 잡기
	if d.vault >= 0 then
		d.vault += dt
		local t = d.vault
		if t < GRIP then
			grip = t / GRIP
		elseif t < GRIP + FLIP then
			grip = 1
			local k = (t - GRIP) / FLIP
			massRx = -math.rad(105) * (k * k * (3 - 2 * k))
		elseif t < GRIP + FLIP + LAND then
			grip = 1
			local k = (t - GRIP - FLIP) / LAND
			massRx = -math.rad(105) * (1 - k)
			massOff = Vector3.new(0, 0.8 * (1 - k * k), 0)
		else
			if not d.landed then
				d.landed = true
				b.step(b.root.Position + Vector3.new(0, -2.4, 0), 1.6) -- 탕!
				d.n1v += 4
			end
			grip = math.max(0, 1 - (t - GRIP - FLIP - LAND) / 0.4)
			if t > GRIP + FLIP + LAND + 0.4 then
				d.vault = -1
			end
		end
	end
	-- 평지 끌기(넘는 중이 아닐 때): 덩어리가 당길 때마다 앞뒤로 흔들림
	local dragging = d.vault < 0
	d.amp = A.approach(d.amp, if dragging then math.clamp(b.speed / 2, 0, 1.2) else 0, 5, dt)
	local prev = b.phase
	if dragging then
		b.phase = (b.phase + b.speed * dt / PULL) % 1
	end
	local ph = b.phase
	local rock = math.sin(ph * math.pi * 2) * d.amp
	A.pose(b, "Mass", massRx + 0.06 * rock, 0, 0, massOff)
	if dragging and d.amp > 0.3 and (prev % 0.5) > (ph % 0.5) then
		b.step(b.root.Position + Vector3.new(0, -2.4, 0), 0.5) -- 손바닥 끌기
	end
	-- 팔: 대기(손목이 무릎 사이로 처짐) / 끌기(진행 쪽 −Z 바닥으로 번갈아 뻗음) / 잡기(팔꿈치가 머리 위로, 손은 등받이 꼭대기)
	for i, n in { "L", "R" } do
		local s = if i == 1 then -1 else 1
		local j = d.abs["UpperArm" .. n]
		local idle = d.abs["UpperArm" .. n] + b.tip["UpperArm" .. n] + b.tip["Forearm" .. n] + Vector3.new(0, 0.05 * math.sin(b.t * 1.3 + i), 0)
		local reach = math.max(0, math.sin(ph * math.pi * 2 + (if i == 1 then 0 else math.pi)))
		local drag = Vector3.new(1.1 * s, 1.0 + 0.6 * (1 - reach), -0.6 - 1.2 * reach)
		local t = idle:Lerp(Vector3.new(drag.X, d.abs.Mass.Y - 3.45 + drag.Y, drag.Z), math.min(d.amp, 1))
		local gp = Vector3.new(0.55 * s, d.abs.Mass.Y, d.abs.Mass.Z) -- 제 등받이 꼭대기(= 넘기 축)
		t = t:Lerp(gp, grip)
		local pole = Vector3.new(0.4 * s, 0, 1):Lerp(Vector3.new(0.3 * s, 1, -0.2), grip)
		ik2(b, "UpperArm" .. n, "Forearm" .. n, j, t, pole)
	end
	-- 긴 목: 스프링(덩어리 흔들림·착지에 늦게 따라옴), 머리는 화면 쪽으로 되돌아감
	local force = -18 * d.n1 - 3 * d.n1v - 1.5 * rock
	d.n1v += force * dt
	d.n1 += d.n1v * dt
	A.pose(b, "NeckTop", d.n1 * 0.25 + 0.03 * math.sin(b.t * 0.9), 0.05 * math.sin(b.t * 0.4), 0)
	A.pose(b, "Head", -d.n1 * 0.15 - massRx * 0.1, 0.08 * math.sin(b.t * 0.37), 0)
end

return M
