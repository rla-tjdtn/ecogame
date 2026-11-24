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
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Round = require(script.Parent.Round)
local Doors = require(script.Parent.Doors)
local SoundBus = require(script.Parent.SoundBus)
local Hiding = require(script.Parent.Hiding)
local Search = require(script.Parent.Search)

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
-- 로비 테스트만 로비로, 나머지는 바로 게임으로 시작(Lobby.boot 가 읽는다)
ReplicatedStorage:SetAttribute("ForceMode", if args.Test == "lobby" then "Lobby" else "Game")
Config.Monster.StartDelay = 1e6
Config.Lives.PerStage = 1 -- (예전 테스트는 한 번 잡히면 죽는 것을 전제: lives 테스트에서만 3개)
Config.SafeZone.Enabled = false -- (예전 테스트는 시작 방에서 괴물을 시험한다: lives 테스트에서만 켠다)
Config.Flower.StartDelay = 1e6 -- (꽃괴물도 멈춰 둔다)
Config.Doppel.StartDelay = 1e6 -- (도플갱어도 멈춰 둔다: doppel 테스트에서만 움직인다)
Config.Key.Required = false -- (열쇠 시험은 core 에서 따로 켠다)
Config.Key.Count = 1 -- (예전 열쇠 시험은 열쇠 하나를 전제)
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
-- (from·to 를 주면 그 두 곳 사이: 맵 길찾기 검사 mapnav)
local function routeWalkable(agent, monster: boolean, fromPos: Vector3?, toPos: Vector3?): (string, number)
	local path = PathfindingService:CreatePath({ AgentRadius = agent.r, AgentHeight = agent.h, AgentCanJump = false })
	local from = fromPos or Round.info.spawns[1].Position - Vector3.new(0, 2.5, 0)
	local to = toPos or Round.info.exitCFrame.Position - Vector3.new(0, 3.5, 0)
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

