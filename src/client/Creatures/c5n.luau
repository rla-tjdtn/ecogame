--!strict
-- c5n 지움: 굴뚝 걸음. 네 손발 중 하나만 떼어 앞으로 다시 짚는다(늘 3점 지지, 순서 왼손 → 오른발 → 오른손 → 왼발).
-- 손은 양벽, 왼발은 벽, 오른발은 바닥 모서리. 벽까지 거리는 레이캐스트로 재서 손발이 실제 벽에 닿게(2마디 IK).
-- 몸통은 짚은 손발 사이에서 미끄러지듯(출렁임 0.1), 갈비는 숨처럼 벌어졌다 오므라든다.
-- 「두 번째 음파」: 서버 SonarVeil = true 인 동안 몸의 모든 선을 이 클라이언트에서 지운다(LocalTransparencyModifier = 1) —
--   음파에 맞아 Reveal 이 켜도 안 보이고, 걸음 소리도 내지 않는다. 두 번째 음파(Exposed)에 갈비가 확 벌어지며 드러남.
-- 추격 중 2.6 안이면 두 손이 벽을 놓고 앞 한 점으로 모이며 갈비가 닫힌다(닫기).
local Players = game:GetService("Players")
local A = require(script.Parent.Parent.CreatureAnim)

local M = {}
local CYCLE = 3.2 -- 한 주기(네 손발 한 번씩) 동안 나아가는 거리
local DUTY = 0.75
local ORDER = { HandL = 0, FootR = 0.25, HandR = 0.5, FootL = 0.75 }
local CHAIN = {
	HandL = { "UpperArmL", "ForearmL", -1 },
	HandR = { "UpperArmR", "ForearmR", 1 },
	FootL = { "ThighL", "ShinL", -1 },
	FootR = { "ThighR", "ShinR", 1 },
}

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

-- 2마디 IK(부모 회전 없음): j 관절 → t 목표, pole 쪽으로 굽힘. 두 뼈의 회전과 끝 회전 합을 돌려준다
local function ik2(b: A.Body, upper: string, lower: string, j: Vector3, t: Vector3, pole: Vector3): CFrame
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
	local r2 = rotTo(S0, r1:VectorToObjectSpace(j + u * dist - elbow))
	setRot(b, upper, r1)
	setRot(b, lower, r2)
	return r1 * r2
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

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

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
	d.parts = {}
	for _, p in b.model:GetDescendants() do
		if p:IsA("BasePart") and (p.Name == "Line" or p.Name == "Ball") then
			table.insert(d.parts, p)
		end
	end
	d.veiled = nil
	d.wall = { [-1] = 3.95, [1] = 3.95 }
	d.rayT = 0
	d.amp = 0
	d.flare = 0
	d.flinch = 0
	d.close = 0
	d.check = 0
	d.near = false
	d.lastVeil = b.model:GetAttribute("Veil")
	d.lastExp = b.model:GetAttribute("Exposed")
end

local function applyVeil(b: A.Body, veiled: boolean)
	local want = if veiled then 1 else 0
	for _, p in b.data.parts do
		if p.LocalTransparencyModifier ~= want then
			p.LocalTransparencyModifier = want
		end
	end
	b.data.veiled = veiled
end

