--!strict
-- 음파에 맞은 괴물은 어그로가 풀릴 때까지 모습이 계속 보인다(이 클라이언트에서만, 팀원 음파도 포함).
--  · 음파(내 것·팀원 것)가 괴물에 닿으면(반경 안, 벽 1장 이하) "드러남"
--  · 드러난 동안 몸의 선(음파 대상 파트)을 흰 네온으로 켜 두어, 움직이는 모습이 계속 보인다
--    (도플갱어 사람 모습의 상자는 상자 윤곽선 SelectionBox)
--  · 어그로가 풀리면(메인 괴물: 다시 배회 Wander, 도플갱어 사람 모습: 들키지 않음) 다시 안 보인다

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)

local Reveal = {}
local S = Config.Sonar
local TAGS = Config.Tags

type Entry = { from: number, since: number, parts: { BasePart }, boxes: { SelectionBox }, ver: number, on: boolean }
local revealed: { [Model]: Entry } = {}

-- 어그로 중인가: 배회(Wander)가 아니면 어그로. 도플갱어 사람 모습은 들켰을 때만
local function aggro(m: Model): boolean
	local st = m:GetAttribute("State")
	if m:GetAttribute("Form") == "Disguise" then
		return m:GetAttribute("Discovered") == true
	end
	return st ~= nil and st ~= "Wander"
end

-- 음파 시작점에서 괴물까지 벽이 1장 이하인가(괴물 소리 판정과 같은 기준)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
local function wallsBetween(a: Vector3, b: Vector3): number
	local stage = workspace:FindFirstChild("Stage")
	if not stage then
		return 0
	end
	rayParams.FilterDescendantsInstances = { stage }
	local n = 0
	local from = a
	local dir = b - a
	for _ = 1, 3 do
		local hit = workspace:Raycast(from, dir, rayParams)
		if not hit then
			break
		end
		n += 1
		local step = dir.Unit * 0.6
		from = hit.Position + step
		dir = b - from
		if dir.Magnitude < 0.5 or dir:Dot(b - a) <= 0 then
			break
		end
	end
	return n
end

function Reveal.onPulse(origin: Vector3)
	local now = os.clock()
	for _, inst in CollectionService:GetTagged(TAGS.Monster) do
		local m = inst :: Model
		if m:IsA("Model") and m.PrimaryPart then
			local p = m.PrimaryPart.Position
			local d = (p - origin).Magnitude
			if d <= S.Radius + 3 and wallsBetween(origin, p) <= 1 then
				local e = revealed[m]
				local from = now + math.min(1, d / 60) -- 파동이 닿을 즈음부터
				if e then
					e.since = math.min(e.since, now)
				else
					revealed[m] = { from = from, since = now, parts = {}, boxes = {}, ver = -1, on = false }
				end
			end
		end
	end
end

local WHITE = Color3.new(S.LineColor.R, S.LineColor.G, S.LineColor.B)
local LEVEL = S.BaseLevel

local function collect(m: Model, e: Entry)
	-- 이전에 켠 것 정리
	for _, p in e.parts do
		if p.Parent then
			p.Transparency = 1
		end
	end
	for _, b in e.boxes do
		b:Destroy()
	end
	table.clear(e.parts)
	table.clear(e.boxes)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and CollectionService:HasTag(d, TAGS.Renderable) then
			if d.Shape == Enum.PartType.Cylinder then
				table.insert(e.parts, d)
			else
				-- 상자(도플갱어 사람 모습): 모서리 윤곽선
				local sb = Instance.new("SelectionBox")
				sb.Name = "RevealBox"
				sb.Adornee = d
				sb.Color3 = WHITE
				sb.LineThickness = 0.04
				sb.SurfaceTransparency = 1
				sb.Transparency = 1 - LEVEL
				sb.Visible = false
				sb.Parent = d
				table.insert(e.boxes, sb)
			end
		end
	end
	e.ver = (m:GetAttribute("BodyVersion") :: number?) or 0
	e.on = false
end

local function show(e: Entry, on: boolean)
	if e.on == on then
		return
	end
	e.on = on
	for _, p in e.parts do
		if p.Parent and p.Name ~= "Eye" then -- (눈은 DoppelFx 가 따로 빛나게 한다)
			if on then
				p.Material = Enum.Material.Neon
				p.Color = Color3.new(WHITE.R * LEVEL, WHITE.G * LEVEL, WHITE.B * LEVEL)
				p.Transparency = 0
			else
				p.Transparency = 1
			end
		end
	end
	for _, b in e.boxes do
		b.Visible = on
	end
end

-- (테스트) 지금 계속 보이는 괴물 수
function Reveal.count(): number
	local n = 0
	for m, e in revealed do
		if e.on and m.Parent then
			n += 1
		end
	end
	return n
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.1 then
		return
	end
	acc = 0
	local now = os.clock()
	for m, e in revealed do
		if not m.Parent then
			revealed[m] = nil
			continue
		end
		local ver = (m:GetAttribute("BodyVersion") :: number?) or 0
		if ver ~= e.ver then
			collect(m, e)
		end
		if now < e.from then
			continue
		end
		if aggro(m) then
			show(e, true)
		elseif now - e.since > 1.2 then
			-- (음파를 듣고 멈칫하기까지 잠깐 기다린 뒤에도) 어그로가 아니면 끝
			show(e, false)
			for _, b in e.boxes do
				b:Destroy()
			end
			revealed[m] = nil
		end
	end
end)

function Reveal.clear()
	for m, e in revealed do
		show(e, false)
		for _, b in e.boxes do
			b:Destroy()
		end
		revealed[m] = nil
	end
end

return Reveal
