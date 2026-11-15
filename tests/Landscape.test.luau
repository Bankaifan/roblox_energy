--!strict
-- Landscape (issue 85): plots stay flat, the world keeps its box, props keep off the meadow and under the part cap.
return function(t, load)
	local Assets = load("Config/Assets")
	local Landscape = load("Core/Landscape").new(Assets.PLOT_SIZE, Assets.PLOT_SPACING, 8)
	local plots = Landscape.PLOTS

	-- The plot box follows the plot constants: 8 plots, centres at slot * PLOT_SPACING
	t.equal(plots.minX, Assets.PLOT_SPACING - Assets.PLOT_SIZE / 2, "first plot starts the plot box")
	t.equal(plots.maxX, 8 * Assets.PLOT_SPACING + Assets.PLOT_SIZE / 2, "eighth plot ends the plot box")
	t.equal(plots.maxZ, Assets.PLOT_SIZE / 2, "the plot box is one plot deep")

	-- Flat ground under every plot, with a margin, and at the spawn (origin)
	for x = plots.minX - 20, plots.maxX + 20, 8 do
		for z = plots.minZ - 12, plots.maxZ + 12, 8 do
			t.equal(Landscape.height(x, z), 0, `ground under the plots is flat at {x}, {z}`)
		end
	end
	t.equal(Landscape.height(0, 0), 0, "ground at the origin is flat")

	-- The world box holds every plot with room for hills; heights stay inside it; there is a lake and there are hills
	t.truthy(
		Landscape.MIN_X < plots.minX - 150 and Landscape.MAX_X > plots.maxX + 150,
		"the world box holds every plot"
	)
	local lowest, highest = 0, 0
	for x = Landscape.MIN_X, Landscape.MAX_X, 16 do
		for z = Landscape.MIN_Z, Landscape.MAX_Z, 16 do
			local height = Landscape.height(x, z)
			lowest, highest = math.min(lowest, height), math.max(highest, height)
		end
	end
	t.truthy(lowest > Landscape.FLOOR and highest < Landscape.CEILING, "heights stay inside the voxel box")
	t.truthy(lowest < Landscape.WATER - 6, "the lake is deep enough to hold water")
	t.truthy(highest > 30, "there are hills")
	t.equal(Landscape.surface(plots.minX, Landscape.roadZ(plots.minX)), "Asphalt", "the road runs beside the plots")

	-- Props: the same for the same seed, none on the meadow or the road, part count under the cap
	local props = Landscape.props(85)
	local again = Landscape.props(85)
	t.equal(#props, #again, "same seed, same number of props")
	local kinds: { [string]: number } = {}
	for index, prop in props do
		t.truthy(prop.x == again[index].x and prop.z == again[index].z, "same seed, same places")
		t.truthy(
			Landscape.meadowDistance(prop.x, prop.z) > 0 or prop.kind == "pole" or prop.kind == "lamppole",
			`{prop.kind} stands on the meadow`
		)
		t.truthy(Landscape.roadDistance(prop.x, prop.z) >= 10, `{prop.kind} stands on the road`)
		local onPlot = prop.x > plots.minX and prop.x < plots.maxX and prop.z > plots.minZ and prop.z < plots.maxZ
		t.truthy(not onPlot, `{prop.kind} stands on a plot`)
		kinds[prop.kind] = (kinds[prop.kind] or 0) + 1
	end
	t.truthy((kinds.oak or 0) + (kinds.birch or 0) >= 50, "there are trees")
	t.truthy((kinds.pole or 0) + (kinds.lamppole or 0) >= 15, "power poles line the road")
	t.truthy((kinds.flower or 0) >= 30, "there are glowing flowers")
	t.truthy(Landscape.partCount(props) <= Landscape.MAX_PARTS, `too many parts: {Landscape.partCount(props)}`)
end
