--!strict
-- 소품 메시 데이터(서버·클라이언트 공용). 자식 모듈 하나 = 에셋 묶음 하나(art/props/export.js 가 만든다, 손으로 고치지 말 것).
--   자식 모듈: { asset = 모델 에셋 번호, items = { [key] = { z = {크기}, c = {가운데}, s = {선분 x1,y1,z1,x2,y2,z2,...}, v = {실루엣 t,ax,ay,az,bx,by,bz,r1,r2,...} } } }
--   좌표: s·v 는 메시 가운데 기준(메시 파트 CFrame 의 로컬, 늘이기 전), c 는 소품 좌표계(dress 의 cf) 기준. v 의 t: 0 = 원통/원뿔대, 1 = 구.
-- key 의 묶음 = 첫 '.' 앞(예: "Hospital.Bed" → Hospital).

export type Item = {
	size: Vector3,
	center: Vector3,
	seg: { number },
	view: { number },
}

local Data = {}
Data.assets = {} :: { [string]: number }

local mods: { [string]: ModuleScript } = {}
for _, c in script:GetChildren() do
	if c:IsA("ModuleScript") then
		mods[c.Name] = c
	end
end

local loaded: { [string]: any } = {}
local function group(name: string): any
	local g = loaded[name]
	if g == nil then
		local ms = mods[name]
		g = if ms then require(ms) :: any else false
		loaded[name] = g
	end
	return if g then g else nil
end

for name in mods do
	local g = group(name)
	if g and type(g.asset) == "number" and g.asset ~= 0 then
		Data.assets[name] = g.asset
	end
end

function Data.groupOf(key: string): string?
	local name = key:match("^([^%.]+)%.")
	if name and mods[name] then
		return name
	end
	return nil
end

local cache: { [string]: Item | false } = {}
function Data.get(key: string): Item?
	local c = cache[key]
	if c ~= nil then
		return if c then c else nil
	end
	local name = Data.groupOf(key)
	local g = name and group(name)
	local raw = g and g.items[key]
	if not raw then
		cache[key] = false
		return nil
	end
	local item: Item = {
		size = Vector3.new(raw.z[1], raw.z[2], raw.z[3]),
		center = Vector3.new(raw.c[1], raw.c[2], raw.c[3]),
		seg = raw.s,
		view = raw.v,
	}
	cache[key] = item
	return item
end

return Data
