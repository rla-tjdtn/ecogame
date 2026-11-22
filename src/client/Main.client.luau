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
local Reveal = require(script.Parent:WaitForChild("Reveal"))
local MobileUI = require(script.Parent:WaitForChild("MobileUI"))
Pulses.onReach = MapView.onReach
-- 음파가 시작될 때(내 것·팀원 것): 도플갱어 눈 빛 + 맞은 괴물은 10초 동안 지금 모습 그대로 보이게(굳은 잔상 선은 그리지 않는다)
World.skipMonster = Reveal.has
Pulses.onStart = function(origin: Vector3)
	DoppelFx.onPulse(origin)
	Reveal.onPulse(origin)
end

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
	Audio.sonar(true, head.Position)
	return true
end

local function charOf(userId: number): Model?
	local p = Players:GetPlayerByUserId(userId)
	return p and p.Character
end

SonarPulse.OnClientEvent:Connect(function(userId: number, origin: Vector3)
	if typeof(origin) ~= "Vector3" then
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
		prompt.PromptHidden:Once(function()
			conn:Disconnect()
			conn2:Disconnect()
			if shownPrompt == prompt then
				shownPrompt = nil
				UI.setPrompt(nil)
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
	elseif kind == "LifeLost" then
		-- 잡혔지만 목숨이 남았다: 점프스케어 → 잠깐 검은 화면 → 시작 방에서 다시(캐릭터가 생기면 화면이 걷힌다)
		if data.userId == player.UserId then
			if data.why == "monster" or data.why == "doppel" or data.why == "flower" then
				JumpScare.play(function()
					-- 잡은 괴물의 자기 괴성(도플갱어 / 그 스테이지 메인 괴물)
					local si = (ReplicatedStorage:GetAttribute("StageIndex") :: number?) or 1
					local voice = if data.why == "doppel" then "Doppel" elseif data.why == "flower" then "Flower" else tostring((math.max(1, si) - 1) % 5 + 1)
					Audio.play(Audio.voiceName(voice, "Scream") or "MonsterAlert", nil, 0.03, 0.8)
				end, data.why)
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
			JumpScare.play(function()
				-- 잡은 괴물의 자기 괴성(도플갱어 / 그 스테이지 메인 괴물)
				local si = (ReplicatedStorage:GetAttribute("StageIndex") :: number?) or 1
				local voice = if data.why == "doppel" then "Doppel" elseif data.why == "flower" then "Flower" else tostring((math.max(1, si) - 1) % 5 + 1)
				Audio.play(Audio.voiceName(voice, "Scream") or "MonsterAlert", nil, 0.03, 0.8)
			end, data.why)
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
		UI.hint((if data.userId == player.UserId then "열쇠를 찾았다" else (data.by .. " 님이 열쇠를 찾았다")) .. " — 이제 출구가 열린다", 5)
	elseif kind == "SearchResult" then
		local t = if data.result == "searching" then "뒤지는 중…" elseif data.result == "empty" then "비어 있다" else "이미 뒤진 곳이다"
		UI.hint(t, if data.result == "searching" then 1 else 2)
	elseif kind == "ExitLocked" then
		UI.hint("출구가 잠겨 있다 — 상자나 서랍에서 열쇠를 찾아야 한다", 3)
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
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	-- 마우스 커서: 1인칭에서는 숨긴다(조준점만). 로비 메뉴(Tab)를 열었을 때만 보인다
	UserInputService.MouseIconEnabled = LobbyUI.mouseFree()
	table.insert(frameTimes, dt)
	if #frameTimes > 240 then
		table.remove(frameTimes, 1)
	end
	Movement.update(dt)
	Pulses.update(now)
	local tl = os.clock()
	Lines.update(now)
	prof.pulses += tl - now
	prof.lines += os.clock() - tl
	prof.frames += 1
	table.insert(luaTimes, os.clock() - now)
	if #luaTimes > 240 then
		table.remove(luaTimes, 1)
	end
	UI.setCooldown((now - lastFire) / Config.Sonar.Cooldown)
	-- 관전 카메라: 살아 있는 동료의 1인칭 시점
	local cam = workspace.CurrentCamera
	if spectating() and cam then
		local targets = spectateTargets()
		if #targets > 0 then
			local t = targets[((spectateIndex - 1) % #targets) + 1]
			local head = t.Character and t.Character:FindFirstChild("Head") :: BasePart?
			if head then
				cam.CameraType = Enum.CameraType.Scriptable
				cam.CFrame = head.CFrame * CFrame.new(0, 0.3, 0)
				UI.setSpectate("관전 중: " .. t.DisplayName .. "   (좌클릭: 대상 변경)")
			end
		else
			UI.setSpectate("관전할 생존자가 없습니다")
		end
	end
end)
RunService.Heartbeat:Connect(function()
	Audio.update()
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
		elseif cmd == "fire" then
			return fire()
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
		elseif cmd == "doppelFx" then
			return { bursts = DoppelFx.bursts, shards = DoppelFx.lastShards, eyes = DoppelFx.litEyeCount() }
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
