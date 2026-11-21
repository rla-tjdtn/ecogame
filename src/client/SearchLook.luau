--!strict
-- 상자·서랍 조작: 조준점(화면 가운데)으로 서랍이나 뚜껑을 보고 E → 열기/닫기(서버 Search 가 판정).
-- 서랍마다 따로 열고 닫을 수 있다. 안내 문구는 UI.setPrompt 로 보여 준다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local UI = require(script.Parent:WaitForChild("UI"))

local SearchLook = {}

local player = Players.LocalPlayer
local SearchAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SearchAction") :: RemoteEvent
local RANGE = 8

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

type Target = { spot: number, comp: number, model: Model, label: string }
local current: Target? = nil
local shown = false

local function find(): Target?
	if player:GetAttribute("Status") ~= "Alive" or player:GetAttribute("Hidden") then
		return nil
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return nil
	end
	params.FilterDescendantsInstances = if player.Character then { player.Character } else {}
	local hit = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * RANGE, params)
	local inst: Instance? = hit and hit.Instance
	while inst and inst ~= workspace do
		if inst:IsA("Model") and inst:GetAttribute("Comp") then
			local spotModel = inst.Parent
			local label = (spotModel and spotModel:GetAttribute("Label") :: string?) or "상자"
			return { spot = inst:GetAttribute("SpotId") :: number, comp = inst:GetAttribute("Comp") :: number, model = inst, label = label }
		end
		inst = inst.Parent
	end
	return nil
end

function SearchLook.target(): { spot: number, comp: number }?
	local t = find()
	return if t then { spot = t.spot, comp = t.comp } else nil
end

-- 보고 있는 서랍/뚜껑을 연다/닫는다(E)
function SearchLook.use(): boolean
	local t = find()
	if not t then
		return false
	end
	SearchAction:FireServer(t.spot, t.comp)
	return true
end

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.E and current then
		SearchLook.use()
	end
end)

local acc = 0
RunService.RenderStepped:Connect(function(dt)
	acc += dt
	if acc < 0.08 then
		return
	end
	acc = 0
	current = find()
	if current then
		local open = current.model:GetAttribute("Open") == true
		local what = if current.label == "서랍장" or current.label == "협탁" then "서랍" else current.label
		UI.setPrompt(if open then ("E   " .. what .. " 닫기") else ("E   " .. what .. " 열기"))
		shown = true
	elseif shown then
		UI.setPrompt(nil)
		shown = false
	end
end)

return SearchLook
