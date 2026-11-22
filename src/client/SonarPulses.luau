--!strict
-- 음파 전파: 발사 지점에서 복셀 격자를 따라 Dijkstra 로 퍼진다(벽은 통과 못 하고, 열린 통로·문으로만 돌아 들어간다).
-- 파면 반경 = 경과 시간 × WaveSpeed. 파면이 지나간 복셀에 연결된 선분이 그 순간 나타난다 → 가까운 곳부터 먼 곳으로.
-- 연산은 여러 프레임에 나눠 한다(프레임당 ExpandBudget).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Geo = require(ReplicatedStorage.Shared.SonarGeometry)
local World = require(script.Parent:WaitForChild("SonarWorld"))
local Lines = require(script.Parent:WaitForChild("SonarLines"))

local S = Config.Sonar
local Pulses = {}

type Pulse = {
	id: number,
	origin: Vector3,
	t0: number,
	dist: { [number]: number },
	hk: { number },
	hv: { number },
	hn: number,
	seen: { [number]: boolean },
	buckets: { [number]: { number } },
	nextBucket: number,
	bucketPos: number, -- 지금 버킷에서 다음에 보여 줄 위치(한 프레임 상한에 걸려 버킷 중간에서 멈췄을 때)
	dynA: { Vector3 },
	dynB: { Vector3 },
	dynM: { Vector3 },
	dynKey: { number | false },
	dynCell: { [number]: { number } },
	dseen: { [number]: boolean },
	cam: Vector3,
	revealed: number,
	trace: { { number } }?,
	own: boolean,
}

local pulses: { Pulse } = {}
local nextId = 0
Pulses.last = nil :: Pulse?
Pulses.started = 0
Pulses.lastFail = nil :: string?
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

-- ── 최소 힙 ──
local function push(p: Pulse, key: number, val: number)
	local n = p.hn + 1
	p.hn = n
	local hk, hv = p.hk, p.hv
	local i = n
	while i > 1 do
		local parent = i // 2
		if hk[parent] <= key then
			break
		end
		hk[i] = hk[parent]
		hv[i] = hv[parent]
		i = parent
	end
	hk[i] = key
	hv[i] = val
end

local function pop(p: Pulse): (number, number)
	local hk, hv = p.hk, p.hv
	local topK, topV = hk[1], hv[1]
	local n = p.hn
	local lastK, lastV = hk[n], hv[n]
	hk[n] = nil
	hv[n] = nil
	n -= 1
	p.hn = n
	if n > 0 then
		local i = 1
		while true do
			local l = i * 2
			if l > n then
				break
			end
			local r = l + 1
			local c = l
			if r <= n and hk[r] < hk[l] then
				c = r
			end
			if hk[c] >= lastK then
				break
			end
			hk[i] = hk[c]
			hv[i] = hv[c]
			i = c
		end
		hk[i] = lastK
		hv[i] = lastV
	end
	return topK, topV
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

-- 움직이는 대상과 원통·구 실루엣을 이번 음파용 선분으로 만든다
local function gatherDynamic(p: Pulse, exclude: Model?)
	local list = Geo.newList()
	local R = S.Radius
	-- 정적 원통·구의 실루엣(키를 붙여 다음 음파 때 같은 선을 옮겨 쓴다)
	for _, part in World.viewPartsNear(p.origin, R) do
		local before = list.n
		Geo.viewEdges(part, p.cam, list)
		local vid = dynId(part)
		for i = before + 1, list.n do
			p.dynKey[i] = -(1e8 + vid * 64 + (i - before))
		end
	end
	-- 문, 괴물, 다른 플레이어(그 순간의 모습)
	for _, e in World.dynamicParts(p.origin, R, exclude) do
		local part = e.part
		local before = list.n
		if e.char then
			local nm = part.Name
			if nm == "Head" then
				Geo.ballSilhouette(part.CFrame, part.Size * 0.85, p.cam, list)
			elseif nm:find("Arm") or nm:find("Leg") or nm:find("Hand") or nm:find("Foot") then
				local s = part.Size
				local axis = if s.Y >= s.X and s.Y >= s.Z then "Y" elseif s.X >= s.Z then "X" else "Z"
				Geo.boxEdges(part.CFrame, s, list, axis, true)
			else
				Geo.boxEdges(part.CFrame, part.Size, list, nil, true)
			end
		else
			Geo.staticEdges(part, list, true)
			Geo.viewEdges(part, p.cam, list)
		end
		local pid = dynId(part)
		for i = before + 1, list.n do
			p.dynKey[i] = -(2e8 + pid * 256 + (i - before))
		end
	end
	-- 분할 + 복셀 연결
	local segLen = S.SegmentLength
	local n = 0
	for i = 1, list.n do
		local a, b = list.A[i], list.B[i]
		local d = b - a
		local len = d.Magnitude
		if len > 0.02 then
			local k = math.max(1, math.ceil(len / segLen))
			local key = p.dynKey[i]
			for s = 0, k - 1 do
				local pa = a + d * (s / k)
				local pb = a + d * ((s + 1) / k)
				n += 1
				p.dynA[n] = pa
				p.dynB[n] = pb
				local m = (pa + pb) / 2
				p.dynM[n] = m
				p.dynKey[-n] = if key then (key :: number) * 32 - s else false
				for _, idx in World.attachCells(m) do
					local l = p.dynCell[idx]
					if not l then
						l = {}
						p.dynCell[idx] = l
					end
					table.insert(l, n)
				end
			end
		end
	end
