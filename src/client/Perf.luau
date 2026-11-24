--!strict
-- 성능 측정(클라이언트). 시스템마다 걸린 CPU 시간(os.clock)을 모으고, 프레임 시간 표본을 남긴다.
-- 비용: 한 번에 os.clock 두 번 + 표 덧셈 — 게임에는 영향이 없을 만큼 작다. 자동 테스트(TestProbe "perfx")가 읽는다.
-- MicroProfiler 에서도 같은 이름으로 보이게 debug.profilebegin/profileend 를 함께 건다.

local Perf = {}

local acc: { [string]: number } = {} -- 이름 → 누적 초
local cnt: { [string]: number } = {} -- 이름 → 호출 수
local worst: { [string]: number } = {} -- 이름 → 한 번에 가장 오래 걸린 초
Perf.frames = {} :: { number } -- 프레임 시간(dt) 표본
Perf.lua = {} :: { number } -- 프레임마다 음파·이동 스크립트 시간
Perf.counters = {} :: { [string]: number } -- 받은 이벤트 수 등
local MAX = 6000

function Perf.add(name: string, dt: number)
	acc[name] = (acc[name] or 0) + dt
	cnt[name] = (cnt[name] or 0) + 1
	if dt > (worst[name] or 0) then
		worst[name] = dt
	end
end

function Perf.count(name: string, n: number?)
	Perf.counters[name] = (Perf.counters[name] or 0) + (n or 1)
end

-- f 를 재면서 부른다(MicroProfiler 이름 = name)
function Perf.wrap<A..., R...>(name: string, f: (A...) -> R...): (A...) -> R...
	return function(...: A...): R...
		debug.profilebegin(name)
		local t = os.clock()
		local function finish(...: R...): R...
			Perf.add(name, os.clock() - t)
			debug.profileend()
			return ...
		end
		return finish(f(...))
	end
end

function Perf.frame(dt: number, luaSec: number)
	local f = Perf.frames
	if #f < MAX then
		table.insert(f, dt)
		table.insert(Perf.lua, luaSec)
	end
end

function Perf.reset()
	table.clear(acc)
	table.clear(cnt)
	table.clear(worst)
	table.clear(Perf.frames)
	table.clear(Perf.lua)
	table.clear(Perf.counters)
end

local function pct(sorted: { number }, q: number): number
	if #sorted == 0 then
		return 0
	end
	return sorted[math.clamp(math.ceil(#sorted * q), 1, #sorted)]
end

-- 요약: 프레임 시간 분포(ms), FPS 평균·1% low, 시스템별 프레임당 평균 ms·최악 ms
function Perf.summary(): { [string]: any }
	local f = table.clone(Perf.frames)
	table.sort(f)
	local sum = 0
	for _, v in f do
		sum += v
	end
	local n = #f
	local avg = if n > 0 then sum / n else 0
	-- 1% low = 가장 느린 1% 프레임의 평균 FPS
	local k = math.max(1, math.floor(n * 0.01))
	local slow = 0
	for i = math.max(1, n - k + 1), n do
		slow += f[i]
	end
	local l = table.clone(Perf.lua)
	table.sort(l)
	local lsum = 0
	for _, v in l do
		lsum += v
	end
	local sys = {}
	for name, a in acc do
		sys[name] = {
			perFrameMs = if n > 0 then a / n * 1000 else 0,
			calls = cnt[name],
			avgMs = a / math.max(1, cnt[name]) * 1000,
			worstMs = (worst[name] or 0) * 1000,
		}
	end
	return {
		frames = n,
		avgMs = avg * 1000,
		fps = if avg > 0 then 1 / avg else 0,
		low1Fps = if n > 0 and slow > 0 then 1 / (slow / math.min(k, n)) else 0,
		p95Ms = pct(f, 0.95) * 1000,
		p99Ms = pct(f, 0.99) * 1000,
		worstMs = (f[n] or 0) * 1000,
		luaAvgMs = if #l > 0 then lsum / #l * 1000 else 0,
		luaP95Ms = pct(l, 0.95) * 1000,
		luaP99Ms = pct(l, 0.99) * 1000,
		luaWorstMs = (l[#l] or 0) * 1000,
		sys = sys,
		counters = table.clone(Perf.counters),
	}
end

return Perf
