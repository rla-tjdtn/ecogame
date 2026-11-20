--!strict
-- 음파 렌더링용 월드 데이터(클라이언트). 스테이지가 로드되면 한 번만 만든다(매 프레임 다시 스캔하지 않음).
--   1) 윤곽선 선분: SonarRenderable 태그 파트의 모서리 → 같은 평면 이음매·묻힌 모서리 제거 → 짧게 분할
--   2) 전파 격자: 소리를 막는 구조물을 복셀(CellSize)로 칠한 점유 격자. 닫힌 문은 열고 닫을 때 갱신.
--   3) 선분 ↔ 복셀 연결: 각 선분은 가까운 빈 복셀을 통해 음파를 받는다(벽 너머 복셀은 거리 제한으로 제외).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Geo = require(ReplicatedStorage.Shared.SonarGeometry)

local S = Config.Sonar
local TAGS = Config.Tags

local World = {}
World.ready = false
World.buildId = 0
World.stage = nil :: Folder?

-- 정적 선분
World.SA = {} :: { Vector3 }
World.SB = {} :: { Vector3 }
World.SM = {} :: { Vector3 }
World.segCount = 0
World.culled = 0
World.unattached = 0
World.cellSegs = {} :: { [number]: { number } }
-- 보는 위치에 따라 선이 바뀌는 정적 파트(원통·구) — 16스터드 버킷
World.viewParts = {} :: { BasePart }
local viewBuckets: { [number]: { number } } = {}
-- 격자
World.cs = S.CellSize
World.origin = Vector3.zero
World.nx, World.ny, World.nz = 0, 0, 0
World.occ = buffer.create(1)
World.doors = {} :: { { model: Model, cells: { number }, blocked: boolean, conn: RBXScriptConnection? } }

local VB = 16
local function vkey(x: number, y: number, z: number): number
	return (x + 512) + (y + 64) * 1024 + (z + 512) * 1024 * 128
end

-- ── 판정 도우미 ──
local function isDynamic(inst: Instance, stage: Instance?): boolean
	local cur: Instance? = inst
	while cur and cur ~= stage and cur ~= workspace do
		if cur:GetAttribute(TAGS.Dynamic) == true then
			return true
		end
		cur = cur.Parent
	end
	return false
end

-- 태그가 붙은 인스턴스(파트 또는 모델)의 파트들
local function taggedParts(tag: string, within: Instance): { BasePart }
	local out = {}
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsDescendantOf(within) then
			if inst:IsA("BasePart") then
				table.insert(out, inst)
			else
				for _, d in inst:GetDescendants() do
					if d:IsA("BasePart") then
						table.insert(out, d)
					end
				end
			end
		end
	end
	return out
end

local function blocksSound(p: BasePart): boolean
	local b = p:GetAttribute("SonarBlocks")
	if type(b) == "boolean" then
		return b
	end
	if not p.CanCollide or p.Transparency >= 1 then
		return false
	end
	local s = p.Size
	local dims = { s.X, s.Y, s.Z }
	table.sort(dims)
	return dims[1] >= 0.9 and dims[2] >= 0.9
end

-- ── 격자 ──
function World.index(x: number, y: number, z: number): number
	return x + World.nx * (y + World.ny * z) + 1
end

function World.coords(idx: number): (number, number, number)
	local c = idx - 1
	local nx, ny = World.nx, World.ny
	local x = c % nx
	local t = c // nx
	return x, t % ny, t // ny
end

function World.cellCenter(idx: number): Vector3
	local x, y, z = World.coords(idx)
	local cs = World.cs
	return World.origin + Vector3.new((x + 0.5) * cs, (y + 0.5) * cs, (z + 0.5) * cs)
end

function World.cellOf(p: Vector3): (number?, number?, number?)
	local r = (p - World.origin) / World.cs
	local x, y, z = math.floor(r.X), math.floor(r.Y), math.floor(r.Z)
	if x < 0 or y < 0 or z < 0 or x >= World.nx or y >= World.ny or z >= World.nz then
		return nil, nil, nil
	end
	return x, y, z
end

function World.free(idx: number): boolean
	return buffer.readu8(World.occ, idx - 1) == 0
