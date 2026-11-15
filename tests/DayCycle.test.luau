--!strict
-- DayCycle (issue 85): the clock follows the day phases, the mood blends without a jump.
return function(t, load)
	local DayCycle = load("Core/DayCycle")
	local Phases = load("Config/Phases")

	-- One day is 480 s: Morgen 0-60, Mittag 60-210, Abend 210-300, Nacht 300-480
	t.equal(DayCycle.clockAt(0, Phases), 5.5, "the morning starts before sunrise")
	t.equal(DayCycle.clockAt(60, Phases), 9, "midday phase starts at 9 o'clock")
	t.equal(DayCycle.clockAt(255, Phases), 18.25, "the sun sets in the middle of the evening phase")
	t.equal(DayCycle.clockAt(300, Phases), 20, "the night phase starts in the dark")
	t.equal(DayCycle.clockAt(390, Phases), 0.75, "the clock wraps at midnight")
	t.equal(DayCycle.clockAt(480 * 3 + 60, Phases), 9, "the clock repeats on later days")

	t.equal(DayCycle.mood(13).glow, 0, "nothing glows at midday")
	t.equal(DayCycle.mood(DayCycle.clockAt(300, Phases)).glow > 0.9, true, "plants glow when the night phase starts")
	t.equal(DayCycle.mood(2).glow, 1, "plants glow at night")

	-- No jump anywhere on the clock, midnight included, and every color stays a color
	local previous = DayCycle.mood(23.99)
	for step = 0, 240 do
		local mood = DayCycle.mood(step / 10)
		t.truthy(math.abs(mood.brightness - previous.brightness) < 0.2, `brightness jumps at {step / 10}`)
		t.truthy(math.abs(mood.glow - previous.glow) < 0.2, `glow jumps at {step / 10}`)
		for _, name in { "ambient", "outdoor", "shift", "air", "decay", "tint" } do
			for _, channel in mood[name] do
				t.truthy(channel >= 0 and channel <= 255, `{name} leaves 0..255 at {step / 10}`)
			end
		end
		previous = mood
	end
end
