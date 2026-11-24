--!strict
-- c6n 도배된 것 (6장 호텔 · 비인간형) — 사양서: art/creatures/sheets/ch6/c6n_spec.md (QA1 반영 절이 최신)
-- 벽지 아래에 납작하게 눌린 앙상한 몸이 머리를 아래로 벽을 기어 내려온다(3차 디자인: c6n_r3.js 의 점을 그대로 옮김, 깊이 ×0.4).
-- 종이는 뼈가 솟은 곳(어깨·팔꿈치·갈비·골반·무릎)에서만 능선이 되고, 벽지 줄 10개는 몸에 닿는 구간에서 끊긴다.
-- 얼굴 = 종이가 입 안으로 빨려 든 구멍 + 콧대 + 꺼진 오른눈 + 왼눈 위 찢긴 틈(붉은 선) 속 눈동자, 손가락은 마디 3 갈고리 4개.
-- 몸은 '오른쪽 벽'(루트 기준 x = +4, 깊이 = −X 쪽으로 튀어나옴)에 만들어 두고, 클라이언트가 레이캐스트로 가까운 벽을 찾아
--   Sheet 뼈를 그 벽 면으로 옮긴다(왼쪽 벽이면 Y 축 180° 뒤집기). 루트(길찾기)는 복도 가운데를 간다.
-- 뼈: Sheet(벽 면 전체·줄무늬) → Spine → Neck → Head → Eye(붉은 틈 + 눈동자), Spine → UpperArmA/B → ForearmA/B → HandA/B(A = 찢고 나온 손),
--      Spine → ThighA/B → KneeA/B(무릎 밀기점)
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
	-- 빌린 벽지 줄 10(간격 1): 몸에 닿는 구간은 끊긴다 — 줄이 빈 자리가 곧 몸
	S("Sheet", W(-4.5, 3, 0.02), W(-4.5, 12, 0.02))
	S("Sheet", W(-3.5, 3, 0.02), W(-3.5, 12, 0.02))
	S("Sheet", W(-2.5, 3, 0.02), W(-2.56, 5.13, 0.02))
	S("Sheet", W(-2.5, 8.88, 0.02), W(-2.5, 12, 0.02))
	S("Sheet", W(-1.51, 3, 0.02), W(-1.58, 6.75, 0.02))
	S("Sheet", W(-1.45, 8.25, 0.02), W(-1.58, 9.5, 0.02))
	S("Sheet", W(-0.57, 10.25, 0.02), W(-0.47, 12, 0.02))
	S("Sheet", W(0.4, 10.88, 0.02), W(0.39, 12, 0.02))
	S("Sheet", W(1.51, 3, 0.02), W(1.52, 6.5, 0.02))
	S("Sheet", W(1.48, 7.75, 0.02), W(1.61, 10.25, 0.02))
	S("Sheet", W(2.5, 3, 0.02), W(2.51, 4.13, 0.02))
	S("Sheet", W(2.49, 7.88, 0.02), W(2.5, 12, 0.02))
	S("Sheet", W(3.5, 3, 0.02), W(3.5, 12, 0.02))
	S("Sheet", W(4.5, 3, 0.02), W(4.5, 12, 0.02))
	-- 머리(거꾸로, 턱이 좁은 해골형): 두개 · 입 · 눈썹뼈 · 콧대 · 꺼진 눈
	chain("Head", { W(0.03, 6.2, 0.28), W(-0.49, 5.46, 0.4), W(-0.9, 5.14, 0.48), W(-0.95, 4.03, 0.34), W(-0.57, 3.63, 0.3), W(-0.03, 3.63, 0.32), W(0.4, 4, 0.4), W(0.68, 4.76, 0.48), W(0.32, 6.13, 0.28) })
	chain("Head", { W(-0.09, 5.86, 0.38), W(-0.25, 5.63, 0.36), W(-0.22, 5.4, 0.4), W(0.21, 5.3, 0.4), W(0.33, 5.49, 0.36), W(0.3, 5.79, 0.38), W(0.13, 5.93, 0.4), W(-0.09, 5.86, 0.38) })
	chain("Head", { W(-0.83, 4.55, 0.48), W(-0.21, 4.45, 0.55), W(0.35, 4.24, 0.48) })
	chain("Head", { W(-0.19, 4.45, 0.54), W(-0.1, 5.12, 0.58) })
	chain("Head", { W(0, 4.67, 0.48), W(0.28, 4.36, 0.4), W(0.47, 4.5, 0.42), W(0.43, 4.73, 0.42), W(0, 4.67, 0.48) })
	-- 붉은 틈(왼눈 위) + 눈동자
	chain("Eye", { W(-0.79, 4.81, 0.46), W(-0.65, 4.61, 0.5), W(-0.29, 4.76, 0.52), W(-0.64, 4.9, 0.49), W(-0.79, 4.81, 0.46) }, true)
	table.insert(balls, { bone = "Eye", c = W(-0.52, 4.75, 0.54), r = 0.07 })
	-- 목 · 몸통 옆 능선 · 갈비 · 골반 V
	chain("Neck", { W(-0.3, 6.4, 0.24), W(-0.4, 5.85, 0.32) })
	chain("Neck", { W(0.3, 6.4, 0.24), W(0.06, 5.85, 0.32) })
	chain("Spine", { W(-0.5, 6.72, 0.24), W(-1.12, 6.82, 0.29), W(-0.86, 8.35, 0.24), W(-0.5, 8.85, 0.16), W(-0.92, 9.4, 0.24) })
	chain("Spine", { W(0.55, 6.7, 0.24), W(1.16, 6.76, 0.29), W(0.9, 8.4, 0.24), W(0.52, 8.85, 0.16), W(0.95, 9.42, 0.24) })
	chain("Spine", { W(-0.88, 7.47, 0.24), W(-0.08, 7.56, 0.25) })
	chain("Spine", { W(0.88, 7.47, 0.24), W(0.12, 7.56, 0.25) })
	chain("Spine", { W(-0.86, 7.99, 0.24), W(-0.08, 8.1, 0.25) })
	chain("Spine", { W(0.86, 7.99, 0.24), W(0.12, 8.1, 0.25) })
	chain("Spine", { W(-0.92, 9.4, 0.24), W(0, 9.95, 0.16), W(0.95, 9.42, 0.24) })
	-- 팔(팔꿈치가 위로 꺾임) · 다리(천장 쪽으로 사라짐)
	chain("UpperArmA", { W(-1.18, 6.8, 0.19), W(-2.45, 8.08, 0.3) })
	chain("ForearmA", { W(-2.45, 8.08, 0.3), W(-2.07, 5.48, 0.27) })
	chain("UpperArmA", { W(-0.72, 7.3, 0.19), W(-2.65, 8.42, 0.3) })
	chain("ForearmA", { W(-2.65, 8.42, 0.3), W(-2.33, 5.42, 0.27) })
	chain("UpperArmB", { W(0.92, 7.33, 0.19), W(2.87, 7.51, 0.3) })
	chain("ForearmB", { W(2.87, 7.51, 0.3), W(2.57, 4.47, 0.24) })
	chain("UpperArmB", { W(1.08, 6.67, 0.19), W(2.63, 7.19, 0.3) })
	chain("ForearmB", { W(2.63, 7.19, 0.3), W(2.33, 4.53, 0.24) })
	chain("ThighA", { W(-0.81, 9.07, 0.16), W(-1.98, 10.67, 0.26) })
	chain("KneeA", { W(-1.98, 10.67, 0.26), W(-1.38, 12.04, 0.06) })
	chain("ThighA", { W(-0.19, 9.63, 0.16), W(-1.52, 10.83, 0.26) })
	chain("KneeA", { W(-1.52, 10.83, 0.26), W(-1.02, 11.86, 0.06) })
	chain("ThighB", { W(0.13, 9.56, 0.16), W(1.01, 11.14, 0.24) })
	chain("KneeB", { W(1.01, 11.14, 0.24), W(0.76, 11.88, 0.06) })
	chain("ThighB", { W(0.91, 9.24, 0.16), W(1.49, 11.06, 0.24) })
	chain("KneeB", { W(1.49, 11.06, 0.24), W(1.14, 12.02, 0.06) })
	-- 손 A(마디 3 갈고리, 종이를 찢고 나옴) · 손 B(종이 아래 능선)
	chain("HandA", { W(-2.42, 5.03, 0.22), W(-2.49, 4.84, 0.54), W(-2.59, 4.5, 0.52), W(-2.67, 4.25, 0.32) })
	chain("HandA", { W(-2.25, 4.98, 0.22), W(-2.27, 4.74, 0.54), W(-2.29, 4.31, 0.52), W(-2.35, 4, 0.32) })
	chain("HandA", { W(-2.08, 4.98, 0.22), W(-2.04, 4.74, 0.54), W(-1.99, 4.3, 0.52), W(-2.04, 3.98, 0.32) })
	chain("HandA", { W(-1.91, 5.03, 0.22), W(-1.82, 4.85, 0.54), W(-1.69, 4.52, 0.52), W(-1.73, 4.28, 0.32) })
	chain("HandB", { W(2.45, 4.5, 0.3), W(2.15, 4.08, 0.32), W(1.87, 3.36, 0.22) })
	chain("HandB", { W(2.32, 4.03, 0.32), W(2.18, 3.13, 0.22) })
	chain("HandB", { W(2.49, 4.03, 0.32), W(2.49, 3.11, 0.22) })
	chain("HandB", { W(2.45, 4.5, 0.3), W(2.66, 4.08, 0.32), W(2.8, 3.39, 0.22) })
	local bones: { Rig.Bone } = {
		{ name = "Sheet", joint = P(0, 7.4, 0), tip = P(W0, 7.4, 0) },
		{ name = "Spine", parent = "Sheet", joint = W(0, 8.6, 0.1), tip = W(0, 6.5, 0.1) },
		{ name = "Neck", parent = "Spine", joint = W(0, 6.5, 0.1), tip = W(-0.1, 5.9, 0.1) },
		{ name = "Head", parent = "Neck", joint = W(-0.1, 5.9, 0.1), tip = W(-0.3, 3.7, 0.1) },
		{ name = "Eye", parent = "Head", joint = W(-0.45, 4.6, 0.1), tip = W(-0.45, 4.5, 0.1) },
		{ name = "UpperArmA", parent = "Spine", joint = W(-0.95, 7.05, 0.1), tip = W(-2.55, 8.25, 0.1) },
		{ name = "ForearmA", parent = "UpperArmA", joint = W(-2.55, 8.25, 0.1), tip = W(-2.2, 5.45, 0.1) },
		{ name = "HandA", parent = "ForearmA", joint = W(-2.2, 5.45, 0.1), tip = W(-2.2, 4.25, 0.1) },
		{ name = "ThighA", parent = "Spine", joint = W(-0.5, 9.35, 0.1), tip = W(-1.75, 10.75, 0.1) },
		{ name = "KneeA", parent = "ThighA", joint = W(-1.75, 10.75, 0.1), tip = W(-1.2, 11.95, 0.1) },
		{ name = "UpperArmB", parent = "Spine", joint = W(1, 7, 0.1), tip = W(2.75, 7.35, 0.1) },
		{ name = "ForearmB", parent = "UpperArmB", joint = W(2.75, 7.35, 0.1), tip = W(2.45, 4.5, 0.1) },
		{ name = "HandB", parent = "ForearmB", joint = W(2.45, 4.5, 0.1), tip = W(2.45, 3.3, 0.1) },
		{ name = "ThighB", parent = "Spine", joint = W(0.52, 9.4, 0.1), tip = W(1.25, 11.1, 0.1) },
		{ name = "KneeB", parent = "ThighB", joint = W(1.25, 11.1, 0.1), tip = W(0.95, 11.95, 0.1) },
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
