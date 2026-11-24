-- Studio plugin: runs automated play tests on request from tools/studio-test.js (음파공포).
-- It asks http://localhost:<port>/next every 2 s (port = the place's ServerStorage attribute TestPort, baked in by
-- tools/perf-build.sh so several Studio windows can run tests at once; 34902 when the place has none); when a test is queued it starts a real Play session with
-- StudioTestService:ExecutePlayModeAsync, or ExecuteMultiplayerTestAsync with a local server and job.players clients
-- (the game's TestHarness script plays the scenario and calls EndTest),
-- then posts what came back to /result. Only the edit session polls; nothing runs in normal play.
-- Installed by copying this file into %LOCALAPPDATA%\Roblox\Plugins (tools/studio-test.js (음파공포) does that).

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local StudioTestService = game:GetService("StudioTestService")

-- (only the editing window: the server and player windows a multiplayer test opens load plugins too)
if RunService:IsRunning() or not RunService:IsEdit() then return end

-- (only this game: another place open in Studio at the same time never takes its tests)
local function thisGame(): boolean
	local server = game:GetService("ServerScriptService"):FindFirstChild("Server")
	local stages = server and server:FindFirstChild("Stages")
	return stages ~= nil and stages:FindFirstChild("Stage1") ~= nil and server:FindFirstChild("StageBuilder") ~= nil and server:FindFirstChild("TestHarness") ~= nil
end

local busy = false

-- (each place picks its own port: read every poll, the place may finish loading after the plugin starts)
local function base(): string
	local port = game:GetService("ServerStorage"):GetAttribute("TestPort")
	return "http://localhost:" .. tostring(if type(port) == "number" then port else 34902)
end

local function request(method, path, body)
	return pcall(function()
		return HttpService:RequestAsync({
			Url = base() .. path,
			Method = method,
			Body = body,
			Headers = if body then { ["Content-Type"] = "application/json" } else nil,
		})
	end)
end

task.spawn(function()
	while true do
		task.wait(2)
		if not busy and thisGame() then
			local ok, res = request("GET", "/next")
			if ok and res.Success and res.Body ~= "" then
				local job = HttpService:JSONDecode(res.Body)
				if job and job.id then
					busy = true
					request("POST", "/started", HttpService:JSONEncode({ id = job.id }))
					local ran, result = pcall(function()
						if (tonumber(job.players) or 1) > 1 then return StudioTestService:ExecuteMultiplayerTestAsync(tonumber(job.players), job.args or {}) end
						return StudioTestService:ExecutePlayModeAsync(job.args or {})
					end)
					request("POST", "/result", HttpService:JSONEncode({ id = job.id, ok = ran, result = if ran then result else tostring(result) }))
					busy = false
				end
			end
		end
	end
end)
