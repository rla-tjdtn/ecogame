--!strict
-- 스테이지별 소품 타일(창고 선반·컨테이너, 하수도 수로·대형 배관, 병원 침대·책상·수술대·캐비닛).
-- 각 함수는 StageBuilder 의 ctx 와 타일 좌표(i, j)를 받는다. 모두 MapKit 부품만 쓴다.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.MapKit)
local PM = require(script.Parent.PropMesh)

local Props = {}

local function base(ctx, i: number, j: number): Vector3
	return ctx.center(i, j) + Vector3.new(0, ctx.floorY(i, j), 0)
end

-- 타일에서 가장 가까운 벽 방향(없으면 nil)
local function wallSide(ctx, i: number, j: number): Vector3?
	for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		if ctx.isWall(i + d[1], j + d[2]) then
			return Vector3.new(d[1], 0, d[2])
		end
	end
	return nil
end

local function emitter(parent: Instance, pos: Vector3, sound: string)
	local em = Kit.box(parent, CFrame.new(pos), Vector3.new(0.2, 0.2, 0.2), { invisible = true, collide = false, tag = false })
	em.CanQuery = false
	em:SetAttribute("Sound", sound)
	CollectionService:AddTag(em, Config.Tags.AmbientEmitter)
end

-- ── 창고 ──
-- 대형 선반(랙): 기둥 + 3단 가로보 + 선반판 + 상자. axis = 선반이 뻗는 방향
local function rack(ctx, i: number, j: number, axis: Vector3)
	local p = base(ctx, i, j)
	local across = Vector3.new(axis.Z, 0, -axis.X)
	local len, depth, height = ctx.T - 0.4, 2.4, 10
	local m = Instance.new("Model")
	m.Name = "Rack"
	m.Parent = ctx.props
	-- (선반 창고는 음파 선이 아주 많아지는 곳이라 꼭 필요한 모서리만: 기둥은 세로선, 보·판은 긴 선만)
	for _, a in { -1, 1 } do
		for _, b in { -1, 1 } do
			local c = p + axis * (a * (len / 2 - 0.15)) + across * (b * (depth / 2 - 0.15))
			Kit.box(m, CFrame.lookAt(c + Vector3.new(0, height / 2, 0), c + Vector3.new(0, height / 2, 0) + axis), Vector3.new(0.3, height, 0.3), { blocks = false, axis = "Y" })
		end
	end
	for k, y in { 0.4, 3.6, 6.8, 9.8 } do
		for _, b in { -1, 1 } do
			local c = p + across * (b * (depth / 2 - 0.15)) + Vector3.new(0, y, 0)
			Kit.box(m, CFrame.lookAt(c, c + axis), Vector3.new(0.25, 0.4, len), { blocks = false, axis = "Z" })
		end
		local deck = p + Vector3.new(0, y + 0.25, 0)
		-- 선반 판은 선을 그리지 않는다(양옆 보가 이미 선반 모양을 보여 준다)
		Kit.box(m, CFrame.lookAt(deck, deck + axis), Vector3.new(depth - 0.3, 0.12, len - 0.3), { blocks = false, collide = k == 1, shape = "None" })
		-- 상자들(층마다 위치를 바꿔서)
		if k < 3 then
			local h = ctx.hash(i * 3 + k, j, 5)
			local n = 1
			for q = 1, n do
				local off = (q - (n + 1) / 2) * 2.3 + (h - 0.5) * 0.8
				local sz = Vector3.new(1.6 + h * 0.6, 1.4 + ((q * 7 + k) % 3) * 0.4, 1.7)
				local bp = deck + axis * off + Vector3.new(0, 0.06, 0)
				local cf = CFrame.lookAt(bp + Vector3.new(0, sz.Y / 2, 0), bp + Vector3.new(0, sz.Y / 2, 0) + axis) * CFrame.Angles(0, (h - 0.5) * 0.3, 0)
				Kit.box(m, cf, Vector3.new(sz.Z, sz.Y, sz.X), { blocks = false })
			end
		end
	end
	-- 보이지 않는 충돌(선반 사이로 들어가지 않게)
	Kit.box(m, CFrame.lookAt(p + Vector3.new(0, 1.5, 0), p + Vector3.new(0, 1.5, 0) + axis), Vector3.new(depth, 3, len), { invisible = true, tag = false })
	PM.dress(m, "Props.Rack", CFrame.lookAt(p, p + axis)) -- (소품 좌표: 바닥 가운데, -Z = 선반이 뻗는 방향)
