--!strict
-- 챕터 괴물 전용 뼈대(괴물마다 다른 뼈 구조). 공용 두 팔·두 다리 skeleton() 을 쓰지 않는다.
-- 정의(def)는 괴물 모듈(Creatures/C*.luau)이 만든다:
--   bones = { { name, parent?, joint: Vector3, tip: Vector3 } ... }   (루트 기준 좌표, 부모가 앞에 와야 함)
--   lines = { { bone, a: Vector3, b: Vector3, r: number, red: boolean?, disc: boolean? } ... }  선(음파에 보이는 모서리)
--   balls = { { bone, c: Vector3, r: number } ... }
-- 각 선은 지정한 뼈에 정확히 붙는다(가까운 뼈 찾기 없음). 뼈는 Motor6D "B_<name>", 클라이언트가 Transform 으로 움직인다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Kit = require(script.Parent.Parent.MapKit)
local Faces = require(ReplicatedStorage.Shared.MonsterFaces)
local Config = require(ReplicatedStorage.Shared.Config)
local CollectionService = game:GetService("CollectionService")

local Rig = {}

export type Bone = { name: string, parent: string?, joint: Vector3, tip: Vector3 }
export type Line = { bone: string, a: Vector3, b: Vector3, r: number, red: boolean?, disc: boolean? }
export type Ball = { bone: string, c: Vector3, r: number, red: boolean? }
export type Def = {
	id: string,
	bones: { Bone },
	lines: { Line },
	balls: { Ball }?,
	floorY: number, -- 루트 가운데 기준 바닥 높이
	mass: number?,
}

local function setup(p: BasePart)
	p.Transparency = 1
	p.CastShadow = false
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
end

function Rig.build(model: Model, root: BasePart, cf: CFrame, def: Def): { [string]: BasePart }
	local holder = Instance.new("Folder")
	holder.Name = "Body"
	holder.Parent = model
	local parts: { [string]: BasePart } = {}
	local joints: { [string]: Vector3 } = {}
	for _, b in def.bones do
		local pv = Instance.new("Part")
		pv.Name = "Bone_" .. b.name
		pv.Size = Vector3.new(0.2, 0.2, 0.2)
		setup(pv)
		pv:SetAttribute("SonarShape", "None")
		pv:SetAttribute("Tip", b.tip - b.joint)
		pv.CFrame = cf * CFrame.new(b.joint)
		pv.Parent = holder
		local parentPart: BasePart = if b.parent then parts[b.parent] else root
		assert(parentPart, "bone parent must come first: " .. b.name)
		local m = Instance.new("Motor6D")
		m.Name = "B_" .. b.name
		m.Part0 = parentPart
		m.Part1 = pv
		m.C0 = CFrame.new(b.joint - (if b.parent then joints[b.parent] else Vector3.zero))
		m.C1 = CFrame.identity
		m.Parent = pv
		parts[b.name] = pv
		joints[b.name] = b.joint
	end
	local function attach(p: BasePart, bone: string, red: boolean?)
		setup(p)
		if red then
			p:SetAttribute("SonarColor", Faces.TEETH)
		end
		local bp = parts[bone]
		assert(bp, "unknown bone " .. bone)
		local w = Instance.new("WeldConstraint")
		w.Part0 = bp
		w.Part1 = p
		w.Parent = p
	end
	for _, l in def.lines do
		local shape = if l.disc then "Disc" elseif (l.b - l.a).Magnitude > l.r * 4 then "Line" else "Disc"
		local p = Kit.cylinder(holder, cf:PointToWorldSpace(l.a), cf:PointToWorldSpace(l.b), l.r, { shape = shape })
		p.Name = "Line"
		attach(p, l.bone, l.red)
	end
	for _, b in def.balls or {} do
		local p = Kit.ball(holder, cf:PointToWorldSpace(b.c), b.r)
		p.Name = "Ball"
		attach(p, b.bone, b.red)
	end
	model:SetAttribute("Rig", 3)
	model:SetAttribute("Creature", def.id)
	model:SetAttribute("FloorY", def.floorY)
	model:SetAttribute("Mass", def.mass or 1)
	return parts
end

-- 괴물 모델의 기본 틀: 루트 파트 + Humanoid(점프·기어오르기 끔). build() 에서 Rig.build 전에 부른다
function Rig.shell(name: string, cf: CFrame, rootSize: Vector3?): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute(Config.Tags.Dynamic, true)
	model:SetAttribute("State", "Wander")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = rootSize or Vector3.new(2, 2, 1.2)
	root.Transparency = 1
	root.CanCollide = true
	root.CanTouch = false
	root.CFrame = cf
	root.Parent = model
	model.PrimaryPart = root
	return model, root
end
function Rig.humanoid(model: Model, hip: number, speed: number): Humanoid
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = hip
	hum.WalkSpeed = speed
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.MaxHealth = math.huge
	hum.Health = math.huge
	hum.AutoJumpEnabled = false
	hum.UseJumpPower = true
	hum.JumpPower = 0
	hum.Parent = model
	for _, st in { Enum.HumanoidStateType.Jumping, Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.Swimming, Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Seated, Enum.HumanoidStateType.Dead } do
		hum:SetStateEnabled(st, false)
	end
	CollectionService:AddTag(model, Config.Tags.Monster)
	return hum
end

-- 2D 시안 좌표(px)를 3D 로: 정면 그림(x 가운데 cx, 바닥 y fy, px 당 스터드 k), z 는 직접
function Rig.fromSheet(cx: number, fy: number, k: number, floorY: number): (number, number, number) -> Vector3
	return function(x: number, y: number, z: number): Vector3
		return Vector3.new((x - cx) * k, floorY + (fy - y) * k, z)
	end
end

return Rig
