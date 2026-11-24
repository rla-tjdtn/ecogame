--!strict
-- c6n 도배된 것 (6장 호텔 · 비인간형) — 사양서: roster/v5/ch6/c6n_spec.md (QA1 반영 절이 최신)
-- 벽지 아래에 납작하게 눌려 갇힌 몸. 몸의 선은 곧 벽지 세로 줄 — 줄 10개(각 7마디)가 사람 모양으로 부풀고 휘어 있다.
-- QA1: 팔 벌린 정면 구도 폐기 → 몸 전체가 거꾸로(머리가 아래) 눌림, 얼굴이 플레이어 가슴~눈 높이(4.5~5.5), 다리는 천장 쪽 ·
--      얼굴 = 종이가 입 안으로 빨려 든 구멍 + 팽팽한 콧대 + 꺼진 오른눈 + 왼눈 위 찢긴 틈(붉은 선) 속 눈동자 ·
--      찢고 나온 손가락 4개가 모두 같은 방향으로 갈고리(벽에서 나와 → 아래로 → 끝은 다시 벽 쪽), 손목에 찢긴 종이 테 한 줄.
-- 몸은 '오른쪽 벽'(루트 기준 x = +4, 깊이 = −X 쪽으로 튀어나옴)에 만들어 두고, 클라이언트가 레이캐스트로 가까운 벽을 찾아
--   Sheet 뼈를 그 벽 면으로 옮긴다(왼쪽 벽이면 Y 축 180° 뒤집기). 루트(길찾기)는 복도 가운데를 간다.
-- 뼈: Sheet(벽 면 전체·줄무늬) → Spine → Neck → Head → Eye(붉은 틈 + 눈동자),  Spine → UpperArmA → ForearmA → HandA(찢고 나온 손),
--      Spine → UpperArmB → ForearmB → HandB(종이 아래에서 미는 손),  Spine → ThighB → KneeB(무릎 밀기점)
-- 붉은 선: 왼눈 위의 찢어진 종이 틈.
-- 공포 장치 「벽에 기대지 마라」: 플레이어가 이 괴물이 붙은 벽에서 2.5 안(벽을 따라 ±5 안)에 3초 머물면 Emerge(얼굴·손이 밀려
--   나옴, 클라이언트), 6초면 Burst — 팔이 벽 밖으로 튀어나와 붙잡음(아직 2.8 안이면 잡힘). 복도 가운데(벽에서 3 이상)는 안 닿음 —
--   그래서 기본 잡기 거리는 아주 짧게(1.6). 음파를 맞으면 줄무늬가 움찔(Ripple).
--   (문틀에서 멈추기·모서리 0.6초 정지·맵 전체 벽지 줄은 빠짐 — 길찾기·맵을 건드려야 함)
local Players = game:GetService("Players")
local Rig = require(script.Parent.Rig)

local M = {}
M.cfg = {
	WanderSpeed = 4,
	InvestigateSpeed = 6,
	ChaseSpeed = 8,
	AgentRadius = 1.0,
	AgentHeight = 6,
	CatchDistance = 1.6,
}
M.spawnLift = 3
M.voice = "5" -- (소리: 전용 소리 전까지 — 낮은 숨 계열을 종이 쓸림 대신)

local HIP = 2
local FLOOR = -(HIP + 1)
local W0 = 4 -- 벽 면(루트 기준 x)
local EMERGE, BURST = 3, 6

local function P(x: number, y: number, z: number): Vector3
	return Vector3.new(x, FLOOR + y, z)
end
-- 벽 면 위의 점: 벽 따라 z, 높이 y, 복도 쪽으로 튀어나온 깊이 dep
local function W(z: number, y: number, dep: number): Vector3
	return P(W0 - dep, y, z)
end

-- 몸 높이장(벽 면 (z, y) → 깊이): 캡슐 가우시안의 최대값 + 입 구멍(음수)
local CAPS = {
	{ 0, 5.0, 0, 5.0, 0.8, 0.45 }, -- 머리(거꾸로: 아래)
	{ 0, 5.7, 0, 6.2, 0.5, 0.3 }, -- 목
	{ 0, 6.3, 0, 8.6, 1.1, 0.4 }, -- 몸통
	{ 0, 8.8, 0, 9.3, 1.0, 0.32 }, -- 골반
	{ -0.5, 9.3, -0.7, 11.6, 0.5, 0.28 }, -- 다리 A(천장 쪽으로 사라짐)
	{ 0.6, 9.3, 0.8, 10.5, 0.5, 0.3 }, -- 다리 B 허벅지
	{ 0.8, 10.5, 0.6, 11.7, 0.45, 0.3 }, -- 다리 B 무릎 위
	{ -0.9, 6.4, -2.0, 5.4, 0.4, 0.25 }, -- 팔 A
	{ -2.0, 5.4, -2.6, 4.4, 0.35, 0.28 },
	{ 0.9, 6.4, 1.9, 5.8, 0.4, 0.25 }, -- 팔 B
	{ 1.9, 5.8, 2.4, 5.0, 0.35, 0.3 },
}
local function depth(z: number, y: number): number
	local best = 0.03
	local p = Vector2.new(z, y)
	for _, c in CAPS do
		local a, b = Vector2.new(c[1], c[2]), Vector2.new(c[3], c[4])
		local ab = b - a
		local t = if ab.Magnitude > 0 then math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1) else 0
		local dist = (p - (a + ab * t)).Magnitude
		best = math.max(best, c[6] * math.exp(-(dist / c[5]) ^ 2))
	end
	local m = (p - Vector2.new(0, 5.28)).Magnitude
	return best - 0.35 * math.exp(-(m / 0.22) ^ 2) -- 입 안으로 빨려 든 종이
