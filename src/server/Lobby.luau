--!strict
-- 로비와 방.
--   · 서버가 시작되면: 예약 서버(방에서 텔레포트로 온 게임 서버)면 바로 게임, 아니면 로비.
--   · 로비: 방 만들기 / 참가 / 나가기 / 시작(방장만) / 친구만(방장만, 켜면 방장의 친구만 참가). 방 목록은 ReplicatedStorage 속성 "Rooms"(JSON), 내 방은 Player 속성 "RoomId".
--   · 시작: 게임에서는 방 사람들을 새 예약 서버로 텔레포트(방마다 따로 플레이).
--           Studio(텔레포트 불가)에서는 이 서버에서 그 방 사람들로 바로 시작하고, 다 깨면 로비로 돌아온다.
-- 클라이언트 요청: Remotes.RoomAction:FireServer(action, arg)  action = "create" | "join"(arg = 방 번호) | "leave" | "start" | "friendsOnly"(arg = true/false)
-- 친구 초대는 클라이언트가 SocialService 초대 창으로 한다(초대받은 친구는 이 로비 서버로 들어온다).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Config = require(ReplicatedStorage.Shared.Config)
local Round = require(script.Parent.Round)
local Rejoin = require(script.Parent.Rejoin)
local RateLimit = require(script.Parent.RateLimit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RoomAction = Remotes:WaitForChild("RoomAction") :: RemoteEvent
local RoundEvent = Remotes:WaitForChild("RoundEvent") :: RemoteEvent

local Lobby = {}

type Room = { id: number, host: Player, members: { Player }, started: boolean, friendsOnly: boolean }
local rooms: { [number]: Room } = {}
local nextId = 0
Lobby.rooms = rooms

local function publish()
	local list = {}
	for _, r in rooms do
		local names, ids = {}, {}
		for _, m in r.members do
			table.insert(names, m.DisplayName)
			table.insert(ids, m.UserId)
		end
		table.insert(list, { id = r.id, host = r.host.DisplayName, hostId = r.host.UserId, names = names, ids = ids, started = r.started, friendsOnly = r.friendsOnly, max = Config.Lobby.MaxPlayers })
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	ReplicatedStorage:SetAttribute("Rooms", HttpService:JSONEncode(list))
end

local function message(p: Player, text: string)
	RoundEvent:FireClient(p, "RoomMsg", { text = text })
end

local function roomOf(p: Player): Room?
	local id = p:GetAttribute("RoomId")
	return if type(id) == "number" then rooms[id] else nil
end

local function leave(p: Player)
	local r = roomOf(p)
	p:SetAttribute("RoomId", nil)
	if not r then
		return
	end
	local i = table.find(r.members, p)
	if i then
		table.remove(r.members, i)
	end
	if #r.members == 0 then
		rooms[r.id] = nil
	elseif r.host == p then
		r.host = r.members[1] -- 방장이 나가면 다음 사람이 방장
		message(r.host, "방장이 되었습니다")
	end
	publish()
end

local function join(p: Player, r: Room): boolean
	if r.started then
		message(p, "이미 시작한 방입니다")
		return false
	end
	if #r.members >= Config.Lobby.MaxPlayers then
		message(p, "방이 가득 찼습니다")
		return false
	end
	if r.friendsOnly and p ~= r.host then
		local ok, friend = pcall(p.IsFriendsWith, p, r.host.UserId)
		if not (ok and friend) then
			message(p, "방장의 친구만 들어올 수 있는 방입니다")
			return false
		end
	end
	leave(p)
	table.insert(r.members, p)
	p:SetAttribute("RoomId", r.id)
	publish()
	return true
end

-- 이 서버에서 그 방 사람들로 게임을 시작한다(Studio, 또는 텔레포트를 쓸 수 없을 때)
function Lobby.startLocal(r: Room)
	local members = {}
	for _, m in r.members do
		members[m] = true
	end
	-- 로비 맵이 사라지므로 다른 방은 모두 닫는다(그 사람들은 게임이 끝날 때까지 기다린다)
	for id, other in rooms do
		for _, m in other.members do
			m:SetAttribute("RoomId", nil)
			if not members[m] then
				message(m, "다른 방이 이 서버에서 게임 중입니다. 끝나면 로비로 돌아옵니다")
			end
		end
		rooms[id] = nil
	end
	publish()
	Round.members = members
	Round.returnToLobby = true
	Round.stageIndex = 1
	task.spawn(Round.loop)
end

local function startTeleport(r: Room)
	local ok, err = pcall(function()
		local code = TeleportService:ReserveServer(game.PlaceId)
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = code
		options:SetTeleportData({ room = r.id, code = code }) -- (code: 끊긴 사람이 다시 돌아오게 게임 서버가 기억한다)
		TeleportService:TeleportAsync(game.PlaceId, r.members, options)
	end)
	if not ok then
		r.started = false
		publish()
		for _, m in r.members do
			message(m, "시작하지 못했습니다(텔레포트 실패). 다시 눌러 주세요")
		end
		warn("[Lobby] teleport failed: " .. tostring(err))
	end
end

local function start(p: Player)
	local r = roomOf(p)
	if not r then
		return
	end
	if r.host ~= p then
		message(p, "방장만 시작할 수 있습니다")
		return
	end
	if r.started then
		return
	end
	if #r.members < Config.Lobby.MinPlayers then
		message(p, string.format("%d명 이상이어야 시작합니다", Config.Lobby.MinPlayers))
		return
	end
	r.started = true
	publish()
	for _, m in r.members do
		RoundEvent:FireClient(m, "RoomStarting", { id = r.id })
	end
	if Lobby.localStart() then
		Lobby.startLocal(r)
	else
		startTeleport(r)
	end
end

-- 텔레포트 대신 이 서버에서 시작하는가(Studio 에서는 텔레포트가 안 된다)
function Lobby.localStart(): boolean
	return RunService:IsStudio() or Config.Lobby.LocalStart == true
end

-- 방에서 텔레포트로 온 게임 서버인가(예약 서버)
function Lobby.isGameServer(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

function Lobby.act(p: Player, action: any, arg: any)
	if Round.state ~= "Lobby" or type(action) ~= "string" then
		return
	end
	-- (방 목록 변경은 모두에게 복제된다: 만들기·나가기를 빠르게 되풀이해도 초당 몇 번만)
	if not RateLimit.allow(p, "RoomAction", 4, 8) then
		return
	end
	if action == "create" then
		if roomOf(p) then
			return
		end
		nextId += 1
		local r: Room = { id = nextId, host = p, members = {}, started = false, friendsOnly = false }
		rooms[r.id] = r
		join(p, r)
	elseif action == "join" then
		local r = if type(arg) == "number" then rooms[arg] else nil
		if r and roomOf(p) ~= r then
			join(p, r)
		end
	elseif action == "leave" then
		leave(p)
	elseif action == "start" then
		start(p)
	elseif action == "friendsOnly" then
		local r = roomOf(p)
		if r and r.host == p then
			r.friendsOnly = arg == true
			publish()
		end
	end
end

RoomAction.OnServerEvent:Connect(Lobby.act)
Players.PlayerRemoving:Connect(leave)

-- 서버 시작: 첫 플레이어가 들어오면 모드를 정한다(테스트는 ReplicatedStorage 속성 ForceMode 로 고른다)
function Lobby.boot()
	while #Players:GetPlayers() == 0 do
		task.wait(0.2)
	end
	local force = ReplicatedStorage:GetAttribute("ForceMode")
	local mode = if force == "Game" or force == "Lobby" then force elseif Lobby.isGameServer() then "Game" else "Lobby"
	if mode == "Game" then
		ReplicatedStorage:SetAttribute("Mode", "Game")
		-- 끊긴 사람이 다시 켜면 이 게임으로 돌아오게: 들어온 사람마다 기록, 30초마다 갱신
		for _, p in Players:GetPlayers() do
			Rejoin.arrived(p)
		end
		Players.PlayerAdded:Connect(Rejoin.arrived)
		Rejoin.startHeartbeat()
		Round.loop()
	else
		publish()
		-- 진행 중인 게임에서 끊겼던 사람은 그 게임(예약 서버)으로 바로 돌려보낸다
		local function tryRejoin(p: Player)
			local code = Rejoin.lookup(p.UserId)
			if not code then
				return
			end
			message(p, "진행 중이던 게임으로 다시 연결합니다…")
			local ok, err = pcall(function()
				local options = Instance.new("TeleportOptions")
				options.ReservedServerAccessCode = code
				options:SetTeleportData({ room = 0, code = code, rejoin = true })
				TeleportService:TeleportAsync(game.PlaceId, { p }, options)
			end)
			if not ok then
				Rejoin.forget(p.UserId)
				message(p, "다시 연결하지 못했습니다. 새 방을 만들어 주세요")
				warn("[Lobby] rejoin failed: " .. tostring(err))
			end
		end
		for _, p in Players:GetPlayers() do
			task.spawn(tryRejoin, p)
		end
		Players.PlayerAdded:Connect(function(p)
			task.spawn(tryRejoin, p)
		end)
		Round.enterLobby()
	end
end

publish()
return Lobby
