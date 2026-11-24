--!strict
-- c4n 운구대: 바퀴 + 노 젓기. 여섯 손이 바닥을 짚고 뒤로 밀어 카트째 굴러간다(손 IK: 어깨 → 팔꿈치 → 손목).
-- 평소(물결 젓기): 앞 → 가운데 → 뒤 쌍 순서로 위상 1/3씩, 짚은 손은 바닥(세상)에 고정 = 위상을 이동 거리에 묶음.
-- 돌진(서버 Charging): 여섯 손이 한꺼번에 뻗었다 민다. 예고(Slap): 여섯 손이 동시에 바닥을 두 번 친다.
-- 충돌(Crash): 쟁반이 앞으로 숙였다 돌아오고 이름표·발이 흔들린다. 바퀴는 거리 / 반지름만큼 구른다.
local A = require(script.Parent.Parent.CreatureAnim)

local M = {}

local FLOOR = -2
local BY = 2.55 -- 엎드린 가슴 높이(바닥 기준)
local WR = 0.36
local Z3 = { -1.75, 0, 1.75 } -- 시안 z(앞 +): 뒤 몸 · 가운데 몸 · 앞 몸
local ORDER = { 0.66, 0.33, 0 } -- 물결 젓기 위상(앞 몸이 먼저)
local CASTERS = { "casterFL", "casterFR", "casterRL", "casterRR" }

local function ik(a: Vector3, c: Vector3, l1: number, l2: number, pole: Vector3): (Vector3, Vector3)
	local d = c - a
	local dist = math.clamp(d.Magnitude, 0.05, l1 + l2 - 0.01)
	local dir = d.Unit
	local x = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
	local h = math.sqrt(math.max(0, l1 * l1 - x * x))
	local side = pole - a
	side = side - dir * side:Dot(dir)
	if side.Magnitude < 1e-3 then
		side = Vector3.new(0, 1, 0)
	end
	local el = a + dir * x + side.Unit * h
	return el, el + (c - el).Unit * l2
end

-- 뼈를 쉬는 방향(rest) → 원하는 방향(want)으로 돌리는 회전(부모 기준)
local function aim(b: A.Body, name: string, rest: Vector3, want: Vector3, extra: CFrame?): CFrame
	local r = CFrame.fromRotationBetweenVectors(rest.Unit, want.Unit)
	local full = if extra then extra * r else r
	local rx, ry, rz = full:ToEulerAnglesYXZ()
	A.pose(b, name, rx, ry, rz)
	return r
end

function M.init(b: A.Body)
	local d = b.data
	d.p = math.random()
	d.roll = 0
	d.sync = 0
	d.pitch = 0
	d.pitchV = 0
	d.tag = 0
	d.tagV = 0
	d.head = 0
	d.slapT = -1
	d.lastSlap = b.model:GetAttribute("Slap")
	d.lastCrash = b.model:GetAttribute("Crash")
	d.down = {} :: { [string]: boolean }
end

