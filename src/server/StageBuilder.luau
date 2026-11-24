--!strict
-- 타일 레이아웃(문자 격자)으로 스테이지 지형을 짓는다. 모든 스테이지가 같은 빌더와 MapKit 부품을 쓴다.
-- 타일 1칸 = 8스터드. 위층 바닥 y=0, 구덩이(아래층) 바닥 y=-6, 천장 y=14.
--
-- 공통 타일 문자
--   #  벽            .  바닥          S  시작 지점       E  출구
--   D  문(복도를 가로지르는 벽 + 문)   A  아치 리브       O  기둥
--   c  상자 더미      m  기계 설비     v  수직 배관 묶음  f  천장 환풍기
--   p  구덩이(아래층) b  구덩이 위 철제 다리             s  계단(구덩이 ↔ 위층)
--   1  2층 계단 아래 칸(바닥 0 → 6)   2  2층 계단 위 칸(6 → 12). 1 은 1층 칸, 2 는 2층 칸과 맞닿는다.
-- 2층: layout.UpperRects 의 직사각형(타일 좌표 {i0, j0, i1, j1}) 안 칸은 바닥이 y=12(UP)이고 천장이 y=26.
--   2층 칸은 1층 칸 위에 겹쳐 쌓지 않고 같은 격자의 다른 구역에 높게 짓는다(벽으로 막혀 있으니 음파로는 구별되지 않는다).
--   center(i, j) 의 y 가 그 칸의 바닥 기준 높이라서, 소품 함수는 floorY·H 를 그대로 상대 높이로 쓰면 된다.
-- 스테이지별 추가 타일은 레이아웃 모듈의 Props 함수로 짓는다(같은 ctx 를 받는다).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.MapKit)
local Doors = require(script.Parent.Doors)
local Hiding = require(script.Parent.Hiding)
local Search = require(script.Parent.Search)

local Builder = {}

local T = 8
local H = 14
local PIT_Y = -6
local BOTTOM = -10
local UP = 12 -- 2층 바닥 높이
Builder.Tile = T
Builder.Height = H
Builder.PitY = PIT_Y
Builder.Up = UP

export type Layout = {
	Rows: { string },
	Props: { [string]: (ctx: any, i: number, j: number) -> () }?,
	Walkable: { [string]: boolean }?, -- Props 타일 중 괴물 배회 지점으로 쓸 수 있는 것
	PitTiles: { [string]: boolean }?, -- Props 타일 중 아래층 높이인 것
	PipeChance: number?,
	HideStyle: string?,
	SearchStyle: string?, -- 상자·서랍(Z) 모양: drawers / crate / toolbox / nightstand / chest (Search.Styles) -- 숨는 곳(L) 모양: locker / tool / rusty / wardrobe / closet (Hiding.Styles)
	Seed: number?,
	UpperRects: { { number } }?, -- 2층 구역(타일 좌표 {i0, j0, i1, j1})
}

export type StageInfo = {
	folder: Folder,
	spawns: { CFrame },
	exitCFrame: CFrame,
	exitSize: Vector3,
	nodes: { Vector3 },
	bounds: { min: Vector3, max: Vector3 },
	-- 타일 격자 위 최단 경로(타일 가운데 바닥 높이 좌표들). PathfindingService 는 시작·목표 주변만 탐색하므로
	-- 큰 맵에서 멀리 돌아가야 하는 길은 이 경로를 짧은 구간으로 나눠 계산한다. monster = true 면 좁은 다리(n) 제외
	route: (from: Vector3, to: Vector3, monster: boolean?) -> { Vector3 }?,
}

local PIT = { p = true, b = true, s = true, n = true }
local function bridgeChar(c: string): boolean
	return c == "b" or c == "n"
end

local function hash(a: number, b: number, c: number): number
	local h = bit32.bxor(bit32.bxor((a * 73856093) % 4294967296, (b * 19349663) % 4294967296), (c * 83492791) % 4294967296)
	return (h % 1000) / 1000
end

