--!strict
-- Day clock (issue 288, step 2): the dial turns with DayCycle.clockAt, the lengths and the countdown come from Config/Phases,
-- every weather id has a chip colour, and the clock texts exist in both languages with the same placeholders.
return function(t, load)
	local ClockView = load("Core/ClockView")
	local DayCycle = load("Core/DayCycle")
	local Phases = load("Config/Phases")
	local Weather = load("Config/Weather")
	local Locale = load("Config/Locale")

	-- A stand-in for Locale.t that names the key and its arguments, in a fixed order.
	local function key(text: string, args: { [string]: any }?): string
		local names = {}
		for name in args or {} do
			table.insert(names, name)
		end
		table.sort(names)
		local out = text
		for _, name in names do
			out ..= `|{name}={(args :: any)[name]}`
		end
		return out
	end

	-- Dial: noon under the pointer is 0 degrees, midnight 180 degrees.
	t.eq(ClockView.angle(12), 0, "noon")
	t.eq(ClockView.angle(0), 180, "midnight")
	t.eq(ClockView.angle(18), 270, "18 h")
	t.eq(ClockView.angle(6), 90, "6 h")
	-- The angle follows DayCycle.clockAt: 100 s into the day is the start of Mittag, 9 h, 45 degrees.
	t.eq(ClockView.angle(DayCycle.clockAt(100, Phases)), 45, "start of Mittag")

	-- 24 segments; night runs from the Nacht hour to the Morgen hour of DayCycle (a segment counts by its middle).
	local segments = ClockView.segments(DayCycle.HOURS)
	t.eq(#segments, 24, "24 segments")
	t.eq(segments[1].night, true, "0 h is night")
	t.eq(segments[5].night, true, "4 h is night")
	t.eq(segments[6].night, false, "5 h: its middle 5.5 is day")
	t.eq(segments[13].night, false, "12 h is day")
	t.eq(segments[20].night, false, "19 h is day")
	t.eq(segments[21].night, true, "20 h is night")
	t.eq(segments[13].angle, 7.5, "angle of the middle of the 12 h segment")

	-- Lengths are sums of Config/Phases: 560 s of day and 160 s of night today.
	local day, night = ClockView.lengths(Phases)
	t.eq(day, 560, "day length")
	t.eq(night, 160, "night length")
	local changed = table.clone(Phases)
	changed[2] = { id = "Mittag", duration = 400 }
	local day2, night2 = ClockView.lengths(changed)
	t.eq(day2, 660, "day length follows Phases")
	t.eq(night2, 160, "night unchanged")

	-- Countdown to the next change of day and night.
	local seconds, isNight = ClockView.untilChange(0, Phases)
	t.eq(seconds, 560, "from the start of Morgen to night")
	t.eq(isNight, false, "morning is day")
	seconds, isNight = ClockView.untilChange(570, Phases)
	t.eq(seconds, 150, "10 s into the night")
	t.eq(isNight, true, "night")
	seconds = ClockView.untilChange(720 + 559, Phases)
	t.eq(seconds, 1, "one second before night, next day")

	t.eq(ClockView.clockText(13.5), "13:30", "clock text")
	t.eq(ClockView.clockText(5.99), "05:59", "clock text pads")
	t.eq(ClockView.mmss(250), "4:10", "m:ss")
	t.eq(ClockView.mmss(-3), "0:00", "never negative")

	-- The three lines use the phase name and the keys of the Locale.
	local lines = ClockView.lines(0, 6, "Morgen", Phases, key)
	t.eq(lines.time, key("clock.time", { phase = key("phase.Morgen"), time = "06:00" }), "time line")
	t.eq(lines.change, key("clock.nightIn", { time = "9:20" }), "night in")
	t.eq(lines.lengths, key("clock.lengths", { day = "9:20", night = "2:40" }), "lengths line")
	local nightLines = ClockView.lines(600, 21, "Nacht", Phases, key)
	t.eq(nightLines.change, key("clock.dayIn", { time = "2:00" }), "day in")

	-- Every weather has a chip colour of three bytes.
	for _, weather in Weather do
		local color = ClockView.chip(weather.id)
		t.truthy(color ~= nil and #color == 3, `{weather.id}: chip colour`)
	end
	t.eq(ClockView.chip("Nebel"), nil, "unknown weather has no chip")

	-- Texts: every clock.* key in both languages with the same placeholders.
	local function placeholders(text: string): string
		local names = {}
		for name in string.gmatch(text, "{(%w+)}") do
			table.insert(names, name)
		end
		table.sort(names)
		return table.concat(names, ",")
	end
	for _, name in { "time", "nightIn", "dayIn", "lengths" } do
		local en, de = Locale.tables.en["clock." .. name], Locale.tables.de["clock." .. name]
		t.truthy(en ~= nil and de ~= nil, `clock.{name}: both languages`)
		if en ~= nil and de ~= nil then
			t.eq(placeholders(en), placeholders(de), `clock.{name}: same placeholders`)
		end
	end
end
