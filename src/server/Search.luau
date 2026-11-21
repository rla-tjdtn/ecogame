--!strict
-- 뒤질 수 있는 상자·서랍(맵 문자 Z). 스테이지마다 그중 한 곳에 열쇠가 있고(라운드마다 서버가 고른다),
-- 누군가 찾으면 팀 전체가 열쇠를 가진다(ReplicatedStorage 속성 HasKey). 열쇠가 없으면 출구가 열리지 않는다(Round).
-- E 로 뒤지면 서랍이 열리거나 뚜껑이 들리고(음파에 그 순간 모습으로), 뒤지는 소리를 가까운 괴물이 듣는다.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.MapKit)
local SoundBus = require(script.Parent.SoundBus)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RoundEvent = Remotes:WaitForChild("RoundEvent") :: RemoteEvent

local Search = {}

export type Spot = {
	model: Model,
	moving: Model, -- 열릴 때 움직이는 서랍/뚜껑(음파는 움직이는 물체로 그린다)
	openOffset: CFrame,
	front: Vector3,
	prompt: ProximityPrompt,
	searched: boolean,
	hasKey: boolean,
	busy: boolean,
}

local spots: { Spot } = {}

-- 챕터별 모양: w 폭, h 높이, d 깊이, kind = "drawers" | "lid"
type Style = { w: number, h: number, d: number, kind: string, rows: number, name: string }
local STYLES: { [string]: Style } = {
	drawers = { w = 3.2, h = 3.8, d = 2.2, kind = "drawers", rows = 3, name = "서랍장" }, -- 지하 시설: 철제 서랍장
	crate = { w = 3.6, h = 3.2, d = 3.0, kind = "lid", rows = 0, name = "나무 상자" }, -- 창고
	toolbox = { w = 3.4, h = 1.9, d = 2.0, kind = "lid", rows = 0, name = "공구함" }, -- 하수도
	nightstand = { w = 2.6, h = 2.8, d = 2.2, kind = "drawers", rows = 2, name = "협탁" }, -- 병원
	chest = { w = 3.6, h = 2.3, d = 2.4, kind = "lid", rows = 0, name = "궤짝" }, -- 심층 미로
}
Search.Styles = STYLES

local function build(parent: Instance, cf: CFrame, s: Style): (Model, Model, CFrame)
	local m = Instance.new("Model")
	m.Name = "SearchSpot"
	local mv = Instance.new("Model")
	mv.Name = "Moving"
	mv:SetAttribute(Config.Tags.Dynamic, true)
	local t = 0.2
	local w, h, d = s.w, s.h, s.d
	local function box(par: Instance, local_: CFrame, size: Vector3, opts: Kit.Opts?): Part
		return Kit.box(par, cf * local_, size, opts)
	end
	-- 몸통(앞 = -Z)
	box(m, CFrame.new(0, h / 2, d / 2 - t / 2), Vector3.new(w, h, t))
	for _, sx in { -1, 1 } do
		box(m, CFrame.new(sx * (w / 2 - t / 2), h / 2, 0), Vector3.new(t, h, d))
	end
	box(m, CFrame.new(0, t / 2, 0), Vector3.new(w, t, d))
	local openOffset
	if s.kind == "drawers" then
		box(m, CFrame.new(0, h - t / 2, 0), Vector3.new(w + 0.1, t, d + 0.1))
		local rowH = (h - t * 2) / s.rows
		for k = 1, s.rows do
			local y = t + rowH * (k - 0.5)
			local par: Instance = if k == s.rows then mv else m -- 맨 위 서랍이 열린다
			box(par, CFrame.new(0, y, -d / 2 + t / 2), Vector3.new(w - t * 2 - 0.08, rowH - 0.1, t), { blocks = false })
			box(par, CFrame.new(0, y, -d / 2 - 0.1), Vector3.new(0.8, 0.12, 0.12), { blocks = false, collide = false })
			if k == s.rows then
				box(mv, CFrame.new(0, y - rowH / 2 + 0.15, 0), Vector3.new(w - t * 2 - 0.1, 0.1, d - t * 2), { blocks = false, collide = false })
			end
		end
		openOffset = CFrame.new(0, 0, -(d * 0.6)) -- 앞으로 빠진다
	else
		-- 앞판 + 뚜껑(+ 띠)
		box(m, CFrame.new(0, h / 2, -d / 2 + t / 2), Vector3.new(w, h, t))
		box(mv, CFrame.new(0, h + t / 2, 0), Vector3.new(w + 0.12, t, d + 0.12))
		if s.name ~= "공구함" then
			for _, sx in { -0.3, 0.3 } do
				box(mv, CFrame.new(sx * w, h + t + 0.03, 0), Vector3.new(0.18, 0.06, d + 0.14), { blocks = false, collide = false })
			end
		else
			box(mv, CFrame.new(0, h + t + 0.25, 0), Vector3.new(w * 0.5, 0.12, 0.12), { blocks = false, collide = false })
		end
		openOffset = CFrame.new(0, 0.6, d * 0.45) * CFrame.Angles(math.rad(-55), 0, 0) -- 뒤로 젖혀진다
	end
	mv.Parent = m
	m.Parent = parent
	return m, mv, openOffset