-- 한 층(격자 하나)을 짓는다. fl 이 있으면 겹쳐 쌓는 2층 건물의 한 층:
--   fl.rows 이 층 격자, fl.y0 바닥 높이(1층 0, 2층 UP), fl.Hc 이 층 천장 높이, fl.above(1층일 때 2층 격자: 계단 구멍 o 위치·계단 도착 칸),
--   fl.below(2층일 때 1층 격자: 계단 구멍 난간), fl.folder(2층은 1층 폴더에 함께 짓는다)
type Floor = { rows: { string }, y0: number, Hc: number, above: { string }?, below: { string }?, folder: Folder? }
local function buildGrid(layout: Layout, parent: Instance?, name: string, fl: Floor?): StageInfo
	local rows = if fl then fl.rows else layout.Rows
	local H = if fl then fl.Hc else H
	local Y0 = if fl then fl.y0 else 0
	local above = fl and fl.above
	local below = fl and fl.below
	local function rowAt(rs: { string }?, i: number, j: number): string
		if not rs or j < 1 or j > #rs or i < 1 or i > #rs[1] then
			return "#"
		end
		return rs[j]:sub(i, i)
	end
	-- 2층 바닥 칸(1층 격자에서 본 위층): 벽도 계단 구멍도 아니다
	local function aboveFloor(i: number, j: number): boolean
		local c = rowAt(above, i, j)
		return above ~= nil and c ~= "#" and c ~= "o"
	end
	local nz = #rows
	local nx = #rows[1]
	local grid: { { string } } = {}
	for j = 1, nz do
		grid[j] = {}
		for i = 1, nx do
			grid[j][i] = rows[j]:sub(i, i)
		end
	end
	local function at(i: number, j: number): string
		if j < 1 or j > nz or i < 1 or i > nx then
			return "#"
		end
		return grid[j][i]
	end
	local pitSet = table.clone(PIT)
	for k, v in layout.PitTiles or {} do
		pitSet[k] = v
	end
	local function isWall(i: number, j: number): boolean
		return at(i, j) == "#"
	end
	local function isPit(i: number, j: number): boolean
		return pitSet[at(i, j)] == true
	end
	local function floorY(i: number, j: number): number
		return if isPit(i, j) then PIT_Y else 0
	end
	-- 2층 구역
	local upperSet: { [number]: boolean } = {}
	local hasUpper = false
	for _, r in layout.UpperRects or {} do
		for j = r[2], r[4] do
			for i = r[1], r[3] do
				upperSet[j * 1000 + i] = true
				hasUpper = true
			end
		end
	end
	local function isFlight(i: number, j: number): boolean
		local c = at(i, j)
		return c == "1" or c == "2"
	end
	-- 이 칸의 바닥 기준 높이(1층 0, 계단 위 칸 6, 2층 12)
	local function base(i: number, j: number): number
		local c = at(i, j)
		if c == "1" then
			return 0
		elseif c == "2" then
			return UP / 2
		end
		return if upperSet[j * 1000 + i] then UP else 0
	end
	local function isUpper(i: number, j: number): boolean
		return upperSet[j * 1000 + i] == true and not isFlight(i, j)
	end
	-- 타일 (i, j) 의 가운데(x,z, y = 그 칸의 바닥 기준 높이). i = 열(x), j = 행(z)
	local function center(i: number, j: number): Vector3
		return Vector3.new((i - 1) * T + T / 2, base(i, j) + Y0, (j - 1) * T + T / 2)
	end
	local TOP = if hasUpper then UP + H else H

	local folder = if fl and fl.folder then fl.folder else Instance.new("Folder")
	folder.Name = name
	local geo = folder:FindFirstChild("Geometry") :: Folder?
	if not geo then
		geo = Instance.new("Folder")
		;(geo :: Folder).Name = "Geometry"
		;(geo :: Folder).Parent = folder
	end
	local props = folder:FindFirstChild("Props") :: Folder?
	if not props then
		props = Instance.new("Folder")
		;(props :: Folder).Name = "Props"
		;(props :: Folder).Parent = folder
	end
	local geo = geo :: Folder
	local props = props :: Folder

	-- ── 직사각형 병합(같은 종류 타일을 큰 상자 하나로) ──
	local function merge(pred: (i: number, j: number) -> boolean): { { number } }
		local used: { [number]: boolean } = {}
		local rects = {}
		for j = 1, nz do
			for i = 1, nx do
				if not used[j * 1000 + i] and pred(i, j) then
					local i1 = i
					while i1 + 1 <= nx and pred(i1 + 1, j) and not used[j * 1000 + i1 + 1] do
						i1 += 1
					end
					local j1 = j
					local grow = true
					while grow and j1 + 1 <= nz do
						for x = i, i1 do
							if not pred(x, j1 + 1) or used[(j1 + 1) * 1000 + x] then
								grow = false
								break
							end
						end
						if grow then
							j1 += 1
						end
					end
					for y = j, j1 do
						for x = i, i1 do
							used[y * 1000 + x] = true
						end
					end
					table.insert(rects, { i, j, i1, j1 })
				end
			end
		end
		return rects
	end
	local function rectSpan(r: { number }, y0: number, y1: number, opts: Kit.Opts?)
		local lo = Vector3.new((r[1] - 1) * T, y0, (r[2] - 1) * T)
		local hi = Vector3.new(r[3] * T, y1, r[4] * T)
		return Kit.span(geo, lo, hi, opts)
	end

	-- 벽 덩어리, 위층 바닥(벽 아래 포함), 아래층 바닥, 천장
	for _, r in merge(function(i, j) return isWall(i, j) end) do
		rectSpan(r, Y0, Y0 + TOP, { name = "Wall" })
	end
	-- (겹쳐 쌓은 2층: 바닥은 1층을 지을 때 층 사이 판으로 이미 깔았다)
	for _, top in if below then {} else { 0, UP / 2, UP } do
		for _, r in merge(function(i, j) return not isPit(i, j) and not isWall(i, j) and base(i, j) == top end) do
			rectSpan(r, BOTTOM, top, { name = if top == UP then "UpperFloor" else "Floor" })
		end
	end
	if not below then
		for _, r in merge(function(i, j) return isWall(i, j) end) do
			rectSpan(r, BOTTOM, 0, { name = "Floor" })
		end
		for _, r in merge(function(i, j) return isPit(i, j) end) do
			rectSpan(r, BOTTOM, PIT_Y, { name = "PitFloor" })
		end
	end
	if above then
		-- 겹쳐 쌓은 1층: 천장 = 층 사이 판(1층 천장 H ~ 2층 바닥 UP). 계단 위(2층 격자의 o)만 뚫는다
		for _, r in merge(function(i, j) return rowAt(above, i, j) ~= "o" end) do
			rectSpan(r, H, UP, { name = "UpperFloor" })
		end
	elseif below then
		Kit.span(geo, Vector3.new(0, Y0 + H, 0), Vector3.new(nx * T, Y0 + H + 2, nz * T), { name = "Ceiling" })
	elseif hasUpper then
		-- 1층 천장(1층·구덩이 칸 위만) + 맨 위 천장(2층과 계단실 위)
		for _, r in merge(function(i, j) return not isWall(i, j) and not isFlight(i, j) and not isUpper(i, j) end) do
			rectSpan(r, H, H + 2, { name = "Ceiling" })
		end
		Kit.span(geo, Vector3.new(0, TOP, 0), Vector3.new(nx * T, TOP + 2, nz * T), { name = "Ceiling" })
	else
		Kit.span(geo, Vector3.new(0, H, 0), Vector3.new(nx * T, H + 2, nz * T), { name = "Ceiling" })
	end

	local dirs = {
		{ di = 1, dj = 0, v = Vector3.new(1, 0, 0) },
		{ di = -1, dj = 0, v = Vector3.new(-1, 0, 0) },
		{ di = 0, dj = 1, v = Vector3.new(0, 0, 1) },
		{ di = 0, dj = -1, v = Vector3.new(0, 0, -1) },
	}

	local info: StageInfo = {
		folder = folder,
		spawns = {},
		exitCFrame = CFrame.new(),
		exitSize = Vector3.new(6, 8, 6),
		nodes = {},
		bounds = { min = Vector3.new(0, BOTTOM, 0), max = Vector3.new(nx * T, Y0 + TOP + 2, nz * T) },
		route = nil,
	}

	-- ── 타일 경로(tools/check-layout.js 와 같은 규칙: 구덩이 = 아래층, 다리 = 위층, 계단 = 둘 다) ──
	-- (벽에 붙은 상자 더미 c·모서리 배관 v 는 칸 절반 이상이 비어 있어 지나갈 수 있다: tools/level-graph.js 와 같은 규칙)
	local passable: { [string]: boolean } = { ["."] = true, S = true, E = true, D = true, A = true, f = true, s = true, ["1"] = true, ["2"] = true, c = true, v = true } -- (P 등 소품 문자는 레이아웃 Walkable 에 적은 것만)
	for k in pitSet do
		passable[k] = true
	end
	for k, v in layout.Walkable or {} do
		passable[k] = v
	end
	local function levels(c: string): { number }
		if pitSet[c] then
			if bridgeChar(c) then
				return { 0 }
			elseif c == "s" then
				return { 0, 1 }
			end
			return { 1 }
		end
		return { 0 }
	end
	-- 층 번호: 0 = 1층, 1 = 구덩이(아래층), 2 = 2층. 계단 1 칸은 1층, 2 칸은 2층으로 치고 둘 사이를 건너면 층이 바뀐다
	local function levelsAt(i: number, j: number): { number }
		local c = at(i, j)
		if c == "1" then
			return { 0 }
		elseif c == "2" or upperSet[j * 1000 + i] then
			return { 2 }
		end
		return levels(c)
	end
	local function hasLevel(i: number, j: number, l: number): boolean
		for _, x in levelsAt(i, j) do
			if x == l then
				return true
			end
		end
		return false
	end
	info.route = function(from: Vector3, to: Vector3, monster: boolean?): { Vector3 }?
		local function tileOf(p: Vector3): (number, number, number)
			local i, j = math.floor(p.X / T) + 1, math.floor(p.Z / T) + 1
			local l = if p.Y < PIT_Y / 2 then 1 elseif p.Y > UP - 4 then 2 else 0
			if not hasLevel(i, j, l) then
				l = levelsAt(i, j)[1]
			end
			return i, j, l
		end
		local si, sj, sl = tileOf(from)
		local gi, gj, gl = tileOf(to)
		if not passable[at(si, sj)] or not passable[at(gi, gj)] then
			return nil
		end
		local function k(i: number, j: number, l: number): number
			return (l * nz + (j - 1)) * (nx + 2) + i
		end
		local prev: { [number]: number } = { [k(si, sj, sl)] = -1 }
		local q = { { si, sj, sl } }
		local head = 1
		local found = false
		while head <= #q do
			local cur = q[head]
			head += 1
			local i, j, l = cur[1], cur[2], cur[3]
			if i == gi and j == gj and l == gl then
				found = true
				break
			end
			local here = k(i, j, l)
			if at(i, j) == "s" then
				local other = k(i, j, 1 - l)
				if prev[other] == nil then
					prev[other] = here
					table.insert(q, { i, j, 1 - l })
				end
			end
			local here_c = at(i, j)
			for _, d in dirs do
				local ni, nj = i + d.di, j + d.dj
				local c = at(ni, nj)
				local nl = l
				-- 계단 아래 칸(1) ↔ 위 칸(2): 층이 바뀐다
				if (here_c == "1" and c == "2") or (here_c == "2" and c == "1") then
					nl = levelsAt(ni, nj)[1]
				end
				if passable[c] and not (monster and c == "n") and hasLevel(ni, nj, nl) then
					local nk = k(ni, nj, nl)
					if prev[nk] == nil then
						prev[nk] = here
						table.insert(q, { ni, nj, nl })
					end
				end
			end
		end
		if not found then
			return nil
		end
		local out = {}
		local cur = k(gi, gj, gl)
		while cur ~= -1 do
			local l = cur // ((nx + 2) * nz)
			local rest = cur % ((nx + 2) * nz)
			local j, i = rest // (nx + 2) + 1, rest % (nx + 2)
			local y = if l == 1 then PIT_Y else 0
			if at(i, j) == "s" then
				y = PIT_Y / 2
			elseif isFlight(i, j) then
				y = UP / 4 -- (계단 칸 가운데 높이: center 의 y 가 그 칸 아래 끝)
			end
			table.insert(out, 1, center(i, j) + Vector3.new(0, y + 0.5, 0))
			cur = prev[cur]
		end
		return out
	end

	local ctx = {
		Kit = Kit,
		Doors = Doors,
		props = props,
		geo = geo,
		at = at,
		center = center,
		floorY = floorY,
		isWall = isWall,
		isPit = isPit,
		T = T,
		H = H,
		PIT_Y = PIT_Y,
		info = info,
		hash = hash,
	}

	-- 이 타일에서 벽이 있는 방향 목록
	local function wallSides(i: number, j: number)
		local out = {}
		for _, d in dirs do
			if isWall(i + d.di, j + d.dj) then
				table.insert(out, d)
			end
		end
		return out
	end
	-- 복도 방향: 양옆이 벽이면 진행 방향 벡터
	local function corridorAxis(i: number, j: number): Vector3?
		local wx = isWall(i - 1, j) and isWall(i + 1, j)
		local wz = isWall(i, j - 1) and isWall(i, j + 1)
		if wx and not wz then
			return Vector3.new(0, 0, 1)
		elseif wz and not wx then
			return Vector3.new(1, 0, 0)
		end
		return nil
	end

	-- ── 벽면 장식: 벽기둥(필라스터), 천장 모서리 경사, 벽 배관 ──
	local pipeChance = layout.PipeChance or 0.55
	local seed = layout.Seed or 1
	for j = 1, nz do
		for i = 1, nx do
			local ch = at(i, j)
			if ch ~= "#" and ch ~= "o" and not isFlight(i, j) then
				local fy = floorY(i, j)
				local c = center(i, j)
				for _, d in wallSides(i, j) do
					local n = -d.v -- 벽면이 방을 향하는 법선
					local along = Vector3.new(d.v.Z, 0, -d.v.X) -- 벽을 따라가는 방향
					local face = c + d.v * (T / 2) -- 벽면 가운데(바닥 높이 0)
					-- 벽기둥: 이 타일의 시작 모서리에, 다음 타일도 같은 쪽에 벽이 있을 때
					local ni, nj = i - math.round(along.X), j - math.round(along.Z)
					if at(ni, nj) ~= "#" and isWall(ni + d.di, nj + d.dj) and floorY(ni, nj) == fy then
						local p = face - along * (T / 2) + n * 0.25
						Kit.box(geo, CFrame.lookAt(p + Vector3.new(0, (fy + H) / 2, 0), p + Vector3.new(0, (fy + H) / 2, 0) + n), Vector3.new(1.1, H - fy, 0.5), { name = "Pilaster" })
					end
					-- 천장 모서리 경사(쐐기): 바닥면이 천장에, 뒷면이 벽에 붙는다
					if ch ~= "D" and ch ~= "A" and ch ~= "E" then
						local s = 1.4
						local pos = face + n * (s / 2) + Vector3.new(0, H - s / 2, 0)
						local vY = Vector3.new(0, -1, 0)
						local vZ = -n
						Kit.wedge(geo, CFrame.fromMatrix(pos, vY:Cross(vZ), vY, vZ), Vector3.new(T, s, s), { name = "Haunch", collide = false, blocks = false })
					end
					-- 벽 배관: 같은 벽 줄(행/열 + 방향)마다 정해진 확률로, 줄 전체에 이어진다
					local lineKey = if math.abs(d.v.X) > 0 then i * 2 + (if d.v.X > 0 then 1 else 0) else j * 2 + (if d.v.Z > 0 then 1 else 0)
					local axisKey = if math.abs(d.v.X) > 0 then 1 else 2
					if hash(lineKey, axisKey, seed) < pipeChance and ch ~= "D" and ch ~= "A" and ch ~= "E" and ch ~= "S" then
						local r = 0.5
						local y = H - 3
						local off = n * (r + 0.9)
						local a = face - along * (T / 2) + off + Vector3.new(0, y, 0)
						local b = face + along * (T / 2) + off + Vector3.new(0, y, 0)
						Kit.pipe(props, a, b, r, { 0 }, true)
						-- 벽 고정 브래킷
						local bc = face + n * 0.6 + Vector3.new(0, y, 0)
						Kit.box(props, CFrame.lookAt(bc, bc + n), Vector3.new(0.3, 0.3, 1.2), { blocks = false, collide = false })
						-- 다음 타일에서 벽이 끊기면 배관을 벽 속으로 꺾어 넣는다
						for _, sgn in { -1, 1 } do
							local ti, tj = i + math.round(along.X) * sgn, j + math.round(along.Z) * sgn
							local continues = at(ti, tj) ~= "#" and isWall(ti + d.di, tj + d.dj) and not (at(ti, tj) == "D" or at(ti, tj) == "A" or at(ti, tj) == "E" or at(ti, tj) == "S")
							if not continues then
								local endP = if sgn > 0 then b else a
								local inner = endP - along * sgn * 0.6
								if isWall(ti, tj) then
									-- 앞이 벽이면 그 벽으로 들어간다(배관이 이미 닿음)
									local _ = inner
								else
									Kit.cylinder(props, inner, inner - n * (r + 1.2), r, { blocks = false })
								end
							end
						end
						-- 가는 전선관(위쪽)
						if hash(lineKey, axisKey, seed + 7) < 0.5 then
							local off2 = n * 0.45
							local a2 = face - along * (T / 2) + off2 + Vector3.new(0, H - 1.9, 0)
							local b2 = face + along * (T / 2) + off2 + Vector3.new(0, H - 1.9, 0)
							Kit.cylinder(props, a2, b2, 0.16, { blocks = false, collide = false })
						end
					end
				end
			end
		end
	end

	-- ── 타일별 구조물 ──
	for j = 1, nz do
		for i = 1, nx do
			local ch = at(i, j)
			local c = center(i, j)
			local fy = floorY(i, j)
			local axis = corridorAxis(i, j)
			if ch == "S" then
				local look = Vector3.new(nx * T / 2, 0, nz * T / 2)
				local p = c + Vector3.new(0, 3.2, 0)
				for k = 0, 1 do
					local off = Vector3.new(if k == 0 then -1.6 else 1.6, 0, 0)
					table.insert(info.spawns, CFrame.lookAt(p + off, Vector3.new(look.X, p.Y, look.Z)))
				end
			elseif ch == "E" then
				-- 들어오는 방향(바닥 이웃)
				local entry = dirs[1]
				for _, d in dirs do
					if not isWall(i + d.di, j + d.dj) then
						entry = d
					end
				end
				local back = -entry.v -- 출구 안쪽 끝 벽 방향
				local right = Vector3.new(back.Z, 0, -back.X)
				-- 입구 문틀(두꺼운 이중 프레임)
				local gate = c + entry.v * (T / 2 - 0.6)
				for _, s in { -1, 1 } do
					for k = 0, 1 do
						local p = gate + right * s * (3.2 + k * 0.6) + Vector3.new(0, 5, 0) - entry.v * k * 0.4
						Kit.box(geo, CFrame.lookAt(p, p + entry.v), Vector3.new(0.5, 10, 1.2), { name = "ExitFrame" })
					end
				end
				Kit.box(geo, CFrame.lookAt(gate + Vector3.new(0, 10.4, 0), gate + Vector3.new(0, 10.4, 0) + entry.v), Vector3.new(8, 0.8, 1.2), { name = "ExitLintel" })
				Kit.box(geo, CFrame.lookAt(gate + Vector3.new(0, 11.6, 0), gate + Vector3.new(0, 11.6, 0) + entry.v), Vector3.new(8, 1.6, 0.6))
				-- EXIT 글자(안쪽 벽)
				local wallFace = c + back * (T / 2 - 0.01)
				Kit.word(props, "EXIT", wallFace + Vector3.new(0, 8.5, 0) - right * 0.7, -right, -back, 1.4)
				-- 사다리와 천장 해치
				local lad = wallFace - back * 0.6 + right * 3.0
				for _, s in { -0.7, 0.7 } do
					Kit.cylinder(props, lad + right * s, lad + right * s + Vector3.new(0, H, 0), 0.1, { blocks = false })
				end
				for y = 1, H - 1, 1.2 do
					Kit.cylinder(props, lad + right * -0.7 + Vector3.new(0, y, 0), lad + right * 0.7 + Vector3.new(0, y, 0), 0.07, { blocks = false, collide = false })
				end
				local hatch = lad + back * 0.4 + Vector3.new(0, H - 0.2, 0)
				for _, s in { -1, 1 } do
					Kit.box(props, CFrame.lookAt(hatch + right * s * 1.4, hatch + right * s * 1.4 + back), Vector3.new(0.3, 0.4, 3.0), { blocks = false, collide = false })
					Kit.box(props, CFrame.lookAt(hatch + back * s * 1.4, hatch + back * s * 1.4 + right), Vector3.new(0.3, 0.4, 3.0), { blocks = false, collide = false })
				end
				info.exitCFrame = CFrame.lookAt(c + Vector3.new(0, 4, 0) + back * 0.8, c + Vector3.new(0, 4, 0) + back * 2)
				info.exitSize = Vector3.new(T - 1, 8, T - 2.5)
			elseif ch == "D" then
				local ax = axis or Vector3.new(1, 0, 0)
				local across = Vector3.new(ax.Z, 0, -ax.X)
				local doorW, doorH, thick = 5, 9, 2
				-- 문 벽: 문 양옆과 문 위
				local sideW = (T - doorW) / 2
				for _, s in { -1, 1 } do
					local p = c + across * s * (doorW / 2 + sideW / 2) + Vector3.new(0, H / 2, 0)
					Kit.box(geo, CFrame.lookAt(p, p + ax), Vector3.new(sideW, H, thick), { name = "DoorWall" })
					-- 문틀(양쪽으로 튀어나온 문설주)
					local jp = c + across * s * (doorW / 2 + 0.25) + Vector3.new(0, doorH / 2, 0)
					Kit.box(geo, CFrame.lookAt(jp, jp + ax), Vector3.new(0.5, doorH, thick + 0.5), { name = "DoorJamb" })
				end
				local top = c + Vector3.new(0, (doorH + H) / 2, 0)
				Kit.box(geo, CFrame.lookAt(top, top + ax), Vector3.new(doorW, H - doorH, thick), { name = "DoorWall" })
				local lint = c + Vector3.new(0, doorH + 0.25, 0)
				Kit.box(geo, CFrame.lookAt(lint, lint + ax), Vector3.new(doorW + 1, 0.5, thick + 0.5), { name = "DoorHead" })
				local hingeBottom = c - across * (doorW / 2) + ax * (thick / 2 - 0.15) + Vector3.new(0, 0.02, 0)
				local swing = if hash(i, j, seed) < 0.5 then 1 else -1
				-- (문짝은 경첩에서 across 방향으로 뻗는다. swing 부호에 따라 ax 쪽이나 반대쪽으로 열린다)
				Doors.create(props, hingeBottom, across, doorW, doorH, swing)
			elseif ch == "A" then
				local ax = axis or Vector3.new(1, 0, 0)
				local across = Vector3.new(ax.Z, 0, -ax.X)
				Kit.archPortal(geo, c + Vector3.new(0, fy, 0), across, T, 6, H - fy)
			elseif ch == "O" then
				local p = c + Vector3.new(0, fy, 0)
				Kit.box(geo, CFrame.new(p + Vector3.new(0, (H - fy) / 2, 0)), Vector3.new(2.4, H - fy, 2.4), { name = "Pillar" })
				Kit.box(geo, CFrame.new(p + Vector3.new(0, 0.4, 0)), Vector3.new(3.4, 0.8, 3.4), { name = "PillarBase" })
				Kit.box(geo, CFrame.new(p + Vector3.new(0, H - fy - 0.6, 0)), Vector3.new(3.2, 1.2, 3.2), { name = "PillarCap" })
			elseif ch == "c" then
				-- 벽 쪽으로 붙인 상자 더미
				local side = Vector3.new(-1, 0, 0)
				for _, d in dirs do
					if isWall(i + d.di, j + d.dj) then
						side = d.v
						break
					end
				end
				local along = Vector3.new(side.Z, 0, -side.X)
				local base = c + side * (T / 2 - 1.8) + Vector3.new(0, fy, 0)
				local yaw = math.atan2(side.X, side.Z)
				Kit.crate(props, base - along * 1.8, Vector3.new(3, 3, 3), yaw)
				Kit.crate(props, base - along * 1.8 + Vector3.new(0, 3, 0), Vector3.new(2.2, 2.2, 2.2), yaw + 0.25)
				Kit.crate(props, base + along * 1.7, Vector3.new(3.2, 2.2, 2.6), yaw - 0.1)
				Kit.box(props, CFrame.new(base + along * 1.7 + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, yaw, 0), Vector3.new(3.6, 0.24, 3.0), { blocks = false })
			elseif ch == "m" then
				local p = c + Vector3.new(0, fy, 0)
				Kit.box(props, CFrame.new(p + Vector3.new(0, 0.4, 0)), Vector3.new(5.4, 0.8, 4.2), { name = "MachineBase" })
				Kit.box(props, CFrame.new(p + Vector3.new(-0.6, 2.4, 0)), Vector3.new(3.6, 3.2, 3.4), { name = "Machine" })
				Kit.box(props, CFrame.new(p + Vector3.new(1.9, 1.9, 0)), Vector3.new(1.0, 2.2, 1.6), { name = "Panel" })
				Kit.pipe(props, p + Vector3.new(-2.4, 5.2, 0), p + Vector3.new(1.6, 5.2, 0), 1.1, { 0, 1 }, true)
				Kit.pipe(props, p + Vector3.new(1.0, 6.3, 0), p + Vector3.new(1.0, H - fy, 0), 0.45, { 0.05, 0.95 }, false)
				for _, s in { -1, 1 } do
					Kit.box(props, CFrame.new(p + Vector3.new(-0.4 + s * 1.4, 4.4, 0)), Vector3.new(0.4, 1.0, 2.2), { blocks = false })
				end
				local em = Kit.box(props, CFrame.new(p + Vector3.new(0, 3, 0)), Vector3.new(0.2, 0.2, 0.2), { invisible = true, collide = false, tag = false })
				em.CanQuery = false
				em:SetAttribute("Sound", "AmbientFan")
				CollectionService:AddTag(em, Config.Tags.AmbientEmitter)
			elseif ch == "Z" then
				local back = nil
				for _, d in dirs do
					if isWall(i + d.di, j + d.dj) and not isWall(i - d.di, j - d.dj) then
						back = d.v
						break
					end
				end
				Search.create(props, c + Vector3.new(0, fy, 0), back or Vector3.new(0, 0, -1), layout.SearchStyle)
			elseif ch == "L" then
				-- 숨는 곳: 등을 댈 벽(맞은편이 열린 쪽)을 찾는다
				local back = nil
				for _, d in dirs do
					if isWall(i + d.di, j + d.dj) and not isWall(i - d.di, j - d.dj) then
						back = d.v
						break
					end
				end
				Hiding.create(props, c + Vector3.new(0, fy, 0), back or Vector3.new(0, 0, -1), layout.HideStyle)
			elseif ch == "v" then
				local p = c + Vector3.new(0, fy, 0)
				local spots = { Vector3.new(-2.2, 0, -2.2), Vector3.new(-2.4, 0, 1.6), Vector3.new(1.8, 0, -2.6) }
				local radii = { 1.0, 0.6, 0.7 }
				for k, o in spots do
					Kit.pipe(props, p + o, p + o + Vector3.new(0, H - fy, 0), radii[k], { 0.07, 0.5, 0.93 }, true)
				end
				Kit.pipe(props, p + spots[1] + Vector3.new(0, 10, 0), p + spots[3] + Vector3.new(0, 10, 0), 0.4, { 0.5 }, false)
			elseif ch == "f" then
				local p = c + Vector3.new(0, H, 0)
				Kit.cylinder(props, p - Vector3.new(0, 1.2, 0), p, 2.4, { blocks = false, collide = false, rings = 1 })
				for k = 0, 3 do
					local a = k * math.pi / 2 + 0.4
					local bp = p - Vector3.new(0, 1.0, 0) + Vector3.new(math.cos(a), 0, math.sin(a)) * 1.05
					Kit.box(props, CFrame.lookAt(bp, bp + Vector3.new(math.cos(a), 0, math.sin(a))) * CFrame.Angles(0, 0, 0.35), Vector3.new(0.7, 0.08, 1.8), { blocks = false, collide = false })
				end
				local em = Kit.box(props, CFrame.new(p - Vector3.new(0, 1.5, 0)), Vector3.new(0.2, 0.2, 0.2), { invisible = true, collide = false, tag = false })
				em.CanQuery = false
				em:SetAttribute("Sound", "AmbientFan")
				CollectionService:AddTag(em, Config.Tags.AmbientEmitter)
			elseif ch == "b" or ch == "n" then
				-- 다리 방향: 다리/위층과 이어진 축
				local bx = (bridgeChar(at(i - 1, j)) or (not isPit(i - 1, j) and not isWall(i - 1, j))) and (bridgeChar(at(i + 1, j)) or (not isPit(i + 1, j) and not isWall(i + 1, j)))
				local ax = if bx then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
				local across = Vector3.new(ax.Z, 0, -ax.X)
				local w = if ch == "n" then 3.2 else 5 -- (좁은 다리 n: 괴물은 지나갈 수 없다)
				local deck = c + Vector3.new(0, -0.25, 0)
				Kit.box(geo, CFrame.lookAt(deck, deck + ax), Vector3.new(w, 0.5, T), { name = "Catwalk" })
				for _, s in { -1, 1 } do
					local beam = c + across * s * (w / 2 - 0.3) + Vector3.new(0, -0.9, 0)
					Kit.box(props, CFrame.lookAt(beam, beam + ax), Vector3.new(0.4, 0.8, T), { blocks = false })
					local ra = c + across * s * (w / 2 - 0.15) - ax * (T / 2)
					Kit.railing(props, ra, ra + ax * T, 3.3, 2.65)
				end
				Kit.box(props, CFrame.lookAt(c + Vector3.new(0, -1.0, 0), c + Vector3.new(0, -1.0, 0) + across), Vector3.new(0.4, 0.6, w), { blocks = false })
				if (i + j) % 2 == 0 then
					for _, s in { -1, 1 } do
						local col = c + across * s * (w / 2 - 0.3)
						Kit.box(props, CFrame.new(col + Vector3.new(0, (PIT_Y - 1.3) / 2, 0)), Vector3.new(0.5, -1.3 - PIT_Y, 0.5), { blocks = false })
					end
				end
			elseif ch == "s" then
				-- 계단: 위층 이웃 쪽으로 올라간다
				local up = dirs[1]
				for _, d in dirs do
					local n = at(i + d.di, j + d.dj)
					if n ~= "#" and not isPit(i + d.di, j + d.dj) then
						up = d
					end
				end
				local across = Vector3.new(up.v.Z, 0, -up.v.X)
				local bottom = c - up.v * (T / 2) + Vector3.new(0, PIT_Y, 0)
				Kit.stairs(props, bottom, up.v, 6, -PIT_Y, T, 8)
				-- 계단 옆이 구덩이면 기울어진 난간
				for _, s in { -1, 1 } do
					local si, sj = i + math.round(across.X * s), j + math.round(across.Z * s)
					if not isWall(si, sj) then
						local a = bottom + across * s * 2.9
						local b = a + up.v * T + Vector3.new(0, -PIT_Y, 0)
						Kit.railing(props, a, b, 3.3, 2.7)
					end
				end
			end
			if ch == "1" or ch == "2" then
				-- 2층 계단: 1 칸은 2 칸 쪽으로, 2 칸은 2층 칸 쪽으로 올라간다(칸마다 6스터드)
				local up = dirs[1]
				for _, d in dirs do
					local ni, nj = i + d.di, j + d.dj
					if (ch == "1" and at(ni, nj) == "2") or (ch == "2" and ((isUpper(ni, nj) and not isWall(ni, nj)) or aboveFloor(ni, nj))) then
						up = d
					end
				end
				local bottom = c - up.v * (T / 2)
				Kit.stairs(props, bottom, up.v, 6, UP / 2, T, 8)
				-- 벽 쪽 손잡이(양옆)
				local across = Vector3.new(up.v.Z, 0, -up.v.X)
				for _, s in { -1, 1 } do
					local a = bottom + across * s * 3.4
					Kit.railing(props, a, a + up.v * T + Vector3.new(0, UP / 2, 0), 3.3, 2.7)
				end
			end
			local pf = layout.Props and layout.Props[ch]
			if pf then
				pf(ctx, i, j)
			end
		end
	end

	-- ── 구덩이 가장자리 난간(위층 쪽) ──
	for j = 1, nz do
		for i = 1, nx do
			if not isWall(i, j) and not isPit(i, j) then
				for _, d in dirs do
					local ni, nj = i + d.di, j + d.dj
					local n = at(ni, nj)
					if isPit(ni, nj) then
						local open = false
						if n == "s" then
							-- 그 계단이 이 타일로 올라오면 난간 없음
							local best = nil
							for _, d2 in dirs do
								local m = at(ni + d2.di, nj + d2.dj)
								if m ~= "#" and not isPit(ni + d2.di, nj + d2.dj) then
									best = d2
								end
							end
							open = best ~= nil and best.di == -d.di and best.dj == -d.dj
						elseif bridgeChar(n) then
							local bx = (bridgeChar(at(ni - 1, nj)) or (not isPit(ni - 1, nj) and not isWall(ni - 1, nj))) and (bridgeChar(at(ni + 1, nj)) or (not isPit(ni + 1, nj) and not isWall(ni + 1, nj)))
							open = (bx and d.dj == 0) or (not bx and d.di == 0)
						end
						if open and bridgeChar(n) then
							-- 다리 입구 양옆은 난간
							local c = center(i, j)
							local edge = c + d.v * (T / 2 - 0.3)
							local across = Vector3.new(d.v.Z, 0, -d.v.X)
							local bw = if n == "n" then 1.75 else 2.6
							for _, s in { -1, 1 } do
								Kit.railing(props, edge + across * s * bw, edge + across * s * (T / 2 - 0.3), 3.3, 2.6)
							end
						elseif not open then
							local c = center(i, j)
							local edge = c + d.v * (T / 2 - 0.3)
							local across = Vector3.new(d.v.Z, 0, -d.v.X)
							Kit.railing(props, edge - across * (T / 2 - 0.3), edge + across * (T / 2 - 0.3), 3.3, 2.6)
						end
					end
				end
			end
		end
	end

	-- ── 괴물 배회 지점 ──
	local walk = layout.Walkable or {}
	for j = 1, nz do
		for i = 1, nx do
			local ch = at(i, j)
			if ch == "." or ch == "p" or ch == "b" or ch == "f" or ch == "D" or ch == "A" or walk[ch] then
				local c = center(i, j)
				local y = if ch == "b" then 0 else floorY(i, j)
				table.insert(info.nodes, c + Vector3.new(0, y + 3, 0))
			end
		end
	end

	-- ── 겹쳐 쌓은 2층: 계단 구멍(o) 둘레 난간(계단이 올라와 닿는 칸 쪽은 뚫는다) ──
	if below then
		for j = 1, nz do
			for i = 1, nx do
				if at(i, j) ~= "#" and at(i, j) ~= "o" then
					for _, d in dirs do
						local hi, hj = i + d.di, j + d.dj
						if at(hi, hj) == "o" then
							local landing = rowAt(below, hi, hj) == "2" and rowAt(below, hi + d.di, hj + d.dj) == "1"
							if not landing then
								local c = center(i, j)
								local edge = c + d.v * (T / 2 - 0.3)
								local across = Vector3.new(d.v.Z, 0, -d.v.X)
								Kit.railing(props, edge - across * (T / 2 - 0.3), edge + across * (T / 2 - 0.3), 3.3, 2.6)
							end
						end
					end
				end
			end
		end
		return info
	end

	-- 바닥 아래 낙하 방지(맵 밖)
	local kill = Kit.span(folder, Vector3.new(-20, BOTTOM - 4, -20), Vector3.new(nx * T + 20, BOTTOM - 2, nz * T + 20), { tag = false, invisible = true })
	kill.Name = "Underfloor"

	return info
