--!strict
-- 괴물: 모델 생성 + AI(배회 → 소리 감지 → 수색 → 추격 → 추격 해제).
-- 보이지 않는 검은 몸. 음파가 닿으면 클라이언트가 몸의 윤곽선을 그린다(SonarDynamic).
-- 이동은 PathfindingService 경로만 따라가므로 벽을 통과하지 않는다. 막히면 경로를 다시 계산하고, 그래도 안 되면 목표를 바꾼다.

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.MapKit)
local Doors = require(script.Parent.Doors)
local SoundBus = require(script.Parent.SoundBus)
local Hiding = require(script.Parent.Hiding)

local MC = Config.Monster

local Monster = {}
Monster.__index = Monster
-- 안전 구역(시작 방) 판정: Round 가 채운다. 그 안의 플레이어는 보지도 잡지도 않고, 그 안으로 들어가지 않는다
Monster.isSafe = function(_pos: Vector3): boolean
	return false
end

export type State = "Wander" | "Alert" | "Investigate" | "Search" | "Chase" | "Disguise"

-- ── 챕터별 머리 도형: 1 삼각형 · 2 사각형 · 3 원 · 4 별 · 5 육각형 (그 이후는 처음부터 반복) ──
-- cy: 머리 중심 높이, eye = {x, y, 반지름}, mouth = {반폭, 윗입술 y, 깊이}, 좌표는 머리 중심 기준
local HeadSpec: { { cy: number, eye: { number }, mouth: { number }, verts: { { number } }?, circle: number?, star: { number }?, hex: number? } } = {
	{ cy = 4.5, eye = { 0.2, 0.0, 0.08 }, mouth = { 0.5, -0.25, 0.35 }, verts = { { -0.85, -0.75 }, { 0.85, -0.75 }, { 0, 0.75 } } },
	{ cy = 4.4, eye = { 0.28, 0.2, 0.09 }, mouth = { 0.5, -0.1, 0.4 }, verts = { { -0.8, -0.65 }, { 0.8, -0.65 }, { 0.8, 0.65 }, { -0.8, 0.65 } } },
	{ cy = 4.35, eye = { 0.22, 0.12, 0.09 }, mouth = { 0.45, -0.2, 0.4 }, circle = 0.6 },
	{ cy = 4.55, eye = { 0.16, 0.12, 0.065 }, mouth = { 0.3, -0.12, 0.25 }, star = { 1.0, 0.48 } },
	{ cy = 4.35, eye = { 0.26, 0.15, 0.09 }, mouth = { 0.5, -0.12, 0.38 }, hex = 0.72 },
}

-- ── 몸 조립 공통: 팔·다리 묶음은 관절(Motor6D)에, 나머지는 루트에 붙인다. 몸은 완전히 투명(음파에만 드러난다) ──
-- prefix: 관절 이름 앞부분(같은 모델에 몸이 둘일 때 구분), holder: 관절 받침 파트를 둘 곳
local function rig(model: Model, root: BasePart, cf: CFrame, parts: { BasePart }, groupParts: { [string]: { BasePart } }, joints: { [string]: Vector3 }, prefix: string, holder: Instance?)
	local grouped: { [BasePart]: boolean } = {}
	for name, list in groupParts do
		local off = joints[name]
		if off then
			local pv = Instance.new("Part")
			pv.Name = "Pivot" .. name
			pv.Size = Vector3.new(0.2, 0.2, 0.2)
			pv.Transparency = 1
			pv.CanCollide = false
			pv.CanQuery = false
			pv.CanTouch = false
			pv.Massless = true
			pv.CFrame = cf * CFrame.new(off)
			pv.Parent = holder or model
			local motor = Instance.new("Motor6D")
			motor.Name = prefix .. name
			motor.Part0 = root
			motor.Part1 = pv
			motor.C0 = CFrame.new(off)
			motor.C1 = CFrame.identity
			motor.Parent = root
			for _, p in list do
				p.Anchored = false
				p.CanCollide = false
				p.CanQuery = false
				p.Massless = true
				local w = Instance.new("WeldConstraint")
				w.Part0 = pv
				w.Part1 = p
				w.Parent = p
				grouped[p] = true
			end
		end
	end
	for _, p in parts do
		if p.Name == "Part" then
			p.Name = "Body"
		end
		-- 몸은 완전히 투명: 음파를 맞을 때만 선으로 드러난다(검은 몸이 선을 가려 위치가 드러나지 않게)
		p.Transparency = 1
		p.CastShadow = false
		if not grouped[p] then
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = p
			w.Parent = p
		end
	end
end

local function makeHumanoid(model: Model, hip: number, speed: number): Humanoid
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
	return hum
end

-- ── 도플갱어 ──
-- 루트(2x2x1) 가운데 기준 바닥은 y = -3 (HipHeight 2). 사람 모습은 약 5.2, 괴물 모습은 약 6.5 스터드.
local DOPPEL_HIP = 2.0

-- 사람 모습: 로블록스 기본 아바타 비율의 상자 6개(머리·몸통·팔·다리). 음파에는 상자 윤곽(사람 모양)으로 보인다
local function buildDisguise(model: Model, root: BasePart, cf: CFrame)
	local folder = Instance.new("Folder")
	folder.Name = "Disguise"
	folder.Parent = model
	local parts: { BasePart } = {}
	local groups: { [string]: { BasePart } } = {}
	local function box(name: string, center: Vector3, size: Vector3, group: string?)
		local p = Kit.box(folder, cf * CFrame.new(center), size, { name = name })
		table.insert(parts, p)
		if group then
			groups[group] = groups[group] or {}
			table.insert(groups[group], p)
		end
	end
	box("Head", Vector3.new(0, 1.62, 0), Vector3.new(1.15, 1.2, 1.15))
	box("Torso", Vector3.new(0, 0, 0), Vector3.new(2, 2, 1))
	box("LeftArm", Vector3.new(-1.5, 0, 0), Vector3.new(1, 2, 1), "Arm-1")
	box("RightArm", Vector3.new(1.5, 0, 0), Vector3.new(1, 2, 1), "Arm1")
	box("LeftLeg", Vector3.new(-0.5, -2, 0), Vector3.new(1, 2, 1), "Leg-1")
	box("RightLeg", Vector3.new(0.5, -2, 0), Vector3.new(1, 2, 1), "Leg1")
	-- (관절은 어깨·엉덩이 위쪽: 팔·다리가 그 점을 축으로 흔들린다)
	rig(model, root, cf, parts, groups, {
		["Arm-1"] = Vector3.new(-1.5, 0.9, 0),
		["Arm1"] = Vector3.new(1.5, 0.9, 0),
		["Leg-1"] = Vector3.new(-0.5, -1, 0),
		["Leg1"] = Vector3.new(0.5, -1, 0),
	}, "DJoint", folder)
end

