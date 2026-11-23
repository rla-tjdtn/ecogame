--!strict
-- 괴물 전신 움직임(클라이언트). 서버는 위치·상태만 정하고, 몸은 여기서 매 프레임 만든다(Rig 2 뼈대의 Motor6D.Transform).
--
-- 원리(관절을 그냥 흔들지 않는다):
--  · 발 고정(Foot Planting): 디딘 발은 월드 위치에 못 박힌다. 몸이 앞으로 가서 발이 "제자리(엉덩이 아래 + 진행 방향)"에서
--    보폭 절반 이상 벗어나면 그 발을 들어 다음 착지점으로 옮긴다(한 번에 한 발, 기어갈 때는 대각선 두 발).
--    다리는 2관절 IK 로 그 발 위치에 맞춘다 → 미끄러짐 없음, 보폭·속도가 저절로 맞는다.
--  · 무게중심: 골반 높이는 디딘 다리가 닿을 수 있는 높이로 정해져(다리를 벌리면 내려간다) 걸음마다 오르내리고,
--    체중을 받는 발 쪽으로 좌우 이동한다. 착지하는 순간 질량만큼 아래로 충격(스프링)을 받는다.
--  · 관성: 몸통·머리·팔은 모두 스프링-감쇠로 목표를 따라가 시간차가 생긴다. 가속하면 상체가 먼저 앞으로 쏠리고,
--    멈추면 뒤로 젖혀졌다가 돌아온다. 회전하면 머리 → 가슴 → 골반 순으로 먼저 돌고 안쪽으로 기운다.
--  · 팔: 진자(길이에 맞는 고유 진동수)로 다리 반대 박자에 흔들리고, 몸의 가속에 늦게 따라온다. 아래 마디는 한 박자 더 늦다.
--  · 머리: 몸통 흔들림을 상쇄하며 바라볼 곳(소리 난 곳, 쫓는 대상, 두리번)을 지연을 두고 본다.
--  · 상태별 자세: 대기(호흡·체중 재분배·미세한 떨림·두리번), 경계(낮은 자세, 움찔), 추격(괴물마다 다른 체형별 동작),
--    덮치기 직전(몸을 낮추고 팔을 뒤로 모았다가 앞으로 뻗음).
--
-- 서버 Monster.luau 의 skeleton() 이 만든 뼈 이름을 쓴다: B_Pelvis, B_Chest, B_Neck, B_Head, B_Thigh±1, B_Shin±1, B_Foot±1,
-- B_Upper±1, (B_Mid±1), B_Fore±1, B_Hand±1. 모델 속성 Rig = 2, FloorY, Mass, Voice(머리 모양 번호), State, Form.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Anim = {}
-- 발이 땅에 닿는 순간(발소리): (모델, 발 위치, 세기 0~1.5)
Anim.onStep = nil :: ((Model, Vector3, number) -> ())?
-- (테스트) 모델별 측정값
Anim.stats = {} :: { [Model]: { [string]: number } }

local TWO_PI = math.pi * 2
local GRAVITY = workspace.Gravity

type Spring = { x: number, v: number }
type VSpring = { x: Vector3, v: Vector3 }
local function sp(x: number?): Spring
	return { x = x or 0, v = 0 }
end
-- 스프링-감쇠(freq: 초당 진동수, damp: 1 = 임계 감쇠)
local function step(s: Spring, target: number, freq: number, damp: number, dt: number)
	local w = TWO_PI * freq
	local a = w * w * (target - s.x) - 2 * damp * w * s.v
	s.v += a * dt
	s.x += s.v * dt
end
local function vstep(s: VSpring, target: Vector3, freq: number, damp: number, dt: number)
	local w = TWO_PI * freq
	local a = (target - s.x) * (w * w) - s.v * (2 * damp * w)
	s.v += a * dt
	s.x += s.v * dt
end
-- 벡터 a 를 b 로 돌리는 회전
local function fromTo(a: Vector3, b: Vector3): CFrame
	local axis = a:Cross(b)
	local s = axis.Magnitude
	local c = a:Dot(b)
	if s < 1e-6 then
		if c > 0 then
			return CFrame.identity
		end
		local perp = if math.abs(a.X) < 0.9 then Vector3.xAxis else Vector3.yAxis
		return CFrame.fromAxisAngle(a:Cross(perp).Unit, math.pi)
	end
	return CFrame.fromAxisAngle(axis / s, math.atan2(s, c))
end
local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end
local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- ── 몸 스타일(상태·괴물마다). 숫자는 매 프레임 부드럽게 섞여 전환된다 ──
-- crouch: 골반을 낮추는 정도(다리 길이 비율), lean: 상체 앞 숙임(rad), stride: 보폭 기준(다리 길이 비율),
-- lift: 발 드는 높이(다리 길이 비율), armBase/armSwing: 팔 기본 각도·흔들림, quad: 손도 땅을 짚는다(0~1),
-- wave: 척추 꿈틀(rad), jerk: 꼭두각시처럼 몸 목표를 끊어서 갱신(0~1), limp: 오른 다리 절뚝(0~1),
-- tension: 몸 스프링 진동수 배율(긴장할수록 빠르고 날카롭다), flail: 팔이 몸 반동에 휘둘리는 정도
type Style = { crouch: number, lean: number, stride: number, lift: number, armBase: number, armSwing: number, armSpread: number, quad: number, wave: number, jerk: number, limp: number, tension: number, flail: number, headDrop: number }
local KEYS = { "crouch", "lean", "stride", "lift", "armBase", "armSwing", "armSpread", "quad", "wave", "jerk", "limp", "tension", "flail", "headDrop" }
local function style(t: { [string]: number }): Style
	local base: { [string]: number } = { crouch = 0.08, lean = 0.12, stride = 0.34, lift = 0.16, armBase = 0.12, armSwing = 0.3, armSpread = 0.12, quad = 0, wave = 0, jerk = 0, limp = 0, tension = 1, flail = 0, headDrop = 0 }
	for k, v in t do
		base[k] = v
	end
	return (base :: any) :: Style
