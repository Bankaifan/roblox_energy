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

return PlotLayout
