--!strict
-- c7n 굴렁쇠: 고리 전체(Hoop 뼈)를 굴린다. 구름 각 = 이동 거리 / 반지름(미끄러짐 없음).
-- 방향 전환(서버 Spin 속성) 땐 동전처럼 쓰러져 돌았다가 다시 일어선다. 한 바퀴마다 머리가 바닥을 스치는 소리.
local A = require(script.Parent.Parent.CreatureAnim)

local M = {}
local RADIUS = 1.98

function M.init(b: A.Body)
	b.data.roll = 0
	b.data.spin = -1
	b.data.lastSpin = b.model:GetAttribute("Spin")
	b.data.nextThump = math.pi * 2
	b.data.tilt = 0
end

function M.step(b: A.Body, dt: number)
	local d = b.data
	local sp = b.model:GetAttribute("Spin")
	if sp ~= d.lastSpin then
		d.lastSpin = sp
		d.spin = 0 -- 쓰러져 돌기 시작
	end
	local tiltT, yaw = 0, 0
	if d.spin >= 0 then
		d.spin += dt
		local t = d.spin
		-- 0~0.5 쓰러짐, 0.5~1.3 웅웅 돌기, 1.3~1.8 일어섬
		if t < 0.5 then
			tiltT = math.rad(68) * (t / 0.5)
		elseif t < 1.3 then
			tiltT = math.rad(68)
			yaw = (t - 0.5) * 9
		elseif t < 1.8 then
			tiltT = math.rad(68) * (1 - (t - 1.3) / 0.5)
		else
			d.spin = -1
		end
	elseif b.state == "Wander" and b.speed < 0.5 then
		tiltT = math.rad(13) -- 서 있을 땐 훌라후프처럼 비스듬히 기대 있음
	end
	d.tilt = A.approach(d.tilt, tiltT, 10, dt)
	-- 구르기: 앞(-Z)으로 가면 고리 윗부분이 앞으로(X 축 음의 회전)
	local fwd = -b.vel.Z
	d.roll -= fwd * dt / RADIUS
	if math.abs(d.roll) >= d.nextThump then
		d.nextThump += math.pi * 2
		b.step(b.root.Position + Vector3.new(0, -1.9, 0), math.clamp(b.speed / 14, 0.3, 1.4))
	end
	A.pose(b, "Hoop", d.roll, yaw, d.tilt)
end

return M