end
function Props.RackX(ctx, i, j)
	rack(ctx, i, j, Vector3.new(1, 0, 0))
end
function Props.RackZ(ctx, i, j)
	rack(ctx, i, j, Vector3.new(0, 0, 1))
end

-- 컨테이너: 골판 리브 + 한쪽 끝 문짝과 잠금 막대. stacked 면 두 단
function Props.Container(ctx, i: number, j: number, stacked: boolean?)
	local p = base(ctx, i, j)
	local axis = if ctx.hash(i, j, 9) < 0.5 then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
	local across = Vector3.new(axis.Z, 0, -axis.X)
	local len, w, h = 7.4, 6.2, 6.4
	local levels = if stacked then 2 else 1
	for lv = 0, levels - 1 do
		local y0 = lv * (h + 0.05)
		local c = p + Vector3.new(0, y0 + h / 2, 0)
		local m = Instance.new("Model")
		m.Name = "Container"
		m.Parent = ctx.props
		Kit.box(m, CFrame.lookAt(c, c + axis), Vector3.new(w, h, len))
		-- 옆면 세로 리브
		for k = -3, 3 do
			for _, s in { -1, 1 } do
				local rp = c + axis * (k * 1.0) + across * (s * (w / 2 + 0.06))
				Kit.box(m, CFrame.lookAt(rp, rp + axis), Vector3.new(0.12, h - 0.6, 0.35), { blocks = false, collide = false })
			end
		end
		-- 문 쪽(앞) 잠금 막대
		local front = c + axis * (len / 2 + 0.12)
		for _, s in { -1.6, -0.6, 0.6, 1.6 } do
			local a = front + across * s - Vector3.new(0, h / 2 - 0.3, 0)
			Kit.cylinder(m, a, a + Vector3.new(0, h - 0.6, 0), 0.09, { blocks = false, collide = false })
		end
		Kit.box(m, CFrame.lookAt(front, front + axis), Vector3.new(0.12, h - 0.4, 0.08), { blocks = false, collide = false })
		PM.dress(m, "Props.Container", CFrame.lookAt(p + Vector3.new(0, y0, 0), p + Vector3.new(0, y0, 0) + axis)) -- (-Z = 문 쪽)
	end
end
function Props.ContainerStack(ctx, i, j)
	Props.Container(ctx, i, j, true)
end

-- ── 하수도 ──
-- 수로: 아래층 바닥 위 얕은 물(선 없음, 걸어서 지나갈 수 있음) + 물소리
function Props.Water(ctx, i: number, j: number)
	local c = ctx.center(i, j)
	local s = Kit.box(ctx.props, CFrame.new(c + Vector3.new(0, ctx.PIT_Y + 0.6, 0)), Vector3.new(ctx.T, 1.2, ctx.T), { collide = false, shape = "None", blocks = false })
	s.CanQuery = false
	if (i + j) % 3 == 0 then
		emitter(ctx.props, c + Vector3.new(0, ctx.PIT_Y + 1, 0), "AmbientWater")
	end
end

