--!strict
-- Plot ground: every slot gets its own square on whole terrain cells beside the road.
return function(t, load)
	local Assets = load("Config/Assets")
	local PlotLayout = load("Core/PlotLayout")
	local Landscape =
		load("Core/Landscape").new(Assets.PLOT_SIZE, Assets.PLOT_SPACING, Assets.PLOT_COLUMNS, Assets.PLOT_ROW_Z)
	local cell = Landscape.CELL

	t.equal(Assets.GROUND_Y, cell / 2, "the surface lies half a terrain cell above the full cells")
	local grounds = {}
	for n = 1, 2 * Assets.PLOT_COLUMNS do
		local slot = PlotLayout.slot(n, Assets.PLOT_SPACING, Assets.PLOT_ROW_Z)
		local ground = PlotLayout.ground(slot, Assets.PLOT_SIZE, cell)
		t.equal(ground.cells, 48, `ground {n} is 48 cells wide`)
		t.equal(ground.maxX - ground.minX, ground.cells * cell, `ground {n} is as wide as its cells`)
		t.equal(ground.maxZ - ground.minZ, ground.cells * cell, `ground {n} is as deep as its cells`)
		t.truthy(ground.minX % cell == 0 and ground.minZ % cell == 0, `ground {n} starts on a cell border`)
		for _, x in { ground.minX, ground.maxX } do
			for _, z in { ground.minZ, ground.maxZ } do
				t.equal(Landscape.meadowDistance(x, z), 0, `ground {n} lies on the meadow at {x}, {z}`)
				t.truthy(Landscape.roadDistance(x, z) >= 9, `ground {n} keeps off the road at {x}, {z}`)
			end
		end
		for _, other in grounds do
			local apart = ground.minX >= other.maxX
				or ground.maxX <= other.minX
				or ground.minZ >= other.maxZ
				or ground.maxZ <= other.minZ
			t.truthy(apart, `ground {n} overlaps no other ground`)
		end
		table.insert(grounds, ground)
	end

	-- Spawn point: inside the plot at the road side and clear of the crank.
	local crank = Assets.furniture.crank
	local spawn = PlotLayout.spawnPoint(Assets.PLOT_SIZE, crank.z, 12)
	t.truthy(math.abs(spawn.x) + 6 <= Assets.PLOT_SIZE / 2, "the spawn platform lies inside the plot in x")
	t.truthy(spawn.z + 6 <= Assets.PLOT_SIZE / 2, "the spawn platform lies inside the plot in z")
	t.truthy(spawn.z - 6 > crank.z + 5, "the spawn platform keeps clear of the crank pad")

	-- Free mowing: the cell under a point, the mown list and the cells' centres.
	local tile, tiles = Assets.TILE, Assets.PLOT_TILES
	for index, field in Assets.fields do
		for cellNo = 1, Assets.siteCount(index) do
			local centre = PlotLayout.cellCentre(field, cellNo, tile, tiles)
			t.equal(
				PlotLayout.cellAt(field, centre.x, centre.z, tile, tiles),
				cellNo,
				`field {index} cell {cellNo} is found at its centre`
			)
		end
	end
	t.equal(PlotLayout.cellAt(Assets.fields[1], 0, 90, tile, tiles), nil, "a point outside the field is no cell")
	t.equal(PlotLayout.cellAt(Assets.fields[2], -60, 0, tile, tiles), nil, "a point left of the field is no cell")
	t.equal(#PlotLayout.mown({ 3, 3, 99, 5 }, 3, 24), 3, "the mown list is cut to the count")
	t.equal(
		table.concat(PlotLayout.mown({ 3, 3, 99, 5 }, 3, 24), ","),
		"3,5,1",
		"repeats and strangers go, free cells fill up"
	)
	t.equal(#PlotLayout.mown(nil, 99, 24), 24, "the mown list never passes the field")
	t.equal(PlotLayout.cellCount(Assets.fields[6]), 4, "a field is its cell list: four wind pads")
	t.equal(PlotLayout.cellAt(Assets.fields[6], -80, -80, tile, tiles), 1, "a 4 x 4 pad is found anywhere on its tiles")
	-- Started cells: prepared ones and those in work (listed beyond the prepared count) have their grass cut.
	t.equal(table.concat(PlotLayout.started({ 4, 6, 2 }, 1, 7), ","), "4,6,2", "cells in work count as started")
	t.equal(table.concat(PlotLayout.started({ 4, 6 }, 2, 7), ","), "4,6", "done cells still count")
	t.equal(#PlotLayout.started(nil, 0, 7), 0, "an empty field has no started cell")
	t.equal(#PlotLayout.started({ 1, 2, 3, 4 }, 0, 3), 3, "never more than the field has")
	t.equal(#PlotLayout.started(nil, 3, 7), 3, "a state that only knows a count pads the lowest cells")
	local order = { 9, 3, 7, 5 }
	t.equal(table.concat(PlotLayout.bare(order, 0), ","), "3,5,7,9", "no unit: every cell is bare, sorted")
	t.equal(table.concat(PlotLayout.bare(order, 2), ","), "5,7", "the units take the first cells in order")
	t.equal(table.concat(PlotLayout.bare(order, 1.9), ","), "3,5,7", "a fractional count rounds down")
	t.equal(#PlotLayout.bare(order, 4), 0, "one unit per cell leaves no bare cell")
	t.equal(#PlotLayout.bare(order, 10), 0, "more units than cells leaves none")
	t.equal(#PlotLayout.bare({}, 0), 0, "no cells, no bare cell")

	-- Issue #192: n owned units on n prepared cells draw n sites, in every field and for every n.
	for plant, field in Assets.fields do
		local cells = PlotLayout.mown(nil, #field.cells, #field.cells)
		for n = 1, #field.cells do
			local prepared = PlotLayout.mown(nil, n, #field.cells)
			local chosen = PlotLayout.chosen(prepared, n)
			t.equal(#chosen, n, `plant {plant}: {n} owned on {n} prepared cells carry {n} units`)
			t.equal(#PlotLayout.cellSites(field, chosen, Assets.TILE, Assets.PLOT_TILES), n, `plant {plant}: {n} sites`)
		end
		t.equal(
			#PlotLayout.chosen(cells, #cells + 3),
			#cells,
			`plant {plant}: units past the cells have no cell of their own`
		)
		t.equal(#PlotLayout.chosen(cells, 0), 0, `plant {plant}: no units, no site`)
	end
	-- Packed units (all bought panels visible): min(owned, cap x cells) sites, each inside its own cell, none overlapping.
	for plant, field in Assets.fields do
		local full = field.size * Assets.TILE
		for _, c in { 1, 2, #field.cells } do
			local cells = PlotLayout.mown(nil, c, #field.cells)
			local cap = Assets.plants[plant].cap
			for _, n in { 0, 1, c, c + 1, 3 * c, cap * c, cap * c + 5 } do
				local sites = PlotLayout.packed(field, cells, n, Assets.TILE, Assets.PLOT_TILES, cap)
				t.equal(#sites, math.min(n, cap * c), `plant {plant}: {n} owned on {c} cells draw min(n, cap x cells)`)
				for i, a in sites do
					local centre = PlotLayout.cellCentre(field, a.cell, Assets.TILE, Assets.PLOT_TILES)
					t.truthy(a.side > 0 and a.side <= full + 1e-9, "a unit is no larger than its cell")
					t.truthy(
						math.abs(a.x - centre.x) + a.side / 2 <= full / 2 + 1e-9
							and math.abs(a.z - centre.z) + a.side / 2 <= full / 2 + 1e-9,
						"a unit lies inside its cell"
					)
					for j = i + 1, #sites do
						local b = sites[j]
						local apart = math.abs(a.x - b.x) >= (a.side + b.side) / 2 - 1e-9
							or math.abs(a.z - b.z) >= (a.side + b.side) / 2 - 1e-9
						t.truthy(apart, "no two units overlap")
					end
				end
			end
		end
	end
	local five = PlotLayout.packed(Assets.fields[1], { 1, 2 }, 5, Assets.TILE, Assets.PLOT_TILES, 4)
	t.equal(#five, 5, "5 panels on 2 cells all show")
	t.equal(five[1].side, Assets.TILE / 2, "a cell with 3 units is a 2 x 2 grid")
	t.equal(five[4].side, Assets.TILE / 2, "and so is one with 2")
	t.equal(#PlotLayout.packed(Assets.fields[1], {}, 5, Assets.TILE, Assets.PLOT_TILES, 4), 0, "no cell, no unit")

	local order = { 7, 2, 9 }
	t.equal(table.concat(PlotLayout.chosen(order, 2), ","), "7,2", "the first cells mown carry the units")
	t.equal(table.concat(PlotLayout.chosen(order, 2.9), ","), "7,2", "a fractional count rounds down")
end
