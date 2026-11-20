--!strict
-- 클라이언트 사운드: 발소리(모든 캐릭터, 3D), 음파, 문, 괴물 발소리·반응음, 환경음.
-- 네트워크를 쓰지 않는다: 각 클라이언트가 복제된 위치·속성(MoveMode, State, Open)을 보고 스스로 재생한다.
-- 소리는 Config.Sounds 에서 교체한다. Id 가 "" 이면 재생하지 않는다.
-- 플레이어 속성 TestMute 가 켜지면(자동 테스트) 전체 음소거.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Config = require(ReplicatedStorage.Shared.Config)

local Audio = {}
local SND = Config.Sounds :: { [string]: { Id: string, Volume: number, Pitch: number, Range: number } }
local player = Players.LocalPlayer

local master = Instance.new("SoundGroup")
master.Name = "SonarMaster"
master.Volume = 1
master.Parent = SoundService

local function applyMute()
	master.Volume = if player:GetAttribute("TestMute") then 0 else 1
end
applyMute()
player:GetAttributeChangedSignal("TestMute"):Connect(applyMute)

local function makeSound(name: string, parent: Instance, looped: boolean?): Sound?
	local def = SND[name]
	if not def or def.Id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = def.Id
	s.Volume = def.Volume
	s.PlaybackSpeed = def.Pitch
	s.Looped = looped == true
	s.SoundGroup = master
	if def.Range > 0 then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 5
		s.RollOffMaxDistance = def.Range
	end
	s.Parent = parent
	return s
end

-- 한 번 재생하고 지운다. at 이 Vector3 이면 그 위치에서(3D), Instance 면 거기 붙여서, nil 이면 2D.
function Audio.play(name: string, at: (Vector3 | Instance)?, pitchJitter: number?, volumeScale: number?)
	local parent: Instance
	local holder: Attachment? = nil
	if typeof(at) == "Vector3" then
		local a = Instance.new("Attachment")
		a.WorldPosition = at :: Vector3
		a.Parent = workspace.Terrain
		holder = a
		parent = a
	elseif typeof(at) == "Instance" then
		parent = at :: Instance
	else
		parent = SoundService
	end
	local s = makeSound(name, parent)
	if not s then
		if holder then
			holder:Destroy()
		end
		return
	end
	if pitchJitter then
		s.PlaybackSpeed *= 1 + (math.random() * 2 - 1) * pitchJitter
	end
	if volumeScale then
		s.Volume *= volumeScale
	end
	s:Play()
	task.delay(6, function()
		s:Destroy()
		if holder then
			holder:Destroy()
		end
	end)
end

function Audio.sonar(localShot: boolean, origin: Vector3)
	if localShot then
		Audio.play("Sonar", nil, 0.03)
		task.delay(0.35, Audio.play, "SonarEcho", nil, 0.03)
	else
		Audio.play("Sonar", origin, 0.03)
		task.delay(0.35, Audio.play, "SonarEcho", origin, 0.03)
	end
end

-- ── 발소리(캐릭터마다 이동 거리 누적) ──
type Tracker = { last: Vector3, acc: number, root: BasePart }
local trackers: { [Model]: Tracker } = {}
local STRIDE = { Walk = 3.6, Run = 5.0, Crouch = 2.4 }

local function stepFor(model: Model, root: BasePart, isMonster: boolean)
	local tr = trackers[model]
	if not tr or tr.root ~= root then
		tr = { last = root.Position, acc = 0, root = root }
		trackers[model] = tr
	end
	local p = root.Position
	local d = Vector3.new(p.X - tr.last.X, 0, p.Z - tr.last.Z).Magnitude
	tr.last = p
	if d > 6 then
		return -- 순간 이동
	end
	tr.acc += d
	if isMonster then
		if tr.acc >= 3.4 then
			tr.acc = 0
			Audio.play("MonsterStep", root, 0.08)
		end
	else
		local mode = (model:GetAttribute("MoveMode") :: string?) or "Walk"
		local stride = STRIDE[mode] or 3.6
		if tr.acc >= stride then
			tr.acc = 0
			local name = if mode == "Run" then "FootRun" elseif mode == "Crouch" then "FootCrouch" else "FootWalk"
			Audio.play(name, root, 0.1)
		end
	end
