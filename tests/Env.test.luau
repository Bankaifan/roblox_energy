--!strict
-- Env (Bauplan section 2): phase from server time, weather from server time and seed. Same input, same output.
return function(t, load)
	local Env = load("Core/Env")
	local Phases = load("Config/Phases")
	local Weather = load("Config/Weather")

	-- One day is 480 s: Morgen 0-60, Mittag 60-210, Abend 210-300, Nacht 300-480
	t.equal(Env.phaseAt(0, Phases).id, "Morgen", "day starts in the morning")
	t.equal(Env.phaseAt(59.9, Phases).id, "Morgen", "morning lasts until 60 s")
	t.equal(Env.phaseAt(60, Phases).id, "Mittag", "noon starts at 60 s")
	t.equal(Env.phaseAt(210, Phases).id, "Abend", "evening starts at 210 s")
	t.equal(Env.phaseAt(300, Phases).id, "Nacht", "night starts at 300 s")
	t.equal(Env.phaseAt(480, Phases).id, "Morgen", "the day repeats after 480 s")
	t.equal(Env.phaseAt(480 * 7 + 250, Phases).id, "Abend", "the phase repeats on later days")

	-- Weather changes every 120 s and stays within one period
	local seed = 42
	local first = Env.weatherAt(120, seed, Weather, 120).id
	t.equal(Env.weatherAt(239.9, seed, Weather, 120).id, first, "weather holds until 240 s")

	-- Determinism: the same seed gives the same sequence, another seed a different one
	local function sequence(sequenceSeed: number): string
		local ids = {}
		for period = 0, 199 do
			table.insert(ids, Env.weatherAt(period * 120, sequenceSeed, Weather, 120).id)
		end
		return table.concat(ids, ",")
	end
	t.equal(sequence(seed), sequence(seed), "same seed, same weather sequence")
	t.truthy(sequence(seed) ~= sequence(43), "another seed gives another sequence")

	-- Shares: over 4000 periods every weather lands within 2 points of its share (Bauplan section 3)
	local counts: { [string]: number } = {}
	local periods = 4000
	for period = 0, periods - 1 do
		local id = Env.weatherAt(period * 120, seed, Weather, 120).id
		counts[id] = (counts[id] or 0) + 1
	end
	for _, weather in Weather do
		local observed = (counts[weather.id] or 0) / periods * 100
		t.truthy(math.abs(observed - weather.share) < 2, `{weather.id}: share {weather.share}, observed {observed}`)
	end
end