end
local WALK = style({})
local ALERT = style({ crouch = 0.2, lean = 0.3, stride = 0.3, armBase = 0.45, armSwing = 0.15, armSpread = 0.25, tension = 1.5 })
-- 쫓아올 때(메인 괴물 머리 모양 번호별): 체형·성격에 맞춘 변형
local CHASE: { [number]: Style } = {
	-- 1 삼각: 무겁게 절뚝이며 앞으로 쏠리고, 긴 팔을 머리 위로 치켜든 채 몸 반동에 휘둘린다
	[1] = style({ crouch = 0.16, lean = 0.5, stride = 0.48, lift = 0.24, armBase = 2.3, armSwing = 0.35, armSpread = 0.35, limp = 0.7, tension = 1.2, flail = 1 }),
	-- 2 사각: 줄 끊긴 꼭두각시. 무릎을 거의 안 굽히고 키를 세운 채, 몸이 줄에 당겨지듯 끊겨 움직이고 팔이 크게 휘둘린다
	[2] = style({ crouch = 0.0, lean = 0.05, stride = 0.42, lift = 0.12, armBase = 0.2, armSwing = 1.1, armSpread = 0.45, jerk = 1, tension = 1.6, flail = 0.6 }),
	-- 3 원: 상체를 땅으로 숙이고 긴 팔로 앞을 짚으며 네 발로 기어온다. 척추가 꿈틀거리며 상체가 끌고 하체가 따라온다
	[3] = style({ crouch = 0.42, lean = 1.25, stride = 0.36, lift = 0.14, armBase = 1.2, armSwing = 0.2, armSpread = 0.2, quad = 1, wave = 0.3, tension = 1.3 }),
	-- 4 별: 키를 세우고 무릎을 높이 들어 크게 성큼 내딛는다. 착지마다 무거운 충격, 팔은 늘어져 출렁인다
	[4] = style({ crouch = -0.02, lean = 0.18, stride = 0.62, lift = 0.6, armBase = 0.05, armSwing = 0.12, armSpread = 0.08, tension = 0.9, flail = 0.5 }),
	-- 5 육각: 몸을 낮추고 팔과 다리로 곤충처럼 잰걸음. 짧고 빠른 보폭
	[5] = style({ crouch = 0.34, lean = 1.0, stride = 0.26, lift = 0.12, armBase = 1.0, armSwing = 0.2, armSpread = 0.35, quad = 1, wave = 0.12, tension = 1.7 }),
}
local DOPPEL_CHASE = style({ crouch = 0.2, lean = 0.55, stride = 0.46, lift = 0.2, armBase = 0.9, armSwing = 0.45, armSpread = 0.3, tension = 1.5, flail = 0.4 })
local FLOWER_RUSH = style({ crouch = 0.12, lean = 0.6, stride = 0.55, lift = 0.22, armBase = -0.35, armSwing = 0.35, armSpread = 0.1, tension = 1.2, flail = 0.8 })
local FLOWER_STILL = style({ crouch = 0.04, lean = 0.06, armBase = 0.02, armSwing = 0.05, headDrop = 0.55, tension = 0.6 })

-- ── 괴물 하나의 몸 ──
type LimbRest = { m1: Motor6D, m2: Motor6D, m3: Motor6D?, mEnd: Motor6D, mToe: Motor6D?, v1: Vector3, v2: Vector3?, v3: Vector3, tip: Vector3, pole: Vector3 }
type Foot = { pos: Vector3, lifted: boolean, from: Vector3, to: Vector3, t: number, dur: number, planted: boolean }
type Arm = { pitch: Spring, roll: Spring, c1: Spring, c2: Spring, c3: Spring }
type Body = {
	model: Model,
	root: BasePart,
	pelvisM: Motor6D,
	chestM: Motor6D,
	neckM: Motor6D,
	headM: Motor6D,
	pelvisRest: Vector3,
	legs: { [number]: LimbRest },
	arms: { [number]: LimbRest },
	floorY: number,
	mass: number,
	legLen: number,
	armLen: number,
	feet: { [number]: Foot },
	hands: { [number]: Foot },
	st: Style,
	pel: VSpring,
	pelRot: VSpring, -- (pitch, yaw, roll)
	chest: VSpring,
	head: VSpring, -- 머리 월드 방향(yaw, pitch) 기준 몸 회전과 별개
	armS: { [number]: Arm },
	vel: VSpring,
	lastPos: Vector3,
	lastYaw: number,
	yawRate: Spring,
	accel: Vector3, -- 로컬 가속(부드럽게)
	t: number,
	gait: number, -- 걸은 거리 누적(척추 꿈틀 박자)
	idleShift: number,
	nextShift: number,
	look: Vector2, -- 두리번 목표(yaw, pitch)
	nextLook: number,
	lookFreq: number,
	held: { [string]: number }, -- 꼭두각시: 끊어서 갱신한 목표
	nextHold: number,
	freezeUntil: number,
	seed: number,
	lastHeard: any,
	lastState: string,
	stats: { [string]: number },
}

local bodies: { [Model]: Body } = {}

local function motor(model: Model, name: string): Motor6D?
	local m = model:FindFirstChild("B_" .. name, true)
	return if m and m:IsA("Motor6D") then m else nil
end
local function tipOf(m: Motor6D): Vector3
	local p = m.Part1
	local t = p and p:GetAttribute("Tip")
	return if typeof(t) == "Vector3" then t else Vector3.new(0, -0.5, 0)
