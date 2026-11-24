-- 오프라인 소품 시뮬레이터: 스테이지 격자마다 소품 함수를 실제로 돌려 만들어진 파트를 JSON 줄로 찍는다.
-- (StageBuilder 의 ctx 중 소품이 쓰는 것만 같은 식으로: at·center·floorY·isWall·isPit·hash·ceilAt·T·H·PIT_Y)
-- node art/props/sim.js 가 rbx.luau + 모듈 묶음 + 이 파일을 이어 붙인다. __STAGES__ 는 돌릴 스테이지 번호 목록.

local function pathProxy(path)
	return setmetatable({ __path = path }, {
		__index = function(t, k)
			if k == "Parent" then
				local p = table.clone(t.__path)
				table.remove(p)
				return pathProxy(p)
			end
			local p = table.clone(t.__path)
			table.insert(p, k)
			return pathProxy(p)
		end,
	})
end
local modCache = {}
local realRequire = require
require = function(x)
	if type(x) == "table" and x.__path then
		local key = table.concat(x.__path, "/")
		if modCache[key] ~= nil then return modCache[key] end
		local f = __mods[key]
		if not f then error("no module " .. key) end
		local r = f(pathProxy(x.__path))
		modCache[key] = r
		return r
	end
	return realRequire(x)
end
game:GetService("ReplicatedStorage")
-- (ReplicatedStorage.Shared.X → shared/X)
local RS = setmetatable({}, { __index = function(_, k) if k == "Shared" then return pathProxy({ "shared" }) end return pathProxy({ k }) end })
local svcGet = game.GetService
game.GetService = function(g, n)
	if n == "ReplicatedStorage" then return RS end
	return svcGet(g, n)
end

-- ── JSON ──
local function num(x)
	if x ~= x then return "0" end
	return (string.format("%.4f", x):gsub("%.?0+$", ""))
end
local function js(s) return '"' .. tostring(s):gsub('[%c"\\]', function(c) return string.format("\\u%04x", string.byte(c)) end) .. '"' end
local function attrJson(a)
	local parts = {}
	for k, v in a do
		local s
		if type(v) == "number" then s = num(v)
		elseif type(v) == "boolean" then s = tostring(v)
		elseif typeof(v) == "Vector3" then s = "[" .. num(v.X) .. "," .. num(v.Y) .. "," .. num(v.Z) .. "]"
		else s = js(tostring(v)) end
		table.insert(parts, js(k) .. ":" .. s)
	end
	return "{" .. table.concat(parts, ",") .. "}"
end
local function partJson(p)
	local c = p.CFrame
	local s = p.Size
	local shape = p.__class
	if p.__class == "Part" then shape = p.Shape.Name end
	local tags = {}
	for t in p.__tags do table.insert(tags, js(t)) end
	return string.format('{"c":%s,"sh":%s,"cf":[%s],"s":[%s,%s,%s],"col":%s,"q":%s,"tr":%s,"tags":[%s],"a":%s}',
		js(p.__class), js(shape),
		table.concat({ num(c.p.X), num(c.p.Y), num(c.p.Z), num(c.x.X), num(c.x.Y), num(c.x.Z), num(c.y.X), num(c.y.Y), num(c.y.Z), num(c.z.X), num(c.z.Y), num(c.z.Z) }, ","),
		num(s.X), num(s.Y), num(s.Z), tostring(p.CanCollide), tostring(p.CanQuery), num(p.Transparency), table.concat(tags, ","), attrJson(p.__attrs))
end
local function cfJson(c)
	return "[" .. table.concat({ num(c.p.X), num(c.p.Y), num(c.p.Z), num(c.x.X), num(c.x.Y), num(c.x.Z), num(c.y.X), num(c.y.Y), num(c.y.Z), num(c.z.X), num(c.z.Y), num(c.z.Z) }, ",") .. "]"
end
local function dressJson(m)
	local list = rawget(m, "__dress")
	if not list then return "[]" end
	local out = {}
	for _, d in list do
		local sc = d.sc or Vector3.one
		local idx = {}
		if d.parts then
			local all = {}
			for _, x in m:GetDescendants() do if x:IsA("BasePart") then table.insert(all, x) end end
			for _, p in d.parts do for k, x in all do if x == p then table.insert(idx, tostring(k - 1)) end end end
		end
		table.insert(out, '{"key":' .. js(d.key) .. ',"cf":' .. cfJson(d.cf) .. ',"sc":[' .. num(sc.X) .. "," .. num(sc.Y) .. "," .. num(sc.Z) .. '],"parts":' .. (if d.parts then "[" .. table.concat(idx, ",") .. "]" else "null") .. "}")
	end
	return "[" .. table.concat(out, ",") .. "]"
end
local function modelJson(m)
	local parts = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then table.insert(parts, partJson(d)) end
	end
	return parts
end

