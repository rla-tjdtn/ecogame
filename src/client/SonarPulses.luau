--!strict
-- 음파 전파: 발사 지점에서 복셀 격자를 따라 Dijkstra 로 퍼진다(벽은 통과 못 하고, 열린 통로·문으로만 돌아 들어간다).
-- 파면 반경 = 경과 시간 × WaveSpeed. 파면이 지나간 복셀에 연결된 선분이 그 순간 나타난다 → 가까운 곳부터 먼 곳으로.
-- 연산은 여러 프레임에 나눠 한다(프레임당 ExpandBudget).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Geo = require(ReplicatedStorage.Shared.SonarGeometry)
local World = require(script.Parent:WaitForChild("SonarWorld"))
local Lines = require(script.Parent:WaitForChild("SonarLines"))
local Perf = require(script.Parent:WaitForChild("Perf"))

local S = Config.Sonar
local Pulses = {}

type Pulse = {
	id: number,
	origin: Vector3,
	t0: number,
	-- 거리 창: 시작 복셀 둘레 WN × wy × WN 만(음파 반경 안이라 이 밖으로는 나갈 수 없다). f64 버퍼, 안 간 곳은 아주 큰 값
	dist: buffer,
	x0: number, -- 창의 (0,0,0) 이 격자의 어느 복셀인가
	y0: number,
	z0: number,
	wy: number,
	-- 버킷 큐(Dial): 거리 [k·bw, (k+1)·bw) 인 칸들. 폭 bw = 가장 짧은 이웃 거리(CellSize)라
	-- 같은 버킷 안 칸끼리는 서로 거리를 줄일 수 없다 → 힙과 똑같은 거리, 넣기·꺼내기는 O(1)
	bq: { [number]: { number } },
	bk: number, -- 지금 꺼내는 버킷
	bpos: number, -- 그 버킷에서 다음에 꺼낼 위치
	bw: number,
	bmax: number, -- 마지막 버킷 번호(반경 끝)
	seen: buffer, -- 정적 선분 번호 → 이미 넣었는가
	blockSeen: buffer, -- 구역 번호 → 그 구역의 원통·움직이는 부품을 이미 계산했는가
	viewSeen: buffer, -- 원통·구 번호 → 이미 계산했는가
	dynBlocks: { [number]: { DynItem } },
	cells: { number }, -- 닿은 복셀(World.index). 끝나면 지도에 남긴다
	buckets: { [number]: { number } },
	nextBucket: number,
	bucketPos: number, -- 지금 버킷에서 다음에 보여 줄 위치(한 프레임 상한에 걸려 버킷 중간에서 멈췄을 때)
	dynN: number,
	dynA: { Vector3 },
	dynB: { Vector3 },
	dynM: { Vector3 },
	dynKey: { number }, -- 나눈 선분 번호 → 선 키
	dynTint: { [number]: Color3 }, -- 나눈 선분 번호 → 색(파트 속성 SonarColor 가 있는 것만)
	dynCell: { [number]: { number } },
	dseen: { [number]: boolean },
	cam: Vector3,
	revealed: number,
	trace: { { number } }?,
	own: boolean,
	cpu: number, -- (측정) 이 음파에 쓴 CPU 시간(시작 + 전파 + 선 보이기)
	startCpu: number,
}
type DynItem = { part: BasePart, cf: CFrame, done: boolean }

local pulses: { Pulse } = {}
local nextId = 0
Pulses.last = nil :: Pulse?
Pulses.started = 0
Pulses.lastFail = nil :: string?
Pulses.maxActive = 0
-- (측정) 끝난 음파마다 쓴 CPU 시간: 합, 수, 최대, 시작(gatherDynamic) 최대
local cost = { sum = 0, n = 0, max = 0, startSum = 0, startMax = 0, startN = 0, cut = 0 }
function Pulses.costStats()
	return {
		avgMs = if cost.n > 0 then cost.sum / cost.n * 1000 else 0,
		maxMs = cost.max * 1000,
		finished = cost.n,
		startAvgMs = if cost.startN > 0 then cost.startSum / cost.startN * 1000 else 0,
		startMaxMs = cost.startMax * 1000,
		cut = cost.cut, -- 상한(MaxRemotePulses)에 걸려 일찍 끝낸 팀원 음파 수
	}
