--!nonstrict
-- (자동 테스트 전용) 소품 메시(PropMesh) 검사와 전·후 화면.
--   propmesh (STAGE=n 이면 그 챕터만, 0 이면 전부): 메시 에셋을 불러와 소품마다 바꿔 입혔는가 · 메시 축이 데이터와 맞는가(가져올 때 축이 바뀌지 않았나)
--     · 클라이언트가 메시 선을 만들었는가(데이터 선분 자리에 정적 선분이 있다) · 숨긴 기본 도형이 충돌·막기를 그대로 갖는가 · 부품 수
--   propshot (STAGE=n): 그 챕터 메시 소품 몇 개 앞에 서서 음파 — 먼저 '후'(메시), 다음 ServerStorage.PropMeshOff 로 다시 지어 '전'(기본 도형).
--     로그 [SHOT] 줄 시각에 맞춰 측정 담당이 창을 캡처한다(각 장면 12초).
-- TestHarness 가 ctx(ask·check·log·place·readyPlayers·R·args)를 넘겨 부른다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(ReplicatedStorage.Shared.PropMeshData)
local Round = require(script.Parent.Round)
local PropMesh = require(script.Parent.PropMesh)

local function stageIndex(id: number): number?
	for i, st in Config.Stages do
		if st.Id == id then
			return i
		end
	end
	return nil
end

local function meshesIn(stage: Instance): { MeshPart }
	local out = {}
	for _, d in stage:GetDescendants() do
		if d:IsA("MeshPart") and d.Name == "PropMesh" then
			table.insert(out, d)
		end
	end
	return out
end

local function waitClient(ctx, p)
	local t = os.clock()
	while os.clock() - t < 40 do
		local st = ctx.ask(p, "stats")
		local stage = workspace:FindFirstChild("Stage")
		if st and st.ready and stage and st.buildId == stage:GetAttribute("BuildId") then
			return st
		end
		task.wait(0.5)
	end
	return nil
end

local function freezeMonsters()
	for _, mm in Round.monsters do
		mm.startAt = os.clock() + 1e6
	end
end

