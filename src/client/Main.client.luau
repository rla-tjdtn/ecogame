--!strict
-- 클라이언트 진입점(StarterPlayerScripts.Main)
--   좌클릭 → 음파(즉시 로컬 표시 + 서버에 알림), 다른 플레이어 음파 표시, 스테이지 로드 대기 → 음파 월드 빌드,
--   사망·탈출 후 관전, 결과 화면, 상호작용 안내.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Shared.Config)
-- 휴대폰·태블릿 가벼운 모드: 메모리·처리량이 작아 부하가 크면 연결이 먼저 끊긴다(오류 277).
-- 음파 선 파트 수와 한 프레임에 새로 보이는 선 수를 줄인다(보이는 범위·시간은 같고, 아주 빽빽한 곳에서 먼 선이 조금 덜 그려진다)
if UserInputService.TouchEnabled and (not UserInputService.MouseEnabled or not UserInputService.KeyboardEnabled) then
	local S = Config.Sonar :: any
	S.PoolSize = math.min(S.PoolSize, 2000)
	S.RevealPerFrame = math.min(S.RevealPerFrame, 220)
	S.MaxRemotePulses = 3
end
local World = require(script.Parent:WaitForChild("SonarWorld"))
local Lines = require(script.Parent:WaitForChild("SonarLines"))
local Pulses = require(script.Parent:WaitForChild("SonarPulses"))
local Movement = require(script.Parent:WaitForChild("Movement"))
local Audio = require(script.Parent:WaitForChild("Audio"))
local UI = require(script.Parent:WaitForChild("UI"))
local MapView = require(script.Parent:WaitForChild("MapView"))
local LobbyUI = require(script.Parent:WaitForChild("LobbyUI"))
local Mates = require(script.Parent:WaitForChild("Mates"))
local KeyHUD = require(script.Parent:WaitForChild("KeyHUD"))
local JumpScare = require(script.Parent:WaitForChild("JumpScare"))
local SearchLook = require(script.Parent:WaitForChild("SearchLook"))
local DoppelFx = require(script.Parent:WaitForChild("DoppelFx"))
-- 괴물 전신 움직임(발 고정 IK·무게중심·관성). 발이 땅에 닿는 순간 발소리
local MonsterAnim = require(script.Parent:WaitForChild("MonsterAnim"))
MonsterAnim.onStep = function(model: Model, at: Vector3, hit: number)
	Audio.monsterFoot(model, at, hit)
end
-- 챕터 괴물(괴물마다 다른 뼈대) 움직임
local CreatureAnim = require(script.Parent:WaitForChild("CreatureAnim"))
CreatureAnim.onStep = function(model: Model, at: Vector3, hit: number)
	Audio.monsterFoot(model, at, hit)
end
require(script.Parent:WaitForChild("SpriteAnim")).onStep = function(model: Model, at: Vector3, hit: number)
	Audio.monsterFoot(model, at, hit)
end
local Reveal = require(script.Parent:WaitForChild("Reveal"))
local MobileUI = require(script.Parent:WaitForChild("MobileUI"))
local Perf = require(script.Parent:WaitForChild("Perf"))
local NetStat = require(script.Parent:WaitForChild("NetStat"))
Pulses.onReach = Perf.wrap("map.onReach", MapView.onReach)
-- 음파가 시작될 때(내 것·팀원 것): 도플갱어 눈 빛 + 맞은 괴물은 10초 동안 지금 모습 그대로 보이게(굳은 잔상 선은 그리지 않는다)
-- (사람 모습 도플갱어는 팀원처럼 윤곽선으로 늘 보이므로 음파 선을 그리지 않는다)
World.skipMonster = function(m: Model): boolean
	return Reveal.has(m) or Reveal.disguised(m) or m:GetAttribute("SonarVeil") == true -- (5장 지움: 첫 음파엔 잔상도 남기지 않음)
end
Audio.stepAudible = Reveal.active -- (괴물 발소리는 음파에 걸린 동안만)
local SpriteAnim = require(script.Parent:WaitForChild("SpriteAnim"))
SpriteAnim.visible = Reveal.active -- (시안 그림 괴물은 음파에 드러난 동안만 보인다)
local RigAnim = require(script.Parent:WaitForChild("RigAnim"))
RigAnim.visible = Reveal.active
RigAnim.onStep = function(model: Model, at: Vector3, hit: number)
	Audio.monsterFoot(model, at, hit)
end
-- 점프스케어: 잡은 괴물의 자기 괴성 + (시안 그림 괴물이면) 그 괴물의 덮침 그림
local function playScare(data: any)
	local sprite = nil
	if typeof(data.creature) == "string" then
		local url, off, size = SpriteAnim.attackFrame(data.creature)
		if url and off and size then
			sprite = { url = url, offset = off, size = size }
		end
	end
	JumpScare.play(function()
		local si = (ReplicatedStorage:GetAttribute("StageIndex") :: number?) or 1
		local voice = if typeof(data.voice) == "string" then data.voice
			elseif data.why == "doppel" then "Doppel"
			elseif data.why == "flower" then "Flower"
			else tostring((math.max(1, si) - 1) % 5 + 1)
		Audio.play(Audio.voiceName(voice, "Scream") or "MonsterAlert", nil, 0.03, 0.8)
	end, data.why, sprite)
