--!strict
-- 메인 괴물 머리(사용자 확정 3차 시안, 노트 main-monster-v3.svg). 1 삼각 · 2 사각 · 3 원 · 4 별 · 5 육각.
-- 서버(Monster.luau: 3D 선 몸)와 클라이언트(JumpScare.luau: 잡혔을 때 화면 가득 얼굴)가 같은 모양을 쓴다.
-- 좌표는 시안의 머리 기준 px(가운데 0, 아래가 +y). 머리 전체는 (tx, ty)로 옮기고 deg 만큼 돌리고 scale 배.
-- extra 는 머리 밖(몸 좌표 그대로) — 2번 어깨의 작은 머리. 점프스케어는 extra 를 그리지 않는다.

local Faces = {}
-- 지금 메인 괴물 머리(모든 스테이지 공통). 1~5 는 예전 스테이지별 머리(지금은 쓰지 않음)
Faces.BONE = 6
-- 메인 괴물 바늘 이빨 색(사용자 확정: 흰 몸 · 흰 눈 · 붉은 이빨). 음파 선(SonarColor)과 점프스케어에 같이 쓴다
Faces.TEETH = Color3.fromRGB(255, 42, 42)

export type Pt = { number }
export type Line = { pts: { Pt }, r: number, closed: boolean, dz: number, tint: Color3? }
export type Circle = { u: number, v: number, rad: number, dz: number, pupil: boolean }
export type Face = { tx: number, ty: number, deg: number, scale: number, lines: { Line }, circles: { Circle }, extra: { Line }, extraCircles: { Circle } }

type Map = (number, number) -> (number, number)

local function quad(p0: Pt, c: Pt, p1: Pt, n: number): { Pt }
	local out: { Pt } = {}
	for i = 0, n do
		local t = i / n
		local u = 1 - t
		table.insert(out, { u * u * p0[1] + 2 * u * t * c[1] + t * t * p1[1], u * u * p0[2] + 2 * u * t * c[2] + t * t * p1[2] })
	end
	return out
end
local function join(a: { Pt }, b: { Pt }): { Pt }
	local out: { Pt } = table.clone(a)
	for i = 2, #b do
		table.insert(out, b[i])
	end
	return out
end
local function ellipse(cx: number, cy: number, rx: number, ry: number, n: number): { Pt }
	local out: { Pt } = {}
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		table.insert(out, { cx + rx * math.cos(a), cy + ry * math.sin(a) })
	end
	return out
end
local function hexagon(r: number): { Pt }
	local h = r * 0.866
	return { { r, 0 }, { r / 2, h }, { -r / 2, h }, { -r, 0 }, { -r / 2, -h }, { r / 2, -h } }
end
-- translate(tx, ty) rotate(deg) (시안 SVG 와 같은 순서)
local function T(tx: number, ty: number, deg: number): Map
	local c, s = math.cos(math.rad(deg)), math.sin(math.rad(deg))
	return function(u: number, v: number): (number, number)
		return tx + u * c - v * s, ty + u * s + v * c
	end
end
-- rotate(deg cx cy)
local function Rabout(deg: number, cx: number, cy: number): Map
	local c, s = math.cos(math.rad(deg)), math.sin(math.rad(deg))
	return function(u: number, v: number): (number, number)
		local x, y = u - cx, v - cy
		return cx + x * c - y * s, cy + x * s + y * c
	end
end
local function mapPts(m: Map, pts: { Pt }): { Pt }
	local out: { Pt } = {}
	for _, p in pts do
		local x, y = m(p[1], p[2])
		table.insert(out, { x, y })
	end
	return out
end

