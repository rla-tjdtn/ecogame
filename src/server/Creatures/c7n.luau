--!strict
-- c7n 굴렁쇠 (7장 학교 · 비인간형) — 사양서: art/creatures/sheets/ch7/c7n_spec.md
-- 뒤로 접혀 제 발목을 쥔 아이의 몸이 닫힌 고리가 되어 구른다. 걷지 않는다.
-- 뼈: HoopCenter(구름·기울기·회전) 하나가 몸 전체를 움직인다. 선은 고리를 따라 이어진 몸통·다리·팔·머리.
-- 공포 장치 「곧은 복도」: 직선에서 빠르게 굴러오지만, 방향을 바꾸려면 1.8초 동안 쓰러져 돌아야 한다(그동안 멈춤).
local Rig = require(script.Parent.Rig)

local M = {}
M.cfg = {
	WanderSpeed = 5,
	InvestigateSpeed = 12,
	ChaseSpeed = 22, -- 플레이어 달리기 18 × 1.2 (직선에서 따라잡힌다)
	AgentRadius = 1.4,
	AgentHeight = 4.5,
	CatchDistance = 2.4,
}
M.spawnLift = 1.2
M.voice = "3" -- (소리: 아직 전용 소리 없음 — 손톱 톡톡 계열을 임시로)

local HIP = 0.98 -- 루트 가운데 높이 = HIP + 1
local FLOOR = -(HIP + 1)
local R = 1.55 -- 몸 중심선 반지름
local CY = FLOOR + 1.98 -- 고리 중심 높이(루트 기준)

-- 고리 위의 점: θ(도, 0 = 바닥 접점, 앞쪽(-Z)으로 증가), 반지름 r, 옆(x)
local function P(deg: number, r: number, x: number): Vector3
	local t = math.rad(deg)
	return Vector3.new(x, CY - r * math.cos(t), -r * math.sin(t))
end

function M.build(cf: CFrame): Model
	local model, root = Rig.shell("Hoop", cf, Vector3.new(1.6, 2, 1.6))
	local lines: { Rig.Line } = {}
	local balls: { Rig.Ball } = {}
	local function arc(d0: number, d1: number, n: number, r: number, x: number, w: number, red: boolean?)
		for i = 0, n - 1 do
			local a, b = d0 + (d1 - d0) * i / n, d0 + (d1 - d0) * (i + 1) / n
			table.insert(lines, { bone = "Hoop", a = P(a, r, x), b = P(b, r, x), r = w, red = red })
		end
	end
	-- 몸통(가슴 → 배 → 골반): 바깥이 배, 안쪽이 등. 두께는 어깨 폭 1.2 → 옆 두 선
	arc(30, 200, 8, R, -0.38, 0.2)
	arc(30, 200, 8, R, 0.38, 0.2)
	-- 갈비뼈: 가슴 쪽 몸을 가로지르는 짧은 선
	for _, d in { 48, 62, 76, 90 } do
		table.insert(lines, { bone = "Hoop", a = P(d, R + 0.12, -0.42), b = P(d, R + 0.12, 0.42), r = 0.06 })
	end
	-- 골반
	table.insert(lines, { bone = "Hoop", a = P(196, R + 0.1, -0.48), b = P(196, R + 0.1, 0.48), r = 0.09 })
	-- 다리(허벅지 → 무릎 → 부러진 두 번째 무릎 → 발목): 고리 나머지를 감싼다, 무릎마다 살짝 밖으로 꺾임
	for _, s in { -1, 1 } do
		local x = 0.3 * s
		table.insert(lines, { bone = "Hoop", a = P(200, R, x), b = P(248, R + 0.1, x), r = 0.16 })
		table.insert(lines, { bone = "Hoop", a = P(248, R + 0.1, x), b = P(286, R + 0.22, x * 1.1), r = 0.13 })
		table.insert(lines, { bone = "Hoop", a = P(286, R + 0.22, x * 1.1), b = P(322, R + 0.05, x), r = 0.11 })
		table.insert(lines, { bone = "Hoop", a = P(322, R + 0.05, x), b = P(344, R - 0.05, x * 0.8), r = 0.09 }) -- 발
		table.insert(balls, { bone = "Hoop", c = P(248, R + 0.1, x), r = 0.16 })
		table.insert(balls, { bone = "Hoop", c = P(286, R + 0.22, x * 1.1), r = 0.15 })
		-- 팔: 어깨(가슴 끝)에서 몸 바깥을 돌아 발목을 쥠
		local ax = 0.56 * s
		table.insert(lines, { bone = "Hoop", a = P(34, R + 0.05, ax), b = P(352, R + 0.3, ax * 1.15), r = 0.1 })
		table.insert(lines, { bone = "Hoop", a = P(352, R + 0.3, ax * 1.15), b = P(326, R + 0.12, ax * 0.75), r = 0.09 })
		table.insert(balls, { bone = "Hoop", c = P(352, R + 0.3, ax * 1.15), r = 0.11 })
	end
	-- 거꾸로 된 머리: 고리 아래쪽(두 발 사이), 정수리가 바닥을 스침
	local hc = P(10, R - 0.05, 0)
	table.insert(balls, { bone = "Hoop", c = hc, r = 0.5 })
	table.insert(lines, { bone = "Hoop", a = hc + Vector3.new(-0.18, 0.05, -0.46), b = hc + Vector3.new(-0.08, 0.06, -0.48), r = 0.05 }) -- 눈(거꾸로)
	table.insert(lines, { bone = "Hoop", a = hc + Vector3.new(0.08, 0.06, -0.48), b = hc + Vector3.new(0.18, 0.05, -0.46), r = 0.05 })
	table.insert(lines, { bone = "Hoop", a = hc + Vector3.new(-0.12, 0.25, -0.44), b = hc + Vector3.new(0.12, 0.25, -0.44), r = 0.05 }) -- 벌린 입(거꾸로라 위)
	-- 안쪽 등뼈 7마디: 고리 안쪽으로 박힌 바퀴살
	for i = 0, 6 do
		local d = 40 + i * 24
		table.insert(lines, { bone = "Hoop", a = P(d, R - 0.3, 0), b = P(d, R - 0.85, 0), r = 0.07 })
	end
	-- 붉은 쓸린 줄(가슴·배 앞면, 회전이 보이게)
	arc(60, 170, 4, R + 0.36, 0, 0.05, true)
	Rig.build(model, root, cf, {
		id = "c7n",
		bones = { { name = "Hoop", parent = nil, joint = Vector3.new(0, CY, 0), tip = Vector3.new(0, 0, -1) } },
		lines = lines,
		balls = balls,
		floorY = FLOOR,
		mass = 0.6,
	})
	Rig.humanoid(model, HIP, M.cfg.WanderSpeed)
	return model
end

-- 방향 전환: 진행 방향이 50° 넘게 바뀌면 1.8초 동안 쓰러져 돌기(멈춤). 클라이언트는 Spin 속성으로 동작을 맞춘다
function M.tick(self: any, now: number): boolean
	local d = self.cdata
	if d.spinUntil and now < d.spinUntil then
		self.hum:MoveTo(self.root.Position)
		return true
	end
	local v = self.root.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	if flat.Magnitude > 4 then
		local dir = flat.Unit
		if d.lastDir and d.lastDir:Dot(dir) < math.cos(math.rad(50)) then
			d.spinUntil = now + 1.8
			d.lastDir = nil
			self.model:SetAttribute("Spin", now)
			self.hum:MoveTo(self.root.Position)
			return true
		end
		d.lastDir = dir
	end
	return false
end

return M
