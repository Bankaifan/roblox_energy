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
export type Field = { size: number, col0: number, perRow: number, rows: { number } }
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

-- Centres of the first `count` sites of a field, in the fixed fill order: a row of `perRow`, then the next row.
-- A site is `field.size` x `field.size` tiles; its size never depends on `count`.
function PlotLayout.sites(field: Field, count: number, tile: number, plotTiles: number): { Site }
	local points: { Site } = {}
	local total = field.perRow * #field.rows
	for i = 0, math.min(math.floor(count), total) - 1 do
		local column = field.col0 + (i % field.perRow) * field.size
		local row = field.rows[i // field.perRow + 1]
		local centre = tileCentre(column, row, tile, plotTiles)
		local shift = (field.size - 1) * tile / 2
		table.insert(points, { x = centre.x + shift, z = centre.z + shift })
	end
	return points
end

-- Integer hash in [0, 1000) of (seed, index, salt): no Roblox APIs, same result on every call.
local function hash(seed: number, index: number, salt: number): number
	local h = (seed * 73856093 + index * 19349663 + salt * 83492791) % 2147483647
	h = (h * 1103515245 + 12345) % 2147483647
	return h % 1000
end

PlotLayout.WILD_SHIFT = 0.4
PlotLayout.WILD_ANGLE = 12
PlotLayout.WILD_PER_ROW = 3

-- Wild layout of the first `count` panels (at most 9): three per row on every second mown row (rows 1, 3, 5 of the
-- field), each shifted by up to WILD_SHIFT studs and turned by up to WILD_ANGLE degrees. The three panels of a row
-- are spread over the field width, so even a turned panel does not touch its neighbour.
function PlotLayout.wild(field: Field, count: number, seed: number, tile: number, plotTiles: number): { WildSite }
	local points: { WildSite } = {}
	local perRow = PlotLayout.WILD_PER_ROW
	local width = field.perRow * field.size * tile
	local left = tileCentre(field.col0, 0, tile, plotTiles).x - tile / 2
	local pitch = width / perRow
	local rowsUsed = (#field.rows + 1) // 2
	local total = perRow * rowsUsed
	for i = 0, math.min(math.floor(count), total) - 1 do
		local row = field.rows[(i // perRow) * 2 + 1]
		local centre = tileCentre(field.col0, row, tile, plotTiles)
		local jx = (hash(seed, i, 1) / 999 * 2 - 1) * PlotLayout.WILD_SHIFT
		local jz = (hash(seed, i, 2) / 999 * 2 - 1) * PlotLayout.WILD_SHIFT
		local angle = (hash(seed, i, 3) / 999 * 2 - 1) * PlotLayout.WILD_ANGLE
		table.insert(points, { x = left + (i % perRow + 0.5) * pitch + jx, z = centre.z + jz, angle = angle })
	end
	return points
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
