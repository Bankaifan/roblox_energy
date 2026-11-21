--!strict
-- WeatherLook (issue 288): every weather of the config has a look, the rotor follows the config wind, looks blend without a jump.
return function(t, load)
	local WeatherLook = load("Core/WeatherLook")
	local Weathers = load("Config/Weather")

	for _, weather in Weathers do
		local look = WeatherLook.of(weather.id, Weathers)
		t.truthy(look ~= nil, `no look for the weather {weather.id}`)
		if look ~= nil then
			t.truthy(look.cover >= 0 and look.cover <= 1, `cover of {weather.id} leaves 0..1`)
			t.truthy(look.density >= 0 and look.density <= 1, `density of {weather.id} leaves 0..1`)
			t.equal(look.rotor, weather.wind, `rotor of {weather.id} is not the config wind`)
		end
	end

	t.equal(WeatherLook.of("Nebel", Weathers), nil, "an unknown id has no look")
	t.equal(WeatherLook.of("Sonnig", { { id = "Sonnig", wind = 3 } }).rotor, 3, "a changed config wind moves the rotor")

	local sunny = WeatherLook.of("Sonnig", Weathers)
	local storm = WeatherLook.of("Gewitter", Weathers)
	t.truthy(storm.cover > sunny.cover, "a storm is cloudier than a sunny day")
	t.truthy(storm.rain > 0 and sunny.rain == 0, "only the storm rains")

	t.equal(WeatherLook.blend(sunny, storm, 0).cover, sunny.cover, "the blend starts at the old look")
	t.equal(WeatherLook.blend(sunny, storm, 1).cover, storm.cover, "the blend ends at the new look")
	t.equal(WeatherLook.blend(sunny, storm, 5).cover, storm.cover, "the blend is clamped")
	t.equal(WeatherLook.blend(sunny, storm, 0.5).cover, (sunny.cover + storm.cover) / 2, "the blend is linear")
end
