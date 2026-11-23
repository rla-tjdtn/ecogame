--!strict
-- 숨는 곳(맵 문자 L): 챕터마다 모양이 다른 캐비닛·옷장. E(ProximityPrompt)로 들어가고 E 로 나온다.
-- 숨어 있는 동안: 움직일 수 없고 음파를 쏠 수 없으며, 괴물은 보지도 잡지도 못한다.
-- 단, 쫓아오던 괴물이 숨는 모습을 봤다면(Config.Hide.SeenWindow 안에 시야에 있었다면) 그 앞으로 와서 끌어낸다(Monster).
-- 문을 여닫는 소리(Config.Hide.Noise)는 가까운 괴물이 듣는다.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.MapKit)
local SoundBus = require(script.Parent.SoundBus)

local Hiding = {}

export type Spot = {
	model: Model,
	center: Vector3, -- 바닥 높이의 안쪽 가운데
	facing: Vector3, -- 문이 향하는 방향(방 안쪽)
	front: Vector3, -- 문 앞(바닥 높이)
	prompt: ProximityPrompt,
	occupant: Player?,
}

local spots: { Spot } = {}
local occupied: { [Player]: Spot } = {}
local hideListeners: { (Player, Spot) -> () } = {}

-- 챕터별 모양
type Style = { w: number, d: number, h: number, doors: number, louvers: boolean, legs: boolean, crown: boolean, tilt: number }
local STYLES: { [string]: Style } = {
	locker = { w = 3.6, d = 3.0, h = 7.6, doors = 1, louvers = true, legs = false, crown = false, tilt = 0 }, -- 지하 시설: 철제 사물함
	tool = { w = 4.6, d = 3.2, h = 7.2, doors = 2, louvers = true, legs = false, crown = false, tilt = 0 }, -- 창고: 공구 캐비닛
	rusty = { w = 3.6, d = 3.0, h = 7.4, doors = 1, louvers = true, legs = false, crown = false, tilt = 0.035 }, -- 하수도: 찌그러진 정비 사물함
	wardrobe = { w = 5.6, d = 3.4, h = 8.0, doors = 2, louvers = true, legs = true, crown = true, tilt = 0 }, -- 병원: 병실 옷장
	closet = { w = 4.8, d = 3.4, h = 8.6, doors = 1, louvers = false, legs = false, crown = true, tilt = 0 }, -- 심층 미로: 낡은 벽장
	hotelcloset = { w = 5.0, d = 3.2, h = 8.2, doors = 2, louvers = false, legs = true, crown = true, tilt = 0 }, -- 호텔: 객실 옷장
	cubby = { w = 4.4, d = 3.0, h = 6.6, doors = 2, louvers = false, legs = true, crown = false, tilt = 0.02 }, -- 폐유치원: 낮은 어린이 사물함(몸을 웅크려 들어간다)
}
Hiding.Styles = STYLES

-- cf: 바닥 높이, 문이 향하는 쪽이 LookVector
local function buildModel(parent: Instance, cf: CFrame, s: Style): (Model, BasePart)
	local m = Instance.new("Model")
	m.Name = "HideSpot"
	local t = 0.25
	local y0 = if s.legs then 0.5 else 0
	local function box(local_: CFrame, size: Vector3, opts: Kit.Opts?): Part
		return Kit.box(m, cf * CFrame.Angles(0, 0, s.tilt) * local_, size, opts)
	end
	local h, w, d = s.h, s.w, s.d
	-- 몸통: 뒤판, 옆판, 지붕, 바닥판(속은 비어 있다)
	box(CFrame.new(0, y0 + h / 2, d / 2 - t / 2), Vector3.new(w, h, t))
	for _, sx in { -1, 1 } do
		box(CFrame.new(sx * (w / 2 - t / 2), y0 + h / 2, 0), Vector3.new(t, h, d))
	end
	box(CFrame.new(0, y0 + h - t / 2, 0), Vector3.new(w, t, d))
	box(CFrame.new(0, y0 + t / 2, 0), Vector3.new(w, t, d), { collide = false })
	if s.legs then
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				box(CFrame.new(sx * (w / 2 - 0.3), y0 / 2, sz * (d / 2 - 0.3)), Vector3.new(0.3, y0, 0.3), { blocks = false })
			end
		end
	end
	if s.crown then
		box(CFrame.new(0, y0 + h + 0.2, -0.1), Vector3.new(w + 0.4, 0.4, d + 0.2), { blocks = false })
	end
	-- 문(앞쪽, -Z): 틀 + 문짝 + 환기 살(숨은 사람이 틈으로 밖을 본다)
	local front = -d / 2 + t / 2
	local doorW = (w - t * 2) / s.doors
	local doorPart: BasePart? = nil
	for k = 1, s.doors do
		local cx = -w / 2 + t + doorW * (k - 0.5)
		local top = y0 + h - t
		if s.louvers then
			-- 아래쪽 판 + 위쪽 살(사이가 비어 있다)
			local solidH = (top - y0) * 0.55
			local p = box(CFrame.new(cx, y0 + solidH / 2, front), Vector3.new(doorW - 0.06, solidH, t), { name = "HideDoor" })
			doorPart = doorPart or p
			local slats = 7
			local span = top - (y0 + solidH)
			for q = 1, slats do
				local sy = y0 + solidH + span * (q - 0.5) / slats
				box(CFrame.new(cx, sy, front) * CFrame.Angles(math.rad(-25), 0, 0), Vector3.new(doorW - 0.06, span / slats * 0.55, 0.12), { blocks = false })
			end
			-- 문 가장자리 세로 틀
			for _, sx in { -1, 1 } do
				box(CFrame.new(cx + sx * (doorW / 2 - 0.1), y0 + solidH + span / 2, front), Vector3.new(0.2, span, t), { blocks = false })
			end
		else
			-- 판자 문 + 눈높이 틈 하나
			local gapY = y0 + 5.6
			local p = box(CFrame.new(cx, (y0 + gapY - 0.25) / 2, front), Vector3.new(doorW - 0.06, gapY - 0.25 - y0, t), { name = "HideDoor" })
			doorPart = doorPart or p
			box(CFrame.new(cx, (gapY + 0.25 + top) / 2, front), Vector3.new(doorW - 0.06, top - gapY - 0.25, t))
			for q = 1, 3 do
				box(CFrame.new(cx - doorW / 2 + doorW * q / 4, (y0 + top) / 2, front - 0.15), Vector3.new(0.08, top - y0 - 0.4, 0.08), { blocks = false, collide = false })
			end
		end
		-- 손잡이
		local hx = if s.doors == 2 then (if k == 1 then cx + doorW / 2 - 0.35 else cx - doorW / 2 + 0.35) else cx + doorW / 2 - 0.4
		box(CFrame.new(hx, y0 + 3.6, front - 0.25), Vector3.new(0.12, 0.9, 0.18), { blocks = false, collide = false })
	end
	m.Parent = parent
	return m, doorPart :: BasePart
