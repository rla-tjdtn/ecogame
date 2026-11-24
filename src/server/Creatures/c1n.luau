--!strict
-- c1n 청음체 (1장 지하 시설 · 비인간형) — 사양서: art/creatures/sheets/ch1/c1n_spec.md (+ QA1 수정 지시 반영)
-- "소리를 더 잘 듣는 몸": 낮게 웅크린 등, S자로 앞으로 내민 목 끝에 한쪽이 찢겨 열린 갈비 깔때기(귀), 그 안에 고막.
-- 3차(최신): 장대 위 새장·세 다리 의자 구성 폐기 — c1n3.js 의 목·깔때기 점을 그대로 옮김. 갈비는 뾰족한 갈고리.
-- 다리는 사람 팔 셋(손바닥으로 딛음) — 하나를 들어 바깥으로 크게 돌려 딛으며 몸통이 도는 회전 삼각 보행.
-- QA1: 우산·파라솔 금지 → 갈비 끝이 앞·아래로 말린 깔때기(조개) — 정면에서 벌어진 구멍 · 갈비 14 → 9, 길이·곡률 제각각,
--      비대칭(왼쪽 2개 결손, 오른쪽 R5 크게 부러져 처짐) · 채운 막 대신 막 테두리 한 줄 + 붉은 세로 틈 고막 ·
--      다리는 '팔'로: 팔꿈치가 바깥으로 꺾이고 손목을 젖혀 손바닥 전체로 딛음 · 퇴화한 팔은 하나만(목뼈를 감아쥠).
-- 뼈: Hub → HipA/B/C → ArmA/B/C → ForeA/B/C → HandA/B/C,  Hub → Neck1 → Neck2 → Neck3 → Dish → Ear(고막), Dish → RibL / RibR,
--      Neck1 → Vest → VestFore(목뼈를 쥔 퇴화한 팔)
-- 붉은 선: 고막(세로로 찢어진 틈 모양 고리 하나).
-- 공포 장치 「겨누는 접시」: 발소리는 못 듣는다(걸음 소리 무시). 40 안의 음파 → 0.8초에 접시를 그쪽으로 겨누고 4초 동안 '듣는 중'
--   (제자리, Listening 속성 + AimAt). 이때 접시 정면 ±35° 안에서 또 쏘면 위치 확정 → 추격, 3 안에서 돌진(22).
--   옆·뒤에서 쏜 음파는 안전(무시).
local Rig = require(script.Parent.Rig)

local M = {}
M.cfg = {
	WanderSpeed = 6,
	InvestigateSpeed = 8,
	ChaseSpeed = 12,
	AgentRadius = 1.6,
	AgentHeight = 4,
	CatchDistance = 2.8,
}
M.spawnLift = 2.8
M.voice = "3" -- (소리: 전용 소리 전까지 — 손바닥 짚는 톡톡 계열)

local HIP = 1.6
local FLOOR = -(HIP + 1)
local HUB = 2.1
local LISTEN = 4.8 -- 겨눔 0.8 + 듣기 4
local CONE = math.cos(math.rad(35))
M.legs = { A = 60, B = -60, C = 180 } -- 다리 방향(도, 0 = 앞 −Z, + = 오른쪽)

local function P(x: number, y: number, z: number): Vector3
	return Vector3.new(x, FLOOR + y, z)
end
local function dir(deg: number): Vector3
	local t = math.rad(deg)
	return Vector3.new(math.sin(t), 0, -math.cos(t))
end

