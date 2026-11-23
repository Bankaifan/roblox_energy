--!strict
-- The day clock card (issue 288, docs/weather-sky-design.md, step 2): the angle of the dial, its 24 hour segments, the day and
-- night lengths, the countdown to the next change and the three text lines. Pure Luau, no Roblox APIs: the client controller
-- (Controllers/Clock) only draws what this returns. The caller passes DayCycle.HOURS and Config/Phases (core modules do not
-- require each other), so nothing here is a second clock: the hour comes from DayCycle.clockAt, the lengths from Phases.
type Phase = { id: string, duration: number }
type Translate = (key: string, args: { [string]: any }?) -> string

local ClockView = {}

-- The one phase that is night; every other phase is day.
ClockView.NIGHT = "Nacht"

-- Chip colour {r, g, b} of the weather text, by Config/Weather id.
local CHIPS: { [string]: { number } } = {
	Sonnig = { 255, 200, 0 },
	Bewoelkt = { 140, 154, 178 },
	Windig = { 80, 210, 255 },
	Gewitter = { 120, 96, 200 },
	Flaute = { 120, 190, 150 },
}

function ClockView.chip(weatherId: string): { number }?
	return CHIPS[weatherId]
end

-- The forecast arrow: the text and chip colour of the next weather, or nil. `nextId` is view.price.nextWeather, which the
-- server sets only for a player with U15, so no extension means no arrow.
function ClockView.forecast(nextId: string?, t: Translate): { text: string, color: { number } }?
	if nextId == nil then
		return nil
	end
	local color = CHIPS[nextId]
	if color == nil then
		return nil
	end
	return { text = t("clock.next", { weather = t("weather." .. nextId) }), color = color }
end

-- Rotation in degrees of the dial container at clock hour `hour`: the current time sits under the fixed pointer at the top.
-- Noon is 0 degrees, midnight 180.
function ClockView.angle(hour: number): number
	return (12 - hour) * 15 % 360
end

-- The 24 hour segments, hour 0 first: `angle` is where the middle of the segment sits on the unturned dial (noon at 0), `night`
-- is true when the middle lies in the night, from the Nacht hour to the Morgen hour of `hours` (DayCycle.HOURS).
function ClockView.segments(hours: { [string]: number }): { { angle: number, night: boolean } }
	local nightFrom, nightTo = hours[ClockView.NIGHT], hours.Morgen
	local list = {}
	for hour = 0, 23 do
		local middle = hour + 0.5
		table.insert(list, {
			angle = (middle - 12) * 15,
			night = middle >= nightFrom or middle < nightTo,
		})
	end
	return list
end

-- Seconds of day and of night in one cycle, as sums of Config/Phases.
function ClockView.lengths(phases: { Phase }): (number, number)
	local day, night = 0, 0
	for _, phase in phases do
		if phase.id == ClockView.NIGHT then
			night += phase.duration
		else
			day += phase.duration
		end
	end
	return day, night
end

-- Seconds until day turns to night (or night to day) at server time `time`, and whether it is night now.
function ClockView.untilChange(time: number, phases: { Phase }): (number, boolean)
	local cycle = 0
	for _, phase in phases do
		cycle += phase.duration
	end
	local inCycle = time % cycle
	local elapsed = 0
	for index, phase in phases do
		if inCycle < elapsed + phase.duration then
			local isNight = phase.id == ClockView.NIGHT
			local left = elapsed + phase.duration - inCycle
			-- Later phases of the same kind extend the wait; a phase of the other kind ends it.
			for step = 1, #phases do
				local following = phases[(index + step - 1) % #phases + 1]
				if (following.id == ClockView.NIGHT) ~= isNight then
					break
				end
				left += following.duration
			end
			return left, isNight
		end
		elapsed += phase.duration
	end
	return 0, false
end

-- "13:20" for a clock hour.
function ClockView.clockText(hour: number): string
	local minutes = math.floor((hour % 24) * 60)
	return string.format("%02d:%02d", minutes // 60, minutes % 60)
end

-- "m:ss" for a number of seconds, never negative.
function ClockView.mmss(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- The three lines of the card: the phase and the clock time, the next change, the day and night lengths. `time` is the server
-- time, `hour` DayCycle.clockAt of it, `phaseId` the Env phase, `t` the translation in the current language.
function ClockView.lines(
	time: number,
	hour: number,
	phaseId: string,
	phases: { Phase },
	t: Translate
): { time: string, change: string, lengths: string }
	local left, isNight = ClockView.untilChange(time, phases)
	local day, night = ClockView.lengths(phases)
	return {
		time = t("clock.time", { phase = t("phase." .. phaseId), time = ClockView.clockText(hour) }),
		change = t(if isNight then "clock.dayIn" else "clock.nightIn", { time = ClockView.mmss(left) }),
		lengths = t("clock.lengths", { day = ClockView.mmss(day), night = ClockView.mmss(night) }),
	}
end

return ClockView