end

function M.build(cf: CFrame): Model
	local model, root = Rig.shell("Papered", cf, Vector3.new(1.2, 2, 1.2))
	local lines: { Rig.Line } = {}
	local balls: { Rig.Ball } = {}
	local function S(bone: string, a: Vector3, b: Vector3, red: boolean?)
		table.insert(lines, { bone = bone, a = a, b = b, r = 0.04, red = red })
	end
	local function chain(bone: string, pts: { Vector3 }, red: boolean?)
		for i = 1, #pts - 1 do
			S(bone, pts[i], pts[i + 1], red)
		end
	end
	-- 빌린 벽지 줄 10개 × 7마디: 사람 모양으로 부풂(줄 간격 1)
	for i = 0, 9 do
		local z = -4.5 + i
		local pts = {}
		for k = 0, 7 do
			local y = 3.0 + k * (8.85 / 7)
			table.insert(pts, W(z, y, depth(z, y)))
		end
		chain("Sheet", pts)
	end
	-- 얼굴(거꾸로: 이마가 아래, 턱이 위): 눈썹뼈 꺾은선 · 팽팽한 콧대 · 입 고리 · 꺼진 오른눈
	chain("Head", { W(-0.4, 4.62, 0.42), W(0, 4.7, 0.5), W(0.4, 4.62, 0.42) })
	chain("Head", { W(0, 4.82, 0.55), W(0, 5.0, 0.66), W(0, 5.12, 0.52) })
	table.insert(lines, { bone = "Head", a = W(0, 5.28, 0.22), b = W(0, 5.28, 0.28), r = 0.2, disc = true })
	chain("Head", { W(0.12, 4.82, 0.38), W(0.25, 4.72, 0.3), W(0.4, 4.82, 0.36), W(0.25, 4.88, 0.32) })
	-- 붉은 틈(왼눈 위, 닫힌 곡선 3마디) + 눈동자
	chain("Eye", { W(-0.42, 4.84, 0.44), W(-0.25, 4.7, 0.46), W(-0.08, 4.84, 0.44), W(-0.42, 4.84, 0.44) }, true)
	table.insert(balls, { bone = "Eye", c = W(-0.25, 4.8, 0.48), r = 0.07 })
	-- 팔 A: 벽 면에 눌린 위팔·아래팔(터져 나올 팔) + 찢고 나온 손(손목 테 + 갈고리 손가락 4)
	S("UpperArmA", W(-0.9, 6.4, 0.3), W(-2.0, 5.4, 0.3))
	S("ForearmA", W(-2.0, 5.4, 0.3), W(-2.6, 4.45, 0.32))
	local wr = W(-2.65, 4.35, 0.35)
	table.insert(lines, { bone = "HandA", a = wr + Vector3.new(0.03, 0, 0), b = wr - Vector3.new(0.03, 0, 0), r = 0.3, disc = true })
	for i = 0, 3 do
		local z = -2.95 + i * 0.2
		chain("HandA", { W(z, 4.25, 0.45), W(z - 0.05, 4.1, 0.95), W(z - 0.05, 3.65, 1.0), W(z, 3.45, 0.7) })
	end
	-- 손 B: 종이 아래 손가락 능선 4 / 무릎 B 능선
	for i = 0, 3 do
		local z = 2.25 + i * 0.16
		S("HandB", W(z, 4.95, 0.38), W(z + 0.05, 4.45, 0.3))
	end
	S("KneeB", W(0.55, 10.6, 0.36), W(0.95, 10.4, 0.36))
	local bones: { Rig.Bone } = {
		{ name = "Sheet", joint = P(0, 7.4, 0), tip = P(W0, 7.4, 0) },
		{ name = "Spine", parent = "Sheet", joint = W(0, 8.6, 0.1), tip = W(0, 6.3, 0.1) },
		{ name = "Neck", parent = "Spine", joint = W(0, 6.3, 0.1), tip = W(0, 5.6, 0.1) },
		{ name = "Head", parent = "Neck", joint = W(0, 5.6, 0.1), tip = W(0, 4.4, 0.1) },
		{ name = "Eye", parent = "Head", joint = W(-0.25, 4.8, 0.4), tip = W(-0.25, 4.8, 0.6) },
		{ name = "UpperArmA", parent = "Spine", joint = W(-0.9, 6.4, 0.1), tip = W(-2.0, 5.4, 0.1) },
		{ name = "ForearmA", parent = "UpperArmA", joint = W(-2.0, 5.4, 0.1), tip = W(-2.6, 4.45, 0.1) },
		{ name = "HandA", parent = "ForearmA", joint = W(-2.6, 4.45, 0.1), tip = W(-2.9, 3.6, 0.1) },
		{ name = "UpperArmB", parent = "Spine", joint = W(0.9, 6.4, 0.1), tip = W(1.9, 5.8, 0.1) },
		{ name = "ForearmB", parent = "UpperArmB", joint = W(1.9, 5.8, 0.1), tip = W(2.4, 5.0, 0.1) },
		{ name = "HandB", parent = "ForearmB", joint = W(2.4, 5.0, 0.1), tip = W(2.5, 4.4, 0.1) },
		{ name = "ThighB", parent = "Spine", joint = W(0.6, 9.3, 0.1), tip = W(0.8, 10.5, 0.1) },
		{ name = "KneeB", parent = "ThighB", joint = W(0.8, 10.5, 0.1), tip = W(0.6, 11.7, 0.1) },
	}
	Rig.build(model, root, cf, {
		id = "c6n",
		bones = bones,
		lines = lines,
		balls = balls,
		floorY = FLOOR,
		mass = 0.5,
	})
	Rig.humanoid(model, HIP, M.cfg.WanderSpeed)
	model:SetAttribute("Emerge", false)
	return model
