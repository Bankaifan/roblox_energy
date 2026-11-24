--!strict
-- The outline Neon Plants draws on the ground under a plant, one pattern per plant: a frame for the solar panels and the
-- house, a ring for the waterwheel, three blades round a hub for the wind turbines. Pure geometry: a bar is a flat box of
-- sx x sz studs at (x, z) from the middle of the footprint, turned `turn` degrees about the vertical axis.
export type Bar = { x: number, z: number, sx: number, sz: number, turn: number }

local GlowPattern = {}

GlowPattern.THICK = 0.6 -- width of a line
GlowPattern.RING_SEGMENTS = 12

GlowPattern.kinds = {
	[1] = "frame",
	[2] = "ring",
	[3] = "frame",
	[4] = "rotor",
	[5] = "frame",
	[6] = "rotor",
} :: { [number]: string }

-- The kind of pattern of a plant; an unknown plant gets the ring.
function GlowPattern.kind(plantId: number): string
	return GlowPattern.kinds[plantId] or "ring"
end

-- The footprint a pattern is drawn in, from the bounding box of the plant (width x depth): a rotor stands upright, so its
-- box is long and thin; its star takes the longer side, but at most ROTOR_MAX studs (or `limit`, e.g. the width of a
-- foundation step) across.
GlowPattern.ROTOR_MAX = 14
GlowPattern.FRAME_MARGIN = 1.5 -- studs a frame lies outside the box of the plant

function GlowPattern.footprint(kind: string, width: number, depth: number, limit: number?): (number, number)
	if kind == "rotor" then
		local across = math.min(math.max(width, depth), GlowPattern.ROTOR_MAX, limit or math.huge)
		return across, across
	end
	-- a frame goes round the plant, so that panels standing over the ground do not hide it
	local margin = if kind == "frame" then 2 * GlowPattern.FRAME_MARGIN else 0
	return math.max(2, width) + margin, math.max(2, depth) + margin
end

-- The bars of `kind` inside a footprint of `width` x `depth` studs.
function GlowPattern.bars(kind: string, width: number, depth: number): { Bar }
	local thick = GlowPattern.THICK
	local bars: { Bar } = {}
	if kind == "frame" then
		local halfX, halfZ = width / 2 - thick / 2, depth / 2 - thick / 2
		table.insert(bars, { x = 0, z = -halfZ, sx = width, sz = thick, turn = 0 })
		table.insert(bars, { x = 0, z = halfZ, sx = width, sz = thick, turn = 0 })
		table.insert(bars, { x = -halfX, z = 0, sx = thick, sz = depth - 2 * thick, turn = 0 })
		table.insert(bars, { x = halfX, z = 0, sx = thick, sz = depth - 2 * thick, turn = 0 })
	elseif kind == "rotor" then
		local radius = math.min(width, depth) / 2
		for i = 0, 2 do
			local angle = math.rad(90 + 120 * i)
			-- a blade from the hub outwards, tapering is left to the eye: a long thin bar
			table.insert(bars, {
				x = math.cos(angle) * radius / 2,
				z = math.sin(angle) * radius / 2,
				sx = radius,
				sz = thick * 1.6,
				turn = -math.deg(angle),
			})
		end
		table.insert(bars, { x = 0, z = 0, sx = thick * 3, sz = thick * 3, turn = 45 })
	else
		local radius = math.min(width, depth) / 2 - thick / 2
		local count = GlowPattern.RING_SEGMENTS
		local chord = 2 * radius * math.tan(math.pi / count)
		for i = 0, count - 1 do
			local angle = 2 * math.pi * i / count
			table.insert(bars, {
				x = math.cos(angle) * radius,
				z = math.sin(angle) * radius,
				sx = thick,
				sz = chord,
				turn = -math.deg(angle),
			})
		end
	end
	return bars
end

return GlowPattern