end
Pulses.onStart = Perf.wrap("pulse.onStart", function(origin: Vector3)
	local t0 = os.clock()
	DoppelFx.onPulse(origin)
	local t1 = os.clock()
	Reveal.onPulse(origin)
	Perf.add("pulse.onStart.doppel", t1 - t0)
	Perf.add("pulse.onStart.reveal", os.clock() - t1)
end)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SonarFire = Remotes:WaitForChild("SonarFire") :: RemoteEvent
local SonarPulse = Remotes:WaitForChild("SonarPulse") :: RemoteEvent
local RoundEvent = Remotes:WaitForChild("RoundEvent") :: RemoteEvent

local lastFire = -math.huge
local spectateIndex = 1
local building = false
local frameTimes: { number } = {}
local luaTimes: { number } = {}
local prof = { pulses = 0, lines = 0, frames = 0 } -- (테스트용) 프레임당 음파 연산 시간 나눠 보기

-- ── 스테이지 로드 → 음파 월드 ──
local function tryBuild()
	local stage = workspace:FindFirstChild("Stage") :: Folder?
	if not stage or building then
		return
	end
	local id = stage:GetAttribute("BuildId")
	if not id or (World.ready and World.buildId == id and World.stage == stage) then
		return
	end
	building = true
	task.spawn(function()
		-- 모든 파트가 복제될 때까지
		local want = (stage:GetAttribute("PartCount") :: number?) or 0
		local t0 = os.clock()
		while os.clock() - t0 < 20 do
			local n = 0
			for _, d in stage:GetDescendants() do
				if d:IsA("BasePart") then
					n += 1
				end
			end
			if n >= want then
				break
			end
			task.wait(0.2)
		end
		Pulses.clear()
		Lines.clear()
		DoppelFx.clear()
		Reveal.clear()
		World.build(stage)
		MapView.load(stage)
		task.spawn(Lines.prewarm, 2500) -- 선 파트 미리 만들기(음파 도중 끊김 방지)
		building = false
		if stage:GetAttribute("BuildId") ~= World.buildId then
			tryBuild()
		end
	end)
end
workspace.ChildAdded:Connect(function(c)
	if c.Name == "Stage" then
		c:GetAttributeChangedSignal("BuildId"):Connect(tryBuild)
		task.defer(tryBuild)
	end
end)
local existing = workspace:FindFirstChild("Stage")
if existing then
	existing:GetAttributeChangedSignal("BuildId"):Connect(tryBuild)
	tryBuild()
end

-- ── 음파 발사 ──
local function alive(): boolean
	return player:GetAttribute("Status") == "Alive"
end

local function fire(): boolean
	if not alive() or not World.ready or player:GetAttribute("Hidden") then
		return false
	end
	local now = os.clock()
	if now - lastFire < Config.Sonar.Cooldown then
		return false
	end
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if not head then
		return false
	end
	lastFire = now
	Pulses.start(head.Position, char, true)
	SonarFire:FireServer()
	NetStat.count("send.SonarFire")
	Audio.sonar(true, head.Position)
	return true
end

local function charOf(userId: number): Model?
	local p = Players:GetPlayerByUserId(userId)
	return p and p.Character
end

SonarPulse.OnClientEvent:Connect(function(userId: number, origin: Vector3, fromModel: Model?)
	Perf.count("net.SonarPulse")
	NetStat.count("recv.SonarPulse")
	if typeof(origin) ~= "Vector3" then
		return
	end
	if userId == 0 then
		-- 도플갱어의 가짜 음파: 팀원 음파와 똑같이 보이고 들린다(그 몸은 파동에서 뺀다)
		local cam = workspace.CurrentCamera
		if cam and (cam.CFrame.Position - origin).Magnitude > Config.Sonar.RemoteViewDistance then
			return
		end
		Pulses.start(origin, if typeof(fromModel) == "Instance" then fromModel else nil, false)
		Audio.sonar(false, origin)
		return
	end
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - origin).Magnitude > Config.Sonar.RemoteViewDistance then
		return
	end
	Pulses.start(origin, charOf(userId), false)
	Audio.sonar(false, origin)
end)

-- ── 관전 ──
local function spectateTargets(): { Player }
	local out = {}
	for _, p in Players:GetPlayers() do
		if p ~= player and p:GetAttribute("Status") == "Alive" and p.Character and p.Character:FindFirstChild("Head") then
			table.insert(out, p)
		end
	end
	return out
end

local function spectating(): boolean
	local st = player:GetAttribute("Status")
	return (st == "Dead" or st == "Escaped") and ReplicatedStorage:GetAttribute("RoundState") == "Playing"
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if spectating() then
			spectateIndex += 1
		else
			fire()
		end
	end
end)

-- ── 상호작용 안내(문, 숨는 곳) ──
local function promptText(prompt: ProximityPrompt): string
	if prompt:GetAttribute("HideSpot") and player:GetAttribute("Hidden") then
		return "E   나가기"
	end
	return "E   " .. prompt.ActionText
