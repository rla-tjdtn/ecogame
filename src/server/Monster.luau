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
local Faces = require(ReplicatedStorage.Shared.MonsterFaces)
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
-- 살아 있는 괴물 전부(서로 몰리지 않게 거리를 본다)
Monster.registry = {} :: { any }
local SPREAD = 35 -- 배회 중 다른 괴물이 이 거리 안이면 반대쪽으로 간다
local SHARE_SOUND = 25 -- 같은 소리를 이미 다른 괴물이 이 거리 안으로 조사하러 가면 따라가지 않는다

export type State = "Wander" | "Alert" | "Investigate" | "Search" | "Chase" | "Disguise" | "Dormant" | "Look"

-- ── 메인 괴물 몸: 모든 스테이지 같은 디자인(삼각 머리 구체관절, buildModel). 스테이지 번호(Voice)는 소리·추격 리듬만 바꾼다 ──

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

-- ── 전신 뼈대(Rig 2): 골반 → 허리(가슴) → 목 → 머리, 가슴 → 어깨 → 위팔 → (가운데 마디) → 아래팔 → 손,
-- 골반 → 허벅지 → 정강이 → 발. 뼈마다 투명한 작은 파트 + Motor6D(이름 "B_<뼈>").
-- 그림 선(parts)은 가장 가까운 뼈에 붙는다(팔 묶음 "Arm±1" 은 그쪽 팔 뼈 중에서, 다리 묶음은 그쪽 다리 뼈 중에서).
-- 움직임은 클라이언트(MonsterAnim)가 매 프레임 Motor6D.Transform 으로 만든다(발 고정 IK, 무게중심, 관성).
-- 뼈 파트 속성 Tip = 그 뼈 끝(발끝·손끝·머리 끝)의 위치(뼈 기준). 모델 속성 FloorY = 루트 기준 바닥 높이, Rig = 2.
export type Limb = { Vector3 }
export type Skeleton = {
	pelvis: Vector3,
	waist: Vector3,
	neck: Vector3,
	head: Vector3,
	headEnd: Vector3,
	legs: { [number]: { hip: Vector3, knee: Vector3, ankle: Vector3, toe: Vector3 } },
	arms: { [number]: { shoulder: Vector3, elbow: Vector3, mid: Vector3?, wrist: Vector3, tip: Vector3 } },
	floorY: number,
	mass: number, -- 무게(착지 충격·둔중함), 1 = 메인 괴물
}
local function skeleton(model: Model, root: BasePart, cf: CFrame, parts: { BasePart }, groupParts: { [string]: { BasePart } }, sk: Skeleton, holder: Instance?)
	type Bone = { name: string, parent: string?, joint: Vector3, tip: Vector3, part: BasePart? }
	local bones: { [string]: Bone } = {}
	local order: { string } = {}
	local function bone(name: string, parent: string?, joint: Vector3, tip: Vector3)
		bones[name] = { name = name, parent = parent, joint = joint, tip = tip }
		table.insert(order, name)
	end
	bone("Pelvis", nil, sk.pelvis, sk.waist)
	bone("Chest", "Pelvis", sk.waist, sk.neck)
	bone("Neck", "Chest", sk.neck, sk.head)
	bone("Head", "Neck", sk.head, sk.headEnd)
	for _, s in { -1, 1 } do
		local L = sk.legs[s]
		bone("Thigh" .. s, "Pelvis", L.hip, L.knee)
		bone("Shin" .. s, "Thigh" .. s, L.knee, L.ankle)
		bone("Foot" .. s, "Shin" .. s, L.ankle, L.toe)
		local A = sk.arms[s]
		bone("Upper" .. s, "Chest", A.shoulder, A.elbow)
		local last = "Upper" .. s
		local from = A.elbow
		if A.mid then
			bone("Mid" .. s, last, A.elbow, A.mid)
			last, from = "Mid" .. s, A.mid
		end
		bone("Fore" .. s, last, from, A.wrist)
		bone("Hand" .. s, "Fore" .. s, A.wrist, A.tip)
	end
	-- 뼈 파트 + 관절
	for _, name in order do
		local b = bones[name]
		local pv = Instance.new("Part")
		pv.Name = "Bone_" .. name
		pv.Size = Vector3.new(0.2, 0.2, 0.2)
		pv.Transparency = 1
		pv.CanCollide = false
		pv.CanQuery = false
		pv.CanTouch = false
		pv.Massless = true
		pv.CastShadow = false
		pv:SetAttribute("SonarShape", "None")
		pv:SetAttribute("Tip", b.tip - b.joint)
		pv.CFrame = cf * CFrame.new(b.joint)
		pv.Parent = holder or model
		b.part = pv
		local parentPart: BasePart = if b.parent then (bones[b.parent].part :: BasePart) else root
		local parentJoint = if b.parent then bones[b.parent].joint else Vector3.zero
		local motor = Instance.new("Motor6D")
		motor.Name = "B_" .. name
		motor.Part0 = parentPart
		motor.Part1 = pv
		motor.C0 = CFrame.new(b.joint - parentJoint)
		motor.C1 = CFrame.identity
		motor.Parent = pv
	end
	local function segDist(p: Vector3, a: Vector3, b: Vector3): number
		local ab = b - a
		local t = if ab.Magnitude < 1e-4 then 0 else math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
		return (a + ab * t - p).Magnitude
	end
	local candidates: { [string]: { string } } = {
		["Leg-1"] = { "Thigh-1", "Shin-1", "Foot-1" },
		["Leg1"] = { "Thigh1", "Shin1", "Foot1" },
		["Arm-1"] = { "Upper-1", "Mid-1", "Fore-1", "Hand-1" },
		["Arm1"] = { "Upper1", "Mid1", "Fore1", "Hand1" },
	}
	local groupOf: { [BasePart]: string } = {}
	for g, list in groupParts do
		for _, p in list do
			groupOf[p] = g
		end
	end
	local core = { "Pelvis", "Chest", "Neck", "Head" }
	for _, p in parts do
		if p.Name == "Part" then
			p.Name = "Body"
		end
		p.Transparency = 1
		p.CastShadow = false
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		local local_ = cf:PointToObjectSpace(p.Position)
		local best, bestD = "Chest", math.huge
		for _, name in candidates[groupOf[p] or ""] or core do
			local b = bones[name]
			if b then
				local d = segDist(local_, b.joint, b.tip)
				if d < bestD then
					best, bestD = name, d
				end
			end
		end
		local w = Instance.new("WeldConstraint")
		w.Part0 = bones[best].part
		w.Part1 = p
		w.Parent = p
	end
	model:SetAttribute("Rig", 2)
	model:SetAttribute("FloorY", sk.floorY)
	model:SetAttribute("Mass", sk.mass)
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
	-- 전신 뼈대(작고 가벼운 몸: 빠르고 날카롭게 반응)
	skeleton(model, root, cf, parts, groups, {
		pelvis = P(130, 318, -0.25),
		waist = P(130, 280, -0.45),
		neck = P(130, 216, -0.75),
		head = P(130, 204, -0.9),
		headEnd = P(130, 150, -1.05),
		legs = {
			[-1] = { hip = P(116, 318, -0.25), knee = P(104, 362, legZ(362)), ankle = P(96, 392, legZ(392)), toe = P(96, 394, -0.6) },
			[1] = { hip = P(144, 318, -0.25), knee = P(160, 362, legZ(362)), ankle = P(174, 392, legZ(392)), toe = P(174, 394, -0.6) },
		},
		arms = {
			[-1] = { shoulder = P(84, 232, armZ(232)), elbow = P(74, 298, armZ(298)), wrist = P(70, 356, armZ(356)), tip = P(76, 394, armZ(394)) },
			[1] = { shoulder = P(176, 232, armZ(232)), elbow = P(186, 298, armZ(298)), wrist = P(190, 356, armZ(356)), tip = P(184, 394, armZ(394)) },
		},
		floorY = -3,
		mass = 0.55,
	}, folder)
