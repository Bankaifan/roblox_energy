--!strict
-- Pure layout math of a plot (issue #90): where each plant pad stands and how the copies sit on a pad.
-- No Roblox APIs. All lengths are studs; x and z are relative to the plot centre.
local PlotLayout = {}

export type Point = { x: number, z: number }

-- Centres of `count` pads in a grid of `columns` columns, `pitch` studs apart, the whole grid centred on (0, centreZ).
function PlotLayout.pads(count: number, columns: number, pitch: number, centreZ: number): { Point }
	local points: { Point } = {}
	if count <= 0 or columns <= 0 then
		return points
	end
	local used = math.min(count, columns)
	local rows = math.ceil(count / columns)
	for i = 0, count - 1 do
		table.insert(points, {
			x = (i % columns - (used - 1) / 2) * pitch,
			z = centreZ + (i // columns - (rows - 1) / 2) * pitch,
		})
	end
	return points
end

-- `copies` models on a square pad of side `pad`: grid of side x side cells with `gap` studs between them.
-- Returns the cell size (at most `maxCell`) and the centre of each cell relative to the pad centre.
function PlotLayout.copies(copies: number, pad: number, gap: number, maxCell: number): (number, { Point })
	local offsets: { Point } = {}
	if copies <= 0 then
		return math.min(pad, maxCell), offsets
	end
	local side = math.ceil(math.sqrt(copies))
	local cell = math.min(maxCell, (pad - gap * (side - 1)) / side)
	local pitch = cell + gap
	for i = 0, copies - 1 do
		table.insert(offsets, {
			x = (i % side - (side - 1) / 2) * pitch,
			z = (i // side - (side - 1) / 2) * pitch,
		})
	end
	return cell, offsets
end

-- Half-extent of a square of side `size` centred at `point`, as the largest absolute x or z reached.
function PlotLayout.reach(point: Point, size: number): number
	return math.max(math.abs(point.x), math.abs(point.z)) + size / 2
end

-- True when two squares (centre + side) overlap.
function PlotLayout.overlap(a: Point, sizeA: number, b: Point, sizeB: number): boolean
	local limit = (sizeA + sizeB) / 2
	return math.abs(a.x - b.x) < limit and math.abs(a.z - b.z) < limit
end

-- Land layout (design 0018). Coordinates are relative to the plot centre, unmirrored: row 0 is the back (-z) and the
-- last row is the road side (+z). A plot with facing -1 is mirrored in z by the caller.
export type Field = { size: number, cells: { { number } } }
export type Site = { x: number, z: number }
export type WildSite = { x: number, z: number, angle: number }
export type Slot = { x: number, z: number, facing: number }

-- Plot slot n (1-based): four columns `spacing` apart, two rows of plots at z = +-rowZ beside the road at z = 0.
-- Slots alternate between the rows from the spawn outwards; z > 0 faces the road with facing -1.
function PlotLayout.slot(n: number, spacing: number, rowZ: number): Slot
	local column = (n - 1) // 2 + 1
	local north = (n - 1) % 2 == 0
	return { x = column * spacing, z = if north then rowZ else -rowZ, facing = if north then -1 else 1 }
end

-- Centre of tile (column, row) of a plot of `plotTiles` tiles of `tile` studs.
local function tileCentre(column: number, row: number, tile: number, plotTiles: number): Site
	local half = plotTiles * tile / 2
	return { x = (column + 0.5) * tile - half, z = (row + 0.5) * tile - half }
end

-- A field is a list of cells (Assets.fields): cell n is `field.cells[n]` = { column, row } of its top-left tile and is
-- `field.size` x `field.size` tiles. A player may mow the cells in any order (Prepare { target, cell }).
local function cellOrigin(field: Field, cell: number): (number, number)
	local origin = field.cells[cell]
	return origin[1], origin[2]
end

-- Number of cells of a field.
function PlotLayout.cellCount(field: Field): number
	return #field.cells
end

-- Centre of cell `cell` of a field (plot-relative studs).
function PlotLayout.cellCentre(field: Field, cell: number, tile: number, plotTiles: number): Site
	local column, row = cellOrigin(field, cell)
	local centre = tileCentre(column, row, tile, plotTiles)
	local shift = (field.size - 1) * tile / 2
	return { x = centre.x + shift, z = centre.z + shift }
end

-- The cell of a field that contains the plot-relative point (x, z), or nil when the point is outside every cell.
function PlotLayout.cellAt(field: Field, x: number, z: number, tile: number, plotTiles: number): number?
	local half = plotTiles * tile / 2
	local tx, tz = math.floor((x + half) / tile), math.floor((z + half) / tile)
	for cell = 1, #field.cells do
		local column, row = cellOrigin(field, cell)
		if tx >= column and tx < column + field.size and tz >= row and tz < row + field.size then
			return cell
		end
	end
	return nil
end

-- The mown cells of a field: the saved ordered list (in the order they were mown), cleaned (whole numbers inside the
-- field, no repeats), padded with the lowest free cells up to `count` (a profile that only knows a count) and cut to it.
function PlotLayout.mown(saved: { number }?, count: number, total: number): { number }
	local list: { number } = {}
	local used: { [number]: boolean } = {}
	local want = math.min(math.floor(count), total)
	for _, cell in saved or {} do
		if #list < want and cell % 1 == 0 and cell >= 1 and cell <= total and not used[cell] then
			used[cell] = true
			table.insert(list, cell)
		end
	end
	local free = 1
	while #list < want do
		if not used[free] then
			used[free] = true
			table.insert(list, free)
		end
		free += 1
	end
	return list
end

-- The started cells of a field: the prepared ones plus those still in work (they are in `saved` beyond the `sites` prepared
-- ones). Their grass is cut from the first stage on. Cleaned like PlotLayout.mown and never more than `total`.
function PlotLayout.started(saved: { number }?, sites: number, total: number): { number }
	return PlotLayout.mown(saved, math.max(#(saved or {}), sites), total)
end

-- Centres of the given cells, in the order given.
function PlotLayout.cellSites(field: Field, cells: { number }, tile: number, plotTiles: number): { Site }
	local points: { Site } = {}
	for _, cell in cells do
		table.insert(points, PlotLayout.cellCentre(field, cell, tile, plotTiles))
	end
	return points
end

-- Centres of the first `count` sites of a field, in the fixed fill order. A site is `field.size` x `field.size` tiles;
-- its size never depends on `count`.
function PlotLayout.sites(field: Field, count: number, tile: number, plotTiles: number): { Site }
	local cells: { number } = {}
	for cell = 1, math.min(math.floor(count), #field.cells) do
		table.insert(cells, cell)
	end
	return PlotLayout.cellSites(field, cells, tile, plotTiles)
end

-- Integer hash in [0, 1000) of (seed, index, salt): no Roblox APIs, same result on every call.
local function hash(seed: number, index: number, salt: number): number
	local h = (seed * 73856093 + index * 19349663 + salt * 83492791) % 2147483647
	h = (h * 1103515245 + 12345) % 2147483647
	return h % 1000
end

PlotLayout.WILD_SHIFT = 0.4
PlotLayout.WILD_ANGLE = 12

-- Wild layout: each point (the centre of a mown cell, in the order they were mown) is shifted by up to WILD_SHIFT studs
-- and turned by up to WILD_ANGLE degrees. The shift is small against the tile, so a wild panel stays on its mown tile.
function PlotLayout.wild(points: { Site }, seed: number): { WildSite }
	local wild: { WildSite } = {}
	for i, point in points do
		local jx = (hash(seed, i - 1, 1) / 999 * 2 - 1) * PlotLayout.WILD_SHIFT
		local jz = (hash(seed, i - 1, 2) / 999 * 2 - 1) * PlotLayout.WILD_SHIFT
		local angle = (hash(seed, i - 1, 3) / 999 * 2 - 1) * PlotLayout.WILD_ANGLE
		table.insert(wild, { x = point.x + jx, z = point.z + jz, angle = angle })
	end
	return wild
end

-- Plot ground (terrain): the square of a slot in world studs and its side in terrain cells of `cell` studs.
export type Ground = { minX: number, maxX: number, minZ: number, maxZ: number, cells: number }

function PlotLayout.ground(slot: Slot, plotSize: number, cell: number): Ground
	local half = plotSize / 2
	return {
		minX = slot.x - half,
		maxX = slot.x + half,
		minZ = slot.z - half,
		maxZ = slot.z + half,
		cells = plotSize // cell,
	}
end

return PlotLayout
