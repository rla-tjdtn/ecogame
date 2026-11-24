--!strict
-- 3D 챕터 괴물(Rig = 4, 메시 있음): 시안 조각 몸을 그대로 옮긴 뼈 메시의 뼈(B1..Bn)를 디자인 자세 프레임으로 움직인다.
--  · 걷기 8장 / 추격 8장(실제 이동 거리로 위상 → 미끄러지지 않음), 서 있으면 걷기 0, 쫓다가 바로 앞이면 덮침
--  · 프레임 사이·자세 사이는 부드럽게 섞는다(사원수 nlerp + 이동 lerp). 반 주기마다 걸음 소리(onStep)
-- 데이터: Shared/CreatureRigs/<id> (art/creatures/source/game/rig.js 가 만든다)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RigAnim = {}
RigAnim.onStep = nil :: ((Model, Vector3, number) -> ())?
RigAnim.stats = {} :: { [string]: { frames: number, steps: number, bones: number, err: string?, chaseMax: number? } }

-- 지금 음파에 드러나 있는가(Main 이 Reveal.active 로 채운다). 보이지 않는 동안에는 걸음 박자만 세고 뼈는 움직이지 않는다
RigAnim.visible = nil :: ((Model) -> boolean)?

type Body = {
	model: Model,
	root: BasePart,
	R: any,
	bones: { Bone },
	hip: number,
	phase: number,
	moveW: number,
	tick: number?,
	chaseW: number,
	attackW: number,
	stat: { frames: number, steps: number, bones: number, err: string?, chaseMax: number? },
}
local bodies: { [Model]: Body } = {}

local function rigData(id: string): any
	local folder = ReplicatedStorage.Shared:FindFirstChild("CreatureRigs")
	local ms = folder and folder:FindFirstChild(id)
	return if ms and ms:IsA("ModuleScript") then require(ms) :: any else nil
end

local function build(model: Model): Body?
	local root = model.PrimaryPart
	local id = model:GetAttribute("Creature")
	if not root or typeof(id) ~= "string" then
		return nil
	end
	local R = rigData(id)
	if not R then
		return nil
	end
	local bones: { Bone } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Bone") then
			local k = tonumber(string.match(d.Name, "^B(%d+)$"))
			if k then
				bones[k] = d
			end
		end
	end
	-- (웨이트가 없는 뼈는 로블록스가 가져올 때 빼므로 개수가 적을 수 있다: 있는 뼈만 움직인다)
	local n = 0
	for _ in bones do
		n += 1
	end
	if n == 0 then
		return nil -- (아직 복제되지 않음)
	end
	RigAnim.stats[id] = RigAnim.stats[id] or { frames = 0, steps = 0, bones = n }
	return {
		model = model,
		root = root,
		R = R,
		bones = bones,
		hip = (model:GetAttribute("Hip") :: number?) or 2,
		phase = math.random(),
		moveW = 0,
		chaseW = 0,
		attackW = 0,
		stat = RigAnim.stats[id],
	}
end

local function approach(cur: number, target: number, rate: number, dt: number): number
	return cur + (target - cur) * (1 - math.exp(-rate * dt))
end

-- 두 프레임(뼈 하나: qx,qy,qz,qw,tx,ty,tz)을 t 로 섞는다
local function mix(a: { number }, b: { number }, t: number, out: { number })
	local d = a[1] * b[1] + a[2] * b[2] + a[3] * b[3] + a[4] * b[4]
	local s = if d < 0 then -1 else 1
	for k = 1, 4 do
		out[k] = a[k] + (b[k] * s - a[k]) * t
	end
	for k = 5, 7 do
		out[k] = a[k] + (b[k] - a[k]) * t
	end
end
local REST = { 0, 0, 0, 1, 0, 0, 0 }
local A, B, C, D = table.create(7, 0), table.create(7, 0), table.create(7, 0), table.create(7, 0)

