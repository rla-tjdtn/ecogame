--!strict
-- c9n 깔린 것: 가장자리 물결 활공(가오리식). 걷지도 기지도 않는다.
-- 옆 지느러미 사슬(fin*1→2→3)이 바깥으로 갈수록 늦게 접혔다 펴지고, 등뼈 네 마디엔 앞 → 뒤로 흐르는 작은 물결.
-- 위상 = 이동 거리 / 5(주기 길이) + 아주 느린 숨. 쫓을 땐 두 손이 번갈아 바닥을 짚고 끌어당긴다(그때만 젖은 소리 b.step).
-- 서버 속성: Flat(음파 — 납작: 물결 멈춤, 몸 내려앉고 팔다리 벌어짐, 입술 닫힘), Lurk(매복 — 손가락만 톡…톡),
--           Grab(발목 낚아채기 — 붉은 입술이 60° 들리며 두 손이 앞으로 뻗음)
local A = require(script.Parent.Parent.CreatureAnim)

local M = {}

local STRIDE = 5.0
local PULL = 2.2 -- 쫓을 때 손 한 번 당기는 거리

function M.init(b: A.Body)
	local d = b.data
	d.p = math.random()
	d.pull = 0
	d.flat = 0
	d.lip = 0
	d.reach = 0
	d.grabT = -1
	d.lastGrab = b.model:GetAttribute("Grab")
	d.side = 0
end

function M.step(b: A.Body, dt: number)
	local d = b.data
	local flatOn = b.model:GetAttribute("Flat") == true
	local lurk = b.model:GetAttribute("Lurk") == true
	d.flat = A.approach(d.flat, if flatOn then 1 else 0, if flatOn then 15 else 3, dt) -- 납작해지는 건 0.2초, 펴지는 건 천천히
	local g = b.model:GetAttribute("Grab")
	if g ~= d.lastGrab then
		d.lastGrab = g
		d.grabT = 0
	end
	local grab = 0
	if d.grabT >= 0 then
		d.grabT += dt
		grab = if d.grabT < 0.25 then d.grabT / 0.25 elseif d.grabT < 1.2 then 1 else math.max(0, 1 - (d.grabT - 1.2) / 0.6)
		if d.grabT > 1.8 then
			d.grabT = -1
		end
	end
	local fwd = -b.vel.Z
	local moving = math.clamp(b.speed / 3, 0, 1)
	d.p = (d.p + math.abs(fwd) * dt / STRIDE + dt * 0.08) % 1
	local live = 1 - d.flat
	local amp = (0.12 + 0.2 * moving) * live
	local ph = d.p * math.pi * 2
	-- 옆 가장자리 물결: 바깥 마디일수록 늦고 크다(양쪽 같은 위상 = 가오리 날갯짓)
	for i = 1, 3 do
		local w = amp * (0.6 + 0.25 * i) * math.sin(ph - i * 0.9)
		A.pose(b, "finL" .. i, 0, 0, -w)
		A.pose(b, "finR" .. i, 0, 0, w)
	end
	-- 등뼈: 앞 → 뒤로 흐르는 작은 물결, 납작해지면 몸이 바닥에 내려앉는다. 돌 때는 몸통이 옆으로 살짝 휜다
	d.side = A.approach(d.side, math.clamp(b.vel.X * 0.03, -0.25, 0.25), 4, dt)
	local sw = 0.035 * live * (0.4 + moving)
	A.pose(b, "spine0", sw * math.sin(ph + 1.5) * 0.5, 0, 0, Vector3.new(0, -0.12 * d.flat, 0))
	A.pose(b, "spine1", sw * math.sin(ph + 1.0), -d.side * 0.5, 0)
	A.pose(b, "spine2", sw * math.sin(ph + 0.5), -d.side * 0.5, 0)
	A.pose(b, "spine3", sw * math.sin(ph) + 0.05 * moving * live, 0, 0)
	-- 두개골·입술: 평소 아주 조금 들썩, 쫓을 땐 앞끝이 들리고, 낚아챌 땐 60°
	local lipT = (0.06 + 0.06 * math.sin(b.t * 1.3)) * live
	if b.state == "Chase" then
		lipT = 0.4 * live
	end
	lipT = math.max(lipT, 1.05 * grab)
	d.lip = A.approach(d.lip, lipT, 10, dt)
	A.pose(b, "skull", 0.12 * d.lip, 0, 0)
	A.pose(b, "lip", d.lip, 0, 0)
	-- 팔: 쫓을 땐 번갈아 앞으로 짚고 끌어당김(위상 = 거리 / PULL), 납작하면 옆으로 벌어짐, 낚아챌 땐 둘 다 앞으로
	local chasing = b.state == "Chase" and d.flat < 0.5
	local pullOld = d.pull
	if chasing then
		d.pull = (d.pull + math.max(0, fwd) * dt / PULL) % 1
		-- 한 손이 바닥을 짚는 순간(반 주기마다): 젖은 천 끄는 소리(작게)
		if math.floor(pullOld * 2) ~= math.floor(d.pull * 2) and b.speed > 2 then
			local side = if d.pull < 0.5 then -1.8 else 1.8
			b.step(b.root.CFrame:PointToWorldSpace(Vector3.new(side, -1.2, -4.3)), 0.25)
		end
	end
	d.reach = A.approach(d.reach, grab, 12, dt)
	local tap = if lurk then math.max(0, math.sin(b.t * 2.4)) ^ 8 * 0.35 else 0
	for _, s in { { "L", -1, 0 }, { "R", 1, 0.5 } } do
		local n, sg, off = s[1] :: string, s[2] :: number, s[3] :: number
		local swing = if chasing then A.wave(d.pull + off) * 0.35 else 0.05 * math.sin(b.t * 0.7 + off * 6)
		local spread = 0.3 * d.flat
		-- 팔 뿌리는 y(좌우 휘두름)로 앞뒤를, 손은 x 로 손끝을 바닥에 박았다 뗀다
		A.pose(b, "arm" .. n, 0, sg * (swing * 0.6 - spread) - sg * 0.25 * d.reach, 0)
		local lift = if chasing then math.max(0, A.wave(d.pull + off + 0.25)) * 0.25 else 0
		A.pose(b, "hand" .. n, -lift - tap * (if n == "L" then 1 else 0.6) + 0.2 * d.reach, sg * (swing * 0.4 - spread * 0.5) - sg * 0.3 * d.reach, 0)
		-- 다리: 끌리며 살짝 흔들림, 납작하면 벌어짐
		local drag = 0.08 * math.sin(ph + off * 6) * moving * live
		A.pose(b, "leg" .. n, 0, sg * (drag + 0.2 * d.flat), 0)
		A.pose(b, "foot" .. n, 0, sg * drag * 0.8, 0)
	end
end

return M
