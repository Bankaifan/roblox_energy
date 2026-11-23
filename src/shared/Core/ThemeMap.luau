--!strict
-- The site map of a plot as Core/ThemeDecor input (docs/themes-design.md, sections 4.3 and 4.5), for one plot slot: the
-- keep-out boxes (every cell of every field, the furniture, the walk lanes), the river centre line and the cable lines.
-- Pure: `libs` holds the modules the caller passes (Assets, Themes, Cosmetics, PlotLayout, River, Cable, ThemeDecor).
local ThemeMap = {}

function ThemeMap.scene(libs: any, seed: number): any
	local Assets, Themes, Cosmetics = libs.Assets, libs.Themes, libs.Cosmetics
	local PlotLayout, River, Cable, ThemeDecor = libs.PlotLayout, libs.River, libs.Cable, libs.ThemeDecor
	local cells, furniture, cables = {}, {}, {}
	local board = Assets.furniture.control
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
				table.insert(cables, { points = { { link.a.x, link.a.z }, { link.b.x, link.b.z } }, distance = 2 })
			end
		end
	end
	for name, spot in Assets.furniture do
		local w, d = spot.size, spot.depth or spot.size
		if name == "battery" then
			w = Assets.container.size * Cosmetics.MEGA_CONTAINER_SCALE
			d = Assets.container.depth * Cosmetics.MEGA_CONTAINER_SCALE
		end
		table.insert(furniture, { spot.x, spot.z, w, d })
	end
	table.insert(furniture, { 9, 72, 3, 3 }) -- founder sign
	table.insert(furniture, { 0, 88, 12, 12 }) -- spawn pad
	table.insert(furniture, { 24, 91, 14, 3 }) -- name sign
	local input = { cells = cells, furniture = furniture, lanes = Themes.lanes, furnitureGap = Assets.CLEARANCE }
	local course = River.course(Assets.river, seed)
	local centre = {}
	for _, sample in course.samples do
		table.insert(centre, { sample.x, sample.z })
	end
	local lines = { { points = centre, distance = Assets.river.band + Assets.CLEARANCE } }
	for _, line in cables do
		table.insert(lines, line)
	end
	return {
		keep = { low = ThemeDecor.keepOut(input, 1.5), tall = ThemeDecor.keepOut(input, Assets.CLEARANCE) },
		lines = lines,
		cables = cables,
		centre = centre,
		course = course,
	}
end

return ThemeMap