end
-- 지금 안내 중인 것: 다른 안내가 사라지는 신호가 늦게 와도(문 → 사물함으로 바로 옮길 때) 지금 것을 지우지 않는다
local shownPrompt: ProximityPrompt? = nil
ProximityPromptService.PromptShown:Connect(function(prompt)
	if prompt.Style == Enum.ProximityPromptStyle.Custom then
		shownPrompt = prompt
		UI.setPrompt(promptText(prompt))
		local function refresh()
			if shownPrompt == prompt then
				UI.setPrompt(promptText(prompt))
			end
		end
		local conn = prompt:GetPropertyChangedSignal("ActionText"):Connect(refresh)
		local conn2 = player:GetAttributeChangedSignal("Hidden"):Connect(refresh)
		local conn3: RBXScriptConnection? = nil
		local hiddenConn: RBXScriptConnection? = nil
		local function gone()
			conn:Disconnect()
			conn2:Disconnect()
			if conn3 then
				conn3:Disconnect()
			end
			if hiddenConn then
				hiddenConn:Disconnect()
			end
			if shownPrompt == prompt then
				shownPrompt = nil
				UI.setPrompt(nil)
			end
		end
		hiddenConn = prompt.PromptHidden:Once(gone)
		-- (안내가 떠 있는 채로 스테이지가 지워지면 PromptHidden 이 오지 않는다: 연결이 남지 않게)
		conn3 = prompt.AncestryChanged:Connect(function()
			if not prompt:IsDescendantOf(workspace) then
				gone()
			end
		end)
	end
end)

-- ── 휴대폰 화면 버튼(MobileUI) 연결: 키보드·마우스와 같은 동작 ──
MobileUI.spectating = spectating
MobileUI.onSonar = function()
	if spectating() then
		spectateIndex += 1
	else
		fire()
	end
end
MobileUI.canInteract = function(): boolean
	return SearchLook.target() ~= nil or shownPrompt ~= nil
end
MobileUI.onInteract = function()
	-- 조준한 서랍·뚜껑이 먼저(E 와 같다), 아니면 지금 안내 중인 문·숨는 곳
	if SearchLook.target() then
		SearchLook.use()
		return
	end
	local pr = shownPrompt
	if pr then
		pr:InputHoldBegin()
		task.delay(0.1, function()
			pr:InputHoldEnd()
		end)
	end
end
MobileUI.onMap = function()
	MapView.toggle()
end
MobileUI.onHint = KeyHUD.requestHint
MobileUI.hintAvailable = KeyHUD.hintAvailable
MobileUI.onMenu = function()
	LobbyUI.setMenu(not LobbyUI.state().menuOpen)
end

-- ── 라운드 이벤트 ──
local function resetCamera()
	local cam = workspace.CurrentCamera
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		if hum then
			cam.CameraSubject = hum
		end
	end
	UI.setSpectate(nil)
end

player.CharacterAdded:Connect(function()
	Movement.reset()
	task.defer(resetCamera)
	UI.hideOverlay(true)
end)

