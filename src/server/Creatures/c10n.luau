--!strict
-- c10n 앞줄 손님 (10장 폐영화관 · 비인간형) — 사양서: roster/v5/ch10/c10n_spec.md (+ QA2 수정 지시 반영)
-- 뒤에서 보면 평범한 앞줄 관객 — 1초 뒤 어긋남: 목이 2스터드나 늘어나 작고 길쭉한 머리가 너무 높이 떠 있고, 귀는 뒤통수 쪽,
-- 등에는 좌석 등받이 같은 세로 누빔 솔기. 두 다리는 무릎 90° 의자 꼴로 한 덩어리로 용접돼 걷지 못한다.
-- 몸은 +Z(화면 쪽)를 보고 만들었고 루트의 앞(-Z, 진행 방향)은 늘 등 — 플레이어는 뒷모습만 본다.
-- QA2: 허리에 손(마름모 팔) 금지 → 대기 땐 어깨가 앞으로 말린 채 손목이 무릎 사이로 처짐 · 어깨는 몸에 붙은 둥근 어깨 →
--      위팔로 이어지는 외곽 · 머리는 볼링 핀이 아니라 턱선 각·가마·뒤로 붙은 귀가 있는 사람 뒤통수 · 넘기는 앉은 L 자
--      덩어리째 등받이 축으로 통째 회전(몸을 눕히지 않음) · 팔은 가늘어지는 원뿔 마디.
-- 뼈: Mass(등받이 꼭대기 = 넘기 축) → Lower(엉덩이·무릎·발목·발끝 용접 덩어리), Mass → Spine1 → Spine2 → NeckBase → NeckTop → Head,
--      NeckBase → ShoulderL/R → UpperArmL/R → ForearmL/R
-- 붉은 선: 목덜미 가로 솔기(머리 바로 밑, 뒤에서만 보임).
-- 공포 장치 「한 줄 더」: 누가 음파를 쏘면 쏜 사람 쪽으로 정확히 한 줄(3.2) 넘어온다(잡기 0.3 → 넘기 0.4 → 앉기 0.2, Vault 속성).
--   음파 없이 20초가 지나면 가장 가까운 플레이어 쪽으로 스스로 한 줄. 평지에선 팔로 끌어 2/초(기본 AI).
--   (좌석 줄 맞춤·접힌 좌석 흔적은 빠짐 — 맵 소품을 건드려야 함. 덮치기는 기본 잡기 거리로)
local Players = game:GetService("Players")
local Rig = require(script.Parent.Rig)

local M = {}
M.cfg = {
	WanderSpeed = 2,
	InvestigateSpeed = 2,
	ChaseSpeed = 3,
	AgentRadius = 1.2,
	AgentHeight = 8.6,
	CatchDistance = 2.6,
}
M.spawnLift = 2.6
M.voice = "4" -- (소리: 전용 소리 전까지 — 쿵 계열을 좌석 '탕' 대신)

local HIP = 1.5
local FLOOR = -(HIP + 1)
local ROW = 3.2
local GRIP, FLIP, LAND = 0.3, 0.4, 0.2

local function P(x: number, y: number, z: number): Vector3
	return Vector3.new(x, FLOOR + y, z)
end

