--!strict
-- Clock hour and light mood of the world (issue 85). The clock follows the day phases of the game (Bauplan,
-- section 2), so the sun stands where the HUD phase says. Pure functions: no Roblox APIs, colors are {r, g, b} in 0..255.
type Phase = { id: string, duration: number }
type Color = { number }
export type Mood = {
	hour: number,
	brightness: number,
	exposure: number,
	ambient: Color,
	outdoor: Color,
	shift: Color,
	density: number,
	haze: number,
	glare: number,
	air: Color,
	decay: Color,
	tint: Color,
	saturation: number,
	contrast: number,
	bloom: number,
	rays: number,
	glow: number,
}

local DayCycle = {}

-- Clock hour at which each phase starts. A phase runs to the start hour of the next one.
DayCycle.HOURS = { Morgen = 5.5, Mittag = 9, Abend = 16.5, Nacht = 20 } :: { [string]: number }

-- Look of the world at fixed hours, blended in between. Warm and hazy by day, a long golden evening, a blue moonlit
-- night. glow: 0 by day, 1 at night; lamps and glowing plants follow it.
local NIGHT: Mood = {
	hour = 0,
	brightness = 1.4,
	exposure = 0.35,
	ambient = { 44, 52, 86 },
	outdoor = { 40, 50, 90 },
	shift = { 120, 150, 255 },
	density = 0.38,
	haze = 1.2,
	glare = 0,
	air = { 62, 76, 116 },
	decay = { 30, 38, 74 },
	tint = { 208, 218, 255 },
	saturation = 0.05,
	contrast = 0.12,
	bloom = 0.9,
	rays = 0.02,
	glow = 1,
}

local function at(hour: number, base: Mood): Mood
	local copy = table.clone(base)
	copy.hour = hour
	return copy
end

local KEYS: { Mood } = {
	NIGHT,
	at(5, NIGHT),
	{
		hour = 6.2,
		brightness = 1.7,
		exposure = 0.1,
		ambient = { 96, 82, 92 },
		outdoor = { 122, 102, 106 },
		shift = { 255, 172, 122 },
		density = 0.36,
		haze = 1.8,
		glare = 0.8,
		air = { 255, 192, 152 },
		decay = { 204, 124, 112 },
		tint = { 255, 232, 220 },
		saturation = 0.12,
		contrast = 0.1,
		bloom = 0.7,
		rays = 0.14,
		glow = 0.3,
	},
	{
		hour = 8.5,
		brightness = 2.4,
		exposure = 0,
		ambient = { 110, 112, 118 },
		outdoor = { 140, 140, 140 },
		shift = { 255, 236, 200 },
		density = 0.3,
		haze = 1,
		glare = 0.3,
		air = { 212, 222, 236 },
		decay = { 150, 170, 200 },
		tint = { 255, 248, 238 },
		saturation = 0.08,
		contrast = 0.06,
		bloom = 0.45,
		rays = 0.08,
		glow = 0,
	},
	{
		hour = 13,
		brightness = 2.8,
		exposure = 0,
		ambient = { 120, 124, 130 },
		outdoor = { 150, 152, 156 },
		shift = { 255, 244, 220 },
		density = 0.27,
		haze = 0.6,
		glare = 0.2,
		air = { 202, 216, 236 },
		decay = { 130, 160, 200 },
		tint = { 255, 252, 244 },
		saturation = 0.1,
		contrast = 0.05,
		bloom = 0.4,
		rays = 0.05,
		glow = 0,
	},
	{
		hour = 16.5,
		brightness = 2.6,
		exposure = 0,
		ambient = { 126, 112, 100 },
		outdoor = { 160, 140, 120 },
		shift = { 255, 214, 160 },
		density = 0.3,
		haze = 1.2,
		glare = 0.6,
		air = { 240, 210, 176 },
		decay = { 190, 150, 120 },
		tint = { 255, 240, 222 },
		saturation = 0.14,
		contrast = 0.08,
		bloom = 0.5,
		rays = 0.1,
		glow = 0,
	},
	{
		hour = 18,
		brightness = 2,
		exposure = -0.05,
		ambient = { 120, 88, 84 },
		outdoor = { 166, 112, 96 },
		shift = { 255, 150, 90 },
		density = 0.36,
		haze = 2.2,
		glare = 1.2,
		air = { 255, 170, 120 },
		decay = { 220, 110, 90 },
		tint = { 255, 222, 205 },
		saturation = 0.2,
		contrast = 0.12,
		bloom = 0.8,
		rays = 0.18,
		glow = 0.35,
	},
	{
		hour = 19.3,
		brightness = 1.3,
		exposure = 0.2,
		ambient = { 72, 62, 98 },
		outdoor = { 82, 70, 114 },
		shift = { 190, 150, 230 },
		density = 0.4,
		haze = 1.8,
		glare = 0.2,
		air = { 150, 110, 152 },
		decay = { 90, 60, 110 },
		tint = { 228, 218, 250 },
		saturation = 0.12,
		contrast = 0.12,
		bloom = 0.9,
		rays = 0.04,
		glow = 0.85,
	},
	at(20.5, NIGHT),
	at(24, NIGHT),
}

-- Clock hour (0..24) at server time `time` in seconds. Linear inside a phase, so the hour never jumps.
function DayCycle.clockAt(time: number, phases: { Phase }): number
	local cycle = 0
	for _, phase in phases do
		cycle += phase.duration
	end

	local inCycle = time % cycle
	local elapsed = 0
	for index, phase in phases do
		if inCycle < elapsed + phase.duration then
			local from = DayCycle.HOURS[phase.id]
			local to = DayCycle.HOURS[phases[index % #phases + 1].id]
			if to <= from then
				to += 24
			end
			return (from + (to - from) * (inCycle - elapsed) / phase.duration) % 24
		end
		elapsed += phase.duration
	end
	return DayCycle.HOURS[phases[1].id]
end

local function mix(a: any, b: any, share: number): any
	if type(a) == "number" then
		return a + (b - a) * share
	end
	local color = {}
	for index, value in a do
		color[index] = value + (b[index] - value) * share
	end
	return color
end

-- Mood at clock hour `hour`: every value blended between the two fixed hours around it.
function DayCycle.mood(hour: number): Mood
	local clock = hour % 24
	for index = 1, #KEYS - 1 do
		local from, to = KEYS[index] :: any, KEYS[index + 1] :: any
		if clock < to.hour then
			local share = (clock - from.hour) / (to.hour - from.hour)
			local mood = {}
			for name, value in from do
				mood[name] = mix(value, to[name], share)
			end
			mood.hour = clock
			return mood :: any
		end
	end
	return at(clock, NIGHT)
end

return DayCycle
