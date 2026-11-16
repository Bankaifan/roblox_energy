--!strict
-- Tutorial (Bauplan.md, section 1, "Die ersten 10 Minuten"; issue #71): the opening steps in order, up to the storage.
-- Pure functions: the caller passes the facts of the run in `facts`, nothing is read from the game, the profile or Roblox.
-- The tutorial never shows a purchase hint (Core/Hints). Skipping or finishing it is final.
export type Step = "crank" | "panel" | "wheel" | "storage"
export type Facts = {
	seconds: number, -- seconds since the tutorial started
	cranks: number, -- crank clicks in this run
	plants: { [number]: number }, -- plant counts by id (Config/Plants): 1 Balcony Panel, 2 Water Wheel
	nodes: { [string]: boolean }, -- run nodes owned; U17 is the Home Battery (the storage)
}
-- index: the current step (1 to #STEPS), done: the tutorial is finished or skipped. Saved as profile.tutorial and tutorialDone.
export type Progress = { index: number, done: boolean }

-- The steps in order. `from` is the earliest second a step can be left (the timeline of Bauplan section 1).
local STEPS: { { id: Step, from: number } } = {
	{ id = "crank", from = 0 }, -- an arrow points to the crank
	{ id = "panel", from = 5 }, -- the first Balcony Panel after about 5 s
	{ id = "wheel", from = 60 }, -- the first Water Wheel after a minute
	{ id = "storage", from = 0 }, -- the storage (U17) ends the tutorial
}

local Tutorial = {}
Tutorial.COUNT = #STEPS

-- The fact each step waits for.
function Tutorial.condition(id: Step, facts: Facts): boolean
	if id == "crank" then
		return facts.cranks >= 1
	elseif id == "panel" then
		return (facts.plants[1] or 0) >= 1
	elseif id == "wheel" then
		return (facts.plants[2] or 0) >= 1
	elseif id == "storage" then
		return facts.nodes.U17 == true
	end
	return false
end

-- The index after `index`, or nil after the last step.
function Tutorial.next(index: number): number?
	if index < Tutorial.COUNT then
		return index + 1
	end
	return nil
end

-- The step a player starts or resumes at. A saved index outside 1 to COUNT is clamped; a broken number starts at 1.
local function clampIndex(value: number): number
	if value ~= value or value < 1 then
		return 1
	end
	return math.min(math.floor(value), Tutorial.COUNT)
end

-- A new tutorial: the first step, not done.
function Tutorial.start(): Progress
	return { index = 1, done = false }
end

-- The id of the current step, or nil when the tutorial is done.
function Tutorial.current(progress: Progress): Step?
	if progress.done then
		return nil
	end
	return STEPS[clampIndex(progress.index)].id
end

-- Moves on while the current step is due (seconds from its `from` on) and its condition holds. Finishing the last step
-- makes the tutorial done. A done tutorial stays as it is.
function Tutorial.step(progress: Progress, facts: Facts): Progress
	if progress.done then
		return { index = progress.index, done = true }
	end
	local index = clampIndex(progress.index)
	while facts.seconds >= STEPS[index].from and Tutorial.condition(STEPS[index].id, facts) do
		local following = Tutorial.next(index)
		if following == nil then
			return { index = index, done = true }
		end
		index = following
	end
	return { index = index, done = false }
end

-- The player skips the tutorial: done, for good.
function Tutorial.skip(_progress: Progress): Progress
	return { index = Tutorial.COUNT, done = true }
end

return Tutorial