-- 대형 배관(머리 위, 타일을 가로지른다)
function Props.BigPipe(ctx, i: number, j: number)
	local old = {}
	for _, x in ctx.props:GetChildren() do
		old[x] = true
	end
	local c = ctx.center(i, j)
	local axis = Vector3.new(1, 0, 0)
	if ctx.isWall(i - 1, j) and ctx.isWall(i + 1, j) then
		axis = Vector3.new(0, 0, 1)
	end
	local y = ctx.floorY(i, j) + 11 -- (가로대 밑이 8.9 — 괴물(키 8)도 밑으로 지나간다)
	local a = c - axis * (ctx.T / 2) + Vector3.new(0, y, 0)
	local b = c + axis * (ctx.T / 2) + Vector3.new(0, y, 0)
	Kit.pipe(ctx.props, a, b, 1.7, { 0 }, true)
	-- 받침(바닥까지 내려오는 H 프레임)
	local across = Vector3.new(axis.Z, 0, -axis.X)
	for _, s in { -1, 1 } do
		local leg = c + across * (s * 2.4) + Vector3.new(0, ctx.floorY(i, j) + (y - 1.7) / 2, 0)
		Kit.box(ctx.props, CFrame.new(leg), Vector3.new(0.4, y - 1.7, 0.4), { blocks = false })
	end
	local cross = c + Vector3.new(0, ctx.floorY(i, j) + y - 1.9, 0)
	Kit.box(ctx.props, CFrame.lookAt(cross, cross + axis), Vector3.new(5.2, 0.4, 0.5), { blocks = false })
	-- (부품이 ctx.props 에 바로 들어간다: 이번에 생긴 배관 모델 + 받침 파트를 모아 배관 모델에 한 번 입힌다)
	local pipeModel: Instance? = nil
	local made = {}
	for _, x in ctx.props:GetChildren() do
		if not old[x] then
			if x:IsA("BasePart") then
				table.insert(made, x)
			else
				pipeModel = x
				for _, d in x:GetDescendants() do
					if d:IsA("BasePart") then
						table.insert(made, d)
					end
				end
			end
		end
	end
	if pipeModel then
		local f = c + Vector3.new(0, ctx.floorY(i, j), 0)
		PM.dress(pipeModel, "Props.BigPipe", CFrame.lookAt(f, f + axis), nil, made) -- (바닥 가운데, -Z = 배관 방향)
	end
end

-- ── 병원 ──
-- 침대: 벽에 머리를 붙인 철제 침대(다리, 매트리스, 머리판, 난간)
function Props.Bed(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j) or Vector3.new(0, 0, -1)
	local head = p + side * (ctx.T / 2 - 0.4)
	local foot = head - side * 6.6
	local across = Vector3.new(side.Z, 0, -side.X)
	local mid = (head + foot) / 2
	local m = Instance.new("Model")
	m.Name = "Bed"
	m.Parent = ctx.props
	Kit.box(m, CFrame.lookAt(mid + Vector3.new(0, 2.0, 0), mid + Vector3.new(0, 2.0, 0) + side), Vector3.new(3.0, 0.7, 6.2), { blocks = false })
	Kit.box(m, CFrame.lookAt(mid + Vector3.new(0, 1.5, 0), mid + Vector3.new(0, 1.5, 0) + side), Vector3.new(3.2, 0.25, 6.4), { blocks = false })
	for _, e in { head, foot } do
		for _, s in { -1, 1 } do
			local leg = e + across * (s * 1.5) - side * (if e == head then 0.15 else -0.15)
			Kit.cylinder(m, leg, leg + Vector3.new(0, if e == head then 3.6 else 2.8, 0), 0.1, { blocks = false })
		end
	end
	local hb = head - side * 0.15 + Vector3.new(0, 2.9, 0)
	Kit.box(m, CFrame.lookAt(hb, hb + side), Vector3.new(3.0, 1.2, 0.12), { blocks = false })
	local fb = foot + side * 0.15 + Vector3.new(0, 2.45, 0)
	Kit.box(m, CFrame.lookAt(fb, fb + side), Vector3.new(3.0, 0.7, 0.12), { blocks = false })
	for _, s in { -1, 1 } do
		local a = head - side * 1.2 + across * (s * 1.65) + Vector3.new(0, 2.8, 0)
		Kit.cylinder(m, a, a - side * 3.2, 0.06, { blocks = false, collide = false })
	end
	Kit.box(m, CFrame.lookAt(mid + Vector3.new(0, 1.5, 0), mid + Vector3.new(0, 1.5, 0) + side), Vector3.new(3.2, 3, 6.4), { invisible = true, tag = false })
	PM.dress(m, "Props.Bed", CFrame.lookAt(mid, mid + side)) -- (-Z = 머리 쪽 벽)
