--!strict
-- 서브 괴물 자기 자리에 맵에 없던 소품을 더 놓는다(Shared/CreatureHomes 의 prop): 욕조 · 칠판 · 풍금 · 모빌 달린 아기 침대 · 천장 봉.
-- 스테이지를 지을 때(폴더가 workspace 에 들어가기 전) 같이 만들어서 음파 선에 다른 소품처럼 그려진다. 부딪히지 않는다(길을 막지 않게).
local Kit = require(script.Parent.MapKit)

local HomeProps = {}
local T = 8
local NC = { blocks = false, collide = false }

local function box(m: Instance, cf: CFrame, size: Vector3)
	Kit.box(m, cf, size, NC)
end
local function rod(m: Instance, a: Vector3, b: Vector3, r: number)
	local p = Kit.cylinder(m, a, b, r)
	p.CanCollide = false
end
local function ball(m: Instance, c: Vector3, r: number)
	local p = Kit.ball(m, c, r)
	p.CanCollide = false
end

local P: { [string]: (m: Model, cf: CFrame) -> () } = {}

-- 다리 달린 욕조(클로풋)
P.Bathtub = function(m, cf)
	local L, W, Hh, t = 6, 2.8, 2.2, 0.25
	local o = cf * CFrame.new(0, 0.8, 0)
	box(m, o * CFrame.new(0, 0, 0), Vector3.new(W, t, L)) -- 바닥
	box(m, o * CFrame.new(W / 2, Hh / 2, 0), Vector3.new(t, Hh, L))
	box(m, o * CFrame.new(-W / 2, Hh / 2, 0), Vector3.new(t, Hh, L))
	box(m, o * CFrame.new(0, Hh / 2, L / 2), Vector3.new(W, Hh, t))
	box(m, o * CFrame.new(0, Hh / 2, -L / 2), Vector3.new(W, Hh * 1.2, t))
	for _, s in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
		ball(m, (o * CFrame.new(s[1] * (W / 2 - 0.3), -0.45, s[2] * (L / 2 - 0.5))).Position, 0.35)
	end
	rod(m, (o * CFrame.new(0, Hh * 1.2, -L / 2)).Position, (o * CFrame.new(0, Hh * 1.2 + 1.2, -L / 2 - 0.4)).Position, 0.12) -- 수도꼭지
end

-- 칠판 + 분필 받침 + 교탁
P.Blackboard = function(m, cf)
	local o = cf * CFrame.new(0, 0, -T / 2 + 0.4) -- 칸 뒤쪽 벽에 붙여
	box(m, o * CFrame.new(0, 6, 0), Vector3.new(12, 4.5, 0.25))
	box(m, o * CFrame.new(0, 6, 0.05), Vector3.new(12.6, 5.1, 0.12)) -- 테두리
	box(m, o * CFrame.new(0, 3.6, 0.35), Vector3.new(12, 0.15, 0.5)) -- 분필 받침
	box(m, o * CFrame.new(0, 1.8, 3.2), Vector3.new(4, 3.6, 2)) -- 교탁
end

-- 풍금(페달 오르간): 몸통 · 건반 · 악보대 · 페달
P.Organ = function(m, cf)
	local o = cf * CFrame.new(0, 0, -T / 2 + 1.4)
	box(m, o * CFrame.new(0, 1.9, 0), Vector3.new(5, 3.8, 1.8))
	box(m, o * CFrame.new(0, 3.1, 1.2), Vector3.new(4.6, 0.25, 0.8)) -- 건반
	for k = -9, 9 do
		box(m, o * CFrame.new(k * 0.24, 3.27, 1.25), Vector3.new(0.12, 0.08, 0.6))
	end
	box(m, o * CFrame.new(0, 4.6, -0.3), Vector3.new(4.4, 1.6, 0.2)) -- 악보대
	box(m, o * CFrame.new(-0.8, 0.3, 1.2) * CFrame.Angles(-0.3, 0, 0), Vector3.new(1, 0.15, 1.4)) -- 페달
	box(m, o * CFrame.new(0.8, 0.3, 1.2) * CFrame.Angles(-0.3, 0, 0), Vector3.new(1, 0.15, 1.4))
	box(m, o * CFrame.new(0, 1.2, 3), Vector3.new(2.6, 0.3, 1.2)) -- 의자