end
-- 극(무릎·팔꿈치가 굽는 쪽): 뼈 두 마디의 꺾인 방향(없으면 기본)
local function poleOf(v1: Vector3, v2: Vector3, default: Vector3): Vector3
	local u = (v1 + v2).Unit
	local p = v1 - u * v1:Dot(u)
	if p.Magnitude < 0.05 then
		return default
	end
	return p.Unit
end

local function build(model: Model): Body?
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local pelvisM, chestM, neckM, headM = motor(model, "Pelvis"), motor(model, "Chest"), motor(model, "Neck"), motor(model, "Head")
	if not (root and pelvisM and chestM and neckM and headM) then
		return nil
	end
	local legs: { [number]: LimbRest } = {}
	local arms: { [number]: LimbRest } = {}
	for _, s in { -1, 1 } do
		local th, sh, ft = motor(model, "Thigh" .. s), motor(model, "Shin" .. s), motor(model, "Foot" .. s)
		local up, mid, fo, ha = motor(model, "Upper" .. s), motor(model, "Mid" .. s), motor(model, "Fore" .. s), motor(model, "Hand" .. s)
		if not (th and sh and ft and up and fo and ha) then
			return nil
		end
		local v1, v2 = sh.C0.Position, ft.C0.Position
		-- (무릎은 앞쪽으로 굽는 경향: 그림의 꺾인 방향 + 앞)
		local kp = poleOf(v1, v2, -Vector3.zAxis)
		legs[s] = { m1 = th, m2 = sh, mEnd = ft, mToe = motor(model, "Toe" .. s), v1 = v1, v3 = v2, tip = tipOf(ft), pole = (kp + Vector3.new(0, 0, -0.8)).Unit }
		if mid then
			local a1, a2, a3 = mid.C0.Position, fo.C0.Position, ha.C0.Position
			arms[s] = { m1 = up, m2 = mid, m3 = fo, mEnd = ha, v1 = a1, v2 = a2, v3 = a3, tip = tipOf(ha), pole = poleOf(a1 + a2, a3, Vector3.zAxis) }
		else
			local a1, a3 = fo.C0.Position, ha.C0.Position
			arms[s] = { m1 = up, m2 = fo, mEnd = ha, v1 = a1, v3 = a3, tip = tipOf(ha), pole = poleOf(a1, a3, Vector3.zAxis) }
		end
	end
	local legLen = (legs[-1].v1.Magnitude + legs[-1].v3.Magnitude + legs[1].v1.Magnitude + legs[1].v3.Magnitude) / 2
	local a = arms[-1]
	local armLen = a.v1.Magnitude + (if a.v2 then a.v2.Magnitude else 0) + a.v3.Magnitude
	local rcf = root.CFrame
	local function footAt(s: number): Foot
		local L = legs[s]
		local ankleLocal = pelvisM.C0.Position + L.m1.C0.Position + L.v1 + L.v3
		local p = rcf:PointToWorldSpace(ankleLocal)
		return { pos = p, lifted = false, from = p, to = p, t = 0, dur = 0.3, planted = true }
	end
	local function handAt(s: number): Foot
		local A = arms[s]
		local p = rcf:PointToWorldSpace(pelvisM.C0.Position + chestM.C0.Position + A.m1.C0.Position + Vector3.new(0, -armLen * 0.8, -0.5))
		return { pos = p, lifted = false, from = p, to = p, t = 0, dur = 0.3, planted = false }
	end
	local function arm(): Arm
		return { pitch = sp(), roll = sp(), c1 = sp(), c2 = sp(), c3 = sp() }
	end
	local _, yaw = rcf:ToEulerAnglesYXZ()
	local b: Body = {
		model = model,
		root = root,
		pelvisM = pelvisM,
		chestM = chestM,
		neckM = neckM,
		headM = headM,
		pelvisRest = pelvisM.C0.Position,
		legs = legs,
		arms = arms,
		floorY = (model:GetAttribute("FloorY") :: number?) or -5,
		mass = (model:GetAttribute("Mass") :: number?) or 1,
		legLen = legLen,
		armLen = armLen,
		feet = { [-1] = footAt(-1), [1] = footAt(1) },
		hands = { [-1] = handAt(-1), [1] = handAt(1) },
		st = style({}),
		pel = { x = Vector3.zero, v = Vector3.zero },
		pelRot = { x = Vector3.zero, v = Vector3.zero },
		chest = { x = Vector3.zero, v = Vector3.zero },
		head = { x = Vector3.zero, v = Vector3.zero },
		armS = { [-1] = arm(), [1] = arm() },
		vel = { x = Vector3.zero, v = Vector3.zero },
		lastPos = rcf.Position,
		lastYaw = yaw,
		yawRate = sp(),
		accel = Vector3.zero,
		t = math.random() * 10,
		gait = 0,
		idleShift = 0,
		nextShift = 0,
		look = Vector2.zero,
		nextLook = 0,
		lookFreq = 2,
		held = {},
		nextHold = 0,
		freezeUntil = 0,
		seed = math.random() * 1000,
		lastHeard = model:GetAttribute("Heard"),
		lastState = (model:GetAttribute("State") :: string?) or "Wander",
		stats = { steps = 0, slip = 0, pelvisMin = math.huge, pelvisMax = -math.huge, chestYawMax = 0, headLag = 0, frames = 0, leanMax = 0, armMax = 0, liftMax = 0, freezes = 0, handSteps = 0 },
	}
	Anim.stats[model] = b.stats
	return b
end

-- 지금 상태에 맞는 목표 스타일
local function targetStyle(b: Body, speed: number): Style
	local m = b.model
	local state = (m:GetAttribute("State") :: string?) or "Wander"
	local voice = m:GetAttribute("Voice")
	if voice == "Flower" then
		return if speed > 3 then FLOWER_RUSH else FLOWER_STILL
	end
	if state == "Chase" then
		if voice == "Doppel" then
			return DOPPEL_CHASE
		end
		return CHASE[tonumber(voice) or 1] or WALK
	elseif state == "Alert" or state == "Investigate" or state == "Search" or state == "Look" then
		return ALERT
	end
	return WALK
