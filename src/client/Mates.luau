--!strict
-- 함께 하는 플레이어(팀원)는 음파와 상관없이 늘 흰 윤곽선으로 보인다(실제 아바타 모양, Highlight).
-- 벽 너머는 가려진다(DepthMode Occluded). 살아 있는(Status "Alive") 다른 플레이어만, 내 캐릭터는 제외.
-- Highlight 는 이 클라이언트에만 만들어진다(복제되지 않음).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Mates = {}
local player = Players.LocalPlayer
local NAME = "MateOutline"

local function wanted(p: Player): Model?
	if p == player or p:GetAttribute("Status") ~= "Alive" then
		return nil
	end
	return p.Character
end

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TAG = require(ReplicatedStorage.Shared.Config).Tags.Monster

local function outline(target: Model): Highlight
	local hl = Instance.new("Highlight")
	hl.Name = NAME
	hl.Adornee = target
	hl.FillTransparency = 1
	hl.OutlineColor = Color3.new(1, 1, 1)
	hl.OutlineTransparency = 0.3
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = target
	return hl
end

local function sync()
	-- 사람 모습 도플갱어(진짜 아바타)도 팀원과 똑같이 늘 윤곽선으로 보인다. 터지면 지운다
	for _, inst in CollectionService:GetTagged(TAG) do
		if inst:IsA("Model") then
			local m = inst :: Model
			local want = m:GetAttribute("Form") == "Disguise" and m:GetAttribute("AvatarOf") ~= nil
			local h = m:FindFirstChild(NAME)
			if want and not h then
				outline(m)
			elseif h and not want then
				h:Destroy()
			end
		end
	end
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local want = wanted(p)
		local h = char and char:FindFirstChild(NAME) :: Highlight?
		if want and not h then
			outline(want)
		elseif h and not want then
			h:Destroy()
		end
	end
end

-- (테스트) 윤곽선이 켜진 팀원 수
function Mates.count(): number
	local n = 0
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local h = char and char:FindFirstChild(NAME) :: Highlight?
		if h and h.Enabled and p ~= player then
			n += 1
		end
	end
	return n
end

local Perf = require(script.Parent:WaitForChild("Perf"))
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc >= 0.25 then
		acc = 0
		local t0 = os.clock()
		sync()
		Perf.add("mates", os.clock() - t0)
	end
end)

return Mates