-- 괴물 모습(확정 시안): 둥글고 긴 머리 위쪽에 빛나는 두 눈, 이마에서 배까지 이어지는 지그재그 틈,
-- 솟은 어깨, 무릎까지 늘어진 굵은 팔과 갈고리 손가락, 굽힌 다리. 앞으로 숙인 자세(머리가 앞으로 나온다).
-- 좌표는 시안 그림(픽셀, 가운데 x=130, 바닥 y=394, 38.2px = 1스터드)에서 옮긴다. 앞 = -Z
-- 틈(Slit)과 벌어진 입(Maw)은 둘 다 만들어 두고 음파 대상 태그로 바꿔 낀다(덮칠 때 입이 벌어진다)
local function buildBeast(model: Model, root: BasePart, cf: CFrame)
	local folder = Instance.new("Folder")
	folder.Name = "Beast"
	folder.Parent = model
	local S = 38.2
	local parts: { BasePart } = {}
	local groups: { [string]: { BasePart } } = {}
	local group: string? = nil
	local mark: string? = nil -- "Slit" / "Maw"
	local function P(px: number, py: number, z: number): Vector3
		return Vector3.new((px - 130) / S, (394 - py) / S - 3, z)
	end
	local function seg(a: Vector3, b: Vector3, r: number, name: string?)
		local shape = if (b - a).Magnitude > r * 4 then "Line" else "Disc"
		local p = Kit.cylinder(folder, cf:PointToWorldSpace(a), cf:PointToWorldSpace(b), r, { shape = shape, name = name, tag = mark ~= "Maw" })
		if mark then
			p:SetAttribute(mark, true)
		end
		table.insert(parts, p)
		if group then
			groups[group] = groups[group] or {}
			table.insert(groups[group], p)
		end
	end
	-- 깊이(z): 머리가 가장 앞, 목·어깨, 몸통, 엉덩이 순으로 뒤
	local function depth(py: number): number
		if py < 210 then
			return -1.05
		elseif py < 236 then
			return -0.75
		elseif py < 300 then
			return -0.45
		end
		return -0.25
	end
	-- 3차 베지어를 n 토막의 선으로(zf: 높이에 따른 깊이 함수)
	local function bez(x0: number, y0: number, x1: number, y1: number, x2: number, y2: number, x3: number, y3: number, n: number, zf: (number) -> number, r: number?)
		local prev = P(x0, y0, zf(y0))
		for i = 1, n do
			local t = i / n
			local u = 1 - t
			local x = u * u * u * x0 + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t * t * t * x3
			local y = u * u * u * y0 + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t * y3
			local p = P(x, y, zf(y))
			seg(prev, p, r or 0.035)
			prev = p
		end
	end
	local function poly(pts: { number }, zf: (number) -> number, r: number?)
		for i = 1, #pts - 2, 2 do
			seg(P(pts[i], pts[i + 1], zf(pts[i + 1])), P(pts[i + 2], pts[i + 3], zf(pts[i + 3])), r or 0.035)
		end
	end
	-- 머리(둥글고 위아래로 긴 돔)
	bez(112, 186, 108, 160, 116, 146, 130, 146, 3, depth)
	bez(130, 146, 144, 146, 152, 160, 148, 186, 3, depth)
	bez(148, 186, 146, 198, 140, 206, 130, 208, 2, depth)
	bez(130, 208, 120, 206, 114, 198, 112, 186, 2, depth)
	-- 빛나는 두 눈(클라이언트가 음파 뒤에도 잠깐 빛나게 한다: 이름 Eye)
	for _, ex in { 122, 138 } do
		seg(P(ex, 166, -1.12), P(ex, 166, -1.18), 0.11, "Eye")
	end
	-- 목, 솟은 어깨(승모근), 둥근 어깨 근육
	poly({ 118, 204, 114, 216 }, depth)
	poly({ 142, 204, 146, 216 }, depth)
	bez(114, 216, 100, 218, 90, 222, 84, 232, 2, depth)
	bez(146, 216, 160, 218, 170, 222, 176, 232, 2, depth)
	bez(84, 232, 78, 242, 78, 252, 84, 262, 2, depth)
	bez(176, 232, 182, 242, 182, 252, 176, 262, 2, depth)
	-- 몸통(좁아지는 허리) + 가슴 근육 선
	bez(90, 240, 88, 270, 98, 300, 108, 318, 3, depth)
	poly({ 108, 318, 152, 318 }, depth)
	bez(152, 318, 162, 300, 172, 270, 170, 240, 3, depth)
	bez(98, 248, 110, 258, 120, 256, 124, 250, 2, depth, 0.025)
	bez(162, 248, 150, 258, 140, 256, 136, 250, 2, depth, 0.025)
	-- 이마에서 배까지 이어지는 지그재그 틈(평소)
	mark = "Slit"
	poly({ 130, 172, 127, 180, 133, 188, 127, 196, 133, 204, 127, 212, 133, 220, 126, 230, 134, 240, 126, 250, 134, 260, 126, 270, 134, 280, 127, 290, 133, 300, 128, 310, 130, 318 }, function(py)
		return depth(py) - 0.06
	end)
	-- 벌어진 세로 입(덮칠 때): 머리~배의 렌즈 모양 + 양쪽 이빨
	mark = "Maw"
	local function front(py: number): number
		return depth(py) - 0.08
	end
	bez(130, 168, 116, 196, 112, 236, 114, 266, 3, front)
	bez(114, 266, 116, 292, 122, 308, 130, 322, 2, front)
	bez(130, 322, 138, 308, 144, 292, 146, 266, 2, front)
	bez(146, 266, 148, 236, 144, 196, 130, 168, 3, front)
	for _, t in { { 124, 182, 130, 185 }, { 121, 196, 128, 197 }, { 118, 210, 126, 210 }, { 116, 224, 124, 223 }, { 115, 238, 123, 237 }, { 115, 252, 123, 250 }, { 116, 266, 124, 264 }, { 118, 280, 125, 278 }, { 121, 294, 127, 292 }, { 124, 306, 129, 304 } } do
		poly({ t[1], t[2], t[3], t[4] }, front, 0.025)
		poly({ 260 - t[1], t[2], 260 - t[3], t[4] }, front, 0.025)
	end
	mark = nil
	-- 팔: 무릎 아래까지 늘어진 굵은 팔(바깥선·안쪽선) + 손바닥 + 갈고리 손가락 4개. 손은 몸 앞쪽으로
	local function armZ(py: number): number
		return -0.45 - math.clamp((py - 232) / 162, 0, 1) * 0.55
	end
	for _, s in { -1, 1 } do
		local function X(px: number): number
			return if s < 0 then px else 260 - px
		end
		group = "Arm" .. s
		bez(X(84), 232, X(72), 258, X(70), 280, X(74), 298, 2, armZ)
		bez(X(74), 298, X(68), 320, X(66), 340, X(70), 356, 2, armZ)
		bez(X(100), 252, X(92), 272, X(90), 284, X(92), 298, 2, armZ)
		bez(X(92), 298, X(90), 320, X(86), 340, X(86), 356, 2, armZ)
		bez(X(70), 356, X(68), 366, X(72), 372, X(78), 374, 2, armZ)
		poly({ X(78), 374, X(86), 370 }, armZ)
		bez(X(86), 370, X(88), 364, X(88), 360, X(86), 356, 1, armZ)
		bez(X(72), 370, X(64), 380, X(62), 388, X(66), 394, 2, armZ, 0.028)
		bez(X(77), 373, X(74), 384, X(74), 392, X(79), 396, 2, armZ, 0.028)
		bez(X(82), 372, X(84), 384, X(86), 390, X(90), 392, 2, armZ, 0.028)
		bez(X(86), 366, X(94), 372, X(96), 378, X(94), 386, 2, armZ, 0.028)
	end
	-- 다리: 무릎을 굽히고 한 발을 내딛은 자세, 크고 납작한 발
	local function legZ(py: number): number
		return if py < 362 then -0.25 - (py - 318) / 44 * 0.2 else -0.45 + (py - 362) / 32 * 0.45
	end
	group = "Leg-1"
	bez(108, 318, 100, 340, 98, 352, 104, 362, 2, legZ)
	bez(104, 362, 100, 376, 98, 386, 96, 392, 2, legZ)
	bez(126, 324, 122, 340, 120, 352, 118, 362, 2, legZ)
	bez(118, 362, 116, 374, 114, 384, 114, 392, 2, legZ)
	poly({ 92, 394, 118, 394 }, legZ)
	group = "Leg1"
	bez(152, 318, 162, 336, 166, 350, 160, 362, 2, legZ)
	bez(160, 362, 166, 374, 170, 386, 174, 392, 2, legZ)
	bez(134, 324, 140, 340, 144, 352, 144, 362, 2, legZ)
	bez(144, 362, 146, 374, 148, 384, 150, 392, 2, legZ)
	poly({ 146, 394, 178, 394 }, legZ)
	group = nil
	rig(model, root, cf, parts, groups, {
		["Arm-1"] = P(84, 232, -0.45),
		["Arm1"] = P(176, 232, -0.45),
		["Leg-1"] = P(116, 318, -0.25),
		["Leg1"] = P(144, 318, -0.25),
	}, "Joint", folder)
