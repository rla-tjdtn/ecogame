--!strict
-- c2n 짐걸이: 빔 밑 매달림 이동. 갈고리 하나씩(앞왼 → 앞오른 → 뒤왼 → 뒤오른) 풀어 앞에 다시 건다.
-- 걸린 갈고리는 빔(세상)에 붙어 있고 몸만 지나가게: 위상 = 이동 거리 / 주기 길이. 다시 걸 때 딸깍(b.step).
-- 풀 때마다 몸이 반대쪽으로 흔들린다(Hang 진자). 쫓을 땐 '던지기': 앞 둘·뒤 둘을 한꺼번에 옮긴다.
-- 위장(서버 Wrap 속성): 네 갈고리를 한 점으로 모으고 몸을 말아 올린다(0.4초), 풀 땐 0.8초. 붉은 가닥만 흔들린다.
local A = require(script.Parent.Parent.CreatureAnim)

local M = {}

local SPAN = 2.1 -- 뿌리(견갑·골반)에서 빔까지 대략의 높이: 갈고리 앞뒤 거리 → 각도
local BEAM_Y = 10.2 -- 루트 기준 빔 높이(소리 위치)

type Limb = { key: string, upper: string, lower: string, hook: string, z: number }
local LIMBS: { Limb } = {
	{ key = "FL", upper = "UpperArmFL", lower = "ForearmFL", hook = "HookFL", z = -1.9 },
	{ key = "FR", upper = "UpperArmFR", lower = "ForearmFR", hook = "HookFR", z = -0.9 },
	{ key = "BL", upper = "ThighBL", lower = "ShinBL", hook = "HookBL", z = 1.55 },
	{ key = "BR", upper = "ThighBR", lower = "ShinBR", hook = "HookBR", z = 2.35 },
}
-- 걸음 방식: 다리마다 위상 시작점, 풀려 있는 비율, 한 주기 길이(스터드)
local CRAWL = { off = { FL = 0, FR = 0.25, BL = 0.5, BR = 0.75 }, swing = 0.25, len = 2.4 }
local THROW = { off = { FL = 0, FR = 0, BL = 0.5, BR = 0.5 }, swing = 0.35, len = 3.0 }

function M.init(b: A.Body)
	b.data.p = math.random()
	b.data.wrap = 0
	b.data.roll = 0
	b.data.pitch = 0
	b.data.s1 = 0
	b.data.s2 = 0
	b.data.sv1 = 0
	b.data.sv2 = 0
	b.data.mode = 0 -- 0 기어가기 ↔ 1 던지기(부드럽게 섞음)
	b.data.down = {} :: { [string]: boolean }
end

-- 한 다리: 위상 q(0~1, 0부터 swing 까지 풀려서 앞으로) → 앞쪽 거리 f(스터드), 들림 0~1
local function limbAt(q: number, swing: number, len: number): (number, number)
	local a = (1 - swing) * len / 2 -- 걸린 동안 몸이 지나가는 거리의 절반(세상에 고정)
	if q < swing then
		local u = q / swing
		local s = u * u * (3 - 2 * u)
		return -a + 2 * a * s, math.sin(u * math.pi)
	end
	local u = (q - swing) / (1 - swing)
	return a - 2 * a * u, 0
end

