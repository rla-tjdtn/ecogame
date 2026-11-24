--!strict
-- 구조물 모양별 윤곽선(모서리) 데이터 생성.
--   Box      : 상자의 12개 모서리 (속성 SonarEdgeAxis = "X"/"Y"/"Z" 이면 그 축 방향 4개만 — 아치 조각, 이어진 난간 등)
--   Wedge    : 쐐기의 9개 모서리
--   Cylinder : 양 끝 원 + (속성 SonarRings 개수만큼) 중간 원 / 보는 위치 기준 실루엣 2줄은 viewEdges 에서
--   Ball     : 보는 위치 기준 실루엣 원(viewEdges)
--   Line     : 가장 긴 축을 따라 선 하나(속성 SonarShape = "Line"). 괴물처럼 가는 막대를 한 획으로 그릴 때
--   Disc     : 원통 가운데 원 하나(속성 SonarShape = "Disc"). 얇은 원판(눈, 둥근 머리)을 한 줄 원으로
--   None     : 선 없음(속성 SonarShape = "None")
-- MeshPart / Union 처럼 정확한 모서리를 얻기 어려운 것은 상자 프록시를 쓴다(SonarShape 속성으로 바꿀 수 있다).
--
-- 결과는 EdgeList 에 쌓는다: A[i]→B[i] 선분, N1[i]/N2[i] 는 그 모서리에 붙은 두 면의 바깥 법선
-- (이음매 제거 판정에 쓰며, 원통의 원처럼 판정이 필요 없는 선은 nil).

local Geo = {}
--   Mesh     : 소품 메시(속성 SonarShape = "Mesh", SonarMesh = 키). 선은 Shared/PropMeshData 에 미리 뽑아 둔 윤곽·꺾임선,
--              실루엣(원통·원뿔대·구)은 SonarWorld 가 viewParts 로 하나씩 올린다(Geo.meshViews)
local PropMeshData = require(script.Parent:WaitForChild("PropMeshData"))

export type EdgeList = {
	A: { Vector3 },
	B: { Vector3 },
	N1: { Vector3 | false },
	N2: { Vector3 | false },
	n: number,
}

function Geo.newList(): EdgeList
	return { A = {}, B = {}, N1 = {}, N2 = {}, n = 0 }
end

local function push(out: EdgeList, a: Vector3, b: Vector3, n1: Vector3?, n2: Vector3?)
	local i = out.n + 1
	out.n = i
	out.A[i] = a
	out.B[i] = b
	out.N1[i] = n1 or false
	out.N2[i] = n2 or false
end

function Geo.shapeOf(part: BasePart): string
	local forced = part:GetAttribute("SonarShape")
	if type(forced) == "string" then
		return forced
	end
	if part:IsA("WedgePart") then
		return "Wedge"
	end
	if part:IsA("Part") then
		local s = (part :: Part).Shape
		if s == Enum.PartType.Cylinder then
			return "Cylinder"
		elseif s == Enum.PartType.Ball then
			return "Ball"
		elseif s == Enum.PartType.Wedge then
			return "Wedge"
		end
	end
	return "Box"
end

local function ringSegments(r: number): number
	return math.clamp(math.floor(r * 5) + 6, 8, 24)
end

-- 상자 모서리. axisOnly: "X"/"Y"/"Z" 이면 그 축과 평행한 모서리만.
function Geo.boxEdges(cf: CFrame, size: Vector3, out: EdgeList, axisOnly: string?, noNormals: boolean?)
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local X, Y, Z = cf.XVector, cf.YVector, cf.ZVector
	local p = cf.Position
	for _, s1 in { -1, 1 } do
		for _, s2 in { -1, 1 } do
			-- X 방향 모서리 (y = s1, z = s2)
			if axisOnly == nil or axisOnly == "X" then
				local o = p + Y * (s1 * hy) + Z * (s2 * hz)
				if noNormals then
					push(out, o - X * hx, o + X * hx)
				else
					push(out, o - X * hx, o + X * hx, Y * s1, Z * s2)
				end
			end
			-- Y 방향 모서리 (x = s1, z = s2)
			if axisOnly == nil or axisOnly == "Y" then
				local o = p + X * (s1 * hx) + Z * (s2 * hz)
				if noNormals then
					push(out, o - Y * hy, o + Y * hy)
				else
					push(out, o - Y * hy, o + Y * hy, X * s1, Z * s2)
				end
			end
			-- Z 방향 모서리 (x = s1, y = s2)
			if axisOnly == nil or axisOnly == "Z" then
				local o = p + X * (s1 * hx) + Y * (s2 * hy)
				if noNormals then
					push(out, o - Z * hz, o + Z * hz)
				else
					push(out, o - Z * hz, o + Z * hz, X * s1, Y * s2)
				end
			end
		end
	end
