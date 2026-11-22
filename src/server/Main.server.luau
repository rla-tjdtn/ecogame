--!strict
-- 서버 진입점(ServerScriptService.Server.Main)
--   · 완전한 어둠 조명 강제
--   · 음파 발사 검증(발사 간격·생존 여부, 위치는 서버가 캐릭터 머리에서 정한다) → 다른 클라이언트에 전달 + 괴물에게 소리
--   · 이동 모드(걷기/달리기/웅크리기) 요청 처리
--   · 로비(방) 또는 게임 시작(Lobby.boot)

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
	-- 간격 검증(여럿이 하거나 휴대폰이라 요청이 늦게·몰려 도착해도 정상 발사는 받아 준다):
	-- "다음 발사 허용 시각"을 쌓아 가며, 그보다 ServerTolerance 까지 일찍 온 것은 받는다. 평균으로는 Cooldown 보다 빨리 쏠 수 없다
	local now = os.clock()
	local tat = lastPulse[player] or -math.huge
	local cd = Config.Sonar.Cooldown
	if now < tat - Config.Sonar.ServerTolerance then
		return -- 간격 위반: 무시(시각 효과는 그 클라이언트에만 있고 괴물·다른 플레이어에게는 없음)
	end
	lastPulse[player] = math.max(tat, now) + cd
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

-- 로비(방 만들기) 또는 게임 서버로 시작
local Lobby = require(script.Parent.Lobby)
task.spawn(Lobby.boot)
