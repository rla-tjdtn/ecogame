--!strict
-- 뒤질 수 있는 상자·서랍(맵 문자 Z). 챕터별 모양(SearchStyle). 서랍장은 서랍마다, 상자는 뚜껑을 따로 열고 닫는다.
-- 조작: 조준점으로 서랍/뚜껑을 보고 E(클라이언트 SearchLook → Remotes.SearchAction(spotId, index)). 다시 E 면 닫힌다.
-- 스테이지마다 한 칸(서랍 하나 또는 뚜껑 하나)에 열쇠가 있고(라운드마다 서버가 고른다), 누가 찾든 팀 전체가 가진다
-- (ReplicatedStorage 속성 HasKey). 열쇠가 없으면 출구가 열리지 않는다(Round). 처음 열 때 뒤지는 소리를 괴물이 듣는다.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.MapKit)
local SoundBus = require(script.Parent.SoundBus)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RoundEvent = Remotes:WaitForChild("RoundEvent") :: RemoteEvent
local SearchAction = Remotes:WaitForChild("SearchAction") :: RemoteEvent

local Search = {}

export type Comp = {
	model: Model, -- 움직이는 서랍/뚜껑(음파는 움직이는 물체로 그린다)
	closedPivot: CFrame,
	openPivot: CFrame,
	open: boolean,
	busy: boolean,
	searched: boolean,
	hasKey: boolean,
}
export type Spot = {
	id: number,
	model: Model,
	center: Vector3,
	front: Vector3,
	comps: { Comp },
	name: string,
}

local spots: { Spot } = {}
local byId: { [number]: Spot } = {}
local nextId = 0

-- 챕터별 모양: w 폭, h 높이, d 깊이, kind = "drawers"(rows 칸) | "lid"
type Style = { w: number, h: number, d: number, kind: string, rows: number, name: string }
local STYLES: { [string]: Style } = {
	drawers = { w = 3.2, h = 3.8, d = 2.2, kind = "drawers", rows = 3, name = "서랍장" }, -- 지하 시설: 철제 서랍장
	crate = { w = 3.6, h = 3.2, d = 3.0, kind = "lid", rows = 0, name = "나무 상자" }, -- 창고
	toolbox = { w = 3.4, h = 1.9, d = 2.0, kind = "lid", rows = 0, name = "공구함" }, -- 하수도
	nightstand = { w = 2.6, h = 2.8, d = 2.2, kind = "drawers", rows = 2, name = "협탁" }, -- 병원
	chest = { w = 3.6, h = 2.3, d = 2.4, kind = "lid", rows = 0, name = "궤짝" }, -- 심층 미로
}
Search.Styles = STYLES

local function newComp(parent: Model, idx: number, spotId: number): Model
	local mv = Instance.new("Model")
	mv.Name = "Comp" .. idx
	mv:SetAttribute(Config.Tags.Dynamic, true)
	mv:SetAttribute("SpotId", spotId)
	mv:SetAttribute("Comp", idx)
	mv.Parent = parent
	return mv
end

