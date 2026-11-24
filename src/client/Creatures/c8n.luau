--!strict
-- c8n 둥글게: 고리 회전 미끄러짐. RingRoot 가 서버 시계로 초당 25° 돌고(서버가 빈자리 방향을 같은 값으로 계산),
-- 맞잡은 손 매듭 1·3·5 와 2·4 가 번갈아 0.6 들렸다 딛는다(위상 = (이동 + 회전) 거리 / 0.9 주기 길이).
-- 요크는 디딤에 따라 물결처럼 오르내리고, 팔은 어깨 끝 → 매듭 두 마디 IK. 서버 RingR(4 → 2.5)로 고리가 좁혀지면
-- 요크가 안쪽으로 6° → 24° 기운다. 빈 손 둘은 바깥으로 열린 채 2초마다 천천히 쥐었다 편다.
local A = require(script.Parent.Parent.CreatureAnim)

local M = {}

local FLOOR = -2
local R0 = 4
local R_MIN = 2.5
local SPIN = math.rad(25)
local SH_Y = 2.35
local GAP = math.rad(-90)
local STRIDE = 2.0
local UP = Vector3.new(0, 1, 0)

local function dir(a: number): Vector3
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

local function ik(a: Vector3, c: Vector3, l1: number, l2: number, pole: Vector3): Vector3
	local d = c - a
	local dist = math.clamp(d.Magnitude, 0.05, l1 + l2 - 0.01)
	local dd = d.Unit
	local x = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
	local h = math.sqrt(math.max(0, l1 * l1 - x * x))
	local side = pole - a
	side = side - dd * side:Dot(dd)
	if side.Magnitude < 1e-3 then
		side = UP
	end
	return a + dd * x + side.Unit * h
end

local function poseCF(b: A.Body, name: string, cf: CFrame, offset: Vector3?)
	local rx, ry, rz = cf:ToEulerAnglesYXZ()
	A.pose(b, name, rx, ry, rz, offset)
end

function M.init(b: A.Body)
	local d = b.data
	d.p = math.random()
	d.r = R0
	d.group = -1
	d.stepIdx = 0
end

function M.step(b: A.Body, dt: number)
	local d = b.data
	local rr = b.model:GetAttribute("RingR")
	d.r = A.approach(d.r, if typeof(rr) == "number" then rr else R0, 4, dt)
	local R = d.r
	local close = math.clamp((R0 - R) / (R0 - R_MIN), 0, 1)
	local sigma = (workspace:GetServerTimeNow() * SPIN) % (math.pi * 2)
	A.pose(b, "RingRoot", 0, sigma, 0)
	-- 디딤 위상: 미끄러짐 + 회전(둘레 속도) 거리에 묶는다
	d.p = (d.p + (b.speed + SPIN * R) * dt / STRIDE) % 1
	local function liftOf(k: number): number
		return A.lift(d.p + (k % 2) * 0.5, 0.45) * 0.6
	end
	-- 매듭 착지 소리: 한 무리(1·3·5 / 2·4)가 디딜 때 그중 하나에서
	local group = if (d.p % 1) < 0.45 then 0 elseif (d.p % 1) >= 0.5 and (d.p % 1) < 0.95 then 1 else -1
	if group == -1 and d.group ~= -1 then
		d.stepIdx = d.stepIdx % 5 + 1
		local a = GAP + math.rad(60 * d.stepIdx) - sigma
		b.step(b.root.CFrame:PointToWorldSpace(dir(a) * R + Vector3.new(0, FLOOR, 0)), math.clamp(0.4 + b.speed / 10, 0.4, 1.2))
	end
	d.group = group
	-- 매듭(디딤)
	local clasp: { Vector3 } = {}
	local lifts: { number } = {}
	for k = 1, 5 do
		local a = GAP + math.rad(60 * k)
		local l = liftOf(k)
		lifts[k] = l
		local off = dir(a) * (R - R0) + UP * l
		clasp[k] = dir(a) * R0 + Vector3.new(0, FLOOR + 0.18 + 0.05, 0) + off
		A.pose(b, "Clasp" .. k, 0.25 * l, 0, 0, off)
	end
	-- 요크와 팔
	local y0 = FLOOR + SH_Y
	for i = 1, 6 do
		local a = GAP + math.rad(30 + 60 * (i - 1))
		local u, t = dir(a), Vector3.new(-math.sin(a), 0, math.cos(a))
		local yc = u * R0 + Vector3.new(0, y0, 0)
		local lp = if i >= 2 then lifts[i - 1] else 0
		local ln = if i <= 5 then lifts[i] else 0
		local bob = 0.3 * (lp + ln) - 0.06
		local tilt = math.rad(6 + 18 * close)
		local rot = CFrame.fromAxisAngle(t, tilt)
		local off = u * (R - R0) + UP * bob
		poseCF(b, "Yoke" .. i, rot, off)
		for _, s in { { "P", 1 }, { "M", -1 } } do
			local tag, sg = s[1] :: string, s[2] :: number
			local empty = (i == 6 and tag == "P") or (i == 1 and tag == "M")
			local upN, foreN = "Arm" .. i .. tag .. "_Up", "Arm" .. i .. tag .. "_Fore"
			local restUp, restFore = b.tip[upN], b.tip[foreN]
			if restUp and restFore and restUp.Magnitude > 0 then
				local tipRest = yc + t * (0.78 * sg) - UP * 0.08
				local S = yc + off + rot * (tipRest - yc)
				local H: Vector3
				if empty then
					-- 빈 손: 플레이어를 부르듯 바깥으로 뻗었다 당겼다(2초)
					local reach = 0.15 * math.sin(b.t * math.pi)
					local out = dir(GAP - sg * math.rad(13))
					H = out * (R + 0.9 + reach) + Vector3.new(0, FLOOR + 1.35 + 0.1 * math.sin(b.t * 1.3 + i), 0)
				else
					H = clasp[if tag == "P" then i else i - 1]
				end
				local el = ik(S, H, restUp.Magnitude, restFore.Magnitude, S + u * 0.5 + UP * 1.2)
				local r1 = CFrame.fromRotationBetweenVectors(restUp.Unit, rot:VectorToObjectSpace(el - S).Unit)
				poseCF(b, upN, r1)
				local r2 = CFrame.fromRotationBetweenVectors(restFore.Unit, (rot * r1):VectorToObjectSpace(H - el).Unit)
				poseCF(b, foreN, r2)
				if empty then
					-- 쥐었다 펴기: 손 전체가 손가락 쪽으로 접혔다 펴짐(옆 축)
					local out = dir(GAP - sg * math.rad(13))
					local side = Vector3.new(-out.Z, 0, out.X)
					local grip = 0.55 * (0.5 - 0.5 * math.cos(b.t * math.pi))
					local parent = rot * r1 * r2
					local want = CFrame.fromAxisAngle(side, -grip)
					poseCF(b, "Arm" .. i .. tag .. "_Hand", parent:Inverse() * want)
				end
			end
		end
	end
end

return M