end

local function addOcc(idx: number, delta: number)
	local v = buffer.readu8(World.occ, idx - 1) + delta
	buffer.writeu8(World.occ, idx - 1, math.clamp(v, 0, 255))
end

-- 파트가 겹치는 복셀 목록(분리축: 파트 축 기준, 보수적)
local function rasterCells(cf: CFrame, size: Vector3): { number }
	local out = {}
	local cs = World.cs
	local h = cs / 2
	local X, Y, Z = cf.XVector, cf.YVector, cf.ZVector
	local ex = h * (math.abs(X.X) + math.abs(X.Y) + math.abs(X.Z))
	local ey = h * (math.abs(Y.X) + math.abs(Y.Y) + math.abs(Y.Z))
	local ez = h * (math.abs(Z.X) + math.abs(Z.Y) + math.abs(Z.Z))
	local hx, hy, hz = size.X / 2 + ex - 0.01, size.Y / 2 + ey - 0.01, size.Z / 2 + ez - 0.01
	-- 월드 AABB
	local ax = math.abs(X.X) * size.X / 2 + math.abs(Y.X) * size.Y / 2 + math.abs(Z.X) * size.Z / 2
	local ay = math.abs(X.Y) * size.X / 2 + math.abs(Y.Y) * size.Y / 2 + math.abs(Z.Y) * size.Z / 2
	local az = math.abs(X.Z) * size.X / 2 + math.abs(Y.Z) * size.Y / 2 + math.abs(Z.Z) * size.Z / 2
	local p = cf.Position
	local o = World.origin
	local x0 = math.max(0, math.floor((p.X - ax - o.X) / cs))
	local x1 = math.min(World.nx - 1, math.floor((p.X + ax - o.X) / cs))
	local y0 = math.max(0, math.floor((p.Y - ay - o.Y) / cs))
	local y1 = math.min(World.ny - 1, math.floor((p.Y + ay - o.Y) / cs))
	local z0 = math.max(0, math.floor((p.Z - az - o.Z) / cs))
	local z1 = math.min(World.nz - 1, math.floor((p.Z + az - o.Z) / cs))
	for z = z0, z1 do
		for y = y0, y1 do
			for x = x0, x1 do
				local c = o + Vector3.new((x + 0.5) * cs, (y + 0.5) * cs, (z + 0.5) * cs)
				local d = c - p
				if math.abs(d:Dot(X)) < hx and math.abs(d:Dot(Y)) < hy and math.abs(d:Dot(Z)) < hz then
					table.insert(out, World.index(x, y, z))
				end
			end
		end
	end
	return out
end

-- mid 근처에서 음파를 받을 수 있는 빈 복셀들
function World.attachCells(mid: Vector3): { number }
	local out = {}
	local x, y, z = World.cellOf(mid)
	if not x then
		return out
	end
	local lim = S.AttachDistance * S.AttachDistance
	for dz = -1, 1 do
		local zz = (z :: number) + dz
		if zz >= 0 and zz < World.nz then
			for dy = -1, 1 do
				local yy = (y :: number) + dy
				if yy >= 0 and yy < World.ny then
					for dx = -1, 1 do
						local xx = (x :: number) + dx
						if xx >= 0 and xx < World.nx then
							local idx = World.index(xx, yy, zz)
							if World.free(idx) then
								local c = World.cellCenter(idx)
								local dd = c - mid
								if dd:Dot(dd) <= lim then
									table.insert(out, idx)
								end
							end
						end
					end
				end
			end
		end
	end
	return out
end

-- ── 문(닫히면 막고 열리면 통과) ──
local function refreshDoor(d)
	local open = d.model:GetAttribute("Open") == true
	local want = not open
	if want ~= d.blocked then
		for _, idx in d.cells do
			addOcc(idx, if want then 1 else -1)
		end
		d.blocked = want
	end
end

