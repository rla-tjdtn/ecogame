--!strict
-- 시안 챕터 괴물(Rig = 4): 몸은 시안 조각을 그대로 옮긴 3D 뼈 메시(Shared/CreatureRigs/<id>.meshId 모델 에셋)를 불러와 루트에 붙이고,
-- 클라이언트(RigAnim)가 디자인 자세 프레임으로 뼈를 움직인다. 서버는 길찾기·충돌용 뿌리(HumanoidRootPart) + Humanoid + 메시.
-- 메시가 아직 업로드되지 않은 괴물은 ready() = false 라 게임에 나오지 않는다(Round 가 예전 괴물로 대신).
-- 루트 가운데는 바닥 위 hip + 1.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rig = require(script.Parent.Rig)

local Baked = {}

export type Spec = {
	id: string,
	sprite: string?, -- 그림(같은 괴물 여러 마리면 같은 그림, 소리만 다르게). 없으면 id
	hip: number, -- Humanoid HipHeight
	rootSize: Vector3?,
	cfg: { [string]: any },
	voice: string,
	gimmick: string?, -- 서브 괴물 기믹(Creatures/Sub.luau): "scare" / "near" / "freeze" / "blind"
}

function Baked.sprite(id: string): any
	local folder = ReplicatedStorage.Shared:FindFirstChild("CreatureSprites")
	local ms = folder and folder:FindFirstChild(id)
	return if ms and ms:IsA("ModuleScript") then require(ms) :: any else nil
end

-- 3D 메시(Shared/CreatureRigs/<id>.meshId 의 모델 에셋: 시안 조각 몸 + 뼈 B1..Bn). 한 번 불러와 복제해 쓴다
local meshCache: { [string]: Instance | false } = {}
function Baked.rig(id: string): any
	local folder = ReplicatedStorage.Shared:FindFirstChild("CreatureRigs")
	local ms = folder and folder:FindFirstChild(id)
	return if ms and ms:IsA("ModuleScript") then require(ms) :: any else nil
end
local function meshTemplate(id: string): Instance?
	if meshCache[id] == nil then
		meshCache[id] = false
		local R = Baked.rig(id)
		if R and R.meshId and R.meshId ~= 0 then
			local ok, asset = pcall(function()
				return InsertService:LoadAsset(R.meshId)
			end)
			if ok and asset then
				meshCache[id] = asset
			else
				warn("[Baked] mesh load failed " .. id .. " " .. tostring(asset))
			end
		 end
	end
	return meshCache[id] or nil
end

function Baked.build(spec: Spec, cf: CFrame): Model
	local sid = spec.sprite or spec.id
	local S = Baked.rig(sid) or Baked.sprite(sid)
	local model, _root = Rig.shell(if S then S.name else spec.id, cf, spec.rootSize or Vector3.new(2, 2, 2))
	model:SetAttribute("Rig", 4)
	model:SetAttribute("Creature", sid)
	model:SetAttribute("CreatureId", spec.id)
	model:SetAttribute("Hip", spec.hip)
	if spec.gimmick then
		model:SetAttribute("Gimmick", spec.gimmick)
	end
	-- 3D 몸: 메시 바닥 가운데를 루트 아래 바닥(hip + 1)에 맞춰 붙인다. 음파에 드러날 때만 보인다(클라이언트 Reveal)
	local tpl = meshTemplate(sid)
	local R = Baked.rig(sid)
	if tpl and R then
		local holder = Instance.new("Folder")
		holder.Name = "Mesh"
		local bb = R.bounds
		local center = Vector3.new((bb[1] + bb[4]) / 2, (bb[2] + bb[5]) / 2 - (spec.hip + 1), (bb[3] + bb[6]) / 2)
		for _, d in tpl:Clone():GetDescendants() do
			if d:IsA("MeshPart") then
				d.Parent = holder
				d.Anchored = false
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.Massless = true
				d.CastShadow = false
				d.Transparency = 1
				d.CFrame = _root.CFrame * CFrame.new(center)
				local w = Instance.new("WeldConstraint")
				w.Part0 = _root
				w.Part1 = d
				w.Parent = d
			end
		end
		holder.Parent = model
	end
	Rig.humanoid(model, spec.hip, spec.cfg.WanderSpeed or 6)
	return model
end

-- 괴물 모듈(Creatures/<id>.luau)을 만드는 도우미
function Baked.creature(spec: Spec): any
	local M: any = {}
	M.cfg = spec.cfg
	M.voice = spec.voice
	M.spawnLift = spec.hip + 1
	M.gimmick = spec.gimmick
	-- 게임에 내보내도 되는가: 3D 뼈 메시가 계정에 올라가 있어야 한다(meshId). 없으면 Round 가 예전 괴물을 대신 띄운다(보이지 않는 괴물 금지)
	function M.ready(): boolean
		local R = Baked.rig(spec.sprite or spec.id)
		-- 메시 에셋을 실제로 불러올 수 있어야 한다(못 불러오면 Round 가 예전 괴물로 대신: 보이지 않는 괴물 금지)
		return R ~= nil and type(R.meshId) == "number" and R.meshId ~= 0 and meshTemplate(spec.sprite or spec.id) ~= nil
	end
	function M.build(cf: CFrame): Model
		return Baked.build(spec, cf)
	end
	if spec.gimmick then
		local Sub = require(script.Parent.Sub) :: any
		Sub.attach(M, spec.gimmick)
	end
	return M
end

return Baked
