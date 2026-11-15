--!strict
-- Phase and weather from server time (Bauplan, section 2). One seed per server; weather changes every 120 s.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local EnvCore = require(Shared:WaitForChild("Core"):WaitForChild("Env") :: ModuleScript) :: any
local Phases = require(Shared:WaitForChild("Config"):WaitForChild("Phases") :: ModuleScript) :: any
local Weathers = require(Shared:WaitForChild("Config"):WaitForChild("Weather") :: ModuleScript) :: any
local BoostService = require(script.Parent.BoostService)

local WEATHER_SECONDS = 120
local seed = math.random(1, 2147483646)
-- The Env payload last sent to all players.
local announced: { [string]: any }? = nil

local Env = {}

-- True when both payloads hold the same value in every field.
local function same(previous: { [string]: any }?, payload: { [string]: any }): boolean
	if previous == nil then
		return false
	end
	for field, value in payload do
		if previous[field] ~= value then
			return false
		end
	end
	return true
end

-- Phase and weather at this moment. Sends nothing.
function Env.current(): (any, any)
	local now = workspace:GetServerTimeNow()
	return EnvCore.phaseAt(now, Phases), EnvCore.weatherAt(now, seed, Weathers, WEATHER_SECONDS)
end

-- What every client gets in Env: phase, weather and the Sunshine Hour (end time, buyer, seconds queued behind it).
function Env.payload(phase: any, weather: any): { [string]: any }
	local sunshine = BoostService.sunshineStatus()
	return {
		phase = phase.id,
		weather = weather.id,
		sunshineEnds = sunshine.ends,
		sunshineBuyer = sunshine.buyer,
		sunshineQueued = sunshine.queued,
	}
end

-- Phase and weather now. Sends Env to all players when anything in it changed since the last send, including the
-- Sunshine Hour starting, queueing or ending.
function Env.update(remotes: { [string]: RemoteEvent }): (any, any)
	local phase, weather = Env.current()
	local payload = Env.payload(phase, weather)
	if not same(announced, payload) then
		announced = payload
		remotes.Env:FireAllClients(payload)
	end
	return phase, weather
end

return Env
