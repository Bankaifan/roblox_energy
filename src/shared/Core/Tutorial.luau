--!strict
-- Tutorial (Bauplan.md, section 1, "Die ersten 10 Minuten"; issues #71, #117): crank, market, mowing, shovel, container, storage.
-- Pure functions: the caller passes the facts of the run in `facts`, nothing is read from the game, the profile or Roblox.
-- The tutorial never shows a purchase hint (Core/Hints). Skipping or finishing it is final.
export type Step = "crank" | "market" | "mowing" | "shovel" | "container" | "storage"
export type Facts = {
	seconds: number, -- seconds since the tutorial started
	cranks: number, -- crank clicks in this run
	marketOpened: boolean, -- the market popup was opened once
	mown: number, -- tiles mown so far (land.cells, design 0018 section 8)
	shovel: boolean, -- the shovel is owned
	container: boolean, -- the container is bought (land.container)
	nodes: { [string]: boolean }, -- run nodes owned; U17 is the Home Battery (the storage)
}
-- index: the current step (1 to #STEPS), done: the tutorial is finished or skipped. Saved as profile.tutorial and tutorialDone.
export type Progress = { index: number, done: boolean }

-- The steps in order. `from` is the earliest second a step can be left (the timeline of Bauplan section 1).
local STEPS: { { id: Step, from: number } } = {
	{ id = "crank", from = 0 }, -- an arrow points to the crank
	{ id = "market", from = 0 }, -- an arrow points to the market; its popup is opened once
	{ id = "mowing", from = 0 }, -- one tile is mown
	{ id = "shovel", from = 0 }, -- the shovel is owned
	{ id = "container", from = 0 }, -- the container is bought
	{ id = "storage", from = 0 }, -- the storage (U17) ends the tutorial
}

local Tutorial = {}
Tutorial.COUNT = #STEPS

-- The fact each step waits for.
function Tutorial.condition(id: Step, facts: Facts): boolean
	if id == "crank" then
		return facts.cranks >= 1
	elseif id == "market" then
		return facts.marketOpened == true
	elseif id == "mowing" then
		return facts.mown >= 1
	elseif id == "shovel" then
		return facts.shovel == true
	elseif id == "container" then
		return facts.container == true
	elseif id == "storage" then
		return facts.nodes.U17 == true
	end
	return false
end

-- The facts of a run from its state, plus what only the server session knows: the seconds since the tutorial started, the
-- crank clicks and whether the market popup was opened.
function Tutorial.facts(state: any, seconds: number, cranks: number, marketOpened: boolean): Facts
	local land = state.land
	local sites = if land ~= nil and land.sites ~= nil then land.sites[1] or 0 else 0
	return {
		seconds = seconds,
		cranks = cranks,
		marketOpened = marketOpened,
		mown = sites,
		shovel = land ~= nil and land.tools ~= nil and land.tools.shovel == true,
		container = land ~= nil and land.container == true,
		nodes = state.nodes or {},
	}
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
