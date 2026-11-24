--!strict
-- 리모트 과부하 방어: 플레이어·이름마다 토큰 통(초당 rate 개, 한 번에 burst 개까지). 정상 입력보다 넉넉하게 잡아
-- 평소 플레이는 절대 막히지 않고, 한꺼번에 수백 번 보내는 것만 버린다. 나간 플레이어 기록은 지운다.

local Players = game:GetService("Players")

local RateLimit = {}

type Bucket = { tokens: number, at: number }
local buckets: { [Player]: { [string]: Bucket } } = {}
RateLimit.dropped = {} :: { [string]: number } -- (측정) 버린 수

-- true 면 처리, false 면 버린다
function RateLimit.allow(p: Player, key: string, rate: number, burst: number): boolean
	local per = buckets[p]
	if not per then
		if not p.Parent then
			return false -- (이미 나간 사람)
		end
		per = {}
		buckets[p] = per
	end
	local now = os.clock()
	local b = per[key]
	if not b then
		b = { tokens = burst, at = now }
		per[key] = b
	end
	b.tokens = math.min(burst, b.tokens + (now - b.at) * rate)
	b.at = now
	if b.tokens < 1 then
		RateLimit.dropped[key] = (RateLimit.dropped[key] or 0) + 1
		return false
	end
	b.tokens -= 1
	return true
end

Players.PlayerRemoving:Connect(function(p)
	buckets[p] = nil
end)

return RateLimit
