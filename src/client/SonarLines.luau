--!strict
-- 윤곽선 파트 풀. 얇은 Neon 파트를 미리 만들어 두고 재사용한다(이펙트를 매번 새로 만들지 않음).
-- 선은 투명도 대신 색으로 사라진다: 흰색 → 검정. 화면이 전부 검정이라 검정 Neon 은 보이지 않고,
-- 불투명 파트라서 투명 파트보다 렌더링이 훨씬 가볍다(인스턴싱).
-- 같은 선분(키)이 다시 음파를 받으면 새로 만들지 않고 타이머만 갱신 → 반복 발사해도 쌓이지 않는다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Perf = require(script.Parent:WaitForChild("Perf"))

local S = Config.Sonar
local Lines = {}

local HIDDEN = CFrame.new(0, -10000, 0)
local LR, LG, LB = S.LineColor.R, S.LineColor.G, S.LineColor.B
local QUANT = 16 -- 밝기 단계 수(색을 바꾸는 횟수를 줄인다: 검은 바탕에서는 16단계로도 부드럽다)

local LEVELS: { [number]: Color3 } = {} -- 밝기 단계별 기본 흰색(같은 색 값을 매번 만들지 않는다)
for q = 0, QUANT do
	local v = q / QUANT
	LEVELS[q] = Color3.new(LR * v, LG * v, LB * v)
end

-- 선 하나(파트와 함께 계속 재사용한다: 음파마다 표를 새로 만들지 않는다)
type Rec = {
	part: Part,
	sk: number, -- 지금 파트 크기 번호(길이·굵기 단계)
	on: boolean,
	t0: number,
	peak: number,
	key: number?,
	q: number,
	slot: number,
	wake: number, -- 밝기가 일정한 구간에서는 이 시각까지 계산을 건너뛴다(0 = 바로)
	tint: Color3?, -- 이 선만의 색(괴물 이빨 등, 파트 속성 SonarColor). 없으면 Config.Sonar.LineColor
	a: Vector3,
	b: Vector3,
	m: Vector3, -- 가운데 점(시야 판정)
	lq: number, -- 지금 있어야 할 밝기 단계(q 는 파트에 실제로 칠한 단계 — 시야 밖이면 칠하기를 미뤄 둘이 다를 수 있다)
	dirty: boolean, -- 시야 밖이라 칠하기를 미뤘다(dirtyList 에 있다)
	wt: number, -- 시간 바퀴에 넣은 깨어날 틱(-1 = 바로 목록 또는 없음)
}

local folder: Folder? = nil
-- 쉬는 선: 크기가 같은 것끼리 모아 둔다. 크기 바꾸기가 가장 비싼 일이라(선 하나 일의 절반) 같은 크기를 먼저 다시 쓴다
local freeBy: { [number]: { Rec } } = {}
local freeCount = 0
local freeCursor = 0
local created = 0
local active: { Rec } = {}
local byKey: { [number]: Rec } = {}
-- 켜진 순서(가장 오래된 것부터). 풀이 가득 찼을 때 가장 오래된 선을 O(1)로 찾는다
-- (예전에는 선 하나마다 켜진 선 전부를 훑어서, 빽빽한 곳에서 한 프레임이 1초 가까이 걸렸다)
-- 이미 꺼졌거나 다시 켜진 항목은 매 프레임 앞에서부터 치운다(예전에는 풀이 가득 찰 때만 치워서 오래 하면 끝없이 쌓였다)
local orderRec: { Rec } = {}
local orderT: { number } = {}
local head, tail = 1, 0
local function pushOrder(rec: Rec, t: number)
	tail += 1
	orderRec[tail] = rec
	orderT[tail] = t
end
local function pruneOrder()
	local n = 0
	while head <= tail and n < 4000 do
		local r = orderRec[head]
		if r.on and r.t0 == orderT[head] then
			break
		end
		orderRec[head] = nil :: any
		orderT[head] = nil :: any
		head += 1
		n += 1
	end
	if head > 8192 or head > tail then
		local count = tail - head + 1
		if count > 0 then
			table.move(orderRec, head, tail, 1)
			table.move(orderT, head, tail, 1)
		end
		for i = math.max(count + 1, 1), tail do
			orderRec[i] = nil :: any
			orderT[i] = nil :: any
		end
		head, tail = 1, math.max(count, 0)
	end