end

-- pos: 타일 가운데 바닥, back: 벽 쪽(단위 벡터)
function Search.create(parent: Instance, pos: Vector3, back: Vector3, styleName: string?): Spot
	local s = STYLES[styleName or "drawers"] or STYLES.drawers
	local facing = -back
	local center = pos + back * (Config.Hide.Tile / 2 - s.d / 2 - 0.15)
	local cf = CFrame.lookAt(center, center + facing)
	local model, moving, openOffset = build(parent, cf, s)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "뒤지기"
	prompt.ObjectText = s.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Key.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	local anchor = model:FindFirstChildWhichIsA("BasePart") :: BasePart
	prompt.Parent = anchor
	CollectionService:AddTag(model, Config.Tags.SearchSpot)
	local spot: Spot = {
		model = model,
		moving = moving,
		openOffset = openOffset,
		front = center + facing * (s.d / 2 + 2.2),
		prompt = prompt,
		searched = false,
		hasKey = false,
		busy = false,
	}
	table.insert(spots, spot)
	prompt.Triggered:Connect(function(player)
		Search.search(player, spot)
	end)
	model.Destroying:Connect(function()
		local i = table.find(spots, spot)
		if i then
			table.remove(spots, i)
		end
	end)
	return spot
end

local function hasKey(): boolean
	return ReplicatedStorage:GetAttribute("HasKey") == true
end

-- 뒤지기: 잠깐 뒤진 뒤 결과. 열쇠가 있으면 팀 전체가 가진다. 결과 문자열을 돌려준다("key" | "empty" | "already" | "busy")
function Search.search(player: Player, spot: Spot): string
	if player:GetAttribute("Status") ~= "Alive" or player:GetAttribute("Hidden") then
		return "busy"
	end
	if spot.searched then
		RoundEvent:FireClient(player, "SearchResult", { result = "already" })
		return "already"
	end
	if spot.busy then
		return "busy"
	end
	spot.busy = true
	-- 열린다(서랍 빠짐 / 뚜껑 젖힘)
	local pivot = spot.moving:GetPivot()
	spot.moving:PivotTo(pivot * spot.openOffset)
	SoundBus.emit(spot.front + Vector3.new(0, 2, 0), Config.Key.SearchNoise, player, "Search")
	RoundEvent:FireClient(player, "SearchResult", { result = "searching" })
	task.wait(Config.Key.SearchSeconds)
	spot.busy = false
	spot.searched = true
	spot.prompt.Enabled = false
	if spot.hasKey and not hasKey() then
		ReplicatedStorage:SetAttribute("HasKey", true)
		RoundEvent:FireAllClients("KeyFound", { by = player.DisplayName, userId = player.UserId })
		return "key"
	end
	RoundEvent:FireClient(player, "SearchResult", { result = "empty" })
	return "empty"
end

-- 새 스테이지: 열쇠를 한 곳에 넣는다(시작에서 먼 쪽 절반 중에서 무작위)
function Search.assignKey(start: Vector3)
	ReplicatedStorage:SetAttribute("HasKey", false)
	if #spots == 0 then
		return
	end
	local sorted = table.clone(spots)
	table.sort(sorted, function(a, b)
		return (a.front - start).Magnitude > (b.front - start).Magnitude
	end)
	local half = math.max(1, math.ceil(#sorted / 2))
	local pick = sorted[math.random(1, half)]
	for _, s in spots do
		s.hasKey = s == pick
	end
end

function Search.all(): { Spot }
	return spots
end

function Search.keySpot(): Spot?
	for _, s in spots do
		if s.hasKey then
			return s
		end
	end
	return nil
end

return Search