-- ─────────────────────────────── 문 끼임 ───────────────────────────────
-- 문 바로 앞(예전에 문짝이 휘두르던 자리)에 서서 열고 지나간다 — 양쪽에서. 문짝은 여는 사람 반대쪽으로 열려야 한다
local function doorTests(p)
	local door = nil
	for _, d in Doors.all() do
		if (d.panel.Position - tile(5, 3, 4.5)).Magnitude < 4 then
			door = d
		end
	end
	if not door then
		check("door for the stuck test", false)
		return
	end
	local x0 = door.panel.Position.X
	for _, side in { -1, 1 } do
		if door.open then
			Doors.toggle(door)
			task.wait(1)
		end
		local from = Vector3.new(x0 + side * 2.2, 3, tile(5, 3).Z)
		local to = Vector3.new(x0 - side * 9, 3, tile(5, 3).Z)
		place(p, from, to)
		task.wait(0.4)
		Doors.toggle(door, p)
		task.wait(0.8)
		ask(p, "move", to)
		local crossed = waitFor(function()
			local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			return r and (r.Position.X - x0) * -side > 2.5
		end, 4)
		check(string.format("open a door standing right at it and walk through (%s side)", if side < 0 then "west" else "east"), crossed ~= nil)
	end
	if door.open then
		Doors.toggle(door)
	end
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
	if m.model:GetAttribute("Rig") == 4 then
		-- 3D 시안 괴물: 선 막대 대신 뼈 메시(시안 선 정점 색) + 음파에 드러날 때 흰 윤곽선. 메시·뼈·스킨이 붙어 있는가
		local meshes, bones, skinned = 0, 0, 0
		for _, d in m.model:GetDescendants() do
			if d:IsA("MeshPart") then
				meshes += 1
				if d.HasSkinnedMesh then
					skinned += 1
				end
			elseif d:IsA("Bone") then
				bones += 1
			end
		end
		check("monster body is a skinned 3D mesh (chapter creature)", meshes > 0 and bones > 10 and skinned > 0, string.format("%s meshes %d bones %d skinned %d", tostring(m.model:GetAttribute("Creature")), meshes, bones, skinned))
	else
		check("monster strokes draw as single lines (Line/Disc)", cyl > 10 and ok == cyl, ok .. "/" .. cyl)
	end
	local visible = 0
	for _, d in m.model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			visible += 1
		end
	end
	check("monster body is invisible (only sonar reveals it)", visible == 0, visible)
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
		-- (음파에 맞은 괴물은 굳은 선 대신 지금 모습 그대로 보인다: Reveal)
		local shown = ask(p, "reveal") or 0
		check("monster appears in the sonar as lines", n >= 15 or shown >= 1, string.format("lines %d, shown %d", n, shown))
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
	-- (구역을 맡은 괴물은 자기 구역 안의 플레이어에게만 다가간다: 플레이어가 구역 밖이면 다가가지 않는 게 맞다)
	local inZone = pr == nil or (m :: any).territory == nil or m:inTerritory(pr.Position)
	if inZone then
		check("wandering monster drifts toward a player now and then", goal ~= nil and gd >= 0 and gd <= Config.Monster.HuntRadius + 8, string.format("%.0f studs", gd))
	else
		check("wandering monster stays in its own zone (player is outside it)", goal == nil or m:inTerritory(goal), string.format("goal %s", tostring(goal)))
	end
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
	-- 1인칭 카메라 방향은 클라이언트가 정한다: 사물함을 바라보게(안내는 화면 안에 있을 때만 뜬다)
	local ui0 = nil
	waitFor(function()
		-- (순간이동 직후엔 카메라가 아직 옛 자리라, 자리를 잡을 때까지 다시 바라보게 한다)
		ask(p, "lookTarget", spot.center + Vector3.new(0, 3, 0))
		ui0 = ask(p, "stats")
		return ui0 ~= nil and ui0.ui.prompt == "E   숨기"
	end, 3)
	local nearDoor = math.huge
	for _, d in Doors.all() do
		nearDoor = math.min(nearDoor, ((d.prompt.Parent :: BasePart).Position - spot.front).Magnitude)
	end
	local pinfo = if not (ui0 and ui0.ui.prompt == "E   숨기") then ask(p, "prompts") else ""
	check("hide prompt shown near the cabinet", ui0 and ui0.ui.prompt == "E   숨기", string.format("%s | %s | tile %d,%d door %.1f enabled %s", ui0 and tostring(ui0.ui.prompt) or "no ui", tostring(pinfo), math.floor(spot.center.X / 8), math.floor(spot.center.Z / 8), nearDoor, tostring(spot.prompt.Enabled)))
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
	waitFor(function() s1b = ask(p, "stats") return s1b and s1b.lines.active == 0 end, 5) -- (Studio 창이 뒤에 있으면 선이 늦게 꺼진다)
	burst()
	local s2 = ask(p, "stats")
	task.wait(Config.Sonar.Hold + 1)
	local s3 = ask(p, "stats")
	waitFor(function() s3 = ask(p, "stats") return s3 and s3.lines.active == 0 end, 5)
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

	-- 발소리는 한 발짝씩: 걷기(10/초)로 16스터드 → 약 3발(파일 하나에 여러 발짝이 들어 있어 잘라서 한 발만)
	place(p, tile(2, 6, 3), tile(2, 8, 3))
	task.wait(0.4)
	local st0 = ask(p, "stats")
	ask(p, "move", tile(2, 8, 3))
	task.wait(2.2)
	local st1 = ask(p, "stats")
	local steps = (st1 and st0) and (st1.steps - st0.steps) or -1
	check("footsteps: about one sound per step while walking (~2 per second)", steps >= 2 and steps <= 5, steps)

	-- 실제 녹음 소리가 이 게임에서 불러와진다(라이선스 효과음)
	local sc = ask(p, "soundCheck")
	local zero = 0
	for _, l in (sc and sc.lengths) or {} do
		if l <= 0 then
			zero += 1
		end
	end
	check("licensed sounds load (screams + monster steps)", sc and #sc.bad == 0 and zero == 0, sc and (table.concat(sc.bad, ", ") .. " lengths " .. table.concat(sc.lengths, "/")))

	-- 점프: 뛰어오르고, 착지 소리를 괴물이 들을 수 있다
	do
		place(p, tile(2, 6, 3), tile(2, 8, 3))
		task.wait(0.6)
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local y0 = r and r.Position.Y or 0
		local n0 = #SoundBus.recent
		ask(p, "jump")
		local peak = y0
		local t0 = os.clock()
		while os.clock() - t0 < 1.4 do
			if r then
				peak = math.max(peak, r.Position.Y)
			end
			task.wait()
		end
		local landed = false
		for i = n0 + 1, #SoundBus.recent do
			if SoundBus.recent[i].kind == "StepLand" then
				landed = true
			end
		end
		check("players can jump", peak - y0 > 1.5, string.format("%.1f studs", peak - y0))
		check("landing makes a noise monsters can hear", landed)
	end

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
			task.wait(20) -- (조사 속도 5.5: 20초면 약 13칸)
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

	-- 12. 열쇠: 상자·서랍 중 한 곳에 있고, 없으면 출구가 잠겨 있다
	m.startAt = 1e9
	m:setState("Wander")
	Config.Key.Required = true
	local spotsZ = Search.all()
	check("searchable boxes/drawers built", #spotsZ >= 5, #spotsZ)
	local ks, ki = Search.keySpot()
	check("exactly one of them holds the key", ks ~= nil and ki ~= nil)
	place(p, Round.info.exitCFrame.Position + Vector3.new(0, -0.5, 0))
	task.wait(1.2)
	check("exit is locked without the key", p:GetAttribute("Status") == "Alive" and ReplicatedStorage:GetAttribute("HasKey") ~= true, p:GetAttribute("Status"))
	local kh0 = ask(p, "keyHud")
	check("key indicator shows no key", kh0 and kh0.visible and kh0.text:find("0/", 1, true) ~= nil, kh0 and kh0.text)
	local empty = nil
	for _, sp in spotsZ do
		if not sp.hasKey then
			empty = sp
			break
		end
	end
	if empty then
		place(p, empty.front + Vector3.new(0, 3, 0), empty.center + Vector3.new(0, 3, 0))
		task.wait(0.3)
		-- 서랍(뚜껑)마다 따로 열고 닫는다: 처음 열면 뒤짐(비어 있음), 닫고 다시 열 수 있다
		local r1 = Search.toggle(p, empty, 1)
		local r2 = Search.toggle(p, empty, 1)
		local r3 = Search.toggle(p, empty, 1)
		check("a drawer opens (empty), closes, and opens again", r1 == "empty" and r2 == "closed" and r3 == "opened", r1 .. "/" .. r2 .. "/" .. r3)
		local allOpen = true
		for i = 2, #empty.comps do
			Search.toggle(p, empty, i)
		end
		for _, c in empty.comps do
			allOpen = allOpen and c.open
		end
		check("every drawer of a cabinet can be opened", allOpen, #empty.comps)
		local fwd = (empty.front - empty.center).Unit
		local c1 = empty.comps[1]
		local moved = c1.model:GetPivot().Position - c1.closedPivot.Position
		check("an opened drawer/lid moves toward the player, not sideways", (moved:Dot(fwd) > 0.4 or moved.Y > 0.4) and math.abs(moved:Dot(Vector3.new(fwd.Z, 0, -fwd.X))) < 0.2, string.format("fwd %.2f side %.2f up %.2f", moved:Dot(fwd), moved:Dot(Vector3.new(fwd.Z, 0, -fwd.X)), moved.Y))
		for i = 1, #empty.comps do
			Search.toggle(p, empty, i)
		end
		local allClosed = true
		for _, c in empty.comps do
			allClosed = allClosed and not c.open
		end
		check("every drawer closes again", allClosed)
		-- 조준점으로 보고 E(클라이언트 경로)
		local c1pos = c1.model:GetPivot().Position
		place(p, c1pos + fwd * 3.2 + Vector3.new(0, 1.2, 0), c1pos)
		task.wait(0.6)
		local tgt = ask(p, "lookTarget", c1pos)
		check("crosshair on a drawer targets it", tgt ~= nil and tgt.spot == empty.id, tgt and (tgt.spot .. ":" .. tgt.comp))
		local wasOpen = tgt and empty.comps[tgt.comp].open
		ask(p, "useLook", c1pos)
		local toggled = waitFor(function()
			return tgt and empty.comps[tgt.comp].open ~= wasOpen
		end, 3)
		check("E while looking opens/closes that drawer", toggled ~= nil)
	end
	if ks and ki then
		place(p, ks.front + Vector3.new(0, 3, 0))
		task.wait(0.3)
		local r3 = Search.toggle(p, ks, ki)
		check("searching the right one finds the key (whole team)", r3 == "key" and ReplicatedStorage:GetAttribute("HasKey") == true, r3)
		task.wait(0.4)
		local kh1 = ask(p, "keyHud")
		check("key indicator shows the key", kh1 and kh1.text:find("출구로", 1, true) ~= nil, kh1 and kh1.text)
	end

	-- 13. 출구 → 탈출 → STAGE CLEAR
	place(p, Round.info.exitCFrame.Position + Vector3.new(0, -0.5, 0))
	local esc = waitFor(function()
		return p:GetAttribute("Status") == "Escaped"
	end, 3)
	check("reaching the exit escapes", esc ~= nil, p:GetAttribute("Status"))
	Config.Key.Required = false
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
	local js = waitFor(function()
		local x = ask(p, "jumpscare")
		return x and x.count > 0 and x
	end, 2)
	check("jump scare: the monster face pops up when caught", js ~= nil, js and js.count)
	task.wait(1.8)
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
		doorTests(p)
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
		for _, d in Round.doppels do
			d.startAt = 0 -- (도플갱어도 사람 모습으로 돌아다니게)
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

-- ─────────────────────────────── aibench (괴물 AI·몸 움직임 비용) ───────────────────────────────
-- env STAGE=n(없으면 6~10). 챕터마다 두 구간을 잰다:
--   wander: 플레이어는 시작 방(안전 구역), 괴물은 배회·사냥 / chase: 3초마다 플레이어를 괴물 10~18스터드 앞 배회 지점으로 옮긴다(추격·문·계단)
-- 서버: 괴물 tick CPU(경로 계산 대기 제외), 경로 계산 수·평균, 프레임마다 잡기·animate, 시야 레이 수, 서버 Heartbeat 시간
-- 클라이언트: MonsterAnim(Perf "monsterAnim") 프레임당 ms, 프레임 시간. 잡혀도 측정이 끊기지 않게 onCatch 는 세기만 한다
local function aibench()
	local Stats = game:GetService("Stats")
	local function r2(v)
		return math.floor((v or 0) * 100 + 0.5) / 100
	end
	local ps = readyPlayers(1)
	check("player ready", ps ~= nil)
	if not ps then
		return
	end
	local p = ps[1]
	local only = tonumber(args.Stage) or 0
	local secs = if args.Quick then 10 else 20
	local acc = { tick = 0, ticks = 0, catch = 0, anim = 0, hbN = 0, los = 0, hbMs = 0 }
	local origTick, origCatch, origAnim, origLos = Monster.tick, Monster.checkCatch, Monster.animate, Monster.lineOfSight
	Monster.tick = function(self)
		local t = os.clock()
		local w0 = Monster.stats.pathWall
		origTick(self)
		acc.tick += (os.clock() - t) - (Monster.stats.pathWall - w0)
		acc.ticks += 1
	end
	Monster.checkCatch = function(self)
		local t = os.clock()
		origCatch(self)
		acc.catch += os.clock() - t
	end
	Monster.animate = function(self, dt)
		local t = os.clock()
		origAnim(self, dt)
		acc.anim += os.clock() - t
	end
	Monster.lineOfSight = function(self, pos)
		acc.los += 1
		return origLos(self, pos)
	end
	local hbConn = RunService.Heartbeat:Connect(function()
		acc.hbN += 1
		acc.hbMs += Stats.HeartbeatTimeMs
	end)
	local rows = {}
	for i = 6, #Config.Stages do
		if only > 0 and i ~= only then
			continue
		end
		Round.startStage(i)
		task.wait(1)
		ps = readyPlayers(1)
		if not ps then
			check("stage " .. i .. " ready", false)
			continue
		end
		local all = {}
		local catches = 0
		for _, list in { Round.monsters, Round.doppels, Round.flowers } do
			for _, m in list do
				m.startAt = 0
				m.onCatch = function()
					catches += 1
				end
				table.insert(all, m)
			end
		end
		local function phase(name, chase)
			if not chase then
				place(p, Round.info.spawns[1].Position)
			end
			task.wait(2)
			for k in acc do
				acc[k] = 0
			end
			catches = 0
			local s0 = { calls = Monster.stats.pathCalls, wall = Monster.stats.pathWall }
			local pos0, stuck0 = {}, {}
			for k, m in all do
				pos0[k] = m.root.Position
				stuck0[k] = 0
				m.log = {}
			end
			ask(p, "perfx", "reset")
			local t0 = os.clock()
			local chases, moved = 0, 0
			local lastMove = 0
			local travel = {}
			for k in all do
				travel[k] = 0
			end
			local prev = table.clone(pos0)
			while os.clock() - t0 < secs do
				if chase and os.clock() - lastMove >= 3 then
					lastMove = os.clock()
					-- 한 괴물(돌아가며) 앞 10~18스터드의 배회 지점(같은 층)으로
					local m = all[(moved % #all) + 1]
					moved += 1
					if m and m.root then
						local mp = m.root.Position
						for _, n in Round.info.nodes do
							local d = (n - mp).Magnitude
							if d > 10 and d < 18 and math.abs(n.Y - mp.Y) < 4 and not Round.inSafe(n) then
								place(p, n + Vector3.new(0, 0.5, 0))
								break
							end
						end
					end
				end
				task.wait(0.5)
				for k, m in all do
					if m.state == "Chase" then
						chases += 1
					end
					travel[k] += (m.root.Position - prev[k]).Magnitude
					prev[k] = m.root.Position
				end
			end
			local dur = os.clock() - t0
			local x = ask(p, "perfx", "reset") or {}
			local sys = x.sys or {}
			local ma = sys.monsterAnim or {}
			local calls = Monster.stats.pathCalls - s0.calls
			local stuckN, trav, states = 0, {}, {}
			for k, m in all do
				for _, l in m.log do
					if l:find("stuck") then
						stuckN += 1
					end
				end
				table.insert(trav, math.floor(travel[k]))
				table.insert(states, m.state)
			end
			local row = {
				stage = i,
				phase = name,
				monsters = #all,
				tickMsPerSec = r2(acc.tick / dur * 1000),
				tickAvgUs = r2(acc.tick / math.max(1, acc.ticks) * 1e6),
				ticksPerSec = r2(acc.ticks / dur),
				pathPerSec = r2(calls / dur),
				pathAvgMs = if calls > 0 then r2((Monster.stats.pathWall - s0.wall) / calls * 1000) else 0,
				catchUsPerFrame = r2(acc.catch / math.max(1, acc.hbN) * 1e6),
				animUsPerFrame = r2(acc.anim / math.max(1, acc.hbN) * 1e6),
				losPerSec = r2(acc.los / dur),
				serverHbMs = r2(acc.hbMs / math.max(1, acc.hbN)),
				clientAnimMsPerFrame = math.floor((ma.perFrameMs or 0) * 1000 + 0.5) / 1000,
				clientAnimWorstMs = r2(ma.worstMs or 0),
				clientFrameMs = r2(x.avgMs),
				clientP99Ms = r2(x.p99Ms),
				chaseSamples = chases,
				stuckEvents = stuckN,
				catches = catches,
				travel = table.concat(trav, ","),
				states = table.concat(states, ","),
			}
			table.insert(rows, row)
			log(HttpService:JSONEncode(row))
		end
		phase("wander", false)
		phase("chase", true)
	end
	hbConn:Disconnect()
	Monster.tick, Monster.checkCatch, Monster.animate, Monster.lineOfSight = origTick, origCatch, origAnim, origLos
	check("aibench rows", #rows > 0, #rows)
	R.info.aibench = rows
end

-- ─────────────────────────────── lobby (2인) ───────────────────────────────
-- 로비에서 시작 → 음파로 로비가 보인다 → P1 방 만들기(버튼) → P2 참가(버튼)·나가기·재참가 → 방장만 시작 →
-- 두 사람 모두 1스테이지 → 함께 탈출해 2스테이지 → 마지막 스테이지를 깨면 로비로 돌아온다
local function lobbyTest()
	local LobbyMod = require(script.Parent.Lobby)
	local want = tonumber(args.Players) or 2
	local ps = waitFor(function()
		local all = Players:GetPlayers()
		if #all < want or Round.state ~= "Lobby" then
			return nil
		end
		for _, q in all do
			if q:GetAttribute("Status") ~= "Alive" or not (q.Character and q.Character:FindFirstChild("HumanoidRootPart")) then
				return nil
			end
		end
		return all
	end, 60)
	check("server starts in the lobby with everyone inside", ps ~= nil, Round.state .. " " .. #Players:GetPlayers())
	if not ps then
		return
	end
	local p1, p2 = ps[1], ps[2]
	local function built(p)
		return waitFor(function()
			local st = ask(p, "stats")
			return st and st.buildId == stageFolder():GetAttribute("BuildId") and st.build.segs > 0 and st
		end, 25)
	end
	local b1, b2 = built(p1), built(p2)
	check("both clients see the lobby through sonar (outlines built)", b1 ~= nil and b2 ~= nil and b1.build.segs > 100, b1 and b1.build.segs)
	check("no monsters in the lobby", #Round.monsters == 0, #Round.monsters)
	task.wait(0.5)
	ask(p1, "resetCooldown")
	ask(p1, "fire")
	task.wait(1.2)
	local lit = ask(p1, "stats")
	check("sonar lights up the lobby", lit and lit.lines.lit > 50, lit and lit.lines.lit)
	-- 작은 로비: 음파 한 번으로 방 거의 전부(벽 아닌 칸의 90% 이상)가 닿아야 한다(지도에 기록된 칸으로 잰다)
	do
		local rows = string.split(stageFolder():GetAttribute("Rows"), "/")
		local open = 0
		for _, row in rows do
			for k = 1, #row do
				if string.sub(row, k, k) ~= "#" then
					open += 1
				end
			end
		end
		local mp = nil
		waitFor(function()
			mp = ask(p1, "map")
			return mp ~= nil and mp.explored >= open * 0.9
		end, 6)
		check("one sonar pulse shows almost the whole lobby (>= 90% of tiles)", mp ~= nil and mp.explored >= open * 0.9, string.format("%s/%d tiles", tostring(mp and mp.explored), open))
	end
	local u = ask(p1, "lobby")
	check("room panel shown in the lobby", u and u.visible and table.find(u.buttons, "방 만들기") ~= nil, u and table.concat(u.buttons, ","))
	local c0 = ask(p1, "cursor")
	check("cursor hidden while looking around", c0 == false, tostring(c0))
	local m = ask(p1, "lobbyMenu", true)
	check("Tab menu frees the mouse", m and m.mouseFree == true)
	task.wait(0.2)
	local c1 = ask(p1, "cursor")
	check("cursor shown only while the menu is open", c1 == true, tostring(c1))
	ask(p1, "lobbyClick", "방 만들기")
	local id = waitFor(function()
		return p1:GetAttribute("RoomId")
	end, 5)
	check("P1 creates a room (button)", id ~= nil, tostring(id))
	local joinText = "참가 " .. tostring(id)
	-- 친구만: 방장이 켜면 친구가 아닌 P2 는 못 들어오고, 끄면 들어온다
	ask(p1, "lobbyClick", "친구만 켜기")
	waitFor(function()
		local x = ask(p1, "lobby")
		return x and table.find(x.buttons, "친구만 끄기") ~= nil
	end, 5)
	waitFor(function()
		local x = ask(p2, "lobby")
		return x and table.find(x.buttons, joinText) ~= nil
	end, 5)
	ask(p2, "lobbyClick", joinText)
	task.wait(1)
	local fm = ask(p2, "lobby")
	check("friends-only room keeps non-friends out", p2:GetAttribute("RoomId") == nil and fm and fm.message:find("친구", 1, true) ~= nil, fm and fm.message)
	ask(p1, "lobbyClick", "친구만 끄기")
	waitFor(function()
		local x = ask(p1, "lobby")
		return x and table.find(x.buttons, "친구만 켜기") ~= nil
	end, 5)
	local inv = ask(p1, "lobby")
	check("invite-friends button in the lobby", inv and table.find(inv.buttons, "친구 초대") ~= nil, inv and table.concat(inv.buttons, ","))
	local seen = waitFor(function()
		local x = ask(p2, "lobby")
		return x and x.rooms == 1 and table.find(x.buttons, joinText) ~= nil and x
	end, 5)
	check("P2 sees the room with a join button", seen ~= nil, seen and table.concat(seen.buttons, ","))
	ask(p2, "lobbyClick", joinText)
	check("P2 joins the room (button)", waitFor(function()
		return p2:GetAttribute("RoomId") == id
	end, 5) ~= nil)
	local u1 = waitFor(function()
		local x = ask(p1, "lobby")
		return x and x.title:find(p2.DisplayName, 1, true) and x
	end, 5)
	check("P1 sees P2 in the room", u1 ~= nil, u1 and u1.title)
	local u2 = ask(p2, "lobby")
	check("only the host has a start button", u1 and table.find(u1.buttons, "시작") ~= nil and u2 and table.find(u2.buttons, "시작") == nil, u2 and table.concat(u2.buttons, ","))
	ask(p2, "lobbyClick", "나가기")
	check("P2 can leave the room", waitFor(function()
		return p2:GetAttribute("RoomId") == nil
	end, 5) ~= nil)
	waitFor(function()
		local x = ask(p2, "lobby")
		return x and table.find(x.buttons, joinText) ~= nil
	end, 5)
	ask(p2, "lobbyClick", joinText)
	check("P2 joins again", waitFor(function()
		return p2:GetAttribute("RoomId") == id
	end, 5) ~= nil)
	LobbyMod.act(p2, "start")
	task.wait(0.8)
	check("a non-host cannot start", Round.state == "Lobby", Round.state)
	-- 방장이 시작
	task.wait(0.5)
	ask(p1, "lobbyClick", "시작")
	local started = waitFor(function()
		return Round.state == "Playing" and Round.stageIndex == 1
	end, 20)
	check("host presses start: stage 1 begins", started ~= nil, Round.state)
	local both = waitFor(function()
		for _, q in { p1, p2 } do
			if q:GetAttribute("Status") ~= "Alive" or not (q.Character and q.Character:FindFirstChild("HumanoidRootPart")) then
				return nil
			end
		end
		return true
	end, 15)
	check("both players are in stage 1", both ~= nil, tostring(p1:GetAttribute("Status")) .. "/" .. tostring(p2:GetAttribute("Status")))
	check("stage 1 has its monsters", #Round.monsters == Config.Stages[1].Monsters, #Round.monsters)
	local g1, g2 = built(p1), built(p2)
	check("both clients rebuilt sonar for stage 1", g1 ~= nil and g2 ~= nil and g1.build.segs > 20000, g1 and g1.build.segs)
	local lu = ask(p1, "lobby")
	check("room panel hidden during the game", lu and not lu.visible)
	task.wait(0.5)
	ask(p2, "resetCooldown")
	ask(p2, "fire")
	task.wait(1.2)
	local lit2 = ask(p2, "stats")
	check("P2's sonar works in the game", lit2 and lit2.lines.lit > 50, lit2 and lit2.lines.lit)
	-- 팀원은 음파 없이도 실제 아바타 윤곽선으로 보인다
	local mt1 = waitFor(function()
		local n = ask(p1, "mates")
		return n == 1 and n
	end, 5)
	local mt2 = ask(p2, "mates")
	check("teammates always shown as an outline of their avatar", mt1 == 1 and mt2 == 1, tostring(mt1) .. "/" .. tostring(mt2))
	-- 시야 공유: P2 의 음파가 P1 의 지도에도 남고, 지도에 팀원이 보인다
	local mp1 = nil
	waitFor(function()
		mp1 = ask(p1, "map")
		return mp1 ~= nil and mp1.explored > 5
	end, 8)
	check("teammate's echo is recorded on my map", mp1 and mp1.explored > 5, mp1 and mp1.explored)
	ask(p1, "toggleMap")
	task.wait(0.4)
	local mp1b = ask(p1, "map")
	check("teammate shown on my map", mp1b and mp1b.matesShown == 1, mp1b and mp1b.matesShown)
	ask(p1, "toggleMap")
	-- 함께 탈출 → 2스테이지
	for _, q in { p1, p2 } do
		place(q, Round.info.exitCFrame.Position + Vector3.new(0, -0.5, 0))
	end
	local next2 = waitFor(function()
		return Round.state == "Playing" and Round.stageIndex == 2 and p1:GetAttribute("Status") == "Alive" and p2:GetAttribute("Status") == "Alive"
	end, 20)
	check("both escape stage 1 together and play stage 2", next2 ~= nil, Round.state .. " " .. Round.stageIndex)
	-- 마지막 스테이지를 깬 것으로 하고 탈출 → 로비로(시작 지점에 세워지기를 기다린 뒤)
	task.wait(2)
	Round.stageIndex = #Config.Stages
	for _, q in { p1, p2 } do
		place(q, Round.info.exitCFrame.Position + Vector3.new(0, -0.5, 0))
	end
	local back = waitFor(function()
		return Round.state == "Lobby" and p1:GetAttribute("Status") == "Alive" and p2:GetAttribute("Status") == "Alive"
	end, 20)
	check("after the last stage both return to the lobby", back ~= nil, Round.state)
	check("rooms are cleared after the game", next(LobbyMod.rooms) == nil and p1:GetAttribute("RoomId") == nil)
	local lu2 = waitFor(function()
		local x = ask(p1, "lobby")
		return x and x.visible and x
	end, 5)
	check("room panel is back in the lobby", lu2 ~= nil)
end

-- ─────────────────────────────── dense ───────────────────────────────
-- 음파로 보여 줄 게 가장 많은 곳(스테이지마다 반경 안 파트가 가장 많은 바닥 칸)에서 음파를 계속 쏴 최악의 프레임을 잰다
local function dense()
	local ps = readyPlayers(1)
	if not ps then
		check("ready", false)
		return
	end
	local p = ps[1]
	local out = {}
	local only = tonumber(args.Stage) or 0
	for i = 1, #Config.Stages do
		if only == 0 or only == i then
			Round.startStage(i)
			readyPlayers(1)
			waitFor(function()
				local st = ask(p, "stats")
				return st and st.buildId == stageFolder():GetAttribute("BuildId") and st.build.segs > 0
			end, 30)
			-- 가장 빽빽한 곳
			local best, bn = nil, -1
			local params = OverlapParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { stageFolder() }
			for k, n in Round.info.nodes do
				if k % 3 == 0 then
					local c = #workspace:GetPartBoundsInRadius(n, 30, params)
					if c > bn then
						best, bn = n, c
					end
				end
			end
			place(p, best + Vector3.new(0, 0, 0), best + Vector3.new(1, 0, 0))
			task.wait(1)
			ask(p, "resetPerf")
			for _ = 1, 8 do
				ask(p, "resetCooldown")
				ask(p, "fire")
				task.wait(Config.Sonar.Cooldown + 0.05)
			end
			task.wait(1)
			local st = ask(p, "stats")
			local r = { stage = i, parts = bn, luaAvg = math.floor(st.lua.avg * 100000) / 100, luaWorst = math.floor(st.lua.worst * 100000) / 100, frameWorst = math.floor(st.worstFrame * 10000) / 10, created = st.lines.created, stolen = st.lines.stolen, active = st.lines.active, pulsesMs = st.prof.pulsesMs, linesMs = st.prof.linesMs, segs = st.build.segs, maxColor = st.lines.maxColor, maxPlace = st.lines.maxPlace, dropped = st.lines.dropped }
			table.insert(out, r)
			log(HttpService:JSONEncode(r))
			check(string.format("stage %d dense spot: sonar worst frame cost < 8ms", i), r.luaWorst < 8, string.format("avg %.2f worst %.2f ms, created %d stolen %d dropped %d", r.luaAvg, r.luaWorst, r.created, r.stolen, st.lines.dropped or 0))
		end
	end
	R.info.dense = out
end

-- ─────────────────────────────── chase ───────────────────────────────
-- 스테이지마다: 메인 괴물이 쫓아올 때 그 스테이지 동작(팔 자세·튀어나가기)으로 실제로 다가오는가
local function chaseMotion()
	local ps = readyPlayers(1)
	if not ps then
		check("ready", false)
		return
	end
	local p = ps[1]
	-- 쫓아올 때 팔 각도가 이만큼은 돼야 그 동작이다(1 머리 위로 휘젓기, 2 원으로 휘두르기, 3·5 앞으로 짚기, 4 팔 늘어짐 + 무릎 높이)
	local armMin = { 1.8, 1.5, 0.6, 0, 0.5 }
	for i = 1, 5 do
		-- (앞 스테이지에서 잡혔으면 되살아날 때까지 기다린 뒤 다음 스테이지)
		waitFor(function()
			return Round.state == "Playing" and p:GetAttribute("Status") == "Alive"
		end, 20)
		Round.startStage(i)
		readyPlayers(1)
		waitFor(function()
			return p:GetAttribute("Status") == "Alive"
		end, 15)
		task.wait(1)
		ask(p, "anim", "all")
		waitFor(function()
			local s = ask(p, "anim")
			return s and (s.bodies or 0) >= #Round.monsters
		end, 8)
		local m = Round.monsters[1]
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not m or not root then
			check(string.format("stage %d: monster and player ready", i), false)
			continue
		end
		-- 안전 구역 밖에서 20~35스터드 떨어진 두 지점
		local pPos, mPos
		for _, a in m.nodes do
			if not Monster.isSafe(a) then
				for _, b in m.nodes do
					local d = (a - b).Magnitude
					if d > 20 and d < 35 and not Monster.isSafe(b) then
						pPos, mPos = a, b
						break
					end
				end
			end
			if pPos then
				break
			end
		end
		if not pPos or not mPos then
			check(string.format("stage %d: found a spot to test the chase", i), false)
			continue
		end
		place(p, pPos + Vector3.new(0, 3, 0), mPos)
		m.model:PivotTo(CFrame.lookAt(mPos + Vector3.new(0, 5, 0), pPos + Vector3.new(0, 5, 0)))
		m.waypoints = {}
		m.startAt = 0
		task.wait(0.3)
		ask(p, "anim", "all")
		local rig4 = m.model:GetAttribute("Rig") == 4
		local cid = m.model:GetAttribute("Creature")
		if rig4 then
			-- 3D 시안 괴물은 음파에 드러난 동안만 뼈를 움직인다: 쫓기 직전에 음파
			ask(p, "creature", "reset")
			ask(p, "pulseAt", root.Position + Vector3.new(0, 1.5, 0))
		end
		m:startChase(p, root.Position)
		local d0 = (m.root.Position - root.Position).Magnitude
		local armMax, legMax, sMin, sMax = 0, 0, math.huge, 0
		local caught = false
		for _ = 1, 35 do
			task.wait(0.1)
			for _, j in m.joints do
				local _, ang = (j.base:Inverse() * j.motor.C0):ToAxisAngle()
				if j.amp > 0.4 then
					legMax = math.max(legMax, math.abs(ang))
				else
					armMax = math.max(armMax, math.abs(ang))
				end
			end
			sMin, sMax = math.min(sMin, m.hum.WalkSpeed), math.max(sMax, m.hum.WalkSpeed)
			if p:GetAttribute("Status") ~= "Alive" then
				caught = true
				break
			end
		end
		local r2 = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local d1 = if r2 then (m.root.Position - r2.Position).Magnitude else 0
		check(string.format("stage %d: chasing monster closes in (%s)", i, m.state), caught or d1 < d0 - 6, string.format("%.0f -> %.0f studs%s", d0, d1, if caught then ", caught" else ""))
		if rig4 then
			-- 3D 시안 괴물: 디자인의 추격 자세로 뼈가 움직이고(추격 비율), 실제 이동 거리로 걸음이 나며, 디자인별 추격 속도로 꾸준히 쫓는다
			local st = ask(p, "creature", cid) or {}
			check(string.format("stage %d: %s chases with its own 3D chase pose", i, tostring(cid)), (st.frames or 0) > 10 and (st.chaseMax or 0) > 0.5 and (st.steps or 0) >= 2, string.format("frames %s chaseW %.2f steps %s bones %s", tostring(st.frames), st.chaseMax or 0, tostring(st.steps), tostring(st.bones)))
			local cs = m.cfg.ChaseSpeed
			check(string.format("stage %d: %s chase speed steady at its own %.0f", i, tostring(cid), cs), math.abs(sMax - cs) < 0.01, string.format("%.1f ~ %.1f", sMin, sMax))
			continue
		end
		-- 전신 동작(클라이언트 측정): 1 팔을 머리 위로, 2 줄에 당겨지듯 몸이 크게 오르내림, 3·5 상체를 숙이고 손으로 땅을 짚음, 4 무릎을 높이 듦
		local a = ask(p, "anim") or {}
		local own = if i == 1 then (a.arm or 0) > 1.6
			elseif i == 2 then (a.pelvisRange or 0) > 0.12
			elseif i == 4 then (a.lift or 0) > 0.3
			else (a.lean or 0) > 0.7 and (a.handSteps or 0) > 0
		check(string.format("stage %d: chase uses its own full-body motion", i), own and (a.steps or 0) >= 2, string.format("arm %.2f lean %.2f lift %.2f pelvis %.2f handSteps %s steps %s", a.arm or 0, a.lean or 0, a.lift or 0, a.pelvisRange or 0, tostring(a.handSteps), tostring(a.steps)))
		check(string.format("stage %d: feet stay planted while chasing", i), (a.slip or 99) < 0.25, string.format("max %.3f studs", a.slip or -1))
		local _ = armMin[i] + armMax + legMax
		local lunge = i == 1 or i == 3 or i == 4
		check(string.format("stage %d: chase speed %s", i, if lunge then "lunges and pauses" else "steady"), if lunge then (sMax > Config.Monster.ChaseSpeed * 1.2 and sMin < Config.Monster.ChaseSpeed * 0.7) else math.abs(sMax - Config.Monster.ChaseSpeed) < 0.01, string.format("%.1f ~ %.1f", sMin, sMax))
	end
end

-- ─────────────────────────────── walk ───────────────────────────────
-- 괴물이 실제로 돌아다니는가: 60초 동안 1초마다 위치를 재서 이동 거리·멈춰 있던 시간을 본다(플레이어는 숨겨 둔다)
local function walk()
	local ps = readyPlayers(1)
	if not ps then
		check("ready", false)
		return
	end
	local p = ps[1]
	local si = tonumber(args.Stage) or 1
	if si ~= Round.stageIndex then
		Round.startStage(si)
		readyPlayers(1)
	end
	local spot = Hiding.all()[1]
	if spot then
		Hiding.enter(p, spot)
	end
	local seconds = tonumber(args.Seconds) or 60
	for _, m in Round.monsters do
		m.startAt = 0
	end
	local track = {}
	for k, m in Round.monsters do
		track[k] = { last = m.root.Position, dist = 0, still = 0, states = {}, swing = 0 }
	end
	ask(p, "anim", "all")
	for _ = 1, seconds do
		task.wait(1)
		for k, m in Round.monsters do
			local t = track[k]
			local pos = m.root.Position
			local d = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(t.last.X, 0, t.last.Z)).Magnitude
			t.dist += d
			if d < 0.5 and m.state ~= "Alert" then
				t.still += 1
			end
			t.last = pos
			t.states[m.state] = (t.states[m.state] or 0) + 1
			local j = m.joints[1]
			if j then
				local _, ang = (j.base:Inverse() * j.motor.C0):ToAxisAngle()
				t.swing = math.max(t.swing, math.abs(ang))
			end
		end
	end
	local out = {}
	for k, m in Round.monsters do
		local t = track[k]
		local st = {}
		for name, n in t.states do
			table.insert(st, name .. "=" .. n)
		end
		table.insert(out, { dist = math.floor(t.dist), still = t.still, states = table.concat(st, " "), log = table.concat(m.log, " | "):sub(-400) })
		check(string.format("monster %d keeps moving (%ds)", k, seconds), t.dist > seconds * Config.Monster.WanderSpeed * 0.4 and t.still < seconds * 0.35, string.format("%d studs, still %ds", math.floor(t.dist), t.still))
	end
	-- 전신 움직임(클라이언트): 발을 디디고 걷는다(디딘 발은 미끄러지지 않는다), 골반이 오르내리고 척추가 비틀린다, 발소리는 발이 닿을 때
	local a = ask(p, "anim") or {}
	local n = #Round.monsters
	check("monsters are animated with the full-body rig", (a.bodies or 0) >= n, tostring(a.bodies))
	check("monsters take real steps (feet lift and land)", (a.steps or 0) >= n * seconds * 0.6, string.format("%s steps", tostring(a.steps)))
	check("planted feet do not slide", (a.slip or 99) < 0.2, string.format("max %.3f studs", a.slip or -1))
	check("pelvis rises and falls with each step (weight)", (a.pelvisRange or 0) > 0.08, string.format("%.2f studs", a.pelvisRange or 0))
	check("spine twists against the pelvis while walking", (a.chestYaw or 0) > 0.02, string.format("%.3f rad", a.chestYaw or 0))
	check("monster footstep sounds play when a foot lands", (a.footSounds or 0) > 0, tostring(a.footSounds))
	R.info.anim = a
	R.info.walk = out
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
		-- (아바타 애니메이션 로드 실패는 도플갱어가 친구 아바타를 입을 때 나는 로블록스 쪽 오류: 빌드 실패로 세지 않는다)
		local buildErrs = {}
		for k = errBefore + 1, #R.errors do
			if not string.find(R.errors[k], "animation", 1, true) then
				table.insert(buildErrs, R.errors[k])
			end
		end
		check(string.format("stage %d built and player spawned", i), ok ~= nil and #buildErrs == 0, Config.Stages[i].Name .. (if #buildErrs > 0 then " | " .. buildErrs[1] else ""))
		if ok then
			local st = ask(p, "stats")
			local paths = {}
			for _, agent in { { r = 1.2, h = 5.5, monster = false }, { r = Config.Monster.AgentRadius, h = Config.Monster.AgentHeight, monster = true } } do
				local status = routeWalkable(agent, agent.monster)
				table.insert(paths, status)
			end
			check(string.format("stage %d: start -> exit walkable (player, monster)", i), paths[1] == "Success" and paths[2] == "Success", table.concat(paths, ","))
			-- 시안 괴물 챕터는 메인 + 서브 전부, 아니면 예전 메인 괴물 수
			local cl = Round.chapterCreatures()
			local wantM = if cl then #cl else Config.Stages[i].Monsters
			check(string.format("stage %d: %d monster(s)%s", i, wantM, if cl then " (chapter creatures)" else ""), #Round.monsters == wantM, #Round.monsters)
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

-- 맵 길찾기(레벨 디자인 검사): 스테이지마다 실제 길찾기(PathfindingService + 타일 경로 구간)로
-- 시작 → 모든 뒤지는 곳(Z) 앞(플레이어), 출구 → 모든 Z 앞(괴물: 어디든 쫓아올 수 있는가), 괴물 배회 지점 아무 곳 12쌍(괴물, 2층 포함)
local function mapNav()
	local ps = readyPlayers(1)
	check("player ready", ps ~= nil)
	if not ps then
		return
	end
	local only = tonumber(args.Stage) or 0
	for i = 1, #Config.Stages do
		if only ~= 0 and i ~= only then
			continue
		end
		local errBefore = #R.errors
		Round.startStage(i)
		if not readyPlayers(1) then
			check("stage " .. i .. " ready", false)
			continue
		end
		-- 짓는 동안 난 오류(괴물 애니메이션 에셋 로드 실패는 맵과 상관없어서 뺀다)
		local errs = {}
		for k = errBefore + 1, #R.errors do
			if not string.find(R.errors[k], "animation", 1, true) then
				table.insert(errs, R.errors[k])
			end
		end
		local stage = workspace:FindFirstChild("Stage")
		check(string.format("stage %d built without map errors (parts %s)", i, tostring(stage and stage:GetAttribute("PartCount"))), #errs == 0, table.concat(errs, " | "))
		local player = { r = 1.2, h = 5.5 }
		local monster = { r = Config.Monster.AgentRadius, h = Config.Monster.AgentHeight }
		local exitPos = Round.info.exitCFrame.Position - Vector3.new(0, 3.5, 0)
		local fails, mfails, n = {}, {}, 0
		local upperSpots = 0
		for _, spot in Search.all() do
			n += 1
			local to = spot.front + Vector3.new(0, 0.5, 0)
			if to.Y > 9 then
				upperSpots += 1
			end
			local st = routeWalkable(player, false, nil, to)
			if st ~= "Success" then
				table.insert(fails, string.format("Z(%d,%d,%s):%s", math.floor(to.X / 8), math.floor(to.Z / 8), if to.Y > 9 then "2F" else "1F", st))
			end
			local ms = routeWalkable(monster, true, exitPos, to)
			if ms ~= "Success" then
				table.insert(mfails, string.format("Z(%d,%d):%s", math.floor(to.X / 8), math.floor(to.Z / 8), ms))
			end
			task.wait()
		end
		check(string.format("stage %d: player can walk start -> every search spot (%d, 2F %d)", i, n, upperSpots), #fails == 0 and n > 0, table.concat(fails, " "))
		check(string.format("stage %d: monster can walk exit -> every search spot", i), #mfails == 0, table.concat(mfails, " "))
		local nodes = Round.info.nodes
		local bad, upper = {}, 0
		for k = 1, 12 do
			local a = nodes[((k * 7919) % #nodes) + 1] - Vector3.new(0, 3, 0)
			local b = nodes[((k * 104729 + 13) % #nodes) + 1] - Vector3.new(0, 3, 0)
			if a.Y > 9 or b.Y > 9 then
				upper += 1
			end
			local ms = routeWalkable(monster, true, a, b)
			if ms ~= "Success" then
				table.insert(bad, string.format("(%d,%d)->(%d,%d):%s", math.floor(a.X / 8), math.floor(a.Z / 8), math.floor(b.X / 8), math.floor(b.Z / 8), ms))
			end
			task.wait()
		end
		check(string.format("stage %d: monster roams between 12 random node pairs (%d touch 2F)", i, upper), #bad == 0, table.concat(bad, " "))
	end
end

-- 스테이지마다 아무 곳 12군데에서 음파를 쏴 본다(실패하면 이유·위치)
local function sonarAll()
	local ps = readyPlayers(1)
	if not ps then
		check("player ready", false)
		return
	end
	local p = ps[1]
	for i = 1, #Config.Stages do
		Round.startStage(i)
		if not readyPlayers(1) then
			check("stage " .. i .. " ready", false)
			continue
		end
		waitFor(function()
			local s = ask(p, "lastFail")
			return s and s.ready
		end, 20)
		local m = Round.monsters[1]
		local fails, lowLit = {}, {}
		for k = 1, 12 do
			local pos = if m then m:randomNode(nil) else Round.info.spawns[1].Position
			place(p, pos + Vector3.new(0, 3, 0))
			task.wait(0.35)
			ask(p, "resetCooldown")
			local ok = ask(p, "fire")
			if not ok then
				local why = ask(p, "lastFail")
				table.insert(fails, string.format("(%.0f,%.0f,%.0f):%s", pos.X, pos.Y, pos.Z, why and tostring(why.fail or ("ready=" .. tostring(why.ready) .. " st=" .. tostring(why.status))) or "?"))
			else
				task.wait(1.0)
				local s2 = ask(p, "stats")
				if not s2 or s2.lines.lit < 30 then
					table.insert(lowLit, string.format("(%.0f,%.0f,%.0f):lit=%s", pos.X, pos.Y, pos.Z, s2 and tostring(s2.lines.lit) or "?"))
				end
			end
		end
		check(string.format("stage %d: sonar fires at 12 random spots", i), #fails == 0, table.concat(fails, " "))
		check(string.format("stage %d: sonar shows lines at those spots", i), #lowLit == 0, table.concat(lowLit, " "))
	end
end

-- ─────────────────────────────── doppel ───────────────────────────────
-- 도플갱어: 스테이지마다 한 마리(사람 모습) → 음파·가까이서 보면 들킴 → 5~10초 뒤 터지며 괴물 → 추격·잡기(도플갱어 점프스케어)
local function doppelTest()
	local ps = readyPlayers(1)
	check("player ready", ps ~= nil)
	if not ps then
		return
	end
	local p = ps[1]
	local D = Config.Doppel
	-- 스테이지마다 한 마리, 사람 모습, 메인 괴물 수는 그대로
	for i = 1, #Config.Stages do
		Round.startStage(i)
		readyPlayers(1)
		local d = Round.doppels[1]
		local boxes = 0
		if d then
			for _, c in d.model:GetDescendants() do
				if c:IsA("BasePart") and CollectionService:HasTag(c, Config.Tags.Renderable) and (c:FindFirstAncestor("Disguise") or c:GetAttribute("DisguisePart") or (c.Parent and c.Parent:GetAttribute("DisguisePart"))) then
					boxes += 1
				end
			end
		end
		local dist = d and (d.root.Position - Round.info.spawns[1].Position).Magnitude or -1
		-- (괴물 수: 시안 괴물 챕터는 메인 + 서브 전부, 아니면 예전 메인 괴물 수)
		local cl = Round.chapterCreatures()
		local wantM = if cl then #cl else Config.Stages[i].Monsters
		check(string.format("stage %d: one doppelganger in player form (other monsters still %d)", i, wantM), #Round.doppels == D.PerStage and d ~= nil and d.form == "Disguise" and boxes >= 6 and #Round.monsters == wantM and CollectionService:HasTag(d.model, Config.Tags.Doppel), string.format("doppels=%d form=%s boxes=%d monsters=%d", #Round.doppels, d and d.form or "-", boxes, #Round.monsters))
		check(string.format("stage %d: doppelganger spawns %d~%d studs from the start", i, D.SpawnDistance[1], D.SpawnDistance[2]), dist >= D.SpawnDistance[1] - 6 and dist <= D.SpawnDistance[2] + 6, string.format("%.0f", dist))
	end
	-- 진짜 사람(친구 또는 플레이어)의 아바타로 갈아입는다
	do
		local dd = Round.doppels[1]
		local dressed = dd and waitFor(function()
			return dd.model:GetAttribute("AvatarOf") ~= nil
		end, 12)
		check("doppelganger wears a real avatar (a friend, or a player)", dressed ~= nil and dd.tracks ~= nil, dd and tostring(dd.model:GetAttribute("AvatarOf")))		-- 들키기 전에도 몸이 보인다(투명하지 않은 아바타 파트)
		local shown, total = 0, 0
		if dd then
			for _, c in dd.model:GetChildren() do
				if c:GetAttribute("DisguisePart") and c:IsA("BasePart") then
					total += 1
					if c.Transparency < 1 then
						shown += 1
					end
				end
			end
		end
		check("disguise avatar is visible before any sonar", total > 0 and shown == total, string.format("%d/%d", shown, total))
		-- 가짜 음파: 진짜 음파처럼 클라이언트에 SonarPulse 로 간다
		local before = dd and dd.model:GetAttribute("FakePing")
		if dd then
			dd:fakeSonar()
		end
		check("doppelganger fires a fake sonar pulse", dd ~= nil and dd.model:GetAttribute("FakePing") ~= before)
	end
	-- 1스테이지 시작 방에서: 플레이어 tile(2,2), 도플갱어 tile(4,4) (약 23스터드: 보이는 거리 밖, 음파 거리 안)
	Round.startStage(1)
	readyPlayers(1)
	local d = Round.doppels[1]
	if not d then
		return
	end
	d.startAt = 0
	local pPos = tile(2, 2, 3)
	place(p, pPos, tile(4, 4, 3))
	local function putDoppel(pos: Vector3)
		d.model:PivotTo(CFrame.lookAt(pos, Vector3.new(pPos.X, pos.Y, pPos.Z)))
		d.waypoints = {}
		d.pauseUntil = os.clock() + 30 -- (제자리에 서 있게)
	end
	putDoppel(tile(4, 4, 3))
	task.wait(1.5)
	check("doppelganger far away (out of sight range) is not discovered yet", d.discoveredBy == nil and d.form == "Disguise", tostring(d.discoveredBy))
	-- 사람 모습도 음파에 윤곽선으로 보인다 + 음파를 쏘면 들킨다
	ask(p, "resetCooldown")
	ask(p, "fire")
	local found = waitFor(function()
		return d.discoveredBy ~= nil
	end, 3)
	local wait0 = d.transformAt - os.clock()
	check("sonar reveals the doppelganger: discovered", found ~= nil and d.discoveredBy == p, tostring(d.discoveredBy))
	check(string.format("transforms %d~%d s after being discovered", D.TransformDelay[1], D.TransformDelay[2]), wait0 > D.TransformDelay[1] - 1.5 and wait0 <= D.TransformDelay[2] + 0.1, string.format("%.1f s", wait0))
	task.wait(1.2)
	local shownNow = ask(p, "reveal")
	-- (진짜 친구 아바타를 입은 도플갱어는 팀원처럼 늘 윤곽선으로 보인다(Reveal.disguised): 음파 목록 대신 몸이 실제로 보이는지)
	local rv = ask(p, "revealedModel", d.model)
	local avatar = d.model:GetAttribute("AvatarOf") ~= nil
	check("sonar hit: the player-shaped doppelganger stays visible as it is (no frozen afterimage)", (shownNow and shownNow >= 1) or (avatar and rv ~= nil and rv.visible > 0), string.format("shown %s avatar %s visibleParts %s", tostring(shownNow), tostring(avatar), tostring(rv and rv.visible)))
	local fx0 = ask(p, "doppelFx")
	-- 변신: 사람 모습이 터지고(조각) 괴물 몸으로
	local turned = waitFor(function()
		return d.form == "Beast"
	end, D.TransformDelay[2] + 3)
	task.wait(0.4)
	local fx1 = ask(p, "doppelFx")
	local beast = d.model:FindFirstChild("Beast")
	local eyes, lineParts = 0, 0
	if beast then
		for _, c in beast:GetChildren() do
			if c:IsA("BasePart") then
				if c.Name == "Eye" then
					eyes += 1
				end
				if CollectionService:HasTag(c, Config.Tags.Renderable) then
					lineParts += 1
				end
			end
		end
	end
	check("transforms into the monster (player body gone, beast body with 2 eyes)", turned ~= nil and d.model:FindFirstChild("Disguise") == nil and beast ~= nil and eyes == 2, string.format("form=%s eyes=%d lines=%d", d.form, eyes, lineParts))
	check("the player body bursts into flying pieces on screen", fx1 and fx0 and fx1.bursts == fx0.bursts + 1 and fx1.shards >= 50, fx1 and string.format("bursts %d->%d shards=%d", fx0 and fx0.bursts or -1, fx1.bursts, fx1.shards))
	check("bursting plays the doppelganger's own burst sound (flesh rip + bone crack)", fx1 and fx0 and fx1.sounds == fx0.sounds + 1, fx1 and string.format("sounds %s->%s", tostring(fx0 and fx0.sounds), tostring(fx1.sounds)))
	do
		local near = false
		for _, e in Players:GetPlayers() do
			local r = e.Character and e.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r and (r.Position - d.root.Position).Magnitude <= D.TransformNear + 3 then
				near = true
			end
		end
		check(string.format("transforms only with a player within %d studs", D.TransformNear), turned ~= nil and near, tostring(near))
	end
	check("monster body is drawn with single strokes (lines and discs)", lineParts > 60 and lineParts < 160, lineParts)
	local chasing = waitFor(function()
		return d.state == "Chase" and d.target == p
	end, D.BurstPause + 2)
	check("after bursting it chases the player who found it", chasing ~= nil, d.state)
	check("doppelganger monster is smaller than the main monster", d.hum.HipHeight < 4 and d.cfg.ChaseSpeed == Config.Doppel.ChaseSpeed, string.format("hip %.1f speed %.1f", d.hum.HipHeight, d.cfg.ChaseSpeed))
	-- 음파에 맞으면 눈이 빛난다(선보다 조금 더 오래)
	putDoppel(tile(4, 4, 3))
	d.startAt = os.clock() + 4 -- (잠깐 세워 둔다)
	ask(p, "resetCooldown")
	ask(p, "fire")
	local lit = waitFor(function()
		local f = ask(p, "doppelFx")
		return f and f.eyes >= 2 and f
	end, 3)
	check("sonar makes its eyes glow", lit ~= nil, lit and lit.eyes)
	-- 덮칠 때 세로 입이 벌어지고, 잡히면 도플갱어 점프스케어
	d.startAt = 0
	d:startChase(p, pPos)
	local opened = waitFor(function()
		return d.model:GetAttribute("MawOpen") == true
	end, 8)
	check("its head-to-belly split opens into a mouth when it lunges", opened ~= nil, tostring(d.model:GetAttribute("MawOpen")))
	local dead = waitFor(function()
		return p:GetAttribute("Status") == "Dead"
	end, 8)
	local js = ask(p, "jumpscare")
	check("caught by the doppelganger -> death with its own jump scare", dead ~= nil and js and js.kind == "doppel", js and tostring(js.kind))
	-- 가까이서 보면(음파 없이) 들킨다
	waitFor(function()
		return Round.state == "Playing" and p:GetAttribute("Status") == "Alive" and Round.doppels[1] ~= nil and Round.doppels[1] ~= d
	end, 20)
	readyPlayers(1)
	local d2 = Round.doppels[1]
	if d2 then
		d2.startAt = 0
		place(p, pPos, tile(3, 3, 3))
		d2.model:PivotTo(CFrame.lookAt(tile(3, 3, 3), pPos))
		d2.waypoints = {}
		d2.pauseUntil = os.clock() + 30
		local seen = waitFor(function()
			return d2.discoveredBy == p
		end, 3)
		check("seeing it up close (no sonar) also gives it away", seen ~= nil, tostring(d2.discoveredBy))
	end
	-- 사람 모습일 때는 플레이어를 잡지 않는다
	Round.startStage(1)
	readyPlayers(1)
	local d3 = Round.doppels[1]
	if d3 then
		d3.startAt = 0
		place(p, pPos, tile(3, 3, 3))
		d3.model:PivotTo(CFrame.lookAt(pPos + Vector3.new(2, 0, 0), pPos))
		task.wait(1.5)
		check("in player form it never kills", p:GetAttribute("Status") == "Alive" and d3.form == "Disguise", p:GetAttribute("Status") .. " " .. d3.form)
	end
end

-- ─────────────────────────────── lives ───────────────────────────────
-- 목숨 3개(스테이지마다) + 시작 방 안전 구역
local function livesTest()
	local ps = readyPlayers(1)
	check("player ready", ps ~= nil)
	if not ps then
		return
	end
	local p = ps[1]
	Config.Lives.PerStage = 3
	Config.SafeZone.Enabled = true
	Round.startStage(1)
	readyPlayers(1)
	local stage = stageFolder()
	local safeCount = #string.split((stage:GetAttribute("SafeTiles") :: string?) or "", ";")
	check("start room is a safe zone (stage 1: 3x3 room)", safeCount == 9 and stage:FindFirstChild("SafeZone") ~= nil, safeCount)
	check("3 lives at the start of a stage", p:GetAttribute("Lives") == 3, p:GetAttribute("Lives"))
	local hud = ask(p, "keyHud")
	check("lives shown on screen (3 hearts)", hud and hud.lives and select(2, string.gsub(hud.lives, "♥", "")) == 3, hud and hud.lives)
	-- 안전 구역 안: 화면에 표시, 괴물이 바로 옆에 와도 잡지 않고 밖으로 나간다
	local inside = tile(2, 2, 3)
	place(p, inside, tile(4, 4, 3))
	local safeShown = waitFor(function()
		local h = ask(p, "keyHud")
		return h and h.safe
	end, 3)
	check("'safe zone' shown while in the start room", safeShown ~= nil)
	local m = Round.monsters[1]
	m.model:PivotTo(CFrame.new(tile(3, 3, 5.2)))
	m.waypoints = {}
	m.startAt = 0
	task.wait(2.5)
	check("monster in the safe zone does not catch or chase the player", p:GetAttribute("Status") == "Alive" and not (m.state == "Chase" and m.target == p), p:GetAttribute("Status") .. " " .. m.state)
	local left = waitFor(function()
		return not Round.inSafe(m.root.Position)
	end, 8)
	check("monster leaves the safe zone on its own", left ~= nil, tostring(m.root.Position))
	-- 쫓기다 안전 구역으로 들어가면 추격을 멈춘다
	local outside = tile(7, 3, 3)
	place(p, outside, tile(9, 3, 3))
	m.model:PivotTo(CFrame.new(tile(10, 3, 5.2)))
	m.waypoints = {}
	m:startChase(p, outside)
	task.wait(0.3)
	place(p, inside, tile(4, 4, 3))
	local dropped = waitFor(function()
		return m.target ~= p and m.state ~= "Chase"
	end, 3)
	check("chase stops when the player reaches the safe zone", dropped ~= nil, m.state)
	m.startAt = 1e9
	-- 잡히면 목숨 하나 잃고 시작 방에서 다시(점프스케어)
	local js0 = ask(p, "jumpscare")
	place(p, outside, tile(9, 3, 3))
	m.model:PivotTo(CFrame.new(outside + Vector3.new(1.5, 2.2, 0)))
	m.startAt = 0
	m:startChase(p, outside)
	local lost = waitFor(function()
		return p:GetAttribute("Status") == "Respawning"
	end, 6)
	m.startAt = 1e9
	m.model:PivotTo(CFrame.new(tile(20, 20, 5.2)))
	check("caught with lives left -> lose one life (not dead)", lost ~= nil and p:GetAttribute("Lives") == 2, tostring(p:GetAttribute("Status")) .. " lives=" .. tostring(p:GetAttribute("Lives")))
	local js1 = ask(p, "jumpscare")
	check("jump scare still plays when a life is lost", js1 and js0 and js1.count == js0.count + 1, js1 and js1.count)
	local back = waitFor(function()
		local r = root(p)
		return p:GetAttribute("Status") == "Alive" and r and Round.inSafe(r.Position)
	end, Config.Lives.RespawnDelay + 6)
	check("respawns in the start room after a moment", back ~= nil, tostring(p:GetAttribute("Status")))
	check("the stage keeps going (not restarted)", Round.state == "Playing" and Round.stageIndex == 1, Round.state)
	local hud2 = ask(p, "keyHud")
	check("hearts drop to 2", hud2 and hud2.lives and select(2, string.gsub(hud2.lives, "♥", "")) == 2, hud2 and hud2.lives)
	-- 두 번 더 잡히면 아웃(마지막 목숨)
	Round.kill(p, "monster")
	waitFor(function()
		return p:GetAttribute("Status") == "Alive"
	end, Config.Lives.RespawnDelay + 6)
	check("second catch: 1 life left", p:GetAttribute("Lives") == 1, p:GetAttribute("Lives"))
	Round.kill(p, "monster")
	check("last life lost -> dead", p:GetAttribute("Status") == "Dead" and p:GetAttribute("Lives") == 0, tostring(p:GetAttribute("Status")))
	-- (혼자면 스테이지 다시 시작) 다시 시작하면 목숨이 다시 3개
	local again = waitFor(function()
		return Round.state == "Playing" and p:GetAttribute("Status") == "Alive"
	end, 25)
	check("new attempt / stage refills lives to 3", again ~= nil and p:GetAttribute("Lives") == 3, p:GetAttribute("Lives"))
	Config.Lives.PerStage = 1
	Config.SafeZone.Enabled = false
end

-- ─────────────────────────────── reveal ───────────────────────────────
-- 음파에 맞은 괴물은 어그로가 풀릴 때까지(다시 배회할 때까지) 계속 보인다
local function revealTest()
	local ps = readyPlayers(1)
	check("player ready", ps ~= nil)
	if not ps then
		return
	end
	local p = ps[1]
	Round.startStage(1)
	readyPlayers(1)
	local catch0 = Config.Monster.CatchDistance
	Config.Monster.CatchDistance = -1 -- (이 테스트에서는 잡지 않게)
	local m = Round.monsters[1]
	local pPos = tile(2, 2, 3)
	place(p, pPos, tile(4, 4, 3))
	m.model:PivotTo(CFrame.new(tile(4, 4, 5.2)))
	m.waypoints = {}
	m.startAt = 0
	task.wait(0.5)
	check("monster not shown before any sonar", ask(p, "reveal") == 0, ask(p, "reveal"))
	ask(p, "resetCooldown")
	ask(p, "fire")
	m:startChase(p, pPos)
	local shown = waitFor(function()
		return (ask(p, "reveal") or 0) >= 1
	end, 3)
	check("sonar hit: the monster becomes visible", shown ~= nil, ask(p, "reveal"))
	-- 음파 선이 사라진 뒤에도(배회해도) 10초 동안은 지금 모습 그대로 보인다
	m.startAt = 1e9
	m.target = nil
	m:setState("Wander")
	task.wait(Config.Sonar.Hold + 2.5)
	check("still visible (live) after the sonar lines fade, within 10 s", (ask(p, "reveal") or 0) >= 1, ask(p, "reveal"))
	local hidden = waitFor(function()
		return ask(p, "reveal") == 0
	end, Config.Sonar.MonsterRevealSeconds)
	check("invisible again about 10 s after the hit", hidden ~= nil, ask(p, "reveal"))
	-- 음파 범위 밖의 괴물은 드러나지 않는다
	m.model:PivotTo(CFrame.new(tile(30, 30, 5.2)))
	m.startAt = 0
	m:startChase(p, pPos)
	ask(p, "resetCooldown")
	ask(p, "fire")
	task.wait(1.5)
	check("a monster out of sonar range is not revealed", ask(p, "reveal") == 0, ask(p, "reveal"))
	m.startAt = 1e9
	m:setState("Wander")
	-- 도플갱어: 음파에 들키면(사람 모습) 계속 보인다
	local d = Round.doppels[1]
	if d then
		d.startAt = 0
		d.model:PivotTo(CFrame.lookAt(tile(4, 4, 3), pPos))
		d.waypoints = {}
		d.pauseUntil = os.clock() + 30
		task.wait(0.3)
		ask(p, "resetCooldown")
		ask(p, "fire")
		local dshown = waitFor(function()
			return d.discoveredBy ~= nil and (ask(p, "reveal") or 0) >= 1
		end, 3)
		task.wait(Config.Sonar.Hold + 0.5)
		check("discovered doppelganger stays visible (player form)", dshown ~= nil and (ask(p, "reveal") or 0) >= 1 and d.form == "Disguise", string.format("%s %s", tostring(ask(p, "reveal")), d.form))
		d.startAt = 1e9
	end
	Config.Monster.CatchDistance = catch0
end

-- ─────────────────────────────── mobile ───────────────────────────────
-- 휴대폰 화면 버튼: 휴대폰 모드에서 로비·스테이지에 맞는 버튼이 보이는가
local function mobileTest()
	local ps = readyPlayers(1)
	check("player ready", ps ~= nil)
	if not ps then
		return
	end
	local p = ps[1]
	local pc = ask(p, "mobile")
	check("PC: no phone buttons", pc and pc.enabled == false, pc and tostring(pc.enabled))
	local st = ask(p, "mobile", true)
	local b = st and table.concat(st.buttons, ",") or ""
	check("phone in a stage: sonar, run, crouch, map buttons", st and st.enabled and b:find("Sonar") and b:find("Run") and b:find("Crouch") and b:find("Map") ~= nil, b)
	Round.enterLobby()
	readyPlayers(1)
	task.wait(1)
	local lb = ask(p, "mobile", true)
	local lbs = lb and table.concat(lb.buttons, ",") or ""
	check("phone in the lobby: sonar and room menu buttons", lb and lbs:find("Sonar") and lbs:find("Menu") ~= nil, lbs)
	ask(p, "mobile", false)
end

-- ─────────────────────────────── seal ───────────────────────────────
-- 스테이지 1~5 를 지어, 실제로 만들어진 벽·바닥에 구멍이 없는지 광선으로 확인한다:
--   바닥 칸마다 아래로(바닥이 있나), 벽 칸 쪽으로(그 벽이 실제로 막고 있나),
--   두 벽이 만나는 모서리 너머가 바닥이면 대각선으로(모서리 틈으로 빠져나갈 수 없나)
local function seal()
	local ps = readyPlayers(1)
	check("player ready", ps ~= nil)
	if not ps then
		return
	end
	local FLOOR = { ["."] = true, S = true, E = true, D = true, A = true, p = true, w = true, b = true, n = true, s = true }
	for i = 1, #Config.Stages do
		Round.startStage(i)
		readyPlayers(1)
		task.wait(1)
		local s = workspace.Stage:GetAttribute("Rows")
		local rows = string.split(s, "/")
		local H, W = #rows, #rows[1]
		local function at(x, y)
			if y < 1 or y > H or x < 1 or x > W then
				return "#"
			end
			return string.sub(rows[y], x, x)
		end
		local params = RaycastParams.new()
		local chars = {}
		for _, pl in Players:GetPlayers() do
			if pl.Character then
				table.insert(chars, pl.Character)
			end
		end
		for _, m in Round.monsters do
			if m.model then
				table.insert(chars, m.model)
			end
		end
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = chars
		params.RespectCanCollide = true
		local noFloor, gaps, corner, tiles = {}, {}, {}, 0
		for y = 1, H do
			for x = 1, W do
				local c = at(x, y)
				if FLOOR[c] then
					tiles += 1
					local o = Vector3.new((x - 1) * 8 + 4, 3, (y - 1) * 8 + 4)
					if not workspace:Raycast(o, Vector3.new(0, -40, 0), params) then
						table.insert(noFloor, string.format("r%dc%d%s", y - 1, x - 1, c))
					end
					for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
						if at(x + d[1], y + d[2]) == "#" then
							for _, h in { 1, 3, 6 } do
								local o2 = Vector3.new(o.X, h, o.Z)
								if not workspace:Raycast(o2, Vector3.new(d[1], 0, d[2]) * 6, params) then
									table.insert(gaps, string.format("r%dc%d->(%d,%d)@%d", y - 1, x - 1, d[1], d[2], h))
									break
								end
							end
						end
					end
					for _, d in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
						if at(x + d[1], y) == "#" and at(x, y + d[2]) == "#" and at(x + d[1], y + d[2]) ~= "#" then
							-- (선 하나는 두 벽 블록이 맞닿은 모서리 선을 정확히 지나갈 수 있어, 몸 크기쯤 되는 공으로 굴려 본다)
							if not workspace:Spherecast(o, 0.6, Vector3.new(d[1], 0, d[2]) * 8, params) then
								table.insert(corner, string.format("r%dc%d->(%d,%d)", y - 1, x - 1, d[1], d[2]))
							end
						end
					end
				end
			end
		end
		local function first(t)
			return table.concat(t, " ", 1, math.min(#t, 8))
		end
		check(string.format("stage %d: every floor tile has a floor under it (%d tiles)", i, tiles), #noFloor == 0, first(noFloor))
		check(string.format("stage %d: walls really block (no gaps beside floor)", i), #gaps == 0, first(gaps))
		check(string.format("stage %d: no leaks through wall corners", i), #corner == 0, first(corner))
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
					-- 원인 찾기: 바로 옆 칸에서 가까이 다시 계산(먼 거리 탐색 한계인지), 그 칸 안의 부딪히는 파트
					local c0 = Vector3.new((b[1] - 1) * 8 + 4, 0, (b[2] - 1) * 8 + 4)
					local c1 = Vector3.new((b[1] + d[1] - 1) * 8 + 4, 0, (b[2] + d[2] - 1) * 8 + 4)
					pcall(function()
						path:ComputeAsync(c1 + Vector3.new(0, 0.5, 0), c0 + Vector3.new(0, 0.5, 0))
					end)
					local near = path.Status.Name
					local parts = {}
					for _, part in workspace:GetPartBoundsInBox(CFrame.new(c0 + Vector3.new(0, 3, 0)), Vector3.new(7.6, 5, 7.6)) do
						if part.CanCollide and not part:IsDescendantOf(Players) and #parts < 4 then
							table.insert(parts, part.Name)
						end
					end
					table.insert(edge, string.format("c%d r%d <- c%d r%d near:%s [%s]", b[1] - 1, b[2] - 1, b[1] + d[1] - 1, b[2] + d[2] - 1, near, table.concat(parts, ",")))
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

local function flowerSpot()
	-- 꽃괴물은 Config.Flower.Stages(하수도)에만, 그 스테이지에선 맵 한가운데쯤(시작점에서 떨어진 곳)에 나오는지
	for i = 1, #Config.Stages do
		local want = table.find(Config.Flower.Stages, Config.Stages[i].Id) ~= nil
		for _ = 1, (if want then 3 else 1) do
			Round.startStage(i)
			task.wait(0.5)
			if not want then
				check("stage " .. i .. " has no flower", #Round.flowers == 0, tostring(#Round.flowers))
				break
			end
			local info = Round.info
			local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
			for _, n in info.nodes do
				x0, x1 = math.min(x0, n.X), math.max(x1, n.X)
				z0, z1 = math.min(z0, n.Z), math.max(z1, n.Z)
			end
			local size = math.max(x1 - x0, z1 - z0)
			local f = Round.flowers[1]
			if not f then
				check("stage " .. i .. " flower exists", false)
				break
			end
			local fp = f.root.Position
			local mid = math.sqrt((fp.X - (x0 + x1) / 2) ^ 2 + (fp.Z - (z0 + z1) / 2) ^ 2)
			local fromStart = (fp - info.spawns[1].Position).Magnitude
			check("stage " .. i .. " flower near map middle", mid <= size * 0.2 and fromStart >= 90,
				string.format("toMid %.0f (map %.0f) fromStart %.0f", mid, size, fromStart))
		end
	end
end

-- 챕터 시안 괴물(env CREATURE=챕터 번호): 전원 생성 · 구역 나눔 · 음파에 그림이 보임 · 움직임/걸음 · 서브 기믹
local function creatureTest()
	local chapter = tonumber(args.Creature)
	local def = chapter and Config.Creatures.Chapters[chapter]
	check("chapter given", def ~= nil, tostring(args.Creature))
	if not def or not chapter then
		return
	end
	local Monster = require(script.Parent.Monster)
	for _, id in def.main do
		check("module " .. id, Monster.creatureModule(id) ~= nil)
	end
	for _, id in def.sub do
		check("module " .. id, Monster.creatureModule(id) ~= nil)
	end
	local stageIdx = nil
	for i, st in Config.Stages do
		if st.Id == chapter then
			stageIdx = i
		end
	end
	local ps = readyPlayers(1)
	if not ps then
		check("player ready", false)
		return
	end
	local p = ps[1]
	Round.startStage(stageIdx)
	readyPlayers(1)
	local ready = Round.chapterCreatures()
	check("chapter has ready (uploaded) creatures", ready ~= nil, if ready then #ready .. " ready" else "none ready (fallback to old monsters)")
	if not ready then
		return
	end
	local want = #ready
	local found: { [string]: any } = {}
	waitFor(function()
		table.clear(found)
		local n = 0
		for _, mm in Round.monsters do
			-- (개체 이름: 같은 디자인 여러 마리(10장 뜬눈 3마리)도 따로 센다)
			local id = mm.model:GetAttribute("CreatureId") or mm.model:GetAttribute("Creature")
			if typeof(id) == "string" then
				found[id] = mm
				n += 1
			end
		end
		return n >= want
	end, 20)
	local n = 0
	local zones: { [number]: boolean } = {}
	local zoneDup = false
	for id, mm in found do
		n += 1
		local z = mm.model:GetAttribute("Zone")
		if zones[z] then
			zoneDup = true
		end
		zones[z] = true
		check(id .. " Rig 4 + starts in own zone", mm.model:GetAttribute("Rig") == 4 and mm:inTerritory(mm.root.Position), tostring(mm.root.Position))
	end
	check("all chapter creatures spawned", n == want, n .. "/" .. want)
	check("one zone each", not zoneDup)
	-- 각 괴물 앞에서 음파 → 그 괴물 그림이 보이고 걷는다
	ask(p, "creature", "reset")
	local results = {}
	for id, mm in found do
		mm.startAt = os.clock() + 1e6 -- (테스트 동안 스스로 생각하지 않게: 아래에서 직접 걷게 한다)
		local at = mm.root.Position
		-- 플레이어 자리: 괴물에서 6~16 스터드, 벽에 가리지 않는 이동 지점(벽 속·벽 너머에 세우지 않는다)
		local spot, walkTo = nil, nil
		local info = Round.info :: any
		for _, n in info.nodes do
			local d = (n - at).Magnitude
			if d >= 6 and d <= 16 and math.abs(n.Y - at.Y) < 6 and mm:lineOfSight(n + Vector3.new(0, 1, 0)) then
				if not spot then
					spot = n
				elseif not walkTo and (n - spot).Magnitude > 8 then
					walkTo = n
				end
			end
		end
		place(p, (spot or (at + mm.root.CFrame.LookVector * 8)) + Vector3.new(0, 3, 0))
		task.wait(0.6)
		ask(p, "pulseAt", root(p).Position + Vector3.new(0, 1.5, 0))
		-- 괴물을 길찾기로 근처 다른 지점까지 걷게 한다
		mm.hum.WalkSpeed = 8
		local goal = walkTo or spot or (at - mm.root.CFrame.LookVector * 8)
		local okPath = mm:pathTo(goal)
		local t1 = os.clock()
		while os.clock() - t1 < 3.5 do
			if okPath then
				mm:follow()
			else
				mm.hum:MoveTo(goal)
			end
			task.wait(0.1)
		end
		local st = ask(p, "creature", mm.model:GetAttribute("Creature"))
		local rv = ask(p, "revealedModel", mm.model)
		local ok = st ~= nil and st.frames > 10 and rv ~= nil and rv.active and rv.visible > 0
		table.insert(results, id .. (if ok then " ok" else " FAIL"))
		check(id .. " 3D body shown on sonar and animated", ok, string.format("frames %s bones %s visible parts %s err %s", st and st.frames or "-", st and st.bones or "-", rv and rv.visible or "-", st and st.err or "-"))
		check(id .. " walks with footsteps", st ~= nil and st.steps > 0, if st then "steps " .. st.steps else "")
		mm.hum:MoveTo(mm.root.Position)
	end
	-- 점프스케어만 내는 서브 괴물: 잡혀도 목숨이 그대로
	for _, id in def.sub do
		local mm = found[id]
		if mm and mm.model:GetAttribute("Gimmick") == "scare" then
			local lives = p:GetAttribute("Lives")
			mm.onCatch(p, mm)
			task.wait(1)
			check(id .. " scare-only catch keeps the player alive", p:GetAttribute("Status") == "Alive" and p:GetAttribute("Lives") == lives, tostring(p:GetAttribute("Status")) .. " lives " .. tostring(p:GetAttribute("Lives")))
		end
	end
	for _, mm in found do
		check("stays in map", mm.root.Position.Y > -50)
	end
end

-- 모든 챕터: 괴물마다 바로 앞에서 음파 → 그 괴물이 실제로 보이는가(보이는 몸이 있고 Reveal 이 켜짐)
local function revealAll()
	local ps = readyPlayers(1)
	check("player ready", ps ~= nil)
	if not ps then
		return
	end
	local p = ps[1]
	local catch0 = Config.Monster.CatchDistance
	Config.Monster.CatchDistance = -1
	for i = 1, #Config.Stages do
		Round.startStage(i)
		readyPlayers(1)
		task.wait(1)
		local shown, total, bodyless = 0, 0, {}
		for _, m in Round.monsters do
			if m.alive and m.model.Parent then
				total += 1
				m.startAt = os.clock() + 1e6 -- (테스트 동안 가만히)
				-- 보일 몸: 예전 괴물 = 음파 대상 파트, 시안 괴물 = 3D 메시
				local body = 0
				for _, d in m.model:GetDescendants() do
					if d:IsA("BasePart") and (CollectionService:HasTag(d, Config.Tags.Renderable) or d:IsA("MeshPart")) then
						body += 1
					end
				end
				if body == 0 then
					table.insert(bodyless, m.model.Name)
				end
				place(p, m.root.Position + m.root.CFrame.LookVector * 8 + Vector3.new(0, 3, 0))
				task.wait(0.5)
				ask(p, "pulseAt", root(p).Position + Vector3.new(0, 1.5, 0))
				local ok = waitFor(function()
					local r = ask(p, "revealedModel", m.model)
					return r ~= nil and r.active and r.visible > 0
				end, 3)
				if ok then
					shown += 1
				end
			end
		end
		check(string.format("stage %d: every monster has a visible body", i), #bodyless == 0, table.concat(bodyless, ","))
		check(string.format("stage %d: every monster revealed by sonar (%d)", i, total), total > 0 and shown == total, shown .. "/" .. total)
	end
	Config.Monster.CatchDistance = catch0
end

-- ─────────────────────────────── 성능: stress / census ───────────────────────────────
--   stress (env STAGE=n, QUICK=1 이면 짧게): 한 클라이언트에서 음파 부하를 단계별로 만들고 구간마다 수치를 잰다.
--     팀원 음파는 서버가 실제 팀원 음파와 똑같은 SonarPulse 이벤트로 보낸다(음파·소리·지도·괴물 드러남 경로가 모두 실제와 같다).
--   census (env STAGE=n 이면 그 챕터만, 아니면 전부): 부품 수·속성 집계, 서버·클라이언트 빌드 시간, 챕터를 이어서 바꿀 때 남는 인스턴스·메모리
local Stats = game:GetService("Stats")
local function r2(x)
	return math.floor((x or 0) * 100 + 0.5) / 100
end
-- 주변에 윤곽선 부품이 가장 많은 배회 지점(가장 무거운 곳)과 그 수
local function heaviestNode()
	local cells: { [number]: number } = {}
	local function key(x, z)
		return x * 4096 + z
	end
	for _, inst in CollectionService:GetTagged(Config.Tags.Renderable) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(stageFolder()) then
			local k = key(inst.Position.X // 8, inst.Position.Z // 8)
			cells[k] = (cells[k] or 0) + 1
		end
	end
	local best, bestN = Round.info.nodes[1], -1
	for _, n in Round.info.nodes do
		local cx, cz = n.X // 8, n.Z // 8
		local sum = 0
		for dx = -4, 4 do
			for dz = -4, 4 do
				if dx * dx + dz * dz <= 18 then
					sum += cells[key(cx + dx, cz + dz)] or 0
				end
			end
		end
		if sum > bestN then
			best, bestN = n, sum
		end
	end
	return best, bestN
end

local function stress()
	local ps = readyPlayers(1)
	check("player ready", ps ~= nil)
	if not ps then
		return
	end
	local p = ps[1]
	local stageNo = tonumber(args.Stage) or 0
	if stageNo > 0 and stageNo ~= Round.stageIndex then
		Round.startStage(stageNo)
		task.wait(1)
		ps = readyPlayers(1)
		check("stage ready", ps ~= nil)
		if not ps then
			return
		end
	end
	local seconds = if args.Quick then 5 else 9
	local SonarPulse = ReplicatedStorage.Remotes.SonarPulse
	local spot, spotParts = heaviestNode()
	place(p, spot + Vector3.new(0, 0.5, 0))
	task.wait(3)
	-- 괴물은 잡지 않게(측정이 끊기지 않게)
	local all = {}
	for _, list in { Round.monsters, Round.doppels, Round.flowers } do
		for _, m in list do
			rawset(m, "checkCatch", function() end)
			table.insert(all, m)
		end
	end
	-- 팀원 세 명이 서 있을 자리: 가까운 배회 지점 중 서로 다른 세 곳(8~28스터드)
	local near = {}
	for _, n in Round.info.nodes do
		local d = (n - spot).Magnitude
		if d > 7 and d < 30 and math.abs(n.Y - spot.Y) < 6 then
			table.insert(near, n)
		end
	end
	table.sort(near, function(a, b)
		return (a - spot).Magnitude < (b - spot).Magnitude
	end)
	local mates = {}
	for k = 1, 3 do
		mates[k] = (near[math.max(1, math.floor(#near * k / 3.2))] or spot) + Vector3.new(0, 1.5, 0)
	end
	local out = {}
	-- 한 구간: shooters 명이 gap 초마다 동시에 쏜다(0명이면 가만히)
	local function phase(name, shooters, gap, opts)
		opts = opts or {}
		task.wait(Config.Sonar.Hold + 0.5) -- 앞 구간의 선이 다 사라진 뒤
		ask(p, "perfx", "reset")
		local hb, hbN, hbMax, hbTime, physT, physMax = 0, 0, 0, 0, 0, 0
		local conn = RunService.Heartbeat:Connect(function(dt)
			hb += dt
			hbN += 1
			hbMax = math.max(hbMax, dt)
			hbTime += Stats.HeartbeatTimeMs
			local ph = Stats.PhysicsStepTimeMs
			physT += ph
			physMax = math.max(physMax, ph)
		end)
		local t = os.clock()
		local emitCpu, emits, fired, calls = 0, 0, 0, 0
		while os.clock() - t < seconds do
			local tick0 = os.clock()
			if opts.monsters then
				local pos = root(p) and root(p).Position
				for i, m in all do
					if pos and m.alive and m.kind ~= "flower" and m.form == "Beast" then
						if (m.root.Position - pos).Magnitude > 45 and i <= 5 and #near > 0 then
							m.model:PivotTo(CFrame.new(near[(i * 7) % #near + 1] + Vector3.new(0, 2, 0)))
						end
						m.startAt = 0
						m:startChase(p, pos)
					end
				end
			end
			if shooters > 0 then
				for s = 1, shooters do
					if s == 1 then
						ask(p, "resetCooldown")
						calls += 1
						if ask(p, "fire") then
							fired += 1
						end
					else
						local at = if opts.overlap then spot + Vector3.new(s * 0.6, 1.5, 0) else mates[(s - 2) % 3 + 1]
						SonarPulse:FireClient(p, 900000 + s, at)
						fired += 1
						local e0 = os.clock()
						SoundBus.emit(at, Config.Noise.Sonar, nil, "Sonar")
						emitCpu += os.clock() - e0
						emits += 1
					end
				end
				local rest = gap - (os.clock() - tick0)
				if rest > 0 then
					task.wait(rest)
				end
			else
				task.wait(0.5)
			end
		end
		conn:Disconnect()
		local dur = os.clock() - t
		local x = ask(p, "perfx", "reset")
		if not x then
			check(name .. ": perfx", false)
			return
		end
		local sys = {}
		for n, v in x.sys do
			sys[n] = string.format("%.2f ms/s, avg %.3f, worst %.2f ms, calls %d", v.avgMs * v.calls / dur, v.avgMs, v.worstMs, v.calls)
		end
		local row = {
			phase = name,
			fired = fired,
			sec = r2(dur),
			fps = r2(x.fps),
			low1 = r2(x.low1Fps),
			avgMs = r2(x.avgMs),
			p95 = r2(x.p95Ms),
			p99 = r2(x.p99Ms),
			worst = r2(x.worstMs),
			luaAvg = r2(x.luaAvgMs),
			luaP95 = r2(x.luaP95Ms),
			luaP99 = r2(x.luaP99Ms),
			luaWorst = r2(x.luaWorstMs),
			pulseAvg = r2(x.pulseCost.avgMs),
			pulseMax = r2(x.pulseCost.maxMs),
			startAvg = r2(x.pulseCost.startAvgMs),
			startMax = r2(x.pulseCost.startMaxMs),
			cut = x.pulseCost.cut,
			maxActive = x.pulseMaxActive,
			finished = x.pulseCost.finished,
			linesActive = x.lineStats.active,
			created = x.lineStats.created,
			dropped = x.lineStats.dropped,
			stolen = x.lineStats.stolen,
			shown = x.lineStats.shown,
			sounds = x.sounds,
			soundsPeak = x.soundsPeak,
			memMb = r2(x.memMb),
			instances = x.instances,
			recvKbps = r2(x.recvKbps),
			sendKbps = r2(x.sendKbps),
			srvFrame = r2(hb / math.max(1, hbN) * 1000),
			srvWorst = r2(hbMax * 1000),
			srvHeartbeatMs = r2(hbTime / math.max(1, hbN)),
			emitMs = if emits > 0 then math.floor(emitCpu / emits * 1e5) / 100 else 0,
			physMs = r2(physT / math.max(1, hbN)),
			physMax = r2(physMax),
			contacts = Stats.ContactsCount,
			counters = x.counters,
			sys = sys,
		}
		out[#out + 1] = row
		log(HttpService:JSONEncode(row))
	end
	phase("idle", 0, 0)
	phase("solo", 1, Config.Sonar.Cooldown)
	phase("two", 2, Config.Sonar.Cooldown)
	phase("four", 4, Config.Sonar.Cooldown)
	phase("four-overlap", 4, Config.Sonar.Cooldown, { overlap = true })
	phase("four-chase", 4, Config.Sonar.Cooldown, { monsters = true })
	phase("flood-12", 12, Config.Sonar.Cooldown)
	-- 다 끝난 뒤 남는 것(누수)
	task.wait(8)
	local z = ask(p, "perfx", "reset")
	check("all sonar lines released after stress", z and z.lineStats.active == 0, z and z.lineStats.active)
	check("no pulse left running", z and z.pulses == 0, z and z.pulses)
	check("no sound left over", z and z.sounds <= 3, z and z.sounds)
	R.info.stress = out
	R.info.spot = { parts = spotParts, at = tostring(spot), monsters = #all, after = z and { instances = z.instances, memMb = r2(z.memMb), sounds = z.sounds, lines = z.lineStats } }
	-- 서버 괴물 움직임 비용(한 프레임, 괴물 전부)
	local c0 = os.clock()
	for _ = 1, 100 do
		for _, m in all do
			m:animate(0.016)
		end
	end
	R.info.animateMsPerFrame = math.floor((os.clock() - c0) / 100 * 1e6) / 1000
end

-- soak (env STAGE, WATCH_SECONDS): 4명 분량 음파를 걸으며(자리 옮김) 계속 → 20초마다 Lua 메모리·인스턴스·선 큐·소리(누수·오래 할수록 느려지는지)
local function soak()
	local ps = readyPlayers(1)
	check("player ready", ps ~= nil)
	if not ps then
		return
	end
	local p = ps[1]
	local stageNo = tonumber(args.Stage) or 0
	if stageNo > 0 and stageNo ~= Round.stageIndex then
		Round.startStage(stageNo)
		task.wait(1)
		readyPlayers(1)
	end
	for _, list in { Round.monsters, Round.doppels, Round.flowers } do
		for _, m in list do
			rawset(m, "checkCatch", function() end)
		end
	end
	local nodes = Round.info.nodes
	local rows = {}
	local t = os.clock()
	local nextAt, i = 0, 0
	ask(p, "perfx", "reset")
	while os.clock() - t < (tonumber(args.Seconds) or 150) do
		local c = os.clock()
		i += 1
		local n = nodes[(i * 37) % #nodes + 1]
		place(p, n + Vector3.new(0, 0.5, 0))
		task.wait(0.05)
		ask(p, "resetCooldown")
		ask(p, "fire")
		for k = 1, 3 do
			ReplicatedStorage.Remotes.SonarPulse:FireClient(p, 900000 + k, n + Vector3.new(k * 2, 1.5, k))
		end
		if os.clock() - t >= nextAt then
			nextAt += 20
			local x = ask(p, "perfx", "reset")
			if x then
				local row = { t = math.floor(os.clock() - t), luaMb = r2((x.luaKb or 0) / 1024), order = x.lineStats.order, instances = x.instances, sounds = x.sounds, fps = r2(x.fps), luaAvg = r2(x.luaAvgMs), luaWorst = r2(x.luaWorstMs), worst = r2(x.worstMs), active = x.lineStats.active, memMb = r2(x.memMb) }
				rows[#rows + 1] = row
				log(HttpService:JSONEncode(row))
			end
		end
		task.wait(math.max(0, Config.Sonar.Cooldown - (os.clock() - c)))
	end
	task.wait(8)
	local z = ask(p, "perfx", "reset")
	check("soak: everything released", z and z.lineStats.active == 0 and z.pulses == 0 and z.sounds <= 3, z and (z.lineStats.active .. " lines, " .. z.pulses .. " pulses, " .. z.sounds .. " sounds"))
	R.info.soak = rows
	R.info.soakEnd = z and { luaMb = r2((z.luaKb or 0) / 1024), order = z.lineStats.order, instances = z.instances, sounds = z.sounds }
end

-- pbench (env STAGE=n, 없으면 전부): 음파 1·4개의 비용을 가짜 시계로 여러 번 재서 최소·중앙값(그 챕터에서 가장 무거운 곳)
local function pbench()
	local ps = readyPlayers(1)
	check("player ready", ps ~= nil)
	if not ps then
		return
	end
	local p = ps[1]
	local only = tonumber(args.Stage) or 0
	local rows = {}
	for i = 1, #Config.Stages do
		if only > 0 and i ~= only then
			continue
		end
		Round.startStage(i)
		task.wait(1)
		readyPlayers(1)
		local spot = heaviestNode()
		place(p, spot + Vector3.new(0, 0.5, 0))
		for _, list in { Round.monsters, Round.doppels, Round.flowers } do
			for _, m in list do
				rawset(m, "checkCatch", function() end)
			end
		end
		task.wait(2)
		local at = { spot + Vector3.new(0, 1.5, 0) }
		for _, n in Round.info.nodes do
			local d = (n - spot).Magnitude
			if #at < 4 and d > 14 * #at - 6 and d < 30 and math.abs(n.Y - spot.Y) < 6 then
				table.insert(at, n + Vector3.new(0, 1.5, 0))
			end
		end
		for _, n in { 1, 4 } do
			local res
			task.spawn(function()
				res = ReplicatedStorage.TestProbe:InvokeClient(p, "pulseBench", { at = at, n = n, reps = if args.Quick then 5 else 9 })
			end)
			waitFor(function()
				return res
			end, 90)
			if res then
				local row = { stage = i, n = n, shown = res.shown }
				for _, k in { "start", "wave", "total", "peak" } do
					row[k .. "Min"] = r2(res[k].min)
					row[k .. "Med"] = r2(res[k].med)
				end
				rows[#rows + 1] = row
				log(HttpService:JSONEncode(row))
			end
		end
	end
	check("bench rows", #rows > 0, #rows)
	R.info.pbench = rows
end

local function census()
	local ps = readyPlayers(1)
	check("player ready", ps ~= nil)
	if not ps then
		return
	end
	local p = ps[1]
	local only = tonumber(args.Stage) or 0
	local rows = {}
	local list = {}
	if only > 0 then
		list = { only }
	else
		for i = 1, #Config.Stages do
			list[i] = i
		end
		table.insert(list, 1) -- (처음 챕터로 돌아왔을 때 처음과 같은가 = 누수 확인)
	end
	for _, i in list do
		local okBuild, err = pcall(Round.startStage, i)
		check("stage " .. i .. " builds", okBuild, err)
		if not okBuild then
			continue
		end
		readyPlayers(1)
		local st = waitFor(function()
			local s = ask(p, "stats")
			return s and s.ready and s.buildId == stageFolder():GetAttribute("BuildId") and s
		end, 40)
		check("stage " .. i .. " client ready", st ~= nil)
		task.wait(2)
		local c = { stage = i, parts = 0, mesh = 0, invisible = 0, collide = 0, query = 0, touch = 0, shadow = 0, tagged = 0, decorQuery = 0, unanchored = 0, models = 0, inst = 0, prompts = 0, sounds = 0, lights = 0, cyl = 0 }
		for _, d in stageFolder():GetDescendants() do
			c.inst += 1
			if d:IsA("BasePart") then
				c.parts += 1
				if d:IsA("MeshPart") then
					c.mesh += 1
				elseif d:IsA("Part") and d.Shape == Enum.PartType.Cylinder then
					c.cyl += 1
				end
				if d.Transparency >= 1 then
					c.invisible += 1
				end
				if d.CanCollide then
					c.collide += 1
				elseif d.CanQuery then
					c.decorQuery += 1
				end
				if d.CanQuery then
					c.query += 1
				end
				if d.CanTouch then
					c.touch += 1
				end
				if d.CastShadow then
					c.shadow += 1
				end
				if not d.Anchored then
					c.unanchored += 1
				end
				if CollectionService:HasTag(d, Config.Tags.Renderable) then
					c.tagged += 1
				end
			elseif d:IsA("Model") then
				c.models += 1
			elseif d:IsA("ProximityPrompt") then
				c.prompts += 1
			elseif d:IsA("Sound") then
				c.sounds += 1
			elseif d:IsA("Light") then
				c.lights += 1
			end
		end
		c.serverBuildMs = math.floor(Round.lastBuildMs)
		c.segs = st and st.segs
		c.clientBuildSec = st and r2(st.build.seconds)
		c.clientBuildCpu = st and r2(st.build.cpu)
		c.grid = st and table.concat(st.grid, "x")
		local mp, mb, mm = 0, 0, 0
		for _, l in { Round.monsters, Round.doppels, Round.flowers } do
			for _, m in l do
				mm += 1
				for _, d in m.model:GetDescendants() do
					if d:IsA("BasePart") then
						mp += 1
					elseif d:IsA("Bone") then
						mb += 1
					end
				end
			end
		end
		c.monsters, c.monsterParts, c.monsterBones = mm, mp, mb
		local x = ask(p, "perfx", "reset")
		if x then
			c.clientInst, c.memMb, c.lines, c.recvKbps = x.instances, r2(x.memMb), x.lineStats.created, r2(x.recvKbps)
		end
		-- 이름별 파트 수 상위 12개(과분할 찾기: Haunch·Pipe·Pilaster·볼트 등), 1스터드보다 작은 장식, 부딪히는 장식(음파 윤곽 대상인데 충돌)
		local byName: { [string]: number } = {}
		local small, smallCollide = 0, 0
		for _, d in stageFolder():GetDescendants() do
			if d:IsA("BasePart") then
				local k = d.Name .. (if d:IsA("Part") and d.Shape == Enum.PartType.Cylinder then "(cyl)" else "")
				byName[k] = (byName[k] or 0) + 1
				local sz = d.Size
				if math.max(sz.X, sz.Y, sz.Z) < 1 then
					small += 1
					if d.CanCollide then
						smallCollide += 1
					end
				end
			end
		end
		local top = {}
		for k, v in byName do
			table.insert(top, { k, v })
		end
		table.sort(top, function(a, b)
			return a[2] > b[2]
		end)
		local s = {}
		for n = 1, math.min(12, #top) do
			s[n] = top[n][1] .. "=" .. top[n][2]
		end
		c.topNames = table.concat(s, " ")
		c.small, c.smallCollide = small, smallCollide
		-- 서버 물리(Studio 플레이는 서버·클라이언트가 한 프로세스)
		c.physMs = r2(Stats.PhysicsStepTimeMs)
		c.primitives = Stats.PrimitivesCount
		c.contacts = Stats.ContactsCount
		-- 지난 챕터에서 남은 것: Stage 폴더 밖 workspace 인스턴스(캐릭터·카메라·지형 제외)
		local loose = 0
		for _, ch in workspace:GetChildren() do
			if ch ~= stageFolder() and not ch:IsA("Terrain") and not ch:IsA("Camera") and not Players:GetPlayerFromCharacter(ch) then
				loose += 1 + #ch:GetDescendants()
			end
		end
		c.wsOutsideStage = loose
		c.serverInst, c.serverMemMb = Stats.InstanceCount, r2(Stats:GetTotalMemoryUsageMb())
		rows[#rows + 1] = c
		log(HttpService:JSONEncode(c))
	end
	R.info.census = rows
end

task.spawn(function()
	local ok, err = pcall(function()
		if args.Test == "stress" then
			stress()
		elseif args.Test == "soak" then
			soak()
		elseif args.Test == "pbench" then
			pbench()
		elseif args.Test == "census" then
			census()
		elseif args.Test == "dense" then
			dense()
		elseif args.Test == "lobby" then
			lobbyTest()
		elseif args.Test == "walk" then
			walk()
		elseif args.Test == "load" then
			load()
		elseif args.Test == "aibench" then
			aibench()
		elseif args.Test == "probe" then
			probe()
		elseif args.Test == "multi" then
			multi()
		elseif args.Test == "perf" then
			perf()
		elseif args.Test == "sonarall" then
			sonarAll()
		elseif args.Test == "stages" then
			stages()
		elseif args.Test == "mapnav" then
			mapNav()
		elseif args.Test == "seal" then
			seal()
		elseif args.Test == "doppel" then
			doppelTest()
		elseif args.Test == "creature" then
			creatureTest()
		elseif args.Test == "flowerspot" then
			flowerSpot()
		elseif args.Test == "chase" then
			chaseMotion()
		elseif args.Test == "lives" then
			livesTest()
		elseif args.Test == "meshcheck" then
			-- 올린 3D 메시 에셋 구조 확인(env CREATURE=에셋 번호)
			local ok, asset = pcall(function()
				return game:GetService("InsertService"):LoadAsset(tonumber(args.Creature) :: number)
			end)
			check("mesh asset loads", ok and asset ~= nil, tostring(asset))
			if ok and asset then
				local meshes, bones, skinned, verts = 0, 0, 0, ""
				for _, d in asset:GetDescendants() do
					if d:IsA("MeshPart") then
						meshes += 1
						if d.HasSkinnedMesh then
							skinned += 1
						end
						verts ..= string.format("%s size=%s ", d.Name, tostring(d.Size))
					elseif d:IsA("Bone") then
						bones += 1
					end
				end
				check("has mesh part", meshes > 0, meshes .. " " .. verts)
				check("has bones", bones > 10, tostring(bones))
				check("skinned", skinned > 0, tostring(skinned))
			end
		elseif args.Test == "revealall" then
			revealAll()
		elseif args.Test == "reveal" then
			revealTest()
		elseif args.Test == "netaudio" or args.Test == "netflood" then
			require(script.Parent.TestNetAudio)({ ask = ask, check = check, log = log, place = place, readyPlayers = readyPlayers, R = R, args = args })
		elseif args.Test == "mobile" then
			mobileTest()
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
