--!strict
-- 라운드(스테이지) 진행: 스테이지 짓기 → 플레이어 배치 → 괴물 → 탈출/사망 판정 → 다음 스테이지 또는 재시작.
-- 플레이어 상태(Player 속성 "Status"): "Waiting" | "Alive" | "Dead" | "Escaped"
-- ReplicatedStorage 속성: StageIndex, StageName, RoundState("Waiting"|"Playing"|"Result"), RoundId

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Builder = require(script.Parent.StageBuilder)
local Doors = require(script.Parent.Doors)
local SoundBus = require(script.Parent.SoundBus)
local Monster = require(script.Parent.Monster)
local Hiding = require(script.Parent.Hiding)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RoundEvent = Remotes:WaitForChild("RoundEvent") :: RemoteEvent

local Round = {}
Round.stageIndex = 1
Round.state = "Waiting"
Round.roundId = 0
Round.lastBuildMs = 0
Round.info = nil :: Builder.StageInfo?
Round.monsters = {} :: { any }
Round.autoLoop = true -- 테스트가 끌 수 있다
Round.lastOutcome = "" :: string
Round.events = {} :: { string }

local stageFolder: Folder? = nil
local spawnCursor = 0
local monsterFolder: Folder = Instance.new("Folder")
monsterFolder.Name = "Monsters"
monsterFolder.Parent = workspace

local function note(s: string)
	table.insert(Round.events, string.format("%.1f %s", os.clock(), s))
	if #Round.events > 80 then
		table.remove(Round.events, 1)
	end
end

local function setStatus(p: Player, s: string)
	p:SetAttribute("Status", s)
end

function Round.status(p: Player): string
	return (p:GetAttribute("Status") :: string?) or "Waiting"
end

function Round.alivePlayers(): { Player }
	local out = {}
	for _, p in Players:GetPlayers() do
		if Round.status(p) == "Alive" then
			table.insert(out, p)
		end
	end
	return out
end

local function stageDef(i: number)
	return Config.Stages[i]
end

local function stageModule(i: number): any?
	local def = stageDef(i)
	if not def then
		return nil
	end
	local m = script.Parent.Stages:FindFirstChild(def.Module)
	if not m then
		return nil
	end
	return require(m :: ModuleScript)
end

function Round.buildStage(i: number)
	if stageFolder then
		stageFolder:Destroy()
		stageFolder = nil
	end
	Doors.clear()
	local layout = stageModule(i)
	assert(layout, "stage module missing: " .. tostring(i))
	local b0 = os.clock()
	local info = Builder.build(layout, workspace, "Stage")
	Round.lastBuildMs = (os.clock() - b0) * 1000
	local folder = info.folder
	folder:SetAttribute("Rows", table.concat(layout.Rows, "/")) -- 클라이언트 지도(Q)용 격자(행을 / 로 구분)
	local count = 0
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	Round.roundId += 1
	folder:SetAttribute("PartCount", count)
	folder:SetAttribute("BuildId", Round.roundId)
	folder:SetAttribute("BoundsMin", info.bounds.min)
	folder:SetAttribute("BoundsMax", info.bounds.max)
	folder.Parent = workspace
	stageFolder = folder
	Round.info = info
	SoundBus.setGeometry(folder)
	note("built stage " .. i .. " parts=" .. count)
end

