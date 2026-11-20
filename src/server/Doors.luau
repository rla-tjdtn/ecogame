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

function Doors.toggle(d: Door, source: Player?)
	if d.busy then
		return
	end
	d.busy = true
	local opening = not d.open
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
function Doors.openNear(pos: Vector3, radius: number): boolean
	local any = false
	for _, d in doors do
		if not d.open and not d.busy and (d.panel.Position - pos).Magnitude <= radius then
			Doors.toggle(d, nil)
			any = true
		end
	end
	return any
end

function Doors.clear()
	table.clear(doors)
end

return Doors
