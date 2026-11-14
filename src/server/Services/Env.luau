--!strict
-- Phase and weather from server time (Bauplan, section 2). One seed per server; weather changes every 120 s.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local EnvCore = require(Shared:WaitForChild("Core"):WaitForChild("Env") :: ModuleScript) :: any
local Phases = require(Shared:WaitForChild("Config"):WaitForChild("Phases") :: ModuleScript) :: any
local Weathers = require(Shared:WaitForChild("Config"):WaitForChild("Weather") :: ModuleScript) :: any

local WEATHER_SECONDS = 120
local seed = math.random(1, 2147483646)
local announced = ""

local Env = {}

-- Phase and weather at this moment. Sends nothing.
function Env.current(): (any, any)
	local now = workspace:GetServerTimeNow()
	return EnvCore.phaseAt(now, Phases), EnvCore.weatherAt(now, seed, Weathers, WEATHER_SECONDS)
end

-- Phase and weather now. Sends Env to all players when either changed since the last send.
function Env.update(remotes: { [string]: RemoteEvent }): (any, any)
	local phase, weather = Env.current()
	local key = phase.id .. "/" .. weather.id
	if key ~= announced then
		announced = key
		remotes.Env:FireAllClients({ phase = phase.id, weather = weather.id })
	end
	return phase, weather
end

return Env