end

-- 아기 침대(난간 살) + 천장에 매단 모빌
P.CribMobile = function(m, cf)
	local L, W, Hh = 4.4, 2.6, 3
	box(m, cf * CFrame.new(0, 1, 0), Vector3.new(W, 0.3, L))
	for _, x in { -W / 2, W / 2 } do
		rod(m, (cf * CFrame.new(x, Hh, -L / 2)).Position, (cf * CFrame.new(x, Hh, L / 2)).Position, 0.08)
		for k = 0, 8 do
			local z = -L / 2 + k * L / 8
			rod(m, (cf * CFrame.new(x, 0, z)).Position, (cf * CFrame.new(x, Hh, z)).Position, 0.06)
		end
	end
	for _, z in { -L / 2, L / 2 } do
		rod(m, (cf * CFrame.new(-W / 2, Hh, z)).Position, (cf * CFrame.new(W / 2, Hh, z)).Position, 0.08)
	end
	-- 모빌: 천장에서 내려온 줄 · 십자 팔 · 매달린 인형들
	local top = cf * CFrame.new(0, 13.6, 0)
	local hub = cf * CFrame.new(0, 8.6, 0)
	rod(m, top.Position, hub.Position, 0.05)
	for k = 0, 5 do
		local a = k * math.pi / 3
		local tip = hub * CFrame.new(math.cos(a) * 2.2, 0, math.sin(a) * 2.2)
		rod(m, hub.Position, tip.Position, 0.06)
		rod(m, tip.Position, (tip * CFrame.new(0, -1.4, 0)).Position, 0.03)
		ball(m, (tip * CFrame.new(0, -1.75, 0)).Position, 0.35)
		ball(m, (tip * CFrame.new(0, -2.3, 0)).Position, 0.25)
	end
end

-- 천장 가까이 가로지른 봉(덮개가 매달린다)
P.HangBar = function(m, cf)
	local a = cf * CFrame.new(0, 12.2, -T * 1.5)
	local b = cf * CFrame.new(0, 12.2, T * 1.5)
	rod(m, a.Position, b.Position, 0.25)
	for _, c in { a, b, cf * CFrame.new(0, 12.2, 0) } do
		rod(m, c.Position, (c * CFrame.new(0, 1.8, 0)).Position, 0.12) -- 천장 고정대
	end
end

-- 칸 (i, j) 의 바닥 높이: 그 칸의 배회 지점(바닥 + 3) 중 band 에 맞는 것
local function floorAt(nodes: { Vector3 }, i: number, j: number, band: string?): number?
	local low = math.huge
	for _, p in nodes do
		low = math.min(low, p.Y)
	end
	local best, bd = nil, math.huge
	local c = Vector3.new((i - 0.5) * T, 0, (j - 0.5) * T)
	for _, p in nodes do
		local okBand = band == nil or (band == "upper" and p.Y > low + 8) or (band == "lower" and p.Y <= low + 8)
		if okBand then
			local d = (Vector3.new(p.X, 0, p.Z) - c).Magnitude
			if d < bd then
				best, bd = p.Y - 3, d
			end
		end
	end
	return best
end

-- 이번 스테이지의 서브 괴물들 자리에 소품을 놓는다
function HomeProps.place(info: any, homes: { [string]: any }, ids: { string }, parent: Instance): number
	local n = 0
	for _, id in ids do
		local h = homes[id]
		local make = h and h.prop and P[h.prop]
		if make then
			local ci = math.floor((h.rect[1] + h.rect[3]) / 2)
			local cj = math.floor((h.rect[2] + h.rect[4]) / 2)
			local y = floorAt(info.nodes, ci, cj, h.band)
			if y then
				local m = Instance.new("Model")
				m.Name = "Home_" .. h.prop
				m:SetAttribute("HomeOf", id)
				m.Parent = parent
				make(m, CFrame.new((ci - 0.5) * T, y, (cj - 0.5) * T))
				n += 1
			end
		end
	end
	return n
end

return HomeProps