end

function Pulses.start(origin: Vector3, exclude: Model?, traced: boolean?): boolean
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
	nextId += 1
	local p: Pulse = {
		id = nextId,
		origin = origin,
		t0 = os.clock(),
		dist = {},
		hk = {},
		hv = {},
		hn = 0,
		seen = {},
		buckets = {},
		nextBucket = 0,
		bucketPos = 1,
		dynA = {},
		dynB = {},
		dynM = {},
		dynKey = {},
		dynCell = {},
		dseen = {},
		cam = Pulses.camera(),
		revealed = 0,
		trace = if traced then {} else nil,
		own = traced == true,
	}
	gatherDynamic(p, exclude)
	p.dist[start] = startD
	push(p, startD, start)
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
					break
				end
			end
			remote -= 1
		end
		table.insert(pulses, p)
	end
	Pulses.last = p
	Pulses.started += 1
	return true
end

local function settle(p: Pulse, c: number, d: number)
	local center = World.cellCenter(c)
	local R = S.Radius
	local segs = World.cellSegs[c]
	if segs then
		local SM = World.SM
		local seen = p.seen
		for _, s in segs do
			if not seen[s] then
				seen[s] = true
				local arr = d + (SM[s] - center).Magnitude
				if arr <= R then
					bucketAdd(p, arr, s)
				end
			end
		end
	end
	local dyn = p.dynCell[c]
	if dyn then
		local dseen = p.dseen
		for _, s in dyn do
			if not dseen[s] then
				dseen[s] = true
				local arr = d + (p.dynM[s] - center).Magnitude
				if arr <= R then
					bucketAdd(p, arr, -s)
				end
			end
		end
	end
end

-- 파면을 limitD 까지 확장. 남은 예산을 돌려준다
local function expand(p: Pulse, limitD: number, budget: number): number
	local nx, ny, nz = World.nx, World.ny, World.nz
	local occ = World.occ
	local cs = World.cs
	local R = S.Radius
	local dist = p.dist
	while p.hn > 0 and budget > 0 do
		if p.hk[1] > limitD then
			break
		end
		local d, c = pop(p)
		if d <= (dist[c] or math.huge) + 1e-6 then
			budget -= 1
			settle(p, c, d)
			local c0 = c - 1
			local x = c0 % nx
			local t = c0 // nx
			local y = t % ny
			local z = t // ny
			for _, nb in NB do
				local xx, yy, zz = x + nb.dx, y + nb.dy, z + nb.dz
				if xx >= 0 and yy >= 0 and zz >= 0 and xx < nx and yy < ny and zz < nz then
					local ni = xx + nx * (yy + ny * zz)
					if buffer.readu8(occ, ni) == 0 then
						local ok = true
						local a, b = nb.a, nb.b
						if a and b then
							local ia = (x + a[1]) + nx * ((y + a[2]) + ny * (z + a[3]))
							local ib = (x + b[1]) + nx * ((y + b[2]) + ny * (z + b[3]))
							ok = buffer.readu8(occ, ia) == 0 and buffer.readu8(occ, ib) == 0
						end
						if ok then
							local nd = d + nb.w * cs
							if nd <= R and nd < (dist[ni + 1] or math.huge) then
								dist[ni + 1] = nd
								push(p, nd, ni + 1)
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
		local key = p.dynKey[-s]
		Lines.show(p.dynA[s], p.dynB[s], now, peak, if key then (key :: number) - 1e7 else nil, p.cam, true)
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
	local showLeft = S.RevealPerFrame -- 이 프레임에 새로 보여 줄 선 수(모든 음파 합계)
	local i = 1
	while i <= #pulses do
		local p = pulses[i]
		local front = (now - p.t0) * S.WaveSpeed
		local per = math.max(400, budget // (#pulses - i + 1))
		local left = expand(p, math.min(front + 3, R + 3), per)
		budget -= (per - left)
		-- 확정된 거리(힙의 최소값)까지, 그리고 파면까지만 보여 준다
		local settled = if p.hn > 0 then p.hk[1] else math.huge
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
		if p.nextBucket > R + 1 and (p.hn == 0 or p.hk[1] > R) then
			table.remove(pulses, i)
			-- 음파가 닿은 곳(내 것과 팀원 것 모두 지도에 남긴다 — 시야 공유)
			if Pulses.onReach then
				Pulses.onReach(p.dist, R)
			end
		else
			i += 1
		end
	end
end

-- 음파(내 것·팀원 것)가 끝났을 때 (복셀 → 거리, 반경)을 받는다(MapView)
Pulses.onStart = nil :: ((origin: Vector3) -> ())? -- 음파가 시작될 때(내 것·팀원 것): 도플갱어 눈 빛
Pulses.onReach = nil :: ((dist: { [number]: number }, radius: number) -> ())?

function Pulses.active(): number
	return #pulses
end

function Pulses.clear()
	table.clear(pulses)
end

return Pulses