end

-- ── 꽃괴물 ──
-- 확정 시안(꽃괴물): 줄기처럼 휜 긴 목, 잎맥 같은 갈비뼈의 마른 몸, 무릎 아래까지 늘어진 팔과 뿌리처럼 갈라진 손가락,
-- 뒤로 꺾인 다리와 뿌리 같은 발. 머리는 평소 고개 숙인 튤립 봉오리(Bud), 깨어나면 뾰족한 꽃잎 6장이 젖혀지고
-- 가운데 작은 눈 7개가 모인 머리(Bloom). 키 약 8.5스터드. 루트 가운데 기준 바닥 y = -4 (HipHeight 3).
-- 좌표는 시안 그림(픽셀, 몸 가운데 x=180, 바닥 y=396, 36.2px = 1스터드)에서 옮긴다. 앞 = -Z
-- 봉오리·펼친 머리는 둘 다 만들어 두고 음파 대상 태그를 바꿔 낀다(도플갱어 입과 같은 방식)
local FLOWER_HIP = 3.0
local function buildFlower(cf: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Flower"
	model:SetAttribute(Config.Tags.Dynamic, true)
	model:SetAttribute("State", "Dormant")
	model:SetAttribute("Form", "Bud")
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
	local folder = Instance.new("Folder")
	folder.Name = "Body"
	folder.Parent = model
	local S = 36.2
	local parts: { BasePart } = {}
	local groups: { [string]: { BasePart } } = {}
	local group: string? = nil
	local mark: string? = nil -- "Bud" / "Bloom"
	local function P(px: number, py: number, z: number): Vector3
		return Vector3.new((px - 180) / S, (396 - py) / S - 4, z)
	end
	local function seg(a: Vector3, b: Vector3, r: number, name: string?)
		local shape = if (b - a).Magnitude > r * 4 then "Line" else "Disc"
		local p = Kit.cylinder(folder, cf:PointToWorldSpace(a), cf:PointToWorldSpace(b), r, { shape = shape, name = name, tag = mark ~= "Bloom" })
		if mark then
			p:SetAttribute(mark, true)
		end
		table.insert(parts, p)
		if group then
			groups[group] = groups[group] or {}
			table.insert(groups[group], p)
		end
	end
	local function flat(z: number): (number) -> number
		return function(_py: number): number
			return z
		end
	end
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
	local function line(x0: number, y0: number, x1: number, y1: number, zf: (number) -> number, r: number?)
		seg(P(x0, y0, zf(y0)), P(x1, y1, zf(y1)), r or 0.035)
	end
	local body = flat(-0.2)
	-- 어깨로 이어지는 목 밑동, 솟은 어깨
	bez(170, 196, 166, 210, 162, 222, 160, 236, 2, body)
	bez(190, 196, 194, 210, 198, 222, 200, 236, 2, body)
	bez(160, 236, 150, 238, 142, 242, 138, 250, 2, body)
	bez(200, 236, 210, 238, 218, 242, 222, 250, 2, body)
	-- 몸통(좁아지는 허리) + 가운데 줄기선 + 잎맥 같은 갈비뼈 3쌍
	bez(142, 250, 144, 280, 152, 305, 164, 318, 3, body)
	line(164, 318, 196, 318, body)
	bez(196, 318, 208, 305, 216, 280, 218, 250, 3, body)
	line(180, 246, 180, 312, flat(-0.25), 0.025)
	for _, y in { 258, 274, 290 } do
		local w = if y == 290 then 18 else 24
		bez(180, y, 174, y + 4, 180 - w * 0.6, y + 4, 180 - w, y, 2, flat(-0.25), 0.022)
		bez(180, y, 186, y + 4, 180 + w * 0.6, y + 4, 180 + w, y, 2, flat(-0.25), 0.022)
	end
	-- 팔: 무릎 아래까지, 뿌리처럼 갈라진 손가락
	local function armZ(py: number): number
		return -0.25 - math.clamp((py - 250) / 140, 0, 1) * 0.45
	end
	for _, s in { -1, 1 } do
		local function X(px: number): number
			return 180 + (px - 180) * -s -- (s = -1: 왼쪽 그대로, 1: 좌우 뒤집기)
		end
		group = "Arm" .. s
		bez(X(138), 250, X(124), 280, X(118), 305, X(120), 330, 2, armZ)
		bez(X(120), 330, X(118), 350, X(116), 362, X(114), 372, 2, armZ)
		bez(X(114), 372, X(110), 380, X(104), 388, X(100), 394, 2, armZ, 0.026)
		line(X(114), 372, X(114), 396, armZ, 0.026)
		bez(X(114), 372, X(118), 380, X(124), 386, X(130), 390, 2, armZ, 0.026)
		line(X(108), 384, X(94), 384, armZ, 0.022)
	end
	-- 다리: 뒤로 꺾이고 뿌리 같은 발
	local function legZ(py: number): number
		return if py < 360 then -0.2 - (py - 318) / 42 * 0.35 else -0.55 + (py - 360) / 36 * 0.6
	end
	for _, s in { -1, 1 } do
		local function X(px: number): number
			return 180 + (px - 180) * -s
		end
		group = "Leg" .. s
		bez(X(168), 318, X(162), 338, X(166), 352, X(174), 360, 2, legZ)
		bez(X(174), 360, X(168), 372, X(160), 384, X(152), 392, 2, legZ)
		line(X(152), 392, X(138), 395, legZ, 0.026)
		line(X(152), 392, X(148), 397, legZ, 0.026)
		line(X(152), 392, X(160), 396, legZ, 0.026)
	end
	group = nil
	-- 머리(평소): 줄기처럼 휜 목 끝에 고개 숙인 튤립 봉오리
	mark = "Bud"
	local function budZ(py: number): number
		return -0.35 - math.clamp((198 - py) / 110, 0, 1) * 0.55
	end
	bez(180, 198, 186, 176, 196, 160, 210, 150, 3, budZ)
	bez(210, 150, 200, 132, 204, 106, 222, 96, 3, budZ)
	bez(222, 96, 238, 104, 244, 128, 236, 148, 3, budZ)
	bez(236, 148, 228, 158, 218, 158, 210, 150, 2, budZ)
	bez(222, 96, 220, 116, 220, 136, 224, 154, 2, budZ, 0.022)
	bez(212, 110, 216, 124, 218, 140, 220, 156, 2, budZ, 0.022)
	bez(232, 108, 230, 124, 230, 140, 228, 154, 2, budZ, 0.022)
	line(222, 96, 220, 88, budZ, 0.022)
	line(222, 96, 226, 89, budZ, 0.022)
	-- 머리(깨어나면): 곧게 선 목 끝에 뾰족한 꽃잎 6장이 젖혀지고 가운데 작은 눈 7개
	mark = "Bloom"
	local headZ = flat(-0.95)
	bez(180, 198, 180, 180, 182, 166, 186, 156, 2, function(py)
		return -0.35 - math.clamp((198 - py) / 42, 0, 1) * 0.55
	end)
	local hx, hy = 186, 128
	for k = 0, 5 do
		local a = math.rad(k * 60)
		local function R(x: number, y: number): (number, number)
			return hx + x * math.cos(a) - y * math.sin(a), hy + x * math.sin(a) + y * math.cos(a)
		end
		local x0, y0 = R(-4, -6)
		local x1, y1 = R(-10, -24)
		local x2, y2 = R(-8, -46)
		local x3, y3 = R(0, -62)
		bez(x0, y0, x1, y1, x2, y2, x3, y3, 2, headZ, 0.03)
		local u1, v1 = R(8, -46)
		local u2, v2 = R(10, -24)
		local u3, v3 = R(4, -6)
		bez(x3, y3, u1, v1, u2, v2, u3, v3, 2, headZ, 0.03)
		local m0, n0 = R(0, -14)
		local m1, n1 = R(0, -52)
		line(m0, n0, m1, n1, headZ, 0.02)
		for _, t in { { 6, -30, 11, -32 }, { 6, -40, 11, -43 } } do
			local a0, b0 = R(t[1], t[2])
			local a1, b1 = R(t[3], t[4])
			line(a0, b0, a1, b1, headZ, 0.02)
		end
	end
	for _, e in { { 0, 0, 0.09 }, { -8, -6, 0.06 }, { 8, -6, 0.06 }, { -10, 4, 0.055 }, { 10, 4, 0.055 }, { -3, 10, 0.05 }, { 3, 10, 0.05 } } do
		seg(P(hx + e[1], hy + e[2], -1.0), P(hx + e[1], hy + e[2], -1.06), e[3], "FEye")
	end
	mark = nil
	-- 전신 뼈대(키 크고 가는 몸: 긴 목·긴 팔의 휘청임)
	skeleton(model, root, cf, parts, groups, {
		pelvis = P(180, 318, -0.2),
		waist = P(180, 280, -0.2),
		neck = P(180, 236, -0.2),
		head = P(180, 198, -0.35),
		headEnd = P(196, 132, -0.9),
		legs = {
			[-1] = { hip = P(168, 318, -0.2), knee = P(174, 360, legZ(360)), ankle = P(152, 392, legZ(392)), toe = P(138, 395, -0.6) },
			[1] = { hip = P(192, 318, -0.2), knee = P(186, 360, legZ(360)), ankle = P(208, 392, legZ(392)), toe = P(222, 395, -0.6) },
		},
		arms = {
			[-1] = { shoulder = P(138, 250, armZ(250)), elbow = P(120, 330, armZ(330)), wrist = P(114, 372, armZ(372)), tip = P(114, 396, armZ(396)) },
			[1] = { shoulder = P(222, 250, armZ(250)), elbow = P(240, 330, armZ(330)), wrist = P(246, 372, armZ(372)), tip = P(246, 396, armZ(396)) },
		},
		floorY = -4,
		mass = 0.7,
	}, folder)
	makeHumanoid(model, FLOWER_HIP, 0)
	CollectionService:AddTag(model, Config.Tags.Monster)
	CollectionService:AddTag(model, Config.Tags.Flower)
	return model
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
local function buildModel(cf: CFrame, _stage: number): Model
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
		local p = Kit.cylinder(model, at(a), at(b), r, { shape = shape })
		add(p)
		return p
	end
	local V3 = Vector3.new
	-- ── 사용자 확정 디자인(노트 main-monster-bone.svg, 모든 스테이지 공통) ──
	-- 뒤집힌 삼각 머리(둥근 눈 둘 + 위아래 이빨 입) · 속이 빈 관 뼈 · 구체관절 · 손발 모두 마디 손가락 4개 + 발톱
	-- 시안 좌표(px): 가운데 x = 335, 발톱 끝(바닥) y = 852, 아래로 +y, 75px = 1스터드. 바닥 y = -5, 앞 = -Z
	local PX = 75
	type Pt = { number }
	local function S(x: number, y: number, z: number): Vector3
		return V3((x - 335) / PX, -5 + (852 - y) / PX, z)
	end
	-- 한 획 선. ra/rb 만큼 양 끝을 잘라 관절 공 안으로 들어가지 않게
	local function line(a: Vector3, b: Vector3, r: number, ra: number?, rb: number?)
		local u = (b - a).Unit
		seg(a + u * (ra or 0), b - u * (rb or 0), r)
	end
	-- 관 뼈: 가는 원통(음파에는 보는 쪽 실루엣 2줄 + 끝 가로선 = 속이 빈 관). 양 끝은 관절 공 겉면까지만
	local BONE_R, BALL_R, KNUCKLE_R = 0.08, 0.15, 0.06
	local function bone(a: Vector3, b: Vector3)
		local u = (b - a).Unit
		add(Kit.cylinder(model, at(a + u * BALL_R), at(b - u * BALL_R), BONE_R))
	end
	-- 구체관절: 어느 쪽에서 봐도 원
	local function ball(p: Vector3, r: number)
		add(Kit.ball(model, at(p), r))
	end
	local function poly(pts: { Pt }, closed: boolean, z: number, r: number)
		local n = #pts
		for i = 1, (if closed then n else n - 1) do
			local a, b = pts[i], pts[i % n + 1]
			seg(S(a[1], a[2], z), S(b[1], b[2], z), r)
		end
	end
	local function curve(p0: Pt, c: Pt, p1: Pt, n: number, z: number, r: number)
		local pts: { Pt } = {}
		for i = 0, n do
			local t = i / n
			local u = 1 - t
			table.insert(pts, { u * u * p0[1] + 2 * u * t * c[1] + t * t * p1[1], u * u * p0[2] + 2 * u * t * c[2] + t * t * p1[2] })
		end
		poly(pts, false, z, r)
	end

	-- 몸통: 목 · 어깨 가로대 · 좁아지는 사다리꼴 몸통 · 휘어진 갈비뼈 5줄 · 육각 골반
	line(S(335, 200, -0.15), S(335, 213, 0), 0.03)
	line(S(287.5, 212, 0), S(392.5, 212, 0), 0.03, BALL_R, BALL_R)
	poly({ { 300, 215 }, { 380, 215 }, { 355, 300 }, { 322.5, 300 } }, true, 0, 0.03)
	curve({ 308, 230 }, { 318, 262 }, { 326, 296 }, 3, -0.02, 0.022)
	for _, rib in { { 318, 228, 345, 242, 372, 226 }, { 321, 242, 346, 254, 369, 240 }, { 324, 256, 346, 266, 366, 254 }, { 327, 269, 346, 278, 362, 268 }, { 330, 282, 346, 289, 358, 281 } } do
		curve({ rib[1], rib[2] }, { rib[3], rib[4] }, { rib[5], rib[6] }, 3, -0.03, 0.03)
	end
	poly({ { 322.5, 300 }, { 355, 300 }, { 362.5, 317.5 }, { 352.5, 335 }, { 325, 335 }, { 315, 317.5 } }, true, 0, 0.03)

	-- 팔·다리: 왼쪽(s = -1) 시안 좌표, 오른쪽은 좌우 대칭(x → 670 - x)
	-- 손·발: 손목(발목)에서 마디 손가락 4개. { 첫 마디 x, y, 둘째 마디 x, y, 발톱 끝 x, y }
	local HAND = { { 180, 512.5, 150, 535, 140, 585 }, { 190, 519, 162.5, 565, 160, 617.5 }, { 202.5, 520, 195, 567.5, 202.5, 612.5 }, { 215, 516, 239, 544, 244, 592.5 } }
	local FOOT = { { 240, 760, 212, 785, 196, 852 }, { 252, 768, 234, 805, 226, 852 }, { 268, 768, 276, 805, 284, 852 }, { 282, 760, 304, 786, 318, 852 } }
	-- 손가락은 아래로 갈수록 앞으로 굽고, 발가락은 발목에서 앞으로 뻗어 발톱 끝이 바닥에 닿는다
	local function handZ(y: number): number
		return -0.15 - 0.45 * math.clamp((y - 462.5) / 155, 0, 1)
	end
	local function footZ(y: number): number
		return 0.1 - 1.3 * math.clamp((y - 715) / 137, 0, 1)
	end
	local function digits(w: Vector3, list: { { number } }, P: (number, number, number) -> Vector3, zf: (number) -> number): Vector3
		local sum = Vector3.zero
		for _, d in list do
			local k1 = P(d[1], d[2], zf(d[2]))
			local k2 = P(d[3], d[4], zf(d[4]))
			local tip = P(d[5], d[6], zf(d[6]))
			line(w, k1, 0.025, BALL_R, KNUCKLE_R)
			line(k1, k2, 0.025, KNUCKLE_R, KNUCKLE_R)
			ball(k1, KNUCKLE_R)
			ball(k2, KNUCKLE_R)
			-- 발톱: 끝으로 갈수록 가늘어지는 가시(두 줄이 끝에서 만난다)
			local dir = (tip - k2).Unit
			local side = dir:Cross(Vector3.zAxis)
			if side.Magnitude < 0.1 then
				side = dir:Cross(Vector3.xAxis)
			end
			side = side.Unit * 0.04
			local base = k2 + dir * KNUCKLE_R
			seg(base + side, tip, 0.015)
			seg(base - side, tip, 0.015)
			sum += tip
		end
		return sum / #list
	end
	type LimbJ = { a: Vector3, b: Vector3, c: Vector3, tip: Vector3 }
	local armJ: { [number]: LimbJ } = {}
	local legJ: { [number]: LimbJ } = {}
	for _, s in { -1, 1 } do
		local function P(x: number, y: number, z: number): Vector3
			return S(if s < 0 then x else 670 - x, y, z)
		end
		group = "Arm" .. s
		local sh, el, wr = P(287.5, 211.5, 0), P(252.5, 332.5, 0.2), P(202.5, 462.5, -0.15)
		bone(sh, el)
		bone(el, wr)
		ball(el, BALL_R)
		ball(wr, BALL_R)
		armJ[s] = { a = sh, b = el, c = wr, tip = digits(wr, HAND, P, handZ) }
		group = "Leg" .. s
		local hip, kn, an = P(310, 333.5, 0), P(287.5, 480, -0.3), P(260, 715, 0.1)
		bone(hip, kn)
		bone(kn, an)
		ball(kn, BALL_R)
		ball(an, BALL_R)
		legJ[s] = { a = hip, b = kn, c = an, tip = digits(an, FOOT, P, footZ) }
		group = nil
		ball(sh, BALL_R)
		ball(hip, BALL_R * 0.9)
	end

	-- ── 머리: 공용 모양(MonsterFaces.BONE, 점프스케어 얼굴과 같다) ──
	local face = Faces.build(Faces.BONE)
	local HZ = -0.25 -- 머리 면의 깊이(조금 앞으로)
	local function hp(u: number, v: number, dz: number): Vector3
		return S(face.tx + u, face.ty + v, HZ + dz)
	end
	for _, l in face.lines do
		local n = #l.pts
		for i = 1, (if l.closed then n else n - 1) do
			local a, b = l.pts[i], l.pts[i % n + 1]
			local p = seg(hp(a[1], a[2], l.dz), hp(b[1], b[2], l.dz), l.r)
			if l.tint then
				p:SetAttribute("SonarColor", l.tint) -- 붉은 바늘 이빨
			end
		end
	end
	for _, c in face.circles do
		local p = hp(c.u, c.v, c.dz)
		seg(p, p + V3(0, 0, -0.02), c.rad / PX)
	end

	-- 전신 뼈대: 관절 위치는 시안 좌표 그대로(팔은 마디 2개, 무릎은 앞으로 굽는다)
	skeleton(model, root, cf, parts, groupParts, {
		pelvis = S(338.75, 318, 0),
		waist = S(340, 262, 0),
		neck = S(340, 212, 0),
		head = S(335, 202, -0.15),
		headEnd = S(face.tx, face.ty - 40, HZ),
		legs = {
			[-1] = { hip = legJ[-1].a, knee = legJ[-1].b, ankle = legJ[-1].c, toe = legJ[-1].tip },
			[1] = { hip = legJ[1].a, knee = legJ[1].b, ankle = legJ[1].c, toe = legJ[1].tip },
		},
		arms = {
			[-1] = { shoulder = armJ[-1].a, elbow = armJ[-1].b, wrist = armJ[-1].c, tip = armJ[-1].tip },
			[1] = { shoulder = armJ[1].a, elbow = armJ[1].b, wrist = armJ[1].c, tip = armJ[1].tip },
		},
		floorY = -5,
		mass = 1,
	})
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
	tracks: { walk: AnimationTrack, idle: AnimationTrack }?, -- 도플갱어가 진짜 아바타로 걷는 애니메이션
}, Monster))