function M.build(cf: CFrame): Model
	local model, root = Rig.shell("FrontRow", cf, Vector3.new(1.6, 2, 1.6))
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
	-- 하체(용접된 의자 꼴): 허벅지 판 · 정강이 · 발
	for _, s in { -1, 1 } do
		S("Lower", P(0.5 * s, 2.25, -0.25), P(0.5 * s, 2.2, 1.55)) -- 허벅지 윗면
		S("Lower", P(0.48 * s, 1.75, -0.1), P(0.46 * s, 1.75, 1.3)) -- 허벅지 아랫면
		S("Lower", P(0.46 * s, 2.15, 1.6), P(0.42 * s, 0.4, 1.7)) -- 정강이 앞
		S("Lower", P(0.44 * s, 1.7, 1.3), P(0.4 * s, 0.45, 1.4)) -- 종아리
		S("Lower", P(0.42 * s, 0.1, 1.35), P(0.42 * s, 0.08, 2.2)) -- 발
	end
	-- 몸통 3마디: 옆 외곽(좌우) + 등의 세로 누빔 솔기 3줄
	for _, s in { -1, 1 } do
		S("Spine1", P(0.62 * s, 2.3, -0.25), P(0.7 * s, 3.25, -0.35))
		S("Spine2", P(0.7 * s, 3.25, -0.35), P(0.82 * s, 4.5, -0.2))
		chain("NeckBase", { P(0.22 * s, 5.1, 0.0), P(0.8 * s, 5.0, 0.12), P(1.02 * s, 4.75, 0.35) }) -- 앞으로 말린 둥근 어깨
	end
	for _, x in { -0.38, 0.0, 0.38 } do
		S("Spine2", P(x, 2.7, -0.58), P(x * 1.05, 4.55, -0.5))
	end
	S("Spine1", P(-0.6, 2.6, -0.57), P(0.6, 2.6, -0.57)) -- 누빔 가로 솔기
	-- 긴 목 2마디(좌우 윤곽)
	for _, s in { -1, 1 } do
		S("NeckBase", P(0.2 * s, 5.05, 0.0), P(0.16 * s, 6.2, 0.1))
		S("NeckTop", P(0.16 * s, 6.2, 0.1), P(0.15 * s, 7.3, 0.22))
	end
	-- 붉은 목덜미 솔기(뒤쪽)
	chain("NeckTop", { P(-0.2, 7.25, 0.06), P(0, 7.28, 0.02), P(0.2, 7.25, 0.06) }, true)
	-- 머리: 길쭉한 사람 뒤통수 — 옆 외곽(턱선 각) + 가운데 윤곽 + 가마 고리 + 뒤로 붙은 귀
	chain("Head", { P(0, 7.35, 0.08), P(0, 8.15, -0.02), P(0, 8.6, 0.25), P(0, 8.45, 0.7), P(0, 7.65, 0.78), P(0, 7.4, 0.5) })
	for _, s in { -1, 1 } do
		chain("Head", { P(0.3 * s, 7.45, 0.12), P(0.36 * s, 8.15, 0.2), P(0.3 * s, 8.4, 0.5), P(0.26 * s, 7.55, 0.62) })
		table.insert(lines, { bone = "Head", a = P(0.36 * s, 7.85, 0.02), b = P(0.39 * s, 7.85, 0.0), r = 0.14, disc = true }) -- 귀(뒤쪽)
	end
	table.insert(lines, { bone = "Head", a = P(0, 8.5, 0.12), b = P(0, 8.53, 0.1), r = 0.09, disc = true }) -- 가마
	-- 팔: 대기 자세 = 손목이 무릎 사이로 처짐. 손가락 갈고리 2
	for _, s in { -1, 1 } do
		local n = if s < 0 then "L" else "R"
		local sh, el, wr = P(1.02 * s, 4.75, 0.35), P(1.05 * s, 3.35, 0.8), P(0.35 * s, 2.35, 1.45)
		cone("UpperArm" .. n, sh, el, 0.17, 0.11, Vector3.new(0, 0, 1))
		cone("Forearm" .. n, el, wr, 0.11, 0.07, Vector3.new(0, 1, 0))
		S("Forearm" .. n, wr, wr + Vector3.new(-0.1 * s, -0.35, 0.18))
		S("Forearm" .. n, wr, wr + Vector3.new(0.02 * s, -0.4, 0.05))
	end
	local bones: { Rig.Bone } = {
		{ name = "Mass", joint = P(0, 3.45, -0.62), tip = P(0, 1.95, -0.1) },
		{ name = "Lower", parent = "Mass", joint = P(0, 1.95, -0.1), tip = P(0, 1.95, 1.45) },
		{ name = "Spine1", parent = "Mass", joint = P(0, 2.2, -0.3), tip = P(0, 3.2, -0.32) },
		{ name = "Spine2", parent = "Spine1", joint = P(0, 3.2, -0.32), tip = P(0, 4.45, -0.22) },
		{ name = "NeckBase", parent = "Spine2", joint = P(0, 4.45, -0.22), tip = P(0, 5.2, 0) },
		{ name = "NeckTop", parent = "NeckBase", joint = P(0, 6.2, 0.1), tip = P(0, 7.3, 0.22) },
		{ name = "Head", parent = "NeckTop", joint = P(0, 7.3, 0.22), tip = P(0, 8.45, 0.45) },
	}
	for _, s in { -1, 1 } do
		local n = if s < 0 then "L" else "R"
		table.insert(bones, { name = "Shoulder" .. n, parent = "NeckBase", joint = P(0.2 * s, 5.05, 0), tip = P(1.02 * s, 4.75, 0.35) })
		table.insert(bones, { name = "UpperArm" .. n, parent = "Shoulder" .. n, joint = P(1.02 * s, 4.75, 0.35), tip = P(1.05 * s, 3.35, 0.8) })
		table.insert(bones, { name = "Forearm" .. n, parent = "UpperArm" .. n, joint = P(1.05 * s, 3.35, 0.8), tip = P(0.35 * s, 2.35, 1.45) })
	end
	Rig.build(model, root, cf, {
		id = "c10n",
		bones = bones,
		lines = lines,
		balls = balls,
		floorY = FLOOR,
		mass = 0.9,
	})
	Rig.humanoid(model, HIP, M.cfg.WanderSpeed)
	return model