RoundEvent.OnClientEvent:Connect(function(kind: string, data: any)
	NetStat.count("recv.RoundEvent")
	NetStat.count("recv.RoundEvent." .. tostring(kind))
	if kind == "Start" then
		UI.hideOverlay(false)
		UI.setStage(data.name)
		if data.stage == 1 then
			task.delay(2.5, UI.hint, if MobileUI.state().enabled then "음파 버튼 — 음파      달리기 · 웅크리기 버튼은 눌러서 켜고 끄기" else "좌클릭 — 음파      Shift — 달리기      Ctrl — 웅크리기", 7)
		end
		task.delay(if data.stage == 1 then 10 else 2.5, UI.hint, if MobileUI.state().enabled then "상자와 서랍(상호작용 버튼)을 뒤져 열쇠를 찾아야 출구가 열린다" else "상자와 서랍(E)을 뒤져 열쇠를 찾아야 출구가 열린다", 6)
	elseif kind == "DoppelBurst" then
		-- 도플갱어의 사람 모습이 터진다(조각이 흩날림)
		DoppelFx.burst(data)
		Audio.doppelBurst(data.at)
	elseif kind == "Scare" then
		-- 서브 괴물(잡혀도 죽지 않는 기믹): 점프스케어만
		playScare({ why = "monster", creature = data.creature, voice = data.voice })
		UI.hint("…놓아줬다. 아직 살아 있다", 3)
	elseif kind == "LifeLost" then
		-- 잡혔지만 목숨이 남았다: 점프스케어 → 잠깐 검은 화면 → 시작 방에서 다시(캐릭터가 생기면 화면이 걷힌다)
		if data.userId == player.UserId then
			if data.why == "monster" or data.why == "doppel" or data.why == "flower" then
				playScare(data)
				task.wait(JumpScare.Duration)
			end
			if player:GetAttribute("Status") == "Respawning" then
				UI.overlay("잡혔다", string.format("남은 목숨 %d — 시작 방에서 다시 시작합니다", data.lives), true)
			end
		else
			local who = Players:GetPlayerByUserId(data.userId)
			UI.hint(string.format("%s 님이 잡혔다 — 남은 목숨 %d", if who then who.DisplayName else "팀원", data.lives), 4)
		end
	elseif kind == "Died" then
		if data.userId == player.UserId and (data.why == "monster" or data.why == "doppel" or data.why == "flower") then
			-- 점프스케어: 괴물 얼굴이 확 뜬 뒤 YOU DIED (도플갱어는 머리~배가 세로로 벌어진 입)
			playScare(data)
			task.wait(JumpScare.Duration)
		end
		if data.userId == player.UserId then
			if data.othersAlive > 0 then
				UI.overlay("YOU DIED", "목숨을 모두 잃었다 — 관전으로 전환합니다", true)
				task.delay(2.5, function()
					if spectating() then
						UI.liftOverlay()
					end
				end)
			else
				UI.overlay("YOU DIED", "스테이지를 다시 시작합니다", true)
			end
		end
	elseif kind == "Escaped" then
		if data.userId == player.UserId then
			UI.overlay("ESCAPED", if data.othersAlive > 0 then "다른 생존자를 기다립니다" else "", true)
			task.delay(2.5, function()
				if spectating() then
					UI.liftOverlay()
				end
			end)
		end
	elseif kind == "Lobby" then
		UI.hideOverlay(false)
		UI.setSpectate(nil)
		UI.setStage("로비")
		task.delay(1.5, UI.hint, if MobileUI.state().enabled then "방 메뉴 버튼 — 방 만들기·참가      음파 버튼 — 음파" else "Tab — 방 메뉴      좌클릭 — 음파      Q — 지도", 7)
	elseif kind == "KeyFound" then
		local who = if data.userId == player.UserId then "열쇠를 찾았다" else (data.by .. " 님이 열쇠를 찾았다")
		local found, need = data.found or 1, data.need or 1
		UI.hint(string.format("%s (%d/%d)", who, found, need) .. (if found >= need then " — 이제 출구가 열린다" else string.format(" — 남은 열쇠 %d개", need - found)), 5)
	elseif kind == "SearchResult" then
		local t = if data.result == "searching" then "뒤지는 중…" elseif data.result == "empty" then "비어 있다" else "이미 뒤진 곳이다"
		UI.hint(t, if data.result == "searching" then 1 else 2)
	elseif kind == "KeyHintShown" then
		UI.hint((if data.userId == player.UserId then string.format("목숨 1개를 써서 힌트를 봤다(남은 목숨 %d)", data.lives or 0) else (data.by .. " 님이 목숨 1개를 써서 힌트를 봤다")) .. " — 마지막 열쇠 위치가 지도(Q)에 표시됨", 5)
	elseif kind == "KeyHintDenied" then
		UI.hint("목숨이 1개뿐이라 힌트를 볼 수 없다(목숨 1개를 쓴다)", 3)
	elseif kind == "ExitFound" then
		-- 누가 출구를 찾았다(팀 공유, 지도 Q 에도 표시된다)
		UI.hint((if data.userId == player.UserId then "출구를 찾았다" else (data.by .. " 님이 출구를 찾았다")) .. " — 지도(Q)에 표시됨", 5)
	elseif kind == "ExitLocked" then
		local found = (ReplicatedStorage:GetAttribute("Keys") :: number?) or 0
		local need = (ReplicatedStorage:GetAttribute("KeysNeeded") :: number?) or 1
		UI.hint(string.format("출구가 잠겨 있다 — 열쇠 %d/%d, 상자나 서랍에서 %d개 더 찾아야 한다", found, need, need - found), 3)
	elseif kind == "RoomMsg" then
		LobbyUI.message(data.text)
	elseif kind == "RoomStarting" then
		LobbyUI.message("게임을 시작합니다…", 6)
	elseif kind == "Clear" then
		local sub = if data.allClear then (if data.toLobby then "모든 스테이지를 탈출했습니다 — 로비로 돌아갑니다" else "모든 스테이지를 탈출했습니다 — 처음부터 다시 시작합니다") else ("다음: " .. data.nextName)
		UI.overlay("STAGE CLEAR", sub, true)
		UI.setSpectate(nil)
	elseif kind == "Failed" then
		local solo = #Players:GetPlayers() == 1
		UI.overlay("YOU DIED", if solo then "스테이지를 다시 시작합니다" else "모두 사망했습니다 — 스테이지를 다시 시작합니다", true)
		UI.setSpectate(nil)
	end
end)

-- ── 매 프레임 ──
-- 관전 카메라 보간 상태
local specCF: CFrame? = nil
local specTarget: Player? = nil
-- 내 시선(카메라 방향)을 초당 최대 10번, 바뀌었을 때만 서버로 보낸다(관전하는 사람이 내 시점 그대로 본다).
-- 관전 중인 사람(죽었거나 탈출한 다른 플레이어)이 있을 때만 보낸다: 아무도 관전하지 않으면 보낼 이유가 없다.
-- (관전이 시작되면 마지막으로 보낸 값과 다르면 바로 다시 보낸다)
local LookShare = Remotes:WaitForChild("LookShare") :: RemoteEvent
local lookSentAt, lookYaw, lookPitch = 0, 99, 99
local watchers = 0 -- 관전 중인 다른 플레이어 수(Status 속성 변화로 센다)
local function countWatchers()
	local n = 0
	for _, p in Players:GetPlayers() do
		local st = p:GetAttribute("Status")
		if p ~= player and (st == "Dead" or st == "Escaped") then
			n += 1
		end
	end
	watchers = n