local function between(r: { number }): number
	return r[1] + math.random() * (r[2] - r[1])
end

-- kind = "doppel" 이면 도플갱어(사람 모습으로 시작). 배회 지점(spawnPos)은 바닥 + 3
function Monster.new(parent: Instance, spawnPos: Vector3, nodes: { Vector3 }, geometry: Instance, onCatch: (Player, any) -> (), stage: number?, kind: string?): Monster
	local isDoppel = kind == "doppel"
	local isFlower = kind == "flower"
	local own: any = if isDoppel then Config.Doppel elseif isFlower then Config.Flower else nil
	local cfg: any = if own
		then setmetatable({}, {
			__index = function(_, k)
				local v = own[k]
				if v ~= nil then
					return v
				end
				return (MC :: any)[k]
			end,
		})
		else MC
	local model = if isDoppel
		then buildDoppel(CFrame.new(spawnPos + Vector3.new(0, 0.1, 0)))
		elseif isFlower then buildFlower(CFrame.new(spawnPos + Vector3.new(0, 1.1, 0)))
		else buildModel(CFrame.new(spawnPos + Vector3.new(0, 2.2, 0)), stage or 1)
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
		kind = if isDoppel then "doppel" elseif isFlower then "flower" else "main",
		form = if isDoppel then "Disguise" elseif isFlower then "Bud" else "Beast",
		cfg = cfg,
		discoveredBy = nil,
		transformAt = 0,
		pauseUntil = 0,
		nextPause = os.clock() + between(Config.Doppel.PauseEvery),
		nextPing = os.clock() + between(Config.Doppel.FakePingEvery),
		mawOpen = false,
		tracks = nil,
	}, Monster)
	-- 괴물마다 자기 소리(Config.MonsterVoices): 메인 괴물은 스테이지(머리 모양) 번호, 도플갱어는 "Doppel"
	model:SetAttribute("Voice", if isDoppel then "Doppel" elseif isFlower then "Flower" else tostring(((stage or 1) - 1) % 5 + 1))
	if isDoppel then
		self:setState("Disguise")
	elseif isFlower then
		self:setState("Dormant")
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
	table.insert(Monster.registry, self)
	return self
