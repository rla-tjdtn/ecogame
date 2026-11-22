--!strict
-- 도플갱어 연출(클라이언트):
--  1) 변신: 사람 모습(상자 6개)의 윤곽선이 조각나 사방으로 터져 흩날리다 사라진다(음파와 상관없이 보인다).
--  2) 눈: 음파가 괴물 모습의 도플갱어에 닿으면, 두 눈(이름 Eye)이 음파 선보다 조금 더 오래 하얗게 빛나다 꺼진다.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)

local DoppelFx = {}
DoppelFx.bursts = 0 -- (테스트) 터진 횟수
DoppelFx.lastShards = 0 -- (테스트) 마지막으로 터질 때 만든 조각 수

local WHITE = Color3.new(1, 1, 1)
local folder: Folder? = nil
local function getFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "DoppelFx"
	f.Parent = workspace
	folder = f
	return f
end

type Shard = { part: Part, pos: Vector3, vel: Vector3, rot: CFrame, spin: Vector3, born: number, life: number }
local shards: { Shard } = {}

local function newShard(cf: CFrame, len: number, vel: Vector3, life: number, now: number)
	local p = Instance.new("Part")
	p.Name = "Shard"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = WHITE
	p.Size = Vector3.new(0.07, 0.07, math.max(0.1, len))
	p.CFrame = cf
	p.Parent = getFolder()
	local spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 14
	table.insert(shards, { part = p, pos = cf.Position, vel = vel, rot = cf.Rotation, spin = spin, born = now, life = life })
end

-- 상자 하나의 12 모서리를 조각으로
local EDGES = {
	{ Vector3.new(-1, -1, -1), Vector3.new(1, -1, -1) },
	{ Vector3.new(-1, 1, -1), Vector3.new(1, 1, -1) },
	{ Vector3.new(-1, -1, 1), Vector3.new(1, -1, 1) },
	{ Vector3.new(-1, 1, 1), Vector3.new(1, 1, 1) },
	{ Vector3.new(-1, -1, -1), Vector3.new(-1, 1, -1) },
	{ Vector3.new(1, -1, -1), Vector3.new(1, 1, -1) },
	{ Vector3.new(-1, -1, 1), Vector3.new(-1, 1, 1) },
	{ Vector3.new(1, -1, 1), Vector3.new(1, 1, 1) },
	{ Vector3.new(-1, -1, -1), Vector3.new(-1, -1, 1) },
	{ Vector3.new(1, -1, -1), Vector3.new(1, -1, 1) },
	{ Vector3.new(-1, 1, -1), Vector3.new(-1, 1, 1) },
	{ Vector3.new(1, 1, -1), Vector3.new(1, 1, 1) },
}

function DoppelFx.burst(data: { at: Vector3, boxes: { { cf: CFrame, size: Vector3 } } })
	local cam = workspace.CurrentCamera
	if not data or not data.at or (cam and (cam.CFrame.Position - data.at).Magnitude > 160) then
		return
	end
	local now = os.clock()
	local made = 0
	local center = data.at
	for _, b in data.boxes or {} do
		local half = b.size / 2
		for _, e in EDGES do
			-- 모서리를 두 토막으로 나눠 더 잘게 부서지게
			local a = b.cf:PointToWorldSpace(e[1] * half)
			local c = b.cf:PointToWorldSpace(e[2] * half)
			for k = 0, 1 do
				local p0 = a:Lerp(c, k * 0.5)
				local p1 = a:Lerp(c, k * 0.5 + 0.5)
				local mid = (p0 + p1) / 2
				local out = mid - center
				out = if out.Magnitude > 0.01 then out.Unit else Vector3.yAxis
				local vel = out * (10 + math.random() * 18) + Vector3.new(0, 6 + math.random() * 10, 0)
				newShard(CFrame.lookAt(mid, p1), (p1 - p0).Magnitude, vel, 1.1 + math.random() * 0.7, now)
				made += 1
			end
		end
	end
	-- 몸 안쪽에서 튀어나오는 잔조각
	for _ = 1, 24 do
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5)
		dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.yAxis
		local p = center + Vector3.new(0, math.random() * 2 - 0.5, 0)
		newShard(CFrame.lookAt(p, p + dir), 0.2 + math.random() * 0.5, dir * (14 + math.random() * 16), 0.8 + math.random() * 0.6, now)
		made += 1
	end
	DoppelFx.bursts += 1
	DoppelFx.lastShards = made
end

-- ── 눈 ──
local eyeUntil: { [Model]: { from: number, to: number } } = setmetatable({}, { __mode = "k" }) :: any
local litEyes: { [BasePart]: boolean } = {}

function DoppelFx.onPulse(origin: Vector3)
	local S = Config.Sonar
	local now = os.clock()
	for _, m in CollectionService:GetTagged(Config.Tags.Doppel) do
		if m:IsA("Model") and m.PrimaryPart and m:GetAttribute("Form") == "Beast" then
			local d = (m.PrimaryPart.Position - origin).Magnitude
			if d <= S.Radius + 2 then
				local from = now + math.min(1, d / 60)
				-- (몸이 보이는 10초 동안 눈도 빛난다)
				eyeUntil[m] = { from = from, to = from + ((S :: any).MonsterRevealSeconds or (S.Hold + Config.Doppel.EyeLinger)) }
			end
		end
	end
end

local function setEye(p: BasePart, on: boolean)
	if on then
		p.Transparency = 0
		p.Material = Enum.Material.Neon
		p.Color = WHITE
		litEyes[p] = true
	else
		p.Transparency = 1
		litEyes[p] = nil
	end
end

-- (테스트) 지금 빛나는 눈 수
function DoppelFx.litEyeCount(): number
	local n = 0
	for p in litEyes do
		if p.Parent then
			n += 1
		end
	end
	return n
end

local moveParts: { BasePart } = {}
local moveCFs: { CFrame } = {}
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	-- 조각: 날아가며 돌고 떨어지다 검게(보이지 않게) 사라진다
	local i = 1
	while i <= #shards do
		local s = shards[i]
		local age = now - s.born
		if age >= s.life or not s.part.Parent then
			s.part:Destroy()
			shards[i] = shards[#shards]
			shards[#shards] = nil
		else
			s.vel += Vector3.new(0, -45 * dt, 0)
			s.vel *= (1 - math.min(0.9, dt * 1.2))
			s.pos += s.vel * dt
			s.rot = s.rot * CFrame.Angles(s.spin.X * dt, s.spin.Y * dt, s.spin.Z * dt)
			table.insert(moveParts, s.part)
			table.insert(moveCFs, CFrame.new(s.pos) * s.rot)
			local fade = math.clamp((age - s.life * 0.35) / (s.life * 0.65), 0, 1)
			local v = 1 - fade
			s.part.Color = Color3.new(v, v, v)
			i += 1
		end
	end
	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveCFs, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(moveParts)
		table.clear(moveCFs)
	end
	-- 눈
	for m, w in eyeUntil do
		local on = now >= w.from and now <= w.to and m.Parent ~= nil and m:GetAttribute("Form") == "Beast"
		local beast = m:FindFirstChild("Beast")
		if beast then
			for _, p in beast:GetChildren() do
				if p:IsA("BasePart") and p.Name == "Eye" then
					if on ~= (litEyes[p] == true) then
						setEye(p, on)
					end
				end
			end
		end
		if now > w.to then
			eyeUntil[m] = nil
		end
	end
end)

function DoppelFx.clear()
	for _, s in shards do
		s.part:Destroy()
	end
	table.clear(shards)
	table.clear(litEyes)
end

return DoppelFx