function M.step(b: A.Body, dt: number)
	local d = b.data
	local charging = b.model:GetAttribute("Charging") == true
	local s = b.model:GetAttribute("Slap")
	if s ~= d.lastSlap then
		d.lastSlap = s
		d.slapT = 0
	end
	local cr = b.model:GetAttribute("Crash")
	if cr ~= d.lastCrash then
		d.lastCrash = cr
		d.pitchV -= 2.2 -- 쟁반이 앞으로 숙여짐
		d.tagV += 9
	end
	d.sync = A.approach(d.sync, if charging then 1 else 0, 6, dt)
	local fwd = -b.vel.Z
	-- 젓기 방식: 물결(주기 3, 짚는 비율 0.6) ↔ 일제(주기 7, 짧게 밀고 길게 미끄러짐)
	local len = 3 + 4 * d.sync
	local swing = 0.4 + 0.25 * d.sync
	d.p = (d.p + fwd * dt / len) % 1
	local moving = math.clamp(b.speed / 1.5, 0, 1)
	-- 예고: 0.6초 동안 여섯 손이 함께 바닥을 두 번 친다
	local slapLift = -1
	if d.slapT >= 0 then
		local t0 = d.slapT
		d.slapT += dt
		local t = d.slapT
		slapLift = math.abs(math.sin(math.min(t, 0.6) / 0.3 * math.pi))
		for _, hit in { 0.3, 0.6 } do
			if t0 < hit and t >= hit then
				b.step(b.root.CFrame:PointToWorldSpace(Vector3.new(0, FLOOR, -1)), 1.3)
			end
		end
		if t >= 0.7 then
			d.slapT = -1
		end
	end
	-- 쟁반(몸 전체): 충돌 때 숙였다 스프링으로 복귀, 밀 때마다 아주 작게 출렁
	d.pitchV += ((0 - d.pitch) * 40 - d.pitchV * 7) * dt
	d.pitch += d.pitchV * dt
	local bob = 0.03 * A.wave(d.p * 3) * moving * (1 - d.sync)
	A.pose(b, "tray", d.pitch * 0.12 + 0.04 * d.sync, 0, 0, Vector3.new(0, bob, 0))
	-- 세 몸의 등이 물결처럼(아주 작게)
	A.pose(b, "spine0", 0, 0, 0)
	for k = 1, 3 do
		A.pose(b, "spine" .. k, 0.02 * math.sin(b.t * 2 + k) * (1 - d.sync), 0, 0.02 * A.wave(d.p + k / 3) * moving)
	end
	-- 머리: 바닥을 향해 늘어져 흔들리다가, 돌진·예고 때 들린다
	local headT = if charging or d.slapT >= 0 then 1 else 0
	d.head = A.approach(d.head, headT, 5, dt)
	A.pose(b, "neck", -0.5 * d.head, 0, 0.05 * math.sin(b.t * 1.3))
	A.pose(b, "head", -0.6 * d.head + 0.08 * A.wave(d.p * 2) * moving, 0.1 * math.sin(b.t * 0.8), 0)
	-- 여섯 팔
	for k = 1, 3 do
		local zc = Z3[k]
		for _, sd in { 1, -1 } do
			local side = if sd > 0 then "L" else "R"
			local shN, elN, wrN = "sh" .. k .. side, "el" .. k .. side, "wr" .. k .. side
			local restUp, restFore = b.tip[shN], b.tip[elN]
			if restUp and restFore and restUp.Magnitude > 0 then
				local off = ORDER[k] * (1 - d.sync)
				local q = (d.p - off) % 1
				local a = (1 - swing) * len / 2
				local f, lift
				if q < swing then
					local u = q / swing
					local sm = u * u * (3 - 2 * u)
					f, lift = -a + 2 * a * sm, math.sin(u * math.pi)
				else
					f, lift = a - 2 * a * (q - swing) / (1 - swing), 0
				end
				f = math.clamp(f, -1.3, 1.3) * moving
				lift *= moving
				if slapLift >= 0 then
					f, lift = 0.6, slapLift
				end
				local shp = Vector3.new(sd * 0.92, FLOOR + BY + 0.02, -(zc + 0.1))
				local hand = Vector3.new(sd * 2.05, FLOOR + 0.1 + lift * 0.75, -(zc + 0.15) - f)
				local el, wr = ik(shp, hand, restUp.Magnitude, restFore.Magnitude, shp + Vector3.new(sd * 0.6, 1, -0.5))
				local r1 = aim(b, shN, restUp, el - shp)
				local r2 = aim(b, elN, restFore, r1:VectorToObjectSpace(wr - el))
				-- 손바닥은 바닥과 평평하게(위 두 회전을 되돌림), 들린 동안은 손끝이 처진다
				local flatten = (r1 * r2):Inverse()
				local rx, ry, rz = (flatten * CFrame.Angles(0.6 * lift, 0, 0)):ToEulerAnglesYXZ()
				A.pose(b, wrN, rx, ry, rz)
				-- 짚는 순간 = 손바닥 소리
				local down = q >= swing
				if down and d.down[shN] == false and moving > 0.3 and slapLift < 0 then
					b.step(b.root.CFrame:PointToWorldSpace(hand), math.clamp(b.speed / 10, 0.3, 1.4))
				end
				d.down[shN] = down
			end
		end
	end
	-- 바퀴: 이동 거리 / 반지름만큼 구름. 앞바퀴만 회전축 유격으로 흔들림
	d.roll = (d.roll + fwd * dt / WR) % (math.pi * 2)
	for i, name in CASTERS do
		local wob = if i <= 2 then 0.15 * math.sin(b.t * 9 + i) * moving else 0
		A.pose(b, name, -d.roll, wob, 0)
	end
	-- 들린 발·이름표: 속도에 끌려 뒤로 젖혀지고 펄럭임(감쇠 진자)
	local tagT = -math.clamp(b.speed * 0.045, 0, 0.9) + 0.12 * math.sin(b.t * (3 + b.speed * 0.6)) * math.clamp(b.speed / 6, 0, 1)
	d.tagV += ((tagT - d.tag) * 30 - d.tagV * 3) * dt
	d.tag += d.tagV * dt
	A.pose(b, "tag", d.tag, 0, 0.1 * math.sin(b.t * 2.3))
	local footSway = 0.06 * math.sin(b.t * 1.7) + 0.04 * A.wave(d.p) * moving
	A.pose(b, "shinL", footSway, 0, 0)
	A.pose(b, "shinR", -footSway * 0.8, 0, 0)
	A.pose(b, "footL", -d.tag * 0.15, 0, 0)
	A.pose(b, "footR", 0.05 * math.sin(b.t * 2.1), 0, 0)
end

return M
