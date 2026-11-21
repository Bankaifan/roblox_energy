--!strict
-- What the world looks like in each weather (issue 288). One row per id of Config/Weather: clouds, light, haze and particles.
-- The rotor factor is not stored here: it is the wind of Config/Weather, so there is no second weather table.
-- Pure functions: no Roblox APIs. The client blends from the previous look to the new one when Env names another weather.
export type Look = {
	cover: number,
	density: number,
	brightness: number,
	haze: number,
	rain: number,
	streaks: number,
	flash: boolean,
	rotor: number,
}

local WeatherLook = {}

-- Seconds a look takes to blend into the next one.
WeatherLook.BLEND_SECONDS = 6

-- brightness and haze multiply the mood of the time of day, rain and streaks are particles per second.
WeatherLook.ROWS = {
	Sonnig = { cover = 0.15, density = 0.4, brightness = 1, haze = 1, rain = 0, streaks = 0, flash = false },
	Bewoelkt = { cover = 0.85, density = 0.7, brightness = 0.75, haze = 1.3, rain = 0, streaks = 0, flash = false },
	Windig = { cover = 0.4, density = 0.5, brightness = 0.9, haze = 1, rain = 0, streaks = 20, flash = false },
	Gewitter = { cover = 1, density = 0.9, brightness = 0.5, haze = 1.6, rain = 120, streaks = 0, flash = true },
	Flaute = { cover = 0.2, density = 0.3, brightness = 1, haze = 1.2, rain = 0, streaks = 0, flash = false },
} :: { [string]: any }

-- The look of weather `id`; `weathers` is Config/Weather. An unknown id gives nil.
function WeatherLook.of(weathers: { any }, id: string): Look?
	local row = WeatherLook.ROWS[id]
	if row == nil then
		return nil
	end
	for _, weather in weathers do
		if weather.id == id then
			local look = table.clone(row)
			look.rotor = weather.wind
			return look :: Look
		end
	end
	return nil
end

-- Share (0..1) of the blend after `elapsed` seconds.
function WeatherLook.share(elapsed: number): number
	return math.clamp(elapsed / WeatherLook.BLEND_SECONDS, 0, 1)
end

-- Numbers move between two looks; flash switches with the target look.
function WeatherLook.blend(from: Look, to: Look, share: number): Look
	local look = table.clone(to)
	for name, value in to :: any do
		if type(value) == "number" then
			(look :: any)[name] = value + ((from :: any)[name] - value) * (1 - share)
		end
	end
	return look
end

return WeatherLook