-- cf: 바닥 가운데, LookVector(-Z) = 앞(방 안쪽)
local function build(parent: Instance, cf: CFrame, s: Style, spotId: number): (Model, { Comp })
	local m = Instance.new("Model")
	m.Name = "SearchSpot"
	m:SetAttribute("SpotId", spotId)
	m:SetAttribute("Label", s.name)
	local t = 0.2
	local w, h, d = s.w, s.h, s.d
	local function box(par: Instance, local_: CFrame, size: Vector3, opts: Kit.Opts?): Part
		return Kit.box(par, cf * local_, size, opts)
	end
	box(m, CFrame.new(0, h / 2, d / 2 - t / 2), Vector3.new(w, h, t))
	for _, sx in { -1, 1 } do
		box(m, CFrame.new(sx * (w / 2 - t / 2), h / 2, 0), Vector3.new(t, h, d))
	end
	box(m, CFrame.new(0, t / 2, 0), Vector3.new(w, t, d))
	local comps: { Comp } = {}
	local facing = cf.LookVector
	if s.kind == "drawers" then
		box(m, CFrame.new(0, h - t / 2, 0), Vector3.new(w + 0.1, t, d + 0.1))
		local rowH = (h - t * 2) / s.rows
		for k = 1, s.rows do
			local mv = newComp(m, k, spotId)
			local y = h - t - rowH * (k - 0.5) -- 1 = 맨 위
			local inner = d - t * 2
			box(mv, CFrame.new(0, y, -d / 2 + t / 2), Vector3.new(w - t * 2 - 0.08, rowH - 0.1, t), { blocks = false })
			box(mv, CFrame.new(0, y, -d / 2 - 0.1), Vector3.new(0.8, 0.12, 0.12), { blocks = false, collide = false })
			-- 서랍 통(바닥 + 양옆 + 뒤): 빠졌을 때 서랍 모양이 보이게
			box(mv, CFrame.new(0, y - rowH / 2 + 0.12, -d / 2 + t + inner / 2), Vector3.new(w - t * 2 - 0.15, 0.08, inner), { blocks = false, collide = false })
			for _, sx in { -1, 1 } do
				box(mv, CFrame.new(sx * (w / 2 - t - 0.12), y - rowH * 0.15, -d / 2 + t + inner / 2), Vector3.new(0.08, rowH * 0.6, inner), { blocks = false, collide = false })
			end
			box(mv, CFrame.new(0, y - rowH * 0.15, d / 2 - t - 0.06), Vector3.new(w - t * 2 - 0.15, rowH * 0.6, 0.08), { blocks = false, collide = false })
			local closed = mv:GetPivot()
			-- 앞으로 곧게 빠진다(월드 기준 이동)
			table.insert(comps, { model = mv, closedPivot = closed, openPivot = closed + facing * (inner * 0.75), open = false, busy = false, searched = false, hasKey = false })
		end
	else
		box(m, CFrame.new(0, h / 2, -d / 2 + t / 2), Vector3.new(w, h, t))
		local mv = newComp(m, 1, spotId)
		box(mv, CFrame.new(0, h + t / 2, 0), Vector3.new(w + 0.12, t, d + 0.12))
		if s.name ~= "공구함" then
			for _, sx in { -0.3, 0.3 } do
				box(mv, CFrame.new(sx * w, h + t + 0.03, 0), Vector3.new(0.18, 0.06, d + 0.14), { blocks = false, collide = false })
			end
		else
			box(mv, CFrame.new(0, h + t + 0.25, 0), Vector3.new(w * 0.5, 0.12, 0.12), { blocks = false, collide = false })
		end
		local closed = mv:GetPivot()
		-- 뒤쪽 경첩을 축으로 뒤로 젖혀진다(월드 기준 회전)
		local hinge = (cf * CFrame.new(0, h + t, d / 2)).Position
		local turn = CFrame.new(hinge) * CFrame.fromAxisAngle(cf.RightVector, math.rad(100)) * CFrame.new(-hinge)
		table.insert(comps, { model = mv, closedPivot = closed, openPivot = turn * closed, open = false, busy = false, searched = false, hasKey = false })
	end
	m.Parent = parent
	return m, comps
end

-- pos: 타일 가운데 바닥, back: 벽 쪽(단위 벡터)
function Search.create(parent: Instance, pos: Vector3, back: Vector3, styleName: string?): Spot
	local s = STYLES[styleName or "drawers"] or STYLES.drawers
	local facing = -back
	local center = pos + back * (Config.Hide.Tile / 2 - s.d / 2 - 0.15)
	local cf = CFrame.lookAt(center, center + facing)
	nextId += 1
	local model, comps = build(parent, cf, s, nextId)
	CollectionService:AddTag(model, Config.Tags.SearchSpot)
	local spot: Spot = { id = nextId, model = model, center = center, front = center + facing * (s.d / 2 + 2.2), comps = comps, name = s.name }
	table.insert(spots, spot)
	byId[spot.id] = spot
	model.Destroying:Connect(function()
		local i = table.find(spots, spot)
		if i then
			table.remove(spots, i)
		end
		byId[spot.id] = nil
	end)
	return spot
