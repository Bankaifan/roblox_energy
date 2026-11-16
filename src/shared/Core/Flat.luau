--!strict
-- Pure maths for laying a slab-shaped model (a solar panel) flat, whatever rotation its parts and its pivot carry.
-- No Roblox APIs. A part is an oriented box in world space; Model:GetBoundingBox is not used because its box follows
-- the pivot's rotation, not the world axes.
local Flat = {}

export type Vec = { x: number, y: number, z: number }
-- Centre, size along the part's own axes, and those axes as unit vectors in world space.
export type Part = { pos: Vec, size: Vec, right: Vec, up: Vec, back: Vec }
export type Box = { minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number }

local function dot(a: Vec, b: Vec): number
	return a.x * b.x + a.y * b.y + a.z * b.z
end

local function cross(a: Vec, b: Vec): Vec
	return { x = a.y * b.z - a.z * b.y, y = a.z * b.x - a.x * b.z, z = a.x * b.y - a.y * b.x }
end

local function length(a: Vec): number
	return math.sqrt(dot(a, a))
end

-- The world-axis box around the parts. Nil for an empty list.
function Flat.box(parts: { Part }): Box?
	local box: Box? = nil
	for _, part in parts do
		local size = part.size
		local reach = {
			x = (math.abs(part.right.x) * size.x + math.abs(part.up.x) * size.y + math.abs(part.back.x) * size.z) / 2,
			y = (math.abs(part.right.y) * size.x + math.abs(part.up.y) * size.y + math.abs(part.back.y) * size.z) / 2,
			z = (math.abs(part.right.z) * size.x + math.abs(part.up.z) * size.y + math.abs(part.back.z) * size.z) / 2,
		}
		local at = part.pos
		if box == nil then
			box = { minX = at.x, minY = at.y, minZ = at.z, maxX = at.x, maxY = at.y, maxZ = at.z }
		end
		box.minX = math.min(box.minX, at.x - reach.x)
		box.minY = math.min(box.minY, at.y - reach.y)
		box.minZ = math.min(box.minZ, at.z - reach.z)
		box.maxX = math.max(box.maxX, at.x + reach.x)
		box.maxY = math.max(box.maxY, at.y + reach.y)
		box.maxZ = math.max(box.maxZ, at.z + reach.z)
	end
	return box
end

-- The face normal of the slab in world space: the thinnest axis of the largest part (the body), pointing to the side
-- the other parts (the glass, the cells) sit on. A body alone, or parts centred in it: the side closer to `toward`.
-- Nil for an empty list.
function Flat.normal(parts: { Part }, toward: Vec): Vec?
	local body: Part? = nil
	local largest = -1
	for _, part in parts do
		local volume = part.size.x * part.size.y * part.size.z
		if volume > largest then
			largest = volume
			body = part
		end
	end
	if body == nil then
		return nil
	end
	local size = body.size
	local axis = body.up
	if size.x <= size.y and size.x <= size.z then
		axis = body.right
	elseif size.z <= size.x and size.z <= size.y then
		axis = body.back
	end
	local side, others = 0, 0
	for _, part in parts do
		if part ~= body then
			local offset = { x = part.pos.x - body.pos.x, y = part.pos.y - body.pos.y, z = part.pos.z - body.pos.z }
			side += dot(offset, axis)
			others += 1
		end
	end
	if others == 0 or math.abs(side / others) < 1e-4 then
		side = dot(axis, toward)
	end
	if side < 0 then
		return { x = -axis.x, y = -axis.y, z = -axis.z }
	end
	return axis
end

-- The shortest rotation that turns the unit vector `from` onto the unit vector `to`: a unit axis and an angle in
-- radians (0 when they already agree, half a turn about any axis across `from` when they are opposite).
function Flat.turn(from: Vec, to: Vec): (Vec, number)
	local axis = cross(from, to)
	local sine = length(axis)
	local cosine = dot(from, to)
	if sine < 1e-6 then
		if cosine > 0 then
			return { x = 0, y = 1, z = 0 }, 0
		end
		axis = cross(from, { x = 1, y = 0, z = 0 })
		if length(axis) < 1e-6 then
			axis = cross(from, { x = 0, y = 0, z = 1 })
		end
		sine = length(axis)
		return { x = axis.x / sine, y = axis.y / sine, z = axis.z / sine }, math.pi
	end
	return { x = axis.x / sine, y = axis.y / sine, z = axis.z / sine }, math.atan2(sine, cosine)
end

return Flat
