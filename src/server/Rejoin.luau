--!strict
-- 끊겼을 때 진행 중이던 게임으로 다시 들어가기.
-- 방에서 시작한 게임은 예약(비공개) 서버라서, 연결이 끊기면(휴대폰 오류 277 등) 친구 따라가기로도 못 들어온다.
--  · 게임 서버: 로비가 넘겨준 예약 서버 접속 코드를 기억하고, 이 게임에 참가한 사람마다 "살아 있음"을 30초마다 적는다(MemoryStore).
--  · 로비 서버: 들어온 사람에게 최근(90초 안) 살아 있는 게임 기록이 있으면 그 예약 서버로 바로 보낸다.
--  · 게임이 끝나면(마지막 스테이지 클리어) 기록을 지운다. 서버가 닫히면 기록이 갱신되지 않아 90초 뒤 저절로 무시된다.
-- Studio·API 꺼짐 등 MemoryStore 를 못 쓰면 조용히 아무것도 하지 않는다.

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Rejoin = {}
Rejoin.FRESH = 90 -- 이 초 안에 갱신된 기록만 "진행 중"
Rejoin.TTL = 15 * 60 -- 기록 보관(초)
Rejoin.code = nil :: string? -- (게임 서버) 이 예약 서버의 접속 코드
Rejoin.roster = {} :: { [number]: boolean } -- (게임 서버) 이 게임에 들어왔던 사람(끊겨도 남는다)

local map: MemoryStoreSortedMap? = nil
local function store(): MemoryStoreSortedMap?
	if RunService:IsStudio() then
		return nil
	end
	if not map then
		local ok, m = pcall(function()
			return MemoryStoreService:GetSortedMap("SonarRejoin")
		end)
		map = if ok then m else nil
	end
	return map
end

local function write(userId: number)
	local m = store()
	if not m or not Rejoin.code then
		return
	end
	pcall(function()
		m:SetAsync(tostring(userId), { code = Rejoin.code, at = os.time() }, Rejoin.TTL)
	end)
end

function Rejoin.forget(userId: number)
	local m = store()
	if not m then
		return
	end
	pcall(function()
		m:RemoveAsync(tostring(userId))
	end)
end

-- (로비 서버) 이 사람이 돌아갈 진행 중인 게임의 접속 코드
function Rejoin.lookup(userId: number): string?
	local m = store()
	if not m then
		return nil
	end
	local ok, data = pcall(function()
		return m:GetAsync(tostring(userId))
	end)
	if ok and type(data) == "table" and type(data.code) == "string" and type(data.at) == "number" and os.time() - data.at <= Rejoin.FRESH then
		return data.code
	end
	return nil
end

-- (게임 서버) 들어온 사람의 접속 코드를 기억하고 명단에 넣는다
function Rejoin.arrived(p: Player)
	local ok, jd = pcall(function()
		return p:GetJoinData()
	end)
	local td = ok and jd and (jd :: any).TeleportData
	if type(td) == "table" and type(td.code) == "string" and not Rejoin.code then
		Rejoin.code = td.code
	end
	Rejoin.roster[p.UserId] = true
	write(p.UserId)
end

-- (게임 서버) 게임이 끝났다: 기록을 지워 다시 끌려오지 않게
local ended = false
function Rejoin.gameOver()
	ended = true
	for userId in Rejoin.roster do
		Rejoin.forget(userId)
	end
end

-- (게임 서버) 30초마다 명단 전원의 "진행 중" 갱신(끊긴 사람도 돌아올 수 있게)
function Rejoin.startHeartbeat()
	task.spawn(function()
		while not ended do
			if Rejoin.code then
				for userId in Rejoin.roster do
					write(userId)
				end
			end
			task.wait(30)
		end
	end)
end

Players.PlayerRemoving:Connect(function(_p)
	-- (기록은 남겨 둔다: 끊긴 사람이 다시 켜면 돌아올 수 있게. 게임이 끝나거나 서버가 닫히면 무시된다)
end)

return Rejoin
