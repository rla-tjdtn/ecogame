--!strict
-- 서버의 소리 이벤트 통로. 음파·발소리·문 소리가 여기로 들어오고, 괴물들이 듣는다.
-- 들리는 거리 = 소리 크기(반경) × (벽 감쇠 ^ 사이에 낀 벽 수).
-- 지금은 거리 + 벽 개수 감쇠. 나중에 경로 길이 기반 전파 등으로 바꾸려면 heardRange 만 고치면 된다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local SoundBus = {}

export type Listener = (pos: Vector3, radius: number, source: Player?, kind: string) -> ()

local listeners: { Listener } = {}
SoundBus.recent = {} :: { { pos: Vector3, radius: number, kind: string, t: number, source: string } }

local geometry: Instance? = nil
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.RespectCanCollide = true

function SoundBus.setGeometry(folder: Instance?)
	geometry = folder
	if folder then
		params.FilterDescendantsInstances = { folder }
	end
end

function SoundBus.listen(fn: Listener): () -> ()
	table.insert(listeners, fn)
	return function()
		local i = table.find(listeners, fn)
		if i then
			table.remove(listeners, i)
		end
	end
end

-- a 와 b 사이의 벽(충돌 파트) 수, 최대 MaxWallsCounted
function SoundBus.wallsBetween(a: Vector3, b: Vector3): number
	if not geometry then
		return 0
	end
	local count = 0
	local from = a
	for _ = 1, Config.Noise.MaxWallsCounted do
		local d = b - from
		if d.Magnitude < 0.1 then
			break
		end
		local hit = workspace:Raycast(from, d, params)
		if not hit then
			break
		end
		count += 1
		-- (파트 안에서 시작한 레이는 그 파트를 다시 맞히지 않으므로 다음 레이는 벽 너머로 나간다)
		from = hit.Position + d.Unit * 0.05
	end
	return count
end

-- 소리(pos, radius)가 listenerPos 에서 들리는 최대 거리
function SoundBus.heardRange(pos: Vector3, listenerPos: Vector3, radius: number): number
	if (pos - listenerPos).Magnitude > radius then
		return radius -- 이미 범위 밖: 벽 계산 생략
	end
	local walls = SoundBus.wallsBetween(pos + Vector3.new(0, 0.5, 0), listenerPos)
	return radius * (Config.Noise.WallAttenuation ^ walls)
end

function SoundBus.canHear(pos: Vector3, listenerPos: Vector3, radius: number): boolean
	local d = (pos - listenerPos).Magnitude
	if d > radius then
		return false
	end
	return d <= SoundBus.heardRange(pos, listenerPos, radius)
end

function SoundBus.emit(pos: Vector3, radius: number, source: Player?, kind: string)
	table.insert(SoundBus.recent, { pos = pos, radius = radius, kind = kind, t = os.clock(), source = if source then source.Name else "" })
	if #SoundBus.recent > 50 then
		table.remove(SoundBus.recent, 1)
	end
	for _, fn in table.clone(listeners) do
		local ok, err = pcall(fn, pos, radius, source, kind)
		if not ok then
			warn("[SoundBus] listener error: " .. tostring(err))
		end
	end
end

return SoundBus
