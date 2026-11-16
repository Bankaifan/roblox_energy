--!strict
-- Plot ground: every slot gets its own square on whole terrain cells beside the road, with a frame of one cell.
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

	local border = 0
	for ix = 1, 48 do
		for iz = 1, 48 do
			if PlotLayout.groundCover(ix, iz, 48, 1) == "border" then
				border += 1
				t.truthy(ix == 1 or ix == 48 or iz == 1 or iz == 48, `border cell {ix}, {iz} lies on the edge`)
			end
		end
	end
	t.equal(border, 48 * 48 - 46 * 46, "the frame is one cell wide all around")
	t.equal(PlotLayout.groundCover(2, 3, 48, 2), "border", "a wider frame reaches the second cell")
end
