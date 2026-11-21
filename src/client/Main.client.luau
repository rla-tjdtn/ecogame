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
Pulses.onReach = MapView.onReach

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
		World.build(stage)
		MapView.load(stage)
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
ProximityPromptService.PromptShown:Connect(function(prompt)
	if prompt.Style == Enum.ProximityPromptStyle.Custom then
		UI.setPrompt(promptText(prompt))
		local conn = prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
			UI.setPrompt(promptText(prompt))
		end)
		local conn2 = player:GetAttributeChangedSignal("Hidden"):Connect(function()
			UI.setPrompt(promptText(prompt))
		end)
		prompt.PromptHidden:Once(function()
			conn:Disconnect()
			conn2:Disconnect()
			UI.setPrompt(nil)
		end)
	end
end)

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
			task.delay(2.5, UI.hint, "좌클릭 — 음파      Shift — 달리기      Ctrl — 웅크리기", 7)
		end
	elseif kind == "Died" then
		if data.userId == player.UserId then
			if data.othersAlive > 0 then
				UI.overlay("YOU DIED", "관전으로 전환합니다", true)
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
	elseif kind == "Clear" then
		local sub = if data.allClear then "모든 스테이지를 탈출했습니다 — 처음부터 다시 시작합니다" else ("다음: " .. data.nextName)
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
