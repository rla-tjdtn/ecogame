--!strict
-- (측정) 리모트 송수신·속성 복제 횟수와 소리 통계. 비용은 표 덧셈 한 번. 자동 테스트(TestProbe "netaudio")가 읽고 비운다.

local NetStat = {}

NetStat.counts = {} :: { [string]: number }
NetStat.t0 = os.clock()

function NetStat.count(name: string, n: number?)
	NetStat.counts[name] = (NetStat.counts[name] or 0) + (n or 1)
end

function NetStat.snapshot(reset: boolean?): { [string]: any }
	local out = { seconds = os.clock() - NetStat.t0, counts = table.clone(NetStat.counts) }
	if reset then
		table.clear(NetStat.counts)
		NetStat.t0 = os.clock()
	end
	return out
end

return NetStat