local function checkStage(ctx, p, id: number)
	local ask, check, log = ctx.ask, ctx.check, ctx.log
	local idx = stageIndex(id)
	if not idx then
		return
	end
	local s0 = table.clone(PropMesh.stats)
	local t0 = os.clock()
	Round.startStage(idx)
	local buildS = os.clock() - t0
	local st = waitClient(ctx, p)
	freezeMonsters()
	local stage = workspace:FindFirstChild("Stage")
	check(("ch%d client sonar world ready"):format(id), st ~= nil, st and st.segs)
	if not stage then
		return
	end
	local meshes = meshesIn(stage)
	local dressed = PropMesh.stats.dressed - s0.dressed
	local fallback = PropMesh.stats.fallback - s0.fallback
	local parts, hidden, hiddenBad = 0, 0, 0
	for _, d in stage:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			if d:GetAttribute("SonarHidden") then
				hidden += 1
				if d.Transparency < 1 then
					hiddenBad += 1
				end
			end
		end
	end
	log(("ch%d props: meshes %d dressed %d fallback %d hidden %d parts %d build %.2fs loadFail %d"):format(id, #meshes, dressed, fallback, hidden, parts, buildS, PropMesh.stats.loadFail))
	ctx.R.info["propmesh" .. id] = { meshes = #meshes, dressed = dressed, fallback = fallback, hidden = hidden, parts = parts, build = buildS, segs = st and st.segs, viewParts = st and st.viewParts }
	check(("ch%d prop meshes loaded (no load failures)"):format(id), PropMesh.stats.loadFail == 0, PropMesh.stats.loadFail)
	check(("ch%d part budget ≤ 9106"):format(id), parts <= 9106, parts)
	check(("ch%d hidden primitives are invisible"):format(id), hiddenBad == 0, hiddenBad)
	-- 메시 축: Size / MeshSize 가 세 축 같은 비율(가져올 때 축이 바뀌거나 늘어나지 않았다)
	local axisBad, axisInfo = 0, ""
	for _, mp in meshes do
		local key = mp:GetAttribute("SonarMesh")
		local item = Data.get(key)
		local ms = mp.MeshSize
		local sc = (mp:GetAttribute("SonarMeshScale") :: Vector3?) or Vector3.one
		if item and ms.Magnitude > 0 then
			local r = Vector3.new(item.size.X / ms.X, item.size.Y / ms.Y, item.size.Z / ms.Z)
			local lo, hi = math.min(r.X, r.Y, r.Z), math.max(r.X, r.Y, r.Z)
			if hi / lo > 1.03 then
				axisBad += 1
				if #axisInfo < 200 then
					axisInfo ..= ("%s ratio %s; "):format(key, tostring(r))
				end
			end
		end
		local _ = sc
	end
	check(("ch%d mesh axes match line data"):format(id), axisBad == 0, if axisBad == 0 then #meshes else axisInfo)
	-- 클라이언트 선: 메시마다(최대 25개) 데이터 첫 선분 가운데에 정적 선분이 있다
	local tested, found = 0, 0
	for i, mp in meshes do
		if i > 25 then
			break
		end
		local item = Data.get(mp:GetAttribute("SonarMesh"))
		if item and #item.seg >= 6 then
			local sc = mp.Size / item.size
			local s = item.seg
			local a = mp.CFrame * Vector3.new(s[1] * sc.X, s[2] * sc.Y, s[3] * sc.Z)
			local b = mp.CFrame * Vector3.new(s[4] * sc.X, s[5] * sc.Y, s[6] * sc.Z)
			local near = ask(p, "segsNear", { (a + b) / 2, 1.4 })
			tested += 1
			if near and #near > 0 then
				found += 1
			end
		end
	end
	check(("ch%d client builds mesh sonar lines"):format(id), tested == 0 or found >= tested * 0.9, found .. "/" .. tested)
end

local function propmesh(ctx)
	local ps = ctx.readyPlayers(1)
	local p = ps and ps[1]
	ctx.check("player ready", p ~= nil)
	if not p then
		return
	end
	ctx.check("prop mesh assets listed", next(Data.assets) ~= nil, (function()
		local n = 0
		for _ in Data.assets do
			n += 1
		end
		return n
	end)())
	local only = tonumber(ctx.args.Stage) or 0
	for _, st in Config.Stages do
		if only == 0 or st.Id == only then
			checkStage(ctx, p, st.Id)
		end
	end
end

-- 전·후 화면: 메시 소품 앞에 서서 음파를 쏜다
local function propshot(ctx)
	local ask, log = ctx.ask, ctx.log
	local ps = ctx.readyPlayers(1)
	local p = ps and ps[1]
	if not p then
		return
	end
	local id = tonumber(ctx.args.Stage) or 4
	local idx = stageIndex(id)
	if not idx then
		return
	end
	-- 1) 후: 메시
	ServerStorage:SetAttribute("PropMeshOff", false)
	Round.startStage(idx)
	waitClient(ctx, p)
	freezeMonsters()
	local stage = workspace:FindFirstChild("Stage")
	local shots = {}
	local seen = {}
	for _, mp in meshesIn(stage) do
		local key = mp:GetAttribute("SonarMesh")
		if not seen[key] and #shots < 4 then
			-- 소품에서 7~12 스터드, 같은 높이, 보이는 이동 지점
			local at = mp.Position
			local floorY = at.Y - mp.Size.Y / 2
			local best, near, nearD = nil, nil, math.huge
			-- (배회 지점 = 바닥 + 3)
			for _, n in (Round.info :: any).nodes do
				local d = (Vector3.new(n.X, at.Y, n.Z) - at).Magnitude
				local sameFloor = math.abs((n.Y - 3) - floorY) < 2.5
				if sameFloor and d >= 6 and d <= 14 and math.abs(d - 9) < nearD then
					near, nearD = n, math.abs(d - 9)
				end
				if sameFloor and d >= 7 and d <= 12 then
					local rp = RaycastParams.new()
					rp.FilterType = Enum.RaycastFilterType.Include
					rp.FilterDescendantsInstances = { stage }
					rp.RespectCanCollide = true
					local eye = n + Vector3.new(0, 1.6, 0)
					local hit = workspace:Raycast(eye, at - eye, rp)
					if not hit or (hit.Position - at).Magnitude < mp.Size.Magnitude / 2 + 1 then
						best = n
						break
					end
				end
			end
			best = best or near
			if best then
				seen[key] = true
				table.insert(shots, { key = key, node = best, at = at })
			end
		end
	end
	local function scene(tag)
		for _, s in shots do
			ctx.place(p, s.node + Vector3.new(0, 0.5, 0), s.at)
			task.wait(0.5)
			ask(p, "lookAt", { s.node + Vector3.new(0, 1.6, 0), s.at })
			-- 장면 내내 0.9초마다 음파(선이 몇 초 안에 사라져서, 고정 8초 어느 순간을 찍어도 선이 보이게). [SHOT] 은 고정 구간 가운데
			local t0 = os.clock()
			local logged = false
			while os.clock() - t0 < 12 do
				ask(p, "resetCooldown")
				ask(p, "pulseAt", s.node + Vector3.new(0, 1.5, 0))
				if not logged and os.clock() - t0 > 6 then
					logged = true
					log(("[SHOT] ch%d %s %s t=%.1f unixms=%d"):format(id, tag, tostring(s.key), os.clock(), DateTime.now().UnixTimestampMillis))
				end
				task.wait(0.9)
			end
		end
	end
	scene("after")
	-- 2) 전: 같은 자리, 기본 도형
	ServerStorage:SetAttribute("PropMeshOff", true)
	Round.startStage(idx)
	waitClient(ctx, p)
	freezeMonsters()
	scene("before")
	ServerStorage:SetAttribute("PropMeshOff", false)
	ask(p, "lookAt", nil)
	ctx.check("prop shots staged", #shots > 0, #shots)
end

return function(ctx)
	if ctx.args.Test == "propshot" then
		propshot(ctx)
	else
		propmesh(ctx)
	end
end
