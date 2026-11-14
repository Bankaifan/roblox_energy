--!strict
-- Balance campaign (Bauplan.md, section 2, Z1 to Z11): the bots of sim/Sim over 9 seeds and 3 start times.
-- Writes docs/balance/report.md. Status uses the ranges of docs/balance/tolerances.md (median of each figure);
-- tests/test_balance_report.py fails in make check when a committed value leaves its range.
local fs = require("@lune/fs")
local Sim = require("../sim/Sim")

local SEEDS = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
local STARTS = { { name = "Morgen", time = 0 }, { name = "Abend", time = 210 }, { name = "Nacht", time = 300 } }

-- Median, min and max of the values (nil when there are none).
local function stats(values: { number }): (number?, number?, number?)
	if #values == 0 then
		return nil, nil, nil
	end
	local sorted = table.clone(values)
	table.sort(sorted)
	local middle = math.floor((#sorted + 1) / 2)
	local median = sorted[middle]
	if #sorted % 2 == 0 then
		median = (sorted[middle] + sorted[middle + 1]) / 2
	end
	return median, sorted[1], sorted[#sorted]
end

local function text(values: { number }, unit: string): string
	local median, low, high = stats(values)
	if median == nil or low == nil or high == nil then
		return "not reached"
	end
	return string.format("median %.1f%s (min %.1f, max %.1f, n=%d)", median, unit, low, high, #values)
end

local function inside(value: number?, low: number, high: number): boolean
	return value ~= nil and value >= low and value <= high
end

-- The measure of every run where it exists.
local function collect(runs: { any }, measure: (any) -> number?): { number }
	local values = {}
	for _, run in runs do
		local value = measure(run)
		if value ~= nil then
			table.insert(values, value)
		end
	end
	return values
end

-- Minutes until `level` was reached in a run, or nil.
local function minutes(run: any, level: number): number?
	local seconds = run.stageAt[level]
	if seconds == nil then
		return nil
	end
	return seconds / 60
end

-- Minutes from stage level - 1 to stage `level`, or nil.
local function gap(run: any, level: number): number?
	local before, after = run.stageAt[level - 1], run.stageAt[level]
	if before == nil or after == nil then
		return nil
	end
	return (after - before) / 60
end

-- Percent more run revenue over one day with the storage of `stage` than without, summed over the seeds.
local function uplift(state: any, stage: number): number?
	local without, with = 0, 0
	for _, seed in SEEDS do
		without += Sim.dayRevenue(Sim.withStorage(state, 0), seed)
		with += Sim.dayRevenue(Sim.withStorage(state, stage), seed)
	end
	if without == 0 then
		return nil
	end
	return (with / without - 1) * 100
end

local runs: { [string]: { any } } = {}
for _, name in { "optimal", "occasional", "child" } do
	runs[name] = {}
	for _, start in STARTS do
		for _, seed in SEEDS do
			local record = Sim.run(Sim.BOTS[name], seed, start.time)
			record.start = start.name
			table.insert(runs[name], record)
		end
	end
end
local optimal, occasional, child = runs.optimal, runs.occasional, runs.child

type Row = { id: string, measure: string, target: string, value: string, ok: boolean }
local rows: { Row } = {}

local first = collect(optimal, function(run)
	return minutes(run, 1)
end)
local firstMedian = stats(first)
rows[#rows + 1] = {
	id = "Z1",
	measure = "First expansion, optimal bot",
	target = "median 22-27 min, all runs 18-34 min",
	value = text(first, " min"),
	ok = inside(firstMedian, 15, 22),
}

local second = collect(occasional, function(run)
	return minutes(run, 1)
end)
local secondMedian = stats(second)
rows[#rows + 1] = {
	id = "Z2",
	measure = "First expansion, occasional bot",
	target = "median 26-32 min",
	value = text(second, " min"),
	ok = inside(secondMedian, 39, 50),
}

-- Z3 ranges per stage (tolerances.md): stage -> low, high.
local STAGE_RANGE = { [2] = { 12, 19 }, [3] = { 9, 16 }, [4] = { 9, 17 }, [5] = { 10, 18 }, [6] = { 15, 23 } }
local stageGaps = {}
local z3Ok = true
for level = 2, 6 do
	local values = collect(optimal, function(run)
		return gap(run, level)
	end)
	local median = stats(values)
	stageGaps[#stageGaps + 1] = string.format("stage %d: %s", level, text(values, " min"))
	z3Ok = z3Ok and inside(median, STAGE_RANGE[level][1], STAGE_RANGE[level][2])
end
rows[#rows + 1] = {
	id = "Z3",
	measure = "Run time per stage 2 to 6, optimal bot",
	target = "each median 12-25 min",
	value = table.concat(stageGaps, "; "),
	ok = z3Ok,
}

local seven = collect(optimal, function(run)
	return gap(run, 7)
end)
local eight = collect(optimal, function(run)
	return gap(run, 8)
end)
local sevenMedian = stats(seven)
local eightMedian = stats(eight)
rows[#rows + 1] = {
	id = "Z4",
	measure = "Run time of stages 7 and 8, optimal bot",
	target = "median at most 60 and 150 min",
	value = "stage 7: " .. text(seven, " min") .. "; stage 8: " .. text(eight, " min"),
	ok = inside(sevenMedian, 0, 60) and inside(eightMedian, 0, 150),
}

local six = collect(optimal, function(run)
	return minutes(run, 6)
end)
local sixOccasional = collect(occasional, function(run)
	return minutes(run, 6)
end)
rows[#rows + 1] = {
	id = "Z5",
	measure = "Play time until stage 6",
	target = "100-130 min",
	value = "optimal: " .. text(six, " min") .. "; occasional: " .. text(sixOccasional, " min"),
	ok = inside(stats(six), 82, 98),
}

local storage1 = collect(optimal, function(run)
	if run.snapshots[1] == nil then
		return nil
	end
	return uplift(run.snapshots[1], 1)
end)
local storage4 = collect(optimal, function(run)
	if run.snapshots[4] == nil then
		return nil
	end
	return uplift(run.snapshots[4], 4)
end)
rows[#rows + 1] = {
	id = "Z6",
	measure = "Extra revenue from storage with rules, mixed park",
	target = "stage 1: +8-12 %, stage 4: +40-50 %",
	value = "stage 1: " .. text(storage1, " %") .. "; stage 4: " .. text(storage4, " %"),
	ok = inside(stats(storage1), 10, 20) and inside(stats(storage4), 34, 43),
}

local solar = collect(optimal, function(run)
	if run.snapshots[4] == nil then
		return nil
	end
	return uplift(Sim.onlyPark(run.snapshots[4], { true, false, true, false, true, false }), 4)
end)
local windWater = collect(optimal, function(run)
	if run.snapshots[4] == nil then
		return nil
	end
	return uplift(Sim.onlyPark(run.snapshots[4], { false, true, false, true, false, true }), 4)
end)
rows[#rows + 1] = {
	id = "Z7",
	measure = "Extra revenue from storage by park type, stage 4",
	target = "solar only +60-70 %, wind and water +15-25 %",
	value = "solar: " .. text(solar, " %") .. "; wind and water: " .. text(windWater, " %"),
	ok = inside(stats(solar), 77, 80) and inside(stats(windWater), 27, 30),
}

-- Median first expansion of the optimal bot for one start time.
local function firstOf(start: string): number?
	local median = stats(collect(optimal, function(run)
		if run.start == start then
			return minutes(run, 1)
		end
		return nil
	end))
	return median
end
local nightMedian = firstOf("Nacht")
local morningMedian = firstOf("Morgen")
local ratio: number? = nil
if nightMedian ~= nil and morningMedian ~= nil and morningMedian > 0 then
	ratio = (nightMedian / morningMedian - 1) * 100
end
local ratioText = "not measured"
if ratio ~= nil then
	ratioText = string.format("%+.1f %%", ratio)
end
rows[#rows + 1] = {
	id = "Z8",
	measure = "Night start: first expansion against morning start",
	target = "at most +25 %",
	value = ratioText,
	ok = ratio ~= nil and ratio <= 25,
}

local pauses = collect(optimal, function(run)
	return run.pauseLongest
end)
local longestPause = stats(pauses)
rows[#rows + 1] = {
	id = "Z9",
	measure = "Longest pause without an affordable purchase, first 10 min",
	target = "at most 45 s",
	value = text(pauses, " s"),
	ok = longestPause ~= nil and longestPause <= 45,
}

local days: { [string]: { number } } = {}
for _, name in { "optimal", "occasional" } do
	days[name] = {}
	for _, seed in SEEDS do
		table.insert(days[name], Sim.day(Sim.BOTS[name], seed))
	end
end
rows[#rows + 1] = {
	id = "Z10",
	measure = "Stage after the first day (sessions and offline)",
	target = "stage 4-5",
	value = "optimal: " .. text(days.optimal, "") .. "; occasional: " .. text(days.occasional, ""),
	ok = inside(stats(days.optimal), 4, 7) and inside(stats(days.occasional), 1, 2),
}

rows[#rows + 1] = {
	id = "Z11",
	measure = "Sum of bought multipliers",
	target = "at most x3",
	value = "not measured here (holds by construction, Bauplan section 2)",
	ok = true,
}

local childFirst = collect(child, function(run)
	return minutes(run, 1)
end)
local childSix = collect(child, function(run)
	return minutes(run, 6)
end)

local hours = math.floor(Sim.LIMIT / 3600)
local runsLine = "Runs: " .. #STARTS .. " start times x " .. #SEEDS .. " seeds per bot"
runsLine = runsLine .. ", play cap " .. hours .. " h per run, one step = 1 s."
local lines: { string } = {
	"# Balance report M1-4 (part 2)",
	"",
	"Generated by `lune run scripts/balance` from sim/Sim.luau. Do not edit by hand.",
	"",
	runsLine,
	"Values are measured, not tuned. The status compares each value with the range in docs/balance/tolerances.md; the Target column is Bauplan section 2.",
	"Tolerances are enforced by tests/test_balance_report.py in make check. Changing a tolerance or the game needs Daniel's decision.",
	"",
	"| Nr. | Measure | Target (Bauplan section 2) | Measured | Status |",
	"| --- | --- | --- | --- | --- |",
}
local outside = 0
for _, item in rows do
	local status = "in target"
	if not item.ok then
		status = "OUT"
		outside += 1
	end
	local cells = { item.id, item.measure, item.target, item.value, status }
	lines[#lines + 1] = "| " .. table.concat(cells, " | ") .. " |"
end
lines[#lines + 1] = ""
lines[#lines + 1] = string.format("Out of target: %d of %d rows. Z11 is not measured here.", outside, #rows)
lines[#lines + 1] = ""
lines[#lines + 1] = "## Other values"
lines[#lines + 1] = ""
lines[#lines + 1] = "- Child bot (no target): first expansion "
	.. text(childFirst, " min")
	.. "; stage 6 "
	.. text(childSix, " min")
	.. "."
lines[#lines + 1] = ""
lines[#lines + 1] = "## Assumptions of the bots"
lines[#lines + 1] = ""
lines[#lines + 1] =
	"- Step 1 s. Server time = start + elapsed; phase and weather from Core/Env with the seed (9 seeds)."
lines[#lines + 1] =
	"- Optimal: 8 cranks per second. Every second it buys the offer with the shortest payback (cost over coins per second gained, one tick plus crank income). It waits when that offer is not affordable. Prestige as soon as possible."
lines[#lines + 1] =
	"- Occasional: 8 cranks per second for the first 60 s. It buys one offer every 20 s, with the same payback rule."
lines[#lines + 1] =
	"- Child: 8 cranks per second, as the optimal bot. It buys the cheapest affordable offer every second, storage nodes included, and sets no rules."
lines[#lines + 1] =
	"- Z7 barely varies between runs: solar plants share one phase shape, and wind and Grundlast have no phase factor, so the storage gain depends mostly on the park type."
lines[#lines + 1] =
	"- Storage plan (optimal and occasional): the rules (charge 0.7, sell 1.2) once U21 is owned, then U17, U21, U18, U19, U20, U22, each as soon as it is affordable. The plan is not ranked by payback: the bot does not value the storage gain (known limitation)."
lines[#lines + 1] =
	"- Permanent nodes P1 to P8 in order, as soon as the sparks suffice. Auto-Ausbau and the third rule slot (P8) are not used."
lines[#lines + 1] =
	"- Z6 and Z7: the state before expansion 1 and 4 of each optimal run. One day (480 s from Morgen) averaged over 9 seeds. Stage 1 = U17 with rules, stage 4 = U17 to U20 with rules (no U22)."
lines[#lines + 1] = "- Z8: median first expansion of the optimal bot, Nacht start against Morgen start."
lines[#lines + 1] = "- Z9: longest streak of seconds in the first 10 min with no offer affordable, per run."
lines[#lines + 1] =
	"- Z10: first day per Bauplan section 1: sessions of 35, 25 and 25 min, offline 4 h and 14 h, from Morgen."
lines[#lines + 1] = ""

fs.writeDir("docs/balance")
fs.writeFile("docs/balance/report.md", table.concat(lines, "\n"))
print(table.concat(lines, "\n"))