-- ── 스테이지 ──
local T, H, PIT_Y, UP, H1 = 8, 14, -6, 12, 11
local PIT = { p = true, b = true, s = true, n = true }
local function hash(a, b, c)
	local h = bit32.bxor(bit32.bxor((a * 73856093) % 4294967296, (b * 19349663) % 4294967296), (c * 83492791) % 4294967296)
	return (h % 1000) / 1000
end

-- PropMesh.dress 는 기록만(모델에 키·좌표계를 적어 둔다)
do
	local ok, PM = pcall(require, pathProxy({ "server", "PropMesh" }))
	if ok and type(PM) == "table" then
		PM.dress = function(m, key, cf, sc, parts, parent)
			local list = rawget(m, "__dress") or {}
			table.insert(list, { key = key, cf = cf, sc = sc, parts = parts })
			rawset(m, "__dress", list)
		end
	end
end

-- 함수 → 이름
local fnName = {}
local function nameFns(mod, prefix)
	for k, v in mod do
		if type(v) == "function" then fnName[v] = prefix .. "." .. k end
	end
end
nameFns(require(pathProxy({ "server", "Props" })), "Props")
for _, ch in { "Cinema", "Facility", "Hospital", "Hotel", "Kindergarten", "Maze", "Parking", "School", "Sewer", "Warehouse" } do
	nameFns(require(pathProxy({ "server", "ChapterProps", ch })), ch)
end

local function runGrid(stageNo, layout, rows, y0, Hc, above, floorNo)
	local nz, nx = #rows, #rows[1]
	local function rowAt(r, i, j)
		if not r or j < 1 or j > #r or i < 1 or i > #r[1] then return "#" end
		return r[j]:sub(i, i)
	end
	local function at(i, j) return rowAt(rows, i, j) end
	local pitSet = table.clone(PIT)
	for k, v in layout.PitTiles or {} do pitSet[k] = v end
	local function isWall(i, j) return at(i, j) == "#" end
	local function isPit(i, j) return pitSet[at(i, j)] == true end
	local function floorY(i, j) return if isPit(i, j) then PIT_Y else 0 end
	local upperSet = {}
	for _, r in layout.UpperRects or {} do
		for j = r[2], r[4] do for i = r[1], r[3] do upperSet[j * 1000 + i] = true end end
	end
	local function base(i, j)
		local c = at(i, j)
		if c == "1" then return 0 elseif c == "2" then return UP / 2 end
		return if upperSet[j * 1000 + i] then UP else 0
	end
	local function center(i, j) return Vector3.new((i - 1) * T + T / 2, base(i, j) + y0, (j - 1) * T + T / 2) end
	local props = Instance.new("Folder")
	local ctx = {
		props = props, geo = Instance.new("Folder"), at = at, center = center, floorY = floorY, isWall = isWall, isPit = isPit,
		T = T, H = Hc, PIT_Y = PIT_Y, info = {}, hash = hash,
		ceilAt = function(i, j)
			if above and rowAt(above, i, j) == "_" then return UP + H end
			return Hc
		end,
	}
	ctx.Kit = require(pathProxy({ "server", "MapKit" }))
	for j = 1, nz do
		for i = 1, nx do
			local ch = at(i, j)
			local pf = layout.Props and layout.Props[ch]
			if pf then
				local before = {}
				for _, c in props.__children do before[c] = true end
				local ok, err = pcall(pf, ctx, i, j)
				local items = {}
				local loose = {}
				for _, c in props.__children do
					if not before[c] then
						if c:IsA("BasePart") then
							table.insert(loose, partJson(c))
						else
							table.insert(items, '{"name":' .. js(c.Name) .. ',"dress":' .. dressJson(c) .. ',"parts":[' .. table.concat(modelJson(c), ",") .. "]}")
						end
					end
				end
				if #loose > 0 then table.insert(items, '{"name":"_loose","parts":[' .. table.concat(loose, ",") .. "]}") end
				local c0 = center(i, j)
				print(string.format('@@{"stage":%d,"floor":%d,"i":%d,"j":%d,"ch":%s,"fn":%s,"ok":%s,"err":%s,"base":[%s,%s,%s],"fy":%s,"models":[%s]}',
					stageNo, floorNo, i, j, js(ch), js(fnName[pf] or "?"), tostring(ok), js(if ok then "" else tostring(err)),
					num(c0.X), num(c0.Y), num(c0.Z), num(floorY(i, j)), table.concat(items, ",")))
				-- (다음 칸 전에 비운다: 메모리)
				for _, c in table.clone(props.__children) do c.Parent = nil end
			end
		end
	end
end

for _, n in __STAGES__ do
	local layout = require(pathProxy({ "server", "Stages", "Stage" .. n }))
	local r2 = layout.Rows2
	if r2 then
		runGrid(n, layout, layout.Rows, 0, H1, r2, 1)
		runGrid(n, layout, r2, UP, H, nil, 2)
	else
		runGrid(n, layout, layout.Rows, 0, H, nil, 1)
	end
end
