--!strict
-- 문: E(ProximityPrompt)로 열고 닫는다. 경첩을 축으로 90도 회전.
-- 문짝은 움직이므로 SonarDynamic(음파가 닿는 순간의 위치로 윤곽선), 닫혀 있으면 음파·소리를 막는다.
-- 괴물은 문을 지나갈 수 있도록 경로 계산에서 문짝을 무시(PathfindingModifier.PassThrough)하고, 가까이 가면 연다.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.MapKit)
local SoundBus = require(script.Parent.SoundBus)

local Doors = {}

type Door = {
	model: Model,
	panel: Part,
	prompt: ProximityPrompt,
	hinge: CFrame,
	closedRel: CFrame,
	swing: number,
	open: boolean,
	busy: boolean,
}

local doors: { Door } = {}

local function setPose(d: Door, t: number)
	local rot = CFrame.Angles(0, d.swing * (math.pi / 2) * t, 0)
	d.panel.CFrame = d.hinge * rot * d.closedRel
end

-- 문짝이나 그 근처에 캐릭터(플레이어·괴물)가 겹쳐 있는가
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
local function someoneInside(panel: BasePart): boolean
	overlap.FilterDescendantsInstances = { panel.Parent :: Instance }
	for _, p in workspace:GetPartBoundsInBox(panel.CFrame, panel.Size + Vector3.new(0.4, 0, 0.6), overlap) do
		local m = p:FindFirstAncestorOfClass("Model")
		if m and m:FindFirstChildOfClass("Humanoid") then
			return true
		end
	end
	return false
end

-- from: 여는 사람(또는 괴물) 위치. 열 때 그 반대쪽으로 열려서 문짝이 사람을 치거나 가두지 않는다
function Doors.toggle(d: Door, source: Player?, from: Vector3?)
	if d.busy then
		return
	end
	d.busy = true
	local opening = not d.open
	if opening then
		local pos = from
		if not pos and source and source.Character then
			local r = source.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			pos = r and r.Position
		end
		if pos then
			-- 문짝은 경첩 기준 -Z*swing 쪽으로 열린다: 여는 사람이 있는 쪽의 반대
			d.swing = if (pos - d.hinge.Position):Dot(d.hinge.ZVector) >= 0 then 1 else -1
		end
	end
	-- 움직이는 동안은 부딪히지 않는다(끼임 방지)
	d.panel.CanCollide = false
	d.open = opening
	d.model:SetAttribute("Open", opening)
	d.prompt.ActionText = if opening then "문 닫기" else "문 열기"
	SoundBus.emit(d.panel.Position, Config.Noise.Door, source, "Door")
	task.spawn(function()
		local dur = 0.55
		local t0 = os.clock()
		while true do
			local a = math.clamp((os.clock() - t0) / dur, 0, 1)
			local e = 1 - (1 - a) * (1 - a)
			setPose(d, if opening then e else 1 - e)
			if a >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		d.busy = false
		-- 멈춘 뒤: 아무도 겹쳐 있지 않을 때 다시 단단해진다
		local waited = 0
		while d.panel.Parent and someoneInside(d.panel) and waited < 10 do
			task.wait(0.2)
			waited += 0.2
		end
		if d.panel.Parent and not d.busy then
			d.panel.CanCollide = true
		end
	end)
end

-- hingeBottom: 경첩 아래 끝, along: 닫힌 문짝이 경첩에서 뻗는 방향(수평), swing: +1/-1 (여는 방향)
function Doors.create(parent: Instance, hingeBottom: Vector3, along: Vector3, width: number, height: number, swing: number): Model
	local model = Instance.new("Model")
	model.Name = "Door"
	model:SetAttribute("Open", false)
	model:SetAttribute(Config.Tags.Dynamic, true)
	model.Parent = parent
	local dir = Vector3.new(along.X, 0, along.Z).Unit
	local hinge = CFrame.fromMatrix(hingeBottom, dir, Vector3.yAxis)
	local closedRel = CFrame.new(width / 2, height / 2, 0)
	local panel = Kit.box(model, hinge * closedRel, Vector3.new(width - 0.1, height - 0.05, 0.3), { name = "Panel" })
	panel:SetAttribute("ClosedCFrame", panel.CFrame)
	-- 손잡이(가로 막대) + 판 무늬: 문으로 알아볼 수 있게
	local handleY = height * 0.45
	for _, side in { -1, 1 } do
		local a = panel.CFrame * Vector3.new(width * 0.05, handleY - height / 2, side * 0.3)
		local b = panel.CFrame * Vector3.new(width * 0.38, handleY - height / 2, side * 0.3)
		local h = Kit.cylinder(model, a, b, 0.08, { collide = false, blocks = false })
		h.Anchored = false
		h.Massless = true
		local w = Instance.new("WeldConstraint")
		w.Part0 = panel
		w.Part1 = h
		w.Parent = h
	end
	local inset = Kit.box(model, panel.CFrame * CFrame.new(0, height * 0.18, 0), Vector3.new(width * 0.62, height * 0.3, 0.42), { collide = false, blocks = false })
	inset.Anchored = false
	inset.Massless = true
	local w2 = Instance.new("WeldConstraint")
	w2.Part0 = panel
	w2.Part1 = inset
	w2.Parent = inset
	local mod = Instance.new("PathfindingModifier")
	mod.PassThrough = true
	mod.Parent = panel
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "문 열기"
	prompt.ObjectText = ""
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = panel
	CollectionService:AddTag(model, Config.Tags.Door)
	local d: Door = {
		model = model,
		panel = panel,
		prompt = prompt,
		hinge = hinge,
		closedRel = closedRel,
		swing = swing,
		open = false,
		busy = false,
	}
	table.insert(doors, d)
	prompt.Triggered:Connect(function(player)
		if player:GetAttribute("Status") ~= "Alive" then
			return
		end
		Doors.toggle(d, player)
	end)
	model.Destroying:Connect(function()
		local i = table.find(doors, d)
		if i then
			table.remove(doors, i)
		end
	end)
	return model
end

function Doors.all(): { Door }
	return doors
end

-- 괴물용: pos 근처 닫힌 문을 연다
function Doors.openNear(pos: Vector3, radius: number, from: Vector3?): boolean
	local any = false
	for _, d in doors do
		if not d.open and not d.busy and (d.panel.Position - pos).Magnitude <= radius then
			Doors.toggle(d, nil, from or pos)
			any = true
		end
	end
	return any
end

function Doors.clear()
	table.clear(doors)
end

return Doors