end
local function watchStatus(p: Player)
	if p ~= player then
		p:GetAttributeChangedSignal("Status"):Connect(countWatchers)
	end
end
for _, p in Players:GetPlayers() do
	watchStatus(p)
end
Players.PlayerAdded:Connect(function(p)
	watchStatus(p)
	countWatchers()
end)
Players.PlayerRemoving:Connect(function()
	task.defer(countWatchers)
end)
countWatchers()
local function shareLook(now: number)
	local cam = workspace.CurrentCamera
	if watchers == 0 or not cam or now - lookSentAt < 0.1 or player:GetAttribute("Status") ~= "Alive" then
		return
	end
	local lv = cam.CFrame.LookVector
	local yaw = math.atan2(-lv.X, -lv.Z)
	local pitch = math.asin(math.clamp(lv.Y, -1, 1))
	local dy = math.abs((yaw - lookYaw + math.pi) % (2 * math.pi) - math.pi)
	if dy < 0.03 and math.abs(pitch - lookPitch) < 0.03 then
		return
	end
	lookSentAt, lookYaw, lookPitch = now, yaw, pitch
	LookShare:FireServer(yaw, pitch)
	NetStat.count("send.LookShare")
end
-- (측정) 복제되어 들어오는 속성 변경 수(플레이어·ReplicatedStorage)
local function watchAttrs(inst: Instance, prefix: string)
	inst.AttributeChanged:Connect(function(name)
		NetStat.count(prefix .. name)
	end)
end
watchAttrs(ReplicatedStorage, "attr.RS.")
for _, p in Players:GetPlayers() do
	watchAttrs(p, if p == player then "attr.me." else "attr.other.")
end
Players.PlayerAdded:Connect(function(p)
	watchAttrs(p, "attr.other.")
end)
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	-- 마우스 커서: 1인칭에서는 숨긴다(조준점만). 로비 메뉴(Tab)를 열었을 때만 보인다
	local free = LobbyUI.mouseFree()
	if UserInputService.MouseIconEnabled ~= free then
		UserInputService.MouseIconEnabled = free
	end
	table.insert(frameTimes, dt)
	if #frameTimes > 240 then
		table.remove(frameTimes, 1)
	end
	Movement.update(dt)
	local tp = os.clock()
	debug.profilebegin("sonar.pulses")
	Pulses.update(now)
	debug.profileend()
	local tl = os.clock()
	debug.profilebegin("sonar.lines")
	Lines.update(now)
	debug.profileend()
	local te = os.clock()
	prof.pulses += tl - now
	prof.lines += te - tl
	prof.frames += 1
	Perf.add("move.update", tp - now)
	Perf.add("pulses.update", tl - tp)
	Perf.add("lines.update", te - tl)
	Perf.frame(dt, te - now)
	table.insert(luaTimes, te - now)
	if #luaTimes > 240 then
		table.remove(luaTimes, 1)
	end
	local tu = os.clock()
	UI.setCooldown((now - lastFire) / Config.Sonar.Cooldown)
	shareLook(now)
	-- 관전 카메라: 살아 있는 동료의 1인칭 시점
	local cam = workspace.CurrentCamera
	if spectating() and cam then
		local targets = spectateTargets()
		if #targets > 0 then
			local t = targets[((spectateIndex - 1) % #targets) + 1]
			-- (머리는 걷는 애니메이션으로 흔들리고 네트워크로 계단처럼 움직여 떨렸다:
			--  몸 가운데(루트)의 눈높이를 따라가며 부드럽게 보간한다. 대상이 바뀌면 바로 그 자리로)
			local troot = t.Character and t.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local head = troot
			if head then
				cam.CameraType = Enum.CameraType.Scriptable
				-- 그 사람의 실제 카메라 방향(공유된 좌우·위아래 시선). 아직 없으면 몸이 향한 방향
				local eye = head.Position + Vector3.new(0, 1.6, 0)
				local yaw = t:GetAttribute("LookYaw") :: number?
				local pitch = (t:GetAttribute("LookPitch") :: number?) or 0
				local want = if yaw then CFrame.new(eye) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0) else head.CFrame * CFrame.new(0, 1.6, 0)
				if specTarget ~= t or not specCF or (specCF.Position - want.Position).Magnitude > 12 then
					specCF = want
					specTarget = t
				else
					specCF = (specCF :: CFrame):Lerp(want, 1 - math.exp(-dt * 10))
				end
				cam.CFrame = specCF :: CFrame
				UI.setSpectate("관전 중: " .. t.DisplayName .. "   (좌클릭: 대상 변경)")
			end
		else
			UI.setSpectate("관전할 생존자가 없습니다")
		end
	end
	NetStat.count("ui.frameUs", (os.clock() - tu) * 1e6)
	NetStat.count("ui.frames")
end)
RunService.Heartbeat:Connect(function()
	debug.profilebegin("audio.update")
	local t = os.clock()
	Audio.update()
	Perf.add("audio.update", os.clock() - t)
	debug.profileend()
end)

