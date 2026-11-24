--!strict
-- c6n 도배된 것: 걷지 않는다 — 벽지 면(Sheet)째 가까운 벽에 붙어 미끄러진다.
-- 0.25초마다 좌우로 레이캐스트해 더 가까운 벽을 찾고, Sheet 를 그 벽 면으로 옮긴다(왼쪽 벽이면 Y 축 180° 뒤집기).
-- 이동: 머리 쪽이 먼저 솟고 뒤가 끌리며 따라오는 물결(줄무늬 면이 0.9초 주기로 부풀었다 가라앉음). 이동 거리마다 종이 쓸림(b.step 약하게).
-- 잠듦: 4초 주기로 아주 얕게 숨쉼. 서버 Emerge = 얼굴 1.5·손 1.05·무릎 0.75 밀려 나옴 + 붉은 틈 속 눈이 열림,
-- Burst = 팔이 벽 밖으로 2.6 튀어나왔다 들어감(0.25초 / 1.2초 뒤 되돌림). Ripple(음파) = 면 전체가 움찔.
local A = require(script.Parent.Parent.CreatureAnim)

local M = {}
local W0 = 4
local CYCLE = 3.6 -- 물결 한 번에 나아가는 거리(0.9초 × 4/초)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

function M.init(b: A.Body)
	local d = b.data
	d.side = 1
	d.dist = W0
	d.rayT = 0
	d.emerge = 0
	d.burst = -1
	d.lastBurst = b.model:GetAttribute("Burst")
	d.lastRipple = b.model:GetAttribute("Ripple")
	d.ripple = 0
	d.travel = 0
	d.flip = 0
end

function M.step(b: A.Body, dt: number)
	local d = b.data
	-- 가까운 벽 찾기
	d.rayT -= dt
	if d.rayT <= 0 then
		d.rayT = 0.25
		local stage = workspace:FindFirstChild("Stage")
		if stage then
			rayParams.FilterDescendantsInstances = { stage }
			local cf = b.root.CFrame
			local from = cf:PointToWorldSpace(Vector3.new(0, 1, 0))
			local bestS, bestD = nil :: number?, math.huge
			for _, s in { -1, 1 } do
				local hit = workspace:Raycast(from, cf.RightVector * (7 * s), rayParams)
				if hit and hit.Distance < bestD then
					bestS, bestD = s, hit.Distance
				end
			end
			if bestS then
				d.side = bestS
				d.dist = bestD
			end
		end
	end
	d.flip = A.approach(d.flip, if d.side > 0 then 0 else math.pi, 10, dt)
	-- 서버 신호
	local bu = b.model:GetAttribute("Burst")
	if bu ~= d.lastBurst then
		d.lastBurst = bu
		d.burst = 0
		b.step(b.root.Position, 1.4) -- (찢김)
	end
	local rp = b.model:GetAttribute("Ripple")
	if rp ~= d.lastRipple then
		d.lastRipple = rp
		d.ripple = 1
	end
	d.ripple = math.max(0, d.ripple - dt * 2)
	local emerging = b.model:GetAttribute("Emerge") == true
	d.emerge = A.approach(d.emerge, if emerging then 1 else 0, if emerging then 1.6 else 2.5, dt) -- (1.2초에 밀려 나옴)
	local burst = 0
	if d.burst >= 0 then
		d.burst += dt
		local t = d.burst
		burst = if t < 0.25 then t / 0.25 elseif t < 1.2 then 1 elseif t < 1.7 then 1 - (t - 1.2) / 0.5 else 0
		if t >= 1.7 then
			d.burst = -1
		end
	end
	-- 물결(이동) + 숨(잠듦) + 움찔(음파): 면 전체의 깊이
	local moving = math.clamp(b.speed / 3, 0, 1)
	b.phase = (b.phase + b.speed * dt / CYCLE) % 1
	d.travel += b.speed * dt
	if d.travel > 1.5 then
		d.travel -= 1.5
		b.step(b.root.Position, 0.25) -- 사각사각
	end
	local wave = math.sin(b.phase * math.pi * 2) * 0.12 * moving
	local breathe = 0.04 * math.sin(b.t * math.pi * 2 / 4)
	local depth = breathe + wave + 0.18 * d.ripple * math.sin(b.t * 30) + 0.15 * d.emerge
	-- Sheet: 루트 기준 오른쪽 벽(x = +W0)에 만든 몸을 실제 벽 면(x = side × dist)으로. 깊이는 복도 쪽(벽 법선)
	local xs = d.dist - W0 - depth
	A.pose(b, "Sheet", 0, d.flip, 0, Vector3.new(xs * d.side, 0, 0))
	-- 머리 쪽이 먼저(앞, −Z 쪽) 솟는 물결: 척추를 진행 쪽으로 살짝 끌고 감
	A.pose(b, "Spine", 0, 0, 0, Vector3.new(-0.1 * math.max(0, math.sin(b.phase * math.pi * 2 + 1)) * moving, 0, -0.25 * moving))
	-- 밀려 나옴(뼈 로컬 −X = 복도 쪽; 뒤집힌 쪽도 Sheet 를 따라 자동으로)
	local e = d.emerge
	A.pose(b, "Head", 0, 0, 0, Vector3.new(-1.05 * e, 0, 0))
	A.pose(b, "Eye", 0, 0, 0, Vector3.new(-0.15 * e, 0, 0))
	A.pose(b, "HandB", 0, 0, 0, Vector3.new(-0.7 * e, 0, 0))
	A.pose(b, "KneeB", 0, 0, 0, Vector3.new(-0.4 * e, 0, 0))
	-- 팔 A: 잠듦엔 납작, 드러나면 손가락이 종이를 찢고 나옴, Burst 땐 팔째 복도 쪽으로 2.6
	A.pose(b, "UpperArmA", 0, 0, 0, Vector3.new(-0.3 * e - 1.2 * burst, 0.4 * burst, 0))
	A.pose(b, "ForearmA", 0, 0, 0, Vector3.new(-0.2 * e - 1.0 * burst, 0.3 * burst, 0))
	A.pose(b, "HandA", 0, 0, 0.25 * math.sin(b.t * 7) * e * (1 - burst), Vector3.new(-0.2 * e - 0.4 * burst, 0, 0))
end

return M
