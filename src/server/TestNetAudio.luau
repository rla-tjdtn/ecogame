--!nonstrict
-- (자동 테스트 전용) netaudio: 여러 클라이언트(PLAYERS=4)로 리모트 송수신 수·속성 복제 수·소리 생성 수·메모리를 단계별로 잰다.
--   idle(가만히) → look(카메라만 돌림) → action(모두 음파 + 걷기 + 괴물 추격) → spectate(한 명 사망·관전) → leave(한 명 퇴장, 음파 중)
-- TestHarness 가 ctx(ask·check·log·place·readyPlayers·R·args)를 넘겨 부른다. 게임 중에는 아무도 부르지 않는다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local Config = require(ReplicatedStorage.Shared.Config)
local Round = require(script.Parent.Round)

-- netflood (PLAYERS=2): 한 사람이 리모트를 한꺼번에 많이 보낸다 → 서버가 처리한 수·다른 사람에게 퍼진 속성 변화·서버 프레임,
-- 그 뒤 정상 입력(음파·이동 모드·시선)이 막히지 않는가
local function flood(ctx)
	local ask, check, log, R = ctx.ask, ctx.check, ctx.log, ctx.R
	local ps = ctx.readyPlayers(2)
	check("2 players ready", ps ~= nil, #Players:GetPlayers())
	if not ps then
		return
	end
	local a, b = ps[1], ps[2]
	-- 관전자가 있어야 시선 공유가 켜진다: b 를 관전 상태로
	Round.kill(b, "test")
	task.wait(2)
	local handled = {}
	local conns = {}
	for _, ev in ReplicatedStorage.Remotes:GetChildren() do
		if ev:IsA("RemoteEvent") then
			table.insert(conns, ev.OnServerEvent:Connect(function()
				handled[ev.Name] = (handled[ev.Name] or 0) + 1
			end))
		end
	end
	local rows = {}
	for _, job in { { "LookShare", 600 }, { "MapShare", 200 }, { "SetMoveMode", 600 }, { "KeyHint", 300 } } do
		ask(a, "netaudio", "reset")
		ask(b, "netaudio", "reset")
		table.clear(handled)
		local attrs = 0
		local c1 = a.AttributeChanged:Connect(function()
			attrs += 1
		end)
		local hbMax, hbSum, hbN = 0, 0, 0
		local c2 = game:GetService("RunService").Heartbeat:Connect(function(dt)
			hbMax = math.max(hbMax, dt)
			hbSum += Stats.HeartbeatTimeMs
			hbN += 1
		end)
		ask(a, "flood", { remote = job[1], n = job[2] })
		task.wait(3)
		c1:Disconnect()
		c2:Disconnect()
		local xa = ask(a, "netaudio", "reset")
		local xb = ask(b, "netaudio", "reset")
		local row = {
			remote = job[1],
			sent = job[2],
			serverReceived = handled[job[1]] or 0,
			serverAttrWrites = attrs,
			observerAttrChanges = xb and ((xb.counts["attr.other.LookYaw"] or 0) + (xb.counts["attr.other.LookPitch"] or 0)) or -1,
			senderMapShareReplies = xa and (xa.counts["recv.MapShare"] or 0) or -1,
			senderMapShareTiles = xa and (xa.counts["recv.MapShare.tiles"] or 0) or -1,
			senderRecvKbps = xa and xa.recvKbps,
			serverWorstFrameMs = math.floor(hbMax * 100000) / 100,
			serverHeartbeatMs = math.floor(hbSum / math.max(1, hbN) * 100) / 100,
		}
		rows[#rows + 1] = row
		log(HttpService:JSONEncode(row))
	end
	-- 정상 입력은 막히지 않는다(폭주 뒤 2초)
	task.wait(2)
	local SM = _G.SonarMaze
	local before = SM.Sonar.accepted[a] or 0
	ask(a, "resetCooldown")
	ask(a, "fire")
	task.wait(0.5)
	check("sonar still accepted after flood", (SM.Sonar.accepted[a] or 0) == before + 1, (SM.Sonar.accepted[a] or 0) - before)
	ask(a, "setMode", "Run")
	task.wait(0.6)
	check("move mode still applied after flood", a.Character and a.Character:GetAttribute("MoveMode") == "Run", a.Character and a.Character:GetAttribute("MoveMode"))
	ask(a, "setMode", nil)
	local y0 = a:GetAttribute("LookYaw")
	ask(a, "spin", 3)
	task.wait(1)
	ask(a, "spin", 0)
	check("look still shared after flood", a:GetAttribute("LookYaw") ~= y0, tostring(y0) .. " -> " .. tostring(a:GetAttribute("LookYaw")))
	for _, c in conns do
		c:Disconnect()
	end
	R.info.netflood = rows
end

return function(ctx)
	local ask, check, log, place, R, args = ctx.ask, ctx.check, ctx.log, ctx.place, ctx.R, ctx.args
	if args.Test == "netflood" then
		return flood(ctx)
	end
	local want = tonumber(args.Players) or 4
	local ps = ctx.readyPlayers(want)
	check("all " .. want .. " players ready", ps ~= nil, #Players:GetPlayers())
	if not ps then
		return
	end
	local function r2(x)
		return math.floor((x or 0) * 100 + 0.5) / 100
	end
	-- 괴물은 잡지 않게
	local all = {}
	for _, list in { Round.monsters, Round.doppels, Round.flowers } do
		for _, m in list do
			rawset(m, "checkCatch", function() end)
			table.insert(all, m)
		end
	end
	-- 서버가 받은 리모트 수
	local srv = {}
	local conns = {}
	for _, ev in ReplicatedStorage.Remotes:GetChildren() do
		if ev:IsA("RemoteEvent") then
			table.insert(conns, ev.OnServerEvent:Connect(function()
				srv[ev.Name] = (srv[ev.Name] or 0) + 1
			end))
		end
	end
	local nodes = Round.info.nodes
	local start = Round.info.spawns and Round.info.spawns[1] or nodes[1]
	for k, p in ps do
		place(p, (if typeof(start) == "CFrame" then start.Position else start) + Vector3.new(k * 2.5, 0.5, 0))
	end
	task.wait(2)
	local out = {}
	local function phase(name, seconds, body)
		for _, p in ps do
			if p.Parent then
				ask(p, "netaudio", "reset")
			end
		end
		table.clear(srv)
		local hbN, hbT = 0, 0
		local c = game:GetService("RunService").Heartbeat:Connect(function()
			hbN += 1
			hbT += Stats.HeartbeatTimeMs
		end)
		local t = os.clock()
		body(seconds)
		local dur = os.clock() - t
		c:Disconnect()
		local row = { phase = name, sec = r2(dur), server = { remotesIn = table.clone(srv), instances = Stats.InstanceCount, memMb = r2(Stats:GetTotalMemoryUsageMb()), heartbeatMs = r2(hbT / math.max(1, hbN)), sendKbps = r2(Stats.DataSendKbps), recvKbps = r2(Stats.DataReceiveKbps) }, clients = {} }
		for i, p in ps do
			if p.Parent then
				local x = ask(p, "netaudio", "reset")
				if x then
					local cnt = x.counts
					local perSec = {}
					for k, v in cnt do
						if not string.find(k, "^snd:") then
							perSec[k] = r2(v / dur)
						end
					end
					local top = {}
					for k, v in cnt do
						if string.find(k, "^snd:") then
							table.insert(top, { k, v })
						end
					end
					table.sort(top, function(a, b)
						return a[2] > b[2]
					end)
					local names = {}
					for j = 1, math.min(8, #top) do
						names[j] = top[j][1] .. "=" .. top[j][2]
					end
					row.clients[i] = {
						perSec = perSec,
						topSounds = table.concat(names, " "),
						livePeak = x.livePeak,
						live = x.live,
						sndCpuUsPerPlay = r2((cnt["snd.cpuUs"] or 0) / math.max(1, cnt["snd.play"] or 0)),
						uiUsPerFrame = r2((cnt["ui.frameUs"] or 0) / math.max(1, cnt["ui.frames"] or 0)),
						soundsInWorkspace = x.soundsInWorkspace,
						soundsInSoundService = x.soundsInSoundService,
						instances = x.instances,
						memMb = r2(x.memMb),
						luaMb = r2(x.luaKb / 1024),
						recvKbps = r2(x.recvKbps),
						sendKbps = r2(x.sendKbps),
					}
				end
			end
		end
		out[#out + 1] = row
		log(HttpService:JSONEncode(row))
		return row
	end

	phase("idle", 15, function(s)
		task.wait(s)
	end)
	phase("look", 15, function(s)
		for _, p in ps do
			task.spawn(ask, p, "spin", 2)
		end
		task.wait(s)
		for _, p in ps do
			task.spawn(ask, p, "spin", 0)
		end
	end)
	local function action(s, who)
		local t = os.clock()
		local i = 0
		while os.clock() - t < s do
			i += 1
			for k, p in who do
				if p.Parent and p:GetAttribute("Status") == "Alive" then
					task.spawn(ask, p, "resetCooldown")
					task.spawn(ask, p, "fire")
					local n = nodes[(i * 13 + k * 31) % #nodes + 1]
					task.spawn(ask, p, "setMode", if k % 2 == 0 then "Run" else nil)
					task.spawn(ask, p, "move", n)
				end
			end
			local target = who[1]
			local rp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
			if rp then
				for _, m in all do
					if m.alive and m.kind ~= "flower" and m.form == "Beast" and m.startChase then
						m.startAt = 0
						pcall(m.startChase, m, target, rp.Position)
					end
				end
			end
			task.wait(Config.Sonar.Cooldown)
		end
	end
	phase("action", 30, function(s)
		for _, p in ps do
			task.spawn(ask, p, "spin", 1)
		end
		action(s, ps)
	end)
	-- 한 명 사망 → 관전(나머지는 계속 움직이며 음파)
	local victim = ps[1]
	phase("spectate", 20, function(s)
		Round.kill(victim, "test")
		task.wait(2)
		local rest = {}
		for k = 2, #ps do
			rest[#rest + 1] = ps[k]
		end
		action(s - 2, rest)
	end)
	local st = ask(victim, "stats")
	check("dead player spectates a teammate", st and st.ui.spectate ~= nil and st.ui.spectate:find("관전 중") ~= nil, st and st.ui.spectate)
	-- 음파·추격 중에 한 명이 나간다
	local leaver = ps[#ps]
	local leaverName = leaver.Name
	phase("leave", 15, function(s)
		local rest = {}
		for k = 2, #ps - 1 do
			rest[#rest + 1] = ps[k]
		end
		task.spawn(function()
			task.wait(3)
			leaver:Kick("netaudio test: leave mid-round")
		end)
		action(s, rest)
	end)
	local SM = _G.SonarMaze
	check("left player's sonar table cleared", SM and SM.Sonar.accepted[leaver] == nil)
	check("round still playing after leave", Round.state == "Playing", Round.state)
	task.wait(8)
	-- (1) 아직 라운드 중(괴물이 쫓고 음파에 드러난 채): 지금 나는 소리는 남아 있어도 된다. 누수 = 7초보다 오래 산 소리
	local rest = {}
	for _, p in ps do
		if p.Parent then
			table.insert(rest, p)
			local z = ask(p, "netaudio")
			check(p.Name .. ": no sound outlives its 6 s cleanup (mid-round)", z and z.liveOld == 0, z and string.format("live %d, old %d, oldest %.1fs: %s", z.live, z.liveOld, z.liveOldestSec, z.liveNames))
		end
	end
	-- (2) 라운드가 끝나고 새 스테이지(괴물·문·소품이 모두 바뀜) → 8초 뒤 이전 라운드 소리는 하나도 남지 않는다
	Round.startStage(Round.stageIndex)
	ctx.readyPlayers(#rest)
	task.wait(8)
	for _, p in rest do
		local z = ask(p, "netaudio", "reset")
		check(p.Name .. ": sounds released after round end", z and z.live <= 3 and z.liveOld == 0, z and string.format("live %d, old %d, oldest %.1fs: %s", z.live, z.liveOld, z.liveOldestSec, z.liveNames))
	end
	for _, c in conns do
		c:Disconnect()
	end
	R.info.netaudio = out
	R.info.leaver = leaverName
end
