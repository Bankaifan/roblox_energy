--!strict
-- WeatherLook (issue 288): every weather of Config/Weather has a look, the rotor follows its wind, looks blend without a jump.
return function(t, load)
	local WeatherLook = load("Core/WeatherLook")
	local Weather = load("Config/Weather")

	for _, weather in Weather do
		local look = WeatherLook.of(Weather, weather.id)
		t.truthy(look ~= nil, `{weather.id} has no WeatherLook row`)
		t.truthy(look.cover >= 0 and look.cover <= 1, `{weather.id}: cover leaves 0..1`)
		t.truthy(look.density >= 0 and look.density <= 1, `{weather.id}: density leaves 0..1`)
		t.truthy(look.brightness > 0 and look.brightness <= 1, `{weather.id}: brightness leaves 0..1`)
		t.equal(look.rotor, weather.wind, `{weather.id}: rotor factor is not the wind of Config/Weather`)
	end

	local changed = { { id = "Sonnig", wind = 3.5 } }
	t.equal(WeatherLook.of(changed, "Sonnig").rotor, 3.5, "a changed wind moves the rotor")
	t.equal(WeatherLook.of(Weather, "Nebel"), nil, "an unknown weather has no look")
	t.equal(WeatherLook.of({}, "Sonnig"), nil, "a weather missing in the config has no look")

	t.truthy(
		WeatherLook.of(Weather, "Bewoelkt").cover > WeatherLook.of(Weather, "Sonnig").cover,
		"cloudy is cloudier than sunny"
	)
	t.truthy(WeatherLook.of(Weather, "Gewitter").rain > 0, "a storm rains")
	t.equal(WeatherLook.of(Weather, "Sonnig").rain, 0, "sunny weather does not rain")

	local sunny = WeatherLook.of(Weather, "Sonnig")
	local storm = WeatherLook.of(Weather, "Gewitter")
	t.equal(WeatherLook.blend(sunny, storm, 0).cover, sunny.cover, "a blend starts at the old look")
	t.equal(WeatherLook.blend(sunny, storm, 1).cover, storm.cover, "a blend ends at the new look")
	t.truthy(
		math.abs(WeatherLook.blend(sunny, storm, 0.5).cover - (sunny.cover + storm.cover) / 2) < 1e-9,
		"a blend is linear"
	)
	t.equal(WeatherLook.share(0), 0, "no time, no blend")
	t.equal(WeatherLook.share(WeatherLook.BLEND_SECONDS * 3), 1, "the share stops at 1")
	t.equal(WeatherLook.share(WeatherLook.BLEND_SECONDS / 2), 0.5, "half the time, half the blend")
end
