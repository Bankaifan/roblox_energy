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
		t.equal(entry.cap, 4, `plant {plant.id} shows up to four copies`)
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

	cell, offsets = PlotLayout.copies(4, Assets.SLOT, Assets.COPY_GAP, Assets.MAX_CELL)
	t.equal(#offsets, 4, "four offsets")
	t.equal(offsets[1].x, -offsets[2].x, "four copies sit 2 x 2: two columns")
	t.equal(offsets[1].z, offsets[2].z, "four copies sit 2 x 2: first row")
	t.equal(offsets[3].z, offsets[4].z, "four copies sit 2 x 2: second row")
	t.truthy(offsets[3].z > offsets[1].z, "four copies sit 2 x 2: two rows")
	for i, a in offsets do
		t.truthy(PlotLayout.reach(a, cell) <= Assets.SLOT / 2, `of four, copy {i} stays on the pad`)
		for j = i + 1, #offsets do
			t.truthy(not PlotLayout.overlap(a, cell, offsets[j], cell), `of four, copies {i} and {j} do not overlap`)
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
		local footprint = piece.depth or piece.size
		t.truthy(PlotLayout.reach(at, footprint) <= half, `{name} is on the ground`)
		t.truthy(math.abs(piece.x) + piece.size / 2 <= half, `{name} fits the plot width`)
		table.insert(pieces, { name = name, at = at, size = footprint })
	end
	for i, a in pieces do
		for j = i + 1, #pieces do
			local b = pieces[j]
			t.truthy(not PlotLayout.overlap(a.at, a.size, b.at, b.size), `{a.name} and {b.name} do not overlap`)
		end
	end
	t.truthy(Assets.furniture.market.size >= 3 * 13, "the market is about three times its old 14 studs")
	-- The market's wide side must not reach over the pad rows (pads end at z = 31).
	local lastPad = pads[#pads]
	local market = Assets.furniture.market
	t.truthy(market.z - market.depth / 2 > lastPad.z + Assets.SLOT / 2, "the market clears the pads")

	-- Building box: a small add-on (sign) does not stretch it.
	local building = Assets.buildingBox({
		{ minX = 0, minY = 0, minZ = 0, maxX = 10, maxY = 6, maxZ = 8 },
		{ minX = 4, minY = 6, minZ = 3, maxX = 5, maxY = 20, maxZ = 3.5 },
		{ minX = -1, minY = 0, minZ = -1, maxX = 11, maxY = 1, maxZ = 9 },
	}, Assets.BUILDING_SHARE)
	t.equal(building.maxY, 6, "the sign post does not raise the building box")
	t.equal(building.minX, -1, "large parts such as the floor count")
	t.equal(Assets.buildingBox({}, Assets.BUILDING_SHARE), nil, "no parts, no box")
	t.equal(#PlotLayout.pads(0, 3, 34, 0), 0, "no plants, no pads")
	t.equal(Assets.useFurniture("market", { market = true }), true, "furniture entry and file: model")
	t.equal(Assets.useFurniture("market", {}), false, "furniture file missing: nothing built")
	t.equal(Assets.useFurniture("nope", { nope = true }), false, "furniture entry missing: nothing built")
	t.equal(Assets.batteryUnits(0), 0, "no storage, no unit")
	t.equal(Assets.batteryUnits(3), 3, "one unit per stage")
	t.equal(Assets.batteryUnits(9), 4, "at most four units")

	-- Land layout (design 0018): fields, fixed-size sites, wild panels, slots.
	local tile, tiles = Assets.TILE, Assets.PLOT_TILES
	t.equal(Assets.PLOT_SIZE, 192, "the plot is 192 studs")
	local rects = {}
	local parts = 0
	for id = 1, #Plants do
		local field = Assets.fields[id]
		t.truthy(field ~= nil, `plant {id} has a field`)
		local count = Assets.siteCount(id)
		parts += count * Assets.partsPerModel[id]
		local first = field.rows[1]
		local last = field.rows[#field.rows] + field.size - 1
		local rect = { c0 = field.col0, c1 = field.col0 + field.perRow * field.size - 1, r0 = first, r1 = last }
		t.truthy(rect.c0 >= 0 and rect.c1 < tiles and rect.r0 >= 0, `field {id} is inside the plot`)
		t.truthy(rect.r1 < Assets.LAND_FURNITURE_ROWS.first, `field {id} stays clear of the furniture rows`)
		for other, o in rects do
			local apart = rect.c1 < o.c0 or o.c1 < rect.c0 or rect.r1 < o.r0 or o.r1 < rect.r0
			t.truthy(apart, `fields {id} and {other} do not overlap`)
		end
		rects[id] = rect

		-- The site size is the same for one and for all units; tidy neighbours are exactly one footprint apart.
		local one = PlotLayout.sites(field, 1, tile, tiles)
		local all = PlotLayout.sites(field, count, tile, tiles)
		t.equal(#one, 1, `field {id}: one site`)
		t.equal(#all, count, `field {id}: all sites`)
		t.equal(all[1].x, one[1].x, `field {id}: the first site does not move with the count`)
		t.equal(all[1].z, one[1].z, `field {id}: the first site does not move in z`)
		local pitch = field.size * tile
		t.equal(all[2].x - all[1].x, pitch, `field {id}: neighbours are one footprint apart`)
		for i, a in all do
			t.truthy(PlotLayout.reach(a, pitch) <= Assets.PLOT_SIZE / 2, `field {id} site {i} is on the plot`)
			for j = i + 1, #all do
				t.truthy(not PlotLayout.overlap(a, pitch, all[j], pitch), `field {id} sites {i} and {j} do not overlap`)
			end
		end
	end
	t.truthy(parts <= Assets.MAX_PLANT_PARTS, `a full plot has {parts} plant parts, within the budget`)
	t.equal(Assets.siteCount(1), 24, "24 panel sites")
	t.equal(Assets.siteCount(2), 12, "12 stream tiles")
	t.equal(#PlotLayout.sites(Assets.fields[1], 99, tile, tiles), 24, "sites are capped at the field")
	t.equal(#PlotLayout.sites(Assets.fields[1], 0, tile, tiles), 0, "no count, no sites")

	local panels = Assets.fields[1]
	for seed = 1, 8 do
		local wild = PlotLayout.wild(panels, 99, seed, tile, tiles)
		local again = PlotLayout.wild(panels, 99, seed, tile, tiles)
		t.equal(#wild, 9, "at most nine wild panels")
		for i, a in wild do
			t.equal(a.x, again[i].x, "wild x is identical on a second call")
			t.equal(a.angle, again[i].angle, "wild angle is identical on a second call")
			t.truthy(math.abs(a.angle) <= PlotLayout.WILD_ANGLE, "the turn is at most 12 degrees")
			t.truthy(PlotLayout.reach(a, tile) <= Assets.PLOT_SIZE / 2, "a wild panel is on the plot")
			for j = i + 1, #wild do
				t.truthy(
					not PlotLayout.overlap(a, 9.6, wild[j], 9.6),
					`seed {seed}: wild panels {i} and {j} do not overlap`
				)
			end
		end
	end
	t.equal(#PlotLayout.wild(panels, 4, 1, tile, tiles), 4, "wild shows only the owned panels")
	-- A wild panel shows only once the tile under its centre is mown (tiles are mown in the order of `sites`).
	for prepared, fit in { [0] = 0, [1] = 1, [2] = 2, [3] = 2, [4] = 3, [8] = 3, [9] = 4, [12] = 6, [24] = 9 } do
		t.equal(PlotLayout.wildFit(panels, prepared, tile), fit, `{prepared} mown tiles carry {fit} wild panels`)
		local mown = PlotLayout.sites(panels, prepared, tile, tiles)
		for _, panel in PlotLayout.wild(panels, fit, 1, tile, tiles) do
			local onEarth = false
			for _, site in mown do
				local near = math.abs(panel.x - site.x) <= tile / 2 + 0.5 and math.abs(panel.z - site.z) <= tile / 2
				onEarth = onEarth or near
			end
			t.truthy(onEarth, `{prepared} mown tiles: every shown wild panel has its centre on a mown tile`)
		end
	end

	local seen = {}
	for n = 1, 8 do
		local s = PlotLayout.slot(n, Assets.PLOT_SPACING, Assets.PLOT_ROW_Z)
		t.truthy(math.abs(s.z) >= Assets.PLOT_SIZE / 2, `slot {n} is off the road`)
		t.equal(s.facing, if s.z > 0 then -1 else 1, `slot {n} faces the road`)
		local key = `{s.x},{s.z}`
		t.truthy(not seen[key], `slot {n} is a new place`)
		seen[key] = true
	end
	t.equal(PlotLayout.slot(1, 240, 128).x, 240, "slot 1 is the first column")
	t.equal(PlotLayout.slot(2, 240, 128).z, -128, "slot 2 is on the other side of the road")
	t.equal(PlotLayout.slot(8, 240, 128).x, 960, "slot 8 is the fourth column")
end
