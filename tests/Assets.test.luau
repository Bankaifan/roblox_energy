--!strict
-- Config/Assets: shape of the plant model map, and the fallback and layout decisions (pure functions).
return function(t, load)
	local Assets = load("Config/Assets")
	local Plants = load("Config/Plants")

	for _, plant in Plants do
		local entry = Assets.entry(plant.id)
		t.truthy(entry ~= nil, `plant {plant.id} has a model entry`)
		t.truthy(type(entry.file) == "string" and entry.file ~= "", `plant {plant.id} names a file`)
		t.truthy(entry.scale > 0 and entry.scale <= 1, `plant {plant.id} scale is in (0, 1]`)
		t.truthy(entry.cap >= 1 and entry.cap <= 8, `plant {plant.id} caps the visible copies at 8 or less`)
	end
	t.equal(Assets.plants[4].scale, 0.4, "the mini turbine is shown at 40 percent")

	-- Fallback: no entry or no file builds the primitive.
	t.equal(Assets.useModel(1, { plant1_panel = true }), true, "entry and file: model")
	t.equal(Assets.useModel(1, {}), false, "missing file: primitive")
	t.equal(Assets.useModel(99, { plant1_panel = true }), false, "missing entry: primitive")

	t.equal(Assets.visibleCopies(0, 8), 0, "no plants, no copies")
	t.equal(Assets.visibleCopies(3, 8), 3, "below the cap, all shown")
	t.equal(Assets.visibleCopies(50, 8), 8, "above the cap, capped")
	t.equal(Assets.visibleCopies(-2, 8), 0, "never negative")

	local cell, offsets = Assets.layout(1, 4)
	t.equal(cell, 4, "one copy fills the slot")
	t.equal(offsets[1].x, 0, "one copy is centred in x")
	cell, offsets = Assets.layout(5, 4)
	t.equal(cell, 4 / 3, "five copies need a 3 x 3 grid")
	t.equal(#offsets, 5, "five offsets")
	t.truthy(math.abs(offsets[5].x) <= 2 and math.abs(offsets[5].z) <= 2, "every copy stays inside the slot")
	t.equal(Assets.fitScale(8, 2, 4, 0.5), 0.25, "the longest side is fitted, times the factor")
end
