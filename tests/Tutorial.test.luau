--!strict
-- Tutorial (Bauplan.md, section 1; issue #71): the steps in order, their timing, skipping and the end at the storage.
return function(t, load)
	local Tutorial = load("Core/Tutorial")

	-- Facts of a run: nothing done yet, unless `changes` names it.
	local function facts(changes: { [string]: any }): { [string]: any }
		local result = { seconds = 0, cranks = 0, plants = { 0, 0 }, nodes = {} }
		for key, value in changes do
			result[key] = value
		end
		return result
	end

	-- The steps in order, with the next step after each.
	t.equal(Tutorial.COUNT, 4, "four steps: crank, panel, wheel, storage")
	t.equal(Tutorial.current(Tutorial.start()), "crank", "a new tutorial starts at the crank")
	t.equal(Tutorial.next(1), 2, "the crank is followed by the panel")
	t.equal(Tutorial.next(3), 4, "the wheel is followed by the storage")
	t.equal(Tutorial.next(4), nil, "the storage is the last step")

	-- Each condition: the fact of its step only.
	t.equal(Tutorial.condition("crank", facts({ cranks = 0 })), false, "no crank click, no crank step")
	t.equal(Tutorial.condition("crank", facts({ cranks = 1 })), true, "a crank click finishes the crank step")
	t.equal(Tutorial.condition("panel", facts({ plants = { 1, 0 } })), true, "a Balcony Panel finishes the panel step")
	t.equal(Tutorial.condition("panel", facts({ plants = { 0, 1 } })), false, "a water wheel is not a panel")
	t.equal(Tutorial.condition("wheel", facts({ plants = { 0, 1 } })), true, "a water wheel finishes the wheel step")
	t.equal(Tutorial.condition("storage", facts({ nodes = { U17 = true } })), true, "U17 is the storage")
	t.equal(Tutorial.condition("storage", facts({ nodes = { U18 = true } })), false, "U18 alone is not the storage")

	-- The steps advance one at a time, each when its condition holds.
	local progress = Tutorial.start()
	progress = Tutorial.step(progress, facts({ seconds = 3 }))
	t.equal(Tutorial.current(progress), "crank", "no click, the crank step stays")
	progress = Tutorial.step(progress, facts({ seconds = 3, cranks = 1 }))
	t.equal(Tutorial.current(progress), "panel", "a click at 3 s moves on to the panel step")
	progress = Tutorial.step(progress, facts({ seconds = 4, cranks = 1, plants = { 1, 0 } }))
	t.equal(Tutorial.current(progress), "panel", "the panel is bought before 5 s, the step waits for 5 s")
	progress = Tutorial.step(progress, facts({ seconds = 5, cranks = 1, plants = { 1, 0 } }))
	t.equal(Tutorial.current(progress), "wheel", "the panel bought at 5 s moves on to the wheel step")
	progress = Tutorial.step(progress, facts({ seconds = 59, cranks = 1, plants = { 1, 1 } }))
	t.equal(Tutorial.current(progress), "wheel", "the wheel bought before a minute waits for a minute")
	progress = Tutorial.step(progress, facts({ seconds = 60, cranks = 1, plants = { 1, 1 } }))
	t.equal(Tutorial.current(progress), "storage", "the wheel at a minute moves on to the storage")
	t.equal(progress.done, false, "the tutorial is not done before the storage")
	progress = Tutorial.step(progress, facts({ seconds = 90, cranks = 1, plants = { 1, 1 } }))
	t.equal(progress.done, false, "no storage, not done")

	-- The storage ends the tutorial; a done tutorial has no current step and never comes back.
	progress = Tutorial.step(progress, facts({ seconds = 90, cranks = 1, plants = { 1, 1 }, nodes = { U17 = true } }))
	t.equal(progress.done, true, "the storage ends the tutorial")
	t.equal(Tutorial.current(progress), nil, "a done tutorial has no step")
	local again = Tutorial.step(progress, facts({ seconds = 0 }))
	t.equal(again.done, true, "a done tutorial stays done")
	t.equal(again.index, 4, "and keeps its step")

	-- One call walks through every step whose condition holds, in order.
	local everything = facts({ seconds = 60, cranks = 1, plants = { 1, 1 }, nodes = { U17 = true } })
	local at = Tutorial.step(Tutorial.start(), everything)
	t.equal(at.done, true, "a run with every step done at a minute is done in one call")

	-- Order matters: a storage bought before the crank does not skip the steps before it.
	local early = Tutorial.step(Tutorial.start(), facts({ seconds = 60, nodes = { U17 = true } }))
	t.equal(Tutorial.current(early), "crank", "the storage does not skip the crank step")
	t.equal(early.done, false, "not done before the crank")

	-- Skipping: done at once, for good.
	local skipped = Tutorial.skip(Tutorial.start())
	t.equal(skipped.done, true, "skipping ends the tutorial")
	t.equal(Tutorial.current(skipped), nil, "a skipped tutorial has no step")
	t.equal(Tutorial.step(skipped, facts({ seconds = 60, cranks = 1 })).done, true, "a skipped tutorial stays skipped")

	-- A saved index outside the steps is clamped: a broken value starts at the crank, a large one at the storage.
	t.equal(Tutorial.current({ index = 0, done = false }), "crank", "an index below 1 starts at the crank")
	t.equal(Tutorial.current({ index = 0 / 0, done = false }), "crank", "a NaN index starts at the crank")
	t.equal(Tutorial.current({ index = 9, done = false }), "storage", "an index past the end is the storage")
	t.equal(Tutorial.current({ index = 2.7, done = false }), "panel", "a fractional index is rounded down")
	local clamped = Tutorial.step({ index = 9, done = false }, facts({ nodes = { U17 = true } }))
	t.equal(clamped.done, true, "a clamped storage step can finish the tutorial")
end