function M.step(b: A.Body, dt: number)
	local d = b.data
	local wrapped = b.model:GetAttribute("Wrap") == true
	d.wrap = A.approach(d.wrap, if wrapped then 1 else 0, if wrapped then 9 else 4.5, dt)
	local w = d.wrap
	local chasing = b.state == "Chase"
	d.mode = A.approach(d.mode, if chasing then 1 else 0, 3, dt)
	local g = if d.mode > 0.5 then THROW else CRAWL
	-- 위상은 이동 거리에 묶는다(앞 = -Z)
	local fwd = -b.vel.Z
	if w < 0.5 then
		d.p = (d.p + fwd * dt / g.len) % 1
	end
	local p = d.p
	-- 몸 흔들림(진자): 기어갈 땐 갈고리를 풀 때마다 좌우로, 던질 땐 앞뒤로 크게
	local moving = math.clamp(b.speed / 3, 0, 1) * (1 - w)
	local rollT = 0.2 * A.wave(p * 2) * moving * (1 - d.mode) + 0.03 * math.sin(b.t * 0.9)
	local pitchT = 0.16 * A.wave(p * 2 + 0.25) * moving * d.mode
	d.roll = A.approach(d.roll, rollT, 6, dt)
	d.pitch = A.approach(d.pitch, pitchT, 6, dt)
	-- 위장 자세: 몸을 빔 쪽으로 끌어올리고(진자 점 기준) 가슴·골반 끝을 말아 올린다
	local hangRx = d.pitch - 0.25 * w
	local spine1Rx = 0.35 * w
	local spine2Rx = 0.75 * w + 0.04 * math.sin(b.t * 1.3)
	A.pose(b, "Hang", hangRx, 0, d.roll, Vector3.new(0, 0.7 * w, 0))
	A.pose(b, "Pelvis", -0.3 * w, 0, 0)
	A.pose(b, "Spine1", spine1Rx, 0, 0)
	A.pose(b, "Spine2", spine2Rx, 0, 0)
	A.pose(b, "NeckStump", 0.5 * w + 0.08 * math.sin(b.t * 1.7), 0.1 * math.sin(b.t * 0.6), 0)
	A.pose(b, "Band1", 0, 0.05 * math.sin(b.t * 2.1), 0)
	A.pose(b, "Band2", 0, -0.05 * math.sin(b.t * 1.9), 0)
	for _, lb in LIMBS do
		local isArm = lb.key:sub(1, 1) == "F"
		local q = (p - g.off[lb.key]) % 1
		local f, lift = limbAt(q, g.swing, g.len)
		f *= 1 - w
		lift *= 1 - w
		-- 위장: 갈고리를 몸 가운데(진자 점) 위로 모은다
		f += lb.z * w * 0.85
		-- 몸이 기운 만큼은 되돌려 갈고리가 빔 위에 남게
		local parentRx = hangRx + (if isArm then -0.3 * w + spine1Rx + spine2Rx else -0.3 * w)
		local rx = -math.atan(f / SPAN) - parentRx
		A.pose(b, lb.upper, rx, 0, -d.roll * 0.8)
		-- 풀린 동안: 팔꿈치·무릎을 굽혀 갈고리를 빔에서 내리고 손가락을 연다
		local bend = lift * 0.55 + 0.4 * w
		A.pose(b, lb.lower, if isArm then bend else -bend, 0, 0)
		A.pose(b, lb.hook, -lift * 1.3 - 0.3 * w, 0, 0)
		-- 다시 걸리는 순간 = 딸깍(빔에 갈고리)
		local down = q >= g.swing
		if down and d.down[lb.key] == false and w < 0.5 and b.speed > 0.3 then
			local at = b.root.CFrame:PointToWorldSpace(Vector3.new(0, BEAM_Y, lb.z))
			b.step(at, math.clamp(b.speed / 8, 0.3, 1.2))
		end
		d.down[lb.key] = down
	end
	-- 붉은 가닥: 2마디 감쇠 진자(움직임 반대로 끌림 + 몸 흔들림을 늦게 따라감)
	local t1 = math.clamp(b.vel.Z * 0.06, -0.6, 0.6) - d.pitch * 0.8
	local t2 = d.s1 * 0.6
	d.sv1 += ((t1 - d.s1) * 30 - d.sv1 * 4) * dt
	d.s1 += d.sv1 * dt
	d.sv2 += ((t2 - d.s2) * 22 - d.sv2 * 3) * dt
	d.s2 += d.sv2 * dt
	local sway = 0.06 * math.sin(b.t * 1.4)
	A.pose(b, "Strand1", d.s1, 0, -d.roll * 0.7 + sway)
	A.pose(b, "Strand2", d.s2, 0, sway * 0.8)
end

return M