-- ── 자동 테스트 응답(Studio 테스트 하네스가 만든 TestProbe 가 있을 때만) ──
task.spawn(function()
	local probe = ReplicatedStorage:WaitForChild("TestProbe", 30) :: RemoteFunction?
	if not probe then
		return
	end
	probe.OnClientInvoke = function(cmd: string, arg: any)
		if cmd == "stats" then
			local sum, worst = 0, 0
			for _, t in frameTimes do
				sum += t
				worst = math.max(worst, t)
			end
			local ls = Lines.stats()
			return {
				ready = World.ready,
				buildId = World.buildId,
				steps = Audio.steps,
				build = { seconds = World.buildSeconds, cpu = World.buildCpu, segs = World.segCount },
				prof = { pulsesMs = if prof.frames > 0 then prof.pulses / prof.frames * 1000 else 0, linesMs = if prof.frames > 0 then prof.lines / prof.frames * 1000 else 0 },
				segs = World.segCount,
				culled = World.culled,
				unattached = World.unattached,
				viewParts = #World.viewParts,
				grid = { World.nx, World.ny, World.nz },
				lines = ls,
				pulses = Pulses.active(),
				pulsesStarted = Pulses.started,
				avgFrame = if #frameTimes > 0 then sum / #frameTimes else 0,
				lua = (function()
					local s2, w2 = 0, 0
					for _, t in luaTimes do
						s2 += t
						w2 = math.max(w2, t)
					end
					return { avg = if #luaTimes > 0 then s2 / #luaTimes else 0, worst = w2 }
				end)(),
				worstFrame = worst,
				ui = UI.state(),
				mode = Movement.mode,
				walkSpeed = (function()
					local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					return h and h.WalkSpeed or 0
				end)(),
				lighting = {
					brightness = game:GetService("Lighting").Brightness,
					ambient = game:GetService("Lighting").Ambient,
					outdoor = game:GetService("Lighting").OutdoorAmbient,
				},
			}
		elseif cmd == "perfx" then
			-- (성능 측정) 프레임 분포·시스템별 비용·메모리·네트워크·선·음파·소리. arg == "reset" 이면 읽은 뒤 비운다
			local Stats = game:GetService("Stats")
			local out = Perf.summary()
			out.lineStats = Lines.stats()
			out.pulses = Pulses.active()
			out.pulsesStarted = Pulses.started
			out.pulseMaxActive = Pulses.maxActive
			out.pulseCost = Pulses.costStats()
			out.memMb = Stats:GetTotalMemoryUsageMb()
			out.luaKb = gcinfo()
			out.instances = Stats.InstanceCount
			out.sounds = Audio.live
			out.soundsPeak = Audio.livePeak
			out.recvKbps = Stats.DataReceiveKbps
			out.sendKbps = Stats.DataSendKbps
			if arg == "reset" then
				Perf.reset()
				Pulses.resetCost()
				Audio.livePeak = Audio.live
				Lines.maxColor, Lines.maxPlace = 0, 0
			end
			return out
		elseif cmd == "pulseBench" then
			-- (성능 측정) 가짜 시계로 음파 n 개를 동시에 끝까지 돌린 비용(ms): 여러 번 되풀이해 최소·중앙값 → 다른 프로그램 부하에 덜 흔들린다
			local at, n, reps = arg.at, arg.n, arg.reps
			local starts, totals, peaks, waves, shown = {}, {}, {}, {}, 0
			for _ = 1, reps do
				Pulses.clear()
				Lines.clear()
				task.wait(0.15)
				local s0 = Lines.shownTotal
				local c0 = os.clock()
				for k = 1, n do
					Pulses.start(at[(k - 1) % #at + 1], player.Character, k == 1)
				end
				local c1 = os.clock()
				local now, peak, wave = c1, 0, 0
				for f = 1, 300 do
					now += 1 / 60
					local a = os.clock()
					Pulses.update(now)
					Lines.update(now)
					local d = os.clock() - a
					peak = math.max(peak, if f == 1 then d + (c1 - c0) else d)
					if Pulses.active() > 0 then
						wave += d
					end
					if Pulses.active() == 0 and Lines.stats().active == 0 then
						break
					end
				end
				table.insert(starts, (c1 - c0) * 1000)
				table.insert(waves, wave * 1000)
				table.insert(totals, (os.clock() - c0) * 1000)
				table.insert(peaks, peak * 1000)
				shown = Lines.shownTotal - s0
			end
			Pulses.clear()
			Lines.clear()
			local function mm(t)
				table.sort(t)
				return { min = t[1], med = t[(#t + 1) // 2] }
			end
			return { start = mm(starts), wave = mm(waves), total = mm(totals), peak = mm(peaks), shown = shown }
		elseif cmd == "netaudio" then
			-- (측정) 리모트·속성·소리 통계. arg == "reset" 이면 읽은 뒤 비운다
			local Stats = game:GetService("Stats")
			local snap = NetStat.snapshot(arg == "reset")
			snap.live = Audio.live
			snap.livePeak = Audio.livePeak
			-- 지금 살아 있는 소리의 나이: Audio.play 는 늦어도 6초에 지우므로 7초보다 오래된 것 = 누수
			local nowT, old, oldest, names = os.clock(), 0, 0, {}
			for _, info in Audio.liveSet do
				local age = nowT - info.t
				oldest = math.max(oldest, age)
				if age > 7 then
					old += 1
				end
				table.insert(names, string.format("%s@%.1fs", info.name, age))
			end
			snap.liveOld = old
			snap.liveOldestSec = math.floor(oldest * 10) / 10
			snap.liveNames = table.concat(names, " ")
			snap.memMb = Stats:GetTotalMemoryUsageMb()
			snap.luaKb = gcinfo()
			snap.instances = Stats.InstanceCount
			snap.recvKbps = Stats.DataReceiveKbps
			snap.sendKbps = Stats.DataSendKbps
			local n = 0
			for _, d in workspace:GetDescendants() do
				if d:IsA("Sound") then
					n += 1
				end
			end
			snap.soundsInWorkspace = n
			snap.soundsInSoundService = #game:GetService("SoundService"):GetChildren()
			if arg == "reset" then
				Audio.livePeak = Audio.live
			end
			return snap
		elseif cmd == "flood" then
			-- (측정) 리모트를 한 번에 많이 보낸다(서버 과부하 방어 시험). arg = { remote = 이름, n = 횟수 }
			local ev = Remotes:FindFirstChild(arg.remote) :: RemoteEvent?
			if not ev then
				return false
			end
			for k = 1, arg.n do
				if arg.remote == "LookShare" then
					ev:FireServer(math.random() * 6 - 3, math.random() - 0.5)
				elseif arg.remote == "MapShare" then
					ev:FireServer("sync")
				elseif arg.remote == "SetMoveMode" then
					ev:FireServer(if k % 2 == 0 then "Run" else "Walk")
				elseif arg.remote == "RoomAction" then
					ev:FireServer(if k % 2 == 0 then "leave" else "create")
				else
					ev:FireServer()
				end
			end
			return true
		elseif cmd == "spin" then
			-- (측정) 카메라를 계속 돌린다(시선 공유 송신량 측정). arg = 초당 라디안, 0 이면 멈춤
			local rate = tonumber(arg) or 0
			RunService:UnbindFromRenderStep("SonarTestSpin")
			if rate ~= 0 then
				RunService:BindToRenderStep("SonarTestSpin", Enum.RenderPriority.Camera.Value + 1, function(dt)
					local cam = workspace.CurrentCamera
					if cam then
						cam.CFrame = cam.CFrame * CFrame.Angles(0, rate * dt, 0)
					end
				end)
			end
			return true
		elseif cmd == "fire" then
			return fire()
		elseif cmd == "lastFail" then
			return { fail = Pulses.lastFail, ready = World.ready, hidden = player:GetAttribute("Hidden"), status = player:GetAttribute("Status") }
		elseif cmd == "rawFire" then
			-- 로컬 대기시간을 무시하고 서버에 바로 요청(서버 검증 시험)
			SonarFire:FireServer()
			return true
		elseif cmd == "move" then
			local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if h then
				h:MoveTo(arg :: Vector3)
			end
			return h ~= nil
		elseif cmd == "resetPerf" then
			table.clear(frameTimes)
			table.clear(luaTimes)
			prof.pulses, prof.lines, prof.frames = 0, 0, 0
			Lines.maxColor, Lines.maxPlace = 0, 0
			return true
		elseif cmd == "resetCooldown" then
			lastFire = -math.huge
			return true
		elseif cmd == "pulseAt" then
			-- 시각 효과만(서버에 알리지 않음): 지정 지점에서 음파
			return Pulses.start(arg :: Vector3, player.Character, true)
		elseif cmd == "floorEndsNear" then
			-- 바닥 높이 수평 선분 중 끝점이 p 에서 r 안에 있는 것의 수(모서리까지 선이 닿는가)
			local t = arg :: { any }
			local p, r = t[1] :: Vector3, t[2] :: number
			local n = 0
			for i = 1, World.segCount do
				local sa, sb = World.SA[i], World.SB[i]
				if math.abs(sa.Y - sb.Y) < 0.05 and math.abs(sa.Y - p.Y) < 0.3 and ((sa - p).Magnitude < r or (sb - p).Magnitude < r) then
					n += 1
				end
			end
			return n
		elseif cmd == "linesNear" then
			local t = arg :: { any }
			return Lines.countNear(t[1], t[2])
		elseif cmd == "lookTarget" or cmd == "useLook" then
			-- (테스트) arg 위치를 바라보게 한 뒤
			if typeof(arg) == "Vector3" then
				local cam = workspace.CurrentCamera
				cam.CFrame = CFrame.lookAt(cam.CFrame.Position, arg :: Vector3)
			end
			return if cmd == "lookTarget" then SearchLook.target() else SearchLook.use()
		elseif cmd == "soundCheck" then
			-- 실제 녹음 소리(괴성 후보 전부 + 괴물 발소리)가 이 게임에서 불러와지는가
			local ids = {}
			for _, r in (Config :: any).RealScreams do
				table.insert(ids, "rbxassetid://" .. r.Id)
				if r.Layer then
					table.insert(ids, "rbxassetid://" .. r.Layer.Id)
				end
			end
			table.insert(ids, (Config.Sounds :: any).MonsterStep.Id)
			local sounds = {}
			for _, id in ids do
				local snd = Instance.new("Sound")
				snd.SoundId = id
				snd.Volume = 0
				snd.Parent = workspace
				table.insert(sounds, snd)
			end
			local bad = {}
			pcall(function()
				game:GetService("ContentProvider"):PreloadAsync(sounds, function(contentId, status)
					if status ~= Enum.AssetFetchStatus.Success then
						table.insert(bad, contentId .. "=" .. status.Name)
					end
				end)
			end)
			local lengths = {}
			for _, snd in sounds do
				table.insert(lengths, math.floor(snd.TimeLength * 10) / 10)
				snd:Destroy()
			end
			return { total = #ids, bad = bad, lengths = lengths }
		elseif cmd == "prompts" then
			-- 주변 ProximityPrompt(거리·켜짐·이름) — 안내가 안 뜰 때 원인 찾기
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local out = {}
			for _, d in workspace:GetDescendants() do
				if d:IsA("ProximityPrompt") and d.Parent and d.Parent:IsA("BasePart") and root then
					local dist = ((d.Parent :: BasePart).Position - root.Position).Magnitude
					if dist < 12 then
						table.insert(out, string.format("%s %.1f/%d en=%s %s", d.ActionText, dist, d.MaxActivationDistance, tostring(d.Enabled), d.Parent:GetFullName()))
					end
				end
			end
			table.insert(out, "svc=" .. tostring(game:GetService("ProximityPromptService").Enabled))
			return table.concat(out, " ; ")
		elseif cmd == "mobile" then
			if arg ~= nil then
				player:SetAttribute("ForceMobileUI", arg == true)
			end
			task.wait(0.4)
			return MobileUI.state()
		elseif cmd == "reveal" then
			return Reveal.count()
		elseif cmd == "revealedModel" then
			-- (테스트) 이 괴물이 지금 음파에 드러나 보이는가 + 보이는 부품 수
			local mdl = arg :: Model
			local vis = 0
			for _, d in mdl:GetDescendants() do
				if d:IsA("BasePart") and d.Transparency < 1 and d.Name ~= "HumanoidRootPart" then
					vis += 1
				end
			end
			return { active = Reveal.active(mdl), visible = vis }
		elseif cmd == "creature" then
			-- (테스트) 챕터 괴물 애니메이션 측정: 프레임 수, 최대 관절 각, 착지(소리) 수
			if arg == "reset" then
				CreatureAnim.range = 1e9
				CreatureAnim.reset()
				RigAnim.reset()
				return true
			end
			return CreatureAnim.stats[arg] or RigAnim.stats[arg] or require(script.Parent:WaitForChild("SpriteAnim")).stats[arg]
		elseif cmd == "anim" then
			-- (테스트) 괴물 몸 움직임 측정: 디딘 발 미끄러짐, 걸음 수, 골반 오르내림, 척추 비틀림, 머리 지연, 실제 발소리 수
			local s = MonsterAnim.summary()
			s.footSounds = Audio.monsterSteps
			if arg == "reset" or arg == "all" then
				if arg == "all" then
					MonsterAnim.range = 1e9 -- (테스트) 멀리 있는 괴물도 계산
				end
				MonsterAnim.reset()
				Audio.monsterSteps = 0
			end
			return s
		elseif cmd == "doppelFx" then
			return { bursts = DoppelFx.bursts, shards = DoppelFx.lastShards, eyes = DoppelFx.litEyeCount(), sounds = Audio.bursts }
		elseif cmd == "jump" then
			local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if h then
				h.Jump = true
			end
			return h ~= nil
		elseif cmd == "cursor" then
			return UserInputService.MouseIconEnabled
		elseif cmd == "jumpscare" then
			return JumpScare.state()
		elseif cmd == "keyHud" then
			return KeyHUD.state()
		elseif cmd == "mates" then
			return Mates.count()
		elseif cmd == "lobby" then
			return LobbyUI.state()
		elseif cmd == "lobbyClick" then
			return LobbyUI.click(arg :: string)
		elseif cmd == "lobbyMenu" then
			LobbyUI.setMenu(arg == true)
			return LobbyUI.state()
		elseif cmd == "map" then
			return MapView.state()
		elseif cmd == "toggleMap" then
			MapView.toggle()
			return MapView.state()
		elseif cmd == "trace" then
			local p = Pulses.last
			if not p or not p.trace then
				return nil
			end
			return { trace = p.trace, revealed = p.revealed, origin = p.origin }
		elseif cmd == "lit" then
			return Lines.litMidpoints()
		elseif cmd == "segInfo" then
			-- 지정 선분 id 의 가운데 점
			return World.SM[arg :: number]
		elseif cmd == "segsNear" then
			-- arg = {pos, radius}: 그 근처 정적 선분 id
			local out = {}
			for i = 1, World.segCount do
				if (World.SM[i] - arg[1]).Magnitude <= arg[2] then
					table.insert(out, i)
				end
			end
			return out
		elseif cmd == "setMode" then
			Movement.forced = arg
			return true
		elseif cmd == "cell" then
			local x, y, z = World.cellOf(arg :: Vector3)
			if not x then
				return "out"
			end
			return if World.free(World.index(x :: number, y :: number, z :: number)) then "free" else "blocked"
		end
		return nil
	end
end)
