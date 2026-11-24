--!strict
-- c5n 지움 (5장 심층 미로 · 비인간형) — 사양서: roster/v5/ch5/c5n_spec.md (+ QA2 수정 지시 반영)
-- 머리 없는 사람 몸이 가슴을 열어젖힌 채 네 손발로 통로 양벽·바닥을 버티고(굴뚝 오르기) 복도 한가운데 떠서 온다.
-- QA2: 만세(X) 자세 금지 → 팔은 어깨에서 거의 수평으로 양벽을 짚고 팔꿈치는 진행 방향으로 튀어나옴, 다리는 무릎이 벽 쪽으로
--      꺾인 낮은 버팀(가로로 넓고 납작한 H). 갈비 4쌍은 척추에서 바깥·앞으로 휘어 벌어진 갈고리(끝 뾰족), 가운데는 텅 빈 창.
--      비대칭: 왼쪽 갈비가 더 벌어지고 오른쪽 맨 아래 갈비는 꺾여 처짐. 손 = 납작 판 + 갈고리 3, 골반 = 쐐기 판 2.
-- 뼈: Sacrum → Lumbar → Thorax → NeckStump,  Thorax → RibL / RibR(갈비 벌림),  Thorax → UpperArmL/R → ForearmL/R → HandL/R,
--      Sacrum → ThighL/R → ShinL/R → FootL/R   (루트가 골반이 아니라 복도 가운데에 떠 있음)
-- 붉은 선: 열린 가슴 창의 테(닫힌 곡선 하나).
-- 공포 장치 「두 번째 음파」: 첫 음파에 맞으면 선이 하나도 안 생긴다(SonarVeil = true 동안 클라이언트가 몸을 지운다).
--   3.5초 안에 다시 맞아야 10초 동안 드러난다(SonarVeil = false, Exposed 속성). 첫 음파를 맞으면 소리 쪽으로 4초간 ×1.85.
--   (넓은 방 입구에서 멈추기·닫기 연타 탈출은 빠짐 — 기본 AI·기본 잡기 유지)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local SoundBus = require(script.Parent.Parent.SoundBus)
local Rig = require(script.Parent.Rig)

local M = {}
M.cfg = {
	WanderSpeed = 2.7,
	InvestigateSpeed = 4,
	ChaseSpeed = 5,
	AgentRadius = 1.6,
	AgentHeight = 7,
	CatchDistance = 2.5,
}
M.spawnLift = 4.2
M.voice = "3" -- (소리: 전용 소리 전까지 — 손톱 톡톡 계열을 짚는 소리로 임시)

local HIP = 3
local FLOOR = -(HIP + 1)
local BOOST = 1.85
local WINDOW = 3.5
local SHOW = 10

local function P(x: number, y: number, z: number): Vector3
	return Vector3.new(x, FLOOR + y, z)
end