end

local function hasKey(): boolean
	return ReplicatedStorage:GetAttribute("HasKey") == true
end

local function move(c: Comp, toOpen: boolean)
	c.busy = true
	local a, b = if toOpen then c.closedPivot else c.openPivot, if toOpen then c.openPivot else c.closedPivot
	local t0 = os.clock()
	local dur = 0.25
	while true do
		local k = math.clamp((os.clock() - t0) / dur, 0, 1)
		local e = 1 - (1 - k) * (1 - k)
		if not c.model.Parent then
			break
		end
		c.model:PivotTo(a:Lerp(b, e))
		if k >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
	c.open = toOpen
	c.model:SetAttribute("Open", toOpen)
	c.busy = false
end

-- 서랍/뚜껑 하나를 열거나 닫는다. 처음 열면 뒤진다(결과: "key" | "empty").
-- 돌려주는 값: "key" | "empty" | "opened" | "closed" | "busy"
function Search.toggle(player: Player, spot: Spot, index: number): string
	local c = spot.comps[index]
	if not c or c.busy or player:GetAttribute("Status") ~= "Alive" or player:GetAttribute("Hidden") then
		return "busy"
	end
	if c.open then
		move(c, false)
		return "closed"
	end
	local first = not c.searched
	if first then
		SoundBus.emit(spot.front + Vector3.new(0, 2, 0), Config.Key.SearchNoise, player, "Search")
		RoundEvent:FireClient(player, "SearchResult", { result = "searching" })
	end
	move(c, true)
	if not first then
		return "opened"
	end
	task.wait(math.max(0, Config.Key.SearchSeconds - 0.25))
	c.searched = true
	if c.hasKey and not hasKey() then
		ReplicatedStorage:SetAttribute("HasKey", true)
		RoundEvent:FireAllClients("KeyFound", { by = player.DisplayName, userId = player.UserId })
		return "key"
	end
	RoundEvent:FireClient(player, "SearchResult", { result = if c.hasKey then "empty" else "empty" })
	return "empty"
end

-- (예전 호출용) 그 상자의 첫 칸을 연다
function Search.search(player: Player, spot: Spot): string
	for i, c in spot.comps do
		if not c.searched then
			return Search.toggle(player, spot, i)
		end
	end
	RoundEvent:FireClient(player, "SearchResult", { result = "already" })
	return "already"
end

SearchAction.OnServerEvent:Connect(function(player: Player, spotId: any, index: any)
	if type(spotId) ~= "number" or type(index) ~= "number" then
		return
	end
	local spot = byId[spotId]
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not spot or not root or (root.Position - spot.center).Magnitude > Config.Key.PromptDistance + 2 then
		return
	end
	Search.toggle(player, spot, index)
end)

-- 새 스테이지: 열쇠를 한 칸에 넣는다(시작에서 먼 쪽 절반의 상자 중 무작위, 그 상자의 무작위 칸)
function Search.assignKey(start: Vector3)
	ReplicatedStorage:SetAttribute("HasKey", false)
	for _, s in spots do
		for _, c in s.comps do
			c.hasKey = false
		end
	end
	if #spots == 0 then
		return
	end
	local sorted = table.clone(spots)
	table.sort(sorted, function(a, b)
		return (a.front - start).Magnitude > (b.front - start).Magnitude
	end)
	local pick = sorted[math.random(1, math.max(1, math.ceil(#sorted / 2)))]
	pick.comps[math.random(1, #pick.comps)].hasKey = true
end

function Search.all(): { Spot }
	return spots
end

-- 열쇠가 든 상자와 칸 번호
function Search.keySpot(): (Spot?, number?)
	for _, s in spots do
		for i, c in s.comps do
			if c.hasKey then
				return s, i
			end
		end
	end
	return nil, nil
end

return Search