end

local function vault(self: any, toward: Vector3, now: number)
	local my = self.root.Position
	local dir = Vector3.new(toward.X - my.X, 0, toward.Z - my.Z)
	if dir.Magnitude < 0.5 then
		return
	end
	local d = self.cdata
	d.vaultAt = now
	d.vaultTo = my + dir.Unit * math.min(ROW, dir.Magnitude)
	d.lastVault = now
	self.waypoints = {}
	self.root.CFrame = CFrame.lookAt(my, my + dir.Unit) -- 등(루트의 앞)을 쏜 사람 쪽으로
	self.model:SetAttribute("Vault", now)
end

function M.init(self: any)
	self.cdata.lastVault = os.clock()
end

function M.tick(self: any, now: number): boolean
	local d = self.cdata
	if d.vaultAt then
		local t = now - d.vaultAt
		if t < GRIP + FLIP + LAND then
			-- 잡기 동안은 그대로, 넘기·앉기 동안 한 줄 뒤로
			self.hum.WalkSpeed = if t < GRIP then 0 else ROW / (FLIP + LAND)
			self.hum:MoveTo(d.vaultTo)
			return true
		end
		d.vaultAt = nil
		self:setState(self.state) -- 원래 속도로
		return false
	end
	if now - d.lastVault > 20 then
		-- 음파 없이 20초: 가장 가까운 플레이어 쪽으로 스스로 한 줄
		local best: Vector3?, bd = nil, 80
		for _, p in Players:GetPlayers() do
			local char = p.Character
			local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r and p:GetAttribute("Status") == "Alive" then
				local dd = (r.Position - self.root.Position).Magnitude
				if dd < bd then
					best, bd = r.Position, dd
				end
			end
		end
		d.lastVault = now
		if best then
			vault(self, best, now)
			return true
		end
	end
	return false
end

function M.hear(self: any, pos: Vector3, _radius: number, source: Player?, kind: string): boolean
	if kind ~= "Sonar" or source == nil then
		return false
	end
	if (pos - self.root.Position).Magnitude > 90 or self.cdata.vaultAt then
		return true -- (넘는 중이거나 너무 멀면 음파는 무시)
	end
	vault(self, pos, os.clock())
	return true
end

return M
