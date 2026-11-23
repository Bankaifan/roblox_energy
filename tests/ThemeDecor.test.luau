--!strict
-- Plot theme decoration (docs/themes-design.md): every theme has its look, texts and set; on the real site map every piece is
-- placed inside the fence and off cells, river, cables, furniture, lanes and sign; layouts are repeatable; the budget holds.
return function(t, load)
	local Assets = load("Config/Assets")
	local Themes = load("Config/Themes")
	local Locale = load("Config/Locale")
	local Cosmetics = load("Core/Cosmetics")
	local PlotLayout = load("Core/PlotLayout")
	local River = load("Core/River")
	local Cable = load("Core/Cable")
	local ThemeDecor = load("Core/ThemeDecor")

	local materials = { Grass = true, LeafyGrass = true, Sand = true, Ground = true, Snow = true }
	for _, id in Cosmetics.THEMES do
		t.truthy(Themes.sets[id] ~= nil, `{id}: a decoration set`)
		t.truthy(materials[Cosmetics.themeLook(id).material], `{id}: a known ground material`)
		t.truthy(Locale.tables.en[`style.theme.{id}`] ~= nil, `{id}: English text`)
		t.truthy(Locale.tables.de[`style.theme.{id}`] ~= nil, `{id}: German text`)
	end
	t.equal(#Cosmetics.THEMES, 8, "eight themes")
	t.equal(Cosmetics.THEMES[1], "classic", "classic stays the default")
	t.equal(#Themes.sets.classic.pieces, 0, "classic has no decoration")

	-- The real site map.
	local cells, furniture, board = {}, {}, Assets.furniture.control
	local cableLines: { ThemeDecor.Line } = {}
	for index, field in Assets.fields do
		local size = field.size * Assets.TILE
		local cellSites = PlotLayout.cellSites(
			field,
			PlotLayout.mown(nil, #field.cells, #field.cells),
			Assets.TILE,
			Assets.PLOT_TILES
		)
		for _, site in cellSites do
			table.insert(cells, { site.x, site.z, size })
		end
		if Assets.cables[index] then
			for _, link in Cable.links(cellSites, { x = board.x, z = board.z }) do
				table.insert(cableLines, { points = { { link.a.x, link.a.z }, { link.b.x, link.b.z } }, distance = 2 })
			end
		end
	end
	for name, spot in Assets.furniture do
		local w, d = spot.size, spot.depth or spot.size
		if name == "battery" then
			w, d =
				Assets.container.size * Cosmetics.MEGA_CONTAINER_SCALE,
				Assets.container.depth * Cosmetics.MEGA_CONTAINER_SCALE
		end
		table.insert(furniture, { spot.x, spot.z, w, d })
	end
	table.insert(furniture, { 9, 72, 3, 3 }) -- founder sign
	table.insert(furniture, { 0, 88, 12, 12 }) -- spawn pad
	table.insert(furniture, { 24, 91, 14, 3 }) -- name sign
	local input = { cells = cells, furniture = furniture, lanes = Themes.lanes, furnitureGap = Assets.CLEARANCE }
	local keep = { low = ThemeDecor.keepOut(input, 1.5), tall = ThemeDecor.keepOut(input, Assets.CLEARANCE) }
	t.equal(#keep.low, #cells + #furniture + #Themes.lanes, "a box for every cell, furniture piece and lane")

	local function overlaps(box: { number }, x: number, z: number, size: number): boolean
		local h = size / 2
		return x + h > box[1] and x - h < box[2] and z + h > box[3] and z - h < box[4]
	end

	local layouts = {}
	for seed = 1, 8 do
		local course = River.course(Assets.river, seed)
		local centre = {}
		for _, sample in course.samples do
			table.insert(centre, { sample.x, sample.z })
		end
		local lines = { { points = centre, distance = Assets.river.band + Assets.CLEARANCE } }
		for _, line in cableLines do
			table.insert(lines, line)
		end
		for id, set in Themes.sets do
			local sites = ThemeDecor.sites(set, keep, lines, seed, Themes.FENCE)
			layouts[`{id}:{seed}`] = sites
			local counts: { [number]: number } = {}
			for _, site in sites do
				local piece = set.pieces[site.piece]
				local size = piece.footprint * ThemeDecor.MAX_SCALE
				counts[site.piece] = (counts[site.piece] or 0) + 1
				local label = `{id} slot {seed} {site.kind}`
				t.truthy(
					math.max(math.abs(site.x), math.abs(site.z)) + size / 2 <= Themes.FENCE,
					`{label}: inside the fence`
				)
				t.truthy(site.scale >= 0.9 and site.scale <= 1.1, `{label}: scale 0.9 to 1.1`)
				for _, box in if piece.tall then keep.tall else keep.low do
					t.truthy(not overlaps(box, site.x, site.z, size), `{label}: off cells, furniture, lanes and sign`)
				end
				t.truthy(
					Cable.distanceToLine(centre, site.x, site.z) >= lines[1].distance + size / 2,
					`{label}: off the river`
				)
				for _, line in cableLines do
					t.truthy(
						Cable.distanceToLine(line.points, site.x, site.z) >= 2 + size / 2,
						`{label}: off the cables`
					)
				end
				t.truthy(
					River.gap(course, { site.x - size / 2, site.x + size / 2, site.z - size / 2, site.z + size / 2 })
						>= Assets.CLEARANCE,
					`{label}: clear of the water`
				)
			end
			for index, piece in set.pieces do
				if piece.zone == "fixed" then
					t.equal(counts[index], nil, `{id} {piece.kind}: no site`)
				elseif piece.zone == "fenceRoad" then
					t.truthy(
						(counts[index] or 0) >= 1 and (counts[index] or 0) <= piece.count,
						`{id} slot {seed} {piece.kind}: along the road rail`
					)
				else
					t.equal(counts[index], piece.count, `{id} slot {seed} {piece.kind}: every piece placed`)
				end
			end
			-- Pieces on the ground do not overlap each other.
			for i, a in sites do
				local zoneA = set.pieces[a.piece].zone
				if zoneA ~= "fenceRoad" and zoneA ~= "corners" then
					for j = i + 1, #sites do
						local b = sites[j]
						local zoneB = set.pieces[b.piece].zone
						if zoneB ~= "fenceRoad" and zoneB ~= "corners" then
							t.truthy(
								not PlotLayout.overlap(
									a,
									set.pieces[a.piece].footprint * ThemeDecor.MAX_SCALE,
									b,
									set.pieces[b.piece].footprint * ThemeDecor.MAX_SCALE
								),
								`{id} slot {seed}: {a.kind} and {b.kind} apart`
							)
						end
					end
				end
			end
		end
	end

	-- The same (theme, seed) gives the same list, another slot another layout.
	local again = ThemeDecor.sites(Themes.sets.christmas, keep, {}, 3, Themes.FENCE)
	local base = ThemeDecor.sites(Themes.sets.christmas, keep, {}, 3, Themes.FENCE)
	t.equal(#again, #base, "same site count")
	local same = true
	for i, site in again do
		same = same
			and site.x == base[i].x
			and site.z == base[i].z
			and site.yaw == base[i].yaw
			and site.scale == base[i].scale
	end
	t.truthy(same, "the same seed gives the same layout")
	local moved = false
	for i, site in layouts["christmas:1"] do
		local other = layouts["christmas:2"][i]
		moved = moved or other == nil or site.x ~= other.x or site.z ~= other.z
	end
	t.truthy(moved, "another plot slot looks different")

	-- Budget: parts, lights and particles stay inside the plot budget.
	local totals = {
		christmas = 179,
		halloween = 162,
		autumn = 119,
		summer = 128,
		spring = 119,
		desert = 79,
		night = 76,
		classic = 58,
	}
	local decoration = { autumn = 61, summer = 70, spring = 61, desert = 21, night = 18 }
	for id, parts in decoration do
		t.equal(Themes.budget(Themes.sets[id]).parts - Themes.BASE_PARTS, parts, `{id}: parts of the decoration alone`)
	end
	for id, set in Themes.sets do
		local budget = Themes.budget(set)
		t.equal(budget.parts, totals[id], `{id}: parts of the base plus the decoration`)
		t.truthy(budget.parts <= Themes.THEME_PARTS, `{id}: at most {Themes.THEME_PARTS} parts`)
		t.truthy(budget.lights <= Themes.MAX_LIGHTS, `{id}: at most {Themes.MAX_LIGHTS} lights`)
		t.truthy(budget.rate <= Themes.MAX_RATE, `{id}: particle rate`)
	end
end