end

-- 쐐기: 바닥(-Y) 전체, 뒷면(+Z) 전체 높이, 경사면은 앞(-Z) 아래쪽에서 뒤(+Z) 위쪽으로 올라간다.
function Geo.wedgeEdges(cf: CFrame, size: Vector3, out: EdgeList, noNormals: boolean?)
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local X, Y, Z = cf.XVector, cf.YVector, cf.ZVector
	local p = cf.Position
	local slopeN = (Y * hz - Z * hy).Unit
	local function v(x: number, y: number, z: number): Vector3
		return p + X * x + Y * y + Z * z
	end
	local function e(a: Vector3, b: Vector3, n1: Vector3, n2: Vector3)
		if noNormals then
			push(out, a, b)
		else
			push(out, a, b, n1, n2)
		end
	end
	e(v(-hx, -hy, -hz), v(hx, -hy, -hz), -Y, slopeN) -- 앞 아래
	e(v(-hx, -hy, hz), v(hx, -hy, hz), -Y, Z) -- 뒤 아래
	e(v(-hx, hy, hz), v(hx, hy, hz), Z, slopeN) -- 꼭대기
	for _, s in { -1, 1 } do
		local x = s * hx
		e(v(x, -hy, hz), v(x, hy, hz), X * s, Z) -- 뒤 세로
		e(v(x, -hy, -hz), v(x, -hy, hz), X * s, -Y) -- 옆 아래
		e(v(x, -hy, -hz), v(x, hy, hz), X * s, slopeN) -- 옆 경사
	end
end

local function circle(center: Vector3, u: Vector3, w: Vector3, r: number, segs: number, out: EdgeList)
	local prev = center + u * r
	for i = 1, segs do
		local t = (i / segs) * math.pi * 2
		local cur = center + u * (math.cos(t) * r) + w * (math.sin(t) * r)
		push(out, prev, cur)
		prev = cur
	end
end

-- 원통(축 = 로컬 X): 양 끝 원과 중간 원
function Geo.cylinderRings(cf: CFrame, size: Vector3, out: EdgeList, rings: number?)
	local r = math.min(size.Y, size.Z) / 2
	local hx = size.X / 2
	local thin = r < 0.3
	if thin then
		return -- 가는 원통(난간, 기둥 살)은 실루엣만
	end
	local segs = ringSegments(r)
	local count = (rings or 0)
	for i = 0, count + 1 do
		local x = -hx + (2 * hx) * (i / (count + 1))
		circle(cf.Position + cf.XVector * x, cf.YVector, cf.ZVector, r, segs, out)
	end
end

