--!strict
-- Day phase and weather (Bauplan.md, section 2). The phase follows server time, the weather follows
-- server time and a seed. Pure functions: the same input gives the same output in Lune and in Studio.
type Phase = { id: string, duration: number }
type Weather = { id: string, share: number }

local Env = {}

-- Park-Miller "minimal standard" generator: modulus 2^31 - 1, multiplier 16807. Integer arithmetic only,
-- every product stays below 2^53, so the numbers are exact on every runtime. math.random is not used.
local MODULUS = 2147483647
local MULTIPLIER = 16807

-- Value in (0, 1) for one weather period of one seed.
local function unitValue(seed: number, period: number): number
	local state = (seed * 7919 + period * 104729) % (MODULUS - 1) + 1
	state = (state * MULTIPLIER) % MODULUS
	state = (state * MULTIPLIER) % MODULUS
	return state / MODULUS
end

-- Phase at server time `time` in seconds. The day repeats after the sum of all phase durations.
function Env.phaseAt(time: number, phases: { Phase }): Phase
	local cycle = 0
	for _, phase in phases do
		cycle += phase.duration
	end

	local inCycle = time % cycle
	local elapsed = 0
	for _, phase in phases do
		elapsed += phase.duration
		if inCycle < elapsed then
			return phase
		end
	end
	return phases[#phases]
end

-- Weather at server time `time`. It changes every `interval` seconds (Bauplan: 120). Each period draws
-- one value from the seed and picks the weather whose share (in percent) covers it.
function Env.weatherAt(time: number, seed: number, weathers: { Weather }, interval: number): Weather
	local roll = unitValue(seed, math.floor(time / interval)) * 100
	local accumulated = 0
	for _, weather in weathers do
		accumulated += weather.share
		if roll < accumulated then
			return weather
		end
	end
	return weathers[#weathers]
end

return Env
