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
local QUANT = 40

type Rec = {
	part: Part,
	t0: number,
	peak: number,
	key: number?,
	q: number,
	slot: number,
}

local folder: Folder? = nil
local free: { Part } = {}
local created = 0
local active: { Rec } = {}
local byKey: { [number]: Rec } = {}
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
	rec.part.Color = Color3.new(0, 0, 0)
	table.insert(moveParts, rec.part)
	table.insert(moveCFs, HIDDEN)
	table.insert(free, rec.part)
end

local function take(): Part
	local p = table.remove(free)
	if p then
		return p
	end
	if created < S.PoolSize then
		return newPart()
	end
	-- 풀이 가득: 가장 오래된 선을 빼앗는다
	local oldest, oi = math.huge, 1
	for i, r in active do
		if r.t0 < oldest then
			oldest, oi = r.t0, i
		end
	end
	Lines.stolen += 1
	release(oi)
	return table.remove(free) :: Part
end

local function place(part: Part, a: Vector3, b: Vector3, cam: Vector3)
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
			rec.peak = math.max(peak, rec.peak * 0.5)
			rec.q = -1
			if replace then
				place(rec.part, a, b, cam)
			end
			return
		end
	end
	local part = take()
	place(part, a, b, cam)
	local rec: Rec = { part = part, t0 = now, peak = peak, key = key, q = -1, slot = #active + 1 }
	active[rec.slot] = rec
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
		else
			local l = level(age) * rec.peak
			local q = math.floor(l * QUANT + 0.5)
			if q ~= rec.q then
				rec.q = q
				local v = q / QUANT
				rec.part.Color = Color3.new(LR * v, LG * v, LB * v)
			end
			i += 1
		end
	end
	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveCFs, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(moveParts)
		table.clear(moveCFs)
	end
end

function Lines.clear()
	while #active > 0 do
		release(#active)
	end
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
	return { active = #active, lit = lit, created = created, free = #free, stolen = Lines.stolen, shown = Lines.shownTotal }
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
