--!strict
-- 시안 그림 챕터 괴물(Rig = 4): 시안을 만든 렌더러로 찍은 그림(8방향 × 9자세)을 그대로 띄운다.
--  · 보는 방향: 괴물이 향한 쪽과 카메라 사이 각도로 8방향 중 하나
--  · 자세: 서 있으면 걷기 0, 걸으면 걷기 4장, 쫓으면 추격 4장(실제 이동 거리로 넘김 → 미끄러지지 않음), 바로 앞이면 덮침
--  · 음파에 드러난 동안만 보인다(Reveal.active). 걸음 소리는 반 주기마다(onStep)
-- 그림 시트: Shared/CreatureSprites/<id> 의 sheets(로블록스 에셋 번호). 0 이면 Studio 안 로컬 파일(rbxasset://sonarcreatures/<id>_<n>.png)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpriteAnim = {}
SpriteAnim.onStep = nil :: ((Model, Vector3, number) -> ())?
SpriteAnim.visible = nil :: ((Model) -> boolean)?
SpriteAnim.stats = {} :: { [string]: { frames: number, steps: number, shown: number, cell: number, loaded: boolean } }

type Body = {
	model: Model,
	root: BasePart,
	S: any,
	gui: BillboardGui,
	img: ImageLabel,
	hip: number,
	phase: number,
	stat: { frames: number, steps: number, shown: number, cell: number, loaded: boolean },
	lastCell: number,
}
local bodies: { [Model]: Body } = {}

local function sheetUrl(S: any, n: number): string
	local id = S.sheets[n]
	if id and id ~= 0 then
		return "rbxassetid://" .. id
	end
	return "rbxasset://sonarcreatures/" .. S.id .. "_" .. n .. ".png"
end

local function build(model: Model): Body?
	local root = model.PrimaryPart
	local id = model:GetAttribute("Creature")
	if not root or typeof(id) ~= "string" then
		return nil
	end
	local folder = ReplicatedStorage.Shared:FindFirstChild("CreatureSprites")
	local ms = folder and folder:FindFirstChild(id)
	if not ms or not ms:IsA("ModuleScript") then
		return nil
	end
	local S = require(ms) :: any
	local gui = Instance.new("BillboardGui")
	gui.Name = "CreatureSprite"
	gui.Adornee = root
	gui.Size = UDim2.fromScale(S.size[1], S.size[2])
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false
	gui.MaxDistance = 400
	gui.ClipsDescendants = true
	gui.Enabled = false
	local img = Instance.new("ImageLabel")
	img.Name = "Body"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.ImageRectSize = Vector2.new(S.cellPx[1], S.cellPx[2])
	img.Image = sheetUrl(S, 1)
	img.ResampleMode = Enum.ResamplerMode.Default
	img.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	SpriteAnim.stats[id] = SpriteAnim.stats[id] or { frames = 0, steps = 0, shown = 0, cell = -1, loaded = false }
	return {
		model = model,
		root = root,
		S = S,
		gui = gui,
		img = img,
		hip = (model:GetAttribute("Hip") :: number?) or 2,
		phase = math.random(),
		stat = SpriteAnim.stats[id],
		lastCell = -1,
	}
end

local function update(b: Body, dt: number, camPos: Vector3)
	local S = b.S
	local v = b.root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local chasing = b.model:GetAttribute("State") == "Chase"
	-- 위상: 한 주기(발 두 번) = 보폭 × 2
	local before = b.phase
	b.phase = (b.phase + speed * dt / (S.stride * 2)) % 1
	if speed > 0.5 and ((before < 0.5 and b.phase >= 0.5) or b.phase < before) then
		b.stat.steps += 1
		if SpriteAnim.onStep then
			SpriteAnim.onStep(b.model, b.root.Position + Vector3.new(0, -(b.hip + 1), 0), math.clamp(speed / 10, 0.3, 1.4))
		end
	end
	local show = if SpriteAnim.visible then SpriteAnim.visible(b.model) else true
	b.gui.Enabled = show
	if not show then
		return
	end
	b.stat.shown += 1
	-- 자세
	local pose = 0
	local me = Players.LocalPlayer.Character
	local hrp = me and me:FindFirstChild("HumanoidRootPart") :: BasePart?
	local near = if hrp then (hrp.Position - b.root.Position).Magnitude else math.huge
	if chasing and near < 6 then
		pose = 8
	elseif speed > 0.5 then
		pose = math.floor(b.phase * 4) % 4 + (if chasing then 4 else 0)
	end
	-- 방향: 카메라가 괴물 기준 어디에 있나(디자인 좌표: 앞 +Z, 왼쪽 +X → 게임 로컬은 x·z 를 뒤집은 것)
	local lp = b.root.CFrame:PointToObjectSpace(camPos)
	local yaw = math.atan2(-lp.X, -lp.Z)
	local yi = math.floor(yaw / (2 * math.pi / S.yaws) + 0.5) % S.yaws
	local cell = yi * S.poses + pose
	if cell ~= b.lastCell then
		b.lastCell = cell
		b.stat.cell = cell
		local per = S.cols * S.rows
		local sheet = cell // per + 1
		local k = cell % per
		local url = sheetUrl(S, sheet)
		if b.img.Image ~= url then
			b.img.Image = url
		end
		b.img.ImageRectOffset = Vector2.new((k % S.cols) * S.cellPx[1], (k // S.cols) * S.cellPx[2])
	end
	-- 그림 가운데: 바닥 위 centerY, 몸 앞쪽 centerZ
	local look = b.root.CFrame.LookVector
	b.gui.StudsOffsetWorldSpace = Vector3.new(0, -(b.hip + 1) + S.centerY, 0) + Vector3.new(look.X, 0, look.Z) * S.centerZ
	b.stat.frames += 1
	b.stat.loaded = b.img.IsLoaded
end

local failedAt: { [Model]: number } = {} -- (그림 몸 만들기 실패: 1초 동안 다시 하지 않는다)
function SpriteAnim.step(model: Model, dt: number, camPos: Vector3)
	local b = bodies[model]
	if not b or b.root ~= model.PrimaryPart then
		if b then
			b.gui:Destroy()
			bodies[model] = nil
		end
		local f = failedAt[model]
		if f and os.clock() - f < 1 then
			return
		end
		local nb = build(model)
		if not nb then
			failedAt[model] = os.clock()
			return
		end
		failedAt[model] = nil
		bodies[model] = nb
		b = nb
	end
	update(b :: Body, dt, camPos)
end

function SpriteAnim.cleanup()
	for m in failedAt do
		if not m.Parent then
			failedAt[m] = nil
		end
	end
	for m, b in bodies do
		if not m.Parent then
			b.gui:Destroy()
			bodies[m] = nil
		end
	end
end

function SpriteAnim.reset()
	for _, st in SpriteAnim.stats do
		st.frames, st.steps, st.shown = 0, 0, 0
	end
end

-- (점프스케어) 이 괴물의 덮침 그림(정면): 이미지 주소와 칸 위치
function SpriteAnim.attackFrame(id: string): (string?, Vector2?, Vector2?)
	local folder = ReplicatedStorage.Shared:FindFirstChild("CreatureSprites")
	local ms = folder and folder:FindFirstChild(id)
	if not ms or not ms:IsA("ModuleScript") then
		return nil
	end
	local S = require(ms) :: any
	local cell = 8 -- 정면 · 덮침
	local per = S.cols * S.rows
	local k = cell % per
	return sheetUrl(S, cell // per + 1), Vector2.new((k % S.cols) * S.cellPx[1], (k // S.cols) * S.cellPx[2]), Vector2.new(S.cellPx[1], S.cellPx[2])
end

return SpriteAnim
