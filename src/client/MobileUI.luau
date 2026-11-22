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

-- 터치 기기인가. 휴대폰·태블릿은 기기마다 키보드·마우스가 있다고 보고되기도 해서 넉넉하게 본다:
--   터치가 되고 (마우스가 없거나, 키보드가 없거나, 마지막 입력이 터치) 이거나, 화면을 한 번이라도 터치했으면 켠다.
--   속성 ForceMobileUI 로 PC 에서도 켜 볼 수 있다(테스트)
local sawTouch = false
UserInputService.TouchStarted:Connect(function()
	sawTouch = true
end)
UserInputService.LastInputTypeChanged:Connect(function(t)
	if t == Enum.UserInputType.Touch then
		sawTouch = true
	end
end)
local function isTouch(): boolean
	if player:GetAttribute("ForceMobileUI") or sawTouch then
		return true
	end
	if not UserInputService.TouchEnabled then
		return false
	end
	return not UserInputService.MouseEnabled or not UserInputService.KeyboardEnabled or UserInputService:GetLastInputType() == Enum.UserInputType.Touch
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

local sonarBtn = button("Sonar", "음파", 100, UDim2.new(), 22)
local runBtn = button("Run", "달리기", 64, UDim2.new(), 15)
local crouchBtn = button("Crouch", "웅크리기", 64, UDim2.new(), 14)
local useBtn = button("Use", "E\n상호작용", 70, UDim2.new(), 14)
local mapBtn = button("Map", "지도", 56, UDim2.new(), 15)
local menuBtn = button("Menu", "방 메뉴", 62, UDim2.new(), 13)

-- ── 배치: 오른손 엄지가 닿는 부채꼴(음파 가운데, 달리기·웅크리기·상호작용이 둘레), 버튼 사이 간격 약 25px ──
-- 좌표는 작은 휴대폰(짧은 변 약 390) 기준 "버튼 가운데" 위치(화면 오른쪽 아래 / 오른쪽 위 모서리에서의 거리), 지름.
-- 휴대폰에서는 로블록스 점프 버튼을 없앴으므로(이 게임에서는 점프가 거의 필요 없다) 음파를 엄지가 쉬는 오른쪽 아래에 둔다.
type Slot = { b: TextButton, x: number, y: number, d: number, text: number, top: boolean? }
local LAYOUT: { Slot } = {
	{ b = sonarBtn, x = -110, y = -95, d = 100, text = 22 }, -- 음파: 오른쪽 아래 엄지 자리, 가장 크게
	{ b = runBtn, x = -215, y = -55, d = 64, text = 15 }, -- 달리기: 음파 왼쪽 아래(엄지를 왼쪽으로)
	{ b = crouchBtn, x = -210, y = -150, d = 64, text = 14 }, -- 웅크리기: 달리기 위
	{ b = useBtn, x = -105, y = -200, d = 70, text = 14 }, -- 상호작용: 음파 바로 위
	{ b = mapBtn, x = -52, y = 118, d = 56, text = 15, top = true }, -- 지도(게임 중): 오른쪽 위, 목숨 표시 아래
	{ b = menuBtn, x = -56, y = 122, d = 62, text = 13, top = true }, -- 방 메뉴(로비): 지도와 같은 자리
}
local hookedJump: Instance? = nil -- (로블록스 점프 버튼: 다시 켜지는 순간 바로 숨긴다)
local lastVP = Vector2.zero
local function layout()
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(812, 375)
	if vp == lastVP then
		return
	end
	lastVP = vp
	local short = math.min(vp.X, vp.Y)
	-- 작은 휴대폰은 조금 작게, 태블릿은 크게
	local s = math.clamp(short / 390, 0.85, 1.3)
	local shift = 0
	for _, slot in LAYOUT do
		local d = math.floor(slot.d * s)
		slot.b.Size = UDim2.fromOffset(d, d)
		slot.b.TextSize = math.floor(slot.text * s)
		if slot.top then
			slot.b.Position = UDim2.new(1, slot.x * s, 0, slot.y * s)
		else
			slot.b.Position = UDim2.new(1, slot.x * s + shift, 1, slot.y * s)
		end
	end
end
layout()

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
	layout() -- (화면을 돌리거나 크기가 바뀌면 다시 배치)
	-- 로블록스 기본 점프 버튼 숨기기(휴대폰에서만. 로블록스가 상태에 따라 다시 켜므로 계속 확인)
	local pg = player:FindFirstChildOfClass("PlayerGui")
	local touchGui = pg and pg:FindFirstChild("TouchGui")
	local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	local jump = frame and frame:FindFirstChild("JumpButton")
	if jump and jump:IsA("GuiObject") then
		if jump.Visible then
			jump.Visible = false
		end
		if hookedJump ~= jump then
			hookedJump = jump
			local j = jump :: GuiObject
			j:GetPropertyChangedSignal("Visible"):Connect(function()
				if j.Visible and gui.Enabled then
					j.Visible = false
				end
			end)
		end
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
