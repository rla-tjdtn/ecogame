--!strict
-- 윤곽선 파트 풀. 얇은 Neon 파트를 미리 만들어 두고 재사용한다(이펙트를 매번 새로 만들지 않음).
-- 선은 투명도 대신 색으로 사라진다: 흰색 → 검정. 화면이 전부 검정이라 검정 Neon 은 보이지 않고,
-- 불투명 파트라서 투명 파트보다 렌더링이 훨씬 가볍다(인스턴싱).
-- 같은 선분(키)이 다시 음파를 받으면 새로 만들지 않고 타이머만 갱신 → 반복 발사해도 쌓이지 않는다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local S = Config.Sonar
local Lines = {}

local HIDDEN = CFrame.new(0, -10000, 0)
local LR, LG, LB = S.LineColor.R, S.LineColor.G, S.LineColor.B
local QUANT = 16 -- 밝기 단계 수(색을 바꾸는 횟수를 줄인다: 검은 바탕에서는 16단계로도 부드럽다)

type Rec = {
	part: Part,
	t0: number,
	peak: number,
	key: number?,
	q: number,
	slot: number,
	wake: number?, -- 밝기가 일정한 구간에서는 이 시각까지 계산을 건너뛴다
}

local folder: Folder? = nil
local free: { Part } = {}
local created = 0
local active: { Rec } = {}
local byKey: { [number]: Rec } = {}
-- 켜진 순서(가장 오래된 것부터). 풀이 가득 찼을 때 가장 오래된 선을 O(1)로 찾는다
-- (예전에는 선 하나마다 켜진 선 전부를 훑어서, 빽빽한 곳에서 한 프레임이 1초 가까이 걸렸다)
local order: { { rec: Rec, t0: number } } = {}
local head = 1
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

local function newPart(): Part
	local p = Instance.new("Part")
	p.Name = "L"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.new(0, 0, 0)
	p.Size = Vector3.new(0.05, 0.05, 1)
	p.CFrame = HIDDEN
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = getFolder()
	created += 1
	return p
end

local function release(i: number)
	local rec = active[i]
	local last = active[#active]
	active[i] = last
	last.slot = i
	active[#active] = nil
	if rec.key then
		byKey[rec.key] = nil
	end
	-- (색은 그대로 두고 화면 밖으로만 옮긴다: 다시 쓸 때 첫 갱신에서 색을 정한다)
	table.insert(moveParts, rec.part)
	table.insert(moveCFs, HIDDEN)
	table.insert(free, rec.part)
end

Lines.dropped = 0
-- (테스트) 한 프레임에 한 일의 양: 색 바꾸기, 위치·크기 바꾸기 — 가장 많았던 프레임
local frameColor, framePlace = 0, 0
Lines.maxColor, Lines.maxPlace = 0, 0
local function take(now: number): Part?
	local p = table.remove(free)
	if p then
		return p
	end
	if created < S.PoolSize then
		return newPart()
	end
	-- 풀이 가득: 이미 사라지는 중인 가장 오래된 선만 가져온다(켜진 순서 큐의 앞, 그사이 다시 켜졌거나 꺼진 것은 건너뛴다).
	-- 아직 또렷한 선뿐이면 새(더 먼) 선을 그리지 않는다 — 가까운 선이 지워졌다 다시 그려지는 일(깜빡임·렉)을 막는다
	local fadeAt = S.Hold - S.FadeTime
	while head <= #order do
		local e = order[head]
		local r = e.rec
		if not (active[r.slot] == r and r.t0 == e.t0) then
			order[head] = nil :: any
			head += 1
		elseif now - r.t0 >= fadeAt then
			order[head] = nil :: any
			head += 1
			Lines.stolen += 1
			release(r.slot)
			return table.remove(free)
		else
			break
		end
	end
	Lines.dropped += 1
	return nil
end

local function place(part: Part, a: Vector3, b: Vector3, cam: Vector3)
	framePlace += 1
	local d = b - a
	local len = d.Magnitude
	local mid = (a + b) / 2
	local w = math.clamp(S.LineMinWidth + (mid - cam).Magnitude * S.LineWidthPerStud, S.LineMinWidth, S.LineMaxWidth)
	part.Size = Vector3.new(w, w, len + w * 0.6)
	local dir = d / len
	local up = if math.abs(dir.Y) > 0.98 then Vector3.xAxis else Vector3.yAxis
	table.insert(moveParts, part)
	table.insert(moveCFs, CFrame.lookAt(mid, mid + dir, up))
end

-- 선 하나를 보여 준다. key 가 같은 선이 이미 있으면 그 선을 갱신한다.
function Lines.show(a: Vector3, b: Vector3, now: number, peak: number, key: number?, cam: Vector3, replace: boolean?)
	if (b - a).Magnitude < 0.03 then
		return
	end
	Lines.shownTotal += 1
	if key then
		local rec = byKey[key]
		if rec then
			rec.t0 = now
			table.insert(order, { rec = rec, t0 = now })
			rec.peak = math.max(peak, rec.peak * 0.5)
			rec.q = -1
			rec.wake = nil
			if replace then
				place(rec.part, a, b, cam)
			end
			return
		end
	end
	local part = take(now)
	if not part then
		return
	end
	place(part, a, b, cam)
	local rec: Rec = { part = part, t0 = now, peak = peak, key = key, q = -1, slot = #active + 1 }
	active[rec.slot] = rec
	table.insert(order, { rec = rec, t0 = now })
	-- 큐 앞쪽 빈자리 정리
	if head > 4096 then
		local n = #order - head + 1
		table.move(order, head, #order, 1)
		for i = n + 1, #order do
			order[i] = nil :: any
		end
		head = 1
	end
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
	local i = 1
	while i <= #active do
		local rec = active[i]
		local age = now - rec.t0
		if age >= S.Hold then
			release(i)
		elseif rec.wake and now < rec.wake then
			i += 1
		else
			-- 플래시가 끝난 뒤 사라지기 시작할 때까지는 밝기가 같다: 그동안은 계산하지 않는다
			local fadeStart = S.Hold - S.FadeTime
			-- 다음에 밝기가 바뀔 때까지 쉰다(매 프레임 색을 바꾸지 않게):
			--   플래시 동안: 플래시가 끝날 때(밝게 → 보통, 두 번만 바뀜)
			--   유지 동안: 사라지기 시작할 때
			--   사라지는 동안: 다음 단계쯤 — 같은 프레임에 켜진 선들이 한꺼번에 바뀌지 않게 조금씩 어긋나게
			local step = S.FadeTime / QUANT
			rec.wake = if age < S.FlashTime then rec.t0 + S.FlashTime elseif age < fadeStart then rec.t0 + fadeStart else now + step * (0.6 + math.random() * 0.8)
			local l = level(age) * rec.peak
			local q = math.floor(l * QUANT + 0.5)
			if q ~= rec.q then
				rec.q = q
				local v = q / QUANT
				rec.part.Color = Color3.new(LR * v, LG * v, LB * v)
				frameColor += 1
			end
			i += 1
		end
	end
	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveCFs, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(moveParts)
		table.clear(moveCFs)
	end
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
			table.insert(free, newPart())
		end
		task.wait()
	end
end

function Lines.clear()
	while #active > 0 do
		release(#active)
	end
	table.clear(order)
	head = 1
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
	return { active = #active, lit = lit, created = created, free = #free, stolen = Lines.stolen, dropped = Lines.dropped, shown = Lines.shownTotal, maxColor = Lines.maxColor, maxPlace = Lines.maxPlace }
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