end

-- 쫓아올 때 확 튀어나갔다 멈칫하는 괴물(머리 모양 번호): 1 삼각 · 3 원 · 4 별. 평균 속도는 ChaseSpeed 그대로
-- (몸 동작은 서버가 아니라 클라이언트 MonsterAnim 이 매 프레임 만든다: 전신 뼈대 Rig 2)
local LUNGE: { [number]: boolean } = { [1] = true, [3] = true, [4] = true }

-- 서버 쪽 움직임: 쫓아올 때 속도 리듬만. 예전 몸(관절 4개, Rig 2 가 아닌 것)은 팔다리를 흔든다
function Monster.animate(self: Monster, dt: number)
	local tracks = self.tracks
	if tracks then
		-- 진짜 아바타 모습: 움직이면 걷기, 서 있으면 숨쉬기(플레이어와 같은 기본 애니메이션)
		local v = self.root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		if speed > 0.6 then
			if not tracks.walk.IsPlaying then
				tracks.idle:Stop(0.2)
				tracks.walk:Play(0.2)
			end
			tracks.walk:AdjustSpeed(math.clamp(speed / 12, 0.4, 1.4))
		elseif not tracks.idle.IsPlaying then
			tracks.walk:Stop(0.2)
			tracks.idle:Play(0.2)
		end
		return
	end
	local shape = if self.kind == "main" then tonumber(self.model:GetAttribute("Voice")) else nil
	if shape and LUNGE[shape] and self.state == "Chase" then
		-- 확 튀어나갔다 멈칫(0.4초 × 1.35배 + 0.3초 × 0.55배 = 평균 ChaseSpeed)
		local cyc = (os.clock() - self.stateChanged) % 0.7
		self.hum.WalkSpeed = self.cfg.ChaseSpeed * (if cyc < 0.4 then 1.35 else 0.55)
	end
	self.animT += dt
	if self.animT < 0.1 or #self.joints == 0 then
		return
	end
	local step = self.animT
	self.animT = 0
	local v = self.root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	self.phase = (self.phase + step * speed * 0.55) % (math.pi * 2)
	local amt = math.clamp(speed / 3, 0, 1)
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
	elseif s == "Dormant" or s == "Look" then
		speed = 0
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

