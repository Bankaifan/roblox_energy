--!strict
-- Where theme decoration may stand (docs/themes-design.md, section 4.3). Pure: no Roblox APIs and no require; the caller passes
-- the data (the site map, the river course and the cable links), like PlotLayout and River. All lengths are plot-relative
-- studs, unmirrored (road side is +z); the server mirrors z by the plot facing.
local ThemeDecor = {}

-- A box is { minX, maxX, minZ, maxZ }.
export type Box = { number }
export type Line = { points: { { number } }, distance: number }
export type Piece = {
	kind: string,
	count: number,
	footprint: number,
	parts: number,
	zone: string,
	tall: boolean?,
	lights: number?,
	every: number?,
}
export type Set = { pieces: { Piece } }
export type Site = { kind: string, x: number, z: number, yaw: number, scale: number, piece: number }
export type KeepOut = { low: { Box }, tall: { Box } }

ThemeDecor.GRID = 2 -- candidates lie on a grid of this many studs
ThemeDecor.MAX_SCALE = 1.1 -- pieces are scaled 0.9 to 1.1; footprints are checked at the largest
ThemeDecor.SEPARATION = 2 -- studs between two placed pieces
ThemeDecor.EDGE = 0.5 -- studs between a piece and the fence line
ThemeDecor.NEAR = 10 -- a `near:<kind>` piece lies at most this far (edge to edge) from the first piece of that kind
ThemeDecor.RIM = 5 -- the rim zone: the outer edge of the piece reaches within this many studs of the fence line
ThemeDecor.YARD = { 60, 90 } -- z range of the yard zone
ThemeDecor.CORNER = { 60, 90 } -- x and z range of the corner zone (the east yard corner)
ThemeDecor.FENCE_START = 90 -- fenceRoad pieces start at x = -FENCE_START

-- The theme the style item `season` shows for a month (1 to 12): spring Mar-May, summer Jun-Aug, autumn Sep-Nov but
-- halloween in October, christmas in December, classic in January and February.
function ThemeDecor.season(month: number): string
	if month == 10 then
		return "halloween"
	elseif month >= 3 and month <= 5 then
		return "spring"
	elseif month >= 6 and month <= 8 then
		return "summer"
	elseif month >= 9 and month <= 11 then
		return "autumn"
	elseif month == 12 then
		return "christmas"
	end
	return "classic"
end

-- The theme a chosen style item shows in a month: `season` follows the date, every other item is itself.
function ThemeDecor.resolve(item: string, month: number): string
	if item == "season" then
		return ThemeDecor.season(month)
	end
	return item
end

-- The keep-out boxes of the site map. `input`: cells = { { x, z, size } } (every cell of every field, centre and side),
-- furniture = { { x, z, w, d } } (largest size, with crank, founder sign, spawn pad and name sign), lanes = { Box } (walk lanes),
-- furnitureGap = studs added round furniture, fence = fence line. `gap` is added round the cells (1.5 for low pieces, the
-- site clearance for tall ones).
function ThemeDecor.keepOut(
	input: {
		cells: { { number } },
		furniture: { { number } },
		lanes: { Box },
		furnitureGap: number,
	},
	gap: number
): { Box }
	local boxes: { Box } = {}
	for _, cell in input.cells do
		local half = cell[3] / 2 + gap
		table.insert(boxes, { cell[1] - half, cell[1] + half, cell[2] - half, cell[2] + half })
	end
	for _, item in input.furniture do
		local gx, gz = item[3] / 2 + input.furnitureGap, item[4] / 2 + input.furnitureGap
		table.insert(boxes, { item[1] - gx, item[1] + gx, item[2] - gz, item[2] + gz })
	end
	for _, lane in input.lanes do
		table.insert(boxes, lane)
	end
	return boxes
end

