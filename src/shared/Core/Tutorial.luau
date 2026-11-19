--!strict
-- Tutorial v2 (docs/design/tutorial-v2.md, issues #200 to #208): twelve steps from the first crank turn to the first grid
-- expansion. Pure functions: the caller passes the facts of the run, nothing is read from the game, the profile or Roblox.
-- The tutorial never shows a purchase hint (Core/Hints). Skipping or finishing it is final.
export type Step =
	"crank"
	| "mow"
	| "market"
	| "panel"
	| "gear"
	| "shovel"
	| "dig"
	| "wheel"
	| "container"
	| "storage"
	| "grow"
	| "expand"
export type Facts = {
	shown: number, -- seconds the current step has been current in this session
	cranks: number, -- crank clicks in this session
	earned: number, -- coins earned in this life (lifetimeEarned)
	marketOpened: boolean, -- the market popup was opened in this session
	mown: number, -- panel tiles mown (land.sites[1])
	panels: number, -- Balcony Panels owned
	gear: boolean, -- U12 Crank Gear is owned
	shovel: boolean, -- the shovel is owned
	dug: number, -- river cells dug (land.sites[2])
	wheels: number, -- Water Wheels owned
	container: boolean, -- the container is bought (land.container)
	nodes: { [string]: boolean }, -- run nodes owned; U17 is the Home Battery (the storage)
	level: number, -- grid level; 1 or more means the first expansion is done
}
-- index: the floor step (1 to #STEPS), done: the tutorial is finished or skipped. Saved as profile.tutorial and tutorialDone.
export type Progress = { index: number, done: boolean }

-- The steps in order. `soft` is the number of seconds after which a step passes by itself (nil = only by its fact).
local STEPS: { { id: Step, soft: number? } } = {
	{ id = "crank" },
	{ id = "mow" },
	{ id = "market" },
	{ id = "panel" },
	{ id = "gear", soft = 90 },
	{ id = "shovel" },
	{ id = "dig" },
	{ id = "wheel" },
	{ id = "container" },
	{ id = "storage" },
	{ id = "grow", soft = 20 },
	{ id = "expand" },
}

local Tutorial = {}
Tutorial.COUNT = #STEPS

-- The id of step `index`, or nil outside 1 to COUNT.
function Tutorial.id(index: number): Step?
	local step = STEPS[index]
	return if step ~= nil then step.id else nil
end

-- The fact each step waits for. `grow` never passes by a fact, only by its soft timer.
function Tutorial.condition(id: Step, facts: Facts): boolean
	if id == "crank" then
		return facts.cranks >= 1 or facts.earned > 0
	elseif id == "mow" then
		return facts.mown >= 1
	elseif id == "market" then
		return facts.marketOpened == true or facts.panels >= 1
	elseif id == "panel" then
		return facts.panels >= 1
	elseif id == "gear" then
		return facts.gear == true
	elseif id == "shovel" then
		return facts.shovel == true
	elseif id == "dig" then
		return facts.dug >= 1
	elseif id == "wheel" then
		return facts.wheels >= 1
	elseif id == "container" then
		return facts.container == true
	elseif id == "storage" then
		return facts.nodes.U17 == true
	elseif id == "expand" then
		return facts.level >= 1
	end
	return false
end

-- The facts of a run from its state, plus what only the server session knows: the seconds the step has been shown, the crank
-- clicks and whether the market popup was opened.
function Tutorial.facts(state: any, shown: number, cranks: number, marketOpened: boolean): Facts
	local land = state.land
	local sites = if land ~= nil and land.sites ~= nil then land.sites else {}
	local plants = state.plants or {}
	local nodes = state.nodes or {}
	return {
		shown = shown,
		cranks = cranks,
		earned = state.lifetimeEarned or 0,
		marketOpened = marketOpened,
		mown = sites[1] or 0,
		panels = plants[1] or 0,
		gear = nodes.U12 == true,
		shovel = land ~= nil and land.tools ~= nil and land.tools.shovel == true,
		dug = sites[2] or 0,
		wheels = plants[2] or 0,
		container = land ~= nil and land.container == true,
		nodes = nodes,
		level = state.level or 0,
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

-- Walks forward from the saved floor while the step's fact holds, or while it is a soft step shown long enough. A soft pass
-- uses up `shown`, so two soft steps never expire in one call. Steps done early are passed silently; the index never goes
-- back. Passing the last step makes the tutorial done. A done tutorial stays as it is.
function Tutorial.step(progress: Progress, facts: Facts): Progress
	if progress.done then
		return { index = progress.index, done = true }
	end
	local index = clampIndex(progress.index)
	local shown = facts.shown
	while true do
		local step = STEPS[index]
		local passes = Tutorial.condition(step.id, facts)
		if not passes and step.soft ~= nil and shown >= step.soft then
			passes = true
			shown = 0
		end
		if not passes then
			break
		end
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
