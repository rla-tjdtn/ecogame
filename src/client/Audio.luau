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
local SND = Config.Sounds :: { [string]: { Id: string, Volume: number, Pitch: number, Range: number, Cut: number?, Fx: { { any } }?, Steps: { { number } }?, Thump: number?, Claw: string? } }
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
	-- Fx = { { "SoundEffect 클래스", { 속성 = 값 } }, ... }: 소리 효과(왜곡·울림·떨림·에코·플랜저 등).
	-- 클래스·속성 이름이 틀려도 소리 전체가 죽지 않게 pcall 로 하나씩 적용한다.
	if def.Fx then
		for _, fx in def.Fx do
			local ok, eff = pcall(function()
				return Instance.new(fx[1] :: string)
			end)
			if ok and eff then
				for k, v in fx[2] :: { [string]: any } do
					pcall(function()
						(eff :: any)[k] = v
					end)
				end
				eff.Parent = s
			end
		end
	end
	s.Parent = parent
	return s
end

-- 한 번 재생하고 지운다. at 이 Vector3 이면 그 위치에서(3D), Instance 면 거기 붙여서, nil 이면 2D.
Audio.steps = 0 -- (테스트) 지금까지 재생한 플레이어 발소리 수

-- opts.gate = { 켜짐초, 꺼짐초 }: 그 박자로 소리를 끊어 켰다 껐다 한다(끊기는 괴성). opts.sweep = { { 정규화 시간 0~1, 피치 배율 }, ... }, opts.dur = 전체 길이(초): 소리를 반복 재생하면서 피치를 시간에 따라 바꾼다(사이렌·오르내리는 괴성)
function Audio.play(name: string, at: (Vector3 | Instance)?, pitchJitter: number?, volumeScale: number?, pitchScale: number?, startAt: number?, cutOverride: number?, opts: { sweep: { { number } }?, dur: number?, gate: { number }? }?)
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
	if pitchScale then
		s.PlaybackSpeed *= pitchScale
	end
	if volumeScale then
		s.Volume *= volumeScale
	end
	if startAt then
		s.TimePosition = startAt
	end
	local sweep = opts and opts.sweep
	local gate = opts and opts.gate
	if gate and not sweep then
		sweep = { { 0, 1 }, { 1, 1 } } -- 음 높이 일정
	end
	if sweep then
		local pts = sweep :: { { number } } -- (reassigned 변수라 클로저 안에서 nil 검사가 풀리므로 복사해 둔다)
		local base, v0, dur = s.PlaybackSpeed, s.Volume, (opts and opts.dur) or 1
		s.Looped = true
		s.Volume = 0
		task.spawn(function()
			local t0 = os.clock()
			while s.Parent do
				local x = (os.clock() - t0) / dur
				if x >= 1 then
					break
				end
				local m = pts[#pts][2]
				for i = 2, #pts do
					if x <= pts[i][1] then
						local a, b = pts[i - 1], pts[i]
						m = a[2] + (b[2] - a[2]) * (x - a[1]) / math.max(b[1] - a[1], 1e-4)
						break
					end
				end
				s.PlaybackSpeed = base * m
				-- 시작 0.05초 페이드인, 끝 0.15초 페이드아웃
				local g = 1
				if gate then
					local ph = (x * dur) % (gate[1] + gate[2])
					g = if ph < gate[1] then math.min(1, ph / 0.015, (gate[1] - ph) / 0.015) else 0
				end
				s.Volume = v0 * g * math.min(1, x * dur / 0.05, (1 - x) * dur / 0.15)
				task.wait()
			end
			if s.Parent then
				s:Stop()
			end
		end)
	end
	s:Play()
	-- Cut: 그 시간(초)만 재생하고 짧게 줄여 끈다(여러 발짝이 든 발소리 파일에서 한 발짝만)
	local cut = cutOverride or (SND[name] and SND[name].Cut)
	if cut then
		local v0 = s.Volume
		task.delay(cut, function()
			for k = 1, 4 do
				if not s.Parent then
					return
				end
				s.Volume = v0 * (1 - k / 4)
				task.wait(0.015)
			end
			s:Stop()
		end)
	end
	task.delay(6, function()
		s:Destroy()
		if holder then
			holder:Destroy()
		end
	end)
end

-- 괴성: Config.Screams[kind] 의 목소리들을 시간차로 겹쳐 길게 지른다
function Audio.scream(kind: string, at: Instance)
	local seq = (Config :: any).Screams[kind]
	if not seq then
		return
	end
	for _, layer in seq do
		task.delay(layer.t, function()
			if at.Parent then
				Audio.play(layer.s, at, 0.05, layer.v, layer.p, layer.start, nil, if layer.sweep or layer.gate then { sweep = layer.sweep, dur = layer.dur, gate = layer.gate } else nil)
			end
		end)
	end
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

-- 한 걸음: Steps 가 있으면 녹음된 여러 걸음 중 하나를(직전과 다른 것으로) 골라 재생 + Thump(낮은 툭) / Claw(괴물 발톱) 겹침
local lastStep: { [string]: number } = {}
function Audio.footstep(name: string, at: Instance, jitter: number, pitchScale: number?)
	local def = SND[name]
	if not def then
		return
	end
	local steps = def.Steps
	if steps then
		local k = math.random(1, #steps)
		if k == lastStep[name] then
			k = k % #steps + 1
		end
		lastStep[name] = k
		Audio.play(name, at, jitter, nil, pitchScale, steps[k][1], steps[k][2])
	else
		Audio.play(name, at, jitter, nil, pitchScale)
	end
	if def.Thump then
		Audio.play("FootThump", at, 0.06, def.Thump, pitchScale)
	end
	if def.Claw then
		local claw = def.Claw
		task.delay(0.07, function()
			if at.Parent then
				Audio.footstep(claw, at, 0.06)
			end
		end)
	end
end

-- ── 발소리(캐릭터마다 이동 거리 누적) ──
type Tracker = { last: Vector3, acc: number, root: BasePart, foot: number }
local trackers: { [Model]: Tracker } = {}
-- 한 발짝 거리(스터드): 걷기 10/초면 초당 약 2발, 달리기 18/초면 약 2.8발, 웅크리기 5/초면 약 1.7발
local STRIDE = { Walk = 4.8, Run = 6.5, Crouch = 3.0 }

local function stepFor(model: Model, root: BasePart, isMonster: boolean)
	local tr = trackers[model]
	if not tr or tr.root ~= root then
		tr = { last = root.Position, acc = 0, root = root, foot = 1 }
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
		if tr.acc >= 4.6 then -- 사람(4.8)과 비슷한 거리지만 괴물은 느려서 쿵… 쿵… 간격이 더 길다
			tr.acc = 0
			Audio.footstep("MonsterStep", root, 0.08)
		end
	else
		local mode = (model:GetAttribute("MoveMode") :: string?) or "Walk"
		local stride = STRIDE[mode] or 3.6
		if tr.acc >= stride then
			tr.acc = 0
			tr.foot = -tr.foot
			local name = if mode == "Run" then "FootRun" elseif mode == "Crouch" then "FootCrouch" else "FootWalk"
			-- 매 걸음 똑같은 깔끔한 한 번의 소리(피치 흔들림·왼발/오른발 차이 없음)
			Audio.footstep(name, root, 0)
			Audio.steps += 1
		end
	end
end

-- ── 괴물 상태 반응음 ──
local monsterConns: { [Model]: { RBXScriptConnection } } = {}
local screamAt: { [Model]: number } = {} -- 추격 중 다음 괴성 시각
local CHASE_SCREAM_GAP = { 3.5, 6 } -- 추격 중 괴성 사이 간격(초, 범위). 괴성 하나가 약 2.4초
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
		-- 괴성은 플레이어를 발견해 쫓기 시작할 때만(배회·조사·수색·경계에는 지르지 않는다). 발소리는 평소에도 난다
			if st == "Chase" then
				Audio.scream("Chase", root)
				screamAt[model] = os.clock() + CHASE_SCREAM_GAP[1] + math.random() * (CHASE_SCREAM_GAP[2] - CHASE_SCREAM_GAP[1])
			end
	end))
	monsterConns[model] = conns
	
	model.Destroying:Connect(function()
		for _, c in conns do
			c:Disconnect()
		end
		monsterConns[model] = nil
		screamAt[model] = nil
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
local ONE_SHOTS = { "AmbientCreak" } -- 물방울·폭발음 같은 금속음은 뺐다

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
			-- 평소에는 소리를 내지 않는다: 발소리·괴성 모두 쫓아올 때만
			if m:GetAttribute("State") == "Chase" then
				stepFor(m, m.PrimaryPart, true)
				local at = screamAt[m]
				if at and now > at then
					screamAt[m] = now + CHASE_SCREAM_GAP[1] + math.random() * (CHASE_SCREAM_GAP[2] - CHASE_SCREAM_GAP[1])
					Audio.scream("Chase", m.PrimaryPart)
				end
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
