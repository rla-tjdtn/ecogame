--!strict
-- 챕터 괴물(Rig = 3) 전용 애니메이션 구동기. 괴물마다 뼈 구조와 이동 방식이 달라서,
-- 모델 속성 Creature(예 "c1h")에 맞는 모듈 Creatures/<id>.luau 의 step(body, dt) 이 뼈(Motor6D)를 직접 움직인다.
-- 공용 두 팔·두 다리 MonsterAnim(Rig = 2)과는 따로 돈다.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)

local CreatureAnim = {}
CreatureAnim.range = 170
CreatureAnim.onStep = nil :: ((Model, Vector3, number) -> ())?
CreatureAnim.stats = {} :: { [string]: { frames: number, steps: number, maxAngle: number } }

export type Body = {
	model: Model,
	root: BasePart,
	id: string,
	m: { [string]: Motor6D }, -- 뼈 이름 → 모터
	rest: { [string]: CFrame }, -- 모터 C0(쉬는 자세)
	tip: { [string]: Vector3 }, -- 뼈 길이 벡터(Tip 속성)
	t: number, -- 누적 시간
	phase: number, -- 보행 위상(괴물 모듈이 쓴다)
	speed: number, -- 수평 속도(부드럽게)
	vel: Vector3, -- 루트 기준 속도(부드럽게)
	state: string,
	data: { [string]: any }, -- 괴물 모듈 마음대로
	step: (at: Vector3, hit: number) -> (), -- 착지 소리
}

local mods: { [string]: any } = {}
local function modFor(id: string): any
	if mods[id] == nil then
		local folder = script.Parent:FindFirstChild("Creatures")
		local ms = folder and folder:FindFirstChild(id)
		mods[id] = if ms and ms:IsA("ModuleScript") then require(ms) :: any else false
	end
	return mods[id] or nil
end

local bodies: { [Model]: Body } = {}
local function build(model: Model, id: string): Body?
	local root = model.PrimaryPart
	if not root then
		return nil
	end
	local m: { [string]: Motor6D } = {}
	local rest: { [string]: CFrame } = {}
	local tip: { [string]: Vector3 } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and string.sub(d.Name, 1, 2) == "B_" then
			local name = string.sub(d.Name, 3)
			m[name] = d
			rest[name] = d.C0
			local t = d.Part1 and d.Part1:GetAttribute("Tip")
			tip[name] = if typeof(t) == "Vector3" then t else Vector3.zero
		end
	end
	local b: Body
	b = {
		model = model,
		root = root,
		id = id,
		m = m,
		rest = rest,
		tip = tip,
		t = math.random() * 10,
		phase = math.random(),
		speed = 0,
		vel = Vector3.zero,
		state = "Wander",
		data = {},
		step = function(at: Vector3, hit: number)
			local st = CreatureAnim.stats[id]
			if st then
				st.steps += 1
			end
			if CreatureAnim.onStep then
				CreatureAnim.onStep(model, at, hit)
			end
		end,
	}
	CreatureAnim.stats[id] = CreatureAnim.stats[id] or { frames = 0, steps = 0, maxAngle = 0 }
	return b
end

-- 공용 도구 ------------------------------------------------------------
-- 뼈 하나를 쉬는 자세 기준으로 회전(라디안, 뼈 로컬 축 X=끄덕, Y=좌우, Z=기울기)
function CreatureAnim.pose(b: Body, name: string, rx: number, ry: number, rz: number, offset: Vector3?)
	local mo = b.m[name]
	if not mo then
		return
	end
	mo.Transform = (if offset then CFrame.new(offset) else CFrame.identity) * CFrame.fromEulerAnglesYXZ(rx, ry, rz)
	local st = CreatureAnim.stats[b.id]
	if st then
		st.maxAngle = math.max(st.maxAngle, math.abs(rx), math.abs(ry), math.abs(rz))
	end
end
-- 0~1 위상에서 부드러운 파형
function CreatureAnim.wave(p: number): number
	return math.sin(p * math.pi * 2)
end
-- 발 들기 곡선(0~1 → 0 → 1 → 0, duty 비율만큼만 들림)
function CreatureAnim.lift(p: number, duty: number): number
	local q = (p % 1) / duty
	return if q < 1 then math.sin(q * math.pi) else 0
end
function CreatureAnim.approach(cur: number, target: number, rate: number, dt: number): number
	return cur + (target - cur) * (1 - math.exp(-rate * dt))
end

RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 1 / 20)
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	for _, inst in CollectionService:GetTagged(Config.Tags.Monster) do
		local model = inst :: Model
		if model:IsA("Model") and model.Parent and model:GetAttribute("Rig") == 3 then
			local id = model:GetAttribute("Creature")
			local root = model.PrimaryPart
			if typeof(id) == "string" and root and (root.Position - camPos).Magnitude < CreatureAnim.range then
				local mod = modFor(id)
				if mod then
					local b = bodies[model]
					if not b or b.root ~= root then
						b = build(model, id)
						if b then
							bodies[model] = b
							if mod.init then
								mod.init(b)
							end
						end
					end
					if b then
						local v = root.AssemblyLinearVelocity
						local flat = Vector3.new(v.X, 0, v.Z)
						b.speed = CreatureAnim.approach(b.speed, flat.Magnitude, 8, dt)
						b.vel = b.vel:Lerp(root.CFrame:VectorToObjectSpace(flat), math.min(1, dt * 8))
						b.state = (model:GetAttribute("State") :: string?) or "Wander"
						b.t += dt
						mod.step(b, dt)
						local st = CreatureAnim.stats[id]
						if st then
							st.frames += 1
						end
					end
				end
			end
		end
	end
	for model in bodies do
		if not model.Parent then
			bodies[model] = nil
		end
	end
end)

function CreatureAnim.reset()
	for _, st in CreatureAnim.stats do
		st.frames, st.steps, st.maxAngle = 0, 0, 0
	end
end

return CreatureAnim