function M.build(cf: CFrame): Model
	local model, root = Rig.shell("Listener", cf, Vector3.new(1.6, 2, 1.6))
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
	local function cone(bone: string, a: Vector3, b: Vector3, wa: number, wb: number, side: Vector3)
		local d = (b - a).Unit
		local off = (side - d * side:Dot(d)).Unit
		for _, k in { -1, 1 } do
			S(bone, a + off * (wa * k), b + off * (wb * k))
		end
	end
	local hub = P(0, HUB, 0)
	-- 낮게 웅크린 등(3차: 장대·의자 구성 폐기): 등 가시 능선 + 양옆 윤곽 + 엉치 쐐기 + 장골 날개
	chain("Hub", { P(0, 2.2, 1.2), P(0, 2.72, 0.65), P(0, 2.82, 0.1), P(0, 2.5, -0.35) })
	for _, s in { -1, 1 } do
		chain("Hub", { P(0.4 * s, 1.8, 1.15), P(0.5 * s, 2.25, 0.6), P(0.55 * s, 2.3, 0), P(0.4 * s, 2.1, -0.4) })
		chain("Hub", { P(0.25 * s, 2.0, 0.9), P(0.62 * s, 1.95, 1.2), P(0.5 * s, 1.65, 1.5) })
	end
	chain("Hub", { P(0, 2.0, 1.25), P(0, 2.05, 1.65), P(0, 1.65, 1.6) })
	local bones: { Rig.Bone } = {
		{ name = "Hub", joint = hub, tip = hub + Vector3.new(0, 0.8, 0) },
	}
	-- 다리 셋 = 사람 팔: 위팔은 바깥·위로(팔꿈치가 무릎처럼 솟음), 아래팔은 거의 수직, 손목을 젖혀 손바닥 전체로 딛음
	for name, deg in M.legs do
		local u = dir(deg)
		local side = Vector3.yAxis:Cross(u)
		local sh = hub + u * 0.45
		local el = P(0, 2.75, 0) + u * 1.35 + side * 0.2 -- 팔꿈치가 무릎처럼 솟고 옆으로 비틀림
		local wr = P(0, 0.35, 0) + u * 1.95
		cone("Arm" .. name, sh, el, 0.2, 0.14, side)
		cone("Fore" .. name, el, wr, 0.14, 0.09, side)
		-- 손바닥 판(바깥으로 젖힘) + 손가락 3(마디가 솟음)
		local palm = wr + u * 0.45 + Vector3.new(0, -0.3, 0)
		chain("Hand" .. name, { wr + side * 0.2, palm + side * 0.25, palm - side * 0.25, wr - side * 0.2 })
		for i = -1, 1 do
			local f0 = palm + side * (0.2 * i)
			local f1 = f0 + u * 0.3 + side * (0.08 * i) + Vector3.new(0, 0.15, 0)
			chain("Hand" .. name, { f0, f1, f1 + u * 0.3 + side * (0.05 * i) + Vector3.new(0, -0.16, 0) })
		end
		table.insert(bones, { name = "Hip" .. name, parent = "Hub", joint = hub, tip = sh })
		table.insert(bones, { name = "Arm" .. name, parent = "Hip" .. name, joint = sh, tip = el })
		table.insert(bones, { name = "Fore" .. name, parent = "Arm" .. name, joint = el, tip = wr })
		table.insert(bones, { name = "Hand" .. name, parent = "Fore" .. name, joint = wr, tip = palm })
	end
	-- S자 목(앞으로 내밀어 숙임): 마디마다 양옆 윤곽 + 가시돌기
	S("Neck1", P(-0.23, 2.15, -0.3), P(-0.21, 2.62, -0.72))
	S("Neck1", P(0.23, 2.15, -0.3), P(0.21, 2.62, -0.72))
	S("Neck2", P(-0.21, 2.62, -0.72), P(-0.19, 2.62, -1.22))
	S("Neck2", P(0.21, 2.62, -0.72), P(0.19, 2.62, -1.22))
	S("Neck3", P(-0.19, 2.62, -1.22), P(-0.17, 2.22, -1.58))
	S("Neck3", P(0.19, 2.62, -1.22), P(0.17, 2.22, -1.58))
	S("Neck3", P(-0.17, 2.22, -1.58), P(-0.16, 1.72, -1.72))
	S("Neck3", P(0.17, 2.22, -1.58), P(0.16, 1.72, -1.72))
	S("Neck2", P(0, 2.8, -0.72), P(0, 3.04, -0.62))
	S("Neck3", P(0, 2.8, -1.22), P(0, 3.04, -1.12))
	-- 깔때기(귀): 한쪽이 찢겨 열린 C자 테두리 → 찢긴 쪽은 꼭지까지 파임
	chain("Dish", { P(0, 1.72, -1.72), P(-0.61, 0.9, -3.04), P(-0.9, 1.41, -3.15), P(-0.69, 2.23, -3.33), P(0.03, 2.57, -3.41), P(0.93, 2.11, -3.31), P(1.06, 1.36, -3.14), P(0.67, 0.8, -3.02), P(0, 1.72, -1.72) })
	-- 갈비 9: 끝은 뾰족한 갈고리, 안쪽 골은 하나 걸러. 왼·오른 묶음(RibL/RibR)이 벌어지고 오므림
	chain("RibR", { P(0.02, 2.05, -2.26), P(0.24, 2.56, -3.4), P(0.48, 2.59, -3.58), P(0.64, 2.36, -3.62) })
	chain("RibR", { P(0.87, 2.2, -3.32), P(1.07, 2.1, -3.45), P(1.08, 1.86, -3.47) })
	chain("RibR", { P(0.4, 1.74, -2.19), P(1.09, 1.57, -3.19), P(1.19, 1.4, -3.27), P(1.09, 1.24, -3.3) })
	chain("RibR", { P(0.86, 0.97, -3.05), P(0.86, 0.81, -3.12), P(0.73, 0.75, -3.15) })
	chain("RibR", { P(0.12, 1.42, -2.25), P(0.13, 1.25, -2.7) })
	chain("RibL", { P(-0.44, 2.43, -3.38), P(-0.29, 2.57, -3.57), P(-0.05, 2.48, -3.63) })
	chain("RibL", { P(-0.34, 1.75, -2.19), P(-0.88, 1.9, -3.26), P(-0.87, 2.06, -3.43), P(-0.67, 2.12, -3.52) })
	chain("RibL", { P(-0.87, 1.29, -3.13), P(-0.96, 1.39, -3.25), P(-0.87, 1.51, -3.33) })
	chain("RibL", { P(-0.18, 1.41, -2.12), P(-0.59, 0.89, -3.04), P(-0.71, 0.91, -3.13), P(-0.71, 1.03, -3.2) })
	-- 붉은 고막: 세로로 찢긴 틈
	chain("Ear", { P(0, 1.92, -2.19), P(0.05, 1.76, -2.16), P(-0.03, 1.64, -2.13), P(0.04, 1.5, -2.1), P(0, 1.34, -2.07), P(-0.05, 1.56, -2.12), P(0, 1.92, -2.19) }, true)
	-- 퇴화한 팔 하나: 매듭 옆에서 올라와 손가락이 목뼈를 감아쥠
	local ve0, ve1, ve2 = P(-0.35, 2.0, -0.4), P(-0.55, 2.3, -0.75), P(-0.2, 2.62, -0.95)
	S("Vest", ve0, ve1)
	S("VestFore", ve1, ve2)
	for _, k in { -1, 0, 1 } do
		S("VestFore", ve2 + Vector3.new(0, 0.12 * k, 0), ve2 + Vector3.new(0.3, 0.12 * k - 0.05, -0.2))
	end
	for _, bdef in {
		{ name = "Neck1", parent = "Hub", joint = P(0, 2.1, 0), tip = P(0, 2.62, -0.72) }, -- (몸통 회전축에서 되돌려야 목이 늘 앞을 봄)
		{ name = "Neck2", parent = "Neck1", joint = P(0, 2.62, -0.72), tip = P(0, 2.62, -1.22) },
		{ name = "Neck3", parent = "Neck2", joint = P(0, 2.62, -1.22), tip = P(0, 1.72, -1.72) },
		{ name = "Dish", parent = "Neck3", joint = P(0, 1.72, -1.72), tip = P(0, 1.44, -2.99) },
		{ name = "Ear", parent = "Dish", joint = P(-0.03, 1.64, -2.13), tip = P(0, 1.92, -2.19) },
		{ name = "RibL", parent = "Dish", joint = P(0, 1.72, -1.72), tip = P(-0.93, 1.56, -3.18) },
		{ name = "RibR", parent = "Dish", joint = P(0, 1.72, -1.72), tip = P(0.93, 1.56, -3.18) },
		{ name = "Vest", parent = "Neck1", joint = ve0, tip = ve1 },
		{ name = "VestFore", parent = "Vest", joint = ve1, tip = ve2 },
	} :: { Rig.Bone } do
		table.insert(bones, bdef)
	end
	Rig.build(model, root, cf, {
		id = "c1n",
		bones = bones,
		lines = lines,
		balls = balls,
		floorY = FLOOR,
		mass = 0.8,
	})
	Rig.humanoid(model, HIP, M.cfg.WanderSpeed)
	return model
