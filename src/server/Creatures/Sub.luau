--!strict
-- 서브 괴물: 역할에 맞는 자기 자리(영역)에 있다가, 그 영역 안에서 음파·플레이어 소리·사람을 알아채면 쫓는다.
-- 쫓는 동안은 영역 밖까지 따라가고, 놓치면 수색한 뒤 자기 영역으로 돌아간다. 거기에 괴물마다 기믹 하나(Config.Creatures.Gimmicks 수치):
--  scare  : 잡혀도 죽지 않는다 — 점프스케어만 뜨고 괴물은 어둠 속으로 사라졌다가 자기 영역 다른 곳에 나타난다
--  near   : 영역 안에서도 가까이(Near) 다가온 소리·사람만 알아챈다(잡히면 목숨 하나)
--  freeze : 음파를 맞으면 그 자리에 굳었다가(Freeze 초) 풀리면 음파 쏜 곳으로 온다(잡히면 목숨 하나)
--  blind  : 앞을 못 본다. 뛰는 발소리·착지 소리만 듣고 쫓는다. 걷거나 웅크리면 지나칠 수 있다(잡히면 목숨 하나)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local SoundBus = require(script.Parent.Parent.SoundBus)

local Sub = {}
local G = (Config.Creatures :: any).Gimmicks

local function roundEvent(): RemoteEvent?
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	return remotes and remotes:FindFirstChild("RoundEvent") :: RemoteEvent?
end

-- 괴물을 자기 구역의 먼 곳으로 옮긴다(플레이어들에게서 떨어진 곳)
local function vanish(self: any)
	local far, best = nil, -1
	for _ = 1, 24 do
		local n = self:randomNode()
		local dmin = math.huge
		for _, p in game:GetService("Players"):GetPlayers() do
			local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r then
				dmin = math.min(dmin, (r.Position - n).Magnitude)
			end
		end
		if dmin > best then
			far, best = n, dmin
		end
	end
	if far then
		self.model:PivotTo(CFrame.new(far + Vector3.new(0, (self.cmod.spawnLift or 2), 0)))
	end
	self.target = nil
	self.goal = nil
	self.waypoints = {}
	self:setState("Wander")
end

function Sub.attach(M: any, kind: string)
	if kind == "scare" then
		-- 잡히면 점프스케어만
		M.catch = function(self: any, p: Player): boolean
			local until_ = (self.cdata.scared or {})[p] or 0
			if os.clock() < until_ then
				return true
			end
			self.cdata.scared = self.cdata.scared or {}
			self.cdata.scared[p] = os.clock() + G.ScareCooldown
			self:note("scared " .. p.Name)
			local ev = roundEvent()
			if ev then
				ev:FireClient(p, "Scare", { creature = self.creature, voice = self.model:GetAttribute("Voice") })
			end
			task.delay(0.3, function()
				if self.alive then
					vanish(self)
				end
			end)
			return true
		end
	elseif kind == "near" then
		-- 자기 영역 안에서도 가까운(Near) 소리·사람만
		M.hear = function(self: any, pos: Vector3, _radius: number, _source: Player?, _kind: string): boolean
			return (pos - self.root.Position).Magnitude > G.Near
		end
		M.cfg.SightLimit = G.Near
	elseif kind == "freeze" then
		-- 음파를 맞으면 그 자리에 굳었다가(Freeze 초), 풀리면 음파 쏜 곳으로
		M.hear = function(self: any, pos: Vector3, radius: number, _source: Player?, k: string): boolean
			if k == "Sonar" and SoundBus.canHear(pos, self.root.Position, radius) then
				self.cdata.frozenUntil = os.clock() + G.Freeze
				self.cdata.frozenAt = pos
				self.model:SetAttribute("Frozen", true)
				self.hum:MoveTo(self.root.Position)
				self.waypoints = {}
				self:note("frozen")
				return true
			end
			return false -- (다른 소리는 기본 반응)
		end
		M.tick = function(self: any, now: number): boolean
			local fu = self.cdata.frozenUntil
			if fu and now < fu then
				self.hum.WalkSpeed = 0
				self.hum:MoveTo(self.root.Position)
				return true
			elseif fu then
				self.cdata.frozenUntil = nil
				self.model:SetAttribute("Frozen", false)
				self:setState(self.state) -- (걸음 속도 되돌리기)
				local at = self.cdata.frozenAt
				self.cdata.frozenAt = nil
				if at and self.state ~= "Chase" then
					self:investigate(at)
				end
			end
			return false
		end
		M.cfg.SightLimit = G.FreezeSight
	elseif kind == "blind" then
		-- 앞을 못 본다: 뛰는 발소리·착지 소리만 듣고 쫓는다
		M.hear = function(self: any, pos: Vector3, radius: number, source: Player?, k: string): boolean
			if (k == "StepRun" or k == "StepLand") and SoundBus.canHear(pos, self.root.Position, radius) then
				if self.state == "Chase" then
					if source and source == self.target then
						self.lastKnown = pos
						self.lastSeen = os.clock()
					end
				elseif source then
					self:note("felt " .. k)
					self:startChase(source, pos)
				end
			end
			return true
		end
		M.cfg.SightLimit = G.BlindTouch
	end
	-- 모든 서브 괴물: 자기 영역(방 + 둘레) 안에서 난 소리·영역 안에 들어온 사람만 알아챈다. 쫓는 중에는 영역 밖까지 따라가고,
	-- 놓치면 수색 뒤 자기 영역으로 돌아간다(배회 지점을 영역 안에서만 고른다)
	local own = M.hear
	M.hear = function(self: any, pos: Vector3, radius: number, source: Player?, k: string): boolean
		if self.state ~= "Chase" and not self:inTerritory(pos) then
			return true
		end
		return if own then own(self, pos, radius, source, k) else false
	end
	M.cfg.SenseInTerritory = true
	-- (근처 감지는 기본 sense 가 cfg.SightLimit 로 줄인 거리 안에서만 한다)
end

return Sub