end
local moveParts: { BasePart } = {}
local moveCFs: { CFrame } = {}
Lines.stolen = 0
Lines.shownTotal = 0

local function getFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "SonarLines"
	f.Parent = workspace
	folder = f
	return f
end

-- 크기 단계: 길이 0.02스터드, 굵기 16단계(눈으로 구별되지 않는 차이). 번호 = 길이 단계 * 32 + 굵기 단계
local LEN_STEP = 0.02
local W_STEP = (S.LineMaxWidth - S.LineMinWidth) / 16
local FIRST_SK = math.floor(1 / LEN_STEP + 0.5) * 32

local function newRec(): Rec
	local p = Instance.new("Part")
	p.Name = "L"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.new(0, 0, 0)
	p.Size = Vector3.new(S.LineMinWidth, S.LineMinWidth, 1)
	p.CFrame = HIDDEN
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = getFolder()
	created += 1
	return { part = p, sk = FIRST_SK, on = false, t0 = 0, peak = 0, key = nil, q = -1, slot = 0, wake = 0, tint = nil, a = Vector3.zero, b = Vector3.zero, m = HIDDEN.Position, lq = -1, dirty = false, wt = -1 }
end

local function giveFree(rec: Rec)
	local l = freeBy[rec.sk]
	if l then
		table.insert(l, rec)
	else
		freeBy[rec.sk] = { rec }
	end
	freeCount += 1
end

-- 쉬는 선 하나: 크기가 같은 것이 있으면 그것, 없으면 아무거나
local function popFree(sk: number): Rec?
	if freeCount == 0 then
		return nil
	end
	local k: number? = sk
	local l = freeBy[sk]
	if not l then
		k = freeCursor
		l = freeBy[freeCursor]
		if not l then
			k, l = next(freeBy)
			freeCursor = k :: number
		end
	end
	local rec = table.remove(l :: { Rec }) :: Rec
	if #(l :: { Rec }) == 0 then
		freeBy[k :: number] = nil
	end
	freeCount -= 1
	return rec
end

