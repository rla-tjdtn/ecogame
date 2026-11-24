--!strict
-- 모듈형 구조물 키트: 모든 스테이지가 같은 부품으로 맵을 짓는다.
-- 모든 구조물은 검은색 무광, 조명 없음. SonarRenderable 태그가 붙어 음파 윤곽선 대상이 된다.
-- 원통(파이프·난간)은 Shape = Cylinder 그대로라서 음파 렌더러가 원통 모양(끝 원 + 실루엣)으로 그린다.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Kit = {}
local TAG = Config.Tags.Renderable
local BLACK = Color3.new(0, 0, 0)

export type Opts = {
	collide: boolean?,
	tag: boolean?, -- false 면 음파 대상 아님(보이지 않는 충돌 경사로 등)
	invisible: boolean?,
	shape: string?, -- SonarShape 속성
	axis: string?, -- SonarEdgeAxis 속성
	rings: number?,
	blocks: boolean?, -- SonarBlocks: 음파·소리 전파를 막는가(nil 이면 크기로 판단)
	name: string?,
}

local function base(p: BasePart, parent: Instance, opts: Opts?)
	local o = opts or {}
	p.Anchored = true
	p.Color = BLACK
	p.Material = Enum.Material.SmoothPlastic
	p.Reflectance = 0
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = if o.collide == nil then true else o.collide
	p.CanTouch = false
	-- 부딪히지 않고 음파·소리도 막지 않는 장식은 공간 쿼리에서도 뺀다(서버 소리·괴물 레이, 클라 Reveal 은 RespectCanCollide,
	-- 음파 윤곽은 태그·지오메트리만 쓴다 — opt-sonar 확인). SearchLook 은 손잡이 뒤 서랍 판(충돌)으로 같은 Comp 를 맞힌다.
	p.CanQuery = p.CanCollide or o.blocks == true
	if o.invisible then
		p.Transparency = 1
	end
	if o.shape then
		p:SetAttribute("SonarShape", o.shape)
	end
	if o.axis then
		p:SetAttribute("SonarEdgeAxis", o.axis)
	end
	if o.rings then
		p:SetAttribute("SonarRings", o.rings)
	end
	if o.blocks ~= nil then
		p:SetAttribute("SonarBlocks", o.blocks)
	end
	if o.name then
		p.Name = o.name
	end
	if o.tag ~= false and not o.invisible then
		CollectionService:AddTag(p, TAG)
	end
	p.Parent = parent
end

