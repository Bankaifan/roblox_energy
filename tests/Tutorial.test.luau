--!strict
-- Tutorial (Bauplan.md, section 1; issues #71, #117): the steps in order, skipping and the end at the storage.
return function(t, load)
	local Tutorial = load("Core/Tutorial")

	-- Facts of a run: nothing done yet, unless `changes` names it.
	local function facts(changes: { [string]: any }): { [string]: any }
		local result = {
			seconds = 0,
			cranks = 0,
			marketOpened = false,
			mown = 0,
			shovel = false,
			container = false,
			nodes = {},
		}
		for key, value in changes do
			result[key] = value
		end
		return result
	end

	-- The steps in order, with the next step after each.
	t.equal(Tutorial.COUNT, 6, "six steps: crank, market, mowing, shovel, container, storage")
	t.equal(Tutorial.current(Tutorial.start()), "crank", "a new tutorial starts at the crank")
	t.equal(Tutorial.next(1), 2, "the crank is followed by the market")
	t.equal(Tutorial.next(2), 3, "the market is followed by mowing")
	t.equal(Tutorial.next(3), 4, "mowing is followed by the shovel")
	t.equal(Tutorial.next(4), 5, "the shovel is followed by the container")
	t.equal(Tutorial.next(5), 6, "the container is followed by the storage")
	t.equal(Tutorial.next(6), nil, "the storage is the last step")

	-- Each condition: the fact of its step only.
	t.equal(Tutorial.condition("crank", facts({ cranks = 0 })), false, "no crank click, no crank step")
	t.equal(Tutorial.condition("crank", facts({ cranks = 1 })), true, "a crank click finishes the crank step")
	t.equal(Tutorial.condition("market", facts({ marketOpened = true })), true, "the opened market finishes its step")
	t.equal(Tutorial.condition("market", facts({ mown = 1 })), false, "a mown tile is not an opened market")
	t.equal(Tutorial.condition("mowing", facts({ mown = 1 })), true, "one mown tile finishes mowing")
	t.equal(Tutorial.condition("mowing", facts({ mown = 0 })), false, "no mown tile, no mowing step")
	t.equal(Tutorial.condition("shovel", facts({ shovel = true })), true, "the shovel finishes its step")
	t.equal(Tutorial.condition("shovel", facts({ container = true })), false, "a container is not a shovel")
	t.equal(Tutorial.condition("container", facts({ container = true })), true, "the container finishes its step")
	t.equal(Tutorial.condition("storage", facts({ nodes = { U17 = true } })), true, "U17 is the storage")
	t.equal(Tutorial.condition("storage", facts({ nodes = { U18 = true } })), false, "U18 alone is not the storage")

	-- The steps advance one at a time, each when its condition holds.
	local progress = Tutorial.start()
	progress = Tutorial.step(progress, facts({ seconds = 3 }))
	t.equal(Tutorial.current(progress), "crank", "no click, the crank step stays")
	progress = Tutorial.step(progress, facts({ cranks = 1 }))
	t.equal(Tutorial.current(progress), "market", "a click moves on to the market step")
	progress = Tutorial.step(progress, facts({ cranks = 1, marketOpened = true }))
	t.equal(Tutorial.current(progress), "mowing", "the opened market moves on to mowing")
	progress = Tutorial.step(progress, facts({ cranks = 1, marketOpened = true, mown = 1 }))
	t.equal(Tutorial.current(progress), "shovel", "a mown tile moves on to the shovel")
	progress = Tutorial.step(progress, facts({ cranks = 1, marketOpened = true, mown = 1, shovel = true }))
	t.equal(Tutorial.current(progress), "container", "the shovel moves on to the container")
	t.equal(progress.done, false, "the tutorial is not done before the storage")
	local owned = { cranks = 1, marketOpened = true, mown = 1, shovel = true, container = true }
	progress = Tutorial.step(progress, facts(owned))
	t.equal(Tutorial.current(progress), "storage", "the container moves on to the storage")
	t.equal(progress.done, false, "no storage, not done")

	-- The storage ends the tutorial; a done tutorial has no current step and never comes back.
	owned.nodes = { U17 = true }
	progress = Tutorial.step(progress, facts(owned))
	t.equal(progress.done, true, "the storage ends the tutorial")
	t.equal(Tutorial.current(progress), nil, "a done tutorial has no step")
	local again = Tutorial.step(progress, facts({ seconds = 0 }))
	t.equal(again.done, true, "a done tutorial stays done")
	t.equal(again.index, 6, "and keeps its step")

	-- One call walks through every step whose condition holds, in order.
	local at = Tutorial.step(Tutorial.start(), facts(owned))
	t.equal(at.done, true, "a run with every step done is done in one call")

	-- Order matters: a storage bought before the crank does not skip the steps before it.
	local early = Tutorial.step(Tutorial.start(), facts({ seconds = 60, nodes = { U17 = true }, container = true }))
	t.equal(Tutorial.current(early), "crank", "the storage does not skip the crank step")
	t.equal(early.done, false, "not done before the crank")
	local gap = Tutorial.step(Tutorial.start(), facts({ cranks = 1, mown = 1, shovel = true, container = true }))
	t.equal(Tutorial.current(gap), "market", "mowing before the market does not skip the market")

	-- Skipping: done at once, for good.
	local skipped = Tutorial.skip(Tutorial.start())
	t.equal(skipped.done, true, "skipping ends the tutorial")
	t.equal(Tutorial.current(skipped), nil, "a skipped tutorial has no step")
	t.equal(Tutorial.step(skipped, facts({ seconds = 60, cranks = 1 })).done, true, "a skipped tutorial stays skipped")

	-- A saved index outside the steps is clamped: a broken value starts at the crank, a large one at the storage.
	t.equal(Tutorial.current({ index = 0, done = false }), "crank", "an index below 1 starts at the crank")
	t.equal(Tutorial.current({ index = 0 / 0, done = false }), "crank", "a NaN index starts at the crank")
	t.equal(Tutorial.current({ index = 9, done = false }), "storage", "an index past the end is the storage")
	t.equal(Tutorial.current({ index = 3.7, done = false }), "mowing", "a fractional index is rounded down")
	local clamped = Tutorial.step({ index = 9, done = false }, facts({ nodes = { U17 = true } }))
	t.equal(clamped.done, true, "a clamped storage step can finish the tutorial")

	-- Facts from a run state.
	local fromState = Tutorial.facts({
		nodes = { U17 = true },
		land = { sites = { 2 }, tools = { shovel = true }, container = true },
	}, 30, 4, true)
	t.equal(fromState.mown, 2, "mown tiles are the prepared panel tiles")
	t.truthy(
		fromState.shovel and fromState.container and fromState.marketOpened and fromState.nodes.U17,
		"owned things are facts"
	)
	t.equal(fromState.cranks, 4, "cranks come from the session")
	local bare = Tutorial.facts({ nodes = {} }, 0, 0, false)
	t.truthy(bare.mown == 0 and not bare.shovel and not bare.container, "a run without land has no land facts")
end
