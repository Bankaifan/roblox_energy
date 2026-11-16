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
		t.truthy(entry.cap >= 1 and entry.cap <= 3, `plant {plant.id} caps the visible copies at 3 or less`)
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

	t.equal(Assets.fitScale(8, 2, 4, 0.5), 0.25, "the longest side is fitted, times the factor")

	-- Plot layout (issue #90): pads, copies, furniture all inside the plot, nothing overlapping.
	local PlotLayout = load("Core/PlotLayout")
	local half = Assets.PLOT_SIZE / 2
	t.truthy(Assets.PLOT_SIZE >= 120, "the plot is at least 120 studs")
	t.truthy(Assets.PLOT_SPACING > Assets.PLOT_SIZE, "neighbouring plots do not touch")

	local cell, offsets = PlotLayout.copies(1, Assets.SLOT, Assets.COPY_GAP, Assets.MAX_CELL)
	t.equal(cell, Assets.MAX_CELL, "one copy is capped at the largest cell")
	t.equal(offsets[1].x, 0, "one copy is centred in x")
	cell, offsets = PlotLayout.copies(3, Assets.SLOT, Assets.COPY_GAP, Assets.MAX_CELL)
	t.equal(#offsets, 3, "three offsets")
	for i, a in offsets do
		t.truthy(PlotLayout.reach(a, cell) <= Assets.SLOT / 2, `copy {i} stays on the pad`)
		for j = i + 1, #offsets do
			t.truthy(not PlotLayout.overlap(a, cell, offsets[j], cell), `copies {i} and {j} do not overlap`)
		end
	end

	local pads = PlotLayout.pads(#Plants, Assets.PAD_COLUMNS, Assets.PAD_PITCH, 0)
	t.equal(#pads, #Plants, "one pad per plant")
	local pieces = {}
	for i, pad in pads do
		t.truthy(PlotLayout.reach(pad, Assets.SLOT) <= half, `pad {i} is on the ground`)
		table.insert(pieces, { name = `pad{i}`, at = pad, size = Assets.SLOT })
	end
	for _, name in { "crank", "market", "control", "battery" } do
		local piece = Assets.furniture[name]
		t.truthy(piece ~= nil and piece.size > 0, `{name} has an entry`)
		local at = { x = piece.x, z = piece.z }
		t.truthy(PlotLayout.reach(at, piece.size) <= half, `{name} is on the ground`)
		table.insert(pieces, { name = name, at = at, size = piece.size })
	end
	for i, a in pieces do
		for j = i + 1, #pieces do
			local b = pieces[j]
			t.truthy(not PlotLayout.overlap(a.at, a.size, b.at, b.size), `{a.name} and {b.name} do not overlap`)
		end
	end
	t.equal(Assets.furniture.market.size, 14, "the market is about 14 wide")
	t.equal(#PlotLayout.pads(0, 3, 34, 0), 0, "no plants, no pads")
	t.equal(Assets.useFurniture("market", { market = true }), true, "furniture entry and file: model")
	t.equal(Assets.useFurniture("market", {}), false, "furniture file missing: nothing built")
	t.equal(Assets.useFurniture("nope", { nope = true }), false, "furniture entry missing: nothing built")
	t.equal(Assets.batteryUnits(0), 0, "no storage, no unit")
	t.equal(Assets.batteryUnits(3), 3, "one unit per stage")
	t.equal(Assets.batteryUnits(9), 4, "at most four units")
end
