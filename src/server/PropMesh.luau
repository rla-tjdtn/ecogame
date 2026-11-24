--!strict
-- 소품 메시: 기본 도형으로 지은 소품(Model)을 실제 3D 메시 에셋 하나로 바꿔 입힌다.
--   PropMesh.dress(m, key, cf, scale?) — 소품 빌더가 다 지은 뒤 한 줄로 부른다. cf = 메시를 만든 소품 좌표계(art/props/models 의 원점),
--   scale = 축마다 늘이기(길이가 바뀌는 소품). 메시 에셋이 없거나 못 불러왔으면 아무것도 하지 않는다 → 예전 기본 도형 그대로(대체).
-- 바꿔 입히면:
--   · 메시 파트 1개(검은 몸, 부딪히지 않음, 공간 쿼리 제외)가 음파 선을 낸다: SonarShape = "Mesh", SonarMesh = key
--     → 클라이언트가 Shared/PropMeshData 의 미리 뽑은 선(윤곽·꺾임선)과 실루엣(원통·구)을 그린다.
--   · 보이던 기본 도형 중 부딪히거나(CanCollide) 쿼리되거나(CanQuery) 음파·소리를 막던 것은 보이지 않게 남긴다(SonarHidden):
--     충돌·괴물 레이·소리 판정·음파 전파 칸이 예전과 똑같다. 아무 역할 없는 장식 도형만 지운다(파트 수가 줄어든다).
--   · 이미 보이지 않던 파트(충돌 상자·소리 발생기)와 태그가 붙은 특수 파트는 건드리지 않는다.
-- 에셋: 챕터 묶음마다 모델 에셋 하나(art/props/upload.js), 서버가 처음 한 번 InsertService:LoadAsset 으로 불러와 복제한다.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(ReplicatedStorage.Shared.PropMeshData)

local PropMesh = {}
local TAG = Config.Tags.Renderable
local BLACK = Color3.new(0, 0, 0)
local SIM = typeof(game) ~= "Instance" -- (오프라인 시뮬레이터 art/props/sim.js 에서는 game 이 흉내 표)

-- 꺼 두기(문제가 생기면 Config 없이도 바로 되돌릴 수 있게): ServerStorage 속성 PropMeshOff = true
local function disabled(): boolean
	if SIM then
		return true
	end
	local ok, ss = pcall(function()
		return game:GetService("ServerStorage")
	end)
	return ok and ss ~= nil and (ss :: any):GetAttribute("PropMeshOff") == true
end

-- ── 에셋 불러오기(묶음마다 한 번) ──
type Group = { state: string, parts: { [string]: MeshPart } }
local groups: { [string]: Group } = {}
PropMesh.stats = { dressed = 0, fallback = 0, removed = 0, hidden = 0, loadFail = 0 }

local function load(name: string): Group
	local g = groups[name]
	if g then
		return g
	end
	g = { state = "loading", parts = {} }
	groups[name] = g
	local id = Data.assets[name]
	if type(id) ~= "number" or id == 0 then
		g.state = "none"
		return g
	end
	task.spawn(function()
		local ok, res = pcall(function()
			return game:GetService("InsertService"):LoadAsset(id)
		end)
		if ok and res then
			for _, d in (res :: Instance):GetDescendants() do
				if d:IsA("MeshPart") then
					g.parts[d.Name] = d
				end
			end
			g.state = "ready"
		else
			g.state = "fail"
			PropMesh.stats.loadFail += 1
			warn("[PropMesh] load failed", name, id, res)
		end
	end)
	return g
end

-- 서버가 켜질 때 전부 미리 불러 둔다(스테이지를 처음 지을 때 기다리지 않게)
function PropMesh.preload()
	if SIM then
		return
	end
	for name in Data.assets do
		load(name)
	end
end

local function template(key: string): MeshPart?
	local gname = Data.groupOf(key)
	if not gname then
		return nil
	end
	local g = load(gname)
	-- 아직 불러오는 중이면 잠깐 기다린다(처음 한 번, 최대 15초)
	local t0 = os.clock()
	while g.state == "loading" and os.clock() - t0 < 15 do
		task.wait(0.1)
	end
	if g.state ~= "ready" then
		return nil
	end
	return g.parts[(key:gsub("%.", "_"))]
end

-- SonarWorld.blocksSound 와 같은 규칙(숨기기 전에 값을 속성으로 굳혀 둔다)
local function blocksSound(p: BasePart): boolean
	local b = p:GetAttribute("SonarBlocks")
	if type(b) == "boolean" then
		return b
	end
	if not p.CanCollide or p.Transparency >= 1 then
		return false
	end
	local s = p.Size
	local dims = { s.X, s.Y, s.Z }
	table.sort(dims)
	return dims[1] >= 0.9 and dims[2] >= 0.9
end

local function special(p: BasePart): boolean
	for _, t in p:GetTags() do
		if t ~= TAG then
			return true
		end
	end
	return false
end

-- parts: 바꿀 파트(없으면 m 의 모든 자손). parent: 메시를 넣을 곳(없으면 m)
function PropMesh.dress(m: Instance, key: string, cf: CFrame, scale: Vector3?, parts: { BasePart }?, parent: Instance?)
	if disabled() then
		return
	end
	local d = Data.get(key)
	if not d then
		PropMesh.stats.fallback += 1
		return
	end
	local tpl = template(key)
	if not tpl then
		PropMesh.stats.fallback += 1
		return
	end
	local sc = scale or Vector3.one
	local list: { BasePart } = parts or {}
	if not parts then
		for _, x in m:GetDescendants() do
			if x:IsA("BasePart") then
				table.insert(list, x)
			end
		end
	end
	local mp = tpl:Clone()
	mp.Name = "PropMesh"
	mp.Anchored = true
	mp.CanCollide = false
	mp.CanQuery = false
	mp.CanTouch = false
	mp.CastShadow = false
	mp.Color = BLACK
	mp.Material = Enum.Material.SmoothPlastic
	mp.Reflectance = 0
	mp.TextureID = ""
	for _, c in mp:GetChildren() do
		c:Destroy() -- (가져온 SurfaceAppearance 등)
	end
	mp.Size = d.size * sc
	mp.CFrame = cf * CFrame.new(d.center * sc)
	mp:SetAttribute("SonarShape", "Mesh")
	mp:SetAttribute("SonarMesh", key)
	if scale then
		mp:SetAttribute("SonarMeshScale", sc)
	end
	CollectionService:AddTag(mp, TAG)
	for _, p in list do
		if p.Transparency < 1 and CollectionService:HasTag(p, TAG) and not special(p) then
			local blocks = blocksSound(p)
			if blocks or p.CanCollide or p.CanQuery then
				p:SetAttribute("SonarBlocks", blocks)
				p:SetAttribute("SonarHidden", true)
				p.Transparency = 1
				PropMesh.stats.hidden += 1
			else
				p:Destroy()
				PropMesh.stats.removed += 1
			end
		end
	end
	mp.Parent = parent or m
	PropMesh.stats.dressed += 1
end

task.defer(PropMesh.preload)

return PropMesh
