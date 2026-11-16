--!strict
-- Natural shapes on a plot (issue #111): the plot stays a meadow, only cleared patches become bare earth, and a field
-- that still has to be prepared is marked with stakes and a rope. Nothing here is ruler-straight: outlines wobble by
-- a hash of the plot seed. Pure functions, no Roblox APIs; x and z are studs relative to the plot centre.
local Meadow = {}

-- A cleared patch: a blob around (x, z) with the mean radius r.
export type Patch = { x: number, z: number, r: number }
export type Field = { size: number, col0: number, perRow: number, rows: { number } }
export type Stake = { x: number, z: number, height: number, lean: number, turn: number }
export type Rope = { from: number, to: number }

-- Share of the radius an outline may move in or out: two lobes around the patch plus a soft wave over the whole plot
-- (one bump about every WAVE_PITCH studs), so neighbouring patches bulge together instead of repeating one shape.
Meadow.LOBES = { 0.12, 0.08 }
Meadow.WAVE = 0.2
Meadow.WAVE_PITCH = 10
-- The radius of the patch of a site, as a share of its side: large enough that the whole site is always earth.
Meadow.SITE_RADIUS = 0.9
-- Fence: a stake at most every STAKE_PITCH studs, moved by up to STAKE_SHIFT studs, STAKE_HEIGHT +- STAKE_VARIES tall
-- and leaning by up to STAKE_LEAN degrees.
Meadow.STAKE_PITCH = 16
Meadow.STAKE_SHIFT = 1.2
Meadow.STAKE_HEIGHT = 1.8
Meadow.STAKE_VARIES = 0.4
Meadow.STAKE_LEAN = 9

-- Number in [-1, 1] from (seed, a, b, salt): the same on every call and on every machine.
local function noise(seed: number, a: number, b: number, salt: number): number
	local h = (seed * 73856093 + a * 19349663 + b * 83492791 + salt * 49979687) % 2147483647
	h = (h * 1103515245 + 12345) % 2147483647
	h = (h * 1103515245 + 12345) % 2147483647
	return (h // 1024) % 2001 / 1000 - 1
end

-- Smooth number in [-1, 1] at (x, z): noise on a grid of WAVE_PITCH studs, blended between its corners.
local function wave(seed: number, x: number, z: number): number
	local gx, gz = x / Meadow.WAVE_PITCH, z / Meadow.WAVE_PITCH
	local ix, iz = math.floor(gx), math.floor(gz)
	local fx, fz = gx - ix, gz - iz
	fx, fz = fx * fx * (3 - 2 * fx), fz * fz * (3 - 2 * fz)
	local near = noise(seed, ix, iz, 3) * (1 - fx) + noise(seed, ix + 1, iz, 3) * fx
	local far = noise(seed, ix, iz + 1, 3) * (1 - fx) + noise(seed, ix + 1, iz + 1, 3) * fx
	return near * (1 - fz) + far * fz
end

-- The patch under a site of `side` studs at (x, z).
function Meadow.sitePatch(x: number, z: number, side: number): Patch
	return { x = x, z = z, r = side * Meadow.SITE_RADIUS }
end

-- The terrain cells of a plot of `cells` x `cells` cells of `cell` studs that are bare earth: mask[ix][iz] = true,
-- 1-based from the corner at (-half, -half). A patch only ever adds cells, so clearing more never regrows grass.
function Meadow.mask(patches: { Patch }, seed: number, cells: number, cell: number): { { boolean } }
	local mask: { { boolean } } = table.create(cells)
	for ix = 1, cells do
		mask[ix] = table.create(cells, false)
	end
	local half = cells * cell / 2
	local reach = 1 + Meadow.LOBES[1] + Meadow.LOBES[2] + Meadow.WAVE
	for _, patch in patches do
		-- The lobes belong to the place of the patch, not to its position in the list.
		local px, pz = math.floor(patch.x + 0.5), math.floor(patch.z + 0.5)
		local phase2 = noise(seed, px, pz, 1) * math.pi
		local phase3 = noise(seed, px, pz, 2) * math.pi
		local far = patch.r * reach
		local firstX = math.max(1, math.floor((patch.x - far + half) / cell) + 1)
		local lastX = math.min(cells, math.ceil((patch.x + far + half) / cell))
		local firstZ = math.max(1, math.floor((patch.z - far + half) / cell) + 1)
		local lastZ = math.min(cells, math.ceil((patch.z + far + half) / cell))
		for ix = firstX, lastX do
			local dx = (ix - 0.5) * cell - half - patch.x
			for iz = firstZ, lastZ do
				if not mask[ix][iz] then
					local dz = (iz - 0.5) * cell - half - patch.z
					local angle = math.atan2(dz, dx)
					local factor = 1
						+ Meadow.LOBES[1] * math.sin(2 * angle + phase2)
						+ Meadow.LOBES[2] * math.sin(3 * angle + phase3)
						+ Meadow.WAVE * wave(seed, patch.x + dx, patch.z + dz)
					local limit = patch.r * factor
					mask[ix][iz] = dx * dx + dz * dz < limit * limit
				end
			end
		end
	end
	return mask
end

-- Cuts the unit edges of one grid line (sorted starts, each `size` long) into ropes of at most `span` units.
local function spans(starts: { number }, size: number, span: number, add: (number, number) -> ())
	table.sort(starts)
	local i = 1
	while i <= #starts do
		local from = starts[i]
		local units = 1
		while units < span and starts[i + units] == from + units * size do
			units += 1
		end
		add(from, from + units * size)
		i += units
	end
end

-- Stakes and ropes around the cells of a field that are not mown yet (`mown` is the set of mown cell numbers, see
-- PlotLayout.mown). The rope follows the outline of the open sites; every stake stands a little off its grid corner,
-- leans and has its own height, so no line is straight. A full field has no fence.
function Meadow.fence(
	field: Field,
	mown: { [number]: boolean },
	seed: number,
	tile: number,
	plotTiles: number
): ({ Stake }, { Rope })
	local size = field.size
	local open: { [number]: boolean } = {}
	local function key(tx: number, tz: number): number
		return tx * 1000 + tz
	end
	local sites: { { number } } = {}
	for i = 0, field.perRow * #field.rows - 1 do
		if not mown[i + 1] then
			local tx, tz = field.col0 + (i % field.perRow) * size, field.rows[i // field.perRow + 1]
			open[key(tx, tz)] = true
			table.insert(sites, { tx, tz })
		end
	end
	-- Outline edges by grid line: across[z] holds the x starts of edges along x, along[x] the z starts of edges along z.
	local across: { [number]: { number } } = {}
	local along: { [number]: { number } } = {}
	local function edge(lines: { [number]: { number } }, line: number, start: number)
		lines[line] = lines[line] or {}
		table.insert(lines[line], start)
	end
	for _, site in sites do
		local tx, tz = site[1], site[2]
		if not open[key(tx, tz - size)] then
			edge(across, tz, tx)
		end
		if not open[key(tx, tz + size)] then
			edge(across, tz + size, tx)
		end
		if not open[key(tx - size, tz)] then
			edge(along, tx, tz)
		end
		if not open[key(tx + size, tz)] then
			edge(along, tx + size, tz)
		end
	end

	local stakes: { Stake } = {}
	local ropes: { Rope } = {}
	local index: { [number]: number } = {}
	local half = plotTiles * tile / 2
	local function stake(vx: number, vz: number): number
		local found = index[key(vx, vz)]
		if found ~= nil then
			return found
		end
		table.insert(stakes, {
			x = vx * tile - half + noise(seed, vx, vz, 4) * Meadow.STAKE_SHIFT,
			z = vz * tile - half + noise(seed, vx, vz, 5) * Meadow.STAKE_SHIFT,
			height = Meadow.STAKE_HEIGHT + noise(seed, vx, vz, 6) * Meadow.STAKE_VARIES,
			lean = noise(seed, vx, vz, 7) * Meadow.STAKE_LEAN,
			turn = noise(seed, vx, vz, 8) * 180,
		})
		index[key(vx, vz)] = #stakes
		return #stakes
	end
	local span = math.max(1, Meadow.STAKE_PITCH // (size * tile))
	local function fenceLines(lines: { [number]: { number } }, flip: boolean)
		local order: { number } = {}
		for line in lines do
			table.insert(order, line)
		end
		table.sort(order)
		for _, line in order do
			spans(lines[line], size, span, function(from: number, to: number)
				local a = if flip then stake(line, from) else stake(from, line)
				local b = if flip then stake(line, to) else stake(to, line)
				table.insert(ropes, { from = a, to = b })
			end)
		end
	end
	fenceLines(across, false)
	fenceLines(along, true)
	return stakes, ropes
end

return Meadow
