--!nonstrict
-- 자동 플레이 테스트. Studio 가 StudioTestService 로 플레이를 시작했을 때만 동작한다(tools/studio-test.js).
-- 일반 플레이·게시된 게임에서는 아무것도 하지 않는다. 모든 테스트 플레이어는 음소거(TestMute).
--   core  : 1인 — 어둠, 음파 퍼짐·유지·소멸, 벽/닫힌 문 가림, 발사 간격, 이동 속도, 괴물 청각·경로·추격·사망, 출구
--   multi : 여러 클라이언트 — 동시 음파, 서로의 음파 수신, 프레임 시간

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local StudioTestService = game:GetService("StudioTestService")
local okArgs, args = pcall(function()
	return StudioTestService:GetTestArgs()
end)
if not okArgs or type(args) ~= "table" or not args.Test then
	return
end

local Players = game:GetService("Players")
local LogService = game:GetService("LogService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Round = require(script.Parent.Round)
local Doors = require(script.Parent.Doors)
local SoundBus = require(script.Parent.SoundBus)

local R = { test = args.Test, finished = false, checks = {}, log = {}, errors = {}, info = {} }
local t0 = os.clock()
local function log(s)
	table.insert(R.log, string.format("%6.1f %s", os.clock() - t0, s))
end
local function check(name, ok, info)
	table.insert(R.checks, { name = name, ok = ok == true, info = if info ~= nil then tostring(info) else nil })
	log((if ok then "PASS " else "FAIL ") .. name .. (if info ~= nil then " (" .. tostring(info) .. ")" else ""))
end
LogService.MessageOut:Connect(function(msg, kind)
	if kind == Enum.MessageType.MessageError or (kind == Enum.MessageType.MessageWarning and (msg:find("%[Monster%]") or msg:find("%[SoundBus%]"))) then
		if #R.errors < 30 then
			table.insert(R.errors, msg:sub(1, 300))
		end
	end
end)

-- 테스트 설정: 괴물은 시험할 때만 움직이고, 결과 화면은 짧게
Config.Monster.StartDelay = 1e6
Config.Round.ResultSeconds = 2
Config.Round.FirstStartDelay = 1

for _, p in Players:GetPlayers() do
	p:SetAttribute("TestMute", true)
end
Players.PlayerAdded:Connect(function(p)
	p:SetAttribute("TestMute", true)
end)
local probe = Instance.new("RemoteFunction")
probe.Name = "TestProbe"
probe.Parent = ReplicatedStorage

local function ask(p, cmd, arg)
	-- (클라이언트가 응답하지 않아도 10초 뒤 nil)
	local done, ok, res = false, false, nil
	task.spawn(function()
		ok, res = pcall(function()
			return probe:InvokeClient(p, cmd, arg)
		end)
		done = true
	end)
	local t = os.clock()
	while not done and os.clock() - t < 10 do
		task.wait()
	end
	if not done then
		log("probe timeout " .. cmd)
		return nil
	end
	if not ok then
		log("probe error " .. cmd .. ": " .. tostring(res))
		return nil
	end
	return res
end

local function waitFor(fn, timeout)
	local t = os.clock()
	while os.clock() - t < timeout do
		local v = fn()
		if v then
			return v
		end
		task.wait(0.1)
	end
	return nil
end

local function root(p)
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end

local function place(p, pos, look)
	local char = p.Character
	if char then
		char:PivotTo(CFrame.lookAt(pos, look or (pos + Vector3.new(1, 0, 0))))
		local r = root(p)
		if r then
			r.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

local function tile(i, j, y)
	return Vector3.new((i - 1) * 8 + 4, y or 3, (j - 1) * 8 + 4)
end

local function readyPlayers(n)
	return waitFor(function()
		local ps = Players:GetPlayers()
		if #ps < n or Round.state ~= "Playing" then
			return nil
		end
		for _, p in ps do
			if p:GetAttribute("Status") ~= "Alive" or not root(p) then
				return nil
			end
			local st = ask(p, "stats")
			local stage = workspace:FindFirstChild("Stage")
			if not st or not st.ready or not stage or st.buildId ~= stage:GetAttribute("BuildId") then
				return nil
			end
		end
		return ps
	end, if n > 1 then 240 else 90)
end

local function stageFolder()
	return workspace:FindFirstChild("Stage")
end

-- ─────────────────────────────── core ───────────────────────────────
local function core()
	local ps = readyPlayers(1)
	check("player spawned and sonar world built", ps ~= nil)
	if not ps then
		return
	end
	local p = ps[1]
	local stage = stageFolder()
	local st = ask(p, "stats")
	R.info.world = st and { segs = st.segs, culled = st.culled, unattached = st.unattached, viewParts = st.viewParts, grid = st.grid }
	check("outline segments generated", st and st.segs > 1000, st and st.segs)
	check("almost every segment can receive the wave", st and st.unattached < st.segs * 0.08, st and (st.unattached .. "/" .. st.segs))
	check("seams removed (coplanar/buried edges culled)", st and st.culled > 0, st and st.culled)

	-- 1. 어둠
	local L = game:GetService("Lighting")
	local lights = 0
	for _, d in workspace:GetDescendants() do
		if d:IsA("Light") then
			lights += 1
		end
	end
	local bright = 0
	local neon = 0
	for _, d in stage:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Transparency < 1 and (d.Color.R + d.Color.G + d.Color.B) > 0.001 then
				bright += 1
			end
			if d.Material == Enum.Material.Neon then
				neon += 1
			end
		end
	end
	check("darkness: no ambient/brightness, no lights", L.Brightness == 0 and L.Ambient == Color3.new() and L.OutdoorAmbient == Color3.new() and lights == 0, "lights=" .. lights)
	check("darkness: every structure is black and unlit", bright == 0 and neon == 0, "nonblack=" .. bright .. " neon=" .. neon)
	check("client lighting is dark too", st and st.lighting.brightness == 0, st and st.lighting.brightness)
	task.wait(3)
	local idle = ask(p, "stats")
	check("nothing visible before a pulse", idle and idle.lines.lit == 0, idle and idle.lines.lit)

	-- 계단 경사로 방향(쐐기 방향 확인)
	local stairs = stage:FindFirstChild("Props") and stage.Props:FindFirstChild("Stairs")
	if stairs then
		local ramp = stairs:FindFirstChildWhichIsA("WedgePart")
		local f = ramp.CFrame.ZVector
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { ramp }
		local function h(off)
			local o = ramp.Position + f * off + Vector3.new(0, 10, 0)
			local hit = workspace:Raycast(o, Vector3.new(0, -30, 0), rp)
			return hit and hit.Position.Y
		end
		local hi, lo = h(2.5), h(-2.5)
		check("stairs ramp rises toward the upper floor", hi and lo and hi > lo + 2, tostring(hi) .. " vs " .. tostring(lo))
	end

	-- 걸을 수 있는 미로: 시작 → 출구 경로
	for _, agent in { { name = "player", r = 1.2, h = 5.5 }, { name = "monster", r = Config.Monster.AgentRadius, h = Config.Monster.AgentHeight } } do
		local path = PathfindingService:CreatePath({ AgentRadius = agent.r, AgentHeight = agent.h, AgentCanJump = false })
		local from = Round.info.spawns[1].Position - Vector3.new(0, 2.5, 0)
		local to = Round.info.exitCFrame.Position - Vector3.new(0, 3.5, 0)
		pcall(function()
			path:ComputeAsync(from, to)
		end)
		check("path start -> exit exists (" .. agent.name .. " size)", path.Status == Enum.PathStatus.Success, path.Status.Name .. " wps=" .. #path:GetWaypoints())
	end

	-- 2~4. 음파: 가까운 곳부터, 유지, 소멸
	place(p, tile(3, 3, 3), tile(3, 6, 3))
	task.wait(0.5)
	ask(p, "resetCooldown")
	local fired = ask(p, "fire")
	check("left-click pulse fires", fired == true)
	local samples = {}
	for _, t in { 0.1, 0.35, 0.7, 1.2 } do
		task.wait(t - (samples.t or 0))
		samples.t = t
		local s = ask(p, "stats")
		table.insert(samples, s and s.lines.lit or -1)
	end
	log("lit over time: " .. table.concat(samples, ", "))
	check("outline appears progressively (grows over time)", samples[1] < samples[2] and samples[2] <= samples[3] and samples[3] > 0, table.concat(samples, ","))
	local tr = ask(p, "trace")
	if tr and tr.trace and #tr.trace > 20 then
		local n = #tr.trace
		local early, late = 0, 0
		local k = math.max(1, n // 10)
		for i = 1, k do
			early += tr.trace[i][2]
			late += tr.trace[n - k + i][2]
		end
		early /= k
		late /= k
		local lastT = tr.trace[n][1]
		check("near structures revealed first, far last", early < late - 8, string.format("first10%%=%.1f last10%%=%.1f studs", early, late))
		check("wave reaches the far edge in ~R/speed", lastT > 0.5 and lastT < 1.4, string.format("%.2fs", lastT))
		-- 시간과 거리의 관계: 늦게 나타난 선일수록 멀다
		local monotone = 0
		for i = 2, n do
			if tr.trace[i][2] + 1.5 >= tr.trace[i - 1][2] then
				monotone += 1
			end
		end
		check("reveal order follows distance", monotone / (n - 1) > 0.97, string.format("%.3f", monotone / (n - 1)))
		R.info.pulse = { revealed = n, lastT = lastT }
	else
		check("pulse trace recorded", false, tr and #tr.trace)
	end
	task.wait(0.6) -- t≈1.8
	local mid = ask(p, "stats")
	check("outline still visible ~1.8s after the pulse", mid and mid.lines.lit > 0, mid and mid.lines.lit)
	task.wait(1.6) -- t≈3.4 (가장 먼 선은 0.9초에 나타나 2초 뒤 사라짐)
	local after = ask(p, "stats")
	check("outline gone again (~2s after reveal)", after and after.lines.lit == 0 and after.lines.active == 0, after and (after.lines.lit .. "/" .. after.lines.active))

	-- 5. 벽·닫힌 문 너머는 보이지 않는다
	local pillar = tile(8, 3, 0)
	local pillarSegs = ask(p, "segsNear", { pillar + Vector3.new(0, 6, 0), 3.5 }) or {}
	check("pillar behind the door has outline segments", #pillarSegs > 4, #pillarSegs)
	local door
	for _, d in Doors.all() do
		if (d.panel.Position - tile(5, 3, 4.5)).Magnitude < 4 then
			door = d
		end
	end
	check("test door found", door ~= nil)
	local function revealedFrom(pos)
		ask(p, "resetCooldown")
		place(p, pos, pillar + Vector3.new(0, 3, 0))
		task.wait(0.4)
		ask(p, "fire")
		task.wait(1.3)
		local t = ask(p, "trace")
		local set = {}
		for _, e in (t and t.trace) or {} do
			set[e[3]] = true
		end
		local hits = 0
		for _, id in pillarSegs do
			if set[id] then
				hits += 1
			end
		end
		return hits, (t and #t.trace) or 0
	end
	if door then
		if door.open then
			Doors.toggle(door)
			task.wait(0.8)
		end
		local hits, total = revealedFrom(Vector3.new(29, 3, 20))
		check("closed door: structures behind it are NOT revealed", hits == 0 and total > 50, "pillar hits=" .. hits .. " total=" .. total)
		Doors.toggle(door)
		task.wait(0.9)
		local hits2, total2 = revealedFrom(Vector3.new(29, 3, 20))
		check("open door: the wave passes through the doorway", hits2 > 0, "pillar hits=" .. hits2 .. " total=" .. total2)
		Doors.toggle(door)
		task.wait(0.8)
	end
	-- 두꺼운 벽 너머(옆방)도 보이지 않는다: 시작 방 동쪽 8스터드 벽 너머 방의 북쪽 벽면(직선 거리 32, 문을 돌아가면 36 이상)
	do
		local crate = Vector3.new(44, 12.5, 9.5) -- (북쪽 벽-천장 모서리와 경사)
		local segs = ask(p, "segsNear", { crate, 3.5 }) or {}
		ask(p, "resetCooldown")
		place(p, tile(2, 2, 3), crate)
		task.wait(0.4)
		ask(p, "fire")
		task.wait(1.3)
		local t = ask(p, "trace")
		local set = {}
		for _, e in (t and t.trace) or {} do
			set[e[3]] = true
		end
		local hits = 0
		for _, id in segs do
			if set[id] then
				hits += 1
			end
		end
				check("room behind a wall is not revealed", #segs > 0 and hits == 0, "segs=" .. #segs .. " hits=" .. hits)
	end

	-- 6. 서버의 발사 간격 검증
	task.wait(1.6)
	local Main = _G.SonarMaze
	local before = Main.Sonar.accepted[p] or 0
	ask(p, "rawFire")
	task.wait(0.15)
	ask(p, "rawFire")
	task.wait(0.15)
	ask(p, "rawFire")
	task.wait(0.4)
	local mid1 = Main.Sonar.accepted[p] or 0
	task.wait(1.4)
	ask(p, "rawFire")
	task.wait(0.4)
	local mid2 = Main.Sonar.accepted[p] or 0
	check("server enforces the 1.5s pulse interval", mid1 - before == 1 and mid2 - mid1 == 1, string.format("burst accepted %d, after 1.8s %d", mid1 - before, mid2 - mid1))

	-- 13. 반복 발사해도 쌓이지 않는다
	task.wait(2.5)
	local function burst()
		for _ = 1, 12 do
			ask(p, "pulseAt", root(p).Position + Vector3.new(0, 1.5, 0))
			task.wait(0.25)
		end
	end
	burst()
	local s1 = ask(p, "stats")
	task.wait(3)
	local s1b = ask(p, "stats")
	burst()
	local s2 = ask(p, "stats")
	task.wait(3)
	local s3 = ask(p, "stats")
	log(string.format("burst lines: active %d created %d / after %d / burst2 active %d created %d / after %d", s1.lines.active, s1.lines.created, s1b.lines.active, s2.lines.active, s2.lines.created, s3.lines.active))
	check("repeated pulses reuse lines (no pile-up)", s2.lines.created <= s1.lines.created * 1.15 + 20 and s2.lines.active < Config.Sonar.PoolSize, string.format("created %d -> %d, active %d", s1.lines.created, s2.lines.created, s2.lines.active))
	check("all lines released after the burst", s1b.lines.active == 0 and s3.lines.active == 0, s3.lines.active)

	-- 7. 걷기·달리기·웅크리기
	local speeds = {}
	for _, m in { "Run", "Crouch", "Walk" } do
		ask(p, "setMode", m)
		task.wait(0.5)
		local s = ask(p, "stats")
		local hum = p.Character:FindFirstChildOfClass("Humanoid")
		speeds[m] = { s and s.walkSpeed, p.Character:GetAttribute("MoveMode"), hum.WalkSpeed }
	end
	ask(p, "setMode", nil)
	check("run speed 18 (client+server)", speeds.Run[1] == 18 and speeds.Run[2] == "Run" and speeds.Run[3] == 18, table.concat({ tostring(speeds.Run[1]), tostring(speeds.Run[2]) }, " "))
	check("crouch speed 5", speeds.Crouch[1] == 5 and speeds.Crouch[2] == "Crouch", tostring(speeds.Crouch[1]))
	check("walk speed 10", speeds.Walk[1] == 10 and speeds.Walk[2] == "Walk", tostring(speeds.Walk[1]))
	-- 실제로 걸어서 발소리 소음이 나는가(서버가 속도로 판정)
	place(p, tile(2, 6, 3), tile(2, 8, 3))
	task.wait(0.3)
	local n0 = #SoundBus.recent
	ask(p, "setMode", "Run")
	ask(p, "move", tile(2, 8, 3))
	task.wait(1.0)
	local kinds = {}
	for i = n0 + 1, #SoundBus.recent do
		kinds[SoundBus.recent[i].kind] = true
	end
	ask(p, "setMode", nil)
	check("running makes loud footstep noise (server-measured)", kinds.StepRun == true, (function()
		local t = {}
		for k in kinds do
			table.insert(t, k)
		end
		return table.concat(t, ",")
	end)())

	-- 소리 감쇠
	local a, b = tile(2, 3, 3), tile(2, 5, 3) -- 시작 방과 그 아래(벽 사이)
	local walls = SoundBus.wallsBetween(a, b)
	check("sound attenuation counts walls between", walls >= 1, walls)
	check("hearing ranges: crouch 4 < walk 10 < run 25 < sonar 45", Config.Noise.Crouch == 4 and Config.Noise.Walk == 10 and Config.Noise.Run == 25 and Config.Noise.Sonar == 45)

	-- 8~9. 괴물: 소리 감지 → 이동(벽 통과 없음)
	local m = Round.monsters[1]
	check("monster exists", m ~= nil)
	if not m then
		return
	end
	-- 플레이어는 멀리(출구 쪽 반대 구석)
	place(p, tile(2, 3, 3))
	local geo = stage:FindFirstChild("Geometry")
	local wallParams = RaycastParams.new()
	wallParams.FilterType = Enum.RaycastFilterType.Include
	wallParams.FilterDescendantsInstances = { geo }
	wallParams.RespectCanCollide = true
	local startNode = tile(10, 16, 5.2)
	local soundAt = tile(15, 16, 4.5)
	m.model:PivotTo(CFrame.new(startNode))
	m.waypoints = {}
	m:setState("Wander")
	m.startAt = 0
	task.wait(0.5)
	SoundBus.emit(soundAt, Config.Noise.Sonar, nil, "Sonar")
	local heard = waitFor(function()
		return m.state == "Alert" or m.state == "Investigate"
	end, 2)
	check("monster reacts to a sonar pulse 40 studs away", heard ~= nil, m.state)
	local prev = m.root.Position
	local through = 0
	local maxStep = 0
	local reached = waitFor(function()
		local cur = m.root.Position
		local d = cur - prev
		if d.Magnitude > 0.05 then
			maxStep = math.max(maxStep, d.Magnitude)
			local hit = workspace:Raycast(prev, d, wallParams)
			if hit then
				through += 1
			end
		end
		prev = cur
		return (cur - soundAt).Magnitude < 7 or m.state == "Search"
	end, 25)
	check("monster walks to the sound position", reached ~= nil, string.format("dist=%.1f state=%s", (m.root.Position - soundAt).Magnitude, m.state))
	check("monster never passes through walls", through == 0, "crossings=" .. through .. " maxStep=" .. string.format("%.2f", maxStep))
	-- 수색 → 배회 복귀
	local searching = waitFor(function()
		return m.state == "Search"
	end, 5)
	check("monster searches around the sound", searching ~= nil, m.state)
	R.info.monsterLog = m.log

	-- 걷는 소리는 가까이에서만 들린다
	m:setState("Wander")
	m.waypoints = {}
	local mp = m.root.Position
	local far = mp + Vector3.new(30, 0, 0)
	check("monster does not hear walking 30 studs away", not SoundBus.canHear(far, mp, Config.Noise.Walk))

	-- 13. 출구 → 탈출 → STAGE CLEAR
	m.startAt = 1e9
	m:setState("Wander")
	place(p, Round.info.exitCFrame.Position + Vector3.new(0, -0.5, 0))
	local esc = waitFor(function()
		return p:GetAttribute("Status") == "Escaped"
	end, 3)
	check("reaching the exit escapes", esc ~= nil, p:GetAttribute("Status"))
	local cleared = waitFor(function()
		return Round.lastOutcome == "Clear"
	end, 4)
	check("stage clear when all survivors escaped", cleared ~= nil, Round.lastOutcome)
	check("clear advances to the next stage", Round.stageIndex == 2 or (Round.stageIndex == 1 and #Config.Stages >= 1), Round.stageIndex)
	Round.stageIndex = 1 -- (사망 시험은 스테이지 1 좌표로)
	task.wait(0.8)
	local ui = ask(p, "stats")
	check("STAGE CLEAR screen shown", ui and ui.ui.overlayTitle == "STAGE CLEAR", ui and ui.ui.overlayTitle)

	-- 10. 다음 라운드에서 잡히기 → 사망 → (혼자) 재시작
	Round.lastOutcome = ""
	local again = readyPlayers(1)
	check("next round starts and player respawns", again ~= nil, ReplicatedStorage:GetAttribute("StageName"))
	if not again then
		return
	end
	local m2 = Round.monsters[1]
	-- 직선 통로에서 12스터드 떨어져 마주 본다
	place(p, tile(3, 10, 3), tile(6, 10, 3))
	m2.model:PivotTo(CFrame.lookAt(tile(5, 10, 5.2) - Vector3.new(4, 0, 0), tile(3, 10, 5.2)))
	m2.waypoints = {}
	m2.startAt = 0
	local chased = waitFor(function()
		return m2.state == "Chase"
	end, 3)
	check("monster spots a nearby player and chases", chased ~= nil, m2.state)
	local died = waitFor(function()
		return p:GetAttribute("Status") == "Dead"
	end, 8)
	check("caught by the monster -> death", died ~= nil, p:GetAttribute("Status"))
	task.wait(1.2)
	local dui = ask(p, "stats")
	check("YOU DIED screen shown", dui and dui.ui.overlayTitle == "YOU DIED", dui and dui.ui.overlayTitle)
	local failed = waitFor(function()
		return Round.lastOutcome == "Failed"
	end, 4)
	check("solo death restarts the stage", failed ~= nil, Round.lastOutcome)
	local back = readyPlayers(1)
	check("respawned after restart", back ~= nil)
	local fs = ask(p, "stats")
	R.info.frame = fs and { avg = fs.avgFrame, worst = fs.worstFrame }
end

-- ─────────────────────────────── multi ───────────────────────────────
local function multi()
	local want = tonumber(args.Players) or 2
	local ps = readyPlayers(want)
	check("all " .. want .. " players spawned with sonar ready", ps ~= nil, #Players:GetPlayers())
	if not ps then
		return
	end
	-- 모두 시작 방 근처에 모은다
	for k, p in ps do
		place(p, tile(2 + (k - 1) % 3, 2 + (k - 1) // 3 * 2, 3))
	end
	task.wait(1)
	local base = {}
	for _, p in ps do
		base[p] = ask(p, "stats").pulsesStarted
		ask(p, "resetPerf")
	end
	local rounds = 6
	for _ = 1, rounds do
		for _, p in ps do
			task.spawn(ask, p, "fire")
		end
		task.wait(1.7)
	end
	task.wait(3)
	local worst, sumAvg = 0, 0
	local luaAvg, luaWorst = 0, 0
	for _, p in ps do
		local s = ask(p, "stats")
		local got = s.pulsesStarted - base[p]
		check(p.Name .. " saw own + others' pulses", got >= rounds * #ps * 0.9, got .. "/" .. rounds * #ps)
		check(p.Name .. " lines released afterwards", s.lines.active == 0, s.lines.active)
		worst = math.max(worst, s.worstFrame)
		sumAvg += s.avgFrame
		luaAvg += s.lua.avg
		luaWorst = math.max(luaWorst, s.lua.worst)
		R.info[p.Name] = { avgFrame = s.avgFrame, worstFrame = s.worstFrame, created = s.lines.created }
	end
	-- (Studio 테스트 창은 모두 비활성 창이라 15fps 로 묶인다: 화면 프레임 대신 음파 스크립트 비용을 본다)
	check("sonar script cost with " .. #ps .. " players pulsing together < 4ms/frame", luaAvg / #ps < 0.004, string.format("lua avg %.2fms worst %.2fms (window frame avg %.1fms)", luaAvg / #ps * 1000, luaWorst * 1000, sumAvg / #ps * 1000))
	-- 한 명이 죽으면 관전, 나머지는 계속
	local victim = ps[1]
	Round.kill(victim, "test")
	task.wait(3)
	local s = ask(victim, "stats")
	check("dead player spectates a teammate", s and s.ui.spectate ~= nil and s.ui.spectate:find("관전 중") ~= nil, s and s.ui.spectate)
	check("round continues while others live", Round.state == "Playing")
	-- 남은 사람 탈출 → 클리어
	for k = 2, #ps do
		place(ps[k], Round.info.exitCFrame.Position + Vector3.new(0, -0.5, 0))
		task.wait(0.4)
	end
	local cleared = waitFor(function()
		return Round.lastOutcome == "Clear"
	end, 5)
	check("survivors escape -> stage clear (with one dead)", cleared ~= nil, Round.lastOutcome)
end

-- ─────────────────────────────── perf ───────────────────────────────
local function perf()
	local ps = readyPlayers(tonumber(args.Players) or 1)
	if not ps then
		check("ready", false)
		return
	end
	local p = ps[1]
	place(p, tile(3, 3, 3), tile(3, 6, 3))
	task.wait(2)
	ask(p, "resetPerf")
	task.wait(3)
	local idle = ask(p, "stats")
	ask(p, "resetPerf")
	for _ = 1, 4 do
		for _, q in ps do
			ask(q, "resetCooldown")
			task.spawn(ask, q, "fire")
		end
		task.wait(1.55)
	end
	local busy = ask(p, "stats")
	R.info.perf = {
		idleFrameMs = idle.avgFrame * 1000, idleWorstMs = idle.worstFrame * 1000, idleLuaMs = idle.lua.avg * 1000,
		busyFrameMs = busy.avgFrame * 1000, busyWorstMs = busy.worstFrame * 1000, busyLuaMs = busy.lua.avg * 1000, busyLuaWorstMs = busy.lua.worst * 1000,
		lines = busy.lines,
	}
	check("sonar script cost per frame (avg) < 4ms", busy.lua.avg < 0.004, string.format("%.2fms avg, %.2fms worst", busy.lua.avg * 1000, busy.lua.worst * 1000))
end

-- ─────────────────────────────── stages ───────────────────────────────
-- 스테이지 1~5 를 차례로 지어: 오류 없이 지어지는가, 시작→출구 경로, 괴물 수, 음파 선이 나오는가
local function stages()
	local ps = readyPlayers(1)
	check("player ready", ps ~= nil)
	if not ps then
		return
	end
	local p = ps[1]
	for i = 1, #Config.Stages do
		local errBefore = #R.errors
		Round.startStage(i)
		local ok = readyPlayers(1)
		check(string.format("stage %d built and player spawned", i), ok ~= nil and #R.errors == errBefore, Config.Stages[i].Name)
		if ok then
			local st = ask(p, "stats")
			local paths = {}
			for _, agent in { { r = 1.2, h = 5.5 }, { r = Config.Monster.AgentRadius, h = Config.Monster.AgentHeight } } do
				local path = PathfindingService:CreatePath({ AgentRadius = agent.r, AgentHeight = agent.h, AgentCanJump = false })
				pcall(function()
					path:ComputeAsync(Round.info.spawns[1].Position - Vector3.new(0, 2.5, 0), Round.info.exitCFrame.Position - Vector3.new(0, 3.5, 0))
				end)
				table.insert(paths, path.Status.Name)
			end
			check(string.format("stage %d: start -> exit walkable (player, monster)", i), paths[1] == "Success" and paths[2] == "Success", table.concat(paths, ","))
			check(string.format("stage %d: %d monster(s)", i, Config.Stages[i].Monsters), #Round.monsters == Config.Stages[i].Monsters, #Round.monsters)
			ask(p, "resetCooldown")
			ask(p, "fire")
			task.wait(1.2)
			local s2 = ask(p, "stats")
			check(string.format("stage %d: sonar reveals outlines", i), s2 and s2.lines.lit > 100, s2 and string.format("segs=%d lit=%d unattached=%d", st.segs, s2.lines.lit, st.unattached))
			R.info["stage" .. i] = st and { segs = st.segs, culled = st.culled, unattached = st.unattached, parts = workspace.Stage:GetAttribute("PartCount") }
			task.wait(2.2)
		end
	end
end

task.spawn(function()
	local ok, err = pcall(function()
		if args.Test == "multi" then
			multi()
		elseif args.Test == "perf" then
			perf()
		elseif args.Test == "stages" then
			stages()
		else
			core()
		end
	end)
	if not ok then
		check("test script ran", false, err)
	end
	R.finished = true
	R.events = Round.events
	log("done")
	StudioTestService:EndTest(R)
end)
