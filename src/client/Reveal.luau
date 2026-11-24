--!strict
-- 음파에 맞은 괴물은 10초 동안(Config.Sonar.MonsterRevealSeconds) 지금 모습 그대로(움직이는 그대로) 보인다.
-- 잔상(그 순간 모습으로 굳은 음파 선)이 아니라 실제 몸을 켜 둔다. 이 클라이언트에서만, 팀원 음파도 포함. 다시 맞으면 10초가 다시 시작.
--  · 음파 반경 안, 벽 1장 이하면 맞은 것(괴물 소리 판정과 같은 기준)
--  · 메인 괴물·도플갱어 괴물: 몸의 선(원통)을 흰 네온으로
--  · 도플갱어 사람 모습: 진짜 아바타면 팀원처럼 윤곽선(Highlight), 상자 몸이면 상자 윤곽선(SelectionBox)
--  · 보이는 동안 음파는 그 괴물의 굳은 선(잔상)을 따로 그리지 않는다(SonarWorld.skipMonster)

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)

local Reveal = {}
local S = Config.Sonar
local TAGS = Config.Tags
local SECONDS = (S :: any).MonsterRevealSeconds or 10

type Entry = { from: number, to: number, parts: { BasePart }, boxes: { SelectionBox }, hl: Highlight?, ver: number, on: boolean, dark: boolean? }
local revealed: { [Model]: Entry } = {}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.RespectCanCollide = true -- (서버 괴물 소리 판정과 같게: 부딪히지 않는 장식은 벽으로 세지 않는다)
local function wallsBetween(a: Vector3, b: Vector3): number
	local stage = workspace:FindFirstChild("Stage")
	if not stage then
		return 0
	end
	rayParams.FilterDescendantsInstances = { stage }
	local n = 0
	local from = a
	for _ = 1, 3 do
		local dir = b - from
		if dir.Magnitude < 0.5 then
			break
		end
		local hit = workspace:Raycast(from, dir, rayParams)
		if not hit then
			break
		end
		n += 1
		from = hit.Position + dir.Unit * 0.6
		if (b - from):Dot(b - a) <= 0 then
			break
		end
	end
	return n
end

-- 진짜 아바타를 입은 사람 모습 도플갱어: 늘 보인다(Mates 가 팀원처럼 윤곽선). 음파로 따로 드러낼 필요가 없다
function Reveal.disguised(m: Model): boolean
	return m:GetAttribute("Form") == "Disguise" and m:GetAttribute("AvatarOf") ~= nil
end

function Reveal.onPulse(origin: Vector3)
	local now = os.clock()
	for _, inst in CollectionService:GetTagged(TAGS.Monster) do
		local m = inst :: Model
		if m:IsA("Model") and m.PrimaryPart and not Reveal.disguised(m) then
			local p = m.PrimaryPart.Position
			local d = (p - origin).Magnitude
			if d <= S.Radius + 3 and wallsBetween(origin, p) <= 1 then
				local from = now + math.min(1, d / 60) -- 파동이 닿을 즈음부터
				local e = revealed[m]
				if e then
					e.from = math.min(e.from, from)
					e.to = math.max(e.to, from + SECONDS)
				else
					revealed[m] = { from = from, to = from + SECONDS, parts = {}, boxes = {}, hl = nil, ver = -1, on = false }
				end
			end
		end
	end
end

-- 음파가 이 괴물의 굳은 선(잔상)을 그리지 않아도 되는가(지금 보이는 중이거나 곧 보일 것)
-- 지금 음파에 걸려 있는가(파동이 닿은 뒤 ~ 10초): 이 동안만 그 괴물 발소리가 들린다
function Reveal.active(m: Model): boolean
	local e = revealed[m]
	if not e then
		return false
	end
	local now = os.clock()
	return now >= e.from and now <= e.to
end

function Reveal.has(m: Model): boolean
	return revealed[m] ~= nil
end

local LINE = Color3.new(S.LineColor.R * S.BaseLevel, S.LineColor.G * S.BaseLevel, S.LineColor.B * S.BaseLevel)