end

function M.init(self: any)
	self.cdata.listenUntil = 0
	self.model:SetAttribute("Listening", false)
end

function M.tick(self: any, now: number): boolean
	local d = self.cdata
	if d.listenUntil > 0 then
		if now < d.listenUntil and self.state ~= "Chase" then
			self.hum:MoveTo(self.root.Position) -- 듣는 동안 제자리
			return true
		end
		d.listenUntil = 0
		self.model:SetAttribute("Listening", false)
	end
	if self.state == "Chase" then
		local t: Player? = self.target
		local char = t and t.Character
		local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local close = r ~= nil and (r.Position - self.root.Position).Magnitude < 4
		local want = if close then 22 else M.cfg.ChaseSpeed -- 마지막 3 스터드 돌진
		if self.hum.WalkSpeed ~= want then
			self.hum.WalkSpeed = want
		end
	end
	return false
end

function M.hear(self: any, pos: Vector3, _radius: number, source: Player?, kind: string): boolean
	if string.sub(kind, 1, 4) == "Step" then
		return true -- 걸음 소리는 못 듣는다
	end
	if kind ~= "Sonar" then
		return false
	end
	local my = self.root.Position
	local to = Vector3.new(pos.X - my.X, 0, pos.Z - my.Z)
	if to.Magnitude > 40 then
		return false
	end
	local d = self.cdata
	local now = os.clock()
	if d.listenUntil > 0 and now < d.listenUntil then
		-- 듣는 중: 접시 정면 ±35° 안에서 다시 쏘면 들킴
		if source and to.Magnitude > 0.5 and d.aimDir and to.Unit:Dot(d.aimDir) >= CONE then
			d.listenUntil = 0
			self.model:SetAttribute("Listening", false)
			self:startChase(source, pos)
		end
		return true
	end
	if self.state == "Chase" then
		return false
	end
	d.aimDir = if to.Magnitude > 0.5 then to.Unit else self.root.CFrame.LookVector
	d.listenUntil = now + LISTEN
	self.model:SetAttribute("AimAt", pos)
	self.model:SetAttribute("Listening", true)
	return true
end

return M