end

local function rootHeight(char: Model): number
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hum and root then
		return hum.HipHeight + root.Size.Y / 2
	end
	return 3
end

local function clear(player: Player)
	local spot = occupied[player]
	if spot then
		spot.occupant = nil
		occupied[player] = nil
	end
	if player:GetAttribute("Hidden") then
		player:SetAttribute("Hidden", false)
	end
end

function Hiding.enter(player: Player, spot: Spot): boolean
	if player:GetAttribute("Status") ~= "Alive" or spot.occupant or occupied[player] then
		return false
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not root then
		return false
	end
	spot.occupant = player
	occupied[player] = spot
	root.AssemblyLinearVelocity = Vector3.zero
	root.Anchored = true
	local p = spot.center + Vector3.new(0, rootHeight(char), 0) - spot.facing * 0.15
	char:PivotTo(CFrame.lookAt(p, p + spot.facing))
	player:SetAttribute("Hidden", true)
	SoundBus.emit(spot.front + Vector3.new(0, 3, 0), Config.Hide.Noise, player, "Hide")
	for _, fn in table.clone(hideListeners) do
		task.spawn(fn, player, spot)
	end
	return true
end

function Hiding.exit(player: Player): boolean
	local spot = occupied[player]
	if not spot then
		return false
	end
	clear(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if char and root then
		local p = spot.front + Vector3.new(0, rootHeight(char), 0)
		char:PivotTo(CFrame.lookAt(p, p + spot.facing))
		root.Anchored = false
	end
	SoundBus.emit(spot.front + Vector3.new(0, 3, 0), Config.Hide.Noise, player, "Hide")
	return true
end

function Hiding.spotOf(player: Player): Spot?
	return occupied[player]
end

function Hiding.all(): { Spot }
	return spots
end

-- 누가 숨었을 때(괴물이 그 모습을 봤는지 판단)
function Hiding.onHide(fn: (Player, Spot) -> ())
	table.insert(hideListeners, fn)
end

-- pos: 타일 가운데 바닥, back: 벽 쪽 방향(단위 벡터)
function Hiding.create(parent: Instance, pos: Vector3, back: Vector3, styleName: string?): Spot
	local s = STYLES[styleName or "locker"] or STYLES.locker
	local facing = -back
	local center = pos + back * (Config.Hide.Tile / 2 - s.d / 2 - 0.1)
	local cf = CFrame.lookAt(center, center + facing) -- (LookVector = -Z = 문 쪽, +Z = 벽 쪽 뒤판)
	local model, door = buildModel(parent, cf, s)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "숨기"
	prompt.ObjectText = ""
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Hide.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("HideSpot", true)
	prompt.Parent = door
	CollectionService:AddTag(model, Config.Tags.HideSpot)
	local spot: Spot = {
		model = model,
		center = center,
		facing = facing,
		front = center + facing * (s.d / 2 + 2.4),
		prompt = prompt,
		occupant = nil,
	}
	table.insert(spots, spot)
	prompt.Triggered:Connect(function(player)
		if occupied[player] == spot then
			Hiding.exit(player)
		elseif not occupied[player] then
			Hiding.enter(player, spot)
		end
	end)
	model.Destroying:Connect(function()
		local i = table.find(spots, spot)
		if i then
			table.remove(spots, i)
		end
		if spot.occupant then
			clear(spot.occupant)
		end
	end)
	return spot
end

-- 죽거나 탈출하거나 새 캐릭터가 생기면 숨은 상태를 푼다
local function watch(p: Player)
	p:GetAttributeChangedSignal("Status"):Connect(function()
		if p:GetAttribute("Status") ~= "Alive" then
			clear(p)
		end
	end)
	p.CharacterAdded:Connect(function()
		clear(p)
	end)
end
for _, p in Players:GetPlayers() do
	watch(p)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(clear)

return Hiding
