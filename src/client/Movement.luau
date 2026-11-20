--!strict
-- 이동(걷기/달리기/웅크리기)과 1인칭 카메라 효과(아주 약한 헤드밥, 웅크릴 때 시점 낮춤, 추격 중 미세한 긴장감).
-- Shift = 달리기, Ctrl = 웅크리기(누르고 있는 동안). 둘을 동시에 누르면 웅크리기.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Shared.Config)

local MV = Config.Move
local SetMoveMode = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetMoveMode") :: RemoteEvent

local Movement = {}
Movement.mode = "Walk"
Movement.forced = nil :: string?
local sentMode = ""
local bobPhase = 0
local crouchDrop = 0
local tension = 0

local SPEED = { Walk = MV.Walk, Run = MV.Run, Crouch = MV.Crouch }

local function wantedMode(): string
	if Movement.forced then
		return Movement.forced
	end
	if UserInputService:GetFocusedTextBox() then
		return "Walk"
	end
	local crouch = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
	if crouch then
		return "Crouch"
	end
	local run = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	if run then
		return "Run"
	end
	return "Walk"
end

function Movement.update(dt: number)
	local player = Players.LocalPlayer
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cam = workspace.CurrentCamera
	if not hum or not root or player:GetAttribute("Status") ~= "Alive" then
		if cam and cam.FieldOfView ~= 70 then
			cam.FieldOfView = 70
		end
		return
	end
	local mode = wantedMode()
	Movement.mode = mode
	hum.WalkSpeed = SPEED[mode]
	if mode ~= sentMode then
		sentMode = mode
		SetMoveMode:FireServer(mode)
	end

	-- 시점: 웅크리기 높이 + 헤드밥
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local targetDrop = if mode == "Crouch" then MV.CrouchCameraDrop else 0
	crouchDrop += (targetDrop - crouchDrop) * math.min(1, dt * 10)
	local amp = if mode == "Run" then MV.BobRun elseif mode == "Crouch" then MV.BobCrouch else MV.BobWalk
	local moving = math.clamp(speed / math.max(1, SPEED[mode]), 0, 1)
	bobPhase += dt * (speed * 0.75 + 0.01)
	local bobY = math.sin(bobPhase * 2) * amp * moving
	local bobX = math.cos(bobPhase) * amp * 0.5 * moving
	hum.CameraOffset = Vector3.new(bobX, bobY - crouchDrop, 0)

	-- 추격 긴장감: 가까운 괴물이 추격 상태면 시야각이 아주 조금 좁아졌다 넓어졌다 한다(위치는 알려 주지 않음)
	local chased = false
	for _, m in CollectionService:GetTagged(Config.Tags.Monster) do
		if m:IsA("Model") and m:GetAttribute("State") == "Chase" and m.PrimaryPart then
			if (m.PrimaryPart.Position - root.Position).Magnitude < 40 then
				chased = true
			end
		end
	end
	tension += ((if chased then 1 else 0) - tension) * math.min(1, dt * 2)
	if cam then
		cam.FieldOfView = 70 - tension * (2 + math.sin(os.clock() * 7) * 0.6)
	end
end

function Movement.reset()
	sentMode = ""
	crouchDrop = 0
	tension = 0
end

return Movement