end

-- 가장 가까운 살아 있는 플레이어(덮치기 자세)
local function nearestPlayer(pos: Vector3): (Vector3?, number)
	local best: Vector3?, bestD = nil, math.huge
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r and p:GetAttribute("Status") ~= "Dead" then
			local d = (r.Position - pos).Magnitude
			if d < bestD then
				best, bestD = r.Position, d
			end
		end
	end
	return best, bestD
end

-- 2관절 IK: 시작점 H 에서 길이 l1, l2 두 마디로 목표 A 에 닿는 무릎(팔꿈치) 위치
local function solve2(H: Vector3, A: Vector3, l1: number, l2: number, pole: Vector3): (Vector3, Vector3)
	local d = A - H
	local dist = math.clamp(d.Magnitude, math.abs(l1 - l2) + 0.02, (l1 + l2) * 0.999)
	local u = if d.Magnitude > 1e-4 then d.Unit else Vector3.new(0, -1, 0)
	local a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
	local h = math.sqrt(math.max(l1 * l1 - a * a, 0))
	local p = pole - u * pole:Dot(u)
	p = if p.Magnitude > 1e-4 then p.Unit else Vector3.new(0, 0, -1)
	return H + u * a + p * h, H + u * dist
end

local function update(b: Body, dt: number)
	local root = b.root
	local rcf = root.CFrame
	local rrot = rcf.Rotation
	b.t += dt
	local now = b.t
	local m = b.model

	-- ── 이동량: 속도·가속·회전 속도(부드럽게) ──
	local pos = rcf.Position
	local rawVel = (pos - b.lastPos) / math.max(dt, 1e-3)
	local teleported = (pos - b.lastPos).Magnitude > 6
	b.lastPos = pos
	if teleported then
		-- 순간 이동(되살아남·테스트 배치): 몸 상태를 놓고 발을 새 자리 밑에 다시 딛는다
		rawVel = Vector3.zero
		b.vel.x, b.vel.v = Vector3.zero, Vector3.zero
		b.pel.x, b.pel.v = Vector3.zero, Vector3.zero
		b.chest.v = Vector3.zero
	end
	local prevVel = b.vel.x
	vstep(b.vel, flat(rawVel), 4, 1, dt)
	local vel = b.vel.x
	local speed = vel.Magnitude
	local accW = (vel - prevVel) / math.max(dt, 1e-3)
	local accL = rrot:VectorToObjectSpace(accW)
	b.accel = b.accel:Lerp(accL, math.min(1, dt * 6))
	local _, yaw = rcf:ToEulerAnglesYXZ()
	local dyaw = (yaw - b.lastYaw + math.pi) % TWO_PI - math.pi
	b.lastYaw = yaw
	step(b.yawRate, dyaw / math.max(dt, 1e-3), 1.5, 1, dt)
	local yawRate = math.clamp(b.yawRate.x, -3, 3)

	-- ── 스타일 섞기 ──
	local tgt = targetStyle(b, speed)
	local k = math.min(1, dt * 3)
	local st = b.st :: any
	for _, key in KEYS do
		st[key] = lerp(st[key], (tgt :: any)[key], k)
	end
	local S = b.st
	local legLen = b.legLen
	local tension = S.tension * (if b.mass < 0.8 then 1.25 else 1)

	-- 상태 변화·소리: 움찔(골반이 내려앉고 상체가 뒤로 젖혀졌다 돌아온다)
	local state = (m:GetAttribute("State") :: string?) or "Wander"
	local heard = m:GetAttribute("Heard")
	if heard ~= b.lastHeard or (state ~= b.lastState and (state == "Alert" or state == "Chase")) then
		b.pel.v += Vector3.new(0, -2.2 * legLen / 4, 0.6)
		b.chest.v += Vector3.new(-2.5, 0, 0)
		b.lookFreq = 7
		b.nextLook = now + 1.5
	end
	b.lastHeard = heard
	b.lastState = state

	-- 꼭두각시: 몸 목표를 끊어서 갱신(가끔 완전히 굳는다)
	local jerk = S.jerk > 0.5
	if jerk and now >= b.nextHold then
		b.nextHold = now + 1 / 6
		if math.noise(now * 0.7, b.seed) > 0.42 and now > b.freezeUntil + 1 then
			b.freezeUntil = now + 0.45
			b.stats.freezes += 1
		end
	end

	-- ── 발 고정·걸음 ──
	local quad = S.quad > 0.5
	local stride = legLen * S.stride
	local threshold = stride * 0.5
	local stepDur = math.clamp(0.85 * threshold / math.max(speed, 0.6), 0.14, 0.5) * (if S.lift > 0.4 then 1.35 else 1)
	local dir = if speed > 0.2 then vel.Unit else Vector3.zero
	local groundY = rcf:PointToWorldSpace(Vector3.new(0, b.floorY, 0)).Y
	local function home(s: number): Vector3
		local L = b.legs[s]
		local hipL = b.pelvisRest + L.m1.C0.Position
		local p = rcf:PointToWorldSpace(Vector3.new(hipL.X * 1.1, 0, hipL.Z + (if quad then legLen * 0.15 else 0)))
		local ankleH = L.v1.Y + L.v3.Y + b.pelvisRest.Y + L.m1.C0.Position.Y - b.floorY
		return Vector3.new(p.X, groundY + ankleH, p.Z)
	end
	local idle = speed < 0.4
	if idle and now > b.nextShift then
		b.nextShift = now + 2.5 + math.noise(now, b.seed + 3) * 2 + 1.5
		b.idleShift = if b.idleShift >= 0 then -1 else 1
	end
	type LimbStep = { f: Foot, home: Vector3, side: number, isHand: boolean }
	local limbs: { LimbStep } = {}
	for _, s in { -1, 1 } do
		table.insert(limbs, { f = b.feet[s], home = home(s), side = s, isHand = false })
	end
	if quad then
		for _, s in { -1, 1 } do
			local A = b.arms[s]
			local sh = rcf:PointToWorldSpace(b.pelvisRest + b.chestM.C0.Position + A.m1.C0.Position)
			local fw = rcf.LookVector * (b.armLen * 0.45 + legLen * 0.2)
			local hh = Vector3.new(sh.X + fw.X, groundY + 0.1, sh.Z + fw.Z)
			local hand = b.hands[s]
			if not hand.planted then
				hand.planted, hand.pos, hand.lifted = true, hh, false
			end
			table.insert(limbs, { f = hand, home = hh, side = s, isHand = true })
		end
	else
		for _, s in { -1, 1 } do
			b.hands[s].planted = false
			b.hands[s].lifted = false
		end
	end
	-- 순간 이동했거나 발이 몸에서 너무 멀어졌으면(끊김·지연) 그 발을 제자리에 다시 딛는다
	for _, l in limbs do
		if teleported or flat(l.f.pos - l.home).Magnitude > legLen * 1.6 then
			l.f.pos, l.f.from, l.f.to, l.f.lifted, l.f.t = l.home, l.home, l.home, false, 0
		end
	end
	local function liftedCount(): number
		local n = 0
		for _, l in limbs do
			if l.f.lifted then
				n += 1
			end
		end
		return n
	end
	-- 떠 있는 발 옮기기(포물선 궤적, 착지하면 충격)
	for _, l in limbs do
		local f = l.f
		if f.lifted then
			f.t += dt / f.dur
			if f.t >= 1 then
				f.lifted = false
				f.pos = f.to
				-- 착지: 질량만큼 골반이 내려앉고(무게), 발소리
				local hit = b.mass * math.clamp(speed / 6, 0.35, 1.6) * (if S.lift > 0.4 then 1.6 else 1)
				if not l.isHand then
					b.pel.v += Vector3.new(0, -1.4 * hit, 0)
					b.chest.v += Vector3.new(0.6 * hit, 0, 0)
					if Anim.onStep then
						Anim.onStep(m, f.pos, hit)
					end
					b.stats.steps += 1
				else
					b.stats.handSteps += 1
				end
			else
				local e = f.t * f.t * (3 - 2 * f.t)
				local p = f.from:Lerp(f.to, e)
				local h = (if l.isHand then legLen * 0.12 else legLen * S.lift) * math.sin(math.pi * f.t)
				f.pos = p + Vector3.new(0, h, 0)
				if not l.isHand then
					b.stats.liftMax = math.max(b.stats.liftMax, h / legLen)
				end
			end
		end
	end
	-- 새로 들 발 고르기: 제자리에서 가장 많이 벗어난 발(두 발을 한꺼번에 들지 않는다. 기어갈 때는 대각선 둘까지)
	if not (jerk and now < b.freezeUntil) then
		local maxLift = if quad then 2 else 1
		local best: LimbStep?, bestErr = nil, 0
		for _, l in limbs do
			if not l.f.lifted then
				local want = l.home + dir * threshold * 0.9
				local err = flat(l.f.pos - want).Magnitude
				local need = if idle then 0.18 * legLen else threshold
				if err > need and err > bestErr then
					-- 같은 쪽(기어갈 때: 같은 쪽 손발)이나 반대 다리가 떠 있으면 기다린다 → 대각선 박자
					local ok = true
					for _, o in limbs do
						if o ~= l and o.f.lifted then
							if quad then
								if (o.isHand == l.isHand) or (o.side == l.side) then
									ok = false
								end
							elseif not o.isHand then
								ok = false
							end
						end
					end
					if ok then
						best, bestErr = l, err
					end
				end
			end
		end
		if best and liftedCount() < maxLift then
			local f = best.f
			local predicted = best.home + vel * stepDur
			local to = if idle then best.home else predicted + dir * threshold * 0.85
			-- 절뚝: 오른 다리는 보폭이 짧다
			if not best.isHand and best.side == 1 and S.limp > 0 then
				to = to:Lerp(best.home + vel * stepDur, S.limp * 0.5)
			end
			f.from, f.to, f.t, f.dur, f.lifted = f.pos, to, 0, stepDur * (if best.isHand then 0.85 else 1), true
		end
	end
	b.gait += speed * dt

	-- ── 골반: 높이(디딘 다리가 닿는 만큼) · 체중 이동 · 회전 ──
	local restH = b.pelvisRest.Y - b.floorY
	local wantH = restH - legLen * S.crouch
	local hipW = b.legs[1].m1.C0.Position.X
	local reachLimit = math.huge
	local planted = 0
	local lateral = 0
	local fwdDiff = 0
	for _, s in { -1, 1 } do
		local f = b.feet[s]
		local fl = rcf:PointToObjectSpace(f.pos)
		fwdDiff += -fl.Z * s
		if not f.lifted then
			planted += 1
			local L = b.legs[s]
			local reach = (L.v1.Magnitude + L.v3.Magnitude) * 0.95
			local hip = b.pelvisRest + L.m1.C0.Position
			local horiz = Vector2.new(fl.X - hip.X, fl.Z - hip.Z).Magnitude
			local maxDrop = math.sqrt(math.max(reach * reach - horiz * horiz, 0.01))
			-- 엉덩이 높이 = 발목 높이 + 닿을 수 있는 수직 거리 → 골반 높이로
			local pelvisH = (f.pos.Y - groundY) + maxDrop + (b.pelvisRest.Y - hip.Y)
			reachLimit = math.min(reachLimit, pelvisH)
			lateral += fl.X
		end
	end
	if planted > 0 then
		lateral /= planted
	end
	if idle then
		lateral = b.idleShift * math.abs(hipW) * 0.6
	end
	local height = math.min(wantH, reachLimit) - restH
	-- 꼭두각시: 줄에 매달린 듯 걸음마다 위로 당겨진다
	if jerk then
		height += legLen * 0.06 * math.abs(math.sin(b.gait / math.max(stride, 0.1) * math.pi))
	end
	local pelTarget = Vector3.new(lateral * 0.55, height, if quad then -legLen * 0.1 else 0)
	if jerk then
		local hk = "pel"
		if now >= (b.held[hk .. "t"] or 0) then
			b.held[hk .. "x"], b.held[hk .. "y"] = pelTarget.X, pelTarget.Y
			b.held[hk .. "t"] = now + 1 / 6
		end
		pelTarget = Vector3.new(b.held[hk .. "x"], b.held[hk .. "y"], pelTarget.Z)
	end
	if jerk and now < b.freezeUntil then
		pelTarget = b.pel.x
	end
	local bodyFreq = 2.2 * tension / math.sqrt(b.mass)
	vstep(b.pel, pelTarget, bodyFreq, 0.45, dt)
	-- 골반 회전: 앞으로 나간 다리 쪽으로 비틀고(yaw), 떠 있는 다리 쪽이 처지고(roll), 숙인 만큼 앞으로(pitch)
	local swingSide = 0
	for _, s in { -1, 1 } do
		if b.feet[s].lifted then
			swingSide = s
		end
	end
	local pelRotT = Vector3.new(S.lean * 0.3 + (if quad then 0.25 else 0), math.clamp(fwdDiff * 0.12, -0.35, 0.35) + yawRate * 0.05, -swingSide * 0.06 * math.clamp(speed / 4, 0, 1))
	vstep(b.pelRot, pelRotT, 2.5 * tension, 0.6, dt)

	-- ── 가슴(척추): 숙임 + 가속에 쏠림 + 골반 반대로 비틂 + 회전 방향으로 먼저 돌고 안쪽으로 기움 + 호흡 + 꿈틀 ──
	local breathe = math.sin(now * TWO_PI * 0.27) * (if idle then 0.035 else 0.012)
	local wave = S.wave * math.sin(b.gait / math.max(stride, 0.1) * math.pi)
	local chestT = Vector3.new(
		S.lean - b.pelRot.x.X + math.clamp(b.accel.Z * -0.025, -0.35, 0.35) + breathe + speed * 0.012,
		math.clamp(-b.pelRot.x.Y * 0.75 + yawRate * 0.05 + wave, -0.35, 0.35),
		-yawRate * math.clamp(speed, 0, 10) * 0.012 + wave * 0.4
	)
	if jerk and now < b.freezeUntil then
		chestT = b.chest.x
	end
	vstep(b.chest, chestT, 1.8 * tension / math.sqrt(b.mass), 0.5, dt)

	-- ── 머리: 바라볼 곳을 늦게 따라가며 몸 흔들림을 상쇄 ──
	local focusP: Vector3? = nil
	local near, nearD = nearestPlayer(pos)
	if state == "Chase" and near then
		focusP = near
	else
		local f = m:GetAttribute("Focus")
		if typeof(f) == "Vector3" and now < b.nextLook then
			focusP = f
		end
	end
	if not focusP and now >= b.nextLook then
		-- 두리번: 가끔 홱 돌리고, 가끔 천천히
		b.nextLook = now + 1.5 + (math.noise(now * 0.3, b.seed) + 0.5) * 3
		b.look = Vector2.new((math.noise(now, b.seed + 9) * 2) * 0.9, math.noise(now, b.seed + 17) * 0.4)
		b.lookFreq = if math.noise(now * 2, b.seed) > 0.2 then 6 else 1.6
	end
	local lookYaw, lookPitch = b.look.X, b.look.Y
	if focusP then
		local d = rrot:VectorToObjectSpace(focusP - (pos + Vector3.new(0, restH * 0.8, 0)))
		lookYaw = math.clamp(math.atan2(-d.X, -d.Z), -1.3, 1.3)
		lookPitch = math.clamp(math.atan2(d.Y, Vector2.new(d.X, d.Z).Magnitude), -0.8, 0.6)
	end
	if not idle and not focusP then
		lookYaw *= 0.3
		lookPitch *= 0.3
	end
	-- 머리 떨림(연속 노이즈: 무작위로 튀지 않는다)
	local tremor = (if state == "Alert" or state == "Chase" then 0.04 else 0.015)
	lookYaw += math.noise(now * 2.3, b.seed + 41) * tremor + yawRate * 0.06
	lookPitch += math.noise(now * 2.1, b.seed + 53) * tremor - S.headDrop
	vstep(b.head, Vector3.new(lookPitch, lookYaw, 0), b.lookFreq * (if jerk then 1.4 else 1), 0.7, dt)
	b.lookFreq = lerp(b.lookFreq, 2.5, math.min(1, dt * 0.5))

	-- ── 덮치기: 쫓다가 가까우면 몸을 낮추고 팔을 뒤로 모았다가(선동작) 붙으면 앞으로 뻗으며 상체를 던진다 ──
	local pounce = 0
	local wind = 0
	if state == "Chase" and near then
		wind = math.clamp((8 - nearD) / 3, 0, 1)
		pounce = math.clamp((5 - nearD) / 1.6, 0, 1)
	end

	-- ── 뼈에 적용 ──
	local pelvisCF = CFrame.new(b.pel.x + Vector3.new(0, -wind * legLen * 0.12 * (1 - pounce), 0)) * CFrame.fromEulerAnglesYXZ(b.pelRot.x.X + pounce * 0.3, b.pelRot.x.Y, b.pelRot.x.Z)
	-- 디딘 다리가 발에 닿지 않으면(돌진·숙임으로 골반이 높을 때) 골반을 그만큼 바로 내린다 → 발은 끝까지 그 자리
	do
		local wp = rcf * CFrame.new(b.pelvisRest) * pelvisCF
		local drop = 0
		for _, s in { -1, 1 } do
			local f = b.feet[s]
			if not f.lifted then
				local L = b.legs[s]
				local H = (wp * CFrame.new(L.m1.C0.Position)).Position
				local R = (L.v1.Magnitude + L.v3.Magnitude) * 0.995
				local horiz = flat(H - f.pos).Magnitude
				if horiz < R then
					drop = math.max(drop, (H.Y - f.pos.Y) - math.sqrt(R * R - horiz * horiz))
				end
			end
		end
		if drop > 0 then
			pelvisCF = CFrame.new(0, -drop, 0) * pelvisCF
			b.pel.x -= Vector3.new(0, drop, 0)
		end
	end
	b.pelvisM.Transform = pelvisCF
	local chestRot = CFrame.fromEulerAnglesYXZ(b.chest.x.X + pounce * 0.5 - wind * 0.2 * (1 - pounce), b.chest.x.Y, b.chest.x.Z)
	b.chestM.Transform = chestRot
	local wPelvis = rcf * CFrame.new(b.pelvisRest) * pelvisCF
	local wChest = wPelvis * CFrame.new(b.chestM.C0.Position) * chestRot
	-- 목·머리: 원하는 머리 월드 방향 = 몸 방향 + 바라봄. 가슴 회전을 빼서 목과 머리가 반씩 나눈다
	local headWorld = rrot * CFrame.fromEulerAnglesYXZ(b.head.x.X + pounce * -0.3, b.head.x.Y, 0)
	local rel = wChest.Rotation:Inverse() * headWorld
	local rx, ry, rz = rel:ToEulerAnglesYXZ()
	rx, ry, rz = math.clamp(rx, -1.1, 0.9), math.clamp(ry, -1.4, 1.4), math.clamp(rz, -0.5, 0.5)
	local half = CFrame.fromEulerAnglesYXZ(rx * 0.5, ry * 0.5, rz * 0.5)
	b.neckM.Transform = half
	b.headM.Transform = half
	b.stats.headLag = math.max(b.stats.headLag, math.abs(b.head.v.Y))

	-- 다리 IK(발은 월드에 고정)
	local function solveLeg(s: number)
		local L = b.legs[s]
		local f = b.feet[s]
		local H = (wPelvis * CFrame.new(L.m1.C0.Position)).Position
		local l1, l2 = L.v1.Magnitude, L.v3.Magnitude
		local pole = wPelvis.Rotation * L.pole
		local K, A = solve2(H, f.pos, l1, l2, pole)
		local pr = wPelvis.Rotation
		local t1 = fromTo(L.v1.Unit, pr:VectorToObjectSpace((K - H).Unit))
		L.m1.Transform = t1
		local r1 = pr * t1
		local t2 = fromTo(L.v3.Unit, r1:VectorToObjectSpace((A - K).Unit))
		L.m2.Transform = t2
		local r2 = r1 * t2
		-- 발: 땅에 평평하게(들 때는 발끝이 아래로)
		local footPitch = if f.lifted then -0.5 * math.sin(math.pi * f.t) else 0
		L.mEnd.Transform = r2:Inverse() * rrot * CFrame.Angles(footPitch, 0, 0)
		-- 발가락(발볼 관절): 디딜 땐 바닥에 평평, 발을 떼면 밑으로 접히고, 내딛기 직전엔 살짝 들렸다가 펴지며 닿는다
		if L.mToe then
			local toe = 0
			if f.lifted then
				local t = f.t
				toe = if t < 0.7 then -0.7 * math.sin(math.pi * 0.5 * math.min(t / 0.35, 1)) * (1 - math.max(0, t - 0.35) / 0.35) else 0.3 * math.sin(math.pi * (t - 0.7) / 0.3)
			end
			L.mToe.Transform = CFrame.Angles(toe, 0, 0)
		end
		-- (테스트) 디딘 발이 목표에서 얼마나 떨어졌나(미끄러짐)
		if not f.lifted then
			b.stats.slip = math.max(b.stats.slip, (A - f.pos).Magnitude)
		end
	end
	solveLeg(-1)
	solveLeg(1)

	-- 팔
	for _, s in { -1, 1 } do
		local A = b.arms[s]
		local st2 = b.armS[s]
		local shoulderW = wChest * CFrame.new(A.m1.C0.Position)
		local hand = b.hands[s]
		if quad and hand.planted then
			-- 기어갈 때: 손을 땅에 짚는다(위팔+가운데 마디를 한 마디로, 아래팔을 한 마디로 IK)
			local v12 = A.v1 + (A.v2 or Vector3.zero)
			local l1, l2 = v12.Magnitude, A.v3.Magnitude
			local H = shoulderW.Position
			local K, P = solve2(H, hand.pos, l1, l2, wChest.Rotation * (Vector3.zAxis * 0.6 + Vector3.xAxis * s * 0.4))
			local cr = wChest.Rotation
			local t1 = fromTo(v12.Unit, cr:VectorToObjectSpace((K - H).Unit))
			A.m1.Transform = t1
			local r = cr * t1
			if A.m3 then
				A.m2.Transform = CFrame.identity
				local t3 = fromTo(A.v3.Unit, r:VectorToObjectSpace((P - K).Unit))
				A.m3.Transform = t3
				r = r * t3
			else
				local t3 = fromTo(A.v3.Unit, r:VectorToObjectSpace((P - K).Unit))
				A.m2.Transform = t3
				r = r * t3
			end
			A.mEnd.Transform = r:Inverse() * rrot * CFrame.Angles(-0.3, 0, 0)
			-- 진자 상태를 지금 자세에 맞춰 둔다(손을 뗄 때 튀지 않게)
			st2.pitch.x, st2.pitch.v = lerp(st2.pitch.x, S.armBase, 0.1), 0
		else
			-- 진자: 다리 반대 박자로 흔들리고(반대쪽 발이 앞이면 앞으로), 몸 가속에 늦게 따라오고, 길수록 느리다
			local f1 = rcf:PointToObjectSpace(b.feet[-s].pos)
			local f2 = rcf:PointToObjectSpace(b.feet[s].pos)
			local legSwing = math.clamp((f2.Z - f1.Z) / math.max(stride, 0.5), -1, 1)
			local target = S.armBase + S.armSwing * legSwing * math.clamp(speed / 3, 0, 1)
			target += wind * -0.9 * (1 - pounce) + pounce * 1.6
			local freq = math.sqrt(GRAVITY / math.max(b.armLen, 0.5)) / TWO_PI * 0.55 * tension
			local pd = st2.pitch
			step(pd, target, freq, 0.32, dt)
			-- 관성: 몸이 앞으로 가속하면 팔은 뒤로 처진다. 골반이 오르내리면 휘둘린다
			pd.v += (b.accel.Z * 0.04 - b.pel.v.Y * 0.25 * S.flail) * dt * 6 / math.max(b.armLen / 3, 0.5)
			local rd = st2.roll
			step(rd, S.armSpread + wind * 0.25 + math.abs(yawRate) * 0.05 * s * (if yawRate * s > 0 then 1 else -0.5), freq * 1.1, 0.4, dt)
			rd.v += b.accel.X * 0.03 * s * dt * 6
			local up = CFrame.fromEulerAnglesYXZ(pd.x, 0, rd.x * s)
			A.m1.Transform = up
			-- 아래 마디: 위 마디가 움직이는 속도의 반대로 한 박자 늦게(채찍처럼) + 들어 올린 팔의 아래 마디는 중력으로 처짐
			local droop = -math.max(pd.x - 1.2, 0) * 0.35
			step(st2.c1, -pd.v * 0.06 + droop + pounce * -0.3, freq * 1.6, 0.35, dt)
			step(st2.c2, -st2.c1.v * 0.05 + droop * 0.6 + 0.08, freq * 2.2, 0.35, dt)
			step(st2.c3, -st2.c2.v * 0.04 + 0.1 + math.noise(now * 3, b.seed + s) * 0.06, freq * 3, 0.4, dt)
			if A.m3 then
				A.m2.Transform = CFrame.Angles(st2.c1.x, 0, 0)
				A.m3.Transform = CFrame.Angles(st2.c2.x, 0, 0)
			else
				A.m2.Transform = CFrame.Angles(st2.c1.x + st2.c2.x, 0, 0)
			end
			A.mEnd.Transform = CFrame.Angles(st2.c3.x, 0, 0)
		end
	end

	-- (테스트) 측정
	local st3 = b.stats
	st3.frames += 1
	st3.pelvisMin = math.min(st3.pelvisMin, b.pel.x.Y)
	st3.pelvisMax = math.max(st3.pelvisMax, b.pel.x.Y)
	st3.chestYawMax = math.max(st3.chestYawMax, math.abs(b.chest.x.Y))
	st3.leanMax = math.max(st3.leanMax, b.chest.x.X + b.pelRot.x.X)
	st3.armMax = math.max(st3.armMax, b.armS[-1].pitch.x, b.armS[1].pitch.x)