function Faces.build(shape: number): Face
	local f: Face = { tx = 0, ty = 0, deg = 0, scale = 1, lines = {}, circles = {}, extra = {}, extraCircles = {} }
	local sub: Map? = nil -- 머리 안의 작은 부분 변환(쪼개진 반쪽, 혹)
	local function L(pts: { Pt }, r: number, closed: boolean?, dz: number?)
		table.insert(f.lines, { pts = if sub then mapPts(sub, pts) else pts, r = r, closed = closed == true, dz = dz or 0 })
	end
	local function C(u: number, v: number, rad: number, dz: number?)
		if sub then
			u, v = sub(u, v)
		end
		table.insert(f.circles, { u = u, v = v, rad = rad, dz = dz or -0.05, pupil = (dz or 0) <= -0.07 })
	end
	local function teeth(list: { { number } }, r: number)
		for _, q in list do
			L({ { q[1], q[2] }, { q[3], q[4] } }, r, false, -0.04)
		end
	end
	local function drool(list: { { number } })
		for _, q in list do
			L({ { q[1], q[2] }, { q[3], q[4] } }, 0.012, false, -0.04)
		end
	end

	if shape == Faces.BONE then
		-- 메인 괴물(사용자 확정, 모든 스테이지): 크게 뒤집힌 삼각 머리, 속이 빈 둥근 눈 둘,
		-- 머리 안의 삼각 입 + 입 둘레에 촘촘히 박힌 가는 바늘 이빨(윗니 16 · 아랫니 17, 노트 main-monster-bone.svg 6차)
		-- 좌표는 몸 시안 px(75px = 1스터드), 머리 가운데 기준
		f.tx, f.ty = 342, 99
		L({ { -114.5, -40.5 }, { 108, -71.5 }, { 6.5, 111 } }, 0.04, true)
		C(-34.5, -21.5, 15)
		C(30.5, -31.5, 15)
		L({ { -62, 11 }, { 63, -10.5 }, { 6.5, 98.5 } }, 0.03, true, -0.02)
		-- 바늘 이빨: 입 가장자리(x, y)에서 안쪽으로(SVG rotate 각도) len 만큼. 밑동 양 끝 → 끝 두 줄이 만나는 가시
		local function needles(deg: number, list: { { number } })
			local c, s = math.cos(math.rad(deg)), math.sin(math.rad(deg))
			local w = 2.1
			for _, q in list do
				local x, y, len = q[1] - f.tx, q[2] - f.ty, q[3]
				L({ { x - w * c, y - w * s }, { x + len * s, y - len * c }, { x + w * c, y + w * s } }, 0.012, false, -0.04)
				f.lines[#f.lines].tint = Faces.TEETH
			end
		end
		needles(170.24, { { 287.4, 108.7, 12 }, { 294.7, 107.5, 21 }, { 302.1, 106.2, 18 }, { 309.4, 104.9, 26 }, { 316.8, 103.7, 20 }, { 324.1, 102.4, 29 }, { 331.5, 101.1, 21 }, { 338.8, 99.9, 29 }, { 346.2, 98.6, 22 }, { 353.5, 97.4, 29 }, { 360.9, 96.1, 21 }, { 368.2, 94.8, 27 }, { 375.6, 93.6, 20 }, { 382.9, 92.3, 25 }, { 390.3, 91, 17 }, { 397.6, 89.8, 13 } })
		needles(51.9, { { 287.6, 119.7, 12 }, { 295.2, 129.4, 18 }, { 302.8, 139.2, 16 }, { 310.4, 148.9, 20 }, { 318.1, 158.6, 14 }, { 325.7, 168.3, 16 }, { 333.3, 178.1, 10 }, { 340.9, 187.8, 8 } })
		needles(-62.6, { { 399.4, 99.4, 10 }, { 393.7, 110.3, 17 }, { 388.1, 121.2, 20 }, { 382.4, 132.1, 16 }, { 376.8, 143, 21 }, { 371.1, 153.9, 16 }, { 365.5, 164.8, 17 }, { 359.8, 175.7, 12 }, { 354.2, 186.6, 8 } })
	elseif shape == 1 then
		-- 1 삼각: 기울어진 머리, 크기 다른 눈 5개, 머리 밖까지 찢어져 목까지 내려오는 입, 가슴까지 늘어진 혀
		f.tx, f.ty, f.deg = -4, -256, -24
		L({ { -30, 22 }, { -10, 23 }, { 9, 21 }, { 30, 22 }, { 15, -6 }, { 0, -34 }, { -16, -7 } }, 0.03, true)
		L({ { -36, 8 }, { -12, 6 }, { 12, 7 }, { 36, 4 } }, 0.028, false, -0.03)
		L(join(quad({ -36, 8 }, { -26, 50 }, { 0, 52 }, 4), quad({ 0, 52 }, { 26, 50 }, { 36, 4 }, 4)), 0.028, false, -0.03)
		teeth({ { -30, 8, -30, 20 }, { -25, 7, -24, 30 }, { -20, 7, -20, 16 }, { -15, 6, -14, 34 }, { -10, 6, -10, 18 }, { -5, 6, -4, 38 }, { 0, 7, 0, 20 }, { 5, 7, 5, 36 }, { 10, 7, 10, 16 }, { 15, 6, 16, 32 }, { 20, 6, 20, 14 }, { 25, 5, 25, 28 }, { 30, 5, 30, 12 } }, 0.014)
		teeth({ { -18, 46, -17, 36 }, { -8, 50, -8, 38 }, { 4, 51, 4, 40 }, { 14, 48, 14, 38 }, { 24, 40, 23, 32 } }, 0.014)
		L(join(quad({ 2, 50 }, { 10, 70 }, { 0, 86 }, 3), quad({ 0, 86 }, { -8, 100 }, { 4, 116 }, 3)), 0.02, false, -0.08)
		C(-8, -8, 7)
		C(-7, -7, 1.5, -0.07)
		C(7, -15, 2.4)
		C(11, -4, 1.6)
		C(1, -22, 1.4)
		C(-16, 2, 2)
		drool({ { -22, 40, -22, 52 }, { 28, 30, 29, 40 } })
	elseif shape == 2 then
		-- 2 사각: 부러진 목처럼 38° 꺾인 머리, 머리 폭 두 배로 삐져나온 입, 어깨에 작은 머리 하나 더
		f.tx, f.ty, f.deg = 16, -244, 38
		L({ { -22, -22 }, { -6, -24 }, { 9, -21 }, { 22, -22 }, { 21, -6 }, { 24, 9 }, { 22, 22 }, { 6, 24 }, { -8, 21 }, { -22, 22 }, { -21, 6 }, { -24, -8 } }, 0.03, true)
		L({ { -44, 2 }, { -14, 1 }, { 14, 3 }, { 44, 0 } }, 0.028, false, -0.03)
		L(join(quad({ -44, 2 }, { -30, 38 }, { -4, 42 }, 4), quad({ -4, 42 }, { 26, 40 }, { 44, 0 }, 4)), 0.028, false, -0.03)
		teeth({ { -38, 2, -37, 14 }, { -32, 1, -31, 24 }, { -26, 1, -26, 12 }, { -20, 1, -19, 30 }, { -14, 1, -14, 14 }, { -8, 2, -7, 34 }, { -2, 2, -2, 16 }, { 4, 2, 4, 36 }, { 10, 3, 10, 14 }, { 16, 2, 17, 30 }, { 22, 2, 22, 12 }, { 28, 1, 28, 24 }, { 34, 1, 34, 10 } }, 0.014)
		C(-9, -10, 8)
		C(-12, -12, 1.5, -0.07)
		C(-6, -7, 1, -0.07)
		C(12, -4, 1.8)
		-- 어깨의 작은 머리(몸 좌표)
		local m = T(-30, -210, -20)
		table.insert(f.extra, { pts = mapPts(m, { { -9, -9 }, { 9, -8 }, { 10, 9 }, { -8, 10 } }), r = 0.025, closed = true, dz = 0.55 })
		table.insert(f.extra, { pts = mapPts(m, { { -6, 5 }, { 7, 5 } }), r = 0.016, closed = false, dz = 0.5 })
		table.insert(f.extra, { pts = { { -24, -198 }, { -28, -202 }, { -30, -201 } }, r = 0.016, closed = false, dz = 0.6 })
		local ex, ey = m(-2, -2)
		table.insert(f.extraCircles, { u = ex, v = ey, rad = 2.4, dz = 0.5, pupil = false })
	elseif shape == 3 then
		-- 3 원: 둥근 머리가 세로로 쪼개져 V자로 벌어지고, 틈 안에 세로 눈동자의 큰 눈. 갈라진 면마다 이빨
		f.tx, f.ty, f.deg = 2, -256, 6
		L(ellipse(0, -2, 9, 20, 12), 0.022, true, 0.05)
		L(join(quad({ 0, -17 }, { 3, -2 }, { 0, 13 }, 3), quad({ 0, 13 }, { -3, -2 }, { 0, -17 }, 3)), 0.016, false, 0.03)
		for _, s in { -1, 1 } do
			local outline: { Pt } = {}
			for i = 0, 8 do
				local t = math.rad(-90 + i * 22.5)
				table.insert(outline, { 6 * s + s * 22 * math.cos(t), 22 * math.sin(t) })
			end
			for _, z in { { 10, 17 }, { 6, 12 }, { 11, 7 }, { 6, 2 }, { 11, -3 }, { 6, -8 }, { 11, -13 }, { 6, -18 } } do
				table.insert(outline, { z[1] * s, z[2] })
			end
			sub = Rabout(16 * s, 6 * s, 22)
			L(outline, 0.028, true)
			if s < 0 then
				C(-18, -6, 2.4)
				C(-18, -6, 0.8, -0.07)
				C(-14, 8, 1.4)
			else
				C(17, -8, 1.8)
				C(15, 6, 2.6)
				C(15, 6, 0.8, -0.07)
			end
			sub = nil
		end
		L(quad({ -14, -30 }, { 0, -24 }, { 14, -30 }, 3), 0.012, false, 0.02)
		drool({ { -2, 20, -3, 34 }, { 3, 19, 4, 30 } })
	elseif shape == 4 then
		-- 4 별: 다섯 꼭짓점에서 촉수가 뻗고 끝에 눈동자 있는 눈. 가운데 둥근 입 + 사방으로 난 이빨
		f.tx, f.ty, f.deg, f.scale = 0, -244, 14, 0.9
		L({ { 0, -26 }, { -7.3, -10.1 }, { -24.7, -8 }, { -11.9, 3.9 }, { -15.3, 21 }, { 0, 12.5 }, { 15.3, 21 }, { 11.9, 3.9 }, { 24.7, -8 }, { 7.3, -10.1 } }, 0.03, true)
		local tent = {
			{ { 0, -26 }, { 4, -34 }, { 0, -40 }, { 0, -44 }, { 1, -45 } },
			{ { -24.7, -8 }, { -32, -6 }, { -37, -12 }, { -41, -13 }, { -42, -12 } },
			{ { -15.3, 21 }, { -17, 30 }, { -23, 33 }, { -26, 36 }, { -25, 37 } },
			{ { 15.3, 21 }, { 20, 29 }, { 24, 32 }, { 27, 35 }, { 28, 34 } },
			{ { 24.7, -8 }, { 33, -12 }, { 38, -12 }, { 42, -13 }, { 41, -14 } },
		}
		for _, t in tent do
			L(quad(t[1], t[2], t[3], 3), 0.022)
			C(t[4][1], t[4][2], 4.2)
			C(t[5][1], t[5][2], 1.6, -0.07)
		end
		C(0, 0, 8)
		teeth({ { 0, -8, 0, -3 }, { 5.7, -5.7, 2.1, -2.1 }, { 8, 0, 3, 0 }, { 5.7, 5.7, 2.1, 2.1 }, { 0, 8, 0, 3 }, { -5.7, 5.7, -2.1, 2.1 }, { -8, 0, -3, 0 }, { -5.7, -5.7, -2.1, -2.1 } }, 0.012)
		drool({ { 0, 8, 1, 22 } })
	else
		-- 5 육각: 큰 육각 머리에 크기 다른 육각 혹 4개가 엉겨 붙음(혹마다 눈), 머리보다 넓은 입
		f.tx, f.ty, f.deg = 2, -256, -6
		-- 혹: { x, y, 회전, 육각 반지름, 눈 반지름, 눈동자(0 = 없음) }
		for _, lump in { { -21, -13, 18, 11, 3.4, 1 }, { 17, -19, -10, 9, 2, 0 }, { 23, 3, 25, 6, 1.4, 0 }, { -6, -30, 8, 6, 1.2, 0 } } do
			sub = T(lump[1], lump[2], lump[3])
			L(hexagon(lump[4]), 0.024, true, 0.04)
			C(0, 0, lump[5])
			if lump[6] > 0 then
				C(0, 0, lump[6], -0.07)
			end
			sub = nil
		end
		L(hexagon(16), 0.03, true)
		C(-5, -4, 4.6)
		C(-4, -3, 1.3, -0.07)
		C(7, -6, 1.8)
		L({ { -24, 11 }, { 24, 14 } }, 0.028, false, -0.03)
		L(join(quad({ -24, 11 }, { -14, 40 }, { 2, 42 }, 4), quad({ 2, 42 }, { 18, 40 }, { 24, 14 }, 4)), 0.028, false, -0.03)
		teeth({ { -19, 11, -19, 20 }, { -14, 12, -13, 27 }, { -9, 12, -9, 19 }, { -4, 12, -3, 30 }, { 1, 13, 1, 21 }, { 6, 13, 6, 31 }, { 11, 13, 11, 20 }, { 16, 14, 16, 27 }, { 21, 14, 21, 19 } }, 0.014)
		teeth({ { -10, 38, -10, 30 }, { 0, 41, 0, 32 }, { 10, 39, 10, 31 } }, 0.014)
		drool({ { -2, 42, -3, 56 } })
	end
	return f
end

return Faces
