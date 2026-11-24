--!strict
-- c1n 청음체: 회전 삼각 보행. 손 둘로 체중을 받치고 셋째 팔을 들어 바깥으로 120° 크게 돌려 딛는 동안 몸통(Hub)이 40° 돈다.
-- 짚은 두 손은 세상에 붙어 있게(몸통이 도는 만큼 반대로 돌림) — 한 순간 최소 2점 접지. 딛을 때마다 손바닥 '탁'(b.step).
-- 목뼈 3마디가 몸통 회전을 반대로 상쇄해 접시는 늘 겨눈 쪽(앞, 또는 서버 AimAt)을 본다 — 몸은 돌며 오는데 접시는 너를 본다.
-- 서버 Listening = 겨눔 0.8초 → 갈비 깔때기가 활짝(듣기). 추격 중 3 안이면 갈비가 닫힌다(촤악).
local Players = game:GetService("Players")
local A = require(script.Parent.Parent.CreatureAnim)

local M = {}
local LEGS = { B = -60, A = 60, C = 180 } -- (서버와 같은 다리 방향)
local ORDER = { "B", "A", "C" } -- 도는 방향 순서로 하나씩 든다
local TURN = math.rad(40) -- 한 걸음에 몸통이 도는 각
local STEP = 1.5 -- 한 걸음에 나아가는 거리

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

local function smooth(x: number): number
	return x * x * (3 - 2 * x)
end

function M.init(b: A.Body)
	local d = b.data
	d.n = math.random(0, 2)
	d.p = 0
	d.aim = 0
	d.pitch = 0
	d.flare = 0
	d.check = 0
	d.close = false
	d.axis = {}
	for name, deg in LEGS do
		local t = math.rad(deg)
		local u = Vector3.new(math.sin(t), 0, -math.cos(t))
		d.axis[name] = Vector3.yAxis:Cross(u).Unit
	end
end

function M.step(b: A.Body, dt: number)
	local d = b.data
	local moving = math.clamp(b.speed / 3, 0, 1)
	d.p += b.speed * dt / STEP
	local landed: string? = nil
	if d.p >= 1 then
		landed = ORDER[d.n % 3 + 1]
		d.n += 1
		d.p -= 1
	end
	local p = d.p
	local psi = TURN * (d.n + p)
	A.pose(b, "Hub", 0.03 * math.sin(p * math.pi * 2) * moving, -psi, 0, Vector3.new(0, -0.08 * math.sin(p * math.pi) * moving, 0))
	-- 다리: 움직이는 다리는 −40° → +40°(공중에서 120°), 짚은 다리는 몸통 회전을 상쇄
	local m = d.n % 3 + 1
	for k, name in ORDER do
		local rel = (k - m) % 3 -- 0 = 지금 드는 다리, 2 = 바로 전에 딛은 다리, 1 = 두 걸음 전
		local off, lift = 0, 0
		if rel == 0 then
			off = -TURN + 2 * TURN * smooth(p)
			lift = math.sin(p * math.pi) * moving
		elseif rel == 2 then
			off = TURN * (1 - p)
		else
			off = -TURN * p
		end
		A.pose(b, "Hip" .. name, 0, -off, 0)
		local ax: Vector3 = d.axis[name]
		local up = CFrame.fromAxisAngle(ax, -0.55 * lift)
		local rx, ry, rz = up:ToEulerAnglesYXZ()
		A.pose(b, "Arm" .. name, rx, ry, rz)
		local bend = CFrame.fromAxisAngle(ax, 0.35 * lift) -- 팔꿈치가 더 꺾이며 손이 들림
		rx, ry, rz = bend:ToEulerAnglesYXZ()
		A.pose(b, "Fore" .. name, rx, ry, rz)
		local wrist = CFrame.fromAxisAngle(ax, 0.4 * lift) -- 손목을 젖혀 딛기 직전 손바닥을 편다
		rx, ry, rz = wrist:ToEulerAnglesYXZ()
		A.pose(b, "Hand" .. name, rx, ry, rz)
	end
	if landed and moving > 0.3 then
		local t = math.rad(LEGS[landed])
		local at = Vector3.new(math.sin(t) * 2.2, -2.5, -math.cos(t) * 2.2)
		b.step(b.root.CFrame:PointToWorldSpace(at), math.clamp(b.speed / 8, 0.4, 1.3)) -- 탁
	end
	-- 접시 겨눔: 듣는 중이면 AimAt 쪽, 아니면 앞. 몸통 회전(psi)을 목이 상쇄
	local listening = b.model:GetAttribute("Listening") == true
	local aimYaw, aimPitch = 0, 0
	local at = b.model:GetAttribute("AimAt")
	if listening and typeof(at) == "Vector3" then
		local lp = b.root.CFrame:PointToObjectSpace(at)
		aimYaw = math.atan2(-lp.X, -lp.Z)
		aimPitch = math.clamp(math.atan2(lp.Y - 3, math.sqrt(lp.X * lp.X + lp.Z * lp.Z)), -0.4, 0.4)
	end
	d.aim = A.approach(d.aim, aimYaw, if listening then 5 else 3, dt) -- (0.8초 안에 겨눔)
	d.pitch = A.approach(d.pitch, aimPitch, 5, dt)
	A.pose(b, "Neck1", 0, psi + d.aim, 0)
	A.pose(b, "Neck2", 0.04 * math.sin(b.t * 1.1), 0, 0.03 * math.sin(b.t * 0.8))
	A.pose(b, "Neck3", d.pitch + 0.03 * math.sin(b.t * 1.3), 0, 0)
	-- 갈비 깔때기: 평소 0, 듣기 활짝(+), 닫힘(−)
	d.check -= dt
	if d.check <= 0 then
		d.check = 0.15
		d.close = b.state == "Chase" and nearestDist(b.root.Position) < 3.5
	end
	local want = if d.close then -0.7 elseif listening then 0.3 else 0.04 * math.sin(b.t * 1.5)
	d.flare = A.approach(d.flare, want, if d.close then 12 else 4, dt)
	A.pose(b, "RibL", 0, d.flare, 0)
	A.pose(b, "RibR", 0, -d.flare, 0)
	A.pose(b, "Ear", 0, 0, if listening then 0.05 * math.sin(b.t * 40) else 0) -- 고막 떨림
	A.pose(b, "VestFore", 0.06 * math.sin(b.t * 2.3), 0, 0)
end

return M
