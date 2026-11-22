--!strict
-- 휴대폰·태블릿용 화면 버튼(터치 기기에서만 보인다. PC 조작은 그대로).
-- 이동·점프·시점은 로블록스 기본 터치 조작(왼쪽 조이스틱·점프 버튼·화면 끌기)을 그대로 쓴다.
--   음파(좌클릭)        → 크게 "음파" (관전 중이면 "다음 사람")
--   달리기(Shift)·웅크리기(Ctrl) → 눌러서 켜고 끄기(둘 중 하나만)
--   상호작용(E)        → 서랍·상자·문·숨는 곳을 볼 때만 나타난다
--   지도(Q)            → 지도 열기/닫기
--   방 메뉴(Tab)       → 로비에서만
-- 실제 동작은 Main 이 콜백(onSonar 등)으로 연결한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MobileUI = {}
MobileUI.run = false
MobileUI.crouch = false
MobileUI.onSonar = nil :: (() -> ())?
MobileUI.onInteract = nil :: (() -> ())?
MobileUI.canInteract = nil :: (() -> boolean)?
MobileUI.onMap = nil :: (() -> ())?
MobileUI.onMenu = nil :: (() -> ())?
MobileUI.spectating = nil :: (() -> boolean)?

local player = Players.LocalPlayer

-- 터치 기기인가(키보드가 없는 휴대폰·태블릿). 속성 ForceMobileUI 로 PC 에서도 켜 볼 수 있다(테스트)
local function isTouch(): boolean
	if player:GetAttribute("ForceMobileUI") then
		return true
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local gui = Instance.new("ScreenGui")
gui.Name = "MobileUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 25 -- (지도(20)·방 메뉴(10) 위: 지도를 연 채로도 닫을 수 있게. 점프스케어(50) 아래)
gui.Enabled = false

local WHITE = Color3.fromRGB(235, 235, 235)
local DIM = Color3.fromRGB(20, 20, 20)

local function button(name: string, text: string, size: number, pos: UDim2, textSize: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = pos
	b.Size = UDim2.fromOffset(size, size)
	b.BackgroundColor3 = DIM
	b.BackgroundTransparency = 0.35
	b.TextColor3 = WHITE
	b.Font = Enum.Font.GothamMedium
	b.TextSize = textSize
	b.AutoButtonColor = true
	b.Active = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Color = WHITE
	stroke.Transparency = 0.4
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	b.Parent = gui
	return b
end

-- 오른쪽 아래(로블록스 점프 버튼 위·왼쪽): 음파가 가장 크고 엄지가 닿기 쉬운 곳
local sonarBtn = button("Sonar", "음파", 104, UDim2.new(1, -185, 1, -120), 22)
local runBtn = button("Run", "달리기", 66, UDim2.new(1, -300, 1, -95), 15)
local crouchBtn = button("Crouch", "웅크리기", 66, UDim2.new(1, -290, 1, -180), 14)
local useBtn = button("Use", "E\n상호작용", 76, UDim2.new(1, -185, 1, -245), 14)
local mapBtn = button("Map", "지도", 56, UDim2.new(1, -60, 0, 110), 15)
local menuBtn = button("Menu", "방 메뉴", 70, UDim2.new(1, -70, 0, 190), 14)

local function paintToggle(b: TextButton, on: boolean)
	b.BackgroundColor3 = if on then Color3.fromRGB(230, 230, 230) else DIM
	b.TextColor3 = if on then Color3.fromRGB(10, 10, 10) else WHITE
end

sonarBtn.Activated:Connect(function()
	if MobileUI.onSonar then
		MobileUI.onSonar()
	end
end)
runBtn.Activated:Connect(function()
	MobileUI.run = not MobileUI.run
	if MobileUI.run then
		MobileUI.crouch = false
	end
	paintToggle(runBtn, MobileUI.run)
	paintToggle(crouchBtn, MobileUI.crouch)
end)
crouchBtn.Activated:Connect(function()
	MobileUI.crouch = not MobileUI.crouch
	if MobileUI.crouch then
		MobileUI.run = false
	end
	paintToggle(runBtn, MobileUI.run)
	paintToggle(crouchBtn, MobileUI.crouch)
end)
useBtn.Activated:Connect(function()
	if MobileUI.onInteract then
		MobileUI.onInteract()
	end
end)
mapBtn.Activated:Connect(function()
	if MobileUI.onMap then
		MobileUI.onMap()
	end
end)
menuBtn.Activated:Connect(function()
	if MobileUI.onMenu then
		MobileUI.onMenu()
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")

-- 상황에 맞게 보이기(0.15초마다)
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.15 then
		return
	end
	acc = 0
	local on = isTouch()
	gui.Enabled = on
	if not on then
		return
	end
	local mode = ReplicatedStorage:GetAttribute("Mode")
	local lobby = mode == "Lobby"
	local playing = mode == "Game" and ReplicatedStorage:GetAttribute("RoundState") == "Playing"
	local alive = player:GetAttribute("Status") == "Alive"
	local spect = MobileUI.spectating ~= nil and MobileUI.spectating()
	sonarBtn.Visible = lobby or playing
	sonarBtn.Text = if spect then "다음\n사람" else "음파"
	runBtn.Visible = alive and (lobby or playing)
	crouchBtn.Visible = alive and (lobby or playing)
	useBtn.Visible = alive and MobileUI.canInteract ~= nil and MobileUI.canInteract()
	mapBtn.Visible = playing
	menuBtn.Visible = lobby
	-- 죽거나 스테이지가 바뀌면 달리기·웅크리기 해제
	if not alive and (MobileUI.run or MobileUI.crouch) then
		MobileUI.run = false
		MobileUI.crouch = false
		paintToggle(runBtn, false)
		paintToggle(crouchBtn, false)
	end
end)

-- (테스트) 보이는 버튼 이름
function MobileUI.state()
	local shown = {}
	for _, c in gui:GetChildren() do
		if c:IsA("TextButton") and c.Visible then
			table.insert(shown, c.Name)
		end
	end
	table.sort(shown)
	return { enabled = gui.Enabled, buttons = shown, run = MobileUI.run, crouch = MobileUI.crouch }
end

return MobileUI
