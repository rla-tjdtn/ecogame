--!strict
-- 서버 진입점(ServerScriptService.Server.Main)
--   · 완전한 어둠 조명 강제
--   · 음파 발사 검증(발사 간격·생존 여부, 위치는 서버가 캐릭터 머리에서 정한다) → 다른 클라이언트에 전달 + 괴물에게 소리
--   · 이동 모드(걷기/달리기/웅크리기) 요청 처리
--   · 라운드 루프 시작

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local SoundBus = require(script.Parent.SoundBus)
local Round = require(script.Parent.Round)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SonarFire = Remotes:WaitForChild("SonarFire") :: RemoteEvent
local SonarPulse = Remotes:WaitForChild("SonarPulse") :: RemoteEvent
local SetMoveMode = Remotes:WaitForChild("SetMoveMode") :: RemoteEvent

-- ── 어둠: 환경광·하늘빛·반사 없음 ──
Lighting.Brightness = 0
Lighting.Ambient = Color3.new(0, 0, 0)
Lighting.OutdoorAmbient = Color3.new(0, 0, 0)
Lighting.EnvironmentDiffuseScale = 0
Lighting.EnvironmentSpecularScale = 0
Lighting.ClockTime = 0
Lighting.GlobalShadows = false
Lighting.FogEnd = 100000
for _, d in Lighting:GetChildren() do
	if d:IsA("Atmosphere") or d:IsA("Clouds") then
		d:Destroy()
	end
end

-- ── 음파 ──
local lastPulse: { [Player]: number } = {}
local accepted: { [Player]: number } = {}
local Sonar = {}
Sonar.accepted = accepted

SonarFire.OnServerEvent:Connect(function(player: Player)
	if player:GetAttribute("Status") ~= "Alive" or player:GetAttribute("Hidden") then
		return
	end
	local char = player.Character
	local head = char and (char:FindFirstChild("Head") :: BasePart?)
	if not head then
		return
	end
	local now = os.clock()
	local last = lastPulse[player] or -math.huge
	if now - last < Config.Sonar.Cooldown - Config.Sonar.ServerTolerance then
		return -- 간격 위반: 무시(시각 효과는 그 클라이언트에만 있고 괴물·다른 플레이어에게는 없음)
	end
	lastPulse[player] = now
	accepted[player] = (accepted[player] or 0) + 1
	local origin = head.Position
	for _, other in Players:GetPlayers() do
		if other ~= player then
			SonarPulse:FireClient(other, player.UserId, origin)
		end
	end
	SoundBus.emit(origin, Config.Noise.Sonar, player, "Sonar")
end)

-- ── 이동 모드(소리·시점 표시용 속성. 실제 소음 크기는 서버가 속도로 판정) ──
local MODES = { Walk = Config.Move.Walk, Run = Config.Move.Run, Crouch = Config.Move.Crouch }
SetMoveMode.OnServerEvent:Connect(function(player: Player, mode: any)
	if type(mode) ~= "string" or not MODES[mode] then
		return
	end
	local char = player.Character
	if not char or player:GetAttribute("Status") ~= "Alive" then
		return
	end
	char:SetAttribute("MoveMode", mode)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = MODES[mode]
	end
end)

Players.PlayerRemoving:Connect(function(p)
	lastPulse[p] = nil
	accepted[p] = nil
end)

-- 테스트 하네스가 읽는 값
_G.SonarMaze = { Round = Round, Sonar = Sonar, SoundBus = SoundBus }

task.spawn(Round.loop)