-- Distance from (x, z) to the polyline `points` ({ x, z } pairs).
local function lineDistance(points: { { number } }, x: number, z: number): number
	local best = math.huge
	for i = 1, #points - 1 do
		local ax, az, bx, bz = points[i][1], points[i][2], points[i + 1][1], points[i + 1][2]
		local dx, dz = bx - ax, bz - az
		local length2 = dx * dx + dz * dz
		local u = if length2 > 0 then math.max(0, math.min(1, ((x - ax) * dx + (z - az) * dz) / length2)) else 0
		best = math.min(best, (x - (ax + u * dx)) ^ 2 + (z - (az + u * dz)) ^ 2)
	end
	return math.sqrt(best)
end

-- True when a square of side `size` centred at (x, z) overlaps the box (touching is allowed).
local function hits(box: Box, x: number, z: number, size: number): boolean
	local h = size / 2
	return x + h > box[1] and x - h < box[2] and z + h > box[3] and z - h < box[4]
end

-- Integer hash (Park-Miller steps, exact in doubles): the same result on every machine.
local function hash(seed: number, index: number, salt: number): number
	local h = (seed * 73856093 + index * 19349663 + salt * 83492791) % 2147483647
	for _ = 1, 3 do
		h = (h * 48271) % 2147483647
	end
	return h
end

-- Is a piece of `size` studs free at (x, z): inside the fence, off the boxes and off the lines.
local function free(x: number, z: number, size: number, boxes: { Box }, lines: { Line }, fence: number): boolean
	local reach = fence - size / 2 - ThemeDecor.EDGE
	if math.abs(x) > reach or math.abs(z) > reach then
		return false
	end
	for _, box in boxes do
		if hits(box, x, z, size) then
			return false
		end
	end
	for _, line in lines do
		if lineDistance(line.points, x, z) < line.distance + size / 2 then
			return false
		end
	end
	return true
end

-- Where along the road-side rail (z = +fence) a piece of `size` studs can stand every `every` studs: starting at
-- x = -FENCE_START, skipping what the boxes (the name sign, the spawn pad, furniture) and lines block.
function ThemeDecor.fenceLine(
	every: number,
	size: number,
	boxes: { Box },
	lines: { Line },
	fence: number
): { { number } }
	local spots: { { number } } = {}
	local z = fence - size / 2 - ThemeDecor.EDGE
	local x = -ThemeDecor.FENCE_START
	while x <= ThemeDecor.FENCE_START do
		if free(x, z, size, boxes, lines, fence) then
			table.insert(spots, { x, z })
		end
		x += every
	end
	return spots
end

local function inZone(
	zone: string,
	x: number,
	z: number,
	size: number,
	fence: number,
	first: { [string]: Site? },
	sizes: { [string]: number }
): boolean
	local h = size / 2
	if zone == "open" then
		return z + h <= ThemeDecor.YARD[1] -- anywhere but the yard
	elseif zone == "rim" then
		return math.max(math.abs(x), math.abs(z)) + h >= fence - ThemeDecor.RIM
	elseif zone == "yard" then
		return z - h >= ThemeDecor.YARD[1] and z + h <= ThemeDecor.YARD[2]
	elseif zone == "corner" then
		return x - h >= ThemeDecor.CORNER[1]
			and x + h <= ThemeDecor.CORNER[2]
			and z - h >= ThemeDecor.CORNER[1]
			and z + h <= ThemeDecor.CORNER[2]
	end
	local kind = string.match(zone, "^near:(.+)$")
	local anchor = if kind then first[kind] else nil
	if anchor == nil then
		return false
	end
	local reach = h + (sizes[kind :: string] or 0) / 2
	local dx, dz = math.max(0, math.abs(x - anchor.x) - reach), math.max(0, math.abs(z - anchor.z) - reach)
	return dx * dx + dz * dz <= ThemeDecor.NEAR * ThemeDecor.NEAR
end

