--!strict
-- 라운드(스테이지) 진행: 스테이지 짓기 → 플레이어 배치 → 괴물 → 탈출/사망 판정 → 다음 스테이지 또는 재시작.
-- 플레이어 상태(Player 속성 "Status"): "Waiting" | "Alive" | "Dead" | "Escaped"
-- ReplicatedStorage 속성: StageIndex, StageName, RoundState("Waiting"|"Lobby"|"Loading"|"Playing"|"Result"), RoundId, Mode("Lobby"|"Game")
-- 로비(RoundState "Lobby"): 로비 맵을 스테이지처럼 지어 음파로 본다. 방(Lobby.luau)에서 시작하면 그 방 사람만 참가자(Round.members).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Builder = require(script.Parent.StageBuilder)
local Doors = require(script.Parent.Doors)
local SoundBus = require(script.Parent.SoundBus)
local Monster = require(script.Parent.Monster)
local Hiding = require(script.Parent.Hiding)
local Search = require(script.Parent.Search)

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
Round.members = nil :: { [Player]: boolean }? -- nil 이면 서버의 모든 플레이어가 참가자
Round.returnToLobby = false -- 로비에서 시작한 게임: 마지막 스테이지를 깨거나 참가자가 모두 나가면 로비로
Round.lastAllClear = false

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

-- 이번 게임 참가자(로비에서 방으로 시작했으면 그 방 사람만)
function Round.participants(): { Player }
	local out = {}
	for _, p in Players:GetPlayers() do
		if not Round.members or Round.members[p] then
			table.insert(out, p)
		end
	end
	return out
end

function Round.alivePlayers(): { Player }
	local out = {}
	for _, p in Round.participants() do
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

local function buildLayout(layout: any, label: string)
	if stageFolder then
		stageFolder:Destroy()
		stageFolder = nil
	end
	Doors.clear()
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
	note("built " .. label .. " parts=" .. count)
end

function Round.buildStage(i: number)
	local layout = stageModule(i)
	assert(layout, "stage module missing: " .. tostring(i))
	buildLayout(layout, "stage " .. i)
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
	if Round.state == "Lobby" then
		-- 로비에서는 죽지 않는다(떨어지면 다시 세운다)
		task.delay(1, function()
			if Round.state == "Lobby" then
				Round.spawnPlayer(p)
			end
		end)
		return
	end
	setStatus(p, "Dead")
	note("dead " .. p.Name .. " " .. (why or ""))
	local others = #Round.alivePlayers()
	RoundEvent:FireAllClients("Died", { userId = p.UserId, solo = #Round.participants() == 1, othersAlive = others, why = why })
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
	ReplicatedStorage:SetAttribute("Mode", "Game")
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
	for _, p in Round.participants() do
		task.spawn(Round.spawnPlayer, p)
	end
	Round.state = "Playing"
	ReplicatedStorage:SetAttribute("RoundState", "Playing")
	Search.assignKey((Round.info :: Builder.StageInfo).spawns[1].Position)
	RoundEvent:FireAllClients("Start", { stage = i, name = def.Name })
	Round.spawnMonsters(def.Monsters)
	note("start " .. i)
end

-- 라운드가 끝났는가: 살아 있는 플레이어가 없다
function Round.finished(): boolean
	if Round.state ~= "Playing" then
		return false
	end
	if #Round.participants() == 0 then
		return true
	end
	for _, p in Round.participants() do
		local s = Round.status(p)
		if s == "Alive" or s == "Waiting" then
			return false
		end
	end
	return true
end

function Round.finish(): string
	local anyEscaped = false
	Round.lastAllClear = false
	for _, p in Round.participants() do
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
		RoundEvent:FireAllClients("Clear", { stage = i, nextStage = nextI, nextName = stageDef(nextI).Name, allClear = allClear, toLobby = Round.returnToLobby, seconds = Config.Round.ResultSeconds })
		Round.stageIndex = nextI
		Round.lastAllClear = allClear
	else
		outcome = "Failed"
		RoundEvent:FireAllClients("Failed", { stage = i, nextName = stageDef(i).Name, seconds = Config.Round.ResultSeconds })
	end
	Round.lastOutcome = outcome
	note("finish " .. outcome)
	return outcome
end

-- 출구·잡기 판정
RunService.Heartbeat:Connect(function(dt)
	if Round.state ~= "Playing" then
		return
	end
	for _, m in Round.monsters do
		m:checkCatch()
		m:animate(dt)
	end
	local info = Round.info
	if not info then
		return
	end
	for _, p in Round.participants() do
		if Round.status(p) == "Alive" then
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local lp = info.exitCFrame:PointToObjectSpace(root.Position)
				local s = info.exitSize / 2
				if math.abs(lp.X) <= s.X and math.abs(lp.Y) <= s.Y and math.abs(lp.Z) <= s.Z then
					if Config.Key.Required and ReplicatedStorage:GetAttribute("HasKey") ~= true then
						-- 잠긴 출구: 몇 초에 한 번 알려 준다
						local last = (p:GetAttribute("ExitLockedAt") :: number?) or 0
						if os.clock() - last > 3 then
							p:SetAttribute("ExitLockedAt", os.clock())
							RoundEvent:FireClient(p, "ExitLocked", {})
						end
					else
						Round.escape(p)
					end
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
	if Round.state == "Lobby" then
		task.defer(Round.spawnPlayer, p)
	elseif Round.state == "Playing" and not Round.members then
		-- 늦게 들어온 플레이어도 시작 지점에서 함께 한다(방에서 시작한 게임은 그 방 사람만)
		task.defer(Round.spawnPlayer, p)
	end
end)

Players.PlayerRemoving:Connect(function(p)
	if Round.members then
		Round.members[p] = nil
	end
end)

-- 로비: 로비 맵을 짓고 모두 그 안에 세운다
function Round.enterLobby()
	clearMonsters()
	Round.members = nil
	Round.returnToLobby = false
	Round.state = "Loading"
	ReplicatedStorage:SetAttribute("RoundState", "Loading")
	ReplicatedStorage:SetAttribute("Mode", "Lobby")
	for _, p in Players:GetPlayers() do
		setStatus(p, "Waiting")
		if p.Character then
			p.Character:Destroy()
			p.Character = nil
		end
	end
	buildLayout(require(script.Parent.Stages.Lobby) :: any, "lobby")
	ReplicatedStorage:SetAttribute("HasKey", false)
	ReplicatedStorage:SetAttribute("StageIndex", 0)
	ReplicatedStorage:SetAttribute("StageName", "로비")
	ReplicatedStorage:SetAttribute("RoundId", Round.roundId)
	spawnCursor = 0
	Round.state = "Lobby"
	ReplicatedStorage:SetAttribute("RoundState", "Lobby")
	for _, p in Players:GetPlayers() do
		task.spawn(Round.spawnPlayer, p)
	end
	RoundEvent:FireAllClients("Lobby", {})
	note("lobby")
end

-- 게임 진행(스테이지 → 결과 → 다음/재시작).
-- returnToLobby 면 다섯 스테이지를 모두 깨거나 참가자가 모두 나가면 로비로 돌아가며 끝난다.
function Round.loop()
	while true do
		while #Round.participants() == 0 do
			if Round.returnToLobby then
				Round.enterLobby()
				return
			end
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
		if Round.returnToLobby and (Round.lastAllClear or #Round.participants() == 0) then
			Round.enterLobby()
			return
		end
	end
end

return Round