local function show(e: Entry, on: boolean)
	if e.on == on then
		return
	end
	e.on = on
	for _, p in e.parts do
		if p.Parent and p.Name ~= "Eye" then -- (도플갱어 눈은 DoppelFx 가 따로 빛나게 한다)
			if on and e.dark then
				-- 3D 시안 괴물(빛 없음): 시안 흰 선 메시(Lines)는 흰 네온이라 캄캄해도 스스로 보이고,
				-- 몸(Body)은 검게 두어 뒤쪽 선을 가린다. 바깥 테두리는 흰 윤곽선(Highlight)
				if string.find(p.Name, "Lines", 1, true) or string.find(p.Name, "Outline", 1, true) then
					p.Material = Enum.Material.Neon
					p.Color = LINE
				else
					p.Material = Enum.Material.SmoothPlastic
					p.Color = Color3.new(0, 0, 0)
				end
				p.Transparency = 0
			elseif on then
				p.Material = Enum.Material.Neon
				p.Color = LINE
				p.Transparency = 0
			else
				p.Transparency = 1
			end
		end
	end
	for _, b in e.boxes do
		b.Visible = on
	end
	if e.hl then
		e.hl.Enabled = on
	end
end

local function release(e: Entry)
	show(e, false)
	for _, b in e.boxes do
		b:Destroy()
	end
	if e.hl then
		e.hl:Destroy()
	end
	table.clear(e.parts)
	table.clear(e.boxes)
	e.hl = nil
end

local function collect(m: Model, e: Entry)
	local wasOn = e.on
	release(e)
	local avatar = m:GetAttribute("Form") == "Disguise" and m:GetAttribute("AvatarOf") ~= nil
	if avatar then
		-- 진짜 아바타 모습: 몸을 보이게 하고 팀원과 같은 흰 윤곽선
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				local top: Instance? = d
				while top and top.Parent ~= m do
					top = top.Parent
				end
				if top and top:GetAttribute("DisguisePart") then
					table.insert(e.parts, d)
				end
			end
		end
		local hl = Instance.new("Highlight")
		hl.Name = "RevealOutline"
		hl.Adornee = m
		hl.FillTransparency = 1
		hl.OutlineColor = Color3.new(1, 1, 1)
		hl.OutlineTransparency = 0.3
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Enabled = false
		hl.Parent = m
		e.hl = hl
	elseif m:GetAttribute("Rig") == 4 and m:FindFirstChild("Mesh") then
		e.dark = true
		for _, d in (m:FindFirstChild("Mesh") :: Instance):GetDescendants() do
			if d:IsA("MeshPart") then
				table.insert(e.parts, d)
			end
		end
		-- 외곽선: 메시에 흰 껍질(Outline: 부풀려 뒤집은 몸)이 있으면 그것이 바깥 테두리와 부위가 겹치는 테두리를 그린다(시안처럼, 가늘게).
		-- 껍질이 없는 예전 메시만 로블록스 윤곽선(Highlight)으로 대신
		if not (m:FindFirstChild("Mesh") :: Instance):FindFirstChild("Outline", true) then
			local hl = Instance.new("Highlight")
			hl.Name = "RevealOutline"
			hl.Adornee = m
			hl.FillTransparency = 1
			hl.OutlineColor = Color3.new(1, 1, 1)
			hl.OutlineTransparency = 0.4
			hl.DepthMode = Enum.HighlightDepthMode.Occluded
			hl.Enabled = false
			hl.Parent = m
			e.hl = hl
		end
	else
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and CollectionService:HasTag(d, TAGS.Renderable) then
				if d.Shape == Enum.PartType.Cylinder then
					table.insert(e.parts, d)
				else
					local sb = Instance.new("SelectionBox")
					sb.Name = "RevealBox"
					sb.Adornee = d
					sb.Color3 = Color3.new(1, 1, 1)
					sb.LineThickness = 0.04
					sb.SurfaceTransparency = 1
					sb.Transparency = 1 - S.BaseLevel
					sb.Visible = false
					sb.Parent = d
					table.insert(e.boxes, sb)
				end
			end
		end
	end
	e.ver = (m:GetAttribute("BodyVersion") :: number?) or 0
	e.on = false
	if wasOn then
		show(e, true)
	end
end

-- (테스트) 지금 보이는 괴물 수
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
	if acc < 0.05 then
		return
	end
	acc = 0
	local now = os.clock()
	for m, e in revealed do
		if not m.Parent or now > e.to then
			release(e)
			revealed[m] = nil
			continue
		end
		local ver = (m:GetAttribute("BodyVersion") :: number?) or 0
		if ver ~= e.ver then
			collect(m, e) -- (도플갱어가 옷을 갈아입거나 변신하거나 입을 벌리면 다시 모은다)
		end
		if now >= e.from then
			show(e, true)
		end
	end
end)

function Reveal.clear()
	for m, e in revealed do
		release(e)
		revealed[m] = nil
	end
end

return Reveal