local frameRelease = 0 -- (측정) 이 프레임에 끈 선 수
local function release(i: number)
	local rec = active[i]
	local last = active[#active]
	active[i] = last
	last.slot = i
	active[#active] = nil
	if rec.key then
		byKey[rec.key] = nil
		rec.key = nil
	end
	rec.on = false
	-- (rec.dirty 는 그대로: 미룬 목록에 남아 있으면 다음에 다시 볼 때 빠진다. dirty == 목록에 있음)
	frameRelease += 1
	-- (색은 그대로 두고 화면 밖으로만 옮긴다: 다시 쓸 때 첫 갱신에서 색을 정한다)
	table.insert(moveParts, rec.part)
	table.insert(moveCFs, HIDDEN)
	giveFree(rec)
end

Lines.dropped = 0
Lines.force = false -- (SonarPulses 가 내 음파를 그릴 때 켠다)
-- (테스트) 한 프레임에 한 일의 양: 색 바꾸기, 위치·크기 바꾸기 — 가장 많았던 프레임
local frameColor, framePlace = 0, 0
Lines.maxColor, Lines.maxPlace = 0, 0
local function take(now: number, sk: number): Rec?
	local free = popFree(sk)
	if free then
		return free
	end
	if created < S.PoolSize then
		return newRec()
	end
	-- 풀이 가득: 이미 사라지는 중인 가장 오래된 선만 가져온다(켜진 순서 큐의 앞, 그사이 다시 켜졌거나 꺼진 것은 건너뛴다).
	-- 아직 또렷한 선뿐이면 새(더 먼) 선을 그리지 않는다 — 가까운 선이 지워졌다 다시 그려지는 일(깜빡임·렉)을 막는다.
	-- 내 음파(Lines.force)는 꼭 그려져야 한다: 사라지는 선이 없으면 가장 오래 켜져 있던 선(먼저 쏜 음파)을 가져온다
	local fadeAt = S.Hold - S.FadeTime
	while head <= tail do
		local r, t = orderRec[head], orderT[head]
		local valid = r.on and r.t0 == t
		if valid and now - t < fadeAt and not Lines.force then
			break
		end
		orderRec[head] = nil :: any
		orderT[head] = nil :: any
		head += 1
		if valid then
			Lines.stolen += 1
			release(r.slot)
			return popFree(sk)
		end
	end
	Lines.dropped += 1
	return nil
end

local function sizeKey(len: number, mid: Vector3, cam: Vector3): (number, number, number)
	local w = math.clamp(S.LineMinWidth + (mid - cam).Magnitude * S.LineWidthPerStud, S.LineMinWidth, S.LineMaxWidth)
	local wi = math.floor((w - S.LineMinWidth) / W_STEP + 0.5)
	w = S.LineMinWidth + wi * W_STEP
	local li = math.max(1, math.floor((len + w * 0.6) / LEN_STEP + 0.5))
	return li * 32 + wi, w, li * LEN_STEP
end

local function place(rec: Rec, a: Vector3, b: Vector3, sk: number, w: number, l: number)
	framePlace += 1
	rec.a, rec.b = a, b
	if rec.sk ~= sk then
		rec.sk = sk
		rec.part.Size = Vector3.new(w, w, l)
		Lines.sized += 1
	end
	local mid = (a + b) / 2
	rec.m = mid
	local d = b - a
	local up = if math.abs(d.Y) > 0.98 * d.Magnitude then Vector3.xAxis else Vector3.yAxis
	table.insert(moveParts, rec.part)
	table.insert(moveCFs, CFrame.lookAt(mid, b, up))
end

Lines.sized = 0 -- (측정) 크기를 바꾼 수

-- ── 시간 바퀴: 깨어날 때가 된 선만 본다 ──
-- (예전에는 매 프레임 켜진 선 전부(수천 개)를 훑어 깨어날 시각인지 봤다: 선이 많을수록 프레임마다 그만큼 든다)
-- 틱 = 1/TPS 초. 칸 = 틱 % SIZE. 깨어날 시각은 그 틱 이상으로 올림해 넣으므로 예전처럼 now >= wake 일 때만 처리된다.
-- 한 칸에는 같은 틱 항목만 있다(SIZE 틱 = 8.5초 > 가장 먼 깨어남 Hold). 다시 넣었거나 꺼진 선의 예전 항목은 wt 가 달라 건너뛴다.
local TPS = 240
local SIZE = 2048
local wheelRec: { [number]: { Rec } } = {}
local wheelWt: { [number]: { number } } = {}
local nowList: { Rec } = {} -- 바로 처리할 선(새로 켰거나 다시 받음)
local lastTick: number? = nil -- 여기까지 처리했다

local function wakeNow(rec: Rec)
	rec.wake = 0
	rec.wt = -1
	table.insert(nowList, rec)
end

local function schedule(rec: Rec, wake: number, minTick: number)
	local t = math.max(math.ceil(wake * TPS), minTick)
	rec.wt = t
	local s = t % SIZE
	local lr = wheelRec[s]
	if lr then
		table.insert(lr, rec)
		table.insert(wheelWt[s], t)
	else
		wheelRec[s] = { rec }
		wheelWt[s] = { t }
	end
end
-- 선 하나를 보여 준다. key 가 같은 선이 이미 있으면 그 선을 갱신한다. tint: 이 선만의 색(없으면 기본 흰색)
function Lines.show(a: Vector3, b: Vector3, now: number, peak: number, key: number?, cam: Vector3, replace: boolean?, tint: Color3?)
	local len = (b - a).Magnitude
	if len < 0.03 then
		return
	end
	Lines.shownTotal += 1
	if key then
		local rec = byKey[key]
		if rec then
			rec.t0 = now
			pushOrder(rec, now)
			rec.peak = math.max(peak, rec.peak * 0.5)
			rec.q = -1
			wakeNow(rec)
			rec.tint = tint
			-- (그 자리 그대로면 옮기지 않는다: 서서 여러 번 쏠 때)
			if replace and (rec.a ~= a or rec.b ~= b) then
				place(rec, a, b, sizeKey(len, (a + b) / 2, cam))
			end
			return
		end
	end
	local sk, w, l = sizeKey(len, (a + b) / 2, cam)
	local rec = take(now, sk)
	if not rec then
		return
	end
	place(rec, a, b, sk, w, l)
	rec.on = true
	rec.t0 = now
	rec.peak = peak
	rec.key = key
	rec.q = -1
	wakeNow(rec)
	rec.tint = tint
	rec.slot = #active + 1
	active[rec.slot] = rec
	pushOrder(rec, now)
	if key then
		byKey[key] = rec
	end
end

-- 밝기 곡선: 도달 순간 플래시 → 유지 → 서서히 사라짐
local function level(age: number): number
	if age < 0 then
		return 0
	end
	if age < S.FlashTime then
		return 1 - (1 - S.BaseLevel) * (age / S.FlashTime)
	end
	local fadeStart = S.Hold - S.FadeTime
	if age < fadeStart then
		return S.BaseLevel
	end
	local t = math.clamp((age - fadeStart) / S.FadeTime, 0, 1)
	return S.BaseLevel * (1 - t) * (1 - t * 0.35)
end

-- ── 시야 밖 선은 색 칠하기를 미룬다 ──
-- 선 쪽 비용의 거의 전부가 색 바꾸기(파트 하나 약 8µs, 4명이 쏘면 초당 1만 번 넘게)다. 음파는 사방으로 퍼지므로 대부분 화면 밖이다.
-- 화면 밖 선은 "있어야 할 밝기(lq)"만 따라가고 칠하지 않는다. 카메라가 돌거나 움직이면 미룬 선을 다시 보고, 시야(+여유각)에 들어온 선은
-- 그 자리에서 지금 밝기로 칠한다. 여유각(VIEW_MARGIN)이 한 번 다시 보는 사이 카메라가 도는 각(VIEW_RECHECK)보다 훨씬 커서,
-- 화면에 보이는 선은 늘 예전과 같은 밝기다.
local VIEW_MARGIN = math.rad(15)
local VIEW_RECHECK = math.cos(math.rad(3)) -- 마지막으로 다시 본 뒤 이만큼 돌면 다시 본다
local VIEW_MOVE = 0.5 -- (스터드) 이만큼 움직여도
local VIEW_NEAR = 4 -- 이보다 가까운 선은 늘 칠한다
local VIEW_SLACK = 2 -- 선 반 길이·굵기 여유(스터드)
local dirtyList: { Rec } = {}
local vP, vR, vU, vL = Vector3.zero, Vector3.xAxis, Vector3.yAxis, -Vector3.zAxis
local vTH, vTV = 10, 10
local lastL, lastU, lastP, lastFov, lastAspect = Vector3.zero, Vector3.zero, Vector3.new(1e9, 0, 0), 0, 0
Lines.deferred = 0 -- (측정) 시야 밖이라 칠하기를 미룬 수
local deferredSeen = 0

local function visible(m: Vector3): boolean
	local d = m - vP
	if d.Magnitude < VIEW_NEAR then
		return true
	end
	local z = d:Dot(vL)
	if z <= 0 then
		return false
	end
	return math.abs(d:Dot(vR)) <= z * vTH + VIEW_SLACK and math.abs(d:Dot(vU)) <= z * vTV + VIEW_SLACK
end

local function paint(rec: Rec, q: number)
	rec.q = q
	local v = q / QUANT
	local c = rec.tint
	rec.part.Color = if c then Color3.new(c.R * v, c.G * v, c.B * v) else LEVELS[q]
	frameColor += 1
end

-- 이 프레임 카메라. 돌았거나 움직였으면 true(미룬 선을 다시 볼 때)
local function setupView(): boolean
	local cam = workspace.CurrentCamera
	if not cam then
		vTH, vTV = 1e9, 1e9 -- (카메라가 없으면 전부 칠한다)
		return true
	end
	local cf = cam.CFrame
	vP, vR, vU, vL = cf.Position, cf.RightVector, cf.UpVector, cf.LookVector
	local vs = cam.ViewportSize
	local aspect = if vs.Y > 0 then vs.X / vs.Y else 16 / 9
	local fov = cam.FieldOfView
	local halfV = math.rad(fov) / 2
	vTV = math.tan(math.min(halfV + VIEW_MARGIN, math.rad(89)))
	vTH = math.tan(math.min(math.atan(math.tan(halfV) * aspect) + VIEW_MARGIN, math.rad(89)))
	if vL:Dot(lastL) < VIEW_RECHECK or vU:Dot(lastU) < VIEW_RECHECK or (vP - lastP).Magnitude > VIEW_MOVE or fov ~= lastFov or aspect ~= lastAspect then
		lastL, lastU, lastP, lastFov, lastAspect = vL, vU, vP, fov, aspect
		return true
	end
	return false
end

-- 선 하나가 깨어났다: 수명이 끝났으면 끄고, 아니면 밝기를 정하고 다음 깨어날 때를 바퀴에 넣는다
local fadeStart = S.Hold - S.FadeTime
local fadeStep = S.FadeTime / QUANT
local function wakeRec(rec: Rec, now: number, minTick: number)
	local age = now - rec.t0
	if age >= S.Hold then
		rec.wt = -1
		release(rec.slot)
		return
	end
	-- 다음에 밝기가 바뀔 때까지 쉰다(매 프레임 색을 바꾸지 않게):
	--   플래시 동안: 플래시가 끝날 때(밝게 → 보통, 두 번만 바뀜)
	--   유지 동안: 사라지기 시작할 때
	--   사라지는 동안: 다음 단계쯤 — 같은 프레임에 켜진 선들이 한꺼번에 바뀌지 않게 조금씩 어긋나게
	rec.wake = if age < S.FlashTime
		then rec.t0 + S.FlashTime
		elseif age < fadeStart then rec.t0 + fadeStart
		else math.min(now + fadeStep * (0.6 + math.random() * 0.8), rec.t0 + S.Hold)
	schedule(rec, rec.wake, minTick)
	local l = level(age) * rec.peak
	local q = math.floor(l * QUANT + 0.5)
	rec.lq = q
	if q ~= rec.q then
		if visible(rec.m) then
			paint(rec, q)
		elseif not rec.dirty then
			rec.dirty = true
			table.insert(dirtyList, rec)
			Lines.deferred += 1
		end
	end
end

local frameWoken = 0 -- (측정) 이 프레임에 깨운 선 수
function Lines.update(now: number)
	local c0 = os.clock()
	local recheck = setupView()
	local nowTick = math.floor(now * TPS)
	local from = if lastTick then lastTick + 1 else nowTick
	if nowTick < from - 1 then
		from = nowTick -- (시계가 뒤로 갔다: 테스트의 가짜 시계 뒤. 바퀴는 Lines.clear 가 비운다)
	end
	from = math.max(from, nowTick - SIZE + 1)
	lastTick = nowTick
	local minTick = nowTick + 1 -- (다시 넣는 것은 다음 틱부터: 이 프레임에 두 번 처리하지 않는다)
	-- 바로 처리할 선
	if #nowList > 0 then
		local list = nowList
		nowList = {}
		for _, rec in list do
			if rec.on and rec.wake == 0 then
				frameWoken += 1
				wakeRec(rec, now, minTick)
			end
		end
	end
	-- 깨어날 틱이 된 칸들
	for t = from, nowTick do
		local s = t % SIZE
		local lr = wheelRec[s]
		if lr then
			local lw = wheelWt[s]
			wheelRec[s] = nil
			wheelWt[s] = nil
			for k, rec in lr do
				local wt = lw[k]
				if rec.on and rec.wt == wt then
					if wt <= nowTick then
						frameWoken += 1
						wakeRec(rec, now, minTick)
					else
						schedule(rec, wt / TPS, wt) -- (한 바퀴 뒤 것: 그대로 다시 넣는다)
					end
				end
			end
		end
	end
	-- 카메라가 돌았거나 움직였다: 미룬 선 중 시야에 들어온 것을 지금 밝기로 칠한다(꺼졌거나 이미 칠한 것은 목록에서 뺀다)
	if recheck and #dirtyList > 0 then
		local n = #dirtyList
		local k = 1
		while k <= n do
			local rec = dirtyList[k]
			local keep = rec.on and rec.dirty and rec.lq ~= rec.q
			if keep and visible(rec.m) then
				paint(rec, rec.lq)
				keep = false
			end
			if keep then
				k += 1
			else
				rec.dirty = false
				dirtyList[k] = dirtyList[n]
				dirtyList[n] = nil
				n -= 1
			end
		end
	end
	pruneOrder()
	local c1 = os.clock()
	local moved = #moveParts
	if moved > 0 then
		workspace:BulkMoveTo(moveParts, moveCFs, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(moveParts)
		table.clear(moveCFs)
	end
	-- (측정) 훑기·색 바꾸기 / 한꺼번에 옮기기 시간, 개수 합계
	Perf.add("lines.scan", c1 - c0)
	Perf.add("lines.bulk", os.clock() - c1)
	Perf.count("lines.color", frameColor)
	Perf.count("lines.moved", moved)
	Perf.count("lines.release", frameRelease)
	Perf.count("lines.woken", frameWoken)
	frameWoken = 0
	Perf.count("lines.deferred", Lines.deferred - deferredSeen)
	deferredSeen = Lines.deferred
	frameRelease = 0
	Lines.maxColor = math.max(Lines.maxColor, frameColor)
	Lines.maxPlace = math.max(Lines.maxPlace, framePlace)
	frameColor, framePlace = 0, 0
end

-- 테스트: p 에서 r 안에 켜져 있는 선 수
function Lines.countNear(p: Vector3, r: number): number
	local n = 0
	for _, rec in active do
		if rec.lq > 0 and (rec.part.Position - p).Magnitude < r then
			n += 1
		end
	end
	return n
end

-- 선 파트를 미리 만들어 둔다(음파 도중에 새로 만들면 그 프레임이 끊긴다). 스테이지를 불러올 때 조금씩 만든다
function Lines.prewarm(n: number)
	local want = math.min(n, S.PoolSize)
	while created < want do
		for _ = 1, 150 do
			if created >= want then
				break
			end
			giveFree(newRec())
		end
		task.wait()
	end
end

function Lines.clear()
	for _, r in dirtyList do
		r.dirty = false
	end
	table.clear(dirtyList)
	while #active > 0 do
		active[#active].wt = -1
		release(#active)
	end
	table.clear(wheelRec)
	table.clear(wheelWt)
	table.clear(nowList)
	lastTick = nil
	table.clear(orderRec)
	table.clear(orderT)
	head, tail = 1, 0
	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveCFs, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(moveParts)
		table.clear(moveCFs)
	end
end

-- (테스트) 실제 화면(여유각 없이) 안에 있는데 칠한 밝기가 있어야 할 밝기와 다른 선 수 — 늘 0 이어야 한다
function Lines.viewMismatch(): number
	local cam = workspace.CurrentCamera
	if not cam then
		return 0
	end
	local cf = cam.CFrame
	local p, r, u, l = cf.Position, cf.RightVector, cf.UpVector, cf.LookVector
	local vs = cam.ViewportSize
	local halfV = math.rad(cam.FieldOfView) / 2
	local tv = math.tan(halfV)
	local th = tv * (if vs.Y > 0 then vs.X / vs.Y else 16 / 9)
	local n = 0
	for _, rec in active do
		local d = rec.m - p
		local z = d:Dot(l)
		if z > 0.1 and math.abs(d:Dot(r)) <= z * th and math.abs(d:Dot(u)) <= z * tv and rec.q ~= rec.lq and rec.lq >= 0 then
			n += 1
		end
	end
	return n
end

function Lines.stats()
	local lit = 0
	for _, r in active do
		if r.lq > 0 then
			lit += 1
		end
	end
	return { active = #active, lit = lit, created = created, free = freeCount, order = tail - head + 1, sized = Lines.sized, stolen = Lines.stolen, deferred = Lines.deferred, dirty = #dirtyList, viewMismatch = Lines.viewMismatch(), dropped = Lines.dropped, shown = Lines.shownTotal, maxColor = Lines.maxColor, maxPlace = Lines.maxPlace }
end

-- 테스트용: 현재 켜진 선의 가운데 점들
function Lines.litMidpoints(): { Vector3 }
	local out = {}
	for _, r in active do
		if r.lq > 0 then
			table.insert(out, r.part.Position)
		end
	end
	return out
end

return Lines