-- The sites of every piece of `set`, in the order of the set: { kind, x, z, yaw, scale, piece } with `piece` the index of the
-- entry. A piece is placed on a candidate (grid, zone, free of `keep`, `lines` and the pieces before it) picked by a hash of
-- (seed, piece, n), so the same (set, seed) gives the same layout everywhere; a piece without a candidate is dropped.
-- fenceRoad pieces stand on the road-side rail, `corners` pieces in the four fence corners; both only keep off the boxes.
-- Entries of zone `fixed` have no site. `seed` is the plot slot.
function ThemeDecor.sites(set: Set, keep: KeepOut, lines: { Line }, seed: number, fence: number): { Site }
	local placed: { Site } = {}
	local blocking: { { number } } = {} -- x, z, size of the pieces that block later ones
	local first: { [string]: Site? } = {}
	local sizes: { [string]: number } = {}
	local masks: { [string]: { [number]: boolean } } = {}
	local grid = ThemeDecor.GRID
	local steps = fence // grid

	local function wobble(piece: Piece, index: number, n: number, x: number, z: number, yawBase: number)
		local salt = index * 1000 + n
		local scale = 0.9 + (hash(seed, salt, 3) % 201) / 1000
		local yaw = yawBase + (hash(seed, salt, 2) % 31) - 15
		local site: Site = { kind = piece.kind, x = x, z = z, yaw = yaw, scale = scale, piece = index }
		table.insert(placed, site)
		return site
	end

	for index, piece in set.pieces do
		if piece.zone == "fixed" then
			continue
		end
		local size = piece.footprint * ThemeDecor.MAX_SCALE
		local boxes = if piece.tall then keep.tall else keep.low
		sizes[piece.kind] = piece.footprint * ThemeDecor.MAX_SCALE
		if piece.zone == "fenceRoad" then
			for n, spot in ThemeDecor.fenceLine(piece.every or 8, size, boxes, lines, fence) do
				if n > piece.count then
					break
				end
				wobble(piece, index, n, spot[1], spot[2], 0)
			end
			continue
		end
		if piece.zone == "corners" then
			local edge = fence - size / 2 - ThemeDecor.EDGE
			local at = hash(seed, index, 4) % 4
			for n = 1, piece.count do
				local corner = (at + n) % 4
				local x, z = if corner % 2 == 0 then -edge else edge, if corner < 2 then -edge else edge
				if free(x, z, size, boxes, lines, fence) then
					wobble(piece, index, n, x, z, 0)
				end
			end
			continue
		end
		local mask = masks[`{piece.tall}:{size}`]
		if mask == nil then
			mask = {}
			masks[`{piece.tall}:{size}`] = mask
		end
		for n = 1, piece.count do
			local candidates: { { number } } = {}
			for ix = -steps, steps do
				for iz = -steps, steps do
					local x, z = ix * grid, iz * grid
					if not inZone(piece.zone, x, z, size, fence, first, sizes) then
						continue
					end
					local blocked = false
					for _, other in blocking do
						local limit = (size + other[3]) / 2 + ThemeDecor.SEPARATION
						if math.abs(x - other[1]) < limit and math.abs(z - other[2]) < limit then
							blocked = true
							break
						end
					end
					if blocked then
						continue
					end
					local key = ix * 1000 + iz
					local ok = mask[key]
					if ok == nil then
						ok = free(x, z, size, boxes, lines, fence)
						mask[key] = ok
					end
					if ok then
						table.insert(candidates, { x, z })
					end
				end
			end
			if #candidates == 0 then
				continue
			end
			local spot = candidates[hash(seed, index * 1000 + n, 1) % #candidates + 1]
			local site = wobble(piece, index, n, spot[1], spot[2], 90 * (hash(seed, index * 1000 + n, 5) % 4))
			table.insert(blocking, { spot[1], spot[2], size })
			if first[piece.kind] == nil then
				first[piece.kind] = site
			end
		end
	end
	return placed
end

return ThemeDecor