end

Anim.range = 170 -- 이 거리 안의 괴물만 움직임을 계산한다(테스트는 전부)
local function animated(m: Model): boolean
	if m:GetAttribute("Rig") ~= 2 then
		return false
	end
	local f = m:GetAttribute("Form")
	return f ~= "Disguise" and f ~= "Bursting"
end

RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 1 / 20)
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	for _, inst in CollectionService:GetTagged(Config.Tags.Monster) do
		local m = inst :: Model
		if m:IsA("Model") and m.Parent and animated(m) then
			local b = bodies[m]
			local root = m.PrimaryPart
			if root and (root.Position - camPos).Magnitude < Anim.range then
				if not b or b.root ~= root or not b.pelvisM.Parent then
					b = build(m)
					bodies[m] = b
				end
				if b then
					update(b, dt)
				end
			end
		end
	end
	for m in bodies do
		if not m.Parent then
			bodies[m] = nil
			Anim.stats[m] = nil
		end
	end
end)

-- (테스트) 측정값 요약: 움직인 괴물들 중 최대 미끄러짐, 걸음 수, 골반 오르내림 폭 등
function Anim.summary(): { [string]: number }
	local out = { bodies = 0, steps = 0, slip = 0, pelvisRange = 0, chestYaw = 0, headLag = 0, lean = 0, arm = 0, lift = 0, freezes = 0, handSteps = 0 }
	for _, st in Anim.stats do
		out.bodies += 1
		out.steps += st.steps
		out.slip = math.max(out.slip, st.slip)
		if st.pelvisMax > st.pelvisMin then
			out.pelvisRange = math.max(out.pelvisRange, st.pelvisMax - st.pelvisMin)
		end
		out.chestYaw = math.max(out.chestYaw, st.chestYawMax)
		out.headLag = math.max(out.headLag, st.headLag)
		out.lean = math.max(out.lean, st.leanMax)
		out.arm = math.max(out.arm, st.armMax)
		out.lift = math.max(out.lift, st.liftMax)
		out.freezes += st.freezes
		out.handSteps += st.handSteps
	end
	return out
end
function Anim.reset()
	for _, st in Anim.stats do
		st.steps, st.slip, st.pelvisMin, st.pelvisMax, st.chestYawMax, st.headLag, st.frames = 0, 0, math.huge, -math.huge, 0, 0, 0
		st.leanMax, st.armMax, st.liftMax, st.freezes, st.handSteps = 0, -math.huge, 0, 0, 0
	end
end

return Anim