-- ── 보는 위치 의존 파트 조회 ──
function World.viewPartsNear(p: Vector3, radius: number): { BasePart }
	local out = {}
	local r = math.ceil(radius / VB)
	local cx, cy, cz = math.floor(p.X / VB), math.floor(p.Y / VB), math.floor(p.Z / VB)
	local seen = {}
	for dz = -r, r do
		for dy = -2, 2 do
			for dx = -r, r do
				local list = viewBuckets[vkey(cx + dx, cy + dy, cz + dz)]
				if list then
					for _, i in list do
						if not seen[i] then
							seen[i] = true
							local part = World.viewParts[i]
							if (part.Position - p).Magnitude <= radius + part.Size.Magnitude / 2 then
								table.insert(out, part)
							end
						end
					end
				end
			end
		end
	end
	return out
end

-- 움직이는 대상(문, 괴물, 다른 플레이어 캐릭터)
function World.dynamicParts(near: Vector3, radius: number, exclude: Model?): { { part: BasePart, char: boolean } }
	local out = {}
	local function consider(p: BasePart, isChar: boolean)
		if (p.Position - near).Magnitude <= radius + 4 then
			table.insert(out, { part = p, char = isChar })
		end
	end
	for _, inst in CollectionService:GetTagged(TAGS.Renderable) do
		if inst:IsA("BasePart") and inst.Parent and isDynamic(inst, nil) and not (exclude and inst:IsDescendantOf(exclude)) then
			consider(inst, false)
		end
	end
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		if char and char ~= exclude and plr ~= Players.LocalPlayer then
			for _, d in char:GetChildren() do
				if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
					consider(d, true)
				end
			end
		end
	end
	return out
end

