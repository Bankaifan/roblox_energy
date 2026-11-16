--!strict
-- Natural plot ground (issue #111): cleared patches with a wobbly outline and a low fence around unprepared sites.
return function(t, load)
	local Assets = load("Config/Assets")
	local PlotLayout = load("Core/PlotLayout")
	local Meadow = load("Core/Meadow")
	local cell = 4
	local cells = Assets.PLOT_SIZE // cell
	local half = Assets.PLOT_SIZE / 2

	local function sitePatches(index: number, sites: number)
		local field = Assets.fields[index]
		local patches = {}
		for _, site in PlotLayout.sites(field, sites, Assets.TILE, Assets.PLOT_TILES) do
			table.insert(patches, Meadow.sitePatch(site.x, site.z, field.size * Assets.TILE))
		end
		return patches
	end
	local function earth(mask): number
		local n = 0
		for ix = 1, cells do
			for iz = 1, cells do
				n += if mask[ix][iz] then 1 else 0
			end
		end
		return n
	end

	-- Every cell of a prepared site is earth, whatever the seed and the site size; the edge reaches beyond it.
	for seed = 1, 2 * Assets.PLOT_COLUMNS do
		for index, field in Assets.fields do
			local total = Assets.siteCount(index)
			local mask = Meadow.mask(sitePatches(index, total), seed, cells, cell)
			local side = field.size * Assets.TILE
			local inside = 0
			for _, site in PlotLayout.sites(field, total, Assets.TILE, Assets.PLOT_TILES) do
				for x = site.x - side / 2 + cell / 2, site.x + side / 2, cell do
					for z = site.z - side / 2 + cell / 2, site.z + side / 2, cell do
						inside += 1
						local ix, iz = (x + half) // cell + 1, (z + half) // cell + 1
						t.truthy(mask[ix][iz], `seed {seed} field {index}: the site cell at {x}, {z} is earth`)
					end
				end
			end
			t.truthy(earth(mask) > inside, `seed {seed} field {index}: the earth frays out beyond the sites`)
		end
	end

	-- The same call gives the same ground, another plot gets another outline, and mowing more never regrows grass.
	local first = Meadow.mask(sitePatches(1, 24), 1, cells, cell)
	local again = Meadow.mask(sitePatches(1, 24), 1, cells, cell)
	local other = Meadow.mask(sitePatches(1, 24), 2, cells, cell)
	local fewer = Meadow.mask(sitePatches(1, 4), 1, cells, cell)
	local differs = false
	local lefts, edges = {}, 0
	for iz = 1, cells do
		for ix = 1, cells do
			t.equal(again[ix][iz], first[ix][iz], `cell {ix}, {iz} is the same on a second call`)
			t.truthy(first[ix][iz] or not fewer[ix][iz], `cell {ix}, {iz} stays earth when more is mown`)
			differs = differs or first[ix][iz] ~= other[ix][iz]
		end
		for ix = 1, cells do
			if first[ix][iz] then
				edges += if lefts[ix] then 0 else 1
				lefts[ix] = true
				break
			end
		end
	end
	t.truthy(differs, "two plots do not share one outline")
	t.truthy(edges >= 2, "the left edge of a mown field is not one straight line")

	-- A fresh plot stays a meadow: the patches around the crank and the market are a small part of it.
	local start = {}
	for _, name in { "crank", "market" } do
		local spot = Assets.furniture[name]
		table.insert(start, { x = spot.x, z = spot.z, r = spot.size / 2 + 8 })
	end
	local cleared = earth(Meadow.mask(start, 1, cells, cell))
	t.truthy(cleared > 0 and cleared < cells * cells / 8, `a fresh plot is mostly meadow ({cleared} cells of earth)`)

	-- Fence: a closed rope around the open sites, few parts, gone when the field is full.
	for index, field in Assets.fields do
		local total = Assets.siteCount(index)
		for _, done in { 0, 1, total // 2, total - 1 } do
			local mown = {}
			for cellNo = 1, done do
				mown[cellNo] = true
			end
			local stakes, ropes = Meadow.fence(field, mown, 3, Assets.TILE, Assets.PLOT_TILES)
			local label = `field {index} with {done} done`
			local ends = table.create(#stakes, 0)
			for _, rope in ropes do
				ends[rope.from] += 1
				ends[rope.to] += 1
				local a, b = stakes[rope.from], stakes[rope.to]
				local length = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
				t.truthy(length > 0 and length <= 16 + 4 * Meadow.STAKE_SHIFT, `{label}: a rope is short ({length})`)
			end
			for i in stakes do
				t.equal(ends[i], 2, `{label}: stake {i} holds two ropes`)
			end
			t.truthy(#stakes >= 4 and #stakes + #ropes <= 40, `{label}: {#stakes + #ropes} fence parts`)
		end
		local full = {}
		for cellNo = 1, total do
			full[cellNo] = true
		end
		local stakes, ropes = Meadow.fence(field, full, 3, Assets.TILE, Assets.PLOT_TILES)
		t.equal(#stakes + #ropes, 0, `field {index}: a full field has no fence`)
	end

	-- No fence line is straight: every stake stands a little off its grid corner, the same on every call.
	local stakes = Meadow.fence(Assets.fields[1], {}, 3, Assets.TILE, Assets.PLOT_TILES)
	local same = Meadow.fence(Assets.fields[1], {}, 3, Assets.TILE, Assets.PLOT_TILES)
	local xs, distinct = {}, 0
	for i, stake in stakes do
		t.equal(same[i].x, stake.x, `stake {i} stands at the same place on a second call`)
		distinct += if xs[stake.x] then 0 else 1
		xs[stake.x] = true
		local gx, gz = (stake.x + half) / Assets.TILE, (stake.z + half) / Assets.TILE
		local off = math.max(math.abs(gx - math.round(gx)), math.abs(gz - math.round(gz))) * Assets.TILE
		t.truthy(off > 0 and off <= Meadow.STAKE_SHIFT, `stake {i} stands a little off its grid corner`)
	end
	t.equal(distinct, #stakes, "no two stakes of a field line up in x")
end