end

-- 책상 + 의자
function Props.Desk(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local yaw = ctx.hash(i, j, 3) * 0.6 - 0.3
	local cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
	local m = Instance.new("Model")
	m.Name = "Desk"
	m.Parent = ctx.props
	Kit.box(m, cf * CFrame.new(0, 3.1, 0), Vector3.new(4.6, 0.2, 2.4), { blocks = false })
	for _, x in { -2.1, 2.1 } do
		for _, z in { -1.0, 1.0 } do
			Kit.box(m, cf * CFrame.new(x, 1.5, z), Vector3.new(0.2, 3.0, 0.2), { blocks = false })
		end
	end
	Kit.box(m, cf * CFrame.new(1.4, 2.2, 0), Vector3.new(1.4, 1.5, 2.0), { blocks = false })
	-- 의자
	local ch = cf * CFrame.new(-0.6, 0, 2.2) * CFrame.Angles(0, 0.4, 0)
	Kit.box(m, ch * CFrame.new(0, 1.8, 0), Vector3.new(1.6, 0.18, 1.6), { blocks = false })
	Kit.box(m, ch * CFrame.new(0, 2.8, 0.75), Vector3.new(1.6, 1.8, 0.15), { blocks = false })
	for _, x in { -0.7, 0.7 } do
		for _, z in { -0.7, 0.7 } do
			Kit.box(m, ch * CFrame.new(x, 0.9, z), Vector3.new(0.12, 1.8, 0.12), { blocks = false })
		end
	end
	Kit.box(m, cf * CFrame.new(0, 1.5, 0), Vector3.new(4.6, 3, 2.4), { invisible = true, tag = false })
	PM.dress(m, "Props.Desk", cf)
end

-- 수술대 + 천장 원형 조명(꺼진) + 기구 카트
function Props.Surgery(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = Instance.new("Model")
	m.Name = "Surgery"
	m.Parent = ctx.props
	Kit.box(m, CFrame.new(p + Vector3.new(0, 3.0, 0)), Vector3.new(2.4, 0.4, 6.0), { blocks = false })
	Kit.cylinder(m, p + Vector3.new(0, 0, 0), p + Vector3.new(0, 2.8, 0), 0.45, { blocks = false })
	Kit.box(m, CFrame.new(p + Vector3.new(0, 0.15, 0)), Vector3.new(2.2, 0.3, 2.8), { blocks = false })
	local lamp = p + Vector3.new(0, ctx.H - ctx.floorY(i, j) - 4.2, 0)
	Kit.cylinder(m, lamp + Vector3.new(0, 4.2, 0), lamp + Vector3.new(0, 1.0, 0), 0.12, { blocks = false, collide = false })
	Kit.cylinder(m, lamp, lamp + Vector3.new(0, 1.0, 0), 1.6, { blocks = false, collide = false })
	Kit.cylinder(m, lamp + Vector3.new(2.6, 0.2, 1), lamp + Vector3.new(2.6, 0.9, 1), 0.9, { blocks = false, collide = false })
	Kit.cylinder(m, lamp + Vector3.new(0, 1.0, 0), lamp + Vector3.new(2.6, 0.9, 1), 0.1, { blocks = false, collide = false })
	local cart = p + Vector3.new(3.0, 0, -2.0)
	Kit.box(m, CFrame.new(cart + Vector3.new(0, 2.6, 0)), Vector3.new(1.4, 0.15, 2.0), { blocks = false })
	Kit.box(m, CFrame.new(cart + Vector3.new(0, 1.2, 0)), Vector3.new(1.4, 0.15, 2.0), { blocks = false })
	for _, x in { -0.6, 0.6 } do
		for _, z in { -0.9, 0.9 } do
			Kit.cylinder(m, cart + Vector3.new(x, 0, z), cart + Vector3.new(x, 2.6, z), 0.06, { blocks = false })
		end
	end
	Kit.box(m, CFrame.new(p + Vector3.new(0, 1.5, 0)), Vector3.new(2.4, 3, 6), { invisible = true, tag = false })
	PM.dress(m, "Props.Surgery", CFrame.new(p))
end

-- 캐비닛(벽에 붙은 키 큰 수납장)
function Props.Cabinet(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j) or Vector3.new(1, 0, 0)
	local c = p + side * (ctx.T / 2 - 1.0) + Vector3.new(0, 3.5, 0)
	local m = Instance.new("Model")
	m.Name = "Cabinet"
	m.Parent = ctx.props
	Kit.box(m, CFrame.lookAt(c, c - side), Vector3.new(3.6, 7, 1.8))
	local face = c - side * 0.95
	Kit.box(m, CFrame.lookAt(face, face - side), Vector3.new(0.08, 6.4, 0.1), { blocks = false, collide = false })
	Kit.box(m, CFrame.lookAt(face + Vector3.new(0, 0.6, 0), face + Vector3.new(0, 0.6, 0) - side) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.08, 3.4, 0.1), { blocks = false, collide = false })
	local fl = c - Vector3.new(0, 3.5, 0)
	PM.dress(m, "Props.Cabinet", CFrame.lookAt(fl, fl - side)) -- (바닥 가운데, -Z = 문 쪽(방 안))
end

-- ── 폐유치원 ──
-- 모든 것이 어른 눈높이보다 낮다(작은 놀이기구 옆에 숨은 괴물이 오히려 커 보이게).

-- 미끄럼틀(U): 벽 쪽 사다리 + 작은 발판 + 방 안쪽으로 내려오는 미끄럼 판
function Props.Slide(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j) or Vector3.new(0, 0, -1)
	local across = Vector3.new(side.Z, 0, -side.X)
	local top = 4.6
	local deck = p + side * 1.6
	local m = Instance.new("Model")
	m.Name = "Slide"
	m.Parent = ctx.props
	-- 발판 + 네 기둥 + 난간
	Kit.box(m, CFrame.lookAt(deck + Vector3.new(0, top, 0), deck + Vector3.new(0, top, 0) + side), Vector3.new(2.8, 0.25, 2.6), { blocks = false })
	for _, a in { -1, 1 } do
		for _, b in { -1, 1 } do
			local c = deck + across * (a * 1.3) + side * (b * 1.2)
			Kit.cylinder(m, c, c + Vector3.new(0, top + 2.2, 0), 0.12, { blocks = false })
		end
		local r0 = deck + across * (a * 1.3) + Vector3.new(0, top + 1.6, 0)
		Kit.cylinder(m, r0 - side * 1.2, r0 + side * 1.2, 0.07, { blocks = false, collide = false })
	end
	-- 작은 삼각 지붕
	for _, a in { -1, 1 } do
		local c = deck + across * (a * 0.75) + Vector3.new(0, top + 2.65, 0)
		Kit.box(m, CFrame.lookAt(c, c + side) * CFrame.Angles(0, 0, a * 0.55), Vector3.new(1.75, 0.15, 2.8), { blocks = false, collide = false })
	end
	-- 사다리(벽 쪽)
	local lad = deck + side * 1.25
	for _, a in { -1, 1 } do
		local c = lad + across * (a * 0.8)
		Kit.cylinder(m, c, c + Vector3.new(0, top, 0), 0.08, { blocks = false })
	end
	for k = 1, 4 do
		local c = lad + Vector3.new(0, k * top / 5, 0)
		Kit.cylinder(m, c - across * 0.8, c + across * 0.8, 0.06, { blocks = false, collide = false })
	end
	-- 미끄럼 판(방 안쪽으로 비스듬히) + 양옆 턱
	local a0 = deck - side * 1.3 + Vector3.new(0, top, 0)
	local a1 = p - side * 3.6 + Vector3.new(0, 0.6, 0)
	local mid = (a0 + a1) / 2
	local len = (a1 - a0).Magnitude
	local cf = CFrame.lookAt(mid, a1)
	Kit.box(m, cf, Vector3.new(1.8, 0.15, len), { blocks = false })
	for _, a in { -1, 1 } do
		Kit.box(m, cf * CFrame.new(a * 0.95, 0.3, 0), Vector3.new(0.12, 0.6, len), { blocks = false, collide = false })
	end
	Kit.box(m, CFrame.lookAt(p + Vector3.new(0, 2.5, 0), p + Vector3.new(0, 2.5, 0) + side), Vector3.new(3, 5, 6.5), { invisible = true, tag = false })
	PM.dress(m, "Props.Slide", CFrame.lookAt(p, p + side)) -- (칸 가운데 바닥, -Z = 벽(사다리) 쪽)
end

-- 작은 책걸상(t): 무릎 높이 탁자 + 작은 의자 둘
function Props.SmallDesk(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local yaw = ctx.hash(i, j, 3) * 0.5 - 0.25
	local cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
	local m = Instance.new("Model")
	m.Name = "SmallDesk"
	m.Parent = ctx.props
	Kit.box(m, cf * CFrame.new(0, 2.1, 0), Vector3.new(3.8, 0.18, 2.2), { blocks = false })
	for _, x in { -1.7, 1.7 } do
		for _, z in { -0.9, 0.9 } do
			Kit.box(m, cf * CFrame.new(x, 1.0, z), Vector3.new(0.18, 2.0, 0.18), { blocks = false })
		end
	end
	for k, s in { -1, 1 } do
		local ch = cf * CFrame.new(s * 0.9, 0, 1.9) * CFrame.Angles(0, (ctx.hash(i, j, 5 + k) - 0.5) * 0.8, 0)
		Kit.box(m, ch * CFrame.new(0, 1.1, 0), Vector3.new(1.1, 0.14, 1.1), { blocks = false })
		Kit.box(m, ch * CFrame.new(0, 1.75, 0.5), Vector3.new(1.1, 1.0, 0.12), { blocks = false })
		for _, x in { -0.45, 0.45 } do
			for _, z in { -0.45, 0.45 } do
				Kit.box(m, ch * CFrame.new(x, 0.55, z), Vector3.new(0.1, 1.1, 0.1), { blocks = false })
			end
		end
	end
	Kit.box(m, cf * CFrame.new(0, 1.2, 0.6), Vector3.new(3.8, 2.4, 3.6), { invisible = true, tag = false })
	PM.dress(m, "Props.SmallDesk", cf)
end

-- 장난감 더미(y): 뚜껑 열린 장난감 상자 + 쌓기 블록 + 공 + 곰 인형
function Props.ToyPile(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j) or Vector3.new(0, 0, -1)
	local across = Vector3.new(side.Z, 0, -side.X)
	local h = ctx.hash(i, j, 7)
	local c = p + side * (ctx.T / 2 - 1.4)
	local m = Instance.new("Model")
	m.Name = "ToyPile"
	m.Parent = ctx.props
	local box = CFrame.lookAt(c + Vector3.new(0, 0.9, 0), c + Vector3.new(0, 0.9, 0) - side)
	Kit.box(m, box, Vector3.new(3.0, 1.8, 1.9), { blocks = false })
	Kit.box(m, box * CFrame.new(0, 1.3, 1.1) * CFrame.Angles(-1.2, 0, 0), Vector3.new(3.0, 0.15, 1.9), { blocks = false, collide = false })
	-- 블록 탑
	local b0 = c - side * 2.0 + across * (if h < 0.5 then 1.4 else -1.4)
	for k = 0, 2 do
		local s = 0.9 - k * 0.12
		Kit.box(m, CFrame.new(b0 + Vector3.new(0, s / 2 + k * 0.85, 0)) * CFrame.Angles(0, k * 0.5 + h, 0), Vector3.new(s, s, s), { blocks = false })
	end
	Kit.ball(m, c - side * 2.4 + across * (if h < 0.5 then -1.2 else 1.2) + Vector3.new(0, 0.6, 0), 0.6, { blocks = false, collide = false })
	-- 곰 인형(상자 위에 기대 앉은 실루엣)
	local t = c + across * 0.6 + Vector3.new(0, 1.8, 0) - side * 0.3
	Kit.ball(m, t + Vector3.new(0, 0.55, 0), 0.55, { blocks = false, collide = false })
	Kit.ball(m, t + Vector3.new(0, 1.4, 0), 0.42, { blocks = false, collide = false })
	for _, s in { -1, 1 } do
		Kit.ball(m, t + Vector3.new(0, 1.78, 0) + across * (s * 0.32), 0.16, { blocks = false, collide = false })
	end
	Kit.box(m, CFrame.lookAt(c - side * 0.6 + Vector3.new(0, 1.2, 0), c - side * 0.6 + Vector3.new(0, 1.2, 0) + side), Vector3.new(3.4, 2.4, 3.2), { invisible = true, tag = false })
	PM.dress(m, if h < 0.5 then "Props.ToyPile1" else "Props.ToyPile2", CFrame.lookAt(p, p + side)) -- (칸 가운데 바닥, -Z = 벽 쪽)
end

-- 볼풀(G): 밟고 지나가는 칸. 공 몇 개 + 볼풀이 아닌 쪽 가장자리에 낮은 쿠션 턱(통과됨)
function Props.BallPit(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = Instance.new("Model")
	m.Name = "BallPit"
	m.Parent = ctx.props
	for k = 1, 5 do
		local a, b, r = ctx.hash(i, j, 10 + k), ctx.hash(i, j, 20 + k), 0.45 + ctx.hash(i, j, 30 + k) * 0.2
		Kit.ball(m, p + Vector3.new((a - 0.5) * 6.4, r + (k % 2) * 0.3, (b - 0.5) * 6.4), r, { blocks = false, collide = false })
	end
	PM.dress(m, "Props.BallPit", CFrame.new(p), nil, m:GetChildren() :: any) -- (공만: 가장자리 쿠션 턱은 기본 도형 그대로)
	for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local n = ctx.at(i + d[1], j + d[2])
		if n ~= "G" and not ctx.isWall(i + d[1], j + d[2]) then
			local v = Vector3.new(d[1], 0, d[2])
			local e = p + v * (ctx.T / 2 - 0.4) + Vector3.new(0, 0.6, 0)
			Kit.box(m, CFrame.lookAt(e, e + v), Vector3.new(ctx.T, 1.2, 0.8), { blocks = false, collide = false })
		end
	end
end

-- 낮잠 매트(N): 밟고 지나가는 얇은 매트 + 베개
function Props.NapMat(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = Instance.new("Model")
	m.Name = "NapMat"
	m.Parent = ctx.props
	local cf = CFrame.new(p) * CFrame.Angles(0, (ctx.hash(i, j, 4) - 0.5) * 0.25, 0)
	Kit.box(m, cf * CFrame.new(0, 0.15, 0), Vector3.new(2.6, 0.3, 5.6), { blocks = false, collide = false })
	Kit.box(m, cf * CFrame.new(0, 0.45, -2.2), Vector3.new(1.8, 0.35, 0.9), { blocks = false, collide = false })
	if ctx.hash(i, j, 6) < 0.4 then
		Kit.box(m, cf * CFrame.new(0.2, 0.4, 0.8) * CFrame.Angles(0, 0.3, 0), Vector3.new(2.4, 0.15, 2.6), { blocks = false, collide = false }) -- 흐트러진 이불
	end
	PM.dress(m, if ctx.hash(i, j, 6) < 0.4 then "Props.NapMat2" else "Props.NapMat1", cf)
end

-- 작은 변기·세면대(j)
function Props.KidToilet(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local side = wallSide(ctx, i, j) or Vector3.new(0, 0, -1)
	local c = p + side * (ctx.T / 2 - 1.2)
	local m = Instance.new("Model")
	m.Name = "KidToilet"
	m.Parent = ctx.props
	if ctx.hash(i, j, 8) < 0.5 then
		Kit.box(m, CFrame.lookAt(c + Vector3.new(0, 1.9, 0), c + Vector3.new(0, 1.9, 0) - side), Vector3.new(1.6, 1.0, 0.5), { blocks = false })
		Kit.cylinder(m, c - side * 0.9, c - side * 0.9 + Vector3.new(0, 1.0, 0), 0.65, { blocks = false })
		Kit.cylinder(m, c - side * 0.9 + Vector3.new(0, 1.0, 0), c - side * 0.9 + Vector3.new(0, 1.15, 0), 0.75, { blocks = false })
	else
		Kit.box(m, CFrame.lookAt(c + Vector3.new(0, 2.2, 0) - side * 0.4, c + Vector3.new(0, 2.2, 0) - side), Vector3.new(2.2, 0.4, 1.4), { blocks = false })
		Kit.cylinder(m, c - side * 0.3, c - side * 0.3 + Vector3.new(0, 2.0, 0), 0.25, { blocks = false })
		Kit.box(m, CFrame.lookAt(c + Vector3.new(0, 4.2, 0) + side * 0.4, c + Vector3.new(0, 4.2, 0) - side), Vector3.new(1.8, 1.4, 0.08), { blocks = false, collide = false }) -- 낮은 거울
	end
	Kit.box(m, CFrame.lookAt(c - side * 0.5 + Vector3.new(0, 1.2, 0), c - side * 0.5 + Vector3.new(0, 1.2, 0) + side), Vector3.new(2.4, 2.4, 2.4), { invisible = true, tag = false })
	PM.dress(m, if ctx.hash(i, j, 8) < 0.5 then "Props.KidToilet" else "Props.KidSink", CFrame.lookAt(c, c - side)) -- (벽 앞 바닥, -Z = 방 안쪽)
end

-- 낮은 기어가는 통로(q): 어린이 키 높이로 내려온 천장 + 칸마다 둥근 테(통과됨, 괴물도 지나간다)
function Props.LowTunnel(ctx, i: number, j: number)
	local p = base(ctx, i, j)
	local m = Instance.new("Model")
	m.Name = "LowTunnel"
	m.Parent = ctx.props
	local low = 6.4
	Kit.box(m, CFrame.new(p + Vector3.new(0, low + 0.15, 0)), Vector3.new(ctx.T, 0.3, ctx.T), { blocks = false, collide = false })
	local ns = ctx.isWall(i - 1, j) and ctx.isWall(i + 1, j) -- 양옆이 벽이면 남북 통로
	local along = if ns then Vector3.new(0, 0, 1) else Vector3.new(1, 0, 0)
	local across = Vector3.new(along.Z, 0, -along.X)
	for _, s in { -1, 1 } do
		local c = p + across * (s * (ctx.T / 2 - 0.5))
		Kit.cylinder(m, c, c + Vector3.new(0, low, 0), 0.18, { blocks = false, collide = false })
	end
	Kit.cylinder(m, p - across * (ctx.T / 2 - 0.5) + Vector3.new(0, low - 0.2, 0), p + across * (ctx.T / 2 - 0.5) + Vector3.new(0, low - 0.2, 0), 0.18, { blocks = false, collide = false })
	PM.dress(m, "Props.LowTunnel", CFrame.lookAt(p, p + along)) -- (-Z = 통로 방향)
end

return Props
