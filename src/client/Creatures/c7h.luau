--!strict
-- c7h 손든 아이: 뻣뻣한 행진(무릎 거의 안 굽힘, 뒤꿈치 찰싹 → 발바닥 전체, 발끝 밀기 거의 없음).
-- 팔·머리·상체는 한 덩어리로 고정 — 골반만 위아래로, 위의 11.9 기둥이 미끄러지듯 다가온다.
-- 서버 Turn = 돌아서는 순간 관절이 한꺼번에 우두둑(몸 떨림). 추격 중 가까우면 굳은 팔이 처음으로 앞으로 떨어져 내려친다.
local Players = game:GetService("Players")
local A = require(script.Parent.Parent.CreatureAnim)

local M = {}
local DUTY = 0.6
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

-- 행진 곡선: 발을 낮게 끌듯 넘기고, 뒤꿈치로 찰싹 착지
local function footCurve(phase: number, prev: number, o: number, stride: number): (number, number, number, boolean)
	local q, qp = (phase + o) % 1, (prev + o) % 1
	local half = DUTY * stride / 2
	local z, h, pitch
	if q < DUTY then
		local s = q / DUTY
		z = -half + 2 * half * s
		h = 0
		pitch = if s < 0.12 then 0.2 * (1 - s / 0.12) else 0
	else
		local s = (q - DUTY) / (1 - DUTY)
		z = half - 2 * half * (0.5 - 0.5 * math.cos(s * math.pi))
		h = 0.22 * math.sin(s * math.pi)
		pitch = 0.2 * s
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
	b.data.lastTurn = b.model:GetAttribute("Turn")
	b.data.turn = -1
	b.data.strike = 0
	b.data.strikeT = 0
	b.data.check = 0
	b.data.close = false
end

function M.step(b: A.Body, dt: number)
	local d = b.data
	d.amp = A.approach(d.amp, math.clamp(b.speed / REF, 0, 1.5), 6, dt)
	local amp = math.min(d.amp, 1)
	local stride = 3.0 + 0.1 * math.max(0, b.speed - 7) -- 짧은 아이 다리: 추격 땐 보폭을 늘려 겨우 따라간다
	local prev = b.phase
	b.phase = (b.phase + b.speed * dt / stride) % 1
	local ph = b.phase
	local dir = if b.vel.Z > 0.5 then -1 else 1
	-- 무릎을 펴고 걸으니 다리를 벌릴수록 골반이 내려가야 한다: 디딤 보폭에서 필요한 높이를 계산
	local l = b.tip.ThighL.Magnitude + b.tip.ShinL.Magnitude
	local half = DUTY * stride / 2 * amp
	local dip = l - math.sqrt(math.max(0.1, l * l - half * half))
	local bob = (-dip - 0.03 - 0.06 * math.cos(ph * math.pi * 4)) * amp - 0.04 * amp
	-- 돌아서기 떨림
	local tn = b.model:GetAttribute("Turn")
	if tn ~= d.lastTurn then
		d.lastTurn = tn
		d.turn = 0
	end
	local jolt = 0
	if d.turn >= 0 then
		d.turn += dt
		jolt = math.sin(d.turn * 60) * 0.05 * math.max(0, 1 - d.turn / 0.35)
		if d.turn > 0.35 then
			d.turn = -1
		end
	end
	local pOff = Vector3.new(0, bob, 0)
	A.pose(b, "Pelvis", 0, 0, jolt, pOff)
	local pelvisPos = b.rest.Pelvis.Position + pOff
	for i, n in { "L", "R" } do
		local hip = pelvisPos + b.rest["Thigh" .. n].Position
		local ankle = b.rest.Pelvis.Position + b.rest["Thigh" .. n].Position + b.tip["Thigh" .. n] + b.tip["Shin" .. n]
		local z, h, pitch, contact = footCurve(ph, prev, if i == 1 then 0 else 0.5, stride)
		local target = ankle + Vector3.new(0, h * amp, z * amp * dir)
		local tRx, sRx = legIK(b, "Thigh" .. n, "Shin" .. n, hip, target, 0)
		sRx = math.max(sRx, -math.rad(12) - 0.05) -- 무릎 굽힘 상한 12°
		A.pose(b, "Thigh" .. n, tRx, 0, 0)
		A.pose(b, "Shin" .. n, sRx, 0, 0)
		A.pose(b, "Foot" .. n, pitch * amp - tRx - sRx, 0, 0)
		local q = (ph + (if i == 1 then 0 else 0.5)) % 1
		A.pose(b, "Slipper" .. n, if q >= DUTY then -0.25 * math.sin((q - DUTY) / (1 - DUTY) * math.pi) * amp else 0, 0, 0) -- 뒤축 펄럭
		if contact and amp > 0.3 then
			b.step(b.root.CFrame:PointToWorldSpace(target), math.clamp(b.speed / 10, 0.4, 1.4)) -- 찰싹
		end
	end
	-- 상체는 고정. 재킷 밑단만 진자
	A.pose(b, "Jacket", 0.12 * math.sin(ph * math.pi * 4 - 0.6) * amp, 0, 0)
	-- 내려치기: 추격 중 4.5 안이면 팔이 앞으로 떨어짐(62°) → 내려침(122°), 머리 +30° 들림
	d.check -= dt
	if d.check <= 0 then
		d.check = 0.15
		d.close = b.state == "Chase" and nearestDist(b.root.Position) < 4.5
	end
	if d.close then
		d.strikeT += dt
	else
		d.strikeT = math.max(0, d.strikeT - dt * 2)
	end
	local s = d.strikeT
	local target = if s <= 0 then 0 elseif s < 0.6 then math.rad(62) * (s / 0.6) elseif s < 1.0 then math.rad(62 + 60 * (s - 0.6) / 0.4) else math.rad(122)
	if s > 1.4 then
		d.strikeT = 0 -- 한 번 내려친 뒤 다시 든다
	end
	d.strike = A.approach(d.strike, target, 18, dt)
	A.pose(b, "UpperArmL", -d.strike, 0, 0)
	A.pose(b, "UpperArmR", -d.strike, 0, 0)
	A.pose(b, "NeckDrop", -math.rad(30) * math.clamp(d.strike / math.rad(62), 0, 1), 0, 0)
end

return M
