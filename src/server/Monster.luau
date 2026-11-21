--!strict
-- 괴물: 모델 생성 + AI(배회 → 소리 감지 → 수색 → 추격 → 추격 해제).
-- 보이지 않는 검은 몸. 음파가 닿으면 클라이언트가 몸의 윤곽선을 그린다(SonarDynamic).
-- 이동은 PathfindingService 경로만 따라가므로 벽을 통과하지 않는다. 막히면 경로를 다시 계산하고, 그래도 안 되면 목표를 바꾼다.

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.MapKit)
local Doors = require(script.Parent.Doors)
local SoundBus = require(script.Parent.SoundBus)
local Hiding = require(script.Parent.Hiding)

local MC = Config.Monster

local Monster = {}
Monster.__index = Monster

export type State = "Wander" | "Alert" | "Investigate" | "Search" | "Chase"

-- ── 챕터별 머리 도형: 1 삼각형 · 2 사각형 · 3 원 · 4 별 · 5 육각형 (그 이후는 처음부터 반복) ──
-- cy: 머리 중심 높이, eye = {x, y, 반지름}, mouth = {반폭, 윗입술 y, 깊이}, 좌표는 머리 중심 기준
local HeadSpec: { { cy: number, eye: { number }, mouth: { number }, verts: { { number } }?, circle: number?, star: { number }?, hex: number? } } = {
	{ cy = 4.5, eye = { 0.2, 0.0, 0.08 }, mouth = { 0.5, -0.25, 0.35 }, verts = { { -0.85, -0.75 }, { 0.85, -0.75 }, { 0, 0.75 } } },
	{ cy = 4.4, eye = { 0.28, 0.2, 0.09 }, mouth = { 0.5, -0.1, 0.4 }, verts = { { -0.8, -0.65 }, { 0.8, -0.65 }, { 0.8, 0.65 }, { -0.8, 0.65 } } },
	{ cy = 4.35, eye = { 0.22, 0.12, 0.09 }, mouth = { 0.45, -0.2, 0.4 }, circle = 0.6 },
	{ cy = 4.55, eye = { 0.16, 0.12, 0.065 }, mouth = { 0.3, -0.12, 0.25 }, star = { 1.0, 0.48 } },
	{ cy = 4.35, eye = { 0.26, 0.15, 0.09 }, mouth = { 0.5, -0.12, 0.38 }, hex = 0.72 },
}

