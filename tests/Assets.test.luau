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
	for _, name in { "crank", "market", "control", "battery" } do
		local piece = Assets.furniture[name]
		t.truthy(piece ~= nil and piece.size > 0, `{name} has an entry`)
		t.truthy(piece.z - (piece.depth or piece.size) / 2 >= 56, `{name} stands in the yard`)
	end
	t.truthy(Assets.furniture.market.size >= 3 * 13, "the market is about three times its old 14 studs")

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

	-- Land layout (design v2, section 3): fields are cell lists of fixed-size sites.
	local tile, tiles = Assets.TILE, Assets.PLOT_TILES
	t.equal(Assets.PLOT_SIZE, 192, "the plot is 192 studs")
	local parts = 0
	local counts = { 25, 7, 7, 7, 4, 4 }
	for id = 1, #Plants do
		local field = Assets.fields[id]
		t.truthy(field ~= nil, `plant {id} has a field`)
		local count = Assets.siteCount(id)
		t.equal(count, counts[id], `field {id} has {counts[id]} cells`)
		parts += count * Assets.partsPerModel[id]
		for i, origin in field.cells do
			local c0, r0 = origin[1], origin[2]
			t.truthy(
				c0 >= Assets.USABLE.first
					and c0 + field.size - 1 <= Assets.USABLE.last
					and r0 >= Assets.USABLE.first
					and r0 + field.size - 1 <= Assets.USABLE.last,
				`field {id} cell {i} is inside the usable area`
			)
		end

		-- The site size is the same for one and for all units.
		local one = PlotLayout.sites(field, 1, tile, tiles)
		local all = PlotLayout.sites(field, count, tile, tiles)
		t.equal(#one, 1, `field {id}: one site`)
		t.equal(#all, count, `field {id}: all sites`)
		t.equal(all[1].x, one[1].x, `field {id}: the first site does not move with the count`)
		t.equal(all[1].z, one[1].z, `field {id}: the first site does not move in z`)
		local pitch = field.size * tile
		for i, a in all do
			t.truthy(PlotLayout.reach(a, pitch) <= Assets.PLOT_SIZE / 2, `field {id} site {i} is on the plot`)
			for j = i + 1, #all do
				t.truthy(not PlotLayout.overlap(a, pitch, all[j], pitch), `field {id} sites {i} and {j} do not overlap`)
			end
		end
	end
	t.truthy(parts <= Assets.MAX_PLANT_PARTS, `a full plot has {parts} plant parts, within the budget`)
	t.equal(Assets.siteCount(1), 25, "25 panel tiles")
	t.equal(Assets.siteCount(2), 7, "7 river segments")
	t.equal(#PlotLayout.sites(Assets.fields[1], 99, tile, tiles), 25, "sites are capped at the field")
	t.equal(#PlotLayout.sites(Assets.fields[1], 0, tile, tiles), 0, "no count, no sites")

	-- Clearance rule: every cell of every field (the river's stand-in cells excepted), the river band and every
	-- furniture box keep CLEARANCE studs from each other and lie inside the usable area.
	local low = Assets.USABLE.first * tile - tiles * tile / 2
	local high = (Assets.USABLE.last + 1) * tile - tiles * tile / 2
	local function problemsOf(fields, furniture, river): { string }
		local problems = {}
		local groups = {}
		for id, field in fields do
			if field.river ~= true then
				local boxes = {}
				for n = 1, #field.cells do
					local c = PlotLayout.cellCentre(field, n, tile, tiles)
					local h = field.size * tile / 2
					table.insert(boxes, { c.x - h, c.x + h, c.z - h, c.z + h, `field {id} cell {n}` })
				end
				table.insert(groups, { name = `field {id}`, boxes = boxes })
			end
		end
		for name, piece in furniture do
			local w, d = piece.size / 2, (piece.depth or piece.size) / 2
			table.insert(
				groups,
				{ name = name, boxes = { { piece.x - w, piece.x + w, piece.z - d, piece.z + d, name } } }
			)
		end
		-- A box is { minX, maxX, minZ, maxZ, name }.
		for _, group in groups do
			for _, b in group.boxes do
				if b[1] < low or b[2] > high or b[3] < low or b[4] > high then
					table.insert(problems, `{b[5]} is outside the usable area`)
				end
			end
		end
		for i, a in groups do
			for j = i + 1, #groups do
				for _, p in a.boxes do
					for _, q in groups[j].boxes do
						local gap = math.max(q[1] - p[2], p[1] - q[2], q[3] - p[4], p[3] - q[4])
						if gap < Assets.CLEARANCE then
							table.insert(problems, `{p[5]} and {q[5]} are closer than {Assets.CLEARANCE} studs`)
						end
					end
				end
			end
		end
		-- The river band: every box keeps band + CLEARANCE from the centre line (a polyline), tested on a 2-stud raster.
		local function distance(px: number, pz: number, a: { number }, b: { number }): number
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local u = math.clamp(((px - a[1]) * dx + (pz - a[2]) * dz) / (dx * dx + dz * dz), 0, 1)
			return math.sqrt((px - a[1] - u * dx) ^ 2 + (pz - a[2] - u * dz) ^ 2)
		end
		for _, group in groups do
			for _, b in group.boxes do
				local near = math.huge
				for x = b[1], b[2], 2 do
					for z = b[3], b[4], 2 do
						for k = 1, #river.points - 1 do
							near = math.min(near, distance(x, z, river.points[k], river.points[k + 1]))
						end
					end
				end
				if near < river.band + Assets.CLEARANCE then
					table.insert(problems, `{b[5]} is too close to the river ({near})`)
				end
			end
		end
		for _, point in river.points do
			if point[1] < low or point[1] > high or point[2] < low or point[2] > high then
				table.insert(problems, "a river point is outside the usable area")
			end
		end
		return problems
	end
	local problems = problemsOf(Assets.fields, Assets.furniture, Assets.river)
	t.equal(#problems, 0, `the site map keeps its clearances: {table.concat(problems, "; ")}`)

	-- The map of design 0018 (water wheels in rows 13 and 16, the market in front of them) breaks the rule.
	local oldFields = { [2] = { size = 1, cells = { { 7, 13 }, { 8, 13 }, { 7, 16 }, { 8, 16 } } } }
	local oldFurniture = { market = { x = -20, z = 48, size = 40, depth = 20 } }
	local oldProblems = table.concat(problemsOf(oldFields, oldFurniture, Assets.river), "; ")
	t.truthy(
		oldProblems:find("field 2 cell 3 and market", 1, true) ~= nil,
		`the old map fails: wheels under the market ({oldProblems})`
	)

	-- Wild panels stand on the mown cells, in any order, each a little shifted and turned.
	local panels = Assets.fields[1]
	local order = { 17, 3, 24, 9, 1, 12, 6, 20, 14 }
	local centres = PlotLayout.cellSites(panels, order, tile, tiles)
	for seed = 1, 8 do
		local wild = PlotLayout.wild(centres, seed)
		local again = PlotLayout.wild(centres, seed)
		t.equal(#wild, #order, "one wild panel per mown cell")
		for i, a in wild do
			t.equal(a.x, again[i].x, "wild x is identical on a second call")
			t.equal(a.angle, again[i].angle, "wild angle is identical on a second call")
			t.truthy(math.abs(a.angle) <= PlotLayout.WILD_ANGLE, "the turn is at most 12 degrees")
			t.truthy(
				math.abs(a.x - centres[i].x) <= PlotLayout.WILD_SHIFT + 1e-9,
				"a wild panel stays on its mown tile in x"
			)
			t.truthy(
				math.abs(a.z - centres[i].z) <= PlotLayout.WILD_SHIFT + 1e-9,
				"a wild panel stays on its mown tile in z"
			)
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