function Kit.box(parent: Instance, cf: CFrame, size: Vector3, opts: Opts?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	base(p, parent, opts)
	return p
end

-- 두 모서리 좌표(최소·최대)로 축 정렬 상자
function Kit.span(parent: Instance, lo: Vector3, hi: Vector3, opts: Opts?): Part
	local a = Vector3.new(math.min(lo.X, hi.X), math.min(lo.Y, hi.Y), math.min(lo.Z, hi.Z))
	local b = Vector3.new(math.max(lo.X, hi.X), math.max(lo.Y, hi.Y), math.max(lo.Z, hi.Z))
	return Kit.box(parent, CFrame.new((a + b) / 2), b - a, opts)
end

function Kit.wedge(parent: Instance, cf: CFrame, size: Vector3, opts: Opts?): WedgePart
	local p = Instance.new("WedgePart")
	p.Size = size
	p.CFrame = cf
	base(p, parent, opts)
	return p
end

-- a 에서 b 까지 원통(반지름 r)
function Kit.cylinder(parent: Instance, a: Vector3, b: Vector3, r: number, opts: Opts?): Part
	local d = b - a
	local len = d.Magnitude
	local dir = d / len
	local up = if math.abs(dir.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(len, r * 2, r * 2)
	p.CFrame = CFrame.fromMatrix((a + b) / 2, dir, dir:Cross(up).Unit:Cross(dir))
	base(p, parent, opts)
	return p
end

function Kit.ball(parent: Instance, c: Vector3, r: number, opts: Opts?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(r * 2, r * 2, r * 2)
	p.CFrame = CFrame.new(c)
	base(p, parent, opts)
	return p
end

-- 배관: 본체 + 양 끝 플랜지(+ 볼트). flangeEvery 마다 중간 플랜지.
function Kit.pipe(parent: Instance, a: Vector3, b: Vector3, r: number, flangeAt: { number }?, bolts: boolean?)
	local m = Instance.new("Model")
	m.Name = "Pipe"
	m.Parent = parent
	Kit.cylinder(m, a, b, r, { blocks = r >= 0.9 })
	local dir = (b - a).Unit
	local len = (b - a).Magnitude
	for _, t in flangeAt or { 0, 1 } do
		local c = a + dir * (math.clamp(t * len, 0.2, len - 0.2))
		local fr = r * 1.35 + 0.08
		local fl = Kit.cylinder(m, c - dir * 0.18, c + dir * 0.18, fr, { blocks = false })
		if bolts and fr >= 0.6 then
			-- 볼트: 플랜지 둘레의 작은 원통 6개
			local up = if math.abs(dir.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
			local u = dir:Cross(up).Unit
			local w = dir:Cross(u).Unit
			for i = 0, 5 do
				local ang = i / 6 * math.pi * 2 + 0.3
				local bp = c + (u * math.cos(ang) + w * math.sin(ang)) * (fr - 0.17)
				-- (지름 0.18 볼트: 음파 실루엣 2줄이 거의 겹치므로 정적 선 1줄 — 음파 한 발마다 다시 계산하는 viewParts 에서 빠진다)
				Kit.cylinder(m, bp - dir * 0.3, bp + dir * 0.3, 0.09, { blocks = false, collide = false, shape = "Line" })
			end
		end
		local _ = fl
	end
	return m
end

-- 난간: a → b (바닥 높이 기준), 기둥 간격 step
function Kit.railing(parent: Instance, a: Vector3, b: Vector3, height: number?, step: number?)
	local h = height or 3.3
	local st = step or 2.6
	local m = Instance.new("Model")
	m.Name = "Railing"
	m.Parent = parent
	local d = b - a
	local len = d.Magnitude
	local n = math.max(1, math.floor(len / st + 0.5))
	for i = 0, n do
		local p = a + d * (i / n)
		Kit.cylinder(m, p, p + Vector3.new(0, h, 0), 0.11, { blocks = false })
	end
	local up = Vector3.new(0, h, 0)
	Kit.cylinder(m, a + up, b + up, 0.13, { blocks = false })
	Kit.cylinder(m, a + up * 0.5, b + up * 0.5, 0.09, { blocks = false })
	-- 발끝 막이(얇은 판)
	local dir = d.Unit
	local cf = CFrame.lookAt((a + b) / 2 + Vector3.new(0, 0.2, 0), (a + b) / 2 + Vector3.new(0, 0.2, 0) + dir)
	Kit.box(m, cf, Vector3.new(0.1, 0.4, len), { blocks = false, collide = false })
	-- 보이지 않는 충돌 벽(떨어지지 않게)
	Kit.box(m, CFrame.lookAt((a + b) / 2 + up / 2, (a + b) / 2 + up / 2 + dir), Vector3.new(0.3, h, len), { invisible = true, tag = false })
	return m
end

-- 계단: bottomCenter(아래 첫 계단 앞 가운데, 바닥 높이) 에서 forward 방향으로 rise 만큼 올라간다.
-- 보이는 계단 판은 충돌 없음, 걷는 면은 보이지 않는 경사로.
function Kit.stairs(parent: Instance, bottomCenter: Vector3, forward: Vector3, width: number, rise: number, run: number, steps: number)
	local m = Instance.new("Model")
	m.Name = "Stairs"
	m.Parent = parent
	local f = Vector3.new(forward.X, 0, forward.Z).Unit
	local stepH = rise / steps
	local stepD = run / steps
	for i = 0, steps - 1 do
		local top = (i + 1) * stepH
		local c = bottomCenter + f * (stepD * (i + 0.5)) + Vector3.new(0, top / 2, 0)
		Kit.box(m, CFrame.lookAt(c, c + f), Vector3.new(width, top, stepD), { collide = false, blocks = i >= steps / 2 })
	end
	-- 경사로(쐐기): 경사가 forward 방향으로 올라가도록 뒤(+Z)를 forward 쪽으로
	local mid = bottomCenter + f * (run / 2) + Vector3.new(0, rise / 2, 0)
	Kit.wedge(m, CFrame.lookAt(mid, mid - f), Vector3.new(width, rise, run), { invisible = true, tag = false })
	return m
end

-- 아치 리브: center = 바닥 가운데, right = 가로 방향, 개구부 폭 2*inner, 스프링 높이 spring
-- 벽 사이에 걸치는 리브(기둥 + 반원 아치) 와 그 위 막힌 벽(header).
function Kit.archPortal(parent: Instance, center: Vector3, right: Vector3, span: number, spring: number, ceiling: number, ribDepth: number?)
	local m = Instance.new("Model")
	m.Name = "Arch"
	m.Parent = parent
	local depth = ribDepth or 1.4
	local r = right.Unit
	local fwd = r:Cross(Vector3.yAxis).Unit
	local half = span / 2
	local pier = 0.7
	local inner = half - pier
	local ring = 0.7
	local outer = inner + ring
	local basis = CFrame.fromMatrix(center, r, Vector3.yAxis) -- X = 가로, Z = 진행 방향
	-- 기둥(좌우)
	for _, s in { -1, 1 } do
		local x = s * (half - pier / 2)
		Kit.box(m, basis * CFrame.new(x, spring / 2, 0), Vector3.new(pier, spring, depth))
	end
	-- 반원 아치 조각
	local segs = 9
	for i = 0, segs - 1 do
		local a0 = math.pi * (i / segs)
		local a1 = math.pi * ((i + 1) / segs)
		local am = (a0 + a1) / 2
		local rm = (inner + outer) / 2
		local chord = 2 * outer * math.sin((a1 - a0) / 2)
		local px, py = math.cos(am) * rm, spring + math.sin(am) * rm
		local seg = basis * CFrame.new(px, py, 0) * CFrame.Angles(0, 0, am + math.pi / 2)
		Kit.box(m, seg, Vector3.new(chord, ring, depth), { axis = "X" })
	end
	-- 아치 위 막힌 벽(리브보다 얇게 → 리브가 튀어나와 윤곽이 보인다), 선 없는 채움
	local wallD = depth * 0.55
	local topY = spring + outer
	Kit.box(m, basis * CFrame.new(0, (topY + ceiling) / 2, 0), Vector3.new(span, ceiling - topY, wallD))
	-- 아치 옆 삼각 부분(스팬드럴)을 세로 띠로 채움
	local cols = 6
	for i = 0, cols - 1 do
		for _, s in { -1, 1 } do
			local x0 = (i / cols) * outer
			local x1 = ((i + 1) / cols) * outer
			-- (띠 바닥은 띠 구간에서 가장 낮은 아치 바깥 높이: 구멍 없이 아치 조각과 겹친다)
			local xm = math.min(x1, outer)
			local yArc = spring + math.sqrt(math.max(0, outer * outer - xm * xm)) - 0.05
			local h = topY - yArc
			if h > 0.05 then
				local cx = s * (x0 + x1) / 2
				Kit.box(m, basis * CFrame.new(cx, yArc + h / 2, 0), Vector3.new(x1 - x0 + 0.02, h, wallD), { shape = "None" })
			end
		end
		local _ = i
	end
	for _, s in { -1, 1 } do
		-- 바깥 원과 기둥 사이
		local x0, x1 = outer, half
		if x1 - x0 > 0.05 then
			Kit.box(m, basis * CFrame.new(s * (x0 + x1) / 2, (spring + topY) / 2, 0), Vector3.new(x1 - x0, topY - spring, wallD), { shape = "None" })
		end
	end
	return m
end

-- 상자(나무 상자 느낌: 모서리 + 가로 띠)
function Kit.crate(parent: Instance, bottom: Vector3, size: Vector3, yaw: number?)
	local cf = CFrame.new(bottom + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, yaw or 0, 0)
	local b = Kit.box(parent, cf, size, { name = "Crate" })
	-- 가운데 띠
	Kit.box(parent, cf, Vector3.new(size.X + 0.12, 0.3, size.Z + 0.12), { blocks = false })
	return b
end

-- 글자(EXIT 표지): 막대 조합. origin = 글자 왼쪽 아래, right/up = 벽면 방향, 글자 높이 h
function Kit.letter(parent: Instance, ch: string, origin: Vector3, right: Vector3, out: Vector3, h: number)
	local w = h * 0.62
	local t = h * 0.14
	local depth = 0.35
	local up = Vector3.yAxis
	local function bar(x0: number, y0: number, x1: number, y1: number)
		local a = origin + right * x0 + up * y0 + out * (depth / 2)
		local b = origin + right * x1 + up * y1 + out * (depth / 2)
		local d = b - a
		local len = d.Magnitude
		local cf = CFrame.fromMatrix((a + b) / 2, d.Unit, out:Cross(d.Unit).Unit)
		Kit.box(parent, cf, Vector3.new(len + t, t, depth), { blocks = false, collide = false })
	end
	local ht = t / 2
	if ch == "E" then
		bar(ht, ht, ht, h - ht)
		bar(ht, h - ht, w - ht, h - ht)
		bar(ht, h / 2, w * 0.8 - ht, h / 2)
		bar(ht, ht, w - ht, ht)
	elseif ch == "X" then
		bar(ht, ht, w - ht, h - ht)
		bar(ht, h - ht, w - ht, ht)
	elseif ch == "I" then
		bar(w / 2, ht, w / 2, h - ht)
	elseif ch == "T" then
		bar(ht, h - ht, w - ht, h - ht)
		bar(w / 2, ht, w / 2, h - ht)
	end
	return w
end

function Kit.word(parent: Instance, text: string, center: Vector3, right: Vector3, out: Vector3, h: number)
	local gap = h * 0.3
	local w = h * 0.62
	local total = #text * w + (#text - 1) * gap
	local x = -total / 2
	for i = 1, #text do
		local ch = text:sub(i, i)
		Kit.letter(parent, ch, center + right * x - Vector3.new(0, h / 2, 0), right, out, h)
		x += w + gap
	end
end

return Kit
