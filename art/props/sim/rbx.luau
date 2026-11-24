-- 오프라인 소품 시뮬레이터용 로블록스 API 흉내(Vector3·CFrame·Instance·Enum·CollectionService).
-- 소품 빌더(Props·ChapterProps·HomeProps·MapKit)가 쓰는 것만. node art/props/sim.js 가 이 파일 + 모듈 소스를 한 파일로 묶어 luau.exe 로 돌린다.

-- ── Vector3 ──
local V = {}
V.__index = V
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V)
end
V.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V.__mul = function(a, b)
	if type(a) == "number" then return v3(b.X * a, b.Y * a, b.Z * a) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V.__div = function(a, b)
	if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V.__idiv = function(a, b) return v3(a.X // b, a.Y // b, a.Z // b) end
V.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V.__tostring = function(a) return string.format("%g, %g, %g", a.X, a.Y, a.Z) end
local Vget = {
	Magnitude = function(a) return math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z) end,
	Unit = function(a)
		local m = math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z)
		if m == 0 then return v3(0 / 0, 0 / 0, 0 / 0) end
		return v3(a.X / m, a.Y / m, a.Z / m)
	end,
}
V.__index = function(a, k)
	local g = Vget[k]
	if g then return g(a) end
	return V[k]
end
function V.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function V.Cross(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function V.Lerp(a, b, t) return a + (b - a) * t end
function V.Min(a, b) return v3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)) end
function V.Max(a, b) return v3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z)) end
function V.Abs(a) return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z)) end
function V.Floor(a) return v3(math.floor(a.X), math.floor(a.Y), math.floor(a.Z)) end
function V.FuzzyEq(a, b, e) return (a - b).Magnitude <= (e or 1e-5) end
Vector3 = { new = v3 }
Vector3.zero = v3(0, 0, 0)
Vector3.one = v3(1, 1, 1)
Vector3.xAxis = v3(1, 0, 0)
Vector3.yAxis = v3(0, 1, 0)
Vector3.zAxis = v3(0, 0, 1)

-- ── CFrame: p + 회전 열 X·Y·Z ──
local C = {}
local function cf(p, x, y, z)
	return setmetatable({ p = p, x = x, y = y, z = z }, C)
end
local Cget = {
	Position = function(c) return c.p end,
	XVector = function(c) return c.x end,
	YVector = function(c) return c.y end,
	ZVector = function(c) return c.z end,
	RightVector = function(c) return c.x end,
	UpVector = function(c) return c.y end,
	LookVector = function(c) return -c.z end,
	Rotation = function(c) return cf(v3(0, 0, 0), c.x, c.y, c.z) end,
	X = function(c) return c.p.X end,
	Y = function(c) return c.p.Y end,
	Z = function(c) return c.p.Z end,
}
C.__index = function(c, k)
	local g = Cget[k]
	if g then return g(c) end
	return C[k]
end
local function rotv(c, v) return c.x * v.X + c.y * v.Y + c.z * v.Z end
C.__mul = function(a, b)
	if getmetatable(b) == V then return a.p + rotv(a, b) end
	return cf(a.p + rotv(a, b.p), rotv(a, b.x), rotv(a, b.y), rotv(a, b.z))
end
C.__add = function(a, b) return cf(a.p + b, a.x, a.y, a.z) end
C.__sub = function(a, b) return cf(a.p - b, a.x, a.y, a.z) end
C.__eq = function(a, b) return a.p == b.p and a.x == b.x and a.y == b.y and a.z == b.z end
function C.Inverse(c)
	-- 전치(열 → 행)
	local x = v3(c.x.X, c.y.X, c.z.X)
	local y = v3(c.x.Y, c.y.Y, c.z.Y)
	local z = v3(c.x.Z, c.y.Z, c.z.Z)
	local r = cf(v3(0, 0, 0), x, y, z)
	return cf(-(rotv(r, c.p)), x, y, z)
end
function C.PointToObjectSpace(c, v) return C.Inverse(c) * v end
function C.PointToWorldSpace(c, v) return c * v end
function C.VectorToObjectSpace(c, v) return rotv(C.Inverse(c), v) end
function C.VectorToWorldSpace(c, v) return rotv(c, v) end
function C.ToObjectSpace(a, b) return C.Inverse(a) * b end
function C.ToWorldSpace(a, b) return a * b end
function C.Lerp(a, b, t)
	-- (회전은 단순 보간 후 정규 직교화 — 소품 빌더는 위치 보간에만 쓴다)
	local x = (a.x + (b.x - a.x) * t).Unit
	local y = (a.y + (b.y - a.y) * t)
	local z = x:Cross(y).Unit
	y = z:Cross(x).Unit
	return cf(a.p + (b.p - a.p) * t, x, y, z)