end

-- ── 괴물 상태 반응음 ──
local monsterConns: { [Model]: { RBXScriptConnection } } = {}
local idleAt: { [Model]: number } = {}
local function watchMonster(m: Instance)
	if not m:IsA("Model") or monsterConns[m] then
		return
	end
	local model = m :: Model
	local conns = {}
	table.insert(conns, model:GetAttributeChangedSignal("State"):Connect(function()
		local st = model:GetAttribute("State")
		local root = model.PrimaryPart
		if not root then
			return
		end
		if st == "Alert" then
			Audio.play("MonsterAlert", root, 0.05)
		elseif st == "Chase" then
			Audio.play("MonsterChase", root, 0.05)
		end
	end))
	monsterConns[model] = conns
	idleAt[model] = os.clock() + 5 + math.random() * 6
	model.Destroying:Connect(function()
		for _, c in conns do
			c:Disconnect()
		end
		monsterConns[model] = nil
		idleAt[model] = nil
		trackers[model] = nil
	end)
end
CollectionService:GetInstanceAddedSignal(Config.Tags.Monster):Connect(watchMonster)
for _, m in CollectionService:GetTagged(Config.Tags.Monster) do
	watchMonster(m)
end

-- ── 문 ──
local function watchDoor(m: Instance)
	if not m:IsA("Model") then
		return
	end
	m:GetAttributeChangedSignal("Open"):Connect(function()
		local panel = m:FindFirstChild("Panel")
		if panel then
			Audio.play("Door", (panel :: BasePart).Position, 0.08)
		end
	end)
end
CollectionService:GetInstanceAddedSignal(Config.Tags.Door):Connect(watchDoor)
for _, m in CollectionService:GetTagged(Config.Tags.Door) do
	watchDoor(m)
end

-- ── 환경음 ──
local hum: Sound? = makeSound("AmbientHum", SoundService, true)
if hum then
	hum:Play()
end
local emitters: { [Instance]: Sound } = {}
local function addEmitter(e: Instance)
	if emitters[e] or not e:IsA("BasePart") then
		return
	end
	local name = (e:GetAttribute("Sound") :: string?) or "AmbientFan"
	local s = makeSound(name, e, true)
	if s then
		s.TimePosition = math.random() * 2
		s:Play()
		emitters[e] = s
	end
	e.Destroying:Connect(function()
		emitters[e] = nil
	end)
end
CollectionService:GetInstanceAddedSignal(Config.Tags.AmbientEmitter):Connect(addEmitter)
for _, e in CollectionService:GetTagged(Config.Tags.AmbientEmitter) do
	addEmitter(e)
end

local nextAmbient = os.clock() + 4
local ONE_SHOTS = { "AmbientDrip", "AmbientDrip", "AmbientMetal", "AmbientCreak" }

function Audio.update()
	-- 발소리
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if char and root and plr:GetAttribute("Status") == "Alive" then
			stepFor(char, root, false)
		end
	end
	local now = os.clock()
	for _, m in CollectionService:GetTagged(Config.Tags.Monster) do
		if m:IsA("Model") and m.PrimaryPart then
			stepFor(m, m.PrimaryPart, true)
			if m:GetAttribute("State") == "Wander" and idleAt[m] and now > idleAt[m] then
				idleAt[m] = now + 7 + math.random() * 9
				Audio.play("MonsterIdle", m.PrimaryPart, 0.1)
			end
		end
	end
	-- 먼 곳의 물방울·금속음·구조물 삐걱임(무작위 위치)
	if now > nextAmbient then
		nextAmbient = now + 4 + math.random() * 8
		local cam = workspace.CurrentCamera
		if cam then
			local ang = math.random() * math.pi * 2
			local r = 15 + math.random() * 35
			local p = cam.CFrame.Position + Vector3.new(math.cos(ang) * r, math.random() * 6 - 2, math.sin(ang) * r)
			Audio.play(ONE_SHOTS[math.random(1, #ONE_SHOTS)], p, 0.15)
		end
	end
	for model, _ in trackers do
		if not model.Parent then
			trackers[model] = nil
		end
	end
end

return Audio