end
function Pulses.resetCost()
	cost.sum, cost.n, cost.max, cost.startSum, cost.startMax, cost.startN, cost.cut = 0, 0, 0, 0, 0, 0, 0
	Pulses.maxActive = #pulses
end
Pulses.camera = function(): Vector3
	local cam = workspace.CurrentCamera
	return if cam then cam.CFrame.Position else Vector3.zero
end

-- 18방향(면 6 + 모서리 12). 모서리 방향은 두 성분 칸이 모두 비어야 지나갈 수 있다(벽 모서리 새는 것 방지).
type Nb = { dx: number, dy: number, dz: number, w: number, a: { number }?, b: { number }? }
local NB: { Nb } = {}
do
	for dz = -1, 1 do
		for dy = -1, 1 do
			for dx = -1, 1 do
				local n = math.abs(dx) + math.abs(dy) + math.abs(dz)
				if n == 1 then
					table.insert(NB, { dx = dx, dy = dy, dz = dz, w = 1 })
				elseif n == 2 then
					local comps = {}
					if dx ~= 0 then
						table.insert(comps, { dx, 0, 0 })
					end
					if dy ~= 0 then
						table.insert(comps, { 0, dy, 0 })
					end
					if dz ~= 0 then
						table.insert(comps, { 0, 0, dz })
					end
					table.insert(NB, { dx = dx, dy = dy, dz = dz, w = math.sqrt(2), a = comps[1], b = comps[2] })
				end
			end
		end
	end
end