-- 원통의 실루엣 2줄(보는 위치 기준)
function Geo.cylinderSilhouette(cf: CFrame, size: Vector3, view: Vector3, out: EdgeList)
	local r = math.min(size.Y, size.Z) / 2
	local hx = size.X / 2
	local lv = cf:PointToObjectSpace(view)
	local d = math.sqrt(lv.Y * lv.Y + lv.Z * lv.Z)
	if d <= r * 1.02 then
		return
	end
	local phi0 = math.atan2(lv.Z, lv.Y)
	local theta = math.acos(r / d)
	for _, s in { -1, 1 } do
		local phi = phi0 + s * theta
		local y, z = math.cos(phi) * r, math.sin(phi) * r
		push(out, cf:PointToWorldSpace(Vector3.new(-hx, y, z)), cf:PointToWorldSpace(Vector3.new(hx, y, z)))
	end
	-- 가는 원통은 끝을 짧은 가로선으로 닫는다(난간 끝, 기둥 살 끝)
	if r < 0.3 then
		local a = Vector3.new(0, math.cos(phi0 + theta) * r, math.sin(phi0 + theta) * r)
		local b = Vector3.new(0, math.cos(phi0 - theta) * r, math.sin(phi0 - theta) * r)
		for _, x in { -hx, hx } do
			local o = Vector3.new(x, 0, 0)
			push(out, cf:PointToWorldSpace(o + a), cf:PointToWorldSpace(o + b))
		end
	end
end

-- 구의 실루엣 원(보는 위치 기준)
function Geo.ballSilhouette(cf: CFrame, size: Vector3, view: Vector3, out: EdgeList)
	local r = math.min(size.X, size.Y, size.Z) / 2
	local c = cf.Position
	local toC = c - view
	local D = toC.Magnitude
	if D <= r * 1.05 then
		return
	end
	local dir = toC / D
	local cc = c - dir * (r * r / D)
	local rr = r * math.sqrt(1 - (r * r) / (D * D))
	local u = dir:Cross(Vector3.yAxis)
	if u.Magnitude < 0.01 then
		u = dir:Cross(Vector3.xAxis)
	end
	u = u.Unit
	local w = dir:Cross(u).Unit
	circle(cc, u, w, rr, ringSegments(r), out)
end

-- 보는 위치와 상관없는 모서리(정적 데이터로 미리 만들어 둔다)
function Geo.staticEdges(part: BasePart, out: EdgeList, noNormals: boolean?)
	local shape = Geo.shapeOf(part)
	local cf, size = part.CFrame, part.Size
	if shape == "Box" then
		local axis = part:GetAttribute("SonarEdgeAxis")
		Geo.boxEdges(cf, size, out, if type(axis) == "string" then axis else nil, noNormals)
	elseif shape == "Wedge" then
		Geo.wedgeEdges(cf, size, out, noNormals)
	elseif shape == "Line" then
		local s = size
		local axis = if s.X >= s.Y and s.X >= s.Z then cf.XVector * (s.X / 2) elseif s.Y >= s.Z then cf.YVector * (s.Y / 2) else cf.ZVector * (s.Z / 2)
		push(out, cf.Position - axis, cf.Position + axis)
	elseif shape == "Disc" then
		local r = math.min(size.Y, size.Z) / 2
		circle(cf.Position, cf.YVector, cf.ZVector, r, ringSegments(r), out)
	elseif shape == "Cylinder" then
		local rings = part:GetAttribute("SonarRings")
		Geo.cylinderRings(cf, size, out, if type(rings) == "number" then rings else nil)
	elseif shape == "Mesh" then
		local key = part:GetAttribute("SonarMesh")
		local item = if type(key) == "string" then PropMeshData.get(key) else nil
		if item then
			local sc = size / item.size
			local s = item.seg
			for i = 1, #s, 6 do
				push(out, cf * Vector3.new(s[i] * sc.X, s[i + 1] * sc.Y, s[i + 2] * sc.Z), cf * Vector3.new(s[i + 3] * sc.X, s[i + 4] * sc.Y, s[i + 5] * sc.Z))
			end
		end
	end
end