function M.build(cf: CFrame): Model
	local model, root = Rig.shell("Erasure", cf, Vector3.new(1.6, 2, 1.4))
	local lines: { Rig.Line } = {}
	local balls: { Rig.Ball } = {}
	local function S(bone: string, a: Vector3, b: Vector3, red: boolean?)
		table.insert(lines, { bone = bone, a = a, b = b, r = 0.05, red = red })
	end
	local function chain(bone: string, pts: { Vector3 }, red: boolean?)
		for i = 1, #pts - 1 do
			S(bone, pts[i], pts[i + 1], red)
		end
	end
	-- 가늘어지는 원뿔 마디: 윤곽선 두 줄(밑동 wa → 끝 wb, 가운데 살짝 불룩)
	local function cone(bone: string, a: Vector3, b: Vector3, wa: number, wb: number, side: Vector3)
		local d = (b - a).Unit
		local off = (side - d * side:Dot(d)).Unit
		local m = a:Lerp(b, 0.4)
		local wm = wa * 0.6 + wb * 0.4 + 0.03
		for _, k in { -1, 1 } do
			chain(bone, { a + off * (wa * k), m + off * (wm * k), b + off * (wb * k * 0.6) })
		end
	end
	-- 손발: 벽(또는 바닥)에 붙은 납작 판(삼각) + 갈고리 3
	local function paw(bone: string, c: Vector3, n: Vector3, up: Vector3)
		local t = (up - n * up:Dot(n)).Unit
		local s = n:Cross(t)
		local a, b2, c2 = c - t * 0.25 + s * 0.3, c - t * 0.25 - s * 0.3, c + t * 0.5
		chain(bone, { a, b2, c2, a })
		for i = -1, 1 do
			local base = c + t * 0.45 + s * (0.2 * i)
			chain(bone, { base, base + t * 0.45 + s * (0.12 * i) + n * 0.12, base + t * 0.55 + s * (0.14 * i) - n * 0.05 })
		end
	end
	local sacrum, lumbar, thorax = P(0, 4.8, 0.3), P(0, 6.3, 0.62), P(0, 8.2, 0.66)
	local neck, stump = P(0, 9.75, 0.35), P(0, 10.35, 0.05)
	-- 몸통 윤곽(등이 살짝 굽은 통): 좌우 두 줄
	for _, s in { -1, 1 } do
		chain("Lumbar", { P(0.55 * s, 5.0, 0.3), P(0.62 * s, 6.3, 0.5) })
		chain("Thorax", { P(0.62 * s, 6.3, 0.5), P(0.75 * s, 8.2, 0.55), P(1.3 * s, 9.45, 0.35) })
		S("Thorax", P(0.18 * s, 9.6, 0.25), P(1.45 * s, 9.5, 0.35)) -- 쇄골
	end
	-- 척추 가운데 선(창 너머로 보이는 등 안쪽) + 잘린 목
	S("Lumbar", sacrum, lumbar)
	S("Thorax", lumbar, thorax)
	S("Thorax", thorax, neck)
	chain("NeckStump", { P(-0.3, 9.7, 0.4), P(-0.28, 10.35, 0.1) })
	chain("NeckStump", { P(0.3, 9.7, 0.4), P(0.28, 10.35, 0.1) })
	table.insert(lines, { bone = "NeckStump", a = P(0, 10.33, 0.08), b = P(0, 10.4, 0.06), r = 0.32, disc = true }) -- 잘린 단면
	-- 골반: 쐐기 판 2
	for _, s in { -1, 1 } do
		chain("Sacrum", { P(0.15 * s, 5.25, 0.35), P(1.05 * s, 5.0, 0.1), P(0.55 * s, 4.3, -0.15), P(0.15 * s, 5.25, 0.35) })
	end
	-- 붉은 창 테: 갈비 끝 안쪽을 잇는 닫힌 곡선(가운데는 비어 있음)
	local rim: { Vector3 } = {}
	for i = 0, 6 do
		local t = i / 6 * math.pi * 2
		table.insert(rim, P(math.sin(t) * 0.7, 7.75 + math.cos(t) * 1.25, -0.55 - 0.12 * math.cos(t)))
	end
	chain("Thorax", rim, true)
	-- 갈비 4쌍: 척추에서 바깥·앞으로 휘어 벌어진 갈고리(끝 뾰족). 왼쪽이 더 벌어짐, 오른쪽 맨 아래는 꺾여 처짐
	for i, y in { 8.85, 8.3, 7.75, 7.2 } do
		for _, s in { -1, 1 } do
			local bone = if s < 0 then "RibL" else "RibR"
			local open = if s < 0 then 1.3 else 1.0
			local a = P(0.25 * s, y, 0.5)
			local m = P((0.95 + 0.35 * open) * s, y - 0.12, -0.05)
			local tip = P((0.95 + 0.15 * open) * s, y - 0.45, -0.95)
			if s > 0 and i == 4 then
				m = P(1.15, y - 0.2, 0.0)
				tip = P(1.25, y - 0.95, -0.35) -- 부러져 아래로 처짐
			end
			chain(bone, { a, m, tip })
		end
	end
	-- 양옆으로 젖혀진 살가죽(갈비 바깥)
	for _, s in { -1, 1 } do
		local bone = if s < 0 then "RibL" else "RibR"
		local o = if s < 0 then 0.25 else 0
		chain(bone, { P(0.7 * s, 9.15, -0.35), P((1.9 + o) * s, 8.7, -0.15), P((2.0 + o) * s, 7.3, -0.1), P(0.8 * s, 6.75, -0.4) })
	end
	-- 팔: 어깨에서 거의 수평으로 양벽, 팔꿈치는 앞으로. 다리: 무릎이 벽 쪽으로 꺾인 낮은 버팀
	local sh = { L = P(-1.5, 9.5, 0.35), R = P(1.45, 9.45, 0.35) }
	local el = { L = P(-2.75, 9.85, -1.5), R = P(2.8, 9.55, -1.4) }
	local wr = { L = P(-3.95, 9.45, -0.55), R = P(3.95, 9.0, -0.4) }
	local hp = { L = P(-0.85, 4.75, 0.05), R = P(0.85, 4.75, 0.05) }
	local kn = { L = P(-2.7, 3.9, -1.2), R = P(2.15, 2.7, -1.0) }
	local an = { L = P(-3.95, 1.5, -0.5), R = P(2.45, 0.2, -0.6) }
	for _, n in { "L", "R" } do
		local s = if n == "L" then -1 else 1
		cone("UpperArm" .. n, sh[n], el[n], 0.24, 0.16, Vector3.new(0, 1, 0))
		cone("Forearm" .. n, el[n], wr[n], 0.17, 0.12, Vector3.new(0, 1, 0))
		paw("Hand" .. n, wr[n], Vector3.new(-s, 0, 0), Vector3.new(0, 0.5, -1))
		cone("Thigh" .. n, hp[n], kn[n], 0.3, 0.2, Vector3.new(0, 0, 1))
		cone("Shin" .. n, kn[n], an[n], 0.2, 0.13, Vector3.new(0, 0, 1))
	end
	paw("FootL", an.L, Vector3.new(1, 0, 0), Vector3.new(0, -0.3, -1)) -- 왼발 = 벽
	paw("FootR", an.R + Vector3.new(0, -0.15, 0), Vector3.new(0, 1, 0), Vector3.new(0.4, 0, -1)) -- 오른발 = 바닥 모서리
	local bones: { Rig.Bone } = {
		{ name = "Sacrum", joint = sacrum, tip = lumbar },
		{ name = "Lumbar", parent = "Sacrum", joint = sacrum + Vector3.new(0, 0.2, 0), tip = lumbar },
		{ name = "Thorax", parent = "Lumbar", joint = lumbar, tip = thorax },
		{ name = "NeckStump", parent = "Thorax", joint = neck, tip = stump },
		{ name = "RibL", parent = "Thorax", joint = P(-0.25, 8.0, 0.55), tip = P(-1.5, 8.0, -0.6) },
		{ name = "RibR", parent = "Thorax", joint = P(0.25, 8.0, 0.55), tip = P(1.3, 8.0, -0.6) },
	}
	for _, n in { "L", "R" } do
		table.insert(bones, { name = "UpperArm" .. n, parent = "Thorax", joint = sh[n], tip = el[n] })
		table.insert(bones, { name = "Forearm" .. n, parent = "UpperArm" .. n, joint = el[n], tip = wr[n] })
		table.insert(bones, { name = "Hand" .. n, parent = "Forearm" .. n, joint = wr[n], tip = wr[n] + Vector3.new(0, 0.5, -0.6) })
		table.insert(bones, { name = "Thigh" .. n, parent = "Sacrum", joint = hp[n], tip = kn[n] })
		table.insert(bones, { name = "Shin" .. n, parent = "Thigh" .. n, joint = kn[n], tip = an[n] })
		table.insert(bones, { name = "Foot" .. n, parent = "Shin" .. n, joint = an[n], tip = an[n] + Vector3.new(0, -0.1, -0.6) })
	end
	Rig.build(model, root, cf, {
		id = "c5n",
		bones = bones,
		lines = lines,
		balls = balls,
		floorY = FLOOR,
		mass = 0.7,
	})
	Rig.humanoid(model, HIP, M.cfg.WanderSpeed)
	model:SetAttribute("SonarVeil", true) -- (클라이언트: true 면 음파에 드러나도 몸을 지운다)
	return model