end
function C.GetComponents(c)
	return c.p.X, c.p.Y, c.p.Z, c.x.X, c.y.X, c.z.X, c.x.Y, c.y.Y, c.z.Y, c.x.Z, c.y.Z, c.z.Z
end
C.components = C.GetComponents
local I3 = { v3(1, 0, 0), v3(0, 1, 0), v3(0, 0, 1) }
local function lookAt(at, target, up)
	up = up or v3(0, 1, 0)
	local look = (target - at).Unit
	if look.X ~= look.X then return cf(at, I3[1], I3[2], I3[3]) end
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		-- (위아래로 볼 때: 로블록스처럼 X 축을 고정)
		right = look:Cross(v3(0, 0, -1) * (if look.Y > 0 then 1 else -1)) * 0 + v3(1, 0, 0)
		if math.abs(look:Dot(right)) > 0.9 then right = v3(0, 0, 1) end
		right = (right - look * right:Dot(look)).Unit
	else
		right = right.Unit
	end
	local up2 = right:Cross(look).Unit
	return cf(at, right, up2, -look)
end
local function angles(rx, ry, rz)
	local function rX(a) local c, s = math.cos(a), math.sin(a) return cf(v3(), v3(1, 0, 0), v3(0, c, s), v3(0, -s, c)) end
	local function rY(a) local c, s = math.cos(a), math.sin(a) return cf(v3(), v3(c, 0, -s), v3(0, 1, 0), v3(s, 0, c)) end
	local function rZ(a) local c, s = math.cos(a), math.sin(a) return cf(v3(), v3(c, s, 0), v3(-s, c, 0), v3(0, 0, 1)) end
	return rX(rx or 0) * rY(ry or 0) * rZ(rz or 0)
end
CFrame = {
	new = function(a, b, c, ...)
		if a == nil then return cf(v3(), I3[1], I3[2], I3[3]) end
		if type(a) == "number" then
			local n = select("#", ...)
			if n == 9 then
				local r00, r01, r02, r10, r11, r12, r20, r21, r22 = ...
				return cf(v3(a, b, c), v3(r00, r10, r20), v3(r01, r11, r21), v3(r02, r12, r22))
			end
			return cf(v3(a, b, c), I3[1], I3[2], I3[3])
		end
		if b ~= nil then return lookAt(a, b) end
		return cf(a, I3[1], I3[2], I3[3])
	end,
	lookAt = lookAt,
	Angles = angles,
	fromEulerAnglesXYZ = angles,
	fromEulerAnglesYXZ = function(rx, ry, rz) return angles(0, ry, 0) * angles(rx, 0, 0) * angles(0, 0, rz) end,
	fromOrientation = function(rx, ry, rz) return angles(0, ry, 0) * angles(rx, 0, 0) * angles(0, 0, rz) end,
	fromAxisAngle = function(axis, a)
		local u = axis.Unit
		local c, s = math.cos(a), math.sin(a)
		local function rot(v) return v * c + u:Cross(v) * s + u * (u:Dot(v) * (1 - c)) end
		return cf(v3(), rot(I3[1]), rot(I3[2]), rot(I3[3]))
	end,
	fromMatrix = function(p, x, y, z)
		z = z or x:Cross(y).Unit
		return cf(p, x, y, z)
	end,
}
CFrame.identity = CFrame.new()

Color3 = {
	new = function(r, g, b) return { R = r or 0, G = g or 0, B = b or 0, __color = true } end,
	fromRGB = function(r, g, b) return { R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255, __color = true } end,
}

-- ── Enum ──
local function enumProxy(path)
	return setmetatable({}, {
		__index = function(_, k)
			return enumProxy(path .. "." .. k)
		end,
		__tostring = function() return path end,
		__eq = function(a, b) return tostring(a) == tostring(b) end,
	})
end
local enumCache = {}
Enum = setmetatable({}, {
	__index = function(_, k)
		local t = enumCache[k]
		if not t then
			local items = {}
			t = setmetatable({}, {
				__index = function(_, n)
					local it = items[n]
					if not it then
						it = setmetatable({ Name = n, EnumType = k }, { __tostring = function() return "Enum." .. k .. "." .. n end })
						items[n] = it
					end
					return it
				end,
			})
			enumCache[k] = t
		end
		return t
	end,
})
local _ = enumProxy