end

-- 가까운 벽(좌우 6 안): 면 위의 점과 법선
local function findWall(self: any): (Vector3?, Vector3?)
	local cf = self.root.CFrame
	local from = cf.Position + Vector3.new(0, 1, 0)
	local best: RaycastResult? = nil
	for _, s in { -1, 1 } do
		local hit = workspace:Raycast(from, cf.RightVector * (6 * s), self.rayParams)
		if hit and (not best or hit.Distance < best.Distance) then
			best = hit
		end
	end
	if best then
		return best.Position, best.Normal
	end
	return nil, nil
end

function M.init(self: any)
	self.cdata.near = {}
	self.cdata.nextWall = 0
	self.cdata.last = os.clock()
	self.cdata.emergeOff = 0
end

function M.tick(self: any, now: number): boolean
	local d = self.cdata
	local dt = math.min(now - d.last, 0.5)
	d.last = now
	if now >= d.nextWall then
		d.nextWall = now + 0.5
		d.wallPos, d.wallN = findWall(self)
	end
	local wp: Vector3?, wn: Vector3? = d.wallPos, d.wallN
	local top, topP, topR = 0, nil :: Player?, nil :: BasePart?
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local t = 0
		if wp and wn and r and p:GetAttribute("Status") == "Alive" and not p:GetAttribute("Hidden") then
			local rel = r.Position - wp
			local along = Vector3.new(wn.Z, 0, -wn.X) -- 벽을 따라
			local lat = (r.Position - self.root.Position):Dot(along)
			if math.abs(rel:Dot(wn)) < 2.5 and math.abs(lat) < 5 and math.abs(rel.Y) < 7 then
				t = (d.near[p] or 0) + dt
			end
		end
		d.near[p] = if t > 0 then t else nil
		if t > top then
			top, topP, topR = t, p, r
		end
	end
	if top >= EMERGE then
		d.emergeOff = 0
		if self.model:GetAttribute("Emerge") ~= true then
			self.model:SetAttribute("Emerge", true)
		end
	elseif self.model:GetAttribute("Emerge") == true then
		d.emergeOff += dt
		if d.emergeOff > 1 then
			self.model:SetAttribute("Emerge", false)
		end
	end
	if top >= BURST and topP and topR and wp and wn then
		-- 팔이 벽 밖으로 2.6 튀어나와 붙잡는다
		d.near[topP] = nil
		self.model:SetAttribute("Burst", now)
		if math.abs((topR.Position - wp):Dot(wn)) < 2.8 then
			self.onCatch(topP, self)
		end
	end
	return false
end

function M.hear(self: any, pos: Vector3, _radius: number, _source: Player?, kind: string): boolean
	if kind == "Sonar" and (pos - self.root.Position).Magnitude < 40 then
		self.model:SetAttribute("Ripple", os.clock())
	end
	return false
end

return M