local function update(b: Body, dt: number)
	local R = b.R
	local v = b.root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local state = b.model:GetAttribute("State")
	local chasing = state == "Chase"
	local frozen = b.model:GetAttribute("Frozen") == true
	local near = math.huge
	local me = Players.LocalPlayer.Character
	local hrp = me and me:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		near = (hrp.Position - b.root.Position).Magnitude
	end
	b.moveW = approach(b.moveW, if frozen then 0 else math.clamp(speed / 2.5, 0, 1), 8, dt)
	b.chaseW = approach(b.chaseW, if chasing then 1 else 0, 3, dt)
	b.attackW = approach(b.attackW, if chasing and near < 6 then 1 else 0, 6, dt)
	b.stat.chaseMax = math.max(b.stat.chaseMax or 0, b.chaseW)
	local before = b.phase
	if not frozen then
		b.phase = (b.phase + speed * dt / (R.stride * 2)) % 1
	end
	if speed > 0.5 and not frozen and ((before < 0.5 and b.phase >= 0.5) or b.phase < before) then
		b.stat.steps += 1
		if RigAnim.onStep then
			RigAnim.onStep(b.model, b.root.Position + Vector3.new(0, -(b.hip + 1), 0), math.clamp(speed / 10, 0.3, 1.4))
		end
	end
	local vis = RigAnim.visible
	if vis and not vis(b.model) then
		return -- (몸이 투명하다: 걸음 소리 박자와 섞기 비율만 이어 간다 → 드러나는 순간 자세가 튀지 않는다)
	end
	-- 거리별 갱신 간격(멀면 뼈를 덜 자주): 가까이 매 프레임, 35 스터드 밖 2프레임, 70 밖 3프레임, 140 밖 멈춤
	local cam = workspace.CurrentCamera
	local dist = if cam then (cam.CFrame.Position - b.root.Position).Magnitude else 0
	local every = if dist > 140 then 0 elseif dist > 70 then 3 elseif dist > 35 then 2 else 1
	if every == 0 then
		return
	end
	b.tick = ((b.tick or 0) + 1) % every
	if b.tick ~= 0 then
		return
	end
	local n = #R.walk
	local f = b.phase * n
	local i0 = math.floor(f) % n + 1
	local i1 = i0 % n + 1
	local t = f - math.floor(f)
	local mw, cw, aw = b.moveW, b.chaseW, b.attackW
	-- 섞는 비율이 0·1 에 가까우면 그 섞기는 건너뛴다(대부분의 프레임: 걷기만, 또는 추격만)
	local E = 0.01
	local useW, useC = cw < 1 - E, cw > E
	local still = mw < 1 - E
	local WC, CC, WS, CS = R.walk, R.chase, R.walk[1], R.chase[1]
	for k, bone in pairs(b.bones) do
		local P: { number }
		if useW and useC then
			mix(WC[i0][k], WC[i1][k], t, A)
			mix(CC[i0][k], CC[i1][k], t, B)
			mix(A, B, cw, C)
			P = C
		elseif useC then
			mix(CC[i0][k], CC[i1][k], t, C)
			P = C
		else
			mix(WC[i0][k], WC[i1][k], t, C)
			P = C
		end
		if still then
			if useW and useC then
				mix(WS[k], CS[k], cw, D)
				mix(D, P, mw, A)
			else
				mix(if useC then CS[k] else WS[k], P, mw, A)
			end
			P = A
		end
		if aw > E then
			mix(P, R.attack[k] or REST, aw, B)
			P = B
		end
		local l = math.sqrt(P[1] * P[1] + P[2] * P[2] + P[3] * P[3] + P[4] * P[4])
		if l < 1e-6 then
			l = 1
		end
		bone.Transform = CFrame.new(P[5], P[6], P[7], P[1] / l, P[2] / l, P[3] / l, P[4] / l)
	end
	b.stat.frames += 1
end

local hasCache: { [Model]: { t: number, v: boolean } } = {}
function RigAnim.has(model: Model): boolean
	local b = bodies[model]
	if b and b.root == model.PrimaryPart then
		return true -- (매 프레임 자손을 훑지 않는다)
	end
	-- (메시가 없다는 답도 1초 기억: 시안 그림 괴물마다 매 프레임 재귀 검색하지 않게)
	local c = hasCache[model]
	local now = os.clock()
	if c and now - c.t < 1 then
		return c.v
	end
	local v = model:FindFirstChild("Mesh", true) ~= nil
	hasCache[model] = { t = now, v = v }
	return v
end

local failedAt: { [Model]: number } = {} -- (몸 만들기 실패: 1초 동안 다시 훑지 않는다)
function RigAnim.step(model: Model, dt: number)
	local b = bodies[model]
	if not b or b.root ~= model.PrimaryPart then
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
	local ok, err = pcall(update, b :: Body, dt)
	if not ok then
		(b :: Body).stat.err = tostring(err)
	end
end

function RigAnim.cleanup()
	for m in failedAt do
		if not m.Parent then
			failedAt[m] = nil
		end
	end
	for m in hasCache do
		if not m.Parent then
			hasCache[m] = nil
		end
	end
	for m in bodies do
		if not m.Parent then
			bodies[m] = nil
		end
	end
end

function RigAnim.reset()
	for _, st in RigAnim.stats do
		st.frames, st.steps, st.chaseMax = 0, 0, 0
	end
end

return RigAnim