-- ── 버킷 큐 ──
-- (예전 이진 힙: 넣기·꺼내기 log n, 같은 거리로 두 번 들어간 칸을 두 번 처리했다. 버킷 큐는 같은 거리를 내면서 약 1/3 빠르다)
local function push(p: Pulse, key: number, val: number)
	local k = key // p.bw
	local l = p.bq[k]
	if l then
		l[#l + 1] = val
	else
		p.bq[k] = { val }
	end
end

-- 아직 처리하지 않은 칸 거리의 하한(없으면 math.huge). 다 쓴 버킷은 치운다
local function pending(p: Pulse): number
	local bq = p.bq
	while p.bk <= p.bmax do
		local l = bq[p.bk]
		if l and p.bpos <= #l then
			return p.bk * p.bw
		end
		bq[p.bk] = nil
		p.bk += 1
		p.bpos = 1
	end
	return math.huge
end

local function bucketAdd(p: Pulse, arrival: number, id: number)
	-- (이미 지나간 구간이면 다음에 보여 줄 구간에 넣는다: 늦게 확정된 칸의 선분이 빠지지 않게)
	local b = math.max(math.floor(arrival), p.nextBucket)
	local l = p.buckets[b]
	if not l then
		l = {}
		p.buckets[b] = l
	end
	table.insert(l, id)
end

-- 움직이는 파트마다 고정 번호(같은 선을 다음 음파 때 새로 만들지 않고 옮겨 쓴다 → 겹쳐서 두 줄·더 밝게 보이지 않는다)
local dynIds: { [BasePart]: number } = setmetatable({}, { __mode = "k" }) :: any
local nextDynId = 0
local function dynId(part: BasePart): number
	local id = dynIds[part]
	if not id then
		nextDynId += 1
		id = nextDynId
		dynIds[part] = id
	end
	return id
end

-- ── 이번 음파용 선분(원통·구 실루엣, 문·서랍·괴물) ──
-- 예전에는 쏘는 순간 반경 안 전부를 한 프레임에 계산했다(빽빽한 곳 15~50ms → 넷이 동시에 쏘면 화면이 멈칫).
-- 지금은 파동이 구역(8스터드)에 처음 들어갈 때 그 구역 것만 계산한다: 벽 너머라 닿지 않는 것은 아예 계산하지 않고, 일이 여러 프레임에 나뉜다.
-- 보는 위치(p.cam)와 움직이는 부품의 자세(item.cf)는 쏜 순간 것을 쓴다 → 그려지는 선은 예전과 같다.
local scratch = Geo.newList()

local function addSegments(p: Pulse, keyBase: number, tint: Color3?)
	local list = scratch
	local segLen = S.SegmentLength
	local R = S.Radius
	local n = p.dynN
	local dynCell = p.dynCell
	local o, cs = World.origin, World.cs
	local ox, oy, oz = o.X, o.Y, o.Z
	local nx, ny, nz = World.nx, World.ny, World.nz
	local occ = World.occ
	local lim = S.AttachDistance * S.AttachDistance
	local origin = p.origin
	for i = 1, list.n do
		local a, b = list.A[i], list.B[i]
		local d = b - a
		local len = d.Magnitude
		if len > 0.02 then
			local k = math.max(1, math.ceil(len / segLen))
			local key = (keyBase - i) * 32
			for s = 0, k - 1 do
				local pa = a + d * (s / k)
				local pb = a + d * ((s + 1) / k)
				local m = (pa + pb) / 2
				-- (곧은 거리가 이미 반경 밖이면 파동이 닿을 수 없다)
				if (m - origin).Magnitude <= R then
					n += 1
					p.dynA[n] = pa
					p.dynB[n] = pb
					p.dynM[n] = m
					p.dynKey[n] = key - s
					if tint then
						p.dynTint[n] = tint
					end
					-- World.attachCells 와 같은 판정(표를 만들지 않고 바로 넣는다)
					local mx, my, mz = m.X, m.Y, m.Z
					local x, y, z = (mx - ox) // cs, (my - oy) // cs, (mz - oz) // cs
					if x >= 0 and y >= 0 and z >= 0 and x < nx and y < ny and z < nz then
						for zz = math.max(0, z - 1), math.min(nz - 1, z + 1) do
							local cz = oz + (zz + 0.5) * cs - mz
							local czz = cz * cz
							if czz <= lim then
								for yy = math.max(0, y - 1), math.min(ny - 1, y + 1) do
									local cy = oy + (yy + 0.5) * cs - my
									local cyz = czz + cy * cy
									if cyz <= lim then
										local base = nx * (yy + ny * zz)
										for xx = math.max(0, x - 1), math.min(nx - 1, x + 1) do
											local cx = ox + (xx + 0.5) * cs - mx
											if cyz + cx * cx <= lim and buffer.readu8(occ, xx + base) == 0 then
												local idx = xx + base + 1
												local l = dynCell[idx]
												if l then
													table.insert(l, n)
												else
													dynCell[idx] = { n }
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
	p.dynN = n
end

-- 구역 b 에 파동이 처음 들어왔다. 한 일의 양(전파 연산 수로 환산)을 돌려준다
local viewIds: { number } = {} -- 원통·구 번호 → 고정 번호(dynId)
local function enterBlock(p: Pulse, b: number): number
	local work = 0
	local list = scratch
	local vl = World.viewBlocks[b]
	if vl then
		local seen = p.viewSeen
		for _, i in vl do
			if buffer.readu8(seen, i) == 0 then
				buffer.writeu8(seen, i, 1)
				local cf, size = World.viewCF[i], World.viewSize[i]
				if (cf.Position - p.origin).Magnitude <= S.Radius + size.Magnitude / 2 then
					list.n = 0
					local taper = World.viewTaper[i]
					if World.viewBall[i] then
						Geo.ballSilhouette(cf, size, p.cam, list)
					elseif taper then
						Geo.coneSilhouette(cf, size, taper, p.cam, list)
					else
						Geo.cylinderSilhouette(cf, size, p.cam, list)
					end
					if list.n > 0 then
						local vid = viewIds[i]
						if not vid then
							-- (소품 메시는 파트 하나에 실루엣이 여럿: 항목 키로 번호를 따로 받는다)
							vid = dynId((World.viewKey[i] or World.viewParts[i]) :: any)
							viewIds[i] = vid
						end
						addSegments(p, -(1e8 + vid * 64), nil)
						work += 4
					end
				end
			end
		end
	end
	local dl = p.dynBlocks[b]
	if dl then
		for _, item in dl do
			if not item.done then
				item.done = true
				local part = item.part
				if part.Parent then
					list.n = 0
					local moved = part.CFrame ~= item.cf
					if moved and Geo.shapeOf(part) == "Box" then
						local axis = part:GetAttribute("SonarEdgeAxis")
						Geo.boxEdges(item.cf, part.Size, list, if type(axis) == "string" then axis else nil, true)
					else
						Geo.staticEdges(part, list, true)
						Geo.viewEdges(part, p.cam, list)
					end
					local tint = part:GetAttribute("SonarColor")
					addSegments(p, -(2e8 + dynId(part) * 256), if typeof(tint) == "Color3" then tint else nil)
					work += 8
				end
			end
		end
	end
	return work
end

-- 쏜 순간의 문·서랍·괴물(자세는 지금 것을 적어 두고, 선은 파동이 닿을 때 만든다)
local function gatherDynamic(p: Pulse, exclude: Model?)
	local blocks = p.dynBlocks
	for _, part in World.dynamicParts(p.origin, S.Radius, exclude) do
		local cf = part.CFrame
		local item: DynItem = { part = part, cf = cf, done = false }
		local h = part.Size.Magnitude / 2
		World.eachBlock(cf.Position, h, h, h, function(b: number)
			local l = blocks[b]
			if l then
				table.insert(l, item)
			else
				blocks[b] = { item }
			end
		end)
	end
end

-- ── 거리 창·버퍼 재사용(음파마다 새로 만들지 않는다) ──
local HALF = math.ceil(S.Radius / S.CellSize) + 1 -- 시작 복셀에서 이보다 멀리 갈 수 없다
local WN = HALF * 2 + 1
local pool: { [number]: { buffer } } = {}
local function takeBuf(size: number, fill: number): buffer
	local l = pool[size]
	local b = l and table.remove(l)
	if not b then
		b = buffer.create(size)
	end
	buffer.fill(b :: buffer, 0, fill)
	return b :: buffer
end
local function giveBuf(b: buffer)
	local size = buffer.len(b)
	local l = pool[size]
	if not l then
		l = {}
		pool[size] = l
	end
	if #l < 8 then
		table.insert(l, b)
	end
end
local function recycle(p: Pulse)
	giveBuf(p.dist)
	giveBuf(p.seen)
	giveBuf(p.blockSeen)
	giveBuf(p.viewSeen)
end

-- 이웃 18방향의 번호 차이(격자 크기가 바뀌면 다시 계산)
local nbKey = ""
local nbW: { number } = {}
local nbDX: { number }, nbDY: { number }, nbDZ: { number } = {}, {}, {}
local nbL: { number } = {} -- 창 번호 차이
local nbG: { number } = {} -- 격자 번호 차이
local nbA: { number }, nbB: { number } = {}, {} -- 모서리 방향일 때 두 성분 칸의 격자 번호 차이(면 방향이면 0)
local function setupNeighbors(wy: number)
	local nx, ny = World.nx, World.ny
	local key = nx .. "," .. ny .. "," .. wy .. "," .. World.cs
	if key == nbKey then
		return
	end
	nbKey = key
	for i, nb in NB do
		nbW[i] = nb.w * World.cs
		nbDX[i], nbDY[i], nbDZ[i] = nb.dx, nb.dy, nb.dz
		nbL[i] = nb.dx + WN * (nb.dy + wy * nb.dz)
		nbG[i] = nb.dx + nx * (nb.dy + ny * nb.dz)
		local a, b = nb.a, nb.b
		nbA[i] = if a then a[1] + nx * (a[2] + ny * a[3]) else 0
		nbB[i] = if b then b[1] + nx * (b[2] + ny * b[3]) else 0
	end
end
local bufWorld: any = nil

function Pulses.start(origin: Vector3, exclude: Model?, traced: boolean?): boolean
	local c0 = os.clock()
	Pulses.lastFail = nil
	if not World.ready then
		Pulses.lastFail = "notReady"
		return false
	end
	if Pulses.onStart then
		Pulses.onStart(origin)
	end
	-- 격자 밖이면 격자 안 가장 가까운 칸으로(맵 가장자리·높은 곳에서도 쏴지게)
	local o, cs = World.origin, World.cs
	local cx = math.clamp(math.floor((origin.X - o.X) / cs), 0, World.nx - 1)
	local cy = math.clamp(math.floor((origin.Y - o.Y) / cs), 0, World.ny - 1)
	local cz = math.clamp(math.floor((origin.Z - o.Z) / cs), 0, World.nz - 1)
	if World.nx <= 0 or World.ny <= 0 or World.nz <= 0 then
		Pulses.lastFail = "outOfGrid"
		return false
	end
	local x, y, z = cx, cy, cz
	-- 시작 복셀(막혀 있으면 가까운 빈 칸. 좁은 곳·장식 옆이면 점점 넓게 찾는다)
	local start, startD = nil, math.huge
	for reach = 1, 4 do
		if start then
			break
		end
		for dz = -reach, reach do
			for dy = -reach, reach do
				for dx = -reach, reach do
					local xx, yy, zz = (x :: number) + dx, (y :: number) + dy, (z :: number) + dz
					if xx >= 0 and yy >= 0 and zz >= 0 and xx < World.nx and yy < World.ny and zz < World.nz then
						local idx = World.index(xx, yy, zz)
						if World.free(idx) then
							local d = (World.cellCenter(idx) - origin).Magnitude
							if d < startD then
								start, startD = idx, d
							end
						end
					end
				end
			end
		end
	end
	if not start then
		Pulses.lastFail = "blocked"
		return false
	end
	-- (새 스테이지: 크기가 다른 예전 버퍼는 버린다)
	if bufWorld ~= World.occ then
		bufWorld = World.occ
		table.clear(pool)
		table.clear(viewIds)
	end
	local sx, sy, sz = World.coords(start)
	local wy = math.min(World.ny, WN)
	local y0 = if World.ny <= WN then 0 else sy - HALF
	setupNeighbors(wy)
	nextId += 1
	local p: Pulse = {
		id = nextId,
		origin = origin,
		t0 = os.clock(),
		dist = takeBuf(WN * wy * WN * 8, 0x7f),
		x0 = sx - HALF,
		y0 = y0,
		z0 = sz - HALF,
		wy = wy,
		bq = {},
		bk = 0,
		bpos = 1,
		bw = World.cs,
		bmax = S.Radius // World.cs + 1,
		seen = takeBuf(World.segCount + 1, 0),
		blockSeen = takeBuf(World.bnx * World.bny * World.bnz, 0),
		viewSeen = takeBuf(#World.viewParts + 1, 0),
		dynBlocks = {},
		cells = {},
		buckets = {},
		nextBucket = 0,
		bucketPos = 1,
		dynN = 0,
		dynA = {},
		dynB = {},
		dynM = {},
		dynKey = {},
		dynTint = {},
		dynCell = {},
		dseen = {},
		cam = Pulses.camera(),
		revealed = 0,
		trace = if traced then {} else nil,
		own = traced == true,
		cpu = 0,
		startCpu = 0,
	}
	local g0 = os.clock()
	gatherDynamic(p, exclude)
	Perf.add("pulse.gather", os.clock() - g0)
	local li = HALF + WN * ((sy - y0) + wy * HALF)
	buffer.writef64(p.dist, li * 8, startD)
	push(p, startD, li)
	-- 내 음파를 먼저 처리한다(한 프레임 연산·선 수 한도를 팀원·도플갱어 음파보다 먼저 쓴다)
	if p.own then
		table.insert(pulses, 1, p)
	else
		-- 팀원·도플갱어 음파는 동시에 MaxRemotePulses 개까지만(여럿이 동시에 쏴도 렉 없이): 넘으면 가장 오래된 것부터 끝낸다
		local remote = 0
		for _, q in pulses do
			if not q.own then
				remote += 1
			end
		end
		local cap = (S :: any).MaxRemotePulses or 4
		while remote >= cap do
			for k, q in pulses do
				if not q.own then
					table.remove(pulses, k)
					recycle(q)
					cost.cut += 1
					break
				end
			end
			remote -= 1
		end
		table.insert(pulses, p)
	end
	Pulses.last = p
	Pulses.started += 1
	Pulses.maxActive = math.max(Pulses.maxActive, #pulses)
	local sc = os.clock() - c0
	p.cpu += sc
	p.startCpu = sc
	cost.startSum += sc
	cost.startN += 1
	cost.startMax = math.max(cost.startMax, sc)
	return true
end

local function settle(p: Pulse, c: number, d: number)
	local segs = World.cellSegs[c]
	local dyn = p.dynCell[c]
	if not segs and not dyn then
		return
	end
	local center = World.cellCenter(c)
	local R = S.Radius
	if segs then
		local SM = World.SM
		local seen = p.seen
		for _, s in segs do
			if buffer.readu8(seen, s) == 0 then
				buffer.writeu8(seen, s, 1)
				local arr = d + (SM[s] - center).Magnitude
				if arr <= R then
					bucketAdd(p, arr, s)
				end
			end
		end
	end
	if dyn then
		local dseen = p.dseen
		local dynM = p.dynM
		for _, s in dyn do
			if not dseen[s] then
				dseen[s] = true
				local arr = d + (dynM[s] - center).Magnitude
				if arr <= R then
					bucketAdd(p, arr, -s)
				end
			end
		end
	end
end

-- 파면을 limitD 까지 확장. 남은 예산을 돌려준다
local blockTime = 0 -- (측정) 이 프레임에 구역 선분(원통·문·괴물) 계산에 쓴 시간
local function expand(p: Pulse, limitD: number, budget: number): number
	local nx, ny, nz = World.nx, World.ny, World.nz
	local occ = World.occ
	local R = S.Radius
	local dist = p.dist
	local x0, y0, z0, wy = p.x0, p.y0, p.z0, p.wy
	local bnx, bny, BL = World.bnx, World.bny, World.BLOCK
	local blockSeen = p.blockSeen
	local cells = p.cells
	local bq, bw = p.bq, p.bw
	while budget > 0 do
		-- 다음 칸: 지금 버킷에서, 다 썼으면 다음 버킷(버킷 하한이 limitD 를 넘으면 멈춘다)
		local l = bq[p.bk]
		if not l or p.bpos > #l then
			if pending(p) > limitD then
				break
			end
			l = bq[p.bk]
		elseif p.bk * bw > limitD then
			break
		end
		local li = (l :: { number })[p.bpos]
		p.bpos += 1
		local d = buffer.readf64(dist, li * 8)
		-- (음수 = 이미 처리한 칸. 더 짧은 거리로 다시 들어가 남은 예전 항목은 건너뛴다)
		if d >= 0 then
			buffer.writef64(dist, li * 8, -1)
			local lt = li // WN
			local x = x0 + li % WN
			local y = y0 + lt % wy
			local z = z0 + lt // wy
			local g = x + nx * (y + ny * z)
			budget -= 1
			local b = x // BL + bnx * (y // BL + bny * (z // BL))
			if buffer.readu8(blockSeen, b) == 0 then
				buffer.writeu8(blockSeen, b, 1)
				local e0 = os.clock()
				budget -= enterBlock(p, b)
				blockTime += os.clock() - e0
			end
			table.insert(cells, g + 1)
			settle(p, g + 1, d)
			-- 격자 안쪽 복셀이면 이웃이 격자 밖인지 볼 필요가 없다
			local inner = x > 0 and y > 0 and z > 0 and x < nx - 1 and y < ny - 1 and z < nz - 1
			for i = 1, 18 do
				local nd = d + nbW[i]
				if nd <= R then
					local ok = true
					if not inner then
						local xx, yy, zz = x + nbDX[i], y + nbDY[i], z + nbDZ[i]
						ok = xx >= 0 and yy >= 0 and zz >= 0 and xx < nx and yy < ny and zz < nz
					end
					if ok and buffer.readu8(occ, g + nbG[i]) == 0 then
						local na = nbA[i]
						if na == 0 or (buffer.readu8(occ, g + na) == 0 and buffer.readu8(occ, g + nbB[i]) == 0) then
							local nl = li + nbL[i]
							if nd < buffer.readf64(dist, nl * 8) then
								buffer.writef64(dist, nl * 8, nd)
								push(p, nd, nl)
							end
						end
					end
				end
			end
		end
	end
	return budget
end

local function reveal(p: Pulse, id: number, arrival: number, now: number)
	local peak = 1 - (1 - S.FarLevel) * math.clamp(arrival / S.Radius, 0, 1)
	Lines.force = p.own
	if id > 0 then
		Lines.show(World.SA[id], World.SB[id], now, peak, id, p.cam, false)
	else
		local s = -id
		Lines.show(p.dynA[s], p.dynB[s], now, peak, p.dynKey[s] - 1e7, p.cam, true, p.dynTint[s])
	end
	p.revealed += 1
	if p.trace and #p.trace < 6000 then
		table.insert(p.trace, { now - p.t0, arrival, if id > 0 then id else 0 })
	end
end

function Pulses.update(now: number)
	if #pulses == 0 then
		return
	end
	local budget = S.ExpandBudget
	local R = S.Radius
	local expandTime, revealTime = 0, 0
	blockTime = 0
	local showLeft = S.RevealPerFrame -- 이 프레임에 새로 보여 줄 선 수(모든 음파 합계)
	local i = 1
	while i <= #pulses do
		local p = pulses[i]
		local c0 = os.clock()
		local front = (now - p.t0) * S.WaveSpeed
		local per = math.max(400, budget // (#pulses - i + 1))
		local left = expand(p, math.min(front + 3, R + 3), per)
		budget -= (per - left)
		local r0 = os.clock()
		expandTime += r0 - c0
		-- 확정된 거리(처리 안 한 칸 거리의 하한)까지, 그리고 파면까지만 보여 준다
		local settled = pending(p)
		local limit = math.min(front, settled)
		-- 한 프레임에 새로 보여 줄 선 수를 제한한다(모든 음파 합계, 버킷 중간에서도 멈춘다 — 빽빽한 곳에서 한 프레임이 길어지지 않게)
		while p.nextBucket <= limit and p.nextBucket <= R + 1 and showLeft > 0 do
			local l = p.buckets[p.nextBucket]
			if l then
				local k = p.bucketPos
				while k <= #l and showLeft > 0 do
					reveal(p, l[k], p.nextBucket, now)
					k += 1
					showLeft -= 1
				end
				if k <= #l then
					p.bucketPos = k
					break
				end
				p.buckets[p.nextBucket] = nil
			end
			p.bucketPos = 1
			p.nextBucket += 1
		end
		local r1 = os.clock()
		revealTime += r1 - r0
		p.cpu += r1 - c0
		if p.nextBucket > R + 1 and pending(p) > R then
			table.remove(pulses, i)
			cost.sum += p.cpu
			cost.n += 1
			cost.max = math.max(cost.max, p.cpu)
			-- 음파가 닿은 곳(내 것과 팀원 것 모두 지도에 남긴다 — 시야 공유)
			if Pulses.onReach then
				Pulses.onReach(p.cells)
			end
			recycle(p)
		else
			i += 1
		end
	end
	-- (측정) 전파(구역 선분 포함) / 그중 구역 선분 / 선 보이기(Lines.show)
	Perf.add("pulses.expand", expandTime)
	Perf.add("pulses.block", blockTime)
	Perf.add("pulses.reveal", revealTime)
end

-- 음파(내 것·팀원 것)가 끝났을 때 닿은 복셀 목록을 받는다(MapView)
Pulses.onStart = nil :: ((origin: Vector3) -> ())? -- 음파가 시작될 때(내 것·팀원 것): 도플갱어 눈 빛
Pulses.onReach = nil :: ((cells: { number }) -> ())?


function Pulses.active(): number
	return #pulses
end

function Pulses.clear()
	table.clear(pulses)
end

return Pulses