-- ── Instance ──
local CLASSES = {
	Part = { "Part", "BasePart", "PVInstance", "Instance" },
	WedgePart = { "WedgePart", "BasePart", "PVInstance", "Instance" },
	MeshPart = { "MeshPart", "BasePart", "PVInstance", "Instance" },
	Model = { "Model", "PVInstance", "Instance" },
	Folder = { "Folder", "Instance" },
}
local IM = {}
local nextSerial = 0
local function newInstance(class)
	nextSerial += 1
	local o = {
		__class = class,
		__props = {
			Name = class,
			ClassName = class,
			Transparency = 0,
			CanCollide = true,
			CanQuery = true,
			CanTouch = true,
			Anchored = false,
			Size = v3(4, 1, 2),
			CFrame = CFrame.new(),
			Shape = Enum.PartType.Block,
		},
		__attrs = {},
		__tags = {},
		__children = {},
		__serial = nextSerial,
	}
	return setmetatable(o, IM)
end
IM.__index = function(o, k)
	local m = rawget(IM, k)
	if m then return m end
	local props = rawget(o, "__props")
	if k == "Parent" then return props.Parent end
	if k == "Position" then return props.CFrame.p end
	local v = props[k]
	if v ~= nil then return v end
	-- 자식 이름
	for _, c in rawget(o, "__children") do
		if c.__props.Name == k then return c end
	end
	return nil
end
IM.__newindex = function(o, k, v)
	local props = rawget(o, "__props")
	if k == "Parent" then
		local old = props.Parent
		if old then
			local ch = rawget(old, "__children")
			for i, c in ch do
				if c == o then table.remove(ch, i) break end
			end
		end
		props.Parent = v
		if v then table.insert(rawget(v, "__children"), o) end
		return
	end
	if k == "Position" then
		local c = props.CFrame
		props.CFrame = cf(v, c.x, c.y, c.z)
		return
	end
	props[k] = v
end
function IM.IsA(o, c)
	for _, n in CLASSES[o.__class] or { o.__class, "Instance" } do
		if n == c then return true end
	end
	return false
end
function IM.SetAttribute(o, k, v) o.__attrs[k] = v end
function IM.GetAttribute(o, k) return o.__attrs[k] end
function IM.GetAttributes(o) return table.clone(o.__attrs) end
function IM.GetChildren(o) return table.clone(o.__children) end
function IM.GetDescendants(o)
	local out = {}
	local function rec(x)
		for _, c in x.__children do
			table.insert(out, c)
			rec(c)
		end
	end
	rec(o)
	return out
end
function IM.FindFirstChild(o, n)
	for _, c in o.__children do
		if c.__props.Name == n then return c end
	end
	return nil
end
function IM.FindFirstChildWhichIsA(o, cl)
	for _, c in o.__children do
		if c:IsA(cl) then return c end
	end
	return nil
end
function IM.Destroy(o) o.Parent = nil end
function IM.ClearAllChildren(o)
	for _, c in table.clone(o.__children) do c.Parent = nil end
end
function IM.IsDescendantOf(o, a)
	local p = o.__props.Parent
	while p do
		if p == a then return true end
		p = p.__props.Parent
	end
	return false
end
function IM.AddTag(o, t) o.__tags[t] = true end
function IM.HasTag(o, t) return o.__tags[t] == true end
function IM.PivotTo(o, c) o.__props.CFrame = c end
function IM.GetPivot(o) return o.__props.CFrame end

Instance = { new = function(class, parent)
	local o = newInstance(class)
	if parent then o.Parent = parent end
	return o
end }

local CollectionService = {
	AddTag = function(_, o, t) o.__tags[t] = true end,
	HasTag = function(_, o, t) return o.__tags[t] == true end,
	RemoveTag = function(_, o, t) o.__tags[t] = nil end,
	GetTagged = function() return {} end,
}
local services = { CollectionService = CollectionService }
game = {
	GetService = function(_, n)
		local s = services[n]
		if not s then
			s = { __service = n }
			services[n] = s
		end
		return s
	end,
}
workspace = newInstance("Folder")
typeof = function(v)
	if type(v) == "table" then
		local mt = getmetatable(v)
		if mt == V then return "Vector3" end
		if mt == C then return "CFrame" end
		if mt == IM then return "Instance" end
		if rawget(v, "__color") then return "Color3" end
	end
	return type(v)
end
task = { wait = function() end, spawn = function(f, ...) f(...) end, defer = function(f, ...) f(...) end }
warn = function(...) end