end

function M.init(self: any)
	self.cdata.lastHit = nil
	self.cdata.boostUntil = 0
	self.cdata.exposedUntil = 0
end

function M.tick(self: any, now: number): boolean
	local d = self.cdata
	if d.exposedUntil > 0 and now > d.exposedUntil then
		d.exposedUntil = 0
		self.model:SetAttribute("SonarVeil", true)
	end
	if now < d.boostUntil then
		local base = if self.state == "Chase" then M.cfg.ChaseSpeed elseif self.state == "Wander" then M.cfg.WanderSpeed else M.cfg.InvestigateSpeed
		self.hum.WalkSpeed = base * BOOST
		d.boosted = true
	elseif d.boosted then
		d.boosted = false
		self:setState(self.state) -- 원래 상태 속도로
	end
	return false
end

-- 음파에 맞았는가(클라이언트 Reveal 과 같은 기준: 반경 + 3 안, 벽 1장 이하)
function M.hear(self: any, pos: Vector3, _radius: number, _source: Player?, kind: string): boolean
	if kind ~= "Sonar" then
		return false
	end
	local my = self.root.Position
	if (pos - my).Magnitude > Config.Sonar.Radius + 3 or SoundBus.wallsBetween(pos, my) > 1 then
		return false
	end
	local d = self.cdata
	local now = os.clock()
	if d.lastHit and now - d.lastHit <= WINDOW then
		-- 두 번째 음파: 10초 동안 드러남
		d.exposedUntil = now + SHOW
		self.model:SetAttribute("SonarVeil", false)
		self.model:SetAttribute("Exposed", now)
	elseif d.exposedUntil == 0 then
		-- 첫 음파: 보이지 않은 채 소리 쪽으로 몸을 틀고 4초간 빨라짐
		self.model:SetAttribute("Veil", now)
		d.boostUntil = now + 4
	end
	d.lastHit = now
	return false -- (소리 쪽 조사는 기본 AI 가)
end

return M