-- 메시 소품의 실루엣 항목: fn(cf, size, ball, taper) — cf·size 는 원통 파트처럼(축 = 로컬 X), taper = 끝 반지름 / 시작 반지름
function Geo.meshViews(part: BasePart, fn: (cf: CFrame, size: Vector3, ball: boolean, taper: number?) -> ())
	local key = part:GetAttribute("SonarMesh")
	local item = if type(key) == "string" then PropMeshData.get(key) else nil
	if not item then
		return
	end
	local cf = part.CFrame
	local sc = part.Size / item.size
	local rs = math.min(sc.X, sc.Y, sc.Z)
	local v = item.view
	for i = 1, #v, 9 do
		local a = cf * Vector3.new(v[i + 1] * sc.X, v[i + 2] * sc.Y, v[i + 3] * sc.Z)
		local r1 = v[i + 7] * rs
		if v[i] == 1 then
			fn(CFrame.new(a), Vector3.one * (r1 * 2), true, nil)
		else
			local b = cf * Vector3.new(v[i + 4] * sc.X, v[i + 5] * sc.Y, v[i + 6] * sc.Z)
			local d = b - a
			local L = d.Magnitude
			if L > 0.02 and r1 > 0.005 then
				local dir = d / L
				local up = if math.abs(dir.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
				local r2 = v[i + 8] * rs
				fn(CFrame.fromMatrix((a + b) / 2, dir, dir:Cross(up).Unit), Vector3.new(L, r1 * 2, r1 * 2), false, if math.abs(r2 - r1) > 0.01 then r2 / r1 else nil)
			end
		end
	end
end

-- 원뿔대 실루엣 2줄: 원통 실루엣과 같고 +X 끝 반지름만 taper 배
function Geo.coneSilhouette(cf: CFrame, size: Vector3, taper: number, view: Vector3, out: EdgeList)
	local r = math.min(size.Y, size.Z) / 2
	local r2 = r * taper
	local rm = (r + r2) / 2
	local hx = size.X / 2
	local lv = cf:PointToObjectSpace(view)
	local d = math.sqrt(lv.Y * lv.Y + lv.Z * lv.Z)
	if d <= rm * 1.02 then
		return
	end
	local phi0 = math.atan2(lv.Z, lv.Y)
	local theta = math.acos(rm / d)
	for _, s in { -1, 1 } do
		local phi = phi0 + s * theta
		local cy, cz = math.cos(phi), math.sin(phi)
		push(out, cf:PointToWorldSpace(Vector3.new(-hx, cy * r, cz * r)), cf:PointToWorldSpace(Vector3.new(hx, cy * r2, cz * r2)))
	end
end

-- 보는 위치에 따라 달라지는 선(원통·구의 실루엣)
function Geo.viewEdges(part: BasePart, view: Vector3, out: EdgeList)
	local shape = Geo.shapeOf(part)
	if shape == "Cylinder" then
		Geo.cylinderSilhouette(part.CFrame, part.Size, view, out)
	elseif shape == "Ball" then
		Geo.ballSilhouette(part.CFrame, part.Size, view, out)
	end
end

function Geo.hasViewEdges(part: BasePart): boolean
	local shape = Geo.shapeOf(part)
	return shape == "Cylinder" or shape == "Ball"
end

-- 점이 파트 안에 있는가(이음매 제거, 복셀화에 사용)
function Geo.pointInside(part: BasePart, p: Vector3, pad: number?): boolean
	local lp = part.CFrame:PointToObjectSpace(p)
	local s = part.Size
	local m = pad or 0
	local shape = Geo.shapeOf(part)
	if shape == "Cylinder" then
		local r = math.min(s.Y, s.Z) / 2 + m
		return math.abs(lp.X) <= s.X / 2 + m and (lp.Y * lp.Y + lp.Z * lp.Z) <= r * r
	elseif shape == "Ball" then
		local r = math.min(s.X, s.Y, s.Z) / 2 + m
		return lp.Magnitude <= r
	end
	if math.abs(lp.X) > s.X / 2 + m or math.abs(lp.Y) > s.Y / 2 + m or math.abs(lp.Z) > s.Z / 2 + m then
		return false
	end
	if shape == "Wedge" then
		-- 경사면 아래(뒤)쪽만 속이 차 있다
		local hy, hz = s.Y / 2, s.Z / 2
		-- 경사면: (y + hy) * (2hz) <= (z + hz) * (2hy)
		return (lp.Y + hy) * hz <= (lp.Z + hz) * hy + m * math.max(hy, hz) * 1.5
	end
	return true
end

return Geo
