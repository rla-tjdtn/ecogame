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

local MC = Config.Monster

local Monster = {}
Monster.__index = Monster

export type State = "Wander" | "Alert" | "Investigate" | "Search" | "Chase"

-- ── 모델 ──
local function buildModel(cf: CFrame): Model
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
	local function add(p: BasePart)
		table.insert(parts, p)
	end
	add(Kit.box(model, cf * CFrame.new(0, -0.6, 0), Vector3.new(1.5, 0.9, 0.9)))
	add(Kit.box(model, cf * CFrame.new(0, 1.3, -0.35) * CFrame.Angles(math.rad(-18), 0, 0), Vector3.new(1.7, 3.0, 0.95)))
	add(Kit.box(model, cf * CFrame.new(0, 2.7, -0.75) * CFrame.Angles(math.rad(-25), 0, 0), Vector3.new(2.3, 0.6, 1.0)))
	add(Kit.cylinder(model, at(Vector3.new(0, 2.9, -0.8)), at(Vector3.new(0, 3.5, -1.3)), 0.22))
	add(Kit.ball(model, at(Vector3.new(0, 3.8, -1.55)), 0.62))
	add(Kit.box(model, cf * CFrame.new(0, 3.55, -2.0) * CFrame.Angles(math.rad(20), 0, 0), Vector3.new(0.7, 0.35, 0.7)))
	for _, s in { -1, 1 } do
		local sh = Vector3.new(1.15 * s, 2.75, -0.8)
		local el = Vector3.new(1.45 * s, 0.4, -1.3)
		local wr = Vector3.new(1.35 * s, -2.1, -1.5)
		add(Kit.cylinder(model, at(sh), at(el), 0.2))
		add(Kit.cylinder(model, at(el), at(wr), 0.16))
		for k = -1, 1 do
			local tip = wr + Vector3.new(0.18 * k, -1.1, -0.15 + 0.1 * k)
			add(Kit.cylinder(model, at(wr), at(tip), 0.06))
		end
		local hip = Vector3.new(0.5 * s, -0.9, 0)
		local knee = Vector3.new(0.62 * s, -3.0, -0.45)
		local ankle = Vector3.new(0.55 * s, -4.75, 0.15)
		add(Kit.cylinder(model, at(hip), at(knee), 0.25))
		add(Kit.cylinder(model, at(knee), at(ankle), 0.19))
		add(Kit.box(model, cf * CFrame.new(0.55 * s, -4.88, -0.25), Vector3.new(0.5, 0.25, 1.1)))
	end
	for _, p in parts do
		p.Name = "Body"
		limb(p)
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
}, Monster))

function Monster.new(parent: Instance, spawnPos: Vector3, nodes: { Vector3 }, geometry: Instance, onCatch: (Player, any) -> ()): Monster
	local model = buildModel(CFrame.new(spawnPos + Vector3.new(0, 2.2, 0)))
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
	}, Monster)
	return self
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
	local ok = pcall(function()
		self.path:ComputeAsync(feet(self.root.Position), goal)
	end)
	if not self.alive then
		return false
	end
	if ok and self.path.Status == Enum.PathStatus.Success then
		self.waypoints = self.path:GetWaypoints()
		self.wp = math.min(2, #self.waypoints)
		self.goal = goal
		return true
	end
	self.waypoints = {}
	self.wp = 1
	return false
end

-- 경로를 따라 한 걸음. 끝에 도착하면 true
function Monster.follow(self: Monster): boolean
	local wps = self.waypoints
	if #wps == 0 or self.wp > #wps then
		return true
	end
	local wp = wps[self.wp]
	local pos = self.root.Position
	local flat = Vector3.new(wp.Position.X - pos.X, 0, wp.Position.Z - pos.Z)
	if flat.Magnitude < 2.2 and math.abs(feet(pos).Y - wp.Position.Y) < 4 then
		self.wp += 1
		if self.wp > #wps then
			return true
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
		if p:GetAttribute("Status") == "Alive" then
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
	self:setState("Chase")
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
			self.target = nil
			self.searchCenter = self.lastKnown or self.root.Position
			self.searchUntil = now + MC.SearchTime
			self:setState("Search")
			self.waypoints = {}
			return
		end
		local tp = troot.Position
		local d = (tp - self.root.Position).Magnitude
		local los = d < 40 and self:lineOfSight(tp)
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
