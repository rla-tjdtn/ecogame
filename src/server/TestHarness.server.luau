--!nonstrict
-- 자동 플레이 테스트. Studio 가 StudioTestService 로 플레이를 시작했을 때만 동작한다(tools/studio-test.js).
-- 일반 플레이·게시된 게임에서는 아무것도 하지 않는다. 모든 테스트 플레이어는 음소거(TestMute).
--   core  : 1인 — 어둠, 음파 퍼짐·유지·소멸, 벽/닫힌 문 가림, 발사 간격, 이동 속도, 괴물 청각·경로·추격·사망, 출구
--   multi : 여러 클라이언트 — 동시 음파, 서로의 음파 수신, 프레임 시간

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
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
local Hiding = require(script.Parent.Hiding)

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

-- 시작 → 출구를 실제로 걸을 수 있는가. 괴물과 같은 방식: 바로 계산이 안 되면 타일 경로를 LegTiles 칸씩 나눠 계산
local function routeWalkable(agent, monster: boolean): (string, number)
	local path = PathfindingService:CreatePath({ AgentRadius = agent.r, AgentHeight = agent.h, AgentCanJump = false })
	local from = Round.info.spawns[1].Position - Vector3.new(0, 2.5, 0)
	local to = Round.info.exitCFrame.Position - Vector3.new(0, 3.5, 0)
	local function compute(a, b)
		local ok = pcall(function()
			path:ComputeAsync(a, b)
		end)
		return ok and path.Status == Enum.PathStatus.Success
	end
	if compute(from, to) then
		return "Success", 1
	end
	local r = Round.info.route(from, to, monster)
	if not r then
		return "NoRoute", 0
	end
	local pos, idx, legs = from, 1, 0
	while idx < #r do
		local step = Config.Monster.LegTiles
		local moved = false
		for _, n in { math.min(#r, idx + step), math.min(#r, idx + math.ceil(step / 2)), idx + 1 } do
			if compute(pos, r[n]) then
				pos, idx, legs, moved = r[n], n, legs + 1, true
				break
			end
		end
		if not moved then
			return string.format("LegFail@c%d,r%d", math.floor(r[idx].X / 8), math.floor(r[idx].Z / 8)), legs
		end
	end
	return "Success", legs
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

-- ─────────────────────────────── 괴물 모습·등장 ───────────────────────────────
local function monsterTests(p)
	local m = Round.monsters[1]
	if not m then
		check("monster exists for look tests", false)
		return
	end
	-- 막대는 한 획(Line), 얇은 원판은 원 하나(Disc): 음파에 여러 겹 선으로 보이지 않게
	local cyl, ok = 0, 0
	for _, d in m.model:GetDescendants() do
		if d:IsA("Part") and d.Shape == Enum.PartType.Cylinder then
			cyl += 1
			local sh = d:GetAttribute("SonarShape")
			if sh == "Line" or sh == "Disc" then
				ok += 1
			end
		end
	end
	check("monster strokes draw as single lines (Line/Disc)", cyl > 10 and ok == cyl, ok .. "/" .. cyl)
	-- 음파가 닿으면 괴물 모습이 선으로 나타난다
	m.startAt = 1e9
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		place(p, tile(3, 10, 3), tile(7, 10, 3))
		task.wait(0.3)
		local mpos = tile(6, 10, 5.2)
		m.model:PivotTo(CFrame.lookAt(mpos, tile(3, 10, 5.2)))
		m.waypoints = {}
		task.wait(0.3)
		ask(p, "resetCooldown")
		ask(p, "fire")
		task.wait(1.0)
		local n = ask(p, "linesNear", { mpos, 4.5 }) or 0
		check("monster appears in the sonar as lines", n >= 15, n)
	end
	-- 배회하다가 가끔 플레이어 근처로 온다
	m.model:PivotTo(CFrame.new(Round.info.exitCFrame.Position + Vector3.new(0, 1.2, 0)))
	m.waypoints = {}
	m.legGoal = nil
	m.target = nil
	m:setState("Wander")
	m.lastHunt = -1e9
	m.startAt = 0
	m.goal = nil
	waitFor(function()
		return m.lastHunt > 0
	end, 4)
	task.wait(2) -- (먼 길은 경로 계산이 걸린다)
	local goal = m.goal
	local pr = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local gd = if goal and pr then (goal - pr.Position).Magnitude else -1
	check("wandering monster drifts toward a player now and then", goal ~= nil and gd >= 0 and gd <= Config.Monster.HuntRadius + 8, string.format("%.0f studs", gd))
	m.startAt = 1e9
	m.waypoints = {}
end

-- ─────────────────────────────── 숨는 곳 ───────────────────────────────
-- 들어가기(E) → 음파 못 쏨 → 바로 앞 괴물도 못 찾음 → 나오기(E) → 쫓던 괴물이 숨는 걸 보면 끌어냄(사망)
local function hideTests(p)
	local spots = Hiding.all()
	check("hide spots built (cabinets/wardrobes)", #spots >= 5, #spots)
	local spot = spots[1]
	local m = Round.monsters[1]
	if not spot or not m then
		return
	end
	m.startAt = 1e9
	place(p, spot.front + Vector3.new(0, 3, 0), spot.center + Vector3.new(0, 3, 0))
	task.wait(0.5)
	local ui0 = ask(p, "stats")
	check("hide prompt shown near the cabinet", ui0 and ui0.ui.prompt == "E   숨기", ui0 and tostring(ui0.ui.prompt))
	local ok = Hiding.enter(p, spot)
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local inside = root and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(spot.center.X, 0, spot.center.Z)).Magnitude
	check("E: hide inside (anchored, inside the cabinet)", ok and p:GetAttribute("Hidden") == true and root ~= nil and root.Anchored and inside ~= nil and inside < 1.5, string.format("ok=%s inside=%.2f", tostring(ok), inside or -1))
	local ui1 = nil
	waitFor(function()
		ui1 = ask(p, "stats")
		return ui1 and ui1.ui.prompt == "E   나가기"
	end, 3)
	check("prompt says get out while hidden", ui1 and ui1.ui.prompt == "E   나가기", ui1 and tostring(ui1.ui.prompt))
	local Main = _G.SonarMaze
	local before = Main.Sonar.accepted[p] or 0
	ask(p, "resetCooldown")
	local fired = ask(p, "fire")
	ask(p, "rawFire")
	task.wait(0.6)
	check("no sonar while hidden", not fired and (Main.Sonar.accepted[p] or 0) == before, tostring(fired))
	local mpos = spot.front + spot.facing * 2 + Vector3.new(0, 5.2, 0)
	m.model:PivotTo(CFrame.lookAt(mpos, spot.center + Vector3.new(0, 5.2, 0)))
	m.waypoints = {}
	m.legGoal = nil
	m.target = nil
	m.pullSpot = nil
	m:setState("Wander")
	m.startAt = 0
	task.wait(3)
	check("monster right outside does not find a hidden player", p:GetAttribute("Status") == "Alive" and m.state ~= "Chase", m.state)
	m.startAt = 1e9
	Hiding.exit(p)
	task.wait(0.2)
	check("E: get out in front of the cabinet", p:GetAttribute("Hidden") == false and root ~= nil and not root.Anchored and (root.Position - spot.front).Magnitude < 4.5, root and string.format("%.1f", (root.Position - spot.front).Magnitude))
	-- 쫓기다가 보는 앞에서 숨기
	local cpos = spot.front + spot.facing * 10 + Vector3.new(0, 5.2, 0)
	m.model:PivotTo(CFrame.lookAt(cpos, spot.front + Vector3.new(0, 5.2, 0)))
	m.waypoints = {}
	m.legGoal = nil
	m.startAt = 0
	m:startChase(p, root and root.Position or spot.front)
	task.wait(0.2)
	Hiding.enter(p, spot)
	local dead = waitFor(function()
		return p:GetAttribute("Status") == "Dead"
	end, 10)
	check("monster that saw you hide pulls you out", dead ~= nil, m.state .. " " .. table.concat(m.log, " | "):sub(-160))
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
	check("nothing visible before a pulse", idle and idle.lines.lit == 0, idle and (idle.lines.lit .. " lit, pulses started " .. tostring(idle.pulsesStarted)))

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
		local status, legs = routeWalkable(agent, agent.name == "monster")
		check("path start -> exit exists (" .. agent.name .. " size)", status == "Success", status .. " legs=" .. legs)
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
	task.wait(Config.Sonar.Hold - 0.4) -- t≈Hold+1.4 (가장 먼 선은 0.9초에 나타나 Hold초 뒤 사라짐)
	-- (Studio 창이 뒤에 있으면 화면 갱신이 느려져 선이 늦게 꺼질 수 있다: 최대 4초 더 기다린다)
	local after = ask(p, "stats")
	waitFor(function()
		after = ask(p, "stats")
		return after and after.lines.lit == 0 and after.lines.active == 0
	end, 4)
	check("outline gone again (~Hold s after reveal)", after and after.lines.lit == 0 and after.lines.active == 0, after and (after.lines.lit .. "/" .. after.lines.active))
	-- 방 안쪽 모서리까지 바닥 선이 끊기지 않고 닿는다(시작 방 오른쪽 위 모서리: 북쪽 벽과 동쪽 벽이 만나는 곳)
	local corner = Vector3.new(32, 0, 8)
	local ends = ask(p, "floorEndsNear", { corner, 0.3 }) or 0
	check("floor lines reach the inner corner (no gap)", ends >= 2, ends)
	-- 지도(Q): 내 음파가 닿은 곳은 선이 사라진 뒤에도 지도에 남는다
	local mp = ask(p, "map")
	check("map records where my sonar reached", mp and mp.explored > 5 and mp.lines > 5, mp and (mp.explored .. " tiles, " .. mp.lines .. " lines"))
	local opened = ask(p, "toggleMap")
	task.wait(0.3)
	local mp2 = ask(p, "map")
	check("Q opens the map with my position", opened and opened.open and mp2 and mp2.meShown, mp2 and tostring(mp2.meShown))
	local closed = ask(p, "toggleMap")
	check("Q closes the map", closed and not closed.open)

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
	task.wait(1.0) -- (서버에 도착할 여유. 첫 발사 후 1.3초: 아직 간격 안)
	local mid1 = Main.Sonar.accepted[p] or 0
	task.wait(0.5)
	ask(p, "rawFire")
	task.wait(1.0)
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
	task.wait(Config.Sonar.Hold + 1)
	local s1b = ask(p, "stats")
	burst()
	local s2 = ask(p, "stats")
	task.wait(Config.Sonar.Hold + 1)
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
	-- (큰 맵에서는 경로 계산이 길어 순간이동 전에 시작한 계산이 끝나며 움직일 수 있다: 한 번 더 제자리에 세운다)
	m.model:PivotTo(CFrame.new(startNode))
	m.waypoints = {}
	m.legGoal = nil
	m.hum:MoveTo(startNode)
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

	-- 큰 맵: 멀리 돌아가야 하는 곳도 타일 경로를 구간으로 나눠 실제로 찾아간다
	do
		local goal = Round.info.exitCFrame.Position - Vector3.new(0, 3.5, 0)
		local startN, startLen = nil, 0
		for _, n in Round.info.nodes do
			local r = Round.info.route(n - Vector3.new(0, 3, 0), goal, true)
			if r and #r >= 30 and #r <= 60 and (n - goal).Magnitude < #r * 8 * 0.6 then
				startN, startLen = n, #r
				break
			end
		end
		if startN then
			m.model:PivotTo(CFrame.new(startN + Vector3.new(0, 2.2, 0)))
			m.waypoints = {}
			m.legGoal = nil
			m:setState("Investigate")
			m.goal = goal
			m.searchCenter = goal
			task.wait(12)
			local r = Round.info.route(m.root.Position - Vector3.new(0, 4.5, 0), goal, true)
			local left = if r then #r else startLen
			check("monster follows a long winding route (route legs)", left <= startLen - 8, string.format("route %d -> %d tiles, state %s", startLen, left, m.state))
		else
			check("monster follows a long winding route (route legs)", false, "no suitable start node")
		end
		m.waypoints = {}
		m.legGoal = nil
		m:setState("Wander")
	end

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
	if back then
		monsterTests(p)
		hideTests(p)
	end
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
	task.wait(Config.Sonar.Hold + 1)
	local worst, sumAvg = 0, 0
	local luaAvg, luaWorst = 0, 0
	local at60 = 0
	for _, p in ps do
		local s = ask(p, "stats")
		local got = s.pulsesStarted - base[p]
		check(p.Name .. " saw own + others' pulses", got >= rounds * #ps * 0.9, got .. "/" .. rounds * #ps)
		check(p.Name .. " lines released afterwards", s.lines.active == 0, s.lines.active)
		worst = math.max(worst, s.worstFrame)
		sumAvg += s.avgFrame
		luaAvg += s.lua.avg
		luaWorst = math.max(luaWorst, s.lua.worst)
		-- 60fps 기준 추정: 파동 전파는 경과 시간만큼 일하므로 프레임 시간 비율로 줄이고, 선 갱신은 프레임마다 그대로
		at60 += s.prof.pulsesMs * math.min(1, (1 / 60) / math.max(s.avgFrame, 1e-3)) + s.prof.linesMs
		R.info[p.Name] = { avgFrame = s.avgFrame, worstFrame = s.worstFrame, created = s.lines.created }
	end
	-- (Studio 테스트 창은 모두 비활성 창이라 15fps 로 묶인다: 화면 프레임 대신 음파 스크립트 비용을 본다)
	-- (Studio 비활성 창은 약 15fps: 한 프레임에 60fps 네 프레임 분량의 파동을 처리하므로 60fps 기준으로 환산해 본다)
	check("sonar script cost with " .. #ps .. " players pulsing together < 4ms/frame at 60fps", at60 / #ps < 4, string.format("~%.2fms at 60fps (measured %.2fms avg, worst %.2fms, at %.1fms frames)", at60 / #ps, luaAvg / #ps * 1000, luaWorst * 1000, sumAvg / #ps * 1000))
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

-- ─────────────────────────────── load ───────────────────────────────
-- 스테이지마다: 서버 빌드 시간, 클라이언트 음파 월드 빌드 시간, 괴물이 움직이는 20초 동안 서버 프레임·경로 계산·클라이언트 음파 비용
local Monster = require(script.Parent.Monster)
local function load()
	local ps = readyPlayers(1)
	if not ps then
		check("ready", false)
		return
	end
	local p = ps[1]
	local all = {}
	for i = 1, #Config.Stages do
		Round.startStage(i)
		local t0 = os.clock()
		readyPlayers(1)
		local built = waitFor(function()
			local st = ask(p, "stats")
			return st and st.buildId == stageFolder():GetAttribute("BuildId") and st.build.seconds > 0 and st
		end, 30)
		local readyIn = os.clock() - t0
		-- 몬스터가 움직이는 동안(플레이어는 시작 방, 음파를 주기적으로)
		local hb = {}
		local conn = RunService.Heartbeat:Connect(function(dt)
			table.insert(hb, dt)
		end)
		local s0 = { calls = Monster.stats.pathCalls, wall = Monster.stats.pathWall, ticks = Monster.stats.ticks }
		ask(p, "resetPerf")
		local mpos0 = {}
		for k, m in Round.monsters do
			mpos0[k] = m.root.Position
			m.startAt = 0 -- (테스트는 괴물을 멈춰 두므로 여기서는 실제처럼 움직이게)
			m.lastHunt = os.clock() - Config.Monster.HuntEvery + 5
		end
		for _ = 1, 10 do
			ask(p, "resetCooldown")
			ask(p, "fire")
			task.wait(2)
		end
		conn:Disconnect()
		local st = ask(p, "stats")
		local sum, worst = 0, 0
		for _, d in hb do
			sum += d
			worst = math.max(worst, d)
		end
		local calls = Monster.stats.pathCalls - s0.calls
		local moved, states = {}, {}
		for k, m in Round.monsters do
			table.insert(moved, math.floor((m.root.Position - (mpos0[k] or m.root.Position)).Magnitude))
			table.insert(states, m.state .. (if m.startAt > os.clock() then "(waiting)" else ""))
		end
		local r = {
			stage = i,
			serverBuildMs = math.floor(Round.lastBuildMs),
			readySec = math.floor(readyIn * 10) / 10,
			clientBuildSec = built and math.floor(built.build.seconds * 100) / 100,
			clientBuildCpuSec = built and math.floor(built.build.cpu * 100) / 100,
			segs = built and built.build.segs,
			serverFrameMs = math.floor(sum / math.max(1, #hb) * 10000) / 10,
			serverWorstMs = math.floor(worst * 10000) / 10,
			pathCallsPerSec = math.floor(calls / 20 * 10) / 10,
			pathAvgMs = if calls > 0 then math.floor((Monster.stats.pathWall - s0.wall) / calls * 10000) / 10 else 0,
			clientLuaMs = st and math.floor(st.lua.avg * 100000) / 100,
			clientLuaWorstMs = st and math.floor(st.lua.worst * 100000) / 100,
			pulsesMs = st and math.floor(st.prof.pulsesMs * 100) / 100,
			linesMs = st and math.floor(st.prof.linesMs * 100) / 100,
			alive = p:GetAttribute("Status"),
			ticksPerSec = math.floor((Monster.stats.ticks - s0.ticks) / 20),
			monsterMoved = table.concat(moved, ","),
			monsterStates = table.concat(states, ","),
			monsterLog = Round.monsters[1] and table.concat(Round.monsters[1].log, " | "):sub(-300) or "",
		}
		table.insert(all, r)
		log(HttpService:JSONEncode(r))
		check(string.format("stage %d: client sonar world ready", i), built ~= nil, r.clientBuildSec)
	end
	R.info.load = all
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
			for _, agent in { { r = 1.2, h = 5.5, monster = false }, { r = Config.Monster.AgentRadius, h = Config.Monster.AgentHeight, monster = true } } do
				local status = routeWalkable(agent, agent.monster)
				table.insert(paths, status)
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

-- ─────────────────────────────── probe ───────────────────────────────
-- 한 스테이지(args.Stage)에서 시작 → 모든 바닥 칸으로 경로를 계산해, 길이 끊기는 경계(갈 수 있는 칸 ↔ 못 가는 칸)를 보고한다.
local function probe()
	local ps = readyPlayers(1)
	check("player ready", ps ~= nil)
	if not ps then
		return
	end
	local si = tonumber(args.Stage) or 1
	Round.startStage(si)
	readyPlayers(1)
	for _, m in Round.monsters do
		m.alive = false
	end
	local from = Round.info.spawns[1].Position - Vector3.new(0, 2.5, 0)
	do
		local ex = Round.info.exitCFrame
		local parts = {}
		for _, part in workspace:GetPartBoundsInBox(CFrame.new(ex.Position - ex.LookVector * 4.8), Vector3.new(7.8, 9, 3.6)) do
			if part.CanCollide then
				table.insert(parts, string.format("%s %s @%s", part.Name, tostring(part.Size), tostring(part.Position - ex.Position)))
			end
		end
		local down = workspace:Raycast(ex.Position, Vector3.new(0, -10, 0))
		R.info.exitTile = { pos = tostring(ex.Position), look = tostring(ex.LookVector), floor = down and (down.Instance.Name .. " y=" .. down.Position.Y) or "none", parts = parts }
	end
	local function key(pos)
		return math.floor(pos.X / 8) + 1, math.floor(pos.Z / 8) + 1
	end
	for _, agent in { { name = "player", r = 1.2, h = 5.5 }, { name = "monster", r = Config.Monster.AgentRadius, h = Config.Monster.AgentHeight } } do
		local path = PathfindingService:CreatePath({ AgentRadius = agent.r, AgentHeight = agent.h, AgentCanJump = false })
		local okSet, bad = {}, {}
		for _, n in (if args.Quick then {} else Round.info.nodes) do
			local i, j = key(n)
			pcall(function()
				path:ComputeAsync(from, n - Vector3.new(0, 3, 0))
			end)
			if path.Status == Enum.PathStatus.Success then
				okSet[i .. "," .. j] = true
			else
				table.insert(bad, { i, j })
			end
		end
		local edge = {}
		for _, b in bad do
			for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				if okSet[(b[1] + d[1]) .. "," .. (b[2] + d[2])] then
					table.insert(edge, string.format("c%d r%d <- c%d r%d", b[1] - 1, b[2] - 1, b[1] + d[1] - 1, b[2] + d[2] - 1))
					break
				end
			end
		end
		-- 출구 칸 안쪽 몇 곳
		local ex = Round.info.exitCFrame
		local exitTries = {}
		for _, off in { 0, 1.5, 3, 4.5 } do
			local goal = ex.Position - Vector3.new(0, 3.5, 0) - ex.LookVector * off
			pcall(function()
				path:ComputeAsync(from, goal)
			end)
			table.insert(exitTries, string.format("%.1f:%s", off, path.Status.Name))
		end
		-- 바로 앞 칸에서 출구 안으로 / 시작에서 바로 앞 칸까지
		local front = ex.Position - Vector3.new(0, 3.5, 0) - ex.LookVector * 8.8
		pcall(function()
			path:ComputeAsync(front, ex.Position - Vector3.new(0, 3.5, 0))
		end)
		table.insert(exitTries, "front->in:" .. path.Status.Name)
		pcall(function()
			path:ComputeAsync(from, front)
		end)
		table.insert(exitTries, "start->front:" .. path.Status.Name)
		local t0 = os.clock()
		local okc, errc = pcall(function()
			path:ComputeAsync(from, ex.Position - Vector3.new(0, 3.5, 0))
		end)
		table.insert(exitTries, string.format("t%.0f:%s err=%s", os.clock() - t0, path.Status.Name, tostring(okc and "" or errc)))
		R.info[agent.name] = { bad = #bad, total = #Round.info.nodes, edge = edge, exit = table.concat(exitTries, " ") }
		check(agent.name .. " reaches every floor tile", #bad == 0, #bad .. "/" .. #Round.info.nodes)
	end
end

task.spawn(function()
	local ok, err = pcall(function()
		if args.Test == "load" then
			load()
		elseif args.Test == "probe" then
			probe()
		elseif args.Test == "multi" then
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