local function nextSpawn(): CFrame
	local info = Round.info :: Builder.StageInfo
	spawnCursor += 1
	return info.spawns[((spawnCursor - 1) % #info.spawns) + 1]
end

function Round.spawnPlayer(p: Player)
	if not Round.info then
		return
	end
	setStatus(p, "Alive")
	p:LoadCharacter()
	local char = p.Character
	if not char or Round.status(p) ~= "Alive" then
		return
	end
	local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
	local root = char:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not hum or not root then
		return
	end
	hum.WalkSpeed = Config.Move.Walk
	hum.UseJumpPower = true
	hum.JumpPower = 0
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	char:SetAttribute("MoveMode", "Walk")
	char:PivotTo(nextSpawn())
	-- 다른 원인으로 죽어도(맵 밖 등) 사망 처리
	hum.Died:Connect(function()
		if Round.status(p) == "Alive" and p.Character == char then
			Round.kill(p, "fell")
		end
	end)
end

function Round.kill(p: Player, why: string?)
	if Round.status(p) ~= "Alive" then
		return
	end
	setStatus(p, "Dead")
	note("dead " .. p.Name .. " " .. (why or ""))
	local others = #Round.alivePlayers()
	RoundEvent:FireAllClients("Died", { userId = p.UserId, solo = #Players:GetPlayers() == 1, othersAlive = others })
	local char = p.Character
	if char then
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.Anchored = true
		end
		task.delay(Config.Round.DeadBodyLinger, function()
			if p.Character == char then
				p.Character = nil
			end
			char:Destroy()
		end)
	end
end

function Round.escape(p: Player)
	if Round.status(p) ~= "Alive" then
		return
	end
	setStatus(p, "Escaped")
	note("escaped " .. p.Name)
	RoundEvent:FireAllClients("Escaped", { userId = p.UserId, othersAlive = #Round.alivePlayers() })
	local char = p.Character
	if char then
		p.Character = nil
		char:Destroy()
	end
end

local function clearMonsters()
	for _, m in Round.monsters do
		m:destroy()
	end
	table.clear(Round.monsters)
	monsterFolder:ClearAllChildren()
end

function Round.spawnMonsters(count: number)
	local info = Round.info :: Builder.StageInfo
	local spawnPos = info.spawns[1].Position
	local candidates = {}
	for _, n in info.nodes do
		if (n - spawnPos).Magnitude >= Config.Monster.MinSpawnDistance then
			table.insert(candidates, n)
		end
	end
	if #candidates == 0 then
		candidates = info.nodes
	end
	table.sort(candidates, function(a, b)
		return (a - spawnPos).Magnitude > (b - spawnPos).Magnitude
	end)
	for k = 1, count do
		-- 멀리 있는 지점들 중 서로 떨어진 곳
		local pick = candidates[math.min(#candidates, 1 + (k - 1) * math.max(1, math.floor(#candidates / (count + 1))))]
		local m = Monster.new(monsterFolder, pick, info.nodes, info.folder, function(player)
			Round.kill(player, "monster")
		end, Round.stageIndex)
		m.route = info.route
		table.insert(Round.monsters, m)
		m:run()
	end
	note("monsters " .. count)
end

function Round.startStage(i: number)
	clearMonsters()
	Round.stageIndex = i
	Round.state = "Loading"
	ReplicatedStorage:SetAttribute("RoundState", "Loading")
	for _, p in Players:GetPlayers() do
		setStatus(p, "Waiting")
		if p.Character then
			p.Character:Destroy()
			p.Character = nil
		end
	end
	Round.buildStage(i)
	local def = stageDef(i)
	ReplicatedStorage:SetAttribute("StageIndex", i)
	ReplicatedStorage:SetAttribute("StageName", def.Name)
	ReplicatedStorage:SetAttribute("RoundId", Round.roundId)
	spawnCursor = 0
	for _, p in Players:GetPlayers() do
		task.spawn(Round.spawnPlayer, p)
	end
	Round.state = "Playing"
	ReplicatedStorage:SetAttribute("RoundState", "Playing")
	RoundEvent:FireAllClients("Start", { stage = i, name = def.Name })
	Round.spawnMonsters(def.Monsters)
	note("start " .. i)
end

-- 라운드가 끝났는가: 살아 있는 플레이어가 없다
function Round.finished(): boolean
	if Round.state ~= "Playing" then
		return false
	end
	if #Players:GetPlayers() == 0 then
		return true
	end
	for _, p in Players:GetPlayers() do
		local s = Round.status(p)
		if s == "Alive" or s == "Waiting" then
			return false
		end
	end
	return true
end

function Round.finish(): string
	local anyEscaped = false
	for _, p in Players:GetPlayers() do
		if Round.status(p) == "Escaped" then
			anyEscaped = true
		end
	end
	Round.state = "Result"
	ReplicatedStorage:SetAttribute("RoundState", "Result")
	clearMonsters()
	local i = Round.stageIndex
	local outcome
	if anyEscaped then
		local nextI = i + 1
		local allClear = nextI > #Config.Stages or stageModule(nextI) == nil
		if allClear then
			nextI = 1
		end
		outcome = "Clear"
		RoundEvent:FireAllClients("Clear", { stage = i, nextStage = nextI, nextName = stageDef(nextI).Name, allClear = allClear, seconds = Config.Round.ResultSeconds })
		Round.stageIndex = nextI
	else
		outcome = "Failed"
		RoundEvent:FireAllClients("Failed", { stage = i, nextName = stageDef(i).Name, seconds = Config.Round.ResultSeconds })
	end
	Round.lastOutcome = outcome
	note("finish " .. outcome)
	return outcome
end

-- 출구·잡기 판정
RunService.Heartbeat:Connect(function()
	if Round.state ~= "Playing" then
		return
	end
	for _, m in Round.monsters do
		m:checkCatch()
	end
	local info = Round.info
	if not info then
		return
	end
	for _, p in Players:GetPlayers() do
		if Round.status(p) == "Alive" then
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local lp = info.exitCFrame:PointToObjectSpace(root.Position)
				local s = info.exitSize / 2
				if math.abs(lp.X) <= s.X and math.abs(lp.Y) <= s.Y and math.abs(lp.Z) <= s.Z then
					Round.escape(p)
				end
			end
		end
	end
end)

-- 발소리 소음: 서버가 실제 이동 속도로 판정(클라이언트 값을 믿지 않는다)
task.spawn(function()
	local N = Config.Noise
	while true do
		task.wait(N.StepInterval)
		if Round.state == "Playing" then
			for _, p in Players:GetPlayers() do
				if Round.status(p) == "Alive" then
					local char = p.Character
					local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
					if char and root then
						local v = root.AssemblyLinearVelocity
						local speed = Vector3.new(v.X, 0, v.Z).Magnitude
						if speed > N.MovingAbove then
							local radius, kind = N.Crouch, "StepCrouch"
							if speed > N.RunSpeedAbove then
								radius, kind = N.Run, "StepRun"
							elseif speed > N.WalkSpeedAbove then
								radius, kind = N.Walk, "StepWalk"
							end
							SoundBus.emit(root.Position - Vector3.new(0, 2.5, 0), radius, p, kind)
						end
					end
				end
			end
		end
	end
end)

SoundBus.listen(function(pos, radius, source, kind)
	for _, m in Round.monsters do
		m:hear(pos, radius, source, kind)
	end
end)

-- 숨는 순간: 쫓던 괴물이 그 모습을 봤는지
Hiding.onHide(function(p, spot)
	for _, m in Round.monsters do
		m:onHide(p, spot.front)
	end
end)

Players.PlayerAdded:Connect(function(p)
	setStatus(p, "Waiting")
	if Round.state == "Playing" then
		-- 늦게 들어온 플레이어도 시작 지점에서 함께 한다
		task.defer(Round.spawnPlayer, p)
	end
end)

function Round.loop()
	while true do
		while #Players:GetPlayers() == 0 do
			task.wait(0.5)
		end
		task.wait(Config.Round.FirstStartDelay)
		Round.startStage(Round.stageIndex)
		while not Round.finished() do
			task.wait(0.2)
		end
		Round.finish()
		task.wait(Config.Round.ResultSeconds)
		while not Round.autoLoop do
			task.wait(0.2)
		end
	end
end

return Round
