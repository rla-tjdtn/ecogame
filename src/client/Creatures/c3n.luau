--!strict
-- c3n 홍예: 벽-벽 버팀 걸음. 한 손이 벽을 짚고 있는 동안 다른 손이 떨어져 앞 벽을 짚는다(아치가 짚은 손을 축으로 돈다).
-- 짚은 손은 벽(세상)에 붙어 있게: 위상 = 이동 거리 / 주기 길이(3스터드, 손 짚기 두 번). 짚을 때마다 철썩(b.step).
-- 쫓을 땐 아치가 벽을 타고 내려와(손목 높이 7 → 4.8) 매달린 손이 머리 높이 가까이 온다.
-- 서버 속성: Mimic(테처럼 굳음 — 완전히 멈추고 손가락만 4초마다 꺾임), Reveal(음파 — 매달린 손 움찔), Grab(밑을 지남 — 목이 늘어나 손이 내려옴)
local A = require(script.Parent.Parent.CreatureAnim)

local M = {}

local CYCLE = 3.0 -- 한 주기(왼손·오른손 한 번씩) 동안 나아가는 거리
local HALF = 0.75 -- 짚은 손이 몸 기준으로 앞→뒤로 지나가는 거리의 절반(= CYCLE / 4)
local SPAN = 7.0 -- 손목 사이
local WRIST_Y = 4.9 -- 루트 기준 손목 높이(벽 짚는 곳)

function M.init(b: A.Body)
	local d = b.data
	d.p = math.random()
	d.lower = 0
	d.tilt = 0
	d.half = if d.p < 0.5 then 0 else 1
	d.n1 = 0
	d.n1v = 0
	d.nz = 0
	d.nzv = 0
	d.drop = 0
	d.grabT = -1
	d.lastGrab = b.model:GetAttribute("Grab")
	d.lastReveal = b.model:GetAttribute("Reveal")
	d.twitch = 0
	d.mimic = 0
end

function M.step(b: A.Body, dt: number)
	local d = b.data
	local mimic = b.model:GetAttribute("Mimic") == true
	d.mimic = A.approach(d.mimic, if mimic then 1 else 0, 3, dt)
	-- 붙잡기: 목뼈가 늘어나며 매달린 손이 0.6초에 내려왔다가 천천히 올라간다
	local g = b.model:GetAttribute("Grab")
	if g ~= d.lastGrab then
		d.lastGrab = g
		d.grabT = 0
	end
	if d.grabT >= 0 then
		d.grabT += dt
		local t = d.grabT
		d.drop = if t < 0.6 then t / 0.6 elseif t < 1.4 then 1 elseif t < 2.6 then 1 - (t - 1.4) / 1.2 else 0
		if t >= 2.6 then
			d.grabT = -1
		end
	end
	-- 음파에 드러남: 매달린 손이 움찔(진자에 충격)
	local rv = b.model:GetAttribute("Reveal")
	if rv ~= d.lastReveal then
		d.lastReveal = rv
		d.n1v += 3
		d.nzv -= 2
	end

	local fwd = -b.vel.Z
	local moving = math.clamp(b.speed / 2, 0, 1) * (1 - d.mimic)
	d.p = (d.p + fwd * dt / CYCLE) % 1
	local half = if d.p < 0.5 then 0 else 1
	local u = (d.p % 0.5) * 2
	-- 손 짚기: 반 주기가 바뀔 때 = 떨어져 있던 손이 벽을 짚음
	if half ~= d.half then
		d.half = half
		if moving > 0.3 then
			local side = if half == 0 then -1 else 1 -- 이번에 짚은 손: half 0 이 시작되면 왼손(A)이 막 짚은 것
			local at = b.root.CFrame:PointToWorldSpace(Vector3.new(side * 4.0, WRIST_Y - 0.6 - d.lower, -HALF))
			b.step(at, math.clamp(b.speed / 6, 0.4, 1.3))
		end
	end
	-- 짚은 손: 몸 기준 앞(-HALF)에서 뒤(+HALF)로(세상에 고정), 떨어진 손: 뒤에서 앞으로 크게 뻗음
	local planted = -HALF + 2 * HALF * u
	local s = u * u * (3 - 2 * u)
	local swinging = HALF - 2 * HALF * s
	local zA = (if half == 0 then planted else swinging) * moving
	local zB = (if half == 0 then swinging else planted) * moving
	local lift = math.sin(u * math.pi) * moving
	-- 아치 전체: 두 손의 가운데로 옮기고, 두 손 앞뒤 차이만큼 돌고, 손을 뻗을 때 앞으로 10° 기운다
	local yaw = math.asin(math.clamp((zA - zB) / SPAN, -0.5, 0.5))
	local lowerT = if b.state == "Chase" and not mimic then 2.1 else 0
	d.lower = A.approach(d.lower, lowerT, 2, dt)
	d.tilt = A.approach(d.tilt, -0.17 * lift, 10, dt)
	local roll = (if half == 0 then 1 else -1) * 0.05 * lift -- 떨어진 손 쪽이 살짝 들림
	A.pose(b, "Root", d.tilt, yaw, roll, Vector3.new(0, -d.lower, (zA + zB) / 2))
	-- 척추는 거의 강체(±6°): 걸을 때만 아주 작은 물결
	for i = 1, 11 do
		local name = string.format("Vert%02d", i)
		A.pose(b, name, 0, 0, 0.012 * moving * math.sin(b.t * 7 + i * 0.6))
	end
	-- 두 손: 떨어진 손은 손바닥이 벽에서 안쪽으로 떨어지고 앞으로 뻗는다
	local liftA = if half == 1 then lift else 0
	local liftB = if half == 0 then lift else 0
	A.pose(b, "HandA_Wrist", -0.5 * liftA, 0, 0.7 * liftA)
	A.pose(b, "HandB_Wrist", -0.5 * liftB, 0, -0.7 * liftB)
	-- 매달린 손: 목뼈 3마디 감쇠 진자(아치가 흔들리는 반대로 늦게) + 붙잡기 때 늘어남
	local t1 = math.clamp(b.vel.Z * 0.05, -0.5, 0.5) - d.tilt * 0.8
	d.n1v += ((t1 - d.n1) * 25 - d.n1v * 3.5) * dt
	d.n1 += d.n1v * dt
	local tz = -roll * 1.5 - yaw * 0.5
	d.nzv += ((tz - d.nz) * 20 - d.nzv * 3) * dt
	d.nz += d.nzv * dt
	local stretch = d.drop * 0.55 -- 마디마다 늘어나는 길이(세 마디 = 1.65)
	A.pose(b, "Neck1", d.n1 * 0.5, 0, d.nz * 0.5, Vector3.new(0, -stretch, 0))
	A.pose(b, "Neck2", d.n1 * 0.3, 0.15 * math.sin(b.t * 0.7) * (1 - d.mimic), d.nz * 0.3, Vector3.new(0, -stretch, 0))
	A.pose(b, "Neck3", d.n1 * 0.2, 0, d.nz * 0.2, Vector3.new(0, -stretch, 0))
	-- 손가락 꺾기: 굳어 있을 땐 4초마다 한 번 천천히, 붙잡을 땐 손이 확 펴졌다 쥔다
	d.twitch = (d.twitch + dt) % 4
	local crack = if d.twitch < 0.5 then math.sin(d.twitch / 0.5 * math.pi) * 0.25 else 0
	A.pose(b, "CrownHand", -0.6 * d.drop + crack, 0.35 * d.drop, 0.1 * math.sin(b.t * 1.1) * (1 - d.mimic))
end

return M