end

local function buildDoppel(cf: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Doppel"
	model:SetAttribute(Config.Tags.Dynamic, true)
	model:SetAttribute("State", "Disguise")
	model:SetAttribute("Form", "Disguise")
	model:SetAttribute("BodyVersion", 1)
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = true
	root.CanTouch = false
	root.CFrame = cf
	root.Parent = model
	model.PrimaryPart = root
	buildDisguise(model, root, cf)
	makeHumanoid(model, DOPPEL_HIP, Config.Doppel.WalkSpeed)
	CollectionService:AddTag(model, Config.Tags.Monster)
	CollectionService:AddTag(model, Config.Tags.Doppel)
	return model
end

-- ── 모델 ──
local function buildModel(cf: CFrame, stage: number): Model
	local model = Instance.new("Model")
	model.Name = "Monster"
	model:SetAttribute(Config.Tags.Dynamic, true)
	model:SetAttribute("State", "Wander")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1.2)
	root.Transparency = 1
	root.CanCollide = true
	root.CanTouch = false
	root.CFrame = cf
	root.Parent = model
	model.PrimaryPart = root

	local function at(v: Vector3): Vector3
		return cf:PointToWorldSpace(v)
	end
	-- 몸통(앞으로 숙인 마른 몸), 머리, 긴 팔, 다리. 루트 가운데 기준 바닥은 y = -5
	local parts: { BasePart } = {}
	-- 팔·다리는 어깨·엉덩이 관절(Motor6D)에 붙여 걸을 때 흔든다(Monster.animate)
	local group: string? = nil
	local groupParts: { [string]: { BasePart } } = {}
	local function add(p: BasePart)
		table.insert(parts, p)
		if group then
			local l = groupParts[group] or {}
			groupParts[group] = l
			table.insert(l, p)
		end
	end
	-- 레퍼런스(손그림): 작은 머리 + 짧은 목 + 좁고 긴 몸통 + 바깥으로 벌어진 긴 팔(발톱 5개) + 길고 가는 다리. 바닥 y = -5, 앞 = -Z
	local function seg(a: Vector3, b: Vector3, r: number)
		-- 음파에는 한 획으로: 막대는 가운데 선 하나(Line), 얇은 원판은 원 하나(Disc)
		local shape = if (b - a).Magnitude > r * 4 then "Line" else "Disc"
		add(Kit.cylinder(model, at(a), at(b), r, { shape = shape }))
	end
	-- 손으로 그린 듯 흔들리는 선(결정적 난수라 매번 같은 모양)
	local seed = 0
	local function rnd(): number
		seed += 1
		local x = math.sin(seed * 12.9898) * 43758.5453
		return x - math.floor(x) - 0.5
	end
	local function ink(a: Vector3, b: Vector3, r: number)
		local d = b - a
		local len = d.Magnitude
		local dir = d.Unit
		local k = math.min(1, len / 2) -- 짧은 선일수록 덜 삐져나오게
		a = a - dir * (0.05 + 0.08 * (rnd() + 0.5)) * k
		b = b + dir * (0.05 + 0.08 * (rnd() + 0.5)) * k
		local n = math.max(2, math.floor(len / 1.6))
		local prev = a
		for i = 1, n do
			local p = a:Lerp(b, i / n)
			if i < n then
				p += Vector3.new(rnd() * 0.07, rnd() * 0.04, rnd() * 0.07)
			end
			seg(prev, p, r)
			prev = p
		end
	end
	local V3 = Vector3.new
	-- 몸통: 사다리꼴 네 선 + 어깨에서 가슴으로 겹치는 두 선
	ink(V3(-0.9, 2.6, -0.35), V3(-0.65, 0.5, 0), 0.03)
	ink(V3(0.9, 2.6, -0.35), V3(0.65, 0.5, 0), 0.03)
	ink(V3(-0.9, 2.6, -0.35), V3(0.9, 2.6, -0.35), 0.03)
	ink(V3(-0.65, 0.5, 0), V3(0.65, 0.5, 0), 0.03)
	ink(V3(-0.9, 2.5, -0.35), V3(-0.15, 1.5, -0.1), 0.025)
	ink(V3(0.9, 2.5, -0.35), V3(0.15, 1.5, -0.1), 0.025)
	-- 짧은 목
	ink(V3(-0.2, 3.75, -0.65), V3(-0.3, 2.6, -0.4), 0.03)
	ink(V3(0.2, 3.75, -0.65), V3(0.3, 2.6, -0.4), 0.03)
	-- 머리(챕터별 도형): 눈 = 작은 동그라미 + 점, 입 = 가로로 넓고 세로 이빨선
	local spec = HeadSpec[((stage - 1) % #HeadSpec) + 1]
	local cy, zf = spec.cy, -1.0
	local function P(x: number, y: number, z: number): Vector3
		return Vector3.new(x, cy + y, z)
	end
	local verts: { { number } } = spec.verts or {}
	if spec.star then
		for i = 0, 9 do
			local r = if i % 2 == 0 then spec.star[1] else spec.star[2]
			local ang = math.pi / 2 + i * math.pi / 5
			table.insert(verts, { r * math.cos(ang), r * math.sin(ang) })
		end
	elseif spec.hex then
		for i = 0, 5 do
			local ang = i * math.pi / 3
			table.insert(verts, { spec.hex * math.cos(ang), spec.hex * math.sin(ang) })
		end
	end
	if spec.circle then
		seg(P(0, 0, zf), P(0, 0, zf + 0.06), spec.circle)
	else
		for i, a in verts do
			local b = verts[i % #verts + 1]
			ink(P(a[1], a[2], zf), P(b[1], b[2], zf), 0.03)
		end
	end
	local ex, ey, er = spec.eye[1], spec.eye[2], spec.eye[3]
	for _, s in { -1, 1 } do
		seg(P(s * ex, ey, zf - 0.03), P(s * ex, ey, zf - 0.06), er)
		seg(P(s * ex, ey, zf - 0.06), P(s * ex, ey, zf - 0.09), 0.025)
	end
	local mw, my, mh = spec.mouth[1], spec.mouth[2], spec.mouth[3]
	local function arcY(x: number): number
		return my - mh * (1 - (x / mw) ^ 2) * 0.35 - mh * 0.65
	end
	local zm = zf - 0.04
	seg(P(-mw, my, zm), P(mw, my, zm), 0.025)
	seg(P(-mw, my, zm), P(-mw * 0.9, arcY(-mw * 0.9), zm), 0.025)
	seg(P(mw, my, zm), P(mw * 0.9, arcY(mw * 0.9), zm), 0.025)
	for i = 0, 5 do
		local x0 = -mw * 0.9 + 1.8 * mw * i / 6
		local x1 = -mw * 0.9 + 1.8 * mw * (i + 1) / 6
		seg(P(x0, arcY(x0), zm), P(x1, arcY(x1), zm), 0.025)
	end
	for i = 1, 8 do
		local x = -mw * 0.9 + 1.8 * mw * i / 9
		seg(P(x, my, zm), P(x, arcY(x), zm), 0.018)
	end
	for _, s in { -1, 1 } do
		-- 긴 팔: 한 줄, 어깨 → 팔꿈치 → 손목, V자로 벌어짐
		group = "Arm" .. s
		local sh = V3(0.9 * s, 2.55, -0.35)
		local el = V3(1.55 * s, 0.15, -0.85)
		local wr = V3(2.1 * s, -2.1, -1.0)
		ink(sh, el, 0.03)
		ink(el, wr, 0.03)
		-- 부채꼴로 퍼지는 긴 발톱 5개
		for k = -2, 2 do
			local mid = wr + V3(k * 0.16 + 0.05 * s, -0.8, -0.12)
			local tip = wr + V3(k * 0.3 + 0.12 * s, -1.55, -0.35 + 0.05 * k)
			seg(wr + V3(k * 0.07, 0, 0), mid, 0.018)
			seg(mid, tip, 0.014)
		end
		-- 길고 곧은 다리: 한 줄 + 무릎 꺾임, 작은 발
		group = "Leg" .. s
		for _, e in { 0.4 } do
			local x0, xk, xa = e * s, (e + 0.06) * s, (e + 0.08) * s
			ink(V3(x0, 0.5, 0), V3(xk, -2.3, -0.2), 0.03)
			ink(V3(xk, -2.3, -0.2), V3(xa, -4.75, 0.1), 0.03)
		end
		local xc = 0.48 * s
		ink(V3(xc, -4.75, 0.1), V3(xc, -4.97, -0.8), 0.03)
		ink(V3(xc, -4.97, 0.35), V3(xc, -4.97, -0.8), 0.03)
		ink(V3(xc, -4.75, 0.1), V3(xc, -4.97, 0.35), 0.03)
	end
	group = nil
	local JOINTS: { [string]: Vector3 } = {
		["Arm-1"] = Vector3.new(-0.9, 2.55, -0.35),
		["Arm1"] = Vector3.new(0.9, 2.55, -0.35),
		["Leg-1"] = Vector3.new(-0.4, 0.5, 0),
		["Leg1"] = Vector3.new(0.4, 0.5, 0),
	}
	rig(model, root, cf, parts, groupParts, JOINTS, "Joint")
	makeHumanoid(model, 4.0, MC.WanderSpeed)
	CollectionService:AddTag(model, Config.Tags.Monster)
	return model
end

-- ── AI ──
export type Monster = typeof(setmetatable({} :: {
	model: Model,
	root: BasePart,
	hum: Humanoid,
	state: State,
	nodes: { Vector3 },
	waypoints: { PathWaypoint },
	wp: number,
	goal: Vector3?,
	target: Player?,
	lastSeen: number,
	lastKnown: Vector3?,
	alertUntil: number,
	searchCenter: Vector3?,
	searchUntil: number,
	lastRepath: number,
	progressPos: Vector3,
	progressT: number,
	stuck: number,
	alive: boolean,
	path: Path,
	rayParams: RaycastParams,
	onCatch: (Player, Monster) -> (),
	log: { string },
	geometry: Instance,
	startAt: number,
	stateChanged: number,
	route: ((Vector3, Vector3, boolean?) -> { Vector3 }?)?,
	legGoal: Vector3?,
	pullSpot: Vector3?, -- 쫓던 플레이어가 숨는 것을 봤다: 그 숨는 곳 앞
	lastHunt: number,
	joints: { { motor: Motor6D, base: CFrame, offset: number, amp: number } },
	phase: number,
	animT: number,
	kind: string, -- "main" / "doppel"
	form: string, -- 도플갱어: "Disguise"(사람 모습) → "Bursting" → "Beast". 메인 괴물은 "Beast"
	cfg: any, -- 속도·거리 설정(도플갱어는 Config.Doppel 이 먼저, 없으면 Config.Monster)
	discoveredBy: Player?,
	transformAt: number,
	pauseUntil: number,
	nextPause: number,
	nextPing: number,
	mawOpen: boolean,
}, Monster))

local function between(r: { number }): number
	return r[1] + math.random() * (r[2] - r[1])
end

-- kind = "doppel" 이면 도플갱어(사람 모습으로 시작). 배회 지점(spawnPos)은 바닥 + 3
function Monster.new(parent: Instance, spawnPos: Vector3, nodes: { Vector3 }, geometry: Instance, onCatch: (Player, any) -> (), stage: number?, kind: string?): Monster
	local isDoppel = kind == "doppel"
	local cfg: any = if isDoppel
		then setmetatable({}, {
			__index = function(_, k)
				local v = (Config.Doppel :: any)[k]
				if v ~= nil then
					return v
				end
				return (MC :: any)[k]
			end,
		})
		else MC
	local model = if isDoppel then buildDoppel(CFrame.new(spawnPos + Vector3.new(0, 0.1, 0))) else buildModel(CFrame.new(spawnPos + Vector3.new(0, 2.2, 0)), stage or 1)
	model.Parent = parent
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { geometry }
	rp.RespectCanCollide = true
	local self = setmetatable({
		model = model,
		root = root,
		hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid,
		state = "Wander" :: State,
		nodes = nodes,
		waypoints = {},
		wp = 1,
		goal = nil,
		target = nil,
		lastSeen = 0,
		lastKnown = nil,
		alertUntil = 0,
		searchCenter = nil,
		searchUntil = 0,
		lastRepath = 0,
		progressPos = root.Position,
		progressT = os.clock(),
		stuck = 0,
		alive = true,
		path = PathfindingService:CreatePath({
			AgentRadius = cfg.AgentRadius,
			AgentHeight = cfg.AgentHeight,
			AgentCanJump = false,
			AgentCanClimb = false,
			WaypointSpacing = 4,
			Costs = { SafeZone = math.huge }, -- (안전 구역 칸은 지나가지 않는다)
		}),
		rayParams = rp,
		onCatch = onCatch,
		log = {},
		geometry = geometry,
		startAt = os.clock() + cfg.StartDelay,
		stateChanged = os.clock(),
		route = nil,
		legGoal = nil,
		pullSpot = nil,
		lastHunt = os.clock(),
		joints = {},
		phase = 0,
		animT = 0,
		kind = if isDoppel then "doppel" else "main",
		form = if isDoppel then "Disguise" else "Beast",
		cfg = cfg,
		discoveredBy = nil,
		transformAt = 0,
		pauseUntil = 0,
		nextPause = os.clock() + between(Config.Doppel.PauseEvery),
		nextPing = os.clock() + between(Config.Doppel.FakePingEvery),
		mawOpen = false,
	}, Monster)
	if isDoppel then
		self:setState("Disguise")
	end
	for _, name in { "Leg-1", "Leg1", "Arm-1", "Arm1" } do
		local motor = root:FindFirstChild("Joint" .. name) :: Motor6D?
		if motor then
			local isLeg = name:sub(1, 3) == "Leg"
			local left = name:find("-1") ~= nil
			-- 다리끼리, 팔끼리 반대로, 팔은 같은 쪽 다리와 반대로
			table.insert(self.joints, { motor = motor, base = motor.C0, offset = if (isLeg == left) then 0 else math.pi, amp = if isLeg then 0.5 else 0.38 })
		end
	end
	return self
end

-- 걷는 모습: 속도만큼 팔다리를 흔든다(초당 10번만 바꿔 네트워크 부담을 줄인다. 음파는 순간 모습만 보여 준다)
function Monster.animate(self: Monster, dt: number)
	self.animT += dt
	if self.animT < 0.1 or #self.joints == 0 then
		return
	end
	local step = self.animT
	self.animT = 0
	local v = self.root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	self.phase = (self.phase + step * speed * 0.55) % (math.pi * 2)
	local amt = math.clamp(speed / 3, 0, 1) -- (느리게 걸어도 팔다리가 크게 흔들려야 음파에 걷는 모습이 보인다)
	for _, j in self.joints do
		j.motor.C0 = j.base * CFrame.Angles(math.sin(self.phase + j.offset) * j.amp * amt, 0, 0)
	end
end

function Monster.note(self: Monster, s: string)
	table.insert(self.log, string.format("%.1f %s", os.clock(), s))
	if #self.log > 40 then
		table.remove(self.log, 1)
	end
end

function Monster.setState(self: Monster, s: State)
	if self.state ~= s then
		self:note(self.state .. "->" .. s)
		self.state = s
		self.stateChanged = os.clock()
		self.model:SetAttribute("State", s)
	end
	local cfg = self.cfg
	local speed = cfg.WanderSpeed
	if s == "Disguise" then
		speed = cfg.WalkSpeed
	elseif s == "Investigate" or s == "Search" then
		speed = cfg.InvestigateSpeed
	elseif s == "Chase" then
		speed = cfg.ChaseSpeed
	elseif s == "Alert" then
		speed = 0
	end
	self.hum.WalkSpeed = speed
	if s ~= "Chase" and self.mawOpen then
		self:setMaw(false)
	end
end

-- (테스트용) 경로 계산 횟수·시간, tick 횟수
Monster.stats = { pathCalls = 0, pathWall = 0, ticks = 0 }

local function feet(p: Vector3): Vector3
	return p - Vector3.new(0, 4.5, 0)
end

-- 경로 계산(양보 있음). 성공하면 true
function Monster.pathTo(self: Monster, rawGoal: Vector3): boolean
	self.lastRepath = os.clock()
	-- 목표를 바닥 높이로 내린다(소리 위치는 머리 높이일 수 있다)
	local goal = rawGoal
	local down = workspace:Raycast(rawGoal + Vector3.new(0, 1, 0), Vector3.new(0, -14, 0), self.rayParams)
	if down then
		goal = down.Position + Vector3.new(0, 0.5, 0)
	end
	self.legGoal = nil
	local from = feet(self.root.Position)
	local function compute(to: Vector3): boolean
		local c0 = os.clock()
		local ok = pcall(function()
			self.path:ComputeAsync(from, to)
		end)
		Monster.stats.pathCalls += 1
		Monster.stats.pathWall += os.clock() - c0
		return ok and self.alive and self.path.Status == Enum.PathStatus.Success
	end
	local function take(final: boolean): boolean
		self.waypoints = self.path:GetWaypoints()
		self.wp = math.min(2, #self.waypoints)
		self.goal = goal
		self.legGoal = if final then nil else goal
		return true
	end
	if compute(goal) then
		return take(true)
	end
	if not self.alive then
		return false
	end
	-- 멀리 돌아가는 길: 타일 경로를 따라 몇 칸 앞까지만 계산하고, 도착하면 다시 계산한다(follow)
	local route = self.route and self.route(from, goal, true)
	if route and #route > 1 then
		for _, ahead in { MC.LegTiles, math.ceil(MC.LegTiles / 2), 2 } do
			local idx = math.min(#route, ahead + 1)
			if compute(route[idx]) then
				return take(idx == #route)
			end
		end
	end
	self.waypoints = {}
	self.wp = 1
	return false
end

-- 구간 끝에 왔다: 최종 목표가 남아 있으면 다음 구간을 계산한다. 최종 목표에 도착했으면 true
function Monster.nextLeg(self: Monster): boolean
	local g = self.legGoal
	if g and (feet(self.root.Position) - g).Magnitude > 4 and self:pathTo(g) then
		return false
	end
	self.legGoal = nil
	return true
end

-- 경로를 따라 한 걸음. 끝에 도착하면 true
function Monster.follow(self: Monster): boolean
	local wps = self.waypoints
	if #wps == 0 or self.wp > #wps then
		return self:nextLeg()
	end
	local wp = wps[self.wp]
	local pos = self.root.Position
	local flat = Vector3.new(wp.Position.X - pos.X, 0, wp.Position.Z - pos.Z)
	if flat.Magnitude < 2.2 and math.abs(feet(pos).Y - wp.Position.Y) < 4 then
		self.wp += 1
		if self.wp > #wps then
			return self:nextLeg()
		end
		wp = wps[self.wp]
	end
	self.hum:MoveTo(wp.Position)
	-- 앞에 닫힌 문이 있으면 연다
	Doors.openNear(pos + self.root.CFrame.LookVector * 2, 6, self.root.Position)
	return false
end

function Monster.randomNode(self: Monster, awayFrom: Vector3?): Vector3
	local function pick(): Vector3
		for _ = 1, 12 do
			local n = self.nodes[math.random(1, #self.nodes)]
			if not Monster.isSafe(n) then
				return n
			end
		end
		return self.nodes[math.random(1, #self.nodes)]
	end
	local best = pick()
	if awayFrom then
		for _ = 1, 6 do
			local n = pick()
			if (n - awayFrom).Magnitude > (best - awayFrom).Magnitude and (n - awayFrom).Magnitude < 90 then
				best = n
			end
		end
	end
	return best
end

-- 안전 구역 밖에서 pos 에 가장 가까운 배회 지점
function Monster.nearestOutside(self: Monster, pos: Vector3): Vector3?
	local best, bd = nil, math.huge
	for _, n in self.nodes do
		if not Monster.isSafe(n) then
			local d = (n - pos).Magnitude
			if d < bd then
				best, bd = n, d
			end
		end
	end
	return best
end

-- 머리에서 대상까지 벽에 막히지 않는가
function Monster.lineOfSight(self: Monster, p: Vector3): boolean
	local from = self.root.Position + Vector3.new(0, 2.5, 0)
	local hit = workspace:Raycast(from, p - from, self.rayParams)
	return hit == nil
end

local function alivePlayers(): { { player: Player, root: BasePart, char: Model } }
	local out = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Status") == "Alive" and not p:GetAttribute("Hidden") then
			local char = p.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if char and root and not Monster.isSafe(root.Position) then
				table.insert(out, { player = p, root = root, char = char })
			end
		end
	end
	return out
end

function Monster.startChase(self: Monster, p: Player, pos: Vector3)
	if self.state ~= "Chase" then
		self:note("chase " .. p.Name)
	end
	self.target = p
	self.lastSeen = os.clock()
	self.lastKnown = pos
	self.pullSpot = nil
	self:setState("Chase")
end

-- 누가 숨었다: 쫓던 대상이고 방금까지 보고 있었다면 숨는 곳을 기억한다
function Monster.onHide(self: Monster, p: Player, front: Vector3)
	if self.form ~= "Beast" then
		return
	end
	if self.state == "Chase" and self.target == p and os.clock() - self.lastSeen <= Config.Hide.SeenWindow then
		self:note("saw " .. p.Name .. " hide")
		self.pullSpot = front
		self.lastKnown = front
		self.waypoints = {}
	end
end

function Monster.investigate(self: Monster, pos: Vector3)
	if Monster.isSafe(pos) then
		-- 안전 구역 안의 소리: 그 앞(밖)까지만 와 본다
		pos = self:nearestOutside(pos) or pos
	end
	self.searchCenter = pos
	if self.state == "Wander" then
		self:setState("Alert")
		self.alertUntil = os.clock() + MC.AlertTime
		self.goal = pos
		return
	end
	if self.state == "Alert" then
		self.goal = pos
		return
	end
	-- 수색 중이거나 조사 중이면 새 위치로
	self:setState("Investigate")
	if not self.goal or (self.goal - pos).Magnitude > 4 or os.clock() - self.lastRepath > 1.5 then
		self.goal = pos
		self.waypoints = {}
	end
end

-- 소리를 들었다(SoundBus)
function Monster.hear(self: Monster, pos: Vector3, radius: number, source: Player?, kind: string)
	if not self.alive or os.clock() < self.startAt then
		return
	end
	if kind == "Door" and source == nil then
		return -- 괴물이 연 문 소리(괴물끼리 서로 문 소리에 끌려다니지 않게)
	end
	if self.form ~= "Beast" then
		-- 사람 모습일 때는 소리에 반응하지 않는다. 다만 가까이서 쏜 음파에 모습이 드러나면 들킨 것
		if self.form == "Disguise" and kind == "Sonar" and source then
			self:sonarSeen(pos, source)
		end
		return
	end
	if not SoundBus.canHear(pos, self.root.Position, radius) then
		return
	end
	if self.state == "Chase" then
		if source and source == self.target then
			self.lastKnown = pos
			self.lastSeen = math.max(self.lastSeen, os.clock() - MC.LoseTime * 0.5)
		end
		return
	end
	self:note("heard " .. kind .. " " .. (if source then source.Name else "-"))
	self:investigate(pos)
end

-- 감각: 가까운 플레이어를 발견
function Monster.sense(self: Monster)
	local my = self.root.Position
	local best: { player: Player, root: BasePart, char: Model }? = nil
	local bestD = math.huge
	for _, e in alivePlayers() do
		local p = e.root.Position
		local d = (p - my).Magnitude
		local crouch = e.char:GetAttribute("MoveMode") == "Crouch"
		local range = if crouch then MC.SightRangeCrouch else MC.SightRange
		if d < bestD and math.abs(p.Y - my.Y) < 9 then
			if d <= MC.SenseRange or (d <= range and self:lineOfSight(p + Vector3.new(0, 1, 0))) then
				best = e
				bestD = d
			end
		end
	end
	if best then
		if self.state ~= "Chase" or self.target == best.player then
			self:startChase(best.player, best.root.Position)
		elseif bestD < 6 then
			self:startChase(best.player, best.root.Position)
		end
	end
end

function Monster.checkStuck(self: Monster, moving: boolean)
	local now = os.clock()
	if now - self.progressT < 1.5 then
		return
	end
	local moved = (self.root.Position - self.progressPos).Magnitude
	self.progressPos = self.root.Position
	self.progressT = now
	if not moving or self.hum.WalkSpeed <= 0 then
		self.stuck = 0
		return
	end
	if moved < 1.0 then
		self.stuck += 1
		self:note("stuck " .. self.stuck)
		self.waypoints = {}
		if self.stuck >= 3 then
			-- 목표를 포기하고 다른 곳으로
			self.goal = nil
			if self.state ~= "Chase" then
				self:setState("Wander")
			end
		end
		if self.stuck >= 6 then
			-- 마지막 수단: 가장 가까운 배회 지점으로 옮긴다
			local best, bd = self.nodes[1], math.huge
			for _, n in self.nodes do
				local d = (n - self.root.Position).Magnitude
				if d < bd and d > 2 then
					best, bd = n, d
				end
			end
			self.model:PivotTo(CFrame.new(best + Vector3.new(0, 2.2, 0)))
			self.stuck = 0
		end
	else
		self.stuck = 0
	end
end

function Monster.tick(self: Monster)
	local now = os.clock()
	if now < self.startAt then
		return
	end
	if self.form == "Disguise" then
		self:disguiseTick(now)
		return
	elseif self.form ~= "Beast" then
		return
	end
	self:sense()
	local st = self.state
	local moving = true
	if st == "Chase" then
		local t = self.target
		local char = t and t.Character
		local troot = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not t or t:GetAttribute("Status") ~= "Alive" or not troot then
			self.pullSpot = nil
			self.target = nil
			self.searchCenter = self.lastKnown or self.root.Position
			self.searchUntil = now + MC.SearchTime
			self:setState("Search")
			self.waypoints = {}
			return
		end
		local tp = troot.Position
		if Monster.isSafe(tp) then
			-- 안전 구역으로 도망쳤다: 쫓기를 그만두고 그 근처(밖)를 뒤진다
			self:note("target reached safe zone")
			self.pullSpot = nil
			self.target = nil
			self.searchCenter = self:nearestOutside(self.root.Position) or self.root.Position
			self.searchUntil = now + MC.SearchTime
			self:setState("Search")
			self.waypoints = {}
			return
		end
		local d = (tp - self.root.Position).Magnitude
		if self.kind == "doppel" then
			-- 덮칠 만큼 가까우면 머리~배의 틈이 세로 입으로 벌어진다(조금 멀어지면 다시 닫힌다)
			if d < self.cfg.MawDistance then
				self:setMaw(true)
			elseif d > self.cfg.MawDistance + 3 then
				self:setMaw(false)
			end
		end
		local hidden = t:GetAttribute("Hidden") == true
		if hidden and self.pullSpot then
			-- 숨는 걸 봤다: 그 앞으로 가서 끌어낸다
			local front = self.pullSpot
			local flat = Vector3.new(front.X - self.root.Position.X, 0, front.Z - self.root.Position.Z).Magnitude
			if flat < 4.5 then
				self:note("pulled out " .. t.Name)
				self.pullSpot = nil
				Hiding.exit(t)
				self.onCatch(t, self)
				self.target = nil
				self.searchCenter = front
				self.searchUntil = now + MC.SearchTime
				self:setState("Search")
				self.waypoints = {}
				return
			end
			if #self.waypoints == 0 or self:follow() then
				if not self:pathTo(front) then
					self.hum:MoveTo(front)
				end
			end
			self:checkStuck(true)
			return
		end
		if not hidden then
			self.pullSpot = nil
		end
		local los = not hidden and d < 40 and self:lineOfSight(tp)
		if los then
			self.lastSeen = now
			self.lastKnown = tp
		end
		if now - self.lastSeen > MC.LoseTime then
			-- 놓쳤다: 마지막 위치로 가서 수색
			self:note("lost target")
			self.target = nil
			self:setState("Investigate")
			self.goal = self.lastKnown
			self.searchCenter = self.lastKnown
			self.waypoints = {}
			return
		end
		if los and d < 14 and math.abs(tp.Y - self.root.Position.Y) < 3 then
			self.waypoints = {}
			self.hum:MoveTo(tp)
			Doors.openNear(self.root.Position + self.root.CFrame.LookVector * 2, 6, self.root.Position)
		else
			if #self.waypoints == 0 or now - self.lastRepath > MC.RepathChase then
				local goal = self.lastKnown or tp
				if not self:pathTo(goal) then
					self.lastRepath = now
				end
			end
			self:follow()
		end
	elseif st == "Alert" then
		moving = false
		if self.goal then
			local look = Vector3.new(self.goal.X, self.root.Position.Y, self.goal.Z)
			if (look - self.root.Position).Magnitude > 0.5 then
				self.hum:MoveTo(self.root.Position + (look - self.root.Position).Unit * 0.5)
			end
		end
		if now >= self.alertUntil then
			self:setState("Investigate")
			self.waypoints = {}
		end
	elseif st == "Investigate" then
		local goal = self.goal or self.searchCenter
		if not goal then
			self:setState("Wander")
			return
		end
		if #self.waypoints == 0 then
			if not self:pathTo(goal) then
				-- 그 자리로 갈 수 없다: 근처 배회 지점을 대신 조사
				local best, bd = nil, math.huge
				for _, n in self.nodes do
					local dd = (n - goal).Magnitude
					if dd < bd then
						best, bd = n, dd
					end
				end
				if best and (best - goal).Magnitude > 0.5 and bd < 20 then
					self.goal = best
					if not self:pathTo(best) then
						self:setState("Wander")
						return
					end
				else
					self:setState("Wander")
					return
				end
			end
		end
		local arrived = self:follow()
		if arrived or (self.root.Position - goal).Magnitude < 4 then
			self.searchCenter = goal
			self.searchUntil = now + MC.SearchTime
			self:setState("Search")
			self.waypoints = {}
		end
	elseif st == "Search" then
		if now > self.searchUntil then
			self:setState("Wander")
			self.waypoints = {}
			return
		end
		if #self.waypoints == 0 or self:follow() then
			local c = self.searchCenter or self.root.Position
			local ok = false
			for _ = 1, 4 do
				local ang = math.random() * math.pi * 2
				local r = MC.SearchRadius * (0.4 + math.random() * 0.6)
				local p = c + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
				if not Monster.isSafe(p) and self:pathTo(p) then
					ok = true
					break
				end
			end
			if not ok then
				self:setState("Wander")
			end
		end
	else -- Wander
		if #self.waypoints == 0 or self:follow() then
			local n = self:randomNode(self.root.Position)
			-- 넓은 맵에서 영영 마주치지 않는 일이 없게: 가끔 플레이어(숨지 않은) 근처로 배회한다
			if now - self.lastHunt >= MC.HuntEvery then
				self.lastHunt = now
				local ps = alivePlayers()
				if #ps > 0 then
					local pick = ps[math.random(1, #ps)]
					local tp = pick.root.Position
					local near = {}
					for _, c in self.nodes do
						local dd = (c - tp).Magnitude
						if dd > 12 and dd <= MC.HuntRadius and not Monster.isSafe(c) then
							table.insert(near, c)
						end
					end
					local best = if #near > 0 then near[math.random(1, #near)] else nil
					if best then
						self:note("hunt near " .. pick.player.Name)
						n = best
					end
				end
			end
			if not self:pathTo(n) then
				self.waypoints = {}
			end
		end
	end
	if Monster.isSafe(self.root.Position) then
		local out = self:nearestOutside(self.root.Position)
		if out then
			self.waypoints = {}
			self.hum:MoveTo(out)
		end
	end
	self:checkStuck(moving)
end

-- ── 도플갱어: 사람 흉내 → 들킴 → 5~10초 뒤 터지며 괴물로 ──
local RoundEvent: RemoteEvent? = nil
local function roundEvent(): RemoteEvent?
	if not RoundEvent then
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		RoundEvent = remotes and remotes:FindFirstChild("RoundEvent") :: RemoteEvent?
	end
	return RoundEvent
end

-- 들켰다: 변신 시각을 정한다(5~10초 뒤)
function Monster.discover(self: Monster, p: Player)
	if self.discoveredBy or self.form ~= "Disguise" then
		return
	end
	self.discoveredBy = p
	self.transformAt = os.clock() + between(self.cfg.TransformDelay)
	self.waypoints = {}
	self.model:SetAttribute("Discovered", true)
	self:note(string.format("discovered by %s, transform in %.1f", p.Name, self.transformAt - os.clock()))
end

-- 가까이서 쏜 음파(벽 1장 이하)에 모습이 드러났다
function Monster.sonarSeen(self: Monster, pos: Vector3, source: Player)
	local my = self.root.Position
	if (pos - my).Magnitude <= self.cfg.SonarRange and SoundBus.wallsBetween(pos, my) <= 1 then
		self:discover(source)
	end
end

-- 사람 모습일 때: 플레이어처럼 걷다 멈춰 두리번, 가끔 가짜 음파 소리. 누가 가까이서 보면 들킨다
function Monster.disguiseTick(self: Monster, now: number)
	local cfg = self.cfg
	local my = self.root.Position
	if not self.discoveredBy then
		for _, e in alivePlayers() do
			local p = e.root.Position
			if (p - my).Magnitude <= cfg.SeeRange and math.abs(p.Y - my.Y) < 6 and self:lineOfSight(p) then
				self:discover(e.player)
				break
			end
		end
	end
	local who = self.discoveredBy
	if who then
		if now >= self.transformAt then
			self:transform()
			return
		end
		-- 변신 전: 발견한 플레이어를 바라보며 아주 천천히 다가온다(멀면 그 자리에 서서 바라본다)
		local char = who.Character
		local troot = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		self.hum.WalkSpeed = cfg.StalkSpeed
		if troot and who:GetAttribute("Status") == "Alive" then
			local tp = troot.Position
			local flat = Vector3.new(tp.X - my.X, 0, tp.Z - my.Z)
			if flat.Magnitude > 4 and flat.Magnitude < 30 and self:lineOfSight(tp) then
				self.hum:MoveTo(tp)
			else
				self.hum:MoveTo(my)
				if flat.Magnitude > 0.5 then
					self.root.CFrame = CFrame.lookAt(my, my + flat.Unit)
				end
			end
		else
			self.hum:MoveTo(my)
		end
		return
	end
	self.hum.WalkSpeed = cfg.WalkSpeed
	-- 멈춰 서서 두리번
	if now < self.pauseUntil then
		self.hum:MoveTo(my)
		return
	end
	if now >= self.nextPause then
		self.pauseUntil = now + between(cfg.PauseFor)
		self.nextPause = self.pauseUntil + between(cfg.PauseEvery)
		self.waypoints = {}
		self.hum:MoveTo(my)
		return
	end
	-- 가짜 음파 소리(클라이언트가 이 자리에서 음파 소리만 낸다)
	if now >= self.nextPing then
		self.nextPing = now + between(cfg.FakePingEvery)
		self.model:SetAttribute("FakePing", now)
	end
	if #self.waypoints == 0 or self:follow() then
		if not self:pathTo(self:randomNode(my)) then
			self.waypoints = {}
		end
	end
	self:checkStuck(true)
end

-- 사람 모습이 터지고(클라이언트가 조각을 흩날린다) 그 자리에서 괴물이 나온다
function Monster.transform(self: Monster)
	if self.form ~= "Disguise" then
		return
	end
	self.form = "Bursting"
	self.model:SetAttribute("Form", "Bursting")
	self.hum.WalkSpeed = 0
	self.hum:MoveTo(self.root.Position)
	local boxes = {}
	local disguise = self.model:FindFirstChild("Disguise")
	if disguise then
		for _, d in disguise:GetChildren() do
			if d:IsA("BasePart") and d.Name ~= "Body" and not d.Name:find("^Pivot") then
				table.insert(boxes, { cf = d.CFrame, size = d.Size })
			end
		end
	end
	local ev = roundEvent()
	if ev then
		ev:FireAllClients("DoppelBurst", { at = self.root.Position, boxes = boxes })
	end
	-- 사람 몸(상자·관절)을 없애고 괴물 몸을 붙인다
	for _, j in self.root:GetChildren() do
		if j:IsA("Motor6D") and j.Name:find("^DJoint") then
			j:Destroy()
		end
	end
	if disguise then
		disguise:Destroy()
	end
	buildBeast(self.model, self.root, self.root.CFrame)
	self.joints = {}
	for _, name in { "Leg-1", "Leg1", "Arm-1", "Arm1" } do
		local motor = self.root:FindFirstChild("Joint" .. name) :: Motor6D?
		if motor then
			local isLeg = name:sub(1, 3) == "Leg"
			local left = name:find("-1") ~= nil
			table.insert(self.joints, { motor = motor, base = motor.C0, offset = if (isLeg == left) then 0 else math.pi, amp = if isLeg then 0.45 else 0.35 })
		end
	end
	self.mawOpen = false
	self.model:SetAttribute("BodyVersion", ((self.model:GetAttribute("BodyVersion") :: number?) or 1) + 1)
	self.model:SetAttribute("Form", "Beast")
	self.form = "Beast"
	self:note("transformed")
	-- 터지는 동안 잠깐 멈췄다가 발견한 플레이어를 쫓는다
	local now = os.clock()
	self.startAt = now + self.cfg.BurstPause
	local who = self.discoveredBy
	local char = who and who.Character
	local troot = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if who and troot and who:GetAttribute("Status") == "Alive" then
		self:startChase(who, troot.Position)
		self.lastSeen = now + self.cfg.BurstPause
	else
		self:setState("Wander")
	end
	self.waypoints = {}
end

-- 세로 입 열기/닫기: 음파 대상 태그를 틈(Slit) ↔ 입(Maw) 선으로 바꿔 낀다(클라이언트는 BodyVersion 이 바뀌면 다시 모은다)
function Monster.setMaw(self: Monster, open: boolean)
	if self.mawOpen == open or self.form ~= "Beast" then
		return
	end
	self.mawOpen = open
	local beast = self.model:FindFirstChild("Beast")
	if not beast then
		return
	end
	local tag = Config.Tags.Renderable
	for _, p in beast:GetChildren() do
		if p:IsA("BasePart") then
			local on = if p:GetAttribute("Maw") then open elseif p:GetAttribute("Slit") then not open else nil
			if on == true then
				CollectionService:AddTag(p, tag)
			elseif on == false then
				CollectionService:RemoveTag(p, tag)
			end
		end
	end
	self.model:SetAttribute("MawOpen", open)
	self.model:SetAttribute("BodyVersion", ((self.model:GetAttribute("BodyVersion") :: number?) or 1) + 1)
end

-- 잡기 판정(매 프레임)
function Monster.checkCatch(self: Monster)
	if not self.alive or os.clock() < self.startAt or self.form ~= "Beast" then
		return
	end
	local my = self.root.Position
	for _, e in alivePlayers() do
		local p = e.root.Position
		local flat = Vector3.new(p.X - my.X, 0, p.Z - my.Z).Magnitude
		if flat <= self.cfg.CatchDistance and math.abs(p.Y - (my.Y - 1.5)) < 5 then
			self:note("caught " .. e.player.Name)
			self.onCatch(e.player, self)
			-- 잡은 뒤에는 그 자리를 잠깐 뒤진다
			self.target = nil
			self.searchCenter = p
			self.searchUntil = os.clock() + MC.SearchTime
			self:setState("Search")
			self.waypoints = {}
		end
	end
end

function Monster.run(self: Monster)
	task.spawn(function()
		while self.alive and self.model.Parent do
			local ok, err = pcall(self.tick, self)
			Monster.stats.ticks += 1
			if not ok then
				warn("[Monster] " .. tostring(err))
				self.waypoints = {}
			end
			task.wait(0.1)
		end
	end)
end

function Monster.destroy(self: Monster)
	self.alive = false
	self.model:Destroy()
end

return Monster