end

-- ── 겹쳐 쌓은 2층 건물(layout.Rows2: 1층과 같은 크기의 2층 격자) ──
-- 1층 천장 H1, 그 위 층 사이 판(H1 ~ UP), 2층 바닥 UP, 2층 천장 UP + H. 계단은 1층의 1(0 → 6)·2(6 → 12) 칸이고,
-- 2층 격자에서 그 두 칸 자리는 계단 구멍 o(바닥 없음, 둘레 난간), 2 칸 앞(1 의 반대쪽) 2층 칸이 계단 도착 칸이다.
local H1 = 11
Builder.LowerCeiling = H1
function Builder.build(layout: Layout, parent: Instance, name: string): StageInfo
	local r2 = (layout :: any).Rows2 :: { string }?
	if not r2 then
		return buildGrid(layout, parent, name, nil)
	end
	local r1 = layout.Rows
	local info = buildGrid(layout, parent, name, { rows = r1, y0 = 0, Hc = H1, above = r2 })
	local info2 = buildGrid(layout, parent, name, { rows = r2, y0 = UP, Hc = H, below = r1, folder = info.folder })
	for _, n in info2.nodes do
		table.insert(info.nodes, n)
	end
	if table.concat(r2, ""):find("E", 1, true) then
		info.exitCFrame, info.exitSize = info2.exitCFrame, info2.exitSize
	end
	info.bounds = { min = info.bounds.min, max = info2.bounds.max }
	-- 타일 경로: (층, 열, 행, 높이) — 1층 구덩이 규칙은 그대로, 계단 2 ↔ 2층 도착 칸
	local nz, nx = #r1, #r1[1]
	local pitSet = table.clone(PIT)
	for k, v in layout.PitTiles or {} do
		pitSet[k] = v
	end
	-- (벽에 붙은 상자 더미 c·모서리 배관 v 는 칸 절반 이상이 비어 있어 지나갈 수 있다: tools/level-graph.js 와 같은 규칙)
	local passable: { [string]: boolean } = { ["."] = true, S = true, E = true, D = true, A = true, f = true, s = true, ["1"] = true, ["2"] = true, c = true, v = true } -- (P 등 소품 문자는 레이아웃 Walkable 에 적은 것만)
	for k in pitSet do
		passable[k] = true
	end
	for k, v in layout.Walkable or {} do
		passable[k] = v
	end
	local function ch(f: number, i: number, j: number): string
		local rs = if f == 1 then r1 else r2
		if j < 1 or j > nz or i < 1 or i > nx then
			return "#"
		end
		return rs[j]:sub(i, i)
	end
	local function lv(f: number, c: string): { number }
		if f == 2 or c == "1" or c == "2" or not pitSet[c] then
			return { 0 }
		end
		if bridgeChar(c) then
			return { 0 }
		elseif c == "s" then
			return { 0, 1 }
		end
		return { 1 }
	end
	local function has(f: number, i: number, j: number, l: number): boolean
		for _, x in lv(f, ch(f, i, j)) do
			if x == l then
				return true
			end
		end
		return false
	end
	local D4 = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	local function key(f: number, i: number, j: number, l: number): number
		return (((f - 1) * 2 + l) * (nz + 2) + j) * (nx + 2) + i
	end
	info.route = function(from: Vector3, to: Vector3, monster: boolean?): { Vector3 }?
		local function tileOf(p: Vector3): (number, number, number, number)
			local i, j = math.floor(p.X / T) + 1, math.floor(p.Z / T) + 1
			local f = if p.Y > UP - 3 and passable[ch(2, i, j)] then 2 else 1
			local l = if f == 1 and p.Y < PIT_Y / 2 then 1 else 0
			if not has(f, i, j, l) then
				l = lv(f, ch(f, i, j))[1]
			end
			return f, i, j, l
		end
		local sf, si, sj, sl = tileOf(from)
		local gf, gi, gj, gl = tileOf(to)
		if not passable[ch(sf, si, sj)] or not passable[ch(gf, gi, gj)] then
			return nil
		end
		local prev: { [number]: number } = { [key(sf, si, sj, sl)] = -1 }
		local where: { [number]: { number } } = { [key(sf, si, sj, sl)] = { sf, si, sj, sl } }
		local q = { { sf, si, sj, sl } }
		local head = 1
		local goalK = key(gf, gi, gj, gl)
		local function push(here: number, f: number, i: number, j: number, l: number)
			local c = ch(f, i, j)
			if not passable[c] or (monster and c == "n") or not has(f, i, j, l) then
				return
			end
			local k = key(f, i, j, l)
			if prev[k] == nil then
				prev[k] = here
				where[k] = { f, i, j, l }
				table.insert(q, { f, i, j, l })
			end
		end
		while head <= #q do
			local cur = q[head]
			head += 1
			local f, i, j, l = cur[1], cur[2], cur[3], cur[4]
			local here = key(f, i, j, l)
			if here == goalK then
				break
			end
			local c = ch(f, i, j)
			if f == 1 and c == "s" then
				push(here, 1, i, j, 1 - l)
			end
			for _, d in D4 do
				local ni, nj = i + d[1], j + d[2]
				local n = ch(f, ni, nj)
				if f == 1 and c == "2" then
					-- 계단 위 칸: 1 칸으로 내려가거나, 1 의 반대쪽 2층 칸으로 올라선다
					if n == "1" then
						push(here, 1, ni, nj, 0)
					elseif ch(1, i - d[1], j - d[2]) == "1" then
						push(here, 2, ni, nj, 0)
					end
				elseif f == 2 and n == "o" then
					if ch(1, ni, nj) == "2" and ch(1, ni + d[1], nj + d[2]) == "1" then
						push(here, 1, ni, nj, 0)
					end
				elseif f == 1 and n == "2" and c ~= "1" then
					-- (계단 위 칸은 옆·앞에서 들어갈 수 없다)
				else
					local nl = l
					if f == 1 and (c == "s" or n == "s" or pitSet[n] or pitSet[c]) then
						nl = l
					end
					push(here, f, ni, nj, nl)
				end
			end
		end
		if prev[goalK] == nil then
			return nil
		end
		local out = {}
		local cur = goalK
		while cur ~= -1 do
			local w = where[cur]
			local f, i, j, l = w[1], w[2], w[3], w[4]
			local c = ch(f, i, j)
			local y = if f == 2 then UP elseif l == 1 then PIT_Y else 0
			if f == 1 and c == "s" then
				y = PIT_Y / 2
			elseif f == 1 and c == "1" then
				y = UP / 4
			elseif f == 1 and c == "2" then
				y = UP * 3 / 4
			end
			table.insert(out, 1, Vector3.new((i - 1) * T + T / 2, y + 0.5, (j - 1) * T + T / 2))
			cur = prev[cur]
		end
		return out
	end
	return info
end

return Builder