function M.step(b: A.Body, dt: number)
	local d = b.data
	local veiled = b.model:GetAttribute("SonarVeil") ~= false
	applyVeil(b, veiled) -- (매 프레임: Reveal 이 투명도를 바꿔도 이 값이 이긴다)
	-- 첫 음파: 몸을 트는 움찔 / 두 번째 음파: 갈비가 확 벌어짐
	local v = b.model:GetAttribute("Veil")
	if v ~= d.lastVeil then
		d.lastVeil = v
		d.flinch = 1
	end
	local e = b.model:GetAttribute("Exposed")
	if e ~= d.lastExp then
		d.lastExp = e
		d.flare = 1
	end
	d.flinch = math.max(0, d.flinch - dt * 2.5)
	d.flare = math.max(0, d.flare - dt * 0.8)
	-- 벽까지 거리(0.3초마다)
	d.rayT -= dt
	if d.rayT <= 0 then
		d.rayT = 0.3
		local stage = workspace:FindFirstChild("Stage")
		if stage then
			rayParams.FilterDescendantsInstances = { stage }
			local cf = b.root.CFrame
			for _, s in { -1, 1 } do
				local from = cf:PointToWorldSpace(Vector3.new(0, 2, 0))
				local hit = workspace:Raycast(from, cf.RightVector * (6 * s), rayParams)
				d.wall[s] = if hit then math.clamp((hit.Position - from).Magnitude - 0.05, 3.0, 4.25) else 3.95
			end
		end
	end
	d.check -= dt
	if d.check <= 0 then
		d.check = 0.15
		d.near = b.state == "Chase" and nearestDist(b.root.Position) < 2.6
	end
	d.close = A.approach(d.close, if d.near then 1 else 0, 7, dt)
	d.amp = A.approach(d.amp, math.clamp(b.speed / 2.7, 0, 1.3), 5, dt)
	local amp = math.min(d.amp, 1.2)
	local prev = b.phase
	b.phase = (b.phase + b.speed * dt / CYCLE) % 1
	local ph = b.phase
	local half = DUTY * CYCLE / 2 * math.min(amp, 1)
	-- 몸통: 짚은 손발 사이에서 미끄러지듯, 출렁임 0.1(한 손발 짚을 때마다)
	local bob = 0.1 * math.sin(ph * math.pi * 8) * amp + 0.05 * math.sin(b.t * 1.3)
	local off = Vector3.new(0, bob, 0)
	A.pose(b, "Sacrum", 0, 0, 0, off)
	A.pose(b, "NeckStump", 0.15 * d.flinch * math.sin(b.t * 40), 0.4 * d.flinch, 0)
	-- 갈비 숨(open 0.95~1.08) + 노출 때 활짝 + 닫기
	local open = 0.07 * math.sin(b.t * 1.7) + 0.35 * d.flare - 0.45 * d.close
	A.pose(b, "RibL", 0, open, 0)
	A.pose(b, "RibR", 0, -open, 0)
	for name, o in ORDER do
		local ch = CHAIN[name]
		local up, lo, s = ch[1] :: string, ch[2] :: string, ch[3] :: number
		local isHand = string.sub(name, 1, 4) == "Hand"
		local rest = d.abs[name]
		local q, qp = (ph + o) % 1, (prev + o) % 1
		local z, lift
		if q < DUTY then
			local k = q / DUTY
			z = -half + 2 * half * k
			lift = 0
		else
			local k = (q - DUTY) / (1 - DUTY)
			z = half - 2 * half * (0.5 - 0.5 * math.cos(k * math.pi))
			lift = math.sin(k * math.pi) * math.min(amp, 1)
		end
		local t
		local onWall = isHand or name == "FootL"
		if onWall then
			local wx = d.wall[s]
			t = Vector3.new(wx * s, rest.Y, rest.Z + z) - Vector3.new(0.7 * s * lift, -0.25 * lift, 0)
		else
			t = Vector3.new(rest.X, rest.Y + 0.6 * lift, rest.Z + z)
		end
		if isHand and d.close > 0.01 then
			t = t:Lerp(Vector3.new(0.25 * s, rest.Y - 1.6, -2.2), d.close) -- 두 손이 앞 한 점으로
		end
		local j = d.abs[up] + off -- (모든 팔다리는 Sacrum 아래: 출렁임만큼 관절이 같이 움직임)
		local pole = if isHand then Vector3.new(0.3 * s, 0.3, -1) else Vector3.new(0.8 * s, 0, -0.6)
		local r = ik2(b, up, lo, j, t, pole)
		setRot(b, name, r:Inverse() * (if isHand and d.close > 0.5 then CFrame.Angles(0.6, 0, 0) else CFrame.identity))
		if qp >= DUTY and q < DUTY and amp > 0.25 and not veiled then
			b.step(b.root.CFrame:PointToWorldSpace(t), math.clamp(b.speed / 4, 0.4, 1.2)) -- 손바닥·발바닥 짚기
		end
	end
end

return M
