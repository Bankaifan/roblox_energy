--!strict
-- Tutorial v2 (design tutorial-v2.md): twelve steps, facts, soft steps, floor, skip.
return function(t, load)
	local Tutorial = load("Core/Tutorial")

	local function facts(changes: { [string]: any }): { [string]: any }
		local result = {
			shown = 0,
			cranks = 0,
			earned = 0,
			marketOpened = false,
			mown = 0,
			panels = 0,
			gear = false,
			shovel = false,
			dug = 0,
			wheels = 0,
			container = false,
			nodes = {},
			level = 0,
		}
		for key, value in changes do
			result[key] = value
		end
		return result
	end

	local ids = {
		"crank",
		"mow",
		"market",
		"panel",
		"gear",
		"shovel",
		"dig",
		"wheel",
		"container",
		"storage",
		"grow",
		"expand",
	}
	t.equal(Tutorial.COUNT, 12, "twelve steps")
	for index, id in ids do
		t.equal(Tutorial.id(index), id, `step {index} is {id}`)
		t.equal(Tutorial.next(index), if index < 12 then index + 1 else nil, `next of {id}`)
	end
	t.equal(Tutorial.current(Tutorial.start()), "crank", "a new tutorial starts at the crank")

	-- Each fact finishes exactly its step.
	local c = Tutorial.condition
	t.truthy(c("crank", facts({ cranks = 1 })) and not c("crank", facts({})), "a click finishes the crank step")
	t.truthy(c("crank", facts({ earned = 5 })), "earned coins finish it after a rejoin")
	t.truthy(c("mow", facts({ mown = 1 })) and not c("mow", facts({})), "one mown tile")
	t.truthy(c("market", facts({ marketOpened = true })) and c("market", facts({ panels = 1 })), "market or panel")
	t.truthy(c("panel", facts({ panels = 1 })) and not c("panel", facts({ marketOpened = true })), "a panel")
	t.truthy(c("gear", facts({ gear = true })), "U12")
	t.truthy(c("shovel", facts({ shovel = true })), "the shovel")
	t.truthy(c("dig", facts({ dug = 1 })), "one river cell dug")
	t.truthy(c("wheel", facts({ wheels = 1 })), "a wheel")
	t.truthy(c("container", facts({ container = true })), "the container")
	t.truthy(
		c("storage", facts({ nodes = { U17 = true } })) and not c("storage", facts({ nodes = { U18 = true } })),
		"U17"
	)
	t.truthy(not c("grow", facts({ level = 1, shown = 999 })), "grow never passes by a fact")
	t.truthy(c("expand", facts({ level = 1 })), "the expansion")

	-- Walk: a fresh run stays at the crank; everything true ends done in one call.
	t.equal(Tutorial.current(Tutorial.step(Tutorial.start(), facts({}))), "crank", "a fresh run stays at the crank")
	local all = facts({
		cranks = 1,
		mown = 1,
		panels = 1,
		gear = true,
		shovel = true,
		dug = 1,
		wheels = 1,
		container = true,
		nodes = { U17 = true },
		level = 1,
		shown = 20,
	})
	t.truthy(Tutorial.step(Tutorial.start(), all).done, "all facts true ends the tutorial in one call")

	-- Order: the shovel owned early does not skip the gear; after the gear the walk lands on dig, not shovel.
	local early = Tutorial.step({ index = 5, done = false }, facts({ cranks = 1, mown = 1, panels = 1, shovel = true }))
	t.equal(Tutorial.current(early), "gear", "the gear step waits")
	local later = Tutorial.step(early, facts({ cranks = 1, mown = 1, panels = 1, shovel = true, gear = true }))
	t.equal(Tutorial.current(later), "dig", "the shovel step is passed silently")

	-- Soft steps: gear at 90 s, not at 89; one call passes only one soft step.
	local function with(extra: { [string]: any }): { [string]: any }
		local merged: { [string]: any } = { cranks = 1, mown = 1, panels = 1 }
		for key, value in extra do
			merged[key] = value
		end
		return merged
	end
	t.equal(Tutorial.current(Tutorial.step({ index = 5, done = false }, facts(with({ shown = 89 })))), "gear", "89 s")
	t.equal(Tutorial.current(Tutorial.step({ index = 5, done = false }, facts(with({ shown = 90 })))), "shovel", "90 s")
	local soft = Tutorial.step(
		{ index = 5, done = false },
		facts(with({ shown = 500, shovel = true, dug = 1, wheels = 1, container = true, nodes = { U17 = true } }))
	)
	t.equal(Tutorial.current(soft), "grow", "only one soft step expires per call")

	-- Floor: the index never goes back; expand finishes; skip and clamping.
	t.equal(Tutorial.step({ index = 8, done = false }, facts({})).index, 8, "a fact turning false does not move back")
	t.truthy(Tutorial.step({ index = 12, done = false }, facts({ level = 1 })).done, "the expansion ends it")
	local skipped = Tutorial.skip(Tutorial.start())
	t.truthy(skipped.done and Tutorial.current(skipped) == nil, "skip is final")
	t.truthy(Tutorial.step(skipped, all).done, "a skipped tutorial stays done")
	t.equal(Tutorial.current({ index = 0 / 0, done = false }), "crank", "a NaN index starts at the crank")
	t.equal(Tutorial.current({ index = 99, done = false }), "expand", "a large index is the last step")

	-- Facts from a state, with and without land.
	local fromState = Tutorial.facts({
		lifetimeEarned = 10,
		level = 1,
		plants = { 2, 1 },
		nodes = { U12 = true, U17 = true },
		land = { sites = { 3, 2 }, tools = { shovel = true }, container = true },
	}, 30, 4, true)
	t.truthy(fromState.mown == 3 and fromState.dug == 2 and fromState.panels == 2 and fromState.wheels == 1, "counts")
	t.truthy(fromState.gear and fromState.shovel and fromState.container and fromState.level == 1, "owned things")
	t.truthy(fromState.cranks == 4 and fromState.shown == 30 and fromState.earned == 10, "session facts")
	local bare = Tutorial.facts({ nodes = {} }, 0, 0, false)
	t.truthy(bare.mown == 0 and not bare.shovel and bare.panels == 0, "a run without land has no land facts")
end