-- ── 모델 ──
local function buildModel(cf: CFrame, stage: number): Model
	local model = Instance.new("Model")
	model.Name = "Monster"
	model:SetAttribute(Config.Tags.Dynamic, true)
	model:SetAttribute("State", "Wander")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1.2)
	root.Transparency = 1
	root.CanCollide = true
	root.CanTouch = false
	root.CFrame = cf
	root.Parent = model
	model.PrimaryPart = root

	local function limb(p: BasePart)
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = p
	end
	local function at(v: Vector3): Vector3
		return cf:PointToWorldSpace(v)
	end
	-- 몸통(앞으로 숙인 마른 몸), 머리, 긴 팔, 다리. 루트 가운데 기준 바닥은 y = -5
	local parts: { BasePart } = {}
	-- 팔·다리는 어깨·엉덩이 관절(Motor6D)에 붙여 걸을 때 흔든다(Monster.animate)
	local group: string? = nil
	local groupParts: { [string]: { BasePart } } = {}
	local function add(p: BasePart)
		table.insert(parts, p)
		if group then
			local l = groupParts[group] or {}
			groupParts[group] = l
			table.insert(l, p)
		end
	end
	-- 레퍼런스(손그림): 작은 머리 + 짧은 목 + 좁고 긴 몸통 + 바깥으로 벌어진 긴 팔(발톱 5개) + 길고 가는 다리. 바닥 y = -5, 앞 = -Z
	local function seg(a: Vector3, b: Vector3, r: number)
		-- 음파에는 한 획으로: 막대는 가운데 선 하나(Line), 얇은 원판은 원 하나(Disc)
		local shape = if (b - a).Magnitude > r * 4 then "Line" else "Disc"
		add(Kit.cylinder(model, at(a), at(b), r, { shape = shape }))
	end
	-- 손으로 그린 듯 흔들리는 선(결정적 난수라 매번 같은 모양)
	local seed = 0
	local function rnd(): number
		seed += 1
		local x = math.sin(seed * 12.9898) * 43758.5453
		return x - math.floor(x) - 0.5
	end
	local function ink(a: Vector3, b: Vector3, r: number)
		local d = b - a
		local len = d.Magnitude
		local dir = d.Unit
		local k = math.min(1, len / 2) -- 짧은 선일수록 덜 삐져나오게
		a = a - dir * (0.05 + 0.08 * (rnd() + 0.5)) * k
		b = b + dir * (0.05 + 0.08 * (rnd() + 0.5)) * k
		local n = math.max(2, math.floor(len / 1.6))
		local prev = a
		for i = 1, n do
			local p = a:Lerp(b, i / n)
			if i < n then
				p += Vector3.new(rnd() * 0.07, rnd() * 0.04, rnd() * 0.07)
			end
			seg(prev, p, r)
			prev = p
		end
	end
	local V3 = Vector3.new
	-- 몸통: 사다리꼴 네 선 + 어깨에서 가슴으로 겹치는 두 선
	ink(V3(-0.9, 2.6, -0.35), V3(-0.65, 0.5, 0), 0.03)
	ink(V3(0.9, 2.6, -0.35), V3(0.65, 0.5, 0), 0.03)
	ink(V3(-0.9, 2.6, -0.35), V3(0.9, 2.6, -0.35), 0.03)
	ink(V3(-0.65, 0.5, 0), V3(0.65, 0.5, 0), 0.03)
	ink(V3(-0.9, 2.5, -0.35), V3(-0.15, 1.5, -0.1), 0.025)
	ink(V3(0.9, 2.5, -0.35), V3(0.15, 1.5, -0.1), 0.025)
	-- 짧은 목
	ink(V3(-0.2, 3.75, -0.65), V3(-0.3, 2.6, -0.4), 0.03)
	ink(V3(0.2, 3.75, -0.65), V3(0.3, 2.6, -0.4), 0.03)
	-- 머리(챕터별 도형): 눈 = 작은 동그라미 + 점, 입 = 가로로 넓고 세로 이빨선
	local spec = HeadSpec[((stage - 1) % #HeadSpec) + 1]
	local cy, zf = spec.cy, -1.0
	local function P(x: number, y: number, z: number): Vector3
		return Vector3.new(x, cy + y, z)
	end
	local verts: { { number } } = spec.verts or {}
	if spec.star then
		for i = 0, 9 do
			local r = if i % 2 == 0 then spec.star[1] else spec.star[2]
			local ang = math.pi / 2 + i * math.pi / 5
			table.insert(verts, { r * math.cos(ang), r * math.sin(ang) })
		end
	elseif spec.hex then
		for i = 0, 5 do
			local ang = i * math.pi / 3
			table.insert(verts, { spec.hex * math.cos(ang), spec.hex * math.sin(ang) })
		end
	end
	if spec.circle then
		seg(P(0, 0, zf), P(0, 0, zf + 0.06), spec.circle)
	else
		for i, a in verts do
			local b = verts[i % #verts + 1]
			ink(P(a[1], a[2], zf), P(b[1], b[2], zf), 0.03)
		end
	end
	local ex, ey, er = spec.eye[1], spec.eye[2], spec.eye[3]
	for _, s in { -1, 1 } do
		seg(P(s * ex, ey, zf - 0.03), P(s * ex, ey, zf - 0.06), er)
		seg(P(s * ex, ey, zf - 0.06), P(s * ex, ey, zf - 0.09), 0.025)
	end
	local mw, my, mh = spec.mouth[1], spec.mouth[2], spec.mouth[3]
	local function arcY(x: number): number
		return my - mh * (1 - (x / mw) ^ 2) * 0.35 - mh * 0.65
	end
	local zm = zf - 0.04
	seg(P(-mw, my, zm), P(mw, my, zm), 0.025)
	seg(P(-mw, my, zm), P(-mw * 0.9, arcY(-mw * 0.9), zm), 0.025)
	seg(P(mw, my, zm), P(mw * 0.9, arcY(mw * 0.9), zm), 0.025)
	for i = 0, 5 do
		local x0 = -mw * 0.9 + 1.8 * mw * i / 6
		local x1 = -mw * 0.9 + 1.8 * mw * (i + 1) / 6
		seg(P(x0, arcY(x0), zm), P(x1, arcY(x1), zm), 0.025)
	end
	for i = 1, 8 do
		local x = -mw * 0.9 + 1.8 * mw * i / 9
		seg(P(x, my, zm), P(x, arcY(x), zm), 0.018)
	end
	for _, s in { -1, 1 } do
		-- 긴 팔: 한 줄, 어깨 → 팔꿈치 → 손목, V자로 벌어짐
		group = "Arm" .. s
		local sh = V3(0.9 * s, 2.55, -0.35)
		local el = V3(1.55 * s, 0.15, -0.85)
		local wr = V3(2.1 * s, -2.1, -1.0)
		ink(sh, el, 0.03)
		ink(el, wr, 0.03)
		-- 부채꼴로 퍼지는 긴 발톱 5개
		for k = -2, 2 do
			local mid = wr + V3(k * 0.16 + 0.05 * s, -0.8, -0.12)
			local tip = wr + V3(k * 0.3 + 0.12 * s, -1.55, -0.35 + 0.05 * k)
			seg(wr + V3(k * 0.07, 0, 0), mid, 0.018)
			seg(mid, tip, 0.014)
		end
		-- 길고 곧은 다리: 한 줄 + 무릎 꺾임, 작은 발
		group = "Leg" .. s
		for _, e in { 0.4 } do
			local x0, xk, xa = e * s, (e + 0.06) * s, (e + 0.08) * s
			ink(V3(x0, 0.5, 0), V3(xk, -2.3, -0.2), 0.03)
			ink(V3(xk, -2.3, -0.2), V3(xa, -4.75, 0.1), 0.03)
		end
		local xc = 0.48 * s
		ink(V3(xc, -4.75, 0.1), V3(xc, -4.97, -0.8), 0.03)
		ink(V3(xc, -4.97, 0.35), V3(xc, -4.97, -0.8), 0.03)
		ink(V3(xc, -4.75, 0.1), V3(xc, -4.97, 0.35), 0.03)
	end
	group = nil
	local JOINTS: { [string]: Vector3 } = {
		["Arm-1"] = Vector3.new(-0.9, 2.55, -0.35),
		["Arm1"] = Vector3.new(0.9, 2.55, -0.35),
		["Leg-1"] = Vector3.new(-0.4, 0.5, 0),
		["Leg1"] = Vector3.new(0.4, 0.5, 0),
	}
	local grouped: { [BasePart]: boolean } = {}
	for name, list in groupParts do
		local off = JOINTS[name]
		if off then
			local pv = Instance.new("Part")
			pv.Name = "Pivot" .. name
			pv.Size = Vector3.new(0.2, 0.2, 0.2)
			pv.Transparency = 1
			pv.CanCollide = false
			pv.CanQuery = false
			pv.CanTouch = false
			pv.Massless = true
			pv.CFrame = cf * CFrame.new(off)
			pv.Parent = model
			local motor = Instance.new("Motor6D")
			motor.Name = "Joint" .. name
			motor.Part0 = root
			motor.Part1 = pv
			motor.C0 = CFrame.new(off)
			motor.C1 = CFrame.identity
			motor.Parent = root
			for _, p in list do
				p.Anchored = false
				p.CanCollide = false
				p.CanQuery = false
				p.Massless = true
				local w = Instance.new("WeldConstraint")
				w.Part0 = pv
				w.Part1 = p
				w.Parent = p
				grouped[p] = true
			end
		end
	end
	for _, p in parts do
		p.Name = "Body"
		if not grouped[p] then
			limb(p)
		end
	end
	-- 장애물 판정과 무관하게(검은 몸은 SonarRenderable 태그로 음파에만 드러난다)
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = 4.0
	hum.WalkSpeed = MC.WanderSpeed
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.MaxHealth = math.huge
	hum.Health = math.huge
	hum.AutoJumpEnabled = false
	hum.UseJumpPower = true
	hum.JumpPower = 0
	hum.Parent = model
	for _, st in { Enum.HumanoidStateType.Jumping, Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.Swimming, Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Seated, Enum.HumanoidStateType.Dead } do
		hum:SetStateEnabled(st, false)
	end
	CollectionService:AddTag(model, Config.Tags.Monster)
	return model
end

-- ── AI ──
export type Monster = typeof(setmetatable({} :: {
	model: Model,
	root: BasePart,
	hum: Humanoid,
	state: State,
	nodes: { Vector3 },
	waypoints: { PathWaypoint },
	wp: number,
	goal: Vector3?,
	target: Player?,
	lastSeen: number,
	lastKnown: Vector3?,
	alertUntil: number,
	searchCenter: Vector3?,
	searchUntil: number,
	lastRepath: number,
	progressPos: Vector3,
	progressT: number,
	stuck: number,
	alive: boolean,
	path: Path,
	rayParams: RaycastParams,
	onCatch: (Player, Monster) -> (),
	log: { string },
	geometry: Instance,
	startAt: number,
	stateChanged: number,
	route: ((Vector3, Vector3, boolean?) -> { Vector3 }?)?,
	legGoal: Vector3?,
	pullSpot: Vector3?, -- 쫓던 플레이어가 숨는 것을 봤다: 그 숨는 곳 앞
	lastHunt: number,
	joints: { { motor: Motor6D, base: CFrame, offset: number, amp: number } },
	phase: number,
	animT: number,
}, Monster))

function Monster.new(parent: Instance, spawnPos: Vector3, nodes: { Vector3 }, geometry: Instance, onCatch: (Player, any) -> (), stage: number?): Monster
	local model = buildModel(CFrame.new(spawnPos + Vector3.new(0, 2.2, 0)), stage or 1)
	model.Parent = parent
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { geometry }
	rp.RespectCanCollide = true
	local self = setmetatable({
		model = model,
		root = root,
		hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid,
		state = "Wander" :: State,
		nodes = nodes,
		waypoints = {},
		wp = 1,
		goal = nil,
		target = nil,
		lastSeen = 0,
		lastKnown = nil,
		alertUntil = 0,
		searchCenter = nil,
		searchUntil = 0,
		lastRepath = 0,
		progressPos = root.Position,
		progressT = os.clock(),
		stuck = 0,
		alive = true,
		path = PathfindingService:CreatePath({
			AgentRadius = MC.AgentRadius,
			AgentHeight = MC.AgentHeight,
			AgentCanJump = false,
			AgentCanClimb = false,
			WaypointSpacing = 4,
		}),
		rayParams = rp,
		onCatch = onCatch,
		log = {},
		geometry = geometry,
		startAt = os.clock() + MC.StartDelay,
		stateChanged = os.clock(),
		route = nil,
		legGoal = nil,
		pullSpot = nil,
		lastHunt = os.clock(),
		joints = {},
		phase = 0,
		animT = 0,
	}, Monster)
	for _, name in { "Leg-1", "Leg1", "Arm-1", "Arm1" } do
		local motor = root:FindFirstChild("Joint" .. name) :: Motor6D?
		if motor then
			local isLeg = name:sub(1, 3) == "Leg"
			local left = name:find("-1") ~= nil
			-- 다리끼리, 팔끼리 반대로, 팔은 같은 쪽 다리와 반대로
			table.insert(self.joints, { motor = motor, base = motor.C0, offset = if (isLeg == left) then 0 else math.pi, amp = if isLeg then 0.5 else 0.38 })
		end
	end
	return self
end

-- 걷는 모습: 속도만큼 팔다리를 흔든다(초당 10번만 바꿔 네트워크 부담을 줄인다. 음파는 순간 모습만 보여 준다)
function Monster.animate(self: Monster, dt: number)
	self.animT += dt
	if self.animT < 0.1 or #self.joints == 0 then
		return
	end
	local step = self.animT
	self.animT = 0
	local v = self.root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	self.phase = (self.phase + step * speed * 0.55) % (math.pi * 2)
	local amt = math.clamp(speed / 3, 0, 1) -- (느리게 걸어도 팔다리가 크게 흔들려야 음파에 걷는 모습이 보인다)
	for _, j in self.joints do
		j.motor.C0 = j.base * CFrame.Angles(math.sin(self.phase + j.offset) * j.amp * amt, 0, 0)
	end
end

function Monster.note(self: Monster, s: string)
	table.insert(self.log, string.format("%.1f %s", os.clock(), s))
	if #self.log > 40 then
		table.remove(self.log, 1)
	end
end

function Monster.setState(self: Monster, s: State)
	if self.state ~= s then
		self:note(self.state .. "->" .. s)
		self.state = s
		self.stateChanged = os.clock()
		self.model:SetAttribute("State", s)
	end
	local speed = MC.WanderSpeed
	if s == "Investigate" or s == "Search" then
		speed = MC.InvestigateSpeed
	elseif s == "Chase" then
		speed = MC.ChaseSpeed
	elseif s == "Alert" then
		speed = 0
	end
	self.hum.WalkSpeed = speed
end

-- (테스트용) 경로 계산 횟수·시간, tick 횟수
Monster.stats = { pathCalls = 0, pathWall = 0, ticks = 0 }

local function feet(p: Vector3): Vector3
	return p - Vector3.new(0, 4.5, 0)
end

-- 경로 계산(양보 있음). 성공하면 true
function Monster.pathTo(self: Monster, rawGoal: Vector3): boolean
	self.lastRepath = os.clock()
	-- 목표를 바닥 높이로 내린다(소리 위치는 머리 높이일 수 있다)
	local goal = rawGoal
	local down = workspace:Raycast(rawGoal + Vector3.new(0, 1, 0), Vector3.new(0, -14, 0), self.rayParams)
	if down then
		goal = down.Position + Vector3.new(0, 0.5, 0)
	end
	self.legGoal = nil
	local from = feet(self.root.Position)
	local function compute(to: Vector3): boolean
		local c0 = os.clock()
		local ok = pcall(function()
			self.path:ComputeAsync(from, to)
		end)
		Monster.stats.pathCalls += 1
		Monster.stats.pathWall += os.clock() - c0
		return ok and self.alive and self.path.Status == Enum.PathStatus.Success
	end
	local function take(final: boolean): boolean
		self.waypoints = self.path:GetWaypoints()
		self.wp = math.min(2, #self.waypoints)
		self.goal = goal
		self.legGoal = if final then nil else goal
		return true
	end
	if compute(goal) then
		return take(true)
	end
	if not self.alive then
		return false
	end
	-- 멀리 돌아가는 길: 타일 경로를 따라 몇 칸 앞까지만 계산하고, 도착하면 다시 계산한다(follow)
	local route = self.route and self.route(from, goal, true)
	if route and #route > 1 then
		for _, ahead in { MC.LegTiles, math.ceil(MC.LegTiles / 2), 2 } do
			local idx = math.min(#route, ahead + 1)
			if compute(route[idx]) then
				return take(idx == #route)
			end
		end
	end
	self.waypoints = {}
	self.wp = 1
	return false
end

-- 구간 끝에 왔다: 최종 목표가 남아 있으면 다음 구간을 계산한다. 최종 목표에 도착했으면 true
function Monster.nextLeg(self: Monster): boolean
	local g = self.legGoal
	if g and (feet(self.root.Position) - g).Magnitude > 4 and self:pathTo(g) then
		return false
	end
	self.legGoal = nil
	return true
end

-- 경로를 따라 한 걸음. 끝에 도착하면 true
function Monster.follow(self: Monster): boolean
	local wps = self.waypoints
	if #wps == 0 or self.wp > #wps then
		return self:nextLeg()
	end
	local wp = wps[self.wp]
	local pos = self.root.Position
	local flat = Vector3.new(wp.Position.X - pos.X, 0, wp.Position.Z - pos.Z)
	if flat.Magnitude < 2.2 and math.abs(feet(pos).Y - wp.Position.Y) < 4 then
		self.wp += 1
		if self.wp > #wps then
			return self:nextLeg()
		end
		wp = wps[self.wp]
	end
	self.hum:MoveTo(wp.Position)
	-- 앞에 닫힌 문이 있으면 연다
	Doors.openNear(pos + self.root.CFrame.LookVector * 2, 6)
	return false
end

function Monster.randomNode(self: Monster, awayFrom: Vector3?): Vector3
	local best = self.nodes[math.random(1, #self.nodes)]
	if awayFrom then
		for _ = 1, 6 do
			local n = self.nodes[math.random(1, #self.nodes)]
			if (n - awayFrom).Magnitude > (best - awayFrom).Magnitude and (n - awayFrom).Magnitude < 90 then
				best = n
			end
		end
	end
	return best
end

-- 머리에서 대상까지 벽에 막히지 않는가
function Monster.lineOfSight(self: Monster, p: Vector3): boolean
	local from = self.root.Position + Vector3.new(0, 2.5, 0)
	local hit = workspace:Raycast(from, p - from, self.rayParams)
	return hit == nil
end

local function alivePlayers(): { { player: Player, root: BasePart, char: Model } }
	local out = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Status") == "Alive" and not p:GetAttribute("Hidden") then
			local char = p.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if char and root then
				table.insert(out, { player = p, root = root, char = char })
			end
		end
	end
	return out
end

function Monster.startChase(self: Monster, p: Player, pos: Vector3)
	if self.state ~= "Chase" then
		self:note("chase " .. p.Name)
	end
	self.target = p
	self.lastSeen = os.clock()
	self.lastKnown = pos
	self.pullSpot = nil
	self:setState("Chase")
end

-- 누가 숨었다: 쫓던 대상이고 방금까지 보고 있었다면 숨는 곳을 기억한다
function Monster.onHide(self: Monster, p: Player, front: Vector3)
	if self.state == "Chase" and self.target == p and os.clock() - self.lastSeen <= Config.Hide.SeenWindow then
		self:note("saw " .. p.Name .. " hide")
		self.pullSpot = front
		self.lastKnown = front
		self.waypoints = {}
	end
end

function Monster.investigate(self: Monster, pos: Vector3)
	self.searchCenter = pos
	if self.state == "Wander" then
		self:setState("Alert")
		self.alertUntil = os.clock() + MC.AlertTime
		self.goal = pos
		return
	end
	if self.state == "Alert" then
		self.goal = pos
		return
	end
	-- 수색 중이거나 조사 중이면 새 위치로
	self:setState("Investigate")
	if not self.goal or (self.goal - pos).Magnitude > 4 or os.clock() - self.lastRepath > 1.5 then
		self.goal = pos
		self.waypoints = {}
	end
end

-- 소리를 들었다(SoundBus)
function Monster.hear(self: Monster, pos: Vector3, radius: number, source: Player?, kind: string)
	if not self.alive or os.clock() < self.startAt then
		return
	end
	if kind == "Door" and source == nil then
		return -- 괴물이 연 문 소리(괴물끼리 서로 문 소리에 끌려다니지 않게)
	end
	if not SoundBus.canHear(pos, self.root.Position, radius) then
		return
	end
	if self.state == "Chase" then
		if source and source == self.target then
			self.lastKnown = pos
			self.lastSeen = math.max(self.lastSeen, os.clock() - MC.LoseTime * 0.5)
		end
		return
	end
	self:note("heard " .. kind .. " " .. (if source then source.Name else "-"))
	self:investigate(pos)
end

-- 감각: 가까운 플레이어를 발견
function Monster.sense(self: Monster)
	local my = self.root.Position
	local best: { player: Player, root: BasePart, char: Model }? = nil
	local bestD = math.huge
	for _, e in alivePlayers() do
		local p = e.root.Position
		local d = (p - my).Magnitude
		local crouch = e.char:GetAttribute("MoveMode") == "Crouch"
		local range = if crouch then MC.SightRangeCrouch else MC.SightRange
		if d < bestD and math.abs(p.Y - my.Y) < 9 then
			if d <= MC.SenseRange or (d <= range and self:lineOfSight(p + Vector3.new(0, 1, 0))) then
				best = e
				bestD = d
			end
		end
	end
	if best then
		if self.state ~= "Chase" or self.target == best.player then
			self:startChase(best.player, best.root.Position)
		elseif bestD < 6 then
			self:startChase(best.player, best.root.Position)
		end
	end
end

function Monster.checkStuck(self: Monster, moving: boolean)
	local now = os.clock()
	if now - self.progressT < 1.5 then
		return
	end
	local moved = (self.root.Position - self.progressPos).Magnitude
	self.progressPos = self.root.Position
	self.progressT = now
	if not moving or self.hum.WalkSpeed <= 0 then
		self.stuck = 0
		return
	end
	if moved < 1.0 then
		self.stuck += 1
		self:note("stuck " .. self.stuck)
		self.waypoints = {}
		if self.stuck >= 3 then
			-- 목표를 포기하고 다른 곳으로
			self.goal = nil
			if self.state ~= "Chase" then
				self:setState("Wander")
			end
		end
		if self.stuck >= 6 then
			-- 마지막 수단: 가장 가까운 배회 지점으로 옮긴다
			local best, bd = self.nodes[1], math.huge
			for _, n in self.nodes do
				local d = (n - self.root.Position).Magnitude
				if d < bd and d > 2 then
					best, bd = n, d
				end
			end
			self.model:PivotTo(CFrame.new(best + Vector3.new(0, 2.2, 0)))
			self.stuck = 0
		end
	else
		self.stuck = 0
	end
end

function Monster.tick(self: Monster)
	local now = os.clock()
	if now < self.startAt then
		return
	end
	self:sense()
	local st = self.state
	local moving = true
	if st == "Chase" then
		local t = self.target
		local char = t and t.Character
		local troot = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not t or t:GetAttribute("Status") ~= "Alive" or not troot then
			self.pullSpot = nil
			self.target = nil
			self.searchCenter = self.lastKnown or self.root.Position
			self.searchUntil = now + MC.SearchTime
			self:setState("Search")
			self.waypoints = {}
			return
		end
		local tp = troot.Position
		local d = (tp - self.root.Position).Magnitude
		local hidden = t:GetAttribute("Hidden") == true
		if hidden and self.pullSpot then
			-- 숨는 걸 봤다: 그 앞으로 가서 끌어낸다
			local front = self.pullSpot
			local flat = Vector3.new(front.X - self.root.Position.X, 0, front.Z - self.root.Position.Z).Magnitude
			if flat < 4.5 then
				self:note("pulled out " .. t.Name)
				self.pullSpot = nil
				Hiding.exit(t)
				self.onCatch(t, self)
				self.target = nil
				self.searchCenter = front
				self.searchUntil = now + MC.SearchTime
				self:setState("Search")
				self.waypoints = {}
				return
			end
			if #self.waypoints == 0 or self:follow() then
				if not self:pathTo(front) then
					self.hum:MoveTo(front)
				end
			end
			self:checkStuck(true)
			return
		end
		if not hidden then
			self.pullSpot = nil
		end
		local los = not hidden and d < 40 and self:lineOfSight(tp)
		if los then
			self.lastSeen = now
			self.lastKnown = tp
		end
		if now - self.lastSeen > MC.LoseTime then
			-- 놓쳤다: 마지막 위치로 가서 수색
			self:note("lost target")
			self.target = nil
			self:setState("Investigate")
			self.goal = self.lastKnown
			self.searchCenter = self.lastKnown
			self.waypoints = {}
			return
		end
		if los and d < 14 and math.abs(tp.Y - self.root.Position.Y) < 3 then
			self.waypoints = {}
			self.hum:MoveTo(tp)
			Doors.openNear(self.root.Position + self.root.CFrame.LookVector * 2, 6)
		else
			if #self.waypoints == 0 or now - self.lastRepath > MC.RepathChase then
				local goal = self.lastKnown or tp
				if not self:pathTo(goal) then
					self.lastRepath = now
				end
			end
			self:follow()
		end
	elseif st == "Alert" then
		moving = false
		if self.goal then
			local look = Vector3.new(self.goal.X, self.root.Position.Y, self.goal.Z)
			if (look - self.root.Position).Magnitude > 0.5 then
				self.hum:MoveTo(self.root.Position + (look - self.root.Position).Unit * 0.5)
			end
		end
		if now >= self.alertUntil then
			self:setState("Investigate")
			self.waypoints = {}
		end
	elseif st == "Investigate" then
		local goal = self.goal or self.searchCenter
		if not goal then
			self:setState("Wander")
			return
		end
		if #self.waypoints == 0 then
			if not self:pathTo(goal) then
				-- 그 자리로 갈 수 없다: 근처 배회 지점을 대신 조사
				local best, bd = nil, math.huge
				for _, n in self.nodes do
					local dd = (n - goal).Magnitude
					if dd < bd then
						best, bd = n, dd
					end
				end
				if best and (best - goal).Magnitude > 0.5 and bd < 20 then
					self.goal = best
					if not self:pathTo(best) then
						self:setState("Wander")
						return
					end
				else
					self:setState("Wander")
					return
				end
			end
		end
		local arrived = self:follow()
		if arrived or (self.root.Position - goal).Magnitude < 4 then
			self.searchCenter = goal
			self.searchUntil = now + MC.SearchTime
			self:setState("Search")
			self.waypoints = {}
		end
	elseif st == "Search" then
		if now > self.searchUntil then
			self:setState("Wander")
			self.waypoints = {}
			return
		end
		if #self.waypoints == 0 or self:follow() then
			local c = self.searchCenter or self.root.Position
			local ok = false
			for _ = 1, 4 do
				local ang = math.random() * math.pi * 2
				local r = MC.SearchRadius * (0.4 + math.random() * 0.6)
				local p = c + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
				if self:pathTo(p) then
					ok = true
					break
				end
			end
			if not ok then
				self:setState("Wander")
			end
		end
	else -- Wander
		if #self.waypoints == 0 or self:follow() then
			local n = self:randomNode(self.root.Position)
			-- 넓은 맵에서 영영 마주치지 않는 일이 없게: 가끔 플레이어(숨지 않은) 근처로 배회한다
			if now - self.lastHunt >= MC.HuntEvery then
				self.lastHunt = now
				local ps = alivePlayers()
				if #ps > 0 then
					local pick = ps[math.random(1, #ps)]
					local tp = pick.root.Position
					local near = {}
					for _, c in self.nodes do
						local dd = (c - tp).Magnitude
						if dd > 12 and dd <= MC.HuntRadius then
							table.insert(near, c)
						end
					end
					local best = if #near > 0 then near[math.random(1, #near)] else nil
					if best then
						self:note("hunt near " .. pick.player.Name)
						n = best
					end
				end
			end
			if not self:pathTo(n) then
				self.waypoints = {}
			end
		end
	end
	self:checkStuck(moving)
end

-- 잡기 판정(매 프레임)
function Monster.checkCatch(self: Monster)
	if not self.alive or os.clock() < self.startAt then
		return
	end
	local my = self.root.Position
	for _, e in alivePlayers() do
		local p = e.root.Position
		local flat = Vector3.new(p.X - my.X, 0, p.Z - my.Z).Magnitude
		if flat <= MC.CatchDistance and math.abs(p.Y - (my.Y - 1.5)) < 5 then
			self:note("caught " .. e.player.Name)
			self.onCatch(e.player, self)
			-- 잡은 뒤에는 그 자리를 잠깐 뒤진다
			self.target = nil
			self.searchCenter = p
			self.searchUntil = os.clock() + MC.SearchTime
			self:setState("Search")
			self.waypoints = {}
		end
	end
end

function Monster.run(self: Monster)
	task.spawn(function()
		while self.alive and self.model.Parent do
			local ok, err = pcall(self.tick, self)
			Monster.stats.ticks += 1
			if not ok then
				warn("[Monster] " .. tostring(err))
				self.waypoints = {}
			end
			task.wait(0.1)
		end
	end)
end

function Monster.destroy(self: Monster)
	self.alive = false
	self.model:Destroy()
end

return Monster