-- 맡은 반쪽(territory): 맵을 반으로 나눠 메인 괴물이 한 마리씩 맡는다. 없으면 맵 전체
function Monster.inTerritory(self: Monster, pos: Vector3): boolean
	local t = (self :: any).territory
	if not t then
		return true
	end
	local v = if t.axis == "X" then pos.X else pos.Z
	return (v - t.mid) * t.side >= 0
end

function Monster.randomNode(self: Monster, awayFrom: Vector3?): Vector3
	local function pick(): Vector3
		for _ = 1, 16 do
			local n = self.nodes[math.random(1, #self.nodes)]
			if not Monster.isSafe(n) and self:inTerritory(n) then
				return n
			end
		end
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
	-- 같은 소리에 여러 마리가 몰려가지 않게: 이미 그 근처를 조사하러 가는(더 가까운) 괴물이 있으면 이 괴물은 가지 않는다
	-- (소리가 아주 가까우면 예외)
	local myD = (pos - self.root.Position).Magnitude
	if myD > 15 and self.state ~= "Chase" then
		for _, o in Monster.registry do
			if o ~= self and o.alive and (o.state == "Alert" or o.state == "Investigate" or o.state == "Search" or o.state == "Chase") then
				local og = o.goal or o.searchCenter
				if og and (og - pos).Magnitude < SHARE_SOUND and (pos - o.root.Position).Magnitude <= myD then
					return
				end
			end
		end
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
	if self.kind == "flower" then
		self:flowerHear(pos, radius, kind)
		return
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
	-- (클라이언트 몸 동작: 소리 난 쪽으로 움찔하며 고개를 돌린다)
	self.model:SetAttribute("Focus", pos)
	self.model:SetAttribute("Heard", os.clock())
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
	if self.kind == "flower" then
		self:flowerTick(now)
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
			-- 다른 괴물이 가까우면 그 반대쪽으로(한 곳에 몰리지 않게)
			local away = self.root.Position
			local nearest, nd = nil, SPREAD
			for _, o in Monster.registry do
				if o ~= self and o.alive and o.root then
					local d = (o.root.Position - self.root.Position).Magnitude
					if d < nd then
						nearest, nd = o, d
					end
				end
			end
			if nearest then
				away = nearest.root.Position
			end
			local n = self:randomNode(away)
			-- 넓은 맵에서 영영 마주치지 않는 일이 없게: 가끔 플레이어(숨지 않은) 근처로 배회한다
			if now - self.lastHunt >= MC.HuntEvery then
				self.lastHunt = now
				-- (자기 반쪽에 있는 플레이어만 찾아간다)
				local ps = {}
				for _, e in alivePlayers() do
					if self:inTerritory(e.root.Position) then
						table.insert(ps, e)
					end
				end
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

-- 가짜 음파: 머리 높이에서 팀원 음파와 똑같이(SonarPulse, userId 0 + 이 모델)
local SonarPulseRemote: RemoteEvent? = nil
function Monster.fakeSonar(self: Monster)
	if not SonarPulseRemote then
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		SonarPulseRemote = remotes and remotes:FindFirstChild("SonarPulse") :: RemoteEvent?
	end
	local head = self.model:FindFirstChild("Head") :: BasePart?
	local origin = if head then head.Position else self.root.Position + Vector3.new(0, 1.5, 0)
	if SonarPulseRemote then
		SonarPulseRemote:FireAllClients(0, origin, self.model)
	end
	self.model:SetAttribute("FakePing", os.clock()) -- (테스트·기록용. 소리는 SonarPulse 가 낸다)
end

-- 들켰다: 변신 시각을 정한다(Config.Doppel.TransformDelay: 10~30초 뒤, 그때 플레이어가 가까이 있어야 변신)
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
			-- 시간이 됐어도 플레이어가 가까이(TransformNear) 있을 때만 변신한다. 멀면 가까워질 때까지 사람 모습으로 기다린다
			local near = false
			for _, e in alivePlayers() do
				if (e.root.Position - my).Magnitude <= (cfg.TransformNear or 20) then
					near = true
					break
				end
			end
			if near then
				self:transform()
				return
			end
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
	-- 가짜 음파: 플레이어처럼 진짜 음파를 쏜다(모두에게 파동·소리가 보이고 들린다. 괴물을 부르지는 않는다)
	if now >= self.nextPing then
		self.nextPing = now + between(cfg.FakePingEvery)
		self:fakeSonar()
	end
	if #self.waypoints == 0 or self:follow() then
		if not self:pathTo(self:randomNode(my)) then
			self.waypoints = {}
		end
	end
	self:checkStuck(true)
end

-- 도플갱어를 진짜 아바타로 입힌다(친구 목록의 사람, 없으면 지금 플레이어 중 한 명 — 혼자면 내 모습).
-- 아바타 몸(R15 파트·장신구)을 모델 바로 아래로 옮기고(속성 DisguisePart), 관절을 우리 루트에 잇는다.
-- 몸은 그대로 보인다: 클라이언트가 팀원과 똑같이 늘 흰 윤곽선을 씌운다(Mates). 음파 선은 그리지 않는다(플레이어처럼)
local WALK_ANIM = "rbxassetid://507777826" -- 로블록스 기본 R15 걷기
local IDLE_ANIM = "rbxassetid://507766388" -- 로블록스 기본 R15 서 있기
function Monster.applyAvatar(self: Monster, desc: HumanoidDescription, who: string): boolean
	if self.form ~= "Disguise" or not self.alive or not self.model.Parent then
		return false
	end
	local ok, av = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not av then
		warn("[Doppel] avatar build failed: " .. tostring(av))
		return false
	end
	local avatar = av :: Model
	local avRoot = avatar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local avHum = avatar:FindFirstChildOfClass("Humanoid")
	if not avRoot or not avHum or self.form ~= "Disguise" then
		avatar:Destroy()
		return false
	end
	avatar:PivotTo(self.root.CFrame)
	-- 예전 상자 몸 치우기
	for _, j in self.root:GetChildren() do
		if j:IsA("Motor6D") and j.Name:find("^DJoint") then
			j:Destroy()
		end
	end
	local old = self.model:FindFirstChild("Disguise")
	if old then
		old:Destroy()
	end
	self.joints = {}
	local tag = Config.Tags.Renderable
	for _, c in avatar:GetChildren() do
		if c ~= avRoot and not c:IsA("Humanoid") and not c:IsA("BaseScript") then
			c:SetAttribute("DisguisePart", true)
			c.Parent = self.model
			local list: { Instance } = c:GetDescendants()
			table.insert(list, c)
			for _, d in list do
				if d:IsA("JointInstance") then
					local jd = d :: any
					if jd.Part0 == avRoot then
						jd.Part0 = self.root
					end
					if jd.Part1 == avRoot then
						jd.Part1 = self.root
					end
				elseif d:IsA("WeldConstraint") then
					if d.Part0 == avRoot then
						d.Part0 = self.root
					end
					if d.Part1 == avRoot then
						d.Part1 = self.root
					end
				elseif d:IsA("BasePart") then
					d.Anchored = false
					d.Massless = true
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
					d.CastShadow = false
					-- (투명하게 하지 않는다: 들키기 전에도 팀원처럼 늘 그 사람 모습으로 보인다)
					CollectionService:AddTag(d, tag)
				end
			end
		end
	end
	self.hum.HipHeight = avHum.HipHeight
	avatar:Destroy()
	-- 플레이어와 같은 걷기·서 있기 애니메이션
	local animator = self.hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = self.hum
	end
	local function load(id: string, fallback: string): AnimationTrack
		local a = Instance.new("Animation")
		a.AnimationId = if id ~= "" and id ~= "rbxassetid://0" then id else fallback
		local tr = (animator :: Animator):LoadAnimation(a)
		tr.Looped = true
		return tr
	end
	self.tracks = {
		walk = load(if desc.WalkAnimation ~= 0 then "rbxassetid://" .. desc.WalkAnimation else "", WALK_ANIM),
		idle = load(if desc.IdleAnimation ~= 0 then "rbxassetid://" .. desc.IdleAnimation else "", IDLE_ANIM),
	}
	self.model:SetAttribute("AvatarOf", who)
	self.model:SetAttribute("BodyVersion", ((self.model:GetAttribute("BodyVersion") :: number?) or 1) + 1)
	self:note("dressed as " .. who)
	return true
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
	-- 진짜 아바타 모습이면 그 몸 파트들(장신구 포함)이 터진다
	local avatarParts: { Instance } = {}
	for _, c in self.model:GetChildren() do
		if c:GetAttribute("DisguisePart") then
			table.insert(avatarParts, c)
			local list: { Instance } = c:GetDescendants()
			table.insert(list, c)
			for _, d in list do
				if d:IsA("BasePart") and #boxes < 40 then
					table.insert(boxes, { cf = d.CFrame, size = d.Size })
				end
			end
		end
	end
	if self.tracks then
		self.tracks.walk:Stop(0)
		self.tracks.idle:Stop(0)
		self.tracks = nil
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
	for _, c in avatarParts do
		c:Destroy()
	end
	self.hum.HipHeight = DOPPEL_HIP
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

-- ── 꽃괴물: 가만히 서 있다가 음파를 들으면 머리를 펼치고 쏜 곳으로 달려간다 ──
-- 머리 펼치기/닫기: 음파 대상 태그를 봉오리(Bud) ↔ 펼친 머리(Bloom) 선으로 바꿔 낀다
function Monster.setBloom(self: Monster, open: boolean)
	local want = if open then "Open" else "Bud"
	if self.form == want then
		return
	end
	self.form = want
	local tag = Config.Tags.Renderable
	local body = self.model:FindFirstChild("Body")
	if body then
		for _, p in body:GetChildren() do
			if p:IsA("BasePart") then
				local on = if p:GetAttribute("Bloom") then open elseif p:GetAttribute("Bud") then not open else nil
				if on == true then
					CollectionService:AddTag(p, tag)
				elseif on == false then
					CollectionService:RemoveTag(p, tag)
				end
			end
		end
	end
	self.model:SetAttribute("Form", want)
	self.model:SetAttribute("BodyVersion", ((self.model:GetAttribute("BodyVersion") :: number?) or 1) + 1)
end

-- 달려갈 곳: 음파 쏜 자리(안전 구역 안이면 그 앞, 바닥 위)
local function rushGoal(self: Monster, pos: Vector3): Vector3
	if Monster.isSafe(pos) then
		return self:nearestOutside(pos) or pos
	end
	return pos
end

function Monster.flowerHear(self: Monster, pos: Vector3, radius: number, kind: string)
	if kind ~= "Sonar" or not self.alive or os.clock() < self.startAt then
		return
	end
	if not SoundBus.canHear(pos, self.root.Position, radius) then
		return
	end
	local goal = rushGoal(self, pos)
	self.goal = goal
	self.waypoints = {}
	if self.state == "Dormant" then
		-- 깨어난다: 쉿(Alert 특수 소리) + 꽃잎을 펼친다, 펼치는 동안은 멈춰 있다
		self:note("woke to sonar")
		self:setBloom(true)
		self.alertUntil = os.clock() + self.cfg.WakeTime
		self:setState("Alert")
	elseif self.state == "Look" then
		self:setState("Chase")
	end
	-- (달리는 중이면 목표만 바뀐다)
end

function Monster.flowerTick(self: Monster, now: number)
	local cfg = self.cfg
	local my = self.root.Position
	local st = self.state
	if st == "Dormant" then
		self.hum:MoveTo(my)
		return
	end
	-- 달리거나 두리번거리는 중, 바로 앞(벽 없이)에 플레이어가 있으면 덤빈다
	if st == "Chase" or st == "Look" then
		for _, e in alivePlayers() do
			local p = e.root.Position
			if (p - my).Magnitude <= cfg.GrabRange and math.abs(p.Y - my.Y) < 7 and self:lineOfSight(p) then
				self.goal = p
				self.waypoints = {}
				if st == "Look" then
					self:setState("Chase")
					st = "Chase"
				end
				self.hum:MoveTo(p)
				return
			end
		end
	end
	if st == "Alert" then
		self.hum:MoveTo(my)
		if now >= self.alertUntil then
			self:setState("Chase")
		end
		return
	end
	if st == "Chase" then
		local goal = self.goal
		if not goal then
			self:setState("Look")
			self.searchUntil = now + between(cfg.LookAround)
			return
		end
		local flat = Vector3.new(goal.X - my.X, 0, goal.Z - my.Z).Magnitude
		if flat < 4 then
			-- 도착: 아무도 없다 → 두리번
			self:note("arrived, looking around")
			self.waypoints = {}
			self.goal = nil
			self:setState("Look")
			self.searchUntil = now + between(cfg.LookAround)
			return
		end
		if #self.waypoints == 0 then
			if not self:pathTo(goal) then
				-- 갈 수 없는 곳: 가장 가까운 배회 지점으로
				local best, bd = nil, math.huge
				for _, n in self.nodes do
					local dd = (n - goal).Magnitude
					if dd < bd and not Monster.isSafe(n) then
						best, bd = n, dd
					end
				end
				if best and (best - goal).Magnitude > 0.5 then
					self.goal = best
				else
					self.goal = nil
				end
				return
			end
		end
		self:follow()
		Doors.openNear(my + self.root.CFrame.LookVector * 2, 6, my)
		self:checkStuck(true)
		return
	end
	if st == "Look" then
		self.hum:MoveTo(my)
		-- 두리번: 조금씩 몸을 돌린다
		self.root.CFrame = self.root.CFrame * CFrame.Angles(0, math.rad(math.random(-25, 25)), 0)
		if now >= self.searchUntil then
			-- 머리를 닫고 그 자리에서 다시 기다린다
			self:note("closing, dormant")
			self:setBloom(false)
			self:setState("Dormant")
		end
		return
	end
	-- (그 밖의 상태가 되면 기다림으로)
	self:setBloom(false)
	self:setState("Dormant")
end

-- 잡기 판정(매 프레임)
function Monster.checkCatch(self: Monster)
	if not self.alive or os.clock() < self.startAt then
		return
	end
	-- 도플갱어는 괴물 모습일 때만, 꽃괴물은 머리를 펼쳤을 때만 잡는다
	if (self.kind == "doppel" and self.form ~= "Beast") or (self.kind == "flower" and self.form ~= "Open") then
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
	local i = table.find(Monster.registry, self)
	if i then
		table.remove(Monster.registry, i)
	end
	self.model:Destroy()
end

return Monster
