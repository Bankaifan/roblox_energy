--!strict
-- How the world looks in each weather (issue 288, design docs/weather-sky-design.md, section 4.1). One row per id of
-- Config/Weather. Pure functions: no Roblox APIs. The rotor factor is the wind of Config/Weather, there is no second table.
export type Look = {
	cover: number,
	density: number,
	light: number,
	haze: number,
	rain: number,
	streaks: number,
	flash: boolean,
	rotor: number,
}

local WeatherLook = {}

WeatherLook.ROWS = {
	Sonnig = { cover = 0.15, density = 0.4, light = 1.0, haze = 1.0, rain = 0, streaks = 0, flash = false },
	Bewoelkt = { cover = 0.85, density = 0.7, light = 0.75, haze = 1.3, rain = 0, streaks = 0, flash = false },
	Windig = { cover = 0.4, density = 0.5, light = 0.9, haze = 1.0, rain = 0, streaks = 20, flash = false },
	Gewitter = { cover = 1.0, density = 0.9, light = 0.5, haze = 1.6, rain = 120, streaks = 0, flash = true },
	Flaute = { cover = 0.2, density = 0.3, light = 1.0, haze = 1.2, rain = 0, streaks = 0, flash = false },
} :: { [string]: any }

-- The look of one weather id; rotor is the wind of the config. nil for an unknown id.
function WeatherLook.of(id: string, weathers: { any }): Look?
	local row = WeatherLook.ROWS[id]
	if row == nil then
		return nil
	end
	for _, weather in weathers do
		if weather.id == id then
			return {
				cover = row.cover,
				density = row.density,
				light = row.light,
				haze = row.haze,
				rain = row.rain,
				streaks = row.streaks,
				flash = row.flash,
				rotor = weather.wind,
			}
		end
	end
	return nil
end

local function mix(a: number, b: number, k: number): number
	return a + (b - a) * k
end

-- Blend from one look to another; k runs 0..1 (clamped). The flash flag switches at the half.
function WeatherLook.blend(from: Look, to: Look, k: number): Look
	local f = math.clamp(k, 0, 1)
	return {
		cover = mix(from.cover, to.cover, f),
		density = mix(from.density, to.density, f),
		light = mix(from.light, to.light, f),
		haze = mix(from.haze, to.haze, f),
		rain = mix(from.rain, to.rain, f),
		streaks = mix(from.streaks, to.streaks, f),
		flash = if f < 0.5 then from.flash else to.flash,
		rotor = mix(from.rotor, to.rotor, f),
	}
end

return WeatherLook