-- ── 빌드(양보하며 진행) ──
function World.build(stage: Folder)
	World.ready = false
	World.stage = stage
	local t0 = os.clock()
	local function yieldSometimes()
		if os.clock() - t0 > 0.012 then
			task.wait()
			t0 = os.clock()
		end
	end
	for _, d in World.doors do
		if d.conn then
			d.conn:Disconnect()
		end
	end
	World.doors = {}
	World.SA, World.SB, World.SM = {}, {}, {}
	World.segCount = 0
	World.culled = 0
	World.unattached = 0
	World.cellSegs = {}
	World.viewParts = {}
	viewBuckets = {}

	-- 정적 파트
	local statics: { BasePart } = {}
	for _, p in taggedParts(TAGS.Renderable, stage) do
		if not isDynamic(p, stage) then
			table.insert(statics, p)
		end
	end

	-- 격자 범위
	local bmin = stage:GetAttribute("BoundsMin") :: Vector3?
	local bmax = stage:GetAttribute("BoundsMax") :: Vector3?
	if not bmin or not bmax then
		local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, p in statics do
			lo = lo:Min(p.Position - p.Size)
			hi = hi:Max(p.Position + p.Size)
		end
		bmin, bmax = lo, hi
	end
	local cs = World.cs
	local lo = ((bmin :: Vector3) - Vector3.one * 4) / cs
	local hi = ((bmax :: Vector3) + Vector3.one * 4) / cs
	World.origin = Vector3.new(math.floor(lo.X), math.floor(lo.Y), math.floor(lo.Z)) * cs
	World.nx = math.ceil(hi.X) - math.floor(lo.X)
	World.ny = math.ceil(hi.Y) - math.floor(lo.Y)
	World.nz = math.ceil(hi.Z) - math.floor(lo.Z)
	World.occ = buffer.create(World.nx * World.ny * World.nz)

	-- 공간 해시(점 포함 판정용, 8스터드 버킷)
	local HB = 8
	local hbuckets: { [number]: { BasePart } } = {}
	for _, p in statics do
		local cf, sz = p.CFrame, p.Size / 2
		local X, Y, Z = cf.XVector, cf.YVector, cf.ZVector
		local half = Vector3.new(
			math.abs(X.X) * sz.X + math.abs(Y.X) * sz.Y + math.abs(Z.X) * sz.Z,
			math.abs(X.Y) * sz.X + math.abs(Y.Y) * sz.Y + math.abs(Z.Y) * sz.Z,
			math.abs(X.Z) * sz.X + math.abs(Y.Z) * sz.Y + math.abs(Z.Z) * sz.Z
		) + Vector3.one * 0.2
		local a = (p.Position - half) / HB
		local b = (p.Position + half) / HB
		for z = math.floor(a.Z), math.floor(b.Z) do
			for y = math.floor(a.Y), math.floor(b.Y) do
				for x = math.floor(a.X), math.floor(b.X) do
					local k = vkey(x, y, z)
					local l = hbuckets[k]
					if not l then
						l = {}
						hbuckets[k] = l
					end
					table.insert(l, p)
				end
			end
		end
		yieldSometimes()
	end
	local function inside(pt: Vector3): boolean
		local l = hbuckets[vkey(math.floor(pt.X / HB), math.floor(pt.Y / HB), math.floor(pt.Z / HB))]
		if not l then
			return false
		end
		for _, p in l do
			if Geo.pointInside(p, pt) then
				return true
			end
		end
		return false
	end

	-- 점유 격자
	for _, p in statics do
		if blocksSound(p) then
			for _, idx in rasterCells(p.CFrame, p.Size) do
				addOcc(idx, 1)
			end
		end
		yieldSometimes()
	end
	-- 문
	for _, m in CollectionService:GetTagged(TAGS.Door) do
		if m:IsA("Model") and m:IsDescendantOf(stage) then
			local panel = m:FindFirstChild("Panel") :: BasePart?
			local closed = panel and panel:GetAttribute("ClosedCFrame") :: CFrame?
			if panel and closed then
				local d = { model = m, cells = rasterCells(closed, panel.Size), blocked = false, conn = nil :: RBXScriptConnection? }
				refreshDoor(d)
				d.conn = m:GetAttributeChangedSignal("Open"):Connect(function()
					refreshDoor(d)
				end)
				table.insert(World.doors, d)
			end
		end
	end

	-- 선분
	local EPS = 0.08
	local list = Geo.newList()
	local SA, SB, SM = World.SA, World.SB, World.SM
	local segLen = S.SegmentLength
	local n = 0
	for _, p in statics do
		if Geo.shapeOf(p) ~= "None" then
			list.n = 0
			Geo.staticEdges(p, list)
			for i = 1, list.n do
				local a, b = list.A[i], list.B[i]
				local n1, n2 = list.N1[i], list.N2[i]
				local d = b - a
				local len = d.Magnitude
				if len > 0.03 then
					local k = math.max(1, math.ceil(len / segLen))
					for s = 0, k - 1 do
						local pa = a + d * (s / k)
						local pb = a + d * ((s + 1) / k)
						local m = (pa + pb) / 2
						local keep = true
						if n1 and n2 then
							local u1 = (n1 :: Vector3) * EPS
							local u2 = (n2 :: Vector3) * EPS
							local diag = inside(m + u1 + u2)
							if not diag then
								-- 한쪽 면이 모서리 너머로 같은 평면으로 이어지면 이음매
								if inside(m + u2 - u1) or inside(m + u1 - u2) then
									keep = false
								end
							elseif inside(m + u1 - u2) and inside(m - u1 + u2) then
								keep = false -- 묻힌 모서리
							end
						end
						if keep then
							n += 1
							SA[n] = pa
							SB[n] = pb
							SM[n] = m
						else
							World.culled += 1
						end
					end
				end
			end
		end
		if Geo.hasViewEdges(p) then
			table.insert(World.viewParts, p)
			local i = #World.viewParts
			local k = vkey(math.floor(p.Position.X / VB), math.floor(p.Position.Y / VB), math.floor(p.Position.Z / VB))
			local l = viewBuckets[k]
			if not l then
				l = {}
				viewBuckets[k] = l
			end
			table.insert(l, i)
		end
		yieldSometimes()
	end
	World.segCount = n

	-- 선분 ↔ 복셀
	local cellSegs = World.cellSegs
	for s = 1, n do
		local cells = World.attachCells(SM[s])
		if #cells == 0 then
			World.unattached += 1
		end
		for _, idx in cells do
			local l = cellSegs[idx]
			if not l then
				l = {}
				cellSegs[idx] = l
			end
			table.insert(l, s)
		end
		if s % 400 == 0 then
			yieldSometimes()
		end
	end

	World.buildId = (stage:GetAttribute("BuildId") :: number?) or 0
	World.ready = true
end

return World
