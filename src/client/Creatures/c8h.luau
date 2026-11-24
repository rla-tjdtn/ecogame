--!strict
-- c8h 눈높이: 무릎 걸음. 접지 목표는 발이 아니라 무릎(KneeContact) — 한쪽 무릎을 들어 앞으로 짚고(b.step),
-- 골반이 좌우로 ±8° 기울며 반대쪽 정강이는 바닥을 쓸며 끌려온다(정강이는 늘 바닥과 나란하게).
-- 얼굴(FaceAim)만 가까운 플레이어 머리 쪽을 올려다본다. 쉴 때 가끔 왼손 검지를 입 앞에 대는 '쉿'.
local Players = game:GetService("Players")
local A = require(script.Parent.Parent.CreatureAnim)

local M = {}
local STRIDE = 1.5 -- 한 주기(무릎 두 번)에 가는 거리
local DUTY = 0.62
local REF = 2.5

local function angOf(z: number, y: number): number
	return math.atan2(-z, -y)
end

-- 무릎 걸음 곡선: 디딤 동안 무릎이 바닥에서 뒤로, 들 때 0.15 들려 앞으로
local function kneeCurve(phase: number, prev: number, o: number): (number, number, boolean, boolean)
	local q, qp = (phase + o) % 1, (prev + o) % 1
	local half = DUTY * STRIDE / 2
	if q < DUTY then
		return -half + 2 * half * (q / DUTY), 0, true, qp > q
	end
	local s = (q - DUTY) / (1 - DUTY)
	return half - 2 * half * (0.5 - 0.5 * math.cos(s * math.pi)), 0.15 * math.sin(s * math.pi), false, false
end

function M.init(b: A.Body)
	b.data.amp = 0
	b.data.aimX = 0
	b.data.aimY = 0
	b.data.look = 0
	b.data.lookAt = nil
	b.data.shh = 0
end

function M.step(b: A.Body, dt: number)
	local d = b.data
	d.amp = A.approach(d.amp, math.clamp(b.speed / REF, 0, 1.4), 6, dt)
	local amp = math.min(d.amp, 1)
	local prev = b.phase
	b.phase = (b.phase + b.speed * dt / STRIDE) % 1
	local ph = b.phase
	local dir = if b.vel.Z > 0.5 then -1 else 1
	local restP = b.rest.Pelvis.Position
	-- 무릎 목표와, 디딤 무릎이 바닥에 닿도록 필요한 골반 높이
	local zs, hs, stance, contact = {}, {}, {}, {}
	local need = math.huge
	for i, n in { "L", "R" } do
		local z, h, st, c = kneeCurve(ph, prev, if i == 1 then 0 else 0.5)
		zs[i], hs[i], stance[i], contact[i] = z * amp * dir, h * amp, st, c
		if st then
			local T0 = b.tip["Thigh" .. n]
			local l = math.sqrt(T0.Y * T0.Y + T0.Z * T0.Z)
			local dz = T0.Z + zs[i]
			need = math.min(need, math.sqrt(math.max(0.05, l * l - dz * dz)) - (-T0.Y))
		end
	end
	if need == math.huge then
		need = 0
	end
	local tiltSide = math.cos((ph - DUTY / 2) * math.pi * 2) -- +1 = 왼무릎 디딤
	local roll = math.rad(8) * tiltSide * amp
	local bob = need + 0.02 * math.sin(b.t * 1.4)
	local pOff = Vector3.new(-0.08 * tiltSide * amp, bob, 0)
	A.pose(b, "Pelvis", 0, 0, roll, pOff)
	for i, n in { "L", "R" } do
		local T0 = b.tip["Thigh" .. n]
		local hip = restP + pOff + b.rest["Thigh" .. n].Position
		local knee = restP + b.rest["Thigh" .. n].Position + T0
		local target = knee + Vector3.new(0, hs[i], zs[i])
		local rx = angOf(target.Z - hip.Z, target.Y - hip.Y) - angOf(T0.Z, T0.Y)
		A.pose(b, "Thigh" .. n, rx, 0, -roll)
		A.pose(b, "ShinSkid" .. n, -rx, 0, 0) -- 정강이는 바닥에 눕힌 채 끌림
		A.pose(b, "FootUp" .. n, 0.1 * math.sin(ph * math.pi * 2 + i) * amp, 0, 0)
		if contact[i] and amp > 0.3 then
			b.step(b.root.CFrame:PointToWorldSpace(target), math.clamp(b.speed / 4, 0.4, 1.2)) -- 무릎이 바닥을 짚는 둔탁한 소리
		end
	end
	-- 상체: 무릎 디딤에 따라 비틀림만 조금, 숨
	A.pose(b, "Spine", 0.03 * math.sin(b.t * 1.4), 0.05 * tiltSide * amp, -roll * 0.6)
	-- 얼굴 조준: 가까운 플레이어 머리를 올려다봄(0.2초마다 다시 찾음), 없으면 천천히 헤맴
	d.look -= dt
	if d.look <= 0 then
		d.look = 0.2
		d.lookAt = nil
		local best = 30
		for _, p in Players:GetPlayers() do
			local char = p.Character
			local head = char and char:FindFirstChild("Head") :: BasePart?
			if head then
				local dist = (head.Position - b.root.Position).Magnitude
				if dist < best then
					best = dist
					d.lookAt = head.Position
				end
			end
		end
	end
	local ax, ay = 0.15 * math.sin(b.t * 0.37), 0.5 * math.sin(b.t * 0.23)
	if d.lookAt then
		local face = b.root.CFrame:PointToWorldSpace(b.rest.Pelvis.Position + Vector3.new(0, 0.9, -1.1))
		local v = b.root.CFrame:VectorToObjectSpace(d.lookAt - face)
		ay = math.clamp(math.atan2(-v.X, -v.Z), -1.1, 1.1)
		ax = math.clamp(math.atan2(v.Y, math.sqrt(v.X * v.X + v.Z * v.Z)), -0.3, 1.2)
	end
	d.aimX = A.approach(d.aimX, ax, 5, dt)
	d.aimY = A.approach(d.aimY, ay, 5, dt)
	A.pose(b, "NeckBend2", 0, d.aimY * 0.3, 0)
	A.pose(b, "FaceAim", d.aimX * 0.7, d.aimY * 0.7, 0)
	-- 오른손: 내민 채 살짝 떨림. 왼손: 바닥을 끄는데, 쉴 땐 9초마다 2초 '쉿'
	local idle = 1 - amp
	local shhT = if (b.t % 9) < 2 and idle > 0.7 then 1 else 0
	d.shh = A.approach(d.shh, shhT, 5, dt)
	A.pose(b, "UpperArmR", 0.03 * math.sin(b.t * 2.3), 0, 0)
	A.pose(b, "HandR", 0.04 * math.sin(b.t * 3.1), 0, 0)
	A.pose(b, "UpperArmL", -1.1 * d.shh + 0.12 * math.sin(ph * math.pi * 2) * amp, 0, 0.3 * d.shh)
	A.pose(b, "ForearmL", -1.6 * d.shh, 0, 0)
end

return M
