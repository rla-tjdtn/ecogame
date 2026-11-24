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
	return { part = p, sk = FIRST_SK, on = false, t0 = 0, peak = 0, key = nil, q = -1, slot = 0, wake = 0, tint = nil, a = Vector3.zero, b = Vector3.zero }
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
	local d = b - a
	local up = if math.abs(d.Y) > 0.98 * d.Magnitude then Vector3.xAxis else Vector3.yAxis
	table.insert(moveParts, rec.part)
	table.insert(moveCFs, CFrame.lookAt(mid, b, up))
end

Lines.sized = 0 -- (측정) 크기를 바꾼 수
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
			rec.wake = 0
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
	rec.wake = 0
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

function Lines.update(now: number)
	local c0 = os.clock()
	local i = 1
	local fadeStart = S.Hold - S.FadeTime
	local step = S.FadeTime / QUANT
	while i <= #active do
		local rec = active[i]
		if now < rec.wake then
			i += 1
			continue
		end
		local age = now - rec.t0
		if age >= S.Hold then
			release(i)
		else
			-- 다음에 밝기가 바뀔 때까지 쉰다(매 프레임 색을 바꾸지 않게):
			--   플래시 동안: 플래시가 끝날 때(밝게 → 보통, 두 번만 바뀜)
			--   유지 동안: 사라지기 시작할 때
			--   사라지는 동안: 다음 단계쯤 — 같은 프레임에 켜진 선들이 한꺼번에 바뀌지 않게 조금씩 어긋나게
			rec.wake = if age < S.FlashTime
				then rec.t0 + S.FlashTime
				elseif age < fadeStart then rec.t0 + fadeStart
				else math.min(now + step * (0.6 + math.random() * 0.8), rec.t0 + S.Hold)
			local l = level(age) * rec.peak
			local q = math.floor(l * QUANT + 0.5)
			if q ~= rec.q then
				rec.q = q
				local v = q / QUANT
				local c = rec.tint
				rec.part.Color = if c then Color3.new(c.R * v, c.G * v, c.B * v) else LEVELS[q]
				frameColor += 1
			end
			i += 1
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
	frameRelease = 0
	Lines.maxColor = math.max(Lines.maxColor, frameColor)
	Lines.maxPlace = math.max(Lines.maxPlace, framePlace)
	frameColor, framePlace = 0, 0
end

-- 테스트: p 에서 r 안에 켜져 있는 선 수
function Lines.countNear(p: Vector3, r: number): number
	local n = 0
	for _, rec in active do
		if rec.q > 0 and (rec.part.Position - p).Magnitude < r then
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
	while #active > 0 do
		release(#active)
	end
	table.clear(orderRec)
	table.clear(orderT)
	head, tail = 1, 0
	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveCFs, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(moveParts)
		table.clear(moveCFs)
	end
end

function Lines.stats()
	local lit = 0
	for _, r in active do
		if r.q > 0 then
			lit += 1
		end
	end
	return { active = #active, lit = lit, created = created, free = freeCount, order = tail - head + 1, sized = Lines.sized, stolen = Lines.stolen, dropped = Lines.dropped, shown = Lines.shownTotal, maxColor = Lines.maxColor, maxPlace = Lines.maxPlace }
end

-- 테스트용: 현재 켜진 선의 가운데 점들
function Lines.litMidpoints(): { Vector3 }
	local out = {}
	for _, r in active do
		if r.q > 0 then
			table.insert(out, r.part.Position)
		end
	end
	return out
end

return Lines
